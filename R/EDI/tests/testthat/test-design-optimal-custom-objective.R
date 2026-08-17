# TODO-7 tests (design_fixed_optimal.md): the custom_objective XPtr plumbing
# for DesignFixedOptimal -- the src/custom_objective.h calling convention
# (double f(const Eigen::MatrixXd& X, const Eigen::VectorXd& w)), XPtr-only
# validation (an R closure is rejected with the performance reason, per
# TODO-2), the annealing-solver integration ("custom" is always annealing --
# no structure to linearize), and the eval helper that lets R code (auto
# temperature calibration, tests) evaluate the compiled objective.

skip_if_not_installed("RcppXPtrUtils")

# Re-implements the greedy kernel's abs_sum_diff criterion under the
# custom_objective calling convention, so the custom path must reproduce the
# built-in objective's optimum (testing-plan item 3).
custom_abs_sum_diff_xptr = local({
	cached = NULL
	function(){
		if (is.null(cached)) {
			cached <<- RcppXPtrUtils::cppXPtr(
				"double custom_abs_sum_diff(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) {
					const int n = X.rows(), p = X.cols();
					Eigen::RowVectorXd mu = X.colwise().mean();
					Eigen::MatrixXd Xc = X.rowwise() - mu;
					Eigen::VectorXd s = 2.0 * w - Eigen::VectorXd::Ones(n);
					double f = 0.0;
					for (int j = 0; j < p; j++) {
						double var = Xc.col(j).squaredNorm() / std::max(1, n - 1);
						double inv_sd = (var < 1e-24) ? 1.0 : 1.0 / std::sqrt(var);
						f += std::abs(Xc.col(j).dot(s) * inv_sd / n);
					}
					return f;
				}",
				depends = "RcppEigen"
			)
		}
		cached
	}
})

custom_test_X = function(n, p, seed){
	set.seed(seed)
	matrix(rnorm(n * p), n, p, dimnames = list(NULL, paste0("x", 1:p)))
}

test_that("eval_custom_design_objective_cpp evaluates the XPtr against an R reference", {
	X = custom_test_X(10, 3, 301)
	w = c(rep(1, 5), rep(0, 5))
	got = EDI:::eval_custom_design_objective_cpp(custom_abs_sum_diff_xptr(), X, w)
	prep = EDI:::prepare_optimal_objective_matrices(X, "abs_sum_diff")
	expect_equal(got, sum(abs(prep$A %*% w)), tolerance = 1e-12)
})

test_that("assert_custom_objective_xptr rejects everything but a compiled XPtr, naming the performance reason", {
	a = EDI:::assert_custom_objective_xptr
	expect_silent(a(custom_abs_sum_diff_xptr()))
	expect_error(a(NULL), "custom_objective")
	expect_error(a(function(X, w) sum(w)), "compiled")
	# The refusal must explain WHY an R closure is disallowed (TODO-2), not just reject it.
	expect_error(a(function(X, w) sum(w)), "per candidate|per-candidate|orders of magnitude")
	expect_error(a(42), "custom_objective")
})

test_that("annealing_solve_custom reproduces the built-in abs_sum_diff optimum", {
	X = custom_test_X(10, 3, 302)
	prep = EDI:::prepare_optimal_objective_matrices(X, "abs_sum_diff")
	exact = EDI:::milp_solve_l1(prep$A, n_T = 5L)
	set.seed(13)
	res = EDI:::annealing_solve_custom(X, custom_abs_sum_diff_xptr(), n_T = 5L,
		n_chains = 6L, max_iter = 4000L)
	expect_identical(sum(res$w), 5)
	expect_true(all(res$w %in% c(0, 1)))
	expect_identical(res$certificate, "annealing_converged")
	# The reported objective must match a from-scratch eval of the returned w...
	expect_equal(res$objective_value,
		EDI:::eval_custom_design_objective_cpp(custom_abs_sum_diff_xptr(), X, res$w),
		tolerance = 1e-9)
	# ...and land on the certified optimum of the equivalent built-in objective.
	expect_lte(res$objective_value, exact$objective_value + 1e-6)
})

