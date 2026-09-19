library(testthat)
library(EDI)

# InferenceIncidBinomialIdentityRiskDiff's private likelihood-test plumbing
# (get_likelihood_test_spec, simulate_under_lik_null) and its
# is_identity_binomial_fit_reasonable() predicate. Existing coverage
# (test-binomial-identity-weighted-refit-reference.R) targets only the
# weighted-refit path; these private helpers were only touched indirectly.
# Each assertion is checked against an independent from-scratch reference
# (direct binomial log-likelihood, numDeriv derivatives, optim), not against
# the package's own C++ kernels.

make_binid_fixture <- function(seed = 1L, n = 80L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$overwrite_all_subject_assignments(rep(0:1, length.out = n))
	w <- des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, 0.3 + 0.2 * w))
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE)
	list(inf = inf, priv = inf$.__enclos_env__$private)
}

ref_loglik <- function(b, X, y) {
	mu <- as.numeric(X %*% b)
	sum(y * log(pmax(mu, 1e-15)) + (1 - y) * log(pmax(1 - mu, 1e-15)))
}

test_that("get_likelihood_test_spec()'s neg_loglik/score/information match independent numeric references", {
	f <- make_binid_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	expect_equal(sp$j, 2L)
	fit <- sp$full_fit
	b <- as.numeric(fit$b)

	expect_equal(sp$neg_loglik(fit), -ref_loglik(b, sp$X, sp$y), tolerance = 1e-10)

	# Score of the log-likelihood vanishes at the interior MLE, and at a
	# perturbed point matches an independent numerical gradient.
	expect_lt(max(abs(sp$score(fit))), 1e-4)
	b_pert <- b + c(0.01, -0.02, 0.005)
	fit_pert <- list(b = b_pert)
	num_grad <- numDeriv::grad(function(p) ref_loglik(p, sp$X, sp$y), b_pert)
	expect_equal(sp$score(fit_pert), num_grad, tolerance = 1e-4)

	num_hess <- numDeriv::hessian(function(p) ref_loglik(p, sp$X, sp$y), b)
	expect_equal(unname(sp$observed_information(fit)), unname(-num_hess), tolerance = 1e-3)
	expect_equal(sp$fisher_information(fit), sp$observed_information(fit))
	expect_equal(sp$information(fit), sp$observed_information(fit))
	expect_equal(sp$extract_start(fit), b)
})

test_that("get_likelihood_test_spec()'s fit_null pins the treatment coefficient and matches an independent constrained optimum", {
	f <- make_binid_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)
	expect_equal(as.numeric(nf$b[sp$j]), 0)
	expect_gte(sp$neg_loglik(nf), sp$neg_loglik(sp$full_fit) - 1e-8)

	free <- setdiff(seq_len(ncol(sp$X)), sp$j)
	obj <- function(p) {
		b <- numeric(ncol(sp$X)); b[free] <- p
		mu <- as.numeric(sp$X %*% b)
		if (any(mu <= 1e-9 | mu >= 1 - 1e-9)) return(1e10)
		-ref_loglik(b, sp$X, sp$y)
	}
	start <- as.numeric(nf$b)[free]
	opt <- optim(start, obj, method = "Nelder-Mead", control = list(reltol = 1e-12, maxit = 5000))
	expect_equal(sp$neg_loglik(nf), opt$value, tolerance = 1e-4)

	# Pinning the treatment coefficient at a nonzero value is honored too.
	nf2 <- sp$fit_null(0.1)
	expect_equal(as.numeric(nf2$b[sp$j]), 0.1)
})

test_that("simulate_under_lik_null draws y_sim from the clipped null mean and refits consistently", {
	f <- make_binid_fixture()
	sp <- f$priv$get_likelihood_test_spec()
	nf <- sp$fit_null(0)

	set.seed(202)
	sim <- f$priv$simulate_under_lik_null(sp, 0, nf)
	expect_true(is.list(sim))
	expect_named(sim, c("full_fit", "fit_null", "neg_loglik"))

	set.seed(202)
	mu <- pmin(pmax(as.numeric(sp$X %*% as.numeric(nf$b)), 0), 1)
	y_sim <- as.numeric(rbinom(length(mu), 1L, mu))
	expect_equal(
		sim$neg_loglik(sim$full_fit),
		-ref_loglik(as.numeric(sim$full_fit$b), sp$X, y_sim),
		tolerance = 1e-10
	)
	sim_null <- sim$fit_null(0)
	if (!is.null(sim_null)) {
		expect_equal(as.numeric(sim_null$b[sp$j]), 0)
		expect_gte(sim$neg_loglik(sim_null), sim$neg_loglik(sim$full_fit) - 1e-8)
	}
})

test_that("is_identity_binomial_fit_reasonable() enforces finiteness, convergence, index and [0,1]-mean constraints", {
	f <- make_binid_fixture()
	ok <- f$priv$is_identity_binomial_fit_reasonable
	X <- cbind(1, c(0, 1, 0, 1))

	expect_false(ok(NULL))
	expect_false(ok(list(b = NULL)))
	expect_true(ok(list(b = c(0.3, 0.2))))
	expect_false(ok(list(b = c(0.3, NA))))
	expect_false(ok(list(b = c(0.3, Inf))))
	expect_false(ok(list(b = c(0.3, 0.2), converged = FALSE)))
	expect_true(ok(list(b = c(0.3, 0.2), converged = TRUE)))
	expect_false(ok(list(b = c(0.3)), j_treat = 2L))
	expect_false(ok(list(b = c(0.3, 0.2)), j_treat = 0L))
	expect_false(ok(list(b = c(0.3, 0.2)), j_treat = c(1L, 2L)))
	# j_treat falls back to the fit's own j_treat, then to 2.
	expect_false(ok(list(b = c(0.3, 0.2), j_treat = 5L), j_treat = NULL))
	# Implied means outside [0, 1] (beyond the 1e-8 tolerance) are rejected.
	expect_true(ok(list(b = c(0.3, 0.2)), X_fit = X))
	expect_false(ok(list(b = c(0.3, 0.8)), X_fit = X))
	expect_false(ok(list(b = c(-0.1, 0.2)), X_fit = X))
	expect_true(ok(list(b = c(0, 1)), X_fit = X))
})
