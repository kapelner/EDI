# Nonparametric Bootstrap Worker: Per-Draw data.frame Subsetting, Model-Matrix Rebuild and R-Level Rank Check

> **Depends on:** nothing architectural. Touches the design-backed
> reusable-worker loader in `inference_all_abstract_non_param_boot.R →
> load_bootstrap_sample_into_design_backed_worker()` (L1191; the
> `subset_field()` closure at L1249–1257) and the per-draw fit wrapper
> `inference_all_abstract.R → fit_with_hardened_qr_column_dropping()`
> (L1179; R `qr()` at L1220).
> **Shared sub-steps, implement once:** TODO-4 below is the same change as
> `bayesian_bootstrap_performance.md → TODO-7` (`release_v1_0_5.md →
> TODO-57`); TODO-5 below is owned by
> `../new_feature_plans/ols_randomization_distr_cpp_wiring.md`
> (`release_v1_0_5.md → TODO-3`). Whichever lands first closes the
> sub-step in both. Otherwise independent of every item in
> `release_v1_0_5.md` and `release_v1_1_0.md`.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-58`).

Written 2026-10-07, user decision. Found by the 2026-10-07 extension of
`R/benchmark/benchmark_model_fits.R` (new "Resampling-Based Inference
Procedure Performance" table, percentile-bootstrap rows vs. `boot`), then
root-caused the same day with `Rprof` and micro-benchmarks against the
installed CRAN EDI 1.0.2 (no rebuild). Under the 2026-09-23 split rule this
is a misfiring performance path that already shipped, not new capability.

## Why

The R6 percentile bootstrap CIs are slower than `boot::boot()` +
`boot.ci(type = "perc")` on the same data and estimator: OLS 0.09x,
logistic 0.86x, Cox 0.42x. The compiled kernels are not the problem:

| Path | Per draw |
|---|---|
| `fast_ols_cpp` (the fit the worker ends up calling) | 0.02 ms |
| `boot`'s `lm.fit` draw, including `boot`'s own R loop | 0.085 ms |
| EDI R6 worker, OLS | 2.1 ms |
| `fast_logistic_regression_cpp` estimate-only | 0.17 ms |
| EDI R6 worker, logistic | 2.6 ms |

So the OLS worker spends about 100x the kernel time per draw, all of it in
R. (The default `compute_bootstrap_confidence_interval(type = "bca")` adds
an n-fold jackknife on top; the percentile numbers above are the floor.)

## Findings (Rprof over 20–30 repetitions, installed EDI 1.0.2, n = 1000)

**F1. Row subsetting a data.frame with duplicated indices calls
`make.unique` on row names.** `subset_field()` does
`x[indices, , drop = FALSE]` on `worker_state$base_Xraw` and
`base_Ximp`, which are data.frames (deliberately, see the comment in
`design_abstract.R → covariate_impute_if_necessary_and_then_create_model_matrix()`).
`[.data.frame` with repeated row indices runs `make.unique()` on the
character row names. That one call is 28% of the whole OLS bootstrap.
Micro-benchmark: `df[idx, , drop = FALSE]` 0.275 ms vs. `mat[idx, , drop
= FALSE]` 0.03 ms for the same 1000 × 4 numeric data.

**F2. The model matrix is rebuilt from raw covariates on every draw.**
After the subset, the worker runs the full covariate pipeline
(`as.data.table` copy, `columns_have_missingness_cpp`, data.table `[`
column selections, `count_unique_values_cpp`,
`create_model_matrix_from_features` → `model.frame`/`model.matrix`),
about 0.36 ms per draw, to produce what is a row subset of the full-data
model matrix in almost every draw.

**F3. An R-level `qr()` rank check runs per draw.**
`fit_with_hardened_qr_column_dropping()` calls `qr(cbind(1, X_mat))`
(0.1 ms) before every fit, builds an `attempt_fit` closure, and wraps the
fit in `tryCatch`. The full-data fit already established the rank; a
bootstrap draw can only lose rank, which the kernel's own failure path
already reports.

**F4. Worker-state bookkeeping.** `load_bootstrap_sample_into_design_backed_worker()`
resets roughly 25 cache fields per draw (correct since the 2026-09-22
stale-worker-cache fix, and cheap individually) and re-derives
`all_subject_data_cache`, `lin_centered_covariates` and matching caches.

**F5. A compiled batched kernel exists and is unused.**
`compute_ols_bootstrap_parallel_cpp(X, y, w, indices_mat, num_cores)`
(`src/ols_distr_parallel.cpp:112`) does the whole OLS bootstrap in one
call, 9x faster than `boot` in the same table, but nothing calls it
(owned by `ols_randomization_distr_cpp_wiring.md`). The non-parametric
bootstrap dispatcher in `inference_all_abstract_non_param_boot.R` has no
`has_private_method("compute_fast_...")` fast-path hook at all (the
randomization dispatcher in `inference_all_abstract_rand.R:60` does).

## Proposal

Fix in payoff order. TODO-2 and TODO-4 are bit-preserving. TODO-3 is
tolerance-equal with a bit-preserving fallback, and is this plan's
documented default change under the standing constraint.

## TODOs

- [ ] TODO-1: **Per-draw harness, before any change.** A scratch script
  that times one `load_bootstrap_sample_into_design_backed_worker()` +
  `compute_bootstrap_worker_estimate()` cycle for OLS, logistic and Cox at
  n = 1000, plus the `Rprof` breakdown, promoted to `R/benchmark/` so
  every later TODO reports before/after on the same rows. Installed
  package only.

- [ ] TODO-2: **Subset without `make.unique` (F1).** In `subset_field()`,
  subset data.frames column-wise (`lapply(x, "[", indices)` →
  `as.data.frame` with compact integer row names via `.set_row_names()`),
  or convert `base_Xraw`/`base_Ximp` once to data.tables at worker
  creation and subset with `x[indices]` (data.table keeps no row names).
  Keep the data.frame class the downstream pipeline expects (see the
  `as.data.table` comment in `design_abstract.R`). Assert bit-identical
  bootstrap distributions for a fixed seed on all three fixtures.

- [ ] TODO-3: **Subset the model matrix instead of rebuilding it (F2).**
  Store `base_X` (the full-data model matrix) in the worker state and set
  `des_priv$X = base_X[indices, , drop = FALSE]` per draw. This differs
  from the rebuild only when a draw changes which columns
  `count_unique_values_cpp` keeps (a covariate constant within the
  draw), where the hardened QR step then drops the same column: the
  treatment estimate agrees to floating-point rounding, not bit-for-bit.
  Therefore: (a) test equality to 1e-10 against the rebuild on the three
  fixtures plus a fixture with a rare factor level; (b) fall back to the
  rebuild when the subset matrix is rank-deficient (so results on those
  draws stay bit-identical); (c) record this as the plan's default change.

- [ ] TODO-4: **Skip the per-draw R `qr()` when the full-data design is
  full rank (F3).** Same change as `bayesian_bootstrap_performance.md →
  TODO-7`: call the kernel directly, fall back to
  `fit_with_hardened_qr_column_dropping()` on failure or rank deficiency,
  move `tryCatch` to per-chunk. Implement once; close in both plans.

- [ ] TODO-5: **Fast-path hook + wire `compute_ols_bootstrap_parallel_cpp` (F5).**
  Add a `compute_fast_bootstrap_distr()` dispatch in the non-parametric
  bootstrap (mirroring `inference_all_abstract_rand.R:60`) and let
  `InferenceContinOLS` implement it with the batched kernel. The kernel
  wiring itself is `ols_randomization_distr_cpp_wiring.md`'s item; this
  plan only adds the hook if that plan has not. Equality to 1e-10 against
  the worker path, documented there.

- [ ] TODO-6: **Re-run the procedure table and update claims.**
  Acceptance: OLS percentile CI ≥ 1x `boot`; logistic and Cox ≥ 1x
  `boot`; bootstrap distributions bit-identical to 1.0.2 for a fixed seed
  except where TODO-3 documents otherwise. Update
  `benchmark_model_fits.md` and any performance text that quotes the
  0.09x / 0.86x / 0.42x numbers.

## Out of scope

- The BCa jackknife cost (`type = "bca"` default): a definitional cost,
  revisit only if the percentile floor above is reached and BCa still
  trails `boot.ci(type = "bca")`.
- Bayesian-bootstrap weighted refits (`bayesian_bootstrap_performance.md`).
- Randomization-distribution plumbing (the cache-key hash of the
  permutation matrix and the no-op `subset_permutations` copy found in
  the same session): not yet planned anywhere; separate item.
