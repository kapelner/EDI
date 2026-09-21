library(testthat)
library(EDI)

# InferenceSurvivalWeibullRegr's kernel dispatchers weibull_kernel_fit / weibull_kernel_score /
# weibull_kernel_hessian: right-censored/exact data use the ordinary kernels, interval/left-
# censored data (has_general_censoring) the general ones. References: a hand-written Weibull AFT
# log-likelihood, numDeriv gradient / Hessian of it, and survival::survreg.

skip_if_not_installed("numDeriv")

hand_ll_rc <- function(par, X, y, dead) {
	k <- ncol(X); b <- par[seq_len(k)]; s <- exp(par[k + 1L])
	z <- (log(y) - drop(X %*% b)) / s
	sum(ifelse(dead == 1, -log(s) - log(y) + z - exp(z), -exp(z)))
}
hand_ll_gen <- function(par, X, y, yL, yR) {
	k <- ncol(X); b <- par[seq_len(k)]; s <- exp(par[k + 1L])
	eta <- drop(X %*% b)
	S <- function(t) exp(-exp((log(t) - eta) / s))
	ll <- numeric(length(eta))
	ex <- !is.na(y)
	z <- (log(y[ex]) - eta[ex]) / s
	ll[ex] <- -log(s) - log(y[ex]) + z - exp(z)
	ic <- !ex
	SLfull <- ifelse(yL <= 0 | is.na(yL), 1, S(pmax(yL, 1e-300)))
	SRfull <- ifelse(is.infinite(yR) | is.na(yR), 0, S(pmax(yR, 1e-300)))
	ll[ic] <- log(pmax(SLfull[ic] - SRfull[ic], 1e-300))
	sum(ll)
}

right_cens <- function() {
	set.seed(2)
	n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t <- rweibull(n, 1.5, exp(1 + 0.4 * w + 0.3 * X$x))
	cens <- runif(n, 0, quantile(t, 0.8))
	y <- pmin(t, cens); dead <- as.numeric(t <= cens)
	des$add_all_subject_responses(ifelse(dead == 1, y, NA), ifelse(dead == 0, y, NA), ifelse(dead == 0, Inf, NA))
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(p = inf$.__enclos_env__$private, y = y, dead = dead, X = cbind(1, w, X$x), w = w, x = X$x)
}

test_that("ordinary path: the fit equals survreg's MLE and the hand log-likelihood at its optimum", {
	f <- right_cens()
	expect_false(isTRUE(f$p$has_general_censoring))
	r <- f$p$weibull_kernel_fit(f$X, f$y, f$dead, estimate_only = FALSE)
	sr <- survival::survreg(survival::Surv(f$y, f$dead) ~ f$w + f$x, dist = "weibull")
	expect_equal(as.numeric(r$params), c(unname(coef(sr)), log(sr$scale)), tolerance = 1e-4)
	expect_equal(as.numeric(r$loglik), hand_ll_rc(r$params, f$X, f$y, f$dead), tolerance = 1e-6)
	# Both fits reach the same value of the hand-written objective (the MLE).
	expect_equal(hand_ll_rc(r$params, f$X, f$y, f$dead), hand_ll_rc(c(unname(coef(sr)), log(sr$scale)), f$X, f$y, f$dead), tolerance = 1e-6)
})

test_that("ordinary path: score and Hessian equal numDeriv's gradient and Hessian of the hand log-likelihood", {
	f <- right_cens()
	set.seed(3)
	par <- c(1.1, 0.2, 0.45, -0.3) + rnorm(4, sd = 0.05)
	sc <- f$p$weibull_kernel_score(f$X, f$y, f$dead, par)
	hs <- f$p$weibull_kernel_hessian(f$X, f$y, f$dead, par)
	expect_equal(as.numeric(sc), numDeriv::grad(hand_ll_rc, par, X = f$X, y = f$y, dead = f$dead), tolerance = 1e-4)
	expect_equal(unname(hs), numDeriv::hessian(hand_ll_rc, par, X = f$X, y = f$y, dead = f$dead), tolerance = 1e-3)
	# At the fitted MLE the score vanishes.
	r <- f$p$weibull_kernel_fit(f$X, f$y, f$dead, estimate_only = FALSE)
	expect_lt(max(abs(f$p$weibull_kernel_score(f$X, f$y, f$dead, r$params))), 1e-3)
})

interval_design <- function() {
	set.seed(4)
	n <- 60L
	des <- DesignFixediBCRD$new(n = n, response_type = "survival", verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	t <- rweibull(n, 1.5, exp(1 + 0.4 * w + 0.3 * X$x))
	kind <- sample(c("exact", "right", "interval", "left"), n, TRUE, prob = c(0.4, 0.2, 0.25, 0.15))
	ys <- ifelse(kind == "exact", t, NA_real_)
	yL <- ifelse(kind == "right", t, ifelse(kind == "interval", t * 0.8, ifelse(kind == "left", 0, NA)))
	yR <- ifelse(kind == "right", Inf, ifelse(kind == "interval", t * 1.25, ifelse(kind == "left", t, NA)))
	des$add_all_subject_responses(ys, yL, yR)
	inf <- InferenceSurvivalWeibullRegr$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(p = inf$.__enclos_env__$private, ys = ys, yL = yL, yR = yR, X = cbind(1, w, X$x), w = w, x = X$x)
}

test_that("general-censoring path is selected and its fit / score / Hessian match the interval-likelihood references", {
	f <- interval_design()
	expect_true(isTRUE(f$p$has_general_censoring))
	yv <- f$p$y
	r <- f$p$weibull_kernel_fit(f$X, yv, f$p$dead, estimate_only = FALSE)
	# survreg with interval2 data as an independent fit.
	lo <- ifelse(is.na(f$ys), f$yL, f$ys); hi <- ifelse(is.na(f$ys), f$yR, f$ys)
	hi_s <- ifelse(is.infinite(hi), NA, hi); lo_s <- ifelse(lo <= 0, NA, lo)
	sr <- survival::survreg(survival::Surv(lo_s, hi_s, type = "interval2") ~ f$w + f$x, dist = "weibull")
	expect_equal(as.numeric(r$params), c(unname(coef(sr)), log(sr$scale)), tolerance = 1e-3)
	par <- as.numeric(r$params) + c(0.05, -0.03, 0.02, 0.04)
	sc <- f$p$weibull_kernel_score(f$X, yv, f$p$dead, par)
	hs <- f$p$weibull_kernel_hessian(f$X, yv, f$p$dead, par)
	ref_ll <- function(p) hand_ll_gen(p, f$X, f$ys, f$yL, f$yR)
	expect_equal(as.numeric(sc), numDeriv::grad(ref_ll, par), tolerance = 1e-3)
	expect_equal(unname(hs), numDeriv::hessian(ref_ll, par), tolerance = 1e-2)
})
