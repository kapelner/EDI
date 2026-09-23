library(testthat)
library(EDI)

# Three distinct KK OneLik classes' combined-likelihood fitters (InferenceContinKKOLSOneLik's
# fit_combined(), InferenceContinKKRobustRegrOneLik's fit_combined(), and
# InferenceContinKKQuantileRegrOneLik's shared_combined_likelihood(), all inheriting/composing the
# shared KK-compound machinery -- the IVWC compound estimators are out of scope for this suite) share
# the exact same final-else "no_usable_matched_or_reservoir_data" guard: fired when there are no
# matched pairs (m == 0) AND the reservoir doesn't contain both treatment and control subjects
# (nRT == 0 or nRC == 0). This had no test reference anywhere for any of the three classes. Reached
# by letting compute_basic_match_data() populate a genuine KKstats object from real data, then
# directly zeroing out its m/nRT/nRC fields before calling the private fitter -- avoids hand-building
# the full KKstats structure while still exercising the real guard code path.

kk_fixture <- function(cls, seed = 1L, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$add_all_subject_responses(rnorm(n) + des$get_w())
	inf <- cls$new(des, verbose = FALSE)
	p <- inf$.__enclos_env__$private
	p$compute_basic_match_data()
	stopifnot(!is.null(p$cached_values$KKstats))
	p$cached_values$KKstats$m <- 0L
	p$cached_values$KKstats$nRT <- 0L
	p$cached_values$KKstats$nRC <- 0L
	list(inf = inf, p = p)
}

test_that("InferenceContinKKOLSOneLik's fit_combined() caches 'no_usable_matched_or_reservoir_data'", {
	f <- kk_fixture(InferenceContinKKOLSOneLik)
	f$p$fit_combined(estimate_only = TRUE)
	expect_identical(f$inf$get_nonestimable_reason(), "no_usable_matched_or_reservoir_data")
})

test_that("InferenceContinKKRobustRegrOneLik's fit_combined() caches 'no_usable_matched_or_reservoir_data'", {
	f <- kk_fixture(InferenceContinKKRobustRegrOneLik, seed = 2L)
	f$p$fit_combined(estimate_only = TRUE)
	expect_identical(f$inf$get_nonestimable_reason(), "no_usable_matched_or_reservoir_data")
})

test_that("InferenceContinKKQuantileRegrOneLik's shared_combined_likelihood() caches 'no_usable_matched_or_reservoir_data'", {
	f <- kk_fixture(InferenceContinKKQuantileRegrOneLik, seed = 3L)
	f$p$shared_combined_likelihood(estimate_only = TRUE)
	expect_identical(f$inf$get_nonestimable_reason(), "no_usable_matched_or_reservoir_data")
})
