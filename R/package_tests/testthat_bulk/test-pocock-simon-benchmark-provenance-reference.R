test_that("Pocock-Simon benchmark provenance records or rejects Git state", {
  benchmark_script = file.path("..", "..", "benchmark", "benchmark_pocock_simon_arrivals.R")
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
  eval(definition("loaded_edi_namespace_path"), envir = helper_env)
  eval(definition("edi_r_layer_sha256"), envir = helper_env)
  eval(definition("read_git_state"), envir = helper_env)

  installed_namespace = helper_env$loaded_edi_namespace_path()
  expect_true(dir.exists(installed_namespace))
  expect_match(helper_env$edi_r_layer_sha256(installed_namespace), "^[[:xdigit:]]{64}$")

  namespace_dir = tempfile("edi-todo60-r-layer-")
  dir.create(file.path(namespace_dir, "R"), recursive = TRUE)
  on.exit(unlink(namespace_dir, recursive = TRUE), add = TRUE)
  namespace_payload = file.path(namespace_dir, "R", "EDI.rdb")
  writeBin(charToRaw("r-layer-before"), namespace_payload)
  r_layer_before = helper_env$edi_r_layer_sha256(namespace_dir)
  expect_match(r_layer_before, "^[[:xdigit:]]{64}$")
  writeBin(charToRaw("r-layer-after"), namespace_payload)
  r_layer_after = helper_env$edi_r_layer_sha256(namespace_dir)
  expect_match(r_layer_after, "^[[:xdigit:]]{64}$")
  expect_false(identical(r_layer_before, r_layer_after))
  expect_identical(helper_env$edi_r_layer_sha256(file.path(namespace_dir, "missing")), "<unavailable>")

  repo = tempfile("edi-todo60-git-state-")
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

  old_git_dir = Sys.getenv("GIT_DIR", unset = NA_character_)
  old_git_work_tree = Sys.getenv("GIT_WORK_TREE", unset = NA_character_)
  on.exit({
    if (is.na(old_git_dir)) Sys.unsetenv("GIT_DIR") else Sys.setenv(GIT_DIR = old_git_dir)
    if (is.na(old_git_work_tree)) Sys.unsetenv("GIT_WORK_TREE") else Sys.setenv(GIT_WORK_TREE = old_git_work_tree)
  }, add = TRUE)
  Sys.setenv(GIT_DIR = file.path(repo, ".git"), GIT_WORK_TREE = repo)

  clean = helper_env$read_git_state()
  expect_identical(clean$status, "<clean>")
  expect_match(clean$tracked_diff_sha256, "^[[:xdigit:]]{64}$")

  writeLines("changed", tracked_file)
  dirty = helper_env$read_git_state()
  expect_match(dirty$status, "M tracked[.]txt")
  expect_match(dirty$tracked_diff_sha256, "^[[:xdigit:]]{64}$")
  expect_false(identical(dirty$tracked_diff_sha256, clean$tracked_diff_sha256))

  failed = helper_env$read_git_state(git_command = "/no/such/git-command")
  expect_identical(failed$status, "<unavailable>")
  expect_identical(failed$tracked_diff_sha256, "<unavailable>")
})
