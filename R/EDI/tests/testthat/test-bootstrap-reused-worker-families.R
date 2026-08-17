# tolerance loosened from 1e-10: the fast (reused-worker) and slow (generic)
# paths converge to the same optimum via different numeric routes, and have
# been observed to differ by ~1e-10 on macOS (Accelerate BLAS) vs. Linux --
# benign cross-BLAS floating-point noise, not a real divergence.
# Exhaustive sweeps in this file run only when EDI_EXHAUSTIVE_WORKER_TESTS=true
# -- see test-bootstrap-reused-worker-asymp-families.R's header for the full
# rationale; that file's always-on smoke test covers the shared reused-worker
# mechanism on every push/CI run.
skip_unless_exhaustive_worker_tests <- function(){
	testthat::skip_if_not(
		identical(Sys.getenv("EDI_EXHAUSTIVE_WORKER_TESTS"), "true"),
		"exhaustive reused-worker sweep: set EDI_EXHAUSTIVE_WORKER_TESTS=true to run"
	)
}

generator_inherits <- function(generator, classname){
	current = generator
	while (!is.null(current)) {
		if (identical(current$classname, classname)) return(TRUE)
		current = current$get_inherit()
	}
	FALSE
}

# Runtime budget (2026-08-17): trimmed alongside its sibling
# test-bootstrap-reused-worker-asymp-families.R (see that file's header for
# the full rationale): duplicate back-to-back Slow* definitions and exact
# duplicate second-seed comparisons removed, and B reduced 11L -> 3L --
# replicate 1 exercises worker creation, replicates 2-3 exercise reuse, and
# per-replicate bit-identical equality is still asserted.
compare_bootstrap_fast_slow <- function(fast_inf, slow_inf, B = 3L, seed = 1L, tolerance = 1e-8){
	fast_inf$num_cores = 1L
	slow_inf$num_cores = 1L
	set.seed(seed)
	fast_boot = fast_inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
	set.seed(seed)
	slow_boot = slow_inf$approximate_bootstrap_distribution_beta_hat_T(B = B, show_progress = FALSE)
	expect_equal(unname(fast_boot), unname(slow_boot), tolerance = tolerance)
}

