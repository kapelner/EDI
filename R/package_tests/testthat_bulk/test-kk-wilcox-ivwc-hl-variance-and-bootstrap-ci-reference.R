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

test_that("KK Wilcox IVWC bootstrap CI is disabled for its (necessarily sequential) KK design", {
	# Nonparametric bootstrap resampling of subjects is invalid for response-
	# adaptive sequential designs (inference_class_registry.R's
	# EDI_INFERENCE_DESIGN_EXCLUDED_CAPABILITIES: any DesignSeqOneByOne
	# descendant except the non-adaptive DesignSeqOneByOneBernoulli loses
	# compute_bootstrap_confidence_interval() and its aliases). Every concrete
	# design InferenceAllKKWilcoxIVWC can attach to is itself a KK (sequential)
	# design, so this capability can never actually run for this class --
	# this test was written before that restriction existed; it now asserts
	# the restriction fires instead of expecting the call to succeed.
	inf <- kk_wilcox_hl_variance_fixture(seed = 812L)
	expect_error(
		inf$compute_bootstrap_confidence_interval(B = 61L, show_progress = FALSE),
		"not supported for DesignSeqOneByOne designs"
	)
})
