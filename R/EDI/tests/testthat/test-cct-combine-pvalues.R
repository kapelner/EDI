library(testthat)
library(EDI)

# inference_suite_inspect.md TODO-18: simulation-based validity checks for
# the Cauchy combination test machinery (cct_combine_pvalues()/
# cct_combine_pvalues_full()/run_all_inference_combine_pvalues()) and the
# TODO-15 weighting dispatcher (run_all_inference_compute_combined_evidence_
# weights()). These test the standalone combiner functions directly (no
# Inference/Design objects involved) -- the property being relied on is a
# statistical one (is the combined p-value calibrated/valid), which needs a
# simulation check, not just a unit test of the algebra.

test_that("TODO-18: combined p-value is calibrated under a true global null (iid uniform p-values)", {
	set.seed(20260819)
	n_sims = 2000L
	k = 5L
	alpha = 0.05
	combined_pvals = vapply(seq_len(n_sims), function(i) {
		pvals = runif(k)
		EDI:::cct_combine_pvalues(pvals)
	}, numeric(1L))

	# Under a true global null, the combined p-value should itself be
	# (roughly) Uniform(0,1) -- not anti-conservative (rejecting more often
	# than alpha would indicate an invalid/too-liberal test). Allow a
	# reasonable Monte Carlo tolerance around the nominal rate.
	rejection_rate = mean(combined_pvals < alpha)
	expect_lt(rejection_rate, alpha * 1.5)

	# A rough uniformity check via a one-sample KS test against Unif(0,1);
	# not exact (CCT's finite-sample distribution is only asymptotically
	# uniform), so use a loose threshold rather than treating this as a
	# strict goodness-of-fit requirement.
	ks = suppressWarnings(ks.test(combined_pvals, "punif"))
	expect_gt(ks$p.value, 0.001)
})

test_that("TODO-18: combined p-value stays valid under correlated p-values sharing common data-driven correlation", {
	set.seed(20260819)
	n_sims = 2000L
	k = 5L
	alpha = 0.05
	rho = 0.6

	# Simulate correlated test statistics via a shared latent factor (mimics
	# k analyses run on the same underlying dataset -- e.g. bootstrap-derived
	# p-values that share sampling variability), each still individually
	# Uniform(0,1) under a true null via the probability integral transform.
	combined_pvals = vapply(seq_len(n_sims), function(i) {
		common = rnorm(1L)
		idiosyncratic = rnorm(k)
		z = sqrt(rho) * common + sqrt(1 - rho) * idiosyncratic
		pvals = 2 * (1 - pnorm(abs(z))) # two-sided p-values, each marginally Unif(0,1) under H0
		EDI:::cct_combine_pvalues(pvals)
	}, numeric(1L))

	# CCT's defining property is validity under arbitrary/unknown
	# dependence: the combined p-value must not spuriously reject at an
	# inflated rate under a true joint null, even when inputs are
	# correlated. Allow a modest tolerance for Monte Carlo error.
	rejection_rate = mean(combined_pvals < alpha)
	expect_lt(rejection_rate, alpha * 2)
})

test_that("TODO-17 edge cases: NA-dropping, <2 usable, and 0/1 clipping", {
	# Dropping NA p-values (with aligned weight-vector dropping).
	res = EDI:::run_all_inference_combine_pvalues(c(0.01, NA, 0.02, 0.03))
	res_no_na = EDI:::run_all_inference_combine_pvalues(c(0.01, 0.02, 0.03))
	expect_equal(res$pval, res_no_na$pval)
	expect_equal(res$n_used, 3L)

	# Fewer than 2 usable p-values -> NA_real_ for pval/stat, not a
	# single-p-value-treated-as-combined result.
	one = EDI:::run_all_inference_combine_pvalues(c(0.05))
	expect_true(is.na(one$pval))
	expect_true(is.na(one$stat))
	expect_identical(one$n_used, 1L)

	zero = EDI:::run_all_inference_combine_pvalues(numeric(0))
	expect_true(is.na(zero$pval))
	expect_identical(zero$n_used, 0L)

	all_na = EDI:::run_all_inference_combine_pvalues(c(NA_real_, NA_real_))
	expect_true(is.na(all_na$pval))
	expect_identical(all_na$n_used, 0L)

	# p-values of exactly 0 or 1 must not produce +-Inf/NaN via the
	# tan()/atan() transform -- clipping to [pval_eps, 1 - pval_eps] avoids
	# the degenerate atan() input.
	extreme = EDI:::run_all_inference_combine_pvalues(c(0, 1, 0.5))
	expect_true(is.finite(extreme$pval))
	expect_true(is.finite(extreme$stat))

	# Four identical p-values combine to exactly that value under equal
	# weighting (a direct check of the CCT mathematical identity).
	identical_four = EDI:::cct_combine_pvalues(rep(0.15, 4))
	expect_equal(identical_four, 0.15, tolerance = 1e-10)

	# pval_eps genuinely changes clipping behavior for an extreme p-value.
	tight = EDI:::run_all_inference_combine_pvalues(c(0, 0.5), pval_eps = 1e-8)
	loose = EDI:::run_all_inference_combine_pvalues(c(0, 0.5), pval_eps = 1e-4)
	expect_false(isTRUE(all.equal(tight$pval, loose$pval)))
})

test_that("TODO-15 weighting policies: estimand_grouped, equal, and custom", {
	df = data.frame(
		inference_class = c("A", "B", "C", "D", "E"),
		estimand = c("mean_difference", "mean_difference", "mean_difference", "median_difference", "stochastic_superiority"),
		pval = c(0.01, 0.02, 0.03, 0.04, 0.05),
		status = rep("ok", 5L),
		stringsAsFactors = FALSE
	)

	w_grouped = EDI:::run_all_inference_compute_combined_evidence_weights(df, "estimand_grouped")
	# 3 estimand groups (G = 3): 3 mean_difference classes each get 1/(3*3),
	# the two singleton groups each get 1/(3*1) -- matches
	# inference_suite_inspect.md's own worked example ratios.
	expect_equal(w_grouped[1:3], rep(1 / 9, 3))
	expect_equal(w_grouped[4], 1 / 3)
	expect_equal(w_grouped[5], 1 / 3)
	expect_equal(sum(w_grouped), 1, tolerance = 1e-10)

	w_equal = EDI:::run_all_inference_compute_combined_evidence_weights(df, "equal")
	expect_equal(w_equal, rep(0.2, 5))

	w_custom = EDI:::run_all_inference_compute_combined_evidence_weights(
		df, "custom", custom_weights = c(A = 2, B = 1)
	)
	expect_equal(w_custom, c(2, 1, 0, 0, 0))

	# estimands filter recomputes G over only the retained groups.
	w_filtered = EDI:::run_all_inference_compute_combined_evidence_weights(
		df, "estimand_grouped", estimands = "mean_difference"
	)
	expect_equal(w_filtered[1:3], rep(1 / 3, 3))
	expect_true(all(is.na(w_filtered[4:5])))

	# A non-usable row (status != "ok") always gets NA_real_ regardless of policy.
	df2 = df
	df2$status[1] = "error"
	w2 = EDI:::run_all_inference_compute_combined_evidence_weights(df2, "equal")
	expect_true(is.na(w2[1]))
	expect_equal(sum(w2, na.rm = TRUE), 1, tolerance = 1e-10)
})
