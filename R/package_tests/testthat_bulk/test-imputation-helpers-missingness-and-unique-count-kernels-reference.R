library(testthat)
library(EDI)

# imputation_helpers.cpp's three exported kernels (columns_have_missingness_cpp,
# create_missingness_indicators_cpp, count_unique_values_cpp), called from
# design_abstract.R's imputation/model-matrix-prep pipeline, had ZERO test references
# anywhere in the codebase -- confirmed via a codebase-wide grep for all three function
# names. Each dispatches per-column on TYPEOF (REALSXP/INTSXP/STRSXP/LGLSXP), with an
# "unknown type" default branch (found_na = FALSE / unique_count = 0 / indicator filled
# with 0) for anything else (e.g. complex, list-columns). A factor column is INTSXP under
# the hood, so it exercises the same integer branch as a plain integer column. Exercised
# directly on the exported kernels with hand-built data.frames, independent reference
# values computed inline.
#
# SUSPECTED SOURCE BUG (not fixed, per this session's standing instructions): passing a
# completely unnamed list/data.frame (names(df) <- NULL, which base R data.frame() itself
# rejects but a bare list built with list() does not) to create_missingness_indicators_cpp
# throws "Not compatible with STRSXP: [type=NULL]" instead of falling back to its
# documented "V<n>_is_missing" naming for the no-names case (the `else` arm at the bottom
# of its column loop) -- df.names() returns R_NilValue when there is no names attribute at
# all, and constructing a CharacterVector directly from that NULL SEXP throws rather than
# behaving like an empty CharacterVector. Not exercised here: design_abstract.R's real
# caller always passes a proper data.frame Ximp with column names, so this specific path
# is not reachable via the public R API today.

test_that("columns_have_missingness_cpp flags numeric/integer/character/logical/factor columns with an NA, and named results carry the column names", {
	df <- data.frame(
		num = c(1, NA, 3), int = c(1L, 2L, NA), chr = c("a", NA, "c"),
		lgl = c(TRUE, FALSE, NA), fac = factor(c("x", "y", NA)), clean = c(1, 2, 3)
	)
	res <- EDI:::columns_have_missingness_cpp(df)
	expect_equal(as.logical(res), c(TRUE, TRUE, TRUE, TRUE, TRUE, FALSE))
	expect_identical(names(res), names(df))
})

test_that("columns_have_missingness_cpp on a column of an unsupported type (complex) reports no missingness", {
	df <- data.frame(a = 1:3)
	df$b <- complex(real = c(1, 2, NA_real_), imaginary = 0)
	res <- EDI:::columns_have_missingness_cpp(df)
	expect_false(unname(res["b"]))
})

test_that("create_missingness_indicators_cpp produces a 0/1 indicator per requested column, named '<col>_is_missing'", {
	df <- data.frame(num = c(1, NA, 3), int = c(1L, 2L, NA), chr = c("a", NA, "c"), lgl = c(TRUE, FALSE, NA))
	res <- EDI:::create_missingness_indicators_cpp(df, c(1L, 2L, 3L, 4L))
	expect_identical(names(res), c("num_is_missing", "int_is_missing", "chr_is_missing", "lgl_is_missing"))
	expect_equal(res$num_is_missing, c(0L, 1L, 0L))
	expect_equal(res$int_is_missing, c(0L, 0L, 1L))
	expect_equal(res$chr_is_missing, c(0L, 1L, 0L))
	expect_equal(res$lgl_is_missing, c(0L, 0L, 1L))
})

test_that("create_missingness_indicators_cpp can select a subset of columns by 1-based index, matching R-to-C++ indexing", {
	df <- data.frame(a = c(1, NA), b = c(NA, 2), c = c(3, 4))
	res <- EDI:::create_missingness_indicators_cpp(df, 2L)
	expect_identical(names(res), "b_is_missing")
	expect_equal(res$b_is_missing, c(1L, 0L))
})

test_that("create_missingness_indicators_cpp on an unsupported-type column fills every row with 0", {
	df <- data.frame(a = 1:3)
	df$b <- complex(real = c(1, NA_real_, 3), imaginary = 0)
	res <- EDI:::create_missingness_indicators_cpp(df, 2L)
	expect_equal(res$b_is_missing, c(0L, 0L, 0L))
})

test_that("count_unique_values_cpp counts distinct non-NA values, plus one more if any NA is present, per type", {
	df <- data.frame(
		num = c(1, 1, 2, NA), int = c(1L, 2L, 2L, NA), chr = c("a", "a", "b", NA),
		lgl = c(TRUE, FALSE, TRUE, NA), fac = factor(c("x", "x", "y", NA)), clean = c(5, 5, 5, 5)
	)
	res <- EDI:::count_unique_values_cpp(df)
	expect_equal(as.integer(res), c(3L, 3L, 3L, 3L, 3L, 1L))
	expect_identical(names(res), names(df))
})

test_that("count_unique_values_cpp on an unsupported-type column reports zero", {
	df <- data.frame(a = 1:3)
	df$b <- complex(real = 1:3, imaginary = 0)
	res <- EDI:::count_unique_values_cpp(df)
	expect_equal(unname(res["b"]), 0L)
})
