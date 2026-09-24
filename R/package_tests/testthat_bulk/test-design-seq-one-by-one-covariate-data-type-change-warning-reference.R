library(testthat)
library(EDI)

# DesignSeqOneByOne's private add_one_subject() (design_seq_one_by_one_abstract.R) compares each new
# subject's per-column data types (via get_column_types_cpp()) against the types established by the
# first subject; when a later subject's column has a DIFFERENT type from what was first recorded (e.g.
# numeric then character), it warns once per changed attribute: "You entered data type <new_type> for
# attribute named <col> that was previously entered with data type <established_type>". A codebase-wide
# grep confirmed this exact warning had zero test references anywhere, despite sequential designs
# (DesignSeqOneByOne* and its many concrete subclasses) being some of the most heavily tested classes in
# the whole suite -- every existing fixture consistently supplies the same covariate types across all
# subjects, so this drift-detection warning was never triggered.

test_that("a later subject's covariate with a changed data type triggers the documented warning, naming the attribute and both types", {
	set.seed(1L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))

	expect_warning(
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = "not_numeric", x2 = "b", stringsAsFactors = FALSE)),
		"You entered data type character for attribute named x1 that was previously entered with data type numeric",
		fixed = TRUE
	)
})

test_that("subsequent subjects with the SAME covariate types as the first never trigger the warning", {
	set.seed(2L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))
	expect_no_warning(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 2.5, x2 = "b", stringsAsFactors = FALSE)))
	expect_no_warning(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 3.5, x2 = "c", stringsAsFactors = FALSE)))
})

test_that("a data-type change on a column supplied in a different order still triggers the warning (attributes matched by name, not position)", {
	set.seed(3L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))

	expect_warning(
		des$add_one_subject_to_experiment_and_assign(data.frame(x2 = "b", x1 = TRUE)),
		"You entered data type logical for attribute named x1 that was previously entered with data type numeric",
		fixed = TRUE
	)
})
