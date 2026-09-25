library(testthat)
library(EDI)

# zzz.R's .onLoad() and globals.R's set_package_threads() both have a diagnostic-only,
# opt-in tracing helper (cat() + flush(stdout()) per step) gated on Sys.getenv("EDI_ONLOAD_TRACE")
# == "1" (added 2026-09-22 while chasing a windows-latest R-CMD-check hang). Both functions are
# already extensively tested elsewhere (test-package-onload-onattach-defaults-and-startup-message-
# reference.R, test-set-package-threads-caching-and-env-contract.R), but always with the trace env
# var unset, so the trace branch itself -- normally a silent no-op, only ever active on the Windows
# CI leg -- had zero test references anywhere. Exercised by setting the env var and asserting on
# the traced stdout output; a fully safe, side-effect-free thing to flip since it only adds cat()
# calls to code paths already exercised elsewhere.

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that(".onLoad() emits its trace lines via packageStartupMessage() when EDI_ONLOAD_TRACE=1, and stays silent otherwise", {
	# 2026-09-25: .onLoad()'s trace helper (edi_onload_trace_step(), zzz.R) switched from
	# cat() to packageStartupMessage() -- R CMD check's "checking R code for possible
	# problems" flags a cat()/print() call found directly in .onLoad()'s own body (see
	# "Good practice" in ?.onAttach), and moving the helper to a top-level function alone
	# wasn't enough once its own body still used cat(). packageStartupMessage() writes to
	# the message condition system, not stdout, so this now captures via
	# capture_messages() instead of capture.output() -- confirmed empirically each
	# captured message carries a trailing "\n" (message()'s own convention), stripped
	# below before comparing.
	withr::local_envvar(EDI_SKIP_LOCAL_TUNING = "1", EDI_ONLOAD_TRACE = "1")
	out <- sub("\n$", "", testthat::capture_messages(Z(".onLoad")("lib", "EDI")))
	expect_true("EDI .onLoad trace: start" %in% out)
	expect_true("EDI .onLoad trace: end" %in% out)
	expect_true("EDI .onLoad trace: after set_package_threads" %in% out)
	expect_true("EDI .onLoad trace: after edi_tuning_import_saved_policies" %in% out)

	withr::local_envvar(EDI_ONLOAD_TRACE = "0")
	expect_silent(Z(".onLoad")("lib", "EDI"))
})

test_that("set_package_threads() emits its trace lines to stdout when EDI_ONLOAD_TRACE=1, and stays silent otherwise", {
	on.exit(EDI:::set_package_threads(1L), add = TRUE)
	withr::local_envvar(EDI_ONLOAD_TRACE = "1")

	out <- capture.output(EDI:::set_package_threads(5L))
	expect_true("EDI set_package_threads trace: start" %in% out)
	expect_true("EDI set_package_threads trace: end" %in% out)
	expect_true("EDI set_package_threads trace: after Sys.setenv" %in% out)
	expect_true("EDI set_package_threads trace: after set_omp_num_threads_cpp" %in% out)

	# the identical()-based short-circuit still fires before any tracing when re-called
	# with the same core count -- no trace lines at all in that case.
	out2 <- capture.output(EDI:::set_package_threads(5L))
	expect_length(out2, 0L)

	withr::local_envvar(EDI_ONLOAD_TRACE = "0")
	expect_silent(EDI:::set_package_threads(6L))
})
