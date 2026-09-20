library(testthat)
library(EDI)

# InferenceIncidLogRegr's g-computation layer: logistic_mean_from_coefs(),
# logistic_marginal_functional() (marginal risk difference and log risk ratio) and
# compute_marginal_estimand_estimate() -- success path against glm() plus a
# hand-rolled delta method, and its four nonestimable branches.

lg_fx <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.4 + 0.8 * w + 0.5 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x = x, y = y, n = n)
}

test_that("mean is the inverse-logit of the linear predictor", {
	p <- lg_fx()$p
	set.seed(1)
	X <- cbind(1, rbinom(8, 1, 0.5), rnorm(8)); b <- c(-0.2, 0.9, 0.4)
	expect_equal(p$logistic_mean_from_coefs(b, X), plogis(drop(X %*% b)), tolerance = 1e-14)
	expect_equal(p$logistic_mean_from_coefs(c(0, 0, 0), X), rep(0.5, 8))
})

test_that("marginal functional: RD is mu1 - mu0, RR is log(mu1 / mu0), averaged over the empirical covariates", {
	p <- lg_fx()$p
	set.seed(2)
	w <- rbinom(30, 1, 0.5); x <- rnorm(30)
	X <- cbind(1, w, x); b <- c(-0.3, 0.7, 0.5)
	mu1 <- mean(plogis(b[1] + b[2] + b[3] * x)); mu0 <- mean(plogis(b[1] + b[3] * x))
	expect_equal(p$logistic_marginal_functional(b, X, "marginal_mean_diff"), mu1 - mu0, tolerance = 1e-12)
	expect_equal(p$logistic_marginal_functional(b, X, "marginal_ratio"), log(mu1 / mu0), tolerance = 1e-12)
	# The observed treatment column is irrelevant, and a zero effect gives RD 0 / log RR 0.
	X2 <- X; X2[, 2] <- 1 - X2[, 2]
	expect_equal(p$logistic_marginal_functional(b, X2, "marginal_mean_diff"), mu1 - mu0, tolerance = 1e-12)
	expect_equal(p$logistic_marginal_functional(c(-0.3, 0, 0.5), X, "marginal_ratio"), 0, tolerance = 1e-12)
	# Any other label is treated as the difference.
	expect_equal(p$logistic_marginal_functional(b, X, "whatever"), mu1 - mu0, tolerance = 1e-12)
})

test_that("marginal RD / log RR estimates and delta-method SEs match glm() and a hand-rolled gradient", {
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		f <- lg_fx()
		f$inf$set_estimand(est)
		pt <- f$inf$compute_estimate()
		se <- f$p$cached_values$s_beta_hat_T
		g <- glm(f$y ~ f$w + f$x, family = binomial())
		X <- cbind(1, f$w, f$x); b <- coef(g)
		fun <- function(b) {
			X1 <- X; X1[, 2] <- 1; X0 <- X; X0[, 2] <- 0
			m1 <- mean(plogis(X1 %*% b)); m0 <- mean(plogis(X0 %*% b))
			if (est == "marginal_ratio") log(m1 / m0) else m1 - m0
		}
		grad <- numDeriv::grad(fun, unname(b))
		ref_se <- sqrt(drop(t(grad) %*% vcov(g) %*% grad))
		expect_equal(pt, fun(unname(b)), tolerance = 1e-5, info = est)
		expect_equal(se, ref_se, tolerance = 5e-3, info = est)
		expect_equal(f$p$cached_values$df, Inf)
		expect_false(f$inf$is_nonestimable("any"))
		expect_equal(f$inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(pt / se)), tolerance = 1e-6, info = est)
	}
})

test_that("estimate_only returns the point without an SE", {
	f <- lg_fx(); f$inf$set_estimand("marginal_mean_diff")
	full <- f$inf$compute_estimate()
	g <- lg_fx(); g$inf$set_estimand("marginal_mean_diff")
	expect_equal(g$inf$compute_estimate(estimate_only = TRUE), full, tolerance = 1e-8)
})

test_that("failure branches: no fit, unavailable point, no vcov, unusable SE", {
	mk <- function() { f <- lg_fx(); f$inf$compute_estimate(); f }
	f <- mk(); f$p$cached_mod <- NULL
	expect_true(is.na(f$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(f$inf$get_nonestimable_reason(), "logistic_marginal_fit_unavailable")
	g <- mk(); g$p$cached_mod$X <- NULL
	expect_true(is.na(g$p$compute_marginal_estimand_estimate("marginal_ratio")))
	expect_identical(g$inf$get_nonestimable_reason(), "logistic_marginal_fit_unavailable")
	h <- mk(); h$p$cached_mod$b[2] <- NA_real_
	expect_true(is.na(h$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(h$inf$get_nonestimable_reason(), "logistic_marginal_point_unavailable")
	k <- mk(); k$p$cached_mod$vcov <- NULL
	pt <- k$p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_true(is.finite(pt))
	expect_identical(k$inf$get_nonestimable_reason(), "logistic_marginal_vcov_unavailable")
	expect_true(k$inf$is_nonestimable("se"))
	m <- mk(); m$p$cached_mod$vcov <- matrix(-1, 3, 3)
	m$p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_identical(m$inf$get_nonestimable_reason(), "logistic_marginal_se_unavailable")
	# A saturated arm makes the log ratio undefined: mu0 = 0 -> point unavailable.
	s <- mk(); s$p$cached_mod$b <- c(-800, 900, 0)
	s$p$cached_mod$X <- cbind(1, s$w, s$x)
	expect_true(is.na(s$p$compute_marginal_estimand_estimate("marginal_ratio")))
	expect_identical(s$inf$get_nonestimable_reason(), "logistic_marginal_point_unavailable")
})
