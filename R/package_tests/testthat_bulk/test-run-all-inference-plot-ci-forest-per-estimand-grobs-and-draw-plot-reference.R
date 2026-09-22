library(testthat)
library(EDI)

# run_all_inference_plot_ci_forest(results_table, alpha): one gtable grob per DISTINCT estimand among usable ("ok" status) rows -- an estimand with no usable
# rows gets no list entry at all, not an empty placeholder -- named by the raw estimand string. Each grob carries edi_n_rows (the count of that estimand's
# own usable rows), edi_max_label_chars, and edi_height_in attributes, exactly what run_all_inference_plot_n_rows()/_plot_max_label_chars()/_plot_height_in()
# (already tested) read off it. An empty/all-unusable results_table gives an empty list. run_all_inference_draw_plot(p): draws a real grob to the active
# graphics device without error and returns invisible(NULL) -- checked on a null pdf() device so no real output is produced.

skip_if_not_installed("ggplot2")
ns <- asNamespace("EDI")
plot_ci_forest <- get("run_all_inference_plot_ci_forest", envir = ns)
draw_plot <- get("run_all_inference_draw_plot", envir = ns)
plot_n_rows <- get("run_all_inference_plot_n_rows", envir = ns)
plot_max_label_chars <- get("run_all_inference_plot_max_label_chars", envir = ns)
plot_height_in <- get("run_all_inference_plot_height_in", envir = ns)

mk_tbl <- function() data.frame(
	inference_class = c("InferenceContinOLS", "InferenceAllSimpleMeanDiffPooledVar", "InferenceIncidLogRegr"),
	cov_model = c("y ~ x1 + x2", NA_character_, NA_character_),
	estimand = c("mean_difference", "mean_difference", "log_odds_ratio_marginal"),
	tau = c(NA_real_, NA_real_, NA_real_),
	estimate = c(1.2345, 2.5, -0.5), se = c(0.2, 0.3, 0.1),
	ci_a = c(0.8, 2.0, -0.7), ci_b = c(1.7, 3.0, -0.3), ci_method = c("wald", "wald", "wald"),
	pval = c(0.045, 0.2, 0.01), pval_method = c("wald", "wald", "wald"), type = c(NA_character_, NA_character_, NA_character_),
	weight = c(0.5, 0.5, 1), status = c("ok", "ok", "error"), stringsAsFactors = FALSE
)

test_that("one gtable grob per distinct estimand among usable rows; an estimand whose only row has status = 'error' gets no entry at all", {
	tbl <- mk_tbl()
	plots <- plot_ci_forest(tbl, 0.05)
	expect_identical(names(plots), "mean_difference")                            # log_odds_ratio_marginal's single row is status = "error"
	expect_s3_class(plots[["mean_difference"]], "gtable")
})

test_that("edi_n_rows equals that estimand group's own count of usable rows, independent of other estimand groups' row counts", {
	tbl <- mk_tbl()
	plots <- plot_ci_forest(tbl, 0.05)
	p <- plots[["mean_difference"]]
	expect_equal(plot_n_rows(p), 2L)                                             # 2 ok rows tagged mean_difference
	tbl2 <- tbl; tbl2$status[3] <- "ok"                                          # now all 3 rows are usable, across 2 estimand groups
	plots2 <- plot_ci_forest(tbl2, 0.05)
	expect_setequal(names(plots2), c("mean_difference", "log_odds_ratio_marginal"))
	expect_equal(plot_n_rows(plots2[["mean_difference"]]), 2L)
	expect_equal(plot_n_rows(plots2[["log_odds_ratio_marginal"]]), 1L)
})

test_that("edi_max_label_chars / edi_height_in are set to positive finite values the reader helpers agree with exactly", {
	tbl <- mk_tbl()
	p <- plot_ci_forest(tbl, 0.05)[["mean_difference"]]
	expect_identical(plot_max_label_chars(p), as.integer(attr(p, "edi_max_label_chars")))
	expect_gt(plot_max_label_chars(p), 0L)
	expect_identical(plot_height_in(p), min(48, as.numeric(attr(p, "edi_height_in"))))
	expect_gt(plot_height_in(p), 0)
})

test_that("an all-unusable results_table gives an empty (zero-length) list, not an error or a placeholder entry", {
	tbl <- mk_tbl(); tbl$status <- rep("error", nrow(tbl))
	expect_identical(plot_ci_forest(tbl, 0.05), list())
	expect_identical(plot_ci_forest(tbl[0, ], 0.05), list())
})

test_that("run_all_inference_draw_plot draws a real grob without error and returns invisible(NULL)", {
	tbl <- mk_tbl()
	p <- plot_ci_forest(tbl, 0.05)[["mean_difference"]]
	null_dev <- grDevices::pdf(NULL)
	on.exit(grDevices::dev.off(), add = TRUE)
	res <- withVisible(draw_plot(p))
	expect_null(res$value)
	expect_false(res$visible)
})
