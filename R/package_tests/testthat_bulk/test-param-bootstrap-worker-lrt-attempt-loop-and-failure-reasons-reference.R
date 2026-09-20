library(testthat)
library(EDI)

# compute_param_bootstrap_worker_lrt(): the per-replicate attempt loop on a reused worker.
# Driven with a fake worker state and a stubbed draw loader so each branch is isolated:
# missing worker -> simulated_data_failure; loader FALSE -> the worker's own
# lr_from_boot_spec result; spec / evaluation failures -> full/null refit failure;
# non-finite negloglik(s) -> the matching reason; success gives
# LR = 2 * (null_negloglik - full_negloglik); retries stop at the first finite LR and the
# last failed result is returned with its attempt count. Also the reuse predicates.

ctx <- function() {
	set.seed(2)
	n <- 30L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	list(inf = inf, priv = priv)
}
stub_loader <- function(priv, fn) {
	unlockBinding("load_param_bootstrap_draw_into_worker", priv)
	priv$load_param_bootstrap_draw_into_worker <- fn
}
worker <- function(eval_fn = function(...) list(invalid = FALSE, full_negloglik = 10, null_negloglik = 12.5),
		spec_fn = function() list(ok = TRUE), sim_fn = function(spec, delta, null_fit) list(worker_data = list(y = 1)),
		lr_fn = function(draw, delta) list(success = FALSE, lr = NA_real_, reason = "from_worker", attempts = 1L)) {
	state_env <- new.env()
	list(worker_priv = list(simulate_under_lik_null = sim_fn, get_likelihood_test_spec = spec_fn,
			get_memoized_likelihood_test_eval = eval_fn, compute_param_bootstrap_lr_from_boot_spec = lr_fn),
		spec = list(), null_fit = list(), state_env = state_env)
}

test_that("a missing worker or worker_priv is a simulated-data failure", {
	f <- ctx()
	r1 <- f$priv$compute_param_bootstrap_worker_lrt(NULL, 0)
	expect_false(r1$success); expect_equal(r1$reason, "simulated_data_failure"); expect_true(is.na(r1$lr))
	expect_equal(f$priv$compute_param_bootstrap_worker_lrt(list(worker_priv = NULL), 0)$reason, "simulated_data_failure")
})

test_that("a successful replicate returns the likelihood-ratio statistic 2 * (null - full)", {
	f <- ctx()
	stub_loader(f$priv, function(worker_state, sim_data) TRUE)
	got <- NULL
	w <- worker(eval_fn = function(delta, testing_type, spec, include_full_negloglik, include_null_negloglik) {
		got <<- list(delta = delta, type = testing_type, full = include_full_negloglik, null = include_null_negloglik)
		list(invalid = FALSE, full_negloglik = 10, null_negloglik = 12.5)
	})
	r <- f$priv$compute_param_bootstrap_worker_lrt(w, 0.3)
	expect_true(r$success)
	expect_equal(r$lr, 5)
	expect_equal(r$reason, "success")
	expect_equal(r$attempts, 1L)
	expect_equal(got, list(delta = 0.3, type = "lik_ratio", full = TRUE, null = TRUE))
})

test_that("each failure point maps to its reason", {
	f <- ctx()
	stub_loader(f$priv, function(worker_state, sim_data) TRUE)
	run <- function(w) f$priv$compute_param_bootstrap_worker_lrt(w, 0)
	expect_equal(run(worker(spec_fn = function() NULL))$reason, "full_refit_failure")
	expect_equal(run(worker(spec_fn = function() stop("x")))$reason, "full_refit_failure")
	expect_equal(run(worker(eval_fn = function(...) stop("boom")))$reason, "null_refit_failure")
	expect_equal(run(worker(eval_fn = function(...) list(invalid = TRUE)))$reason, "null_refit_failure")
	expect_equal(run(worker(eval_fn = function(...) list(invalid = FALSE, full_negloglik = NA_real_, null_negloglik = 1)))$reason, "full_refit_failure")
	expect_equal(run(worker(eval_fn = function(...) list(invalid = FALSE, full_negloglik = 1, null_negloglik = Inf)))$reason, "null_refit_failure")
	expect_equal(run(worker(eval_fn = function(...) list(invalid = FALSE, full_negloglik = -Inf, null_negloglik = 1)))$reason, "full_refit_failure")
	for (r in list(run(worker(spec_fn = function() NULL)), run(worker(eval_fn = function(...) stop("boom"))))) {
		expect_false(r$success); expect_true(is.na(r$lr))
	}
})

test_that("when the draw cannot be loaded, the worker's own LR-from-draw result is used", {
	f <- ctx()
	stub_loader(f$priv, function(worker_state, sim_data) { worker_state$state_env$current_param_bootstrap_draw <- sim_data; FALSE })
	seen <- NULL
	w <- worker(sim_fn = function(spec, delta, null_fit) list(marker = "draw"),
		lr_fn = function(draw, delta) { seen <<- list(draw = draw, delta = delta); list(success = TRUE, lr = 3.25, reason = "success", attempts = 1L) })
	r <- f$priv$compute_param_bootstrap_worker_lrt(w, 0.5)
	expect_equal(r$lr, 3.25)
	expect_equal(seen, list(draw = list(marker = "draw"), delta = 0.5))
})

test_that("retries stop at the first finite statistic; exhausted retries return the last failure with its attempt count", {
	f <- ctx()
	stub_loader(f$priv, function(worker_state, sim_data) TRUE)
	calls <- 0L
	w <- worker(eval_fn = function(...) {
		calls <<- calls + 1L
		if (calls < 3L) list(invalid = TRUE) else list(invalid = FALSE, full_negloglik = 1, null_negloglik = 2)
	})
	r <- f$priv$compute_param_bootstrap_worker_lrt(w, 0, max_attempts_per_replicate = 5L)
	expect_true(r$success); expect_equal(r$lr, 2); expect_equal(r$attempts, 3L); expect_equal(calls, 3L)

	calls <- 0L
	w2 <- worker(eval_fn = function(...) { calls <<- calls + 1L; list(invalid = TRUE) })
	r2 <- f$priv$compute_param_bootstrap_worker_lrt(w2, 0, max_attempts_per_replicate = 4L)
	expect_false(r2$success); expect_equal(r2$attempts, 4L); expect_equal(calls, 4L)
	expect_equal(r2$reason, "null_refit_failure")
})

test_that("a seed makes the simulated draws reproducible", {
	f <- ctx()
	stub_loader(f$priv, function(worker_state, sim_data) TRUE)
	w <- worker(sim_fn = function(spec, delta, null_fit) list(worker_data = list(y = runif(1))),
		eval_fn = function(...) list(invalid = FALSE, full_negloglik = runif(1), null_negloglik = 1 + runif(1)))
	a <- f$priv$compute_param_bootstrap_worker_lrt(w, 0, seed = 11L)
	b <- f$priv$compute_param_bootstrap_worker_lrt(w, 0, seed = 11L)
	c <- f$priv$compute_param_bootstrap_worker_lrt(w, 0, seed = 12L)
	expect_equal(a$lr, b$lr)
	expect_false(isTRUE(all.equal(a$lr, c$lr)))
})

test_that("reusable-worker predicates follow the enabling flag and the support hook", {
	f <- ctx()
	expect_true(f$priv$supports_reusable_param_bootstrap_worker())
	f$priv$reusable_bootstrap_worker_enabled <- TRUE
	expect_true(f$priv$use_reusable_param_bootstrap_worker())
	f$priv$reusable_bootstrap_worker_enabled <- FALSE
	expect_false(f$priv$use_reusable_param_bootstrap_worker())
})
