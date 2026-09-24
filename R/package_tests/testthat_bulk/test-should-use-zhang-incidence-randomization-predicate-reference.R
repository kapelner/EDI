library(testthat)
library(EDI)

# InferenceAll's private should_use_zhang_incidence_randomization() (inference_all_abstract_rand.R)
# gates compute_rand_two_sided_pval()/compute_rand_confidence_interval()'s Zhang exact-combined-test
# dispatch via five AND'd conditions, including a specific 2026-08-26 bug-fix guard (a custom-
# randomization-only class composing neither RandomizationCI nor compute_exact_two_sided_pval_rand
# must NOT be reported Zhang-eligible, or the dispatch crashes with "attempt to apply non-function").
# supports_rand_pval_for_incidence()'s own callers ARE tested (test-rand-pval-and-rand-bootstrap-ci-
# incidence-not-supported-guards-reference.R), but only through composite happy-path/error-message
# checks on real class+design combinations -- the function itself, and each of its five conditions in
# isolation (confirmed via a zero-hit grep for its own name), had never been tested directly.
#   1. A genuinely Zhang-eligible case (incidence response, Bernoulli design, no custom statistic, a
#      class that composes RandomizationCI) is TRUE.
#   2. A custom randomization statistic function set disqualifies it, even though every other
#      condition is met.
#   3. A compiled C++ statistic function set disqualifies it the same way.
#   4. Neither a Bernoulli design nor matched-pair structure disqualifies it.
#   5. A non-incidence response type disqualifies it outright.
#   6. The 2026-08-26 bug-fix guard: a class that doesn't compose compute_exact_two_sided_pval_rand
#      (simulating a RandomizationTest-only class) is NOT reported Zhang-eligible even on an otherwise
#      fully-qualifying Bernoulli incidence design.

incid_bernoulli_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("a genuinely Zhang-eligible case (incidence, Bernoulli, no custom statistic, composes RandomizationCI) is TRUE", {
	priv <- incid_bernoulli_fixture(1L)
	expect_true(priv$is_bernoulli_design())
	expect_true(priv$has_private_method("compute_exact_two_sided_pval_rand"))
	expect_true(priv$should_use_zhang_incidence_randomization())
})

test_that("a custom randomization statistic function disqualifies it, even though every other condition is met", {
	priv <- incid_bernoulli_fixture(2L)
	priv$custom_randomization_statistic_function <- function(y, w) 0
	expect_false(priv$should_use_zhang_incidence_randomization())
})

test_that("a compiled C++ statistic function disqualifies it the same way", {
	priv <- incid_bernoulli_fixture(3L)
	priv$compiled_cpp_stat_fn <- "dummy"
	expect_false(priv$should_use_zhang_incidence_randomization())
})

test_that("neither a Bernoulli design nor matched-pair structure disqualifies it", {
	set.seed(4L); n <- 20L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$is_bernoulli_design())
	expect_false(isTRUE(priv$has_match_structure))
	expect_false(priv$should_use_zhang_incidence_randomization())
})

test_that("a non-incidence response type disqualifies it outright", {
	set.seed(5L); n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinOLS$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_false(priv$should_use_zhang_incidence_randomization())
})

test_that("2026-08-26 bug-fix guard: a class not composing compute_exact_two_sided_pval_rand is NOT reported Zhang-eligible on an otherwise fully-qualifying Bernoulli design", {
	priv <- incid_bernoulli_fixture(6L)
	orig_has_private_method <- priv$has_private_method
	unlockBinding("has_private_method", priv)
	priv$has_private_method <- function(name) if (identical(name, "compute_exact_two_sided_pval_rand")) FALSE else orig_has_private_method(name)
	expect_false(priv$should_use_zhang_incidence_randomization())
})
