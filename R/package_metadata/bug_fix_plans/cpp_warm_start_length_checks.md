# C++ Kernels Accept a `warm_start_beta` of the Wrong Length and Corrupt the Heap

> **Depends on:** nothing. Touches six `src/` kernels (sites listed under
> F2), one shared inline helper in `src/_helper_functions_core.h`, and one
> new testthat file. Independent of every item in `release_v1_0_5.md` and
> `release_v1_1_0.md`. Verify by **targeted compile of the touched `.cpp`
> files only** and a relink (top-level `CLAUDE.md`; never a full rebuild).
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-63`).

Written 2026-10-07, user decision. Found by accident while profiling the
2026-10-07 benchmark extension against the installed CRAN EDI 1.0.2: a
profiling script called the logistic kernel with a bare `TRUE` as its
third positional argument and the R session segfaulted in the next
`gc()`. Memory-safety bug, so a correctness item under the 2026-09-23
split rule even though no R6 code path reaches it today.

## Findings

**F1. Reproduction (installed 1.0.2, deterministic).**

```r
X = cbind(1, rbinom(200, 1, 0.5), matrix(rnorm(800), 200, 4)); y = rbinom(200, 1, 0.5)
EDI:::fast_logistic_regression_cpp(X, y, TRUE)   # TRUE -> warm_start_beta of length 1, p = 6
gc()                                             # exit code 139
```

Also fails with `warm_start_beta = 0.1` (length 1), passes with
`rep(0, 6)`. A single call is enough. `fast_logistic_regression.cpp:90–91`
does `if (warm_start_beta.has_value()) beta = *warm_start_beta;` with no
length check; `beta` is then a length-1 vector in a p = 6 solve. With
Eigen's asserts compiled out (`NDEBUG`), the mismatched products write
outside their allocations.

**F2. Source audit of every `warm_start_beta` dereference in `src/`
(2026-10-07).** Unguarded:

| Kernel | Site | Failure shape |
|---|---|---|
| `fast_logistic_regression.cpp` | L91 `beta = *warm_start_beta` | resizes `beta` to the wrong length; UB in every later product |
| `fast_poisson_regression.cpp` | L106–107 (`size() > 0` only) | same, for any non-empty wrong length |
| `fast_coxph_regression.cpp` | L270–271 and L454–455 (`for q < p: beta[q] = sb[q]`) | out-of-bounds read when shorter; silently ignores extra entries when longer |
| `fast_beta_regression.cpp` | L232 `params.head(p) = *warm_start_beta` (reached from the three exports via `sb_ptr`, L438/533/628) | block assignment with mismatched size: heap write overflow |
| `fast_robust_regression.cpp` | L106–107 `apply_fixed_values(*warm_start_beta, fixed_spec)` then `subset_vector(..., free_idx)` | `apply_fixed_values` (`_helper_functions_core.h:609`) indexes `params[fixed_idx[i]]` without a bounds check |

Guarded (explicit size check or branch on size): probit (L111–113),
log-binomial and identity-binomial (L173–174, L356–357), continuation
ratio (L179–180), GEE (L136), ordinal GLMM (L303–306), Gaussian LMM
(L428–431), clogit+GLMM (L544–547), Weibull frailty (L335–338),
stereotype logit (L707–710, L1183–1186), combined conditional Poisson
(L290–293), adjacent-category logit (L222–225).

A first-pass grep of the 39 `warm_start_weights` / `warm_start_fisher_info`
dereferences found an adjacent size check at only 11 of them (robust
regression checks both, L177 and L194). TODO-1 audits those precisely.

**F3. Exposure.** Every R6 caller sizes warm starts through
`private$get_fit_warm_start_for_length()` (`inference_all_abstract.R:725`),
so the R6 API is safe. Direct callers are not: tests, benchmarks, scratch
scripts, and the Python bindings, which pass `warm_start_beta` through in
eight `python/cpp/bindings_*.cpp` files (whether the binding layer checks
lengths is part of TODO-1).

## TODOs

- [x] TODO-1: **Complete the audit.** List every `warm_start_*` and
  `fixed_values`/`fixed_idx` dereference in `src/` with its guard status
  (the F2 table plus the weights/Fisher-information sites), and check
  whether `python/cpp/bindings_*.cpp` validates lengths before calling
  the kernels. Record the table in this file. **Partial source audit
  2026-10-09:** all eight binding families accept `std::optional<Eigen::...>`
  and forward it without dimensional validation, so the native boundary is
  the required common protection. The original F2 five-kernel cluster has
  now been guarded; the broader weights/Fisher-information inventory is
  still open.

  Follow-up indexed source inventory, 2026-10-15: `warm_start_fisher_info`
  has 38 direct dereference hits across 37 symbols in 31 C++ source files.
  Six internals call `require_square_matrix()`; 11 other functions contain
  explicit dimension/finite-value rejection (with `fast_robust_regression`
  appearing in both groups), and GEE has a dimension-mismatch fallback.
  The remaining Fisher-start paths still need individual classification.
  `warm_start_weights` has three direct-dereference internals: logistic,
  Poisson, and robust use the shared length helper; weighted constrained
  binomial has an explicit row-count check. Probit documents the argument as
  unused, and the unweighted constrained-binomial path accepts but does not
  consume it. This is not yet the required full `warm_start_*` plus
  `fixed_values`/`fixed_idx` inventory; TODO 1 remains open.

  Follow-up source audit and guard pass, 2026-10-16: the existing shared
  `require_square_matrix()` helper was added at the remaining unsafe Fisher
  start entry points: ordinal cauchit, stereotype logit, continuation-ratio,
  adjacent-category, both Weibull regression paths, ordinal probit, ordinal
  CLMM, ordinal logit, ZINB, clogit+GLMM, Clayton-Weibull, dependent-censoring
  transform, and negative-binomial regression. The Clayton-Weibull path also
  now rejects a parameter start whose length is not `ncol(X) + 2` before
  constructing the objective. The CRAN contract test now asserts malformed
  Fisher dimensions are rejected through each affected exported kernel.
  R parsing and `git diff --check` were run; the latter reports pre-existing
  trailing whitespace in the concurrently modified bulk-test manifest, which
  was not changed here. No compile/install was run, so checkout behavior and
  sanitizer/Valgrind validation remain pending; TODO 1 and TODO 4 stay open.

- [x] TODO-2: **One helper, used everywhere.** Add to
  `_helper_functions_core.h` an inline
  `require_length(const std::optional<Eigen::VectorXd>&, Eigen::Index expected, const char* what)`
  (and a matrix variant for Fisher information) that throws
  `std::invalid_argument("<what> must have length <expected>")`, which
  Rcpp turns into an R error. Call it at every unguarded site from
  TODO-1. The check must run **before any OpenMP region** (a C++
  exception inside a parallel region terminates R; same rule as the
  2026-09-21 robust `method` check). Make `apply_fixed_values` itself
  bounds-check `fixed_idx` against `params.size()`. **Source implementation
  2026-10-09:** `require_length` (optional and pointer forms) and
  `require_square_matrix` now guard the logistic, Poisson, Cox (both
  optimizer paths), beta, and robust internal entry points before optimizer
  or OpenMP work. `apply_fixed_values` now verifies its parallel index/value
  vectors and each index. This is source-complete for F2 but awaits TODO-4's
  authorized targeted compile. **Dispatch correction 2026-10-11:**
  `cox_fit()` now forwards `warm_start_fisher_info` to its LBFGS branch;
  previously that branch silently discarded the supplied matrix before its
  otherwise-present guard could validate it. The contract test now covers
  this branch too. This source correction remains unexecuted.

- [ ] TODO-3: **Regression test.** `R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R`:
  for every exported kernel that takes `warm_start_beta` (enumerate from
  `RcppExports.R`), call it with a too-short, a too-long and a length-1
  warm start on a small fixture and `expect_error(..., "must have
  length")`; then `gc()` and assert the session is alive (the test
  itself is the assertion: a crash fails the file). Also one case per
  kernel for `warm_start_weights` and `warm_start_fisher_info` where
  present. The test must run in the `R-CMD-check-sanitizers` (ASAN/UBSAN)
  and `R-CMD-check-valgrind` jobs of `.github/workflows/R-CMD-check.yaml`,
  which would have caught F1 directly. **Coverage audit 2026-10-17:**
  enumerating `RcppExports.R` shows 38 exported wrappers with
  `warm_start_beta`, 17 with `warm_start_weights`, and 63 with
  `warm_start_fisher_info`; this contract test currently exercises only
  38/38, 17/17, and 19/63 unique wrappers respectively (20 Fisher call cases
  because Cox is checked under two optimizer modes). Of the 17 weight
  wrappers, 10 validate
  consumed starts and reject a wrong row count; the remaining four unweighted
  constrained-binomial wrappers and three probit wrappers accept but do not
  consume the argument, so the test asserts identical results with a malformed
  vector and with no start. The coefficient fixture has three columns so
  length 1, a non-one short length, and a long length are distinct. Full
  At that 2026-10-17 snapshot, Fisher-wrapper coverage and sanitizer/Valgrind
  execution remained open.

  Static source audit on 2026-10-17 found additional silent-ignore paths:
  adjacent-category (including with-variance), continuation-ratio (including
  weighted/with-variance and the no-augmented-row return), Gaussian LMM, GEE
  pair/singleton, stereotype logit/profile, ordinal GLMM, clogit+GLMM,
  combined conditional-Poisson, and Weibull frailty. Their internal entry
  points now reject unsupported lengths before copying/using the starts;
  combined-model APIs preserve their supported beta-only and full-parameter
  dimensions. The Gaussian LMM fixture uses only supported pair-sized groups.
  These checkout C++ edits are not compiled.

  Final warm-start source audit, 2026-10-18: exhaustive searches of C++
  entry-point accesses, conditional size checks, copies, indexing and caller
  paths found two additional `warm_start_params` branches that silently
  discarded malformed non-null vectors in favor of a cold start:
  `fast_ordinal_clmm_internal` and `fast_dep_cens_transform_optim_internal`.
  Both now call `require_length(..., total, "warm_start_params")` before
  initializing the start vector, and copy only after that guard. Each internal
  is called by both the R and Python binding. The warm-start portion of the
  source audit is complete; TODO-1 remains open only for its separate
  exhaustive `fixed_values`/`fixed_idx` inventory. No other consumed
  warm-start input was found to have an unchecked or silent-ignore path;
  documented unused weight arguments remain no-ops.

  Fixed-parameter source audit, 2026-10-18: `trail grep` enumerated all 78
  `make_fixed_param_spec(` call sites (72 symbols, 34 C++ files) and all 27
  `fixed_idx[` / 19 `fixed_values[` indexed-access hits. The hits are
  `apply_fixed_values` (`_helper_functions_core.h:651-662`),
  `fast_poisson_internal` (`fast_poisson_regression.cpp:177,308`),
  constrained-binomial unweighted/weighted fits (`fast_log_binomial_regression.cpp:169,353`),
  logistic (`fast_logistic_regression.cpp:103`), probit
  (`fast_probit_regression.cpp:126`), Cox Newton-Raphson
  (`fast_coxph_regression.cpp:337,354`), robust
  (`fast_robust_regression.cpp:92,135`), combined conditional Poisson
  (`fast_cpoisson_combined.cpp:305,422`), logistic/ordinal/Poisson GLMM
  (`fast_logistic_glmm.cpp:526`, `fast_ordinal_glmm.cpp:348`,
  `fast_poisson_glmm.cpp:415`), OLS and OLS-with-variance
  (`fast_ols.cpp:26,31,108,113`), and ZINB/ZIP reduced fallbacks
  (`fast_zinb.cpp:462,476,479,582-584`). Each receives a validated
  `FixedParamSpec` from the shared helper at `_helper_functions_core.h:517-581`
  or a filtered copy of such a spec; the helper checks paired presence for
  nonempty indices, equal lengths, one-based range, duplicates, finite values,
  and at least one free parameter. The R adapter
  (`_helper_functions.h:60-73`) and Python lambdas forward optionals without
  pre-validation, so this common native validation is the boundary for both.
  `apply_fixed_values()` independently checks index/value lengths and every
  target index before assignment. No unchecked external fixed-parameter access
  was found, so no new native guard or malformed-input regression is justified.
  The scan did identify two Python docstrings claiming `fast_ols` and
  `fast_robust_regression` use zero-based `fixed_idx`; both bindings forward
  directly to the one-based helper. The C++ binding docs and generated
  `python/src/edi_kernels/_core.pyi` now state one-based. This is a docs-only
  correction. No build, install, or runtime test was run; native/Python
  extension validation remains under TODO-4/TODO-5.

  Contract note: the shared helper returns the all-free spec immediately when
  `fixed_idx` is absent or empty, so an independently supplied `fixed_values`
  vector is currently ignored (not indexed). This is not an unsafe access;
  changing that no-op behavior would be a separate API-contract decision.

  TODO-1 source inventory is complete. Validation requiring a checkout-native
  library or rebuilt Python extension remains intentionally assigned to
  TODO-4/TODO-5, not this source-audit checkbox.

