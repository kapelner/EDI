library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d218ace01 (InferencePropZeroOneInflatedBetaRegr):
# - the reported effect is the beta-mean treatment coefficient conditional on y in (0, 1): with real 0/1 mass
#   it equals betareg's treatment coefficient fitted to the interior rows only, since the ZOIB likelihood
#   factorizes (inference_proportion_zero_one_inflated_beta.R:6);
# - treatment that only moves mass between the point masses and the interior gives a null conditional
#   coefficient while marginal_mean_diff is clearly non-zero (:10);
# - model_formula_zero_one = NULL uses model_formula when given, otherwise ~ . (:17).

zoib_sim = function(seed, n, beta_T, p0_w, p1_w) {
	set.seed(seed)
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "proportion", verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	mu = plogis(0.3 + beta_T * w + 0.4 * X$x1)
	p0 = plogis(-2 + p0_w * w)
	p1 = plogis(-2 + p1_w * w)
	u = runif(n)
	y = ifelse(u < p0, 0, ifelse(u < p0 + p1, 1, rbeta(n, mu * 8, (1 - mu) * 8)))
	des$add_all_subject_responses(y)
	list(des = des, y = y, w = w, X = X)
}

test_that("with 0/1 mass the conditional estimate equals betareg's treatment coefficient on the interior rows", {
	skip_if_not_installed("betareg")
	f = zoib_sim(1L, 200L, beta_T = 0.6, p0_w = -0.2, p1_w = 0.1)
	expect_gt(sum(f$y == 0), 5L)
	expect_gt(sum(f$y == 1), 5L)
	est = InferencePropZeroOneInflatedBetaRegr$new(f$des)$compute_estimate()
	mid = f$y > 0 & f$y < 1
	ref = betareg::betareg(y ~ w + x1 + x2, data = data.frame(y = f$y, w = f$w, f$X)[mid, ])
	expect_equal(est, unname(coef(ref)["w"]), tolerance = 1e-3)
	# not the all-rows (sanitized) beta regression
	all_rows = suppressWarnings(betareg::betareg(y ~ w + x1 + x2, data = data.frame(y = sanitize_beta_response(f$y), w = f$w, f$X)))
	expect_gt(abs(est - unname(coef(all_rows)["w"])), 0.05)
})

test_that("treatment that only shifts the point masses gives a null conditional coefficient but a non-zero marginal effect", {
	f = zoib_sim(2L, 1000L, beta_T = 0, p0_w = -1.5, p1_w = 1.5)
	inf = InferencePropZeroOneInflatedBetaRegr$new(f$des)
	ci_cond = inf$compute_asymp_confidence_interval()
	expect_lt(ci_cond[1], 0)
	expect_gt(ci_cond[2], 0)
	inf$set_estimand("marginal_mean_diff")
	ci_marg = inf$compute_asymp_confidence_interval()
	expect_gt(inf$compute_estimate(), 0.1)
	expect_gt(ci_marg[1], 0)
})

test_that("model_formula_zero_one defaults to ~ . without model_formula and to model_formula when one is given", {
	f = zoib_sim(3L, 120L, beta_T = 0.5, p0_w = 0, p1_w = 0)
	inf_default = InferencePropZeroOneInflatedBetaRegr$new(f$des)
	p = inf_default$.__enclos_env__$private
	expect_equal(p$model_formula_zero_one, ~ ., ignore_attr = TRUE)
	inf_default$compute_estimate()
	expect_identical(ncol(p$cached_mod$X_zero_one), 4L) # intercept, treatment, x1, x2

	inf_x1 = InferencePropZeroOneInflatedBetaRegr$new(f$des, model_formula = ~ x1)
	p1 = inf_x1$.__enclos_env__$private
	expect_equal(p1$model_formula_zero_one, ~ x1, ignore_attr = TRUE)
	inf_x1$compute_estimate()
	expect_identical(ncol(p1$cached_mod$X_zero_one), 3L) # intercept, treatment, x1

	inf_explicit = InferencePropZeroOneInflatedBetaRegr$new(f$des, model_formula = ~ x1, model_formula_zero_one = ~ x2)
	expect_equal(inf_explicit$.__enclos_env__$private$model_formula_zero_one, ~ x2, ignore_attr = TRUE)
})
