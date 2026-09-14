library(testthat)
library(EDI)

make_rand_custom_design = function(n = 20, seed = 20260913){
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = seq_len(n)))
	des$overwrite_all_subject_assignments(rep(c(0, 1), each = n / 2))
	des$add_all_subject_responses(c(seq_len(n / 2), seq_len(n / 2) + 2))
	des
}

welch_t_stat_src = "
double welch_t_stat(NumericVector y, IntegerVector w) {
	int n = y.size();
	double sum_t = 0, sum_c = 0;
	int n_t = 0, n_c = 0;
	for (int i = 0; i < n; i++) {
		if (w[i] == 1) { sum_t += y[i]; n_t++; }
		else           { sum_c += y[i]; n_c++; }
	}
	double mean_t = sum_t / n_t;
	double mean_c = sum_c / n_c;
	double var_t = 0, var_c = 0;
	for (int i = 0; i < n; i++) {
		if (w[i] == 1) { double d = y[i] - mean_t; var_t += d * d; }
		else           { double d = y[i] - mean_c; var_c += d * d; }
	}
	var_t /= (n_t - 1);
	var_c /= (n_c - 1);
	return (mean_t - mean_c) / sqrt(var_t / n_t + var_c / n_c);
}
"

welch_t_stat_r = function(y, w, dead){
	y_t = y[w == 1]; y_c = y[w == 0]
	(mean(y_t) - mean(y_c)) / sqrt(var(y_t) / length(y_t) + var(y_c) / length(y_c))
}

test_that("InferenceRandCustom requires exactly one of function or cpp", {
	des = make_rand_custom_design()
	expect_error(InferenceRandCustom$new(des), "requires custom_randomization_statistic_function")
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_function = welch_t_stat_r, custom_randomization_statistic_cpp = welch_t_stat_src),
		"not both"
	)
})

test_that("InferenceRandCustom: R-function branch computes estimate, p-value, and CI", {
	des = make_rand_custom_design()
	inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = welch_t_stat_r, verbose = FALSE)
	expect_equal(inf$compute_estimate(), welch_t_stat_r(des$get_y(), des$get_w(), NULL))
	set.seed(1)
	pval = inf$compute_rand_two_sided_pval(r = 199, show_progress = FALSE)
	expect_true(is.finite(pval) && pval >= 0 && pval <= 1)
	ci = inf$compute_rand_confidence_interval(r = 199, show_progress = FALSE)
	expect_length(ci, 2)
	expect_true(all(is.finite(ci)))
	expect_lt(ci[1], ci[2])
})

test_that("InferenceRandCustom: cpp source-string branch matches R-function branch under the same permutations", {
	des = make_rand_custom_design()
	inf_r = InferenceRandCustom$new(des, custom_randomization_statistic_function = welch_t_stat_r, verbose = FALSE)
	inf_cpp = InferenceRandCustom$new(des, custom_randomization_statistic_cpp = welch_t_stat_src, verbose = FALSE)
	expect_equal(inf_r$compute_estimate(), inf_cpp$compute_estimate())
	perms = list(w_mat = replicate(101, sample(des$get_w())))
	p_r = inf_r$compute_rand_two_sided_pval(r = 101, permutations = perms, show_progress = FALSE)
	p_cpp = inf_cpp$compute_rand_two_sided_pval(r = 101, permutations = perms, show_progress = FALSE)
	expect_equal(p_r, p_cpp, tolerance = 1e-12)
})

test_that("InferenceRandCustom: precompiled Rcpp function and XPtr forms agree with the source-string form", {
	des = make_rand_custom_design()
	compiled = Rcpp::cppFunction(welch_t_stat_src)
	xptr = RcppXPtrUtils::cppXPtr(
		"double welch_t_stat_xptr(const Eigen::VectorXd& y, const Eigen::VectorXd& w) {
			double n_t = w.sum();
			double n_c = w.size() - n_t;
			double mean_t = y.dot(w) / n_t;
			double mean_c = (y.sum() - y.dot(w)) / n_c;
			Eigen::VectorXd dev_t = (y.array() - mean_t) * w.array();
			Eigen::VectorXd dev_c = (y.array() - mean_c) * (1 - w.array());
			double var_t = dev_t.squaredNorm() / (n_t - 1);
			double var_c = dev_c.squaredNorm() / (n_c - 1);
			return (mean_t - mean_c) / std::sqrt(var_t / n_t + var_c / n_c);
		}",
		depends = "RcppEigen"
	)
	inf_src = InferenceRandCustom$new(des, custom_randomization_statistic_cpp = welch_t_stat_src, verbose = FALSE)
	inf_fn = InferenceRandCustom$new(des, custom_randomization_statistic_cpp = compiled, verbose = FALSE)
	inf_xptr = InferenceRandCustom$new(des, custom_randomization_statistic_cpp = xptr, verbose = FALSE)
	expect_equal(inf_src$compute_estimate(), inf_fn$compute_estimate(), tolerance = 1e-12)
	expect_equal(inf_src$compute_estimate(), inf_xptr$compute_estimate(), tolerance = 1e-12)
	perms = list(w_mat = replicate(101, sample(des$get_w())))
	p_src = inf_src$compute_rand_two_sided_pval(r = 101, permutations = perms, show_progress = FALSE)
	p_xptr = inf_xptr$compute_rand_two_sided_pval(r = 101, permutations = perms, show_progress = FALSE)
	expect_equal(p_src, p_xptr, tolerance = 1e-12)
})

test_that("InferenceRandCustom: cpp arity and bare-externalptr validation errors match the documented contract", {
	des = make_rand_custom_design()
	bad_arity_src = "double f(NumericVector y) { return 0.0; }"
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = bad_arity_src, verbose = FALSE),
		"2 arguments"
	)
	bare = RcppXPtrUtils::cppXPtr(
		"double f_bare(const Eigen::VectorXd& y, const Eigen::VectorXd& w) { return y.sum() + w.sum(); }",
		depends = "RcppEigen"
	)
	attributes(bare) = NULL
	expect_error(
		InferenceRandCustom$new(des, custom_randomization_statistic_cpp = bare, verbose = FALSE),
		"RcppXPtrUtils::cppXPtr"
	)
})

test_that("InferenceRandCustom: duplicate() clones the custom statistic correctly", {
	des = make_rand_custom_design()
	inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = welch_t_stat_r, verbose = FALSE)
	cloned = inf$duplicate()
	expect_s3_class(cloned, "InferenceRandCustom")
	expect_equal(cloned$compute_estimate(), inf$compute_estimate())
	set.seed(2)
	p_orig = inf$compute_rand_two_sided_pval(r = 101, show_progress = FALSE)
	set.seed(2)
	p_clone = cloned$compute_rand_two_sided_pval(r = 101, show_progress = FALSE)
	expect_equal(p_orig, p_clone)
})

test_that("InferenceRandCustom: only randomization test/CI capabilities are exposed", {
	des = make_rand_custom_design()
	inf = InferenceRandCustom$new(des, custom_randomization_statistic_function = welch_t_stat_r, verbose = FALSE)
	caps = inf$capabilities()
	expect_true(all(c("randomization_test", "randomization_ci") %in% caps))
	expect_false(any(c("wald", "nonparametric_bootstrap", "randomization_bootstrap", "bayesian_bootstrap", "jackknife") %in% caps))
})
