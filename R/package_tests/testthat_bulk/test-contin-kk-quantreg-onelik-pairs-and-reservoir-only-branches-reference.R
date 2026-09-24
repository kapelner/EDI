library(testthat)
library(EDI)

# InferenceContinKKQuantileRegrOneLik's private shared_combined_likelihood()
# (inference_all_KK_quantile_regr_one_lik_abstract.R, shared with InferencePropKKQuantileRegrOneLik)
# has the same three-way matched-pairs/reservoir design-construction structure as the OLS/robust-regr
# OneLik siblings whose pairs-only/reservoir-only branches were closed the last two iterations. The
# combined (both present) branch and the fit-failure/nonestimable guards are already covered
# (test-kk-quantile-regr-one-lik-fit-and-coefficient-unavailable-guards-reference.R, migration-golden
# tests), but the matched-pairs-only and reservoir-only branches had no reference anywhere. Forced
# here by mutating the class's own already-cached KKstats partition to zero out the other source, same
# technique as the OLS/robust-regr siblings. Verified against an independently reconstructed
# quantreg::rq() call on the same stacked design the method itself builds (this is the class's own
# fitter, since quantile regression has no simple closed-form alternative reference -- the thing under
# test is the design-CONSTRUCTION logic, not the optimizer, exactly as for the OLS/robust siblings'
# lm.fit()/MASS::rlm() comparisons).
#   1. Matched-pairs-only (nRT forced to 0): a single-column ("trt__") design of the pair differences,
#      matching an independent quantreg::rq() call on the same stacked data exactly.
#   2. Reservoir-only (m forced to 0): an intercept+treatment(+covariates) design on reservoir rows
#      only, matching an independent quantreg::rq() call exactly.

qr_onelik_fixture <- function(seed, n = 60L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rnorm(n))
	inf <- InferenceContinKKQuantileRegrOneLik$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$compute_basic_match_data()
	list(inf = inf, priv = priv, KKstats = priv$cached_values$KKstats)
}

test_that("matched-pairs-only (no reservoir) matches an independent quantreg::rq() call on the pair-difference design exactly", {
	f <- qr_onelik_fixture(1L)
	expect_gt(f$KKstats$m, 0L)
	f$priv$cached_values$KKstats$nRT <- 0L                                         # force the pairs-only branch

	f$priv$shared_combined_likelihood(estimate_only = TRUE)
	Xd <- as.matrix(f$KKstats$X_matched_diffs)
	dat <- as.data.frame(cbind(trt__ = 1, Xd))
	dat$y_stack__ <- f$KKstats$yTs_matched - f$KKstats$yCs_matched
	ref <- suppressWarnings(quantreg::rq(y_stack__ ~ . - 1, tau = f$priv$tau, data = dat))
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[["trt__"]]), tolerance = 1e-8)
})

test_that("reservoir-only (no matched pairs) matches an independent quantreg::rq() call on the reservoir design exactly", {
	f <- qr_onelik_fixture(2L)
	expect_gt(f$KKstats$nRT, 0L)
	expect_gt(f$KKstats$nRC, 0L)
	f$priv$cached_values$KKstats$m <- 0L                                           # force the reservoir-only branch

	f$priv$shared_combined_likelihood(estimate_only = TRUE)
	X_r <- as.matrix(f$KKstats$X_reservoir)
	dat <- as.data.frame(cbind(intercept = 1, trt__ = f$KKstats$w_reservoir, X_r))
	dat$y_stack__ <- f$KKstats$y_reservoir
	ref <- suppressWarnings(quantreg::rq(y_stack__ ~ . - 1, tau = f$priv$tau, data = dat))
	expect_equal(f$priv$cached_values$beta_hat_T, unname(coef(ref)[["trt__"]]), tolerance = 1e-8)
})
