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

- [ ] TODO-1: **Complete the audit.** List every `warm_start_*` and
  `fixed_values`/`fixed_idx` dereference in `src/` with its guard status
  (the F2 table plus the weights/Fisher-information sites), and check
  whether `python/cpp/bindings_*.cpp` validates lengths before calling
  the kernels. Record the table in this file.

- [ ] TODO-2: **One helper, used everywhere.** Add to
  `_helper_functions_core.h` an inline
  `require_length(const std::optional<Eigen::VectorXd>&, Eigen::Index expected, const char* what)`
  (and a matrix variant for Fisher information) that throws
  `std::invalid_argument("<what> must have length <expected>")`, which
  Rcpp turns into an R error. Call it at every unguarded site from
  TODO-1. The check must run **before any OpenMP region** (a C++
  exception inside a parallel region terminates R; same rule as the
  2026-09-21 robust `method` check). Make `apply_fixed_values` itself
  bounds-check `fixed_idx` against `params.size()`.

- [ ] TODO-3: **Regression test.** `R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R`:
  for every exported kernel that takes `warm_start_beta` (enumerate from
  `RcppExports.R`), call it with a too-short, a too-long and a length-1
  warm start on a small fixture and `expect_error(..., "must have
  length")`; then `gc()` and assert the session is alive (the test
  itself is the assertion: a crash fails the file). Also one case per
  kernel for `warm_start_weights` and `warm_start_fisher_info` where
  present. The test must run in the `R-CMD-check-sanitizers` (ASAN/UBSAN)
  and `R-CMD-check-valgrind` jobs of `.github/workflows/R-CMD-check.yaml`,
  which would have caught F1 directly.

- [ ] TODO-4: **Verify by targeted compile.** Recompile only the touched
  `.cpp` files with the flags from `src/Makevars`, relink `EDI.so` from
  the existing `.o` files, load with `pkgload::load_all(compile = FALSE)`,
  run TODO-3 and the kernel-equivalence tests. Bit-preserving by
  construction: the change only rejects inputs that were undefined
  behavior before. `NEWS.md` entry under bug fixes.

- [ ] TODO-5: **Python bindings.** If TODO-1 finds the bindings pass
  lengths through unchecked, the C++ fix covers them once the wheels are
  rebuilt; add a matching pytest that a wrong-length warm start raises a
  Python exception rather than crashing the interpreter.

## Out of scope

- Any change to how warm starts are chosen or used when the length is
  right.
