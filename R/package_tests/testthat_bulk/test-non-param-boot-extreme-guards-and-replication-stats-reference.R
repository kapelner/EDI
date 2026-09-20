library(testthat)
library(EDI)

# InferenceNonParamBootstrap's small private decision helpers, none of which had
# a direct test reference: bootstrap_estimates_extreme() / bootstrap_confidence_
# interval_extreme() (separation-style sanity guards), missing_bootstrap_ci(),
# renumber_match_ids(), the control-condition passthrough (is_resampling_control_
# condition / resampling_error_to_na), check_bootstrap_replicate_deadline(),
# assert_valid_bootstrap_type() / get_bootstrap_type(), and
# bootstrap_replication_stats(). Expected values follow the documented rules,
# computed independently in the test.

boot_priv <- function(n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n, sd = 0.3))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("bootstrap_estimates_extreme flags out-of-range draws and implausibly wide spreads", {
	f <- boot_priv()
	ext <- f$priv$bootstrap_estimates_extreme
	expect_false(ext(numeric(0)))
	expect_false(ext(c(NA, Inf, NaN)))
	expect_false(ext(c(1, 2, 3), est = 2, max_abs = 10))
	# Any finite draw beyond max_abs is extreme; non-finite draws are ignored.
	expect_true(ext(c(1, 2, 11), est = 2, max_abs = 10))
	expect_false(ext(c(1, 2, NA), est = 2, max_abs = 10))
	# Spread rule: 95% quantile width (type 8) above max_abs * max(1, |est|, median|theta|).
	theta <- c(-8, -7, 0, 7, 8, rep(0, 20))
	width <- diff(quantile(theta, c(0.025, 0.975), names = FALSE, type = 8))
	scale_ref <- max(1, 0, median(abs(theta)))
	expect_equal(ext(theta, est = 0, max_abs = 10), width > 10 * scale_ref)
	expect_true(ext(theta, est = 0, max_abs = 1))
	# A non-positive / invalid threshold falls back to the package separation threshold.
	expect_false(ext(c(1, 2, 3), est = 2, max_abs = -5))
	expect_true(ext(c(1, 2, 2e6), est = 2, max_abs = NA))
})

test_that("bootstrap_confidence_interval_extreme applies the magnitude, scaled-width and absolute-width rules", {
	f <- boot_priv()
	ext <- f$priv$bootstrap_confidence_interval_extreme
	expect_false(ext(c(NA, 1), est = 0))
	expect_false(ext(1, est = 0))
	expect_true(ext(c(-1, 200), est = 0, max_abs = 100))                     # endpoint beyond max_abs
	expect_true(ext(c(0, 6), est = 0, max_abs = 100))                        # width 6 > absolute cap 5
	expect_false(ext(c(0, 4), est = 0, max_abs = 100))                       # width 4 <= 5
	expect_true(ext(c(-0.9, 0.9), est = 0, max_abs = 1))                     # width 1.8 > max_abs * scale (1 * 1)
	expect_false(ext(c(-0.9, 0.9), est = 0, max_abs = 3))
	expect_true(ext(c(0, 6), est = 10, max_abs = 10))                        # scaled width 100, but absolute cap 5 wins
	expect_false(ext(c(0, 4.9), est = 10, max_abs = 10))
	expect_false(ext(c(0, 4), est = 0, max_abs = NA))                        # invalid max_abs -> 1e6
})

test_that("missing_bootstrap_ci returns a named NA interval and caches the reason at the requested stage", {
	f <- boot_priv()
	ci <- f$priv$missing_bootstrap_ci(0.1, "bootstrap_unavailable_reason", stage = "estimate")
	expect_equal(names(ci), c("5%", "95%"))
	expect_true(all(is.na(ci)))
	expect_true(f$inf$is_nonestimable("estimate"))

	f2 <- boot_priv()
	f2$priv$missing_bootstrap_ci(0.05, "se_reason", stage = "se")
	expect_true(f2$inf$is_nonestimable("se"))
	expect_false(f2$inf$is_nonestimable("estimate"))
	expect_error(f2$priv$missing_bootstrap_ci(0.05, "x", stage = "bogus"))
})

test_that("renumber_match_ids compacts positive ids in ascending order and zeroes unmatched entries", {
	f <- boot_priv()
	rn <- f$priv$renumber_match_ids
	expect_null(rn(NULL))
	expect_equal(rn(c(5, 5, 9, 0, NA, 9, 2, 2)), c(2L, 2L, 3L, 0L, 0L, 3L, 1L, 1L))
	expect_equal(rn(c(0, NA, 0)), c(0L, 0L, 0L))
	expect_equal(rn(c(10, 20, 30)), c(1L, 2L, 3L))
	expect_equal(rn(integer(0)), integer(0))
})

