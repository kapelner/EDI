library(testthat)
library(EDI)

# InferenceCountZeroInflatedPoisson's asymptotic CI / p-value dispatch when the
# standard error is available, unavailable (bootstrap fallback with a warning),
# unavailable on a design without nonparametric-bootstrap support (NA, no
# fallback), or blocked by the count-likelihood guard, under both the
# conditional and marginal estimands. Existing tests only run the happy path.
# The state each branch keys on is forced with stubs on a real fitted object.

zip_fixture <- function(seed = 4L, n = 100L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- ifelse(runif(n) < 0.3, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.2 * x)))
	des$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedPoisson$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

stub_private <- function(priv, name, fn) {
	unlockBinding(name, priv)
	assign(name, fn, envir = priv)
}

stub_public <- function(inf, name, fn) {
	unlockBinding(name, inf)
	assign(name, fn, envir = inf)
}

ref_z_or_t <- function(priv, est, alpha = 0.05) {
	s <- priv$cached_values$s_beta_hat_T
	df <- priv$cached_values$df
	mult <- if (is.null(df) || !is.finite(df)) qnorm(1 - alpha / 2) else qt(1 - alpha / 2, df)
	c(est - mult * s, est + mult * s)
}

test_that("with an available SE the conditional CI and p-value are the z/t Wald formulas", {
	f <- zip_fixture()
	est <- f$inf$compute_estimate()
	ci <- f$inf$compute_asymp_confidence_interval()
	expect_equal(as.numeric(ci), ref_z_or_t(f$priv, est), tolerance = 1e-10)
	s <- f$priv$cached_values$s_beta_hat_T
	df <- f$priv$cached_values$df
	z <- est / s
	ref_p <- if (is.null(df) || !is.finite(df)) 2 * pnorm(-abs(z)) else 2 * pt(-abs(z), df)
	expect_equal(f$inf$compute_asymp_two_sided_pval(), ref_p, tolerance = 1e-10)
	expect_equal(f$inf$compute_asymp_two_sided_pval(delta = est), 1, tolerance = 1e-8)
})

test_that("an unavailable SE falls back to the bootstrap with a warning", {
	f <- zip_fixture()
	est <- f$inf$compute_estimate()
	stub_private(f$priv, "get_standard_error", function() NA_real_)
	stub_public(f$inf, "compute_estimate", function(estimate_only = FALSE) {
		f$priv$cached_values$s_beta_hat_T <- NA_real_
		est
	})
	calls <- list()
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(alpha = 0.05, ...) {
		calls$ci <<- alpha
		c(-9, 9)
	})
	stub_public(f$inf, "compute_bootstrap_two_sided_pval", function(delta = 0, na.rm = FALSE, ...) {
		calls$pval <<- list(delta = delta, na.rm = na.rm)
		0.123
	})

	expect_warning(ci <- f$inf$compute_asymp_confidence_interval(alpha = 0.1), "Zero-Inflated Poisson: falling back to bootstrap")
	expect_equal(ci, c(-9, 9))
	expect_equal(calls$ci, 0.1)

	expect_warning(p <- f$inf$compute_asymp_two_sided_pval(delta = 0.2), "falling back to bootstrap")
	expect_equal(p, 0.123)
	expect_equal(calls$pval$delta, 0.2)
	expect_true(calls$pval$na.rm)
})

test_that("without nonparametric-bootstrap support the unavailable-SE case returns NA without a fallback", {
	f <- zip_fixture()
	est <- f$inf$compute_estimate()
	stub_private(f$priv, "get_standard_error", function() NA_real_)
	stub_public(f$inf, "compute_estimate", function(estimate_only = FALSE) {
		f$priv$cached_values$s_beta_hat_T <- NA_real_
		est
	})
	stub_public(f$inf, "capabilities", function() setdiff(c("wald", "jackknife", "nonparametric_bootstrap"), "nonparametric_bootstrap"))
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(...) stop("bootstrap must not be called"))
	stub_public(f$inf, "compute_bootstrap_two_sided_pval", function(...) stop("bootstrap must not be called"))

	expect_no_warning(ci <- f$inf$compute_asymp_confidence_interval())
	expect_length(ci, 2L)
	expect_true(all(is.na(ci)))
	expect_no_warning(p <- f$inf$compute_asymp_two_sided_pval())
	expect_true(is.na(p))
})

test_that("a finite get_standard_error() repopulates a missing cached SE before the Wald formula", {
	f <- zip_fixture()
	est <- f$inf$compute_estimate()
	stub_private(f$priv, "get_standard_error", function() 0.5)
	stub_public(f$inf, "compute_estimate", function(estimate_only = FALSE) {
		f$priv$cached_values$s_beta_hat_T <- NA_real_
		est
	})
	ci <- f$inf$compute_asymp_confidence_interval()
	expect_equal(f$priv$cached_values$s_beta_hat_T, 0.5)
	expect_equal(as.numeric(ci), ref_z_or_t(f$priv, est), tolerance = 1e-10)
})

test_that("the count-likelihood guard makes both asymptotic outputs unavailable", {
	f <- zip_fixture()
	f$inf$compute_estimate()
	stub_private(f$priv, "mark_count_likelihood_block_asymp_nonestimable", function() TRUE)
	ci <- f$inf$compute_asymp_confidence_interval()
	expect_true(all(is.na(ci)))
	expect_true(is.na(f$inf$compute_asymp_two_sided_pval()))
})

test_that("marginal estimands use the cached SE when finite and are unavailable (no fallback) when not", {
	f <- zip_fixture()
	f$inf$set_estimand("marginal_mean_diff")
	est <- f$inf$compute_estimate()
	s <- f$priv$cached_values$s_beta_hat_T
	expect_true(is.finite(s) && s > 0)
	ci <- f$inf$compute_asymp_confidence_interval()
	expect_equal(as.numeric(ci), ref_z_or_t(f$priv, est), tolerance = 1e-10)
	z <- est / s
	df <- f$priv$cached_values$df
	ref_p <- if (is.null(df) || !is.finite(df)) 2 * pnorm(-abs(z)) else 2 * pt(-abs(z), df)
	expect_equal(f$inf$compute_asymp_two_sided_pval(), ref_p, tolerance = 1e-10)

	stub_public(f$inf, "compute_estimate", function(estimate_only = FALSE) {
		f$priv$cached_values$s_beta_hat_T <- NA_real_
		est
	})
	stub_public(f$inf, "compute_bootstrap_confidence_interval", function(...) stop("bootstrap must not be called"))
	expect_true(all(is.na(f$inf$compute_asymp_confidence_interval())))
	expect_true(is.na(f$inf$compute_asymp_two_sided_pval()))
})
