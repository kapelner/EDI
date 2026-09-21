library(testthat)
library(EDI)

# KK (matched pairs + reservoir) proportion classes: InferencePropKKQuantileRegrOneLik equals median regression
# (quantreg::rq) on the stacked logit-scale rows [pair differences of logit(y): (0, 1, x_T - x_C)] over
# [reservoir rows (1, w, x) with logit(y)]; the KK GEE and KK GLMM classes estimate the logit-link (quasi-binomial-
# type) treatment effect and are within 0.5% of the quasi-binomial glm on this fixture (the pair correlation is small),
# far from the beta-regression / glmmTMB(beta) scale (0.70) and from a Gaussian model on logit(y) (0.80).

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
	y <- rbeta(n, mu * 8, (1 - mu) * 8)
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
		expect_equal(est, qb, tolerance = 5e-3, scale = 1, info = cls)
		expect_gt(abs(est - gauss_logit), 0.1)
		expect_gt(abs(est - beta_scale), 0.01)
	}
})
