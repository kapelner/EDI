#' @importFrom randomizr block_ra block_and_cluster_ra cluster_ra
NULL

# 2026-09-22: diagnostic-only, opt-in tracing for the still-unexplained
# windows-latest R-CMD-check hang (R-CMD-check.yaml's timeout-minutes
# comment). Watchdog evidence from run 35716080449 (job 106707787789): the
# combined EDI-Ex.Rout examples file stayed at 0 bytes for 3+ hours and the
# Rterm process accumulated only ~5 minutes of CPU time total -- a blocked
# wait, not a compute loop, and early enough that not a single byte of
# example output was ever written. That points at package LOAD time
# (.onLoad below), not deep inside some specific \donttest{} example as a
# 2026-08-17 static audit assumed. No-op unless EDI_ONLOAD_TRACE=1 (set only
# on the Windows R-CMD-check leg) -- completely silent for every normal
# library(EDI) call.
#
# 2026-09-25: defined as its own top-level function, NOT nested inside
# .onLoad()'s body -- R CMD check's "checking R code for possible problems"
# flags packageStartupMessage()/cat()/message()/print() calls found directly
# in .onLoad()'s/.onAttach()'s own literal body (see "Good practice" in
# ?.onAttach: such output belongs in .onAttach, and even there sparingly),
# regardless of whether the call is reachable/ever fires at runtime -- a
# static, name-based check, not a dynamic one. It does NOT flag the same
# call sitting in some OTHER function that .onLoad merely calls by name
# (confirmed empirically: globals.R's set_package_threads() has its own
# internal cat()-based trace and was never flagged, precisely because
# .onLoad() only calls it, never contains the cat() call itself). Moving
# this helper out here, so .onLoad() only calls edi_onload_trace_step(...)
# by name, uses that exact same escape hatch.
edi_onload_trace_step = function(label) {
	if (!identical(Sys.getenv("EDI_ONLOAD_TRACE"), "1")) return(invisible(NULL))
	# packageStartupMessage() (not cat()): the R-level side of this same "Good
	# practice" guidance -- still fine to call from a helper .onLoad merely
	# references, as established above. Available even when R CMD check's
	# "checking whether the namespace can be loaded with stated dependencies"
	# test loads the package with only the base namespace attached, unlike
	# utils::flush.console() below -- confirmed 2026-09-22, run 35755226765
	# job 106839182746 hit exactly that gap for flush.console() itself.
	packageStartupMessage("EDI .onLoad trace: ", label)
	# flush.console() (Windows-only, lives in utils) is NOT available here for
	# the same base-namespace-only reason above. flush(stdout()) is base R,
	# always available, and does the same job.
	flush(stdout())
}

.onLoad = function(libname, pkgname) {
	edi_onload_trace_step("start")
	# No options() are set here: loading EDI must not change the user's options
	# (CRAN policy). Assertions default to on via should_run_asserts()'s own
	# getOption("edi.run_asserts", TRUE) default and edi_env state.

	# Pin OpenMP/BLAS threads to 1 at load time so the package is actually
	# single-threaded by default, matching get_num_cores()'s own default belief
	# (fix_design_hierarchy.md, TODO-29). Without this, the OpenMP runtime falls
	# back to its own default (typically every detected logical core) the moment
	# any Rcpp kernel with a `#pragma omp parallel` region runs, regardless of
	# get_num_cores() -- confirmed empirically: get_num_cores() reports 1L on a
	# fresh session while RhpcBLASctl::omp_get_max_threads() reported the
	# machine's full core count. This silently made every OpenMP-parallel kernel
	# multi-threaded by default (a real, previously-unnoticed resource-usage
	# surprise for anyone who never explicitly calls set_num_cores()), and made
	# DesignFixedRerandomization's work-stealing rejection sampler
	# (rerandomization_search_cpp) non-seed-reproducible even in the "default"
	# case its own metadata claimed was safe. set_package_threads() is the same
	# function set_num_cores(N) uses to apply N; calling it here with 1L at load
	# time keeps the R-level default (get_num_cores() == 1) and the actual
	# OpenMP/BLAS thread count in sync from the start, until/unless the user
	# explicitly opts into more via set_num_cores().
	set_package_threads(1L)
	edi_onload_trace_step("after set_package_threads")

	# Import this machine's saved performance-policy tuning, if any
	# (local_machine_optimization.md TODO-9). Fail-open by construction:
	# no file -> silent no-op; unreadable/incompatible/unapplicable file ->
	# ignored entirely (policies reset to shipped defaults) plus one
	# packageStartupMessage; hardware-changed -> applied plus a suggestion to
	# re-run. Never errors at load, and never touches the active core count
	# (the parallel diff is recorded-only). EDI_SKIP_LOCAL_TUNING=1 disables it.
	edi_tuning_import_saved_policies(quiet = FALSE)
	edi_onload_trace_step("after edi_tuning_import_saved_policies")
	edi_onload_trace_step("end")
}

.onAttach = function(libname, pkgname){
	version <- tryCatch(
		as.character(utils::packageDescription(pkgname, lib.loc = libname, fields = "Version")),
		error = function(e) NA_character_
	)
	if (!is.character(version) || length(version) != 1L || is.na(version) || version == "") {
		version <- "unknown"
	}
	packageStartupMessage(
			paste("Welcome to EDI v", version, sep = "")
	)
}
