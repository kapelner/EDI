library(testthat)
library(EDI)

# Regression test (2026-10-23, release_v1_0_5.md TODO-18 calibration cell C1).
# The bootstrap-randomization test (BRT) installs the resampled pair ids `m_vec_b`
# as private$m on a duplicated design, but DesignFixedBinaryMatch (and
# DesignFixedMatchingGreedyPairSwitching) drew the fresh assignment from the
# duplicated private$bms, i.e. the ORIGINAL sample's row pairs. Resampled pairs
# then got 0 or 2 treated subjects, the KK pair differences went NA, and
# InferenceContinKKRobustRegrOneLik's robust kernel returned beta = 0 on every draw:
# the null distribution was identically 0 and p = 2/(B+1) always (~1 and ~.).
# InferenceContinKKOLSOneLik's null was all NA; the quantile sibling's was distorted.

brt_fixture_design = function(design_name, n = 40L, seed = 1L) {
	set.seed(seed)
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
	gen = get(design_name, envir = asNamespace("EDI"))
	des = gen$new(response_type = "continuous", n = n)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x1 + stats::rnorm(n))
	des
}

pairs_without_one_treated = function(draw) {
	sum(tapply(draw$w_b, draw$m_vec_b, sum) != 1)
}

test_that("FixedBinaryMatch BRT replay randomizes within the resampled pairs", {
	des = brt_fixture_design("DesignFixedBinaryMatch")
	for (cls in c("InferenceAllSimpleAverageDiff", "InferenceContinKKRobustRegrOneLik")) {
		inf = get(cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
		set.seed(3)
		draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(15L, materialize_w = TRUE)
		expect_false(is.null(draws[[1L]]$m_vec_b))
		expect_identical(vapply(draws, pairs_without_one_treated, numeric(1L)), rep(0, 15L), info = cls)
	}
})

test_that("GreedyPairSwitching BRT replay randomizes within the resampled pairs", {
	des = brt_fixture_design("DesignFixedMatchingGreedyPairSwitching")
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(3)
	draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(15L, materialize_w = TRUE)
	expect_false(is.null(draws[[1L]]$m_vec_b))
	expect_identical(vapply(draws, pairs_without_one_treated, numeric(1L)), rep(0, 15L))
})

test_that("DesignFixedBinaryMatch rebuilds a stale pairing from private$m before drawing", {
	des = brt_fixture_design("DesignFixedBinaryMatch", n = 12L)
	dup = des$duplicate(verbose = FALSE)
	dp = dup$.__enclos_env__$private
	m_new = rep(1:6, times = 2L)  # pairs (i, i + 6), unrelated to the matched pairing
	dp$m = m_new
	w = dup$draw_ws_according_to_design(5L)
	for (r in seq_len(ncol(w))) expect_true(all(tapply(w[, r], m_new, sum) == 1))
})

test_that("KK robust one-lik BRT null distribution is non-degenerate on FixedBinaryMatch", {
	B = 41L
	pvals = numeric(0)
	for (seed in 1:3) {
		des = brt_fixture_design("DesignFixedBinaryMatch", seed = seed)
		for (f in list(~ 1, ~ .)) {
			inf = InferenceContinKKRobustRegrOneLik$new(des, model_formula = f, verbose = FALSE)
			set.seed(seed + 100L)
			t0 = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = B, delta = 0, show_progress = FALSE)
			expect_gt(sum(is.finite(t0)), B / 2)
			expect_lt(sum(t0 == 0, na.rm = TRUE), 3L)
			expect_gt(stats::sd(t0, na.rm = TRUE), 0)
			set.seed(seed + 100L)
			pvals = c(pvals, inf$compute_rand_bootstrap_two_sided_pval(B = B, type = "percentile", show_progress = FALSE))
		}
	}
	expect_true(all(is.finite(pvals)))
	expect_false(all(abs(pvals - 2 / (B + 1)) < 1e-12))
	expect_gt(max(pvals), 0.1)
})

