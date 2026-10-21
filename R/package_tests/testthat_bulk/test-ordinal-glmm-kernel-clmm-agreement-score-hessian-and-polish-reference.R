library(testthat)
library(EDI)

# fast_ordinal_glmm_cpp (random-intercept cumulative logit, alpha = [first threshold, log threshold
# gaps]) and its score / Hessian / negative log-likelihood kernels. References: ordinal::clmm
# (nAGQ = 25) for the fit and a hand-written per-group integral (numDeriv) for the derivatives. Unlike
# fast_ordinal_clmm_cpp started at log sigma = -3, this kernel does not collapse sigma: it matches
# ordinal::clmm to ~5 digits on every simulated dataset tried.

skip_if_not_installed("ordinal")
skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed) {
	set.seed(seed)
	G <- 40L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m); x <- rnorm(n); u <- rnorm(G, 0, 0.9)[g]
	y <- as.integer(cut(0.6 * x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	d <- data.frame(y = factor(y, ordered = TRUE), x = x, g = factor(g))
	list(X = matrix(x, ncol = 1), y = y, g = as.integer(g), G = G,
		mm = suppressWarnings(ordinal::clmm(y ~ x + (1 | g), data = d, link = "logit", nAGQ = 25)))
}
hand_nll <- function(p, dat) {
	a <- c(p[1], p[1] + exp(p[2])); b <- p[3]; s <- exp(p[4])
	-sum(vapply(seq_len(dat$G), function(k) {
		i <- dat$g == k
		log(integrate(function(z) vapply(z, function(zz) {
			eta <- dat$X[i, 1] * b + zz
			cdf <- cbind(0, plogis(a[1] - eta), plogis(a[2] - eta), 1)
			prod(cdf[cbind(seq_len(sum(i)), dat$y[i] + 1L)] - cdf[cbind(seq_len(sum(i)), dat$y[i])]) * dnorm(zz, 0, s)
		}, 0), -Inf, Inf, rel.tol = 1e-10)$value)
	}, 0))
}

test_that("the fit matches ordinal::clmm on several datasets: coefficient, thresholds, log sigma and likelihood", {
	for (s in c(301L, 302L, 303L, 305L)) {
		f <- fx(s)
		r <- K("fast_ordinal_glmm_cpp")(f$X, f$y, f$g, 3L, 0L)
		th <- unname(f$mm$alpha)
		expect_true(r$converged)
		expect_equal(as.numeric(r$b), unname(coef(f$mm)["x"]), tolerance = 1e-4, info = as.character(s))
		expect_equal(c(as.numeric(r$alpha)[1], as.numeric(r$alpha)[1] + exp(as.numeric(r$alpha)[2])), th, tolerance = 1e-3, info = as.character(s))
		expect_equal(as.numeric(r$log_sigma), log(sqrt(as.numeric(ordinal::VarCorr(f$mm)$g))), tolerance = 1e-3, info = as.character(s))
		expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(f$mm)), tolerance = 1e-4, info = as.character(s))
		expect_false(isTRUE(r$variance_boundary_hit))
	}
})

test_that("negative log-likelihood, score and Hessian kernels equal the hand integral and its numeric derivatives (high node count)", {
	f <- fx(301L)
	p0 <- c(-0.8, log(1.1), 0.5, log(0.6))
	expect_equal(K("get_ordinal_glmm_neg_loglik_cpp")(f$X, f$y, f$g, p0, 3L, 80L), hand_nll(p0, f), tolerance = 1e-6)
	sc <- K("get_ordinal_glmm_score_cpp")(f$X, f$y, f$g, p0, 3L, 80L)
	expect_equal(as.numeric(sc), -numDeriv::grad(hand_nll, p0, dat = f), tolerance = 1e-4)
	h <- K("get_ordinal_glmm_hessian_cpp")(f$X, f$y, f$g, p0, 3L, 80L)
	# Sign convention: this kernel's 'Hessian' is the Hessian of the NEGATIVE log-likelihood (positive
	# definite observed information), while its score is the gradient of the log-likelihood.
	expect_equal(unname(h), numDeriv::hessian(hand_nll, p0, dat = f), tolerance = 5e-3)
	expect_true(all(eigen(h, symmetric = TRUE)$values > 0))
	expect_equal(unname(h), unname(t(h)), tolerance = 1e-6)
})

test_that("a fit warm-started from the ordinal-package reference stays at the independent solution", {
	f <- fx(302L)
	r <- K("fast_ordinal_glmm_cpp")(f$X, f$y, f$g, 3L, 0L, n_gh = 80L)
	ref_thresholds <- unname(f$mm$alpha)
	warm_start <- c(
		ref_thresholds[1L], log(diff(ref_thresholds)),
		unname(coef(f$mm)["x"]), log(sqrt(as.numeric(ordinal::VarCorr(f$mm)$g)))
	)
	r2 <- K("fast_ordinal_glmm_cpp")(
		f$X, f$y, f$g, 3L, 0L, n_gh = 80L, warm_start_params = warm_start
	)
	p2 <- c(as.numeric(r2$alpha), as.numeric(r2$b), as.numeric(r2$log_sigma))
	# The valid warm-start fit must agree with both independent oracles, not
	# only with another call to the same EDI kernel.
	thresholds2 <- c(p2[1L], p2[1L] + exp(p2[2L]))
	expect_equal(p2[3L], unname(coef(f$mm)["x"]), tolerance = 1e-4)
	expect_equal(thresholds2, unname(f$mm$alpha), tolerance = 1e-3)
	expect_equal(p2[4L], log(sqrt(as.numeric(ordinal::VarCorr(f$mm)$g))), tolerance = 1e-3)
	expect_equal(as.numeric(r2$neg_loglik), -as.numeric(logLik(f$mm)), tolerance = 1e-4)
	expect_equal(as.numeric(r2$neg_loglik), hand_nll(p2, f), tolerance = 1e-6)
	expect_equal(as.numeric(r2$neg_loglik), as.numeric(r$neg_loglik), tolerance = 1e-6)
	expect_equal(as.numeric(r2$b), as.numeric(r$b), tolerance = 1e-4)
	expect_true(all(c("newton_polish_attempted", "newton_polish_accepted", "newton_polish_iterations", "variance_boundary_hit") %in% names(r)))
})
