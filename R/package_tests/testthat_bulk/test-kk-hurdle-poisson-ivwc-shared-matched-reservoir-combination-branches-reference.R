library(testthat)
library(EDI)

# InferenceCountKKHurdlePoissonIVWC's private shared() (inference_count_KK_cond_poisson.R) combines
# a hurdle-Poisson-GLMM fit on the matched pairs (fit_hurdle_for_matched_pairs(), returning
# list(beta_hat=, se=)) and a standard Poisson fit on the reservoir (fit_poisson_for_reservoir(),
# returning list(beta_hat=, ssq_hat=)) via inverse-variance weighting -- the same IVWC-combination
# pattern already closed this stretch for several sibling classes, including a
# cache_nonestimable_estimate("kk_hurdle_poisson_ivwc_no_usable_component") guard when neither piece
# succeeds. The class's only reference to these two private methods anywhere
# (test-proportion-count-family-contracts.R) merely asserts they EXIST as private methods on the
# class (`"fit_hurdle_for_matched_pairs" %in% names(...$private_methods)`), never actually exercising
# any of shared()'s 4 branches -- confirmed via grep that no test calls either method or checks the
# "no_usable_component" reason string. Reached by unlockBinding-replacing both private methods with
# stubs returning exact beta/variance values, independent of the real hurdle-GLMM/Poisson-fitting
# machinery (already tested via the class's golden/migration files).

mk_fixture <- function(seed, n = 20L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rpois(n, exp(0.3 * w))
	des$add_all_subject_responses(y)
	inf <- InferenceCountKKHurdlePoissonIVWC$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

set_mocks <- function(priv, beta_m, se_m, beta_r, ssq_r) {
	unlockBinding("fit_hurdle_for_matched_pairs", priv)
	priv$fit_hurdle_for_matched_pairs <- function(...) list(beta_hat = beta_m, se = se_m)
	unlockBinding("fit_poisson_for_reservoir", priv)
	priv$fit_poisson_for_reservoir <- function(...) list(beta_hat = beta_r, ssq_hat = ssq_r)
}

test_that("only the matched-pairs (hurdle-GLMM) piece succeeds: beta_hat_T = beta_m, s_beta_hat_T = se_m", {
	f <- mk_fixture(1L)
	set_mocks(f$priv, 1.2, sqrt(0.2), NA_real_, NA_real_)
	est <- f$inf$compute_estimate()
	expect_equal(est, 1.2)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2))
})

test_that("only the reservoir (Poisson) piece succeeds: beta_hat_T = beta_r, s_beta_hat_T = sqrt(ssq_r)", {
	f <- mk_fixture(2L)
	set_mocks(f$priv, NA_real_, NA_real_, 0.8, 0.5)
	est <- f$inf$compute_estimate()
	expect_equal(est, 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.5))
})

test_that("both pieces succeed: the IVWC combination matches the closed-form weighted formula exactly", {
	f <- mk_fixture(3L)
	set_mocks(f$priv, 1.2, sqrt(0.2), 0.8, 0.5)
	est <- f$inf$compute_estimate()
	w_star <- 0.5 / (0.5 + 0.2)
	expect_equal(est, w_star * 1.2 + (1 - w_star) * 0.8)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(0.2 * 0.5 / (0.2 + 0.5)))
})

test_that("neither piece succeeds: the estimate is nonestimable with the exact documented reason", {
	f <- mk_fixture(4L)
	set_mocks(f$priv, NA_real_, NA_real_, NA_real_, NA_real_)
	est <- f$inf$compute_estimate()
	expect_true(is.na(est))
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_equal(f$inf$get_nonestimable_reason(), "kk_hurdle_poisson_ivwc_no_usable_component")
})
