library(testthat)
library(EDI)

# robust_negbinreg() (helper_robust_regression.R) has zero test references
# anywhere -- confirmed via repo-wide grep. It wraps MASS::glm.nb() with a
# retry loop that drops the LAST data-frame column and refits whenever the
# fit errors, until either a fit succeeds or no columns remain (returning NA).
# Called from design_seq_one_by_one_KK21_stepwise.R's negative-binomial
# covariate-model refresh.
#
# NOTE: the ncol(data_obj) == 0 -> NA fallback branch is not exercised here.
# Constructing a fixture that survives every column drop down to a
# response-only intercept model, yet still fails MASS::glm.nb, requires a
# genuinely degenerate response (e.g. a constant response, tried during
# exploration); glm.nb's internal theta-estimation loop does not error
# cleanly on that input within a reasonable time budget, so asserting it here
# would risk an unreliable/hanging test. The retry-and-succeed path below is
# covered instead, which is the realistic call pattern from the one caller.

test_that("robust_negbinreg matches an independent MASS::glm.nb fit when the first attempt already succeeds", {
	set.seed(2026)
	n <- 40L
	x1 <- rnorm(n)
	x2 <- rnorm(n)
	y <- rnbinom(n, size = 3, mu = exp(1 + 0.3 * x1 - 0.2 * x2))
	df <- data.frame(response_obj = y, x1 = x1, x2 = x2)

	res <- EDI:::robust_negbinreg(response_obj ~ ., df)
	ref <- suppressWarnings(MASS::glm.nb(response_obj ~ ., data = df))

	expect_s3_class(res, "negbin")
	expect_equal(unname(coef(res)), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(unname(res$theta), unname(ref$theta), tolerance = 1e-6)
})

test_that("robust_negbinreg drops one trailing bad column and refits successfully", {
	set.seed(3)
	n <- 40L
	x1 <- rnorm(n)
	x_bad <- rep(Inf, n)
	y <- rnbinom(n, size = 2, mu = exp(1.2 + 0.25 * x1))
	df <- data.frame(response_obj = y, x1 = x1, x_bad = x_bad)

	res <- EDI:::robust_negbinreg(response_obj ~ ., df)
	ref <- suppressWarnings(MASS::glm.nb(response_obj ~ x1, data = df))

	expect_s3_class(res, "negbin")
	expect_equal(names(coef(res)), c("(Intercept)", "x1"))
	expect_equal(unname(coef(res)), unname(coef(ref)), tolerance = 1e-6)
})

test_that("robust_negbinreg drops multiple trailing bad columns one at a time until a fit succeeds", {
	set.seed(4)
	n <- 40L
	x1 <- rnorm(n)
	x_bad1 <- rep(NaN, n)
	x_bad2 <- rep(Inf, n)
	y <- rnbinom(n, size = 3, mu = exp(1.1 + 0.2 * x1))
	df <- data.frame(response_obj = y, x1 = x1, x_bad1 = x_bad1, x_bad2 = x_bad2)

	res <- EDI:::robust_negbinreg(response_obj ~ ., df)
	ref <- suppressWarnings(MASS::glm.nb(response_obj ~ x1, data = df))

	expect_s3_class(res, "negbin")
	# Both trailing bad columns were dropped, not just the last one.
	expect_equal(names(coef(res)), c("(Intercept)", "x1"))
	expect_equal(unname(coef(res)), unname(coef(ref)), tolerance = 1e-6)
})

test_that("robust_negbinreg falls back to an intercept-only fit when every covariate column is unusable", {
	set.seed(5)
	n <- 40L
	y <- rnbinom(n, size = 2, mu = 6)
	df <- data.frame(response_obj = y, x_bad = rep(Inf, n))

	res <- EDI:::robust_negbinreg(response_obj ~ ., df)
	ref <- suppressWarnings(MASS::glm.nb(response_obj ~ 1, data = df))

	expect_s3_class(res, "negbin")
	expect_equal(names(coef(res)), "(Intercept)")
	expect_equal(unname(coef(res)), unname(coef(ref)), tolerance = 1e-6)
})
