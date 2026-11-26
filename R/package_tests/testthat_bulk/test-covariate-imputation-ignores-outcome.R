library(testthat)
library(EDI)

# v1.0.6-TODO-9: missingness_method = "impute" imputes from the baseline covariates only.
# It used to add the response as a predictor. Treated subjects have shifted responses, so the
# imputed covariate then carried part of the treatment effect, and adjusting for it biased the
# estimate toward 0 (n = 200, 30% of x missing, true effect 1: mean estimate 0.90, 95% CI
# coverage 0.91; after the fix 0.996 and 0.93). The imputation is also seeded (the design's
# seed, else a fixed one) inside a .Random.seed save/restore.
# These tests check the mechanism directly rather than re-running that simulation:
#   1. the imputed covariates do not depend on the response at all;
#   2. the same covariates give the same imputed values, and a design seed is honored;
#   3. imputing leaves the caller's RNG stream where it was.

imp_covariates <- function(n = 40L) {
	set.seed(11L)
	X <- data.frame(x = rnorm(n), z = rnorm(n), g = sample(c("a", "b"), n, TRUE))
	X$x[c(3, 8, 15, 22, 30)] <- NA
	X$g[5] <- NA
	X
}

imp_design <- function(X, y, seed = NULL) {
	n <- nrow(X)
	des <- DesignFixediBCRD$new(response_type = "continuous", n = n, verbose = FALSE,
		missingness_method = "impute", include_is_missing_as_a_new_feature = FALSE, seed = seed)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = rep(0:1, length.out = n))
	des$add_all_subject_responses(y)
	des$.__enclos_env__$private$covariate_impute_if_necessary_and_then_create_model_matrix()
	des$.__enclos_env__$private$Ximp
}

test_that("imputed covariates do not depend on the response", {
	X <- imp_covariates()
	w <- rep(0:1, length.out = nrow(X))
	Ximp_null <- imp_design(X, y = rnorm(nrow(X)))
	Ximp_effect <- imp_design(X, y = rnorm(nrow(X)) + 10 * w)
	expect_false(anyNA(Ximp_null))
	expect_equal(Ximp_effect, Ximp_null)
})

test_that("the same covariates give the same imputed values; a design seed is honored", {
	X <- imp_covariates()
	y <- rnorm(nrow(X))
	expect_equal(imp_design(X, y), imp_design(X, y))
	expect_equal(imp_design(X, y, seed = 7L), imp_design(X, y, seed = 7L))
	expect_false(isTRUE(all.equal(imp_design(X, y, seed = 7L)$x, imp_design(X, y, seed = 8L)$x)))
})

test_that("imputing does not move the caller's RNG stream", {
	X <- imp_covariates()
	y <- rnorm(nrow(X))
	des <- DesignFixediBCRD$new(response_type = "continuous", n = nrow(X), verbose = FALSE,
		missingness_method = "impute", include_is_missing_as_a_new_feature = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects(w_precomputed = rep(0:1, length.out = nrow(X)))
	des$add_all_subject_responses(y)
	set.seed(5L)
	before <- .Random.seed
	des$.__enclos_env__$private$covariate_impute_if_necessary_and_then_create_model_matrix()
	expect_identical(.Random.seed, before)
})
