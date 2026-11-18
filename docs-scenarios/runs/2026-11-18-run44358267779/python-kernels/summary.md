# Summary: python-kernels run, 2026-11-18

## What I set out to do
I wanted to act as a Python user fitting EDI's kernels without R. On simulated data (numpy,
seed 20261118, n = 157, unequal arms, 0/1-coded `w`, two covariates, tied survival times)
the plan was to fit OLS (`fast_ols`), logistic (`fast_logistic_regression`, with and without
`weights`), Cox (`fast_coxph_regression`) and Poisson (`fast_poisson_regression`) models. For
each one I would read off the treatment estimate and its SE, build the Wald CI and p-value,
and cross-check against statsmodels and lifelines to 3 digits. After that I planned to probe
the documented options and edge cases: no intercept column, `w` coded 1/2 or -1/1,
`estimate_only`, `set_checks(False)`, small n and separation.

## What I finished
- I read the README, the article "EDI from Python" and the `_core.pyi` stub. The stub lists
  63 unique functions (64 `def`s, because `fast_pchisq_upper` has an overload), which
  matches the article's count.
- `analysis.py` simulates the data and computes the reference fits. statsmodels OLS gives
  treatment estimate 0.718914 (SE 0.165550). GLM logit gives 0.770296 (0.344825). Weighted
  logit gives 0.786313 (0.312527). Poisson gives 0.290071 (0.136865). lifelines Cox (Efron
  ties) gives 0.736215 (0.194693). The script then tries the edi_kernels fits in a child
  process.

## What I could not do and why
- **No edi_kernels call could be made.** `import edi_kernels` (and `import edi_kernels._core`)
  dies with SIGILL, exit code 132, on this AMD EPYC 7763 CPU, which has AVX2 but no AVX-512
  (F1). So there are no cross-checks, no option or edge-case probing, and `help()` cannot be
  run either. All documentation reading was done on the `.pyi` stub and the context files.
- I did not try workarounds such as loading `_checks.py` directly by file path. That is
  undocumented, and the compiled kernels would still be missing.

## Decisions and guesses (unattended run)
- I treated the import crash as a blocking finding rather than an environment fluke. It
  happens 3 times out of 3, and the other compiled packages in the venv (numpy,
  scipy_openblas32) work on the same CPU. That the cause is a host-specific build (AVX-512 /
  `-march=native`) is a guess; I did not inspect the binary.
- The repros are bash/Python instead of R, because the area is the Python package.
- Cox reference: I used lifelines (Efron ties), since the EDI docs do not state a tie method
  (F3).

## Known findings re-checked
None. known_findings.md lists no earlier findings for this area.
