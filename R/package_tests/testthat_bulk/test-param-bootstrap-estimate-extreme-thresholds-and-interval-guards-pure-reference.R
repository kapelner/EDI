library(testthat)
library(EDI)

# InferenceExtParamBootstrapEstimate pure predicates, evaluated against a fake `private` list so every threshold source
# can be controlled: param_bootstrap_estimate_threshold() (smallest positive finite candidate among the per-class
# thresholds, max_abs_reasonable_coef and EDI_SEPARATION_THRESHOLD), param_bootstrap_estimate_extreme() (any |theta| above
# the threshold, or a 95% replicate width above threshold * scale) and param_bootstrap_confidence_interval_extreme().

ns <- asNamespace("EDI")
ext <- get("InferenceExtParamBootstrapEstimate", ns)$private
SEP <- get("EDI_SEPARATION_THRESHOLD", ns)
bind <- function(name, priv = list()) {
	fn <- ext[[name]]
	env <- new.env(parent = ns)
	env$private <- c(priv, list(
		param_bootstrap_estimate_threshold = function() {
			g <- ext$param_bootstrap_estimate_threshold; environment(g) <- env; g()
		}))
	environment(fn) <- env
	fn
}
thr <- function(priv) bind("param_bootstrap_estimate_threshold", priv)()

test_that("threshold defaults to the separation constant when no per-class limit is set", {
	expect_identical(SEP, 1e6)
	expect_identical(thr(list()), SEP)
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = NULL, max_abs_reasonable_coef = NULL)), SEP)
})

test_that("threshold is the smallest positive finite candidate; invalid candidates are ignored", {
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = 50)), 50)
	expect_identical(thr(list(bootstrap_extreme_estimate_threshold = 30, max_abs_reasonable_coef = 80)), 30)
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = 200, bootstrap_extreme_estimate_threshold = 100, max_abs_reasonable_coef = 400)), 100)
	expect_identical(thr(list(max_abs_reasonable_coef = 1e9)), SEP)                     # larger than the constant: constant wins
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = -5, bootstrap_extreme_estimate_threshold = 0,
		max_abs_reasonable_coef = NA_real_)), SEP)
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = "abc", max_abs_reasonable_coef = 7)), 7)
	expect_identical(thr(list(param_bootstrap_extreme_estimate_threshold = Inf)), SEP)
})

test_that("estimate-extreme: absolute-size trigger, width trigger, and non-finite handling", {
	ex <- bind("param_bootstrap_estimate_extreme")
	expect_false(ex(numeric(0), max_abs = 10)); expect_false(ex(c(NA, NaN, Inf, -Inf), max_abs = 10))
	expect_false(ex(c(-2, 0, 2), max_abs = 10))
	expect_true(ex(c(1, 10.0001), max_abs = 10)); expect_true(ex(c(-11, 1), max_abs = 10))
	expect_false(ex(c(-10, 10), max_abs = 10))                                   # boundary: not strictly greater
	# width trigger: no single value above max_abs but the 95% spread exceeds max_abs * scale
	set.seed(1); wide <- c(rep(-9, 50), rep(9, 50))
	expect_true(ex(wide, est = 0, max_abs = 9 / 2))
	expect_false(ex(wide, est = 0, max_abs = 9))                                   # width 18 vs 9 * max(1, median|theta| = 9) = 81
	# scale_ref grows with |est| and the median magnitude, so the same width stops being extreme
	th <- seq(-3, 3, length.out = 101)
	expect_true(ex(th, est = 0, max_abs = 2.9))       # absolute size 3 > 2.9
	w95 <- diff(quantile(th, c(0.025, 0.975), names = FALSE, type = 8)); scale_ref <- max(1, 0, median(abs(th)))
	for (m in c(3.2, 3.5, 3.9, 4.5)) expect_identical(ex(th, est = 0, max_abs = m), any(abs(th) > m) || w95 > m * scale_ref, info = m)
	expect_true(ex(th, est = 0, max_abs = w95 / scale_ref - 0.01) )     # just under the width limit
	# invalid max_abs falls back to the separation constant
	expect_false(ex(c(1, 2, 3), max_abs = NA_real_)); expect_false(ex(c(1, 2, 3), max_abs = -1)); expect_true(ex(c(2e6, 1), max_abs = 0))
})

test_that("estimate-extreme default max_abs comes from the threshold method", {
	ex <- bind("param_bootstrap_estimate_extreme", list(max_abs_reasonable_coef = 5))
	expect_true(ex(c(1, 6))); expect_false(ex(c(1, 4)))
	ex2 <- bind("param_bootstrap_estimate_extreme")
	expect_true(ex2(c(1, 2e6))); expect_false(ex2(c(1, 5e5)))
})

test_that("interval-extreme: needs two finite bounds; flags a bound beyond max_abs or a width beyond max_abs * max(1, |est|)", {
	ci <- bind("param_bootstrap_confidence_interval_extreme")
	expect_false(ci(c(NA, 1), max_abs = 10)); expect_false(ci(1, max_abs = 10)); expect_false(ci(c(-Inf, 2), max_abs = 10))
	expect_false(ci(c(-2, 2), max_abs = 10))
	expect_true(ci(c(-11, 1), max_abs = 10)); expect_true(ci(c(0, 10.5), max_abs = 10))     # absolute-bound trigger
	expect_false(ci(c(-5, 5), max_abs = 10))                                                # |bounds| <= 10, width 10 = 10 * 1 (not strictly greater)
	expect_true(ci(c(-5.1, 5), max_abs = 10))                                               # width 10.1 > 10 * 1
	expect_true(ci(c(-8, 8), est = 0, max_abs = 9))                                         # bounds ok, width 16 > 9
	expect_false(ci(c(-8, 8), est = 0, max_abs = 16))                                       # width 16 = 16 * 1
})

test_that("interval-extreme scale uses |est| when larger than 1, but the absolute-bound rule is unaffected", {
	ci <- bind("param_bootstrap_confidence_interval_extreme")
	expect_true(ci(c(0, 6), est = 1, max_abs = 7 / 2))         # width 6 > 3.5 * 1  (bounds 6 > 3.5 as well)
	expect_true(ci(c(-3, 3), est = 1, max_abs = 5))            # bounds fine, width 6 > 5 * 1
	expect_false(ci(c(-3, 3), est = 5, max_abs = 5))           # width 6 < 5 * 5
	expect_false(ci(c(-3, 3), est = -5, max_abs = 5))
	expect_true(ci(c(-3, 6), est = 50, max_abs = 5))           # absolute bound 6 > 5 regardless of est
	expect_false(ci(c(-3, 3), est = 5, max_abs = NA))          # invalid max_abs -> separation constant
})
