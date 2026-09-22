library(testthat)
library(EDI)

# run_all_inference_format_html_table(results_table): the HTML counterpart of run_all_inference_format_pretty_table(), built on the same shared
# run_all_inference_build_display_table() (already tested) but never wraps cells (an HTML table has no fixed-width constraint) and every cell/key entry is
# escaped via htmltools_escape_or_identity() (already tested). Structure: a <table class="results"> with one <th> per display column in <thead>, one <tr
# class="status-<status>[ group-start]"> per row with one <td> per cell in <tbody> -- "group-start" is added on the first row of a NEW estimand group
# (never the very first row overall), "status-<status>" always reflects that row's own status verbatim. cov_key becomes an <h2>/<ul> block with one <li>
# per entry (empty string when there is no key). An empty results_table gives table_html = "<p>(no rows)</p>", key_html = "".

ns <- asNamespace("EDI")
format_html <- get("run_all_inference_format_html_table", envir = ns)
build_display <- get("run_all_inference_build_display_table", envir = ns)
esc <- get("htmltools_escape_or_identity", envir = ns)

mk_tbl <- function() data.frame(
	inference_class = c("InferenceContinOLS", "InferenceAllSimpleMeanDiffPooledVar", "InferenceIncidLogRegr"),
	cov_model = c("y ~ x1 + x2", NA, "y ~ x1 + x2"),
	estimand = c("mean_difference", "mean_difference", "log_odds_ratio_marginal"),
	tau = c(NA_real_, NA_real_, NA_real_),
	estimate = c(1.2345, 2.5, -0.5), se = c(0.2, 0.3, 0.1),
	ci_a = c(0.8, 2.0, -0.7), ci_b = c(1.7, 3.0, -0.3), ci_method = c("wald", "wald", "wald"),
	pval = c(0.045, 0.2, 0.01), pval_method = c("wald", "wald", "wald"), type = c(NA_character_, NA_character_, NA_character_),
	weight = c(0.5, 0.5, 1), status = c("ok", "error", "ok"), stringsAsFactors = FALSE
)

test_that("the header row has one <th> per display column, in the display's own column order and escaped", {
	tbl <- mk_tbl()
	built <- build_display(tbl)
	out <- format_html(tbl)
	expected_header <- paste0("<th>", esc(names(built$display)), "</th>", collapse = "")
	expect_match(out$table_html, expected_header, fixed = TRUE)
	expect_match(out$table_html, '<table class="results">', fixed = TRUE)
})

test_that("each row's class is status-<status>, with group-start added only on the first row of a NEW estimand group", {
	tbl <- mk_tbl()
	out <- format_html(tbl)
	built <- build_display(tbl)
	# sorted order: row1 (logodds, status ok, first overall -> no group-start), row2 (mean_difference, status error, NEW group -> group-start),
	# row3 (mean_difference, status ok, same group as row2 -> no group-start)
	expect_match(out$table_html, '<tr class="status-ok">', fixed = TRUE)
	expect_match(out$table_html, '<tr class="status-error group-start">', fixed = TRUE)
	expect_false(grepl('<tr class="status-ok group-start">', out$table_html, fixed = TRUE))    # the 3rd (ok) row is mid-group, not group-start
	expect_identical(lengths(regmatches(out$table_html, gregexpr("group-start", out$table_html))), 1L)   # exactly one group-start row
})

test_that("cells are escaped and never <br>-wrapped, even for a long class label that the text table would split onto two lines", {
	tbl <- mk_tbl()
	out <- format_html(tbl)
	built <- build_display(tbl)
	for (v in as.character(built$display[1, ])) {
		if (nzchar(v)) expect_match(out$table_html, paste0("<td>", esc(v), "</td>"), fixed = TRUE, info = v)
	}
	expect_false(grepl("<br", out$table_html, fixed = TRUE))
})

test_that("HTML-special characters in a cov_model formula are escaped in the cov-key legend, and the key lists one <li> per distinct formula", {
	tbl <- mk_tbl(); tbl$cov_model[c(1, 3)] <- "y ~ x1 & x2 < x3"
	out <- format_html(tbl)
	expect_match(out$key_html, "<h2>Cov mod key</h2>", fixed = TRUE)
	expect_match(out$key_html, "y ~ x1 &amp; x2 &lt; x3", fixed = TRUE)
	expect_false(grepl("x1 & x2", out$key_html, fixed = TRUE))                     # the raw unescaped string never appears
	expect_length(gregexpr("<li>", out$key_html)[[1]], 1L)                         # both rows share one formula -> one key entry
})

test_that("no cov_model letter key gives an empty key_html string", {
	tbl <- mk_tbl(); tbl$cov_model <- rep(NA_character_, nrow(tbl))
	out <- format_html(tbl)
	expect_identical(out$key_html, "")
})

test_that("an empty results_table gives the documented placeholder table and an empty key", {
	out <- format_html(mk_tbl()[0, ])
	expect_identical(out$table_html, "<p>(no rows)</p>")
	expect_identical(out$key_html, "")
})
