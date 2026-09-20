library(testthat)
library(EDI)

# The bootstrap-randomization (BRT) CI machinery's private search pieces:
# closed_form_ci_from_affine_null_draws() (exact inversion when every null draw is
# affine in delta), expand_rand_bootstrap_bound(), invert_rand_bootstrap_test_
# bisection() (incl. its conservative-bound branch), the deadline check and the
# transform-code map. Only the affine-coefficient builder had direct tests. The
# closed form is checked against a brute-force scan of the p-value it inverts.

brt_priv <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.5))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

brute_pval <- function(A, cs, t_obs, d) {
	t0 <- A + d * cs
	B <- length(A)
	min(1, max(2 / B, 2 * min(sum(t0 >= t_obs), sum(t0 <= t_obs)) / B))
}

test_that("the closed-form interval is exactly the region where the Monte Carlo p-value stays at or above alpha / 2", {
	f <- brt_priv()
	for (seed in c(1L, 2L, 3L)) {
		set.seed(seed)
		B <- 400L
		A <- rnorm(B); cs <- runif(B, 0.5, 1.5)
		t_obs <- 0.3; alpha <- 0.1
		ci <- f$priv$closed_form_ci_from_affine_null_draws(A, cs, t_obs, alpha)
		expect_length(ci, 2L)
		expect_lt(ci[1], ci[2])
		th <- alpha / 2
		# Closed endpoints are accepted; points just outside are rejected.
		# (Nudged inward by 1e-9 so floating-point rounding at an exact breakpoint cannot
		# flip a tail count.)
		expect_gte(brute_pval(A, cs, t_obs, ci[1] + 1e-9), th)
		expect_gte(brute_pval(A, cs, t_obs, ci[2] - 1e-9), th)
		expect_lt(brute_pval(A, cs, t_obs, ci[1] - 1e-6), th)
		expect_lt(brute_pval(A, cs, t_obs, ci[2] + 1e-6), th)
		# Every grid point strictly inside is accepted at some level, and the accepted
		# grid range matches the interval.
		grid <- seq(ci[1] - 2, ci[2] + 2, length.out = 4001)
		acc <- vapply(grid, function(d) brute_pval(A, cs, t_obs, d) >= th, logical(1))
		expect_equal(range(grid[acc]), ci, tolerance = 0.01)
		expect_true(all(acc[grid > ci[1] + 1e-3 & grid < ci[2] - 1e-3]))
		expect_true(!any(acc[grid < ci[1] - 1e-3 | grid > ci[2] + 1e-3]))
	}
})

test_that("draws with a vanishing slope contribute constant tail counts, non-finite draws are dropped", {
	f <- brt_priv()
	set.seed(4)
	B <- 400L
	A <- rnorm(B); cs <- runif(B, 0.5, 1.5)
	cs[1:5] <- 0                                    # slope-free draws
	A_bad <- c(A, NA, Inf); c_bad <- c(cs, 1, 1)    # non-finite ones are ignored
	ci1 <- f$priv$closed_form_ci_from_affine_null_draws(A, cs, 0.3, 0.1)
	ci2 <- f$priv$closed_form_ci_from_affine_null_draws(A_bad, c_bad, 0.3, 0.1)
	expect_equal(ci1, ci2)
	th <- 0.05
	expect_gte(brute_pval(A, cs, 0.3, ci1[1] + 1e-9), th)
	expect_lt(brute_pval(A, cs, 0.3, ci1[1] - 1e-6), th)
	expect_lt(brute_pval(A, cs, 0.3, ci1[2] + 1e-6), th)
	expect_gte(brute_pval(A, cs, 0.3, ci1[2] - 1e-9), th)
	# When the slope-free draws alone keep both tails at or above the threshold, acceptance is unbounded -> NULL.
	cs40 <- cs; cs40[1:40] <- 0
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(A, cs40, 0.3, 0.1))
})

test_that("the closed form declines (NULL) when the p-value floor is too high, breakpoints degenerate, or acceptance is unbounded", {
	f <- brt_priv()
	set.seed(5)
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(rnorm(30), runif(30, 0.5, 1.5), 0.3, 0.1))    # 2/B >= alpha/2
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(numeric(0), numeric(0), 0.3, 0.1))
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(rnorm(400), rep(0, 400), 0.3, 0.1))          # every slope ~ 0
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(rnorm(400), rep(1, 400) * c(1, rep(0, 399)), 0.3, 0.1))   # a single breakpoint
	# Identical draws all flip at one breakpoint -> fewer than two distinct breakpoints.
	expect_null(f$priv$closed_form_ci_from_affine_null_draws(rep(0, 400), rep(1, 400), 0.3, 0.1))
})