test_that("control conditions (timeouts / interrupts) pass through error-to-NA conversion; ordinary errors become NA", {
	f <- boot_priv()
	ordinary <- simpleError("something else failed")
	timeout <- simpleError("Bootstrap replicate reached elapsed time limit")
	cpu <- simpleError("x reached CPU time limit")
	expect_false(f$priv$is_resampling_control_condition(ordinary))
	expect_true(f$priv$is_resampling_control_condition(timeout))
	expect_true(f$priv$is_resampling_control_condition(cpu))
	expect_true(f$priv$is_resampling_control_condition(structure(class = c("interrupt", "condition"), list(message = "", call = NULL))))
	expect_true(is.na(f$priv$resampling_error_to_na(ordinary)))
	expect_error(f$priv$resampling_error_to_na(timeout), "elapsed time limit")
})

test_that("check_bootstrap_replicate_deadline stops only once the (guarded) deadline has passed", {
	f <- boot_priv()
	withr::local_options(list(EDI.ci_timeout_deadline = NULL))
	expect_false(f$priv$check_bootstrap_replicate_deadline())

	now <- unname(proc.time()[["elapsed"]])
	withr::local_options(list(EDI.ci_timeout_deadline = now + 1000, EDI.ci_timeout_guard_sec = 0.5))
	expect_false(f$priv$check_bootstrap_replicate_deadline())

	withr::local_options(list(EDI.ci_timeout_deadline = now - 1))
	expect_error(f$priv$check_bootstrap_replicate_deadline("Custom label"), "Custom label reached elapsed time limit")

	# The guard window makes it trigger slightly before the deadline itself.
	withr::local_options(list(EDI.ci_timeout_deadline = now + 5, EDI.ci_timeout_guard_sec = 10))
	expect_error(f$priv$check_bootstrap_replicate_deadline(), "reached elapsed time limit")
	withr::local_options(list(EDI.ci_timeout_deadline = "not a number"))
	expect_false(f$priv$check_bootstrap_replicate_deadline())
})

test_that("bootstrap_type is validated only for blocking designs, and an explicit type passes through", {
	f <- boot_priv()
	expect_null(f$priv$assert_valid_bootstrap_type(NULL))
	expect_error(f$priv$assert_valid_bootstrap_type("within_blocks"), "only be set for blocking designs")
	expect_error(f$priv$assert_valid_bootstrap_type("nonsense"), "within_blocks|resample_blocks")
	expect_equal(f$priv$get_bootstrap_type("resample_blocks"), "resample_blocks")
	expect_equal(f$priv$get_bootstrap_type(NULL), EDI:::edi_bootstrap_dispatch_policy(class(f$inf), object = f$inf))
})

test_that("bootstrap_replication_stats returns theta/se pairs and converts every failure mode to NA", {
	f <- boot_priv()
	fake_sub <- function(theta = 1.5, se = 0.4, nonest = character(0), boom = NULL) {
		env <- new.env()
		env$cached_values <- list(s_beta_hat_T = se)
		list(
			compute_estimate = function(estimate_only = FALSE) { if (!is.null(boom)) stop(boom); theta },
			is_nonestimable = function(what) what %in% nonest,
			.__enclos_env__ = list(private = env)
		)
	}
	set_sub <- function(x) {
		unlockBinding("bootstrap_subset_inference", f$priv)
		f$priv$bootstrap_subset_inference <- function(draw, smooth = FALSE) x
	}
	stats_of <- function(...) f$priv$bootstrap_replication_stats(list(), ...)

	set_sub(NULL)
	expect_equal(stats_of(), c(theta = NA_real_, se = NA_real_))

	set_sub(fake_sub())
	expect_equal(stats_of(), c(theta = 1.5, se = NA_real_))
	expect_equal(stats_of(require_se = TRUE), c(theta = 1.5, se = 0.4))

	set_sub(fake_sub(nonest = "estimate"))
	expect_equal(stats_of(require_se = TRUE), c(theta = NA_real_, se = NA_real_))
	set_sub(fake_sub(nonest = "se"))
	expect_equal(stats_of(require_se = TRUE), c(theta = 1.5, se = NA_real_))
	set_sub(fake_sub(theta = Inf, se = Inf))
	expect_equal(stats_of(require_se = TRUE), c(theta = NA_real_, se = NA_real_))

	set_sub(fake_sub(boom = "ordinary failure"))
	expect_equal(stats_of(), c(theta = NA_real_, se = NA_real_))
	set_sub(fake_sub(boom = "Bootstrap replicate reached elapsed time limit"))
	expect_error(stats_of(), "elapsed time limit")
})
