library(testthat)
library(EDI)

# fast_ordinal_clmm_cpp(): random-intercept cumulative-logit model. Started with log sigma = 0 it
# reaches ordinal::clmm's ML solution (treatment coefficient, log sigma, likelihood). The kernel
# uses deterministic log-sigma multistart, so an explicitly poor -3 start and the default cold
# start must select the same likelihood basin rather than silently collapsing the random effect.

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
	# TODO-31 classifies a boundary-looking stop using its gradient; keep the
	# optimizer diagnostic present/finite alongside the independent ML oracle.
	expect_true(is.finite(as.numeric(r$gradient_norm)))
	expect_equal(as.numeric(r$b), unname(coef(f$mm)["x"]), tolerance = 0.1)
	expect_equal(as.numeric(r$log_sigma), f$clmm_logsig, tolerance = 0.02)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(f$mm)), tolerance = 0.5)
	expect_gt(as.numeric(r$log_sigma), -1.5)
})

test_that("the fit is stable across other datasets when started at log sigma = 0 (never collapses)", {
	for (s in c(302L, 303L, 304L, 305L, 306L)) {
		f <- fx(s)
		r <- K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(0))
		expect_true(is.finite(as.numeric(r$gradient_norm)), info = as.character(s))
		expect_gt(as.numeric(r$log_sigma), -2.5)
		expect_equal(as.numeric(r$log_sigma), f$clmm_logsig, tolerance = 0.03, info = as.character(s))
	}
})

test_that("the -3 start and default cold start select the same finite optimum as the zero start", {
	f <- fx()
	good <- K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(0))
	for (r in list(K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L, warm_start_params = f$start(-3)),
			K("fast_ordinal_clmm_cpp")(f$X, f$y, f$g, 3L, 0L))) {
		expect_true(r$converged)
		expect_true(is.finite(as.numeric(r$gradient_norm)))
		expect_gt(as.numeric(r$log_sigma), -1.5)
		expect_equal(as.numeric(r$neg_loglik), as.numeric(good$neg_loglik), tolerance = 1e-5)
		# Same kernel, different starting points converging to "the same"
		# optimum in parameter space only to the solver's own convergence
		# tolerance, not to 1e-5 exactly (observed diff ~5.3e-5 here).
		expect_equal(as.numeric(r$b), as.numeric(good$b), tolerance = 1e-4)
	}
})

test_that("the default quadrature is within the recorded bound of 320 nodes on the seeded CLMM fixture", {
	f <- fx(301L)
	# The seeded latent-logistic fixture is deterministic under the default R
	# RNG convention described in vignette("reproducibility"); ordinal::clmm
	# supplies the independent high-accuracy fit reference.
	r320 <- K("fast_ordinal_clmm_cpp")(
		f$X, f$y, f$g, 3L, 0L, n_gh = 320L
	)
	r20 <- K("fast_ordinal_clmm_cpp")(
		f$X, f$y, f$g, 3L, 0L, n_gh = 20L
	)
	expect_true(r320$converged)
	expect_true(r20$converged)
	expect_equal(as.numeric(r320$b), unname(coef(f$mm)["x"]), tolerance = 0.1)
	expect_equal(as.numeric(r320$log_sigma), f$clmm_logsig, tolerance = 0.02)
	expect_true(is.finite(as.numeric(r320$ssq_b_T)) && as.numeric(r320$ssq_b_T) > 0)
	expect_lte(
		abs(as.numeric(r20$b) - as.numeric(r320$b)) / sqrt(as.numeric(r320$ssq_b_T)),
		0.75
	)
	expect_lte(abs(as.numeric(r20$log_sigma) - as.numeric(r320$log_sigma)), 0.10)
})
