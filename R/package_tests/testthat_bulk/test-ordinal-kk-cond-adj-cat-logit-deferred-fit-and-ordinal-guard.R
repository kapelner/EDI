library(testthat)
library(EDI)

# docs-claims audit, finding docs-claims-d95cc5759 (InferenceOrdinalKKCondAdjCatLogitRegr,
# R/EDI/R/inference_ordinal_KK_cond_adj_cat_logit.R initialize()):
#   - the constructor does not fit; fitting is deferred to the first compute_estimate();
#   - des_obj must be a KK design with an ordinal response.

kk_design <- function(response_type, y_fun, n = 40L, seed = 21L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

test_that("construction does not fit; the first compute_estimate() does", {
	des <- kk_design("ordinal", function(w) as.integer(cut(0.5 * w + rlogis(length(w)), c(-Inf, -0.6, 0.6, Inf))), n = 60L)
	inf <- InferenceOrdinalKKCondAdjCatLogitRegr$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	expect_null(p$cached_values$beta_hat_T)
	expect_null(p$cached_values$s_beta_hat_T)
	est <- inf$compute_estimate()
	expect_true(is.finite(est))
	expect_identical(p$cached_values$beta_hat_T, est)
	expect_true(is.finite(p$cached_values$s_beta_hat_T))
})

test_that("completed KK designs with a non-ordinal response are rejected", {
	expect_error(InferenceOrdinalKKCondAdjCatLogitRegr$new(kk_design("continuous", function(w) rnorm(length(w)))),
		"does not support response type 'continuous'")
	expect_error(InferenceOrdinalKKCondAdjCatLogitRegr$new(kk_design("incidence", function(w) rbinom(length(w), 1, 0.5))),
		"does not support response type 'incidence'")
})
