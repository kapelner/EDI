library(testthat)
library(EDI)

# InferenceIncidGCompRiskRatio's compute_rr_subsampling_two_sided_pval() (reached via the public
# compute_subsampling_two_sided_pval() dispatch, since this class's estimand type is "RR") has an
# "a null risk-ratio delta must be finite and positive" guard identical in shape to the already-tested
# jackknife (test-incid-gcomp-risk-ratio-jackknife-pval-unusable-original-estimate-reference.R) and
# m-out-of-n bootstrap guards on the same class, caching "subsampling_log_risk_ratio_null_unavailable" --
# but this specific subsampling-path copy of the guard had no test anywhere calling it, unlike its
# m_out_of_n sibling which is already covered.

rr_fx <- function(seed = 3L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w(); y <- rbinom(n, 1, plogis(-0.6 + 0.7 * w + 0.4 * x)); des$add_all_subject_responses(y)
	InferenceIncidGCompRiskRatio$new(des, verbose = FALSE)
}

test_that("compute_subsampling_two_sided_pval dispatches to the RR-specific subsampling path for this class", {
	p <- rr_fx()$.__enclos_env__$private
	expect_identical(p$get_estimand_type(), "RR")
})

test_that("a non-positive or non-finite null delta is nonestimable with the shared reason, for every invalid value", {
	for (d in c(0, -1, NA)) {
		inf <- rr_fx()
		pv <- inf$compute_subsampling_two_sided_pval(delta = d, B = 20, show_progress = FALSE)
		expect_true(is.na(pv), info = paste("delta =", d))
		expect_identical(inf$get_nonestimable_reason(), "subsampling_log_risk_ratio_null_unavailable", info = paste("delta =", d))
	}
})

test_that("a usable positive delta does not trip this guard and returns a finite p-value", {
	inf <- rr_fx()
	pv <- inf$compute_subsampling_two_sided_pval(delta = 1, B = 80, show_progress = FALSE)
	expect_true(is.finite(pv))
	expect_false(inf$is_nonestimable("any"))
})

test_that("calling the private method directly reproduces the identical guard behavior", {
	inf <- rr_fx()
	p <- inf$.__enclos_env__$private
	pv <- p$compute_rr_subsampling_two_sided_pval(delta = -0.5, B = 20, show_progress = FALSE)
	expect_true(is.na(pv))
	expect_identical(inf$get_nonestimable_reason(), "subsampling_log_risk_ratio_null_unavailable")
})
