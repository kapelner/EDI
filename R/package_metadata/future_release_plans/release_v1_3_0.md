# Release Scope: v1.3.0 — Design Extensions and Model Diagnostics

> **Depends on:** `release_v1_2_0.md` (the merged greedy engine with
> general `prob_T`); the diagnostics half also on `release_v1_1_0.md → TODO-3`
> (`SolverDiagnostics`, the shared report surface). Release index over plans in `../new_feature_plans/` and `../bug_fix_plans/`.
> (Global ordering: see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (thematic 1.x split); **amended the same day (user
decision): the theoretical-design backlog — every plan commissioned from
`missing_theoretical_design_classes_literature_audit.md` — moves to
`release_v2_0_0.md`.** What remains here are the design extensions
commissioned from the *practice* audit
(`missing_design_classes_literature_audit.md`) plus the already-approved
many-by-many family: all two-arm, one assignment per subject, on the
existing design factory.

**Retitled 2026-10-20 (user decision).** v1.3.0 now has two themes: the design
extensions above, and the `ModelDiagnostics` declaration contract plus the
nine-family pilot batteries (`model_diagnostics_framework.md`; moved here from
v1.1.0 `TODO-17z` via v1.2.0 `TODO-35`, split into a contract item and one item
per family so each is a reviewable unit). The two halves are independent.

## In scope (by plan)

### Cluster-level and allocation-ratio generalizations (practice audit)
- `cluster_level_covariate_balancing_designs.md` — `cluster_col =` on
  every fixed balancing design (constrained cluster randomization,
  pair-matched clusters, matched cluster quadruplets),
  `DesignFixedClusterSaturation`, graph-cluster documentation. Design
  audit #2 (rank 1), #4, #8.
- `unequal_allocation_matching_greedy_minimization.md` — `prob_T ≠ 0.5`
  on matched / greedy designs (k-tuples or reservoir), `target_ratio` on
  sequential coins, `neyman_prob_T()` helper, per-stratum `prob_T`. Design
  audit #1. Note: the allocation-ratio-*preserving* coin rules
  (Kuznetsova-Tymofyeyev) live in the 2.0.0 classical-completions plan;
  ship the plain `target_ratio` here and the ARP variants there.

### New timing family
- `design_seq_many_by_many.md` — `DesignSeqManyByMany` + `Bernoulli` /
  `CRD` / `Blocking` / `Rerandomization` (Zhou et al. 2018) / `Atkinson`;
  TODO-1 decision batch taken in the 1.1.0 Phase 0 sitting.
  `../new_research_ideas/design_seq_many_by_many_greedy_pair_switch.md`
  follows if wanted.

### Model diagnostics (added 2026-10-20)
- `model_diagnostics_framework.md → TODO-1..6` — registry-declared assumption
  checks returning typed results with pre-specified gate thresholds, one shared
  report with `SolverDiagnostics`, then the nine pilot families (57 classes).
  The full 66-class roster, the four new families and the visualization layer
  stay in v2.0.0 (`release_v2_0_0.md → TODO-5c`).

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Unequal allocation**
  `unequal_allocation_matching_greedy_minimization.md → TODO-1..5` (its
  TODO-1 route decision depends on the 1.2.0 greedy merge's `pair_mode`
  finding; ARP coins deferred to 2.0.0).
- [ ] TODO-2: **Cluster-level balancing designs**
  `cluster_level_covariate_balancing_designs.md → TODO-1..5`.
- [ ] TODO-3: **Many-by-many family** `design_seq_many_by_many.md →
  TODO-2..10` (TODO-2's shared-ingestion extraction is behavior-
  preserving under golden test).
- [ ] TODO-4: Registry / capability metadata sweep (`supports("cluster")`,
  `prob_T` capability, new `timing_family`) and the design-side vignette
  update.
- [ ] TODO-5 (moved 2026-10-20, user decision, from v1.1.0 `TODO-17z` via v1.2.0 `TODO-35`): **`ModelDiagnostics` — contract** (`model_diagnostics_framework.md → TODO-1, 2, 4, 5, 6`). Small and first; every family item below depends on it.
  - **Decision gate** (plan TODO-1): registry field shape (per class vs per component), the typed check-result contract, the severity taxonomy and what the report does with each level, and ratify the nine pilot families below.
  - **Declaration contract** (plan TODO-2): an `assumption_checks` registry field naming each check, its applicability, its implementation and its **declared gate-threshold constant** (so a selection pipeline is a pure, pre-specified function). `ModelDiagnostics$new(des_obj)` discovers applicable classes as `InferenceSuite` does; a class with no declared checks is a typed `no_declared_checks` row, never silently omitted; `likelihood_tier = "none"` classes never disqualify. Results are typed (statistic, p-value or flag, severity, optional plot), never free text.
  - **Formula-grid wiring** (plan TODO-4): checks run across `~w`, `~w + .`, `~w * .` and splines, shown per cell.
  - **Shared report surface** (plan TODO-2, with `public_diagnostics_api_spec.md`): one table with `SolverDiagnostics`' rows, so a user sees "converged fine, PH violated" as one row; minimal assumption table and plain HTML (plan TODO-5; the plot layer is v2.0.0).
  - **Documentation** (plan TODO-6): vignette fronting the report-alongside-prespecified-analysis workflow, roxygen.
  - **Gate:** a toy class declares one check end to end; the report renders it with a `SolverDiagnostics` row; `no_declared_checks` and the none-tier rule are tested.
  - **Depends on:** `release_v1_1_0.md → TODO-3` (`SolverDiagnostics`). `release_v1_1_0.md → TODO-17y`'s optional assumption gate consumes these results.
- [ ] TODO-6 (added 2026-10-20, user decision): **Pilot battery: Cox PH / stratified Cox** (`model_diagnostics_framework.md → TODO-3`, family 1 of 9; 6 classes).
  - **Classes:** `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr`, `InferenceSurvivalKKLWACoxPHIVWC`, `InferenceSurvivalKKLWACoxPHOneLik`, `InferenceSurvivalKKStratCoxPHIVWC`, `InferenceSurvivalKKStratCoxPHOneLik`.
  - **Checks:** proportional hazards via scaled Schoenfeld residuals (Grambsch–Therneau); covariate functional form.
  - **Known-violation recovery test:** simulated time-varying-effect data must be flagged by the PH check; proportional-hazards data must pass at the nominal rate. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-7 (added 2026-10-20, user decision): **Pilot battery: Poisson / quasi-Poisson / robust-Poisson** (`model_diagnostics_framework.md → TODO-3`, family 2 of 9; 4 classes).
  - **Classes:** `InferenceCountPoisson`, `InferenceCountQuasiPoisson`, `InferenceCountRobustPoisson`, `InferenceCountKKCondPoissonOneLik`.
  - **Checks:** overdispersion (Cameron–Trivedi); zero-inflation against the observed zero count. Lighter on `InferenceCountRobustPoisson`: the mean-model functional-form check applies, the overdispersion check matters less because its SE is already dispersion-robust.
  - **Known-violation recovery test:** overdispersed and zero-inflated simulated counts must be flagged; equidispersed data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-8 (added 2026-10-20, user decision): **Pilot battery: Negative binomial / ZINB / hurdle** (`model_diagnostics_framework.md → TODO-3`, family 3 of 9; 7 classes).
  - **Classes:** `InferenceCountNegBin`, `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`, `InferenceCountHurdleNegBin`, `InferenceCountHurdlePoisson`, `InferenceCountKKHurdlePoissonIVWC`, `InferenceCountKKHurdlePoissonOneLik`.
  - **Checks:** dispersion-parameter adequacy; mixture-component support.
  - **Known-violation recovery test:** data with a mis-specified dispersion or an unsupported zero-inflation component must be flagged; correctly specified data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-9 (added 2026-10-20, user decision): **Pilot battery: Incidence GLM family (logit / probit / log / identity / modified-Poisson links)** (`model_diagnostics_framework.md → TODO-3`, family 4 of 9; 6 classes).
  - **Classes:** `InferenceIncidLogRegr`, `InferenceIncidProbitRegr`, `InferenceIncidLogBinomial`, `InferenceIncidModifiedPoisson`, `InferenceIncidKKModifiedPoisson`, `InferenceIncidBinomialIdentityRiskDiff`.
  - **Checks:** separation (surfacing the existing internal `EDI_SEPARATION_THRESHOLD` / `is_separated_coefficient_magnitude()` machinery as a user-visible diagnostic); calibration (Hosmer–Lemeshow-style plus calibration plots); link linearity. Log- and identity-link members additionally need a boundary check, since fitted probabilities can leave [0, 1] under those links.
  - **Known-violation recovery test:** completely separated data and a nonlinear-link truth must be flagged; for log/identity links a fit with out-of-range fitted probabilities must be flagged. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-10 (added 2026-10-20, user decision): **Pilot battery: Ordinal regression family (proportional-odds, adjacent-category, continuation-ratio, cauchit / cloglog / probit / stereotype links)** (`model_diagnostics_framework.md → TODO-3`, family 5 of 9; 8 classes).
  - **Classes:** `InferenceOrdinalPropOddsRegr`, `InferenceOrdinalAdjCatLogitRegr`, `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`, `InferenceOrdinalContRatioRegr`, `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalStereotypeLogitRegr`, `InferenceOrdinalKKCondAdjCatLogitRegr`.
  - **Checks:** Brant proportionality test for the proportional-odds and adjacent-category members; category-collapsibility sanity across all. Continuation-ratio is proportional-odds-exempt by construction (sequential-logit form): its battery is the lighter functional-form / link check only, never Brant.
  - **Known-violation recovery test:** non-proportional-odds data must be flagged by Brant for the members that carry it; continuation-ratio must never be run through Brant; proportional data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-11 (added 2026-10-20, user decision): **Pilot battery: OLS / robust** (`model_diagnostics_framework.md → TODO-3`, family 6 of 9; 7 classes).
  - **Classes:** `InferenceContinOLS`, `InferenceContinLin`, `InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`, `InferenceContinRobustRegr`, `InferenceContinKKRobustRegrIVWC`, `InferenceContinKKRobustRegrOneLik`.
  - **Checks:** residual structure, heteroskedasticity, influence, with the honest caveat stated in the report that under HC/sandwich SEs several classical checks matter less for the treatment coefficient.
  - **Known-violation recovery test:** heteroskedastic data and a single high-leverage point must be flagged; well-behaved data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-12 (added 2026-10-20, user decision): **Pilot battery: Beta / ZOIB / fractional logit** (`model_diagnostics_framework.md → TODO-3`, family 7 of 9; 3 classes).
  - **Classes:** `InferencePropBetaRegr`, `InferencePropZeroOneInflatedBetaRegr`, `InferencePropFractionalLogit`.
  - **Checks:** boundary-mass adequacy; precision-submodel checks.
  - **Known-violation recovery test:** data with excess boundary mass or a wrong precision submodel must be flagged; correctly specified data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-13 (added 2026-10-20, user decision): **Pilot battery: GEE (quasi tier)** (`model_diagnostics_framework.md → TODO-3`, family 8 of 9; 4 classes).
  - **Classes:** `InferenceCountPoissonKKGEE`, `InferenceIncidKKGEE`, `InferenceOrdinalKKGEE`, `InferencePropKKGEE`.
  - **Checks:** working-correlation adequacy.
  - **Known-violation recovery test:** data with a misspecified within-cluster correlation must be flagged; data matching the working structure must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-14 (added 2026-10-20, user decision): **Pilot battery: GLMM classes** (`model_diagnostics_framework.md → TODO-3`, family 9 of 9; 12 classes).
  - **Classes:** `InferenceContinKKGLMM`, `InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferenceOrdinalKKCLMM`, `InferenceOrdinalKKCLMMCauchit`, `InferenceOrdinalKKCLMMCloglog`, `InferenceOrdinalKKCLMMProbit`, `InferencePropKKGLMM`, `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`, `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`, `InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`, `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik`.
  - **Checks:** random-effect distribution and variance-component sanity (a boundary or collapsed σ is reported, not hidden; see v1.0.5 TODO-31).
  - **Known-violation recovery test:** non-normal random effects and a collapsed variance component must be flagged; correctly specified data must pass. Each check also gets a no-violation test at the nominal false-flag rate.
  - **Depends on:** `TODO-5` (contract).
- [ ] TODO-15: **Release mechanics** per `release.md`.

## Standing constraints

As 1.1.0/1.2.0: additive (the diagnostics are opt-in new objects; no existing class's results change), defaults preserved under the
numerical-equivalence rule (`cross_platform_reproducibility.md` D2; every new `cluster_col` /
`prob_T` argument defaults to today's behaviour), `define_design_class()`
for every class, kernel conventions, targeted compile only.
