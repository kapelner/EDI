library(testthat)
library(EDI)

# InferenceBayesianBootstrap's context builder on a blocking design (within-block
# weights vs whole-block resampling), the row expansion of unit weights, the
# worker-loading hooks, the worker estimate's nonestimable guard, the abstract
# estimation hook and the supported-type accessors. Existing files cover the
# plain-design context, cache key, sample weights, jackknife and BCa.

blk_fixture <- function(n = 24L, seed = 1L) {
	set.seed(seed)
	des <- DesignFixedBlocking$new(strata_cols = "g", response_type = "continuous", n = n, seed = seed, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(g = factor(rep(c("a", "b", "c"), each = n / 3)), x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(w + rnorm(n))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, des = des, n = n)
}

test_that("blocking design, default unit: one unit per subject, weight groups are the blocks", {
	f <- blk_fixture()
	ctx <- f$priv$build_bayesian_bootstrap_context()
	blocks <- as.integer(f$des$get_block_ids())
	expect_equal(ctx$row_to_unit, seq_len(f$n))
	expect_equal(ctx$n_units, f$n)
	expect_equal(ctx$unit_group_id, match(blocks, unique(blocks)))
	expect_equal(as.integer(table(ctx$unit_group_id)), rep(8L, 3L))
})

test_that("blocking design, resample_blocks: one unit per block, all in a single weight group", {
	f <- blk_fixture()
	ctx <- f$priv$build_bayesian_bootstrap_context("resample_blocks")
	blocks <- as.integer(f$des$get_block_ids())
	expect_equal(ctx$row_to_unit, match(blocks, unique(blocks)))
	expect_equal(ctx$n_units, 3L)
	expect_equal(ctx$unit_group_id, rep(1L, 3L))
})

test_that("sample weights: within-block draws sum to block size; whole-block draws sum to the block count", {
	f <- blk_fixture()
	set.seed(9)
	sw <- f$priv$bayesian_bootstrap_sample_weights()
	expect_length(sw$subject_or_block_weights, f$n)
	expect_true(all(sw$subject_or_block_weights > 0))
	expect_equal(as.numeric(tapply(sw$subject_or_block_weights, sw$context$unit_group_id, sum)), rep(8, 3))
	sb <- f$priv$bayesian_bootstrap_sample_weights("resample_blocks")
	expect_length(sb$subject_or_block_weights, 3L)
	expect_equal(sum(sb$subject_or_block_weights), 3)
	# Reference: the same RNG stream, gamma draws normalised per group, in group order.
	set.seed(9)
	ref <- numeric(f$n)
	for (g in 1:3) { idx <- which(sw$context$unit_group_id == g); d <- rgamma(8, 1, 1); ref[idx] <- d / sum(d) * 8 }
	expect_equal(sw$subject_or_block_weights, ref)
})

test_that("unit weights expand to per-row weights through row_to_unit, with validation", {
	f <- blk_fixture()
	expect_error(f$priv$expand_subject_or_block_weights_to_row_weights(rep(1, 3)), "No Bayesian-bootstrap context")
	f$priv$current_bayesian_bootstrap_context <- f$priv$build_bayesian_bootstrap_context("resample_blocks")
	rw <- f$priv$expand_subject_or_block_weights_to_row_weights(c(0.5, 1, 1.5))
	expect_equal(rw, rep(c(0.5, 1, 1.5), each = 8))
	expect_error(f$priv$expand_subject_or_block_weights_to_row_weights(c(1, 1)))            # wrong length
	expect_error(f$priv$expand_subject_or_block_weights_to_row_weights(c(1, -1, 1)))        # negative
	expect_error(f$priv$expand_subject_or_block_weights_to_row_weights(c(1, NA, 1)))        # missing
	withr::local_options(edi.run_asserts = FALSE)
	expect_equal(f$priv$expand_subject_or_block_weights_to_row_weights(c(2, 2, 2)), rep(2, 24))   # unchecked when asserts are off
})

test_that("worker loading hooks copy weights and context onto the worker's private state", {
	f <- blk_fixture(); g <- blk_fixture(seed = 2L)
	draw <- list(subject_or_block_weights = c(1L, 2L, 3L), context = f$priv$build_bayesian_bootstrap_context("resample_blocks"))
	ws <- list(worker = g$inf)
	f$priv$load_bayesian_bootstrap_weights_into_worker(ws, draw)
	expect_identical(g$priv$current_bayesian_bootstrap_subject_or_block_weights, c(1, 2, 3))
	expect_type(g$priv$current_bayesian_bootstrap_subject_or_block_weights, "double")
	expect_identical(g$priv$current_bayesian_bootstrap_context, draw$context)
	h <- blk_fixture(seed = 3L)
	f$priv$load_bayesian_bootstrap_draw_into_worker(list(worker = h$inf), draw, extra_ignored = TRUE)
	expect_identical(h$priv$current_bayesian_bootstrap_context, draw$context)
	expect_equal(h$priv$current_bayesian_bootstrap_subject_or_block_weights, c(1, 2, 3))
})

test_that("worker estimate takes the first value of the weighted estimate, and reports NA when nonestimable", {
	f <- blk_fixture()
	fake <- function(est, nonest) {
		list(
			compute_estimate_with_bootstrap_weights = function(subject_or_block_weights, estimate_only) {
				expect_true(estimate_only); expect_equal(subject_or_block_weights, c(1, 2, 3)); est
			},
			is_nonestimable = function(what) { expect_equal(what, "estimate"); nonest }
		)
	}
	f$priv$current_bayesian_bootstrap_subject_or_block_weights <- c(1, 2, 3)
	# The hook reads the weights from the WORKER's private env, so use a real worker with weights installed.
	w <- blk_fixture(seed = 4L)
	w$priv$current_bayesian_bootstrap_subject_or_block_weights <- c(1, 2, 3)
	wk <- list(.__enclos_env__ = list(private = w$priv))
	wk <- c(fake(c(7, 8), FALSE), wk)
	expect_equal(f$priv$compute_bayesian_bootstrap_worker_estimate(list(worker = wk)), 7)
	wk2 <- c(fake(5, TRUE), list(.__enclos_env__ = list(private = w$priv)))
	expect_true(is.na(f$priv$compute_bayesian_bootstrap_worker_estimate(list(worker = wk2))))
})

test_that("the abstract weighted-estimation hook and the supported-type accessors", {
	f <- blk_fixture()
	expect_equal(f$inf$get_supported_bayesian_bootstrap_pval_types(), c("percentile", "symmetric", "wald", "studentized", "bootstrap-t", "bca"))
	expect_equal(f$inf$get_supported_bayesian_bootstrap_ci_types(), c("percentile", "basic", "wald", "studentized", "bootstrap-t", "bca"))
	expect_true(f$priv$supports_bayesian_bootstrap())
	# The base class's hook is abstract (the concrete class overrides it, so fetch the parent's).
	base <- get("InferenceBayesianBootstrap", envir = asNamespace("EDI"))
	hook <- base$public_methods$compute_estimate_with_bootstrap_weights
	env <- new.env(); env$self <- structure(list(), class = c("SomeConcrete", "R6"))
	environment(hook) <- env
	expect_error(hook(c(1, 1)), "SomeConcrete must implement weighted bootstrap estimation")
})
