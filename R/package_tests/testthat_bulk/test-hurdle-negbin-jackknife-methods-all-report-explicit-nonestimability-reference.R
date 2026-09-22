library(testthat)
library(EDI)

# InferenceCountHurdleNegBin's five compute_jackknife_*() overrides (estimate, bias_estimate, std_error,
# wald_two_sided_pval, wald_confidence_interval): the class's own documentation states delete-one refits of
# this two-part jointly-estimated-dispersion model are numerically unstable, so every one of these always
# short-circuits to NA and flags "hurdle_negbin_jackknife_not_supported" -- never attempting a refit. This
# behavior was previously only asserted indirectly, via a registry exclusion-list test confirming jackknife
# is NOT offered for this class name; no test ever actually called these five methods on a real instance.

fx <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w(); y <- rnbinom(n, mu = exp(0.5 + 0.4 * w + 0.3 * X$x1), size = 2)
	d$add_all_subject_responses(y)
	InferenceCountHurdleNegBin$new(d, verbose = FALSE)
}

test_that("every jackknife method returns NA (or an all-NA CI) and flags the same explicit non-estimability reason, without attempting a refit", {
	inf <- fx()
	expect_true(is.na(inf$compute_jackknife_estimate()))
	expect_identical(inf$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")
	expect_true(inf$is_nonestimable("se"))

	inf2 <- fx()
	expect_true(is.na(inf2$compute_jackknife_bias_estimate()))
	expect_identical(inf2$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")

	inf3 <- fx()
	expect_true(is.na(inf3$compute_jackknife_std_error()))
	expect_identical(inf3$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")

	inf4 <- fx()
	expect_true(is.na(inf4$compute_jackknife_wald_two_sided_pval(delta = 0.5)))
	expect_identical(inf4$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")

	inf5 <- fx()
	ci <- inf5$compute_jackknife_wald_confidence_interval(alpha = 0.1)
	expect_true(all(is.na(ci)))
	expect_identical(names(ci), c("5%", "95%"))
	expect_identical(inf5$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")
})

test_that("the alpha argument controls the returned CI's percentage labels even though the bounds are always NA", {
	inf <- fx()
	ci <- inf$compute_jackknife_wald_confidence_interval(alpha = 0.2)
	expect_identical(names(ci), c("10%", "90%"))
	expect_true(all(is.na(ci)))
})

test_that("the jackknife methods report non-estimability independently of any prior successful compute_estimate() call", {
	inf <- fx()
	est <- inf$compute_estimate()
	skip_if(!is.finite(est), "fixture's ordinary fit did not converge on this platform")
	expect_false(inf$is_nonestimable("any"))                          # the real fit succeeded
	expect_true(is.na(inf$compute_jackknife_estimate()))              # jackknife is still refused regardless
	expect_identical(inf$get_nonestimable_reason(), "hurdle_negbin_jackknife_not_supported")
})
