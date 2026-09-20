library(testthat)
library(EDI)

# InferenceAsymp: compute_z_or_t_ci_from_s_and_df / compute_z_or_t_two_sided_pval_from_s_and_df
# (cached estimate, SE, df) and compute_wald_confidence_interval_impl / compute_wald_two_sided_pval_impl
# (fresh estimate, SE, df through the accessors). References: qt / qnorm / pt / pnorm by
# hand; z is used when df is missing, NA or infinite; guards return NA for bad estimate / SE.

fx <- function() {
	set.seed(2)
	n <- 40L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	inf <- InferenceIncidLogRegr$new(des, verbose = FALSE)
	inf
}
priv_of <- function(inf) inf$.__enclos_env__$private
set_cache <- function(p, est, se, df = NULL) {
	p$cached_values$beta_hat_T <- est
	p$cached_values$s_beta_hat_T <- se
	p$cached_values$df <- df
}

test_that("cached-values CI uses t quantiles for finite df, z for missing / NA / infinite df, and names the bounds", {
	p <- priv_of(fx())
	set_cache(p, 1.5, 0.4, 12)
	ci <- p$compute_z_or_t_ci_from_s_and_df(0.1)
	expect_equal(unname(ci), 1.5 + c(-1, 1) * qt(0.95, 12) * 0.4)
	expect_equal(names(ci), c("5%", "95%"))
	for (df in list(NULL, NA_real_, Inf)) {
		set_cache(p, 1.5, 0.4, df)
		expect_equal(unname(p$compute_z_or_t_ci_from_s_and_df(0.05)), 1.5 + c(-1, 1) * qnorm(0.975) * 0.4)
	}
})

test_that("cached-values p-value is two-sided t (finite df) or z, and symmetric in the sign of the deviation", {
	p <- priv_of(fx())
	set_cache(p, 1.5, 0.4, 9)
	expect_equal(p$compute_z_or_t_two_sided_pval_from_s_and_df(0.5), 2 * pt(-abs(1 / 0.4), 9))
	expect_equal(p$compute_z_or_t_two_sided_pval_from_s_and_df(2.5), p$compute_z_or_t_two_sided_pval_from_s_and_df(0.5))
	set_cache(p, 1.5, 0.4, NULL)
	expect_equal(p$compute_z_or_t_two_sided_pval_from_s_and_df(0.5), 2 * pnorm(-abs(1 / 0.4)))
	expect_equal(p$compute_z_or_t_two_sided_pval_from_s_and_df(1.5), 1)
})

test_that("bad cached estimate or SE (wrong length, non-finite, non-positive) gives NA outputs", {
	p <- priv_of(fx())
	for (bad in list(list(NA_real_, 0.4), list(1, NA_real_), list(1, 0), list(1, -0.2), list(Inf, 0.4), list(c(1, 2), 0.4), list(1, c(0.1, 0.2)), list(numeric(0), 0.4))) {
		set_cache(p, bad[[1]], bad[[2]], 5)
		expect_equal(unname(p$compute_z_or_t_ci_from_s_and_df(0.05)), c(NA_real_, NA_real_))
		expect_true(is.na(p$compute_z_or_t_two_sided_pval_from_s_and_df(0)))
	}
})

test_that("Wald impls use the estimate, SE and df accessors: t for finite df, z otherwise", {
	inf <- fx(); p <- priv_of(inf)
	self_env <- inf
	for (nm in c("get_standard_error", "get_degrees_of_freedom")) unlockBinding(nm, p)
	unlockBinding("compute_estimate", self_env)
	self_env$compute_estimate <- function(estimate_only = FALSE) 2
	p$get_standard_error <- function() 0.5
	p$get_degrees_of_freedom <- function() 20
	ci <- p$compute_wald_confidence_interval_impl(0.05)
	expect_equal(unname(ci), 2 + c(-1, 1) * qt(0.975, 20) * 0.5)
	expect_equal(names(ci), c("2.5%", "97.5%"))
	expect_equal(p$compute_wald_two_sided_pval_impl(1), 2 * pt(-2, 20))
	p$get_degrees_of_freedom <- function() Inf
	expect_equal(unname(p$compute_wald_confidence_interval_impl(0.05)), 2 + c(-1, 1) * qnorm(0.975) * 0.5)
	expect_equal(p$compute_wald_two_sided_pval_impl(1), 2 * pnorm(-2))
})

test_that("Wald impls return NA for a non-finite estimate or an unusable SE", {
	inf <- fx(); p <- priv_of(inf)
	self_env <- inf
	for (nm in c("get_standard_error", "get_degrees_of_freedom")) unlockBinding(nm, p)
	unlockBinding("compute_estimate", self_env)
	p$get_degrees_of_freedom <- function() Inf
	for (case in list(list(NA_real_, 0.5), list(2, NA_real_), list(2, 0), list(2, -1), list(c(1, 2), 0.5))) {
		self_env$compute_estimate <- local({ v <- case[[1]]; function(estimate_only = FALSE) v })
		p$get_standard_error <- local({ v <- case[[2]]; function() v })
		expect_equal(unname(p$compute_wald_confidence_interval_impl(0.05)), c(NA_real_, NA_real_))
		expect_true(is.na(p$compute_wald_two_sided_pval_impl(0)))
	}
})
