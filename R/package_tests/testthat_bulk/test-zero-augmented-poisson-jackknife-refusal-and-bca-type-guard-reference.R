library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract (composed by InferenceCountZeroInflatedPoisson/InferenceCountHurdlePoisson)
# reuses the SAME "zero_augmented_poisson_jackknife_not_supported" reason string for two distinct purposes, neither
# previously exercised by any test: (1) five trivial compute_jackknife_*() overrides that always report NA/non-
# estimable (delete-one refits are documented as too unstable for this mixture model); (2) a type = "bca" guard on
# FOUR otherwise-delegating bootstrap methods (compute_bootstrap_two_sided_pval/_confidence_interval and their
# Bayesian-bootstrap counterparts) -- BCa needs a jackknife acceleration constant this class cannot supply, so it
# is refused with the same reason, while every OTHER bootstrap type (percentile, basic, ...) still delegates
# normally to the real nonparametric/Bayesian bootstrap machinery.

fx <- function(seed = 4L, n = 60L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w(); zi <- rbinom(n, 1, 0.3); y <- ifelse(zi == 1, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.2 * X$x1)))
	d$add_all_subject_responses(y)
	InferenceCountZeroInflatedPoisson$new(d, verbose = FALSE)
}

test_that("every jackknife method returns NA (or an all-NA CI) and flags the shared non-estimability reason", {
	inf <- fx()
	expect_true(is.na(inf$compute_jackknife_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf2 <- fx()
	expect_true(is.na(inf2$compute_jackknife_bias_estimate()))
	expect_identical(inf2$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf3 <- fx()
	expect_true(is.na(inf3$compute_jackknife_std_error()))
	expect_identical(inf3$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf4 <- fx()
	expect_true(is.na(inf4$compute_jackknife_wald_two_sided_pval(delta = 0.3)))
	expect_identical(inf4$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf5 <- fx()
	ci <- inf5$compute_jackknife_wald_confidence_interval(alpha = 0.1)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf5$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")
})

test_that("type = 'bca' is refused with the same reason on all four (Bayesian-)bootstrap CI/p-value entry points", {
	inf <- fx()
	pv <- inf$compute_bootstrap_two_sided_pval(delta = 0, type = "bca", B = 20, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf2 <- fx()
	ci <- inf2$compute_bootstrap_confidence_interval(alpha = 0.05, type = "bca", B = 20, show_progress = FALSE)
	expect_true(all(is.na(ci)))
	expect_identical(inf2$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf3 <- fx()
	pv3 <- inf3$compute_bayesian_bootstrap_two_sided_pval(delta = 0, type = "bca", B = 20, show_progress = FALSE)
	expect_true(is.na(pv3))
	expect_identical(inf3$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	inf4 <- fx()
	ci4 <- inf4$compute_bayesian_bootstrap_confidence_interval(alpha = 0.05, type = "bca", B = 20, show_progress = FALSE)
	expect_true(all(is.na(ci4)))
	expect_identical(inf4$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")

	# case-insensitive: "BCA" is refused too
	inf5 <- fx()
	pv5 <- inf5$compute_bootstrap_two_sided_pval(delta = 0, type = "BCA", B = 20, show_progress = FALSE)
	expect_true(is.na(pv5))
	expect_identical(inf5$get_nonestimable_reason(), "zero_augmented_poisson_jackknife_not_supported")
})

test_that("every OTHER bootstrap type still delegates normally instead of being refused", {
	inf <- fx()
	pv <- inf$compute_bootstrap_two_sided_pval(delta = 0, type = "percentile", B = 30, show_progress = FALSE)
	expect_true(is.finite(pv))
	expect_false(inf$is_nonestimable("any"))

	inf2 <- fx()
	pv_default <- inf2$compute_bootstrap_two_sided_pval(delta = 0, B = 30, show_progress = FALSE)      # type = NULL default
	expect_true(is.finite(pv_default))
	expect_false(inf2$is_nonestimable("any"))
})
