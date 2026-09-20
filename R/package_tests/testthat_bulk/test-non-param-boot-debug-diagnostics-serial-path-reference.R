library(testthat)
library(EDI)

# approximate_bootstrap_distribution_beta_hat_T(debug = TRUE) (serial, cores = 1):
# diagnostic list contract, agreement of the debug values with the plain path under
# the same seed, cache bypass-then-store, and per-replicate error/warning capture
# via a stubbed replicate estimator.

mk <- function(seed = 11L, n = 24L) {
	set.seed(3)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE, seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w * 0.7 + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	inf
}

test_that("debug output has the documented fields with consistent lengths and proportions", {
	inf <- mk()
	B <- 12L
	d <- inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE, debug = TRUE)
	expect_named(d, c("values", "errors", "warnings", "num_errors", "num_warnings",
		"prop_iterations_with_errors", "prop_iterations_with_warnings", "prop_illegal_values"))
	expect_length(d$values, B)
	expect_length(d$errors, B)
	expect_length(d$warnings, B)
	expect_equal(d$num_errors, lengths(d$errors))
	expect_equal(d$num_warnings, lengths(d$warnings))
	expect_equal(d$prop_iterations_with_errors, mean(d$num_errors > 0))
	expect_equal(d$prop_illegal_values, mean(!is.finite(d$values)))
	expect_equal(d$prop_illegal_values, 0)
})

test_that("with a fixed seed the debug values equal the plain distribution and populate the cache", {
	plain <- mk()$approximate_bootstrap_distribution_beta_hat_T(B = 10L, show_progress = FALSE)
	inf <- mk()
	d <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 10L, show_progress = FALSE, debug = TRUE)
	expect_equal(d$values, as.numeric(plain))
	# The cache now holds those values; a plain call returns them without recomputation.
	priv <- inf$.__enclos_env__$private
	expect_equal(as.numeric(priv$get_cached_resampling_distribution("non_param_boot", "10")), d$values)
	expect_equal(as.numeric(inf$approximate_bootstrap_distribution_beta_hat_T(B = 10L, show_progress = FALSE)), d$values)
})

test_that("debug = TRUE ignores an existing cached entry", {
	inf <- mk()
	priv <- inf$.__enclos_env__$private
	priv$set_cached_resampling_distribution("non_param_boot", "8", rep(999, 8))
	d <- inf$approximate_bootstrap_distribution_beta_hat_T(B = 8L, show_progress = FALSE, debug = TRUE)
	expect_false(any(d$values == 999))
})

test_that("replicate errors and warnings are captured per draw, and failures become NA illegal values", {
	inf <- mk()
	priv <- inf$.__enclos_env__$private
	calls <- 0L
	unlockBinding("use_reusable_bootstrap_worker", priv)
	priv$use_reusable_bootstrap_worker <- function() FALSE
	unlockBinding("bootstrap_subset_inference", priv)
	priv$bootstrap_subset_inference <- function(boot_draw, smooth = FALSE) {
		calls <<- calls + 1L
		k <- calls
		list(compute_estimate = function(estimate_only = TRUE) {
			if (k %% 3L == 0L) stop("boom ", k)
			if (k %% 3L == 1L) warning("careful ", k)
			as.numeric(k)
		})
	}
	B <- 6L
	d <- inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE, debug = TRUE)
	expect_equal(d$num_errors, c(0L, 0L, 1L, 0L, 0L, 1L))
	expect_equal(d$num_warnings, c(1L, 0L, 0L, 1L, 0L, 0L))
	expect_match(d$errors[[3]], "boom 3")
	expect_match(d$warnings[[4]], "careful 4")
	expect_true(all(is.na(d$values[c(3, 6)])))
	expect_equal(d$values[c(1, 2, 4, 5)], c(1, 2, 4, 5))
	expect_equal(d$prop_illegal_values, 2 / 6)
	expect_equal(d$prop_iterations_with_errors, 2 / 6)
	expect_equal(d$prop_iterations_with_warnings, 2 / 6)
})
