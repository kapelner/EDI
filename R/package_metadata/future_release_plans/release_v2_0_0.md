# Release Scope: v2.0.0

> **Depends on:** `release_v1_4_0.md` (the last 1.x release; ships
> first). Release index over plans in `../new_feature_plans/`; not new work
> of its own. (Global ordering: see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (user decision: thematic split of the open backlog into
1.1.0 inference quality / 1.2.0 performance & engines / 1.3.0 design
theory / 1.4.0 response & data extensions / 2.0.0 architecture). **2.0.0
is the release for genuinely new functionality
that requires large refactorings or new architecture** — anything that
changes a core contract every class depends on (the binary `w`, the
scalar-`y`-per-subject response shape, the single-look inference
contract, the CPU-only kernel backend), or that adds a whole new response
shape. Because these change public contracts frozen at 1.0.0, 2.0.0 is
also where the deferred **breaking** changes land (public-class deletions
that 1.1.0 only soft-deprecates).

## In scope (by plan)

### Multi-arm (K > 2) designs and inference — the binary-`w` contract change

- `multi_arm_designs.md → TODO-1b..5` — integer `w` storage, `K` /
  `prob_T_vec` on `Design`, K-arm C++ kernels for every fixed and
  sequential design, lifting `DesignFixedFactorial`'s 2-cell stopgap,
  `arm_treated` / `arm_control` on `Inference$initialize()`,
  `MultiArmInference` orchestration (Bonferroni/Holm/Dunnett), demand-gated
  native K-arm inference on a parallel root, and the open research
  question of K-arm KK matching. Every class touches `w`; §7 of the plan
  notes that randomization-test validity for a two-arm contrast inside a
  K-arm mechanism is new statistical work. (TODO-1a and TODO-6 already
  shipped in 1.0.0.)
- Rides on it: factorial contrasts as named estimands (inference audit
  #13); 2^K factorial and multi-arm rerandomization (theoretical audit
  #47); K-arm Atkinson / ARM / online balancing walk / bandits (#48);
  rank-based k-sample tests (inference audit 4C #24).

### New response shapes — the scalar-`y` contract change

Each needs its own `Design$y` storage project, generator semantics in
`SimulationFramework`, and an estimand decision; the 1.1.0 Phase 0
decision batch still records the yes/no for each.

- `longitudinal_repeated_measures_response_type_report.md` — new
  `longitudinal` type (ragged `(subject, wave, y)`), `InferenceLongitudinalGEE`
  / `GLMM`. **Also the substrate for the entire deferred multi-period
  design tier** — crossover, within-subject counterbalancing,
  stepped-wedge, switchback, SMART, MRT, N-of-1/SCED (design audit Part 4D)
  — which together dominate HCI, special education, digital health, PK
  trials and marketplace experimentation. The plan's deferred
  treatment×time / unstructured-covariance (MMRM) items should be promoted
  to its first wave (inference audit #7).
- `multivariate_response_type_report.md` — K endpoints per subject;
  `InferenceMultiEndpointComposite` (Holm; Fisher/O'Brien global test),
  extended with Romano-Wolf, Anderson q-values and summary indices
  (inference audit #8); hierarchical win ratio, cost-effectiveness ICER,
  and the nominal joint-K-vector test all ride here.
- `compositional_response_type_report.md` — `compositional` (n×K simplex),
  ILR → OLS wrapper, ILR-Hotelling/permutation.
- `rank_choice_response_type_report.md` — discrete choice on nominal
  machinery + conditional-logit kernel; new `ranking` shape (Plackett-Luce
  / Mallows). Conjoint / factorial-vignette / list-experiment designs
  (design audit #31, inference audit #23) are this paradigm.
- `nominal_response_type_report.md` — rewritten 2026-08-27; its recorded
  recommendation for its own TODO-1 is **no / defer indefinitely** (18 of
  20 published nominal-outcome RCTs use one-vs-rest binaries EDI already
  supports; the joint test belongs to the multivariate plan). Listed here
  only so the decision has a home; if "no", it moves to
  `../finished_features/` as a closed scoping report with the
  one-vs-rest vignette section as its sole deliverable (1.1.0-sized).
- `response_types_landscape_report.md → TODO-1/2/9` — landscape refresh
  after the above ship; recurrent events (Andersen-Gill / LWYY — needs a
  counting-process response; inference audit 4D #10) and functional /
  network outcomes remain unplanned even here.

### Sequential inference — the single-look contract change

- `sequential_inference.md` — `SequentialMonitor` (alpha-spending
  O'Brien-Fleming/Pocock, Bayesian monitoring via the Bayesian bootstrap,
  anytime-valid confidence sequences, sequential randomization tests) and
  the design-side analysis ledger (`record_analysis_event()`, `interim =
  TRUE` bypass of `assert_all_subjects_arrived()`). Every `Inference*`
  class today assumes the trial is over; interim looks with error-rate
  guarantees across looks are a new inference paradigm. Its 1.1.0 scoping
  (former TODO-13) still runs; implementation is 2.0.0. Group-sequential
  designs are "very common" in medicine and tech (design audit #18) — this
  is the highest-value 2.0.0 item after multi-arm.
- Rides on it: two-arm **response-adaptive randomization** (Thompson /
  DBCD / ERADE / CARA; design audit #5, theoretical audit 2D), which needs
  the same response-dependent replay and a new inference contract
  (adaptively-weighted AIPW / batched OLS).

### Cluster-level model-based inference — generalizing the KK-pair machinery

- `cluster_robust_inference_glmm_gee.md` (`_master.md` Phase 5Y) — a
  `ClusterRobust` SE component (CR0–CR3, Satterthwaite / Bell-McCaffrey
  df, wild cluster bootstrap) plus random-cluster-intercept GLMM and GEE
  classes for arbitrary clusters. Requires generalizing the `KKGEE` /
  `KKGLMM` components away from pair structure — the longitudinal plan's
  Stage 1 does exactly that extraction, so this lands with it. The
  design-side half (`cluster_level_covariate_balancing_designs.md`) is
  1.3.0. Medicine: GLMM 52% / GEE 16% of cluster trials; education:
  near-universal.

### Mediation — a post-treatment variable on the design

- `mediation_analysis.md` (`_master.md` Phase 5Z) — mediator column on
  `Design`, `InferenceContinMediationProduct` (product-of-coefficients
  with bootstrap / Sobel; `"indirect"` / `"direct"` / `"total"`
  estimands), later counterfactual NDE/NIE with sensitivity `ρ` and
  moderated mediation. A third stored per-subject variable class (after
  `y` and the 1.4.0 `treatment_received`) — largest gap for psychology /
  marketing users.

### Two-arm response-adaptive randomization

- `response_adaptive_randomization.md` (`_master.md` Phase 5AA`) — DBCD /
  ERADE, tempered Thompson / exploration sampling, urn RAR, CARA second
  wave, with the replay-contract extension (replay may see responses) and
  an `AdaptiveWeighting` inference component (AW-AIPW, batched OLS).
  Rides the sequential-inference implementation.

### New compute backends

- `gpu_optimizations.md` (if its TODO-1 said yes) — GPU port of the
  optimal-design search and the batched kernels; a backend/dispatch
  architecture (`TODO-7`) that `quantum_upgrade.md` reuses.
- `quantum_upgrade.md` (if its TODO-1 said (a) or full) — QUBO/annealer
  solver hook on `DesignFixedOptimal` / `OptimalBlocks`, backend registry
  with `qubo_backend = "none"` default, vendored `minorminer busclique`,
  hardware detection. Its lightest option — a vignette plus a
  `qubo_sampler` hook with no backend — is 1.x-sized and may be pulled
  forward if decided; the backend architecture is 2.0.0.
- `../new_research_ideas/quantum_greedy_design.md` (`DesignFixedGibbs`)
  — gated on simulations; classical arm could ship earlier.

### Deferred breaking changes

- `design_fixed_greedy_pair_switch_merge.md` — **deletion** of the public
  `DesignFixedGreedy` and `DesignFixedGreedyDOptimal` classes. Per the
  1.1.0 note, 1.1.0 ships `DesignFixedGreedyPairSwitch` with the
  general-`prob_T` rederivation and soft-deprecates the two old names
  (warnings, aliases); the hard deletion is a 2.0.0 item.
- Any other public-contract break surfaced by the multi-arm `w` storage
  change or the response-shape work lands here, never in 1.x.

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Decision batch** for every gated 2.0.0 track (multi-arm
  research question on K-arm KK; each response-shape TODO-1; GPU/quantum
  TODO-1s; nominal TODO-1 with its recorded "no" recommendation). May be
  taken in the 1.1.0 Phase 0 sitting; recorded in owning plans.
- [ ] TODO-2: **Audit-commissioned 2.0.0 plans** (owning plans written
  2026-08-27; each TODO-1 is a decision):
  - [ ] TODO-2a: `cluster_robust_inference_glmm_gee.md → TODO-1..5` —
    after TODO-4's longitudinal Stage 1 extraction.
  - [ ] TODO-2b: `mediation_analysis.md → TODO-1..5` — after 1.4.0's
    `treatment_received` plumbing pattern.
  - [ ] TODO-2c: `response_adaptive_randomization.md → TODO-1..5` — after
    TODO-5 (sequential inference); TODO-4 there is the replay-contract
    change.
- [ ] TODO-3: **Multi-arm track** `multi_arm_designs.md → TODO-1b, 1c, 2,
  3, 4, 5` in that order.
- [ ] TODO-4: **Longitudinal response type** (first, because it is the
  substrate for cluster GLMM/GEE and the multi-period design tier), then
  **multivariate**, then **compositional**, then **rank/choice**; nominal
  only if its TODO-1 overturns the recorded recommendation.
- [ ] TODO-5: **Sequential inference** implementation from the 1.1.0
  scoping output; then two-arm RAR on top.
- [ ] TODO-6: **Compute backends** — GPU dispatch architecture first
  (`gpu_optimizations.md → TODO-7`), quantum hook second.
- [ ] TODO-7: **Breaking changes** — greedy-class deletion; any contract
  breaks accumulated from TODO-3/4, each with a documented deprecation
  path from 1.x.
- [ ] TODO-8: **Landscape refresh** `response_types_landscape_report.md`
  after TODO-4.
- [ ] TODO-9: **Release mechanics** per `release.md`, including a
  migration guide for every 1.x → 2.0.0 break.

## Standing constraints

`define_inference_class()` / `define_design_class()` for every class;
kernel conventions per `sexp_removal_rcppeigen_conversion_spec.md`;
targeted compile only. Unlike 1.x, bit-for-bit default reproduction of the
prior release is **not** required where a contract deliberately changes —
but every such change must ship with a deprecation shim in the last 1.x
release and a migration note.
