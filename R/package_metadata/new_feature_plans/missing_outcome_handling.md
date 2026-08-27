# Missing-Outcome Handling: Lee Bounds, Multiple Imputation, IPW for Attrition

> **Depends on:** shipped inference hierarchy; the existing covariate
> `missingness_method` plumbing on `Design`. Moderate: outcomes may now be
> `NA` at analysis time, which every inference class currently forbids.
> **Release target: v1.4.0 (response & data extensions)**
> (`release_v1_4_0.md → TODO-11`; `_master.md` Phase 5X).

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#16** (Part 4B).

## Why

EDI imputes / drops *covariates* but has no missing-*outcome* pathway
(`assert_all_responses_recorded()`). Practice: complete-case is the
majority in medicine (45%, Bell et al. 2014), MI in 8% of trials but
common in IES education work; Lee (2009) trimming bounds are common in
development / labor RCTs with differential attrition; IPW and
delta-adjusted / tipping-point sensitivity analyses are the regulatory
expectation under ICH E9(R1).

## Proposal

- Design side: allow `y = NA` (and `y_L/y_R = NA`) to mean "outcome
  missing"; `get_response_observed()` indicator; `assert_all_responses_recorded()`
  becomes `assert_no_missing_outcomes()` with an opt-out.
- `InferenceAllLeeBounds` — Lee (2009) sharp bounds on the ATE under
  monotone selection: trim the arm with higher response rate at the
  quantile `p = (r_high − r_low)/r_high` from above and below;
  bootstrap/randomization CIs (Imbens-Manski). Manski worst-case bounds
  as a `method = "manski"` option for bounded outcomes.
- **Multiple-imputation wrapper** — `run_with_multiple_imputation(inf_class,
  m = 20, imputer = )`: impute outcomes (default: `mice`-style chained
  equations on covariates + `w`, arm-specific), fit any inference class
  per completed dataset, pool with Rubin's rules (estimate, SE, Barnard-
  Rubin df). Works for every class with a scalar estimate + SE; document
  that randomization p-values are not Rubin-poolable (use the
  bootstrap-MI combination instead).
- **IPW for attrition** — `weights =` on the mean-difference and
  regression classes from a response-propensity model; sandwich SE.
- Sensitivity: delta-adjustment / tipping-point loop over the MI wrapper.

## Tests

Lee bounds vs `leebounds` (Stata reference values) / R `leebounds`;
Rubin's rules vs `mice::pool`; no-missing-outcome case reproduces every
golden test; simulation with MAR attrition where MI recovers the truth
and complete-case is biased.

## TODOs

- [ ] TODO-1: Design-side missing-outcome representation and asserts;
  golden no-op when nothing is missing.
- [ ] TODO-2: `InferenceAllLeeBounds` (+ Manski option).
- [ ] TODO-3: MI wrapper with Rubin's rules; `mice` in `Suggests`.
- [ ] TODO-4: IPW weights on mean-difference / OLS / LPM classes.
- [ ] TODO-5: tipping-point sensitivity helper; vignette section.
