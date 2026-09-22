library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract's private zero_augmented_poisson_marginal_functional(theta, X, Xzi,
# is_hurdle, estimand): the G-computation average marginal mean-difference/log-ratio, column 2 (treatment) set to
# 1 vs. 0 across all subjects then averaged -- the same pattern already independently tested for the sibling
# logistic_marginal_functional()/poisson_family_marginal_functional() helpers, but never written for this family.
# Reference: the already-tested zero_augmented_poisson_mean_from_theta() (per-row ZIP/hurdle mean), averaged by
# hand under the same column-2 override. Also covers compute_marginal_estimand_estimate()'s nonestimable guards
# and its successful full path (point estimate, delta-method sandwich SE, Inf df, estimate_only skipping SE).

zip_fx <- function(seed = 4L, n = 100L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = runif(n))
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
	zi <- rbinom(n, 1, plogis(-1 + 0.5 * X$x1)); y <- ifelse(zi == 1, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.3 * X$x1)))
	d$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedPoisson$new(d, verbose = FALSE)
	Xc <- cbind(1, w, X$x1, X$x2); colnames(Xc) <- c("(Intercept)", "treatment", "x1", "x2")
	list(inf = inf, p = inf$.__enclos_env__$private, Xc = Xc)
}

ref_marginal <- function(mean_fn, theta, X, is_hurdle, ratio = FALSE) {
	X1 <- X; X1[, 2L] <- 1; X0 <- X; X0[, 2L] <- 0
	m1 <- mean(mean_fn(theta, X1, X1, is_hurdle)); m0 <- mean(mean_fn(theta, X0, X0, is_hurdle))
	if (ratio) log(m1 / m0) else m1 - m0
}

test_that("marginal_mean_diff and marginal_ratio match the hand-averaged column-2-override reference, for both ZIP and hurdle means", {
	f <- zip_fx()
	theta <- c(0.3, 0.4, 0.3, 0, -1, 0.5, 0, 0)
	mean_fn <- f$p$zero_augmented_poisson_mean_from_theta
	fn <- f$p$zero_augmented_poisson_marginal_functional

	expect_equal(fn(theta, f$Xc, f$Xc, FALSE, "marginal_mean_diff"), ref_marginal(mean_fn, theta, f$Xc, FALSE), tolerance = 1e-12)
	expect_equal(fn(theta, f$Xc, f$Xc, FALSE, "marginal_ratio"), ref_marginal(mean_fn, theta, f$Xc, FALSE, ratio = TRUE), tolerance = 1e-12)
	expect_equal(fn(theta, f$Xc, f$Xc, TRUE, "marginal_mean_diff"), ref_marginal(mean_fn, theta, f$Xc, TRUE), tolerance = 1e-12)
	expect_equal(fn(theta, f$Xc, f$Xc, TRUE, "marginal_ratio"), ref_marginal(mean_fn, theta, f$Xc, TRUE, ratio = TRUE), tolerance = 1e-12)
	# ZIP and hurdle genuinely differ on the same parameters (the hurdle truncated mean is not the ZIP mean)
	expect_false(isTRUE(all.equal(fn(theta, f$Xc, f$Xc, FALSE, "marginal_mean_diff"), fn(theta, f$Xc, f$Xc, TRUE, "marginal_mean_diff"))))
	# any estimand string other than exactly "marginal_ratio" falls through to the mean-difference branch
	expect_equal(fn(theta, f$Xc, f$Xc, FALSE, "anything_else"), ref_marginal(mean_fn, theta, f$Xc, FALSE), tolerance = 1e-12)
})

test_that("compute_marginal_estimand_estimate() is nonestimable when the raw fit or its parameters are unavailable", {
	f <- zip_fx()
	f$p$cached_mod <- list(mod = NULL)
	expect_true(is.na(f$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(f$inf$get_nonestimable_reason(), "zero_augmented_poisson_marginal_fit_unavailable")

	g <- zip_fx()
	g$p$cached_mod <- list(mod = list(params = NULL, X_fit = g$Xc, Xzi_fit = g$Xc))
	expect_true(is.na(g$p$compute_marginal_estimand_estimate("marginal_mean_diff")))
	expect_identical(g$inf$get_nonestimable_reason(), "zero_augmented_poisson_marginal_fit_unavailable")
})

test_that("compute_marginal_estimand_estimate(): full path caches the point estimate, a finite sandwich delta-method SE, and Inf df; estimate_only skips the SE", {
	f <- zip_fx()
	theta <- c(0.3, 0.4, 0.3, 0, -1, 0.5, 0, 0)
	V <- diag(0.01, 8)
	f$p$cached_mod <- list(mod = list(params = theta, X_fit = f$Xc, Xzi_fit = f$Xc, is_hurdle = FALSE, vcov = V))
	point <- f$p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_equal(point, ref_marginal(f$p$zero_augmented_poisson_mean_from_theta, theta, f$Xc, FALSE), tolerance = 1e-12)
	expect_equal(f$p$cached_values$beta_hat_T, point)
	expect_true(is.finite(f$p$cached_values$s_beta_hat_T) && f$p$cached_values$s_beta_hat_T > 0)
	expect_equal(f$p$cached_values$df, Inf)
	expect_false(f$inf$is_nonestimable("any"))

	g <- zip_fx()
	g$p$cached_mod <- list(mod = list(params = theta, X_fit = g$Xc, Xzi_fit = g$Xc, is_hurdle = FALSE, vcov = V))
	point_only <- g$p$compute_marginal_estimand_estimate("marginal_mean_diff", estimate_only = TRUE)
	expect_equal(point_only, point, tolerance = 1e-12)
	expect_null(g$p$cached_values$s_beta_hat_T)
})
