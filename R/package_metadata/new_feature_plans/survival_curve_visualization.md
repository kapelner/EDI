# Kaplan-Meier Survival Curve Visualization

> **Depends on:** `InferenceSuite`'s shipped `run_all_inference(plots=,
> html=)` reporting conventions (`R/EDI/R/inference_suite.R`) and
> `inference_suite_interactive_reporting.md`'s `interactive =`
> convention (`DT`/`plotly`, `Suggests`-gated) — reused, not duplicated,
> for the `plotly` wrap here. Consumes the fitted survival classes'
> existing KM/risk-table machinery
> (`inference_all_abstract_mle_or_KM_summary_table.R`,
> `inference_survival_km_diff.R`, `inference_survival_log_rank.R`,
> `inference_survival_rmst.R`) rather than recomputing survival curves
> from raw data. **Release target: v3.0.0** (wiring into
> `release_v3_0_0.md` / `_master.md` / `ROADMAP.md` to follow, done
> together with this plan's sibling
> `simulation_framework_visualization.md` in the parent conversation).

Written 2026-09-10 (user request, from a visualization brainstorm: EDI
ships substantial survival machinery — log-rank, KM-diff, RMST,
Cox/stratified Cox, Weibull, frailty, dependent-censoring transform — but
zero Kaplan-Meier curve plotting exists anywhere in `R/EDI/R/`, verified
by grep this session).

## 1. Why

Every survival-analysis workflow in practice starts with a KM curve —
it is the visual the log-rank test, KM-diff, and RMST estimand are *about*.
EDI computes all of the underlying quantities (survival estimates,
censoring, at-risk counts) internally already to produce its point
estimates, but a user gets only a number back, never the curve. A package
with this much survival-inference depth and zero KM plotting is a
conspicuous gap against the field's baseline expectation (`survival` +
`survminer` is the universal R reference point).

## 2. Scope: one KM report per (design × formula) cell

Grounded in `survminer::ggsurvplot()` — the de facto R convention this
plan deliberately matches rather than inventing a new visual language, so
existing user intuition transfers:

- **KM curve per arm**, overlaid on one plot, step function, censoring
  ticks marked.
- **Confidence band** per arm (the same variance estimator the fitted KM
  class already computes — no new numerical work, a plot consuming
  existing output).
- **Risk table underneath** — numbers-at-risk by arm at the plot's own
  tick marks, the `survminer` convention of stacking a compact table
  directly below the curve on a shared x-axis rather than as a separate
  figure.
- **Log-rank test annotation** — p-value (and the KM-diff/RMST estimate,
  when that class was also fit) printed on the plot, sourced from the
  already-fitted `InferenceSurvivalLogRank`/`InferenceSurvivalKMDiff`/
  `InferenceSurvivalRestrictedMeanDiff` result, never recomputed for the
  plot.

## 3. Architecture

- New plot function following the existing `run_all_inference_plot_*`
  naming convention (`R/EDI/R/inference_suite.R`) —
  `run_all_inference_plot_km_curve(results_table, ...)` or a standalone
  `plot_km(des_obj, ...)` callable independent of a full
  `InferenceSuite` run (a KM curve is useful even before running every
  applicable inference class) — **decision gate, not resolved here**.
- Reuses the survival response type's existing per-arm survival-estimate
  computation (already present in the KM/log-rank/KM-diff classes) rather
  than a new estimation path — this plan is presentation only.
- `ggplot2` static by default; `plotly::ggplotly()` wrap when
  `interactive = TRUE`, the exact convention
  `inference_suite_interactive_reporting.md` establishes (hover → exact
  survival probability, CI, and at-risk count at a given time) —
  `Suggests`-gated, same fallback rule.
- HTML embedding follows `run_all_inference_render_html()`'s existing
  table-and-plot layout conventions rather than a new HTML surface.

## 4. Forward-looking extension point (not scoped here)

Once `competing_risks_response.md` and
`interval_censored_survival_response_type_report.md` land, the same
report surface should grow **cumulative incidence function (CIF)** curves
(the competing-risks analogue of KM) and interval-censored-appropriate
curve estimates (e.g. Turnbull). Noted as the natural next step for
whoever picks this up after those response-type plans ship — not
designed in depth here, since both are still open plans themselves.

## Tests

- Golden plot data: the curve's plotted survival probabilities and at-risk
  counts equal the fitted KM class's own internal computation exactly (not
  a re-derivation) — assert on the underlying data frame, not pixels.
- Censoring ticks appear at exactly the censored observation times per
  arm.
- Log-rank/KM-diff/RMST annotation text matches the corresponding fitted
  class's own `compute_pval()`/`compute_estimate()` output.
- No-Suggests CI leg: `interactive = TRUE` without `plotly` installed
  degrades to the static plot plus a message, never an error.
- Multi-arm behavior: the curve renders one line per arm with a legend,
  not one plot per arm — verified once `multi_arm_designs.md` lands (this
  plan's pilot scope is two-arm; K-arm is additive, not a redesign).

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — plot function
  name/signature and whether it is callable standalone (`plot_km(des_obj)`)
  or only through `InferenceSuite`'s report; risk-table inclusion default
  (on by default, per `survminer` convention, or opt-in).
- [ ] TODO-2: **KM curve + confidence band**, consuming the existing
  fitted-class survival-estimate computation.
- [ ] TODO-3: **Risk table** underneath, shared x-axis with the curve.
- [ ] TODO-4: **Test/estimand annotation** (log-rank p-value, KM-diff/RMST
  estimate) sourced from already-fitted classes.
- [ ] TODO-5: **`plotly` interactivity**, `Suggests`-gated, per §3.
- [ ] TODO-6: **HTML/report integration** with `InferenceSuite`'s existing
  surface.
- [ ] TODO-7: **Documentation**: vignette section, roxygen, and a note in
  `competing_risks_response.md`/`interval_censored_survival_response_type_report.md`
  pointing back here as their own future CIF-visualization extension
  point (§4).

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were supplied from
general knowledge and must be checked against the primary source before
citation in roxygen/`REFERENCES.md`.)

- Kaplan, E. L., and Meier, P. (1958). "Nonparametric estimation from
  incomplete observations." *JASA*, 53(282), 457–481. `NEEDS VERIFICATION`
  (pages).
- Kassambara, A., Kosinski, M., and Biecek, P. — `survminer`: Drawing
  Survival Curves using `ggplot2` (CRAN) — the plot/risk-table convention
  this plan matches.
- Therneau, T. M. — `survival` package — the underlying KM/log-rank
  reference implementation EDI's own estimators are checked against
  elsewhere in the codebase.
