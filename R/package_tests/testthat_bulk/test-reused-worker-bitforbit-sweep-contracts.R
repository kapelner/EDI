library(testthat)
library(EDI)

load_sweep_helpers = function(){
	e = new.env(parent = globalenv())
	script_path = testthat::test_path("..", "..", "..", "scripts", "reused_worker_bitforbit_sweep.R")
	suppressMessages(capture.output(sys.source(script_path, envir = e), type = "output"))
	e$RESAMPLING_NONDEGENERATE_R = 15L
	# Most comparator cases below use tiny synthetic manifests; production's
	# record/compare entry points retain the checked-in 240-key requirement.
	e$RESAMPLING_NONDEGENERATE_EXPECTED_KEY_COUNT = 1L
	fixture_path = testthat::test_path("..", "..", "EDI", "tests", "testthat",
	                                  "test-reused-worker-resampling-nondegenerate.R")
	fixture_exprs = parse(fixture_path)
	for (expr in fixture_exprs) {
		if (is.call(expr) && length(expr) > 0L) {
			head_name = tryCatch(as.character(expr[[1L]])[1L], error = function(e) "")
			if (head_name %in% c("test_that", "library", "require")) next
		}
		eval(expr, envir = e)
	}
	e
}

save_snapshot_pair = function(e, before, after){
	dir = tempfile("edi-todo12-sweep-contract-", tmpdir = "/tmp")
	dir.create(dir)
	before_path = file.path(dir, "before.rds")
	after_path = file.path(dir, "after.rds")
	provenance = list(
		package_version = "1.0.3",
		package_path = "/tmp/EDI",
		source_tree = FALSE,
		native_dll_path = "/tmp/EDI.so",
		native_dll_md5 = "0123456789abcdef0123456789abcdef",
		r_layer_kind = "source-files",
		r_layer_file_md5 = c("inference.R" = "abcdef0123456789abcdef0123456789")
	)
	attr(before, "provenance") = provenance
	attr(after, "provenance") = provenance
	saveRDS(before, before_path)
	saveRDS(after, after_path)
	list(before = before_path, after = after_path, provenance = provenance,
	     cleanup = function() unlink(dir, recursive = TRUE))
}

test_that("sweep provenance pins loaded EDI version, native DLL, and R layer", {
	e = load_sweep_helpers()
	provenance = e$sweep_capture_provenance(use_source_tree = FALSE)
	e$validate_sweep_provenance(provenance)
	expect_identical(provenance$package_version,
	                 unname(read.dcf(file.path(provenance$package_path, "DESCRIPTION"))[1L, "Version"]))
	expect_true(file.exists(provenance$native_dll_path))
	expect_identical(provenance$native_dll_md5,
	                 unname(tools::md5sum(provenance$native_dll_path)))
	expect_gt(length(provenance$r_layer_file_md5), 0L)
	expect_true(all(grepl("^[[:xdigit:]]{32}$", provenance$r_layer_file_md5)))
	expect_true(provenance$r_layer_kind %in% c("source-files", "installed-lazyload"))
	expect_false(provenance$source_tree)
})

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

test_that("strict sweep enumeration excludes an incompatible non-reusable class without drawing", {
	e = load_sweep_helpers()
	registry = EDI:::inference_class_registry_as_list()
	exact_binomial = registry[["InferenceIncidExactBinomial"]]
	expect_true(isTRUE(exact_binomial$requires_kk_matching_design))

	arms = e$resampling_nondegenerate_arms()
	bernoulli_cases = e$resampling_nondegenerate_cases(
		arms[[1L]], "incidence", NULL,
		registry = list(InferenceIncidExactBinomial = exact_binomial),
		ns = asNamespace("EDI"), strict = TRUE
	)
	expect_length(bernoulli_cases, 0L)

	kk_incidence = e$resampling_nondegenerate_kk_design("incidence")
	kk_cases = e$resampling_nondegenerate_cases(
		arms[[2L]], "incidence", kk_incidence,
		registry = list(InferenceIncidExactBinomial = exact_binomial),
		ns = asNamespace("EDI"), strict = TRUE
	)
	expect_length(kk_cases, 0L)
})

