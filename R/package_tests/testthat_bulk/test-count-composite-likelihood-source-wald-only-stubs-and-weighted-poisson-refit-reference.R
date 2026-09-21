library(testthat)
library(EDI)

# CountCompositeLikelihood source (composed by InferenceCountQuasiPoisson): Wald-only capability flags, the
# score / gradient unsupported stops, and compute_estimate_with_bootstrap_weights() (weighted Poisson refit; constant
# weights reuse the unweighted estimate; zero-weight rows are dropped). Independent reference: stats::glm with
# family = poisson and the same weights.

mk <- function(seed = 2L, n = 60L) {
	set.seed(seed)
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	X <- data.frame(x1 = rnorm(n)); d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w(); y <- rpois(n, exp(0.2 + 0.4 * w + 0.3 * X$x1)); d$add_all_subject_responses(y)
	inf <- InferenceCountQuasiPoisson$new(d, verbose = FALSE); p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- list(row_to_unit = seq_len(n), unit_group_id = rep(1L, n), n_units = n)
	list(inf = inf, p = p, y = y, w = w, x1 = X$x1, n = n)
}
f <- mk()

test_that("Wald is the only supported testing type and likelihood-based tests are disabled", {
	expect_false(f$p$supports_likelihood_tests()); expect_false(f$p$supports_lik_ratio_param_bootstrap())
	expect_identical(f$p$get_supported_testing_types_impl(), "wald")
	expect_identical(f$inf$get_supported_testing_types(), "wald")
})

test_that("score and gradient inference stop with class-named messages", {
	expect_error(f$p$compute_score_two_sided_pval_impl(0), "InferenceCountQuasiPoisson does not support score p-values")
	expect_error(f$p$compute_score_confidence_interval_impl(0.05), "does not support score confidence intervals")
	expect_error(f$p$compute_gradient_two_sided_pval_impl(0), "does not support gradient p-values")
	expect_error(f$p$compute_gradient_confidence_interval_impl(0.05), "does not support gradient confidence intervals")
})

test_that("the point estimate is the quasi-Poisson treatment coefficient", {
	expect_equal(f$inf$compute_estimate(), unname(coef(glm(f$y ~ f$w + f$x1, family = quasipoisson))[2]), tolerance = 1e-6)
})

test_that("weighted refit equals a weighted Poisson glm and the unweighted estimate is restored afterwards", {
	unweighted <- f$inf$compute_estimate()
	set.seed(5); wt <- rexp(f$n) + 0.1
	b <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	expect_equal(b, unname(coef(glm(f$y ~ f$w + f$x1, family = poisson, weights = wt))[2]), tolerance = 1e-6)
	expect_false(isTRUE(all.equal(b, unweighted)))
	expect_equal(f$inf$compute_estimate(), unweighted, tolerance = 1e-10)
})

test_that("zero-weight rows are dropped from the refit", {
	g <- mk(); set.seed(6); wt <- rexp(g$n) + 0.1; wz <- wt; wz[1:6] <- 0
	keep <- -(1:6)
	ref <- unname(coef(glm(g$y[keep] ~ g$w[keep] + g$x1[keep], family = poisson, weights = wt[keep]))[2])
	expect_equal(g$inf$compute_estimate_with_bootstrap_weights(wz), ref, tolerance = 1e-6)
})

test_that("effectively constant weights return the unweighted estimate (scale-free)", {
	g <- mk(); u <- g$inf$compute_estimate()
	expect_equal(g$inf$compute_estimate_with_bootstrap_weights(rep(2, g$n)), u, tolerance = 1e-10)
	expect_equal(g$inf$compute_estimate_with_bootstrap_weights(rep(0.37, g$n)), u, tolerance = 1e-10)
})

test_that("weights not matching the installed context are rejected; a missing context errors", {
	g <- mk()
	expect_error(g$inf$compute_estimate_with_bootstrap_weights(rep(1, g$n - 1L)))
	h <- mk(); h$p$current_bayesian_bootstrap_context <- NULL
	expect_error(h$inf$compute_estimate_with_bootstrap_weights(rep(1, h$n)), "No Bayesian-bootstrap context is installed")
})
