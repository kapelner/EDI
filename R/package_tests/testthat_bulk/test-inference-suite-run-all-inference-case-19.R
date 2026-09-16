library(testthat)
library(EDI)

test_that("run_all_inference: per-class failure isolation is a real regression test, not just dev-session verification", {
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))

	# run_all_inference_one_class() looks the class up via
	# get(cls_name, envir = getNamespace("EDI")) (the same pattern
	# InferenceSuite$initialize()'s inference_params validation already uses),
	# whose search chain reaches .GlobalEnv but NOT a test_that() block's own
	# local frame -- so the generator must be assigned into .GlobalEnv
	# explicitly, not just defined as a local variable here.
	InferenceTemporaryAlwaysThrowsRunAll = R6::R6Class("InferenceTemporaryAlwaysThrowsRunAll",
		inherit = EDI:::Inference,
		public = list(
			initialize = function(des_obj, ...) {
				stop("InferenceTemporaryAlwaysThrowsRunAll: constructor always fails (test double).")
			}
		)
	)
	assign("InferenceTemporaryAlwaysThrowsRunAll", InferenceTemporaryAlwaysThrowsRunAll, envir = .GlobalEnv)
	on.exit(rm("InferenceTemporaryAlwaysThrowsRunAll", envir = .GlobalEnv), add = TRUE)
	EDI:::register_inference_class(
		name = "InferenceTemporaryAlwaysThrowsRunAll",
		parent = "Inference",
		metadata = list(
			abstract = FALSE, exported = TRUE, response_types = "continuous",
			design_families = "all", compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none", required_packages = character(), capabilities = character()
		),
		direct_components = character()
	)

	suite = InferenceSuite$new(des)
	expect_true("InferenceTemporaryAlwaysThrowsRunAll" %in% suite$applicable_design_classes)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE)
	})
	tbl = res$results_table
	broken_row = tbl[tbl$inference_class == "InferenceTemporaryAlwaysThrowsRunAll", , drop = FALSE]
	expect_identical(nrow(broken_row), 1L)
	expect_identical(broken_row$status, "error")
	expect_true(grepl("constructor always fails", broken_row$message, fixed = TRUE))
	# Every other applicable class must be unaffected by the broken one --
	# "unaffected" means none of them report status = "error" because of the
	# broken class, not that every one of ~30 diverse classes cleanly fits
	# on this particular small (n=20) random draw. Some (Wilcoxon
	# Hodges-Lehmann jackknife, robust-regression/quantile-regression
	# bootstrap SE stability) legitimately and correctly report "nonest" on
	# small samples regardless of isolation -- that's honest non-estimability
	# reporting, not a failure this test is checking for.
	other_rows = tbl[tbl$inference_class != "InferenceTemporaryAlwaysThrowsRunAll", , drop = FALSE]
	expect_true(all(other_rows$status %in% c("ok", "nonest")))
})

