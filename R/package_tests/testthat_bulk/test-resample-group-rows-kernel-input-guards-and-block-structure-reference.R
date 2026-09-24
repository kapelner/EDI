library(testthat)
library(EDI)

# resample_group_rows_cpp (fast_sample_int.cpp) draws sample_size groups with replacement and
# returns the concatenated original row indices of each drawn group (whole-block resampling), used
# by the fixed-blocking/clustering/stratified design bootstrap machinery (design_fixed_blocking.R,
# design_fixed_cluster.R, design_fixed_blocked_cluster.R, design_component_registry.R). Despite this
# real, heavy production usage, a codebase-wide grep across testthat_bulk/, R/package_tests/testthat/
# and R/EDI/tests/testthat/ confirms ZERO test references of any kind for this exported kernel --
# neither its three input guards nor its actual block-resampling behavior.
#   1. `if (sample_size < 0) throw ("sample_size must be non-negative.")`.
#   2. `if (group_id[i] <= 0) throw ("group_id must contain only positive integers.")`.
#   3. `if any group in [1, max(group_id)] has zero members) throw ("group_id must be consecutive
#      positive integers starting at 1.")`.
# The block-structure test below decodes the flat output back into the sequence of drawn groups by
# greedily matching each group's exact, ordered row-index vector as a prefix -- an independent
# structural check that a real bootstrap draw only ever returns whole, intact groups (never a mix of
# rows from different groups, and never a partial group), plus reproducibility under set.seed().

f <- get("resample_group_rows_cpp", envir = asNamespace("EDI"))

test_that("a negative sample_size throws the non-negative error", {
	expect_error(f(c(1L, 1L, 2L), -1L), "sample_size must be non-negative")
})

test_that("a non-positive group_id value throws the positive-integers error", {
	expect_error(f(c(0L, 1L, 2L), 3L), "group_id must contain only positive integers")
	expect_error(f(c(1L, -2L, 2L), 3L), "group_id must contain only positive integers")
})

test_that("a group_id with a gap (non-consecutive from 1) throws the consecutive-integers error", {
	expect_error(f(c(1L, 1L, 3L, 3L), 4L), "group_id must be consecutive positive integers starting at 1")
})

test_that("sample_size = 0 returns an empty result without touching group_id at all", {
	expect_identical(f(c(1L, 2L, 3L), 0L), integer(0))
	expect_identical(f(integer(0), 0L), integer(0))
})

test_that("a real draw returns only whole, intact groups in original row order, decodable back to a group sequence of the requested length, and is reproducible under set.seed()", {
	gid <- c(1L, 1L, 2L, 2L, 2L, 3L)
	groups <- split(seq_along(gid), gid)
	decode <- function(out) {
		remaining <- out
		decoded <- integer(0)
		while (length(remaining) > 0) {
			matched <- FALSE
			for (gname in names(groups)) {
				grp <- groups[[gname]]
				L <- length(grp)
				if (length(remaining) >= L && identical(remaining[seq_len(L)], grp)) {
					decoded <- c(decoded, as.integer(gname))
					remaining <- remaining[-seq_len(L)]
					matched <- TRUE
					break
				}
			}
			if (!matched) return(NULL)
		}
		decoded
	}

	set.seed(42)
	out1 <- f(gid, 8L)
	decoded1 <- decode(out1)
	expect_false(is.null(decoded1))
	expect_length(decoded1, 8L)
	expect_true(all(out1 %in% seq_along(gid)))

	set.seed(42)
	out2 <- f(gid, 8L)
	expect_identical(out1, out2)
})
