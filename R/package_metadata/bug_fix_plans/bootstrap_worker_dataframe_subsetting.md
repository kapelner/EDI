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
  comparison or the `boot` speed gate. **Rare-factor extension, 2026-10-20:**
  the existing bulk fixture now also omits a rare factor level from a draw,
  asserts that the direct matrix override is cleared and the design rebuilds,
  then compares the treatment estimate with an independent `model.matrix()` +
  `lm.fit()` reference at `1e-10`. The whole test file passed 116/116
  expectations after loading current checkout R sources via
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; the loaded DLL
  was the temporary `EDI.so` under `/tmp/Rtmp.../pkgload...`, so this is R
  source against the available installed native code, not a current-head
  native validation. TODO-3/TODO-6 and release TODO-58 remain open.
  **Checkout-loader three-fixture equality, 2026-10-21:** the existing
  OLS/logistic/Cox comparison now invokes the loader definition extracted
  from checkout R, rather than the installed package's loader. The same five
  seeded draws per fixture still compare direct-subset estimates against both
  the forced rebuild and independent `lm.fit()`/`glm.fit()`/`coxph()` at
  `1e-10`. The focused file passed 118 expectations via
  `timeout 300s Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE,
  quiet = TRUE); testthat::test_file("R/package_tests/testthat_bulk/test-design-backed-bootstrap-worker-state-and-sample-loading-reference.R", package = "EDI")'`.
  EDI reported version 1.0.3, checkout R namespace `/home/kapelner/workspace/EDI/R/EDI`,
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and the
  `pkgload` DLL `/tmp/RtmpriL676/pkgload375a7d910/EDI.so` with MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, matching the installed library DLL;
  installed DLL SHA-256 is
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This closes the checkout-R three-fixture equality-test subgate only. The
  loaded native library is the available installed artifact, not a rebuild
  from current HEAD; original-size speed and authenticated EDI 1.0.2 parity
  remain open.

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

  **TODO-58 loader-QR audit, 2026-10-20:** the remaining loader QR is not a
  duplicate of the hardened-fit QR. For each new bootstrap row-index sample,
  the loader checks the exact augmented matrix `[1, treatment, X_subset]`
  before deciding whether it may retain the direct base-matrix subset. It
  stores an exact `mode = "unweighted"` matrix certificate when full rank;
  the fit helper consumes that same certificate to avoid a second QR. An
  identical subsequent sample reuses the exact prior certificate and makes
  no QR call. A repeated-row deficient draw must still be rank-checked before
  selecting direct-matrix reuse; it clears `worker_priv$X` and the certificate
  and marks the design matrix stale so the established rebuild-and-harden
  fallback remains intact. Parent full rank alone cannot certify a bootstrap
  sample, because resampling may omit levels/rows or duplicate observations.
  Thus there is no safe QR removal in this loader without moving an equivalent
  rank check or changing the required deficient-draw fallback. The existing
  `test-design-backed-bootstrap-worker-state-and-sample-loading-reference.R`
  regression `checkout sample loader reuses only an exact prior full-rank
  matrix certificate` passed 9 assertions with:

  ```sh
  timeout 60s Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE); dll <- getLoadedDLLs()[["EDI"]][["path"]]; cat("DLL:", dll, "\n"); cat("MD5:", unname(tools::md5sum(dll)), "\n"); testthat::test_file("R/package_tests/testthat_bulk/test-design-backed-bootstrap-worker-state-and-sample-loading-reference.R", desc = "checkout sample loader reuses only an exact prior full-rank matrix certificate")'
  ```

  Checkout R code was loaded without compilation; EDI reported version 1.0.3
  and loaded DLL `/tmp/RtmpN9KmwG/pkgload322599c37/EDI.so`, MD5
  `a75519a9256c0b3121398032314291d4`. This verifies the exact-certificate
  reuse and deficient-draw fallback contract only. No loader edit is
  justified by this optimization request; TODO-58's benchmark and authentic
  EDI 1.0.2 parity gates remain open.

