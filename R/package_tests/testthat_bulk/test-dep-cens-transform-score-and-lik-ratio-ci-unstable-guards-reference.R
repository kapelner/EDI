library(testthat)
library(EDI)

# InferenceSurvivalDepCensTransformRegr (inference_survival_dep_cens_transform.R) has two more
# nonestimable guards on its likelihood-test surface, neither of which had a test reference
# anywhere:
#   1. compute_score_two_sided_pval(): caches "dep_cens_transform_score_pvalue_unstable" when the
#      score p-value disagrees sharply with the asymptotic Wald p-value (score p < 0.01 while the
#      asymptotic p > 0.05) -- a documented instability check, not a plain error path.
#   2. compute_lik_ratio_confidence_interval(): catches an internal '"names" attribute' error from
#      compute_lik_ratio_confidence_interval_impl() (a known failure signature for this model) or a
#      malformed/non-finite CI, and caches "dep_cens_transform_lik_ratio_ci_unavailable" either way.
# Reached by overriding the exact private impl / public method each guard reads from, the same
# unlockBinding()-based technique already used elsewhere in this suite (including this session's
# InferenceSurvivalDepCensTransformRegr studentized-bootstrap-CI reference test) for analogous
# unreachable-in-practice failure paths.

dep_cens_fixture <- function(seed = 2L, n = 30L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rexp(n, exp(0.4 * w)))
	InferenceSurvivalDepCensTransformRegr$new(des, verbose = FALSE)
}

test_that("compute_score_two_sided_pval flags disagreement with the asymptotic test as unstable", {
	inf <- dep_cens_fixture()
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_two_sided_pval_impl", p)
	p$compute_score_two_sided_pval_impl <- function(delta) 0.001  # score test: strongly significant
	unlockBinding("compute_asymp_two_sided_pval", inf)
	inf$compute_asymp_two_sided_pval <- function(delta) 0.9       # asymptotic test: not significant at all

	res <- inf$compute_score_two_sided_pval(0)
	expect_true(is.na(res))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_score_pvalue_unstable")
})

test_that("compute_score_two_sided_pval passes through a score p-value that agrees with the asymptotic test", {
	inf <- dep_cens_fixture(seed = 5L)
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_score_two_sided_pval_impl", p)
	p$compute_score_two_sided_pval_impl <- function(delta) 0.02
	unlockBinding("compute_asymp_two_sided_pval", inf)
	inf$compute_asymp_two_sided_pval <- function(delta) 0.03

	res <- inf$compute_score_two_sided_pval(0)
	expect_equal(res, 0.02)
})

test_that("compute_lik_ratio_confidence_interval catches the documented '\"names\" attribute' failure signature", {
	inf <- dep_cens_fixture(seed = 3L)
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_lik_ratio_confidence_interval_impl", p)
	p$compute_lik_ratio_confidence_interval_impl <- function(alpha) {
		stop("'names' attribute [3] must be the same length as the vector [2]")
	}

	ci <- inf$compute_lik_ratio_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_lik_ratio_ci_unavailable")
})

test_that("compute_lik_ratio_confidence_interval also rejects a malformed/non-finite CI from the impl", {
	inf <- dep_cens_fixture(seed = 4L)
	p <- inf$.__enclos_env__$private
	unlockBinding("compute_lik_ratio_confidence_interval_impl", p)
	p$compute_lik_ratio_confidence_interval_impl <- function(alpha) c(NA_real_, NA_real_)

	ci <- inf$compute_lik_ratio_confidence_interval(0.05)
	expect_true(all(is.na(ci)))
	expect_identical(inf$get_nonestimable_reason(), "dep_cens_transform_lik_ratio_ci_unavailable")
})