test_that("annealing_solve_custom is seed-deterministic", {
	X = custom_test_X(12, 2, 303)
	set.seed(14)
	res1 = EDI:::annealing_solve_custom(X, custom_abs_sum_diff_xptr(), n_T = 6L, n_chains = 2L, max_iter = 1500L)
	set.seed(14)
	res2 = EDI:::annealing_solve_custom(X, custom_abs_sum_diff_xptr(), n_T = 6L, n_chains = 2L, max_iter = 1500L)
	expect_identical(res1$w, res2$w)
	expect_identical(res1$objective_value, res2$objective_value)
})

test_that("annealing_solve_custom also accepts a C++ source string, via the same shared normalizer", {
	X = custom_test_X(10, 2, 305)
	src = "double f_src(const Eigen::MatrixXd& X, const Eigen::VectorXd& w) {
		Eigen::RowVectorXd mu = X.colwise().mean();
		Eigen::MatrixXd Xc = X.rowwise() - mu;
		Eigen::VectorXd s = 2.0 * w - Eigen::VectorXd::Ones(X.rows());
		return (Xc.transpose() * s).squaredNorm();
	}"
	set.seed(16)
	res = EDI:::annealing_solve_custom(X, src, n_T = 5L, n_chains = 2L, max_iter = 1500L)
	expect_identical(sum(res$w), 5)
	expect_identical(res$certificate, "annealing_converged")
})

test_that("a wrong-signature XPtr is refused by the shared calling-convention check", {
	wrong_sig = RcppXPtrUtils::cppXPtr(
		"double f_wrong(const Eigen::VectorXd& y, const Eigen::VectorXd& w) { return y.sum() + w.sum(); }",
		depends = "RcppEigen"
	)
	expect_error(EDI:::assert_custom_objective_xptr(wrong_sig), "calling convention")
})

test_that("custom randomization statistic: XPtr form is uniform with the legacy source-string form", {
	# The same mean-difference statistic supplied both ways must yield the
	# identical randomization p-value under the same seed.
	set.seed(400)
	des = DesignFixediBCRD$new(n = 14, response_type = "continuous", seed = 17)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(14)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(14))

	stat_xptr = RcppXPtrUtils::cppXPtr(
		"double stat_eigen(const Eigen::VectorXd& y, const Eigen::VectorXd& w) {
			double sw = w.sum();
			return y.dot(w) / sw - (y.sum() - y.dot(w)) / (y.size() - sw);
		}",
		depends = "RcppEigen"
	)
	stat_src = "double stat_rcpp(NumericVector y, IntegerVector w) {
		double s1 = 0, s0 = 0; int n1 = 0, n0 = 0;
		for (int i = 0; i < y.size(); i++) {
			if (w[i] == 1) { s1 += y[i]; n1++; } else { s0 += y[i]; n0++; }
		}
		return s1 / n1 - s0 / n0;
	}"

	inf1 = EDI:::InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	inf1$set_custom_randomization_statistic_cpp(stat_xptr)
	set.seed(18)
	p_xptr = inf1$compute_rand_two_sided_pval(r = 100, show_progress = FALSE)

	inf2 = EDI:::InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	inf2$set_custom_randomization_statistic_cpp(stat_src)
	set.seed(18)
	p_src = inf2$compute_rand_two_sided_pval(r = 100, show_progress = FALSE)

	expect_equal(p_xptr, p_src, tolerance = 1e-12)
})

test_that("custom randomization statistic: bare externalptrs without cppXPtr's signature are refused", {
	set.seed(401)
	des = DesignFixediBCRD$new(n = 8, response_type = "continuous", seed = 19)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(8)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(8))
	inf = EDI:::InferenceAllSimpleMeanDiff$new(des, verbose = FALSE)
	bare = custom_abs_sum_diff_xptr()
	attributes(bare) = NULL
	expect_error(inf$set_custom_randomization_statistic_cpp(bare), "RcppXPtrUtils::cppXPtr")
})

test_that("optimal_solve_auto: custom always uses annealing, even at tiny n", {
	X = custom_test_X(8, 2, 304)
	set.seed(15)
	res = EDI:::optimal_solve_auto(kind = "custom", X = X,
		custom_objective = custom_abs_sum_diff_xptr(), n_T = 4L, max_iter = 1000L)
	expect_identical(res$solver, "annealing")
	expect_identical(res$certificate, "annealing_converged")
	expect_identical(sum(res$w), 4)
})
