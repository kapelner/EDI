# Wire the Unused OLS Randomization-Distribution Kernel (and Triage Eight Other Dead Kernels)

> **Release:** v1.0.5 (`../future_release_plans/release_v1_0_5.md → TODO-3`,
> moved 2026-09-23 from `release_v1_1_0.md → TODO-17p`, bug-fix/feature
> split; 2026-08-30, user decision). R-side wiring of an existing, exported C++
> kernel plus a dead-code triage in `src/`; no new algorithm. No Phase 0
> dependency. Independent of, but multiplicative with,
> `randomization_ci_affine_shift_reuse.md` (`→ TODO-17o`): that plan cuts
> the number of null distributions per CI from ~25 to 1; this one cuts the
> cost of each distribution by 20–50×.
>
> **Follow-on:** `ols_distr_kernel_fwl.md` (v1.2.0) rewrites the kernel's
> per-replicate algebra. It is pointless until this plan lands, because the
> kernel is currently never executed.

Date: 2026-08-30

## The finding

`compute_ols_distr_parallel_cpp()` (`src/ols_distr_parallel.cpp:15`) is a
complete OpenMP kernel: given the covariate block `X` (n×p), `y`, an n×B
integer permutation matrix `w_mat`, and `delta`, it returns the OLS treatment
coefficient of `y + δ·w_b` on `[1, w_b, X]` for every column `b`, with
`Xᵀ1` and `XᵀX` hoisted out of the loop. It is `Rcpp::export`ed and appears
in `RcppExports.R`. **Nothing calls it** — not `R/EDI/R`, not the tests, not
`python/`, not `R/benchmark`.

`InferenceContinOLS` defines no `compute_fast_randomization_distr()`, so the
dispatcher (`inference_all_abstract_rand.R:166`) falls through to
`compute_fast_randomization_distr_via_reused_worker()` (`:708-800`). Per
replicate that path: indexes a column out of `w_mat`, writes `y`, `w`, `m`
and the design into a duplicated R6 worker's private fields, calls
`sync_randomization_worker_state()`, resets `cached_values`, calls
`create_design_matrix()` (an R `cbind`), then `fast_ols_cpp()` inside a
`tryCatch`. That is ~100–200 µs of R/R6 bookkeeping around a ~5 µs solve.
At `r = 1000` the distribution costs ~150 ms where the kernel would take
~5 ms.

`InferenceContinLin` *does* define `compute_fast_randomization_distr()`
(`inference_continuous_lin.R:212`) — but it just delegates to the same
reused-worker loop, so it is not a fast path either. Lin's design has
`w·Xc` interaction columns the OLS kernel does not build; it is a stretch
item here (TODO-6), not the main deliverable.

The Poisson class was previously cited as the intended wiring, but that
method called a kernel that never existed and was deleted in v1.0.5
TODO-64. The valid simple-template is instead
`InferenceAllSimpleAverageDiff$compute_fast_randomization_distr()`
(`inference_all_average_diff.R:193`): take `permutations$w_mat`, normalize
the kernel inputs at the boundary, and return the batch distribution (or
`NULL` when the fast-path preconditions do not hold).

## Semantics that must match the slow path

1. **Hardened covariate columns.** With `harden = TRUE` (the default),
   `shared()` fits through `fit_with_hardened_qr_column_dropping()`
   (`inference_all_abstract.R:1078`), which takes a rank-revealing QR of the
   *full-data* design and keeps `[1, w]` plus the pivoted full-rank covariate
   columns. The randomization worker inherits those columns. So the kernel
   must be handed the same covariate block — `create_design_matrix()[, -(1:2)]`,
   exactly as `compute_rand_bootstrap_ci_affine_coefs()` already does at
   `inference_continuous_ols.R:230` — not the raw `private$X`.
2. **Per-replicate rank deficiency.** Permuting `w` can (rarely — binary
   covariates, tiny strata) make `[1, w_b, X_kept]` rank-deficient for some
   `b`. The worker returns `NA` for that replicate (its `fit_ok` requires
   `is.finite(b[2])`). The kernel currently does `ColPivHouseholderQR(XᵀX).solve()`
   and stores `beta[1]` if `allFinite()` — a rank-deficient `XᵀX` gives a
   finite basic solution, **not** `NA`. Add `if (qr.rank() < p_full) → NA_REAL`
   so the two paths agree on which replicates are `NA`.
3. **`delta` convention.** Kernel: `y_sim[i] = y[i] + (w_b[i] == 1 ? δ : 0)`
   (`:72`). Worker: `y_sim[perm_data$w == 1] += delta` (`:763`). Identical.
