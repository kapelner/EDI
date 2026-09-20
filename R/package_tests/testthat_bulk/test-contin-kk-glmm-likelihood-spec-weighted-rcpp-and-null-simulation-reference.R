library(testthat)
library(EDI)

# InferenceContinKKGLMM (Rcpp Gaussian LMM path): the fitted parameter vector and
# neg-log-likelihood against a hand-coded marginal likelihood, the
# likelihood-test spec closures (score / information / constrained fit),
# weighted_rcpp_estimate() and compute_estimate_with_bootstrap_weights() branches,
# and simulate_under_lik_null()'s guard and shape.

lmm_fx <- function(seed = 2L, np = 25L, ns = 10L, ...) {
	set.seed(seed)
	n <- 2L * np + ns
	des <- DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(X[i, , drop = FALSE])
	des$.__enclos_env__$private$m <- c(rep(seq_len(np), each = 2L), rep(0L, ns))
	w <- des$get_w()
	g <- c(rep(seq_len(np), each = 2L), np + seq_len(ns))
	u <- rnorm(max(g), 0, 0.8)
	y <- 1 + 0.7 * w + 0.5 * X$x1 + u[g] + rnorm(n, 0, 0.5)
	des$add_all_subject_responses(y)
	inf <- InferenceContinKKGLMM$new(des, verbose = FALSE, ...)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x = X$x1, y = y, g = g, n = n, Xm = cbind(1, w, X$x1))
}

# Marginal Gaussian negative log-likelihood, b = (beta, log sigma_e, log sigma_b).
ref_nll <- function(f, b) {
	se <- exp(b[4]); sb <- exp(b[5]); tot <- 0
	for (k in unique(f$g)) {
		i <- which(f$g == k)
		V <- se^2 * diag(length(i)) + sb^2
		r <- f$y[i] - f$Xm[i, , drop = FALSE] %*% b[1:3]
		tot <- tot + 0.5 * (length(i) * log(2 * pi) + determinant(V)$modulus[1] + sum(r * solve(V, r)))
	}
	tot
}

test_that("the fit's parameter vector and neg-log-likelihood equal the hand-coded marginal likelihood at its optimum", {
	f <- lmm_fx()
	est <- f$inf$compute_estimate()
	fit <- f$p$cached_mod
	expect_equal(unname(fit$b["b1"]), est)
	expect_equal(names(fit$b), c("b0", "b1", "b2", "log_sigma_e", "log_sigma_b"))
	expect_equal(as.numeric(fit$neg_loglik), ref_nll(f, fit$b), tolerance = 1e-6)
	expect_equal(f$p$cached_vc_params, unname(fit$b[4:5]))
	# It is a (local) optimum of that likelihood.
	opt <- optim(fit$b, function(b) ref_nll(f, b), method = "BFGS")
	expect_equal(as.numeric(fit$neg_loglik), opt$value, tolerance = 1e-5)
	expect_equal(unname(fit$b[1:3]), unname(opt$par[1:3]), tolerance = 2e-2)
	expect_equal(f$p$cached_values$df, Inf)
})

test_that("spec closures: zero score at the MLE, symmetric positive-definite information, LR-consistent constrained fits", {
	f <- lmm_fx()
	sp <- f$p$get_likelihood_test_spec()
	expect_equal(sp$j, 2L)
	expect_equal(sp$group_id, as.integer(f$g))
	fit <- sp$full_fit
	expect_true(all(abs(sp$score(fit)) < 5e-2))            # solver stops at a gradient norm of ~1e-2
	I <- sp$fisher_information(fit)
	expect_equal(dim(I), c(5L, 5L))
	expect_equal(I, t(I), tolerance = 1e-8)
	expect_true(all(eigen(I, symmetric = TRUE, only.values = TRUE)$values > 0))
	expect_equal(sp$observed_information(fit), I)
	expect_equal(sp$information(fit), I)
	expect_equal(sp$extract_start(fit), as.numeric(fit$b))
	expect_equal(sp$neg_loglik(fit), ref_nll(f, fit$b), tolerance = 1e-6)

	null_at_mle <- sp$fit_null(unname(fit$b[2]))
	expect_equal(sp$neg_loglik(null_at_mle), sp$neg_loglik(fit), tolerance = 1e-4)
	n0 <- sp$fit_null(0)
	expect_equal(unname(n0$b[2]), 0, tolerance = 1e-8)
	expect_equal(sp$neg_loglik(n0), ref_nll(f, n0$b), tolerance = 1e-5)
	expect_gt(sp$neg_loglik(n0), sp$neg_loglik(fit))
	# The constrained fit's own score vanishes in every free coordinate.
	sc <- sp$score(n0)
	expect_true(all(abs(sc[-2]) < 5e-2))
	expect_gt(abs(sc[2]), 1)                                   # the constrained coordinate is far from stationary
})

