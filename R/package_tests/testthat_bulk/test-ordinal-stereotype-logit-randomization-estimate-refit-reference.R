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
#   1. On the same w, matches compute_estimate()'s own cached value; on a permuted w, differs and
#      stays finite.
#   2. With no prior column selection (best_Xmm_colnames still NULL), it calls shared() first.
#   3. stereotype_fit_is_usable(res) FALSE (mocked) returns NA.
#   4. A fitter failure (res NULL) returns NA.

stereotype_fixture <- function(seed = 4L, n = 200L) {
	set.seed(seed)
	x <- rnorm(n)
	des <- DesignFixediBCRD$new(n = n, response_type = "ordinal", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x = x))
	des$assign_w_to_all_subjects()
	w <- des$get_w()
	y <- as.integer(cut(0.9 * w + rlogis(n), c(-Inf, -1, 0.4, 1.5, Inf)))
	des$add_all_subject_responses(y)
	inf <- InferenceOrdinalStereotypeLogitRegr$new(des, model_formula = ~1, verbose = FALSE)
	inf$num_cores <- 1L
	list(inf = inf, priv = inf$.__enclos_env__$private, w = w)
}

test_that("on the same w it matches compute_estimate()'s own value; on a permuted w it differs and stays finite", {
	f <- stereotype_fixture()
	main_est <- f$inf$compute_estimate()
	expect_true(is.finite(main_est))
	expect_equal(f$priv$best_Xmm_colnames, character(0))

	same_w_est <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_equal(same_w_est, main_est, tolerance = 1e-8)

	set.seed(9)
	w2 <- sample(f$w)
	f$priv$w <- w2
	est2 <- f$priv$compute_treatment_estimate_during_randomization_inference()
	expect_true(is.finite(est2))
	expect_false(isTRUE(all.equal(main_est, est2, tolerance = 1e-3)))
})

test_that("without prior column selection it calls shared() first", {
	f <- stereotype_fixture(seed = 6L)
	expect_null(f$priv$best_Xmm_colnames)
	expect_true(is.finite(f$priv$compute_treatment_estimate_during_randomization_inference()))
	expect_false(is.null(f$priv$best_Xmm_colnames))
})

test_that("stereotype_fit_is_usable() FALSE returns NA", {
	f <- stereotype_fixture(seed = 7L)
	f$inf$compute_estimate()
	p <- f$priv
	unlockBinding("stereotype_fit_is_usable", p)
	p$stereotype_fit_is_usable <- function(...) FALSE

	expect_true(is.na(p$compute_treatment_estimate_during_randomization_inference()))
})

test_that("a fitter failure (res NULL) returns NA", {
	f <- stereotype_fixture(seed = 8L)
	f$inf$compute_estimate()
	local_mocked_bindings(fast_stereotype_logit_cpp = function(...) NULL, .package = "EDI")

	expect_true(is.na(f$priv$compute_treatment_estimate_during_randomization_inference()))
})
