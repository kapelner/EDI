# Continuous Treatments (Dose-Response `w`)

> **Depends on:** shipped design/inference hierarchies
> (`../finished_features/fix_design_hierarchy.md`,
> `../finished_features/fix_inference_hierarchy.md`); the `estimand` axis
> (`marginal_estimand_report.md`'s `set_estimand()`). **Release target:
> v3.0.0 (tentative)** (`../future_release_plans/release_v3_0_0.md`;
> `_master.md` Phase 7, item 6).

Written 2026-09-11.

## Why

`w` is binary everywhere in EDI today: `EDI/R/design_fixed_abstract.R:173`
and `EDI/R/design_abstract.R:423` both hard-assert
`w %in% c(0L, 1L)` in `overwrite_all_subject_assignments()`, every
concrete `Design*` class's randomization mechanics draw a `{0,1}`
allocation, and every `Inference*` estimand is a scalar contrast between
the `w = 1` and `w = 0` arms (`beta_T`). Real experiments and
observational studies routinely have a continuous exposure instead — drug
dose, ad spend, price, duration, intensity, temperature — and
dose-response designs/analyses are common enough in applied causal
inference that this package's own literature audits have already run
into the gap twice without giving it a home:

- `missing_design_classes_literature_audit.md` items #9 and #32 both flag
  dose-finding/dose-ranging designs, but rule the *adaptive* dose-finding
  paradigm (3+3, CRM, BOIN) permanently out of scope — "not a randomized
  design" — without addressing the *randomized*-continuous-dose case at
  all.
- `causal_forest_inference.md`'s own "Explicitly Deferred" section lists
  "continuous doses" as not a first-release requirement, with nowhere to
  land once it is revisited.

This plan is the first one that actually owns "`w` is a real number,"
rather than approximating a dose axis with `multi_arm_designs.md`'s
discrete `K` arms.

## Relationship to other plans (scope carve-out)

- **`multi_arm_designs.md`** — `K` discrete arms (e.g. three fixed dose
  levels compared as named levels). This plan is for genuinely continuous
  `w`; it does not replace multi-arm support, and a "three-dose trial"
  can legitimately be served by either plan depending on whether the
  analysis wants discrete-arm contrasts or a fitted dose-response curve.
- **Phase I dose-finding (3+3, CRM, BOIN)** — stays explicitly out of
  scope, as `missing_design_classes_literature_audit.md` #32 already
  decided: those allocate by a safety rule, not by randomization, and are
  a different paradigm from the one EDI serves.
- **`causal_forest_inference.md`** — its deferred "continuous doses" item
  is downstream of this plan (a dose-response CATE surface would build on
  whatever estimand/design primitives land here), not the other way
  round; this plan does not implement a causal-forest dose-response
  surface itself.
- **`response_types_landscape_report.md`**'s "dose-response curves
  treated as whole objects" entry is a different axis entirely — that is
  about `y` being a functional/curve response. This plan leaves `y` as
  any of EDI's existing scalar response types and makes `w`, the
  treatment/regressor, continuous instead.

## Current Design Class Inventory (audit; all binary-`w` today)

Every concrete `Design*` class shipped today assumes `w %in% c(0L, 1L)`
(the two guards cited above). None of them support a continuous dose;
this table is the starting roster TODO-2's type-relaxation audit and
TODO-3's MVP class must work against — `DesignFixedBernoulli` is the
direct template for `DesignFixedContinuousUniform`, and
`DesignFixedRerandomization`/`DesignFixedGreedy` are the templates for
the later balance-criterion wave.

**Fixed-sample-size (`DesignFixed*`)**

| Class | What it does |
|---|---|
| `DesignFixedBernoulli` | Independent coin-flip randomization |
| `DesignFixediBCRD` | Individually balanced CRD (exact terminal allocation) |
| `DesignFixedBlocking` | Stratified-block randomization within covariate strata |
| `DesignFixedCluster` | Unblocked cluster randomization |
| `DesignFixedBlockedCluster` | Blocked + clustered randomization |
| `DesignFixedFactorial` | Balanced two-arm factorial |
| `DesignFixedBinaryMatch` | Non-bipartite matched-pair, within-pair randomization |
| `DesignFixedMatchingGreedyPairSwitching` | Matched-pair design, greedy optimization of which member is treated |
| `DesignFixedGreedy` | Covariate-balanced via greedy pairwise-swap search |
| `DesignFixedGreedyDOptimal` | Model-based (D-optimal) greedy pairwise-exchange design |
| `DesignFixedOptimal` | Deterministic single-allocation optimal design |
| `DesignFixedOptimalBlocks` | Covariate-homogeneous-block randomized design |
| `DesignFixedRerandomization` | Rejection-sampled rerandomization on covariate balance |

**Sequential, one-by-one (`DesignSeqOneByOne*`)**

| Class | What it does |
|---|---|
| `DesignSeqOneByOneBernoulli` | Sequential coin-flip |
| `DesignSeqOneByOneiBCRD` | Sequential design guaranteeing exact terminal balance |
| `DesignSeqOneByOneRandomBlockSize` | Permuted blocks with randomly varying sizes |
| `DesignSeqOneByOneSPBR` | Stratified permuted-block, fixed block size |
| `DesignSeqOneByOneUrn` | Wei's (1977/78) adaptive urn design |
| `DesignSeqOneByOneEfron` | Efron's (1971) biased-coin design |
| `DesignSeqOneByOneAtkinson` | Atkinson's (1982) covariate-adjusted biased coin |
| `DesignSeqOneByOnePocockSimon` | Pocock & Simon's (1975) minimization design |
| `DesignSeqOneByOneKK14` | Kapelner & Krieger (2014) sequential matching-on-the-fly |
| `DesignSeqOneByOneKK21` | Kapelner & Krieger (2021) outcome-weighted sequential matching |
| `DesignSeqOneByOneKK21stepwise` | Stepwise variant of KK21 |

**Observational (non-randomized, for analyzing existing data)**

| Class | What it does |
|---|---|
| `ObservationalDesign` | Fixed observational design |
| `ObservationalDesignBlocks` | Observational design with blocks |
| `ObservationalDesignMatching` | Observational matched-pair design |

## Current Inference Path Inventory (audit; regressor `w` vs. binary contrast)

`inference_plots.md` already organizes EDI's 102 concrete `Inference*`
classes into 19 model families; this reuses that taxonomy to audit a
different axis — not "what plot does this need" but "does this
estimator use `w` as an ordinary regression covariate (so a continuous
dose flows through `model_formula`/`model.matrix` almost for free) or
does it require a genuine binary two-arm contrast (so it has no
continuous-`w` analog without a new estimator)?" Grounds TODO-4's MVP
family list.

| # | Family | Verdict | Notes |
|---|---|---|---|
| 1 | Poisson / quasi-Poisson / robust-Poisson | ✅ Compatible | non-KK: `InferenceCountPoisson`, `InferenceCountQuasiPoisson`, `InferenceCountRobustPoisson` |
| 2 | Negative binomial / ZINB / hurdle | ✅ Compatible | non-KK: `InferenceCountNegBin`, `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`, `InferenceCountHurdleNegBin`, `InferenceCountHurdlePoisson` |
| 3 | OLS / robust regression | ✅ mostly / ⚠️ `InferenceContinLin` | `InferenceContinOLS`, `InferenceContinRobustRegr` compatible; `InferenceContinLin`'s design-based ANCOVA estimand is built around a binary contrast — needs its own redefinition, not just relaxing an assert |
| 4 | Quantile regression, OneLik | ❌ KK-only | both members (`InferenceContinKKQuantileRegrOneLik`, `InferencePropKKQuantileRegrOneLik`) are KK joint-likelihood, matched-design |
| 5 | Quantile regression, IVWC | ✅ Compatible (non-KK) | `InferenceContinQuantileRegr`, `InferencePropQuantileRegr`; KK siblings not |
| 6 | Cox PH / stratified Cox | ✅ Compatible (non-KK) | `InferenceSurvivalCoxPHRegr`, `InferenceSurvivalStratCoxPHRegr` — dose-response hazard ratio is a standard survival-analysis use case; KK LWA siblings not |
| 7 | Weibull parametric survival | ✅ Compatible (non-KK) | `InferenceSurvivalWeibullRegr`; `InferenceSurvivalKKWeibullMarginal` not |
| 8 | Dependent-censoring transform survival | ✅ Compatible | single class (`InferenceSurvivalDepCensTransformRegr`), non-KK |
| 9 | GEE (quasi tier) | ❌ KK-only | all 4 members are `KK*GEE`, matched-design estimating equations, not a generic marginal GEE |
| 10 | GLMM classes | ❌ KK/matched-only | every member is KK-prefixed or a matched-frailty IVWC/OneLik combiner |
| 11 | Incidence GLM family | ✅ Compatible (non-KK) | `InferenceIncidLogRegr`, `InferenceIncidProbitRegr`, `InferenceIncidLogBinomial`, `InferenceIncidModifiedPoisson`, `InferenceIncidBinomialIdentityRiskDiff` — logistic/probit dose-response curves are a textbook toxicology use case |
| 12 | Beta / ZOIB / fractional logit | ✅ Compatible | `InferencePropBetaRegr`, `InferencePropZeroOneInflatedBetaRegr`, `InferencePropFractionalLogit` — all non-KK |
| 13 | Conditional logistic, matched-set | ❌ Matched-only | all 4 members KK-prefixed, condition out matched-set nuisance parameters |
| 14 | Exact/closed-form incidence (2×2-table) | ❌ Structurally binary | CMH, Fisher, Newcombe, Wald, Miettinen-Nurminen, exact binomial/Zhang — every statistic is defined on a 2×2 table |
| 15 | G-computation risk-diff/ratio wrappers | ⚠️ Needs redefinition | non-KK members (`InferenceIncidGCompRiskDiff`/`RiskRatio`, `InferenceOrdinalGCompMeanDiff`, `InferencePropGCompMeanDiff`) predict counterfactuals at exactly `w ∈ {0,1}`; could generalize to a contrast between two doses `{w0, w0+Δ}`, but that is a redefinition, not MVP |
| 16 | Ordinal regression family | ✅ Compatible (non-KK) | `InferenceOrdinalPropOddsRegr`, `InferenceOrdinalAdjCatLogitRegr`, `InferenceOrdinalContRatioRegr`, `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`, `InferenceOrdinalOrderedProbitRegr`, `InferenceOrdinalStereotypeLogitRegr`; `InferenceOrdinalKKCondAdjCatLogitRegr` not |
| 17 | Ordinal partial-proportional-odds | ✅ Compatible | single class (`InferenceOrdinalPartialProportionalOddsRegr`), non-KK |
| 18 | Rank / distribution-free tests | ❌ Structurally binary/few-group | Wilcoxon, Gehan-Wilcox, log-rank, sign test, ridit are two/few-group statistics; `InferenceOrdinalJonckheereTerpstraTest` (an ordered-*groups* trend test) is the closest existing precedent for a dose trend but still operates on discrete groups, not a continuum |
| 19 | Simple mean/average-difference | ❌ Structurally binary | by definition a two-arm difference; family #3's plain OLS is the natural continuous-`w` replacement for this family's purpose |

**Summary:** ~32 non-KK regression-based classes across 11 families (1,
2, 3-partial, 5, 6, 7, 8, 11, 12, 16, 17) are the MVP target — `w`
already flows through them as an ordinary `model_formula` covariate, so
the dose-response slope/ADRF machinery in TODO-4 applies with no change
to the underlying kernel. Two families (`InferenceContinLin`, the
G-computation wrappers) need estimand redefinition, not just an assert
relaxation — deferred past the first landing. The remaining seven
families are structurally tied to a binary two-arm contrast — every
`KK*`-prefixed class (GEE, GLMM, IVWC/OneLik combiners, conditional
logistic) inherits this from the matched-pair Design mechanism itself
(§A's "Later-wave" note — matched continuous dosing is not MVP there
either), and the exact 2×2-table, rank/distribution-free, and
simple-mean-difference families have no continuous-dose analog without
inventing a new statistic entirely. None of these seven are attempted in
this plan.

## Proposal

Two halves: **(A)** assigning a continuous `w` under a randomized design,
and **(B)** estimating a dose-response effect from it.

### A. Design side — `w` as a continuous draw

- Root-owned private state (`w`) needs a type axis. Introduce a
  class-level `treatment_type` metadata field (`"binary"` — today's
  default and the only supported value for every existing class —
  or `"continuous"`), threaded through the two hard-coded
  `w %in% c(0L, 1L)` guards above (and any other binary-`w` assumption a
  full-repo audit turns up — TODO-2) rather than relaxing the check
  package-wide. Binary stays the default, best-supported path.
- MVP class: `DesignFixedContinuousUniform` — the continuous-`w` analog
  of `EDI/R/design_fixed_bernoulli.R`'s `DesignFixedBernoulli`. Each
  unit's dose is drawn i.i.d. from a declared support/distribution
  (`w_support = c(low, high)`, or a distribution object), independent of
  covariates — the simplest possible baseline, exactly mirroring how
  `DesignFixedBernoulli` is the simplest baseline on the binary side.
  Registered via `define_design_class()`
  (`EDI/R/design_class_factory.R`) per the existing contract, picked up
  by `populate_design_class_registry()`'s namespace scan like every other
  `Design` generator.
- Later-wave balance/optimal design extension: generalize the existing
  rerandomization / greedy pair-switch machinery (`design_fixed_greedy.R`,
  `design_fixed_rerandomization.R`) from a binary-label swap to a
  continuous-treatment balance criterion — e.g. minimizing the sum of
  squared covariate-`w` correlations (Branson & Bind's rerandomization
  for a continuous treatment) — or a D-optimal design for the
  dose-response model's parameters (the classical response-surface/DoE
  literature `missing_theoretical_design_classes_literature_audit.md` #58
  already flagged "deferred / out of scope"; this plan is what would
  un-defer the continuous-`w` slice of it, not full factorial DoE). Not
  MVP — see "Explicitly Deferred."

