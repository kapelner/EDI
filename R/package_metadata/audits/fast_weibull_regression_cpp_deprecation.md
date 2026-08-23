# Should `fast_weibull_regression_cpp` Be Deprecated In Favor Of `fast_weibull_regression_general_cpp`?

Date: 2026-08-14

## Question

`interval_censored_survival_response.md` TODO-3 added
`fast_weibull_regression_general_cpp` (`R/EDI/src/fast_weibull_regression.cpp`),
a `(y, y_L, y_R)`-based Weibull AFT kernel that is a strict superset of the
legacy `fast_weibull_regression_cpp`'s `(y, dead)`-based fit (exact/right-
censored data is one special case of the general interval-censored
likelihood). Given that, should the legacy kernel be deprecated and deleted
in favor of always calling the general one?

## Short Answer

**No, not yet — keep both.** Correctness is not the issue (they are provably
byte-identical on right-censored data, verified below) and performance is not
the issue either (no measurable regression, verified below). The blocker is
that `fast_weibull_regression_cpp` is still a live, load-bearing dependency
of code that has not been migrated to pass `y_L`/`y_R`:

- Three KK-combined survival `Inference` classes
  (`inference_survival_KK_weibull_frailty_loggamma.R`, `inference_survival_KK_weibull_frailty_normal.R`,
  `inference_survival_KK_weibull_marginal.R`) still call
  `fast_weibull_regression_cpp` directly, with a `(y, dead)` calling
  convention baked into their own logic (not just a pass-through).
- `InferenceSurvivalWeibullRegr` itself — the very class TODO-4 updated —
  still calls the legacy kernel for its exact/right-censored fast path;
  only the general-censoring branch was switched over.
- `R/EDI/R/glm_fit_helpers.R`'s public `fast_weibull_regression()` wrapper,
  several benchmark scripts, and multiple `testthat` files
  (`test-rcpp-fitting-equivalence.R`, `test-rcpp-fitting-real-data.R`) all
  call it directly.

Deleting the legacy kernel today would break all of the above. Deprecating
it (i.e., committing to eventually removing it) is reasonable in principle
now that TODO-3/TODO-4 have proven the general kernel is a safe drop-in
replacement on the data it was checked against, but the actual removal
should wait until every remaining `(y, dead)` call site listed above has
been migrated to pass `y_L`/`y_R` (the natural continuation of TODO-4,
covering the three KK-combined classes it explicitly left out) — otherwise
this becomes a second, uncoordinated migration on top of the one already in
flight, tracked in the same file this report is about.

## Why Correctness Is Not In Question

Both functions build the exact same `WeibullAFTLikelihood` C++ class
(`fast_weibull_regression.cpp:60-179`) — there is no separate legacy
likelihood implementation. The only difference between the two exposed
functions is how they arrive at that class's `(y, y_L, y_R)` constructor
arguments:

- `fast_weibull_regression_cpp(X, y, dead, ...)` calls a `dead_to_bounds()`
  helper once (`dead == 1` -> exact `y`; `dead == 0` -> `y_L = y, y_R = Inf`)
  before constructing `WeibullAFTLikelihood`.
- `fast_weibull_regression_general_cpp(X, y, y_L, y_R, ...)` is handed
  `y_L`/`y_R` directly and skips that conversion.

This was already established in TODO-3/TODO-4 ("bit-identical" against
`numDeriv`, `0` difference in coefficients/score/Hessian) but re-verified
directly here as part of this audit:

```r
devtools::load_all("R/EDI")
legacy  = fast_weibull_regression_cpp(X, y, dead, estimate_only = FALSE)
general = fast_weibull_regression_general_cpp(X, y_exact, y_L, y_R, estimate_only = FALSE)
```

| n | max\|coef diff\| | max\|vcov diff\| | \|neg-loglik diff\| | both converged |
|---:|---:|---:|---:|:---:|
| 200 | 0.000e+00 | 0.000e+00 | 0.000e+00 | yes |
| 1000 | 0.000e+00 | 0.000e+00 | 0.000e+00 | yes |
| 5000 | 0.000e+00 | 0.000e+00 | 0.000e+00 | yes |

Exactly `0` difference — not just "close" — across coefficients, the full
vcov matrix, and the negative log-likelihood, for right-censored data
generated fresh for this report (`n = 200/1000/5000`, Weibull AFT with
3 covariates, ~33% censoring, `set.seed(1)`).

## Performance Benchmark

### Method

The obvious mechanism for a slowdown is that
`fast_weibull_regression_cpp`'s `dead_to_bounds()` conversion is an extra
`O(n)` pass, and (for the default `smart_cold_start = TRUE` path)
`fast_weibull_regression_general_cpp` does the reverse conversion
(`general_to_effective()`) to feed the existing OLS-based smart-start
heuristic — so each function does *some* one-time `O(n)` conversion work
the other doesn't, on top of the shared optimizer loop. The question is
whether this is measurable against the `O(n) x maxit` cost of the shared
`WeibullAFTLikelihood` evaluations that dominate both.

