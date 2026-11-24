# Untested-code audit, 2026-11-24: covers R/EDI/R/inference_all_abstract_rand.R:335-348
# (approximate_randomization_distribution_beta_hat_T; region unt-ae62b6fc7f4c).
# Reference: A plain-R treated-minus-control mean difference under each supplied permuted allocation
# (closed form), plus the documented debug-list contract (zero errors and prop_illegal_values = 0
# when every iteration succeeds).
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 13 of 13
# target lines (6.2 s).

library(testthat)
library(EDI)

test_that("debug randomization distribution without a reusable worker returns per-permutation mean differences and zero error counts", {
		CustomRand = getFromNamespace("InferenceCustomRand", "EDI")
		MeanDiffRand = R6::R6Class(
			"AuditDebugMeanDiffRand",
			inherit = CustomRand,
			lock_objects = FALSE,
			public = list(
				fit = function(estimate_only = FALSE) {
					dat = self$get_analysis_data()
					list(estimate = mean(dat$y[dat$w == 1]) - mean(dat$y[dat$w == 0]))
				}
			)
		)
		n = 20L
		r = 6L
		w = rep(c(0, 1), each = n / 2L)
		set.seed(20261124)
		y = round(rnorm(n) + w, 3)
		des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = rep(c(4, 1, 7, 2, 9, 3, 8, 5, 10, 6), 2)))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf = MeanDiffRand$new(des, verbose = FALSE)
		expect_false(isTRUE(inf$.__enclos_env__$private$use_reusable_bootstrap_worker()))
		set.seed(20261125)
		w_mat = vapply(seq_len(r), function(j) sample(w), numeric(n))
		out = inf$approximate_randomization_distribution_beta_hat_T(
			r = r,
			permutations = list(w_mat = w_mat),
			debug = TRUE,
			show_progress = FALSE
		)
		# Plain-R definition: the treated-minus-control mean under each permuted allocation (delta = 0).
		ref = apply(w_mat, 2, function(wp) mean(y[wp == 1]) - mean(y[wp == 0]))
		# Closed-form arithmetic on the same data: only floating-point rounding differs.
		expect_equal(as.numeric(out$values), as.numeric(ref), tolerance = 1e-12)
		expect_length(out$errors, r)
		expect_identical(as.integer(out$num_errors), rep(0L, r))
		expect_identical(out$prop_iterations_with_errors, 0)
		expect_identical(out$prop_illegal_values, 0)
})
