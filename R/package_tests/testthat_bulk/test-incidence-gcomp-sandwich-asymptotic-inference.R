library(testthat)
library(EDI)

# inference_incidence_gcomp_abstract.R's dominant untested surface is the full
# (estimate_only = FALSE) sandwich-covariance/delta-method path: shared(),
# fit_logistic_with_sandwich(), compute_standardized_effects_r() and the
# public compute_estimate/get_standard_error/compute_asymp_confidence_interval/
# compute_wald_two_sided_pval contracts built on them. Existing coverage
# (test-incidence-gcomp-weighted-risk-difference-reference.R) only exercises
# the estimate_only = TRUE bootstrap-weights point-estimate path, which
# explicitly skips this covariance machinery (see the class's own docs).

gcomp_asymp_fixture <- function(generator, seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 60L
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- rbinom(n, 1, plogis(-0.3 + 0.7 * w + 0.5 * x))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	list(inf = generator$new(des, model_formula = ~ x, verbose = FALSE), X = cbind("(Intercept)" = 1, treatment = w, x = x), y = y, n = n)
}

gcomp_hc0_sandwich_reference <- function(fixture) {
	fit <- glm.fit(fixture$X, fixture$y, family = binomial())
	b <- fit$coefficients
	mu <- fitted(fit)
	bread <- solve(t(fixture$X) %*% diag(mu * (1 - mu)) %*% fixture$X)
	meat <- t(fixture$X) %*% diag((fixture$y - mu)^2) %*% fixture$X
	vcov <- bread %*% meat %*% bread
	X1 <- fixture$X; X1[, 2] <- 1
	X0 <- fixture$X; X0[, 2] <- 0
	risk1_i <- plogis(X1 %*% b); risk0_i <- plogis(X0 %*% b)
	risk1 <- mean(risk1_i); risk0 <- mean(risk0_i)
	grad1 <- as.numeric(crossprod(X1, risk1_i * (1 - risk1_i))) / fixture$n
	grad0 <- as.numeric(crossprod(X0, risk0_i * (1 - risk0_i))) / fixture$n
	grad_rd <- grad1 - grad0
	se_rd <- sqrt(as.numeric(t(grad_rd) %*% vcov %*% grad_rd))
	grad_log_rr <- grad1 / risk1 - grad0 / risk0
	se_log_rr <- sqrt(as.numeric(t(grad_log_rr) %*% vcov %*% grad_log_rr))
	list(rd = risk1 - risk0, se_rd = se_rd, rr = risk1 / risk0, se_log_rr = se_log_rr)
}

test_that("risk-difference sandwich estimate/SE/CI/p-value match an independent HC0-sandwich delta-method reference", {
	f <- gcomp_asymp_fixture(InferenceIncidGCompRiskDiff, 99)
	ref <- gcomp_hc0_sandwich_reference(f)
	est <- f$inf$compute_estimate(estimate_only = FALSE)
	se <- f$inf$get_standard_error()
	expect_equal(est, ref$rd, tolerance = 1e-7)
	expect_equal(se, ref$se_rd, tolerance = 1e-7)
	z <- qnorm(0.975)
	expect_equal(unname(f$inf$compute_asymp_confidence_interval(0.05)), ref$rd + c(-1, 1) * z * ref$se_rd, tolerance = 1e-6)
	expect_equal(f$inf$compute_wald_two_sided_pval(0), 2 * pnorm(-abs(ref$rd / ref$se_rd)), tolerance = 1e-7)
	# A nonzero null shifts the Wald statistic accordingly.
	expect_equal(f$inf$compute_wald_two_sided_pval(0.1), 2 * pnorm(-abs((ref$rd - 0.1) / ref$se_rd)), tolerance = 1e-7)
})

