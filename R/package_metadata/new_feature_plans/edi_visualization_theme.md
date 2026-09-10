# A Shared `theme_edi()` Visualization Theme

> **Depends on:** nothing structurally — a pure `ggplot2` theme object plus
> a shared color-palette helper, no new statistical machinery. **Release
> target: v3.0.0** (per user decision 2026-09-10, added with the rest of
> this session's visualization brainstorm) — **see the scheduling caveat
> below; this item is a poor fit for "ships last" among its siblings.**
> (Global ordering: see `_master.md`.)

Written 2026-09-10 (from this session's visualization brainstorm — the one
cross-cutting item on that list, not a new visualization capability of its
own).

## Why

By the time every item from this session's visualization brainstorm ships,
EDI will have independently-built `ggplot2` plotting code in at least:
`InferenceSuite` (CI forest plot, box-and-whisker panel —
`inference_suite_interactive_reporting.md`), `ModelDiagnostics` (per-check
plots — `model_diagnostics_framework.md` §6), `DesignDiagnostics` (Love
plot, eCDF overlay, randomization-distribution histogram —
`design_diagnostics_framework.md` §4), the Bayesian posterior plots
(`bayesian_stan_primary_analysis_report.md` §4B), the mixture-model plots
(`finite_mixture_regression.md` §F), Kaplan-Meier curves
(`survival_curve_visualization.md`), `SimulationFramework` power/OC curves
(`simulation_framework_visualization.md`), the sequential boundary chart
(`sequential_inference.md`), the RAR trajectory plot
(`response_adaptive_randomization.md`), the causal-forest HTE plots
(`causal_forest_inference.md`), and the multi-arm pairwise-comparison plot
(`multi_arm_designs.md`). Eleven independent plotting call sites, each
free to pick its own base font size, grid style, and color for "this is
significant"/"this failed a check"/"this is arm A vs. arm B" — without a
shared theme, EDI's reports will look like eleven different people's
default `ggplot2` output, not one product.

## Architecture

- **`theme_edi(base_size =, base_family =)`** — one `ggplot2` theme
  object (built on `theme_minimal()` or `theme_bw()`, undecided —
  TODO-1), used by every plotting function across every plan listed
  above. Print- and screen-friendly; no dark-mode concern (these are
  R-session/HTML-report plots, not a themed web app).
- **`edi_palette(n, type = c("arm", "sequential", "flag"))`** — a shared
  color mapping: consistent arm colors (so "arm A is blue" means the same
  thing in a `DesignDiagnostics` Love plot, an `InferenceSuite` forest
  plot, and a `survival_curve_visualization.md` KM curve), a consistent
  "flagged/significant/violated" color (used by `InferenceSuite`'s
  significance highlighting, `ModelDiagnostics`' severity levels, and
  `DesignDiagnostics`' SMD-threshold flagging — three different plans
  independently need "this is the color that means attention," and it
  should be the same color), and a sequential palette for K > 2 arms /
  K-component mixtures.
- Every plotting function in every listed plan takes its theme/palette
  from here rather than hardcoding `scale_color_manual()` calls locally —
  a one-line dependency (`+ theme_edi()`), not a heavy coupling.

## Scheduling caveat — read before treating this as "just another v3.0.0 item"

Unlike its ten siblings, this item is not a new visualization capability —
it is a **consistency foundation** the others should be built *on top of*,
not retrofitted *onto* after the fact. Three of the eleven plotting
systems above (`InferenceSuite` interactive reporting, `ModelDiagnostics`
visualization, `DesignDiagnostics`) are already **v2.0.0** scope
(`release_v2_0_0.md → TODO-6i/6j/6k`) — meaning, taken literally, this
plan would ship in v3.0.0 *after* those three already exist with their own
ad hoc styling, requiring a retrofit pass later rather than a shared
foundation from the start. Flagging this rather than silently deciding it:
if the v2.0.0 diagnostics/reporting work (TODO-6i/6j/6k) hasn't started
implementation yet when this is prioritized, pulling this specific item
forward to ship *alongside or just before* those three — even though the
rest of this session's brainstorm stays v3.0.0 — would avoid the retrofit
entirely. This is a real scheduling question for a future decision batch,
not resolved here.

## Tests

- Every plotting function across the listed plans, once each ships,
  applies `theme_edi()` and pulls its colors from `edi_palette()` — a
  lint-style check (grep for stray `theme_minimal()`/`scale_color_*` calls
  outside this file) rather than a statistical test.
- Visual regression: a golden-image or golden-data snapshot per plot type
  confirming the theme renders consistently across a `ggplot2` version
  bump (belt-and-suspenders given how often theme internals shift between
  `ggplot2` releases).

## TODOs

- [ ] TODO-1: **Decision gate** — `theme_minimal()` vs. `theme_bw()` base;
  default `base_size`; the flag/significance color (should probably not be
  a plain "red," given colorblind-accessibility conventions — pick a
  palette with an accessibility citation, e.g. Okabe-Ito, rather than an
  arbitrary hex value).
- [ ] TODO-2: **Build `theme_edi()` and `edi_palette()`**, exported
  functions, documented as the house style.
- [ ] TODO-3: **Retrofit** onto every plotting function in every plan
  listed above, in whatever order those plans actually ship (not
  necessarily the order listed here).
- [ ] TODO-4: **Documentation** — a short vignette section on the house
  visual style, referenced from every plan's own visualization section
  instead of each redescribing color/style choices independently.

## References

- Okabe, M., and Ito, K. (2008). "Color Universal Design (CUD) — how to
  make figures and presentations that are friendly to colorblind people."
  `NEEDS VERIFICATION` (exact citation form) — candidate source for the
  flag/significance color and the arm palette.
