library(testthat)
library(EDI)

# InferenceCountNegBin's explicit jackknife non-estimability methods and its
# private likelihood-test plumbing (get_likelihood_test_spec with its
# boundary_information guard, simulate_under_lik_null). References: an
# independent dnbinom log-likelihood in the (beta, log theta) parameterization
# differentiated with numDeriv, and a from-scratch seeded simulation.

nb_fixture <- function(seed = 6L, n = 120L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 2, mu = exp(0.5 + 0.4 * w + 0.3 * x))
	des$add_all_subject_responses(y)
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w, x = x, y = y, n = n)
}

nb_loglik <- function(par, X, y) {
	p <- ncol(X)
	sum(dnbinom(y, size = exp(par[p + 1L]), mu = exp(as.numeric(X %*% par[seq_len(p)])), log = TRUE))
}

test_that("every jackknife method reports the explicit unsupported state", {
	f <- nb_fixture()
	expect_true(is.na(f$inf$compute_jackknife_estimate()))
	expect_true(is.na(f$inf$compute_jackknife_bias_estimate()))
	expect_true(is.na(f$inf$compute_jackknife_std_error()))
	expect_true(is.na(f$inf$compute_jackknife_wald_two_sided_pval(delta = 0.1)))
	ci <- f$inf$compute_jackknife_wald_confidence_interval(alpha = 0.1)
	expect_true(all(is.na(ci)))
	expect_equal(names(ci), c("5%", "95%"))
	expect_true(f$inf$is_nonestimable("se"))
})

test_that("likelihood spec's neg_loglik, score and information match independent numeric references", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	expect_equal(sp$j, 2L)
	fit <- sp$full_fit
	par <- c(as.numeric(fit$b), log(as.numeric(fit$theta_hat)))

	ll <- function(p) nb_loglik(p, sp$X, sp$y)
	expect_equal(sp$neg_loglik(fit), -ll(par), tolerance = 1e-6)
	expect_equal(as.numeric(sp$score(fit)), numDeriv::grad(ll, par), tolerance = 1e-4)
	num_info <- -numDeriv::hessian(ll, par)
	expect_equal(unname(sp$observed_information(fit)), unname(num_info), tolerance = 1e-3)
	expect_equal(sp$fisher_information(fit), sp$observed_information(fit))
	expect_equal(sp$information(fit), sp$observed_information(fit))
	expect_equal(sp$extract_start(fit), par)
})

test_that("neg_loglik falls back through the alternative field names", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	expect_equal(sp$neg_loglik(list(neg_loglik = 3)), 3)
	expect_equal(sp$neg_loglik(list(neg_log_lik = 4)), 4)
	expect_equal(sp$neg_loglik(list(neg_ll = 5)), 5)
	expect_equal(sp$neg_loglik(list(logLik = -6)), 6)
	expect_equal(sp$neg_loglik(list(log_lik = -7)), 7)
	expect_true(is.na(sp$neg_loglik(list())))
})

test_that("the Poisson-boundary flag decouples the dispersion coordinate of the information matrix", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	fit <- sp$full_fit
	base <- sp$information(fit)
	expect_false(isTRUE(fit$dispersion_at_poisson_boundary))

	bounded <- fit
	bounded$dispersion_at_poisson_boundary <- TRUE
	adj <- sp$information(bounded)
	k <- nrow(base)
	expect_equal(adj[k, k], 1)
	expect_true(all(adj[k, -k] == 0) && all(adj[-k, k] == 0))
	expect_equal(adj[-k, -k], base[-k, -k])
})

test_that("fit_null pins the treatment coefficient at the null value", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	expect_true(isTRUE(nf$converged))
	expect_equal(as.numeric(nf$b[sp$j]), 0)
	expect_gte(sp$neg_loglik(nf), sp$neg_loglik(sp$full_fit) - 1e-6)
	nf2 <- sp$fit_null(0.3)
	expect_equal(as.numeric(nf2$b[sp$j]), 0.3)
})

test_that("simulate_under_lik_null draws from the null NB model and refits full and null fits", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)

	set.seed(77)
	sim <- f$priv$simulate_under_lik_null(sp, 0, nf)
	expect_named(sim, c("full_fit", "fit_null", "neg_loglik"))

	set.seed(77)
	mu <- pmax(exp(as.numeric(sp$X %*% as.numeric(nf$b))), 0)
	y_sim <- as.integer(rnbinom(length(mu), size = as.numeric(nf$theta_hat), mu = mu))
	par_full <- c(as.numeric(sim$full_fit$b), log(as.numeric(sim$full_fit$theta_hat)))
	expect_equal(sim$neg_loglik(sim$full_fit), -nb_loglik(par_full, sp$X, y_sim), tolerance = 1e-6)

	sim_null <- sim$fit_null(0)
	if (!is.null(sim_null)) {
		expect_equal(as.numeric(sim_null$b[sp$j]), 0)
		expect_gte(sim$neg_loglik(sim_null), sim$neg_loglik(sim$full_fit) - 1e-6)
	}
})

test_that("simulate_under_lik_null declines when the null dispersion is unusable", {
	f <- nb_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	for (bad in list(0, -1, NA_real_, Inf)) {
		nf_bad <- nf
		nf_bad$theta_hat <- bad
		expect_null(f$priv$simulate_under_lik_null(sp, 0, nf_bad))
	}
})
