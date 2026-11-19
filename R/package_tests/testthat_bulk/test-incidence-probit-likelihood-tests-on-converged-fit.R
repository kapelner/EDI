library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-ddb2d8dbd (InferenceIncidProbitRegr):
# likelihood_tier "full" -- Wald, score, gradient and likelihood-ratio tests are
# all available on a converged fit; the LR p-value matches glm's deviance test.

test_that("probit: on a converged fit score, gradient and LR p-values are finite and supported; LR matches anova(glm)", {
	set.seed(11); n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.2 * w))

	expect_identical(get_inference_class_metadata("InferenceIncidProbitRegr")$likelihood_tier, "full")
	inf <- InferenceIncidProbitRegr$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate()))
	expect_true(all(c("wald", "score", "gradient", "lik_ratio") %in% inf$get_supported_testing_types()))
	for (tt in c("score", "gradient", "lik_ratio")) {
		p <- inf[[paste0("compute_", tt, "_two_sided_pval")]]()
		expect_true(is.finite(p) && p > 0 && p <= 1, info = tt)
	}
	dat <- data.frame(y = des$get_y(), w = w, X)
	g1 <- glm(y ~ w + x1 + x2, family = binomial("probit"), data = dat)
	g0 <- glm(y ~ x1 + x2, family = binomial("probit"), data = dat)
	lrt <- anova(g0, g1, test = "LRT")[2, "Pr(>Chi)"]
	expect_equal(inf$compute_lik_ratio_two_sided_pval(), lrt, tolerance = 1e-5)
	# and set_testing_type("lik_ratio") dispatches the asymptotic p-value to it
	inf2 <- InferenceIncidProbitRegr$new(des, verbose = FALSE)
	inf2$set_testing_type("lik_ratio")
	expect_equal(inf2$compute_asymp_two_sided_pval(), lrt, tolerance = 1e-5)
})
