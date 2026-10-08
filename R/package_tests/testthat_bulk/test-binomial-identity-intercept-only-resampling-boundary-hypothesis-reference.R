library(testthat)
library(EDI)

make_intercept_only_identity_fixture <- function() {
	set.seed(27027L)
	n <- 60L
	w <- rep(0:1, each = n / 2L)
	y <- rbinom(n, 1L, 0.3)
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$overwrite_all_subject_assignments(w)
	des$add_all_subject_responses(y)
	inf <- InferenceIncidBinomialIdentityRiskDiff$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, w = w, y = y, n = n)
}

test_that("intercept-only identity fits cannot trigger fitted-probability boundary rejection", {
	f <- make_intercept_only_identity_fixture()
	est <- as.numeric(f$inf$compute_estimate(estimate_only = TRUE))

	# With an intercept and binary treatment only, the model is saturated for the
	# two arms: its fitted probabilities are the two observed arm proportions.
	# This algebraically rules out the proposed outside-[0,1] boundary mechanism.
	expect_equal(est, mean(f$y[f$w == 1L]) - mean(f$y[f$w == 0L]), tolerance = 1e-10)
	mod <- f$inf$.__enclos_env__$private$cached_mod
	mu <- cbind(1, f$w) %*% as.numeric(mod$b)
	expect_true(all(mu >= 0 & mu <= 1))
	expect_equal(unique(as.numeric(mu[f$w == 0L])), mean(f$y[f$w == 0L]), tolerance = 1e-10)
	expect_equal(unique(as.numeric(mu[f$w == 1L])), mean(f$y[f$w == 1L]), tolerance = 1e-10)
})

test_that("intercept-only m-out-of-n and subsampling draws remain fully estimable", {
	f <- make_intercept_only_identity_fixture()
	b <- floor(f$n ^ 0.7)
	f$inf$set_seed(27028L)
	m_draws <- f$inf$approximate_m_out_of_n_bootstrap_distribution_beta_hat_T(
		B = 31L, m = b, show_progress = FALSE, debug = TRUE
	)
	f$inf$set_seed(27028L)
	s_draws <- f$inf$approximate_subsampling_distribution_beta_hat_T(
		B = 31L, b = b, show_progress = FALSE, debug = TRUE
	)

	expect_length(m_draws$values, 31L)
	expect_length(s_draws$values, 31L)
	expect_true(all(is.finite(m_draws$values)))
	expect_true(all(is.finite(s_draws$values)))
	expect_true(all(abs(m_draws$values) <= 1))
	expect_true(all(abs(s_draws$values) <= 1))
})