4. **`transform_responses`.** OLS resolves to `"none"` for continuous
   responses (`:427-434`); the kernel has no transform argument. Return
   `NULL` from the fast path (falling back to the worker) if a non-`"none"`
   transform is ever requested, mirroring Poisson's `log_transform` guard.
5. **Numerics.** `fast_ols_cpp` solves via LDLT on `XᵀX`; the kernel via
   ColPivQR on `XᵀX`. Same estimator to ~1e-14 relative; not bit-for-bit.
   This is a documented default change under the v1.1.0 additive
   constraint, with the equivalence test tolerance set at `1e-10`.
6. ~~**Custom statistics, compiled or R.** Return `NULL` if either
   `custom_randomization_statistic_function` or `compiled_cpp_stat_fn` is
   set (Poisson checks only the former — check both).~~ **Moot as of
   2026-09-13** (`fix_custom_randomization_statistic.md`,
   `finished_features/`): neither field can exist on `InferenceContinOLS`
   (or any class outside the new, standalone `InferenceRandCustom`) any
   more, so this guard is unreachable and not needed. Number kept so
   cross-references elsewhere still resolve.
7. **`m_mat` (matched-pair designs).** `permutations$m_mat` is non-`NULL`
   for KK designs; the OLS class on a matched design is a different class.
   Return `NULL` if `m_mat` is present, to be safe.

## Items

- [x] **TODO-1: `InferenceContinOLS$compute_fast_randomization_distr()`.**
  Private method with the Poisson signature. Guards per §1–7 above, then
  `compute_ols_distr_parallel_cpp(Xc_kept, as.numeric(y), w_mat,
  as.numeric(delta), private$n_cpp_threads(ncol(w_mat)))`. `Xc_kept` is
  memoised on `cached_design_matrix` so the hardened column set is computed
  once per object, not per call. For `p_covars = 0` pass a 0-column matrix;
  verify the kernel handles `p_covars = 0` (it sizes `XtX` as 2×2 — check
  `Xt_1`/`XtX_c` with zero columns compile to no-ops rather than UB).
- [x] **TODO-2: Kernel rank guard.** In `ols_distr_parallel.cpp`, after the
  QR, `if (qr.rank() < p_full) { res_ptr[b] = NA_REAL; continue; }`. Also
  return `NA` when `sum_w == 0 || sum_w == n` (all-treated / all-control
  permutation) rather than letting the solve produce garbage. Targeted
  compile of this one file only, per `CLAUDE.md`.
- [x] **TODO-3: Equivalence tests.**
  `test-parallel-distribution-kernel-contracts.R`:
  (a) for fixed seed and permutations, the sorted `t0s` from the kernel path
  and from `compute_fast_randomization_distr_via_reused_worker()` agree to
  `1e-10`, at `p_covars ∈ {0, 1, 5}`, `harden ∈ {TRUE, FALSE}`, and
  `δ ∈ {0, 0.5}`; (b) a design with a duplicated covariate column (hardening
  drops one) gives identical `NA` patterns and values across both paths;
  (c) a design where some permutation makes `[1, w_b, X]` singular yields
  `NA` at the same `b` in both; (d) `compute_rand_two_sided_pval()` and
  `compute_confidence_interval_rand()` end-to-end agree within
  `pval_epsilon`; (e) a custom-statistic OLS never enters the kernel path
  (spy on the kernel).

  **Source implementation 2026-10-10:** TODO-1 now normalizes the
  dispatcher's double `w_mat`, declines transformed/matching draws, derives
  the hardened covariate block from `create_design_matrix()`, and calls the
  batch kernel. TODO-2 now returns `NA` for one-arm and rank-deficient
  permutations. TODO-3 has direct-kernel degeneracy regressions plus an OLS
  fast-path versus reused-worker parity regression in
  `test-parallel-distribution-kernel-contracts.R`. On 2026-10-13, the focused
  kernel-contract, end-to-end OLS p-value/CI parity, and parallel-threshold
  suites passed source-loaded with `compile = FALSE`, using the already
  installed native library. No compile or rebuild was performed. The full
  parameter matrix was added to `test-parallel-distribution-kernel-contracts.R`
  and passed on 2026-10-14 against the reinstalled package (48 observations,
  8 fixed permutations, covariate counts 0/1/5, `harden` TRUE/FALSE, and
  `delta` 0/0.5). **Equivalence subchecks (TODO-3) are satisfied by this
  installed-package evidence**; it is not a current-checkout native
  validation. The separate benchmark TODO-5 is checked below. The release
  parent remains open for current-head native validation and the TODO-4
  dead-export disposition; TODO-6 (Lin) remains a stretch item. The TODO-1..3
  checkmarks record source implementation and equivalence-test evidence only;
  they do not close the release parent's current-head native gate.