test_that("likelihood tests are unavailable without the Rcpp path", {
	f <- lmm_fx(use_rcpp = FALSE)
	expect_false(f$p$supports_likelihood_tests())
	expect_false(f$p$supports_lik_ratio_param_bootstrap())
	expect_null(f$p$get_likelihood_test_spec())
	g <- lmm_fx()
	expect_true(g$p$supports_likelihood_tests()); expect_true(g$p$supports_lik_ratio_param_bootstrap())
	expect_equal(g$p$get_complexity_tier(), "heavy")
	expect_equal(g$p$glmm_response_type(), "continuous")
	expect_equal(g$p$glmm_family()$family, "gaussian")
})

test_that("simulate_under_lik_null: NULL for a short parameter vector, otherwise a usable seed-reproducible replicate spec", {
	f <- lmm_fx()
	sp <- f$p$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	expect_null(f$p$simulate_under_lik_null(sp, 0, list(b = c(0, 0, 0, 0))))
	set.seed(4); a <- f$p$simulate_under_lik_null(sp, 0, nf)
	set.seed(4); b <- f$p$simulate_under_lik_null(sp, 0, nf)
	skip_if(is.null(a) || is.null(b), "replicate did not converge for this seed")
	expect_equal(as.numeric(a$full_fit$b), as.numeric(b$full_fit$b))
	expect_setequal(names(a), c("full_fit", "fit_null", "neg_loglik"))
	n1 <- a$fit_null(0)
	expect_equal(unname(n1$b[2]), 0, tolerance = 1e-8)
	expect_gte(a$neg_loglik(n1) - a$neg_loglik(a$full_fit), -1e-6)
})

test_that("weighted Rcpp estimate: unit weights reproduce the unweighted fit (estimate and SE); estimate_only returns a bare number", {
	f <- lmm_fx()
	est <- f$inf$compute_estimate()
	f$inf$compute_asymp_confidence_interval()
	se <- f$p$cached_values$s_beta_hat_T
	ones <- rep(1, f$n)
	expect_equal(f$p$weighted_rcpp_estimate(ones, TRUE), est, tolerance = 1e-3)
	full <- f$p$weighted_rcpp_estimate(ones, FALSE)
	expect_type(full, "list")
	expect_equal(full$beta, est, tolerance = 1e-3)
	expect_equal(full$se, se, tolerance = 2e-2)
})

test_that("bootstrap-weight entry point: constant weights short-circuit, non-constant weights refit and reset the SE cache", {
	f <- lmm_fx()
	est <- f$inf$compute_estimate()
	f$p$current_bayesian_bootstrap_context <- f$p$build_bayesian_bootstrap_context()
	K <- f$p$current_bayesian_bootstrap_context$n_units
	expect_equal(f$inf$compute_estimate_with_bootstrap_weights(rep(3, K)), est, tolerance = 1e-8)
	expect_equal(f$p$cached_values$df, Inf)
	expect_null(f$p$cached_values$summary_table)

	set.seed(6)
	wts <- rexp(K)
	b1 <- f$inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = TRUE)
	expect_true(is.finite(b1))
	expect_false(isTRUE(all.equal(b1, est, tolerance = 1e-6)))
	expect_true(is.na(f$p$cached_values$s_beta_hat_T))
	expect_equal(f$p$cached_values$beta_hat_T, b1)
	b2 <- f$inf$compute_estimate_with_bootstrap_weights(wts, estimate_only = FALSE)
	expect_equal(b2, b1, tolerance = 1e-3)
	expect_true(is.finite(f$p$cached_values$s_beta_hat_T))
})

