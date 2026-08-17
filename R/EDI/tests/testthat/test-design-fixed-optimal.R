# TODO-9 tests (design_fixed_optimal.md): the DesignFixedOptimal class --
# construction validation, registry/capability integration (testing-plan
# item 5), the solve dispatch onto the TODO-5/6 solver layer, the mirror
# coin (testing-plan item 8), and the r = 1 draw contract. BRT end-to-end
# lives with TODO-8b's tests.

skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")

optimal_class_design = function(n = 10, seed = 42, ...){
	des = DesignFixedOptimal$new(n = n, response_type = "continuous", seed = seed, ...)
	set.seed(1000 + n)
	des$add_all_subjects_to_experiment(data.frame(
		x1 = rnorm(n), x2 = runif(n), x3 = rnorm(n, sd = 2)
	))
	des
}

test_that("registry and capability integration (deterministic_optimal family)", {
	md = EDI:::get_design_class_metadata("DesignFixedOptimal")
	expect_identical(md$randomization_family, "deterministic_optimal")
	expect_identical(md$timing_family, "fixed")
	expect_false(md$abstract)
	expect_true(md$seed_reproducible_draw)
	expect_false(md$supports_batch_w_pregeneration)
	expect_identical(md$required_packages, c("ompr", "ompr.roi", "ROI.plugin.glpk"))

	des = optimal_class_design()
	expect_false(des$supports_randomization_draw())
	expect_true(des$supports_resampling_replay())
	expect_true(des$supports_resampling())
})

test_that("assign_w_to_all_subjects installs the certified optimum (objective D) with full diagnostics", {
	des = optimal_class_design(objective = "D")
	des$assign_w_to_all_subjects()
	w = des$get_w()
	expect_identical(sum(w), 5)
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$solver, "ompr")
	expect_identical(diag$optimum_certificate, "global")
	expect_identical(diag$kind, "quadratic")
	expect_true(diag$mirror_feasible)

	# The installed allocation achieves the certified global optimum of w'Pw
	# (modulo the mirror, which ties by symmetry).
	priv = des$.__enclos_env__$private
	P = EDI:::build_optimal_design_P_H(priv$X[1:10, , drop = FALSE], interest = "all",
		prior_precision = NULL, standardize_covariates = TRUE, need_H = FALSE)$P
	exact = EDI:::milp_solve_quadratic(P, n_T = 5L)
	expect_equal(drop(t(w) %*% P %*% w), exact$objective_value, tolerance = 1e-9)
	expect_equal(diag$objective_value, exact$objective_value, tolerance = 1e-9)
})

test_that("the mirror coin flips: both labelings occur across seeds, none with mirror_coin = FALSE", {
	labels_coin = vapply(1:10, function(s){
		des = optimal_class_design(seed = s, objective = "abs_sum_diff")
		des$assign_w_to_all_subjects()
		expect_true(des$get_optimization_diagnostics()$mirror_tied)
		des$get_w()[1]
	}, numeric(1))
	expect_true(length(unique(labels_coin)) == 2L)

	labels_fixed = vapply(1:6, function(s){
		des = optimal_class_design(seed = s, objective = "abs_sum_diff", mirror_coin = FALSE)
		des$assign_w_to_all_subjects()
		expect_false(des$get_optimization_diagnostics()$mirror_feasible)
		des$get_w()[1]
	}, numeric(1))
	expect_identical(length(unique(labels_fixed)), 1L)
})

test_that("seed reproducibility includes the mirror coin", {
	des1 = optimal_class_design(seed = 7); des1$assign_w_to_all_subjects()
	des2 = optimal_class_design(seed = 7); des2$assign_w_to_all_subjects()
	expect_identical(des1$get_w(), des2$get_w())
	expect_identical(
		des1$get_optimization_diagnostics()$mirror_flipped,
		des2$get_optimization_diagnostics()$mirror_flipped
	)
})

test_that("mirror is infeasible at prob_T != 0.5", {
	des = optimal_class_design(seed = 3, prob_T = 0.3)
	des$assign_w_to_all_subjects()
	expect_identical(sum(des$get_w()), 3)
	expect_false(des$get_optimization_diagnostics()$mirror_feasible)
})

test_that("draw_ws_according_to_design honors the r = 1 contract and forbids r > 1", {
	des = optimal_class_design(seed = 11)
	w_mat = des$draw_ws_according_to_design(1L)
	expect_identical(dim(w_mat), c(10L, 1L))
	expect_identical(sum(w_mat), 5)
	expect_error(des$draw_ws_according_to_design(2L), "forbidden")
})

test_that("fencing: randomization test refused, model-based estimation available", {
	des = optimal_class_design(seed = 13)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(10))
	inf = EDI:::InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	expect_error(inf$compute_rand_two_sided_pval(r = 50), "no randomization mechanism")
	expect_true(is.finite(inf$compute_estimate()))
})

test_that("objective mahal_dist reaches the certified optimum; abs_sum_diff is always exact", {
	des = optimal_class_design(seed = 21, objective = "mahal_dist")
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$optimum_certificate, "global")
	priv = des$.__enclos_env__$private
	prep = EDI:::prepare_optimal_objective_matrices(priv$X[1:10, , drop = FALSE], "mahal_dist")
	exact = EDI:::milp_solve_quadratic(prep$Q, n_T = 5L)
	expect_equal(diag$objective_value, exact$objective_value, tolerance = 1e-9)

	des2 = optimal_class_design(seed = 22, objective = "abs_sum_diff")
	des2$assign_w_to_all_subjects()
	diag2 = des2$get_optimization_diagnostics()
	expect_identical(diag2$kind, "l1")
	expect_identical(diag2$optimum_certificate, "global")
})

