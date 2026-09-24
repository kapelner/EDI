library(testthat)
library(EDI)

# fast_beta_regression()'s 3-stage fallback chain (helper_glm_fit.R): primary fast_beta_regression_cpp()
# fit; on failure, falls back to betareg::betareg() (if installed); if betareg is unavailable OR its own
# fit also fails, falls back to a final OLS-on-logit(y) fit (fast_ols_cpp). Each stage transition issues
# its own documented warning(). A codebase-wide grep confirmed all 3 exact warning messages had zero
# test references anywhere -- the function's only existing reference (test-fast-glm-direct-helper-
# reference.R) exercises only the happy-path primary fit against an independent betareg reference,
# never any fallback branch. Reached via with_mocked_bindings() forcing fast_beta_regression_cpp() to
# error (so every scenario enters the fallback chain), combined with mocking check_package_installed()
# or betareg::betareg() itself to force each specific downstream branch, independent of the real
# solvers' actual numerical behavior.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	X <- cbind(1, x1 = rnorm(n))
	y <- pmin(pmax(plogis(0.3 * X[, 2]) + rnorm(n, sd = 0.02), 0.001), 0.999)
	list(X = X, y = y)
}

test_that("a primary-fit failure falls back to betareg::betareg(), with the documented warning and betareg's own coefficients used", {
	f <- fx(1L)
	stub_coefs <- c("(Intercept)" = 0.1, "x1" = 0.5, "(phi)" = 12.3)
	with_mocked_bindings(
		fast_beta_regression_cpp = function(...) stop("forced cpp failure"),
		.package = "EDI",
		code = {
			with_mocked_bindings(
				betareg = function(...) list(coefficients = stub_coefs),
				.package = "betareg",
				code = {
					expect_warning(
						res <- fast_beta_regression(f$X, f$y),
						"fast_beta_regression_cpp failed, falling back to betareg. Error: forced cpp failure",
						fixed = TRUE
					)
					expect_equal(res$b, stub_coefs)
					expect_equal(res$phi, 12.3)
				}
			)
		}
	)
})

test_that("a primary-fit failure with betareg unavailable falls all the way through to OLS on logit(y), with both documented warnings", {
	f <- fx(2L)
	with_mocked_bindings(
		fast_beta_regression_cpp = function(...) stop("forced cpp failure"),
		check_package_installed = function(...) FALSE,
		.package = "EDI",
		code = {
			warns <- character(0)
			res <- withCallingHandlers(
				fast_beta_regression(f$X, f$y),
				warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }
			)
			expect_true(any(grepl("fast_beta_regression_cpp failed, falling back to betareg. Error: forced cpp failure", warns, fixed = TRUE)))
			expect_true(any(grepl("Package 'betareg' is not installed; skipping betareg fallback and using OLS on logit(y).", warns, fixed = TRUE)))
			expect_equal(res$b, fast_ols_cpp(f$X, logit(f$y))$b)
		}
	)
})

test_that("a primary-fit failure AND a failing betareg fit both fall through to OLS on logit(y), with both documented warnings", {
	f <- fx(3L)
	with_mocked_bindings(
		fast_beta_regression_cpp = function(...) stop("forced cpp failure"),
		.package = "EDI",
		code = {
			with_mocked_bindings(
				betareg = function(...) stop("forced betareg failure"),
				.package = "betareg",
				code = {
					warns <- character(0)
					res <- withCallingHandlers(
						fast_beta_regression(f$X, f$y),
						warning = function(w) { warns <<- c(warns, conditionMessage(w)); invokeRestart("muffleWarning") }
					)
					expect_true(any(grepl("fast_beta_regression_cpp failed, falling back to betareg. Error: forced cpp failure", warns, fixed = TRUE)))
					expect_true(any(grepl("betareg fallback failed, using OLS on logit(y). Error: forced betareg failure", warns, fixed = TRUE)))
					expect_equal(res$b, fast_ols_cpp(f$X, logit(f$y))$b)
				}
			)
		}
	)
})

test_that("a well-behaved primary fit never triggers any fallback warning", {
	f <- fx(4L)
	expect_no_warning(fast_beta_regression(f$X, f$y))
})
