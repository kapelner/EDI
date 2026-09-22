library(testthat)
library(EDI)

# run_all_inference_format_pretty_table(results_table): builds the shared display via the already-tested run_all_inference_build_display_table(), then
# renders it as text lines using the already-tested run_all_inference_fmt_wrapped_row() -- both used directly here as the reference for a byte-for-byte
# independent reconstruction of the expected lines. Structure: header lines + "=" rule, one wrapped row block per table row (single physical line when
# compute_conf_intervals = FALSE / "ci_a" absent, two lines otherwise), a "-" rule inserted BETWEEN (not before the first, not doubled) each change of
# tbl$estimand group, one final "-" rule after the last row, and -- only when a cov_model letter key exists -- a blank line, "Cov mod key:", and one legend
# line per key entry. An empty results_table renders as the single string "(no rows)".

ns <- asNamespace("EDI")
format_pretty <- get("run_all_inference_format_pretty_table", envir = ns)
build_display <- get("run_all_inference_build_display_table", envir = ns)
fmt_row <- get("run_all_inference_fmt_wrapped_row", envir = ns)

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
# Independent line-by-line reconstruction from the same two already-tested building blocks the function itself uses.
ref_lines <- function(tbl) {
	built <- build_display(tbl)
	if (is.null(built)) return("(no rows)")
	headers <- names(built$display)
	header_lines <- fmt_row(headers, headers)
	total_width <- max(nchar(header_lines))
	lines <- c(header_lines, strrep("=", total_width))
	single_line <- !("ci_a" %in% headers)
	prev <- NULL
	for (i in seq_len(nrow(built$display))) {
		if (!is.null(prev) && !identical(built$tbl$estimand[[i]], prev)) lines <- c(lines, strrep("-", total_width))
		lines <- c(lines, fmt_row(as.character(built$display[i, ]), headers, single_line = single_line))
		prev <- built$tbl$estimand[[i]]
	}
	lines <- c(lines, strrep("-", total_width))
	if (length(built$cov_key) > 0L) {
		lines <- c(lines, "", "Cov mod key:")
		for (f in names(built$cov_key)) lines <- c(lines, sprintf('  (%s)  "%s"', built$cov_key[[f]], f))
	}
	lines
}

test_that("the full multi-estimand table matches an independent reconstruction from build_display_table() + fmt_wrapped_row()", {
	tbl <- mk_tbl()
	expect_identical(format_pretty(tbl), ref_lines(tbl))
})

test_that("a '-' rule separates estimand groups but never precedes the first row or doubles within one group", {
	out <- format_pretty(mk_tbl())
	rule_lines <- which(out == strrep("-", nchar(out[3])))
	expect_length(rule_lines, 2L)                                              # one between the two estimand groups, one final
	expect_true(rule_lines[1] > 4L)                                            # not immediately after the header/"=" rule
})

test_that("compute_conf_intervals = FALSE renders each row as one physical line instead of two", {
	tbl <- mk_tbl(); attr(tbl, "compute_conf_intervals") <- FALSE
	out <- format_pretty(tbl)
	expect_identical(out, ref_lines(tbl))
	expect_false(any(grepl("ci_a", out, fixed = TRUE)))
})

test_that("no cov_model letter key means no trailing legend block", {
	tbl <- mk_tbl(); tbl$cov_model <- rep(NA_character_, nrow(tbl))              # every row's formula becomes NA -> no key entries
	out <- format_pretty(tbl)
	expect_false(any(grepl("Cov mod key", out, fixed = TRUE)))
	expect_identical(out, ref_lines(tbl))
})

test_that("an empty results_table renders as exactly the single string '(no rows)'", {
	expect_identical(format_pretty(mk_tbl()[0, ]), "(no rows)")
})
