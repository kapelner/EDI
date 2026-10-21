library(testthat)
library(EDI)

# Since 2026-10-20 compute_rand_two_sided_pval() always draws w vectors from the design (user decision):
# the Zhang exact-combined-test dispatch it used to take for Zhang-eligible incidence designs ignored the
# draws and was far more conservative (200 KK21stepwise nulls: reject@0.05 1% vs 3%, median p 0.82 vs 0.58).
# This file pins that every remaining InferenceRandCI-pinned incidence class (probit, binomial-identity, modified Poisson, KK conditional-logit OneLik/IVWC, KK Newcombe) uses the draw-based path on a Zhang-eligible design: the p-value is finite, in (0, 1],
# reproducible under a fixed seed, a nonzero delta is refused for incidence (additive shifts are not defined
# for 0/1 outcomes), and the Zhang test is still reachable explicitly via type = "Zhang".

bernoulli_fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

kk_fx <- function(seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}


check_draw_based_pval <- function(inf, info) {
	expect_true(inf$.__enclos_env__$private$should_use_zhang_incidence_randomization(), info = info)
	set.seed(11L); pv1 <- inf$compute_rand_two_sided_pval(delta = 0, show_progress = FALSE)
	set.seed(11L); pv2 <- inf$compute_rand_two_sided_pval(delta = 0, show_progress = FALSE)
	expect_true(is.finite(pv1) && pv1 > 0 && pv1 <= 1, info = info)
	expect_identical(pv1, pv2, info = info)
	expect_error(inf$compute_rand_two_sided_pval(delta = 0.3, show_progress = FALSE), "delta nonzero not supported for incidence", info = info)
	expect_error(inf$compute_rand_two_sided_pval(delta = -0.3, show_progress = FALSE), "delta nonzero not supported for incidence", info = info)
	pz <- inf$compute_rand_two_sided_pval(delta = 0, type = "Zhang")
	expect_true(is.finite(pz) && pz > 0 && pz <= 1, info = info)
}

test_that("InferenceIncidProbitRegr, InferenceIncidBinomialIdentityRiskDiff, InferenceIncidModifiedPoisson: Zhang-eligible via a plain Bernoulli design, p-value comes from the draws", {
	des <- bernoulli_fx(1L)
	for (cls in c("InferenceIncidProbitRegr", "InferenceIncidBinomialIdentityRiskDiff", "InferenceIncidModifiedPoisson")) {
		check_draw_based_pval(get(cls)$new(des, verbose = FALSE), cls)
	}
})

test_that("InferenceIncidKKCondLogitOneLik, InferenceIncidKKCondLogitIVWC, InferenceIncidKKNewcombeRiskDiff: Zhang-eligible via a real KK14 matching design, p-value comes from the draws", {
	des <- kk_fx(2L)
	for (cls in c("InferenceIncidKKCondLogitOneLik", "InferenceIncidKKCondLogitIVWC", "InferenceIncidKKNewcombeRiskDiff")) {
		check_draw_based_pval(get(cls)$new(des, verbose = FALSE), cls)
	}
})
