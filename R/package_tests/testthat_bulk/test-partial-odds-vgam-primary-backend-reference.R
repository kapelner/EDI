library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's primary/default backend cascade
# (fit_partial_proportional_odds_from_covariates()), used whenever `nonparallel`
# is non-empty, dispatches directly to VGAM::vglm(cumulative(parallel=...)) --
# never the fast Rcpp solver or the MASS::polr fallback. This was previously
# only smoke-tested for finiteness (test-ordinal-superiority-and-model-contracts.R);
# the existing fallback-cascade reference test (test-partial-odds-backend-fallback-reference.R)
# deliberately disables VGAM/clm to force the MASS::polr fallback path instead,
# so the true default path's values were never checked against an independent
# reference. Uses a binary nonparallel covariate (not continuous) because a
# continuous nonparallel covariate on 4 ordinal categories readily produces
# intersecting/crossing linear predictors here, an inherent instability of the
# partial-PO model unrelated to any EDI defect.

ppo_vgam_fixture <- function(seed = 2026091801L, n = 150L) {
	skip_if_not_installed("VGAM")
	set.seed(seed)
	x1 <- rbinom(n, 1, 0.5)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	lin <- 0.3 * w + 0.5 * x1
	thresh <- c(-1, 0.5, 1.6)
	p <- plogis(outer(lin, thresh, "-"))
	u <- runif(n)
	y <- 1L + rowSums(u > p)
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(
		des, model_formula = ~x1, nonparallel = "x1", verbose = FALSE
	)
	private <- inf$.__enclos_env__$private
	private$current_bayesian_bootstrap_context <- private$build_bayesian_bootstrap_context()
	list(inf = inf, private = private, y = y, w = w, x1 = x1, n = n)
}

ppo_vgam_reference <- function(y, w, x1, weights = NULL) {
	dat <- data.frame(y = ordered(y, levels = sort(unique(y))), treatment = w, x1 = x1)
	mod <- if (is.null(weights)) {
		VGAM::vglm(
			y ~ treatment + x1,
			family = VGAM::cumulative(link = "logitlink", parallel = ~treatment),
			data = dat, trace = FALSE, model = FALSE
		)
	} else {
		dat$.wt__ <- weights
		VGAM::vglm(
			y ~ treatment + x1,
			family = VGAM::cumulative(link = "logitlink", parallel = ~treatment),
			data = dat, weights = .wt__, trace = FALSE, model = FALSE
		)
	}
	beta <- VGAM::Coef(mod)[["treatment"]]
	se <- suppressWarnings(sqrt(VGAM::vcov(mod)["treatment", "treatment"]))
	list(beta = beta, se = se)
}

test_that("unweighted VGAM primary backend matches an independent vglm fit exactly", {
	fixture <- ppo_vgam_fixture()
	ref <- suppressWarnings(ppo_vgam_reference(fixture$y, fixture$w, fixture$x1))

	actual_est <- suppressWarnings(fixture$inf$compute_estimate())
	expect_equal(actual_est, ref$beta, tolerance = 1e-6)

	df <- fixture$n - 1L
	alpha <- 0.1
	tcrit <- qt(1 - alpha / 2, df)
	expected_ci <- stats::setNames(
		ref$beta + c(-1, 1) * tcrit * ref$se,
		paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%")
	)
	expect_equal(
		suppressWarnings(fixture$inf$compute_asymp_confidence_interval(alpha = alpha)),
		expected_ci, tolerance = 1e-4
	)

	expected_pval <- 2 * pt(-abs(ref$beta / ref$se), df)
	expect_equal(
		suppressWarnings(fixture$inf$compute_asymp_two_sided_pval()),
		expected_pval, tolerance = 1e-4
	)

	# Wald aliases are identical to the asymp methods.
	expect_equal(
		suppressWarnings(fixture$inf$compute_wald_confidence_interval(alpha = alpha)),
		expected_ci, tolerance = 1e-4
	)
	expect_equal(
		suppressWarnings(fixture$inf$compute_wald_two_sided_pval()),
		expected_pval, tolerance = 1e-4
	)
})

test_that("weighted VGAM primary backend matches an independent weighted vglm fit and drops the SE", {
	fixture <- ppo_vgam_fixture()
	set.seed(5)
	weights <- runif(fixture$n, 0.5, 2)

	actual_w <- suppressWarnings(
		fixture$inf$compute_estimate_with_bootstrap_weights(weights)
	)
	ref_w <- suppressWarnings(
		ppo_vgam_reference(fixture$y, fixture$w, fixture$x1, weights = weights)
	)
	expect_equal(actual_w, ref_w$beta, tolerance = 1e-6)
	# Documented contract: the weighted path never computes a standard error.
	expect_true(is.na(fixture$private$cached_values$s_beta_hat_T))
})

test_that("effectively-constant bootstrap weights short-circuit to the unweighted estimate", {
	fixture <- ppo_vgam_fixture()
	unweighted <- suppressWarnings(fixture$inf$compute_estimate(estimate_only = TRUE))
	const_weighted <- suppressWarnings(
		fixture$inf$compute_estimate_with_bootstrap_weights(rep(3, fixture$n))
	)
	expect_identical(const_weighted, unweighted)
	# Scaling the constant doesn't change the shortcut result either.
	const_weighted_scaled <- suppressWarnings(
		fixture$inf$compute_estimate_with_bootstrap_weights(rep(7.5, fixture$n))
	)
	expect_identical(const_weighted_scaled, unweighted)
})
