library(testthat)
library(EDI)

# design_seq_one_by_one_abstract.R's add_one_subject() rejects two specific unsupported covariate
# column data types on the incoming subject row -- ordered factors ("Ordered factor data type is not
# supported; please convert to either an unordered factor or numeric.") and Date columns ("Date data
# type is not supported; please convert to numeric.") -- always-on checks (should_run_asserts()-
# gated, the package default), reached via the public add_one_subject_to_experiment_and_assign()
# entry point. Neither guard had any test references anywhere.

test_that("add_one_subject_to_experiment_and_assign(): an ordered-factor covariate column errors with the documented message", {
	des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_error(
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = factor("a", levels = c("a", "b"), ordered = TRUE))),
		"Ordered factor data type is not supported; please convert to either an unordered factor or numeric\\."
	)
})

test_that("add_one_subject_to_experiment_and_assign(): a Date covariate column errors with the documented message", {
	des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_error(
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = as.Date("2020-01-01"))),
		"Date data type is not supported; please convert to numeric\\."
	)
})

test_that("add_one_subject_to_experiment_and_assign(): an unordered factor or numeric column does not error", {
	des <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_no_error(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = factor("a", levels = c("a", "b")))))

	des2 <- DesignSeqOneByOneBernoulli$new(n = 4L, response_type = "continuous", verbose = FALSE)
	expect_no_error(des2$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5)))
})
