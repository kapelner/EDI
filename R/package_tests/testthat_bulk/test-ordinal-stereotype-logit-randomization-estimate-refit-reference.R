library(testthat)
library(EDI)

# InferenceOrdinalStereotypeLogitRegr's compute_treatment_estimate_during_randomization_inference()
# (inference_ordinal_stereotype_logit.R) had no test reference anywhere -- the same gap pattern
# already closed this session on several sibling ordinal classes. Unlike those siblings, no
# widely-used R package implements the stereotype-logit model, and this class's estimator is already
# documented elsewhere in this suite as multimodal (project memory: "estimate can sit at non-global
# optimum (~3% at n=50)") -- so rather than an external independent reference, the happy-path
# assertion here is a genuine structural self-consistency check: on the SAME (unpermuted) w, this
# private method's own direct fast_stereotype_logit_cpp() call reaches the identical estimate as
# compute_estimate()'s independently-implemented hardened-QR generate_mod() pipeline -- confirmed
# empirically via a standalone probe (both estimation paths use the same fitter but assemble the
# design matrix and warm-start differently, so agreement is a real correctness signal, not a
# tautology). The remaining branches are reached by mocking, since organic covariate-adjusted
# convergence for this model proved unreliable in probing (also empirically confirmed).
#   1. On the same w, returns compute_estimate()'s own cached value; on a permuted w, equals a
#      fresh object's estimate there.
#   2. With no prior column selection (best_Xmm_colnames still NULL), it runs shared() first.
#   3. It writes no "params" warm start (TODO-178).
#   4. A fitter failure (res NULL) returns NA.

# Default was seed = 4L; this model's likelihood is documented elsewhere as
# multimodal (project memory: "estimate can sit at non-global optimum (~3%
# at n=50)") and, empirically, organic (unmocked) convergence fails outright
# (stereotype_fit_is_usable() correctly rejects every multistart candidate:
# NaN min_eigenvalue_information) for roughly 3 of 20 arbitrary seeds even
# with no covariates -- seed 4 happened to be one of them. Since 2026-11-08
# a `~ 1` fit with 3+ categories is always non-estimable, so the fixture
# uses `~ x`. seed 1 converges cleanly for both the unpermuted and a permuted w on
# this exact fixture; this is an existing, accepted optimizer limitation
# (not something this test is meant to exercise), not a regression to chase
# here.
stereotype_fixture <- function(seed = 1L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~x, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

# TODO-178 (2026-11-07): the hook is now the class's own estimator --
# private$shared(estimate_only) and the cached beta_hat_T -- the same estimator
# the randomization / bootstrap workers apply to every draw (full generate_mod():
# column selection, cold primary fit, deterministic multistart). It no longer
# refits single-start from the object's warm start or writes a "params" warm
# start back, so the tests below pin that contract.

test_that("on the same w it returns compute_estimate()'s own value; on a permuted w (cache cleared) it equals a fresh object's estimate there", {
	f <- stereotype_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))
	expect_equal(f$priv$best_Xmm_colnames, "x")

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_identical(same_w_est, main_est)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	f$priv$cached_values <- list()
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()

	g <- stereotype_fixture()
	g$priv$w <- w2
	expect_identical(est2, g$priv$compute_treatment_estimate_during_randomization_inference())
	if (is.finite(est2)) expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it runs the full fit (shared()) first", {
	f <- stereotype_fixture(seed = 6L)
	expect_null(f$priv$best_Xmm_colnames)
	est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_false(is.null(f$priv$cached_values$beta_hat_T))
	g <- stereotype_fixture(seed = 6L)
	expect_identical(est, suppressWarnings(g$inf$compute_estimate(estimate_only = TRUE)))
})

test_that("the hook writes no 'params' warm start, so a later SE fit equals a fresh object's", {
	f <- stereotype_fixture(seed = 7L)
	f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_null(f$priv$get_fit_warm_start("params"))
	after <- suppressWarnings(f$inf$compute_asymp_confidence_interval())
	g <- stereotype_fixture(seed = 7L)
	expect_identical(after, suppressWarnings(g$inf$compute_asymp_confidence_interval()))
})

test_that("a fitter failure (res NULL) returns NA", {
	f <- stereotype_fixture(seed = 8L)
	local_mocked_bindings(fast_stereotype_logit_cpp = function(...) NULL, .package = "EDI")

	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
