library(testthat)
library(EDI)

# C++ kernels: get_negbin_regression_{score,hessian,expected_hessian}_cpp (params = coefficients,
# log theta) against numDeriv / the expected information (X' diag(mu theta / (mu + theta)) X and a
# truncated-sum expectation for the log-theta entry); get_coxph_hessian_cpp and
# get_stratified_coxph_hessian_cpp against numDeriv of a hand-written partial log-likelihood; and the
# small test-statistic helpers likelihood_ratio_test_from_negloglik_cpp,
# score_test_from_score_information_cpp (Schur-complement effective information) and
# gradient_test_from_restricted_score_cpp.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

nb_fixture <- function() {
	set.seed(3)
	n <- 100L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5))
	list(X = X, y = as.numeric(rnbinom(n, size = 3, mu = exp(X %*% c(0.3, 0.4, -0.2)))), n = n)
}
nb_ll <- function(p, dat) sum(dnbinom(dat$y, size = exp(p[4]), mu = exp(dat$X %*% p[1:3]), log = TRUE))

test_that("negative-binomial score and observed Hessian equal numeric derivatives", {
	f <- nb_fixture(); p0 <- c(0.2, 0.3, -0.1, log(2.5))
	expect_equal(K("get_negbin_regression_score_cpp")(f$X, f$y, p0), numDeriv::grad(nb_ll, p0, dat = f), tolerance = 1e-6)
	expect_equal(unname(K("get_negbin_regression_hessian_cpp")(f$X, f$y, p0)), numDeriv::hessian(nb_ll, p0, dat = f), tolerance = 1e-5)
})

test_that("the expected Hessian is minus the expected information: coefficient block in closed form, log-theta entry by summation", {
	f <- nb_fixture(); p0 <- c(0.2, 0.3, -0.1, log(2.5))
	h <- K("get_negbin_regression_expected_hessian_cpp")(f$X, f$y, p0)
	mu <- as.numeric(exp(f$X %*% p0[1:3])); th <- exp(p0[4])
	expect_equal(unname(h[1:3, 1:3]), crossprod(f$X * (mu * th / (mu + th)), f$X), tolerance = 1e-8)
	expect_equal(unname(h[4, 1:3]), rep(0, 3))                             # coefficients and dispersion are orthogonal in expectation
	# Expected information for log theta: -E[d^2 log f / d(log theta)^2], summed over subjects.
	info_lt <- sum(vapply(seq_len(f$n), function(i) {
		ys <- 0:400
		pr <- dnbinom(ys, size = th, mu = mu[i])
		d2 <- vapply(ys, function(yy) numDeriv::hessian(function(lt) dnbinom(yy, size = exp(lt), mu = mu[i], log = TRUE), p0[4]), 0)
		-sum(pr * d2)
	}, 0))
	expect_equal(unname(h[4, 4]), info_lt, tolerance = 1e-4)
	expect_true(all(eigen(h, symmetric = TRUE)$values > 0))
})

cox_fixture <- function() {
	set.seed(6)
	n <- 80L
	list(X = cbind(rnorm(n), rbinom(n, 1, 0.5)), t = round(rexp(n, 1) * 5) + 1, d = rbinom(n, 1, 0.7), n = n)
}
pl_cox <- function(b, dat, strata = NULL) {
	eta <- drop(dat$X %*% b); s <- 0
	for (i in which(dat$d == 1)) {
		risk <- dat$t >= dat$t[i]
		if (!is.null(strata)) risk <- risk & strata == strata[i]
		s <- s + eta[i] - log(sum(exp(eta[risk])))
	}
	s
}

test_that("Cox partial-likelihood Hessian (Breslow ties), plain and stratified, equals the numeric Hessian", {
	f <- cox_fixture(); b0 <- c(0.3, -0.2)
	expect_equal(unname(K("get_coxph_hessian_cpp")(f$X, f$t, f$d, b0)), numDeriv::hessian(pl_cox, b0, dat = f), tolerance = 1e-5)
	st <- rep(1:2, length.out = f$n)
	expect_equal(unname(K("get_stratified_coxph_hessian_cpp")(f$X, f$t, f$d, st, b0)), numDeriv::hessian(pl_cox, b0, dat = f, strata = st), tolerance = 1e-5)
	expect_equal(K("get_stratified_coxph_hessian_cpp")(f$X, f$t, f$d, rep(1L, f$n), b0), K("get_coxph_hessian_cpp")(f$X, f$t, f$d, b0))
})

test_that("likelihood-ratio helper: 2 * (null - unrestricted) referred to chi-square(df); negative differences clamp to zero", {
	r <- K("likelihood_ratio_test_from_negloglik_cpp")(100, 103.2, 1L)
	expect_equal(r$statistic, 6.4); expect_equal(r$df, 1L)
	expect_equal(r$p_value, pchisq(6.4, 1, lower.tail = FALSE), tolerance = 1e-10)
	r2 <- K("likelihood_ratio_test_from_negloglik_cpp")(100, 103.2, 2L)
	expect_equal(r2$p_value, pchisq(6.4, 2, lower.tail = FALSE), tolerance = 1e-10)
	r0 <- K("likelihood_ratio_test_from_negloglik_cpp")(100, 99.9, 1L)
	expect_equal(r0$statistic, 0); expect_equal(r0$p_value, 1)
})

test_that("score helper uses the Schur-complement effective information for the tested coefficient", {
	sc <- c(2.1, -0.5, 1.2)
	I <- matrix(c(10, 1, 2, 1, 8, 0.5, 2, 0.5, 6), 3, 3)
	eff <- I[2, 2] - I[2, -2] %*% solve(I[-2, -2]) %*% I[-2, 2]
	r <- K("score_test_from_score_information_cpp")(sc, I, 2L)
	expect_equal(r$information_effective, drop(eff), tolerance = 1e-10)
	expect_equal(r$score, -0.5)
	expect_equal(r$statistic, 0.25 / drop(eff), tolerance = 1e-10)
	expect_equal(r$p_value, pchisq(0.25 / drop(eff), 1, lower.tail = FALSE), tolerance = 1e-10)
})

test_that("gradient helper: score times the estimate gap, clamped at zero, on chi-square(1)", {
	r <- K("gradient_test_from_restricted_score_cpp")(c(2.1, -0.5, 1.2), 0.8, 0.1, 2L)
	expect_equal(r$estimate_gap, 0.7); expect_equal(r$score, -0.5)
	expect_equal(r$statistic, 0); expect_equal(r$p_value, 1)                 # -0.5 * 0.7 < 0
	r2 <- K("gradient_test_from_restricted_score_cpp")(c(2.1, 1.5, 1.2), 0.8, 0.1, 2L)
	expect_equal(r2$statistic, 1.5 * 0.7, tolerance = 1e-12)
	expect_equal(r2$p_value, pchisq(1.05, 1, lower.tail = FALSE), tolerance = 1e-10)
})
