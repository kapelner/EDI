library(testthat)
library(EDI)

# inference_survival_rmst.R (InferenceSurvivalRestrictedMeanDiff) already has
# weighted/bootstrap-weights and all-censored bootstrap-fallback coverage in
# test-rmst-weighted-and-fallback-coverage.R. This file targets what that one
# does not reach: the ordinary (unweighted) compute_estimate()/
# compute_asymp_confidence_interval()/compute_asymp_two_sided_pval() Wald path
# with a genuinely finite Greenwood SE, the delta != 0 unsupported branch, the
# always-error compute_rand_confidence_interval(), and the left-/interval-
# censoring (has_general_censoring) dispatch to the Turnbull-NPMLE estimator
# and its bootstrap-fallback SE.

# Independent reference: per-arm KM restricted-mean and its Greenwood-type
# variance, computed from survival::survfit() output rather than calling any
# EDI internal, mirroring the variance formula documented in
# fast_survival_stats.cpp (Var(RMST) = sum_j A(t_j)^2 * d_j / (n_j*(n_j-d_j))).
km_rmst_and_se <- function(y, dead) {
  fit <- survival::survfit(survival::Surv(y, dead) ~ 1)
  tau <- max(y)
  times <- c(0, fit$time)
  surv <- c(1, fit$surv)
  area <- 0
  for (i in seq_len(length(times) - 1L)) area <- area + surv[i] * (times[i + 1L] - times[i])
  area <- area + surv[length(surv)] * (tau - times[length(times)])

  ev <- data.frame(time = fit$time, n.risk = fit$n.risk, n.event = fit$n.event, surv = fit$surv)
  ev <- ev[ev$n.event > 0, , drop = FALSE]
  K <- nrow(ev)
  if (K == 0L) return(list(rmst = area, se = 0))
  A <- numeric(K)
  A[K] <- ev$surv[K] * (tau - ev$time[K])
  if (K > 1L) for (k in (K - 1L):1L) A[k] <- A[k + 1L] + ev$surv[k] * (ev$time[k + 1L] - ev$time[k])
  var_rmst <- 0
  for (k in seq_len(K)) {
    nj <- ev$n.risk[k]; dj <- ev$n.event[k]
    if (nj > dj) var_rmst <- var_rmst + A[k]^2 * dj / (nj * (nj - dj))
  }
  list(rmst = area, se = sqrt(var_rmst))
}

rmst_wald_fixture <- function() {
  ctrl_y <- c(1, 2, 3, 4, 5, 6); ctrl_dead <- c(1, 0, 1, 1, 0, 1)
  trt_y  <- c(1.5, 2.5, 3, 4, 5, 7); trt_dead <- c(1, 1, 0, 1, 1, 0)
  y <- c(ctrl_y, trt_y); dead <- c(ctrl_dead, trt_dead); w <- rep(0:1, each = 6L)

  des <- DesignFixedBernoulli$new(n = 12L, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(12L)))
  des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(
    ifelse(dead == 1, y, NA_real_),
    ifelse(dead == 0, y, NA_real_),
    ifelse(dead == 0, Inf, NA_real_)
  )

  ref_c <- km_rmst_and_se(ctrl_y, ctrl_dead)
  ref_t <- km_rmst_and_se(trt_y, trt_dead)
  list(
    inf = InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE),
    rmst_diff = ref_t$rmst - ref_c$rmst,
    se_diff = sqrt(ref_t$se^2 + ref_c$se^2)
  )
}

test_that("unweighted compute_estimate matches an independent KM restricted-mean contrast and populates s_beta_hat_T", {
  f <- rmst_wald_fixture()
  expect_equal(f$inf$compute_estimate(), f$rmst_diff, tolerance = 1e-9)
  expect_equal(f$inf$.__enclos_env__$private$cached_values$s_beta_hat_T, f$se_diff, tolerance = 1e-9)

  # estimate_only = TRUE must skip the s_beta_hat_T side effect.
  f2 <- rmst_wald_fixture()
  expect_equal(f2$inf$compute_estimate(estimate_only = TRUE), f2$rmst_diff, tolerance = 1e-9)
  expect_null(f2$inf$.__enclos_env__$private$cached_values$s_beta_hat_T)
})

test_that("compute_asymp_confidence_interval uses the Greenwood-based Wald interval when SE is finite", {
  f <- rmst_wald_fixture()
  for (alpha in c(0.05, 0.2)) {
    ci <- f$inf$compute_asymp_confidence_interval(alpha = alpha)
    mult <- stats::qnorm(1 - alpha / 2)
    expect_equal(unname(ci), c(f$rmst_diff - mult * f$se_diff, f$rmst_diff + mult * f$se_diff), tolerance = 1e-9)
  }
})

