# `ModelDiagnostics`: Per-Model Assumption Batteries, Registry-Declared

> **Depends on:** `InferenceSuite`'s shipped plumbing (registry discovery,
> per-class failure isolation, `num_cores`, `formulas`, screen/HTML
> reporting) — reused, not duplicated. Sits **above** the numerical
> diagnostics layer (`public_diagnostics_api_spec.md`'s
> `SolverDiagnostics`, v1.1.0) and shares its reporting surface: a user
> should see "converged fine, PH violated" as one row. Split (2026-09-02,
> user decision) from what was briefly one combined plan with
> `model_selection_framework.md` — that sibling consumes this plan's
> check results as assumption gates in its selection table; this plan
> stands alone as the **absolute** half of model criticism ("does this
> model's own assumptions hold"), the sibling is the **relative** half
> ("which candidate fits best"). **Release target: v1.1.0**
> (`release_v1_1_0.md → TODO-17z`; moved from v2.0.0 `TODO-6g` on
> 2026-09-05, user decision, resolving TODO-1(e)): this is the lighter
> half — no fold/split substrate needed, checks are in-sample — so the
> declaration contract and the pilot batteries ship in 1.x alongside the
> sibling's Phase A (`model_selection_framework.md → TODO-17y`), which
> consumes this plan's typed check results as its assumption gate once
> both exist. Sequenced after `SolverDiagnostics`
> (`public_diagnostics_api_spec.md`, v1.1.0 `TODO-3`) because the two
> share one report surface. The per-class rollout beyond the pilots is a
> ledger inside this plan, not a release item. (Global ordering: see
> `_master.md` 5AH.)
>
> **Amended 2026-09-10 (user decision): the "ledger" is promoted to scoped
> v2.0.0 work.** §3B (full 66-class roster, verified against
> `public_api_inventory.csv`), §3C (the 36-class none-tier catalogue), and
> §6 (visualization — ggplot2/HTML/plotly/DT) are new, v2.0.0-targeted
> sections (`release_v2_0_0.md → TODO-5c`; `_master.md` Phase 5AH extended,
> not superseded). **The v1.1.0 scope (TODO-1..4: decision gate,
> declaration contract, the original 9-family pilot, formula-grid wiring)
> is unchanged** — this amendment only fills in what ships after the
> pilot, it does not move the pilot itself. Sibling plan
> `design_diagnostics_framework.md` (also v2.0.0, same day) does the same
> for the *design* side (covariate balance, randomization-distribution
> visualization) — the two are meant to become one combined pre-analysis
> report; see that file's own header.

Written 2026-09-02 (user proposal: `ModelDiagnostics(des_obj)` giving "a
whole host of model diagnostics for the different offered models, where
each model has different diagnostic checking functions based on its own
specific assumptions," across formulas `~1`, `~.`, `~.*w`,
nonparametrics).

Related:
[post_selection_inference_menu.md](../new_research_ideas/post_selection_inference_menu.md)
— the reference report on honest inference after diagnostics-gated
selection; this plan's gate constants (§2) are what make that report's
selection-inclusive test a pre-specified statistic.

## 1. Why

`InferenceSuite` reports what every applicable model *estimates*, but
nothing in the package checks whether any model's *assumptions hold* on
this data: no proportional-hazards check for the Cox classes, no
overdispersion check for the Poisson classes, no proportionality check
for the cumulative-logit classes, no calibration or residual diagnostics
anywhere user-visible. The gap matters most where the package's own
estimands lean on the outcome model — the g-computation and
marginal-estimand classes standardize over a fitted outcome model, so
that model's adequacy directly determines the estimate's quality — and
it matters for the suite's transparency story too: a table of forty
estimates is more honest when each row carries evidence about whether
its model believes in itself.

## 2. The architectural centerpiece: checks are declared, not switchboarded

**Classes declare their assumption checks the same way they declare
capabilities.** A new registry field (per class or per component, e.g.
`assumption_checks`) names each check, its applicability conditions, and
its implementation. `ModelDiagnostics$new(des_obj)` discovers applicable
classes exactly as `InferenceSuite` does, then discovers each class's
declared battery from the registry — no hand-maintained mapping from
~140 classes to their checks, and a newly added class brings its own
battery with it or shows up as a typed `no_declared_checks` row (never a
silent omission).

A check returns a **typed result** — statistic, p-value or qualitative
flag, severity, optional plot object — never free text, so the panel
renders uniformly and downstream consumers (the selection sibling's
gates; the HTML report) are mechanical.

Three contract requirements ratified 2026-09-02 (user decision, working
through the post-selection-inference mechanics with the sibling plan —
see its §5):

- **Gate thresholds are declared constants.** Each check's declaration
  carries its disqualification threshold (e.g., "Schoenfeld rejects at
  0.05 → Cox cell disqualified") as a typed field, so the sibling's
  pipeline is a pure, pre-specified function — a requirement for the
  selection-inclusive randomization statistic to be well-defined, and
  the difference between a gate and a judgment call.
- ~~**Every check carries a `blindable` tag.** Covariate-side checks
  can run treatment-blinded; treatment-side checks inherently see `w`
  and cannot; the tag partitioned each battery into a blinded and an
  unblinded tranche that the sibling's `InferencePostSelection`
  dispatched its execution path off.~~ **Removed 2026-09-06 (user
  decision, "strip blinding … it's something that will never be
  implemented"; see the sibling's §5 removal note).** Every check runs
  on the model as fitted — with `w` in it, since `w` is part of the data
  — and every check re-runs on every randomization replicate. There is
  no tag, no tranche, and no cheaper execution path to dispatch to.
- **`likelihood_tier = "none"` classes never disqualify.** Rank/exact
  classes have essentially no parametric assumptions to violate; their
  batteries are empty-or-advisory by construction, which is what lets
  the sibling plan require one as the guaranteed non-empty-qualified-set
  fallback.

Checks run across the same formula grid the sibling plan uses (`~w`,
`~w + .`, `~w * .`, splines): an assumption can hold under one specification
and fail under another, and the panel should show that per cell.

## 3. Pilot batteries (v1.1.0)

Full rollout is per-class work tracked like the path audit's per-class
metadata was; the pilot tranche (TODO-3) is:

| Class family | Assumption checks |
|---|---|
| Cox PH / stratified Cox | proportional hazards via scaled Schoenfeld residuals (Grambsch–Therneau); covariate functional form |
| Poisson / quasi-Poisson | overdispersion tests (Cameron–Trivedi); zero-inflation check against the observed zero count |
| Negative binomial / ZINB / hurdle | dispersion-parameter adequacy; mixture-component support |
| Logistic / probit | separation — surfacing the package's **existing internal** `EDI_SEPARATION_THRESHOLD` / `is_separated_coefficient_magnitude()` machinery as a user-visible diagnostic rather than only an internal guard; calibration (Hosmer–Lemeshow-style plus calibration plots); linearity of the link |
| Proportional odds | proportionality/parallel-lines test (Brant); category-collapsibility sanity |
| OLS / robust | residual structure, heteroskedasticity, influence — with the honest caveat, stated in the report, that under HC/sandwich SEs several classical checks matter less for the treatment coefficient |
| Beta / ZOIB / fractional logit | boundary-mass adequacy; precision-submodel checks |
| GEE (quasi tier) | working-correlation adequacy |
| GLMM classes | random-effect distribution and variance-component sanity |

## 3B. Full roster (added 2026-09-10, user decision — v2.0.0)

**Promoted from the open-ended "ledger" (§3's original framing) into scoped
v2.0.0 work.** Verified against `R/package_tests/public_api_inventory.csv`
(the same machine-generated inventory the comprehensive-suite quality gates
use) rather than estimated: EDI ships **102 concrete `Inference*` classes**
(103 `r6_class` rows tagged `Inference*`, minus `InferenceSuite` itself,
which is the orchestrator, not a fittable model). Classifying each by
`infer_inference_likelihood_tier()`'s actual regex
(`R/EDI/R/inference_class_registry.R:623`) gives:

- **66 classes** with `likelihood_tier` `full` (46), `partial` (11,
  Cox/conditional-logit family), or `quasi` (9, GEE/robust/composite) —
  these have a real parametric or quasi-likelihood model whose assumptions
  can be violated, and are this section's scope.
- **36 classes** with `likelihood_tier = "none"` — rank/exact/
  distribution-free tests, closed-form 2×2-table incidence estimators,
  g-computation wrappers that standardize over a *different* class's fit,
  and IVWC (variance-only, no joint likelihood) estimators. Per §2's
  existing rule, these correctly get no battery — see §3C for the full,
  verified list rather than a hand-wave.

The table below extends each of §3's nine pilot families with its **exact**
class membership (most families turn out broader than the pilot's
single-example naming suggested) and adds **four families the pilot never
named** — every `full`/`partial`/`quasi` class is accounted for exactly
once across the thirteen rows (6+4+7+6+8+7+3+4+12+2+1+4+2 = 66).

| Class family | Classes (exact, verified) | Assumption checks |
|---|---|---|
| Cox PH / stratified Cox | `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr`, `InferenceSurvivalKKLWACoxPHIVWC`, `InferenceSurvivalKKLWACoxPHOneLik`, `InferenceSurvivalKKStratCoxPHIVWC`, `InferenceSurvivalKKStratCoxPHOneLik` (6) | as §3 |
| Poisson / quasi-Poisson / robust-Poisson | `InferenceCountPoisson`, `InferenceCountQuasiPoisson`, `InferenceCountRobustPoisson`, `InferenceCountKKCondPoissonOneLik` (4) | as §3's overdispersion/zero-inflation checks, but **lighter on `RobustPoisson`**: the mean-model (functional-form) check still applies; the variance-model overdispersion check matters less once the SE is already dispersion-robust by construction — same logic as the OLS/robust row below |
| Negative binomial / ZINB / hurdle | `InferenceCountNegBin`, `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`, `InferenceCountHurdleNegBin`, `InferenceCountHurdlePoisson`, `InferenceCountKKHurdlePoissonIVWC`, `InferenceCountKKHurdlePoissonOneLik` (7) | as §3 |
| Incidence GLM family (logit/probit/log/identity/modified-Poisson links) | `InferenceIncidLogRegr`, `InferenceIncidProbitRegr`, `InferenceIncidLogBinomial`, `InferenceIncidModifiedPoisson`, `InferenceIncidKKModifiedPoisson`, `InferenceIncidBinomialIdentityRiskDiff` (6) | as §3's separation/calibration/link-linearity checks; **log- and identity-link members additionally need a boundary check** — fitted probabilities can leave `[0,1]` under those links, unlike logit |
| Ordinal regression family (proportional-odds, adjacent-category, continuation-ratio, cauchit/cloglog/probit/stereotype links) | `InferenceOrdinalPropOddsRegr`, `InferenceOrdinalAdjCatLogitRegr`, `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`, `InferenceOrdinalContRatioRegr`, `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalStereotypeLogitRegr`, `InferenceOrdinalKKCondAdjCatLogitRegr` (8) | Brant proportionality test for the proportional-odds and adjacent-category members; category-collapsibility sanity across all. **Continuation-ratio is proportional-odds-exempt by construction** (sequential-logit form) — its battery is the lighter functional-form/link check only, never Brant |
| OLS / robust | `InferenceContinOLS`, `InferenceContinLin`, `InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`, `InferenceContinRobustRegr`, `InferenceContinKKRobustRegrIVWC`, `InferenceContinKKRobustRegrOneLik` (7) | as §3 |
| Beta / ZOIB / fractional logit | `InferencePropBetaRegr`, `InferencePropZeroOneInflatedBetaRegr`, `InferencePropFractionalLogit` (3) | as §3 |
| GEE (quasi tier) | `InferenceCountPoissonKKGEE`, `InferenceIncidKKGEE`, `InferenceOrdinalKKGEE`, `InferencePropKKGEE` (4) | as §3 |
| GLMM classes | `InferenceContinKKGLMM`, `InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferenceOrdinalKKCLMM`, `InferenceOrdinalKKCLMMCauchit`, `InferenceOrdinalKKCLMMCloglog`, `InferenceOrdinalKKCLMMProbit`, `InferencePropKKGLMM`, `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`, `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`, `InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`, `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik` (12) | as §3 |
| **Weibull parametric survival** *(new family)* | `InferenceSurvivalWeibullRegr`, `InferenceSurvivalKKWeibullMarginal` (2) | Cox-Snell residuals for overall fit adequacy; log-log survival linearity — the fully-parametric-baseline functional-form check Cox's semi-parametric baseline never needs |
| **Dependent-censoring transform** *(new family)* | `InferenceSurvivalDepCensTransformRegr` (1) | copula/dependence-parameter sensitivity (does the fitted failure–censoring association drive the estimate); bivariate transform goodness-of-fit. `NEEDS VERIFICATION` — no established off-the-shelf test is known for this specific model; likely needs a simulation-based (parametric-bootstrap) calibration check rather than a closed-form statistic |
| **Conditional logistic, matched-set** *(new family)* | `InferenceIncidKKCondLogitIVWC`, `InferenceIncidKKCondLogitOneLik`, `InferenceIncidKKCondLogitGLMMIVWC`, `InferenceIncidKKCondLogitGLMMOneLik` (4) | within-set covariate balance at the fitted model (not just at the design); a conditional-likelihood analogue of calibration, grouped by matched set rather than pooled Hosmer–Lemeshow |
| **Quantile regression, joint likelihood** *(new family)* | `InferenceContinKKQuantileRegrOneLik`, `InferencePropKKQuantileRegrOneLik` (2) | quantile-crossing check (do fitted quantiles at adjacent τ preserve order); pinball-loss-based goodness-of-fit (Koenker & Bassett 1978). No classical residual-normality assumption applies — quantile regression is semi-parametric by construction, the same "several classical checks don't apply" caveat as OLS/robust, stated explicitly here so the panel never renders a misleading residual plot for these two classes |

## 3C. None-tier catalogue (added 2026-09-10) — the 36 classes with no battery, and why

Documented explicitly rather than left as an assertion, since a class here
must show up as a typed, verified `no_declared_checks` row (§2), not a
silent gap:

| Group | Classes | Why no parametric assumption to check |
|---|---|---|
| Rank / distribution-free tests | `InferenceAllSimpleWilcox`, `InferenceAllKKWilcoxIVWC`, `InferenceOrdinalJonckheereTerpstraTest`, `InferenceOrdinalPairedSignTest`, `InferenceOrdinalRidit`, `InferenceSurvivalGehanWilcox`, `InferenceSurvivalLogRank`, `InferenceSurvivalKKRankRegrIVWC` (8; corrected 2026-09-10 — this row read 7 and omitted `KKRankRegrIVWC`, caught on a fresh re-verification against `public_api_inventory.csv` while scoping `inference_plots.md`) | test statistics are rank-based; validity comes from permutation/exchangeability, not a fitted likelihood |
| Simple mean/average-difference | `InferenceAllSimpleAverageDiff`, `InferenceAllSimpleMeanDiffPooledVar`, `InferenceAllKKMeanDiffIVWC`, `InferenceBaiAdjustedTKK14`, `InferenceBaiAdjustedTKK21`, `InferenceSurvivalKMDiff`, `InferenceSurvivalRestrictedMeanDiff` (7) | arithmetic contrasts (means, KM/RMST differences); nothing beyond the data to misspecify |
| Exact/closed-form incidence (2×2-table) | `InferenceIncidCMH`, `InferenceIncidExactBinomial`, `InferenceIncidExactFisher`, `InferenceIncidExactZhang`, `InferenceIncidExtendedRobins`, `InferenceIncidMiettinenNurminenRiskDiff`, `InferenceIncidNewcombeRiskDiff`, `InferenceIncidKKNewcombeRiskDiff`, `InferenceIncidRiskDiff`, `InferenceIncidWald` (10) | closed-form functions of table counts; no regression model fitted |
| G-computation risk-diff/ratio wrappers | `InferenceIncidGCompRiskDiff`, `InferenceIncidGCompRiskRatio`, `InferenceIncidKKGCompRiskDiff`, `InferenceIncidKKGCompRiskRatio`, `InferenceOrdinalGCompMeanDiff`, `InferencePropGCompMeanDiff` (6) | standardizes over an **outcome model owned by a different class** — any assumption check belongs to that underlying model, not this wrapper; a future TODO could thread the wrapped model's own battery through, but that is new plumbing, not a gap in this list |
| Quantile regression, IVWC (variance-only) | `InferenceContinQuantileRegr`, `InferenceContinKKQuantileRegrIVWC`, `InferencePropQuantileRegr`, `InferencePropKKQuantileRegrIVWC` (4) | rank-based variance estimator, no joint likelihood (contrast with the `OneLik` siblings in §3B, which do) |
| Ordinal partial-proportional-odds | `InferenceOrdinalPartialProportionalOddsRegr` (1) | classified `none` by the actual registry regex (matches neither `PropOdds` nor any `full` token as substrings) — **worth a quick confirmation at implementation time** that this genuinely has no checkable likelihood rather than being a regex miss; not re-derived here |
| Suite orchestrator (excluded, not counted in the 36) | `InferenceSuite` | not a fittable model |

## 6. Visualization (added 2026-09-10, user decision — v2.0.0)

TODO-5 ("assumption table, check plots, HTML") previously had zero design
detail — one unchecked line. Scoped here, consistent with `InferenceSuite`'s
existing `run_all_inference(plots=, html=)` visualization
(`R/EDI/R/inference_suite.R`) rather than inventing a separate visual
language:

- **Plot type per check**, `ggplot2`, one plot object per typed check
  result (§2's "optional plot object" field): Schoenfeld residuals vs. time
  (Cox PH family); a reliability/calibration diagram (incidence GLM family,
  Hosmer–Lemeshow-style); residual-vs-fitted + QQ + leverage, the
  `plot.lm()`-equivalent EDI currently lacks entirely (OLS/robust family);
  observed-vs-expected variance plot (Poisson/NegBin/hurdle families);
  a per-cutpoint coefficient plot for the Brant test (ordinal family);
  Cox-Snell residual plot (Weibull parametric survival); a
  working-correlation heatmap (GEE); a random-effect QQ plot
  (GLMM/CLMM/frailty family); a quantile-crossing plot (quantile-regression
  family).
- **HTML**: embed each check's plot in the shared report row next to its
  numeric result (§ "Boundaries" above already commits to "converged fine,
  PH violated" as one row) — an expandable/collapsible panel per
  (class × formula × check) cell, reusing
  `run_all_inference_render_html()`'s existing table-rendering conventions
  rather than a new HTML layer.
- **`plotly`/`DT`** (optional `Suggests`, gated the same way every other
  optional backend in this codebase is — `requireNamespace()`, never a hard
  dependency): `DT::datatable()` for a sortable/filterable assumption-check
  table in place of a static HTML table; `plotly::ggplotly()` wrapping each
  `ggplot2` diagnostic plot for hover-to-inspect points/residuals. This
  directly closes the "static only, no interactivity" gap already flagged
  against `InferenceSuite`'s own forest plot — worth offering the same
  `plotly` wrap there too once this lands, for one consistent interactivity
  story across both reports rather than two.
- Static (`ggplot2`/base HTML) stays the default; `plotly`/`DT` is opt-in
  (`interactive = TRUE` or similar) so a user without those packages
  installed gets the full report, just non-interactive — matching the
  no-Suggests CI leg's expectations.

## 4. Boundaries

- **Below**: `SolverDiagnostics` (v1.1.0) owns numerical health —
  convergence, conditioning, identifiability. This plan owns statistical
  assumptions. One shared report (coordinate via TODO-2).
- **Beside**: design-side diagnostics (match quality, reservoir size,
  within-pair distance distributions for the KK designs) are a natural
  adjacent panel but **out of scope** — they diagnose the design, not a
  model; candidate follow-on plan.
- **Sibling**: comparative fit, formula-grid guardrails, CV folds,
  the selection-inclusive randomization test,
  and the pre-specification workflow all live in
  `model_selection_framework.md`. This plan's outputs feed that plan's
  selection table as gates/flags (its TODO decides gate-vs-flag
  semantics).

## 5. The honesty rules still bind

Assumption checking is standard good practice and lower-risk than
selection, but **diagnose-then-switch is data-driven selection through
the back door** (pretest bias). Two rules, inherited from the sibling
plan and enforced here too: (1) checks never display, sort, or gate on
treatment-effect magnitude or significance (~~and run treatment-blinded
where feasible, `blind = c("omit_w", "mask_w", "none")`~~ — blinding
modes dropped 2026-09-06, user; `w` is in every fit); (2) when a diagnostic motivates
switching models, the report routes to the sibling plan's honest exits
(selection-inclusive randomization test, sample splitting 5AE, selective
inference 5AF) rather than to the switched-to model's naive p-value.
Reporting diagnostics *alongside* a prespecified analysis, without
switching, needs no correction and is encouraged — that is this plan's
front-door workflow.

## Tests

- Battery discovery: undeclared class → typed `no_declared_checks` row;
  declared check → typed result shape or typed failure; never silence.
- Known-violation recovery: simulated non-PH hazards, overdispersed
  counts, and non-parallel ordinal lines are flagged by the
  corresponding battery at reasonable power; clean data is not flagged
  at gross excess of nominal size.
- Rule 1: no check result, severity, or gate is a function of the
  treatment coefficient's magnitude or p-value (assert on a fixture
  where only `w`'s coefficient changes between two fits).
- Separation surfacing: the logistic battery's separation row agrees
  with the internal guard's determination on the same fit.
- Failure isolation: one pathological (class × formula × check) cell
  yields a typed status, never an aborted panel.
- **(added 2026-09-10, v2.0.0)** Full-roster completeness: every one of
  the 66 `likelihood_tier != "none"` classes in §3B has a declared battery
  (no silent gap); every one of the 36 §3C classes shows the typed
  `no_declared_checks` row, not an error or an omission.
- **(added 2026-09-10, v2.0.0)** Visualization: each §6 plot type renders
  without error on its family's pilot fixture; `plotly::ggplotly()`-wrapped
  and static versions of the same check agree on the underlying data (not
  just "both render"); `DT::datatable()` output is absent (falls back to
  a static table) when `DT` is not installed, verified on the no-Suggests
  CI leg.

## TODOs

- [ ] TODO-1: **Decision gate (ask the user, no code).** (a) Registry
  field shape (per class vs. per component) and the typed check-result
  contract; (b) ratify the §3 pilot tranche; (c) severity taxonomy and
  what the HTML report does with each level; (d) ~~`blind` default shared
  with the sibling plan~~ **moot (2026-09-06, user): blinding dropped
  from both plans**; (e) ~~**release placement of the pilots** — the
  declaration contract plus pilot batteries need no v2.0.0 substrate and
  could ship in a 1.x release ahead of the sibling; confirm or decline~~
  **decided (2026-09-05, user): confirmed — v1.1.0 (`TODO-17z`), in the
  same release as the sibling's Phase A rather than ahead of it; see the
  header.**
- [ ] TODO-2: **Declaration contract + shared report surface**: the
  registry field, typed result shape — **including the ratified
  per-check gate-threshold constant (§2; the `blindable` tag was
  dropped 2026-09-06)** —
  discovery, and one rendering table with `SolverDiagnostics` rows
  (coordinate with `public_diagnostics_api_spec.md`).
- [ ] TODO-3: **Pilot batteries** per §3's table, plus the
  known-violation recovery tests; per-class rollout beyond the pilots
  tracked as its own ledger thereafter.
- [ ] TODO-4: **Formula-grid wiring** (consume the sibling's grid engine
  once it exists, or a minimal local grid if this plan ships first per
  TODO-1(e)).
- [ ] TODO-5: **Reporting (v1.1.0 minimal form)**: assumption table and
  plain HTML — enough for the pilot to ship usably; the full plot/interactivity
  layer is TODO-8 below (v2.0.0), not required for the pilot itself.
- [ ] TODO-6: **Documentation**: vignette fronting the
  report-alongside-prespecified-analysis workflow, roxygen, and a
  JSS-manuscript sentence when shipped.
- [ ] TODO-7 (added 2026-09-10, v2.0.0): **Full-roster rollout** — §3B's
  thirteen families (four new beyond the original nine-family pilot;
  Weibull parametric survival, dependent-censoring transform, conditional
  logistic matched-set, quantile regression joint-likelihood) covering all
  66 `likelihood_tier != "none"` classes; §3C's none-tier catalogue shipped
  as verified documentation, including the `InferenceOrdinalPartialProportionalOddsRegr`
  classification worth double-checking (§3C's own note) before treating it
  as settled.
- [ ] TODO-8 (added 2026-09-10, v2.0.0): **Visualization layer** per §6 —
  one `ggplot2` plot function per check type (Schoenfeld residuals,
  calibration/reliability diagram, `plot.lm()`-equivalent residual/QQ/
  leverage panel, observed-vs-expected variance, Brant per-cutpoint plot,
  Cox-Snell residuals, working-correlation heatmap, random-effect QQ,
  quantile-crossing plot); HTML embedding in the shared report row;
  optional `plotly`/`DT` interactivity, `Suggests`-gated. Cross-reference:
  `inference_suite_interactive_reporting.md` (added 2026-09-10, also
  v2.0.0) is the matching retrofit onto `InferenceSuite`'s existing
  static forest plot and results table, scoped as its own plan rather
  than left as this note's aspiration.

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were supplied from
general knowledge and must be checked against the primary source before
citation in roxygen/`REFERENCES.md`.)

- Box, G. E. P. (1980). "Sampling and Bayes' inference in scientific
  modelling and robustness." *JRSS-A*, 143(4), 383–430. (Model criticism
  umbrella.) `NEEDS VERIFICATION`.
- Grambsch, P. M., and Therneau, T. M. (1994). "Proportional hazards
  tests and diagnostics based on weighted residuals." *Biometrika*,
  81(3), 515–526. `NEEDS VERIFICATION` (pages).
- Brant, R. (1990). "Assessing proportionality in the proportional odds
  model for ordinal logistic regression." *Biometrics*, 46(4),
  1171–1178. `NEEDS VERIFICATION`.
- Cameron, A. C., and Trivedi, P. K. (1990). "Regression-based tests for
  overdispersion in the Poisson model." *Journal of Econometrics*, 46,
  347–364. `NEEDS VERIFICATION`.
- Hosmer, D. W., and Lemeshow, S. (1980). "Goodness of fit tests for the
  multiple logistic regression model." *Communications in Statistics —
  Theory and Methods*, A9(10), 1043–1069. `NEEDS VERIFICATION`.
- Madigan, D., Ryan, P. B., and Schuemie, M. (2013) — already
  `[MadiganRyanSchuemie2013]` in `REFERENCES.md` (the honesty framing).
- Cox, D. R., and Snell, E. J. (1968). "A general definition of residuals."
  *JRSS-B*, 30(2), 248–275. (Cox-Snell residuals, §3B Weibull family.)
  `NEEDS VERIFICATION`.
- Koenker, R., and Bassett, G. (1978). "Regression quantiles."
  *Econometrica*, 46(1), 33–50. (Pinball loss / quantile-regression
  goodness-of-fit, §3B quantile-regression family.) `NEEDS VERIFICATION`.
