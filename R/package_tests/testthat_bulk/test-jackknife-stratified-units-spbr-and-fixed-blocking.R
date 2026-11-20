library(testthat)
library(EDI)

# v1.0.6-TODO-4: the jackknife on DesignSeqOneByOneSPBR and DesignFixedBlocking used to delete whole
# strata (get_block_ids() returns stratum ids), leaving 2-4 replicates. The automatic units are now
# "permuted_block" (SPBR: the design's permuted blocks, a trailing partial block merged into the
# previous block of its stratum) and "observation_within_block" (FixedBlocking: one subject at a time),
# both with the stratified delete-1 jackknife of Wolter (2007, Sec. 4.5) applied to the reweighting-
# equivalent replicates theta* = theta_hat + r_h (theta_(h,i) - theta_hat), r_h = n_h (N - 1) / (N (n_h - 1)):
#   v = sum_h (n_h - 1) / n_h * sum_i (theta*_(h,i) - theta*_bar_h)^2, bias = sum_h (n_h - 1) (theta*_bar_h - theta_hat).

stratified_hand <- function(loo, strata, theta_hat) {
	N <- length(loo); v <- 0; b <- 0
	for (h in unique(strata)) {
		th <- loo[strata == h]; n_h <- length(th)
		if (n_h < 2L) next
		th <- theta_hat + n_h * (N - 1) / (N * (n_h - 1)) * (th - theta_hat)
		v <- v + (n_h - 1) / n_h * sum((th - mean(th))^2)
		b <- b + (n_h - 1) * (mean(th) - theta_hat)
	}
	list(se = sqrt(v), bias = b)
}

mean_diff <- function(y, w) mean(y[w == 1]) - mean(y[w == 0])

fixed_blocking_fixture <- function(sizes = c(4L, 4L, 4L), seed = 3L) {
	set.seed(seed)
	n <- sum(sizes)
	X <- data.frame(s = factor(rep(letters[seq_along(sizes)], sizes)), x1 = rnorm(n))
	des <- DesignFixedBlocking$new(strata_cols = "s", n = n, response_type = "continuous", equal_block_sizes = FALSE, verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n) + as.integer(X$s))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(des = des, inf = inf, p = inf$.__enclos_env__$private, y = des$get_y(), w = des$get_w(), blk = des$get_block_ids())
}

spbr_fixture <- function(n = 23L, seed = 5L, block_size = 4L) {
	set.seed(seed)
	X <- data.frame(s = factor(sample(c("a", "b"), n, TRUE), levels = c("a", "b")), x1 = rnorm(n))
	des <- DesignSeqOneByOneSPBR$new(strata_cols = "s", block_size = block_size, n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + as.integer(X$s))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(des = des, inf = inf, p = inf$.__enclos_env__$private, X = X, y = des$get_y(), w = des$get_w())
}

test_that("FixedBlocking: the automatic jackknife deletes one subject and pools within strata (hand JKn)", {
	f <- fixed_blocking_fixture()
	expect_identical(f$p$resolve_jackknife_unit("auto"), "observation_within_block")
	theta_hat <- mean_diff(f$y, f$w)
	loo <- vapply(seq_along(f$y), function(i) mean_diff(f$y[-i], f$w[-i]), numeric(1))
	expect_equal(f$inf$approximate_jackknife_distribution_beta_hat_T(), loo, tolerance = 1e-12)
	hand <- stratified_hand(loo, f$blk, theta_hat)
	expect_equal(f$inf$compute_jackknife_std_error(), hand$se, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_bias_estimate(), hand$bias, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_estimate(), theta_hat - hand$bias, tolerance = 1e-12)
	# v1.0.6-TODO-231: t reference with df = sum_h (n_h - 1) = 3 * 3 on the stratified units.
	df <- sum(table(f$blk) - 1)
	expect_equal(df, 9)
	z <- qt(0.975, df)
	expect_equal(unname(f$inf$compute_jackknife_wald_confidence_interval()),
		theta_hat - hand$bias + c(-1, 1) * z * hand$se, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_wald_two_sided_pval(),
		2 * pt(-abs((theta_hat - hand$bias) / hand$se), df), tolerance = 1e-12)
	# Closed forms: v = ((N-1)/N)^2 sum_h n_h/(n_h-1) sum_i (theta_(h,i) - theta_bar_h)^2 and, with no
	# singleton stratum, bias = (N - 1)(theta_bar - theta_hat).
	N <- length(loo)
	v_closed <- sum(vapply(unique(f$blk), function(h) { th <- loo[f$blk == h]; n_h <- length(th)
		((N - 1) / N)^2 * n_h / (n_h - 1) * sum((th - mean(th))^2) }, numeric(1)))
	expect_equal(f$inf$compute_jackknife_std_error(), sqrt(v_closed), tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_bias_estimate(), (N - 1) * (mean(loo) - theta_hat), tolerance = 1e-12)
	# Not the unstratified delete-1 formula (which also counts the between-stratum spread).
	G <- length(loo)
	expect_false(isTRUE(all.equal(f$inf$compute_jackknife_std_error(), sqrt((G - 1) / G * sum((loo - mean(loo))^2)))))
})

