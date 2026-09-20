library(testthat)
library(EDI)
library(survival)

# helper_survival_fits.R: .extract_survreg_start() (Weibull warm start), .extract_lognormal_start()
# and .fit_standard_weibull_aft_from_matrix() (treatment coefficient and variance), against
# survival::survreg references, plus their guard / fallback branches.

Z <- function(x) get(x, envir = asNamespace("EDI"))

surv_data <- function(seed = 3L, n = 120L) {
	set.seed(seed)
	w <- rbinom(n, 1, 0.5); x <- rnorm(n)
	t <- rweibull(n, shape = 1.5, scale = exp(1 + 0.4 * w + 0.3 * x)); cens <- rexp(n, 0.1)
	list(y = pmin(t, cens), d = as.integer(t <= cens), X = cbind(w = w, x = x), w = w, x = x)
}

test_that("Weibull start values equal the survreg coefficients and log scale, named with an intercept", {
	s <- surv_data()
	st <- Z(".extract_survreg_start")(s$y, s$d, s$X)
	ref <- survreg(Surv(s$y, s$d) ~ s$w + s$x, dist = "weibull")
	expect_equal(names(st$beta), c("(Intercept)", "w", "x"))
	expect_equal(unname(st$beta), unname(coef(ref)), tolerance = 1e-3)
	expect_equal(unname(st$log_sigma), log(ref$scale), tolerance = 1e-3)
})

test_that("lognormal start values equal survreg(dist = 'lognormal') and use the supplied event indicator", {
	s <- surv_data()
	st <- Z(".extract_lognormal_start")(s$y, s$d, s$X, s$d)
	ref <- survreg(Surv(s$y, s$d) ~ s$w + s$x, dist = "lognormal")
	expect_equal(names(st$beta), c("(Intercept)", "w", "x"))
	expect_equal(unname(st$beta), unname(coef(ref)), tolerance = 1e-4)
	expect_equal(unname(st$log_sigma), log(ref$scale), tolerance = 1e-4)
	# A different event indicator changes the fit (it is not silently replaced by `dead`).
	all_events <- Z(".extract_lognormal_start")(s$y, s$d, rep(1L, length(s$y)), X = s$X)
	expect_false(isTRUE(all.equal(unname(all_events$beta), unname(st$beta), tolerance = 1e-6)))
})

test_that("start extractors return zero starts when no model can be fit", {
	zero_w <- Z(".extract_survreg_start")(c(1, 2, 3), c(0L, 0L, 0L), cbind(w = c(0, 1, 0)))
	expect_equal(names(zero_w$beta), c("(Intercept)", "w"))
	expect_true(all(is.finite(zero_w$beta)))
	expect_true(is.finite(zero_w$log_sigma))
	ln <- Z(".extract_lognormal_start")(c(1, 2), c(0L, 0L), cbind(w = c(0, 1)), c(0L, 0L))
	expect_equal(unname(ln$beta), c(0, 0)); expect_equal(ln$log_sigma, 0)
})

test_that("standard Weibull AFT: treatment coefficient and its variance equal survreg's; estimate_only omits the variance", {
	s <- surv_data()
	a <- Z(".fit_standard_weibull_aft_from_matrix")(s$y, s$d, s$X)
	ref <- survreg(Surv(s$y, s$d) ~ s$w + s$x, dist = "weibull")
	V <- vcov(ref)
	expect_equal(a$beta, unname(coef(ref)[2]), tolerance = 1e-3)
	expect_equal(a$ssq, unname(V[2, 2]), tolerance = 5e-3)
	e <- Z(".fit_standard_weibull_aft_from_matrix")(s$y, s$d, s$X, estimate_only = TRUE)
	expect_equal(e$beta, a$beta, tolerance = 1e-4)
	expect_true(is.na(e$ssq))
	expect_gt(a$ssq, 0)
})

test_that("standard Weibull AFT: no observations, no events, or no treatment column give NULL", {
	s <- surv_data()
	f <- Z(".fit_standard_weibull_aft_from_matrix")
	expect_null(f(numeric(0), integer(0), s$X[0, ]))
	expect_null(f(s$y, rep(0L, length(s$y)), s$X))
	renamed <- s$X; colnames(renamed) <- c("trt", "x")                    # only a column named 'w' is the treatment
	expect_null(f(s$y, s$d, renamed))
})

test_that("standard Weibull AFT accepts a warm start without changing the answer", {
	s <- surv_data()
	f <- Z(".fit_standard_weibull_aft_from_matrix")
	base <- f(s$y, s$d, s$X)
	st <- Z(".extract_survreg_start")(s$y, s$d, s$X)
	warm <- f(s$y, s$d, s$X, starts = list(c(unname(st$beta), st$log_sigma)))
	expect_equal(warm$beta, base$beta, tolerance = 1e-4)
	expect_equal(warm$ssq, base$ssq, tolerance = 1e-3)
})
