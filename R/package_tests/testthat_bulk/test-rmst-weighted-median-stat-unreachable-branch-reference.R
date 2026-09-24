library(testthat)
library(EDI)

# InferenceSurvivalRestrictedMeanDiff's private weighted_survival_stat_for_group()/
# weighted_survival_stat_diff() (inference_survival_rmst.R) accept requested_stat = c("median",
# "restricted_mean"), the SAME shape as InferenceSurvivalKMDiff's own copy of these two functions
# (test-km-diff-weighted-restricted-mean-stat.R) -- but each class's only public caller passes the
# OPPOSITE constant literal: KMDiff always passes "median", while RestrictedMeanDiff's compute_
# estimate_with_bootstrap_weights() always passes "restricted_mean" (inference_survival_rmst.R:122).
# The mirror-image gap of the already-closed KMDiff one: here it's this class's own "median" branch
# that has no caller anywhere and no test reference in the suite (confirmed via grep scoped to
# InferenceSurvivalRestrictedMeanDiff specifically -- a bare function-name grep for
# weighted_survival_stat_for_group/weighted_survival_stat_diff matches the KMDiff file too, which
# would incorrectly read as "already covered" without checking which CLASS owns the hit). Reachable
# only via direct private access.

make_rmst_design = function(seed, n = 60L){
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

independent_weighted_median = function(y, dead, row_weights) {
	fit = survival::survfit(survival::Surv(y, dead) ~ 1, weights = row_weights)
	q = stats::quantile(fit, probs = 0.5)
	unname(as.numeric(q$quantile))
}

test_that("weighted_survival_stat_for_group's median branch matches an independent weighted survfit() quantile", {
	setup = make_rmst_design(seed = 6101L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	row_weights = runif(length(setup$y), 0.5, 2)
	got = priv$weighted_survival_stat_for_group(setup$y, setup$dead, row_weights, requested_stat = "median")
	expected = independent_weighted_median(setup$y, setup$dead, row_weights)
	expect_equal(got, expected, tolerance = 1e-6)

	# "median" and "restricted_mean" are genuinely different statistics on the same data.
	got_rmean = priv$weighted_survival_stat_for_group(setup$y, setup$dead, row_weights, requested_stat = "restricted_mean")
	expect_false(isTRUE(all.equal(got, got_rmean)))
})

test_that("weighted_survival_stat_diff's median branch is the between-arm difference of the independent per-arm medians", {
	setup = make_rmst_design(seed = 6102L, n = 80L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	row_weights = runif(length(setup$y), 0.5, 2)
	got = priv$weighted_survival_stat_diff(row_weights, requested_stat = "median")

	idx_t = setup$w == 1
	idx_c = setup$w == 0
	stat_t = independent_weighted_median(setup$y[idx_t], setup$dead[idx_t], row_weights[idx_t])
	stat_c = independent_weighted_median(setup$y[idx_c], setup$dead[idx_c], row_weights[idx_c])
	expect_equal(got, stat_t - stat_c, tolerance = 1e-6)
})

test_that("weighted_survival_stat_diff returns NA when one arm has no positive weight, matching the shared no-caller guard", {
	setup = make_rmst_design(seed = 6103L, n = 40L)
	inf = InferenceSurvivalRestrictedMeanDiff$new(setup$des, verbose = FALSE)
	priv = inf$.__enclos_env__$private

	row_weights = ifelse(setup$w == 1, 0, 1)
	expect_true(is.na(priv$weighted_survival_stat_diff(row_weights, requested_stat = "median")))
})
