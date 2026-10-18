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
   increasing trend from t=10 to t=1000. Preserve the printed result and
   record the host/load fields above; the existing harness does not emit each
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

TODO-5 remains open for the prohibited installed-package rebuild and report
refresh. Its additional “within 10x of carat” criterion is infeasible under
the same item allowing up to 0.5 ms per arrival: 1000 public R calls at that
bound already total 500 ms, whereas the recorded batch-C++ carat row is 4.41
ms (a 44.1 ms 10x ceiling). Meeting that criterion requires the explicitly
out-of-scope whole-sequence C++ API, so the installed rerun should assess the
flat/0.5 ms arrival criterion and compare honestly with the R-loop Minirand row.

## Out of scope

- Moving the whole sequence into C++ as `carat` does (the batch
  `generate_permutations_pocock_simon_cpp()` already exists for
  rerandomization; the per-arrival API must stay in R because the user
  supplies each subject).
- Fixed-design construction cost (`design_construction_overhead.md`).
