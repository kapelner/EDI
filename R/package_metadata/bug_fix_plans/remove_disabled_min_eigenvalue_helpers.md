# Remove disabled minimum-eigenvalue helper code

**Release target:** v1.0.5 TODO-51.

The two native helper templates were deliberately disabled because false
non-convergence is common and enabling them imposed an extra Hessian build and
eigendecomposition on many fits. Their bodies contained no executable
diagnostic logic, yet every generic optimizer and seven hand-written fitters
still called them.

The no-op helpers, their unused SFINAE trait, and all call sites are removed.
The `min_eigenvalue_information` result fields remain because they are part of
the R/Python result schema and several specialized kernels may populate their
own diagnostics. Generic results retain the documented `NaN` default. This is
therefore an internal cleanup with no result or numerical-behavior change.

## TODOs

- [x] Audit exact helper and call-site reachability.
- [x] Remove both disabled helper templates, the unused trait, and all calls.
- [x] Preserve the public result-field contract and its `NaN` default.
- [ ] After the user rebuilds, run the affected kernel output-contract and
  equivalence tests. No source-loaded test can execute this header change.
