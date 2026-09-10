# `SimulationFramework` Power / Operating-Characteristic Visualization

> **Depends on:** `SimulationFrameworkReport`'s shipped aggregation
> (`R/EDI/R/simulation_framework_report.R`) — this plan visualizes its
> existing `summarize()` output, computing nothing new. `InferenceSuite`'s
> `run_all_inference(plots=, html=)` reporting conventions
> (`R/EDI/R/inference_suite.R`) and `inference_suite_interactive_reporting.md`'s
> `interactive =` convention, reused for the reporting layer. **Release
> target: v3.0.0** (wiring into `release_v3_0_0.md` / `_master.md` /
> `ROADMAP.md` to follow, done together with this plan's sibling
> `survival_curve_visualization.md` in the parent conversation).

Written 2026-09-10 (user request, from a visualization brainstorm: EDI's
own `DESCRIPTION` names "power analysis and operating-characteristic
studies across designs, response types, and inference procedures" as a
headline feature, yet `simulations_framework.R` and
`simulation_framework_report.R` contain zero plotting code, verified by
grep this session).

## 1. Why

`SimulationFrameworkReport$summarize()` already computes exactly the
numbers a power/operating-characteristic study needs — but only as a
data.table a user must pivot and plot themselves. For a package whose
stated differentiator is comparing *multiple inference procedures* on the
*same* design/response-type cell, the natural output is a comparison
plot, not a table row per procedure the user has to eyeball across.

## 2. What already exists to plot (verified against `simulation_framework_report.R`)

`summarize()` returns one row per `(response_type, cond_exp_func_model, n,
p, betaT, design, inference, inference_type[, simulation_mode])`
combination, with:

- `MSE`, `n_est` — always.
- `coverage`, `ci_length`, `coverage_pval` — when CI-producing inference
  types ran (`coverage_pval` is already an exact two-sided binomial test
  of `H0: true coverage = 1 - alpha`).
- `power`, `n_pow` (rows where `betaT != 0` / the custom-DGP non-null
  rows) and `size`, `n_size`, `size_pval` (rows where `betaT == 0`;
  `size_pval` is already an exact two-sided binomial test of
  `H0: true size = alpha`) — when p-value-producing inference types ran.

This plan is presentation only: every number below already exists in this
object; nothing here computes a new statistic.

## 3. Scope: three plot types

### A. Power curve

`power` vs. `n` (or `betaT`, whichever the study actually varies — the
plot should detect which axis has more than one level and use that),
**one line per `(inference, inference_type)`** so procedures are directly
comparable on the same axes, faceted by `(response_type,
cond_exp_func_model, design)` when a study spans more than one. The
headline plot for "which procedure is more powerful here."

### B. Calibration check (type-I-error / coverage)

Two companion plots, both using rows already flagged by their own
`_pval` column so a user sees *which* procedures are miscalibrated, not
just an aggregate:

- **Size check**: `size` vs. nominal `alpha`, one point/line per
  procedure, a horizontal reference line at nominal `alpha`, with
  `size_pval` driving a visual flag (e.g. point styling) for the
  procedures whose exact binomial test rejects calibration — this is the
  standard operating-characteristic sanity check every simulation study
  in the literature runs before trusting a power comparison.
  Multiplicity across procedures/cells is the user's problem to correct
  (e.g. Bonferroni across the panel), not something this plot decides for
  them — annotate the raw per-cell `size_pval`, don't pre-correct it.
- **Coverage check**: `coverage` vs. nominal `1 - alpha`, same
  reference-line-plus-flag treatment, using `coverage_pval`.

### C. Operating-characteristic comparison view

For one `(design, response_type)` cell (the natural unit a user is
choosing an inference procedure for), a single comparison view — grouped
bars or a dot plot — showing power, size/coverage, and `MSE`/`ci_length`
side by side across every `inference`/`inference_type` that ran on that
cell. The "which procedure should I actually use here" summary, one
step up from the per-metric plots in A/B.

## 4. Architecture

- New plot functions on `SimulationFrameworkReport` (or a companion
  reporting object, mirroring how `InferenceSuite`'s plotting lives
  alongside `run_all_inference()` rather than as a separate class) —
  `plot_power()`, `plot_calibration()`, `plot_oc_comparison()` — exact
  naming a decision-gate item, not resolved here.
- Each consumes `summarize()`'s existing output directly; no new
  aggregation logic duplicated in the plotting layer.
- `ggplot2` static by default; `plotly::ggplotly()` wrap when
  `interactive = TRUE`, matching `inference_suite_interactive_reporting.md`'s
  convention exactly (hover → exact power/size/coverage value and its
  `_pval`) — `Suggests`-gated, same fallback rule.
- HTML report surface follows `run_all_inference_render_html()`'s
  existing conventions.

## Tests

- Golden plot data: every plotted value equals `summarize()`'s own output
  exactly for a fixed simulation result set — this plan adds no new
  arithmetic to verify beyond that equality.
- Axis auto-detection: a study varying `n` (fixed `betaT`) plots power vs.
  `n`; a study varying `betaT` (fixed `n`) plots power vs. `betaT`; a study
  varying neither degrades to the comparison view (§C) rather than a
  degenerate single-point curve.
- Calibration flagging: a synthetic miscalibrated procedure (deliberately
  wrong nominal coverage) is visually flagged by the size/coverage check
  plots; a correctly calibrated one is not, at reasonable simulation
  replicate counts.
- No-Suggests CI leg: `interactive = TRUE` without `plotly` degrades to
  static plots plus a message, never an error.
- Works from both construction paths `SimulationFrameworkReport` already
  supports — a live `SimulationFramework` object and a loaded
  `.csv`/`.csv.bz2` results file — since `summarize()`'s output shape is
  identical either way.

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — plot function
  names/signatures; whether they live as `SimulationFrameworkReport`
  methods or standalone functions taking a report object; default axis
  detection rule for the power curve (§A) when a study varies more than
  one of `n`/`betaT`/`p`.
- [ ] TODO-2: **Power curve** (§A) — axis auto-detection, one line per
  `(inference, inference_type)`, faceting.
- [ ] TODO-3: **Calibration check plots** (§B) — size and coverage,
  reference line, `_pval`-driven flagging.
- [ ] TODO-4: **Operating-characteristic comparison view** (§C).
- [ ] TODO-5: **`plotly` interactivity**, `Suggests`-gated, per §4.
- [ ] TODO-6: **HTML/report integration**.
- [ ] TODO-7: **Documentation**: vignette section (likely extending the
  existing `SimulationFramework` vignette rather than a new one), roxygen.

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were supplied from
general knowledge and must be checked against the primary source before
citation in roxygen/`REFERENCES.md`.)

- Standard operating-characteristic reporting convention (power curves,
  type-I-error calibration checks) — general simulation-study methodology
  in biostatistics; no single canonical citation, domain-convention-
  informed. `NEEDS VERIFICATION` if a specific anchor citation is wanted
  for the vignette.
