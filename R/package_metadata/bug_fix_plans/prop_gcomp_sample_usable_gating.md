# Fix: `InferencePropGCompMeanDiff` Randomization Distribution All-NA — Reused-Worker Fast Path Never Adapted for the `rand` Operation

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-13` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-35`, bug-fix/feature split). Found 2026-09-22, surfaced as a side-finding
> during `stale_worker_cache_resampling.md`'s TODO-6 regression test
> (carried there as a self-retiring `KNOWN_BROKEN` entry); this plan is the
> dedicated fix for it.

Unrelated mechanism to `stale_worker_cache_resampling.md` — that plan
fixed a stale-cache bug (draws silently reusing a prior draw's fitted
estimate). This is a worker-state **gating** bug: every randomization draw
on this class returns `NA_real_`, not a stale value — an error-shaped
failure, not a silently-wrong number, but still a broken shipped inference
path.

## The bug, traced to source (not yet independently re-verified by direct repro in this session; high confidence per the trace below)

1. `create_bootstrap_worker_state()` (`R/EDI/R/inference_proportion_gcomp.R:424-433`)
   initializes `state$runtime$sample_usable = FALSE` (line 429) on every
   fresh reused worker.
2. `sample_usable` is set `TRUE`/`FALSE` in exactly one place:
   `load_bootstrap_sample_into_worker()` (`:434-457`) — the **bootstrap**
   row-sample loader. It runs a boundary/separation usability check
   (`bootstrap_sample_is_usable()`) and writes the result to
   `worker_state$runtime$sample_usable` (line 455), along with
   `runtime$current_X_full`/`current_y` (lines 453-454).
3. `compute_bootstrap_worker_estimate()` (`:458-464`) is the estimator:
   `if (!isTRUE(worker_state$runtime$sample_usable)) return(NA_real_)`
   (line 459), then reads `runtime$current_X_full`/`current_y`.
4. Per `EDI_RESAMPLING_DRAW_CONTRACTS$rand`
   (`R/EDI/R/contracts_resampling_draws.R:10-17`), the randomization path's
   estimator is `compute_randomization_worker_estimate`, whose **generic
   default implementation** (`R/EDI/R/inference_all_abstract_rand.R:839-845`)
   is a pure delegate: `estimator = private[["compute_bootstrap_worker_estimate"]];
   estimator(worker_state)`. `InferencePropGCompMeanDiff` never overrides
   this delegate with a randomization-specific estimator.
5. `load_randomization_perm_into_worker()`
   (`inference_all_abstract_rand.R:916` onward) is the generic,
   shared-by-every-class loader — it operates on `worker_priv$w`/`y`
   directly and has no concept of this class's private `runtime` env. It
   never touches `sample_usable`, `current_X_full`, or `current_y`.

Net effect: every randomization draw reuses the class's bootstrap-shaped
estimator, which reads a flag that only the bootstrap loader ever sets. On
the `rand` path that flag is permanently stuck at its init value `FALSE`,
so `compute_bootstrap_worker_estimate()` returns `NA_real_` on every draw —
the whole randomization distribution is uniformly NA in production.

## Broken implementation, not a missing capability declaration

`supports_reusable_bootstrap_worker()` returns `TRUE` unconditionally
(`inference_proportion_gcomp.R:421-423`) — a single flag gating the reused-
worker fast path for all of `{rand, non_param_boot, m_out_of_n_boot,
rand_bootstrap}` — so the class does intend to expose fast-path
randomization; it just never implemented it correctly.

Corroborating evidence the class **should** work here: it already has a
correct randomization-path estimator on the standard (non-reused-worker,
duplicate-per-iteration) path —
`compute_treatment_estimate_during_randomization_inference()`
(`:414-417`), which calls `private$shared()` and returns
`cached_values$md` directly, with none of the `sample_usable`/`runtime`
machinery. The bug is specifically that the reused-worker **fast-path**
estimator was written bootstrap-only-shaped and never adapted for a
permutation draw's differently-populated worker state — the fast path and
the (correct) standard path have diverged.

## Scope: isolated to this one class

`grep -rn "sample_usable" R/EDI/R/` outside `inference_proportion_gcomp.R`
returns zero hits — this `runtime`-env/`sample_usable` pattern is unique to
`InferencePropGCompMeanDiff`, not a shared mixin or base-class mechanism.
**No other class shares this defect.**

## Proposed fix (not yet applied — two options)

