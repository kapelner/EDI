library(testthat)
library(EDI)

# inference_all_abstract_rand_ci.R's assert_no_incidence_only_randomization_args(resp_type, type,
# args_for_type), called from compute_rand_two_sided_pval() (and, for a non-incidence response,
# compute_rand_confidence_interval() before its own separate incidence guard) rejects the
# incidence-only `type`/`args_for_type` arguments on any non-incidence-response instance: "type"
# non-NULL errors "Randomization type dispatch is only supported for incidence outcomes.";
# "args_for_type" non-NULL errors "args_for_type is only used for incidence randomization
# inference." On an incidence-response instance whose design is Zhang-eligible, both arguments are
# instead legitimate (dispatched to the Zhang exact-combined test) and this guard is never reached --
# that path is already covered elsewhere. Zero test references for either message anywhere.

fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n))); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	InferenceContinLin$new(d, verbose = FALSE)
}

test_that("compute_rand_two_sided_pval(): a non-NULL type on a non-incidence instance errors with the documented message", {
	inf <- fx(seed = 1L)
	expect_error(
		inf$compute_rand_two_sided_pval(r = 50, type = "Zhang", show_progress = FALSE),
		"Randomization type dispatch is only supported for incidence outcomes\\."
	)
})

test_that("compute_rand_two_sided_pval(): a non-NULL args_for_type on a non-incidence instance errors with the documented message", {
	inf <- fx(seed = 2L)
	expect_error(
		inf$compute_rand_two_sided_pval(r = 50, args_for_type = list(a = 1), show_progress = FALSE),
		"args_for_type is only used for incidence randomization inference\\."
	)
})

test_that("compute_rand_two_sided_pval(): neither incidence-only arg supplied does NOT error on a non-incidence instance", {
	inf <- fx(seed = 3L)
	pv <- inf$compute_rand_two_sided_pval(r = 50, show_progress = FALSE)
	expect_true(is.finite(pv) && pv >= 0 && pv <= 1)
})
