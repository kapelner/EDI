library(testthat)
library(EDI)

# fast_ordinal_glmm_cpp started from log sigma = -3 (the start used by InferenceOrdinalKKCombined,
# inference_ordinal_KK_combined.R) does NOT collapse: its Newton polish moves the L-BFGS result to the ML
# solution, matching ordinal::clmm. Contrast with fast_ordinal_clmm_cpp from the same start (pinned in
# test-ordinal-clmm-kernel-...-sigma-collapse-...). Also: a Poisson-GLMM cold start (also log sigma = -3)
# recovers glmer on every simulated dataset tried.

skip_if_not_installed("ordinal")
K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("from the -3 warm start the ordinal GLMM kernel reaches ordinal::clmm on every dataset, via an accepted Newton polish", {
	n_polished <- 0L
	for (s in 301:308) {
		set.seed(s)
		G <- 40L; m <- 5L; n <- G * m
		g <- rep(seq_len(G), each = m); x <- rnorm(n); u <- rnorm(G, 0, 0.9)[g]
		y <- as.integer(cut(0.6 * x + u + rlogis(n), c(-Inf, -1, 0.5, Inf)))
		d <- data.frame(y = factor(y, ordered = TRUE), x = x, g = factor(g))
		mm <- suppressWarnings(ordinal::clmm(y ~ x + (1 | g), data = d, link = "logit", nAGQ = 25))
		if (sqrt(as.numeric(ordinal::VarCorr(mm)$g)) < 0.05) next
		X <- matrix(x, ncol = 1)
		nore <- K("fast_ordinal_regression_cpp")(X, y - 1L)
		a <- as.numeric(nore$alpha)
		ws <- c(a[1], log(a[2] - a[1]), as.numeric(nore$b), -3.0)
		r <- K("fast_ordinal_glmm_cpp")(X, y, as.integer(g), 3L, 0L, warm_start_params = ws)
		expect_true(r$converged, info = as.character(s))
		expect_gt(as.numeric(r$log_sigma), -2.5)
		expect_equal(as.numeric(r$log_sigma), log(sqrt(as.numeric(ordinal::VarCorr(mm)$g))), tolerance = 2e-3, info = as.character(s))
		expect_equal(as.numeric(r$b), unname(coef(mm)["x"]), tolerance = 1e-3, info = as.character(s))
		expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(mm)), tolerance = 1e-4, info = as.character(s))
		if (isTRUE(r$newton_polish_accepted)) n_polished <- n_polished + 1L
	}
	expect_gte(n_polished, 4L)                                    # the polish is what rescues the start
})

test_that("Poisson GLMM cold start (log sigma = -3) matches glmer's variance component across simulated datasets", {
	skip_if_not_installed("lme4")
	tried <- 0L
	for (s in 501:508) {
		set.seed(s)
		G <- 40L; m <- 5L; n <- G * m
		g <- rep(seq_len(G), each = m); X <- cbind(1, rnorm(n)); u <- rnorm(G, 0, 0.7)[g]
		y <- as.numeric(rpois(n, exp(X %*% c(0.2, 0.4) + u)))
		d <- data.frame(y = y, x = X[, 2], g = factor(g))
		mm <- tryCatch(suppressWarnings(suppressMessages(lme4::glmer(y ~ x + (1 | g), family = poisson, data = d, nAGQ = 25))), error = function(e) NULL)
		if (is.null(mm) || as.data.frame(lme4::VarCorr(mm))$sdcor < 0.05) next
		tried <- tried + 1L
		r <- K("fast_poisson_glmm_cpp")(X, y, as.integer(g), 1L, n_gh = 80L)
		expect_true(r$converged)
		expect_equal(as.numeric(r$log_sigma), log(as.data.frame(lme4::VarCorr(mm))$sdcor), tolerance = 2e-2, info = as.character(s))
		expect_equal(as.numeric(r$b)[2], unname(lme4::fixef(mm))[2], tolerance = 2e-3, info = as.character(s))
	}
	expect_gt(tried, 4L)
})
