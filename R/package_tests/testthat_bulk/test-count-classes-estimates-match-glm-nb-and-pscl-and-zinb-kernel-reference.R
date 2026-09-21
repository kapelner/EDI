library(testthat)
library(EDI)

# Class-level count estimates against independent fits: Poisson / quasi-Poisson / robust Poisson equal
# glm(poisson), the NB class equals MASS::glm.nb, and the zero-inflated / hurdle classes equal the pscl
# count-model treatment coefficients (same covariates in both parts). fast_zinb_cpp agrees with
# pscl::zeroinfl(dist = "negbin") -- coefficients, log theta and standard errors -- when the data really
# have excess zeros. Observation pinned (not asserted as a bug): when the data have NO zero inflation the
# ZINB class' estimate-only value exists but the full variance fit is declared unavailable
# ("zinb_fit_unavailable"), which also turns the estimate into NA afterwards.

skip_if_not_installed("pscl")
skip_if_not_installed("MASS")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(zero_inflated = FALSE) {
	set.seed(4)
	n <- 200L
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	x <- rnorm(n)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.6 + 0.4 * w + 0.3 * x))
	if (zero_inflated) { set.seed(5); z <- rbinom(n, 1, plogis(-0.5 + 0.6 * x)); y <- ifelse(z == 1, 0, y) }
	des$add_all_subject_responses(y)
	list(des = des, w = w, x = x, y = y, n = n, d = data.frame(y = y, w = w, x = x))
}
new_inf <- function(cls, des) {
	inf <- get(cls, envir = asNamespace("EDI"))$new(des, verbose = FALSE)
	if (is.function(inf$set_estimand)) inf$set_estimand("conditional")
	inf
}

test_that("Poisson-family classes equal glm(poisson) and the NB class equals glm.nb", {
	f <- fx()
	pois <- unname(coef(glm(y ~ w + x, family = poisson, data = f$d))["w"])
	for (cls in c("InferenceCountPoisson", "InferenceCountQuasiPoisson", "InferenceCountRobustPoisson")) {
		expect_equal(unname(new_inf(cls, f$des)$compute_estimate()), pois, tolerance = 1e-6, info = cls)
	}
	nb <- unname(coef(MASS::glm.nb(y ~ w + x, data = f$d))["w"])
	expect_equal(new_inf("InferenceCountNegBin", f$des)$compute_estimate(), nb, tolerance = 5e-3)
})

test_that("zero-inflated and hurdle classes equal the pscl count-model treatment coefficients", {
	f <- fx()
	ref <- c(
		InferenceCountZeroInflatedPoisson = coef(pscl::zeroinfl(y ~ w + x | w + x, data = f$d))[["count_w"]],
		InferenceCountHurdlePoisson = coef(pscl::hurdle(y ~ w + x | w + x, data = f$d, dist = "poisson"))[["count_w"]],
		InferenceCountHurdleNegBin = coef(pscl::hurdle(y ~ w + x | w + x, data = f$d, dist = "negbin"))[["count_w"]])
	for (cls in names(ref)) expect_equal(new_inf(cls, f$des)$compute_estimate(), unname(ref[cls]), tolerance = 2e-3, info = cls)
})

test_that("with true excess zeros, fast_zinb_cpp equals pscl::zeroinfl(negbin): coefficients, log theta and SEs; the ZINB class is stable", {
	f <- fx(zero_inflated = TRUE)
	X <- cbind(1, f$w, f$x)
	r <- K("fast_zinb_cpp")(X, X, as.numeric(f$y))
	zi <- pscl::zeroinfl(y ~ w + x | w + x, data = f$d, dist = "negbin")
	expect_true(r$converged)
	p <- as.numeric(r$params)
	expect_equal(p[1:6], unname(coef(zi)), tolerance = 5e-3)
	expect_equal(p[7], log(zi$theta), tolerance = 5e-3)
	expect_equal(unname(sqrt(diag(r$vcov)))[1:6], unname(sqrt(diag(vcov(zi)))), tolerance = 5e-3)
	expect_false(isTRUE(r$zero_inflation_at_boundary))
	inf <- new_inf("InferenceCountZeroInflatedNegBin", f$des)
	e1 <- inf$compute_estimate()
	expect_equal(e1, unname(coef(zi)[["count_w"]]), tolerance = 5e-3)
	ci <- suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.finite(ci)))
	expect_equal(inf$compute_estimate(), e1)                     # unchanged after the full fit
})

test_that("OBSERVATION (pinned): without excess zeros the ZINB class' full fit is unavailable and the estimate becomes NA afterwards", {
	f <- fx(zero_inflated = FALSE)
	inf <- new_inf("InferenceCountZeroInflatedNegBin", f$des)
	e1 <- inf$compute_estimate()
	expect_true(is.finite(e1))
	ci <- suppressWarnings(inf$compute_asymp_confidence_interval())
	expect_true(all(is.na(ci)))
	expect_true(is.na(inf$compute_estimate()))
	expect_true(inf$is_nonestimable("estimate"))
})
