library(testthat)
library(EDI)

if (identical(Sys.getenv("NOT_CRAN"), "true")) {
	# EDI_TESTTHAT_PROGRESS is set by the CI workflows (R-CMD-check.yaml) to
	# diagnose the intermittent silent hang inside `R CMD check`'s
	# "checking tests" phase (see .github/scripts/test-hang-watchdog.sh):
	# the default CheckReporter prints nothing per-file until the whole
	# suite finishes, so a hung run's testthat.Rout never says which test
	# file it died in. The location reporter prints a line as each file
	# starts/ends, which the watchdog's periodic .Rout tail then captures.
	# Unset (i.e. everywhere except CI, including CRAN), behavior is
	# exactly as before. (Comment edited 2026-09-01 to re-trigger CI: the
	# prior trigger attempt touched .github/scripts/, which the workflow's
	# paths: filter ignores.)
	if (identical(Sys.getenv("EDI_TESTTHAT_PROGRESS"), "true")) {
		test_check("EDI", reporter = MultiReporter$new(list(
			CheckReporter$new(),
			LocationReporter$new()
		)))
	} else {
		test_check("EDI")
	}
}
