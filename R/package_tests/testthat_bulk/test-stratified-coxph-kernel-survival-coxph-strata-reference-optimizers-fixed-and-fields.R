library(testthat)
library(EDI)

# fast_stratified_coxph_regression_cpp(X, y, dead, strata, ...): stratified Cox partial likelihood with Breslow ties. Reference:
# survival::coxph(ties = "breslow") with strata(): coefficients, vcov (= inverse Fisher information), partial log-likelihood (neg_ll),
# all optimizers agree, fixed coefficients equal the offset coxph, estimate_only returns the short field set, strata labels are arbitrary
# (relabelled / reordered rows give the same fit), and maxit = 1 reports the iteration cap.

skip_if_not_installed("survival")
f <- get("fast_stratified_coxph_regression_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 150L
X <- cbind(w = rbinom(n, 1, 0.5), a = rnorm(n)); st <- sample(1:3, n, TRUE)
tt <- rexp(n, exp(0.5 * X[, 1] + 0.3 * X[, 2] + 0.2 * st)); cc <- rexp(n, 0.3); y <- pmin(tt, cc); dead <- as.numeric(tt <= cc)
g <- survival::coxph(survival::Surv(y, dead) ~ X + survival::strata(st), ties = "breslow")

test_that("coefficients, vcov, information and partial log-likelihood equal the stratified coxph", {
	r <- f(X, y, dead, st)
	expect_true(r$converged); expect_false(r$hit_iteration_cap)
	expect_equal(r$coefficients, unname(coef(g)), tolerance = 1e-6)
	expect_equal(unname(r$vcov), unname(vcov(g)), tolerance = 1e-5)
	expect_equal(unname(solve(r$fisher_information)), unname(vcov(g)), tolerance = 1e-5)
	expect_equal(r$neg_ll, -as.numeric(g$loglik[2]), tolerance = 1e-8)
	expect_lt(r$gradient_norm, 1e-4)
})

test_that("newton_raphson, lbfgs and irls agree", {
	for (alg in c("newton_raphson", "lbfgs", "irls")) expect_equal(f(X, y, dead, st, optimization_alg = alg)$coefficients, unname(coef(g)), tolerance = 1e-4, info = alg)
})

test_that("fixed coefficient: profile fit equals coxph with the fixed term as an offset", {
	r <- f(X, y, dead, st, fixed_idx = 1L, fixed_values = 0.3)
	expect_equal(r$coefficients[1], 0.3)
	ref <- survival::coxph(survival::Surv(y, dead) ~ X[, 2] + survival::strata(st) + offset(0.3 * X[, 1]), ties = "breslow")
	expect_equal(r$coefficients[2], unname(coef(ref)), tolerance = 1e-6)
	expect_equal(r$neg_ll, -as.numeric(ref$loglik[2]), tolerance = 1e-8)
})

test_that("strata labels and row order are arbitrary; a single stratum equals the unstratified coxph", {
	perm <- sample.int(n)
	relabel <- c(`1` = 40L, `2` = -5L, `3` = 7L)[as.character(st)]
	r <- f(X[perm, ], y[perm], dead[perm], relabel[perm])
	expect_equal(r$coefficients, unname(coef(g)), tolerance = 1e-6)
	one <- f(X, y, dead, rep(1L, n))
	expect_equal(one$coefficients, unname(coef(survival::coxph(survival::Surv(y, dead) ~ X, ties = "breslow"))), tolerance = 1e-6)
})

test_that("estimate_only returns the short field set; maxit = 1 reports the iteration cap", {
	e <- f(X, y, dead, st, estimate_only = TRUE)
	expect_false("vcov" %in% names(e)); expect_true(all(c("coefficients", "converged", "neg_ll", "num_iter") %in% names(e)))
	expect_equal(e$coefficients, f(X, y, dead, st)$coefficients, tolerance = 1e-8)
	c1 <- f(X, y, dead, st, maxit = 1L)
	expect_equal(c1$num_iter, 1L); expect_true(c1$hit_iteration_cap); expect_false(c1$converged)
})
