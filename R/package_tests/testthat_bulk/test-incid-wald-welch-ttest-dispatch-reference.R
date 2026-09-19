library(testthat)
library(EDI)

# InferenceIncidWald's own doc-comment and private$get_standard_error() /
# compute_incidence_wald_components() describe the classical two-proportion
# unpooled Wald SE (sqrt(p_T(1-p_T)/n_T + p_C(1-p_C)/n_C)). Previously
# compute_asymp_confidence_interval()/compute_asymp_two_sided_pval() were
# actually supplied by the composed SimpleMeanDifference component (which
# uses Welch's unequal-variance t-test on the raw 0/1 responses), bypassing
# the class's own two-proportion formula entirely -- because
# SimpleMeanDifference is composed after Wald in this class's `components`
# list and neither method was pinned in the class's own public list. Fixed
# by explicitly pinning both methods to the Wald component's implementation
# (InferenceAsymp$public_methods$...) in inference_incid_wald.R. This file
# now pins down the real (Wald, two-proportion) behavior against an
# independent from-scratch reference.

make_wald_incidence_design <- function(n, p, seed) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(rbinom(n, 1, p))
	des
}

test_that("InferenceIncidWald's estimate is the simple mean difference", {
	des <- make_wald_incidence_design(40L, 0.4, 42L)
	w <- des$get_w()
	y <- des$get_y()
	expected <- mean(y[w == 1]) - mean(y[w == 0])
	inf <- InferenceIncidWald$new(des, verbose = FALSE)
	expect_equal(inf$compute_estimate(estimate_only = TRUE), expected, tolerance = 1e-12)
	expect_equal(inf$compute_estimate(), expected, tolerance = 1e-12)
})

test_that("InferenceIncidWald's CI/p-value dispatch to the documented two-proportion Wald formula (bug fixed)", {
	for (seed in c(42L, 7L, 99L)) {
		des <- make_wald_incidence_design(40L, 0.4, seed)
		w <- des$get_w()
		y <- des$get_y()

		p_t <- mean(y[w == 1])
		p_c <- mean(y[w == 0])
		n_t <- sum(w == 1)
		n_c <- sum(w == 0)
		est_ref <- p_t - p_c
		se_ref <- sqrt(p_t * (1 - p_t) / n_t + p_c * (1 - p_c) / n_c)
		alpha <- 0.05
		z <- qnorm(1 - alpha / 2)
		ci_ref <- c(est_ref - z * se_ref, est_ref + z * se_ref)
		z_stat <- est_ref / se_ref
		pval_ref <- 2 * pnorm(-abs(z_stat))

		inf <- InferenceIncidWald$new(des, verbose = FALSE)
		est <- inf$compute_estimate()
		ci <- inf$compute_asymp_confidence_interval(alpha = alpha)
		pval <- inf$compute_asymp_two_sided_pval()

		expect_equal(unname(est), est_ref, tolerance = 1e-10, info = as.character(seed))
		expect_equal(as.numeric(ci), as.numeric(ci_ref), tolerance = 1e-8, info = as.character(seed))
		expect_equal(pval, pval_ref, tolerance = 1e-10, info = as.character(seed))

		# The class's own two-proportion Wald SE is now genuinely populated by
		# the public CI/p-value dispatch.
		priv <- inf$.__enclos_env__$private
		expect_equal(priv$cached_values$incidence_wald_se, se_ref, tolerance = 1e-10, info = as.character(seed))
	}
})

test_that("InferenceIncidWald's own private two-proportion Wald SE formula, if invoked directly, matches an independent unpooled-proportion reference", {
	des <- make_wald_incidence_design(40L, 0.4, 42L)
	w <- des$get_w()
	y <- des$get_y()
	p_t <- mean(y[w == 1])
	p_c <- mean(y[w == 0])
	n_t <- sum(w == 1)
	n_c <- sum(w == 0)
	expected_se <- sqrt(p_t * (1 - p_t) / n_t + p_c * (1 - p_c) / n_c)

	inf <- InferenceIncidWald$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	inf$compute_estimate()
	# get_standard_error() is a private override reachable directly (it exists
	# and is well-defined even though nothing in the public API calls it).
	se_direct <- priv$get_standard_error()
	expect_equal(se_direct, expected_se, tolerance = 1e-10)
	expect_equal(priv$get_degrees_of_freedom(), NA_real_)
})

test_that("InferenceIncidWald is nonestimable when one arm has zero subjects", {
	des <- DesignFixediBCRD$new(n = 4L, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = 1:4))
	des$overwrite_all_subject_assignments(rep(1, 4))
	des$add_all_subject_responses(c(1, 0, 1, 1))
	inf <- InferenceIncidWald$new(des, verbose = FALSE)
	expect_true(is.na(inf$compute_estimate()))
})
