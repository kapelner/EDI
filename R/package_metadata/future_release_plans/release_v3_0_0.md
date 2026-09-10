# Release Scope: v3.0.0 (Tentative)

> **Depends on:** `release_v2_0_0.md` (the last currently-scoped release;
> ships first). Release index over plans in `../new_feature_plans/`; not
> new work of its own. (Global ordering: see
> `../new_feature_plans/_master.md`.)

Written 2026-09-10 (user decision). **This release does not yet have a
real scope, a Phase-0-style decision batch, or even a settled identity of
its own** — v2.0.0 is still the frontier of actually-planned work. This
file is a shared, tentative home for scoping efforts that landed the same
day and were each explicitly targeted here — two new-architecture items
(finite mixture regression, Bayesian primary analysis via Stan) and,
added later the same day from a visualization brainstorm, a cluster of
visualization work spanning both brand-new plans and new sections grafted
onto several existing plans. None of these items structurally need each
other; they share this file only because none has a firmer release home
yet. Expect this file's scope, and possibly its very existence as a
release separate from v2.0.0 (or as a single release rather than several),
to be revisited once v2.0.0 itself nears completion and a real decision
batch for "what comes after" is taken.

## In scope (by plan)

### Finite mixture regression

- `finite_mixture_regression.md` — finite (latent-class) mixture
  regression for existing response families: a generic EM driver reusing
  each family's existing weighted C++ kernel for the M-step, one concrete
  `Inference*Mixture` class per family sharing a common
  `InferenceMixinFiniteMixtureEM` component, user-specified `K` with
  BIC/ICL for comparing a few values, bootstrap-only inference for v1,
  and both per-component and mixture-weighted marginal treatment effects
  (the latter depending on `marginal_estimand_report.md`'s
  `set_estimand("marginal_*")` machinery). See that file's own
  "Explicitly Deferred" section for what is deliberately out of scope
  even here (automatic K-selection, asymptotic/Louis SEs,
  randomization-based CIs, mixture-of-experts).

### Bayesian primary analysis via Stan

