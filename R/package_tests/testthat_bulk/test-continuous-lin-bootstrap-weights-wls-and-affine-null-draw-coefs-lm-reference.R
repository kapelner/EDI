library(testthat)
library(EDI)

# InferenceContinLin: compute_estimate_with_bootstrap_weights() is weighted least squares on the Lin design
# (reference: stats::lm(y ~ w * Xc, weights)), drops non-positive/non-finite weights, returns NA when nothing is
# left, and compute_rand_bootstrap_ci_affine_coefs() gives A_b + delta * c_b equal to the Lin coefficient on
# the shifted-response refit for each bootstrap draw (reference: lm on the resampled data).

set.seed(11); n <- 40L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
des <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 3L, verbose = FALSE)
des$add_all_subjects_to_experiment(X)
des$assign_w_to_all_subjects()
w <- des$get_w()
set.seed(12); y <- rnorm(n) + 1.5 * w + X$x1
des$add_all_subject_responses(y)
mk <- function() {
	inf <- InferenceContinLin$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
	list(inf = inf, p = p)
}
Xc <- scale(as.matrix(X), center = TRUE, scale = FALSE)
ref_wls <- function(wt, keep = rep(TRUE, n)) {
	d <- data.frame(y = y, w = w, Xc)[keep, ]
	unname(coef(lm(y ~ w * (x1 + x2), data = d, weights = wt[keep]))["w"])
}

test_that("weighted refit equals lm(y ~ w * Xc, weights) and caches beta, weighted SE and df", {
	f <- mk()
	set.seed(1); wt <- rexp(n)
	est <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	expect_equal(est, ref_wls(wt), tolerance = 1e-8)
	# the public wrapper runs isolated; call the underlying implementation to inspect the cache it fills
	expect_equal(f$p$weighted_refit_impl(wt), est)
	expect_equal(f$p$cached_values$beta_hat_T, est)
	expect_equal(f$p$cached_values$df, n - 6)
	fit <- lm(y ~ w * (x1 + x2), data = data.frame(y = y, w = w, Xc), weights = wt)
	se_ref <- sqrt(sum(wt * resid(fit)^2) / (n - 6) * solve(crossprod(model.matrix(fit) * sqrt(wt)))[2, 2])
	expect_equal(f$p$cached_values$s_beta_hat_T, se_ref, tolerance = 1e-8)
})

test_that("estimate_only skips the variance and clears cached SE/df", {
	f <- mk()
	set.seed(2); wt <- rexp(n)
	f$inf$compute_estimate_with_bootstrap_weights(wt)
	est <- f$p$weighted_refit_impl(wt, estimate_only = TRUE)
	expect_equal(est, ref_wls(wt), tolerance = 1e-8)
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(is.na(f$p$cached_values$df))
})

test_that("zero weights drop rows from the fit (still the full-data centring)", {
	f <- mk()
	set.seed(3); wt <- rexp(n); wt[c(2, 9, 17)] <- 0
	keep <- is.finite(wt) & wt > 0
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(wt), ref_wls(wt, keep), tolerance = 1e-8)
	f$p$weighted_refit_impl(wt)
	expect_equal(f$p$cached_values$df, sum(keep) - 6)
	expect_error(f$inf$compute_estimate_with_bootstrap_weights(replace(wt, 5, NA)), "missing values")
})

test_that("all-zero weights give NA and clear the cached estimate, SE and df", {
	f <- mk()
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(0, n))))
	f$p$weighted_refit_impl(rep(0, n))
	expect_true(is.na(f$p$cached_values$beta_hat_T))
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_true(is.na(f$p$cached_values$df))
})

test_that("affine null-draw coefficients reproduce the Lin coefficient of the delta-shifted resampled data", {
	f <- mk()
	set.seed(4)
	draws <- lapply(1:4, function(b) list(i_b = sample.int(n, n, replace = TRUE), w_b = sample(rep(0:1, length.out = n))))
	ab <- f$p$compute_rand_bootstrap_ci_affine_coefs(draws)
	expect_length(ab$A, 4L)
	for (b in 1:4) {
		i <- draws[[b]]$i_b; wf <- draws[[b]]$w_b
		for (delta in c(0, 0.7, -1.3)) {
			ysim <- y[i] - delta * w[i] + delta * wf
			d <- data.frame(y = ysim, w = wf, Xc[i, ])
			ref <- unname(coef(lm(y ~ w * (x1 + x2), data = d))["w"])
			expect_equal(ab$A[b] + delta * ab$c[b], ref, tolerance = 1e-7, info = paste(b, delta))
		}
	}
})

test_that("affine coefficients: empty draws give NULL, malformed draws give NULL, degenerate arms give NA", {
	f <- mk()
	expect_null(f$p$compute_rand_bootstrap_ci_affine_coefs(list()))
	expect_null(f$p$compute_rand_bootstrap_ci_affine_coefs(list(list(i_b = 1:5, w_b = rep(0:1, length.out = 5)))))
	expect_null(f$p$compute_rand_bootstrap_ci_affine_coefs(list(list(i_b = 1:n, w_b = NULL))))
	ab <- f$p$compute_rand_bootstrap_ci_affine_coefs(list(list(i_b = 1:n, w_b = rep(1, n)), list(i_b = 1:n, w_b = rep(0, n))))
	expect_true(all(is.na(ab$A)))
	expect_true(all(is.na(ab$c)))
})
