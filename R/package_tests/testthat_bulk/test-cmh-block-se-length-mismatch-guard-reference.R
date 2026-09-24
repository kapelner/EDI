library(testthat)
library(EDI)

# compute_cmh_block_se_cpp(y, m_vec, n_total) (cmh_speedups.cpp) guards on y and m_vec having the same
# length before doing any block-accumulation work: "compute_cmh_block_se_cpp: y and m_vec must have
# the same length." A codebase-wide grep confirmed this exact message had zero test references
# anywhere, despite the function itself being extensively tested elsewhere (test-cmh-flat-vector.R,
# test-todo98-new-kernel-smoke.R) -- every existing reference supplies correctly length-matched y/m_vec
# pairs and covers the separate n_total <= 0 -> NA branch, but never this length-mismatch guard.

test_that("compute_cmh_block_se_cpp() rejects y and m_vec of different lengths", {
	expect_error(
		EDI:::compute_cmh_block_se_cpp(c(1, 0, 1), c(1L, 2L), 10L),
		"compute_cmh_block_se_cpp: y and m_vec must have the same length.",
		fixed = TRUE
	)
	expect_error(
		EDI:::compute_cmh_block_se_cpp(c(1, 0), c(1L, 2L, 3L), 10L),
		"compute_cmh_block_se_cpp: y and m_vec must have the same length.",
		fixed = TRUE
	)
})

test_that("matching lengths never trigger the guard", {
	expect_no_error(EDI:::compute_cmh_block_se_cpp(c(1, 0, 1, 0), c(1L, 1L, 2L, 2L), 10L))
})
