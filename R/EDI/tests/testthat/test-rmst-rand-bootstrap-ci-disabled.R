library(testthat)
library(EDI)

# G4-C R4A (2026-10-25): the randomization-bootstrap CI inverts a multiplicative
# (log-time) shift of the survival response, so for InferenceSurvivalRestrictedMeanDiff
# its bounds were for a log-time ratio, not the RMST difference the class estimates
# (the same reason the class already refuses compute_rand_confidence_interval()).
# All four CI types are refused with a classed condition and the capability is not
# advertised; the randomization-bootstrap p-value at delta = 0 is untouched.

make_rmst_design = function(seed = 3L, n = 40L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w(); y = rexp(n, 0.15 * exp(0.4 * w)); dead = rbinom(n, 1, 0.75)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA_real_), ifelse(dead == 0, y, NA_real_), ifelse(dead == 0, Inf, NA_real_))
	des
}

test_that("RMST does not advertise the randomization-bootstrap CI but keeps the randomization-bootstrap p-value", {
	capabilities = EDI:::get_effective_capabilities("InferenceSurvivalRestrictedMeanDiff")
	expect_false("randomization_bootstrap_ci" %in% capabilities)
	expect_false("randomization_ci" %in% capabilities)
	expect_true("randomization_bootstrap" %in% capabilities)
	expect_true("randomization_bootstrap_ci" %in% EDI:::get_inference_class_metadata("InferenceSurvivalRestrictedMeanDiff")$excluded_capabilities)
})

test_that("every randomization-bootstrap CI type is refused with the classed scale-mismatch condition", {
	inf = InferenceSurvivalRestrictedMeanDiff$new(make_rmst_design(), verbose = FALSE)
	for (type in c("percentile", "studentized", "symmetric-percentile-t", "smoothed")) {
		expect_error(
			inf$compute_rand_bootstrap_confidence_interval(B = 19L, show_progress = FALSE, type = type),
			class = "edi_rand_bootstrap_ci_scale_mismatch_refused",
			info = type
		)
	}
	expect_error(inf$compute_rand_bootstrap_confidence_interval(B = 19L, show_progress = FALSE), "log-time ratio")
})

test_that("the randomization-bootstrap p-value at delta = 0 still runs", {
	inf = InferenceSurvivalRestrictedMeanDiff$new(make_rmst_design(seed = 4L), verbose = FALSE)
	p = inf$compute_rand_bootstrap_two_sided_pval(B = 39L, show_progress = FALSE)
	expect_true(is.finite(p) && p >= 0 && p <= 1)
})
