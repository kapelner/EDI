library(testthat)
library(EDI)

# InferenceAbstractKKModifiedPoisson's private likelihood plumbing
# (get_likelihood_test_spec, simulate_under_lik_null), its coefficient-size
# predicate, failed-fit cache, the harden-mode treatment-only retry in
# shared(), and the get_standard_error()/get_degrees_of_freedom() accessors.
# The sibling asymptotic reference test covers the ordinary fit only.
# References: stats::glm(family = poisson()) on the same binary responses (the
# working model is a Poisson log-link fit), closed-form Poisson score and
# information, and a from-scratch seeded simulation.

modpois_fixture <- function(seed = 31L, n = 70L, harden = TRUE) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "incidence", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- rbinom(n, 1, plogis(-0.3 + 0.9 * w + 0.4 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceIncidKKModifiedPoisson$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$harden <- harden
	list(inf = inf, priv = priv, w = w, X = X, y = y, n = n)
}

pois_ll <- function(b, X, y) {
	eta <- as.numeric(X %*% b)
	sum(y * eta - exp(eta) - lgamma(y + 1))
}

test_that("likelihood spec's neg_loglik, score and information match the Poisson references", {
	f <- modpois_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	expect_equal(sp$j, 2L)
	fit <- sp$full_fit
	g <- glm(f$y ~ f$w + f$X$x1 + f$X$x2, family = poisson())
	expect_equal(as.numeric(fit$b), unname(coef(g)), tolerance = 1e-6)
	expect_equal(sp$neg_loglik(fit), -as.numeric(logLik(g)), tolerance = 1e-6)

	b <- as.numeric(fit$b) + c(0.05, -0.03, 0.02, 0.04)
	fit_pert <- list(b = b)
	mu <- exp(as.numeric(sp$X %*% b))
	expect_equal(sp$score(fit_pert), as.numeric(crossprod(sp$X, sp$y - mu)), tolerance = 1e-6)
	ref_info <- crossprod(sp$X * sqrt(mu))
	expect_equal(unname(sp$observed_information(fit_pert)), unname(ref_info), tolerance = 1e-6)
	expect_equal(sp$fisher_information(fit_pert), sp$observed_information(fit_pert))
	expect_equal(sp$information(fit_pert), sp$observed_information(fit_pert))
	expect_equal(sp$extract_start(fit), as.numeric(fit$b))
	expect_equal(sp$neg_loglik(fit_pert), -pois_ll(b, sp$X, sp$y), tolerance = 1e-8)
})

test_that("fit_null pins the treatment coefficient and attains the constrained Poisson optimum", {
	f <- modpois_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	expect_equal(as.numeric(nf$b[sp$j]), 0)
	ref <- glm(f$y ~ f$X$x1 + f$X$x2, family = poisson())
	expect_equal(as.numeric(nf$b[-sp$j]), unname(coef(ref)), tolerance = 1e-5)
	expect_gte(sp$neg_loglik(nf), sp$neg_loglik(sp$full_fit) - 1e-8)
	nf2 <- sp$fit_null(0.4)
	expect_equal(as.numeric(nf2$b[sp$j]), 0.4)
})

test_that("simulate_under_lik_null draws Poisson responses from the null fit and refits", {
	f <- modpois_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)

	set.seed(55)
	sim <- f$priv$simulate_under_lik_null(sp, 0, nf)
	expect_named(sim, c("full_fit", "fit_null", "neg_loglik"))

	set.seed(55)
	y_sim <- as.numeric(rpois(nrow(sp$X), pmax(exp(as.numeric(sp$X %*% as.numeric(nf$b))), 0)))
	g <- suppressWarnings(glm(y_sim ~ sp$X - 1, family = poisson()))
	expect_equal(as.numeric(sim$full_fit$b), unname(coef(g)), tolerance = 1e-5)
	expect_equal(sim$neg_loglik(sim$full_fit), -pois_ll(as.numeric(sim$full_fit$b), sp$X, y_sim), tolerance = 1e-8)
	sn <- sim$fit_null(0)
	expect_equal(as.numeric(sn$b[sp$j]), 0)
})

