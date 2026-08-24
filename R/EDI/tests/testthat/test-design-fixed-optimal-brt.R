# TODO-8b tests (design_fixed_optimal.md): BRT wiring for DesignFixedOptimal
# -- the prepare_for_resampling_replay() hook, the reduced per-replicate
# solver profile (solver_args$brt_solver/brt_max_iter/brt_n_chains), and the
# testing-plan item 7 end-to-end checks: the BRT runs, per-replicate w*_b
# varies beyond mere mirroring, and results are seed-deterministic.

skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")

brt_optimal_design = function(n = 20, seed = 60, ...){
	des = DesignFixedOptimal$new(n = n, response_type = "continuous", seed = seed,
		objective = "mahal_dist", ...)
	set.seed(2000 + n)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	des
}

test_that("prepare_for_resampling_replay is a harmless no-op on ordinary designs", {
	des = DesignFixediBCRD$new(n = 8, response_type = "continuous", seed = 1)
	expect_invisible(des$prepare_for_resampling_replay())
})

test_that("the replicate profile switches solves to reduced annealing (default) or exact ompr (opt-in)", {
	skip_on_cran()
	des = brt_optimal_design(n = 12, seed = 61, solver_args = list(brt_max_iter = 500L))
	des$prepare_for_resampling_replay()
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$solver_profile, "brt_replicate")
	expect_identical(diag$solver, "annealing")
	expect_identical(diag$optimum_certificate, "annealing_converged")
	expect_identical(diag$n_chains, 1L)
	expect_identical(diag$max_iter, 500L)

	des2 = brt_optimal_design(n = 12, seed = 62, solver_args = list(brt_solver = "ompr"))
	des2$prepare_for_resampling_replay()
	des2$assign_w_to_all_subjects()
	diag2 = des2$get_optimization_diagnostics()
	expect_identical(diag2$solver_profile, "brt_replicate")
	expect_identical(diag2$solver, "ompr")
	expect_identical(diag2$optimum_certificate, "global")
})

test_that("without the hook, solves stay on the main profile", {
	des = brt_optimal_design(n = 12, seed = 63)
	des$assign_w_to_all_subjects()
	expect_identical(des$get_optimization_diagnostics()$solver_profile, "main")
})

test_that("BRT end-to-end: p-value computes, is valid, and is seed-deterministic", {
	skip_on_cran()
	des = brt_optimal_design(seed = 64, solver_args = list(brt_max_iter = 400L))
	des$assign_w_to_all_subjects()
	set.seed(70)
	des$add_all_subject_responses(rnorm(20))

	inf1 = EDI:::InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(71)
	p1 = inf1$compute_rand_bootstrap_two_sided_pval(B = 30, show_progress = FALSE)
	expect_true(is.finite(p1) && p1 >= 0 && p1 <= 1)

	inf2 = EDI:::InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(71)
	p2 = inf2$compute_rand_bootstrap_two_sided_pval(B = 30, show_progress = FALSE)
	expect_identical(p1, p2)
})

test_that("per-replicate w*_b varies beyond mere mirroring (testing-plan item 7)", {
	skip_on_cran()
	des = brt_optimal_design(seed = 65, solver_args = list(brt_max_iter = 400L))
	des$assign_w_to_all_subjects()
	set.seed(72)
	des$add_all_subject_responses(rnorm(20))
	inf = EDI:::InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(73)
	draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(B = 12, materialize_w = TRUE)
	w_mat = do.call(cbind, lapply(draws, `[[`, "w_b"))
	expect_identical(nrow(w_mat), 20L)
	expect_gte(ncol(w_mat), 10L)
	# Canonicalize modulo the mirror: flip any column whose first entry is 0,
	# then require more than one distinct canonical allocation.
	canon = apply(w_mat, 2, function(w) if (w[1] == 0) 1 - w else w)
	expect_gt(length(unique(apply(canon, 2, paste, collapse = ""))), 1L)
	# And every replicate's allocation is a genuine exact-n_T assignment.
	expect_true(all(colSums(w_mat) == 10))
})

test_that("spot-check: a replicate assignment is reproduced by re-optimizing that replicate's resampled covariates", {
	skip_on_cran()
	des = brt_optimal_design(seed = 66, solver_args = list(brt_solver = "ompr"))
	des$assign_w_to_all_subjects()
	set.seed(74)
	des$add_all_subject_responses(rnorm(20))
	inf = EDI:::InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(75)
	draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(B = 3, materialize_w = TRUE)
	draw = draws[[1]]
	# Rebuild the resampled model matrix and solve it exactly: the replicate's
	# w_b must achieve the same certified objective value (modulo the mirror).
	X_full = des$.__enclos_env__$private$X[1:20, , drop = FALSE]
	X_b = X_full[draw$i_b, , drop = FALSE]
	prep = EDI:::prepare_optimal_objective_matrices(X_b, "mahal_dist")
	f = function(w) if (identical(prep$kind, "quadratic")) drop(t(w) %*% prep$Q %*% w) else sum(abs(prep$A %*% w))
	exact = if (identical(prep$kind, "quadratic")) {
		EDI:::milp_solve_quadratic(prep$Q, n_T = 10L)
	} else {
		EDI:::milp_solve_l1(prep$A, n_T = 10L)
	}
	expect_equal(f(draw$w_b), exact$objective_value, tolerance = 1e-8)
})

test_that("brt_solver validation", {
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		solver_args = list(brt_solver = "greedy")), "brt_solver")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "custom", custom_objective = "double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) { return w.sum(); }",
		solver_args = list(brt_solver = "ompr")), "cannot use")
})
