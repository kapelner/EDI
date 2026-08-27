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

	reason_fn = EDI:::infer_inference_design_compatibility_reason_fn(EDI:::InferenceIncidCMH)
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

	reason_fn = EDI:::infer_inference_design_compatibility_reason_fn(EDI:::InferenceIncidCMH)
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

	reason_fn = EDI:::infer_inference_design_compatibility_reason_fn(EDI:::InferenceIncidExtendedRobins)
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
	# Not asserted via incompatible_inference_classes_due_to_design_structure()
	# here: this des_bad is non-blocking, so the pre-existing coarse
	# requires_blocking_design registry filter (is_inference_class_compatible_
	# with_design_metadata()) already excludes this class before
	# design_compatibility_reason() is ever consulted -- that bucket only
	# holds classes that pass the coarse filter but fail the finer-grained
	# predicate (see the CMH block-size-inequality case above, which is
	# blocking and does reach this bucket).
})

test_that("InferenceAllSimpleWilcox: design_compatibility_reason matches real throw behavior", {
	n = 20L
	des_ok = DesignFixedBernoulli$new(n = n, response_type = "continuous", prob_T = 0.5)
	des_ok$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des_ok$assign_w_to_all_subjects()
	des_ok$add_all_subject_responses(rnorm(n))

	reason_fn = EDI:::infer_inference_design_compatibility_reason_fn(EDI:::InferenceAllSimpleWilcox)
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

# Regression coverage for the method-level (not class-construction-level) fix
# to fix_inference_hierarchy.md's "method-level stop()s" TODO: InferenceRand's
# plain compute_rand_two_sided_pval() throws for an incidence-response
# instance with no custom randomization statistic on a design whose
# randomization_family() isn't "rerandomization" AND that isn't Zhang-eligible
# -- confirmed reachable for InferenceIncidGCompRiskRatio/RiskDiff (this class
# pins InferenceRand's own method rather than a separately-defined override).
# Before the fix, InferenceSuite's run_all_inference_call_pval_for_method()
# caught this stop() and silently degraded to pval = NA while still reporting
# status = "ok" and method = "rand" -- indistinguishable from a genuine (if
# unlucky) NA result. After the fix, the "rand" sentinel is recognized as
# inapplicable up front (mirroring the "no capability" shape used elsewhere in
# this file) for designs that are genuinely unsupported.
#
# 2026-08-23 (per user request, same day as the method-level-stop() fix
# above): a Zhang-eligible incidence design (matched-pair or Bernoulli, no
# custom randomization statistic) now gets a real "rand" p-value via the
# Zhang exact combined test instead of throwing -- see
# InferenceRand$supports_rand_pval_for_incidence()'s and
# compute_rand_two_sided_pval()'s own doc comments in
# inference_all_abstract_rand.R. That escape hatch lives directly in
# InferenceRand's own method body, so InferenceIncidGCompRiskRatio/RiskDiff
# (which pin `InferenceRand$public_methods$compute_rand_two_sided_pval` by
# reference, not a frozen copy) inherit it automatically for a Bernoulli
# design like the one below -- this is the current, intended behavior, not a
# regression. The genuinely-unsupported-throws-a-real-error path this test
# originally covered is still real; it is simply not reachable from THIS
# design (Bernoulli, Zhang-eligible) any more.
test_that("InferenceRand: supports_rand_pval_for_incidence() matches real throw behavior", {
	n = 20L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))
	expect_identical(des$randomization_family(), "bernoulli")

	inf = InferenceIncidGCompRiskRatio$new(des)
	expect_true(inf$supports_rand_pval_for_incidence())
	p = inf$compute_rand_two_sided_pval(r = 51)
	expect_true(is.finite(p) && p >= 0 && p <= 1)
})

