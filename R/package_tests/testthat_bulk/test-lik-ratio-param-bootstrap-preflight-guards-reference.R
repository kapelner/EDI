library(testthat)
library(EDI)

# InferenceExtParamBootstrapEstimate's compute_lik_ratio_bootstrap_two_sided_pval()
# (inference_all_abstract_param_boot.R) has six sequential nonestimable guards, none of which had a
# test reference anywhere. The first five all fire before any bootstrap replicate is ever simulated
# (a pure preflight on the observed likelihood-ratio statistic), so they're reached cheaply by
# mocking the exact private helper each site calls; the sixth needs no real replicate refitting
# either -- mocking run_param_bootstrap_replicates() itself to return a synthetic too-few-finite
# result set:
#   1. "lik_ratio_bootstrap_spec_unavailable": get_likelihood_test_spec() returns NULL.
#   2. "lik_ratio_bootstrap_observed_lr_invalid": get_memoized_likelihood_test_eval() flags the
#      observed evaluation as invalid.
#   3. "lik_ratio_bootstrap_observed_negloglik_nonfinite": the observed full/null negloglik is
#      non-finite.
#   4. "lik_ratio_bootstrap_observed_lr_nonfinite": the derived LR statistic itself is non-finite even
#      though both negloglik values individually pass is.finite() -- reached with two individually-
#      finite but enormous values (+/-1e308) whose difference overflows double precision to +/-Inf.
#   5. "lik_ratio_bootstrap_observed_lr_extreme": param_bootstrap_lr_extreme(lr_obs) is TRUE.
#   6. "lik_ratio_bootstrap_too_few_converged_samples": too few finite replicate LR statistics.
# Reached via InferenceContinLin (a direct, non-IVWC composer of supports_lik_ratio_param_bootstrap
# = TRUE, already used for this exact fixture shape in this session's InferenceContinLin design-
# unusable-guard test).

lin_fixture <- function(seed = 1L, n = 40L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	InferenceContinLin$new(des, verbose = FALSE)
}

test_that("'lik_ratio_bootstrap_spec_unavailable' fires when get_likelihood_test_spec() returns NULL", {
	inf <- lin_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function(...) NULL

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_spec_unavailable")
})

test_that("'lik_ratio_bootstrap_observed_lr_invalid' fires when the observed evaluation is flagged invalid", {
	inf <- lin_fixture(seed = 2L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_memoized_likelihood_test_eval", p)
	p$get_memoized_likelihood_test_eval <- function(...) list(invalid = TRUE)

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_observed_lr_invalid")
})

test_that("'lik_ratio_bootstrap_observed_negloglik_nonfinite' fires when the observed full/null negloglik is non-finite", {
	inf <- lin_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_memoized_likelihood_test_eval", p)
	p$get_memoized_likelihood_test_eval <- function(...) list(invalid = FALSE, full_negloglik = NA_real_, null_negloglik = 12)

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_observed_negloglik_nonfinite")
})

test_that("'lik_ratio_bootstrap_observed_lr_nonfinite' fires when the derived LR statistic is non-finite", {
	inf <- lin_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_memoized_likelihood_test_eval", p)
	# both individually finite, but the difference overflows double precision to +/-Inf
	p$get_memoized_likelihood_test_eval <- function(...) list(invalid = FALSE, full_negloglik = -1e308, null_negloglik = 1e308)

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_observed_lr_nonfinite")
})

test_that("'lik_ratio_bootstrap_observed_lr_extreme' fires when param_bootstrap_lr_extreme(lr_obs) is TRUE", {
	inf <- lin_fixture(seed = 5L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_memoized_likelihood_test_eval", p)
	p$get_memoized_likelihood_test_eval <- function(...) list(invalid = FALSE, full_negloglik = 0, null_negloglik = 10)
	unlockBinding("param_bootstrap_lr_extreme", p)
	p$param_bootstrap_lr_extreme <- function(lr, ...) TRUE

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_observed_lr_extreme")
})

test_that("'lik_ratio_bootstrap_too_few_converged_samples' fires when too few replicate LR statistics converge", {
	inf <- lin_fixture(seed = 6L)
	p <- inf$.__enclos_env__$private
	unlockBinding("get_memoized_likelihood_test_eval", p)
	p$get_memoized_likelihood_test_eval <- function(...) {
		list(invalid = FALSE, full_negloglik = 0, null_negloglik = 10, null_fit = list())
	}
	unlockBinding("param_bootstrap_lr_extreme", p)
	p$param_bootstrap_lr_extreme <- function(lr, ...) rep(FALSE, length(lr))
	unlockBinding("run_param_bootstrap_replicates", p)
	p$run_param_bootstrap_replicates <- function(...) {
		list(
			results = list(list(lr = NA_real_), list(lr = NA_real_), list(lr = 5)),
			used_worker_path = FALSE,
			used_deterministic_mode = FALSE
		)
	}

	pval <- inf$compute_lik_ratio_bootstrap_two_sided_pval(B = 20L, min_number_usable_samples = 5L, show_progress = FALSE)
	expect_true(is.na(pval))
	expect_identical(inf$get_nonestimable_reason(), "lik_ratio_bootstrap_too_few_converged_samples")
})
