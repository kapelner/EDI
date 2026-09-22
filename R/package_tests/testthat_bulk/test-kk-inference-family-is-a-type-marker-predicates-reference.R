library(testthat)
library(EDI)

# A family of private is_a_<x>() type-marker predicates (return TRUE, always) declared across
# several KK-design inference mixins/abstracts, none of which had any test reference anywhere
# (confirmed by repo-wide grep on the literal function names) despite the classes that carry
# them being otherwise well-tested via their public behavior:
#   - is_a_glmm_family (inference_mixin_kk_glmm_shared.R, KKGLMM component) on InferenceContinKKGLMM
#   - is_a_kk_cond_logit_glmm (inference_incidence_KK_cond_logit_glmm_abstract.R) on the
#     non-IVWC InferenceIncidKKCondLogitGLMMOneLik leaf (the IVWC sibling leaf is out of scope --
#     avoided per this session's ongoing IVWC-compound-estimator exclusion)
#   - is_a_kk_marginal_incid (inference_incidence_KK_marginal_abstract.R) on
#     InferenceIncidKKModifiedPoisson (not the InferenceIncidKKGComp* leaves in the same file,
#     which share bootstrap-worker-cache machinery this session is avoiding)
#   - is_a_kk_ordinal_clmm (inference_ordinal_KK_clmm_abstract.R) on InferenceOrdinalKKCLMM
# All four have zero callers anywhere in the package source (grep -rn confirmed), same as the
# is_a_custom_* markers covered separately -- purely declarative type contracts, not reachable
# via any dispatch path, so the only thing worth pinning is that each concrete class's own
# predicate exists, is callable, and returns TRUE.

test_that("InferenceContinKKGLMM's is_a_glmm_family() exists, is callable, and returns TRUE", {
	set.seed(1); n <- 24L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKGLMM$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_glmm_family))
	expect_identical(priv$is_a_glmm_family(), TRUE)
})

test_that("InferenceIncidKKCondLogitGLMMOneLik's is_a_kk_cond_logit_glmm() exists, is callable, and returns TRUE", {
	set.seed(2); n <- 40L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w)))
	inf <- InferenceIncidKKCondLogitGLMMOneLik$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_kk_cond_logit_glmm))
	expect_identical(priv$is_a_kk_cond_logit_glmm(), TRUE)
})

test_that("InferenceIncidKKModifiedPoisson's is_a_kk_marginal_incid() exists, is callable, and returns TRUE", {
	set.seed(3); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.3 + 0.7 * w)))
	inf <- InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_kk_marginal_incid))
	expect_identical(priv$is_a_kk_marginal_incid(), TRUE)
})

test_that("InferenceOrdinalKKCLMM's is_a_kk_ordinal_clmm() exists, is callable, and returns TRUE", {
	y <- rep(1:3, length.out = 21L)
	des <- DesignSeqOneByOneKK14$new(n = length(y), response_type = "ordinal", verbose = FALSE)
	for (i in seq_along(y)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
		des$add_one_subject_response(i, y[i])
	}
	inf <- InferenceOrdinalKKCLMM$new(des, model_formula = ~ 1, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	expect_true(is.function(priv$is_a_kk_ordinal_clmm))
	expect_identical(priv$is_a_kk_ordinal_clmm(), TRUE)
})
