library(testthat)
library(EDI)

# Cross-family contract of the *_with_var kernels: every full-inference kernel returns `fisher_information` and a treatment variance
# `ssq_b_j` equal to [solve(fisher_information)]_jj for the requested coefficient j, with converged fits. Poisson / logistic / probit
# are additionally compared with glm's covariance. Field-set differences between families (XtWX only on Poisson / weighted / logistic-weighted
# kernels) are pinned so the inconsistency is visible.

set.seed(1); n <- 120L
X <- cbind(1, rbinom(n, 1, 0.5), rnorm(n))
yc <- rpois(n, exp(0.2 + 0.3 * X[, 2] + 0.2 * X[, 3]))
yb <- rbinom(n, 1, plogis(0.2 + 0.6 * X[, 2] + 0.3 * X[, 3]))
K <- function(nm) get(nm, envir = asNamespace("EDI"))

families <- list(
	poisson = list(fn = "fast_poisson_regression_with_var_cpp", y = yc, glm = function() glm(yc ~ X[, -1], family = poisson)),
	logistic = list(fn = "fast_logistic_regression_with_var_cpp", y = yb, glm = function() glm(yb ~ X[, -1], family = binomial)),
	probit = list(fn = "fast_probit_regression_with_var_cpp", y = yb, glm = function() glm(yb ~ X[, -1], family = binomial("probit"))),
	log_binomial = list(fn = "fast_log_binomial_regression_with_var_cpp", y = yb, glm = NULL),
	identity_binomial = list(fn = "fast_identity_binomial_regression_with_var_cpp", y = yb, glm = NULL))

test_that("each family's with-var kernel converges and returns fisher_information with ssq_b_j = inverse-Fisher diagonal for every j", {
	for (nm in names(families)) {
		fam <- families[[nm]]
		for (j in 1:3) {
			r <- K(fam$fn)(X, fam$y, j = j)
			expect_true(isTRUE(r$converged), info = paste(nm, j))
			expect_true(all(c("b", "fisher_information", "ssq_b_j") %in% names(r)), info = nm)
			fi <- as.matrix(r$fisher_information)
			expect_identical(dim(fi), c(3L, 3L)); expect_true(isSymmetric(unname(fi), tol = 1e-8), info = nm)
			expect_equal(r$ssq_b_j, solve(fi)[j, j], tolerance = 1e-6, info = paste(nm, j))
			expect_gt(r$ssq_b_j, 0)
		}
	}
})

test_that("Poisson, logistic and probit kernels agree with glm's coefficients and covariance", {
	for (nm in c("poisson", "logistic", "probit")) {
		fam <- families[[nm]]; ref <- fam$glm(); r <- K(fam$fn)(X, fam$y, j = 2L)
		expect_equal(as.numeric(r$b), unname(coef(ref)), tolerance = 1e-5, info = nm)
		expect_equal(r$ssq_b_j, unname(vcov(ref)[2, 2]), tolerance = 1e-3, info = nm)
		expect_equal(unname(solve(r$fisher_information)), unname(vcov(ref)), tolerance = 1e-3, info = nm)
	}
})

test_that("field-set inconsistency: XtWX is present only on the Poisson non-with-var / weighted kernels, never on the with-var kernels", {
	for (nm in names(families)) expect_false("XtWX" %in% names(K(families[[nm]]$fn)(X, families[[nm]]$y, j = 2L)), info = nm)
	expect_true("XtWX" %in% names(K("fast_poisson_regression_cpp")(X, yc)))
	expect_true("XtWX" %in% names(K("fast_poisson_regression_weighted_cpp")(X, yc, weights = rep(1, n))))
	expect_true("XtWX" %in% names(K("fast_logistic_regression_weighted_cpp")(X, yb, weights = rep(1, n))))
	expect_false("XtWX" %in% names(K("fast_logistic_regression_cpp")(X, yb)))
})

test_that("j outside the parameter range gives an NA variance (fit still returned)", {
	for (nm in c("poisson", "logistic")) {
		fn <- K(families[[nm]]$fn)
		r <- fn(X, families[[nm]]$y, j = 9L)
		expect_true(is.na(r$ssq_b_j), info = nm)                                              # observed: a list with NA variance, not an error
		expect_true(is.finite(r$b[1]), info = nm)
	}
})
