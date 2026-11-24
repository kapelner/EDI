# Untested-code audit, 2026-11-24: covers R/EDI/R/inference_all_abstract_rand.R:601-602
# (compute_rand_two_sided_pval; region unt-c489a8a7fa0b).
# Reference: Plain-R difference in arm means for each permutation column (the cached null draws), and
# the guard's documented contract: NA_real_ plus the reason
# 'randomization_observed_statistic_unavailable'.
# Verified on commit f52f53392559 under pkgload::load_all(compile = FALSE): passed; executed 2 of 2
# target lines (5.7 s).

library(testthat)
library(EDI)

test_that("cached affine randomization path returns NA with the documented reason when the observed statistic is non-finite", {
	set.seed(7L)
	n = 30L
	r = 20L
	des = DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rnorm(n) + 0.5 * w
	des$add_all_subject_responses(y)
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	perms = priv$generate_permutations(r)

	# First call (delta = 0, explicit permutations) fills the affine cache used by the guarded branch.
	p_first = inf$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	expect_true(is.finite(p_first))
	W = perms$w_mat
	t0_ref = vapply(seq_len(r), function(b) mean(y[W[, b] == 1]) - mean(y[W[, b] == 0]), numeric(1))
	# closed-form difference in means per draw; only summation order differs
	expect_equal(priv$cached_values$t0s_rand, t0_ref, tolerance = 1e-10)
	expect_length(priv$cached_values$t0s_rand_slopes, r)

	# Defensive guard (contract section 5): stub the observed statistic to a non-finite value.
	unlockBinding("compute_treatment_estimate_during_randomization_inference", priv)
	priv$compute_treatment_estimate_during_randomization_inference = function(estimate_only = TRUE) Inf
	p_second = inf$compute_rand_two_sided_pval(r = r, permutations = perms, show_progress = FALSE)
	expect_identical(p_second, NA_real_)
	reasons = c(unlist(priv$cached_values$procedure_failure_reason), inf$get_nonestimable_reason())
	expect_true("randomization_observed_statistic_unavailable" %in% reasons)
})
