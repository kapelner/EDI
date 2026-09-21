library(testthat)
library(EDI)

# resolve_optimal_interest_z0_columns(X, interest): interest as character column names or a one-sided formula -> Z0 column
# indices (intercept occupies index 1, so +1). assertFormulaContext(formula, data, context) and
# assertStrataClusterArgs(strata_cols, cluster_col, data, strata_cols_must_be_factor, context) argument validators.

Z <- function(x) get(x, envir = asNamespace("EDI"))
res <- Z("resolve_optimal_interest_z0_columns")
X <- cbind(a = 1:6, b = c(2, 4, 1, 5, 3, 6), cc = c(0, 1, 0, 1, 1, 0))

test_that("character interest maps to model-matrix column positions + 1, in the order given, duplicates kept", {
	expect_identical(res(X, "a"), 2L)
	expect_identical(res(X, c("cc", "a")), c(4L, 2L))
	expect_identical(res(X, c("b", "b")), c(3L, 3L))
})

test_that("formula interest expands through model.matrix (intercept dropped, interactions and transforms named)", {
	expect_identical(res(X, ~ a + b), c(2L, 3L))
	expect_identical(res(X, ~ cc), 4L)
	expect_error(res(X, ~ a:b), "not found")                            # interaction column 'a:b' is not a design column
	expect_error(res(X, ~ log(b)), "not found")
	expect_error(res(X, ~ 1), "at least one covariate")
})

test_that("errors: no column names, empty selection, unmatched names listed with the available columns", {
	expect_error(res(unname(X), "a"), "has no column names")
	expect_error(res(X, character(0)), "at least one covariate column")
	expect_error(res(X, c("a", "zz", "yy")), "interest column\\(s\\) not found in the design's model matrix: zz, yy\\. Available columns: a, b, cc")
	expect_error(res(X, "zz"), "Factor covariates must be referred to by their expanded model-matrix column names")
})

test_that("assertFormulaContext: passes when every variable exists, ignores '.', errors listing the missing variables", {
	dat <- data.frame(x = 1, z = 2)
	f <- Z("assertFormulaContext")
	expect_null(f(~ x + z, dat)); expect_null(f(~ ., dat)); expect_null(f(NULL, dat)); expect_null(f(~ x, NULL))
	expect_error(f(~ x + a + b, dat), "model_formula contains variables not present in the available covariates: a, b\\.")
	expect_error(f(~ q, dat, context = "analysis formula"), "^analysis formula contains variables")
	expect_error(f(y ~ x, dat), "y\\.")                                              # response variable also needs to exist
	expect_error(f("not a formula", dat))
})

test_that("assertFormulaContext is a no-op when assertions are disabled", {
	withr::local_options(edi.run_asserts = FALSE)
	expect_null(Z("assertFormulaContext")(~ absent, data.frame(x = 1)))
})

test_that("assertStrataClusterArgs: type checks, cluster/strata overlap, missing columns, categorical requirement", {
	a <- Z("assertStrataClusterArgs")
	dat <- data.frame(g = factor(c("u", "v")), h = c("p", "q"), num = c(1, 2), cl = 1:2, stringsAsFactors = FALSE)
	expect_null(a()); expect_null(a(strata_cols = "g", data = dat)); expect_null(a(cluster_col = "cl", data = dat))
	expect_error(a(strata_cols = character(0)))
	expect_error(a(strata_cols = c("g", NA)))
	expect_error(a(cluster_col = c("cl", "g")))
	expect_error(a(strata_cols = c("g", "cl"), cluster_col = "cl"), "cluster_col must not also appear in strata_cols for strata/cluster arguments\\.")
	expect_error(a(strata_cols = "nope", data = dat, context = "my design"), "my design references column\\(s\\) not present in the supplied covariates: nope\\.")
	expect_error(a(strata_cols = "g", cluster_col = "zzz", data = dat), "zzz")
	expect_null(a(strata_cols = c("g", "h"), data = dat, strata_cols_must_be_factor = TRUE))    # factor and character are categorical
	expect_error(a(strata_cols = c("g", "num"), data = dat, strata_cols_must_be_factor = TRUE), "non-categorical column\\(s\\): num\\.")
	expect_null(a(strata_cols = "num", data = dat, strata_cols_must_be_factor = FALSE))
})

test_that("assertStrataClusterArgs is a no-op when assertions are disabled", {
	withr::local_options(edi.run_asserts = FALSE)
	expect_null(Z("assertStrataClusterArgs")(strata_cols = "zz", cluster_col = "zz", data = data.frame(x = 1)))
})
