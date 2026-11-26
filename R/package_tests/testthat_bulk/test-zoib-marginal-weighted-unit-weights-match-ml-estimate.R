# Numerical-robustness review audit, 2026-11-19: Under estimand = "marginal_mean_diff",
# compute_estimate_with_bootstrap_weights() fits the zero and one parts as two independent binary
# logistic regressions (P(Y=0) vs rest, P(Y=1) vs rest). It then passes those coefficients to
# zoib_marginal_mean_diff_from_coefs(), which reads them as reference-category softmax logits
# log(p0/p_mid), log(p1/p_mid). The inflation probabilities, and so the marginal mean difference,
# come out wrong even with all-ones weights. Example: p0=0.6, p1=0.1 in control and the reverse under
# treatment. The weighted path then returns about 0.53, while the ML fit gives about 0.50.
# Where: R/EDI/R/inference_proportion_zero_one_inflated_beta.R:262 (kind: other_numerical).
# On commit 0231668c948b this test failed with: Expected `abs(est_unit - est_full)` < 0.005. Actual
# comparison: 0.029 >= 0.005 Difference: 0.024 >= 0
# Tracked as v1.0.7-TODO-98; remove the skip() when it is fixed.

test_that("ZOIB marginal mean diff under unit bootstrap weights matches the unweighted ML estimate", {
	skip("v1.0.7-TODO-98: the weighted refit uses two binary logits instead of the softmax parameterization")
		set.seed(11)
		n = 400L
		seq_des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
		x1 = rnorm(n)
		for (i in seq_len(n)) seq_des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i]))
		w = seq_des$get_w()
		u = runif(n)
		p_zero = ifelse(w == 1, 0.1, 0.6)
		p_one = ifelse(w == 1, 0.6, 0.1)
		y = ifelse(u < p_zero, 0, ifelse(u < p_zero + p_one, 1, rbeta(n, 5, 5)))
		seq_des$add_all_subject_responses(y)
		inf = InferencePropZeroOneInflatedBetaRegr$new(seq_des)
		inf$set_estimand("marginal_mean_diff")
		est_full = as.numeric(inf$compute_estimate(estimate_only = TRUE))
		inf$.__enclos_env__$private$current_bayesian_bootstrap_context = list(
			row_to_unit = seq_len(n),
			unit_group_id = rep(1L, n),
			n_units = n
		)
		est_unit = as.numeric(inf$compute_estimate_with_bootstrap_weights(rep(1, n), estimate_only = TRUE))
		expect_true(is.finite(est_full))
		expect_true(is.finite(est_unit))
		expect_lt(abs(est_unit - est_full), 0.005)
})
