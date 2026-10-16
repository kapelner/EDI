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

  **Harness promoted 2026-10-14:**
  `R/benchmark/benchmark_bootstrap_worker_draws.R` benchmarks the three
  installed-package worker paths, prepares draws before timing, reports
  batched per-draw timings, and prints an `Rprof` summary. A bounded pilot
  against installed EDI 1.0.3 (2026-10-14; n = 30, 25 draws, seed 20261014)
  passed: OLS 0.60 ms/draw, logistic 0.92 ms/draw, Cox 0.68 ms/draw. The
  pilot caught and fixed two harness issues: exact-event Cox responses now
  pass `ys` without unpaired censoring bounds, and `Rprof` uses the platform's
  10 ms minimum interval. Results are in
  `/tmp/edi_bootstrap_worker_draws_pilot_20261014.csv`. This is only a
  functionality pilot, not the required n = 1000 evidence. Since the worker
  changes predate this harness, its measurement is a current-state baseline,
  not the required pre-change baseline; TODO-1 remains open for the larger
  run and historical comparison. **Larger current-state profile, 2026-10-15:**
  the installed EDI 1.0.3 harness ran n = 1000, 100 draws, seed 20261015
  (the three fixtures use seeds 20261015--20261017). Median/IQR were OLS
  1.00/0.12 ms per draw, logistic 1.04/0.33 ms, and Cox 1.24/0.33 ms.
  The 100-draw, 10-ms-interval Rprof snapshots show OLS time concentrated in
  `which()` / `drop_highly_correlated_cols()` / `create_design_matrix()` and
  sample loading; logistic in `generate_mod()` and
  `fit_with_hardened_qr_column_dropping()`; Cox in sample loading,
  `generate_mod()`, and `.Call`. The short profile is directional rather than
  a precise attribution. CSV: `/tmp/edi-todo58-worker-profile-1000-100-20261015.csv`.
  This is still current-state data only; it neither recovers the 1.0.2
  pre-change baseline nor compares the full procedure table to `boot`, so
  TODO-1 and TODO-6 remain open.

- [x] TODO-2: **Subset without `make.unique` (F1).** In `subset_field()`,
  subset data.frames column-wise (`lapply(x, "[", indices)` →
  `as.data.frame` with compact integer row names via `.set_row_names()`),
  or convert `base_Xraw`/`base_Ximp` once to data.tables at worker
  creation and subset with `x[indices]` (data.table keeps no row names).
  Keep the data.frame class the downstream pipeline expects (see the
  `as.data.table` comment in `design_abstract.R`). Implemented by rebuilding
  the existing zero-row data frame column-by-column and assigning compact
  automatic row names, avoiding `make.unique()` for duplicated bootstrap
  rows. The worker-state regression verifies repeated-row column values and
  row names. Full fixed-seed distribution confirmation on the three
  performance fixtures remains part of TODO-6's installed-runtime gate.

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
  **Source implementation 2026-10-10; execution pending.** The reusable
  worker now takes the direct row subset of its saved full model matrix. It
  checks the intercept/treatment/covariate matrix for full rank first; a
  deficient sample clears both worker matrix overrides and marks the design
  matrix stale, restoring the historical rebuild-and-harden path. A focused
  rare-covariate sample regression asserts that fallback and its OLS estimate.
  The three-fixture equality runs remain part of TODO-6's installed-runtime
  gate, so this checkbox stays open. **Installed-package regression,
  2026-10-15:** `test-design-backed-bootstrap-worker-state-and-sample-loading-reference.R`
  passed 59/59 assertions against EDI 1.0.3, including repeated-row data
  frame values/row names, OLS resampling with changing design matrices,
  rare-covariate rank-deficient fallback versus rebuild at `1e-10`, matching
  vector renumbering, and survival event indicators. This validates the
  installed worker behavior, not the three performance-fixture distribution
  comparison or the `boot` speed gate.

