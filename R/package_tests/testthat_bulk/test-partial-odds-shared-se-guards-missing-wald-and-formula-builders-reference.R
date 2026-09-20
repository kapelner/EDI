library(testthat)
library(EDI)

# InferenceOrdinalPartialProportionalOddsRegr's control layer: ppo_fit_is_usable(),
# has_finite_se(), the shared() state machine (full success, estimate-only success,
# SE-unavailable and fit-unavailable branches, df = n - 1), missing_asymp_ci/pval
# under harden TRUE/FALSE, the Wald entry points (t critical values with n - 1 df,
# alias identity), get_standard_error / get_degrees_of_freedom and the two formula
# builders. The backend fits are stubbed so each branch is driven deterministically.

ppo_fx <- function(seed = 7L, n = 60L, harden = TRUE) {
	set.seed(seed)
	x1 <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x1))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- 1L + rowSums(matrix(runif(n), n, 3) > plogis(outer(0.5 * w + 0.4 * x1, c(-1, 0.5, 1.6), "-")))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalPartialProportionalOddsRegr$new(des, model_formula = ~x1, verbose = FALSE, harden = harden)
	list(inf = inf, p = inf$.__enclos_env__$private, n = n)
}

stub_fit <- function(f, fn) {
	unlockBinding("fit_partial_proportional_odds", f$p)
	f$p$fit_partial_proportional_odds <- fn
	f
}

test_that("ppo_fit_is_usable requires a finite beta, and a positive finite SE only on request", {
	p <- ppo_fx()$p
	u <- p$ppo_fit_is_usable
	expect_false(u(NULL))
	expect_true(u(list(beta = 0.3, se = NA_real_)))
	expect_false(u(list(beta = 0.3, se = NA_real_), require_se = TRUE))
	expect_false(u(list(beta = 0.3, se = 0), require_se = TRUE))
	expect_false(u(list(beta = NA_real_, se = 1), require_se = FALSE))
	expect_false(u(list(beta = Inf, se = 1)))
	expect_true(u(list(beta = -2, se = 0.1), require_se = TRUE))
})

test_that("has_finite_se reads the cached SE: positive and finite only", {
	p <- ppo_fx()$p
	for (v in list(0.2, 1e-9)) { p$cached_values$s_beta_hat_T <- v; expect_true(p$has_finite_se()) }
	for (v in list(0, -1, NA_real_, Inf)) { p$cached_values$s_beta_hat_T <- v; expect_false(p$has_finite_se()) }
})

test_that("shared(): a fit with beta and SE caches estimate, SE and df = n - 1 and clears nonestimable state", {
	f <- ppo_fx()
	seen <- NULL
	stub_fit(f, function(require_se = FALSE) { seen <<- c(seen, require_se); list(beta = 0.6, se = 0.2) })
	f$p$shared(FALSE)
	expect_equal(c(f$p$cached_values$beta_hat_T, f$p$cached_values$s_beta_hat_T, f$p$cached_values$df), c(0.6, 0.2, f$n - 1))
	expect_false(f$inf$is_nonestimable("any"))
	expect_identical(seen, TRUE)                                           # SE required for a full request
	f$p$shared(FALSE)                                                      # cached: no second fit
	expect_length(seen, 1L)
	g <- ppo_fx(); seen <- NULL
	stub_fit(g, function(require_se = FALSE) { seen <<- c(seen, require_se); list(beta = 0.6, se = NA_real_) })
	g$p$shared(TRUE)
	expect_identical(seen, FALSE)
	expect_equal(g$p$cached_values$beta_hat_T, 0.6)
	expect_false(g$inf$is_nonestimable("any"))                             # estimate_only never flags the SE
})

test_that("shared(): estimate succeeds without an SE -> estimate kept, SE flagged unavailable", {
	f <- ppo_fx()
	stub_fit(f, function(require_se = FALSE) if (require_se) NULL else list(beta = 0.4, se = NA_real_))
	f$p$shared(FALSE)
	expect_equal(f$p$cached_values$beta_hat_T, 0.4)
	expect_equal(f$p$cached_values$df, f$n - 1)
	expect_true(f$inf$is_nonestimable("se"))
	expect_false(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "ppor_standard_error_unavailable")

	g <- ppo_fx()                                                          # fit with beta but zero SE
	stub_fit(g, function(require_se = FALSE) list(beta = 0.4, se = 0))
	g$p$shared(FALSE)
	expect_true(g$inf$is_nonestimable("se"))
	expect_equal(g$p$cached_values$beta_hat_T, 0.4)
})

test_that("shared(): no usable fit -> estimate nonestimable with ppor_fit_unavailable (df still set for full requests)", {
	f <- ppo_fx()
	stub_fit(f, function(require_se = FALSE) NULL)
	f$p$shared(FALSE)
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "ppor_fit_unavailable")
	expect_equal(f$p$cached_values$df, f$n - 1)
	expect_true(is.na(f$p$cached_values$beta_hat_T))
	g <- ppo_fx()
	stub_fit(g, function(require_se = FALSE) list(beta = NA_real_, se = 1))
	g$p$shared(TRUE)
	expect_identical(g$inf$get_nonestimable_reason(), "ppor_fit_unavailable")
})

