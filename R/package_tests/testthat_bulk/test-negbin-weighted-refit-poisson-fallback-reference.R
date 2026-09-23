library(testthat)
library(EDI)

# InferenceCountNegBin$compute_estimate_with_bootstrap_weights() (inference_count_negbin.R) falls
# back to an unweighted-in-structure (but weights-applied) stats::glm(poisson) fit when
# fast_neg_bin_weighted_cpp() fails to produce a usable fit -- errors, doesn't converge, or gives a
# non-finite/missing treatment coefficient after hardened QR column-dropping is exhausted -- and
# only returns NA if that Poisson fallback ALSO fails. Every existing weighted-refit reference test
# exercises only fast_neg_bin_weighted_cpp()'s success path; this fallback (and its own failure
# branch) had no test reference anywhere. fast_neg_bin_cpp (the UNweighted sibling backend) is
# already mocked for a different purpose in
# test-negbin-randomization-estimate-descriptors-and-null-simulation-reference.R, but
# fast_neg_bin_weighted_cpp -- the one this method actually calls -- never was.

nb_weighted_fixture <- function(seed = 4L, n = 40L) {
	set.seed(seed)
	des <- DesignFixediBCRD$new(n = n, response_type = "count", verbose = FALSE)
	X <- data.frame(x1 = rnorm(n))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- rnbinom(n, size = 3, mu = exp(0.5 + 0.4 * w + 0.3 * X$x1))
	des$add_all_subject_responses(y)
	inf <- InferenceCountNegBin$new(des, verbose = FALSE)
	priv <- inf$.__enclos_env__$private
	priv$current_bayesian_bootstrap_context <- priv$build_bayesian_bootstrap_context()
	list(priv = priv, X = X, y = y, w = w, n = n)
}

test_that("a fast_neg_bin_weighted_cpp failure falls back to a weighted Poisson glm() matching an independent reference", {
	f <- nb_weighted_fixture()
	set.seed(5); wt <- rexp(f$n)

	local_mocked_bindings(fast_neg_bin_weighted_cpp = function(...) stop("backend failure"), .package = "EDI")
	est <- f$priv$weighted_refit_impl(wt)

	ref <- unname(coef(glm(f$y ~ f$w + f$X$x1, family = poisson(link = "log"), weights = wt))[2])
	expect_equal(est, ref, tolerance = 1e-8)
	expect_equal(f$priv$cached_values$beta_hat_T, est)
	# the fallback never computes a weighted SE/df
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(is.na(f$priv$cached_values$df))
})

test_that("a fast_neg_bin_weighted_cpp fit with a non-finite treatment coefficient also triggers the Poisson fallback", {
	f <- nb_weighted_fixture(seed = 6L)
	set.seed(7); wt <- rexp(f$n)

	local_mocked_bindings(
		fast_neg_bin_weighted_cpp = function(X, ...) list(b = c(0, NA_real_, rep(0, ncol(X) - 2L)), theta_hat = 1, fisher_information = NULL),
		.package = "EDI"
	)
	est <- f$priv$weighted_refit_impl(wt)
	ref <- unname(coef(glm(f$y ~ f$w + f$X$x1, family = poisson(link = "log"), weights = wt))[2])
	expect_equal(est, ref, tolerance = 1e-8)
})

test_that("if the Poisson fallback ALSO fails, the estimate, SE, and df are all NA", {
	f <- nb_weighted_fixture(seed = 8L)
	set.seed(9); wt <- rexp(f$n)

	local_mocked_bindings(fast_neg_bin_weighted_cpp = function(...) stop("backend failure"), .package = "EDI")
	local_mocked_bindings(glm = function(...) stop("poisson fallback also fails"), .package = "stats")

	est <- f$priv$weighted_refit_impl(wt)
	expect_true(is.na(est))
	expect_true(is.na(f$priv$cached_values$beta_hat_T))
	expect_true(is.na(f$priv$cached_values$s_beta_hat_T))
	expect_true(is.na(f$priv$cached_values$df))
})
