# v1.0.6-TODO-195 (1) / (3): the KK hurdle-Poisson classes fit the count part of a
# hurdle model (a zero-truncated Poisson GLMM on the matched rows with a positive
# count; OneLik adds a plain Poisson likelihood on the reservoir). They had none of
# the zero-augmented guards: when every positive matched row was treated the
# estimate was an arbitrary -0.43 (SE 0.31), when every treated positive count was
# 1 it was -14 (SE 335), and aliased count covariates were kept. Now the count
# rows get the same guards as InferenceCountHurdlePoisson (v1.0.6-TODO-186 and
# -195 (2) / (3)): see kk_hurdle_count_guard().

kk_hurdle_guard_design = function(y_fun, n = 40L, seed = 2L, x = NULL) {
	set.seed(seed)
	if (is.null(x)) x = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBinaryMatch$new(response_type = "count", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(x)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

kk_hurdle_guard_classes = c("InferenceCountKKHurdlePoissonIVWC", "InferenceCountKKHurdlePoissonOneLik")

test_that("kk_hurdle_count_guard decides from the rows that enter the count likelihood", {
	X = cbind(1, w = rep(c(1, 0), 4), x = c(0.1, 0.5, -0.3, 0.2, 0.9, -1, 0.4, -0.2))
	# matched rows only (IVWC matched component): every positive row treated
	g = kk_hurdle_count_guard(X, c(2, 0, 3, 0, 1, 0, 2, 0), 2L, matched_idx = 1:8)
	expect_identical(g$reason, "kk_hurdle_count_treatment_unidentified")
	# every treated positive count is 1
	g = kk_hurdle_count_guard(X, c(1, 2, 1, 3, 1, 2, 0, 1), 2L, matched_idx = 1:8)
	expect_identical(g$reason, "kk_hurdle_count_mle_not_finite")
	expect_equal(g$arms, 1)
	# a treated count of 2 makes the MLE finite
	g = kk_hurdle_count_guard(X, c(2, 2, 1, 3, 1, 2, 0, 1), 2L, matched_idx = 1:8)
	expect_null(g$reason)
	# OneLik with a reservoir: treated matched positives all 1 AND treated reservoir
	# counts all 0 -> infinite; one treated reservoir count > 0 bounds it
	g = kk_hurdle_count_guard(X, c(1, 2, 1, 3, 0, 2, 0, 1), 2L, matched_idx = 1:4, reservoir_idx = 5:8)
	expect_identical(g$reason, "kk_hurdle_count_mle_not_finite")
	g = kk_hurdle_count_guard(X, c(1, 2, 1, 3, 2, 2, 0, 1), 2L, matched_idx = 1:4, reservoir_idx = 5:8)
	expect_null(g$reason)
	# zero-weight rows do not count
	g = kk_hurdle_count_guard(X, c(2, 2, 1, 3, 1, 2, 0, 1), 2L, matched_idx = 1:8, weights = c(0, 1, 1, 1, 1, 1, 1, 1))
	expect_identical(g$reason, "kk_hurdle_count_mle_not_finite")
})

test_that("unidentified count-part treatment makes the KK hurdle classes NA, not an arbitrary estimate", {
	skip_if_not_installed("nbpMatching")
	des = kk_hurdle_guard_design(function(w) ifelse(w == 1, rpois(length(w), 2) * rbinom(length(w), 1, 0.7), 0))
	for (cls in kk_hurdle_guard_classes) {
		inf = get(cls)$new(des, verbose = FALSE)
		expect_true(is.na(suppressWarnings(inf$compute_estimate())), info = cls)
		expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason,
			"kk_hurdle_count_treatment_unidentified", info = cls)
	}
})

test_that("a treated arm whose positive counts are all 1 gives NA with a recorded reason and one warning", {
	skip_if_not_installed("nbpMatching")
	des = kk_hurdle_guard_design(function(w) {
		y = rpois(length(w), exp(0.5)) * rbinom(length(w), 1, 0.7)
		y[w == 1 & y > 0] = 1
		y
	})
	for (cls in kk_hurdle_guard_classes) {
		inf = get(cls)$new(des, verbose = FALSE)
		w = expect_warning(est <- inf$compute_estimate(), class = "edi_hurdle_count_mle_not_finite_warning")
		expect_s3_class(w, "edi_procedure_na_warning")
		expect_identical(w$reason, "kk_hurdle_count_mle_not_finite")
		expect_true(is.na(est), info = cls)
		expect_identical(inf$.__enclos_env__$private$cached_values$nonestimable_reason,
			"kk_hurdle_count_mle_not_finite", info = cls)
		# permuted assignments mix the 1s into both arms: replicates are finite and
		# respond to the assignment (no warm-start constant)
		set.seed(5)
		distr = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 12, show_progress = FALSE))
		expect_gt(sum(is.finite(distr)), 8L)
		expect_gt(sd(distr[is.finite(distr)]), 0.05)
	}
})

test_that("when every positive count is 1 every randomization replicate is NA too", {
	skip_if_not_installed("nbpMatching")
	des = kk_hurdle_guard_design(function(w) rbinom(length(w), 1, 0.5))
	for (cls in kk_hurdle_guard_classes) {
		inf = get(cls)$new(des, verbose = FALSE)
		expect_true(is.na(suppressWarnings(inf$compute_estimate(), classes = "edi_hurdle_count_mle_not_finite_warning")))
		set.seed(5)
		distr = suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(r = 8, show_progress = FALSE))
		expect_true(all(is.na(distr)), info = cls)
	}
})

test_that("a count covariate aliased on the positive matched rows is dropped, as glm does", {
	skip_if_not_installed("nbpMatching")
	set.seed(21)
	n = 40
	x1 = rnorm(n)
	x2 = rnorm(n)
	# positive counts only on rows 1..28, where x2 = 2 x1 + 1: x2 varies over the
	# sample but is aliased on the rows that determine the count part
	S = seq_len(28)
	x2[S] = 2 * x1[S] + 1
	des = kk_hurdle_guard_design(function(w) {
		y = numeric(length(w))
		y[S] = rpois(length(S), exp(0.5 + 0.4 * w[S] + 0.2 * x1[S])) * rbinom(length(S), 1, 0.8)
		y
	}, n = n, seed = 21, x = data.frame(x1 = x1, x2 = x2))
	for (cls in kk_hurdle_guard_classes) {
		inf = get(cls)$new(des, verbose = FALSE)
		expect_warning(est <- inf$compute_estimate(), class = "edi_covariate_dropped_warning")
		ref = suppressWarnings(get(cls)$new(des, model_formula = ~ x1, verbose = FALSE)$compute_estimate())
		expect_true(is.finite(est), info = cls)
		expect_equal(est, ref, tolerance = 1e-8, info = cls)
	}
})
