# EDI calibration study: campaign 2026-11-12-a46ab113

**In progress: provisional.** Cells fill in as waves finish; the size / coverage gate is applied when the campaign completes.

Simulated at EDI commit [`a46ab113`](https://github.com/kapelner/EDI/commit/a46ab113871924fed13ee43cb86b0b03c4f0e10d) (started 2026-11-12T21:05Z); analysed at [`00aa18a6`](https://github.com/kapelner/EDI/commit/00aa18a6bcec8389d60cfde6c2f15a1098731dbe).

## Summary

Progress: 2314983 of 13330000 replicates (17%) after wave 2; 2216 of 19930 cells complete, 0 abandoned.

10696 null cells and 0 power cells have results; 18716 of the plan's 129978 tests (null size and coverage, coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate: Benjamini-Hochberg q < 0.05 over all 129978 tests of the plan on the screening replicates (a test enters with its p-value when its cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only "not flagged" is provisional) flags **57** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at 0.01 / 129978, fixed in advance, so a confirmed failure is final when it is made.

Confirmation so far: 24 confirmed failing, 33 pending, 0 could not be confirmed (counted as failing), 0 cleared. Failing null cells so far (provisional): **34**.

304 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

Classes: 0 complete, 40 in progress, 60 not started ([Classes](classes.md)).

A red campaign is one whose `analyze` job's last step, `Gate verdict`, failed: confirmed failing cells (a calibration result).
Any other failed step or job is a bug in the check itself (annotation "Calibration CI bug"), not a result.

## Contents

| Page | Contents |
|---|---|
| [Failing cells: continuous](failing-continuous.md) | 2 failing cell(s) |
| [Failing cells: incidence](failing-incidence.md) | 32 failing cell(s) |
| [Failing cells: count](failing-count.md) | 0 failing cell(s) |
| [Failing cells: proportion](failing-proportion.md) | pending (not run yet) |
| [Failing cells: survival](failing-survival.md) | pending (not run yet) |
| [Failing cells: ordinal](failing-ordinal.md) | pending (not run yet) |
| [Screen flags and confirmation](flags.md) | every test the screen flagged, with its confirmation verdict |
| [Null bias](null-bias.md) | bias at beta_T = 0, `bias_sd_large_n` flag (reported, not gated) |
| [Coverage and bias away from the null](nonnull.md) | gated coverage of the true estimand, bias at beta_T != 0 |
| [Design comparison and power](designs.md) | paired power tests between designs |
| [Classes](classes.md) | every class: status, verdict and its own page (figure, cells) |
| [Convergence slopes](convergence.md) | error versus n_eff against the registry's expected order |
| [Figures: continuous](figures-continuous.md) | null and non-null figures |
| [Figures: incidence](figures-incidence.md) | null and non-null figures |
| [Figures: count](figures-count.md) | null and non-null figures |
| [Figures: proportion](figures-proportion.md) | null and non-null figures |
| [Figures: survival](figures-survival.md) | null and non-null figures |
| [Figures: ordinal](figures-ordinal.md) | null and non-null figures |
| [Data](data.md) | tables, raw rows, column descriptions |
| [About this study](about.md) | design of the study, levels, gate |

## Data

Tables as CSV, raw replicate rows as workflow artifacts: see [Data](data.md).

## About this study

Every month EDI re-runs a simulation study of its own inference procedures and publishes the results here, failures included. How the data are generated, the level each cell is held to and the two-stage gate are on the [About page](about.md).
