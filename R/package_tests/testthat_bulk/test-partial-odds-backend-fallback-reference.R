library(testthat)
library(EDI)

partial_odds_fallback_fixture <- function(no_fit = FALSE, missing_se = FALSE) {
  # Control CDFs are .25,.75; treatment CDFs are .10,.50.
  # Both cumulative logits differ by exactly log(3).
  y <- c(rep(1:3, c(5, 10, 5)), rep(1:3, c(2, 8, 10)))
  des <- DesignFixedBernoulli$new(n = 40L, response_type = "ordinal", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(40L)))
  des$overwrite_all_subject_assignments(rep(c(0, 1), each = 20L))
  des$add_all_subject_responses(y)
  # Exercise the optional-backend cascade when preceding backends are unavailable.
  disabled <- list(
    fit_fast_proportional_odds = function(...) NULL,
    fit_vgam = function(...) NULL,
    fit_clm = function(...) NULL,
    fit_fast_proportional_odds_weighted = function(...) NULL,
    fit_vgam_weighted = function(...) NULL,
    fit_clm_weighted = function(...) NULL
  )
  if (no_fit || missing_se) disabled$fit_polr <- function(...) NULL
  if (missing_se) {
    disabled$fit_fast_proportional_odds <- function(...) list(beta = log(3), se = NA_real_)
  }
  generator <- R6::R6Class("InferenceOrdinalPartialProportionalOddsRegr",
    inherit = InferenceOrdinalPartialProportionalOddsRegr, parent_env = asNamespace("EDI"),
    lock_objects = FALSE, private = disabled)
  inf <- generator$new(des, model_formula = ~ 1, verbose = FALSE)
  private <- inf$.__enclos_env__$private
  list(inf = inf, private = private)
}

test_that("partial odds MASS fallback recovers a common empirical cumulative-logit shift", {
  fixture <- partial_odds_fallback_fixture()
  inf <- fixture$inf
  expect_equal(inf$compute_estimate(), log(3), tolerance = 1e-4)
  expect_equal(inf$compute_asymp_two_sided_pval(delta = log(3)), 1, tolerance = 1e-4)
  ci <- inf$compute_asymp_confidence_interval(alpha = 0.2)
  expect_true(all(is.finite(ci)))
  expect_lt(ci[1L], log(3))
  expect_gt(ci[2L], log(3))
})

test_that("partial odds records unavailable fits when every backend fails", {
  fixture <- partial_odds_fallback_fixture(no_fit = TRUE)
  expect_true(is.na(fixture$inf$compute_estimate()))
  expect_true(fixture$inf$is_nonestimable("estimate"))
  expect_identical(fixture$inf$get_nonestimable_reason(), "ppor_fit_unavailable")
  expect_true(all(is.na(fixture$inf$compute_asymp_confidence_interval())))
})

test_that("partial odds retains a point estimate when every standard error is unavailable", {
  fixture <- partial_odds_fallback_fixture(missing_se = TRUE)
  expect_equal(fixture$inf$compute_estimate(), log(3))
  expect_false(fixture$inf$is_nonestimable("estimate"))
  expect_identical(fixture$inf$get_nonestimable_reason(), "ppor_standard_error_unavailable")
  expect_true(all(is.na(fixture$inf$compute_asymp_confidence_interval())))
  expect_true(is.na(fixture$inf$compute_asymp_two_sided_pval()))
})

test_that("weighted partial odds MASS fallback preserves a common armwise odds shift", {
  fixture <- partial_odds_fallback_fixture()
  p <- fixture$private
  p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
  # Each arm's category proportions stay fixed when its subjects share a weight.
  # Both cumulative-logit treatment shifts therefore remain exactly log(3).
  weights <- rep(c(2, 3), each = 20L)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(weights),
               log(3), tolerance = 5e-4)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(5 * weights),
               log(3), tolerance = 5e-4)
  expect_true(is.na(p$cached_values$s_beta_hat_T))
})
