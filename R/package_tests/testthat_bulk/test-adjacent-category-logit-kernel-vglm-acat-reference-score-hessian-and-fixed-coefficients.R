library(testthat)
library(EDI)

# Adjacent-category logit kernels (fast_adjacent_category_logit_cpp / _with_var_cpp / get_..._score_cpp / _hessian_cpp): the model is
# log P(y = k + 1) / P(y = k) = x'b - alpha_k (parallel slopes). Reference: VGAM::vglm(acat(parallel = TRUE, reverse = FALSE)) (whose
# intercepts are -alpha), a hand-written category-probability log-likelihood, and numDeriv derivatives of it; fixed coefficients are
# compared with a from-scratch optim profile fit.

skip_if_not_installed("VGAM"); skip_if_not_installed("numDeriv")
K <- function(nm) get(nm, envir = asNamespace("EDI"))
f <- K("fast_adjacent_category_logit_cpp")
set.seed(1); n <- 400L
X <- cbind(x1 = rbinom(n, 1, 0.5), x2 = rnorm(n))
lat <- 0.6 * X[, 1] + 0.4 * X[, 2] + rlogis(n); y <- as.integer(cut(lat, c(-Inf, -0.5, 0.5, 1.5, Inf))); Kc <- max(y)
ll <- function(p) {
	alpha <- p[1:(Kc - 1)]; b <- p[-(1:(Kc - 1))]; xb <- as.numeric(X %*% b)
	cum <- cbind(0, t(apply(outer(xb, alpha, "-"), 1, cumsum)))            # log P(y = k) up to a constant: sum_{j < k} (x'b - alpha_j)
	sum(cum[cbind(seq_len(n), y)] - (log(rowSums(exp(cum)))))
}
v <- suppressMessages(VGAM::vglm(y ~ X, family = VGAM::acat(parallel = TRUE, reverse = FALSE)))

test_that("parameters and log-likelihood equal vglm acat (alpha = -intercepts) and the hand-written likelihood", {
	r <- f(X, y)
	expect_true(r$converged)
	cv <- unname(VGAM::coef(v))
	expect_equal(r$alpha, -cv[1:(Kc - 1)], tolerance = 1e-4); expect_equal(r$b, cv[-(1:(Kc - 1))], tolerance = 1e-4)
	expect_equal(r$params, c(r$alpha, r$b))
	expect_equal(r$neg_loglik, -as.numeric(VGAM::logLik(v)), tolerance = 1e-5)
	expect_equal(r$neg_loglik, -ll(r$params), tolerance = 1e-8)
})

test_that("score and Hessian kernels equal numDeriv derivatives of the log-likelihood (score = gradient and Hessian of the log-likelihood, same signs)", {
	r <- f(X, y); pp <- r$params + c(0.05, -0.04, 0.03, 0.02, -0.03)
	sc <- as.numeric(K("get_adjacent_category_logit_score_cpp")(X, y, pp)); g <- numDeriv::grad(ll, pp)
	expect_equal(sc, g, tolerance = 1e-5)
	H <- K("get_adjacent_category_logit_hessian_cpp")(X, y, pp); Hn <- numDeriv::hessian(ll, pp)
	expect_equal(unname(H), unname(Hn), tolerance = 1e-4)
	expect_lt(max(abs(K("get_adjacent_category_logit_score_cpp")(X, y, r$params))), 0.1)
})

test_that("with_var kernel: vcov equals vglm's covariance (up to the alpha sign flip) and ssq_b_j its treatment variance", {
	rv <- K("fast_adjacent_category_logit_with_var_cpp")(X, y)
	Vv <- VGAM::vcov(v); s <- c(rep(-1, Kc - 1), rep(1, 2)); Vref <- Vv * outer(s, s)
	expect_equal(unname(rv$vcov), unname(Vref), tolerance = 1e-3)
	expect_equal(rv$ssq_b_j, unname(Vref[Kc, Kc]), tolerance = 1e-3)
	expect_equal(rv$neg_loglik, -ll(rv$params), tolerance = 1e-8)
})

test_that("fixed coefficient: profile fit reaches the optim optimum with the fixed slope", {
	r <- f(X, y, fixed_idx = Kc, fixed_values = 0.2)
	expect_equal(r$params[Kc], 0.2)
	free <- function(q) -ll(append(q, 0.2, after = Kc - 1L))
	o <- optim(r$params[-Kc], free, method = "BFGS", control = list(reltol = 1e-12, maxit = 500))
	expect_equal(r$params[-Kc], o$par, tolerance = 1e-3)
	expect_equal(r$neg_loglik, o$value, tolerance = 1e-6)
	expect_gte(r$neg_loglik, f(X, y)$neg_loglik - 1e-8)
})
