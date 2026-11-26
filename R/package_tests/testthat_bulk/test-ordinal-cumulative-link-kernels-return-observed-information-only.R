# v1.0.6-TODO-156 item (2): the four cumulative-link ordinal kernels (logit,
# probit, cauchit, cloglog) used to return the observed Hessian under the name
# `fisher_information` as well as `observed_information` / `information`. The
# expected (Fisher) information is computed in R
# (ordinal_cumlink_expected_information(), v1.0.6-TODO-142), so the misleading
# field is gone: the kernels return the observed information only, and every R
# caller that fed it to the next fit's warm start reads `observed_information`.
# The kernel assertions need the rebuilt EDI.so (PATCHED, needs owner build);
# the class-level warm-start checks pass on either build.
library(testthat)
library(EDI)

ordinal_obs_only_data = function(n = 80L, seed = 21L){
	set.seed(seed)
	w = rep(0:1, length.out = n)
	x = rnorm(n)
	z = 0.6 * w + 0.5 * x + rlogis(n)
	list(X = cbind(treatment = w, x = x), y = as.numeric(cut(z, c(-Inf, -0.5, 0.5, 1.5, Inf), labels = FALSE)) - 1)
}

ordinal_obs_only_kernels = list(
	logit = list(fit = "fast_ordinal_regression_cpp", with_var = "fast_ordinal_regression_with_var_cpp",
		hessian = "get_ordinal_regression_hessian_cpp"),
	probit = list(fit = "fast_ordinal_probit_regression_cpp", with_var = "fast_ordinal_probit_regression_with_var_cpp",
		hessian = "get_ordinal_probit_regression_hessian_cpp"),
	cauchit = list(fit = "fast_ordinal_cauchit_regression_cpp", with_var = "fast_ordinal_cauchit_regression_with_var_cpp",
		hessian = "get_ordinal_cauchit_regression_hessian_cpp"),
	cloglog = list(fit = "fast_ordinal_cloglog_regression_cpp", with_var = "fast_ordinal_cloglog_regression_with_var_cpp",
		hessian = "get_ordinal_cloglog_regression_hessian_cpp")
)

ordinal_obs_only_fn = function(nm) get(nm, envir = asNamespace("EDI"))

ordinal_obs_only_expect = function(r, X, y, hessian_fn, info){
	expect_false("fisher_information" %in% names(r), info = info)
	expect_identical(r$information_type, "observed", info = info)
	expect_identical(r$information, r$observed_information, info = info)
	H = -hessian_fn(X, y, as.numeric(r$params))
	expect_lt(max(abs(H - r$observed_information)) / max(abs(H)), 1e-8)
}

test_that("cumulative-link kernels return the observed information and no fisher_information field", {
	d = ordinal_obs_only_data()
	for (link in names(ordinal_obs_only_kernels)) {
		k = ordinal_obs_only_kernels[[link]]
		hessian_fn = ordinal_obs_only_fn(k$hessian)
		ordinal_obs_only_expect(ordinal_obs_only_fn(k$fit)(d$X, d$y), d$X, d$y, hessian_fn, paste(link, "fit"))
		ordinal_obs_only_expect(ordinal_obs_only_fn(k$with_var)(d$X, d$y), d$X, d$y, hessian_fn, paste(link, "with_var"))
	}
	rw = fast_ordinal_regression_weighted_cpp(d$X, d$y, weights = rep(1, nrow(d$X)))
	ordinal_obs_only_expect(rw, d$X, d$y, get_ordinal_regression_hessian_cpp, "logit weighted")
})

test_that("the observed information still reaches the warm start of every cumulative-link class", {
	set.seed(4)
	n = 60L
	X = data.frame(x1 = rnorm(n))
	des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(as.numeric(cut(0.7 * w + 0.6 * X$x1 + rlogis(n), c(-Inf, -1, 0, 1, Inf), labels = FALSE)))
	n_params = 2L + 3L
	expect_warm_fisher = function(priv, info){
		fisher = priv$get_fit_warm_start_fisher(n_params)
		expect_true(is.matrix(fisher) && all(dim(fisher) == n_params) && all(is.finite(fisher)), info = info)
	}
	# generate_mod() stores the full-fit params and information; the shared
	# StandardModelCache step then replaces that warm start with the reported
	# coefficient pair, so look right after generate_mod().
	for (cls in c("InferenceOrdinalPropOddsRegr", "InferenceOrdinalOrderedProbitRegr",
			"InferenceOrdinalCauchitRegr", "InferenceOrdinalCloglogRegr")) {
		priv = get(cls)$new(des, verbose = FALSE)$.__enclos_env__$private
		expect_false(is.null(priv$generate_mod(estimate_only = FALSE)), info = cls)
		expect_warm_fisher(priv, cls)
	}
	inf = InferenceOrdinalPartialProportionalOddsRegr$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_asymp_two_sided_pval()))
	expect_warm_fisher(inf$.__enclos_env__$private, "PartialPO")
	inf = InferenceOrdinalGCompMeanDiff$new(des, verbose = FALSE)
	expect_true(is.finite(inf$compute_estimate(estimate_only = TRUE)))
	expect_warm_fisher(inf$.__enclos_env__$private, "GComp")
})
