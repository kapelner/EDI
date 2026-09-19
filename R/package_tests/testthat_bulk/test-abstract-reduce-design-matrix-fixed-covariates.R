library(testthat)
library(EDI)

# InferenceAll's private reduce_design_matrix_preserving_treatment_fixed_covariates()
# and reduce_design_matrix_preserving_treatment_matrix() (R/EDI/R/inference_all_abstract.R)
# had zero test references anywhere (confirmed via repo-wide grep) despite being
# reachable from any harden=TRUE concrete class. Unlike the plain
# reduce_design_matrix_preserving_treatment(), the "_fixed_covariates" variant
# QR-reduces the non-treatment columns first (preserving them across calls via
# fixed_covariate_keep_cache) and only adds the treatment column afterward,
# checking that it doesn't become collinear with the already-reduced covariates.

make_min_design <- function(n) {
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "continuous")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i / 10))
	}
	des$overwrite_all_subject_assignments(rep(c(0, 1), length.out = n))
	des$add_all_subject_responses(rnorm(n))
	des
}

make_inf <- function(harden = TRUE) {
	inf <- InferenceAllSimpleAverageDiff$new(make_min_design(20L))
	inf$.__enclos_env__$private$harden <- harden
	inf
}

test_that("reduce_design_matrix_preserving_treatment_fixed_covariates returns the full matrix unchanged when harden=FALSE", {
	inf <- make_inf(harden = FALSE)
	priv <- inf$.__enclos_env__$private
	X_full <- cbind(`(Intercept)` = 1, treatment = rep(c(0, 1), 5), x = rnorm(10))

	res <- priv$reduce_design_matrix_preserving_treatment_fixed_covariates(X_full)
	expect_equal(res$X, X_full)
	expect_equal(res$keep, 1:3)
	expect_equal(res$j_treat, 2L)
})

test_that("reduce_design_matrix_preserving_treatment_fixed_covariates delegates to the plain variant when ncol<=2", {
	inf <- make_inf(harden = TRUE)
	priv <- inf$.__enclos_env__$private
	X_full <- cbind(`(Intercept)` = 1, treatment = rep(c(0, 1), 5))

	res <- priv$reduce_design_matrix_preserving_treatment_fixed_covariates(X_full)
	res_plain <- priv$reduce_design_matrix_preserving_treatment(X_full)
	expect_equal(res$X, res_plain$X)
	expect_equal(res$keep, res_plain$keep)
	expect_equal(res$j_treat, res_plain$j_treat)
})

test_that("reduce_design_matrix_preserving_treatment_fixed_covariates keeps a genuinely useful covariate alongside treatment", {
	set.seed(1)
	n <- 40L
	inf <- make_inf(harden = TRUE)
	priv <- inf$.__enclos_env__$private
	treatment <- rep(c(0, 1), length.out = n)
	x_indep <- rnorm(n)
	X_full <- cbind(`(Intercept)` = 1, treatment = treatment, x = x_indep)

	res <- priv$reduce_design_matrix_preserving_treatment_fixed_covariates(X_full)
	expect_equal(res$keep, c(1L, 2L, 3L))
	expect_equal(unname(res$j_treat), 2L)
	expect_equal(unname(res$X), unname(X_full))
})

test_that("reduce_design_matrix_preserving_treatment_fixed_covariates falls back to the plain reducer when treatment is collinear with the reduced covariates", {
	set.seed(2)
	n <- 20L
	inf <- make_inf(harden = TRUE)
	priv <- inf$.__enclos_env__$private
	# treatment is an exact linear function of x -- after QR-reducing the
	# non-treatment columns (intercept, x), adding treatment cannot raise rank.
	x <- rnorm(n)
	treatment <- 2 * x + 1
	X_full <- cbind(`(Intercept)` = 1, treatment = treatment, x = x)

	res <- priv$reduce_design_matrix_preserving_treatment_fixed_covariates(X_full)
	res_plain <- priv$reduce_design_matrix_preserving_treatment(X_full)
	expect_equal(res$keep, res_plain$keep)
	expect_equal(unname(res$X), unname(res_plain$X))
})

test_that("reduce_design_matrix_preserving_treatment_fixed_covariates drops a redundant fixed covariate before considering treatment", {
	set.seed(3)
	n <- 20L
	inf <- make_inf(harden = TRUE)
	priv <- inf$.__enclos_env__$private
	treatment <- rep(c(0, 1), length.out = n)
	x <- rnorm(n)
	X_full <- cbind(`(Intercept)` = 1, treatment = treatment, x = x, x_dup = x)

	res <- priv$reduce_design_matrix_preserving_treatment_fixed_covariates(X_full)
	# x_dup (col 4) is redundant with x (col 3) among the non-treatment columns;
	# the QR reduction on other_cols = c(1,3,4) must drop one of them, and
	# treatment (col 2) is added back afterward.
	expect_true(2L %in% res$keep)
	expect_true(1L %in% res$keep)
	expect_true(xor(3L %in% res$keep, 4L %in% res$keep) || !(3L %in% res$keep && 4L %in% res$keep))
	expect_equal(length(res$keep), 3L)
})

test_that("reduce_design_matrix_preserving_treatment_matrix returns exactly the $X component of the plain reducer", {
	inf <- make_inf(harden = TRUE)
	priv <- inf$.__enclos_env__$private
	set.seed(4)
	X_full <- cbind(`(Intercept)` = 1, treatment = rep(c(0, 1), 5), x = rnorm(10))

	# Note: the fresh QR-reduction path (qr_reduce_preserve_cols_cpp) drops
	# dimnames, while a subsequent cache-hit path (try_cached_reduced_design_keep,
	# a plain column subset of X_full) preserves them -- a real, harmless
	# inconsistency, not asserted as a bug. Compare on values only.
	mat <- priv$reduce_design_matrix_preserving_treatment_matrix(X_full)
	full_res <- priv$reduce_design_matrix_preserving_treatment(X_full)
	expect_equal(unname(mat), unname(full_res$X))
})
