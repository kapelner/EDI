library(testthat)
library(EDI)
skip_if_not_installed("numDeriv")

# Regression file for marginal-estimand standard-error consistency: under a marginal estimand get_standard_error(), the Wald CI
# and the p-value must all come from the delta-method SE of the g-computed functional (reference: sqrt(g' V g) of the g-computed
# mean difference with V = glm's model-based covariance). Fixed bugs: InferenceIncidLogRegr returned the CONDITIONAL log-odds SE;
# InferenceCountPoisson returned NA (its with_var kernel returns fisher_information, not XtWX, so the stored vcov was NULL);
# InferenceCountZeroInflatedPoisson returned the conditional information SE while its marginal CI / p-value were NA on a fit
# with no zero inflation (degenerate zero-augmented fit), it now reports NA consistently there. InferenceCountQuasiPoisson used to have
# no MarginalEstimand component (set_estimand did not exist); it now has one, covered in its own quasipoisson marginal file.

set.seed(5); n <- 150L
mkd <- function(rt, yfun) {
	d <- DesignFixedBernoulli$new(response_type = rt, n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n))); d$assign_w_to_all_subjects(); d$add_all_subject_responses(yfun(d$get_w())); d
}
di <- mkd("incidence", function(w) rbinom(n, 1, 0.3 + 0.3 * w))
dc <- mkd("count", function(w) rpois(n, exp(0.2 + 0.4 * w)))
ci_half <- function(inf, a = 0.05) unname(diff(inf$compute_asymp_confidence_interval(a))) / 2 / qnorm(1 - a / 2)

test_that("logistic regression: the cached marginal SE equals the delta-method reference, and the CI is built from it", {
	inf <- InferenceIncidLogRegr$new(di, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); est <- inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	dat <- data.frame(y = di$get_y(), w = di$get_w(), di$get_X_raw())
	fit <- glm(y ~ w + x1 + x2, data = dat, family = binomial)
	Xm <- model.matrix(fit); b <- coef(fit)
	f <- function(th) { X1 <- Xm; X1[, "w"] <- 1; X0 <- Xm; X0[, "w"] <- 0; mean(plogis(X1 %*% th)) - mean(plogis(X0 %*% th)) }
	g <- numDeriv::grad(f, b); ref_se <- sqrt(drop(t(g) %*% vcov(fit) %*% g))
	expect_equal(est, f(b), tolerance = 1e-5)
	expect_equal(p$cached_values$s_beta_hat_T, ref_se, tolerance = 1e-3)
	expect_equal(ci_half(inf), ref_se, tolerance = 1e-3)
})

test_that("logistic: get_standard_error() under a marginal estimand is the cached delta-method SE (and the conditional SE is unchanged)", {
	inf <- InferenceIncidLogRegr$new(di, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_equal(p$get_standard_error(), p$cached_values$s_beta_hat_T, tolerance = 1e-10)
	expect_equal(p$get_standard_error(), ci_half(inf), tolerance = 1e-6)
	expect_equal(p$get_degrees_of_freedom(), Inf)
	cond <- InferenceIncidLogRegr$new(di, verbose = FALSE); cond$compute_estimate()
	g <- glm(di$get_y() ~ di$get_w() + ., data = di$get_X_raw(), family = binomial)
	expect_equal(cond$.__enclos_env__$private$get_standard_error(), unname(summary(g)$coefficients[2, 2]), tolerance = 1e-3)
	expect_gt(cond$.__enclos_env__$private$get_standard_error(), 3 * p$get_standard_error())
	inf$set_estimand("conditional"); inf$compute_estimate()                       # switching back restores the conditional SE
	expect_equal(inf$.__enclos_env__$private$get_standard_error(), cond$.__enclos_env__$private$get_standard_error(), tolerance = 1e-10)
})

test_that("zero-inflated Poisson, degenerate fit (no zero inflation): SE, CI and p-value are consistently NA under a marginal estimand", {
	inf <- InferenceCountZeroInflatedPoisson$new(dc, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); est <- inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_true(is.finite(est)); expect_true(is.na(p$get_standard_error()))
	expect_true(all(is.na(inf$compute_asymp_confidence_interval()))); expect_true(is.na(inf$compute_asymp_two_sided_pval()))
})

test_that("zero-inflated Poisson with genuine zero inflation: SE == CI half-width / z and the p-value follows from it, for both marginal estimands", {
	set.seed(5); m <- 300L
	d <- DesignFixedBernoulli$new(response_type = "count", n = m, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(data.frame(x1 = rnorm(m), x2 = runif(m))); d$assign_w_to_all_subjects()
	zi <- rbinom(m, 1, plogis(-0.3 + 0.4 * d$get_X_raw()$x1)); d$add_all_subject_responses(ifelse(zi == 1, 0L, rpois(m, exp(0.8 + 0.4 * d$get_w()))))
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		inf <- InferenceCountZeroInflatedPoisson$new(d, verbose = FALSE); inf$set_estimand(est); e <- inf$compute_estimate()
		se <- inf$.__enclos_env__$private$get_standard_error()
		expect_true(is.finite(se) && se > 0, info = est)
		expect_equal(se, ci_half(inf), tolerance = 1e-6, info = est)
		expect_equal(inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(e / se)), tolerance = 1e-6, info = est)
	}
})