### B. Inference side — dose-response estimand

- New estimand via the existing `set_estimand()` axis:
  `"dose_response"`, replacing the scalar `beta_T` contrast with a fitted
  function `f(w)` and, for compatibility with the existing scalar
  Wald/LR/bootstrap/randomization contracts, a classical scalar summary —
  the marginal effect `f'(w0)` at a reference dose (default the observed
  mean dose).
- MVP estimator: parametric. Treat `w` as an ordinary continuous
  regressor (linear or polynomial/spline term) in the existing
  GLM/OLS/Cox/etc. kernels, reusing `model_formula`'s existing
  continuous-covariate support essentially as-is — the ~32 non-KK
  regression-based classes identified in the Inference Path Inventory
  above. Report the fitted average dose-response function (ADRF, Hirano
  & Imbens 2004) over a grid of `w` values with pointwise Wald or
  bootstrap confidence bands.
- Second wave: generalized propensity score (GPS) adjustment (Hirano &
  Imbens 2004) — model `w | X` (Normal/Gamma GLM depending on `w`'s
  support), include `\hat{GPS}(w_i)` as an outcome-model covariate.
- Third wave, explicitly deferred (see below): doubly-robust
  nonparametric dose-response curves (Kennedy et al. 2017's
  kernel-smoothed pseudo-outcome regression).
