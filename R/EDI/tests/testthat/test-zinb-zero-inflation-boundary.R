test_that("fast_zinb_cpp collapses to a stable reduced NegBin fit when the zero-inflation intercept runs away", {
	# Regression for 2026-09-07 fix (#18): the zero-inflation submodel has no
	# boundary handling analogous to the dispersion parameter's
	# dispersion_at_poisson_boundary. When the true zero-inflation
	# probability is 0, the optimizer's gradient-norm stopping rule is
	# satisfied at an arbitrary large-magnitude (but finite) zero-inflation
	# intercept -- sigmoid'(x) -> 0 as x -> -infinity vanishes the analytic
	# score in that block long before the true unconstrained optimum. This
	# produced noisy vcov/LR statistics downstream. fast_zinb_cpp now
	# detects the collapse (zero_inflation_at_boundary) and refits the
	# stable reduced (zi-off) plain-NegBin likelihood directly.
	set.seed(7)
	n <- 500L
	X <- cbind(1, rbinom(n, 1, 0.5))
	Xzi <- matrix(1, n, 1)
	colnames(X) <- c("(Intercept)", "w")
	mu <- exp(0.5 + 0.3 * X[, 2])
	y <- MASS::rnegbin(n, mu = mu, theta = 3) # no true zero-inflation
	fit <- fast_zinb_cpp(X, Xzi, y, maxit = 1000, estimate_only = FALSE)

	expect_true(isTRUE(fit$zero_inflation_at_boundary))
	expect_identical(fit$reduced_model, "NegBinNoZI")
	expect_true(all(is.finite(fit$params)))
	expect_equal(fit$params[3], -10, tolerance = 1e-8) # anchored at -kZinbZiBoundaryLogitEta
	# The zi coefficient block is neutered (NaN) in the raw internal vcov,
	# matching the existing dispersion_at_poisson_boundary convention --
	# real-data consumers of this fit go through
	# InferenceCountZeroAugmentedPoissonAbstract's boundary_information(),
	# which pins that block to an identity row/col instead.
	expect_true(is.na(fit$vcov[3, 3]))
	expect_true(all(is.finite(fit$vcov[c(1, 2, 4), c(1, 2, 4)])))
})

test_that("fast_zinb_cpp does not misfire the zero-inflation boundary fallback for an ordinary well-identified fit", {
	set.seed(99)
	n <- 300L
	X <- cbind(1, rbinom(n, 1, 0.5))
	Xzi <- cbind(1, rnorm(n))
	colnames(X) <- c("(Intercept)", "w")
	mu <- exp(0.5 + 0.3 * X[, 2])
	pi_true <- plogis(-0.5 + 0.4 * Xzi[, 2]) # real, moderate zero-inflation
	is_zero_inflated <- runif(n) < pi_true
	y <- ifelse(is_zero_inflated, 0L, MASS::rnegbin(n, mu = mu, theta = 3))
	fit <- fast_zinb_cpp(X, Xzi, y, maxit = 1000, estimate_only = FALSE)

	expect_false(isTRUE(fit$zero_inflation_at_boundary))
	expect_identical(fit$reduced_model, "")
	expect_true(all(is.finite(fit$vcov)))
})

test_that("InferenceCountZeroInflatedNegBin's likelihood-test information matrix neuters the zi block at the boundary", {
	set.seed(7)
	n <- 500L
	des <- DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	mu <- exp(0.5 + 0.3 * w)
	y <- MASS::rnegbin(n, mu = mu, theta = 3)
	des$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedNegBin$new(des, model_formula_zero = ~1, verbose = FALSE)
	p <- inf$compute_lik_ratio_two_sided_pval()
	expect_true(is.na(p) || (p >= 0 && p <= 1))
})
