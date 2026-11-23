# v1.2.0-TODO-263 (owner ruling 2026-11-23, option (a)): the (1 + b) / (1 + B) randomization
# p-value (v1.2.0-TODO-207) counts the observed allocation once, so it must not also be one of
# the B reference draws. (1) A seeded fixed design analysed without an inference seed used to
# replay its realized allocation as reference draw 1; that replay is now skipped. (2) A supplied
# full enumeration contains the realized allocation; exactly one copy is dropped.

seeded_fixture = function(cls = DesignFixediBCRD, n = 20L, seed = 11L, ...) {
	set.seed(seed + 1000L)
	des = cls$new(n = n, response_type = "continuous", seed = seed, ...)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	des
}

test_that("a seeded design's reference draws skip the replayed realized allocation", {
	for (cls in list(DesignFixediBCRD, DesignFixedBernoulli)) {
		des = seeded_fixture(cls)
		w = as.numeric(des$get_w())
		# the replay this guards against: the first draw of the design-seed stream is w
		dd = des$duplicate()
		set.seed(11L)
		expect_identical(as.numeric(dd$draw_ws_according_to_design(1L)[, 1L]), w)
		inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
		P = inf$.__enclos_env__$private$generate_permutations(50L)$w_mat
		expect_equal(ncol(P), 50L)
		expect_false(isTRUE(all(P[, 1L] == w)))
		# the reference draws are exactly the design-seed stream after the replayed draw
		dd = des$duplicate()
		set.seed(11L)
		invisible(dd$draw_ws_according_to_design(1L))
		expect_equal(unname(P), unname(dd$draw_ws_according_to_design(50L)))
	}
})

test_that("only the replay is skipped: legitimate redraws equal to w are kept", {
	# n = 4 with 2 treated has 6 allocations, so random redraws often equal w by chance
	des = seeded_fixture(DesignFixediBCRD, n = 4L, seed = 3L)
	w = as.numeric(des$get_w())
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	P = inf$.__enclos_env__$private$generate_permutations(60L)$w_mat
	expect_gt(sum(colSums(abs(P - w)) == 0), 0L)
	# an inference seed different from the design seed draws from its own stream, untouched
	inf2 = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf2$set_seed(99L)
	P2 = inf2$.__enclos_env__$private$generate_permutations(60L)$w_mat
	dd = des$duplicate()
	set.seed(99L)
	expect_equal(unname(P2), unname(dd$draw_ws_according_to_design(60L)))
	# an inference seed equal to the design seed replays too, and is skipped the same way
	inf3 = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf3$set_seed(3L)
	expect_equal(unname(inf3$.__enclos_env__$private$generate_permutations(60L)$w_mat), unname(P))
})

test_that("seeded p-values and CIs stay reproducible and independent of the core count", {
	des = seeded_fixture(DesignFixediBCRD)
	mk = function(cores) { inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE); inf$num_cores = cores; inf }
	p1 = mk(1L)$compute_rand_two_sided_pval(r = 201L, show_progress = FALSE)
	expect_identical(mk(1L)$compute_rand_two_sided_pval(r = 201L, show_progress = FALSE), p1)
	expect_identical(mk(2L)$compute_rand_two_sided_pval(r = 201L, show_progress = FALSE), p1)
	expect_true(is.finite(p1) && p1 >= 2 / 202)
	# the CI search, including its sequential Monte Carlo batches (deferred draws), seeds the same way
	ci1 = mk(1L)$compute_rand_confidence_interval(r = 201L, show_progress = FALSE)
	expect_identical(mk(1L)$compute_rand_confidence_interval(r = 201L, show_progress = FALSE), ci1)
	expect_identical(mk(2L)$compute_rand_confidence_interval(r = 201L, show_progress = FALSE), ci1)
	ctrl = list(mc_enable = FALSE)
	expect_identical(mk(1L)$compute_rand_confidence_interval(r = 201L, show_progress = FALSE, ci_search_control = ctrl),
		mk(2L)$compute_rand_confidence_interval(r = 201L, show_progress = FALSE, ci_search_control = ctrl))
})

