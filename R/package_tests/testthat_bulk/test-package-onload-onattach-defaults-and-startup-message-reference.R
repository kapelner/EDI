library(testthat)
library(EDI)

# zzz.R: .onLoad() option defaults (set only when unset, never overriding a user value),
# the load-time single-thread pin, EDI_SKIP_LOCAL_TUNING, and .onAttach()'s startup
# message with its "unknown" version fallback.

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that(".onLoad sets datatable.quiet and edi.run_asserts only when they are unset", {
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1")
	withr::local_options(datatable.quiet = NULL, edi.run_asserts = NULL)
	Z(".onLoad")("lib", "EDI")
	expect_true(getOption("datatable.quiet"))
	expect_true(getOption("edi.run_asserts"))
	withr::local_options(datatable.quiet = FALSE, edi.run_asserts = FALSE)
	Z(".onLoad")("lib", "EDI")
	expect_false(getOption("datatable.quiet"))                               # user choices survive
	expect_false(getOption("edi.run_asserts"))
})

test_that(".onLoad pins the package to one thread and keeps get_num_cores() in sync", {
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1")
	old <- Z("get_num_cores")()
	on.exit(try(Z("set_num_cores")(old), silent = TRUE), add = TRUE)
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
	ver <- as.character(utils::packageDescription("EDI", fields = "Version"))
	expect_message(Z(".onAttach")(dirname(system.file(package = "EDI")), "EDI"), paste0("^Welcome to EDI v", gsub(".", "\\.", ver, fixed = TRUE), "\\s*$"))
	expect_true(inherits(tryCatch(Z(".onAttach")(dirname(system.file(package = "EDI")), "EDI"), message = function(m) m), "packageStartupMessage"))
})

test_that(".onAttach falls back to 'unknown' when the version cannot be read", {
	expect_message(suppressWarnings(Z(".onAttach")("/nonexistent/lib", "NoSuchPackageForEDI")), "^Welcome to EDI vunknown\\s*$")
	# An empty Version field is treated the same way as a missing one.
	local_mocked_bindings(packageDescription = function(...) "", .package = "utils")
	expect_message(Z(".onAttach")("lib", "EDI"), "vunknown")
})
