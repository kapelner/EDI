library(testthat)
library(EDI)

# InferenceContinKKOLSOneLik's PUBLIC get_likelihood_components() (inference_continuous_KK_ols_
# one_lik.R) had no test reference anywhere -- confirmed via grep. It returns the log-likelihood,
# score (gradient), and observed information (negated to a Hessian) evaluated at the class's own
# fitted MLE, drawn from the same get_likelihood_test_spec() closures used internally for
# likelihood-ratio/score/gradient testing (already covered indirectly through those testing paths,
# but never through this direct accessor).
#   1. loglik matches an independently hand-computed -0.5 * RSS / sigma2_hat (the class's own
#      neg_loglik() convention -- a partial Gaussian log-likelihood that drops the normalizing
#      constant, consistent with how it's used for likelihood-ratio comparisons).
#   2. gradient is numerically zero at the OLS optimum (X'e = 0 is the first-order condition defining
#      the least-squares estimator itself -- an exact mathematical identity, not merely "small").
#   3. hessian matches an independently constructed -(X'X)/sigma2_hat exactly.
#   4. When the underlying fit is nonestimable (fit_ols() fails), the result is NULL.

ols_onelik_fixture <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKOLSOneLik$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("loglik, gradient, and hessian match independently hand-computed references at the fitted OLS optimum", {
	f <- ols_onelik_fixture(1L)
	comp <- f$inf$get_likelihood_components()
	expect_named(comp, c("loglik", "gradient", "hessian"))

	ctx <- f$priv$cached_values$likelihood_test_context
	X <- ctx$X; y <- ctx$y
	sig2 <- f$priv$cached_mod$sigma2_hat
	beta <- f$priv$cached_mod$b
	rss <- sum((y - X %*% beta)^2)

	expect_equal(comp$loglik, -0.5 * rss / sig2, tolerance = 1e-10)
	expect_equal(comp$hessian, -(t(X) %*% X) / sig2, tolerance = 1e-10, check.attributes = FALSE)
	expect_true(max(abs(comp$gradient)) < 1e-8)                                     # X'e = 0 at the OLS optimum, an exact identity
})

test_that("when the underlying fit is nonestimable, get_likelihood_components() returns NULL", {
	f <- ols_onelik_fixture(2L)
	unlockBinding("fit_ols", f$priv)
	f$priv$fit_ols <- function(...) NULL
	expect_null(f$inf$get_likelihood_components())
})
