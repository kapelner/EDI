library(testthat)
library(EDI)

# v1.0.6-TODO-270 (owner decision 2026-11-20): on DesignSeqOneByOneSPBR and DesignSeqOneByOneRandomBlockSize the
# automatic jackknife unit is the permuted block only when every stratum holds at least
# EDI_JACKKNIFE_MIN_PERMUTED_BLOCKS_PER_STRATUM (5) permuted-block units; with fewer in any stratum it is one
# subject within its stratum ("observation_within_block", Wolter 2007, Sec. 4.5). With 3-4 blocks in the smallest
# stratum the permuted-block jackknife-Wald test was too liberal (InferenceCountPoisson, RandomBlockSize, prob_T 0.2,
# n 200, ~1: size 0.082 against 0.055 deleting single subjects). An explicit unit = "permuted_block" is unchanged.

# Stratum "a" gets n_a subjects and stratum "b" n_b, in random enrolment order.
two_strata_X <- function(n_a, n_b, seed) {
	set.seed(seed)
	s <- sample(c(rep("a", n_a), rep("b", n_b)))
	data.frame(s = factor(s, levels = c("a", "b")), x1 = rnorm(n_a + n_b))
}

run_seq_design <- function(des, X, response_type = "continuous") {
	n <- nrow(X)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	y <- if (response_type == "count") rpois(n, exp(0.5 + 0.3 * as.integer(X$s))) else rnorm(n) + as.integer(X$s)
	des$add_all_subject_responses(y)
	des
}

spbr_des <- function(n_a, n_b, seed = 1L, block_size = 4L, response_type = "continuous") {
	X <- two_strata_X(n_a, n_b, seed)
	run_seq_design(DesignSeqOneByOneSPBR$new(strata_cols = "s", block_size = block_size, n = nrow(X),
		response_type = response_type, verbose = FALSE), X, response_type)
}

rbs_des <- function(n_a, n_b, seed = 1L, block_sizes = 4L, strata = TRUE, response_type = "continuous") {
	X <- two_strata_X(n_a, n_b, seed)
	des <- if (strata) {
		DesignSeqOneByOneRandomBlockSize$new(strata_cols = "s", block_sizes = block_sizes, n = nrow(X),
			response_type = response_type, verbose = FALSE)
	} else {
		DesignSeqOneByOneRandomBlockSize$new(block_sizes = block_sizes, n = nrow(X), response_type = response_type, verbose = FALSE)
	}
	run_seq_design(des, X, response_type)
}

jk_inf <- function(des) {
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	inf
}

min_blocks_per_stratum <- function(inf) {
	lay <- inf$.__enclos_env__$private$jackknife_stratified_layout("permuted_block")
	min(tabulate(lay$strata))
}

test_that("the threshold is a named constant equal to 5", {
	expect_identical(EDI:::EDI_JACKKNIFE_MIN_PERMUTED_BLOCKS_PER_STRATUM, 5L)
})

test_that("SPBR: 5 full blocks in the smallest stratum keeps the permuted block", {
	inf <- jk_inf(spbr_des(20L, 28L))
	p <- inf$.__enclos_env__$private
	expect_identical(min_blocks_per_stratum(inf), 5L)
	expect_identical(p$resolve_jackknife_unit("auto"), "permuted_block")
	expect_length(inf$approximate_jackknife_distribution_beta_hat_T(), 12L)
	expect_identical(inf$compute_jackknife_std_error(), inf$compute_jackknife_std_error(unit = "permuted_block"))
})

test_that("SPBR: 4 blocks (one with a merged partial block) in a stratum switches to one subject within its stratum", {
	inf <- jk_inf(spbr_des(19L, 28L))
	p <- inf$.__enclos_env__$private
	expect_identical(min_blocks_per_stratum(inf), 4L)
	expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block")
	lay <- p$jackknife_stratified_layout("auto")
	expect_identical(lay, p$jackknife_stratified_layout("observation_within_block"))
	expect_length(lay$delete, 47L)
	expect_length(inf$approximate_jackknife_distribution_beta_hat_T(), 47L)
	se_auto <- inf$compute_jackknife_std_error()
	expect_identical(se_auto, inf$compute_jackknife_std_error(unit = "observation_within_block"))
	expect_identical(inf$compute_jackknife_wald_two_sided_pval(), inf$compute_jackknife_wald_two_sided_pval(unit = "observation_within_block"))
	# t reference df = sum_h (n_h - 1) with subjects as units: 18 + 27.
	expect_equal(p$compute_jackknife_summary("auto")$df, 45)
	# The explicit permuted-block unit is unchanged, and the summaries are cached under the resolved unit.
	expect_length(inf$approximate_jackknife_distribution_beta_hat_T(unit = "permuted_block"), 11L)
	se_pb <- inf$compute_jackknife_std_error(unit = "permuted_block")
	expect_false(isTRUE(all.equal(se_auto, se_pb)))
	expect_identical(p$jackknife_cache_key("auto"), "observation_within_block")
	expect_setequal(names(p$cached_values$jackknife_summary), c("observation_within_block", "permuted_block"))
})