test_that("FixedBlocking: an explicit unit = \"block\" still deletes whole strata", {
	f <- fixed_blocking_fixture()
	expect_length(f$inf$approximate_jackknife_distribution_beta_hat_T(unit = "block"), 3L)
	# 3 strata: below EDI_JACKKNIFE_MIN_DELETION_UNITS, so NA with a warning.
	expect_warning(se <- f$inf$compute_jackknife_std_error(unit = "block"), class = "edi_procedure_na_warning")
	expect_true(is.na(se))
})

test_that("FixedBlocking: a one-subject stratum contributes nothing to the stratified jackknife", {
	# Singleton strata are Bernoulli-randomized; pick a seed whose singleton is treated and whose other
	# strata leave both arms after any one deletion.
	f <- fixed_blocking_fixture(sizes = c(6L, 6L, 1L), seed = 11L)
	expect_equal(sum(f$blk == f$blk[13L]), 1L)
	theta_hat <- mean_diff(f$y, f$w)
	loo <- vapply(seq_along(f$y), function(i) mean_diff(f$y[-i], f$w[-i]), numeric(1))
	hand <- stratified_hand(loo, f$blk, theta_hat)
	expect_equal(f$inf$compute_jackknife_std_error(), hand$se, tolerance = 1e-12)
	strata <- f$p$jackknife_replicate_strata("auto")
	m <- EDI:::edi_jackknife_bias_variance(loo, theta_hat, strata)
	# The singleton's replicate value never enters (it still counts in N, the number of units).
	loo2 <- loo; loo2[13L] <- loo2[13L] + 100
	expect_identical(EDI:::edi_jackknife_bias_variance(loo2, theta_hat, strata), m)
	# Effective units: sum_h (n_h - 1) + 1 = 5 + 5 + 0 + 1.
	expect_identical(EDI:::edi_jackknife_effective_units(13L, strata), 11L)
})

test_that("FixedBlocking: too few within-stratum degrees of freedom gives NA with the stratified message", {
	f <- fixed_blocking_fixture(sizes = c(2L, 2L, 2L), seed = 4L)
	expect_identical(EDI:::edi_jackknife_effective_units(6L, f$p$jackknife_replicate_strata("auto")), 4L)
	expect_warning(se <- f$inf$compute_jackknife_std_error(), "degrees of freedom within strata", class = "edi_procedure_na_warning")
	expect_true(is.na(se))
})

