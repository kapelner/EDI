library(testthat)
library(EDI)

# InferenceAbstractKKOrdinalCLMM's private clmm_predictors_df()/clmm_predictors_df_from_design()/
# clmm_X_for_rcpp() (inference_ordinal_KK_clmm_abstract.R) had no test reference anywhere. This is the
# shared base for all four ordinal KK CLMM link-function siblings (InferenceOrdinalKKCLMM/...Cauchit/
# ...Cloglog/...Probit), inherited via plain R6::R6Class(inherit = ...) rather than
# define_inference_class() composition -- a first (naive) generator-level $private_methods check
# incorrectly showed these as absent on the concrete subclasses, since that field only lists a
# generator's OWN directly-declared private list, not inherited ones; a live instance's own private
# env (checked here, and how every test below reads the method) confirms they really are present and
# reachable.
#   1. clmm_predictors_df_from_design() drops create_design_matrix()'s "(Intercept)" column and
#      renames the (now-first) "treatment" column to "w", leaving any remaining covariate columns
#      untouched, in order.
#   2. clmm_predictors_df() is exactly clmm_predictors_df_from_design(create_design_matrix()) --
#      verified by calling both independently and comparing.
#   3. With no covariates (model_formula = ~1), the result is a single-column data.frame named "w"
#      with the design's actual treatment assignment.
#   4. clmm_X_for_rcpp() is exactly as.matrix(clmm_predictors_df()).

clmm_fixture <- function(seed, n = 20L, model_formula = NULL, X_df = NULL) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "ordinal", verbose = FALSE)
	if (is.null(X_df)) X_df <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X_df[i, , drop = FALSE])
	des$add_all_subject_responses(sample(1:4, n, replace = TRUE))
	inf <- if (is.null(model_formula)) InferenceOrdinalKKCLMM$new(des, verbose = FALSE) else InferenceOrdinalKKCLMM$new(des, model_formula = model_formula, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

test_that("clmm_predictors_df_from_design() drops the intercept, renames treatment to \"w\", and leaves covariates untouched", {
	f <- clmm_fixture(1L)
	full_X <- f$priv$create_design_matrix()
	expect_identical(colnames(full_X), c("(Intercept)", "treatment", "x1", "x2"))

	df <- f$priv$clmm_predictors_df_from_design(full_X)
	expect_identical(colnames(df), c("w", "x1", "x2"))
	expect_equal(nrow(df), nrow(full_X))
	expect_equal(df$w, as.numeric(full_X[, "treatment"]))
	expect_equal(df$x1, as.numeric(full_X[, "x1"]))
	expect_equal(df$x2, as.numeric(full_X[, "x2"]))
})

test_that("clmm_predictors_df() is exactly clmm_predictors_df_from_design(create_design_matrix())", {
	f <- clmm_fixture(2L)
	full_X <- f$priv$create_design_matrix()
	expect_identical(f$priv$clmm_predictors_df(), f$priv$clmm_predictors_df_from_design(full_X))
})

test_that("with no covariates, the result is a single-column data.frame named \"w\" holding the actual treatment assignment", {
	f <- clmm_fixture(3L, model_formula = ~1)
	df <- f$priv$clmm_predictors_df()
	expect_identical(colnames(df), "w")
	expect_equal(df$w, as.numeric(f$priv$w))
})

test_that("clmm_X_for_rcpp() is exactly as.matrix(clmm_predictors_df())", {
	f <- clmm_fixture(4L)
	expect_identical(f$priv$clmm_X_for_rcpp(), as.matrix(f$priv$clmm_predictors_df()))
})
