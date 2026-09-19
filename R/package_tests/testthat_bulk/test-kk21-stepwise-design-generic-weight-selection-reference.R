library(testthat)
library(EDI)

# DesignSeqOneByOneKK21stepwise's private compute_weights_KK21stepwise* family
# (helper for forward-stepwise covariate weighting) is only ever reached from
# the public compute_weights() dispatcher via a fallback branch for
# response_type values outside {continuous, incidence, count, proportion,
# survival, ordinal} -- every current response type instead calls a C++
# kk21_stepwise_*_weights_cpp() kernel directly. So this generic R-level
# machinery is unreachable via any public API call with today's response
# types, but it is real, directly-callable private logic (not gated dead code
# like inference_mixin_kk_passthrough.R), and had zero test references
# anywhere in the suite before this file. Exercised here via direct private
# access, matching the pattern already used elsewhere in this suite.

test_that("compute_weights_KK21stepwise_continuous matches an independent from-scratch stepwise lm() selection", {
	set.seed(1)
	n <- 40L
	X <- cbind(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	w <- rep(0:1, n / 2L)
	y <- 0.5 * X[, 1] - 0.3 * X[, 2] + rnorm(n)

	ref_stepwise <- function(X, y, w) {
		p <- ncol(X)
		weights <- rep(NA_real_, p)
		selected <- integer(0)
		remaining <- seq_len(p)
		while (length(remaining) > 0) {
			zs <- rep(NA_real_, p)
			for (j in remaining) {
				Xmat <- cbind(X[, j, drop = FALSE], X[, selected, drop = FALSE], w)
				m <- lm(y ~ Xmat)
				zs[j] <- abs(coef(summary(m))[2, 3])
			}
			j_max <- which.max(zs)
			weights[j_max] <- zs[j_max]
			selected <- c(selected, j_max)
			remaining <- setdiff(remaining, j_max)
		}
		weights
	}
	ref <- ref_stepwise(X, y, w)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "continuous")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weights_KK21stepwise_continuous(X, y, w)

	# Source returns a 1-d array() (a dim attribute); strip it since only the
	# values matter here, not that incidental array-vs-vector representation.
	expect_equal(as.numeric(actual), ref, tolerance = 1e-10)
})

test_that("compute_weights_KK21stepwise_incidence matches an independent from-scratch stepwise glm() selection", {
	set.seed(2)
	n <- 60L
	X <- cbind(x1 = rnorm(n), x2 = rnorm(n))
	w <- rep(0:1, n / 2L)
	y <- rbinom(n, 1, plogis(0.5 * X[, 1] - 0.3 * X[, 2]))

	ref_stepwise_logistic <- function(X, y, w) {
		p <- ncol(X)
		weights <- rep(NA_real_, p)
		selected <- integer(0)
		remaining <- seq_len(p)
		while (length(remaining) > 0) {
			zs <- rep(NA_real_, p)
			for (j in remaining) {
				Xmat <- cbind(X[, j, drop = FALSE], X[, selected, drop = FALSE], w)
				m <- suppressWarnings(glm(y ~ Xmat, family = "binomial"))
				zs[j] <- abs(coef(summary(m))[2, 3])
			}
			j_max <- which.max(zs)
			weights[j_max] <- zs[j_max]
			selected <- c(selected, j_max)
			remaining <- setdiff(remaining, j_max)
		}
		weights
	}
	ref <- ref_stepwise_logistic(X, y, w)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "incidence")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weights_KK21stepwise_incidence(X, y, w)

	# Loose tolerance: the package's internal fast_logistic_regression_with_var
	# IRLS solver and base R's glm() converge to slightly different fixed
	# points on the same data (both valid MLE solutions, different solver
	# tolerances) -- not a source-level discrepancy. Source returns a 1-d
	# array(); strip the incidental dim attribute before comparing.
	expect_equal(as.numeric(actual), ref, tolerance = 1e-3)
})

test_that("compute_weights_KK21stepwise's generic loop no longer crashes when every remaining candidate's statistic is NA in the same step (bug fixed)", {
	# Previously: when a SINGLE candidate's abs_z_compute_fun call returns NA,
	# the loop correctly skips it via which.max()'s NA-ignoring behavior and
	# the outer na0() wrapper (in compute_weights()) replaces any leftover NA
	# weights with 0. But if EVERY remaining candidate in a given step
	# returned NA, which.max() on an all-NA vector returned integer(0)
	# instead of NA_integer_, and the subsequent
	# `X_stepwise[, n_stepwise] <- X[, j_max]` assignment crashed with
	# "replacement has length zero". Fixed by breaking out of the stepwise
	# loop when every remaining candidate is NA, leaving the rest of
	# `weights` NA (which na0() then converts to 0), instead of crashing.
	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "continuous")
	priv <- des$.__enclos_env__$private
	X <- matrix(rnorm(20L * 2L), ncol = 2L)
	y <- rnorm(20L)
	w <- rep(0:1, 10L)

	weights <- priv$compute_weights_KK21stepwise(X, y, w, function(resp, covmat) NA_real_)
	expect_true(all(is.na(weights)))
	expect_length(weights, ncol(X))
})

test_that("compute_weights_KK21stepwise_proportion's non-speedup path matches an independent betareg() stepwise reference", {
	set.seed(3)
	n <- 50L
	X <- cbind(x1 = rnorm(n))
	w <- rep(0:1, n / 2L)
	y <- plogis(0.4 * X[, 1]) + rnorm(n, sd = 0.02)
	y <- pmin(pmax(y, 0.01), 0.99)

	des <- EDI:::DesignSeqOneByOneKK21stepwise$new(n = 6L, response_type = "proportion", proportion_use_speedup = FALSE)
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weights_KK21stepwise_proportion(X, y, w)

	# Independent reference via betareg::betareg (a separate beta-regression
	# implementation from the package's own internal fast_beta_regression_with_var).
	# With a single covariate, the stepwise loop has no other candidate to
	# choose between, so this reduces to one betareg fit's own coefficient z-stat.
	ref_mod <- betareg::betareg(y ~ w + X[, 1])
	ref <- abs(coef(summary(ref_mod))$mean["X[, 1]", "z value"])

	expect_equal(as.numeric(actual), ref, tolerance = 1e-3)
})
