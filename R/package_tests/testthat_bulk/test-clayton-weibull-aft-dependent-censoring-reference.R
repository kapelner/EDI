library(testthat)
library(EDI)

# .fit_clayton_weibull_aft (R/EDI/R/helper_survival_fits.R) has zero test
# references anywhere in the suite despite being a real dependent-censoring
# fitter used by simulation/audit machinery. Independent from-scratch
# reference: the standard Clayton bivariate-copula log-likelihood, derived
# directly from copula partial derivatives (Genest & MacKay 1986), not by
# reusing the package's private .clayton_copula_logA/.weibull_aft_margin_terms
# helpers -- same model, independently coded.
independent_clayton_weibull_neg_loglik <- function(par, y, dead, X, pair_idx, singleton_rows) {
	num_beta <- ncol(X)
	beta <- par[seq_len(num_beta)]
	sigma <- exp(par[num_beta + 1L])
	theta <- exp(par[num_beta + 2L])
	eta <- as.vector(X %*% beta)
	H <- exp((log(y) - eta) / sigma)
	log_f <- log(H) - log(sigma) - log(y) - H  # d/dt[-log S(t)] * S(t), i.e. hazard*survival

	ll <- 0
	if (nrow(pair_idx) > 0) {
		i1 <- pair_idx[, 1]; i2 <- pair_idx[, 2]
		d1 <- dead[i1]; d2 <- dead[i2]
		A <- exp(theta * H[i1]) + exp(theta * H[i2]) - 1
		logA <- log(A)
		for (k in seq_along(i1)) {
			if (d1[k] == 0 && d2[k] == 0) {
				ll <- ll - (1 / theta) * logA[k]
			} else if (d1[k] == 1 && d2[k] == 0) {
				ll <- ll + log_f[i1[k]] + (theta + 1) * H[i1[k]] + (-1 / theta - 1) * logA[k]
			} else if (d1[k] == 0 && d2[k] == 1) {
				ll <- ll + log_f[i2[k]] + (theta + 1) * H[i2[k]] + (-1 / theta - 1) * logA[k]
			} else {
				ll <- ll + log(theta + 1) + log_f[i1[k]] + log_f[i2[k]] +
					(theta + 1) * (H[i1[k]] + H[i2[k]]) + (-1 / theta - 2) * logA[k]
			}
		}
	}
	if (length(singleton_rows) > 0) {
		d <- dead[singleton_rows]
		ll <- ll + sum(d * log_f[singleton_rows] - (1 - d) * H[singleton_rows])
	}
	-ll
}

make_clayton_pair_fixture <- function(n_pairs = 60L, theta_true = 2.5, seed = 918) {
	set.seed(seed)
	n <- n_pairs * 2L
	w <- rep(c(0, 1), n_pairs)
	pair_id <- rep(seq_len(n_pairs), each = 2L)
	eta <- 0.3 + 0.6 * w
	sigma_true <- 0.8
	# Clayton-dependent Gumbel-margin draws via the conditional method for
	# theta > 0: U1 ~ Unif, U2 | U1 from the Clayton conditional inverse-cdf.
	u1 <- runif(n_pairs)
	v <- runif(n_pairs)
	u2 <- (v^(-theta_true / (theta_true + 1)) * (u1^(-theta_true) - 1) + 1)^(-1 / theta_true)
	# invert Weibull-AFT survival S(t) = exp(-exp((log t - eta)/sigma)) => H = -log(u)
	H1 <- -log(u1)
	H2 <- -log(u2)
	t1 <- exp(eta[seq(1, n, by = 2)] + sigma_true * log(H1))
	t2 <- exp(eta[seq(2, n, by = 2)] + sigma_true * log(H2))
	y_true <- as.numeric(rbind(t1, t2))
	cens_time <- rexp(n, rate = 1 / (3 * median(y_true)))
	y <- pmin(y_true, cens_time)
	dead <- as.integer(y_true <= cens_time)
	X <- cbind(w = w)
	list(y = y, dead = dead, X = X, pair_id = pair_id)
}

