library(testthat)
library(EDI)

# InferenceRand's per-draw machinery: setup_randomization_template_and_shifts() (null-shifted
# responses, lazy template), load_randomization_perm_into_worker() (worker w / y overwrite and
# cache resets), load_randomization_draw_into_worker() (list vs bare draws),
# sync_randomization_worker_state() and run_randomization_iteration() (permutation lookup with
# wrap-around, delta shifting, debug output), checked against direct mean-difference references.

rw_fx <- function(n = 24L, seed = 4L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- 0.5 * w + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des); inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private, des = des, w = w, y = y, n = n)
}

mean_diff <- function(y, w) mean(y[w == 1]) - mean(y[w == 0])

test_that("setup: no shift for delta = 0; for a nonzero delta the treated responses are shifted back by delta; the template is built lazily", {
	f <- rw_fx()
	s0 <- f$p$setup_randomization_template_and_shifts(0, "none")
	expect_equal(s0$y_delta, f$y); expect_equal(s0$base_template_y, f$y)
	s <- f$p$setup_randomization_template_and_shifts(0.7, "none")
	expect_equal(s$y_delta, ifelse(f$w == 1, f$y - 0.7, f$y))
	expect_equal(mean_diff(s$y_delta, f$w), mean_diff(f$y, f$w) - 0.7, tolerance = 1e-10)
	expect_true(is.function(s$get_template))
	tpl <- s$get_template()
	expect_equal(tpl$.__enclos_env__$private$y, s$y_delta)
	expect_identical(s$get_template(), tpl)                                          # built once
	expect_false(identical(tpl, f$des))                                              # a duplicate, not the original design
	expect_equal(f$des$get_y(), f$y)                                                 # the original is untouched
})

worker_for <- function(f) {
	dup <- f$inf$duplicate()
	list(worker_inf = dup, worker_des = dup$.__enclos_env__$private$des_obj$duplicate())
}

test_that("loading a permutation into a worker overwrites w and y and clears every derived cache", {
	f <- rw_fx()
	f$inf$compute_estimate(estimate_only = FALSE)
	wk <- worker_for(f)
	ip <- wk$worker_inf$.__enclos_env__$private
	ip$cached_values$beta_hat_T <- 999; ip$cached_values$s_beta_hat_T <- 9; ip$cached_reduced_X <- matrix(1)
	set.seed(1); perm <- sample(f$w)
	s0 <- f$p$setup_randomization_template_and_shifts(0, "none")
	f$p$load_randomization_perm_into_worker(wk, perm, 0, "none", s0$y_delta, s0$base_template_y, s0$base_template_dead)
	expect_equal(ip$w, perm); expect_equal(ip$y, f$y); expect_equal(ip$y_temp, f$y)
	expect_null(ip$cached_values$beta_hat_T); expect_null(ip$cached_values$s_beta_hat_T); expect_null(ip$cached_reduced_X)
	expect_equal(wk$worker_des$.__enclos_env__$private$w, perm)
	# With a nonzero delta the worker sees y shifted forward on the permuted treated rows.
	s1 <- f$p$setup_randomization_template_and_shifts(0.5, "none")
	f$p$load_randomization_perm_into_worker(wk, perm, 0.5, "none", s1$y_delta, s1$base_template_y, s1$base_template_dead)
	expect_equal(ip$y, ifelse(perm == 1, s1$y_delta + 0.5, s1$y_delta), tolerance = 1e-12)
	expect_equal(wk$worker_des$.__enclos_env__$private$y, ip$y)
})

test_that("draw loading accepts a bare permutation or a list draw with $w, and the worker estimate needs a reusable estimator", {
	f <- rw_fx()
	wk <- worker_for(f); ip <- wk$worker_inf$.__enclos_env__$private
	s0 <- f$p$setup_randomization_template_and_shifts(0, "none")
	set.seed(2); perm <- sample(f$w)
	f$p$load_randomization_draw_into_worker(wk, perm, 0, "none", s0)
	expect_equal(ip$w, perm)
	perm2 <- sample(f$w)
	f$p$load_randomization_draw_into_worker(wk, list(w = perm2, m_vec = NULL), 0, "none", s0)
	expect_equal(ip$w, perm2)
	got <- f$p$compute_randomization_worker_estimate(list(worker = wk$worker_inf))
	expect_equal(got, mean_diff(f$y, perm2), tolerance = 1e-10)
})

