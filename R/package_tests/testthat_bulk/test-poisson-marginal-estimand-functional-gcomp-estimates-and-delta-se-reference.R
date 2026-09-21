library(testthat)
library(EDI)

# InferenceCountPoisson marginal estimands: poisson_mean_from_coefs, poisson_marginal_functional (g-computation average of
# exp(X beta) with the treatment column set to 1 / 0; mean difference or log ratio), and compute_marginal_estimand_estimate
# (point estimate from the cached ML fit, delta-method SE from its vcov, Inf df). References: stats::glm(poisson) coefficients and
# vcov, hand g-computation, and numDeriv gradients for the delta method.

set.seed(3); n <- 120L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w(); y <- rpois(n, exp(0.2 + 0.4 * w + 0.3 * X$x1 - 0.2 * X$x2)); d$add_all_subject_responses(y)
mk <- function() { inf <- InferenceCountPoisson$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
Xd <- cbind(1, w, X$x1, X$x2)
fit <- glm(y ~ w + x1 + x2, data = data.frame(y, w, X), family = poisson)
b <- unname(coef(fit)); V <- unname(vcov(fit))
gcomp <- function(beta, est) {
	X1 <- Xd; X1[, 2] <- 1; X0 <- Xd; X0[, 2] <- 0
	m1 <- mean(exp(X1 %*% beta)); m0 <- mean(exp(X0 %*% beta))
	if (est == "marginal_ratio") log(m1 / m0) else m1 - m0
}

test_that("mean function is exp(X beta) elementwise", {
	f <- mk()
	beta <- c(0.1, 0.2, -0.3, 0.4)
	expect_equal(f$p$poisson_mean_from_coefs(beta, Xd), exp(as.numeric(Xd %*% beta)), tolerance = 1e-12)
	expect_equal(f$p$poisson_mean_from_coefs(rep(0, 4), Xd), rep(1, n))
})

test_that("marginal functional equals hand g-computation for both estimands; the design matrix argument is not modified", {
	f <- mk(); beta <- c(0.1, 0.2, -0.3, 0.4); X_copy <- Xd
	expect_equal(f$p$poisson_marginal_functional(beta, Xd, "marginal_mean_diff"), gcomp(beta, "marginal_mean_diff"), tolerance = 1e-12)
	expect_equal(f$p$poisson_marginal_functional(beta, Xd, "marginal_ratio"), gcomp(beta, "marginal_ratio"), tolerance = 1e-12)
	expect_identical(Xd, X_copy)
	# with no treatment effect the ratio functional is exactly 0 and the difference is 0
	b0 <- beta; b0[2] <- 0
	expect_equal(f$p$poisson_marginal_functional(b0, Xd, "marginal_ratio"), 0, tolerance = 1e-12)
	expect_equal(f$p$poisson_marginal_functional(b0, Xd, "marginal_mean_diff"), 0, tolerance = 1e-12)
	# unknown estimand names fall through to the mean difference
	expect_equal(f$p$poisson_marginal_functional(beta, Xd, "anything"), gcomp(beta, "marginal_mean_diff"), tolerance = 1e-12)
})

test_that("class estimate under each marginal estimand equals the g-computation of the glm fit", {
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		f <- mk(); f$inf$set_estimand(est)
		expect_equal(f$inf$compute_estimate(), gcomp(b, est), tolerance = 1e-5, info = est)
	}
	f <- mk(); expect_equal(f$inf$compute_estimate(), unname(coef(fit)[2]), tolerance = 1e-6)          # conditional stays the treatment coefficient
})

test_that("delta-method SE equals sqrt(grad' V grad) once the fit carries its vcov; df is Inf", {
	skip_if_not_installed("numDeriv")
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		f <- mk(); f$inf$set_estimand(est); f$inf$compute_estimate()
		f$p$cached_mod$vcov <- V; f$p$cached_mod$b <- b                                # supply the glm coefficients / covariance directly
		f$p$cached_values$s_beta_hat_T <- NULL
		f$p$compute_marginal_estimand_estimate(est)
		g <- numDeriv::grad(function(th) gcomp(th, est), b)
		expect_equal(f$p$cached_values$s_beta_hat_T, sqrt(drop(t(g) %*% V %*% g)), tolerance = 1e-4, info = est)
		expect_identical(f$p$cached_values$df, Inf)
	}
})

test_that("regression: the default cached fit carries a vcov, so the marginal SE is available, finite and matches the delta method", {
	f <- mk(); f$inf$set_estimand("marginal_mean_diff"); f$inf$compute_estimate()
	expect_false(is.null(f$p$cached_mod$vcov))                                          # solve(fisher_information) of the with_var kernel
	se <- f$p$get_standard_error()
	expect_true(is.finite(se) && se > 0)
	expect_false(isTRUE(f$inf$is_nonestimable("se")))
	g <- numDeriv::grad(function(th) gcomp(th, "marginal_mean_diff"), as.numeric(f$p$cached_mod$b))
	expect_equal(se, sqrt(drop(t(g) %*% f$p$cached_mod$vcov %*% g)), tolerance = 1e-4)
	expect_true(all(is.finite(f$inf$compute_asymp_confidence_interval())))
})

test_that("estimate-only path returns the point without a variance; missing fit is reported as nonestimable", {
	f <- mk(); f$inf$set_estimand("marginal_mean_diff")
	expect_equal(f$inf$compute_estimate(estimate_only = TRUE), gcomp(b, "marginal_mean_diff"), tolerance = 1e-5)
	g <- mk(); g$inf$set_estimand("marginal_mean_diff"); g$p$cached_mod <- NULL
	expect_true(is.na(g$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_true(isTRUE(g$inf$is_nonestimable("estimate")))
})
