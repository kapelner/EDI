library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's g-computation layer:
# identity_binomial_mean_from_coefs(), identity_binomial_marginal_functional()
# (exactly beta[2] without interactions) and compute_marginal_estimand_estimate()'s
# success path (point = conditional coefficient, delta-method SE = its own SE) and
# its four nonestimable branches, driven by editing the cached fit.

bi_fx <- function(seed = 1L, n = 150L) {
	set.seed(seed)
	w <- rep(0:1, n / 2); x1 <- rnorm(n, sd = 0.4)
	y <- rbinom(n, 1, pmin(pmax(0.3 + 0.15 * w + 0.1 * x1, 0.02), 0.98))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x1 = x1, y = y, n = n)
}

test_that("mean_from_coefs is the linear predictor; the marginal functional equals beta[2] for every design matrix", {
	p <- bi_fx()$p
	set.seed(2)
	X <- cbind(1, rbinom(10, 1, 0.5), rnorm(10), rnorm(10))
	b <- c(0.3, 0.12, -0.05, 0.2)
	expect_equal(p$identity_binomial_mean_from_coefs(b, X), drop(X %*% b))
	expect_equal(p$identity_binomial_marginal_functional(b, X), b[2], tolerance = 1e-12)
	X2 <- X; X2[, 2] <- 0                                        # the treatment column is overwritten, not read
	expect_equal(p$identity_binomial_marginal_functional(b, X2), b[2], tolerance = 1e-12)
	b2 <- c(0.1, -0.4, 1, 1)
	expect_equal(p$identity_binomial_marginal_functional(b2, X), -0.4, tolerance = 1e-12)
})

test_that("with an interaction column the functional is the average of the implied treatment contrasts", {
	p <- bi_fx()$p
	set.seed(3)
	w <- rbinom(12, 1, 0.5); x <- rnorm(12)
	# Column 2 is the treatment; the interaction column is a fixed covariate here, so it does not change with w.
	X <- cbind(1, w, x, w * x)
	b <- c(0.2, 0.1, 0.05, 0.3)
	X1 <- X; X1[, 2] <- 1; X0 <- X; X0[, 2] <- 0
	expect_equal(p$identity_binomial_marginal_functional(b, X), mean(X1 %*% b) - mean(X0 %*% b), tolerance = 1e-12)
})

test_that("marginal_mean_diff succeeds with point = conditional coefficient and SE from the fitted vcov (df = Inf)", {
	f <- bi_fx()
	est <- f$inf$compute_estimate(); f$inf$compute_asymp_confidence_interval()
	cond_se <- f$p$cached_values$s_beta_hat_T
	mod <- f$p$cached_mod
	expect_equal(est, unname(mod$b[2]), tolerance = 1e-10)
	expect_equal(cond_se, sqrt(mod$vcov[2, 2]), tolerance = 1e-4)

	g <- bi_fx()
	g$inf$set_estimand("marginal_mean_diff")
	pt <- g$inf$compute_estimate()
	expect_equal(pt, est, tolerance = 1e-8)
	expect_equal(g$p$cached_values$s_beta_hat_T, cond_se, tolerance = 1e-4)     # gradient is e_2, so var = vcov[2, 2]
	expect_equal(g$p$cached_values$df, Inf)
	expect_false(g$inf$is_nonestimable("any"))
	# estimate_only returns the point without an SE.
	h <- bi_fx(); h$inf$set_estimand("marginal_mean_diff")
	expect_equal(h$inf$compute_estimate(estimate_only = TRUE), est, tolerance = 1e-8)
})

test_that("failure branches: missing fit, unavailable point, missing vcov, unusable SE", {
	f <- bi_fx(); f$inf$compute_estimate()
	f$p$cached_mod <- NULL
	expect_true(is.na(f$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(f$inf$get_nonestimable_reason(), "identity_binomial_marginal_fit_unavailable")

	g <- bi_fx(); g$inf$compute_estimate()
	g$p$cached_mod$X <- NULL
	expect_true(is.na(g$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(g$inf$get_nonestimable_reason(), "identity_binomial_marginal_fit_unavailable")

	h <- bi_fx(); h$inf$compute_estimate()
	h$p$cached_mod$b[2] <- NA_real_
	expect_true(is.na(h$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(h$inf$get_nonestimable_reason(), "identity_binomial_marginal_point_unavailable")

	k <- bi_fx(); pt <- k$inf$compute_estimate()
	k$p$cached_mod$vcov <- NULL
	expect_equal(k$p$compute_marginal_estimand_estimate("marginal_mean_diff"), pt, tolerance = 1e-10)
	expect_true(k$inf$is_nonestimable("se"))
	expect_identical(k$inf$get_nonestimable_reason(), "identity_binomial_marginal_vcov_unavailable")

	m <- bi_fx(); pt <- m$inf$compute_estimate()
	m$p$cached_mod$vcov <- matrix(-1, 3, 3)                        # negative variance -> unusable SE
	expect_equal(m$p$compute_marginal_estimand_estimate("marginal_mean_diff"), pt, tolerance = 1e-10)
	expect_identical(m$inf$get_nonestimable_reason(), "identity_binomial_marginal_se_unavailable")
	expect_true(m$inf$is_nonestimable("se"))
})
