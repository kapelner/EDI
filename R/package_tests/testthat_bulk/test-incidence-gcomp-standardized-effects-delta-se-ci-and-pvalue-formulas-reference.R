library(testthat)
library(EDI)
skip_if_not_installed("sandwich")

# InferenceIncidGCompRiskDiff / RiskRatio private effect helpers: standardized risks, RD, log RR, delta-method SEs from the
# HC0 sandwich of the logistic fit, get_effect_estimate(), compute_effect_confidence_interval(alpha) and
# compute_effect_pvalue(delta) (formulas checked with injected cache values), default null values and the RR delta guard.
# References: stats::glm + sandwich::vcovHC(HC0) + hand-computed gradients.

set.seed(5); n <- 150L
X <- data.frame(x1 = rnorm(n), x2 = runif(n))
d <- DesignFixedBernoulli$new(response_type = "incidence", n = n, seed = 1L, verbose = FALSE)
d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
y <- rbinom(n, 1, plogis(-0.3 + 0.8 * w + 0.5 * X$x1)); d$add_all_subject_responses(y)
dat <- data.frame(y, w, X)
mk <- function(cls) { inf <- cls$new(d, verbose = FALSE); list(inf = inf, p = inf$.__enclos_env__$private) }
rd <- mk(InferenceIncidGCompRiskDiff); rr <- mk(InferenceIncidGCompRiskRatio)
rd$inf$compute_estimate(); rr$inf$compute_estimate()

fit <- glm(y ~ w + x1 + x2, data = dat, family = binomial)
Xm <- model.matrix(fit); X1 <- Xm; X1[, "w"] <- 1; X0 <- Xm; X0[, "w"] <- 0
b <- coef(fit); m1 <- plogis(X1 %*% b); m0 <- plogis(X0 %*% b)
r1 <- mean(m1); r0 <- mean(m0)
V <- sandwich::vcovHC(fit, type = "HC0")
g_rd <- colMeans(as.numeric(m1 * (1 - m1)) * X1 - as.numeric(m0 * (1 - m0)) * X0)
g_lrr <- colMeans(as.numeric(m1 * (1 - m1)) * X1) / r1 - colMeans(as.numeric(m0 * (1 - m0)) * X0) / r0

test_that("standardized risks, RD and RR equal the g-computation of the logistic fit", {
	cv <- rd$p$cached_values
	expect_equal(cv$risk1, r1, tolerance = 1e-6); expect_equal(cv$risk0, r0, tolerance = 1e-6)
	expect_equal(cv$rd, r1 - r0, tolerance = 1e-6); expect_equal(cv$log_rr, log(r1 / r0), tolerance = 1e-6); expect_equal(cv$rr, r1 / r0, tolerance = 1e-6)
	expect_equal(rd$inf$compute_estimate(), r1 - r0, tolerance = 1e-6); expect_equal(rr$inf$compute_estimate(), r1 / r0, tolerance = 1e-6)
	expect_identical(rd$p$get_estimand_type(), "RD"); expect_identical(rr$p$get_estimand_type(), "RR")
	expect_equal(rd$p$get_effect_estimate(), r1 - r0, tolerance = 1e-6); expect_equal(rr$p$get_effect_estimate(), r1 / r0, tolerance = 1e-6)
})

test_that("delta-method SEs use the HC0 sandwich covariance of the coefficients", {
	expect_equal(rd$p$cached_values$se_rd, sqrt(drop(t(g_rd) %*% V %*% g_rd)), tolerance = 1e-4)
	expect_equal(rd$p$cached_values$se_log_rr, sqrt(drop(t(g_lrr) %*% V %*% g_lrr)), tolerance = 1e-4)
	expect_equal(unname(rd$p$cached_values$full_vcov), unname(V), tolerance = 1e-4)
	expect_equal(unname(rd$p$cached_values$full_coefficients), unname(b), tolerance = 1e-6)
})

