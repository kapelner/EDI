# Thread and random-number review (monthly): one batch of parallel or resampling files

You are one of the agents run monthly by `.github/workflows/audit-thread-rng.yml` (plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 4). You review a few
source files of EDI (an R package with C++ kernels) that run parallel loops or draw random
numbers, and you prove each bug with a testthat test that fails on the current code. You have
read-only tools (Read, Glob, Grep) and no shell: you cannot run R or the tests. The job runs
your tests after you finish.

## Your inputs

- The batch file named in your task message (`.audit-work/batches/<id>.json`). Its `units` list
  holds one entry per file:
  - `id`: the unit id (the file path). Use it as `unit` in your findings and in `units_checked`.
  - `reason`: why it was chosen (new, changed, open finding, rotation).
  - `file`, `language` (C++ or R), `lines`.
  - `parallel_or_rng_lines`: `[line, text]` for each line with an OpenMP pragma, a thread, an
    RNG call, a seed, a cluster or a core count. Start there, then read the whole loop or
    function around each one.
  - C++ units: `rcpp_exports`, `included_by` (for a header), `r_callers` (R files and lines
    that call the exports), `r_classes`.
  - R units: `r_classes` and `cpp_kernels_called`.
  - `test_files`: existing tests that name the exports or classes.
  - `invariance_test_templates`: the existing bulk tests that call `set_num_cores()`. Read
    `R/package_tests/testthat_bulk/test-rand-seed-core-count-invariance-two-session.R` before
    writing a test: it shows how this repository compares results across core counts.
  - `recent_commits`: the file's last commits (you have no `git`).
- `.audit-work/decisions.md`: settled decisions and findings the owner rejected. Never raise a
  finding that matches one of them.
- `.audit-work/mechanical.json`: findings already reported. Do not repeat them.

Background you need: EDI's documented contract is that a seeded result (a randomization draw,
p-value, interval or bootstrap distribution) does not depend on the number of cores. The fix
pattern this repository uses is to seed each draw from its draw index, never per thread
(`R/EDI/src/RNG.h` describes EDI's portable R-compatible generator `RRng` and its two uses).
`set_num_cores(n)` and `unset_num_cores()` are in `R/EDI/R/globals.R`; designs and inference
objects capture the core count when they are constructed, so set it first.

## What to look for

| `kind` | Pattern |
|---|---|
| `seed_per_thread` | a random stream seeded per thread or per chunk (so the draws a given index gets depend on how work is split) instead of per draw index |
| `shared_rng_in_parallel` | R's RNG (`unif_rand`, `norm_rand`, `R::r*`, `GetRNGstate`) or one shared C++ engine used inside an OpenMP or thread region |
| `shared_mutable_state` | a variable, buffer, cache or accumulator written by several threads without a reduction, lock or per-thread copy (a data race), or a floating-point reduction whose result depends on the thread count where the docs promise it does not |
| `r_api_in_thread` | an R API call (allocation, `Rcpp::` objects, `Rf_*`, `R_CheckUserInterrupt`) from a worker thread |
| `core_count_dependence` | any other path where a seeded result changes with `set_num_cores()`: R-level workers (`par_lapply`, mirai, fork clusters) seeded per worker, an RNG stream advanced a different number of times, a fallback path taken only when parallel |
| `draw_order_dependence` | a result that changes with the order in which draws are made or collected (for example results collected in completion order) where it should not |

Out of scope: speed, numerical accuracy of single-threaded code (another audit covers it), and
code where the documentation explicitly says the result depends on the core count.

## Evidence: every finding needs a failing test

A finding without a test is not kept. The job wraps your `test_code` in
`test_that("<test_name>", { ... })`, runs it against EDI installed from the commit you read
(`library(testthat)` and `library(EDI)` are attached; the runner has 4 cores), and keeps the
finding only if:

- at least one expectation **fails**, and none errors or skips;
- the failure is not a wrong call (an unknown function or argument, a missing object). Read
  the signatures you call; internal functions are reached as `EDI:::name`;
- if you give `failure_contains`, that exact text appears in the failure message. It is required
  when the test uses `expect_error`, `expect_no_error`, `expect_silent`, `expect_warning`,
  `expect_no_warning` or `expect_condition`.

The test should compute the same seeded result twice, once per core count (for example
`set_num_cores(1)` then `set_num_cores(2)`, constructing the design and inference objects after
each call, with `on.exit(unset_num_cores(), add = TRUE)`), or in two draw orders, and compare
with `expect_equal()` or `expect_identical()`. A race that shows only sometimes is not good
evidence: make the test fail every time (enough draws, a fixed seed), or do not report it.
Other rules:

- self-contained: data built in the test with `set.seed()`; no files, no network, no
  `library()` calls. Use EDI, testthat, base R and the packages EDI imports (as `pkg::fun`);
  `callr` is installed if you need a fresh R session per core count. Do not call `skip()` or
  `skip_if_not_installed()`: a skipped test is not kept;
- small: well under 120 seconds (the limit is 300 seconds, and a time-out is not kept);
- R style of this repository: tabs for indentation and `=` for assignment.

`test_code` is the body only, without the `test_that()` line or the closing brace.

## Your output (the structured JSON the run asks for)

- `units_checked`: the `id` of every unit you actually reviewed. A unit you did not finish is
  left out, so it stays due for the next run.
- `findings`: one object per bug, with `unit`, `kind`, `text` (what is wrong and what changes
  with the core count or draw order), `location` (`file:line`), `evidence` (the path from the R
  entry point to the defect, with `file:line` steps), `test_name`, `test_file_slug` (a few words
  in kebab case that describe the behaviour, never a TODO number), `test_code`,
  `failure_contains` (or an empty string), and `fix_hint` (one sentence).
- No finding is a valid result. Do not pad.
