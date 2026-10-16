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
- [x] **TODO-6: Native and binding validation.** Rebuild the R native library
  and run the focused raw C++ analysis/resampling-kernel assertions against
  that rebuilt binary; build/install the Python extension and run its Ridit
  binding coverage. The source-level R checks and Python parse check above do
  not validate the changed native code in the shipped binaries.

**Same-HEAD CI validation (2026-10-16):** commit
`430c19bcdb0702d998c79f9058c449449034134c` passed R bulk run `38808821543`:
the build job installed that commit, and all five correctness shards passed.
The correctness manifest includes the focused treatment-reference,
unweighted/Wald/fast-kernel, and weighted-bootstrap Ridit tests; shard loading
uses `compile = FALSE` after the CI build. Python run `38808821508` passed its
editable-extension coverage job, which runs pytest across `python/tests`,
including `test_fast_ridit_analysis.py`, and the Linux/macOS/Windows wheel
jobs. This closes the binary-validation gate without a local build or
artifact download. CI reports aggregate job outcomes, not a separate result
for each Python test file.

**Installed-package recheck 2026-10-14:** after the user's reinstall, the
installed R package (reports EDI 1.0.3) passed the treatment-reference/raw-
kernel regression (34 assertions), unweighted/wald/fast-kernel Ridit tests
(34), and weighted-bootstrap Ridit tests (19), plus 2 fit-unavailable guard
assertions: 89 total, no failures or warnings. Codex did not compile, build,
or install. `python3` cannot import `edi_kernels` in this environment, so the
Python binding test could not run; it requires the separately managed Python
extension build/install. This was the status before the same-HEAD CI validation
above.
