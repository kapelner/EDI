# Release Scope: v1.1.0

> **Depends on:** `release_v1_0_0.md` (the contract freeze ships first; every
> plan below is additive on top of the frozen substrate), plus the in-scope
> plans listed below — like the 1.0.0 file, this document is the release
> index that batches them, not new work of its own. (Global ordering: see
> `_master.md`; this file draws the next release line across it.)

Written 2026-08-17, user decision. **v1.1.0 is defined as "everything
currently open in `new_feature_plans/` that is not inside the v1.0.0 release
line"** — the entire additive backlog in one release, superseding
`release_v1_0_0.md → TODO-5`'s earlier guess that 1.1.0 would be only a small
first wave (estimate/estimand + the Easy-tier bias corrections).

## Scope rule

A plan (or plan fragment) is in scope for v1.1.0 if and only if it lives in
`new_feature_plans/` and is **not** named in `release_v1_0_0.md`'s "In scope"
list or its amendments. Concretely, the exclusions are:

- `fix_inference_hierarchy.md` (all remaining Phase 1D work — 1.0.0 item 1),
- `extending-edi-r6.md` (1.0.0 item 6),
- `fix_documentation.md` (1.0.0 item 7 — including the Python docstring
  TODOs, which ride the same-commit-family `edi_kernels` 1.0.0 wheel, and
  the folded-in `marginal_estimand_report.md → TODO-2` roxygen sharpening),
- `marginal_estimand_report.md` in full (1.0.0 item 14, amended 2026-08-18
  — the package-wide `estimand` concept `inference_suite_inspect.md`'s
  Combined Evidence Metric default weighting policy needs; its TODO-1
  decided **yes** 2026-08-18). `expanded_estimate_report.md` was
  initially excluded alongside it, then **moved back into v1.1.0 scope
  the same day** (user decision) — see "In scope" and `TODO-1`/`TODO-5`
  below.
- `fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO` (1.0.0
  item 9),
- the already-closed fragments: `multi_arm_designs.md → TODO-6`,
  `optimizer_diagnostics_report.md → TODO-4`,
  `bootstrap_calibrated_lr_report.md → TODO-1`,
- everything already in `../finished_features/`.

Decision-gated tracks below (Firth, GPU, response types, etc.) are in scope
**conditional on their Phase 0 decision being "yes"** — a "no" removes that
track from this release without replacement; it does not block the release.

## In scope (by plan)

The corrections family (**minus `marginal_estimand_report.md`, pulled into
v1.0.0 — amended 2026-08-18, user decision; see `release_v1_0_0.md`'s item
14**): `expanded_estimate_report.md` (`estimate_type` — moved back here
2026-08-18, still an open Phase 0 decision, see `TODO-1` step 1 below),
`bias_correction_cox_snell.md`, `cordeiro_mccullagh_bias_correction_report.md`,
`score_correction_cordeiro_ferrari.md`, `gradient_correction_lemonte.md`,
`likrat_correction_bartlett.md`, `firth_penalties_report.md`,
`l1_l2_penalties_all_likelihood_paths_report.md`,
`median_bias_correction_likelihood_paths_report.md`,
`modified_profile_likelihood_report.md`, `bootstrap_calibrated_lr_report.md`
(its remaining Difficult-tier work).

The diagnostics family: `optimizer_diagnostics_report.md` (TODO-1, 2, 3, 5),
`public_diagnostics_api_spec.md`, `prw_subsampling_implementation_spec.md`
(its remaining TODO-14..17 splice and TODO-20).

The kernel/perf family: `robust_regression_perf_optimization_spec.md`,
`quantile_regression_cpp_kernel_spec.md`, `ordinal_gee_cpp_kernel_spec.md`,
`cold_starts.md`, `local_machine_optimization.md`, `gpu_optimizations.md`
(decision-gated).

The response-type family: `nominal_response_type_report.md`,
`rank_choice_response_type_report.md`,
`semi_continuous_response_type_report.md`,
`multivariate_response_type_report.md`,
`compositional_response_type_report.md`,
`longitudinal_repeated_measures_response_type_report.md`,
`censored_continuous_response.md`, `censored_count_response.md`,
`betaregscale_duplication.md`,
`interval_censored_survival_response_type_report.md` (second wave,
decision-gated), `response_types_landscape_report.md` (refresh).

