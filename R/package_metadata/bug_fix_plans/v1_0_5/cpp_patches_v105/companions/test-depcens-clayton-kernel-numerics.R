library(testthat)
library(EDI)

# PROPOSED probe-gated tests for cpp patch 02 (DepCens clamped gradient, TODO-111 4th pass) and
# patch 03 (Clayton stable log-sum-exp, TODO-121 3rd batch). NOT in the live suite: copy to
# R/EDI/tests/testthat/ after the patched kernels are built. Pre-patch each block skips with
# 'patch not applied' (probe = the failure it fixes); with EDI_REQUIRE_CPP_PATCHES=true the
# skip becomes a failure.

# EDI_REQUIRE_CPP_PATCHES=true turns "patch not applied" skips into failures: set it once the
# patches are built so a regression back to the old behavior cannot hide behind the probe skip.
skip_unless_patched = function(applied, msg) {
	if (isTRUE(applied)) return(invisible(TRUE))
	if (identical(Sys.getenv("EDI_REQUIRE_CPP_PATCHES"), "true")) testthat::fail(msg) else testthat::skip(msg)
}

# ---- patch 02: DepCens zero-covariate fit, design seed 111, B = 101 resamples, kernel directly ----
# Pre-patch survey (this fixture, estimate_only cold fit, warm start rep(0, 7)): 38 of 101 resamples
# are non-converged / non-finite (the R retry ladder in generate_mod() normally rescues them).
dc_zero_cov_design = function(n = 40L, seed = 111L){
	set.seed(seed)
	des = DesignFixedBinaryMatch$new(n = n, response_type = "survival", m = rep(seq_len(n / 2L), each = 2L), verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(row.names = seq_len(n)))
	des$assign_w_to_all_subjects()
	time = rexp(n); dead = rbinom(n, 1, 0.8)
	des$add_all_subject_responses(ys = ifelse(dead == 1, time, NA),
		y_Ls = ifelse(dead == 1, NA, time), y_Rs = ifelse(dead == 1, NA, Inf))
	des
}
dc_kernel_failures = function(B = 101L){
	inf = InferenceSurvivalDepCensTransformRegr$new(dc_zero_cov_design(), model_formula = ~1, verbose = FALSE)
	inf$compute_estimate()
	p = inf$.__enclos_env__$private
	n = length(p$y)
	set.seed(111L)
	bad = 0L
	for (b in seq_len(B)) {
		ii = sample.int(n, n, replace = TRUE)
		f = tryCatch(suppressWarnings(EDI:::fast_dep_cens_transform_optim_cpp(
			cbind(1, p$w[ii]), as.numeric(p$y[ii]), as.numeric(p$dead[ii]),
			warm_start_params = rep(0, 7), smart_cold_start = FALSE, estimate_only = TRUE)),
			error = function(e) NULL)
		if (is.null(f) || !isTRUE(f$converged) || !is.finite(f$b[2L])) bad = bad + 1L
	}
	bad
}

test_that("DepCens zero-covariate resamples converge in the kernel without the R retry (patch 02)", {
	skip_on_cran()
	bad = dc_kernel_failures()
	skip_unless_patched(bad <= 10L, paste0("DepCens clamped-gradient patch not applied (", bad, "/101 kernel failures)"))
	expect_lte(bad, 2L)
})

# ---- patch 03: Clayton Weibull AFT objective at tiny theta ----
clayton_fixture = function(n_pairs = 30L, seed = 918L) {
	# same generator as test-clayton-logtheta-optimizer-bound.R::clayton_bound_fixture
	set.seed(seed)
	n = n_pairs * 2L
	w = rep(c(0, 1), n_pairs)
	pair_idx = matrix(seq_len(n) - 1L, ncol = 2L, byrow = TRUE)
	u1 = runif(n_pairs); v = runif(n_pairs); theta = 2.5
	u2 = (v^(-theta / (theta + 1)) * (u1^(-theta) - 1) + 1)^(-1 / theta)
	H = as.numeric(rbind(-log(u1), -log(u2)))
	y = exp(0.3 + 0.6 * w + 0.8 * log(H))
	list(X = cbind(w = w), y = y, dead = rep(1, n), pair_idx = pair_idx, singleton_rows = integer(0))
}
clayton_profile_value = function(d, lt) {
	f = tryCatch(suppressWarnings(EDI:::fast_clayton_weibull_aft_optim_cpp(
		d$X, d$y, d$dead, d$pair_idx, d$singleton_rows, c(0.3, 0, lt),
		estimate_only = TRUE, fixed_idx = 3L, fixed_values = lt)), error = function(e) NULL)
	if (is.null(f)) NA_real_ else as.numeric(f$value)
}

test_that("Clayton profile objective stays finite and converges to the independence limit as log-theta -> -Inf (patch 03)", {
	skip_on_cran()
	d = clayton_fixture()
	v20 = clayton_profile_value(d, -20)
	# Pre-patch survey on this fixture: values are finite and smooth to log-theta = -18
	# (101.93186479 at -18) and NaN at -20.
	skip_unless_patched(is.finite(v20), "Clayton stable logA patch not applied (profile value is NaN at log-theta = -20)")
	v18 = clayton_profile_value(d, -18)
	v16 = clayton_profile_value(d, -16)
	expect_true(all(is.finite(c(v16, v18, v20))))
	# limit exists: successive differences shrink (O(theta)) instead of exploding with cancellation noise
	expect_lt(abs(v20 - v18), 1e-6)
	expect_lt(abs(v18 - v16), 1e-4)
	# fits with larger theta*h are unchanged (patch is gated to theta*h <= 1): spot-check the survey value
	expect_equal(clayton_profile_value(d, -6), 101.840010784024, tolerance = 1e-6)
})
