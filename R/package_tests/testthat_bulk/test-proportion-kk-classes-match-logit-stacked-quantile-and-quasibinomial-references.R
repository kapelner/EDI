library(testthat)
library(EDI)

# KK (matched pairs + reservoir) proportion classes: InferencePropKKQuantileRegrOneLik equals median regression
# (quantreg::rq) on the stacked logit-scale rows [pair differences of logit(y): (0, 1, x_T - x_C)] over
# [reservoir rows (1, w, x) with logit(y)]; the KK GEE and KK GLMM classes estimate the logit-link (quasi-binomial-
# type) treatment effect and are within 1e-2 of the quasi-binomial glm on this fixture (the pair correlation is small),
# away from the beta-regression fit (0.55) and far from a Gaussian model on logit(y) (0.79; GEE/GLMM 0.57).
#
# v1.0.6-TODO-10 (KK14's match test was twice as strict as published; fixed 2026-11-17): the fix changed this
# seed's allocation (56 pairs; the old-threshold allocation had 54) and with it the data, and the GEE/GLMM-vs-
# Gaussian-logit gap fell from 0.17 to 0.05, failing the > 0.1 check. That gap is a property of the method, not
# of the seed: GEE/GLMM estimate the coefficient of logit(E[y]) (as quasi-binomial does), the Gaussian fit the
# coefficient of E[logit(y)], and for Beta(mu * phi, (1 - mu) * phi) responses E[logit(y)] =
# digamma(mu phi) - digamma((1 - mu) phi) is a stretched logit(mu), more so for smaller phi. With phi = 8 (the old
# fixture) the population gap for this model is only about 0.11 (2e5-row check: quasi-binomial 0.47 vs
# Gaussian-logit 0.59), so at n = 120 the observed gap (smaller of GEE, GLMM) fell below 0.1 in 20 of 30 seeds;
# the old pass was luck. phi = 4 widens the population gap to about 0.22 (0.47 vs 0.68) and this seed shows 0.22,
# so the 0.1 check now sits at half the expected separation. The 0.1 threshold and the seed are unchanged; only
# the response precision phi went from 8 to 4.

skip_if_not_installed("quantreg")
skip_if_not_installed("betareg")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 120L
	des <- DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 0.5
	mu <- plogis(-0.2 + 0.5 * w + 0.4 * X$x + u)
	phi <- 4 # was 8; see the v1.0.6-TODO-10 note in the header
	y <- rbeta(n, mu * phi, (1 - mu) * phi)
	des$add_all_subject_responses(y)
	list(des = des, d = data.frame(y = y, w = w, x = X$x, m = m))
}
new_inf <- function(cls, des) K(cls)$new(des, verbose = FALSE)

test_that("KK quantile one-likelihood class equals median regression on the stacked logit-scale design", {
	f <- fx()
	d <- f$d
	pr <- d[d$m > 0, ]
	dd <- t(vapply(sort(unique(pr$m)), function(k) { a <- pr[pr$m == k, ]; t1 <- a[a$w == 1, ]; t0 <- a[a$w == 0, ]; c(qlogis(t1$y) - qlogis(t0$y), t1$x - t0$x) }, numeric(2)))
	res <- d[d$m == 0, ]
	Xs <- rbind(cbind(0, 1, dd[, 2]), cbind(1, res$w, res$x))
	ys <- c(dd[, 1], qlogis(res$y))
	ref <- unname(suppressWarnings(coef(quantreg::rq(ys ~ Xs - 1, tau = 0.5))[2]))
	expect_equal(unname(new_inf("InferencePropKKQuantileRegrOneLik", f$des)$compute_estimate()), ref, tolerance = 1e-5)
})

test_that("KK GEE and KK GLMM classes are on the logit-link scale, close to the quasi-binomial glm", {
	f <- fx()
	qb <- unname(coef(glm(y ~ w + x, family = quasibinomial, data = f$d))["w"])
	beta_scale <- unname(coef(betareg::betareg(y ~ w + x, data = f$d))["w"])
	gauss_logit <- unname(coef(lm(qlogis(y) ~ w + x, data = f$d))["w"])
	for (cls in c("InferencePropKKGEE", "InferencePropKKGLMM")) {
		est <- unname(new_inf(cls, f$des)$compute_estimate())
		# "close to", not identical to, the quasi-binomial glm (a KK
		# GEE/GLMM random-effects fit vs. a plain marginal GLM): 5e-3 had no
		# margin for InferencePropKKGEE on this fixture (observed diff
		# ~6.6e-3).
		expect_equal(est, qb, tolerance = 1e-2, scale = 1, info = cls)
		expect_gt(abs(est - gauss_logit), 0.1)
		expect_gt(abs(est - beta_scale), 0.01)
	}
})

