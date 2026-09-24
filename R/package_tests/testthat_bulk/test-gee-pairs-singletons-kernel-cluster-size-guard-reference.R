library(testthat)
library(EDI)

# gee_pairs_singletons_cpp_impl (fast_gee.cpp) -- the shared internal fitter behind both exported
# gee_pairs_singletons_cpp (unweighted) and gee_pairs_singletons_weighted_cpp (weighted), used by the
# KK GEE Inference classes -- validates that no group_id cluster has more than 2 members: `if
# (grp_size[gi] > 2) throw std::invalid_argument("gee_pairs_singletons_cpp: cluster %d has size %d
# (only singletons and pairs are supported)")`. Matches the identical size-guard rationale already
# closed this stretch for fast_gaussian_lmm.cpp's group-size guard: this is a closed-form solver
# specific to KK-design matched-pair/reservoir-singleton clusters. A codebase-wide grep across
# testthat_bulk/, R/package_tests/testthat/ and R/EDI/tests/testthat/ confirms this guard had no test
# reference anywhere for either kernel (the 2 existing reference files that call into this file
# always use real KK matched-pair/reservoir cluster structures).

fx <- function(seed = 19L, n = 9L) {
	set.seed(seed)
	X <- cbind(1, rnorm(n))
	y <- rnorm(n)
	list(X = X, y = y, bad_group_id = c(1L, 1L, 1L, 2L, 2L, 3L, 4L, 4L, 5L))   # cluster 1 has 3 members
}
pattern <- "gee_pairs_singletons_cpp: cluster \\d+ has size \\d+ \\(only singletons and pairs are supported\\)"

test_that("gee_pairs_singletons_cpp (unweighted) rejects a cluster with more than 2 observations", {
	d <- fx()
	f <- get("gee_pairs_singletons_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id, "gaussian"), pattern)
})

test_that("gee_pairs_singletons_weighted_cpp rejects a cluster with more than 2 observations", {
	d <- fx(seed = 20L)
	f <- get("gee_pairs_singletons_weighted_cpp", envir = asNamespace("EDI"))
	expect_error(f(d$X, d$y, d$bad_group_id, "gaussian", rep(1, length(d$y))), pattern)
})

test_that("the guard fires identically for binomial and poisson families too", {
	d <- fx(seed = 21L)
	f <- get("gee_pairs_singletons_cpp", envir = asNamespace("EDI"))
	y_bin <- as.numeric(d$y > median(d$y))
	y_pois <- rpois(length(d$y), 2)
	expect_error(f(d$X, y_bin, d$bad_group_id, "binomial"), pattern)
	expect_error(f(d$X, y_pois, d$bad_group_id, "poisson"), pattern)
})

test_that("well-formed clusters (all size 1 or 2) do not trigger the guard on either kernel", {
	d <- fx(seed = 22L)
	good_group_id <- c(1L, 1L, 2L, 2L, 3L, 4L, 4L, 5L, 5L)

	r1 <- get("gee_pairs_singletons_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id, "gaussian")
	expect_true(r1$converged)

	r2 <- get("gee_pairs_singletons_weighted_cpp", envir = asNamespace("EDI"))(d$X, d$y, good_group_id, "gaussian", rep(1, length(d$y)))
	expect_true(r2$converged)
})
