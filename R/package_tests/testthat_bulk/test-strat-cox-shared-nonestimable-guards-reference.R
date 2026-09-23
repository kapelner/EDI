library(testthat)
library(EDI)

# InferenceSurvivalStratCoxPHRegr's shared() (inference_survival_strat_cox.R) has two nonestimable
# guards, neither of which had a test reference anywhere (test-survival-strong-effect-fit-guards.R
# exercises the happy accepted-fit path only, never asserting a nonestimable reason):
#   1. "strat_cox_fit_unavailable": generate_mod()'s beta_hat_T (or b[2] fallback) is non-finite.
#   2. "strat_cox_standard_error_unavailable": ssq_b_2 is non-finite/non-positive.
# A third guard, "strat_cox_extreme_estimate" (finite beta_hat_T exceeding max_abs_reasonable_coef),
# was removed from shared() as dead code: both real generate_mod() output formatters --
# format_rcpp_output() and format_mod_output() -- already clamp an extreme coefficient to
# beta_hat_T = NA_real_ before returning, so shared() could never actually observe a finite,
# out-of-range beta_hat_T; the branch was unreachable through any real code path.
# Both remaining guards reached by mocking generate_mod() itself (unlockBinding, private) --
# bypassing the two real formatters entirely, since it's shared()'s own guard logic being tested.

strat_cox_fixture <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n) / n))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = seq_len(n), y_Ls = rep(NA_real_, n), y_Rs = rep(NA_real_, n))
	InferenceSurvivalStratCoxPHRegr$new(des, verbose = FALSE)
}

test_that("shared() caches 'strat_cox_fit_unavailable' when generate_mod()'s beta_hat_T/b[2] is non-finite", {
	inf <- strat_cox_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) list(b = c(NA_real_, NA_real_), ssq_b_2 = NA_real_)

	res <- inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "strat_cox_fit_unavailable")
})

test_that("shared() caches 'strat_cox_standard_error_unavailable' when ssq_b_2 is non-finite/non-positive", {
	inf <- strat_cox_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	unlockBinding("generate_mod", p)
	p$generate_mod <- function(estimate_only = FALSE) list(beta_hat_T = 0.5, b = c(0, 0.5), ssq_b_2 = NA_real_)

	res <- inf$compute_estimate()
	expect_equal(res, 0.5)
	expect_true(is.na(p$cached_values$s_beta_hat_T))
	expect_identical(inf$get_nonestimable_reason(), "strat_cox_standard_error_unavailable")
})
