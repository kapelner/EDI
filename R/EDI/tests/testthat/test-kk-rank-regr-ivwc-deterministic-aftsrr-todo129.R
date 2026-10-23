library(testthat)
library(EDI)

# TODO-129 / G6 #50 (owner decision 2026-10-23; was release_v1_1_0.md TODO-72):
# InferenceSurvivalKKRankRegrIVWC (legacy IVWC) takes its IVWC weights from
# aftgee::aftsrr(se = "ISMB"), a multiplier bootstrap that reads R's global RNG.
# Every aftsrr call now runs inside a save / set.seed(<deterministic seed>) /
# restore block (seed derived from the object's seed -- inference seed, else
# design seed, else a fixed constant -- plus the fitted data), so results
# duplicate across calls and fresh objects, the caller's .Random.seed is left
# alone, and replicate refits do not depend on the core count.

make_kk_rank_regr_seq_design = function(){
	set.seed(3)
	n = 40L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	x1 = rnorm(n)
	x2 = rnorm(n)
	for (i in seq_len(n)){
		w_i = des$add_one_subject_to_experiment_and_assign(data.frame(x1 = x1[i], x2 = x2[i]))
		t_i = rexp(1, rate = exp(-0.1 + 0.2 * w_i + 0.15 * x1[i]))
		if (runif(1) < 0.8) des$add_one_subject_response(i, t_i) else des$add_one_subject_response(i, y_L = t_i, y_R = Inf)
	}
	des
}

make_kk_rank_regr_match_design = function(n = 40L){
	set.seed(7)
	des = DesignFixedBinaryMatch$new(response_type = "survival", n = n,
		m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	t = rexp(n, rate = exp(-0.1 - 0.4 * w - 0.3 * X$x1))
	cens = runif(n) < 0.2
	des$add_all_subject_responses(ifelse(cens, NA, t), ifelse(cens, t, NA), ifelse(cens, Inf, NA))
	des
}

kk_rank_regr_run = function(des, seed, caller_seed, calls, cores = 1L){
	inf = InferenceSurvivalKKRankRegrIVWC$new(des, verbose = FALSE)
	if (!is.null(seed)) inf$set_seed(seed)
	inf$num_cores = cores
	set.seed(caller_seed)
	before = .Random.seed
	out = suppressWarnings(suppressMessages(lapply(calls, function(f) f(inf))))
	out$untouched = identical(.Random.seed, before)
	out
}

test_that("KKRankRegrIVWC: seeded estimate, SE, randomization p-value and CI duplicate across fresh objects and leave the caller's RNG alone", {
	skip_if_not_installed("aftgee")
	skip_on_cran()
	des = make_kk_rank_regr_seq_design()
	calls = list(
		est = function(inf) inf$compute_estimate(),
		ci = function(inf) inf$compute_asymp_confidence_interval(),
		rand_p = function(inf) inf$compute_rand_two_sided_pval(r = 15, show_progress = FALSE),
		rand_ci = function(inf) inf$compute_rand_confidence_interval(r = 15, show_progress = FALSE)
	)
	a = kk_rank_regr_run(des, 5L, 1L, calls)
	b = kk_rank_regr_run(des, 5L, 2L, calls)
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_true(is.finite(a$est))
	expect_true(all(is.finite(a$ci)))
	expect_identical(a[c("est", "ci", "rand_p", "rand_ci")], b[c("est", "ci", "rand_p", "rand_ci")])
	# the ISMB draws follow the seed: a different seed gives different IVWC weights
	d = kk_rank_regr_run(des, 6L, 1L, calls[c("est", "ci")])
	expect_false(identical(a$ci, d$ci))
})

test_that("KKRankRegrIVWC: unseeded estimate and SE are deterministic and do not advance the caller's RNG", {
	skip_if_not_installed("aftgee")
	des = make_kk_rank_regr_seq_design()
	calls = list(
		est = function(inf) inf$compute_estimate(),
		ci = function(inf) inf$compute_asymp_confidence_interval()
	)
	a = kk_rank_regr_run(des, NULL, 1L, calls)
	b = kk_rank_regr_run(des, NULL, 2L, calls)
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_identical(a[c("est", "ci")], b[c("est", "ci")])
})

test_that("KKRankRegrIVWC: seeded bootstrap duplicates across fresh objects, leaves the caller's RNG alone and does not depend on the core count", {
	skip_if_not_installed("aftgee")
	skip_on_cran()
	des = make_kk_rank_regr_match_design()
	calls = list(
		ci = function(inf) inf$compute_asymp_confidence_interval(),
		boot = function(inf) inf$approximate_bootstrap_distribution_beta_hat_T(B = 11, show_progress = FALSE),
		boot_ci = function(inf) inf$compute_bootstrap_confidence_interval(B = 11, type = "percentile", show_progress = FALSE)
	)
	a = kk_rank_regr_run(des, 5L, 1L, calls)
	b = kk_rank_regr_run(des, 5L, 2L, calls)
	expect_true(a$untouched)
	expect_true(b$untouched)
	expect_true(any(is.finite(a$boot)))
	expect_identical(a[c("ci", "boot", "boot_ci")], b[c("ci", "boot", "boot_ci")])
	c2 = kk_rank_regr_run(des, 5L, 1L, calls, cores = 2L)
	expect_true(c2$untouched)
	expect_identical(a[c("ci", "boot", "boot_ci")], c2[c("ci", "boot", "boot_ci")])
})
