# Wilkinson's r-out-of-k Order-Statistic Combination Test for InferenceSuite

> **Depends on:** nothing architectural — additive alongside the existing
> Cauchy combination test (`cct_combine_pvalues()` /
> `run_all_inference_combine_pvalues()`) in `R/inference_suite.R`. **Release
> target: v1.1.0** (`release_v1_1_0.md → TODO-17n`).

Written 2026-08-30.

## Why

`InferenceSuite$run_all_inference()`'s `combined_evidence$pval` answers "does
*at least one* applicable inference procedure detect a signal on this
estimand" — a union-intersection test built on the Cauchy combination test
(CCT; Liu & Xie 2020), chosen because CCT's dependence-robust closed-form
null holds under the arbitrary, unknown correlation among procedures fit to
the same dataset (see `cct_combine_pvalues()`'s roxygen and the "Combined
Evidence interpretation caveat" on `InferenceSuite`). But "at least one
rejects" is not the only question users ask, and CCT's tan-transform
statistic is dominated by whichever single p-value is smallest by
construction — it structurally cannot answer "do *most* of the applicable
procedures agree there's an effect," a materially different and arguably
more robust question (closer to "does this conclusion survive across
reasonable modeling choices" than to "is there any modeling choice under
which we'd reject"). No amount of reweighting the existing CCT call answers
this: the tail behavior that gives CCT its validity guarantee is exactly
what makes it a min-type, not a majority-type, statistic.

Wilkinson's test generalizes "smallest p-value" (r = 1, essentially what CCT
approximates in the tail) to "the r-th smallest p-value out of k," letting a
caller pick r = ceil(k/2) (or any other cutoff) to test "at least r of k
reject" — i.e. majority/plurality agreement rather than existence of one
striking result.

## The catch: no free lunch under dependence

CCT's appeal is precisely that Liu & Xie (2020) derive a closed-form
asymptotic null distribution for its tan-transformed statistic that is valid
under *arbitrary, unknown* dependence among the input p-values — no
covariance estimation, no resampling. Wilkinson's r-th-order-statistic test
has no equivalent closed-form result under dependence: the classical
Wilkinson/Tippett-type derivations assume independence, and the r-th order
statistic's null distribution under correlated inputs depends on the
(unknown, and here structurally uncharacterized) joint dependence structure
among the different inference procedures' p-values — every row `InferenceSuite`
discovers is fit to the *same* dataset, so independence is not a defensible
assumption (the same reason Fisher's/Stouffer's combination was rejected in
favor of CCT for the existing metric).

A naive implementation (plug the order statistic into the independence-case
reference distribution) would therefore not be valid here. Options, roughly
in order of implementation cost:

1. **Permutation/bootstrap-calibrated reference distribution.** Simulate the
   joint null (shared response, no treatment effect) via the design's own
   randomization distribution or a parametric bootstrap under the fitted
   null models, recompute every procedure's p-value on each simulated
   dataset, and empirically calibrate the r-th-order-statistic's null
   quantiles. Valid by construction, but expensive: this is `Nrep` extra
   full re-fits of every applicable class, similar in cost to
   `SimulationFramework`'s own null-calibration runs, and would need to
   reuse `run_all_inference()`'s discovery/dispatch machinery rather than
   duplicating it.
2. **A conservative closed-form bound.** Bonferroni-style or Simes-style
   bounds on an order statistic exist under limited dependence assumptions
   (e.g. positive regression dependence), but likely don't hold generally
   across truly heterogeneous procedures (bootstrap vs. asymptotic vs.
   exact), so would need its own validity audit before shipping, comparable
   to what backs today's CCT choice.
3. **Report the vote count only, undecorated with a p-value.** Skip the
   reference-distribution problem entirely: `results_table` already has
   every row's `pval`, so `sum(pval < alpha) / nrow(results_table)` (or a
   per-estimand breakdown) can ship as an additional descriptive summary
   field with no new statistical machinery — at the cost of it not being a
   formal hypothesis test with a controlled size.

## Proposal (staged)

- **Stage 1 (cheap, no new theory):** add a plain descriptive vote-count
  field to `run_all_inference()`'s return value alongside `combined_evidence`
  — e.g. `combined_evidence$vote_fraction` (and a per-estimand breakdown
  mirroring the existing per-estimand Cauchy breakdown printed by
  `run_all_inference_combined_evidence_summary_line()`) reporting the
  fraction of usable rows with `pval < alpha`. Ships independently of the
  harder order-statistic work below; answers "do most agree" informally,
  without claiming a formal type-I error guarantee.
- **Stage 2 (gated on a Phase 0 decision):** decide whether a formal
  r-out-of-k test is worth the calibration cost above. If yes, prototype
  option 1 (bootstrap/permutation-calibrated r-th order statistic) as an
  opt-in `combined_evidence_method = c("cauchy", "wilkinson")` alongside the
  existing Cauchy path on `run_all_inference()`, reusing its discovery/fit
  loop for the null re-simulations rather than duplicating it.

## Tests

- Stage 1: golden test on `vote_fraction` for a known `results_table`
  (hand-computed fraction); confirm it does not depend on
  `combined_evidence_weighting` (a plain count, not a weighted combination).
- Stage 2 (if built): calibration test under the true null (`betaT = 0` in
  `SimulationFramework`) confirming the empirical rejection rate of the
  Wilkinson test matches nominal `alpha` across many replications, the same
  style of calibration check already backing CCT's use here (see
  `inference_suite_plan.md`'s calibration-testing notes).

## TODOs

- [ ] TODO-1: Decide (Phase 0) whether Stage 2's formal r-out-of-k test is
  worth building given its calibration cost, or whether Stage 1's
  descriptive vote fraction is sufficient on its own.
- [ ] TODO-2: Ship Stage 1 — `vote_fraction` (overall and per-estimand) on
  `run_all_inference()`'s return value; roxygen note distinguishing it from
  `combined_evidence$pval` (a descriptive count, not a p-value with a
  controlled type-I error rate).
- [ ] TODO-3 (if TODO-1 decides yes): design and validate the null-calibration
  procedure for the r-th-order-statistic reference distribution (option 1
  above).
- [ ] TODO-4 (if TODO-1 decides yes): add the `combined_evidence_method`
  switch (`"cauchy"` default, unchanged, vs. `"wilkinson"`); parity test
  that the `"cauchy"` path's output is bit-identical to today's.
- [ ] TODO-5: cross-reference from `InferenceSuite`'s existing "Combined
  Evidence interpretation caveat" roxygen section to this plan and the new
  field(s), once shipped.

## References

Liu, Y. and Xie, J. (2020), "Cauchy combination test: a powerful test with
analytic p-value calculation under arbitrary dependency structures," *Journal
of the American Statistical Association*, 115(529), 393-402 — same reference
as `cct_combine_pvalues()`'s roxygen, cited here for contrast.

Wilkinson, B. (1951), "A statistical consideration in psychological
research," *Psychological Bulletin*, 48(2), 156-158 — the original
r-th-order-statistic combination test this plan generalizes from.
