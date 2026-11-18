## Covered
- Import of edi_kernels 1.0.4 (a locally built cp312 linux_x86_64 wheel) on an AVX2-only AMD EPYC 7763 crashes with SIGILL (exit code 132). Check with `python -c "import edi_kernels"` before planning anything else.
- Static review of the `_core.pyi` stub against the README and the article "edi-from-python" (function count, index conventions, `estimate_only` defaults, w-check claims, Cox tie handling).
- The statsmodels/lifelines reference values for the analysis.py simulation are already computed (seed 20261118).

## Not reached
- Everything at runtime: the fast_ols, logistic (with weights), Cox and Poisson cross-checks in analysis.py are ready to run as soon as the import works.
- w coded 1/2 or -1/1 in `fast_logrank_stats` / `wilcox_hl_point_estimate` / `get_survival_stat_diff` (does it raise ValueError as the README says, or not, as the article says?), and the same under `set_checks(False)`.
- `fast_ols` called with `estimate_only` left at its default (True): does `XtWX` go missing? Also `fixed_idx`/`fixed_values`.
- Is `ssq_b_j` really nan for logistic, as the article says? Check `fast_logistic_regression` `weights` against statsmodels `var_weights` and `freq_weights`.
- Cox ties: compare against lifelines (Efron) and statsmodels `PHReg(ties="breslow")`.
- `fast_robust_regression`'s `j`: the stub says it "currently has no effect"; the article lists it as a 1-based position argument.

## Workarounds
- Run every edi_kernels call in a subprocess (see analysis.py), so a native crash does not take the test script down with it.
- Check CPU features with `numpy._core._multiarray_umath.__cpu_features__`; reading /proc/cpuinfo was denied.

## Confusing docs
- README "Input checks" (w is checked) vs the article "Differences to watch" (w is "not checked").
- `set_checks`/`get_checks` are in the README but not in the `.pyi` stub.
- The README says `estimate_only=False` is "the default on most kernels", but `fast_ols` defaults to True. The README examples pass it explicitly, so this is easy to miss.
- `fixed_idx` is documented as 1-based for fast_ols and fast_coxph, but the logistic and Poisson docstrings just say "Optional indices", without the base.
