library(testthat)
library(EDI)

# fast_coxph_regression() (R wrapper over the C++ Cox kernel, Breslow ties): coefficients, covariance and
# negative partial log-likelihood against survival::coxph(ties = "breslow"), estimate_only dropping the vcov,
# both optimizers, rejection of the IRLS option, and the glmnet (lambda = 0) fallback. Also
# .normalize_optimizer_algorithm(): defaults, IRLS permission, partial matching and the error text.

skip_if_not_installed("survival")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(6)
	n <- 120L
	X <- cbind(a = rnorm(n), b = rbinom(n, 1, 0.5))
	list(X = X, t = round(rexp(n, exp(0.4 * X[, 1] - 0.3 * X[, 2])) * 5) + 1, dead = rbinom(n, 1, 0.75))
}

test_that("coefficients, covariance and negative log-likelihood equal coxph with Breslow ties", {
	f <- fx()
	ref <- survival::coxph(survival::Surv(f$t, f$dead) ~ f$X, ties = "breslow")
	r <- fast_coxph_regression(f$X, f$t, f$dead)
	expect_equal(unname(r$b), unname(coef(ref)), tolerance = 1e-5)
	expect_equal(names(r$b), colnames(f$X))
	expect_identical(r$b, r$coefficients)
	expect_equal(unname(r$vcov), unname(vcov(ref)), tolerance = 1e-4)
	expect_equal(r$neg_log_lik, -as.numeric(ref$loglik[2]), tolerance = 1e-6)
	expect_equal(unname(r$fisher_information), unname(solve(vcov(ref))), tolerance = 1e-3)
})

test_that("estimate_only drops the covariance; both optimizers agree with each other and coxph", {
	f <- fx()
	ref <- unname(coef(survival::coxph(survival::Surv(f$t, f$dead) ~ f$X, ties = "breslow")))
	expect_null(fast_coxph_regression(f$X, f$t, f$dead, estimate_only = TRUE)$vcov)
	for (alg in c("lbfgs", "newton_raphson")) {
		expect_equal(unname(fast_coxph_regression(f$X, f$t, f$dead, optimization_alg = alg)$b), ref, tolerance = 1e-4, info = alg)
	}
	expect_error(fast_coxph_regression(f$X, f$t, f$dead, optimization_alg = "irls"), "should be one of")
})

test_that("the glmnet fallback (use_rcpp = FALSE) returns the same coefficients", {
	skip_if_not_installed("glmnet")
	f <- fx()
	ref <- unname(coef(survival::coxph(survival::Surv(f$t, f$dead) ~ f$X, ties = "breslow")))
	r <- fast_coxph_regression(f$X, f$t, f$dead, use_rcpp = FALSE)
	expect_equal(as.numeric(r$b), ref, tolerance = 5e-3)
})

test_that(".normalize_optimizer_algorithm applies defaults, the IRLS permission, partial matching and errors", {
	nz <- K(".normalize_optimizer_algorithm")
	expect_equal(nz(), "lbfgs")
	expect_equal(nz(allow_irls = TRUE), "irls")
	expect_equal(nz(NULL, allow_irls = TRUE, default = "lbfgs"), "lbfgs")
	expect_equal(nz("newton", allow_irls = FALSE), "newton_raphson")             # partial matching
	expect_equal(nz("irls", allow_irls = TRUE), "irls")
	expect_equal(nz("lbfgs", allow_irls = TRUE), "lbfgs")
	expect_error(nz("irls"), "should be one of")
	expect_error(nz("bogus", allow_irls = TRUE), "should be one of")
})
