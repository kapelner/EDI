library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-dfabf84ea (InferenceOrdinalKKGEE, R/EDI/R/inference_ordinal_KK_combined.R):
#   - under separation every jackknife method returns NA with an edi_procedure_na_warning (reason
#     jackknife_full_data_separation);
#   - des_obj must have an ordinal response;
#   - model_formula NULL reuses the design's formula and matrix; a supplied formula builds a new design matrix.
skip_if_not_installed("multgee")

kk_design <- function(response_type, y_fun, n = 40L, seed = 1L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}
collect_warnings <- function(expr) {
	classes <- character(); messages <- character()
	value <- withCallingHandlers(expr, warning = function(w) {
		classes <<- c(classes, class(w)[1L]); messages <<- c(messages, conditionMessage(w)); invokeRestart("muffleWarning")
	})
	list(value = value, classes = classes, messages = messages)
}

test_that("under separation every jackknife method is NA with an edi_procedure_na_warning naming the separation reason", {
	des <- kk_design("ordinal", function(w) ifelse(w == 1, 4, sample(1:4, length(w), replace = TRUE)))
	expect_true(all(des$get_y()[des$get_w() == 1] == 4))
	inf <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)
	calls <- list(
		ci = function() inf$compute_jackknife_wald_confidence_interval(),
		estimate = function() inf$compute_jackknife_estimate(),
		se = function() inf$compute_jackknife_std_error(),
		pval = function() inf$compute_jackknife_wald_two_sided_pval()
	)
	for (nm in names(calls)) {
		res <- collect_warnings(calls[[nm]]())
		expect_true(all(is.na(res$value)), info = nm)
		expect_true("edi_procedure_na_warning" %in% res$classes, info = nm)
		na_msgs <- res$messages[res$classes == "edi_procedure_na_warning"]
		expect_true(any(grepl("jackknife_full_data_separation", na_msgs, fixed = TRUE)), info = nm)
	}
	expect_true(is.finite(suppressWarnings(inf$compute_estimate())))     # the point estimate is unchanged
})

test_that("completed KK designs with a non-ordinal response are rejected", {
	expect_error(InferenceOrdinalKKGEE$new(kk_design("count", function(w) rpois(length(w), 2))),
		"does not support response type 'count'")
	expect_error(InferenceOrdinalKKGEE$new(kk_design("continuous", function(w) rnorm(length(w)))),
		"does not support response type 'continuous'")
})

test_that("model_formula NULL uses the design's covariates; ~ x1 builds a predictor frame with w and x1 only", {
	des <- kk_design("ordinal", function(w) as.integer(cut(-0.4 * w + rnorm(length(w)), c(-Inf, -0.4, 0.4, Inf))), n = 50L, seed = 3L)
	p_null <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)$.__enclos_env__$private
	p_x1 <- InferenceOrdinalKKGEE$new(des, model_formula = ~ x1, verbose = FALSE)$.__enclos_env__$private
	pd_null <- p_null$gee_predictors_df()
	pd_x1 <- p_x1$gee_predictors_df()
	expect_identical(colnames(pd_null), c("w", "x1", "x2"))
	expect_identical(colnames(pd_x1), c("w", "x1"))
	expect_equal(pd_x1$w, des$get_w())
	expect_equal(unname(pd_x1$x1), unname(pd_null$x1))
})
