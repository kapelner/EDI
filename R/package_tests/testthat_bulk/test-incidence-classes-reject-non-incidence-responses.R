library(testthat)
library(EDI)

# docs-claims audit: initialize() of these incidence classes requires an
# incidence response and refuses any other response type.
#   docs-claims-d1f53ee72 InferenceIncidNewcombeRiskDiff
#   docs-claims-d31d47dff InferenceIncidExactFisher
#   docs-claims-d42892ef3 InferenceIncidExactZhang
#   docs-claims-d7661f482 InferenceIncidWald
#   docs-claims-dcc460d2a InferenceIncidCMH
#   docs-claims-ddab9b480 InferenceIncidExactBinomial
# (The "no censoring" half of those claims is not reachable: a non-survival
# response cannot carry censoring, so only the response-type guard is checked.)

incidence_msg <- "only available for incidence responses"

fill_fixed <- function(des, rt, n) {
	set.seed(1)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(if (rt == "count") rpois(n, 2) else rnorm(n))
	des
}

test_that("iBCRD designs with continuous or count responses are refused by Newcombe, Wald and exact Fisher", {
	for (rt in c("continuous", "count")) {
		des <- fill_fixed(DesignFixediBCRD$new(n = 8L, response_type = rt, verbose = FALSE), rt, 8L)
		expect_error(InferenceIncidNewcombeRiskDiff$new(des, verbose = FALSE), incidence_msg, info = rt)
		expect_error(InferenceIncidWald$new(des, verbose = FALSE), incidence_msg, info = rt)
		expect_error(InferenceIncidExactFisher$new(des, verbose = FALSE), incidence_msg, info = rt)
	}
})

test_that("a Bernoulli design with a continuous response is refused by exact Zhang", {
	des <- fill_fixed(DesignFixedBernoulli$new(n = 8L, response_type = "continuous", verbose = FALSE), "continuous", 8L)
	expect_error(InferenceIncidExactZhang$new(des, verbose = FALSE), incidence_msg)
})

test_that("a blocking design with a continuous response is refused by CMH", {
	des <- fill_fixed(DesignFixedBlocking$new(n = 8L, response_type = "continuous", m = rep(1:2, each = 4), verbose = FALSE), "continuous", 8L)
	expect_error(InferenceIncidCMH$new(des, verbose = FALSE), incidence_msg)
})

test_that("a binary-match design with a continuous response is refused by exact binomial", {
	des <- fill_fixed(DesignFixedBinaryMatch$new(n = 8L, response_type = "continuous", verbose = FALSE), "continuous", 8L)
	expect_error(InferenceIncidExactBinomial$new(des, verbose = FALSE), incidence_msg)
})