test_that("SPBR: the deletion units are the permuted blocks; a trailing partial block is merged", {
	f <- spbr_fixture()
	# v1.0.6-TODO-270: 2-3 blocks per stratum here, so "auto" deletes single subjects; the permuted-block
	# layout itself is checked through the explicit unit.
	expect_identical(f$p$resolve_jackknife_unit("auto"), "observation_within_block")
	lay <- f$p$jackknife_stratified_layout("permuted_block")
	keys <- as.character(f$X$s)
	strata_order <- unique(keys)
	expected <- list(); expected_strata <- integer(0)
	for (h in seq_along(strata_order)) {
		idx <- which(keys == strata_order[h])
		n_full <- length(idx) %/% 4L
		blk <- (seq_along(idx) - 1L) %/% 4L + 1L
		if (length(idx) %% 4L != 0L && n_full >= 1L) blk[blk > n_full] <- n_full
		for (b in sort(unique(blk))) expected[[length(expected) + 1L]] <- idx[blk == b]
		expected_strata <- c(expected_strata, rep(h, length(unique(blk))))
	}
	expect_identical(lay$delete, expected)
	expect_identical(lay$strata, expected_strata)
	# Every unit is one design block: full blocks have 2 treated of 4; the merged one 4 + partial.
	sizes <- lengths(lay$delete)
	expect_true(all(sizes >= 4L & sizes <= 7L))
	expect_true(all(vapply(lay$delete[sizes == 4L], function(d) sum(f$w[d]), numeric(1)) == 2))
	expect_identical(sort(unlist(lay$delete)), seq_len(23L))
})

test_that("SPBR: a stratum with only a partial block is one unit", {
	set.seed(8)
	n <- 15L
	X <- data.frame(s = factor(c(rep("a", 12L), rep("b", 3L))[sample(n)], levels = c("a", "b")))
	des <- DesignSeqOneByOneSPBR$new(strata_cols = "s", block_size = 4L, n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n))
	p <- InferenceAllSimpleAverageDiff$new(des)$.__enclos_env__$private
	lay <- p$jackknife_stratified_layout("permuted_block")
	b_units <- lay$delete[lay$strata == match("b", unique(as.character(X$s)))]
	expect_length(b_units, 1L)
	expect_identical(b_units[[1L]], which(X$s == "b"))
	expect_length(lay$delete, 4L)
})

test_that("SPBR: jackknife SE and bias are the stratified JKn of the block-deleted replicates", {
	# v1.0.6-TODO-270: n large enough for >= 10 blocks in each stratum, so "auto" is the permuted block.
	f <- spbr_fixture(n = 120L, seed = 9L)
	expect_identical(f$p$resolve_jackknife_unit("auto"), "permuted_block")
	lay <- f$p$jackknife_stratified_layout("auto")
	theta_hat <- mean_diff(f$y, f$w)
	loo <- vapply(lay$delete, function(d) mean_diff(f$y[-d], f$w[-d]), numeric(1))
	expect_equal(f$inf$approximate_jackknife_distribution_beta_hat_T(), loo, tolerance = 1e-12)
	hand <- stratified_hand(loo, lay$strata, theta_hat)
	expect_equal(f$inf$compute_jackknife_std_error(), hand$se, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_estimate(), theta_hat - hand$bias, tolerance = 1e-12)
})

test_that("unit = \"permuted_block\" needs SPBR; \"observation_within_block\" needs a blocking design", {
	f <- fixed_blocking_fixture()
	expect_error(f$inf$compute_jackknife_std_error(unit = "permuted_block"), "DesignSeqOneByOneSPBR")
	set.seed(1)
	des <- DesignFixedBernoulli$new(n = 20L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(20L))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(20L))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	expect_error(inf$compute_jackknife_std_error(unit = "observation_within_block"), "requires a blocking design")
})

test_that("unstratified units keep the ordinary jackknife formula bit for bit", {
	set.seed(2)
	jack <- rnorm(17L); theta_hat <- 0.3
	G <- length(jack); jack_bar <- mean(jack)
	m <- EDI:::edi_jackknife_bias_variance(jack, theta_hat, NULL)
	expect_identical(m$bias, (G - 1) * (jack_bar - theta_hat))
	expect_identical(m$variance, ((G - 1) / G) * sum((jack - jack_bar)^2))
	expect_identical(EDI:::edi_jackknife_effective_units(17L, NULL), 17L)
	des <- DesignFixedBernoulli$new(n = 30L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(30L))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(30L))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	p <- inf$.__enclos_env__$private
	expect_null(p$jackknife_replicate_strata("auto"))
	loo <- inf$approximate_jackknife_distribution_beta_hat_T()
	G <- length(loo)
	expect_identical(inf$compute_jackknife_std_error(), sqrt(((G - 1) / G) * sum((loo - mean(loo))^2)))
})