test_that("solver = 'annealing' is honored; 'auto' past the cutoff falls back with a message", {
	des = optimal_class_design(seed = 31, solver = "annealing", solver_args = list(max_iter = 2000L))
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$solver, "annealing")
	expect_identical(diag$optimum_certificate, "annealing_converged")

	des2 = optimal_class_design(seed = 32,
		solver_args = list(linearization_max_n = 8L, max_iter = 2000L))
	expect_message(des2$assign_w_to_all_subjects(), "annealing")
	expect_identical(des2$get_optimization_diagnostics()$solver, "annealing")
})

test_that("objective A with interest 'all' routes through Dinkelbach to a global certificate", {
	des = optimal_class_design(seed = 41, objective = "A", interest = "all")
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$kind, "ratio")
	expect_identical(diag$optimum_certificate, "global")
	expect_true(diag$converged)
})

test_that("objective 'custom' runs end-to-end through the class", {
	skip_if_not_installed("RcppXPtrUtils")
	xptr = RcppXPtrUtils::cppXPtr(
		"double fobj(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) {
			Eigen::RowVectorXd mu = X.colwise().mean();
			Eigen::MatrixXd Xc = X.rowwise() - mu;
			Eigen::VectorXd s = 2.0 * w - Eigen::VectorXd::Ones(X.rows());
			return (Xc.transpose() * s).squaredNorm();
		}", depends = "RcppEigen")
	des = optimal_class_design(seed = 51, objective = "custom", custom_objective = xptr,
		solver_args = list(max_iter = 2000L, n_chains = 2L))
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_identical(diag$solver, "annealing")
	expect_identical(diag$kind, "custom")
	expect_identical(sum(des$get_w()), 5)
})

test_that("fencing: randomization CI is refused like the randomization test (testing-plan item 5)", {
	des = optimal_class_design(seed = 91)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(10))
	inf = EDI:::InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	expect_error(inf$compute_rand_confidence_interval(r = 50), "no randomization mechanism")
})

test_that("A/'all' labeling is objective-determined: the coin never fires (mirror not co-optimal)", {
	# The trace criterion over all parameters includes the intercept (the
	# control-group mean), so w* and 1 - w* are NOT tied and the labeling is
	# decided by the objective itself -- the verification must detect the
	# non-tie and skip the flip.
	des = optimal_class_design(seed = 92, objective = "A", interest = "all")
	des$assign_w_to_all_subjects()
	diag = des$get_optimization_diagnostics()
	expect_true(diag$mirror_feasible)   # prob_T = 0.5: the mirror is a legal allocation...
	expect_false(diag$mirror_tied)      # ...but not a co-optimum
	expect_false(diag$mirror_flipped)
})

test_that("quality baseline: annealing does not lose to blind greedy restarts in its necessary zone (testing-plan item 4)", {
	# Annealing's necessary zone is past the exact-solve cutoff; compare, on the
	# same data and D criterion, forced annealing against the best of n_chains
	# independent DesignFixedGreedyDOptimal greedy draws.
	n = 24
	set.seed(555)
	dat = data.frame(x1 = rnorm(n), x2 = runif(n), x3 = rnorm(n, sd = 2))
	ann_obj = numeric(3); greedy_obj = numeric(3)
	for (k in 1:3) {
		des_a = DesignFixedOptimal$new(n = n, response_type = "continuous", seed = 600 + k,
			objective = "D", solver = "annealing", solver_args = list(n_chains = 4L, max_iter = 5000L))
		des_a$add_all_subjects_to_experiment(dat)
		des_a$assign_w_to_all_subjects()
		ann_obj[k] = des_a$get_optimization_diagnostics()$objective_value

		des_g = DesignFixedGreedyDOptimal$new(n = n, response_type = "continuous", seed = 700 + k, objective = "D")
		des_g$add_all_subjects_to_experiment(dat)
		w_g = des_g$draw_ws_according_to_design(r = 4)
		P = des_g$.__enclos_env__$private$P
		greedy_obj[k] = min(apply(w_g, 2, function(w) drop(t(w) %*% P %*% w)))
	}
	expect_lte(mean(ann_obj), mean(greedy_obj) + 1e-9)
})

test_that("always-on construction validation", {
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous", objective = "Z"), "objective must be")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous", prob_T = 1.2), "prob_T")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "mahal_dist", interest = "all"), 'only meaningful for objective = "D"/"A"')
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "abs_sum_diff", prior_precision = 2), 'only meaningful for objective = "D"/"A"')
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "custom"), "custom_objective")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "D", custom_objective = "double f() { return 0; }"), 'objective = "custom"')
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous", solver = "cvxpy"), "solver must be")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		objective = "custom", custom_objective = "x", solver = "ompr"), "cannot be solved")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		solver_args = list(sim_anneal_temp = 5)), "Unknown solver_args")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous",
		solver_args = list(roi_solver = "cbc")), "roi_solver")
	expect_error(DesignFixedOptimal$new(n = 10, response_type = "continuous", mirror_coin = NA), "mirror_coin")
})
