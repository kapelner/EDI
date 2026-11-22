# Numerical-robustness review audit, 2026-11-17: evaluate_penalized_neg_loglik_at() takes
# determinant(...)$modulus, which is log|det I| and drops the sign. An indefinite information matrix
# (common for observed information away from the MLE, e.g. diag(2, -3)) has a negative determinant,
# so the Jeffreys/Firth penalty log|I(theta)| is undefined there. The function still returns a finite
# penalized objective (neg_loglik - 0.5*log 6) instead of the documented infeasibility value Inf, so
# an optimizer can be steered into regions where the information is not positive definite.
# Where: R/EDI/R/inference_mixin_off_optimum_likelihood_eval.R:99 (kind: other_numerical).
# On commit 48765322fe90 this test failed with: Expected `val` to equal Inf. Differences: 1/1
# mismatches [1] -0.396 - Inf == -Inf
# Tracked as v1.0.6-TODO-391; remove the skip() when it is fixed.

test_that("penalized neg-loglik is infeasible (Inf) when the information matrix is indefinite", {
	skip("v1.0.6-TODO-391: determinant()$modulus drops the sign, so an indefinite information gives a finite value")
		mixin = EDI:::InferenceMixinOffOptimumLikelihoodEval
		env = new.env(parent = asNamespace("EDI"))
		priv = lapply(mixin$private, function(f) {
			environment(f) = env
			f
		})
		env$private = priv
		env$self = structure(list(), class = "FakeOffOptimumHost")
		spec = list(
			neg_loglik_at = function(theta) sum(theta^2),
			information_at = function(theta, source = "observed") diag(c(2, -3))
		)
		val = priv$evaluate_penalized_neg_loglik_at(c(0.5, 0.5), spec = spec, source = "observed")
		# log|I| is undefined for an indefinite information matrix (det = -6);
		# the documented contract is to return Inf for an infeasible penalty.
		expect_equal(val, Inf)
})
