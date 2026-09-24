library(testthat)
library(EDI)

# sample_int_replace_cpp (fast_sample_int.cpp) draws `size` integers uniformly from 1..n with
# replacement, seeded from one R::unif_rand() draw into a portable re-implementation of R's own
# Mersenne-Twister (see the source's own reproducibility note). Despite real, heavy production usage
# as the plain i.i.d.-subject nonparametric bootstrap draw across many design classes
# (design_abstract.R, design_matching_abstract.R, design_seq_one_by_one_pocock_simon.R,
# design_fixed_matching_greedy_pair_switching.R, design_component_registry.R, and two KK IVWC
# inference classes), a codebase-wide grep across testthat_bulk/, R/package_tests/testthat/ and
# R/EDI/tests/testthat/ confirms ZERO test references of any kind for this exported kernel -- the
# same situation already found and closed this stretch for its file-sibling
# resample_group_rows_cpp.
#
# There is no independent R reference for this exact bespoke RNG stream (a different generator than
# base R's sample()), so this file pins the properties that ARE independently verifiable: output
# shape/range/type contracts, the size = 0 and n = 1 edge cases, reproducibility under set.seed(),
# and approximate uniformity via a chi-squared goodness-of-fit test on a large draw (a standard,
# non-flaky way to validate an RNG kernel's distributional correctness without depending on its
# internal implementation).

f <- get("sample_int_replace_cpp", envir = asNamespace("EDI"))

test_that("size = 0 returns an empty integer vector regardless of n", {
	expect_identical(f(5L, 0L), integer(0))
	expect_identical(f(1L, 0L), integer(0))
})

test_that("n = 1 always returns a vector of 1s of the requested length", {
	expect_identical(f(1L, 5L), rep(1L, 5L))
})

test_that("output has the requested length, is integer-valued, and every value lies in [1, n]", {
	set.seed(11)
	out <- f(7L, 100L)
	expect_length(out, 100L)
	expect_true(is.integer(out) || all(out == round(out)))
	expect_true(all(out >= 1L & out <= 7L))
})

test_that("draws are reproducible under an identical set.seed() and differ across distinct seeds", {
	set.seed(21); a <- f(10L, 20L)
	set.seed(21); b <- f(10L, 20L)
	expect_identical(a, b)

	set.seed(22); c_ <- f(10L, 20L)
	expect_false(identical(a, c_))
})

test_that("a large draw is approximately uniform over 1..n (chi-squared goodness-of-fit)", {
	set.seed(31)
	draw <- f(5L, 50000L)
	tab <- table(factor(draw, levels = 1:5))
	expect_equal(sum(tab), 50000L)
	pval <- suppressWarnings(chisq.test(tab)$p.value)
	expect_gt(pval, 0.001)   # loose, non-flaky threshold: only fails if grossly non-uniform
})
