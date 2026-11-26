library(testthat)
library(EDI)

# v1.0.6-TODO-161 (2): in InferenceIncidBinomialIdentityRiskDiff, InferenceIncidLogBinomial, InferenceContinKKGLMM and
# InferenceCountKKGLMM, private$get_standard_error() (used by compute_wald_*(), the Wald fallback, CI-inversion seeds
# and InferenceSuite's se column) came from the likelihood-test spec's information, while compute_asymp_*() used the
# fit's own Wald SE: identity 0.0825 vs 0.0935, log-binomial 0.305 vs 0.339, Contin KK GLMM 0.2170 vs 0.2077 (sigma_b
# near 0), Count KK GLMM 0.236 vs 0.187 (the jackknife-raised SE vs the model SE). Now every path uses the Wald SE:
# expected information X'WX for the two binomial classes (glm()'s convention, owner decision 2026-11-19), the full
# observed Hessian for the Gaussian LMM, and max(model, jackknife) for the Poisson GLMM.

se_paths_bern_design <- function(seed, n = 80L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	x1 <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, pmin(0.9, 0.3 * exp(0.3 * x1))))
	des
}

se_paths_kk_design <- function(response_type, seed, n = 60L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		y_i <- if (response_type == "continuous") 0.6 * w_i + 0.3 * X$x1[i] + rnorm(1L, sd = 0.8)
			else rpois(1L, exp(0.5 + 0.3 * w_i + 0.2 * X$x1[i]))
		des$add_one_subject_response(i, y_i)
	}
	des
}

se_paths_all_agree <- function(inf, info) {
	priv <- inf$.__enclos_env__$private
	z <- stats::qnorm(0.975)
	se_asymp <- unname(diff(inf$compute_asymp_confidence_interval(0.05))) / (2 * z)
	se_wald <- unname(diff(inf$compute_wald_confidence_interval(0.05))) / (2 * z)
	se_priv <- priv$get_standard_error()
	expect_true(is.finite(se_priv) && se_priv > 0, info = info)
	expect_equal(se_priv, priv$cached_values$s_beta_hat_T, tolerance = 1e-12, info = info)
	expect_equal(se_asymp, se_priv, tolerance = 1e-10, info = info)
	expect_equal(se_wald, se_priv, tolerance = 1e-10, info = info)
	expect_equal(inf$compute_wald_two_sided_pval(0), inf$compute_asymp_two_sided_pval(0), tolerance = 1e-10, info = info)
	se_priv
}

test_that("identity- and log-binomial SE paths all give the expected-information Wald SE", {
	for (cls in list(InferenceIncidBinomialIdentityRiskDiff, InferenceIncidLogBinomial)) for (seed in 1:3) {
		inf <- cls$new(se_paths_bern_design(seed), verbose = FALSE)
		info <- paste(cls$classname, seed)
		se <- suppressWarnings(se_paths_all_agree(inf, info), classes = "edi_binomial_mle_boundary_warning")
		priv <- inf$.__enclos_env__$private
		mod <- priv$cached_mod
		j <- mod$j_treat %||% 2L
		# glm()'s convention: inverse expected information X'WX of the fit
		expect_equal(se, sqrt(solve(mod$fisher_information)[j, j]), tolerance = 1e-8, info = info)
		# ... which is not the observed information the score test uses (the old get_standard_error() value)
		se_observed <- priv$compute_standard_error_from_information_matrix()
		expect_gt(abs(se / se_observed - 1), 1e-3)
	}
})

test_that("Gaussian KK GLMM SE paths all give the full observed-Hessian Wald SE", {
	for (seed in 1:3) {
		inf <- InferenceContinKKGLMM$new(se_paths_kk_design("continuous", seed), verbose = FALSE)
		se <- se_paths_all_agree(inf, paste("contin", seed))
		fit <- inf$.__enclos_env__$private$cached_mod
		expect_equal(se, sqrt(fit$ssq_b_T), tolerance = 1e-10)
	}
})

test_that("Poisson KK GLMM SE paths all give the jackknife-raised Wald SE", {
	for (seed in 1:3) {
		inf <- InferenceCountKKGLMM$new(se_paths_kk_design("count", seed), verbose = FALSE)
		se <- se_paths_all_agree(inf, paste("count", seed))
		priv <- inf$.__enclos_env__$private
		se_model <- sqrt(priv$cached_mod$ssq_b_T)
		expect_gte(se, se_model * (1 - 1e-12))
		if (identical(priv$cached_values$s_beta_hat_T_source, "jackknife")) {
			expect_equal(priv$cached_values$s_beta_hat_T_model, se_model, tolerance = 1e-10)
		}
	}
})
