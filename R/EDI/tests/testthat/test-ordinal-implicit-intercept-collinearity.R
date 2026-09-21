library(testthat)
library(EDI)

# Ordinal threshold models have no intercept column in X but an implicit one per stage, so a
# covariate set that sums to a constant (e.g. BOTH dummies of a two-level factor) is collinear
# with it even though qr(X) alone calls it full rank. InferenceOrdinalContRatioRegr then started
# its solver from garbage (thresholds ~ -7e13), "converged" after 1 iteration with a gradient
# norm of ~27, and reported the unconverged cold-start value as the estimate (-0.027 vs the
# true MLE -0.10 in the harness case). Every Bayesian-bootstrap replicate equalled that estimate
# because the weights never entered the fit, giving zero-width CIs. Found 2026-09-21 via the
# comprehensive_tests results audit (SPBR designs, whose strata are factor columns).

collinear_ordinal_design = function(complementary) {
	set.seed(31)
	n = 120L
	d1 = rbinom(n, 1, 0.5)
	X = data.frame(x1 = rnorm(n), d1 = d1)
	if (complementary) X$d2 = 1 - d1
	w = rbinom(n, 1, 0.5)
	y = as.integer(cut(0.5 * w + 0.7 * X$x1 + 0.4 * d1 + rlogis(n), c(-Inf, -1, 0, 1, Inf)))
	d = DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
	d$add_all_subjects_to_experiment(X)
	d$overwrite_all_subject_assignments(w)
	d$add_all_subject_responses(y)
	d
}

test_that("a complementary dummy pair does not change the ordinal continuation-ratio estimate", {
	est_with = suppressWarnings(InferenceOrdinalContRatioRegr$new(collinear_ordinal_design(TRUE))$compute_estimate())
	est_without = suppressWarnings(InferenceOrdinalContRatioRegr$new(collinear_ordinal_design(FALSE))$compute_estimate())
	expect_true(is.finite(est_with))
	expect_equal(est_with, est_without, tolerance = 1e-3)
})

test_that("Bayesian-bootstrap weights move the ordinal continuation-ratio estimate on collinear covariates", {
	inst = InferenceOrdinalContRatioRegr$new(collinear_ordinal_design(TRUE))
	suppressWarnings(inst$compute_estimate())
	priv = inst$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context = priv$build_bayesian_bootstrap_context(weighting_unit_type = NULL)
	reps = vapply(1:6, function(k) inst$compute_estimate_with_bootstrap_weights(priv$bayesian_bootstrap_sample_weights(NULL)$subject_or_block_weights, estimate_only = TRUE), numeric(1))
	expect_gt(stats::sd(reps, na.rm = TRUE), 1e-3)
})

test_that("the hardened column dropper removes columns that are collinear with the implicit intercept", {
	inst = InferenceOrdinalContRatioRegr$new(collinear_ordinal_design(TRUE))
	priv = inst$.__enclos_env__$private
	X = cbind(treatment = rep(0:1, 60), a = rep(c(0, 1, 1, 0), 30), b = rep(c(1, 0, 0, 1), 30), z = rnorm(120))
	seen = NULL
	priv$fit_with_hardened_qr_column_dropping(
		X_full = X, required_cols = 1L, implicit_intercept = TRUE,
		fit_fun = function(X_fit) { seen <<- colnames(X_fit); list(ok = TRUE) },
		fit_ok = function(mod, X_fit, keep) TRUE
	)
	expect_false(all(c("a", "b") %in% seen))
	expect_true(all(c("treatment", "z") %in% seen))
})
