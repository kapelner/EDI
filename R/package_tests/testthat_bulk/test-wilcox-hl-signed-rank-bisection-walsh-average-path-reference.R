library(testthat)
library(EDI)

# wilcox_hl_signed_rank_point_estimate_cpp (fast_wilcox_hl.cpp) has two implementations selected by
# input size: for m*(m+1)/2 <= kExactMedianMaterializeLimit (4096, i.e. up to 90 finite diffs) it
# materializes every pairwise Walsh average and takes their exact median; above that threshold
# (lines 135-189/242-247) it instead sorts and does a bisection search for the Walsh-average median,
# to avoid materializing an O(m^2) vector for large inputs. The only existing reference test
# (test-poisson-probit-kernels-hodges-lehmann-and-missingness-utility-reference.R) uses 17 diffs,
# which only ever exercises the small/exact-materialize path -- the bisection path (needing more
# than 90 diffs) had no test reference anywhere.

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("the bisection Walsh-average path (>90 diffs) matches the exact median of pairwise Walsh averages", {
	fn <- K("wilcox_hl_signed_rank_point_estimate_cpp")
	set.seed(11)
	for (m in c(91L, 120L, 300L)) {
		dy <- rnorm(m, 0.4, 2)
		wa <- outer(dy, dy, "+") / 2
		ref <- median(wa[upper.tri(wa, diag = TRUE)])
		expect_equal(fn(dy), ref, tolerance = 1e-8, info = m)
		expect_gt(m * (m + 1) / 2, 4096)  # confirms this m is actually above the materialize-limit threshold
	}
})

test_that("the bisection path also matches wilcox.test's one-sample Hodges-Lehmann estimator", {
	fn <- K("wilcox_hl_signed_rank_point_estimate_cpp")
	set.seed(12)
	dy <- rnorm(150L, -0.7, 1.5)
	expect_equal(fn(dy), unname(wilcox.test(dy, conf.int = TRUE)$estimate), tolerance = 1e-4)
})

test_that("the bisection path is shift-equivariant", {
	fn <- K("wilcox_hl_signed_rank_point_estimate_cpp")
	set.seed(13)
	dy <- rnorm(200L)
	base <- fn(dy)
	expect_equal(fn(dy + 3.5), base + 3.5, tolerance = 1e-8)
})
