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

test_that("reordered sequential covariates bind by attribute name without type warnings", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 644)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0, site = "A", count = 2L))
  expect_warning(des$add_one_subject_to_experiment_and_assign(
    data.frame(count = 7L, site = "B", x = 3.0)), NA)
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(x = c(1, 3), site = c("A", "B"), count = c(2L, 7L)))
  expect_identical(des$get_t(), 2L)
  expect_length(des$get_w(), 2L)
})

test_that("simultaneously new and omitted covariates retain established column order", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 645)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0, site = "A", count = 2L))
  des$add_one_subject_to_experiment_and_assign(data.frame(score = 8.0, x = 3.0))
  des$add_one_subject_to_experiment_and_assign(data.frame(site = "C", count = 9L, x = 5.0))
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(x = c(1, 3, 5), site = c("A", NA_character_, "C"),
      count = c(2, NA_real_, 9), score = c(NA_real_, 8, NA_real_)))
  expect_identical(des$get_t(), 3L)
  expect_length(des$get_w(), 3L)
})

test_that("reordered factor and logical attributes retain their classes and values", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 646)
  des$add_one_subject_to_experiment_and_assign(
    data.frame(site = factor("A", levels = c("A", "B")), flag = TRUE, x = 1.0))
  expect_warning(des$add_one_subject_to_experiment_and_assign(
    data.frame(x = 2.0, flag = FALSE, site = factor("B", levels = c("A", "B")))), NA)
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(site = factor(c("A", "B")), flag = c(TRUE, FALSE), x = c(1, 2)))
})

test_that("a closed sequential schema accepts reordered attributes and warns on genuine type changes", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 647)
  des$add_one_subject(data.frame(x = 1.0, site = "A"))
  expect_warning(des$add_one_subject(data.frame(site = "B", x = 2.0), allow_new_cols = FALSE), NA)
  expect_warning(des$add_one_subject(data.frame(site = "C", x = "three"), allow_new_cols = FALSE),
    "character for attribute named x that was previously entered with data type numeric", fixed = TRUE)
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(x = c("1", "2", "three"), site = c("A", "B", "C")))
})

test_that("name alignment remains enforced with argument assertions disabled", {
  old_options <- options(edi.run_asserts = FALSE)
  on.exit(options(old_options), add = TRUE)
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 648)
  arrivals <- list(data.frame(x = 1.0, site = "A"),
    data.frame(site = "B", x = 2.0), data.frame(score = 7.0, x = 3.0))
  for (row in arrivals) des$add_one_subject_to_experiment_and_assign(row)
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(x = c(1, 2, 3), site = c("A", "B", NA_character_),
      score = c(NA_real_, NA_real_, 7)))
  expect_identical(des$get_t(), 3L)
  expect_length(des$get_w(), 3L)
})

test_that("missing attributes in the first sequential arrival do not create extra subjects", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 649)
  des$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0, score = NA_real_, site = "A"))
  expect_equal(as.data.frame(des$get_X_raw()), data.frame(x = 1.0, site = "A"))
  expect_identical(des$get_t(), 1L)
  expect_length(des$get_w(), 1L)
  # A previously unobserved attribute can still arrive later using the
  # default open schema, with its earlier value padded as missing.
  des$add_one_subject_to_experiment_and_assign(data.frame(score = 7.0, site = "B", x = 2.0))
  expect_equal(as.data.frame(des$get_X_raw()),
    data.frame(x = c(1, 2), site = c("A", "B"), score = c(NA_real_, 7)))
  expect_identical(des$get_t(), 2L)
  expect_length(des$get_w(), 2L)
})

test_that("a closed first-arrival schema warns before rejecting later missing attributes", {
  des <- DesignSeqOneByOneBernoulli$new("continuous", seed = 650)
  expect_warning(des$add_one_subject(data.frame(x = 1.0, score = NA_real_, site = "A"), allow_new_cols = FALSE),
    "missing data in the first subject's covariate", fixed = TRUE)
  expect_equal(as.data.frame(des$get_X_raw()), data.frame(x = 1.0, site = "A"))
  expect_warning(des$add_one_subject(data.frame(site = "B", x = 2.0), allow_new_cols = FALSE), NA)
  before <- as.data.frame(des$get_X_raw())
  expect_error(des$add_one_subject(data.frame(x = 3.0, site = "C", score = 7.0), allow_new_cols = FALSE),
    "allow_new_cols = TRUE", fixed = TRUE)
  expect_equal(as.data.frame(des$get_X_raw()), before)
  expect_identical(des$get_t(), 2L)
})