test_that("KK robust one-lik fit_rlm treats non-finite rows as nonestimable, not beta = 0", {
	des = brt_fixture_design("DesignFixedBinaryMatch", n = 20L)
	inf = InferenceContinKKRobustRegrOneLik$new(des, verbose = FALSE)
	priv = inf$.__enclos_env__$private
	X = matrix(1, nrow = 10L, ncol = 1L)
	y = c(stats::rnorm(9L), NA_real_)
	expect_null(priv$fit_rlm(X, y, 1L, estimate_only = TRUE))
	expect_false(is.null(priv$fit_rlm(X, stats::rnorm(10L), 1L, estimate_only = TRUE)))
})

# ---------------------------------------------------------------------------
# Parametric extension (2026-10-23, release_v1_0_5.md TODO-131): every design
# whose draw_ws_raw() reads cached structure must redraw within the RESAMPLED
# structure on a BRT replay. Each resampled unit keeps the block / cluster id it
# carried (private$m / the cluster column, subset by i_b), except
# DesignFixedOptimalBlocks, whose blocking is re-solved on the resampled
# covariates (G6 #51, owner 2026-10-23). Before the fix DesignFixedOptimalBlocks
# balanced within its cached ORIGINAL-row block_ids (2-5 of 5 blocks unbalanced
# per draw).

replay_fixture = function(design_name, args, n = 40L, seed = 1L) {
	set.seed(seed)
	X = data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n),
		site = rep(c("a", "b"), each = n / 2L),
		cl = rep(seq_len(n / 4L), each = 4L))
	gen = get(design_name, envir = asNamespace("EDI"))
	des = do.call(gen$new, c(list(response_type = "continuous", n = n), args))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(X$x1 + stats::rnorm(n))
	des
}

unbalanced_groups = function(groups, w) {
	sum(tapply(w, groups, function(ww) !(sum(ww) %in% c(floor(length(ww) / 2), ceiling(length(ww) / 2)))))
}

# G6 #51 DECIDED 2026-10-23 by owner: a BRT replay RE-SOLVES the optimal blocking
# on the resampled covariates (same method/B/dist/solver) and draws within the new
# blocks. Reference solve: the design's own solver called directly on the resampled
# rows of the design's model matrix (constant columns carry no distance).
fresh_optimal_blocks = function(des, i_b) {
	dpriv = des$.__enclos_env__$private
	Xb = dpriv$X[i_b, , drop = FALSE]
	Xb = Xb[, apply(Xb, 2L, function(col) length(unique(col)) > 1L), drop = FALSE]
	switch(dpriv$method,
		`K-way` = dpriv$solve_kway_blocks(Xb),
		greedy = dpriv$solve_greedy_blocks(Xb),
		ompr = dpriv$solve_optimal_blocks(optimal_blocks_distance_matrix_cpp(Xb, dist_code = 3L))
	)
}

same_partition = function(a, b) {
	a = as.integer(a); b = as.integer(b)
	identical(match(a, unique(a)), match(b, unique(b)))
}

optimal_blocks_replay_subdesign = function(des, i_b) {
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	sub_inf = inf$.__enclos_env__$private$bootstrap_subset_inference(list(i_b = i_b, m_vec_b = NULL), smooth = FALSE)
	sub_inf$.__enclos_env__$private$des_obj
}

replay_cases = list(
	list(design = "DesignFixedBlocking", args = list(strata_cols = "site"), kind = "blocks"),
	list(design = "DesignFixedOptimalBlocks", args = list(B = 5L), kind = "reblocked"),
	list(design = "DesignFixedCluster", args = list(cluster_col = "cl"), kind = "clusters"),
	list(design = "DesignFixedBlockedCluster", args = list(strata_cols = "site", cluster_col = "cl"), kind = "blocked_clusters"),
	list(design = "DesignFixedBinaryMatch", args = list(), kind = "pairs"),
	list(design = "DesignFixedMatchingGreedyPairSwitching", args = list(), kind = "pairs"),
	list(design = "DesignFixedRerandomization", args = list(prop_acceptable = 0.1), kind = "balanced"),
	list(design = "DesignFixedGreedy", args = list(), kind = "balanced"),
	list(design = "DesignFixedGreedyDOptimal", args = list(), kind = "balanced")
)

