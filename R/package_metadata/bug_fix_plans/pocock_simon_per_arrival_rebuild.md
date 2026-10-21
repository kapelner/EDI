# Pocock–Simon Sequential Design: O(t) Work per Arrival (O(n²) per Trial)

> **Depends on:** nothing architectural. Touches
> `design_seq_one_by_one_abstract.R → add_one_subject()` (L58–159: the
> `rbindlist` append at L149 and the model-matrix rebuild at L157) and
> `design_seq_one_by_one_pocock_simon.R` (`assign_wt()` L118–135,
> `ensure_factor_metadata()` L161–187, `get_subject_levels_idx()`
> L176+). `design_construction_overhead.md` (`release_v1_0_5.md → TODO-59`)
> touches the same model-matrix builder from the fixed-design side;
> independent in content, rebase the second onto the first.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-60`).

Written 2026-10-07, user decision. Found by the 2026-10-07 extension of
`R/benchmark/benchmark_model_fits.R` (new "Design Generation Performance"
table vs. `carat` and `Minirand`), root-caused the same day with `Rprof`
against the installed CRAN EDI 1.0.2 (no rebuild). Under the 2026-09-23
split rule this is a misfiring performance path that already shipped, not
new capability.

## Why

A full Pocock–Simon sequence in EDI times at 0.0014x of `carat` (which
runs the whole sequence in C++) and 0.3x of `Minirand` (an R loop). The
per-arrival cost in EDI is 3.0 ms at the start of the sequence and 3.7 ms
near the end, and it grows with t. The minimization step itself,
`pocock_simon_assign_and_update_cpp()`, updates a levels × 2 count matrix
in place and is O(number of strata columns). Everything around it is
O(t).

## Findings (Rprof, installed EDI 1.0.2, 4 strata columns)

**F1. `rbindlist(list(Xraw, x_new))` copies the whole table on every
arrival** (`add_one_subject()` L149). O(t) per arrival, O(n²) per trial.

**F2. The full model matrix is rebuilt on every arrival once
`t > ncol(Xraw) + 2`** (`add_one_subject()` L157 →
`covariate_impute_if_necessary_and_then_create_model_matrix()`). The
Pocock–Simon assignment rule never reads the model matrix: it works on
the raw strata columns via `get_subject_levels_idx()`. For this class
the rebuild (`as.data.table` copy, data.table column selections,
`count_unique_values_cpp`, `model.matrix`; about 1 ms at n = 1000, growing
with t) is pure waste during the sequence. The same code path runs for
every other `DesignSeqOneByOne*` class whether or not its rule uses `X`.

**F3. `ensure_factor_metadata()` rescans every strata column in full on
every arrival** (L161–187: `unique(ifelse(is.na(col_vals), "NA",
as.character(col_vals)))` over all t rows per column), and runs twice per
arrival: once in `assign_wt()` (L119) and again inside
`get_subject_levels_idx()` (L176). O(t · k) per arrival. Only the new
row can introduce a new level.

**F4. Per-arrival row extraction goes through data.table `[`**
(`private$Xraw[private$t, ]`, ~0.1 ms) when the rule only needs k scalar
values, available as `Xraw[[col]][t]`.

## Proposal

All items are bit-preserving: the assignment sequence is a deterministic
function of the per-arrival strata indices, the running counts and the
RNG stream consumed by `pocock_simon_assign_and_update_cpp()`. None of
the items change what that kernel receives or in what order. The test is
a fixed-seed assignment sequence identical to 1.0.2's on several
fixtures (including one with a level first seen late in the sequence, and
one with `NA` strata values).

## TODOs

- [x] TODO-1: **Per-arrival harness, before any change.** Time
  `add_one_subject()` + `assign_wt()` at t = 10, 100, 500, 1000 and plot
  cost against t; the slope is the bug. Promote to `R/benchmark/` next to
  the design table. Installed package only.

- [x] TODO-2: **Incremental level bookkeeping (F3).** Make
  `ensure_factor_metadata()` O(k): keep the full rescan only when
  `strata_level_rows` is `NULL` (first call or after `duplicate()`), and
  otherwise register only the keys of row t. Remove the duplicate call
  from `get_subject_levels_idx()` or make it a no-op after the first
  registration. Also read the k values directly (`Xraw[[col]][t]`) instead
  of `Xraw[t, ]` (F4). The current source implements this: the full scan is
  limited to first use/reinitialization, subsequent arrivals inspect only
  row `t`, and the sequential numeric-row lookup reads `Xraw[[col]][i]`
  directly. The focused reference test covers incremental level discovery,
  first-arrival missing strata versus a literal `"NA"` category, and stable
  count-row mappings. Parse-only validation passed on 2026-10-16. Native
  execution against the current checkout remains unverified until an
  authorized rebuild/install; that runtime gate is tracked with TODO-5's
  post-change validation, not as unfinished implementation work here.

- [x] TODO-3: **Do not rebuild the model matrix during the sequence for
  rules that never read it (F2).** Add a class-level private flag (for
  example `assignment_rule_reads_model_matrix`, default `TRUE` to
  preserve current behavior) that `DesignSeqOneByOnePocockSimon` sets to
  `FALSE`; `add_one_subject()` skips the rebuild when it is `FALSE` and
  marks the matrix stale. Build on first access after the sequence (same
  staleness mechanism as `design_construction_overhead.md → TODO-3`, if
  that lands first; otherwise a local flag). Audit each
  `DesignSeqOneByOne*` subclass's `assign_wt()` and set the flag where
  the rule provably never touches `X`/`Ximp` (Efron, Bernoulli-style,
  Pocock–Simon; the covariate-adaptive and CARA rules keep `TRUE`).

- [x] TODO-4: **Amortize the append (F1).** Preallocate `Xraw` with
  capacity when `n` is known (fixed-sample sequential designs) and fill
  with data.table `set()`, or grow geometrically; expose the first t rows
  to every reader via the existing accessors. If the preallocation
  interferes with `rbindlist`'s `use.names`/new-column handling
  (`allow_new_cols = TRUE`), restrict it to the no-new-columns path and
  keep the current append as the fallback.

- [ ] TODO-5: **Re-run the design table.** Acceptance: per-arrival cost
  flat in t and ≤ 0.5 ms at k = 4; fixed-seed assignment sequences
  identical to 1.0.2 on the TODO-1 fixtures. Record the complete n=1000
  `carat`/`Minirand` comparison as context in `benchmark_model_fits.md`, not
  as a ratio gate: the ≤0.5 ms per-arrival bound allows up to 500 ms for
  1000 public R calls, while 10x the recorded batch-C++ `carat` time is only
  44.1 ms and is therefore incompatible with the per-arrival target.

  Installed-package rerun on 2026-10-14 (EDI 1.0.3; n=1000, batch=20,
  five repeats) measured per-arrival medians of 0.35 ms at t=10, 0.35 ms at
  t=100, 0.35 ms at t=500, and 0.40 ms at t=1000; whole-sequence median was
  364.05 ms. The focused level/missing-stratum/reference test passed 67
  assertions, including a fixed-seed eight-row expected assignment vector.
  The per-arrival timing is flat and below 0.5 ms, but this run did not
  compare the full sequence against `carat` or all TODO-1 fixtures against
  EDI 1.0.2, so TODO 5 remains open.

  **Additional installed rerun 2026-10-14 (under concurrent CPU load):**
  `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5` completed
  against installed EDI 1.0.3 without writing a CSV. Per-arrival medians were
  0.50 ms at t=10, 0.70 ms at t=100, 0.50 ms at t=500, and 0.45 ms at
  t=1000; whole-sequence median was 503.05 ms. Three other R jobs were each
  using approximately one CPU during this run, and the observed range at
  t=1000 extended to 1.25 ms. This load-contended sample is not clean
  acceptance evidence: it is broadly flat but does not meet the strict
  <=0.5 ms median criterion at every checkpoint. TODO 5 remains open; rerun
  under isolated load before release closure.

  **Additional installed rerun 2026-10-14 (high concurrent R load):** the same
  command, `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5`,
  completed against installed EDI 1.0.3 without writing a CSV. Per-arrival
  medians were 1.75 ms at t=10, 3.55 ms at t=100, 2.75 ms at t=500, and
  1.30 ms at t=1000; whole-sequence median was 1486.70 ms. Multiple concurrent
  R jobs were active during the run, so these measurements are diagnostic,
  not a clean comparison; they fail the 0.5 ms target at every checkpoint.
  This reinforces the need for an isolated timing run and does not close
  TODO-5.

  **Read-only scratch-artifact audit 2026-10-18:** four timing-only CSVs are
  retained under `/tmp`: `/tmp/edi_v105_todo60_pocock_simon_arrivals.csv`
  (medians 0.35, 0.35, 0.35, 0.40 ms at t=10/100/500/1000), plus
  `/tmp/todo60_pocock_benchmark.csv`, `_fast.csv`, and `_fast3.csv` (medians
  respectively 1.4/1.6/1.4/1.4, 1.0/1.0/1.0/1.0, and
  0.667/1.0/0.667/1.0 ms). Each contains only `t, median_ms, min_ms,
  max_ms`; no companion run log, source SHA, installed package identity, or
  CPU-load record was found in the bounded `/tmp` search. The first CSV's
  values match the previously recorded 2026-10-14 result, but the file alone
  cannot authenticate its run conditions; the remaining CSVs do not meet the
  strict per-checkpoint 0.5 ms target. None establishes fixed-seed parity
  against EDI 1.0.2. Treat these as diagnostic scratch outputs, not
  acceptance evidence. TODO-5 still requires a provenance-pinned isolated
  timing run and an authentic 1.0.2 assignment-vector comparison; do not
  infer either result from these files.

  **Read-only parity-artifact check 2026-10-18:** the only retained 1.0.2
  candidate found is `/tmp/claude-1000/tmp.tRezeJm6cW/EDI_1.0.2.tar.gz`
  (SHA-256 `01f79c8d52678cbd95af1b7ed25609a8f1c340f059531939c9c82fddd5c47af9`).
  Its `DESCRIPTION` identifies source version 1.0.2, but the archive contains
  source files only and no `.so`, `.dll`, or `.dylib`; no signature or trusted
  checksum was found to authenticate it as the exact CRAN artifact. Running
  that source would require compiling, which is not authorized here. Thus it
  cannot supply the plan's isolated installed-1.0.2 comparison, and the
  baseline-vector half of TODO-5 remains open.

  **Installed focused correctness recheck, 2026-10-20:**
  `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
  passed against installed EDI 1.0.3 (`testthat::test_file(...,
  package="EDI")`; 67 expectations, 0 failures/warnings/skips). This is the
  bounded regression for incremental level discovery, stable count-row
  mapping, and the first-arrival missing stratum versus a literal `"NA"`
  category, including the fixed-seed assignment-vector fixture. The loaded
  package path was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its DLL was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  14,727,184 bytes, mtime 2026-10-20 09:38:02 +0300, MD5
  `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  Checkout `R/EDI/src/EDI.so` is byte-identical. The package has no embedded
  Git SHA; checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  and an unrelated native source file is modified in the worktree. This
  validates the available installed artifact's focused behavior, not a new
  current-head native build. No source loading, build/install, benchmark, or
  result regeneration occurred. TODO-5's isolated per-arrival timing and
  authentic EDI 1.0.2 assignment-vector comparison remain open.

  **Model-matrix deferral call-count regression, 2026-10-20:** broadened the
  existing `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
  fixture to spy on the private model-matrix builder. It asserts zero builder
  calls across Pocock–Simon enrollment and exactly one on first post-enrollment
  access, while retaining the fixed-seed assignment, incremental level-map,
  and independent fit checks. The focused file passed with checkout R loaded
  via `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; namespace
  `/home/kapelner/workspace/EDI/R/EDI`, temporary DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, package
  version 1.0.3. No build/install occurred. This proves the R-layer deferral
  contract for the fixture, not timing acceptance, current-head native build
  provenance, or authentic EDI 1.0.2 assignment-vector parity.

### TODO-5 post-gate run protocol (prepared 2026-10-16)

Do not run until TODO-56 is terminal, the current checkout has an explicitly
authorized `EDI_UNITY=0` rebuild/install, and the machine is otherwise idle.
Record `git rev-parse HEAD`, installed `packageVersion("EDI")` and
`find.package("EDI")`, build/install time, R/platform versions, the exact
command, and whether any competing CPU-heavy process was active. Keep the
benchmark stdout and its optional CSV together as one isolated run record.

1. For asymptotic/per-arrival acceptance, run the current installed package
   with `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5`.
   This fixes `n=1000`, 20 batched designs, five repeats, four strata columns,
   covariate seed 6001 and assignment seed 6002; the harness reports
   per-arrival median/min/max at `t={10,100,500,1000}` and whole-sequence
   median. Require each checkpoint median `<= 0.5 ms` and no material
  increasing trend from t=10 to t=1000. Preserve the printed result; when an
  output CSV path is supplied, the harness now writes an adjacent provenance
  sidecar with package/DLL hash, checkout HEAD and tracked-diff/worktree state,
  seeds, R/platform/session, relevant thread environment, and host load/CPU
  affinity at start and finish. The harness still does not emit each
  replicate's raw timing, so do not describe min/max as a confidence interval.

2. For semantic parity, run the same explicit fixture in an isolated EDI
   1.0.2 environment and the rebuilt checkout: the eight-row factor fixture
   in `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
   (seed 601, `strata_cols=c("g","h")`, weights `c(1,2)`, `p_best=0.8`,
   including late levels and missing values). Capture the full `X`, factor
   levels, constructor arguments, seed, and both complete assignment vectors;
   require exact vector identity and separately verify the expected vector
   `c(1,0,0,1,0,1,0,0)`. The source-test expectation alone is not evidence
   that EDI 1.0.2 produced the same vector. If 1.0.2 cannot be run, report
   that baseline comparison as unavailable rather than infer parity.

3. For release-table context, compare complete n=1000 workflows against the
   existing `carat::PocSimMIN()` and `Minirand` rows in
   `R/benchmark/benchmark_model_fits.md`, recording their two-factor fixture
   and ten warmed-run convention separately from the four-column focused
   harness above. `carat` processes the whole table in C++ and uses a
   different interface/imbalance criterion, so its 4.41 ms result is context,
   not a feasible pass threshold for EDI's 1000 public R arrivals. Retain the
   R-loop Minirand comparison as contextual evidence, not an algorithmically
   identical parity claim. Do not claim the original “within 10x of carat”
   criterion; at 0.5 ms per EDI arrival that cap permits 500 ms total, while
   10x the recorded carat time is only 44.1 ms.

This protocol is readiness documentation only: no benchmark or package
execution was performed while TODO-56/rebuild authorization gates remain.
The optional output sidecar/helper has a focused test for clean, dirty, and
unavailable Git-command states; it does not itself validate the current
installed benchmark artifact.

## Implementation and validation (2026-10-09)

TODOs 1, 3--4 are implemented. TODO-2's incremental bookkeeping source is
implemented but is reopened below for a newly discovered first-arrival edge
case. Fixed-size Pocock--Simon designs preallocate
`Xraw`, expose only the enrolled prefix, fill schema-compatible rows in place,
and fall back to `rbindlist` when a late factor schema cannot be filled safely.
Their assignment rule opts out of the generic model-matrix rebuild and leaves
the shared stale flag for the first inference/getter consumer. Level metadata
now scans all rows only for initial/recovery construction; ordinary arrivals
register one key per strata column and return the current row indices directly.

`R/benchmark/benchmark_pocock_simon_arrivals.R` is the reusable installed- or
source-package harness for t = 10, 100, 500, and 1000 plus the whole sequence.
The non-compiling source-loaded run was flat in t. Seven warmed whole-sequence
runs at n=1000 had times 672, 502, 525, 532, 542, 468, and 495 ms (median 525
ms, about 0.525 ms/arrival). That median misses the 0.5 ms acceptance target;
individual faster runs do not establish it. An installed build is required for
the release acceptance measurement.

The fixed-seed late-level/NA fixture remains exactly
`c(1, 0, 0, 1, 0, 1, 0, 0)`, with the expected stable level-row map and a
deferred matrix identical after first access. The focused metadata suite passes
53 expectations, the all-design seed suite passes 25, and five sequential
schema/type/bootstrap suites pass 62 more expectations.

### First-arrival missing-stratum correction (2026-10-12)

Static review found that the generic first-arrival cleanup removed every
missing column before Pocock--Simon could register its strata.  A first subject
with a missing declared stratum therefore lost that required column, despite
this plan's missing-level contract.  The cleanup now retains declared strata
columns and only drops other missing first-row covariates.  A public regression
adds a missing first stratum followed by a literal `"NA"` category and asserts
that both enroll and map to different level rows.  TODO-2 remains open until
that added regression is run against a rebuilt package; the earlier 53-test
result did not cover this first-arrival case.

**Source-loaded follow-up, 2026-10-20:** the focused reference file, including
the first-arrival missing-stratum regression, passed 67/67 expectations after
loading current checkout R sources with
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE, export_all = FALSE)`;
the 10 test blocks had no failures, warnings, or skips. The namespace path was
`/home/kapelner/workspace/EDI/R/EDI`; pkgload used a temporary copy of the
available EDI 1.0.3 native DLL. R was `R Under development (unstable)
(2026-10-13 r90668)`. Checkout `R/EDI/src/EDI.so` and installed
`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had the
same SHA-256:
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`. No
compile or install occurred. This validates the R fix against that native
library, not a matching current-head build. TODO-2's source behavior is
confirmed; TODO-5's installed timing, authentic 1.0.2 assignment-vector
parity, and release-provenance gates remain open.

TODO-5 remains open for the prohibited installed-package rebuild and report
refresh. Its additional “within 10x of carat” criterion is infeasible under
the same item allowing up to 0.5 ms per arrival: 1000 public R calls at that
bound already total 500 ms, whereas the recorded batch-C++ carat row is 4.41
ms (a 44.1 ms 10x ceiling). Meeting that criterion requires the explicitly
out-of-scope whole-sequence C++ API, so the installed rerun should assess the
flat/0.5 ms arrival criterion and compare honestly with the R-loop Minirand row.

**Static complexity review and focused installed test, 2026-10-18:** the
current compatible-schema path fills one preallocated row, skips the
Pocock--Simon model-matrix rebuild, and sends one level index per strata
column to the assignment kernel. This supports O(k) per arrival when the
factor-level maps remain fixed or bounded. Registering an unseen level
searches the accumulated per-column map and may expand/copy the counts matrix;
cost can therefore depend on the number of observed levels as cardinality
grows. The focused level/missing-stratum test passed 67 expectations with no
failures or warnings against installed EDI 1.0.3 (built 2026-10-18 00:57:28
UTC; `EDI.so` MD5 `dd43c5d0e11708aea17ba82b900f66d1`). The installed metadata
does not record a checkout SHA, so this pass is installed-package evidence,
not validation of newer checkout source. The test checks correctness and
stable mappings; it does not count operations or establish timing acceptance.
TODO-5 remains open for the isolated, provenance-pinned timing run and the
authentic EDI 1.0.2 assignment-vector replay described above.

**Installed benchmark diagnostic, 2026-10-20 (not acceptance):** ran
`Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5 /tmp/edi-v105-todo60-bench-n8DtfP/benchmark.csv`
against installed EDI 1.0.3 (Built 2026-10-19 20:31:50 UTC; R-devel
r90668). Per-arrival medians at t=10/100/500/1000 were 0.50/0.70/0.45/0.65
ms; whole-sequence median was 509.95 ms. The strict <=0.5 ms checkpoint
criterion fails at t=100 and t=1000. No R job or competing user process was
visible at start, but system load ranged 3.19--3.64 on 12 CPUs, so this was
not a strictly idle/acceptance-clean run. The recorded checkout HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the relevant implementation,
focused-test, and benchmark files were clean, and no local build occurred.
Installed DLL SHA-256 was
`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
The retained CSV is `/tmp/edi-v105-todo60-bench-n8DtfP/benchmark.csv`
(SHA-256 `3a8fab5447a1aabe261597c62f25a393ca5eeab27d3d1542cbe219ce04fec88b`).
This diagnostic does not close the timing gate; the authentic EDI 1.0.2
assignment-vector comparison remains open as well.

