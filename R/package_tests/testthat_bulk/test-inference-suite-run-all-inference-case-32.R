library(testthat)
library(EDI)

test_that("run_all_inference: methods argument accepts the TODO-22 list-of-types shape", {
	set.seed(20260819)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res <- suite$run_all_inference(
			screen = TRUE, plots = FALSE,
			classes = "InferenceAllSimpleAverageDiff",
			methods = list(bootstrap = c("percentile", "bca"), wald = NULL)
		)
	})
	tbl = res$results_table
	expect_identical("type" %in% names(tbl), TRUE)
	# Exactly 3 tasks requested: bootstrap x {percentile, bca}, plus wald
	# (no type axis) -- one row each, all against a class that supports all
	# three.
	expect_identical(nrow(tbl), 3L)
	expect_setequal(
		paste(tbl$method, tbl$type),
		c("bootstrap percentile", "bootstrap bca", "wald NA")
	)
	expect_true(all(tbl$status == "ok"))
	# ci_method/pval_method for a typed sentinel report the type-qualified
	# form via method_with_type_short_label() in the pretty display table,
	# but results_table itself keeps ci_method/pval_method as plain sentinel
	# labels (the raw method actually used) with `type` as its own column.
	boot_rows = tbl[tbl$method == "bootstrap", , drop = FALSE]
	expect_true(all(boot_rows$ci_method == "bootstrap"))
	expect_true(all(boot_rows$pval_method == "bootstrap"))
	expect_setequal(boot_rows$type, c("percentile", "bca"))
})

