library(testthat)
library(EDI)

kk_wilcox_hl_variance_fixture <- function(n = 40L, seed = 811L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		des$add_one_subject_response(i, rnorm(1) + 0.4 * w_i)
	}
	InferenceAllKKWilcoxIVWC$new(des, verbose = FALSE)
}

test_that("KK Wilcox IVWC uses the normal-calibrated HL component variances", {
	inf <- kk_wilcox_hl_variance_fixture()
	p <- inf$.__enclos_env__$private
	p$compute_basic_match_data()
	inf$compute_estimate()
	stats <- p$cached_values$KKstats

	if (length(stats$y_matched_diffs) >= 2L && !all(stats$y_matched_diffs == 0)) {
		d <- stats$y_matched_diffs
		walsh <- unlist(lapply(seq_along(d), function(i) (d[i] + d[i:length(d)]) / 2))
		expect_equal(p$cached_values$ssq_beta_T_matched, var(walsh) * (2 * pi / 3) / length(d))
	}
	if (stats$nRT >= 2L && stats$nRC >= 2L) {
		y_t <- stats$y_reservoir[stats$w_reservoir == 1L]
		y_c <- stats$y_reservoir[stats$w_reservoir == 0L]
		expect_equal(
			p$cached_values$ssq_beta_T_reservoir,
			var(as.vector(outer(y_t, y_c, "-"))) * pi * (length(y_t) + length(y_c)) / (6 * length(y_t) * length(y_c))
		)
	}
})

test_that("KK Wilcox IVWC bootstrap CI is a resampling interval, not the Wald alias", {
	inf <- kk_wilcox_hl_variance_fixture(seed = 812L)
	set.seed(8121L)
	boot_ci <- inf$compute_bootstrap_confidence_interval(B = 61L, show_progress = FALSE)
	wald_ci <- inf$compute_asymp_confidence_interval()
	expect_length(boot_ci, 2L)
	expect_true(all(is.finite(boot_ci)))
	expect_false(isTRUE(all.equal(boot_ci, wald_ci, tolerance = 0)))
})
