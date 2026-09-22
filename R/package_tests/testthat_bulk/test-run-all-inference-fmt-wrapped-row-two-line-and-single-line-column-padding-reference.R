library(testthat)
library(EDI)

# run_all_inference_fmt_wrapped_row(vals, headers, single_line): renders one table row as two space-joined, fixed-width-padded physical lines by default (each
# cell wrapped via the already-tested run_all_inference_wrap_cell_2lines() at its own EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS[header] width), or a single
# physical line (each cell ellipsis-truncated via run_all_inference_truncate_1line(), NOT wrap_cell_2lines() + drop line 2 -- the two give different results
# for text that would otherwise wrap) when single_line = TRUE. NA values display as "NA". Every physical line has the same total width: the widths of the
# selected headers plus 2 spaces between every pair of columns.

ns <- asNamespace("EDI")
fmt_row <- get("run_all_inference_fmt_wrapped_row", envir = ns)
wrap2 <- get("run_all_inference_wrap_cell_2lines", envir = ns)
trunc1 <- get("run_all_inference_truncate_1line", envir = ns)
caps <- get("EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS", envir = ns)

test_that("two-line mode matches wrap_cell_2lines()'s own line 1 / line 2 for each cell, space-joined and padded to width", {
	headers <- c("inference class", "cov mod", "estimand")
	vals <- c("KK CLMM Cauchit", "~.", "mean diff")
	got <- fmt_row(vals, headers)
	widths <- caps[headers]
	cells <- mapply(wrap2, vals, widths, SIMPLIFY = FALSE)
	ref <- c(
		paste(mapply(function(c, w) formatC(c[[1]], width = -w), cells, widths), collapse = "  "),
		paste(mapply(function(c, w) formatC(c[[2]], width = -w), cells, widths), collapse = "  ")
	)
	expect_identical(got, ref)
	expect_length(got, 2L)
	expect_identical(nchar(got), rep(sum(widths) + 2L * (length(headers) - 1L), 2L))     # both lines share one total width
})

test_that("single_line = TRUE truncates each cell with an ellipsis rather than dropping wrap_cell_2lines()'s discarded second line", {
	headers <- c("inference class", "cov mod")
	vals <- c("KK CLMM Cauchit", "~.")
	got <- fmt_row(vals, headers, single_line = TRUE)
	widths <- caps[headers]
	ref <- paste(mapply(function(v, w) formatC(trunc1(v, w), width = -w), vals, widths), collapse = "  ")
	expect_identical(got, ref)
	expect_length(got, 1L)                                           # a single physical line, not c(line, "")
	expect_true(grepl("…", got))                                 # the long class name is ellipsis-truncated, not silently dropped to "KK CLMM"
	expect_false(grepl("^KK CLMM  ", got))                            # the bug this mode fixed: wrap_cell_2lines's line 1 alone would read "KK CLMM"
})

test_that("NA values display as the literal string 'NA' in both modes", {
	headers <- c("inference class", "cov mod", "estimand")
	got2 <- fmt_row(c(NA, NA, NA), headers)
	widths <- caps[headers]
	expect_identical(got2[1], paste(vapply(widths, function(w) formatC("NA", width = -w), ""), collapse = "  "))
	expect_identical(trimws(got2[2]), "")                             # the wrapped second line is empty for a value that fits on one line
	got1 <- fmt_row(c(NA, NA, NA), headers, single_line = TRUE)
	expect_identical(got1, paste(vapply(widths, function(w) formatC("NA", width = -w), ""), collapse = "  "))
})

test_that("a short value that fits within its column width is not truncated or wrapped in either mode", {
	headers <- c("estimand")
	expect_identical(fmt_row("RR", headers, single_line = TRUE), formatC("RR", width = -caps[["estimand"]]))
	expect_identical(fmt_row("RR", headers)[1], formatC("RR", width = -caps[["estimand"]]))
	expect_identical(trimws(fmt_row("RR", headers)[2]), "")
})
