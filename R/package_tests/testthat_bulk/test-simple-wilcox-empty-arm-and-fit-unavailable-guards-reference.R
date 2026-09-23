library(testthat)
library(EDI)

# InferenceAllSimpleWilcox$shared() (inference_all_simple_wilcox.R) has two distinct nonestimable
# guards, neither of which had a test reference anywhere:
#   1. "wilcox_empty_treatment_arm": either arm is empty -- checked in both the estimate_only fast
#      path (hl_point_estimate) and the full (stats::wilcox.test) path.
#   2. "wilcox_fit_unavailable": stats::wilcox.test(conf.int = TRUE) itself errors.
# Branch 1 is reached by directly overwriting private$w to an all-treatment vector post-construction
# (unlockBinding, the same private-state-injection technique already used elsewhere in this suite);
# branch 2 is reached by mocking stats::wilcox.test to always fail.

test_that("an empty control arm is nonestimable ('wilcox_empty_treatment_arm'), in both estimate_only and full paths", {
	set.seed(1); n <- 20L
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	for (estimate_only in c(TRUE, FALSE)) {
		inf <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)
		p <- inf$.__enclos_env__$private
		unlockBinding("w", p)
		p$w <- rep(1, n)  # every subject "treated"; no control arm

		res <- if (estimate_only) inf$compute_estimate(estimate_only = TRUE) else inf$compute_estimate()
		expect_true(is.na(res))
		expect_identical(inf$get_nonestimable_reason(), "wilcox_empty_treatment_arm", info = estimate_only)
	}
})

test_that("a stats::wilcox.test() error is nonestimable ('wilcox_fit_unavailable')", {
	set.seed(2); n <- 20L
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	inf <- InferenceAllSimpleWilcox$new(des, verbose = FALSE)
	local_mocked_bindings(`wilcox.test` = function(...) stop("forced failure"), .package = "stats")

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "wilcox_fit_unavailable")
})
