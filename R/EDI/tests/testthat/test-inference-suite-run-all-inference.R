library(testthat)
library(EDI)

# TODO-9 (inference_suite_inspect.md): working/scratch subset, NOT the full
# committed fixture grid. Per that plan's explicit gating, the full grid
# (every response type x {iid, KK} x {BCRD, blocking, KK, greedy, D-optimal})
# is locked until fix_inference_hierarchy.md's Phase 1D (Base Deletion etc.)
# closes, since that phase can still shift a class's likelihood_tier/
# optional-method columns out from under a hardcoded expectation. This file
# stays safe to run today by asserting only STRUCTURE (schema shape,
# design_family labeling, "at least one status == 'ok' row", return-object
# shape) -- never a specific class's specific capability/value -- so it is
# resilient to Phase 1D churn. It covers the full DESIGN-CLASS axis (BCRD,
# blocking, KK, greedy, D-optimal) but only two response types (continuous,
# incidence), not the full response-type x design-family cross product.
# Extend to the full grid with tighter, class-specific assertions once
# Phase 1D closes (see _master.md's Phase 1G).

expect_valid_run_all_inference_report = function(des_obj, expected_design_family, alpha = 0.05) {
	suite = InferenceSuite$new(des_obj)
	out = capture.output({
		res <- suite$run_all_inference(screen = TRUE, html = FALSE, alpha = alpha, plots = FALSE)
	})

	expect_s3_class(res, "EDIInferenceSuiteResults")
	expect_true(is.list(res))
	expect_identical(
		names(res),
		c("results", "results_table", "design", "alpha",
		  "unavailable_due_to_missing_packages", "combined_evidence", "plots", "files",
		  "timestamp", "total_secs", "edi_version")
	)

	tbl = res$results_table
	expect_identical(
		names(tbl),
		c("inference_class", "method", "cov_model", "response_type", "design_family", "likelihood_tier",
		  "estimate", "se", "ci_a", "ci_b", "ci_method",
		  "pval", "pval_method", "estimand", "fit_secs", "warnings",
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
		expect_true(all(is.na(ok$message)))
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

test_that("run_all_inference: continuous iBCRD (iid)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	expect_valid_run_all_inference_report(des, "iid")
})

test_that("run_all_inference: incidence iBCRD (iid)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBernoulli$new(n = n, response_type = "incidence", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	expect_valid_run_all_inference_report(des, "iid")
})

test_that("run_all_inference: incidence blocking design (iid, non-KK)", {
	set.seed(20260818)
	n = 30L
	des = DesignFixedBlocking$new(n = n, response_type = "incidence", strata_cols = "x2", equal_block_sizes = FALSE)
	X = data.frame(x1 = rnorm(n), x2 = sample(c("a", "b"), n, TRUE))
	des$add_all_subjects_to_experiment(X)
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(rbinom(n, 1, plogis(-0.2 + 0.6 * w)))
	expect_valid_run_all_inference_report(des, "iid")
})

test_that("run_all_inference: continuous KK14 (matched pair)", {
	set.seed(20260818)
	n = 16L
	des = DesignSeqOneByOneKK14$new(n = n, response_type = "continuous", verbose = FALSE)
	for (i in seq_len(n)) {
		des$add_one_subject_to_experiment_and_assign(data.frame(x1 = rnorm(1)))
	}
	des$add_all_subject_responses(rnorm(n))
	expect_valid_run_all_inference_report(des, "kk_matched_pair")
})

test_that("run_all_inference: continuous DesignFixedGreedy (iid)", {
	set.seed(20260818)
	n = 20L
	des = DesignFixedGreedy$new(response_type = "continuous", n = n, verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	expect_valid_run_all_inference_report(des, "iid")
})

test_that("run_all_inference: continuous DesignFixedOptimal (iid, deterministic)", {
	skip_if_not_installed("ompr")
	skip_if_not_installed("ompr.roi")
	skip_if_not_installed("ROI.plugin.glpk")
	set.seed(20260818)
	n = 12L
	des = DesignFixedOptimal$new(n = n, response_type = "continuous", seed = 42)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n), x2 = runif(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	expect_valid_run_all_inference_report(des, "iid")
})

test_that("run_all_inference: per-class failure isolation is a real regression test, not just dev-session verification", {
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))

	# run_all_inference_one_class() looks the class up via
	# get(cls_name, envir = getNamespace("EDI")) (the same pattern
	# InferenceSuite$initialize()'s inference_params validation already uses),
	# whose search chain reaches .GlobalEnv but NOT a test_that() block's own
	# local frame -- so the generator must be assigned into .GlobalEnv
	# explicitly, not just defined as a local variable here.
	InferenceTemporaryAlwaysThrowsRunAll = R6::R6Class("InferenceTemporaryAlwaysThrowsRunAll",
		inherit = EDI:::Inference,
		public = list(
			initialize = function(des_obj, ...) {
				stop("InferenceTemporaryAlwaysThrowsRunAll: constructor always fails (test double).")
			}
		)
	)
	assign("InferenceTemporaryAlwaysThrowsRunAll", InferenceTemporaryAlwaysThrowsRunAll, envir = .GlobalEnv)
	on.exit(rm("InferenceTemporaryAlwaysThrowsRunAll", envir = .GlobalEnv), add = TRUE)
	EDI:::register_inference_class(
		name = "InferenceTemporaryAlwaysThrowsRunAll",
		parent = "Inference",
		metadata = list(
			abstract = FALSE, exported = TRUE, response_types = "continuous",
			design_families = "all", compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none", required_packages = character(), capabilities = character()
		),
		direct_components = character()
	)

	suite = InferenceSuite$new(des)
	expect_true("InferenceTemporaryAlwaysThrowsRunAll" %in% suite$applicable_design_classes)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE)
	})
	tbl = res$results_table
	broken_row = tbl[tbl$inference_class == "InferenceTemporaryAlwaysThrowsRunAll", , drop = FALSE]
	expect_identical(nrow(broken_row), 1L)
	expect_identical(broken_row$status, "error")
	expect_true(grepl("constructor always fails", broken_row$message, fixed = TRUE))
	# Every other applicable class must be unaffected by the broken one.
	other_rows = tbl[tbl$inference_class != "InferenceTemporaryAlwaysThrowsRunAll", , drop = FALSE]
	expect_true(all(other_rows$status == "ok"))
})

