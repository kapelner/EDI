library(testthat)
library(EDI)

# Three pure formatting/weighting helpers behind run_all_inference()'s combined-evidence summary, exercised directly on hand-built results_table data frames
# (no inference fitting needed):
#  * run_all_inference_estimand_grouped_weights(results_table): w_i = 1 / (G * group_size_i) for usable rows (status == "ok", finite pval); NA elsewhere. G is
#    the number of distinct estimand groups AMONG USABLE ROWS ONLY.
#  * run_all_inference_combined_evidence_summary_line(combined_evidence): a fixed sprintf template; "estimand_grouped" displays as "uniform within estimand",
#    every other weighting string displays verbatim; a non-finite pval displays as "NA", else 3 significant figures.
#  * run_all_inference_per_estimand_breakdown_lines(results_table): one line per distinct estimand among usable rows (status == "ok", finite pval, non-NA
#    estimand), each showing that group's own within-group combined p-value (via run_all_inference_combine_pvalues -- NA when the group has under 2 usable
#    rows); every line is padded to the same total width.

ns <- asNamespace("EDI")
grouped_weights <- get("run_all_inference_estimand_grouped_weights", envir = ns)
summary_line <- get("run_all_inference_combined_evidence_summary_line", envir = ns)
breakdown_lines <- get("run_all_inference_per_estimand_breakdown_lines", envir = ns)
combine_pvalues <- get("run_all_inference_combine_pvalues", envir = ns)

test_that("estimand_grouped_weights: 1 / (G * group_size) for usable rows, NA for error/non-finite-pval rows, G counted over usable rows only", {
	tab <- data.frame(status = c("ok", "ok", "ok", "ok", "error", "ok"), pval = c(0.1, 0.2, 0.3, NA, 0.5, 0.05),
		estimand = c("mean_difference", "mean_difference", "RR", "RR", "RR", "mean_difference"), stringsAsFactors = FALSE)
	w <- grouped_weights(tab)
	# usable rows: 1,2,3,6 (row 4 has NA pval, row 5 is an error) -> groups mean_difference (size 3: rows 1,2,6), RR (size 1: row 3) -> G = 2
	expect_equal(w, c(1 / (2 * 3), 1 / (2 * 3), 1 / (2 * 1), NA, NA, 1 / (2 * 3)))
	expect_equal(sum(w, na.rm = TRUE), 1, tolerance = 1e-10)                       # weights sum to 1 over usable rows
})

test_that("estimand_grouped_weights: no usable rows returns an all-NA vector of the same length as the table", {
	tab <- data.frame(status = c("error", "error"), pval = c(NA_real_, NA_real_), estimand = c("RR", "RR"), stringsAsFactors = FALSE)
	expect_identical(grouped_weights(tab), c(NA_real_, NA_real_))
	tab1 <- data.frame(status = "ok", pval = 0.2, estimand = "RR", stringsAsFactors = FALSE)          # a single usable row: weight 1
	expect_equal(grouped_weights(tab1), 1)
})

test_that("combined_evidence_summary_line follows the documented template, relabels 'estimand_grouped', and formats pval as NA or 3 sig figs", {
	expect_identical(
		summary_line(list(weighting = "estimand_grouped", n_estimand_groups = 3L, n_classes_used = 10L, pval = 0.048)),
		"Combined evidence against the sharp null across 3 estimands\n(10 inferences, weighting = uniform within estimand):\np = 0.048"
	)
	expect_identical(
		summary_line(list(weighting = "equal", n_estimand_groups = 2L, n_classes_used = 5L, pval = NA_real_)),
		"Combined evidence against the sharp null across 2 estimands\n(5 inferences, weighting = equal):\np = NA"
	)
	expect_identical(
		summary_line(list(weighting = "custom", n_estimand_groups = 1L, n_classes_used = 2L, pval = 0.0001234)),
		"Combined evidence against the sharp null across 1 estimands\n(2 inferences, weighting = custom):\np = 0.000123"
	)
})

test_that("per_estimand_breakdown_lines: one line per usable estimand group, its own within-group combined p-value, no line for NA-estimand/error rows", {
	tab <- data.frame(status = c("ok", "ok", "ok", "ok", "error"), pval = c(0.1, 0.2, 0.05, NA, 0.3),
		estimand = c("mean_difference", "mean_difference", "RR", NA, "RR"), tau = rep(NA_real_, 5), stringsAsFactors = FALSE)
	lines <- breakdown_lines(tab)
	expect_length(lines, 2L)
	md_combined <- combine_pvalues(c(0.1, 0.2))
	expect_match(lines[1], sprintf("Estimand: mean %s \\(2 inferences\\).*p = %s", "Δ", sub("^0", "0", sprintf("%.3f", md_combined$pval))))
	expect_match(lines[2], "Estimand: risk ratio \\(1 inferences\\).*p =\\s*NA")     # the RR group has only 1 usable row (row 5 is status = error) -> NA
})

test_that("per_estimand_breakdown_lines: lines are padded to a common width; empty input gives character(0)", {
	tab <- data.frame(status = rep("ok", 4L), pval = c(0.001, 0.002, 0.5, 0.99),
		estimand = c("mean_difference", "mean_difference", "hodges_lehmann_shift", "RR"), tau = rep(NA_real_, 4L), stringsAsFactors = FALSE)
	lines <- breakdown_lines(tab)
	expect_length(lines, 3L)
	expect_length(unique(nchar(lines)), 1L)                                       # all lines share one total width
	expect_true(all(startsWith(lines, "  Estimand: ")))
	expect_identical(breakdown_lines(data.frame(status = "error", pval = NA_real_, estimand = NA_character_)), character(0))
})
