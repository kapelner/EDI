# Installs every package a fresh machine needs before running
# comprehensive_tests.R (and the nohup commands in
# comprehensive_tests_nohup_runs.txt). Two separate sources, kept separate
# below rather than silently merged, since they answer different questions
# and come from different places in the repo:
#
#   1. EDI's own Suggests (R/EDI/DESCRIPTION) -- what EDI itself needs for
#      its optional features/tests.
#   2. comprehensive_tests.R's own required_packages list
#      (package_tests/comprehensive_tests.R:641) -- the test harness's own
#      hard-enforced dependencies (require()+stop() if missing), which is
#      NOT the same list and is not derived from EDI's DESCRIPTION at all.
#      This is the list that actually fails with "Required package is not
#      installed: PTE" on a fresh machine.
#
# Run this once on a new machine before launching comprehensive_tests.R.

# 1. EDI's Suggests (R/EDI/DESCRIPTION)
install.packages(c(
	"anticlust", "blockTools", "clinfun", "coin", "dplyr", "mirai", "aftgee",
	"betareg", "copula", "doParallel", "ggplot2", "fixest", "gamlss.dist",
	"geepack", "glmmTMB", "glmnet", "icenReg", "interval", "jsonlite",
	"knitr", "lme4", "multgee", "nbpMatching", "nlme", "nnet", "optmatch",
	"ordinal", "pscl", "qpdf", "quantreg", "R.utils", "RcppXPtrUtils",
	"Rfit", "rmarkdown", "testthat", "VGAM", "ompr", "ompr.roi",
	"ROI.plugin.glpk", "sandwich", "withr"
))

# 2. comprehensive_tests.R's own required_packages
# ("datasets" ships with base R; install.packages() on it is a harmless
# no-op, kept here only so this list matches comprehensive_tests.R's
# exactly and nobody has to go cross-reference the two by hand.)
install.packages(c(
	"doParallel", "PTE", "datasets", "qgam", "mlbench",
	"AppliedPredictiveModeling", "dplyr", "ggplot2", "gridExtra", "profvis",
	"data.table", "devtools", "R.utils"
))
