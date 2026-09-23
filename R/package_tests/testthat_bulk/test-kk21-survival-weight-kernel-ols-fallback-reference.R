library(testthat)
library(EDI)

# kk21_survival_weights_cpp (kk21_weights.cpp) tries a per-covariate Weibull AFT t-statistic first
# (univariate_weibull_tstat()) and only falls back to an OLS-on-log(time) t-statistic when that
# returns a non-positive or non-finite value -- most simply, when fewer than 2 events are observed
# (n_events < 2 makes univariate_weibull_tstat() return -1.0 immediately, before any fitting). The
# existing reference test (test-kk21-weighted-crossprod.R, "KK21 survival weights match an R Weibull
# reference") always uses event = rbinom(n, 1, 0.8), which reliably yields many events and so only
# ever exercises the Weibull success path; the OLS fallback had no test reference anywhere.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("with fewer than 2 events, the kernel falls back to OLS on log(time), matching an independent lm() reference", {
	set.seed(5); n <- 20L
	x1 <- rnorm(n)
	x2 <- runif(n, -1, 1)
	X <- cbind(x1, x2)
	time <- rexp(n, 1)

	logy <- log(pmax(time, 1e-10))
	for (event in list(rep(0L, n), c(1L, rep(0L, n - 1L)))) {  # 0 events, then exactly 1 event
		got <- K("kk21_survival_weights_cpp")(X, time, event)
		for (j in 1:2) {
			ref_fit <- lm(logy ~ X[, j])
			ref_t <- abs(coef(summary(ref_fit))[2, 3])
			expect_equal(got[j], ref_t, tolerance = 1e-8, info = j)
		}
	}
})

test_that("the fallback's own degenerate sub-branch (constant column) still returns the eps weight", {
	set.seed(6); n <- 20L
	time <- rexp(n, 1)
	event <- rep(0L, n)  # forces the OLS fallback
	X <- cbind(constant = rep(1, n), real = rnorm(n))
	got <- K("kk21_survival_weights_cpp")(X, time, event)
	expect_equal(got[1], .Machine$double.eps)
	expect_true(is.finite(got[2]) && got[2] != .Machine$double.eps)
})
