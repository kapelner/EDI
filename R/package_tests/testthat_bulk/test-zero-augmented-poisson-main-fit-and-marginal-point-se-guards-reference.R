library(testthat)
library(EDI)

# InferenceCountZeroAugmentedPoissonAbstract (inference_count_zero_augmented_poisson_abstract.R) has
# four nonestimable guards with no test reference anywhere, distinct from the sibling guards already
# closed this session (the weighted-refit design/aux/fit-unavailable trio in
# test-zero-augmented-poisson-weighted-refit-design-and-fit-unavailable-guards-reference.R, and the
# marginal-estimand fit/vcov-unavailable pair in
# test-zero-augmented-poisson-marginal-functional-and-compute-marginal-estimand-estimate-reference.R):
#   1. "zero_augmented_poisson_fit_unavailable": generate_mod()'s MAIN (non-weighted), use_rcpp =
#      FALSE glmmTMB path -- fit_zero_augmented_model() itself returns NULL. (The default use_rcpp =
#      TRUE path shares the exact same reason string at a distinct call site inside the Rcpp branch;
#      only the glmmTMB-path site had no reference.)
#   2. "zero_augmented_poisson_treatment_missing": the fit succeeds but glmmTMB::fixef(mod)$cond has
#      no finite "w" coefficient (same use_rcpp = FALSE path as (1)).
#   3. "zero_augmented_poisson_marginal_point_unavailable": compute_marginal_estimand_estimate()'s
#      functional(raw$params) call is non-finite/errors on an otherwise-usable raw fit.
#   4. "zero_augmented_poisson_marginal_se_unavailable": the sandwich vcov is available, but
#      marginal_estimand_delta_se() itself returns a non-finite/negative SE.
# (1)/(2) reached on InferenceCountZeroInflatedPoisson via mocking fit_zero_augmented_model()
# (private, EDI namespace) and glmmTMB::fixef() directly -- NOT glmmTMB::glmmTMB() itself, which a
# past iteration this session found breaks the real backend fit when mocked. (3)/(4) reuse the
# cached_mod-injection fixture pattern from the already-closed marginal-estimand reference test.

zip_fx <- function(seed = 4L, n = 100L, use_rcpp = TRUE) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n), x2 = runif(n))
	d <- DesignFixedBernoulli$new(response_type = "count", n = n, seed = 1L, verbose = FALSE)
	d$add_all_subjects_to_experiment(X); d$assign_w_to_all_subjects(); w <- d$get_w()
	zi <- rbinom(n, 1, plogis(-1 + 0.5 * X$x1)); y <- ifelse(zi == 1, 0L, rpois(n, exp(0.3 + 0.4 * w + 0.3 * X$x1)))
	d$add_all_subject_responses(y)
	inf <- InferenceCountZeroInflatedPoisson$new(d, use_rcpp = use_rcpp, verbose = FALSE)
	Xc <- cbind(1, w, X$x1, X$x2); colnames(Xc) <- c("(Intercept)", "treatment", "x1", "x2")
	list(inf = inf, p = inf$.__enclos_env__$private, Xc = Xc)
}

test_that("generate_mod() caches 'zero_augmented_poisson_fit_unavailable' when the glmmTMB-path fitter fails", {
	f <- zip_fx(use_rcpp = FALSE)
	unlockBinding("fit_zero_augmented_model", f$p)
	f$p$fit_zero_augmented_model <- function(...) NULL

	res <- f$inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(f$inf$get_nonestimable_reason(), "zero_augmented_poisson_fit_unavailable")
})

test_that("generate_mod() caches 'zero_augmented_poisson_treatment_missing' when fixef(mod)$cond has no usable 'w'", {
	f <- zip_fx(seed = 5L, use_rcpp = FALSE)
	unlockBinding("fit_zero_augmented_model", f$p)
	f$p$fit_zero_augmented_model <- function(...) structure(list(), class = "fake_zap_fit")
	local_mocked_bindings(
		fixef = function(object, ...) list(cond = c(`(Intercept)` = 0.5)),
		.package = "glmmTMB"
	)

	res <- f$inf$compute_estimate()
	expect_true(is.na(res))
	expect_identical(f$inf$get_nonestimable_reason(), "zero_augmented_poisson_treatment_missing")
})

test_that("compute_marginal_estimand_estimate() caches 'zero_augmented_poisson_marginal_point_unavailable' when the functional is non-finite", {
	f <- zip_fx(seed = 6L)
	theta <- c(0.3, 0.4, 0.3, 0, -1, 0.5, 0, 0)
	f$p$cached_mod <- list(mod = list(params = theta, X_fit = f$Xc, Xzi_fit = f$Xc, is_hurdle = FALSE, vcov = diag(0.01, 8)))
	unlockBinding("zero_augmented_poisson_marginal_functional", f$p)
	f$p$zero_augmented_poisson_marginal_functional <- function(...) NaN

	res <- f$p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_true(is.na(res))
	expect_identical(f$inf$get_nonestimable_reason(), "zero_augmented_poisson_marginal_point_unavailable")
})

test_that("compute_marginal_estimand_estimate() caches 'zero_augmented_poisson_marginal_se_unavailable' when the delta-method SE is unusable", {
	f <- zip_fx(seed = 7L)
	theta <- c(0.3, 0.4, 0.3, 0, -1, 0.5, 0, 0)
	f$p$cached_mod <- list(mod = list(params = theta, X_fit = f$Xc, Xzi_fit = f$Xc, is_hurdle = FALSE, vcov = diag(0.01, 8)))
	local_mocked_bindings(marginal_estimand_delta_se = function(...) list(se = NA_real_), .package = "EDI")

	point <- f$p$compute_marginal_estimand_estimate("marginal_mean_diff")
	expect_true(is.finite(point))  # the point estimate itself is still usable
	expect_identical(f$inf$get_nonestimable_reason(), "zero_augmented_poisson_marginal_se_unavailable")
})
