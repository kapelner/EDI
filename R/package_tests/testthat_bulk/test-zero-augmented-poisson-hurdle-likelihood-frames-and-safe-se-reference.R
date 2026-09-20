library(testthat)
library(EDI)

# The zero-augmented Poisson base (inference_count_zero_augmented_poisson_abstract.R), via
# InferenceCountHurdlePoisson: hurdle_poisson_neg_loglik() against the hand-written hurdle
# likelihood (and its optimum vs the class's own estimate), build_component_frame() /
# build_formula_from_matrix(), invalidate_likelihood_fit() and safe_zero_augmented_vcov_se().

hz_fx <- function(seed = 3L, n = 150L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x)); des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- ifelse(runif(n) < plogis(-0.3 - 0.5 * w), 0L, 1L + rpois(n, exp(0.4 + 0.3 * w + 0.2 * x)))
	des$add_all_subject_responses(y)
	inf <- InferenceCountHurdlePoisson$new(des, verbose = FALSE)
	list(inf = inf, p = inf$.__enclos_env__$private, w = w, x = x, y = y, n = n)
}

ref_hurdle_nll <- function(par, y, Xc, Xz) {
	eta_c <- drop(Xc %*% par[seq_len(ncol(Xc))]); eta_z <- drop(Xz %*% par[ncol(Xc) + seq_len(ncol(Xz))])
	lambda <- exp(eta_c); pi0 <- plogis(eta_z)
	ll <- ifelse(y == 0, log(pi0), log(1 - pi0) + dpois(y, lambda, log = TRUE) - log(1 - exp(-lambda)))
	-sum(ll)
}

test_that("hurdle negative log-likelihood equals the zero-mass + zero-truncated Poisson definition up to the log-factorial constant", {
	f <- hz_fx()
	Xc <- cbind(1, f$w, f$x); Xz <- cbind(1, f$w)
	for (par in list(c(0.4, 0.3, 0.2, -0.3, -0.5), c(0, 0, 0, 0, 0), c(1, -0.5, 0.1, 0.5, 0.2))) {
		# The class drops the parameter-free -lgamma(y + 1) term of the positive counts.
		const <- sum(lgamma(f$y[f$y > 0] + 1))
		expect_equal(f$p$hurdle_poisson_neg_loglik(par, Xc, Xz) + const, ref_hurdle_nll(par, f$y, Xc, Xz), tolerance = 1e-10)
	}
	# Differences between parameter values are unaffected by that constant.
	a <- c(0.4, 0.3, 0.2, -0.3, -0.5); b <- c(1, -0.5, 0.1, 0.5, 0.2)
	expect_equal(f$p$hurdle_poisson_neg_loglik(a, Xc, Xz) - f$p$hurdle_poisson_neg_loglik(b, Xc, Xz),
		ref_hurdle_nll(a, f$y, Xc, Xz) - ref_hurdle_nll(b, f$y, Xc, Xz), tolerance = 1e-10)
})

test_that("its minimiser reproduces the class's conditional treatment estimate", {
	f <- hz_fx()
	Xc <- cbind(1, f$w, f$x); Xz <- cbind(1, f$w)
	opt <- optim(c(0.4, 0.3, 0.2, -0.3, -0.5), function(b) f$p$hurdle_poisson_neg_loglik(b, Xc, Xz), method = "BFGS", control = list(reltol = 1e-12, maxit = 500))
	expect_equal(opt$par[2], f$inf$compute_estimate(), tolerance = 2e-2)
	# The optimum is a stationary point of the independent reference too.
	expect_lt(max(abs(numDeriv::grad(function(b) ref_hurdle_nll(b, f$y, Xc, Xz), opt$par))), 1e-3)
})

test_that("component frame: response, treatment and the extra covariates of both parts, zero-part duplicates dropped", {
	f <- hz_fx()
	Xc <- cbind("(Intercept)" = 1, w = f$w, "a b" = f$x, z = f$x^2)
	Xz <- cbind("(Intercept)" = 1, w = f$w, z = f$x^2, q = f$x^3)
	d <- f$p$build_component_frame(Xc, Xz)
	expect_equal(names(d), c("y", "w", "a.b", "z", "q"))                            # make.names() applied; the shared covariate z appears once
	expect_equal(d$y, as.numeric(f$y)); expect_equal(d$w, f$w)
	expect_equal(d$q, f$x^3)
	only2 <- f$p$build_component_frame(Xc[, 1:2], Xz[, 1:2])
	expect_equal(names(only2), c("y", "w"))
})

test_that("formula builder: response ~ covariate terms, intercept-only when none, one-sided when the response is NULL", {
	f <- hz_fx()
	X <- cbind("(Intercept)" = 1, w = 1, x1 = 2, x2 = 3)
	expect_equal(deparse(f$p$build_formula_from_matrix(X)), "y ~ w + x1 + x2")
	expect_equal(deparse(f$p$build_formula_from_matrix(X, response = "z")), "z ~ w + x1 + x2")
	expect_equal(deparse(f$p$build_formula_from_matrix(X, response = NULL)), "~w + x1 + x2")
	expect_equal(deparse(f$p$build_formula_from_matrix(X[, 1, drop = FALSE])), "y ~ 1")
})

test_that("invalidating the fit clears the cached model and likelihood context and flags the estimate nonestimable", {
	f <- hz_fx()
	f$inf$compute_estimate()
	f$p$cached_values$likelihood_test_context <- list(x = 1)
	f$p$cached_mod <- list(b = 1)
	expect_null(f$p$invalidate_likelihood_fit("za_test_reason"))
	expect_null(f$p$cached_mod); expect_null(f$p$cached_values$likelihood_test_context)
	expect_true(f$inf$is_nonestimable("estimate"))
	expect_identical(f$inf$get_nonestimable_reason(), "za_test_reason")
})

test_that("safe vcov SE: the square root of the treatment diagonal entry for a valid matrix, NA for missing / short / malformed matrices", {
	f <- hz_fx()
	g <- f$p$safe_zero_augmented_vcov_se
	V <- diag(c(1, 4, 9))
	expect_equal(g(list(vcov = V)), 2)                                              # sqrt of entry [2, 2] by default
	expect_equal(g(list(vcov = V), j_treat = 3L), 3)
	expect_true(is.na(g(list(vcov = NULL))))
	expect_true(is.na(g(list(vcov = V[1, , drop = FALSE]))))
	expect_true(is.na(g(list(vcov = V), j_treat = 4L)))
	expect_true(is.na(g(list(vcov = c(1, 2)))))
	expect_true(is.na(g(list())))
})
