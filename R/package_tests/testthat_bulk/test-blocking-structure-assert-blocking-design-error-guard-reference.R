library(testthat)
library(EDI)

# design_blocking_abstract.R's assert_blocking_design() (composed by every concrete class listing
# the BlockingStructure component) stop()s "This design requires a blocking design." whenever
# is_blocking_design() is FALSE. Every current concrete class composing BlockingStructure
# (DesignFixedBlocking, DesignFixedOptimalBlocks, DesignFixedIBCRD, DesignSeqOneByOneIBCRD,
# DesignObservationalBlocks, DesignFixedBlockedCluster, DesignSeqOneByOneSPBR,
# DesignSeqOneByOneRandomBlockSize) sets private$blocking_capable = TRUE unconditionally in its own
# initialize(), so the success path (is_blocking_design() == TRUE) is exercised constantly but the
# actual stop() itself is never naturally reachable through any current construction path -- the
# existing test file for this component (test-blocking-structure-manual-block-ids-completeness-
# equal-size-assertion-and-block-summaries-reference.R) only confirms the method is silent when
# blocking IS present and that it's absent entirely on a non-composing class, never that it actually
# errors. Exercised the same way this session has tested other structurally-real-but-not-naturally-
# reachable guards: directly nulling the private blocking_capable/m fields on an already-constructed
# object (mirrors the sibling assert_matching_design()'s already-tested error path, which IS
# naturally reachable since matching_capable is set conditionally on some classes).

test_that("assert_blocking_design(): a construction-time blocking design does not error", {
	set.seed(1)
	des <- DesignFixedBlocking$new(response_type = "continuous", n = 12L, verbose = FALSE)
	expect_true(des$is_blocking_design())
	expect_silent(des$assert_blocking_design())
})

test_that("assert_blocking_design(): forcing is_blocking_design() to FALSE errors with the documented message", {
	set.seed(2)
	des <- DesignFixedBlocking$new(response_type = "continuous", n = 12L, verbose = FALSE)
	priv <- des$.__enclos_env__$private
	unlockBinding("blocking_capable", priv)
	priv$blocking_capable <- FALSE
	priv$m <- NULL

	expect_false(des$is_blocking_design())
	expect_error(des$assert_blocking_design(), "This design requires a blocking design\\.")
})

test_that("a design not composing BlockingStructure does not expose assert_blocking_design at all", {
	des <- DesignFixedBernoulli$new(response_type = "continuous", n = 12L, verbose = FALSE)
	expect_false(is.function(des$assert_blocking_design))
})
