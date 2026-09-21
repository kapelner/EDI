library(testthat)
library(EDI)

# fast_ordinal_clmm_cpp(): random-intercept cumulative-logit model. Started with log sigma = 0 it
# reaches ordinal::clmm's ML solution (treatment coefficient, log sigma, likelihood). SUSPECTED
# SOURCE BUG (pinned, not fixed): started with log sigma = -3 -- exactly what the KK ordinal CLMM
# classes' clmm_warm_start() supplies (`c(alpha_par, beta_nore, -3.0)` in
# inference_ordinal_KK_clmm_abstract.R) and also the kernel's own cold start -- the fit slides to the
# lower sigma boundary (~ -3), reports converged = TRUE, and lands at a worse likelihood and a
# biased treatment coefficient (6 of 12 simulated datasets with true sigma 0.9 in a probe).

skip_if_not_installed("ordinal")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function(seed = 301L) {
	set.seed(seed)
	G <- 40L; m <- 5L; n <- G * m
	g <- rep(seq_len(G), each = m); x <- rnorm(n); u <- rnorm(G, 0, 0.9)[g]
	y <- as.integer(cut(0.6 * x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
	d <- data.frame(y = factor(y, ordered = TRUE), x = x, g = factor(g))
	mm <- suppressWarnings(ordinal::clmm(y ~ x + (1 | g), data = d, link = "logit", nAGQ = 25))
	X <- matrix(x, ncol = 1)
	nore <- K("fast_ordinal_regression_cpp")(X, y - 1L)
	a <- as.numeric(nore$alpha)
	list(X = X, y = y, g = as.integer(g), mm = mm,
		start = function(log_sigma) c(a[1], log(a[2] - a[1]), as.numeric(nore$b), log_sigma),
		clmm_logsig = log(sqrt(as.numeric(ordinal::VarCorr(mm)$g))))
}

test_that("started at log sigma = 0 the CLMM kernel matches ordinal::clmm (coefficient, log sigma) and is at least as likely", {
	f <- fx()
	r <- K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(0))
	expect_true(r$converged)
	expect_equal(as.numeric(r$b), unname(coef(f$mm)["x"]), tolerance = 0.1)
	expect_equal(as.numeric(r$log_sigma), f$clmm_logsig, tolerance = 0.02)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(f$mm)), tolerance = 0.5)
	expect_gt(as.numeric(r$log_sigma), -1.5)
})

test_that("the fit is stable across other datasets when started at log sigma = 0 (never collapses)", {
	for (s in c(302L, 303L, 304L, 305L, 306L)) {
		f <- fx(s)
		r <- K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(0))
		expect_gt(as.numeric(r$log_sigma), -2.5)
		expect_equal(as.numeric(r$log_sigma), f$clmm_logsig, tolerance = 0.03, info = as.character(s))
	}
})

test_that("SUSPECTED SOURCE BUG (pinned): the -3 start (the KK CLMM classes' warm start) and the default cold start collapse sigma at a worse likelihood", {
	f <- fx()
	good <- K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(0))
	for (r in list(K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(-3)),
			K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L))) {
		expect_true(r$converged)
		expect_lt(as.numeric(r$log_sigma), -2.5)
		expect_gt(as.numeric(r$neg_loglik) - as.numeric(good$neg_loglik), 0.5)
		expect_gt(abs(as.numeric(r$b) - as.numeric(good$b)), 0.02)
	}
})
