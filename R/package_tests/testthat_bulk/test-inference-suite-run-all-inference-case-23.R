library(testthat)
library(EDI)

test_that("run_all_inference: plots = TRUE builds real ggplot objects when ggplot2 is available", {
	skip_if_not_installed("ggplot2")
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	null_dev = grDevices::pdf(NULL)
	on.exit(grDevices::dev.off(), add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = TRUE, compute_conf_intervals = TRUE)
	})
	# `plots$ci_forest` is a named list of one ggplot per estimand (the
	# former separate `plots$estimates` was folded into it, 2026-08-21).
	expect_null(res$plots$estimates)
	expect_true(length(res$plots$ci_forest) >= 1L)
	# Each entry is a forest+box `gtable` grob (not a bare ggplot) -- see
	# `run_all_inference_stack_forest_and_box()`.
	for (p in res$plots$ci_forest) expect_s3_class(p, "gtable")
})

