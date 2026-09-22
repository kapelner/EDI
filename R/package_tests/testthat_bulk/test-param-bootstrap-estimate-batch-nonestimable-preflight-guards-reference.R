library(testthat)
library(EDI)

# InferenceExtParamBootstrapEstimate's run_param_bootstrap_estimate_batch() (shared batch runner behind
# compute_param_bootstrap_estimate()/compute_param_bootstrap_confidence_interval()): three early-return
# nonestimable "preflight" guards before any bootstrap replicate is run -- (1) the likelihood-test spec itself is
# unavailable or malformed (NULL, or missing full_fit/j), (2) the raw (unrestricted) anchor estimate extracted
# from that spec is non-finite, (3) that raw estimate is "extreme" by param_bootstrap_estimate_extreme()'s own
# threshold. Existing coverage of this function is extensive for the DOWNSTREAM replicate-running logic (extreme-
# replicate detection, deterministic seeding, n_success/n_failure/n_extreme diagnostics, the bias-correction
# reconciliation identity) but never exercised any of these three preflight branches.

fx <- function(seed = 1L, n = 60L) {
	set.seed(seed)
	X <- data.frame(x1 = rnorm(n))
	des <- DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X); des$assign_w_to_all_subjects()
	w <- des$get_w(); des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * w + 0.2 * X$x1)))
	InferenceIncidLogRegr$new(des, model_formula = ~x1, verbose = FALSE)
}

test_that("a NULL likelihood-test spec is nonestimable with the documented reason and returns NULL", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function() NULL
	out <- p$run_param_bootstrap_estimate_batch(B = 5, max_attempts_per_replicate = 1, show_progress = FALSE)
	expect_null(out)
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_spec_unavailable")
	expect_true(inf$is_nonestimable("any"))
	expect_true(inf$is_nonestimable("se"))                                    # cache_nonestimable_se(): stage = "se", unlike the other two branches below
})

test_that("a spec with a non-finite raw (anchor) estimate is nonestimable with its own reason and returns NULL", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	real_spec <- p$get_likelihood_test_spec()
	bad_spec <- real_spec
	bad_spec$full_fit$b[real_spec$j] <- NA_real_
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function() bad_spec
	out <- p$run_param_bootstrap_estimate_batch(B = 5, max_attempts_per_replicate = 1, show_progress = FALSE)
	expect_null(out)
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_raw_estimate_nonfinite")
	expect_true(inf$is_nonestimable("estimate"))
})

test_that("a spec with an extreme raw (anchor) estimate is nonestimable with its own reason and returns NULL", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	real_spec <- p$get_likelihood_test_spec()
	extreme_spec <- real_spec
	extreme_spec$full_fit$b[real_spec$j] <- 1e6
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function() extreme_spec
	out <- p$run_param_bootstrap_estimate_batch(B = 5, max_attempts_per_replicate = 1, show_progress = FALSE)
	expect_null(out)
	expect_identical(inf$get_nonestimable_reason(), "param_bootstrap_estimate_raw_estimate_extreme")
})

test_that("an already-recorded nonestimable('estimate') reason is not overwritten by a later preflight failure", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	p$cache_nonestimable_estimate("preexisting_reason")
	unlockBinding("get_likelihood_test_spec", p)
	p$get_likelihood_test_spec <- function() NULL
	p$run_param_bootstrap_estimate_batch(B = 5, max_attempts_per_replicate = 1, show_progress = FALSE)
	expect_identical(inf$get_nonestimable_reason(), "preexisting_reason")
})

test_that("the ordinary (unstubbed) path is unaffected: a real usable spec runs the batch and returns a finite raw_estimate", {
	inf <- fx()
	p <- inf$.__enclos_env__$private
	out <- p$run_param_bootstrap_estimate_batch(B = 10, max_attempts_per_replicate = 1, show_progress = FALSE)
	expect_false(is.null(out))
	expect_true(is.finite(out$raw_estimate))
	expect_false(inf$is_nonestimable("any"))
})
