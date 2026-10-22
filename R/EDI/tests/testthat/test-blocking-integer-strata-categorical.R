# TODO-105: few-level integer strata columns are categorical, not quantile-binned.
.t105_blocks = function(col, ...) {
	n = length(col)
	des = DesignFixedBlocking$new(n = n, response_type = "continuous",
		strata_cols = "s", equal_block_sizes = FALSE, verbose = FALSE, ...)
	des$add_all_subjects_to_experiment(data.frame(s = col, x = seq_len(n) %% 7))
	des$get_block_ids()
}

test_that("integer / numeric site codes with few levels give one block per value", {
	site = rep(1:4, each = 15)
	expect_equal(length(unique(.t105_blocks(site))), 4L)
	expect_equal(length(unique(.t105_blocks(as.numeric(site)))), 4L)
	expect_equal(length(unique(.t105_blocks(as.character(site)))), 4L)
	expect_equal(length(unique(.t105_blocks(factor(site)))), 4L)
	b = .t105_blocks(site)
	expect_equal(length(unique(b[site == 1])), 1L)
})

test_that("continuous-like numeric strata columns are still quantile-binned", {
	set.seed(2)
	age = sample(18:80, 60, replace = TRUE)           # integer, > 10 distinct values
	expect_equal(length(unique(.t105_blocks(age))), 2L)
	expect_equal(length(unique(.t105_blocks(rnorm(60)))), 2L)
	expect_equal(length(unique(.t105_blocks(rep(1:30, 2)))), 2L)
})

test_that("exact_num_blocks still reaches its target with a few-level integer column", {
	site = rep(1:4, each = 15)
	b = .t105_blocks(site, B_target = 4, exact_num_blocks = TRUE)
	expect_equal(length(unique(b)), 4L)
	b2 = .t105_blocks(site, B_target = 2, exact_num_blocks = TRUE)
	expect_equal(length(unique(b2)), 2L)
})
