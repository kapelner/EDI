library(testthat)
library(EDI)

# InferenceMixinKKPassthroughCompound's private compute_reservoir_and_match_statistics()
# (inference_mixin_kk_passthrough_compound.R) computes the matched-pairs mean difference (d_bar) and
# its variance (ssqD_bar = var(y_matched_diffs) / m), the reservoir mean difference (r_bar) via its
# pooled-variance two-sample formula (ssqR = pooled_var * (1/nRT + 1/nRC)), and the inverse-variance
# combination weight (w_star = ssqR / (ssqR + ssqD_bar)) -- the exact formulas InferenceAllKKMeanDiffIVWC's
# shared() (already covered for its own branch-dispatch logic in test-kk-mean-diff-ivwc-shared-
# extreme-imbalance-branches-reference.R, which injects these values directly rather than deriving
# them) relies on. A codebase-wide grep confirms this function's own numeric formulas were never
# independently verified against real KK design data anywhere -- the class's existing golden tests
# only compare against previously-saved snapshot values, not a from-scratch reference. This file pins
# all 5 computed quantities against an independent from-scratch R computation, plus the m <= 1
# degenerate case (ssqD_bar becomes NA while d_bar itself, the mean of matched diffs, still computes).

test_that("d_bar/ssqD_bar/r_bar/ssqR/w_star match an independent from-scratch pooled-variance IVWC reference on real KK design data", {
	set.seed(1); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	KK <- priv$cached_values$KKstats

	yd <- KK$y_matched_diffs
	m <- length(yd)
	ref_d_bar <- mean(yd)
	ref_ssqD <- var(yd) / m

	yT <- KK$y_reservoir[KK$w_reservoir == 1]
	yC <- KK$y_reservoir[KK$w_reservoir == 0]
	nRT <- length(yT); nRC <- length(yC)
	ref_r_bar <- mean(yT) - mean(yC)
	sp2 <- (var(yT) * (nRT - 1) + var(yC) * (nRC - 1)) / (nRT + nRC - 2)
	ref_ssqR <- sp2 * (1 / nRT + 1 / nRC)
	ref_w_star <- ref_ssqR / (ref_ssqR + ref_ssqD)

	expect_equal(KK$d_bar, ref_d_bar, tolerance = 1e-10)
	expect_equal(KK$ssqD_bar, ref_ssqD, tolerance = 1e-10)
	expect_equal(KK$r_bar, ref_r_bar, tolerance = 1e-10)
	expect_equal(KK$ssqR, ref_ssqR, tolerance = 1e-10)
	expect_equal(KK$w_star, ref_w_star, tolerance = 1e-10)
})

test_that("m <= 1 leaves ssqD_bar (and downstream w_star) NA while d_bar itself still computes", {
	set.seed(2); n <- 30L
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rnorm(n) + 0.8 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllKKMeanDiffIVWC$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	priv$compute_reservoir_and_match_statistics()
	expected_d_bar <- priv$cached_values$KKstats$d_bar

	priv$cached_values$KKstats$m <- 1L
	priv$compute_reservoir_and_match_statistics()
	expect_true(is.na(priv$cached_values$KKstats$ssqD_bar))
	expect_true(is.na(priv$cached_values$KKstats$w_star))
	expect_equal(priv$cached_values$KKstats$d_bar, expected_d_bar)
})
