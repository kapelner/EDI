library(testthat)
library(EDI)

# EDI:::weighted_cox_bootstrap_surrogate_fit(): weighted coxph on treatment + covariates, optional strata/cluster.
# Reference: survival::coxph with the same weights (and strata()/cluster()). Also pins row filtering (weight <= 0,
# non-finite time/dead, NA strata/cluster), the treatment column naming rules, the NULL returns and warm starts.

skip_if_not_installed("survival")
f <- EDI:::weighted_cox_bootstrap_surrogate_fit
set.seed(31); n <- 80L
trt <- rep(0:1, length.out = n); x1 <- rnorm(n)
time <- rexp(n, exp(0.5 * trt + 0.3 * x1)); dead <- rbinom(n, 1, 0.8)
X <- cbind(treatment = trt, x1 = x1)
wt <- rexp(n)
ref <- function(idx = rep(TRUE, n), extra = "") {
	d <- data.frame(time = time, dead = dead, treatment = trt, x1 = x1, wt = wt, s = rep(1:3, length.out = n), cl = rep(1:20, length.out = n))[idx, ]
	survival::coxph(stats::as.formula(paste("survival::Surv(time, dead) ~ treatment + x1", extra)), data = d, weights = wt)
}

test_that("plain fit equals weighted coxph and returns the fit object", {
	r <- f(time, dead, X, wt)
	m <- ref()
	expect_equal(r$beta_hat, unname(coef(m)["treatment"]), tolerance = 1e-7)
	expect_equal(r$coefficients, coef(m), tolerance = 1e-7)
	expect_s3_class(r$fit, "coxph")
})

test_that("non-positive weights and NA strata/cluster rows are removed before fitting", {
	w0 <- wt; w0[1:10] <- 0
	r <- f(time, dead, X, w0)
	d0 <- data.frame(time, dead, treatment = trt, x1 = x1, wt = w0)[w0 > 0, ]
	m0 <- survival::coxph(survival::Surv(time, dead) ~ treatment + x1, data = d0, weights = wt)
	expect_equal(r$beta_hat, unname(coef(m0)["treatment"]), tolerance = 1e-7)
	s <- rep(1:3, length.out = n); s[c(11, 12)] <- NA
	rs <- f(time, dead, X, w0, strata = s)
	keep <- w0 > 0 & !is.na(s)
	d <- data.frame(time, dead, treatment = trt, x1 = x1, wt = w0, s = s)[keep, ]
	m <- survival::coxph(survival::Surv(time, dead) ~ treatment + x1 + strata(s), data = d, weights = wt)
	expect_equal(rs$beta_hat, unname(coef(m)["treatment"]), tolerance = 1e-7)
	cl <- rep(1:20, length.out = n); cl[13] <- NA
	rc <- f(time, dead, X, w0, cluster = cl)
	keep2 <- w0 > 0 & !is.na(cl)
	expect_equal(nrow(rc$fit$y), sum(keep2))
	expect_true(!is.null(rc$fit$naive.var))                 # cluster() switches on the robust variance
})

test_that("cluster fit keeps the same point estimate as the unclustered fit but adds a robust variance", {
	cl <- rep(1:20, length.out = n)
	r0 <- f(time, dead, X, wt); rc <- f(time, dead, X, wt, cluster = cl)
	expect_equal(rc$beta_hat, r0$beta_hat, tolerance = 1e-7)
	expect_false(isTRUE(all.equal(unname(rc$fit$var), unname(r0$fit$var))))
})

test_that("column naming: first column becomes 'treatment' when absent, unnamed columns get x1..", {
	r <- f(time, dead, cbind(a = trt, b = x1), wt)
	expect_named(r$coefficients, c("treatment", "b"))
	r2 <- f(time, dead, unname(cbind(trt, x1)), wt)
	expect_named(r2$coefficients, c("treatment", "x2"))
	expect_equal(r2$beta_hat, r$beta_hat, tolerance = 1e-7)
})

test_that("warm start is accepted when its length matches and ignored otherwise", {
	base <- f(time, dead, X, wt)$beta_hat
	expect_equal(f(time, dead, X, wt, warm_start_beta = c(0.4, 0.2))$beta_hat, base, tolerance = 1e-6)
	expect_equal(f(time, dead, X, wt, warm_start_beta = c(0.4, NA))$beta_hat, base, tolerance = 1e-7)
	expect_equal(f(time, dead, X, wt, warm_start_beta = 1)$beta_hat, base, tolerance = 1e-7)
})

test_that("no usable rows gives NULL", {
	expect_null(f(time, dead, X, rep(0, n)))
	expect_null(f(time, dead, X, rep(NA_real_, n)))
	expect_null(f(replace(time, TRUE, NA_real_), dead, X, wt))
})

test_that("a degenerate design (no treatment variation) returns NULL rather than a non-finite beta", {
	expect_null(f(time, dead, cbind(treatment = rep(1, n), x1 = x1), wt))
})
