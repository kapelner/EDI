library(testthat)
library(EDI)

test_that("design benchmark provenance distinguishes clean and failed Git status", {
  benchmark_script = file.path("..", "..", "benchmark", "benchmark_design_construction.R")
  expect_true(file.exists(benchmark_script))
  expressions = parse(benchmark_script)
  definition = function(name) {
    matches = Filter(function(expr) {
      is.call(expr) && identical(expr[[1L]], as.name("=")) &&
        identical(expr[[2L]], as.name(name))
    }, expressions)
    expect_length(matches, 1L)
    matches[[1L]]
  }
  helper_env = new.env(parent = globalenv())
  eval(definition("sha256_file"), envir = helper_env)
  eval(definition("read_benchmark_r_layer_state"), envir = helper_env)
  eval(definition("read_benchmark_git_state"), envir = helper_env)

  installed_package = tempfile("edi-todo59-installed-package-")
  r_dir = file.path(installed_package, "R")
  dir.create(r_dir, recursive = TRUE)
  writeBin(as.raw(c(1L, 2L, 3L)), file.path(r_dir, "EDI.rdb"))
  writeBin(as.raw(c(4L, 5L)), file.path(r_dir, "EDI.rdx"))
  nested_dir = file.path(r_dir, "nested")
  dir.create(nested_dir)
  writeLines("namespace companion", file.path(nested_dir, "helper.rds"))

  r_layer = helper_env$read_benchmark_r_layer_state(installed_package)
  expect_identical(r_layer$path, normalizePath(r_dir, winslash = "/"))
  expect_identical(r_layer$file_count, 3L)
  expect_identical(vapply(strsplit(r_layer$files, "\t", fixed = TRUE), `[[`, character(1L), 1L),
                   c("EDI.rdb", "EDI.rdx", "nested/helper.rds"))
  expect_true(all(grepl("^[[:xdigit:]]{64}$", vapply(
    strsplit(r_layer$files, "\t", fixed = TRUE), `[[`, character(1L), 2L
  ))))
  expect_match(r_layer$manifest_sha256, "^[[:xdigit:]]{64}$")
  writeBin(as.raw(c(1L, 2L, 9L)), file.path(r_dir, "EDI.rdb"))
  changed_r_layer = helper_env$read_benchmark_r_layer_state(installed_package)
  expect_false(identical(changed_r_layer$manifest_sha256, r_layer$manifest_sha256))
  expect_identical(helper_env$read_benchmark_r_layer_state(tempfile())$manifest_sha256,
                   "<unavailable>")
  empty_package = tempfile("edi-todo59-empty-package-")
  dir.create(file.path(empty_package, "R"), recursive = TRUE)
  expect_identical(helper_env$read_benchmark_r_layer_state(empty_package)$manifest_sha256,
                   "<unavailable>")

  repo = tempfile("edi-todo59-git-state-")
  dir.create(repo)
  on.exit(unlink(repo, recursive = TRUE), add = TRUE)
  git_prefix = c("-C", shQuote(repo))
  expect_identical(system2("git", c(git_prefix, "init", "--quiet")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.email", "test@example.invalid")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.name", "EDI test")), 0L)
  tracked_file = file.path(repo, "tracked.txt")
  writeLines("baseline", tracked_file)
  expect_identical(system2("git", c(git_prefix, "add", "tracked.txt")), 0L)
  expect_identical(system2("git", c(git_prefix, "commit", "--quiet", "-m", "baseline")), 0L)

  clean = helper_env$read_benchmark_git_state(git_args_prefix = git_prefix)
  expect_identical(clean$status, "<clean>")
  expect_match(clean$tracked_diff_sha256, "^[[:xdigit:]]{64}$")
  expect_match(clean$untracked_content_sha256, "^[[:xdigit:]]{64}$")

  writeLines("changed", tracked_file)
  dirty = helper_env$read_benchmark_git_state(git_args_prefix = git_prefix)
  expect_match(dirty$status, "M tracked[.]txt")
  expect_match(dirty$tracked_diff_sha256, "^[[:xdigit:]]{64}$")
  expect_false(identical(dirty$tracked_diff_sha256, clean$tracked_diff_sha256))

  untracked_file = file.path(repo, "untracked.txt")
  writeLines("untracked", untracked_file)
  with_untracked = helper_env$read_benchmark_git_state(git_args_prefix = git_prefix)
  expect_match(with_untracked$status, "\\?\\? untracked[.]txt")
  expect_identical(with_untracked$tracked_diff_sha256, dirty$tracked_diff_sha256)
  expect_match(with_untracked$untracked_content_sha256, "^[[:xdigit:]]{64}$")
  expect_false(identical(with_untracked$untracked_content_sha256, clean$untracked_content_sha256))

  writeLines("different untracked contents", untracked_file)
  changed_untracked = helper_env$read_benchmark_git_state(git_args_prefix = git_prefix)
  expect_identical(changed_untracked$status, with_untracked$status)
  expect_identical(changed_untracked$tracked_diff_sha256, with_untracked$tracked_diff_sha256)
  expect_false(identical(changed_untracked$untracked_content_sha256,
                         with_untracked$untracked_content_sha256))

  failed = helper_env$read_benchmark_git_state(git_command = "/no/such/git-command")
  expect_identical(failed$status, "<unavailable>")
  expect_identical(failed$tracked_diff_sha256, "<unavailable>")
  expect_identical(failed$untracked_content_sha256, "<unavailable>")
})
