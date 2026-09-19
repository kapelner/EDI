library(testthat)
library(EDI)

# inference_proportion_gcomp.R's dominant untested surface is the full
# (estimate_only = FALSE) sandwich-covariance/delta-method path: shared(),
# fit_fractional_logit_with_sandwich(), compute_standardized_effects_r() and the
# public compute_estimate/get_standard_error/compute_asymp_confidence_interval/
# compute_wald_two_sided_pval contracts built on them, plus the 8-strategy
# variance_fallback_methods cascade and the estimate_only harden=FALSE fast path.
# Existing coverage (test-proportion-gcomp-weighted-standardization-reference.R)
# only exercises the estimate_only = TRUE bootstrap-weights point-estimate path,
# which explicitly skips this covariance machinery.

prop_gcomp_asymp_fixture <- function(seed, ...) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 60L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- plogis(-0.3 + 0.7 * w + 0.5 * x + rnorm(n, sd = 0.3))
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	list(inf = InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE, ...),
		X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

# Same HC0 sandwich/delta-method formula as the analogous incidence g-comp
# reference (bread = (X'WX)^-1 with W = mu(1-mu), meat = X' diag((y-mu)^2) X;
# see gcomp_speedups.cpp's compute_gcomp_logistic_post_fit, shared by both the
# binary and fractional-logit exports) -- the formula does not depend on y
# being binary, only on the fitted mu.
prop_gcomp_hc0_sandwich_reference <- function(fixture) {
	fit <- glm.fit(fixture$X, fixture$y, family = quasibinomial())
	b <- fit$coefficients
	mu <- fitted(fit)
	bread <- solve(t(fixture$X) %*% diag(mu * (1 - mu)) %*% fixture$X)
	meat <- t(fixture$X) %*% diag((fixture$y - mu)^2) %*% fixture$X
	vcov <- bread %*% meat %*% bread
	X1 <- fixture$X; X1[, 2] <- 1
	X0 <- fixture$X; X0[, 2] <- 0
	mean1_i <- plogis(X1 %*% b); mean0_i <- plogis(X0 %*% b)
	mean1 <- mean(mean1_i); mean0 <- mean(mean0_i)
	grad1 <- as.numeric(crossprod(X1, mean1_i * (1 - mean1_i))) / fixture$n
	grad0 <- as.numeric(crossprod(X0, mean0_i * (1 - mean0_i))) / fixture$n
	grad_md <- grad1 - grad0
	se_md <- sqrt(as.numeric(t(grad_md) %*% vcov %*% grad_md))
	list(md = mean1 - mean0, se_md = se_md)
}

test_that("mean-difference sandwich estimate/SE/CI/p-value match an independent HC0-sandwich delta-method reference", {
	f <- prop_gcomp_asymp_fixture(99)
	ref <- prop_gcomp_hc0_sandwich_reference(f)
	est <- f$inf$compute_estimate(estimate_only = FALSE)
	se <- f$inf$get_standard_error()
	expect_equal(est, ref$md, tolerance = 1e-7)
	expect_equal(se, ref$se_md, tolerance = 1e-7)
	z <- qnorm(0.975)
	expect_equal(unname(f$inf$compute_asymp_confidence_interval(0.05)), ref$md + c(-1, 1) * z * ref$se_md, tolerance = 1e-6)
	expect_equal(f$inf$compute_wald_two_sided_pval(0), 2 * pnorm(-abs(ref$md / ref$se_md)), tolerance = 1e-7)
	# compute_asymp_two_sided_pval is documented to share the same contract as compute_wald_two_sided_pval.
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), f$inf$compute_wald_two_sided_pval(0))
	# A nonzero null shifts the Wald statistic accordingly.
	expect_equal(f$inf$compute_wald_two_sided_pval(0.1), 2 * pnorm(-abs((ref$md - 0.1) / ref$se_md)), tolerance = 1e-7)
	expect_equal(unname(f$inf$compute_wald_confidence_interval(0.05)), unname(f$inf$compute_asymp_confidence_interval(0.05)))
})

test_that("degenerate cached standard error leaves the asymptotic CI/p-value non-estimable rather than erroring", {
	f <- prop_gcomp_asymp_fixture(101)
	f$inf$compute_estimate(estimate_only = FALSE)
	priv <- f$inf$.__enclos_env__$private
	priv$cached_values$se_md <- 0
	expect_true(all(is.na(f$inf$compute_asymp_confidence_interval(0.05))))
	priv$cached_values$se_md <- NA_real_
	expect_true(is.na(f$inf$compute_wald_two_sided_pval(0)))
})

