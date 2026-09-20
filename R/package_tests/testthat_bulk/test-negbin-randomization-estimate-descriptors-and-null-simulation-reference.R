library(testthat)
library(EDI)

# InferenceCountNegBin: class descriptors, compute_treatment_estimate_during_randomization_
# inference() (refit on the selected covariate columns with the current w, checked against
# MASS::glm.nb, failure -> NA) and simulate_under_lik_null() (invalid theta -> NULL; valid
# theta gives a refit-able replicate).

nb_fixture <- function(seed = 4L, n = 60L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.5 + 0.4 * w + 0.3 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, X = X, y = y, w = w)
}

test_that("class descriptors: heavy tier, reusable worker, all four likelihood testing types", {
	f <- nb_fixture()
	expect_equal(f$priv$get_complexity_tier(), "heavy")
	expect_true(f$priv$supports_reusable_bootstrap_worker())
	expect_true(f$priv$supports_likelihood_tests())
	expect_true(f$priv$supports_lik_ratio_param_bootstrap())
	expect_equal(f$priv$get_supported_testing_types_impl(), c("wald", "score", "lik_ratio", "gradient"))
})

test_that("the randomization-time estimate refits the treatment coefficient for a permuted assignment", {
	f <- nb_fixture()
	f$inf$compute_estimate()
	expect_equal(f$priv$best_X_colnames, "x1")
	# Current w: agrees with an independent glm.nb fit.
	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref <- unname(coef(MASS::glm.nb(f$y ~ f$w + f$X$x1))[2])
	expect_equal(est, ref, tolerance = 0.01)
	# A permuted assignment injected into the private state is what gets refit.
	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	ref2 <- unname(coef(MASS::glm.nb(f$y ~ w2 + f$X$x1))[2])
	expect_equal(est2, ref2, tolerance = 0.01)
	expect_false(isTRUE(all.equal(est, est2, tolerance = 1e-3)))
})

test_that("without prior selection it calls shared() first, and an unfittable refit yields NA", {
	f <- nb_fixture()
	expect_null(f$priv$best_X_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_X_colnames))
	# A backend error, or a non-finite treatment coefficient, returns NA rather than erroring.
	local_mocked_bindings(fast_neg_bin_cpp = function(...) stop("backend failure"), .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
	local_mocked_bindings(fast_neg_bin_cpp = function(X, ...) list(b = c(0, NA_real_, rep(0, ncol(X) - 2L)), theta_hat = 1), .package = "EDI")
	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})

test_that("null simulation returns NULL for an invalid theta and a refit-able replicate otherwise", {
	f <- nb_fixture()
	f$inf$compute_estimate()
	spec <- f$priv$get_likelihood_test_spec()
	fit <- spec$full_fit
	bad <- fit; bad$theta_hat <- -1
	expect_null(f$priv$simulate_under_lik_null(spec, 0, bad))
	bad$theta_hat <- NA_real_
	expect_null(f$priv$simulate_under_lik_null(spec, 0, bad))
	set.seed(21)
	sim <- f$priv$simulate_under_lik_null(spec, 0, fit)
	expect_false(is.null(sim))
	expect_true(all(c("full_fit", "fit_null") %in% names(sim)))
	expect_length(sim$full_fit$b, length(fit$b))
	expect_true(is.finite(sim$full_fit$neg_loglik))
	expect_true(is.finite(sim$full_fit$theta_hat) && sim$full_fit$theta_hat > 0)
	# Reproducible under a fixed RNG seed.
	set.seed(21)
	sim2 <- f$priv$simulate_under_lik_null(spec, 0, fit)
	expect_equal(sim2$full_fit$b, sim$full_fit$b)
})
