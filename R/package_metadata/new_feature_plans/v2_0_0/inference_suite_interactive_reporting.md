# `InferenceSuite` Interactive Reporting: `plotly`/`DT`

> **Depends on:** `InferenceSuite`'s shipped `run_all_inference(plots=,
> html=)` plumbing (`R/EDI/R/inference_suite.R`) — extended, not
> replaced. Shares its interactivity convention with
> `model_diagnostics_framework.md` §6/TODO-8 and
> `design_diagnostics_framework.md` §4/TODO-6, both of which cross-
> reference this exact retrofit ("the natural place to retrofit the same
> interactivity onto `InferenceSuite`'s existing static HTML tables").
> This file is that retrofit, formally scoped. **Release target: v2.0.0**
> (corrected from an initial v1.2.0 target, user decision 2026-09-10 —
> v1.2.0's own theme is explicitly "no new statistical functionality,"
> and this is reporting/UX on top of existing results, not a
> statistical addition, but it belongs with its two v2.0.0 diagnostics
> siblings rather than the performance-and-engines release). (Global
> ordering: see `_master.md`.)

Written 2026-09-10 (user request, quoting this session's own earlier
critique of `InferenceSuite`'s visualization: "Static only — ggplot2 +
static HTML tables, no plotly/DT. A 40+ row results table would benefit a
lot from sortable/filterable HTML.").

## 1. Why

`run_all_inference()` already ships a real, working report: a CI forest
plot faceted by estimand (`run_all_inference_plot_ci_forest`,
`R/EDI/R/inference_suite.R:2598`), a box-and-whisker summary panel
(`run_all_inference_stack_forest_and_box`), an HTML table
(`run_all_inference_format_html_table`, `:3850`), and a PDF export
(`run_all_inference_save_plots_pdf`). All of it is static. A suite run
across every applicable class and formula routinely produces 40+ result
rows; a static HTML table gives the user no way to sort by p-value, filter
to one estimand, or search a method name, and the static forest plot gives
no way to hover a point for its exact estimate/CI/p-value without reading
off the printed annotation text. This is a UX gap on top of already-good
content, not a missing feature.

## 2. Architecture

Reuse, don't replace: `interactive = FALSE` default keeps today's exact
static output (bit-for-bit HTML/plot output, no default change). When
`interactive = TRUE`:

- **`DT::datatable()`** wraps the same data frame
  `run_all_inference_format_html_table()` already builds — sortable
  columns, a search box, and per-column filters (class, method, estimand,
  significance) — rather than a second, separately-maintained table
  builder. The static `esc()`/`htmltools_escape_or_identity()` formatting
  stays the value-formatting layer either way; only the rendering wrapper
  changes.
- **`plotly::ggplotly()`** wraps the `ggplot2` object
  `run_all_inference_plot_ci_forest()`/`run_all_inference_build_plots()`
  already constructs — hover shows the exact estimate, CI bounds, p-value,
  and class/method label currently only available by reading the printed
  annotation text off the static plot. The box-and-whisker summary panel
  gets the same wrap.
- Both are `Suggests`-only (`DT`, `plotly`), gated by
  `requireNamespace(..., quietly = TRUE)`, exactly like every other
  optional backend in this codebase — never a hard dependency of
  `run_all_inference()`'s existing fast/default path. Absent the package,
  `interactive = TRUE` degrades to the static equivalent with a one-line
  message, not an error — same rule `model_diagnostics_framework.md`'s
  TODO-8 tests already state for its own `DT`/`plotly` use.
- One shared `interactive =` argument convention across all three reports
  that now offer this — `InferenceSuite`, `ModelDiagnostics`,
  `DesignDiagnostics` — so a user learns the flag once.

## 3. Scope boundary

This is presentation only: no change to what is computed, no change to
`results_table`'s columns or `print()`/`summary()`'s text output, no
change to the PDF export path (PDF is inherently static; `plotly` has no
meaningful PDF form). `save_results_as_JSON` is unaffected — JSON already
carries the full numeric content the interactive views only re-render.

## Tests

- Static/interactive data parity: the values `DT::datatable()` renders
  equal `run_all_inference_format_html_table()`'s data frame exactly;
  the `plotly`-wrapped forest plot's underlying data equals the static
  `ggplot2` object's data (not just "both render").
- No-Suggests CI leg: `interactive = TRUE` without `DT`/`plotly` installed
  produces the static report plus one message, never an error, verified
  on the existing `_R_CHECK_SUGGESTS_ONLY_` leg (`release.md`).
- Default-output golden test: `interactive = FALSE` (the default)
  produces byte-identical HTML/plot output to today's `run_all_inference()`
  — this feature adds a path, it does not change the existing one.
- Large-table behavior: a 40+ row `results_table` renders in `DT` within
  the same report-generation time budget as today's static table (no
  quadratic blowup in the sort/filter wiring).

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — the argument
  name/default (`interactive =`, matching the convention proposed for
  `ModelDiagnostics`/`DesignDiagnostics`); whether `DT` filtering defaults
  to per-column search boxes or a single global search.
- [ ] TODO-2: **`DT` integration** — wrap
  `run_all_inference_format_html_table()`'s data frame in
  `DT::datatable()`; column-level sort/filter; static fallback.
- [ ] TODO-3: **`plotly` integration** — wrap the CI forest plot and
  box-and-whisker panel via `ggplotly()`; verify facet-by-estimand and the
  significance-highlight styling survive the wrap; static fallback.
- [ ] TODO-4: **Shared convention documentation** — the `interactive =`
  argument's behavior documented once and cross-referenced from
  `model_diagnostics_framework.md` and `design_diagnostics_framework.md`
  rather than redocumented three times.
- [ ] TODO-5: **Tests** per the section above.
- [ ] TODO-6: **Documentation**: vignette section, roxygen, `NEWS.md`
  entry noting `interactive = TRUE` as new opt-in surface, not a default
  change.