test_that("with a single stratum the stratified formulas reduce to the ordinary jackknife", {
	set.seed(4)
	jack <- rnorm(12L); theta_hat <- 0.1
	m1 <- EDI:::edi_jackknife_bias_variance(jack, theta_hat, rep(1L, 12L))
	m0 <- EDI:::edi_jackknife_bias_variance(jack, theta_hat, NULL)
	expect_equal(m1, m0, tolerance = 1e-12)
})

# v1.0.6-TODO-231 (3): DesignSeqOneByOneRandomBlockSize draws each block's size at random, so its blocks
# cannot be rebuilt from the enrolment order; assign_wt() records the block of every subject (and each
# block's stratum and drawn size), and the jackknife deletes one recorded block at a time, with SPBR's
# rule for a stratum's trailing unfilled block (merged into that stratum's previous block).
rbs_fixture <- function(n = 50L, seed = 6L, strata = TRUE) {
	set.seed(seed)
	X <- data.frame(s = factor(sample(c("a", "b"), n, TRUE), levels = c("a", "b")), x1 = rnorm(n))
	des <- if (strata) {
		DesignSeqOneByOneRandomBlockSize$new(strata_cols = "s", block_sizes = c(2L, 4L, 6L), n = n, response_type = "continuous", verbose = FALSE)
	} else {
		DesignSeqOneByOneRandomBlockSize$new(block_sizes = c(2L, 4L, 6L), n = n, response_type = "continuous", verbose = FALSE)
	}
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + as.integer(X$s))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(des = des, dp = des$.__enclos_env__$private, inf = inf, p = inf$.__enclos_env__$private, X = X,
		y = des$get_y(), w = des$get_w())
}

test_that("RandomBlockSize: assign_wt() records balanced permuted blocks within strata", {
	f <- rbs_fixture()
	ids <- f$dp$permuted_block_ids
	expect_length(ids, 50L)
	expect_false(anyNA(ids))
	keys <- f$dp$permuted_block_keys
	sizes <- f$dp$permuted_block_sizes
	expect_true(all(sizes %in% c(2L, 4L, 6L)))
	# Every block holds one stratum; a complete block is balanced, and only a stratum's last block can be
	# incomplete.
	for (b in unique(ids)) {
		idx <- which(ids == b)
		expect_length(unique(as.character(f$X$s[idx])), 1L)
		if (length(idx) == sizes[b]) expect_equal(sum(f$w[idx]), sizes[b] / 2)
		else expect_identical(b, max(which(keys == keys[b])))
	}
	expect_identical(f$des$duplicate()$.__enclos_env__$private$permuted_block_ids, ids)
})

test_that("RandomBlockSize: the jackknife deletes one recorded block, merging a trailing unfilled block", {
	# v1.0.6-TODO-270: n large enough for >= 10 blocks in each stratum, so "auto" is the permuted block.
	f <- rbs_fixture(n = 120L)
	expect_identical(f$p$resolve_jackknife_unit("auto"), "permuted_block")
	ids <- f$dp$permuted_block_ids
	keys <- f$dp$permuted_block_keys
	sizes <- f$dp$permuted_block_sizes
	expected <- list(); expected_strata <- integer(0)
	strata_order <- unique(keys[sort(unique(ids))])
	for (h in seq_along(strata_order)) {
		b_h <- sort(unique(ids[keys[ids] == strata_order[h]]))
		groups <- as.list(b_h)
		last <- b_h[length(b_h)]
		if (length(b_h) > 1L && sum(ids == last) < sizes[last]) {
			groups[[length(groups) - 1L]] <- c(groups[[length(groups) - 1L]], last)
			groups[[length(groups)]] <- NULL
		}
		for (g in groups) expected[[length(expected) + 1L]] <- which(ids %in% g)
		expected_strata <- c(expected_strata, rep(h, length(groups)))
	}
	lay <- f$p$jackknife_stratified_layout("auto")
	expect_identical(lay$delete, expected)
	expect_identical(lay$strata, expected_strata)
	theta_hat <- mean_diff(f$y, f$w)
	loo <- vapply(lay$delete, function(d) mean_diff(f$y[-d], f$w[-d]), numeric(1))
	expect_equal(f$inf$approximate_jackknife_distribution_beta_hat_T(), loo, tolerance = 1e-12)
	hand <- stratified_hand(loo, lay$strata, theta_hat)
	expect_equal(f$inf$compute_jackknife_std_error(), hand$se, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_estimate(), theta_hat - hand$bias, tolerance = 1e-12)
	# Explicit "block" still deletes whole strata.
	expect_length(f$inf$approximate_jackknife_distribution_beta_hat_T(unit = "block"), 2L)
})

