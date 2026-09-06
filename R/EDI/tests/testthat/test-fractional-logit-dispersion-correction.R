test_that("InferencePropFractionalLogit applies a quasi-binomial dispersion correction to its variance", {
	# Regression for the 2026-09-06 comprehensive-results investigation:
	# generate_mod() used the raw Bernoulli Fisher information (X'WX with
	# W = mu(1-mu)) as the variance for beta_hat_T with no dispersion
	# correction. A genuinely fractional response's true conditional
	# variance is always <= mu(1-mu) (Bernoulli is the maximum-variance
	# distribution on [0,1] for a given mean), so the uncorrected variance
	# systematically overstates Var(beta_hat_T), pinning p-values near 1
	# (observed: 0/278 and 0/204 rejections under a true null). Fixed by
	# scaling ssq_b_2 by an estimated Pearson-residual quasi-binomial
	# dispersion parameter, Papke & Wooldridge's own prescription.
	set.seed(4401L)
	n <- 200L
	x <- rnorm(n)
	w <- rep(c(0, 1), n / 2)
	eta <- -0.3 + 0.4 * x
	mu <- plogis(eta)
	phi_true <- 20
	y <- pmin(pmax(rbeta(n, mu * phi_true, (1 - mu) * phi_true), 1e-4), 1 - 1e-4)

	des <- DesignFixedTestFixture$new(n = n, response_type = "proportion", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)

	inf <- InferencePropFractionalLogit$new(des, model_formula = ~ x, verbose = FALSE)
	inf$compute_estimate()

	fit <- inf$.__enclos_env__$private$cached_mod
	expect_true(is.finite(fit$dispersion))
	# The true overdispersion here is large (phi=20 on the Beta scale
	# implies a Pearson dispersion well below 1, since Beta(mu*phi,(1-mu)*phi)
	# has variance mu(1-mu)/(phi+1), much smaller than the Bernoulli
	# variance mu(1-mu) the naive Fisher information assumes) -- the
	# estimated dispersion should be well under 1, not left at the
	# uncorrected value of exactly 1.
	expect_lt(fit$dispersion, 0.5)

	p <- inf$compute_asymp_two_sided_pval()
	expect_true(is.finite(p) && p >= 0 && p <= 1)
})

test_that("InferencePropFractionalLogit asymptotic test is approximately correctly sized under H0", {
	set.seed(4402L)
	n <- 200L
	R <- 100L
	reject <- logical(R)
	for (r in seq_len(R)) {
		set.seed(5000L + r)
		x <- rnorm(n)
		w <- rep(c(0, 1), n / 2)
		eta <- -0.3 + 0.4 * x
		mu <- plogis(eta)
		phi_true <- 20
		y <- pmin(pmax(rbeta(n, mu * phi_true, (1 - mu) * phi_true), 1e-4), 1 - 1e-4)
		des <- DesignFixedTestFixture$new(n = n, response_type = "proportion", verbose = FALSE)
		des$add_all_subjects_to_experiment(data.frame(x = x))
		des$overwrite_all_subject_assignments(w)
		des$add_all_subject_responses(y)
		inf <- InferencePropFractionalLogit$new(des, model_formula = ~ x, verbose = FALSE)
		p <- inf$compute_asymp_two_sided_pval()
		reject[r] <- is.finite(p) && p < 0.05
	}
	# Nominal is 5%; before the fix this was ~0%. Allow a generous band
	# (well above the old 0% failure mode, well below a wildly inflated one).
	rejection_rate <- mean(reject)
	expect_gt(rejection_rate, 0.01)
	expect_lt(rejection_rate, 0.20)
})
