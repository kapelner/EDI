# Optimal-Design Objective Extensions: Kernel Balance, Propensity Constraints, CATE Optimality, Pilot-Index Pairing, k-Tuples

> **Depends on:** the greedy-swap engine, `DesignFixedOptimal`'s MILP /
> annealer, `DesignFixedGreedyDOptimal`'s `interest =` machinery,
> `DesignFixedBinaryMatch` (all shipped). Additive objectives and
> arguments. **Release target: v1.3.0 (design theory)** (`release_v1_3_0.md → TODO-3`;
> `_master.md` Phase 5R).

Written 2026-08-27. Owning plan for
`missing_theoretical_design_classes_literature_audit.md` items **#2, #3,
#4, #5, #9, #41, #42**.

## Items

### A. Kernel-MMD balance objective (Kallus 2018) — `objective = "mmd"(kernel)`

Worst-case conditional variance over an RKHS ball is `w'Kw` with `K` the
Gram matrix; linear kernel recovers Mahalanobis (EDI today). Drop-in on
the swap search, annealer and MILP (the MILP needs the quadratic form
linearized or handed to a QP solver — `Optimal` already does Dinkelbach
for A-criteria). Shares the kernel with
`rerandomization_criterion_variants.md` item A.

### B. Per-unit propensity / entropy constraints (Kallus §6; BJK 2015; BRT; Nordin-Schultzberg)

`DesignFixedOptimal(..., min_propensity = p)` returning `K` allocations
with every unit treated in `[p, 1−p]` of them, randomized uniformly among
the `K`; and `Greedy(..., entropy_floor =)`. Makes the balance–randomness
tradeoff a first-class constraint instead of the implicit `n_iter` /
top-quantile proxy.

### C. I-/V-optimality for CATE — `interest = "cate"`

An L-criterion `tr(L (X'X)⁻¹)` with `L` the covariate second-moment
matrix on the treatment×covariate interaction block: minimizes
`∫ Var(τ̂(x)) dF_n(x)` under the interacted model. Nobody has written this
as an assignment criterion; small on `GreedyDOptimal`'s existing
`interest =` code path. E- and G-optimality documented as not useful for
a single treatment coefficient (G ≡ D by Kiefer-Wolfowitz).

### D. Pilot-index pairing (Bai 2022) + Bai-Romano-Shaikh variance

`DesignFixedBinaryMatch(score =)` pairs on a user-supplied prognostic
index (e.g. a pilot-fitted `E[Y(1)+Y(0) | X]`) rather than raw X —
asymptotically MSE-optimal among stratified designs. The BRS (2022)
adjusted pair variance is confirmed absent from EDI's inference layer;
add it to the KK / matched-pair mean-difference classes.

### E. Matched k-tuple local randomization (Cytrynbaum 2023/24)

k-way non-bipartite grouping with `k₁` treated per tuple — the rigorous
theory for unequal allocation with matching and the design class
`full_glmm_for_weibull_frailty.md` TODO-0 defers. Coordinate with
`unequal_allocation_matching_greedy_minimization.md` TODO-1.

### F. Energy-distance / discrepancy objective — `objective = "energy"`

Nonparametric distributional balance (Székely-Rizzo); cheap once A exists.

### G. Documentation

Kasy (2016) GP-prior optimum = `Optimal` with a kernel-implied basis
(cover via A); c-optimality ≡ Mahalanobis; Higgins-Sävje-Sekhon threshold
blocking ≈ `OptimalBlocks`.

## Tests

Linear-kernel MMD ≡ Mahalanobis golden; propensity constraint verified
over the returned set; CATE criterion vs numeric `∫Var(τ̂(x))` on the
interacted OLS; pilot-index pairing vs `nbpMatching` on the score; BRS
variance vs the paper's formula; k-tuple grouping vs brute force at tiny
`n`.

## TODOs

- [ ] TODO-1: A — kernel-MMD objective on swap / annealer / MILP.
- [ ] TODO-2: B — `min_propensity` / `entropy_floor` constraints.
- [ ] TODO-3: C — `interest = "cate"` L-criterion.
- [ ] TODO-4: D — `score =` pairing; BRS variance on matched-pair inference.
- [ ] TODO-5: E — k-tuple matching design (joint with the unequal-allocation
  plan).
- [ ] TODO-6: F + G — energy objective; documentation cross-references.
