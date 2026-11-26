library(testthat)
library(EDI)

# v1.0.6-TODO-163 (found under v1.1.0-TODO-217): fast_zinb_cpp() with optimization_alg = "newton_raphson" (the class default), warm-started from
# the full-data MLE, can step into the flat region where every zero-inflation linear predictor is below -10; the C++
# fit_zinb_zi_boundary_fallback() then accepts the zero-inflation-off NegBin fit ("NegBinNoZI") although an interior
# fit has a lower negative log-likelihood. Randomization draws are warm-started that way, so 13-14% of them returned
# a wrong (non-MLE) treatment estimate on the calibration DGP and the randomization test was oversized (size
# 0.075-0.109 in campaign 2026-11-15-e36c7710). fast_zinb_cpp_guarded() refits such a fit with L-BFGS and keeps the
# lower negative log-likelihood; every ZINB fit in inference_count_zero_augmented_poisson_abstract.R goes through it.

zinb_boundary_fixture <- function() {
	set.seed(1L)
	n <- 200L
	x1 <- rnorm(n)
	y <- as.numeric(ifelse(rbinom(n, 1L, plogis(-1 + 0.5 * x1)) == 1L, 0, rnbinom(n, size = 2, mu = exp(0.5 + 0.6 * x1))))
	w <- rep(0:1, n / 2L)
	perms <- replicate(5L, sample(w))
	list(y = y, w = w, perms = perms)
}

test_that("a warm-started Newton fit that collapses to the zero-inflation-off boundary is refit to the interior MLE", {
	ns <- asNamespace("EDI")
	raw <- get("fast_zinb_cpp", envir = ns)
	guarded <- get("fast_zinb_cpp_guarded", envir = ns)
	nll <- get("zinb_neg_loglik_r", envir = ns)
	fx <- zinb_boundary_fixture()
	X <- cbind(1, fx$w)
	full <- raw(X = X, Xzi = X, y = fx$y, optimization_alg = "newton_raphson")
	Xb <- cbind(1, fx$perms[, 5L])
	mle <- raw(X = Xb, Xzi = Xb, y = fx$y, optimization_alg = "lbfgs")
	expect_true(isTRUE(mle$converged))
	expect_false(isTRUE(mle$zero_inflation_at_boundary))

	unguarded <- raw(X = Xb, Xzi = Xb, y = fx$y, warm_start_params = full$params, optimization_alg = "newton_raphson", estimate_only = TRUE)
	if (isTRUE(unguarded$zero_inflation_at_boundary)) {
		# The C++ bug this guards against: the boundary fit is not the MLE.
		expect_gt(nll(unguarded$params, Xb, Xb, fx$y, zi_off = TRUE), nll(mle$params, Xb, Xb, fx$y) + 0.01)
	}
	fit <- guarded(X = Xb, Xzi = Xb, y = fx$y, warm_start_params = full$params, optimization_alg = "newton_raphson", estimate_only = TRUE)
	expect_true(isTRUE(fit$converged))
	expect_false(isTRUE(fit$zero_inflation_at_boundary))
	expect_equal(fit$params[2L], mle$params[2L], tolerance = 2e-3)  # flat separation ridge: optimizers agree to ~1e-4
	expect_lte(nll(fit$params, Xb, Xb, fx$y), nll(mle$params, Xb, Xb, fx$y) + 1e-6)
})

test_that("zinb_neg_loglik_r matches the kernel's neg_loglik and the NegBin limit", {
	ns <- asNamespace("EDI")
	nll <- get("zinb_neg_loglik_r", envir = ns)
	fx <- zinb_boundary_fixture()
	X <- cbind(1, fx$w)
	f <- get("fast_zinb_cpp", envir = ns)(X = X, Xzi = X, y = fx$y)
	expect_equal(nll(f$params, X, X, fx$y), f$neg_loglik, tolerance = 1e-8)
	theta <- 1.7; b <- c(0.4, -0.1)
	expect_equal(nll(c(b, 0, 0, log(theta)), X, X, fx$y, zi_off = TRUE),
		-sum(dnbinom(fx$y, size = theta, mu = exp(drop(X %*% b)), log = TRUE)))
})

test_that("the guard leaves fits with fixed zero-inflation coefficients untouched", {
	ns <- asNamespace("EDI")
	raw <- get("fast_zinb_cpp", envir = ns)
	guarded <- get("fast_zinb_cpp_guarded", envir = ns)
	fx <- zinb_boundary_fixture()
	X <- cbind(1, fx$w)
	a <- raw(X = X, Xzi = X, y = fx$y, fixed_idx = 3:4, fixed_values = c(-40, 0), estimate_only = TRUE)
	b <- guarded(X = X, Xzi = X, y = fx$y, fixed_idx = 3:4, fixed_values = c(-40, 0), estimate_only = TRUE)
	expect_identical(a$params, b$params)
})

test_that("InferenceCountZeroInflatedNegBin randomization draws equal fresh fits on the permuted assignments", {
	fx <- zinb_boundary_fixture()
	n <- length(fx$y)
	X <- data.frame(x = rep(1, n))
	mk <- function(w) {
		d <- DesignFixedBernoulli$new(n = n, response_type = "count")
		d$add_all_subjects_to_experiment(X)
		d$assign_w_to_all_subjects(w_precomputed = w)
		d$add_all_subject_responses(ys = fx$y)
		d
	}
	inf <- InferenceCountZeroInflatedNegBin$new(mk(fx$w), model_formula = ~ 1)
	inf$compute_estimate()
	t0s <- suppressWarnings(inf$approximate_randomization_distribution_beta_hat_T(
		r = ncol(fx$perms), permutations = list(w_mat = fx$perms), show_progress = FALSE))
	fresh <- vapply(seq_len(ncol(fx$perms)), function(b) {
		as.numeric(InferenceCountZeroInflatedNegBin$new(mk(fx$perms[, b]), model_formula = ~ 1)$compute_estimate())
	}, numeric(1L))
	expect_equal(as.numeric(t0s), fresh, tolerance = 1e-3)
})
