library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr$compute_bootstrap_confidence_interval_studentized()
# (inference_survival_dep_cens_transform.R) validates the basic bootstrap CI it builds on via two
# private predicates -- dep_cens_ci_excludes_zero() and dep_cens_ci_too_wide() -- and caches
# "dep_cens_transform_studentized_bootstrap_ci_unstable" (returning an all-NA CI) if either flags
# the result. Neither branch had a test reference anywhere. Reached by overriding the public
# compute_bootstrap_confidence_interval_basic() method directly on the instance (unlockBinding,
# since R6 public methods stay locked even with lock_objects = FALSE) to return a hand-built CI that
# trips each predicate in turn -- the same private-state/method-override technique already used
# elsewhere in this suite for analogous unreachable-in-practice failure paths.

dep_cens_fixture <- function(seed = 2L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

test_that("a basic CI that excludes zero is rejected as unstable", {
	inf <- dep_cens_fixture()
	unlockBinding("compute_bootstrap_confidence_interval_basic", inf)
	inf$compute_bootstrap_confidence_interval_basic <- function(...) c(`2.5%` = 1, `97.5%` = 2)

	ci <- inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_studentized_bootstrap_ci_unstable")
})

test_that("a basic CI that is implausibly wide is rejected as unstable", {
	inf <- dep_cens_fixture(seed = 3L)
	unlockBinding("compute_bootstrap_confidence_interval_basic", inf)
	inf$compute_bootstrap_confidence_interval_basic <- function(...) c(`2.5%` = -1e10, `97.5%` = 1e10)

	ci <- inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_studentized_bootstrap_ci_unstable")
})

test_that("a well-behaved basic CI is NOT rejected (sanity contrast for the two predicates)", {
	inf <- dep_cens_fixture(seed = 4L)
	unlockBinding("compute_bootstrap_confidence_interval_basic", inf)
	inf$compute_bootstrap_confidence_interval_basic <- function(...) c(`2.5%` = -0.5, `97.5%` = 0.5)

	ci <- inf$compute_bootstrap_confidence_interval_studentized(alpha = 0.05)
	expect_equal(unname(ci), c(-0.5, 0.5))
})
