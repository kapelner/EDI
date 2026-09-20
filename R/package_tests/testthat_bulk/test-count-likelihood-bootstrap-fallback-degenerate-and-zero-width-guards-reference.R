library(testthat)
library(EDI)

# count_bootstrap_fallback_ci() / count_bootstrap_fallback_pval() (CountLikelihoodPlumbing):
# a degenerate fit short-circuits to an all-NA interval (named by the alpha/2 quantile
# labels) or NA p-value; otherwise the bootstrap results pass through, except a
# finite bootstrap CI narrower than sqrt(eps) * max(1, |estimate|) is declared
# non-estimable. Bootstrap methods are stubbed so the guard logic is isolated.

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
stub_public <- function(inf, name, fn) {
	if (bindingIsLocked(name, inf)) unlockBinding(name, inf)
	inf[[name]] <- fn
}

test_that("the missing interval is NA with quantile-percent names for the given alpha", {
	f <- mk()
	ci <- f$p$count_likelihood_missing_ci(0.1)
	expect_equal(unname(ci), c(NA_real_, NA_real_))
	expect_equal(names(ci), c("5%", "95%"))
	expect_equal(names(f$p$count_likelihood_missing_ci()), c("2.5%", "97.5%"))
})

test_that("a degenerate fit skips the bootstrap entirely (CI -> NA, p-value -> NA)", {
	f <- mk()
	f$p$cached_values$fit_degenerate <- TRUE
	called <- 0L
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) { called <<- called + 1L; c(1, 2) })
	stub_public(f$inf, "compute_bootstrap_two_sided_pval", function(delta = 0, na.rm = FALSE) { called <<- called + 1L; 0.5 })
	expect_equal(unname(f$p$count_bootstrap_fallback_ci(0.05)), c(NA_real_, NA_real_))
	expect_true(is.na(f$p$count_bootstrap_fallback_pval()))
	expect_equal(called, 0L)
})

test_that("a non-degenerate fit passes a normal-width bootstrap CI and the p-value (with na.rm = TRUE) through", {
	f <- mk()
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) c(`2.5%` = 0.1, `97.5%` = 0.7))
	seen <- NULL
	stub_public(f$inf, "compute_bootstrap_two_sided_pval", function(delta = 0, na.rm = FALSE) { seen <<- list(delta = delta, na.rm = na.rm); 0.031 })
	expect_equal(f$p$count_bootstrap_fallback_ci(0.05), c(`2.5%` = 0.1, `97.5%` = 0.7))
	expect_equal(f$p$count_bootstrap_fallback_pval(delta = 0.25), 0.031)
	expect_equal(seen, list(delta = 0.25, na.rm = TRUE))
})

test_that("a finite zero-width bootstrap CI is treated as non-estimable; the width threshold scales with |estimate|", {
	f <- mk()
	tiny <- sqrt(.Machine$double.eps)
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) c(0.4, 0.4))
	expect_equal(unname(f$p$count_bootstrap_fallback_ci()), c(NA_real_, NA_real_))
	# Just above the threshold for |est| <= 1 (width 2 * tiny > tiny * 1) is kept.
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) c(0.4, 0.4 + 2 * tiny))
	expect_equal(unname(f$p$count_bootstrap_fallback_ci()), c(0.4, 0.4 + 2 * tiny))
	# With a large estimate the same width is under the scaled threshold and is rejected.
	f$p$cached_values$beta_hat_T <- 1000
	expect_equal(unname(f$p$count_bootstrap_fallback_ci()), c(NA_real_, NA_real_))
})

test_that("non-finite or wrong-length bootstrap intervals are returned untouched", {
	f <- mk()
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) c(NA_real_, NA_real_))
	expect_equal(unname(f$p$count_bootstrap_fallback_ci()), c(NA_real_, NA_real_))
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05) 0.3)
	expect_equal(f$p$count_bootstrap_fallback_ci(), 0.3)
})
