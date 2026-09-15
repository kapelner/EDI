library(testthat)
library(EDI)

private_env = function(x) x$.__enclos_env__$private

test_that("Efron assignment takes balanced and both imbalanced branches", {
	des = DesignSeqOneByOneEfron$new(
		response_type = "continuous", n = 6L, prob_T = 0.5,
		weighted_coin_prob = 1, seed = 101
	)
	p = private_env(des)

	p$prob_T = 1
	p$w = c(1, 0, NA, NA, NA, NA)
	expect_identical(des$assign_wt(), 1L)
	p$w = c(1, 1, 0, NA, NA, NA)
	expect_identical(des$assign_wt(), 0L)
	p$w = c(1, 0, 0, NA, NA, NA)
	expect_identical(des$assign_wt(), 1L)
})

test_that("Wei urn assignment responds deterministically at zero-alpha extremes", {
	des = DesignSeqOneByOneUrn$new(
		alpha = 0, beta = 1, response_type = "continuous", n = 4L, seed = 102
	)
	p = private_env(des)
	p$w = c(1, NA, NA, NA)
	expect_identical(des$assign_wt(), 0L)
	p$w = c(0, NA, NA, NA)
	expect_identical(des$assign_wt(), 1L)

	expect_error(
		DesignSeqOneByOneUrn$new(alpha = -1, beta = 1, response_type = "continuous", n = 4L),
		"alpha"
	)
	expect_error(
		DesignSeqOneByOneUrn$new(alpha = 1, beta = -1, response_type = "continuous", n = 4L),
		"beta"
	)
})

test_that("Atkinson early assignment uses the configured fallback coin", {
	des = DesignSeqOneByOneAtkinson$new(
		response_type = "continuous", n = 5L, prob_T = 0.5, seed = 103
	)
	p = private_env(des)
	p$prob_T = 1
	p$t = 1L
	p$Xraw = matrix(0, nrow = 1L, ncol = 2L)
	expect_identical(des$assign_wt(), 1L)
})

test_that("random-block design refills and consumes balanced blocks", {
	des = DesignSeqOneByOneRandomBlockSize$new(
		block_sizes = c(2L, 2L), response_type = "continuous", n = 4L, seed = 104
	)
	draw = c(des$assign_wt(), des$assign_wt())
	expect_equal(sort(draw), c(0, 1))
	expect_length(private_env(des)$strata_states$overall, 0L)

	expect_error(
		DesignSeqOneByOneRandomBlockSize$new(
			block_sizes = 3L, prob_T = 0.5, response_type = "continuous", n = 4L
		),
		"integer number of treatment assignments"
	)
	expect_error(
		DesignSeqOneByOneRandomBlockSize$new(
			block_sizes = numeric(), response_type = "continuous", n = 4L
		),
		"block_sizes"
	)
})

test_that("Pocock-Simon metadata includes missing and newly observed levels", {
	des = DesignSeqOneByOnePocockSimon$new(
		strata_cols = c("site", "sex"), weights = c(2, 1), p_best = 1,
		response_type = "continuous", n = 4L, seed = 105
	)
	p = private_env(des)
	p$Xraw = data.frame(
		site = c("A", "B", NA, "C"),
		sex = c("F", "M", "F", "F"),
		stringsAsFactors = FALSE
	)
	p$ensure_factor_metadata()
	expect_identical(p$num_levels_total, 6L)
	expect_setequal(names(p$strata_level_rows$site), c("A", "B", "NA", "C"))
	expect_setequal(names(p$strata_level_rows$sex), c("F", "M"))

	p$counts = matrix(1, nrow = 1L, ncol = 2L)
	p$ensure_factor_metadata()
	expect_identical(dim(p$counts), c(6L, 2L))
	expect_equal(p$counts[1, ], c(1, 1))
	expect_true(all(p$counts[-1, ] == 0))

	expect_error(
		DesignSeqOneByOnePocockSimon$new(
			strata_cols = character(), response_type = "continuous", n = 4L
		),
		"strata_cols"
	)
	expect_error(
		DesignSeqOneByOnePocockSimon$new(
			strata_cols = "site", weights = c(1, 2), response_type = "continuous", n = 4L
		),
		"weights"
	)
	expect_error(
		DesignSeqOneByOnePocockSimon$new(
			strata_cols = "site", p_best = 0.4, response_type = "continuous", n = 4L
		),
		"p_best"
	)
})

test_that("rerandomization validates modes and computes both objectives", {
	expect_error(
		DesignFixedRerandomization$new(
			response_type = "continuous", n = 4L,
			obj_val_cutoff = 1, prop_acceptable = 0.5
		),
		"Cannot specify both"
	)

	X = matrix(c(0, 0, 2, 4, 1, 3, 1, 3), nrow = 4L)
	w = c(0, 0, 1, 1)
	des = DesignFixedRerandomization$new(response_type = "continuous", n = 4L)
	p = private_env(des)
	p$S_inv = diag(2)
	expect_equal(p$compute_obj(X, w), sum((colMeans(X[w == 1, ]) - colMeans(X[w == 0, ]))^2))
	p$objective = "abs_sum_diff"
	expect_equal(p$compute_obj(X, w), sum(abs(colMeans(X[w == 1, ]) - colMeans(X[w == 0, ]))))
	p$objective = "unsupported"
	expect_error(p$compute_obj(X, w), "Unsupported objective")
})