- Randomization inference needs a different null-generation mechanism
  than label-swapping: redraw `w` from the Design object's own
  randomization distribution (whatever (A) implements), not a
  permutation of `{0,1}` labels. This should compose for close to free
  once (A) exists — every existing randomization-inference path already
  redraws `w` from the `Design` rather than hand-rolling a permutation —
  but must be verified, not assumed (TODO-5).

## Explicitly Deferred (out of scope for the first landing)

- Phase I dose-finding / adaptive dose-escalation designs — permanently
  out of scope per the design audit (non-randomized).
- Doubly-robust nonparametric/kernel dose-response curves (Kennedy et al.
  2017) — second-wave-plus estimator, not MVP.
- Multiple simultaneous continuous treatments (e.g. dose *and* duration
  jointly) — a single continuous `w` only, first landing.
- Optimal/balanced continuous-dose designs beyond the simple i.i.d. draw
  — the rerandomization/D-optimal generalization is a later TODO.
- A causal-forest dose-response surface — downstream of
  `causal_forest_inference.md`, not this plan's job to build.
- Every `KK*`-prefixed inference class (GEE, GLMM, IVWC/OneLik
  combiners, conditional logistic) — tied to the matched-pair Design
  mechanism, itself deferred on the Design side; the exact 2×2-table,
  rank/distribution-free, and simple-mean-difference families — no
  continuous-dose analog exists without inventing a new statistic (see
  the Inference Path Inventory).
