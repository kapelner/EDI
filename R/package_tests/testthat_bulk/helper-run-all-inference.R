library(testthat)
library(EDI)

# TODO-9 (inference_suite_plan.md, tracked elsewhere as "inference_suite_
# inspect.md" -- same plan, stale name): full grid, unlocked 2026-08-23 once
# fix_inference_hierarchy.md's Phase 1D (Base Deletion etc.) closed, so a
# class's likelihood_tier/optional-method columns are now stable. Covers the
# full DESIGN-CLASS axis (BCRD, blocking, KK, greedy, D-optimal; continuous/
# incidence only, since exercising every response type against every design
# class is combinatorially unnecessary once both axes are independently
# covered) x the full RESPONSE-TYPE axis (all six response types, each x
# {iid iBCRD, KK14 matched pair}). Structural assertions
# (`expect_valid_run_all_inference_report()`: schema shape, design_family
# labeling, per-diagnostics shape, return-object shape) apply everywhere;
# `expect_canonical_class_ok()` layers a tighter, class-specific check (a
# named canonical class for that response type reports status == "ok" with a
# finite estimate, not just "some row is ok") on the iid block of each of the
# four newly-added response types.

expect_valid_run_all_inference_report = function(des_obj, expected_design_family, alpha = 0.05, basic_bootstrap = FALSE) {
	suite = InferenceSuite$new(des_obj)
	out = capture.output({
		res <- suite$run_all_inference(screen = TRUE, html = FALSE, alpha = alpha, plots = FALSE, basic_bootstrap = basic_bootstrap)
	})

	expect_s3_class(res, "EDIInferenceSuiteResults")
	expect_true(is.list(res))
	expect_identical(
		names(res),
		c("results", "results_table", "compute_conf_intervals", "design", "alpha",
		  "unavailable_due_to_missing_packages", "combined_evidence", "plots", "files",
		  "timestamp", "total_secs", "edi_version")
	)

	tbl = res$results_table
	expect_identical(
		names(tbl),
		c("inference_class", "method", "type", "cov_model", "response_type", "design_family", "likelihood_tier",
		  "estimate", "se", "ci_a", "ci_b", "ci_method",
		  "pval", "pval_method", "estimand", "tau", "fit_secs", "warnings",
		  "status", "message", "weight")
	)
	# `methods = NULL` (default) now fans out to one row per applicable
	# method sentinel per class, so row/result count is >= the class count,
	# not equal to it -- but every applicable class must appear at least
	# once, and no unrequested class should ever appear.
	expect_true(nrow(tbl) >= length(suite$applicable_design_classes))
	expect_identical(sort(unique(tbl$inference_class)), sort(suite$applicable_design_classes))
	result_classes = vapply(res$results, function(r) r$inference_class, character(1L))
	expect_identical(sort(unique(result_classes)), sort(suite$applicable_design_classes))

	if (nrow(tbl) > 0L) {
		expect_true(all(tbl$design_family == expected_design_family))
		expect_true(all(tbl$status %in% c("ok", "nonest", "error")))
		expect_true(any(tbl$status == "ok"))
		ok = tbl[tbl$status == "ok", , drop = FALSE]
		# A status == "ok" row must have a finite estimate; a class with no
		# CI/p-value capability in the Method Selection Policy table legitimately
		# reports NA there without being a failure.
		expect_true(all(is.finite(ok$estimate)))
		# An `ok` row carries a `message` only to explain a CI/p-value call
		# that errored (swallowed into `NA` -- see `run_all_inference_call_
		# {ci,pval}_for_method()`, 2026-08-21); never otherwise.
		expect_true(all(is.na(ok$message) | is.na(ok$ci_a) | is.na(ok$pval)))
	}

	expect_identical(res$design$design_family, expected_design_family)
	expect_identical(res$design$n, des_obj$get_n())
	expect_identical(res$alpha, alpha)
	expect_null(res$files$html)
	expect_null(res$files$pdf)
	expect_null(res$files$json)

	# Every result row's `diagnostics` sub-list carries the v1.0.0-scoped
	# placeholder shape (see inference_suite_inspect.md's Per-class
	# `diagnostics` element note) -- real values are v1.1.0 scope.
	for (r in res$results) {
		expect_identical(
			names(r$diagnostics),
			c("converged", "hit_iteration_cap", "iterations", "optimizer")
		)
	}

	res
}

# Tighter, class-specific check layered on top of the structural helper above
# (TODO-9's "full grid ... with tighter, class-specific assertions", now that
# fix_inference_hierarchy.md's Phase 1D closed 2026-08-23 and a class's
# likelihood_tier/optional-method columns are stable): asserts a specific,
# well-known canonical class for this response type reports status == "ok"
# with a finite estimate -- not just "some row, somewhere, is ok".
expect_canonical_class_ok = function(res, class_name) {
	tbl = res$results_table
	row = tbl[tbl$inference_class == class_name, , drop = FALSE]
	expect_gt(nrow(row), 0L, label = sprintf("%s present in results_table", class_name))
	expect_true(any(row$status == "ok"), label = sprintf("%s has an 'ok' row", class_name))
	ok_row = row[row$status == "ok", , drop = FALSE][1, ]
	expect_true(is.finite(ok_row$estimate))
}

