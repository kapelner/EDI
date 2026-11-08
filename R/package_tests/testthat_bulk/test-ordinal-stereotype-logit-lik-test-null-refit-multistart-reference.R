library(testthat)
library(EDI)

# InferenceOrdinalStereotypeLogitRegr's get_likelihood_test_spec()$fit_null(delta) tries several
# starting points for the delta-constrained null refit and keeps whichever converges to the lower
# neg_loglik (originally two: the caller-supplied/warm-started point and a nudged full fit; since
# TODO-175 only deterministic data-only starts -- see the tests below). This is the ORIGINAL multi-start fix this session's
# InferenceOrdinalCloglogRegr fix explicitly cites as its own precedent ("same mechanism, same fix, as
# InferenceOrdinalStereotypeLogitRegr's null-refit"), and per its own comment is high-impact: a
# single-start constrained refit spuriously marked the null refit unusable and returned NA for
# compute_lik_ratio_two_sided_pval() on ~2/3 of real fits (200/300 in a direct reproduction) before the
# fix. Despite this severity, a codebase-wide grep confirmed zero test references anywhere for the
# multi-start SELECTION mechanic itself: the class is exercised in the generic parametric-bootstrap-LR
# smoke test and several other reference files, but none of them mock the underlying kernel to verify
# fit_null() actually picks the better of its two starts (as opposed to merely running without
# erroring). Exercised via the same technique as the cloglog sibling: mocking fast_stereotype_logit_cpp()
# to return controlled, distinguishable neg_loglik values per call, independent of any real optimization
# landscape. (stereotype_fit_is_usable()'s own guards are already covered elsewhere; called here with
# check_treatment = FALSE, require_information_pd = FALSE exactly as fit_null() does, so a converged
# mock fit with no fisher_information field passes it trivially.)

# seed 4 hits InferenceOrdinalStereotypeLogitRegr's documented multimodal-
# likelihood convergence gap (every multistart candidate's Fisher
# information ends up singular; see the matching fix/comment in
# test-ordinal-stereotype-logit-randomization-estimate-refit-reference.R
# and test-ordinal-cloglog-stereotype-simulate-under-lik-null-fit-null-
# multistart-reference.R), so compute_estimate() returns NA and
# get_likelihood_test_spec() returns NULL here -- seed 1 converges cleanly
# for this exact fixture.
fx <- function(seed = 1L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~x, verbose = FALSE)
	inf$compute_estimate()
	inf$.__enclos_env__$private$get_likelihood_test_spec()
}

# TODO-175 (2026-11-07): fit_null() ignores `start` (the warm-start chain's
# previous null fit) and the object's warm Fisher; it tries deterministic,
# data-only starts in a fixed order -- the nudged full fit with beta_T = delta,
# a cold start, the adjacent-category two-stage start, then the full-data
# multistart offsets -- and a later start wins only on a neg_loglik improvement
# > 1e-6. The mock records each constrained refit's start; the two-stage
# start's first stage (loadings fixed too, length(fixed_idx) > 1) is answered
# separately.
mock_null_kernel <- function(nll_for_call, log_env) {
	function(X, y, fixed_idx = NULL, fixed_values = NULL, warm_start_params = NULL, warm_start_fisher_info = NULL, smart_cold_start = TRUE, estimate_only = FALSE, ...) {
		if (length(fixed_idx) > 1L) return(list(converged = TRUE, params = rep(0.5, 6L), neg_loglik = 1e6))
		log_env$n <- log_env$n + 1L
		log_env$starts[[log_env$n]] <- warm_start_params
		log_env$fishers[[log_env$n]] <- warm_start_fisher_info
		nll <- nll_for_call(log_env$n)
		if (is.na(nll)) return(list(converged = FALSE))
		list(converged = TRUE, params = rep(log_env$n, 6L), neg_loglik = nll)
	}
}

test_that("all deterministic starts are tried in order and the lowest neg_loglik wins", {
	spec <- fx()
	log_env <- new.env(); log_env$n <- 0L; log_env$starts <- list(); log_env$fishers <- list()
	local_mocked_bindings(fast_stereotype_logit_cpp = mock_null_kernel(function(k) if (k == 4L) 50 else 100, log_env), .package = "EDI")
	res <- spec$fit_null(0.3)
	expect_equal(res$neg_loglik, 50)
	expect_equal(res$params, rep(4, 6L))
	expect_gte(log_env$n, 4L)
	full_start <- as.numeric(spec$full_fit$params) + 1e-3
	full_start[spec$j] <- 0.3
	expect_equal(log_env$starts[[1L]], full_start)  # first: the nudged full fit at delta
	expect_null(log_env$starts[[2L]])              # second: cold
	expect_true(all(vapply(log_env$fishers, is.null, logical(1))))
})

test_that("ties keep the first start (improvement must exceed 1e-6)", {
	spec <- fx()
	log_env <- new.env(); log_env$n <- 0L; log_env$starts <- list(); log_env$fishers <- list()
	local_mocked_bindings(fast_stereotype_logit_cpp = mock_null_kernel(function(k) if (k == 1L) 10 else 10 - 5e-7, log_env), .package = "EDI")
	expect_equal(spec$fit_null(0.3)$params, rep(1, 6L))
})

test_that("`start` and the object's warm start are ignored (no history dependence)", {
	f_spec <- fx()
	log_env <- new.env(); log_env$n <- 0L; log_env$starts <- list(); log_env$fishers <- list()
	local_mocked_bindings(fast_stereotype_logit_cpp = mock_null_kernel(function(k) 100 - k, log_env), .package = "EDI")
	a <- f_spec$fit_null(0.3)
	starts_a <- log_env$starts
	log_env$n <- 0L; log_env$starts <- list()
	b <- f_spec$fit_null(0.3, start = rep(7, length(f_spec$full_fit$params)))
	expect_identical(a, b)
	expect_identical(log_env$starts, starts_a)
})

test_that("when some starts don't converge, the best successful fit is used", {
	spec <- fx()
	log_env <- new.env(); log_env$n <- 0L; log_env$starts <- list(); log_env$fishers <- list()
	local_mocked_bindings(fast_stereotype_logit_cpp = mock_null_kernel(function(k) if (k == 3L) 77 else NA, log_env), .package = "EDI")
	expect_equal(spec$fit_null(0.3)$neg_loglik, 77)
})

test_that("when no start converges, fit_null returns NULL", {
	spec <- fx()
	local_mocked_bindings(fast_stereotype_logit_cpp = function(...) list(converged = FALSE), .package = "EDI")
	expect_null(spec$fit_null(0.3))
})
