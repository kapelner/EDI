library(testthat)
library(EDI)

# InferenceCountZeroInflatedPoisson/InferenceCountHurdlePoisson's marginal_mean_diff/
# marginal_ratio estimand path (compute_marginal_estimand_estimate() in
# inference_count_zero_augmented_poisson_abstract.R) was only smoke-tested for finiteness
# under estimate_only = TRUE in test-count-model-and-bootstrap-contracts.R -- never checked
# with a standard error/CI/p-value against an independent reference, never exercised for
# marginal_ratio, and never independently verified for the hurdle-specific truncated-mean
# functional (zero_augmented_poisson_mean_from_theta's is_hurdle = TRUE branch) vs. the
# zero-inflated untruncated-mean branch. Grepped testthat/testthat_bulk: no other hits.

zip_marginal_fixture <- function(seed = 20260921L, n = 70L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignSeqOneByOneBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	for (i in seq_len(n)) {
		w_i <- des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
		mu_i <- exp(0.4 + 0.4 * w_i + 0.2 * X$x1[i])
		p0 <- stats::plogis(-1.0 - 0.3 * w_i)
		y_i <- if (stats::runif(1) > p0) stats::rpois(1, mu_i) else 0L
		des$add_one_subject_response(i, y_i)
	}
	des
}

# Independent delta-method reference: reimplements the ZIP/hurdle log-likelihood, the
# g-computation mean-difference/ratio functional, and the sandwich covariance from scratch
# (via numDeriv's automatic differentiation), not by calling any of the package's own
# analytic score/functional helpers. is_hurdle selects the truncated- vs untruncated-mean
# formula and the hurdle-vs-ZIP zero-generating process, matching each class's own model.
independent_marginal_reference <- function(theta_hat, X_fit, Xzi_fit, y, is_hurdle, estimand) {
	p <- ncol(X_fit)
	loglik_i <- function(theta) {
		b_cond <- theta[1:p]; b_zi <- theta[(p + 1):length(theta)]
		lambda <- exp(as.numeric(X_fit %*% b_cond))
		pi_ <- stats::plogis(as.numeric(Xzi_fit %*% b_zi))
		if (isTRUE(is_hurdle)) {
			ifelse(y == 0, log(pi_), log1p(-pi_) + dpois(y, lambda, log = TRUE) - log(-expm1(-lambda)))
		} else {
			ifelse(y == 0, log(pi_ + (1 - pi_) * exp(-lambda)), log1p(-pi_) + dpois(y, lambda, log = TRUE))
		}
	}
	functional <- function(theta) {
		b_cond <- theta[1:p]; b_zi <- theta[(p + 1):length(theta)]
		X1 <- X_fit; X1[, 2] <- 1; X0 <- X_fit; X0[, 2] <- 0
		Xzi1 <- Xzi_fit; Xzi1[, 2] <- 1; Xzi0 <- Xzi_fit; Xzi0[, 2] <- 0
		mean_fn <- function(Xc, Xz) {
			lam <- exp(as.numeric(Xc %*% b_cond))
			pi_ <- stats::plogis(as.numeric(Xz %*% b_zi))
			mu <- if (isTRUE(is_hurdle)) lam / (-expm1(-lam)) else lam
			mean((1 - pi_) * mu)
		}
		mean1 <- mean_fn(X1, Xzi1); mean0 <- mean_fn(X0, Xzi0)
		if (identical(estimand, "marginal_ratio")) log(mean1 / mean0) else mean1 - mean0
	}
	H <- numDeriv::hessian(function(th) -sum(loglik_i(th)), theta_hat)
	bread <- solve(H)
	meat <- crossprod(numDeriv::jacobian(loglik_i, theta_hat))
	vcov_indep <- bread %*% meat %*% bread
	grad <- numDeriv::grad(functional, theta_hat)
	list(
		point = functional(theta_hat),
		se = sqrt(as.numeric(t(grad) %*% vcov_indep %*% grad))
	)
}

