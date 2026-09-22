library(testthat)
library(EDI)

# fast_ordinal_probit_regression_with_var_cpp / fast_ordinal_probit_regression_cpp beyond the point fit (covered elsewhere): the covariance
# equals MASS::polr(method = "probit", Hess = TRUE) (same sign convention: P(y <= k) = pnorm(alpha_k - x'b)), ssq_b_j is the treatment-column
# variance, information is the observed information (-Hessian of the direct likelihood), fixed coefficients equal an optim profile fit, and
# maxit is honoured.

skip_if_not_installed("MASS"); skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(9); n <- 300L
X <- cbind(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
y <- as.integer(cut(0.6 * X[, 1] - 0.4 * X[, 2] + rnorm(n), c(-Inf, -1, 0.3, 1.4, Inf))); Kc <- max(y)
ll <- function(p) { eta <- as.numeric(X %*% p[Kc:(Kc + 1L)]); cuts <- c(-Inf, p[1:(Kc - 1)], Inf)
	sum(log(pmax(pnorm(cuts[y + 1L] - eta) - pnorm(cuts[y] - eta), 1e-300))) }
rv <- K("fast_ordinal_probit_regression_with_var_cpp")(X, y)
pr <- suppressWarnings(MASS::polr(factor(y) ~ X, method = "probit", Hess = TRUE))

test_that("vcov equals polr's covariance (thresholds first, then coefficients); ssq_b_j is the treatment-column variance", {
	expect_true(rv$converged)
	Vp <- vcov(pr)[c(3:5, 1:2), c(3:5, 1:2)]
	expect_equal(unname(rv$vcov), unname(Vp), tolerance = 5e-3)
	expect_equal(rv$ssq_b_j, unname(rv$vcov[Kc, Kc]), tolerance = 1e-8)
	expect_equal(rv$params, c(unname(pr$zeta), unname(coef(pr))), tolerance = 5e-3)
})

test_that("information is the observed information: -numerical Hessian of the direct likelihood; vcov is its inverse; neg_loglik is the direct likelihood", {
	expect_identical(rv$information_type, "observed")
	expect_equal(unname(rv$fisher_information), unname(-numDeriv::hessian(ll, rv$params)), tolerance = 1e-3)
	expect_equal(unname(rv$vcov), unname(solve(rv$fisher_information)), tolerance = 1e-8)
	expect_equal(rv$neg_loglik, -ll(rv$params), tolerance = 1e-8)
	expect_equal(rv$neg_loglik, -as.numeric(logLik(pr)), tolerance = 1e-5)
})

test_that("fixed coefficient: profile fit reaches an optim profile optimum and cannot beat the free fit", {
	f <- K("fast_ordinal_probit_regression_cpp")
	fx <- f(X, y, fixed_idx = Kc, fixed_values = 0.4)
	expect_equal(fx$params[Kc], 0.4)
	o <- optim(fx$params[-Kc], function(q) -ll(append(q, 0.4, after = Kc - 1L)), method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))
	expect_equal(fx$neg_loglik, o$value, tolerance = 1e-5)
	expect_equal(fx$params[-Kc], o$par, tolerance = 1e-2)
	expect_gte(fx$neg_loglik, f(X, y)$neg_loglik - 1e-8)
})

test_that("the iteration cap is reported", {
	c1 <- K("fast_ordinal_probit_regression_cpp")(X, y, maxit = 1L)
	expect_lte(c1$num_iter, 1L); expect_false(c1$converged)
})