- [ ] **TODO-4: Dead-kernel triage.** For the remaining exports below
  without a production caller, decide *wire in* or *delete*, and do it.
  A Graft caller audit on 2026-10-14 found direct test/benchmark/profiler
  references for these exports, so “unreferenced” here means no production
  inference path, not no repository references. In particular,
  `compute_ols_bootstrap_parallel_cpp` is already used by
  `InferenceContinOLS$compute_fast_non_param_bootstrap_distr()` for the
  ordinary row-IID percentile-bootstrap path; randomization bootstrap uses the
  distinct `compute_rand_bootstrap_ols_parallel_cpp` kernel. The two old
  Wilcoxon exports are likewise exercised by contract tests but have no
  production caller; the live inference path uses the HL kernel. The bootstrap
  loops, fill-in helper, and bisection kernels also have direct contract-test
  references that must be migrated or intentionally removed with any deletion.
  Current installed-package runs on 2026-10-14 passed 144 resampling-kernel
  assertions, 18 bisection-tail/discontinuity assertions, 13 index-fill and
  bisection-loop assertions, plus 54 parallel-distribution and 31 threshold
  assertions. They establish these are exercised contracts, not unreferenced
  code; they do not settle whether the internal wrappers should remain.
  Deleting means
  removing the function from its `.cpp`, re-running
  `Rcpp::compileAttributes()`, and — because of the unity build — checking
  the file is still non-empty or removing it from its `unity_NN.cpp` group
  (`configure`'s `generate_unity_wrappers`; see
  `unity_build_collision_audit.md`). Recommendation per kernel:
  | kernel | file | recommendation |
  | --- | --- | --- |
  | `compute_ols_distr_parallel_cpp` | `ols_distr_parallel.cpp` | **wire** (TODO-1) |
  | `compute_ols_bootstrap_parallel_cpp` | `ols_distr_parallel.cpp` | **retain** — already wired to ordinary OLS percentile bootstrap via `compute_fast_non_param_bootstrap_distr()`; distinct from randomization-bootstrap kernel |
  | `compute_wilcox_distr_parallel_cpp` | `fast_wilcox_parallel.cpp` | **delete** — superseded by the live `compute_wilcox_hl_distr_parallel_cpp` (`inference_all_simple_wilcox.R:262`) |
  | `compute_wilcox_distr_from_list_parallel_cpp` | `fast_wilcox_parallel.cpp` | **delete**, same reason |
  | `base_bootstrap_loop_cpp` | `base_bootstrap_loop.cpp` | **delete** — the reusable-bootstrap-worker path replaced it |
  | `matching_bootstrap_loop_cpp` | `kk_bootstrap_loop.cpp` | **delete**, same |
  | `fill_i_b_with_matches_loop_cpp` | `KK_bootstrap_helper_fillin.cpp` | **delete** (also O(m·n); not worth fixing) |
  | `bisection_ci_parallel_cpp`, `bisection_ci_single_bound_cpp` | `bisection_ci.cpp` | **delete** — they call an R `pval_fn` per step, so they cannot be faster than the R bisection, and the R search now has expansion/MC/cache logic they lack |
  | `bisection_ci_loop_cpp` | `bisection_ci_loop.cpp` | **delete**, same |
  **Source-only caller disposition audit, corrected 2026-10-18:** The earlier
  2026-10-16 note incorrectly classified `compute_ols_bootstrap_parallel_cpp`
  as having no production caller. The current caller is
  `InferenceContinOLS$compute_fast_non_param_bootstrap_distr()`
  (`R/EDI/R/inference_continuous_ols.R:203-248`, native call at `:241`), for
  ordinary row-IID OLS percentile-bootstrap draws. It receives zero-based
  `i_b - 1` indices, and the wrapper requires supported Bernoulli designs,
  unstructured draws, and full-rank sampled designs; unsupported/rank-deficient
  cases decline to the worker. The separate randomization-bootstrap path uses
  `compute_rand_bootstrap_ols_parallel_cpp`, so the older kernel should not be
  wired as `compute_fast_rand_bootstrap_distr()`. Direct-kernel reference tests
  in `test-resampling-parallel-threshold-contracts.R:66-86` compare fixed-index
  samples with `lm.fit`; its public percentile-dispatch test at `:88-121`
  compares the complete distribution and CI endpoints against independent
  `lm.fit` references. These source/test references establish the current
  production role but are not current-checkout native validation.

  The remaining exports in this subsection have no incoming edge from a
  production inference path. Their non-generated references are only direct
  test/benchmark/profiler calls (and generated `RcppExports`/`.Call`
  registration plumbing). This confirms “no production caller” for those
  kernels, but does not make their package-private wrappers unreferenced or
  authorize deleting them. The two Wilcoxon kernels are superseded by the
  live HL kernel; the two bootstrap loops by the reusable-worker route; the
  fill-in helper and three bisection kernels are likewise test-only from the
  source caller graph. These eight match the plan's delete recommendation.
  The remaining delete recommendations still require migration/removal of
  direct contract tests and profiler/benchmark references as applicable,
  generated Rcpp export/registration updates, and unity-wrapper cleanup. No
  source/export was changed and no compile was run.
  **Direct-test migration map, 2026-10-18:** the package-private contracts
  are grouped as follows, so a future approved retirement can migrate each
  call site without weakening unrelated coverage:
  - `compute_wilcox_distr_parallel_cpp` and
    `compute_wilcox_distr_from_list_parallel_cpp`:
    `test-parallel-distribution-kernel-contracts.R` and
    `test-resampling-parallel-threshold-contracts.R`; replace with live
    HL/public-kernel assertions only after the retirement decision.
  - `base_bootstrap_loop_cpp` and `matching_bootstrap_loop_cpp`:
    `test-resampling-callback-recovery-contracts.R`,
    `test-resampling-kernel-contracts.R`, and the profiler entry in
    `R/profile/edi_kernel_profiler.R`. Preserve the distinct
    `match_stats_from_indices_cpp` coverage when migrating the matching
    wrapper.
  - `fill_i_b_with_matches_loop_cpp`:
    `test-bootstrap-index-fillin-and-bisection-loop.R` and
    `test-resampling-kernel-contracts.R`.
  - `bisection_ci_parallel_cpp`, `bisection_ci_single_bound_cpp`, and
    `bisection_ci_loop_cpp`:
    `test-bisection-tail-and-discontinuity-regressions.R`,
    `test-bootstrap-index-fillin-and-bisection-loop.R`,
    `test-resampling-kernel-contracts.R`, and
    `test-resampling-parallel-threshold-contracts.R`.
  These direct tests currently encode wrapper-specific contracts; do not
  delete or rewrite them before the maintainer disposition. Once approved,
  migrate tests/profiler references and the Rcpp export/prototype/registration
  rows together, regenerate exports, and verify no stale references remain.
  If a whole file becomes empty, delete the file and its unity-group entry.
  Update `python/` bindings only if any of these were surfaced there (the
  grep says none are).
