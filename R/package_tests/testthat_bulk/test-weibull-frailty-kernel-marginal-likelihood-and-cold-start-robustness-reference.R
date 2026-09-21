library(testthat)
library(EDI)

# fast_weibull_frailty_cpp: Weibull AFT with a normal random intercept (params = coefficients,
# log sigma_eps, log sigma_u). Reference: the per-group marginal likelihood integrated numerically.
# The fit's negative log-likelihood equals the hand integral at its own optimum, the optimum is a
# genuine local optimum of that integral (BFGS does not move it), the treatment-slope variance equals
# vcov's diagonal, and the default cold start (which begins at log sigma_u = -3) reaches the same
# optimum as a well-started fit on every simulated dataset (no variance collapse, unlike the ordinal
# CLMM kernel).

K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed, su = 0.7) {
	set.seed(seed)
	G <- 40L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m); x <- rnorm(n); u <- rnorm(G, 0, su)[g]
	t <- rweibull(n, 1.5, exp(1 + 0.4 * x + u)); cens <- runif(n, 0, quantile(t, 0.85))
	list(X = cbind(1, x), y = pmin(t, cens), dead = as.numeric(t <= cens), g = as.integer(g), G = G, n = n)
}
hand_nll <- function(p, dat) {
	b <- p[1:2]; se <- exp(p[3]); su <- exp(p[4]); eta <- drop(dat$X %*% b)
	-sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k
		log(integrate(function(z) vapply(z, function(uu) {
			zz <- (log(dat$y[i]) - eta[i] - uu) / se
			exp(sum(ifelse(dat$dead[i] == 1, -log(se) - log(dat$y[i]) + zz - exp(zz), -exp(zz))))
		}, 0) * dnorm(z, 0, su), -Inf, Inf, rel.tol = 1e-9)$value)
	}, 0))
}

test_that("the negative log-likelihood is the marginal likelihood integral at the fitted parameters, and the fit is a local optimum of it", {
	f <- fx(11L)
	r <- K("fast_weibull_frailty_cpp")(f$X, f$y, f$dead, f$g, n_gh = 40L)
	expect_true(r$converged)
	p <- as.numeric(r$params)
	expect_equal(as.numeric(r$neg_loglik), hand_nll(p, f), tolerance = 5e-4)
	o <- optim(p, hand_nll, dat = f, method = "BFGS", control = list(reltol = 1e-10))
	expect_equal(o$par, p, tolerance = 5e-3)
	expect_lte(hand_nll(p, f), o$value + 1e-3)
})

test_that("default cold start reaches the same optimum as a well-started fit on every dataset (no variance collapse)", {
	for (s in 601:608) {
		f <- fx(s, su = 0.8)
		rc <- K("fast_weibull_frailty_cpp")(f$X, f$y, f$dead, f$g, n_gh = 40L)
		rw <- K("fast_weibull_frailty_cpp")(f$X, f$y, f$dead, f$g, n_gh = 40L, warm_start_params = c(1, 0.4, log(1 / 1.5), log(0.8)))
		expect_true(rc$converged && rw$converged, info = as.character(s))
		expect_equal(as.numeric(rc$neg_loglik), as.numeric(rw$neg_loglik), tolerance = 1e-4, info = as.character(s))
		expect_equal(as.numeric(rc$log_sigma_u), as.numeric(rw$log_sigma_u), tolerance = 1e-2, info = as.character(s))
		expect_gt(as.numeric(rc$log_sigma_u), -2.5)
	}
})

test_that("vcov is the inverse observed information (numeric Hessian of the marginal likelihood); ssq_b_T is the FIRST coefficient's variance", {
	f <- fx(11L)
	r <- K("fast_weibull_frailty_cpp")(f$X, f$y, f$dead, f$g, n_gh = 40L)
	skip_if_not_installed("numDeriv")
	expect_equal(unname(as.matrix(r$vcov)), solve(numDeriv::hessian(hand_nll, as.numeric(r$params), dat = f)), tolerance = 5e-3)
	# The kernel takes the treatment to be the first design column (here the intercept), so ssq_b_T = vcov[1, 1].
	expect_equal(as.numeric(r$ssq_b_T), as.numeric(r$vcov[1, 1]), tolerance = 1e-8)
	expect_true(all(is.finite(diag(r$vcov))) && all(diag(r$vcov) > 0))
	expect_true(all(eigen(as.matrix(r$observed_information), symmetric = TRUE)$values > 0))
	expect_lt(as.numeric(r$gradient_norm), 1e-2)
})