- Redefining `InferenceContinLin`'s design-based ANCOVA estimand and the
  G-computation risk-diff/ratio wrappers for a continuous-dose contrast —
  needs real rework, not an assert relaxation (see the Inference Path
  Inventory).

## Tests

- Parity vs. `lm`/`glm` with `w` as an ordinary continuous regressor
  (closed form) for the parametric MVP estimator.
- GPS-adjustment wave: parity vs. a hand-rolled two-stage GPS fit on a
  simulated fixture with a known dose-response truth.
- Simulation: a known ADRF recovered at nominal coverage across the
  pointwise CI grid (new `SimulationFramework` generator, TODO-7).
- Golden no-op: every existing binary-`w` class is bit-identical once the
  `treatment_type` axis lands — a regression guard against the TODO-2
  type-relaxation refactor changing today's behavior.

## TODOs

- [ ] TODO-1: **Decision** — pursue at all (joins a future v3.0.0
  Phase-0-style decision batch once one opens; today v3.0.0 has no Phase
  0 of its own, per `../future_release_plans/release_v3_0_0.md`). Also
  decide first-landing scope: parametric-only, or parametric + GPS
  together.
- [ ] TODO-2: `w` root-owned-state type relaxation — a `treatment_type`
  capability flag threaded through the `w %in% c(0L, 1L)` guards
  (`EDI/R/design_fixed_abstract.R:173`, `EDI/R/design_abstract.R:423`)
  and every other binary-`w` assumption a full-repo audit turns up.
