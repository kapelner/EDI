library(testthat)
library(EDI)

# helper_matching.R's compute_binary_match_structure(X, mahal_match = TRUE)'s
# singular-covariance guard: when stats::var(X) is (numerically) singular, the
# function retries solve() against 6 escalating ridge-regularized versions
# (diag(ridge, p) added, ridge doubling^10-ish from 1e-8) before giving up and
# stop()-ing "Covariance matrix is singular; cannot compute Mahalanobis
# distances.". Existing coverage (test-matching-blocking-geometry-references.R)
# only exercises the non-singular, mahal_match = TRUE success path and the
# mahal_match = FALSE (Euclidean) path -- this guard itself was never
# triggered anywhere. Confirmed reachable (not just theoretical dead code) by
# probing directly: two exactly-collinear columns at ordinary scale get
# "fixed" by the ridge additions (they're tiny relative to typical variances),
# but at a large enough scale the ridge additions (up to ~1e-3) are
# numerically negligible next to the ~1e15-magnitude collinear covariance
# entries, and solve() keeps reporting exact singularity through all 6
# attempts -- reproducing the real failure mode this guard exists for
# (a covariate that is exactly collinear with another, not just near-collinear).

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("a covariate matrix with an exactly collinear pair at large scale stays singular through every ridge attempt and stops with the documented message", {
	skip_if_not_installed("nbpMatching")
	set.seed(1)
	n <- 6L
	x1 <- rnorm(n) * 1e8
	X <- cbind(a = x1, b = x1)                                    # b is an exact linear copy of a
	S <- stats::var(X)
	expect_error(solve(S), "singular")                             # sanity: the raw covariance really is singular
	for (ridge in 1e-8 * 10^(0:5)) {
		expect_error(solve(S + diag(ridge, ncol(S))), "singular")    # sanity: every one of the 6 escalation levels still fails
	}
	expect_error(
		K("compute_binary_match_structure")(X, mahal_match = TRUE),
		"Covariance matrix is singular; cannot compute Mahalanobis distances\\."
	)
})

test_that("the same exactly collinear pair at ordinary scale IS recovered by ridge regularization (guard does not misfire on realistic data)", {
	skip_if_not_installed("nbpMatching")
	set.seed(2)
	n <- 6L
	x1 <- rnorm(n)
	X <- cbind(a = x1, b = x1)
	expect_no_error(K("compute_binary_match_structure")(X, mahal_match = TRUE))
})

test_that("a genuinely non-singular covariate matrix is unaffected by the guard and matches an independent Mahalanobis pairing", {
	skip_if_not_installed("nbpMatching")
	X <- cbind(c(0, 0.1, 10, 10.2), c(0, 0.2, 2, 2.1))
	S_inv <- solve(stats::var(X))
	ref_D <- matrix(NA_real_, 4, 4)
	for (i in 1:4) for (j in 1:4) {
		d <- X[i, ] - X[j, ]
		ref_D[i, j] <- as.numeric(t(d) %*% S_inv %*% d)
	}
	possible <- list(matrix(c(1, 2, 3, 4), 2, byrow = TRUE),
	                  matrix(c(1, 3, 2, 4), 2, byrow = TRUE),
	                  matrix(c(1, 4, 2, 3), 2, byrow = TRUE))
	cost <- function(pairs) sum(ref_D[pairs])
	fit <- K("compute_binary_match_structure")(X, mahal_match = TRUE)
	expect_equal(cost(fit$indices_pairs), min(vapply(possible, cost, numeric(1))), tolerance = 1e-8)
})
