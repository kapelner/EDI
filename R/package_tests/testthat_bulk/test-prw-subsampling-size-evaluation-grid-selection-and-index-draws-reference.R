library(testthat)
library(EDI)

# InferenceExtPRWSubsampling helpers around the subsampling distribution: subsampling_sample_indices()
# (size-b draws without replacement, sorted rows), evaluate_subsampling_size() (finite-population
# corrected centred pivot, CI and p-value checked in closed form on a stubbed draw distribution,
# nonestimable branches), the b-grid construction in select_optimal_b_subsampling(), the
# sensitivity wrapper's output class, and the worker load / estimate delegations.

ps_fx <- function(n = 60L, seed = 4L, draws = NULL) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des); inf$num_cores <- 1L
	f <- list(inf = inf, p = inf$.__enclos_env__$private, n = n)
	if (!is.null(draws)) {
		est <- inf$compute_estimate()
		D <- if (is.function(draws)) draws(est) else draws
		unlockBinding("approximate_subsampling_distribution_beta_hat_T", inf)
		inf$approximate_subsampling_distribution_beta_hat_T <- function(B, b, show_progress = FALSE, subsampling_type = NULL, scaling = "sqrt_n", ...) D
		f$draws <- D; f$est <- est
	}
	f
}

test_that("index draws: b distinct units without replacement, returned in increasing row order", {
	f <- ps_fx()
	set.seed(1)
	for (i in 1:20) {
		s <- f$p$subsampling_sample_indices(12L)
		expect_length(s$i_b, 12L); expect_false(anyDuplicated(s$i_b) > 0)
		expect_false(is.unsorted(s$i_b))
		expect_true(all(s$i_b %in% seq_len(f$n)))
		expect_equal(s$b, 12L); expect_equal(s$n_units, f$n); expect_equal(s$unit_type, "observation")
	}
	# Different seeds give different subsamples.
	set.seed(2); a <- f$p$subsampling_sample_indices(12L)$i_b; set.seed(3); b <- f$p$subsampling_sample_indices(12L)$i_b
	expect_false(identical(a, b))
})

test_that("size evaluation applies the finite-population correction to the centred, scaled draws", {
	f <- ps_fx(draws = function(est) est + rnorm(300, 0, 0.2))
	b <- 15L; alpha <- 0.1
	e <- f$p$evaluate_subsampling_size(b = b, B = 300L, alpha = alpha)
	fpc <- 1 / sqrt(1 - b / f$n)
	cs <- fpc * sqrt(b) * (f$draws - f$est)
	q <- quantile(cs, c(1 - alpha / 2, alpha / 2), names = FALSE, type = 8)
	expect_equal(e$status, "ok")
	expect_equal(as.numeric(e$ci), f$est - q / sqrt(f$n), tolerance = 1e-10)
	expect_equal(names(e$ci), c("5%", "95%"))
	t_obs <- sqrt(f$n) * f$est
	expect_equal(e$pval, min(1, max(2 / 300, 2 * min(mean(cs <= t_obs), mean(cs >= t_obs)))), tolerance = 1e-10)
	expect_equal(c(e$n_finite, e$finite_fraction), c(300L, 1))
	expect_equal(e$estimate, f$est)
	expect_true(is.na(e$dominant_failure_reason))
})

