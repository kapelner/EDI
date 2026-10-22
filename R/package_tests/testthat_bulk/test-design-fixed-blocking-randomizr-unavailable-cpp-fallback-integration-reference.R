library(testthat)
library(EDI)

# DesignFixedBlocking$draw_ws_raw() uses the internal batched block_ra_batch() helper (TODO-118),
# which does not depend on randomizr at all (the old generate_permutations_blocking_cpp() kernel
# was deleted 2026-10-22). This test pins that behaviour end to end through the public API with
# randomizr mocked as unavailable: every stratum must get exactly round(prob_T * stratum_size)
# treated subjects.

test_that("with randomizr (mocked as) unavailable, assign_w_to_all_subjects() still balances every block via the C++ fallback", {
	set.seed(1)
	n <- 24L
	des <- DesignFixedBlocking$new(n = n, B_target = 4L, equal_block_sizes = TRUE, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))

	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		des$assign_w_to_all_subjects()
	)

	w <- des$get_w()
	blocks <- des$get_block_ids()
	expect_true(all(w %in% c(0, 1)))
	for (blk in unique(blocks)) {
		idx <- blocks == blk
		size <- sum(idx)
		expect_equal(sum(w[idx]), round(0.5 * size), info = paste("block", blk))
	}
})

test_that("the fallback also balances with a different seed/block count (default equal_block_sizes = TRUE)", {
	set.seed(3)
	n <- 32L
	des <- DesignFixedBlocking$new(n = n, B_target = 8L, equal_block_sizes = TRUE, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))

	with_mocked_bindings(
		check_package_installed = function(pkg) FALSE,
		.package = "EDI",
		des$assign_w_to_all_subjects()
	)

	w <- des$get_w()
	blocks <- des$get_block_ids()
	for (blk in unique(blocks)) {
		idx <- blocks == blk
		size <- sum(idx)
		expect_equal(sum(w[idx]), round(0.5 * size), info = paste("block", blk))
	}
})
