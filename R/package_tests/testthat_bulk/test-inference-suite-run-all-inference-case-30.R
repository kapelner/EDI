library(testthat)
library(EDI)

test_that("run_all_inference: estimand is a registry-level fact, populated regardless of fit outcome", {
	set.seed(20260819)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	suite = InferenceSuite$new(des)
	target = intersect(
		suite$applicable_design_classes,
		c("InferenceIncidGCompRiskDiff", "InferenceIncidGCompRiskRatio", "InferenceIncidLogRegr")
	)
	skip_if(length(target) < 2L, "gcomp classes not applicable to this fixture")

	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE, classes = target)
	})
	tbl = res$results_table
	row_rd = tbl[tbl$inference_class == "InferenceIncidGCompRiskDiff", ]
	row_rr = tbl[tbl$inference_class == "InferenceIncidGCompRiskRatio", ]
	row_logit = tbl[tbl$inference_class == "InferenceIncidLogRegr", ]

	# `methods = NULL` (default) can now fan a class out to more than one
	# row (one per applicable method sentinel) -- `estimand` is a
	# registry-level, per-class fact, so it's identical across every
	# method-row for the same class; check via unique() rather than
	# assuming exactly one row.
	expect_identical(unique(row_rd$estimand), "mean_difference")
	# The whole point of reading estimand from the class metadata registry
	# instead of the fitted instance: it must still be populated even when
	# status != "ok" (registry lookup needs no successful construction/fit).
	expect_identical(unique(row_rr$estimand), "RR")
	expect_true(all(row_rr$status %in% c("ok", "nonest")))
	# Every class now has a registry-declared estimand (a later, broader
	# taxonomy pass populated the ones that used to report NA here).
	expect_identical(unique(row_logit$estimand), "log_odds_ratio_marginal")
})

# TODO-23 (inference_suite_plan.md): EDI_INFERENCE_SUITE_METHOD_SENTINELS/
# _CI_METHOD_PRIORITY/_PVAL_METHOD_PRIORITY are now derived from
# contracts_mixins.R's public_methods_for_capability registry (validated at
# package-load time) rather than a hand-typed literal with no connection to
# it. This is the permanent drift guard: it must return empty every time
# these tests run, exactly like the completeness check
# fix_inference_hierarchy.md's own test-capability-tables.R runs for the
# registry itself -- if a future capability/method pair is added to
# contracts_mixins.R and never mapped to a sentinel (or explicitly
# allowlisted as deliberately uncatalogued), this fails loudly instead of
# the gap going unnoticed.
