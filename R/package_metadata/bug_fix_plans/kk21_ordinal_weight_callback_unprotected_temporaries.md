# KK21 Ordinal Weight Kernels: Unprotected `wrap()` Temporaries in the R Callback Can Be Garbage-Collected Mid-Call

> **Depends on:** nothing. Touches one static helper in `src/kk21_weights.cpp`
> (`multivariate_ordinal_tstat`, ~L1233–1243) that both ordinal weight kernels
> call, plus one new testthat file. Independent of every item in
> `release_v1_0_5.md` and `release_v1_1_0.md`. Verify by **targeted compile of
> `kk21_weights.cpp` only** and a relink (top-level `CLAUDE.md`; never a full
> rebuild). **Release target: v1.0.5** (`release_v1_0_5.md → TODO-65`).

Written 2026-10-08, user decision. Found while measuring how much the
`DesignSeqOneByOneKK21` `*_use_speedup` OLS-on-transform weight approximation
loses against the full per-covariate GLM weights (answer: nothing measurable;
recorded in the class's roxygen Details). The end-to-end ordinal arm of that
study, run with `ordinal_use_speedup = FALSE`, hard-crashed R three times out of
three on a stable install, yet a same-seed rerun (and a second rerun of the
identical script) completed all 150 replications. Same inputs, different
outcome: a garbage-collection-timing bug, not a data bug. Memory-safety bug, so
a correctness item under the 2026-09-23 split rule even though the affected
path is non-default.

## Findings

**F1. The crash (installed 1.0.2, `ordinal_use_speedup = FALSE`, n = 200,
4 ordinal levels, 8 covariates, 150 design replications).** Three of five
runs aborted with

```
Error: Not compatible with requested type: [type=NULL; target=double].
 *** caught segfault ***
address 0x652e537bab18, cause 'memory not mapped'
Traceback:
 1: kk21_ordinal_weights_cpp(as.matrix(xs), as.numeric(ys))
 2: private$compute_weights(all_subject_data)
 3: self$assign_wt()
```

The three crashes happened while three other R processes were running
concurrently; the two clean runs were nearly alone on the machine. The
install was stable throughout (last reinstall finished before any of the
runs started), so this is not the reinstall-flapping explanation.

**F2. Root cause.** `multivariate_ordinal_tstat` is the only `Rcpp::Function`
callback in `src/`. It hands two fresh, unprotected `wrap()` temporaries
straight to `Function::operator()`:

```cpp
// src/kk21_weights.cpp, multivariate_ordinal_tstat, ~L1238–1239
Function f("fast_ordinal_regression_with_var_cpp");
List res = f(wrap(X), wrap(y));
```

`wrap(X)` allocates a `NumericMatrix` SEXP that nothing protects; `wrap(y)`
then allocates again and can trigger a collection that frees the first. Only
inside `Function::operator()` does Rcpp shield the arguments, which is too
late. When the collected `X` SEXP is reused, the callee's `.Call` wrapper
sees garbage: a header that reads as `NILSXP` gives exactly the "Not
compatible with requested type: [type=NULL; target=double]" error seen in
F1; other reuse patterns give NaN results or a segfault.

**F3. Proof (installed 1.0.2, deterministic under `gctorture`).**

```r
set.seed(404); n = 40; p = 3; X = matrix(rnorm(n * p), n, p)
y = as.numeric(cut(0.8 * X[, 1] + rlogis(n), c(-Inf, -1.2, 0, 1.2, Inf), labels = FALSE))
EDI:::kk21_ordinal_weights_cpp(X, y)                      # 2.357 0.857 0.181
gctorture(TRUE); EDI:::kk21_ordinal_weights_cpp(X, y); gctorture(FALSE)   # NaN NaN NaN  (3/3 runs)
gctorture(TRUE); r = fast_ordinal_regression_with_var_cpp(X[, 1, drop = FALSE], y); gctorture(FALSE)
abs(r$b[1] / sqrt(r$ssq_b_j))                             # 2.357: the callee itself is GC-safe
```

A standalone `Rcpp::sourceCpp` reproduction of the identical pattern
(`List res = f(wrap(X), wrap(y))` with Eigen arguments, calling a trivial R
function) errors under `gctorture(TRUE)` with "unimplemented type (27) in
'eval'"; the variant that first holds the wrapped values in Rcpp objects
returns the correct value under `gctorture`. Ruled out along the way: a bare
`catch (...)` swallowing an Rcpp longjump (a sourceCpp demo of that pattern
survives under Rcpp 1.1.2) and install flapping (F1).

**F4. Blast radius.** Both ordinal weight kernels route through the helper:
`kk21_ordinal_weights_cpp` (~L1266) behind `DesignSeqOneByOneKK21` with
`ordinal_use_speedup = FALSE`, and `kk21_stepwise_ordinal_weights_cpp`
(~L1314) behind `DesignSeqOneByOneKK21stepwise` with the same flag. The
default `ordinal_use_speedup = TRUE` never enters the helper. No other
kernel in `src/` calls back into R. Symptoms in the wild: rare silent NaN
weights (which the design then normalizes and feeds into the weighted
distance), R errors, or a segfault, all nondeterministic.

## Items

- [ ] **TODO-1: Protect the temporaries.** In `multivariate_ordinal_tstat`,
  hold the wrapped arguments in Rcpp objects before the call:
  ```cpp
  NumericMatrix Xs = wrap(X);
  NumericVector ys = wrap(y);
  List res = f(Xs, ys);
  ```
  Bit-preserving: identical arithmetic, only the undefined behavior goes
  away. Verify by targeted compile of `kk21_weights.cpp` and a relink, then
  rerun the F3 snippet: the `gctorture` call must return `2.357 0.857 0.181`.
- [ ] **TODO-2: Sweep `src/` for the same shape.** Grep every
  `Rcpp::Function` / `Function` call site for inline `wrap(...)` or other
  freshly allocated SEXP arguments (today this helper is the only callback,
  so the sweep should come back empty; record that in the test from
  TODO-3 as a static check so a future callback cannot reintroduce it).
- [ ] **TODO-3: Regression test** (new
  `R/EDI/tests/testthat/test-kk21-ordinal-weight-kernel-gc-safety.R`):
  on the F3 fixture, assert that `kk21_ordinal_weights_cpp` and
  `kk21_stepwise_ordinal_weights_cpp` under `gctorture(TRUE)` return finite
  weights equal (to 1e-10) to their non-`gctorture` results and to
  `abs(b / sqrt(ssq_b_j))` from the direct callee; wrap in
  `on.exit(gctorture(FALSE))`. Keep the fixture tiny (n = 40, p = 3) since
  `gctorture` is slow. Add the static grep from TODO-2 to the same file.
- [ ] **TODO-4 (optional, performance):** the helper exists only to reach
  `fast_ordinal_regression_internal` in `fast_ordinal_regression.cpp`
  through R. Declaring that C++ entry point and calling it directly removes
  the R round-trip per covariate per subject (the reason the non-speedup
  ordinal path is the slowest of the GLM weight paths) and removes the
  callback class of bug entirely. Bit-identical to TODO-1 since it is the
  same code; do it only if the user wants the speed, since TODO-1 alone
  closes the bug.
