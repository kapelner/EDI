library(testthat)
library(EDI)

# Frequency-weight equivalence for the weighted regression kernels: fitting with integer weights w_i must give the same coefficients as
# fitting the unweighted kernel on data in which row i is repeated w_i times (an independent reference that needs no external package).
# Also: unit weights reproduce the unweighted fit, and zero-weight rows drop out. Families: Poisson, logistic, probit, log-binomial,
# identity-binomial, negative binomial (overdispersed data).

set.seed(1); n <- 100L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
yb <- rbinom(n, 1, plogis(0.2 + 0.6 * X[, 2] + 0.3 * X[, 3]))
yc <- rpois(n, exp(0.2 + 0.3 * X[, 2]))
ynb <- rnbinom(n, mu = exp(0.5 + 0.4 * X[, 2] + 0.2 * X[, 3]), size = 1.5)
wt <- sample(1:3, n, TRUE); idx <- rep(seq_len(n), wt)
K <- function(nm) get(nm, envir = asNamespace("EDI"))

fams <- list(
	poisson = list(w = "fast_poisson_regression_weighted_cpp", u = "fast_poisson_regression_cpp", y = yc, tol = 1e-6),
	logistic = list(w = "fast_logistic_regression_weighted_cpp", u = "fast_logistic_regression_cpp", y = yb, tol = 1e-6),
	probit = list(w = "fast_probit_regression_weighted_cpp", u = "fast_probit_regression_cpp", y = yb, tol = 1e-5),
	log_binomial = list(w = "fast_log_binomial_regression_weighted_cpp", u = "fast_log_binomial_regression_cpp", y = yb, tol = 1e-5),
	identity_binomial = list(w = "fast_identity_binomial_regression_weighted_cpp", u = "fast_identity_binomial_regression_cpp", y = yb, tol = 1e-4))

test_that("integer weights equal row replication (coefficients) for each family", {
	for (nm in names(fams)) {
		f <- fams[[nm]]
		a <- K(f$w)(X, f$y, as.numeric(wt)); b <- K(f$u)(X[idx, ], f$y[idx])
		expect_equal(as.numeric(a$b), as.numeric(b$b), tolerance = f$tol, info = nm)
	}
})

test_that("unit weights reproduce the unweighted fit", {
	for (nm in names(fams)) {
		f <- fams[[nm]]
		a <- K(f$w)(X, f$y, rep(1, n)); b <- K(f$u)(X, f$y)
		expect_equal(as.numeric(a$b), as.numeric(b$b), tolerance = f$tol, info = nm)
	}
})

test_that("zero-weight rows drop out of the fit for the unconstrained-link families (Poisson, logistic, probit)", {
	keep <- seq_len(n) > 20; w0 <- as.numeric(keep)
	for (nm in c("poisson", "logistic", "probit")) {
		f <- fams[[nm]]
		a <- K(f$w)(X, f$y, w0); b <- K(f$u)(X[keep, ], f$y[keep])
		expect_equal(as.numeric(a$b), as.numeric(b$b), tolerance = 10 * f$tol, info = nm)
	}
})

test_that("OBSERVATION: for the support-constrained links, zero-weight rows still take part in the feasibility constraint", {
	keep <- seq_len(n) > 20; w0 <- as.numeric(keep)
	# identity link: mu = X b must stay in [0, 1] on EVERY row, including rows with zero weight, so the estimate differs from the subset fit
	a <- K(fams$identity_binomial$w)(X, yb, w0); b <- K(fams$identity_binomial$u)(X[keep, ], yb[keep])
	expect_true(isTRUE(a$converged)); expect_lte(max(X %*% a$b), 1 + 1e-6); expect_gt(max(X %*% b$b), 1)              # the subset fit alone would leave [0, 1] on the omitted rows
	expect_gt(max(abs(as.numeric(a$b) - as.numeric(b$b))), 1e-3)
	# log link: the weighted fit reports non-convergence (one iteration) and its mean exceeds 1 on some rows
	l <- K(fams$log_binomial$w)(X, yb, w0)
	expect_false(isTRUE(l$converged))
})

test_that("weighted negative binomial: coefficients match the replicated-row fit (theta is checked to be positive and finite)", {
	a <- K("fast_neg_bin_weighted_cpp")(X, ynb, as.numeric(wt)); b <- K("fast_neg_bin_cpp")(X[idx, ], ynb[idx])
	expect_equal(as.numeric(a$b), as.numeric(b$b), tolerance = 2e-3)
	expect_true(is.finite(a$theta_hat) && a$theta_hat > 0); expect_equal(a$theta_hat, b$theta_hat, tolerance = 5e-2)
	expect_true(isTRUE(a$converged))
})

test_that("scaling all weights by a constant leaves the Poisson / logistic coefficients unchanged (weights act as frequencies only through ratios)", {
	for (nm in c("poisson", "logistic")) {
		f <- fams[[nm]]
		a <- K(f$w)(X, f$y, as.numeric(wt)); b <- K(f$w)(X, f$y, 4 * as.numeric(wt))
		expect_equal(as.numeric(a$b), as.numeric(b$b), tolerance = 1e-6, info = nm)
	}
})
