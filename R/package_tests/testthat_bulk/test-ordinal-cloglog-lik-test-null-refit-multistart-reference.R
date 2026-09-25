library(testthat)
library(EDI)

# InferenceOrdinalCloglogRegr's get_likelihood_test_spec()$fit_null(delta) (inference_ordinal_
# cloglog.R:183-210) tries TWO starting points for the constrained (treatment coefficient pinned at
# -delta) null refit -- the caller-supplied/warm-started point and a nudged version of the full
# unconstrained fit -- and keeps whichever converges to the lower neg_loglik. This multi-start fix
# (found 2026-09-23, ordinal_cumulative_link_null_refit_multistart.md) exists because a single-start
# constrained refit can stall in a bad local optimum relative to the unconstrained full fit, inflating
# the parametric-bootstrap/likelihood-ratio statistic and producing an anti-conservative p-value at the
# true null -- "same mechanism, same fix, as InferenceOrdinalStereotypeLogitRegr's null-refit" per the
# source's own comment. A codebase-wide grep confirmed zero test references anywhere for this specific
# multi-start selection mechanic: the class is included in the generic parametric-bootstrap-LR smoke
# test (test-parametric-bootstrap-lr-all-capable-classes.R), which only confirms this code path runs
# without erroring, never that it actually picks the better of the two starts. The sibling
# simulate_under_lik_null()'s OWN copy of this same fit_null (used by the parametric-bootstrap path
# rather than the direct LR test) has the identical mechanism and is deliberately left untested here to
# keep this file focused; get_likelihood_test_spec()'s copy is exercised directly since it needs no
# extra plumbing to reach. Exercised by mocking fast_ordinal_cloglog_regression_cpp() to return
# controlled, distinguishable neg_loglik values for each of the two starting points (identified by
# call order), independent of any real optimization landscape.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", seed = seed, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(rnorm(n) + 0.3 * w, breaks = c(-Inf, -0.5, 0.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalCloglogRegr$new(des, model_formula = ~x1, verbose = FALSE)
	inf$compute_estimate()
	inf$.__enclos_env__$private$get_likelihood_test_spec()
}

test_that("when the second (nudged-full-fit) start converges to the lower neg_loglik, its fit is returned, not the first start's", {
	spec <- fx(1L)
	call_n <- 0L
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(params = rep(0, length(warm_start_params)), neg_loglik = 100) else list(params = rep(1, length(warm_start_params)), neg_loglik = 50)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 50)
	expect_equal(call_n, 2L)  # both starts are always tried
})

test_that("when the first (caller-supplied/warm-started) start converges to the lower neg_loglik, its fit is returned instead", {
	spec <- fx(2L)
	call_n <- 0L
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) list(params = rep(9, length(warm_start_params)), neg_loglik = 10) else list(params = rep(1, length(warm_start_params)), neg_loglik = 999)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 10)
})

test_that("when one start errors/fails, the other's (successful) fit is used", {
	spec <- fx(3L)
	call_n <- 0L
	local_mocked_bindings(
		fast_ordinal_cloglog_regression_cpp = function(X, y, fixed_idx, fixed_values, warm_start_params, warm_start_fisher_info = NULL, smart_cold_start = TRUE) {
			call_n <<- call_n + 1L
			if (call_n == 1L) stop("optimizer failure") else list(params = rep(2, length(warm_start_params)), neg_loglik = 77)
		},
		.package = "EDI"
	)
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 77)
})

test_that("when both starts fail, fit_null returns NULL", {
	spec <- fx(4L)
	local_mocked_bindings(fast_ordinal_cloglog_regression_cpp = function(...) NULL, .package = "EDI")
	expect_null(spec$fit_null(0.3))
})