- [ ] TODO-4: **Skip the per-draw R `qr()` when the full-data design is
  full rank (F3).** Same change as `bayesian_bootstrap_performance.md →
  TODO-7`: call the kernel directly, fall back to
  `fit_with_hardened_qr_column_dropping()` on failure or rank deficiency,
  move `tryCatch` to per-chunk. Implement once; close in both plans.

  **Shared helper step, 2026-10-16 (TODO-57 TODO-7):**
  `fit_with_hardened_qr_column_dropping()` now accepts an exact-matrix rank
  certificate and first attempts the normal all-column fit without another
  helper-level QR. The design-backed nonparametric worker passes the
  certificate from its existing per-draw rank check, so rank-deficient draws
  still take the historical rebuild-and-harden path. Bayesian-bootstrap
  workers mark a draw eligible only when every weight is finite and strictly
  positive; a previously established full-matrix certificate can then be
  reused because positive row scaling preserves rank. A failed fit continues
  through the existing hardened QR/drop-column fallback. The focused checkout
  source regression tests both no-QR certified success and fallback behavior;
  it evaluates only the helper definition and does not load the checkout
  package. This is one shared implementation, not a second TODO-57 change.
  Remaining acceptance: eliminate the nonparametric loader's own per-draw QR
  without changing its bit-preserving deficient-draw rebuild, and validate
  current-checkout/native performance and behavior. The shared reusable-worker
  dispatcher also now uses one chunk-level `tryCatch` on the no-error path;
  after a non-control draw error, it records that draw as `NA` and processes
  the chunk suffix with the existing per-draw handler so later draws remain
  isolated. Deadline/control conditions and errors outside the fit block still
  propagate. A checkout-source regression verifies one guard for a clean
  chunk, continued results after multiple failed draws, and control-condition
  propagation. The source regression passed with the installed-package test
  harness, but evaluates the checkout dispatcher separately; it is not a
  native/current-package validation. This checkbox remains open.

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

  **Installed worker-vs-`boot` pilot (2026-10-15; diagnostic, not closure):**
  `boot` 1.3.32 was already installed; no install/build occurred. The
  compile-free harness `/tmp/edi-todo58-boot-compare.R` recreated the
  procedure benchmark's deterministic `generate_data()` fixtures and
  `seed_for_class("Procedure <response>")` rule, with 4 covariates, balanced
  treatment, OLS `n=1000, B=1000`, logistic `n=1000, B=500`, and Cox
  `n=500, B=500`. It compared the installed EDI reusable worker against the
  corresponding `boot` statistic on identical resample indices, and separately
  timed EDI worker draws against complete `boot::boot()` calls divided by B.
  All draws were finite; the paired distributions' maximum absolute
  coefficient differences were `1.55e-15` (OLS), `5.20e-11` (logistic), and
  `3.39e-9` (Cox), and their percentile endpoints agreed on every paired
  fixture. Median per-draw times (EDI worker / `boot::boot`) were 0.84 / 0.145
  ms (0.17x), 1.14 / 1.662 ms (1.46x), and 1.04 / 0.516 ms (0.50x),
  respectively. Results: `/tmp/edi-todo58-boot-compare-20261015.csv`.
  This direct-worker pilot is not the required public R6 procedure-table
  rerun, does not establish 1.0.2 distribution parity, and leaves TODO-6 and
  release TODO-58 open; do not use it to overwrite the canonical benchmark.

  **Protocol clarification, 2026-10-16:** the ≥1x current-speed gate compares
  the public R6 percentile-CI procedure call with the complete canonical
  `boot::boot()` + `boot::boot.ci(type = "perc")` call on the controlled
  fixtures, using interleaved timing samples. The EDI procedure timing excludes
  fresh inference-object construction (which is measured separately); the
  canonical timing includes both `boot()` and `boot.ci()`. The speed comparison
  does not require EDI and `boot` to use identical bootstrap indices: their
  resampling implementations differ, and resetting both to the same R seed
  does not guarantee matched draws. Fixed-seed distribution parity is a
  separate gate against EDI 1.0.2, not against `boot`.

  Fixture RNG starts with `set.seed(seed_for_class(paste("Procedure", fx)))`
  before `generate_data(n, p = 5, family)`, where `fx` is `continuous`,
  `incidence`, or `survival`, giving seeds 22422, 19021, and 17961. The
  procedure row then starts at
  `seed_for_class(paste(spec$name, spec$pkg, spec$func))`; `seed_for_class(s)`
  is `sum(utf8ToInt(s) * seq_along(utf8ToInt(s))) %% 2147483647`. For the
  current rows (`pkg = "boot"`) the full row strings and seeds are:
  - `Nonparametric bootstrap CI: OLS (B = 1000) [R6 InferenceContinOLS] boot boot(lm.fit)+boot.ci(perc)` → 414230.
  - `Nonparametric bootstrap CI: logistic regression (B = 500) [R6 InferenceIncidLogRegr] boot boot(glm.fit)+boot.ci(perc)` → 609739.
  - `Nonparametric bootstrap CI: Cox PH (B = 500, n = 500) [R6 InferenceSurvivalCoxPHRegr] boot boot(coxph.fit)+boot.ci(perc)` → 628354.

  **Public-path high-load reduced-B pilot, 2026-10-16 (diagnostic only):**
  installed EDI 1.0.3 (`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`,
  DLL `libs/EDI.so`), R 4.7.0 x86_64, 12 detected cores; OMP/MKL/BLAS/OpenBLAS
  were configured for one thread. At host load averages 7.79/7.89/8.96, two
  alternating public R6-vs-full-`boot` pairs gave OLS (B=100) 398/236 ms vs
  258/25 ms, logistic (B=50) 171/154 ms vs 145/132 ms, and Cox (B=50) 157/132
  ms vs 54/50 ms. This used the exact deterministic fixture seeds above, but
  a simplified row seed rather than the full row seeds listed above; the small
  sample and high load also make these times unsuitable for acceptance. Results
  are isolated at `/tmp/edi-todo58-public-paired-pilot-20261016.csv`; the run
  did not establish 1.0.2 distribution parity. Do not promote these values or
  edit the canonical report from this pilot. Run the full 10-sample, original-B
  public-procedure comparison only in a quiet window.

## Out of scope

- The BCa jackknife cost (`type = "bca"` default): a definitional cost,
  revisit only if the percentile floor above is reached and BCa still
  trails `boot.ci(type = "bca")`.
- Bayesian-bootstrap weighted refits (`bayesian_bootstrap_performance.md`).
- Randomization-distribution plumbing (the cache-key hash of the
  permutation matrix and the no-op `subset_permutations` copy found in
  the same session): not yet planned anywhere; separate item.