test_that("risk-ratio sandwich estimate/SE/CI/p-value match an independent log-scale delta-method reference", {
	f <- gcomp_asymp_fixture(InferenceIncidGCompRiskRatio, 99)
	ref <- gcomp_hc0_sandwich_reference(f)
	est <- f$inf$compute_estimate(estimate_only = FALSE)
	se <- f$inf$get_standard_error()
	expect_equal(est, ref$rr, tolerance = 1e-7)
	expect_equal(se, ref$rr * ref$se_log_rr, tolerance = 1e-6)
	z <- qnorm(0.975)
	expect_equal(unname(f$inf$compute_asymp_confidence_interval(0.05)),
		exp(log(ref$rr) + c(-1, 1) * z * ref$se_log_rr), tolerance = 1e-6)
	expect_equal(f$inf$compute_wald_two_sided_pval(1), 2 * pnorm(-abs(log(ref$rr) / ref$se_log_rr)), tolerance = 1e-7)
	# compute_asymp_two_sided_pval is documented to share the same contract as compute_wald_two_sided_pval.
	expect_equal(f$inf$compute_asymp_two_sided_pval(1), f$inf$compute_wald_two_sided_pval(1))
	# RR delta must be strictly positive.
	expect_error(f$inf$compute_wald_two_sided_pval(delta = -1), "strictly positive")
	expect_error(f$inf$compute_wald_two_sided_pval(delta = 0), "strictly positive")
})

test_that("degenerate cached standard errors leave the asymptotic CI/p-value non-estimable rather than erroring", {
	f <- gcomp_asymp_fixture(InferenceIncidGCompRiskDiff, 101)
	f$inf$compute_estimate(estimate_only = FALSE)
	priv <- f$inf$.__enclos_env__$private
	priv$cached_values$se_rd <- 0
	expect_true(all(is.na(f$inf$compute_asymp_confidence_interval(0.05))))
	priv$cached_values$se_rd <- NA_real_
	expect_true(is.na(f$inf$compute_wald_two_sided_pval(0)))
})

test_that("prob_clip_eps is validated to [0, 0.5) at construction", {
	withr::local_seed(42)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, n / 2))
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	expect_error(InferenceIncidGCompRiskDiff$new(des, prob_clip_eps = 0.5000001), "not <= 0.5")
	expect_silent(InferenceIncidGCompRiskDiff$new(des, prob_clip_eps = 0.5, verbose = FALSE))
	expect_error(InferenceIncidGCompRiskDiff$new(des, prob_clip_eps = -0.1), "not >= 0")
	expect_silent(InferenceIncidGCompRiskDiff$new(des, prob_clip_eps = 0.499, verbose = FALSE))
})

test_that("risk-ratio basic-bootstrap CI reproduces the log-scale reflection formula from its own bootstrap draws", {
	f <- gcomp_asymp_fixture(InferenceIncidGCompRiskRatio, 5)
	f$inf$compute_estimate(estimate_only = FALSE)
	est <- f$inf$compute_estimate(estimate_only = TRUE)
	withr::local_seed(777)
	boot <- as.numeric(f$inf$approximate_bootstrap_distribution_beta_hat_T(B = 15, show_progress = FALSE))
	q <- stats::quantile(log(boot), probs = c(0.975, 0.025), names = FALSE, type = 8)
	expected_ci <- exp(2 * log(est) - q)

	f2 <- gcomp_asymp_fixture(InferenceIncidGCompRiskRatio, 5)
	withr::local_seed(777)
	actual_ci <- f2$inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "basic", show_progress = FALSE)
	expect_equal(unname(actual_ci), expected_ci, tolerance = 1e-8)
})

test_that("risk-difference bootstrap CI ignores the RR-only basic-CI override and uses the shared base-class path", {
	f <- gcomp_asymp_fixture(InferenceIncidGCompRiskDiff, 5)
	withr::local_seed(2024)
	ci <- f$inf$compute_bootstrap_confidence_interval(alpha = 0.05, B = 15, type = "basic", show_progress = FALSE)
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], ci[2])
})
