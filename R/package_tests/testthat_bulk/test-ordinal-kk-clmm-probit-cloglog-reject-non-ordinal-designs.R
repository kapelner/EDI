library(testthat)
library(EDI)

# docs-claims audit, findings docs-claims-db50271f2 (InferenceOrdinalKKCLMMProbit) and docs-claims-deb0abc5f
# (InferenceOrdinalKKCLMMCloglog), R/EDI/R/inference_ordinal_KK_clmm_abstract.R: "Class is for ordinal responses
# (non-ordinal designs are rejected)".

kk_design <- function(response_type, y_fun, n = 20L, seed = 1L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = response_type, verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(y_fun(des$get_w()))
	des
}

test_that("the probit and cloglog CLMM leaves reject completed continuous, incidence and count KK designs", {
	designs <- list(
		continuous = kk_design("continuous", function(w) rnorm(length(w))),
		incidence = kk_design("incidence", function(w) rbinom(length(w), 1, 0.5)),
		count = kk_design("count", function(w) rpois(length(w), 2))
	)
	for (cls in list(InferenceOrdinalKKCLMMProbit, InferenceOrdinalKKCLMMCloglog)) {
		for (nm in names(designs)) {
			expect_error(cls$new(designs[[nm]], verbose = FALSE), "only available for ordinal responses", info = paste(cls$classname, nm))
		}
	}
	ord <- kk_design("ordinal", function(w) sample(1:4, length(w), replace = TRUE))
	expect_no_error(InferenceOrdinalKKCLMMProbit$new(ord, verbose = FALSE))
	expect_no_error(InferenceOrdinalKKCLMMCloglog$new(ord, verbose = FALSE))
})
