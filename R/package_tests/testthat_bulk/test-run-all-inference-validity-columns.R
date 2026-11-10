# v1.0.5 TODO-194: run_all_inference() gains regime / n_eff / size_order /
# rate_basis columns read from the procedure-regime and convergence-rate
# registry (R/EDI/R/inference_procedure_regime.R) on the design's realised data.
# Additive only: the earlier columns keep their position.
library(testthat)

internals = function(name) get(name, envir = asNamespace("EDI"))
skip_if_no_validity = function() skip_if_not(exists("edi_inference_validity_columns", envir = asNamespace("EDI")), "package predates the validity columns")

run_suite = function(des, classes) {
	suite = InferenceSuite$new(des)
	capture.output({ res <- suite$run_all_inference(screen = TRUE, plots = FALSE, classes = classes) })
	res$results_table
}

test_that("validity columns: presence, types, additive and in the registry's vocabulary", {
	skip_if_no_validity()
	set.seed(20261110)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	tbl = run_suite(des, "InferenceAllSimpleAverageDiff")
	new_cols = c("regime", "n_eff", "size_order", "rate_basis")
	expect_true(all(new_cols %in% names(tbl)))
	for (cl in new_cols) expect_type(tbl[[cl]], "character")
	# Additive: the new columns come after every pre-existing one, `weight` stays put.
	expect_identical(tail(names(tbl), 4L), new_cols)
	expect_identical(names(tbl)[match("weight", names(tbl))], "weight")
	expect_true(all(tbl$regime %in% c("asymptotic", "finite_sample")))
	expect_true(all(tbl$rate_basis %in% internals("EDI_CONVERGENCE_BASIS")))
	expect_identical(tbl$regime, internals("inference_procedure_regime")(tbl$method))
	expect_true(all(grepl("^n = 30$", tbl$n_eff)))
	expect_true(all(grepl("^(exact|O\\(1\\)|unknown|O\\(n_eff\\^-[0-9/]+\\))$", tbl$size_order)))
	# Finite-sample rows (exact / rand) are exact; asymptotic rows have an order.
	fin = tbl$regime == "finite_sample"
	expect_true(any(fin))
	expect_true(all(tbl$size_order[fin] == "exact"))
	expect_true(all(tbl$rate_basis[fin] == "theory"))
	expect_false(any(tbl$size_order[!fin] == "exact"))
})

test_that("validity columns: matched design reports n_pairs from the realised matching", {
	skip_if_no_validity()
	set.seed(20261110)
	n = 30L
	des = DesignFixedBinaryMatch$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	tbl = run_suite(des, "InferenceOrdinalPairedSignTest")
	expect_gt(NROW(tbl), 0L)
	expect_true(all(tbl$n_eff == "n_pairs = 15"))
	counts = internals("edi_inference_validity_counts")(des)
	expect_equal(unname(counts[["n_pairs"]]), 15)
	expect_equal(unname(counts[["n_pairs_plus_reservoir"]]), 15)
})

test_that("validity columns: unequal allocation reports n_min_arm", {
	skip_if_no_validity()
	set.seed(20261110)
	n = 50L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", prob_T = 0.2, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rnorm(n) + w)
	tbl = run_suite(des, "InferenceAllSimpleAverageDiff")
	expected = sprintf("n_min_arm = %d", min(sum(w == 1), sum(w == 0)))
	asy = tbl$regime == "asymptotic"
	expect_true(any(asy))
	expect_true(all(tbl$n_eff[asy] == expected))
	# Finite-sample procedures keep the class/procedure rule: allocation is not their business.
	expect_true(all(tbl$n_eff[!asy] == sprintf("n = %d", n)))
})

test_that("validity helpers: order rendering, NA handling and empty input", {
	skip_if_no_validity()
	render = internals("edi_inference_validity_render_order")
	expect_identical(render(c(Inf, 0, NA, 1, 2, 2 / 3)),
		c("exact", "O(1)", "unknown", "O(n_eff^-1)", "O(n_eff^-2)", "O(n_eff^-2/3)"))
	des = DesignFixedBernoulli$new(n = 10L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(10L)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(10L))
	cols = internals("edi_inference_validity_columns")
	odd = cols(des, c("InferenceAllSimpleAverageDiff", "InferenceAllSimpleAverageDiff"), c("wald", NA))
	expect_identical(odd$regime, c("asymptotic", NA))
	expect_true(all(is.na(unlist(odd[2L, ]))))
	zero = cols(des, character(0), character(0))
	expect_identical(NROW(zero), 0L)
	expect_identical(names(zero), c("regime", "n_eff", "size_order", "rate_basis"))
	# A counts rule that does not apply to the design is NA, and says so in the label.
	expect_true(is.na(internals("edi_inference_validity_n_eff")(des, "n_pairs")))
	expect_identical(cols(des, "InferenceOrdinalPairedSignTest", "wald")$n_eff, "n_pairs = NA")
})
