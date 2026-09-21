library(testthat)
library(EDI)

# fast_coxph_regression_cpp(X, y, dead, ...): Cox partial likelihood with BRESLOW tie handling (times here are tied on purpose).
# Reference: survival::coxph(ties = "breslow") (the Efron fit differs, pinned as a contrast): coefficients, model vcov = inverse
# Fisher information, partial log-likelihood, cluster-robust vcov equal to coxph(cluster =), optimizers, fixed coefficients as an
# offset, estimate_only and the iteration cap.

skip_if_not_installed("survival")
f <- get("fast_coxph_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 150L
X <- cbind(w = rbinom(n, 1, 0.5), a = rnorm(n))
tt <- rexp(n, exp(0.5 * X[, 1] + 0.3 * X[, 2])); cc <- rexp(n, 0.3); y <- round(pmin(tt, cc) * 10) / 10 + 0.1; dead <- as.numeric(tt <= cc)
cl <- rep(1:30, each = 5L)
g <- survival::coxph(survival::Surv(y, dead) ~ X, ties = "breslow")

test_that("tied times: coefficients, vcov, information and partial log-likelihood equal coxph(ties = 'breslow'), not Efron", {
	expect_gt(n - length(unique(y)), 10L)
	r <- f(X, y, dead)
	expect_true(r$converged)
	expect_equal(r$coefficients, unname(coef(g)), tolerance = 1e-6)
	expect_equal(unname(r$vcov), unname(vcov(g)), tolerance = 1e-5)
	expect_equal(unname(solve(r$fisher_information)), unname(vcov(g)), tolerance = 1e-5)
	expect_equal(r$neg_ll, -as.numeric(g$loglik[2]), tolerance = 1e-8)
	ge <- survival::coxph(survival::Surv(y, dead) ~ X, ties = "efron")
	expect_gt(max(abs(r$coefficients - unname(coef(ge)))), 1e-2)                 # the Efron estimate is genuinely different here
})

test_that("cluster argument: vcov becomes the cluster-robust sandwich of coxph(cluster =); coefficients unchanged", {
	r <- f(X, y, dead, cluster = cl)
	gc <- survival::coxph(survival::Surv(y, dead) ~ X + survival::cluster(cl), ties = "breslow")
	expect_equal(r$coefficients, unname(coef(g)), tolerance = 1e-6)
	expect_equal(unname(r$vcov), unname(vcov(gc)), tolerance = 1e-4)
	expect_false(isTRUE(all.equal(unname(r$vcov), unname(vcov(g)), tolerance = 1e-3)))
})

test_that("newton_raphson, lbfgs and irls agree; fixed coefficient equals the offset coxph", {
	for (alg in c("newton_raphson", "lbfgs", "irls")) expect_equal(f(X, y, dead, optimization_alg = alg)$coefficients, unname(coef(g)), tolerance = 1e-5, info = alg)
	r <- f(X, y, dead, fixed_idx = 1L, fixed_values = 0.3)
	ref <- survival::coxph(survival::Surv(y, dead) ~ X[, 2] + offset(0.3 * X[, 1]), ties = "breslow")
	expect_equal(r$coefficients, c(0.3, unname(coef(ref))), tolerance = 1e-6)
	expect_equal(r$neg_ll, -as.numeric(ref$loglik[2]), tolerance = 1e-8)
})

test_that("estimate_only returns the short field set; maxit = 1 reports the iteration cap", {
	e <- f(X, y, dead, estimate_only = TRUE)
	expect_false("vcov" %in% names(e)); expect_equal(e$coefficients, f(X, y, dead)$coefficients, tolerance = 1e-8)
	c1 <- f(X, y, dead, maxit = 1L)
	expect_equal(c1$num_iter, 1L); expect_true(c1$hit_iteration_cap); expect_false(c1$converged)
})
