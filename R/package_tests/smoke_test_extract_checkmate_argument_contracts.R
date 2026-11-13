#!/usr/bin/env Rscript

# read.csv() calls in this file go through read_csv_fast(): fread-backed, same
# result as read.csv (R/package_tests/read_csv_fast.R), loaded from the checkout.
if (!exists("read_csv_fast", mode = "function")) local({
	script = sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
	for (d in c(getwd(), if (!is.na(script)) dirname(script))) {
		top = tryCatch(suppressWarnings(system2("git", c("-C", shQuote(d), "rev-parse", "--show-toplevel"), stdout = TRUE, stderr = FALSE)), error = function(e) character())
		helper = if (length(top)) file.path(top[1], "R", "package_tests", "read_csv_fast.R") else ""
		if (nzchar(helper) && file.exists(helper)) { sys.source(helper, envir = parent.env(environment())); break }
	}
	if (!exists("read_csv_fast", mode = "function")) stop("read_csv_fast.R not found: run from inside the EDI git checkout.", call. = FALSE)
})

path = "package_tests/checkmate_argument_contracts.csv"
if (!file.exists(path)) {
	stop("Missing ", path, ". Run package_tests/extract_checkmate_argument_contracts.R first.", call. = FALSE)
}

contracts = read_csv_fast(path, stringsAsFactors = FALSE)
required_cols = c(
	"api_name", "api_kind", "class_name", "method_name", "arg", "default_expr",
	"assertion", "choices", "lower", "upper", "len", "min_len", "max_len",
	"positive", "null_ok", "any_missing", "source_file", "source_line",
	"coverage_scope", "inside_should_run_asserts"
)
missing_cols = setdiff(required_cols, names(contracts))
if (length(missing_cols)) {
	stop("Missing expected contract columns: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

assert_has = function(assertion) {
	n = sum(contracts$assertion == assertion, na.rm = TRUE)
	if (n <= 0L) stop("Expected at least one ", assertion, " contract.", call. = FALSE)
	invisible(n)
}

assert_has("assertChoice")
assert_has("assertNumeric")
assert_has("assertCount")
assert_has("assertFormula")

if (!any(nzchar(contracts$choices), na.rm = TRUE)) {
	stop("Expected at least one extracted choices domain.", call. = FALSE)
}
if (!any(nzchar(contracts$lower) | nzchar(contracts$upper), na.rm = TRUE)) {
	stop("Expected at least one extracted numeric bound.", call. = FALSE)
}
if (!all(contracts$coverage_scope == "public_contract")) {
	stop("Phase 1 smoke test expects public_contract coverage scope rows only.", call. = FALSE)
}
if (!all(!is.na(contracts$source_line))) {
	stop("Expected all extracted contracts to preserve source lines.", call. = FALSE)
}

message("Phase 1 extractor smoke test passed with ", nrow(contracts), " contract rows.")
