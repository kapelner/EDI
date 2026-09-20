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

test_that("nonlogit KK CLMM weighted surrogates agree with cumulative-link likelihood", {
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
    reference <- ordinal::clm(ordered(y) ~ w, weights = row_weights,
                              link = links[[class_name]],
                              control = ordinal::clm.control(gradTol = 1e-8))
    reference_beta <- unname(stats::coef(reference)["w"])
    if (links[[class_name]] == "cauchit") {
      # Match MASS's finite endpoint convention using a separate scalar
      # likelihood implementation; unlike normal/logistic tails, Cauchy
      # tail mass at the backend's +/-100 cap is still appreciable.
      nll <- function(par) {
        thresholds <- c(-Inf, par[2L], par[2L] + exp(par[3L]), Inf)
        eta <- par[1L] * w
        probabilities <- pcauchy(pmin(100, thresholds[y + 1L] - eta)) -
          pcauchy(pmax(-100, thresholds[y] - eta))
        -sum(row_weights * log(probabilities))
      }
      start <- c(reference_beta, reference$alpha[1L], log(diff(reference$alpha)))
      reference_beta <- stats::optim(start, nll, method = "BFGS",
        control = list(reltol = 1e-12, maxit = 1000L))$par[1L]
    }
    estimate <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
    expect_true(is.finite(estimate), info = class_name)
    expect_equal(estimate, unname(reference_beta), tolerance = 2e-4,
                 info = class_name)
    expect_true(is.na(private$weighted_refit_se()), info = class_name)
    expect_equal(inf$compute_estimate_with_bootstrap_weights(5 * weights, estimate_only = TRUE),
                 estimate, tolerance = 2e-4, info = class_name)
  }
})
