library(testthat)
library(EDI)

# InferenceNonParamBootstrap's design-backed reusable worker: create_design_backed_bootstrap_worker_state()
# (independent duplicate of the object and its design; snapshot of the base data incl. effective survival
# times / event indicators) and load_bootstrap_sample_into_design_backed_worker() (row subsetting of w, y,
# X, dead, m, cache resets, KK match-id override), checked by recomputing the estimate on the loaded sample.

wk_fx <- function(n = 30L, seed = 4L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- w + rnorm(n)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des); inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private, des = des, w = w, y = y, n = n)
}

mean_diff <- function(y, w) mean(y[w == 1]) - mean(y[w == 0])

test_that("worker state: an independent single-core duplicate plus a snapshot of the base data", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	expect_equal(ws$n, f$n)
	expect_equal(ws$base_w, as.numeric(f$w)); expect_equal(ws$base_y, f$y)
	expect_equal(ws$base_dead, rep(1, f$n))                                              # exact responses: all events
	expect_null(ws$base_m)
	expect_equal(nrow(ws$base_X), f$n)
	expect_equal(nrow(ws$base_Xraw), f$n)
	expect_false(identical(ws$worker, f$inf))
	expect_equal(ws$worker$num_cores, 1L)
	expect_false(identical(ws$worker_des_priv, f$p$des_obj_priv_int))                    # the design was duplicated too
	expect_identical(ws$worker_priv$des_obj_priv_int, ws$worker_des_priv)
	expect_equal(ws$base_Xraw, as.data.frame(f$p$des_obj_priv_int$Xraw))
})

test_that("loading a sample subsets the worker's data and the estimate equals the estimate on those rows", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	set.seed(3)
	idx <- sample(f$n, f$n, replace = TRUE)
	while (length(unique(f$w[idx])) < 2L) idx <- sample(f$n, f$n, replace = TRUE)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	wp <- ws$worker_priv
	expect_equal(wp$w, as.numeric(f$w[idx])); expect_equal(wp$y, f$y[idx]); expect_equal(wp$y_temp, f$y[idx])
	expect_equal(wp$n, f$n); expect_equal(nrow(wp$X), f$n)
	expect_equal(c(ws$worker_des_priv$n, ws$worker_des_priv$t), c(f$n, f$n))              # the worker design's size follows the sample
	expect_equal(ws$worker$compute_estimate(estimate_only = TRUE), mean_diff(f$y[idx], f$w[idx]), tolerance = 1e-10)
	# The source object is untouched.
	expect_equal(f$inf$compute_estimate(), mean_diff(f$y, f$w), tolerance = 1e-10)
	expect_equal(f$p$w, f$w)
})

test_that("a smaller sample changes n, drops every derived cache and can be reloaded repeatedly", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	wp <- ws$worker_priv
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, 1:10)
	wp$cached_values$beta_hat_T <- 5; wp$cached_reduced_X <- matrix(1); wp$cached_design_matrix <- matrix(2); wp$cached_mod <- list(b = 1)
	expect_equal(wp$n, 10L)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, 11:30)
	expect_equal(wp$n, 20L); expect_equal(wp$w, as.numeric(f$w[11:30]))
	expect_length(wp$cached_values, 0L)
	expect_null(wp$cached_reduced_X); expect_null(wp$cached_design_matrix); expect_null(wp$cached_mod)
	expect_equal(ws$worker$compute_estimate(estimate_only = TRUE), mean_diff(f$y[11:30], f$w[11:30]), tolerance = 1e-10)
})

test_that("the indices may be a bare vector or a list draw with i_b (and an optional m_vec_b override)", {
	f <- wk_fx()
	ws <- f$p$create_design_backed_bootstrap_worker_state()
	idx <- c(2, 5, 7, 9, 20, 21)
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, list(i_b = idx, m_vec_b = NULL))
	expect_equal(ws$worker_priv$w, as.numeric(f$w[idx]))
	f$p$load_bootstrap_sample_into_design_backed_worker(ws, as.numeric(idx))              # doubles are coerced to integer rows
	expect_equal(ws$worker_priv$y, f$y[idx])
	expect_null(ws$worker_priv$m %||% NULL)
})

test_that("KK designs: the match vector is subset by row unless the draw supplies its own renumbered ids", {
	set.seed(6); np <- 8L; ns <- 4L; n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x = rnorm(n)); for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns)); des$.__enclos_env__$private$m <- m
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	expect_equal(as.integer(ws$base_m), m)
	idx <- c(1L, 2L, 5L, 6L, 17L, 18L)
	p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	expect_equal(as.integer(ws$worker_priv$m), m[idx])
	p$load_bootstrap_sample_into_design_backed_worker(ws, list(i_b = idx, m_vec_b = c(1L, 1L, 2L, 2L, 0L, 0L)))
	expect_equal(as.integer(ws$worker_priv$m), c(1L, 1L, 2L, 2L, 0L, 0L))
})

test_that("survival responses: the base response is the effective time and the event indicator follows censoring", {
	set.seed(8); n <- 24L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	t <- rexp(n); d <- rep(c(1, 0, 1, 1), length.out = n)
	des$add_all_subject_responses(ifelse(d == 1, t, NA), ifelse(d == 1, NA, t), ifelse(d == 1, NA, Inf))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE); p <- inf$.__enclos_env__$private
	ws <- p$create_design_backed_bootstrap_worker_state()
	expect_equal(ws$base_y, t); expect_equal(ws$base_dead, d)
	idx <- c(1L, 2L, 3L, 4L, 4L, 2L)
	p$load_bootstrap_sample_into_design_backed_worker(ws, idx)
	expect_equal(ws$worker_priv$y, t[idx]); expect_equal(ws$worker_priv$dead, d[idx])
	expect_true(ws$worker_priv$any_censoring)
	p$load_bootstrap_sample_into_design_backed_worker(ws, c(1L, 3L, 4L))               # only events
	expect_false(ws$worker_priv$any_censoring)
})
