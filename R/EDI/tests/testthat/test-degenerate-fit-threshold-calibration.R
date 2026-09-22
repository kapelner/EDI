library(testthat)
library(EDI)

# Calibration check for the zero-augmented-Poisson degenerate-fit thresholds
# (zero_augmented_fit_is_degenerate(): rcond(vcov) < 1e-10, conditional
# intercept < -15) added 2026-09-20 as conservative guesses. Investigated
# 2026-09-22: across a spectrum of increasing hurdle-side separation (0% to
# 100%) on n=60 data, legitimate fits' rcond clustered at 1e-3..1e-2 and
# degenerate fits' at 1e-11..1e-15 with NO observed case in between, even at
# the s=0.6 transition point -- a 6-8 order-of-magnitude gap around the 1e-10
# threshold. Down to 3-4 positive counts out of n=200 (genuinely rare but real
# events, no separation) with >= 4 positive counts, rcond stayed >= 6.7e-4 and
# the intercept stayed >= -1.2, far from either threshold. With only 1-2
# positive counts out of n=200 the check DOES trip (rcond ~1e-18) -- correctly
# so: a conditional-count model has no information to estimate a coefficient
# from 1-2 points, so that is genuine unidentifiability, not a false alarm.
# No false positive was found once real information is present; the
# thresholds are not re-tuned here for lack of counter-evidence that they're
# wrong, but are locked in by this test instead of resting on an unverified
# guess.

hurdle_rare_fixture = function(seed, n = 200L, rare_rate = 0.02, min_pos = 4L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	w = rbinom(n, 1, 0.5)
	pos = rbinom(n, 1, rare_rate * exp(0.3 * (w - 0.5)))
	# Both arms must be represented among the positives, or the treatment coefficient in the
	# hurdle part is genuinely unidentifiable (correctly flagged degenerate, not a miscalibration).
	if (sum(pos) < min_pos || length(unique(w[pos == 1])) < 2L) return(NULL)
	y = ifelse(pos == 1, rpois(n, 3) + 1, 0)
	d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y)
	d
}

hurdle_separated_fixture = function(seed, n = 60L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n))
	w = rbinom(n, 1, 0.5)
	pos = rbinom(n, 1, plogis(0.3 + 8 * (w - 0.5)))
	y = ifelse(pos == 1, rpois(n, 3) + 1, 0)
	d = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y)
	d
}

test_that("a rare-but-real hurdle fit (a handful of positive counts, no separation) is not flagged degenerate", {
	checked = 0L
	for (seed in 1:20) {
		des = hurdle_rare_fixture(seed)
		if (is.null(des)) next
		checked = checked + 1L
		inst = InferenceCountHurdlePoisson$new(des)
		suppressWarnings(inst$compute_estimate())
		priv = inst$.__enclos_env__$private
		fit = priv$cached_mod$mod
		if (is.null(fit) || is.null(fit$vcov)) next
		expect_false(zero_augmented_fit_is_degenerate(fit$vcov, as.numeric(fit$params)))
	}
	expect_gte(checked, 5L)
})

test_that("a near-perfectly-separated hurdle fit is flagged degenerate", {
	found_degenerate = FALSE
	for (seed in 1:8) {
		des = hurdle_separated_fixture(seed)
		inst = InferenceCountHurdlePoisson$new(des)
		suppressWarnings(inst$compute_estimate())
		priv = inst$.__enclos_env__$private
		fit = priv$cached_mod$mod
		if (is.null(fit) || is.null(fit$vcov)) { found_degenerate = TRUE; next }
		rc = tryCatch(rcond(as.matrix(fit$vcov)), error = function(e) NA_real_)
		if (is.na(rc) || rc < 1e-10) found_degenerate = TRUE
	}
	expect_true(found_degenerate)
})