hand_gls <- function(X, y, g, le, lb, wts = rep(1, length(y))) {
	A <- 0; B <- 0; se <- exp(le); sb <- exp(lb)
	for (k in unique(g)) {
		i <- which(g == k); V <- se^2 * diag(length(i)) + sb^2; Xi <- X[i, , drop = FALSE]
		A <- A + wts[i[1]] * t(Xi) %*% solve(V, Xi); B <- B + wts[i[1]] * t(Xi) %*% solve(V, y[i])
	}
	drop(solve(A, B))
}

test_that("GLS kernel matches hand-coded GLS for singleton groups and for sigma_e = 1", {
	set.seed(1); n <- 40
	w <- rbinom(n, 1, 0.5); X <- cbind(a = 1, w = w, x = rnorm(n)); y <- rnorm(n)
	kern <- function(g, le, lb) unname(EDI:::fast_gaussian_lmm_gls_cpp(X = X, y = y, group_id = as.integer(g), log_sigma_e = le, log_sigma_b = lb))
	expect_equal(kern(seq_len(n), -0.5, 0), unname(hand_gls(X, y, seq_len(n), -0.5, 0)), tolerance = 1e-8)
	g <- rep(1:20, each = 2)
	expect_equal(kern(g, 0, -0.3), unname(hand_gls(X, y, g, 0, -0.3)), tolerance = 1e-8)
})

test_that("GLS kernel with multi-row groups and sigma_e != 1 equals hand-coded GLS, including group weights", {
	set.seed(1); n <- 40
	w <- rbinom(n, 1, 0.5); X <- cbind(a = 1, w = w, x = rnorm(n)); y <- rnorm(n); g <- rep(1:20, each = 2)
	for (le in c(-0.5, 0.7)) for (lb in c(-1, 0, 0.4)) {
		got <- unname(EDI:::fast_gaussian_lmm_gls_cpp(X = X, y = y, group_id = as.integer(g), log_sigma_e = le, log_sigma_b = lb))
		expect_equal(got, unname(hand_gls(X, y, g, le, lb)), tolerance = 1e-8)
	}
	wts <- rep(runif(20, 0.5, 2), each = 2)
	gotw <- unname(EDI:::fast_gaussian_lmm_gls_cpp(X = X, y = y, group_id = as.integer(g), log_sigma_e = -0.5, log_sigma_b = 0.2, weights = wts))
	expect_equal(gotw, unname(hand_gls(X, y, g, -0.5, 0.2, wts)), tolerance = 1e-8)
})

test_that("GLS bootstrap fast path (opt-in) needs cached variance components and returns the kernel's treatment coefficient", {
	f <- lmm_fx(use_gls_fast_path_bootstrap = TRUE)
	expect_true(f$p$use_gls_fast_path_bootstrap)
	est <- f$inf$compute_estimate()
	vc <- f$p$cached_vc_params
	expect_false(is.null(vc))
	Xf <- as.matrix(f$p$create_design_matrix()); colnames(Xf)[colnames(Xf) == "treatment"] <- "w"
	k <- EDI:::fast_gaussian_lmm_gls_cpp(X = Xf, y = as.numeric(f$y), group_id = as.integer(f$g),
		log_sigma_e = vc[1], log_sigma_b = vc[2], weights = rep(1, f$n))
	expect_equal(f$p$weighted_rcpp_estimate(rep(1, f$n), TRUE), unname(k[2]))
	# Without cached components it falls back to the full weighted fit, which reproduces the estimate.
	g <- lmm_fx(use_gls_fast_path_bootstrap = TRUE)
	expect_null(g$p$cached_vc_params)
	expect_equal(g$p$weighted_rcpp_estimate(rep(1, g$n), TRUE), est, tolerance = 1e-3)
})
