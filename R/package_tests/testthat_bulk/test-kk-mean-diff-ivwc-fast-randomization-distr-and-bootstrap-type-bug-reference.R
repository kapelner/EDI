library(testthat)
library(EDI)

# InferenceAllKKMeanDiffIVWC's own private compute_fast_randomization_distr(y, permutations, delta,
# transform_responses, ...) override (inference_all_KK_mean_diff_IVWC.R) had no direct test reference
# anywhere: the 4 existing references to the class (test-continuous-estimator-contracts.R,
# test-simple-mean-difference-migration-golden.R, etc.) are golden/migration/contract tests that never
# call this method directly, and the class's public entry point
# (approximate_randomization_distribution_beta_hat_T()) dispatches to it internally but only ever with
# the design's own generated permutations, never isolating this method's specific documented branches:
#   1. delta != 0: returns NULL immediately (a Wald-only class -- no shift-invariant fast path).
#   2. m_mat == NULL (no pairing info supplied): treated as unpaired, i.e. reduces to the plain
#      treated-minus-control mean difference dispatched through compute_matching_compound_distr_
#      parallel_cpp with an all-zero pairing matrix.
#   3. Real (nontrivial) pairing info reproduces compute_estimate()'s own point estimate exactly when
#      the permutation column IS the subject's actual observed assignment/pairing (an independent
#      cross-check against the class's own compute_estimate(), analogous to the established pattern in
#      test-simple-wilcox-hl-point-estimate-weighted-branch-and-fast-randomization-distribution-
#      reference.R).
#   4. NA entries in m_mat are zeroed (treated as unpaired) rather than propagating NA.
#
# Separately: this iteration also found -- but per instructions does NOT fix -- a real source bug in
# this file's SIBLING private method, compute_fast_bootstrap_distr(): it builds w_mat/m_mat as
# `matrix(0L, ...)` (integer) but then assigns `w_mat[, b] = w[i_b]` where w (private$w) is always
# stored as a *double* vector everywhere in this codebase; assigning a double vector into an integer
# matrix column promotes R's ENTIRE matrix to double (confirmed via a minimal `m <- matrix(0L,2,2);
# m[,1] <- c(1,2)` repro), so w_mat (and m_mat, built the same way) end up double by the time they
# reach compute_matching_compound_bootstrap_parallel_cpp(), which Rcpp-maps as Eigen::MatrixXi --
# raising "Wrong R type for mapped matrix" on every call. This method is, however, structurally
# unreachable via the public API: every KK-matching design (KK14/KK21/KK21stepwise) is a
# DesignSeqOneByOne descendant, and EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES (inference_class_
# registry.R) disables the "nonparametric_bootstrap" capability -- including approximate_bootstrap_
# distribution_beta_hat_T(), the only caller -- for that entire design family (DesignSeqOneByOneBernoulli
# is the sole exception, and it has no match structure to dispatch this fast path at all). So this bug
# can never actually be hit by a real user; no test is written to exercise the crash (which would just
# be testing an artifact of the type-promotion bug, not a documented contract), matching this project's
# established convention of leaving genuinely-unreachable code untested rather than forcing an
# artificial repro.

fx <- function(seed, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv, n = n)
}

test_that("a nonzero delta returns NULL immediately, regardless of permutations", {
	f <- fx(1L)
	w_int <- as.integer(f$priv$w)
	m_vec <- as.integer(f$priv$m); m_vec[is.na(m_vec)] <- 0L
	perms <- list(w_mat = cbind(w_int), m_mat = cbind(m_vec))
	out <- f$priv$compute_fast_randomization_distr(f$priv$y, perms, delta = 0.3, transform_responses = "none")
	expect_null(out)
})

test_that("passing the subject's real assignment and real pairing as the sole permutation column reproduces compute_estimate() exactly", {
	f <- fx(2L)
	w_int <- as.integer(f$priv$w)
	m_vec <- as.integer(f$priv$m); m_vec[is.na(m_vec)] <- 0L
	perms <- list(w_mat = cbind(w_int), m_mat = cbind(m_vec))
	out <- f$priv$compute_fast_randomization_distr(f$priv$y, perms, delta = 0, transform_responses = "none")
	expect_equal(as.numeric(out), f$inf$compute_estimate(estimate_only = TRUE), tolerance = 1e-10)
})

test_that("a NULL m_mat (no pairing supplied) reduces to the plain treated-minus-control mean difference", {
	f <- fx(3L)
	w_int <- as.integer(f$priv$w)
	out <- f$priv$compute_fast_randomization_distr(f$priv$y, list(w_mat = cbind(w_int)), delta = 0, transform_responses = "none")
	expect_equal(as.numeric(out), mean(f$priv$y[w_int == 1L]) - mean(f$priv$y[w_int == 0L]), tolerance = 1e-10)
})

test_that("NA entries in m_mat are zeroed (unpaired) rather than propagating NA, and multi-column permutation matrices work", {
	f <- fx(4L)
	w_int <- as.integer(f$priv$w)
	m_vec <- as.integer(f$priv$m); m_vec[is.na(m_vec)] <- 0L
	w2 <- w_int; w2[1] <- 1L - w2[1]
	perms <- list(w_mat = cbind(w_int, w2), m_mat = cbind(m_vec, NA_integer_))
	out <- f$priv$compute_fast_randomization_distr(f$priv$y, perms, delta = 0, transform_responses = "none")
	expect_length(out, 2L)
	expect_true(all(is.finite(out)))
	# second column has an all-NA (-> all-zero) m_mat column, so it must match the unpaired formula
	expect_equal(out[2], mean(f$priv$y[w2 == 1L]) - mean(f$priv$y[w2 == 0L]), tolerance = 1e-10)
})
