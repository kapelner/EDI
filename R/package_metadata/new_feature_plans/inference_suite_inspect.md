# InferenceSuite run_all_inference(): Fit-and-Compare Every Applicable Inference Class

> **Depends on:** `fix_inference_hierarchy.md` — specifically `_master.md`
> Phase 1D (family migration completion): `run_all_inference()` constructs and fits
> every applicable class, so the families should be fully migrated before
> its golden fixtures are cut. Discovery itself
> (`discover_applicable_inference_classes()`) is already metadata-driven
> and stable. `fix_design_hierarchy.md` (closed 2026-08-17, in
> `../finished_features/`) supplies the design-side capability metadata.
> (Global ordering: see `_master.md` § 1G.)

Written 2026-08-17.

## Purpose

`InferenceSuite` (`R/inference_suite.R`) currently only *discovers* which
`Inference` classes are applicable to a completed `Design` — it never
constructs or fits any of them. A user who wants to know "which estimator
should I actually use, and what do they each say" has to construct and fit
every applicable class by hand, one at a time, and eyeball the results
against each other. There is no standardized way to compare estimate / SE /
CI / p-value across classes, and no single output shape that reads the same
way whether the response is continuous, incidence, count, ordinal, or
survival, or whether the design is plain iid randomization or KK
matched-pair.

This plan adds a `run_all_inference()` method to `InferenceSuite` that constructs and
fits every class in `applicable_design_classes`, and reports one uniform
comparison table across all of them.

## Non-Goals

- Do not change `InferenceSuite$initialize()`'s discovery/validation
  behavior. `run_all_inference()` is new, additive, opt-in (a user must call it
  explicitly — it fits models, unlike the constructor).
- Do not compute every optional method (bootstrap, randomization,
  jackknife, likelihood-ratio) per class. `run_all_inference()` reports each class's
  *primary* CI/p-value method (whatever a bare `compute_ci()`/
  `compute_pval()` call resolves to for that class), not a full diagnostics
  dump — that is `public_diagnostics_api_spec.md`'s job, not this one.
- Do not build a new diagnostics object schema (`EDIInferenceDebugResult`).
  This is a separate, flatter, comparison-oriented schema (decided in
  discussion: a new uniform schema, not a reuse of the debug-object
  contract).
- Do not add plotting, model selection, or a "recommended estimator" verdict
  in the first pass. `run_all_inference()` reports; it does not decide.

## Output Schema

One row per class in `applicable_design_classes`, identical column set
regardless of response type or iid/KK design family:

```r
list(
  inference_class = <character>,   # e.g. "InferenceContinOLS"
  response_type   = <character>,   # from des_obj$get_response_type()
  design_family   = <character>,   # "iid" | "kk_matched_pair"
  likelihood_tier = <character>,   # "none" | "quasi" | "partial" | "full"
  estimate        = <numeric or NA_real_>,
  se              = <numeric or NA_real_>,
  ci_lower        = <numeric or NA_real_>,
  ci_upper        = <numeric or NA_real_>,
  ci_method       = <character or NA_character_>,  # e.g. "wald", "randomization"
  pval            = <numeric or NA_real_>,
  pval_method     = <character or NA_character_>,
  estimand        = <character>,   # what the estimate IS: e.g. "mean_difference",
                                   # "log_odds_ratio", "hazard_ratio" — guards
                                   # against apples-to-oranges comparison of the
                                   # estimate column across classes
  fit_secs        = <numeric>,     # wall-clock seconds for this class's
                                   # construct+fit+summarize
  warnings        = <character or NA_character_>,  # captured R warnings from the
                                   # fit (convergence, separation, etc.),
                                   # collapsed to one string; NA if none
  status          = "ok" | "nonestimable" | "error",
  message         = <character or NA_character_>
)
```

`run_all_inference()` also takes `alpha` (default `0.05`): the CI level
(`1 - alpha`) and the significance threshold used anywhere the report
flags/format significance — not hardwired to 95%.

Below the per-class table, both output modes append an
**unavailable-classes footer** listing
`unavailable_due_to_missing_packages` (class name → missing packages), so
the practitioner can see which estimators an `install.packages()` away.

`design_family` is derived once from `normalize_inference_design_metadata()`'s
existing `is_kk` field (`"kk_matched_pair"` if `TRUE`, else `"iid"`) — no
response-type-conditional columns, no per-family schema branching. This is
the concrete meaning of "standard output for each response type and data
model type" from the brainstorming discussion: one schema, always these
columns, `NA`/`NA_character_` filled in wherever a class doesn't produce that
value (e.g. a `likelihood_tier = "none"` class has no `pval_method` beyond
whatever its default test is; a class with no closed-form SE reports
`se = NA_real_`).

