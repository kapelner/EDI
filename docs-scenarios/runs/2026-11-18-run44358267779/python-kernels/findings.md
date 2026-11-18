# Findings: python-kernels (edi_kernels 1.0.4)

Note on repros: this area is the Python package, so the repros are Python/bash scripts
run with the venv interpreter rather than R scripts starting with `.libPaths()`. They
simulate any data they need with numpy and a fixed seed.

### F1: `import edi_kernels` kills the Python interpreter with SIGILL ("Illegal instruction", exit code 132) on an AVX2-only x86-64 CPU, so no kernel can be called
- Kind: documented option fails
- Expected: the README's "Install" and "Usage" sections and the article "EDI from Python" (sections "Installing" and "What the Python package covers") say `pip install edi_kernels` and then `import edi_kernels as ek` gives 63 callable kernels. The wheel is tagged `cp312-cp312-linux_x86_64`, a generic x86-64 tag, and no CPU requirement is documented. The import should succeed on any x86-64 CPU, or the docs should name the required instruction set. At worst the import should raise a Python `ImportError`, not kill the process.
- Observed: on an AMD EPYC 7763 (numpy reports AVX, AVX2 and FMA3 present, and every AVX512* feature absent), the import crashes the process. The failing step is the load of the compiled extension `edi_kernels._core` (`_core.cpython-312-x86_64-linux-gnu.so`):
  ```
  $ /home/runner/work/_temp/venv/bin/python -X faulthandler -c "import edi_kernels"
  Fatal Python error: Illegal instruction
  ...
    File "<frozen importlib._bootstrap_external>", line 1293 in create_module
    ...
    File ".../site-packages/edi_kernels/__init__.py", line 19 in <module>
  Illegal instruction (core dumped)      # exit status 132
  ```
  `python -c "import edi_kernels._core"` crashes the same way. It fails 3 times out of 3. In the same venv, `import scipy_openblas32` (the declared BLAS dependency), numpy, scipy, statsmodels and lifelines all import fine. The most likely cause is that the wheel was built with host-specific flags (for example `-march=native` on an AVX-512 machine). That is an inference; I did not read source or disassemble the binary.
- Repro:
  ```bash
  # bash; no data needed
  /home/runner/work/_temp/venv/bin/python -c "from numpy._core._multiarray_umath import __cpu_features__ as f; print('AVX2', f['AVX2'], 'AVX512F', f['AVX512F'])"
  /home/runner/work/_temp/venv/bin/python -X faulthandler -c "import edi_kernels; print('imported OK')"; echo "exit=$?"
  # observed: AVX2 True AVX512F False ; "Fatal Python error: Illegal instruction" ; exit=132
  ```
- Workaround used, if any: none possible without rebuilding, which this run is not allowed to do. Every model fit and cross-check in the task is blocked. `analysis.py` runs the kernels in a child process so the crash is caught; it still computes the statsmodels/lifelines reference values for the next run.

### F2: The README and the article contradict each other on whether the kernels check that `w` is 0/1
- Kind: inconsistency
- Expected: one consistent statement. README "Usage > Input checks" says: "Every kernel checks its inputs ... The checks cover ... 0/1 treatment and event vectors (`w`, `dead`) ... Recode a 1/2 or -1/1 treatment vector to 0/1 first. Before these checks, such a vector gave a silent `nan` or a sign-flipped estimate". It adds that the 0/1 checks "still run" under `set_checks(False)`.
- Observed: the article "EDI from Python", section "Differences to watch > Treatment coding", says the Python kernels that take a treatment vector (`wilcox_hl_point_estimate`, `get_survival_stat_diff`, `fast_logrank_stats`, `fast_ridit_analysis`, and others) "expect 0/1 with 1 = treatment. They do not check it." So a user cannot tell from the docs whether a 1/2-coded `w` raises an error or silently returns a wrong answer. I could not settle it at runtime because of F1. The README example (`fast_logrank_stats([1, 2, 3.5, 4], [1, 1, 1, 1], [1, 2, 1, 2])` raising `ValueError`) is the test to run once the import works. `set_checks`/`get_checks` also have no signature or docstring in the `_core.pyi` stub; only the README mentions them.
- Repro:
  ```bash
  cd /home/runner/work/_temp/scenario/python-kernels
  grep -n "They do not check it" context/articles/edi-from-python.Rmd
  grep -n "treatment and event vectors" context/python/README_PYPI.md
  grep -c "set_checks" /home/runner/work/_temp/venv/lib/python3.12/site-packages/edi_kernels/_core.pyi   # 0
  ```
- Workaround used, if any: none; I would recode `w` to 0/1 myself in either case.

### F3: The `fast_coxph_regression` docstring does not say how tied event times are handled (Breslow or Efron), so a 3-digit cross-check against lifelines/statsmodels cannot be set up from the docs
- Kind: insufficient docs
- Expected: a Cox kernel's docs should name its partial-likelihood tie approximation. lifelines `CoxPHFitter` uses Efron, R `survival::coxph` defaults to Efron, and statsmodels `PHReg` defaults to Breslow. With tied times (any rounded follow-up) the estimate and SE differ in the 2nd to 3rd digit depending on the method.
- Observed: the stub docstring ("Fast Cox proportional-hazards regression via Newton-Raphson (unstratified, no cluster-robust vcov). No R-side roxygen documents this raw kernel directly ...") and its Parameters section never mention ties. Neither do the README's Survival section or the article's Task 4. `fast_stratified_coxph_regression` has the same gap. In my simulated data (n = 157, times rounded to 0.1, so many ties), lifelines (Efron) gives a treatment log-HR of 0.736215 with SE 0.194693. I could not check which method EDI matches because of F1.
- Repro:
  ```bash
  S=/home/runner/work/_temp/venv/lib/python3.12/site-packages/edi_kernels/_core.pyi
  sed -n '/^def fast_coxph_regression/,/^def /p' $S | grep -ciE "tie|breslow|efron"            # 0
  sed -n '/^def fast_stratified_coxph_regression/,/^def /p' $S | grep -ciE "tie|breslow|efron" # 0
  ```
- Workaround used, if any: for the next run, `analysis.py` keeps both references available: lifelines (Efron), and statsmodels `PHReg(ties="breslow")` can be added.
