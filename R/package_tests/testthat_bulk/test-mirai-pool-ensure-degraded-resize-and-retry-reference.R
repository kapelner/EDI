library(testthat)
library(EDI)

# ensure_mirai_daemons() decides when a mirai pool may be reused. Every double
# below sits at the mirai:: boundary, so EDI's launch, retry and settle logic
# runs for real while no daemon or background process is ever started
# (see test-mirai-plumbing-no-daemon-safe-branches.R for why real daemons are
# avoided in this suite).
local_fake_mirai_pool = function(capacity, connections = 0L, .env = parent.frame()) {
	skip_if_not_installed("mirai")
	pool = new.env(parent = emptyenv())
	pool$capacity = as.integer(capacity)
	pool$connections = as.integer(connections)
	pool$teardowns = 0L
	pool$launches = integer(0)
	pool$configures = 0L
	pool$die_on_configure = FALSE
	pool$resolves = TRUE
	local_mocked_bindings(
		status = function(...) {
			list(
				connections = pool$connections,
				daemons = "abstract://fake",
				mirai = c(awaiting = 0L, executing = 0L, completed = 0L)
			)
		},
		daemons = function(n, url = NULL, ...) {
			if (!missing(n) && identical(as.integer(n), 0L)) {
				pool$teardowns = pool$teardowns + 1L
				pool$connections = 0L
			}
			invisible(NULL)
		},
		local_url = function(...) "abstract://fake",
		launch_local = function(n, ...) {
			pool$launches = c(pool$launches, as.integer(n))
			pool$connections = min(pool$connections + as.integer(n), pool$capacity)
			invisible(NULL)
		},
		everywhere = function(.expr, ...) {
			pool$configures = pool$configures + 1L
			if (pool$die_on_configure) pool$connections = 0L
			list("setup-task")
		},
		unresolved = function(x) !pool$resolves,
		.package = "mirai",
		.env = .env
	)
	env = EDI:::edi_env
	saved_target = env$mirai_pool_target
	withr::defer(assign("mirai_pool_target", saved_target, envir = env), envir = .env)
	pool
}

reset_pool_counts = function(pool) {
	pool$teardowns = 0L
	pool$launches = integer(0)
	pool$configures = 0L
}

test_that("a short pool launched for n survives repeated ensures for n", {
	pool = local_fake_mirai_pool(capacity = 3L)
	expect_warning(
		EDI:::start_mirai_daemons_bounded(4L, total_timeout_secs = 0.2),
		"only 3 of 4"
	)
	reset_pool_counts(pool)
	# More capacity now, so unfixed code fails on the teardown count at once
	# instead of sitting in the launcher's 90s connection wait.
	pool$capacity = 4L

	EDI:::ensure_mirai_daemons(4L)
	EDI:::ensure_mirai_daemons(4L)

	expect_identical(pool$teardowns, 0L)
	expect_identical(pool$launches, integer(0))
	expect_identical(pool$connections, 3L)
})

test_that("a short pool launched for a different n is still resized", {
	pool = local_fake_mirai_pool(capacity = 3L)
	expect_warning(
		EDI:::start_mirai_daemons_bounded(4L, total_timeout_secs = 0.2),
		"only 3 of 4"
	)
	reset_pool_counts(pool)
	pool$capacity = 8L

	EDI:::ensure_mirai_daemons(6L)

	expect_identical(pool$teardowns, 1L)
	expect_identical(pool$launches, 6L)
	expect_identical(pool$connections, 6L)
})

test_that("resizing a healthy pool relaunches at the new size and caps worker threads", {
	pool = local_fake_mirai_pool(capacity = 8L)
	EDI:::start_mirai_daemons_bounded(4L)
	reset_pool_counts(pool)

	EDI:::ensure_mirai_daemons(2L)

	expect_identical(pool$teardowns, 1L)
	expect_identical(pool$launches, 2L)
	expect_identical(pool$connections, 2L)
	expect_identical(pool$configures, 1L)
})

test_that("a pool that lost every daemon is relaunched at its recorded size", {
	pool = local_fake_mirai_pool(capacity = 4L)
	EDI:::start_mirai_daemons_bounded(4L)
	pool$connections = 0L
	reset_pool_counts(pool)

	EDI:::ensure_mirai_daemons(4L)

	expect_identical(pool$launches, 4L)
	expect_identical(pool$connections, 4L)
})

test_that("a correctly sized pool is reconfigured only when always_configure is set", {
	pool = local_fake_mirai_pool(capacity = 4L)
	EDI:::start_mirai_daemons_bounded(4L)
	reset_pool_counts(pool)

	EDI:::ensure_mirai_daemons(4L)
	expect_identical(pool$configures, 0L)

	EDI:::ensure_mirai_daemons(4L, always_configure = TRUE)
	expect_identical(pool$configures, 1L)
	expect_identical(pool$teardowns, 0L)
	expect_identical(pool$launches, integer(0))
})

test_that("daemons dying during setup get one relaunch, then a loud failure", {
	pool = local_fake_mirai_pool(capacity = 4L)
	pool$resolves = FALSE
	pool$die_on_configure = TRUE

	expect_error(EDI:::ensure_mirai_daemons(4L), "failed to start")

	expect_identical(pool$launches, c(4L, 4L))
	expect_identical(pool$connections, 0L)
})
