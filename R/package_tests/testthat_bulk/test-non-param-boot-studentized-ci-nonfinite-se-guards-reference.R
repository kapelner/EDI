library(testthat)
library(EDI)

# inference_all_abstract_non_param_boot.R's ci_studentized()/ci_symmetric_studentized() each guard
# private$infer_original_se() being finite and positive before delegating to the shared
# bootstrap_ci_studentized()/bootstrap_ci_symmetric_studentized() formulas -- reachable through the
# public compute_bootstrap_confidence_interval(type = "studentized"/"symmetric-percentile-t") on an
# unhardened (harden = FALSE) object, whose enclosing tryCatch re-throws rather than swallowing the
# error. Not naturally triggerable with ordinary data (infer_original_se() is a real model-based SE
# estimate), so exercised the same way this session has tested other structurally-real guards:
# stubbing the private method directly on an already-constructed object. Zero test references for
# either message anywhere. (The sibling ci_bca()/pval_bca() "requires jackknife estimates" stop()s
# in the same file are, by contrast, genuinely unreachable dead code -- an identical length(jack) <
# 2L check immediately above each one already returns gracefully before either stop() line could
# ever run, regardless of should_run_asserts(); noted, not tested, per this job's scope.)

make_studentized_fixture <- function(seed = 1L, n = 30L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	d <- DesignFixedBernoulli$new(response_type = "continuous", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
	w <- d$get_w()
	d$add_all_subject_responses(rnorm(n) + w)
	inf <- InferenceContinLin$new(d, harden = FALSE, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	unlockBinding("infer_original_se", priv)
	list(inf = inf, priv = priv)
}

test_that("ci_studentized(): a non-finite/non-positive original SE errors via the public studentized bootstrap CI", {
	f <- make_studentized_fixture(seed = 1L)
	f$priv$infer_original_se <- function(...) NA_real_
	expect_error(
		f$inf$compute_bootstrap_confidence_interval(type = "studentized", B = 100, show_progress = FALSE),
		"Studentized bootstrap CI requires a finite standard error\\."
	)

	g <- make_studentized_fixture(seed = 2L)
	g$priv$infer_original_se <- function(...) 0
	expect_error(
		g$inf$compute_bootstrap_confidence_interval(type = "studentized", B = 100, show_progress = FALSE),
		"Studentized bootstrap CI requires a finite standard error\\."
	)
})

test_that("ci_symmetric_studentized(): a non-finite/non-positive original SE errors via the public symmetric-percentile-t bootstrap CI", {
	f <- make_studentized_fixture(seed = 3L)
	f$priv$infer_original_se <- function(...) NA_real_
	expect_error(
		f$inf$compute_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 100, show_progress = FALSE),
		"Symmetric percentile-t bootstrap CI requires a finite standard error\\."
	)

	g <- make_studentized_fixture(seed = 4L)
	g$priv$infer_original_se <- function(...) -1
	expect_error(
		g$inf$compute_bootstrap_confidence_interval(type = "symmetric-percentile-t", B = 100, show_progress = FALSE),
		"Symmetric percentile-t bootstrap CI requires a finite standard error\\."
	)
})