# 2026-08-27 (incidence_randomization_cis.md stopgap): run_all_inference()
# no longer offers the "rand" method for incidence responses at all --
# compute_rand_confidence_interval()'s Zhang CI dispatch was found to report
# the same log-odds-ratio-scale interval verbatim for every incidence
# class regardless of its own estimand's scale, so the CI side was
# hard-disabled; since "rand" was only kept in incidence's applicable-method
# list to pair that (now-broken) CI with its own real p-value, the whole
# method is excluded rather than emit a p-value-only row with a permanently
# broken CI. compute_rand_two_sided_pval() itself is untouched and still
# correct when called directly (see the test above) -- only the suite's
# auto-discovery stopped offering it for incidence. The class still gets a
# results-table row (run_all_inference() always emits one per requested
# class), but with no method actually attempted: pval/pval_method/ci_* all
# come back NA and status stays "ok" (verified directly, 2026-08-27). Once
# the plan's real fix ships (Implementation TODO-5: restore "rand" in
# run_all_inference_class_applicable_methods()'s incidence branch alongside
# reverting the CI stopgap), this test should go back to asserting a real,
# non-NA pval, as it did before 2026-08-27.
test_that("run_all_inference(): 'rand' method is not offered for an incidence design (CI-side stopgap)", {
	n = 20L
	des = DesignSeqOneByOneBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	for (i in seq_len(n)) des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	des$add_all_subject_responses(rbinom(n, 1, 0.4))

	suite = InferenceSuite$new(des)
	res = suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, pdf = FALSE,
		save_results_as_JSON = FALSE, methods = c("rand"),
		classes = c("InferenceIncidGCompRiskRatio")
	)
	row = res$results_table[res$results_table$inference_class == "InferenceIncidGCompRiskRatio", ]
	expect_identical(nrow(row), 1L)
	expect_identical(row$status, "ok")
	expect_true(is.na(row$pval))
	expect_true(is.na(row$pval_method))
})

# Regression coverage for the Bartlett-sentinel-gating fix (user report,
# 2026-08-21: "why is Bartlett running for Probit? Bartlett exact is not
# implemented for probit"). InferenceIncidProbitRegr's own
# supports_bartlett_likelihood_ratio_exact() correctly defaults FALSE, and
# get_supported_testing_types() (a real, pre-existing public accessor)
# already excludes "lik_ratio_bartlett_exact" from its result -- but
# run_all_inference_call_ci_for_method()/_call_pval_for_method() only
# checked the coarse "likelihood_tests" capability (shared with plain
# wald/score/lik_ratio/gradient) for the two Bartlett sentinels, never
# consulting that accessor, so the sentinel was attempted anyway and
# silently produced a status = "nonest" row instead of never being offered.
test_that("get_supported_testing_types() excludes lik_ratio_bartlett_exact for InferenceIncidProbitRegr", {
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))

	inf = InferenceIncidProbitRegr$new(des)
	supported = inf$get_supported_testing_types()
	expect_false("lik_ratio_bartlett_exact" %in% supported)
})

test_that("run_all_inference(): lik_ratio_bartlett_exact is never offered for InferenceIncidProbitRegr", {
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", prob_T = 0.5, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rbinom(n, 1, plogis(0.3 * des$get_w())))

	suite = InferenceSuite$new(des)
	res = suite$run_all_inference(
		screen = TRUE, html = FALSE, plots = FALSE, pdf = FALSE,
		methods = c("lik_ratio_bartlett_exact", "lik_ratio_bartlett_approx"),
		classes = c("InferenceIncidProbitRegr")
	)
	tbl = res$results_table[res$results_table$inference_class == "InferenceIncidProbitRegr", ]
	# Bartlett-approx is genuinely supported (status can be "ok"/"nonest"
	# depending on the fit), but bartlett-exact must never be attempted --
	# no row should report either ci_method or pval_method as the exact
	# sentinel, and none should be the tell-tale "nonest" row the user
	# actually observed for it.
	expect_false(any(tbl$ci_method == "lik_ratio_bartlett_exact", na.rm = TRUE))
	expect_false(any(tbl$pval_method == "lik_ratio_bartlett_exact", na.rm = TRUE))
})