test_that("bound expansion returns an already-rejecting bound, doubles the step otherwise, and falls back conservatively", {
	f <- brt_priv()
	expand <- function(bound, lower, evaluate_pval, max_radius = 8, max_expansions = 6L) {
		f$priv$expand_rand_bootstrap_bound(bound, est = 0, target_pval = 0.05, lower = lower,
			max_radius = max_radius, max_expansions = max_expansions, evaluate_pval = evaluate_pval)
	}
	pv <- function(d) 2 * pnorm(-abs(d) / 1)                   # rejects (p < 0.05) beyond |d| > 1.96
	expect_equal(expand(3, FALSE, pv), 3)                      # already beyond the rejection region
	expect_equal(expand(-3, TRUE, pv), -3)
	expect_equal(expand(20, FALSE, pv), 8)                     # clipped to est + max_radius (still rejecting)
	expect_equal(expand(-20, TRUE, pv), -8)
	# Bound inside the acceptance region: step doubles from |est - bound| until it rejects.
	expect_equal(expand(0.5, FALSE, pv), 2)                    # 0.5 -> 1 -> 2 (p(2) < 0.05)
	expect_equal(expand(-0.5, TRUE, pv), -2)
	# Never rejects: conservative fallback to the search boundary.
	expect_equal(expand(1, FALSE, function(d) 0.9), 8)
	expect_equal(expand(-1, TRUE, function(d) 0.9), -8)
	# Unusable inputs.
	expect_true(is.na(expand(NA_real_, FALSE, pv)))
	expect_true(is.na(f$priv$expand_rand_bootstrap_bound(1, est = NA_real_, 0.05, FALSE, 8, 3L, pv)))
	expect_true(is.na(expand(1, FALSE, pv, max_radius = 0)))
})

test_that("bisection converges to the bound where a smooth p-value crosses the threshold", {
	f <- brt_priv()
	pv <- function(d) 2 * pnorm(-abs(d))                        # p = 0.05 at |d| = qnorm(0.975)
	target <- qnorm(0.975)
	upper <- f$priv$invert_rand_bootstrap_test_bisection(0, 6, pval_th = 0.05, tol = 1e-6, lower = FALSE,
		show_progress = FALSE, evaluate_pval = pv)
	expect_equal(upper, target, tolerance = 1e-3)
	lower <- f$priv$invert_rand_bootstrap_test_bisection(-6, 0, pval_th = 0.05, tol = 1e-6, lower = TRUE,
		show_progress = FALSE, evaluate_pval = pv)
	expect_equal(lower, -target, tolerance = 1e-3)
	# Non-finite p-values at the ends are re-probed by halving.
	flaky <- function(d) if (d > 5.5) NA_real_ else pv(d)
	expect_equal(f$priv$invert_rand_bootstrap_test_bisection(0, 6, 0.05, 1e-6, FALSE, FALSE, flaky), target, tolerance = 1e-3)
	# Never available -> NA.
	expect_true(is.na(f$priv$invert_rand_bootstrap_test_bisection(0, 6, 0.05, 1e-6, FALSE, FALSE, function(d) NA_real_)))
})

test_that("a still-accepted search boundary is returned as a conservative bound with a message", {
	f <- brt_priv()
	flat <- function(d) 0.5
	expect_message(up <- f$priv$invert_rand_bootstrap_test_bisection(0, 6, 0.05, 1e-6, FALSE, FALSE, flat),
		"upper bound is conservative")
	expect_equal(up, 6)
	expect_message(lo <- f$priv$invert_rand_bootstrap_test_bisection(-6, 0, 0.05, 1e-6, TRUE, FALSE, flat),
		"lower bound is conservative")
	expect_equal(lo, -6)
})

test_that("each conservative-bound return increments the package's conservative counter", {
	f <- brt_priv()
	suppressMessages(f$priv$invert_rand_bootstrap_test_bisection(0, 6, 0.05, 1e-6, FALSE, FALSE, function(d) 0.5))
	expect_equal(f$priv$rand_bootstrap_ci_conservative_count, 1L)
	suppressMessages(f$priv$invert_rand_bootstrap_test_bisection(-6, 0, 0.05, 1e-6, TRUE, FALSE, function(d) 0.5))
	expect_equal(f$priv$rand_bootstrap_ci_conservative_count, 2L)
	# A properly bracketed search does not count.
	f$priv$invert_rand_bootstrap_test_bisection(0, 6, 0.05, 1e-6, FALSE, FALSE, function(d) 2 * pnorm(-abs(d)))
	expect_equal(f$priv$rand_bootstrap_ci_conservative_count, 2L)
})

test_that("the BRT CI deadline check and transform-code map behave as documented", {
	f <- brt_priv()
	withr::local_options(list(EDI.ci_timeout_deadline = NULL))
	expect_true(is.na(f$priv$rand_bootstrap_ci_timeout_deadline()))
	expect_false(f$priv$check_rand_bootstrap_ci_deadline())
	now <- unname(proc.time()[["elapsed"]])
	expect_false(f$priv$check_rand_bootstrap_ci_deadline(now + 1000))
	expect_error(f$priv$check_rand_bootstrap_ci_deadline(now - 1, "My BRT step"), "My BRT step reached elapsed time limit")
	withr::local_options(list(EDI.ci_timeout_deadline = now - 1))
	expect_equal(f$priv$rand_bootstrap_ci_timeout_deadline(), now - 1)
	expect_error(f$priv$check_rand_bootstrap_ci_deadline(), "Bootstrap randomization CI bisection reached elapsed time limit")
	withr::local_options(list(EDI.ci_timeout_deadline = "junk"))
	expect_false(f$priv$check_rand_bootstrap_ci_deadline())

	tc <- f$priv$rand_bootstrap_transform_code
	expect_equal(tc("none"), 0L)
	expect_equal(tc("log"), 1L)
	expect_equal(tc("logit"), 2L)
	expect_null(tc("sqrt"))
})
