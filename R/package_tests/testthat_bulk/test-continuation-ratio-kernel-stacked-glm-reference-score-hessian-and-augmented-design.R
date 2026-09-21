library(testthat)
library(EDI)

# Continuation-ratio kernels (fast_continuation_ratio_regression_cpp / _with_var_cpp / get_continuation_ratio_regression_score_cpp /
# _hessian_cpp): the model is a stacked logistic regression with cut-specific intercepts on the subjects still "at risk" at each cut
# (y >= k), outcome 1{y > k}. Reference: glm(yy ~ 0 + cut + covariates, binomial) on the hand-expanded data; the augmented design
# (X_aug, z) is the same expansion in subject-major order; score / Hessian equal numDeriv derivatives of the stacked log-likelihood;
# ssq_b_j / vcov equal glm's; fixed coefficients and the iteration cap behave as for the other GLM kernels.

skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
f <- K("fast_continuation_ratio_regression_cpp")
set.seed(1); n <- 300L
X <- cbind(x1 = rbinom(n, 1, 0.5), x2 = rnorm(n))
lat <- 0.6 * X[, 1] + 0.4 * X[, 2] + rlogis(n); y <- as.integer(cut(lat, c(-Inf, -0.5, 0.5, 1.5, Inf))); Kc <- max(y)
rows <- do.call(rbind, lapply(seq_len(n), function(i) { ks <- seq_len(min(y[i], Kc - 1L))
	data.frame(sub = i, k = ks, yy = as.integer(y[i] > ks), x1 = unname(X[i, 1]), x2 = unname(X[i, 2])) }))
rows$cut <- factor(rows$k)
g <- glm(yy ~ 0 + cut + x1 + x2, data = rows, family = binomial())
stacked_ll <- function(p) { eta <- p[rows$k] + p[Kc - 1L + 1L] * rows$x1 + p[Kc - 1L + 2L] * rows$x2
	sum(rows$yy * eta - log1p(exp(eta))) }

test_that("coefficients, cut intercepts and log-likelihood equal the stacked glm", {
	r <- f(X, y)
	expect_true(r$converged)
	expect_equal(r$params, unname(coef(g)), tolerance = 1e-5)
	expect_equal(r$alpha, unname(coef(g))[1:(Kc - 1)], tolerance = 1e-5); expect_equal(r$b, unname(coef(g))[-(1:(Kc - 1))], tolerance = 1e-5)
	expect_equal(r$beta_full, r$params)
	expect_equal(r$neg_loglik, -as.numeric(logLik(g)), tolerance = 1e-6)
})

test_that("the augmented design and stacked outcome are the subject-major expansion", {
	r <- f(X, y)
	expect_equal(nrow(r$X_aug), nrow(rows)); expect_equal(as.numeric(r$z), rows$yy)
	ref <- cbind(model.matrix(~ 0 + cut, rows), rows$x1, rows$x2)
	expect_equal(unname(r$X_aug), unname(ref), tolerance = 1e-12)
})

test_that("fisher_information is the stacked information X_aug' W X_aug; score and Hessian kernels equal numDeriv of the stacked log-likelihood", {
	r <- f(X, y); p <- r$params
	eta <- as.numeric(r$X_aug %*% p); w <- plogis(eta) * (1 - plogis(eta))
	expect_equal(unname(r$fisher_information), unname(crossprod(r$X_aug * sqrt(w))), tolerance = 1e-6)
	pp <- p + c(0.05, -0.04, 0.03, 0.02, -0.03)
	expect_equal(as.numeric(K("get_continuation_ratio_regression_score_cpp")(X, y, pp)), numDeriv::grad(stacked_ll, pp), tolerance = 1e-5)
	H <- K("get_continuation_ratio_regression_hessian_cpp")(X, y, pp)
	expect_equal(unname(H), unname(numDeriv::hessian(stacked_ll, pp)), tolerance = 1e-4)
	expect_lt(max(abs(K("get_continuation_ratio_regression_score_cpp")(X, y, p))), 1e-3)
})

test_that("with_var kernel: ssq_b_j and vcov equal the stacked glm's covariance", {
	rv <- K("fast_continuation_ratio_regression_with_var_cpp")(X, y)
	expect_equal(rv$ssq_b_j, unname(vcov(g)[Kc, Kc]), tolerance = 1e-4)
	expect_equal(unname(rv$vcov), unname(vcov(g)), tolerance = 1e-4)
	expect_equal(rv$neg_loglik, -as.numeric(logLik(g)), tolerance = 1e-6)
})

test_that("fixed coefficient equals the offset glm; maxit = 1 reports the iteration cap", {
	r <- f(X, y, fixed_idx = Kc, fixed_values = 0.2)
	expect_equal(r$params[Kc], 0.2)
	ref <- glm(yy ~ 0 + cut + x2, data = rows, offset = 0.2 * rows$x1, family = binomial())
	expect_equal(r$params[-Kc], unname(coef(ref)), tolerance = 1e-3)
	c1 <- f(X, y, maxit = 1L)
	expect_equal(c1$num_iter, 1L); expect_true(c1$hit_iteration_cap); expect_false(c1$converged)
})
