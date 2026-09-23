library(testthat)
library(EDI)

# InferenceCountKKCondPoissonOneLik's shared_combined_cpoisson()/try_combined_fit()/try_pairs_only()/
# try_reservoir_only() cascade (inference_count_KK_cond_poisson.R) had no direct test reference
# anywhere -- test-kk-cond-poisson-onelik-combined-data-likelihood-and-fit-reference.R already covers
# the underlying combined-fit LIKELIHOOD/score/fitter (fit_combined_cpoisson()) closely, but never the
# three-way dispatch cascade shared_combined_cpoisson() drives: try a combined matched+reservoir fit
# first, then fall back to matched-pairs-only, then reservoir-only, failing only when none of the
# three can produce a usable fit.
#   1. With both matched pairs and reservoir subjects, try_combined_fit() succeeds and is used; its
#      point estimate matches self$compute_estimate()'s own cached value (dispatch wiring check).
#   2. try_pairs_only(), called in isolation on matched-pair proportion data, matches an independent
#      weighted logistic regression (glm(y_prop ~ ., family=binomial, weights=n_k)) exactly.
#   3. try_reservoir_only(), called in isolation on reservoir count data, matches an independent
#      glm(y ~ w + X, family=poisson()) exactly -- including its own QR-rank-deficiency reduction
#      when a covariate is exactly collinear with another (the reduced fit matches glm() on only the
#      surviving covariates).
#   4. When try_combined_fit() fails, the cascade falls back to try_pairs_only() (still matching the
#      isolated try_pairs_only() reference above).
#   5. Both try_pairs_only() and try_reservoir_only() return FALSE (not an error) on empty input, the
#      exact condition under which the cascade's final "neither fallback worked" guard fires.

cond_pois_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rpois(n, 3))
	inf <- InferenceCountKKCondPoissonOneLik$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv)
}

cond_pois_cascade_inputs <- function(priv) {
	KKstats <- priv$cached_values$KKstats
	yT <- KKstats$yTs_matched; yC <- KKstats$yCs_matched
	n_k <- yT + yC
	valid <- which(n_k > 0)
	list(
		yT_v = yT[valid], n_k_v = n_k[valid],
		X_diff_v = as.matrix(KKstats$X_matched_diffs_full[valid, , drop = FALSE]),
		y_r_v = KKstats$y_reservoir, w_r_v = KKstats$w_reservoir,
		X_r_v = as.matrix(KKstats$X_reservoir)
	)
}

test_that("with both matched pairs and reservoir subjects, try_combined_fit() succeeds and matches self$compute_estimate()'s cached value", {
	f <- cond_pois_fixture(1L)
	main_est <- as.numeric(f$inf$compute_estimate())[1L]
	inputs <- cond_pois_cascade_inputs(f$priv)
	expect_gt(length(inputs$yT_v), 0L)
	expect_gt(length(inputs$y_r_v), 0L)

	f$priv$cached_values$beta_hat_T <- NULL
	success <- do.call(f$priv$try_combined_fit, c(list(estimate_only = TRUE), inputs))
	expect_true(success)
	expect_equal(f$priv$cached_values$beta_hat_T, main_est)
})

test_that("try_pairs_only(), in isolation, matches an independent weighted logistic regression exactly", {
	f <- cond_pois_fixture(2L)
	inputs <- cond_pois_cascade_inputs(f$priv)
	y_prop <- inputs$yT_v / inputs$n_k_v
	X <- cbind(1, inputs$X_diff_v)
	ref <- glm(y_prop ~ X - 1, family = binomial(), weights = inputs$n_k_v)

	success <- f$priv$try_pairs_only(TRUE, inputs$yT_v, inputs$n_k_v, inputs$X_diff_v)
	expect_true(success)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[1]), tolerance = 1e-6)
})

test_that("try_reservoir_only(), in isolation, matches an independent glm(poisson) exactly, including its QR rank-deficiency reduction", {
	f <- cond_pois_fixture(3L)
	inputs <- cond_pois_cascade_inputs(f$priv)
	y_r_v <- inputs$y_r_v; w_r_v <- inputs$w_r_v; X_r_v <- inputs$X_r_v

	X_full <- cbind(1, w_r_v, X_r_v)
	ref <- glm(y_r_v ~ X_full - 1, family = poisson())
	success <- f$priv$try_reservoir_only(TRUE, y_r_v, w_r_v, X_r_v)
	expect_true(success)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[2]), tolerance = 1e-6)

	set.seed(9L); n_r <- length(y_r_v)
	x1 <- rnorm(n_r); x2 <- 2 * x1                                                  # exactly collinear -> rank deficient
	X_r_collinear <- cbind(x1 = x1, x2 = x2)
	ref_reduced <- glm(y_r_v ~ w_r_v + x1, family = poisson())
	success2 <- f$priv$try_reservoir_only(TRUE, y_r_v, w_r_v, X_r_collinear)
	expect_true(success2)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref_reduced)["w_r_v"]), tolerance = 1e-6)
})

test_that("when try_combined_fit() fails, the cascade falls back to try_pairs_only(), matching that isolated reference", {
	f <- cond_pois_fixture(4L)
	inputs <- cond_pois_cascade_inputs(f$priv)
	y_prop <- inputs$yT_v / inputs$n_k_v
	X <- cbind(1, inputs$X_diff_v)
	ref <- glm(y_prop ~ X - 1, family = binomial(), weights = inputs$n_k_v)

	unlockBinding("try_combined_fit", f$priv)
	f$priv$try_combined_fit <- function(...) FALSE                                 # force the combined attempt to fail
	f$priv$cached_values$beta_hat_T <- NULL
	f$priv$cached_values$combined_cov_keep <- NULL

	f$priv$shared_combined_cpoisson(estimate_only = TRUE)
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[1]), tolerance = 1e-6)
})

test_that("both try_pairs_only() and try_reservoir_only() return FALSE (not an error) on empty input", {
	f <- cond_pois_fixture(5L)
	expect_false(f$priv$try_pairs_only(TRUE, numeric(0), numeric(0), matrix(nrow = 0, ncol = 0)))
	expect_false(f$priv$try_reservoir_only(TRUE, numeric(0), numeric(0), matrix(nrow = 0, ncol = 0)))
})