test_that("run_all_inference: screen/html both FALSE is a hard error, not a silent no-op", {
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)
	expect_error(
		suite$run_all_inference(screen = FALSE, html = FALSE),
		"at least one of `screen`/`html` must be TRUE",
		fixed = TRUE
	)
})

test_that("run_all_inference: html writes a self-contained file and returns its path", {
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	old_browser = getOption("browser")
	tmp_dir = tempfile("edi-inference-suite-html-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	options(browser = function(url) invisible(NULL))
	on.exit({ setwd(old_wd); options(browser = old_browser); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	res = suite$run_all_inference(screen = FALSE, html = TRUE, plots = FALSE)

	expect_true(!is.null(res$files$html))
	expect_true(file.exists(res$files$html))
	html_txt = paste(readLines(res$files$html, warn = FALSE), collapse = "\n")
	expect_true(grepl("<!DOCTYPE html>", html_txt, fixed = TRUE))
	expect_false(grepl("<script", html_txt, fixed = TRUE))
	expect_false(grepl("http://", html_txt, fixed = TRUE))
	expect_false(grepl("https://", html_txt, fixed = TRUE))
})

test_that("run_all_inference: save_results_as_JSON writes a file that round-trips", {
	skip_if_not_installed("jsonlite")
	set.seed(20260818)
	n = 10L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	tmp_dir = tempfile("edi-inference-suite-json-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	on.exit({ setwd(old_wd); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, save_results_as_JSON = TRUE, plots = FALSE)
	})

	expect_true(!is.null(res$files$json))
	expect_true(file.exists(res$files$json))
	parsed = jsonlite::fromJSON(res$files$json)
	expect_identical(nrow(parsed$results_table), nrow(res$results_table))
	expect_identical(sort(names(parsed$results)), sort(names(res$results)))
})

test_that("run_all_inference: plots = TRUE builds real ggplot objects when ggplot2 is available", {
	skip_if_not_installed("ggplot2")
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	null_dev = grDevices::pdf(NULL)
	on.exit(grDevices::dev.off(), add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = TRUE)
	})
	expect_s3_class(res$plots$estimates, "ggplot")
	expect_s3_class(res$plots$ci_forest, "ggplot")
})