test_that("Wald p-value and CI use t(n - 1) with the model SE; asymptotic and Wald entry points are identical", {
	f <- ppo_fx()
	stub_fit(f, function(require_se = FALSE) list(beta = 0.6, se = 0.2))
	df <- f$n - 1
	expect_equal(f$inf$compute_asymp_two_sided_pval(0.1), 2 * pt(-abs((0.6 - 0.1) / 0.2), df), tolerance = 1e-10)
	expect_equal(as.numeric(f$inf$compute_asymp_confidence_interval(0.1)), 0.6 + c(-1, 1) * qt(0.95, df) * 0.2, tolerance = 1e-10)
	expect_equal(f$inf$compute_wald_two_sided_pval(0.1), f$inf$compute_asymp_two_sided_pval(0.1))
	expect_equal(f$inf$compute_wald_confidence_interval(0.1), f$inf$compute_asymp_confidence_interval(0.1))
	expect_equal(f$p$get_standard_error(), 0.2)
	expect_equal(f$p$get_degrees_of_freedom(), df)
	expect_error(f$inf$compute_asymp_confidence_interval(alpha = 0))
	expect_error(f$inf$compute_asymp_two_sided_pval(delta = "a"))
})

test_that("without a finite SE, hardened objects return NA / named NA interval and flag it; unhardened objects stop", {
	for (fn in c("compute_asymp_two_sided_pval", "compute_wald_two_sided_pval")) {
		f <- ppo_fx()
		stub_fit(f, function(require_se = FALSE) if (require_se) NULL else list(beta = 0.4, se = NA_real_))
		expect_true(is.na(f$inf[[fn]](0)), info = fn)
		expect_identical(f$inf$get_nonestimable_reason(), "ppor_standard_error_unavailable")
		u <- ppo_fx(harden = FALSE)
		stub_fit(u, function(require_se = FALSE) if (require_se) NULL else list(beta = 0.4, se = NA_real_))
		expect_error(u$inf[[fn]](0), "could not compute a finite model-based standard error", info = fn)
	}
	for (fn in c("compute_asymp_confidence_interval", "compute_wald_confidence_interval")) {
		f <- ppo_fx()
		stub_fit(f, function(require_se = FALSE) if (require_se) NULL else list(beta = 0.4, se = NA_real_))
		ci <- f$inf[[fn]](alpha = 0.1)
		expect_true(all(is.na(ci)), info = fn)
		expect_equal(names(ci), c("5%", "95%"), info = fn)
		u <- ppo_fx(harden = FALSE)
		stub_fit(u, function(require_se = FALSE) NULL)
		expect_error(u$inf[[fn]](0.1), "finite model-based standard error", info = fn)
	}
	f <- ppo_fx()
	expect_true(is.na(f$p$missing_asymp_pval("custom_reason")))
	expect_identical(f$inf$get_nonestimable_reason(), "custom_reason")
	expect_equal(names(f$p$missing_asymp_ci(0.2, "other")), c("10%", "90%"))
	expect_identical(f$inf$get_nonestimable_reason(), "other")
})

test_that("formula builders put the response first (main) or omit it (parallel)", {
	p <- ppo_fx()$p
	expect_equal(deparse(p$main_formula(c("treatment", "x1", "x2"))), "y ~ treatment + x1 + x2")
	expect_equal(deparse(p$parallel_formula(c("treatment", "x1"))), "~treatment + x1")
	expect_length(all.vars(p$parallel_formula("a")), 1L)
	expect_equal(all.vars(p$main_formula("a")), c("y", "a"))
})

test_that("weighted estimate: constant weights reuse the unweighted estimate with the SE dropped; otherwise the weighted fit is used", {
	f <- ppo_fx()
	est <- f$inf$compute_estimate()
	f$p$current_bayesian_bootstrap_context <- f$p$build_bayesian_bootstrap_context()
	K <- f$p$current_bayesian_bootstrap_context$n_units
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rep(2, K)), est, tolerance = 1e-8)
	expect_true(is.na(f$p$weighted_refit_se()))
	unlockBinding("fit_partial_proportional_odds_from_covariates_weighted", f$p)
	got <- NULL
	f$p$fit_partial_proportional_odds_from_covariates_weighted <- function(X_cov, row_weights) { got <<- list(X_cov, row_weights); list(beta = 9.5) }
	set.seed(3); wts <- rexp(K)
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(wts), 9.5)
	expect_equal(got[[2]], wts)
	expect_equal(colnames(got[[1]]), "x1")
	expect_true(is.na(f$p$weighted_refit_se()))
	f$p$fit_partial_proportional_odds_from_covariates_weighted <- function(X_cov, row_weights) NULL
	expect_true(is.na(f$inf$compute_estimate_with_bootstrap_weights(wts)))
})
