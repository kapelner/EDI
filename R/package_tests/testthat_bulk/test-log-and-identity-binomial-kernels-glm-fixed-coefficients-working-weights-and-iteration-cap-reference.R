library(testthat)
library(EDI)

# fast_log_binomial_regression_cpp / fast_identity_binomial_regression_cpp (support-constrained binomial GLMs): coefficients equal
# glm(family = binomial(link)) started from a feasible point, mu_hat / working_weights / fisher_information equal their definitions
# (log: mu, mu / (1 - mu); identity: X b, 1 / (mu (1 - mu)); information X' W X), fitted means stay inside (0, 1), fixed
# coefficients equal glm(offset =), maxit = 1 reports the iteration cap. The fitted-mean support constraint is checked on the fit.

K <- function(nm) get(nm, envir = asNamespace("EDI"))
set.seed(1); n <- 300L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n, 0, 0.3))
y <- rbinom(n, 1, pmin(0.9, exp(-1.2 + 0.4 * X[, 2] + 0.2 * X[, 3])))
spec <- list(
	log = list(fn = "fast_log_binomial_regression_cpp", fam = binomial("log"), start = c(-1.2, 0.4, 0.2),
		mean = function(b) exp(as.numeric(X %*% b)), w = function(mu) mu / (1 - mu), tol = 1e-4),
	identity = list(fn = "fast_identity_binomial_regression_cpp", fam = binomial("identity"), start = c(0.3, 0.1, 0),
		mean = function(b) as.numeric(X %*% b), w = function(mu) 1 / (mu * (1 - mu)), tol = 1e-4))

test_that("coefficients equal glm, and fitted means / working weights / information equal their definitions", {
	for (nm in names(spec)) {
		s <- spec[[nm]]; r <- K(s$fn)(X, y)
		g <- glm(y ~ X - 1, family = s$fam, start = s$start)
		expect_true(r$converged, info = nm)
		expect_equal(as.numeric(r$b), unname(coef(g)), tolerance = s$tol, info = nm)
		mu <- s$mean(r$b)
		expect_true(all(mu > 0 & mu < 1), info = nm)
		expect_equal(as.numeric(r$mu_hat), mu, tolerance = 1e-8, info = nm)
		w <- s$w(mu)
		expect_equal(as.numeric(r$working_weights), w, tolerance = 1e-6, info = nm)
		expect_equal(unname(r$fisher_information), unname(crossprod(X * sqrt(w))), tolerance = 1e-5, info = nm)
	}
})

test_that("fixed coefficient: profile fit equals glm with the fixed term as an offset", {
	for (nm in names(spec)) {
		s <- spec[[nm]]; r <- K(s$fn)(X, y, fixed_idx = 2L, fixed_values = 0.3)
		expect_equal(r$b[2], 0.3, info = nm)
		st <- s$start[-2]; st[1] <- if (nm == "log") -1.25 else 0.22
		ref <- glm(y ~ X[, -2] - 1, offset = 0.3 * X[, 2], family = s$fam, start = st)
		expect_equal(as.numeric(r$b[-2]), unname(coef(ref)), tolerance = 1e-3, info = nm)
	}
})

test_that("maxit = 1 reports the iteration cap and non-convergence; a normal run converges within the default cap", {
	for (nm in names(spec)) {
		s <- spec[[nm]]
		r1 <- K(s$fn)(X, y, maxit = 1L)
		expect_equal(r1$num_iter, 1L, info = nm); expect_true(r1$hit_iteration_cap, info = nm); expect_false(r1$converged, info = nm)
		r <- K(s$fn)(X, y)
		expect_false(r$hit_iteration_cap, info = nm); expect_lt(r$num_iter, 20L)
	}
})

test_that("the log-binomial kernel also exposes estimate_only; the identity kernel does not take it", {
	e <- K("fast_log_binomial_regression_cpp")(X, y, estimate_only = TRUE)
	expect_named(e, c("b", "converged", "hit_iteration_cap", "num_iter"), ignore.order = TRUE)
	expect_equal(as.numeric(e$b), as.numeric(K("fast_log_binomial_regression_cpp")(X, y)$b), tolerance = 1e-8)
	expect_false("estimate_only" %in% names(formals(K("fast_identity_binomial_regression_cpp"))))
})
