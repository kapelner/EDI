# `InferenceOrdinalRidit(reference = "treatment")` Reports an Identically Zero Estimate

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-32`. Added 2026-09-24
> from the test-comment audit: pinned as `SUSPECTED SOURCE BUG (pinned, not
> fixed)` in `test-ridit-analysis-and-bootstrap-kernels-reference-groups-and-treatment-reference-degeneracy-reference.R`
> at both the kernel (`fast_ridit_analysis_cpp` and the ridit bootstrap kernel) and
> class level. The degeneracy is arithmetic and reproduced by the pinned
> tests; whether the option was ever intended to be usable is not established.

## The finding

With `reference = "treatment"` the ridit scores are computed relative to the
treated group, so the treated group's mean ridit is exactly `0.5` by
construction. The estimate is defined as `mean_ridit_t - 0.5`, so it is
identically `0` (to rounding) for every dataset, while the standard error is
positive (test: `se > 0.01`). The class therefore reports estimate `0`,
`p = 1` and a CI centered on 0 even with a strong true effect. `reference =
"control"` (the default) gives the expected non-zero estimate.

`../new_feature_plans/ridit_kernel_level_slots.md` describes performance work
for `reference = "control"`/`"treatment"` and assumes both are valid, so this
needs deciding before that plan invests in the `"treatment"` path.

## Items

- [ ] **TODO-1: Decide semantics.** Either (a) the estimand under
  `reference = "treatment"` should be redefined (e.g. `0.5 - mean control
  ridit`, the symmetric statistic, which is non-degenerate), or (b) the
  option is removed/refused with a clear error, or (c) it stays as an
  intentionally degenerate diagnostic and is documented as such. Confirm the
  literature intent (Bross's ridit analysis; the reference population is
  normally an external or pooled group).
- [ ] **TODO-2: Implement the decision** in the analysis and bootstrap
  kernels and the class; keep `"control"` and `"pooled"` bit-for-bit.
- [ ] **TODO-3: Flip the pinned tests** to assert the decided behavior.
- [ ] **TODO-4: Tell the ridit performance plan** the outcome
  (`../new_feature_plans/ridit_kernel_level_slots.md`).
- [ ] **TODO-5: Docs** (roxygen for the `reference` argument) and a NEWS
  entry; if the behavior of `"treatment"` changes it is a documented
  default change.
