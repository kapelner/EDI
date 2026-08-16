library(testthat)
library(EDI)

# interval_censored_survival_response.md TODO-3: WeibullAFTLikelihood extended
# with a single censored branch log(S(y_L) - S(y_R)), valid uniformly for
# right- (y_R = Inf), left- (y_L = 0), and interval-censored rows. These tests
# verify the algebraic reductions numerically rather than trusting the algebra
# (per the TODO's own instruction), and confirm zero regression against the
# survival::survreg on exact/right-censored data.

test_that("general kernel score/Hessian match numDeriv on mixed exact/left/interval/right data", {
	skip_if_not_installed("numDeriv")
	set.seed(101)
	n <- 24L
	X <- cbind(1, rnorm(n), runif(n, -1, 1))
	params <- c(0.2, -0.15, 0.1, log(0.8))

	beta <- params[seq_len(ncol(X))]
	log_sigma0 <- params[ncol(X) + 1L]
	eta0 <- drop(X %*% beta)
	true_time <- exp(eta0 + exp(log_sigma0) * log(-log(1 - runif(n))))

	kind <- rep(c("exact", "left", "interval", "right"), length.out = n)
	y <- ifelse(kind == "exact", true_time, NA_real_)
	y_L <- ifelse(kind == "left", 0,
	         ifelse(kind == "interval", pmax(true_time - 0.3, 0.01),
	           ifelse(kind == "right", true_time * 0.8, NA_real_)))
	y_R <- ifelse(kind == "left", true_time * 1.5,
	         ifelse(kind == "interval", true_time + 0.3,
	           ifelse(kind == "right", Inf, NA_real_)))

	nll <- function(par) {
		eta <- drop(X %*% par[seq_len(ncol(X))])
		log_sigma <- par[ncol(X) + 1L]
		sigma <- exp(log_sigma)
		ll <- numeric(n)
		for (i in seq_len(n)) {
			if (is.finite(y[i])) {
				w <- min((log(y[i]) - eta[i]) / sigma, 700)
				ll[i] <- w - log_sigma - log(y[i]) - exp(w)
			} else {
				a <- if (y_L[i] <= 0) -Inf else (log(y_L[i]) - eta[i]) / sigma
				b <- if (!is.finite(y_R[i])) Inf else (log(y_R[i]) - eta[i]) / sigma
				S_L <- if (is.infinite(a)) 1 else exp(-exp(a))
				S_R <- if (is.infinite(b)) 0 else exp(-exp(b))
				ll[i] <- log(S_L - S_R)
			}
		}
		-sum(ll)
	}

	score <- EDI:::get_weibull_regression_general_score_cpp(X, y, y_L, y_R, params)
	hessian <- EDI:::get_weibull_regression_general_hessian_cpp(X, y, y_L, y_R, params)
	expect_equal(
		as.numeric(score),
		as.numeric(-numDeriv::grad(nll, params)),
		tolerance = 1e-6
	)
	expect_equal(
		unname(hessian),
		unname(-numDeriv::hessian(nll, params)),
		tolerance = 1e-4
	)
})

test_that("general kernel matches survival::survreg on exact/right-censored data", {
	skip_if_not_installed("survival")
	set.seed(102)
	n <- 50L
	X <- cbind(1, rnorm(n))
	y_raw <- rexp(n, 0.3)
	dead <- rbinom(n, 1, 0.65)

	y_gen <- ifelse(dead == 1, y_raw, NA_real_)
	y_L_gen <- ifelse(dead == 1, NA_real_, y_raw)
	y_R_gen <- ifelse(dead == 1, NA_real_, Inf)

	fit <- EDI:::fast_weibull_regression_general_cpp(X, y_gen, y_L_gen, y_R_gen)
	fit_ref <- survival::survreg(survival::Surv(y_raw, dead) ~ X[, 2L], dist = "weibull")
	expect_equal(as.numeric(fit$params[1:2]), as.numeric(stats::coef(fit_ref)), tolerance = 1e-4)
	expect_equal(as.numeric(fit$params[3L]), as.numeric(log(fit_ref$scale)), tolerance = 1e-4)
})

test_that("left-censored data recovers the generating coefficients", {
	set.seed(103)
	n <- 400L
	beta_true <- c(0.5, -0.3, 0.2)
	sigma_true <- 1.1
	X <- cbind(1, rnorm(n), rnorm(n))
	eta <- drop(X %*% beta_true)
	true_time <- exp(eta + sigma_true * log(-log(1 - runif(n))))

	thresh <- as.numeric(quantile(true_time, 0.3))
	y <- ifelse(true_time > thresh, true_time, NA_real_)
	y_L <- ifelse(true_time > thresh, NA_real_, 0)
	y_R <- ifelse(true_time > thresh, NA_real_, thresh)

	fit <- EDI:::fast_weibull_regression_general_cpp(X, y, y_L, y_R)
	expect_true(fit$converged)
	expect_equal(fit$params[seq_along(beta_true)], beta_true, tolerance = 0.3)
	expect_equal(fit$params[length(beta_true) + 1L], log(sigma_true), tolerance = 0.3)
})

test_that("interval-censored data recovers the generating coefficients", {
	set.seed(104)
	n <- 500L
	beta_true <- c(0.5, -0.3, 0.2)
	sigma_true <- 1.1
	X <- cbind(1, rnorm(n), rnorm(n))
	eta <- drop(X %*% beta_true)
	true_time <- exp(eta + sigma_true * log(-log(1 - runif(n))))

	g <- 0.5
	y_L <- floor(true_time / g) * g
	y_R <- y_L + g
	y <- rep(NA_real_, n)

	fit <- EDI:::fast_weibull_regression_general_cpp(X, y, y_L, y_R)
	expect_true(fit$converged)
	expect_equal(fit$params[seq_along(beta_true)], beta_true, tolerance = 0.3)
	expect_equal(fit$params[length(beta_true) + 1L], log(sigma_true), tolerance = 0.3)
})

test_that("right-censored score reduces to the -exp(w) likelihood", {
	skip_if_not_installed("numDeriv")
	X <- matrix(c(1, 1), ncol = 1)
	y_L <- c(2.5, 4.0)
	y_R <- c(Inf, Inf)
	y <- c(NA_real_, NA_real_)
	params <- c(0.3, log(1.4))

	score_general <- EDI:::get_weibull_regression_general_score_cpp(X, y, y_L, y_R, params)
	nll <- function(par) {
		eta <- drop(X %*% par[1L])
		sigma <- exp(par[2L])
		sum(exp((log(y_L) - eta) / sigma))
	}
	expect_equal(as.numeric(score_general), as.numeric(-numDeriv::grad(nll, params)), tolerance = 1e-8)
})
