#!/usr/bin/env Rscript
# Run the drift generators (drift_artifacts.sh regenerate) one after another in
# ONE R process, so EDI is loaded from source once instead of once per script
# (three of them pkgload::load_all(compile = FALSE), ~5.5 s each).
#
# Usage, from R/: Rscript package_tests/run_drift_generators.R "<script> [args]" ...
#
# Each script gets the clean state a fresh `Rscript package_tests/<script>`
# would: the global environment is emptied, the options captured at startup are
# restored, .Random.seed is dropped, and commandArgs() reports that script's own
# --file= and trailing arguments (the scripts locate the repo and decide whether
# to run main() from it). Scripts are evaluated in the global environment
# because public_argument_contract_registry.R only runs main() there. A script
# that calls quit(status = 1) ends this process with that status, as before.
#
# What is shared, by design: the EDI namespace loaded from source by the first
# load_all (the load_edi_namespace() helpers skip a second load_all when EDI is
# already a dev package), and attached packages. Scripts that previously ran
# requireNamespace("EDI") in their own process loaded the INSTALLED EDI; here
# they see the source-loaded one, which is what CI's freshly installed EDI
# matches. drift_artifacts.sh falls back to one process per script with
# EDI_DRIFT_SEPARATE_PROCESSES=1.

drift_specs = commandArgs(trailingOnly = TRUE)
if (!length(drift_specs)) stop("usage: run_drift_generators.R \"<script> [args]\" ...", call. = FALSE)

drift_runner = new.env(parent = emptyenv())
drift_runner$specs = drift_specs
drift_runner$options = options()
drift_runner$base_args = commandArgs(FALSE)
drift_runner$base_args = drift_runner$base_args[seq_len(match("--args", drift_runner$base_args, nomatch = length(drift_runner$base_args) + 1L) - 1L)]
drift_runner$base_args = drift_runner$base_args[!grepl("^--file=", drift_runner$base_args)]
# Kept off the global environment, which each script gets emptied.
attach(drift_runner, name = "edi_drift_runner", warn.conflicts = FALSE)
rm(drift_runner, drift_specs)

for (edi_drift_spec in get("specs", envir = as.environment("edi_drift_runner"))) {
	local({
		runner = as.environment("edi_drift_runner")
		parts = strsplit(edi_drift_spec, " +")[[1L]]
		script = file.path("package_tests", parts[[1L]])
		script_args = parts[-1L]
		cat(">>> Rscript ", script, if (length(script_args)) paste0(" ", paste(script_args, collapse = " ")), "\n", sep = "")
		rm(list = ls(globalenv(), all.names = TRUE), envir = globalenv())
		options(runner$options)
		fake_args = c(runner$base_args, paste0("--file=", script), if (length(script_args)) c("--args", script_args))
		assign("commandArgs", function(trailingOnly = FALSE) if (trailingOnly) script_args else fake_args, envir = globalenv())
		sys.source(script, envir = globalenv(), keep.source = FALSE, toplevel.env = globalenv())
	})
}
invisible(NULL)
