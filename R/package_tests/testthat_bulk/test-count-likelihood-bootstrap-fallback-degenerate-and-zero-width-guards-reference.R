library(testthat)
library(EDI)

# CountLikelihoodPlumbing's missing interval, and the removal of its bootstrap
# fallback (v1.0.6-TODO-380). count_bootstrap_fallback_ci() / _pval() used to give
# the zero-augmented classes' Wald path a bootstrap interval / p-value when the
# asymptotic SE was unavailable (with degenerate-fit and zero-width guards). A Wald
# request now gets the Wald result or NA (edi_wald_unavailable_na()), so the
# helpers and their guards are gone; test-zero-inflated-poisson-asymp-se-fallback-
# branches-reference.R covers the NA path.

mk <- function() {
	set.seed(5)
	n <- 60L
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rpois(n, exp(0.3 + 0.4 * w)))
	inf <- InferenceCountPoisson$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$cached_values$beta_hat_T <- 0.4
	list(inf = inf, p = p)
}

test_that("the missing interval is NA with quantile-percent names for the given alpha", {
	f <- mk()
	ci <- f$p$count_likelihood_missing_ci(0.1)
	expect_equal(unname(ci), c(NA_real_, NA_real_))
	expect_equal(names(ci), c("5%", "95%"))
	expect_equal(names(f$p$count_likelihood_missing_ci()), c("2.5%", "97.5%"))
})

test_that("the bootstrap-fallback helpers no longer exist (v1.0.6-TODO-380)", {
	f <- mk()
	expect_false(exists("count_bootstrap_fallback_ci", envir = f$p, inherits = FALSE))
	expect_false(exists("count_bootstrap_fallback_pval", envir = f$p, inherits = FALSE))
})
