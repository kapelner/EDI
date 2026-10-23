library(testthat)
library(EDI)

# TODO-129 sweep (release_v1_0_5.md, owner decision G6 #49): every resampling
# override that makes its own random draws must apply set_seed() (save the
# caller's .Random.seed, set.seed(seed), restore on exit), like the base
# InferenceNonParamBootstrap$approximate_bootstrap_distribution_beta_hat_T().
# Offenders found and fixed by the sweep (each case below fails before its fix):
#  - InferenceMixinKKPassThrough bootstrap (the original TODO-129 fix);
#  - InferencePropGCompMeanDiff$approximate_bootstrap_distribution_beta_hat_T()
#    (own screened-resample loop; serial and debug paths were unseeded);
#  - InferenceNonParamBootstrap's calibrated / double-bootstrap / prepivoted
#    CI (private ci_calibrated_bootstrap(): outer calibration resamples);
#  - InferenceExtQuantileRandCI$compute_rand_confidence_interval() (Zhang
#    sign-flip / permutation draws; InferenceContin/PropKKQuantileRegrIVWC).
# Unseeded calls still draw from the caller's global RNG stream.

make_sweep129_design = function(response_type, kind = c("match", "ibcrd"), n = 40L, seed = 7L) {
	kind = match.arg(kind)
	set.seed(seed)
	des = if (kind == "match") {
		DesignFixedBinaryMatch$new(response_type = response_type, n = n,
			m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	} else {
		DesignFixediBCRD$new(response_type = response_type, n = n, verbose = FALSE)
	}
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	w = as.vector(replicate(n / 2L, sample(0:1)))
	des$assign_w_to_all_subjects(w)
	eta = 0.5 * w + 0.4 * X$x1
	y = if (response_type == "continuous") {
		eta + rnorm(n)
	} else {
		pmin(0.95, pmax(0.05, plogis(eta + rnorm(n, 0, 0.5))))
	}
	des$add_all_subject_responses(y)
	des
}

sweep129_cases = list(
	kk_passthrough_boot = list(cls = "InferenceContinKKOLSOneLik", rt = "continuous", kind = "match",
		call = function(inf) inf$approximate_bootstrap_distribution_beta_hat_T(B = 9, show_progress = FALSE)),
	prop_gcomp_boot = list(cls = "InferencePropGCompMeanDiff", rt = "proportion", kind = "ibcrd",
		call = function(inf) inf$approximate_bootstrap_distribution_beta_hat_T(B = 9, show_progress = FALSE)),
	prop_gcomp_boot_debug = list(cls = "InferencePropGCompMeanDiff", rt = "proportion", kind = "ibcrd",
		call = function(inf) inf$approximate_bootstrap_distribution_beta_hat_T(B = 5, show_progress = FALSE, debug = TRUE)$values),
	# ~40 s for both blocks (25 x 5 outer resamples, each with an inner bootstrap).
	calibrated_boot_ci = list(cls = "InferenceContinOLS", rt = "continuous", kind = "ibcrd", heavy = TRUE,
		call = function(inf) inf$compute_bootstrap_confidence_interval(B = 25, type = "calibrated", show_progress = FALSE)),
	quantile_ivwc_rand_ci = list(cls = "InferenceContinKKQuantileRegrIVWC", rt = "continuous", kind = "match",
		call = function(inf) inf$compute_rand_confidence_interval(r = 15, show_progress = FALSE)),
	prop_quantile_ivwc_rand_ci = list(cls = "InferencePropKKQuantileRegrIVWC", rt = "proportion", kind = "match",
		call = function(inf) inf$compute_rand_confidence_interval(r = 15, show_progress = FALSE))
)

sweep129_run = function(case, des, seed) {
	inf = get(case$cls)$new(des, verbose = FALSE)
	if (!is.null(seed)) inf$set_seed(seed)
	inf$num_cores = 1L
	suppressWarnings(case$call(inf))
}

for (case_name in names(sweep129_cases)) {
	local({
		case = sweep129_cases[[case_name]]
		test_that(paste0("TODO-129 sweep: seeded ", case_name, " is reproducible and leaves the caller's RNG alone"), {
			if (isTRUE(case$heavy)) skip_on_cran()
			des = make_sweep129_design(case$rt, case$kind)
			set.seed(1L); a = sweep129_run(case, des, seed = 5L)
			set.seed(2L); before = .Random.seed
			b = sweep129_run(case, des, seed = 5L)
			expect_true(identical(.Random.seed, before), info = paste(case_name, "caller RNG untouched"))
			expect_equal(a, b, tolerance = 1e-10, info = case_name)
			expect_true(any(is.finite(a)), info = case_name)
		})
		test_that(paste0("TODO-129 sweep: unseeded ", case_name, " still draws from the caller's RNG stream"), {
			if (isTRUE(case$heavy)) skip_on_cran()
			des = make_sweep129_design(case$rt, case$kind)
			set.seed(3L); a = sweep129_run(case, des, seed = NULL)
			set.seed(3L); b = sweep129_run(case, des, seed = NULL)
			expect_equal(a, b, tolerance = 1e-10, info = case_name)
			set.seed(3L); before = .Random.seed
			sweep129_run(case, des, seed = NULL)
			expect_false(identical(.Random.seed, before), info = paste(case_name, "unseeded call advances the caller's RNG"))
		})
	})
}
