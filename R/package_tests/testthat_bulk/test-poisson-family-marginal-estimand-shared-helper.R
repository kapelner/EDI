library(testthat)
library(EDI)

# Shared marginal-estimand helpers used by InferenceCountPoisson and InferenceCountQuasiPoisson (helper_marginal_estimand.R):
# poisson_family_mean_from_coefs, poisson_family_marginal_functional and poisson_family_marginal_estimand_estimate. Covered here:
# the pure functions against hand g-computation, the estimate routine's success / failure states through a fake private
# environment (no class needed), both classes' private wrappers delegating to it, and the one intended difference between the
# classes: the quasi-Poisson delta-method SE is the plain-Poisson SE times sqrt(phi) at an identical point estimate.

H <- function(name) getFromNamespace(name, "EDI")
set.seed(3); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects()
w <- d$get_w(); y <- rnbinom(n, mu = exp(0.2 + 0.4 * w + 0.3 * X$x1 - 0.2 * X$x2), size = 1.5); d$add_all_subject_responses(y)
mk <- function(cls) { inf <- cls$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
Xd <- cbind(1, w, X$x1, X$x2)
gcomp <- function(beta, est) {
	X1 <- Xd; X1[, 2] <- 1; X0 <- Xd; X0[, 2] <- 0
	m1 <- mean(exp(X1 %*% beta)); m0 <- mean(exp(X0 %*% beta))
	if (est == "marginal_ratio") log(m1 / m0) else m1 - m0
}
fake_private <- function() {
	e <- new.env(); e$cached_values <- list(); e$calls <- character()
	e$cache_nonestimable_estimate <- function(reason) e$calls <- c(e$calls, paste0("estimate:", reason))
	e$cache_nonestimable_se <- function(reason) e$calls <- c(e$calls, paste0("se:", reason))
	e$clear_nonestimable_state <- function() e$calls <- c(e$calls, "cleared")
	e
}

test_that("mean function and g-computation functional equal the hand computation and leave X untouched", {
	beta <- c(0.1, 0.2, -0.3, 0.4); X_copy <- Xd
	expect_equal(H("poisson_family_mean_from_coefs")(beta, Xd), exp(as.numeric(Xd %*% beta)), tolerance = 1e-12)
	for (est in c("marginal_mean_diff", "marginal_ratio"))
		expect_equal(H("poisson_family_marginal_functional")(beta, Xd, est), gcomp(beta, est), tolerance = 1e-12, info = est)
	expect_identical(Xd, X_copy)
	b0 <- beta; b0[2] <- 0                                            # no treatment effect: both functionals are exactly 0
	expect_equal(H("poisson_family_marginal_functional")(b0, Xd, "marginal_ratio"), 0, tolerance = 1e-12)
	expect_equal(H("poisson_family_marginal_functional")(b0, Xd, "marginal_mean_diff"), 0, tolerance = 1e-12)
	expect_equal(H("poisson_family_marginal_functional")(beta, Xd, "anything"), gcomp(beta, "marginal_mean_diff"), tolerance = 1e-12)
})

test_that("estimate routine: success writes the point estimate, delta SE and df = Inf, and clears the non-estimable state", {
	skip_if_not_installed("numDeriv")
	b <- c(0.2, 0.4, 0.3, -0.2); V <- diag(c(0.02, 0.01, 0.005, 0.005)); est <- "marginal_mean_diff"
	e <- fake_private()
	point <- H("poisson_family_marginal_estimand_estimate")(e, list(b = b, X = Xd, vcov = V), est)
	g <- numDeriv::grad(function(th) gcomp(th, est), b)
	expect_equal(point, gcomp(b, est), tolerance = 1e-12)
	expect_equal(e$cached_values$beta_hat_T, point)
	expect_equal(e$cached_values$s_beta_hat_T, sqrt(drop(t(g) %*% V %*% g)), tolerance = 1e-4)
	expect_identical(e$cached_values$df, Inf)
	expect_identical(e$calls, "cleared")
})

test_that("estimate routine failure states carry the caller's reason prefix and never write a stale SE", {
	fn <- H("poisson_family_marginal_estimand_estimate")
	b <- c(0.2, 0.4, 0.3, -0.2)
	e <- fake_private(); expect_true(is.na(fn(e, NULL, "marginal_ratio", reason_prefix = "quasipoisson")))
	expect_identical(e$calls, "estimate:quasipoisson_marginal_fit_unavailable")
	e <- fake_private(); expect_true(is.na(fn(e, list(b = b), "marginal_ratio")))                                     # no X
	expect_identical(e$calls, "estimate:poisson_marginal_fit_unavailable")
	e <- fake_private(); expect_true(is.na(fn(e, list(b = c(Inf, 0, 0, 0), X = Xd), "marginal_ratio")))              # non-finite functional
	expect_identical(e$calls, "estimate:poisson_marginal_point_unavailable")
	e <- fake_private(); p <- fn(e, list(b = b, X = Xd), "marginal_mean_diff")                                        # no vcov: point kept, SE flagged
	expect_equal(p, gcomp(b, "marginal_mean_diff"), tolerance = 1e-12)
	expect_identical(e$calls, "se:poisson_marginal_vcov_unavailable"); expect_null(e$cached_values$s_beta_hat_T)
	e <- fake_private(); p <- fn(e, list(b = b, X = Xd, vcov = diag(-1, 4)), "marginal_mean_diff")                    # negative quadratic form
	expect_identical(e$calls, "se:poisson_marginal_se_unavailable")
	e <- fake_private(); p <- fn(e, list(b = b, X = Xd), "marginal_mean_diff", estimate_only = TRUE)                  # estimate_only: nothing but the point
	expect_equal(p, gcomp(b, "marginal_mean_diff"), tolerance = 1e-12); expect_length(e$calls, 0L)
})

test_that("both classes' private wrappers delegate to the shared functions", {
	beta <- c(0.1, 0.2, -0.3, 0.4)
	po <- mk(InferenceCountPoisson)$p; qp <- mk(InferenceCountQuasiPoisson)$p
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		ref <- H("poisson_family_marginal_functional")(beta, Xd, est)
		expect_identical(po$poisson_marginal_functional(beta, Xd, est), ref, info = est)
		expect_identical(qp$quasipoisson_marginal_functional(beta, Xd, est), ref, info = est)
	}
	expect_identical(po$poisson_mean_from_coefs(beta, Xd), qp$quasipoisson_mean_from_coefs(beta, Xd))
})

test_that("quasi-Poisson marginal SE is the plain-Poisson marginal SE times sqrt(phi) at an identical point estimate", {
	phi <- summary(glm(y ~ w + x1 + x2, data = data.frame(y, w, X), family = quasipoisson))$dispersion
	expect_gt(phi, 1.3)
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		q <- mk(InferenceCountQuasiPoisson); q$inf$set_estimand(est); pq <- q$inf$compute_estimate(); se_q <- q$p$get_standard_error()
		p <- mk(InferenceCountPoisson); p$inf$set_estimand(est); pp <- p$inf$compute_estimate(); se_p <- p$p$get_standard_error()
		expect_equal(pq, pp, tolerance = 1e-6, info = est)
		expect_gt(se_q, se_p)
		expect_equal(se_q / se_p, sqrt(phi), tolerance = 2e-3, info = est)
	}
})
