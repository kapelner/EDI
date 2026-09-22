library(testthat)
library(EDI)

# run_all_inference_print_row(r, static, widths, headers): assembles one table row's display values (class/cov-model/estimand from `static`, est/se/ci_a/ci_b
# at 3 significant figures via the already-tested run_all_inference_sigfig(), pval in scientific notation, pval_method/ci_method via
# method_with_type_short_label()) and cat()s it through run_all_inference_fmt_wrapped_row() -- both already-tested helpers are used directly here as the
# independent reference for exact byte-for-byte output. The ci-method column blanks to "" (not "NA") whenever it is identical to the pval-method column
# (the common case); it stays non-blank when the two genuinely differ. When `headers` omits the CI columns (compute_conf_intervals = FALSE, "ci_a" not
# among headers), pval/pval_method/status are printed and the row collapses to ONE single-line-truncated physical line instead of two wrapped ones.

ns <- asNamespace("EDI")
print_row <- get("run_all_inference_print_row", envir = ns)
headers <- get("EDI_INFERENCE_SUITE_LIVE_TABLE_HEADERS", envir = ns)
widths <- get("EDI_INFERENCE_SUITE_TABLE_COL_WIDTH_CAPS", envir = ns)
sig <- get("run_all_inference_sigfig", envir = ns)
method_type_label <- get("method_with_type_short_label", envir = ns)
fmt_row <- get("run_all_inference_fmt_wrapped_row", envir = ns)

static <- list(inference_class_disp = "OLS", cov_model_disp = "~.", estimand_disp = "mean diff")
r <- list(estimate = 1.2345, se = 0.234, ci_a = 0.5, ci_b = 2.0, pval = 0.045, pval_method = "wald", ci_method = "wald", type = NA, status = "ok")

test_that("with the full CI headers: two physical lines, values match an independent construction from the already-tested formatting helpers", {
	out <- capture.output(print_row(r, static, widths, headers))
	expect_length(out, 2L)
	pval_disp <- method_type_label("wald", NA_character_)
	vals <- c("OLS", "~.", "mean diff", sig(1.2345, 3L), sig(0.234, 3L), sig(0.5, 3L), sig(2.0, 3L), sig(0.045, 3L, scientific = TRUE), pval_disp, "", "ok")
	ref <- fmt_row(vals, headers, single_line = FALSE)
	expect_identical(out, c(ref[1], ref[2]))
})

test_that("the ci-method column blanks to '' when it equals the pval-method column, and shows the real label when the two differ", {
	blank_out <- capture.output(print_row(r, static, widths, headers))
	expect_false(grepl("wald.*wald", blank_out[1]))                                  # only one "wald" appears, not two
	r2 <- utils::modifyList(r, list(ci_method = "rand_bootstrap"))
	diff_out <- capture.output(print_row(r2, static, widths, headers))
	expect_true(grepl("rand boot", diff_out[1], fixed = TRUE))
	pval_disp <- method_type_label("wald", NA_character_)
	vals2 <- c("OLS", "~.", "mean diff", sig(1.2345, 3L), sig(0.234, 3L), sig(0.5, 3L), sig(2.0, 3L), sig(0.045, 3L, scientific = TRUE),
		pval_disp, method_type_label("rand_bootstrap", NA_character_), "ok")
	ref2 <- fmt_row(vals2, headers, single_line = FALSE)
	expect_identical(diff_out, c(ref2[1], ref2[2]))
})

test_that("when headers omit the CI columns, the row collapses to one single-line-truncated physical line (no ci_a/ci_b/ci_method values)", {
	headers_noci <- setdiff(headers, c("ci_a", "ci_b", "ci method (if different)"))
	out <- capture.output(print_row(r, static, widths, headers_noci))
	expect_length(out, 1L)
	pval_disp <- method_type_label("wald", NA_character_)
	vals <- c("OLS", "~.", "mean diff", sig(1.2345, 3L), sig(0.234, 3L), sig(0.045, 3L, scientific = TRUE), pval_disp, "ok")
	ref <- fmt_row(vals, headers_noci, single_line = TRUE)
	expect_identical(out, ref)
})
