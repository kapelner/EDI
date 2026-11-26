# Numerical-robustness review audit, 2026-11-17:
# compute_treatment_estimate_during_randomization_inference() returns res$b[2] from
# fast_identity_binomial_regression_cpp without checking res$converged or feasibility. When the warm
# start chained from the previous permutation is infeasible for the current assignment (or the warm
# Fisher is stale, the failure documented at the TODO-177 comment in fit_null), the kernel rejects
# every line-search step and returns its start with converged = FALSE. The method then reports that
# start's treatment coefficient (e.g. 0, or the previous replicate's estimate) as the randomization
# estimate.
# Where: R/EDI/R/inference_incidence_binomial_identity.R:172 (kind: converged_unchecked).
# On commit 48765322fe90 this test failed with: Expected `is.na(est) || abs(est - ref) < 0.001` to be
# TRUE. Differences: `actual`: FALSE `expected`: TRUE
# v1.0.6-TODO-146 fixed this: the method now returns compute_estimate(estimate_only = TRUE), whose
# fit refits cold when the warm-started fit stalls and rejects a non-converged fit.

test_that("identity-binomial randomization refit does not return a non-converged warm start as the estimate", {
		set.seed(11)
		n = 40
		des = DesignFixedBernoulli$new(n = n, response_type = "incidence")
		des$add_all_subjects_to_experiment(data.frame(x1 = stats::rnorm(n)))
		des$assign_w_to_all_subjects()
		w = as.numeric(des$get_w())
		y = ifelse(w == 1, c(rep(c(0, 1), length.out = sum(w == 1))), 0)
		des$add_all_subject_responses(ys = y)
		# treatment-only model, as when the original fit kept no covariates
		inf = InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~1)
		priv = inf$.__enclos_env__$private
		# warm start chained from a previous permutation that is infeasible here
		priv$fit_warm_start_enabled = TRUE
		priv$fit_warm_start = c(5, 0)
		priv$fit_warm_start_type = "beta"
		priv$fit_warm_start_fisher = NULL
		est = priv$compute_treatment_estimate_during_randomization_inference(estimate_only = TRUE)
		ref = mean(y[w == 1]) - mean(y[w == 0])
		expect_true(ref > 0.3)
		expect_true(is.na(est) || abs(est - ref) < 1e-3)
})
