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
# v1.0.6-TODO-219 (2026-11-24): the warning is gone. Retyping the stored column for every earlier subject
# changed later assignments and broke the analysis, so a changed type is now coerced back to the stored
# type, and a value that cannot be converted is refused with an error naming the column.

test_that("a later subject's covariate with an unconvertible changed data type is refused, naming the attribute and both types", {
	set.seed(1L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))

	expect_error(
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = "not_numeric", x2 = "b", stringsAsFactors = FALSE)),
		"covariate 'x1' of subject 2 is character (not_numeric) but was entered as numeric",
		fixed = TRUE
	)
	expect_equal(des$get_t(), 1)
	expect_true(is.numeric(des$get_X_raw()$x1))
})

test_that("subsequent subjects with the SAME covariate types as the first never trigger the warning", {
	set.seed(2L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))
	expect_no_warning(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 2.5, x2 = "b", stringsAsFactors = FALSE)))
	expect_no_warning(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 3.5, x2 = "c", stringsAsFactors = FALSE)))
})

test_that("a convertible data-type change on a column supplied in a different order is coerced back to the stored type (attributes matched by name, not position)", {
	set.seed(3L)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1.5, x2 = "a", stringsAsFactors = FALSE))

	expect_no_warning(des$add_one_subject_to_experiment_and_assign(data.frame(x2 = "b", x1 = TRUE)))
	expect_true(is.numeric(des$get_X_raw()$x1))
	expect_equal(des$get_X_raw()$x1, c(1.5, 1))
})
