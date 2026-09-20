library(testthat)
library(EDI)

# invert_test_pval_confidence_interval() (InferenceExtCIInversion): the score,
# gradient and likelihood-ratio test-inversion confidence intervals of
# InferenceIncidLogRegr, checked against independent references built from base
# glm() profile fits: for each candidate null delta, refit
# glm(y ~ x + offset(delta * w)) and compare the classical chi-square(1)
# statistic to its critical value; the CI endpoints are the two roots.
# Only the finalize_inverted_ci policy had prior direct tests.

logit_ci_fixture <- function(n = 80L, seed = 2L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, x = x, y = y)
}

profile_stats <- function(f) {
	g <- glm(f$y ~ f$w + f$x, family = binomial())
	ll_full <- as.numeric(logLik(g))
	bhat <- unname(coef(g)[2])
	se <- sqrt(vcov(g)[2, 2])
	null_fit <- function(delta) glm(f$y ~ f$x + offset(delta * f$w), family = binomial())
	lr <- function(delta) 2 * (ll_full - as.numeric(logLik(null_fit(delta))))
	score <- function(delta) {
		m <- null_fit(delta)
		mu <- fitted(m); W <- mu * (1 - mu)
		X <- cbind(1, f$x, f$w)
		U_w <- sum(f$w * (f$y - mu))
		I <- crossprod(X * sqrt(W))
		I_eff <- I[3, 3] - I[3, 1:2] %*% solve(I[1:2, 1:2]) %*% I[1:2, 3]
		U_w^2 / as.numeric(I_eff)
	}
	gradient <- function(delta) {
		m <- null_fit(delta)
		U_w <- sum(f$w * (f$y - fitted(m)))
		abs(U_w * (bhat - delta))
	}
	list(bhat = bhat, se = se, lr = lr, score = score, gradient = gradient)
}

roots <- function(stat_fn, bhat, se, crit) {
	c(
		uniroot(function(d) stat_fn(d) - crit, c(bhat - 8 * se, bhat), tol = 1e-9)$root,
		uniroot(function(d) stat_fn(d) - crit, c(bhat, bhat + 8 * se), tol = 1e-9)$root
	)
}

test_that("likelihood-ratio inversion equals the profile-likelihood interval", {
	f <- logit_ci_fixture()
	ps <- profile_stats(f)
	for (alpha in c(0.05, 0.1)) {
		ref <- roots(ps$lr, ps$bhat, ps$se, qchisq(1 - alpha, 1))
		f$inf$set_testing_type("lik_ratio")
		ci <- f$inf$compute_asymp_confidence_interval(alpha = alpha)
		expect_equal(as.numeric(ci), ref, tolerance = 1e-3, info = as.character(alpha))
		expect_equal(names(ci), paste0(c(alpha / 2, 1 - alpha / 2) * 100, "%"))
	}
})

test_that("score inversion equals the interval where the classical score statistic hits its critical value", {
	f <- logit_ci_fixture()
	ps <- profile_stats(f)
	ref <- roots(ps$score, ps$bhat, ps$se, qchisq(0.95, 1))
	f$inf$set_testing_type("score")
	ci <- f$inf$compute_asymp_confidence_interval(alpha = 0.05)
	expect_equal(as.numeric(ci), ref, tolerance = 2e-3)
})

test_that("gradient inversion equals the interval where score * (bhat - delta) hits its critical value", {
	f <- logit_ci_fixture()
	ps <- profile_stats(f)
	ref <- roots(ps$gradient, ps$bhat, ps$se, qchisq(0.95, 1))
	f$inf$set_testing_type("gradient")
	ci <- f$inf$compute_asymp_confidence_interval(alpha = 0.05)
	expect_equal(as.numeric(ci), ref, tolerance = 2e-3)
})

test_that("all inverted intervals bracket the estimate, differ from Wald, and the test p-value at an endpoint equals alpha", {
	f <- logit_ci_fixture()
	ps <- profile_stats(f)
	f$inf$set_testing_type("wald")
	wald <- as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.05))
	f$inf$set_testing_type("lik_ratio")
	ci <- as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.05))
	expect_lt(ci[1], ps$bhat); expect_gt(ci[2], ps$bhat)
	expect_false(isTRUE(all.equal(ci, wald, tolerance = 1e-6)))
	for (e in ci) expect_equal(pchisq(ps$lr(e), 1, lower.tail = FALSE), 0.05, tolerance = 1e-3)
})

test_that("an unavailable test at the estimate caches a nonestimable SE and returns NA", {
	f <- logit_ci_fixture()
	f$inf$set_testing_type("score")
	unlockBinding("get_memoized_likelihood_test_pval", f$priv)
	f$priv$get_memoized_likelihood_test_pval <- function(...) NA_real_
	ci <- f$priv$invert_test_pval_confidence_interval(0.05, "score")
	expect_equal(ci, c(NA_real_, NA_real_))
	expect_true(f$inf$is_nonestimable("se"))
	expect_equal(f$inf$get_nonestimable_reason(), "score_test_unavailable")

	g <- logit_ci_fixture()
	unlockBinding("compute_estimate", g$inf)
	g$inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	expect_equal(g$priv$invert_test_pval_confidence_interval(0.05, "lik_ratio"), c(NA_real_, NA_real_))
	expect_false(g$inf$is_nonestimable("se"))
})
