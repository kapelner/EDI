library(testthat)
library(EDI)

test_that("Bayesian-bootstrap benchmark distinguishes clean, dirty, and unavailable Git state", {
  benchmark_script = file.path("..", "..", "benchmark", "benchmark_bayesian_bootstrap_performance.R")
  expect_true(file.exists(benchmark_script))
  expressions = parse(benchmark_script)
  matches = Filter(function(expr) {
    is.call(expr) && identical(expr[[1L]], as.name("=")) &&
      identical(expr[[2L]], as.name("read_benchmark_worktree_state"))
  }, expressions)
  expect_length(matches, 1L)
  helper_env = new.env(parent = globalenv())
  eval(matches[[1L]], envir = helper_env)

  repo = tempfile("edi-todo57-git-state-")
  dir.create(repo)
  on.exit(unlink(repo, recursive = TRUE), add = TRUE)
  git_prefix = c("-C", shQuote(repo))
  expect_identical(system2("git", c(git_prefix, "init", "--quiet")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.email", "test@example.invalid")), 0L)
  expect_identical(system2("git", c(git_prefix, "config", "user.name", "EDI test")), 0L)
  tracked = file.path(repo, "tracked.txt")
  writeLines("baseline", tracked)
  expect_identical(system2("git", c(git_prefix, "add", "tracked.txt")), 0L)
  expect_identical(system2("git", c(git_prefix, "commit", "--quiet", "-m", "baseline")), 0L)

  clean = helper_env$read_benchmark_worktree_state(repo)
  expect_identical(clean$status, "<clean>")
  expect_identical(clean$dirty, FALSE)

  writeLines("changed", tracked)
  dirty = helper_env$read_benchmark_worktree_state(repo)
  expect_match(dirty$status, "tracked[.]txt")
  expect_identical(dirty$dirty, TRUE)

  failed = helper_env$read_benchmark_worktree_state(repo, git_command = "/no/such/git-command")
  expect_identical(failed$status, "<unavailable>")
  expect_identical(failed$dirty, NA)
})