for (case in replay_cases) {
	test_that(paste0(case$design, " BRT replay respects the resampled structure"), {
		des = replay_fixture(case$design, case$args)
		dpriv = des$.__enclos_env__$private
		inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
		set.seed(3)
		draws = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(10L, materialize_w = TRUE)
		blocks = if (!is.null(dpriv$m)) as.integer(dpriv$m) else NULL
		Xraw = dpriv$Xraw
		for (d in draws) {
			expect_false(is.null(d$w_b), info = case$design)
			if (is.null(d$w_b)) next
			w = d$w_b
			if (case$kind == "pairs") {
				expect_equal(sum(tapply(w, d$m_vec_b, sum) != 1), 0, info = case$design)
			} else if (case$kind == "blocks") {
				expect_equal(unbalanced_groups(blocks[d$i_b], w), 0, info = case$design)
			} else if (case$kind == "reblocked") {
				# G6 #51 (owner, 2026-10-23): the blocking is re-solved on the resample
				expect_equal(unbalanced_groups(fresh_optimal_blocks(des, d$i_b), w), 0, info = case$design)
			} else if (case$kind %in% c("clusters", "blocked_clusters")) {
				cl = Xraw$cl[d$i_b]
				expect_true(all(tapply(w, cl, function(ww) length(unique(ww)) == 1L)), info = case$design)
				if (case$kind == "blocked_clusters") {
					site = Xraw$site[d$i_b]
					for (s in unique(site)) {
						wc = tapply(w[site == s], cl[site == s], `[`, 1L)
						expect_true(sum(wc) %in% c(floor(length(wc) / 2), ceiling(length(wc) / 2)), info = case$design)
					}
				}
			} else {
				expect_equal(sum(w), length(w) / 2, info = case$design)
			}
		}
	})
}

test_that("DesignFixedOptimalBlocks replay re-solves the blocking on the resampled covariates", {
	des = replay_fixture("DesignFixedOptimalBlocks", list(B = 5L))
	orig_blocks = des$get_block_ids()
	op = des$.__enclos_env__$private
	orig_key = op$block_solve_key
	set.seed(11)
	i_b = sample.int(40L, 40L, replace = TRUE)
	sub_des = optimal_blocks_replay_subdesign(des, i_b)
	sp = sub_des$.__enclos_env__$private
	# the replay design arrives carrying the resampled units' ORIGINAL block ids
	expect_identical(as.integer(sp$m), as.integer(orig_blocks)[i_b])
	set.seed(9)
	w = sub_des$draw_ws_according_to_design(8L)
	fresh = fresh_optimal_blocks(des, i_b)
	# block structure equals a direct fresh solve on the resampled X ...
	expect_true(same_partition(sp$block_ids, fresh))
	# ... which is a different partition from the carried ids
	expect_false(same_partition(sp$block_ids, as.integer(orig_blocks)[i_b]))
	expect_identical(as.integer(sp$m), as.integer(sp$block_ids))
	expect_identical(as.integer(table(sp$block_ids)), rep(8L, 5L))
	# every re-solved block is balanced in every replayed assignment
	for (r in seq_len(ncol(w))) expect_equal(unbalanced_groups(fresh, w[, r]), 0)
	# seeded replay is reproducible
	sub_des2 = optimal_blocks_replay_subdesign(des, i_b)
	set.seed(9)
	expect_identical(sub_des2$draw_ws_according_to_design(8L), w)
	# a second draw on the same resample reuses the re-solve (no further solve)
	unlockBinding("solve_kway_blocks", sp)
	sp$solve_kway_blocks = function(X) stop("unexpected second re-solve")
	expect_silent(sub_des$draw_ws_according_to_design(2L))
	# the original design's blocks, solve key and draws are untouched, and a normal
	# draw on unchanged data hits the cache instead of re-solving
	expect_identical(as.integer(op$block_ids), as.integer(orig_blocks))
	expect_identical(op$block_solve_key, orig_key)
	set.seed(5)
	w_before = des$draw_ws_according_to_design(4L)
	unlockBinding("solve_kway_blocks", op)
	real_solve = op$solve_kway_blocks
	op$solve_kway_blocks = function(X) stop("normal draw must not re-solve")
	set.seed(5)
	expect_identical(des$draw_ws_according_to_design(4L), w_before)
	op$solve_kway_blocks = real_solve
	for (r in seq_len(ncol(w_before))) expect_equal(unbalanced_groups(as.integer(orig_blocks), w_before[, r]), 0)
})

