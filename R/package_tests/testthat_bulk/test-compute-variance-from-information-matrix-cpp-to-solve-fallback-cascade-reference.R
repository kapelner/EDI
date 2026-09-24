library(testthat)
library(EDI)

# InferenceExtInformationMatrix's private compute_variance_from_information_matrix()
# (inference_ext_information_matrix.R) has a three-tier fallback cascade for the multi-parameter
# (nrow > 1) case: a fast Rcpp single-entry-of-the-inverse computation first, then
# tryCatch(solve(information)), then tryCatch(qr.solve(information, diag(...))) if solve() also
# fails, and only then NA_real_. Every existing test (test-inference-core-cache-and-matrix-contracts.R,
# test-ext-information-matrix.R, test-information-score-analytic-references.R) supplies a
# well-conditioned information matrix the Rcpp path handles directly on the first try, so the R-level
# solve()/qr.solve() fallback tiers -- confirmed reachable only by forcing the Rcpp call itself to
# fail -- had never actually been exercised.
#   1. When eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp() returns a non-finite value,
#      the solve() fallback engages and matches an independent solve(information)[j, j]) exactly.
#   2. When solve() ALSO fails, the qr.solve() fallback engages (a call-count probe confirms it fires)
#      and matches an independent qr.solve(information, diag(p))[j, j] exactly.
#   3. When every tier fails, the result is NA_real_, not an error.

make_information_matrix_inference <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	x <- rnorm(n)
	w <- rep(c(1, 0), length.out = n)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(rbinom(n, 1L, plogis(-0.2 + 0.5 * w + 0.3 * x)))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf$.__enclos_env__$private
}

test_that("when the Rcpp entry-extractor returns non-finite, the solve() fallback engages and matches an independent solve() exactly", {
	priv <- make_information_matrix_inference(1L)
	info <- matrix(c(4, 1, 1, 3), 2, 2)
	local_mocked_bindings(eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp = function(...) NA_real_, .package = "EDI")

	res <- priv$compute_variance_from_information_matrix(info, 2L)
	expect_equal(res, solve(info)[2, 2], tolerance = 1e-10)
})

test_that("when solve() also fails, the qr.solve() fallback engages and matches an independent qr.solve() exactly", {
	priv <- make_information_matrix_inference(2L)
	info <- matrix(c(4, 1, 1, 3), 2, 2)
	local_mocked_bindings(eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp = function(...) NA_real_, .package = "EDI")

	solve_calls <- 0L
	local_mocked_bindings(solve = function(...) { solve_calls <<- solve_calls + 1L; stop("forced solve() failure") }, .package = "base")
	res <- priv$compute_variance_from_information_matrix(info, 2L)
	expect_equal(solve_calls, 1L)                                                   # solve() really was tried and really did fail
	expect_equal(res, qr.solve(info, diag(2))[2, 2], tolerance = 1e-10)
})

test_that("when every tier fails, the result is NA_real_, not an error", {
	priv <- make_information_matrix_inference(3L)
	info <- matrix(c(4, 1, 1, 3), 2, 2)
	local_mocked_bindings(
		eigen_compute_single_entry_on_diagonal_of_inverse_matrix_cpp = function(...) NA_real_,
		.package = "EDI"
	)
	local_mocked_bindings(solve = function(...) stop("forced solve() failure"), .package = "base")
	local_mocked_bindings(qr.solve = function(...) stop("forced qr.solve() failure"), .package = "base")
	res <- priv$compute_variance_from_information_matrix(info, 2L)
	expect_true(is.na(res))
})
