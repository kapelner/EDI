# merge_comprehensive_slice_results.R options for slices that straddle reinstalls
# (path-audit gap regeneration, 2026-11-12 batch): --accept-same-source-dlls,
# --installed-build-head, --accept-code-change-in, the --legacy-no-provenance exit
# waiver, and backup names for target files near the 255-byte name limit.
testthat::test_that("same-source DLL acceptance checks git, and the legacy exit waiver stays narrow", {
	testthat::skip_if_not_installed("data.table")
	testthat::skip_if(!nzchar(Sys.which("git")), "git not available")

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

	root <- tempfile("edi-merge-same-source-")
	dir.create(root)
	on.exit(unlink(root, recursive = TRUE), add = TRUE)
	canon_dir <- file.path(root, "canon")
	dir.create(canon_dir)
	dll_a <- file.path(root, "A.so"); writeLines("build A", dll_a)
	dll_b <- file.path(root, "B.so"); writeLines("build B", dll_b)
	dll_c <- file.path(root, "C.so"); writeLines("build C", dll_c)
	sa <- sha256(dll_a); sb <- sha256(dll_b); sc <- sha256(dll_c)

	# A throwaway checkout: c1 -> c2 changes only a comment and a test file -> c3
	# changes one code line in R/EDI/R/registry.R.
	repo <- file.path(root, "repo")
	dir.create(file.path(repo, "R", "EDI", "R"), recursive = TRUE)
	dir.create(file.path(repo, "R", "EDI", "tests"), recursive = TRUE)
	git <- function(...) {
		out <- suppressWarnings(system2("git", c("-C", shQuote(repo), ...), stdout = TRUE, stderr = TRUE))
		if (!is.null(attr(out, "status"))) stop("git ", paste(c(...), collapse = " "), " failed: ", paste(out, collapse = "\n"))
		out
	}
	commit <- function(msg) {
		git("add", "-A")
		git("-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", msg)
		git("rev-parse", "HEAD")[1L]
	}
	git("init", "-q")
	writeLines(c("# helper", "f = function(x) x + 1"), file.path(repo, "R", "EDI", "R", "a.R"))
	writeLines("excluded = c('x')", file.path(repo, "R", "EDI", "R", "registry.R"))
	writeLines("test_that('t', {})", file.path(repo, "R", "EDI", "tests", "t.R"))
	c1 <- commit("c1")
	writeLines(c("# helper, reworded", "f = function(x) x + 1", ""), file.path(repo, "R", "EDI", "R", "a.R"))
	writeLines("test_that('t2', {})", file.path(repo, "R", "EDI", "tests", "t.R"))
	c2 <- commit("c2")
	writeLines("excluded = c('x', 'y')", file.path(repo, "R", "EDI", "R", "registry.R"))
	c3 <- commit("c3")

	key <- function(rep, beta, dataset, rt, design, cls, fn) {
		paste(as.integer(rep), format(as.numeric(beta), scientific = TRUE, digits = 17), dataset, rt, design, cls, fn, sep = "||")
	}
	foo <- "InferenceIncidFoo (model_formula=~1) [design_formula=~1]"
	pval <- "compute_rand_two_sided_pval"
	make_rows <- function(rep, result_1) {
		n <- length(rep)
		data.table::data.table(
			rep = as.integer(rep), beta_T = 0, dataset = "pima", response_type = "incidence",
			design = "Bernoulli", inference_class = foo, function_run = pval,
			id = key(rep, 0, "pima", "incidence", "Bernoulli", foo, pval),
			method_family = "rand", timestamp = "2026-11-12 10:00:00 IST",
			result_1 = as.character(result_1), result = as.character(result_1),
			error_message = NA_character_, skip_reason = "", r = 151L, status = "ok"
		)
	}
	canonical <- file.path(canon_dir, "comprehensive_tests_results_nc_1_incidence.csv")
	data.table::fwrite(make_rows(1:2, c("0.1", "0.2")), canonical, na = "NA")
	canonical_bytes <- readBin(canonical, "raw", file.size(canonical))
	canonical_unchanged <- function() identical(readBin(canonical, "raw", file.size(canonical)), canonical_bytes)
	writeLines("key,check,response_type,class,formula,function_run,detail", file.path(canon_dir, "comprehensive_results_audit_baseline.csv"))

	slice_name <- "comprehensive_tests_results_nc_1_incidence_filtered_design-Bernoulli_class-InferenceIncidFoo_family-rand.csv"
	state <- function(dll, head, porcelain = character()) {
		list(edi_dll_sha256 = sha256(dll), edi_dll_path = dll, checkout_head = head, checkout_path = repo,
			checkout_status_porcelain = porcelain)
	}
	make_slice <- function(before = state(dll_a, c1), after = before, sidecar = TRUE, exit_status = 0L, stderr_lines = NULL) {
		dir <- tempfile("slice-", tmpdir = root)
		dir.create(dir)
		csv <- file.path(dir, slice_name)
		data.table::fwrite(make_rows(c(1L, 3L), c("0.15", "0.3")), csv, na = "NA")
		if (sidecar) {
			saveRDS(list(schema_version = 2L, results_file = csv,
				command_args = c("1", "1", "incidence", "Bernoulli", "InferenceIncidFoo", "NA", "NA", "NA", "rand"),
				results_file_after = list(exists = TRUE, bytes = file.size(csv), sha256 = sha256(csv)),
				completed_at_utc = "2026-11-12T08:00:00Z", before = before, after = after),
				paste0(csv, ".provenance-20261112T080000.000000-pid1.rds"))
		}
		receipt <- list(schema = "edi_external_process_receipt", schema_version = 1L, state = "completed",
			exit_status = exit_status, pid = 1, started_at_utc = "2026-11-12T07:00:00Z", completed_at_utc = "2026-11-12T08:00:00Z")
		if (!is.null(stderr_lines)) {
			err <- file.path(dir, "err.log")
			writeLines(stderr_lines, err)
			receipt$stderr <- list(path = err, bytes = file.size(err), sha256 = sha256(err))
		}
		saveRDS(receipt, file.path(dir, "receipt.json"))
		dir
	}
	run <- function(slice, ..., installed = dll_a) {
		report <- tempfile("report-", tmpdir = root)
		dir.create(report)
		out <- suppressWarnings(system2(rscript, c(shQuote(script), "--canonical-dir", shQuote(canon_dir),
			"--installed-dll", shQuote(installed), "--slice-dir", shQuote(slice), "--report-dir", shQuote(report), ...),
			stdout = TRUE, stderr = TRUE))
		status <- attr(out, "status")
		list(status = if (is.null(status)) 0L else as.integer(status), out = paste(out, collapse = "\n"))
	}
	ok_list <- paste(sa, sb, sep = ",")

	# Usage errors exit 2: bad hex, and the two helper options without the list.
	plain <- make_slice()
	testthat::expect_identical(run(plain, "--accept-same-source-dlls", "nothex")$status, 2L)
	testthat::expect_identical(run(plain, "--installed-build-head", c1)$status, 2L)
	testthat::expect_identical(run(plain, "--accept-code-change-in", "R/EDI/R/registry.R")$status, 2L)

	# Sidecar build A, installed build B: blocked without the list ...
	res <- run(plain, installed = dll_b)
	testthat::expect_identical(res$status, 1L, info = res$out)
	testthat::expect_match(res$out, "differs from the installed", fixed = TRUE)
	# ... and with a list that names only one of the two builds.
	res <- run(plain, "--accept-same-source-dlls", sa, "--installed-build-head", c2, installed = dll_b)
	testthat::expect_identical(res$status, 1L, info = res$out)

	# Both listed, installed head c2: only comment/blank/test lines changed, so it passes.
	res <- run(plain, "--accept-same-source-dlls", ok_list, "--installed-build-head", c2, installed = dll_b)
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, "accepted by --accept-same-source-dlls", fixed = TRUE)
	testthat::expect_match(res$out, paste0("same-source check: heads ", substr(c1, 1, 8), ", ", substr(c2, 1, 8)), fixed = TRUE)

	# A DLL that changed during the run is accepted the same way.
	straddle <- make_slice(before = state(dll_a, c1), after = state(dll_b, c2))
	testthat::expect_identical(run(straddle, installed = dll_b)$status, 1L)
	res <- run(straddle, "--accept-same-source-dlls", ok_list, "--installed-build-head", c2, installed = dll_b)
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, "DLL changed during the run", fixed = TRUE)

	# Installed head c3 adds a real code line: blocked, naming the file ...
	res <- run(plain, "--accept-same-source-dlls", ok_list, "--installed-build-head", c3, installed = dll_b)
	testthat::expect_identical(res$status, 1L, info = res$out)
	testthat::expect_match(res$out, "R/EDI code differs between", fixed = TRUE)
	testthat::expect_match(res$out, "R/EDI/R/registry.R", fixed = TRUE)
	# ... unless the owner accepts that file as irrelevant; the line is still reported.
	res <- run(plain, "--accept-same-source-dlls", ok_list, "--installed-build-head", c3,
		"--accept-code-change-in", "R/EDI/R/registry.R", installed = dll_b)
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, "code change accepted as irrelevant to this slice", fixed = TRUE)
	testthat::expect_match(res$out, "excluded = c('x', 'y')", fixed = TRUE)
	# Accepting a different file does not cover it.
	res <- run(plain, "--accept-same-source-dlls", ok_list, "--installed-build-head", c3,
		"--accept-code-change-in", "R/EDI/R/a.R", installed = dll_b)
	testthat::expect_identical(res$status, 1L, info = res$out)
	# A commit that does not resolve is blocking.
	res <- run(plain, "--accept-same-source-dlls", ok_list, "--installed-build-head", strrep("0", 40), installed = dll_b)
	testthat::expect_identical(res$status, 1L, info = res$out)
	testthat::expect_match(res$out, "cannot resolve the installed build's commit", fixed = TRUE)

	# Uncommitted R/EDI code at run time is warned about, not silently passed.
	dirty <- make_slice(before = state(dll_a, c1, porcelain = c(" M R/EDI/R/a.R", " M R/EDI/tests/t.R")))
	res <- run(dirty, "--accept-same-source-dlls", ok_list, "--installed-build-head", c2, installed = dll_b)
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, paste0("content not checkable: ", substr(c1, 1, 8), ":R/EDI/R/a.R"), fixed = TRUE)
	testthat::expect_false(grepl("R/EDI/tests/t.R", res$out, fixed = TRUE))
	testthat::expect_true(canonical_unchanged())

	# --legacy-no-provenance accepts a non-zero exit only when there is no sidecar and the
	# runner finished, then failed solely on hashing its missing provenance file.
	reason <- shQuote("every other slice in the batch has the same build")
	tail_ok <- c("row 1", "All tests complete!", "Error in f(): cannot hash a missing comprehensive-run provenance file: x.rds")
	legacy <- make_slice(sidecar = FALSE, exit_status = 1L, stderr_lines = tail_ok)
	testthat::expect_identical(run(legacy)$status, 1L)
	res <- run(legacy, "--legacy-no-provenance", reason)
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_match(res$out, "failed hashing its missing provenance sidecar", fixed = TRUE)
	not_done <- make_slice(sidecar = FALSE, exit_status = 1L, stderr_lines = tail_ok[-2])
	testthat::expect_identical(run(not_done, "--legacy-no-provenance", reason)$status, 1L)
	other_error <- make_slice(sidecar = FALSE, exit_status = 1L, stderr_lines = c(tail_ok, "Error: something else"))
	testthat::expect_identical(run(other_error, "--legacy-no-provenance", reason)$status, 1L)
	error_before <- make_slice(sidecar = FALSE, exit_status = 1L, stderr_lines = c("Error: early", tail_ok))
	testthat::expect_identical(run(error_before, "--legacy-no-provenance", reason)$status, 1L)
	with_sidecar <- make_slice(exit_status = 1L, stderr_lines = tail_ok)
	testthat::expect_identical(run(with_sidecar, "--legacy-no-provenance", reason)$status, 1L)
	testthat::expect_true(canonical_unchanged())

	# A target file whose backup name would pass the 255-byte limit gets a shortened,
	# hash-tagged backup, and the apply succeeds.
	long_name <- paste0("comprehensive_tests_results_nc_1_incidence_filtered_class-",
		paste(rep("InferenceIncidFoo", 9L), collapse = "_"), ".csv")
	testthat::expect_gt(nchar(paste0(long_name, ".pre_slice_merge_20261112T080000Z.bak")), 250L)
	testthat::expect_lt(nchar(long_name), 256L)
	long_target <- file.path(canon_dir, long_name)
	data.table::fwrite(make_rows(3L, "0.03"), long_target, na = "NA")
	res <- run(plain, "--apply")
	testthat::expect_identical(res$status, 0L, info = res$out)
	testthat::expect_identical(data.table::fread(long_target, colClasses = "character")$result_1, "0.3")
	backups <- list.files(canon_dir, pattern = "\\.pre_slice_merge_.*\\.bak$")
	long_backup <- backups[startsWith(backups, substr(long_name, 1L, 160L))]
	testthat::expect_length(long_backup, 1L)
	testthat::expect_match(long_backup, "^.{160}~[0-9a-f]{12}\\.pre_slice_merge_")
	testthat::expect_lte(nchar(long_backup, type = "bytes"), 255L)
	merged <- data.table::fread(canonical, colClasses = "character")
	testthat::expect_identical(merged$result_1, c("0.15", "0.2"))
})
