# Release Scope: v1.2.0

> **Depends on:** `release_v1_1_0.md` (ships first). Like the 1.0.0 and
> 1.1.0 files, this is a release index that batches plans living in
> `../new_feature_plans/`; it is not new work of its own. (Global ordering:
> see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (user decision: split the open backlog into 1.1.0 /
1.2.0 / 2.0.0). **Rule for the split:**

- **1.x releases are improvements on the current codebase plus simple new
  additions** — corrections, diagnostics, kernels/perf, new inference or
  design classes that slot into the existing factories/registries/
  components on the existing six scalar response types, and small
  plumbing extensions.
- **1.1.0** takes the items that are small-to-medium and touch nothing
  structural; **1.2.0** takes the additive items that need *moderate*
  plumbing (a new stored column, a generalized bounds schema, a new
  timing-family sibling class, a k-strata kernel generalization) or that
  carry real estimator risk and deserve their own release cycle.
- **2.0.0 introduces genuinely new functionality with large refactorings
  or new architecture** — see `release_v2_0_0.md`.

Everything here is additive and must reproduce 1.1.0 results bit-for-bit
by default (same standing constraint as 1.1.0).

## In scope (by plan)

### Censored-response extensions of existing scalar types (`_master.md` Phase 5C)

- `censored_continuous_response.md` — Tobit kernel dispatched inside
  `InferenceContinOLS`; Tier 2 Lin/quantile(`crq`)/robust/KK variants.
  Generalizes the `y_L`/`y_R` bounds schema from `survival` to
  `continuous` — the moderate-plumbing reason this is 1.2.0 not 1.1.0.
- `censored_count_response.md` — censored Poisson/NB branches; binned
  counts. Depends on the continuous plan's schema generalization.
- `betaregscale_duplication.md` — interval-censored beta regression with
  variable dispersion; depends on `censored_continuous_response.md`'s
  censored-quantile machinery.

### Survival-model extensions

- `competing_risks_response.md` — `event_type` cause code on the existing
  `survival` response + cause-specific Cox/log-rank, Aalen-Johansen CIF
  difference, Gray's test, RMTL, Fine-Gray (via `cmprsk` delegation;
  counting-process C++ kernel later). Decision-gated (its TODO-1). **Wave 0
  coordination note:** if the `dead → uncensored` rename (1.1.0 →
  TODO-15c) ships first, add the `event_type` column in that same sweep as
  a dormant, additive field so the 31 `Surv()` call sites are rewritten
  once; the estimators (Waves 1–3) land here.
- `cure_fraction_survival_inference.md` — `InferenceSurvivalMixtureCureWeibull`
  (+ optional promotion-time variant) via the shipped `estimand` axis;
  `flexsurvcure` delegation first, native kernel second. Decision-gated;
  sequenced after competing risks.
- `interval_censored_survival_response_type_report.md → second wave` (if
  its TODO-1 said yes): NPMLE/Turnbull Cox-analogue, stratified `icenReg`
  delegation, current-status estimator.
- `survival_quantile_regression.md` — `InferenceSurvivalQuantileRegr` +
  KK IVWC/OneLik: a *custom* self-consistent EM estimator for general
  interval censoring with three recorded open risks (EM-to-Peng-Huang
  reduction unverified, heuristic sandwich variance, randomization-
  inference performance). Approved design; moved from 1.1.0 to 1.2.0 on
  2026-08-27 because it is a new estimator with validation risk, not a
  simple addition. (`count_quantile_regression.md`, by contrast, stays in
  1.1.0 — jittered `rq()` is a simple addition.)

### Semi-continuous outcomes on the existing `continuous` type

- `semi_continuous_response_type_report.md` (if its TODO-1 said yes) —
  `InferenceContinHurdleLogNormal` / `InferenceContinHurdleGamma` two-part
  likelihoods with new zero-augmented kernels; Tobit second wave rides the
  censored-continuous plan. No new response-type enum (it stays
  `continuous`), which is why it is 1.2.0 rather than 2.0.0.

### KK-family generalizations

- `full_glmm_for_weibull_frailty.md` — generalize the Weibull-frailty
  survival classes from pairs to arbitrary strata size `k` (log-normal
  frailty kernel already general; Clayton/gamma-frailty likelihood
  re-derived per Hougaard 2000), ragged bootstrap kernel,
  `allow_k_wise_groups` opt-in on `DesignFixedBinaryMatch`. 41 open TODOs;
  a real k-strata kernel generalization — 1.2.0. (Its TODO-0 records that a
  true k-way matching *design* class is a separate future plan; the
  theoretical audit's Cytrynbaum k-tuple item is that plan's home when
  written.)

### New design timing family

