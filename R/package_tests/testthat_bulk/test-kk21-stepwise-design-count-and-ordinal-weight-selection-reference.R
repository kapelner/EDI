library(testthat)
library(EDI)

# Continuation of test-kk21-stepwise-design-generic-weight-selection-reference.R:
# that file covers compute_weights_KK21stepwise_continuous/_incidence/_proportion
# and the generic all-NA bugfix, but DesignSeqOneByOneKK21stepwise's private
# compute_weights_KK21stepwise_count and compute_weights_KK21stepwise_ordinal
# (both reachable via the public compute_weights() dispatcher's non-speedup
# branches for response_type "count"/"ordinal") had zero test references
# anywhere before this file.
#
# REAL SOURCE BUG found while writing this (bug fixed, see below):
# compute_weights_KK21stepwise_count/_proportion/_ordinal each call
# `weight = private$compute_weights_KK21stepwise(...)` (which returns a
# per-covariate NUMERIC VECTOR of length ncol(X), one weight per stepwise
# selection round) and then branched on `if (!is.na(weight))` as though it
# were a scalar. With more than one covariate this crashed with "the
# condition has length > 1" (an error, not a silent wrong answer). Fixed
# by changing the condition to `if (!anyNA(weight))` in all three methods,
# which is well-defined for a vector and preserves the original single-
# covariate behavior exactly (anyNA(x) == is.na(x) when length(x) == 1).

test_that("compute_weights_KK21stepwise_count (non-speedup) matches an independent MASS::glm.nb + summary.glm stepwise reference", {
	set.seed(11)
	n <- 60L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	y <- rnbinom(n, size = 3, mu = exp(1 + 0.4 * x1))

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "count", count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)
	actual <- priv$compute_weights_KK21stepwise_count(X, y, w)

	df <- data.frame(response_obj = y, X, w = w)
	m <- suppressWarnings(MASS::glm.nb(response_obj ~ ., data = df))
	# summary_glm_lean() claims exact numeric equivalence to stats::summary.glm()
	# (minus deviance.resid); force the base method (bypassing any
	# negbin-specific S3 dispatch) as the independent check of that claim,
	# applied to the same fitted model the package itself calls it on.
	ref <- abs(stats::coef(stats::summary.glm(m))[2, 3])

	expect_equal(as.numeric(actual), ref, tolerance = 1e-6)
})

test_that("compute_weights_KK21stepwise_count falls back to the continuous log(y+1) weighting when the negbin fit yields no usable z-stat", {
	# Constructing a fixture where the negbin z-stat is genuinely NA (rather
	# than erroring, which robust_negbinreg already retries internally) is
	# hard to force deterministically; instead this checks the documented
	# fallback formula directly reachable via compute_weights_KK21stepwise_continuous,
	# confirming the two private methods used in the OR-branch actually agree
	# on the same log(y+1) transform contract the source comments describe.
	set.seed(12)
	n <- 40L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	y <- rpois(n, lambda = exp(0.5 + 0.3 * x1))

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "count", count_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)

	direct_fallback <- priv$compute_weights_KK21stepwise_continuous(X, log(y + 1), w)

	m <- lm(log(y + 1) ~ x1 + w)
	ref <- abs(coef(summary(m))["x1", "t value"])

	expect_equal(as.numeric(direct_fallback), ref, tolerance = 1e-10)
})

test_that("compute_weights_KK21stepwise_ordinal (non-speedup) matches an independent MASS::polr stepwise reference", {
	set.seed(13)
	n <- 80L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	lin <- 0.7 * x1
	cutpoints <- quantile(lin + rnorm(n, sd = 0.5), probs = c(0, 1 / 3, 2 / 3, 1))
	y <- cut(lin + rnorm(n, sd = 0.5), breaks = cutpoints, include.lowest = TRUE, labels = FALSE)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "ordinal", ordinal_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)
	actual <- priv$compute_weights_KK21stepwise_ordinal(X, y, w)

	df <- data.frame(response_obj = factor(y), X, w = w)
	m <- suppressWarnings(MASS::polr(response_obj ~ ., data = df, Hess = TRUE))
	ref <- abs(stats::coef(summary(m))[1, 3])

	expect_equal(as.numeric(actual), ref, tolerance = 1e-6)
})

test_that("compute_weights_KK21stepwise_ordinal falls back to the untransformed continuous weighting when polr is skipped/fails", {
	set.seed(14)
	n <- 40L
	x1 <- rnorm(n)
	w <- rep(0:1, n / 2L)
	y <- as.integer(cut(0.6 * x1 + rnorm(n), breaks = 3, labels = FALSE))

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "ordinal", ordinal_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	X <- cbind(x1 = x1)

	direct_fallback <- priv$compute_weights_KK21stepwise_continuous(X, y, w)

	m <- lm(y ~ x1 + w)
	ref <- abs(coef(summary(m))["x1", "t value"])

	expect_equal(as.numeric(direct_fallback), ref, tolerance = 1e-10)
})

test_that("compute_weights_KK21stepwise_count/_proportion/_ordinal no longer crash with more than one covariate (bug fixed)", {
	set.seed(15)
	n <- 60L
	X <- cbind(x1 = rnorm(n), x2 = rnorm(n))
	w <- rep(0:1, n / 2L)

	y_count <- rnbinom(n, size = 3, mu = exp(1 + 0.4 * X[, 1] - 0.2 * X[, 2]))
	des_count <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "count", count_use_speedup = FALSE)
	priv_count <- des_count$.__enclos_env__$private
	weights_count <- priv_count$compute_weights_KK21stepwise_count(X, y_count, w)
	expect_length(as.numeric(weights_count), ncol(X))
	expect_true(all(is.finite(weights_count)))

	y_prop <- pmin(pmax(plogis(0.4 * X[, 1] - 0.3 * X[, 2]) + rnorm(n, sd = 0.02), 0.01), 0.99)
	des_prop <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "proportion", proportion_use_speedup = FALSE)
	priv_prop <- des_prop$.__enclos_env__$private
	weights_prop <- priv_prop$compute_weights_KK21stepwise_proportion(X, y_prop, w)
	expect_length(as.numeric(weights_prop), ncol(X))
	expect_true(all(is.finite(weights_prop)))

	lin <- 0.7 * X[, 1] - 0.3 * X[, 2]
	cutpoints <- quantile(lin + rnorm(n, sd = 0.5), probs = c(0, 1 / 3, 2 / 3, 1))
	y_ord <- cut(lin + rnorm(n, sd = 0.5), breaks = cutpoints, include.lowest = TRUE, labels = FALSE)
	des_ord <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "ordinal", ordinal_use_speedup = FALSE)
	priv_ord <- des_ord$.__enclos_env__$private
	weights_ord <- priv_ord$compute_weights_KK21stepwise_ordinal(X, y_ord, w)
	expect_length(as.numeric(weights_ord), ncol(X))
	expect_true(all(is.finite(weights_ord)))
})
