library(testthat)
library(EDI)

# InferencePropGCompMeanDiff's compute_asymp_confidence_interval()/compute_asymp_two_sided_pval()
# (inference_proportion_gcomp.R) each wrap their real computation in a tryCatch: any error surfacing
# from compute_effect_confidence_interval()/compute_effect_pvalue() is converted to a warning
# ("G-computation mean difference: <original error message>") plus an NA return (c(NA_real_, NA_real_)
# for the CI, NA_real_ for the p-value), rather than propagating the raw error. A codebase-wide grep
# confirmed this exact warning message had zero test references anywhere -- the class's existing
# asymptotic-inference reference file (test-proportion-gcomp-sandwich-asymptotic-inference.R) covers
# a "degenerate cached standard error" nonestimable-CACHING path (a different, deliberate mechanism),
# never this raw error-to-warning-and-NA conversion. Reached by stubbing the two underlying private
# computation methods directly to force an arbitrary error, independent of any real numerical failure
# mode of the g-computation fit itself (already tested elsewhere).

prop_gcomp_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(0:1, n / 2)
	y <- plogis(-0.3 + 0.7 * w + 0.5 * x + rnorm(n, sd = 0.3))
	des <- DesignFixedBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	InferencePropGCompMeanDiff$new(des, model_formula = ~ x, verbose = FALSE)
}

test_that("an error from compute_effect_confidence_interval() is caught, warned about with the documented prefix, and returns c(NA, NA)", {
	inf <- prop_gcomp_fixture(1L)
	priv <- inf$.__enclos_env__$private
	unlockBinding("compute_effect_confidence_interval", priv)
	priv$compute_effect_confidence_interval <- function(alpha) stop("forced failure")

	expect_warning(
		ci <- inf$compute_asymp_confidence_interval(),
		"G-computation mean difference: forced failure",
		fixed = TRUE
	)
	expect_true(all(is.na(ci)))
})

test_that("an error from compute_effect_pvalue() is caught, warned about with the documented prefix, and returns NA", {
	inf <- prop_gcomp_fixture(2L)
	priv <- inf$.__enclos_env__$private
	unlockBinding("compute_effect_pvalue", priv)
	priv$compute_effect_pvalue <- function(delta) stop("forced failure2")

	expect_warning(
		pv <- inf$compute_asymp_two_sided_pval(),
		"G-computation mean difference: forced failure2",
		fixed = TRUE
	)
	expect_true(is.na(pv))
})

test_that("a well-behaved fit never triggers either warning", {
	inf <- prop_gcomp_fixture(3L)
	expect_no_warning(inf$compute_asymp_confidence_interval())
	expect_no_warning(inf$compute_asymp_two_sided_pval())
})
