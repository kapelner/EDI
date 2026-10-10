# Mixed-kernel warm-start shape guards

**Release target:** v1.0.5 TODO-38. This plan records the sibling sweep that
remained after the ZOIB heap-overflow fix. The shared test-comment audit is
historical input; this file is the implementation and validation record.

## Audit result

The ten sites named by the original static sweep reduce to these cases:

- `fast_zero_one_inflated_beta.cpp` already validates the parameter-vector
  length, Fisher-information dimensions, and row alignment.
- The count-only entry in `fast_hurdle_negbin.cpp` already calls
  `validate_truncated_negbin_inputs()` before assigning the supplied start.
- The full hurdle negative-binomial entry and seven other kernels had either a
  direct unchecked assignment or silently ignored a malformed start:
  Gaussian LMM, hurdle-Poisson GLMM, logistic GLMM, ordinal GLMM, Poisson GLMM,
  Weibull frailty, and zero-augmented Poisson.

The affected kernels now reject short, long, non-finite, and wrongly shaped
caller inputs before the optimizer or an Eigen expression can consume them.
The zero-augmented-Poisson R wrapper retains its established exception contract:
it returns a failed diagnostic result whose `exception_message` records the
shape error.

The unreferenced R helper `.fit_zero_one_inflated_beta()` also supplied a start
whose length only happened to fit a one-column auxiliary design. Its start,
parameter names, and numerical Hessian likelihood now use both full
`X_zero_one` coefficient blocks.

## TODOs

- [x] **TODO-1: Audit all ten listed sites.** Classify pre-existing guards and
  identify the eight kernel entry points needing a change.
- [x] **TODO-2: Guard the native inputs.** Validate `warm_start_params` length
  and finiteness and `warm_start_fisher_info` dimensions and finiteness before
  fitting.
- [x] **TODO-3: Repair the orphaned R helper.** Construct the full two-block
  inflation start and evaluate the matching covariate-dependent likelihood in
  its Hessian fallbacks.
- [x] **TODO-4: Add focused regression coverage.** The mixed-kernel test covers
  short and long parameter starts plus rectangular Fisher matrices at every
  affected export; the helper tests cover multi-column auxiliary designs and
  the generalized likelihood.
- [ ] **TODO-5: Validate the rebuilt native artifact.** After the user rebuilds,
  run `test-mixed-kernel-warm-start-shape-guards-reference.R`, the existing
  ZOIB input-validation tests, and the affected kernel-equivalence tests.
- [ ] **TODO-6: Repeat memory-safety validation.** Run the focused file in the
  ASAN/UBSAN and valgrind jobs, then regenerate and reconcile the installed
  comprehensive CSV. These checks inherently require rebuilt native code.
