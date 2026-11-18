# v1.0.6-TODO-124: the cached affine-reuse fast path of
# compute_rand_two_sided_pval() must enforce the same documented
# max(10, floor(r/10)) finite-draw minimum as the uncached path (it used to
# return NA only when no draw was finite), record the same failure reason, and
# give identical p-values when enough draws are finite.

library(testthat)
library(EDI)

affine_fixture = function(r = 200L, seed = 1L) {
	set.seed(seed)
	n = 40L
	des = DesignFixediBCRD$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = rep(c(1, 0), n / 2)
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rnorm(n) + 0.3 * w)
	W = vapply(seq_len(r), function(j) sample(w), numeric(n))
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private,
		perms = list(w_mat = W, m_mat = NULL), r = r)
}

# Populate the affine cache with one ordinary call, then overwrite the cached
# draws with a stub that has only `n_finite` finite entries.
stub_cache = function(fx, n_finite) {
	pv = fx$inf$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms, show_progress = FALSE)
	expect_true(is.finite(pv))
	cv = fx$priv$cached_values
	expect_length(cv$t0s_rand, fx$r)
	expect_length(cv$t0s_rand_slopes, fx$r)
	t0s = cv$t0s_rand
	if (n_finite < fx$r) t0s[(n_finite + 1L):fx$r] = NA_real_
	fx$priv$cached_values$t0s_rand = t0s
	t0s
}

test_that("affine-reuse path returns NA below max(10, floor(r/10)) finite draws", {
	fx = affine_fixture(r = 200L)
	# min_required = max(10, floor(200/10)) = 20; 15 finite draws is above the old
	# zero-finite cutoff but below the documented minimum.
	stub_cache(fx, n_finite = 15L)
	expect_true(isTRUE(fx$priv$supports_additive_delta_shift("none")))
	expect_true(is.na(fx$inf$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms,
		delta = 0.5, show_progress = FALSE)))
	for (alt in c("greater", "less")) {
		expect_true(is.na(fx$inf$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms,
			delta = 0.5, show_progress = FALSE, alternative = alt)))
	}
})

test_that("affine-reuse path agrees with the uncached helper at and above the minimum", {
	for (n_finite in c(20L, 21L, 200L)) {
		fx = affine_fixture(r = 200L)
		t0s = stub_cache(fx, n_finite = n_finite)
		delta = 0.25
		t = fx$priv$compute_treatment_estimate_during_randomization_inference()
		shifted = t0s + delta * fx$priv$cached_values$t0s_rand_slopes
		for (alt in c("two.sided", "greater", "less")) {
			got = fx$inf$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms,
				delta = delta, show_progress = FALSE, alternative = alt)
			finite = is.finite(shifted)
			tails = rand_tail_counts(shifted, t)
			want = rand_pval_from_tail_counts(tails[["ge"]], tails[["le"]], sum(finite), alt)
			expect_true(is.finite(got))
			expect_identical(got, want)
			expect_identical(got, fx$priv$compute_two_sided_randomization_pval_from_t0s(shifted, t, alt))
		}
	}
})

test_that("affine-reuse NA records the same failure reason as the uncached path when hardened", {
	fx = affine_fixture(r = 200L)
	stub_cache(fx, n_finite = 15L)
	fx$priv$harden = TRUE
	expect_true(is.na(fx$inf$compute_rand_two_sided_pval(r = fx$r, permutations = fx$perms,
		delta = 0.5, show_progress = FALSE)))
	cv = fx$priv$cached_values
	reasons = unlist(c(cv$procedure_failure_reason,
		cv$nonestimable_reason), use.names = FALSE)
	expect_true("randomization_too_few_finite_estimates" %in% reasons)
})
