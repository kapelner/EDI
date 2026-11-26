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
  expect_true(is.na(p$last_weighted_refit$s_beta_hat_T))
})

# docs-claims audit, finding docs-claims-d38c37c85: "unavailable packages are silently skipped in
# favor of the next fallback" -- simulate real package absence through the package-availability
# check (check_package_installed() wraps requireNamespace()) instead of stubbing the fitters.
ppo_absent_pkg_fixture <- function(nonparallel = character(0), disable_fast = FALSE) {
  set.seed(31)
  n <- 90L
  x1 <- rnorm(n)
  trt <- rep(0:1, length.out = n)
  y <- as.integer(cut(qlogis(runif(n)) + 0.7 * trt + 0.5 * x1, c(-Inf, -0.7, 0.7, Inf)))
  des <- DesignFixedBernoulli$new(n = n, response_type = "ordinal", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x1 = x1))
  des$overwrite_all_subject_assignments(trt)
  des$add_all_subject_responses(y)
  gen <- if (disable_fast) {
    R6::R6Class("InferenceOrdinalPartialProportionalOddsRegr",
      inherit = InferenceOrdinalPartialProportionalOddsRegr, parent_env = asNamespace("EDI"),
      lock_objects = FALSE, private = list(fit_fast_proportional_odds = function(...) NULL))
  } else InferenceOrdinalPartialProportionalOddsRegr
  inf <- gen$new(des, model_formula = ~ x1, nonparallel = nonparallel, verbose = FALSE)
  list(inf = inf, y = y, trt = trt, x1 = x1)
}

test_that("with VGAM unavailable, a non-parallel fit silently falls through to ordinal::clm", {
  skip_if_not_installed("ordinal")
  asked <- character(0)
  local_mocked_bindings(check_package_installed = function(package_name) {
    asked <<- c(asked, package_name); !identical(package_name, "VGAM")
  }, .package = "EDI")
  f <- ppo_absent_pkg_fixture(nonparallel = "x1")
  expect_no_error(est <- f$inf$compute_estimate())
  expect_true(all(c("VGAM", "ordinal") %in% asked))
  dat <- data.frame(y = ordered(f$y), treatment = f$trt, x1 = f$x1)
  ref <- suppressWarnings(ordinal::clm(y ~ treatment, nominal = ~ x1, data = dat, link = "logit"))
  expect_equal(est, unname(coef(ref)[["treatment"]]), tolerance = 1e-4)
  expect_true(is.finite(f$inf$compute_asymp_two_sided_pval()))
})

test_that("with VGAM and ordinal both unavailable, a parallel fit silently falls through to MASS::polr", {
  asked <- character(0)
  local_mocked_bindings(check_package_installed = function(package_name) {
    asked <<- c(asked, package_name); !(package_name %in% c("VGAM", "ordinal"))
  }, .package = "EDI")
  f <- ppo_absent_pkg_fixture(disable_fast = TRUE)
  expect_no_error(est <- f$inf$compute_estimate())
  expect_true(all(c("VGAM", "ordinal") %in% asked))
  ref <- suppressWarnings(MASS::polr(ordered(f$y) ~ f$trt + f$x1, method = "logistic", Hess = TRUE))
  expect_equal(est, unname(coef(ref)[1]), tolerance = 1e-4)
  expect_equal(f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T, sqrt(vcov(ref)[1, 1]), tolerance = 1e-3)
})

# docs-claims audit, finding docs-claims-d38c37c85: when every weighted backend fails, the weighted
# refit falls back to weighted_ordinal_bootstrap_surrogate_fit(..., method = "logistic").
test_that("weighted refit falls back to weighted proportional odds with NA SE", {
  fixture <- partial_odds_fallback_fixture()
  p <- fixture$private
  unlockBinding("fit_polr_weighted", p)
  p$fit_polr_weighted <- function(...) NULL
  p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
  set.seed(8)
  weights <- sample(1:4, 40L, replace = TRUE)
  got <- fixture$inf$compute_estimate_with_bootstrap_weights(weights)
  y <- c(rep(1:3, c(5, 10, 5)), rep(1:3, c(2, 8, 10)))
  treatment <- rep(c(0, 1), each = 20L)
  dat <- data.frame(y = ordered(y), treatment = treatment, weight = weights / mean(weights))
  ref <- suppressWarnings(MASS::polr(y ~ treatment, data = dat, weights = weight, method = "logistic",
    control = list(reltol = 1e-10)))
  expect_equal(got, unname(coef(ref)[["treatment"]]), tolerance = 1e-5)
  expect_true(is.finite(got))
  expect_true(is.na(p$last_weighted_refit$s_beta_hat_T))
  sur <- EDI:::weighted_ordinal_bootstrap_surrogate_fit(
    X = cbind(treatment = treatment), y = y, row_weights = weights, method = "logistic")
  expect_identical(sur$fit_type, "polr_logistic")
})
