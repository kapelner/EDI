library(testthat)
library(EDI)

# zhang_ci_exact_combined()'s num_cores > 1 branch (inference_helpers_zhang.R) dispatches to
# zhang_compute_ci_bounds_parallel(), a fork-parallel variant of the same lower/upper bisection search
# the serial (num_cores = 1) path already performs directly -- duplicating the inference object per
# worker, recomputing each bound's exact-stats independently, and combining both bounds' results. A
# codebase-wide grep confirmed zhang_compute_ci_bounds_parallel had zero test references anywhere:
# test-zhang-exact-incidence-stats-pvalues-and-ci-search-reference.R's existing exact-CI coverage
# always runs with the default num_cores = 1, so the parallel branch itself was never exercised, even
# though it's a real, non-trivial 2-worker fork-parallel code path (private$par_lapply with
# n_cores = 2, already an established, safe pattern used by 10+ other test files in this suite).
# Reached by setting inf$num_cores <- 2L on the same KK matched-pair-plus-reservoir fixture used by the
# existing serial test, and comparing the resulting interval to the identical seed's serial-path result
# for exact numeric equality (both branches perform the same deterministic bisection search, so they
# must agree bit-for-bit).

kk_fx <- function(seed = 6L, np = 15L, ns = 14L) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	des$.__enclos_env__$private$m <- m
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(0.8 * w))
	des$add_all_subject_responses(y)
	InferenceIncidExactZhang$new(des, verbose = FALSE)
}

test_that("the num_cores > 1 parallel exact-CI bisection search matches the serial (num_cores = 1) result exactly, on the same design", {
	inf_serial <- kk_fx()
	ci_serial <- inf_serial$compute_exact_confidence_interval(0.1)

	inf_parallel <- kk_fx()
	inf_parallel$num_cores <- 2L
	ci_parallel <- inf_parallel$compute_exact_confidence_interval(0.1)

	expect_equal(as.numeric(ci_parallel), as.numeric(ci_serial), tolerance = 1e-8)
	expect_length(ci_parallel, 2L)
	est <- inf_parallel$compute_estimate()
	expect_lt(ci_parallel[[1]], est)
	expect_gt(ci_parallel[[2]], est)
})

test_that("the parallel path also agrees on a Bernoulli (no matched-pair) design", {
	set.seed(3L)
	n <- 40L
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.2 + 0.8 * w))
	des$add_all_subject_responses(y)

	inf_serial <- InferenceIncidExactZhang$new(des$clone(deep = TRUE), verbose = FALSE)
	ci_serial <- inf_serial$compute_exact_confidence_interval(0.05)

	inf_parallel <- InferenceIncidExactZhang$new(des$clone(deep = TRUE), verbose = FALSE)
	inf_parallel$num_cores <- 2L
	ci_parallel <- inf_parallel$compute_exact_confidence_interval(0.05)

	expect_equal(as.numeric(ci_parallel), as.numeric(ci_serial), tolerance = 1e-8)
})
