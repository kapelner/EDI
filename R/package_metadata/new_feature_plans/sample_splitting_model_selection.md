# Sample-Splitting / Data-Carving Workflow for InferenceSuite Model Selection

> **Depends on:** nothing existing architecturally, but is itself an
> architectural addition — a new two-phase fitting workflow, not a
> post-process over `results_table` the way
> `wilkinson_combined_pval.md`/`model_averaged_estimand_report.md`/
> `multiplicity_adjusted_results_table.md` (all v1.x) are. Needs real
> `Design`-level splitting support, particularly for sequential
> matching-on-the-fly designs (see "Architectural cost" below). **Release
> target: v2.0.0** (`release_v2_0_0.md → TODO-6e`) — "genuinely new
> functionality requiring large refactoring," per this repo's 1.x/2.0.0
> release-line rule, not an additive v1.x item.

Written 2026-08-30.

## Why

Every other multi-model summary discussed for `InferenceSuite`
(`combined_evidence$pval`'s CCT, `wilkinson_combined_pval.md`'s
vote-count/order-statistic work, `model_averaged_estimand_report.md`'s
model averaging, `multiplicity_adjusted_results_table.md`'s Holm/BH
correction) reuses the *same* data to both choose/weight/test the candidate
models and to report significance on them. Each has its own validity
argument for why that's still honest (dependence-robust closed forms,
union-bound arguments, `p.adjust()`'s guarantees) — but all of them are
*corrections* applied after the fact to a set of models all fit on the full
data.

Sample splitting sidesteps the multiplicity problem structurally instead of
correcting for it: partition the data, use one part to pick which
model/link/procedure looks best, then test *only that one* on the held-out
part at the ordinary, uncorrected $\alpha$. No combination formula is
needed at all, because the "winning" model's significance is never
evaluated on the same observations that made it win — this is the most
airtight honest answer to "how do I look at many competing models without
cheating" that this whole line of discussion produced. The cost is real and
should not be undersold: only part of the data is used for the actual
confirmatory test, so power is genuinely lower than any full-data method
above, and this is a fundamentally different workflow from anything
`InferenceSuite` does today (it fits every applicable class once, on the
full dataset, in one pass).

## Mechanics

1. Partition enrolled subjects into a **selection set** $S$ and a
   **confirmation set** $C$ (e.g. a 50/50 split, tunable).
2. Fit every class in `applicable_design_classes` on $S$ only; pick one
   winning class/model specification by some pre-declared selection
   criterion (smallest p-value on $S$? best AIC? the existing
   `combined_evidence` pipeline restricted to $S$? — a real decision, not
   an obvious default; see Stage 0 below).
3. Refit *only* the winning class on $C$.
4. Report that one class's estimate/CI/p-value, computed on $C$ alone, at
   the full nominal $\alpha$ — no adjustment needed, because this is now an
   ordinary single confirmatory test on fresh data.

Two flavors, worth distinguishing up front because their implementation
cost differs enormously:

- **Plain sample splitting** (Cox 1975): discard $S$ entirely for the final
  inference. Simple, needs no new per-class theory, but wasteful — only the
  $C$-allocated fraction of the data is ever used for the actual test.
- **Data carving** (Fithian, Sun & Taylor 2014): additionally condition on
  the selection event (which model won) and recover some of $S$'s
  information in a validity-preserving way, recouping some of plain
  splitting's power loss. Substantially heavier: it needs a tractable
  conditional-on-selection likelihood or test derived per `Inference` class,
  which is a large lift to do correctly across the registry rather than a
  generic wrapper.

## Architectural cost — why this is v2.0.0, not an additive v1.x plan

- Every `Design` subclass today accumulates one coherent set of enrolled
  subjects; splitting needs two coherent sub-`Design` objects sharing the
  same `response_type`/`design_formula`/etc. but carrying disjoint subject
  subsets. For **sequential (matching-on-the-fly) designs** in particular,
  this is not a post-hoc row filter: each subject was matched against
  *every previously enrolled* subject at assignment time, so partitioning
  after the fact can silently break the design's own within-half covariate-
  balance guarantees. Whether the split needs to happen *a priori*
  (declaring some subjects "selection-only" as they're enrolled,
  interleaved, or by index range) is a real design-level question, not a
  detail.
