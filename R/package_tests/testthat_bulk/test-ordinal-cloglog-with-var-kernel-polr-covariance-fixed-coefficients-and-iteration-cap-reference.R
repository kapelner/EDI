library(testthat)
library(EDI)

# fast_ordinal_cloglog_regression_with_var_cpp / fast_ordinal_cloglog_regression_cpp beyond the point fit (covered elsewhere): the covariance
# equals MASS::polr(method = "cloglog", Hess = TRUE) up to the kernel's alpha + x'b sign convention (coefficient block negated, so alpha-b
# covariances flip sign), ssq_b_j is the treatment-column variance, information is the observed information (-Hessian of the direct
# likelihood), fixed coefficients equal an optim profile fit, and maxit is honoured (hit_iteration_cap / converged).

skip_if_not_installed("MASS"); skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(9); n <- 300L
X <- cbind(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
y <- as.integer(cut(0.6 * X[, 1] - 0.4 * X[, 2] + rlogis(n), c(-Inf, -1, 0.3, 1.4, Inf))); Kc <- max(y)
ll <- function(p) { eta <- as.numeric(X %*% p[Kc:(Kc + 1L)]); cdf <- cbind(0, vapply(p[1:(Kc - 1)], function(t) 1 - exp(-exp(t + eta)), numeric(n)), 1)
	sum(log(cdf[cbind(seq_len(n), y + 1L)] - cdf[cbind(seq_len(n), y)])) }
rv <- K("fast_ordinal_cloglog_regression_with_var_cpp")(X, y)
pr <- suppressWarnings(MASS::polr(factor(y) ~ X, method = "cloglog", Hess = TRUE))

test_that("vcov equals polr's covariance with the coefficient block negated; ssq_b_j is the treatment-column variance", {
	expect_true(rv$converged)
	Vp <- vcov(pr)[c(3:5, 1:2), c(3:5, 1:2)]                             # order: thresholds then coefficients
	s <- c(rep(1, Kc - 1), rep(-1, 2)); Vref <- Vp * outer(s, s)
	expect_equal(unname(rv$vcov), unname(Vref), tolerance = 5e-3)
	expect_equal(rv$ssq_b_j, unname(rv$vcov[Kc, Kc]), tolerance = 1e-8)
})

test_that("information is the observed information: -numerical Hessian of the direct log-likelihood, and vcov is its inverse", {
	expect_identical(rv$information_type, "observed")
	expect_equal(unname(rv$fisher_information), unname(-numDeriv::hessian(ll, rv$params)), tolerance = 1e-3)
	expect_equal(rv$information, rv$fisher_information); expect_equal(rv$observed_information, rv$fisher_information)
	expect_equal(unname(rv$vcov), unname(solve(rv$fisher_information)), tolerance = 1e-8)
})

test_that("fixed coefficient: profile fit reaches an optim profile optimum and cannot beat the free fit", {
	f <- K("fast_ordinal_cloglog_regression_cpp")
	fx <- f(X, y, fixed_idx = Kc, fixed_values = -0.4)
	expect_equal(fx$params[Kc], -0.4)
	o <- optim(fx$params[-Kc], function(q) -ll(append(q, -0.4, after = Kc - 1L)), method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))
	expect_equal(fx$neg_loglik, o$value, tolerance = 1e-5)
	expect_equal(fx$params[-Kc], o$par, tolerance = 1e-2)
	expect_gte(fx$neg_loglik, f(X, y)$neg_loglik - 1e-8)
})

test_that("the iteration cap is reported", {
	c1 <- K("fast_ordinal_cloglog_regression_cpp")(X, y, maxit = 1L)
	expect_true(is.finite(c1$num_iter)); expect_lte(c1$num_iter, 1L)
	expect_false(c1$converged)
})
