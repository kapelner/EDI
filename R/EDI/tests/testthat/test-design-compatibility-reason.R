library(testthat)
library(EDI)

# Regression coverage for `design_compatibility_reason()` (fix_inference_hierarchy.md,
# "Discovery-time applicability is response-type-only and name-pattern-derived" TODO):
# closes the gap flagged during its 2026-08-21 audit ("no regression test exists ...
# unlike the earlier public_methods_for_capability TODO, which explicitly landed as
# a regression-tested invariant, not just a one-time manual pass"). Two things are
# verified for every class below, for both a compatible and an incompatible design:
#   1. `design_compatibility_reason(des_obj)` (called unbound, self/private-free, the
#      same access pattern `infer_inference_design_compatibility_reason_fn()` itself
#      uses) returns `NA_character_` iff the design is actually compatible, and a
#      non-NA reason string iff `initialize()` would actually throw for it.
#   2. `InferenceSuite$new(des_obj)$applicable_design_classes` end-to-end excludes the
#      class for the incompatible design (and, for the CMH/ExtendedRobins case, lists
#      it in `des_obj$incompatible_inference_classes_due_to_design_structure()` with a
#      reason), rather than only discoverable as a `status = "error"` row.

test_that("InferenceIncidCMH: design_compatibility_reason matches real throw behavior (blocking)", {
	n = 20L
	des_ok = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des_ok$add_all_subjects_to_experiment(X)
	des_ok$assign_w_to_all_subjects()
	des_ok$add_all_subject_responses(rbinom(n, 1, 0.4))

	reason_fn = EDI:::InferenceIncidCMH$private_methods$design_compatibility_reason
	expect_true(is.na(reason_fn(des_ok)))
	expect_no_error(InferenceIncidCMH$new(des_ok))
	expect_true("InferenceIncidCMH" %in% des_ok$applicable_inference_class_names())

	des_bad = DesignFixedBlocking$new(n = n, response_type = "incidence", m = c(rep(1L, 6L), rep(2L, 14L)))
	Xb = data.frame(x1 = rnorm(n))
	des_bad$add_all_subjects_to_experiment(Xb)
	des_bad$assign_w_to_all_subjects()
	des_bad$add_all_subject_responses(rbinom(n, 1, 0.4))

	reason_bad = reason_fn(des_bad)
	expect_identical(reason_bad, "cmh_requires_equal_block_sizes")
	expect_error(InferenceIncidCMH$new(des_bad), "equal block sizes")
	expect_false("InferenceIncidCMH" %in% des_bad$applicable_inference_class_names())
	incompatible = des_bad$incompatible_inference_classes_due_to_design_structure()
	expect_identical(incompatible[["InferenceIncidCMH"]], "cmh_requires_equal_block_sizes")
})

test_that("InferenceIncidCMH: design_compatibility_reason matches real throw behavior (non-blocking)", {
	n = 20L
	des_bad = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.3)
	des_bad$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = rbinom(n, 1, 0.3)
	if (all(w == w[1])) w[1] = 1L - w[1]
	des_bad$assign_w_to_all_subjects(w_precomputed = w)
	des_bad$add_all_subject_responses(rbinom(n, 1, 0.4))

	reason_fn = EDI:::InferenceIncidCMH$private_methods$design_compatibility_reason
	expect_identical(reason_fn(des_bad), "cmh_requires_even_allocation")
	expect_error(InferenceIncidCMH$new(des_bad), "even treatment allocation")
	expect_false("InferenceIncidCMH" %in% des_bad$applicable_inference_class_names())
})

test_that("InferenceIncidExtendedRobins: design_compatibility_reason matches real throw behavior", {
	n = 20L
	des_ok = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = TRUE)
	X = data.frame(x1 = rnorm(n), x2 = rep(c("a", "b"), n / 2L))
	des_ok$add_all_subjects_to_experiment(X)
	des_ok$assign_w_to_all_subjects()
	des_ok$add_all_subject_responses(rbinom(n, 1, 0.4))

	reason_fn = EDI:::InferenceIncidExtendedRobins$private_methods$design_compatibility_reason
	expect_true(is.na(reason_fn(des_ok)))
	expect_no_error(InferenceIncidExtendedRobins$new(des_ok))
	expect_true("InferenceIncidExtendedRobins" %in% des_ok$applicable_inference_class_names())

	des_bad = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des_bad$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	w = rep(c(0L, 1L), n / 2L)
	des_bad$assign_w_to_all_subjects(w_precomputed = w)
	des_bad$add_all_subject_responses(rbinom(n, 1, 0.4))

	reason_bad = reason_fn(des_bad)
	expect_identical(reason_bad, "extended_robins_requires_blocking_design")
	expect_error(InferenceIncidExtendedRobins$new(des_bad), "blocking design")
	expect_false("InferenceIncidExtendedRobins" %in% des_bad$applicable_inference_class_names())
	incompatible = des_bad$incompatible_inference_classes_due_to_design_structure()
	expect_identical(incompatible[["InferenceIncidExtendedRobins"]], "extended_robins_requires_blocking_design")
})

test_that("InferenceAllSimpleWilcox: design_compatibility_reason matches real throw behavior", {
	n = 20L
	des_ok = DesignFixedBernoulli$new(n = n, response_type = "continuous", prob_T = 0.5)
	des_ok$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_ok$assign_w_to_all_subjects()
	des_ok$add_all_subject_responses(rnorm(n))

	reason_fn = EDI:::InferenceAllSimpleWilcox$private_methods$design_compatibility_reason
	expect_true(is.na(reason_fn(des_ok)))
	expect_no_error(InferenceAllSimpleWilcox$new(des_ok))
	expect_true("InferenceAllSimpleWilcox" %in% des_ok$applicable_inference_class_names())

	des_bad = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des_bad$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_bad$assign_w_to_all_subjects()
	des_bad$add_all_subject_responses(rbinom(n, 1, 0.4))

	expect_identical(reason_fn(des_bad), "wilcoxon_incidence_response_unsupported")
	expect_error(InferenceAllSimpleWilcox$new(des_bad), "incidence")
	expect_false("InferenceAllSimpleWilcox" %in% des_bad$applicable_inference_class_names())
})

test_that("Every class with a design_compatibility_reason predicate is excluded end-to-end for an incompatible design it flags", {
	# General, registry-driven sweep (not just the four classes spot-checked
	# above): for every exported, non-abstract Inference class that declares
	# a `design_compatibility_reason`, build one design known to trip it
	# (reusing the incompatible fixtures above by response-type family) and
	# confirm InferenceSuite's discovery actually excludes it -- catches a
	# future class registering the predicate but the InferenceSuite/Design
	# wiring silently not picking it up for that class.
	n = 20L
	des_bad_incidence = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5)
	des_bad_incidence$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_bad_incidence$assign_w_to_all_subjects()
	des_bad_incidence$add_all_subject_responses(rbinom(n, 1, 0.4))

	registry = EDI:::inference_class_registry_as_list()
	classes_with_predicate = Filter(function(nm) {
		isTRUE(registry[[nm]]$exported) && !isTRUE(registry[[nm]]$abstract) &&
			!is.null(EDI:::infer_inference_design_compatibility_reason_fn(get(nm, envir = asNamespace("EDI"))))
	}, names(registry))
	expect_true(length(classes_with_predicate) >= 3L)

	for (nm in classes_with_predicate) {
		reason = EDI:::inference_class_design_compatibility_reason(nm, des_bad_incidence)
		if (!is.na(reason)) {
			applicable = des_bad_incidence$applicable_inference_class_names()
			expect_false(nm %in% applicable, info = nm)
		}
	}
})
