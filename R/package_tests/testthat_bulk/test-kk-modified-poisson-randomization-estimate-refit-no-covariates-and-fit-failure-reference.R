library(testthat)
library(EDI)

# InferenceAbstractKKModifiedPoisson's compute_treatment_estimate_during_randomization_inference()
# (inference_incidence_KK_marginal.R, reached here through InferenceIncidKKModifiedPoisson) had no
# test reference anywhere.
#
# GOTCHA investigated and ruled OUT as a bug: this method's shared(estimate_only = TRUE) call has an
# early-return guard (`if (estimate_only && !is.null(cached_values$beta_hat_T)) return(...)`) that
# skips re-populating private$best_X_colnames once compute_estimate() has already cached a point
# estimate -- so calling this private method directly on the SAME already-fitted instance after
# mutating private$w (the pattern used for every other class in this session's randomization-estimate
# series) always falls through to compute_estimate()'s own stale cached value, appearing to ignore
# the permutation entirely. Confirmed via the real public compute_rand_two_sided_pval() that this is
# NOT how randomization inference actually works for this class: it gives a sensible, non-degenerate
# p-value (1.48e-05 on a strong simulated true effect), because the real dispatch runs each
# permutation replicate on a FRESH self$duplicate() worker clone (cached_values$beta_hat_T starts
# NULL on the clone), not by mutating private$w on the live instance in place. This file follows that
# same duplicate()-based pattern, which is the only way to correctly exercise this method's real
# design-matrix-reuse fast path.
#
#   1. On a duplicate() worker with a permuted w, the refit matches an independent
#      glm(family = poisson()) fit -- both with and without covariates.
#   2. A fitter failure (fit_modified_poisson() always returning NULL, or always returning a
#      non-finite beta_hat) returns NA. On a fresh worker this actually confirmed to route through
#      shared()'s own failed-fit path first (best_X_colnames never gets populated, since
#      fit_modified_poisson() is the same mocked function shared() itself calls), landing on the
#      outer self$compute_estimate() fallback -- which fails the same way and returns NA -- rather
#      than this method's own direct is.null(fit) check on a *successfully* design-matrix-reusing
#      call. Confirmed via a call-count probe (2 calls: one from shared(), one from the
#      compute_estimate() fallback) before writing this assertion.

kk_modpois_fixture <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-1.2 + 0.5 * w + 0.3 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, x = X$x1, y = y, w = w)
}

kk_modpois_no_cov_fixture <- function(seed = 2L, n = 80L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-1.2 + 0.5 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKModifiedPoisson$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, y = y, w = w)
}

test_that("on a duplicate() worker with a permuted w, the refit matches glm(poisson) with covariates", {
	f <- kk_modpois_fixture()
	f$inf$compute_estimate()

	set.seed(9)
	w2 <- sample(f$w)
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	expect_null(pw$cached_values$beta_hat_T)
	pw$w <- w2

	est <- pw$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ w2 + f$x, family = poisson()))[2])
	expect_equal(est, ref, tolerance = 1e-6)
})

test_that("on a duplicate() worker with a permuted w and no covariates, the refit matches glm(poisson)", {
	f <- kk_modpois_no_cov_fixture()
	f$inf$compute_estimate()

	set.seed(9)
	w2 <- sample(f$w)
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	pw$w <- w2

	est <- pw$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(glm(f$y ~ w2, family = poisson()))[2])
	expect_equal(est, ref, tolerance = 1e-6)
})

test_that("a fitter failure (fit_modified_poisson() returns NULL) returns NA", {
	f <- kk_modpois_fixture(seed = 3L)
	f$inf$compute_estimate()
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	unlockBinding("fit_modified_poisson", pw)
	pw$fit_modified_poisson <- function(...) NULL

	expect_true(is.na(pw$compute_treatment_estimate_during_randomization_inference()))
})

test_that("a non-finite fit_modified_poisson() beta_hat returns NA", {
	f <- kk_modpois_fixture(seed = 4L)
	f$inf$compute_estimate()
	worker <- f$inf$duplicate()
	pw <- worker$.__enclos_env__$private
	unlockBinding("fit_modified_poisson", pw)
	pw$fit_modified_poisson <- function(...) list(beta_hat = NA_real_)

	expect_true(is.na(pw$compute_treatment_estimate_during_randomization_inference()))
})
