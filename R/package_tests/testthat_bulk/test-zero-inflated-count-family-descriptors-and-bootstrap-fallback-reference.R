library(testthat)
library(EDI)

# InferenceCountZeroInflatedPoisson: the family / description / estimand
# descriptors, and the asymptotic p-value and interval dispatch when the model
# SE is unavailable (NA with an edi_wald_unavailable_warning, v1.0.6-TODO-225;
# it used to fall back to the bootstrap), plus the marginal-estimand
# branch's use of the cached SE. Reference values are the Wald formulas.

zi_fx <- function(seed = 2L, n = 120L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- ifelse(runif(n) < 0.3, 0L, rpois(n, exp(0.5 + 0.3 * w + 0.2 * x)))
	des$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, n = n)
}

freeze_without_se <- function(f) {
	est <- f$inf$compute_estimate()
	f$p$cached_values$s_beta_hat_T <- NA_real_
	unlockBinding("compute_estimate", f$inf)
	f$inf$compute_estimate <- function(estimate_only = FALSE) est          # keep the SE unavailable
	unlockBinding("get_standard_error", f$p)
	f$p$get_standard_error <- function() NA_real_
	invisible(f)
}

test_that("descriptors: log-link Poisson family, model description and the three supported estimands", {
	f <- zi_fx()
	expect_equal(f$p$za_family()$family, "poisson")
	expect_equal(f$p$za_family()$link, "log")
	expect_equal(f$p$za_description(), "Zero-Inflated Poisson")
	expect_equal(f$p$get_supported_estimands_impl(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	expect_equal(f$inf$get_supported_estimands(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	expect_equal(f$inf$get_estimand(), "conditional")
	expect_error(f$inf$set_estimand("nonsense"))
})

test_that("with a finite SE the asymptotic outputs are the Wald formulas of the cached estimate and SE", {
	f <- zi_fx()
	est <- f$inf$compute_estimate()
	p0 <- f$inf$compute_asymp_two_sided_pval(0)
	se <- f$p$cached_values$s_beta_hat_T
	expect_true(is.finite(se) && se > 0)
	z <- est / se
	dfv <- f$p$cached_values$df
	ref_p <- if (is.finite(dfv)) 2 * pt(-abs(z), dfv) else 2 * pnorm(-abs(z))
	expect_equal(p0, ref_p, tolerance = 1e-8)
	crit <- if (is.finite(dfv)) qt(0.975, dfv) else qnorm(0.975)
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(0.05)), est + c(-1, 1) * crit * se, tolerance = 1e-8)
})

test_that("an unavailable SE gives NA and one edi_wald_unavailable_warning naming the class, never the bootstrap", {
	# v1.0.6-TODO-225: this used to fall back to the bootstrap with a warning naming the model.
	f <- zi_fx()
	freeze_without_se(f)
	unlockBinding("compute_bootstrap_confidence_interval", f$inf)
	unlockBinding("compute_bootstrap_two_sided_pval", f$inf)
	f$inf$compute_bootstrap_confidence_interval <- function(...) stop("bootstrap must not be called")
	f$inf$compute_bootstrap_two_sided_pval <- function(...) stop("bootstrap must not be called")
	expect_warning(ci <- f$inf$compute_asymp_confidence_interval(0.05), "InferenceCountZeroInflatedPoisson: the Wald",
		class = "edi_wald_unavailable_warning")
	expect_true(all(is.na(ci)))
	expect_equal(names(ci), c("2.5%", "97.5%"))
	pv <- f$inf$compute_asymp_two_sided_pval(0.2)
	expect_true(is.na(pv))
	expect_identical(f$p$cached_values$procedure_failure_reason$wald, "wald_standard_error_unavailable")
})

test_that("without bootstrap capability an unavailable SE gives the same NA outputs", {
	f <- zi_fx()
	freeze_without_se(f)
	unlockBinding("capabilities", f$inf)
	f$inf$capabilities <- function() character()
	expect_warning(pv <- f$inf$compute_asymp_two_sided_pval(0), class = "edi_wald_unavailable_warning")
	expect_true(is.na(pv))
	ci <- f$inf$compute_asymp_confidence_interval(0.1)
	expect_true(all(is.na(ci)))
	expect_equal(names(ci), c("5%", "95%"))
})

test_that("marginal estimands never fall back to the bootstrap: finite SE gives Wald output, missing SE gives NA", {
	f <- zi_fx()
	f$inf$set_estimand("marginal_mean_diff")
	est <- f$inf$compute_estimate()
	se <- f$p$cached_values$s_beta_hat_T
	skip_if(!is.finite(se))
	expect_equal(f$inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(est / se)), tolerance = 1e-8)
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(0.1)), est + c(-1, 1) * qnorm(0.95) * se, tolerance = 1e-8)
	f$p$cached_values$s_beta_hat_T <- NA_real_
	unlockBinding("compute_estimate", f$inf)
	f$inf$compute_estimate <- function(estimate_only = FALSE) est          # keep the SE unavailable
	expect_silent(pv <- f$inf$compute_asymp_two_sided_pval(0))
	expect_true(is.na(pv))
	ci <- f$inf$compute_asymp_confidence_interval(0.1)
	expect_true(all(is.na(ci)))
})
