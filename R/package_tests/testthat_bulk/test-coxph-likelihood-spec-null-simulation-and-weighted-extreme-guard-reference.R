library(testthat)
library(EDI)
library(survival)

# InferenceSurvivalCoxPHRegr's get_likelihood_test_spec() closures (score,
# observed information, neg-log-likelihood, constrained null fit) against
# survival::coxph, simulate_under_lik_null()'s guard/shape, the weighted
# bootstrap estimate (incl. the extreme-coefficient guard) and the use_rcpp
# capability toggles. Continuous survival times, so there are no ties and
# Breslow / Efron partial likelihoods coincide.

cox_fx <- function(seed = 3L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t <- rexp(n, exp(0.5 * w + 0.3 * x)); d <- rbinom(n, 1, 0.8)
	des$add_all_subject_responses(ifelse(d == 1, t, NA), ifelse(d == 1, NA, t), ifelse(d == 1, NA, Inf))
	inf <- InferenceSurvivalCoxPHRegr$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, t = t, d = d, w = w, x = x, n = n)
}

test_that("spec closures reproduce the coxph fit, score, information and constrained null fit", {
	f <- cox_fx()
	ref <- coxph(Surv(f$t, f$d) ~ f$w + f$x)
	sp <- f$p$get_likelihood_test_spec()
	expect_equal(sp$j, 1L)
	expect_equal(as.numeric(sp$full_fit$b), unname(coef(ref)), tolerance = 1e-6)
	expect_equal(sp$neg_loglik(sp$full_fit), -as.numeric(logLik(ref)), tolerance = 1e-6)
	expect_true(all(abs(sp$score(sp$full_fit)) < 1e-6))
	expect_equal(unname(sp$observed_information(sp$full_fit)), unname(solve(vcov(ref))), tolerance = 1e-5)
	expect_equal(unname(sp$information(sp$full_fit)), unname(solve(vcov(ref))), tolerance = 1e-5)
	expect_equal(sp$extract_start(sp$full_fit), unname(coef(ref)), tolerance = 1e-6)

	nf <- sp$fit_null(0.2)
	ref0 <- coxph(Surv(f$t, f$d) ~ f$x + offset(0.2 * f$w))
	expect_equal(nf$b, c(0.2, unname(coef(ref0))), tolerance = 1e-5)
	expect_equal(sp$neg_loglik(nf), -as.numeric(logLik(ref0)), tolerance = 1e-5)
	# Score at the null fit: only the constrained coordinate is non-zero; equals the coxph score of that offset model.
	sc <- sp$score(nf)
	expect_equal(sc[2], 0, tolerance = 1e-5)
	# LR statistic implied by the spec is the classical partial-likelihood ratio.
	expect_equal(2 * (sp$neg_loglik(nf) - sp$neg_loglik(sp$full_fit)),
		2 * (as.numeric(logLik(ref)) - as.numeric(logLik(ref0))), tolerance = 1e-5)
	# Fisher information defaults to the observed information when the fit carries none.
	bare <- list(b = nf$b)
	expect_equal(sp$fisher_information(bare), sp$observed_information(bare))
	expect_equal(sp$information(bare), sp$observed_information(bare))
	expect_equal(sp$information(list(b = nf$b, information = diag(2))), diag(2))
})

test_that("simulate_under_lik_null returns NULL for a non-finite null fit and otherwise a usable bootstrap spec", {
	f <- cox_fx()
	sp <- f$p$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	expect_null(f$p$simulate_under_lik_null(sp, 0, list(b = c(NA_real_, 0))))
	set.seed(5)
	sim <- f$p$simulate_under_lik_null(sp, 0, nf)
	skip_if(is.null(sim), "simulated replicate did not converge for this seed")
	expect_setequal(names(sim), c("full_fit", "fit_null", "neg_loglik"))
	expect_length(sim$full_fit$b, 2L)
	expect_equal(sim$neg_loglik(list(neg_loglik = 3.5)), 3.5)
	n1 <- sim$fit_null(0)
	expect_equal(n1$b[1], 0)
	# The replicate's own LR statistic is non-negative.
	expect_gte(sim$neg_loglik(n1) - sim$neg_loglik(sim$full_fit), -1e-8)
})

test_that("capability flags follow use_rcpp; Bartlett approximation is always off", {
	f <- cox_fx()
	expect_true(f$p$supports_likelihood_tests())
	expect_true(f$p$supports_lik_ratio_param_bootstrap())
	expect_false(f$p$supports_bartlett_likelihood_ratio_approx())
	expect_true(f$p$supports_interval_or_left_censored_data())
	f$p$use_rcpp <- FALSE
	expect_false(f$p$supports_likelihood_tests())
	expect_false(f$p$supports_lik_ratio_param_bootstrap())
	expect_false(f$p$supports_bartlett_likelihood_ratio_approx())
})

test_that("coefficient extremeness uses the instance threshold and rejects non-finite values", {
	f <- cox_fx()
	expect_equal(f$p$cox_extreme_coef_threshold, 20)
	expect_false(f$p$cox_coefficients_extreme(c(-19.9, 5)))
	expect_true(f$p$cox_coefficients_extreme(c(0, -20.1)))
	expect_true(f$p$cox_coefficients_extreme(NA_real_))
	expect_true(f$p$cox_coefficients_extreme(Inf))
	f$p$cox_extreme_coef_threshold <- 0.1
	expect_true(f$p$cox_coefficients_extreme(0.2))
})

test_that("weighted estimate tracks coxph(weights=), drops the SE, and flags extreme weighted coefficients", {
	f <- cox_fx()
	f$p$current_bayesian_bootstrap_context <- f$p$build_bayesian_bootstrap_context()
	set.seed(8)
	wts <- rexp(f$n)
	est <- f$inf$compute_estimate_with_bootstrap_weights(wts)
	ref <- coxph(Surv(f$t, f$d) ~ f$w + f$x, weights = wts)
	expect_equal(est, unname(coef(ref))[1], tolerance = 1e-3)
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))

	g <- cox_fx()
	g$p$current_bayesian_bootstrap_context <- g$p$build_bayesian_bootstrap_context()
	g$p$cox_extreme_coef_threshold <- 1e-6
	expect_true(is.na(g$inf$compute_estimate_with_bootstrap_weights(wts)))
	expect_true(g$inf$is_nonestimable("estimate"))
	expect_identical(g$inf$get_nonestimable_reason(), "coxph_weighted_extreme_coefficients")
})
