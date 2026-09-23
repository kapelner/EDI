library(testthat)
library(EDI)

# InferenceCountHurdleNegBin (inference_count_hurdle.R) has two sibling nonestimable guards to the
# four already closed by test-hurdle-negbin-fit-and-design-unusable-guards-reference.R, neither with
# a test reference anywhere:
#   1. "hurdle_negbin_aux_design_unusable": generate_mod()'s main (count-submodel) design reduction
#      succeeds, but the hurdle-submodel design reduction returns a NULL X. Reached with a
#      call-counting override of reduce_design_matrix_preserving_treatment() -- first call (count
#      submodel) passes through to the real implementation, second call (hurdle submodel) returns
#      the NULL-X sentinel -- the same call-counting-mock technique already used for the analogous
#      "zero_augmented_poisson_aux_design_unusable" guard closed earlier this session.
#   2. "hurdle_negbin_weighted_treatment_missing": compute_estimate_with_bootstrap_weights()'s
#      weighted glmmTMB refit succeeds, but glmmTMB::fixef(mod)$cond has no finite "w" coefficient.
#      A past iteration this session found that mocking ONLY glmmTMB::fixef() while letting the real
#      glmmTMB::glmmTMB() fit proceed breaks the real fit's own internal machinery (mocking leaks
#      into fit-internal fixef() calls); reached here instead by mocking BOTH glmmTMB::glmmTMB()
#      (to a cheap fake fit object, never touching the real optimizer) and glmmTMB::fixef() (to
#      extract from that fake object), so no real glmmTMB fitting occurs at all.

hurdle_negbin_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rpois(n, exp(0.3 * X$x1 + 0.5 * des$get_w() + 1)))
	des
}

test_that("generate_mod() caches 'hurdle_negbin_aux_design_unusable' when only the hurdle-submodel design reduction fails", {
	des <- hurdle_negbin_fixture()
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	orig <- p$reduce_design_matrix_preserving_treatment
	call_count <- 0
	unlockBinding("reduce_design_matrix_preserving_treatment", p)
	p$reduce_design_matrix_preserving_treatment <- function(...) {
		call_count <<- call_count + 1
		if (call_count == 1) orig(...) else list(X = NULL, keep = integer(0), j_treat = NA_integer_)
	}

	res <- p$generate_mod(estimate_only = TRUE)
	expect_null(res)
	expect_identical(inf$get_nonestimable_reason(), "hurdle_negbin_aux_design_unusable")
	expect_equal(call_count, 2L)
})

test_that("compute_estimate_with_bootstrap_weights() caches 'hurdle_negbin_weighted_treatment_missing' when fixef(mod)$cond has no usable 'w'", {
	des <- hurdle_negbin_fixture(seed = 2L)
	inf <- InferenceCountHurdleNegBin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	local_mocked_bindings(
		glmmTMB = function(...) structure(list(), class = "fake_hurdle_negbin_fit"),
		fixef = function(object, ...) list(cond = c(`(Intercept)` = 0.5)),
		.package = "glmmTMB"
	)

	res <- p$weighted_refit_impl(rep(1, 40L))
	expect_true(is.na(res))
	expect_identical(p$cached_values$nonestimable_reason, "hurdle_negbin_weighted_treatment_missing")
})
