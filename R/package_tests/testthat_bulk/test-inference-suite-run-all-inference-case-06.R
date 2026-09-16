library(testthat)
library(EDI)

test_that("run_all_inference: continuous DesignFixedOptimal (iid, deterministic)", {
	skip_if_not_installed("ompr")
	skip_if_not_installed("ompr.roi")
	skip_if_not_installed("ROI.plugin.glpk")
	set.seed(20260818)
	n = 12L
	des = DesignFixedOptimal$new(n = n, response_type = "continuous", seed = 42)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	expect_valid_run_all_inference_report(des, "iid")
})

# ---- Full response-type grid (TODO-9, unlocked 2026-08-23) ----
# The blocks above cover continuous/incidence x {iBCRD, blocking, KK14, greedy,
# D-optimal}; these add the remaining four response types (count, proportion,
# survival, ordinal) x {iBCRD (iid), KK14 (matched pair)} -- the design-class
# axis is already exercised above, so the response-type axis is what was
# missing. Each also asserts a canonical class's status == "ok" specifically.

