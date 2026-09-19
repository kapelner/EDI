library(testthat)
library(EDI)

# globals.R's mirai/multi-core plumbing (make_configured_fork_cluster,
# start_mirai_daemons_bounded, mirai_daemons_alive, settle_mirai_tasks) is
# only reachable with num_cores > 1 or a real mirai backend configured, and
# the source's own comments document a history of CI hangs/panics around
# actually launching mirai daemons (nng fork-reentrancy panics, dispatcher
# condition-variable wedges -- see the extensive commentary in globals.R
# around start_mirai_daemons_bounded()). Actually spinning up daemons here
# would risk the same fragility this suite deliberately avoids elsewhere.
#
# This file covers only the two branches that are safe to exercise WITHOUT
# starting any daemon or background process: mirai_daemons_alive()'s
# no-connection-yet path, and settle_mirai_tasks()'s empty-task-list
# short-circuit. Both were confirmed via grep to have zero prior test
# references (only a comment mentions make_configured_fork_cluster by name
# elsewhere, not an actual call). The remaining functions
# (make_configured_fork_cluster, start_mirai_daemons_bounded, and
# mirai_daemons_alive/settle_mirai_tasks's daemon-connected branches) are
# left untested -- deliberately, not an oversight -- since reliably
# exercising them needs a real fork cluster or mirai daemon pool, which is
# exactly the failure mode documented as historically flaky in the source.

test_that("mirai_daemons_alive() returns FALSE when no mirai daemons are connected", {
	# Guard: skip (don't fail) if some other process/test in this R session
	# already configured daemons, since we must not tear down or interfere
	# with state we didn't create.
	skip_if(EDI:::mirai_daemons_alive(), "mirai daemons already active in this session; skipping to avoid interfering with them")
	expect_false(EDI:::mirai_daemons_alive())
})

test_that("settle_mirai_tasks() short-circuits to an empty list without touching any daemon", {
	expect_identical(EDI:::settle_mirai_tasks(list()), list())
	# A non-empty but instantly-vacuous list of "tasks" containing no real
	# mirai handles would error inside mirai::unresolved(); the empty-list
	# short-circuit at the top of the function is the only branch safely
	# reachable without a real daemon.
})
