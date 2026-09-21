library(testthat)
library(EDI)

# fast_clogit_plus_glmm_cpp(): the joint likelihood behind the KK incidence conditional-logit + GLMM
# estimator -- discordant matched pairs (conditional logit on treatment / covariate differences) plus
# concordant pairs and reservoir subjects (random-intercept logistic model). Checked in its three
# regimes: GLMM only (agrees with lme4::glmer, and does NOT show the variance collapse of the
# standalone fast_logistic_glmm_cpp default fit), discordant only (equals logistic regression on the
# differences without an intercept), and combined (negative log-likelihood is the sum of the two
# parts and the optimum matches a derivative-based optimizer).

K <- function(x) get(x, envir = asNamespace("EDI"))

test_that("GLMM-only regime equals glmer's ML solution across several simulated datasets (no sigma collapse)", {
	skip_if_not_installed("lme4")
	agree <- 0L; tried <- 0L
	for (s in 1:6) {
		set.seed(200 + s)
		G <- 40L; m <- 5L; n <- G * m
		g <- rep(seq_len(G), each = m); w <- rbinom(n, 1, 0.5); x <- rnorm(n)
		X <- cbind(1, w, x); u <- rnorm(G, 0, 0.9)[g]
		y <- as.numeric(rbinom(n, 1, plogis(X %*% c(-0.2, 0.7, 0.3) + u)))
		d <- data.frame(y = y, w = w, x = x, g = factor(g))
		mm <- tryCatch(suppressWarnings(suppressMessages(lme4::glmer(y ~ w + x + (1 | g), family = binomial, data = d, nAGQ = 25))), error = function(e) NULL)
		if (is.null(mm) || as.data.frame(lme4::VarCorr(mm))$sdcor < 0.05) next
		tried <- tried + 1L
		r <- K("fast_clogit_plus_glmm_cpp")(matrix(0, 0, 3), numeric(0), X, y, as.integer(g), FALSE, TRUE)
		p <- as.numeric(r$params)
		expect_true(r$converged)
		expect_equal(p[1:3], unname(lme4::fixef(mm)), tolerance = 5e-2)
		expect_equal(p[4], log(as.data.frame(lme4::VarCorr(mm))$sdcor), tolerance = 5e-2)
		expect_gt(p[4], -2.5)
		agree <- agree + 1L
	}
	expect_gt(tried, 2L)
	expect_equal(agree, tried)
})

test_that("discordant-only regime equals logistic regression without an intercept on the difference design", {
	set.seed(3)
	Kp <- 60L
	Xd <- cbind(1, rnorm(Kp)); yd <- as.numeric(rbinom(Kp, 1, plogis(Xd %*% c(0.5, 0.4))))
	r <- K("fast_clogit_plus_glmm_cpp")(Xd, yd, matrix(0, 0, 3), numeric(0), integer(0), TRUE, FALSE)
	g <- glm(yd ~ Xd - 1, family = binomial())
	expect_true(r$converged)
	expect_equal(as.numeric(r$params), unname(coef(g)), tolerance = 1e-3)
	expect_equal(unname(sqrt(diag(r$vcov))), unname(sqrt(diag(vcov(g)))), tolerance = 1e-3)
	expect_equal(as.numeric(r$neg_loglik), -as.numeric(logLik(g)), tolerance = 1e-5)
})

test_that("combined regime: negative log-likelihood is the conditional-logit part plus the GLMM part, at the optimizer's optimum", {
	set.seed(7)
	G <- 25L; m <- 4L; n <- G * m
	g <- rep(seq_len(G), each = m); w <- rbinom(n, 1, 0.5); x <- rnorm(n)
	Xc <- cbind(1, w, x); u <- rnorm(G, 0, 0.7)[g]
	yc <- as.numeric(rbinom(n, 1, plogis(Xc %*% c(-0.2, 0.6, 0.3) + u)))
	Kp <- 30L
	Xd <- cbind(1, rnorm(Kp)); yd <- as.numeric(rbinom(Kp, 1, plogis(Xd %*% c(0.6, 0.3))))
	r <- K("fast_clogit_plus_glmm_cpp")(Xd, yd, Xc, yc, as.integer(g), TRUE, TRUE)
	expect_true(r$converged)
	nll <- function(p) {
		bs <- p[1:3]; ed <- Xd %*% bs[2:3]
		-sum(yd * ed - log1p(exp(ed))) + K("get_logistic_glmm_neg_loglik_cpp")(Xc, yc, as.integer(g), c(bs, p[4]), 40L)
	}
	p_fit <- as.numeric(r$params)
	expect_equal(as.numeric(r$neg_loglik), nll(p_fit), tolerance = 1e-5)
	o <- optim(p_fit + 0.1, nll, method = "BFGS", control = list(reltol = 1e-12))
	expect_lte(as.numeric(r$neg_loglik), o$value + 1e-4)
	expect_equal(p_fit[1:3], o$par[1:3], tolerance = 2e-2, ignore_attr = TRUE)
})
