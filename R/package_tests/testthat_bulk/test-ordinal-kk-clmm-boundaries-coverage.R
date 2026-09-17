library(testthat)
library(EDI)

ordinal_clmm_coverage_design <- function(y = rep(1:3, 12L)) {
  withr::local_seed(715)
  des <- DesignSeqOneByOneKK14$new(n = length(y), response_type = "ordinal", verbose = FALSE)
  for (i in seq_along(y)) {
    des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
    des$add_one_subject_response(i, y[i])
  }
  des
}

test_that("KK CLMM reports unsupported response cardinality as nonestimable", {
  for (case in list(list(y = rep(1L, 24L), reason = "kk_clmm_too_few_levels"),
                    list(y = seq_len(24L), reason = "kk_clmm_too_many_levels"))) {
    inf <- InferenceOrdinalKKCLMM$new(ordinal_clmm_coverage_design(case$y),
                                     model_formula = ~ 1, verbose = FALSE)
    expect_true(is.na(inf$compute_estimate(estimate_only = TRUE)))
    expect_true(inf$is_nonestimable("estimate"))
    expect_identical(inf$get_nonestimable_reason(), case$reason)
    # Repeated requests preserve the diagnostic rather than returning a coefficient.
    expect_true(is.na(inf$compute_estimate()))
    expect_identical(inf$get_nonestimable_reason(), case$reason)
  }
})