test_that("snapshot validation rejects incomplete manifests and invalid distributions", {
	e = load_sweep_helpers()
	expect_error(e$validate_sweep_snapshot(list(a = 1:15), c("a", "b"), 15L,
	                                       expected_key_count = 2L), "key mismatch.*missing=.*b")
	expect_error(e$validate_sweep_snapshot(list(a = 1:15), c("a", "a"), 15L),
	             "expected manifest has duplicate keys")
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

	# Exercise both extra after.rds names in one comparison: neither may be
	# silently ignored just because the before snapshot's manifest is correct.
	after_extra = structure(list(a = seq_len(15L), b = seq_len(15L), c = seq_len(15L)), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_extra)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "key mismatch.*extra=.*b, c")

	after_na = structure(list(a = c(NA_real_, 2:15)), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_na)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "NA-pattern mismatch for a")

	after_short = structure(list(a = 1:14), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after_short)
	on.exit(pair$cleanup(), add = TRUE)
	expect_error(e$compare(pair$before, pair$after), "must be numeric length 15")
})

test_that("comparison refuses snapshots without the source-derived key manifest", {
	e = load_sweep_helpers()
	for (missing_side in c("before", "after")) {
		before = structure(list(a = seq_len(15L)), expected_keys = "a")
		after = structure(list(a = seq_len(15L)), expected_keys = "a")
		if (identical(missing_side, "before")) attr(before, "expected_keys") = NULL
		if (identical(missing_side, "after")) attr(after, "expected_keys") = NULL
		pair = save_snapshot_pair(e, before, after)
		on.exit(pair$cleanup(), add = TRUE)
		expect_error(e$compare(pair$before, pair$after),
		             "both snapshots must carry their source-derived expected_keys manifest")
	}
})

test_that("comparison refuses snapshots from different native packages", {
	e = load_sweep_helpers()
	before = structure(list(a = seq_len(15L)), expected_keys = "a")
	after = structure(list(a = seq_len(15L)), expected_keys = "a")
	pair = save_snapshot_pair(e, before, after)
	on.exit(pair$cleanup(), add = TRUE)
	after_loaded = readRDS(pair$after)
	provenance = attr(after_loaded, "provenance")
	before_loaded = readRDS(pair$before)
	attr(before_loaded, "provenance") = NULL
	saveRDS(before_loaded, pair$before)
	expect_error(e$compare(pair$before, pair$after),
	             "before snapshot is missing valid EDI package/native/R-source provenance")
	attr(before_loaded, "provenance") = pair$provenance
	saveRDS(before_loaded, pair$before)
	attr(after_loaded, "provenance") = NULL
	saveRDS(after_loaded, pair$after)
	expect_error(e$compare(pair$before, pair$after),
	             "after snapshot is missing valid EDI package/native/R-source provenance")
	attr(after_loaded, "provenance") = pair$provenance

	provenance$native_dll_md5 = "fedcba9876543210fedcba9876543210"
	attr(after_loaded, "provenance") = provenance
	saveRDS(after_loaded, pair$after)
	expect_error(e$compare(pair$before, pair$after), "before/after native EDI DLLs differ")

	provenance$native_dll_md5 = pair$provenance$native_dll_md5
	provenance$package_version = "1.0.4"
	attr(after_loaded, "provenance") = provenance
	saveRDS(after_loaded, pair$after)
	expect_error(e$compare(pair$before, pair$after), "before/after package versions differ")
})

