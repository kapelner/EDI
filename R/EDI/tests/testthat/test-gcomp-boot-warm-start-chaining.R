library(testthat)
library(EDI)

# Verify that warm-start chaining in compute_weighted_gcomp_estimate / weighted_gcomp_fit
# produces results consistent with independent (fresh-object) fits.
# Logistic regression is strictly convex → both paths converge to the same MLE within tolerance.

make_incid_kk_design <- function(n, seed) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w = des$get_w()
	p = plogis(-0.3 + 0.7 * w + 0.4 * X$x1)
	des$add_all_subject_responses(rbinom(n, 1, p))
	des
}

test_that("KK gcomp warm-start chaining matches independent fits (RD)", {
	des = make_incid_kk_design(60L, seed = 20260705)
	set.seed(1L)
	n = des$get_t()
	weight_sets = lapply(1:15, function(b) { wts = rexp(n); wts / mean(wts) })

	# Chained: reuse one object so gcomp_boot_beta accumulates across calls
	inf_chain = InferenceIncidKKGCompRiskDiff$new(des, verbose = FALSE)
	priv_chain = inf_chain$.__enclos_env__$private
	priv_chain$shared(estimate_only = TRUE)  # run primary fit so warm start is set
	chain_vals = vapply(weight_sets, function(wts) {
		rd = priv_chain$compute_weighted_gcomp_estimate(wts)
		if (is.null(rd)) NA_real_ else rd
	}, numeric(1))

	# Reference: fresh object per replicate (no chaining, cold from primary warm start)
	ref_vals = vapply(weight_sets, function(wts) {
		inf_fresh = InferenceIncidKKGCompRiskDiff$new(des, verbose = FALSE)
		priv_fresh = inf_fresh$.__enclos_env__$private
		priv_fresh$shared(estimate_only = TRUE)
		rd = priv_fresh$compute_weighted_gcomp_estimate(wts)
		if (is.null(rd)) NA_real_ else rd
	}, numeric(1))

	expect_equal(chain_vals, ref_vals, tolerance = 1e-6)
	expect_true(all(is.finite(chain_vals)))
})

test_that("KK gcomp warm-start chaining matches independent fits (RR)", {
	des = make_incid_kk_design(60L, seed = 20260706)
	set.seed(2L)
	n = des$get_t()
	weight_sets = lapply(1:15, function(b) { wts = rexp(n); wts / mean(wts) })

	inf_chain = InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
	priv_chain = inf_chain$.__enclos_env__$private
	priv_chain$shared(estimate_only = TRUE)
	chain_vals = vapply(weight_sets, function(wts) {
		rr = priv_chain$compute_weighted_gcomp_estimate(wts)
		if (is.null(rr)) NA_real_ else rr
	}, numeric(1))

	ref_vals = vapply(weight_sets, function(wts) {
		inf_fresh = InferenceIncidKKGCompRiskRatio$new(des, verbose = FALSE)
		priv_fresh = inf_fresh$.__enclos_env__$private
		priv_fresh$shared(estimate_only = TRUE)
		rr = priv_fresh$compute_weighted_gcomp_estimate(wts)
		if (is.null(rr)) NA_real_ else rr
	}, numeric(1))

	expect_equal(chain_vals, ref_vals, tolerance = 1e-6)
	expect_true(all(is.finite(chain_vals)))
})

test_that("non-KK gcomp warm-start chaining matches independent fits via weighted_gcomp_fit", {
	# `InferenceIncidGCompRiskDiff`/`RiskRatio` now implement reusable-bootstrap-
	# worker support (fix_inference_hierarchy.md Follow-Ups), so `gcomp_boot_beta`
	# warm-start chaining is only ever exercised through ONE persistent worker
	# object reused across an entire bootstrap run -- driven by
	# `create_bootstrap_worker_state()` and `compute_estimate_with_bootstrap_
	# weights()`, with `private$active_resampling_operation` set for the
	# duration (as `approximate_bayesian_bootstrap_distribution_beta_hat_T()`
	# does). Calling the private `weighted_gcomp_effects_from_row_weights()`/
	# `weighted_gcomp_fit()` methods directly and repeatedly on one object, as
	# this test previously did, bypasses that guard entirely: with
	# `active_resampling_operation` unset, `set_fit_warm_start()`'s "resampling
	# fits must not replace the primary MLE warm state" protection never
	# engages, so each replicate's fit corrupts the *primary* warm-start cache
	# too (not just the intentional `gcomp_boot_beta` chaining), which can bias
	# a later replicate's IRLS convergence enough to trigger a different
	# rank-deficient-column-dropping outcome than a cold start would have --
	# a real divergence, but one that only that direct-private-call pattern
	# (never used by any real code path) can trigger. Exercising the real
	# worker mechanism below reproduces exactly what production does.
	set.seed(20260707)
	n = 80L
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w + 0.3 * X$x1)))

	set.seed(3L)
	weight_sets = lapply(1:15, function(b) { wts = rexp(n); wts / mean(wts) })

	# Chained: one persistent reusable worker processes all replicates in
	# sequence, exactly as approximate_bayesian_bootstrap_distribution_beta_
	# hat_T()'s reusable-worker path does internally.
	inf = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	priv$shared(estimate_only = TRUE)
	expect_true(priv$use_reusable_bootstrap_worker())
	priv$active_resampling_operation = "bayesian_boot"
	worker_state = priv$create_bootstrap_worker_state()
	worker = worker_state$worker
	worker_priv = worker$.__enclos_env__$private
	worker_priv$active_resampling_operation = "bayesian_boot"
	worker_priv$current_bayesian_bootstrap_context = worker_priv$build_bayesian_bootstrap_context()
	chain_vals = vapply(weight_sets, function(wts) {
		as.numeric(worker$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE))
	}, numeric(1))
	priv$active_resampling_operation = NULL

	# Reference: fresh object per replicate (no chaining, cold start)
	ref_vals = vapply(weight_sets, function(wts) {
		inf_fresh = InferenceIncidGCompRiskDiff$new(des, verbose = FALSE)
		priv_fresh = inf_fresh$.__enclos_env__$private
		priv_fresh$shared(estimate_only = TRUE)
		effects = priv_fresh$weighted_gcomp_effects_from_row_weights(wts)
		if (is.null(effects)) NA_real_ else effects$rd
	}, numeric(1))

	expect_equal(chain_vals, ref_vals, tolerance = 1e-6)
	expect_true(all(is.finite(chain_vals)))
})