test_that("prob_clip_eps and prob_clip_strong_eps are validated to [0, 0.5) at construction", {
	withr::local_seed(42)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, n / 2))
	des$add_all_subject_responses(plogis(rnorm(n)))
	expect_error(InferencePropGCompMeanDiff$new(des, prob_clip_eps = 0.5000001), "not <= 0.5")
	expect_silent(InferencePropGCompMeanDiff$new(des, prob_clip_eps = 0.5, verbose = FALSE))
	expect_error(InferencePropGCompMeanDiff$new(des, prob_clip_strong_eps = -0.1), "not >= 0")
	expect_silent(InferencePropGCompMeanDiff$new(des, prob_clip_strong_eps = 0.499, verbose = FALSE))
})

test_that("variance_fallback_methods is validated against the known strategy set at construction", {
	withr::local_seed(43)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, n / 2))
	des$add_all_subject_responses(plogis(rnorm(n)))
	expect_error(InferencePropGCompMeanDiff$new(des, variance_fallback_methods = "not_a_real_method"), "not_a_real_method|subset")
	expect_silent(InferencePropGCompMeanDiff$new(des, variance_fallback_methods = "model_based", verbose = FALSE))
	expect_silent(InferencePropGCompMeanDiff$new(des, variance_fallback_methods = character(0), verbose = FALSE))
})

test_that("an empty variance_fallback_methods list makes the full (estimate_only=FALSE) fit non-estimable, not just its variance", {
	# effects_are_usable() requires a finite, positive se_md for the non-estimate-only
	# path, so a fit with no computable variance is treated as an unusable fit
	# overall (point estimate included), not merely an NA variance around a
	# retained estimate -- despite the constructor docs describing this option as
	# only affecting variance ("always returns NA variance rather than erroring").
	# The estimate_only=TRUE path is unaffected since it never calls effects_are_usable
	# with a variance requirement.
	f <- prop_gcomp_asymp_fixture(99, variance_fallback_methods = character(0))
	est <- f$inf$compute_estimate(estimate_only = FALSE)
	expect_true(is.na(est))
	expect_true(is.na(f$inf$get_standard_error()))
	expect_true(all(is.na(f$inf$compute_asymp_confidence_interval(0.05))))
	expect_true(is.na(f$inf$compute_wald_two_sided_pval(0)))

	f2 <- prop_gcomp_asymp_fixture(99, variance_fallback_methods = character(0))
	ref <- prop_gcomp_hc0_sandwich_reference(f2)
	fast_est <- f2$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(fast_est, ref$md, tolerance = 1e-7)
})

test_that("model_based-only fallback matches an independent Fisher-information (non-robust) delta-method reference", {
	f <- prop_gcomp_asymp_fixture(99, variance_fallback_methods = "model_based")
	f$inf$compute_estimate(estimate_only = FALSE)
	actual_se <- f$inf$get_standard_error()

	fit <- glm.fit(f$X, f$y, family = quasibinomial())
	b <- fit$coefficients
	mu <- fitted(fit)
	info <- t(f$X) %*% diag(mu * (1 - mu)) %*% f$X
	vcov_model <- solve(info)
	X1 <- f$X; X1[, 2] <- 1
	X0 <- f$X; X0[, 2] <- 0
	mean1_i <- plogis(X1 %*% b); mean0_i <- plogis(X0 %*% b)
	grad1 <- as.numeric(crossprod(X1, mean1_i * (1 - mean1_i))) / f$n
	grad0 <- as.numeric(crossprod(X0, mean0_i * (1 - mean0_i))) / f$n
	grad_md <- grad1 - grad0
	expected_se <- sqrt(as.numeric(t(grad_md) %*% vcov_model %*% grad_md))

	expect_equal(actual_se, expected_se, tolerance = 1e-6)
	# The model-based (Fisher-information) SE differs from the robust sandwich SE
	# under the misspecified fractional-logit working model used to generate y.
	expect_false(isTRUE(all.equal(actual_se, prop_gcomp_hc0_sandwich_reference(f)$se_md, tolerance = 1e-6)))
})

test_that("estimate_only=TRUE with harden=FALSE uses the fast glm.fit-based path and matches the full estimate", {
	f <- prop_gcomp_asymp_fixture(2024, harden = FALSE)
	fast_est <- f$inf$compute_estimate(estimate_only = TRUE)
	ref <- prop_gcomp_hc0_sandwich_reference(f)
	expect_equal(fast_est, ref$md, tolerance = 1e-7)
	# se_md is explicitly left NA on this fast path.
	expect_true(is.na(f$inf$.__enclos_env__$private$cached_values$se_md))
})
