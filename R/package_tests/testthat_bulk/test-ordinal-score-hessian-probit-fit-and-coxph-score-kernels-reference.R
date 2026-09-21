library(testthat)
library(EDI)

# Direct C++ kernels: get_ordinal_regression_score_cpp / _hessian_cpp (proportional-odds logit,
# params = [thresholds, coefficients]) against numDeriv of a hand-written log-likelihood;
# fast_ordinal_probit_regression_cpp() against MASS::polr(method = "probit"); and
# get_coxph_score_cpp / get_stratified_coxph_score_cpp (Breslow ties) against numDeriv of a
# hand-written (stratified) partial log-likelihood.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

ord_fixture <- function() {
	set.seed(5)
	n <- 150L
	X <- cbind(x1 = rnorm(n), x2 = rbinom(n, 1, 0.5))
	lat <- 0.6 * X[, 1] - 0.4 * X[, 2] + rlogis(n)
	list(X = X, y = as.integer(cut(lat, c(-Inf, -1, 0.3, 1.4, Inf))), n = n, ncat = 4L)
}
ll_ord <- function(p, dat, link = plogis) {
	a <- p[seq_len(dat$ncat - 1L)]
	b <- p[seq(dat$ncat, length.out = ncol(dat$X))]
	eta <- drop(dat$X %*% b)
	cdf <- cbind(0, vapply(a, function(t) link(t - eta), numeric(dat$n)), 1)
	sum(log(cdf[cbind(seq_len(dat$n), dat$y + 1L)] - cdf[cbind(seq_len(dat$n), dat$y)]))
}

test_that("ordinal logit score and Hessian equal numeric derivatives of the hand log-likelihood", {
	f <- ord_fixture()
	p0 <- c(-1, 0.3, 1.4, 0.5, -0.3)
	expect_equal(K("get_ordinal_regression_score_cpp")(f$X, f$y, p0), numDeriv::grad(ll_ord, p0, dat = f), tolerance = 1e-6)
	h <- K("get_ordinal_regression_hessian_cpp")(f$X, f$y, p0)
	expect_equal(unname(h), numDeriv::hessian(ll_ord, p0, dat = f), tolerance = 1e-4)
	expect_equal(unname(h), unname(t(h)))
	expect_true(all(eigen(h, symmetric = TRUE)$values < 0))                # concave at a sensible point
})

test_that("only the rank order of y matters for the ordinal score", {
	f <- ord_fixture()
	p0 <- c(-1, 0.3, 1.4, 0.5, -0.3)
	expect_equal(K("get_ordinal_regression_score_cpp")(f$X, f$y * 10 + 3, p0), K("get_ordinal_regression_score_cpp")(f$X, f$y, p0))
})

test_that("the probit fit equals polr(method = 'probit'): coefficients, thresholds, log-likelihood and covariance", {
	skip_if_not_installed("MASS")
	f <- ord_fixture()
	r <- K("fast_ordinal_probit_regression_cpp")(f$X, f$y)
	pr <- suppressWarnings(MASS::polr(factor(f$y) ~ f$X, method = "probit", Hess = TRUE))
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), unname(coef(pr)), tolerance = 1e-3)
	expect_equal(as.numeric(r$alpha), unname(pr$zeta), tolerance = 1e-3)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(pr)), tolerance = 1e-5)
	# polr's vcov lists the coefficients first; ours lists thresholds first, so compare the coefficient blocks.
	expect_equal(unname(r$vcov[4:5, 4:5]), unname(suppressMessages(vcov(pr))[1:2, 1:2]), tolerance = 5e-3)
	# The reported parameter vector is thresholds followed by coefficients.
	expect_equal(as.numeric(r$params), c(as.numeric(r$alpha), as.numeric(r$b)))
	# And its probit log-likelihood is the hand objective at those parameters.
	expect_equal(-ll_ord(as.numeric(r$params), f, link = pnorm), as.numeric(r$neg_loglik), tolerance = 1e-6)
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

test_that("Cox partial-likelihood score (Breslow ties) equals the numeric gradient, plain and stratified", {
	f <- cox_fixture()
	b0 <- c(0.3, -0.2)
	expect_equal(K("get_coxph_score_cpp")(f$X, f$t, f$d, b0), numDeriv::grad(pl_cox, b0, dat = f), tolerance = 1e-6)
	st <- rep(1:2, length.out = f$n)
	expect_equal(K("get_stratified_coxph_score_cpp")(f$X, f$t, f$d, st, b0), numDeriv::grad(pl_cox, b0, dat = f, strata = st), tolerance = 1e-6)
	# One stratum reproduces the unstratified score.
	expect_equal(K("get_stratified_coxph_score_cpp")(f$X, f$t, f$d, rep(1L, f$n), b0), K("get_coxph_score_cpp")(f$X, f$t, f$d, b0))
})

test_that("the Cox score vanishes at the partial-likelihood MLE from survival::coxph", {
	f <- cox_fixture()
	fit <- survival::coxph(survival::Surv(f$t, f$d) ~ f$X, ties = "breslow")
	expect_lt(max(abs(K("get_coxph_score_cpp")(f$X, f$t, f$d, unname(coef(fit))))), 1e-3)
})
