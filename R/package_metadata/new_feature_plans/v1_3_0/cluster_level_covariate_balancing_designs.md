# Cluster-Level Covariate-Balancing Designs and Randomized Saturation

> **Depends on:** the `ClusterStructure` component and the fixed
> covariate-balancing designs (shipped). Moderate: one component
> generalization threads through six design classes. **Release target:
> v1.3.0 (design extensions from practice)** (`release_v1_3_0.md →
> TODO-2`; `_master.md` Phase 5T).

Written 2026-08-27. Owning plan for
`missing_design_classes_literature_audit.md` items **#2, #4, #8** (Part
4A/4B; #2 is rank 1 in its list) and the cluster halves of
`missing_theoretical_design_classes_literature_audit.md` #49–#51.

## Why

`DesignFixedCluster` / `DesignFixedBlockedCluster` only stratify on user-
supplied strata. Every covariate-balancing design in EDI (`BinaryMatch`,
`OptimalBlocks`, `Rerandomization`, `Greedy`, `GreedyDOptimal`, `Optimal`)
is subject-level. Practice at cluster level: pair-matched clusters (19%
of CRTs, Ivers 2012; very common for villages in dev econ), covariate-
constrained cluster randomization (Moulton 2004; `cvcrand`; the NIH
Collaboratory standard for few-cluster pragmatic CRTs; UK school CRTs 80%
restricted), matched quadruplets (McKenzie), stratified-then-
rerandomized geo/matched-market designs (Google/Meta ad measurement).

## Proposal

### A. `cluster_col =` on every fixed covariate-balancing design

- Generalize `ClusterStructure` to expose cluster-level covariate
  summaries (means, sizes, optionally user-supplied cluster covariates)
  and a `broadcast_w(w_cluster)` step.
- Each balancing design runs its existing algorithm on the `G × p`
  cluster-summary matrix (with cluster size as a weight where the
  criterion is size-sensitive), then broadcasts. Constrained cluster
  randomization is exactly `Rerandomization` at cluster level;
  pair-matched clusters is `BinaryMatch` at cluster level; matched
  cluster quadruplets is `OptimalBlocks`.
- Bootstrap and permutation replay already resample at cluster level.
- Registry: `supports("cluster")` capability flips on for the six classes.

### B. `DesignFixedClusterSaturation`

Two-stage: clusters are assigned a saturation level from `saturations =`
(stratified complete randomization over levels), then subjects within
each cluster are randomized at that rate (Bernoulli or complete). Baird,
Bohren, McIntosh & Özler (2018); occasional and growing in dev econ.
Replay = two nested draws. The unit-level direct-effect contrast is
two-arm; saturation-level contrasts are multi-arm-shaped and ride the
multi-arm track.

### C. Documentation: graph-derived clusters

`DesignFixedCluster` already accepts any `cluster_col`; document the
graph-cluster / ego-cluster workflow (Ugander et al. 2013; Saint-Jacques
2019) as "compute clusters upstream, pass the column"; exposure-
probability estimation stays out of scope.

## Tests

Cluster-level `BinaryMatch` vs `nbpMatching` on cluster means;
constrained randomization vs `cvcrand`; broadcast invariants (all members
share `w`); cluster-level replay tests; saturation design's marginal
`P(w_i = 1)` equals the mean saturation.

## TODOs

- [ ] TODO-1: `ClusterStructure` cluster-summary + broadcast API.
- [ ] TODO-2: `cluster_col =` on `Rerandomization` (constrained cluster
  randomization) and `BinaryMatch` (pair-matched clusters) — the two
  highest-frequency uses.
- [ ] TODO-3: `cluster_col =` on `OptimalBlocks`, `Greedy`,
  `GreedyDOptimal`, `Optimal`.
- [ ] TODO-4: `DesignFixedClusterSaturation`.
- [ ] TODO-5: docs for graph-derived clusters; registry capability; fixtures.
