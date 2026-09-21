library(testthat)
library(EDI)

# Design design_formula handling: default ~ ., get_design_formula() echo, construction-time formula validation, effect of the
# formula on the model matrix (get_X) versus the raw covariates (get_X_raw), factor expansion via model.matrix, and has_private_method().
# References: stats::model.matrix without its intercept column.

dat <- data.frame(x1 = 1:6, x2 = c(2, 1, 4, 3, 6, 5), x3 = 6:1, g = factor(rep(c("a", "b", "c"), 2)))
mk <- function(formula = NULL, ...) {
	args <- list(response_type = "continuous", n = 6L, seed = 1L, verbose = FALSE, ...)
	if (!is.null(formula)) args$design_formula <- formula
	d <- do.call(DesignFixedBernoulli$new, args); d$add_all_subjects_to_experiment(dat); d
}

test_that("default formula is ~ . and a supplied formula is returned unchanged", {
	expect_identical(deparse(mk()$get_design_formula()), "~.")
	f <- ~ x1 + x2
	expect_identical(deparse(mk(f)$get_design_formula()), deparse(f))
	expect_s3_class(mk(f)$get_design_formula(), "formula")
})

test_that("only formulas are accepted", {
	expect_error(DesignFixedBernoulli$new(response_type = "continuous", n = 6L, design_formula = "x1", seed = 1L, verbose = FALSE), "Must be a formula")
	expect_error(DesignFixedBernoulli$new(response_type = "continuous", n = 6L, design_formula = 3, seed = 1L, verbose = FALSE))
})

test_that("the model matrix follows the formula (intercept dropped) while raw covariates keep every column", {
	d <- mk(~ x1 + x2)
	expect_identical(colnames(d$get_X()), c("x1", "x2"))
	expect_equal(unname(d$get_X()), unname(model.matrix(~ x1 + x2, dat)[, -1]), tolerance = 1e-12)
	expect_identical(colnames(d$get_X_raw()), c("x1", "x2", "x3", "g"))
	all_cols <- mk()
	expect_true(all(c("x1", "x2", "x3") %in% colnames(all_cols$get_X())))
})

test_that("factors are expanded to treatment contrasts; transformations and interactions are supported", {
	d <- mk(~ g)
	expect_identical(colnames(d$get_X()), c("gb", "gc"))
	expect_equal(unname(d$get_X()), unname(model.matrix(~ g, dat)[, -1]))
	e <- mk(~ x1 + I(x2^2) + x1:x3)
	expect_equal(unname(e$get_X()), unname(model.matrix(~ x1 + I(x2^2) + x1:x3, dat)[, -1]), tolerance = 1e-12)
})

test_that("a formula referencing a missing variable fails when covariates arrive", {
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = 6L, design_formula = ~ nope, seed = 1L, verbose = FALSE)
	expect_error(d$add_all_subjects_to_experiment(dat))
})

test_that("has_private_method probes only this object's own private environment", {
	p <- mk()$.__enclos_env__$private
	expect_true(p$has_private_method("assign_wt_Bernoulli")); expect_true(p$has_private_method("has_private_method"))
	expect_false(p$has_private_method("definitely_not_a_method")); expect_false(p$has_private_method("get_n"))         # public, not private
})
