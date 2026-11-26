# v1.0.6-TODO-149 item (4): classes without the MarginalEstimand component used to fail
# set_estimand() with "attempt to apply non-function". The Inference root now provides
# set_estimand() / get_supported_estimands() that stop with a classed
# "edi_estimand_not_supported" error, and get_estimand() that returns "conditional";
# classes composing MarginalEstimand replace all three with the component's versions.
library(testthat)
library(EDI)

estimand_count_design = function(seed = 1L, n = 40L) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
		des$add_one_subject_response(i, rpois(1, exp(0.5 + 0.3 * w)))
	}
	des
}

test_that("NegBin count classes reject set_estimand() with a classed, explanatory error", {
	des = estimand_count_design()
	for (cl in c("InferenceCountNegBin", "InferenceCountZeroInflatedNegBin", "InferenceCountHurdleNegBin")) {
		inf = get(cl)$new(des, verbose = FALSE)
		expect_false(isTRUE(inf$supports("marginal_estimand")), info = cl)
		for (est in c("marginal_mean_diff", "marginal_ratio", "conditional")) {
			err = tryCatch(inf$set_estimand(est), error = function(e) e)
			expect_s3_class(err, "edi_estimand_not_supported")
			expect_identical(err$inference_class, cl)
			expect_identical(
				conditionMessage(err),
				paste0(cl, " does not support set_estimand(): only its default (\"conditional\") estimand ",
					"is available, i.e. the treatment effect the class reports (for a regression model, the ",
					"model-scale coefficient); marginal estimands are not available for this class in this release.")
			)
		}
		expect_error(inf$get_supported_estimands(), class = "edi_estimand_not_supported", info = cl)
		expect_error(inf$get_supported_estimands(), "does not support get_supported_estimands\\(\\)", info = cl)
		expect_identical(inf$get_estimand(), "conditional", info = cl)
		# The refusal leaves the object usable.
		expect_true(is.finite(inf$compute_estimate()), info = cl)
	}
})

test_that("a class composing MarginalEstimand keeps its own set_estimand()", {
	des = estimand_count_design()
	inf = InferenceCountPoisson$new(des, verbose = FALSE)
	expect_true(isTRUE(inf$supports("marginal_estimand")))
	expect_identical(inf$get_supported_estimands(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	beta_cond = inf$compute_estimate()
	expect_silent(inf$set_estimand("marginal_mean_diff"))
	expect_identical(inf$get_estimand(), "marginal_mean_diff")
	expect_true(is.finite(inf$compute_estimate()))
	# Poisson is collapsible on the log scale, so use the mean difference, which differs.
	expect_false(isTRUE(all.equal(inf$compute_estimate(), beta_cond)))
	inf$set_estimand("conditional")
	expect_equal(inf$compute_estimate(), beta_cond)
	# The component's own rejection (not the root error) still applies to an unsupported value.
	expect_error(inf$set_estimand("not_an_estimand"), "Unrecognized estimand")
})
