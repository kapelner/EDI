library(testthat)
library(EDI)

# zzz.R: .onLoad() leaves the user's options() alone (CRAN policy),
# the load-time single-thread pin, EDI_SKIP_LOCAL_TUNING, and .onAttach()'s startup
# message with its "unknown" version fallback.

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that(".onLoad never changes the user's options(), and asserts default to on", {
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1")
	withr::local_options(datatable.quiet = NULL, edi.run_asserts = NULL, mc.cores = NULL)
	options_before <- options()
	Z(".onLoad")("lib", "EDI")
	expect_identical(options(), options_before)
	expect_true(Z("should_run_asserts")())
	withr::local_options(datatable.quiet = FALSE, edi.run_asserts = FALSE)
	Z(".onLoad")("lib", "EDI")
	expect_false(getOption("datatable.quiet"))                               # user choices survive
	expect_false(getOption("edi.run_asserts"))
	expect_false(Z("should_run_asserts")())                                   # and are honored
})

test_that(".onLoad pins the package to one thread and keeps get_num_cores() in sync", {
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1")
	old <- Z("get_num_cores")()
	on.exit(try(Z("set_num_cores")(old), silent = TRUE), add = TRUE)
	# set_package_threads() skips its actual OMP/BLAS syscalls when its own
	# edi_env$last_set_threads bookkeeping already equals the target --
	# a real bulk-suite run executes many test files in one R session, and
	# anything upstream that touches OpenMP threads directly (bypassing
	# set_package_threads()) leaves that bookkeeping stale relative to the
	# actual thread count. Clearing it forces .onLoad() below to always take
	# the real code path instead of possibly no-op'ing on stale state.
	edi_env <- Z("edi_env")
	edi_env$last_set_threads <- NULL
	Z(".onLoad")("lib", "EDI")
	expect_equal(Z("get_num_cores")(), 1L)
	if (requireNamespace("RhpcBLASctl", quietly = TRUE)) expect_equal(RhpcBLASctl::omp_get_max_threads(), 1L)
})

test_that(".onLoad never errors, even when local tuning is disabled or no saved file exists", {
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1")
	expect_silent(Z(".onLoad")("lib", "EDI"))
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = NA_character_)
	env <- Z("edi_env"); old <- env$tuning_config_dir_override
	on.exit(env$tuning_config_dir_override <- old, add = TRUE)
	env$tuning_config_dir_override <- file.path(tempdir(), "edi-no-such-config-dir")
	expect_no_error(suppressMessages(Z(".onLoad")("lib", "EDI")))
})

test_that(".onAttach announces the installed version through a startup message", {
	# Recomputes the expected version with the EXACT same tryCatch + fallback
	# logic .onAttach() itself uses (zzz.R), not a bare packageDescription()
	# call -- that stayed correct under a real CI install (lib.loc matches
	# .onAttach()'s own explicit libname argument) but broke identically to
	# how .onAttach() itself never breaks under the bulk-suite shards, which
	# load the package via pkgload::load_all(compile = FALSE) rather than a
	# real install: with no Meta/package.rds cache, packageDescription() can't
	# resolve a version under either mechanism, so both sides must fall back
	# to "unknown" together (confirmed 2026-09-22, run 35755226654 shard 20).
	ver <- suppressWarnings(tryCatch(
		as.character(utils::packageDescription("EDI", lib.loc = dirname(system.file(package = "EDI")), fields = "Version")),
		error = function(e) NA_character_
	))
	if (!is.character(ver) || length(ver) != 1L || is.na(ver) || ver == "") {
		ver <- "unknown"
	}
	expect_message(Z(".onAttach")(dirname(system.file(package = "EDI")), "EDI"), paste0("^Welcome to EDI v", gsub(".", "\\.", ver, fixed = TRUE), "\\s*$"))
	expect_true(inherits(tryCatch(Z(".onAttach")(dirname(system.file(package = "EDI")), "EDI"), message = function(m) m), "packageStartupMessage"))
})

test_that(".onAttach falls back to 'unknown' when the version cannot be read", {
	expect_message(suppressWarnings(Z(".onAttach")("/nonexistent/lib", "NoSuchPackageForEDI")), "^Welcome to EDI vunknown\\s*$")
	# An empty Version field is treated the same way as a missing one.
	local_mocked_bindings(packageDescription = function(...) "", .package = "utils")
	expect_message(Z(".onAttach")("lib", "EDI"), "vunknown")
})