test_that("DesignFixedOptimalBlocks BRT replay draws are reproducible and re-solved per draw", {
	des = replay_fixture("DesignFixedOptimalBlocks", list(B = 5L))
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	ip = inf$.__enclos_env__$private
	set.seed(3)
	draws = ip$generate_rand_bootstrap_draws(8L, materialize_w = TRUE)
	set.seed(3)
	draws2 = ip$generate_rand_bootstrap_draws(8L, materialize_w = TRUE)
	expect_identical(lapply(draws, `[[`, "w_b"), lapply(draws2, `[[`, "w_b"))
	carried_unbalanced = 0
	for (d in draws) {
		expect_equal(unbalanced_groups(fresh_optimal_blocks(des, d$i_b), d$w_b), 0)
		carried_unbalanced = carried_unbalanced + unbalanced_groups(as.integer(des$get_block_ids())[d$i_b], d$w_b)
	}
	# the draws are balanced within the re-solved blocks, not the carried ones
	expect_gt(carried_unbalanced, 0)
})

test_that("a failed replay re-solve makes that draw a recorded failure, not a crash", {
	des = replay_fixture("DesignFixedOptimalBlocks", list(B = 5L))
	orig_blocks = des$get_block_ids()
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	set.seed(3)
	draws = with_mocked_bindings(
		balanced_clustering = function(...) stop("solver failed"),
		.package = "anticlust",
		code = inf$.__enclos_env__$private$generate_rand_bootstrap_draws(4L, materialize_w = TRUE)
	)
	expect_true(all(vapply(draws, function(d) is.null(d$w_b), logical(1L))))
	expect_identical(as.integer(des$.__enclos_env__$private$block_ids), as.integer(orig_blocks))
	# the failed sub-design keeps no stale blocks for a later draw to reuse
	set.seed(11)
	i_b = sample.int(40L, 40L, replace = TRUE)
	sub_des = optimal_blocks_replay_subdesign(des, i_b)
	sp = sub_des$.__enclos_env__$private
	with_mocked_bindings(
		balanced_clustering = function(...) stop("solver failed"),
		.package = "anticlust",
		code = expect_error(sub_des$draw_ws_according_to_design(1L), "solver failed")
	)
	expect_null(sp$block_ids)
	expect_null(sp$block_solve_key)
	invisible(sub_des$draw_ws_according_to_design(1L))
	expect_true(same_partition(sp$block_ids, fresh_optimal_blocks(des, i_b)))
	# the null distribution records failed re-solves as NA instead of erroring
	set.seed(4)
	t0 = with_mocked_bindings(
		balanced_clustering = function(...) stop("solver failed"),
		.package = "anticlust",
		code = inf$approximate_rand_bootstrap_distribution_beta_hat_T(B = 5L, delta = 0, show_progress = FALSE)
	)
	expect_true(all(is.na(t0)))
})

