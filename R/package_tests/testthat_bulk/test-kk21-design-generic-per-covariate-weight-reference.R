library(testthat)
library(EDI)

# DesignSeqOneByOneKK21's private compute_weight_KK21_* family (per-covariate
# association-statistic helpers) is only ever reached from the public
# compute_weights() dispatcher via a fallback loop for response_type values
# outside {continuous, incidence, count, proportion, survival, ordinal} --
# every current response type instead calls a C++ kk21_*_weights_cpp() kernel
# directly. So this R-level machinery is unreachable via any public API call
# with today's response types, but it is real, directly-callable private
# logic (not gated dead code), and had zero test references anywhere in the
# suite before this file. Same shape as DesignSeqOneByOneKK21stepwise's
# analogous compute_weights_KK21stepwise family, covered separately.

test_that("compute_weight_KK21_continuous matches an independent lm() t-statistic", {
	set.seed(1)
	n <- 30L
	X <- cbind(x1 = rnorm(n))
	y <- 0.6 * X[, 1] + rnorm(n)

	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "continuous")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_continuous(X, y, rep(1, n), 1L)

	ref_m <- lm(y ~ X[, 1])
	ref <- abs(coef(summary(ref_m))[2, 3])

	expect_equal(actual, ref, tolerance = 1e-10)
})

test_that("compute_weight_KK21_continuous returns .Machine$double.eps on a single-row (degenerate) design", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "continuous")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_continuous(matrix(1, 1, 1), 5, 1, 1L)
	expect_equal(actual, .Machine$double.eps)
})

test_that("compute_weight_KK21_incidence matches an independent glm() logistic t-statistic", {
	set.seed(2)
	n <- 50L
	X <- cbind(x1 = rnorm(n))
	y <- rbinom(n, 1, plogis(0.6 * X[, 1]))

	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "incidence")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_incidence(X, y, rep(1, n), 1L)

	ref_m <- suppressWarnings(glm(y ~ X[, 1], family = "binomial"))
	ref <- abs(coef(summary(ref_m))[2, 3])

	# Loose tolerance: internal fast_logistic_regression_with_var's IRLS solver
	# and base R's glm() converge to slightly different fixed points on the
	# same data (both valid MLE solutions) -- not a source-level discrepancy.
	expect_equal(actual, ref, tolerance = 1e-3)
})

test_that("compute_weight_KK21_count's non-speedup path is close to an independent MASS::glm.nb() reference", {
	set.seed(3)
	n <- 50L
	X <- cbind(x1 = rnorm(n))
	y <- rnbinom(n, size = 2, mu = exp(0.3 * X[, 1] + 1))

	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "count", count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_count(X, y, rep(1, n), 1L)

	ref_m <- suppressWarnings(MASS::glm.nb(y ~ x, data = data.frame(x = X[, 1], y = y)))
	ref <- abs(coef(summary(ref_m))[2, 3])

	# Wider tolerance: glm.nb's internal theta (dispersion) re-estimation and
	# the package's own summary_glm_lean() helper can land on very slightly
	# different theta/SE values run-to-run even on identical data; both are
	# legitimate MLE fits of the same model, not a source-level discrepancy.
	expect_equal(actual, ref, tolerance = 0.05)
})

test_that("compute_weight_KK21_proportion's beta-regression success path matches an independent betareg() reference", {
	set.seed(4)
	n <- 50L
	X <- cbind(x1 = rnorm(n))
	y <- plogis(0.5 * X[, 1]) + rnorm(n, sd = 0.03)
	y <- pmin(pmax(y, 0.01), 0.99)

	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "proportion")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_proportion(X, y, rep(1, n), 1L)

	ref_m <- betareg::betareg(y ~ X[, 1])
	ref <- abs(coef(summary(ref_m))$mean["X[, 1]", "z value"])

	# Loose tolerance: the package's internal fast_beta_regression_with_var
	# optimizer and betareg::betareg's own MLE solver converge to very
	# slightly different fixed points on the same data.
	expect_equal(actual, ref, tolerance = 5e-3)
})