test_that("run_all_inference: pdf = TRUE writes a two-page PDF", {
	skip_if_not_installed("ggplot2")
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	old_wd = getwd()
	tmp_dir = tempfile("edi-inference-suite-pdf-")
	dir.create(tmp_dir)
	setwd(tmp_dir)
	null_dev = grDevices::pdf(NULL)
	on.exit({ grDevices::dev.off(); setwd(old_wd); unlink(tmp_dir, recursive = TRUE) }, add = TRUE)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = TRUE, pdf = TRUE)
	})

	expect_true(!is.null(res$files$pdf))
	expect_true(file.exists(res$files$pdf))
	# A PDF's page count is encoded as the number of "/Type /Page" (not
	# "/Pages") object entries. Matched directly against the raw byte vector
	# via grepRaw() -- avoids both a hard dependency on pdftools/pdfinfo being
	# installed in the test environment, and the encoding warnings/errors that
	# rawToChar()/gregexpr() throw on a PDF's binary (non-UTF-8) byte stream.
	raw = readBin(res$files$pdf, "raw", file.info(res$files$pdf)$size)
	page_matches = grepRaw("/Type\\s*/Page[^s]", raw, all = TRUE, fixed = FALSE)
	expect_true(length(page_matches) >= 1L)
})

# --- Practitioner follow-ups (TODO-10..13) ---------------------------------

test_that("run_all_inference: print()/summary() S3 methods dispatch correctly", {
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE, classes = "InferenceContinOLS")
	})

	printed = capture.output(print(res))
	expect_true(any(grepl("EDIInferenceSuiteResults", printed, fixed = TRUE)))
	expect_true(any(grepl("InferenceContinOLS", printed, fixed = TRUE)))

	smry = summary(res)
	expect_s3_class(smry, "summary.EDIInferenceSuiteResults")
	expect_identical(smry$n_classes, 1L)
	expect_identical(unname(smry$status_counts[["ok"]]), 1L)
	expect_identical(smry$alpha, 0.05)

	smry_printed = capture.output(print(smry))
	expect_true(any(grepl("summary", smry_printed, fixed = TRUE)))
	expect_true(any(grepl("classes:", smry_printed, fixed = TRUE)))
})

test_that("run_all_inference: classes/exclude_classes filter and validate", {
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res_allow <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			classes = c("InferenceContinOLS", "InferenceContinLin"))
	})
	expect_identical(sort(unique(res_allow$results_table$inference_class)), c("InferenceContinLin", "InferenceContinOLS"))

	capture.output({
		res_deny <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			exclude_classes = "InferenceContinOLS")
	})
	expect_false("InferenceContinOLS" %in% res_deny$results_table$inference_class)
	expect_identical(length(unique(res_deny$results_table$inference_class)), length(suite$applicable_design_classes) - 1L)

	expect_error(
		suite$run_all_inference(screen = TRUE, classes = "NotARealInferenceClass"),
		"unknown/inapplicable class"
	)
	expect_error(
		suite$run_all_inference(screen = TRUE, exclude_classes = "NotARealInferenceClass"),
		"unknown/inapplicable class"
	)
})

