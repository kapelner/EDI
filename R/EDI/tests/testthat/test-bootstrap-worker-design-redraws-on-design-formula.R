# v1.0.6-TODO-130: the reusable bootstrap worker used to copy the INFERENCE's model-formula
# matrix into the worker design's private$X on full-rank draws, so covariate-aware redraws
# (greedy, rerandomization, Atkinson, KK21stepwise exact replay) balanced on the inference's
# columns instead of the design_formula's. On rank-deficient draws the worker inference also
# fell back to the design's matrix and fitted on the design's columns. The fast worker must
# match the slow bootstrap_subset_inference() path in both roles, and must be unchanged when
# the two formulas coincide.

make_fixed_design_for_worker_X_test = function(gen, X, y, ...) {
	d = gen$new(response_type = "continuous", n = nrow(X), ...)
	d$add_all_subjects_to_experiment(X)
	d$assign_w_to_all_subjects()
	d$add_all_subject_responses(y)
	d
}

make_seq_design_for_worker_X_test = function(gen, X, y, ...) {
	d = gen$new(n = nrow(X), response_type = "continuous", verbose = FALSE, ...)
	for (i in seq_len(nrow(X))) {
		d$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		d$add_one_subject_response(i, y[i])
	}
	d
}

worker_vs_slow_redraws = function(inf, B = 6L) {
	ip = inf$.__enclos_env__$private
	ws = ip$create_bootstrap_worker_state()
	n = ip$n
	out = list()
	for (b in seq_len(B)) {
		set.seed(100 + b)
		idx = sample.int(n, n, replace = TRUE)
		ip$load_bootstrap_sample_into_worker(ws, idx)
		wd = ws$worker$.__enclos_env__$private$des_obj
		wd$prepare_for_resampling_replay()
		set.seed(b)
		w_fast = as.numeric(wd$draw_ws_according_to_design(1L)[, 1L])
		sub_des = ip$bootstrap_subset_inference(list(i_b = idx, m_vec_b = NULL), smooth = FALSE)$.__enclos_env__$private$des_obj
		sub_des$prepare_for_resampling_replay()
		set.seed(b)
		w_slow = as.numeric(sub_des$draw_ws_according_to_design(1L)[, 1L])
		out[[b]] = list(fast = w_fast, slow = w_slow, des_X_cols = colnames(ws$worker_des_priv$X))
	}
	out
}

set.seed(1)
n_wx = 30
X_wx = data.frame(x1 = rnorm(n_wx), x2 = rnorm(n_wx), x3 = rnorm(n_wx))
y_wx = X_wx$x1 + rnorm(n_wx)

worker_X_designs = list(
	greedy = function() make_fixed_design_for_worker_X_test(DesignFixedGreedy, X_wx, y_wx, design_formula = ~ x2 + x3, n_iter = 30),
	rerand = function() make_fixed_design_for_worker_X_test(DesignFixedRerandomization, X_wx, y_wx, design_formula = ~ x2 + x3, prop_acceptable = 0.1),
	atkinson = function() make_seq_design_for_worker_X_test(DesignSeqOneByOneAtkinson, X_wx, y_wx, design_formula = ~ x2 + x3),
	kk21stepwise = function() make_seq_design_for_worker_X_test(DesignSeqOneByOneKK21stepwise, X_wx, y_wx,
		design_formula = ~ x2 + x3, condition_on_ws_for_rand_tests = FALSE)
)

for (des_name in names(worker_X_designs)) {
	test_that(paste0(des_name, ": worker design redraws on the design_formula matrix, matching the slow path"), {
		d = worker_X_designs[[des_name]]()
		inf = InferenceContinOLS$new(d, model_formula = ~ x1)
		draws = worker_vs_slow_redraws(inf)
		for (dr in draws) {
			expect_identical(dr$des_X_cols, c("x2", "x3"))
			expect_identical(dr$fast, dr$slow)
		}
	})
}

test_that("rank-deficient draw keeps the inference's model-formula columns", {
	set.seed(1)
	n = 30
	X = data.frame(x1 = c(1, rep(0, n - 1L)), x2 = rnorm(n), x3 = rnorm(n))
	y = X$x2 + rnorm(n)
	d = make_fixed_design_for_worker_X_test(DesignFixedGreedy, X, y, design_formula = ~ x2 + x3, n_iter = 30)
	inf = InferenceContinOLS$new(d, model_formula = ~ x1 + x2)
	ip = inf$.__enclos_env__$private
	ws = ip$create_bootstrap_worker_state()
	idx = c(2:n, 2L)  # drops the only x1 = 1 subject
	ip$load_bootstrap_sample_into_worker(ws, idx)
	expect_identical(colnames(ws$worker_priv$get_X()), c("x1", "x2"))
	slow = ip$bootstrap_subset_inference(list(i_b = idx, m_vec_b = NULL))
	expect_equal(ws$worker$compute_estimate(estimate_only = TRUE), slow$compute_estimate(estimate_only = TRUE))
})

test_that("coinciding formulas keep the shared-matrix worker path", {
	for (des_name in names(worker_X_designs)) {
		d = worker_X_designs[[des_name]]()
		inf = InferenceContinOLS$new(d)
		ws = inf$.__enclos_env__$private$create_bootstrap_worker_state()
		expect_null(ws[["base_des_X"]])
	}
})
