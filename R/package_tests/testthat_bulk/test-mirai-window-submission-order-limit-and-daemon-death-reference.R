library(testthat)
library(EDI)

# run_mirai_window() and par_lapply()'s mirai branch. Doubles sit at the mirai::
# boundary, so the window logic and par_lapply's chunking run for real while no
# daemon is started (see test-mirai-plumbing-no-daemon-safe-branches.R for why
# real daemons are avoided in this suite).
local_fake_tasks = function(connections = 2L, .env = parent.frame()) {
	skip_if_not_installed("mirai")
	world = new.env(parent = emptyenv())
	world$connections = as.integer(connections)
	world$polls_left = integer(0)
	world$next_id = 0L
	world$submitted = 0L
	world$max_in_flight = 0L
	world$teardowns = 0L
	world$launches = 0L
	world$stopped = integer(0)
	# A task resolves after `polls` unresolved() checks; its value is what `m[]`
	# returns, tagged with an id so unresolved() can tell tasks apart.
	world$add_task = function(value, polls) {
		world$next_id = world$next_id + 1L
		world$submitted = world$submitted + 1L
		world$polls_left[world$next_id] = as.integer(polls)
		world$max_in_flight = max(world$max_in_flight, sum(world$polls_left > 0L))
		structure(value, task_id = world$next_id)
	}
	local_mocked_bindings(
		unresolved = function(x) {
			id = attr(x, "task_id")
			if (world$polls_left[id] > 0L) world$polls_left[id] = world$polls_left[id] - 1L
			world$polls_left[id] > 0L
		},
		stop_mirai = function(x) {
			world$stopped = c(world$stopped, attr(x, "task_id"))
			invisible(TRUE)
		},
		status = function(...) {
			list(
				connections = world$connections,
				daemons = "abstract://fake",
				mirai = c(awaiting = 0L, executing = 0L, completed = 0L)
			)
		},
		daemons = function(n, url = NULL, ...) {
			if (!missing(n)) {
				world$teardowns = world$teardowns + 1L
				world$connections = 0L
			}
			invisible(NULL)
		},
		local_url = function(...) "abstract://fake",
		launch_local = function(n, ...) {
			world$launches = world$launches + 1L
			world$connections = as.integer(n)
			invisible(NULL)
		},
		everywhere = function(.expr, ...) list(),
		mirai = function(.expr, ..., .args = list()) {
			job = list(...)
			world$add_task(job$RUN_CHUNK(job$chunk), polls = 2L)
		},
		.package = "mirai",
		.env = .env
	)
	world
}

test_that("results keep chunk order when later chunks finish first", {
	world = local_fake_tasks()
	polls = c(5L, 1L, 3L, 1L)
	seen_index = integer(0)
	submit = function(chunk, i) {
		seen_index <<- c(seen_index, i)
		world$add_task(chunk * 10, polls = polls[i])
	}

	out = EDI:::run_mirai_window(list(1, 2, 3, 4), submit, window = 2L)

	expect_identical(vapply(out, as.numeric, 0), c(10, 20, 30, 40))
	expect_identical(seen_index, 1:4)
})

test_that("no more than window chunks are ever in flight", {
	world = local_fake_tasks()
	submit = function(chunk, i) world$add_task(chunk, polls = 3L)

	EDI:::run_mirai_window(as.list(1:7), submit, window = 3L)

	expect_identical(world$max_in_flight, 3L)
	expect_identical(world$submitted, 7L)
})

test_that("losing every daemon returns NULL and submits nothing further", {
	world = local_fake_tasks()
	submit = function(chunk, i) {
		world$connections = 0L
		world$add_task(chunk, polls = 1000L)
	}

	out = EDI:::run_mirai_window(as.list(1:5), submit, window = 2L)

	expect_null(out)
	expect_identical(world$submitted, 2L)
})

test_that("a chunk lost with its daemon is an error, not a result", {
	local_fake_tasks()
	local_mocked_bindings(unresolved = function(x) FALSE, .package = "mirai")
	# Collecting a real mirai whose daemon is gone yields errorValue 19
	# (connection reset). Plain `[` would strip that class, so the double needs
	# its own method, as a real mirai has.
	registerS3method("[", "fake_lost_task", function(x, ...) structure(19L, class = "errorValue"))
	lost_chunk = structure(list(), class = "fake_lost_task")
	submit = function(chunk, i) if (i == 2L) lost_chunk else chunk

	expect_error(
		EDI:::run_mirai_window(as.list(1:3), submit, window = 2L),
		"chunk 2"
	)
})

test_that("a stall tears the pool down so the wedged daemon is not reused, then errors", {
	world = local_fake_tasks()
	env = EDI:::edi_env
	saved_target = env$mirai_pool_target
	withr::defer(assign("mirai_pool_target", saved_target, envir = env))
	assign("mirai_pool_target", 2L, envir = env)
	submit = function(chunk, i) world$add_task(chunk, polls = 1000000L)

	expect_error(
		EDI:::run_mirai_window(as.list(1:5), submit, window = 2L, stall_secs = 0.05),
		"EDI.mirai_stall_timeout_secs"
	)

	expect_identical(world$teardowns, 1L)
	expect_identical(world$connections, 0L)
	expect_null(env$mirai_pool_target)
	expect_identical(world$submitted, 2L)
})

