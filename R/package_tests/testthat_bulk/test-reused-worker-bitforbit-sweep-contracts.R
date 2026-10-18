library(testthat)
library(EDI)

load_sweep_helpers = function(){
	e = new.env(parent = globalenv())
	script_path = testthat::test_path("..", "..", "..", "scripts", "reused_worker_bitforbit_sweep.R")
	suppressMessages(capture.output(sys.source(script_path, envir = e), type = "output"))
	e$RESAMPLING_NONDEGENERATE_R = 15L
	fixture_path = testthat::test_path("..", "..", "EDI", "tests", "testthat",
	                                  "test-reused-worker-resampling-nondegenerate.R")
	fixture_exprs = parse(fixture_path)
	case_expr = Filter(function(expr) {
		is.call(expr) && length(expr) >= 3L &&
			(identical(expr[[1L]], as.name("=")) || identical(expr[[1L]], as.name("<-"))) &&
			identical(expr[[2L]], as.name("resampling_nondegenerate_cases"))
	}, fixture_exprs)
	if (length(case_expr) != 1L) stop("expected exactly one sweep case-enumerator definition")
	eval(case_expr[[1L]], envir = e)
	e
}

save_snapshot_pair = function(e, before, after){
	dir = tempfile("edi-todo12-sweep-contract-", tmpdir = "/tmp")
	dir.create(dir)
	before_path = file.path(dir, "before.rds")
	after_path = file.path(dir, "after.rds")
	saveRDS(before, before_path)
	saveRDS(after, after_path)
	list(before = before_path, after = after_path, cleanup = function() unlink(dir, recursive = TRUE))
}

test_that("sweep constructors and distribution calls fail closed", {
	e = load_sweep_helpers()
	broken_arm = list(name = "fake", build = function(response_type) stop("design boom"))
	expect_error(e$sweep_build_design(broken_arm, "continuous"), "design constructor failed.*design boom")

	broken_generator = list(new = function(...) stop("class boom"))
	expect_error(e$sweep_new_inference(broken_generator, list(), "Fake|bernoulli|continuous|production"),
	             "inference constructor failed.*class boom")
	broken_object = list(approximate_randomization_distribution_beta_hat_T = function(...) stop("distribution boom"))
	expect_error(e$sweep_distribution(broken_object, "Fake|bernoulli|continuous|production", 15L),
	             "distribution failed.*distribution boom")
	expect_error(e$sweep_distribution(list(approximate_randomization_distribution_beta_hat_T = function(...) 1:14),
	                                "Fake|bernoulli|continuous|production", 15L),
	             "has length 14; expected 15")
})

test_that("strict fixture enumeration reports missing and failed registered classes", {
	e = load_sweep_helpers()
	arm = list(name = "fake", selects = function(entry) TRUE)
	registry = list(FakeSweepClass = list(abstract = FALSE, response_types = "continuous"))
	missing_ns = new.env(parent = globalenv())
	expect_error(e$resampling_nondegenerate_cases(arm, "continuous", list(), registry, missing_ns, strict = TRUE),
	             "missing registered sweep class: FakeSweepClass")

	broken_ns = new.env(parent = globalenv())
	broken_ns$FakeSweepClass = R6::R6Class(
		"FakeSweepClass", public = list(initialize = function(...) stop("constructor boom"))
	)
	expect_error(e$resampling_nondegenerate_cases(arm, "continuous", list(), registry, broken_ns, strict = TRUE),
	             "sweep class constructor failed for FakeSweepClass.*constructor boom")
})

test_that("snapshot validation rejects incomplete manifests and invalid distributions", {
	e = load_sweep_helpers()
	expect_error(e$validate_sweep_snapshot(list(a = 1:15), c("a", "b"), 15L), "key mismatch.*missing=.*b")
	expect_error(e$validate_sweep_snapshot(list(a = 1:14), "a", 15L), "must be numeric length 15")
	expect_error(e$validate_sweep_snapshot(list(a = c(rep(1, 14), Inf)), "a", 15L), "non-finite, non-NA")
	expect_error(e$validate_sweep_snapshot(structure(list(1:15, 1:15), names = c("a", "a")), "a", 15L),
	             "duplicate keys")
})

test_that("comparison refuses manifest, observed-key, and NA-pattern mismatches", {
	e = load_sweep_helpers()
	before = structure(list(a = seq_len(15L)), expected_keys = "a")
	after_missing_manifest = structure(list(b = seq_len(15L)), expected_keys = "b")
	pair = save_snapshot_pair(e, before, after_missing_manifest)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "expected key manifests differ")

	after_extra = structure(list(a = seq_len(15L), b = seq_len(15L)), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_extra)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "key mismatch.*extra=.*b")

	after_na = structure(list(a = c(NA_real_, 2:15)), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_na)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "NA-pattern mismatch for a")

	after_short = structure(list(a = 1:14), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_short)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "must be numeric length 15")
})