The KK one-stage-estimation family (added 2026-08-18): `kk_beta_regression_one_lik_derivation.md`
— a genuine Beta-family (not quasi-binomial) one-stage `OneLik` joint
likelihood for proportion responses under KK designs, closing one of the
two remaining gaps named in `../new_research_ideas/KK_followup_research_plan.md`.
Additive, no decision gate; may run in parallel with the response-type
family above once TODO-1's KK-migration dependency (see the plan's own
`Depends on` header) is satisfied.

Designs and orchestration: `multi_arm_designs.md` (TODO-1..5; TODO-6 already
shipped in 1.0.0), `design_fixed_greedy_pair_switch_merge.md`,
`design_seq_many_by_many.md` (added 2026-08-17, user decision — the new
sequential many-by-many design family: `DesignSeqManyByMany` abstract plus
Bernoulli/CRD/Blocking/Rerandomization/Atkinson concrete classes),
`sequential_inference.md` (research scoping — may produce a decision to
defer implementation to 1.2; the scoping itself is in scope).

## Implementation TODOs (dependency order)

Work top to bottom. TODO-3 and TODO-4 may run in parallel with each other
once TODO-1 is recorded; everything from TODO-5 on assumes v1.0.0 has shipped
(shallow hierarchy, frozen kernels). Per the standing constraint, TODOs are
ticked in their **owning plans**; this list is the release index.

