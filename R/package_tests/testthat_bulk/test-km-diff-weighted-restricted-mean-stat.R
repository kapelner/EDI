library(testthat)
library(EDI)

# InferenceSurvivalKMDiff's private weighted_survival_stat_for_group()/
# weighted_survival_stat_diff() accept requested_stat = c("median",
# "restricted_mean"), but the only public caller (compute_estimate_with_bootstrap_weights)
# always passes "median" -- the "restricted_mean" branch (a manual weighted
# KM-area-under-curve integral, lines ~303-322) has no caller anywhere in this
# class and no test reference in the suite (verified via grep). Reachable
# only via direct private access, matching this suite's established pattern.

make_km_diff_design = function(seed, n = 60L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rexp(n, rate = 0.5 * exp(0.3 * w))
	dead = rbinom(n, 1, 0.8)
	y_exact = ifelse(dead == 1, y, NA_real_)
	y_L = ifelse(dead == 1, NA_real_, y)
	y_R = ifelse(dead == 1, NA_real_, Inf)
	des$add_all_subject_responses(y_exact, y_L, y_R)
	list(des = des, w = w, y = y, dead = dead)
}

independent_weighted_rmst = function(y, dead, row_weights) {
	fit = survival::survfit(survival::Surv(y, dead) ~ 1, weights = row_weights)
	tau = max(y)
	# survival's own summary()-table rmean uses a distinct internal code path
	# (survival:::survmean) from the package's manual step-function integral.
	s = summary(fit, rmean = tau)
	unname(s$table[["rmean"]])
}

test_that("weighted_survival_stat_for_group's restricted_mean branch matches survival::survfit's own rmean", {
	setup = make_km_diff_design(seed = 5101L)
	inf = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	row_weights = runif(length(setup$y), 0.5, 2)
	got = priv$weighted_survival_stat_for_group(setup$y, setup$dead, row_weights, requested_stat = "restricted_mean")
	expected = independent_weighted_rmst(setup$y, setup$dead, row_weights)
	expect_equal(got, expected, tolerance = 1e-6)

	# Unit weights reproduce the unweighted rmean too.
	got_unit = priv$weighted_survival_stat_for_group(setup$y, setup$dead, rep(1, length(setup$y)), requested_stat = "restricted_mean")
	expected_unit = independent_weighted_rmst(setup$y, setup$dead, rep(1, length(setup$y)))
	expect_equal(got_unit, expected_unit, tolerance = 1e-6)

	# "restricted_mean" and "median" are genuinely different statistics on the same data.
	got_median = priv$weighted_survival_stat_for_group(setup$y, setup$dead, row_weights, requested_stat = "median")
	expect_false(isTRUE(all.equal(got, got_median)))
})

test_that("weighted_survival_stat_diff's restricted_mean branch is the between-arm difference of the independent per-arm rmeans", {
	setup = make_km_diff_design(seed = 5102L, n = 80L)
	inf = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	row_weights = runif(length(setup$y), 0.5, 2)
	got = priv$weighted_survival_stat_diff(row_weights, requested_stat = "restricted_mean")

	idx_t = setup$w == 1
	idx_c = setup$w == 0
	stat_t = independent_weighted_rmst(setup$y[idx_t], setup$dead[idx_t], row_weights[idx_t])
	stat_c = independent_weighted_rmst(setup$y[idx_c], setup$dead[idx_c], row_weights[idx_c])
	expect_equal(got, stat_t - stat_c, tolerance = 1e-6)
})

test_that("weighted_survival_stat_for_group's restricted_mean branch handles degenerate inputs", {
	setup = make_km_diff_design(seed = 5103L, n = 40L)
	inf = InferenceSurvivalKMDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	# All weights filtered out (non-positive) -> NA, not an error.
	expect_true(is.na(priv$weighted_survival_stat_for_group(setup$y, setup$dead, rep(0, length(setup$y)), requested_stat = "restricted_mean")))

	# A single finite observation still yields a finite rmean (fit succeeds trivially).
	got_one = priv$weighted_survival_stat_for_group(setup$y[1], setup$dead[1], 1, requested_stat = "restricted_mean")
	expect_true(is.finite(got_one))

	# Non-finite weight rows are silently dropped, matching the "median" branch's own filter.
	w_with_na = c(NA_real_, runif(length(setup$y) - 1L, 0.5, 2))
	got_filtered = priv$weighted_survival_stat_for_group(setup$y, setup$dead, w_with_na, requested_stat = "restricted_mean")
	keep = !is.na(w_with_na)
	expected_filtered = independent_weighted_rmst(setup$y[keep], setup$dead[keep], w_with_na[keep])
	expect_equal(got_filtered, expected_filtered, tolerance = 1e-6)
})
