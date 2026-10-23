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

test_that("nonlogit KK CLMM weighted refits agree with cumulative-link mixed likelihood", {
  skip_if_not_installed("ordinal")
  des <- ordinal_clmm_coverage_design()
  y <- rep(1:3, 12L)
  w <- des$get_w()
  links <- c(InferenceOrdinalKKCLMMProbit = "probit",
             InferenceOrdinalKKCLMMCauchit = "cauchit",
             InferenceOrdinalKKCLMMCloglog = "cloglog")
  for (class_name in names(links)) {
    generator <- get(class_name, envir = asNamespace("EDI"))
    inf <- generator$new(des, model_formula = ~ 1, verbose = FALSE)
    private <- inf$.__enclos_env__$private
    context <- private$build_bayesian_bootstrap_context()
    private$current_bayesian_bootstrap_context <- context
    weights <- rep(c(1, 2, 3, 2), length.out = context$n_units)
    row_weights <- weights[context$row_to_unit]
    group_id <- private$clmm_group_id()
    fixed_start <- suppressWarnings(ordinal::clm(
      ordered(y) ~ w, weights = row_weights, link = links[[class_name]], Hess = FALSE
    ))
    candidates <- lapply(c(-5, -3, -1, 0, 1), function(log_sigma) {
      tryCatch(suppressWarnings(ordinal::clmm(
        ordered(y) ~ w + (1 | group_id), weights = row_weights,
        # ordinal::clmm's cloglog/loglog names are swapped upstream (v1.0.5 TODO-31,
        # G6 #45): ask clmm for the name that fits EDI's link; clm above is correct.
        link = EDI:::ordinal_clmm_link_name(links[[class_name]]), nAGQ = 20L, Hess = FALSE,
        start = c(coef(fixed_start), log_sigma)
      )), error = function(e) NULL)
    })
    candidates <- Filter(Negate(is.null), candidates)
    reference <- candidates[[which.max(vapply(candidates, logLik, numeric(1L)))]]
    reference_beta <- unname(stats::coef(reference)["w"])
    estimate <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
    expect_true(is.finite(estimate), info = class_name)
    expect_equal(estimate, unname(reference_beta), tolerance = 1e-6,
                 info = class_name)
    expect_true(is.na(private$weighted_refit_se()), info = class_name)
  }
})