test_that("ZIP marginal_mean_diff/marginal_ratio match an independently-rederived delta-method reference", {
	skip_if_not_installed("numDeriv")
	des <- zip_marginal_fixture()
	inf <- InferenceCountZeroInflatedPoisson$new(des, model_formula = ~x1, model_formula_zero = ~1, use_rcpp = TRUE)
	conditional <- inf$compute_estimate(estimate_only = FALSE)
	priv <- inf$.__enclos_env__$private

	for (estimand in c("marginal_mean_diff", "marginal_ratio")) {
		inf$set_estimand(estimand)
		point_pkg <- inf$compute_estimate(estimate_only = FALSE)
		se_pkg <- priv$cached_values$s_beta_hat_T
		expect_true(is.finite(point_pkg))
		expect_true(is.finite(se_pkg) && se_pkg > 0)

		raw <- priv$cached_mod$mod
		expect_false(isTRUE(raw$is_hurdle))
		ref <- independent_marginal_reference(raw$params, raw$X_fit, raw$Xzi_fit, des$get_y(), FALSE, estimand)
		expect_equal(point_pkg, ref$point, tolerance = 1e-8)
		expect_equal(se_pkg, ref$se, tolerance = 1e-4)

		# CI/p-value dispatch under the marginal path: plain z-based formula (df = Inf).
		alpha <- 0.05
		ci <- inf$compute_asymp_confidence_interval(alpha)
		expect_equal(unname(ci), point_pkg + c(-1, 1) * qnorm(1 - alpha / 2) * se_pkg, tolerance = 1e-10)
		pval <- inf$compute_asymp_two_sided_pval(delta = 0)
		expect_equal(pval, 2 * pnorm(-abs(point_pkg / se_pkg)), tolerance = 1e-10)
	}

	# Switching back to "conditional" re-derives from the estimand-invariant cached_mod,
	# not stale marginal numbers left by shared()'s short-circuit guard.
	inf$set_estimand("conditional")
	expect_equal(inf$compute_estimate(estimate_only = FALSE), conditional, tolerance = 1e-10)

	# And switching forward again reproduces the identical marginal point (pure post-fit
	# transform of the one cached ML fit -- no refit as the estimand toggles).
	inf$set_estimand("marginal_mean_diff")
	expect_equal(inf$compute_estimate(estimate_only = FALSE), priv$cached_values$beta_hat_T, tolerance = 1e-10)
})

test_that("hurdle Poisson's marginal_mean_diff uses the truncated-mean functional, verified independently", {
	skip_if_not_installed("numDeriv")
	des <- zip_marginal_fixture()
	inf <- InferenceCountHurdlePoisson$new(des, model_formula = ~x1, model_formula_hurdle = ~1, use_rcpp = TRUE)
	inf$compute_estimate()
	inf$set_estimand("marginal_mean_diff")
	point_pkg <- inf$compute_estimate(estimate_only = FALSE)
	priv <- inf$.__enclos_env__$private
	se_pkg <- priv$cached_values$s_beta_hat_T

	raw <- priv$cached_mod$mod
	expect_true(isTRUE(raw$is_hurdle))
	ref <- independent_marginal_reference(raw$params, raw$X_fit, raw$Xzi_fit, des$get_y(), TRUE, "marginal_mean_diff")
	expect_equal(point_pkg, ref$point, tolerance = 1e-8)
	expect_equal(se_pkg, ref$se, tolerance = 1e-4)

	# The untruncated (ZIP-style) functional must give a genuinely different number here --
	# proves the is_hurdle branch actually changes the mean formula, not a silent no-op.
	ref_untruncated <- independent_marginal_reference(raw$params, raw$X_fit, raw$Xzi_fit, des$get_y(), FALSE, "marginal_mean_diff")
	expect_false(isTRUE(all.equal(point_pkg, ref_untruncated$point)))
})

test_that("marginal estimand caches the nonestimable vcov-unavailable reason when the sandwich covariance fails", {
	des <- zip_marginal_fixture()
	inf <- InferenceCountZeroInflatedPoisson$new(des, model_formula = ~x1, model_formula_zero = ~1, use_rcpp = TRUE)
	inf$compute_estimate()
	priv <- inf$.__enclos_env__$private
	unlockBinding("zero_augmented_poisson_sandwich_vcov_full", priv)
	priv$zero_augmented_poisson_sandwich_vcov_full <- function(...) NULL

	inf$set_estimand("marginal_mean_diff")
	point <- inf$compute_estimate(estimate_only = FALSE)
	expect_true(is.finite(point))
	expect_true(inf$is_nonestimable())
	expect_identical(inf$get_nonestimable_reason(), "zero_augmented_poisson_marginal_vcov_unavailable")
	expect_true(is.na(priv$cached_values$s_beta_hat_T))
})
