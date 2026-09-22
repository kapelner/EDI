library(testthat)
library(EDI)

# fast_beta_regression_with_var_cpp / fast_beta_regression_cpp (logit mean, log precision; parameters (b, log phi)): coefficients, phi and log-likelihood
# equal betareg(link = "logit", link.phi = "log"); vcov / std_errs equal betareg's (~1% agreement); fisher_information is the observed information
# (-numerical Hessian of the direct beta log-likelihood in (b, log phi)); fixed coefficients equal an optim profile fit; compute_std_errs is a deprecated no-op.

skip_if_not_installed("betareg"); skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(1); n <- 300L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
mu <- plogis(X %*% c(-0.2, 0.5, 0.3)); y <- rbeta(n, mu * 20, (1 - mu) * 20)
m <- betareg::betareg(y ~ X[, -1], link = "logit", link.phi = "log")
rv <- K("fast_beta_regression_with_var_cpp")(X, y)
ll <- function(p) { mu <- plogis(as.numeric(X %*% p[1:3])); ph <- exp(p[4]); sum(dbeta(y, mu * ph, (1 - mu) * ph, log = TRUE)) }

test_that("coefficients, phi and log-likelihood equal betareg", {
	expect_true(rv$converged)
	expect_equal(as.numeric(rv$coefficients), unname(coef(m))[1:3], tolerance = 1e-3)
	expect_equal(rv$phi, unname(exp(coef(m)[4])), tolerance = 5e-3)
	expect_equal(-rv$neg_loglik, as.numeric(logLik(m)), tolerance = 1e-5)
	expect_equal(-rv$neg_loglik, ll(c(rv$coefficients, log(rv$phi))), tolerance = 1e-8)
})

test_that("vcov / std_errs equal betareg's; information is the observed information in (b, log phi)", {
	expect_equal(as.numeric(rv$std_errs), unname(sqrt(diag(vcov(m)))), tolerance = 1e-2)
	expect_equal(unname(rv$vcov), unname(vcov(m)), tolerance = 2e-2)
	expect_equal(as.numeric(rv$std_errs), sqrt(diag(rv$vcov)), tolerance = 1e-8)
	p <- c(rv$coefficients, log(rv$phi))
	expect_equal(unname(rv$fisher_information), unname(-numDeriv::hessian(ll, p)), tolerance = 1e-3)
	expect_equal(unname(rv$vcov), unname(solve(rv$fisher_information)), tolerance = 1e-6)
})

test_that("fixed coefficient: profile fit reaches an optim profile optimum and cannot beat the free fit", {
	f <- K("fast_beta_regression_cpp")
	fx <- f(X, y, fixed_idx = 2L, fixed_values = 0.3)
	expect_equal(as.numeric(fx$coefficients)[2], 0.3)
	o <- optim(c(fx$coefficients[c(1, 3)], log(fx$phi)), function(q) -ll(c(q[1], 0.3, q[2], q[3])), method = "BFGS", control = list(reltol = 1e-14, maxit = 2000))
	expect_equal(fx$neg_loglik, o$value, tolerance = 1e-6)
	expect_equal(as.numeric(fx$coefficients)[c(1, 3)], o$par[1:2], tolerance = 1e-2); expect_equal(fx$phi, exp(o$par[3]), tolerance = 1e-2)
	expect_gte(fx$neg_loglik, K("fast_beta_regression_cpp")(X, y)$neg_loglik - 1e-8)
})

test_that("compute_std_errs is a deprecated no-op on both entry points; estimate_only gives the same coefficients", {
	r <- K("fast_beta_regression_with_var_cpp")(X, y, compute_std_errs = FALSE)
	expect_equal(unname(r$vcov), unname(rv$vcov), tolerance = 1e-8)              # variance still returned (documented: no effect)
	expect_equal(as.numeric(r$coefficients), as.numeric(rv$coefficients), tolerance = 1e-6)
	e <- K("fast_beta_regression_cpp")(X, y, estimate_only = TRUE)
	expect_equal(as.numeric(e$coefficients), as.numeric(rv$coefficients), tolerance = 1e-4)
})
