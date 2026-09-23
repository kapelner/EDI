library(testthat)
library(EDI)

# imputation_helpers.cpp's columns_have_missingness_cpp / create_missingness_indicators_cpp /
# count_unique_values_cpp each switch on SEXP type (REALSXP/INTSXP/STRSXP/LGLSXP, default). The
# existing reference test (test-poisson-probit-kernels-hodges-lehmann-and-missingness-utility-
# reference.R) exercises only numeric and character columns; count_unique_values_cpp's own
# reference test (test-sandwich-hc2-...-reference.R) is the same. Neither ever passes a LOGICAL
# column with an NA, and none of the three functions' "unknown type" default branch (a list-column,
# e.g. called from design_abstract.R on arbitrary user covariate data.frames) had any test
# reference anywhere.
#
# Note (not a test target -- called out here since it was investigated): create_missingness_
# indicators_cpp's "col_names.size() <= col_idx" fallback name branch ("V<idx>_is_missing", line
# ~135) looks structurally reachable but isn't from R: R's names<-() always pads a shorter
# replacement to the object's full length with NA, so col_names.size() can never be smaller than
# the column count for any list/data.frame constructible from R. Not tested here.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("a logical column with NA is detected by columns_have_missingness_cpp", {
	df <- data.frame(a = c(TRUE, NA, FALSE, TRUE))
	expect_equal(K("columns_have_missingness_cpp")(df), c(a = TRUE))
	df2 <- data.frame(a = c(TRUE, FALSE, TRUE))
	expect_equal(K("columns_have_missingness_cpp")(df2), c(a = FALSE))
})

test_that("create_missingness_indicators_cpp builds the correct 0/1 indicator for a logical column", {
	df <- data.frame(a = c(TRUE, NA, FALSE, TRUE, NA))
	ind <- K("create_missingness_indicators_cpp")(df, 1L)
	expect_equal(names(ind), "a_is_missing")
	expect_equal(as.numeric(ind$a_is_missing), c(0, 1, 0, 0, 1))
})

test_that("count_unique_values_cpp counts a logical column's distinct values, NA included", {
	df <- data.frame(a = c(TRUE, NA, FALSE, TRUE))
	expect_equal(as.numeric(K("count_unique_values_cpp")(df)["a"]), 3)   # TRUE, FALSE, NA
	df2 <- data.frame(a = c(TRUE, TRUE, TRUE))
	expect_equal(as.numeric(K("count_unique_values_cpp")(df2)["a"]), 1)  # TRUE only
	df3 <- data.frame(a = c(TRUE, FALSE))
	expect_equal(as.numeric(K("count_unique_values_cpp")(df3)["a"]), 2)  # TRUE, FALSE, no NA
})

test_that("an unsupported column type (a list-column) silently falls through to the default branch for all three functions", {
	df <- list(x = c(1, NA, 3), y = list(1, 2, 3))
	flags <- K("columns_have_missingness_cpp")(df)
	expect_equal(flags, c(x = TRUE, y = FALSE))

	cu <- K("count_unique_values_cpp")(df)
	expect_equal(as.numeric(cu["x"]), 3)  # {1, 3} distinct + NA counted as its own value = 3
	expect_equal(as.numeric(cu["y"]), 0)

	ind <- K("create_missingness_indicators_cpp")(df, 2L)
	expect_equal(names(ind), "y_is_missing")
	expect_equal(as.numeric(ind$y_is_missing), c(0, 0, 0))
})
