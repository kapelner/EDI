library(testthat)
library(EDI)

# TODO-102 (release_v1_0_5, intentional default change): naming strata_cols while leaving B_target
# unset now means B_target = NULL (use ALL named strata). Before, the sqrt/divisor cap (1 at prime n)
# silently dropped them. strata_cols = NULL keeps the capped default.

make_x = function(n) data.frame(sex = factor(rep(c("F", "M"), length.out = n)), x = seq_len(n) / n)
new_des = function(n, ...) DesignFixedBlocking$new(n = n, response_type = "continuous", verbose = FALSE, ...)

test_that("named strata_cols + default B_target use the strata at prime n (equal_block_sizes = FALSE)", {
	for (n in c(61L, 67L, 71L, 97L)) {
		des = new_des(n, strata_cols = "sex", equal_block_sizes = FALSE)
		des$add_all_subjects_to_experiment(make_x(n))
		expect_no_warning(ids <- des$get_block_ids())
		expect_equal(length(unique(ids)), 2L)
	}
})

test_that("named strata_cols + default B_target at composite n with small divisor uses all strata", {
	n = 58L
	X = data.frame(g = factor(rep(c("a", "b", "c"), length.out = n)))
	des = new_des(n, strata_cols = "g", equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(X)
	expect_equal(length(unique(des$get_block_ids())), 3L)
})

test_that("default equal_block_sizes = TRUE errors clearly when named strata cannot be equal", {
	for (n in c(61L, 67L, 58L)) {
		X = if (n == 58L) data.frame(g = factor(rep(c("a", "b", "c"), length.out = n))) else make_x(n)
		des = new_des(n, strata_cols = names(X)[1])
		expect_error({des$add_all_subjects_to_experiment(X); des$get_block_ids()}, "equal_block_sizes = FALSE")
	}
	# even n with a balanced 2-level stratum works with the default
	des = new_des(60L, strata_cols = "sex")
	des$add_all_subjects_to_experiment(make_x(60L))
	expect_equal(length(unique(des$get_block_ids())), 2L)
})

test_that("explicit B_target is honored as before", {
	n = 67L
	des = new_des(n, strata_cols = "sex", B_target = 2L, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(make_x(n))
	expect_equal(length(unique(des$get_block_ids())), 2L)
	expect_error(new_des(n, strata_cols = "sex", B_target = 2L), "divisible")
})

test_that("strata_cols = NULL keeps the capped default (1 block at prime n)", {
	n = 67L
	des = new_des(n, equal_block_sizes = FALSE)
	des$add_all_subjects_to_experiment(make_x(n))
	expect_equal(length(unique(des$get_block_ids())), 1L)
})