# docs-claims audit, finding docs-claims-d10536fd2 (inference_proportion_KK_combined.R:109): the estimate
# maximizes the joint conditional-logit (discordant pairs) plus random-intercept GLMM (concordant pairs and
# reservoir) likelihood with a shared beta_T. Proportion pairs are never discordant (|y_T - y_C| = 1 cannot
# happen in (0, 1)), so the whole likelihood is the GLMM term: groups = matched pairs plus one singleton group
# per reservoir subject, Bernoulli-form log-likelihood y * eta - log(1 + exp(eta)) integrated over
# b ~ N(0, sigma^2). It is rebuilt here in R with 40-node Gauss-Hermite quadrature and maximized with optim.
# A strong pair effect (x 4) keeps sigma_hat inside the [-8, 8] log-sigma box. The likelihood is flat in
# beta_T to about 1e-4 in nll near the optimum, so beta_T is compared at 1e-3 (it is 0.02 from the plain
# quasi-binomial glm, so the check still tells the joint fit from the glm).
test_that("KK GLMM estimate maximizes the random-intercept joint likelihood rebuilt in R", {
	set.seed(4)
	n <- 60L
	des <- DesignSeqOneByOneKK14$new(response_type = "proportion", n = n, verbose = FALSE)
	X <- data.frame(x = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	w <- des$get_w()
	m <- des$.__enclos_env__$private$m[seq_len(n)]
	u <- ifelse(m > 0, rnorm(max(m))[pmax(m, 1)], 0) * 4
	mu <- plogis(-0.2 + 0.5 * w + 0.4 * X$x + u)
	y <- rbeta(n, mu * 4, (1 - mu) * 4)
	des$add_all_subject_responses(y)

	inf <- InferencePropKKGLMM$new(des, verbose = FALSE)
	est <- inf$compute_estimate()
	p <- inf$.__enclos_env__$private
	expect_false(p$prepare_clogit_plus_glmm_data()$has_discordant)

	gh <- local({
		k <- 40L
		J <- matrix(0, k, k)
		for (i in seq_len(k - 1L)) { v <- sqrt(i / 2); J[i, i + 1L] <- v; J[i + 1L, i] <- v }
		e <- eigen(J, symmetric = TRUE)
		list(x = e$values, logw = log(sqrt(pi) * e$vectors[1, ]^2 / sqrt(pi)))
	})
	grp <- factor(ifelse(m > 0, m, max(m) + seq_len(n)))
	Xm <- cbind(1, w, X$x)
	nll <- function(par) {
		eta <- as.numeric(Xm %*% par[1:3])
		E <- outer(eta, sqrt(2) * exp(par[4]) * gh$x, "+")
		L <- sweep(rowsum(y * E - log1p(exp(E)), grp, reorder = FALSE), 2, gh$logw, "+")
		mx <- apply(L, 1, max)
		-sum(mx + log(rowSums(exp(L - mx))))
	}
	opt <- optim(c(0, 0, 0, 0), nll, method = "L-BFGS-B", lower = c(-Inf, -Inf, -Inf, -8), upper = c(Inf, Inf, Inf, 8),
		control = list(factr = 1e2, maxit = 2000))
	expect_identical(opt$convergence, 0L)
	expect_gt(opt$par[4], -7) # sigma_hat interior, so the random intercept matters

	# Same objective: the R likelihood at EDI's parameters equals EDI's reported neg_loglik.
	expect_equal(nll(p$cached_mod$params), p$cached_mod$neg_loglik, tolerance = 1e-8)
	# EDI's fit is at the maximum.
	expect_lt(abs(p$cached_mod$neg_loglik - opt$value), 1e-3)
	expect_lt(abs(est - opt$par[2]), 1e-3)
	qb <- unname(coef(glm(y ~ w + X$x, family = quasibinomial))[2])
	expect_gt(abs(est - qb), 0.01)
})
