# v1.0.6-TODO-100: the Bayesian-bootstrap studentized interval/p-value was NA for
# InferenceOrdinalGCompMeanDiff (its weighted refit had no SE, and its own cache restore hid any
# SE from run_isolated_weighted_refit) and for InferenceIncidKKGCompRiskDiff/RiskRatio (the
# weighted refit set s_beta_hat_T = NA and a full fit never set it). The weighted refits now
# return a weighted delta-method SE: weighted inverse information (ordinal) and a weighted
# KK-pair cluster sandwich (KK). Unit weights must reproduce the unweighted SE.

gcomp_weighted_se_kk_design = function(n = 60L, seed = 2L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w + 0.4 * X$x1)))
	des
}

gcomp_weighted_se_ordinal_design = function(n = 60L, seed = 2L){
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(response_type = "ordinal", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(pmin(pmax(round(2.5 + 0.8 * w + X$x1 + rnorm(n)), 1), 5))
	des
}

gcomp_weighted_se_cases = list(
	list(cls = "InferenceIncidKKGCompRiskDiff", make = gcomp_weighted_se_kk_design),
	list(cls = "InferenceIncidKKGCompRiskRatio", make = gcomp_weighted_se_kk_design),
	list(cls = "InferenceOrdinalGCompMeanDiff", make = gcomp_weighted_se_ordinal_design)
)

test_that("a full fit mirrors the standard error into s_beta_hat_T", {
	for (cs in gcomp_weighted_se_cases) {
		inf = get(cs$cls)$new(cs$make(), verbose = FALSE)
		priv = inf$.__enclos_env__$private
		se = if (is.function(inf$get_standard_error)) inf$get_standard_error() else priv$get_standard_error()
		expect_true(is.finite(se) && se > 0, info = cs$cls)
		expect_identical(priv$cached_values$s_beta_hat_T, se, info = cs$cls)
	}
})

test_that("the weighted refit's standard error equals the unweighted one at unit weights and ignores weight scale", {
	for (cs in gcomp_weighted_se_cases) {
		inf = get(cs$cls)$new(cs$make(), verbose = FALSE)
		priv = inf$.__enclos_env__$private
		se = if (is.function(inf$get_standard_error)) inf$get_standard_error() else priv$get_standard_error()
		priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context()
		n_units = priv$current_bayesian_bootstrap_context$n_units
		inf$compute_estimate_with_bootstrap_weights(rep(1, n_units), estimate_only = FALSE)
		expect_equal(priv$weighted_refit_se(), se, tolerance = 1e-4, info = cs$cls)
		inf$compute_estimate_with_bootstrap_weights(rep(3.7, n_units), estimate_only = FALSE)
		expect_equal(priv$weighted_refit_se(), se, tolerance = 1e-4, info = cs$cls)
		set.seed(9)
		g = stats::rgamma(n_units, 1)
		est_se = inf$compute_estimate_with_bootstrap_weights(g, estimate_only = FALSE)
		se_g = priv$weighted_refit_se()
		expect_true(is.finite(se_g) && se_g > 0, info = cs$cls)
		# The SE never changes the weighted point estimate.
		est_only = inf$compute_estimate_with_bootstrap_weights(g, estimate_only = TRUE)
		expect_equal(est_only, est_se, tolerance = 1e-8, info = cs$cls)
		expect_true(is.na(priv$weighted_refit_se()), info = cs$cls)
		# The weighted refit must not leak into the unweighted cache.
		expect_identical(priv$cached_values$s_beta_hat_T, se, info = cs$cls)
	}
})

test_that("the KK weighted cluster sandwich reproduces the unweighted cluster-robust SE at unit weights", {
	# Constant weights take a shortcut in compute_estimate_with_bootstrap_weights(), so call the
	# weighted fit directly.
	for (cs in gcomp_weighted_se_cases[1:2]) {
		inf = get(cs$cls)$new(cs$make(), verbose = FALSE)
		priv = inf$.__enclos_env__$private
		se = inf$get_standard_error()
		n = length(priv$y)
		est1 = priv$compute_weighted_gcomp_estimate(rep(1, n), with_se = TRUE)
		expect_equal(attr(est1, "se"), se, tolerance = 1e-5, info = cs$cls)
		est2 = priv$compute_weighted_gcomp_estimate(rep(2.5, n), with_se = TRUE)
		expect_equal(attr(est2, "se"), se, tolerance = 1e-5, info = cs$cls)
		# Without with_se the return value is the bare estimate (no attribute).
		expect_null(attributes(priv$compute_weighted_gcomp_estimate(rep(1, n))))
	}
})

test_that("the KK weighted cluster meat is linear in a cluster-constant weight", {
	set.seed(4)
	X = cbind(1, rbinom(20, 1, 0.5), rnorm(20))
	y = rbinom(20, 1, 0.5)
	b = c(-0.2, 0.5, 0.3)
	cl = rep(1:10, each = 2)
	# A pair-bootstrap draw that takes cluster 1 twice and cluster 10 never, as weights (2, 0)
	# must equal the same draw as duplicated rows (the copy is its own cluster).
	w = rep(1, 20); w[cl == 1] = 2; w[cl == 10] = 0
	v_w = EDI:::gcomp_weighted_logistic_cluster_sandwich_vcov(X, y, b, w, cl)
	dup = c(which(cl != 10), which(cl == 1))
	cl_dup = c(cl[cl != 10], c(11L, 11L))
	v_dup = EDI:::gcomp_weighted_logistic_cluster_sandwich_vcov(X[dup, ], y[dup], b, rep(1, 20), cl_dup)
	expect_equal(unname(v_w), unname(v_dup), tolerance = 1e-10)
})

test_that("the studentized Bayesian bootstrap interval is finite", {
	for (cs in gcomp_weighted_se_cases) {
		inf = get(cs$cls)$new(cs$make(), verbose = FALSE)
		inf$set_seed(3)
		ci = inf$compute_bayesian_bootstrap_confidence_interval(B = 51, type = "studentized", show_progress = FALSE)
		expect_true(all(is.finite(ci)), info = cs$cls)
		expect_lt(ci[1L], ci[2L])
	}
})
