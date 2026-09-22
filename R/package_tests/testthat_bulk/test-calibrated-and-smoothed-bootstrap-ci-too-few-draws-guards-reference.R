library(testthat)
library(EDI)

# inference_all_abstract_non_param_boot.R's ci_calibrated_bootstrap()/ci_smoothed_bootstrap() each
# re-draw their own outer bootstrap distribution independently of compute_bootstrap_confidence_
# interval()'s own earlier boot_distr length check (the two calls are separate, uncorrelated draws
# of size B), so a small B that clears the outer dispatcher's min_number_usable_samples floor but
# sits below these two helpers' own hardcoded "< 10L finite draws" floor reaches each helper's own
# guard deterministically: "Calibrated bootstrap CI returned too few finite bootstrap draws." /
# "Smoothed bootstrap CI returned too few finite bootstrap draws." Both had zero test references
# anywhere despite being reachable through the public compute_bootstrap_confidence_interval(type =
# "calibrated"/"smoothed") on an unhardened (harden = FALSE) object, whose enclosing tryCatch
# re-throws rather than swallowing the error when harden = FALSE.

fx <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	InferenceContinLin$new(d, harden = FALSE, verbose = FALSE)
}

test_that("ci_calibrated_bootstrap(): B below the internal 10-draw floor errors with the documented message", {
	inf <- fx(seed = 1L)
	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "calibrated", B = 6L, min_number_usable_samples = 5L, show_progress = FALSE),
		"Calibrated bootstrap CI returned too few finite bootstrap draws\\."
	)
})

test_that("ci_smoothed_bootstrap(): B below the internal 10-draw floor errors with the documented message", {
	inf <- fx(seed = 2L)
	expect_error(
		inf$compute_bootstrap_confidence_interval(type = "smoothed", B = 6L, min_number_usable_samples = 5L, show_progress = FALSE),
		"Smoothed bootstrap CI returned too few finite bootstrap draws\\."
	)
})

test_that("with a normal B, both calibrated and smoothed bootstrap CIs succeed", {
	inf <- fx(seed = 3L, n = 40L)
	ci_cal <- inf$compute_bootstrap_confidence_interval(type = "calibrated", B = 60L, show_progress = FALSE)
	expect_length(ci_cal, 2L)
	expect_true(all(is.finite(ci_cal)))

	inf2 <- fx(seed = 4L, n = 40L)
	ci_sm <- inf2$compute_bootstrap_confidence_interval(type = "smoothed", B = 60L, show_progress = FALSE)
	expect_length(ci_sm, 2L)
	expect_true(all(is.finite(ci_sm)))
})