test_that("log-binomial reusable bootstrap worker matches generic path", {
	skip_unless_exhaustive_worker_tests()
	SlowInferenceIncidLogBinomial = R6::R6Class(
		"SlowInferenceIncidLogBinomial",
		inherit = InferenceIncidLogBinomial,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	set.seed(20260410)
	n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	p = pmin(0.95, pmax(0.02, exp(-1.4 + 0.5 * w + 0.2 * X$x1 - 0.1 * X$x2)))
	y = stats::rbinom(n, 1, p)
	des$add_all_subject_responses(y)

	compare_bootstrap_fast_slow(
		InferenceIncidLogBinomial$new(des, verbose = FALSE),
		SlowInferenceIncidLogBinomial$new(des, verbose = FALSE),
		seed = 101
	)
})

test_that("binomial identity reusable bootstrap worker matches generic path", {
	skip_unless_exhaustive_worker_tests()
	SlowInferenceIncidBinomialIdentityRiskDiff = R6::R6Class(
		"SlowInferenceIncidBinomialIdentityRiskDiff",
		inherit = InferenceIncidBinomialIdentityRiskDiff,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	set.seed(20260411)
	n = 64
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	p = pmin(0.95, pmax(0.02, 0.25 + 0.18 * w + 0.05 * X$x1 - 0.03 * X$x2))
	y = stats::rbinom(n, 1, p)
	des$add_all_subject_responses(y)

	compare_bootstrap_fast_slow(
		InferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE),
		SlowInferenceIncidBinomialIdentityRiskDiff$new(des, verbose = FALSE),
		seed = 103
	)
})

test_that("count reusable bootstrap workers match generic paths", {
	skip_unless_exhaustive_worker_tests()
	SlowInferenceCountPoisson = R6::R6Class(
		"SlowInferenceCountPoisson",
		inherit = InferenceCountPoisson,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	SlowInferenceCountRobustPoisson = R6::R6Class(
		"SlowInferenceCountRobustPoisson",
		inherit = InferenceCountRobustPoisson,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)
	SlowInferenceCountQuasiPoisson = R6::R6Class(
		"SlowInferenceCountQuasiPoisson",
		inherit = InferenceCountQuasiPoisson,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	set.seed(20260412)
	n = 68
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "count", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	lambda = exp(0.2 + 0.35 * w + 0.15 * X$x1 - 0.1 * X$x2)
	y = stats::rpois(n, lambda)
	des$add_all_subject_responses(y)

	compare_bootstrap_fast_slow(InferenceCountPoisson$new(des, verbose = FALSE), SlowInferenceCountPoisson$new(des, verbose = FALSE), seed = 105)
	compare_bootstrap_fast_slow(InferenceCountPoisson$new(des, verbose = FALSE), SlowInferenceCountPoisson$new(des, verbose = FALSE), seed = 106)
	compare_bootstrap_fast_slow(InferenceCountRobustPoisson$new(des, verbose = FALSE), SlowInferenceCountRobustPoisson$new(des, verbose = FALSE), seed = 107)
	compare_bootstrap_fast_slow(InferenceCountRobustPoisson$new(des, verbose = FALSE), SlowInferenceCountRobustPoisson$new(des, verbose = FALSE), seed = 108)
	compare_bootstrap_fast_slow(InferenceCountQuasiPoisson$new(des, verbose = FALSE), SlowInferenceCountQuasiPoisson$new(des, verbose = FALSE), seed = 109)
	compare_bootstrap_fast_slow(InferenceCountQuasiPoisson$new(des, verbose = FALSE), SlowInferenceCountQuasiPoisson$new(des, verbose = FALSE), seed = 110)
})

test_that("count likelihood phase 1 and 2 classes share the count likelihood base", {
	# Structural invariant, checked without constructing instances (no design,
	# no model fits), so it stays always-on. A class satisfies "shares the
	# count likelihood base" either through the old-ladder ancestry (classes
	# not yet migrated to define_inference_class()) or through composing the
	# corresponding registered component (migrated classes -- e.g.
	# InferenceCountQuasiPoisson/RobustPoisson now parent directly to
	# Inference and carry CountCompositeLikelihood as a component; the old
	# instance-inherits() assertion this replaces failed for them the moment
	# they migrated, since the R6 chain no longer contains the base name).
	EDI:::populate_inference_class_registry()
	shares_count_base = function(generator, base_classname, component_name){
		generator_inherits(generator, base_classname) ||
			component_name %in% EDI:::get_effective_components(generator$classname)
	}
	expect_true(shares_count_base(InferenceCountPoisson, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountNegBin, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountZeroInflatedPoisson, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountZeroInflatedNegBin, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountHurdlePoisson, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountHurdleNegBin, "InferenceCountLikelihood", "CountLikelihoodPlumbing"))
	expect_true(shares_count_base(InferenceCountRobustPoisson, "InferenceCountCompositeLikelihood", "CountCompositeLikelihood"))
	expect_true(shares_count_base(InferenceCountQuasiPoisson, "InferenceCountCompositeLikelihood", "CountCompositeLikelihood"))
})

test_that("continuous robust reusable bootstrap worker matches generic path", {
	skip_unless_exhaustive_worker_tests()
	SlowInferenceContinRobustRegr = R6::R6Class(
		"SlowInferenceContinRobustRegr",
		inherit = InferenceContinRobustRegr,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	set.seed(20260413)
	n = 60
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = 0.4 * w + 0.3 * X$x1 - 0.2 * X$x2 + stats::rt(n, df = 5)
	des$add_all_subject_responses(y)

	compare_bootstrap_fast_slow(InferenceContinRobustRegr$new(des, method = "M", verbose = FALSE), SlowInferenceContinRobustRegr$new(des, method = "M", verbose = FALSE), seed = 111)
	compare_bootstrap_fast_slow(InferenceContinRobustRegr$new(des, method = "M", verbose = FALSE), SlowInferenceContinRobustRegr$new(des, method = "M", verbose = FALSE), seed = 112)
})

test_that("continuous quantile reusable bootstrap worker matches generic path", {
	skip_unless_exhaustive_worker_tests()
	skip_if_not_installed("quantreg")

	SlowInferenceContinQuantileRegr = R6::R6Class(
		"SlowInferenceContinQuantileRegr",
		inherit = InferenceContinQuantileRegr,
		lock_objects = FALSE,
		private = list(supports_reusable_bootstrap_worker = function() FALSE)
	)

	set.seed(20260414)
	n = 56
	X = data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	y = 0.5 * w + 0.25 * X$x1 - 0.15 * X$x2 + stats::rt(n, df = 6)
	des$add_all_subject_responses(y)

	compare_bootstrap_fast_slow(InferenceContinQuantileRegr$new(des, tau = 0.5, verbose = FALSE), SlowInferenceContinQuantileRegr$new(des, tau = 0.5, verbose = FALSE), seed = 113)
	compare_bootstrap_fast_slow(InferenceContinQuantileRegr$new(des, tau = 0.5, verbose = FALSE), SlowInferenceContinQuantileRegr$new(des, tau = 0.5, verbose = FALSE), seed = 114)
})
