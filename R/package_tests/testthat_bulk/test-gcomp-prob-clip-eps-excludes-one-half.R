# The g-computation classes document prob_clip_eps (and, for proportions, prob_clip_strong_eps)
# as lying in [0, 0.5). At 0.5 every fitted probability is clipped to 0.5, so the check must
# reject it; assertNumber(upper = 0.5) alone accepted it (source-comment-rot audit decision
# source-comment-rot-d4adc9b4d, owner ruling 2026-11-18: tighten the check).
library(testthat)
library(EDI)

gcomp_clip_design = function(response_type, y) {
	set.seed(11)
	n = length(y)
	des = DesignFixedBernoulli$new(n = n, response_type = response_type)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(y)
	des
}

test_that("incidence g-computation rejects prob_clip_eps = 0.5 and accepts values below it", {
	set.seed(12)
	des = gcomp_clip_design("incidence", rbinom(40, 1, 0.4))
	below_half = 0.5 - .Machine$double.eps / 4
	for (cls in list(InferenceIncidGCompRiskDiff, InferenceIncidGCompRiskRatio)) {
		for (invalid in list(-0.01, 0.5, 0.51, NA_real_, Inf, "0.1", c(0.1, 0.2))) {
			expect_error(cls$new(des, prob_clip_eps = invalid), "prob_clip_eps must be in \\[0, 0.5\\)")
		}
		expect_no_error(cls$new(des, prob_clip_eps = below_half))
		expect_no_error(cls$new(des, prob_clip_eps = 0))
	}
})

test_that("proportion g-computation rejects either clamp at 0.5", {
	set.seed(13)
	des = gcomp_clip_design("proportion", stats::runif(40, 0.05, 0.95))
	expect_error(InferencePropGCompMeanDiff$new(des, prob_clip_eps = 0.5), "prob_clip_eps must be in \\[0, 0.5\\)")
	expect_error(InferencePropGCompMeanDiff$new(des, prob_clip_strong_eps = 0.5),
		"prob_clip_strong_eps must be in \\[0, 0.5\\)")
	expect_no_error(InferencePropGCompMeanDiff$new(des, prob_clip_eps = 0.49, prob_clip_strong_eps = 0.49))
})
