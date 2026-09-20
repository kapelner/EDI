library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's compute_estimate_with_bootstrap_weights()
# (IncidenceBinomialIdentityLikelihoodSource, inference_incidence_binomial_identity.R)
# is only ever called with unit weights in R/EDI/tests/testthat/test-bayesian-bootstrap.R,
# checked solely for finiteness -- never against an independent reference under
# genuinely varying weights. Unlike the sibling InferenceIncidModifiedPoisson class,
# this class *does* compute a real weighted-fit SE (see the fit_fun's
# !estimate_only branch), so this file checks that SE too, not just the point
# estimate.

binomial_identity_fixture <- function() {
	withr::local_seed(20260918, .local_envir = parent.frame())
	n <- 150L
	w <- rep(0:1, n / 2)
	x1 <- rnorm(n, sd = 0.4)
	y <- rbinom(n, 1, pmin(pmax(0.3 + 0.15 * w + 0.1 * x1, 0.02), 0.98))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	list(des = des, X = cbind("(Intercept)" = 1, treatment = w, x1 = x1), y = y, n = n)
}

make_binomial_identity_inf <- function(f) {
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(f$des, model_formula = ~x1, verbose = FALSE)
	inf$.__enclos_env__$private$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n
	)
	inf
}

weighted_binomial_identity_reference <- function(f, weights) {
	fit <- suppressWarnings(glm.fit(f$X, f$y, weights = weights, family = binomial(link = "identity"), start = c(0.5, 0, 0)))
	se <- sqrt(diag(summary.glm(fit)$cov.unscaled * summary.glm(fit)$dispersion))
	list(est = unname(fit$coefficients[2]), se = unname(se[2]))
}

test_that("weighted-bootstrap refit matches an independent weighted identity-link binomial glm.fit", {
	f <- binomial_identity_fixture()
	weights <- runif(f$n, 0.4, 2.0)
	ref <- weighted_binomial_identity_reference(f, weights)
	inf <- make_binomial_identity_inf(f)
	est <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	se <- inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T
	expect_equal(as.numeric(est), ref$est, tolerance = 1e-5)
	expect_equal(se, ref$se, tolerance = 1e-5)
})

test_that("unit weights reproduce compute_estimate()'s point estimate", {
	f <- binomial_identity_fixture()
	inf_weighted <- make_binomial_identity_inf(f)
	weighted_est <- inf_weighted$compute_estimate_with_bootstrap_weights(rep(1, f$n), estimate_only = FALSE)
	inf_direct <- InferenceIncidBinomialIdentityRiskDiff$new(f$des, model_formula = ~x1, verbose = FALSE)
	direct_est <- inf_direct$compute_estimate(estimate_only = FALSE)
	expect_equal(as.numeric(weighted_est), as.numeric(direct_est), tolerance = 1e-8)
})

test_that("estimate_only = TRUE skips the SE computation", {
	f <- binomial_identity_fixture()
	inf <- make_binomial_identity_inf(f)
	inf$compute_estimate_with_bootstrap_weights(runif(f$n, 0.5, 1.5), estimate_only = TRUE)
	expect_true(is.na(inf$.__enclos_env__$private$last_weighted_refit$s_beta_hat_T))
})

test_that("the weighted-fit estimate is invariant to a common weight scale factor", {
	f <- binomial_identity_fixture()
	weights <- runif(f$n, 0.5, 1.5)
	inf1 <- make_binomial_identity_inf(f)
	est1 <- inf1$compute_estimate_with_bootstrap_weights(weights, estimate_only = FALSE)
	inf2 <- make_binomial_identity_inf(f)
	est2 <- inf2$compute_estimate_with_bootstrap_weights(5 * weights, estimate_only = FALSE)
	expect_equal(as.numeric(est1), as.numeric(est2), tolerance = 1e-6)
})
