library(testthat)
library(EDI)

# summary_glm_lean(): the lean summary.glm replacement. Existing coverage is one
# binomial fit; here every dispersion branch (estimated t-branch, fixed z-branch,
# user-supplied, zero residual df), aliased coefficients, correlation output and
# the retained fields are compared against stats::summary.glm.

lean <- function(...) get("summary_glm_lean", envir = asNamespace("EDI"))(...)

test_that("estimated-dispersion families use the t branch and match summary.glm", {
	set.seed(1)
	d <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
	d$y <- 1 + 0.5 * d$x1 - 0.3 * d$x2 + rnorm(60)
	d$g <- rgamma(60, shape = 4, rate = 4 / exp(0.5 + 0.2 * d$x1))
	for (fit in list(glm(y ~ x1 + x2, data = d), glm(g ~ x1 + x2, data = d, family = Gamma("log")))) {
		l <- lean(fit); r <- summary(fit)
		expect_equal(l$coefficients, r$coefficients, tolerance = 1e-10)
		expect_equal(colnames(l$coefficients)[3:4], c("t value", "Pr(>|t|)"))
		expect_equal(l$dispersion, r$dispersion, tolerance = 1e-10)
		expect_equal(l$df, r$df)
		expect_equal(l$cov.scaled, r$cov.scaled, tolerance = 1e-10)
		expect_equal(l$cov.unscaled, r$cov.unscaled, tolerance = 1e-10)
		expect_equal(l$aliased, r$aliased)
		expect_s3_class(l, "summary.glm")
	}
})

test_that("Poisson and binomial use a fixed dispersion of one with z statistics", {
	set.seed(2)
	d <- data.frame(x = rnorm(80))
	d$c <- rpois(80, exp(0.3 + 0.4 * d$x))
	fit <- glm(c ~ x, data = d, family = poisson())
	l <- lean(fit); r <- summary(fit)
	expect_equal(l$dispersion, 1)
	expect_equal(colnames(l$coefficients)[3:4], c("z value", "Pr(>|z|)"))
	expect_equal(l$coefficients, r$coefficients, tolerance = 1e-10)
})

test_that("a user-supplied dispersion rescales the covariance and switches to z statistics", {
	set.seed(3)
	d <- data.frame(x = rnorm(50)); d$y <- 2 + d$x + rnorm(50)
	fit <- glm(y ~ x, data = d)
	l <- lean(fit, dispersion = 4)
	r <- summary(fit, dispersion = 4)
	expect_equal(l$dispersion, 4)
	expect_equal(l$coefficients, r$coefficients, tolerance = 1e-10)
	expect_equal(l$cov.scaled, 4 * l$cov.unscaled)
})

test_that("aliased coefficients are flagged and excluded from the coefficient table", {
	set.seed(4)
	d <- data.frame(x = rnorm(40)); d$dup <- 2 * d$x; d$y <- 1 + d$x + rnorm(40)
	fit <- glm(y ~ x + dup, data = d)
	l <- lean(fit); r <- summary(fit)
	expect_equal(unname(l$aliased), unname(r$aliased))
	expect_equal(unname(l$aliased), c(FALSE, FALSE, TRUE))
	expect_equal(rownames(l$coefficients), rownames(r$coefficients))
	expect_equal(l$coefficients, r$coefficients, tolerance = 1e-10)
	expect_equal(l$df, r$df)
})

test_that("a saturated fit (no residual df) yields NaN inference rather than an error", {
	d <- data.frame(x = c(1, 2), y = c(1, 3))
	fit <- glm(y ~ x, data = d)
	l <- lean(fit)
	expect_true(is.nan(l$dispersion))
	expect_true(all(is.nan(l$coefficients[, 2:4])))
	expect_equal(l$coefficients[, 1], coef(fit))
	expect_equal(colnames(l$coefficients)[3:4], c("t value", "Pr(>|t|)"))
})

test_that("correlation = TRUE adds the coefficient correlation matrix", {
	set.seed(5)
	d <- data.frame(x1 = rnorm(50), x2 = rnorm(50)); d$y <- d$x1 + d$x2 + rnorm(50)
	fit <- glm(y ~ x1 + x2, data = d)
	l <- lean(fit, correlation = TRUE, symbolic.cor = TRUE)
	r <- summary(fit, correlation = TRUE, symbolic.cor = TRUE)
	expect_equal(l$correlation, r$correlation, tolerance = 1e-10)
	expect_true(l$symbolic.cor)
	expect_equal(unname(diag(l$correlation)), rep(1, 3))
	expect_null(lean(fit)$correlation)
})

test_that("the lean object drops the heavy residual/weight components but keeps the summary fields", {
	set.seed(6)
	d <- data.frame(x = rnorm(30)); d$y <- d$x + rnorm(30)
	l <- lean(glm(y ~ x, data = d))
	expect_null(l$deviance.resid)
	expect_true(all(c("call", "terms", "family", "deviance", "aic", "df.residual", "null.deviance", "df.null", "iter") %in% names(l)))
})
