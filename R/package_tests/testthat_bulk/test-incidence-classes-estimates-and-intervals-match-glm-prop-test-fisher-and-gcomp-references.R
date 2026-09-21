library(testthat)
library(EDI)

# Class-level incidence results against independent references: logistic / probit / log-binomial /
# modified-Poisson classes equal the corresponding glm treatment coefficients, the risk-difference regression
# class equals the OLS coefficient, the Wald class equals the crude risk difference with prop.test's
# uncorrected interval and the Wald z p-value, the Newcombe class' interval is the hybrid-Wilson formula,
# the exact-Fisher class reports log of fisher.test's conditional odds ratio with its exact interval, and the
# g-computation classes equal the standardized risk difference / ratio from the logistic fit.

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 300L
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.numeric(rbinom(n, 1, plogis(-0.4 + 0.7 * w + 0.5 * x)))
	des$add_all_subject_responses(y)
	list(des = des, w = w, x = x, y = y, n = n)
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)
wilson <- function(x, n, a = 0.05) unname(prop.test(x, n, conf.level = 1 - a, correct = FALSE)$conf.int[1:2])

test_that("regression classes equal the matching glm / lm treatment coefficients", {
	f <- fx()
	d <- data.frame(y = f$y, w = f$w, x = f$x)
	expect_equal(unname(new_inf("InferenceIncidLogRegr", f$des)$compute_estimate()), unname(coef(glm(y ~ w + x, family = binomial, data = d))["w"]), tolerance = 1e-6)
	expect_equal(unname(new_inf("InferenceIncidProbitRegr", f$des)$compute_estimate()), unname(coef(glm(y ~ w + x, family = binomial("probit"), data = d))["w"]), tolerance = 1e-5)
	expect_equal(unname(new_inf("InferenceIncidRiskDiff", f$des)$compute_estimate()), unname(coef(lm(y ~ w + x, data = d))["w"]), tolerance = 1e-8)
	expect_equal(unname(new_inf("InferenceIncidModifiedPoisson", f$des)$compute_estimate()), unname(coef(suppressWarnings(glm(y ~ w + x, family = poisson, data = d)))["w"]), tolerance = 1e-5)
	expect_equal(unname(new_inf("InferenceIncidLogBinomial", f$des)$compute_estimate()), unname(coef(suppressWarnings(glm(y ~ w + x, family = binomial("log"), data = d, start = c(-1, 0, 0))))["w"]), tolerance = 1e-4)
})

test_that("Wald class: crude risk difference, prop.test's uncorrected CI, and the Wald z p-value", {
	f <- fx()
	inf <- new_inf("InferenceIncidWald", f$des)
	p1 <- mean(f$y[f$w == 1]); p0 <- mean(f$y[f$w == 0]); n1 <- sum(f$w == 1); n0 <- sum(f$w == 0)
	rd <- p1 - p0; se <- sqrt(p1 * (1 - p1) / n1 + p0 * (1 - p0) / n0)
	expect_equal(unname(inf$compute_estimate()), rd, tolerance = 1e-12)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(prop.test(c(sum(f$y[f$w == 1]), sum(f$y[f$w == 0])), c(n1, n0), correct = FALSE)$conf.int[1:2]), tolerance = 1e-8)
	expect_equal(inf$compute_asymp_two_sided_pval(0), 2 * pnorm(-abs(rd / se)), tolerance = 1e-8)
})

test_that("Newcombe and Miettinen-Nurminen classes share the crude risk difference; Newcombe's interval is the hybrid-Wilson interval", {
	f <- fx()
	n1 <- sum(f$w == 1); n0 <- sum(f$w == 0); x1 <- sum(f$y[f$w == 1]); x0 <- sum(f$y[f$w == 0])
	rd <- x1 / n1 - x0 / n0
	nw <- new_inf("InferenceIncidNewcombeRiskDiff", f$des)
	expect_equal(unname(nw$compute_estimate()), rd, tolerance = 1e-12)
	w1 <- wilson(x1, n1); w0 <- wilson(x0, n0); p1 <- x1 / n1; p0 <- x0 / n0
	hyb <- c(rd - sqrt((p1 - w1[1])^2 + (w0[2] - p0)^2), rd + sqrt((w1[2] - p1)^2 + (p0 - w0[1])^2))
	expect_equal(unname(nw$compute_asymp_confidence_interval(0.05)), hyb, tolerance = 1e-8)
	mn <- new_inf("InferenceIncidMiettinenNurminenRiskDiff", f$des)
	expect_equal(unname(mn$compute_estimate()), rd, tolerance = 1e-12)
	ci <- unname(mn$compute_asymp_confidence_interval(0.05))
	expect_true(ci[1] < rd && rd < ci[2])
	expect_lt(abs(ci[1] - hyb[1]), 0.01); expect_lt(abs(ci[2] - hyb[2]), 0.01)      # score and hybrid intervals are close
})

test_that("exact-Fisher class reports log of fisher.test's conditional odds ratio and its exact interval", {
	f <- fx()
	ft <- fisher.test(table(f$w, f$y))
	inf <- new_inf("InferenceIncidExactFisher", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(log(ft$estimate)), tolerance = 1e-6)
	expect_equal(as.numeric(inf$compute_exact_confidence_interval()), as.numeric(log(ft$conf.int)), tolerance = 1e-5)
})

test_that("g-computation classes equal the standardized risk difference / ratio from the logistic fit", {
	f <- fx()
	d <- data.frame(y = f$y, w = f$w, x = f$x)
	g <- glm(y ~ w + x, family = binomial, data = d)
	p1 <- mean(predict(g, data.frame(w = 1, x = f$x), type = "response")); p0 <- mean(predict(g, data.frame(w = 0, x = f$x), type = "response"))
	expect_equal(unname(new_inf("InferenceIncidGCompRiskDiff", f$des)$compute_estimate()), p1 - p0, tolerance = 1e-6)
	expect_equal(unname(new_inf("InferenceIncidGCompRiskRatio", f$des)$compute_estimate()), p1 / p0, tolerance = 1e-6)
})
