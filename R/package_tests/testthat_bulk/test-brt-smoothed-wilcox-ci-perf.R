library(EDI)

SlowInferenceAllSimpleWilcox = R6::R6Class(
	"SlowInferenceAllSimpleWilcox",
	inherit = InferenceAllSimpleWilcox,
	lock_objects = FALSE,
	private = list(
		compute_fast_rand_bootstrap_distr = function(y0_full, rand_bootstrap_draws, delta, transform_responses, zero_one_logit_clamp = .Machine$double.eps){
			NULL
		}
	)
)

test_that("smoothed CI: fast-kernel result matches the forced-slow-fallback result", {
	set.seed(20260731)
	n = 20
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	X = data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))

	fast_inf = InferenceAllSimpleWilcox$new(des)
	slow_inf = SlowInferenceAllSimpleWilcox$new(des)

	set.seed(99)
	fast_ci = fast_inf$compute_rand_bootstrap_confidence_interval(B = 51, type = "smoothed", show_progress = FALSE)
	set.seed(99)
	slow_ci = slow_inf$compute_rand_bootstrap_confidence_interval(B = 51, type = "smoothed", show_progress = FALSE)

	expect_equal(as.numeric(fast_ci), as.numeric(slow_ci), tolerance = 1e-6)
})

test_that("smoothed CI: fast kernel is dramatically faster than the forced-slow fallback", {
	skip_on_cran()
	# This is the actual motivating case from the original investigation: CI inversion
	# pre-materializes fresh assignments (materialize_w = TRUE) once and reuses them (common
	# random numbers) across every delta evaluated during root-finding, so the fast kernel can
	# engage on every one of those evaluations. A *standalone* compute_rand_bootstrap_two_sided_pval
	# call (no CI inversion) deliberately draws w lazily per-iteration (materialize_w = FALSE) for
	# CRN reasons unrelated to smoothing, so rand_bootstrap_draw_matrices() can't build i_mat/w_mat
	# and the fast kernel never engages there regardless of this fix — that path's cost is
	# untouched by design, not a regression, so it is not asserted on here.
	set.seed(20260732)
	n = 20
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	X = data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))

	fast_inf = InferenceAllSimpleWilcox$new(des)
	slow_inf = SlowInferenceAllSimpleWilcox$new(des)

	# Best-of-3 timing on both paths: at this workload t_fast is only a few
	# hundredths of a second, so a single measurement is dominated by fixed
	# overhead and scheduler noise on a loaded shared CI runner -- run
	# 33599645201 failed this assertion at 4.97x against the 5x threshold
	# (t_fast=0.032s, t_slow=0.159s) from one noisy t_fast sample. The
	# minimum over three runs is the standard de-noising for
	# micro-benchmarks: noise only ever adds time, so min approaches the
	# true cost.
	time_best_of_3 = function(fn) {
		min(vapply(1:3, function(i) {
			set.seed(99)
			system.time(fn())[["elapsed"]]
		}, numeric(1)))
	}
	t_fast = time_best_of_3(function()
		fast_ci <<- fast_inf$compute_rand_bootstrap_confidence_interval(B = 51, type = "smoothed", show_progress = FALSE)
	)
	t_slow = time_best_of_3(function()
		slow_ci <<- slow_inf$compute_rand_bootstrap_confidence_interval(B = 51, type = "smoothed", show_progress = FALSE)
	)

	expect_equal(as.numeric(fast_ci), as.numeric(slow_ci), tolerance = 1e-6)
	# Measured ~50x on this workload during development; require at least 5x here to allow for
	# machine variance while still catching a regression back to the fully-slow path.
	expect_true(t_fast < t_slow / 5, info = sprintf("t_fast=%.3fs t_slow=%.3fs", t_fast, t_slow))
})
