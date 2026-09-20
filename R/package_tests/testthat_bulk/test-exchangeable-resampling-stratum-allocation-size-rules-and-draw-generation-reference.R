library(testthat)
library(EDI)

# InferenceExtExchangeableResamplingUnits (spliced into the bootstrap base):
# allocate_resampling_sizes_by_stratum() (largest-remainder rounding and the
# without-replacement capacity guard), resolve_resampling_size() bounds,
# get_resampling_strata_ids(), and generate_exchangeable_resampling_draws()
# (B draws, stratified counts, distinctness without replacement, ordering).
# The sibling file covers cluster/block units and the single-draw builders.

rs_fx <- function(n = 40L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBlocking$new(strata_cols = "g", response_type = "continuous", n = n, seed = seed,
		verbose = FALSE, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(data.frame(g = factor(rep(c("a", "b"), c(30, 10))), x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(des$get_w() + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, p = inf$.__enclos_env__$private, n = n)
}

test_that("stratum allocation uses largest-remainder rounding and always sums to the total", {
	p <- rs_fx()$p
	a <- p$allocate_resampling_sizes_by_stratum(8L, rep(c("a", "b"), c(30, 10)), replace = FALSE)
	expect_equal(a, c(a = 6, b = 2))
	# raw = 3.5, 2.1, 1.4 -> floors 3,2,1 -> the one extra unit goes to the largest fraction (.5).
	ids <- rep(c("x", "y", "z"), c(5, 3, 2))
	a <- p$allocate_resampling_sizes_by_stratum(7L, ids, replace = TRUE)
	expect_equal(a, c(x = 4, y = 2, z = 1))
	for (tot in 1:10) expect_equal(sum(p$allocate_resampling_sizes_by_stratum(tot, ids, TRUE)), tot)
	# Names follow first appearance; numeric strata ids are coerced to character.
	a2 <- p$allocate_resampling_sizes_by_stratum(4L, c(3, 3, 1, 1, 3, 1), TRUE)
	expect_equal(names(a2), c("3", "1"))
	expect_equal(sum(a2), 4)
	# Exact proportions need no rounding.
	expect_equal(p$allocate_resampling_sizes_by_stratum(10L, rep(c("u", "v"), c(5, 5)), TRUE), c(u = 5, v = 5))
})

test_that("without replacement, a stratum too small for its share is an error; with replacement it is allowed", {
	p <- rs_fx()$p
	ids <- c("a", "b")                                   # one unit per stratum
	expect_error(p$allocate_resampling_sizes_by_stratum(6L, ids, replace = FALSE), "Subsampling stratum is too small")
	expect_equal(p$allocate_resampling_sizes_by_stratum(6L, ids, replace = TRUE), c(a = 3, b = 3))
	expect_error(p$allocate_resampling_sizes_by_stratum(3L, c("a", "a", "b"), replace = FALSE), NA)  # 2 of a, 1 of b fits
})

test_that("resampling size defaults to floor(n^0.7) and must lie in [max(5, p + 2), floor(n / 2)]", {
	f <- rs_fx(); p <- f$p
	expect_equal(p$resampling_effective_p(), 2L)                          # intercept-free X: treatment + covariate
	expect_equal(p$resolve_resampling_size(NULL, 40, "m"), floor(40^0.7))
	expect_equal(p$resolve_resampling_size(NULL, 40, "m", deterministic_exponent = 0.5), 6L)
	expect_equal(p$resolve_resampling_size(7.9, 40, "m"), 7L)
	expect_equal(p$resolve_resampling_size(20, 40, "m"), 20L)
	expect_error(p$resolve_resampling_size(21, 40, "m"), "m must satisfy 5 <= m <= 20")
	expect_error(p$resolve_resampling_size(4, 40, "m"), "5 <= m <= 20")
	expect_error(p$resolve_resampling_size(NA, 40, "m"), "must satisfy")
	expect_error(p$resolve_resampling_size(list(1), 40, "b"), "b selection must be resolved before drawing")
	# The minimum grows with the covariate count.
	unlockBinding("resampling_effective_p", p)
	p$resampling_effective_p <- function() 9L
	expect_error(p$resolve_resampling_size(10, 40, "m"), "11 <= m <= 20")
	expect_equal(p$resolve_resampling_size(11, 40, "m"), 11L)
})

test_that("strata ids come from the design's strata keys, and are NULL without them", {
	f <- rs_fx()
	expect_equal(f$p$get_resampling_strata_ids(), rep(c("a", "b"), c(30, 10)))
	des <- DesignFixedBernoulli$new(n = 10L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = 1:10)); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(10))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	expect_null(inf$.__enclos_env__$private$get_resampling_strata_ids())
})

test_that("generated draws: B replicates, requested size, stratified counts, distinct rows without replacement", {
	f <- rs_fx(); p <- f$p
	ui <- p$get_exchangeable_units("observation")
	set.seed(3)
	d <- p$generate_exchangeable_resampling_draws(ui, 25L, 8L, replace = FALSE, stratified = TRUE, preserve_order = FALSE, size_label = "m")
	expect_length(d, 25L)
	strata <- ui$strata_ids
	for (x in d) {
		expect_length(x$i_b, 8L)
		expect_equal(x$m, 8L)
		expect_equal(x$unit_type, "observation")
		expect_equal(x$n_units, 40L)
		expect_false(anyDuplicated(x$i_b) > 0)
		expect_equal(sum(strata[x$i_b] == "a"), 6L); expect_equal(sum(strata[x$i_b] == "b"), 2L)
		expect_equal(x$i_b, x$unit_ids)                       # observation units are rows
		expect_null(x$m_vec_b)
	}
	# With replacement draws can repeat; unstratified draws ignore the 6/2 split.
	set.seed(4)
	dr <- p$generate_exchangeable_resampling_draws(ui, 200L, 12L, replace = TRUE, stratified = FALSE, preserve_order = FALSE, size_label = "b")
	expect_true(any(vapply(dr, function(x) anyDuplicated(x$i_b) > 0, logical(1))))
	expect_true(all(vapply(dr, function(x) x$b == 12L, logical(1))))
	na <- vapply(dr, function(x) sum(strata[x$i_b] == "a"), numeric(1))
	expect_gt(length(unique(na)), 1L)                          # not pinned at an allocation
	expect_equal(mean(na), 12 * 0.75, tolerance = 0.1)
	# preserve_order sorts each draw's rows.
	dp <- p$generate_exchangeable_resampling_draws(ui, 10L, 8L, FALSE, TRUE, TRUE, "m")
	expect_true(all(vapply(dp, function(x) !is.unsorted(x$i_b), logical(1))))
})

test_that("draw generation is reproducible under a seed", {
	p <- rs_fx()$p
	ui <- p$get_exchangeable_units("observation")
	set.seed(9); a <- p$generate_exchangeable_resampling_draws(ui, 5L, 8L, FALSE, TRUE, FALSE, "m")
	set.seed(9); b <- p$generate_exchangeable_resampling_draws(ui, 5L, 8L, FALSE, TRUE, FALSE, "m")
	expect_equal(lapply(a, `[[`, "i_b"), lapply(b, `[[`, "i_b"))
})
