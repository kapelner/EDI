library(testthat)
library(EDI)

# Randomization-CI search plumbing (InferenceRandCI): normalize_randomization_ci_
# search_control() defaults / overrides / validation, check_randomization_ci_
# deadline(), assert_no_incidence_only_randomization_args(),
# compute_randomization_ci_pval_cached() (memoization + failure handling),
# get_randomization_ci_seed_candidates() and build_randomization_ci_search_bounds().
# None had a direct test reference. Reference values are the documented defaults
# and the class's own Wald / asymptotic intervals.

ci_priv <- function(n = 20L, seed = 123L) {
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

test_that("search-control defaults follow r and the p-value epsilon", {
	f <- ci_priv()
	ctrl <- f$priv$normalize_randomization_ci_search_control(NULL, r = 501, pval_epsilon = 0.005)
	expect_equal(ctrl$fallback, "fallback")
	expect_equal(ctrl$seed, "asymp_then_boot")
	expect_equal(ctrl$max_radius_se_mult, 25)
	expect_equal(ctrl$max_radius_scale_mult, 6)
	expect_equal(ctrl$max_expansions, 7L)
	expect_equal(ctrl$seed_boot_B, max(51L, min(501L, 201L)))
	expect_true(ctrl$pval_cache_enable)
	expect_equal(ctrl$pval_cache_resolution, 0.005)
	expect_true(ctrl$mc_enable)                                   # r >= 200
	default_batch <- min(501L, max(25L, as.integer(ceiling(2 * sqrt(501L)))))
	expect_equal(ctrl$mc_batch_size, default_batch)
	expect_equal(ctrl$mc_min_draws, min(501L, max(100L, 2L * default_batch)))
	expect_equal(ctrl$mc_conf_level, 0.99)
	expect_true(ctrl$high_precision_confirm)

	small <- f$priv$normalize_randomization_ci_search_control(NULL, r = 100, pval_epsilon = 0.01)
	expect_false(small$mc_enable)                                 # r < 200
	expect_equal(small$mc_batch_size, 25L)
	expect_equal(small$mc_min_draws, 100L)
	expect_equal(small$seed_boot_B, 100L)
})

test_that("user overrides win, and invalid choices / numbers are rejected", {
	f <- ci_priv()
	ctrl <- f$priv$normalize_randomization_ci_search_control(
		list(seed = "none", mc_enable = FALSE, max_expansions = 3L, pval_cache_resolution = 0.02), r = 501, pval_epsilon = 0.005)
	expect_equal(ctrl$seed, "none")
	expect_false(ctrl$mc_enable)
	expect_equal(ctrl$max_expansions, 3L)
	expect_equal(ctrl$pval_cache_resolution, 0.02)
	expect_equal(ctrl$fallback, "fallback")                        # untouched default survives

	bad <- function(...) f$priv$normalize_randomization_ci_search_control(list(...), r = 501, pval_epsilon = 0.005)
	expect_error(bad(fallback = "x"), "fallback")
	expect_error(bad(seed = "sometimes"), "seed")
	expect_error(bad(max_radius_se_mult = -1))
	expect_error(bad(max_radius_scale_mult = Inf))
	expect_error(bad(max_expansions = 0L))
	expect_error(bad(pval_cache_enable = "yes"))
	expect_error(bad(pval_cache_resolution = 0))
	expect_error(f$priv$normalize_randomization_ci_search_control("notalist", r = 501, pval_epsilon = 0.005))
})

test_that("the CI deadline check prefers the control's deadline, honors the guard window and labels the error", {
	f <- ci_priv()
	withr::local_options(list(EDI.ci_timeout_deadline = NULL, EDI.ci_timeout_guard_sec = 0.5))
	expect_false(f$priv$check_randomization_ci_deadline())
	expect_false(f$priv$check_randomization_ci_deadline(list(timeout_deadline = NA_real_)))

	now <- unname(proc.time()[["elapsed"]])
	expect_false(f$priv$check_randomization_ci_deadline(list(timeout_deadline = now + 1000)))
	expect_error(f$priv$check_randomization_ci_deadline(list(timeout_deadline = now - 5), label = "My search"),
		"My search reached elapsed time limit")
	# The control's deadline wins over the option; with no control value the option is used.
	withr::local_options(list(EDI.ci_timeout_deadline = now - 5))
	expect_false(f$priv$check_randomization_ci_deadline(list(timeout_deadline = now + 1000)))
	expect_error(f$priv$check_randomization_ci_deadline(NULL), "Randomization CI bisection reached elapsed time limit")
	# Inside the guard window the check already trips.
	withr::local_options(list(EDI.ci_timeout_deadline = now + 5, EDI.ci_timeout_guard_sec = 60))
	expect_error(f$priv$check_randomization_ci_deadline(NULL), "reached elapsed time limit")
	withr::local_options(list(EDI.ci_timeout_deadline = now + 1000, EDI.ci_timeout_guard_sec = -3))
	expect_false(f$priv$check_randomization_ci_deadline(NULL))
})

test_that("incidence-only randomization arguments are rejected for other response types (when assertions are on)", {
	f <- ci_priv()
	expect_null(f$priv$assert_no_incidence_only_randomization_args("continuous", NULL, NULL))
	expect_error(f$priv$assert_no_incidence_only_randomization_args("continuous", "zhang", NULL), "only supported for incidence")
	expect_error(f$priv$assert_no_incidence_only_randomization_args("continuous", NULL, list(a = 1)), "args_for_type is only used")
	old <- options(edi.run_asserts = FALSE); on.exit(options(old), add = TRUE)
	expect_null(f$priv$assert_no_incidence_only_randomization_args("continuous", "zhang", list(a = 1)))
})

test_that("the cached p-value evaluator memoizes by (resolution-rounded) delta and turns failures into NA", {
	f <- ci_priv()
	calls <- numeric(0)
	fake <- list(compute_rand_two_sided_pval = function(r, delta, transform_responses, na.rm, show_progress, permutations) {
		calls <<- c(calls, delta)
		if (delta > 100) stop("boom")
		if (delta < -100) return(numeric(0))
		c(0.25, 0.9)
	})
	ctrl <- list(pval_cache_enable = TRUE, pval_cache_resolution = 0.01)
	cache <- new.env()
	ev <- function(delta, ctl = ctrl, cch = cache) f$priv$compute_randomization_ci_pval_cached(fake, 100, delta, "none", NULL, ctl, cch)

	expect_equal(ev(0.301), 0.25)
	expect_equal(length(calls), 1L)
	expect_equal(ev(0.3049), 0.25)                       # rounds to the same 0.30 key -> cache hit
	expect_equal(length(calls), 1L)
	expect_equal(ev(0.42), 0.25)
	expect_equal(length(calls), 2L)

	expect_true(is.na(ev(500)))                          # error -> NA (and cached)
	expect_true(is.na(ev(-500)))                         # empty result -> NA
	n_before <- length(calls)
	expect_true(is.na(ev(500)))
	expect_equal(length(calls), n_before)

	# Cache disabled or absent: every call evaluates.
	calls <- numeric(0)
	ev(0.1, ctl = list(pval_cache_enable = FALSE)); ev(0.1, ctl = list(pval_cache_enable = FALSE))
	expect_equal(length(calls), 2L)
	calls <- numeric(0)
	ev(0.1, cch = NULL); ev(0.1, cch = NULL)
	expect_equal(length(calls), 2L)
})

test_that("seed candidates are the class's own Wald / asymptotic intervals at 2 * alpha, sorted and NA-safe", {
	f <- ci_priv()
	sc <- f$priv$get_randomization_ci_seed_candidates(f$inf, 0.05)
	ref <- sort(as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.1)))
	expect_equal(sc$asym_ci, ref, tolerance = 1e-10)
	expect_equal(sc$wald_ci, ref, tolerance = 1e-10)
	# A wider alpha gives a narrower seed interval.
	wide <- f$priv$get_randomization_ci_seed_candidates(f$inf, 0.2)
	expect_lt(diff(wide$asym_ci), diff(sc$asym_ci))

	# Failing or non-finite intervals collapse to NA pairs; missing methods yield NA pairs.
	broken <- list(compute_asymp_confidence_interval = function(alpha) stop("nope"), get_supported_testing_types = function() "wald")
	expect_equal(f$priv$get_randomization_ci_seed_candidates(broken, 0.05), list(wald_ci = c(NA_real_, NA_real_), asym_ci = c(NA_real_, NA_real_)))
	expect_equal(f$priv$get_randomization_ci_seed_candidates(list(), 0.05), list(wald_ci = c(NA_real_, NA_real_), asym_ci = c(NA_real_, NA_real_)))
	inf_ci <- list(compute_asymp_confidence_interval = function(alpha) c(2, NA), get_supported_testing_types = function() character())
	expect_equal(f$priv$get_randomization_ci_seed_candidates(inf_ci, 0.05)$asym_ci, c(NA_real_, NA_real_))
	rev_ci <- list(compute_asymp_confidence_interval = function(alpha) c(5, 1), get_supported_testing_types = function() character())
	expect_equal(f$priv$get_randomization_ci_seed_candidates(rev_ci, 0.05)$asym_ci, c(1, 5))
})

