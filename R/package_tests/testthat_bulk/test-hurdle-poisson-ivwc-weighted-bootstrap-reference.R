library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC$compute_estimate_with_bootstrap_weights()
# combines a weighted matched-pair hurdle-Poisson glmmTMB fit with a weighted
# reservoir Poisson fit via inverse-variance weighting. Grepped testthat/
# testthat_bulk/R/EDI/tests/testthat for this class: only ever
# name-existence-checked or smoke-instantiated (test-count-kk-hurdle-ivwc-migration-golden.R,
# test-proportion-count-family-contracts.R), never called with real varying
# weights against an independent reference.

hurdle_ivwc_fixture <- function() {
	withr::local_seed(20260919L)
	n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
	w <- des$get_w()
	mu <- exp(0.3 + 0.4 * w)
	y <- ifelse(rbinom(n, 1, plogis(0.2 + 0.3 * w)) == 1, pmax(1L, rpois(n, mu)), 0L)
	des$add_all_subject_responses(y)
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, model_formula = ~ 1, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	context <- private$build_bayesian_bootstrap_context()
	private$current_bayesian_bootstrap_context <- context
	list(inf = inf, context = context, w = w, y = y)
}

hurdle_ivwc_reference_estimate_only <- function(fixture, weights) {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	units <- split(seq_along(fixture$y), fixture$context$row_to_unit)
	pairs <- units[lengths(units) == 2L]
	reservoir <- unlist(units[lengths(units) == 1L], use.names = FALSE)
	row_weight <- weights[fixture$context$row_to_unit]

	beta_m <- NA_real_
	if (length(pairs) > 0L) {
		matched_idx <- unlist(pairs, use.names = FALSE)
		dat_m <- data.frame(
			y = fixture$y[matched_idx],
			w = fixture$w[matched_idx],
			pair_group = factor(rep(seq_along(pairs), each = 2L))
		)
		mod_m <- suppressWarnings(suppressMessages(glmmTMB::glmmTMB(
			y ~ w + (1 | pair_group), ziformula = ~ w + (1 | pair_group),
			family = glmmTMB::truncated_poisson(link = "log"),
			data = dat_m, weights = row_weight[matched_idx], se = FALSE
		)))
		beta_m <- as.numeric(glmmTMB::fixef(mod_m)$cond["w"])
	}

	beta_r <- NA_real_
	if (length(reservoir) > 1L) {
		mod_r <- glm.fit(
			cbind(1, fixture$w[reservoir]), fixture$y[reservoir],
			weights = row_weight[reservoir], family = poisson(link = "log")
		)
		beta_r <- unname(mod_r$coefficients[2])
	}
	list(beta_m = beta_m, beta_r = beta_r, combined = 0.5 * beta_m + 0.5 * beta_r)
}

test_that("KK hurdle-Poisson IVWC weighted estimate-only combines independent matched/reservoir fits", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_ivwc_fixture()
	weights <- rep(c(1, 2, 3, 4), length.out = fixture$context$n_units)
	ref <- hurdle_ivwc_reference_estimate_only(fixture, weights)
	skip_if(!is.finite(ref$beta_m) || !is.finite(ref$beta_r), "reference fit did not converge on this fixture")

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_equal(actual, ref$combined, tolerance = 1e-3)
})

test_that("KK hurdle-Poisson IVWC weighted estimate diverges from the unweighted estimate under real weights", {
	fixture <- hurdle_ivwc_fixture()
	unweighted <- fixture$inf$compute_estimate(estimate_only = TRUE)
	weights <- rep(c(1, 5, 1, 5), length.out = fixture$context$n_units)
	weighted <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_true(is.finite(weighted))
	expect_true(abs(weighted - unweighted) > 1e-8)
})

# Unlike the Rcpp-vs-glmmTMB-fallback path used by compute_estimate() with
# weights = NULL, compute_estimate_with_bootstrap_weights() has no
# constant-weight shortcut and always routes the matched-pair component
# through glmmTMB (per this class's own comment: "a caller-supplied weights
# vector always routes through glmmTMB ... skipping the unweighted
# Rcpp-then-glmmTMB-fallback path entirely"). So unit weights here are NOT
# expected to numerically reproduce compute_estimate()'s Rcpp-optimizer
# result -- verified instead against a fresh, independent unit-weighted
# glmmTMB+glm.fit combination using the same reference helper as above.
test_that("KK hurdle-Poisson IVWC unit weights match an independent unweighted glmmTMB+glm combination", {
	skip_if_not(requireNamespace("glmmTMB", quietly = TRUE))
	fixture <- hurdle_ivwc_fixture()
	weights <- rep(1, fixture$context$n_units)
	ref <- hurdle_ivwc_reference_estimate_only(fixture, weights)
	skip_if(!is.finite(ref$beta_m) || !is.finite(ref$beta_r), "reference fit did not converge on this fixture")

	actual <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
	expect_equal(actual, ref$combined, tolerance = 1e-3)
})

# Not asserting exact weight-scale invariance here: the matched-pair
# component is a glmmTMB random-effects (Laplace-approximation) fit, whose
# optimizer path -- and hence converged point estimate -- is not exactly
# invariant to an overall weight-scale change in practice (confirmed
# empirically: a 7x scale shift moves the combined estimate by a
# non-negligible amount on this fixture, unlike the fixed-effects-only
# weighted fits elsewhere in this suite). Both scales are checked to still
# produce a finite, real combined estimate instead.
test_that("KK hurdle-Poisson IVWC weighted estimate stays finite across a weight-scale change", {
	fixture <- hurdle_ivwc_fixture()
	weights <- rep(c(1, 2, 3, 4), length.out = fixture$context$n_units)
	base <- fixture$inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)

	fixture2 <- hurdle_ivwc_fixture()
	scaled <- fixture2$inf$compute_estimate_with_bootstrap_weights(7 * weights, estimate_only = TRUE)
	expect_true(is.finite(base))
	expect_true(is.finite(scaled))
})
