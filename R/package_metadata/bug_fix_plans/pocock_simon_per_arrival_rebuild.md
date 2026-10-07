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

- [ ] TODO-1: **Per-arrival harness, before any change.** Time
  `add_one_subject()` + `assign_wt()` at t = 10, 100, 500, 1000 and plot
  cost against t; the slope is the bug. Promote to `R/benchmark/` next to
  the design table. Installed package only.

- [ ] TODO-2: **Incremental level bookkeeping (F3).** Make
  `ensure_factor_metadata()` O(k): keep the full rescan only when
  `strata_level_rows` is `NULL` (first call or after `duplicate()`), and
  otherwise register only the keys of row t. Remove the duplicate call
  from `get_subject_levels_idx()` or make it a no-op after the first
  registration. Also read the k values directly (`Xraw[[col]][t]`) instead
  of `Xraw[t, ]` (F4).

- [ ] TODO-3: **Do not rebuild the model matrix during the sequence for
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

- [ ] TODO-4: **Amortize the append (F1).** Preallocate `Xraw` with
  capacity when `n` is known (fixed-sample sequential designs) and fill
  with data.table `set()`, or grow geometrically; expose the first t rows
  to every reader via the existing accessors. If the preallocation
  interferes with `rbindlist`'s `use.names`/new-column handling
  (`allow_new_cols = TRUE`), restrict it to the no-new-columns path and
  keep the current append as the fallback.

- [ ] TODO-5: **Re-run the design table.** Acceptance: per-arrival cost
  flat in t and ≤ 0.5 ms at k = 4; whole-sequence time within 10x of
  `carat` at n = 1000; fixed-seed assignment sequences identical to 1.0.2
  on the TODO-1 fixtures. Update `benchmark_model_fits.md`.

## Out of scope

- Moving the whole sequence into C++ as `carat` does (the batch
  `generate_permutations_pocock_simon_cpp()` already exists for
  rerandomization; the per-arrival API must stay in R because the user
  supplies each subject).
- Fixed-design construction cost (`design_construction_overhead.md`).
