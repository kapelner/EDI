library(testthat)
library(EDI)

# fill_i_b_with_matches_loop_cpp (KK_bootstrap_helper_fillin.cpp) and
# bisection_ci_loop_cpp (bisection_ci_loop.cpp) are exported Rcpp wrappers
# with no current R-level caller (verified via repo-wide grep), so the bulk
# suite never reached them. Both remain reachable via `.Call`/EDI:::, and
# match sibling wrappers already tested elsewhere (bisection_ci_single_bound_cpp,
# bisection_ci_parallel_cpp), so exercise the exported contracts directly.

fill_i_b_reference <- function(m_vec, ms_b) {
	out <- integer(0)
	for (target in ms_b) {
		found <- which(m_vec == target)
		out <- c(out, (head(found, 2)) )
	}
	out
}

test_that("fill_i_b_with_matches_loop_cpp appends up to two 1-based match indices per target, in place", {
	m_vec <- c(5L, 3L, 5L, 7L, 3L)
	ms_b <- c(5L, 3L)

	i_b <- integer(6)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b, m_vec, ms_b, 0L)
	expect_equal(i_b, c(1L, 3L, 2L, 5L, 0L, 0L))
	expect_equal(i_b[seq_along(fill_i_b_reference(m_vec, ms_b))], fill_i_b_reference(m_vec, ms_b))

	# A target with only one match does not overrun (found never reaches 2).
	i_b_single <- integer(4)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b_single, m_vec, c(7L), 0L)
	expect_equal(i_b_single, c(4L, 0L, 0L, 0L))

	# A target with no matches writes nothing.
	i_b_none <- integer(2)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b_none, m_vec, c(99L), 0L)
	expect_equal(i_b_none, c(0L, 0L))

	# A nonzero starting index offsets where writes begin, leaving the prefix untouched.
	i_b_offset <- integer(6)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b_offset, m_vec, ms_b, 2L)
	expect_equal(i_b_offset, c(0L, 0L, 1L, 3L, 2L, 5L))

	# Empty ms_b leaves i_b untouched.
	i_b_empty_targets <- integer(3)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b_empty_targets, m_vec, integer(0), 0L)
	expect_equal(i_b_empty_targets, c(0L, 0L, 0L))

	# Empty m_vec means every target is unmatched.
	i_b_empty_source <- integer(2)
	EDI:::fill_i_b_with_matches_loop_cpp(i_b_empty_source, integer(0), c(1L, 2L), 0L)
	expect_equal(i_b_empty_source, c(0L, 0L))
})

test_that("bisection_ci_loop_cpp converges both tails and validates inputs like its sibling wrappers", {
	# Missing midpoints are rejected on both tails of a two-sided p-value;
	# the lower and upper searches must still find their .6 and 1.4 crossings,
	# matching the reference behaviour of bisection_ci_single_bound_cpp.
	pval <- function(r, delta, transform_responses) {
		if (delta %in% c(.5, 1.5)) NA_real_ else min(delta, 2 - delta)
	}
	lower <- EDI:::bisection_ci_loop_cpp(pval, 1L, 0, 1, .6, .01, "none", TRUE)
	upper <- EDI:::bisection_ci_loop_cpp(pval, 1L, 1, 2, .6, .01, "none", FALSE)
	expect_equal(lower, .6, tolerance = .01)
	expect_equal(upper, 1.4, tolerance = .01)

	# This wrapper's pval_fn signature omits num_cores (unlike bisection_ci_parallel_cpp's
	# four-argument callback); confirm the exact three-argument transform_responses value
	# is what reaches the callback.
	pval_transform <- function(r, delta, transform_responses) {
		if (transform_responses != "log") stop("wrong transform reached callback")
		min(delta, 2 - delta)
	}
	expect_equal(EDI:::bisection_ci_loop_cpp(pval_transform, 1L, 0, 1, .6, .01, "log", TRUE), .6, tolerance = .01)

	expect_error(
		EDI:::bisection_ci_loop_cpp(pval, 1L, 1, 0, .6, .01, "none", TRUE),
		"finite and ordered"
	)
	expect_error(
		EDI:::bisection_ci_loop_cpp(pval, 1L, 0, 1, .6, -1, "none", TRUE),
		"finite and positive"
	)
	expect_error(
		EDI:::bisection_ci_loop_cpp(pval, 1L, 0, 1, NaN, .01, "none", TRUE),
		"threshold must be finite"
	)
})
