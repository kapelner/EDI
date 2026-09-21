library(testthat)
library(EDI)
skip_if_not_installed("numDeriv")

# InferenceCountQuasiPoisson composes MarginalEstimand: set_estimand("marginal_mean_diff" / "marginal_ratio") gives the g-computed
# difference / log-ratio of the average fitted counts with a delta-method SE from the dispersion-scaled covariance. Reference:
# glm(family = quasipoisson) coefficients and vcov (phi (X'WX)^-1) with a numDeriv gradient of the functional.

set.seed(5); n <- 200L
d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n))); d$assign_w_to_all_subjects(); w <- d$get_w()
d$add_all_subject_responses(rnbinom(n, mu = exp(0.3 + 0.4 * w + 0.2 * d$get_X_raw()$x1), size = 2))
dat <- data.frame(y = d$get_y(), w = w, d$get_X_raw())
g <- glm(y ~ w + x1 + x2, data = dat, family = quasipoisson); Xm <- model.matrix(g); b <- coef(g)
functional <- function(th, est) { X1 <- Xm; X1[, "w"] <- 1; X0 <- Xm; X0[, "w"] <- 0; m1 <- mean(exp(X1 %*% th)); m0 <- mean(exp(X0 %*% th))
	if (est == "marginal_ratio") log(m1 / m0) else m1 - m0 }
mk <- function(est = NULL) { q <- InferenceCountQuasiPoisson$new(d, verbose = FALSE); if (!is.null(est)) q$set_estimand(est); q }

test_that("the class now supports the two marginal estimands and rejects unknown ones", {
	q <- mk()
	expect_equal(q$get_supported_estimands(), c("conditional", "marginal_mean_diff", "marginal_ratio"))
	expect_equal(q$get_estimand(), "conditional")
	expect_error(q$set_estimand("bogus"), "Unrecognized estimand")
})

test_that("conditional: estimate and dispersion-scaled SE equal glm(quasipoisson)", {
	q <- mk()
	expect_equal(q$compute_estimate(), unname(b["w"]), tolerance = 1e-6)
	expect_equal(q$.__enclos_env__$private$get_standard_error(), unname(sqrt(vcov(g)["w", "w"])), tolerance = 1e-5)
})

test_that("marginal estimands: point, delta-method SE, Wald CI and p-value equal the glm + numDeriv reference", {
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		q <- mk(est); e <- q$compute_estimate(); p <- q$.__enclos_env__$private
		gr <- numDeriv::grad(function(th) functional(th, est), b); ref_se <- sqrt(drop(t(gr) %*% vcov(g) %*% gr))
		expect_equal(e, functional(b, est), tolerance = 1e-6, info = est)
		expect_equal(p$get_standard_error(), ref_se, tolerance = 1e-4, info = est)
		expect_equal(p$get_degrees_of_freedom(), Inf, info = est)
		expect_equal(unname(q$compute_asymp_confidence_interval()), functional(b, est) + c(-1, 1) * qnorm(0.975) * ref_se, tolerance = 1e-4, info = est)
		expect_equal(q$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(functional(b, est) / ref_se)), tolerance = 1e-4, info = est)
	}
})

test_that("call order does not matter: SE / CI before compute_estimate, estimate_only first, and switching back to conditional", {
	q <- mk("marginal_mean_diff")
	se_first <- q$.__enclos_env__$private$get_standard_error()                 # no compute_estimate() yet
	q_ref <- mk("marginal_mean_diff"); q_ref$compute_estimate()
	expect_equal(se_first, q_ref$.__enclos_env__$private$get_standard_error(), tolerance = 1e-10)
	q2 <- mk("marginal_mean_diff"); pt <- q2$compute_estimate(estimate_only = TRUE)
	expect_equal(pt, functional(b, "marginal_mean_diff"), tolerance = 1e-6)
	expect_equal(q2$compute_estimate(), pt, tolerance = 1e-10)
	expect_true(is.finite(q2$.__enclos_env__$private$get_standard_error()))       # variance obtained after the estimate-only pass
	q2$set_estimand("conditional")
	expect_equal(q2$compute_estimate(), unname(b["w"]), tolerance = 1e-6)
	expect_equal(q2$.__enclos_env__$private$get_standard_error(), unname(sqrt(vcov(g)["w", "w"])), tolerance = 1e-5)
})

test_that("for the log link the marginal log-ratio equals the conditional coefficient and its SE the conditional SE", {
	q <- mk("marginal_ratio"); q$compute_estimate()
	expect_equal(q$compute_estimate(), unname(b["w"]), tolerance = 1e-6)
	expect_equal(q$.__enclos_env__$private$get_standard_error(), unname(sqrt(vcov(g)["w", "w"])), tolerance = 1e-4)
})
