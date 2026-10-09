library(testthat)
library(EDI)

kk_clmm_weighted_logit_fixture <- function() {
  withr::local_seed(715)
  y <- rep(1:3, length.out = 37L)
  des <- DesignSeqOneByOneKK14$new(n = length(y), response_type = "ordinal",
                                  verbose = FALSE)
  for (i in seq_along(y)) {
    des$add_one_subject_to_experiment_and_assign(data.frame(x = sin(i)))
    des$add_one_subject_response(i, y[i])
  }
  inf <- InferenceOrdinalKKCLMM$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  context <- private$build_bayesian_bootstrap_context()
  private$current_bayesian_bootstrap_context <- context
  list(inf = inf, private = private, context = context, y = y,
       w = des$get_w(), weights = rep(c(1, 2, 3, 2), length.out = context$n_units))
}

kk_clmm_weighted_logit_reference <- function(fixture, weights) {
  row_weights <- weights[fixture$context$row_to_unit]
  dat <- data.frame(y = ordered(fixture$y), w = fixture$w,
                    group_id = factor(fixture$private$clmm_group_id()),
                    weight = row_weights)
  ordinal::clmm(y ~ w + (1 | group_id), data = dat[row_weights > 0, ],
                weights = weight, link = "logit", nAGQ = 20L, Hess = TRUE)
}

test_that("KK CLMM logit expands matched-unit weights and retains the random intercept", {
  skip_if_not_installed("ordinal")
  fixture <- kk_clmm_weighted_logit_fixture()
  sizes <- tabulate(fixture$context$row_to_unit)
  expect_true(any(sizes == 2L))
  expect_true(any(sizes == 1L))
  expect_true(all(sizes %in% c(1L, 2L)))
  reference <- kk_clmm_weighted_logit_reference(fixture, fixture$weights)
  beta <- unname(coef(reference)["w"])
  se <- sqrt(unname(vcov(reference)["w", "w"]))
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(fixture$weights),
               beta, tolerance = 1e-6)
  expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T, se, tolerance = 1e-6)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(
    fixture$weights, estimate_only = TRUE), beta, tolerance = 2e-5)
  expect_true(is.na(fixture$private$last_weighted_refit$s_beta_hat_T))
})

test_that("KK CLMM logit excludes whole zero-weight pairs and reservoir subjects", {
  skip_if_not_installed("ordinal")
  fixture <- kk_clmm_weighted_logit_fixture()
  sizes <- tabulate(fixture$context$row_to_unit)
  zero_units <- c(which(sizes == 2L)[1L], which(sizes == 1L)[1L])
  weights <- fixture$weights
  weights[zero_units] <- 0
  expect_equal(sum(weights[fixture$context$row_to_unit] == 0), 3L)
  reference <- kk_clmm_weighted_logit_reference(fixture, weights)
  beta <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
  expect_equal(beta, unname(coef(reference)["w"]), tolerance = 1e-6)
  expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T,
               sqrt(unname(vcov(reference)["w", "w"])), tolerance = 2e-5)
  expect_true(is.na(fixture$inf$compute_estimate_with_bootstrap_weights(weights * 0)))
  expect_true(is.na(fixture$private$last_weighted_refit$s_beta_hat_T))
})

test_that("KK CLMM logit can reuse an ordinal coefficient and information warm start", {
  skip_if_not_installed("ordinal")
  fixture <- kk_clmm_weighted_logit_fixture()
  reference <- kk_clmm_weighted_logit_reference(fixture, fixture$weights)
  params <- unname(coef(reference))
  fisher <- solve(vcov(reference))
  fixture$private$set_fit_warm_start(params, "params", fisher = fisher)
  expect_equal(fixture$private$get_fit_warm_start_for_length("params", 3L), params)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(fixture$weights),
               unname(coef(reference)["w"]), tolerance = 1e-6)
  expect_equal(fixture$private$last_weighted_refit$s_beta_hat_T,
               sqrt(unname(vcov(reference)["w", "w"])), tolerance = 2e-5)
  expect_equal(fixture$private$get_fit_warm_start_for_length("params", 3L), params)
})
