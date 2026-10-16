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

kk_wilcox_stats_fixture <- function(stats, seed) {
	inf <- kk_wilcox_hl_variance_fixture(n = 8L, seed = seed)
	p <- inf$.__enclos_env__$private
	# Supply deterministic, explicitly sized matching/reservoir summaries so
	# each shared() branch is guaranteed rather than silently skipped by a
	# random design fixture. The reference below is computed independently from
	# these source statistics, not from the estimator's populated cache.
	p$cached_values$KKstats <- stats
	list(inf = inf, priv = p, stats = stats)
}

kk_wilcox_component_references <- function(diffs, y_t, y_c) {
	matched <- NULL
	if (length(diffs) > 0L && !all(diffs == 0)) {
		matched <- suppressWarnings(stats::wilcox.test(diffs, conf.int = TRUE))
		walsh <- (outer(diffs, diffs, "+") / 2)[upper.tri(matrix(0, length(diffs), length(diffs)), diag = TRUE)]
		matched <- list(
			beta = unname(as.numeric(matched$estimate)),
			ssq = if (length(diffs) >= 2L) var(walsh) * (2 * pi / 3) / length(diffs) else NA_real_
		)
	}
	reservoir <- NULL
	if (length(y_t) > 0L && length(y_c) > 0L) {
		mod <- suppressWarnings(stats::wilcox.test(y_t, y_c, conf.int = TRUE))
		reservoir_diffs <- as.vector(outer(y_t, y_c, "-"))
		reservoir <- list(
			beta = unname(as.numeric(mod$estimate)),
			ssq = if (length(y_t) >= 2L && length(y_c) >= 2L) {
				var(reservoir_diffs) * pi * (length(y_t) + length(y_c)) / (6 * length(y_t) * length(y_c))
			} else NA_real_
		)
	}
	list(matched = matched, reservoir = reservoir)
}

kk_wilcox_cached_stats <- function(diffs = numeric(), y_t = numeric(), y_c = numeric()) {
	list(
		m = as.integer(if (length(diffs)) max(1L, length(diffs)) else 0L),
		nRT = as.integer(length(y_t)),
		nRC = as.integer(length(y_c)),
		y_matched_diffs = as.numeric(diffs),
		y_reservoir = c(y_t, y_c),
		w_reservoir = c(rep(1L, length(y_t)), rep(0L, length(y_c)))
	)
}

test_that("KK Wilcox IVWC combines guaranteed matched and reservoir HL components against independent references", {
	diffs <- c(1, 2, 5)
	y_t <- c(4, 6, 7)
	y_c <- c(1, 3, 4)
	stats <- kk_wilcox_cached_stats(diffs, y_t, y_c)
	f <- kk_wilcox_stats_fixture(stats, seed = 821L)
	ref <- kk_wilcox_component_references(diffs, y_t, y_c)
	expect_identical(c(stats$m, stats$nRT, stats$nRC), c(3L, 3L, 3L))
	expect_true(!is.null(ref$matched) && !is.null(ref$reservoir))
	expect_true(is.finite(ref$matched$ssq) && ref$matched$ssq > 0)
	expect_true(is.finite(ref$reservoir$ssq) && ref$reservoir$ssq > 0)

	w_star <- ref$reservoir$ssq / (ref$reservoir$ssq + ref$matched$ssq)
	expect_equal(f$inf$compute_estimate(), w_star * ref$matched$beta + (1 - w_star) * ref$reservoir$beta, tolerance = 1e-12)
	expect_equal(f$priv$cached_values$s_beta_hat_T,
		sqrt(ref$matched$ssq * ref$reservoir$ssq / (ref$matched$ssq + ref$reservoir$ssq)), tolerance = 1e-12)
	expect_equal(f$priv$cached_values$ssq_beta_T_matched, ref$matched$ssq, tolerance = 1e-12)
	expect_equal(f$priv$cached_values$ssq_beta_T_reservoir, ref$reservoir$ssq, tolerance = 1e-12)
})

