library(testthat)
library(EDI)

# globals.R's make_configured_fork_cluster(n_cores) starts with a guard: if
# edi_env$mirai_has_been_used is TRUE, it stop()s immediately -- before ever attempting
# parallel::makeForkCluster() -- with a message explaining that forking after mirai-backed
# parallelism has run in the same session risks an "nng is not fork-reentrant safe" panic.
# The companion file test-mirai-plumbing-no-daemon-safe-branches.R deliberately leaves this
# function entirely untested, reasoning that exercising it needs a real fork cluster or
# mirai daemon pool -- true for the function's main body, but this guard clause itself
# fires purely off private package state (edi_env$mirai_has_been_used) and returns before
# any cluster is ever created, so it can be reached safely by toggling that flag directly.
# A codebase-wide grep confirmed the exact guard message had zero test references anywhere.
#
# The flag is saved and restored via on.exit so this test never leaves global package state
# mutated for any other test in the suite (the same discipline this session uses for
# RNGkind() saves elsewhere).

test_that("make_configured_fork_cluster() stops immediately, without attempting a fork, when mirai has already been used this session", {
	edi_env <- EDI:::edi_env
	old <- edi_env$mirai_has_been_used
	on.exit(edi_env$mirai_has_been_used <- old, add = TRUE)

	edi_env$mirai_has_been_used <- TRUE
	expect_error(
		EDI:::make_configured_fork_cluster(1L),
		"Cannot create a fork cluster after mirai-backed parallelism has been used in the same R session",
		fixed = TRUE
	)
})

test_that("the guard does not fire when mirai has not been used", {
	edi_env <- EDI:::edi_env
	old <- edi_env$mirai_has_been_used
	on.exit(edi_env$mirai_has_been_used <- old, add = TRUE)

	edi_env$mirai_has_been_used <- FALSE
	cl <- EDI:::make_configured_fork_cluster(1L)
	on.exit(try(parallel::stopCluster(cl), silent = TRUE), add = TRUE)
	expect_false(is.null(cl))
})
