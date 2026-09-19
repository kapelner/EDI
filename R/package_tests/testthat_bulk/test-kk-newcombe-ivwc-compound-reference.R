library(testthat)
library(EDI)

# InferenceIncidKKNewcombeRiskDiff's compound Newcombe IVWC estimator (paired
# discordant-pairs Newcombe combined with independent-samples Newcombe on the
# reservoir, via inverse-variance weighting) previously had only migration-
# golden coverage (legacy-vs-migrated equivalence, R/EDI/tests/testthat/
# test-incid-kk-newcombe-migration-golden.R) -- never an independent numeric
# reference. Unlike the other KK IVWC "compound estimator" classes in this
# repo (which need iterative score-test/likelihood convergence and turned out
# to be rabbit holes), this one is closed-form algebra straight from the
# matched/reservoir counts, so a from-scratch R re-derivation is safe and fast.

make_kk_design <- function(n, seed) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence")
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1), x2 = rnorm(1)))
	}
	des$add_all_subject_responses(rbinom(n, 1, 0.5))
	des
}

kk_newcombe_ivwc_reference <- function(KKstats) {
	m <- KKstats$m
	nRT <- KKstats$nRT
	nRC <- KKstats$nRC
	est_m <- var_m <- est_r <- var_r <- NA_real_
	if (m > 0) {
		p10 <- KKstats$d_plus / m
		p01 <- KKstats$d_minus / m
		est_m <- p10 - p01
		var_m <- (p10 + p01 - (p10 - p01)^2) / m
	}
	if (nRT > 0 && nRC > 0) {
		pRT <- KKstats$n11 / nRT
		pRC <- KKstats$n01 / nRC
		est_r <- pRT - pRC
		var_r <- pRT * (1 - pRT) / nRT + pRC * (1 - pRC) / nRC
	}
	ok_m <- is.finite(est_m) && is.finite(var_m) && var_m > 0
	ok_r <- is.finite(est_r) && is.finite(var_r) && var_r > 0
	if (ok_m && ok_r) {
		w1 <- var_r / (var_m + var_r)
		list(estimate = w1 * est_m + (1 - w1) * est_r, variance = var_m * var_r / (var_m + var_r))
	} else if (ok_m) {
		list(estimate = est_m, variance = var_m)
	} else if (ok_r) {
		list(estimate = est_r, variance = var_r)
	} else {
		list(estimate = NA_real_, variance = NA_real_)
	}
}

test_that("KK Newcombe IVWC point estimate and SE match an independent from-scratch IVWC combination", {
	for (seed in c(42, 7, 99)) {
		des <- make_kk_design(40L, seed)
		inf <- InferenceIncidKKNewcombeRiskDiff$new(des, verbose = FALSE)
		est <- inf$compute_estimate()
		priv <- inf$.__enclos_env__$private
		ref <- kk_newcombe_ivwc_reference(priv$cached_values$KKstats)

		expect_equal(est, ref$estimate, tolerance = 1e-10)
		expect_equal(priv$cached_values$s_beta_hat_T, sqrt(ref$variance), tolerance = 1e-10)
		expect_true(is.na(priv$cached_values$df))
	}
})

test_that("KK Newcombe IVWC falls back to the reservoir-only component when there are no matched pairs", {
	des <- DesignSeqOneByOneKK14$new(n = 16L, response_type = "incidence")
	set.seed(3)
	for (i in seq_len(16L)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = i * 100, x2 = i * 100))
	}
	des$add_all_subject_responses(rbinom(16L, 1, 0.5))
	inf <- InferenceIncidKKNewcombeRiskDiff$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	inf$compute_estimate()
	KKstats <- priv$cached_values$KKstats
	skip_if(KKstats$m > 0L, "fixture unexpectedly produced matched pairs")

	ref <- kk_newcombe_ivwc_reference(KKstats)
	nRT <- KKstats$nRT
	nRC <- KKstats$nRC
	direct_est <- KKstats$n11 / nRT - KKstats$n01 / nRC
	expect_equal(ref$estimate, direct_est, tolerance = 1e-10)
	expect_equal(priv$cached_values$beta_hat_T, direct_est, tolerance = 1e-10)
})

test_that("KK Newcombe IVWC estimate_only skips variance/df but reuses cached estimate on a second call", {
	des <- make_kk_design(30L, 11)
	inf <- InferenceIncidKKNewcombeRiskDiff$new(des, verbose = FALSE)
	est_only <- inf$compute_estimate(estimate_only = TRUE)
	priv <- inf$.__enclos_env__$private
	expect_true(is.finite(est_only))
	est_full <- inf$compute_estimate(estimate_only = FALSE)
	expect_equal(est_full, est_only, tolerance = 1e-12)
	expect_true(is.finite(priv$cached_values$s_beta_hat_T))
})
