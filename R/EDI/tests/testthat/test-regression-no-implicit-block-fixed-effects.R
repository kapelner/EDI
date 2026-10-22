# TODO-105: regression inference on blocking designs adds no block fixed
# effects by itself. This pins the CURRENT, documented behaviour; if an
# opt-in add_block_fixed_effects is ever added, the default must stay FALSE
# (or this test must be updated deliberately).
test_that("InferenceContinOLS on a blocking design uses only the covariate matrix (no block dummies)", {
	set.seed(1)
	n = 40
	des = DesignFixedBlocking$new(n = n, response_type = "continuous",
		strata_cols = "site", equal_block_sizes = FALSE, verbose = FALSE)
	X = data.frame(site = factor(rep(c("a", "b", "c", "d"), each = 10)), x2 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + 2 * as.integer(X$site))
	expect_equal(length(unique(des$get_block_ids())), 4L)
	inf = InferenceContinOLS$new(des, verbose = FALSE)
	dm = inf$.__enclos_env__$private$create_design_matrix()
	cn = colnames(dm)
	# the model sees the covariates exactly as supplied to the design; the
	# block ids themselves are not appended as extra columns
	expect_false(any(grepl("block", cn, ignore.case = TRUE)))
	expect_true(ncol(dm) <= 2L + ncol(as.matrix(des$get_X())))
	expect_true(is.finite(inf$compute_estimate()))
})
