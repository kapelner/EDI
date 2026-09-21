library(testthat)
library(EDI)

# get_zero_augmented_poisson_{score,hessian}_cpp and fast_zero_augmented_poisson_cpp (zero-inflated
# and hurdle Poisson; params = count coefficients then zero-model coefficients, where the zero model is
# logit P(structural zero) = plogis(Xzi %*% gamma)). References: hand-written log-likelihoods with
# numDeriv derivatives, a derivative-free optimum, and pscl::zeroinfl / pscl::hurdle. The kernel's
# neg_loglik omits the parameter-free sum(lfactorial(y)) term. pscl's hurdle zero model is for
# P(y > 0), so its zero coefficients are the NEGATIVE of this kernel's.

skip_if_not_installed("numDeriv")
K <- function(x) get(x, envir = asNamespace("EDI"))

fx <- function() {
	set.seed(4)
	n <- 200L
	X <- cbind(1, rnorm(n), rbinom(n, 1, 0.5)); Xz <- cbind(1, X[, 2])
	mu <- exp(X %*% c(0.5, 0.3, -0.2)); z <- rbinom(n, 1, plogis(Xz %*% c(-0.5, 0.4)))
	list(X = X, Xz = Xz, y = as.numeric(ifelse(z == 1, 0, rpois(n, mu))), n = n)
}
ll_za <- function(p, dat, hurdle) {
	mu <- as.numeric(exp(dat$X %*% p[1:3])); pz <- as.numeric(plogis(dat$Xz %*% p[4:5])); y <- dat$y
	if (hurdle) sum(ifelse(y == 0, log(pz), log(1 - pz) + dpois(y, mu, log = TRUE) - log1p(-exp(-mu))))
	else sum(ifelse(y == 0, log(pz + (1 - pz) * exp(-mu)), log(1 - pz) + dpois(y, mu, log = TRUE)))
}
p0 <- c(0.4, 0.2, -0.1, -0.3, 0.3)

test_that("score and Hessian equal numeric derivatives for both the zero-inflated and hurdle likelihoods", {
	f <- fx()
	for (h in c(FALSE, TRUE)) {
		expect_equal(K("get_zero_augmented_poisson_score_cpp")(f$X, f$y, f$Xz, p0, h), numDeriv::grad(ll_za, p0, dat = f, hurdle = h), tolerance = 1e-6, info = h)
		hs <- K("get_zero_augmented_poisson_hessian_cpp")(f$X, f$y, f$Xz, p0, h)
		expect_equal(unname(hs), numDeriv::hessian(ll_za, p0, dat = f, hurdle = h), tolerance = 1e-5, info = h)
		expect_equal(unname(hs), unname(t(hs)), tolerance = 1e-8)
	}
})

test_that("fits reach the derivative-free optimum, with the neg-loglik offset by sum(lfactorial(y)) and vcov = inverse observed information", {
	f <- fx()
	for (h in c(FALSE, TRUE)) {
		r <- K("fast_zero_augmented_poisson_cpp")(f$X, f$y, f$Xz, h)
		o <- optim(p0, function(p) -ll_za(p, f, h), method = "BFGS", control = list(reltol = 1e-12))
		p_fit <- as.numeric(r$params)
		expect_true(r$converged)
		expect_equal(p_fit, o$par, tolerance = 2e-3, info = as.character(h))
		expect_equal(as.numeric(r$neg_loglik), -ll_za(p_fit, f, h) - sum(lfactorial(f$y)), tolerance = 1e-6, info = as.character(h))
		expect_equal(unname(as.matrix(r$vcov)), solve(-numDeriv::hessian(ll_za, p_fit, dat = f, hurdle = h)), tolerance = 5e-3, info = as.character(h))
	}
})

test_that("the fits agree with pscl::zeroinfl and pscl::hurdle (hurdle zero coefficients with opposite sign)", {
	skip_if_not_installed("pscl")
	f <- fx()
	d <- data.frame(y = f$y, x1 = f$X[, 2], x2 = f$X[, 3])
	zi <- pscl::zeroinfl(y ~ x1 + x2 | x1, data = d)
	rz <- K("fast_zero_augmented_poisson_cpp")(f$X, f$y, f$Xz, FALSE)
	expect_equal(as.numeric(rz$params), unname(coef(zi)), tolerance = 2e-3)
	expect_equal(-as.numeric(rz$neg_loglik) - sum(lfactorial(f$y)), as.numeric(logLik(zi)), tolerance = 1e-4)
	expect_equal(unname(sqrt(diag(rz$vcov))), unname(sqrt(diag(vcov(zi)))), tolerance = 5e-3)
	hu <- pscl::hurdle(y ~ x1 + x2 | x1, data = d, dist = "poisson", zero.dist = "binomial")
	rh <- K("fast_zero_augmented_poisson_cpp")(f$X, f$y, f$Xz, TRUE)
	expect_equal(as.numeric(rh$params)[1:3], unname(coef(hu))[1:3], tolerance = 2e-3)
	expect_equal(as.numeric(rh$params)[4:5], -unname(coef(hu))[4:5], tolerance = 2e-3)
	expect_equal(-as.numeric(rh$neg_loglik) - sum(lfactorial(f$y)), as.numeric(logLik(hu)), tolerance = 1e-4)
})
