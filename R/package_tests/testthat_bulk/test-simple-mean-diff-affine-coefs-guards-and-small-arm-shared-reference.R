library(testthat)
library(EDI)

# InferenceAllSimpleAverageDiff's private compute_rand_bootstrap_ci_affine_coefs()
# guard branches (empty draws, malformed draws, degenerate splits) checked on
# hand-built draws against a from-scratch A_b / c_b formula, and shared()'s
# Welch quantities plus its small-arm (n <= 1 per arm) branch. The existing
# rand-bootstrap test covers the happy-path decomposition only.

smd_fixture <- function(w = NULL, n = 20L, seed = 123L) {
	set.seed(seed)
	des <- DesignFixedBernoulli$new(n = n, response_type = "continuous", seed = seed)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	if (!is.null(w)) des$overwrite_all_subject_assignments(w)
	w_use <- des$get_w()
	y <- w_use + rnorm(n, sd = 0.3)
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w_use, y = y, n = n)
}

test_that("affine coefficients match A_b = raw mean difference and c_b = 1 - mean(w_obs|T) + mean(w_obs|C) on hand-built draws", {
	f <- smd_fixture()
	set.seed(3)
	draws <- lapply(1:5, function(b) {
		i_b <- sample(f$n, f$n, replace = TRUE)
		list(i_b = i_b, w_b = sample(rep(0:1, length.out = f$n)))
	})
	aff <- f$priv$compute_rand_bootstrap_ci_affine_coefs(draws)
	for (b in 1:5) {
		i <- draws[[b]]$i_b; wf <- draws[[b]]$w_b
		yb <- f$y[i]; wo <- f$w[i]
		expect_equal(aff$A[b], mean(yb[wf == 1]) - mean(yb[wf == 0]), tolerance = 1e-12, info = b)
		expect_equal(aff$c[b], 1 - mean(wo[wf == 1]) + mean(wo[wf == 0]), tolerance = 1e-12, info = b)
	}
})

test_that("empty and malformed draw lists return NULL", {
	f <- smd_fixture()
	expect_null(f$priv$compute_rand_bootstrap_ci_affine_coefs(list()))
	good <- list(i_b = seq_len(f$n), w_b = rep(0:1, length.out = f$n))
	expect_null(f$priv$compute_rand_bootstrap_ci_affine_coefs(list(good, list(i_b = seq_len(f$n)))))                       # no w_b
	expect_null(f$priv$compute_rand_bootstrap_ci_affine_coefs(list(good, list(i_b = 1:5, w_b = rep(0:1, length.out = f$n)))))  # short i_b
	expect_null(f$priv$compute_rand_bootstrap_ci_affine_coefs(list(good, list(i_b = seq_len(f$n), w_b = c(0, 1)))))            # short w_b
})

test_that("draws with an empty or full treated arm are skipped as NA without aborting the rest", {
	f <- smd_fixture()
	ok <- list(i_b = seq_len(f$n), w_b = rep(0:1, length.out = f$n))
	none <- list(i_b = seq_len(f$n), w_b = rep(0L, f$n))
	all_t <- list(i_b = seq_len(f$n), w_b = rep(1L, f$n))
	aff <- f$priv$compute_rand_bootstrap_ci_affine_coefs(list(none, ok, all_t))
	expect_true(is.na(aff$A[1]) && is.na(aff$c[1]))
	expect_true(is.finite(aff$A[2]) && is.finite(aff$c[2]))
	expect_true(is.na(aff$A[3]) && is.na(aff$c[3]))
})

test_that("shared() caches Welch SE and Satterthwaite df and the likelihood-test context", {
	f <- smd_fixture()
	f$priv$shared()
	yT <- f$y[f$w == 1]; yC <- f$y[f$w == 0]
	s1 <- var(yT) / length(yT); s2 <- var(yC) / length(yC)
	expect_equal(f$priv$cached_values$s_beta_hat_T, sqrt(s1 + s2), tolerance = 1e-12)
	expect_equal(f$priv$cached_values$df, (s1 + s2)^2 / (s1^2 / (length(yT) - 1) + s2^2 / (length(yC) - 1)), tolerance = 1e-12)
	ctx <- f$priv$cached_values$likelihood_test_context
	expect_equal(ctx$j, 2L)
	expect_equal(ctx$X, cbind(1, f$w), ignore_attr = TRUE)
	expect_equal(ctx$full_fit$b, c(mean(yC), mean(yT) - mean(yC)), tolerance = 1e-12)
	expect_equal(ctx$full_fit$vt, var(yT), tolerance = 1e-12)
	expect_equal(ctx$full_fit$vc, var(yC), tolerance = 1e-12)

	# Second call is a no-op (cached).
	f$priv$cached_values$s_beta_hat_T <- 123
	f$priv$shared()
	expect_equal(f$priv$cached_values$s_beta_hat_T, 123)
})

test_that("an arm with a single subject leaves the SE and df unavailable", {
	w <- c(1L, rep(0L, 19L))
	f <- smd_fixture(w = w)
	f$priv$shared()
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(is.na(f$priv$cached_values$df))
	expect_null(f$priv$cached_values$likelihood_test_context)
	expect_true(is.finite(f$inf$compute_estimate()))
})