- [ ] TODO-5: **Fast-path hook + wire `compute_ols_bootstrap_parallel_cpp` (F5).**
  Add a `compute_fast_bootstrap_distr()` dispatch in the non-parametric
  bootstrap (mirroring `inference_all_abstract_rand.R:60`) and let
  `InferenceContinOLS` implement it with the batched kernel. The kernel
  wiring itself is `ols_randomization_distr_cpp_wiring.md`'s item; this
  plan only adds the hook if that plan has not. Equality to 1e-10 against
  the worker path, documented there.

  **Parity-test strengthening, 2026-10-18:** the existing bulk fixture
  `test-resampling-parallel-threshold-contracts.R` already reached the OLS
  hook and compared public percentile-CI endpoints with an independent
  `lm.fit` reference at `1e-8`. It now also compares the hook's complete
  fixed-draw vector directly against the per-draw `lm.fit` coefficients at
  `1e-10`, the plan's required tolerance. Running that file through
  `testthat::test_file()` against installed EDI 1.0.3 passed 46 assertions
  (0 failures, warnings, or skips). This is installed-package evidence only;
  because compilation is not authorized, it does not validate the current
  checkout/native library. TODO-5 remains open pending current-head
  validation and confirmation that the tested installed binary contains the
  same hook implementation. **Checkout-R/native-DLL pairing, 2026-10-18:**
  the same file also passed 46/46 with
  `pkgload::load_all("R/EDI", compile = FALSE)`, loading the current checkout's
  R source without compilation. `pkgload`'s temporary `EDI.so` had MD5
  `dd43c5d0e11708aea17ba82b900f66d1`, matching the installed EDI 1.0.3 DLL at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` exactly.
  This validates current R dispatch/test source against that installed native
  binary, not a current-head native build; the full benchmark and historical
  EDI 1.0.2 parity gates remain open.

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

  **Parity-comparator provenance guard, 2026-10-20 (harness subgate only):**
  `validate_parity_provenance()` checks the recorded package version against
  the referenced `DESCRIPTION` and recomputes the DLL SHA-256 when those
  referenced files still exist. The focused
  `test-todo58-parity-provenance-guard-reference.R` passed 8 assertions using
  temporary synthetic package/DLL artifacts: a matching pair is accepted,
  while changed DLL bytes and a changed package version are rejected. This
  verifies the comparator's local tamper-detection path only; it does not
  authenticate artifacts after their source files are unavailable, establish
  that either artifact is an authentic EDI installation, or provide any
  EDI 1.0.2 distribution-parity evidence. TODO-6's original-size benchmark
  and authentic 1.0.2 parity gates remain open.

  **Exact historical-baseline version guard, 2026-10-21:** broadened the
  existing synthetic comparator fixture with a coherent wrong-version case:
  both the old artifact's recorded package version and its synthetic
  `DESCRIPTION` say 1.0.1. The comparator rejects it because the baseline
  contract requires exactly EDI 1.0.2. The focused file passed 89
  expectations against installed EDI 1.0.3; it sources the checked-out
  benchmark script and tests synthetic artifacts, not a benchmark or EDI
  distribution parity. This closes only the exact-version rejection test gap;
  authentic 1.0.2 artifacts/vectors, quiet-host original-size timing, and
  current-source/native provenance remain open.

  **Retained full-size public benchmark, 2026-10-20 (failed speed gate):**
  read-only validation of `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv`
  (SHA-256
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`)
  found 30 rows: exactly one sample numbered 1–10 for each accepted case,
  with no duplicate `(case, sample)` keys and all rows using the manifest's
  original `n`, `B`, fixture seed, and row seed. The recorded benchmark-script
  SHA-256
  (`fda10ec6115507a446d120f5258eb4fe6038e00827cf8ba52ec9191a64064441`)
  matches the current harness. The output identifies installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  plus R-devel `r90668`, boot 1.3.32, survival 3.8.12, Linux/WSL2 host
  identity, and MKL BLAS identity. At this audit, that installed path's
  `DESCRIPTION` says it was built 2026-10-20 07:40:04 UTC; the CSV itself
  does not record that field. For each of ten alternating timing
  samples, `speedup` is `boot_complete_ms / EDI_procedure_ms`: the EDI timer
  covers the public `compute_bootstrap_confidence_interval()` call only
  (inference construction is separate), while the `boot` timer includes
  `boot::boot()` plus `boot.ci(type = "perc")`. Both sides restart from the
  accepted row seed; this is timing interleaving, not shared-index distribution
  parity. Median speedups are OLS 0.137x, logistic 1.030x, and Cox 0.392x.
  Thus the artifact establishes that OLS and Cox still miss the >=1x target;
  only logistic clears it. The CSV has no adjacent provenance sidecar, run
  timestamp, host-load/CPU-affinity/thread record, checkout HEAD/worktree
  fingerprint, or installed R-source/build identity. It therefore does not
  establish a quiet-host acceptance run despite carrying package/DLL, R,
  dependency, host, BLAS, script, and exact case-key provenance. No paired
  parity RDS or authentic installed EDI 1.0.2 package was found in the
  retained artifacts; do not treat this timing output as parity evidence.
  The artifact remains diagnostic and does not change thresholds or close
  TODO-6 / release TODO-58.

  **Retained per-fixture interval files, 2026-10-21 (not historical parity):**
  a bounded read-only inventory found
  `/tmp/edi_todo58_ols_b1000_20261020_{intervals,provenance}.csv`,
  `/tmp/edi_todo58_logistic_b500_20261020_{intervals,provenance}.csv`,
  `/tmp/edi_todo58_cox_b500_20261020_{intervals,provenance}.csv`, and
  `/tmp/edi_todo58_ols_b1000_20261020.csv`. Their small provenance
  rows identify installed EDI 1.0.3, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  `boot` 1.3.32, `survival` 3.8.12, R-devel `r90668`, and MKL BLAS; they do
  not identify an installed R-layer payload or an EDI 1.0.2 artifact. The
  interval files compare the EDI public interval, type-8 quantiles of EDI's
  own draws, an independent full `boot` stream, and `boot.ci()` applied to
  EDI's draws. EDI's public intervals agree with its own type-8 draw
  quantiles (exactly for OLS/Cox and within about 2.2e-11 for logistic),
  while the independent stream and `boot.ci` interpolation differ slightly.
  These are current-version diagnostic/reference outputs, not source-pinned
  old/new EDI distribution parity. The full-size timing CSV remains the only
  retained 10-sample public benchmark artifact and still lacks a sidecar,
  quiet-host evidence, and installed R-source identity.

  **Threshold provenance check, 2026-10-21:** Git history/blame traces the
  acceptance `OLS percentile CI >= 1x boot; logistic and Cox >= 1x boot` to
  the plan's initial 2026-10-07 user-decision commit
  `7083f7e328abe0af547c9c25766cb57ba1328def`. No later threshold change or
  alternative speed target was found in the linked plan/release history. The
  existing target is therefore retained; the recorded full-size medians
  (OLS 0.137x, logistic 1.030x, Cox 0.392x) leave OLS/Cox below it. No
  authentic EDI 1.0.2 package, source-pinned old/new parity RDS, or equivalent
  historical distribution artifact was found in the tracked inventory or the
  targeted retained TODO-58 scratch paths. Both TODO-6 parity and OLS/Cox
  speed gates remain open; no benchmark was run during this audit.

  **Source-path performance audit, 2026-10-21 (no benchmark):** the public
  percentile route obtains bootstrap estimates through
  `approximate_bootstrap_distribution_beta_hat_T()` and the reusable
  design-backed worker. The loader already subsets the cached full-data model
  matrix rather than rebuilding the formula/model matrix, and passes its
  per-draw rank certificate to `fit_with_hardened_qr_column_dropping()` so
  that wrapper need not repeat the same QR. The loader's per-draw rank check
  cannot safely be removed: deficient bootstrap samples must retain the
  historical rebuild-and-harden fallback. OLS still refits each resample;
  Cox uses the prebuilt C++ fitter with the `survival` R fallback, while the
  benchmark reference calls `survival::coxph.fit()`. No correctness-preserving
  R-only optimization was evident from this path audit; reducing loader data
  frame allocations would need class-specific parity evidence because the
  shared loader also refreshes the worker design state. The OLS/Cox >=1x speed
  gate remains failed/open, and profiling, authentic historical parity, and
  current-source/native validation remain outstanding. No behavior or
  acceptance threshold changed.

  **GitHub release-asset provenance, 2026-10-21 (metadata-only):** the
  official GitHub release `v1.0.2`
  (https://github.com/kapelner/EDI/releases/tag/v1.0.2; published
  2026-10-07 09:53:47 UTC) has one uploaded asset,
  `EDI_1.0.2.tar.gz`, size 3,263,678 bytes. GitHub's release-asset API
  (https://api.github.com/repos/kapelner/EDI/releases/assets/618268034)
  records uploader `kapelner` and digest
  `sha256:01f79c8d52678cbd95af1b7ed25609a8f1c340f059531939c9c82fddd5c47af9`,
  matching the existing local candidate's size and SHA-256. The release tag
  ref points directly to commit `903ced0404921b7f4a6b5a8b1f7d0a6702466a31`
  (not an annotated/signed tag); the asset digest authenticates the released
  source bytes, but no native binary or bootstrap vectors are attached. The
  only Actions run on that commit was Copilot Setup Steps
  (https://github.com/kapelner/EDI/actions/runs/37603732050), whose artifact
  metadata reports zero artifacts. The accepted vectors remain absent:
  OLS `n=1000, B=1000`, fixture/row seeds `22422/414230`; logistic
  `n=1000, B=500`, `19021/609739`; Cox `n=500, B=500`, `17961/628354`.
  The accepted manifest is defined in
  `R/benchmark/benchmark_todo58_public_bootstrap_ci.R::todo58_case_manifest()`.
  A local 2026-10-21 inventory found the retained 10-sample EDI 1.0.3-vs-`boot`
  artifact at `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv`
  (SHA-256 `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`);
  it stores interval/timing summaries, not raw bootstrap vectors. The other
  retained per-case files are interval and provenance summaries only. No
  accepted EDI 1.0.2 parity vectors were found locally. These timing artifacts
  do not satisfy the separate quiet-host timing gate. Therefore source-archive
  provenance is now established, but TODO-58 still
  requires a controlled run against this authenticated 1.0.2 source, retention
  of all three full distributions and RNG/package provenance, and exact parity
  comparison with current EDI. No archive download, R run, build, or install
  occurred during this audit.

  **Benchmark/parity acceptance recheck, 2026-10-21 (read-only):** the
  retained `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv` is present,
  31 lines (header + 30 samples: 10 each for OLS, logistic, Cox), and still
  hashes to `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`.
  It uses the accepted original-size manifest exactly: OLS
  `n=1000/B=1000/22422/414230`, logistic `1000/500/19021/609739`, Cox
  `500/500/17961/628354`. It records installed EDI 1.0.3 and DLL SHA-256,
  R/dependency versions, OS/kernel/architecture, BLAS, script path/hash, and
  construction/procedure/`boot` timings. The directory contains only this CSV;
  there is no `.provenance.rds` sidecar. Its recorded script SHA-256
  `fda10ec6115507a446d120f5258eb4fe6038e00827cf8ba52ec9191a64064441`
  matches neither the current worktree harness
  (`12a5872495f45822af387887eedeafd6e423b74a8b5e591d339ad28da83d7c89`)
  nor the tracked-HEAD harness
  (`ba7c13741384b9863b9baa5b9da2fef6d129851f85869bb1522b8a754f6d5b19`),
  and the CSV has no checkout/worktree identity, host-load, CPU-affinity, or
  thread-state fields. The current worktree harness now defines sidecar
  capture for loaded R-payload fingerprint, checkout status/diff identity,
  and host load/CPU affinity, but no retained run exercises those fields yet.
  Thus the old file is a full-size diagnostic, not
  quiet-host/current-source acceptance: OLS and Cox medians
  remain below the fixed 1x threshold (0.137x and 0.392x; logistic is 1.030x).
  The currently retained per-case CSVs are interval/provenance summaries, not
  bootstrap distributions; the previously cited combined B=64 parity CSV is
  absent. The locally retained EDI 1.0.2 source tarball is authenticated by
  the official GitHub release digest recorded above, but no accepted full-B
  vectors from that source exist. Consequently no artifact establishes both
  original-size timing acceptance and exact historical parity without new
  execution; thresholds and open gates are unchanged.

## Out of scope

- **Generic clone/subset fallback, audit 2026-10-20:** the ordinary
  resampling dispatcher uses the reusable worker only for inference classes
  that explicitly implement and pass `supports_reusable_bootstrap_worker()`;
  its fallback still calls `bootstrap_subset_inference()` per draw. That
  helper duplicates both the design and inference objects, and is also used
  by debug/reporting and other bootstrap families. A class-agnostic shortcut
  here is not a safe extension of the OLS/logistic/Cox worker optimization:
  those callers have different worker contracts and error/reporting behavior.
  Keep the fallback unchanged. Any future extension must first name the
  eligible inference classes and preserve their fixed-draw results and
  diagnostics against the existing clone path; add class-specific independent
  parity tests before measuring performance. This audit does not change
  TODO-58 acceptance or close its original-size public benchmark and EDI 1.0.2
  parity gates.

- The BCa jackknife cost (`type = "bca"` default): a definitional cost,
  revisit only if the percentile floor above is reached and BCa still
  trails `boot.ci(type = "bca")`.
- Bayesian-bootstrap weighted refits (`bayesian_bootstrap_performance.md`).
- Randomization-distribution plumbing (the cache-key hash of the
  permutation matrix and the no-op `subset_permutations` copy found in
  the same session): not yet planned anywhere; separate item.