test_that("consistent classes: the standard error equals the Wald CI half-width divided by z (binomial identity, hurdle Poisson)", {
	b <- InferenceIncidBinomialIdentityRiskDiff$new(di, verbose = FALSE); b$set_estimand("marginal_mean_diff"); b$compute_estimate()
	expect_equal(b$.__enclos_env__$private$get_standard_error(), ci_half(b), tolerance = 1e-6)
	h <- InferenceCountHurdlePoisson$new(dc, verbose = FALSE); h$set_estimand("marginal_mean_diff"); h$compute_estimate()
	expect_equal(h$.__enclos_env__$private$get_standard_error(), ci_half(h), tolerance = 1e-6)
})

test_that("marginal_ratio: hurdle Poisson and logistic regression are consistent (SE == CI half-width / z, p-value from SE)", {
	get_se <- function(cls, data, est) { inf <- cls$new(data, verbose = FALSE); inf$set_estimand(est); inf$compute_estimate(); list(inf = inf, se = inf$.__enclos_env__$private$get_standard_error()) }
	h <- get_se(InferenceCountHurdlePoisson, dc, "marginal_ratio")
	expect_equal(h$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(h$inf$compute_estimate() / h$se)), tolerance = 1e-6)
	expect_equal(h$se, ci_half(h$inf), tolerance = 1e-6)
	l <- get_se(InferenceIncidLogRegr, di, "marginal_ratio")
	expect_equal(l$se, ci_half(l$inf), tolerance = 1e-6)                        # SE now matches the marginal delta-method CI
	lm <- get_se(InferenceIncidLogRegr, di, "marginal_mean_diff")
	expect_false(isTRUE(all.equal(l$se, lm$se)))                                # and differs between the two estimands
})

test_that("Poisson: get_standard_error() is the finite delta-method SE; the design-conservative Wald CI / p-value are at least as wide / large as the plain z ones", {
	# InferenceCountPoisson combines its model Wald with a jackknife Wald (max rule), so its CI/p-value may exceed the plain z values.
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		inf <- InferenceCountPoisson$new(dc, verbose = FALSE); inf$set_estimand(est); e <- inf$compute_estimate()
		p <- inf$.__enclos_env__$private
		se <- p$get_standard_error()
		expect_true(is.finite(se) && se > 0, info = est)
		expect_equal(se, p$cached_values$s_beta_hat_T, tolerance = 1e-10, info = est)
		ci <- inf$compute_asymp_confidence_interval()
		expect_true(all(is.finite(ci)) && ci[1] < e && e < ci[2], info = est)
		expect_gte(diff(ci) / 2 / qnorm(0.975), se * (1 - 1e-6))
		pv <- inf$compute_asymp_two_sided_pval()
		expect_true(is.finite(pv), info = est)
		expect_gte(pv, 2 * pnorm(-abs(e / se)) * (1 - 1e-6))
	}
})