**Caveat on measurement method:** wall-clock timing on this machine was not
trustworthy while this report was being written — `ps` confirmed a
concurrent Claude Code session running sustained heavy R package compiles
and `testthat` runs during the same window (consistent with the same
caveat noted in TODO-3 itself). An initial `microbenchmark`-based wall-clock
pass produced physically implausible results (`n=200` slower than
`n=5000`) purely from that contention. Two mitigations were used instead:
CPU (`user.self`) time via `proc.time()`, which is far less sensitive to
being descheduled by other processes than wall-clock elapsed time, and
tight interleaving of the two kernels in blocks of 5 calls each (rather
than running all reps of one kernel, then all reps of the other) so any
residual drift from contention affects both kernels equally rather than
biasing one.

```r
cpu_time_reps = function(f, reps) {
  t0 = proc.time()[["user.self"]]
  for (i in seq_len(reps)) f()
  (proc.time()[["user.self"]] - t0) / reps * 1000  # ms/call
}
# ... called in interleaved blocks of 5 for `legacy` and `general`
```

Three scenarios, `n = 200/1000/5000/20000`, same freshly-generated
right-censored data per `n` fed to both kernels:

### Results

**`estimate_only = TRUE`, `smart_cold_start = TRUE`** (the common
real-world call — point estimate, default cold start):

| n | legacy (ms) | general (ms) | ratio (general/legacy) |
|---:|---:|---:|---:|
| 200 | 0.080 | 0.140 | 1.750 |
| 1000 | 0.430 | 0.340 | 0.791 |
| 5000 | 1.760 | 1.800 | 1.023 |
| 20000 | 8.000 | 7.990 | 0.999 |

**Full fit with variance (`estimate_only = FALSE`)**:

| n | legacy (ms) | general (ms) | ratio (general/legacy) |
|---:|---:|---:|---:|
| 200 | 0.183 | 0.217 | 1.182 |
| 1000 | 0.400 | 0.450 | 1.125 |
| 5000 | 2.717 | 2.700 | 0.994 |
| 20000 | 8.650 | 8.967 | 1.037 |

**Fixed identical warm start, `smart_cold_start = FALSE`** (isolates pure
likelihood-evaluation cost, no smart-start heuristic on either side):

| n | legacy (ms) | general (ms) | ratio (general/legacy) |
|---:|---:|---:|---:|
| 200 | 0.200 | 0.200 | 1.000 |
| 1000 | 0.567 | 0.533 | 0.941 |
| 5000 | 2.200 | 2.083 | 0.947 |
| 20000 | 10.317 | 10.533 | 1.021 |

### Interpretation

- At `n = 200`, sub-millisecond calls are inherently noisy relative to
  timer/scheduler granularity (hence the 1.75x outlier in the first table)
  — not a reliable signal either way at that scale.
- At `n >= 1000`, where per-call time is large enough to measure cleanly,
  ratios sit in a tight `0.79x`-`1.18x` band with **no consistent
  direction** — the general kernel is faster in some scenarios, slower in
  others, by amounts consistent with run-to-run noise rather than a
  structural cost difference. At `n = 20000` specifically (the largest,
  most timing-stable case in every scenario), ratios are `0.999`, `1.037`,
  and `1.021` — within 4% either way.
- This matches the code-level expectation: the `dead_to_bounds()`/
  `general_to_effective()` conversions are single `O(n)` linear passes,
  dwarfed by the shared `O(n) x maxit` optimizer loop (`maxit` iterations
  of `WeibullAFTLikelihood`'s gradient/Hessian evaluation, identical code
  in both cases) that dominates total cost at every `n` tested.

**Conclusion: no performance regression from using
`fast_weibull_regression_general_cpp` for right-censored fits**, at any
tested sample size.

## Recommendation

1. **Do not delete `fast_weibull_regression_cpp` now.** It has real,
   unmigrated production callers (the three KK-combined classes listed
   above, plus `InferenceSurvivalWeibullRegr`'s own exact/right-censored
   fast path).
2. **Do mark it deprecated in its roxygen docs** (`@seealso` already points
   to the general kernel; add an explicit note that new call sites should
   prefer `fast_weibull_regression_general_cpp`), so no *new* code takes a
   dependency on the narrower kernel while the migration is incomplete.
3. **Extend TODO-4's migration to the three KK-combined classes** it
   explicitly deferred, plus `InferenceSurvivalWeibullRegr`'s exact/
   right-censored branch itself, switching them all to call
   `fast_weibull_regression_general_cpp` unconditionally (feeding
   `y_L = y, y_R = Inf` for right-censored rows, exactly as
   `dead_to_bounds()` already does internally) — this is the point at
   which `fast_weibull_regression_cpp` becomes genuinely dead code.
4. **Then, and only then, delete it** — along with
   `get_weibull_regression_score_cpp`/`get_weibull_regression_hessian_cpp`
   (the non-`_general` score/Hessian exports) and updating
   `compute_weibull_rand_bootstrap_parallel_cpp` if it's also migrated —
   and drop the now-unneeded `dead_to_bounds()` bridge helper.
5. **Python bindings note** (out of scope for this report, flagged for
   awareness): `python/CMakeLists.txt`/`python/cpp/bindings_survival.cpp`
   currently bind only `fast_weibull_regression_cpp`, not the `_general`
   variant. Whenever step 3/4 above lands, the Python package will need a
   corresponding binding added (not just a swap) if interval-censored
   fits are meant to be Python-accessible too — see
   `R/package_metadata/finished_features/python_bindings_package_spec.md`
   and the broader note in `interval_censored_survival_response.md` that
   this whole rework blocks the next `edi_kernels` release regardless.
