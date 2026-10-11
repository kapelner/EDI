library(testthat)
library(EDI)

# The first step has one candidate, so the native score statistic can be
# reconstructed from an independently fitted reduced Weibull model.  This is
# deliberately not a port of the native fitter: survreg supplies the MLE for
# beta and scale, then this file applies only the documented score-test
# arithmetic.
kk21_stepwise_weibull_score_reference <- function(x, time, event, treatment) {
	fit <- survival::survreg(
		survival::Surv(time, event) ~ treatment,
		dist = "weibull"
	)
	eta <- unname(coef(fit)["(Intercept)"] + coef(fit)["treatment"] * treatment)
	z <- (log(time) - eta) / fit$scale
	w <- exp(z)
	model <- cbind(1, treatment)
	v <- drop(crossprod(model, w * x))
	information <- sum(w * x^2) - drop(crossprod(v, solve(crossprod(model, w * model), v)))
	abs(sum(x * (event - w)) / sqrt(information))
}

test_that("native KK21 stepwise survival score is evaluated at the Weibull MLE", {
	set.seed(6721)
	n <- 120L
	treatment <- rep(0:1, length.out = n)
	x <- rnorm(n)
	time <- rweibull(n, shape = 1.4, scale = exp(0.35 * treatment + 0.55 * x))

	for (event in list(censored = rbinom(n, 1L, 0.8), uncensored = rep(1L, n))) {
		expected <- kk21_stepwise_weibull_score_reference(x, time, event, treatment)
		actual <- EDI:::kk21_stepwise_survival_weights_cpp(
			matrix(x, ncol = 1L), time, event, treatment
		)
		expect_equal(unname(actual[1L]), expected, tolerance = 1e-5)
	}
})
