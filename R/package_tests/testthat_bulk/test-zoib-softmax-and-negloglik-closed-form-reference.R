library(testthat)
library(EDI)

# helper_zoib.R's two pure-R kernels: .softmax_three_from_logits() (3-category
# probabilities with the beta category as the baseline, computed stably) and
# .neg_loglik_zoib() (mixture negative log-likelihood), against closed-form
# references. The compiled ZOIB fitter is deliberately not exercised here.

Z <- function(x) get(x, envir = asNamespace("EDI"))

test_that("softmax: probabilities sum to one and equal the naive formula with the beta category as baseline", {
	sm <- Z(".softmax_three_from_logits")
	for (a in list(c(0, 0), c(1, -2), c(-3, 0.5), c(4, 4))) {
		p <- sm(a[1], a[2])
		expect_equal(names(p), c("pi0", "pi1", "pib"))
		expect_equal(sum(p), 1, tolerance = 1e-14)
		den <- 1 + exp(a[1]) + exp(a[2])
		expect_equal(unname(p), c(exp(a[1]), exp(a[2]), 1) / den, tolerance = 1e-12)
	}
	expect_equal(unname(sm(0, 0)), rep(1 / 3, 3))
	# The log-odds of each inflated category against the beta category are the logits.
	p <- sm(0.7, -1.2)
	expect_equal(log(p[["pi0"]] / p[["pib"]]), 0.7, tolerance = 1e-12)
	expect_equal(log(p[["pi1"]] / p[["pib"]]), -1.2, tolerance = 1e-12)
})

test_that("softmax is stable for extreme logits where the naive formula overflows", {
	sm <- Z(".softmax_three_from_logits")
	big <- sm(1000, 0)
	expect_equal(unname(big), c(1, 0, 0), tolerance = 1e-12)
	expect_true(all(is.finite(sm(1000, 1000))))
	expect_equal(unname(sm(1000, 1000)), c(0.5, 0.5, 0), tolerance = 1e-12)
	tiny <- sm(-1000, -1000)
	expect_equal(unname(tiny), c(0, 0, 1), tolerance = 1e-12)
	expect_equal(sum(sm(-800, 900)), 1, tolerance = 1e-12)
})

test_that(".neg_loglik_zoib equals the hand-written mixture log-likelihood", {
	nll <- Z(".neg_loglik_zoib")
	set.seed(1)
	n <- 60; x <- rnorm(n)
	y <- rbeta(n, 2, 3)
	y[1:6] <- 0; y[7:10] <- 1
	is_zero <- y == 0; is_one <- y == 1; inner <- !(is_zero | is_one)
	Xb <- cbind(1, x[inner]); yb <- y[inner]
	par <- c(0.3, -0.4, log(4), -1.0, -1.5)
	got <- nll(par, p = 2L, is_zero = is_zero, is_one = is_one, y_beta = yb, X_beta = Xb)
	pr <- Z(".softmax_three_from_logits")(par[4], par[5])
	mu <- plogis(drop(Xb %*% par[1:2])); phi <- exp(par[3])
	ref <- -(sum(is_zero) * log(pr[["pi0"]]) + sum(is_one) * log(pr[["pi1"]]) +
		length(yb) * log(pr[["pib"]]) + sum(dbeta(yb, mu * phi, (1 - mu) * phi, log = TRUE)))
	expect_equal(got, unname(ref), tolerance = 1e-10)
})

test_that("with no interior observations only the point-mass terms remain; empty categories drop out", {
	nll <- Z(".neg_loglik_zoib")
	is_zero <- c(TRUE, TRUE, FALSE, FALSE, FALSE); is_one <- !is_zero
	par <- c(0, log(2), 0.2, -0.3)
	got <- nll(par, p = 1L, is_zero = is_zero, is_one = is_one, y_beta = numeric(0), X_beta = matrix(1, 0, 1))
	den <- 1 + exp(0.2) + exp(-0.3)
	expect_equal(got, -(2 * log(exp(0.2) / den) + 3 * log(exp(-0.3) / den)), tolerance = 1e-12)
	# No zeros or ones: only the beta part and the log(pb) weight.
	yb <- c(0.2, 0.5, 0.7)
	got2 <- nll(par, p = 1L, is_zero = rep(FALSE, 3), is_one = rep(FALSE, 3), y_beta = yb, X_beta = matrix(1, 3, 1))
	mu <- 0.5; phi <- 2
	expect_equal(got2, -(3 * log(1 / den) + sum(dbeta(yb, mu * phi, (1 - mu) * phi, log = TRUE))), tolerance = 1e-12)
})

test_that("the likelihood is maximised at the empirical inflation proportions and is a proper function of phi and mu", {
	nll <- Z(".neg_loglik_zoib")
	set.seed(2)
	n <- 400
	y <- ifelse(runif(n) < 0.2, 0, ifelse(runif(n) < 0.25, 1, rbeta(n, 3, 3)))
	is_zero <- y == 0; is_one <- y == 1; inner <- !(is_zero | is_one)
	Xb <- matrix(1, sum(inner), 1); yb <- y[inner]
	f <- function(a) nll(c(0, log(6), a[1], a[2]), 1L, is_zero, is_one, yb, Xb)
	opt <- optim(c(0, 0), f, method = "BFGS")
	p0 <- mean(is_zero); p1 <- mean(is_one); pb <- mean(inner)
	expect_equal(opt$par, c(log(p0 / pb), log(p1 / pb)), tolerance = 1e-3)
	# Scale-free check: the shape parameters enter only through mu * phi and (1 - mu) * phi.
	g <- function(par) nll(par, 1L, is_zero, is_one, yb, Xb)
	expect_lt(g(c(0, log(6), opt$par)), g(c(1.5, log(6), opt$par)))
})
