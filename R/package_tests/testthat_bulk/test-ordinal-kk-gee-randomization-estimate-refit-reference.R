library(testthat)
library(EDI)

# InferenceOrdinalKKGEE's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_KK_combined.R) had no test reference anywhere. Its own source comment documents
# why it exists as a distinct override at all: randomization inference must reuse the ordLORgee fit
# (not the generic geeglm-based mixin fallback, which errors on >2-level responses and silently
# returns NA for every permutation replicate) and must NOT write into cached_values, since permuted
# data is refit repeatedly.
#
# GOTCHA found while probing this directly (not a bug -- documented here so a future test author
# doesn't mistake it for one): unlike the covariate-based siblings in this session's randomization-
# estimate series, calling this private method directly after manually reassigning private$w does
# NOT pick up the new assignment unless private$cached_design_matrix is also cleared first --
# gee_predictors_df() -> create_design_matrix() (inference_all_abstract.R) memoizes the design matrix
# (baked-in treatment column included) and only returns it fresh once cleared. The real
# compute_rand_two_sided_pval() worker machinery (inference_all_abstract_rand.R) clears this cache
# before every permutation replicate fit internally; a direct private-method call under test must do
# the same by hand, which this file does explicitly.
#
# No independent multgee-based reference is built here (test-kk-gee-parity.R already establishes
# that reference for compute_estimate() on this exact class/sign-convention); instead, the happy-path
# check is a structural self-consistency comparison -- on the SAME w, this method's own direct
# fit_ordinal_gee_mod_with_fallback() call reaches the identical estimate as compute_estimate()'s
# cached shared_gee_dispatch() result, and a permuted w (with the cache correctly cleared) produces a
# different, still-finite value.

kk_gee_fixture <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(as.integer(cut(0.9 * w + 0.3 * X$x1 + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf))))
	inf <- InferenceOrdinalKKGEE$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

test_that("on the same w it matches compute_estimate()'s own value; on a permuted w (with the design-matrix cache cleared) it differs and stays finite", {
	f <- kk_gee_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-8)
	# calling it a second time does not mutate the class's own cached point estimate
	expect_equal(f$priv$cached_values$beta_hat_T, main_est)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	f$priv$cached_design_matrix <- NULL
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(est2))
	expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("a fitter failure (fit_ordinal_gee_mod_with_fallback() returns NULL) returns NA", {
	f <- kk_gee_fixture(seed = 2L)
	f$inf$compute_estimate()
	p <- f$priv
	unlockBinding("fit_ordinal_gee_mod_with_fallback", p)
	p$fit_ordinal_gee_mod_with_fallback <- function(...) NULL

	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})

test_that("an out-of-range treatment index (gee_treatment_index() fails) returns NA", {
	f <- kk_gee_fixture(seed = 3L)
	f$inf$compute_estimate()
	p <- f$priv
	unlockBinding("gee_treatment_index", p)
	p$gee_treatment_index <- function(...) NA_integer_

	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})