test_that("each finished chunk restarts the stall clock", {
	local_fake_tasks()
	# Every chunk takes 0.3s, so the batch outlasts stall_secs while no single
	# gap between completions comes near it.
	local_mocked_bindings(
		unresolved = function(x) { Sys.sleep(0.3); FALSE },
		.package = "mirai"
	)

	out = EDI:::run_mirai_window(as.list(1:5), function(chunk, i) chunk, window = 1L, stall_secs = 1)

	expect_identical(unlist(out), 1:5)
})

test_that("each finished task reaches on_ready once, with its own index", {
	world = local_fake_tasks()
	polls = c(4L, 1L, 2L)
	seen = integer(0)
	batches = 0L

	left = EDI:::poll_mirai_tasks(
		n = 3L,
		submit = function(i) world$add_task(i * 10, polls = polls[i]),
		window = 3L,
		on_ready = function(i, task) {
			expect_equal(as.numeric(task[]), i * 10)
			seen <<- c(seen, i)
		},
		after_ready = function() batches <<- batches + 1L
	)

	expect_identical(left, 0L)
	expect_identical(seen, c(2L, 3L, 1L))
	expect_identical(batches, 3L)
})

test_that("an error raised by on_ready stops every task still in flight", {
	world = local_fake_tasks()
	polls = c(1L, 1000000L, 1000000L)

	expect_error(
		EDI:::poll_mirai_tasks(
			n = 3L,
			submit = function(i) world$add_task(i, polls = polls[i]),
			window = 3L,
			on_ready = function(i, task) stop("abort from callback")
		),
		"abort from callback"
	)

	expect_identical(sort(world$stopped), c(2L, 3L))
})

test_that("losing every daemon reports how many tasks were left and stops them", {
	world = local_fake_tasks()
	submit = function(i) {
		world$connections = 0L
		world$add_task(i, polls = 1000000L)
	}

	left = EDI:::poll_mirai_tasks(n = 5L, submit, window = 2L, on_ready = function(i, task) NULL)

	expect_identical(left, 2L)
	expect_identical(sort(world$stopped), 1:2)
})

test_that("a throttled liveness check waits out its interval before giving up", {
	world = local_fake_tasks()
	submit = function(i) {
		world$connections = 0L
		world$add_task(i, polls = 1000000L)
	}
	started = as.numeric(Sys.time())

	left = EDI:::poll_mirai_tasks(
		n = 1L, submit, window = 1L, on_ready = function(i, task) NULL,
		liveness_every_secs = 0.3
	)

	expect_identical(left, 1L)
	expect_gte(as.numeric(Sys.time()) - started, 0.3)
})

test_that("an empty chunk list submits nothing", {
	world = local_fake_tasks()
	expect_identical(EDI:::run_mirai_window(list(), function(chunk, i) stop("no"), window = 2L), list())
	expect_identical(world$submitted, 0L)
})

test_that("par_lapply narrower than the global pool caps concurrency without touching the pool", {
	world = local_fake_tasks(connections = 4L)
	env = EDI:::edi_env
	saved = list(cores = env$global_mirai_num_cores, cl = env$global_fork_cluster)
	withr::defer({
		assign("global_mirai_num_cores", saved$cores, envir = env)
		assign("global_fork_cluster", saved$cl, envir = env)
	})
	assign("global_mirai_num_cores", 4L, envir = env)
	assign("global_fork_cluster", NULL, envir = env)
	set.seed(1)
	des = DesignFixedBernoulli$new(n = 20L, response_type = "continuous", seed = 1L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20L)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(20L))
	priv = InferenceAllSimpleAverageDiff$new(des)$.__enclos_env__$private

	out = priv$par_lapply(1:16, function(i) i^2, n_cores = 2L)

	expect_identical(unlist(out), (1:16)^2)
	expect_identical(world$teardowns, 0L)
	expect_identical(world$launches, 0L)
	expect_identical(world$max_in_flight, 2L)
})

test_that("par_lapply applies the stall timeout option", {
	world = local_fake_tasks(connections = 2L)
	env = EDI:::edi_env
	saved = list(cores = env$global_mirai_num_cores, cl = env$global_fork_cluster)
	withr::defer({
		assign("global_mirai_num_cores", saved$cores, envir = env)
		assign("global_fork_cluster", saved$cl, envir = env)
	})
	assign("global_mirai_num_cores", 2L, envir = env)
	assign("global_fork_cluster", NULL, envir = env)
	withr::local_options(EDI.mirai_stall_timeout_secs = 0.05)
	local_mocked_bindings(
		mirai = function(.expr, ..., .args = list()) world$add_task(1, polls = 1000000L),
		.package = "mirai"
	)
	set.seed(1)
	des = DesignFixedBernoulli$new(n = 20L, response_type = "continuous", seed = 1L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20L)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(20L))
	priv = InferenceAllSimpleAverageDiff$new(des)$.__enclos_env__$private

	expect_error(priv$par_lapply(1:8, function(i) i, n_cores = 2L), "EDI.mirai_stall_timeout_secs")
})