- [ ] TODO-3: `DesignFixedContinuousUniform` — MVP continuous-dose
  randomized design (i.i.d. draw from a declared support/distribution),
  registered via `define_design_class()`.
- [ ] TODO-4: `"dose_response"` estimand on `set_estimand()`; parametric
  linear/polynomial/spline dose-response fit; ADRF grid + pointwise Wald
  CI. Scope: the ~32 non-KK regression classes across the 11 compatible
  families in the Inference Path Inventory; prove on 2-3 families (e.g.
  OLS, Poisson, Incidence GLM) before extending to the rest.
- [ ] TODO-5: Bootstrap and randomization-inference paths for the
  dose-response estimand (redraw `w` from the Design's own randomization
  mechanism; verify this composes for free or fix where it doesn't).
- [ ] TODO-6: GPS-adjustment second wave (Hirano & Imbens 2004).
- [ ] TODO-7: `SimulationFramework` generator with a known ADRF ground
  truth; coverage simulation.
- [ ] TODO-8: Documentation, `path_audits.html` row, benchmark row, and
  comprehensive-suite wiring per `contracts/new_model_creation.md`
  (noting the Design side does not yet have that contract's full
  equivalent — `fix_design_hierarchy.md`'s "Class Factory Implementation"
  work is the closest analog).
