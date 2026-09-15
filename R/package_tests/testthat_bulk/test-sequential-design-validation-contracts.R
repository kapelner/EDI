library(testthat)
library(EDI)

test_that("cross-argument validation helpers reject inconsistent inputs", {
  expect_error(EDI:::assertBootstrapArgs(5, min_number_usable_samples = 6, context = "unit test"),
               "less than or equal to B")
  expect_error(EDI:::assertBootstrapArgs(5, type = "bad", allowed_types = c("basic", "percentile")),
               "Must be element")
  expect_null(EDI:::assertBootstrapArgs(10, 5, "basic", c("basic")))

  dat <- data.frame(x = 1:3, group = factor(c("a", "b", "a")))
  expect_null(EDI:::assertFormulaContext(~ x, dat))
  expect_error(EDI:::assertFormulaContext(~ absent, dat, "analysis formula"), "absent")
  expect_error(EDI:::assertStrataClusterArgs("group", "group", dat), "must not also appear")
  expect_error(EDI:::assertStrataClusterArgs("missing", NULL, dat), "not present")
  expect_error(EDI:::assertStrataClusterArgs("x", NULL, dat, TRUE), "factor/categorical")
})

test_that("response assertions distinguish type and censoring contracts", {
  expect_null(EDI:::assertResponseType("count", "count"))
  expect_error(EDI:::assertResponseType("continuous", "count"), "count")
  expect_null(EDI:::assertNoCensoring(FALSE))
  expect_error(EDI:::assertNoCensoring(TRUE), "censor")
})

test_that("optional-package checks are memoized and informative", {
  fake <- "EDI_package_that_cannot_exist_20260916"
  expect_false(check_package_installed(fake))
  expect_true(exists(fake, envir = EDI:::package_cache, inherits = FALSE))
  expect_false(check_package_installed(fake))
  expect_true(check_package_installed("stats"))
  expect_null(EDI:::print_progress(NULL, 1, 2))
})

test_that("sequential base rejects malformed subject rows and unsupported columns", {
  des <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", n = 3)
  expect_error(des$add_one_subject_to_experiment_and_assign(data.frame(x = 1:2)), "one subject")
  expect_error(des$add_one_subject_to_experiment_and_assign(data.frame(x = ordered("a"))), "Ordered factor")
  expect_error(des$add_one_subject_to_experiment_and_assign(data.frame(x = as.Date("2026-01-01"))), "Date")
})

test_that("Efron biased coin deterministically favors the underrepresented arm at probability one", {
  des <- DesignSeqOneByOneEfron$new(response_type = "continuous", n = 3,
                                    weighted_coin_prob = 1, seed = 201)
  first <- des$add_one_subject_to_experiment_and_assign(data.frame(x = 1))
  second <- des$add_one_subject_to_experiment_and_assign(data.frame(x = 2))
  expect_true(first %in% c(0, 1))
  expect_identical(second, 1 - first)
})

test_that("SPBR validates integer treatment counts and balances each completed block", {
  expect_error(DesignSeqOneByOneSPBR$new("site", block_size = 3, response_type = "continuous",
                                         prob_T = 0.5, n = 4), "integer number")
  des <- DesignSeqOneByOneSPBR$new("site", block_size = 4, response_type = "continuous",
                                   prob_T = 0.5, n = 4, seed = 202)
  for (i in 1:4) des$add_one_subject_to_experiment_and_assign(data.frame(site = factor("A")))
  expect_equal(sum(des$get_w()), 2)
  expect_true(des$is_blocking_design())
})

test_that("Pocock-Simon validates weights and rejects continuous strata", {
  expect_error(DesignSeqOneByOnePocockSimon$new("site", weights = c(1, 2),
                                                response_type = "continuous", n = 3), "length 1")
  expect_error(DesignSeqOneByOnePocockSimon$new("site", p_best = 0.4,
                                                response_type = "continuous", n = 3), "not >= 0.5")
  des <- DesignSeqOneByOnePocockSimon$new("site", response_type = "continuous", n = 3)
  expect_error(des$add_one_subject_to_experiment_and_assign(data.frame(site = 1.2)),
               "factor/categorical")
})

test_that("KK21 validates weight-estimation controls and exposes empty history", {
  expect_error(DesignSeqOneByOneKK21$new("continuous", n = 6, num_boot = 0), "Must be >= 1")
  expect_error(DesignSeqOneByOneKK21$new("continuous", n = 6, count_use_speedup = NA), "May not be NA")
  des <- DesignSeqOneByOneKK21$new("continuous", n = 6, num_boot = 5, seed = 203)
  expect_identical(des$get_iteration_weights(), list())
  expect_null(des$get_covariate_weights())
  w <- des$add_one_subject_to_experiment_and_assign(data.frame(x = 1))
  expect_true(w %in% c(0, 1))
  expect_identical(des$get_iteration_weights(), list())
})