**Installed R-layer provenance follow-up, 2026-10-21:** the optional
benchmark sidecar now records the loaded EDI namespace path and a deterministic
SHA-256 over the sorted relative paths and per-file hashes under its `R/`
directory. The focused provenance test passed 23 expectations, including a
synthetic payload-change check and a digest of the actually loaded installed
namespace. This closes the harness's prior installed-R-layer fingerprint gap;
it does not authenticate historical timing CSVs, establish timing acceptance,
or supply EDI 1.0.2 assignment vectors. No benchmark, build, or install ran.
TODO-5 remains open.

**Operation-count guard validation:** the focused level-rows reference test,
including the operation-count assertions, passed 86 expectations across 10
test blocks against installed EDI 1.0.3. The installed and checkout
`R/EDI/src/EDI.so` files have SHA-256
`ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`. The
exact invocation is not recorded here. This is installed-package test evidence,
not a timing result or proof that the current checkout R source was loaded.
The assertions guard against re-keying the enrolled prefix and accidental
matrix construction; they do not bound named-map lookup or matrix resize/copy
cost. TODO-5's isolated timing and authentic EDI 1.0.2 parity gates remain
open.

**Current artifact/source reconciliation, 2026-10-21 (read-only):** the
retained Oct 20 `/tmp/edi-v105-todo60-bench-n8DtfP/benchmark.csv` remains
SHA-256 `3a8fab5447a1aabe261597c62f25a393ca5eeab27d3d1542cbe219ce04fec88b`;
only its 237-byte CSV and 184-byte stdout are present, with no adjacent
provenance sidecar. Its per-arrival medians (0.50/0.70/0.45/0.65 ms at
t=10/100/500/1000) miss the <=0.5 ms limit at t=100 and t=1000, and the
recorded host load was 3.19--3.64 on 12 CPUs. The operation-count test result
(86 expectations) is installed EDI 1.0.3 evidence with no recorded invocation;
it does not establish current checkout R behavior or bound level-map lookup
and matrix resize/copy costs. Static inspection of current R source confirms
the compatible-schema preallocated row path, incremental level registration,
and Pocock--Simon opt-out from assignment-time model-matrix rebuilds, but this
does not authenticate a timed run. The 23-assertion sidecar test validates
future instrumentation only and cannot retroactively authenticate the CSV.
Next, obtain an authenticated EDI 1.0.2 fixed-seed assignment-vector baseline
for parity; then, in an authorized quiet-host window, run the installed
acceptance command from TODO-5 with a fresh output path and its provenance
sidecar. No benchmark, build, install, or canonical write occurred in this
audit.

## Out of scope

- Moving the whole sequence into C++ as `carat` does (the batch
  `generate_permutations_pocock_simon_cpp()` already exists for
  rerandomization; the per-arrival API must stay in R because the user
  supplies each subject).
- Fixed-design construction cost (`design_construction_overhead.md`).
