# v1.0.6-TODO-180: under left-/interval-censoring several survival classes fit through a
# Suggests package (interval for KMDiff, RestrictedMeanDiff, LogRank and GehanWilcox;
# icenReg for CoxPHRegr) and stop with "Package 'X' is required for <class>" when it is
# absent. The R-devel valgrind and ASAN/UBSAN runners install only EDI's hard
# dependencies, so the randomization / rand-bootstrap slow-path-vs-worker tests on
# interval-censored data got all-NA draws there and failed. The requirement depends on
# the data (right-censored fits need neither package), so it is not in the inference
# registry's required_packages; it is read from the class's own error instead, exactly
# as helper-inference-fixture-missing-packages.R does for constructor guards.
#
# general_censoring_missing_package(cls, des) returns the package `cls` needs to estimate
# on `des` that is not installed, or character(0). Any other error is not a missing
# package and is left for the caller's expectations to report.
general_censoring_missing_package = function(cls, des) {
	msg = tryCatch({
		suppressWarnings(get(cls)$new(des, verbose = FALSE)$compute_estimate())
		NULL
	}, error = function(e) conditionMessage(e))
	if (is.null(msg)) return(character(0))
	m = regmatches(msg, regexec("Package '([^']+)' is required for", msg))[[1L]]
	# the class's own installed-check, so a class that wrongly demands an installed
	# package still fails
	if (length(m) < 2L || EDI:::check_package_installed(m[2L])) return(character(0))
	m[2L]
}
