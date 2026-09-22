library(testthat)
library(EDI)

# fast_ordinal_cauchit_regression_cpp / _with_var_cpp / get_ordinal_cauchit_regression_{score,hessian}_cpp: proportional-odds model with the
# Cauchy link, P(y <= k) = pcauchy(alpha_k - x'b). References: the direct log-likelihood, a tight BFGS optimum, numDeriv derivatives, and
# an optim profile fit for fixed coefficients. NOTE: MASS::polr(method = "cauchit") is NOT used as a likelihood reference -- its reported
# logLik is inconsistent with the likelihood of its own parameters (-484.78 reported vs -482.14 evaluated on this data) and its optimum
# is slightly off; the kernel's stop rule leaves a small residual gradient, so parameters are compared at ~1e-2, likelihood at 1e-3.

skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
f <- K("fast_ordinal_cauchit_regression_cpp")
set.seed(1); n <- 400L
X <- cbind(x1 = rbinom(n, 1, 0.5), x2 = rnorm(n))
lat <- 0.6 * X[, 1] + 0.4 * X[, 2] + rcauchy(n) * 0.6; y <- as.integer(cut(lat, c(-Inf, -1, 0, 1.2, Inf))); Kc <- max(y)
ll <- function(p) { alpha <- p[1:(Kc - 1)]; eta <- as.numeric(X %*% p[-(1:(Kc - 1))]); cuts <- c(-Inf, alpha, Inf)
	sum(log(pmax(pcauchy(cuts[y + 1L] - eta) - pcauchy(cuts[y] - eta), 1e-300))) }
r <- f(X, y)
opt <- optim(r$params, function(p) -ll(p), method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))

test_that("neg_loglik is the direct Cauchy-link likelihood at the returned parameters and matches the BFGS optimum", {
	expect_true(r$converged)
	expect_equal(r$params, c(r$alpha, r$b))
	expect_equal(r$neg_loglik, -ll(r$params), tolerance = 1e-8)
	expect_equal(r$neg_loglik, opt$value, tolerance = 1e-4)
	expect_equal(r$params, opt$par, tolerance = 2e-2)
	expect_gte(r$neg_loglik, opt$value - 1e-6)                                 # the kernel cannot beat the true optimum
})

test_that("score and Hessian kernels equal numDeriv derivatives of the log-likelihood; information / vcov / ssq_b_j are consistent", {
	pp <- r$params + c(0.05, -0.04, 0.03, 0.02, -0.03)
	expect_equal(as.numeric(K("get_ordinal_cauchit_regression_score_cpp")(X, y, pp)), numDeriv::grad(ll, pp), tolerance = 1e-5)
	expect_equal(unname(K("get_ordinal_cauchit_regression_hessian_cpp")(X, y, pp)), unname(numDeriv::hessian(ll, pp)), tolerance = 1e-4)
	rv <- K("fast_ordinal_cauchit_regression_with_var_cpp")(X, y)
	expect_equal(unname(rv$fisher_information), unname(-numDeriv::hessian(ll, rv$params)), tolerance = 1e-3)
	expect_equal(unname(rv$vcov), unname(solve(rv$fisher_information)), tolerance = 1e-6)
	expect_equal(rv$ssq_b_j, unname(rv$vcov[Kc, Kc]), tolerance = 1e-8)
	expect_identical(rv$information_type, "observed")
})

test_that("fixed coefficient: profile fit reaches the optim profile optimum and cannot beat the free fit", {
	fx <- f(X, y, fixed_idx = Kc, fixed_values = 0.5)
	expect_equal(fx$params[Kc], 0.5)
	o <- optim(fx$params[-Kc], function(q) -ll(append(q, 0.5, after = Kc - 1L)), method = "BFGS", control = list(reltol = 1e-14, maxit = 1000))
	expect_equal(fx$neg_loglik, o$value, tolerance = 1e-3)
	expect_equal(fx$params[-Kc], o$par, tolerance = 5e-2)
	expect_gte(fx$neg_loglik, r$neg_loglik - 1e-6)
})

test_that("maxit = 1 reports the iteration cap and non-convergence", {
	c1 <- f(X, y, maxit = 1L)
	expect_equal(c1$num_iter, 1L); expect_true(c1$hit_iteration_cap); expect_false(c1$converged)
})
