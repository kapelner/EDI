library(testthat)
library(EDI)

test_that("Beta inference maps a singular covariance to typed SE nonestimability", {
	set.seed(26)
	n <- 100L
	des <- DesignFixedBernoulli$new(
		n = n, response_type = "proportion", seed = 1L, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = rnorm(n)))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(
		rbeta(n, plogis(0.2 + 0.3 * w) * 8, (1 - plogis(0.2 + 0.3 * w)) * 8)
	)

	inf <- InferencePropBetaRegr$new(des, verbose = FALSE)
	private <- inf$.__enclos_env__$private
	private$harden <- FALSE
	private$X <- cbind(x = as.numeric(private$X[, 1L]),
	                   x_duplicate = as.numeric(private$X[, 1L]))

	ci <- inf$compute_asymp_confidence_interval()
	expect_true(all(is.na(ci)))
	expect_false(private$cached_mod$information_invertible)
	expect_true(is.na(private$cached_values$s_beta_hat_T))
	expect_true(isTRUE(private$cached_values$nonestimable))
	expect_identical(private$cached_values$nonestimable_reason,
	                  "model_standard_error_unavailable")
	expect_identical(private$cached_values$nonestimable_stage, "se")
})

test_that("zero-augmented Poisson inference preserves typed nonestimability for singular fits", {
	set.seed(31)
	n <- 120L
	x <- rnorm(n)
	des <- DesignFixedBernoulli$new(
		n = n, response_type = "count", seed = 1L, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(as.integer(rpois(n, exp(0.3 + 0.2 * w + 0.15 * x))))

	for (class_name in c("InferenceCountZeroInflatedPoisson", "InferenceCountHurdlePoisson")) {
		class_generator <- get(class_name, envir = asNamespace("EDI"))
		model_args <- if (identical(class_name, "InferenceCountHurdlePoisson")) {
			list(model_formula_hurdle = ~1)
		} else {
			list(model_formula_zero = ~1)
		}
		inf <- do.call(class_generator$new, c(
			list(des_obj = des, model_formula = ~x, verbose = FALSE), model_args
		))
		private <- inf$.__enclos_env__$private
		private$harden <- FALSE
		# Preserve the deliberately duplicated columns through this class's normal
		# component-matrix cache; hardening would otherwise drop the singularity.
		private$za_X_cov_all <- cbind(x = x, x_duplicate = x)
		private$za_Xzi_cov_all <- matrix(numeric(), nrow = n, ncol = 0L)

		estimate <- inf$compute_estimate()
		expect_true(is.finite(estimate), info = class_name)
		expect_false(private$cached_mod$information_invertible, info = class_name)
		expect_true(is.na(private$cached_values$s_beta_hat_T), info = class_name)
		expect_true(isTRUE(private$cached_values$nonestimable), info = class_name)
		expect_identical(private$cached_values$nonestimable_reason,
		                  "model_standard_error_unavailable", info = class_name)
		expect_identical(private$cached_values$nonestimable_stage, "se", info = class_name)

		ci <- expect_warning(
			inf$compute_asymp_confidence_interval(),
			"falling back to bootstrap"
		)
		expect_true(all(is.na(ci)), info = class_name)
	}
})

test_that("ZINB inference maps a guarded singular covariance to typed SE nonestimability", {
	set.seed(2)
	n <- 120L
	x <- rnorm(n)
	w <- rep(c(0, 1), length.out = n)
	structural_zero <- rbinom(n, 1L, plogis(-1 + 0.2 * w))
	y <- ifelse(
		structural_zero == 1L,
		0L,
		rnbinom(n, mu = exp(0.2 + 0.3 * w + 0.1 * x), size = 2)
	)
	des <- DesignFixedBernoulli$new(
		n = n, response_type = "count", seed = 1L, verbose = FALSE
	)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	des$add_all_subject_responses(as.integer(y))

	inf <- InferenceCountZeroInflatedNegBin$new(
		des, model_formula = ~x, model_formula_zero = ~1, verbose = FALSE
	)
	private <- inf$.__enclos_env__$private
	private$harden <- FALSE
	# Retain an exact duplicate in the conditional component while keeping a
	# valid low-dimensional zero-inflation model. This fixture's native fit
	# converges, so the covariance guard—not fit failure—is exercised.
	private$za_X_cov_all <- cbind(x = x, x_duplicate = x)
	private$za_Xzi_cov_all <- matrix(numeric(), nrow = n, ncol = 0L)

	estimate <- inf$compute_estimate()
	expect_true(is.finite(estimate))
	expect_false(private$cached_mod$information_invertible)
	expect_true(is.na(private$cached_values$s_beta_hat_T))
	expect_true(isTRUE(private$cached_values$nonestimable))
	expect_identical(private$cached_values$nonestimable_reason,
	                  "model_standard_error_unavailable")
	expect_identical(private$cached_values$nonestimable_stage, "se")

	ci <- expect_warning(
		inf$compute_asymp_confidence_interval(),
		"falling back to bootstrap"
	)
	expect_true(all(is.na(ci)))
})
