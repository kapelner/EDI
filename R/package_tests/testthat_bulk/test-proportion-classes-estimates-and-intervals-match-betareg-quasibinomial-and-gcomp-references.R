library(testthat)
library(EDI)

# Class-level proportion results against independent fits: the beta-regression class equals
# betareg's treatment coefficient and confint, the fractional-logit class equals the quasi-binomial glm
# (estimate and SE), the zero-one-inflated beta class is close to beta regression on data with no 0/1 mass,
# the g-computation mean-difference class equals the standardized difference from the quasi-binomial fit and
# the beta class' marginal_mean_diff estimand equals the standardized difference from the betareg fit, and
# the quantile-regression class works on the LOGIT scale (near rq(logit(y)), far from rq(y)).

skip_if_not_installed("betareg")
skip_if_not_installed("quantreg")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "proportion", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	mu <- plogis(-0.2 + 0.5 * w + 0.4 * x)
	y <- rbeta(n, mu * 8, (1 - mu) * 8)
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = y, w = w, x = x), x = x, n = n)
}
new_inf <- function(cls, des) {
	inf <- K(cls)$new(des, verbose = FALSE)
	if (is.function(inf$set_estimand)) inf$set_estimand("conditional")
	inf
}
std_diff <- function(pred_fun, x) mean(pred_fun(data.frame(w = 1, x = x))) - mean(pred_fun(data.frame(w = 0, x = x)))

test_that("beta-regression class equals betareg: estimate and Wald interval", {
	f <- fx()
	br <- betareg::betareg(y ~ w + x, data = f$d)
	inf <- new_inf("InferencePropBetaRegr", f$des)
	expect_equal(unname(inf$compute_estimate()), unname(coef(br)["w"]), tolerance = 1e-4)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(confint(br)["w", ]), tolerance = 1e-3)
})

test_that("fractional-logit class equals the quasi-binomial glm: estimate, SE, interval", {
	f <- fx()
	g <- glm(y ~ w + x, family = quasibinomial, data = f$d)
	inf <- new_inf("InferencePropFractionalLogit", f$des)
	s <- summary(g)$coefficients["w", ]
	expect_equal(unname(inf$compute_estimate()), unname(coef(g)["w"]), tolerance = 1e-6)
	expect_equal(inf$.__enclos_env__$private$get_standard_error(), unname(s[2]), tolerance = 1e-5)
	expect_equal(unname(inf$compute_asymp_confidence_interval(0.05)), unname(coef(g)["w"] + c(-1, 1) * qnorm(0.975) * s[2]), tolerance = 1e-5)
})

test_that("zero-one-inflated beta is close to plain beta regression when there are no boundary values", {
	f <- fx()
	expect_equal(unname(new_inf("InferencePropZeroOneInflatedBetaRegr", f$des)$compute_estimate()),
		unname(new_inf("InferencePropBetaRegr", f$des)$compute_estimate()), tolerance = 5e-3, scale = 1)
})

test_that("g-computation classes report standardized mean differences", {
	f <- fx()
	g <- glm(y ~ w + x, family = quasibinomial, data = f$d)
	expect_equal(unname(K("InferencePropGCompMeanDiff")$new(f$des, verbose = FALSE)$compute_estimate()),
		std_diff(function(nd) predict(g, nd, type = "response"), f$x), tolerance = 1e-4)
	br <- betareg::betareg(y ~ w + x, data = f$d)
	inf <- K("InferencePropBetaRegr")$new(f$des, verbose = FALSE)
	inf$set_estimand("marginal_mean_diff")
	expect_equal(unname(inf$compute_estimate()), std_diff(function(nd) predict(br, nd, type = "response"), f$x), tolerance = 1e-4)
})

test_that("quantile-regression class works on the logit scale", {
	f <- fx()
	est <- unname(new_inf("InferencePropQuantileRegr", f$des)$compute_estimate())
	logit_fit <- unname(suppressWarnings(coef(quantreg::rq(qlogis(y) ~ w + x, tau = 0.5, data = transform(f$d, y = f$d$y)))["w"]))
	raw_fit <- unname(suppressWarnings(coef(quantreg::rq(y ~ w + x, tau = 0.5, data = f$d))["w"]))
	expect_lt(abs(est - logit_fit), 0.05)         # median-regression solutions on the logit scale (solver-dependent within a flat set)
	expect_gt(abs(est - raw_fit), 0.3)            # nowhere near the raw-scale fit
})