test_that("default null values: 0 for RD, 1 for RR", {
	expect_equal(rd$p$default_null_value(), 0); expect_equal(rr$p$default_null_value(), 1)
})

test_that("CI formulas with injected values: RD is est +/- z*se; RR exponentiates the log-scale interval; names are percent labels", {
	g <- mk(InferenceIncidGCompRiskDiff)
	g$p$cached_values[c("rd", "se_rd", "log_rr", "se_log_rr")] <- list(0.2, 0.05, log(1.5), 0.1)
	for (a in c(0.1, 0.05)) {
		z <- qnorm(1 - a / 2)
		ci <- g$p$compute_effect_confidence_interval(a)
		expect_equal(unname(ci), 0.2 + c(-1, 1) * z * 0.05, tolerance = 1e-12)
		expect_identical(names(ci), paste0(c(a / 2, 1 - a / 2) * 100, "%"))
	}
	h <- mk(InferenceIncidGCompRiskRatio)
	h$p$cached_values[c("rd", "se_rd", "log_rr", "se_log_rr")] <- list(0.2, 0.05, log(1.5), 0.1)
	expect_equal(unname(h$p$compute_effect_confidence_interval(0.05)), exp(log(1.5) + c(-1, 1) * qnorm(0.975) * 0.1), tolerance = 1e-12)
})

test_that("CI is NA when the estimate or SE is unusable (non-finite, zero SE)", {
	g <- mk(InferenceIncidGCompRiskDiff)
	for (v in list(list(NA_real_, 0.1), list(0.2, NA_real_), list(0.2, 0), list(0.2, -1), list(Inf, 0.1))) {
		g$p$cached_values[c("rd", "se_rd")] <- v
		expect_true(all(is.na(g$p$compute_effect_confidence_interval(0.05))))
	}
	h <- mk(InferenceIncidGCompRiskRatio); h$p$cached_values[c("log_rr", "se_log_rr")] <- list(0.1, 0)
	expect_true(all(is.na(h$p$compute_effect_confidence_interval(0.05))))
})

test_that("p-values: two-sided normal on (est - delta)/se for RD and (log RR - log delta)/se for RR; NULL delta uses the default null", {
	g <- mk(InferenceIncidGCompRiskDiff); g$p$cached_values[c("rd", "se_rd")] <- list(0.2, 0.05)
	expect_equal(g$p$compute_effect_pvalue(0.1), 2 * pnorm(-abs((0.2 - 0.1) / 0.05)), tolerance = 1e-12)
	expect_equal(g$p$compute_effect_pvalue(NULL), 2 * pnorm(-abs(0.2 / 0.05)), tolerance = 1e-12)
	h <- mk(InferenceIncidGCompRiskRatio); h$p$cached_values[c("log_rr", "se_log_rr")] <- list(log(1.5), 0.1)
	expect_equal(h$p$compute_effect_pvalue(1.2), 2 * pnorm(-abs((log(1.5) - log(1.2)) / 0.1)), tolerance = 1e-12)
	expect_equal(h$p$compute_effect_pvalue(NULL), 2 * pnorm(-abs(log(1.5) / 0.1)), tolerance = 1e-12)
	g$p$cached_values$se_rd <- 0; expect_true(is.na(g$p$compute_effect_pvalue(0)))
})

test_that("RR inference requires a strictly positive null ratio; the class p-value/CI agree with the private helpers", {
	expect_error(rr$p$compute_effect_pvalue(0), "delta must be strictly positive")
	expect_error(rr$p$compute_effect_pvalue(-1), "delta must be strictly positive")
	expect_equal(rd$inf$compute_asymp_two_sided_pval(), rd$p$compute_effect_pvalue(NULL), tolerance = 1e-12)
	expect_equal(unname(rr$inf$compute_asymp_confidence_interval()), unname(rr$p$compute_effect_confidence_interval(0.05)), tolerance = 1e-12)
})
