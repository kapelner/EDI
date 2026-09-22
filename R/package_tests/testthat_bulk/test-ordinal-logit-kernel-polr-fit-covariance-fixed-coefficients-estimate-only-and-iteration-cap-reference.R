library(testthat)
library(EDI)

# fast_ordinal_regression_cpp / fast_ordinal_regression_with_var_cpp (proportional-odds logit): coefficients / thresholds / log-likelihood equal
# MASS::polr(method = "logistic"); the with_var covariance equals polr's Hessian-based vcov and the information the -numerical Hessian of the
# direct likelihood; fixed_idx / fixed_values equal an optim profile fit; estimate_only returns the short field set; maxit is honoured.

skip_if_not_installed("MASS"); skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
f <- K("fast_ordinal_regression_cpp")
set.seed(9); n <- 300L
X <- cbind(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
y <- as.integer(cut(0.6 * X[, 1] - 0.4 * X[, 2] + rlogis(n), c(-Inf, -1, 0.3, 1.4, Inf))); Kc <- max(y)
ll <- function(p) { eta <- as.numeric(X %*% p[Kc:(Kc + 1L)]); cuts <- c(-Inf, p[1:(Kc - 1)], Inf)
	sum(log(pmax(plogis(cuts[y + 1L] - eta) - plogis(cuts[y] - eta), 1e-300))) }
pr <- suppressWarnings(MASS::polr(factor(y) ~ X, method = "logistic", Hess = TRUE))
r <- f(X, y); rv <- K("fast_ordinal_regression_with_var_cpp")(X, y)

test_that("thresholds, coefficients and log-likelihood equal polr(logistic); neg_loglik is the direct likelihood", {
	expect_true(r$converged)
	pref <- c(unname(pr$zeta), unname(coef(pr)))
	expect_equal(as.numeric(r$params), pref, tolerance = 2e-3)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(pr)), tolerance = 1e-5)
	expect_equal(as.numeric(r$neg_loglik), -ll(as.numeric(r$params)), tolerance = 1e-8)
})

test_that("with_var: vcov equals polr's covariance (thresholds first) and is the inverse of the observed information", {
	Vp <- vcov(pr)[c(3:5, 1:2), c(3:5, 1:2)]
	expect_equal(unname(rv$vcov), unname(Vp), tolerance = 5e-3)
	expect_equal(unname(rv$fisher_information), unname(-numDeriv::hessian(ll, as.numeric(rv$params))), tolerance = 1e-3)
	expect_equal(unname(rv$vcov), unname(solve(rv$fisher_information)), tolerance = 1e-8)
	expect_equal(rv$ssq_b_j, unname(rv$vcov[Kc, Kc]), tolerance = 1e-8)
})

test_that("fixed coefficient: profile fit reaches an optim profile optimum and cannot beat the free fit", {
	fx <- f(X, y, fixed_idx = Kc, fixed_values = 0.4)
	expect_equal(as.numeric(fx$params)[Kc], 0.4)
	o <- optim(as.numeric(fx$params)[-Kc], function(q) -ll(append(q, 0.4, after = Kc - 1L)), method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))
	expect_equal(as.numeric(fx$neg_loglik), o$value, tolerance = 1e-5)
	expect_equal(as.numeric(fx$params)[-Kc], o$par, tolerance = 1e-2)
	expect_gte(as.numeric(fx$neg_loglik), as.numeric(r$neg_loglik) - 1e-8)
})

test_that("estimate_only returns the short field set with the same coefficients; maxit = 1 reports non-convergence", {
	e <- f(X, y, estimate_only = TRUE)
	expect_false("vcov" %in% names(e)); expect_equal(as.numeric(e$b), as.numeric(r$b), tolerance = 1e-6)
	c1 <- f(X, y, maxit = 1L)
	expect_lte(c1$num_iter, 1L); expect_false(c1$converged)
})
