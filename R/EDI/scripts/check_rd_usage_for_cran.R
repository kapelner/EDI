#!/usr/bin/env Rscript
# Pre-submission check that every Rd file's \usage arguments are documented
# (and every documented argument is in \usage), via tools::checkDocFiles() --
# the check behind R CMD check's "checking Rd \usage sections ... WARNING".
# R CMD check only reports it as a WARNING, which is how the 2026-09-25
# generate_permutations_*_cpp Rd files reached CRAN; this makes it a hard
# failure. Needs only the source tree (man/), no build.
#
# Usage: Rscript check_rd_usage_for_cran.R <pkg_dir>
# Exits non-zero, printing R's own report, if anything is undocumented.

args = commandArgs(trailingOnly = TRUE)
if (length(args) < 1L) stop("usage: check_rd_usage_for_cran.R <pkg_dir>")
problems = tools::checkDocFiles(dir = args[1])
if (length(unlist(problems))) {
	print(problems)
	cat("\nERROR: Rd files have undocumented arguments (listed above) -- CRAN flags this as a WARNING.\n", file = stderr())
	quit(status = 1L)
}
cat("OK: all Rd \\usage arguments are documented\n")
