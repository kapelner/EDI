library(testthat)
library(EDI)

# simulations_framework.R's generate_covariate_dataset(n, p, ..., X_mat, cov_draw_method, ...) has
# three argument-shape guards, none exercised by any existing test (confirmed via codebase-wide
# grep for each exact message -- "simulations_framework" is "closed already" per this session's
# standing list, but that closure covered the render/parallel-dispatch layer, not this standalone
# argument-validation surface):
#   1. Supplying BOTH X_mat and a non-NULL cov_draw_method (the default) is rejected -- callers
#      supplying their own X_mat must also explicitly pass cov_draw_method = NULL.
#   2. Supplying NEITHER (both NULL) is rejected.
#   3. cond_exp_func_model = "nonlinear" (the Friedman 1991 function) requires p >= 5; a p < 5
#      nonlinear request is rejected.
# Exercised via a direct namespace call, no simulation/design fixture needed -- a lightweight,
# pure-function target.

test_that("supplying both X_mat and the default (non-NULL) cov_draw_method is rejected", {
	expect_error(
		EDI:::generate_covariate_dataset(10, 3, X_mat = matrix(rnorm(30), 10, 3)),
		"generate_covariate_dataset: supply exactly one of 'X_mat' or 'cov_draw_method', not both.",
		fixed = TRUE
	)
})

test_that("supplying neither X_mat nor cov_draw_method is rejected", {
	expect_error(
		EDI:::generate_covariate_dataset(10, 3, cov_draw_method = NULL),
		"generate_covariate_dataset: one of 'X_mat' or 'cov_draw_method' must be non-NULL.",
		fixed = TRUE
	)
})

test_that("a nonlinear (Friedman) covariate model with p < 5 is rejected", {
	expect_error(
		EDI:::generate_covariate_dataset(10, 3, cond_exp_func_model = "nonlinear"),
		"Friedman nonlinear cond_exp_func_model requires p >= 5.",
		fixed = TRUE
	)
})

test_that("a nonlinear (Friedman) covariate model with p >= 5 is accepted", {
	set.seed(1)
	res <- EDI:::generate_covariate_dataset(20, 5, cond_exp_func_model = "nonlinear")
	expect_equal(nrow(res$X), 20L)
	expect_equal(ncol(res$X), 5L)
	expect_length(res$y_cont, 20L)
	expect_true(all(is.finite(res$y_cont)))
})

test_that("explicitly passing X_mat alone (cov_draw_method = NULL) is accepted, and column names default to x1..xp", {
	Xm <- matrix(rnorm(30), 10, 3)
	res <- EDI:::generate_covariate_dataset(10, 3, X_mat = Xm, cov_draw_method = NULL)
	expect_identical(colnames(res$X), c("x1", "x2", "x3"))
	expect_equal(unname(as.matrix(res$X)), unname(Xm))
})
