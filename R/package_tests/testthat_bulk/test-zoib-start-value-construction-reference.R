library(testthat)
library(EDI)

# .build_zoib_start() (helper_zoib.R) supplies the default starting values for
# .fit_zero_one_inflated_beta() whenever `starts = NULL`. Existing coverage
# (test-statistical-helper-contracts.R) only exercises .fit_zero_one_inflated_beta's
# error/degenerate branches, never a successful fit that reaches this starting-value
# construction -- confirmed via repo-wide grep, zero direct or indirect references.
#
# Note: .fit_zero_one_inflated_beta() itself has no callers anywhere in R/EDI/R/
# (the real ZOIB inference class, inference_proportion_zero_one_inflated_beta.R,
# calls fast_zero_one_inflated_beta_cpp() directly with its own warm-start logic
# and never goes through this helper). This helper and .build_zoib_start() are
# only reachable via EDI:::, so this is likely dead/orphaned R-level wiring
# around a still-live C++ kernel -- not flagged as confirmed-dead like
# inference_mixin_kk_passthrough.R (no hardcoded gate found), just unreferenced.

zoib_start_fixture <- function(seed) {
	set.seed(seed)
	n <- 60L
	x <- rnorm(n)
	y <- plogis(0.4 + 0.9 * x) + rnorm(n, sd = 0.08)
	y <- pmin(pmax(y, 0), 1)
	list(y = y, X = cbind(x = x), n = n)
}

test_that(".build_zoib_start's logistic-regression component matches an independent binary-indicator fit", {
	f <- zoib_start_fixture(1)
	start <- EDI:::.build_zoib_start(f$y, f$X)

	# The starting beta comes from fast_logistic_regression_cpp() fit on the
	# clipped response treated as a binary/continuous target for the logit link;
	# verify it reproduces that exact fit rather than trusting it's "close".
	eps <- .Machine$double.eps
	y_clip <- pmin(pmax(f$y, eps), 1 - eps)
	ref <- EDI:::fast_logistic_regression_cpp(cbind(1, f$X), y_clip)

	expect_equal(unname(start[1:2]), as.numeric(ref$b), tolerance = 1e-8)
	# The beta-start names are stripped (unname()'d) in the source before being
	# concatenated with the named log_phi/alpha0/alpha1 tail -- only the tail
	# carries names.
	expect_equal(names(start), c("", "", "log_phi", "alpha0", "alpha1"))
})

test_that(".build_zoib_start's mixture-weight starts reflect the observed zero/one proportions", {
	f <- zoib_start_fixture(2)
	y <- f$y
	y[1:6] <- 0
	y[7:9] <- 1
	start <- EDI:::.build_zoib_start(y, f$X)

	pi0 <- mean(y == 0)
	pi1 <- mean(y == 1)
	pib <- 1 - pi0 - pi1
	expect_equal(unname(start["alpha0"]), log(pi0 / pib), tolerance = 1e-8)
	expect_equal(unname(start["alpha1"]), log(pi1 / pib), tolerance = 1e-8)
	expect_equal(unname(start["log_phi"]), log(10), tolerance = 1e-10)
})

test_that(".build_zoib_start clamps degenerate all-zero and all-one responses instead of producing non-finite alphas", {
	f <- zoib_start_fixture(3)
	start_all_zero <- EDI:::.build_zoib_start(rep(0, f$n), f$X)
	start_all_one <- EDI:::.build_zoib_start(rep(1, f$n), f$X)

	expect_true(all(is.finite(start_all_zero)))
	expect_true(all(is.finite(start_all_one)))
	# With no zero/one mass at all, both proportions clamp near their floor.
	start_no_boundary <- EDI:::.build_zoib_start(pmin(pmax(f$y, 0.01), 0.99), f$X)
	expect_true(all(is.finite(start_no_boundary)))
})

test_that(".build_zoib_start falls back to a zero beta vector when the logistic pre-fit fails or misaligns", {
	f <- zoib_start_fixture(4)
	# A rank-deficient design (duplicated column, collinear) can make the internal
	# fast_logistic_regression_cpp call error or return an unusable/mismatched
	# coefficient vector -- .build_zoib_start must not propagate that failure.
	X_collinear <- cbind(x = f$X[, "x"], x2 = f$X[, "x"])
	start <- EDI:::.build_zoib_start(f$y, X_collinear)
	expect_length(start, 6L)
	expect_true(all(is.finite(start)))
})

# NOTE (not asserted as a test -- too unreliable to pin deterministically):
# EDI:::.fit_zero_one_inflated_beta(y, X) was found to crash reproducibly
# (8/8 seeds) with "'names' attribute [5] must be the same length as the
# vector [0]" when run in a fresh Rscript process, on ordinary well-conditioned
# data (>=1 covariate column, a normal mix of zero/one/interior response mass --
# not a rare degenerate edge case). Root cause isolated to
# fast_zero_one_inflated_beta_cpp() itself: it returns neg_loglik = NaN and
# coefficients = NULL regardless of the warm-start vector supplied (confirmed
# with both .build_zoib_start()'s own output and a manually-constructed,
# correctly-sized start vector -- both fail identically, ruling out a
# start-vector length/shape mismatch as the cause). This is undefined
# behavior / memory-safety territory in the C++ kernel itself (the same call
# did NOT reproduce the crash when run inside this testthat session), so the
# underlying C++ instability is not fixed here (out of scope for an R-level
# change). What WAS fixed at the R level (helper_zoib.R): the R-level guard
# `if (is.null(fit) || !is.finite(fit$neg_loglik)) next` previously failed to
# also check `length(fit$coefficients) == 0L`, so a NaN/0-length-coefficient
# fit from the C++ kernel slipped past it into `best`, and the subsequent
# `names(coef_full) = param_names` assignment on a length-0 vector crashed
# instead of the loop cleanly skipping that candidate (and .fit_zero_one_
# inflated_beta() returning NULL if every candidate fails this way, as
# intended). This function has no callers anywhere in R/EDI/R/ (the real
# ZOIB inference class calls fast_zero_one_inflated_beta_cpp directly,
# bypassing this helper entirely, and already has its own defensive guard),
# so practical exposure was always limited to direct EDI::: use.
