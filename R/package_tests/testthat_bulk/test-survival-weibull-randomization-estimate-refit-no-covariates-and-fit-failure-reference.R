library(testthat)
library(EDI)

# InferenceSurvivalWeibullRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_survival_weibull.R) had no test reference anywhere -- the same gap pattern already
# closed this session on several sibling classes across incidence/count/proportion/ordinal, extended
# here to the first survival-family class. Fully exact (uncensored) event times, the same fixture
# shape already used for InferenceSurvivalStratCoxPHRegr's happy-path acceptance test.
#   1. The covariate-adjusted refit on the current (and then a permuted) w matches an independent
#      survival::survreg(dist = "weibull") fit.
#   2. With no prior column selection (best_X_colnames still NULL), it calls shared() first.
#   3. With no covariates selected (model_formula = ~1), X = cbind((Intercept)=1, treatment=w) rather
#      than including covariate columns.
#   4. A fitter failure (res NULL, res$converged not TRUE, or non-finite res$b[2]) returns NA.

weibull_fixture <- function(seed = 1L, n = 100L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rweibull(n, shape = 1.5, scale = exp(1 + 0.4 * w + 0.3 * x))
	des$add_all_subject_responses(ys = y, y_Ls = rep(NA_real_, n), y_Rs = rep(NA_real_, n))
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, x = x, y = y, w = w)
}

weibull_no_cov_fixture <- function(seed = 2L, n = 100L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rweibull(n, shape = 1.5, scale = exp(1 + 0.4 * w))
	des$add_all_subject_responses(ys = y, y_Ls = rep(NA_real_, n), y_Rs = rep(NA_real_, n))
	inf <- InferenceSurvivalWeibullRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, w = w)
}

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment, matching survreg(weibull)", {
	f <- weibull_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x1")
	y <- f$y; w <- f$w; x <- f$x

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(survival::survreg(survival::Surv(y, rep(1, length(y))) ~ w + x, dist = "weibull"))["w"])
	expect_equal(est, ref, tolerance = 1e-4)

	set.seed(9)
	w2 <- sample(w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(survival::survreg(survival::Surv(y, rep(1, length(y))) ~ w2 + x, dist = "weibull"))["w2"])
	expect_equal(est2, ref2, tolerance = 1e-4)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- weibull_fixture(seed = 3L)
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
})

test_that("with no covariates selected, the refit uses cbind(1, treatment = w) and matches survreg(y ~ w, weibull)", {
	f <- weibull_no_cov_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, character(0))
	y <- f$y; w <- f$w

	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(survival::survreg(survival::Surv(y, rep(1, length(y))) ~ w, dist = "weibull"))["w"])
	expect_equal(est, ref, tolerance = 1e-4)
})

test_that("a fitter failure (res NULL, not converged, or non-finite res$b[2]) returns NA", {
	f <- weibull_fixture(seed = 4L)
	f$inf$compute_estimate()
	p <- f$priv
	unlockBinding("weibull_kernel_fit", p)
	p$weibull_kernel_fit <- function(...) NULL
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	p$weibull_kernel_fit <- function(...) list(converged = FALSE, b = c(0, 0.5), log_sigma = 0, fisher_information = diag(3))
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))

	p$weibull_kernel_fit <- function(...) list(converged = TRUE, b = c(0, NA_real_), log_sigma = 0, fisher_information = diag(3))
	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})
