library(testthat)
library(EDI)

# ZIP: the default Newton->LBFGS fit from the smart cold start can stall at
# |grad| ~5e-8 (> tol 1e-8) and be flagged unconverged although the params
# already equal pscl's; compute_estimate() used to return NA
# (zero_augmented_poisson_fit_unavailable). A plain cold retry recovers it.

zip_stall_design = function(n = 100L, seed = 6L) {
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

test_that("ZIP estimate and SE match pscl on seeds where the first fit stalls", {
	skip_on_cran()
	skip_if_not_installed("pscl")
	for (sd in c(6L, 19L)) {
		des = zip_stall_design(seed = sd)
		inf = InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
		est = inf$compute_estimate()
		expect_true(is.finite(est), info = paste("seed", sd))
		d = data.frame(y = des$get_y(), w = des$get_w())
		ref = suppressWarnings(pscl::zeroinfl(y ~ w | w, data = d, dist = "poisson"))
		sm = summary(ref)$coefficients$count
		expect_equal(est, unname(sm["w", 1]), tolerance = 1e-3)
		# default SE is the robust sandwich; the model-based inverse information
		# of the recovered fit must equal pscl's
		pr = inf$.__enclos_env__$private
		expect_true(is.finite(pr$get_standard_error()))
		se_mb = sqrt(solve(pr$cached_mod$fisher_information)[2, 2])
		expect_equal(se_mb, unname(sm["w", 2]), tolerance = 0.01)
	}
})
