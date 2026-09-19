library(testthat)
library(EDI)

# Targeting the coverage_gap_registry.csv-flagged fallback/edge branches in
# inference_survival_strat_cox.R's free-function helpers: covariate-reduction
# fallback (w or a redundant covariate dropped for collinearity), and the
# formula-fit vs fast-fit divergence path -- previously only the primary
# happy-path informative-rows check (test-regression-rank-and-stratified-
# cox-contracts.R) and a shallow strata_info/reduce_covariates smoke check
# existed; none of the branches below were exercised.

test_that("cox_partial_likelihood_informative_rows also excludes an all-censored two-arm stratum", {
	# The existing repo test only covers single-arm exclusion (unique(w)<2)
	# and a kept mixed-censoring stratum; this adds the third branch: a
	# stratum with both arms present but zero events at all.
	w <- c(0, 1, 0, 1, 0, 1)
	y <- c(1, 2, 3, 4, 5, 6)
	dead <- c(1, 1, 0, 0, 1, 1)
	strata <- c(1L, 1L, 2L, 2L, 3L, 3L)
	keep <- EDI:::cox_partial_likelihood_informative_rows(strata, y, dead, w)
	expect_identical(keep, c(1L, 2L, 5L, 6L))
})

test_that("cox_partial_likelihood_reduce_covariates drops the treatment column itself when it's collinear with a covariate", {
	# w exactly proportional to the covariate -> the combined design is rank
	# deficient in a way that removes 'w' from the kept set -> the function's
	# own documented "w not in X_keep" branch returns an explicit 0-column matrix.
	X_covars <- cbind(x1 = c(1, 2, 3, 4, 5, 6))
	w_collinear <- 2 * c(1, 2, 3, 4, 5, 6)
	reduced <- EDI:::cox_partial_likelihood_reduce_covariates(w_collinear, y = 1:6, X_covars)
	expect_identical(dim(reduced), c(6L, 0L))
})

test_that("cox_partial_likelihood_reduce_covariates drops a redundant covariate but keeps w and the independent one", {
	x1 <- c(1, 2, 3, 4, 5, 6)
	x2 <- 2 * x1
	w <- c(0, 1, 0, 1, 0, 1)
	reduced <- EDI:::cox_partial_likelihood_reduce_covariates(w, y = 1:6, cbind(x1 = x1, x2 = x2))
	expect_identical(dim(reduced), c(6L, 1L))
	expect_identical(colnames(reduced), "x1")
	expect_equal(as.numeric(reduced[, "x1"]), x1)
})

test_that("cox_partial_likelihood_strata_info groups rows by distinct covariate patterns and falls back to one stratum with no covariates", {
	# Strata are formed from the full (a, b) covariate pattern jointly, not
	# column-by-column -- rows 1-2 share (a=1,b=0), rows 3-4 share (a=2,b=0),
	# rows 5-6 share (a=3,b=1); all three patterns are distinct.
	X_full <- cbind(a = c(1, 1, 2, 2, 3, 3), b = c(0, 0, 0, 0, 1, 1))
	info <- EDI:::cox_partial_likelihood_strata_info(X_full, nrow(X_full))
	expect_length(info$strata_id, 6L)
	expect_identical(info$strata_id[1], info$strata_id[2])
	expect_identical(info$strata_id[3], info$strata_id[4])
	expect_identical(info$strata_id[5], info$strata_id[6])
	expect_identical(length(unique(info$strata_id)), 3L)
	expect_identical(info$num_strata, 3L)

	# No-covariate fallback: everything is one stratum.
	empty_info <- EDI:::cox_partial_likelihood_strata_info(matrix(numeric(0), nrow = 6, ncol = 0), 6L)
	expect_identical(empty_info$strata_id, rep(1L, 6L))
	expect_identical(empty_info$num_strata, 1L)
})

test_that("fit_estimate_only_fast (breslow ties) agrees exactly with an independent breslow-tie coxph reference, and diverges from fit_with_formula's default efron ties under real tied event times", {
	set.seed(20260919)
	n <- 40L
	w <- rep(c(0, 1), n / 2)
	x1 <- rnorm(n)
	strat <- rep(1:2, each = n / 2)
	# Deliberately round to induce tied event times within strata.
	y <- round(rexp(n, rate = exp(0.5 * w + 0.3 * x1)) * 10) / 10
	y[y == 0] <- 0.01
	dead <- rep(1, n)
	expect_true(any(duplicated(y[strat == 1])) || any(duplicated(y[strat == 2])), "fixture must contain tied event times to test tie-handling divergence")

	dat <- data.frame(y = y, dead = dead, w = w, x1 = x1, strat = strat)
	fit_formula <- EDI:::cox_partial_likelihood_fit_with_formula(
		dat, "survival::Surv(y, dead) ~ w + x1 + survival::strata(strat)"
	)
	expect_true(!is.null(fit_formula))

	X <- cbind(w = w, x1 = x1)
	surv_y <- survival::Surv(y, dead)
	fit_fast <- EDI:::cox_partial_likelihood_fit_estimate_only_fast(X, surv_y, strata = strat)
	expect_true(fit_fast$converged)
	expect_true(all(is.finite(fit_fast$b)))

	# fit_estimate_only_fast forces ties="breslow" (per source); verify it
	# matches an independent breslow reference exactly.
	ref_breslow <- survival::coxph(
		survival::Surv(y, dead) ~ w + x1 + survival::strata(strat), data = dat, ties = "breslow"
	)
	expect_equal(unname(fit_fast$b), unname(coef(ref_breslow)), tolerance = 1e-6)

	# fit_with_formula uses survival::coxph's own default (efron) ties method
	# -- confirmed to genuinely diverge from the breslow fast-fit path under
	# real ties, not a floating-point-noise difference.
	expect_gt(max(abs(unname(coef(fit_formula)) - unname(fit_fast$b))), 1e-4)
	ref_efron <- survival::coxph(survival::Surv(y, dead) ~ w + x1 + survival::strata(strat), data = dat)
	expect_equal(unname(coef(fit_formula)), unname(coef(ref_efron)), tolerance = 1e-6)
})

test_that("fit_with_formula returns NULL on a formula it cannot fit rather than raising", {
	dat <- data.frame(y = c(1, 2), dead = c(1, 1), w = c(0, 1))
	res <- EDI:::cox_partial_likelihood_fit_with_formula(dat, "survival::Surv(y, dead) ~ not_a_column")
	expect_null(res)
})

test_that("fit_estimate_only_fast handles near-perfectly-separated data without crashing, returning either NULL or a finite coefficient", {
	# Perfect separation in a tiny 1-event stratum-free design tends to blow
	# up the partial-likelihood coefficient; the function's own contract
	# (per its `is.null(fit) || length(b) != ncol(X) || !all(is.finite(b))`
	# guard) is to return NULL rather than a non-finite/garbage estimate --
	# never to propagate an error.
	X <- cbind(w = c(0, 0, 0, 1, 1, 1))
	surv_y <- survival::Surv(c(1, 1, 1, 100, 100, 100), c(1, 1, 1, 1, 1, 1))
	res <- suppressWarnings(EDI:::cox_partial_likelihood_fit_estimate_only_fast(
		X, surv_y, coxph_control = survival::coxph.control(iter.max = 2L)
	))
	if (!is.null(res)) {
		expect_true(all(is.finite(res$b)))
	} else {
		expect_null(res)
	}
})
