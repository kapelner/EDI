library(testthat)
library(EDI)

# Design$add_one_subject_response(t, y) (design_abstract.R:296-297) warns rather than silently
# overwriting when a response is already recorded for subject t -- warning(paste("Overwriting
# previous response for t =", t)). A codebase-wide grep confirmed this exact message had zero test
# references anywhere, despite add_one_subject_response()'s several stop() shape guards (already
# closed earlier this session in test-design-add-one-subject-response-y-bounds-validation-guards-
# reference.R) being well covered. Exercised via the plain public API: recording a response for the
# same subject twice.

test_that("recording a second response for the same subject warns with the documented message", {
	set.seed(1)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1))
	des$add_one_subject_response(1, 5)

	expect_warning(
		des$add_one_subject_response(1, 7),
		"Overwriting previous response for t = 1",
		fixed = TRUE
	)
	expect_equal(des$get_y()[1], 7)
})

test_that("the first response for a subject never triggers the warning", {
	set.seed(2)
	des <- DesignSeqOneByOneBernoulli$new(n = 5L, response_type = "continuous", verbose = FALSE)
	des$add_one_subject_to_experiment_and_assign(data.frame(x1 = 1))
	expect_no_warning(des$add_one_subject_response(1, 5))
})
