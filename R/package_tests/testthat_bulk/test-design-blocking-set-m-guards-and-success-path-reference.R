library(testthat)
library(EDI)

# The BlockingStructure component's public set_m(m) (design_blocking_abstract.R) had zero test
# references anywhere: add_all_subject_matched_pair_ids() (the sibling, already-blocking-capable-only
# setter) is exercised elsewhere, but set_m() itself -- meant for a user to manually supply strata
# post-construction, before the design derives its own -- was never called. Two guards:
#   1. "can only be used with a blocking-capable design": every real BlockingStructure-composing class
#      (DesignFixedBlocking, DesignFixedOptimalBlocks, DesignFixedIBCRD, ...) sets private$blocking_capable
#      = TRUE unconditionally in its own initialize(), so this branch is structurally unreachable through
#      any real constructed class -- reached instead via the established direct-private-state-injection
#      pattern this suite already uses for such invariant guards.
#   2. "can only be called when the strata have not yet been set": genuinely reachable -- DesignFixedBlocking
#      with no explicit m/strata_cols leaves private$m NULL until set_m() (or assignment) is called.
# Also covers the success path (m is stored as integer(), get_block_ids() reflects it, is_blocking_design()
# becomes TRUE) and the assertIntegerish() shape guard (m must be non-negative, integer-valued, non-empty).

test_that("set_m() rejects a design that isn't blocking-capable (direct private-state injection: no real class leaves this reachable otherwise)", {
	d <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	p <- d$.__enclos_env__$private
	unlockBinding("blocking_capable", p); on.exit(p$blocking_capable <- TRUE, add = TRUE)
	p$blocking_capable <- FALSE
	expect_error(d$set_m(rep(1:2, each = 4)), "set_m\\(\\) can only be used with a blocking-capable design")
})

test_that("set_m() succeeds once on a fresh blocking-capable design with no strata yet, and get_block_ids()/is_blocking_design() reflect it", {
	d <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	p <- d$.__enclos_env__$private
	expect_null(p$m)
	expect_true(d$is_blocking_design())  # already TRUE via blocking_capable, before m is ever set

	ret <- d$set_m(c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L))
	expect_identical(ret, d)  # invisible(self) for chaining
	expect_identical(p$m, c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L))
	expect_true(d$is_blocking_design())
	expect_identical(d$get_block_ids(), c(1L, 1L, 1L, 1L, 2L, 2L, 2L, 2L))
})

test_that("set_m() refuses to overwrite already-set strata (private$m is not NULL)", {
	d <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	d$set_m(rep(1:2, each = 4))
	expect_error(d$set_m(rep(1:4, each = 2)), "set_m\\(\\) can only be called when the strata have not yet been set")
	# the original strata are untouched by the rejected call
	expect_identical(d$.__enclos_env__$private$m, rep(1:2, each = 4))
})

test_that("set_m() enforces the assertIntegerish(m, lower = 0, any.missing = FALSE, min.len = 1) shape guard", {
	d <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	expect_error(d$set_m(integer(0)))
	expect_error(d$set_m(rep(c(1L, NA_integer_), 4)))
	expect_error(d$set_m(rep(-1L, 8L)))
	expect_error(d$set_m(rep(1.5, 8)))

	# 0 is explicitly allowed (documented as the sequential-KK reservoir flag)
	d2 <- DesignFixedBlocking$new(n = 4L, response_type = "continuous", verbose = FALSE)
	d2$set_m(c(0L, 0L, 1L, 1L))
	expect_identical(d2$.__enclos_env__$private$m, c(0L, 0L, 1L, 1L))
})

test_that("with asserts off, set_m() skips both guards and the shape check", {
	d <- DesignFixedBlocking$new(n = 8L, response_type = "continuous", verbose = FALSE)
	p <- d$.__enclos_env__$private
	unlockBinding("blocking_capable", p); on.exit(p$blocking_capable <- TRUE, add = TRUE)
	p$blocking_capable <- FALSE
	withr::local_options(edi.run_asserts = FALSE)
	d$set_m(c(-1L, 2L))  # neither the blocking_capable guard nor the shape guard fires
	expect_identical(p$m, c(-1L, 2L))
	d$set_m(c(5L, 5L))  # the already-set guard is also skipped, so this silently overwrites
	expect_identical(p$m, c(5L, 5L))
})
