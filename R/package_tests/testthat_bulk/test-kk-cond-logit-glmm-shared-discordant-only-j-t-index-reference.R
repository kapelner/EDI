library(testthat)
library(EDI)

# InferenceAbstractKKCondLogitGLMM's shared() (inference_incidence_KK_cond_logit_glmm_abstract.R)
# picks the treatment-coefficient index into fast_clogit_plus_glmm_cpp()'s returned params based on
# has_concordant: j_T = 2L (par[1], after the intercept) when concordant/GLMM data is present, else
# j_T = 1L (par[0]) when the fit is discordant-only. test-kk-cond-logit-glmm-shared-nonestimable-
# guards-reference.R already exercises shared()'s 4 nonestimable-guard branches, but always with
# has_concordant = TRUE (a concordant-only mocked data block), so it only ever reaches the j_T = 2L
# path. test-kk-cond-logit-glmm-data-split-reference.R separately confirms has_concordant = FALSE
# occurs for all-discordant KK splits, but never carries that block through a REAL (unmocked)
# fast_clogit_plus_glmm_cpp() fit -- so the j_T = 1L branch's numeric correctness was never verified
# against an independent reference anywhere.
#
# When has_concordant = FALSE, the conditional-logit block alone determines the fit: X_disc's first
# column is a constant 1 (see prepare_clogit_plus_glmm_data()'s contract, confirmed in the data-split
# reference file), so beta_hat_T (par[0]) is exactly the intercept of an ordinary logistic regression
# of y_disc on the covariate differences, glm(y_disc ~ x_diff, family = binomial()) -- there is no
# random-intercept GLMM contribution at all in this branch. Reached by mocking
# prepare_clogit_plus_glmm_data() (real fast_clogit_plus_glmm_cpp() is NOT mocked) with a well-
# conditioned discordant-only data block built directly from a known logistic model, independently of
# any real KK design/matching mechanics (already covered elsewhere).

discordant_only_fixture <- function(seed, n_pairs = 25L, beta_T_true = 0.8, beta_x_true = 0.5) {
	set.seed(seed)
	x_diff <- rnorm(n_pairs)
	y_disc <- rbinom(n_pairs, 1, plogis(beta_T_true + beta_x_true * x_diff))
	X_disc <- cbind(treatment = 1, x1 = x_diff)

	des <- DesignSeqOneByOneKK14$new(n = 20L, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(20L))
	for (i in seq_len(20L)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(20L, 1, 0.4))
	inf <- InferenceIncidKKCondLogitGLMMIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("prepare_clogit_plus_glmm_data", priv)
	priv$prepare_clogit_plus_glmm_data <- function(...) list(
		has_discordant = TRUE, has_concordant = FALSE,
		X_disc = X_disc, y_disc = y_disc,
		X_conc = matrix(numeric(0), nrow = 0L, ncol = 2L), y_conc = numeric(0), group_conc = integer(0)
	)
	list(inf = inf, priv = priv, x_diff = x_diff, y_disc = y_disc)
}

test_that("has_concordant = FALSE: beta_hat_T (j_T = 1L) matches an independent glm(y_disc ~ x_diff, binomial()) intercept", {
	f <- discordant_only_fixture(1L)
	est <- f$inf$compute_estimate()
	expect_false(f$inf$is_nonestimable("estimate"))

	fit_ref <- glm(f$y_disc ~ f$x_diff, family = binomial())
	expect_equal(est, unname(coef(fit_ref)[1]), tolerance = 1e-4)
})

test_that("has_concordant = FALSE: s_beta_hat_T also matches the independent glm() reference's intercept standard error", {
	f <- discordant_only_fixture(2L)
	f$inf$compute_estimate()
	ci <- f$inf$compute_asymp_confidence_interval()
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)))

	fit_ref <- glm(f$y_disc ~ f$x_diff, family = binomial())
	se_ref <- summary(fit_ref)$coefficients[1, 2]
	expect_equal(f$priv$cached_values$s_beta_hat_T, se_ref, tolerance = 1e-3)
})

test_that("the likelihood_test_context records j_T = 1L for the discordant-only branch", {
	f <- discordant_only_fixture(3L)
	f$inf$compute_estimate()
	ctx <- f$priv$cached_values$likelihood_test_context
	expect_equal(ctx$j_T, 1L)
})
