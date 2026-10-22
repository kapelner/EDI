library(testthat)
library(EDI)

# ZINB where the zero-inflation treatment coefficient runs to -Inf (one arm has
# no excess zeros): the zi block is unidentified, but the count-model treatment
# coefficient is estimable and pscl / glmmTMB report a finite SE for it. EDI used
# to reject the whole vcov (rcond ~1e-12) and return a NA Wald p-value.

zinb_zi_sep_design = function(n = 40L, seed = 1L) {
	set.seed(seed)
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = rnbinom(n, mu = 3 * exp(0.3 * w), size = 1.5)
	y[runif(n) < 0.3] = 0
	des$add_all_subject_responses(y)
	des
}

test_that("ZINB Wald SE is finite and matches pscl when only the zero-inflation block is unidentified", {
	skip_on_cran()
	skip_if_not_installed("pscl")
	for (sd in c(1L, 3L)) {
		des = zinb_zi_sep_design(seed = sd)
		inf = InferenceCountZeroInflatedNegBin$new(des, verbose = FALSE)
		est = inf$compute_estimate()
		se = inf$.__enclos_env__$private$get_standard_error()
		expect_true(is.finite(se) && se > 0, info = paste("seed", sd))
		d = data.frame(y = des$get_y(), w = des$get_w())
		ref = suppressWarnings(pscl::zeroinfl(y ~ w | w, data = d, dist = "negbin"))
		sm = summary(ref)$coefficients$count
		expect_equal(est, unname(sm["w", 1]), tolerance = 1e-3)
		expect_equal(se, unname(sm["w", 2]), tolerance = 0.05)
		p = inf$compute_asymp_two_sided_pval()
		expect_true(is.finite(p) && p > 0 && p <= 1)
	}
})
