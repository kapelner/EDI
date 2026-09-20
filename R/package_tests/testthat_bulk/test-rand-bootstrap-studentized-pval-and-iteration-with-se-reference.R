library(testthat)
library(EDI)

# Bootstrap-randomization studentized machinery (InferenceRandBootstrap):
# compute_two_sided_brt_pval_studentized() against hand-written formulas (one-sided
# tail proportions doubled for the asymmetric form, |z| exceedance for the symmetric
# form, 2 / n_ok floor, invalid-input NA rules) and run_rand_bootstrap_iteration_with_se()
# (one bootstrap null draw -> (t0, se0)) against a hand-computed Welch difference.

fx <- function(n = 30L) {
	set.seed(3)
	des <- DesignFixediBCRD$new(n = n, response_type = "continuous", verbose = FALSE, seed = 3L)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnorm(n) + 0.5 * w
	des$add_all_subject_responses(y)
	inf <- InferenceAllSimpleAverageDiff$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, y = y, n = n)
}

test_that("asymmetric studentized p is twice the smaller tail proportion of the studentized null draws", {
	f <- fx()
	set.seed(1)
	t0 <- rnorm(200, sd = 0.5); se0 <- runif(200, 0.2, 0.6)
	for (t_obs in c(-1, 0.1, 0.9)) {
		delta <- 0.05; se_obs <- 0.4
		z0 <- (t0 - delta) / se0; zo <- (t_obs - delta) / se_obs
		ref <- min(1, max(2 / 200, 2 * min(mean(z0 >= zo), mean(z0 <= zo))))
		expect_equal(f$priv$compute_two_sided_brt_pval_studentized(t_obs, t0, se0, delta, se_obs), ref, info = t_obs)
	}
})

test_that("symmetric studentized p is the proportion of |z| exceedances", {
	f <- fx()
	set.seed(2)
	t0 <- rnorm(150); se0 <- runif(150, 0.5, 1.5)
	ref <- function(t_obs, delta, se_obs) min(1, max(2 / 150, mean(abs(t0 - delta) / se0 >= abs(t_obs - delta) / se_obs)))
	for (t_obs in c(0.2, 1.5, 4)) {
		expect_equal(f$priv$compute_two_sided_brt_pval_studentized(t_obs, t0, se0, 0.1, 0.7, symmetric = TRUE), ref(t_obs, 0.1, 0.7), info = t_obs)
	}
	# Symmetric form is invariant to reflecting the observed statistic about delta.
	expect_equal(f$priv$compute_two_sided_brt_pval_studentized(0.1 + 1, t0, se0, 0.1, 0.7, TRUE),
		f$priv$compute_two_sided_brt_pval_studentized(0.1 - 1, t0, se0, 0.1, 0.7, TRUE))
})

test_that("the 2 / n_ok floor and the cap at one apply, and unusable draws are excluded from n_ok", {
	f <- fx()
	# No draw as extreme as the observation: floor 2 / n_ok with n_ok counting only usable draws.
	t0 <- c(rep(0, 8), NA, Inf); se0 <- c(rep(1, 8), 1, 1)
	expect_equal(f$priv$compute_two_sided_brt_pval_studentized(50, t0, se0, 0, 1), 2 / 8)
	expect_equal(f$priv$compute_two_sided_brt_pval_studentized(50, t0, se0, 0, 1, symmetric = TRUE), 2 / 8)
	# Everything at the null centre: capped at 1.
	expect_equal(f$priv$compute_two_sided_brt_pval_studentized(0, rep(0, 10), rep(1, 10), 0, 1), 1)
	# Non-positive / non-finite draw SEs are dropped.
	t0b <- c(0, 0, 0, 5); se0b <- c(1, 1, 1, 0)
	expect_equal(f$priv$compute_two_sided_brt_pval_studentized(3, t0b, se0b, 0, 1), 2 / 3)
})

test_that("invalid observed statistic / SE or no usable draws give NA", {
	f <- fx()
	p <- f$priv$compute_two_sided_brt_pval_studentized
	expect_true(is.na(p(1, rnorm(5), rep(1, 5), 0, 0)))
	expect_true(is.na(p(1, rnorm(5), rep(1, 5), 0, -1)))
	expect_true(is.na(p(1, rnorm(5), rep(1, 5), 0, NA_real_)))
	expect_true(is.na(p(NA_real_, rnorm(5), rep(1, 5), 0, 1)))
	expect_true(is.na(p(1, rnorm(5), rep(0, 5), 0, 1)))
	expect_true(is.na(p(1, rep(NA_real_, 5), rep(1, 5), 0, 1)))
})

test_that("one null draw returns the Welch mean difference and SE of the resampled, shifted data", {
	f <- fx()
	set.seed(8)
	for (delta in c(0, 0.3, -0.7)) {
		d <- list(i_b = sample(f$n, f$n, TRUE), w_b = sample(rep(0:1, length.out = f$n)))
		out <- f$priv$run_rand_bootstrap_iteration_with_se(d, delta, "none", f$y)
		ys <- f$y[d$i_b]; ww <- d$w_b
		ys[ww == 1] <- ys[ww == 1] + delta
		a <- ys[ww == 1]; b <- ys[ww == 0]
		expect_equal(unname(out["t0"]), mean(a) - mean(b), tolerance = 1e-10, info = delta)
		expect_equal(unname(out["se0"]), sqrt(var(a) / length(a) + var(b) / length(b)), tolerance = 1e-10, info = delta)
		expect_named(out, c("t0", "se0"))
	}
})

test_that("a draw whose assignment length does not match its resample yields NA statistics", {
	f <- fx()
	set.seed(9)
	i_b <- sample(f$n, f$n, TRUE)
	out <- f$priv$run_rand_bootstrap_iteration_with_se(list(i_b = i_b[-1], w_b = sample(rep(0:1, length.out = f$n))), 0, "none", f$y)
	expect_true(all(is.na(out)))
})
