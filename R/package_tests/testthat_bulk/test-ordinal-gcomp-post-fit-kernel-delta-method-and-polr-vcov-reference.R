library(testthat)
library(EDI)

# ordinal_gcomp_post_fit_cpp(X, y, coef, alpha, j_treat): g-computation on a proportional-odds fit.
# Checked against MASS::polr: the model-based covariance / SEs / z of the coefficients, the standardized mean
# category scores under all-treated / all-control, their difference, and the delta-method SE of the difference
# built from numDeriv gradients and polr's full (coefficients + thresholds) covariance. Also: invariance to the
# numeric coding of y, and the error branches.

skip_if_not_installed("MASS")
skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	w <- rbinom(n, 1, 0.5); x <- rnorm(n)
	y <- as.integer(cut(0.9 * w + 0.4 * x + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	X <- cbind(w = w, x = x)
	po <- MASS::polr(factor(y) ~ w + x, Hess = TRUE)
	list(X = X, y = y, po = po, b = as.numeric(coef(po)), a = as.numeric(po$zeta))
}
cat_probs <- function(Xm, b, a) {
	eta <- drop(Xm %*% b)
	cdf <- cbind(0, vapply(a, function(t) plogis(t - eta), numeric(nrow(Xm))), 1)
	cdf[, -1] - cdf[, -ncol(cdf)]
}

test_that("coefficient covariance, SEs and z-values equal polr's model-based ones", {
	f <- fx()
	r <- K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b, f$a, 1L)
	V <- vcov(f$po)[1:2, 1:2]
	expect_equal(unname(r$vcov), unname(V), tolerance = 1e-4)
	expect_equal(as.numeric(r$std_err), unname(sqrt(diag(V))), tolerance = 1e-4)
	expect_equal(as.numeric(r$z_vals), f$b / unname(sqrt(diag(V))), tolerance = 1e-4)
})

test_that("standardized mean scores, their difference and the delta-method SE match hand computations", {
	f <- fx()
	X1 <- f$X; X1[, 1] <- 1; X0 <- f$X; X0[, 1] <- 0
	md_fun <- function(theta) mean(cat_probs(X1, theta[1:2], theta[3:5]) %*% 1:4) - mean(cat_probs(X0, theta[1:2], theta[3:5]) %*% 1:4)
	th <- c(f$b, f$a)
	r <- K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b, f$a, 1L)
	expect_equal(r$mean1, mean(cat_probs(X1, f$b, f$a) %*% 1:4), tolerance = 1e-8)
	expect_equal(r$mean0, mean(cat_probs(X0, f$b, f$a) %*% 1:4), tolerance = 1e-8)
	expect_equal(r$md, r$mean1 - r$mean0, tolerance = 1e-12)
	expect_equal(r$md, md_fun(th), tolerance = 1e-8)
	V <- vcov(f$po)[c("w", "x", "1|2", "2|3", "3|4"), c("w", "x", "1|2", "2|3", "3|4")]
	g <- numDeriv::grad(md_fun, th)
	expect_equal(r$se_md, sqrt(as.numeric(t(g) %*% V %*% g)), tolerance = 1e-4)
})

test_that("only the category ordering of y matters, not its numeric coding", {
	f <- fx()
	a <- K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b, f$a, 1L)
	b <- K("ordinal_gcomp_post_fit_cpp")(f$X, f$y * 10 + 3, f$b, f$a, 1L)
	expect_equal(a$md, b$md, tolerance = 1e-12)
	expect_equal(a$se_md, b$se_md, tolerance = 1e-10)
})

test_that("out-of-bounds treatment index and dimension mismatches stop with clear messages", {
	f <- fx()
	expect_error(K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b, f$a, 3L), "treatment column index is out of bounds")
	expect_error(K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b, f$a, 0L), "treatment column index is out of bounds")
	expect_error(K("ordinal_gcomp_post_fit_cpp")(f$X, f$y, f$b[1], f$a, 1L), "dimension mismatch")
	expect_error(K("ordinal_gcomp_post_fit_cpp")(f$X, f$y[-1], f$b, f$a, 1L), "dimension mismatch")
})