test_that("a supplied full enumeration has one copy of the realized allocation removed", {
	set.seed(4)
	n = 8L
	des = DesignFixediBCRD$new(n = n, response_type = "continuous")
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	y = rnorm(n)
	des$add_all_subject_responses(y)
	w = as.numeric(des$get_w())
	cmb = utils::combn(n, 4L)
	W = matrix(0, n, ncol(cmb))
	for (j in seq_len(ncol(cmb))) W[cmb[, j], j] = 1
	N = ncol(W)                                   # 70, includes w once
	md = function(wv) mean(y[wv == 1]) - mean(y[wv == 0])
	t_all = apply(W, 2L, md)
	t_obs = md(w)
	tol = sqrt(.Machine$double.eps) * max(abs(t_all))
	b_ge = sum(t_all >= t_obs - tol); b_le = sum(t_all <= t_obs + tol)   # both count w itself
	exact = c(two.sided = min(1, 2 * min(b_ge, b_le) / N), greater = b_ge / N, less = b_le / N)
	inf = InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	for (alt in names(exact)) {
		p_auto = inf$compute_rand_two_sided_pval(r = N, permutations = list(w_mat = W), show_progress = FALSE, alternative = alt)
		p_flag = inf$compute_rand_two_sided_pval(r = N, permutations = list(w_mat = W, enumeration = TRUE), show_progress = FALSE, alternative = alt)
		p_off = inf$compute_rand_two_sided_pval(r = N, permutations = list(w_mat = W, enumeration = FALSE), show_progress = FALSE, alternative = alt)
		expect_equal(p_auto, exact[[alt]], info = alt)          # b / N: counted once, exact
		expect_identical(p_flag, p_auto)
		# without the drop, w is counted twice (once as a draw, once through the +1)
		k = switch(alt, two.sided = min(b_ge, b_le), greater = b_ge, less = b_le)
		expect_equal(p_off, min(1, (if (alt == "two.sided") 2 else 1) * (1 + k) / (1 + N)), info = alt)
	}
	# random draws are never treated as an enumeration, even when one equals w
	R = cbind(W[, 1:30], w)
	expect_false(EDI:::rand_drop_realized_from_enumeration(list(w_mat = R), w, ncol(R))$dropped)
	# the helper drops exactly one copy
	E = EDI:::rand_drop_realized_from_enumeration(list(w_mat = W), w, N)
	expect_true(E$dropped)
	expect_identical(E$r, N - 1L)
	expect_equal(sum(colSums(abs(E$permutations$w_mat - w)) == 0), 0)
	# enumeration = TRUE without w among the columns is an error
	keep = colSums(abs(W - w)) != 0
	expect_error(inf$compute_rand_two_sided_pval(r = sum(keep), permutations = list(w_mat = W[, keep], enumeration = TRUE),
		show_progress = FALSE), "realized allocation is not among")
})

test_that("the full enumeration test is exact: rejection probability <= alpha over all allocations", {
	set.seed(9)
	n = 8L
	y = rexp(n)
	cmb = utils::combn(n, 4L)
	W = matrix(0, n, ncol(cmb))
	for (j in seq_len(ncol(cmb))) W[cmb[, j], j] = 1
	p = vapply(seq_len(ncol(W)), function(j) {
		des = DesignFixediBCRD$new(n = n, response_type = "continuous")
		des$add_all_subjects_to_experiment(data.frame(x1 = seq_len(n)))
		des$overwrite_all_subject_assignments(W[, j])
		des$add_all_subject_responses(y)
		InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)$compute_rand_two_sided_pval(
			r = ncol(W), permutations = list(w_mat = W), show_progress = FALSE)
	}, numeric(1))
	for (alpha in c(0.05, 0.1, 0.2)) expect_lte(mean(p <= alpha + 1e-12), alpha)
})
