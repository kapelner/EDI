# Dead Randomization Fast Paths: a Kernel That Does Not Exist, Two Type Mismatches, and a Dispatcher That Hides Both

> **Depends on:** nothing. Touches `inference_count_poisson.R →
> compute_fast_randomization_distr()` (L816–822),
> `inference_all_simple_wilcox.R → compute_fast_randomization_distr()`
> (L287–298), `inference_all_KK_wilcox_ivwc.R`'s equivalent, the fast-path
> dispatcher in `inference_all_abstract_rand.R` (L60–66), and one new
> wiring test. `permutation_signature_once.md` (`release_v1_1_0.md →
> TODO-42`) shares TODO-2 (integer storage) with this plan: implement once.
> Otherwise independent of every item in `release_v1_0_5.md` and
> `release_v1_1_0.md`.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-64`).

Written 2026-10-07. Found while scoping `permutation_signature_once.md`
against the installed CRAN EDI 1.0.2 (no rebuild): a script called each
class's `compute_fast_randomization_distr()` directly on the permutation
object the dispatcher itself produces. Filed on the model's initiative under
the standing instruction to add found bugs to v1.0.5; delete if unwanted.

## Findings (installed 1.0.2, `DesignFixediBCRD` n = 1000 unless noted)

**F1. `InferenceCountPoisson`'s fast path calls a kernel that does not
exist.** `inference_count_poisson.R:821` calls
`compute_poisson_distr_parallel_cpp(X_covars, y, w_mat, delta,
log_transform, threads)`. There is no such function anywhere in the
package: no definition in `src/`, no wrapper in `RcppExports.R`, no
Poisson distribution kernel under any name (`grep` of `src/` for
`poisson.*distr.*_cpp` is empty). The call has been dangling since the
initial commit (`ff079d54`, 2026-08-10). On the installed package it fails
with `could not find function "compute_poisson_distr_parallel_cpp"`. The
`ols_randomization_distr_cpp_wiring.md` plan (`release_v1_0_5.md →
TODO-3`) cites this very method as "the Poisson class shows the intended
wiring"; the template points at a kernel that was never written.

**F2. Two Wilcoxon fast paths hand a double matrix to an integer-mapped
kernel.** `generate_permutations()` stores `w_mat` as double
(`inference_all_abstract_rand.R:755`). `InferenceAllSimpleWilcox` passes
it to `compute_wilcox_hl_distr_parallel_cpp` and `InferenceAllKKWilcoxIVWC`
to `compute_matching_wilcox_distr_parallel_cpp`, both declared
`Eigen::Map<Eigen::MatrixXi>& w_mat`, which cannot map a `REALSXP`:
`Wrong R type for mapped matrix`. Measured: `InferenceAllSimpleWilcox`
`compute_rand_two_sided_pval(r = 1000)` 891 ms through the fallback versus
404 ms for its kernel on an integer matrix.

Tested and working (their kernels take `IntegerMatrix`, which Rcpp
coerces with a copy): `InferenceAllSimpleAverageDiff`, `InferenceContinLin`,
`InferenceContinRobustRegr`, `InferenceContinQuantileRegr`,
`InferenceAllKKMeanDiffIVWC`, `InferenceContinKKOLSIVWC`,
`InferenceContinKKOLSOneLik`. Not yet tested: `InferenceOrdinalRidit`,
`InferencePropQuantileRegr`, the KK robust and Bai classes
(`compute_bai_distr_parallel_cpp` is also `Map<MatrixXi>`, so Bai is
likely dead too), `InferenceCustomRand`.

**F3. The dispatcher swallows every fast-path error.**
`inference_all_abstract_rand.R:61–66` wraps the fast path in
`tryCatch(..., error = function(e) NULL)` and falls through to the
per-permutation R worker loop. Nothing logs, warns or tests this, so a
missing kernel and a type mismatch both look like a slow day. No test
exercises any class's fast path against the dispatcher's own permutation
object; the one-line static check that found F1 (every `*_cpp(` inside a
`compute_fast_randomization_distr` body must exist in `RcppExports.R`) did
not exist either.

## TODOs

- [ ] TODO-1: **Complete the audit.** Run the direct-call check for every
  class that defines `compute_fast_randomization_distr()` (18 files) on a
  design each can be constructed on, plus the static `*_cpp(`-exists check,
  and record the table here. Installed package only.

- [ ] TODO-2: **Integer `w_mat` for the `Map<MatrixXi>` kernels (F2).**
  Minimal v1.0.5 form: coerce at the two Wilcoxon call sites
  (`storage.mode(w_mat) = "integer"`; one copy per call, which the
  fallback was paying many times over). Permanent form: integer storage at
  generation, `permutation_signature_once.md → TODO-4`. Implement once.
  Bit-preserving: the kernel and the worker loop compute the same
  statistic; assert equality to 1e-10 on a fixed permutation set.

- [ ] TODO-3 *(choose one; the kernel option is the result-changing
  exception in the standing constraint)*: **Poisson (F1).**
  - (a) Delete the dead method so `InferenceCountPoisson` honestly takes
    the worker path (bit-preserving: that is what it does today), and
    correct the "intended wiring" paragraph in
    `ols_randomization_distr_cpp_wiring.md` to point at
    `inference_all_average_diff.R:193` instead. Recommended for v1.0.5.
  - (b) Write `compute_poisson_distr_parallel_cpp` (per-permutation IRLS
    for the treatment coefficient with `X` hoisted, OpenMP over columns,
    `log_transform` honored) and keep the method. Same estimator to
    floating point, tolerance 1e-10 against the worker path; move the
    item to the OLS wiring plan's triage list if deferred.

- [ ] TODO-4: **Stop hiding fast-path failures (F3).** Under
  `should_run_asserts()`, rethrow the fast-path error instead of falling
  back (tests and `comprehensive_tests` then catch the next dead path).
  Outside asserts keep the fallback, but `warning()` once per class per
  session and record the reason in `cached_values` for
  `InferenceSuite` diagnostics.

- [ ] TODO-5: **Wiring test.** `test-randomization-fast-path-wiring.R` (or
  a block in `test-inference-class-wiring-completeness.R`): for every
  class with a fast path, construct on a small fixture, call
  `generate_permutations(50)`, then assert the fast path returns without
  error and equals the worker-loop distribution to 1e-10 on the same
  permutations. Also the static `*_cpp(`-exists check over
  `R/EDI/R/*.R`.

## Acceptance

No class's fast path errors on the dispatcher's own permutation object;
`InferenceAllSimpleWilcox` R6 p-value within 1.1x of its kernel at
n = r = 1000; `InferenceCountPoisson` either has a working kernel or no
fast-path method; TODO-5 in the pre-push structural gates.
