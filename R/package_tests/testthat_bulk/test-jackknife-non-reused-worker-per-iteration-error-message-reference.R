library(testthat)
library(EDI)

# InferenceNonParamBootstrap's jackknife machinery (inference_all_abstract_non_param_boot.R:1683-1694)
# has a non-reused-worker fallback path (when use_reusable_bootstrap_worker() is FALSE) that catches
# a per-iteration compute_estimate() error, emits message("Jackknife error at iteration ", i, ": ",
# e$message), and records NA for that draw rather than aborting the whole jackknife. A codebase-wide
# grep confirmed this exact message had zero test references anywhere -- the reused-worker path
# (used by InferenceAllSimpleAverageDiff and most other classes by default) never reaches this
# branch at all. Forced by directly disabling reusable_bootstrap_worker_enabled (unlockBinding) and
# stubbing bootstrap_subset_inference() to return a fake sub-inference object whose compute_estimate()
# always throws -- both scoped to a single throwaway instance, no global state touched.

test_that("the non-reused-worker jackknife path emits a per-iteration error message and records NA for each failing draw", {
	set.seed(1)
	n <- 20L
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(rnorm(n) + 0.5 * w)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private

	unlockBinding("reusable_bootstrap_worker_enabled", priv)
	priv$reusable_bootstrap_worker_enabled <- FALSE
	expect_false(priv$use_reusable_bootstrap_worker())

	unlockBinding("bootstrap_subset_inference", priv)
	priv$bootstrap_subset_inference <- function(draw, smooth) {
		list(compute_estimate = function(estimate_only) stop("boom"))
	}

	msgs <- character(0)
	res <- withCallingHandlers(
		inf$compute_jackknife_estimate(unit = "auto"),
		message = function(m) {
			msgs[[length(msgs) + 1]] <<- conditionMessage(m)
			invokeRestart("muffleMessage")
		}
	)

	expect_true(any(grepl("^Jackknife error at iteration 1: boom", msgs)))
	expect_true(is.na(res))
})
