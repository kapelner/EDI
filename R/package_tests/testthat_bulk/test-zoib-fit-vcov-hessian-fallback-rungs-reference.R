library(testthat)
library(EDI)

# .fit_zero_one_inflated_beta() (helper_zoib.R) has a 3-rung vcov fallback ladder that only engages
# when the native fit's own vcov (from fast_zero_one_inflated_beta_cpp) is missing or unusable:
#   1. numDeriv::hessian() + solve() -- the first fallback attempt.
#   2. If that still yields NULL/non-finite, numDeriv::hessian() + MASS::ginv() -- the
#      pseudo-inverse fallback for a (near-)singular Hessian.
#   3. If that ALSO still yields NULL/non-finite, give up: return the point estimate with an
#      all-NA vcov matrix (coefficients are always kept regardless).
# None of the three rungs had a test reference anywhere (the existing zoib test files -- test-zoib-
# fit-input-validation-guards-reference.R, test-zoib-start-value-construction-reference.R, test-
# zoib-marginal-estimand.R -- only exercise input validation and the happy path). This is a
# deliberately dormant fallback: fast_zero_one_inflated_beta_cpp (the real C++ fitter) is on this
# session's avoid-list for an intermittent crash, so it is never called for real here -- instead,
# fast_zero_one_inflated_beta_cpp is mocked to return a fit with an unusable native vcov (forcing
# entry into the fallback ladder), and numDeriv::hessian() is independently mocked per rung to
# deterministically control which fallback step succeeds, without ever invoking the risky real
# kernel.

f <- getFromNamespace(".fit_zero_one_inflated_beta", "EDI")

fx <- function(seed = 5L, n = 60L) {
	set.seed(seed)
	X <- cbind(rnorm(n))
	y <- pmin(pmax(plogis(0.3 * X[, 1] + rnorm(n)), 0), 1)
	y[y < 0.05] <- 0
	y[y > 0.95] <- 1
	fake_coefs <- c("(Intercept)" = 0.2, "V1" = 0.5, log_phi = 1, alpha0 = -2, alpha1 = -2)
	list(X = X, y = y, fake_coefs = fake_coefs, fake_fit = list(coefficients = unname(fake_coefs), vcov = NULL, neg_loglik = 100))
}

test_that("an unusable native vcov (NULL) falls through to the numDeriv::hessian() + solve() first rung and succeeds", {
	d <- fx()
	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) d$fake_fit, .package = "EDI")
	res <- f(d$y, d$X)
	expect_equal(unname(res$coefficients), unname(d$fake_coefs))
	expect_equal(dim(res$vcov), c(5L, 5L))
	expect_true(all(is.finite(diag(res$vcov))))
})

test_that("when the first rung's hessian is singular (solve() fails), the MASS::ginv() second rung engages and succeeds", {
	d <- fx(seed = 6L)
	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) d$fake_fit, .package = "EDI")
	local_mocked_bindings(hessian = function(...) matrix(0, 5, 5), .package = "numDeriv")
	res <- f(d$y, d$X)
	expect_equal(unname(res$coefficients), unname(d$fake_coefs))
	expect_true(all(is.finite(res$vcov)))
	expect_equal(unname(res$vcov), unname(MASS::ginv(matrix(0, 5, 5))))
})

test_that("when both fallback rungs fail (a non-finite hessian), the point estimate is kept with an all-NA vcov", {
	d <- fx(seed = 7L)
	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) d$fake_fit, .package = "EDI")
	local_mocked_bindings(hessian = function(...) matrix(NaN, 5, 5), .package = "numDeriv")
	res <- f(d$y, d$X)
	expect_equal(unname(res$coefficients), unname(d$fake_coefs))
	expect_true(all(is.na(res$vcov)))
	expect_equal(dim(res$vcov), c(5L, 5L))
})

test_that("estimate_only = TRUE bypasses the whole fallback ladder entirely (vcov is NULL, not computed)", {
	d <- fx(seed = 8L)
	local_mocked_bindings(fast_zero_one_inflated_beta_cpp = function(...) d$fake_fit, .package = "EDI")
	res <- f(d$y, d$X, estimate_only = TRUE)
	expect_equal(unname(res$coefficients), unname(d$fake_coefs))
	expect_null(res$vcov)
})
