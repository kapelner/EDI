# Numerical-robustness review audit, 2026-11-18: With a binary ordinal response (K = 2, which the
# stereotype class accepts when there is a covariate), simulate_under_lik_null() indexes the loadings
# as params_null[(n_alpha + p + 1L):n_params]. That range runs downward, (p+2):(p+1), so gammas =
# c(NA, last beta). As a result phi[2] is NA, every simulated outcome is set to category 1, and the
# function returns NULL. Every parametric-bootstrap replicate fails, so
# compute_lik_ratio_bootstrap_two_sided_pval() returns NA even though the model (here just logistic
# regression) is well defined.
# Where: R/EDI/R/inference_ordinal_stereotype_logit.R:684 (kind: na_where_defined).
# On commit 4ce2b7126d36 this test failed with: Expected `is.null(boot)` to be FALSE. Differences:
# `actual`: TRUE `expected`: FALSE
# Remove the skip() once a release TODO covers this finding, and cite that TODO here
# (v<version>-TODO-<n>).

test_that("stereotype logit parametric LR bootstrap simulates a binary (K = 2) response", {
	skip("open a release TODO for this")
		set.seed(1)
		n = 200L
		x = rnorm(n)
		des = DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = x))
		des$assign_w_to_all_subjects()
		w = des$get_w()
		y = as.integer(0.5 * w + 0.8 * x + rlogis(n) > 0) + 1L
		des$add_all_subject_responses(y)
		inf = InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~x, verbose = FALSE)
		est = inf$compute_estimate()
		expect_true(is.finite(est))
		priv = inf$.__enclos_env__$private
		spec = priv$get_likelihood_test_spec()
		expect_false(is.null(spec))
		null_fit = spec$fit_null(0)
		expect_false(is.null(null_fit))
		set.seed(2)
		boot = priv$simulate_under_lik_null(spec, 0, null_fit)
		# a binary logistic null (phi_2 = 1) simulates both categories at n = 200
		expect_false(is.null(boot))
		inf$set_seed(3)
		pval = inf$compute_lik_ratio_bootstrap_two_sided_pval(delta = 0, B = 19, show_progress = FALSE)
		expect_true(is.finite(pval))
})