test_that("SPBR: a stratum with only a partial block counts as one unit and also switches", {
	inf <- jk_inf(spbr_des(3L, 40L))
	expect_identical(min_blocks_per_stratum(inf), 1L)
	expect_identical(inf$.__enclos_env__$private$resolve_jackknife_unit("auto"), "observation_within_block")
})

test_that("RandomBlockSize: 5 recorded blocks in the smallest stratum keeps the permuted block; 4 switches", {
	at <- jk_inf(rbs_des(20L, 28L))
	expect_identical(min_blocks_per_stratum(at), 5L)
	expect_identical(at$.__enclos_env__$private$resolve_jackknife_unit("auto"), "permuted_block")
	expect_length(at$approximate_jackknife_distribution_beta_hat_T(), 12L)
	below <- jk_inf(rbs_des(19L, 28L))
	p <- below$.__enclos_env__$private
	expect_identical(min_blocks_per_stratum(below), 4L)
	expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block")
	expect_length(below$approximate_jackknife_distribution_beta_hat_T(), 47L)
	expect_identical(below$compute_jackknife_std_error(), below$compute_jackknife_std_error(unit = "observation_within_block"))
	expect_length(below$approximate_jackknife_distribution_beta_hat_T(unit = "permuted_block"), 11L)
})

test_that("RandomBlockSize with random block sizes: the switch follows the recorded block count", {
	seen <- character(0)
	for (seed in 1:6) for (n_a in c(14L, 40L)) {
		inf <- jk_inf(rbs_des(n_a, 40L, seed = seed, block_sizes = c(2L, 4L, 6L)))
		expected <- if (min_blocks_per_stratum(inf) < 5L) "observation_within_block" else "permuted_block"
		unit <- inf$.__enclos_env__$private$resolve_jackknife_unit("auto")
		expect_identical(unit, expected)
		seen <- c(seen, unit)
	}
	expect_setequal(unique(seen), c("observation_within_block", "permuted_block"))
})

test_that("RandomBlockSize without strata: one stratum, so the switch looks at the total block count", {
	many <- jk_inf(rbs_des(10L, 10L, strata = FALSE))
	expect_identical(many$.__enclos_env__$private$resolve_jackknife_unit("auto"), "permuted_block")
	expect_length(many$approximate_jackknife_distribution_beta_hat_T(), 5L)
	few <- jk_inf(rbs_des(8L, 8L, strata = FALSE))
	p <- few$.__enclos_env__$private
	expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block")
	expect_length(few$approximate_jackknife_distribution_beta_hat_T(), 16L)
	# get_block_ids() is unavailable without strata_cols, so the layout puts every subject in one stratum.
	expect_identical(unique(p$jackknife_replicate_strata("auto")), 1L)
	expect_true(is.finite(few$compute_jackknife_std_error()))
	expect_equal(p$compute_jackknife_summary("auto")$df, 15)
	# One stratum: the ordinary delete-1 formula.
	loo <- few$approximate_jackknife_distribution_beta_hat_T()
	expect_equal(few$compute_jackknife_std_error(), sqrt(15 / 16 * sum((loo - mean(loo))^2)), tolerance = 1e-12)
})

test_that("InferenceCountPoisson: the automatic unit already deletes subjects, so its block fallback does not fire", {
	des <- rbs_des(19L, 28L, response_type = "count")
	inf <- InferenceCountPoisson$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	p <- inf$.__enclos_env__$private
	expect_identical(p$resolve_jackknife_unit("auto"), "observation_within_block")
	expect_false(p$use_within_block_jackknife_fallback())
	pj <- suppressWarnings(inf$compute_jackknife_wald_two_sided_pval(unit = "observation_within_block"))
	expect_true(is.finite(pj))
	expect_identical(p$design_jackknife_pval(), pj)
})
