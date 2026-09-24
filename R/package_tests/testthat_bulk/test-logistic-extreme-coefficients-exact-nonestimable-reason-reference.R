library(testthat)
library(EDI)

# InferenceIncidLogRegr's extreme-coefficient nonestimable guards ("logistic_regression_extreme_
# coefficients" in generate_mod(), and "logistic_regression_weighted_extreme_coefficients" in
# compute_estimate_with_bootstrap_weights()) already have thorough BOOLEAN coverage -- is_nonestimable(
# "estimate") is asserted TRUE for a perfectly-separated fit in both the harden = TRUE and harden = FALSE
# paths (test-logistic-harden-false-extreme-coef-and-weighted-fit-reference.R) -- but the EXACT cached
# reason STRING was never asserted anywhere (confirmed via a zero-hit grep for both literal strings).
# Reaching the unweighted class's own specific reason through the public API is not possible: generate_
# mod()'s own guard is immediately overwritten by the shared generate_mod()-wrapping InferenceAsympLik
# StdModCache mixin's more generic "model_fit_unavailable" once it observes generate_mod() returned NULL
# -- the same "reason gets clobbered by an outer wrapper" situation this suite has already documented for
# InferenceIncidLogBinomial (test-log-binomial-fit-unavailable-guards-reference.R). Calling private$
# generate_mod() directly (bypassing the outer wrapper, the same technique used there) observes the
# specific reason before it's overwritten. The weighted refit's reason is NOT clobbered and is directly
# observable through the public API.
#   1. generate_mod()'s own specific reason ("logistic_regression_extreme_coefficients") is observable
#      by calling it directly, in both the harden = TRUE and harden = FALSE branches; through the public
#      API the same failure surfaces as the generic "model_fit_unavailable".
#   2. compute_estimate_with_bootstrap_weights()'s own specific reason ("logistic_regression_weighted_
#      extreme_coefficients") is directly observable through the public weighted-refit state.

separated_fixture <- function(harden, max_abs = 5, n = 80L, seed = 2L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(w == 1)                                                          # perfectly separated by treatment
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, harden = harden, max_abs_reasonable_coef = max_abs, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, n = n)
}

test_that("generate_mod()'s own specific reason is observable directly, in both harden branches, before the outer wrapper clobbers it", {
	for (harden in c(FALSE, TRUE)) {
		f <- separated_fixture(harden)
		res <- f$priv$generate_mod(estimate_only = TRUE)
		expect_null(res, info = harden)
		expect_identical(f$inf$get_nonestimable_reason(), "logistic_regression_extreme_coefficients", info = harden)

		f2 <- separated_fixture(harden)
		expect_true(is.na(f2$inf$compute_estimate()))
		expect_identical(f2$inf$get_nonestimable_reason(), "model_fit_unavailable", info = harden)
	}
})

test_that("compute_estimate_with_bootstrap_weights()'s own specific weighted-refit reason is directly observable", {
	f <- separated_fixture(TRUE)
	priv <- f$priv
	priv$current_bayesian_bootstrap_context <- list(
		row_to_unit = seq_len(f$n), unit_group_id = rep(1L, f$n), n_units = f$n
	)
	res <- f$inf$compute_estimate_with_bootstrap_weights(rep(1, f$n))
	expect_true(is.na(res))
	expect_identical(priv$last_weighted_refit$nonestimable_reason, "logistic_regression_weighted_extreme_coefficients")
	expect_true(priv$weighted_refit_is_nonestimable("estimate"))
})
