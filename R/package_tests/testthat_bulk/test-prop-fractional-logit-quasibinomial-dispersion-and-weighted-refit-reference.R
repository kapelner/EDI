library(testthat)
library(EDI)

# InferencePropFractionalLogit: the Papke-Wooldridge quasi-binomial dispersion
# correction in generate_mod() (estimate and SE against glm(family = quasibinomial)),
# the non-hardened estimate_only path, the weighted refit (against a weighted
# quasibinomial glm; zero weights dropped; all-zero -> NA) and the class flags.

fx <- function(harden = TRUE, seed = 6L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- pmin(pmax(plogis(-0.2 + 0.5 * w + 0.4 * X$x + rnorm(n, sd = 0.8)), 0.01), 0.99)
	des$add_all_subject_responses(y)
	inf <- InferencePropFractionalLogit$new(des, verbose = FALSE, harden = harden)
	inf$num_cores <- 1L
	priv <- inf$.__enclos_env__$private
	unlockBinding("expand_subject_or_block_weights_to_row_weights", priv)
	priv$expand_subject_or_block_weights_to_row_weights <- function(w) w
	list(inf = inf, priv = priv, X = X, y = y, w = w, n = n)
}

test_that("estimate and SE equal the quasi-binomial glm (naive Bernoulli variance scaled by Pearson dispersion)", {
	f <- fx()
	g <- glm(f$y ~ f$w + f$X$x, family = quasibinomial())
	s <- summary(g)$coefficients
	expect_equal(f$inf$compute_estimate(), unname(s[2, 1]), tolerance = 1e-6)
	expect_equal(f$priv$get_standard_error(), unname(s[2, 2]), tolerance = 1e-5)
	# The correction is the Pearson dispersion: SE^2 = phi * naive Bernoulli variance.
	phi <- summary(g)$dispersion
	binom_se <- suppressWarnings(summary(glm(f$y ~ f$w + f$X$x, family = binomial()))$coefficients[2, 2])
	expect_equal(f$priv$get_standard_error(), binom_se * sqrt(phi), tolerance = 1e-5)
	expect_equal(f$priv$best_X_colnames, "x")
})

test_that("a Wald p-value uses the corrected SE", {
	f <- fx()
	g <- summary(glm(f$y ~ f$w + f$X$x, family = quasibinomial()))$coefficients
	z <- g[2, 1] / g[2, 2]
	expect_equal(f$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(z)), tolerance = 1e-4)
})

test_that("estimate_only without hardening uses a plain quasi-binomial glm.fit and records the covariate columns", {
	f <- fx(harden = FALSE)
	est <- f$inf$compute_estimate(estimate_only = TRUE)
	expect_equal(est, unname(coef(glm(f$y ~ f$w + f$X$x, family = quasibinomial()))[2]), tolerance = 1e-6)
	expect_equal(f$priv$best_X_colnames, "x")
	# A second call returns the cached value untouched.
	f$priv$cached_values$beta_hat_T <- 123
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), 123)
})

test_that("the weighted refit matches a weighted quasi-binomial glm and drops zero-weight rows", {
	f <- fx()
	set.seed(9)
	wt <- rexp(f$n)
	got <- f$inf$compute_estimate_with_bootstrap_weights(wt)
	ref <- unname(coef(suppressWarnings(glm(f$y ~ f$w + f$X$x, family = quasibinomial(), weights = wt)))[2])
	expect_equal(got, ref, tolerance = 5e-3)
	# Scale-free: only relative weights matter.
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(10 * wt), got, tolerance = 1e-6)
	wt0 <- wt; wt0[c(3, 10)] <- 0
	keep <- wt0 > 0
	got0 <- f$inf$compute_estimate_with_bootstrap_weights(wt0)
	ref0 <- unname(coef(suppressWarnings(glm(f$y[keep] ~ f$w[keep] + f$X$x[keep], family = quasibinomial(), weights = wt0[keep])))[2])
	expect_equal(got0, ref0, tolerance = 5e-3)
})

test_that("all-zero, negative or non-finite weights give NA and clear the cached SE", {
	f <- fx()
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(0, f$n))))
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(-1, f$n))))
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(rep(NA_real_, f$n))))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T) || is.null(f$priv$cached_values$s_beta_hat_T))
})

test_that("likelihood tests are off for this quasi-likelihood class, and a class-level proportion response is required", {
	f <- fx()
	expect_false(f$priv$supports_likelihood_tests())
	expect_equal(f$inf$get_supported_testing_types(), "wald")
	set.seed(1)
	des <- DesignFixediBCRD$new(n = 10L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(10)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(10))
	expect_error(InferencePropFractionalLogit$new(des, verbose = FALSE))
})