- [x] **TODO-5: Benchmark.** Completed 2026-10-14 against the reinstalled
  package: three interleaved fast/worker timing pairs per cell for
  `r ∈ {201, 1001, 2001}`, `n ∈ {100, 500, 1000}`, `p ∈ {0, 5, 10}`, and
  1/4 cores. All 162 p-value pairs matched at `1e-10`. Median speedup was
  43.07× at one core (cell-median range 19.50×–185×) and 54.30× at four
  cores (28.37×–113×); the one-core median meets the 20–50× target, while
  the `n=1000, p=0, r=2001` one-core cell is the low outlier. The slow path
  was the same inference class with the batch-kernel hook disabled; each
  pair used an identical fixed permutation matrix. Results are recorded in
  `benchmark_model_fits.md`'s randomization section. The fast times are
  generally short enough that per-call overhead and timer resolution explain
  much of the small-cell spread; permutation generation was outside the
  timed call on both paths.
- [ ] **TODO-6 (stretch): Lin.** A `compute_lin_distr_parallel_cpp` that
  builds `[1, w_b, Xc, w_b·Xc]` per replicate (the interaction block is
  the only thing that changes with `w_b`, and it is `diag(w_b)·Xc`, so
  `XᵀX` blocks update in O(np²) per replicate — or defer to the FWL plan).
  Only after TODO-1..5; if not done in 1.1.0, move to
  `ols_distr_kernel_fwl.md`'s scope.

## Explicitly out of scope

- Rewriting the kernel's per-replicate algebra (FWL, hoisted Cholesky,
  zero-allocation loop) — `ols_distr_kernel_fwl.md`, v1.2.0.
- The `t0s_rand` affine-shift reuse across bisection steps —
  `randomization_ci_affine_shift_reuse.md` (`→ TODO-17o`).
- Any change to the reused-worker path itself; it remains the fallback for
  every class without a batch kernel.