test_that("KK Wilcox IVWC reaches each usable one-component fallback", {
	diffs <- c(1, 2, 5)
	y_t <- c(4, 6, 7)
	y_c <- c(1, 3, 4)

	matched <- kk_wilcox_stats_fixture(kk_wilcox_cached_stats(diffs = diffs), seed = 822L)
	matched_ref <- kk_wilcox_component_references(diffs, numeric(), numeric())$matched
	expect_identical(c(matched$stats$m, matched$stats$nRT, matched$stats$nRC), c(3L, 0L, 0L))
	expect_true(!is.null(matched_ref) && matched_ref$ssq > 0)
	expect_equal(matched$inf$compute_estimate(), matched_ref$beta, tolerance = 1e-12)
	expect_equal(matched$priv$cached_values$s_beta_hat_T, sqrt(matched_ref$ssq), tolerance = 1e-12)

	reservoir <- kk_wilcox_stats_fixture(kk_wilcox_cached_stats(y_t = y_t, y_c = y_c), seed = 823L)
	reservoir_ref <- kk_wilcox_component_references(numeric(), y_t, y_c)$reservoir
	expect_identical(c(reservoir$stats$m, reservoir$stats$nRT, reservoir$stats$nRC), c(0L, 3L, 3L))
	expect_true(!is.null(reservoir_ref) && reservoir_ref$ssq > 0)
	expect_equal(reservoir$inf$compute_estimate(), reservoir_ref$beta, tolerance = 1e-12)
	expect_equal(reservoir$priv$cached_values$s_beta_hat_T, sqrt(reservoir_ref$ssq), tolerance = 1e-12)
})

test_that("KK Wilcox IVWC handles degenerate and insufficient-size components explicitly", {
	# All-zero paired differences take rank_for_matched_pairs()'s early return;
	# with no reservoir component, shared() must report a non-estimable result.
	all_zero <- kk_wilcox_stats_fixture(kk_wilcox_cached_stats(diffs = c(0, 0)), seed = 824L)
	expect_identical(c(all_zero$stats$m, all_zero$stats$nRT, all_zero$stats$nRC), c(2L, 0L, 0L))
	expect_true(is.na(all_zero$inf$compute_estimate()))
	expect_true(is.na(all_zero$priv$cached_values$s_beta_hat_T))

	# One paired difference and a 1-vs-2 reservoir reach the variance-size
	# fallbacks (m_pairs < 2; one reservoir arm < 2) despite both rank tests
	# having observations. Their point estimates remain independently defined,
	# but neither component has a usable variance for the IVWC estimate.
	small <- kk_wilcox_stats_fixture(
		kk_wilcox_cached_stats(diffs = 2, y_t = 4, y_c = c(1, 3)), seed = 825L
	)
	expect_identical(c(small$stats$m, small$stats$nRT, small$stats$nRC), c(1L, 1L, 2L))
	expect_true(!is.null(kk_wilcox_component_references(2, 4, c(1, 3))$matched))
	expect_true(!is.null(kk_wilcox_component_references(2, 4, c(1, 3))$reservoir))
	expect_true(is.na(small$inf$compute_estimate()))
	expect_true(is.na(small$priv$cached_values$s_beta_hat_T))

	# Constant treatment/control reservoir groups produce a zero pairwise-
	# difference variance: the rank estimator exists but that component is not
	# usable for inverse-variance combination.
	constant <- kk_wilcox_stats_fixture(
		kk_wilcox_cached_stats(y_t = c(3, 3), y_c = c(3, 3)), seed = 826L
	)
	expect_identical(c(constant$stats$m, constant$stats$nRT, constant$stats$nRC), c(0L, 2L, 2L))
	expect_true(is.na(constant$inf$compute_estimate()))
	expect_true(is.na(constant$priv$cached_values$ssq_beta_T_reservoir))
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
