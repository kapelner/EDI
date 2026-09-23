library(testthat)
library(EDI)

# design_seq_one_by_one_abstract.R's DesignSeqOneByOne has a private assign_wt() stub ("Must be
# implemented by subclass.") that every real concrete sequential design overrides -- the sequential-
# design sibling of DesignFixed's own draw_ws_raw() stub
# (test-design-fixed-draw-ws-raw-must-implement-guard-reference.R). Since DesignSeqOneByOne itself
# refuses direct instantiation, exercised the same way: a minimal concrete R6 subclass that inherits
# DesignSeqOneByOne without overriding assign_wt(), reached through
# add_one_subject_to_experiment_and_assign(). Zero test references anywhere.

test_that("a DesignSeqOneByOne subclass that never overrides assign_wt() errors with the documented message", {
	DesignSeqOneByOne <- getFromNamespace("DesignSeqOneByOne", "EDI")
	TmpNoAssignWt <- R6::R6Class("TmpNoAssignWt", inherit = DesignSeqOneByOne, lock_objects = FALSE)

	d <- TmpNoAssignWt$new(response_type = "continuous", verbose = FALSE)
	expect_error(
		d$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1L))),
		"Must be implemented by subclass\\."
	)
})

test_that("a real concrete sequential design overrides assign_wt and assigns without error", {
	des <- DesignSeqOneByOneBernoulli$new(response_type = "continuous", verbose = FALSE)
	expect_no_error(des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1L))))
})
