library(testthat)
library(EDI)

make_contract_design <- function(response_type, y, seed = 20260915L) {
  set.seed(seed)
  n <- length(y)
  x <- rnorm(n)
  des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = response_type,
                                        design_formula = ~ ., seed = seed)
  for (i in seq_len(n)) {
    des$add_one_subject_to_experiment_and_assign(
      data.frame(x = x[i], duplicate = x[i], constant = 1)
    )
  }
  des$add_all_subject_responses(y)
  des
}

test_that("count and proportion regression constructors reject the wrong response family", {
  count_des <- make_contract_design("count", rep(c(0L, 1L, 2L, 4L), 8))
  prop_des <- make_contract_design("proportion", rep(c(0, 0.2, 0.7, 1), 8))

  expect_error(InferenceCountQuasiPoisson$new(prop_des), "count")
  expect_error(InferenceCountRobustPoisson$new(prop_des), "count")
  expect_error(InferencePropFractionalLogit$new(count_des), "proportion")
  expect_error(InferencePropBetaRegr$new(count_des), "proportion")
})

test_that("count quasi and robust fits drop duplicate/constant columns but preserve treatment", {
  set.seed(20260916)
  y <- rpois(48, lambda = rep(c(1.5, 3), 24))
  des <- make_contract_design("count", y, seed = 20260916L)

  for (generator in list(InferenceCountQuasiPoisson, InferenceCountRobustPoisson)) {
    inf <- generator$new(des, model_formula = ~ x + duplicate + constant)
    estimate <- inf$compute_estimate()
    expect_true(is.finite(estimate))
    expect_false(inf$is_nonestimable())
    expect_equal(inf$compute_estimate(estimate_only = TRUE), estimate)
    expect_true(all(is.finite(inf$compute_asymp_confidence_interval())))
    pval <- inf$compute_asymp_two_sided_pval()
    expect_true(is.finite(pval) && pval >= 0 && pval <= 1)
    expect_identical(inf$get_supported_testing_types(), "wald")
    expect_error(inf$set_testing_type("lik_ratio"), "supported|likelihood|testing")
  }
})

test_that("fractional logit unhardened estimate-only fast path is cached", {
  set.seed(20260917)
  n <- 60L
  eta <- rep(c(-0.6, 0.6), n / 2) + rnorm(n, sd = 0.2)
  y <- plogis(eta + rnorm(n, sd = 0.35))
  des <- make_contract_design("proportion", y, seed = 20260917L)
  inf <- InferencePropFractionalLogit$new(
    des, model_formula = ~ x + duplicate + constant, harden = FALSE
  )

  first <- inf$compute_estimate(estimate_only = TRUE)
  second <- inf$compute_estimate(estimate_only = TRUE)
  expect_true(is.finite(first))
  expect_identical(second, first)
  expect_identical(inf$get_supported_testing_types(), "wald")
  expect_error(inf$set_testing_type("score"), "supported|likelihood|testing")
})

test_that("proportion model formula validation rejects non-formulas", {
  des <- make_contract_design("proportion", rep(c(0.1, 0.3, 0.6, 0.9), 8))
  expect_error(InferencePropFractionalLogit$new(des, model_formula = "x"), "formula")
  expect_error(InferencePropBetaRegr$new(des, model_formula = 42), "formula")
})
