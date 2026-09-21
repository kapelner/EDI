library(testthat)
library(EDI)

# fast_neg_bin_cpp(X, y, ...): coefficients, theta_hat and logLik equal MASS::glm.nb (fast optimizer: ~1e-3 agreement); the
# coefficient block of fisher_information equals X' diag(mu / (1 + mu / theta)) X; fixed_idx / fixed_values equal the offset glm.nb
# profile fit; estimate_only returns the same fields; maxit = 1 reports the iteration cap; non-overdispersed data give a large
# finite theta with a clean convergence (dispersion_at_poisson_boundary is only a rescue flag, raised when the optimizer
# would otherwise report failure near the Poisson limit).

skip_if_not_installed("MASS")
f <- get("fast_neg_bin_cpp", envir = asNamespace("EDI"))
set.seed(1); n <- 300L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
y <- rnbinom(n, mu = exp(X %*% c(0.5, 0.4, 0.2)), size = 1.5)
g <- MASS::glm.nb(y ~ X - 1)

test_that("coefficients, theta and log-likelihood agree with glm.nb", {
	r <- f(X, y)
	expect_true(r$converged); expect_false(r$hit_iteration_cap); expect_false(r$dispersion_at_poisson_boundary)
	expect_equal(r$b, unname(coef(g)), tolerance = 2e-3)
	expect_equal(r$theta_hat, g$theta, tolerance = 2e-2)
	expect_equal(r$logLik, as.numeric(logLik(g)), tolerance = 1e-4)
})

test_that("fisher_information is the observed information in (coefficients, log theta): the numerical Hessian of the NB log-likelihood", {
	skip_if_not_installed("numDeriv")
	r <- f(X, y)
	expect_equal(dim(r$fisher_information), c(4L, 4L))
	ll <- function(p) sum(dnbinom(y, size = exp(p[4]), mu = exp(X %*% p[1:3]), log = TRUE))
	H <- -numDeriv::hessian(ll, c(r$b, log(r$theta_hat)))
	expect_equal(unname(r$fisher_information), unname(H), tolerance = 1e-6)
	expect_equal(r$fisher_information, t(r$fisher_information), tolerance = 1e-10)
	expect_equal(unname(solve(r$fisher_information[1:3, 1:3])), unname(vcov(g)), tolerance = 1e-1)   # profile-free block vs glm.nb's conditional vcov
})

test_that("fixed coefficient: profile fit equals the offset glm.nb fit", {
	r <- f(X, y, fixed_idx = 2L, fixed_values = 0.3)
	expect_equal(r$b[2], 0.3)
	ref <- MASS::glm.nb(y ~ X[, -2] - 1 + offset(0.3 * X[, 2]))
	expect_equal(r$b[-2], unname(coef(ref)), tolerance = 5e-3)
	expect_equal(r$theta_hat, ref$theta, tolerance = 5e-2)
	expect_lte(r$logLik, f(X, y)$logLik + 1e-8)                             # constrained fit cannot beat the free MLE
})

test_that("estimate_only returns the same field set and coefficients; maxit = 1 reports the iteration cap", {
	e <- f(X, y, estimate_only = TRUE)
	expect_true(all(c("b", "theta_hat", "converged", "num_iter") %in% names(e)))
	expect_equal(e$b, f(X, y)$b, tolerance = 1e-6)
	r <- f(X, y, maxit = 1L)
	expect_equal(r$num_iter, 1L); expect_true(r$hit_iteration_cap); expect_false(r$converged)
})

test_that("Poisson-distributed data: theta_hat is large, the fit converges normally and the rescue flag stays FALSE; coefficients match the Poisson glm", {
	set.seed(2); yp <- rpois(n, exp(X %*% c(0.5, 0.4, 0.2)))
	r <- f(X, yp)
	expect_true(r$converged); expect_gt(r$theta_hat, 10); expect_true(is.finite(r$theta_hat))
	expect_false(r$dispersion_at_poisson_boundary)
	expect_equal(r$b, unname(coef(glm(yp ~ X - 1, family = poisson()))), tolerance = 2e-2)
	set.seed(3); ybig <- rpois(2000, exp(0.5)); Xb <- cbind(1, rnorm(2000))
	rb <- f(Xb, ybig)
	expect_gt(rb$theta_hat, 1000)                              # theta grows without bound as the data approach the Poisson limit
	expect_true(rb$converged)
})
