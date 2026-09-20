library(testthat)
library(EDI)

# InferenceParamBootstrap's replicate machinery, driven by hand-built bootstrap specs:
# compute_param_bootstrap_lr_from_boot_spec() (every failure reason and the success value
# 2 * (null NLL - full NLL)), compute_param_bootstrap_lr_impl() (retry attempts, last failure
# returned), and run_param_bootstrap_replicates() (B results, seed-determinism, RNG-state
# restoration, serial dispatch). validate_param_bootstrap_spec and the failure-reason extractor
# are checked alongside.

pb_fx <- function(seed = 2L, n = 60L, run_seed = NULL) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w)))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	p$seed <- run_seed
	list(inf = inf, p = p)
}

spec_with <- function(full_nll = 10, null_nll = 13, null_fit = list(b = 1), fit_null_result = "ok") {
	list(
		full_fit = list(b = c(0, 1)),
		fit_null = function(d) if (identical(fit_null_result, "ok")) null_fit else if (identical(fit_null_result, "error")) stop("no fit") else NULL,
		neg_loglik = function(fit) if (identical(fit, list(b = c(0, 1)))) full_nll else null_nll
	)
}

test_that("spec validation needs a list with a full fit and two functions", {
	f <- pb_fx()
	v <- f$p$validate_param_bootstrap_spec
	expect_true(v(spec_with()))
	expect_false(v(NULL)); expect_false(v("x")); expect_false(v(list()))
	expect_false(v(list(full_fit = 1, fit_null = 1, neg_loglik = function(x) 1)))
	expect_false(v(list(full_fit = 1, fit_null = function(d) 1)))
	expect_false(v(list(fit_null = function(d) 1, neg_loglik = function(x) 1)))
})

test_that("failure-reason extraction prefers the spec field, then the attribute, then the default", {
	f <- pb_fx(); ex <- f$p$extract_param_bootstrap_failure_reason
	expect_equal(ex(NULL), "simulated_data_failure")
	expect_equal(ex(list(failure_reason = "bad_x")), "bad_x")
	s <- list(); attr(s, "edi_param_boot_failure_reason") <- "from_attr"
	expect_equal(ex(s), "from_attr")
	expect_equal(ex(list(failure_reason = 5)), "simulated_data_failure")
	expect_equal(ex(list(), default = "custom"), "custom")
	expect_equal(ex(list(failure_reason = c("first", "second"))), "first")
})

test_that("LR from a spec: 2 * (null NLL - full NLL) on success, a specific reason for each failure", {
	f <- pb_fx(); g <- f$p$compute_param_bootstrap_lr_from_boot_spec
	ok <- g(spec_with(10, 13), 0)
	expect_true(ok$success); expect_equal(ok$lr, 6); expect_equal(ok$reason, "success"); expect_equal(ok$attempts, 1L)
	expect_equal(g(spec_with(10, 10), 0)$lr, 0)
	expect_equal(g(spec_with(10, 9.5), 0)$lr, -1)                                      # negative LR is returned as is (not clipped)
	expect_equal(g(NULL, 0)$reason, "simulated_data_failure")
	expect_equal(g(list(failure_reason = "custom_reason"), 0)$reason, "custom_reason")
	expect_equal(g(list(full_fit = 1), 0)$reason, "full_refit_failure")                 # invalid spec without an explicit reason
	expect_equal(g(spec_with(full_nll = NA_real_), 0)$reason, "full_refit_failure")
	expect_equal(g(spec_with(fit_null_result = "error"), 0)$reason, "null_refit_failure")
	expect_equal(g(spec_with(fit_null_result = "null"), 0)$reason, "null_refit_failure")
	expect_equal(g(spec_with(null_nll = Inf), 0)$reason, "non_finite_lr")
	bad <- g(spec_with(null_nll = NaN), 0)
	expect_false(bad$success); expect_true(is.na(bad$lr)); expect_null(bad$details)
	# The null fit is requested at the hypothesised delta.
	seen <- NULL
	sp <- spec_with(); sp$fit_null <- function(d) { seen <<- d; list(b = 1) }
	g(sp, 0.37); expect_equal(seen, 0.37)
})

test_that("result constructors coerce to scalars", {
	f <- pb_fx()
	s <- f$p$param_boot_success_result(c(2.5, 9), attempts = c(3L, 4L))
	expect_equal(s$lr, 2.5); expect_equal(s$attempts, 3L); expect_true(s$success); expect_equal(s$reason, "success")
	x <- f$p$param_boot_failure_result(c("a", "b"), attempts = 2, details = list(k = 1))
	expect_equal(x$reason, "a"); expect_equal(x$attempts, 2L); expect_equal(x$details, list(k = 1)); expect_false(x$success)
})

