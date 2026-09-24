library(testthat)
library(EDI)

# InferenceRandCI's compute_rand_confidence_interval() (inference_all_abstract_rand_ci.R)
# has a third fallback mode -- ci_search_control$fallback = "error" -- alongside "na" and the
# usable-fallback-CI path, all reached from the same "search failed to bracket the target
# p-value" branch. The sibling test file test-rand-ci-search-bounds-and-bisection-failed-
# guards-reference.R covers only fallback = "na" (nonestimable, NA CI); the raw
# stop("Randomization CI search failed to bracket the target p-value within the configured
# search radius.") that fires when fallback = "error" had zero test references anywhere.
# Reached via the same mocking technique as that sibling file: unlockBinding() the private
# build_randomization_ci_search_bounds() to force non-finite bounds, bypassing the real
# permutation/bisection machinery entirely.

smd_fixture <- function(n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("fallback = 'error' raises the raw bracket-search-failed error instead of caching a nonestimable NA CI", {
	f <- smd_fixture()
	unlockBinding("build_randomization_ci_search_bounds", f$priv)
	f$priv$build_randomization_ci_search_bounds <- function(...) {
		list(l = NA_real_, u = NA_real_, est = 0.3, fallback_ci = NULL)
	}

	expect_error(
		f$inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE, ci_search_control = list(fallback = "error")),
		"Randomization CI search failed to bracket the target p-value within the configured search radius.",
		fixed = TRUE
	)
})

test_that("the default fallback mode ('na') does not raise, for contrast against the 'error' mode above", {
	f <- smd_fixture(seed = 2L)
	unlockBinding("build_randomization_ci_search_bounds", f$priv)
	f$priv$build_randomization_ci_search_bounds <- function(...) {
		list(l = NA_real_, u = NA_real_, est = 0.3, fallback_ci = NULL)
	}

	ci <- f$inf$compute_rand_confidence_interval(r = 21L, show_progress = FALSE, ci_search_control = list(fallback = "na"))
	expect_true(all(is.na(ci)))
})
