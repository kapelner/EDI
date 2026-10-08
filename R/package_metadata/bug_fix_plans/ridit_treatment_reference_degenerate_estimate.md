# `InferenceOrdinalRidit(reference = "treatment")` Reports an Identically Zero Estimate

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-32`. Added 2026-09-24
> from the test-comment audit: pinned as `SUSPECTED SOURCE BUG (pinned, not
> fixed)` in `test-ridit-analysis-and-bootstrap-kernels-reference-groups-and-treatment-reference-degeneracy-reference.R`
> at both the kernel (`fast_ridit_analysis_cpp` and the ridit bootstrap kernel) and
> class level. The degeneracy is arithmetic and reproduced by the pinned
> tests; whether the option was ever intended to be usable is not established.

> **Fixed 2026-10-08.** A treatment reference now uses
> `0.5 - mean_control_ridit`, with its SE computed from the control-arm ridit
> scores. This is algebraically the same empirical Mann-Whitney contrast as
> `mean_treatment_ridit - 0.5` under a control reference and preserves the
> positive-treated-outcome sign convention. Control and pooled behavior is
> unchanged. R class, weighted/resampling paths, raw C++ kernels, Python
> binding docs/tests, Rd, NEWS, and the performance plan are aligned. All 83
> focused R assertions, including the raw C++ analysis/resampling kernels,
> pass with `compile = FALSE`. The Python sources parse, but its extension is
> not installed in this environment, so binary-level Python validation remains
> pending the user's next permitted build/install.

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

- [x] **TODO-1: Decide semantics.** Either (a) the estimand under
  `reference = "treatment"` should be redefined (e.g. `0.5 - mean control
  ridit`, the symmetric statistic, which is non-degenerate), or (b) the
  option is removed/refused with a clear error, or (c) it stays as an
  intentionally degenerate diagnostic and is documented as such. Confirm the
  literature intent (Bross's ridit analysis; the reference population is
  normally an external or pooled group).
- [x] **TODO-2: Implement the decision** in the analysis and bootstrap
  kernels and the class; keep `"control"` and `"pooled"` bit-for-bit.
- [x] **TODO-3: Flip the pinned tests** to assert the decided behavior.
- [x] **TODO-4: Tell the ridit performance plan** the outcome
  (`../new_feature_plans/ridit_kernel_level_slots.md`).
- [x] **TODO-5: Docs** (roxygen for the `reference` argument) and a NEWS
  entry; if the behavior of `"treatment"` changes it is a documented
  default change.