test_that("search bounds bracket the estimate and expose the Wald fallback interval", {
	f <- ci_priv()
	ref_ci <- sort(as.numeric(f$inf$compute_asymp_confidence_interval(alpha = 0.1)))   # populate the asymptotic cache first
	ctrl <- f$priv$normalize_randomization_ci_search_control(NULL, r = 201, pval_epsilon = 0.005)
	set.seed(2)
	b <- f$priv$build_randomization_ci_search_bounds(f$inf, r = 201L, alpha = 0.05, transform_arg = "none",
		permutations = NULL, ci_search_control = ctrl, ci_pval_cache = new.env())
	expect_named(b, c("est", "l", "u", "fallback_ci"))
	expect_equal(b$est, as.numeric(f$inf$compute_estimate()), tolerance = 1e-12)
	expect_lt(b$l, b$est)
	expect_gt(b$u, b$est)
	expect_equal(b$fallback_ci, ref_ci, tolerance = 1e-10)
})

test_that("a randomization p-value taken before any asymptotic call does not poison the cached SE", {
	poisoned <- ci_priv()
	set.seed(1)
	poisoned$inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE)
	expect_true(is.finite(poisoned$priv$cached_values$beta_hat_T))
	ci_after <- poisoned$inf$compute_asymp_confidence_interval()
	expect_true(all(is.finite(ci_after)))
	expect_true(is.finite(poisoned$priv$cached_values$s_beta_hat_T))
	healthy0 <- ci_priv(); healthy0$inf$compute_estimate()
	expect_equal(ci_after, healthy0$inf$compute_asymp_confidence_interval(), tolerance = 1e-10)

	healthy <- ci_priv()
	healthy$inf$compute_estimate()
	set.seed(1)
	healthy$inf$compute_rand_two_sided_pval(r = 201, show_progress = FALSE)
	expect_true(all(is.finite(healthy$inf$compute_asymp_confidence_interval())))

	fresh <- ci_priv()
	ctrl <- fresh$priv$normalize_randomization_ci_search_control(NULL, r = 201, pval_epsilon = 0.005)
	set.seed(2)
	b <- fresh$priv$build_randomization_ci_search_bounds(fresh$inf, r = 201L, alpha = 0.05, transform_arg = "none",
		permutations = NULL, ci_search_control = ctrl, ci_pval_cache = new.env())
	expect_true(all(is.finite(b$fallback_ci)))
	ref_fresh <- ci_priv()
	expect_equal(b$fallback_ci, sort(as.numeric(ref_fresh$inf$compute_asymp_confidence_interval(alpha = 0.1))), tolerance = 1e-10)
})