test_that("run_all_inference: max_secs_per_class actually interrupts a slow R-level fit", {
	skip_on_cran()
	on.exit(EDI:::populate_inference_class_registry(), add = TRUE)
	set.seed(20260818)
	n = 12L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	des$add_all_subject_responses(rnorm(n))

	# Busy-loops for 5s in pure R (an R-level loop, not one opaque native call) --
	# setTimeLimit() is documented to check at R-level interrupt points, so this
	# is the case the timeout mechanism is actually guaranteed to catch (see the
	# "known limitation" note on run_all_inference_one_class()).
	InferenceTemporarySlowRunAll = R6::R6Class("InferenceTemporarySlowRunAll",
		inherit = EDI:::Inference,
		public = list(
			compute_estimate = function(estimate_only = FALSE) {
				t_end = Sys.time() + 5
				while (Sys.time() < t_end) { x = 0; for (i in 1:1e5) x = x + 1 }
				0
			}
		)
	)
	assign("InferenceTemporarySlowRunAll", InferenceTemporarySlowRunAll, envir = .GlobalEnv)
	on.exit(rm("InferenceTemporarySlowRunAll", envir = .GlobalEnv), add = TRUE)
	EDI:::register_inference_class(
		name = "InferenceTemporarySlowRunAll", parent = "Inference",
		metadata = list(
			abstract = FALSE, exported = TRUE, response_types = "continuous",
			design_families = "all", compatibility = EDI:::always_compatible_inference_metadata,
			likelihood_tier = "none", required_packages = character(), capabilities = character()
		),
		direct_components = character()
	)

	suite = InferenceSuite$new(des)
	t0 = Sys.time()
	capture.output({
		res <- suite$run_all_inference(screen = TRUE, plots = FALSE,
			classes = "InferenceTemporarySlowRunAll", max_secs_per_class = 1)
	})
	elapsed = as.numeric(difftime(Sys.time(), t0, units = "secs"))

	expect_lt(elapsed, 4)  # well under the 5s the fit would otherwise take
	row = res$results_table
	expect_identical(row$status, "timeout")
	expect_true(grepl("max_secs_per_class", row$message, fixed = TRUE))
})

test_that("run_all_inference: num_cores > 1 fits in parallel and produces identical rows to sequential", {
	skip_on_cran()
	skip_on_os("windows")
	set.seed(20260818)
	n = 20L
	des = DesignFixedBernoulli$new(n = n, response_type = "continuous", verbose = FALSE)
	des$add_all_subjects_to_experiment(data.frame(x1 = rnorm(n)))
	des$assign_w_to_all_subjects()
	w = des$get_w()
	des$add_all_subject_responses(1 + 0.5 * w + rnorm(n))
	suite = InferenceSuite$new(des)

	capture.output({
		res_seq <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 1)
	})
	capture.output({
		res_par <- suite$run_all_inference(screen = TRUE, plots = FALSE, num_cores = 2)
	})

	seq_tbl = res_seq$results_table[order(res_seq$results_table$inference_class), ]
	par_tbl = res_par$results_table[order(res_par$results_table$inference_class), ]
	rownames(seq_tbl) = NULL
	rownames(par_tbl) = NULL
	# fit_secs will differ run to run; compare everything else.
	compare_cols = setdiff(names(seq_tbl), "fit_secs")
	expect_identical(seq_tbl[compare_cols], par_tbl[compare_cols])
})

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
	expect_identical(unique(row_rd$estimand), "RD")
	# The whole point of reading estimand from the class metadata registry
	# instead of the fitted instance: it must still be populated even when
	# status != "ok" (registry lookup needs no successful construction/fit).
	expect_identical(unique(row_rr$estimand), "RR")
	expect_true(all(row_rr$status %in% c("ok", "nonest")))
	# A class with no declared get_estimand_type() reports NA, not an error.
	expect_identical(unique(row_logit$estimand), NA_character_)
})
