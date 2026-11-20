library(testthat)
library(EDI)

# v1.0.6-TODO-286 (audit ids ds-custom-statistic-44358267779-f1, -f5, -f6):
# InferenceRandCustom's fast randomization path re-added the null shift to every
# draw additively (y + delta * w), although y_delta had delta removed on the
# transform_responses scale (log for count/survival, logit for proportion under
# the default "none" mapping of compute_rand_two_sided_pval()). Its nonzero-delta
# reference distributions matched no sharp null, and its survival randomization
# CI fed log times to the user's statistic. The fast path now re-applies delta
# with the base class's shift_randomization_responses(), and the survival CI
# inverts the class's own p-value (log shift of the raw times).
#
# A custom statistic that reproduces a built-in class's statistic must now give
# that class's draws, p-values and survival CI.

rand_custom_shift_fixture = function(response_type, seed = 5L, n = 60L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	d = DesignFixedBernoulli$new(n = n, response_type = response_type, verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	w = d$get_w()
	if (response_type == "survival") {
		et = rexp(n, exp(-0.7 * w))
		fu = runif(n, 0.5, 3)
		cz = et > fu
		d$add_all_subject_responses(ys = ifelse(cz, NA, et), y_Ls = ifelse(cz, fu, NA), y_Rs = ifelse(cz, Inf, NA))
	} else if (response_type == "count") {
		d$add_all_subject_responses(rpois(n, exp(1 + 0.5 * w)))
	} else if (response_type == "proportion") {
		d$add_all_subject_responses(plogis(rnorm(n, 0.5 * w)))
	} else {
		d$add_all_subject_responses(1 + X$x1 + w + rnorm(n))
	}
	list(des = d, x1 = X$x1)
}

# Statistics equal to the built-in classes' estimates (treatment coefficient with
# the x1 covariate), and the built-in class each one reproduces.
rand_custom_shift_cases = list(
	survival = list(
		builtin = function() InferenceSurvivalWeibullRegr,
		stat = function(x1) function(y, w, dead) unname(coef(survival::survreg(survival::Surv(y, dead) ~ w + x1, dist = "weibull"))[2]),
		transform = "log",
		tol = 1e-3
	),
	count = list(
		builtin = function() InferenceCountPoisson,
		stat = function(x1) function(y, w, dead) unname(coef(glm(y ~ w + x1, family = poisson))[2]),
		transform = "log",
		tol = 1e-6
	),
	proportion = list(
		builtin = function() InferencePropFractionalLogit,
		stat = function(x1) function(y, w, dead) unname(suppressWarnings(coef(glm(y ~ w + x1, family = quasibinomial)))[2]),
		transform = "logit",
		tol = 1e-6
	)
)

for (response_type in names(rand_custom_shift_cases)) local({
	rt = response_type
	case = rand_custom_shift_cases[[rt]]
	test_that(paste0("InferenceRandCustom nonzero-delta draws and p-values match the built-in class on ", rt), {
		if (rt == "survival") skip_if_not_installed("survival")
		fx = rand_custom_shift_fixture(rt)
		b = case$builtin()$new(fx$des)
		cu = InferenceRandCustom$new(fx$des, custom_randomization_statistic_function = case$stat(fx$x1))
		expect_equal(cu$compute_estimate(), b$compute_estimate(), tolerance = case$tol)
		b$set_seed(3)
		perms = b$.__enclos_env__$private$generate_permutations(20L)
		db = b$approximate_randomization_distribution_beta_hat_T(r = 20L, delta = 0.3,
			transform_responses = case$transform, permutations = perms, show_progress = FALSE)
		dc = cu$approximate_randomization_distribution_beta_hat_T(r = 20L, delta = 0.3,
			transform_responses = case$transform, permutations = perms, show_progress = FALSE)
		# Before the fix: max |difference| 0.14 (survival), 0.21 (count); proportion
		# draws left [0, 1] and the statistic errored.
		expect_equal(dc, db, tolerance = case$tol)
		# Default transform_responses = "none" resolves per response type.
		b$set_seed(1)
		cu$set_seed(1)
		expect_equal(
			cu$compute_rand_two_sided_pval(r = 49L, delta = 0.3, show_progress = FALSE),
			b$compute_rand_two_sided_pval(r = 49L, delta = 0.3, show_progress = FALSE)
		)
	})
})

test_that("InferenceRandCustom survival randomization CI matches the built-in Weibull class", {
	skip_if_not_installed("survival")
	fx = rand_custom_shift_fixture("survival")
	case = rand_custom_shift_cases$survival
	b = case$builtin()$new(fx$des)
	cu = InferenceRandCustom$new(fx$des, custom_randomization_statistic_function = case$stat(fx$x1))
	# The CI evaluates the statistic on raw times (it used to see log times, where
	# survreg fails on the negative values).
	seen_min = Inf
	cu_watch = InferenceRandCustom$new(fx$des, custom_randomization_statistic_function = function(y, w, dead) {
		seen_min <<- min(seen_min, y)
		mean(log(y[w == 1])) - mean(log(y[w == 0]))
	})
	cu_watch$set_seed(1)
	ci_watch = cu_watch$compute_rand_confidence_interval(r = 39L, show_progress = FALSE)
	expect_true(all(is.finite(ci_watch)))
	expect_gt(seen_min, 0)
	b$set_seed(1)
	cu$set_seed(1)
	ci_b = b$compute_rand_confidence_interval(r = 49L, pval_epsilon = 0.0005, show_progress = FALSE)
	ci_c = cu$compute_rand_confidence_interval(r = 49L, pval_epsilon = 0.0005, show_progress = FALSE)
	expect_true(all(is.finite(ci_c)))
	# The p-value is a step function of delta, so the two bisections can stop at
	# different points inside the same flat region.
	expect_equal(unname(ci_c), unname(ci_b), tolerance = 0.01)
})

test_that("InferenceRandCustom continuous \"none\" stays an additive shift", {
	fx = rand_custom_shift_fixture("continuous")
	md = function(y, w, dead) mean(y[w == 1]) - mean(y[w == 0])
	cu = InferenceRandCustom$new(fx$des, custom_randomization_statistic_function = md)
	priv = cu$.__enclos_env__$private
	cu$set_seed(2)
	perms = priv$generate_permutations(15L)
	y = priv$y
	w = priv$w
	expected = vapply(seq_len(ncol(perms$w_mat)), function(j) {
		wj = perms$w_mat[, j]
		md(y - 0.5 * w + 0.5 * wj, wj, NULL)
	}, numeric(1L))
	got = cu$approximate_randomization_distribution_beta_hat_T(r = 15L, delta = 0.5,
		transform_responses = "none", permutations = perms, show_progress = FALSE)
	expect_equal(got, expected, tolerance = 1e-12)
	# Pinned values from before the fix (same seed and r).
	cu$set_seed(1)
	expect_equal(cu$compute_rand_two_sided_pval(r = 99L, delta = 0.5, show_progress = FALSE), 2 / 99, tolerance = 1e-12)
})
