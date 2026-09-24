library(testthat)
library(EDI)

# distance_matrix_custom_cpp() / optimal_blocks_distance_matrix_cpp() (optimal_blocks_distance.cpp),
# the custom-distance-function dispatch used by DesignFixedOptimalBlocks whenever a user supplies a
# function as its `dist` argument, have three defensive guards: distance_matrix_custom_cpp() stops
# with "Custom dist must return one finite nonnegative number per subject pair." whenever the
# user-supplied dist function's return value isn't a single numeric (wrong type or length), and
# separately whenever it IS numeric but non-finite or negative; optimal_blocks_distance_matrix_cpp()
# itself stops with "Custom distance dispatch requires a distance function." when dist_code selects
# the custom path (0L) but no dist_fn is supplied at all (unreachable via the R-level
# DesignFixedOptimalBlocks wrapper, which always supplies dist_fn together with dist_code = 0L, but a
# real, directly-callable guard on the exported kernel itself). A codebase-wide grep confirmed none of
# these had any test reference anywhere -- the only existing reference to distance_matrix_custom_cpp()
# (test-proportion-interval-and-distance-matrix-kernels-reference.R) exercises only a well-formed
# custom distance function.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("distance_matrix_custom_cpp() rejects a non-numeric or wrong-length return from the dist function", {
	Y <- matrix(rnorm(12), 4, 3)
	expect_error(
		K("distance_matrix_custom_cpp")(Y, function(a, b) "not numeric"),
		"Custom dist must return one finite nonnegative number per subject pair.",
		fixed = TRUE
	)
	expect_error(
		K("distance_matrix_custom_cpp")(Y, function(a, b) c(1, 2)),
		"Custom dist must return one finite nonnegative number per subject pair.",
		fixed = TRUE
	)
})

test_that("distance_matrix_custom_cpp() rejects a numeric return that is non-finite or negative", {
	Y <- matrix(rnorm(12), 4, 3)
	expect_error(
		K("distance_matrix_custom_cpp")(Y, function(a, b) -1),
		"Custom dist must return one finite nonnegative number per subject pair.",
		fixed = TRUE
	)
	expect_error(
		K("distance_matrix_custom_cpp")(Y, function(a, b) NA_real_),
		"Custom dist must return one finite nonnegative number per subject pair.",
		fixed = TRUE
	)
	expect_error(
		K("distance_matrix_custom_cpp")(Y, function(a, b) Inf),
		"Custom dist must return one finite nonnegative number per subject pair.",
		fixed = TRUE
	)
})

test_that("a well-formed custom distance function does not trigger either guard", {
	Y <- matrix(rnorm(12), 4, 3)
	D <- K("distance_matrix_custom_cpp")(Y, function(a, b) sum(abs(a - b)))
	expect_equal(dim(D), c(4L, 4L))
	expect_true(all(is.finite(D)))
})

test_that("optimal_blocks_distance_matrix_cpp() rejects dist_code = 0L (custom) with no dist_fn supplied", {
	Y <- matrix(rnorm(12), 4, 3)
	expect_error(
		K("optimal_blocks_distance_matrix_cpp")(Y, dist_code = 0L),
		"Custom distance dispatch requires a distance function.",
		fixed = TRUE
	)
})
