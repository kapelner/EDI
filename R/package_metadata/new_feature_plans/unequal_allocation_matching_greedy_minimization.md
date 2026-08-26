# Unequal Allocation (`prob_T ≠ 0.5`) in Matching, Greedy-Swap and Sequential-Coin Designs

> **Depends on:** `design_fixed_greedy_pair_switch_merge.md` (its
> general-`prob_T` swap-delta rederivation is the model for the greedy
> half); `sequential_design_classical_completions.md` (ARP coins ship
> together with unequal ratios on sequential classes). **Release target:
> v1.2.0** (`release_v1_2_0.md → TODO-12d`).

Written 2026-08-27. Owning plan for
`missing_design_classes_literature_audit.md` item **#1** (Part 4A) and
`missing_theoretical_design_classes_literature_audit.md` item **#38**
(Neyman allocation helper).

## Why

2:1 allocation is used in 10–15% of medical trials (estimate; Dumville
2006; Hey & Kimmelman 2014), common in industry phase II/III; unequal
ratios are occasional in economics. EDI's `iBCRD`, `Bernoulli`,
`Blocking`, `Cluster`, `GreedyDOptimal`, `Optimal`, `Rerandomization`
accept any `prob_T`, but `BinaryMatch`, `MatchingGreedyPairSwitching` and
`Greedy` hard-error at `prob_T ≠ 0.5`, and `Efron` / `Urn` / `PocockSimon`
/ `Atkinson` use `prob_T` only as a tie or fallback coin, so they cannot
target 2:1.

## Proposal

- **Greedy-swap**: covered by the merge plan's rederivation (swap delta
  `(n/2)(1/n_T + 1/n_C)`); this plan tracks the matched-pair variant.
- **Matched designs**: two options, decide at TODO-1 — (a) 1:2 / 1:k
  *triplets/k-tuples* via k-way non-bipartite grouping (the Cytrynbaum
  2023/24 "local randomization" theory; the k-way matching design class
  `full_glmm_for_weibull_frailty.md` TODO-0 defers); (b) keep pairs and
  randomize the residual `n_T − n/2` subjects at the target rate from a
  reservoir. (a) is principled and has inference theory; (b) is cheap.
- **Sequential coins**: allocation-ratio-preserving versions (Kuznetsova
  & Tymofyeyev) of Efron / Wei / Pocock-Simon / Atkinson with a
  `target_ratio =`; the Atkinson D_A rule generalizes directly (Atkinson &
  Biswas).
- **Neyman allocation helper**: `neyman_prob_T(pilot)` returning
  `σ_T/(σ_T + σ_C)` (global) or per-stratum propensities (Hahn-Hirano-
  Karlan 2011) with the Cai & Rafi (2024) small-pilot regularization;
  per-stratum `prob_T` vector accepted by `DesignFixedBlocking`.

## Tests

`prob_T = 0.5` is a golden no-op everywhere; realized `n_T` at the target
for each class; ARP: unconditional `P(w_i = 1)` = target at every
position; k-tuple matching vs `nbpMatching`-based reference; Neyman
helper vs closed form.

## TODOs

- [ ] TODO-1: Decide matched-design route (k-tuples vs reservoir).
- [ ] TODO-2: `MatchingGreedyPairSwitching` and `BinaryMatch` unequal
  allocation per TODO-1.
- [ ] TODO-3: `target_ratio =` + ARP on Efron / Wei / Pocock-Simon /
  Atkinson.
- [ ] TODO-4: `neyman_prob_T()` helper; per-stratum `prob_T` on `Blocking`.
- [ ] TODO-5: registry `prob_T` capability metadata; fixtures; roxygen.
