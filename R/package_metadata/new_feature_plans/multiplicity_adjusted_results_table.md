# Multiplicity-Adjusted `results_table`: Which Specific Models Survive Correction

> **Depends on:** nothing architectural — a post-process over
> `InferenceSuite$run_all_inference()`'s existing `results_table`, additive
> alongside the Cauchy combination test, `wilkinson_combined_pval.md`, and
> `model_averaged_estimand_report.md`. No dependency on any of those three;
> genuinely independent deliverable. **Release target: v1.4.0**
> (`release_v1_4_0.md → TODO-11c`).

Written 2026-08-30.

## Why

`combined_evidence$pval` (Cauchy combination), the vote-count/Wilkinson work
(`wilkinson_combined_pval.md`), and Berger's IUT (`max(pval)`, also in that
plan) all collapse `results_table`'s many rows into **one number** answering
some flavor of "is there evidence anywhere / in most places / everywhere."
None of them answer a differently-shaped, equally legitimate question: "of
these `k` estimands/models fit to the same outcome, *which specific ones*
are individually significant, after honestly accounting for having looked at
all `k` of them?"

That's the classical multiple-comparisons question, and it has a
well-established honest answer that needs no dependence-robustness project
at all: apply Holm's step-down procedure (strong FWER control, valid under
*arbitrary* dependence — no assumption-audit needed, unlike Wilkinson's
r-out-of-k work) or Benjamini-Hochberg's step-up procedure (FDR control,
valid under independence or positive regression dependence — a condition
worth checking against `InferenceSuite`'s procedures, see Tests below) to
the raw `pval` column, and report the resulting per-row adjusted decisions
alongside (not instead of) the existing combined-evidence summaries.

This directly answers the "without cheating" question from the surrounding
discussion: it's honest by construction as long as the candidate set
(`applicable_design_classes`, already structurally fixed at discovery time,
not caller-curated) is fixed before the correction is applied — the same
precondition every other summary in this family already relies on.

## Proposal

- Add `combined_evidence$multiplicity_adjusted` (or a top-level sibling
  field; naming TBD) to `run_all_inference()`'s return value: a copy of the
  relevant `results_table` columns plus one or two new columns,
  `pval_holm`/`pval_bh` (adjusted p-values) and `reject_holm`/`reject_bh`
  (logical, at the suite's own `alpha`).
- `method = c("holm", "bh", "both")` argument (default `"both"`, both are
  cheap to compute from the same sorted p-value vector).
- Scope: apply per estimand group by default (mirrors
  `combined_evidence_weighting = "estimand_grouped"`'s existing rationale —
  correcting across estimand groups conflates the "many testing methods for
  one model" multiplicity with the "many different model specifications"
  multiplicity, which are different sources of multiplicity a user may want
  controlled separately); an `across_estimands = TRUE` option additionally
  runs the correction over the full flat set for users who want one FWER/FDR
  budget across everything.
- Print/HTML surface: one additional table section (or an extra
  column on the existing per-estimand table) showing which rows survive
  correction — no new plot needed, this is tabular by nature.

## Tests

- Golden test: hand-computed Holm/BH adjusted p-values and rejection sets on
  a small fixed `pval` vector, compared against `stats::p.adjust(method =
  "holm"/"BH")` (do not reimplement the arithmetic — call it).
- Holm validity needs no dependence assumption to check (true under
  arbitrary dependence by construction) — no calibration test needed beyond
  the golden test.
- BH's formal FDR guarantee assumes independence or PRDS (positive
  regression dependency on a subset); `InferenceSuite`'s rows are fit to the
  same dataset and are *not* generally independent, so this needs a
  calibration check under the true null (`betaT = 0` in
  `SimulationFramework`) confirming BH's empirical false-discovery rate
  stays near nominal here in practice, the same style of check already
  backing CCT's and (proposed) Wilkinson's use in this codebase — if it
  doesn't hold up, ship Holm only and document BH as unavailable/experimental
  rather than silently mis-calibrated.

## TODOs

- [ ] TODO-1: Implement Holm adjustment (`stats::p.adjust(method = "holm")`
  wrapper) over `results_table`, estimand-grouped by default with
  `across_estimands` opt-out.
- [ ] TODO-2: Implement BH adjustment the same way; run the PRDS calibration
  check (Tests, above) before enabling it by default — ship gated
  (`method = "holm"` default) if the check fails.
- [ ] TODO-3: Wire `combined_evidence$multiplicity_adjusted` (or equivalent)
  into `run_all_inference()`'s return value and its print/HTML/PDF output.
- [ ] TODO-4: golden tests against `stats::p.adjust()`; BH calibration test
  under `betaT = 0`.
- [ ] TODO-5: roxygen — distinguish this from `combined_evidence$pval`
  (a single joint-null test) and from `vote_fraction`/`iut_pval`
  (`wilkinson_combined_pval.md`, also single numbers): this is the one
  summary in the family that names *which* rows are significant, not
  whether *any*/*most*/*all* are.

## References

Holm, S. (1979), "A simple sequentially rejective multiple test procedure,"
*Scandinavian Journal of Statistics*, 6(2), 65-70 — the step-down FWER
procedure, valid under arbitrary dependence.

Benjamini, Y., and Hochberg, Y. (1995), "Controlling the false discovery
rate: a practical and powerful approach to multiple testing," *Journal of
the Royal Statistical Society: Series B*, 57(1), 289-300 — the step-up FDR
procedure; validity under dependence established later by Benjamini & Yekutieli
(2001) for the PRDS case.