test_that("compute_asymp_two_sided_pval at delta = 0 matches the two-sided z-test and rejects a nonzero null", {
  f <- rmst_wald_fixture()
  f$inf$compute_estimate()
  pval <- f$inf$compute_asymp_two_sided_pval()
  z <- f$rmst_diff / f$se_diff
  expect_equal(pval, 2 * min(stats::pnorm(z), 1 - stats::pnorm(z)), tolerance = 1e-9)

  f2 <- rmst_wald_fixture()
  f2$inf$compute_estimate()
  expect_error(f2$inf$compute_asymp_two_sided_pval(delta = 0.5), "TO-DO")
})

test_that("compute_asymp_two_sided_pval no longer returns a silent Inf when called before compute_estimate() (bug fixed)", {
  # Previously: unlike compute_asymp_confidence_interval() (which guards with
  # `if (is.null(private$cached_values$beta_hat_T)) self$compute_estimate()`),
  # compute_asymp_two_sided_pval() had no such guard: calling it on a fresh
  # object with neither compute_estimate() nor compute_asymp_confidence_interval()
  # called first divided a NULL beta_hat_T by a freshly computed s_beta_hat_T,
  # yielding a zero-length z and a silent Inf (with a "no non-missing arguments
  # to min" warning) instead of the correct p-value. Fixed by adding the same
  # `if (is.null(private$cached_values$beta_hat_T)) self$compute_estimate()`
  # guard used by compute_asymp_confidence_interval().
  f <- rmst_wald_fixture()
  pval <- f$inf$compute_asymp_two_sided_pval()
  z <- f$rmst_diff / f$se_diff
  expect_equal(pval, 2 * min(stats::pnorm(z), 1 - stats::pnorm(z)), tolerance = 1e-9)
  expect_true(is.finite(pval))
})

test_that("compute_rand_confidence_interval always errors with the units-mismatch message", {
  f <- rmst_wald_fixture()
  expect_error(
    f$inf$compute_rand_confidence_interval(),
    "Randomization confidence intervals are not supported.*inconsistent estimator units"
  )
})

general_censoring_design <- function() {
  # One interval-censored subject per arm (finite y_L and y_R) is sufficient
  # to flip Design$has_general_censoring() to TRUE; mix in exact-event and
  # ordinary right-censored subjects so the Turnbull fit is well identified.
  ys    <- c(1,   NA,  NA, 2.5, NA,  NA)
  y_Ls  <- c(NA,  3,   2,  NA,  4,   3)
  y_Rs  <- c(NA,  Inf, 5,  NA,  Inf, 6)
  w <- c(0, 0, 0, 1, 1, 1)
  des <- DesignFixedBernoulli$new(n = 6L, response_type = "survival", verbose = FALSE)
  des$add_all_subjects_to_experiment(data.frame(x = seq_len(6L)))
  des$overwrite_all_subject_assignments(w)
  des$add_all_subject_responses(ys, y_Ls, y_Rs)
  expect_true(des$has_general_censoring())
  des
}

test_that("general (interval-/left-) censoring routes compute_estimate through the Turnbull-NPMLE contrast", {
  skip_if_not_installed("interval")
  des <- general_censoring_design()
  inf <- InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
  reference <- EDI:::turnbull_npmle_stat_diff(
    des$get_y_L(), des$get_y_R(), des$get_w(), "restricted_mean"
  )
  expect_equal(inf$compute_estimate(estimate_only = TRUE), reference, tolerance = 1e-8)
})

test_that("general censoring rejects Bayesian-bootstrap weighted estimation and falls back to bootstrap SE", {
  skip_if_not_installed("interval")
  des <- general_censoring_design()
  inf <- InferenceSurvivalRestrictedMeanDiff$new(des, verbose = FALSE)
  expect_error(
    inf$compute_estimate_with_bootstrap_weights(rep(1, 6L)),
    "Bayesian bootstrap is not yet supported for left-/interval-censored survival data"
  )

  # compute_s_beta_hat_T() leaves s_beta_hat_T NA under general censoring (no
  # closed-form SE from interval::icfit()), which must route the asymp CI/pval
  # to the bootstrap fallback, exactly as the all-censored right-censoring case
  # already covers in test-rmst-weighted-and-fallback-coverage.R.
  generator <- R6::R6Class("InferenceSurvivalRestrictedMeanDiff",
    inherit = InferenceSurvivalRestrictedMeanDiff, parent_env = asNamespace("EDI"),
    lock_objects = FALSE,
    public = list(
      compute_bootstrap_confidence_interval = function(alpha = 0.05, ...) {
        private$fallback_calls$alpha <- alpha
        c(-9, 9)
      },
      compute_bootstrap_two_sided_pval = function(delta = 0, na.rm = FALSE, ...) {
        private$fallback_calls$delta <- delta
        0.5
      }
    ), private = list(fallback_calls = list()))
  inf2 <- generator$new(des, verbose = FALSE)
  ci <- inf2$compute_asymp_confidence_interval(alpha = 0.1)
  expect_identical(ci, c(-9, 9))
  expect_identical(inf2$compute_asymp_two_sided_pval(), 0.5)
  expect_true(is.na(inf2$.__enclos_env__$private$cached_values$s_beta_hat_T))
})
