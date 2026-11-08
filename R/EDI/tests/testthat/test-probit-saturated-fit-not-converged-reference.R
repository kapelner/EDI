library(testthat)
library(EDI)

# TODO-181 (a) (v1.0.5): fast_probit_regression's IRLS / LBFGS reported converged = TRUE at a
# saturated fit. pnorm_fast() is clamped at |eta| >= 8 and dnorm_fast() underflows past ~38, so
# beyond that the computed probit likelihood is flat and the score is exactly 0: an absurd warm
# start (intercept 460900, stored by an InferenceIncidProbitRegr null refit during the TODO-177
# investigation) or an IRLS overshoot "converged" there with gradient_norm = 0, although every
# y = 0 row had fitted probability 1. A fit is now converged only if it is finite and no row is
# saturated against its own outcome (y = 1 with eta <= -8, y = 0 with eta >= 8).

todo181_probit_fixture <- function() {
	set.seed(181L)
	n <- 100L
	w <- rep(0:1, n / 2L)
	x <- stats::rnorm(n)
	y <- stats::rbinom(n, 1L, stats::pnorm(-0.2 + 0.4 * x))
	list(X = cbind(1, w, x), y = as.numeric(y))
}

test_that("an absurd warm start no longer reports convergence at the saturated plateau (IRLS)", {
	d <- todo181_probit_fixture()
	for (st in list(c(460900, 0, 0), c(40, 0, 0), c(-40, 0, 0))) {
		f <- fast_probit_regression_cpp(d$X, d$y, warm_start_beta = st)
		expect_false(f$converged, info = paste(st, collapse = ","))
		f_null <- fast_probit_regression_with_var_cpp(X = d$X, y = d$y, j = 2L, warm_start_beta = st, fixed_idx = 2L, fixed_values = 0)
		expect_false(f_null$converged, info = paste(st, collapse = ","))
	}
})

test_that("the same saturated start is not reported as converged by the LBFGS path or the weighted kernel", {
	d <- todo181_probit_fixture()
	f <- fast_probit_regression_cpp(d$X, d$y, warm_start_beta = c(460900, 0, 0), optimization_alg = "lbfgs")
	expect_false(f$converged)
	fw <- fast_probit_regression_weighted_cpp(d$X, d$y, rep(1, length(d$y)), warm_start_beta = c(460900, 0, 0))
	expect_false(fw$converged)
})

test_that("a treatment coefficient fixed deep in the clamp region is not a converged null fit", {
	d <- todo181_probit_fixture()
	f <- fast_probit_regression_with_var_cpp(X = d$X, y = d$y, j = 2L, fixed_idx = 2L, fixed_values = 1782)
	expect_false(f$converged)
})

test_that("ordinary fits are unchanged: converged, and equal to glm(probit)", {
	d <- todo181_probit_fixture()
	ref <- stats::glm(d$y ~ d$X[, -1], family = stats::binomial(link = "probit"))
	for (alg in c("irls", "lbfgs")) {
		f <- fast_probit_regression_cpp(d$X, d$y, optimization_alg = alg)
		expect_true(f$converged, info = alg)
		expect_equal(as.numeric(f$b), unname(stats::coef(ref)), tolerance = 1e-5, info = alg)
	}
	f0 <- fast_probit_regression_with_var_cpp(X = d$X, y = d$y, j = 2L, fixed_idx = 2L, fixed_values = 0)
	expect_true(f0$converged)
})

test_that("calibration fixture (incidence, n = 200, Bernoulli, rep 1, ~1): the stored absurd start is rejected", {
	# Seed formula of cal_run_rep() in R/package_tests/calibration/calibration_fast_tier_common.R
	# (cal_rt_index("incidence") = 2, n = 200, null effect).
	set.seed(1e6 * 2L + 7L * 200L + 1L)
	X <- data.frame(x1 = stats::rnorm(200), x2 = stats::rbinom(200, 1L, 0.5))
	des <- DesignFixedBernoulli$new(n = 200, response_type = "incidence")
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(ys = stats::rbinom(200, 1L, stats::plogis(-0.5 + 0.5 * X$x1 + 0.5 * X$x2)))
	o <- InferenceIncidProbitRegr$new(des, model_formula = ~1)
	spec <- o$.__enclos_env__$private$get_likelihood_test_spec()
	expect_false(isTRUE(spec$fit_null(0, start = c(460900, 0))$converged))
	cold <- spec$fit_null(0, start = NULL)
	expect_true(cold$converged)
	expect_lt(abs(cold$b[1]), 1)
})
