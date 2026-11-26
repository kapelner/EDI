library(testthat)
library(EDI)

# v1.0.6-TODO-170: every EDI Cox point estimate uses Breslow ties (fast_coxph_regression.cpp,
# and the R fallbacks pinned to ties = "breslow"), but the weighted refits behind the Cox
# Bayesian bootstraps (weighted_cox_bootstrap_surrogate_fit() and kk_ivwc_weighted_cox_half()
# in globals.R) used survival::coxph()'s default Efron ties. On tied event times a replicate
# therefore fit a different partial likelihood from the estimate it resamples. These tests use
# a fixture with heavy ties and check that (1) the weighted refit with all weights 1 reproduces
# compute_estimate(), and (2) with non-uniform weights it matches
# survival::coxph(ties = "breslow", weights = w). The weights-are-constant short cut is mocked
# off so (1) really runs the weighted refit.

mk_tied_design <- function(seed = 3L, n = 40L) {
	set.seed(seed)
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	y <- ceiling(rexp(n, exp(0.5 * w)) * 4) # integer times: many tied events
	dead <- rbinom(n, 1, 0.85)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA), ifelse(dead == 0, y, NA), ifelse(dead == 0, Inf, NA))
	list(des = des, n = n, X = X, w = w, y = y, dead = dead)
}

fx <- mk_tied_design()

test_that("the fixture has tied event times, so Breslow and Efron differ", {
	ev <- fx$y[fx$dead == 1]
	expect_gt(length(ev) - length(unique(ev)), 10L)
	b <- coef(survival::coxph(survival::Surv(fx$y, fx$dead) ~ fx$w + fx$X$x1, ties = "breslow"))[1]
	e <- coef(survival::coxph(survival::Surv(fx$y, fx$dead) ~ fx$w + fx$X$x1, ties = "efron"))[1]
	expect_gt(abs(b - e), 1e-3)
})

test_that("weighted_cox_bootstrap_surrogate_fit() fits Breslow ties on every path", {
	set.seed(11)
	rw <- rexp(fx$n)
	Xm <- cbind(treatment = fx$w, x1 = fx$X$x1)
	strata <- rep(1:2, length.out = fx$n)
	cluster <- rep(seq_len(fx$n / 2), each = 2)
	dat <- data.frame(y = fx$y, dead = fx$dead, w = fx$w, x1 = fx$X$x1, s = strata, cl = cluster, rw = rw)
	ref <- function(extra = NULL) {
		f <- stats::as.formula(paste("survival::Surv(y, dead) ~ w + x1", if (!is.null(extra)) paste("+", extra)))
		as.numeric(coef(suppressWarnings(survival::coxph(f, data = dat, weights = rw, ties = "breslow")))[1])
	}
	# unstratified, unclustered: the coxph.fit() fast path
	fit <- EDI:::weighted_cox_bootstrap_surrogate_fit(fx$y, fx$dead, Xm, rw)
	expect_equal(fit$beta_hat, ref(), tolerance = 1e-7)
	# stratified and clustered: the formula path
	fit_s <- EDI:::weighted_cox_bootstrap_surrogate_fit(fx$y, fx$dead, Xm, rw, strata = strata)
	expect_equal(fit_s$beta_hat, ref("strata(s)"), tolerance = 1e-7)
	fit_c <- EDI:::weighted_cox_bootstrap_surrogate_fit(fx$y, fx$dead, Xm, rw, cluster = cluster)
	expect_equal(fit_c$beta_hat, ref("cluster(cl)"), tolerance = 1e-7)
	# all weights 1 reproduces the C++ (Breslow) fitter
	cpp <- EDI:::fast_coxph_regression_cpp(Xm, fx$y, fx$dead, estimate_only = TRUE)
	fit_1 <- EDI:::weighted_cox_bootstrap_surrogate_fit(fx$y, fx$dead, Xm, rep(1, fx$n))
	expect_equal(fit_1$beta_hat, as.numeric(cpp$coefficients[1]), tolerance = 1e-6)
	# Efron is still reachable explicitly (InferenceSurvivalDepCensTransformRegr's surrogate)
	fit_e <- EDI:::weighted_cox_bootstrap_surrogate_fit(fx$y, fx$dead, Xm, rw, ties = "efron")
	expect_equal(fit_e$beta_hat,
		as.numeric(coef(suppressWarnings(survival::coxph(survival::Surv(fx$y, fx$dead) ~ fx$w + fx$X$x1,
			weights = rw, ties = "efron")))[1]), tolerance = 1e-7)
})

test_that("kk_ivwc_weighted_cox_half() fits Breslow ties with the model-based variance", {
	set.seed(12)
	rw <- rexp(fx$n)
	Xm <- cbind(w = fx$w, x1 = fx$X$x1)
	half <- EDI:::kk_ivwc_weighted_cox_half(fx$y, fx$dead, list(Xm), rw)
	ref <- suppressWarnings(survival::coxph(survival::Surv(fx$y, fx$dead) ~ fx$w + fx$X$x1, weights = rw, ties = "breslow"))
	expect_equal(half$beta, as.numeric(coef(ref)[1]), tolerance = 1e-7)
	expect_equal(half$ssq, ref$naive.var[1, 1], tolerance = 1e-6)
})

test_that("KK Cox IVWC replicates with all weights 1 reproduce compute_estimate() on tied data", {
	local_mocked_bindings(weights_are_effectively_constant = function(...) FALSE, .package = "EDI")
	for (cls in c("InferenceSurvivalKKStratCoxPHIVWC", "InferenceSurvivalKKLWACoxPHIVWC")) {
		inf <- get(cls, envir = asNamespace("EDI"))$new(fx$des, verbose = FALSE)
		est <- as.numeric(inf$compute_estimate())[1]
		rep1 <- inf$.__enclos_env__$private$compute_weighted_estimate_ivwc(list(row_weights = rep(1, fx$n)), estimate_only = TRUE)
		expect_true(is.finite(est), info = cls)
		expect_equal(rep1, est, tolerance = 1e-6, info = cls)
	}
})

test_that("non-KK and KK one-likelihood Cox replicates with all weights 1 reproduce compute_estimate()", {
	local_mocked_bindings(weights_are_effectively_constant = function(...) FALSE, .package = "EDI")
	for (cls in c("InferenceSurvivalCoxPHRegr", "InferenceSurvivalStratCoxPHRegr",
			"InferenceSurvivalKKStratCoxPHOneLik", "InferenceSurvivalKKLWACoxPHOneLik")) {
		# StratCoxPHRegr warns that it ignores the matched pairs of a KK design; expected here.
		inf <- suppressWarnings(get(cls, envir = asNamespace("EDI"))$new(fx$des, verbose = FALSE))
		est <- as.numeric(inf$compute_estimate())[1]
		priv <- inf$.__enclos_env__$private
		ctx <- priv$build_bayesian_bootstrap_context()
		priv$current_bayesian_bootstrap_context <- ctx
		rep1 <- inf$compute_estimate_with_bootstrap_weights(rep(1, ctx$n_units), estimate_only = TRUE)
		expect_true(is.finite(est), info = cls)
		expect_equal(as.numeric(rep1)[1], est, tolerance = 1e-6, info = cls)
	}
})