**Option A (recommended) — class-specific randomization estimator.**
Override `compute_randomization_worker_estimate()` on
`InferencePropGCompMeanDiff` so it does NOT delegate to
`compute_bootstrap_worker_estimate()`. Instead it should read the worker
state that `load_randomization_perm_into_worker()` actually populates (the
design-backed worker's permuted `w`/`y`) and compute the estimate the same
way `compute_treatment_estimate_during_randomization_inference()` does on
the standard path (`shared()` → `cached_values$md`), applied to the worker
clone instead of `self`. More consistent with how
`EDI_RESAMPLING_DRAW_CONTRACTS` already separates a distinct `rand`
`estimator` key from the bootstrap one — this class just never populated
it, falling through to the generic delegate.

**Option B — post-load hook in the randomization loader.** Extend
`load_randomization_perm_into_worker` with a class-specific hook
(mirroring `bootstrap_sample_is_usable()`) that populates
`runtime$current_X_full`/`current_y`/`sample_usable` from the permuted
assignment before the shared bootstrap-shaped estimator runs. Keeps one
estimator function but adds a class-specific branch to shared loader logic
— less consistent with the contract-driven separation the codebase is
moving toward (`stale_worker_cache_resampling.md`'s TODO-9 follow-up
makes the same "one shared, keep-list/contract-driven mechanism, not a
per-class branch" argument).

Recommend Option A. Not yet decided/reviewed — flagged here, not fixed.

## Status

Fixed 2026-09-23 (Option A, as recommended). Added a class-specific
`compute_randomization_worker_estimate()` override to
`InferencePropGCompMeanDiff` (`inference_proportion_gcomp.R`) — declared in
`define_inference_class()`'s `overrides$private` (required; R6/the
component system rejects an undeclared override with "overrides component
private member(s) without declaration"). Verified via direct repro: rand
distribution now 99/99 finite (`sd = 0.0162`, previously all-NA); Type-I
error at the true null measured at 0.05 over 20 reps (`r = 99`); bootstrap-
family distribution unaffected (unchanged code path, confirmed same
finite/sd behavior before and after). Removed from
`RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
`test-reused-worker-resampling-nondegenerate.R`; full suite re-run passes
(13/13). TODO-6 (CSV regeneration) still open, deferred to the same
regeneration pass as `stale_worker_cache_resampling.md → TODO-7`.

## TODOs

- [x] TODO-1: Confirm the trace above with a direct repro:
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, see top-level `CLAUDE.md`).
  Construct a minimal `InferencePropGCompMeanDiff` fixture, call
  `approximate_randomization_distribution_beta_hat_T()` (or equivalent) with
  a small `r`, and confirm all draws are `NA_real_`. Also confirm the
  *unpermuted* point estimate and the *standard-path* (non-reused-worker)
  randomization distribution both work correctly — isolating the defect to
  specifically the reused-worker fast path, not the class in general.
- [x] TODO-2: Implement Option A (add a class-specific
  `compute_randomization_worker_estimate()` override) unless TODO-1's repro
  surfaces a reason Option B is preferable — if so, that's a ruling for
  whoever picks this up, not a default.
- [x] TODO-3: Verify the fix doesn't change the *bootstrap*-family
  distributions for this class (they were already correct — confirm
  bit-for-bit, reusing `scripts/reused_worker_bitforbit_sweep.R` from
  `stale_worker_cache_resampling.md` if it still applies, or a
  narrower ad hoc check).
- [x] TODO-4: Re-run the true-null repro (analogous to
  `stale_worker_cache_resampling.md`'s TODO-5): confirm the fixed
  randomization distribution is non-degenerate and has correctly-calibrated
  Type-I error, not just "not NA."
- [x] TODO-5: Remove `InferencePropGCompMeanDiff` from
  `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
  `R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R` once
  fixed — the test's `expect_identical` against that list will fail loudly
  if this isn't done, forcing the update.
- [ ] TODO-6: Regenerate any `comprehensive_tests` CSV rows for this class's
  `rand`-family methods once fixed and installed (same caution as
  `stale_worker_cache_resampling.md`'s TODO-7 — only after install, not
  before).

### TODO-6 reconciliation criteria (read-only prep, 2026-10-16)

The available pre-fix archive
`R/package_tests/todo56_mp_resume_20261016/R/package_tests/comprehensive_tests_results_nc_1_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv`
has 2,964 rows at commit `09b5905b413f70009104e6e0e19d0c7cf782fe90`:
988 each for `compute_rand_two_sided_pval`,
`compute_rand_two_sided_pval(delta=0.5)`, and
`compute_rand_confidence_interval`. Both p-value rows are marked
`numeric_instability` with NA results; the confidence-interval rows have
numeric endpoints. Treat this as the stale pre-fix comparison, not as current
evidence. Before closing TODO-6 after the active run/install:

- derive the expected current row-key set from the current comprehensive
  harness for `InferencePropGCompMeanDiff`, `response_type=proportion`,
  `method_family=rand`; compare it against the merged results by the unique
  runner `id` (including `model_formula=~1` and `~.` and each supported
  design / dataset / beta_T / replicate), and account explicitly for missing
  or extra keys rather than relying only on total row counts. `case_id` omits
  replicate and `beta_T`; use it only as a descriptive grouping/consistency
  field, never as a row-level merge key. Require unique IDs and a zero-row
  anti-join in both directions;
- verify provenance on regenerated rows (`github_commit_id`, timestamp,
  runner, and installed package/build version) identifies the post-fix
  checkout/install, and ensure old pre-fix rows are not silently retained as
  duplicates or treated as regenerated evidence;
- inspect `status`, `skip_reason`, `error_message`, `result_1`, `result_2`,
  `result`, and `coverage_truth` for every target row. The old
  `numeric_instability`/NA p-value records must be replaced by valid finite
  results or individually explained legitimate non-estimability; runner
  `status=ok` alone is not enough. For interval rows, also confirm finite
  endpoints and the recorded `beta_T_in_confidence_interval` agrees with the
  interval and `coverage_truth` contract;
- confirm non-`rand` families are outside this TODO-6 replacement scope, and
  reconcile/dedupe only after the complete post-install target row set is
  available. Do not edit the canonical comprehensive CSV during this prep.

**Read-only key-set check, 2026-10-16:** compared the archived partition above
with the existing `R/package_tests/comprehensive_tests_results_nc_1_proportion.csv`.
The existing canonical file contains no rows for this class in the proportion
`rand` family. The archived pre-fix partition has 2,964 unique `id` values,
66 `case_id` values (22 per function run), and 988 rows for each of its three
function runs; all archived `(id, case_id)` pairs are absent from the existing
canonical file. The partition is therefore not already merged and must remain
a stale comparison, not be counted as post-fix evidence. This does not establish
the current harness's expected key set; derive that from the post-install run
before merging. No result CSV was modified.

**Focused installed regression recheck (2026-10-18):**
`test-prop-gcomp-mean-diff-randomization-worker-estimate-not-all-na-reference.R`
passed all 6 assertions against installed EDI 1.0.3, with no failures,
warnings, or skips. The test proves its fixture enters the reused-worker path,
the identity assignment reproduces the observed estimate, and a 30-permutation
public randomization distribution is finite and non-degenerate. Loaded DLL:
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, SHA-256
`23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`. This
validates the installed package's focused regression only; it neither validates
the current checkout nor closes TODO-6's provenance-stamped comprehensive-row
regeneration and key/status reconciliation. No canonical results were written.

**Current-R-source regression recheck (2026-10-18):** after
`pkgload::load_all("R/EDI", compile = FALSE)`,
`test-prop-gcomp-mean-diff-randomization-worker-estimate-not-all-na-reference.R`
passed all 6 assertions, with no failures, warnings, or skips. R source came
from `/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3. The source overlay
loaded `/tmp/Rtmp0tLF3P/pkgload36f6c04c47157c/EDI.so`, SHA-256
`23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`, matching
the installed EDI 1.0.3 DLL. This confirms the current R worker override and
public-path identity/non-degeneracy regression against that existing native
ABI; it does not close TODO-6's post-fix comprehensive rows and reconciliation.
No native build/install or canonical result write occurred.

**Current-R-source regression recheck (2026-10-20):** the same focused test
passed all 6 assertions using `pkgload::load_all("R/EDI", compile = FALSE,
quiet = TRUE)`. R was `R Under development (unstable) (2026-10-13 r90668)`;
checkout and loaded package versions were both 1.0.3. The tested source file
`R/EDI/R/inference_proportion_gcomp.R` has SHA-256
`cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63`; the
test file has SHA-256
`a95ee0ebd70c2680d531cc50f40c4a46f028fc3b0498a21fea85fbab41e33906`.
`pkgload` loaded its temporary copy of the existing installed EDI DLL, SHA-256
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`, exactly
matching the installed library DLL. This validates the checkout-R focused
regression against that existing native ABI only; TODO-6's comprehensive-row
regeneration/reconciliation remains open. No compile/install or canonical
result write occurred.

**Current-R-source/current-native recheck (2026-10-20):** reran the same
six-assertion regression with `pkgload::load_all("R/EDI", compile = FALSE,
quiet = TRUE)` against the latest user-rebuilt EDI native artifact. R was
`R Under development (unstable) (2026-10-13 r90668)`; source namespace was
`/home/kapelner/workspace/EDI/R/EDI`; package version was 1.0.3. The loaded
temporary DLL SHA-256 was
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. A
read-only SHA-256 and `cmp -s` check confirmed this matches both the installed
user-rebuilt `EDI.so` and checkout `R/EDI/src/EDI.so` byte-for-byte. Source
file and test hashes remain respectively
`cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63` and
`a95ee0ebd70c2680d531cc50f40c4a46f028fc3b0498a21fea85fbab41e33906`.
This validates the focused checkout-R regression against the matching
current native artifact; TODO-6's comprehensive-row regeneration and
reconciliation remain open. No build/install or canonical result write
occurred.

**Isolated regeneration preparation, 2026-10-18 (not run):** the output-path
override is covered by
`test-comprehensive-results-output-directory-override-reference.R` (3/3
assertions, `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-results-output-directory-override-reference.R")'`, no compilation). Once a post-fix installed package is explicitly available, the full supported proportion `rand` target can be generated without opening the canonical CSV using a fresh `/tmp` directory and:

```sh
outdir=$(mktemp -d /tmp/edi-todo13-propgcomp-postfix.XXXXXX)
COMPREHENSIVE_FORCE_SLOW_PATHS=1 EDI_COMPREHENSIVE_RESULTS_DIR="$outdir" Rscript R/package_tests/comprehensive_tests.R 40 1 proportion NA InferencePropGCompMeanDiff NA NA NA rand
```

**Static target/guard audit, 2026-10-18:** the harness places
`InferencePropGCompMeanDiff` in `ADDITIONAL_TEST_SLOW_PATHS$rand`,
`$rand_pval`, and `$rand_ci`. Without `COMPREHENSIVE_FORCE_SLOW_PATHS=1`,
the class-level `skip_rand` gate suppresses its rand-family calls even when the
family filter is `rand`; the force flag also disables the separate rand-pval
and rand-CI exclusions. For `response=proportion`, the harness call sites
define the expected `function_run` labels as `compute_rand_two_sided_pval`,
`compute_rand_two_sided_pval(delta=0.5)`, and
`compute_rand_confidence_interval`, under both `model_formula=~1` and `~.`.
This is a source-derived acceptance inventory, not a promise of a fixed row
count: the complete case/id set remains dependent on the harness's current
eligible design/dataset/beta/replication grid and per-call execution status.

This leaves design, dataset, beta, and replicate filters unset, so the harness
enumerates its full current target, including both formula branches. It should
write `comprehensive_tests_results_nc_1_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv` only under `$outdir`. The CSV records the checkout `github_commit_id`, not the loaded package identity; separately capture `packageVersion("EDI")`, `.libPaths()`, the resolved installed library path, and the SHA-256 of its `libs/EDI.so` (or platform DLL). No package-install/build provenance is inferred from the CSV alone. A post-fix package/install identity and the resulting isolated output are still missing; do not merge or deduplicate until the complete `id`/`case_id` set and row-level status/result/coverage checks in TODO-6 pass. This command is a preparation only, not evidence of regeneration.

**Staged regeneration plan (source-derived scope, 2026-10-20; not run):**
the current runner's proportion datasets are `diamonds`, `pte_example`,
`ionosphere`, `abalone`, `iris`, `boston`, `fuel`, `cars`, and `airquality`
(`_dataset_load.R`: the first five plus `fuel`/`cars` derive a proportion
response from continuous data; `boston` and `airquality` declare one
explicitly). `beta_T_values` is `{0, 0.5}`; `Nrep=40`; both `~1` and `~.`
formulas run for each case. `TESTED_DESIGNS` has seven entries, but the direct
proportion GComp branch excludes the two designs recognized as KK
(`KK21stepwise`, `FixedBinaryMatch`); the remaining candidate design selectors
are `Bernoulli`, `SPBR`, `FixediBCRD`, `FixedBlocking`, and
`FixedMatchingGreedy`. The exhaustive fallback is invoked with
`exhaustive_sweep=TRUE` (which sets `skip_slow=TRUE`), so it does not supply
additional `rand` attempts and does not duplicate the direct non-KK attempts.
The outer harness also loops over `formulas_to_test` and passes each value as
the design formula; the direct class call above uses
`run_inference_checks_both_paths()`, which independently runs both model
formulas. Therefore the actual source-level candidate has four distinct
`model_formula × design_formula` combinations per eligible case, not two.
The candidate envelope is 9 datasets × 2 beta values × 5 designs × 40
replicates × 4 formula combinations = 14,400 case contexts. With the forced
slow paths, each eligible context should attempt at most the three labels
listed above, i.e. at most 43,200 result rows. These are source-derived upper
bounds before runtime instantiation/capability and per-call status gates, not
a substitute for the actual post-fix attempt manifest.

Partition the full run into 90 independent selectors (`dataset × beta_T ×
design`); each full chunk covers 40 replicates × 4 formula combinations = 160
contexts and at most 480 result rows. The first selector pilot below showed
that the runner's startup dry-run prune scan dominates the 300-second budget.
The runner now has a narrow explicit opt-in for isolated runs:
`EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1` is accepted only when
`EDI_COMPREHENSIVE_RESULTS_DIR` names an existing directory outside the
checkout. It skips only the read-only startup scan; the default remains the
dry run, and neither path passes `--apply`. The one-replicate and 10-replicate
pilots below have now completed with this option. The measured 10-replicate
slice suggests roughly 216 seconds for a 40-replicate selector by naive linear
projection, but that is not a runtime guarantee. Any larger selector chunk
still needs an explicit runtime budget and hard timeout. Do not split a
selector into repeated processes unless necessary, since each process
otherwise repeats startup costs. The harness uses `r=151` for each
randomization call and `pval_epsilon=0.007` for interval inversion, so the
candidate row bound does not imply a linear runtime bound. The prior
40-replicate attempt without the bypass remains incomplete. A later isolated
40-replicate selector (`airquality × beta_T=0.5 × Bernoulli`) completed with
the bypass, but this is one of 90 selectors, not a full-grid run; see its
record below.

For each pilot/full invocation, set the environment output override to a new
directory, e.g.:

For the installed-package acceptance run, invoke the runner directly so its
`library(EDI)` call resolves the installed package; do not use
`pkgload::load_all()` in this acceptance command. A `compile=FALSE` source
overlay can be useful for checkout-R diagnostics, but it is not a substitute
for the post-fix installed-package run. Record the installed package path,
version, `Built` metadata, library paths, and loaded DLL SHA separately from
the runner's checkout HEAD/diff and source hashes.

```sh
chunk_outdir=$(mktemp -d "/tmp/edi-todo13-propgcomp-${design}-${dataset}-beta${beta}.XXXXXX")
COMPREHENSIVE_FORCE_SLOW_PATHS=1 EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1 \
COMPREHENSIVE_FORK=FALSE EDI_COMPREHENSIVE_RESULTS_DIR="$chunk_outdir" \
  Rscript R/package_tests/comprehensive_tests.R \
  40 1 proportion "$design" InferencePropGCompMeanDiff "$dataset" "$beta" NA rand
```

For a single-replicate pilot, pass `Nrep=40` and `1` in the replicate-filter
position (`... "$beta" 1 rand`); the 10-replicate pilot used `Nrep=10` and
`NA` to enumerate reps 1–10; a full selector uses `Nrep=40` and `NA`. The
runner rejects
the skip option if the results override is missing, invalid, or resolves
inside the checkout. The per-selector
output basename is identical across invocations, which is safe because each
invocation has a unique `$chunk_outdir`; preserve all chunk directories and
never point the override at `R/package_tests/` or a tracked result location.
Before and after every invocation, record the exact argument vector, exit
status, timestamps/elapsed time, checkout commit and dirty state, runner and
relevant R-source hashes, R version, `packageVersion("EDI")`, `.libPaths()`,
resolved installed package path, `Built` metadata, and installed native DLL
SHA-256. Keep the runner CSV's `github_commit_id` as checkout provenance only;
the package/DLL identity must be recorded separately.

After all 90 chunks finish, form the expected attempt manifest from the
current runner gates and compare it with the union of the isolated CSVs by
unique `id` (zero missing/extra anti-joins, no duplicate IDs); use
`case_id` only for grouping. Check the three expected `function_run` labels,
both model formulas crossed with both design formulas, and every
design/dataset/beta/replicate stratum. Review
`status`, `skip_reason`, `error_message`, result fields, `coverage_truth`, and
finite interval endpoints/coverage flags. Keep each chunk and the combined
candidate outside the canonical path; only consider a canonical replacement
after the complete provenance/key/value reconciliation has passed and the
merge is separately authorized.

**Capped source-overlay pilot, 2026-10-20 (incomplete; not acceptance):** ran
one selector (`airquality × beta_T=0.5 × Bernoulli`) with the full 40-replicate
target, both runner formula loops, `COMPREHENSIVE_FORCE_SLOW_PATHS=1`, and the
output override set to
`/tmp/edi-todo13-propgcomp-airquality-beta0.5-Bernoulli.8c0Pf9`. R was
`R Under development (unstable) (2026-10-13 r90668)`; `pkgload::load_all(
"EDI", compile=FALSE, quiet=TRUE)` loaded checkout R from
`/home/kapelner/workspace/EDI/R/EDI` (version 1.0.3) and existing DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, matching
the installed DLL. Checkout HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`; relevant R source SHA-256 was
`cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63`, runner
SHA-256 `cd487c2e342c7326b84fe38ea9f5738f2b963349fcd06b4531aa0d85a074eb6c`,
and dataset-loader SHA-256
`7e3cf603ef384c369c4435dc5ca0b541d9248bbda9e5db7f3c17b2b41628bdda`. The
installed package reports EDI 1.0.3, `Built` at 2026-10-20 07:40:04 UTC, and
DLL SHA-256 equal to the source-overlay DLL. The runner command and arguments
(stdout/stderr redirected to the recorded `runner.log`) were:

```sh
timeout --signal=TERM --kill-after=10s 300s env COMPREHENSIVE_FORCE_SLOW_PATHS=1 COMPREHENSIVE_FORK=FALSE EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo13-propgcomp-airquality-beta0.5-Bernoulli.8c0Pf9 Rscript -e 'pkgload::load_all("EDI", compile=FALSE, quiet=TRUE); cat("SOURCE_PACKAGE_PATH=", find.package("EDI"), "\n", sep=""); cat("SOURCE_PACKAGE_VERSION=", as.character(packageVersion("EDI")), "\n", sep=""); d <- getLoadedDLLs()[["EDI"]]; p <- d[["path"]]; cat("LOADED_DLL_PATH=", p, "\n", sep=""); system2("sha256sum", p); source("package_tests/comprehensive_tests.R")' 40 1 proportion Bernoulli InferencePropGCompMeanDiff airquality 0.5 NA rand > /tmp/edi-todo13-propgcomp-airquality-beta0.5-Bernoulli.8c0Pf9/runner.log 2>&1
```

The command exited 124 at its 300-second timeout. Startup's dry-run
`prune_stale_result_rows.R` check scanned the default comprehensive result
files (no `--apply`; no canonical write) and reported 716,473 stale rows; the
logged scan interval was about 152 seconds before the first fit. At the time
of this pilot, no runner flag/environment option suppressed that startup
check. `EDI_COMPREHENSIVE_RESULTS_DIR` redirects the main runner
CSV only: the startup call invokes `prune_stale_result_rows.R` with no
arguments, and that helper resolves its CSVs beside its own script. Its only
write branch requires the explicit `--apply` argument, which the runner does
not pass; the helper's safety regression also checks that a default dry run
leaves the CSV bytes unchanged. Thus the precheck is read-only but cannot
currently be isolated from canonical-file scanning through the documented
output override. Do not use `--apply` as a workaround. The isolated
CSV has 336 rows: replicates 1–28 complete, 12 rows per replicate (three
function labels across four formula combinations); every recorded row has
`status=ok`, finite p-values/CI endpoints and coverage truth, and a unique
`id`. The process had started replicate 29 and was interrupted during its
second `compute_rand_two_sided_pval(delta=0.5)` call, so replicate 29 contributes
no accepted rows and the candidate is incomplete. CSV SHA-256 is
`41f4c0dad6cbb47d28f51e3570498fa67153d295faef414c1a7cf54623359384`; runner
log SHA-256 is
`4b9a39c44a793138b63e9fa0009bd0db07dbd26fe2dcbaf1ba1bc61369818abb`.
At the time of this invocation, the runner's per-selector startup scan alone
consumed roughly half the budget and the nested formula loops doubled the
planned row scope, so this 40-replicate attempt was not viable under a
300-second cap. Splitting it into repeated one-replicate processes would also
have repeated the 152-second scan. The candidate remains incomplete; the later
tested scan-bypass and bounded follow-up pilots are recorded below. Keep this
candidate in `/tmp`; do not merge it or treat it as a complete pilot.

**Isolated startup-scan opt-in (2026-10-20; tested, pilot not rerun):** the
runner now accepts `EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1` only together with an
existing `EDI_COMPREHENSIVE_RESULTS_DIR` that resolves outside the checkout.
Invalid/missing output overrides fail closed; the bypass branch does not
invoke the pruner, and the ordinary path still invokes it with only the script
path (never `--apply`). Regression coverage was added to
`test-comprehensive-results-output-directory-override-reference.R`; the file
passed 88 expectations with checkout R loaded via
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` and the existing
DLL. The isolated fixture confirmed its canonical CSV bytes were unchanged.
This establishes the opt-in routing/safety contract only; that regression
test generated no comprehensive rows or runtime measurement. The subsequent
one-replicate run is recorded below.

**One-replicate isolated pilot (2026-10-20; source overlay, incomplete):**
after enabling the opt-in, ran only `airquality × beta_T=0.5 × Bernoulli ×
rep=1`, with `Nrep=40`, both design-formula branches, and both model-formula
branches. Environment was `COMPREHENSIVE_FORCE_SLOW_PATHS=1`,
`COMPREHENSIVE_FORK=FALSE`, `EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1`, and
`EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo13-airquality-beta05-rep1.2PPnrk`.
The runner arguments recorded in the sidecar are exactly `40 1 proportion
Bernoulli InferencePropGCompMeanDiff airquality 0.5 1 rand`. R was `R Under
development (unstable) (2026-10-13 r90668)`; source namespace was
`/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Installed EDI 1.0.3 reports
`Built: R 4.7.0; x86_64-pc-linux-gnu; 2026-10-20 07:40:04 UTC; unix`. The
loaded overlay DLL and installed `EDI.so` both have SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
The proportion GComp source SHA-256 is
`cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63`; the
startup/output-path helper SHA-256 is
`bea6f01d7813249cc70c561dc8b226a1b20dd6c12391ffe958e5665ce306af29`.
Runner SHA-256 is
`660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`; the
sidecar records dirty-checkout digest
`abadd3824b2dcc486963a10773f30b75b84afb335dea708456ad50bbeea81364`.

The run completed in 9.318 seconds according to the provenance sidecar,
within the hard 180-second cap. Its isolated result CSV has 12 rows and 12
unique `id`s: all four `model_formula × design_formula` contexts crossed with
`compute_rand_two_sided_pval`, `compute_rand_two_sided_pval(delta=0.5)`, and
`compute_rand_confidence_interval`. All 12 statuses are `ok`; there are no
skip reasons or error messages; `coverage_truth` and every `result_1` are
finite, while `result_2` is missing only for p-value rows and finite for the
confidence-interval rows. The exact IDs and row values are preserved in
the CSV at
`/tmp/edi-todo13-airquality-beta05-rep1.2PPnrk/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_rep-1_family-rand.csv`
(SHA-256 `077f180802b6d2d587acdd4d6fe1bbab363198a98318e8a54091e55d59456772`);
the adjacent provenance sidecar SHA-256 is
`aa4f5ef6ace43b5529952b9ff376947ed3c40c762d11985892fb9997527bbf69`, and
the runner log SHA-256 is
`6afc5392bfec2d61456b6dbab9a922c13be1e401e20be385fc86a3178807eb9a`. The
sidecar confirms the result file did not exist before this run and records
the output path under `/tmp`. No canonical result file was written. This
validates one context and the safe scan bypass; it does not establish full-grid
runtime/scaling, row completeness, or post-fix comprehensive acceptance.

**Ten-replicate isolated pilot (2026-10-20; source overlay, incomplete):**
ran the same `airquality × beta_T=0.5 × Bernoulli` selector with `Nrep=10`,
`REP_FILTER=NA`, both design/model formula branches, forced slow paths, and
the tested prune-scan opt-in. Environment was
`COMPREHENSIVE_FORCE_SLOW_PATHS=1`, `COMPREHENSIVE_FORK=FALSE`,
`EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1`, and
`EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo13-airquality-beta05-rep10.ycJFOb`.
The invocation was capped at 180 seconds total (stricter than the
180-second-per-replicate limit); it exited 0. The sidecar
records arguments `10 1 proportion Bernoulli InferencePropGCompMeanDiff
airquality 0.5 NA rand`, start `2026-10-20T16:06:33.223220Z`, completion
`2026-10-20T16:07:27.139828Z`, and elapsed 53.917 seconds. R was `R Under
development (unstable) (2026-10-13 r90668)`. It captured source namespace
`/home/kapelner/workspace/EDI/R/EDI`, package version 1.0.3,
checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and runner SHA-256
`660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`.
Installed EDI 1.0.3 was built by R 4.7.0 at 2026-10-20 07:40:04 UTC; its
`EDI.so` and the loaded overlay DLL both have SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`. The
sidecar checkout-diff digest is
`80ab9343679a2de5342f7995c1575928f2868309d25cb112633a257622e2e103`.

The isolated CSV contains 120 rows for reps 1–10, 12 per rep, with 120 unique
IDs and no duplicates or missing reps. Each of the four formula contexts has
the three expected function labels; counts are 40 rows each for
`compute_rand_two_sided_pval`, `compute_rand_two_sided_pval(delta=0.5)`, and
`compute_rand_confidence_interval`. All statuses are `ok`, with no skip
reasons or error messages. Coverage truths and `result_1` are finite in every
row; `result_2` is missing only on p-value rows and finite for CI rows. Exact
IDs and rows are preserved in
`/tmp/edi-todo13-airquality-beta05-rep10.ycJFOb/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
(SHA-256 `fee3e62581062fbf4981ecb9ddcfcaebafc015c0441374c259771b8e49ab194a`);
the sidecar SHA-256 is
`4cdc59d5ad6966ae90a366e0ffcb482462f7028182c6991a428801ad7ea825a2`, and
the runner log SHA-256 is
`1f2498833158efc4696caf8db772113fdd06ac5c0e549bd31bee14039fd677b7`. The
sidecar records that the external result file did not exist before the run;
no canonical output was written.

The first-replicate keys, `status`, `result_1`, `result_2`, `coverage_truth`,
and interval-inclusion flags match the earlier `Nrep=40`, `REP_FILTER=1`
pilot exactly across all 12 rows; this supports using `Nrep=10`,
`REP_FILTER=NA` for this pilot slice without changing rep-1 output.

The measured sidecar wall time averages 5.392 seconds per replicate. A naive
linear projection for 40 reps is about 216 seconds for this one selector,
excluding R/package startup; this is only a rough sizing estimate from one
dataset/design/beta, not a runtime guarantee or a full-grid estimate. A
preflight process check found another R process active, so this is not an
idle-host timing acceptance result. The successful 10-replicate slice
establishes that the bounded chunk protocol works
with the prune bypass, but full-selector and full-grid reconciliation remain
open.

**Complete isolated selector pilot (2026-10-20; not full-grid acceptance):**
after the R/Rscript process table was clear, ran the full
`airquality × beta_T=0.5 × Bernoulli` selector with `Nrep=40` and
`REP_FILTER=NA` under a 240-second whole-process cap. Environment was
`COMPREHENSIVE_FORCE_SLOW_PATHS=1`, `COMPREHENSIVE_FORK=FALSE`,
`EDI_COMPREHENSIVE_SKIP_PRUNE_CHECK=1`, and
`EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo13-reps1-40.ZOLn0y`. The runner
exited 0; sidecar interval was `2026-10-20T17:23:50.461286Z` through
`2026-10-20T17:26:33.059009Z` (about 163 seconds). Command arguments were
`40 1 proportion Bernoulli InferencePropGCompMeanDiff airquality 0.5 NA rand`.
R was R-devel `r90668`; checkout R was loaded with `pkgload::load_all(
"R/EDI", compile=FALSE, quiet=TRUE)` (version 1.0.3; HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`); the existing loaded EDI DLL SHA-256
was `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
The output has 480 rows and 480 unique IDs/structural keys: 12 per replicate,
with all four model/design formula pairs crossed with the three expected
`rand` functions (40 rows per pair/function). Every status is `ok`; all 160 CI
rows have finite endpoints and nonmissing `coverage_truth`; there are no error
messages. CSV:
`/tmp/edi-todo13-reps1-40.ZOLn0y/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
(SHA-256 `92c3368e565e6f955b5540d2e287c1dc35f9bba08e2777524aeb96d7a51f8b63`);
sidecar SHA-256 `6ccec75fbba9084678612cfe60ab17edc425bc0343c36510a002472cf9c0a9d1`.
This supersedes the earlier rough 216-second linear projection for this one
selector only; neither the observed runtime nor this single selector closes
the complete-grid timing, provenance, or exact-key reconciliation gates. No
`--apply`, build/install, or canonical result write occurred.

**Distinct five-replicate selector pilot (2026-10-20; partial):** with no
active R/Rscript runner at preflight, ran the predeclared adjacent selector
`airquality × beta_T=0 × Bernoulli` using `Nrep=5`, `REP_FILTER=NA`, the same
forced-slow-path and prune-skip settings, checkout R overlay with compilation
disabled, and a fresh `/tmp` output directory. It exited 0; the sidecar interval
was `2026-10-20T17:37:20.971207Z` through `2026-10-20T17:38:32.041117Z`
(about 71 seconds). Arguments were
`5 1 proportion Bernoulli InferencePropGCompMeanDiff airquality 0 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are in
the provenance sidecar. The CSV contains 60 rows, 60 unique IDs/structural
keys, 12 per rep; all four model/design formula pairs crossed with the three
expected functions have five rows each. All statuses are `ok`; all 20 CI rows
have finite endpoints and nonmissing `coverage_truth`; there are no error
messages. This advances only the beta=0 selector pilot, not full-grid or
post-fix installed-package acceptance. CSV:
`/tmp/edi-todo13-airquality-beta0-Bernoulli.pIAoX7/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
(SHA-256 `bf6e8de5af476497e6a0b6e452ba378b995ff121e6efe66e4bb3a3447c5dbdb3`);
sidecar SHA-256 `2380a470bb83d5a2fe53a8a5678ec569df416686b3bdf9ca60ba9ff1b7a03443`.
No `--apply`, build/install, or canonical result write occurred.

**Next predeclared design selector pilot (2026-10-20; partial):** after
waiting for the active count comprehensive runner to exit, ran
`airquality × beta_T=0 × SPBR` with `Nrep=5`, `REP_FILTER=NA`, the same
forced-slow-path/prune-skip settings, checkout R overlay with compilation
disabled, a fresh `/tmp` destination, and a 240-second cap. It exited 0; the
sidecar interval was `2026-10-20T17:42:35.990683Z` through
`2026-10-20T17:43:46.686647Z` (about 71 seconds). Arguments were
`5 1 proportion SPBR InferencePropGCompMeanDiff airquality 0 NA rand`. R-devel
`r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are in
the sidecar. The CSV contains 60 rows, 60 unique IDs/structural keys, 12 per
rep, all four formula pairs crossed with the three expected functions (five
rows per pair/function). All statuses are `ok`; all 20 CI rows have finite
endpoints and nonmissing `coverage_truth`; no error messages occurred. This is
one five-replicate SPBR selector pilot only, not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta0-SPBR.PygJI9/comprehensive_tests_results_nc_1_proportion_filtered_design-SPBR_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
(SHA-256 `07424215f42fd6c6ec1ab584b835ba11f0bf0d3641ab2b8912136af511e21a1e`);
sidecar SHA-256 `adfb3c4a74c09cfd2a594cfeab043170ef60ada9985d46fade12f504d9e1d320`.
No `--apply`, build/install, or canonical result write occurred.

**Next predeclared design selector pilot (2026-10-20; partial):** after the
R/Rscript process table was clear, ran `airquality × beta_T=0 × FixediBCRD`
with `Nrep=5`, `REP_FILTER=NA`, the tested forced-slow-path/prune-skip
settings, checkout R loaded with compilation disabled, a fresh `/tmp`
destination, and a 240-second cap. It exited 0; the sidecar interval was
`2026-10-20T17:55:08.660109Z` through `2026-10-20T17:56:04.188676Z` (about
56 seconds). Arguments were
`5 1 proportion FixediBCRD InferencePropGCompMeanDiff airquality 0 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, and all four model/design formula
pairs crossed with the three expected functions (five rows per pair/function).
All statuses are `ok`; all 20 CI rows have finite endpoints and nonmissing
`coverage_truth`; there are no error messages. This is one five-replicate
FixediBCRD selector pilot only, not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta0-FixediBCRD.aH7riu/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
(SHA-256 `2250958d94ffdf67008710b093bf433ad46a8888489b20bd85d9caf36d4088a3`);
sidecar:
`/tmp/edi-todo13-airquality-beta0-FixediBCRD.aH7riu/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv.provenance-20261020T175508.660109-pid5.rds`
(SHA-256 `d171566778776adbfe4a19459d01ff08494a13d4cffec2c122334738d60ca1b4`).
No `--apply`, build/install, or canonical result write occurred; complete
eligible-grid regeneration and exact-key reconciliation remain open.

**Next predeclared design selector pilot (2026-10-20; partial):** after the
active R/Rscript runner exited, ran `airquality × beta_T=0 × FixedBlocking`
with `Nrep=5`, `REP_FILTER=NA`, the tested forced-slow-path/prune-skip
settings, checkout R loaded with compilation disabled, a fresh `/tmp`
destination, and a 240-second cap. It exited 0; the sidecar interval was
`2026-10-20T18:01:16.263357Z` through `2026-10-20T18:02:19.796341Z` (about
64 seconds). Arguments were
`5 1 proportion FixedBlocking InferencePropGCompMeanDiff airquality 0 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, and all four model/design formula
pairs crossed with the three expected functions (five rows per pair/function).
All statuses are `ok`; all 20 CI rows have finite endpoints and nonmissing
`coverage_truth`; no row errors occurred. The log recorded the expected
`equal_block_sizes=TRUE` retry because strata were unequal (33, 41), after
which the run completed. This is one five-replicate FixedBlocking selector
pilot only, not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta0-FixedBlocking.CbZG9i/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
(SHA-256 `9adc1f811a5ead1c725c07ccb3ca4ac3629a9254174f49d9ff6e08025006b2ee`);
sidecar:
`/tmp/edi-todo13-airquality-beta0-FixedBlocking.CbZG9i/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv.provenance-20261020T180116.263357-pid5.rds`
(SHA-256 `f5ea2d12581cbabd5a0a59027136c14c545874907d3811f185f6ff28020d98bd`).
No `--apply`, build/install, or canonical result write occurred; full-grid
regeneration and exact-key reconciliation remain open.

**Next predeclared design selector pilot (2026-10-20; partial):** after the
R/Rscript process table was clear, ran `airquality × beta_T=0 ×
FixedMatchingGreedy` with `Nrep=5`, `REP_FILTER=NA`, the tested
forced-slow-path/prune-skip settings, checkout R loaded with compilation
disabled, a fresh `/tmp` destination, and a 240-second cap. It exited 0; the
sidecar interval was `2026-10-20T18:05:22.149233Z` through
`2026-10-20T18:06:19.348261Z` (about 57 seconds). Arguments were
`5 1 proportion FixedMatchingGreedy InferencePropGCompMeanDiff airquality 0 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, and all four model/design formula
pairs crossed with the three expected functions (five rows per pair/function).
All statuses are `ok`; all 20 CI rows have finite endpoints and nonmissing
`coverage_truth`; no row errors occurred. This is one five-replicate
FixedMatchingGreedy selector pilot only, not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta0-FixedMatchingGreedy.h4uDq1/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedMatchingGreedy_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
(SHA-256 `fd4bfbc920d15fd2b6d2b1e50f6c46e0df5dd89c529c6583403efdfc07270c60`);
sidecar:
`/tmp/edi-todo13-airquality-beta0-FixedMatchingGreedy.h4uDq1/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedMatchingGreedy_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv.provenance-20261020T180522.149233-pid5.rds`
(SHA-256 `307243cf39af9048fa8aeca8cb947d67ab6961714300fd9cd4001b92c9f13ad8`).
No `--apply`, build/install, or canonical result write occurred; full-grid
regeneration and exact-key reconciliation remain open.

**Next predeclared selector pilot (2026-10-20; partial):** after confirming
the R/Rscript process table was clear, ran `airquality × beta_T=0.5 × SPBR`
with `Nrep=5`, `REP_FILTER=NA`, the tested forced-slow-path/prune-skip
settings, checkout R loaded with compilation disabled, a fresh `/tmp`
destination, and a 240-second cap. It exited 0; the sidecar interval was
`2026-10-20T18:10:54.245414Z` through `2026-10-20T18:11:25.330416Z` (about
31 seconds). Arguments were
`5 1 proportion SPBR InferencePropGCompMeanDiff airquality 0.5 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, all four model/design formula pairs,
and the three expected functions (five rows per pair/function). All statuses
are `ok`; all 20 CI rows have finite endpoints and nonmissing `coverage_truth`;
no row errors occurred. This is one five-replicate SPBR selector pilot only,
not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta05-SPBR.dGSa2Q/comprehensive_tests_results_nc_1_proportion_filtered_design-SPBR_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
(SHA-256 `999582b6314d0e0b035f59f6739db130ed7450db73099ccb1129edeefbca52c4`);
sidecar:
`/tmp/edi-todo13-airquality-beta05-SPBR.dGSa2Q/comprehensive_tests_results_nc_1_proportion_filtered_design-SPBR_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T181054.245414-pid5.rds`
(SHA-256 `4bd80dfb05795656fe902bbe3fc00382c1e103c6c4d25074c3f6492a10ac7e64`).
No `--apply`, build/install, or canonical result write occurred; full-grid
regeneration and exact-key reconciliation remain open.

**Next predeclared selector pilot (2026-10-20; partial):** after waiting for
the active survival R/Rscript runner to exit, ran
`airquality × beta_T=0.5 × FixediBCRD` with `Nrep=5`, `REP_FILTER=NA`, the
tested forced-slow-path/prune-skip settings, checkout R loaded with
compilation disabled, a fresh `/tmp` destination, and a 240-second cap. It
exited 0; the sidecar interval was `2026-10-20T19:29:17.259746Z` through
`2026-10-20T19:31:38.926511Z` (about 142 seconds). Arguments were
`5 1 proportion FixediBCRD InferencePropGCompMeanDiff airquality 0.5 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, all four model/design formula pairs,
and the three expected functions (five rows per pair/function). All statuses
are `ok`; all 20 CI rows have finite endpoints and nonmissing `coverage_truth`;
no row errors occurred. This is one five-replicate FixediBCRD selector pilot
only, not full-grid acceptance. CSV:
`/tmp/edi-todo13-airquality-beta05-FixediBCRD.4dyDU5/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
(SHA-256 `eeca0de70f6308e463346accee75198293a8891d4edd5fdb4630f4dae4ce58f2`);
sidecar:
`/tmp/edi-todo13-airquality-beta05-FixediBCRD.4dyDU5/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T192917.259746-pid5.rds`
(SHA-256 `581e47f37fd67cc5ea4eb1d6cb5cdce1e46095d2a0cd66561fc0bcc1de160b14`).
No `--apply`, build/install, or canonical result write occurred; full-grid
regeneration and exact-key reconciliation remain open.

**Next predeclared selector pilot (2026-10-20; partial):** after the active
R/Rscript workloads exited, ran `airquality × beta_T=0.5 × FixedBlocking`
with `Nrep=5`, `REP_FILTER=NA`, the tested forced-slow-path/prune-skip
settings, checkout R loaded with compilation disabled, a fresh `/tmp`
destination, and a 240-second cap. It exited 0; the sidecar interval was
`2026-10-20T19:35:43.374376Z` through `2026-10-20T19:37:56.245854Z` (about
133 seconds). Arguments were
`5 1 proportion FixedBlocking InferencePropGCompMeanDiff airquality 0.5 NA rand`.
R-devel `r90668`, EDI 1.0.3, checkout HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
recorded in the sidecar. The CSV contains 60 rows with 60 unique IDs and
structural keys, 12 rows per replicate, all four model/design formula pairs,
and the three expected functions (five rows per pair/function). All statuses
are `ok`; all 20 CI rows have finite endpoints and nonmissing `coverage_truth`;
no row errors occurred. The log recorded `equal_block_sizes=TRUE` retries for
unequal strata (33, 41), followed by successful completion. This is one
five-replicate FixedBlocking selector pilot only, not full-grid acceptance.
CSV:
`/tmp/edi-todo13-airquality-beta05-FixedBlocking.6Jj8Hj/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
(SHA-256 `8c4222f17ce801a4a745c3af5a190836795c070ea5267432de91bd7977dcbf6c`);
sidecar:
`/tmp/edi-todo13-airquality-beta05-FixedBlocking.6Jj8Hj/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T193543.374376-pid5.rds`
(SHA-256 `9689507193a0714cb840b7f5ad512a168811eb21ba37db8d3f320a0cee200d24`).
No `--apply`, build/install, or canonical result write occurred; full-grid
regeneration and exact-key reconciliation remain open.

**Focused installed regression recheck (2026-10-20):**
`test-prop-gcomp-mean-diff-randomization-worker-estimate-not-all-na-reference.R`
passed all 6 assertions with no failures, warnings, or skips against installed
EDI 1.0.3. `packageDescription("EDI")$Built` reports
`R 4.7.0; x86_64-pc-linux-gnu; 2026-10-19 20:31:50 UTC`; the loaded package
path is `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, and the loaded
DLL is `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
(SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`,
mtime `2026-10-19 23:47:15 +0300`). This is a fresh installed-package
regression check; the package metadata does not identify its source commit,
so it does not establish checkout/native parity. It does not close TODO-6's
post-fix comprehensive-row generation, provenance, or key/status/value
reconciliation. No build/install or canonical result write was performed.

**Read-only target-artifact recheck (2026-10-20):** a recursive filename search
under `/tmp` found one copy of the expected filtered proportion/rand output,
`/tmp/edi-v105-r6-benchmark.eQ0PpT/R/package_tests/comprehensive_tests_results_nc_1_proportion_filtered_class-InferencePropGCompMeanDiff_family-rand.csv`
(mtime 2026-09-09 02:43, 2,358,350 bytes). Its SHA-256
`27d257400aa6a1e0586faa1e74cb93f4e292d57989dd6ea5901e3f34a2b12338` is
identical to the tracked canonical filtered CSV, so this is the same old
pre-fix artifact, not a post-fix isolated run. Other `/tmp` proportion-wide
CSV snapshots were dated 2026-10-09 and 2026-10-15, but do not provide the
target filtered artifact with post-fix package/install provenance. The
required evidence remains a new isolated harness output from the post-fix
installed package, with package/DLL identity captured separately, exact unique
`id` key-set reconciliation across both formulas and the full eligible grid,
and row-level status/result/coverage validation before any merge. No result
CSV was read for values, changed, or merged.

**Current retained-pilot inventory, 2026-10-21 (read-only):** the
`/tmp/edi-todo13-*` inventory contains 29 result CSVs (3,120 rows; 1,740
unique IDs) against the source-derived 43,200-key roster. All observed IDs
are in-roster, leaving 41,460 absent; all rows have `status=ok`, and the 372
repeated-key groups have no conflicting result/status/error/coverage payloads.
Twenty-eight CSVs have byte-count/SHA-256-verified receipts (12 schema v1,
16 schema v2); schema-v2 artifacts span four package-payload hashes and three
DLL hashes, while all receipts span five runner hashes. One 336-row
airquality/Bernoulli/beta=.5 CSV remains unreceipted. The iris beta=0
Bernoulli five-replicate CSV is
`/tmp/edi-todo13-iris-beta0-Bernoulli-5rep-final/results/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-iris_beta-0_family-rand.csv`
(SHA-256 `6cd266d9c31c0e1245218ddc56ee69e39dbaa5527f4ecf5dfcbefb97aeeecc60`);
its verified schema-v2 receipt records package-payload SHA-256
`58f809147f419372f9e82792e2ad6de097b3cbfede3371f9fac9d4ddd0283afd`, DLL
SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
and runner SHA-256
`72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`, matching
the current runner. The staged 12-row iris one-replicate file adds no unique
IDs; its rows exactly overlap the five-replicate pilot. This is pilot evidence
only: no complete run, homogeneous authenticated acceptance cohort, or full
acceptance reconciliation exists. No CSV was modified or merged.

**Receipt-to-file pairing recheck, 2026-10-21 (read-only):** the current
filename inventory has 29 matching result CSVs and 29 provenance sidecars,
but only 28 one-to-one CSV/sidecar pairs. The extra sidecar names a
`pte_example`/beta=.5/`FixedBinaryMatch` output whose matching result CSV is
not in the retained inventory; the unreceipted result remains the 336-row
airquality/Bernoulli/beta=.5 CSV. Thus the sidecar count is not a 29th
accepted result receipt. The earlier counts and acceptance gates are
unchanged: 1,740 unique pilot keys, 41,460 roster keys absent, heterogeneous
package/DLL/runner identities, and no complete post-fix installed run or
canonical merge authorization.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