test_that("coefficients_are_usable enforces non-empty, finite and size-capped coefficient vectors", {
	f <- modpois_fixture()
	ok <- f$priv$coefficients_are_usable
	cap <- f$priv$max_abs_reasonable_coef
	expect_true(ok(c(1, -2)))
	expect_true(ok(c(cap, -cap)))
	expect_false(ok(c(1, cap + 0.01)))
	expect_false(ok(numeric(0)))
	expect_false(ok(c(1, NA)))
	expect_false(ok(c(Inf, 1)))
})

test_that("set_failed_fit_cache marks the estimate nonestimable and clears the fit summaries", {
	f <- modpois_fixture()
	f$inf$compute_asymp_confidence_interval()
	expect_false(is.null(f$priv$cached_values$full_coefficients))
	f$priv$set_failed_fit_cache()
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_null(f$priv$cached_values$full_coefficients)
	expect_null(f$priv$cached_values$full_vcov)
	expect_null(f$priv$cached_values$summary_table)
})

test_that("with hardening a failed covariate-adjusted fit is retried treatment-only; without hardening it is nonestimable", {
	for (harden in c(TRUE, FALSE)) {
		f <- modpois_fixture(harden = harden)
		real <- f$priv$fit_modified_poisson
		calls <- 0L
		ncols <- integer(0)
		unlockBinding("fit_modified_poisson", f$priv)
		f$priv$fit_modified_poisson <- function(X_fit, j_treat, estimate_only = FALSE) {
			calls <<- calls + 1L
			ncols <<- c(ncols, ncol(X_fit))
			if (calls == 1L) return(NULL)
			real(X_fit, j_treat, estimate_only = estimate_only)
		}
		est <- f$inf$compute_estimate()
		if (harden) {
			expect_equal(calls, 2L)
			expect_equal(ncols, c(4L, 2L))
			ref <- unname(coef(glm(f$y ~ f$w, family = poisson()))[2])
			expect_equal(est, ref, tolerance = 1e-6)
			expect_equal(ncol(f$priv$cached_values$likelihood_test_context$X), 2L)
			expect_false(f$inf$is_nonestimable("estimate"))
		} else {
			expect_equal(calls, 1L)
			expect_true(is.na(est) || is.null(est))
			expect_true(f$inf$is_nonestimable("estimate"))
		}
	}
})

test_that("get_standard_error and get_degrees_of_freedom read the fitted SE and residual df, defaulting when absent", {
	f <- modpois_fixture()
	se <- f$priv$get_standard_error()
	expect_true(is.finite(se) && se > 0)
	expect_equal(se, f$priv$cached_values$s_beta_hat_T)
	expect_equal(f$priv$get_degrees_of_freedom(), f$priv$cached_values$df)
	expect_equal(f$priv$cached_values$df, nrow(f$priv$cached_values$likelihood_test_context$X) - ncol(f$priv$cached_values$likelihood_test_context$X))

	f$priv$cached_values$s_beta_hat_T <- NULL
	f$priv$cached_values$s_beta_hat_T <- numeric(0)
	unlockBinding("shared", f$priv)
	f$priv$shared <- function(estimate_only = FALSE) invisible(NULL)
	expect_true(is.na(f$priv$get_standard_error()))
	f$priv$cached_values$df <- NULL
	expect_equal(f$priv$get_degrees_of_freedom(), Inf)
})

test_that("assert_finite_se never signals for finite, non-finite or non-positive SEs (source quirk, not fixed)", {
	f <- modpois_fixture()
	for (se in list(0.4, NA_real_, 0, -1)) {
		f$priv$cached_values$s_beta_hat_T <- se
		expect_null(f$priv$assert_finite_se())
	}
})
