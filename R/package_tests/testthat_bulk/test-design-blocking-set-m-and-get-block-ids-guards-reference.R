library(testthat)
library(EDI)

# DesignFixedBlocking (via the shared BlockingStructure component)'s set_m()/get_block_ids(): four guards with no
# prior test coverage. set_m(): (1) rejects a design that isn't blocking_capable, (2) rejects being called a
# second time once strata are already set (private$m is not NULL). get_block_ids(): (3) errors when no block ids
# can be found or derived at all, (4) errors when a found/derived block-id vector doesn't match the number of
# recorded responses. Existing coverage of this class only exercises the normal, successful block-derivation path.

blocking_fx <- function(seed = 2L, n = 20L) {
	set.seed(seed)
	g <- factor(rep(c("a", "b"), each = n / 2))
	des <- DesignFixedBlocking$new(strata_cols = "g", response_type = "continuous", n = n, seed = seed, verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(data.frame(g = g, x = rnorm(n)))
	des
}

test_that("set_m() succeeds once (before strata are set) and matches the requested block ids", {
	des <- blocking_fx()
	expect_null(des$.__enclos_env__$private$m)
	des$set_m(rep(1:4, 5))
	expect_equal(as.integer(table(des$get_block_ids())), rep(5L, 4L))
})

test_that("set_m() rejects being called a second time once strata are already set", {
	des <- blocking_fx()
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(des$get_n()))
	expect_false(is.null(des$.__enclos_env__$private$m))                  # derived automatically on assignment
	expect_error(
		des$set_m(rep(1:2, 10)),
		"set_m\\(\\) can only be called when the strata have not yet been set \\(private\\$m is not NULL\\)\\."
	)
})

test_that("set_m() rejects a design that isn't blocking_capable", {
	des <- blocking_fx()
	p <- des$.__enclos_env__$private
	unlockBinding("blocking_capable", p); p$blocking_capable <- FALSE
	expect_error(des$set_m(rep(1:4, 5)), "set_m\\(\\) can only be used with a blocking-capable design\\.")
})

test_that("get_block_ids() errors when no block ids can be found or derived at all", {
	des <- blocking_fx()
	des$assign_w_to_all_subjects(); des$add_all_subject_responses(rnorm(des$get_n()))
	p <- des$.__enclos_env__$private
	unlockBinding("m", p); p$m <- NULL
	unlockBinding("blocking_capable", p); p$blocking_capable <- FALSE     # forces past the strata-key fallback branch too
	expect_error(des$get_block_ids(), "Block identifiers are undefined for this design\\.")
})

test_that("get_block_ids() errors when the found block-id vector is the wrong length", {
	des <- blocking_fx()
	des$assign_w_to_all_subjects(); des$add_all_subject_responses(rnorm(des$get_n()))
	p <- des$.__enclos_env__$private
	unlockBinding("m", p); p$m <- 1:5                                     # wrong length vs. 20 responses
	unlockBinding("blocking_capable", p); p$blocking_capable <- FALSE
	expect_error(des$get_block_ids(), "Block identifiers are improperly sized for this design\\.")
})
