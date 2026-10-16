library(testthat)
library(EDI)

test_that("fast_logistic_regression_with_var drops a separated nuisance covariate and matches glm on the retained model", {
	set.seed(20261016L)
	n <- 80L
	w <- rep(0:1, each = n / 2L)
	x_sep <- rep(c(-1e-8, 1e-8), length.out = n)
	y <- as.numeric(x_sep > 0)
	X <- cbind("(Intercept)" = 1, treatment = w, separated = x_sep)

	got <- EDI:::fast_logistic_regression_with_var(X, y, j = 2L)
	ref <- glm(y ~ w, family = binomial())
	expect_equal(unname(got$b), unname(coef(ref)), tolerance = 1e-5)
	expect_equal(got$ssq_b_j, vcov(ref)["w", "w"], tolerance = 1e-5)
})
