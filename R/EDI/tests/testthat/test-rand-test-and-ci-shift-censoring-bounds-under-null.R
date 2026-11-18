# v1.0.6-TODO-143 follow-up (owner decision 2026-11-18): the plain randomization test and the
# randomization CI used to refuse a nonzero delta under left-/interval-censoring, because the
# sharp-null shift reached y (NA for censored subjects) but not y_L / y_R. They now shift the
# bounds exactly as y is shifted (multiplicatively, exp(delta), on the default "log" scale for
# survival; 0 and Inf bounds stay put), on the reusable-worker path and the slow path alike,
# through the shared randomization_null_censoring_bounds() helper that the bootstrap
# randomization test (v1.0.6-TODO-143 itself) also uses.

rand_bounds_interval_design = function(n = 60L, all_interval = FALSE){
	set.seed(2)
	X = data.frame(x1 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "survival", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	t_true = rexp(n, exp(-1 - 0.8 * des$get_w() + 0.5 * X$x1))
	kind = if (all_interval) rep("interval", n) else sample(c("exact", "interval", "right", "left"), n, replace = TRUE)
	y = ifelse(kind == "exact", t_true, NA_real_)
	y_L = ifelse(kind == "interval", t_true * 0.7, ifelse(kind == "right", t_true * 0.8, ifelse(kind == "left", 0, NA_real_)))
	y_R = ifelse(kind == "interval", t_true * 1.3, ifelse(kind == "right", Inf, ifelse(kind == "left", t_true * 1.2, NA_real_)))
	des$add_all_subject_responses(y, y_L, y_R)
	des
}

rand_bounds_null_draws = function(cls, des, delta, worker, r = 12L){
	inf = suppressWarnings(get(cls)$new(des, verbose = FALSE))
	inf$num_cores = 1L
	inf$.__enclos_env__$private$reusable_bootstrap_worker_enabled = worker
	inf$set_seed(4)
	suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(
		r = r, delta = delta, transform_responses = "log", show_progress = FALSE))
}

test_that("the plain-rand null bounds remove delta at the observed w and re-impose it at the draw's w", {
	des = rand_bounds_interval_design()
	inf = suppressWarnings(InferenceSurvivalWeibullRegr$new(des, verbose = FALSE))
	p = inf$.__enclos_env__$private
	set.seed(1)
	w_new = rbinom(60L, 1L, 0.5)
	delta = 0.7
	b = p$randomization_null_censoring_bounds(w_new, delta, "log", "survival")
	w = des$get_w()
	expect_equal(b$y_L, des$get_y_L() * exp(delta * (w_new - w)))
	expect_equal(b$y_R, des$get_y_R() * exp(delta * (w_new - w)))
	# 0 (left-censored), Inf (right-censored) and NA (exact) bounds stay as they are
	expect_identical(b$y_L == 0, des$get_y_L() == 0)
	expect_identical(is.infinite(b$y_R), is.infinite(des$get_y_R()))
	expect_identical(is.na(b$y_L), is.na(des$get_y_L()))
	# the bootstrap helper is the same shift on resampled rows
	i_b = sample.int(60L, 60L, replace = TRUE)
	expect_equal(
		p$rand_bootstrap_null_censoring_bounds(i_b, w_new, delta, "log", "survival"),
		p$randomization_null_censoring_bounds(w_new, delta, "log", "survival", i_b = i_b)
	)
})

test_that("an all-interval-censored randomization null distribution moves with delta", {
	des = rand_bounds_interval_design(all_interval = TRUE)
	for (worker in c(TRUE, FALSE)) {
		m = vapply(c(-1, 0, 1), function(d) mean(rand_bounds_null_draws("InferenceSurvivalWeibullRegr", des, d, worker, r = 20L)), numeric(1))
		# Weibull's estimate is a log time ratio, so the null draws centre on delta.
		expect_equal(m[3L] - m[2L], 1, tolerance = 0.2, info = paste("worker", worker))
		expect_equal(m[2L] - m[1L], 1, tolerance = 0.2, info = paste("worker", worker))
	}
})

test_that("the slow path matches the reusable worker at nonzero delta for every general-censoring survival class", {
	des = rand_bounds_interval_design()
	for (cls in c("InferenceSurvivalWeibullRegr", "InferenceSurvivalKMDiff", "InferenceSurvivalRestrictedMeanDiff",
			"InferenceSurvivalLogRank", "InferenceSurvivalGehanWilcox", "InferenceSurvivalCoxPHRegr")) {
		fast = rand_bounds_null_draws(cls, des, 0.7, TRUE)
		slow = rand_bounds_null_draws(cls, des, 0.7, FALSE)
		expect_true(sum(is.finite(slow)) >= 10L, info = cls)
		expect_equal(slow, fast, tolerance = 1e-6, info = cls)
		# the shift reaches the censored subjects: draws differ from delta = 0
		expect_false(isTRUE(all.equal(slow, rand_bounds_null_draws(cls, des, 0, FALSE))), info = cls)
	}
})

test_that("a worker reused across deltas does not keep the previous delta's bounds", {
	des = rand_bounds_interval_design()
	inf = suppressWarnings(InferenceSurvivalWeibullRegr$new(des, verbose = FALSE))
	inf$num_cores = 1L
	p = inf$.__enclos_env__$private
	draws = function(d) { inf$set_seed(4); inf$approximate_randomization_distribution_beta_hat_T(r = 12L, delta = d, transform_responses = "log", show_progress = FALSE) }
	fresh0 = draws(0)
	p$begin_rand_worker_reuse_session()
	draws(1)
	after = draws(0)
	p$end_rand_worker_reuse_session()
	expect_equal(after, fresh0, tolerance = 1e-8)
})

test_that("the rand p-value and the Weibull rand CI run at nonzero delta on interval-censored data", {
	des = rand_bounds_interval_design()
	inf = suppressWarnings(InferenceSurvivalWeibullRegr$new(des, verbose = FALSE))
	inf$num_cores = 1L
	inf$set_seed(1)
	p = inf$compute_rand_two_sided_pval(r = 50L, delta = 0.5, show_progress = FALSE)
	expect_true(is.finite(p) && p >= 0 && p <= 1)
	inf$set_seed(1)
	ci = suppressMessages(inf$compute_rand_confidence_interval(r = 50L, show_progress = FALSE))
	expect_length(ci, 2L)
	expect_true(all(is.finite(ci)) && ci[1L] < ci[2L])
	est = inf$compute_estimate()
	expect_true(ci[1L] <= est && est <= ci[2L])
	km = suppressWarnings(InferenceSurvivalKMDiff$new(des, verbose = FALSE))
	km$num_cores = 1L
	km$set_seed(1)
	expect_true(is.finite(suppressWarnings(km$compute_rand_two_sided_pval(r = 50L, delta = -0.4, show_progress = FALSE))))
})
