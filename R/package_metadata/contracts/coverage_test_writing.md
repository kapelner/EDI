# Contract: Writing Coverage Tests for New Code and Refactors

Date: 2026-10-15.

This is the contract for the tests that accompany a change to code that
*already exists* -- a new function or branch in an existing file, a refactor,
a bug fix, a new C++ kernel path -- and for any test written to close a row in
`R/package_tests/coverage_gap_registry.csv`. It is the companion to
`new_model_creation.md`, which owns the test requirements for a *new*
`Inference*`/`Design*` class (§4 there); this document does not repeat those.
If your change adds a class, satisfy `new_model_creation.md` and use this
document only for the parts of your change that touch existing files.

The one-sentence version: **a test counts only if an independent reference
says the result is right, and a coverage test counts only if a real
instrumented measurement shows the targeted lines moved.** Everything below is
how to get both without wasting a test on a line that cannot be measured or a
branch that is already covered.

Companion documents (read them; this contract references but does not repeat
them):

- `R/package_metadata/new_feature_plans/full_test_coverage.md` -- the
  coverage plan this contract distills: the TODO-1 gap categories (§"Phase
  1"), the broaden-vs-new-test rule (TODO-7), the defensive-branch rule
  (TODO-8), the measurement-noise catalogue (TODO-10, 2026-10-13), and the
  `covr`/composition-attribution decision (2026-09-23).
- `R/package_tests/ci/README.md` -- the runtime-balanced shard system every
  bulk test file lives in: manifest registration, the 2,400 s shard budget,
  the correctness vs. coverage tiers, and the pre-push drift gate.
- `CONTRIBUTING.md` §3 ("Tests before fixes", golden-fixture policy) and §4
  (what the pre-push hook runs vs. what you run yourself).
- `vignette("reproducibility")` -- required reading before any test that
  seeds, resamples, or sets `num_cores`.
- `vignette("backend-contracts")` -- required before testing a C++ kernel
  directly rather than through its R6 wrapper.

---

## 1. Decide what kind of gap this is before writing anything

Every uncovered line is one of four things, and the right test is different
for each. Classify first (these are the registry's `category` values):

| Category | What it looks like | What closes it |
|---|---|---|
| `straightforward_test` | Code nobody ever called; no gate in front of it. | A new focused test (§3). |
| `dispatch_threshold` | Reachable only past a size/count/core gate: `if (num_cores > 1)`, `n > threshold`, `B >= 128`, an OpenMP region, a "fast path" chosen over a reference path. | A test that *deliberately crosses the gate* and asserts a real result, filed in `testthat_bulk/` (§4). |
| `dead_or_unreachable` | No public path can reach it; a guard for a state the constructor forbids. | Not a test. Either delete it, or exclude it with a stated reason (§5). |
| `diagnostic_smoke` | Introspection/build-info/printing with no numerical claim. | One assertion that it returns a well-formed object. Nothing more. |

Two rules sit on top of the table:

- **Broaden before you add (TODO-7).** Grep `R/EDI/tests/testthat/` and
  `R/package_tests/testthat_bulk/` for the function and for the class. If an
  existing fixture already *reaches* the branch but does not *assert* on it,
  extend that test's inputs or assertions. A new file that exercises code an
  old file already exercises adds runtime and closes nothing. Record which
  route you took in the registry row's `notes` (§7).
- **Check that the gap is real before you chase it (TODO-10).** Three kinds
  of measured gap cannot be closed by any test; see §6 before writing one.

## 2. The test itself: what makes an assertion count here

This repository's dominant test is the **reference test** (907 of the ~1,000
bulk files end in `-reference.R`). Its shape:

1. **An independent reference computation.** Hand-written math in plain R, a
   closed form, or an unrelated package (`glm`, `survival::coxph`,
   `sandwich::vcovHC`, `MASS::rlm`, `coin`). It must *not* be a second call
   into the same EDI kernel, the same R6 method with different arguments, or a
   re-derivation that copies the kernel's own loop. If the kernel is the only
   implementation in existence, write the slow obvious version in R (a
   `for` loop over the definition) and compare against that -- see
   `threshold_ridit_reference()` in
   `test-resampling-parallel-threshold-contracts.R` for the pattern, including
   the comment that explains which documented semantics the reference mirrors.
2. **A deterministic fixture.** `set.seed()` at the top of the fixture
   builder, sizes stated as named integers, and -- for a `dispatch_threshold`
   test -- a comment that names the exact gate being crossed and with how much
   margin (`# 128 columns * 160 subjects exceeds both should_parallelize_
   replicates gates (128 replicates and 20,000 total work)`). A reader must be
   able to see that the test crosses the threshold without opening the source.
3. **Assertions on the quantity the code is for**, with an explicit
   `tolerance`. `expect_equal(est, ref, tolerance = 1e-10)` for closed-form
   algebra; looser, justified tolerances for iterative fits (say why in a
   comment). "Didn't error" is not a coverage test. Where a method returns a
   named CI, assert both bounds and the names.
4. **Both sides of every branch the test is meant to cover.** A constant
   column *and* a varying one for `scale_columns_cpp`; the `sd > 0` branch
   alone leaves the `else` uncovered and the file at 50%. If the branch is a
   guard that returns `NA`/`FALSE`, assert that return and the
   `is_nonestimable()` reason, not merely that the call survived.
5. **Nothing self-fulfilling.** Do not compute the expected value by calling
   the function under test on a transformed input, do not read the expected
   value out of a cache the function populates, and do not assert on an
   object's own `print()` output as evidence of a number.

Access internals the way the suite already does: `K <- function(x) get(x,
envir = asNamespace("EDI"))` or `EDI:::name` for unexported kernels; a private
R6 method through `obj$.__enclos_env__$private$method()`. If a reference
package is in `Suggests`, open with `skip_if_not_installed("pkg")` -- and know
that this skips the *whole file*, so do not put an unrelated kernel's only
test in a file that skips on a package it does not need.

## 3. When to write a new file, and what goes in it

- One topic per file. A file's name is its contract:
  `test-<area>-<specific-behavior>-reference.R` (correctness vs. an
  independent reference), `-contracts.R` (argument/shape/error-message
  contracts), `-migration-golden.R` / `-migration-baseline.R` (pins old-class
  vs. new-class output; see §5 for when these may change). Do not name a file
  after the registry row (`test-coverage-foo.R`); name it after what it
  proves.
- Open every file with `library(testthat)` then `library(EDI)`; nothing
  else at top level except fixture/reference helpers used only in this file.
- Shared machinery lives in `R/package_tests/testthat_bulk/helper-*.R`
  (`helper-inference-migration-harness.R`, `helper-fixed-design-test-fixture.R`,
  `helper-likelihood-method-smoke.R`, `helper-run-all-inference.R`, ...).
  Reuse these; add a new helper only when three or more files would use it.
  Remember that `covr::file_coverage()` and ad hoc `Rscript` runs do not load
  helpers automatically -- a test that needs one must still work when run
  through `ci/run_selected_tests.R`, which does.
- A test that fails against the *current* package may be committed only as a
  deliberate regression test for a bug you are fixing in the same change
  (CONTRIBUTING §3, "Tests before fixes"), named so the failure reads as the
  bug (`...-distinguishes-...`, `...-regression...`). Never weaken a reference
  to make a test pass.

## 4. Placement: which bucket a test belongs in

There are two directories and three execution buckets. Choose the directory
by the decision rule below; the buckets then follow automatically from the
manifest.

### 4.1 The two directories

| | Fast tier -- `R/EDI/tests/testthat/` (252 files) | Bulk tier -- `R/package_tests/testthat_bulk/` (~1,150 files) |
|---|---|---|
| Who runs it | `R CMD check` (so **CRAN runs it**), the pre-push hook, every CI check-matrix job, *and* the coverage shards | CI only: the sharded `test-bulk-non-cran` correctness run on every PR/push, and the coverage shards on push to `main` |
| Ships in the package tarball | yes | no |
| Sees internals via | `EDI:::` / `asNamespace("EDI")` (installed package) | same, through `pkgload::load_all(compile = FALSE)` of the checkout |
| Parallel / multi-worker | must skip or run single-threaded under `EDI_PREPUSH_NO_PARALLEL=true` | allowed; this is where parallel-dispatch tests live |
| Runtime budget | seconds; the whole directory is CRAN's test time | a few minutes per file; packed into 2,400 s shards |
| Suggests-only packages | avoid, or `skip_if_not_installed()` -- CRAN checks "no Suggests" too (`ubuntu-latest (release, no Suggests)`) | `skip_if_not_installed()` at the top of the file |

**Decision rule -- a test goes in the fast tier only if all four hold:**

1. It is a *contract* a CRAN user should be able to verify on install: the
   public API's shape, argument errors, a small closed-form correctness
   check, seed reproducibility, build metadata.
2. It finishes in seconds with `B`/`r` in the single digits to low tens.
3. It does not need `num_cores > 1`, OpenMP fan-out, or a Suggests-only
   package (or it skips cleanly without one).
4. It would still be worth running on every single `git push`.

Everything else -- and **every coverage test by default** -- goes in the bulk
tier. In particular: any `dispatch_threshold` test (crossing a size, `B`, `r`
or `num_cores` gate is the point, and that is exactly what the fast tier
cannot afford), any independent-reference test that fits a model more than a
handful of times, anything using `coin`/`sandwich`/`MASS`-style comparators,
and all migration goldens. If you are unsure, bulk: a slow fast-tier test
costs every contributor on every push and risks a CRAN timing NOTE; a bulk
test costs one shard once.

Current convention in the fast tier for the rare borderline case: 11 of 252
files use `skip_on_cran()` and 2 gate on `EDI_PREPUSH_NO_PARALLEL`. Prefer
moving the test to bulk over adding a third kind of skip.

### 4.2 The three execution buckets (what the manifest does with your file)

`R/package_tests/ci/test_runtimes.csv` has one row per file per
`runtime_tier`, and `refresh_manifest.py` assigns tiers by directory:

- **`correctness`** -- bulk files only (1,147 rows). Runs in
  `test-bulk-non-cran.yml` on every PR and push, sharded to 2,400 s, and
  fails CI on any failed expectation. The fast tier is *not* in this bucket
  because `R CMD check` already runs it in every matrix job.
- **`coverage`** -- bulk files **and** fast-tier files (1,147 + 252 rows).
  Runs under `covr::package_coverage()` in `test-coverage-R.yaml` on push to
  `main`; failures are logged, not fatal, so the measurement completes. This
  is the only bucket whose result moves `coverage_gap_registry.csv`, the
  floor gate, and the Codecov badge -- which is why a fast-tier test *does*
  count toward coverage even though it never appears in the correctness
  shards.
- **`R CMD check` / pre-push** -- fast tier only, not managed by the
  manifest at all.

Consequences worth knowing: a bulk file is measured twice per push (once for
correctness, once for coverage); a fast-tier file is the only kind that can
block a CRAN submission; and a test that *passes* but is in the wrong bucket
is invisible until someone reads the manifest.

### 4.3 Registering and budgeting

- **Register every bulk file** after adding, renaming, or deleting one:
  ```sh
  python3 R/package_tests/ci/refresh_manifest.py
  ```
  and commit the updated `test_runtimes.csv`. The pre-push hook runs both
  shard planners with `--check-only` and refuses the push on inventory drift
  (`Manifest inventory mismatch: missing={...}`); CI's `plan` job fails the
  same way. New rows get a `bootstrap` estimate until a real `timings.csv`
  is imported (`refresh_manifest.py --timings ...`); don't hand-edit
  estimates.
- **Stay under the shard budget.** Shards are packed longest-first into
  2,400-estimated-second buckets; a single file above that budget fails
  planning for everyone. Keep one file to a few minutes and split by topic
  rather than writing one giant file.
- **Pin thread counts** in anything that touches OpenMP or BLAS
  (`OMP_NUM_THREADS=1` etc. are set job-wide in CI; a local run that forgets
  them can pass for the wrong reason). A test whose *purpose* is to exercise
  `num_cores > 1` must assert the result equals the `num_cores = 1` result
  (`vignette("reproducibility")`).

## 5. Refactors, guards, and goldens

- **A refactor with zero behavior change can still drop coverage**, and that
  drop is real. Replacing a hand-rolled loop with a call into shared machinery
  (`kk21_stepwise_survival.cpp`, commit `51d9167c`: IRLS loop -> 
  `optimize_likelihood()`) removed well-covered lines and added new
  `return false` guards (`!XS.allFinite()`, `!fit.converged`) that no fixture
  reaches. New guard clauses are new code; each one needs either a test that
  triggers it (feed the non-finite input, force non-convergence) or an
  explicit exclusion decision -- never silence.
- **Defensive / impossible-state branches (TODO-8)** get a decision, not a
  shrug. Either (a) reach the branch deliberately -- malform the private state
  through `.__enclos_env__$private`, pass the forbidden argument past
  `should_run_asserts()`, construct the degenerate design -- and assert the
  documented error message or `NA` return; or (b) mark it excluded with an
  inline comment stating *why no public path can reach it*. An unexplained
  exclusion is indistinguishable from a hidden gap.
- **Golden and baseline fixtures pin numbers on purpose.** If your refactor
  changes a `-migration-golden.R` expected value, the change is either a bug
  in your refactor or an intentional, documented behavior change declared in
  `NEWS.md` and the PR. Updating a golden "to make it pass" without one of
  those two sentences is forbidden.
- Seeded results are part of the contract: a refactor that changes any seeded
  output is a breaking change (`vignette("reproducibility")`).

## 6. Before you write a test for a measured gap: is the number real?

Three attribution failures in this codebase produce low coverage that **no
test can raise**. Writing one anyway is the most expensive mistake in this
area, because it looks like progress. Check these first; each has a cheap
verification and a precedent in `full_test_coverage.md` (TODO-10):

1. **`covr`/`define_inference_class()` composition gap.** A thin wiring file
   (`inference_continuous_KK14_bai.R`: one `define_inference_class(...)` call
   and one dead helper) or a harvested component source
   (`inference_incidence_gcomp_abstract.R`) shows ~0%/NaN no matter how well
   its class is tested, because the methods' bodies live in other files and
   `covr` cannot attribute them back. *Verify:* `covr::file_coverage()` the
   file against its dedicated tests; if real assertions pass while coverage
   reads 0%/NaN, it is this. Note `file_coverage()` cannot measure the
   *origin* file either (it re-sources into a scratch env the loaded package
   never touches) -- only a full `package_coverage()` run can, and even that
   under-counts this pattern. Decision on record (2026-09-23): accepted,
   not a `covr` PR target.
2. **gcov header/inline attribution.** An `inline` function in a `.h`
   (`r_seed_draw.h`) shows 0% while every `.cpp` that inlines it measures
   fine. *Verify:* its only callers are above threshold.
3. **`-O2 --coverage` line noise.** Unchanged source, a previously-100%
   file reads 75% (`fast_scale_cols.cpp`). *Verify:* pull the merged report
   and `covr::tally_coverage(report$coverage, by = "line")`; if loop entry,
   both branches, and `return` all have real hits and only a couple of plain
   arithmetic statements read 0, it is the optimizer reordering lines.

A gap that survives these checks is real. A file in any of the three
categories goes in the registry as `category = unclassified`,
`status = excluded`, with the verification in `notes` -- and into
`codecov.yml`'s `ignore:` list so patch coverage does not flag diffs to it.

## 7. Confirming it worked, and recording it

- **The only confirmation is a real instrumented measurement.** A test whose
  assertion "looks relevant" proves nothing about coverage attribution;
  `covr::file_coverage()` cannot stand in for `package_coverage()` on
  composed classes (§6); and a local full run needs a user-authorized rebuild
  (see `CLAUDE.md`). The authoritative report is CI's: every push to `main`
  that touches R/C++ runs `test-coverage-R.yaml` (~1.5 h wall-clock, sharded)
  and uploads two artifacts:
  ```sh
  gh run list --workflow=test-coverage-R.yaml --limit 5
  gh run download <run-id> -R kapelner/EDI -n coverage-registry -D <dir>   # candidate CSV + drift note
  gh run download <run-id> -R kapelner/EDI -n coverage-merged   -D <dir>   # merged-coverage.rds
  ```
  Use the newest run that actually executed the `shards` and `merge` jobs
  (nightly runs are no-ops when nothing changed).
- **Registry rows move on evidence, not intent.** A row becomes `addressed`
  when a real report shows the file at or above the 80% threshold -- the
  generator does this; you do not hand-edit `coverage_percent`. Until then
  the row stays `pending`/`in_progress` with a `notes` entry saying which
  test you added and whether you broadened or created it. Rows you resolve
  as measurement artifacts get `excluded` + the verification note (§6).
- **A fall from `addressed` back to `pending` is a signal, not a verdict.**
  Diff the source since the last measured commit. Unchanged source -> suspect
  §6.3 and check the line tally. Changed source -> find the new uncovered
  lines; they are your new tests (§5).
- Patch coverage (`codecov/patch/r`, target 80% ± 2) is posted on PRs and
  required for merge; for direct pushes to `main` it, like the floor gate, is
  a retrospective red X, not a pre-landing block. Treat a red patch status as
  "fix in the next commit", not "ignore".

## 8. Definition of Done (checklist)

- [ ] Gap classified (§1) and the registry row's `notes` say which of the four
      categories, and whether an existing fixture was broadened or a new file
      written (and why not the other).
- [ ] §6 checked first: the gap is not a composition-attribution, header-
      inline, or `-O2` line-noise artifact. If it is, the row is `excluded`
      with the verification recorded and the file added to `codecov.yml`
      `ignore:`; no test written.
- [ ] Every assertion compares against an **independent** reference (plain-R
      definition, closed form, or unrelated package), with an explicit,
      justified `tolerance`; no self-referential checks; `set.seed()` in the
      fixture.
- [ ] Both sides of each targeted branch exercised; guards assert their
      documented return/error, not mere survival.
- [ ] Placed by the §4.1 decision rule: fast tier only if it is a CRAN-
      verifiable contract that runs in seconds, needs no `num_cores > 1` and
      no Suggests-only package; otherwise (and for every coverage test by
      default) `testthat_bulk/`. `dispatch_threshold` tests state the gate
      and margin in a comment and are never in the fast tier; parallel tests
      assert equality with `num_cores = 1`.
- [ ] Defensive branches either reached deliberately or excluded with an
      inline reason (§5); new guard clauses from a refactor each have one or
      the other.
- [ ] No `-migration-golden.R` / `-baseline.R` expected value changed without
      a `NEWS.md` entry and a PR sentence saying the change is intentional.
- [ ] File named for what it proves (`test-<area>-<behavior>-reference.R`
      etc.), opens with `library(testthat); library(EDI)`, one topic, under
      the shard budget, `skip_if_not_installed()` only for packages the whole
      file genuinely needs.
- [ ] `python3 R/package_tests/ci/refresh_manifest.py` run and
      `test_runtimes.csv` committed; pre-push hook's `--check-only` planners
      pass.
- [ ] Coverage confirmed from a real CI `coverage-merged` artifact (or a
      user-authorized local `package_coverage()` run), not inferred from the
      assertion; registry regenerated from that report rather than hand-set.
