#!/usr/bin/env Rscript
#
# Runs the "bulk" testthat suite: the large majority of EDI's tests that are
# pure algorithmic/statistical logic (model fitting, formula checks,
# golden-value comparisons) with no OS-dependent behavior. These files used
# to live under R/EDI/tests/testthat/ and got re-run, serially and in full,
# on every R-CMD-check matrix leg (5 OS/R-version combos) plus
# R-CMD-check-no-suggests/-sanitizers/-valgrind plus test-coverage-R.yaml --
# 9 redundant full passes of the same OS-independent logic, which is what
# made the suite too slow to run in practice (see the "moved out of
# tests/testthat/ so CI is faster" decision this script implements).
#
# R/EDI/tests/testthat/ now keeps only the small set of genuinely
# platform-sensitive files (skip_on_os() users, real OS-level fork/parallel
# tests, thread-pool/BLAS setup) -- those still run under the normal R CMD
# check matrix. This script runs everything else, once, in a single job (see
# .github/workflows/test-bulk-non-cran.yml).
#
# NOTE: because these files no longer live under R/EDI/tests/, they are not
# part of `R CMD check` at all -- not on CRAN (which already skipped the
# whole suite via tests/testthat.R's NOT_CRAN guard) and not on our own
# R-CMD-check jobs either. This script is the only thing that runs them.

suppressMessages(pkgload::load_all("EDI", compile = FALSE, quiet = TRUE))
library(testthat)

test_dir_path = file.path("package_tests", "testthat_bulk")
if (!dir.exists(test_dir_path)) {
	# Allow invocation from either the `R/` working directory (CI convention
	# for everything else under package_tests/) or from this directory itself.
	test_dir_path = "."
}

reporter = Sys.getenv("EDI_BULK_TESTS_REPORTER", "summary")
results = testthat::test_dir(test_dir_path, reporter = reporter, stop_on_failure = FALSE)

df = as.data.frame(results)

cat(sprintf(
	"\nBulk testthat suite: %d test files, %d failed expectations across files, %d warnings.\n",
	length(results), sum(df$failed, na.rm = TRUE), sum(df$warning, na.rm = TRUE)
))

if (sum(df$failed, na.rm = TRUE) > 0L) {
	quit(status = 1L)
}
