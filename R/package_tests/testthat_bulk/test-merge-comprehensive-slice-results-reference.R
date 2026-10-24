testthat::test_that("slice merge reconciles keys, refuses unsafe inputs, and applies atomically and idempotently", {
	testthat::skip_if_not_installed("data.table")

	find_repo_file <- function(path) {
		at <- normalizePath(getwd())
		repeat {
			candidate <- file.path(at, path)
			if (file.exists(candidate)) return(candidate)
			parent <- dirname(at)
			if (identical(parent, at)) break
			at <- parent
		}
		stop("cannot locate repository file: ", path)
	}
	script <- find_repo_file(file.path("R", "package_tests", "merge_comprehensive_slice_results.R"))
	sha_env <- new.env()
	sys.source(find_repo_file(file.path("R", "package_tests", "comprehensive_run_provenance.R")), envir = sha_env)
	sha256 <- sha_env$comprehensive_sha256_file
	rscript <- file.path(R.home("bin"), "Rscript")

	root <- tempfile("edi-merge-slice-")
	dir.create(root)
	on.exit(unlink(root, recursive = TRUE), add = TRUE)
	canon_dir <- file.path(root, "canon")
	dir.create(canon_dir)
	fake_dll <- file.path(root, "EDI.so")
	writeLines("fake native library", fake_dll)
	other_dll <- file.path(root, "Other.so")
	writeLines("a different native library", other_dll)

	# Mirrors build_result_key()/serialize_beta_T() in comprehensive_tests.R; the
	# script re-derives every id from the runner itself and refuses a mismatch.
	key <- function(rep, beta, dataset, rt, design, cls, fn) {
		paste(as.integer(rep), format(as.numeric(beta), scientific = TRUE, digits = 17), dataset, rt, design, cls, fn, sep = "||")
	}
	make_rows <- function(rep, beta, design, cls, fn, result_1, status = "ok", method_family = "rand") {
		n <- length(rep)
		data.table::data.table(
			rep = as.integer(rep), beta_T = beta, dataset = "pima", response_type = "incidence",
			design = rep_len(design, n), inference_class = rep_len(cls, n), function_run = fn,
			id = key(rep, beta, "pima", "incidence", rep_len(design, n), rep_len(cls, n), fn),
			method_family = rep_len(method_family, n), timestamp = "2026-10-23 10:00:00 IDT",
			result_1 = as.character(result_1), result = as.character(result_1),
			error_message = ifelse(rep_len(status, n) == "error", "boom", NA_character_),
			skip_reason = ifelse(rep_len(status, n) == "error", "error", ""),
			r = 151L, status = rep_len(status, n)
		)
	}
	foo <- "InferenceIncidFoo (model_formula=~1) [design_formula=~1]"
	pval <- "compute_rand_two_sided_pval"
	canonical_rows <- data.table::rbindlist(list(
		make_rows(1, 0, "FixedBlocking", foo, pval, "0.5"),                         # out of scope: design
		make_rows(1, 0, "Bernoulli", "InferenceIncidBar [design_formula=~1]", pval, "0.6"), # out of scope: class
		make_rows(1, 0, "Bernoulli", foo, "compute_estimate", "1.25", method_family = "estimate"), # out of scope: family
		make_rows(1, 0, "Bernoulli", foo, pval, "0.1"),                              # k1: value change
		make_rows(2, 0, "Bernoulli", foo, pval, NA, status = "error"),               # k2: error -> ok
		make_rows(3, 0, "Bernoulli", foo, pval, "0.3"),                              # k3: missing in slice
		make_rows(4, 0, "Bernoulli", foo, pval, "0.4")                               # k4: identical
	))
	# The canonical header order differs from the slice's (function_run first), as in the real files.
	canonical_order <- c("function_run", setdiff(names(canonical_rows), "function_run"))
	canonical <- file.path(canon_dir, "comprehensive_tests_results_nc_1_incidence.csv")
	data.table::fwrite(canonical_rows[, ..canonical_order], canonical, na = "NA")
	canonical_bytes <- readBin(canonical, "raw", file.size(canonical))
	canonical_lines <- readLines(canonical)
	# k7 already lives in a tracked _filtered_ file: it must be replaced there.
	filtered <- file.path(canon_dir, "comprehensive_tests_results_nc_1_incidence_filtered_class-InferenceIncidFoo.csv")
	data.table::fwrite(make_rows(7, 0, "Bernoulli", foo, pval, "0.17"), filtered, na = "NA")
	filtered_bytes <- readBin(filtered, "raw", file.size(filtered))
	# A file named for another response type is not searched (its ids cannot be incidence keys).
	other_type <- file.path(canon_dir, "comprehensive_tests_results_nc_1_count_filtered_class-InferenceIncidFoo.csv")
	data.table::fwrite(make_rows(7, 0, "Bernoulli", foo, pval, "0.99"), other_type, na = "NA")
	baseline <- file.path(canon_dir, "comprehensive_results_audit_baseline.csv")
	writeLines("key,check,response_type,class,formula,function_run,detail", baseline)

	slice_name <- "comprehensive_tests_results_nc_1_incidence_filtered_design-Bernoulli_class-InferenceIncidFoo_family-rand.csv"
	slice_rows <- data.table::rbindlist(list(
		make_rows(1, 0, "Bernoulli", foo, pval, "0.2"),
		make_rows(2, 0, "Bernoulli", foo, pval, "0.7"),
		make_rows(4, 0, "Bernoulli", foo, pval, "0.4"),
		make_rows(5, 0.5, "Bernoulli", foo, pval, "0.05"),
		make_rows(6, 0.5, "Bernoulli", foo, paste0(pval, "(delta=0.5)"), "0.9"),
		make_rows(7, 0, "Bernoulli", foo, pval, "0.27")
	))
	make_slice <- function(rows = slice_rows, receipt = TRUE, dll = fake_dll, mutate_csv = NULL) {
		dir <- tempfile("slice-", tmpdir = root)
		dir.create(dir)
		csv <- file.path(dir, slice_name)
		data.table::fwrite(rows, csv, na = "NA")
		if (!is.null(mutate_csv)) mutate_csv(csv)
		after <- list(edi_dll_sha256 = sha256(dll), edi_dll_path = dll, checkout_head = strrep("a", 40))
		saveRDS(list(schema_version = 2L, results_file = csv,
			command_args = c("1", "1", "incidence", "Bernoulli", "InferenceIncidFoo", "NA", "NA", "NA", "rand"),
			results_file_after = list(exists = TRUE, bytes = file.size(csv), sha256 = sha256(csv)),
			completed_at_utc = "2026-10-23T08:00:00Z", before = after, after = after),
			paste0(csv, ".provenance-20261023T080000.000000-pid1.rds"))
		if (receipt) {
			saveRDS(list(schema = "edi_external_process_receipt", schema_version = 1L, state = "completed",
				exit_status = 0L, pid = 1, started_at_utc = "2026-10-23T07:00:00Z", completed_at_utc = "2026-10-23T08:00:00Z"),
				file.path(dir, "receipt.rds"))
		}
		dir
	}
	run <- function(...) {
		out <- suppressWarnings(system2(rscript, c(shQuote(script), "--canonical-dir", shQuote(canon_dir),
			"--installed-dll", shQuote(fake_dll), ...), stdout = TRUE, stderr = TRUE))
		status <- attr(out, "status")
		list(status = if (is.null(status)) 0L else as.integer(status), out = paste(out, collapse = "\n"))
	}
	latest_report <- function(dir) {
		reports <- sort(list.files(dir, pattern = "^merge_slice_report_.*\\.csv$", full.names = TRUE))
		data.table::fread(reports[length(reports)], colClasses = "character")
	}
	canonical_unchanged <- function() identical(readBin(canonical, "raw", file.size(canonical)), canonical_bytes)

	# Usage errors exit 2.
	testthat::expect_identical(run()$status, 2L)
	slice <- make_slice()
	testthat::expect_identical(run("--slice-dir", shQuote(slice), "--apply", "--allow-no-receipt")$status, 2L)

	# Clean dry run: replace / identical / add / missing-in-slice, status and value changes.
	res <- run("--slice-dir", shQuote(slice))
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_true(canonical_unchanged())
	rep_dt <- latest_report(slice)
	counts <- table(rep_dt$action)
	testthat::expect_identical(as.integer(counts[c("replace", "identical", "add", "missing_in_slice")]), c(3L, 1L, 2L, 1L))
	k7 <- rep_dt[id == key(7, 0, "pima", "incidence", "Bernoulli", foo, pval)]
	testthat::expect_identical(k7$target_file, basename(filtered))
	testthat::expect_match(k7$value_changes, "result_1: 0.17 -> 0.27", fixed = TRUE)
	testthat::expect_identical(unique(rep_dt[action == "add", target_file]), basename(canonical))
	testthat::expect_match(res$out, "1 slice key(s) live only in _filtered_ files", fixed = TRUE)
	testthat::expect_identical(rep_dt[action == "missing_in_slice", id], key(3, 0, "pima", "incidence", "Bernoulli", foo, pval))
	k1 <- rep_dt[id == key(1, 0, "pima", "incidence", "Bernoulli", foo, pval)]
	testthat::expect_match(k1$value_changes, "result_1: 0.1 -> 0.2", fixed = TRUE)
	k2 <- rep_dt[id == key(2, 0, "pima", "incidence", "Bernoulli", foo, pval)]
	testthat::expect_identical(c(k2$canonical_status, k2$slice_status), c("error", "ok"))
	testthat::expect_match(res$out, "error->ok=1", fixed = TRUE)
	testthat::expect_false(any(grepl("InferenceIncidBar|FixedBlocking|compute_estimate", rep_dt$id)))

	# Duplicate slice key: refused, nothing written even with --apply.
	dup <- make_slice(rows = rbind(slice_rows, slice_rows[4]))
	res <- run("--slice-dir", shQuote(dup), "--apply")
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "appear more than once", fixed = TRUE)
	testthat::expect_true(canonical_unchanged())

	# A key living in two searched files is refused.
	twice <- file.path(canon_dir, "comprehensive_tests_results_nc_2_filtered_design-Bernoulli.csv")
	data.table::fwrite(make_rows(7, 0, "Bernoulli", foo, pval, "0.37"), twice, na = "NA")
	res <- run("--slice-dir", shQuote(slice), "--apply")
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "live in more than one results file", fixed = TRUE)
	testthat::expect_true(canonical_unchanged())
	unlink(twice)

	# Schema mismatch: refused with the column diff.
	extra <- data.table::copy(slice_rows)[, extra_col := "x"]
	res <- run("--slice-dir", shQuote(make_slice(rows = extra)), "--apply")
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "only in slice [extra_col]", fixed = TRUE)
	testthat::expect_true(canonical_unchanged())

	# An id that is not the runner's key is refused.
	bad_id <- data.table::copy(slice_rows)[1, id := "not-a-runner-key"]
	res <- run("--slice-dir", shQuote(make_slice(rows = bad_id)))
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "differs from build_result_key", fixed = TRUE)

	# Missing receipt: blocking; --allow-no-receipt downgrades it for a dry run only.
	no_receipt <- make_slice(receipt = FALSE)
	res <- run("--slice-dir", shQuote(no_receipt))
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "no external-process receipt", fixed = TRUE)
	testthat::expect_identical(run("--slice-dir", shQuote(no_receipt), "--allow-no-receipt")$status, 0L)
	testthat::expect_identical(run("--slice-dir", shQuote(no_receipt), "--apply")$status, 1L)
	testthat::expect_true(canonical_unchanged())

	# Sidecar DLL differs from the installed one: both hashes reported.
	res <- run("--slice-dir", shQuote(make_slice(dll = other_dll)))
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, sha256(other_dll), fixed = TRUE)
	testthat::expect_match(res$out, sha256(fake_dll), fixed = TRUE)

	# --expect-keys must equal the slice key set.
	keys_file <- file.path(root, "expect.txt")
	writeLines(slice_rows$id[-6], keys_file)
	res <- run("--slice-dir", shQuote(slice), "--expect-keys", shQuote(keys_file))
	testthat::expect_identical(res$status, 1L)
	testthat::expect_match(res$out, "1 extra", fixed = TRUE)
	writeLines(slice_rows$id, keys_file)
	testthat::expect_identical(run("--slice-dir", shQuote(slice), "--expect-keys", shQuote(keys_file))$status, 0L)

	# --out-dir: merged copies + audit inputs in a separate dir, canonical files untouched.
	testthat::expect_identical(run("--slice-dir", shQuote(slice), "--out-dir", shQuote(root), "--apply")$status, 2L)
	preview <- file.path(root, "preview")
	dir.create(preview)
	res <- run("--slice-dir", shQuote(slice), "--out-dir", shQuote(preview))
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_true(canonical_unchanged())
	testthat::expect_identical(readBin(filtered, "raw", file.size(filtered)), filtered_bytes)
	testthat::expect_setequal(list.files(preview), c(basename(canonical), basename(filtered), basename(baseline)))
	preview_dt <- data.table::fread(file.path(preview, basename(canonical)), colClasses = "character")
	testthat::expect_identical(nrow(preview_dt), nrow(canonical_rows) + 2L)
	testthat::expect_identical(data.table::fread(file.path(preview, basename(filtered)), colClasses = "character")$result_1, "0.27")
	testthat::expect_match(res$out, "audit_comprehensive_results.R --force", fixed = TRUE)
	testthat::expect_identical(run("--slice-dir", shQuote(slice), "--out-dir", shQuote(preview))$status, 2L) # not empty

	# --apply: backup, atomic rewrite, replace in place, append new keys, keep everything else.
	res <- run("--slice-dir", shQuote(slice), "--apply")
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_identical(readBin(file.path(preview, basename(canonical)), "raw", file.size(canonical)), readBin(canonical, "raw", file.size(canonical)))
	backups <- list.files(canon_dir, pattern = "\\.pre_slice_merge_.*\\.bak$", full.names = TRUE)
	testthat::expect_length(backups, 2L)
	canon_backup <- backups[startsWith(basename(backups), basename(canonical))]
	testthat::expect_identical(readBin(canon_backup, "raw", file.size(canon_backup)), canonical_bytes)
	testthat::expect_identical(sort(list.files(canon_dir, all.files = TRUE, no.. = TRUE)),
		sort(c(basename(c(canonical, filtered, other_type, baseline)), basename(backups))))
	testthat::expect_identical(data.table::fread(filtered, colClasses = "character")$result_1, "0.27")
	testthat::expect_identical(data.table::fread(other_type, colClasses = "character")$result_1, "0.99")
	merged_lines <- readLines(canonical)
	testthat::expect_length(merged_lines, length(canonical_lines) + 2L)
	# header, the three out-of-scope rows, the missing-in-slice row and the identical row: byte for byte, same position
	untouched <- c(1L, 2L, 3L, 4L, 7L, 8L)
	testthat::expect_identical(merged_lines[untouched], canonical_lines[untouched])
	merged <- data.table::fread(canonical, colClasses = "character")
	testthat::expect_identical(names(merged), canonical_order)
	testthat::expect_identical(merged$id[seq_len(nrow(canonical_rows))], canonical_rows$id)
	testthat::expect_identical(merged$id[nrow(canonical_rows) + 1:2], slice_rows$id[4:5])
	testthat::expect_identical(merged[id == k1$id, result_1], "0.2")
	testthat::expect_identical(merged[id == k2$id, status], "ok")

	# A second --apply is a no-op: no rewrite, no new backup.
	after_first <- readBin(canonical, "raw", file.size(canonical))
	res <- run("--slice-dir", shQuote(slice), "--apply")
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, "nothing to change", fixed = TRUE)
	testthat::expect_identical(readBin(canonical, "raw", file.size(canonical)), after_first)
	testthat::expect_length(list.files(canon_dir, pattern = "\\.bak$"), 2L)
	rep_dt <- latest_report(slice)
	testthat::expect_identical(sort(unique(rep_dt$action)), c("identical", "missing_in_slice"))
})