- `bayesian_stan_primary_analysis_report.md` — an optional, `cmdstanr`-
  backed Bayesian primary-analysis family: real priors, a declared
  likelihood, posterior probability statements, optionally Bayes factors
  (bridge sampling) and hierarchical/borrowing models, kept complementary
  to and separately labeled from the existing `BayesianBootstrap` (a
  model-based posterior vs. a nonparametric resampling frequency — not
  the same object). `cmdstanr` stays a `Suggests`-only external backend
  (recommendation over tight `rstan`/`StanHeaders` coupling, per that
  report's §2) — no `LinkingTo` change to `R/EDI`, no risk to its compile
  time or CRAN posture. Commissioned by
  `missing_inference_classes_literature_audit.md` item 21. Phased (§7
  there): MVP (continuous + incidence, posterior estimate/CI,
  diagnostics) → decision outputs (`P(effect > 0)`, Bayes factors) →
  remaining response types → hierarchical/borrowing models → sequential/
  platform-trial monitoring tie-in with `sequential_inference.md`.

Neither item depends on the other; they are tracked in one file only
because both are tentative and post-v2.0.0.

### Visualization (added 2026-09-10, from this session's visualization brainstorm)

Nine items, three brand-new plans and six new sections grafted onto
existing plans (four of which otherwise remain v2.0.0 — only their new
visualization section targets v3.0.0). All nine reuse
`inference_suite_interactive_reporting.md`'s ggplot2/HTML/`plotly`
convention rather than inventing a new visual language each.

- `survival_curve_visualization.md` (new) — Kaplan-Meier curves per arm,
  risk table, confidence bands, log-rank/RMST annotation, sourced from
  already-fitted survival classes (no new estimation). `survminer`
  convention.
- `simulation_framework_visualization.md` (new) — power curves,
  size/coverage calibration-check plots, and an operating-characteristic
  comparison view for `SimulationFramework`, grounded directly in
  `SimulationFrameworkReport$summarize()`'s existing output columns.
- `edi_visualization_theme.md` (new) — a shared `theme_edi()`/
  `edi_palette()` foundation for every plotting subsystem above and
  below. **Read that file's own "Scheduling caveat" section before
  treating it as an ordinary v3.0.0 item** — it argues for being pulled
  forward alongside `release_v2_0_0.md → TODO-6i/6j/6k` rather than
  shipping after them and needing a retrofit; not resolved here.
- `bayesian_stan_primary_analysis_report.md → TODO-3` (§4B) — `bayesplot`-
  backed posterior density, trace, prior-vs-posterior overlay, and a
  posterior forest plot in `InferenceSuite`'s own visual language.
- `finite_mixture_regression.md`'s "Implementation Sequencing" step 5
  (§F) — fitted-component-density overlay, classification/responsibility
  plot, BIC/ICL-vs-K comparison plot.
- `sequential_inference.md → TODO-6` (§10) — the Lan-DeMets/
  O'Brien-Fleming boundary chart, interim Z-statistics vs. information
  fraction with spending-function boundaries, sourced from that file's
  own `get_analysis_events()` ledger. The rest of that plan stays v2.0.0.
- `response_adaptive_randomization.md → TODO-6` — allocation-proportion-
  over-time trajectory plot, target-ratio reference line for DBCD/ERADE.
  The rest of that plan stays v2.0.0.
- `causal_forest_inference.md`'s "HTE visualization" section (Phase 6) —
  CATE-vs-covariate partial-dependence plot and a variable-importance
  plot, with an explicit rule that a shown SATE/ATE is a separately-styled
  reference line, never blended into the CATE band. The rest of that plan
  stays v2.0.0.
- `multi_arm_designs.md`'s §6c (`TODO-4b`) — a `multcomp`-style
  pairwise-comparison panel over the Bonferroni/Holm/Dunnett contrasts;
  explicitly scoped to that plan's Path (a) only. The rest of that plan
  stays v2.0.0.

### `inference_plots.md` (added 2026-09-11, user decision)

- `inference_plots.md` — every one of the package's 102 concrete
  `Inference*` classes gets a section listing the *result/effect*
  plots the statistical literature and software ecosystem have settled
  on for that model type — deliberately not diagnostics
  (`model_diagnostics_framework.md`'s job) and not a re-description of
  `InferenceSuite`'s existing generic CI forest plot
  (`inference_suite_interactive_reporting.md`'s job). Organized by 19
  model families (the same 13 likelihood-bearing + 6 `likelihood_tier =
  "none"` families `model_diagnostics_framework.md` §3B/§3C already
  established) rather than 102 independent searches, since IVWC/OneLik/
  KK-matched-design siblings share an identical fitted-model shape and
  therefore an identical plot — cross-referenced rather than repeated,
  though every class still gets its own subsection. **Six classes have a
  real structural dependency on `survival_curve_visualization.md`** (not
  mere non-overlap) — see that file's own TODO-3 below and
  `inference_plots.md`'s header for exactly which six and why.

## Implementation TODOs (dependency order; tentative — no decision batch taken yet)

- [ ] TODO-1: **Decision batch** — not yet taken for either item; neither
  has a Phase-0 sitting to join yet (v2.0.0's own Phase 0 doesn't cover
  post-2.0.0 work). Covers both plans' own "pursue this at all?" gates:
  finite mixture regression's (implicitly decided *by design*, 2026-09-10,
  in the scoping conversation itself — see that file's "Decisions Already
  Made") and Bayesian-Stan's (`bayesian_stan_primary_analysis_report.md →
  TODO-1`, genuinely undecided: pursue at all, confirm `cmdstanr` as
  backend, confirm the hand-written `.stan`-library approach, confirm
  response-type entry order). Revisit both once a real post-2.0.0
  planning cycle opens.
- [ ] TODO-2: `finite_mixture_regression.md`'s own "Implementation
  Sequencing" step 1 — audit per-family density-evaluator availability.
- [ ] TODO-3: Build the generic EM driver + `InferenceMixinFiniteMixtureEM`
  once, proven on Gaussian/OLS, Poisson, and Beta.
- [ ] TODO-4: Extend to remaining families, batched, per the audit's
  findings.
- [ ] TODO-5: If TODO-1's Bayesian-Stan decision is yes,
  `bayesian_stan_primary_analysis_report.md → TODO-2` — write the real
  implementation plan for Phase 1 (MVP) only; do not plan Phases 2–5 in
  detail until Phase 1's registry integration and result contract are
  proven out. **TODO-3 there (visualization, §4B) ships alongside Phase
  1**, not deferred — the plots are cheap once the draws already exist.
- [ ] TODO-6 (added 2026-09-10): `finite_mixture_regression.md`'s
  "Implementation Sequencing" step 5 — visualization, proven on the same
  three families as step 2 before extending with step 3.
- [ ] TODO-7 (added 2026-09-10): **Decide `edi_visualization_theme.md`'s
  scheduling** — ship as an ordinary v3.0.0 item, or pull forward to land
  before/alongside `release_v2_0_0.md → TODO-6i/6j/6k` per that file's own
  "Scheduling caveat" section. Not decided here.
- [ ] TODO-8 (added 2026-09-10): `survival_curve_visualization.md →
  TODO-1..7`.
- [ ] TODO-9 (added 2026-09-10): `simulation_framework_visualization.md →
  TODO-1..7`.
- [ ] TODO-10 (added 2026-09-10): the four v2.0.0-hosted visualization
  sections — `sequential_inference.md → TODO-6`,
  `response_adaptive_randomization.md → TODO-6`,
  `causal_forest_inference.md`'s "HTE visualization" section,
  `multi_arm_designs.md → TODO-4b` — each independently gated on its own
  host plan's core statistical work (v2.0.0) landing first; not otherwise
  dependent on each other or on anything else in this file.
- [ ] TODO-11 (added 2026-09-11): `inference_plots.md → TODO-1` — decision
  gate: pursue all 19 families/102 classes, or triage to a prioritized
  subset first.
- [ ] TODO-12 (added 2026-09-11): `inference_plots.md → TODO-2` — build
  the reporting layer + a proving batch of 2-3 families before scaling to
  the rest.
- [ ] TODO-13 (added 2026-09-11): `inference_plots.md → TODO-3` — the six
  survival-family entries gated on TODO-8 above
  (`survival_curve_visualization.md`) landing first; do not schedule
  ahead of it.
- [ ] TODO-14 (added 2026-09-11): `inference_plots.md → TODO-4..5` —
  remaining sixteen families, batched, then documentation.

## Standing constraints

Same as every release: `define_inference_class()` for every new class; no
mixin splicing, no class-name dispatch; kernel conventions per
`sexp_removal_rcppeigen_conversion_spec.md`; targeted compile only (see
the repo `CLAUDE.md`). Finite mixture regression adds no new package
dependency (its own decision); Bayesian-Stan adds `cmdstanr`/`posterior`
(optionally `bridgesampling`) as `Suggests`-only, gated by
`requireNamespace()`/`cmdstanr::cmdstan_version()`, never a hard
dependency of `R/EDI`. The visualization items add `Suggests`-only
`ggplot2` (already a `Suggests` dependency via `InferenceSuite`),
optionally `plotly`/`DT` (per `inference_suite_interactive_reporting.md`'s
convention), `bayesplot` (Bayesian posterior plots only), and
`survminer`-convention KM plotting (built on `ggplot2`, no new hard
dependency beyond it) — every one gated by `requireNamespace()`, every one
degrading to a static/absent-plot fallback rather than an error, verified
on the no-Suggests CI leg.
