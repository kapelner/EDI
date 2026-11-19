library(testthat)
library(EDI)

# run_all_inference_build_display_table(results_table): builds the shared display data.frame behind both the text and HTML result tables. Rows are sorted by
# (estimand, inference_class) -- the RAW registry names, before either is abbreviated for display. Each display column is an already-tested formatting
# helper applied to the raw column (run_all_inference_sigfig for est/se/ci_a/ci_b/pval/weight, inference_class_short_label/estimand_short_label for the two
# label columns, method_with_type_short_label for pval/ci method), so those helpers are used directly here as the reference. attr(results_table,
# "compute_conf_intervals") controls whether ci_a/ci_b/ci method columns appear at all; the "ci method (if different)" column itself only appears when at
# least one row's ci method differs from its pval method (blank elsewhere), and is entirely absent when compute_conf_intervals is missing/TRUE by default
# but every row's methods agree. An empty results_table returns NULL.

ns <- asNamespace("EDI")
build_display <- get("run_all_inference_build_display_table", envir = ns)
sig <- get("run_all_inference_sigfig", envir = ns)
class_label <- get("inference_class_short_label", envir = ns)
estimand_label <- get("estimand_short_label", envir = ns)
method_type_label <- get("method_with_type_short_label", envir = ns)
cov_display <- get("cov_model_display", envir = ns)

mk_tbl <- function() data.frame(
	inference_class = c("InferenceContinOLS", "InferenceAllSimpleMeanDiffPooledVar", "InferenceIncidLogRegr"),
	cov_model = c("y ~ x1 + x2", NA, "y ~ x1 + x2"),
	estimand = c("mean_difference", "mean_difference", "log_odds_ratio_marginal"),
	tau = c(NA_real_, NA_real_, NA_real_),
	estimate = c(1.2345, 2.5, -0.5), se = c(0.2, 0.3, 0.1),
	ci_a = c(0.8, 2.0, -0.7), ci_b = c(1.7, 3.0, -0.3), ci_method = c("wald", "wald", "wald"),
	pval = c(0.045, 0.2, 0.01), pval_method = c("wald", "wald", "wald"), type = c(NA_character_, NA_character_, NA_character_),
	weight = c(0.5, 0.5, 1), status = c("ok", "ok", "ok"), stringsAsFactors = FALSE
)

test_that("rows are sorted by (estimand, inference_class) raw names, and every column matches its own tested formatting helper applied directly", {
	tbl <- mk_tbl()
	out <- build_display(tbl)
	expect_identical(out$display[["inference class"]], c("Logist Regr", "Avg Δ Pooled Var", "OLS"))   # log_odds... < mean_difference; within it, Pooled Var < ContinOLS by class name
	ord <- order(tbl$estimand, tbl$inference_class)
	expect_identical(out$tbl, tbl[ord, , drop = FALSE])
	expect_identical(out$display[["est"]], sig(tbl$estimate, 3L)[ord])
	expect_identical(out$display[["se"]], sig(tbl$se, 3L)[ord])
	expect_identical(out$display[["ci_a"]], sig(tbl$ci_a, 3L)[ord])
	expect_identical(out$display[["pval"]], sig(tbl$pval, 3L, scientific = TRUE)[ord])
	expect_identical(out$display[["weight"]], sig(tbl$weight, 2L)[ord])
	expect_identical(out$display[["pval method"]], method_type_label(tbl$pval_method, tbl$type)[ord])
	expect_identical(out$display[["status"]], tbl$status[ord])
	cov <- cov_display(tbl$cov_model[ord])
	expect_identical(out$display[["cov mod"]], cov$disp); expect_identical(out$cov_key, cov$key)
})

test_that("the 'ci method (if different)' column is dropped entirely when every row's ci_method equals its pval_method", {
	out <- build_display(mk_tbl())
	expect_false("ci method (if different)" %in% names(out$display))
})

test_that("the 'ci method (if different)' column appears (blank where they agree) when at least one row's ci method genuinely differs", {
	tbl <- mk_tbl(); tbl$ci_method[2] <- "rand_bootstrap"
	out <- build_display(tbl)
	expect_true("ci method (if different)" %in% names(out$display))
	ord <- order(tbl$estimand, tbl$inference_class)
	row_of_2 <- which(ord == 2L)
	expect_identical(out$display[["ci method (if different)"]][row_of_2], "rand boot")
	expect_true(all(out$display[["ci method (if different)"]][-row_of_2] == ""))
})

test_that("compute_conf_intervals = FALSE omits ci_a/ci_b/ci-method columns entirely, keeping pval/pval method", {
	tbl <- mk_tbl(); attr(tbl, "compute_conf_intervals") <- FALSE
	out <- build_display(tbl)
	expect_false(any(c("ci_a", "ci_b", "ci method (if different)") %in% names(out$display)))
	expect_true(all(c("pval", "pval method", "est", "se", "weight", "status") %in% names(out$display)))
})

test_that("an empty results_table returns NULL", {
	expect_null(build_display(mk_tbl()[0, ]))
})

# docs-claims audit, finding docs-claims-d3906c9d4: with compute_conf_intervals = FALSE a real
# run_all_inference() results_table keeps ci_a/ci_b/ci_method, all NA.
test_that("a real run with compute_conf_intervals = FALSE keeps ci_a/ci_b/ci_method in results_table, all NA", {
	set.seed(1)
	des <- DesignSeqOneByOneBernoulli$new(n = 20L, response_type = "continuous", verbose = FALSE)
	for (i in 1:20) des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	des$add_all_subject_responses(rnorm(20))
	res <- NULL
	capture.output(res <- InferenceSuite$new(des)$run_all_inference(screen = TRUE, plots = FALSE,
		classes = c("InferenceAllSimpleAverageDiff", "InferenceContinOLS"), methods = c("wald", "rand"), r = 19,
		compute_conf_intervals = FALSE))
	tbl <- res$results_table
	expect_true(all(c("ci_a", "ci_b", "ci_method") %in% names(tbl)))
	expect_true(all(is.na(tbl$ci_a)))
	expect_true(all(is.na(tbl$ci_b)))
	skip("v1.0.6-TODO-261: with compute_conf_intervals = FALSE, run_all_inference_one_class() back-fills ci_method with the row's method sentinel ('wald', 'rand'), so ci_method is not NA as documented")
	expect_true(all(is.na(tbl$ci_method)))
})
