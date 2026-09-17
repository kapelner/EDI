library(testthat)
library(EDI)

test_that("sequential arrivals fill both new and omitted covariates by subject", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 641)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0, site = "A"))
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 2.0, site = "B", score = 5.0))
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 3.0, site = "C"))
  expect_equal(as.data.frame(des$get_X_raw()),
               data.frame(x = c(1, 2, 3), site = c("A", "B", "C"),
                          score = c(NA_real_, 5, NA_real_)))
  expect_false(des$is_fixed_sample_size())
  expect_identical(des$get_t(), 3L)
  expect_equal(des$get_n(), 3)
  expect_length(des$get_w(), 3L)
  expect_true(all(des$get_w() %in% c(0, 1)))
})

test_that("new logical integer and categorical covariates preserve their values", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 642)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0))
  des$add_one_subject_to_experiment_and_assign(
    data.frame(x = 2.0, flag = TRUE, count = 7L, group = factor("new")))
  raw <- as.data.frame(des$get_X_raw())
  expect_identical(names(raw), c("x", "flag", "count", "group"))
  expect_true(all(is.na(raw[1L, c("flag", "count", "group")])))
  expect_equal(as.numeric(raw$flag[2L]), 1)
  expect_equal(raw$count[2L], 7)
  expect_equal(as.character(raw$group[2L]), "new")
})

test_that("rejecting a schema change leaves arrival and assignment state intact", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 643)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0))
  before <- as.data.frame(des$get_X_raw())
  assignment <- des$get_w()
  expect_error(des$add_one_subject(data.frame(z = 2.0), allow_new_cols = FALSE),
               "allow_new_cols = TRUE", fixed = TRUE)
  expect_equal(as.data.frame(des$get_X_raw()), before)
  expect_identical(des$get_t(), 1L)
  expect_identical(des$get_w(), assignment)
})