test_that("comparison accepts matched keys and native bits across installed/source R layers", {
	e = load_sweep_helpers()
	keys = c("FakeA|arm|continuous|production", "FakeB|arm|continuous|forced")
	e$RESAMPLING_NONDEGENERATE_EXPECTED_KEY_COUNT = length(keys)
	before = structure(list(seq_len(15L), seq_len(15L)), names = keys, expected_keys = keys)
	after = structure(list(seq_len(15L), seq_len(15L) + 0.25), names = keys, expected_keys = keys)
	pair = save_snapshot_pair(e, before, after)
	on.exit(pair$cleanup(), add = TRUE)

	before_loaded = readRDS(pair$before)
	after_loaded = readRDS(pair$after)
	before_provenance = pair$provenance
	before_provenance$package_path = "/tmp/EDI-installed"
	before_provenance$source_tree = FALSE
	before_provenance$native_dll_path = "/tmp/EDI-installed/libs/EDI.so"
	before_provenance$r_layer_kind = "installed-lazyload"
	before_provenance$r_layer_file_md5 = c("R/lazyload" = "11111111111111111111111111111111")
	after_provenance = before_provenance
	after_provenance$package_path = "/tmp/EDI-checkout/R/EDI"
	after_provenance$source_tree = TRUE
	after_provenance$native_dll_path = "/tmp/EDI-checkout/R/EDI/src/EDI.so"
	after_provenance$r_layer_kind = "source-files"
	after_provenance$r_layer_file_md5 = c("inference.R" = "22222222222222222222222222222222")
	attr(before_loaded, "provenance") = before_provenance
	attr(after_loaded, "provenance") = after_provenance
	saveRDS(before_loaded, pair$before)
	saveRDS(after_loaded, pair$after)

	expect_identical(attr(before_loaded, "expected_keys"), keys)
	expect_identical(attr(after_loaded, "expected_keys"), keys)
	expect_identical(before_provenance$native_dll_md5, after_provenance$native_dll_md5)
	expect_false(identical(before_provenance$r_layer_file_md5, after_provenance$r_layer_file_md5))
	comparison = capture.output(e$compare(pair$before, pair$after))
	expect_true(any(grepl("entries: 2  bit-identical: 1  changed: 1 (fixed: 0, noise: 0, MOVED: 1)",
	                     comparison, fixed = TRUE)))
	expect_true(any(grepl(keys[[2L]], comparison, fixed = TRUE)))
})

test_that("sweep classification does not call an all-NA baseline a cache fix", {
	e = load_sweep_helpers()
	# A finite point mass is direct evidence of a collapsed distribution; an
	# all-NA baseline has no finite evidence and must remain an investigated move.
	expect_identical(e$classify_change(rep(2, 15L), seq_len(15L), 1e-8), "fixed")
	expect_identical(e$classify_change(rep(NA_real_, 15L), seq_len(15L), 1e-8), "MOVED")
})

test_that("sweep snapshots reject empty rosters and invalid replicate counts", {
	e = load_sweep_helpers()
	expect_error(e$validate_sweep_snapshot(list(a = seq_len(15L)), character(), 15L),
	             "expected manifest must contain non-empty character keys")

	for (bad_r in list(0L, -1L, 1.5, NA_real_, c(1L, 2L), "15")) {
		expect_error(e$validate_sweep_snapshot(list(a = seq_len(15L)), "a", bad_r),
		             "r must be one positive integer")
	}
})

test_that("production sweep roster remains the planned 240 unique keys", {
	e = load_sweep_helpers()
	keys = paste0("class-", seq_len(240L), "|arm|continuous|production")
	snapshot = structure(rep(list(seq_len(15L)), length(keys)), names = keys)
	expect_identical(
		e$validate_sweep_snapshot(snapshot, keys, 15L, expected_key_count = 240L),
		snapshot
	)
	expect_error(
		e$validate_sweep_snapshot(snapshot[seq_len(239L)], keys[seq_len(239L)], 15L,
		                          expected_key_count = 240L),
		"expected manifest must contain exactly 240 source-derived keys"
	)
})
