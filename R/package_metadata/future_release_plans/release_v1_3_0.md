# Release Scope: v1.3.0 — Design Theory: Classical Completions, Balance Criteria, and Modern Balancing Designs

> **Depends on:** `release_v1_2_0.md` (the merged greedy engine with
> general `prob_T`). Release index over plans in `../new_feature_plans/`.
> (Global ordering: see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (thematic 1.x split). **Theme.** Design classes only:
finish the classical sequential toolbox, make EDI's rerandomization /
optimal-design engines accept the full family of published criteria and
constraints, add the modern balancing designs the methodological
literature benchmarks against (Gram-Schmidt Walk, online balancing walk,
ARM/PSR), extend covariate balancing to cluster level, lift the `prob_T =
0.5` restriction everywhere, and ship the many-by-many batch family. All
two-arm, one assignment per subject, on the existing design factory.

## In scope (by plan)

### Classical completions
- `sequential_design_classical_completions.md` — tolerance rules (big
  stick, Chen, Berger maximal, block urn, Ehrenfest, ABCD), Smith's coin,
  Hu & Hu stratum weights on Pocock-Simon, allocation-ratio-preserving
  coins, `DesignFixedPermutedBlocks`, optional continuous-covariate
  minimization.

### Criteria, constraints, samplers, validity diagnostics
- `rerandomization_criterion_variants.md` — generalized quadratic-form
  `w'Aw` (Mahalanobis / ridge / PCA / Bayesian / kernel / energy / user),
  tiers, p-value acceptance, min–max |t| with retained-set size `K`,
  pair-switching and MCMC samplers, Grundy-Healy concurrence diagnostic,
  `DesignFixedHadamard`, inference-side LDR CI / Li-Ding variance /
  studentized-FRT checks.
- `optimal_design_objective_extensions.md` — kernel-MMD objective,
  per-unit propensity / entropy-floor constraints, `interest = "cate"`
  I-optimality, pilot-index pairing + Bai-Romano-Shaikh variance, matched
  k-tuples, energy objective, documentation cross-references.

### Modern balancing designs
- `gram_schmidt_walk_and_online_balancing.md` — `DesignFixedGramSchmidtWalk`,
  `DesignSeqOneByOneBalancingWalk`, `DesignSeqOneByOneARM` / `PSR`, plus
  the two simulation studies (GSW vs KAK/harmonized; ARM vs KK14).

### Cluster-level and allocation-ratio generalizations
- `cluster_level_covariate_balancing_designs.md` — `cluster_col =` on
  every fixed balancing design (constrained cluster randomization, pair-
  matched clusters, matched cluster quadruplets), `DesignFixedClusterSaturation`,
  graph-cluster documentation.
- `unequal_allocation_matching_greedy_minimization.md` — `prob_T ≠ 0.5`
  on matched / greedy designs (k-tuples or reservoir), `target_ratio` +
  ARP on sequential coins, `neyman_prob_T()` helper, per-stratum `prob_T`.

### New timing family
- `design_seq_many_by_many.md` — `DesignSeqManyByMany` + `Bernoulli` /
  `CRD` / `Blocking` / `Rerandomization` (Zhou et al. 2018) / `Atkinson`;
  its TODO-1 decision batch (Atkinson rule, bootstrap shape, threshold
  schedule, carry-over default) is taken in the 1.1.0 Phase 0 sitting.
  `../new_research_ideas/design_seq_many_by_many_greedy_pair_switch.md`
  follows if wanted.

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Classical completions**
  `sequential_design_classical_completions.md → TODO-1..7` (ARP coins,
  TODO-4, only together with TODO-5 below).
- [ ] TODO-2: **Rerandomization criteria & samplers**
  `rerandomization_criterion_variants.md → TODO-1..6`.
- [ ] TODO-3: **Objective extensions**
  `optimal_design_objective_extensions.md → TODO-1..6` (shares the kernel
  with TODO-2; TODO-5 k-tuples jointly with TODO-5 below).
- [ ] TODO-4: **GSW / balancing walk / ARM-PSR**
  `gram_schmidt_walk_and_online_balancing.md → TODO-1..5`.
- [ ] TODO-5: **Unequal allocation**
  `unequal_allocation_matching_greedy_minimization.md → TODO-1..5` (its
  TODO-1 route decision depends on the 1.2.0 greedy merge's `pair_mode`
  finding).
- [ ] TODO-6: **Cluster-level balancing designs**
  `cluster_level_covariate_balancing_designs.md → TODO-1..5`.
- [ ] TODO-7: **Many-by-many family** `design_seq_many_by_many.md →
  TODO-2..10` (TODO-2's shared-ingestion extraction is behavior-
  preserving under golden test).
- [ ] TODO-8: Registry / capability metadata sweep
  (`supports("cluster")`, `prob_T` capability, `randomization_family`
  enum additions) and the design-side vignette update.
- [ ] TODO-9: **Release mechanics** per `release.md`.

## Standing constraints

As 1.1.0/1.2.0: additive, bit-for-bit defaults (every new `criterion` /
`objective` / `cluster_col` / `prob_T` argument defaults to today's
behaviour), `define_design_class()` for every class, kernel conventions,
targeted compile only.
