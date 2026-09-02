# Selective (Post-Selection) Inference for InferenceSuite Model Selection

> **Depends on:** nothing existing architecturally for the Phase 0 scoping
> and a narrow single-class pilot; a full per-class rollout across the
> registry is a much larger, likely multi-release lift (see "Scope note"
> below). Complementary to, and technically stronger than,
> `sample_splitting_model_selection.md` (v2.0.0) — see "Relationship to
> sample splitting." **Release target: v1.4.0** (`release_v1_4_0.md →
> TODO-11d`), scoped to Phase 0 + one pilot class; broader rollout may need
> to move to a later release once the pilot's actual lift is known.

Written 2026-08-30.

## Why

Every full-data multi-model summary in this family —
`combined_evidence$pval` (CCT), `wilkinson_combined_pval.md`'s vote-count/
order-statistic work, `model_averaged_estimand_report.md`'s model averaging,
`multiplicity_adjusted_results_table.md`'s Holm/BH correction — answers "how
do I honestly summarize evidence across many models fit on the same data."
`sample_splitting_model_selection.md` answers "how do I honestly test one
model chosen from many, without any correction formula at all" by sacrificing
data to a split.

Selective (post-selection) inference is the third, technically strongest
answer to that same question: methods like PoSI (Berk et al. 2013) or data
carving (Fithian, Sun & Taylor 2014) derive p-values/CIs that are **already
valid conditional on having selected the winning model from the full
candidate set** — without needing to sacrifice any data to a split. This is
the most direct honest answer to "I looked at 18 models and picked the best
one" that uses *all* the data for both selection and inference, at the cost
of a substantially heavier statistical/implementation lift than anything
else discussed: the validity argument (and the resulting adjusted
distribution to test against) is generally derived **per model class**, not
as a generic wrapper over `results_table` the way Holm/BH or CCT are.

## Mechanics

The core idea: condition the sampling distribution of the winning model's
test statistic on the *event that it was selected* (e.g. "this class had the
smallest p-value among the k candidates"), rather than treating its p-value
as if the class had been chosen a priori. Two established families:

- **PoSI (Berk, Brown, Buja, Zhang & Zhao 2013):** derives simultaneously
  valid confidence intervals that hold *uniformly over every possible
  model-selection procedure* a analyst might have used — the strongest,
  most conservative guarantee (valid regardless of which selection rule was
  actually followed), originally worked out for linear regression variable
  selection specifically.
- **Data carving (Fithian, Sun & Taylor 2014):** conditions on the *specific*
  selection event that actually occurred (e.g. "class $j$ had the smallest
  p-value") and derives a truncated/conditional reference distribution for
  that specific case — less universally conservative than PoSI (it exploits
  knowing exactly what selection rule was used and what happened), but the
  derivation is specific to both the selection rule and the model family,
  so it needs to be redone per `Inference` class (or class family) rather
  than applying generically. This is the same data-carving idea flagged as
  `sample_splitting_model_selection.md`'s Stage 2, but derived without
  discarding any data to a split (see "Relationship to sample splitting").

Both require, for each candidate `Inference` class: (a) a description of the
selection event in terms of that class's test statistic, and (b) a tractable
conditional (often truncated-Normal or truncated-$\chi^2$-family) null
distribution for that statistic given the event — this is exactly why the
literature (and the lift here) is per-model-class, unlike a generic p-value
combiner that only needs each $p_i$ to already be marginally valid.

## Relationship to sample splitting

`sample_splitting_model_selection.md` and this plan solve the same problem
by different means:

| | Uses all the data? | Validity source | Implementation cost |
|---|---|---|---|
| Sample splitting (Stage 1) | No — confirmation set only | Structural (selection and test see disjoint data) | Low — mostly `Design`-level splitting machinery |
| Data carving (either plan's version) | Partially | Conditional distribution given selection | High — per selection-rule/model-family derivation |
| Selective inference / PoSI (this plan) | Yes | Conditional distribution given selection, or uniform-over-selection-rules guarantee | Highest — per-class derivation, no generic wrapper |

If both plans proceed, they should share the underlying "condition on the
selection event" machinery where it overlaps (data carving is common to
both) rather than developing two separate implementations — worth an
explicit cross-check once `sample_splitting_model_selection.md`'s Stage 2 is
scoped.

## Design-based implementation route (added 2026-09-02, user decision): the rejection-sampled conditional randomization test

Classical conditional inference needs per-selection-rule geometry
(polyhedral characterizations of the selection event). EDI has a
geometry-free route unavailable to generic packages, because inference
already calls back into the design: **redraw `w` from the design, re-run
the entire selection pipeline per redraw, keep only the redraws where
the same model wins, and compute the randomization p-value within that
accepted subset.** That is exact conditional-on-selection inference
under the sharp null for *any* selection rule — no algebra, no
per-class derivation — which directly attacks this plan's own "per-class
rollout cost" scope concern: one wrapper serves every class the
selection pipeline can pick.

Costs stated honestly: (i) the acceptance rate is the price — a fragile
winner means most redraws are discarded, so the effective replicate
count (and hence p-value resolution) degrades exactly when selection was
least stable; report the acceptance rate alongside the p-value and set a
typed floor below which the result is declared non-estimable rather than
reported on a handful of accepted draws. (ii) It conditions on the
selection event within the sharp-null randomization frame — it does not
deliver the asymptotic/likelihood-scale conditional CIs the polyhedral
route gives, so it complements rather than replaces the Stage 1 pilot.
(iii) Selection re-runs per redraw: pipeline-cost × replicates ÷
acceptance rate, mitigated by warm starts, the parallel layers, and
sequential-MC early stopping. The pipeline definition, gate constants,
and provenance object come from `model_selection_framework.md` §5
(which routes to this plan via its `method = "rand_conditional"`); the
blinding-commutation special case documented there does not apply here —
conditioning is only interesting when selection is unblinded, since
blinded selection is invariant across redraws and the acceptance rate is
then 1 (the conditional test degenerates, correctly, to the plain test).

## Scope note (why this is staged, and staged conservatively)

A full rollout — every applicable `Inference` class in the registry gaining
a selective-inference-valid p-value/CI — is a large, multi-class research
and implementation project, closer in scope to
`sample_splitting_model_selection.md`'s architectural weight than to the
thin-wrapper v1.x plans above. Rather than defer the whole idea to 2.0.0
outright, this plan is scoped narrowly for v1.4.0: a **Phase 0 decision**
plus **one pilot class** (the simplest tractable case — likely
`InferenceContinOLS`/simple mean-difference, where PoSI's original linear-
regression derivation applies most directly) to establish real implementation
cost before deciding whether broader rollout is v1.4.0-tractable or needs to
move to 2.0.0 alongside `sample_splitting_model_selection.md`.

## Proposal (staged)

- **Stage 0 (Phase 0 decision):** PoSI vs. data-carving as the starting
  framework (PoSI's uniform guarantee is more conservative but
  selection-rule-agnostic and arguably a better fit for `InferenceSuite`'s
  open-ended candidate set; data carving needs the selection rule fixed in
  advance, which `InferenceSuite`'s `combined_evidence`-style winner-picking
  could supply); which selection statistic to condition on (matches Stage 0
  of `sample_splitting_model_selection.md` — same open decision, share it).
- **Stage 1 (pilot):** implement the chosen framework for one class
  (`InferenceContinOLS`, continuous mean-difference) end to end: selection
  event definition, conditional reference distribution, adjusted p-value/CI.
  Benchmark its implementation cost and its power against Stage 1 sample
  splitting and against the naive (invalid, for contrast) unadjusted
  approach.
- **Stage 2 (gated on Stage 1's measured cost):** extend to additional
  classes by family (e.g. other GLM-based classes sharing OLS's asymptotic
  structure first), or defer broader rollout to 2.0.0 if Stage 1 shows the
  per-class cost is prohibitive at v1.x's expected pace.

## Tests

- Stage 1 calibration: under the true null (`betaT = 0` in
  `SimulationFramework`), the pilot class's selective-inference-adjusted
  p-value's empirical type-I error should be exactly nominal *even when
  restricted to replications where that class was actually the one
  selected* — this conditional calibration check is the crux of the whole
  method and the one most likely to reveal a derivation error.
- Power comparison: pilot class's selective-inference-adjusted test vs. (a)
  the naive unadjusted p-value (invalid, shown for contrast — should be
  visibly anti-conservative under the same conditional-selection
  replications), (b) Stage 1 sample splitting at the same nominal $\alpha$,
  and (c) the full-data oracle upper bound.

## TODOs

- [ ] TODO-1: Phase 0 decision — PoSI vs. data carving as the starting
  framework; selection statistic (coordinate with
  `sample_splitting_model_selection.md → TODO-1`, same underlying decision).
- [ ] TODO-2: Implement the chosen framework for the pilot class
  (`InferenceContinOLS`): selection-event definition, conditional reference
  distribution, adjusted p-value/CI.
- [ ] TODO-3: Conditional-calibration test (type-I error under `betaT = 0`,
  restricted to replications where the pilot class was actually selected)
  and the three-way power comparison (naive / sample-split / this method).
- [ ] TODO-4: Document the pilot's actual implementation cost (person-time,
  lines of derivation/code, test complexity) as the input to the Stage
  2/2.0.0-deferral decision.
- [ ] TODO-5 (gated on TODO-4): extend to additional classes by family, or
  formally move remaining rollout to 2.0.0 alongside
  `sample_splitting_model_selection.md`'s data-carving stage.
- [ ] TODO-6: roxygen distinguishing this from every other summary in the
  family, with explicit cross-reference to `sample_splitting_model_selection.md`
  (same underlying problem, different validity mechanism and cost profile).
- [ ] TODO-7 (added 2026-09-02): the rejection-sampled conditional
  randomization test (see the design-based-route section above) —
  wrapper over `model_selection_framework.md`'s provenance object and
  the custom-randomization-statistic machinery; acceptance-rate
  reporting with a typed non-estimable floor; conditional-calibration
  test mirroring TODO-3 (type-I error within accepted-draw subsets under
  `betaT = 0`); benchmark against the Stage 1 polyhedral pilot on the
  same simulated selections. Sequenced after
  `model_selection_framework.md → TODO-7` supplies the pipeline wrapper
  (v2.0.0), even though this plan's polyhedral pilot is v1.4.0 — the two
  routes ship independently.

## References

Berk, R., Brown, L., Buja, A., Zhang, K., and Zhao, L. (2013), "Valid
post-selection inference," *Annals of Statistics*, 41(2), 802-837 — PoSI.

Fithian, W., Sun, D., and Taylor, J. (2014), "Optimal Inference After Model
Selection," arXiv:1410.2597 — data carving; same reference as
`sample_splitting_model_selection.md`'s Stage 2.

Taylor, J., and Tibshirani, R. J. (2015), "Statistical learning and
selective inference," *Proceedings of the National Academy of Sciences*,
112(25), 7629-7634 — accessible overview of the selective-inference
framework this plan draws on.
