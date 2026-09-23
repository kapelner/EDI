library(testthat)
library(EDI)

# helper_matching.R's compute_binary_match_structure(X, mahal_match) stop()s "Design matrix must
# have an even number of rows for binary matching." when nrow(X) is odd -- checked immediately after
# the nbpmatching-availability assertion, before any pairing computation. The sibling "Covariance
# matrix is singular; cannot compute Mahalanobis distances." guard in the same function is already
# covered (test-binary-match-structure-singular-covariance-mahalanobis-guard-reference.R), but this
# even-rows guard had zero test references anywhere.

test_that("compute_binary_match_structure(): an odd number of rows errors with the documented message", {
	f <- getFromNamespace("compute_binary_match_structure", "EDI")
	X <- matrix(rnorm(3L * 2L), nrow = 3L, ncol = 2L)
	expect_error(
		f(X),
		"Design matrix must have an even number of rows for binary matching\\."
	)
})

test_that("compute_binary_match_structure(): an even number of rows with p == 1 succeeds without error", {
	f <- getFromNamespace("compute_binary_match_structure", "EDI")
	set.seed(1)
	X <- matrix(rnorm(8L), ncol = 1L)
	res <- f(X)
	expect_true(is.list(res))
	expect_true("indicies_pairs" %in% names(res))
	expect_equal(dim(res$indicies_pairs), c(4L, 2L))
})
