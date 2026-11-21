# EDI calibration study: campaign 2026-11-09-8c32d060

**In progress: provisional.** Cells fill in as waves finish; the size / coverage gate is applied when the campaign completes.

Simulated at EDI commit [`8c32d060`](https://github.com/kapelner/EDI/commit/8c32d0604d810c0e127086341b1c1931025851b5) (started 2026-11-09T23:21Z); analysed at [`519ca9fd`](https://github.com/kapelner/EDI/commit/519ca9fd6d53e183d16a313dc9ed8720367ffc5f).

## Summary


Progress: 192767 of 872000 replicates (22%) after wave 15; 225 of 1308 cells complete, 0 abandoned.

9166 null cells and 5050 power cells; 19251 tests (null size and coverage, coverage of the true estimand at the power effects). Two-stage gate: Benjamini-Hochberg q < 0.05 on the screening replicates flags **556** test(s); each flagged cell is re-run on fresh replicates and fails only if those alone reject (at 0.01 / 556).

Confirmation: pending (the flags are provisional). Failing null cells so far: **283**.


158 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.


A red campaign is one whose `analyze` job's last step, `Gate verdict`, failed: confirmed failing cells (a calibration result).
Any other failed step or job is a bug in the check itself (annotation "Calibration CI bug"), not a result.

## Contents

| Page | Contents |
|---|---|
| [Failing cells: continuous](failing-continuous.md) | 1 failing cell(s) |
| [Failing cells: incidence](failing-incidence.md) | 16 failing cell(s) |
| [Failing cells: count](failing-count.md) | 222 failing cell(s) |
| [Failing cells: proportion](failing-proportion.md) | 0 failing cell(s) |
| [Failing cells: survival](failing-survival.md) | 10 failing cell(s) |
| [Failing cells: ordinal](failing-ordinal.md) | 34 failing cell(s) |
| [Screen flags and confirmation](flags.md) | every test the screen flagged, with its confirmation verdict |
| [Null bias](null-bias.md) | bias at beta_T = 0, `bias_sd_large_n` flag (reported, not gated) |
| [Coverage and bias away from the null](nonnull.md) | gated coverage of the true estimand, bias at beta_T != 0 |
| [Design comparison and power](designs.md) | paired power tests between designs |
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