`ci_method`/`pval_method` are read from whatever method the class's own
`compute_ci()`/`compute_pval()` actually dispatched to — `run_all_inference()` does
not force a specific method; it just labels the one each class picked by
default, so results are directly comparable to what a user gets calling
that class normally.

## Per-Class Failure Isolation

A single class's construction or fit failure must not abort the whole
report. Wrap each class's construct-and-fit sequence in `tryCatch()`:

- Construction/fit raises a non-estimability condition recognized by the
  package's existing non-estimable-result convention → `status =
  "nonestimable"`, `message` set from the condition, all numeric fields
  `NA`.
- Construction/fit raises any other error → `status = "error"`, `message =
  conditionMessage(e)`, all numeric fields `NA`.
- Success → `status = "ok"`, `message = NA_character_`, numeric fields
  populated from the fitted object.

`inference_params` (already validated by `initialize()`) is forwarded to
each class's constructor exactly as it would be for a manual construction.

## Output Modes: `screen`, `html`

```r
InferenceSuite$run_all_inference(screen = TRUE, html = FALSE)
```

- `screen`: print results to the console **incrementally, in computation
  order** — each class's row is printed as soon as its fit completes, not
  buffered into one table at the end. Below the streamed rows, maintain a
  live progress bar showing **% done and estimated time to complete**,
  following `SimulationFramework`'s existing pattern
  (`.draw_simulation_progress_bars()` / its `.fmt_secs()` ETA formatter and
  `\r`/`\033[2K` stderr redraw discipline in `simulations_framework.R`;
  also the throttled-redraw and "Estimating..." → measured-throughput ETA
  fallback there). Here one bar suffices (classes done / total classes;
  ETA from mean per-class elapsed time so far). Rows print to stdout;
  the bar redraws on stderr below them, cleared before each new row is
  emitted (the `.message_stderr()`-style clear-then-print pattern).
- `html`: render the same table to a self-contained HTML file, written to
  the **current working directory** with a timestamped filename —
  `inference_suite_results_<YYYYMMDD_HHMMSS>.html` — and then opened
  automatically in the user's default browser via `utils::browseURL()`.
- **Constraint: at least one of `screen`/`html` must be `TRUE`.** Both
  `FALSE` is a construction-time argument error (`stop()`), not a silent
  no-op — mirrors the existing `should_run_asserts()`-gated argument
  validation style already used in `InferenceSuite$initialize()`.
- Both may be `TRUE` simultaneously (console print + saved/opened HTML in
  the same call).
## Return Object

`run_all_inference()` returns (invisibly) one structured **list of lists** carrying
every piece of information the call generated — the programmatic
counterpart of the screen/HTML/plot outputs, complete enough to
reconstruct any of them without re-fitting. (Note: this is `run_all_inference()`'s
return, not `InferenceSuite$new()`'s — R6 semantics require `$new()` to
return the constructed object itself; the constructor remains
discovery/validation-only.) S3 class `c("EDIInferenceSuiteResults",
"list")`:

```r
list(
  results = list(          # one entry per applicable class, computation order
    InferenceContinOLS = list(
      inference_class = ..., response_type = ..., design_family = ...,
      likelihood_tier = ..., estimate = ..., se = ...,
      ci_lower = ..., ci_upper = ..., ci_method = ...,
      pval = ..., pval_method = ..., estimand = ...,
      fit_secs = ..., warnings = ..., status = ..., message = ...,
      diagnostics = list(...)   # numerical-fit diagnostics; see below
    ),
    ...                    # every schema field, one sub-list per class
  ),
  results_table = <data.frame>,   # the same rows, flat (what screen/HTML print)
  design = list(                  # snapshot of the design metadata used
    response_type = ..., design_family = ..., design_class = ...,
    n = ..., n_T = ..., n_C = ...
  ),
  alpha = <numeric>,
  unavailable_due_to_missing_packages = <named list>,
  plots = list(estimates = <ggplot or NULL>, ci_forest = <ggplot or NULL>),
  files = list(html = <path or NULL>, pdf = <path or NULL>,
               json = <path or NULL>),   # NULL when that output wasn't requested
  timestamp = <character>,        # the shared YYYYMMDD_HHMMSS artifact stamp
  total_secs = <numeric>,
  edi_version = <character>
)
```

- `save_results_as_JSON` flag (default `FALSE`): serialize the return
  object — minus the `plots` element (ggplot objects don't survive JSON;
  everything else is scalars/vectors/paths) — to a timestamped JSON file
  in the current working directory,
  `inference_suite_results_<YYYYMMDD_HHMMSS>.json` (same shared timestamp
  as the HTML/PDF artifacts). Use `jsonlite` if already a dependency;
  otherwise add to `Suggests` and gate with `requireNamespace()`, same
  rule as `ggplot2`. `NA` fields serialize as JSON `null`.
- The JSON flag is independent of `screen`/`html` — the
  at-least-one-of-`screen`/`html` constraint is unchanged.

### Per-class `diagnostics` element

Each class result carries a `diagnostics` sub-list with numerical-fit
diagnostics. **v1.0.0 scope: free fields only** — values the fit already
produced at no extra cost, read from the optimizer's result (the
`optimizer_diagnostics_report.md` TODO-4 layer that already shipped
pre-1.0):

```r
diagnostics = list(
  converged         = <logical or NA>,   # gradient-norm-based, per TODO-4
  hit_iteration_cap = <logical or NA>,
  iterations        = <integer or NA>,
  optimizer         = <character or NA>  # which algorithm/kernel fit it
)
```

`NA` for classes with no iterative fit (closed-form estimators, exact
tests). No extra QR/eigen/refit work on this path — same "share
orchestration, not instrumentation" rule as
`public_diagnostics_api_spec.md`.

**v1.1.0 expansion point:** this element is deliberately a named list so
the Phase 2 diagnostics chain (`optimizer_diagnostics_report.md` →
`public_diagnostics_api_spec.md`) can enrich it additively — condition
numbers, separation flags, per-stage timings, the curated
`EDIInferenceDebugResult` fields — without changing its shape or breaking
JSON consumers. The expansion is tracked as
`public_diagnostics_api_spec.md → TODO-19` (v1.1.0, Phase 3 there), not
here.

## Visualizations (ggplot2)

Two companion plots, generated with `ggplot2` from the same result
data.frame (only `status == "ok"` rows; classes on the y-axis, sorted by
estimate; consistent theming across both). An earlier draft had a third
standalone log10 p-value number line; it was merged into the forest plot
(user decision, 2026-08-17) — its information survives as per-row printed
p-values plus significance-driven segment styling.

1. **Estimate number line** — every class's point estimate on one shared
   horizontal axis (`geom_point`), with:
   - each dot labeled **above it at a 45° angle** with the class name and
     its estimate method (`geom_text(angle = 45, hjust = 0)` or
     `ggrepel`-style nudging if labels collide — decide during
     implementation; the 45° angle is the requested default),
   - a **box-and-whisker plot of the estimate values underneath** the
     number line (same x-axis, compressed y-band below the dots), giving
     an at-a-glance summary of the spread/consensus of estimates across
     classes and flagging outlier estimators.
   Facet by `estimand` so estimates on different scales are never drawn
   on one shared axis (the boxplot is per-facet too — a spread summary
   across mixed scales would be meaningless).
2. **Annotated CI forest plot** (merges the former p-value and CI plots)
   — every class's `(1 - alpha)`-level `[ci_lower, ci_upper]` as a
   horizontal segment with a point at the estimate, and per row:
   - the **p-value printed to the left** of the CI segment (scientific
     notation below ~1e-4, so tiny p-values stay readable),
   - the **CI width printed to the right** of the segment,
   - the **class name and its ci/pval method underneath** the segment
     (two-line label under the line rather than a y-axis label — long
     class names like `InferenceSurvivalKKGEEWeibull` don't fit an axis),
   - segment styling (color/alpha) keyed to significance at the user's
     `alpha`, so the which-classes-reject scan the old log10 plot
     provided survives the merge visually, not just as printed text.
   A vertical reference line sits at the null value for the panel's
   scale (zero on additive scales, 1 — or log-scale zero — on ratio
   scales), with the same per-`estimand` faceting rule as plot 1 (CI
   widths aren't comparable across scales either). The title/subtitle
   states the level explicitly (e.g. "95% confidence intervals" for
   `alpha = 0.05`) — the intervals plotted are the same `alpha`-driven
   ones in the table, never hardwired 95%. Row height scales with the
   number of classes (each row is ~3 text lines tall); the PDF page
   grows vertically with class count rather than shrinking text. Same per-`estimand` faceting rule as
   plot 1 (zero is only meaningful on additive scales; on ratio scales the
   reference line is at the null value for that scale, e.g. 1 — or the
   log-scale zero if estimates are reported on the log scale).

Wiring:

- `plots` flag (default `TRUE` when `screen = TRUE`): display the two
  plots on the current graphics device after the table completes.
- `pdf` flag (default `FALSE`): save the two plots to a single
  timestamped multi-page PDF in the current working directory —
  `inference_suite_results_plots_<YYYYMMDD_HHMMSS>.pdf` (same timestamp
  string as the HTML file when both are requested in one call, so the
  artifacts pair up).
- When `html = TRUE`, embed the same two plots into the HTML report as
  base64-inlined PNGs (keeps the HTML self-contained/offline, per the
  no-external-assets rule).
- `ggplot2` dependency: check `DESCRIPTION` — if not already an Import,
  add it to `Suggests` and gate the plot paths on
  `requireNamespace("ggplot2")` with a clear error, consistent with how
  the package treats other optional packages.
- The plot objects are also returned in the result's `plots` element (see
  Return Object above) so users can restyle them.

## Implementation Notes

- Reuse `discover_applicable_inference_classes()`/
  `normalize_inference_design_metadata()` already in `inference_suite.R` —
  do not duplicate discovery logic.
- HTML rendering: a minimal `knitr::kable(..., format = "html")` (or
  equivalent already-a-dependency table-to-HTML helper — check
  `DESCRIPTION` before adding a new dependency) wrapped in a tiny static
  HTML shell. No JS, no external assets — must render standalone offline.
- Writing to the current working directory (not `tempdir()`) is a
  deliberate, user-visible side effect; document it prominently in
  `run_all_inference()`'s roxygen so it isn't a surprise mid-session.
- `utils::browseURL()` is base/recommended-package machinery; no new
  dependency.

## Implementation TODOs

- [ ] TODO-1: Add `run_all_inference(screen = TRUE, html = FALSE)` to `InferenceSuite`
  in `inference_suite.R`; validate `screen || html` at entry.
- [ ] TODO-2: Implement the per-class construct-fit-summarize loop with
  `tryCatch()` isolation, producing one row per applicable class in the
  schema above.
- [ ] TODO-3: Implement the `design_family` normalization (`"iid"` vs.
  `"kk_matched_pair"`) from existing `normalize_inference_design_metadata()`
  output.
- [ ] TODO-4: Implement `screen` console output: incremental
  row-per-completed-class streaming plus the live %-done/ETA progress bar
  per the `SimulationFramework` pattern above.
- [ ] TODO-5: Implement `html` output: timestamped filename, write to CWD,
  `utils::browseURL()` auto-open.
- [ ] TODO-6: Add the practitioner columns/parameters: `estimand`,
  `fit_secs`, `warnings` capture, `alpha`, and the unavailable-classes
  footer in both output modes.
- [ ] TODO-7: Implement the two ggplot2 visualizations (estimate number
  line with 45°-angled class/method labels above each dot and a
  box-and-whisker summary of the estimates underneath; annotated CI
  forest with per-row p-value left of the segment, CI
  width right of it, class name + method underneath, significance-keyed
  styling at `alpha`, and null-value reference line), the `plots`/`pdf`
  flags, timestamped multi-page PDF output with class-count-scaled page
  height, and base64-PNG embedding into the HTML report.
- [ ] TODO-7b: Implement the `EDIInferenceSuiteResults` return
  object (list-of-lists per the Return Object section), including the
  per-class `diagnostics` element (free optimizer fields only —
  `converged`/`hit_iteration_cap`/`iterations`/`optimizer`; `NA` for
  non-iterative fits), and the `save_results_as_JSON` flag with its
  timestamped CWD JSON file.
- [ ] TODO-8: Roxygen for `run_all_inference()`, including the CWD-write side effects
  (HTML + PDF + JSON) and the `screen`/`html` constraint; regenerate docs.
- [ ] TODO-9: Tests: full fixture grid — **every response type
  (continuous, incidence, count, proportion, survival, ordinal) × design
  family {iid, KK matched-pair} × design class {BCRD, one blocking design,
  one KK design, one greedy design, one D-optimal design}** (skipping
  grid cells that are structurally impossible, e.g. a KK design in the
  iid column — record each skip explicitly in the test file rather than
  silently omitting it). For every valid cell: schema shape (identical
  column set), `design_family` labeling, and at least one `status = "ok"`
  row. Plus: per-class failure isolation (a
  deliberately-broken class still yields a full report); the
  `screen`/`html` both-`FALSE` error; the HTML file actually gets written
  and is valid standalone HTML (a JS-free static rendering check, not a
  browser-open check in CI); the PDF gets written with two pages; plot
  objects build without error on each fixture (no graphics device needed
  in CI — test the ggplot objects, not rendered output); the return
  object carries every documented element, `results` order matches
  computation order, and `save_results_as_JSON = TRUE` writes a JSON file
  that round-trips (parse it back, compare against `results_table`;
  `NA` fields serialize as JSON `null`).