test_that("RandomBlockSize without strata: the recorded blocks form one stratum (ordinary delete-a-block jackknife)", {
	f <- rbs_fixture(strata = FALSE)
	expect_identical(f$p$resolve_jackknife_unit("auto"), "permuted_block")
	lay <- f$p$jackknife_stratified_layout("auto")
	expect_identical(unique(lay$strata), 1L)
	loo <- f$inf$approximate_jackknife_distribution_beta_hat_T()
	G <- length(loo)
	expect_equal(f$inf$compute_jackknife_std_error(), sqrt((G - 1) / G * sum((loo - mean(loo))^2)), tolerance = 1e-12)
})

test_that("RandomBlockSize without a block record (an object saved before 1.0.6) keeps the whole-stratum unit", {
	f <- rbs_fixture()
	f$dp$permuted_block_ids <- integer(0)
	inf <- InferenceAllSimpleAverageDiff$new(f$des)
	expect_identical(inf$.__enclos_env__$private$resolve_jackknife_unit("auto"), "block")
	expect_null(inf$.__enclos_env__$private$jackknife_stratified_layout("permuted_block"))
})

# v1.0.6-TODO-231 (4): the BCa acceleration on the stratified units is the skewness of the empirical
# influence values centred within strata (Davison & Hinkley 1997, stratified case):
# a = sum_h c_h^3 sum_i d^3 / (6 (sum_h c_h^2 sum_i d^2)^(3/2)), d = r_h (theta_bar_h - theta_(h,i)),
# c_h = (n_h - 1)/n_h.
test_that("stratified BCa acceleration: hand formula, single-stratum reduction, invariance to stratum shifts", {
	set.seed(7)
	jack <- c(rnorm(6L), rexp(9L), rnorm(1L))
	strata <- c(rep(1L, 6L), rep(2L, 9L), 3L)
	N <- length(jack)
	num <- 0; ss <- 0
	for (h in 1:2) {
		th <- jack[strata == h]; n_h <- length(th)
		d <- n_h * (N - 1) / (N * (n_h - 1)) * (mean(th) - th)
		num <- num + ((n_h - 1) / n_h)^3 * sum(d^3); ss <- ss + ((n_h - 1) / n_h)^2 * sum(d^2)
	}
	expect_equal(EDI:::edi_jackknife_acceleration(jack, strata), num / (6 * ss^1.5), tolerance = 1e-12)
	# Shifting a whole stratum's replicates (a between-stratum difference) does not change it.
	jack2 <- jack + c(rep(5, 6L), rep(-3, 9L), 100)
	expect_equal(EDI:::edi_jackknife_acceleration(jack2, strata), EDI:::edi_jackknife_acceleration(jack, strata), tolerance = 1e-12)
	# One stratum: Efron's formula; NULL strata: the old expression bit for bit.
	jb <- mean(jack)
	old <- sum((jb - jack)^3) / (6 * (sum((jb - jack)^2)^(3/2)))
	expect_identical(EDI:::edi_jackknife_acceleration(jack, NULL), old)
	expect_equal(EDI:::edi_jackknife_acceleration(jack, rep(1L, N)), old, tolerance = 1e-12)
	expect_identical(EDI:::edi_jackknife_acceleration(rep(1, 5L), NULL), 0)
})

