# Wire the Unused OLS Randomization-Distribution Kernel (and Triage Eight Other Dead Kernels)

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-17p`;
> 2026-08-30, user decision). R-side wiring of an existing, exported C++
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

The Poisson class shows the intended wiring
(`inference_count_poisson.R:839-846`): check for a custom statistic, take
`permutations$w_mat`, pass `private$X`, `y`, `delta`, and
`private$n_cpp_threads(ncol(w_mat))` to the batch kernel.

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
6. **Custom statistics, compiled or R.** Return `NULL` if either
   `custom_randomization_statistic_function` or `compiled_cpp_stat_fn` is
   set (Poisson checks only the former — check both).
7. **`m_mat` (matched-pair designs).** `permutations$m_mat` is non-`NULL`
   for KK designs; the OLS class on a matched design is a different class.
   Return `NULL` if `m_mat` is present, to be safe.

## Items

- [ ] **TODO-1: `InferenceContinOLS$compute_fast_randomization_distr()`.**
  Private method with the Poisson signature. Guards per §1–7 above, then
  `compute_ols_distr_parallel_cpp(Xc_kept, as.numeric(y), w_mat,
  as.numeric(delta), private$n_cpp_threads(ncol(w_mat)))`. `Xc_kept` is
  memoised on `cached_design_matrix` so the hardened column set is computed
  once per object, not per call. For `p_covars = 0` pass a 0-column matrix;
  verify the kernel handles `p_covars = 0` (it sizes `XtX` as 2×2 — check
  `Xt_1`/`XtX_c` with zero columns compile to no-ops rather than UB).
- [ ] **TODO-2: Kernel rank guard.** In `ols_distr_parallel.cpp`, after the
  QR, `if (qr.rank() < p_full) { res_ptr[b] = NA_REAL; continue; }`. Also
  return `NA` when `sum_w == 0 || sum_w == n` (all-treated / all-control
  permutation) rather than letting the solve produce garbage. Targeted
  compile of this one file only, per `CLAUDE.md`.
- [ ] **TODO-3: Equivalence tests.** New `test-ols-rand-distr-kernel.R`:
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
- [ ] **TODO-4: Dead-kernel triage.** For each of the nine unreferenced
  exports below, decide *wire in* or *delete*, and do it. Deleting means
  removing the function from its `.cpp`, re-running
  `Rcpp::compileAttributes()`, and — because of the unity build — checking
  the file is still non-empty or removing it from its `unity_NN.cpp` group
  (`configure`'s `generate_unity_wrappers`; see
  `unity_build_collision_audit.md`). Recommendation per kernel:
  | kernel | file | recommendation |
  | --- | --- | --- |
  | `compute_ols_distr_parallel_cpp` | `ols_distr_parallel.cpp` | **wire** (TODO-1) |
  | `compute_ols_bootstrap_parallel_cpp` | `ols_distr_parallel.cpp` | **wire** as `compute_fast_rand_bootstrap_distr()` if its resampling contract matches `inference_all_abstract_rand_bootstrap.R:227/808` (index matrix, `-1 = NA`); else delete |
  | `compute_wilcox_distr_parallel_cpp` | `fast_wilcox_parallel.cpp` | **delete** — superseded by the live `compute_wilcox_hl_distr_parallel_cpp` (`inference_all_simple_wilcox.R:262`) |
  | `compute_wilcox_distr_from_list_parallel_cpp` | `fast_wilcox_parallel.cpp` | **delete**, same reason |
  | `base_bootstrap_loop_cpp` | `base_bootstrap_loop.cpp` | **delete** — the reusable-bootstrap-worker path replaced it |
  | `matching_bootstrap_loop_cpp` | `kk_bootstrap_loop.cpp` | **delete**, same |
  | `fill_i_b_with_matches_loop_cpp` | `KK_bootstrap_helper_fillin.cpp` | **delete** (also O(m·n); not worth fixing) |
  | `bisection_ci_parallel_cpp`, `bisection_ci_single_bound_cpp` | `bisection_ci.cpp` | **delete** — they call an R `pval_fn` per step, so they cannot be faster than the R bisection, and the R search now has expansion/MC/cache logic they lack |
  | `bisection_ci_loop_cpp` | `bisection_ci_loop.cpp` | **delete**, same |
  If a whole file becomes empty, delete the file and its unity-group entry.
  Update `python/` bindings only if any of these were surfaced there (the
  grep says none are).
- [ ] **TODO-5: Benchmark.** `r ∈ {201, 1001, 2001}`, `n ∈ {100, 500, 1000}`,
  `p ∈ {0, 5, 10}`, `compute_rand_two_sided_pval()` before/after, 1 and 4
  cores. Expect 20–50× single-core; record the point where the R-side
  per-call overhead (permutation generation, `t` computation) dominates.
  Add the numbers to `benchmark_model_fits.md`'s randomization section.
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