- [ ] TODO-4: **Verify by targeted compile.** Recompile only the touched
  `.cpp` files with the flags from `src/Makevars`, relink `EDI.so` from
  the existing `.o` files, load the rebuilt package without source-loading,
  run TODO-3 and the kernel-equivalence tests. Bit-preserving by
  construction: the change only rejects inputs that were undefined
  behavior before. `NEWS.md` entry under bug fixes.

  Installed-package check on 2026-10-14: the CRAN-shipped
  `test-kernel-warm-start-length-contracts.R` passed all 20 assertions under
  EDI 1.0.3. This confirms the installed boundary rejects the tested malformed
  starts without terminating R, but does not validate the current checkout's
  C++ edits or sanitizer behavior; targeted compile/link and sanitizer runs
  remain pending explicit permission.

  Installed-package recheck on 2026-10-17: the expanded file parses, and
  export enumeration confirms 38/38 beta-taking wrappers have malformed-start
  cases. Running against `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`
  (EDI 1.0.3) yields 107 pass / 46 fail / 0 warnings. Failures are current-
  checkout versus installed-native discrepancies for guarded paths, including
  adjacent-category, continuation-ratio's normalized error and degenerate-
  response guard, GEE, combined models, ordinal/stereotype models, and Weibull
  frailty; this installed binary is not evidence for the checkout. No local
  compile/build/install was run. TODO-3 remains open pending execution against
  a rebuilt package and sanitizer/Valgrind CI evidence.

  Fisher-info completion audit, 2026-10-18: the CRAN contract test now has a
  malformed-matrix invocation for every one of the 63 R wrappers whose
  signature accepts `warm_start_fisher_info`. Shared internals are exercised
  at each wrapper boundary, including both Cox optimizer branches. The three
  ordinary probit wrappers reject a malformed matrix on IRLS; under their
  documented `optimization_alg = "lbfgs"` path, which bypasses IRLS and does
  not consult this argument, the test asserts result identity against `NULL`.
  The 17/17 weight-wrapper assertions remain: consuming implementations reject
  wrong lengths, while documented unused constrained-binomial and probit
  weight arguments are tested as no-ops.

  The expanded audit added source guards for ordinary probit (p-by-p before
  IRLS setup, only on the consuming path), ordinal cloglog (threshold-plus-beta
  dimension before its degenerate-level return), GEE pair/singleton (p-by-p
  instead of silently falling back), both constrained-binomial implementations
  (p-by-p before using or falling back), and continuation-ratio (augmented
  dimension before the zero-augmentation return). Existing ordinal, ZINB,
  hurdle/truncated NB, GLMM, zero-augmented, zero-one-inflated-beta, survival,
  and mixed-model guards were classified by shared internals; dimensions
  include model-specific thresholds, dispersion, random-effect terms, and
  cpoisson's `p + 2` form where applicable. Static review only: no checkout
  C++ compile, install, sanitizer, or Valgrind run has occurred.

  Focused installed-package rerun after the 2026-10-18 expansion used
  `testthat::test_file("R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R", package = "EDI")`
  against EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`: 140 passed,
  60 failed, 0 warnings. The additional matrix cases exposed no invocation or
  fixture errors after correcting truncated-NB input to strictly positive
  counts. New guard expectations that fail against this old installed binary
  are the four constrained-binomial unweighted wrappers, two ordinal-cloglog
  wrappers, three probit IRLS wrappers (old binary reaches `subset_matrix`
  instead of the named dimension guard), and zero-augmented Poisson. Existing
  beta/continuation and other checkout-native guard expectations also remain
  stale-binary failures. This run verifies only fixture reachability and the
  documented probit L-BFGS/no-op equivalences; it does not validate checkout
  source. The edited test parses and `git diff --check` is clean. No local
  build/install occurred; TODO-3/TODO-4 and sanitizer/Valgrind gates remain
  open.

  Warm-start follow-up, 2026-10-18: the CRAN contract file now also asserts
  that short and long parameter starts are rejected by the ordinal CLMM and
  dependent-censoring transform kernels. Matching pytest cases assert Python
  `ValueError` for short and long vectors through `fast_ordinal_clmm` and
  `fast_dep_cens_transform_optim`. The four R and four Python malformed-length
  cases cover the two newly guarded paths; they have not been executed against
  the checkout native library or a checkout-built Python extension. The
  exhaustive warm-start source audit is complete, but TODO-3 runtime,
  sanitizer, and Valgrind evidence remains open pending an authorized rebuild.

- [ ] TODO-5: **Python bindings.** If TODO-1 finds the bindings pass
  lengths through unchecked, the C++ fix covers them once the wheels are
  rebuilt; add a matching pytest that a wrong-length warm start raises a
  Python exception rather than crashing the interpreter. **Compile-free
  smoke 2026-10-14:** the matching regression already exists at
  `python/tests/test_fast_logistic_regression.py::test_wrong_length_warm_start_beta_raises_value_error`;
  it passed (`1 passed in 0.29s`) using
  `python/.venv/bin/python -m pytest -q` against the existing extension at
  `python/.venv/lib/python3.14/site-packages/edi_kernels/_core.cpython-314-x86_64-linux-gnu.so`.
  No build/install was run. This confirms the existing binary's logistic
  binding behavior only; the wheel/build provenance is not tied to the
  current C++ checkout edits, so rebuild-backed Python validation remains
  open. **Additional Python coverage, 2026-10-18:** short/long malformed-
  length `ValueError` regressions were added to
  `python/tests/test_fast_ordinal_clmm.py` (expected vector length 5) and
  `python/tests/test_fast_dep_cens_transform_optim.py` (expected vector
  length 7). No pytest run used the stale extension. After an authorized
  checkout extension rebuild/install, run:
  `python -m pytest python/tests/test_fast_ordinal_clmm.py python/tests/test_fast_dep_cens_transform_optim.py`.
  This gate remains open until that command passes against the rebuilt
  extension; no extension was built or installed in this audit.

## Out of scope

- Any change to how warm starts are chosen or used when the length is
  right.
