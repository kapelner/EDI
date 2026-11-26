# v1.0.6-TODO-95: under left-/interval-censoring the censored subjects' y is NA, so the
# bootstrap randomization test's sharp-null shift (applied to y only) left y_L / y_R at their
# observed values on both the reusable-worker and the slow path. The null distribution then
# ignored delta entirely when every subject was censored (identical draws at delta = -1, 0, 1)
# and imposed the null on exact times only otherwise. The bounds now get the same shift as y.

brt_bounds_interval_design = function(n = 60L, all_interval = FALSE){
	set.seed(2)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "survival", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	t_true = rexp(n, exp(-1 - 0.8 * des$get_w() + 0.5 * X$x1))
	kind = if (all_interval) rep("interval", n) else sample(c("exact", "interval", "right"), n, replace = TRUE)
	y = ifelse(kind == "exact", t_true, NA_real_)
	y_L = ifelse(kind == "interval", t_true * 0.7, ifelse(kind == "right", t_true * 0.8, NA_real_))
	y_R = ifelse(kind == "interval", t_true * 1.3, ifelse(kind == "right", Inf, NA_real_))
	des$add_all_subject_responses(y, y_L, y_R)
	des
}

brt_bounds_null_draws = function(cls, des, delta, worker, B = 8L){
	inf = suppressWarnings(get(cls)$new(des, verbose = FALSE))
	inf$.__enclos_env__$private$reusable_bootstrap_worker_enabled = worker
	set.seed(4)
	suppressWarnings(inf$approximate_rand_bootstrap_distribution_beta_hat_T(
		B = B, delta = delta, transform_responses = "log", show_progress = FALSE))
}

test_that("the null censoring bounds carry the multiplicative sharp-null shift", {
	des = brt_bounds_interval_design()
	inf = suppressWarnings(InferenceSurvivalWeibullRegr$new(des, verbose = FALSE))
	p = inf$.__enclos_env__$private
	set.seed(1)
	i_b = sample.int(60L, 60L, replace = TRUE)
	w_new = rbinom(60L, 1L, 0.5)
	delta = 0.7
	b = p$rand_bootstrap_null_censoring_bounds(i_b, w_new, delta, "log", "survival")
	w = des$get_w()
	y_L0 = des$get_y_L() * exp(-delta * w)
	y_R0 = des$get_y_R() * exp(-delta * w)
	expect_equal(b$y_L, y_L0[i_b] * exp(delta * w_new))
	expect_equal(b$y_R, y_R0[i_b] * exp(delta * w_new))
	# Inf (right-censored) and NA (exact) stay as they are
	expect_identical(is.infinite(b$y_R), is.infinite(des$get_y_R()[i_b]))
	expect_identical(is.na(b$y_L), is.na(des$get_y_L()[i_b]))
})

test_that("an all-interval-censored rand-bootstrap null distribution moves with delta", {
	des = brt_bounds_interval_design(all_interval = TRUE)
	for (worker in c(TRUE, FALSE)) {
		m = vapply(c(-1, 0, 1), function(d) mean(brt_bounds_null_draws("InferenceSurvivalWeibullRegr", des, d, worker, B = 20L)), numeric(1))
		# Weibull's estimate is a log time ratio, so the null draws centre on delta.
		expect_equal(m[3L] - m[2L], 1, tolerance = 0.2, info = paste("worker", worker))
		expect_equal(m[2L] - m[1L], 1, tolerance = 0.2, info = paste("worker", worker))
	}
})

test_that("the slow path matches the reusable worker at nonzero delta on interval-censored data", {
	des = brt_bounds_interval_design()
	skipped = character(0)
	for (cls in c("InferenceSurvivalWeibullRegr", "InferenceSurvivalKMDiff", "InferenceSurvivalLogRank")) {
		# v1.0.6-TODO-126: skip a class whose interval-censored fit needs an absent Suggests package
		missing_pkg = general_censoring_missing_package(cls, des)
		if (length(missing_pkg)) { skipped[[cls]] = missing_pkg; next }
		fast = brt_bounds_null_draws(cls, des, 0.7, TRUE)
		slow = brt_bounds_null_draws(cls, des, 0.7, FALSE)
		expect_true(all(is.finite(slow)), info = cls)
		expect_equal(slow, fast, tolerance = 1e-6, info = cls)
		# the shift now reaches the censored subjects: draws differ from delta = 0
		expect_false(isTRUE(all.equal(slow, brt_bounds_null_draws(cls, des, 0, FALSE))), info = cls)
	}
	skip_inference_fixtures_missing_packages(skipped)
})