test_that("sync copies the thread design's state into the inference object and drops its design-matrix caches", {
	f <- rw_fx()
	thread_des <- f$des$duplicate(); thread_inf <- f$inf$duplicate()
	dp <- thread_des$.__enclos_env__$private
	set.seed(3); dp$w <- sample(f$w); dp$y <- f$y + 1
	tp <- thread_inf$.__enclos_env__$private
	tp$cached_reduced_X <- matrix(1); tp$cached_design_matrix <- matrix(2)
	expect_null(f$p$sync_randomization_worker_state(NULL, thread_inf))
	f$p$sync_randomization_worker_state(thread_des, thread_inf)
	expect_equal(tp$w, dp$w); expect_equal(tp$y, dp$y); expect_equal(tp$y_temp, dp$y)
	expect_identical(tp$des_obj, thread_des)
	expect_null(tp$cached_reduced_X); expect_null(tp$cached_design_matrix)
})

test_that("an iteration evaluates the estimator under the requested permutation (with wrap-around) and shifts responses for delta != 0", {
	f <- rw_fx()
	set.seed(5)
	W <- replicate(4, sample(f$w))
	perms <- list(w_mat = W, m_mat = NULL)
	s0 <- f$p$setup_randomization_template_and_shifts(0, "none")
	iter <- function(i, delta = 0, setup = s0, debug = FALSE) {
		f$p$run_randomization_iteration(f$des$duplicate(), f$inf$duplicate(), i, perms, delta, "none",
			setup$y_delta, setup$base_template_y, setup$base_template_dead, debug = debug)
	}
	for (i in 1:4) expect_equal(iter(i), mean_diff(f$y, W[, i]), tolerance = 1e-10)
	expect_equal(iter(6), mean_diff(f$y, W[, 2]), tolerance = 1e-10)                 # index 6 wraps to column 2
	s1 <- f$p$setup_randomization_template_and_shifts(0.4, "none")
	expect_equal(iter(3, delta = 0.4, setup = s1), mean_diff(ifelse(W[, 3] == 1, s1$y_delta + 0.4, s1$y_delta), W[, 3]), tolerance = 1e-10)
	d <- iter(1, debug = TRUE)
	expect_equal(names(d), c("val", "error")); expect_null(d$error)
	expect_equal(d$val, mean_diff(f$y, W[, 1]), tolerance = 1e-10)
	# A list of permutation records is accepted too.
	lst <- lapply(1:2, function(j) list(w = W[, j], m_vec = NULL))
	v <- f$p$run_randomization_iteration(f$des$duplicate(), f$inf$duplicate(), 2L, lst, 0, "none", s0$y_delta, s0$base_template_y, s0$base_template_dead)
	expect_equal(v, mean_diff(f$y, W[, 2]), tolerance = 1e-10)
})

test_that("estimator failures become NA (with the message in debug mode) and nonestimable estimates are NA", {
	f <- rw_fx()
	perms <- list(w_mat = cbind(f$w), m_mat = NULL)
	s0 <- f$p$setup_randomization_template_and_shifts(0, "none")
	thread_inf <- f$inf$duplicate()
	unlockBinding("compute_treatment_estimate_during_randomization_inference", thread_inf$.__enclos_env__$private)
	thread_inf$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference <- function(estimate_only = TRUE) stop("boom")
	r <- f$p$run_randomization_iteration(f$des$duplicate(), thread_inf, 1L, perms, 0, "none", s0$y_delta, s0$base_template_y, s0$base_template_dead, debug = TRUE)
	expect_true(is.na(r$val)); expect_identical(r$error, "boom")
	expect_true(is.na(f$p$run_randomization_iteration(f$des$duplicate(), thread_inf, 1L, perms, 0, "none", s0$y_delta, s0$base_template_y, s0$base_template_dead)))
	flagged <- f$inf$duplicate()
	unlockBinding("compute_treatment_estimate_during_randomization_inference", flagged$.__enclos_env__$private)
	flagged$.__enclos_env__$private$compute_treatment_estimate_during_randomization_inference <- function(estimate_only = TRUE) {
		flagged$.__enclos_env__$private$cache_nonestimable_estimate("bad"); 1.5 }
	expect_true(is.na(f$p$run_randomization_iteration(f$des$duplicate(), flagged, 1L, perms, 0, "none", s0$y_delta, s0$base_template_y, s0$base_template_dead)))
})
