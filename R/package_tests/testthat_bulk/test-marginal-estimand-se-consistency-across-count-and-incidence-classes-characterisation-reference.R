library(testthat)
library(EDI)
skip_if_not_installed("numDeriv")

# Characterisation of how the marginal-estimand standard error surfaces across classes that support estimands. Reference: the delta-method SE
# sqrt(g' V g) of the g-computed mean difference with V = glm's model-based covariance. Observed inconsistencies (suspected bugs, pinned):
#  * InferenceIncidLogRegr: cached s_beta_hat_T is the marginal delta SE (correct) but private get_standard_error() returns the CONDITIONAL
#    log-odds SE;
#  * InferenceCountZeroInflatedPoisson: get_standard_error() is finite but the asymptotic CI / p-value are NA under a marginal estimand;
#  * InferenceCountPoisson: see the Poisson-specific characterisation files (SE unavailable, CI finite).
# Classes with consistent behaviour (binomial identity, hurdle Poisson, beta) are checked for SE == CI half-width / z.

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

test_that("SUSPECTED BUG: logistic private get_standard_error() ignores the marginal estimand and returns the conditional coefficient SE", {
	inf <- InferenceIncidLogRegr$new(di, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_gt(p$get_standard_error(), 3 * p$cached_values$s_beta_hat_T)                    # 0.348 vs 0.078 on this fixture
	cond <- InferenceIncidLogRegr$new(di, verbose = FALSE); cond$compute_estimate()
	expect_equal(p$get_standard_error(), cond$.__enclos_env__$private$get_standard_error(), tolerance = 1e-6)
})

test_that("SUSPECTED BUG: zero-inflated Poisson gives a finite get_standard_error() under a marginal estimand but NA CI and p-value", {
	inf <- InferenceCountZeroInflatedPoisson$new(dc, verbose = FALSE); inf$set_estimand("marginal_mean_diff"); est <- inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_true(is.finite(est)); expect_true(is.finite(p$get_standard_error()))
	expect_true(all(is.na(inf$compute_asymp_confidence_interval()))); expect_true(is.na(inf$compute_asymp_two_sided_pval()))
})

test_that("consistent classes: the standard error equals the Wald CI half-width divided by z (binomial identity, hurdle Poisson)", {
	b <- InferenceIncidBinomialIdentityRiskDiff$new(di, verbose = FALSE); b$set_estimand("marginal_mean_diff"); b$compute_estimate()
	expect_equal(b$.__enclos_env__$private$get_standard_error(), ci_half(b), tolerance = 1e-6)
	h <- InferenceCountHurdlePoisson$new(dc, verbose = FALSE); h$set_estimand("marginal_mean_diff"); h$compute_estimate()
	expect_equal(h$.__enclos_env__$private$get_standard_error(), ci_half(h), tolerance = 1e-6)
})

test_that("marginal_ratio: hurdle Poisson is consistent (p-value from SE); logistic / ZIP repeat the same inconsistent SE as under the mean difference", {
	get_se <- function(cls, data, est) { inf <- cls$new(data, verbose = FALSE); inf$set_estimand(est); inf$compute_estimate(); list(inf = inf, se = inf$.__enclos_env__$private$get_standard_error()) }
	h <- get_se(InferenceCountHurdlePoisson, dc, "marginal_ratio")
	expect_equal(h$inf$compute_asymp_two_sided_pval(), 2 * pnorm(-abs(h$inf$compute_estimate() / h$se)), tolerance = 1e-6)
	expect_equal(h$se, ci_half(h$inf), tolerance = 1e-6)
	for (spec in list(list(InferenceIncidLogRegr, di), list(InferenceCountZeroInflatedPoisson, dc))) {
		a <- get_se(spec[[1]], spec[[2]], "marginal_mean_diff")$se; b <- get_se(spec[[1]], spec[[2]], "marginal_ratio")$se
		expect_equal(a, b, tolerance = 1e-8)                                   # identical for both estimands: it is the estimand-independent (conditional) SE
	}
	l <- get_se(InferenceIncidLogRegr, di, "marginal_ratio")
	expect_gt(l$se, 1.5 * ci_half(l$inf))                                      # while the CI half-width (marginal delta SE) is much smaller
})

test_that("Poisson: p-value and CI are finite under both marginal estimands even though get_standard_error() is NA", {
	for (est in c("marginal_mean_diff", "marginal_ratio")) {
		inf <- InferenceCountPoisson$new(dc, verbose = FALSE); inf$set_estimand(est); inf$compute_estimate()
		expect_true(is.na(inf$.__enclos_env__$private$get_standard_error()), info = est)
		expect_true(all(is.finite(inf$compute_asymp_confidence_interval())), info = est)
		expect_true(is.finite(inf$compute_asymp_two_sided_pval()), info = est)
	}
})
