library(testthat)
library(EDI)

# DesignSeqOneByOneKK21$compute_weight_KK21_survival() (design_seq_one_by_one_KK21.R) tries
# robust_survreg_with_surv_object() with each of "weibull", "lognormal" and "loglogistic" in turn
# and only falls back to compute_weight_KK21_continuous(xs_to_date, log(ys_to_date), ...) once
# every one of the three fails (NULL fit or a NaN summary table). The existing reference test
# (test-kk21-design-survival-ordinal-count-per-covariate-weight-reference.R) only exercises the
# weibull success path; the "all three distributions failed" fallback had no test reference
# anywhere.
#
# A single-row design makes robust_survreg_with_surv_object() return NULL for all three
# distributions (verified directly below), so the loop exhausts every dist without returning and
# falls through to the continuous-on-log(survival time) fallback, which itself has its own
# already-tested single-row degenerate branch returning .Machine$double.eps.

test_that("robust_survreg_with_surv_object returns NULL for every distribution on a single-row design", {
	fit <- survival::Surv(5, 1)
	for (dist in c("weibull", "lognormal", "loglogistic")) {
		expect_null(EDI:::robust_survreg_with_surv_object(fit, 1, dist = dist), info = dist)
	}
})

test_that("compute_weight_KK21_survival on a single-row design falls back to compute_weight_KK21_continuous's own degenerate branch", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "survival")
	priv <- des$.__enclos_env__$private

	x <- matrix(1, 1, 1); y <- 5; dd <- 1
	actual <- priv$compute_weight_KK21_survival(x, y, dd, 1L)
	expect_equal(actual, .Machine$double.eps)

	# independent reference: exactly what the fallback call computes directly
	ref <- priv$compute_weight_KK21_continuous(x, log(y), dd, 1L)
	expect_equal(actual, ref)
})

test_that("compute_weight_KK21_survival's fallback also fires for a different single-row event time", {
	des <- EDI:::DesignSeqOneByOneKK21$new(n = 6L, response_type = "survival")
	priv <- des$.__enclos_env__$private
	actual <- priv$compute_weight_KK21_survival(matrix(1, 1, 1), 12.5, 0, 1L)
	expect_equal(actual, .Machine$double.eps)
})
