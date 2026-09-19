library(testthat)
library(EDI)

# inference_ordinal_gcomp.R's delta-method sandwich path (private$shared()'s
# finite-difference gradient of the proportional-odds standardization through
# fast_ordinal_regression_with_var_cpp's fitted vcov) and its bootstrap-fallback
# branch (private$has_finite_md_se()) were previously only smoke-tested
# (test-ordinal-gcomp-and-conditional-setup-contracts.R checks compute_estimate/
# compute_asymp_confidence_interval/compute_asymp_two_sided_pval return finite,
# self-consistent values, with no independent numerical reference and no
# coverage of the fallback branch or the weighted-bootstrap-replicate path).

ordinal_gcomp_asymp_fixture <- function(seed) {
	withr::local_seed(seed, .local_envir = parent.frame())
	n <- 80L
	x1 <- rnorm(n)
	trt <- rep(0:1, n / 2L)
	eta <- 0.8 * trt + 0.5 * x1
	y <- as.integer(cut(qlogis(runif(n)) + eta, breaks = c(-Inf, -1, 0, 1, Inf), labels = 1:4, ordered_result = TRUE))
	des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(trt)
	des$add_all_subject_responses(y)
	list(inf = InferenceOrdinalGCompMeanDiff$new(des, model_formula = ~ x1, verbose = FALSE), x1 = x1, trt = trt)
}

# Independent reimplementation of gcomp_ordinal_proportional_odds_post_fit_cpp's
# documented standardization formula (mean_k = 1 + sum_{j<K}(1 - plogis(alpha_j - eta))),
# fit via MASS::polr (an entirely separate proportional-odds implementation) rather
# than the package's own fast_ordinal_regression_with_var_cpp.
ordinal_gcomp_md_from_theta <- function(beta, zeta, X_fit, j_treat = 1L) {
	eta_base <- as.numeric(X_fit %*% beta) - beta[j_treat] * X_fit[, j_treat]
	eta1 <- eta_base + beta[j_treat]
	eta0 <- eta_base
	mean_score <- function(eta) mean(1 + vapply(eta, function(e) sum(1 - plogis(zeta - e)), numeric(1)))
	list(mean1 = mean_score(eta1), mean0 = mean_score(eta0), md = mean_score(eta1) - mean_score(eta0))
}

test_that("delta-method estimate/SE match an independent MASS::polr fit and finite-difference gradient", {
	skip_if_not_installed("MASS")
	f <- ordinal_gcomp_asymp_fixture(2026)
	est <- f$inf$compute_estimate()
	se <- f$inf$.__enclos_env__$private$get_standard_error()

	fit <- MASS::polr(ordered(f$inf$.__enclos_env__$private$y) ~ f$trt + f$x1, method = "logistic", Hess = TRUE)
	beta <- coef(fit); zeta <- fit$zeta
	X_fit <- cbind(trt = f$trt, x1 = f$x1)
	ref_md <- ordinal_gcomp_md_from_theta(beta, zeta, X_fit)$md

	theta <- c(beta, zeta)
	grad <- numeric(length(theta))
	for (j in seq_along(theta)) {
		step <- max(1e-6, 1e-6 * (1 + abs(theta[j])))
		tp <- theta; tp[j] <- tp[j] + step
		tm <- theta; tm[j] <- tm[j] - step
		md_p <- ordinal_gcomp_md_from_theta(tp[1:2], tp[3:5], X_fit)$md
		md_m <- ordinal_gcomp_md_from_theta(tm[1:2], tm[3:5], X_fit)$md
		grad[j] <- (md_p - md_m) / (2 * step)
	}
	ref_se <- sqrt(as.numeric(t(grad) %*% vcov(fit) %*% grad))

	expect_equal(est, ref_md, tolerance = 5e-3)
	expect_equal(se, ref_se, tolerance = 5e-3)

	z <- qnorm(0.95)
	expect_equal(unname(f$inf$compute_asymp_confidence_interval(alpha = 0.1)), est + c(-1, 1) * z * se, tolerance = 1e-8)
	expect_equal(f$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(est / se)), tolerance = 1e-8)

	# The Wald methods are documented as identical aliases of the asymp ones.
	expect_identical(f$inf$compute_wald_confidence_interval(alpha = 0.1), f$inf$compute_asymp_confidence_interval(alpha = 0.1))
	expect_identical(f$inf$compute_wald_two_sided_pval(), f$inf$compute_asymp_two_sided_pval())

	expect_error(f$inf$compute_asymp_confidence_interval(alpha = 0), "alpha")
})

test_that("a non-finite delta-method SE falls back to the exact bootstrap CI/p-value, with a warning", {
	f <- ordinal_gcomp_asymp_fixture(42)
	f$inf$compute_estimate()
	priv <- f$inf$.__enclos_env__$private
	priv$cached_values$se_md <- NA_real_
	priv$cached_values$s_beta_hat_T <- NA_real_

	expect_warning(
		ci <- f$inf$compute_asymp_confidence_interval(alpha = 0.2),
		"falling back to bootstrap"
	)
	set.seed(999)
	expected_ci <- f$inf$compute_bootstrap_confidence_interval(alpha = 0.2, na.rm = TRUE)
	set.seed(999)
	actual_ci <- suppressWarnings(f$inf$compute_asymp_confidence_interval(alpha = 0.2))
	expect_equal(actual_ci, expected_ci)

	set.seed(1)
	expected_pval <- f$inf$compute_bootstrap_two_sided_pval(na.rm = TRUE)
	set.seed(1)
	actual_pval <- suppressWarnings(f$inf$compute_asymp_two_sided_pval())
	expect_equal(actual_pval, expected_pval)
})

test_that("bootstrap-weighted replicates run side-effect-free and reproduce the unweighted estimate under unit weights", {
	f <- ordinal_gcomp_asymp_fixture(2026)
	est_before <- f$inf$compute_estimate()
	priv <- f$inf$.__enclos_env__$private
	md_before <- priv$cached_values$md
	se_before <- priv$cached_values$se_md
	warm_before <- priv$fit_warm_start
	cols_before <- priv$best_X_colnames

	boot <- f$inf$approximate_bootstrap_distribution_beta_hat_T(B = 5, show_progress = FALSE)
	expect_length(boot, 5L)
	expect_true(all(is.finite(boot)))

	expect_identical(priv$cached_values$md, md_before)
	expect_identical(priv$cached_values$se_md, se_before)
	expect_identical(priv$fit_warm_start, warm_before)
	expect_identical(priv$best_X_colnames, cols_before)
	expect_equal(f$inf$compute_estimate(), est_before)
})
