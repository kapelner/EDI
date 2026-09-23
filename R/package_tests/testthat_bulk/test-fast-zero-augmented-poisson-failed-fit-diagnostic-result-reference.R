library(testthat)
library(EDI)

# fast_zero_augmented_poisson_cpp's failed_fit_result() lambda (fast_zero_augmented_poisson.cpp,
# ~496-529) is a catch-all diagnostic path: if fast_zap_internal() throws ANY exception -- most
# simply, an unsupported optimization_alg string, which its internal normalizer rejects before any
# fitting happens -- the wrapper catches it and returns a full diagnostic list (converged = FALSE,
# num_iter = 0, params from the same warm-start/smart-cold-start/zero fallback ladder the real
# optimizer would have used, plus the neg log-lik/gradient/hessian evaluated AT that starting point,
# and exception_message). No test reference anywhere calls this kernel with an invalid
# optimization_alg, so this whole path had zero coverage.

f <- get("fast_zero_augmented_poisson_cpp", envir = asNamespace("EDI"))
score_fn <- get("get_zero_augmented_poisson_score_cpp", envir = asNamespace("EDI"))

set.seed(1); n <- 40L
X <- cbind(1, rnorm(n))
Xzi <- cbind(1, rnorm(n))
y <- rpois(n, 1) * rbinom(n, 1, 0.7)

test_that("an unsupported optimization_alg is caught and returns the documented failure diagnostic", {
	res <- f(X, y, Xzi, is_hurdle = FALSE, optimization_alg = "totally_bogus")
	expect_false(res$converged)
	expect_identical(res$num_iter, 0L)
	expect_false(res$hit_iteration_cap)
	expect_true(is.na(res$min_eigenvalue_information))
	expect_identical(res$params_origin, "optimizer entry; terminal parameters unavailable after exception")
	expect_match(res$exception_message, "optimization_alg must be one of")
	expect_length(res$params, ncol(X) + ncol(Xzi))
})

test_that("the failure-path starting params follow the documented ladder: supplied warm start wins outright", {
	ws <- c(0.5, -0.3, 0.2, -0.1)
	res <- f(X, y, Xzi, is_hurdle = FALSE, optimization_alg = "bogus_alg", warm_start_params = ws)
	expect_equal(res$params, ws)
})

test_that("with no warm start and smart_cold_start = FALSE, the ladder falls back to log(mean(y)) in the intercept only", {
	res <- f(X, y, Xzi, is_hurdle = FALSE, optimization_alg = "bogus_alg", smart_cold_start = FALSE)
	expect_equal(res$params, c(log(mean(y)), 0, 0, 0), tolerance = 1e-10)
})

test_that("the diagnostic neg_ll/gradient_norm are evaluated at those starting params, matching the independently-tested score kernel", {
	ws <- c(0.5, -0.3, 0.2, -0.1)
	res <- f(X, y, Xzi, is_hurdle = FALSE, optimization_alg = "bogus_alg", warm_start_params = ws)
	sc <- score_fn(X, y, Xzi, ws, FALSE)
	expect_equal(res$gradient_norm, sqrt(sum(sc^2)), tolerance = 1e-8)
	expect_equal(res$neg_ll, res$neg_loglik)
	expect_true(is.finite(res$neg_ll))
})

test_that("the same failure diagnostic reaches through the hurdle variant too", {
	res <- f(X, y, Xzi, is_hurdle = TRUE, optimization_alg = "bogus_alg")
	expect_false(res$converged)
	expect_match(res$exception_message, "optimization_alg must be one of")
})
