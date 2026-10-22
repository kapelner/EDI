library(testthat)
library(EDI)

# TODO-124 (release_v1_0_5.md): the KK continuous OLS/robust IVWC + OneLik
# classes must expose a finite point estimate through the estimate-only path
# that every resampling procedure (randomization, bootstrap, jackknife)
# uses for its observed statistic and refits.
#  - InferenceContinKKOLSIVWC: the IVW weights need the per-component
#    variances, and the estimate-only path used to skip them, so
#    compute_estimate(estimate_only = TRUE) returned NA on a fresh object
#    and every resampling p-value / CI was NA.
#  - OneLik classes were never affected; the NA-vs-NA randomization columns
#    in the migration goldens come from the r = 9 draw count, which is below
#    the documented minimum of 10 finite draws for a randomization p-value.

make_kk_estimate_only_design = function(n = 60L, seed = 20261022L) {
	set.seed(seed)
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i = des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, 1.0 * ((w_i + 1) / 2) + 0.3 * X$x1[i] + rnorm(1L, sd = 0.6))
	}
	des
}

kk_estimate_only_classes = c(
	"InferenceContinKKOLSIVWC", "InferenceContinKKOLSOneLik",
	"InferenceContinKKRobustRegrIVWC", "InferenceContinKKRobustRegrOneLik"
)

test_that("estimate_only = TRUE on a fresh object is finite and equals the full estimate", {
	des = make_kk_estimate_only_design()
	for (cl in kk_estimate_only_classes) {
		est_only = get(cl)$new(des)$compute_estimate(estimate_only = TRUE)
		full = get(cl)$new(des)$compute_estimate()
		expect_true(is.finite(est_only), info = cl)
		expect_equal(est_only, full, tolerance = 1e-8, info = cl)
	}
})

test_that("randomization p-value is finite and in the ballpark of the Wald p-value", {
	des = make_kk_estimate_only_design()
	for (cl in kk_estimate_only_classes) {
		inf = get(cl)$new(des)
		inf$set_seed(1L)
		p_rand = inf$compute_rand_two_sided_pval(r = 201L, show_progress = FALSE)
		p_wald = get(cl)$new(des)$compute_asymp_two_sided_pval()
		expect_true(is.finite(p_rand), info = cl)
		expect_gt(p_rand, 0)
		expect_lt(abs(p_rand - p_wald), 0.15, label = paste(cl, "|p_rand - p_wald|"))
	}
})

test_that("randomization distribution is entirely finite for the four KK continuous classes", {
	des = make_kk_estimate_only_design()
	for (cl in kk_estimate_only_classes) {
		inf = get(cl)$new(des)
		inf$set_seed(1L)
		d = inf$approximate_randomization_distribution_beta_hat_T(r = 21L, show_progress = FALSE)
		expect_equal(sum(is.finite(d)), 21L, info = cl)
	}
})