- [ ] TODO-1: **Phase 0 decision batch** (ask the user, no code — one
  sitting, in this order because decisions cascade; this is `_master.md`
  Phase 0 verbatim, minus `marginal_estimand_report.md → TODO-1`, which
  moved to v1.0.0 and was decided **yes** there (2026-08-18); plus
  `expanded_estimate_report.md → TODO-1`, moved back here the same day —
  when decided, check which `estimand` values
  `marginal_estimand_report.md → TODO-3` already landed on so neither
  enum absorbs the other's):
  1. `expanded_estimate_report.md → TODO-1` (`estimate_type` design —
     blocks the API shape of steps 3 and 5 below),
  2. `firth_penalties_report.md → TODO-1` +
     `l1_l2_penalties_all_likelihood_paths_report.md → TODO-1` (joint
     penalized-fitting inference semantics),
  3. `median_bias_correction_likelihood_paths_report.md → TODO-1` (after
     Firth),
  4. `bias_correction_cox_snell.md → TODO-1` +
     `cordeiro_mccullagh_bias_correction_report.md → TODO-1` (one project),
  5. `modified_profile_likelihood_report.md → TODO-1`,
  6. `likrat_correction_bartlett.md → TODO-1` (incl. ordering vs.
     score/gradient corrections),
  7. `bootstrap_calibrated_lr_report.md → TODO-2` (Difficult tier yes/no),
  8. the response-type decisions in one pass: `nominal_… → TODO-1`,
     `rank_choice_… → TODO-1`, `semi_continuous_… → TODO-1`,
     `multivariate_… → TODO-1`, `compositional_… → TODO-1`,
     `longitudinal_repeated_measures_… → TODO-1`,
  9. `gpu_optimizations.md → TODO-1` and `→ TODO-7` (backend/build story),
  10. `interval_censored_survival_response_type_report.md → TODO-1`
      (second-wave semiparametric yes/no),
  11. `local_machine_optimization.md → TODO-1` remaining parts (a, b, c, e —
      part (d) was decided 2026-08-17: tuned core count is recorded-only).
- [ ] TODO-2: `local_machine_optimization.md → TODO-2` — the warm-start
  dispatcher refactor (lift the hardcoded sample-size-conditioned layer of
  `edi_warm_start_dispatch_policy()` into the overridable config table).
  Standalone and decision-independent; explicitly allowed to land in a 1.0.x
  patch ahead of this release. Everything in TODO-10 below builds on it.
- [ ] TODO-3: **Diagnostics chain** (`_master.md` Phase 2, strictly ordered):
  `optimizer_diagnostics_report.md → TODO-1` (free diagnostics), `→ TODO-2`
  (hardening), `→ TODO-3` (`SolverDiagnostics` component — **prerequisite
  for Firth in TODO-5**), `→ TODO-5` (Phase 4, lower priority); then
  `public_diagnostics_api_spec.md → TODO-1..4`, `→ TODO-5..8`, `→ TODO-9..12`,
  `→ TODO-13..16`, `→ TODO-17..18` (which also closes
  `prw_subsampling_implementation_spec.md → TODO-14..17` **[spliced]**),
  plus `prw_subsampling_implementation_spec.md → TODO-20` alongside.
- [ ] TODO-4: **Kernel/perf lane** (`_master.md` Phase 4 remainder; parallel
  with TODO-3): `robust_regression_perf_optimization_spec.md → TODO-1..4`
  (profile-first), `quantile_regression_cpp_kernel_spec.md → its TODO list`,
  `ordinal_gee_cpp_kernel_spec.md → TODO-1..2` then `→ TODO-3..5` (the KK
  wirings in both wait on 1.0.0's Phase 1D.2 KK migration landing),
  `cold_starts.md → TODO-1..14` (documentation/audit — also a prerequisite
  for TODO-10, which benchmarks the axes this audit documents).
- [ ] TODO-5: **Corrections track** (`_master.md` Phase 5A order, minus
  `marginal_estimand_report.md`, moved to v1.0.0, amended 2026-08-18;
  `expanded_estimate_report.md` moved back here the same day; each
  decision-gated item gated by its TODO-1 decision):
  1. `expanded_estimate_report.md → TODO-2..5` (`estimate_type` first —
     its values are consumed by steps 3 and 5),
  2. `bias_correction_cox_snell.md → TODO-2..5` +
     `cordeiro_mccullagh_bias_correction_report.md → TODO-2..4` (one
     project: shared `X'WX` helper, Easy-tier GLMs first),
  3. the higher-order test-correction batch in order:
     `score_correction_cordeiro_ferrari.md → Phase 0..5` (anchor), then
     `gradient_correction_lemonte.md → Phase 0..4`, then
     `likrat_correction_bartlett.md → exact-rollout TODO-2` (shared
     cumulant machinery built exactly once),
  4. `firth_penalties_report.md → TODO-2..5` (requires TODO-3's
     `SolverDiagnostics`) + `l1_l2_penalties_all_likelihood_paths_report.md
     → TODO-3` (joint semantics recorded once in both plans),
  5. `l1_l2_penalties_all_likelihood_paths_report.md → TODO-2` then
     `→ TODO-4`,
  6. `median_bias_correction_likelihood_paths_report.md → TODO-3..4` (only
     after Firth ships),
  7. `modified_profile_likelihood_report.md → TODO-2..4`,
  8. `bootstrap_calibrated_lr_report.md → Difficult-tier work` (if TODO-1.7
     said yes).
- [ ] TODO-6: **Response-type track** (`_master.md` Phase 5B order):
  `nominal_… → TODO-2 (Stage 1)` + `rank_choice_… → TODO-2 (Stage 1)`
  (spliced: admit `nominal` once); `nominal_… → TODO-3..4`;
  `rank_choice_… → TODO-3` (and `→ TODO-4` under its own sub-decision);
  `semi_continuous_… → TODO-2`, `→ TODO-6`, `→ TODO-3..5`;
  `multivariate_… → TODO-2..4`; `compositional_… → TODO-5` then
  `→ TODO-2..4` (vector storage last among scalar-adjacent types);
  `longitudinal_repeated_measures_… → TODO-5` then `→ TODO-2..4` (Stage 1
  extracts the clustered-fit core from `KKGEE`, so it follows 1.0.0's
  Phase 1D.2).
- [ ] TODO-7: **Censored-response track** (`_master.md` Phase 5C order):
  `censored_continuous_response.md → TODO-1..` (its TODO-1 generalizes the
  Design-layer bounds schema; everything downstream keys off it), then
  `censored_count_response.md → TODO-1..`, then
  `betaregscale_duplication.md → TODO-1..` (reuses the censored-quantile
  machinery).
- [ ] TODO-8: **Multi-arm track** (`_master.md` Phase 5D):
  `multi_arm_designs.md → TODO-1` (design side; the 1.0.0 hierarchy work
  supplies the capability metadata), `→ TODO-2`, `→ TODO-3`, `→ TODO-4`
  (coordinate with TODO-6's multivariate orchestration layer — same shape),
  `→ TODO-5` (demand-gated).
- [ ] TODO-9: **GPU track** (if TODO-1.9 said yes; `_master.md` Phase 5E):
  `gpu_optimizations.md → TODO-7` (backend/build design) then `→ TODO-2..5`,
  each merge gated by `→ TODO-6`'s benchmark matrix.
- [ ] TODO-10: **Local machine optimization**:
  `local_machine_optimization.md → TODO-3..12` (harness, per-axis tuners,
  persistence, safety blocklist, contention guard, correctness gate,
  `.onLoad()` import, tests, docs). After TODO-2 (its own prerequisite) and
  after `cold_starts.md`'s audit in TODO-4; benefits from landing late in
  the release so the tuner benchmarks the release-candidate kernels, not
  mid-release ones.
- [ ] TODO-11: **Greedy-design merge**:
  `design_fixed_greedy_pair_switch_merge.md → TODO-1..10` — deletes
  `DesignFixedGreedy`/`DesignFixedGreedyDOptimal`, replacing both with
  `DesignFixedGreedyPairSwitch`. Sequenced here per its plan (after the
  1.0.0 design-hierarchy shared-engine work and `design_fixed_optimal.md`,
  both already shipped). **Note:** this deletes two public 1.0.0 classes —
  a breaking change under the 1.0.0 freeze. Before implementation, record
  the deprecation story (soft-deprecate with warnings in 1.1.0 and delete
  in 2.0.0, vs. the plan's current delete-outright shape); the explicit
  user instruction (2026-08-16) made it post-1.0.0 but did not settle the
  deprecation mechanics.
- [ ] TODO-12: **Interval-censored second wave** (if TODO-1.10 said yes):
  the NPMLE/Turnbull + stratified-Cox icenReg delegation work per
  `interval_censored_survival_response_type_report.md`, tracked as new
  TODOs in a reopened/new owning plan (the original
  `interval_censored_survival_response.md` is closed in
  `../finished_features/` — do not reopen it; open a fresh implementation
  plan).
- [ ] TODO-13: **Sequential inference scoping**:
  `sequential_inference.md` — run the scoping against the now-shipped
  1.0.0 public accessors; output is either a set of implementation TODOs
  (then decide 1.1.0 vs. 1.2) or an explicit defer note in that plan.
- [ ] TODO-14: **Landscape refresh**: `response_types_landscape_report.md →
  remaining open TODOs` — refresh after the TODO-6/7 tracks ship, so the
  landscape describes the release, not the plan.
- [ ] TODO-15b: **KK one-stage Beta-regression estimator** (added
  2026-08-18): `kk_beta_regression_one_lik_derivation.md → TODO-1..10` —
  TODO-1 (prototype validation) first; TODO-2/TODO-3 (glmmTMB-reuse cheap
  path + its golden tests) ship before TODO-4/TODO-5 (the from-scratch
  Gauss-Hermite backend and its `OneLik` class), mirroring
  `InferenceContinKKGLMM`'s own `use_rcpp` history. Additive and
  independent of every other track in this file; may run in parallel with
  TODO-6's response-type track any time after its own KK-migration
  dependency is met (see the plan's `Depends on` header).
- [ ] TODO-15: **Sequential many-by-many design family**:
  `design_seq_many_by_many.md → TODO-1..10` — its TODO-1 decision batch
  (Atkinson rule, bootstrap shape, threshold schedule) can join this file's
  TODO-1 sitting; the implementation is additive and independent of every
  other track (it needs only the 1.0.0 shallow design hierarchy), so it may
  run in parallel with TODO-5..8 any time after v1.0.0 ships. Note its
  TODO-2 extracts shared ingestion logic from the frozen
  `DesignSeqOneByOne$add_one_subject()` path — behavior-preserving under
  golden test, per the additive constraint below.
- [ ] TODO-16: **Release mechanics** (owned by this file): CHANGELOG 1.1.0
  entry written when the batch closes (dated at submission, house
  convention); version bump; re-run the `release_v1_0_0.md` Release Gate
  checklist's CRAN-facing items on the 1.1.0 candidate (win-builder/
  mac-builder, check profile, submission artifacts); `edi_kernels` 1.1.0
  wheel from the same commit family. Tagging, pushing, and submitting
  (CRAN or PyPI) each remain a **separate explicit go-ahead** — nothing in
  this plan authorizes them. On acceptance, move the closed in-scope plans
  to `../finished_features/`.

## Standing constraints

All of `_master.md`'s standing constraints apply unchanged (update
`extending-edi-r6.md` on any extension-contract change; new kernels follow
the SEXP/RcppEigen conventions including unity-build group membership; new
classes go through `define_inference_class()`/`define_design_class()`; tick
TODOs in owning plans). Additionally, everything in this release must be
**additive**: default behavior with no new switches set must reproduce
1.0.0 results bit-for-bit, except where a plan explicitly documents a
default change (currently only TODO-11's class deletion, pending its
deprecation decision).