- `design_seq_many_by_many.md` — `DesignSeqManyByMany` abstract sibling of
  `DesignSeqOneByOne` plus `Bernoulli` / `CRD` / `Blocking` /
  `Rerandomization` (Zhou et al. 2018) / `Atkinson`. Approved 2026-08-17
  for 1.1.0; **moved to 1.2.0 on 2026-08-27** — a new timing family with
  its own ingestion path (`add_many_subjects*`, `assign_wts`,
  block-by-block replay) is more than a simple addition, though it needs
  no refactor of existing classes (hence not 2.0.0). Its TODO-1 decision
  batch can still be taken in the 1.1.0 Phase 0 sitting.
- `../new_research_ideas/design_seq_many_by_many_greedy_pair_switch.md`
  follows if and when the family and the greedy merge (1.1.0 TODO-11)
  both land.

### Unowned backlog from the 2026-08-26/27 audits — suggested 1.2.0 placement

These have **no owning plan yet** (per the `_master.md` rule they cannot
be indexed until one exists); listed so the split is complete. Each needs
a scoping report or a TODO in an existing plan before it enters this file
as a real item. Medium-effort, two-arm/single-assignment, existing types:

- Design-side `treatment_received` field + `InferenceAllCACEWald` / 2SLS
  (design audit #3, inference audit #3).
- Treatment × covariate moderation estimand on regression classes
  (inference audit #4).
- Cluster-level covariate-balancing designs — `cluster_col =` on
  `BinaryMatch` / `OptimalBlocks` / `Rerandomization` / `Greedy` /
  `GreedyDOptimal` / `Optimal` (design audit #2).
- Unequal allocation in matching / greedy / minimization designs (design
  audit #1) — partly covered by 1.1.0 TODO-11's general-`prob_T` rederivation.
- Randomized saturation two-stage design (design audit #4).
- Gram-Schmidt Walk design and the online balancing walk (theoretical
  audit #1, #22); ARM/PSR sequential coin (#21); Neyman / per-stratum
  allocation helper (#38); Cytrynbaum k-tuple matching (#3); I-optimal
  CATE criterion (#41).
- Missing-outcome handling: Lee bounds, MI with Rubin's-rules pooling
  (inference audit #16).

## Implementation TODOs (dependency order)

Ticked in owning plans; this list is the index.

- [ ] TODO-1: **Phase 0 decisions carried from 1.1.0** that gate items
  here: `semi_continuous_… → TODO-1`, `interval_censored_… → TODO-1`
  (second wave), `competing_risks_response.md → TODO-1`,
  `cure_fraction_survival_inference.md → TODO-1`,
  `design_seq_many_by_many.md → TODO-1`. Take them in the 1.1.0 Phase 0
  sitting if convenient; record answers in the owning plans.
- [ ] TODO-2: **Censored-response track** in the order
  `censored_continuous_response.md → TODO-1..12` (schema generalization
  first), then `censored_count_response.md → TODO-1..14`, then
  `betaregscale_duplication.md → TODO-2..12`.
- [ ] TODO-3: **Competing risks** `competing_risks_response.md →
  TODO-2..9` (Wave 0 coordinated with the 1.1.0 rename per the note above).
- [ ] TODO-4: **Cure fraction** `cure_fraction_survival_inference.md →
  TODO-2..6`, after TODO-3.
- [ ] TODO-5: **Interval-censored second wave** (if decided yes) — new
  implementation plan per `release_v1_1_0.md`'s former TODO-12 note (do not
  reopen the finished plan).
- [ ] TODO-6: **Survival quantile regression** — write its implementation
  plan (writing-plans step; the design is approved), then execute; the
  three open risks must each be closed by a test before the classes are
  exported.
- [ ] TODO-7: **Semi-continuous** (if decided yes) `semi_continuous_… →
  TODO-2..6`.
- [ ] TODO-8: **Weibull-frailty k-strata** `full_glmm_for_weibull_frailty.md
  → TODO-0..40` (its TODO-0 decision first).
- [ ] TODO-9: **Many-by-many design family** `design_seq_many_by_many.md →
  TODO-2..10` (TODO-2's shared-ingestion extraction from the frozen
  `DesignSeqOneByOne$add_one_subject()` path is behavior-preserving under
  golden test).
- [ ] TODO-10: **Scope the unowned 1.2.0 backlog** above — one scoping
  report per item (or a TODO in an existing plan), citing the audit item
  number; only then promote into this index.
- [ ] TODO-11: **Release mechanics** per `release.md`.

## Standing constraints

Same as `release_v1_1_0.md`: additive only; defaults reproduce the prior
release bit-for-bit; every new class through `define_inference_class()` /
`define_design_class()`; every new C++ kernel follows
`sexp_removal_rcppeigen_conversion_spec.md` conventions; targeted compile
only, never a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
`load_all(compile = TRUE)`.