test_that("FixedBlocking BCa interval uses the stratified acceleration", {
	f <- fixed_blocking_fixture(sizes = c(8L, 10L, 12L), seed = 12L)
	p <- f$p
	jack <- p$approximate_jackknife_distribution_beta_hat_T_private("auto")
	strata <- p$jackknife_replicate_strata("auto")
	expect_length(strata, length(jack))
	boot <- sort(rnorm(999L, mean_diff(f$y, f$w), 0.4))
	est <- mean_diff(f$y, f$w)
	fail <- function(reason) c(NA_real_, NA_real_)
	expect_identical(p$ci_bca(boot, 0.05, est),
		p$bca_ci_core(boot, 0.05, est, jack, reason_prefix = "bootstrap_bca_", on_failure = fail, strata = strata))
})

# v1.0.6-TODO-231 (6), owner decision 2026-11-20: the stratified units use t with sum_h (n_h - 1) df;
# unstratified units keep the normal reference bit for bit.
test_that("SPBR jackknife-Wald test and interval use t with sum_h (n_h - 1) degrees of freedom", {
	f <- spbr_fixture(n = 120L, seed = 9L)
	expect_identical(f$p$resolve_jackknife_unit("auto"), "permuted_block")
	lay <- f$p$jackknife_stratified_layout("auto")
	df <- sum(table(lay$strata) - 1)
	est <- f$inf$compute_jackknife_estimate(); se <- f$inf$compute_jackknife_std_error()
	expect_equal(unname(f$inf$compute_jackknife_wald_confidence_interval(alpha = 0.1)),
		est + c(-1, 1) * qt(0.95, df) * se, tolerance = 1e-12)
	expect_equal(f$inf$compute_jackknife_wald_two_sided_pval(delta = 0.2), 2 * pt(-abs((est - 0.2) / se), df), tolerance = 1e-12)
	expect_equal(f$p$compute_jackknife_summary("auto")$df, df)
})

test_that("unstratified jackknife-Wald keeps the normal reference exactly", {
	set.seed(3)
	des <- DesignFixedBernoulli$new(n = 30L, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(30L))); des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(30L))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	est <- inf$compute_jackknife_estimate(); se <- inf$compute_jackknife_std_error()
	expect_identical(inf$.__enclos_env__$private$compute_jackknife_summary("auto")$df, Inf)
	z <- stats::qnorm(1 - 0.05 / 2)
	expect_identical(unname(inf$compute_jackknife_wald_confidence_interval()), c(est - z * se, est + z * se))
	expect_identical(inf$compute_jackknife_wald_two_sided_pval(), 2 * stats::pnorm(-abs(est / se)))
	# Explicit "block" on a blocking design (unstratified delete-a-group) also stays normal.
	f <- fixed_blocking_fixture(sizes = c(4L, 4L, 4L, 4L, 4L, 4L))
	expect_identical(f$p$compute_jackknife_summary("block")$df, Inf)
})

# v1.0.6-TODO-231 (5), owner decision 2026-11-20.
obs_blocks_fixture <- function(n_blocks, per = 12L, seed = 2L) {
	set.seed(seed)
	n <- n_blocks * per
	des <- ObservationalDesignBlocks$new(response_type = "continuous", m = rep(seq_len(n_blocks), each = per))
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects(w_precomputed = rep(c(1, 0), n / 2))
	des$add_all_subject_responses(rnorm(n) + rep(seq_len(n_blocks), each = per))
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(des = des, inf = inf, p = inf$.__enclos_env__$private)
}

test_that("ObservationalDesignBlocks: fewer than 5 blocks -> one subject within its block; 5 or more -> the block", {
	few <- obs_blocks_fixture(3L)
	expect_identical(few$p$resolve_jackknife_unit("auto"), "observation_within_block")
	expect_length(few$inf$approximate_jackknife_distribution_beta_hat_T(), 36L)
	expect_true(is.finite(few$inf$compute_jackknife_wald_two_sided_pval()))
	expect_equal(few$p$compute_jackknife_summary("auto")$df, 33)
	# Explicit units still work.
	expect_length(few$inf$approximate_jackknife_distribution_beta_hat_T(unit = "block"), 3L)
	many <- obs_blocks_fixture(6L, per = 4L)
	expect_identical(many$p$resolve_jackknife_unit("auto"), "block")
	expect_length(many$inf$approximate_jackknife_distribution_beta_hat_T(), 6L)
	expect_length(many$inf$approximate_jackknife_distribution_beta_hat_T(unit = "observation_within_block"), 24L)
})
