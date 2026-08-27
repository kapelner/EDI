# Release Scope: v1.3.0 — Design Extensions from Practice

> **Depends on:** `release_v1_2_0.md` (the merged greedy engine with
> general `prob_T`). Release index over plans in `../new_feature_plans/`.
> (Global ordering: see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (thematic 1.x split); **amended the same day (user
decision): the theoretical-design backlog — every plan commissioned from
`missing_theoretical_design_classes_literature_audit.md` — moves to
`release_v2_0_0.md`.** What remains here are the design extensions
commissioned from the *practice* audit
(`missing_design_classes_literature_audit.md`) plus the already-approved
many-by-many family: all two-arm, one assignment per subject, on the
existing design factory.

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
- [ ] TODO-5: **Release mechanics** per `release.md`.

## Standing constraints

As 1.1.0/1.2.0: additive, bit-for-bit defaults (every new `cluster_col` /
`prob_T` argument defaults to today's behaviour), `define_design_class()`
for every class, kernel conventions, targeted compile only.
