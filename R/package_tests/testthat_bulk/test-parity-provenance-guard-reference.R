library(testthat)
library(EDI)

test_that("TODO-58 parity comparison checks recorded provenance when files remain", {
  script = file.path("..", "..", "benchmark", "benchmark_todo58_public_bootstrap_ci.R")
  expect_true(file.exists(script))
  script_lines = readLines(script)
  expect_true(any(grepl("benchmark_script_path = benchmark_provenance\\$script_path", script_lines)))
  expect_true(any(grepl("write_todo58_benchmark_sidecar(output_path, benchmark_sidecar)",
                        script_lines, fixed = TRUE)))
  expect_true(any(grepl("sidecar_path <- if (identical(mode, \"benchmark\"))",
                        script_lines, fixed = TRUE)))
  expressions = parse(script)
  assignment = function(name) {
    matches = Filter(function(expr) {
      is.call(expr) &&
        (identical(expr[[1L]], as.name("<-")) || identical(expr[[1L]], as.name("="))) &&
        identical(expr[[2L]], as.name(name))
    }, expressions)
    expect_length(matches, 1L)
    matches[[1L]]
  }
  helper_env = new.env(parent = globalenv())
  eval(assignment("sha256_file"), envir = helper_env)
  eval(assignment("todo58_case_manifest"), envir = helper_env)
  eval(assignment("todo58_case_keys"), envir = helper_env)
  eval(assignment("validate_parity_provenance"), envir = helper_env)
  eval(assignment("validate_todo58_environment_provenance"), envir = helper_env)
  eval(assignment("capture_todo58_environment_provenance"), envir = helper_env)
  eval(assignment("validate_todo58_parity_artifact"), envir = helper_env)
  eval(assignment("capture_todo58_benchmark_provenance"), envir = helper_env)
  eval(assignment("todo58_provenance_sidecar_path"), envir = helper_env)
  eval(assignment("capture_todo58_namespace_r_fingerprint"), envir = helper_env)
  eval(assignment("capture_todo58_checkout_identity"), envir = helper_env)
  eval(assignment("capture_todo58_host_state"), envir = helper_env)
  eval(assignment("capture_todo58_thread_settings"), envir = helper_env)
  eval(assignment("validate_todo58_benchmark_sidecar"), envir = helper_env)
  eval(assignment("write_todo58_benchmark_sidecar"), envir = helper_env)

  runtime_provenance = helper_env$capture_todo58_environment_provenance(
    boot_version = "1.3.32", survival_version = "3.8-3",
    host_info = c(sysname = "SyntheticOS", release = "test-release", machine = "test-arch"),
    r_platform = "test-platform",
    software_versions = c(BLAS = "SyntheticBLAS 1.0")
  )

  scratch = tempfile("edi-todo58-parity-provenance-")
  dir.create(scratch)
  on.exit(unlink(scratch, recursive = TRUE), add = TRUE)

  namespace_path = file.path(scratch, "installed-EDI")
  r_path = file.path(namespace_path, "R")
  dir.create(file.path(r_path, "nested"), recursive = TRUE)
  writeBin(as.raw(c(1L, 2L, 3L)), file.path(r_path, "EDI.rdb"))
  writeBin(as.raw(c(4L, 5L)), file.path(r_path, "EDI.rdx"))
  writeLines("helper payload", file.path(r_path, "nested", "helper.rds"))
  r_fingerprint = helper_env$capture_todo58_namespace_r_fingerprint(namespace_path)
  expect_identical(r_fingerprint$file_count, 3L)
  expect_identical(
    vapply(strsplit(r_fingerprint$files, "\t", fixed = TRUE), `[[`, character(1L), 1L),
    c("EDI.rdb", "EDI.rdx", "nested/helper.rds")
  )
  expect_match(r_fingerprint$manifest_sha256, "^[[:xdigit:]]{64}$")
  original_r_hash = r_fingerprint$manifest_sha256
  writeBin(as.raw(c(1L, 2L, 9L)), file.path(r_path, "EDI.rdb"))
  changed_r_fingerprint = helper_env$capture_todo58_namespace_r_fingerprint(namespace_path)
  expect_false(identical(changed_r_fingerprint$manifest_sha256, original_r_hash))
  expect_error(
    helper_env$capture_todo58_namespace_r_fingerprint(file.path(scratch, "missing-package")),
    "loaded namespace path is unavailable"
  )
  loaded_namespace = helper_env$capture_todo58_namespace_r_fingerprint(
    getNamespaceInfo(asNamespace("EDI"), "path")
  )
  expect_identical(
    loaded_namespace$namespace_path,
    normalizePath(getNamespaceInfo(asNamespace("EDI"), "path"), winslash = "/", mustWork = TRUE)
  )
  expect_true(loaded_namespace$file_count > 0L)
  expect_match(loaded_namespace$manifest_sha256, "^[[:xdigit:]]{64}$")
  empty_namespace = file.path(scratch, "empty-EDI")
  dir.create(file.path(empty_namespace, "R"), recursive = TRUE)
  expect_error(helper_env$capture_todo58_namespace_r_fingerprint(empty_namespace), "R payload is empty")

  host = helper_env$capture_todo58_host_state(
    loadavg_lines = "2.50 2.00 1.50 2/100 1234",
    status_lines = c("Name:\tr", "Cpus_allowed_list:\t0-3")
  )
  expect_identical(host$load_average, "2.50 2.00 1.50 2/100 1234")
  expect_identical(host$cpu_affinity, "0-3")
  thread_names = c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "BLAS_NUM_THREADS",
                   "VECLIB_MAXIMUM_THREADS", "NUMEXPR_NUM_THREADS", "R_DATATABLE_NUM_THREADS",
                   "RCPP_PARALLEL_NUM_THREADS")
  thread_values = setNames(rep("1", length(thread_names)), thread_names)
  thread_settings = helper_env$capture_todo58_thread_settings(thread_values)
  expect_identical(names(thread_settings), thread_names)
  expect_true(all(vapply(thread_settings, identical, logical(1L), "1")))
  expect_error(helper_env$capture_todo58_thread_settings(thread_values[-1L]), "name every supported")

  checkout = file.path(scratch, "checkout")
  dir.create(checkout)
  git_prefix = c("-C", shQuote(checkout))
  expect_identical(system2("git", c(git_prefix, "init", "--quiet")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.email", "test@example.invalid")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.name", "EDI test")), 0L)
  tracked = file.path(checkout, "tracked.txt")
  writeLines("baseline", tracked)
  expect_identical(system2("git", c(git_prefix, "add", "tracked.txt")), 0L)
  expect_identical(system2("git", c(git_prefix, "commit", "--quiet", "-m", "baseline")), 0L)
  clean_checkout = helper_env$capture_todo58_checkout_identity(checkout)
  expect_match(clean_checkout$head, "^[[:xdigit:]]{40}([[:xdigit:]]{24})?$")
  expect_identical(clean_checkout$status, "<clean>")
  expect_match(clean_checkout$tracked_diff_sha256, "^[[:xdigit:]]{64}$")
  expect_match(clean_checkout$untracked_content_sha256, "^[[:xdigit:]]{64}$")
  writeLines("changed", tracked)
  dirty_checkout = helper_env$capture_todo58_checkout_identity(checkout)
  expect_match(dirty_checkout$status, "M tracked[.]txt")
  expect_false(identical(dirty_checkout$tracked_diff_sha256, clean_checkout$tracked_diff_sha256))
  expect_error(
    helper_env$capture_todo58_checkout_identity(checkout, git_command = "/no/such/git-command"),
    "could not capture checkout identity from Git"
  )

  benchmark_output = file.path(scratch, "benchmark.csv")
  writeLines("result rows", benchmark_output)
  sidecar = list(
    started_at_utc = "2026-10-20T10:00:00Z", finished_at_utc = "2026-10-20T10:01:00Z",
    host_start = host, host_finish = host, thread_settings = thread_settings,
    checkout = dirty_checkout, namespace_r_payload = changed_r_fingerprint
  )
  sidecar_path = helper_env$write_todo58_benchmark_sidecar(benchmark_output, sidecar)
  expect_identical(sidecar_path, paste0(benchmark_output, ".provenance.rds"))
  saved_sidecar = readRDS(sidecar_path)
  expect_identical(saved_sidecar$output_csv_path, normalizePath(benchmark_output, winslash = "/"))
  expect_identical(saved_sidecar$output_csv_sha256, helper_env$sha256_file(benchmark_output))
  expect_identical(saved_sidecar$namespace_r_payload$manifest_sha256,
                   changed_r_fingerprint$manifest_sha256)
  expect_error(helper_env$write_todo58_benchmark_sidecar(benchmark_output, sidecar), "Refusing to overwrite")
  missing_thread_sidecar = saved_sidecar
  missing_thread_sidecar$thread_settings = NULL
  expect_error(helper_env$validate_todo58_benchmark_sidecar(missing_thread_sidecar),
               "missing thread settings")

  make_package = function(version) {
    path = file.path(scratch, paste0("EDI-", version))
    dir.create(path)
    writeLines(c("Package: EDI", paste0("Version: ", version)), file.path(path, "DESCRIPTION"))
    path
  }
  make_artifact = function(version, package_path, dll_path) {
    manifest = helper_env$todo58_case_manifest()
    cases = lapply(manifest, function(spec) {
      distribution = rep(0.1, spec$B)
      # Exercise a non-identical but in-tolerance fixed-seed comparison.
      if (identical(version, "1.0.2")) distribution[[1L]] = distribution[[1L]] + 5e-11
      c(spec, list(distribution = distribution))
    })
    c(list(package_version = version, package_path = package_path,
          edi_dll_path = dll_path, edi_dll_sha256 = helper_env$sha256_file(dll_path),
          r_version = "R test version", script_path = normalizePath(script),
          script_sha256 = helper_env$sha256_file(script),
          case_keys = helper_env$todo58_case_keys(),
          cases = cases),
      runtime_provenance)
  }
  old_package = make_package("1.0.2")
  current_package = make_package("1.0.3")
  old_dll = file.path(scratch, "old-EDI.so")
  current_dll = file.path(scratch, "current-EDI.so")
  writeBin(charToRaw("old native library"), old_dll)
  writeBin(charToRaw("current native library"), current_dll)
  old_rds = file.path(scratch, "old.rds")
  current_rds = file.path(scratch, "current.rds")
  saveRDS(make_artifact("1.0.2", old_package, old_dll), old_rds)
  saveRDS(make_artifact("1.0.3", current_package, current_dll), current_rds)

  benchmark_keys = helper_env$todo58_case_keys()
  captured = helper_env$capture_todo58_benchmark_provenance(
    readRDS(current_rds), benchmark_keys, script_path = script, r_version = "R test version",
    runtime_provenance = runtime_provenance
  )
  expect_identical(captured$case_keys, benchmark_keys)
  expect_identical(captured$package_version, "1.0.3")
  expect_match(captured$script_sha256, "^[[:xdigit:]]{64}$")
  expect_identical(captured$boot_package_version, "1.3.32")
  expect_identical(captured$survival_package_version, "3.8-3")
  expect_identical(captured$host_sysname, "SyntheticOS")
  expect_identical(captured$host_release, "test-release")
  expect_identical(captured$host_machine, "test-arch")
  expect_identical(captured$r_platform, "test-platform")
  expect_identical(captured$blas_identity, "SyntheticBLAS 1.0")
  expect_error(
    helper_env$validate_todo58_environment_provenance(
      runtime_provenance[setdiff(names(runtime_provenance), "blas_identity")], "synthetic artifact"
    ),
    "missing boot/survival, host, or BLAS provenance"
  )
  expect_error(
    helper_env$capture_todo58_benchmark_provenance(
      readRDS(current_rds), benchmark_keys[-1L], script_path = script, r_version = "R test version"
    ),
    "fixtures, B, or seeds"
  )
  missing_dll_artifact = readRDS(current_rds)
  missing_dll_artifact$edi_dll_path = file.path(scratch, "missing-EDI.so")
  expect_error(
    helper_env$capture_todo58_benchmark_provenance(
      missing_dll_artifact, benchmark_keys, script_path = script, r_version = "R test version"
    ),
    "requires an existing installed EDI package and native DLL"
  )

  rscript = file.path(R.home("bin"), "Rscript")
  run_compare = function(old_path = old_rds, current_path = current_rds) {
    output = suppressWarnings(system2(rscript,
      args = c(shQuote(script), "compare-parity", shQuote(old_path), shQuote(current_path)),
      stdout = TRUE, stderr = TRUE))
    list(output = output, status = attr(output, "status"))
  }
  valid = run_compare()
  expect_null(valid$status)
  expect_match(paste(valid$output, collapse = "\n"), "max_abs_diff")
  wrong_baseline_version_package = make_package("1.0.1")
  wrong_baseline_version = readRDS(old_rds)
  wrong_baseline_version$package_version = "1.0.1"
  wrong_baseline_version$package_path = wrong_baseline_version_package
  wrong_baseline_version_rds = file.path(scratch, "wrong-baseline-version.rds")
  saveRDS(wrong_baseline_version, wrong_baseline_version_rds)
  wrong_baseline = run_compare(old_path = wrong_baseline_version_rds)
  expect_identical(as.integer(wrong_baseline$status), 1L)
  expect_match(paste(wrong_baseline$output, collapse = "\n"),
               "The first parity artifact must come from installed EDI 1[.]0[.]2")
  old_distributions = lapply(readRDS(old_rds)$cases, `[[`, "distribution")
  current_distributions = lapply(readRDS(current_rds)$cases, `[[`, "distribution")
  fixture_diffs = vapply(seq_along(old_distributions), function(i) {
    max(abs(old_distributions[[i]] - current_distributions[[i]]))
  }, numeric(1L))
  expect_true(all(fixture_diffs > 0 & fixture_diffs <= 1e-10))

  over_tolerance_artifact = readRDS(current_rds)
  over_tolerance_artifact$cases[[1L]]$distribution[[1L]] =
    old_distributions[[1L]][[1L]] + 2e-10
  over_tolerance_rds = file.path(scratch, "over-tolerance.rds")
  saveRDS(over_tolerance_artifact, over_tolerance_rds)
  over_tolerance = run_compare(current_path = over_tolerance_rds)
  expect_identical(as.integer(over_tolerance$status), 1L)
  expect_match(paste(over_tolerance$output, collapse = "\n"),
               "Fixed-seed distribution parity failed the 1e-10 TODO-3 tolerance")

  finite_mask_artifact = readRDS(current_rds)
  finite_mask_artifact$cases[[1L]]$distribution[[1L]] = NA_real_
  finite_mask_rds = file.path(scratch, "finite-mask-mismatch.rds")
  saveRDS(finite_mask_artifact, finite_mask_rds)
  finite_mask_mismatch = run_compare(current_path = finite_mask_rds)
  expect_identical(as.integer(finite_mask_mismatch$status), 1L)
  expect_match(paste(finite_mask_mismatch$output, collapse = "\n"),
               "Distribution length or finite-value pattern differs")

  missing_script_provenance_artifact = readRDS(old_rds)
  missing_script_provenance_artifact$script_sha256 = NULL
  missing_script_provenance_rds = file.path(scratch, "missing-script-provenance.rds")
  saveRDS(missing_script_provenance_artifact, missing_script_provenance_rds)
  missing_script_provenance = run_compare(missing_script_provenance_rds)
  expect_identical(as.integer(missing_script_provenance$status), 1L)
  expect_match(paste(missing_script_provenance$output, collapse = "\n"), "missing valid R/script provenance")

  wrong_manifest = "OLS|1000|1000|different-fixture-seed|414230"
  wrong_keys_artifact = readRDS(old_rds)
  wrong_keys_artifact$case_keys[[1L]] = wrong_manifest
  wrong_keys_rds = file.path(scratch, "wrong-case-manifest.rds")
  saveRDS(wrong_keys_artifact, wrong_keys_rds)
  wrong_current_artifact = readRDS(current_rds)
  wrong_current_artifact$case_keys[[1L]] = wrong_manifest
  wrong_current_rds = file.path(scratch, "wrong-current-case-manifest.rds")
  saveRDS(wrong_current_artifact, wrong_current_rds)
  wrong_matching_keys = run_compare(wrong_keys_rds, wrong_current_rds)
  expect_identical(as.integer(wrong_matching_keys$status), 1L)
  expect_match(paste(wrong_matching_keys$output, collapse = "\n"), "case keys do not match the accepted TODO-58 manifest")

  missing_case_artifact = readRDS(old_rds)
  missing_case_artifact$cases = missing_case_artifact$cases[-3L]
  missing_case_rds = file.path(scratch, "missing-case.rds")
  saveRDS(missing_case_artifact, missing_case_rds)
  missing_case = run_compare(missing_case_rds)
  expect_identical(as.integer(missing_case$status), 1L)
  expect_match(paste(missing_case$output, collapse = "\n"), "must contain exactly 3 case records")

  short_distribution_artifact = readRDS(old_rds)
  short_distribution_artifact$cases[[1L]]$distribution = head(
    short_distribution_artifact$cases[[1L]]$distribution, -1L
  )
  short_distribution_rds = file.path(scratch, "short-distribution.rds")
  saveRDS(short_distribution_artifact, short_distribution_rds)
  short_distribution = run_compare(short_distribution_rds)
  expect_identical(as.integer(short_distribution$status), 1L)
  expect_match(paste(short_distribution$output, collapse = "\n"), "case record does not match the accepted manifest")

  directory_dll = file.path(scratch, "directory-instead-of-dll")
  dir.create(directory_dll)
  directory_artifact = readRDS(old_rds)
  directory_artifact$edi_dll_path = directory_dll
  directory_rds = file.path(scratch, "directory-dll.rds")
  saveRDS(directory_artifact, directory_rds)
  directory_dll_result = run_compare(directory_rds)
  expect_identical(as.integer(directory_dll_result$status), 1L)
  expect_match(paste(directory_dll_result$output, collapse = "\n"), "DLL path is a directory")

  package_file = file.path(scratch, "not-a-package-directory")
  writeLines("not a package directory", package_file)
  file_package_artifact = readRDS(old_rds)
  file_package_artifact$package_path = package_file
  file_package_rds = file.path(scratch, "file-package.rds")
  saveRDS(file_package_artifact, file_package_rds)
  file_package_result = run_compare(file_package_rds)
  expect_identical(as.integer(file_package_result$status), 1L)
  expect_match(paste(file_package_result$output, collapse = "\n"), "package path is not a directory")

  writeBin(charToRaw("tampered old native library"), old_dll)
  tampered_dll = run_compare()
  expect_identical(as.integer(tampered_dll$status), 1L)
  expect_match(paste(tampered_dll$output, collapse = "\n"), "DLL SHA-256 does not match")

  writeLines(c("Package: EDI", "Version: 9.9.9"), file.path(old_package, "DESCRIPTION"))
  tampered_package = run_compare()
  expect_identical(as.integer(tampered_package$status), 1L)
  expect_match(paste(tampered_package$output, collapse = "\n"), "package version does not match")
})