test_that("size evaluation reports missing draws, an unavailable estimate and out-of-range sizes", {
	g <- ps_fx(draws = c(NA, Inf, NaN))
	e <- g$p$evaluate_subsampling_size(b = 15L, B = 3L, alpha = 0.1)
	expect_equal(e$status, "nonestimable"); expect_equal(e$dominant_failure_reason, "subsampling_too_few_finite_estimates")
	expect_equal(e$n_finite, 0L); expect_equal(e$finite_fraction, 0)
	h <- ps_fx()
	unlockBinding("compute_estimate", h$inf); h$inf$compute_estimate <- function(estimate_only = FALSE) NA_real_
	r <- h$p$evaluate_subsampling_size(b = 15L, B = 50L, alpha = 0.1)
	expect_equal(r$status, "nonestimable"); expect_equal(r$dominant_failure_reason, "subsampling_original_estimate_unavailable")
	expect_equal(r$n_finite, 0L)
	expect_error(ps_fx()$p$evaluate_subsampling_size(b = 2L, B = 50L, alpha = 0.1), "must satisfy")
	expect_error(ps_fx()$p$evaluate_subsampling_size(b = 45L, B = 50L, alpha = 0.1), "must satisfy")
	# Extreme draws make the interval unusable.
	x <- ps_fx(draws = function(est) c(est + 1e9, est - 1e9, rep(est, 20)))
	ex <- x$p$evaluate_subsampling_size(b = 15L, B = 22L, alpha = 0.1)
	expect_equal(ex$status, "nonestimable"); expect_equal(ex$dominant_failure_reason, "subsampling_extreme_confidence_interval")
})

test_that("b-grid selection: exponent grid maps to unique floor(n^p) sizes; an explicit grid overrides it", {
	f <- ps_fx(draws = function(est) est + rnorm(60, 0, 0.2))
	sel <- f$inf$select_optimal_b_subsampling(B = 60L, b_pow_of_n_grid = c(0.5, 0.55, 0.6, 0.7), show_progress = FALSE)
	expect_s3_class(sel, "EDISubsamplingBSelection")
	gt <- sel$grid_table
	expect_equal(gt$b, unique(floor(60^c(0.5, 0.55, 0.6, 0.7))))
	expect_equal(gt$b_pow_of_n, c(0.5, 0.55, 0.6, 0.7)[!duplicated(floor(60^c(0.5, 0.55, 0.6, 0.7)))])
	expect_true(sel$b_optimal %in% gt$b)
	g <- f$inf$select_optimal_b_subsampling(B = 60L, b_grid = c(10L, 14L, 18L, 22L), show_progress = FALSE)
	expect_equal(g$grid_table$b, c(10L, 14L, 18L, 22L)); expect_true(all(is.na(g$grid_table$b_pow_of_n)))
	expect_true(g$b_optimal %in% c(10L, 14L, 18L, 22L))
	expect_error(f$inf$select_optimal_b_subsampling(B = 60L, b_grid = c(10L, 14L), show_progress = FALSE), "at least volatility_window unique values")
	expect_error(f$inf$select_optimal_b_subsampling(B = 60L, b_grid = 10:14, target = "pval", show_progress = FALSE))
})

test_that("the sensitivity wrapper returns the grid table with the selection fields removed and its own class", {
	f <- ps_fx(draws = function(est) est + rnorm(60, 0, 0.2))
	s <- f$inf$compute_subsampling_sensitivity(B = 60L, b_grid = c(10L, 14L, 18L), show_progress = FALSE)
	expect_s3_class(s, "EDISubsamplingSensitivity")
	expect_false(inherits(s, "EDISubsamplingBSelection"))
	expect_equal(s$grid_table$b, c(10L, 14L, 18L))
	for (nm in c("status", "reason", "b_optimal", "b_pow_of_n_optimal")) expect_null(s[[nm]], info = nm)
	expect_true(all(c("grid_table", "objective") %in% names(s)))
})

test_that("worker loading and estimation delegate to the bootstrap worker hooks", {
	f <- ps_fx()
	calls <- character(0)
	unlockBinding("load_bootstrap_sample_into_worker", f$p); unlockBinding("estimate_bootstrap_worker", f$p)
	f$p$load_bootstrap_sample_into_worker <- function(worker_state, draw) { calls <<- c(calls, paste("load", draw$tag)); invisible(NULL) }
	f$p$estimate_bootstrap_worker <- function(worker_state) { calls <<- c(calls, "estimate"); 3.5 }
	ws <- list(id = 1)
	expect_identical(f$p$load_subsampling_draw_into_worker(ws, list(tag = "d1")), ws)
	expect_equal(f$p$compute_subsampling_worker_estimate(ws), 3.5)
	expect_equal(calls, c("load d1", "estimate"))
})