- `InferenceSuite$run_all_inference()` today fits every applicable class
  **once**, against **one** `Design` object holding the full data. Sample
  splitting needs a genuinely new orchestration mode: fit-on-$S$, select,
  refit-winner-on-$C$ — a different control flow, not a new parameter on
  the existing method.
- The selection criterion itself is an open design decision with real
  power/validity tradeoffs (see Stage 0), unlike the v1.x plans above where
  the combining formula was mostly a known quantity from the literature.

## Proposal (staged)

- **Stage 0 (Phase 0 decision):** selection criterion; split ratio/policy
  (fixed 50/50 default vs. user-tunable); the `Design`-level splitting
  mechanism, with explicit attention to sequential matching-on-the-fly
  designs.
- **Stage 1 (plain sample splitting):** implement `Design`-level splitting
  (name TBD, e.g. `split_design()`) returning two coherent sub-`Design`
  objects, plus an `InferenceSuite` orchestration mode (e.g.
  `run_all_inference(split = TRUE)` or a dedicated method) that fits every
  applicable class on $S$, selects a winner by the Stage-0 criterion, refits
  only that winner on $C$, and returns its estimate/CI/p-value together with
  metadata recording which class won and why.
- **Stage 2 (gated on appetite after Stage 1's power benchmark):** data
  carving, starting with the simplest classes (e.g. OLS / simple
  mean-difference) where a tractable conditional-on-selection adjustment is
  most likely to already exist in the literature, rather than attempting the
  whole registry at once.

## Tests

- Stage 1 calibration: under the true null (`betaT = 0` in
  `SimulationFramework`), the confirmation-set test's type-I error should be
  *exactly* nominal, not merely approximately calibrated — this is the
  entire point of the method (an ordinary single test on fresh data), and a
  failure here would mean the split/selection step leaked information.
- Stage 1 power benchmark: compare against (a) the full-data
  single-best-model oracle (an upper bound no honest procedure can beat) and
  (b) `combined_evidence$pval`/Wilkinson at matched nominal $\alpha$, to
  quantify and document the real power cost of splitting in typical
  `InferenceSuite` scenarios — this is the concrete number that lets a user
  decide whether the honesty is worth the power loss for their use case.
- Sequential-design-specific test: confirm the chosen splitting mechanism
  does not silently break a sequential design's own within-half balance
  guarantees (run the design's existing balance diagnostics separately on
  $S$ and $C$).

## TODOs

- [ ] TODO-1: Phase 0 decision — selection criterion, split ratio/policy,
  and the `Design`-level splitting mechanism (especially for sequential
  matching-on-the-fly designs).
- [ ] TODO-2: Implement `Design`-level splitting producing two coherent
  sub-`Design` objects; unit tests confirming each half is a valid,
  self-consistent `Design` for its `response_type`.
- [ ] TODO-3: Implement Stage 1 orchestration on `InferenceSuite`
  (selection fit → winner pick → confirmation fit); document the return
  schema (which class won, why, plus the confirmation-set estimate/CI/pval).
- [ ] TODO-4: Calibration test (exact type-I error under `betaT = 0`) and
  the power-tradeoff benchmark against full-data alternatives.
- [ ] TODO-5 (gated on TODO-1 / appetite after TODO-4's benchmark): Stage 2
  data carving for a starter subset of classes.
- [ ] TODO-6: roxygen distinguishing this workflow from every other
  `InferenceSuite` summary in this family — it's the one method that
  restructures *data usage* itself rather than combining, weighting, or
  adjusting a full-data `results_table`.

## References

Cox, D. R. (1975), "A note on data-splitting for the evaluation of
significance levels," *Biometrika*, 62(2), 441-444 — the classical
sample-splitting idea.

Fithian, W., Sun, D., and Taylor, J. (2014), "Optimal Inference After Model
Selection," arXiv:1410.2597 — data carving, generalizing sample splitting to
recover some of the selection-stage data's information validly.

Rasines, D. G., and Young, G. A. (2023), "Splitting strategies for
post-selection inference," *Biometrika*, 110(3), 597-614 — a modern
treatment of splitting-based approaches, useful background for the Stage 0
selection-criterion decision.
