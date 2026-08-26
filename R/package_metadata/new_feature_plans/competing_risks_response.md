# Competing Risks for Survival Responses — Scoping Report

> **Depends on:** shipped shallow design/inference hierarchies
> (`define_design_class()` / `define_inference_class()`, registry metadata,
> components); the shipped y/y_L/y_R interval-censoring rework
> (`../finished_features/interval_censored_survival_response.md`).
> Should be sequenced **with or after** the `dead → uncensored` rename
> (`release_v1_1_0.md → TODO-15c`; source TODO-29 in the finished
> interval-censoring plan) because both touch the same event-indicator
> plumbing across R, C++ and the Python binding. Decision-gated (TODO-1).
> (Global ordering: see `_master.md`; not yet indexed in
> `release_v1_1_0.md` — see TODO-0.)

Written 2026-08-27, commissioned from
`missing_inference_classes_literature_audit.md` (gap #9) and the
"missing response families" follow-up: competing risks was the largest
gap surfaced by the audits that appears in **no** existing plan
(`response_types_landscape_report.md` discusses recurrent events but not
competing risks).

## Scope

A **competing risk** is an event whose occurrence precludes the event of
interest (or changes its probability). Canonical examples: death from
other causes when the endpoint is cancer death; transplant when the
endpoint is death on the waiting list; hospital discharge when the
endpoint is in-hospital infection; relapse vs. non-relapse mortality in
haematology; return-to-work vs. disability-pension exit in labour
economics; graduation vs. dropout in education.

This report evaluates adding competing-risks support to EDI's existing
`survival` response type — **not** a new response type. The subject-level
data shape is still one time-to-event `y` (or `y_L`/`y_R` bounds) per
subject; what changes is that the event indicator becomes a **cause code**
with ≥2 event types instead of a 0/1 indicator. In the tiering language of
the two audits this is univariate `y`, two-arm, one assignment per subject
— i.e. it sits in the prioritized tier, not the deferred one.

It covers: (1) why this matters, with frequency evidence; (2) the
estimands practitioners use; (3) what EDI stores today and what has to
change; (4) the inference classes to add, in waves; (5) design-side and
`SimulationFramework` implications; (6) a decision recommendation and
staged TODOs.

## Why This Matters

Competing risks are the single most-mishandled survival situation in the
trial literature:

- Austin & Fine (*Stat Med* 2017; summarized at thestatsgeek 2017)
  reviewed 40 time-to-event RCTs in top journals (late 2015): **31 were
  competing-risk-prone, and 77% of those still used Kaplan-Meier**, which
  overestimates cumulative incidence when competing events are censored.
- Fine-Gray / cumulative-incidence analyses are **occasional** in
  cardiology, nephrology, oncology and geriatrics, usually as a secondary
  analysis (JACC 2024 review of competing risks in cardiovascular trials).
- Cause-specific hazards are what regulators and Cochrane recommend for
  aetiological questions; subdistribution hazards (Fine-Gray) for
  prognostic/absolute-risk questions (Latouche et al. 2013; Austin, Lee &
  Fine *Circulation* 2016).
- Econ/education analogues (multiple exit states from unemployment,
  schooling, welfare) are analysed with competing-risks duration models
  (Lancaster 1990; van den Berg 2001) in the applied-micro literature,
  though RCT applications are rarer than in medicine.

The frequency label from the inference audit is **"common in at least
one major field"** (medicine) with a high *error* rate — i.e. the value of
a package doing it right is larger than the raw usage share suggests.

## What Practitioners Actually Estimate

There are two families of estimand, and the package should make the
distinction explicit rather than pick one silently:

### Cause-specific hazard (CSH) family — "aetiological"

- **Cause-specific Cox model**: treat competing events as censored at
  their time, fit Cox for the event of interest. Estimand: cause-specific
  log hazard ratio. This is what most trials that "handle" competing risks
  actually do, and it is *exactly* the existing `InferenceSurvivalCoxPHRegr`
  applied to a recoded indicator `1{cause == k}`.
- **Cause-specific log-rank test**: same recode, existing
  `InferenceSurvivalLogRank`.
- Interpretation caveat: CSH ratios describe the instantaneous rate among
  those still at risk; they do not translate to absolute risk when the
  competing hazard also differs by arm.

### Cumulative incidence / subdistribution family — "prognostic"

- **Aalen-Johansen cumulative incidence function (CIF)**: the
  nonparametric estimate of P(event of type k by time t), replacing KM's
  1 − S(t). Treatment-effect estimands: CIF difference at a horizon `t*`,
  or CIF ratio; variance by Aalen-Johansen/Greenwood-type formula or
  bootstrap.
- **Gray's test**: the CIF analogue of the log-rank test (Gray 1988).
- **Fine-Gray subdistribution hazard model** (Fine & Gray 1999): Cox-type
  model on the subdistribution hazard, fit by weighted partial likelihood
  with inverse-probability-of-censoring weights (IPCW) on subjects who
  experienced a competing event. Estimand: subdistribution log hazard
  ratio, which maps monotonically to the CIF.
- **Restricted mean time lost (RMTL)** to cause k (Andersen 2013): the
  competing-risks analogue of RMST difference; area under the CIF to
  `t*`.
- **Direct binomial / pseudo-value regression** on the CIF at `t*`
  (Klein & Andersen 2005; Scheike, Zhang & Gerds 2008): GLM on
  jackknife pseudo-observations — attractive here because it reduces to
  the package's existing GLM machinery once pseudo-values are computed.

Practitioner usage, in decreasing order: cause-specific Cox (by far);
CIF plots; Fine-Gray; Gray's test; RMTL/pseudo-values (rare/emerging).

## What EDI Stores Today

- Survival responses are the triple `y` / `y_L` / `y_R` per subject
  (`Design$add_one_subject_response(t, y, y_L, y_R)`,
  `design_abstract.R:255`; `add_all_subject_responses(ys, y_Ls, y_Rs)`,
  `:358`). Exact events store `y`; censored subjects store bounds and
  `y = NA`. Right-censoring is `(y_L = c, y_R = Inf)`.
- **The event indicator is not stored — it is derived**:
  `get_effective_dead()` returns `as.integer(!is.na(private$y))`
  (`design_abstract.R:807`), and `get_effective_time()` returns
  `ifelse(is.na(y), y_L, y)` (`:792`). The `Inference` base copies these
  into `private$y` / `private$dead` at construction
  (`inference_all_abstract.R:94`).
- `survival::Surv(y, dead)` appears at 31 call sites across the survival
  inference classes; the Cox path uses `fast_coxph_regression_prebuilt_cpp`
  with `survival::coxph.fit` fallback and `icenReg::ic_sp` for
  left/interval censoring; KM/RMST/log-rank/Gehan use `survival::survfit`
  / `survdiff` / `interval::ictest`.
- Registry metadata carries `supports_general_censoring` per class
  (`inference_class_registry.R:681`), inferred from each class's
  `supports_interval_or_left_censored_data()`; the test fixtures use
  `constraint_survival_censoring_supported`
  (`public_argument_combination_constraints.R:240`).
- Nothing in `R/EDI/R`, `src/`, or `DESCRIPTION` references `cmprsk`,
  `finegray`, `riskRegression`, `prodlim`, or competing risks.
- The `dead → uncensored` rename (TODO-15c) is pending and touches
  ~576 R occurrences, `src/*.cpp`, and the Python binding.

So the minimal storage change is one new per-subject integer:
**`event_type`** (cause code; `0` = censored, `1..K` = cause), stored
alongside `y`/`y_L`/`y_R`, with `get_effective_dead()` becoming a derived
view `as.integer(event_type == k_of_interest)` for a chosen cause.

## Design Decisions To Make (TODO-1 inputs)

1. **Storage shape.** Recommended: `event_type` integer column on
   `Design`, defaulting to `1` for every exact event and `0` for censored,
   so all existing single-cause survival code is unchanged (`dead =
   as.integer(event_type > 0)`). `add_one_subject_response(t, y, y_L,
   y_R, event_type = NULL)` and `add_all_subject_responses(..., event_types
   = NULL)` get one optional argument. Factor labels (`c("relapse",
   "death")`) map to integer codes with the same bookkeeping pattern as
   `ordinal_levels`.
2. **Cause of interest.** Recommended: a constructor argument on each
   competing-risks inference class, `cause = 1L` (or a label), not a
   design-level setting — the same design can be analysed for each cause.
3. **Interaction with interval censoring.** Competing risks with
   interval-censored times is a genuinely hard, thin literature (Hudgens et
   al. 2001; `icenReg` does not do it). Recommended: v1 supports
   competing risks for **exact/right-censored** times only; a class with
   `event_type` present and left/interval bounds should error clearly, via
   the same `supports_interval_or_left_censored_data()` gate that already
   exists. Note this is the *opposite* scope choice from the survival
   quantile-regression plan (which took general censoring from day one) —
   deliberately, because here the estimators are standard and the
   interval-censored extension has no reference implementation.
4. **Estimand tagging.** With `set_estimand()` shipped, each class should
   declare `estimand` metadata: `"cause_specific_hazard_ratio"`,
   `"subdistribution_hazard_ratio"`, `"cif_difference"`, `"rmtl_difference"`.
5. **Sequencing with the rename.** Do the `event_type` column in the same
   sweep as `dead → uncensored`, since both rewrite every `Surv(y, dead)`
   site; doing them separately means touching 31+ call sites twice.

## Inference Classes To Add

### Wave 1 — recode wrappers over existing machinery (small)

These need only the `event_type` column and a `cause =` argument; the
estimator is an existing class applied to `dead_k = 1{event_type == k}`:

- `InferenceSurvivalCauseSpecificCoxPHRegr` — cause-specific Cox; delegates
  to `InferenceSurvivalCoxPHRegr` with the recoded indicator. Estimand:
  cause-specific log HR. All existing inference contracts (Wald, partial
  likelihood, bootstrap, randomization) carry over unchanged.
- `InferenceSurvivalCauseSpecificLogRank` — delegates to
  `InferenceSurvivalLogRank`.
- (Optional) stratified / KK variants by the same delegation.

Implementation note: rather than K new classes, a single `cause =`
argument on the *existing* Cox/log-rank/stratified-Cox classes (defaulting
to "any event", i.e. today's behaviour) is smaller and keeps the class
count down. Recommended over new class names unless the registry needs the
distinction for `InferenceSuite` discovery — decide at TODO-2.

### Wave 2 — cumulative-incidence estimands (medium)

New estimators, but standard and closed-form:

- `InferenceSurvivalCIFDiff` — Aalen-Johansen CIF for cause `k` in each
  arm, difference at horizon `tau` (mirrors `InferenceSurvivalRestrictedMeanDiff`'s
  horizon API). SE by the Aalen-Johansen variance (Marubini & Valsecchi
  1995) with bootstrap fallback, exactly as `RestrictedMeanDiff` does.
  Reference implementation for parity tests: `survival::survfit(Surv(y,
  factor(event_type)) ~ w)` (multi-state survfit) or `cmprsk::cuminc`.
- `InferenceSurvivalGrayTest` — Gray's K-sample test on the CIF; test
  statistic as the "estimate" with the same p-value-only contract shape
  the log-rank class uses (mean weighted-residual difference). Reference:
  `cmprsk::cuminc`.
- `InferenceSurvivalRMTLDiff` — restricted mean time lost to cause `k`;
  area under the CIF to `tau`; delta from the CIF machinery.

### Wave 3 — Fine-Gray subdistribution model (medium–large)

- `InferenceSurvivalFineGrayRegr` — weighted Cox partial likelihood with
  IPCW weights (Fine & Gray 1999; Geskus 2011 weighting). Two
  implementation routes:
  1. **Data expansion + existing Cox kernel**: `survival::finegray()`
     produces an expanded (start, stop, weight) dataset on which ordinary
     `coxph(..., weights)` fits the model. EDI's Cox kernel takes
     right-censored `(y, dead)` and no start/stop or weights today, so
     route 1 means extending `fast_coxph_regression_prebuilt_cpp` to
     counting-process input with case weights — a kernel change that also
     unlocks future time-varying-covariate and recurrent-event (AG) work.
  2. **`cmprsk::crr` delegation** as the non-`use_rcpp` fallback and the
     parity oracle, mirroring how Cox falls back to `survival::coxph.fit`.
  Recommended: route 2 first (fast to ship, `cmprsk` in `Suggests`), route 1
  as the `use_rcpp = TRUE` path in a later kernel spec, following the
  `quantile_regression_cpp_kernel_spec.md` pattern of shipping the R
  dependency path first with an exact-parity C++ kernel later.
  Randomization inference: refit per permutation is one `crr()` call —
  slow but valid; the bootstrap path reuses the design-backed worker
  pattern.
- KK variants (`IVWC` / `OneLik`) for Fine-Gray: defer; pair-stratified
  subdistribution models are not standard.

### Wave 4 — pseudo-value regression (optional)

- `InferenceSurvivalCIFPseudoValueRegr` — jackknife pseudo-observations of
  the CIF at `tau`, then a GLM (identity or cloglog link) with sandwich
  SE. Reuses the existing GLM/`Wald` components once pseudo-values exist.
  Rare in practice; include only if Wave 2's CIF machinery makes it nearly
  free.

## Design-Side Implications

- **All 27 design classes**: unchanged — none model the response.
- **`DesignSeqOneByOneKK21` / `KK21stepwise`**: `compute_weights()`
  (`design_seq_one_by_one_KK21.R:324-361`) fits a per-covariate AFT on
  survival responses. With competing risks the natural weight is from a
  cause-specific model on `1{event_type == k}` — a one-line recode if the
  design knows the cause of interest, which today it does not. Recommended:
  KK21 treats "any event" as the event for weighting (today's behaviour)
  and documents it; a `weight_cause =` argument is a later refinement.
- **Bootstrap/permutation replay**: `event_type` must ride along with
  `y`/`y_L`/`y_R` through `draw_bootstrap_indices()` and the
  design-backed worker state — same plumbing the interval-censoring
  rework added for `y_L`/`y_R`, so the pattern exists.

## `SimulationFramework` Implications (moderate)

- Generator: the current survival branch draws one latent time. Competing
  risks needs K latent cause-specific times (e.g. independent Weibulls
  with cause-specific `betaT_k`) with `y = min`, `event_type = argmin`,
  then censoring. A `competing_risks = list(K = 2, betaT = c(...),
  shapes = ..., scales = ...)` option on the survival generator.
- Truth: the scalar truth depends on the estimand — cause-specific log HR
  for cause `k` is known in closed form from the generator; the true CIF
  difference at `tau` is computable numerically; the true subdistribution
  HR is *not* constant under a cause-specific-Weibull generator (the
  Fine-Gray model is misspecified there), so either generate from a
  Fine-Gray-consistent model (Jeong & Fine 2006) for those runs or
  report bias against the large-sample `crr()` estimate. Flag this in
  the simulation docs; it is a known wrinkle, not an EDI problem.
- Curated default classes for survival gain the Wave 1 cause-specific Cox
  when `event_type` has >1 level.

## Testing

- **Storage**: round-trip `event_type` through `add_one_subject_response`,
  `add_all_subject_responses`, save/load, bootstrap index draws,
  `duplicate()`; default `event_type = 1` reproduces every existing
  survival golden test bit-for-bit.
- **Wave 1 parity**: cause-specific Cox/log-rank equal
  `InferenceSurvivalCoxPHRegr`/`LogRank` on a hand-recoded design (exact
  equality).
- **Wave 2 parity**: CIF and Gray's test vs `cmprsk::cuminc` and
  multi-state `survival::survfit`; RMTL vs numeric integration of the
  reference CIF.
- **Wave 3 parity**: Fine-Gray vs `cmprsk::crr` and vs
  `coxph(finegray())` at tight tolerance; randomization p-value spot-check
  by brute force at small `n`.
- **Simulation**: recover known cause-specific `betaT_k` at increasing
  `n`; CIF-difference coverage; demonstrate the KM-vs-CIF bias the Austin
  & Fine review describes (a nice vignette figure).
- **Registry**: new classes named `InferenceSurvival…` so
  `infer_inference_response_types()` picks them up; `supports_general_censoring
  = FALSE` for all competing-risks classes in v1; fixture matrix extended
  with an `event_type` axis in `public_argument_combination_constraints.R`.

## Non-Goals

- Competing risks under left/interval censoring (v1 errors clearly).
- Multi-state models beyond the competing-risks (one transition from
  "alive") structure; illness-death and general multistate need a
  transition-structure response and are deferred (inference audit 4D #27).
- Recurrent events (Andersen-Gill / LWYY) — separate family, though the
  counting-process Cox kernel extension in Wave 3 route 1 is shared
  infrastructure worth noting in whichever plan lands first.
- Cure-fraction / mixture-cure models — a different model on the same
  single-cause survival response; out of scope here (would be its own
  small plan if wanted).
- KK IVWC/OneLik Fine-Gray variants.

## Effort Summary

| Wave | Content | Effort | New dependencies |
|---|---|---|---|
| 0 | `event_type` storage + replay + rename splice | small–medium (many call sites, but mechanical; ride TODO-15c) | none |
| 1 | cause-specific Cox / log-rank via recode | small | none |
| 2 | Aalen-Johansen CIF diff, Gray's test, RMTL | medium | `cmprsk` in `Suggests` (test oracle) |
| 3 | Fine-Gray via `cmprsk::crr`; later C++ counting-process Cox kernel | medium (delegation) / large (kernel) | `cmprsk` (runtime, non-`use_rcpp` path) |
| 4 | pseudo-value CIF regression | small once Wave 2 exists | none |

## Recommendation

**Pursue Waves 0–2 in v1.1.0; Wave 3 via `cmprsk` delegation in v1.1.0 if
`cmprsk` as a `Suggests` dependency is acceptable, otherwise defer the
kernel to a later kernel spec; Wave 4 optional.** Rationale: (a) the
literature frequency is high and the mishandling rate is higher; (b) it
is univariate `y` inside an existing response type — no new type, no
vector estimand, no paradigm change; (c) Wave 1 is nearly free and Wave 2
is closed-form; (d) sequencing Wave 0 with the pending `dead →
uncensored` rename halves the plumbing cost.

## Implementation TODOs

- [ ] TODO-0: Index this plan in `release_v1_1_0.md` (survival/censored
  track, alongside TODO-7 and TODO-15c) and `_master.md` Phase 5 once
  TODO-1 is decided.
- [ ] TODO-1: **Decision — ask the user**: pursue competing risks at all;
  confirm v1 scope = exact/right-censored only; confirm `event_type`
  storage shape and `cause =` as an inference-class argument; confirm
  splicing Wave 0 with the `dead → uncensored` rename; confirm `cmprsk`
  in `Suggests`.
- [ ] TODO-2: Wave 0 — `event_type` column on `Design` (default 1 for
  exact events), `add_*_response(..., event_type)`, factor-label
  bookkeeping, `get_effective_dead(cause = NULL)`, bootstrap/permutation
  replay, save/load; golden tests prove bit-for-bit no-op for existing
  survival classes. Decide new-class vs `cause =` argument on existing
  classes.
- [ ] TODO-3: Wave 1 — cause-specific Cox / log-rank (and stratified-Cox,
  KK delegations if free); parity tests vs hand recode.
- [ ] TODO-4: Wave 2 — `InferenceSurvivalCIFDiff`, `InferenceSurvivalGrayTest`,
  `InferenceSurvivalRMTLDiff`; parity vs `cmprsk::cuminc` / multi-state
  `survfit`; estimand metadata.
- [ ] TODO-5: Wave 3a — `InferenceSurvivalFineGrayRegr` via `cmprsk::crr`
  delegation (Wald + bootstrap + randomization); parity vs
  `coxph(finegray())`.
- [ ] TODO-6: Wave 3b (later kernel spec) — extend
  `fast_coxph_regression_prebuilt_cpp` to counting-process
  (start, stop, weight) input; `use_rcpp = TRUE` Fine-Gray path; note the
  shared benefit for a future recurrent-events plan.
- [ ] TODO-7: `SimulationFramework` — competing-risks generator, per-
  estimand truth, curated default set; document the subdistribution-HR
  misspecification wrinkle.
- [ ] TODO-8: KK21 `weight_cause =` refinement (optional), vignette
  section with the KM-vs-CIF bias figure, update
  `response_types_landscape_report.md`'s survival section and the two
  literature audits to point here.
- [ ] TODO-9 (optional): Wave 4 pseudo-value CIF regression.
