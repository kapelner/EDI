library(testthat)
library(EDI)

# Continuation of test-kk21-design-generic-per-covariate-weight-reference.R:
# DesignSeqOneByOneKK21's private compute_weight_KK21_survival, _ordinal and the
# count speedup/fallback path had no direct references. Each is checked against
# an independent from-scratch survreg / polr / lm t-statistic for every
# covariate column j.

kk21_private <- function(response_type, ...) {
	EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = response_type, ...)$.__enclos_env__$private
}

kk21_covariates <- function(n = 60L, seed = 5L) {
	set.seed(seed)
	cbind(a = rnorm(n), b = rnorm(n))
}

test_that("compute_weight_KK21_survival matches an independent weibull survreg |z| for each covariate", {
	x <- kk21_covariates()
	n <- nrow(x)
	set.seed(6)
	ys <- rexp(n, exp(0.4 * x[, 1]))
	ds <- rbinom(n, 1, 0.7)
	priv <- kk21_private("survival")
	for (j in 1:2) {
		ref <- abs(summary(survival::survreg(survival::Surv(ys, ds) ~ x[, j], dist = "weibull"))$table[2, 3])
		expect_equal(priv$compute_weight_KK21_survival(x, ys, ds, j), ref, tolerance = 1e-6, info = j)
	}
	# The two covariates give genuinely different weights (column selection works).
	expect_false(isTRUE(all.equal(
		priv$compute_weight_KK21_survival(x, ys, ds, 1), priv$compute_weight_KK21_survival(x, ys, ds, 2)
	)))
})

test_that("compute_weight_KK21_ordinal matches an independent MASS::polr |t| for each covariate", {
	x <- kk21_covariates()
	n <- nrow(x)
	set.seed(7)
	yo <- as.integer(cut(0.7 * x[, 1] + rnorm(n), breaks = c(-Inf, -0.5, 0.5, Inf), labels = FALSE))
	priv <- kk21_private("ordinal")
	for (j in 1:2) {
		m <- suppressWarnings(MASS::polr(factor(yo) ~ x[, j], Hess = TRUE))
		ref <- abs(coef(summary(m))[1, 3])
		expect_equal(priv$compute_weight_KK21_ordinal(x, yo, rep(1, n), j), ref, tolerance = 1e-6, info = j)
	}
})

test_that("compute_weight_KK21_ordinal on a constant response does not yield a finite weight (source quirk, not fixed)", {
	# With a single response level the polr summary has no usable z-statistic; the
	# method returns NaN rather than taking its OLS fallback. Pinned only as
	# "not a finite weight" so the exact NaN/fallback outcome is not over-fixed.
	x <- kk21_covariates()
	priv <- kk21_private("ordinal")
	w <- priv$compute_weight_KK21_ordinal(x, rep(2L, nrow(x)), rep(1, nrow(x)), 1)
	expect_length(w, 1L)
	expect_false(is.finite(w))
})

test_that("compute_weight_KK21_count's speedup path equals the OLS |t| on log(y + 1)", {
	x <- kk21_covariates()
	n <- nrow(x)
	set.seed(8)
	yc <- rpois(n, exp(0.3 * x[, 1] + 1))
	priv <- kk21_private("count", count_use_speedup = TRUE)
	for (j in 1:2) {
		ref <- abs(summary(lm(log(yc + 1) ~ x[, j]))$coefficients[2, 3])
		expect_equal(priv$compute_weight_KK21_count(x, yc, rep(1, n), j), ref, tolerance = 1e-8, info = j)
	}
})