test_that("DesignFixedOptimalBlocks greedy and ompr replays also re-solve with the design's solver", {
	for (method in c("greedy", "ompr")) {
		if (method == "greedy") skip_if_not_installed("blockTools")
		if (method == "ompr") {
			skip_if_not_installed("ompr"); skip_if_not_installed("ompr.roi"); skip_if_not_installed("ROI.plugin.glpk")
		}
		n = if (method == "ompr") 8L else 24L
		B = if (method == "ompr") 2L else 4L
		set.seed(2)
		X = data.frame(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
		des = DesignFixedOptimalBlocks$new(response_type = "continuous", n = n, B = B, method = method, verbose = FALSE)
		des$add_all_subjects_to_experiment(X)
		des$assign_w_to_all_subjects()
		des$add_all_subject_responses(X$x1 + stats::rnorm(n))
		orig_blocks = des$get_block_ids()
		set.seed(7)
		i_b = sample.int(n, n, replace = TRUE)
		sub_des = optimal_blocks_replay_subdesign(des, i_b)
		set.seed(1)
		w = sub_des$draw_ws_according_to_design(3L)
		sp = sub_des$.__enclos_env__$private
		# blockTools' greedy blocking consumes the RNG: the replay solve runs under
		# the draw's own seed, so the reference solve uses the same one
		set.seed(1)
		expect_true(same_partition(sp$block_ids, fresh_optimal_blocks(des, i_b)), info = method)
		for (r in seq_len(ncol(w))) expect_equal(unbalanced_groups(as.integer(sp$block_ids), w[, r]), 0, info = method)
		expect_identical(as.integer(des$.__enclos_env__$private$block_ids), as.integer(orig_blocks), info = method)
	}
})

test_that("GreedyDOptimal and Rerandomization rebuild covariate caches when X changes", {
	set.seed(11)
	i_b = sample.int(40L, 40L, replace = TRUE)
	des = replay_fixture("DesignFixedGreedyDOptimal", list())
	dup = des$duplicate(verbose = FALSE)
	dp = dup$.__enclos_env__$private
	P0 = dp$P
	expect_false(is.null(P0))
	dp$X = dp$X[i_b, , drop = FALSE]
	invisible(dup$draw_ws_according_to_design(1L))
	expect_equal(dp$P, build_optimal_design_P_H(dp$X, "all", NULL, TRUE, FALSE)$P)
	expect_identical(des$.__enclos_env__$private$P, P0)

	des = replay_fixture("DesignFixedRerandomization", list(prop_acceptable = 0.1))
	dup = des$duplicate(verbose = FALSE)
	dp = dup$.__enclos_env__$private
	dp$X = dp$X[i_b, , drop = FALSE]
	invisible(dup$draw_ws_according_to_design(1L))
	S = stats::var(dp$X)
	expect_equal(dp$S_inv, solve(S))
})

test_that("greedy optimal blocks survive a blockTools assignment whose incomplete row is not last", {
	skip_if_not_installed("blockTools")
	# n = 200, B = 14 bootstrap resample (duplicated rows) on which blockTools put its
	# incomplete row mid-table; the re-solve failed with "replacement has length zero"
	n = 200L; B = 14L
	set.seed(1)
	X = as.data.frame(matrix(stats::rnorm(n * 4L), n, 4L))
	des = DesignFixedOptimalBlocks$new(response_type = "continuous", n = n, B = B, method = "greedy", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	dp = des$.__enclos_env__$private
	dp$ensure_model_matrix_current()
	set.seed(5)
	i_b = sample.int(n, n, replace = TRUE)
	set.seed(1)
	ids = dp$solve_greedy_blocks(dp$X[i_b, , drop = FALSE])
	expect_length(ids, n)
	expect_true(all(table(ids) %in% c(14L, 15L)))
	expect_identical(nlevels(ids), B)
})