test_that("LR impl retries up to the attempt cap, returns the first success, else the last failure", {
	f <- pb_fx(); calls <- 0L
	unlockBinding("simulate_under_lik_null", f$p)
	f$p$simulate_under_lik_null <- function(spec, delta, null_fit) {
		calls <<- calls + 1L
		if (calls < 3L) NULL else spec_with(10, 14)
	}
	r <- f$p$compute_param_bootstrap_lr_impl(list(), 0, list(), seed = 1L, max_attempts_per_replicate = 5L)
	expect_true(r$success); expect_equal(r$lr, 8); expect_equal(r$attempts, 3L); expect_equal(calls, 3L)
	calls <- 0L
	r2 <- f$p$compute_param_bootstrap_lr_impl(list(), 0, list(), seed = 1L, max_attempts_per_replicate = 2L)
	expect_false(r2$success); expect_equal(r2$reason, "simulated_data_failure"); expect_equal(r2$attempts, 2L); expect_equal(calls, 2L)
	expect_equal(f$p$compute_param_bootstrap_lr_impl(list(), 0, list(), seed = 1L, max_attempts_per_replicate = 0L)$attempts, 1L)   # at least one attempt
	# A simulator that throws is handled like a missing spec.
	f$p$simulate_under_lik_null <- function(spec, delta, null_fit) stop("sim failed")
	expect_equal(f$p$compute_param_bootstrap_lr_impl(list(), 0, list(), seed = 1L)$reason, "simulated_data_failure")
})

test_that("replicate runner: B results, deterministic per-replicate seeds when the object has a seed, RNG state restored", {
	f <- pb_fx(run_seed = 11L)
	unlockBinding("simulate_under_lik_null", f$p)
	f$p$simulate_under_lik_null <- function(spec, delta, null_fit) {
		u <- runif(1)                                                                   # depends on the replicate's seed
		list(full_fit = list(b = c(0, 1)), fit_null = function(d) list(b = 1), neg_loglik = function(fit) if (identical(fit, list(b = c(0, 1)))) 10 else 10 + u)
	}
	set.seed(99); before <- .Random.seed
	a <- f$p$run_param_bootstrap_replicates(list(), 0, list(), B = 8L, max_attempts_per_replicate = 1L, allow_worker_reuse = FALSE)
	expect_identical(.Random.seed, before)                                              # the caller's stream is untouched
	b <- f$p$run_param_bootstrap_replicates(list(), 0, list(), B = 8L, max_attempts_per_replicate = 1L, allow_worker_reuse = FALSE)
	lrs <- function(res) vapply(res$results, function(r) r$lr, numeric(1))
	expect_length(a$results, 8L)
	expect_equal(lrs(a), lrs(b))                                                        # same seed -> same LRs
	expect_true(all(lrs(a) >= 0 & lrs(a) <= 2))                                         # 2 * U(0, 1)
	expect_gt(length(unique(round(lrs(a), 8))), 4L)                                     # replicates differ from each other
	expect_true(a$used_deterministic_mode); expect_false(a$used_worker_path)
	g <- pb_fx(run_seed = 12L)
	unlockBinding("simulate_under_lik_null", g$p); g$p$simulate_under_lik_null <- f$p$simulate_under_lik_null
	expect_false(isTRUE(all.equal(lrs(g$p$run_param_bootstrap_replicates(list(), 0, list(), 8L, 1L, allow_worker_reuse = FALSE)), lrs(a))))   # a different seed changes them
})

test_that("without a stored seed the runner is not deterministic and uses the serial path", {
	f <- pb_fx()
	unlockBinding("simulate_under_lik_null", f$p)
	f$p$simulate_under_lik_null <- function(spec, delta, null_fit) {
		u <- runif(1)
		list(full_fit = list(b = c(0, 1)), fit_null = function(d) list(b = 1), neg_loglik = function(fit) if (identical(fit, list(b = c(0, 1)))) 10 else 10 + u)
	}
	set.seed(1); a <- f$p$run_param_bootstrap_replicates(list(), 0, list(), 6L, 1L, allow_worker_reuse = FALSE)
	set.seed(2); b <- f$p$run_param_bootstrap_replicates(list(), 0, list(), 6L, 1L, allow_worker_reuse = FALSE)
	expect_false(a$used_deterministic_mode)
	lrs <- function(res) vapply(res$results, function(r) r$lr, numeric(1))
	expect_false(isTRUE(all.equal(lrs(a), lrs(b))))
	expect_length(a$results, 6L)
})