test_that(".fit_clayton_weibull_aft's optimum matches an independent Clayton copula log-likelihood", {
	f <- make_clayton_pair_fixture()
	fit <- EDI:::.fit_clayton_weibull_aft(f$y, f$dead, f$X, f$pair_id, optimization_alg = "lbfgs")

	expect_false(is.null(fit))
	expect_true(is.finite(fit$beta))
	expect_true(is.finite(fit$ssq))
	expect_gt(fit$ssq, 0)
	expect_true(fit$theta > 0)

	pair_idx <- EDI:::.complete_pair_index_matrix(f$pair_id)
	X_full <- cbind("(Intercept)" = 1, f$X)
	my_neg_ll <- independent_clayton_weibull_neg_loglik(
		fit$best_par, f$y, f$dead, X_full, pair_idx, integer(0)
	)
	# best_fit$value is either the C++ optimizer's or optim()'s minimized value;
	# both should equal an independently-coded evaluation of the same
	# log-likelihood at the same parameter vector.
	expect_equal(my_neg_ll, fit$best_fit$value, tolerance = 1e-4)

	# The optimum should also beat a clearly wrong parameter vector (theta near 0,
	# i.e. near-independence) on the same independent likelihood -- confirms the
	# fit is a real optimum, not an artifact of my reference formula happening to
	# match some fixed value.
	bad_par <- fit$best_par
	bad_par[length(bad_par)] <- log(0.01)
	worse_ll <- independent_clayton_weibull_neg_loglik(bad_par, f$y, f$dead, X_full, pair_idx, integer(0))
	expect_gt(worse_ll, my_neg_ll)
})

test_that(".fit_clayton_weibull_aft returns NULL with no complete pairs and include_singletons = FALSE", {
	f <- make_clayton_pair_fixture(n_pairs = 5L)
	broken_pair_id <- seq_along(f$y)  # every subject its own unique id -> no complete pairs
	fit <- EDI:::.fit_clayton_weibull_aft(f$y, f$dead, f$X, broken_pair_id, include_singletons = FALSE)
	expect_null(fit)
})

test_that(".fit_clayton_weibull_aft with include_singletons = TRUE uses unpaired rows instead of dropping them", {
	f <- make_clayton_pair_fixture(n_pairs = 5L)
	broken_pair_id <- seq_along(f$y)  # all singletons
	fit <- EDI:::.fit_clayton_weibull_aft(f$y, f$dead, f$X, broken_pair_id, include_singletons = TRUE)

	expect_false(is.null(fit))
	expect_true(is.finite(fit$beta))

	pair_idx <- matrix(integer(0), ncol = 2)
	X_full <- cbind("(Intercept)" = 1, f$X)
	my_neg_ll <- independent_clayton_weibull_neg_loglik(
		fit$best_par, f$y, f$dead, X_full, pair_idx, seq_along(f$y)
	)
	expect_equal(my_neg_ll, fit$best_fit$value, tolerance = 1e-4)
})

test_that(".fit_clayton_weibull_aft rejects mismatched row counts", {
	f <- make_clayton_pair_fixture(n_pairs = 5L)
	expect_error(
		EDI:::.fit_clayton_weibull_aft(f$y, f$dead[-1], f$X, f$pair_id),
		"matching row counts"
	)
})

test_that(".fit_clayton_weibull_aft(estimate_only = TRUE) skips vcov computation", {
	f <- make_clayton_pair_fixture(n_pairs = 30L)
	fit <- EDI:::.fit_clayton_weibull_aft(f$y, f$dead, f$X, f$pair_id, estimate_only = TRUE)

	expect_false(is.null(fit))
	expect_true(is.na(fit$ssq))
	expect_true(is.finite(fit$beta))
	expect_true(fit$theta > 0)
})
