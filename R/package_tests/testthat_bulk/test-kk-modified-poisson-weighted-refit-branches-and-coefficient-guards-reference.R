library(testthat)
library(EDI)

# InferenceIncidKKModifiedPoisson (abstract InferenceAbstractKKModifiedPoisson):
# compute_estimate_with_bootstrap_weights() branches (effectively-constant weights,
# zero/invalid weights, NA when the design matrix is missing, agreement with a
# weighted Poisson glm), and the small guards coefficients_are_usable() and
# set_failed_fit_cache(), plus the SE/df accessors.

mk <- function(seed = 5L, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	priv <- inf$.__enclos_env__$private
	unlockBinding("expand_subject_or_block_weights_to_row_weights", priv)
	priv$expand_subject_or_block_weights_to_row_weights <- function(w) w
	list(inf = inf, priv = priv, n = n)
}

test_that("weighted refit matches a weighted Poisson glm on the same design and does not disturb the unweighted estimate", {
	f <- mk()
	est0 <- f$inf$compute_estimate()
	se0 <- f$priv$get_standard_error()
	set.seed(2)
	wts <- rexp(f$n)
	got <- f$inf$compute_estimate_with_bootstrap_weights(wts)
	X <- as.matrix(f$priv$build_design_matrix())
	ref <- unname(coef(suppressWarnings(glm(f$priv$y ~ X - 1, family = poisson, weights = wts)))[2])
	expect_equal(got, ref, tolerance = 5e-3)
	expect_equal(f$inf$compute_estimate(), est0)
	expect_equal(f$priv$get_standard_error(), se0)
})

test_that("effectively-constant weights short-circuit to the unweighted estimate", {
	f <- mk()
	est0 <- f$inf$compute_estimate()
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rep(2.5, f$n)), est0, tolerance = 1e-8)
})

test_that("rows with zero or non-finite weight are dropped from the fit", {
	f <- mk()
	set.seed(3)
	wts <- rexp(f$n)
	wts[c(2, 7)] <- 0
	got <- f$inf$compute_estimate_with_bootstrap_weights(wts)
	keep <- wts > 0
	X <- as.matrix(f$priv$build_design_matrix())
	ref <- unname(coef(suppressWarnings(glm(f$priv$y[keep] ~ X[keep, ] - 1, family = poisson, weights = wts[keep])))[2])
	expect_equal(got, ref, tolerance = 5e-3)
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n))))
})

test_that("a missing design matrix gives NA", {
	f <- mk()
	unlockBinding("build_design_matrix", f$priv)
	f$priv$build_design_matrix <- function() NULL
	set.seed(4)
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rexp(f$n))))
})

test_that("coefficients_are_usable requires finite values within max_abs_reasonable_coef", {
	f <- mk()
	u <- f$priv$coefficients_are_usable
	expect_equal(f$priv$max_abs_reasonable_coef, 25)
	expect_true(u(c(0.5, -3, 25)))
	expect_false(u(c(0.5, 25.01)))
	expect_false(u(c(-26, 0)))
	expect_false(u(c(1, NA)))
	expect_false(u(c(1, Inf)))
	expect_false(u(numeric(0)))
})

test_that("set_failed_fit_cache marks the estimate nonestimable and clears fit artifacts", {
	f <- mk()
	f$inf$compute_estimate()
	f$priv$cached_values$full_coefficients <- c(a = 1)
	f$priv$cached_values$full_vcov <- diag(1)
	f$priv$cached_values$summary_table <- data.frame(a = 1)
	f$priv$set_failed_fit_cache()
	expect_null(f$priv$cached_values$full_coefficients)
	expect_null(f$priv$cached_values$full_vcov)
	expect_null(f$priv$cached_values$summary_table)
	expect_true(f$inf$is_nonestimable("estimate"))
})

test_that("standard error and df accessors default safely", {
	f <- mk()
	f$inf$compute_estimate()
	expect_true(is.finite(f$priv$get_standard_error()) && f$priv$get_standard_error() > 0)
	f$priv$cached_values$df <- NULL
	expect_equal(f$priv$get_degrees_of_freedom(), Inf)
	f$priv$cached_values$df <- 17
	expect_equal(f$priv$get_degrees_of_freedom(), 17)
	expect_true(f$priv$is_a_kk_modified_poisson())
})
