# Release Scope: v1.0.5

> **Depends on:** `release_v1_0_0.md` (ships first). No dependency on
> `release_v1_1_0.md` — this file was split out of it on 2026-09-23 (user
> decision) precisely so these fixes are not gated on that release's new
> capabilities. (Global ordering: see `_master.md`; this file draws a patch
> release line across it, parallel to and independent of v1.1.0.)

Split from `release_v1_1_0.md` on 2026-09-23, user decision: **v1.0.5 is
every correctness/hardening fix and audit-found bug in the v1.1.0 backlog,
with no new capability of its own; v1.1.0 keeps everything that adds new
inference-quality machinery.** The rule for what counts as "this file, not
v1.1.0": an item that fixes something already shipped in v1.0.0 behaving
wrongly (a bug, a dead/misfiring performance path, an unguarded numerical
edge case) — not a new correction family, new estimand, new response type,
or new diagnostic capability, all of which stay in `release_v1_1_0.md`.

Every item here is **independent of `release_v1_1_0.md`** (verified when each
was originally scoped into v1.1.0; nothing here depends on that release's
Phase 0 decision batch or its diagnostics-chain prerequisite). Explicit
intra-release ordering and shared validation gates are recorded in the
individual TODOs and their owning plans. This release can ship the moment its
own items are done and verified, without waiting on v1.1.0 — that independence
is the entire reason for the split. The original items were renumbered 1..16
in chronological "added" order; later items retain their subsequently
assigned numbers (including the documented 50/51 collision resolution). Each
item still names its owning plan file with that plan's own (unrenumbered) TODO
range, since the plan files' internal numbering did not change.

## Implementation TODOs

- [ ] TODO-1 (added 2026-08-27): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`** — `../bug_fix_plans/reusable_bootstrap.md →
  TODO-1..6`. The one class (of 51 live inference families, audited)
  missing the `get_bootstrap_worker_spec()` fast path
  `local_machine_optimization.md`'s shipped `tune_EDI_for_this_machine()`
  already relies on elsewhere; its jackknife originally rebuilt a fresh
  `Design`/`Inference` object and reran full column-selection from scratch
  per leave-one-out fold instead of reusing one warmed-up worker. Small,
  additive, R-layer only (no kernel change); must reproduce bit-identical
  jackknife results before/after (plan's TODO-4). **Verified NOT
  implemented, 2026-09-24**: `get_bootstrap_worker_spec()` — the specific
  method this plan says is missing — is still missing on the installed
  package. (The four generic reused-worker methods checked first,
  `supports_reusable_bootstrap_worker()` etc., exist, but that's a red
  herring — they're baseline mixin methods every class gets regardless of
  this fix.) Plan's own checklist: 0/6 checked.
  **Source-status reconciliation 2026-10-10:** the class now does opt into
  the worker contract and has two-matrix worker state/load/estimate methods.
  Its primary matrix deliberately retains candidate columns to mirror the
  ordinary per-fold fit, while the zero/one matrix retains the full-sample
  selected columns; rank-gated or unusable direct fits use the ordinary
  hardened fallback. The optional exhaustive reused-worker test's `n = 40`
  ZOIB comparison is not the diagnosed `n = 50` tuning fixture, so it cannot
  close exact-fixture parity or speedup: a failed direct fit there can still
  incur the ordinary fallback. Installed-package checks passed 30 assertions
  in `test-non-param-boot-reusable-worker-distribution-driver-and-worker-estimate-reference.R`
  and 19 in `test-bayesian-bootstrap-non-reusable-worker-debug-path.R` against
  EDI v1.0.3. That installation lacks current checkout design classes, and
  these suites do not cover the diagnosed `n = 50` parity/performance fixture.
  The linked performance/parity study, tuning exclusion removal, and tuning
  run remain open pending validation against a matching build.
  **Exact-fixture probe 2026-10-14:** with the default tuning seed `20264492`,
  the 50 leave-one-out values were finite and bit-identical between the
  reusable class and an R6 subclass forcing the legacy route, but both public
  jackknife estimates were `NA` (`jackknife_extreme_summary`). The reusable
  route took 11.051s versus 6.617s for legacy; tracing counted 68 versus 60
  calls to `fast_zero_one_inflated_beta_cpp()` (eight extra fallback fits).
  This disproves the hoped-for speedup on the diagnosed fixture. TODO-1 stays
  open while the class-specific cost, non-NA parity fixture, exclusion removal,
  and end-to-end tuning behavior remain unresolved.
  **Fallback-reason observer, 2026-10-21:** one bounded exact-seed run of
  `/tmp/edi_todo3_fallback_observer.R` (`timeout 180s Rscript ...`, with
  `pkgload::load_all("R/EDI", compile = FALSE)`) recorded 50 `n=49`
  estimate-only calls: 42 finite and 8 nonfinite treatment coefficients;
  no NULL/missing/error cases. Each of the 8 direct nonfinite results was
  followed by three ordinary refit calls (two nonfinite `p=4`, then one
  finite `p=3`), 24 ordinary calls total. The public summary stayed `NA`
  (`jackknife_extreme_summary`). CSV:
  `/tmp/edi-todo3-fallback-observer-20261021.csv`. The checkout R namespace
  was `/home/kapelner/workspace/EDI/R/EDI`, EDI version 1.0.3; loaded DLL
  `/tmp/RtmpORtmTo/pkgload3f2ea126/EDI.so`, MD5
  `bfea6f47ab8b27618d5d8633e9021f91`. This localizes the direct-fit
  nonfinite-coefficient fallback on the reusable route; it is not a timing
  run and does not reconcile the historical 68/60 cross-route call totals.
  No estimator behavior changed; TODO-3 performance/parity acceptance stays
  open.
  **Dual-regime parity test, 2026-10-20:** the linked plan's TODO-4 now has
  a public jackknife estimate/SE/Wald-p bit-identical comparison against the
  forced-legacy route on both an interior-only fixture and a boundary-mass,
  two-component rank-fallback fixture. The 55-assertion file passed with
  current checkout R sources via `pkgload::load_all(..., compile = FALSE)`;
  the temporary EDI DLL matched installed v1.0.3 (MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`). This closes the linked plan's
  dual-regime R-layer parity-test gate only. It does not resolve TODO-3's
  exact tuning fixture (both jackknife summaries are still `NA`, and the
  reusable route was slower), so TODO-5's exclusion removal and TODO-6's
  end-to-end tuning run remain blocked pending a cost-effective, non-NA
  exact-fixture result.
  **Installed migration-golden rerun with DLL provenance, 2026-10-20:** the
  same focused file passed 55 assertions (0 failures, warnings, or skips;
  exit 0) against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` MD5:
  `a75519a9256c0b3121398032314291d4`; SHA-256:
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; this run used
  the installed artifact, not checkout R/native source. The diagnosed
  seed-20264492 case remains NA for both public summaries and slower on the
  reusable route; performance, exclusion-removal, and end-to-end tuning gates
  remain open.
  The finite parity fixture is distinct: `InferencePropZeroOneInflatedBetaRegr`
  on `DesignFixedBernoulli`, response type `proportion`, `n=50`, seed
  `20264507`, with constructor-default `model_formula` and
  `model_formula_zero_one`, no boundary responses, and exact comparisons for
  `compute_jackknife_estimate`, `compute_jackknife_std_error`, and
  `compute_jackknife_wald_two_sided_pval`. Its `x1,x2 ~ N(0,1)` response uses
  `mu=plogis(0.2 + 0.5*w + 0.3*x1 - 0.2*x2)` and
  `rbeta(mu*8, (1-mu)*8)` clipped to `[0.02,0.98]`. This is finite parity
  evidence only, not the diagnosed `20264492` fixture or speedup acceptance.
  **Installed-artifact focused rerun, 2026-10-21:** the existing
  `R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R`
  passed 67 assertions (0 failures, warnings, or skips) against installed EDI
  1.0.3. Loaded DLL MD5 was `ea0e2f72d87d401db15557e0ecc151c9`. The initially
  requested `R/EDI/tests/testthat/` path does not contain this file; the
  existing extended-suite path above was used. This strengthens installed
  migration-golden evidence only; it does not close the exact tuning fixture,
  speedup, exclusion-removal, or end-to-end gates.
  **Reinstalled-artifact rerun, 2026-10-21:** after the later EDI reinstall,
  the same test again passed all 67 assertions against installed EDI 1.0.3;
  its loaded DLL SHA-256 is
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`, also
  byte-identical to checkout `R/EDI/src/EDI.so`. This verifies the focused
  migration golden on the current installed native artifact, but the exact
  tuning fixture remains non-NA-unresolved and the speed/exclusion/end-to-end
  gates remain open.
  **Checkout-R exact-fixture rerun, 2026-10-21:** after confirming no
  competing R/Rscript process, ran
  `timeout 180s Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE); testthat::test_file("R/package_tests/testthat_bulk/test-zoib-jackknife-reusable-worker-migration-golden.R", reporter = "summary")'`.
  All 80 assertions passed (0 failures, warnings, or skips; exit 0). This
  exercises the exact-seed per-fold parity and documented NA-summary contract
  against checkout R sources with compilation disabled. The run did not
  capture a loaded-DLL path/hash and is not a native rebuild attestation.
  It does not resolve the 11.051s versus 6.617s performance result or justify
  removing the tuning exclusion; TODO-3/5/6 remain open.
  **Generic worker-state guard contract, 2026-10-21:**
  `test-non-param-boot-reusable-worker-state-validation-guards-reference.R`
  passed all 8 assertions (0 failures, warnings, or skips; exit 0) against
  installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL MD5:
  `ea0e2f72d87d401db15557e0ecc151c9`. This closes only the generic installed-
  artifact worker-state validation-guard subgate; it does not validate the
  checkout's ZOIB worker implementation or current-source/native parity, and
  does not affect the exact-fixture, performance, exclusion-removal, or
  end-to-end tuning gates.
  **Installed driver/worker-estimate contract rerun, 2026-10-21:**
  `test-non-param-boot-reusable-worker-distribution-driver-and-worker-estimate-reference.R`
  passed 55 assertions (0 failures, warnings, or skips; exit 0) with
  `testthat::test_file(..., package = "EDI")`. The process loaded installed
  EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` (DLL MD5
  `ea0e2f72d87d401db15557e0ecc151c9`); the test also extracts the checkout's
  pure-R distribution-driver method for its source-level batching/guard
  checks. This adds generic driver, chunking, error-recovery, and worker
  estimate contract evidence only; it does not test the ZOIB two-matrix
  invariant, the diagnosed tuning fixture, or current-checkout native parity.
  TODO-2's wider matrix invariant and TODO-3/5/6 tuning/performance gates stay
  open.
  **Current-checkout R-source overlay, 2026-10-21:** with no active
  R/Rscript job, `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`
  followed by the same migration-golden test passed all 67 assertions
  (0 failures, warnings, or skips; exit 0). The loaded temporary DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94` is
  identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; no compile/install occurred.
  This covers current checkout R-layer worker behavior, finite legacy parity,
  the dual-matrix alignment/rank-fallback fixture, and the summary guard over
  the existing native DLL. It does not establish performance, exclusion
  removal, end-to-end tuning, or CI/coverage confirmation; TODO-1 remains open.
  **Exact diagnosed-seed migration regression, 2026-10-21:** the existing
  `test-zoib-jackknife-reusable-worker-migration-golden.R` now checks the
  `proportion`, `n=50`, seed `20264492` fixture's 50 finite per-fold values
  bit-identically across reusable and forced-legacy routes, as well as the
  matching `NA` public summaries and `jackknife_extreme_summary` reason. The
  focused file passed 80 expectations (0 failures, warnings, or skips; exit 0)
  against installed EDI 1.0.3 with
  `testthat::test_file(..., package = "EDI", reporter = "summary")`; no
  build/install occurred and no DLL identity was captured for this run. This
  closes the exact-seed R-level parity regression gap only, not the current
  checkout R-layer attestation, performance target, tuning exclusion, or
  end-to-end tuning gate. TODO-1 remains open.
- [ ] TODO-2 (added 2026-08-30, user decision): **Randomization CI
  affine-shift reuse** — `randomization_ci_affine_shift_reuse.md →
  TODO-1..7` (plus a decision-gated TODO-8). The fast path at
  `inference_all_abstract_rand.R:436` (`t0s = t0s_rand + delta`) is dead —
  `cached_values$t0s_rand` has never been assigned a value, so the
  δ-keyed distribution cache misses on every bisection step and a
  randomization CI costs ~20–35 full `r`-permutation distributions. For
  statistics linear in `y` with `w` in the design (simple mean diff,
  average diff, OLS, Lin) `t0_b(δ) = t0_b(0) + δ·(1 − c_b)` is an exact
  identity, so one full δ = 0 distribution serves the whole search. Adds a
  `supports_additive_delta_shift()` predicate (default `FALSE`; never for
  rank statistics, transformed scales, custom statistics, non-linear
  models), populates `t0s_rand` only from a full-`r` δ = 0 call, and forces
  that one full call in `build_randomization_ci_search_bounds()`. Expected
  20–30× on `compute_confidence_interval_rand()` for those classes.
  Equivalence is to floating point, not bit-for-bit (documented default
  change; tolerances in the plan). KK combined estimators are tier 2,
  opt-in after numerical verification. Once this lands, a tier-1 class's
  `p(δ)` is an exact step function of δ, opening a direct order-statistic
  inversion recorded as the plan's decision-gated TODO-8. **Verified NOT
  implemented, 2026-09-24**: `supports_additive_delta_shift()` does not
  exist anywhere (checked at the instance level, not just the generator),
  and `cached_values$t0s_rand` never gets populated after a rand-CI call.
  Plan's own checklist: 0/8 checked.

  **Implemented at source level, 2026-10-09:** TODO-1..5 and TODO-7 now
  implement the signed affine identity, cache it only for the same full
  permutation set, and cover tier-1 plus the numerically verified KK OLS
  one-likelihood opt-in. The CI warm-up verifies that a complete cache also
  has matching slopes and the CI permutation signature before reusing it. The
  KK-GEE stale read was removed. TODO-6's full source-loaded benchmark ran on
  2026-10-13 (`compile = FALSE`, three repetitions per `n/r` cell); median
  speedups were 1.13–1.59× for average difference and 1.05–2.14× for OLS,
  below the plan's projected 20–30×. The OLS slope calculation was then
  vectorized by residualizing the fixed covariate block once, with the
  per-permutation QR reference and tier-1 equivalence tests passing. TODO-6
  records the complete measurements; the projected gain was not achieved, so
  this release item remains unchecked pending reconciliation of that target.
  The focused `test-ci-rand.R` suite also passed 80 assertions against the
  currently installed EDI 1.0.3 package on 2026-10-14. The working tree has no
  randomization-CI source changes pending; this does not resolve the measured
  speedup versus the original 20–30× expectation or the documentation claim.
  A bounded installed-package check on 2026-10-15 (EDI 1.0.3; installed
  `EDI.so` mtime 14:09:05 +0300) at `n=500, r=1001`, three interleaved
  pairs with a warm-up per path, measured 1.12× for
  `InferenceAllSimpleAverageDiff` (0.108 s affine vs. 0.121 s general) and
  1.82× for `InferenceContinOLS` (0.084 s vs. 0.153 s). Results are in
  `/tmp/edi-todo2-installed-benchmark-20261015.csv`; the harness is
  `/tmp/edi-todo2-installed-benchmark.R`. This independently confirms a
  modest gain in the installed package but does not meet the 20–30× target.
  An exploratory low-sample call-level profile on 2026-10-16 found material
  GC/allocation and shared CI p-value/cache work, but its few samples do not
  establish a stable per-function attribution (details in the linked plan).
  Keep TODO-2 open pending reconciling the target and documentation (or an
  explicit owner decision to accept the smaller gain).
  **Second-pass provenance audit, 2026-10-21:** the checked-in harness
  available for the 2026-10-13 full-grid run (introduced at commit `c189e94f`,
  blob `41611163047d2940553497a6f27efaffcbc1bf88`) timed the end-to-end
  `compute_rand_confidence_interval()` call on fresh objects sharing each
  cell's design and fixed permutation matrix. It ran three samples per route
  in a fixed affine-then-general order, without warm-ups or alternating order;
  therefore the feature-plan phrase “three interleaved repetitions” is not
  supported by that runner. The harness emits only per-cell medians/ratios,
  and no full-grid stdout/log or individual timing rows were found among the
  retained local TODO-2 artifacts, so exact historical samples and runtime
  identity cannot be independently reconciled. The 2026-10-15 installed
  1.0.3 three-pair cell also times the public CI operation with shared fixed
  permutations, but is only `n=500, r=1001` and uses fresh warm-ups plus
  alternating order; compare it as a separate, better-balanced single-cell
  check, not as a replication of the full grid. The 20–30× figure is a
  projected reduction in repeated full-distribution work (~20–35 per CI to
  one), not an observed runtime ratio: affine CI still does slope/cache work
  and per-delta p-value/search work. Keep the target decision open.
  **Maintainer target decision pending:** accept/restated target for the
  measured 1.05–2.14× OLS and 1.13–1.59× average-difference gains, or retain
  the original 20–30× target and optimize further; no option is selected.
  See `../new_feature_plans/randomization_ci_affine_shift_reuse.md → TODO-6`.
  The decision-gated direct-inversion TODO-8 remains deliberately out of
  scope. **Source-level micro-optimization, 2026-10-16:** the randomization
  p-value path now reuses the permutation signature it already computed when
  building the distribution cache key, avoiding the duplicate full-content
  hash in that call. The regression covers key identity, mutation sensitivity,
  and NULL-key compatibility. Scoped diff checks and R parsing pass, but the
  installed package cannot validate unbuilt checkout edits; no test or
  benchmark was run after the change. This is not evidence toward the 20–30×
  target, which remains open. **Post-change focused check, 2026-10-18:**
  source-loaded validation of `test-stable-signature-full-content-hash-
  sensitivity-and-cache-key-components-reference.R` passed 37 assertions
  with compilation disabled. It covers the precomputed permutation-signature
  path, parity with the legacy omitted-signature path, full-content mutation
  sensitivity, and NULL-signature compatibility. This is R-source evidence
  against installed EDI 1.0.3's native library, not current-native validation
  or benchmark acceptance. **Focused cache-write guard, 2026-10-20:** the
  source-loaded `test-ci-rand.R` suite now passes 89 expectations after adding
  a public nonzero-`delta` p-value call that must leave the delta-zero affine
  cache vectors and permutation signature unset. Compilation was disabled;
  native calls still used installed EDI 1.0.3, so this is not current-native
  validation. The measured-speed target/maintainer decision and TODO-6
  benchmark reconciliation remain open. **Installed correctness recheck,
  2026-10-20:** `testthat::test_file("R/package_tests/testthat_bulk/test-ci-rand.R")`
  passed against installed EDI 1.0.3 without source loading or compilation.
  Package path was `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`;
  loaded DLL SHA-256 was
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  This confirms focused installed-artifact correctness only; performance-target
  reconciliation and maintainer decision remain open. **Current-checkout
  source/native recheck, 2026-10-20:** reran the complete test file after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; it finished
  `DONE` with no failures. The R namespace was
  `/home/kapelner/workspace/EDI/R/EDI`; the temporary loaded DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  matching the user-rebuilt installed artifact and checkout `R/EDI/src/EDI.so`
  as byte-verified under TODO-3. This adds current-checkout R-layer correctness
  evidence against the matching native artifact, not performance acceptance;
  the target decision and TODO-6 benchmark reconciliation remain open. No
  compilation or installation occurred.
  **Installed stable-signature/cache-key correctness check, 2026-10-21:**
  `test-stable-signature-full-content-hash-sensitivity-and-cache-key-components-reference.R`
  passed 37 assertions (0 failures, warnings, or skips; exit 0) directly
  against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded DLL MD5:
  `ea0e2f72d87d401db15557e0ecc151c9`; SHA-256:
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This covers full-content signature sensitivity, precomputed-signature/cache-
  key identity, key-component differentiation, and NULL-signature behavior.
  It establishes installed-artifact correctness only, not public-CI affine
  equivalence or the measured speed target; TODO-2's performance decision and
  benchmark reconciliation remain open. **Installed public-CI correctness
  rerun, 2026-10-21:** `test-ci-rand.R` passed 110 assertions (0 failures,
  warnings, or skips; exit 0) via `testthat::test_file(..., package = "EDI")`
  against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL MD5
  `ea0e2f72d87d401db15557e0ecc151c9`, SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This is public affine-CI correctness evidence for the installed artifact,
  not proof of installed R-source identity/current-checkout native parity and
  not performance acceptance. The 20–30× target decision and benchmark
  reconciliation remain open.
  **Target-origin/acceptance brief, 2026-10-21:** the original 20–30× figure
  is a projection from eliminating roughly 20–35 full-`r` permutation
  distributions per CI search (one full `delta = 0` distribution reused via
  the affine identity); it was not a measured speedup. The 2026-10-13 full
  18-cell source-loaded run used the earlier harness: three measured calls per
  route/cell in fixed affine-then-general order, without a warm-up. It measured
  1.13–1.59× for average difference and 1.05–2.14× for OLS; the later quick
  run used the warmed, alternating-order harness and measured 1.33×/1.42×,
  while the separate installed `n=500, r=1001` check
  measured 1.12×/1.82×. These are distinct workload/protocol samples, not one
  pooled estimate. The linked plan attributes the gap plausibly to shared CI
  setup/search and p-value/cache work, but the original work-count argument
  did not establish that these costs were negligible. Maintainer choice
  remains: accept and restate the workload-specific measured target/documentation,
  or retain 20–30× and authorize further optimization. No choice or new
  benchmark is authorized by this reconciliation.
  **Post-reinstall focused correctness rerun, 2026-10-21:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-ci-rand.R",
  reporter = "summary")` completed `DONE` (exit 0) against installed EDI
  1.0.3, without `pkgload`, build, or install. Package path:
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded `EDI.so`
  SHA-256 `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`
  (14,727,184 bytes; installed `DESCRIPTION` Built `2026-10-21 11:12:19 UTC`).
  This rechecks focused public affine-CI correctness on the latest installed
  artifact only. It does not prove installed R-source identity/current-source
  native parity, measure performance, or resolve the target/documentation
  decision; TODO-2 stays open.
- [ ] TODO-3 (added 2026-08-30, user decision): **Wire the unused OLS
  randomization-distribution kernel; triage dead kernels** —
  `ols_randomization_distr_cpp_wiring.md → TODO-1..6`.
  **Historical status, now corrected:** `compute_ols_distr_parallel_cpp`
  (`src/ols_distr_parallel.cpp:15`) was exported but unused, while
  `InferenceContinOLS` fell through to the R-level reused-worker loop
  (`inference_all_abstract_rand.R:708-800`), paying ~100–200 µs of R6
  bookkeeping per replicate around a ~5 µs solve. The source fix now adds
  `compute_fast_randomization_distr()` on the Poisson pattern
  (`inference_count_poisson.R:839`), passing the hardened covariate block and
  adding a per-replicate rank guard so `NA` patterns match the worker. The
  implementation, parity tests, and measured 43.07×/54.30× one-/four-core
  speedups are recorded below. The eight *other* exports without a production
  caller still need a wire/delete disposition; TODO-6's separate Lin stretch
  decision also remains open.
  **Verified NOT implemented —
  and actively broken, 2026-09-24**: `compute_fast_randomization_distr()`
  shows as present on `InferenceContinOLS`'s class *generator* (a static
  existence check), but throws `"attempt to apply non-function"` — one of
  the audit's own `programming_error` patterns — when called on a real
  instance with the correct dispatch arguments. Measured consequence: this
  class's randomization p-value took 2.28s for `r=2001` vs. 0.003s for a
  comparable simple mean-difference statistic (~800× slower, not 20–50×
  faster) — it silently falls back to the slow R loop every time (the
  generic dispatcher catches the error, so calls don't crash, they're just
  never actually fast). Plan's own checklist: 0/6 checked.
  **Source implementation 2026-10-10:** the OLS class now calls the batch
  kernel on its hardened covariate matrix for untransformed, nonmatching
  draws. The kernel returns `NA` for one-arm or rank-deficient permutations,
  and source regressions cover those guards plus fast/worker parity. The
  focused kernel-contract, end-to-end OLS p-value/CI parity, and
  parallel-threshold suites passed source-loaded on 2026-10-13 with
  `compile = FALSE`, using the installed native library. No compile/rebuild
  was performed. The full parameter matrix was added to
  `test-parallel-distribution-kernel-contracts.R` and passed on 2026-10-14
  against the reinstalled package (`n = 48`, 8 permutations, `p = 0/1/5`,
  `harden = TRUE/FALSE`, `delta = 0/0.5`). TODO-5's full end-to-end
  parameter-grid benchmark also passed on 2026-10-14: all p-values matched,
  with median speedups of 43.07× at one core and 54.30× at four cores. Results
  are recorded in `benchmark_model_fits.md`. **Caller correction, 2026-10-18:**
  `compute_ols_bootstrap_parallel_cpp` is used by the ordinary OLS percentile-
  bootstrap path (`InferenceContinOLS$compute_fast_non_param_bootstrap_distr`);
  it is distinct from the randomization-bootstrap kernel and is not a dead
  export. The eight genuinely unused candidates have test/benchmark/profiler
  references but no production inference callers; the two Wilcoxon kernels
  are superseded by the HL path. Deletion would require
  migrating/removing the direct contract tests and regenerating Rcpp
  exports/unity wrappers. That cleanup is still open and requires explicit
  permission for generated-code changes; this release checkbox remains open.
  Additional installed-package
  verification on 2026-10-14 passed 54 assertions in
  `test-parallel-distribution-kernel-contracts.R` and 31 in
  `test-resampling-parallel-threshold-contracts.R` against EDI 1.0.3, without
  compiling or installing. **TODO-3 evidence reconciliation, 2026-10-16:**
  the equivalence subchecks are satisfied by the recorded installed-package
  matrix/parity evidence and TODO-5's benchmark. At the time, these results did
  not validate native code from the current checkout. The focused
  current-checkout R/native runtime subgate was subsequently exercised and
  recorded below; the parent remains unchecked for TODO-4's dead-export
  disposition and the separate TODO-6 Lin stretch decision.
  **R-layer fallback regression, 2026-10-20:** the focused
  `test-parallel-distribution-kernel-contracts.R` passed 65 assertions after
  adding checks that `InferenceContinOLS` returns `NULL` for missing `w_mat`,
  a row-mismatched `w_mat`, and a zero-column batch, matching its explicit
  pre-native fallback guards. It was run with
  `pkgload::load_all("R/EDI", compile = FALSE)` and therefore exercised
  checkout R source against the existing EDI 1.0.3 native library; no build or
  install occurred. The source namespace was
  `/home/kapelner/workspace/EDI/R/EDI`; the loaded library was
  `/tmp/RtmpoHuOG2/pkgload81b622b8d75a6/EDI.so`, MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`. This does not close current-head native
  validation or the eight-export disposition, both of which remain open.
  **Installed-native recheck, 2026-10-20:**
  `test-kk-ols-one-lik-fast-randomization-distr-reused-worker-reference.R`
  passed 8 expectations and
  `test-parallel-distribution-kernel-contracts.R` passed 65 expectations
  (0 failures, warnings, or skips) via `testthat::test_file()` against
  installed EDI 1.0.3. Both processes loaded
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; `EDI.so` was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, MD5
  `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`,
  size 14,727,184 bytes, mtime `2026-10-20 09:38:02 +0300`. This confirms
  focused parity and kernel-edge contracts in that installed artifact. A
  direct byte comparison confirmed the installed `EDI.so` is identical to
  checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; both hashes are the SHA-256
  above and `cmp -s` returned identical. The shared worktree has modifications
  in `R/EDI/R/inference_all_abstract_rand.R` and
  `test-parallel-distribution-kernel-contracts.R`; the test namespace was the
  installed package rather than checkout R source. This closes the native DLL
  identity gap for these focused tests, but does not establish checkout
  R-dispatch identity or broader matrix completion. No compilation,
  installation, or canonical output write occurred. The eight-export
  disposition and TODO-6 owner decision remain open.
  **Fresh user-managed rebuild/reinstall validation, 2026-10-20:** after the
  user reported recompiling and reinstalling EDI, both focused suites were
  rerun against installed EDI 1.0.3: the OLS reused-worker test passed 8
  expectations and the kernel-contract test passed 65 (0 failures, warnings,
  or skips). Installed `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  matches checkout `R/EDI/src/EDI.so` byte-for-byte; install `Built` time was
  `2026-10-20 07:40:04 UTC`. This validates the freshly installed native
  artifact for these focused cases. It does not settle the eight-export
  disposition or TODO-6 Lin stretch decision; no build/install was performed
  by the agent.
  - [x] Rerun the OLS kernel parity/edge matrix and public randomization test
    against the freshly user-rebuilt/reinstalled artifact. See the
    2026-10-20 fresh-build evidence above; this closes only the current native
    validation subgate.
  - [x] Recheck the kernel-contract suite with current checkout R sources and
    `compile = FALSE`; on 2026-10-20 all 65 assertions passed. The source
    namespace was `/home/kapelner/workspace/EDI/R/EDI`; the loaded temporary
    DLL SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
    matched both the installed user-rebuilt `EDI.so` and checkout
    `R/EDI/src/EDI.so` byte-for-byte. This closes focused R/native provenance
    for that suite only, not unrun cases or the remaining owner decisions.
    The recorded hashes establish native artifact identity and test execution;
    no independent compiler-input manifest/source-hash-at-build record was
    captured, so they should not be generalized into full source-to-binary
    provenance or broad TODO-3 completion.
  - [ ] Decide the disposition of the eight genuinely unused exports; only
    after approval, migrate their direct tests/benchmarks, update Rcpp
    registration/generated wrappers, and verify no production callers remain.
    **Read-only inventory recheck, 2026-10-20:** the exact names are
    `compute_wilcox_distr_parallel_cpp`,
    `compute_wilcox_distr_from_list_parallel_cpp`,
    `base_bootstrap_loop_cpp`, `matching_bootstrap_loop_cpp`,
    `fill_i_b_with_matches_loop_cpp`, `bisection_ci_parallel_cpp`,
    `bisection_ci_single_bound_cpp`, and `bisection_ci_loop_cpp`. Each has
    existing direct wrapper-contract tests; none has a production inference
    caller. They are registered Rcpp/native wrappers, not explicit
    `NAMESPACE` public exports. The plan's delete recommendations are not
    maintainer approval, so this is a wire/delete decision gate, not a
    missing-coverage-only task. Definition/test mapping and the retained
    `compute_ols_bootstrap_parallel_cpp` exception are in the linked plan.
    **Exhaustive caller/export/document recheck, 2026-10-21:** indexed
    `trail grep` for each of the eight names and a repository-wide `rg`
    confirm no production inference caller and no `NAMESPACE` export. Their
    direct contract-test references are unchanged: the Wilcoxon pair is in
    `test-parallel-distribution-kernel-contracts.R` and
    `test-resampling-parallel-threshold-contracts.R`; the bootstrap-loop pair
    is in `test-resampling-callback-recovery-contracts.R` and
    `test-resampling-kernel-contracts.R` (the base loop also has a profiler
    entry); fill-in is in `test-bootstrap-index-fillin-and-bisection-loop.R`
    and `test-resampling-kernel-contracts.R`; and the bisection trio spans
    `test-bisection-tail-and-discontinuity-regressions.R`,
    `test-bootstrap-index-fillin-and-bisection-loop.R`,
    `test-resampling-kernel-contracts.R`, and
    `test-resampling-parallel-threshold-contracts.R`. Additional non-caller
    references matter for cleanup: the three bisection wrappers have generated
    `R/EDI/man/*.Rd` help aliases marked internal; the Wilcoxon kernel is still
    named as a possible GPU prototype in `gpu_optimizations.md`; and other
    plans/catalogs document these kernels. Recommendation: do not auto-delete
    or treat the existing plan's delete labels as approval. Keep the owner
    disposition gate; if deletion is authorized, migrate direct tests and
    profiler use, update/remove generated help and roadmap references, then
    regenerate Rcpp registration/wrappers and unity grouping together. The
    separate `compute_ols_distr_parallel_cpp` wiring and live
    `compute_ols_bootstrap_parallel_cpp` percentile-bootstrap caller are not
    deletion candidates.
  - [ ] Obtain the separate owner decision on TODO-6's Lin stretch target and
    align the release claim with that decision.
- [ ] TODO-4 (added 2026-08-30; source fixed 2026-10-08; validation in progress 2026-10-20): **Guard the unguarded
  information-matrix inverses** — `../bug_fix_plans/guard_unguarded_information_inverse.md
  → TODO-1..6`. Correctness, not performance. `fast_negbin_regression.cpp:485`
  inverts the free-parameter information block with a bare `.inverse()`
  and no invertibility check (its own roxygen admits it); the same pattern
  is at `fast_zinb.cpp:457`, `fast_zero_augmented_poisson.cpp:340`/`:566`,
  and `fast_beta_regression.cpp:643`, while Cox, ordinal, and ZOIB check
  `FullPivLU::isInvertible()` and return a `NaN` covariance. A
  near-singular block today yields a *finite, wildly wrong* SE with no
  warning. One shared `invert_free_information()` helper in
  `_helper_functions_core.h` — `FullPivLU` for the decision, the original
  `.inverse()` for the value so every invertible fit stays bit-for-bit —
  applied at the five sites, plus tests that a duplicated-column
  `harden = FALSE` design now yields `NA` SE/CI, and roxygen rewrites.
  **Verified NOT implemented, 2026-09-24**: an exact-duplicate-column
  design (guaranteed-singular information block) on `InferenceCountNegBin`
  with `harden = FALSE` still returns a finite SE (0.236), not `NA`.
  Plan's own checklist: 0/6 checked (TODO-6, confirming the rejection reason names, added 2026-09-24).

  **Requirement (added 2026-09-24, user decision; reason naming checked
  same day):** the guard's rejections must be surfaced as typed SE
  nonestimability through the existing `cache_nonestimable_se()` (R-side,
  using each class's `<prefix>_standard_error_unavailable` string, default
  `standard_error_unavailable`), not a new ad-hoc flag. The C++ helper must
  also return an invertible/not status alongside the `NaN` inverse, so the
  v1.1.0 `SolverDiagnostics` component
  (`../new_feature_plans/optimizer_diagnostics_report.md → TODO-3`) can
  classify "singular information" later without rework. No shared
  "singular information" reason exists in the code today; see the plan's
  "Diagnostics coordination" section. The diagnostics chain itself stays in
  v1.1.0.

  **Implemented 2026-10-08:** a portable `invert_free_information()` uses
  `FullPivLU` for the accept/reject decision while retaining the prior
  `.inverse()` values for accepted inputs. All five bare sites and the evolved
  R-facing ZINB covariance are guarded, kernels expose
  `information_invertible`, and wrappers use the existing typed
  `model_standard_error_unavailable` paths. A high-level NegBin `harden =
  FALSE` edge was found and fixed on 2026-10-14: when the native guard rejects
  the information matrix, the wrapper now preserves the finite point estimate
  but caches typed SE non-estimability. After the user's 2026-10-14 reinstall,
  the information-inverse test passed all 30 assertions, the information-matrix
  extraction/fallback suite passed 48, and the solve-cascade reference passed 4
  against the installed native library; Codex did not compile/install. The
  additional negative-binomial and ZINB Poisson-boundary acceptance suites
  passed 11 and 8 assertions, respectively, against installed EDI v1.0.3.
  Added `test-information-inverse-edge-cases.R` for a boundary-excluded
  zero-dimensional free block and rejection of non-finite information through
  the installed public NegBin kernel; it passed 11 assertions without failures,
  warnings, or skips, including a finite-input fixture that yields a literal
  `Inf` information entry and verifies `information_invertible = FALSE` with
  all-`NaN` covariance. `test-information-inverse-inference-typed-guards.R`
  adds runtime typed SE/CI coverage for Beta, Zero-Inflated Poisson, and
  Hurdle Poisson, passing 22 assertions; together with the earlier NegBin
  regression, these paths preserve finite point estimates and surface the
  typed `model_standard_error_unavailable` reason. The zero-augmented public
  CI follows its documented bootstrap fallback, warns, and returns NA
  endpoints. ZINB typed SE/CI coverage was then added using a duplicate
  conditional covariate; the R override preserves the finite estimate, records
  `model_standard_error_unavailable`, and keeps the public bootstrap fallback.
  The typed-guard test passed 30 assertions with the checkout's R class
  source-overlaid on installed EDI v1.0.3 (installed native kernels; no
  compile/install). Plain installed-namespace execution still used the older
  class at that checkpoint. The full before/after sweep was still open at that
  checkpoint; the later fixture-union replay below broadens the evidence but
  is not exhaustive. The new literal-Inf assertion passed against the installed
  EDI v1.0.3 binary, whose metadata reports a Sep 20 native build; it confirms
  the behavior of the available binary, not the current source revision's
  native migration.
  **Installed-native focused recheck, 2026-10-20:** the solve-fallback test
  passed 4 assertions, the information-matrix extraction/fallback test passed
  48, `test-information-inverse-guard.R` passed 33, and
  `test-information-inverse-edge-cases.R` passed 11 (96 total; no failures,
  warnings, or skips) against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Its loaded DLL was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  This confirms behavior of that installed artifact only; the provenance-pinned
  current-head before/after `with_var` sweep remains open, so release TODO-4
  remains unchecked. No build/install occurred. TODO-17's Wilcoxon-specific
  maintainer decision/calibration gate is separate and unchanged.
  **Independent affected-kernel references, 2026-10-20:** against the same
  installed artifact, the Beta `with_var` reference test passed 18 assertions;
  the zero-augmented Poisson kernel/reference test passed 20 assertions with
  three upstream `pscl` deprecated-`.Names` warnings. These do not establish
  the required before/after identity across every `with_var` fixture.
  **Fresh user-managed rebuild/reinstall guard recheck, 2026-10-20:**
  `test-information-inverse-guard.R` passed 33 assertions,
  `test-information-inverse-edge-cases.R` passed 11, the Beta `with_var`
  reference passed 18, and the zero-augmented Poisson kernel/reference passed
  20 (82 assertions total; 0 failures, 3 upstream `pscl` deprecation
  warnings). Installed EDI 1.0.3 `EDI.so` SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to checkout `R/EDI/src/EDI.so`; install `Built` time was
  `2026-10-20 07:40:04 UTC`. This validates current installed guard/kernel
  behavior. No build/install was performed by the agent.
  **Installed-package focused recheck, 2026-10-21:**
  `timeout 180s Rscript -e 'library(EDI); ...; testthat::test_file("R/EDI/tests/testthat/test-information-inverse-guard.R", reporter = "summary")'`
  passed all 33 expectations (0 failures, warnings, or skips). The test ran
  against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded `EDI.so`
  SHA-256 `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`). This is installed-artifact
  evidence only and does not establish the installed R-source/build chain or
  replace the pending provenance-pinned before/after `with_var` inventory.
  No build/install or canonical output occurred; TODO-4 remains unchecked.
  **Recovered pre-guard artifact and focused identity probe, 2026-10-20:** a
  scratch snapshot of the parent of guard commit `288e6643` was loaded with
  `compile=FALSE` and an Oct-8 09:58 pre-guard candidate DLL (SHA-256
  `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`). On
  the same seeded, well-conditioned `n=100` inputs, all common native result
  fields were `identical()` between that EDI 1.0.2 artifact and the installed
  EDI 1.0.3 DLL (SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`)
  for NegBin, Beta, zero-augmented Poisson, Hurdle Poisson, and ZINB. On the
  matched duplicated-column NegBin fixture, the candidate pre-guard DLL
  produced non-finite covariance entries including `+/-Inf`; the current DLL
  reported `information_invertible = FALSE` and all-`NaN` covariance. Probe
  script and RDS outputs are under `/tmp/edi-v105-todo4-preguard.Ocl0Mg/`.
  This verifies one invertible fixture per kernel branch plus the singular
  behavior; it does not establish identity across every `with_var` fixture.
  **Expanded seeded identity matrix, 2026-10-20:** the same pre-guard
  snapshot/candidate DLL and freshly installed current DLL were run over
  75 well-conditioned fits: 3 sample sizes (`n=50,100,200`) × 5 fixed seeds
  × NegBin, Beta, zero-augmented Poisson, Hurdle Poisson, and ZINB. All 75
  current fits reported `information_invertible = TRUE`; every common native
  result field was bit-identical pre/post (75/75). The current-only
  `information_invertible` field was excluded from parity. The RDS outputs
  (`old-matrix.rds` SHA-256
  `51838dcdc92ef9cd87cd4fe87848ddeb32d1e2853409791811077a0aac29b711`,
  `new-matrix.rds` SHA-256
  `babe3f294b2043961ccf5cad43e06dbf9a07a8f14c5d39a25f5abd77308fee49`)
  and driver are in `/tmp/edi-v105-todo4-preguard.Ocl0Mg/`. At this checkpoint,
  this expanded generated-fit coverage did not yet meet the existing-fixture
  requirement; the later 20-file fixture-union replay below broadens coverage
  but does not close the exhaustive-fixture gate.
  **Captured fixture-union parity and typed-fallback evidence, 2026-10-20 (not exhaustive):**
  instrumented 20 affected-kernel R test files using identical current
  checkout R sources (`pkgload::load_all(..., compile = FALSE)`) while
  swapping only the recovered pre-guard DLL (SHA-256
  `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b`) and
  the current installed/checkout DLL (SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`). The
  test files exercised 638 legacy and 644 current native calls; the union
  produced 567 unique exact-input fixtures, replayed successfully against both
  artifacts with zero native errors. Of 436 currently invertible fits, all
  common native result fields were bit-identical. Of 131 non-invertible fits,
  72 changed only `vcov` to all-NaN (18 legacy covariances contained non-finite
  entries); the remaining common fields were identical, and 59 singular cases
  were identical in every common field. Current source-loaded tests passed
  1,229 assertions with no failures (16 upstream warnings, 2 skips); the
  pre-guard run's seven failures were the expected typed singular-SE/CI
  rejection assertions. Manifest and before/after outputs are under
  `/tmp/edi-v105-todo4-preguard.Ocl0Mg/` (manifest SHA-256
  `84c3ff1c657f5a9cbb99f8ae6211d0bf3a4b34df0b17dd9113f324906a99a9c0`, old
  outputs `8d0b665b929d1100517a31e2ed74e6cb27c0e6b45a2d7622eafbb76e7e17f811`,
  current outputs `fea3a768182d559cd2a9646a34e6150134ea592d31249fd1cefcebb5f432dfe5`).
  The 567-fixture union is the complete replay of the 20 captured files, but
  not every existing `with_var` fixture. A pre-existing test,
  `R/EDI/tests/testthat/test-zinb-operator-workspace.R`, was omitted from that
  capture. Its deterministic ZINB variance-path fixture uses seed `11001`,
  `n = 180`, a warm-start estimate-only fit, and a subsequent
  `fast_zinb_cpp(..., estimate_only = FALSE)` fit; the installed-artifact test
  passed all 7 expectations. It ran against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  (matching checkout `R/EDI/src/EDI.so`). This establishes current-artifact
  execution only. **Omitted-fixture pre/post replay, 2026-10-20:** to close
  that specific capture omission without changing the saved capture script,
  two isolated `/tmp` package copies from current checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` were loaded with
  `pkgload::load_all(..., compile = FALSE)`. Their R-source trees were
  identical (sorted `.R`-file manifest SHA-256
  `1adba6bbd477f63760d4d0ee7e1d2b9d805149829fe7aad9edc1e1e0f8046635`), as
  was the test file (SHA-256
  `d59d48461b5ff78d91a05f9bf24414d60dbc319743da4ee109ec1e272ce5528e`);
  only the DLL differed: recovered pre-guard SHA-256
  `89faa3386ace12922e63b28c67e5d24d1b0be924de2199831555d94ce5b3560b` versus
  current SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  `test-zinb-operator-workspace.R` passed all 7 expectations under both. The
  separately generated estimate-only warm-start parameter vectors were
  bit-identical; every common result field from the subsequent variance-path
  call was also `identical()`, including `vcov`. The current-only
  `information_invertible` field was excluded from that common-field
  comparison. RDS outputs are preserved under
  `/tmp/edi-todo4-zinb-replay.EZqzty/` (pre-guard SHA-256
  `60afd6971a83230ebb815d9a025f9f91b2bddf50c9f355d83c834465f50f3186`, current
  SHA-256 `694c9f55c43eaf5887372f084c64582e67b1bb3b47616c58ca69af2133174c81`).
  This closes the operator-workspace fixture's replay gap; the original
  20-file/567-fixture capture remains unchanged and must not be described as a
  21-file capture. A subsequent source-inventory audit found two additional
  successful ZINB variance-path tests outside that capture:
  `test-zinb-poisson-boundary-score-length.R` (seed 1, `n = 30`, fixed
  treatment coefficient, Poisson-boundary fit) and
  `test-zinb-kernel-warm-start-params-wrong-length-guard-reference.R` (seed
  37, `n = 150`, correctly-sized warm start, full-variance default). Both
  were replayed 2026-10-20 against preserved pre-guard/current DLLs in
  isolated copies with identical current R sources loaded using
  `pkgload::load_all(..., compile = FALSE)`: the boundary test passed 15
  assertions under each artifact, and all four successful calls matched by
  exact arguments (two had identical common fields; two differed only in
  `vcov`, where current returned all-NaN rather than the pre-guard partial
  NaN/large-finite matrix). The warm-start test passed 7 assertions under each;
  its successful full-variance call had identical common result fields. The
  current-only `information_invertible` field was not part of common-field
  equality. Outputs and exact provenance are in the linked plan's
  “Two additional ZINB fixture replays” note and
  `/tmp/edi-todo4-zinb-twofixtures.OPBGoG/`. These standalone replays do not
  change the original 20-file/567-fixture capture or prove the complete
  direct/indirect successful-call inventory. Keep release TODO-4 unchecked
  until that inventory is exhaustive and every fixture is reconciled. No
  build or install was performed.
  **Caller-inventory follow-up, 2026-10-20:** source tracing found six native
  helper call sites and the R routes through Beta/NegBin inference, shared
  zero-augmented likelihood methods, and KK21 Beta weight helpers. Against the
  unchanged hand-maintained 20-file/567-fixture capture, 11 more focused test
  files were replayed under preserved pre-guard/current DLLs with identical
  checkout R sources (`pkgload::load_all(..., compile = FALSE)`): 132
  assertions passed under each DLL, and 26 successful calls were captured.
  Current DLL results replayed on exact old arguments matched all common
  fields for the six NegBin class calls and 16/20 direct/Beta calls; four
  degenerate Beta covariance cases differed in `vcov` (two also in
  `std_errs`), with guarded all-NaN fallback versus pre-guard Inf/NaN values.
  The next candidate, `test-mle-km-summary-table.R`, was then replayed under
  both DLLs and passed; its one successful Beta variance call had identical
  arguments and all 11 common result fields. Thus this adds one exact-input
  pair (current-only `information_invertible` excluded). In
  `test-asymp-inference-paths.R`, only the NegBin and Beta asymptotic blocks
  plus their helper were then run: each passed 20 expectations under both
  DLLs; one successful call per class had identical exact arguments and all
  11 common fields on current-DLL replay. Other file blocks were not run.
  `test-permutations.R` was statically classified as an estimate-only Beta
  randomization-refit path (`fast_beta_regression_cpp(...,
  compute_std_errs = FALSE)`), so it is not a positive information-inversion
  fixture. The single Beta `compute_estimate()` block in
  `test-design-inference.R` was replayed under both DLLs (one expectation each);
  its exact-input current replay matched all 11 common fields. In the Bartlett
  smoke file, only the initial `compute_estimate()` fits were run for its
  NegBin, ZINB, ZIP, and Hurdle fixtures; the B=21 Bartlett p-value/CI
  null-refit workload was not run. Four successful calls (one NegBin, one
  ZINB, two zero-augmented) were replayed on exact old arguments, matching 11
  common NegBin fields and 15 common fields for each zero-augmented call. The
  full smoke test's resampling portion remains open. The NegBin gradient block
  in `test-smart-start-warm-paths.R` was also isolated (4 expectations): its
  one exact-input current replay matched all 11 common fields. Conversely,
  `test-negbin-weighted.R` uses the distinct `fast_neg_bin_weighted_cpp`
  point-estimate path and is not an inversion fixture. The other broad
  candidate is `test-parametric-bootstrap-lr-all-capable-classes.R`, whose B=2
  matrix was not run; any remaining indirect helper hits still need
  success-path classification. Details and provenance are in the
  linked plan's “Caller-inventory and omitted-fixture follow-up” note. This
  does not close the full replay gate; no build/install or canonical capture
  change was made.
  - [ ] Run linked-plan TODO-3's before/after comparison across the existing
    `with_var` test fixtures; preserve exact identity for invertible fits and
    verify typed SE/CI fallback for singular/non-finite fits.
  **Current-checkout R/current-user-native focused guard recheck, 2026-10-21:**
  after confirming `ps -C R -C Rscript` was empty and `/tmp` had 16 GiB free,
  ran `test-information-inverse-guard.R` (33 expectations) and
  `test-information-inverse-edge-cases.R` (11; 44 total) after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`, with no
  failures reported. The loaded namespace was
  `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; temporary DLL
  `/tmp/Rtmp82cqLV/pkgload24f4a25e7/EDI.so` had MD5
  `bfea6f47ab8b27618d5d8633e9021f91` and SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
  byte-identical to checkout and installed `EDI.so`. This validates the
  focused R guard/edge behavior against the latest user-built native artifact
  without compilation. It does not close the provenance-pinned before/after
  identity inventory across every successful `with_var` caller, Python
  positive parity, or Bartlett per-replicate diagnostics; TODO-4 remains open.
  No canonical outputs were written.

  **Cross-confirmed 2026-09-24** by the new `pval_miscalibration`/
  `low_coverage` audit checks, independently of the direct-repro check
  above: `InferenceCountNegBin` and all four zero-inflated/hurdle variants
  (`InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`,
  `InferenceCountHurdleNegBin`, `InferenceCountHurdlePoisson` — all inherit
  `InferenceCountZeroAugmentedPoissonAbstract`, confirmed to call
  `fast_zinb_cpp`/`fast_zero_augmented_poisson_cpp`, i.e. exactly the two
  other files this TODO already names) show broad, multi-family
  miscalibration in the audit data — real-world statistical evidence the
  unguarded-inverse defect actually manifests at scale, not just in a
  constructed duplicate-column repro. No new investigation needed; this
  strengthens the existing finding.

  **Also checked and RULED OUT, same day**: `InferenceCountPoisson`,
  despite also showing broad audit-flagged miscalibration (16 families),
  does NOT share this mechanism — confirmed it uses a different, already
  well-guarded kernel, `compute_diagonal_inverse_entry()`
  (`_helper_functions_core.h:222-245`, LDLT-first with a rank-revealing
  `ColPivHouseholderQR` fallback, returns `NaN` not a wrong finite value on
  a singular system) — exactly the pattern this TODO wants added
  elsewhere, already present here. Its own broad miscalibration has a
  different, unidentified cause — tracked separately, not part of this
  TODO (see the count-family investigation note below). `InferenceCountRobustPoisson`,
  `InferenceCountQuasiPoisson`, `InferenceCountKKGLMM` (inherit `Inference`
  directly, confirmed independent implementations) and
  `InferenceCountKKHurdlePoissonOneLik` (separate file) are similarly
  confirmed NOT to share this TODO's specific kernels — also broadly
  flagged, also unexplained, also not part of this TODO. One unrelated
  dead-code note surfaced while checking `InferenceCountPoisson`:
  `set_min_eigenvalue_if_suspect()` was then entirely commented out, so the
  generic `min_eigenvalue_information` diagnostic was never populated. That
  historical no-op was later removed under TODO-51; it was unrelated to this
  TODO's miscalibration investigation.
- [x] TODO-5 (added 2026-09-04, found empirically; fully reconciled
  2026-10-09): **Randomization CI
  construction audit** — `../new_feature_plans/randomization_ci_construction_audit.md →
  TODO-1..4`. Two findings. **§A (bug):** the Cox-family classes
  (`InferenceSurvivalCoxPHRegr`, KK LWA Cox ×2, KK strat Cox ×2) run the
  generic randomization-CI driver, which shifts responses on the log-time
  (AFT) scale but seeds, brackets, and reports on the estimate's
  log-hazard-ratio scale — on a Weibull DGP with true log HR `−1.6` the Cox
  rand CI came back `[−1.702, −1.264]` with the lower bound equal to the
  estimate, while `p(δ)` correctly peaks at the log time-ratio `0.8`. Same
  bug family as `incidence_randomization_cis.md`. **Decided and
  implemented 2026-09-06 (user decision, option 1):** the six log-HR
  classes are listed in `EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES`, excluded
  from the `randomization_ci` capability, and refused with an explanation
  on a direct call; randomization p-value and randomization-bootstrap CI
  untouched. Test: `test-log-hazard-ratio-randomization-ci-disabled.R`.
  **§B (closed 2026-09-05, no code change):** an earlier draft claimed the
  null construction was shift-the-null; it is not — every path imputes the
  control potential outcomes first, then shifts the permuted-treated
  units (the Rosenbaum / Imbens–Rubin construction), pinned by
  `tests/testthat/test-rand-null-construction.R`. **Verified DONE,
  2026-09-24**: the plan's own checklist shows TODO-1, 2, 2b, 4, 5 checked
  `[x]`; the cosmetic test-comment fix (TODO-3) was completed 2026-10-09,
  so all linked TODOs are checked. The one substantively complete item among
  TODO-1..6.
- [ ] TODO-6 (added 2026-09-11, source fixed 2026-10-08; exact production timing pending; found via a comprehensive-test-harness
  timing investigation, not a user report): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`
  optimizer stability** — `../bug_fix_plans/clayton_loggamma_frailty_optimizer_stability.md
  → TODO-1..4`. A ~200× bimodal slowdown (0.5-1s vs. 150-180s, same
  scenario, only the data realization differs) in
  `compute_lik_ratio_bartlett_approx_two_sided_pval()`'s Monte-Carlo null
  replicates (the method default is B=99; the standard comprehensive runner
  overrides it with `B=r=151`). The reported historical `~1` outliers are
  therefore likely B=151 if they came from that runner, but the retained
  matching-class rows cover `~.` rather than those `~1` cases, so their exact
  B remains unproven. The slowdown was traced to the Clayton-copula/loggamma-frailty C++
  optimizer having no bound on its dependence parameter (unlike the
  sibling normal-frailty optimizer's `max_abs_log_sigma=8.0` cap) plus a
  stale-gradient mismatch (the objective clips `theta` but the gradient
  terms don't), which can leave the optimizer thrashing toward its
  2000-iteration cap and triggering an expensive R-level Nelder-Mead
  fallback cascade that only this class's fit path has. Additive/no-op for
  every other class; needs a golden-test parity check to confirm the new
  bound doesn't move existing point estimates. **Verified NOT implemented,
  2026-09-24** (via the plan's own checklist — 0/4 checked; not
  independently re-timed this pass): the C++ dependence-parameter bound
  and the stale-gradient fix have not been applied. **Implemented
  2026-10-08:** the native optimizer now caps `log_theta` at 6 like the R
  fallback, keeps the valid independence tail open, uses a zero chain
  derivative on the clipped flat surface, normalizes returned parameters, and
  reports upper-bound contact. On 2026-10-14, after the user's reinstall,
  `test-clayton-logtheta-optimizer-bound.R` passed 18 assertions (including
  the native boundary fit and golden censored outputs), and the failed-fit
  branch test passed 7; Codex did not compile/install. Linked-plan TODO-4 is
  complete. **Filtered timing probe 2026-10-14:** an isolated harness copy,
  restricted to formula `~1` and run sequentially through rep 13 for the
  survival/KK21stepwise/diamonds/`beta_T=0` Bartlett case, measured the
  approx Bartlett p-value at 0.359s (rep 1) and 0.380s (rep 13), both finite
  and `status=ok` (p=0.837/0.735), versus the historical 178.7s/159.7s.
  This is not an exact re-run of the original full-sweep samples: filtering
  out other datasets/designs/classes changes RNG consumption, so rep 13 is
  only the 13th replicate of this focused sweep. A separate two-formula
  attempt stalled for >5:24 in the generic Bartlett p-value on `~.` and was
  interrupted. The filtered `~1` result suggests the approx-pval tail is
  gone on those draws, but TODO-3 remains open pending an exact full-sweep
  sample and resolution/measurement of the `~.` path. Results CSV:
  `/tmp/edi-v105-todo6.kCbSHR/R/package_tests/comprehensive_tests_results_nc_1_survival_filtered_design-KK21stepwise_class-InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik_dataset-diamonds_beta-0_family-bartlett.csv`;
  heartbeat path recorded in that CSV:
  `/tmp/RtmpaeuB1H/comprehensive_tests_heartbeat_2.log` (temporary R session
  path; stdout was not saved separately). No build or install was performed.
  **Fresh provenance recheck 2026-10-18 (read-only):** checkout `HEAD`
  `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`; current
  `R/EDI/src/fast_survival_models_optim.cpp` SHA-256
  `c0ce193eaa4a40a511c55dcbce39026e2f35fab7df0a979fb70ee386b352475d`
  (mtime 2026-10-18 05:59:22 +0300). The loaded installed EDI 1.0.3 DLL is
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  SHA-256 `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`
  (mtime 2026-10-18 03:57:33.954 +0300). The DLL predates this source
  translation-unit mtime and there is no build attestation tying it to the
  current whole source; the current source diff is an unrelated
  dependent-censoring warm-start length guard, not a Clayton change. This is
  a provenance limitation, not evidence that the Clayton fix is absent from
  the DLL. No fit was run while TODO-56 is active. The historical seed/RNG
  context remains unavailable, and no numeric runtime ceiling or parity
  tolerances have been maintainer-approved.
  - [ ] Recover the historical sample/seed and package provenance (or obtain
    approval for a deterministic replacement), and obtain a maintainer-approved
    numeric runtime bound plus explicit point-estimate/SE/Bartlett-p parity
    criteria for both `~1` and `~.`. After TODO-56 releases the shared paths,
    rerun the full production case under a hard timeout; require finite
    successful results and recorded package/native provenance, then compare
    against those predeclared criteria. The linked plan currently says only
    “well under” the historical 159.7–178.7 s outliers and does not define a
    numeric acceptance cutoff.
  **Independence-tail test follow-up, 2026-10-20:** the focused Clayton
  regression now checks the current source's one-sided upper-cap expression
  and a finite, small, nonzero native score at `log_theta = -20`. It passed
  22 assertions against installed EDI 1.0.3 (build timestamp
  `2026-10-19 23:31:50 IDT`); this is not an exact current-head native-build
  attestation. No compile/install or timing run occurred, and it does not
  resolve the historical RNG/sample or maintainer-accepted runtime/parity
  criteria above.
  **Post-rebuild native recheck, 2026-10-20:** reran
  `test-clayton-logtheta-optimizer-bound.R`; all 22 expectations passed
  against installed EDI 1.0.3 with no failures, warnings, or skips. Loaded
  `EDI.so` (`/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  14,727,184 bytes, mtime `2026-10-20 09:38:02 +0300`) SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (MD5 `a75519a9256c0b3121398032314291d4`), byte-identical to checkout
  `R/EDI/src/EDI.so` at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  This focused DLL recheck does not satisfy the historical RNG/sample,
  maintainer-set timing/parity criteria, or calibration gates; TODO-6 remains
  open. No compile/install, timing run, or canonical result change occurred.
  **Checkout-R source-overlay recheck, 2026-10-20:** after the active R work
  finished, ran the focused `test-clayton-logtheta-optimizer-bound.R` with
  checkout R loaded via `pkgload::load_all("R/EDI", compile = FALSE)`; all
  22 expectations passed with no failures, warnings, or skips. The loaded
  checkout namespace used R `R Under development (unstable) (2026-10-13
  r90668)` and a temporary DLL with SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to the installed user-rebuilt EDI 1.0.3 DLL and checkout
  `R/EDI/src/EDI.so`. This adds focused checkout-R/runtime evidence only; it
  is not independent compiler-input provenance, an exact historical-sample
  replay, or timing/parity acceptance. TODO-3 remains open; no build,
  install, timing run, or canonical result change occurred.
  **Filtered-artifact metadata recheck, 2026-10-20 (read-only):** the retained
  `/tmp/edi-v105-todo6.kCbSHR` tree contains only six files: its filtered
  runner/helpers and two filtered result CSVs (13-replicate: 40,109 bytes;
  rep-1: 3,529 bytes). The 13-replicate CSV has case/result, commit,
  timestamp, duration, and heartbeat columns, but no RNG state,
  assignment/outcome hash, or provenance sidecar; no original sample or full
  run bundle is present there. This does not recover the original reps 1/13
  realization. The historical replay/runtime-parity and maintainer-approved
  runtime/estimate/SE/Bartlett-p acceptance gates remain open. No fit or
  canonical result write occurred.
  **Tracked-source RNG/provenance audit, 2026-10-20 (read-only):** the runner
  begins with `set.seed(1)`, but `_dataset_load.R` consumes that stream to
  sample the `diamonds` rows before individual inference cases. This is not
  the original case-start `.Random.seed`/`RNGkind()` or sampled-input hash.
  The current provenance helper snapshots RNG state only at run boundaries,
  after dataset loading, so it cannot backfill the historical cases. The
  linked TODO records propose a deterministic one-replicate-per-formula
  replacement but require approval; none is recorded. The recoverable
  metadata is limited to the configured start seed and historical row labels,
  outcomes/timings, and commit metadata. Exact replay still needs the per-case
  RNG state and sampled-row/assignment-or-outcome hash plus compatible data,
  harness, and package provenance; otherwise the maintainer must approve the
  replacement protocol and acceptance thresholds. No fit or artifact write
  occurred.
  **Timing/workload acceptance reconciliation, 2026-10-21 (read-only):** the
  reported historical `~1` outliers (178.7s and 159.7s, reps 1 and 13) cannot
  be authenticated as replay inputs: retained artifacts do not include the
  original per-case RNG state/RNG kind, sampled `diamonds` row IDs or input
  hash, treatment/outcome realization, or compatible harness/package/DLL
  provenance. The filtered post-fix `~1` timings above are replacement draws,
  not those historical realizations; the separate `~.` attempt stalled in
  the generic Bartlett path, not the target approximate-p-value path, and
  therefore does not measure that target. The retained full-sweep `~.` rows
  are different cases and do not fill this gap. There is also a workload
  discrepancy to resolve before replay: the linked historical description
  says B=99, while the current runner sets `r=151` and passes `B=r` to this
  call; the filtered CSV records `r=151`. No historical artifact establishes
  which B produced the original outliers. The current installed/checkout
  native DLLs were byte-identical at SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`, and
  the optimizer translation-unit SHA-256 was
  `c0ce193eaa4a40a511c55dcbce39026e2f35fab7df0a979fb70ee386b352475d`; this
  establishes artifact identity for that inspection, not build-input
  attestation or timing provenance for the earlier measurements. Closure
  still requires either recovery of the exact historical sample, seed/RNG,
  B, and package/harness provenance, or maintainer approval of a clearly
  labeled replacement protocol; plus an explicit numeric runtime ceiling and
  separate estimate, SE, and Bartlett-p tolerances for both `~1` and `~.`.
  None of those acceptance limits is currently specified, and no threshold
  is inferred here. TODO-6 remains open; no benchmark, build/install, or
  canonical output write occurred.
  **Scratch-path availability recheck, 2026-10-21 (read-only):** the
  previously cited `/tmp/edi-v105-todo6.kCbSHR` filtered-run directory is no
  longer present at that path. Thus the filtered CSVs/runner snapshot
  described in the linked plan are not currently recoverable from that
  location; this does not supply the missing original RNG/input provenance or
  a replacement acceptance run. Closure still requires either the original
  per-case RNG/input and package/harness provenance, or maintainer approval
  of a replacement protocol, plus explicit runtime and estimate/SE/Bartlett-p
  criteria for both formulas. No fit, benchmark, build/install, or canonical
  write occurred in this recheck.
- [x] TODO-7 (added 2026-09-17, fixed 2026-10-08; found via a raw `comprehensive_tests`
  results-CSV audit, not a user report): **`KKQuantileRegrOneLik`
  randomization CI** — `../bug_fix_plans/KKQuantileRegrOneLik_rand_ci.md → TODO-1..6`.
  `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
  compose `QuantileRandomizationCI` (Zhang test-inversion) without ever
  supplying the `compute_rand_pval_matched_pairs`/`compute_rand_pval_reservoir`
  hooks it needs — the bisection silently collapsed to a zero-width
  interval at the point estimate instead of erroring (100% zero-width
  across ~1,644 audited rows, ~0-1% empirical coverage vs. ~95% nominal).
  Stopgap `stop()` landed 2026-09-17; the follow-up decision selected the
  already-correctly-wired generic `InferenceRandCI` bisection instead of
  Zhang.
  **Implemented:** both continuous and proportion OneLik leaves now inherit
  the generic stacked-estimator inversion, while IVWC retains Zhang. The
  emergency stop, leaf override collisions, four wiring exemptions and stale
  path-audit entries were removed. Focused finite-width/Wald-overlap and
  50-repetition coverage checks pass without compilation; the wiring audit is
  10/10 and migration golden is 72/72. All six linked-plan items are closed.
- [ ] TODO-8 (added 2026-09-22, found via a raw `comprehensive_tests`
  results-CSV audit, not a user report): **Stereotype-logit multimodal
  likelihood** — `../bug_fix_plans/multimodal_log_liks.md → TODO-1..8`. The 2026-09-21
  fix to `InferenceOrdinalStereotypeLogitRegr`'s delta-constrained null
  refit (multi-start, closed a zero-width-CI bug) left a residual: the
  likelihood is multimodal and `compute_estimate()`'s own unconstrained fit
  is single-start, so it can silently return a non-global optimum (~3% of
  `n=50` fits in a 400-simulation measurement). Explains a residual ~13%
  Type-I error at `n=50` (vs. 6.5% at `n=100`).
  **Source implementation 2026-10-08:** `generate_mod()` now screens its
  ordinary full-data fit across deterministic and data-hashed local starts,
  retaining the lowest converged negative log likelihood while leaving the
  repeated randomization and weighted-bootstrap paths single-start. Linked
  plan TODOs 1--3, 5, and 6 are complete: focused source-loaded references
  remain compatible and the deterministic fixture confirms the better
  optimum; the measured full-fit cost is 0.035s versus 0.006s. This release
  item remains unchecked pending the post-fix 400-null calibration study
  (TODO-4), its consequent roxygen/update work (TODO-7), and installed
  comprehensive-results regeneration (TODO-8). The plan's separate thin-
  sample post-fix coverage lead (TODO-9) also requires that larger study
  before any conclusion. After the user's 2026-10-14 reinstall, the CRAN
  multi-start regression passed 14 assertions and the linked null-refit
  reference passed 5; its private native-wrapper calls were qualified with
  `EDI:::` so `testthat::test_file()` can resolve them. These focused passes
  do not substitute for the calibration study. **Installed-package
  diagnostic 2026-10-14 (not release-current validation):** 400 seeds per
  configuration (1001--1400) against installed EDI v1.0.3 yielded, at
  `n=100, K=5`, 224 finite estimate/LR-p-value pairs, 19/224 rejections
  (8.48%), 212/224 finite CIs covering zero (94.64%), zero zero-width CIs,
  and 3/400 multistart NLL improvements. At `n=50, K=3`, there were 177
  finite estimate/LR-p-value pairs, 6/177 rejections (3.39%), non-missing
  interval-comparison coverage 168/172 (97.67%; 170 finite CI pairs, 168/170
  covering zero), zero zero-width CIs, and 48/400 multistart NLL improvements.
  Missing estimate/LR results (176 and 223) report `model_fit_unavailable`;
  sampled missing fits converged but failed the Fisher-information
  conditioning gate (rcond 1.29e-9 at n=100 and 1.82e-11 at n=50, below the
  ~1.49e-8 threshold). This usable-denominator discrepancy—especially
  224/400 versus the earlier 386/400 at n=100—remains unreconciled. The
  installed library reports EDI 1.0.3 and native build timestamp
  2026-09-20, so this is not validation of the current checkout/native pair.
  **Artifact-only reconciliation 2026-10-15:** a post-reinstall run at
  `/tmp/edi-todo8-400-null-reinstall-20261014T173835Z/` is byte-identical
  to the above n=100/n=50 CSVs (SHA256
  `e07fb6839cbacb3e0bfa40da1f6a5614d9823206caf12ad273c4169ee0ddd051` /
  `5992e43b803016c970e0bbd2a92cf541872f062e153fad0b853d0bfdf147eff4`),
  despite reporting a 2026-10-14 native build timestamp. An Oct 9
  source-loaded n=100 artifact at `/tmp/edi_todo8_n100k5.csv` has 64/400
  finite fits; those same 64 seeds are finite in the newer 224-case run,
  with 160 additional seeds finite and no old-only finite seeds. No paired
  n=50 CSV was found for that run. The historical 386/400 n=100 and 169/400
  n=50 table still lacks its seed-level CSV/run metadata, so the cause of
  the denominator differences cannot be established. TODO-8 remains open;
  no regeneration or compilation was performed. TODO-7's documentation
  update and comprehensive-results regeneration must wait. Full results
  and metadata are preserved at
  `/tmp/edi-todo8-400-null-installed-20261014T142934Z/`.
  **Artifact/source snapshot audit 2026-10-20:** independently re-hashed the
  two preserved installed-package CSV pairs; `n100k5.csv` matches at SHA-256
  `e07fb6839cbacb3e0bfa40da1f6a5614d9823206caf12ad273c4169ee0ddd051`,
  and `n50k3.csv` at
  `5992e43b803016c970e0bbd2a92cf541872f062e153fad0b853d0bfdf147eff4`.
  The two `study.R` snapshots differ only in the output-directory literal
  and added installed-artifact-mtime metadata collection; the seed range,
  simulation grid, and fit/acceptance calculations are unchanged. Metadata
  confirms different installed native build timestamps (2026-09-20 06:41:28
  IDT vs. 2026-10-14 20:37:15 IDT), but emitted results remain byte-identical.
  Thus the reinstall did not resolve the 224/400 denominator or explain the
  missing historical 386/400 run. No canonical data or artifacts were
  modified; current-native validation and the historical seed-level CSV/run
  metadata remain blockers.
  **Full-data wiring regression, 2026-10-18:** the new integration assertion
  in `test-stereotype-logit-full-fit-multistart.R` confirms ordinary
  `generate_mod()` invokes the multi-start selector and returns a finite
  treatment estimate with a selected start. Source-loaded test passed 17
  assertions with compilation disabled; native calls used installed EDI
  1.0.3 (`EDI.so` MD5 `dd43c5d0e11708aea17ba82b900f66d1`). This closes only
  the call-site regression gap, not calibration or current-native validation.
  **Installed-package focused recheck, 2026-10-20:**
  `test-stereotype-logit-full-fit-multistart.R` passed all 17 expectations
  using `testthat::test_file()`. The installed package was EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, Built
  `2026-10-20 06:33:10 UTC`, under `R-devel r90668`; its loaded `EDI.so`
  SHA-256 was `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (MD5 `a75519a9256c0b3121398032314291d4`). Checkout HEAD was
  `4f7a6e4ca828`. This installed-package recheck does not show that its R
  implementation matches checkout source and is not current-checkout/native
  validation. No compilation or installation occurred; the 400-null study,
  documentation update, and comprehensive-results regeneration remain open.
  **Ordinary-fit RNG-stream contract, 2026-10-21:** broadened the existing
  fast regression to capture `.Random.seed` immediately before the real
  `generate_mod()` multi-start call and assert that it is unchanged afterward.
  The focused file passed all 18 expectations against installed EDI 1.0.3
  via `testthat::test_file(..., package = "EDI")`, with no failures,
  warnings, or skips. This extends the existing candidate-generator RNG
  check to the ordinary fit integration path; it does not establish
  calibration or test the separate resampling refit paths. No build/install
  or simulation ran; TODO-8's calibration and artifact gates remain open.
  **Scratch audit-path check (2026-10-18):** the focused
  `test-comprehensive-audit-output-directory-override-reference.R` passed 7
  assertions with 0 failures and 0 warnings. This verifies that response-level
  audit inputs, baseline, and stamp route to the configured scratch directory;
  it is not a full audit or post-fix regeneration and does not close TODO-8.
  Before any scratch `--write-baseline` pass, stage all complete response-type
  inputs covered by the baseline; an ordinal-only audit input set could make
  findings for absent response types appear resolved and prune them.
  **Installed null-refit-selection regression, 2026-10-20:**
  `test-ordinal-stereotype-logit-lik-test-null-refit-multistart-reference.R`
  passed 5 assertions (0 failures/warnings/skips; exit 0) against installed
  EDI 1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`.
  Loaded DLL `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`
  MD5 `8b3ca30492d7b1c790deeebe94b201ad`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This mock-based
  unit test checks null-start selection/failure handling only; it does not
  establish Type-I error or coverage, regenerate the full class result rows,
  reconcile historical usable denominators, or prove installed R-source
  freshness. TODO-8's regeneration gate and TODO-4/7 calibration/documentation
  prerequisites remain open.
  **Historical artifact reconciliation, 2026-10-21:** the two retained
  October 14 study directories each contain 400 seed rows for n=100 and n=50,
  and their CSVs are byte-identical. The October 9 n=100 file's 64 finite
  estimate/LR rows all occur in the later 224-finite-row file (zero old-only,
  160 later-only finite rows). The retained study metadata identifies EDI
  1.0.3/R-devel and seeds 1001–1400 but has no source revision, DLL hash,
  per-seed timing, or explicit failure-stage/conditioning fields. The original
  September 21 per-seed output and run metadata were not found in the bounded
  artifact inventory, so the historical 386/400 and 169/400 counts remain
  unreconciled. Recover those inputs or approve a provenance-pinned rerun with
  per-seed status, error stage, conditioning, and elapsed time; do not infer
  the historical discrepancy from the Oct. 9/14 overlap alone.
  **Retained-artifact inventory, 2026-10-21 (read-only):** the previously
  named `/tmp/edi-todo8-400-null-reinstall-20261014T173835Z/`,
  `/tmp/edi-todo8-400-null-installed-20261014T142934Z/`, and
  `/tmp/edi_todo8_n100k5.csv` are absent now. The only TODO-8-named file found
  under `/tmp` is the 1,249-byte source-test log
  `/tmp/todo8-stereotype-multistart-source-20261020.log`. Four ignored,
  filtered historical class CSVs survive in `R/package_tests/` (line counts
  include headers): beta-0 parametric bootstrap, 556 lines, SHA-256
  `46479a28cf5acf36f52b6365cec75a9766be4d0f080ce80eb07d8392b42db6ff`;
  bootstrap, 133 lines, `362c25a221608db8030cda91330fda2315dc8e6c1c61363b97eca27f2a7bb7be`;
  jackknife, 508 lines, `9fdd6ffb04c2a72a9659c44deec521b2dae5b6f5c395afe1cf9e52e9ccc56cca`;
  rand, 163 lines, `298511ebeb8200d997f5f24d003b403032cac2c7ea7b6cc9bc20876d753de011`.
  Their mtimes are Sep 8 (three slices) and Sep 21 (beta-0 parametric
  bootstrap), all before the Oct 8 ordinary full-fit multi-start fix; none is
  a complete all-`function_run` class shard or carries current source/DLL
  provenance. The two documented Oct 14 400-row null-study cohorts are absent
  too and are not comprehensive-runner results. No exact current-source
  reconciliation or complete expected-key roster can be recovered from these
  files. Keep TODO-8 open behind TODO-4/7; after those gates, regenerate an
  installed, provenance-stamped all-`function_run` shard and reconcile it
  against complete ordinal scratch inputs. Do not use these stale partial
  files to modify canonical results or baseline.
  **Ordinal artifact parity recheck, 2026-10-21 (read-only):** the bounded
  inventory also finds `comprehensive_tests_results_nc_1_ordinal.csv.pre_stereotype_merge.bak`
  (437,321,222 bytes; mtime 2026-09-21) and two Bernoulli/diamonds filtered
  class outputs (`rand_custom` and `rand`, both dated 2026-09-23). All predate
  the 2026-10-08 ordinary-fit multi-start change; the backup is a pre-change
  snapshot and the others are narrow dataset/family slices. None validates
  post-fix optimum selection/calibration or supplies a full class key
  inventory. No new retained artifact closes TODO-8 without TODO-4/7
  calibration and provenance; do not update canonical CSV/baseline from
  these files.
- [ ] TODO-9 (added 2026-09-22, found via a raw `comprehensive_tests`
  results-CSV audit, not a user report; three new checks —
  `biased_estimate`, `bad_type1_error`, `low_power` — added to
  `audit_comprehensive_results.R` itself this wave): **Stale worker-cache
  in reused-worker resampling** — `../bug_fix_plans/stale_worker_cache_resampling.md →
  TODO-1..8`. **Fixed and merged.** A correctness bug: any class whose
  point-estimate cache guard used a key outside the reused
  randomization/bootstrap worker's narrow, hardcoded reset list had every
  permutation/bootstrap draw after the first silently reuse the first
  draw's stale fit instead of refitting — collapsing the resampling
  distribution to a constant regardless of which draw was used (proven:
  `InferenceOrdinalGCompMeanDiff` rejected a true null 100% of the time
  instead of 5%). Fixed systemically (allowlist → denylist reset,
  `cached_values` reconciled to a `duplicate()`-derived keep-list) plus a
  permanent non-degeneracy regression test. **Reconciled 2026-10-09:** the
  code, focused regressions, published-output audit, and linked plan
  TODO-1..6/8 are complete; its sole remaining linked action is TODO-7's
  installed comprehensive CSV regeneration plus authoritative
  `audit_comprehensive_results.R --write-baseline`. This release TODO stays
  unchecked until that regeneration is complete; no local build/install was
  attempted. After the user's 2026-10-14 reinstall, the CRAN
  non-degeneracy regression passed all 13 assertions against the installed
  package.
  - [ ] Reconcile the current comprehensive rows only after TODO-18's
    supported/unsupported smoothed-method scope is settled. Classify all
    183 baseline findings now absent and 373 newly reported findings; do not
    write a new baseline until every difference has an evidence-backed
    disposition and the canonical run is authorized.
    **Evidence audit, 2026-10-18:** TODO-18 now maps current support (16
    continuous/count keys supported; nine categorical baseline keys blocked),
    but the tracked baseline has aggregate keys only and the audit stamp has
    only input paths/sizes/mtimes. The raw comprehensive CSVs and the
    row-level 183-absent/373-new audit diff are not tracked, so those totals
    cannot yet be classified or safely joined. The ordinal smoothed
    `low_power` key was specifically classifiable at that audit stage:
    `low_power|ordinal|InferenceOrdinalGCompMeanDiff|NA|compute_rand_bootstrap_two_sided_pval_smoothed`
    (0/67 at .05) is not supported by the current guard. The exact-key
    scratch recheck below extends this partial classification but still does
    not dispose of the remaining differences or authorize
    `--write-baseline`. Preserve or
    regenerate the complete finding table in `/tmp`, join by exact key to
    baseline, and disposition every difference before a baseline write.
    **Bounded smoothed-key disposition, 2026-10-18:** the current
    `rand_bootstrap_smoothing_supported()` predicate blocks incidence,
    ordinal, and proportion smoothing unless the class provides a private
    `compute_fast_rand_bootstrap_distr()` method; the p-value support list and
    execution path use this predicate. The nine categorical baseline keys
    match classes without that method. Their exact `(response_type, class,
    formula)` tuples, all for `compute_rand_bootstrap_two_sided_pval_smoothed`,
    are incidence: `(InferenceIncidBinomialIdentityRiskDiff, ~.)`,
    `(InferenceIncidBinomialIdentityRiskDiff, ~1)`,
    `(InferenceIncidKKCondLogitOneLik, ~.)`,
    `(InferenceIncidKKCondLogitOneLik, ~1)`, `(InferenceIncidKKGEE, ~.)`,
    `(InferenceIncidProbitRegr, ~1)`; ordinal:
    `(InferenceOrdinalGCompMeanDiff, NA)`,
    `(InferenceOrdinalPairedSignTest, NA)`,
    `(InferenceOrdinalPropOddsRegr, NA)`. **Scratch exact-key recheck,
    2026-10-18 (no canonical writes):** local gitignored full response CSVs
    were symlinked read-only into `/tmp/edi-todo9-audit.NnBBLg`, with a copy
    of the tracked baseline. A forced audit reproduced 183 baseline findings
    absent / 373 new; a second pass wrote the current finding table and stamp
    only in that scratch directory for exact key comparison. It found four
    new smoothed keys in addition to the nine baseline keys: the above ordinal
    `low_power` key, `low_power|incidence|InferenceIncidLogRegr|~1|compute_rand_bootstrap_two_sided_pval_smoothed`,
    `pval_miscalibration|proportion|InferencePropBetaRegr|~.|compute_rand_bootstrap_two_sided_pval_smoothed`,
    and
    `pval_miscalibration|proportion|InferencePropFractionalLogit|~.|compute_rand_bootstrap_two_sided_pval_smoothed`.
    All four new classes lack the private fast-kernel method required by the
    current predicate, so the thirteen smoothed keys appear to be old output
    for unsupported paths, not supported current behavior. The local CSVs'
    mtimes range from 2026-09-27 to 2026-10-09 and have no verified
    source/DLL provenance; this is an audit-key classification only, not
    current-package validation. The remaining 183 absent / 373 new findings
    are still unresolved, and no baseline update is authorized.
    **Baseline-write safety regression, 2026-10-20:** the focused bulk test
    now invokes `audit_comprehensive_results.R --write-baseline` against a
    `/tmp` directory containing only one nonempty response CSV plus sentinel
    baseline/stamp files. It confirms the command rejects the partial
    artifact set and leaves both prior state files unchanged.
    This verifies the fail-closed CLI guard; it neither classifies the
    unresolved finding deltas nor authorizes a canonical baseline write.
    **Positive scratch baseline-write regression, 2026-10-20:** the same
    focused test also runs `--write-baseline` on six synthetic response CSVs,
    with the copied runner and output directory both contained under one
    `tempfile()` root. It confirms a successful zero-finding write, the exact
    baseline schema and size/mtime stamp, and that sidecars are created only
    in the configured override directory. This exercises the CLI happy path
    on synthetic inputs only; it does not reconcile the real finding deltas
    or authorize a canonical baseline write.
    **Structural input preflight, 2026-10-21:** the write guard now checks
    each of the six response files for the required result columns and at
    least one data row (reading only the header/first row); the focused
    scratch-path test passes 39 assertions, including rejection of
    header-only/wrong-schema inputs while preserving existing baseline/stamp
    sentinels. This is only a structural check, not proof of complete keys,
    current source/native provenance, or valid terminal outcomes. The
    six-response provenance/key reconciliation remains open; the 183
    baseline-only and 373 finding-only differences are not resolved, and no
    canonical baseline write is authorized.
    **Duplicate response-name guard, 2026-10-21:** the same preflight now
    rejects duplicate names in its response-path vector before inspecting any
    files, preventing one response path from being ambiguously presented as
    multiple response-level inputs. The focused scratch-path test passes with
    the added rejection case. This input-shape guard does not establish that
    all six distinct response types are complete or provenance-valid; the
    reconciliation and baseline-write gates above remain unchanged.
    **Sweep-classification guard, 2026-10-20:** deterministic review found
    that the linked `scripts/reused_worker_bitforbit_sweep.R` comparator
    classified an all-NA baseline as a point mass (`0 <= 1`) and could label
    its transition to a varying distribution as `fixed`. It now calls `fixed`
    only when the baseline has exactly one finite value; the focused contract
    test pins both this case and all-NA → `MOVED`. The new assertions passed,
    but the full focused file had two existing failures against installed EDI
    1.0.3 because its `InferenceIncidExactBinomial` registry entry differs
    from checkout expectations. No sweep ran; pre/post snapshot comparison
    and unresolved finding reconciliation remain open.
    **Retained exact-key partition, 2026-10-21 (read-only):** the 2026-10-18
    scratch finding table was previously recorded at
    `/tmp/edi-todo9-audit.NnBBLg/comprehensive_results_audit_baseline.csv`
    with SHA-256
    `14d3ddbe31f0a6c39a21c0e394054b4d1d4cdbfd770b02200954c0e394828464`;
    that file is now absent, so its recorded byte identity cannot be checked.
    The copied input baseline is `baseline.before.csv`, SHA-256
    `6daf9c3d6caff7bd09a65afef066de818e53dbe7d7e15b0a9b1dddac321cf125`.
    Exact key join gives 2,165 unique baseline keys, 2,355 unique finding
    keys, 1,982 common, 183 baseline-only, and 373 finding-only; neither
    table has duplicate keys. This reproduces the earlier totals, but is not
    a new current-package audit: the six CSV inputs were read-only links to
    gitignored artifacts dated 2026-09-27 through 2026-10-09, and the scratch
    stamp (SHA-256
    `54f8e558f3121cd6b4a22641840dd7d3c8c3ded363d41d1b06ee17aea0f7ccde`)
    records only input paths, sizes, and mtimes—not source revision, package,
    or native-DLL identity.

    Bounded disposition: current source rejects 13 smoothed class/formula
    keys (the nine baseline keys remain among the 1,982 common keys; four
    appear among the 373 new keys). Those four exact new keys are the
    incidence/ordinal/proportion keys listed above; all require the private
    fast-kernel method that those classes lack. One of these four also falls
    in the 29 new `pval_miscalibration|proportion|InferencePropBetaRegr`
    keys (18 p-value functions, formulas `~.`, `~1`, `NA`). The 29-key
    PropBeta subset comes from the 2026-10-09 proportion CSV, predating the
    TODO-52 Oct. 11 warm-start change, but has no source/DLL provenance:
    classify it as historical/pre-fix with current status unknown, not as
    safe to drop or accept. Thus 32 distinct new keys have this limited
    source-scope/historical classification (the four smoothed keys and 29
    PropBeta keys overlap once); 341 other new keys and all 183 absent keys
    remain unexplained. No baseline disposition follows from these
    classifications alone.

    Minimal safe-write prerequisites: regenerate all six complete
    response-level inputs from one authorized current package/source/native
    identity; retain row/run provenance (including source/script hashes,
    package version/path, native-DLL hash, and attempted-key/status data);
    audit in an isolated copy with separate baseline/stamp; then account for
    every exact-key delta, including the remaining 341 new and 183 absent
    keys, and review persistent findings as fixed or explicitly accepted.
    Only after that review may an explicitly authorized baseline/stamp
    promotion occur. No canonical CSV/baseline/stamp payload was read or
    changed in this partition audit.
    **Tracked-HEAD replay, 2026-10-21:** copied the audit script and paths
    helper byte-for-byte from checkout HEAD
    `4f7a6e4ca82829e880c15a76699701a95e5e83b9` into an isolated `/tmp` tree,
    then replayed them against the six retained response CSVs and tracked
    baseline. The script exited 0 and reproduced 2,355 finding keys; the
    exact join again gives 2,165 baseline, 1,982 common, 183 baseline-only,
    and 373 finding-only keys, with no duplicates. Replay table:
    `/tmp/edi-todo9-head-replay.8aFP0a/R/package_tests/comprehensive_results_audit_baseline.csv`,
    SHA-256
    `14d3ddbe31f0a6c39a21ecf653054b4d1d4cdbfd770b02200954c0e394828464`.
    The prior scratch table is gone; the formerly recorded hash differs from
    this regenerated table, and the original bytes cannot now be compared.
    This hash identifies the regenerated table only. The 556-key
    source-disposition table is
    `/tmp/edi-todo9-head-replay.8aFP0a/source_disposition_table.csv`, SHA-256
    `e8b13ca4fed1caeb9b48f9d1b33b1927290b7bc0c1ed887805bed16fdaeb073c`.
    Its bounded tags cover 32 new keys (four unsupported smoothed-path keys
    and 29 pre-TODO-52 PropBeta keys, with one overlap); 341 other new and
    all 183 absent keys remain unexplained. The raw inputs still lack
    source/package/native-DLL/RNG provenance, so this replay establishes
    reproducible key membership and limited source-scope tags only—not a
    current-package audit, complete dispositions, or authority to promote
    the baseline. A dirty-checkout audit produced 3,148 rows under later
    denominator changes and is not comparable to this tracked-HEAD replay.
    No canonical input, output, baseline, or stamp was changed.
- [ ] TODO-10 (added 2026-09-22, found the same way; a harness bug, not an
  inference-code bug): **MC coverage-truth uses the wrong covariate set** —
  `../bug_fix_plans/mc_coverage_truth_covariate_mismatch.md → TODO-1..6`. **Fixed.**
  `get_coverage_truth()`'s Monte-Carlo path (`COVERAGE_MC_SPEC`, ~25
  non-collapsible link-scale classes: Cox, logit/probit, GLMM/GEE) fit the
  class's own estimator against a synthetic single Gaussian covariate to
  compute the coverage target, but the graded rows were generated with the
  real dataset's full multi-column covariate matrix — for a
  non-collapsible coefficient the adjustment set changes the target
  itself. Confirmed on 13 of 25 `COVERAGE_MC_SPEC` classes (a 14th,
  `PropQuantileRegr`, found via a per-dataset check after the pooled check
  looked clean). Fixed via a shared
  `coverage_truth_uses_real_covariates()`/`coverage_truth_cache_key()`
  helper. `KKStratCoxPHOneLik`/`KKLWACoxPHOneLik` remain untrustworthy
  under the fix (their MC truth hasn't converged, likely genuine
  finite-sample attenuation bias, not a further harness bug) — do not
  re-run those two pending further work (plan's TODO-6).

  **New class found 2026-09-24** (plan's TODO-7, source fix completed
  2026-10-08): `InferenceSurvivalKMDiff` was missed by the original 25-class
  `COVERAGE_MC_SPEC` sweep — surfaced instead by this session's new
  `biased_estimate` audit check as apparent large bias, confirmed on
  investigation to be the same truth-scale-mismatch mechanism (estimator
  itself is unbiased at the null; `coverage_truth` is identical to raw
  `beta_T` for 100% of rows despite KM-difference being a non-collapsible,
  different-scale quantity). It is now covered by a survival MC-refit
  entry in `COVERAGE_MC_SPEC`; focused registry coverage includes that
  dispatch. This does not make the release TODO complete: the linked plan's
  comprehensive-results regeneration and baseline re-audit remain open.
  - [ ] Regenerate the affected survival and ordinal comprehensive rows with
    the corrected truth dispatch, reconcile every affected key/status, and
    rerun the baseline audit. Keep `KKStratCoxPHOneLik` and
    `KKLWACoxPHOneLik` excluded until the linked plan's convergence/policy
    gate is resolved.
  **Compile-free source regression recheck 2026-10-20:**
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-coverage-mc-registry-gaps-reference.R")'`
  passed 53 expectations (0 failures, warnings, or skips) after adding a
  bare `InferenceIncidLogRegr` dispatch case: a no-suffix fixed-formula label
  must default to `~.` and forward the real covariate matrix. This file parses
  `comprehensive_tests.R` and evaluates only named coverage-truth assignments
  in a stub environment; it exercises the `InferenceSurvivalKMDiff` MC-truth
  dispatch alongside the incidence/ordinal gap cases and checks key-specific
  seed isolation without fitting models or invoking native kernels. It is
  source/test-contract evidence only; the survival/ordinal results regeneration
  and baseline re-audit above remain open. The recheck also passed with
  `library(EDI)` loaded for installed EDI 1.0.3 (`EDI.so` MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`); the test stubs MC fitting and does not
  call package or native code. **Checkout-R source-overlay recheck, also
  2026-10-20:** the same test passed 53 expectations after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` (R-devel
  r90668, checkout namespace `/home/kapelner/workspace/EDI/R/EDI`, package
  version 1.0.3). Current `comprehensive_tests.R` SHA-256 is
  `0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`; the
  test SHA-256 is
  `e392d6fafe916fdc2f15daf088aef6f83c79a3b5eb32990014c3b789c2d9510b`.
  The loaded temporary DLL SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`
  matches the installed EDI DLL. The test parses current harness assignments
  and stubs the MC fit; no native fitting or calibration run occurred. This
  remains source-level dispatch evidence only, not result regeneration or
  baseline reconciliation.
  **Cache adjustment-set isolation, 2026-10-20:** extended and reran the
  same focused registry test with paired `~.` and `~1` requests for the same
  class/dataset/effect/response. The assertions confirm separate cache keys,
  the expected real-covariate versus `NULL` stub inputs, and reuse within each
  key. The focused `testthat::test_file(...)` run passed 59 expectations
  (0 failures, warnings, or skips) against installed EDI 1.0.3; the test
  evaluates selected current-harness assignments with a stubbed MC fit, not
  model fits or native kernels. This adds source/test-contract evidence only;
  affected-row regeneration and baseline reconciliation remain open, so
  TODO-10 stays unchecked.
  **Bounded source-overlay row pilot, 2026-10-20:** one rep at beta_T=0.5,
  family `estimate`, was run for `InferenceSurvivalKMDiff`/`cars` and
  `InferenceOrdinalRidit`/`diamonds`, with outputs isolated under
  `/tmp/edi-todo10-row-pilot.WQ09ZP`. The exact four expected natural keys
  (each selected class's `compute_estimate` row under `design_formula=~1` and
  `~.`) equaled the observed keys: 4 rows, all `ok`, no missing, extra, or
  duplicate keys, and finite coverage truths. The runner used checkout R via
  `R_PROFILE_USER` and `pkgload::load_all(..., compile = FALSE)`; provenance
  records checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, source
  namespace `/home/kapelner/workspace/EDI/R/EDI`, and temporary DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  These candidate rows validate only the two selected estimate-family cases;
  they do not complete affected-class/family/dataset/beta/replicate coverage
  or the baseline re-audit. Canonical outputs were not modified.
  **Survival expected-attempt roster regression, 2026-10-20:**
  `test-todo10-survival-expected-attempt-roster-reference.R` passed both test
  blocks, 29 expectations total (0 failures, warnings, or skips; exit 0).
  Its source-derived fixture reconciles a deliberately reduced 272-key roster
  from the runner's survival dispatch, including class availability, the two
  formula axes, estimate labels, LogRank asymptotic labels, and the
  incidence-only exact-family guard. This is static eligibility/roster
  evidence, not a fit, real-attempt inventory, full method roster, corrected
  result regeneration, or baseline audit. The test ran under R-devel
  `r90668` with installed EDI 1.0.3; `testthat::test_file()` attached the
  package, but the test only parses runner/class sources and invokes no native
  fitter. The loaded DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; runner SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`;
  test SHA-256
  `2d40fbde3c8686bc8b4ed5133b2e27eb944db83aba74b392892e9c4f89ee015d`.
  Full affected-row regeneration and baseline re-audit remain open. No build,
  fit, result generation, or canonical output write occurred.
  **Focused source-roster rerun, 2026-10-21:** reran
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo10-survival-expected-attempt-roster-reference.R", reporter = "summary")'`;
  both test blocks passed (29 expectations, 0 failures, warnings, or skips).
  The test derives its reduced 272 natural keys from parsed runner dispatch,
  source class eligibility/inheritance, and declared function labels rather
  than observed result rows. The roster covers estimate attempts and the
  source-declared LogRank asymptotic labels for its reduced fixture; it does
  not establish the full runner method inventory, real-attempt output
  completeness, or result provenance. Test SHA-256 remains
  `2d40fbde3c8686bc8b4ed5133b2e27eb944db83aba74b392892e9c4f89ee015d`; the
  parsed current runner SHA-256 is
  `1b12a10860e566d3402cc7d799669c7a94ac20bb6e37d348d249c15e2a293b1a`.
  EDI 1.0.3 attached, but no fitter/native code was invoked. Full affected-row
  regeneration, exact production-key/status reconciliation, and baseline
  re-audit remain open; no build or canonical output write occurred.
  **Ordinal expected-attempt roster input guards, 2026-10-21:** the existing
  `test-comprehensive-coverage-mc-registry-gaps-reference.R` fixture now also
  rejects an omitted explicit `skip_slow` flag and a nonlogical
  `has_compute_estimate`, matching `comprehensive_ordinal_coverage_attempt_manifest()`'s
  documented validation errors. The focused full-file run passed (no failures,
  warnings, or skips) with installed EDI 1.0.3 attached. This fixture derives
  the reduced 84-key ordinal roster from two cases, seven selected direct-call
  classes, two formulas, and the explicit estimate/Wald flags; its validation
  assertions prove only the pure-R fixture guard and exact reduced roster, not
  live class capabilities or emitted-attempt completeness. It parses current
  runner/helper source and calls no fitter/native kernel; no build or result
  write occurred. Test/helper/runner SHA-256 at the run:
  `88e57fa56d7eef713b212ad6a4283ad26690a1ab4b7fae4d9cd27b1bbc157db2` /
  `5877432dbcb9515bd33717ea4792f442e64c48f96d73fcdcba1b7fe304ed410e` /
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`.
  Full affected-row regeneration, exact production-key/status reconciliation,
  and baseline re-audit remain open.
  **Source-derived production case-lattice regression, 2026-10-21:**
  `test-todo10-survival-expected-attempt-roster-reference.R` passed all 41
  expectations (0 failures, warnings, or skips; exit 0). This invocation
  suppressed the test file's `library(EDI)` call and loaded only `testthat`,
  so it parsed source and asserted roster dimensions without loading EDI or
  calling native code. The new parser derives the 9 dataset/response pairs,
  runner beta/design/formula axes, and produces 20,160 *candidate case rows*
  at `Nrep=40`: 10,080 each for survival and ordinal, with half each for
  design formula `~1` and `~.`. Every row is explicitly conditional on
  dataset/design/inference setup and runtime support; this is not an emitted
  attempt/result-key manifest and does not predict constructor failures or
  skips. The unresolved `InferenceSurvivalKKLWACoxPHOneLik` and
  `InferenceSurvivalKKStratCoxPHOneLik` are preserved in the lattice's
  explicit excluded-class metadata. Test SHA-256
  `dabe7c201dceab9e6888808425bd05c81544ac4e8a26f95c2f476867c58032fb`,
  runner SHA-256 `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`,
  dataset-source SHA-256 `7e3cf603ef384c369c4435dc5ca0b541d9248bbda9e5db7f3c17b2b41628bdda`.
  Full affected-row regeneration, exact production attempt/status reconciliation,
  and baseline re-audit remain open; no fit, build, package load, or result write.
  **Read-only actual-attempt artifact audit, 2026-10-20:** the retained
  source-overlay pilot at `/tmp/edi-todo10-row-pilot.WQ09ZP` contains exact
  two-key slices for `InferenceSurvivalKMDiff`/`cars`/survival/Bernoulli and
  `InferenceOrdinalRidit`/`diamonds`/ordinal/Bernoulli, each with
  `design_formula=~1` and `~.` and `function_run=compute_estimate`. Both slices
  exactly match their independently reconstructed expected keys: two rows,
  no missing/extra/duplicate key, both `status=ok`, and unique `id` and
  `run_row_id`. Recorded sidecar path, byte count, and CSV SHA-256 match each
  artifact; before/after R/EDI/DLL/checkout/diff/runner identity fields match.
  Provenance: R-devel `r90668`, EDI 1.0.3, HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Survival CSV/sidecar SHA-256:
  `e467af71f4ae3755d5e97bf8f403d8e91d11880b531c962845eae114ad77bbc5` /
  `b0397e49108d5610b405d6f134327f937f71736f17750768cd81012139c6511e`;
  ordinal CSV/sidecar SHA-256:
  `aa042a5bdac1ca0a30be61065a2250070672e7c59ec4245928956c83785da3e5` /
  `a677c6ddf0d115320981d016c01f9e0c47b51ae6271d389108450b2d86dadc41`.
  These retained sidecars are schema 1; the current artifact validator
  requires schema 2, so this manual slice audit is not validator acceptance.
  It covers neither the full affected grid nor the baseline re-audit. No fit
  was rerun and no output was written. A later schema-2 recapture and
  artifact-side disposition are recorded below; full-row reconciliation and
  baseline audit remain open.
  **Schema-2 artifact/roster reconciliation, 2026-10-21 (read-only):** the
  later `/tmp/edi-todo10-schema2.HNmaUs` cohort has the same four
  `compute_estimate` keys (two formulas each for SurvivalKMDiff/cars and
  OrdinalRidit/diamonds); each two-row CSV has unique IDs and both rows
  `status=ok`. With the two independently specified case keys per CSV,
  `validate_comprehensive_result_artifact()` passed both artifacts' schema-2
  sidecar, CSV byte/SHA identity, before/after identity, and exact-key checks.
  CSV/sidecar SHA-256 pairs are `d423a5c2ec64e1bcffe3b6c6e6e4d431612fd27a8454f38245dcf20d12d0e6c4` /
  `813c808727758eaf078949371a59a950c1a4ca8d558dffdacde497d4bc65f4f8` for
  survival and `51ea567ba01e964e40ad661b8d34f4981ca1a2a4e9e06317c8e3e7033aa1fbc4` /
  `7579fd2c97b99c7271feb12809f758930738ca01404a0660991f5bc8bfa87847` for
  ordinal. However, the 272-key roster test is a deliberately reduced source
  fixture over `toy-a`/`toy-b`, reps 1:2, beta 0/0.5, and survival dispatch;
  it is not a production result manifest. Exact natural-key intersection with
  these four pilot rows is zero: the SurvivalKMDiff rows match the roster's
  class/design/formula/estimate shape but use `cars` rather than a toy dataset,
  while OrdinalRidit is outside this survival roster. Thus the pilot cannot be
  counted as 4/272 complete or as 272 missing production attempts. The
  bounded production-shaped roster for these retained slices is independently
  derivable from current source: `cars$y_original` includes survival and
  `diamonds$y_original` includes ordinal; Bernoulli is in `TESTED_DESIGNS`,
  the filtered run selects beta 0.5 and rep 1, each class has a matching
  Bernoulli entry in `COVERAGE_MC_SPEC`, the runner traverses `~1` and `~.`;
  the estimate-family route emits `compute_estimate`. This yields exactly the
  four observed natural keys (2 per class/case), with no absent or extra key
  within those two selected slices. It is intentionally not a full production
  roster: it says nothing about other eligible classes, supported
  dataset/response pairs, families, beta values, or reps, whose runtime
  dispatch/skip outcomes still need a provenance-matched regenerated artifact.
  The schema-2 sidecars are internally validator-valid for their captured run,
  but stale relative to the current source snapshot: they record runner SHA
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`, whereas
  the current runner is `1b12a10860e566d3402cc7d799669c7a94ac20bb6e37d348d249c15e2a293b1`;
  they record package-payload SHA
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`, and
  checkout R/source files have post-capture modifications. Same HEAD does not
  make the captured dirty diff current. The earlier schema-1 cohort still
  fails the current validator (`unsupported or missing ... schema`). Next
  safe step for full acceptance: derive the complete eligible production
  roster from the corrected runner/spec and supported dataset/beta/rep/family
  axes, then regenerate/reconcile that scope with fresh schema-2 provenance.
  No result, canonical, or baseline file was changed.
  **Retained canonical-artifact inventory, 2026-10-21 (read-only):** the
  identified `/tmp/edi-todo10-*` simulation cohorts contain only the two
  schema-2 pilot CSV/sidecar pairs above: four selected `compute_estimate`
  keys total, valid only for their captured run. Those sidecars record runner
  SHA-256 `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`;
  the current raw `comprehensive_tests.R` file hashes to
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`.
  The 20,160-row source case lattice remains candidate scope, not an emitted-
  attempt roster: setup eligibility, `function_run` emission, and runtime
  skip outcomes are unresolved. Canonical survival and ordinal CSVs are
  372,209,537 bytes (2026-09-27) and 417,165,307 bytes (2026-10-09), with no
  adjacent provenance sidecars. No current-source complete or reconcilable
  result exists beyond the four-key pilot. Full attempt-roster/setup-outcome
  derivation, current-source schema-2 regeneration, exact key/status/value
  reconciliation, and baseline re-audit remain open; no simulation or
  canonical write occurred.
  **Deterministic MC-truth retry/cache/RNG regression, 2026-10-21:** the
  linked `test-comprehensive-coverage-mc-registry-gaps-reference.R` now
  covers retry after implausible finite and non-finite MC results, the exact
  per-attempt seed-state sequence derived from the cache key, acceptance and
  caching of the first plausible result, cache reuse without another fit,
  and five-attempt exhaustion returning `NA` without caching. Its stubbed
  fitter keeps this a deterministic source-contract test rather than a
  calibration run. The focused command
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-coverage-mc-registry-gaps-reference.R")'`
  passed 89 expectations (0 failures, warnings, or skips; exit 0); it attached
  installed EDI 1.0.3 but evaluates only selected harness assignments and
  does not call native code. This adds no evidence for complete affected-row
  regeneration, current-source/native provenance, or baseline re-audit; those
  gates remain open and no canonical results were changed.
- [x] TODO-11 (added 2026-09-22, closed 2026-10-08 after re-audit;
  **resolved — do not enable**): **Cox
  Bartlett-approx likelihood-ratio correction, forced off** —
  `../new_feature_plans/enable_cox_bartlett_approx.md`. A 300+300-rep validation of the
  currently-forced-off Bartlett-approx path on `InferenceSurvivalCoxPHRegr`
  (`n=100`, `B=49`, ~1.4h runtime) showed no improvement over plain Wald
  (Type-I error 0.077 vs. Wald's 0.057, nominal 0.05; CI coverage 0.937 vs.
  Wald's 0.947, nominal 0.95) — mild over-rejection/under-coverage if
  anything. **Decision: leave both Cox classes' explicit `FALSE` as they
  are.** Revisiting would need its own budgeted multi-scenario/multi-class
  simulation (each such run costs over an hour), not something to do
  speculatively. Both Cox classes still explicitly decline approximate and
  exact Bartlett support, omit the testing type, and reject the entry point;
  an eight-assertion source-loaded regression pins that opt-out and the linked
  plan confirms that no release subtasks remain.
- [ ] TODO-12 (added 2026-09-22, core fix implemented 2026-10-07;
  release verification still open; found during
  TODO-9's own final review,
  not a new audit finding; no concrete class reaches it yet): **Latent
  `cached_mod` reset gap, same bug shape as TODO-9** —
  `../bug_fix_plans/stale_worker_cache_resampling.md → TODO-9`. One level up from the
  `cached_values` gap TODO-9 fixed, the same randomization loader still
  resets a hand-maintained private-field allowlist that's missing
  `cached_mod` — the identical failure shape, just one field over.
  Confirmed a landmine, not a live defect (every concrete class writes
  `cached_mod` unconditionally rather than reading it stale; TODO-9's
  240-class non-degeneracy sweep found no additional degenerate class).
  Fixed by routing every reused-worker loader through one context-aware
  private-cache reset helper. Structural and two-draw reused-versus-fresh
  regressions cover randomization, bootstrap, and randomization-bootstrap;
  focused source-loaded tests pass without compilation. The isolated TODO-12
  baseline is recorded below; the release-wide pre/post bit-for-bit sweep
  remains open because the broad 614-file comparison is not a comparable
  TODO-12-only baseline. After the user's
  2026-10-14 reinstall, the CRAN private-cache-reset regression passed all
  55 assertions against the installed package. **Isolated source comparison,
  2026-10-18:** recovered pre-fix source at `362c5d28` and isolated only the
  TODO-12 helper plus its two randomization-loader call-site changes from
  `70b55982`; both sides used the same staged native library and identical
  fixture/sweep hashes. Across 240 shared entries, 234 were bit-identical,
  five were repeatable noise, and one stable `MOVED` result was
  `InferenceContinRobustRegr|bernoulli|continuous|production` (max absolute
  difference 0.139). The movement is reproducible across post repeats and is
  now adjudicated against the class contract: `best_X_colnames` is selected
  from the original fit and the randomization refit explicitly uses that same
  design-matrix structure, so clearing it and reselecting under each draw is
  an unintended semantic change. A narrow follow-up preserves only this field
  for `InferenceContinRobustRegr` assignment workers; the loader class check
  uses the exact active R6 worker object selected from `worker_state`, while
  the sync call checks its `thread_inf_obj`. The other classes keep the
  existing reset policy. A three-draw regression compares the reused
  output with independent direct `MASS::rlm` fits using the original selected
  covariate set. **Refined isolated sweep, 2026-10-18:** using the exact
  pre-fix source at `362c5d28`, the same staged native library, and unchanged
  fixture/seed definitions (`RESAMPLING_NONDEGENERATE_SEED = 20260922`,
  `r = 15`), the class-scoped refinement returned the
  original robust-regression production distribution bit-for-bit (max
  absolute difference 0), consistent with the fixed-original-covariate
  contract. The run used R Under development (2026-10-13 r90668), exact
  pre-fix source commit `362c5d28fa6233d99d6d6815d1bffa02f5aa33ab`, and
  compile-disabled source loading. Across all 240 entries, 235 were bit-identical, five were
  repeatable floating-point noise, and there were zero `fixed` or `MOVED`
  entries. The only noise rows were
  `InferenceAllKKMeanDiffIVWC|kk|continuous|forced`,
  `InferenceBaiAdjustedTKK14|kk|continuous|forced`,
  `InferenceBaiAdjustedTKK21|kk|continuous|forced`,
  `InferenceAllKKMeanDiffIVWC|kk|proportion|forced`, and
  `InferenceAllKKMeanDiffIVWC|kk|survival|forced`; all were within 1.11e-16.
  Pre/pre noise-floor comparison remained 235 identical / five noise / zero
  `MOVED`. Provenance: staged `EDI.so` SHA-256
  `20f5713ae07cf3c7f53b7e5b66657bce028183a1b74d778d83fe0b061135f3a9` on
  both source trees; fixture-registry SHA-256
  `b31d1a4b9ef9da754cfc492c990975d52080d43bf7e8fbfa8eaa4ef96fbadccd`;
  pre snapshots SHA-256 `2ed850bfe71a073e36ee0aa6d264049a1062d131accbc7a9f44bbb171e14250e`
  and `865e7580b555079a0359fec20e9ad455fd004de67d572b5bc3648c734789d83f`;
  refined snapshot SHA-256
  `222a87ce4aac5304cdc9790c39bae4167cfa876ec2e8e117d4e7c861a2a1fb63`.
  The source-loaded robust-regression reference test passed 14/14 assertions;
  it loaded checkout R code with `compile = FALSE` and installed EDI 1.0.3
  native DLL MD5 `dd43c5d0e11708aea17ba82b900f66d1`. No compilation ran; the
  current-native verification gate remains separate. TODO-12 release
  acceptance remains open pending the release-wide sweep and authorized
  native gate.
  **Runner/fixture-scope preflight, 2026-10-18 (read-only):** the current
  `test-reused-worker-resampling-nondegenerate.R` SHA-256
  (`b31d1a4b9ef9da754cfc492c990975d52080d43bf7e8fbfa8eaa4ef96fbadccd`)
  matches both staged source trees; the sweep runner SHA-256
  (`645db2a8acd8d8815d6c44561e410343119428cb422951d4f9a152cb490c1081`)
  also matches both. This independently confirms that the current fixture
  registry and runner match the recorded 240-entry isolated sweep inputs; the
  staged `EDI.so` identity is already recorded above. It is scope/provenance
  preflight only, not a release-wide rerun or current-checkout native
  validation. Keep all future RDS snapshots under `/tmp`; this preflight read
  no canonical comprehensive results and does not contend with TODO-56's
  shared-result paths.
  **Positive comparator-contract regression, 2026-10-20:** the existing
  sweep-contract test now also proves a valid two-key synthetic pair is
  accepted with identical expected keys/package version/native-DLL digest
  while installed-lazyload and checkout-source R provenance differ; its
  result asserts one bit-identical and one substantive `MOVED` distribution.
  The focused test passed 37 expectations with checkout R loaded via
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; test SHA-256
  `32fa2407c994826374e3c2cb56717a2173e8f354231799a97b081989ab39ab9a`,
  temporary loaded DLL MD5 `8b3ca30492d7b1c790deeebe94b201ad`. This is
  comparator-contract evidence only: no distribution or snapshot was
  generated, and the release-wide paired sweep, retained-artifact
  reconciliation, and current-native gate remain open.
  **Current harness provenance recheck, 2026-10-19 (read-only):** checkout
  `HEAD` is `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Since the recorded
  2026-10-18 preflight, commit `4d2531e9` changed the sweep runner and fixture
  registry. Their current SHA-256 values are respectively
  `826f9518760c89d238a493cdb1de2244152bc555644e45226272091075f7df28` and
  `5c1a428134aee72b969d06f446171d34a8d28bfb88e399b641ee7562109f2d53`, not
  the previously recorded hashes. The diff adds strict enumeration/failure
  checks and snapshot key/shape validation; it does not change the sweep's
  distribution calculation or arm/data fixture definitions. This strengthens
  the runner but means the old artifacts are not provenance-matched to the
  current harness.
  No sweep was rerun; release-wide acceptance remains open and requires
  current authorization for its broad run.
  **Snapshot/output safety precondition (2026-10-20):** the sweep runner's
  `record()` writes directly to its caller-supplied path and can overwrite an
  existing file. Any future run must use distinct, non-existing absolute
  snapshot paths under a fresh `/tmp` directory; stop rather than pass a
  checkout/canonical path or reuse a filename. The legacy `--source` recipe
  copies the installed DLL over `R/EDI/src/EDI.so` and then removes that path;
  do not execute it as written or overwrite/remove an existing staged DLL.
  Capture R version, checkout HEAD/status/diff, runner and fixture hashes, and
  native DLL path/hash externally before and after the paired run: snapshot
  provenance records package/native/R-layer identity but not those run inputs.
  **Existing artifact-only integrity check, 2026-10-19:** read-only
  `readRDS()` inspection of `before-1.rds`, `before-2.rds`, and
  `after-refined-v2.rds` found 240 uniquely named entries in each, with
  identical key sets. The two pre snapshots and refined post snapshot match
  their recorded SHA-256 values above, but none carries the new runner's
  `expected_keys` attribute. This confirms internal key-set consistency only;
  it cannot establish that strict current-source enumeration would produce
  exactly these keys, so it does not replace a rerun with the updated runner.
  **Registry-routing metadata correction, 2026-10-20:** the strict
  enumeration preflight had selected `InferenceIncidExactBinomial` for the
  Bernoulli arm, where construction correctly rejects the design. Its class
  contract permits only `DesignFixedBinaryMatch` or KK-capable designs, but
  the registry's name/override rule had left `requires_kk_matching_design`
  false. Added the explicit KK-required override and assertions for both the
  inferred routing flag and resolved registry metadata. The focused
  source-loaded registry test passed 43 expectations with checkout R code
  loaded using `compile = FALSE` against installed EDI 1.0.3; the test
  exercised registry/R metadata only. A follow-up no-draw strict-enumeration
  smoke loaded the runner helpers and completed candidate selection across
  all arms and response types. ExactBinomial routed only to `kk`; its targeted
  KK-incidence constructor check succeeded but produced zero reusable-worker
  candidates, so no distribution key is expected for this class. No
  distribution was called and no snapshot was written. This did not run the
  runner's `record` mode or validate old snapshot coverage; those snapshots
  still lack the current `expected_keys` attribute. No canonical artifacts
  were read or written. Release-wide pre/post parity, current-native
  verification, and result reconciliation remain open.
  **Persistent candidate-exclusion regression, 2026-10-20:** the existing
  sweep-contract test now asserts that ExactBinomial is absent from Bernoulli
  incidence candidates and, after strict KK-incidence construction, contributes
  zero reusable-worker cases. The focused source-loaded run passed 27
  expectations, made no resampling-distribution call, and wrote no snapshot;
  provenance and hashes are recorded in the linked plan. **Compile-free
  manifest-guard extension, 2026-10-20:** broadened that same fixture with
  an assertion that `validate_sweep_snapshot()` rejects a duplicate expected
  key. The checkout-source test passed 28 expectations via
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE,
  export_all = FALSE)` followed by `testthat::test_file(...)`, using the
  existing installed EDI 1.0.3 native DLL. No distribution call or snapshot
  write occurred. This pins duplicate-manifest rejection only; it does not
  establish full manifest completeness, paired parity, or current-native
  validation. **Retained-artifact acceptance check, 2026-10-20:** read-only
  inspection confirmed that all three retained 240-entry RDS snapshots match
  their recorded SHA-256 hashes and have unique names, but lack both the
  `expected_keys` and `provenance` attributes required by the current
  comparator. Their names/key-set agreement alone is not acceptance evidence;
  do not retrofit run metadata. Added a focused missing-manifest comparator
  regression; the complete sweep-contract test passed 31 expectations with
  checkout R sources loaded using `compile = FALSE` (the installed-only run
  fails two existing registry assertions because EDI 1.0.3 is stale). No
  distribution was called and no snapshot was written. Provenance and hashes
  are recorded in the linked plan. Release-wide paired parity and
  current-native verification remain open.
  **Installed-native focused recheck, 2026-10-20:**
  `test-reused-worker-private-cache-reset.R` passed 55 expectations (0
  failures, warnings, or skips) against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Its installed
  `DESCRIPTION` SHA-256 is
  `4a90096cefbca36c7f68d2d53af5821ed7747fa20d0d359880bcd704372998f0`;
  loaded `EDI.so` SHA-256 is
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  The DLL is byte-identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but this does not establish
  source/build provenance; installed and checkout DESCRIPTION hashes differ.
  This confirms the focused installed-artifact cache-reset regression only.
  The release-wide paired sweep and reproducible current-source/native
  provenance gate remain open. No build/install, sweep, or canonical output
  was produced.
  **Current installed sweep-contract recheck, 2026-10-20:** attached
  installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` and ran
  `testthat::test_file("R/package_tests/testthat_bulk/test-reused-worker-bitforbit-sweep-contracts.R")`;
  all 31 expectations passed with no failures, warnings, or skips. The
  deterministic test covers mocked failure handling, installed-registry
  routing, snapshot key/NA/provenance rejection, and all-NA classification; it
  calls no resampling distribution and writes no sweep snapshot. The test
  sources the current checkout runner (SHA-256
  `4510d0e8a56ffa681c84e3de8e7057b44c87f8bb581c88b8f0114ffb8c5e6bdf`); test
  SHA-256 is
  `a63dd474cf8f907112d1dcba0c56999180badf124b50484845646f84382ca922`.
  Installed DESCRIPTION SHA-256 is
  `9bc2620857fc1dce03c0cf8f0ce91f51c2385da011fb8d8c6f4264ef9c9231c5`; loaded
  `EDI.so` SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This validates the harness contract against the latest installed namespace,
  not actual reused-worker distribution behavior; the release-wide paired
  sweep, artifact reconciliation, and reproducible current-source/native
  provenance remain open. No build/install or canonical output write.
  **Comparator fail-closed edge recheck, 2026-10-21:** broadened the existing
  sweep-contract fixture to exercise an `after.rds` with two extra names,
  missing `expected_keys` on either side independently, and missing R/native
  provenance on the after side. `testthat::test_file()` passed 39
  expectations (0 failures, warnings, or skips) with installed EDI 1.0.3;
  the test sources the checkout sweep script and writes only synthetic RDS
  files under `/tmp`. The comparator rejects all three cases. This covers
  artifact-structure failure paths only; no real snapshot was read or
  produced, and release-wide paired runtime parity, current-native
  verification, and retained-artifact reconciliation remain open.
  **Three-snapshot run preflight, 2026-10-21:** the pending 720 evaluations
  comprise two same-source pre-fix noise-floor snapshots plus one post-fix
  snapshot, each with the exact 240-key source-derived roster (registry,
  strict arm/design construction, reusable-worker capability), `r=15`, seed
  `20260922`, three arms (`bernoulli`, `kk`, `blocking`), six response types,
  and production/forced paths. No current matched artifact pair is usable:
  the recorded 240-entry RDS/staging paths are absent, and the bounded `/tmp`
  inventory found only synthetic comparator fixtures. Current preflight
  identities are HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, working-tree
  runner SHA-256
  `4510d0e8a56ffa681c84e3de8e7057b44c87f8bb581c88b8f0114ffb8c5e6bdf`, fixture
  SHA-256 `5c1a428134aee72b969d06f446171d34a8d28bfb88e399b641ee7562109f2d53`,
  and matching installed/staged DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`. These
  are point-in-time preflight values, not historical-run provenance. No R
  test/workload or output generation ran; await explicit run approval and
  freeze/record a reproducible pre/post source bundle before execution.
  - [x] TODO-12-only paired sweep and noise-floor review: 240 entries, 235
  bit-identical, five repeatable noise, zero `fixed`, zero `MOVED`, with the
  robust-regression result restored exactly to the original source result.
  - [ ] Run the release-wide pre/post sweep on identical fixtures and RNG
  seeds with matching package/native environments; review every `fixed`,
  `noise`, or `MOVED` classification. The separate broad
  `362c5d28..430c19bc` comparison spans 614 files and is not attributable to
  TODO-12; do not use its `MOVED` rows for release acceptance. Native-build
  verification remains a separate gate and requires explicit user
  permission; no build/install was performed for this review.
  **Live `/tmp` snapshot inventory, 2026-10-21:** the historical paths
  `/tmp/edi-todo12-paired-53rKFp/before-1.rds`,
  `/tmp/edi-todo12-paired-53rKFp/before-2.rds`, and
  `/tmp/edi-todo12-refined-9EdvIW/after-refined-v2.rds` are now absent. A
  read-only search of 669 `/tmp` RDS files found no match for their recorded
  SHA-256 values (`2ed850bfe71a073e36ee0aa6d264049a1062d131accbc7a9f44bbb171e14250e`,
  `865e7580b555079a0359fec20e9ad455fd004de67d572b5bc3648c734789d83f`, and
  `222a87ce4aac5304cdc9790c39bae4167cfa876ec2e8e117d4e7c861a2a1fb63`). The
  remaining TODO-12-prefixed RDS files are tiny synthetic comparator fixtures
  or staged `testthat-problems.rds`, not run snapshots. The historical
  240-key/key-set and hash check above therefore cannot be repeated against
  extant artifacts; those old snapshots also lacked `expected_keys` and
  `provenance` and were not acceptance-eligible. Current preflight identity is
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9` and runner SHA-256
  `f22124b58abc774b1a66b174cf18007b8048ac3a62b929e77805c9d606b19a45`.
  The required fresh evidence remains three snapshots × 240 keys × `r=15`
  (720 evaluations). This audit did not run them: the user explicitly
  prohibited that workload, and fresh explicit user approval is required
  before it can be launched. No artifact was modified.
  **Checkout-R source-overlay regression, 2026-10-20:**
  `test-reused-worker-private-cache-reset.R` passed 55 assertions (0 failures,
  warnings, or skips) using `pkgload::load_all("R/EDI", compile = FALSE,
  quiet = TRUE)` and `testthat::test_file(...)`. The test covers cache reset
  across randomization, bootstrap, and randomization-bootstrap small fixtures.
  Checkout namespace was `/home/kapelner/workspace/EDI/R/EDI`; loaded
  temporary DLL MD5 `8b3ca30492d7b1c790deeebe94b201ad` matches installed and
  checkout `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This is focused source-overlay evidence only, not the release-wide 614-file
  identical-fixture/seed sweep or its required review of every classification.
  No build/install, sweep, or result write occurred; the release-wide sweep
  and separate native/provenance gate remain open.
- [ ] TODO-13 (added 2026-09-22, surfaced as a `KNOWN_BROKEN` entry in
  TODO-9's regression test, root-caused same day on user request):
  **`InferencePropGCompMeanDiff` randomization distribution all-NA in
  production** — `../bug_fix_plans/prop_gcomp_sample_usable_gating.md → TODO-1..6`.
  **Fixed 2026-09-23.** An error-shaped bug (`NA_real_` every draw), not
  silently-wrong like TODO-9/TODO-12, and a different mechanism entirely —
  worker-state gating, not stale caching. The class's reused-worker
  fast-path estimator gates on `worker_state$runtime$sample_usable`, which
  only the *bootstrap* row-sample loader ever sets true; the class never
  overrides the randomization path's estimator, so it falls through to the
  generic delegate that reuses the bootstrap estimator — on the `rand`
  path that flag is permanently stuck at its init value `FALSE`, so every
  draw returns NA. Fixed with a class-specific
  `compute_randomization_worker_estimate()` override reusing the
  already-correct standard-path logic. **Reconciled 2026-10-10:** linked
  TODOs 1--5 (direct trace, override, bootstrap bit-for-bit preservation,
  true-null check, and removal from the nondegeneracy exclusion) are all
  complete; the focused regression rerun passed 13/13. Only TODO-6's
  post-install comprehensive-CSV regeneration remains, coordinated with
  the stale-worker-cache regeneration pass, so this release item stays
  unchecked. **Checkout-source recheck 2026-10-20:** the linked focused
  randomization regression passed all 6 assertions with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` under R-devel
  `r90668`, checkout version 1.0.3. The tested R source SHA-256 is
  `cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63`; the
  test SHA-256 is
  `a95ee0ebd70c2680d531cc50f40c4a46f028fc3b0498a21fea85fbab41e33906`.
  The existing EDI 1.0.3 native DLL loaded by pkgload matched the installed
  DLL, SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  This is focused checkout-R/current-existing-native evidence only; no
  compile/install or canonical result write occurred. **Current-artifact
  recheck, 2026-10-20:** reran the same 6-assertion test with checkout R under
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; it passed with
  no failures, warnings, or skips. The temporary loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  matched the installed user-rebuilt DLL and checkout `R/EDI/src/EDI.so`
  byte-for-byte (`cmp -s` succeeded). Source/test SHA-256 values are
  `cc5e502fedd2b6c4f2d259341445d7a3f003ee947aee900b97f673a247ef1a63` /
  `a95ee0ebd70c2680d531cc50f40c4a46f028fc3b0498a21fea85fbab41e33906`.
  This closes focused current-R/current-native regression provenance only;
  complete post-fix `rand` CSV regeneration and exact-key/status reconciliation
  remain open. No build/install or canonical output write occurred.
  **Isolated scaling pilot, 2026-10-20:** the runner accepts only one scalar
  `REP_FILTER` and seeds once at startup, so separate invocations for reps
  11--20 would restart the same RNG stream. To preserve a continuous stream,
  ran one fresh isolated `Nrep=20` process with the prune-skip guard, then
  inspected only reps 11--20. It completed in about 114 seconds (under the
  180-second whole-process cap); the output contains 240 rows total, with 12
  unique runner IDs per rep and `status=ok` throughout. Reps 11--20 contain
  120 rows (12 each), covering all four model/design formula pairs and the
  three eligible `rand` calls per pair; all 120 IDs are unique, all 40 CI rows
  have finite endpoints and nonmissing coverage truth, and there are no error
  messages. This is one `airquality`/beta=0.5/Bernoulli pilot only, not evidence
  for the full eligible grid or an extrapolation to its runtime. Checkout R
  source was loaded with `pkgload::load_all("R/EDI", compile=FALSE)` under
  R-devel `r90668` (checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  package version 1.0.3); the loaded existing DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Isolated CSV:
  `/tmp/edi-todo13-reps11-20.l7cZnQ/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `3d57bd3f066ab07ccbb34ca76a5cfd20c3809b3f26b7388a53b2f91aaf9ceffc`);
  its sidecar records the command, checkout diff hash, DLL hash, and run
  interval. The isolated run did not use `--apply` or write canonical results.
  **Additional isolated pilot, 2026-10-20:** after waiting for the other
  comprehensive runners to exit, ran a fresh `Nrep=25` process under the same
  prune-skip guard and 180-second cap, then inspected reps 21--25. The runner
  also computed reps 1--20 in this fresh output to preserve its single-seed
  sequence. It exited successfully in about 128 seconds; the CSV has 300 rows
  total, with 12 unique IDs per rep and `status=ok` throughout. Reps 21--25
  contain 60 rows (12 each), spanning all four model/design formula pairs and
  three eligible `rand` calls per pair; all 60 IDs are unique, all 20 CI rows
  have finite endpoints and nonmissing coverage truth, and there are no error
  messages. This remains a single `airquality`/beta=0.5/Bernoulli pilot, with
  no runtime extrapolation. Provenance sidecar records R-devel `r90668`, EDI
  1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded
  DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Isolated CSV:
  `/tmp/edi-todo13-reps21-25.0iWTyQ/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `945ef4998f234e84d3991b44272a31652da0ca584fb3959f52d45380d629d665`).
  Sidecar:
  `/tmp/edi-todo13-reps21-25.0iWTyQ/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T165157.205885-pid4.rds`
  (SHA-256 `76de6491229ca6754dabffed4240f1d6e5afd753e6a9e83ba5067de65c00229e`).
  No `--apply`, build/install, or canonical result write occurred; the
  complete supported proportion `rand` grid and exact-key reconciliation
  remain open.
  **Third isolated pilot, 2026-10-20:** after the R/Rscript process table was
  clear, ran a fresh `Nrep=30` process under the same prune-skip guard and
  180-second cap, then inspected reps 26--30. Reps 1--25 were also computed in
  the isolated run to preserve its single-seed sequence. It exited successfully
  in about 160 seconds; the CSV contains 360 rows, 12 unique IDs per rep, and
  `status=ok` throughout. Reps 26--30 contain 60 rows (12 each), spanning all
  four model/design formula pairs and three eligible `rand` calls per pair;
  all 60 IDs are unique, all 20 CI rows have finite endpoints and nonmissing
  coverage truth, and there are no error messages. This is still only the
  `airquality`/beta=0.5/Bernoulli pilot; no runtime extrapolation is made.
  Provenance sidecar records R-devel `r90668`, EDI 1.0.3, checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Isolated CSV:
  `/tmp/edi-todo13-reps26-30.BNb9W3/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `620f89184c11e31ec9c15286d6ff4a176edb366ff1ab878fb08b6549f0bc7159`);
  sidecar:
  `/tmp/edi-todo13-reps26-30.BNb9W3/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T171237.868245-pid4.rds`
  (SHA-256 `937a81efff20ee69357df361ee34c3ad155f42800c579af4a4f40bd9d4379c2f`).
  No `--apply`, build/install, or canonical result write occurred; full-grid
  regeneration and exact-key reconciliation remain open.
  **Replicate-continuation audit, 2026-10-20:** the current runner resets to
  `set.seed(1)` at startup, accepts only one scalar `REP_FILTER`, and has no
  option to restore an initial RNG state or select a range. Although the Nrep=30
  sidecar records its final `.Random.seed`, the runner does not consume that
  state; reusing a scalar filter would skip intervening reps without advancing
  RNG, so it would not produce the authentic reps 31--40 stream. Injecting a
  saved seed and relabeling or rewriting result IDs would require an unsupported
  alternate harness/provenance path. At the time of this audit, no reps 31--40
  run was started. A subsequent complete Nrep=40 pilot below covers the
  selector without relying on seed continuation. The earlier partial pilots
  are separate seeded processes and should not be concatenated as one
  replication stream. Full-grid/exact-key acceptance remains open.
  **Complete isolated selector pilot, 2026-10-20:** after confirming no
  R/Rscript runner was active, ran a fresh Nrep=40 process with `REP_FILTER=NA`,
  the tested prune-skip guard, checkout R loaded using
  `pkgload::load_all("R/EDI", compile=FALSE)`, and a 240-second cap. It exited
  successfully in about 163 seconds. The isolated CSV has 480 rows, 480 unique
  runner IDs and structural keys, 12 rows per replicate, and `status=ok` for
  every row. It covers all four model/design formula pairs and three eligible
  `rand` functions (40 rows for every pair/function combination). All 160 CI
  rows have finite endpoints and nonmissing coverage truth; there are no error
  messages. Provenance sidecar records R-devel `r90668`, EDI 1.0.3, checkout
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This is one `airquality`/beta=0.5/Bernoulli selector only—not full-grid
  acceptance or a runtime projection. CSV:
  `/tmp/edi-todo13-reps1-40.ZOLn0y/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `92c3368e565e6f955b5540d2e287c1dc35f9bba08e2777524aeb96d7a51f8b63`);
  sidecar:
  `/tmp/edi-todo13-reps1-40.ZOLn0y/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv.provenance-20261020T172350.461286-pid4.rds`
  (SHA-256 `6ccec75fbba9084678612cfe60ab17edc425bc0343c36510a002472cf9c0a9d1`).
  No `--apply`, build/install, or canonical result write occurred.
  **Distinct adjacent selector pilot, 2026-10-20:** the predeclared
  `airquality × beta_T=0 × Bernoulli` selector completed 5 reps in about 71
  seconds with 60 unique rows/keys, all statuses `ok`, all four formula pairs
  crossed with three `rand` functions, and all 20 CI rows finite with coverage
  truth present. It used checkout R with `compile=FALSE`; EDI 1.0.3, R-devel
  `r90668`, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` are
  captured in the isolated sidecar. See
  `../bug_fix_plans/prop_gcomp_sample_usable_gating.md` for output hashes and
  full provenance. This is one 5-replicate selector pilot only; the supported
  proportion `rand` grid and exact-key reconciliation remain open.
  **Next predeclared design selector, 2026-10-20:** the adjacent
  `airquality × beta_T=0 × SPBR` pilot completed 5 reps in about 71 seconds:
  60 unique rows/keys, all `ok`, four formula pairs crossed with three `rand`
  functions, and all 20 CI rows finite with coverage truth present. Provenance
  is captured in the isolated sidecar (checkout R with `compile=FALSE`, EDI
  1.0.3, R-devel `r90668`, HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`). See
  `../bug_fix_plans/prop_gcomp_sample_usable_gating.md` for output hashes and
  complete details. This is one five-replicate selector only; full-grid
  reconciliation remains open.
  **Next predeclared selector pilot (2026-10-20; partial):** after confirming
  no R/Rscript runner was active, ran `airquality × beta_T=0 × FixediBCRD`
  with `Nrep=5`, `REP_FILTER=NA`, the tested prune-skip guard, checkout R
  loaded with `pkgload::load_all("R/EDI", compile=FALSE)`, fresh isolated
  `/tmp` output, and a 240-second cap. It exited 0 in about 56 seconds. The
  output contains 60 unique IDs/structural keys (12 per rep), all four
  model/design formula pairs crossed with the three expected functions (five
  rows per pair/function), all statuses `ok`, and 20 CI rows with finite
  endpoints and nonmissing coverage truth; no error messages occurred. Sidecar
  provenance: R-devel `r90668`, EDI 1.0.3, checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T17:55:08.660109Z`–`2026-10-20T17:56:04.188676Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta0-FixediBCRD.aH7riu/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
  (SHA-256 `2250958d94ffdf67008710b093bf433ad46a8888489b20bd85d9caf36d4088a3`);
  sidecar SHA-256
  `d171566778776adbfe4a19459d01ff08494a13d4cffec2c122334738d60ca1b4`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Next predeclared selector pilot (2026-10-20; partial):** after the active
  R/Rscript process exited, ran `airquality × beta_T=0 × FixedBlocking` with
  `Nrep=5`, `REP_FILTER=NA`, the tested prune-skip guard, checkout R loaded
  with `pkgload::load_all("R/EDI", compile=FALSE)`, fresh isolated `/tmp`
  output, and a 240-second cap. It exited 0 in about 64 seconds. The CSV has
  60 unique IDs/structural keys (12 per rep), all four formula pairs crossed
  with the three expected functions (five rows per pair/function), all
  statuses `ok`, and 20 CI rows with finite endpoints and nonmissing coverage
  truth; no row errors occurred. The log records an `equal_block_sizes=TRUE`
  retry for unequal strata (33, 41), followed by successful completion.
  Sidecar provenance: R-devel `r90668`, EDI 1.0.3, checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T18:01:16.263357Z`–`2026-10-20T18:02:19.796341Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta0-FixedBlocking.CbZG9i/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
  (SHA-256 `9adc1f811a5ead1c725c07ccb3ca4ac3629a9254174f49d9ff6e08025006b2ee`);
  sidecar SHA-256
  `f5ea2d12581cbabd5a0a59027136c14c545874907d3811f185f6ff28020d98bd`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Next predeclared selector pilot (2026-10-20; partial):** after confirming
  no R/Rscript runner was active, ran `airquality × beta_T=0 ×
  FixedMatchingGreedy` with `Nrep=5`, `REP_FILTER=NA`, the tested prune-skip
  guard, checkout R loaded with `pkgload::load_all("R/EDI", compile=FALSE)`,
  fresh isolated `/tmp` output, and a 240-second cap. It exited 0 in about 57
  seconds. The CSV has 60 unique IDs/structural keys (12 per rep), all four
  formula pairs crossed with the three expected functions (five rows per
  pair/function), all statuses `ok`, and 20 CI rows with finite endpoints and
  nonmissing coverage truth; no row errors occurred. Sidecar provenance:
  R-devel `r90668`, EDI 1.0.3, checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T18:05:22.149233Z`–`2026-10-20T18:06:19.348261Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta0-FixedMatchingGreedy.h4uDq1/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedMatchingGreedy_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0_family-rand.csv`
  (SHA-256 `fd4bfbc920d15fd2b6d2b1e50f6c46e0df5dd89c529c6583403efdfc07270c60`);
  sidecar SHA-256
  `307243cf39af9048fa8aeca8cb947d67ab6961714300fd9cd4001b92c9f13ad8`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Next predeclared selector pilot (2026-10-20; partial):** with no active
  R/Rscript process at preflight, ran `airquality × beta_T=0.5 × SPBR` with
  `Nrep=5`, `REP_FILTER=NA`, the tested prune-skip guard, checkout R loaded
  with `pkgload::load_all("R/EDI", compile=FALSE)`, fresh isolated `/tmp`
  output, and a 240-second cap. It exited 0 in about 31 seconds. The CSV has
  60 unique IDs/structural keys (12 per rep), all four formula pairs crossed
  with the three expected functions (five rows per pair/function), all
  statuses `ok`, and 20 CI rows with finite endpoints and nonmissing coverage
  truth; no row errors occurred. Sidecar provenance: R-devel `r90668`, EDI
  1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded
  DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T18:10:54.245414Z`–`2026-10-20T18:11:25.330416Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta05-SPBR.dGSa2Q/comprehensive_tests_results_nc_1_proportion_filtered_design-SPBR_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `999582b6314d0e0b035f59f6739db130ed7450db73099ccb1129edeefbca52c4`);
  sidecar SHA-256
  `4bd80dfb05795656fe902bbe3fc00382c1e103c6c4d25074c3f6492a10ac7e64`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Next predeclared selector pilot (2026-10-20; partial):** after waiting for
  the active survival R/Rscript runner to exit, ran
  `airquality × beta_T=0.5 × FixediBCRD` with `Nrep=5`, `REP_FILTER=NA`, the
  tested prune-skip guard, checkout R loaded with
  `pkgload::load_all("R/EDI", compile=FALSE)`, fresh isolated `/tmp` output,
  and a 240-second cap. It exited 0 in about 142 seconds. The CSV has 60
  unique IDs/structural keys (12 per rep), all four formula pairs crossed
  with the three expected functions (five rows per pair/function), all
  statuses `ok`, and 20 CI rows with finite endpoints and nonmissing coverage
  truth; no row errors occurred. Sidecar provenance: R-devel `r90668`, EDI
  1.0.3, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded
  DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T19:29:17.259746Z`–`2026-10-20T19:31:38.926511Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta05-FixediBCRD.4dyDU5/comprehensive_tests_results_nc_1_proportion_filtered_design-FixediBCRD_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `eeca0de70f6308e463346accee75198293a8891d4edd5fdb4630f4dae4ce58f2`);
  sidecar SHA-256
  `581e47f37fd67cc5ea4eb1d6cb5cdce1e46095d2a0cd66561fc0bcc1de160b14`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Next predeclared selector pilot (2026-10-20; partial):** after the active
  R/Rscript workloads exited, ran `airquality × beta_T=0.5 × FixedBlocking`
  with `Nrep=5`, `REP_FILTER=NA`, the tested prune-skip guard, checkout R
  loaded with `pkgload::load_all("R/EDI", compile=FALSE)`, fresh isolated
  `/tmp` output, and a 240-second cap. It exited 0 in about 133 seconds. The
  CSV has 60 unique IDs/structural keys (12 per rep), all four formula pairs
  crossed with the three expected functions (five rows per pair/function),
  all statuses `ok`, and 20 CI rows with finite endpoints and nonmissing
  coverage truth; no row errors occurred. The log records
  `equal_block_sizes=TRUE` retries for unequal strata (33, 41), followed by
  successful completion. Sidecar provenance: R-devel `r90668`, EDI 1.0.3,
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  interval `2026-10-20T19:35:43.374376Z`–`2026-10-20T19:37:56.245854Z`.
  CSV:
  `/tmp/edi-todo13-airquality-beta05-FixedBlocking.6Jj8Hj/comprehensive_tests_results_nc_1_proportion_filtered_design-FixedBlocking_class-InferencePropGCompMeanDiff_dataset-airquality_beta-0.5_family-rand.csv`
  (SHA-256 `8c4222f17ce801a4a745c3af5a190836795c070ea5267432de91bd7977dcbf6c`);
  sidecar SHA-256
  `9689507193a0714cb840b7f5ad512a168811eb21ba37db8d3f320a0cee200d24`.
  This five-replicate selector pilot does not close full-grid regeneration,
  post-fix installed-package validation, or exact-key/status/value
  reconciliation. No `--apply`, build/install, or canonical result write.
  **Broader pilot-artifact reconciliation, 2026-10-21 (initial inventory):** the source-derived
  envelope is 90 selectors and at most 43,200 attempts (9 datasets × 2 beta
  values × 5 designs × 4 formula pairs × 3 `rand` operations × 40 reps).
  The bounded `/tmp/edi-todo13-*` inventory contains 23 CSVs, 22 sidecars,
  and 23 logs. Each CSV has the expected four formula and three operation
  labels, unique within-file natural keys/IDs, `status=ok`, no row errors,
  and finite ordered CI endpoints with coverage truth; all 22 sidecars match
  their CSV hashes. However, only 17/90 selectors are represented: 16 have
  reps 1--5 only, and one (airquality, beta 0.5, Bernoulli) has a complete
  40-rep/480-key artifact. Six overlapping partial files for that selector
  all begin at rep 1; their overlapping payloads match the complete file, so
  they are duplicate evidence, not chunks to concatenate. The raw files have
  2,808 rows, 1,440 unique keys, and 1,368 duplicate occurrences. Seventy-
  three selectors are absent; the 16 partial selectors are each 35 reps
  short. Sidecars show three DLL cohorts (`db4b…`, `d44e…`, `ae4f…`), so the
  multi-selector pilots are not one homogeneous installed-native run. One
  CSV has neither sidecar nor terminal-completion marker; a separate failed
  log has no CSV. Keep the full-grid gate open: confirm one post-fix package/
  DLL identity, regenerate all selectors into isolated `/tmp`, then pass
  exact-manifest, provenance, status, and value checks before any canonical
  merge. No R/build or canonical write was performed for this reconciliation.
  **Subsequent independent selector pilot, 2026-10-21:** ran
  `pte_example × beta_T=0.5 × Bernoulli` with `Nrep=5` and `REP_FILTER=NA`
  (no replicate filter), using checkout R with `compile=FALSE` and isolated
  output at `/tmp/edi-todo13-pte-beta05-Bernoulli.clF5JU/`. All 60 expected
  keys (reps 1--5 × four formula pairs × three `rand` operations) were unique
  and present; all rows were `status=ok` without errors, all 20 CI rows had
  finite ordered bounds and consistent coverage flags, and all 40 p-values
  were finite in `[0,1]`. The schema-v2 sidecar matched the 44,955-byte CSV
  and its SHA-256 `d132e7fba029f1035030d00f13fe56728c6a5fe729a9636ac6a780fbb137db26`.
  Provenance: EDI 1.0.3, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  loaded temporary DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This is a valid five-replicate candidate slice, not full-grid acceptance;
  no build/install or canonical output write occurred.
  **Second independent selector pilot, 2026-10-21:**
  `pte_example × beta_T=0.5 × SPBR` also passed a five-replicate unfiltered
  run at `/tmp/edi-todo13-pte-beta05-SPBR.7x6NUd/`. All 60 expected keys were
  present and unique; statuses/errors, finite coverage truths, 20 ordered CI
  rows/flags, and 40 finite in-range p-values passed validation. Its
  schema-v2 sidecar matched the CSV SHA-256
  `a22c8c88015657c4a49d52974c852b01cb2851260ff6434a95630d58949beb5e`;
  provenance identifies EDI 1.0.3, HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  With the immediately preceding pte_example/beta=.5/Bernoulli pilot, these
  raise represented coverage to 19/90 selectors: one 40-rep selector and 18
  five-rep selectors; 71 selectors remain absent. Both are pilot slices only.
  **Two more bounded pilots, 2026-10-21:** `pte_example × beta_T=0.5 ×
  FixediBCRD` and `FixedBlocking` each completed reps 1:5 with all 60 expected
  unique keys, valid status/error fields, finite ordered CI endpoints and
  matching coverage flags, finite in-range p-values, and schema-v2 sidecars
  matching their CSV hashes. Outputs are under
  `/tmp/edi-todo13-pte-beta05-FixediBCRD.4tsRMo/` and
  `/tmp/edi-todo13-pte-beta05-FixedBlocking.EFVXAH/`; both record EDI 1.0.3,
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, and DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  The two selectors raise represented coverage to 21/90 (one 40-rep and 20
  five-rep selectors; 69 absent). They remain bounded pilots, not full-grid
  acceptance. An attempted `pte_example × beta_T=0.5 × FixedBinaryMatch`
  selector produced no CSV: the runner reported that no covariates were
  available for binary matching, and the provenance sidecar records zero
  result bytes. Source/plan eligibility review confirms FixedBinaryMatch is
  excluded from the five supported proportion designs; its absence does not
  change the 90-selector target. It contributes no keys and is not counted
  among covered selectors.
  **Missing-selector pilot estimate, 2026-10-21 (read-only):** 20 retained
  complete five-rep selector CSVs each contain 60 rows and are about 42.9–46.7
  KB, with roughly 10 KB sidecars and 16–19 KB logs. Producing five-rep pilots
  for the 69 selectors without a CSV is estimated at about 5 MB of persistent
  artifacts. Nineteen retained logs suggest a median of 87 seconds per
  selector, or roughly 100 minutes serially (observed-range extrapolation:
  44 minutes–2 hours 20 minutes); these estimates do not cover unrepresented
  datasets or retries. The full 40-rep target is 43,200 rows, including
  33,120 rows for the 69 missing selectors; a single retained 40-rep selector
  suggests about 25 MB of CSV for those 69, but is not a reliable runtime
  forecast. Five-rep pilots validate selector paths only, not full-grid
  acceptance. No run was launched for this estimate.
  **Read-only retained-artifact reconciliation, 2026-10-21:** re-inventoried
  29 `/tmp/edi-todo13-*` CSVs: 3,120 physical rows reduce to 1,740 unique
  natural keys/runner IDs across 22 of 90 source-derived selectors and four
  datasets (`airquality`, `diamonds`, `iris`, `pte_example`). One selector has
  reps 1--40; the other 21 have reps 1--5; 68 selectors have no artifact. The
  represented keys cover all four formula contexts (encoded in
  `inference_class`) and all three expected `rand` function labels. All 3,120
  rows have `status=ok`; all 1,740 unique IDs are in the 43,200-key
  conditional roster, leaving 41,460 absent. Repeated-key groups have no
  conflicting result/status/error/coverage payloads. Twenty-eight CSVs have
  receipts whose byte count and SHA-256 match; 12 receipts are schema v1 and
  16 are schema v2. The schema-v2 receipts span four package-payload hashes
  and three DLL hashes, while all receipts span five runner-source hashes;
  these are not one homogeneous installed-run cohort.
  `/tmp/edi-todo13-propgcomp-airquality-beta0.5-Bernoulli.8c0Pf9/` contains a
  further 336-row CSV with no sidecar; its keys add nothing beyond the
  retained 40-replicate airquality/Bernoulli/beta=.5 artifact and it is not
  counted as provenance-backed coverage. The 60-row iris beta=0 Bernoulli
  five-replicate pilot is
  `/tmp/edi-todo13-iris-beta0-Bernoulli-5rep-final/results/comprehensive_tests_results_nc_1_proportion_filtered_design-Bernoulli_class-InferencePropGCompMeanDiff_dataset-iris_beta-0_family-rand.csv`
  (SHA-256 `6cd266d9c31c0e1245218ddc56ee69e39dbaa5527f4ecf5dfcbefb97aeeecc60`);
  its verified schema-v2 receipt records package-payload SHA-256
  `58f809147f419372f9e82792e2ad6de097b3cbfede3371f9fac9d4ddd0283afd`, DLL
  SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  and runner SHA-256
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`,
  matching the current runner. The staged 12-row iris one-replicate file has
  the same package/DLL identity and identical overlapping payloads but an
  older runner hash, adding no coverage. Full-grid attempts, homogeneous
  provenance, and exact status/value reconciliation remain open; no canonical
  merge is supported by these pilot artifacts.

  **Coverage-membership precision note, 2026-10-21:** a read-only check of the
  560 unique CI rows agrees with all 560 recorded
  `beta_T_in_confidence_interval` flags when evaluated against the full-
  precision endpoint pair in `result`. Comparing against rounded
  `result_1`/`result_2` instead produces one apparent mismatch: airquality,
  beta=.5, Bernoulli, rep 35, both formulas `~.`, where the rounded upper
  endpoint is `0.111` but the raw upper endpoint is `0.110510415439683` and
  coverage truth is `0.1105502`; the recorded `FALSE` flag is consistent with
  the raw endpoints. `record_result()` preserves full-precision `result` but
  rounds `result_1`/`result_2` and computes the flag from the unrounded
  endpoints (`R/package_tests/comprehensive_tests.R:1529-1540,1558-1562`).
  Future reconciliation should use `result` for this membership check, not
  infer a defect from the rounded display columns. No result files were
  modified; complete post-fix installed-package regeneration and exact-key,
  provenance, status, and value reconciliation remain required.
  This check covered the earlier 560-row pilot subset; the newly inventoried
  iris pilot contributes 12 CI rows that are not covered by that precision
  check.

  **Eligibility-aware source roster, 2026-10-21 (read-only):** TODO-13 is the
  proportion class `InferencePropGCompMeanDiff`, not an incidence-response
  artifact. Its direct components are `BayesianBootstrap` and `Jackknife`
  (`R/EDI/R/inference_proportion_gcomp.R:49-52`; registry mapping at
  `R/EDI/R/inference_class_registry.R:1210`). The BayesianBootstrap
  dependency chain includes `RandomizationBootstrapCI`, `RandomizationCI`,
  and `RandomizationTest` (`R/EDI/R/contracts_mixins.R:319-335,447-461,480-489`),
  so the live runner's `supports_randomization_test` and
  `supports_randomization_ci` predicates are statically true for this class.
  The only registered design exclusion is sequential-design
  `nonparametric_bootstrap` (`R/EDI/R/inference_class_registry.R:1526-1534`),
  which does not remove either rand capability for the five selected designs.
  With the plan's proportion/`rand` filters and
  `COMPREHENSIVE_FORCE_SLOW_PATHS=1`, the source roster is therefore exactly
  14,400 case contexts (9 datasets × 2 beta values × 40 reps × 5 designs ×
  2 model formulas × 2 design formulas) crossed with the three eligible calls:
  `compute_rand_two_sided_pval`,
  `compute_rand_two_sided_pval(delta=0.5)`, and
  `compute_rand_confidence_interval`, for 43,200 candidate attempt keys.
  This is an exact source-derived candidate roster conditional on each
  dataset/design/formula setup succeeding, not a claim that those calls were
  emitted or completed. Historical pilot rows match the operation labels but
  remain heterogeneous in provenance; complete current-installation run,
  setup-failure accounting, and exact-key/status/value reconciliation remain
  open. No maintainer policy choice or result-generation action is implied.

  **Full conditional-roster reference test, 2026-10-21:** broadened the
  existing `test-comprehensive-rand-pvalue-eligibility-reference.R` inventory
  so the inference-model formula and outer design formula are independent
  dimensions. The previous fixture paired them diagonally and asserted only
  21,600 keys; the corrected source-derived lattice asserts 14,400 case
  contexts (all four formula pairs), 28,800 ordinary rand-p-value keys,
  14,400 rand-CI keys, and 43,200 distinct non-missing IDs. Its explicit
  conditional-on-setup wording makes clear this is not evidence of actual
  calls, output rows, or setup success. Focused command
  `Rscript -e 'invisible(parse("R/package_tests/testthat_bulk/test-comprehensive-rand-pvalue-eligibility-reference.R")); testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-rand-pvalue-eligibility-reference.R")'`
  passed 61 expectations (0 failures, warnings, or skips) with installed EDI
  1.0.3; it parses the checkout runner/manifests and constructs no designs,
  fits, or output rows. This closes only the source-roster test subgate; the
  full post-fix installed run and artifact reconciliation remain open.

  **Independent retained-pilot anti-join, refreshed 2026-10-21 (read-only):** rebuilt
  the natural-key roster from the 9 proportion datasets, 5 supported designs,
  both beta values, 40 reps, all four independent inference/design formula
  pairs, and the three eligible `rand` operation labels above. Across the 29
  retained `/tmp/edi-todo13-*` result CSVs (3,120 physical rows), all 1,740
  unique IDs are in the 43,200-key roster; 41,460 roster keys are absent,
  with zero out-of-roster IDs. There are 1,380 duplicate occurrences across
  372 repeated-key groups, with zero conflicting result/status/error/coverage
  payloads; all 3,120 rows have `status=ok`. Twenty-eight CSVs have receipts
  whose byte count and SHA-256 match (12 schema v1, 16 schema v2); the v2
  files span four package-payload hashes and three DLL hashes, while all
  receipts span five runner-source hashes. The remaining unreceipted file is
  the 336-row airquality/Bernoulli/beta=.5 CSV. The 60-row iris beta=0
  Bernoulli five-replicate pilot has SHA-256
  `6cd266d9c31c0e1245218ddc56ee69e39dbaa5527f4ecf5dfcbefb97aeeecc60`; its
  verified schema-v2 receipt records package-payload SHA-256
  `58f809147f419372f9e82792e2ad6de097b3cbfede3371f9fac9d4ddd0283afd`, DLL
  SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  and current-runner SHA-256
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`. The
  staged 12-row iris file has the same package/DLL identity and identical
  overlapping payloads, but an older runner hash and no unique IDs. This is
  pilot evidence only, not proof of full-grid attempts or acceptance. No rows
  were merged or modified. The acceptance gate remains a complete post-fix
  installed-package run with one authenticated package/DLL provenance cohort,
  then exact roster equality and status/value validation before any
  canonical merge.

  **Receipt-to-file pairing recheck, 2026-10-21 (read-only):** the current
  filename inventory contains 29 matching result CSVs and 29 provenance
  sidecars, but only 28 matching CSV/sidecar pairs. One sidecar is orphaned:
  it names a `pte_example`/beta=.5/`FixedBinaryMatch` output with no matching
  retained result CSV. The unreceipted CSV remains the 336-row
  airquality/Bernoulli/beta=.5 file. This does not add a provenance-backed
  cohort or change the anti-join: 1,740 unique keys observed, 41,460 absent,
  heterogeneous package/DLL/runner identities, no complete post-fix run, and
  no canonical merge authorization.

  **Candidate-manifest input guards, 2026-10-21:** strengthened the pure-R
  proportion rand p-value attempt manifest to reject malformed numeric keys
  (non-finite beta or non-positive/non-integer reps), non-character textual
  key fields, unknown family-filter labels, and non-scalar/missing logical
  eligibility flags before emitting candidate IDs. The focused existing
  reference test now exercises those failures and confirms that a recognized
  non-rand `estimate` filter still yields an empty rand manifest. Command
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-rand-pvalue-eligibility-reference.R")'`
  passed 74 expectations with installed EDI 1.0.3 (0 failures, warnings, or
  skips); this was pure-R manifest/capability logic, not native inference or
  candidate-row generation. It improves validation readiness only and does
  not close the full post-fix run, homogeneous provenance, setup/attempt
  accounting, exact result-key/status/value reconciliation, or canonical
  merge gates below.

  **Installed-package focused worker regression, 2026-10-21:** after the
  current EDI reinstall and with no competing R/Rscript process, ran
  `test-prop-gcomp-mean-diff-randomization-worker-estimate-not-all-na-reference.R`
  against installed EDI 1.0.3. All six expectations passed: reusable-worker
  selection, identity-permutation parity with `compute_estimate()`, and a
  30-permutation finite, nonconstant randomization distribution. The loaded
  library is `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its
  `R/EDI.rdb` / `R/EDI.rdx` SHA-256 values are
  `40e86c189d1af56ff23cfee1c487c914a4e8b8fb03781a36b3b54462a0d84761` /
  `9e677c323091a5344ea1f1f6d5aed97b6eae7c385113df292b6850fccb93b56f`, and
  `EDI.so` SHA-256 is
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  The package metadata records `Built: R 4.7.0; x86_64-pc-linux-gnu;
  2026-10-21 06:41:23 UTC`. No build/load_all/install or result generation
  occurred. This validates the focused installed R-layer behavior only; the
  complete post-fix run, homogeneous provenance, setup/attempt accounting,
  exact-key/status/value reconciliation, and canonical merge gates remain open.

  - [ ] After a post-fix package is available, regenerate the complete
    supported proportion `rand` family (both `~1` and `~.` formulas and all
    supported design/data/beta/rep keys); reconcile by unique runner `id`
    (the row-level key). `case_id` omits replicate and `beta_T`, so use it
    only as a descriptive grouping/consistency field, never as a row-level
    merge key. Require exact key-set equality, validate provenance, statuses,
    finite CI endpoints and coverage fields, then merge/deduplicate only the
    complete target set.
- [ ] TODO-14 (added 2026-09-22, surfaced the same way as TODO-13 — the
  new KK-design fixture arm was the first thing to exercise
  `estimate_only = TRUE` on this class with both components simultaneously
  usable — root-caused same day on user request): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`
  randomization distribution all-NA in production** —
  `../bug_fix_plans/glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md → TODO-1..7`.
  **Fixed 2026-09-23.** A plain arithmetic NA-propagation bug, unrelated to
  TODO-9/TODO-12 (no caching) or TODO-13 (no worker-state gating):
  `shared()`'s inverse-variance pooling weight (`w_star = ssq_r / (ssq_r +
  ssq_m)`) used two variance components unconditionally, even though
  they're deliberately `NA` under `estimate_only = TRUE` (every resampling
  draw uses this flag for speed) — so `w_star` and the final `beta_hat_T`
  came out `NA` on every draw, even though the two underlying point
  estimates were both finite. Confirmed by direct reproduction:
  `estimate_only = FALSE` gives `-0.2164` (correct), `estimate_only = TRUE`
  on the same data gave `NA`. Fixed with the equal-weight
  (`0.5 * beta_m + 0.5 * beta_r`) fallback already correct elsewhere in the
  same file. **Reconciled 2026-10-10:** linked TODOs 1--6 (including the
  broader pooling-shape sweep, the ordinary-fit preservation check, and the
  reused-worker distribution) are complete; the focused regression rerun
  passed 13/13. **Harness selection repaired and validated 2026-10-16:** the
  repaired class was missing from the explicit KK-survival comprehensive
  runner while IVWC classes are intentionally skipped by exhaustive class
  discovery. It is now in the explicit selector, with a focused regression
  at `R/package_tests/testthat_bulk/test-comprehensive-survival-ivwc-rand-selection-reference.R`
  (7 expectations passing against installed EDI 1.0.3). Isolated one-core
  beta 0 and 0.5 `pte_example` runs emitted six rand rows each, and direct
  public-API calls matched all 12 harness values exactly. Those `/tmp` rows
  are validation only, not canonical results. Only TODO-7's authorized
  post-install comprehensive-CSV regeneration/reconciliation remains, so
  this release item stays unchecked.
  **Canonical-results audit, 2026-10-18:** the current survival CSV has
  475,092 rows, all `status=ok`, spanning reps 1–50 and 7,680 distinct
  `case_id`s; only 1,114 case IDs occur in all 50 reps. It has 23 source
  commit IDs but no invocation, requested-`Nrep`, package-version, or DLL
  provenance. The repaired `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`
  is absent from both `inference_class` and `function_run`, including all
  `rand` rows, and the CSV predates the 2026-10-16 harness-selector fix.
  Therefore neither the rep-50 maximum nor all-`ok` statuses establish target
  completeness. The comprehensive runner defaults to 40 when `Nrep` is
  omitted, but the observed maximum of 50 means that default is only a
  provisional target, not recovered invocation provenance. Regenerate the
  newly eligible rows from the post-fix installation; do not merge this old
  file as proof.
  **Independent runner-attempt inventory (source-derived, not yet observed or
  evidence of output completeness):** with the current default dataset and
  design loops, the target selector is reached for nine survival datasets
  (`diamonds`, `pte_example`, `ionosphere`, `abalone`, `iris`, `boston`,
  `fuel`, `cars`, `airquality`), beta values `0` and `0.5`, reps `1:40`, and
  the intersection of `TESTED_DESIGNS` with `is_kk_design`:
  `KK21stepwise` and `FixedBinaryMatch`. Each has both design formulas (`~1`,
  `~.`), yielding class labels ending in `[design_formula=~1]` and
  `[design_formula=~.]`, and three `rand` operations:
  `compute_rand_two_sided_pval`,
  `compute_rand_two_sided_pval(delta=0.5)`, and
  `compute_rand_confidence_interval`. This gives a provisional expected
  **8,640 runner-attempt keys** (9 datasets × 2 beta values × 40 reps × 2
  designs × 2 design formulas × 3 operations); it is not a
  claim that any of those rows have run or succeeded. Build the expected-key
  manifest independently from these source loop/selector dimensions under
  the fresh `/tmp` run directory, before running the harness; do not infer
  the target set from the emitted CSV. The natural key is
  `(rep, beta_T, dataset, response_type, design, inference_class,
  function_run)`, identical to the harness result key `id` formed by joining
  those values with `||` and serializing numeric `beta_T` with
  `format(as.numeric(beta_T), scientific=TRUE, digits=17)`. `case_id` is not
  unique across replicates and is not the merge key.
  **Full-run feasibility preflight, 2026-10-21:** the source-derived manifest
  has exactly 8,640 rows (8,640 data lines plus header), confirming the
  corrected dimension product above. The baseline RNG-preserving invocation
  is one unfiltered 40-rep, one-core run with dataset/design/beta/rep unset;
  the scalar `REP_FILTER` cannot resume a stream or safely partition this run.
  **Potential prefix/resume route (not yet validated):** `Nrep` is only the
  rep-loop upper bound, and the harness has a results-CSV resume cache.
  Replaying the identical unfiltered command from rep 1 with the same output
  path and increasing `Nrep` from `K` to 40 may preserve the parent RNG stream
  while skipping cached calls; dataset/beta/design filters do not. Before
  relying on this, add an integration regression comparing one-shot and
  prefix/resume keys, result payloads, and final parent `.Random.seed`. The
  cache currently treats any `status=ok` row as complete, including timeout
  rows with a nonempty `error_message`, so these cannot be silently accepted
  as completed work.
  **Timeout-cache classification regression, 2026-10-21:** extracted the
  resumed-row classifier into `R/package_tests/comprehensive_result_cache_classification.R`
  and wired it into the runner. Only anchored runner-emitted 1/60/120-second
  timeout messages (optionally suffixed by the outer `safe_call` guard) are
  retryable and eligible for the opt-in timeout cache; other `status=ok` rows
  remain completed, while `status=error` rows enter neither cache. Timeout
  keys are seeded before completed keys. The focused contract test passed all
  7 expectations against installed EDI 1.0.3, and is registered in both
  correctness and coverage manifest tiers. This is classifier-level evidence,
  not a full runner resume or artifact-reconciliation result; the 8,640-key
  current-installation gate below remains open. No build/install or canonical
  write occurred.
  **Bounded prefix/resume validation, 2026-10-21:** compared one-shot
  `Nrep=2` against `Nrep=1` followed by resumed `Nrep=2` for the same
  `iris × beta_T=0.5 × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` selector. Both emitted the
  same 12 natural keys and identical `id`, raw result fields, coverage fields,
  status, and error-message values; the resumed output had 12 `ok` rows and
  no errors or skips. Final parent `.Random.seed` values were identical.
  All three schema-v2 sidecars agreed on initial RNG state, R 4.7-devel
  r90668, package-payload SHA-256
  `58f809147f419372f9e82792e2ad6de097b3cbfede3371f9fac9d4ddd0283afd`, and
  installed DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`; the
  payload and DLL hashes were unchanged across each invocation. Isolated
  outputs are `/tmp/edi-todo14-one-shot-corrected-20261021/` and
  `/tmp/edi-todo14-prefix-resume-corrected-20261021/`. This validates the
  resume argument for this 12-key slice only; timeout-row cache behavior and
  the full 8,640-key acceptance remain open. No build/install or canonical
  write occurred.
  Retained timings imply an optimistic roughly 3.5–4.1 hours, but some
  single-replicate cars/diamonds slices exceeded 180 seconds, so total runtime
  is not bounded. `/tmp` had only 363 MiB free on a 21 GiB tmpfs. Do not launch
  the full candidate until there is explicit multi-hour authorization, a
  serialized R slot, and substantially more scratch headroom. The full-grid
  acceptance gate remains open.
  - [ ] Regenerate the complete eligible
    `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` `rand` row set from the
    current post-fix installation, with source/package/DLL provenance; keep
    the post-install data gate open until all of the following pass:
    - Exact anti-join of manifest IDs against candidate IDs and candidate
      IDs against manifest IDs has zero missing and zero unexpected keys;
      require exactly 8,640 rows, unique IDs/natural keys and unique
      `run_row_id`s, and reps exactly `1:40` for every non-replicate key.
      Treat design/setup failures or absent rows as missing keys, not as
      eligible-set reductions.
    - Every row has the exact target class, `response_type=survival`,
      `method_family=rand`, `coverage_scope=comprehensive_workflow`,
      `argument_coverage_kind=not_argument_combination`, nonempty source
      commit/timestamp and `status=ok`; reject errors, skips, or nonempty
      `error_message`s unless a specific skip is independently approved
      before the run (none is assumed by this inventory).
    - For both p-value `function_run`s, `result_1` is finite and in `[0,1]`;
      for CI rows, both endpoints are finite and ordered, `coverage_truth` is
      finite, and `beta_T_in_confidence_interval` equals the inclusive
      endpoint-membership check. Reconcile every field for overlapping
      natural keys against any existing canonical target rows, then merge
      and deduplicate only after provenance, anti-join, status and value gates
      pass. No canonical CSV write is authorized by this note.
  **Validator-only QA, 2026-10-20:** the synthetic
  `test-todo14-candidate-validation-reference.R` passed 24 expectations.
  Review found and closed two fail-open cases: fractional replicate values
  could be truncated to integer IDs, and duplicate expected-provenance field
  names were silently resolved by R's named-list lookup. The validator now
  rejects malformed replicate numbers on both manifest and candidate sides
  and duplicate field names in provenance snapshots; its fixture confirms
  candidate/manifest files remain unchanged. This does not inspect or validate
  a real post-fix candidate, and the full run's package/DLL provenance,
  8,640-key reconciliation, and any later canonical merge remain open.
  **Validator-only focused rerun, 2026-10-21:** the exact synthetic
  `test-todo14-candidate-validation-reference.R` passed 37 expectations
  against installed EDI 1.0.3, with no failures, warnings, or skips. The
  positive fixture supplies all 8,640 expected rows; deleting the complete
  `FixedBinaryMatch × pte_example × beta_T=0.5 × design_formula=~1` group
  (120 keys) is rejected with missing IDs, candidate-count, and replicate
  issues even while the matching `~.` group remains valid. Malformed IDs,
  fractional reps, invalid result/status fields, and provenance mismatch are
  also rejected, and file hashes confirm validation is read-only. This
  exercises the synthetic validator contract only: the fixture does not
  derive its expected manifest from a successful real setup or run any fit.
  The acceptance inventory remains conditional on setup success; a setup
  failure is a missing/failed target gate, not authority to shrink the 8,640
  expected-key manifest. No candidate output or canonical file was written.
  **Additional isolated candidate slices, 2026-10-21:** cohort-C iris,
  `beta_T=0.5`, reps 7--13 now has 42/42 expected `rand` keys, all unique and
  `status=ok`; each six-row CSV passed schema-v2 sidecar size/hash validation
  and the exact-key validator. However, the single-rep filter resets the
  process RNG to `set.seed(1)` and skips earlier reps before response/design
  setup, so the same six row payloads repeat under every rep label. A
  byte-for-byte comparison confirms reps 7--13 are seven copies of one
  realization, not seven independent replications. These rows prove only
  key/status/sidecar behavior and must not count as independent candidate
  reps. Reps 7--12 share HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, diff
  `e6f7cf1d...a29d25`, payload `24f16c8b...386927`, and DLL
  `ae4fddaf...68d94` (cohort C). Rep 13 has the same HEAD, package payload,
  and DLL; its checkout-diff snapshot is `4f9b30fb...d0d2cb`, reflecting
  out-of-payload repository edits. Rep 12 is under
  `/tmp/edi-todo14-iris-beta05-rep12-schema2.oKaH6t/`. Across the individually
  validated slices there are now 126 key instances, but they span multiple
  provenance cohorts and cover only a small part of the 8,640-key manifest;
  independence of other isolated-rep slices has not been established. A
  valid regeneration must preserve the full-run RNG progression or use an
  explicitly specified and validated per-rep seed scheme, then pass the
  existing key/provenance/status/value gates. This evidence is not a
  canonical merge and does not close the post-install reconciliation gate.
  **Sequential-RNG candidate slice, 2026-10-21:** reran the same
  `iris × beta_T=0.5 × IVWC` selector with `Nrep=5` and `REP_FILTER=NA` in one
  source-overlay process, output under
  `/tmp/edi-todo14-iris-beta05-reps1to5-sequential-schema2.A0xNso/`. The
  exact 30-key roster passed (six unique rows per rep, all `status=ok`) and
  the schema-v2 sidecar matched the CSV. Its package payload and DLL match
  cohort C; reps 1--5 have distinct CI result payloads across the sequence,
  unlike isolated reps 7--13. This establishes a valid sequential five-rep
  candidate slice, not a full-run parity result or authorization to merge
  overlapping keys from other provenance cohorts.
  **Overlapping-slice audit, 2026-10-21:** compared the sequential five-rep
  iris/.5/IVWC candidate against isolated rep1–5 CSVs by natural key. All 30
  keys overlap, but only 22/30 full result payloads match: the eight CI rows
  for reps 2–5 differ, while rep 1 and all 20 p-value rows match. Each
  isolated single-rep file repeats one result per selector/formula/method
  across its rep labels; the sequential candidate instead has five distinct
  CI payloads per formula. Together with startup `set.seed(1)` and the early
  `REP_FILTER` skip, this confirms the isolated slices cannot establish
  replication equivalence. The sequential slice supports only its own 30 keys
  and advancing RNG sequence, not historical full-run parity or the 8,640-key
  gate. Do not merge overlapping rows without a predeclared authority and
  reconciliation rule.
  **Recheck, 2026-10-20:** the source-derived manifest still exists at
  `/tmp/edi-todo14-expected-attempts-20261020.csv` with SHA-256
  `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`; the
  current runner SHA-256 is still
  `0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`, matching
  its recorded snapshot. The focused
  synthetic validator test was rerun and passed 27 expectations. This pass
  also added an explicit malformed-manifest regression: duplicating an
  expected natural key is rejected as `duplicate_manifest_id` and violates
  the exact 1:40 replicate contract. An
  older 207,998,976-byte `candidate_survival.csv` remains in
  `/tmp/edi-todo14-fullmerge.s72fR5/` (dated 2026-10-16) without adjacent run
  provenance, so it is not accepted as the post-fix target candidate and was
  not reconciled. The 8,640-key manifest remains an expected-attempt inventory,
  not observed-output evidence.
  **Bounded source-overlay candidate, 2026-10-20:** a fresh
  `compile=FALSE` run for `pte_example × KK21stepwise × beta_T=0.5 × reps 1:7`
  emitted 42/42 unique expected keys (both design formulas × three rand calls
  × seven reps), all `status=ok`. The 30 result/status rows for reps 1:5
  exactly match the earlier reps 1:5 candidate; reps 6:7 completed. Scratch
  output is `/tmp/edi-todo14-pte-kk21stepwise-beta05-reps1to7.9BIqzA/`; CSV
  SHA-256 `1f8c56350056876f95e137a3e0ff141634c4d96b518bd97545f545362c52ccf4`,
  provenance sidecar SHA-256
  `2053b8228c47d5759f5999c5063acecddffdbf20abca7bb5096a2a427242b568`.
  The sidecar records R 4.6 development r90668, EDI 1.0.3 from the checkout
  namespace, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner
  SHA-256 `660dae16378ce533bf1d7bb816b2e7933b989bff838e93989ec0cbf024159`,
  and source-loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  **Provenance limitation:** the prior five-rep run has a different checkout
  diff SHA-256 (`10a1fa7a26e891c180043d9e22849c0e2de6809f63c74c21a91fe87ab1138b2a`)
  from this seven-rep run (`cadcf4db5339dbedd445cc25a147d8ca702a200bb671f3138dd4f939e12c8721`),
  although the runner and DLL hashes match and the deterministic result/status
  fields match exactly. This is a bounded candidate, not release-wide or
  byte-identical full-source replay evidence; the 8,640-key gate remains open.
  **FixedBinaryMatch `~1` key boundary, 2026-10-20:** the class API accepts
  explicit matched-pair IDs through `m`, but the comprehensive runner's
  `FixedBinaryMatch` constructor does not supply `m`; the source-derived
  `pte_example` fixture contains covariates/outcomes and no pair-ID field.
  Thus the observed `~1` setup skip cannot be replaced with a source-supported
  paired fixture without an authoritative pairing source. Do not invent pair
  IDs or remove these attempts from the expected manifest: the focused
  validator regression now removes exactly the 120 `pte_example`, beta 0.5,
  `FixedBinaryMatch/~1` keys while retaining valid `~.` rows and confirms the
  missing IDs, row-count, and candidate-replicate checks fail. Its rerun passed
  37 expectations; the full 8,640-key candidate/provenance reconciliation
  remains outstanding.
  **Additional bounded candidate, 2026-10-20:** the source-roster subset
  `iris × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0.5 × rep=1` comprises six expected keys (two formula labels ×
  three rand calls). A `compile=FALSE` source-overlay run emitted all 6 with
  unique IDs and `status=ok`; `validate_comprehensive_result_artifact()`
  confirmed six rows, exact expected-key equality, and its matching sidecar.
  Scratch directory `/tmp/edi-todo14-iris-kk21-beta05-rep1.oEHfZ8/`; CSV
  SHA-256 `3f14a4d97b92c1e2fffc43b2d8fbb79f3aea099456f853bf8766c29adac49f99`,
  sidecar SHA-256
  `0b1c1b94fa9dd9f4f9ea2f0613bf3950c9a1cc87882c27989b6cc5246fd6c983`,
  log SHA-256
  `f773b08b7cf7300a90f0d5c30f61f9713081f0ca63daddc927cf4f8ac6e183da`.
  Provenance records R 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `660dae16378ce533bf1d7bb816b2e7933b989bff838e93989ec0cbf024159`,
  and checkout-diff SHA-256
  `3bbe6bc89834cca14ac176265fbb0c5f378b4bf778e1492613ae6e91037e6dc0`.
  The `cars` and `diamonds` candidates are partial—not accepted: each reached
  its timeout with only the three `~1` rows persisted; the `~.` CI did not
  complete, so neither partial artifact has completion-provenance acceptance.
  All remain under `/tmp`. This is bounded evidence only; the full 8,640-key
  reconciliation and post-install/native gate stay open.
  **Additional bounded candidate, 2026-10-20:** the source-roster subset
  `airquality × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0.5 × rep=1` comprises six expected keys (two formula labels ×
  three rand calls). A `compile=FALSE` source-overlay run emitted all 6 with
  unique IDs and `status=ok`; `validate_comprehensive_result_artifact()`
  confirmed six rows, exact expected-key equality, and its matching sidecar.
  Scratch directory `/tmp/edi-todo14-airquality-kk21-beta05-rep1.e6NO3W/`; CSV
  SHA-256 `bcca23507f183a46fecc8dd3f9a0babf01ac2cfb34174c2590739d121a73c3b4`,
  sidecar SHA-256
  `326ae151d21a0123cf229e061602f7c7bbef98ec0794ff4adf06434a493d6245`,
  log SHA-256
  `27eeb1a54312ca28630d60aa22bb8961308364c92d12dfe0f35973f40c11bd3a`.
  Provenance records R 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`,
  and checkout-diff SHA-256
  `5347c7f6f8fd7a307becbaf477810be5291d642180e9ad4ae15178f425e2f24d`.
  This is bounded evidence only; the 8,640-key full-grid reconciliation and
  post-install/native gate remain open.
  **Schema-v2 provenance replay (2026-10-20):** reran the same
  `airquality × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0.5 × rep=1` six-key slice with the package-payload fingerprint
  validator. It emitted all six unique expected keys (both formulas × two
  rand p-values and rand CI), all `status=ok`; exact-key validation passed
  and all deterministic result fields equal the prior airquality beta=.5
  candidate. Before/after runtime package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`;
  before/after loaded DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-airquality-beta05-schema2-R3kWt9/`; CSV SHA-256
  `4cea9b5e92649e00d88fe541622f4bf0afb1580918e3b8e4d0e8a2d650359849`,
  schema-v2 sidecar SHA-256
  `c6febf58435588200d3762e629b267e59b2698c33e7180c2b7b7ce84f4e01936`.
  Isolated source-overlay evidence only; the 8,640-key reconciliation and
  post-install/native gate remain open.
  **Additional schema-v2 bounded candidate (iris beta=0, 2026-10-20):**
  preflighted the prepared TODO-14 manifest and selected its exact
  `iris × survival × KK21stepwise × InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC
  × beta_T=0 × rep=1` subset (six unique keys, both formulas × three rand
  calls). A `compile=FALSE` run completed in under the 180-second cap and
  emitted all six, each `status=ok`, with no missing results; exact ID-set
  comparison and `validate_comprehensive_result_artifact()` passed. Sidecar
  schema is 2; before/after package-payload SHA-256 is
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`, and
  before/after loaded-DLL SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-iris-beta0-schema2.jjnO9U/`; CSV SHA-256
  `7379bb8c1be4c0e72ce788fa8c2b6df9a20abfd8fdc66b6627f0aa4479282dc3`,
  sidecar SHA-256
  `5d7981bf4ef3c9e0096b41819c1bc98043b988b8602fb75138f46d759f0e5368`.
  This isolated source-overlay candidate does not close the 8,640-key
  reconciliation or post-install/native gate.
  **Additional schema-v2 bounded candidate (pte_example beta=0, 2026-10-20):**
  the source-derived manifest subset `pte_example × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0 × rep=1` has six
  unique keys (both formulas × three rand calls). With no active R workload,
  a serialized `compile=FALSE` run completed within the 180-second cap; all
  six exact IDs were emitted once, `status=ok`, with no missing results.
  `validate_comprehensive_result_artifact()` accepted the exact key set and
  matching schema-v2 sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382` and
  before/after loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-pte-beta0-schema2.DX4ydF/`; CSV SHA-256
  `8e079102d56fce9091d9df94f72d74f79eb3ad673c38a06b02b29f344e632648`,
  sidecar SHA-256
  `c2ec4cd8be69b4d1e5cd97948bfaf725abdbd1720f5450c04530e65fcb91adaa`,
  log SHA-256 `ad125f5eadbf03727366e41368c72e675233fff022ce965fbbe537d26bdf3da8`.
  This is an isolated source-overlay slice; full-grid reconciliation and
  post-install/native acceptance remain open.
  **Partial candidate, not accepted (airquality beta=0, 2026-10-20):** the
  source-roster subset `airquality × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0 × rep=1` has six
  expected keys. The serialized schema-v2 `compile=FALSE` run hit its
  180-second timeout: only the three `~1` rows persisted (`status=ok`); the
  log records both `~.` p-values, but the `~.` confidence-interval call was
  still running and no completion sidecar was written. The three absent keys
  remain expected; this is not validator-accepted evidence. Scratch
  `/tmp/edi-todo14-airquality-beta0-schema2.4EbTwx/`; partial CSV SHA-256
  `3b5e0610608510a0015c53bf9dd7373029aafa84a0afa52596a6a603f3e309af`, log
  SHA-256 `63090e9feb010be1adf3c01c417cb1835da2b1b557078c5d74f26c15651ed8bc`.
  Do not shrink the manifest or use these rows to close the 8,640-key gate.
  **Additional schema-v2 bounded candidate (pte_example beta=.5 rep=8,
  2026-10-20):** the source-derived subset has six exact IDs for
  `pte_example × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=8`
  (two formulas × three rand calls). With no competing R job, a serialized
  `compile=FALSE` run completed in 129 seconds under the 180-second cap.
  All six IDs were unique and matched the manifest exactly, all statuses
  were `ok`, no results were missing, and the schema-v2 artifact validator
  accepted the CSV and sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`;
  before/after loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Scratch `/tmp/edi-todo14-pte-beta05-rep8-schema2.Kr4ClI/`; CSV SHA-256
  `aa3c98bf79599f8d23daed201ae290b07bf73bb576eaf58b3c4c9d842a54f3cc`,
  sidecar SHA-256
  `21acecd56bb658c7f266fc0e94d1c347c542e0cf970b639fd111805400198845`,
  log SHA-256 `554405268dbb536ff0730d8cb84ecd5fe1d6811c499336b01f9f40448d75a376`.
  This is a bounded source-overlay candidate only; the full 8,640-key
  reconciliation and post-install/native gate stay open.
  **Additional schema-v2 bounded candidate (iris beta=.5 rep=2,
  2026-10-20):** the prepared source manifest contains six exact IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=2`.
  Following serialization preflight, a `compile=FALSE` run completed in
  about 120 seconds under the 180-second cap. All six IDs were unique and
  matched the manifest exactly, all rows had `status=ok`, no results were
  missing, and the schema-v2 artifact validator accepted the CSV and
  sidecar. Before/after package-payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from the
  checkout namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  runner SHA-256 `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep2-schema2.bYgDXf/`; CSV SHA-256
  `932671e3b49f99606070794fefcbdb3e874396d6476ca2eb82f5efba9945e921`,
  sidecar SHA-256
  `bb63292b3f87c6c53ebf59d184ac060a2fd0470f1daa8d5dfffe207006397fd8`,
  log SHA-256 `0e9ab355029a0460838e43c19fc6ea60d1c01e0b5eb66cc76b63e57837dfc576`.
  Isolated source-overlay evidence only; the full 8,640-key reconciliation
  and post-install/native gate remain open.
  **Additional schema-v2 bounded candidate (iris beta=.5 rep=3,
  2026-10-20):** the source-derived subset has exactly six IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=3`.
  The serialized `compile=FALSE` run completed in about 113 seconds under
  the 180-second cap. All six IDs were unique and matched the manifest,
  all statuses were `ok`, no results were missing, and the schema-v2
  artifact validator accepted the CSV and sidecar. Before/after package-
  payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep3-schema2.2m3lEQ/`; CSV SHA-256
  `a61e2926ceba860574286b071b6bc4535a52d96d66be9375bd8b547a221407d8`,
  sidecar SHA-256
  `1be0de08f98844f045bf80025c296f6c63b8cf9558f74a2e98206315d774903d`,
  log SHA-256 `b83bc635f684eebec3abb7de251a65ab795b9facf3df1f8a8693b417bc05d7bc`.
  This isolated source-overlay candidate does not close the full 8,640-key
  reconciliation or post-install/native gate.
  **Additional schema-v2 bounded candidate (iris beta=.5 rep=4,
  2026-10-20):** the source-derived subset has six expected IDs for
  `iris × survival × KK21stepwise ×
  InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC × beta_T=0.5 × rep=4`.
  The serialized `compile=FALSE` run completed in about 121 seconds under
  the 180-second cap. All six IDs were unique and matched the manifest;
  all statuses were `ok`, no results were missing, and the schema-v2
  artifact validator accepted the CSV and sidecar. Before/after package-
  payload SHA-256 was
  `ed3f0fa1591701ba1d1d9e6dd793006e843053323e931255a9350db54dce6382`; the
  loaded-DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` both
  before and after. R was 4.6 development r90668, EDI 1.0.3 from checkout
  namespace, HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189`.
  Scratch `/tmp/edi-todo14-iris-beta05-rep4-schema2.ammv1O/`; CSV SHA-256
  `199b1b3eb231f079de1dfb011e057d1acd393fd4238c3351b0db6f013dce5a11`,
  sidecar SHA-256
  `c41f76be66a018cd5919e3101e91ec42b02c4e746f585e55b35362749d768dcc`,
  log SHA-256 `c923b9a4f15bb77071f124620e3f52a3adf3c7b25cf080c90d88731de791720d`.
  Isolated source-overlay evidence only; the full 8,640-key reconciliation
  and post-install/native gate remain open.
  **Read-only candidate-artifact reconciliation, 2026-10-21:** checked the
  source-derived manifest at
  `/tmp/edi-todo14-expected-attempts-20261020.csv` (8,640 unique IDs; SHA-256
  `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`)
  against 34 existing direct-output CSVs under `/tmp/edi-todo14-*`. The files
  contain 300 rows and 192 unique expected IDs: 8,448 IDs are missing and
  there are no extra IDs or within-file duplicate IDs. Across files, 78 IDs
  repeat (108 repeated occurrences); eight repeated confidence-interval IDs
  have conflicting payloads (iris, beta=.5, reps 2–5, both formulas). Of the
  36 beta/dataset/design selectors, 12 have any candidate rows and 24 have
  none; none of the 216 formula/operation groups has all 40 reps. All 300
  rows have `status=ok`, but one row has the nonempty timeout message
  `Skipped due to timeout after 120 seconds`, which fails the no-error-message
  acceptance gate and is retryable under the timeout-cache fix.

  Provenance is not a single current-run cohort: 27 CSVs have one sidecar, one
  has two (one matches the final CSV hash and one is stale), and six have no
  sidecar. Of 29 sidecars, 28 match a CSV hash. Sidecars record EDI 1.0.3,
  four package-payload hashes, three DLL hashes, and three runner hashes; none
  of the runner hashes matches the current runner SHA-256
  `1b12a10860e566d3402cc7d799669c7a94ac20bb6e37d348d249c15e2a293b1a`.
  The 372,209,537-byte canonical `comprehensive_tests_results_nc_1_survival.csv`
  has no row for the target IVWC class, and no IVWC-specific canonical CSV is
  present. The older 207,998,976-byte
  `/tmp/edi-todo14-fullmerge.s72fR5/candidate_survival.csv` remains without
  adjacent provenance and is inadmissible. These overlapping pilots must not
  be merged: conflicting payloads and repeated `run_row_id`s prevent them
  from satisfying the unique-row contract. At this audit, `/tmp` had only
  363 MiB free. The full current-source/current-package 40-rep run, exact
  8,640-key reconciliation, provenance/status/value gates, and any canonical
  merge remain open and unchanged; no output was modified.
  **One-shot/prefix-resume cohort classification, 2026-10-21:** the two
  corrected scratch CSVs
  `/tmp/edi-todo14-one-shot-corrected-20261021/` and
  `/tmp/edi-todo14-prefix-resume-corrected-20261021/` are already included in
  the 34-file/300-row census above. Each has 12 unique natural keys exactly
  matching the manifest slice for iris, beta=.5, KK21stepwise, reps 1–2,
  both design formulas, and the three emitted rand calls. Both have all rows
  `status=ok`, no error messages or within-file key/`run_row_id` duplicates;
  their result/CI/truth/status payloads agree row-for-row. They are duplicate
  cohorts, not 24 additional eligible attempts. The one-shot sidecar's final
  CSV hash matches its 9,125-byte CSV. The prefix/resume directory has two
  sidecars: one binds an overwritten 4,808-byte intermediate, while the later
  sidecar's hash matches the final 9,120-byte CSV. All three sidecars record
  runner SHA-256 `77bfab7772580bc94f96e845fb20a89e7f9c7d7ae9014e42f0be50c93a71fbb9`,
  not the current runner hash
  `1b12a10860e566d3402cc7d799669c7a94ac20bb6e37d348d249c15e2a293b1a`; this
  bounded slice is key-complete but not current-runner-provenance eligible.
  No counts or acceptance status change: the 8,640-key production run,
  current-provenance/status/value validation, and canonical merge gates remain
  open; no artifacts were modified.
  **Validator-backed candidate rescan, 2026-10-21 (read-only):** current
  source still supports the manifest axes: the IVWC class is in the explicit
  KK-survival selector; its intersection with `TESTED_DESIGNS` is
  `KK21stepwise`/`FixedBinaryMatch`; the runner has both formula labels and
  the three recorded `rand` operations. The retained manifest remains 8,640
  unique IDs (SHA-256 above). Rechecked the 34 direct-output candidate CSVs
  against that manifest: 300 rows, 192 unique expected IDs, 8,448 expected IDs
  absent, no target extras or within-file duplicate IDs, 108 repeated row
  occurrences across files (78 repeated IDs), and 8 conflicting payload IDs
  (confidence-interval results for iris, beta=.5, reps 2–5, both formulas).
  All rows say `status=ok`, but one has the timeout `error_message` and is not
  acceptable. Twelve of 36 dataset/beta/design selectors have any candidate
  rows; 54 of 216 formula/operation groups are represented and none has all 40
  reps.

  Ran `validate_comprehensive_result_artifact()` read-only on each available
  direct-file sidecar, deriving the expected slice from its recorded command
  filters and the source manifest. Of 29 sidecars for 34 files, 19 exact
  schema-2 artifacts passed; 10 failed (9 lack schema 2, 1 has a stale CSV
  hash). Six files have no sidecar. Of the 29 sidecars, 28 bind their current
  CSV bytes/hash, but their three runner-hash cohorts are all different from
  current `comprehensive_tests.R` SHA-256
  `1b12a10860e566d3402cc7d799669c7a94ac20bb6e37d348d249c15e2a293b1a`.
  Thus validator-pass only means internally consistent for the captured
  command/artifact, not current-source provenance or full-grid acceptance.

  A recursive `/tmp/edi-todo14-*` scan also finds six nested diagnostic CSVs
  (42 rows, 20 distinct IDs, none in the target manifest): five are KK14 API
  comparison outputs, outside the two accepted design axes, and one is an
  unrelated ordinal Cloglog pilot. They have no provenance sidecars and are
  classified as controls, not TODO-14 candidates. Including these controls
  would create 20 extra IDs and four additional conflicting payload IDs; they
  must not be merged into the target artifact census. The current-source,
  post-install 8,640-key run and reconciliation remain open; no result or
  canonical file was changed.
  **Source-derived candidate-roster guard, 2026-10-21:** added
  `todo14_source_candidate_manifest()` and a focused pure-R contract to
  `test-todo14-candidate-validation-reference.R`. The helper parses the
  checked-in runner/dataset loader and validates the no-CLI-filter scope
  (40 reps, beta 0/0.5, two target designs/formulas, the selected IVWC class,
  three `rand` operations, and nine survival datasets) before emitting 8,640
  unique candidate keys. The focused test passed 71 expectations; it did not
  run the comprehensive harness or establish package/native provenance.
  Candidate rows are explicitly marked as requiring setup/runtime eligibility:
  this source inventory cannot predict live constructor/capability/runtime
  skips and is not an exact emitted-attempt roster. The post-install run,
  event-output reconciliation, provenance/status/value checks, and any
  canonical merge remain open.
  **Malformed expected-manifest guard regression, 2026-10-21:** extended
  `test-todo14-candidate-validation-reference.R` to exercise the distinct
  `manifest_id_key_mismatch` validator branch, including its missing/extra ID
  report and input-file hash stability. The pure-R test passed 50 assertions
  with `testthat::test_file(..., load_helpers = FALSE)` (no EDI load, native
  call, build, or install). This closes only that negative-case test gap; it
  does not validate setup or provide the current-source 8,640-key artifact,
  which remains open.
  **Timeout-result validator contract, 2026-10-21:** extended
  `test-todo14-attempt-result-provenance-reference.R` with the producer-shaped
  timeout terminal (`status=ok`, `skip_reason=timeout`, exact timeout message,
  missing numeric result) and verified the artifact validator rejects it.
  The focused test passed 12 expectations against installed EDI 1.0.3, with
  no failures, warnings, or skips; no native code, build, install, or canonical
  result was involved. This closes only the validator-contract subgate. The
  full 8,640-key post-install artifact, provenance/value reconciliation, and
  any canonical merge remain open.
  **Filesystem-only TODO-14 recount, 2026-10-21:** rechecked the prepared
  manifest (`/tmp/edi-todo14-expected-attempts-20261020.csv`, 8,640 unique
  IDs; SHA-256 `7f7af2c77b02458dfff4f1aab1b2fc55d9844cde5526a3f3aa4abeb6b4c925b0`)
  against the 34 direct-output candidate CSVs. The candidate rows claim
  `github_commit_id=4f7a6e4ca82829e880c15a76699701a95e5e83b9`, matching the
  checkout HEAD at this recount, but this alone does not establish loaded
  package or DLL identity. The 300 rows contain 192 distinct expected IDs,
  no extras, and 8,448 absent IDs; all natural-key columns agree with the
  manifest. There are 108 repeated row occurrences beyond the unique IDs
  (78 IDs recur across files), and 8 IDs have conflicting `ok` confidence-
  interval payloads (iris, beta=.5, reps 2–5, both formulas). All rows have
  `status=ok`; the separately recorded timeout-message exception above still
  fails acceptance. Sidecar receipts exist for 28/34 CSVs (29 sidecar files;
  one CSV has two); six CSVs have none. This filesystem-only recount did not
  decode or validate RDS receipts; the earlier sidecar-validator findings
  above remain the applicable evidence. No candidate is a complete cohort,
  no files were merged or modified, and the full current-package 8,640-key
  run and reconciliation remain open.
  **Conflict provenance attribution, 2026-10-21 (read-only):** the eight
  conflicting confidence-interval IDs (iris, beta=.5, reps 2–5, both design
  formulas) come from isolated invocations with `Nrep=rep` and
  `REP_FILTER=rep`, which repeat the rep-1 payload across nominal replicates.
  The 30-row unfiltered `Nrep=5`, `REP_FILTER=NA` candidate at
  `/tmp/edi-todo14-iris-beta05-reps1to5-sequential-schema2.A0xNso/` has CSV
  SHA `8cb3fee97dc81632ff2fe4effde085eca23a89980db3c05e11606057aca90cda`;
  its per-replicate interval values are distinct. Later one-shot and
  prefix/resume 12-key artifacts agree exactly on rep 2, corroborating that
  sequential value. Receipts show heterogeneous package-payload fingerprints
  across the isolated and sequential/replay cohorts (full identities are in
  the linked plan), so the isolated repeats are not independent-replicate
  evidence and the partial cohorts are not mergeable/current full-grid
  acceptance. No artifacts were changed; the provenance-matched 8,640-key run
  and exact reconciliation remain open.
- [x] TODO-15 (added 2026-09-23, conclusively refuted 2026-10-09; from the same `bad_type1_error` audit wave
  as TODO-9, originally hypothesized to be the same mechanism — confirmed
  separate and still unfixed; the later TODO-28 cache hypothesis was
  closed as stale on 2026-10-07 and does not explain this finding):
  **`InferenceContinLin` parametric-bootstrap
  / likelihood-ratio methods have inflated Type-I error, design-dependent**
  — `../bug_fix_plans/contin_lin_param_bootstrap_bad_type1_error.md → TODO-1..7`. Three
  methods flagged simultaneously by the audit
  (`compute_lik_ratio_bootstrap_two_sided_pval` z=19.4,
  `compute_param_bootstrap_pval` z=18.8,
  `compute_lik_ratio_bartlett_approx_two_sided_pval` z=16.4) — NOT the
  reused-worker `rand` path TODO-9 fixed (that path is confirmed fixed for
  this class), but a separate parametric-bootstrap/likelihood-ratio-
  simulation mechanism. Confirmed by direct comparison against
  `InferenceContinOLS` (same generic `ParametricLikelihoodBootstrap`
  machinery, near-nominal rejection rates) that the bug is isolated to this
  class's own overrides, not shared machinery. Confirmed design-dependent
  from historical CSV data: rejection rate at a true null ranges from 0.059
  (SPBR, near nominal) to 0.406 (`FixedMatchingGreedy`, 8× nominal) — but
  NOT reproduced with a plain Bernoulli design plus a merely-correlated
  covariate, meaning the bug needs the actual structured `Design`
  subclass's block/match machinery to bite. Root cause not yet pinned down.
  **Resolution:** current observed, null and simulated Lin fits reuse the same
  reduced matrix and treatment index, and the parametric-bootstrap loader
  clears `lin_centered_covariates`. On the actual `DesignFixedBlocking`
  source path, Gaussian, nonlinear/heteroskedastic and 20-covariate
  near-collinear null checks produced 1/40, 1/40 and 0/40 LR-bootstrap
  rejections respectively, with all 120 p-values finite. The historical
  diamonds cell is an assumption-stress result for the documented secondary
  Gaussian working-model path, not a current cache/design defect. All seven
  linked subtasks are closed; no source or CSV change is warranted.
- [ ] TODO-16 (added 2026-09-23, from the same `bad_type1_error` triage
  wave as TODO-9/TODO-15): **Ordinal cumulative-link parametric-bootstrap
  inference — two distinct bugs found investigating
  `InferenceOrdinalCloglogRegr`'s 60% Type-I error** —
  `../bug_fix_plans/ordinal_cumulative_link_null_refit_multistart.md → TODO-1..18`
  (now including **TODO-12**, added 2026-09-24: `InferenceOrdinalContRatioRegr`'s
  `fit_null` is still single-start — the exact same unfixed Bug-1
  vulnerability, found by direct code comparison; high confidence, not yet
  reproduced — candidate explanation for this class's own 9-family
  `pval_miscalibration` audit finding; and **TODO-13/18**, added 2026-09-24,
  resolved the same day: TODO-13's suspected shared package-level SE bug
  across `ContRatioRegr`/`PartialProportionalOddsRegr`/`Cauchit`/
  `AdjCatLogitRegr` turned out to be a **harness truth-registry gap**,
  not a package bug, for 3 of the 4 classes (`Cauchit`/`AdjCatLogitRegr`/
  `ContRatioRegr` are genuinely misspecified relative to the harness's
  cumulative-logit DGP — same mechanism as the already-fixed
  `InferenceOrdinalRidit` bug; confirmed high confidence, fix tracked at
  `../bug_fix_plans/mc_coverage_truth_covariate_mismatch.md → TODO-10`,
  not yet implemented, harness-only change). `PartialProportionalOddsRegr`
  was initially thought correctly specified and separately open (`TODO-18`
  in the linked plan) — **resolved same day**: it's a 4th instance of the
  same harness-truth-registry gap via a different mechanism
  (non-collapsibility of the treatment coefficient under covariate
  adjustment — coverage is nominal everywhere except `model_formula=~.`
  at nonzero `beta_T`, where it collapses to 0.283 — confirmed by
  `beta_T`-stratified querying, high confidence). Now folded into the
  same `mc_coverage_truth_covariate_mismatch.md → TODO-10` fix, 4 classes
  total. Also this same pass: `InferenceOrdinalOrderedProbitRegr`'s 0.760
  `compute_bayesian_bootstrap_confidence_interval_basic` outlier
  confirmed to genuinely hit the "basic"/reflection CI formula (not the
  "percentile" default), closed as the same known skew-sensitivity
  weakness already found benign for `InferenceSurvivalDepCensTransformRegr`
  — no source defect, no v1.5.0 entry. `TODO-9`
  (`InferenceOrdinalKKCondAdjCatLogitRegr`) root-caused to medium
  confidence: `TODO-28` cleanly ruled out (declared-but-bodiless
  `overrides`, same pattern as `InferencePropKKGLMM`, falls through to
  the generic `supports_reusable_bootstrap_worker()=FALSE` default); new
  leading candidate is `weighted_ordinal_bootstrap_surrogate_fit()`'s
  approximate (non-exact) weighted refit distorting the bootstrap
  distribution — not yet confirmed or traced to a fix.
  (1) **Fixed**: `get_likelihood_test_spec()`/`simulate_under_lik_null()`'s
  `fit_null` closures were single-start constrained refits — the identical
  vulnerability found and fixed in `InferenceOrdinalStereotypeLogitRegr`
  (TODO-8); same multi-start fix applied. Verifying it surfaced a durable
  gotcha: this class composes via a two-step "interim R6 class → lazy
  component registry → composed class" pattern, and checking
  `Generator$private_methods$fn` after `pkgload::load_all()` — even with
  `reset=TRUE`, even after a real `R CMD INSTALL` — does not reflect the
  edit; only an instantiated object's bound method does. (2) **Root-caused,
  not fixed, and the actual cause of the reproduced 60% Type-I error**: the
  shared `simulate_param_boot_ordinal_y()` helper generates bootstrap
  replicates via `cdf_fn(threshold - eta)` using the model's native fitted
  parameters, but Cloglog's own `compute_estimate()` negates that native
  coefficient for public use — the helper's formula has the wrong sign for
  this class's actual fit convention. Confirmed directly: simulating under
  a native value of `-0.383` and refitting recovers `+0.14` to `+0.89`
  (clustered near the negation, not the true value). A per-class sign
  audit of the five other classes this triage wave also flagged (`Cauchit`,
  `PropOddsRegr`, `KKCondAdjCatLogitRegr`, `AdjCatLogitRegr`,
  `OrderedProbitRegr`) found none of them share this bug — their own flags
  are on unrelated mechanisms, out of scope here. At that point, a
  package-wide sweep for any other class sharing both the helper and the
  negation pattern remained open (plan's TODO-2b); the sweep was later
  completed as recorded below. **2026-09-25, investigated at user request
  from the live TODO-4 re-run's first partial results:**
  `PropBetaRegr`/`PropFractionalLogit` still cover at only 0.84/0.85
  (nominal 0.95) on `ionosphere` (33 real covariates) after the
  `mc_coverage_truth_covariate_mismatch.md` fix landed — checked whether
  this is `TODO-6`'s MC-truth-non-convergence mechanism recurring (many
  real covariates, like the Cox/`diamonds` case): it is **not**. The MC
  truth here (0.37-0.43 across block-recycled/bootstrap constructions and
  2 seeds) converges consistently and sits within half an SD of the real
  per-row estimator's own distribution at `n=148` (mean 0.411, SD 0.143) —
  unlike Cox's truth, which was 6-9 SDs outside it. Instead, coverage is
  uniformly ~0.79-0.81 across 4 independently-derived asymptotic CI methods
  (`asymp`/`wald`/`lik_ratio`/`subsampling`) while resampling-based methods
  (`jackknife_wald`/`lik_ratio_bootstrap`) over-cover at 1.00 — the
  signature of an anti-conservative model-based SE at high covariate count
  relative to `n` (33 covariates, `n=148`), not a wrong truth. Root-caused
  to medium confidence only (one dataset, 33-128 reps so far); full
  write-up and TODO at `mc_coverage_truth_covariate_mismatch.md → TODO-11`.
  Explicitly not the same bug as `TODO-6`; do not conflate when resolving
  either.

  **TODO-11 artifact/provenance re-audit, 2026-10-21:** the ignored local
  `R/package_tests/comprehensive_tests_results_nc_1_proportion.csv` snapshot
  (84,170,816 bytes; SHA-256
  `cd5bbd589816657930eb8e4aa5ae92b9f4fe8de02084dcfa21548a37d9edc6ba`)
  contains 1,438 ionosphere beta_T=0.5 rows for the two affected classes
  (854 `PropBetaRegr`, 584 `PropFractionalLogit`). It cites source commit
  `95e5203765fde92b5d501c0e93139603c2a95bf1` but has no provenance sidecar or
  installed package/DLL identity, so it cannot confirm this hypothesis against
  a current installation. The observed ionosphere pattern remains roughly
  0.79--0.81 for asymptotic/Wald/LR/subsampling CIs versus 1.00 for
  jackknife-Wald/LR-bootstrap; this is consistent with, but does not prove, a
  high-p/n SE limitation. Existing `/tmp` merged coverage reports measure
  code coverage, not statistical CI coverage. No provenance-matched lower-p/n
  comparison is retained. The linked plan's acceptance gap remains a current-
  provenance beta_T=0.5 comparison for both classes on a lower-covariate-count
  dataset, followed by the maintainer's choice to document a reproducible
  high-p/n limitation or investigate an SE correction; if lower-p/n
  under-coverage also appears, revisit the shared truth/SE explanation. The
  linked-plan TODO-11 remains open and separate from TODO-6; this note does
  not close or change the release TODO-16 checkbox.

  **Implementation status 2026-10-09:** the cloglog simulator now converts
  native slopes to the public `threshold - X beta` convention; its observed
  fit screens deterministic alternative starts; and continuation-ratio
  observed/simulated constrained fits select the better of two starts.
  Focused source-loaded checks preserve the cloglog sign (the old fixture
  refit at median -1.42 around an observed +1.33), give 0/25 null rejections
  for both parametric and LR bootstrap checks, and 24/25 parametric-CI
  coverage. Harness MC-refit truth now covers cloglog and ordered probit,
  while the conditional adjacent-category class no longer advertises a
  Bayesian bootstrap based on its mismatched surrogate estimator. The
  focused migration/registry suites pass. The completed TODO-2b source
  sweep found exactly four production callers of the shared ordinal
  simulator (Cauchit, Cloglog, Ordered Probit, Proportional Odds); only
  Cloglog negates its native slope block before simulation, and no additional
  affected caller was found. This establishes source scope only, not null
  calibration. **Linked-plan status corrected
  2026-10-16:** TODO-1 is open again because no independent post-fix
  true-null calibration is recorded for direct LR, LR-bootstrap, or
  Bartlett-approx methods; the focused multistart-selection tests do not
  establish their rejection rates. TODO-6 also remains open for installed-
  package comprehensive CSV regeneration and re-audit. Linked-plan TODOs
  2-5 and 7-18 remain closed. This release item stays unchecked until both
  TODO-1 and TODO-6 are complete.
  - [ ] Calibrate direct LR, LR-bootstrap, and Bartlett-approx methods under
    the post-fix Cloglog null with independent seeds and a predeclared
    rejection-rate interval; then regenerate and re-audit all affected
    parametric-bootstrap comprehensive rows with package/DLL provenance.

  **Acceptance-policy audit, 2026-10-18:** repository reporting includes an
  exact binomial size p-value, but no pass cutoff or accepted interval;
  comprehensive miscalibration screening and its power-only
  `LOW_POWER_TARGET` do not set this criterion. Keep this item open until the
  maintainer adopts the audit rule or specifies the interval, confidence
  level, and replicate/finite-denominator target. Details are recorded in
  `../bug_fix_plans/ordinal_cumulative_link_null_refit_multistart.md → TODO-1`.
  **Decision tradeoff, clarified 2026-10-21:** adopting the existing audit
  screen (combined binomial-size evidence, BH `q = 0.05`, 30-row minimum) is
  the smallest-policy-change option, but its non-rejection is not evidence of
  practical equivalence to nominal size and its row floor is not a precision
  target. Alternatively, the maintainer can define an acceptable rejection-
  rate interval, confidence level, and valid-replicate denominator; that
  provides an explicit tolerance/precision target but requires choosing the
  limits and running enough independent null replicates. No option or
  numeric criterion is selected; calibration remains gated on this decision.

  **Installed-package multistart regression recheck, 2026-10-20:** the
  focused Cloglog and stereotype-logit constrained-null-refit tests, including
  the second `simulate_under_lik_null()` closure test, passed 18 expectations
  against EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  matches checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. These mocked optimizer-selection
  checks confirm installed R behavior only; they do not establish source-to-
  install R provenance or the three methods' Type-I calibration. The
  maintainer's acceptance criterion, independent null calibration, and TODO-6
  comprehensive regeneration/re-audit remain open. No Type-I simulation or
  build/install occurred. **Current-checkout/current-native recheck,
  2026-10-20:** reran the two constrained-null-refit selection tests and the
  second `simulate_under_lik_null()` closure test after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. All 18
  assertions passed with no failures, warnings, or skips. Checkout HEAD was
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  matched the user-rebuilt installed DLL and checkout `R/EDI/src/EDI.so`
  byte-for-byte. This closes focused checkout-R/current-native provenance
  only; TODO-1's acceptance/calibration gate and TODO-6's comprehensive
  regeneration/reconciliation remain open. No build/install or canonical
  output write occurred.
  **Run-replay metadata guard, 2026-10-20:** comprehensive-run provenance
  snapshots now include `RNGkind()` and the current `.Random.seed` in both
  before/after records; the focused provenance test verifies the snapshot
  against the actual capture state and passed with no failures, warnings, or
  skips. The run used checkout helper code and installed EDI 1.0.3 under
  R-devel `r90668` (DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`); no
  native compilation/build/install occurred. This makes future runs more
  replayable but does not parameterize the harness's fixed seed or satisfy
  independent-seed Type-I calibration. The owner acceptance rule and
  TODO-6's comprehensive regeneration/re-audit remain open.

  **Constrained-coordinate regression, 2026-10-21:** the focused Cloglog
  null-refit test now checks both `fixed_idx = spec$j` and
  `fixed_values = -delta` (fixture `delta = 0.3`), and that the selected fit
  retains the constrained coordinate. The test passed all 8 expectations
  against installed EDI 1.0.3. This is installed-package evidence only; it
  does not establish current-checkout R-layer provenance, true-null
  rejection calibration, or comprehensive-row regeneration. No simulation,
  build/install, or canonical output write occurred. TODO-16 remains open for
  the maintainer's acceptance rule and independent calibration, plus TODO-6's
  post-fix comprehensive regeneration/re-audit.

  **Independent confirmation 2026-10-09** (algorithm-sweep verification F18,
  `../new_feature_plans/algorithm_choice_audit_catalog.md §13.4`): the cloglog
  native `α + xβ` convention is the root cause of the sign bug, **for cloglog
  only**. Proportional-odds, cauchit and ordered-probit callers match the shared
  simulator and are unaffected. AdjCat, KKCondAdjCat, CR and stereotype never call it.
  The staged cloglog fix (`inference_ordinal_cloglog.R` +
  `test-cloglog-parametric-bootstrap-native-sign.R`) checked out as correct.
  **Installed-package focused regression recheck, 2026-10-21:** the two
  constrained-null-refit selector tests and the null-likelihood simulation
  closure test passed all 18 expectations (0 failures, warnings, or skips)
  against installed EDI 1.0.3. The loaded DLL was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This is installed-artifact evidence for null-refit multistart selection and
  likelihood-null closure only; it does not establish current-checkout R-source
  provenance or true-null rejection-rate calibration for LR, LR-bootstrap, and
  Bartlett. The maintainer-selected calibration rule and TODO-6 comprehensive
  row regeneration/reconciliation remain open. No broad simulation,
  build/install, or canonical output write occurred.
  **Calibration-artifact audit, 2026-10-21:** the acceptance rule is still
  unspecified: exact-binomial size reporting supplies a p-value but no pass
  cutoff/interval; the audit's BH `q=0.05` plus 30-row screen is a discovery
  rule, and `LOW_POWER_TARGET=0.10` is a power criterion. Retained post-fix
  evidence separates into (a) an implementation repro for the distinct
  simulator-sign bug: 25 true-null reps at `n=100`, `B=39` gave 0/25 rejects
  for the two parametric-bootstrap p-value families and CI coverage 24/25,
  with an ordinary-LR 8/100 result; this is not the independent post-fix
  calibration of the constrained-null-refit fix required by TODO-1, and the
  small counts do not establish an approved pass rule; (b) a retained
  one-replicate installed-package pilot for Cloglog / Bernoulli / `diamonds` /
  `beta_T=0`, `rep=1`, which emitted eight `ok` parametric-bootstrap-family
  rows across `~1` and `~.` but is not a rejection-rate study; and (c) focused
  null-refit-selection tests (18 expectations) that exercise mocked optimizer
  outcomes/closure behavior, not rejection rates. The canonical ordinal CSV's
  latest recorded affected rows predate the 2026-10-09 fix (Cloglog and
  continuation-ratio rows dated 2026-09-27); it is not a post-fix result
  artifact. No retained artifact supplies independent-seed rejection counts
  and denominator/nonestimable accounting for direct LR, LR-bootstrap, and
  Bartlett under the post-fix Cloglog true null. **Bounded next step:** obtain
  the maintainer's choice of (i) pass rule or acceptable rate interval and
  confidence level, (ii) number of reps/finite-denominator handling, and
  (iii) the approved true-null fixture/seed protocol for those three methods.
  Only then run and report that narrowly scoped Cloglog calibration with
  independent seeds; keep TODO-6's separate provenance-stamped comprehensive
  row regeneration/re-audit gated on TODO-56's shared-output release. No
  simulation or canonical result access was performed for this audit.
  **Decision-ready TODO-1 calibration protocol options, 2026-10-21:** the
  linked plan identifies one confirmed class/null target,
  `InferenceOrdinalCloglogRegr` with treatment coefficient `beta_T=0`, and
  three separate outcomes to calibrate: `compute_lik_ratio_two_sided_pval`
  (direct LR), `compute_lik_ratio_bootstrap_two_sided_pval` (LR bootstrap),
  and Bartlett approximation. The exact DGP/dataset, `model_formula` strata,
  and inner LR-bootstrap B are not specified for this post-fix check. The
  retained one-replicate pilot (`Bernoulli` / `diamonds` / `beta_T=0`, both
  `~1` and `~.`) exercises execution only, not calibration. The plan's
  `25+`-replicate, `n=100` precedent belongs to TODO-4's distinct
  `compute_param_bootstrap_pval` simulator-sign fix; it is not a TODO-1
  sample-size criterion and does not test these three methods.

  For planning only, at nominal size `p=0.05`, a normal approximation to a
  95% binomial interval gives half-widths of about 1.9 percentage points at
  500 independent outer datasets per selected null stratum (evaluate all
  three methods on each dataset), 1.35 points at 1,000, and 0.96 points at
  2,000 (`h ~= 1.96 * sqrt(p*(1-p)/n)`). These are transparent precision
  options, not acceptance limits; final results should report exact binomial
  intervals at a maintainer-selected confidence level. `n=100` is about ±4.3
  points and `n=25` about ±8.5 points at the same nominal rate, illustrating
  why the older small diagnostic cannot by itself establish tight calibration.
  **Project-convention recommendation:** `SimulationFrameworkReport` already
  computes size from finite p-values (`pval < alpha`), records their count as
  `n_size`, and reports the exact two-sided binomial test of `H0: size=alpha`;
  its file-backed default is `alpha=0.05`, matching the historical audit
  signal. Reuse that finite-p-value denominator and report `k`, `n_size`, and
  the observed rate, plus an exact Clopper-Pearson interval (the report's
  `size_pval` is a test, not an interval). The comprehensive audit uses BH
  `q=0.05` with a 30-row discovery floor for its p-value-distribution screen;
  this is a reasonable diagnostic screen to report alongside the size
  statistics, but is not established as TODO-1's pass rule. `LOW_POWER_TARGET`
  is for alternatives and does not govern this null check. Keep attempted,
  estimable, and nonconvergent counts visible even when using `n_size` as the
  rate denominator.

  **Owner choices still required:** approve the true-null DGP/dataset and
  whether `~1` and `~.` are separate strata; select outer replicate target,
  inner LR-bootstrap B, interval confidence level, treatment of failures in
  any acceptance denominator, and whether the decision is a per-method/cell
  interval or a simultaneous/multiplicity-adjusted criterion. The finite-p
  denominator and exact-binomial reporting can follow existing project
  convention without a new policy choice, but no rejection-rate simulation
  should be treated as acceptance evidence until those fixture and pass-rule
  choices are explicit. The deterministic
  `test-simulation-report-finite-calibration-reference.R` already checks
  finite-p-value denominators and exact-binomial size p-values, so that
  reporting contract can be reused without fits. No threshold, DGP expansion,
  or simulation is selected here; TODO-1 and the independent TODO-6 artifact
  gate remain open.
- [x] TODO-17 (CLOSED 2026-10-21 by owner decision: deferred; remedy tracked in `release_v1_5_0.md → TODO-1`; added 2026-09-23, surfaced by the new `pval_miscalibration`
  audit check's extreme-violation triage — ACAT-combined p as low as
  2.5e-300 — root-caused same day): **`InferenceAllSimpleWilcox`
  resampling-family p-values collapse to exactly 1** —
  `../bug_fix_plans/simple_wilcox_hl_degenerate_pval_boundary.md → TODO-1..7`. A
  resurfacing of an already-partially-fixed bug: the Wald-family variant
  of this exact mechanism, in this same file, was already found and fixed
  2026-09-06 — the resampling-family methods (`rand`, `bootstrap*`,
  `m_out_of_n_bootstrap`, `subsampling`) were simply never touched by that
  fix and still carry the identical defect. Root cause: the class's
  Hodges-Lehmann point estimate frequently lands on exactly 0 on tied
  count/ordinal data, which also degenerates the resampling null
  distribution's tail proportions toward 1, saturating the generic
  two-sided p-value formula's `min(1, ...)` clamp. Confirmed by direct
  reproduction: 100% of true-null reps landing at `beta_hat_T == 0`
  produced `compute_rand_two_sided_pval() == 1` exactly, matching the
  historical audit's 80-99.6% observed rates. Not the stale-cache bug
  (`shared()` guards on standard keys, already correctly reset) and not a
  fast-path bug (uses a dedicated vectorized C++ kernel, not the
  reused-worker `cached_values` path) — ruled out directly, not assumed.
  Sibling classes `InferenceAllSimpleAverageDiff`/
  `InferenceAllSimpleMeanDiffPooledVar` confirmed unaffected (mean-
  difference estimators essentially never land exactly on 0). A mid-p/
  tie-splitting change to the generic two-sided p-value formula
  (`inference_all_abstract_rand.R:317` and the bootstrap-family equivalents)
  was the initial candidate. TODO-2 later ruled out a generic rewrite for
  v1.0.5 because it would alter legitimate tied results package-wide; any
  remedy must be Wilcoxon-scoped and supported by the plan's direct
  count/ordinal and coverage evidence.
  Independent of every other item in this release; depends on nothing else.

  **Updated 2026-09-24** (plan's TODO-1..7 now cover CI coverage too, plan's
  new TODO-8/9 added): the new `low_coverage` audit check found the SAME
  HL-ties-at-zero mechanism also breaks this class's resampling-family CI
  coverage (~48-57%, target 95%), via the identical degenerate
  `boot_distr` feeding `bootstrap_ci_from_distribution()`'s `"basic"`
  quantile formula — confirmed, not a separate bug, no new plan file
  needed. Separately, `InferenceAllSimpleMeanDiffPooledVar` (previously
  confirmed unaffected by the p-value mechanism) also shows CI
  undercoverage (~55%) — a genuine, independently-confirmed bug was found
  (its Bayesian-bootstrap estimator silently uses `AverageDiff`'s Welch
  formula instead of its own documented pooled-variance formula, despite
  `overrides$public` declaring an override that doesn't exist) but does
  NOT explain the specific flagged symptom (the flagged CI type never
  reads the SE the Welch/pooled bug affects) — real bug, unconfirmed
  cause of the coverage finding, both tracked in the same plan's new
  TODO-8/9.

  **Static scope reconciliation 2026-10-10:** the linked plan's TODO-2 is
  complete: the inclusive-tail calculation is shared by randomization,
  bootstrap, Bayesian-bootstrap, exchangeable-resampling, and
  rand-bootstrap paths. A generic mid-p rewrite would alter legitimate
  tied results package-wide, so it is not a safe source-only fix for this
  Wilcoxon-specific defect. The direct count/ordinal reproduction was
  rerun after the user's reinstall on 2026-10-14: zero-HL draws yielded
  `p_rand == 1` in 100% of cases (76% of count runs; all ordinal runs).
  This confirms the discrete boundary, but not an anti-conservative p-value;
  no unvalidated mid-p change was made. The independent pooled-variance
  Bayesian-bootstrap SE fix now has a passing deterministic regression.
  Wilcoxon-scoped method/coverage work remains open; this release item stays
  unchecked.
  - [x] **Owner decision 2026-10-21: defer the Wilcoxon-specific remedy.** Keep the
    deterministic inclusive-tail method and document the conservatism (roxygen
    on `InferenceAllSimpleWilcox`). No generic mid-p change. TODO-3..7 of the linked
    plan stay open until a candidate passes the conditional-size gate. This item
    stays unchecked as a deferred-to-later-release item: the resampling CI
    undercoverage (~48-57%) from the same mechanism is also deferred and is
    documented, not fixed.
  - [ ] (superseded by the deferral above) Obtain a maintainer decision on the Wilcoxon-specific remedy or an
    explicit deferral. If proceeding, require nondegenerate-estimand parity,
    conditional size calibration for HL-zero ties, and a permanent tied
    p-value/CI regression before post-fix comprehensive regeneration; do not
    use a generic mid-p change.
- [ ] TODO-18 (added 2026-09-23, surfaced by the new `pval_miscalibration`
  audit check — one function_run variant appeared across ~85 distinct
  (class, response_type) cells with wildly inconsistent miscalibration
  direction/severity, itself the tell that this is shared machinery
  breaking differently depending on data shape, not 85 per-class bugs;
  root-caused same day): **`smoothed` randomization-bootstrap p-value adds
  unclamped continuous noise to binary/ordinal responses** —
  `../bug_fix_plans/rand_bootstrap_smoothed_noise_unclamped.md → TODO-1..8`.
  **Partial fix 2026-10-07:** categorical/bounded model refits now reject
  `smoothed` explicitly, while fast real-valued statistics retain support;
  focused noncompiling tests pass. Broad class calibration and CSV
  regeneration remain open. The original investigation found this to be
  shared: `add_rand_bootstrap_smooth_noise()`
  (`inference_all_abstract_rand_bootstrap.R:613-618`), one function, three
  call sites in the abstract base class, no per-class override. Root
  cause: it has an explicit special case rounding/clamping noisy responses
  for `response_type == "count"` (fixed 2026-09-15 after negative noisy
  counts broke Poisson refits) but **no equivalent for `incidence`
  (binary 0/1) or `ordinal` (integer category codes)** — the code's own
  comment says "every other response type keeps the raw additive noise,"
  so continuous Gaussian noise lands straight on 0/1 or integer-coded
  responses (e.g. `y=0.3`, `y=4.7`) feeding a refit that expects
  binary/ordinal data, with undefined-by-design downstream behavior that
  varies wildly by class — exactly matching the audit's observed range
  (`InferenceContinKKRobustRegrOneLik` reject-rate 0.495 at a true null,
  10x nominal; `InferenceIncidKKCondLogitOneLik` 0.325, 6.5x nominal;
  `InferenceOrdinalGCompMeanDiff` 0.000, never rejects). One open thread:
  `InferenceContinKKRobustRegrOneLik` is `continuous`, not one of the two
  identified-missing types, so the bandwidth formula itself
  (`sd(private$y)/sqrt(n)`) may need its own look across response
  types/link scales, not just the missing rounding (plan's TODO-2).
  Bounded to classes routing through this R-level dispatch — the C++ batch
  kernels (mean difference, Wilcoxon, survival) apply noise themselves per
  an existing code comment and are believed unaffected (plan's TODO-1
  confirms the exact boundary). Independent of every other item in this
  release; depends on nothing else.
  **Status reconciliation 2026-10-10:** the policy/source steps (linked
  TODOs 4--5) are complete: public p-value/CI guards, advertised types,
  lower-level draw guards, and the compatible real-valued/count paths have
  58 focused source-loaded expectations. This does not validate the original
  calibration finding. The exact dispatch/audit cross-reference (TODO-1),
  continuous-bandwidth investigation (TODO-2), direct historical
  reproduction (TODO-3), true-null calibration and permanent calibration
  regression (TODOs 6--7), and post-install CSV regeneration (TODO-8) all
  remain open; this release checkbox must remain unchecked. After the user's
  2026-10-14 reinstall, the smoothed-noise plumbing and count-support tests
  passed 7 and 58 assertions, respectively; these are guard/plumbing checks,
  not calibration evidence.
  **Source-boundary follow-up, 2026-10-18:** the dispatch audit documented
  three R-level noise paths separately from C++ batch kernels, which consume
  their own `noise_mat`; current-source runs of the smoothed-count-support
  and noise-matrix-plumbing tests passed 58 and 7 assertions (65 total).
  The tracked baseline contains 25 `_smoothed` rows: 16 currently admitted
  continuous/count keys (five dispatched to identified C++ batches, eleven
  to generic R refits) and nine incidence/ordinal keys now blocked by the
  support predicate. This does not recover the other ~60 historical cells;
  their exact keys require the missing provenance-bearing historical audit
  input/output. It also does not validate the continuous bandwidth formula or
  provide calibration evidence.
  **Historical-class CI guard recheck, 2026-10-20:** the existing focused
  support test now checks CI support advertisement and pre-draw rejection for
  `InferenceIncidKKCondLogitOneLik` and `InferenceOrdinalGCompMeanDiff`, in
  addition to p-values. The source-loaded test passed 62 expectations with
  compilation disabled (test SHA-256
  `a9f60a6a4e98bb1180478b54a6a1bff5cad567f7ecad70f754dc725dd062b391`; already-built
  overlay DLL SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`). This
  only closes the deterministic CI-guard coverage gap; calibration, the
  continuous-bandwidth investigation, historical audit provenance, and
  post-install CSV regeneration remain open, so TODO-18 remains unchecked.
  **Installed-package guard recheck, 2026-10-20:** the focused
  `R/EDI/tests/testthat/test-brt-smoothed-count-support.R` passed 62
  expectations against EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (MD5 `a75519a9256c0b3121398032314291d4`). This confirms support/rejection
  guards on the installed package only; it does not validate calibration,
  historical findings, bandwidth, or regenerated comprehensive rows. No
  build/install or canonical write occurred.
  **Installed-package focused recheck, 2026-10-21:** with no competing R
  process, ran `test-brt-smoothed-count-support.R` and
  `test-brt-smoothed-noise-mat-plumbing.R` sequentially via
  `testthat::test_file()` after `library(EDI)`. They passed 62 and 7
  expectations respectively (69 total; no failures, warnings, or skips).
  Package version/path were EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had
  SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This confirms the installed package's deterministic support/guard and
  noise-matrix plumbing contracts only; it does not establish checkout R or
  native-source behavior, historical reproduction, true-null calibration,
  or post-fix comprehensive-row provenance. The tracked baseline cohort
  remains 25 `_smoothed` keys (16 currently supported continuous/count and
  nine intentionally blocked incidence/ordinal), while the other historical
  cells are not provenance-resolved. Open linked gates are the TODO-1 exact
  dispatch/caller cross-reference, TODO-2 continuous-bandwidth investigation,
  TODO-3 historical reproduction, TODO-6/7 owner-specified true-null strata,
  replicate/precision and acceptance rule plus permanent calibration test,
  and TODO-8 post-install provenance-stamped regeneration/reconciliation
  after TODO-56 releases the shared result paths. No build/install or
  canonical CSV write occurred.
  **Rejected-request RNG regression, 2026-10-21:** the existing fast-tier
  support test now also asserts that unsupported categorical smoothed p-value
  and confidence-interval requests leave the caller's `.Random.seed` unchanged
  for incidence, ordinal, and proportion model-refit classes. The focused
  installed-package test passed 68 expectations with no failures, warnings,
  or skips; no build/load_all/install or canonical artifact write occurred.
  This pins the early-rejection reproducibility contract only; it does not
  address TODO-18's calibration, historical audit, bandwidth, or regeneration
  gates.
  **Latest installed-artifact support recheck, 2026-10-21:** reran
  `test-brt-smoothed-count-support.R` via `timeout 180s Rscript -e` after
  `library(EDI)`; all 68 expectations passed (0 failures, warnings, or skips).
  Installed EDI 1.0.3 was at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`), byte-identical to the ignored
  checkout DLL. Test file SHA-256
  `67d7af1b25207cf62f21a5f64c212abae4a4d047dece86b4be9674193d165126`.
  This verifies deterministic support/guard behavior on the installed
  artifact only; it does not validate calibration, historical findings,
  bandwidth, current R-source identity, or comprehensive rows. No
  build/install or canonical write occurred.
  **Decision-ready true-null protocol options, 2026-10-21:** the linked plan's
  expressly named minimum calibration roster is nine cells: continuous
  `InferenceContinKKRobustRegrOneLik` / `~1` and `InferenceContinOLS` / `~.`,
  plus the seven currently supported count keys
  `InferenceAllSimpleAverageDiff` / `NA`, `InferenceCountHurdleNegBin` /
  `~1`, `InferenceCountHurdlePoisson` / `~1`,
  `InferenceCountKKHurdlePoissonOneLik` / `~1`, `InferenceCountPoisson` /
  `~.`, `InferenceCountZeroInflatedNegBin` / `~1`, and
  `InferenceCountZeroInflatedPoisson` / `~1`. This is distinct from the
  broader source-supported baseline cohort of 16 keys: the other seven
  continuous keys are `InferenceAllSimpleAverageDiff` / `NA`,
  `InferenceAllSimpleMeanDiffPooledVar` / `NA`, `InferenceContinLin` / `~.`
  and `~1`, `InferenceContinOLS` / `~1`,
  `InferenceContinQuantileRegr` / `~1`, and `InferenceContinRobustRegr` /
  `~1`. The roster decision is whether to calibrate only the nine cells
  expressly named by the plan or all 16 source-supported cells; do not treat
  all 16 as historical miscalibration findings without the missing
  provenance-bearing historical audit input. The nine incidence/ordinal
  baseline keys are intentionally unsupported now and belong only in the
  deterministic rejection/advertisement checks, not an estimator-size
  calibration.

  Apply the existing finite-null reporting convention to each admitted
  candidate: `SimulationFrameworkReport` forms `size` from finite p-values
  satisfying `p < alpha`, records their count as `n_size`, and reports the
  exact two-sided binomial test of `H0: size=alpha`. Report `k`, `n_size`, and
  the observed rate for percentile and smoothed variants separately, with an
  exact Clopper-Pearson interval at a stated confidence level; additionally
  retain attempted, nonfinite/nonestimable counts and paired decision
  discordances. The current report supplies the exact test, not the interval.
  The audit's BH `q=0.05`/30-row rule is a discovery screen only, not an
  acceptance band for these cells.

  The plan proposes at least 500 *estimable* outer cases per selected
  stratum and B=101 materialized assignments per case. For transparent
  planning, the normal approximation `n ~= z^2 p(1-p) / h^2` at nominal
  `p=0.05` gives a 95%-planning half-width `h` of about 4.3 percentage points
  at n=100, 1.9 points at n=500, and 1.0 point at n=1,825. These are
  precision illustrations, not pass bands. The nine-cell minimum is 4,500
  estimable outer cases; expanding to all 16 admitted candidates is 8,000,
  with the same 101 assignments per case and paired variants. Report exact
  binomial intervals for observed rejection counts; the maintainer chooses
  the interval confidence level and acceptance rule. The choice still needed is
  whether the criterion is per-cell or simultaneous across selected cells,
  including any multiplicity treatment; neither exact-binomial reporting nor
  `LOW_POWER_TARGET` supplies a cutoff. Also specify the selected roster,
  true-null design/DGP (recover the comprehensive harness inputs or approve a
  clearly labeled fresh representative design), seeds, and how estimable vs.
  attempted outer cases define the denominator. For each case, pair the
  percentile and smoothed variants on identical assignments and Gaussian
  noise; retain attempted/estimable counts and paired decision discordances.
  Keep B=101 unless the maintainer changes the precision/run-cost target.
  No simulation or canonical result access occurred for this protocol note;
  the calibration, acceptance rule, and post-install regeneration gates
  remain open.
  **Bounded on-disk recheck, 2026-10-21:** the two exploratory raw pilot files
  are present under `scratch/todo18_onelik_larger_n_20261016_01/` (200 data
  rows; SHA-256 `623fe2f22bd123eca1a8b58f0a3f189ac097d46e60912285ea395610b33dd59d`)
  and `scratch/todo18_onelik_kk21stepwise_20261016_01/` (100 rows; SHA-256
  `e46b1a8688d37135753430f2b0e776b3dfbcccfed98096affc5fe53881b90e71`).
  Their companion summaries/paired tables are present, but neither directory
  has a provenance sidecar or package/DLL/R/source identity. Raw rows retain
  deterministic seed/variant columns and identify EDI 1.0.3. The specifically
  named earlier `/tmp/edi-todo18-robust-onelik-bandwidth-20261016*` outputs
  are absent. These small synthetic pilots do not recover the historical
  105-row inputs or resolve the roster, null-DGP, acceptance, denominator,
  or precision choices above. No workload, build/install, or canonical output
  was touched; TODO-18 remains open.
  - [ ] Finish the dispatch/support cross-reference and continuous-bandwidth
    investigation; then, after TODO-56 releases shared result paths, run the
    predeclared matched calibration for supported continuous and count cells
    (at least 500 estimable cases per stratum, B=101, shared assignments and
    noise, exact binomial intervals and paired discordances). Verify bounded
    categorical cases are rejected, select and pin a permanent-test fixture/
    tolerance, then regenerate rows with package/DLL provenance.
  **Retained-artifact audit, 2026-10-21:** only two exploratory B=101
  robust-OneLik pilot slices remain: FixedBinaryMatch n=148 (50 fixtures) and
  KK21stepwise n=60 (25 fixtures), both from installed EDI 1.0.3. They retain
  seeds and paired variants, but no package path, DLL hash, R version, checkout
  HEAD/source hash, or provenance sidecar, so they do not establish current
  post-fix calibration. Earlier n=30/25-fixture and 500-fixture `/tmp` outputs
  are absent; retained comprehensive CSVs are historical and lack seeds,
  assignments, and response vectors for replay. No artifact closes the
  calibration gate. The supported roster, null strata/DGP, per-cell versus
  simultaneous acceptance rule/multiplicity, interval confidence level,
  attempted-versus-estimable denominator, and proposed ≥500 estimable cases
  per stratum (B=101) still require confirmation. Keep post-fix calibration
  and provenance-stamped comprehensive regeneration open; no run or result
  merge occurred.
- [ ] TODO-19 (added 2026-09-23, resolved in source 2026-10-09):
  **`InferenceIncidKKModifiedPoisson` exposed invalid working-likelihood
  inference.** The validated estimator uses a cluster-robust sandwich, so
  score, gradient, likelihood-ratio, Bartlett, and parametric-bootstrap
  procedures from the Poisson working likelihood were removed. The class
  and registry now advertise Wald inference only with `likelihood_tier =
  "none"`; focused source-loaded regression coverage is complete. The
  original over-estimated-SE hypothesis was refuted by the faithful
  200-replicate Pima/KK21stepwise replay (empirical SD 0.19318; mean robust
  SE 0.19870; ratio 1.0286; MC-truth coverage 0.955). Installed
  comprehensive-CSV regeneration/re-audit remains the sole release gate.
  **Additional installed migration-golden check:** the updated
  `test-incid-kk-modified-poisson-migration-golden.R`, including the explicit
  `likelihood_tier == "none"` assertion, passed 36 expectations against
  installed EDI 1.0.3 after sourcing the checkout's pure-R fixture helper.
  This is mixed-provenance test evidence, not a source-loaded or rebuilt-
  checkout validation; the exact invocation and loaded DLL hash were not
  captured. No build/install or canonical result write occurred.
  **Current artifact audit, 2026-10-21:** the canonical incidence results
  CSV is 525,863,531 bytes and dated 2026-10-09, before the source fix. The
  two known `/tmp` roots retain only limited diagnostics: a 64-row all-family
  slice and an 8-row Wald slice, with no provenance sidecars. Their limited
  keys/statuses do not cover the supported full matrix. The next acceptance
  step is a full class-filtered regeneration to isolated scratch with current
  package/DLL provenance, exact key/status reconciliation (removed likelihood
  methods absent; valid Wald rows retained), and only then consideration of a
  canonical update. No run or canonical CSV write occurred in this audit.
  **Read-only roster/resource preflight, 2026-10-21:** the current runner
  source expands to 26,880 class/formula labels for the full Modified Poisson
  incidence grid (12 incidence datasets × 2 beta values × 40 reps × 7 tested
  designs × 2 design formulas × 2 model formulas). The retained 64-row pilot
  contains 16 distinct `function_run` candidates per label; applying that
  operation roster yields 430,080 candidate rows, conditional on the pilot
  roster remaining eligible across the grid, not a guaranteed terminal-row
  count. The pilot took 11.340 aggregate seconds and occupied 49,574 bytes;
  linear extrapolation gives about 21.2 hours and 318 MiB of CSV output, with
  substantial runtime variability not captured by one Pima/KK21stepwise case.
  At the audit, `/tmp` had about 362 MiB free, leaving only about 44 MiB beyond
  the estimated CSV before sidecar/log/temp needs; this is inadequate headroom
  for a safe isolated full run. The existing pilot does not satisfy the full
  key/status reconciliation. Future authorized command shape, after creating
  an empty dedicated output directory and ensuring adequate scratch space:
  `EDI_COMPREHENSIVE_RESULTS_DIR=/tmp/edi-todo19-authorized-full-grid Rscript
  R/package_tests/comprehensive_tests.R 40 2 incidence NA
  InferenceIncidKKModifiedPoisson NA NA NA`. Keep the regeneration and
  canonical reconciliation gate open; no run or result-file edit was made.
  **Scratch-space recheck, 2026-10-21:** `/tmp` now reports 16 GiB free, so
  the earlier 362 MiB headroom constraint is no longer current. The retained
  `/tmp/edi-v105-todo19-current-DgbXhW/` still contains only the same 49,574-
  byte all-family pilot and 6,413-byte Wald pilot, dated 2026-10-20, with no
  run log or provenance sidecar. This metadata-only check reads no CSV payload
  and does not establish full-grid results. Disk capacity alone no longer
  blocks a fresh isolated candidate, but the estimated ~21-hour full grid,
  current package/DLL provenance, and exact key/status reconciliation remain
  gates; no workload was started.
  The historical investigation notes below record how the superseded SE
  hypothesis was ruled out.

  **Checked against the empirical SD 2026-09-23 — REFUTED as originally
  stated, medium confidence (approximate fixture, not an exact harness
  replay).** 40 true-null reps on a hand-built fixture approximating the
  flagged cell (`model_formula=~1`, `DesignSeqOneByOneKK21stepwise`,
  n=148): empirical SD of `beta_hat_T` = 0.221, mean implied SE from the
  asymptotic CI = 0.272 — a 1.23× ratio, mildly conservative, nowhere near
  the ~4× estimated from the historical CSV's IQR-vs-CI-width comparison.
  Wald reject rate = 2.5% (1/40) — mildly conservative vs. nominal 5%, not
  the dramatic "0.000 across every test family" the original finding
  reported. The dramatic pattern did not reproduce. Two live
  possibilities, neither resolved: the hand-built fixture isn't a faithful
  enough replay of `comprehensive_tests.R`'s exact data-generating process
  (baseline probability, per-subject noise), or the original historical-
  CSV comparison (IQR vs. CI width) pooled rows across conditions in a way
  that wasn't a clean apples-to-apples comparison — the same pooling risk
  flagged elsewhere in this session's own audit-tooling work. Before
  drawing further conclusions, reproduce using `comprehensive_tests.R`'s
  actual DGP call path (or re-pull the historical finding fresh from a
  larger CSV sample) rather than a hand-built approximation.

  **Broadened 2026-09-23** by a second, independent investigation (into
  `type="studentized"`/`"symmetric-percentile-t"` randomization-bootstrap
  p-values, which also showed wildly class-dependent miscalibration
  direction/severity across `InferenceOrdinalGCompMeanDiff`,
  `InferenceIncidKKCondLogitGLMMOneLik`, `InferenceIncidKKGEE`,
  `InferenceContinQuantileRegr` — same triage wave as this TODO). That
  investigation traced the shared dispatch/pivot code
  (`compute_rand_bootstrap_two_sided_pval()`,
  `inference_all_abstract_rand_bootstrap.R:471-505`, pivot formula at
  `:1026-1038`) and found it **correct** — the observed and every null-draw
  pivot read the identical `cached_values$s_beta_hat_T` field, no cross-
  estimator mismatch, no shared-code bug. This is evidence FOR, not
  against, this TODO's hypothesis: if the shared bootstrap machinery is
  clean, the class-dependent, both-directions miscalibration pattern (seen
  in TWO unrelated code paths now — Wald-family per this TODO's original
  finding, and the studentized-BRT pivot per this update) is best explained
  by **per-class SE-estimator quality**, not a single fixable shared bug.
  A class whose asymptotic/plug-in `s_beta_hat_T` is a poor finite-sample
  approximation would degrade every test family that consumes it
  (Wald/score/gradient/LR/Bartlett AND the studentized-bootstrap pivot)
  simultaneously through that one shared field — over-estimated SE →
  conservative/under-reject, under-estimated SE → anti-conservative/
  over-reject, both directions genuinely observed. Not yet confirmed by a
  multi-rep calibration repro (medium confidence). Tracked as an open
  investigation (see the plan-link above); should be upgraded to a proper
  fix plan only once the empirical-SD-vs-reported-SE check confirms the
  hypothesis for at least one class (or finds the real cause), and should
  be treated as a potential cross-class SE-quality audit, not a
  single-class fix.

  **Tension to note 2026-09-23**: this "broadened" reasoning partly leaned
  on this TODO's original ~4× SE-overestimation number for
  `InferenceIncidKKModifiedPoisson`, which the direct empirical-SD check
  above did NOT confirm (found 1.23×, not ~4×). The studentized-BRT-pivot
  code trace is still valid on its own (the shared dispatch/pivot code is
  clean), so "per-class SE-estimator quality, not shared-code bug" remains
  the best-supported explanation for the studentized-pivot miscalibration
  specifically — but it should no longer be read as cross-confirmed by
  this TODO's own original finding, since that finding didn't hold up.
  Treat the two threads (studentized-pivot class-dependence; this TODO's
  Wald-family zero-rejection) as separately-motivated, not mutually
  reinforcing, until at least one is confirmed with a faithful harness
  replay.

  **Implementation status 2026-10-09:** a faithful 200-replicate Pima/
  KK21stepwise replay refuted the SE hypothesis (empirical SD 0.19318,
  mean robust SE 0.19870, ratio 1.0286; MC-truth coverage 0.955). The real
  defect was API capability: a binary modified-Poisson sandwich estimator
  exposed score, gradient, LR, Bartlett and parametric-bootstrap tests from
  its Poisson working likelihood. The concrete class and registry now expose
  robust Wald inference only; dead likelihood specification/simulation code
  and stale capability baselines were removed. Focused sandwich, capability,
  likelihood-baseline, hardening, migration and registry checks pass 1,113
  assertions with one pre-existing quarantine skip. Only installed
  comprehensive CSV regeneration/re-audit remains, so this item stays
  unchecked.
  **Installed migration-golden recheck 2026-10-16:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-incid-kk-modified-poisson-migration-golden.R", package = "EDI")`
  passed all 35 assertions against installed EDI 1.0.3 with no warnings or
  skips. This confirms the installed migration/capability contract but does
  not close the comprehensive-CSV regeneration/re-audit gate or validate a
  newer checkout/native pair.
  **Fresh checkout-R/current-native migration rerun, 2026-10-20:**
  `test-incid-kk-modified-poisson-migration-golden.R` passed all 35 assertions
  with `pkgload::load_all("R/EDI", compile = FALSE)` against the user's
  freshly rebuilt native DLL (SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`). This
  revalidates the current R migration/capability contract only; the complete
  incidence comprehensive-row regeneration and exact-key audit remain open.
  - [ ] After a provenance-pinned post-fix package is installed, regenerate
    and reconcile the `InferenceIncidKKModifiedPoisson` comprehensive rows:
    unsupported score/gradient/LR/Bartlett/parametric-bootstrap rows must be
    absent and the supported Wald rows must remain. Record exact result keys
    and package/DLL provenance before re-auditing.
  - **Limited pilot, 2026-10-20 (not the release gate):** the current R source
    was loaded with `pkgload::load_all(..., compile = FALSE)` against the
    user-rebuilt native DLL (SHA-256
    `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`).
    One `pima` / `KK21stepwise` / `beta_T=0` / Wald runner cell emitted 8
    `ok` rows covering the four model/design-formula combinations. The CSV is
    in `/tmp/edi-v105-todo19-current-DgbXhW/`; this source-overlay smoke run
    neither audits historical keys nor proves absent unsupported rows, so the
    checkbox above remains open pending full installed-package regeneration
    and reconciliation.
  - **Installed-package regression, 2026-10-20:** the reinstalled EDI 1.0.3
    package passed `test-incid-kk-modified-poisson-migration-golden.R` (35
    assertions) via `library(EDI)` with no checkout-R overlay. Its installed
    `EDI.so` SHA-256 matched the checkout DLL above. This validates the focused
    migration/capability contract on the installed package; it still does not
    audit comprehensive result keys or unsupported-row absence.
  - **Installed comprehensive pilot, 2026-10-20:** direct `Rscript` execution
    of `R/package_tests/comprehensive_tests.R` against installed EDI 1.0.3 for
    `pima` / `KK21stepwise` / `beta_T=0` / rep 1, with all method families
    selected and narrow mode, emitted 64 rows (16 distinct calls across four
    formula combinations), all `ok`. Asymptotic/Wald calls remained; no score,
    gradient, likelihood-ratio, Bartlett, or parametric-bootstrap rows were
    emitted. Slow methods skipped by narrow mode are not covered by this
    pilot. CSV: `/tmp/edi-v105-todo19-current-DgbXhW/`;
    SHA-256 `42308b5901487f4e3e842c8153fad697762b9503a279a3b54d7c51e6ab6bb3c2`.
    This is one representative cell, not the full exact-key reconciliation,
    so the release checkbox remains open.
  **Pilot exact-key subset audit, 2026-10-20:** the 64-row all-family CSV
  contains 64 unique `id`s, all `ok`, across four class/formula labels. Its
  eight Wald rows have exactly the same `id` set and non-telemetry fields as
  the separate eight-row Wald-only pilot; only timestamps, durations, epochs,
  heartbeat, and `run_row_id` differ. This reconciles the isolated pilot
  subset, not the full supported-incidence matrix, and does not establish
  package provenance or normal-mode absence of every unsupported family.
  **Source-roster cross-check, 2026-10-21:** a bounded parse of this artifact
  confirms 16 rows for each of its four formula pairs (`model_formula` ×
  `design_formula` in `{~1, ~.}`), each with a distinct `function_run`:
  estimate; asymptotic p-value/CI; Wald p-value/CI; jackknife estimate and
  Wald p-value/CI; randomization p-value at default and `delta=0.5`; and
  Bayesian-bootstrap p-value (default, symmetric, Wald) and CI (default,
  basic, Wald). All 64 IDs are unique and `status=ok`; the eight Wald-family
  IDs equal those in the co-located Wald-only pilot. This verifies only the
  observed pilot keys against the runner's operation set. It is still one
  dataset/design/beta/replicate and has no EDI DLL hash, so the source-derived
  430,080-row candidate roster is unverified against a full post-fix result.
  The estimated 21.2-hour/318-MiB class-filtered run remains the only
  identified closure path, pending adequate isolated-disk headroom and
  provenance.
  The installed migration golden was rerun with
  `testthat::test_file(..., package = "EDI")` and passed 35 assertions against
  EDI 1.0.3 (DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`).
  Full provenance-pinned installed regeneration and exact-key reconciliation
  remain the release gate; no canonical output was changed.
  **Latest installed migration-golden recheck, 2026-10-21:**
  `test-incid-kk-modified-poisson-migration-golden.R` passed all 35
  expectations against installed EDI 1.0.3 with no failures, warnings, or
  skips. Loaded `EDI.so` SHA-256 was
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This confirms the installed migration/capability contract only; it does
  not close the full comprehensive-row regeneration/reconciliation gate.
- [x] TODO-20 (CLOSED 2026-10-21 by owner decision: not reproducible; added 2026-09-23, same audit-triage wave; original
  `fit_warm_keep` hypothesis **REFUTED 2026-09-23 by direct code trace,
  high confidence** — new alternative lead, medium confidence, not yet
  reproduced; tracked as an open investigation, not a fix plan, in
  `bug_fix_plans/investigate_contin_quantile_regr_bootstrap_family_inflation.md`):
  `InferenceContinQuantileRegr` shows CONSISTENT-direction
  (not mixed, unlike TODO-19) severe Type-I error inflation across
  multiple bootstrap-family p-value methods
  (`compute_rand_bootstrap_two_sided_pval` 0.185 vs. nominal 0.05,
  studentized ~0.285) while its plain `compute_rand_two_sided_pval` looks
  fine (0.061, near nominal) — the problem is specific to the
  bootstrap-family resampling path, not this class's estimator generally.

  **Refuted**: the `private$fit_warm_keep` warm-start reuse path
  (`inference_continuous_quantile_regr.R:218-225`) only activates when
  `reuse_factorizations = TRUE`
  (`get_ci_fit_controls()`, `:208-214`, reads
  `private$randomization_mc_control$fit_reuse_factorizations`).
  Exhaustively traced every site that sets `randomization_mc_control`
  across `R/EDI/R/*.R`: it defaults to `NULL`
  (`inference_all_abstract_rand.R:350`) and is populated **only** inside
  CI-search/bisection (`inference_all_abstract_rand_ci.R:279-280`,
  `:403`), restored via `on.exit` afterward. A standalone
  `compute_rand_bootstrap_two_sided_pval()` call — the flagged method, not
  a CI computation — never touches this code path, so the `fit_warm_keep`
  branch never executes for the flagged methods. Not a stale-cache bug.

  **New alternative lead (medium confidence, code-reading only, not yet
  reproduced)**: BRT draws are generated by `bootstrap_sample_indices()`
  (`inference_all_abstract_rand_bootstrap.R:662`) — confirmed a
  **with-replacement** row-index draw (duplicating rows), not a
  permutation (which reshuffles treatment labels on the same n distinct
  rows, never duplicating). `quantreg::rq()`'s simplex ("br") method and
  its Powell-style sandwich SE are both known in the quantile-regression
  literature to be numerically sensitive to exact row/response ties — a
  with-replacement bootstrap manufactures ties directly. This would
  explain the exact fine/broken split observed (permutation fine,
  every bootstrap-family variant broken) without any code defect —
  possibly a genuine statistical instability, not a bug. Next step:
  construct a true-null fixture, draw several BRT resamples, and check
  whether the resampled design's tie/duplication pattern correlates with
  unstable/biased `beta_hat_T`/SE, using `InferenceContinOLS`/
  `InferenceContinRobustRegr` (non-tie-sensitive estimators) as a negative
  control. May turn out not to be a "fixable" code defect at all (the
  eventual writeup might be "document BRT isn't recommended for
  quantile-regression classes" or "add a tie-breaking jitter before
  refitting," not a simple correction) — don't assume a fix is possible
  before this reproduction step. Possibly related in kind (not
  mechanism) to TODO-21's GEE-sandwich-SE-under-cluster-bootstrap
  question — both are "asymptotic-SE-based methods whose variance
  estimator has known finite-sample fragility under resampling," worth
  checking whether they're two instances of one broader category once
  both are reproduced. An installed-package pilot on 2026-10-14 (`n=60`,
  `model_formula = ~1`, 25 null replicates, `B=99`) did not reproduce the
  historical inflation: quantile plain-randomization rejected 1/25, BRT
  percentile and studentized each 0/25, while OLS BRT rejected 2/25. Actual
  BRT draws contained duplicated rows and yielded finite quantile fits, but
  tie-count correlation was not established. **Matched-draw extension
  2026-10-14:** 50 installed-package sharp-null cases, 12 actual BRT draws per
  case, and the same 600 materialized draws per estimator for Quantile, OLS,
  and RobustRegr. All 600/600 estimates and positive SEs per estimator were
  finite; draws had median 22 duplicated rows and 72 tied-response pairs.
  Within-case median Spearman correlations (duplicate rows vs. log(SE)) were
  -0.055, -0.021, -0.080 for Quantile/OLS/RobustRegr; versus absolute
  studentized statistic they were 0.027, 0.053, 0.074. Quantile showed no
  excess instability or tie association relative to controls. Since 12 draws
  imply a two-sided p-value floor of 2/12, this is a draw-level diagnostic,
  not a Type-I-error test; the fixture also differs from the historical
  comprehensive-test DGP. Details and denominators are in
  `../bug_fix_plans/investigate_contin_quantile_regr_bootstrap_family_inflation.md`.
  **Installed direct-reference recheck 2026-10-20:**
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-continuous-quantile-regr-reference-and-weighted-refit.R")'`
  passed 14 assertions against EDI 1.0.3, covering independent unweighted and
  weighted `quantreg::rq` references plus rank-deficient/insufficient-df
  guards. It does not exercise the historical `~.` DGP or BRT p-value path,
  and provides no Type-I-error replication or root-cause evidence. The exact
  historical dataset/design/DGP/seed schedule remains unrecovered, so this
  installed-package check does not dismiss or reproduce the 428-row finding.
  **Aggregate reconciliation, 2026-10-20:** the checked-in audit baseline has
  two distinct 428-row Quantile BRT cells. Its `~.` rows at
  `R/package_tests/comprehensive_results_audit_baseline.csv:1137-1139` report
  rejection rates 0.185 (ordinary), 0.285 (studentized), and 0.294
  (symmetric-percentile-t), matching this plan's finding. Separate `~1` rows
  at `:1153-1155` report 0.033 (ordinary), 0.047 (studentized), and 0.065
  (smoothed); they are not the rows summarized by the plan. This resolves the
  apparent formula-label discrepancy in favor of the existing `~.` target;
  do not relabel either cell. The aggregate still lacks per-row dataset,
  design, seed, and DGP provenance, so it does not recover the exact
  historical run or establish a cause. No replay or correction to canonical
  results is claimed. The linked plan now pins the inspected aggregate
  baseline's SHA-256 and Git source commit and distinguishes the retained
  50-case/12-draw TODO-20 pilot artifacts from that historical aggregate.
  At this 2026-10-20 audit checkpoint, TODO-20 remained open without a fix or
  dismissal of the historical finding; the owner later closed it as not
  reproducible on 2026-10-21, as recorded above.
  **Simulation redo, owner-requested:** Fresh 300-rep true-null simulation 2026-10-21 (Pima, n=120, tied and jittered glucose, ~1 and ~bmi+age, rand and three BRT variants): all 16 rejection rates 0.027-0.073, no tie effect; historical 0.185/0.285 NOT reproduced. Details in the linked investigation. **Owner decision 2026-10-21: closed as not reproducible.**
  **Tie-sensitivity evidence reconciliation, 2026-10-21:** the tracked
  audit-baseline target is specifically `model_formula=~.`: its 428 beta_T=0
  rows report rejection rates 0.185 (ordinary BRT), 0.285 (studentized), and
  0.294 (symmetric-percentile-t). The distinct `~1` cells are 0.033/0.047/0.065;
  this resolves the formula-label ambiguity but not the anomaly's source. The
  2026-10-14 retained pilot (`/tmp/edi-v105-todo20/same_draws.csv`, SHA-256
  `9e119ac4cf6e35b82ab52d8842f3b9bb95e426ed9a067678f3d37560c186a398`, plus
  summary `e78612509a57e2fcf7292d577ff4a2fcfdd5788388b1a08187f5753d74184c62`)
  is 50 cases × 12 shared BRT draws across Quantile/OLS/RobustRegr on an
  exploratory `~1` fixture. All 600 fits/SEs per estimator were finite and
  within-case duplicate/tie correlations were near zero; with only 12 draws,
  this is a fit/tie diagnostic, not a calibrated p-value or Type-I-error
  comparison. The 2026-10-21 300-replicate tied-vs-jittered Pima run also uses
  another dataset/design/formula set and B=101; its rates 0.027–0.073 with no
  tie effect do not reproduce the historical `~.` cell. The 14-assertion
  direct/weighted `quantreg::rq` reference test validates point-fit paths, not
  the three BRT p-value methods or their coverage. The baseline is pinned
  (SHA-256 `6daf9c3d6caff7bd09a65afef066de818e53dbe7d7e15b0a9b1dddac321cf125`,
  commit `11f61e0a0dfa08b36c893cd7e9ced783662e9248`), but it is aggregate-only:
  no exact historical dataset/design/DGP/seed-level rows are retained. Thus
  confirmed without a new simulation: the candidate mechanism is with-
  replacement BRT duplication/tie sensitivity (the separate `fit_warm_keep`
  lead is refuted), the formula target is `~.`, and the existing pilots do
  not support a Quantile-specific tie effect on their own fixtures. Historical
  replay, calibrated coverage, and any causal disposition remain gated on
  recovering the exact inputs and predeclaring case/draw counts, calibration
  decision rules, multiplicity, estimator-parity tolerances, and tie-association
  threshold. Do not substitute TODO-49's separate confidence-interval coverage
  findings or `quantreg` SE discussion for this BRT p-value replay gate. No new
  simulation, build, test run, or canonical output was made.
- [x] TODO-21 (CLOSED 2026-10-21 by owner decision: historical inflation not reproducible; the separate 2026-10-20 scalar-resampling kernel defect stays on its own validation; added 2026-09-23, same audit-triage wave; pair-vs-singleton
  grouping hypothesis **REFUTED 2026-09-23 by code trace AND direct
  reproduction, with a separate scalar-resampling defect found 2026-10-20**.
  The historical inflation claim was not reproduced and is closed by the
  recorded owner decision; the missing original input limits independent
  historical replay, but does not block that disposition. The separate
  scalar-resampling fix still has its own native-provenance gate. Details in
  `bug_fix_plans/investigate_incid_kk_gee_bootstrap_family_inflation.md`:
  `InferenceIncidKKGEE` shows the same consistent-direction
  bootstrap-family inflation shape as TODO-20
  (`compute_bayesian_bootstrap_two_sided_pval_wald` 0.314,
  `compute_bayesian_bootstrap_two_sided_pval` 0.306,
  `compute_rand_bootstrap_two_sided_pval_symmetric-percentile-t` 0.185 —
  all vs. nominal 0.05, from historical `comprehensive_tests` CSV rows).

  **Pair-grouping hypothesis refuted**: read the full chain —
  `design_matching_abstract.R:55-114` (separates reservoir-singleton
  indices from matched-pair row pairs, both cached in
  `init_matching_bootstrap_structure()`) and
  `bootstrap_match_indices.cpp:92-130`
  (`draw_matching_bootstrap_sample_cpp`, the actual C++ resampler). Matched
  pairs are preserved intact and receive fresh relabeled pair IDs. **New
  source finding (2026-10-20):** direct R semantics show that
  `sample(c(7L), size=4, replace=TRUE)` samples from `1:7`, not from the
  singleton row index. The kernel used this form for reservoir indices. A
  focused regression exposed the defect (4/4 sampled indices were not 7);
  the checkout C++ source now samples positions and maps back to row indices.
  The focused test against installed EDI 1.0.3 therefore fails on the old
  native artifact. No native rebuild was run, so the source fix is not yet
  validated. This finding does not establish that it caused the historical
  .306/.314/.185 rates.

  **Direct reproduction could NOT reproduce the historical inflation
  either**: a fresh true-null `InferenceIncidKKGEE` fixture
  (`DesignSeqOneByOneKK14`, `pkgload`, no compilation) gave
  `compute_bayesian_bootstrap_two_sided_pval(type="wald")` = **0.050**
  (n=100, B=200, 40 reps — exactly nominal) and the default variant =
  **0.025** (mildly conservative). A second, smaller check (n=60, B=100,
  25 reps) gave 0/25 rejections — consistent with nominal/conservative,
  not inflated. Neither run is remotely close to the historical
  0.306-0.314.

  **Historical replay limitation (not a blocker to the recorded closure)**:
  the reproduction fixture used a
  single simple covariate and default settings, while the flagged
  historical rows were at `model_formula=~1` AND `~.` (both flagged,
  different rates) on whatever specific dataset the harness used for
  this class — the same shape as the already-CONFIRMED `InferenceContinLin`
  bug, where `~1` vs `~.` on one specific real dataset with near-collinear
  covariates was the actual trigger, not a generic class property. The
  concrete next step, if this is picked up again, is reproducing with the
  *exact* dataset/design/formula combination from the flagged historical
  CSV rows, not a fresh simplified fixture — this investigation did not
  do that. Also not checked: whether the other three `KKGEE`-family
  classes (`InferenceCountPoissonKKGEE`, `InferenceOrdinalKKGEE`,
  `InferencePropKKGEE`) show the same historical pattern.

  **Recorded disposition**: the 2026-10-21 owner decision closes the
  historical-inflation claim as not reproducible on the available evidence.
  The original trigger remains unverified because the stamped input is
  unavailable; this limits historical attribution but does not leave TODO-21
  open. If the investigation is reopened, recover the stamped input or an
  owner-approved equivalent with dataset, design, both formulas, DGP, seed
  schedule, commit/runtime, denominator, and pooling rules before replaying
  the flagged rates or checking the three KKGEE siblings. Keep that optional
  historical replay separate from validation of the scalar-resampling fix.
  **Independent resampling-invariant check, 2026-10-20:** the focused
  `test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R`
  passed 1,216 expectations against installed EDI 1.0.3. Its 200-draw fixture
  verifies reservoir singleton sampling and intact matched-pair resampling
  with fresh pair IDs. This supports the already-refuted singleton-handling
  hypothesis only; it does not replay the historical KKGEE rates or supply
  current-checkout native provenance. The exact stamped historical input (or
  an owner-approved equivalent preserving dataset, design, both formulae,
  DGP, seeds, runtime, denominator, and pooling rule) is still required.
  No historical CSV, broad simulation, or canonical output was read or
  written.
  **Current installed-artifact singleton regression recheck, 2026-10-20:**
  the same focused test passed 1,216 expectations with 0 failures, warnings,
  or skips against installed EDI 1.0.3. The loaded `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` matches
  checkout `R/EDI/src/EDI.so` byte-for-byte. It validates the singleton-index
  resampling fix plus intact-pair/RNG invariants in the available artifact;
  the hash match does not provide a build manifest. It does not reproduce or
  attribute the historical rates. The stamped input and complete DGP, seeds,
  denominator, and pooling provenance remain the blocker; no build/install,
  simulation, historical CSV, or canonical output was used.
  **Additional focused installed-package validation, 2026-10-20:**
  `test-compute-bootstrap-matching-stats-kernel-reservoir-pairs-and-column-pruning-reference.R`
  passed 342 expectations (0 failures/warnings/skips; exit 0) against EDI
  1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`.
  Loaded DLL: `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  MD5 `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  Checkout HEAD when recorded: `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  This tests the installed artifact, not the checkout's native library, and
  does not establish or attribute the historical .306/.314/.185 rates. Their
  stamped raw input, DGP, seeds, denominator, and pooling rule remain missing;
  keep the historical-attribution gate open.
  **Current installed-artifact regression recheck, 2026-10-20:** the focused
  `test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R`
  passed 1,225 expectations across seven test blocks (0 failures, warnings,
  or skips) against installed EDI 1.0.3. Command:
  `Rscript -e 'cat("R:", R.version.string, "\nEDI:", as.character(utils::packageVersion("EDI")), "\npath:", find.package("EDI"), "\n"); testthat::test_file("R/package_tests/testthat_bulk/test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R", reporter="summary")'`.
  R was `R Under development (unstable) (2026-10-13 r90668)`; package path
  was `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The installed
  `libs/EDI.so` SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to checkout `R/EDI/src/EDI.so`. This newer run preserves the
  earlier 1,216-expectation record above; neither run provides a build
  manifest or reproduces/attributes the historical inflation. The stamped
  input and complete DGP, seeds, denominator, and pooling provenance remain
  the historical-attribution blocker. No build/install, broad simulation,
  historical CSV, or canonical output was used.
  **Checkout-R-source overlay recheck, 2026-10-20:** after
  `pkgload::load_all("R/EDI", compile=FALSE, quiet=TRUE)`, the same focused
  match-stat/reservoir test passed 1,225 expectations in seven blocks (0
  failures/warnings/skips), with R Under development (2026-10-13 r90668), EDI
  1.0.3, and namespace source path `/home/kapelner/workspace/EDI/R/EDI`.
  Loaded existing DLL MD5: `8b3ca30492d7b1c790deeebe94b201ad`. This is
  checkout-R-source evidence only; it does not validate the modified checkout
  C++ fix or reproduce/attribute `.306/.314/.185`. The stamped historical
  input and full DGP, seed/RNG state, denominator, and pooling provenance (or
  maintainer-approved equivalent) remain open. No build/install, simulation,
  historical CSV, or canonical output was used.
  **Retained-input provenance recheck, 2026-10-20:** the 403-byte workspace
  audit stamp (SHA-256
  `ea3dd4ef6872c4a7e398fb20469ba438ed59d6f781bfe684811adf7b05a93b70`)
  records only response-CSV names/sizes/mtime epochs; its incidence entry
  expects 561,975,056 bytes at epoch `1790497128`. Metadata-only filename
  checks found the current full CSV (525,863,531 bytes), older same-name
  copies (525,208,409 and 27,124,848 bytes), and an identical copy of the
  current file; none matches the stamp. No class-filtered historical
  `InferenceIncidKKGEE` CSV or approved replacement manifest was found. The
  1,225-expectation source-overlay test is resampling-mechanics evidence, not
  empirical reproduction of the historical rates. Details are in the linked
  plan. No large CSV, R process, simulation, or canonical output was used.
  **Simulation redo, owner-requested:** Fresh 300-rep true-null simulation 2026-10-21 (Pima, n=148, KK21stepwise, ~1 and ~bmi+age, BB default/Wald and three BRT variants): rejection rates 0.043-0.067 at 0.05; historical .306/.314/.185 NOT reproduced. Details in the linked investigation. **Owner decision 2026-10-21: closed as not reproducible; the scalar-resampling kernel defect stays on its own validation.**
  **Paired/singleton evidence reconciliation, 2026-10-21:** the focused
  `test-matching-bootstrap-draw-grouping-and-match-stats-kernels-reference.R`
  was rerun against installed EDI 1.0.3 and passed with no failures, warnings,
  or skips. Its singleton fixture requires a sole reservoir row (`7`) to be
  repeated, leaves the matched pair `[1,2]` intact with a fresh pair ID, and
  the seeded reference checks preserve multi-row reservoir order/RNG state.
  The loaded DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94` matches
  checkout `R/EDI/src/EDI.so`; its 2026-10-21 00:56 +0300 mtime is after the
  modified C++ source's 2026-10-20 04:57 +0300 mtime, but no build manifest
  proves the source revision. This current installed behavior supports the
  separate scalar singleton-index fix and the structural claim that pairs
  stay intact; the tests measure neither Type-I error/coverage nor runtime
  performance. No retained artifact supplies a paired-vs-singleton timing
  comparison. The 300-replicate Pima result is a statistical calibration
  sample on a replacement fixture, not performance data or a replay of the
  missing historical run. The only TODO-21-named `/tmp` CSV is a 298-byte
  header with no attempt rows; the stamped historical CSV (561,975,056 bytes)
  remains absent, and the tracked aggregate does not reproduce .306/.314/.185.
  Thus grouping itself is refuted and current singleton mechanics pass the
  installed regression, while historical inflation attribution/closure still
  requires that stamped input or the maintainer's explicit disposition. No
  benchmark, simulation, historical CSV, build, install, or canonical output
  was performed for this recheck.
- [x] TODO-22 (added 2026-09-23/24, found and fixed by a separate session
  working concurrently in this repo — not this file's own investigation;
  recorded here at user request so it has a release home): **KK survival
  compound classes silently fed real `NA`s into the fitter for censored
  subjects during randomization inference** —
  `InferenceSurvivalKKLWACoxPHOneLik` (the original discovery site) and
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`/`...IVWC` (found to
  share the identical buggy snippet the same day). Root cause:
  `compute_treatment_estimate_during_randomization_inference()` re-read
  `y`/`dead` from `private$des_obj_priv_int$y` directly and derived
  `dead = as.numeric(!is.na(y))` — but post the `y`/`y_L`/`y_R` migration,
  the `Design` object's own `y` field uses `NA` to encode a *censored*
  observation (the true bound lives in `y_L`/`y_R` instead), not a missing
  value, so every censored subject's response was silently replaced with a
  real `NA` fed straight into the fitter on every randomization-inference
  call. Found via a before/after randomization-pval contrast on simulated
  data with a strong known effect: `0.02` (correct) with no censoring vs.
  `0.97` (silently wrong, not even an error) with ~20% censoring on
  otherwise identical data. **Fixed**, confirmed present in the installed
  source for all three classes named above: `y`/`dead` are now re-derived
  the same way `Design$get_effective_time()`/`$get_effective_dead()` do,
  matching `InferenceAll`'s own `initialize()` exactly. Not independently
  re-verified by this file's original investigation. **Independently
  re-verified 2026-10-07** with the focused effective-time/dead and
  randomization-refit tests against the source checkout.

  **Follow-up sweep completed 2026-09-23/24 — no other class affected,
  closed**: checked every `inference_survival_*.R` file's own
  `compute_treatment_estimate_during_randomization_inference()`/`shared()`/
  `generate_mod()` override (16 files) for whether it re-reads raw
  `des_obj_priv_int$y`/`$dead` instead of the already-correct
  `private$y`/`private$dead` set once by `Inference$initialize()`
  (`inference_all_abstract.R:92`: `private$y = if
  (private$has_general_censoring) des_obj$get_y() else
  des_obj$get_effective_time()`). Every class besides the three already
  named above — `inference_survival_coxph.R`, `inference_survival_strat_cox.R`,
  `inference_survival_KK_strat_cox.R` (flows through the base
  `InferenceRand`/`StandardModelCache` generic, which just calls
  `self$compute_estimate()`/`private$shared()`), `inference_survival_weibull.R`,
  `inference_survival_dep_cens_transform.R`,
  `inference_survival_KK_weibull_marginal.R`,
  `inference_survival_KK_lwa_cox_ivwc_abstract.R` — reads `private$y`/
  `private$dead` directly, never the raw design field. A 4th site with the
  buggy re-derivation pattern was found and confirmed already fixed while
  sweeping (`InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`,
  `inference_survival_GLMM_weibull_frailty_normal.R` — same fix comment/
  pattern as the other three). No unfixed occurrences remain. This TODO is
  now fully closed.

  **Unrelated tangent noticed while sweeping, checked and closed
  2026-09-24**: `inference_survival_KK_lwa_cox_ivwc_abstract.R`'s `shared()`
  (lines ~109-138) has the same *shape* as TODO-14's estimate-only-NA-
  pooling bug (unconditional `w_star = ssq_r / (ssq_r + ssq_m)`
  inverse-variance pooling), which `../bug_fix_plans/glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md`'s
  TODO-2 sweep hadn't explicitly checked for this IVWC class (only its
  `...OneLik` sibling). Code-read first: unlike the Weibull-frailty case,
  this class's `fit_cox_model()` (`:205-221`) calls
  `fast_coxph_regression_cpp()` with no `estimate_only` argument at all and
  always computes `se`/`ssq` from `res$vcov`, regardless of the outer
  `shared(estimate_only=...)` value — so `ssq_m`/`ssq_r` are never
  deliberately `NA` the way the Weibull-frailty helpers make them. **Direct
  behavioral confirmation**, using the golden fixture from
  `test-survival-kk-lwa-cox-ivwc-migration-golden.R`
  (`DesignSeqOneByOneKK14`, sequential KK assignment,
  `InferenceSurvivalKKLWACoxPHIVWC`), via `pkgload::load_all(".", compile =
  FALSE)`: `compute_estimate(estimate_only = TRUE)` vs. `FALSE` gave
  bit-identical, finite results on 6 independent fixtures (n=24 seed 20260817,
  plus n=40 seeds 1-5; e.g. `0.8151751` / `0.8151751`, `0.9487012` /
  `0.9487012`, `-0.4883716` / `-0.4883716`) — no NA under `estimate_only`
  anywhere. **Confirmed NOT affected; no action needed.**
- [ ] TODO-23 (added 2026-09-24, surfaced by the new `low_coverage` audit
  check — two-sided exact-binomial test, H0: coverage=0.95 — root-caused
  same day, high confidence): **`InferenceSurvivalRestrictedMeanDiff`
  computes RMST to a different truncation horizon τ per treatment arm** —
  `../bug_fix_plans/rmst_mismatched_truncation_horizon.md → TODO-1..7`. Near-universal
  severe undercoverage (0.53-0.65, target 0.95) across almost every CI
  method family this class supports. Root cause, confirmed at three code
  sites (`inference_survival_rmst.R:239`,
  `fast_survival_stats.cpp:158`/`:290`/`:400`): τ is derived independently
  per arm as that arm's own max observed/censored time, when the RMST
  literature requires a shared τ across arms for the difference to be a
  coherent estimand. Two consequences: the point estimate itself may not
  estimate a single well-defined quantity, AND the classical Greenwood-
  based SE (assumes fixed τ) structurally under-estimates sampling
  variance since τ varies per bootstrap draw — either alone would produce
  the observed undercoverage. Fix is a scoped 3-site code change (shared
  τ, conventionally the min of both arms' max time), not a redesign, but
  is an intentional, documented DEFAULT CHANGE to the point estimate for
  mismatched-follow-up cases (not bit-for-bit preserving, unlike most of
  this session's other fixes). A second, narrower, unconfirmed finding
  (`InferenceSurvivalDepCensTransformRegr`, one isolated method
  undercovering, not class-wide) is tracked in the same plan file
  (TODO-8/9), separate mechanism, low confidence, not yet root-caused.
  Independent of every other item in this release; depends on nothing
  else. **Source implementation 2026-10-08:** all RMST-difference paths now
  derive one shared horizon, the minimum of the two arm-level maxima,
  including the R weighted-bootstrap, native/portable point-estimate,
  Greenwood SE-difference, and randomization-bootstrap paths; single-group
  exported helpers retain their own-arm horizon. Focused common-horizon
  references and source-loaded weighted checks passed. **Installed-package
  recheck 2026-10-14:** despite the installed package identifying as 1.0.3,
  the shared-horizon weighted reference passed 4 assertions; the
  C++-kernel/randomization reference passed 17; the asymptotic/general-
  censoring reference passed 18; the weighted/fallback reference passed 12;
  and the independent `survfit` group/difference Greenwood reference passed
  52. No Codex compile/build/install was run. **Same-HEAD CI validation
  2026-10-16:** R bulk run `38808821543` built/installed HEAD
  `430c19bcdb0702d998c79f9058c449449034134c` in an isolated CI library and
  passed all five correctness shards. The correctness manifest includes the
  focused RMST shared-horizon, native-kernel/randomization, Greenwood
  `survfit`, weighted/fallback, and general-censoring tests. This confirms
  same-HEAD native compile/runtime behavior without a local build, but does not
  satisfy linked TODO-3's literal targeted-only compile criterion; keep that
  checkbox open unless the criterion is explicitly waived in favor of CI.
  TODO-5's broad coverage calibration and TODO-7's installed
  comprehensive-results regeneration also remain open, so this release item
  stays unchecked.
  **Post-HEAD installed-native recheck, 2026-10-20:**
  `test-rmst-se-mean-diff-kernel-and-complete-randomization-draw-kernels-reference.R`
  passed 17 assertions with 0 failures, warnings, or skips against installed
  EDI 1.0.3. The installed `EDI.so` SHA-256 is
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`; its
  embedded build timestamp is `2026-10-19 23:31:50 IDT` (mtime
  `23:47:15 IDT`), after checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (`21:03:16 IDT`). The changed
  native source, R helper, and test file are clean at HEAD. This supports
  focused runtime validation of the user's reported post-HEAD reinstall, but
  the package embeds no Git SHA; exact-source artifact provenance is still
  insufficient for linked TODO-3. TODO-5 calibration and TODO-7 regeneration
  remain open. No build/install, snapshot, or canonical output write was done.
  **Checkout-R source overlay, 2026-10-20:** reran
  `test-rmst-se-mean-diff-kernel-and-complete-randomization-draw-kernels-reference.R`
  (17 assertions) after `pkgload::load_all("R/EDI", compile = FALSE,
  quiet = TRUE)`; all passed with 0 failures, warnings, or skips. EDI reported
  version 1.0.3 and loaded a temporary copy of the existing installed native
  DLL. The installed DLL SHA-256 is
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`
  (mtime `2026-10-19 23:47:15 +0300`). The relevant R helper, native source,
  and test are clean at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  This is focused checkout-R/installed-native runtime evidence, not proof
  that the DLL was built from exact HEAD; the package embeds no Git SHA. It
  does not close TODO-3's provenance gate, TODO-5's calibration, or TODO-7's
  comprehensive regeneration. No build/install or canonical output write.
  **Installed R-helper edge recheck, 2026-10-20:** the shared-horizon test
  also covers an all-censored control arm and passed all 8 expectations
  against installed EDI 1.0.3 (0 failures, warnings, or skips). The
  `survival::survfit` reference confirms the all-censored arm's RMST is the
  shared `tau`, and the R weighted-difference helper matches the reference
  contrast. Installed `EDI.so` SHA-256 is
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (mtime `2026-10-20 09:38:02 +0300`); checkout HEAD is
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This validates the installed R
  helper only, not native-kernel behavior. A read-only `cmp` found the
  installed DLL byte-identical to the ignored checkout artifact
  `R/EDI/src/EDI.so` (same SHA-256 above; `cmp` exit 0). This establishes
  binary equality to the local artifact, but the ignored `.so` has no embedded
  build manifest/Git SHA, so its tracked-source build revision is not
  authenticated and the exact-source/native gate remains open. No
  build/install or canonical output write; TODO-3/5/7 remain open.
  **Latest installed-native recheck, 2026-10-20:** the user's later reinstall
  resolves to EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` under R-devel
  `r90668`; loaded `EDI.so` SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  (mtime `2026-10-20 10:40:08 +0300`). With that installed package attached,
  `test-rmst-se-mean-diff-kernel-and-complete-randomization-draw-kernels-reference.R`
  passed 17 expectations with no failures, warnings, or skips. The relevant
  tracked native/R/test files remain clean at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but the package and DLL do not
  embed a Git SHA, so this current runtime check still cannot authenticate the
  binary against exact HEAD. TODO-3 provenance, TODO-5 calibration, and TODO-7
  regeneration remain open. No build/install or canonical output write.
  **Coverage-accounting audit, 2026-10-20:** the linked plan's BCa diagnostic
  reports both finite-only rates (33/35 and 34/36) and all-replication rates
  after counting invalid intervals as noncoverage (33/120 and 34/120). The
  generic `SimulationFrameworkReport` does not implement that policy: its
  finite-calibration test uses five CI rows, excludes two non-finite intervals,
  and reports `n_cov=3`, coverage 2/3, with the binomial denominator 3. Existing
  RMST tests verify estimates, intervals, and fallback routing on fixed
  fixtures, not empirical coverage classification. No RMST calibration raw
  rows or driver were found in the targeted `/tmp` filename audit, so the
  stored tabulation is not independently reproducible from retained artifacts.
  Use an explicit all-replication denominator and record invalid counts in
  TODO-5 acceptance; no calibration was run.
  **Checkout-R source-overlay recheck, 2026-10-20:** ran the existing
  `test-simulation-report-finite-calibration-reference.R` after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; it passed with
  no failures. Runtime was R Under development (2026-10-13 r90668), EDI 1.0.3,
  checkout namespace `/home/kapelner/workspace/EDI/R/EDI`; temporary loaded
  DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This is focused checkout-R/installed-native evidence for the generic
  report's finite-only denominator, not all-attempts RMST calibration or a
  regenerated empirical result. TODO-5 calibration and TODO-7 row regeneration
  remain open. No build/install, simulation, or canonical output write.
  **One-key pilot preflight, 2026-10-20 (not run):** selected exact current
  manifest key `rep=1, beta_T=0, dataset=diamonds, response=survival,
  design=Bernoulli, design_formula=~1,
  InferenceSurvivalRestrictedMeanDiff [design_formula=~1],
  compute_wald_confidence_interval`. The `/tmp` runbook is
  `/tmp/edi-todo23-rmst-pilot-preflight-20261020.md`. The runner has no
  formula selector, so its one-rep `wald` invocation also emits the companion
  `~.` branch and any other wald-family attempts; preserve all rows/statuses,
  including invalid intervals. This was a bounded row-retention diagnostic,
  not a coverage estimate; no R process or output had been created at preflight
  time while the R slot was reserved. TODO-5 remains open for its multi-method
  120-rep study, all-attempts denominator, and owner-approved
  precision/acceptance criteria.
  **Completed isolated diagnostic pilot, 2026-10-20:** the later scratch run
  `/tmp/edi-todo23-rmst-pilot.0alSnq/` emitted one rep for the designated
  `diamonds × beta_T=0 × survival × Bernoulli` case, with both `~1` and `~.`
  formula branches and Wald p-value/CI attempts. Its `run.log` ends with
  “All tests complete!”; the output CSV is 3,361 bytes. No matching provenance
  sidecar or package/source/native identity receipt is present. This confirms
  only that the isolated one-rep harness path completed; it is diagnostic,
  not coverage/acceptance or a provenance-pinned cohort. No CSV payload was
  read and no canonical result was changed.
  **Acceptance criteria (owner decision 2026-10-21, TODO-5 calibration):**
  - **Denominator:** accept on the **all-attempts** denominator. Every attempted
    replicate counts; an invalid, non-finite or missing interval counts as
    noncoverage (the BCa diagnostic is 33/35 = 94% finite-only but 33/120 = 27.5%
    all-attempts, the gap being almost entirely invalid intervals). The generic
    `SimulationFrameworkReport` finite-only rate (invalid excluded) is not
    acceptance evidence for this item.
  - **Invalid fraction:** report the invalid count per method family and cap it
    separately: a family fails if more than 5% of attempts yield an invalid
    interval (5% cap confirmed by the owner 2026-10-21: keep 5%, conventional and strict).
  - **Precision / replicates:** target a 95% binomial half-width of about 2
    points at coverage 0.95, i.e. at least 457 attempted replicates per method
    family (120 replicates gives only about +/-4 points). A family passes when
    its exact binomial interval for all-attempts coverage contains 0.95.
  **Invalid-fraction diagnostic, 2026-10-21:** the retained seed-23002,
  120-attempt installed-package summary reports ordinary BCa with 85/120
  invalid intervals (70.8%) and Bayesian BCa with 84/120 (70.0%); the other
  listed methods report 120 finite intervals. A separate seed-23003
  four-method diagnostic explicitly reports 120/120 finite intervals. These
  summaries show that the proposed 5% cap would reject the two BCa families
  in the pilot, but they are not source/native-pinned and do not establish
  full calibration. No raw per-replicate RMST rows or driver were found for
  independent reconstruction. The 5% cap is now confirmed (owner, 2026-10-21), so the BCa families must
  cut their invalid rate below 5% to pass; the gate
  still requires a provenance-pinned post-fix run with at least 457 attempts
  per family and all-attempts coverage analysis.
  **Diagnostics follow-up (v1.1.0):** `release_v1_1_0.md → TODO-3` (diagnostics
  chain; `optimizer_diagnostics_report.md` failure mode 8, non-finite bootstrap
  replicates, and `public_diagnostics_api_spec.md`) should record a typed reason
  per invalid interval, making the 5% cap diagnosable. It will not itself bring
  the BCa invalid rate under 5%.
  **Source-derived operation-roster preflight, 2026-10-20 (scratch only):**
  `/tmp/edi-todo23-source-attempt-operation-manifest.csv` contains 18 current
  source-derived full-route survival CI `function_run` candidates, compared
  in `/tmp/edi-todo23-source-attempt-comparison.csv` and
  `/tmp/edi-todo23-source-attempt-comparison.txt`. Thirteen match explicit
  historical CI labels; the plan's grouped rand-bootstrap-t wildcard does
  not specify the exact BRT membership, and the source roster also includes
  a Bayesian-bootstrap studentized candidate not individually named there.
  The historical target is 16 keys, so the exact roster cannot be recovered
  from the current wildcard/table without guessing. Maintainer input is
  needed to provide or approve the exact historical `function_run` keys
  before an anti-join. This manifest is operation-level only, not a complete
  result-key/reconciliation or post-fix artifact receipt. TODO-7 remains open;
  no canonical CSV was read or written for this preflight.
  **Expanded full-grid source preflight, 2026-10-20 (scratch only):**
  `/tmp/edi-todo23-source-attempt-full-key-manifest.csv` expands the 18
  current operation candidates over the current runner defaults: 9 survival
  datasets, `beta_T` 0 and 0.5, default `Nrep=40`, seven tested designs, and
  `~1`/`~.` design-formula paths. The 10,080 source case dimensions produce
  181,440 unique candidate full keys. Generator and summary:
  `/tmp/edi-todo23-full-key-manifest.R` and
  `/tmp/edi-todo23-source-attempt-full-key-summary.txt`. A 16-operation
  roster on this same grid would conditionally contain 161,280 keys, not a
  historical target; `Nrep=40` is a current-source default, not an attested
  historical run setting. The exact historical 16 operation names and grid
  dimensions remain unresolved, so no exact key anti-join is possible. Keep
  historical row reconciliation and TODO-7 open pending the exact approved
  historical roster/grid. No canonical CSV was read or written for this
  preflight.
  **Read-only retained-artifact reconciliation audit, 2026-10-21:** the
  canonical `R/package_tests/comprehensive_tests_results_nc_1_survival.csv`
  remains the recorded pre-fix artifact (372,209,537 bytes; mtime
  2026-09-27), and no matching comprehensive-run provenance sidecar is
  present beside it. The retained source-derived manifest has 181,440
  candidate keys for 18 current-source operations; the 161,280-key count for
  16 operations is conditional on the current default grid and is not an
  attested historical target. The exact historical `function_run` roster and
  grid/attempt dimensions are still missing, including the maintainer's
  choice resolving the grouped rand-bootstrap-t wildcard and studentized
  Bayesian-bootstrap candidate. Obtain that approved roster and historical
  grid before an exact anti-join; after TODO-56 releases shared artifacts,
  regenerate to an isolated output with provenance and reconcile full keys,
  statuses, and obsolete-method removals. No result payload was read or
  modified; TODO-23 remains unchecked.
  **Operation-label reconciliation detail, 2026-10-21:** the linked plan's
  historical table names these 13 CI operations exactly:
  `compute_wald_confidence_interval`,
  `compute_asymp_confidence_interval`,
  `compute_subsampling_confidence_interval`,
  `compute_bayesian_bootstrap_confidence_interval_bca`,
  `compute_bayesian_bootstrap_confidence_interval_wald`,
  `compute_bayesian_bootstrap_confidence_interval`,
  `compute_bayesian_bootstrap_confidence_interval_basic`,
  `compute_bootstrap_confidence_interval`,
  `compute_bootstrap_confidence_interval_bca`,
  `compute_bootstrap_confidence_interval_basic`,
  `compute_m_out_of_n_bootstrap_confidence_interval`,
  `compute_bootstrap_confidence_interval_studentized`, and
  `compute_jackknife_wald_confidence_interval`. Its
  `compute_rand_bootstrap_confidence_interval*` row is an aggregate wildcard,
  not a list of exact keys; `compute_rand_two_sided_pval(custom)` is a
  separate p-value reference and is not a CI operation. The 18 current
  source candidates are the 13 exact names above plus
  `compute_bayesian_bootstrap_confidence_interval_studentized` and four
  current BRT names: `compute_rand_bootstrap_confidence_interval`,
  `compute_rand_bootstrap_confidence_interval_studentized`,
  `compute_rand_bootstrap_confidence_interval_symmetric-percentile-t`, and
  `compute_rand_bootstrap_confidence_interval_smoothed`. This resolves the
  source-candidate comparison, but source alone did not establish which of
  the five additional names appeared in the historical 16-operation summary.
  The plan's historical coverage table does not declare the original
  dataset/design/formula/beta/replicate grid or `Nrep`; the current 9-dataset,
  seven-design, two-formula grid and `Nrep=40` are source defaults only. The
  retained-artifact scan below now identifies the low-coverage summary's
  exact 16 operation names, but not whether that summary or every raw-present
  CI operation defines release reconciliation, nor an authoritative single-
  run grid. Maintainer approval is still required before anti-join or
  regeneration; no historical grid is inferred from the merged raw union.
  **Retained-artifact operation/grid reconciliation, 2026-10-21 (read-only):**
  the 756,199-byte `R/package_tests/comprehensive_results_audit_baseline.csv`
  (mtime 2026-09-24) has exactly 16 `low_coverage` rows for this class. They
  are the 13 explicit CI names listed above plus three BRT names:
  `compute_rand_bootstrap_confidence_interval`,
  `compute_rand_bootstrap_confidence_interval_studentized`, and
  `compute_rand_bootstrap_confidence_interval_smoothed`. Their summary Ns are
  583, 511, and 583 respectively. Thus the historical wildcard maps to these
  three in the low-coverage summary; it does not include the fourth
  `compute_rand_bootstrap_confidence_interval_symmetric-percentile-t`, and
  the summary has no row for
  `compute_bayesian_bootstrap_confidence_interval_studentized`.
  **However,** the 372,209,537-byte canonical raw survival CSV (mtime
  2026-09-27) contains all five additional exact `function_run` labels as
  successful rows: 1,565 rows for Bayesian studentized, and 592 rows for
  each of the four BRT variants. Across the 18 source-candidate operations,
  the filtered metadata inventory finds 20,496 rows, all status `ok`; the
  observed union spans rep 1–50, beta 0/0.5, three datasets
  (`abalone`, `diamonds`, `pte_example`), seven designs, two formulas (`~1`,
  `~.`), 52 observed case-context cells, and 1,610 rep-context keys. This is
  an observed union, not a complete Cartesian grid: the raw file spans
  18 distinct GitHub commit IDs and timestamps from 2026-08-24 through
  2026-09-27, with no matching comprehensive-run provenance sidecar. The
  16-name audit summary therefore resolves its own coverage-report roster,
  but the merged raw table proves the two omitted methods also had historical
  result rows. `comprehensive_suite_coverage.csv` contributes only a
  class-level workflow count (50,850 rows), not operation-level keys. These
  artifact dimensions differ from the current-source preflight's nine
  datasets and `Nrep=40`; neither may be silently substituted for a
  provenance-pinned historical run manifest. **Maintainer choice required
  before reconciliation:** confirm whether TODO-23's affected-method target
  is the audit's exact 16 low-coverage operations (explicitly excluding the
  two raw-present methods above), or all 18 source/raw candidate CI operations;
  also confirm which historical run/grid and attempt statuses define the
  anti-join, rather than treating the merged raw union as a single run. No
  result payload was read, no fit/regeneration or canonical write occurred,
  and TODO-23 remains open.
  **Scenario-independent key reconciliation guard, 2026-10-21:** added
  `validate_todo23_attempt_reconciliation.R` and a standalone pure-R
  reference test. The helper exact-key anti-joins an explicitly supplied
  expected roster against event and result rows, surfaces missing/extra and
  duplicate results, permits completed retries, and reports orphan terminals
  and starts without terminals. Its fixture passed 11 assertions with
  `load_helpers=FALSE` and no EDI package/native load. This validates only
  reconciliation mechanics; it neither selects TODO-23's historical
  operation/grid target nor resolves the empirical scenario freeze. The
  calibration, current-native provenance, and stale-row regeneration gates
  remain open; no canonical results were read or written.
  **Attempt-lifecycle overlap regression, 2026-10-21:** extended the existing
  standalone pure-R reconciliation test with `started, started, terminal` for
  one operation key. It asserts that the overlapping start is still reported
  as unclosed/overlapping even when the single terminal and result counts
  match. The focused file passed all 38 expectations; its existing bulk
  correctness/coverage manifest entries were confirmed. This validates one
  previously unasserted lifecycle branch only; the 16-vs-18 historical
  operation/grid choice, provenance-pinned post-fix artifact, calibration,
  and canonical reconciliation remain open. No fit, simulation, build/install,
  or canonical result access/write occurred.
  **Pure-R reconciliation recheck, 2026-10-21:** the standalone
  `test-todo23-attempt-reconciliation-reference.R` passed 50 assertions with
  0 failures/warnings/skips under
  `timeout 120s Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo23-attempt-reconciliation-reference.R")'`.
  It sources the pure-R reconciler directly; test SHA-256
  `682fb06990de0ab8f1203470d6638d8fb1d2c5b202c24a3c2797f8fa354dc7e2`, helper
  SHA-256 `8529ed5ff430755d7ea0457052864e544ff796a27bbc81c999163ad55171e03d`.
  This validates synthetic exact-key and attempt-lifecycle mechanics only; no
  historical result artifact, calibration, or canonical output was read or
  written. The 16-vs-18 historical roster choice, provenance-pinned current
  run, calibration, and stale-row reconciliation remain open.
  **Retained-artifact provenance follow-up, 2026-10-21:** the 18-operation
  source candidate `/tmp/edi-todo23-source-attempt-operation-manifest.csv`
  has SHA-256
  `0096afb20a18676b0e879aee122d931529fb542730fc447400d779d84104ba10`; its
  comparison CSV SHA-256 is
  `35f771c6d354cbd20fb4362d80f3f02bd879639b26d9347b81e39a208cd0bcd7` (text
  SHA-256 `86a6860c7508fac8e461a551de01928a8a211826f2702a389f510c3ed4389d5a`).
  The expanded current-source candidate
  `/tmp/edi-todo23-source-attempt-full-key-manifest.csv` has 181,440 keys and
  SHA-256 `99871ef30ab3ebd065edb527d5e9424d5dc08de6aeb4351d8dd8192b155b4a5b`;
  generator/summary are `/tmp/edi-todo23-full-key-manifest.R` and
  `/tmp/edi-todo23-source-attempt-full-key-summary.txt`. Its 9 datasets,
  beta 0/0.5, default 40 reps, seven designs, and two formulas are not
  historical run provenance; 16 operations/161,280 keys is conditional only.
  The sole scratch result is
  `/tmp/edi-todo23-rmst-pilot.0alSnq/comprehensive_tests_results_nc_1_survival_filtered_design-Bernoulli_class-InferenceSurvivalRestrictedMeanDiff_dataset-diamonds_beta-0_rep-1_family-wald.csv`:
  four rows across `~1`/`~.` (Wald p-value and CI; SHA-256
  `7ae942b4e7073ce6b390ab27feb5285b7d0920d31ca443645e85eb99ef2e7c32`). Its
  completed run log SHA-256 is
  `b68f7a92810821c9fb41fa7e04cfe9f74308c1a4b3eba2b354ce678bd7e89864` and
  reports EDI 1.0.3; CSV commit metadata is `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  No attempt-event receipt, run sidecar, package/library identity, or DLL hash
  accompanies it, so this is not provenance-pinned calibration/reconciliation.
  The canonical `R/package_tests/comprehensive_tests_results_nc_1_survival.csv`
  is the pre-fix mixed artifact (372,209,537 bytes, mtime 2026-09-27, 18
  commits; no matching run sidecar). Only recorded metadata was used here; its
  row payload was not read or merged. The maintainer must choose the exact
  16 low-coverage operations versus all 18 current/raw-present operations and
  supply/approve the historical grid and attempt/status roster. Then run the
  full affected slice in an isolated directory with current package/R/DLL
  identity and event receipt before exact-key reconciliation. TODO-23 remains
  open; no canonical artifact was read or changed.
  **Pure-R validator contract recheck, 2026-10-21:** with no R/Rscript
  process active beforehand and no compile/install, the parent reran
  `test-todo14-attempt-result-provenance-reference.R` (12 expectations) and
  `test-todo23-attempt-reconciliation-reference.R` (50 expectations); both
  completed cleanly. These synthetic tests cover generic receipt/result
  provenance and TODO-23 exact-key/event-lifecycle mechanics only. They do
  not attest retained RMST outputs, resolve the 16-vs-18 operation/grid
  decision, validate current native provenance, or provide empirical
  calibration evidence. The post-fix full run and reconciliation remain open.
  **Read-only reconciliation recheck, 2026-10-21:** the canonical merged
  survival CSV remains the 372,209,537-byte artifact (SHA-256
  `05e1dbf4c9b51d573b5d2f0caff6a311bb3ffb4c498668d2a6d84c4b950b1b79`),
  with 18 recorded GitHub commits and no matching run receipt/sidecar; it is
  not attributable to one source-derived run roster. The audit baseline's
  16 low-coverage operation labels and the 18 operations present in the raw
  union leave the exact release target owner-dependent. The prior 181,440-key
  source candidate manifest is stale for current checkout: it records HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` and runner SHA-256
  `491a0d088461f1e408d96fa8be92b716a0fb1986ac0718a2beeadc16fab25cd7`, while
  current HEAD is `bf3addd46b63c405b961178be09ea4e03c7c6275` and the runner
  SHA-256 is `63f3055edea1b7f2db4da635a723882aa5dbb55a2187de25339ecea621739590`.
  The four-row scratch pilot remains diagnostic only: its EDI 1.0.3 log and
  checkout commit do not bind package/library payload, DLL, or attempt events.
  Next, obtain approval of the exact historical operation/grid/status roster
  or use an authorized isolated post-fix run with current package/R/DLL
  provenance and an attempt receipt; then rebuild the source-derived roster
  from the current runner and reconcile exact keys/statuses. TODO-23 remains
  open; no workload or canonical artifact was changed.
  - [ ] Re-run the predeclared multi-method coverage calibration with a
    provenance-pinned post-fix package, and evaluate invalid intervals rather
    than dropping them. Then validate the shared-horizon behavior on current
    native code and regenerate/re-audit the stale survival rows before any
    canonical reconciliation.
- [x] TODO-24 (added 2026-09-24, conclusively refuted 2026-10-08):
  **KK-matched Cox proportional-hazards undercoverage was a coverage-truth
  artifact, not a variance defect** —
  `../bug_fix_plans/survival_kk_cox_coverage_variance.md → TODO-1..8`. Confirmed
  distinct from `TODO-5 §A` (that's about `compute_confidence_interval_rand()`,
  already fixed by excluding these classes from the `randomization_ci`
  capability entirely — this new finding is on Wald/asymp/score/gradient/
  bootstrap/lik-ratio, a different code path). Confirmed KK-matching-
  specific, not Cox-general: plain siblings `InferenceSurvivalCoxPHRegr`
  (0.94-1.00) and `InferenceSurvivalStratCoxPHRegr` (0.90-1.00) are fine.
  `InferenceSurvivalKKStratCoxPHOneLik` (0.47-0.94, varying by method):
  medium-high confidence root cause — `shared()`
  (`inference_survival_KK_strat_cox.R:176-265`) inverse-variance-pools two
  SEPARATELY-fit matched-pair and reservoir estimates assuming
  independence; the matched/reservoir split comes from the same KK-
  matching allocation process, so the two may be correlated, which would
  make the standard pooling variance formula an underestimate — not yet
  empirically confirmed (needs a direct `Cov(beta_m, beta_r)` estimate).
  `InferenceSurvivalKKLWACoxPHOneLik` (0.50-1.00, similar shape): does NOT
  share the pooling pattern (uses a single joint cluster-robust Cox fit,
  which reads as textbook-correct) — root cause NOT found, needs the
  C++ cluster-robust vcov kernel read directly. The completed audit found that
  the plan had conflated OneLik with IVWC siblings: Strat OneLik already uses
  one joint stratified partial likelihood, and LWA OneLik uses one joint
  marginal Cox fit with a pair-clustered sandwich SE. The native meat/bread
  formula matches independent scores and `survival::coxph`. The non-null
  findings came from TODO-10's unconverged coverage truth and are now
  explicitly ungraded; historical null coverage was 0.93–1.00. All eight
  linked-plan items are closed and 112 focused assertions pass without
  compilation. Independent of every other item in this release.
- [x] TODO-25 (added 2026-09-24, resolved 2026-10-09):
  **`InferenceContinOLS` has no weighted-bootstrap estimator or SE bug.**
  `bug_fix_plans/investigate_contin_ols_weighted_bootstrap_se.md` records a
  faithful reproduction that resolved the audit finding as an estimand
  mismatch: iid/superpopulation resampling was graded against repeated
  randomization of one fixed finite dataset. No production source change or
  installed-result regeneration is warranted. The historical finding was
  that this fundamental class appeared to show severe
  `model_formula=~.`-specific miscalibration
  across resampling-family methods that reweight rather than permute
  (`subsampling` reject=0.19 vs nominal 0.05, `m_out_of_n_bootstrap`
  reject=0.16, several `bayesian_bootstrap` variants reject=0.13,
  `rand_bootstrap` reject=0.14; coverage as low as 0.80 on
  `bayesian_bootstrap`-family CIs). Confirmed NOT related to `TODO-15`
  (`InferenceContinLin`, different method-family group entirely — no
  overlap) or `TODO-3` (different code path). The historical candidate
  mechanism, refuted by the faithful reproduction, was that
  `compute_estimate_with_bootstrap_weights()`
  (`inference_continuous_ols.R:121-159`) computes its SE via an unguarded
  `solve(crossprod(...))[2,2]` with no rank/conditioning check, unlike the
  observed-fit path which applies an adaptive QR-based hardening layer —
  a near-singular reweighted design under a particular bootstrap draw
  could produce an unstable, too-small SE. Two synthetic reproduction
  attempts both failed (same "needs the real harness DGP" lesson several
  other findings this session hit). This is the same surface signature
  (severe, `~.`-specific) now seen in FOUR classes total
  (`InferenceContinOLS`, `InferenceContinLin`/TODO-15,
  `InferenceIncidLogBinomial`, `InferenceSurvivalWeibullRegr`) with no
  confirmed shared mechanism between any of them yet — a dedicated
  cross-class investigation (plan's own next-step list) may be
  higher-leverage than four separate per-class fixes. **Resolution:** a
  faithful 100-replicate current-source replay reproduced the
  nonstudentized symptom but found calibrated ordinary OLS and studentized
  Bayesian-bootstrap inference. Across 9,900 weighted draws, even condition
  numbers up to 1.99e7 produced finite estimates/SEs matching independent
  WLS references. The bootstrap distribution was about 20% narrower because
  it targets iid/superpopulation variation while the audit compared it with
  repeated randomization of one fixed finite dataset. That target mismatch,
  not an OLS defect, explains the percentile/basic findings. All linked
  subtasks are closed; a focused three-assertion WLS reference passes and no
  installed-result regeneration is warranted.
- [ ] TODO-26 (added 2026-09-24, found independently TWICE the same day —
  by a survival-class cluster investigation and separately by a
  dedicated `biased_estimate` audit sweep, both converging on the same
  raw outlier values — high confidence this is real): **`InferenceSurvivalKKWeibullMarginal`
  jackknife estimate has catastrophic single-fold outliers** —
  `../bug_fix_plans/kk_weibull_marginal_jackknife_outliers.md → TODO-1..8`. Apparent
  "bias" (mean −0.080) is actually RMSE (2.154) ~27× the bias magnitude —
  not a mean shift, a small number of individual jackknife replicates
  with catastrophic errors (raw values of −38.0 and +17.5 found directly,
  for an estimand whose typical scale is ~0.2-0.3) dominating the RMSE.
  **Root cause confirmed and source fix implemented 2026-10-08:** on the
  deterministic seed-1 KK14 fixture, the fold omitting rows 2 and 17 removes
  the treatment arm's only event.  The old marginal-Weibull fit reported
  convergence and returned 17.1343525; well-identified folds were
  0.91--1.66.  Ordinary and weighted refits now require at least one
  positive-weight observed event in each treatment arm, otherwise returning
  `NA_real_` with typed reason
  `kk_weibull_marginal_treatment_arm_no_events`; the shared jackknife
  summary correctly retains that nonfinite fold as nonestimable.  This is a
  narrow identifiability guard, not an arbitrary coefficient cutoff.  Also a
  clean real-data validation of this session's `biased_estimate` check
  redesign (t-test alone would miss this — p=0.47 — Wilcoxon signed-rank
  catches it, p=5.7e-11 — exactly the outlier-robustness gap discussed
  when the check was designed). **Installed recheck 2026-10-14:** the
  focused jackknife arm-event guard passed 16 assertions and the no-event/
  fit-failure guards passed 4. On the original `diamonds` /
  `KK21stepwise` combination, 25 installed-harness replications each for
  `~1` and `~.` yielded 50 finite estimates, max absolute errors 0.193 and
  0.134, and RMSEs 0.085 and 0.052; t-test/Wilcoxon results showed no
  catastrophic outliers (see linked plan TODO-5). TODO-8's broader installed
  comprehensive-results regeneration remains open. Independent of every
  other item in this release; depends on nothing else. The release checkbox
  therefore remains unchecked.
  **Source-loaded focused recheck, 2026-10-18:** after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`,
  `test-kk-weibull-marginal-jackknife-arm-event-guard-reference.R` passed 16
  assertions and `test-kk-weibull-marginal-no-events-and-fit-failed-guards-reference.R`
  passed 4 (20 total; 0 failures, warnings, or skips). The source-loaded EDI
  metadata reported version 1.0.3; its temporary DLL
  `/tmp/RtmpFgk7nF/pkgload371e26210ba362/EDI.so` had MD5
  `dd43c5d0e11708aea17ba82b900f66d1`, matching installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`.
  This exercises current checkout R code against the installed native
  artifact; it is not a rebuilt-checkout native validation and does not close
  the separate TODO-8 50-rep, two-formula-by-three-operation result matrix.
  No comprehensive run or canonical output was touched.
  **Isolated installed-package matrix, 2026-10-20:** the exact 50-rep,
  two-formula/three-operation matrix was run into
  `/tmp/edi-todo26-matrix-9NDMSE/`; all 300 unique rows were `ok`, with finite
  estimates/CI endpoints and p-values in [0,1]. The result summaries showed no
  catastrophic outlier, but no threshold is inferred. The installed package
  was EDI 1.0.3, build stamp 2026-10-19 23:31:50 IDT, DLL MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`; the CSV's `github_commit_id` is the
  harness checkout SHA, not the loaded package/DLL source revision. See the
  linked plan for exact command, output SHA, metrics, and the distinction
  between installed evidence and current-head native validation. This advances
  the isolated matrix only; canonical reconciliation remains separately
  authorized and open.
  **Additional installed-package reference check, 2026-10-20:**
  `test-kk-weibull-marginal-cpp-and-survreg-fits-cluster-robust-se-agreement-and-guards-reference.R`
  passed 19 assertions (0 failures, warnings, or skips) against installed
  EDI 1.0.3. The deterministic `set.seed(8)`, `n=80` test compares the C++
  treatment estimate and cluster-robust SE to an independent `survreg`
  reference, plus no-cluster/missing-treatment guards. R-devel r90668;
  library `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; DLL MD5
  `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`;
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This DLL differs
  from the one used for the 300-row isolated matrix (MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`), so this adds an installed-package
  estimator-reference check only; it is neither historical-result parity nor
  current-checkout native validation. It does not close TODO-26's linked
  TODO-8 canonical regeneration/reconciliation gate.
  **Post-reinstall focused installed-package recheck, 2026-10-20:** the
  jackknife arm-event and no-event/fit-failure guard tests passed 16 and 4
  assertions, respectively; the independent C++/`survreg` estimator-reference
  test passed 19 (39 total, no failures, warnings, or skips). Installed EDI
  remains version 1.0.3 (Built 2026-10-20 07:40:04 UTC); loaded DLL MD5
  `8b3ca30492d7b1c790deeebe94b201ad`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to ignored checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This improves focused installed
  validation only; no package Git SHA attests the installed R-layer source.
  The isolated matrix's source provenance and formula-specific truth review,
  plus separately authorized exact-key canonical reconciliation, remain open.
  **Checkout-R source-overlay recheck, 2026-10-20:** the independent
  `test-kk-weibull-marginal-cpp-and-survreg-fits-cluster-robust-se-agreement-and-guards-reference.R`
  passed all 19 assertions (0 failures, warnings, or skips) after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. The deterministic
  `n=80`, seed-8 C++ estimate/cluster-robust-SE comparison against independent
  `survival::survreg` and its guard checks therefore passed with checkout R
  sources. The loaded temporary DLL MD5 `8b3ca30492d7b1c790deeebe94b201ad`
  matches the installed/checkout DLL, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  No build/install, matrix run, or canonical write occurred. This adds
  focused source-overlay evidence only; authenticated installed R-layer
  provenance and formula-specific truth review for the isolated matrix, and
  separately authorized exact-key canonical reconciliation, remain open.
  **Matrix-era provenance search, 2026-10-20:** the documented isolated output
  directory contains only the CSV (no provenance sidecar, install log, or
  package-source manifest); the prepared `/tmp/edi-todo26-ready-BouNHE/` tree
  contains a runbook only. The current installed 1.0.3 build is later than the
  matrix and its DLL SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  differs from the matrix-era DLL MD5 recorded above. Retrospective installed
  R-layer attribution is therefore unavailable. Safe rerun gate: after
  TODO-56 is terminal, pin installed R-layer/source, package/library, DLL,
  runner, and helper identities in a fresh manifest/sidecar, then regenerate
  only into a new isolated directory; canonical reconciliation remains
  separately authorized. No CSV payload was read and no rerun or canonical
  write occurred.
  **Class-specific formula-routing regression, 2026-10-21:** broadened the
  existing coverage-truth registry test to include
  `InferenceSurvivalKKWeibullMarginal` with its `DesignFixedBinaryMatch`
  registry entry. The focused file passed 76 expectations while its
  `library(EDI)` attachment was suppressed; no EDI package or native code was
  loaded. The stubbed-simulator assertions pin `design_formula=~1` to
  `real_X=NULL`, `~.` to the real toy covariate matrix, and bare labels to the
  adjusted cache entry, while checking registry `mc_n=3000`. This verifies
  formula-aware dispatch only, not the historical `coverage_truth` numbers.
  The original `test-comprehensive-proportion-coverage-truth-reference.R`
  remains registered in `R/package_tests/ci/test_runtimes.csv` for correctness
  (120 seconds) and coverage (240 seconds). This is only its existing
  registration, not the separate TODO-10 retry/cache/RNG assertions; neither
  registration establishes measured line hits.
  For this matrix's `beta_T=0` stratum, source review derives the analytical
  treatment-coefficient truth as exactly zero for both `~1` and `~.`. The
  serialized formula-specific `coverage_truth` values are one-replicate fitted
  estimates from the MC truth generator, not exact truth; the retained CSV is
  diagnostic only for truth, and no coverage impact is inferred. Matrix-era
  package/R/DLL provenance and TODO-8 exact-key/canonical reconciliation
  remain open; canonical values are unchanged.
  - [ ] Complete TODO-8 reconciliation. The 2026-10-20 isolated run already
    contains all 300 expected keys/statuses, but its `github_commit_id` is the
    harness checkout SHA, not the installed package's source revision; the
    installed EDI 1.0.3 build/DLL identity is recorded but does not authenticate
    the R-layer source used for the fix. The linked plan also records the
    formula-specific `coverage_truth` values. Source inspection of
    `R/package_tests/_dataset_load.R` and
    `R/package_tests/comprehensive_tests.R` establishes the exact null target
    (`0`) for both formula paths; the stored values are one-replicate MC fitted
    estimates and remain diagnostic only. Do not infer a coverage-count impact
    or rewrite them as canonical truth. Obtain/verify the post-fix
    package-source provenance; rerun the matrix only if that provenance cannot
    be established for the existing output. Then perform a separately authorized
    exact-key canonical reconciliation without overwriting the existing
    filtered rows. No rerun or canonical write is authorized by this note.
  **Independent read-only matrix audit, 2026-10-21:** the extant isolated CSV
  was rehashed and checked against the declared grid: 300/300 unique keys and
  IDs, reps 1–50 × two formula labels × three jackknife operations, all
  `status=ok`; `error_message` is the serialized missing marker `NA`. The
  matrix directory contains only that 220,422-byte CSV (SHA-256
  `b017896390779fd24afed7f3126d8633c65de0bd7b11fbe5b607dcef694fe4ed`), with
  no sidecar, install log, or source manifest. The prepared `/tmp` runbook
  directory cited in the linked plan was absent at this check. The existing
  300/300 comparison is against the pre-fix canonical cohort and establishes
  key coverage only—not installed R-source identity or merge authorization.
  The analytical null truth is now established as zero; the matrix's stochastic
  `coverage_truth` fields are diagnostic estimates, and no coverage impact is
  inferred. Keep provenance and separately authorized canonical reconciliation
  open.
- [x] TODO-27 (added 2026-09-24, conclusively refuted 2026-10-08):
  **Historical audit output reported** moderate Type-I error inflation
  (~2.6× nominal, reject rate ~0.13) for
  `InferenceIncidBinomialIdentityRiskDiff` specifically on
  `compute_subsampling_two_sided_pval`/`compute_m_out_of_n_bootstrap_two_sided_pval`,
  consistent at BOTH `model_formula=~1` and `~.` (NOT the formula-
  dependent pattern TODO-25/TODO-15 and friends show — a different
  mechanism). Found during a broader incidence-class-cluster triage that
  characterized most of that cluster (`InferenceIncidLogRegr`,
  `InferenceIncidProbitRegr`, plain `InferenceIncidModifiedPoisson`) as
  mild, conservative, consistent with ordinary finite-sample asymptotic
  imprecision — NOT worth chasing further — and confirmed
  `InferenceIncidKKCondLogitOneLik`'s worst cell is already explained by
  `TODO-18` (unclamped smoothed-noise injection), with only a small,
  low-priority residual left. `InferenceIncidBinomialIdentityRiskDiff` is
  the one historical exception selected for a dedicated investigation.

  **Plan written 2026-09-24:**
  `../bug_fix_plans/investigate_incid_binomial_identity_subsampling_inflation.md
  → TODO-1..6` (investigation-first; fix gated on TODO-3 confirming).

  **Investigated further 2026-09-24 — low-medium confidence, not
  confirmed.** Confirmed the exact pattern directly (`m_out_of_n_bootstrap`
  reject=0.117/0.116, `subsampling` reject=0.131/0.123 at `~1`/`~.`
  respectively). Both methods dispatch through fully generic, package-wide
  shared subsampling/m-out-of-n code
  (`inference_all_abstract_non_param_boot.R:190`/`:309` →
  `inference_ext_prw_subsampling.R:135`, textbook Politis/Romano/Wolf
  centered-pivot subsampling) — since this is 100% shared/generic, a bug
  in the pivot math itself would plausibly hit many other classes too, so
  the concentration on this one class more likely implicates something
  specific to how ITS estimator behaves under a subsample, not the
  generic formula. Candidate mechanism: this class's identity-link
  binomial fit has a hard, intentional rejection boundary
  (`is_identity_binomial_fit_reasonable()`,
  `inference_incidence_binomial_identity.R:133-146` — marks a fit
  non-estimable if any fitted probability falls outside `[-1e-8,
  1+1e-8]`, a documented limitation of the identity link, not a bug in
  itself). A subsample of size `b < n` (Politis/Romano/Wolf `b` typically
  `floor(n^0.7)`) is mechanically more likely to produce a treatment-arm
  split extreme enough to push an identity-link fit outside `[0,1]` than
  the full-sample fit would. IF boundary-rejected subsample draws are
  disproportionately the ones with large `|beta_hat_subsample -
  beta_hat_full|`, and the centered-pivot p-value formula drops/filters
  them in a way that's not statistically neutral, that would artificially
  narrow the empirical pivot reference distribution — inflating rejection
  when the full-sample statistic is compared against it, independent of
  `model_formula`, exactly matching what's observed. **Not confirmed**:
  `subsampling_centered_pivot()`/`resampling_centered_pval()` themselves
  (in `inference_ext_prw_subsampling.R`) were not read to verify the
  actual filtering behavior, and no empirical reproduction was run.
  Recommended fix direction if confirmed: either make the centered-pivot
  formula's treatment of dropped/non-finite subsample draws statistically
  neutral, or relax/soften the hard `[0,1]` boundary for the resampling-
  distribution context specifically (a design decision, not a one-line
  fix) — distinct from the observed-fit context, where hard rejection is
  more defensible.
  **Resolution:** for the reported `model_formula = ~1` cells, the
  intercept-plus-treatment identity fit is algebraically equal to the two arm
  proportions and cannot cross `[0,1]`. Source-loaded checks saw zero dropout;
  independent exact-pivot simulations at `n=150` and `n=60` were near nominal,
  and a fresh focused CSV did not reproduce the historical inflation. The
  filtering path remains correctly gated, but no filtering occurred here. A
  deterministic regression pins finite, bounded resampling draws; all six
  linked-plan items are closed and 133 focused/related assertions pass without
  compilation. No production change is warranted.
- [x] TODO-28 (added 2026-09-24; **closed as a stale source finding on
  2026-10-07**): **Reused bootstrap worker `cached_design_matrix` reset
  audit** — `../bug_fix_plans/bootstrap_worker_stale_design_matrix.md`.
  The named loader already resets `cached_design_matrix` and
  `cached_hardened_X_cov` in HEAD; blame traces those resets to commit
  `8aa321146` on 2026-06-01, before this TODO was written. A new two-draw
  OLS regression confirms that the reused worker's second estimate matches
  a fresh worker and an independent `lm.fit`. Historical investigation notes
  below are superseded; the original class-specific miscalibration findings
  remain open under their own TODOs. The old hypothesis was that
  `load_bootstrap_sample_into_design_backed_worker()`
  (`inference_all_abstract_non_param_boot.R:1191-1235` — the loader for
  `subsampling`/`m_out_of_n_bootstrap`/plain `bootstrap`, and the exact
  loader this session's ORIGINAL stale-cache fix already confirmed "fully
  wipes `cached_values`" and treated as the correctly-behaving reference)
  resets `cached_mod` and several sibling caches between draws but **never
  resets `w_priv$cached_design_matrix`** — even though it correctly resets
  `w_priv$w`/`w_priv$X` to the current draw's resampled rows.
  `create_design_matrix()` (`inference_all_abstract.R:1032-1034`)
  unconditionally returns the cached matrix if one exists, so every draw
  after the first silently reuses draw 1's design matrix while the
  weights applied to it are correctly the current draw's — a scrambled
  data/weight correspondence, repeating every draw. Same allowlist-not-
  denylist shape as this session's original bug and as the then-open
  `TODO-12` (`cached_mod` gap in a DIFFERENT loader) — this time in the
  loader previously believed to already be fully correct. Confirmed all
  four of `InferenceContinOLS` (`TODO-25`), `InferenceContinLin`
  (`TODO-15`), `InferenceIncidLogBinomial`, and `InferenceSurvivalWeibullRegr`
  declare `compute_estimate_with_bootstrap_weights()` overrides calling
  the same shared, unguarded-cache code path; exact mechanistic match
  confirmed for `InferenceContinOLS` (its worst-affected families,
  `subsampling`/`m_out_of_n_bootstrap`, are literally the two families
  that call this exact loader). Not yet confirmed whether this fully or
  only partially resolves each of the four classes' independent
  investigations (`TODO-15`/`TODO-25` each already found their own
  candidate per-class mechanism, not yet confirmed to be the same bug or
  a compounding second bug) — TODO-4 of the new plan settles this.
  Highest-leverage fix candidate found across this whole `~.`-pattern
  investigation thread. Independent of every other item in this release;
  depends on nothing else.
  **Scope update 2026-09-24 (same day, later forks):** confirmed to reach
  at least 2 more classes via direct call-chain reads —
  `InferenceContinRobustRegr`, `InferencePropFractionalLogit` — plus
  `InferencePropGCompMeanDiff` (confirmed call-graph match) and, per the
  separate scope-widening note below, `InferenceCountRobustPoisson` —
  total confirmed scope now the original 4 + these 4 = 8 classes.
  **Further scope update, same day**: 4 more GComp-family classes
  independently confirmed (both conditions verified directly, not by
  naming similarity) — `InferenceIncidGCompRiskDiff`,
  `InferenceIncidGCompRiskRatio`, `InferenceIncidKKGCompRiskDiff`,
  `InferenceIncidKKGCompRiskRatio` — bringing confirmed scope to 12
  classes. `InferenceOrdinalGCompMeanDiff` was checked and **ruled out**
  (its `build_design_matrix()` is a custom, uncached implementation that
  never calls `create_design_matrix()` at all). See plan file's GComp
  verification section for detail. **The
  whole "KKGLMM"-named cluster (`InferenceContinKKGLMM`,
  `InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferenceOrdinalKKCLMM`
  + its 3 link-function subclasses) was initially miscategorized as
  "confirmed" by an earlier fork that checked only the call chain, not
  whether the class actually reaches the reused-worker path — a later,
  more careful re-check ruled all 7 of these OUT** (see "Also explicitly
  ruled out, same day" below for the full reasoning: none of them override
  `supports_reusable_bootstrap_worker()`, so each draw gets a fresh
  worker and `cached_design_matrix` cannot go stale). Also **refuted**
  (does not call `create_design_matrix()`, needs independent
  root-causing) for `InferenceContinKKOLSOneLik`,
  `InferenceContinKKRobustRegrOneLik`, `InferencePropBetaRegr`,
  `InferencePropZeroOneInflatedBetaRegr`, and `InferencePropKKGLMM` — see
  plan file's "Scope update 2026-09-24" section for the full per-class
  table and unresolved cases (`InferenceContinKKQuantileRegrOneLik`,
  `InferenceOrdinalGCompMeanDiff`, other GComp siblings).
- [x] TODO-29 (added 2026-09-24, fixed and audited 2026-10-08): Historical
  audit output identified `InferenceAllSimpleAverageDiff`'s
  `bayesian_bootstrap_studentized`/`jackknife_wald` families are
  consistently the worst-covering across all 5 response types this class
  supports, while other families are fine — `../bug_fix_plans/investigate_average_diff_bayesian_jackknife_se_quality.md`.
  **Not TODO-28** — this class builds no design matrix in this path,
  confirmed a distinct mechanism. The historical Kish-effective-size
  candidate is resolved below; `jackknife_wald` is independently classified
  as finite-sample Wald behavior. Independent of TODO-28 and everything else
  in this release.

  **Resolution:** Bayesian-bootstrap studentization incorrectly applied Kish
  effective sample size to normalized Dirichlet frequency weights, inflating
  replicate SEs by about `sqrt(2)`. It now uses frequency-weight Welch
  contributions `Q/[W(W-1)]` and matching `W-1` Satterthwaite degrees of
  freedom. Independent coverage improved from 0.820–0.840 to 0.944–0.953;
  source-loaded coverage was 0.960 with 300/300 finite runs. The separate
  `jackknife_wald` path never uses this hook, matches a hand delete-one/qnorm
  calculation, and approaches nominal coverage with sample size, so its audit
  flags are finite-sample Wald behavior. All four linked-plan items and 163
  focused assertions pass without compilation.

  **Scope widened 2026-09-24**: a 5th class, `InferenceCountRobustPoisson`
  (9 families uniformity, 2 coverage, previously unexplained), is an EXACT
  mechanistic match — `build_design_matrix()`
  (`inference_count_robust_poisson.R:205-207`) delegates directly to
  `private$create_design_matrix()`, the exact broken cached path, and
  `supports_reusable_bootstrap_worker()` returns `TRUE`
  (`:202-204`), confirming it uses the reused-worker path this bug
  requires. **Explicitly ruled out, same check**: `InferenceCountQuasiPoisson`
  (also 9 families uniformity, 4 coverage, also previously unexplained)
  does NOT share this mechanism — its `build_design_matrix()`
  (`inference_count_quasipoisson.R:244-252`) reads `private$w`/`private$X`
  directly on every call with no caching at all, genuinely immune to a
  stale-cache bug. `InferenceCountQuasiPoisson`'s broad miscalibration
  remains real and completely unexplained — a fresh investigation, not
  covered by this TODO.

  **Also explicitly ruled out, same day**: the whole "KKGLMM"-named class
  cluster — `InferenceContinKKGLMM`, `InferenceCountKKGLMM`,
  `InferenceOrdinalKKGLMM` (all three compose the `KKGLMM` mixin component,
  `inference_mixin_kk_glmm_shared.R`, whose `glmm_predictors_df()` calls
  `private$create_design_matrix()` directly — same broken cached path) and
  the separately-implemented `InferencePropKKGLMM` /
  `InferenceIncidKKCondLogitGLMMIVWC` / `InferenceIncidKKCondLogitGLMMOneLik`
  (all three inherit `InferenceAbstractKKCondLogitGLMM`, whose
  `compute_estimate_with_bootstrap_weights()` also calls
  `private$create_design_matrix()` directly at
  `inference_incidence_KK_cond_logit_glmm_abstract.R:99`). All 6 classes
  were checked for `supports_reusable_bootstrap_worker()`: none of them
  (nor the `KKGLMM`/`BayesianBootstrap`/`ParametricLikelihoodBootstrap`
  components they compose) override it, so all 6 inherit the base default
  `FALSE` (`inference_all_abstract_non_param_boot.R:1090-1092`). Confirmed
  via the Bayesian-bootstrap driver
  (`inference_all_abstract_bayesian_bootstrap.R:192-246`): when
  `supports_reusable_bootstrap_worker()` is `FALSE`, every draw gets a
  **fresh** `worker_inf = inf_template$duplicate(...)` (line 201/230) before
  calling `compute_estimate_with_bootstrap_weights()` — so
  `cached_design_matrix` starts `NULL` on every draw and cannot go stale
  across draws. This whole cluster genuinely does not use the reused-worker
  path this bug requires, unlike `InferenceCountRobustPoisson` above. If any
  of these 6 classes show real miscalibration in the audit, it is a
  different, not-yet-investigated mechanism.

**Investigated and CLOSED, not a bug (2026-09-24):** classical incidence
risk-difference `low_power` audit findings for `InferenceIncidNewcombeRiskDiff`,
`InferenceIncidRiskDiff`, `InferenceIncidMiettinenNurminenRiskDiff`,
`InferenceIncidKKNewcombeRiskDiff` (moderate-low reject rates, 3-20%, at
`beta_T=0.5`, no near-zero/catastrophic cells). Compared directly against
an independently-implemented GComp baseline (`InferenceIncidGCompRiskDiff`)
at the identical effect size: reject rates cluster in the SAME 0.02-0.20
band across all five classes, no meaningful gap between the "conservative-
by-design" classical methods and the GComp comparator. High confidence
this is a genuinely underpowered benchmark scenario at this harness's
default effect size for the whole risk-difference estimand family, not a
defect in any one method's implementation — consistent with how several
other `low_power` findings this session resolved. No plan file, no
further investigation warranted; recommend accepting into the audit
baseline as expected/benign.

- [x] TODO-30 (added 2026-09-24, fixed 2026-10-07):
  **Cox risk-set cache staleness guard** —
  `../bug_fix_plans/cox_risk_set_cache_staleness.md → TODO-1..5`.
  `InferenceCoxPH` (`cox_*` caches) and `InferenceStratifiedCoxPH`
  (`strat_cox_*` caches) now key on the full `w`/`y`/`dead`/`X` inputs.
  The same-pattern sweep found and fixed four model-matrix caches that
  reused stale `X` at fixed `w` (logit, log-binomial, Poisson, negative
  binomial). Focused mutation, bootstrap, cache-reuse, and class-wiring
  tests pass without compilation; the linked plan's 5 items are checked.
  The tagged v1.0.0 source has old Cox guards, but no tagged binary was
  tested for a released numerical failure.
- [ ] TODO-50 (added 2026-09-24 as TODO-31, **renumbered 2026-09-24** — a
  concurrent session independently added an unrelated TODO-31/TODO-32 pair
  the same day, colliding with this one and the next; this pair was moved
  to 50/51 rather than the other, larger, contiguous batch, since only two
  files needed updating; nothing else in this repo referenced these two
  numbers under their old numbers besides those two files, both fixed in
  the same pass): promoted from asides inside TODO-4's and
  TODO-29's prose — user flagged that un-homed findings in this file risk
  getting lost; tracked as an open investigation, not a fix plan, in
  `bug_fix_plans/investigate_count_family_unexplained_miscalibration_cluster.md`):
  **four count-family classes show real, audit-flagged miscalibration with
  no confirmed root cause** — `InferenceCountPoisson` (16 families
  flagged), `InferenceCountQuasiPoisson` (9 families uniformity + 4
  coverage), `InferenceCountKKGLMM` (part of the cluster ruled out from
  TODO-28/29's stale-design-matrix mechanism), and
  `InferenceCountKKHurdlePoissonOneLik`. Each was checked against a specific
  candidate mechanism from a different investigation (TODO-4's unguarded-
  information-inverse bug, TODO-28/29's stale-`cached_design_matrix` bug)
  and confirmed to NOT share it — but none has been root-caused on its own
  terms. No plan file existed for any of the four before this TODO.
  **Reconciled 2026-10-10:** this umbrella no longer owns an independent
  unresolved implementation. `InferenceCountPoisson`'s Bartlett-family
  conservative combination is resolved under TODO-48; `InferenceCountKKGLMM`'s
  actual finding is the near-zero variance-component basin fixed at source
  under TODO-31; and `InferenceCountKKHurdlePoissonOneLik` now combines its
  model and design-based inference conservatively. `InferenceCountQuasiPoisson`'s
  remaining modest small-sample behavior and isolated 1.000-coverage
  subsampling interval are method properties (the latter conservative), not a
  formula or dispatch defect. The linked plan's historical-row comparison and
  cache sweep are complete. This row remains unchecked only because TODO-31's
  native rebuild validation and the subsequent installed comprehensive-CSV
  reconciliation are still required; no separate TODO-50 source change remains.
  **TODO-31 partial grid evidence 2026-10-14 (installed EDI 1.0.3; no
  rebuild):** the explicit small-grid convention `n={120,200}`,
  `sigma={0.6,0.9}`, seeds `41001:41010` covered all four native kernels
  (160 fits). No ordinal boundary fit was materially worse than its
  `clmm(nAGQ=25)` reference; the three logistic boundary fits matched
  singular/zero-sigma `glmer` references. Poisson had no boundary fits, but
  reproducible cold-start non-boundary local optima at seed 41003 (0.12833
  NLL worse) and seed 41008 (1.01325 worse) versus glmer-informed native
  starts. These fits reported convergence, no iteration-cap hit, and gradients
  below `8e-7`; the better reference-start fits had higher reported gradients
  (0.0475 and 0.0313), so convergence/gradient interpretation remains part of
  TODO-31's residual. Its linked plan records the full kernel-level settings
  and results. TODO-50 stays open pending TODO-31's broader validation/native
  gate and canonical
  comprehensive-CSV reconciliation.
  **Read-only TODO-31 row/provenance inventory 2026-10-18:** the root
  canonical count CSV contains 14,206 matching `InferenceCountKKGLMM` rows
  (all `ok`; 14,206 distinct row `id`s, 307 broader `case_id`s; timestamps
  2026-08-24 12:38:18 IDT–2026-09-27 09:32:10 IDT) across 22 recorded
  `github_commit_id`s. The ordinal CSV contains 69,121 matching
  `InferenceOrdinalKKCLMM` rows (all `ok`; 69,121 distinct row `id`s, 973
  broader `case_id`s; timestamps 2026-08-24 12:30:58 IDT–2026-10-09
  01:12:24 IDT), also across 22 recorded commit IDs. Neither class has a row
  whose recorded commit descends from sigma-start fix
  `e706c6f67a6798eea666921155c259a751476feb`. Use `id` rather than
  `case_id` for row-level reconciliation because `id` includes replicate and
  `beta_T`. Exact 22-SHA inventories are in the linked TODO-31 plan. The
  CSV `github_commit_id` records source HEAD, not the native library actually
  loaded, so this inventory establishes stale source attribution, not native
  artifact identity; separately record the built/loaded native artifact on
  regeneration. No result CSV or baseline was changed. The 1.0.5 acceptance
  policy is owner-approved; current-head native validation and row
  regeneration/audit remain open.
  **Coverage-denominator reconciliation note, 2026-10-21:** after the
  provenance-stamped CountKKGLMM/OrdinalKKCLMM rows are regenerated with native
  provenance, recompute the affected coverage findings using current
  `audit_one()` semantics and reconcile attempts with finite truth, finite
  bounds, and covered counts. A separate read-only audit of retained
  ZeroInflatedPoisson rows found status-ok attempts with finite truth but
  missing intervals; the saved aggregates used only finite-bound denominators,
  unlike the current source rule, which counts those attempts as uncovered.
  This is an audit-pipeline/version warning, not evidence about the targeted
  KKGLMM/ordinal rows and not a replacement for the TODO-31 native-validation or
  TODO-50 provenance-stamped regeneration gates.
  **TODO-50 retained-artifact disposition, 2026-10-21:** the two canonical
  files contain 83,327 targeted rows total (14,206 CountKKGLMM + 69,121
  OrdinalKKCLMM); all are `ok` with unique `id`/`run_row_id`, but every row's
  `github_commit_id` predates fix `e706c6f67a6798eea666921155c259a751476feb`
  and current HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Count CSV:
  mtime 2026-09-27 11:17:02 +0300, SHA-256
  `684e7fa07ea616d0743c226bae4a5300360ad7906d6d166872e4399ec144fba3`;
  ordinal CSV: mtime 2026-10-09 01:12:24 +0300, SHA-256
  `5da4c24e4e078bb47c18f8d8a5f78775c511d46c05e11bed40e0fe67c74111ce`.
  The canonical rows do not bind loaded-DLL identity. The retained 29,440-row
  candidate-strata CSV has SHA-256
  `5d0760ec7b2e750fe096c28bd67b5a38d309a67aaa856c3d5fc15974fab662bb`
  (mtime 2026-10-20 14:56:52 +0300), but lacks `function_run` and attempt
  identities; its README supplies neither generator nor source hashes and
  cites the now-dirty `comprehensive_tests.R`, so it is not current-source
  attestation. No post-fix comprehensive output/sidecar is retained. CI
  `38808821543` at descendant commit `430c19bcdb0702d998c79f9058c449449034134c`
  is regression/build evidence only, not row reconciliation. Exact
  reconciliation therefore awaits an isolated post-fix run with package/R/DLL
  provenance and complete attempted-key/terminal-state output; no result file
  was changed and TODO-50 remains open.
  **TODO-50 inventory recheck, 2026-10-21 (read-only):** only
  `/tmp/edi-todo50-source-strata.8DTD1J/` remains under the matching `/tmp`
  prefix, with README plus the 29,440-row candidate-strata CSV. The candidate
  and canonical CSV hashes still match the recorded inventory. Current raw
  source hashes are `comprehensive_tests.R`
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221` and
  `_dataset_load.R`
  `7e3cf603ef384c369c4435dc5ca0b541d9248bbda9e5db7f3c17b2b41628bdda`;
  however, the candidate README has no generator/source hashes, so its
  29,440 strata cannot be attributed to those current bytes. The canonical
  files remain without adjacent run-provenance sidecars. This does not add a
  current-source attempt roster or post-fix result output. The full
  `function_run`/terminal-outcome roster, provenance-stamped regeneration,
  and exact reconciliation remain open; no result or canonical file changed.
  - [ ] Validate the owner-approved 20-vs-320 parameter bound on the broader
    four-kernel grid with current-head native provenance, and reconcile the
    provenance-stamped CountKKGLMM/OrdinalKKCLMM comprehensive rows; then
    confirm TODO-50's historical umbrella findings remain dispositioned in
    the baseline audit.
- [x] TODO-51 (added 2026-09-24 as TODO-32, renumbered 2026-09-24 for the
  same collision as TODO-50 above): promoted from a one-line dead-code aside
  inside TODO-4's prose, same reason as TODO-50 — user flagged that un-homed
  findings risk getting lost; now tracked in
  `../bug_fix_plans/remove_disabled_min_eigenvalue_helpers.md`): **dead code in
  `_helper_functions_core.h`** — `set_min_eigenvalue_if_suspect()`
  was entirely commented out, so the generic
  `min_eigenvalue_information` diagnostic was never populated by that helper.
  Found while checking `InferenceCountPoisson`
  against TODO-4's unguarded-information-inverse bug (unrelated — there was
  no live caller to implicate either way). **Source progress 2026-10-10:** the
  decision is to remove the disabled no-op helper templates, their unused
  SFINAE trait, and all call sites while retaining the
  `min_eigenvalue_information` result fields in the R/Python schemas with
  their existing `NaN` default. This cleanup changes neither numerical
  behavior nor the public result contract. **Installed-package recheck
  2026-10-14:** probit output/equivalence (75 assertions), Poisson output/
  equivalence (37), and zero-augmented-Poisson diagnostic (14) all passed
  against the user's reinstalled EDI package (reported version 1.0.3); no
  Codex compile/build/install was run.
- [ ] TODO-52 (added 2026-09-24, promoted from asides inside
  `bootstrap_worker_stale_design_matrix.md`'s (TODO-28) cross-class sweep,
  same reason and same pattern as TODO-50/51 — user asked for a double-check
  sweep of this file for orphans and buried secrets; tracked as an open
  investigation, not a fix plan, in
  `bug_fix_plans/investigate_beta_ols_kkglmm_low_coverage_orphans.md`):
  **six audited findings show real but heterogeneous historical flags
  (`pval_miscalibration`, `low_coverage`, or `biased_estimate`), each checked
  only against the stale-`cached_design_matrix` bug and confirmed not to
  share it, with no common-source investigation yet justified**
  — `InferencePropBetaRegr`, `InferencePropZeroOneInflatedBetaRegr`,
  `InferenceContinKKOLSOneLik`, `InferenceContinKKRobustRegrOneLik`,
  `InferencePropKKGLMM`, `InferenceIncidKKCondLogitGLMMIVWC`/
  `InferenceIncidKKCondLogitGLMMOneLik` (grouped as one finding, all three
  inherit `InferenceAbstractKKCondLogitGLMM`). The lower-priority 7-class
  KKGLMM/KKCLMM addendum was likewise ruled out from TODO-28's mechanism and
  does have real, heterogeneous audit-flagged rows; those rows do not support
  a common-source claim.
  **Audit progress 2026-10-09:** the linked plan now reconciles the retained
  historical audit rows. The six classes do not have a single error
  signature (only BetaRegr/ZOIB share two 37-null-draw custom-randomization
  rows), while the KKGLMM/KKCLMM addendum does have real but heterogeneous
  flagged rows. The investigation remains open: a causal claim needs a new
  targeted study, not a retrospective source edit.
  - [ ] Recover the flagged historical cells' dataset, design, formula, DGP,
    and seed/provenance, or obtain approval for a replacement targeted study.
    Test the six named groups and seven-class addendum separately; implement
    no shared fix unless a common mechanism is reproduced.
  - [x] Run the six corrected one-replicate proportion-response pilots in
    isolated `/tmp` outputs, timing B=151 first. All 63 result rows are `ok`
    with no errors; `FixedBinaryMatch` skips `design_formula=~1` as expected
    and runs `design_formula=~.` with both model formulas. Full per-cell counts, durations, output
    roots, and the remaining calibration limitation are in the linked plan.
  - [ ] Inspect these pilot outputs against an owner-approved calibration
    criterion, then decide whether a larger post-fix calibration study or a
    source change is warranted. Six one-replicate cells cannot establish
    calibration or resolve the missing historical replay provenance.
  - [x] Fix the filtered-runner beta no-op: an explicit `beta_T=0.3` filter
    was silently skipped because the default sweep contains only `0` and
    `0.5`. The runner now uses the explicit filter as its sole beta value and
    rejects malformed/non-finite values; the focused regression passes 8
    assertions. The first corrected Bernoulli B=151 pilot completed with 18
    `ok` result rows (6 parametric-bootstrap, 12 companion bootstrap). The
    full six-cell pilot produced 63 error-free rows; `FixedBinaryMatch` skips
    `design_formula=~1` because that design path lacks covariates. Malformed beta
    CLI input now fails closed. These pilots validate execution/timing only.
    **checkout-source recheck 2026-10-20:**
    `pkgload::load_all("R/EDI", compile = FALSE)` followed by
    `testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-beta-filter-reference.R")`
    passed 8 expectations (0 failures, warnings, or skips). The beta helper
    was sourced from this checkout; available installed EDI 1.0.3 was at
    `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, built
    2026-10-19 23:31:50 IDT under R-devel r90668, `EDI.so` MD5
    `dfd5bf4384b5a0cc0d430fd70dab2a59`. No compile/install occurred; this is
    filter-contract evidence only and adds no historical or calibration claim.
    The post-fix calibration/source decision remains open. Isolated artifacts:
    `/tmp/edi-v105-todo52-pilot-fixed-beta-NuLaVN/`.
    **Read-only artifact integrity recheck, 2026-10-20:** all six isolated
    CSVs were present and parseable (63 rows total; all `status=ok`, no
    nonempty `error_message`); all report checkout commit
    `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. SHA-256 values and exact
    per-design/family counts are recorded in the linked plan. No package/DLL
    provenance sidecar exists in those roots, so this confirms retained bytes
    and row/status integrity only—not installed-binary identity, calibration,
    or a reproducible historical replay.
  **Source/reference/artifact gate audit, 2026-10-21:** the plan's source
  review rules out only TODO-28's stale `cached_design_matrix` mechanism; it
  does not establish a shared cause across the six named findings or the
  heterogeneous seven-class KKGLMM/KKCLMM addendum. Existing independent
  estimator references (including the `betareg`/quasibinomial/G-computation
  proportion-class suite) check estimator/interval behavior, not the flagged
  method-family rejection/coverage cells. The eight-assertion beta-filter
  regression validates explicit `beta_T` selection in the runner, not
  inference calibration. The retained 63-row pilot matrix is exclusively
  `InferencePropBetaRegr`, `airquality`, `beta_T=0.3`, one outer replicate,
  across Bernoulli/FixedBinaryMatch and `lik_ratio`,
  `parametric_bootstrap` (B=151), and Wald; it establishes execution and
  `status=ok`/error-free outputs, not null behavior or nominal size. Its CSVs
  carry the checkout commit but have no package/DLL provenance sidecar; the
  historical row-level CSVs retain some cell labels and run metadata but not
  assignments, outcomes, or RNG state sufficient for exact replay. Thus the
  next gate is to recover the original per-cell fixture/DGP/seed/provenance or
  obtain maintainer approval of a replacement study and its calibration
  criterion, then study the flagged groups separately before proposing any
  source change. No independent calibration reference, additional source
  defect, or post-fix full-grid artifact was established here; no test,
  simulation, or canonical result access was performed for this audit.
  **Independent pilot-key audit, 2026-10-21 (read-only):** rechecked the six
  retained CSVs and run logs. The combined 63 rows have 63 unique full keys
  (`rep`, `beta_T`, dataset, response, design, inference-class/formula label,
  and function run), with per-file counts 6/18/6/9/12/12, `rep=1`,
  `beta_T=0.3`, `airquality`, `InferencePropBetaRegr`, and `status=ok` in all
  rows; serialized `error_message` is `NA`. Each pilot has an adjacent
  `run.log` showing its filtered arguments and terminal completion. The
  malformed-beta log is only a rejected-input smoke check. No pilot directory
  contains a package/DLL provenance sidecar or RNG-state receipt, so the
  checkout commit does not authenticate the loaded package or enable exact
  replay. This closes only the observed pilot key/status check, not recovery
  of historical DGP/seed/assignment inputs or the owner-approved replacement
  study/calibration-criterion gate. No canonical artifact was changed.

- [ ] TODO-31 (added 2026-09-24, from an audit of test-file comments; four
  tests pin it as `SUSPECTED SOURCE BUG (pinned, not fixed)`): **Random-effect
  variance collapse in GLMM/CLMM fits** —
  `../bug_fix_plans/glmm_variance_component_sigma_collapse.md → TODO-1..6`.
  `fast_ordinal_clmm_cpp` (started at `log sigma = -3`, the KK CLMM classes'
  warm start), `fast_logistic_glmm_cpp` (default cold start) and the KK count
  GLMM (Newton) slide `log sigma` to about `-3`, report `converged = TRUE`,
  and return a worse likelihood and biased estimate (6/12, 12/30 simulated
  datasets in the probes); `InferenceOrdinalKKCLMM` returned the fixed-effects
  `polr` estimate (0.4101 vs 0.4228 from `clmm`/`InferenceOrdinalKKGLMM`).
  Also a wrong-signed log-sigma entry in `get_logistic_glmm_hessian_cpp`.
  Reproduced by the pinned fixtures only; extent and fix undecided.
  **Implementation status 2026-10-09:** the ordinal, logistic and Poisson
  native GLMM fitters now screen deterministic log-sigma starts and retain
  the best finite objective while respecting fixed sigma; KK CLMM uses a
  neutral warm sigma. The duplicated sigma chain-rule factors in the
  logistic Hessian were removed, five pinned regressions were flipped, and
  the reach audit is complete. Static parsing and diff checks pass. Linked
  TODOs 2-5 are closed. **Installed-package recheck 2026-10-14:** the
  reinstalled EDI binary passed the five focused native regression files
  (ordinal CLMM kernel/class, logistic GLMM, count KK GLMM, and logistic
  score/Hessian), 62 assertions total, no failures/warnings. Codex did not
  compile, build, or install. An additional nonlogit KK-CLMM fixture was
  added to the existing class/reference test and passed 26 assertions against
  installed EDI 1.0.3 on 2026-10-16; this still does not validate the current
  checkout's native code. **Diagnostic assertion extension, 2026-10-18:**
  the focused class/reference file now also requires finite `gradient_norm`
  for the independent `ordinal::clmm` oracle start, five seeded stability
  starts, and both -3/default cold starts. It passed 31 assertions against
  installed EDI 1.0.3 (DLL SHA256
  `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`).
  This pins the diagnostic's presence without imposing an undecided threshold;
  it is not current-checkout native validation. TODO-1's sigma-by-n characterization and
  TODO-6's comprehensive-row regeneration remain open; this release item
  stays unchecked.
  **Poisson local-optimum follow-up, 2026-10-18:** the cold smart-start now
  adds a fixed-effects Poisson IRLS beta candidate alongside the existing
  start family, preserving fixed-sigma handling and selecting the lowest
  finite GLMM objective. A non-vacuous regression uses seeds 41003/41008 and
  independently integrates each result's marginal likelihood against the
  `glmer(nAGQ = 25)` candidate. R parsing and scoped diff checks pass. Against
  installed EDI 1.0.3, the 15 existing assertions pass and only the two new
  seed comparisons fail, as expected because that native binary predates this
  checkout change. The source fix is not yet validated: current-native testing
  requires an explicitly authorized `EDI_UNITY=0` rebuild/install. The broader
  four-kernel sigma-by-n grid and comprehensive-row reconciliation also remain
  open.
  **Optimizer-mode limitation, 2026-10-18:** the new exact-NLL test currently
  calls the kernel with its default L-BFGS optimizer; it does not exercise the
  production `InferenceCountKKGLMM` Newton path. A saved Newton probe using the
  added GLM beta candidate reports a 40-node kernel objective (`neg_loglik`)
  of 312.754654 versus 312.749004 for the `glmer`-started fit at seed 41003
  (gap about 0.00565, above the linked plan's 1e-3 material threshold;
  gradient norm 1.731). These are not independently integrated exact NLLs.
  This probe is not a
  current-checkout native validation, but it means the present change does not
  yet establish optimizer-independent acceptance. The sigma-by-n runner also
  labels `strictly_worse` at 1e-6 while the plan's material threshold is
  1e-3; compare raw likelihood gaps under the declared threshold before
  interpreting its classification. The owner-approved 1.0.5 policy keeps the
  default and optimizer/start behavior unchanged; validate its 20-vs-320 bound
  on the broader grid with current-source/native provenance before closing
  TODO-31.
  **Metric reconciliation, 2026-10-20:** the old probe and the new exact-NLL
  regression use the same Poisson GLMM fixture (seed 41003; `n=200`, 40 groups
  of five), but they are not the same numerical cell. The probe fitted at
  `n_gh=40` and compared approximate kernel objectives for supplied GLM and
  glmer starts; its 312.754654 result has a finite-quadrature gradient norm
  of 1.731. The regression fits at `n_gh=320` and compares independently
  integrated exact marginal NLL to the `glmer(nAGQ=25)` parameter candidate.
  A read-only installed-artifact rerun confirms this distinction: for a cold
  Newton fit at `n_gh=40`, reported objective was 312.754653511, but exact
  integrated NLL was 312.919277091 versus 312.828220611 at the glmer candidate
  (gap 0.091056480); at `n_gh=320`, exact NLL was 312.828220610 (gap
  `-1e-9`) and gradient norm `2.47e-8`. The seed-41008 Newton/L-BFGS exact
  gaps at 320 nodes were `4.245e-6` / `4.333e-6`; all four seed/optimizer
  cases pass the test's `1e-4` exact-NLL allowance. Thus the older 0.00565
  is a 40-node approximate-objective gap, while the new test's 1e-4 is an
  independently integrated high-quadrature criterion; neither supersedes the
  other. The test uses installed EDI 1.0.3 `EDI.so` SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`,
  byte-identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; this identity does not attest
  the source/build chain. The 1.0.5 optimizer/start behavior is owner-approved
  and unchanged; the broader four-kernel grid, current-source/native provenance,
  and comprehensive-row gates remain open.
  **Fixed-coordinate contract subgate, 2026-10-20:** the same focused
  Poisson GLMM test now supplies a caller warm start and fixes the log-sigma
  coordinate at `log(0.6)`. It requires exact preservation of the fixed value
  and agreement between the reported kernel objective and independent exact
  marginal NLL within `1e-6`. The file passed 24 assertions (0 failures,
  warnings, or skips) against installed EDI 1.0.3; no build/install occurred.
  This is a policy-neutral fixed-parameter contract check, not evidence that
  the 40-node Newton cold fit meets the glmer candidate or that the source/build
  chain is current. The owner-approved optimizer/start policy remains unchanged
  for 1.0.5; four-kernel sigma-by-n characterization, current-source/native
  provenance, and comprehensive-row reconciliation remain open.
  **Fresh installed-native exact-NLL regression rerun, 2026-10-20:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-poisson-glmm-fit-quadrature-convergence-and-glmer-agreement-reference.R", package = "EDI")`
  passed all 29 expectations (0 failures, warnings, or skips) against installed
  EDI 1.0.3. The installed `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` is
  byte-identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This focused run covers the
  320-node seed-41003/41008 exact-NLL fixtures under Newton and L-BFGS; it does
  not itself validate the 1.0.5 20-vs-320 acceptance bound, current-source/native
  provenance, or the broader grid/canonical-row gates. The owner-approved
  optimizer/start policy remains unchanged.
  **Installed-package exact-NLL regression recheck, 2026-10-21:** reran the
  same focused file via `timeout 180s Rscript -e` with `library(EDI)` and
  `testthat::test_file(..., reporter = "summary")`; all 29 expectations passed
  (0 failures, warnings, or skips). Runtime package was EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded `EDI.so`
  MD5 `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
  mtime `2026-10-21 09:43:34 +0300`. The focused test file SHA-256 was
  `40111009586499512e27258409339c8e25f5ecbcb01889c0918432678606eef2`;
  checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This is a
  newer/different installed artifact than the 2026-10-20 run, but does not
  attest its R-source/build chain or validate current-checkout native code.
  No build/install or canonical result generation occurred. The 20-vs-320
  parameter bound, broader four-kernel grid, current-source/native provenance,
  and comprehensive-row reconciliation remain open.
  **Installed production-quadrature measurement, 2026-10-20:** the installed
  EDI 1.0.3 namespace (`Built: R 4.7.0; x86_64-pc-linux-gnu;
  2026-10-20 07:40:04 UTC`) was exercised on the existing `n=200`, 40-group,
  five-observation/group fixtures at seeds 41003 and 41008, using the shipped
  20-node setting and `optimization_alg="newton_raphson"`. The loaded DLL
  SHA-256 (`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`)
  matches checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the namespace still reports
  version 1.0.3, so this identity alone does not prove the source/build chain.
  Both fits reported `converged=TRUE`: seed 41003 had gradient norm 0.01319449,
  reported 20-node NLL 312.0581, independent exact marginal NLL 312.8483, and
  exact NLL 312.8282 at the `glmer(nAGQ=25)` candidate (gap +0.0201086); seed
  41008 had gradient norm 0.008018855, reported NLL 378.0112, exact NLL
  379.5786, and reference exact NLL 379.5325 (gap +0.0460531). These are
  measurements, not the 1.0.5 pass/fail metric: the owner-approved acceptance
  is 20-vs-320 parameter agreement, bounded at `0.75` SE per coefficient and
  `0.10` for log sigma; `1e-4` exact-NLL remains only the optimizer-correctness
  gate at 320 nodes. The existing optimizer and start policy are unchanged for
  1.0.5. Retain the broader four-kernel sigma-by-n, current-source/native, and
  comprehensive-row gates until validated with the required provenance.
  **40-node criterion-scope check, 2026-10-20:** a minimal checkout-R
  source-overlay (`pkgload::load_all("R/EDI", compile = FALSE)`) at seed
  41003, `n=200`, 40 groups of five, `n_gh=40`, Newton requested reported
  `converged=TRUE` in two iterations with gradient norm `1.73142`. The kernel
  NLL `312.7547` matched an independently coded R 40-node Gauss-Hermite
  evaluation; that approximation was `0.2912` lower at the returned fit than
  at the `glmer(nAGQ=25)` parameters (`313.0458`). Independent exact NLL
  reversed the ranking: `312.9193` versus `312.8282` (gap `+0.09106`). This
  exceeds the `1e-3` grid marker and `1e-4` exact-NLL allowance numerically,
  but the former was used for boundary-stop classification and the latter is
  the optimizer-correctness gate at 320 nodes. This is a non-boundary 40-node
  diagnostic, not an accepted pass/fail cell. The shipped default is 20 nodes;
  its exact-NLL gap is not the approved 1.0.5 comparator. The owner-approved
  criterion is 20-vs-320 parameter agreement, with coefficient differences
  bounded by `0.75` SE and log-sigma difference by `0.10`. Do not change shared
  optimizer or convergence policy for 1.0.5. Validate the bound with
  current-source/native provenance and complete the broader grid and result-row
  reconciliation gates.
  **Owner decision 2026-10-21 (cheap option for 1.0.5):** the 20-node (shipped)
  acceptance is agreement with the 320-node optimum, not the 1e-4 exact-NLL rule
  (which at 20 fixed nodes would measure quadrature error, not optimizer quality).
  The default node count, optimizer and start policy are NOT changed in 1.0.5.
  The 1e-4 exact-NLL rule stays as the optimizer-correctness gate at 320 nodes.
  **Measured baseline 2026-10-21** (installed EDI 1.0.3, Poisson GLMM, seeds
  41001:41010, Newton and L-BFGS agree to ~1e-3 SE): 20-node vs 320-node optimum,
  max |intercept diff| 0.67 SE, max |slope diff| 0.62 SE (seed 41005), max |log
  sigma diff| 0.084 (seeds 41007/41009 about 0.07); 40 nodes is no better (slope
  up to 0.44 SE, log sigma up to 0.084). Two fits reported `converged = FALSE`
  (seed 41007 Newton at 20 nodes; seed 41001 Newton at 40 nodes). A tight
  tolerance therefore cannot gate the shipped setting; the 1.0.5 criterion is
  the owner-approved non-regression bound at the measured level (|coefficient
  diff| <= 0.75 SE and |log sigma diff| <= 0.10 on these ten fixtures) plus documentation of the
  limitation. Real accuracy is deferred to adaptive quadrature, scheduled for
  v1.2.0 as `performance_profiling_and_upgrades.md → TODO-153`. The numeric bound
  was confirmed by the owner 2026-10-21 ("do (1) and revisit after todo153"):
  |coefficient diff| <= 0.75 SE and |log sigma diff| <= 0.10, enforced by
  `R/package_tests/testthat_bulk/test-poisson-glmm-20-node-vs-320-node-bound.R`
  (seeds 41001:41010, Newton, 20 vs 320 nodes; 20 assertions pass on installed
  EDI 1.0.3). **Revisit the bound after `performance_profiling_and_upgrades.md →
  TODO-153` (adaptive quadrature, v1.2.0) lands.**
  **Installed-package bound recheck, 2026-10-21:** reran that test with
  `timeout 180s Rscript -e` and `library(EDI)`; all 20 assertions passed in
  5.4 seconds. Installed EDI 1.0.3 came from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`, mtime
  `2026-10-21 09:43:34 +0300`), byte-identical to the ignored checkout
  `R/EDI/src/EDI.so`. Test-file SHA-256 was
  `96cf46c3b67ed6a219aeaaff4a871062b48f09f102452447543db1cd8be32509`;
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This rechecks the
  ten fixed Poisson seeds against the installed artifact, but neither DLL
  equality nor this test proves the binary's build/source chain. The broader
  four-kernel grid, current-source/native provenance, and comprehensive-row
  reconciliation remain open; no build/install or canonical output occurred.
  **Diagnostics follow-up (v1.1.0):** `release_v1_1_0.md → TODO-3` (diagnostics
  chain) should surface this gap: `optimizer_diagnostics_report.md` failure mode
  6 (quadrature/node-count inadequacy, currently undetected) and mode 2
  (`converged = (niter < maxit)` mislabeling, which can hide the two
  `converged = FALSE` fits above), via `→ TODO-1` and `SolverDiagnostics`
  (`→ TODO-3`). Debugging aid only; adaptive quadrature stays the fix.
  **Read-only canonical-row provenance inventory 2026-10-18:** the count
  artifact has 14,206 `InferenceCountKKGLMM` rows (all `ok`, 14,206 distinct
  `id`s/307 `case_id`s, 2026-08-24–2026-09-27) and 22 distinct recorded
  `github_commit_id`s; the ordinal artifact has 69,121 `InferenceOrdinalKKCLMM`
  rows (all `ok`, 69,121 distinct `id`s/973 `case_id`s, 2026-08-24–2026-10-09)
  and 22 distinct commit IDs. A read-only ancestry check found zero rows
  stamped with commits descending from the sigma-start fix
  `e706c6f67a6798eea666921155c259a751476feb`; the plan records the exact SHA
  inventories. Row-level joins should use `id`, which includes rep and
  `beta_T`, rather than the broader `case_id`. `github_commit_id` describes
  the source HEAD, not the native library loaded, so this does not establish
  native provenance or current-native acceptance. Keep the optimizer policy,
  native grid, and post-fix row regeneration/audit gates open.
  **Read-only source/artifact identity audit, 2026-10-21:** the approved
  20-vs-320 bound currently has a passing 20-assertion test only for ten
  Poisson GLMM seeds, against an earlier installed EDI 1.0.3 DLL (`0e513077…`).
  The prior 160-fit four-kernel grid is installed-package evidence without a
  current-source build receipt; no provenance-stamped broader-grid output was
  found in the bounded `/tmp` search. Current source files are clean at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; current installed and ignored
  checkout `EDI.so` match at SHA-256 `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`
  (14,727,184 bytes, 2026-10-21 14:12 +0300), but no build manifest attests
  that DLL to the four source hashes. The existing post-fix CI run covers
  focused fixture regressions, not the broad 20-vs-320 grid. Keep current-
  source/native four-kernel bound validation and post-fix comprehensive-row
  reconciliation open; no test, build, install, or canonical output was run
  for this audit.
  - [ ] Validate the owner-approved 20-vs-320 parameter bound (coefficient
    differences <= 0.75 SE; log-sigma difference <= 0.10) on the broader
    four-kernel sigma-by-n grid with current-head native provenance, then
    reconcile provenance-stamped CountKKGLMM/OrdinalKKCLMM comprehensive rows.
  **Ordinal CLMM representative-bound fixture, 2026-10-21:** broadened the
  existing seeded ordinal CLMM reference file with one 40-group × 5-observation
  fixture (seed 301). The 20-node slope is within 0.75 of the 320-node
  treatment-coefficient SE and log sigma differs by at most 0.10; the 320-node
  slope/log sigma also satisfy the existing independent `ordinal::clmm(nAGQ=25)`
  reference tolerances. The focused file passed 38 expectations against
  installed EDI 1.0.3 (library DLL SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`). This
  DLL matches ignored checkout `EDI.so`, but no build/source receipt exists;
  classify as diagnostic installed-artifact coverage only. It covers one
  ordinal CLMM fixture, not current-source/native acceptance, the other
  non-Poisson kernels, the broader sigma-by-n grid, or comprehensive-row
  reconciliation. No build/install or canonical output occurred.
- [x] TODO-32 (added 2026-09-24, source fixed 2026-10-08): **`InferenceOrdinalRidit(
  reference = "treatment")` now uses a non-degenerate symmetric estimand** —
  `../bug_fix_plans/ridit_treatment_reference_degenerate_estimate.md →
  TODO-1..6`. Treatment reference now reports
  `0.5 - mean_control_ridit` with the control-score SE. This is algebraically
  the same empirical Mann–Whitney contrast as the control-reference path and
  preserves the positive-treatment orientation; control and pooled behavior
  remain unchanged. The R class, weighted and resampling hooks, native R and
  Python kernels, docs, tests, NEWS and performance plan are aligned. Eighty-
  three focused R assertions pass without compilation. Python sources parse;
  **Installed R-package recheck 2026-10-14:** the treatment-reference/raw-
  kernel, unweighted/wald/fast-kernel, weighted-bootstrap, and unavailable-
  fit-guard files passed 89 assertions against the reinstalled package (which
  reports 1.0.3); Codex did not compile/build/install. The `edi_kernels`
  Python extension is not installed here; same-HEAD CI validation below
  subsequently closed that gate.
  **Same-HEAD CI validation (2026-10-16):** at
  `430c19bcdb0702d998c79f9058c449449034134c`, R bulk run `38808821543` built
  and installed the checkout and passed all five correctness shards, including
  the three focused Ridit files in the correctness manifest. Python run
  `38808821508` passed the editable-extension pytest coverage job over
  `python/tests` (which includes `test_fast_ridit_analysis.py`) and all three
  platform wheel jobs. This closes linked TODO-6; Python CI provides aggregate
  suite status rather than a per-file result. No local build or artifact
  download was performed.
- [ ] TODO-33 (added 2026-09-24, core fix and regression added 2026-10-07; real-data validation still open): **Randomization-CI
  high-precision refinement ignores `lower`** —
  `../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md →
  TODO-1..4`. Previously, `high_precision_confirm_and_refine_ci_bound()` set
  `u2 <- m` on acceptance, right for a lower bound and wrong for an upper
  bound. The loop now branches by bound direction, and a controlled public-API
  regression exercises both directions by stubbing
  `compute_randomization_ci_pval_cached`; it verifies controlled public
  orchestration with injected p-values, not a real-data permutation-backed
  trigger. Real-data reproduction of the inner loop remains open.
  **Installed-package coverage recheck 2026-10-14:** a
  tier-1 `InferenceContinOLS` simulation (n=32, true effect 1, nominal 90%,
  500 replications, r=201, sequential MC plus full-precision confirmation)
  covered 461/500 (92.2%; exact 95% interval 89.49%-94.39%), including
  nominal 90%. **Real-data trigger search 2026-10-14:** 100 installed-package
  public `InferenceContinOLS` CIs on `mtcars` (`mpg ~ wt + hp`, `r=1001`,
  default controls) had zero errors and zero upper-bound inner refinements.
  The required cheap-span `<= tolerance`, full-span `> tolerance`, and
  bracket-width `> tolerance` condition occurred 0/100 times; 84 cases had a
  wide bracket but full-precision span already `<= tolerance`, while 7 had a
  full-precision span above tolerance but also a cheap span above tolerance.
  Further bounded `mtcars`/`airquality` probes at `r=201`/`1001` likewise
  found no inner entry. **Additional bounded `airquality` probe 2026-10-14:**
  on 111 complete cases (`Ozone ~ Wind + Temp`), 25 seeds at `r=201`,
  `pval_epsilon=0.005`, and 10 seeds at `r=1001`, `pval_epsilon=0.001`, all
  35 calls completed without errors and none entered the upper inner loop;
  all upper delta brackets were already narrower than tolerance. Harnesses
  and CSVs are `/tmp/edi-v105-todo33-airquality-probe.R`,
  `/tmp/edi-v105-todo33/airquality_public_api_ci_probe_r201.csv`,
  `/tmp/edi-v105-todo33-airquality-r1001-probe.R`, and
  `/tmp/edi-v105-todo33/airquality_public_api_ci_probe_r1001.csv`.
  This remains a trigger-search failure, not proof of inaccessibility.
  Harness/results:
  `/tmp/edi-v105-todo33/public_api_probe.R` and
  `/tmp/edi-v105-todo33/mtcars_public_api_ci_probe_r1001.csv`. This is a
  trigger-search failure, not evidence of inaccessibility or unchanged
  coverage; the linked plan's TODO-1 and this release item remain open.
  **Source-loaded focused regression, 2026-10-18:**
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R")`
  passed 30 assertions (0 failures, warnings, or skips). The fixture tests
  both lower and upper directions directly against mirrored analytic normal
  crossings; its public-API case also forces hidden cheap Monte Carlo p-values
  to create wide brackets, observes upper full-precision midpoint evaluations,
  and checks the returned two-sided interval against the independent normal
  score. The source-loaded DLL was
  `/tmp/RtmpJWVK0H/pkgload37242a3e64b573/EDI.so`, MD5
  `dd43c5d0e11708aea17ba82b900f66d1`, matching installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`.
  This validates current R source against the installed native artifact, not a
  rebuilt checkout or a real-data trigger. The TODO-56-gated `trees` search
  below remains open; no trigger search or comprehensive output was run here.
  - [x] Bounded 20-seed `trees` public-API trigger search, 2026-10-19:
    installed EDI 1.0.3, seeds 20261081:20261100, `r=1001`,
    `pval_epsilon=0.005`; 0 errors and 0 eligible upper-bound inner-refinement
    triggers. All upper calls stopped at the cheap p-span check, with two
    fresh full-precision endpoint evaluations and zero midpoint evaluations.
    No candidate/replay RDS was produced. The invocation returned normally,
    but the scratch metadata has no explicit exit-code footer. Script,
    metadata, and CSV are under `/tmp/edi-todo33-ready-20261016/`; their
    SHA-256s are `4cedea54f53f0c3a7a6397fb165c25d5b72270d332b6c095b48121279a08645c`,
    `cbaf672d1b8587ab6c337b72560aea29a5291365df013eb39a6b771fa208fe97`, and
    `b99e918046108aca4cfc52971b8534be3d78f3d65d52ffaf8dc631033f071f3e`,
    respectively. This closes only the bounded-search substep: it found no
    real-data trigger and does not establish branch inaccessibility or validate
    current-checkout native code. TODO-33 remains open pending a
    trigger-producing fixture; if one is found, preserve replay inputs and
    pause for review before the old-branch counterfactual or repeated-trial
    coverage study.
  **Installed-package recheck, 2026-10-20:**
  `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R", reporter = "summary")'`
  passed 37 expectations against EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` MD5
  `a75519a9256c0b3121398032314291d4`. This is controlled/stubbed p-value and
  cache-contract evidence only; no model/permutation fit, real-data trigger,
  or calibration was run. It does not close TODO-1 or the trigger/replay gate.
  **Early-stopped-cache isolation regression, 2026-10-20:** broadened the
  linked bisection reference file with a fixture that places tolerance-small
  noisy Monte-Carlo endpoint p-values in the caller cache, then verifies that
  full-precision confirmation uses its own cache and refines to an independent
  step crossing. It also checks that full-precision evaluations share their
  fresh cache without changing the two caller-cache entries. The focused file
  passed 37 expectations (0 failures, warnings, or skips) with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; p-values are
  stubbed, with no model/permutation fit or calibration run. This closes only
  the test-contract gap; the real-data trigger/replay gate remains open and
  TODO-33 stays unchecked.
  **Additional bounded packaged-data search, 2026-10-21:** the retained
  `datasets::CO2` probe screened 8 new seeds on `uptake ~ conc + Treatment +
  Plant` (n=84; `r=501`, epsilon 0.005, sequential MC). All calls were
  error-free; cheap-span, full-span, and upper-width conditions occurred
  6/8, 1/8, and 6/8 times, with 0 joint triggers. Every confirmation used
  two full-precision endpoints and no midpoint; no trigger bundle was saved.
  The exact settings, command, log hash, loaded DLL provenance, and strict
  joint trigger definition are recorded in
  `../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md`. This is
  another bounded negative screen, not evidence of unreachability or coverage;
  TODO-33 remains open for a real trigger, old-branch replay, and repeated-trial
  coverage comparison.
  **Installed-package diagnostic rerun, 2026-10-21:** the focused test file
  was run with `Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R")'`
  against installed EDI 1.0.3 (welcome banner): 6 failures, 0 warnings, 0
  skips, 54 passes. This does not validate current-checkout R source; no DLL
  hash/path was captured. The then-current fixture diagnostics saw 11 scorer
  records vs 3 cached full calls, t0s lengths 500 and 50 vs the 501-draw
  oracle, two full-call p-value/oracle discrepancies (0.2480 vs 0.251 and
  0.0533 vs 0.251), and the unresolved 4.43 vs 4.04 upper-bound difference.
  The test instrumentation was then corrected to distinguish the MC control
  requested by the outer call from the control active at scorer entry; that
  correction is unvalidated. Current-source validation is still needed to
  determine whether these are stale-installed-R-layer effects or genuine
  behavior. TODO-33 remains unchecked; do not treat these results as a trigger,
  replay, or calibration result.
  **Current-checkout-R/current-user-native focused recheck, 2026-10-21:** after
  confirming no R/Rscript process was active and 16 GiB remained on `/tmp`,
  ran the focused reference file through
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-rand-ci-bisection-and-high-precision-refinement-reference.R", reporter = "summary")`.
  The test completed successfully with no failures reported. The loaded EDI
  namespace was `/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3; the
  temporary DLL was `/tmp/RtmpFsnInz/pkgload25ba783c6/EDI.so`, MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
  byte-identical to both checkout `R/EDI/src/EDI.so` and installed EDI's
  `libs/EDI.so`. No compilation, install, or canonical output write occurred.
  This validates the corrected focused fixture against checkout R and the
  current user-built native library only; it does not establish a real-data
  strict-refinement trigger or close old-branch replay and repeated-trial
  coverage gates. TODO-33 remains unchecked.
  **Negative-search provenance contract, 2026-10-21:** added a TODO-33-only
  pure-R sidecar helper and extended the existing bisection/refinement
  reference test. Completed searches, including zero-trigger searches, now
  have a contract for before/after package/source-payload/DLL/checkout
  provenance, the actual search-runner SHA-256, run settings/environment,
  input data, all per-seed results, and trigger replay paths (which may be
  empty). The focused filtered test passed 9 expectations with installed EDI
  1.0.3; this is a pure-R contract test and does not establish current-checkout
  package provenance or validate a real-data search. A scratch integration is
  staged at `/tmp/edi_todo33_trigger_search_with_provenance_20261021.R`; it
  preserves the existing trigger-positive replay branch and writes a separate
  no-overwrite sidecar. No real-data workload, build/install, or canonical
  output write was performed. TODO-33 remains unchecked pending a real
  permutation-backed trigger/replay and repeated-trial coverage evidence.
  **Synthetic positive trigger/replay fixture, 2026-10-21:** broadened the
  existing public-CI fixed-permutation test with a deterministic 8-by-501
  assignment matrix that reaches upper strict refinement. The test writes and
  reloads a replay bundle plus positive-trigger sidecar, then recomputes the
  upper endpoint from the serialized inputs using a plain-R permutation oracle.
  It also reproduces the pre-fix upper update from parent commit
  `362c5d28fa6233d99d6d6815d1bffa02f5aa33ab`; the old result is on the accepted
  side while the fixed endpoint is on the rejected side. The exact test passed
  35 expectations through checkout R loaded with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`; there was no
  build/install, real-data search, or canonical output write. This is synthetic
  branch/replay and branch-divergence evidence only, not a natural-data trigger
  or coverage result. The real-data old-branch replay and repeated-trial
  coverage gates remain open; TODO-33 remains unchecked.
  **Per-seed sidecar fail-closed guard, 2026-10-21:** the TODO-33 search
  sidecar helper now rejects duplicate/missing seeds and missing trigger
  outcomes before computing `trigger_count`; otherwise repeated or unknown
  seed results could distort the search denominator/count. The existing
  `test-rand-ci-bisection-and-high-precision-refinement-reference.R` now
  covers both invalid cases. Its installed-package run exposed three failures
  in the unrelated refinement-fixture section; the complete file then passed
  with checkout R loaded via
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. This validates
  the pure-R sidecar contract without a build, real-data search, or canonical
  output write; TODO-33's real-data trigger/replay and coverage gates remain
  open.
  **Installed-layer failure detail for that sidecar-guard turn, 2026-10-21:**
  the failing file was the same TODO-33 refinement reference file named above;
  the installed-package output captured three failures in its unrelated
  `scored_upper` fixture: expected length 3 but received 0; the `t0s` vector
  comparison had lengths 0 vs 3; and indexing `scored_upper[[i]]` failed with
  `subscript out of bounds` at test line 347. The captured reporter output did
  not include a total expectation count, so none is inferred here. This is
  distinct from the earlier installed diagnostic recorded above (6 failures,
  54 passes), and from the 9-expectation installed sidecar-only test and the
  later complete-file checkout-R/source-overlay pass. It does not change the
  TODO-33 real-data trigger/replay or coverage gates.
  **Failure triage:** these three errors are a single stale-installed-R-layer
  cascade, not independent regressions or an invalid fixture. The installed
  EDI 1.0.3 R layer does not propagate the supplied full-precision control
  (`mc_enable = FALSE`) to the inference object's active MC state. The fixture
  filters scorer records by that active control, so `scored_upper` is empty;
  the 0-vs-3 `vapply` mismatch and subsequent out-of-bounds access follow. The
  current checkout's `compute_randomization_ci_pval_cached()` scopes the passed
  control onto the private state, and the recorded complete-file source-overlay
  pass supports the fixture under current R source. This explains the installed
  result only: the real-data trigger/replay and repeated-trial coverage gates
  remain open.
  **Positive-trigger replay-path guard, 2026-10-21:** the sidecar constructor
  now rejects positive trigger results with no replay path and any supplied
  replay path that is missing or a directory. A focused inline `Rscript -e`
  test sourced `R/package_tests/todo33_trigger_search_provenance.R` and passed
  6 expectations against installed EDI 1.0.3: negative-result/empty-path
  acceptance, positive-result/empty-path rejection, nonexistent-file
  rejection, and existing-bundle acceptance. This was a pure-R helper test;
  no source load, build/install, model/permutation run, or canonical output
  write occurred. No path-per-trigger rule was added because the current
  schema does not associate replay paths with seed rows. This closes only the
  validator subgate; the real-data trigger/replay/counterfactual and
  repeated-trial coverage gates remain open, so TODO-33 remains unchecked.
  **Retained trigger/replay inventory correction, 2026-10-21 (read-only):**
  the CO2 negative-screen log's temporary `pkgload` DLL MD5
  (`ea0e2f72d87d401db15557e0ecc151c9`) is not today's checkout/installed
  artifact (both currently hash MD5 `a07120a2c7181f9992aa1c4993fcffdf`,
  SHA-256 `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`).
  The retained CO2 (8 seeds), mcycle (6), and swiss (6) logs are all negative
  searches with 0 joint triggers; none has a provenance sidecar, trigger
  replay path, or saved assignment/permutation inputs. The older trees bundle
  likewise has no retained candidate or candidate inputs. The synthetic
  replay fixture is not a natural-data trigger. Thus no real-data failure can
  be reproduced from the retained artifacts. The next acceptance is a
  provenance-stamped trigger-producing search on the approved source/native
  pair, retaining exact replay inputs; then compare the current and old branch
  before the separately required repeated-trial coverage assessment. Details
  and retained log hashes are in
  `../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md`. This
  correction does not close the real-data trigger, replay, or coverage gates;
  no search, build/install, or canonical write was performed.
- [x] TODO-34 (added 2026-09-24, same audit; fixed 2026-10-07): **Interval-censored `compute_shared_icen()` blanket cache guard**
  — `../bug_fix_plans/interval_censored_compute_shared_cache_guard.md →
  TODO-1..4`. After `compute_estimate(estimate_only = TRUE)`, a later full
  call on `InferenceSurvivalLogRank`/`GehanWilcox` under general censoring
  never computes `s_beta_hat_T`, and `compute_asymp_confidence_interval()`
  crashes. Fixed for both classes; focused ordering and interval-reference tests pass without compilation. Same family as the stale-cache fixes.
- [x] TODO-35 (added 2026-09-24, fixed 2026-10-07): **`delta = NA` crash in the incidence g-computation risk ratio** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-1`. Added `any.missing = FALSE` to ordinary and KK g-computation p-values and the same vulnerable Newcombe risk-difference p-value. Focused regression tests pass without compilation.

- [x] TODO-36 (added 2026-09-24, fixed 2026-10-07): **Exact-test classes cannot use the shared weighted estimate** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-2`. Exact-only classes now report a clear unsupported error for bootstrap-weighted estimation; the dead helper calls and six wiring exceptions were removed. Focused exact-class and wiring tests pass without compilation.

- [x] TODO-37 (added 2026-09-24, fixed 2026-10-07): **`inference_class_accepts_model_formula()` is always FALSE** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-3`. The predicate now inspects the effective R6 initializer, including inherited and lazy component methods. `run_all_inference_build_tasks()` now expands requested formulas for eligible classes; the focused regression test passes without compilation.

- [ ] TODO-38 (added 2026-09-24, test-comment audit; **reproduced 2026-09-24 under valgrind: heap overflow from an unvalidated `warm_start_params` length**, see plan TODO-4; **ZOIB kernel length checks implemented and verified 2026-09-24**, sibling source sweep completed 2026-10-09; installed-native recheck 2026-10-14): **Fresh-process crash in `fast_zero_one_inflated_beta_cpp()`** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-4`. In a fresh Rscript the kernel returned `neg_loglik = NaN` and `coefficients = NULL` on ordinary data (8/8 seeds) but not inside testthat, suggesting undefined behavior in the C++ kernel. The direct input-validation test passed 9 assertions against the reinstalled EDI package and under Valgrind Memcheck; the CRAN fast-math test passed 2 assertions. Codex did not compile/build/install. The class was previously verified not to pass malformed starts; the broad sibling-kernel validation remains tracked separately.
  **Source implementation status 2026-10-09:** the ZOIB native guard remains
  fixed, and the successor plan `mixed_kernel_warm_start_shape_guards.md`
  records completed audit, native guard, orphaned-R-helper, and focused-test
  source work (TODO-1..4). Rebuilt-native kernel tests, ASAN/Valgrind, and
  installed comprehensive-CSV reconciliation (TODO-5..6) remain release
  gates, so this checkbox deliberately stays unchecked.
  **Re-audit 2026-10-19 (unchecked; was wrongly `[x]`):** ZOIB guard
  (`fast_zero_one_inflated_beta.cpp:434-435`) and its test exist. NOT DONE:
  `mixed_kernel_warm_start_shape_guards.md` TODO-5 (rebuilt-native kernel
  validation of the sibling kernels) and TODO-6 (ASAN/Valgrind and installed
  comprehensive-CSV reconciliation).
  **Matching-native ZOIB recheck, 2026-10-20:** the checkout's EDI 1.0.3
  install recorded under TODO-63 (DLL SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`)
  passed `test-zoib-kernel-input-length-validation.R` with 9 expectations via
  `testthat::test_file(..., package = "EDI")`. The file covers malformed
  warm-start lengths/shapes and one correctly sized start. The sibling
  `test-mixed-kernel-warm-start-shape-guards-reference.R` had already passed
  23 assertions against the same installed DLL, as recorded under TODO-63.
  TODO-38 remains open for affected-kernel equivalence validation and TODO-6's
  ASAN/Valgrind plus comprehensive-CSV reconciliation; these focused checks do
  not close those gates.
  **Latest installed-artifact guard recheck, 2026-10-20:** against installed
  EDI 1.0.3, the sibling-shape test passed 39 expectations and the CRAN-shipped
  ZOIB kernel input-validation test passed 9 (0 failures, warnings, or skips).
  Installed `EDI.so` SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041` is
  byte-identical to checkout `R/EDI/src/EDI.so`; no build/install occurred.
  This refreshes only input-guard evidence for the available artifact, not
  affected-kernel equivalence or sanitizer validation. TODO-38 remains open
  for TODO-5 kernel-equivalence tests and TODO-6 ASAN/Valgrind plus
  comprehensive-CSV reconciliation.
  **Partial TODO-5 reference, 2026-10-20:** checkout R loaded with
  `pkgload::load_all("R/EDI", compile=FALSE)` passed all 14 assertions in
  `test-glmm-cpp-equivalence.R`, including `fast_poisson_glmm_cpp` against
  `lme4::glmer` with a valid caller warm start. Loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  matched the existing checkout artifact; no build/install occurred. This
  does not prove current C++ source provenance or close the remaining
  equivalence and memory-tool/data-reconciliation gates.
  **TODO-5 provenance audit, 2026-10-20:** three sequential compile-free
  checkout-R references passed: hurdle NB (29 assertions; 11 `pscl` `.Names`
  deprecation warnings), Poisson GLMM (29; no warnings), and Weibull-frailty
  class/kernel/`survreg` (7; no warnings). The checkout and installed EDI 1.0.3
  DLLs are both 14,727,184 bytes and SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
  installed metadata reports Built 2026-10-20 07:40:04 UTC, after HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Identity/timestamps do not
  provide a source/build/flag manifest or per-test loaded-DLL sidecar. These
  references are not current-source native validation; TODO-5 remains open.
  **Memory-tool coverage audit, 2026-10-20:** the sanitizer and Valgrind jobs
  run the shipped testthat suite, whose `test-kernel-warm-start-length-contracts.R`
  covers malformed Fisher matrices for the sibling exports but not malformed
  `warm_start_params` for those TODO-38 entries. The extended cross-kernel
  regression remains outside the shipped test tree. This is a workflow and
  test-inventory finding, not a passing memory-tool run; TODO-6 remains open.
  **Additional installed-artifact valid-fit references, 2026-10-21:** the
  focused Gaussian LMM kernel test passed 17 expectations and the ordinal
  GLMM/`clmm` kernel test passed 37, sequentially via
  `testthat::test_file(..., package='EDI')` against installed EDI 1.0.3.
  Loaded `EDI.so` SHA-256 was
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  These add independent valid-fit checks for two previously unrecorded
  kernels, but validate only the installed artifact: current-head native
  provenance, ASAN/UBSAN and Valgrind execution, and comprehensive-row
  reconciliation remain open.
  **Current installed-artifact kernel sweep, 2026-10-21:** against the same
  installed EDI 1.0.3 DLL (SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`), the
  zero-augmented Poisson/`pscl` fit reference, hurdle negative-binomial/`pscl`
  reference, Poisson-GLMM quadrature/`glmer` reference, GLMM equivalence file,
  and Weibull-frailty/`survreg` reference all passed via `testthat::test_file()`.
  The two `pscl` comparisons emitted only upstream `.Names` deprecation
  warnings; the other three were warning-free. Together with the Gaussian and
  ordinal tests above, this adds current-installed valid-fit reference
  coverage across the recorded kernel families. The ZOIB Hessian fallback
  reference and hurdle-Poisson GLMM score/Hessian/input-guard reference also
  passed against the same installed DLL. This remains installed-artifact
  evidence, not rebuild-backed or memory-instrumented validation. The
  malformed-`warm_start_params` ASAN/
  Valgrind gate and comprehensive-row reconciliation remain open.

  **Latest installed malformed-start sweep, 2026-10-21:**
  `test-mixed-kernel-warm-start-shape-guards-reference.R` passed all 39
  expectations against installed EDI 1.0.3, with loaded DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  This updates the sibling shape-guard evidence for the current installed
  artifact; it does not validate the unbuilt checkout C++ change or provide
  ASAN/UBSAN, Valgrind, or comprehensive-row evidence.
  **CRAN-shipped sibling parameter guards, 2026-10-21:** broadened the
  existing `R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R`
  with short/long `warm_start_params` checks for the seven sibling kernels
  and zero-augmented-Poisson wrapper (16 assertions). The focused fresh-R
  process passed all 220 expectations against installed EDI 1.0.3; its DLL
  SHA-256 is `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  byte-identical to checkout `R/EDI/src/EDI.so`. This puts the primary length
  guards in the shipped suite automatically run by sanitizer/Valgrind
  `R-CMD-check` jobs, but no such workflow was run here. At this point the
  non-finite parameter cases were still bulk-only; source/build provenance
  and comprehensive-row reconciliation also remained open.
  **Shipped-suite non-finite sibling-start inventory, 2026-10-21:** the same
  fast-tier test now asserts rejection of correctly sized `NaN` and `Inf`
  starts for each of the seven sibling kernels (14 added assertions). This
  adds the finite-value guard branch to the shipped suite used by
  ASAN/UBSAN/Valgrind check jobs, but this task did not run R or those jobs.
  At the time of this note, the added expectations had not yet been executed;
  see the installed-artifact recheck below. TODO-5 current-source
  native provenance/equivalence, TODO-6 actual instrumented workflow results,
  the zero-augmented-Poisson non-finite diagnostic, non-finite Fisher-info
  cases, and comprehensive-row reconciliation remain open.
  **Installed non-finite sibling-start recheck, 2026-10-21:** the shipped
  `test-kernel-warm-start-length-contracts.R` passed all 234 assertions in a
  fresh `Rscript` against installed EDI 1.0.3 (0 failures, warnings, or skips;
  exit 0), including the 14 correctly sized NaN/Inf start guards. The loaded
  installed `EDI.so` SHA-256 is
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`, byte-
  identical to checkout `R/EDI/src/EDI.so` (both 14,727,184 bytes). No build,
  compile, or install occurred. This confirms behavior in the currently
  installed artifact and its identity with the checkout's existing binary;
  it does not authenticate that binary to the tracked C++ sources or replace
  the actual ASAN/UBSAN, Valgrind, current-source provenance, equivalence, or
  comprehensive-row gates.
  **Additional installed reference sweep, 2026-10-21:** seven focused valid-fit
  reference files passed against installed EDI 1.0.3 / `EDI.so` SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`:
  Gaussian LMM (17 assertions), hurdle NB/`pscl` (29; 11 upstream `.Names`
  deprecation warnings), GLMM equivalence (17; logistic, hurdle-Poisson and
  Poisson), ordinal GLMM/`clmm` (37), Poisson GLMM/`glmer` (29), Weibull
  frailty/`survreg` (7), and zero-augmented Poisson/`pscl` (27; six upstream
  `.Names` deprecation warnings). These independent references extend
  installed-artifact valid-fit coverage only; they do not supply a current-head
  native build manifest, instrument malformed starts under ASAN/UBSAN or
  Valgrind, or reconcile comprehensive rows. TODO-38 remains open for those
  native/memory/data gates.
  **Shipped guard regression recheck, 2026-10-21:** after adding the missing
  non-finite Fisher and zero-augmented-Poisson diagnostic assertions to the
  shipped `test-kernel-warm-start-length-contracts.R`, its focused installed-
  package run passed all 243 expectations (0 failures, warnings, or skips) on
  EDI 1.0.3. Loaded `EDI.so` SHA-256:
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This confirms only the installed artifact/test behavior; the hash does not
  prove that the DLL was built from current checkout C++ sources. No rebuild,
  ASAN/UBSAN job, or project Valgrind job was run; those and comprehensive-row
  reconciliation remain open.

  **Checkout-R/current-native valid-fit reference rerun, 2026-10-21:** with
  `pkgload::load_all("R/EDI", compile=FALSE)`, seven focused references passed
  (163 assertions total): Gaussian LMM (17), hurdle NB/`pscl` (29; 11 upstream
  `.Names` deprecation warnings), GLMM equivalence (17), ordinal GLMM/`clmm`
  (37), Poisson GLMM/`glmer` (29), Weibull frailty/`survreg` (7), and
  zero-augmented Poisson/`pscl` (27; six upstream `.Names` deprecation
  warnings). The checkout namespace was `/home/kapelner/workspace/EDI/R/EDI`;
  the temporary loaded DLL SHA-256 was
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`, matching
  the latest user-built artifact recorded above. No compilation, build, or
  install occurred. This validates checkout R code with that native artifact
  for valid-fit independent references; it does not provide a reproducible
  source/build manifest, malformed-start memory-tool validation, or
  comprehensive-row reconciliation. TODO-38 remains open for TODO-5 native
  provenance/equivalence and TODO-6 ASAN/UBSAN, Valgrind, and comprehensive
  row gates.

  **Native artifact/memory-job audit, 2026-10-21:** successful ASAN/UBSAN
  (job `117626532715`) and Valgrind (`117626532797`) checks are retained in
  run `39110868823` at commit `4d2531e97bc0636d3409003576a5766d15a308d0`.
  The eight affected C++ files have unchanged Git contents through current
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but the run predates the
  2026-10-21 shipped malformed-sibling-start assertions; fresh instrumented
  jobs must confirm those assertions actually execute. Current installed and
  checkout DLLs match (SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`), and
  generated user-build metadata reports `EDI_UNITY=1`; this is artifact/config
  identity, not a source/object manifest. The retained local TODO-38 Valgrind
  logs are inconclusive (one has no test summary; another fails loading R's
  `tools.so` before EDI tests). Keep fresh ASAN/UBSAN/Valgrind execution, TODO-5
  current-source build/equivalence provenance, and comprehensive-row
  reconciliation open.

  **Malformed-start/CI reconciliation, 2026-10-21:** the current shipped
  `test-kernel-warm-start-length-contracts.R` has SHA-256
  `c938ce677076ac16df6d9de6700922cc3a8e967c941d277b1ef51f319dfd866c`
  (184 insertions, 8 deletions versus HEAD), including the newly added sibling
  parameter-length and NaN/Inf start cases. The successful retained ASAN/UBSAN
  and Valgrind jobs in run `39110868823` used commit
  `4d2531e97bc0636d3409003576a5766d15a308d0`; the shipped test at that commit
  has SHA-256 `18af939b192e9e008464f81b649ea2e97bf6f0aa2a7d212fa2ee145529db8aaa`,
  equal to current HEAD but not this dirty test file. Therefore those jobs did
  not exercise the new malformed-start assertions. The 243-expectation
  installed-package run is not instrumented and lacks a recorded test-file
  hash; the local Valgrind logs are not valid runs (banner-only, or startup
  failure loading `tools.so` before EDI tests). TODO-6 requires fresh
  ASAN/UBSAN and Valgrind jobs at a commit containing the test changes with
  output confirming those cases ran. TODO-5 separately requires an attested
  current-source build/object manifest with `EDI_UNITY=0`; the available
  `EDI_UNITY=1` metadata and matching DLL hashes do not establish source
  identity. Comprehensive-row reconciliation remains open.

- [x] TODO-39 (added 2026-09-24, fixed 2026-10-07): **Oversized greedy optimal block from multiple leftovers** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-5`. The fallback did see leftover subjects, but could assign several to one block (`n = 8`, `B = 3` yielded sizes `4,2,2`). It now chooses the nearest block below `ceiling(n / B)`, yielding `3,3,2`; focused allocation and randomization-inference tests pass without compilation.

- [x] TODO-40 (added 2026-09-24, fixed 2026-10-07): **Zero-length estimate instead of `NA` on sparse weights** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-6`. The incidence risk-difference weighted refit now retains the treatment column or returns scalar `NA_real_` with a typed nonestimable reason. Sparse and ordinary weighted-refit tests pass without compilation.

- [x] TODO-41 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced; installed-native recheck 2026-10-14): **Unchecked callback result in the randomization loop** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-7`. `randomization_loop_cpp()` now rejects a length-0 callback result before indexing, and its focused callback-contract regression passed all 32 assertions against the user's reinstalled EDI binary (reported version 1.0.3). Codex did not compile/build/install.

- [x] TODO-42 (added 2026-09-24, closed 2026-10-08): **Stale Bayesian-bootstrap worker workaround is no longer needed** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-8`. The Cox regression already exercises randomization, nonparametric bootstrap and Bayesian bootstrap on one object. A matching `InferenceSurvivalKMDiff` regression now compares the reused object's Bayesian distribution and p-value bit-for-bit with a fresh object after both earlier resampling calls. Eighteen focused assertions pass without compilation; no stale worker was reproduced.

- [x] TODO-43 (added 2026-09-24, closed 2026-10-08): **The reported IVWC frailty RNG sensitivity was a mismatched-estimator fallback** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-9`. Direct fits were finite and RNG-invariant on the exact fixture and a 100-seed sweep. Previously, a nonfinite direct Clayton/Weibull result on the constant-weight path fell through to a different marginal-Weibull surrogate, creating the appearance that the same fit had changed. Constant weights now return the direct estimator's result, including `NA`; varying weights retain the surrogate. Forty-nine focused assertions pass without compilation.

- [x] TODO-44 (added 2026-09-24, fixed 2026-10-07): **Silent `NA`
  results with no recorded reason** —
  `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-10`.
  Jackknife summaries with fewer than two replicates now record
  `jackknife_too_few_replicate_estimates`; subsampling and m-out-of-n
  selection failures record their existing typed reason under either
  hardening setting. Focused tests cover failure and successful-selector
  paths without compilation.

- [x] TODO-45 (added 2026-09-24, fixed 2026-10-08): **Weighted-refit SEs are populated when requested** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-11`. Plain modified Poisson now caches a weighted HC0 SE, `InferenceIncidKKModifiedPoisson` caches a weighted cluster-sandwich SE, and all four Weibull surrogate callers cache the model or cluster-robust `survreg` SE. `estimate_only = TRUE` still skips variance work, and constant-weight shortcuts honor the flag. Six focused suites pass 105 assertions without compilation; studentized Bayesian-bootstrap smoke checks return finite p-values.

- [x] TODO-46 (added 2026-09-24, closed 2026-10-08): **Cosmetic / minor list audited** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-12`. The dead stratification stop was already absent; stale test commentary was removed and the shared categorical-strata guard gained a direct numeric-stratum regression. Nested `$` prefixes are now documented as an intentional conservative contract. The R Weibull fallback's `estimate_only` limitation and the cross-family `with_var` field differences are explicitly documented and pinned, with `fisher_information` retained as the common contract. Across TODO-42 and this batch, 184 focused assertions pass without compilation.

- [x] TODO-47 (added 2026-09-24, closed 2026-10-09; found via a dedicated cross-class
  investigation fork re-running `audit_comprehensive_results.R`'s
  `low_coverage` check for the first time against real data — medium
  confidence, likely NOT a bug): `InferenceIncidLogRegr` (21 findings) and
  `InferenceIncidProbitRegr` (21 findings) both show broad, mild, uniform
  OVER-coverage (0.97-0.998 vs. 0.95 target) across nearly every
  `function_run` family, both formulas — `../bug_fix_plans/investigate_incid_logregr_probitregr_coverage.md`.
  **`TODO-28` ruled out** — the pattern hits purely asymptotic methods
  with zero resampling involved, same magnitude as bootstrap-family
  methods, which a resampling-cache bug can't explain. Two candidate
  explanations, not fully distinguished: (1) a non-collapsibility
  truth-mismatch for `LogRegr` specifically (same family as `TODO-10`'s
  fix — written using this file's *old*, pre-split `release_v1_1_0.md`
  numbering where that fix was `TODO-32`; corrected 2026-09-24, see
  `_master.md`'s still-outstanding old-numbering references for the same
  drift elsewhere), or (2) ordinary benign Wald/LR-type CI conservativeness for
  binary-outcome GLMs — favored, since `InferenceIncidProbitRegr` uses
  MC-refit truth (immune to (1)) yet shows the identical pattern,
  matching this session's earlier RiskDiff/RiskRatio "not a bug"
  precedent. One outlier noted separately: `InferenceIncidProbitRegr ~1
  compute_jackknife_wald_confidence_interval` is UNDER-coverage (0.926),
  opposite direction, possibly connected to `TODO-29`'s `jackknife_wald`
  finding. Also a smaller, unconfirmed `biased_estimate` finding for
  `InferenceIncidLogRegr ~.` (plausibly ordinary uncorrected finite-sample
  logistic-MLE bias). **Resolution:** the truth-scale cross-link is already
  implemented. A deterministic 3,000-replicate correctly specified logistic
  simulation confirmed ordinary finite-sample MLE bias that grows with the
  covariate-count/sample-size ratio and falls sharply by `n=200`. Shared
  jackknife-Wald inference now centers on the bias-corrected jackknife
  estimate. Two focused files pass 30 assertions without compilation, and all
  linked-plan subtasks are closed.
- [x] TODO-48 (added 2026-09-24, fixed/audited 2026-10-09; same source — initially
  medium-low confidence with root cause unresolved): the count-family GLM `low_coverage`
  cluster — `InferenceCountPoisson`, `InferenceCountNegBin` (broad
  ~0.85-0.93 undercoverage across both asymptotic AND most resampling
  methods simultaneously), `InferenceCountZeroInflatedPoisson`
  (asymptotic-only, no bootstrap-family components) — 50 findings total —
  `../bug_fix_plans/investigate_count_glm_family_coverage.md`. **`TODO-28`
  cleanly ruled out for all 3** — `InferenceCountPoisson`/`InferenceCountNegBin`
  build their design matrix inline from `private$get_X()`, never touching
  `create_design_matrix()`'s cache. Most promising unconfirmed lead: none
  of these 3 classes appears in `comprehensive_tests.R`'s
  `COVERAGE_CLOSED_FORM`/`COVERAGE_MC_SPEC` tables, so coverage checking
  falls back to raw `beta_T` as ground truth — same harness-gap shape as
  `InferenceAllSimpleMeanDiffPooledVar`'s prior coverage bug and `TODO-10`'s
  fix (same old-numbering correction as TODO-47 above) — but in tension with the fact that nonparametric resampling
  methods (which should be immune to a truth-value mismatch) show the
  same undercoverage; flagged as an open tension, not resolved either
  way. Secondary candidate: genuine DGP overdispersion NegBin's dispersion
  parameter may not fully absorb (benign DGP-mismatch, not a package
  bug). **Resolution:** Poisson's explicit approximate and best-available
  Bartlett likelihood-ratio p-value/CI entry points now use the same
  jackknife max/union as its sibling likelihood methods. A four-entry-point
  regression passes as part of a 26-assertion focused file. NegBin/ZIP parity
  and the later audit support benign small-sample joint-MLE bias; direct
  estimate-resampling intervals retain their generic semantics and are
  explicitly outside the design-conservative union. All linked-plan subtasks
  are closed.
- [x] TODO-49 (added 2026-09-24, resolved/refuted 2026-10-09; same source — medium confidence): `InferenceContinQuantileRegr`'s 33 `low_coverage`
  findings, the single largest uninvestigated cluster in this audit
  wave — `../bug_fix_plans/investigate_contin_quantile_regr_coverage.md`.
  Ruled out the obvious hypothesis (missing `COVERAGE_MC_SPEC` truth
  entry, the pattern that already explained `LogRank`/`GehanWilcox`/`Ridit`) —
  confirmed absent from the registry, but a direct distributional argument
  shows the raw-`beta_T` fallback is actually CORRECT here (the harness's
  continuous DGP is a deterministic additive shift, so the true median
  effect equals `beta_T` exactly, marginally and covariate-conditionally;
  no estimand-scale mismatch). Root cause remains open: two unconfirmed
  candidates — `quantreg`'s `"nid"` sandwich SE possibly misbehaving under
  the harness's small/near-noiseless noise scale, or compounding with the
  pre-existing `TODO-20` tie-sensitivity hypothesis for resampling-family
  methods specifically. **Resolution:** no implementation defect is supported:
  the raw treatment shift is the correct truth, reusable workers invalidate
  every dependent cache on sample/assignment change, and weighted QR disables
  factorization reuse. The residual finite-sample calibration behavior is a
  property of `quantreg`'s documented `nid` SE, not a v1.0.5 bug. Focused
  source-loaded checks passed 14, 48, and 55 expectations.

- [x] TODO-53 (added 2026-09-24; replay correction implemented; approximate default accepted 2026-10-20): **Randomization
  p-values are conservative at the null under
  `DesignSeqOneByOneKK21stepwise` (incidence)** —
  `../bug_fix_plans/investigate_kk21stepwise_incidence_randomization_pval_conservative.md →
  TODO-1..4`. 60 simulated nulls: 0 rejections, median p 0.71, mean p 0.66;
  `InferenceAllSimpleAverageDiff` gives identical p-values, so it is shared
  design-replay/randomization machinery, not the g-computation class. Costs
  power (0.183 vs 0.317 for the Wald test at `beta_T = 0.5`); not a validity
  failure. **Replay correction:** KK21 inherited KK14's fixed-realized-pair
  redraw, which is invalid once outcome-adaptive weights make pair formation
  depend on the assignment path. Plain `DesignSeqOneByOneKK21` keeps that
  redraw because its marginal weights do not depend on assignment. For
  `DesignSeqOneByOneKK21stepwise`, full sequential replay while exposing only
  prior responses is opt-in via
  `condition_on_ws_for_rand_tests = FALSE`; the default `TRUE` remains the
  faster approximate fixed-pair redraw. The tests cover exact replay across
  incidence/continuous/count and separately cover the default pair-conditioned
  behavior. The historical report of 90 assertions has not been re-measured
  in this reconciliation. Inclusive exact tails remain unchanged to preserve
  the finite-sample conservative convention.
  **Contract re-audit 2026-10-20:** commit
  39e3ca04 (2026-10-13) reworked this after the 2026-10-09 closure. Plain
  `DesignSeqOneByOneKK21` (`DesignSeqOneByOneKK21.R:351-354`) now inherits
  KK14's `draw_ws_raw`, declared exact because its weights do not use `ws`.
  Full sequential replay exists only in `DesignSeqOneByOneKK21stepwise`
  (`design_seq_one_by_one_KK21_stepwise.R:195-232`) and only when
  `condition_on_ws_for_rand_tests = FALSE`; the default (`TRUE`) uses the
  fixed-pair redraw and is documented as "approximate, not exact". The linked
  plan and this entry now reflect that contract. Remaining gates: (1) an owner
  decision on whether the default approximate stepwise path is acceptable given
  the original conservative-p-value complaint; (2) the historical "90
  assertions" source-loaded count remains unexplained. A fresh installed EDI
  1.0.3 run, `Rscript -e 'library(EDI); testthat::test_file("R/EDI/tests/testthat/test-permutations.R")'`,
  passed 117 assertions on 2026-10-20; this is not a replay of the historical
  source-loaded run or current-checkout native validation. See the linked plan
  for the provenance limitation. **Current-source recheck 2026-10-20:**
  `Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE); testthat::test_file("R/EDI/tests/testthat/test-permutations.R")'`
  also passed 117 assertions (0 failures, warnings, or skips). R sources came
  from this checkout; native calls used the available installed EDI 1.0.3
  library at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, built
  2026-10-19 23:31:50 IDT under R-devel r90668, with `EDI.so` MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59`. No checkout compile occurred. This does
  not validate a rebuilt current-head native package or recover the historical
  90-assertion run's exact source/runtime. The remaining
  release blocker is the owner's decision on the approximate default, not a
  missing test pass.

  **Owner decision 2026-10-20 — approximate default accepted.** Paired null
  simulation, recompiled install (EDI 1.0.3 string): `DesignSeqOneByOneKK21stepwise`,
  incidence, n = 148, one covariate, outcome depends on the covariate with no
  treatment effect, r = 151, 200 experiments, same data/observed design/draw
  seed in both arms, mean-difference statistic computed directly from
  `draw_ws_according_to_design()` draws (inclusive tails). `TRUE` (default):
  reject@0.05 0.030, @0.10 0.085, mean p 0.550, median 0.579. `FALSE` (exact
  replay): 0.030, 0.090, 0.542, 0.556. Mid-p is near uniform in both (KS
  p = 0.17/0.25). Paired p-values correlate 0.986 (mean diff -0.008, SD
  0.048); mean SD of the reference draws 0.0797 vs 0.0792 (ratio 0.999);
  ties about 4% of each reference distribution. The residual inclusive-tail
  conservatism is the documented discreteness effect, not the redraw
  approximation. **Caveat (verified 2026-10-20 on the same 200 experiments):**
  the original 60-null result (median p 0.71) came from the Zhang exact
  combined test, not these draws: the public-API p-value had reject@0.05
  0.010, @0.10 0.020, mean 0.723, median 0.816 (correlation with the
  draw-based p-values 0.70), versus 0.030/0.085/0.550/0.579 for the draws.
  Zhang is now removed from the default p-value (TODO-99):
  `compute_rand_two_sided_pval()` returns it for matched/Bernoulli incidence
  designs (`should_use_zhang_incidence_randomization()`), so
  `condition_on_ws_for_rand_tests` cannot affect that p-value. Single configuration only (one covariate, one statistic,
  incidence); the 95% interval on a 0.05 rejection rate at 200 reps is about
  +/-0.03.

- [x] TODO-54 (added 2026-09-24, fixed 2026-10-08):
  **`InferenceSurvivalKMDiff` Bayesian-bootstrap p-values tolerate occasional
  undefined weighted medians** —
  `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-13`. The
  class-specific wrapper now defaults to dropping non-finite draws and uses
  the existing minimum-finite-draw guard and typed
  `bayesian_bootstrap_too_few_finite_estimates` reason. Callers can still set
  `na.rm = FALSE` to retain fail-on-any-nonfinite behavior. Forty-one focused
  assertions pass without compilation, including the censored reproduction,
  generic guard contract and same-object composition regression.
- [ ] TODO-55 (added 2026-09-25, core fix implemented 2026-10-07;
  regeneration/re-audit still open; found checking other
  proportion classes for
  `TODO-16`/plan `TODO-11`'s pattern; root-caused, high confidence, not the
  same mechanism): **Proportion mean-diff closed-form coverage truth is
  stale relative to the 2026-09-15 DGP fix** —
  `../bug_fix_plans/prop_mean_diff_closed_form_truth_stale.md`.
  The closed form now uses the clamped-baseline, zero-noise logit-shift
  contrast; the audit also gave proportion Wilcox a response-qualified Monte
  Carlo truth.
  Eighteen focused assertions pass, and stale-row rules register every
  affected historical row for regeneration. Re-auditing and pruning the
  baseline remain after those rows regenerate.
  Before this fix, `compute_prop_mean_diff_coverage_truth()` computed the
  truth via a raw additive shift clamped to `[0, 1]`, but the actual
  proportion DGP had been fixed 2026-09-15 to shift on the **logit scale**
  (baseline clamped to `[0.05, 0.95]` first) specifically to avoid this
  exact boundary distortion — the truth function had never been updated to
  match (the sibling
  incidence closed form, `incid_p_base_and_treated()`, already implements
  the correct pattern; looks like an omission when the DGP fix landed).
  Affects `InferenceAllSimpleAverageDiff`/`InferenceAllSimpleMeanDiffPooledVar`/
  `InferencePropGCompMeanDiff`. Severe where it hits: 0.00 coverage on
  `boston` (hundreds of rows, all post-fix), while `diamonds`/most `abalone`
  rows happen to predate the DGP fix and so are self-consistently (but
  separately) stale rather than mismatched. Verified directly: `boston`'s
  real per-row estimate (mean 0.109, SD 0.021, n=122) matches the corrected
  logit-scale truth (0.112) almost exactly, against the stale formula's
  0.466 (17+ SDs off). The small test-harness-only formula change now mirrors
  the incidence sibling; the historical rows have not yet regenerated.
  **Open estimand-semantics choice (2026-10-18):** the proportion DGP also
  adds `N(0, 0.1)` noise inside the logit transform, while the corrected
  closed form omits that noise and is the zero-noise conditional contrast.
  Its exact noisy marginal-mean contrast may differ. This is not classified
  as a TODO-55 defect and does not change the implemented formula; a
  maintainer must confirm which estimand coverage truth is intended to use.
  **Owner decision 2026-10-21: noisy marginal truth.** The DGP adds the
  `N(0, SD_NOISE)` logit noise in both arms and the estimator is a difference
  of observed proportion means, so coverage truth is the noisy marginal
  contrast `E[p_t(eps)] - E[p_c(eps)]`. Implemented in
  `comprehensive_tests.R` (`prop_logistic_normal_mean`, 40-node Gauss-Hermite;
  `compute_prop_mean_diff_coverage_truth` now uses it); it differs from the
  zero-noise closed form by at most ~3e-4 at `SD_NOISE = 0.1`. The focused
  test file now pins it against an independent `integrate()` oracle and passed
  28 assertions, and the registry-gaps file passed 70, against installed EDI
  1.0.3 (pure-R harness code, no compile). Regenerating the proportion rows
  (which now use the new truth) and the baseline re-audit remain open.
  **Retained-artifact and bounded-test audit, 2026-10-21:** the canonical
  `comprehensive_tests_results_nc_1_proportion.csv` (84,170,816 bytes,
  2026-10-09), the broad affected-class filtered CSV (108,804,685 bytes,
  2026-10-09), and the later Boston Wald smoke CSV (28,732 bytes,
  2026-10-14) all predate the noisy-marginal owner decision. The retained
  `/tmp/edi-todo55-{sweep,isolated,smoke}` outputs/source snapshots are from
  2026-10-16 and likewise cannot establish rows generated under the selected
  truth; the isolated snapshot also carries the pre-run audit baseline. No
  retained artifact closes full proportion-row regeneration or the subsequent
  baseline re-audit/pruning. With no competing R/Rscript process, the existing
  pure-R `test-comprehensive-proportion-coverage-truth-reference.R` was run
  with a 60-second cap and passed all 28 expectations (exit 0, no build or
  install). This confirms the current helper/independent quadrature oracle and
  CI grading fixture only; it does not validate regenerated comprehensive
  rows. The canonical result files were not changed.
  Independent of
  `mc_coverage_truth_covariate_mismatch.md`'s TODO-6/TODO-11 — different
  mechanism (closed-form path, not Monte-Carlo), different classes, do not
  conflate when resolving either.
  **Checkout-source focused recheck 2026-10-20:**
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE,
  export_all = FALSE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-proportion-coverage-truth-reference.R", reporter = "summary")`
  passed all 18 assertions (no failures, warnings, or skips) at checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. The test extracts and evaluates
  only named R assignments from the checkout harness and does not call native
  code. Pkgload reused existing EDI 1.0.3 `EDI.so`; its SHA-256 matches the
  checkout source DLL (`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`).
  This does not choose the noisy-versus-zero-noise estimand and does not
  replace comprehensive-row regeneration or baseline re-audit.
  **Candidate-estimand regression, 2026-10-20:** the existing focused file
  now also tests that `record_result()` grades a CI against the selected
  zero-noise coverage truth rather than `beta_T`, and independently computes
  the noisy logistic-normal marginal candidate by quadrature at five fixed
  baseline probabilities. The complete file passed 26 assertions with
  `pkgload::load_all("R/EDI", compile = FALSE, export_all = FALSE)` and no
  failures, warnings, or skips. This pure-R test is decision-support only: it
  adds no marginal-truth API and does not choose or change the default
  estimand. The owner choice, regenerated proportion rows, and baseline
  re-audit remain open.
  **Noisy-marginal row-grading regression, 2026-10-21:** the existing focused
  test now verifies `record_result()` stores/grades against an independent
  `integrate()` oracle at the DGP's `SD_NOISE=0.1`, rather than forcing the
  prior zero-noise case. It also checks the selected helper against retained
  five-point quadrature reference values. The exact command
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-proportion-coverage-truth-reference.R")'`
  passed 29 expectations with no failures, warnings, or skips. This is a
  pure-R checkout-harness test run with installed EDI 1.0.3 loaded; the test
  extracts named assignments from current `comprehensive_tests.R` and stubs
  attempt-event logging, so it does not validate native behavior or the event
  ledger. The test is already registered in both bulk correctness and
  coverage tiers. No compile/install, comprehensive-result run, or canonical
  write occurred. Full affected-row regeneration and baseline audit/pruning
  remain open.
  **Resume-cache invalidation correction, 2026-10-21:** the four TODO-55
  class-wide `stale_ok_row_rules.csv` cutoffs were `2026-10-08`, but pruning
  matches only rows with dates strictly before the cutoff; canonical rows
  dated 2026-10-09 therefore remained cache-eligible after the noisy-marginal
  decision. All four cutoffs are now `2026-10-22`, expiring prior function
  runs for the three mean-difference classes and proportion Wilcox. The
  existing pruning safety test now verifies the actual checked-in rules by
  retaining synthetic cutoff-day rows and removing 2026-10-09/2026-10-21
  rows. `Rscript -e
  'testthat::test_file("R/package_tests/testthat_bulk/test-prune-stale-result-rows-safety-reference.R")'`
  passed 18 expectations with no failures, warnings, or skips; it uses only
  synthetic temporary data/repository state. No canonical CSV was modified.
  Since pruning is date-granular, start regeneration only when the actual R
  process's local date is 2026-10-22 or later: row timestamps use
  `format(Sys.time(), ...)` without an explicit timezone and pruning compares
  the first ten characters only. Record the process timezone alongside run
  provenance; the 2026-10-22 00:00:00 synthetic row is the inclusive local-date
  boundary. First confirm the runner is loading the authenticated current EDI
  package/DLL and current coverage-truth source, then use an isolated candidate
  output and exact-key/value/provenance checks before any canonical rerun.
  Full proportion-row regeneration and baseline audit/pruning remain open.
  **Retained-artifact inventory, 2026-10-21:** the canonical filtered CSV has
  140,960 unique rows for the four affected classes (43,998
  `InferenceAllSimpleAverageDiff`; 7,585 `InferenceAllSimpleMeanDiffPooledVar`;
  69,643 `InferencePropGCompMeanDiff`; 19,734 proportion
  `InferenceAllSimpleWilcox`). All are `status=ok`, unique, and dated
  2026-10-09, with no provenance sidecar; the broader proportion CSV contains
  none of these classes. The retained `/tmp/edi-todo13-*` pilots are
  PropGComp-only: 29 CSVs, 3,120 rows, 1,740 unique IDs and 1,380 repeats, all
  dated 2026-10-20/21. Twenty-eight have hash-matching sidecars, but the
  receipts span six runner/payload/DLL/HEAD cohorts; one CSV lacks a sidecar.
  These incomplete pre-cutoff pilots do not satisfy the four-class gate. No
  run, canonical write, or pruning occurred. The remaining gate is a fresh
  isolated four-class regeneration on or after the R process's local
  2026-10-22 date, with timezone and matching current package/DLL and
  coverage-truth provenance, followed by exact-key/value validation and
  baseline re-audit/pruning. The checklist remains open.
  - [ ] Regenerate the full proportion rows for
    `InferenceAllSimpleAverageDiff`,
    `InferenceAllSimpleMeanDiffPooledVar`, `InferencePropGCompMeanDiff`, and
    proportion `InferenceAllSimpleWilcox`; then rerun the baseline audit and
    prune only findings resolved by those rows. Do not start the canonical
    run while TODO-56 is using the shared result paths.
- [ ] TODO-56 (added 2026-10, found investigating why incidence-response
  power looked low across every design; **core fix implemented and verified
  same session; release follow-ups still open**):
  **`InferenceIncidModifiedPoisson`'s non-robust SE was
  severely over-conservative** —
  `../bug_fix_plans/modified_poisson_naive_se_miscalibration.md`. The
  model-based Poisson Fisher-information SE this class used overstates the
  true sampling variance for a binary outcome (Poisson assumes
  \(\mathrm{Var}(Y_i)=\mu_i\); the truth is Bernoulli,
  \(\mathrm{Var}(Y_i)=p_i(1-p_i)\le\mu_i\)) — measured at 0.26% empirical
  Type-I error against a nominal 5%, roughly 20x under nominal, the class's
  own docstring had long flagged this as an approximation but nobody had
  measured the severity. Fixed with Zou's (2004) robust/sandwich
  correction, computed in pure R from quantities the existing C++ kernel
  already returns (`mu`, `fisher_information`) — no kernel change, no
  rebuild. Verified via a fresh 500-replicate null simulation: Type-I error
  moved to 7.2%, median p-value from 0.63 to 0.46. **Result-changing**:
  every SE/CI/p-value this class has ever returned differs from this
  version's — a third exception alongside TODO-2/TODO-3 in the standing
  constraint below. Historical `comprehensive_tests.R` CSVs were not
  regenerated (plan's own TODO-6) and still reflect the pre-fix behavior.
  The audit added a direct deterministic sandwich regression, synchronized
  both generated Rd topics, and recorded the result-changing fix in NEWS;
  CSV regeneration is the only item-specific subtask left.
  **Candidate-run artifact audit, 2026-10-18:** no worker process remains.
  Slice 1 (broad 40-replicate class): 101,287 unique row IDs across reps
  1--40; all 48,872 original target IDs are present, plus 52,415 additional
  IDs. Statuses are 98,682 `ok` and 2,605 `error`; every error carries the
  same unsupported smoothed-randomization-bootstrap message, and all original
  `ok` IDs remain `ok`. A heartbeat records about 49 hours of row durations,
  but no terminal exit/stdout record survives. Treat as full-key/replicate
  coverage evidence pending status-policy reconciliation; do not rerun this
  roughly 50-hour slice solely to recover an exit code.
  Slices 2 and 3 have complete exact target-ID sets, reps 1--60 and 1--25
  respectively, all `ok`; their artifact timestamps span about 13m34s and
  1m51s, but neither has a retained invocation exit record. Slices 4--7 have
  no regenerated target rows, and the analyzer has not run. For the smallest
  pending slice (#6, 16 expected rows), an Oct 14 historical run took about
  13--15 seconds wall time; that is only a ballpark, not an ETA guarantee.
  The candidate tree remains 2.7 GiB under
  `R/package_tests/todo56_mp_resume_20261016/`, while `/tmp` has about 1.5 GiB
  free. Do not write more scratch into the checkout; run a small remaining
  slice only with all scratch routed to a new `/tmp` directory and preserve
  its exit/provenance record. Reconcile every key/status before marking this
  item complete.
  **Read-only process/handle recheck, 2026-10-19:** no `Rscript` process or
  TODO-56 command was present in the process list; the only transient R
  process observed was a source-only `pkgload` definition comparison and it
  exited before follow-up. `lsof` reported no open handles under the three
  TODO-56 slice scratch directories. `/tmp` was 94% used with 1.4 GiB free.
  This is a point-in-time process/handle check, not evidence that candidate
  artifacts have complete exit provenance or that the remaining slices ran.
  **Read-only recheck, 2026-10-20:** no `R`/`Rscript` process was present,
  and `lsof` showed no open handles under the candidate tree or slice scratch
  directories. The newest candidate-tree files remain the filtered result
  file (2026-10-18 11:09:00) and heartbeat (2026-10-18 11:09:25); the three
  `/tmp/edi-todo56-slice6*` directories also have no files newer than
  2026-10-18 11:09:25. `/tmp` remains 94% used with 1.4 GiB free. No row,
  exit-provenance, or analyzer state has advanced since the recorded Oct 18
  artifacts; this does not close the regeneration/reconciliation gate.
  **Session/artifact reconciliation, 2026-10-20:** the owning exec handle for
  the broad slice-6 run returned terminal exit 143; its log ends at
  2026-10-18 11:09:00 during ordinal
  `InferenceOrdinalPartialProportionalOddsRegr` randomization inference, and
  its heartbeat ends at 11:09:25. No `R`/`Rscript` process is currently
  present. A separate `/tmp/edi-todo56-slice6-target.lnaz88` filtered output
  contains 152 all-`ok` rows: it includes all 16 canonical target IDs but
  also 136 additional IDs, and its log has no terminal exit/provenance
  record. This is not an accepted isolated slice and must not be merged into
  canonical results. Preserve both artifacts; do not restart or clean them
  as part of this audit.
  **Read-only execution preflight 2026-10-20:** `ps -C R,Rscript` showed no
  R process, and `lsof` showed no open handles under the target slice output.
  Host load was 5.64/4.62/4.33 on the 12-CPU machine; `/tmp` was 94% used
  with 1.4 GiB free. The currently available package is EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, build stamp
  `2026-10-19 23:31:50 IDT`, `EDI.so` MD5
  `dfd5bf4384b5a0cc0d430fd70dab2a59` (R-devel r90668). This provenance is
  current-environment metadata only; it cannot identify the DLL used by the
  Oct 18 target artifact. The target inventory is still unresolved (16
  canonical pima IDs versus 152 all-`ok` candidate IDs, 136 additional), and
  temporary-disk headroom is insufficient for another broad scratch run.
  No run, fit, analyzer, or canonical write was started.
  **External receipt wrapper contract, 2026-10-21:** added the reusable
  `R/package_tests/comprehensive_external_process_receipt.R` helper and
  `R/package_tests/run_comprehensive_with_receipt.R` CLI. Its focused stub-child
  contract test passed 31 expectations (exit 0) with installed EDI 1.0.3 using
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-comprehensive-external-process-receipt-contracts.R", reporter="summary")'`.
  The test records command/arguments, PID, UTC start/end, terminal status, and
  stdout/stderr paths, sizes, and hashes. The CLI's `NAME=value` overrides are
  normalized to the named vector required by `processx`, while receipt
  serialization retains the original strings. This exercised only a short
  stub child; it does not change the runner's schema-v2 sidecar or validate an
  EDI workload. The external receipt remains untested on an authorized
  TODO-56 run; closure still requires a fresh isolated run with terminal exit
  0, complete sidecar provenance, and exact key/status/value reconciliation.
  **Read-only process/artifact recheck, 2026-10-21:** `ps -C R -C Rscript`
  showed no live R/Rscript process, and `lsof +D` found no open handles under
  the candidate tree or either retained `/tmp/edi-todo56-slice6*` directory.
  The broad historical slice-6 run is already terminal (exit 143; its runner
  log/heartbeat end 2026-10-18 11:09/11:09:25). The separate
  `/tmp/edi-todo56-slice6-target.lnaz88/results/comprehensive_tests_results_nc_1_incidence_filtered_design-Bernoulli_class-InferenceIncidModifiedPoisson_family-rand.csv`
  is 115,424 bytes and contains 152 all-`ok` rows: it includes the 16
  canonical target IDs plus 136 extras, and has no terminal receipt. Preserve
  it; do not merge it or restart the broad run. `/tmp` currently has 16 GiB
  free, but the exact 16 target IDs/argv still require owner confirmation.
  The only safe next run is that confirmed 16-key slice in a fresh `/tmp`
  directory with the external receipt and complete sidecar provenance,
  followed by exact key/status/value reconciliation. This recheck advances no
  regeneration gate; TODO-56 remains open.
- [ ] TODO-57 (added 2026-10-07, user decision; moved here from
  `release_v1_1_0.md → TODO-39` the same day): **Bayesian bootstrap
  performance: parallel scaling and native weighted refits** —
  `../bug_fix_plans/bayesian_bootstrap_performance.md → TODO-1..10`.

  A `bayesboot` comparison at n = 500, B = 1000 found two problems. A third
  (TODO-10, added 2026-10-18) came from profiling `comprehensive_tests.R`.
  - **EDI's Bayesian bootstrap does not scale with cores.**
    - The serial blocklist in `get_parallel_dispatch_policy()` pins
      logistic, Cox, Weibull and every other non-KK survival class to one
      core. No plan records why, and overriding it gave Cox 1.9–2.1x on 3
      cores.
    - Where parallel is allowed, it loses: OLS runs at 0.63x on 3 cores at
      B = 5000. Each of the `4 × cores` jobs likely ships all B draws plus
      the inference object.
    - The warmup gate times worker creation rather than the refit, so it
      never chooses serial.
  - **Cox, Weibull and OLS refit through R**: `survival::coxph` and
    `survreg` formula calls rebuilt per draw (including an unused
    concordance), and `lm.wfit`. Even C++-kernel classes spend about 70%
    of their time in R-side wrappers.
  - **Classes without a reusable worker copy the inference object per
    draw** (plan F7 / TODO-10): `InferenceCountHurdleNegBin` and the six
    KK GLMM / conditional-logit classes. The hurdle class's plain path
    takes 0.103 s per draw vs. 0.057 s on one reused copy, with identical
    estimates. Present since the initial commit, so not a regression.
    TODO-66's serial fallback for the non-reusable strategy changes the
    HurdleNegBin multi-core dispatch context; after fork-safety validation,
    re-evaluate/report this class's parallel-scaling comparison separately.
    This cross-reference does not change TODO-57's performance scope or
    thresholds.

  Fix order:
  1. dispatch machinery (bit-preserving; also speeds up the nonparametric
     bootstrap and the jackknife);
  2. blocklist audit;
  3. weighted Cox, Weibull and OLS kernels (tolerance-equal: the
     **result-changing exception** in the standing constraint below);
  4. hot-loop thinning.

  Independent of every other item here and of v1.1.0.

  **Conditional pull-in from v1.1.0's TODO-18** (decided 2026-10-07, user
  decision). The overlap with `consolidate_parallelization_code.md` is
  narrow. This item changes what `par_lapply` ships per job. TODO-18
  touches `ensure_mirai_daemons`, the `SimulationFramework` mirai polling
  loop and the worker env-var setup. They meet only where `par_lapply`'s
  mirai branch calls `ensure_mirai_daemons`.
  - **If** the owning plan's TODO-2 ends up changing `ensure_mirai_daemons`
    (for example, to send the inference object once per mirai daemon),
    then pull `consolidate_parallelization_code.md → TODO-1` (unify the two
    `ensure_mirai_daemons` copies, including the
    `SimulationFramework` copy's 2-attempt retry) into this release.
    Land it before that change, and record it here as a sub-item.
    That plan's TODO-2..4 stay in v1.1.0.
  - **Otherwise** TODO-18 stays whole in v1.1.0 and rebases onto this
    item.

  CRAN Task View proposals #11 (HighPerformanceComputing) and #13
  (Bayesian) are held until this ships (owner, 2026-10-07; see
  `marketing_plans/cran_task_view_proposals.md`'s gate checklist and the
  owning plan's TODO-9).

  **Source progress 2026-10-10:** plan TODO-4 now batch-generates the
  Bayesian-bootstrap gamma weights in the parent with one shared context and
  one `rgamma()` call, while preserving the historical replicate-then-group
  RNG order; a deterministic blocking reference covers that ordering. The
  studentized/bootstrap-t statistics loop now consumes the same full parent
  batch instead of B one-draw calls. This completes only that source-level
  substep. Dispatch, blocklist, weighted native-refit, hot-loop,
  installed-equivalence, and benchmark acceptance work remain open, so this
  release item stays unchecked.
  **Source progress 2026-10-19 (TODO-10):** the non-reusable Bayesian-
  bootstrap parallel path now duplicates one inference worker per draw chunk
  instead of once per draw; its warmup closure also reuses one duplicate.
  The focused regression compares ordinary and debug results with an
  independent fresh-clone-per-draw reference. Source-loaded with
  `pkgload::load_all("R/EDI", compile = FALSE)`, that test passed 25
  assertions. This validates the R source path only; no benchmark, native
  rebuild/install, or fork-sensitive runtime test was run, so TODO-10's
  performance/current-artifact gates and TODO-57 remain open.
  **Matching-native follow-up, 2026-10-20:** after an `EDI_UNITY=0`
  install of this checkout on 2026-10-19 (installed EDI 1.0.3; `EDI.so` SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`),
  the same focused test passed all 25 assertions with
  `testthat::test_file(..., package = "EDI")`. This supersedes the earlier
  missing-DLL-identity limitation for this focused R regression only. It does
  not validate multi-core/fork behavior, performance, or the other TODO-57
  acceptance gates.

  **Focused source/fixture check, 2026-10-18:** the design-backed bootstrap
  worker state/sample-loading reference test passed 113 assertions against
  installed EDI 1.0.3. Its QR-certificate assertions extract the current
  checkout's `load_bootstrap_sample_into_design_backed_worker()` definition;
  setup and native calls still came from the installed DLL. This is focused
  R-source evidence, not current-checkout native validation or performance
  acceptance.

  **Installed dispatch-contract rerun, 2026-10-20:**
  `test-compute-bayesian-bootstrap-distribution-with-reused-workers-dispatch-reference.R`
  passed 7 assertions (exit 0) against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Loaded DLL
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` MD5
  `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  This confirms the installed artifact's wrapper-to-driver argument contract
  only; it does not load checkout R sources or validate current-head native
  code, multi-core/fork behavior, payload size, or performance. A bounded
  actual-two-core installed-package test attempt reached fork setup but could
  not bind a local server socket after 20 ports in the sandbox; no
  outside-sandbox rerun was authorized. Those gates remain open.

  **Acceptance (reconciled to linked-plan TODO-9, 2026-10-20):**
  `marketing_plans/bb_bench2.R` must show no row slower on 3 cores than on
  1; Cox and Weibull must each scale at least 1.8x on 3 cores; and EDI must
  be at least 1x vs. `bayesboot` on every row at both core counts. This is a
  documentation reconciliation only; no benchmark result is asserted here.
  **Post-reinstall non-reusable-worker regression, 2026-10-21:**
  `test-bayesian-bootstrap-non-reusable-worker-debug-path.R` passed against
  installed EDI 1.0.3 with no failures, warnings, or skips. For the seeded
  `InferenceCountHurdleNegBin` non-reusable branch, debug and ordinary
  distributions match a fresh-clone-per-draw reference; the ordinary-path
  spy confirms the one-core clamp occurs before warmup, draw chunks rather
  than the full draw list cross the dispatch seam, and the callback does not
  capture all draws. The debug spy confirms no `par_lapply` call. No real
  fork, benchmark, or build/install occurred. Installed EDI was built
  2026-10-20 21:56:26 UTC, with DLL SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  matching checkout `R/EDI/src/EDI.so`; this is a focused installed runtime
  contract check, not performance, release-scale fork safety, or full R-source
  identity. The companion
  `test-bayesian-bootstrap-blocking-contexts-worker-loading-and-abstract-hooks-reference.R`
  also passed against installed EDI 1.0.3: it checks block-grouped gamma
  weights against the historical seeded `rgamma()` reference, weight/context
  transfer to workers, invalid-weight rank-certificate clearing, and abstract
  hooks. These are bounded correctness checks only; TODO-57's broader
  benchmark, blocklist, weighted-refit and reproducibility gates remain open.
  **Current-source worker/payload overlay, 2026-10-21:** after the R slot was
  clear, `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed
  by `testthat::test_file("R/package_tests/testthat_bulk/test-bayesian-bootstrap-non-reusable-worker-debug-path.R")`
  passed all 29 assertions (exit 0). The test's ordinary dispatch spy checks
  fresh-clone-per-chunk results against an independent fresh-clone-per-draw
  reference, one-core clamp before warmup, draw-chunk payloads, and that the
  callback environment does not capture the full draw list; the debug spy
  asserts no `par_lapply` call. The loaded temporary DLL was
  `/tmp/Rtmpj8bYGi/pkgload1c9bd85ee948bc/EDI.so`, MD5
  `ea0e2f72d87d401db15557e0ecc151c9`, SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  matching checkout `R/EDI/src/EDI.so`. This exercises the current working-tree
  R worker/payload contract against the existing native library only: the
  synchronous spy creates no fork and provides no multi-core, serialized-byte,
  performance, rebuild-manifest, or benchmark acceptance evidence. TODO-57
  remains open for those gates.

  **Positive-weight QR-certificate helper regression, 2026-10-21:**
  `Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-inference-hardened-qr-column-dropping-retry-reference.R", package = "EDI")'`
  passed 56 assertions (0 failures, warnings, or skips; exit 0) with installed
  EDI 1.0.3 used for package setup. The focused tests directly extract/evaluate
  the checkout helper and compare its positive-weight result to independent
  `stats::lm.wfit`, including the failed-fit/drop-column fallback. This does
  not execute or validate the native weighted-refit implementation, loader
  integration, or performance; those TODO-57 gates remain open.

  **Focused current-R/current-native Poisson-GLMM weighted-path smoke,
  2026-10-21:**
  `Rscript -e 'pkgload::load_all("R/EDI", compile=FALSE, quiet=TRUE); testthat::test_file("R/package_tests/testthat_bulk/test-kk-glmm-count-weighted-bootstrap-estimate-reference.R")'`
  passed all 10 assertions (exit 0). Loaded namespace:
  `/home/kapelner/workspace/EDI/R/EDI`; EDI 1.0.3; temporary `EDI.so` MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0` (the
  latest user-built artifact). Its positive-weight case exercises the existing
  `compute_weighted_glmm_bootstrap_estimate()` path through
  `fast_poisson_glmm_cpp()`; the expected value is re-derived via a second call
  to that same native kernel, while zero-weight and fallback behavior are also
  covered. This is a focused dispatch/current-artifact smoke, not an
  independent numerical oracle and not validation of the planned native Cox,
  Weibull, or OLS weighted-refit replacements.
  **Release TODO-57 → linked plan TODO-6, OLS first slice, 2026-10-21:**
  `InferenceContinOLS` now sends
  sqrt-weighted design/response matrices to existing `fast_ols_cpp()` for
  full-rank draws with finite native coefficients, retaining
  `stats::lm.wfit()` for rank-deficient or failed native fits. The existing
  `test-continuous-ols-weighted-bootstrap-wls-reference.R` was broadened with
  weighted-input/native-dispatch checks, an independent `lm.wfit` estimate/SE
  reference (`1e-10`), and a rank-deficient fallback case. All 10 assertions
  passed under `pkgload::load_all("R/EDI", compile=FALSE)`; checkout namespace
  `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3, loaded temporary DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`. No
  compile/build/install or benchmark occurred. This advances only the plain
  OLS bootstrap refit path and makes no performance claim; other OLS-family
  callers and the planned Cox/Weibull weighted kernels remain open. This
  R-layer change calls the existing `fast_ols_cpp()` export; the test loaded
  checkout R over the latest user-built DLL, which was not rebuilt for this
  edit. Any later C++ kernel/export changes require explicit build permission
  and focused native validation before acceptance.
  **Release TODO-57 → linked plan TODO-6, Lin OLS-family slice, 2026-10-21:**
  `InferenceContinLin` now calls existing `fast_ols_cpp()` with the
  sqrt-weighted Lin design/response for full-rank finite fits and preserves
  `stats::lm.wfit()` for rank-deficient/failed fits. The broadened existing
  weighted-Lin test verifies native inputs and estimate/SE against an
  independent weighted `lm()` reference; its aliased-treatment test confirms
  fallback and no native call. The two focused files passed 38 and 6
  expectations under checkout `pkgload::load_all("R/EDI", compile=FALSE)`.
  Namespace `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; loaded temporary
  DLL MD5 `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This is current R-layer/installed-native evidence only; no native rebuild,
  install, or performance claim. Remaining OLS-family call sites and
  weighted Cox/Weibull kernels are open.
  **Release TODO-57 → linked plan TODO-6, incidence risk-difference OLS-family slice, 2026-10-21:**
  `InferenceIncidRiskDiff` now uses existing `fast_ols_cpp()` on the
  sqrt-weighted design/response for full-rank positive-row draws with finite
  coefficients, retaining `stats::lm.wfit()` for rank-deficient or failed
  native fits. The existing
  `test-incidence-risk-diff-weighted-refit-reference.R` verifies exact native
  inputs and one native call against an independent `lm.wfit` coefficient
  reference (`1e-8`); all 8 assertions passed under checkout
  `pkgload::load_all("R/EDI", compile=FALSE)`. Namespace
  `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; loaded temporary DLL MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  No native rebuild, install, or performance claim is made. This advances
  only this additional R-layer weighted OLS caller; native Cox/Weibull
  weighted kernels, remaining OLS-family callers, and performance gates
  remain open.
  **Release TODO-57 → linked plan TODO-6, KK one-likelihood OLS caller, 2026-10-21:**
  `ContinKKOLSOneLikLikelihoodSource.fit_weighted_combined()` now dispatches
  full-rank finite sqrt-weighted designs to existing `fast_ols_cpp()`, keeping
  `stats::lm.wfit()` for rank-deficient or failed native fits. The existing
  `test-kk-ols-one-lik-fit-weighted-combined-regime-branches-reference.R`
  verifies combined, matched-only, and reservoir-only regimes, exact weighted
  native inputs, and the coefficient against an independent `lm.wfit`
  reference; HC2 SEs are checked finite and positive. Its spy-scope correction
  leaves the mock active through the fit call. All 18 expectations passed
  under checkout `pkgload::load_all("R/EDI", compile=FALSE)`. Namespace
  `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; loaded temporary DLL MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This is R-layer dispatch evidence against the existing DLL only: no native
  rebuild/install or performance claim. Other OLS-family callers and native
  Cox/Weibull weighted kernels remain open.

  **TODO-57 retained-artifact audit, 2026-10-21:** the tracked
  `marketing_plans/bb_bench2_results.txt` table (SHA-256
  `c3d53f58aef9e0c7b9465a87f81da24fd32022c45975b52ebfe03d6c9d503a26`)
  is historical EDI 1.0.2 vs `bayesboot` 0.2.3 evidence at n=500/B=1000
  (median of three timings, one/three cores, 12 detected cores). It has
  aggregate estimates and timing but no raw draw vectors, exact seeds,
  host/R/BLAS identity, or script/source hash, so it is not provenance-complete
  current before/after evidence. A targeted `/tmp` inventory found no retained
  TODO-57 benchmark output; the prior pilot stopped before timing because
  `bayesboot` was unavailable and produced no CSV. The focused dispatch/fork
  and weighted OLS-family tests documented above close narrow correctness
  subgates only, not current performance, payload reduction, or native
  Cox/Weibull weighted-refit acceptance. TODO-57 remains open.
  **Retained-artifact recheck, 2026-10-21 (read-only):** re-hashed the
  tracked `marketing_plans/bb_bench2_results.txt`; SHA-256 remains
  `c3d53f58aef9e0c7b9465a87f81da24fd32022c45975b52ebfe03d6c9d503a26`
  (5,234 bytes; mtime 2026-10-07). The n=500/B=1000, three-run, one-/three-
  core table contains only aggregate mean/SD and timing, not raw draw vectors,
  exact seeds, or runtime/source provenance. A bounded top-level `/tmp` name
  search for `*todo57*` returned no matching artifact; this is not a recursive
  absence claim. Thus no retained evidence closes draw-level parity,
  serialized payload bytes before/after, current performance, or native
  weighted-refit acceptance. Those still require an authorized, provenance-
  complete run with payload measurements and fixed-seed vectors. No benchmark,
  test, build, install, or canonical write occurred; TODO-57 remains open.

- [ ] TODO-58 (added 2026-10-07, user decision): **Nonparametric bootstrap
  worker: per-draw data.frame subsetting, model-matrix rebuild and R-level
  rank check** — `../bug_fix_plans/bootstrap_worker_dataframe_subsetting.md
  → TODO-1..6`.

  The 2026-10-07 benchmark extension found the R6 percentile bootstrap CIs
  at 0.09x (OLS), 0.86x (logistic) and 0.42x (Cox) of `boot`, while the
  kernels they call are far faster than `boot`'s refit. Per draw the OLS
  worker spends 2.1 ms around a 0.02 ms `fast_ols_cpp` call:
  - `[.data.frame` with duplicated indices runs `make.unique` on row names
    (28% of the whole bootstrap);
  - the model matrix is rebuilt from raw covariates (0.36 ms) instead of
    row-subset;
  - `fit_with_hardened_qr_column_dropping()` runs an R `qr()` (0.1 ms) and
    a `tryCatch` per draw.
  Fix order: subset without `make.unique` (bit-preserving); subset the
  model matrix directly (tolerance-equal with a rebuild fallback — the
  **result-changing exception** in the standing constraint below); skip
  the per-draw `qr()` (the same change as TODO-57's plan → TODO-7,
  implement once); add a non-parametric fast-path hook so TODO-3's
  `compute_ols_bootstrap_parallel_cpp` wiring has somewhere to land.
  **Source progress 2026-10-10:** duplicated-row data-frame worker subsets
  now rebuild columns with compact automatic row names, avoiding
  `[.data.frame`'s `make.unique()` work while preserving downstream
  data-frame inputs; a repeated-row worker-state regression covers it. The
  model-matrix subset now uses the saved full matrix directly and detects a
  rank-deficient resample before falling back to the historical rebuild path;
  a rare-covariate reference covers that branch. The hardened-fit fast path,
  OLS batched dispatch, and installed benchmark/regression gates remain open.
  Acceptance: all three rows ≥ 1x `boot`. Otherwise independent of every
  other item here and of v1.1.0. **Installed worker profile 2026-10-15:**
  at n=1000 / 100 draws, OLS/logistic/Cox measured 1.00/1.04/1.24 ms per
  draw against EDI 1.0.3; the short Rprof shows the OLS `which()`/design
  matrix path, logistic hardened QR fit, and Cox sample-loading/fit path as
  top inclusive entries. This is a current-state profile only, not a
  before/after or `boot` comparison; it does not meet acceptance. Details and
  the `/tmp` result path are in
  `../bug_fix_plans/bootstrap_worker_dataframe_subsetting.md → TODO-1/6`.
  The installed worker-state/sample-loading reference also passed 59/59
  assertions on 2026-10-15, covering OLS resample matrix refresh and the
  rare-covariate rebuild fallback. This does not establish fixed-seed
  distribution equivalence or the `boot` comparison, so TODO-58 remains open.
  **Source-path performance audit, 2026-10-21 (no benchmark):** the public
  percentile route already subsets the cached full-data model matrix and
  passes the per-draw QR rank certificate to the hardened fit wrapper, avoiding
  a duplicate QR. The first rank check remains necessary for the rank-deficient
  resample rebuild/fallback contract. OLS refits each sample; Cox uses the
  prebuilt C++ fitter with the `survival` R fallback, versus `coxph.fit()` in
  the `boot` reference. No safe R-only optimization was evident without
  class-specific parity evidence. This source audit changes neither behavior
  nor acceptance: OLS/Cox speed remain below the >=1x target, and profiling,
  current-source/native proof, and authentic EDI 1.0.2 parity remain open.
  **Focused source-loaded follow-up, 2026-10-20:** the existing worker test now
  also covers a resample omitting a rare factor level and checks the fallback
  estimate against independent `model.matrix()` + `lm.fit()` at `1e-10`.
  All 116 expectations passed with checkout R code loaded using
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` and the
  available installed DLL. This adds factor-level branch evidence only; it is
  not current-head native validation and does not satisfy the original-size
  benchmark or EDI 1.0.2 parity gates.
  **Parity-provenance fail-closed cases, 2026-10-20:** the comparator now
  rejects an existing package path that is a regular file and an EDI DLL path
  that is a directory (both previously skipped identity verification). The
  tampering regression exercises both through the CLI using scratch artifacts;
  its focused non-compiling test passed 12 assertions. This validates only
  path-shape rejection, not artifact authenticity when original files are
  unavailable. The original-size benchmark and authentic EDI 1.0.2/current
  fixed-seed parity artifacts remain required.
  **Retained full-size benchmark audit, 2026-10-20 (not acceptance):** the
  isolated scratch CSV `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv`
  (SHA-256
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`)
  contains exactly ten alternating timing samples per accepted OLS/logistic/Cox
  row at the manifest's original `n`, B, fixture seeds, and row seeds. Its
  benchmark-script SHA-256
  (`fda10ec6115507a446d120f5258eb4fe6038e00827cf8ba52ec9191a64064441`)
  matches the current harness; it records installed EDI 1.0.3 and DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  R/dependency/host/BLAS identity. The installed path's current `DESCRIPTION`
  says build time 2026-10-20 07:40:04 UTC; the CSV itself does not record the
  field. The per-sample speedup is
  `boot_complete_ms / EDI_procedure_ms`; EDI construction is timed separately,
  and the `boot` denominator includes `boot()` plus percentile `boot.ci()`.
  Median speedups were OLS 0.137x, logistic 1.030x, Cox 0.392x, so OLS and Cox
  miss the existing >=1x criterion. The CSV lacks run-time host-load/thread
  data, checkout HEAD/worktree fingerprint, an adjacent sidecar, and installed
  R-source identity; this is retained diagnostic evidence, not quiet-host
  acceptance. No authentic EDI 1.0.2 distribution-parity artifact was found.
  Thresholds are unchanged; both speed and historical-parity gates remain
  open. See the linked plan for row-level provenance and artifact details.
  **Post-reinstall worker regression and artifact recheck, 2026-10-21:**
  `test-design-backed-bootstrap-worker-state-and-sample-loading-reference.R`
  passed against installed EDI 1.0.3 with no failures, warnings, or skips.
  It covers installed worker setup/estimation and repeated-index sample
  behavior, direct model-matrix subsetting and rank-deficient/rare-factor
  rebuild fallbacks against independent `model.matrix()`/`lm.fit()` results,
  and fixed-draw OLS percentile-CI references. The test also extracts the
  checkout loader for explicitly source-labeled loader assertions. Installed
  EDI was built 2026-10-20 21:56:26 UTC; installed and checkout DLLs match at
  SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  but `DESCRIPTION` does not identify the loaded R payload/checkout SHA, so
  this is focused installed/runtime worker evidence, not full source-layer
  provenance or historical parity. The retained full-size results CSV still
  has hash
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25` and no
  sidecar; the current harness SHA is `12a5872495f45822af387887eedeafd6e423b74a8b5e591d339ad28da83d7c89`,
  not the older script hash recorded for that run
  (`fda10ec6115507a446d120f5258eb4fe6038e00827cf8ba52ec9191a64064441`). Its
  OLS/Cox medians remain below the 1x gate, and the B=64 same-draw comparison
  to `boot` is a reduced-size independent-reference pilot, not EDI 1.0.2
  distribution parity. The only located 1.0.2 tarball is unauthenticated,
  source-only, and has no retained baseline vectors. Original-size quiet-host
  timing and parity against an authentic 1.0.2 package/vector baseline remain
  required; this rerun does not close TODO-58. A local read-only recheck found
  the candidate `/tmp/claude-1000/tmp.tRezeJm6cW/EDI_1.0.2.tar.gz`
  (SHA-256 `01f79c8d52678cbd95af1b7ed25609a8f1c340f059531939c9c82fddd5c47af9`;
  its embedded `DESCRIPTION` declares version 1.0.2). No adjacent detached
  signature/checksum or compiled DLL, and no fixed-seed baseline vectors, are
  retained with this candidate. The hash pins the local bytes but cannot
  authenticate them without an independent trusted checksum/signature or
  authoritative repository copy. The extant 2026-10-20 benchmark/provenance
  CSVs identify installed EDI 1.0.3 and are not historical 1.0.2 vectors.
  Therefore the exact missing independent reference remains an authenticated
  EDI 1.0.2 package (or its trusted published checksum/signature) plus the
  accepted fixed-seed bootstrap distributions for the three TODO-58 fixtures;
  current/reduced-size `boot` comparisons do not substitute for these vectors.
  **Local Git-history cross-check, 2026-10-21:** this checkout has a local
  lightweight `v1.0.2` ref pointing to commit
  `903ced0404921b7f4a6b5a8b1f7d0a6702466a31` (the commit declares EDI 1.0.2),
  but the ref is not a signed tag and the commit has no verified signature
  (`git verify-tag` cannot verify a commit ref; commit signature status is
  unsigned). The candidate tarball's selected source files match that local
  snapshot, but this does not authenticate the archive or establish published
  provenance. Tests committed at that ref include bootstrap smoke/reference
  coverage, but none uses the accepted TODO-58 fixture/row seeds
  (`22422/414230`, `19021/609739`, `17961/628354`) or stores those three
  distributions. The retained B=64 parity CSV
  `/tmp/edi-todo58-distribution-parity-b64-20261016.csv` (SHA-256
  `bbaa2b13b0210dca0b0b6ef547117cc34ce9a0685ee0f31bd925743ad3cd42c8`)
  reuses the three fixture seeds but uses draw seeds `314159..314161` and
  compares the current EDI worker against independent `lm.fit()`/`glm.fit()`/
  `coxph.fit()` estimates on identical draws; it is not an EDI 1.0.2
  public-CI result. Thus local Git history
  supplies source context only, not the missing independent historical result
  vectors/authentication anchor.
  **Current artifact-presence recheck, 2026-10-21:** the original-size
  diagnostic `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv` remains
  present at SHA-256
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`; its
  directory contains no provenance sidecar. The referenced combined
  `/tmp/edi-todo58-distribution-parity-b64-20261016.csv` is absent from the
  inspected `/tmp` tree and checkout. The remaining per-family summary,
  interval, and provenance CSVs are not that combined parity artifact and do
  not supply an authenticated EDI 1.0.2 public-CI baseline. The acceptance
  step remains a quiet-host original-size benchmark with complete current
  provenance plus fixed-seed distribution comparison against an authenticated
  EDI 1.0.2 package or trusted vectors.
  **Checkout-loader three-fixture regression, 2026-10-21:** the existing
  OLS/logistic/Cox direct-subset-versus-rebuild test now calls the extracted
  checkout loader and retains independent reference checks at `1e-10` across
  five fixed draws per fixture. The focused bulk file passed 118 expectations
  under `pkgload::load_all("R/EDI", compile = FALSE)`; EDI version 1.0.3,
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, loaded DLL MD5
  `bfea6f47ab8b27618d5d8633e9021f91` (installed library SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`).
  This closes only the checkout-R test-coverage subgate; it is not current-HEAD
  native validation and does not close the original-size timing or
  authenticated EDI 1.0.2 parity requirements.
  - [ ] Run the full original-bootstrap-size public R6 percentile-CI benchmark
    for OLS, logistic, and Cox against `boot`, requiring each row to reach at
    least 1x; separately confirm fixed-seed distribution parity against an
    authoritative EDI 1.0.2 package. Record package/DLL provenance and keep
    diagnostic or reduced-B pilots out of acceptance.
  **Synthetic comparator guard, 2026-10-21:** the existing provenance test
  now also changes both the old artifact's version and its synthetic
  `DESCRIPTION` to 1.0.1, then verifies compare-parity rejects it because the
  accepted baseline is exactly EDI 1.0.2. The focused file passed 89
  expectations against installed EDI 1.0.3 while sourcing the checkout
  benchmark script; this is synthetic harness evidence only, not benchmark or
  old/current distribution parity. Authentic EDI 1.0.2 vectors, quiet-host
  speed evidence, and current-source/native provenance remain open.
  **GitHub release-asset provenance recheck, 2026-10-21 (metadata-only):**
  official release `v1.0.2` was published 2026-10-07 09:53:47 UTC and has one
  asset, `EDI_1.0.2.tar.gz`, uploaded by `kapelner` (3,263,678 bytes). GitHub
  release-asset metadata
  (`https://api.github.com/repos/kapelner/EDI/releases/assets/618268034`)
  records SHA-256
  `01f79c8d52678cbd95af1b7ed25609a8f1c340f059531939c9c82fddd5c47af9`,
  matching the existing local candidate's size/hash; release:
  `https://github.com/kapelner/EDI/releases/tag/v1.0.2`. The tag ref points
  directly to unsigned commit `903ced0404921b7f4a6b5a8b1f7d0a6702466a31`,
  but the GitHub asset digest independently pins the uploaded source bytes.
  The only Actions run for that commit was Copilot Setup Steps
  (#37603732050), and its artifact metadata has `total_count=0`; no native
  binary or seed-vector artifact is attached to the release. Thus
  EDI 1.0.2 source authenticity is established, superseding the earlier
  “unauthenticated local candidate” status, but the accepted full vectors are
  still absent: OLS `n=1000, B=1000`, seeds `22422/414230`; logistic
  `n=1000, B=500`, `19021/609739`; Cox `n=500, B=500`, `17961/628354`.
  A local 2026-10-21 inventory found the retained 10-sample EDI 1.0.3-vs-`boot`
  file `/tmp/edi-todo58-formal10-20261020-p5wFEL/results.csv` (31 lines
  including header; SHA-256
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`).
  It contains interval/timing rows, not raw bootstrap vectors; the retained
  per-case files likewise contain interval/provenance summaries only. No
  accepted EDI 1.0.2 parity vectors were found locally. This does not satisfy
  the separate quiet-host timing gate, so the full parity gate remains open.
  The remaining parity step requires a controlled run against the authenticated
  source and preservation of the three length-B distributions plus RNG/package
  provenance, followed by exact comparison with current EDI. No download, R
  execution, build, or install occurred; TODO-58 remains open.
  **Acceptance-artifact recheck, 2026-10-21 (read-only):** the retained
  `results.csv` is still 31 lines (10 timing samples for each accepted
  original-size OLS/logistic/Cox row), SHA-256
  `eff896a4ca97c5f53184605df80f8fb5ad0428335e47abf066c009a2d2657e25`.
  It records EDI 1.0.3/DLL, R and dependency versions, host OS/kernel/CPU,
  BLAS, accepted B/seeds, timings, and a benchmark-script hash. It has no
  sidecar, checkout/worktree identity, host-load, CPU-affinity, or thread-state
  data; the recorded script SHA differs from both current worktree and HEAD
  script hashes. It is full-size diagnostic evidence but not quiet-host/current-
  provenance acceptance, and its OLS/Cox medians (0.137x/0.392x) fail the
  fixed >=1x criterion (logistic 1.030x passes). The other retained CSVs are
  per-case interval/provenance summaries, not vectors; the combined B=64
  parity artifact is absent. Though the official release digest authenticates
  the EDI 1.0.2 source tarball, there are no accepted OLS B=1000, logistic
  B=500, or Cox B=500 vectors from it. No existing artifact establishes the
  required timing and parity gates without new execution; TODO-58 remains
  unchecked and acceptance thresholds are unchanged.

- [ ] TODO-59 (added 2026-10-07, user decision): **Design construction
  overhead: `packageVersion()` disk read and eager covariate ingestion** —
  `../bug_fix_plans/design_construction_overhead.md → TODO-1..5`.

  `DesignFixediBCRD` + one draw is 0.03x of `randomizr::complete_ra()` and
  `DesignFixedBlocking` 0.12x of `block_ra()`, although the draws
  themselves are microseconds (blocking delegates to `block_ra`, 0.7 ms).
  The 5–8 ms is `Design$initialize()` (1.4 ms, including
  `utils::packageVersion("EDI")` reading `DESCRIPTION` from disk on every
  design, `design_abstract.R:233`) plus the covariate pipeline
  (`as.data.table` copy, 2–3 data.table `[` calls at 0.125 ms each,
  `model.matrix` 0.36 ms) run eagerly for rules that never read the model
  matrix. Fix: cache the version at load; build the model matrix lazily
  behind a staleness flag; trim the data.table round trips. All
  bit-preserving (equality test on `X`, `Ximp`, draws). Acceptance: iBCRD
  row ≤ 1.5 ms, blocking ≤ 2.5 ms. Touches the same builder as TODO-60;
  independent in content, rebase the second onto the first.

  **Implementation status 2026-10-09:** package-version lookup is cached for
  the session and covariate-dependent fixed designs defer model-matrix
  construction behind a lazy builder gate. The focused missingness/cache and
  all-design seed suites pass 82 expectations without compilation. A new
  benchmark records source-loaded diagnostics, but those concurrent-load
  timings are not the required installed-package acceptance measurement.
  **Diagnostic harness extension 2026-10-16 (not timing acceptance):** the
  benchmark now separates constructor-only (`n=NULL` and specified `n`),
  blocking registration-only, and assignment-only timings. Its adjacent
  provenance sidecar records installed package/library, checkout and R
  identity, thread environment, plus start/end host load and process CPU
  affinity; the CSV schema remains unchanged. Parse-only and diff checks pass;
  no timings were run during the active TODO-56 CPU-intensive study.
  Linked-plan TODOs 1-4 are closed; TODO-5 remains pending the next authorized
  rebuild/install, so this release item stays unchecked. **Follow-up source
  correction 2026-10-11:** inference construction now honors a non-`NULL`
  design matrix's stale flag. This prevents a sequential Pocock--Simon design
  from carrying a manually materialized prefix covariate matrix into final
  inference after later arrivals. A regression checks an eight-row enrollment
  after a four-row materialization. **Checkout-R source-overlay recheck,
  2026-10-20:** the containing test file passed with no failures, warnings, or
  skips via `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE,
  export_all = FALSE)` followed by `testthat::test_file(...)`. The checkout R
  namespace used the existing installed native DLL (SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`,
  identical to `R/EDI/src/EDI.so`); no build or install occurred. This verifies
  the stale-prefix refresh/OLS-reference regression only; it does not satisfy
  TODO-5's installed timing or EDI 1.0.2 parity gates. Details are in
  `../bug_fix_plans/design_construction_overhead.md`.
  **Installed benchmark diagnostic 2026-10-19 (not acceptance):** the exact
  `n=1000`, `batch=100`, seven-repeat command completed against installed EDI
  1.0.3 with 12-core affinity. Host load was 3.81/4.23/4.23 at start and
  3.94/4.23/4.23 at finish, so the quiet-host requirement was not met. Median
  iBCRD full construction was 1.45 ms (within 1.5 ms); blocking full
  construction was 3.65 ms (over 2.5 ms; min/max 3.23/3.89 ms). The package
  DLL SHA-256 was
  `2de0c2d4918cb7fbd74d35a05c32893bfe58b00429a09d3ae6851c0e43c6946a`;
  this was installed EDI 1.0.3 under R-devel, not a rebuilt checkout, and no
  authentic EDI 1.0.2 assignment-weight comparison was made. The CSV and
  provenance sidecar are in `/tmp/edi-todo59-design-bench-LIsn6K/`, with
  SHA-256s `be8d37c0715d4422904d95d5d4b117d07573f43f52690b209c9ab72776f75ba4`
  and `855f3c7f4ef79852a1a66cd05510bb8902b0f11a1b3e2f8fd9af7902ecc66c88`.
  The harness retains median/min/max, not each repeat. This is diagnostic
  only; TODO-59 remains open for a quiet-host acceptance run and the EDI 1.0.2
  parity comparison.
  **Provenance-gate smoke check, 2026-10-20:** the benchmark sidecar now
  records the complete porcelain worktree status (including untracked paths)
  and SHA-256 of the tracked `git diff --binary HEAD`, alongside checkout HEAD
  and DLL identity. A bounded source-loaded invocation (`n=5`, `batch=1`, one
  repeat) verified both fields without replacing any acceptance output. Its
  `/tmp` CSV and sidecar hashes are
  `e785cc58d05a0f33874db7b0ea0b7053e322cf8d9c39cd78e6501c6c6a7a631b` and
  `5728a707b4f604c7abe56878acfe5448624cfc0acb00a718d2620ab7c2cdaa69`.
  This checks metadata emission only; it is not timing evidence, and status
  reports untracked paths without hashing their contents. The quiet-host
  timing target and authentic EDI 1.0.2 fixed-seed parity input remain open.
  **Failure-path hardening and focused test, 2026-10-20:** a missing/failing
  Git status command now reports `<unavailable>` instead of being mistaken
  for a clean checkout. `test-benchmark-design-construction-provenance-reference.R`
  passed 17 assertions covering clean, dirty tracked, untracked-path, and
  unavailable-command cases. The untracked-path check confirms porcelain
  status includes the path while the tracked-diff digest remains unchanged.
  It creates only a temporary Git repository; no full timing benchmark or
  canonical output was run or modified.
  **Untracked-source content provenance regression, 2026-10-20:** porcelain
  status and the tracked-diff digest alone did not distinguish different
  contents at an unchanged untracked path. The sidecar now also records a
  SHA-256 over the path/content manifest for nonignored untracked files. The
  focused provenance fixture passed 24 expectations, including a mutation
  that changes only untracked contents while leaving the status text and
  tracked-diff digest unchanged. This deterministic harness check is not a
  timing run; only the quiet-host timing target and authentic EDI 1.0.2
  fixed-seed assignment parity remain for TODO-59.
  **Current artifact/provenance audit, 2026-10-21:** the preserved Oct 19
  CSV and sidecar still match the hashes above. They remain diagnostic, not
  acceptance evidence: recorded host load was 3.81/4.23/4.23 at start and
  3.94/4.23/4.23 at finish (not a quiet host), blocking median was 3.65 ms
  against the 2.5 ms cap, and the recorded DLL SHA-256
  (`2de0c2d4918cb7fbd74d35a05c32893bfe58b00429a09d3ae6851c0e43c6946a`)
  differs from the current installed EDI 1.0.3 DLL. The current installed
  package was built 2026-10-20 21:56:26 UTC; its DLL matches checkout
  `R/EDI/src/EDI.so` at SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`, but
  the worktree is dirty, so the old run's HEAD/DLL metadata does not establish
  current source provenance. The focused
  `test-benchmark-design-construction-provenance-reference.R` was rerun
  against installed EDI 1.0.3 and passed all 31 assertions; it exercises
  provenance helpers only, not timing. A candidate EDI 1.0.2 source archive
  previously found in `/tmp` has no trusted checksum/provenance and contains
  no native binary or retained assignment vectors, so it is not an
  authoritative parity baseline. Both the quiet-host timing run with current
  provenance and fixed-seed parity against an authentic EDI 1.0.2 baseline
  remain required; this audit does not close TODO-59.
  **Preserved timing-artifact reconciliation, 2026-10-21 (read-only):**
  rechecked `/tmp/edi-todo59-design-bench-LIsn6K/timings.csv` and its
  provenance sidecar. Their SHA-256 hashes still match
  `be8d37c0715d4422904d95d5d4b117d07573f43f52690b209c9ab72776f75ba4` and
  `855f3c7f4ef79852a1a66cd05510bb8902b0f11a1b3e2f8fd9af7902ecc66c88`.
  The sidecar authenticates the run parameters (`n=1000`, `batch=100`, seven
  repeats, seed 5901), EDI 1.0.3/R-devel environment, HEAD, host load and
  affinity, and the then-loaded native DLL hash
  `2de0c2d4918cb7fbd74d35a05c32893bfe58b00429a09d3ae6851c0e43c6946a`.
  It predates the harness's checkout-status/diff and R-layer manifest fields;
  it records medians/minima/maxima rather than per-repeat samples. The stored
  medians remain 1.45 ms for iBCRD and 3.65 ms for blocking, so the latter
  misses the 2.5 ms ceiling; the host load (3.81/4.23/4.23 at start,
  3.94/4.23/4.23 at finish) also fails the quiet-host condition. Read-only
  hashing now confirms the installed and checkout DLLs match at
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  distinct from the artifact's older DLL, so that timing is not attributable
  to the current installed artifact. No authentic EDI 1.0.2 fixed-seed
  assignment-weight vectors or trusted installed baseline were found in the
  retained evidence; the candidate source archive remains unauthenticated and
  contains no native binary or vectors. The remaining tests are therefore a
  quiet-host acceptance-settings run with the current installed package and
  complete sidecar provenance, plus fixed-seed assignment-weight comparison
  against an authenticated EDI 1.0.2 package or provenance-pinned reference
  vectors. Both criteria remain unchanged; this reconciliation does not close
  TODO-59 and no timing run or canonical output write occurred.
  **Retained-run completeness audit, 2026-10-21:** among the other local
  TODO-59 timing CSVs, `/tmp/edi_v105_todo59_design_construction.csv` is an
  unproven candidate with the acceptance `n=1000`, `batch=100`; its
  iBCRD/blocking full-workflow medians are 0.83/1.91 ms (SHA-256
  `f002a5077eea71948e19b99532585e90b3639d143e1122c8240a1d6d205f29be`). It
  has no sidecar or raw repeat rows, so its repeat count, host load, package/
  DLL identity, and checkout provenance cannot be established; passing point
  medians alone do not meet the quiet-host gate. The older 10/09, 10/15, and
  10/16 summary CSVs also lack sidecars; the latter installed/pinned-core
  blocking medians are 5.90–6.88 ms, above the 2.5 ms cap. The only
  provenance-bearing acceptance-sized timing remains the 10/19 artifact
  above (high load, 3.65 ms blocking, stale DLL identity); the 10/20
  provenance smoke used `n=5`, `batch=1`, one repeat, source-loaded code, and
  load 4.24, so it is metadata-only, not acceptance. No retained run can
  establish both quiet-host threshold performance and current package
  identity. On the parity side, the source-only candidate and unsigned local
  `v1.0.2` commit contain no recorded TODO-59 fixed-seed assignment vector;
  the checked-in expected vector has no independent 1.0.2 run provenance.
  Therefore neither open gate can be closed from existing artifacts without
  the missing baseline and a provenance-complete acceptance run.
  **Closure recipe and decision boundary, 2026-10-21:** when an authorized
  quiet-host slot is available, run the installed-package harness (do not set
  `EDI_BENCH_SOURCE`) with a unique scratch output:
  `Rscript R/benchmark/benchmark_design_construction.R 1000 100 7 /tmp/edi-todo59-acceptance-<unique>.csv`.
  Preserve both CSV and `.provenance.txt` hashes. The sidecar must identify
  installed EDI and its loaded R-namespace payload, DLL SHA-256, checkout
  HEAD/worktree/tracked and untracked manifests, R/session and thread settings,
  host load and CPU affinity at start/end, and exact run parameters. Require
  iBCRD median <= 1.5 ms and blocking median <= 2.5 ms across the seven
  repeats; do not reuse or overwrite the diagnostic artifacts. “Quiet host”
  has no numeric load cutoff in the acceptance text. The maintainer must
  choose a numeric cutoff only if one is required for machine-verifiable
  acceptance; otherwise the existing qualitative quiet-window requirement
  stands. Fixed-seed parity separately requires an authenticated EDI 1.0.2
  package or trusted provenance-pinned assignment vectors for the concrete
  designs in `test-seed-reproducibility-all-designs.R`; the unsigned local
  source ref is not an adequate anchor. Both gates remain open; no timing or
  parity run was performed for this note.
  **Current-artifact identity recheck, 2026-10-21 (read-only):** the retained
  Oct 19 acceptance CSV/sidecar hashes still match
  `be8d37c0715d4422904d95d5d4b117d07573f43f52690b209c9ab72776f75ba4` /
  `855f3c7f4ef79852a1a66cd05510bb8902b0f11a1b3e2f8fd9af7902ecc66c88`, and
  the Oct 20 `n=5`, `batch=1`, one-repeat source-loaded provenance smoke
  hashes still match `e785cc58d05a0f33874db7b0ea0b7053e322cf8d9c39cd78e6501c6c6a7a631b` /
  `5728a707b4f604c7abe56878acfe5448624cfc0acb00a718d2620ab7c2cdaa69`.
  Their recorded DLL hashes (`2de0c2d4…` and `5a0b9497…`) differ from the
  currently installed EDI 1.0.3 DLL and checkout `R/EDI/src/EDI.so`, which
  now match at SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`
  (installed DESCRIPTION Built: 2026-10-21 11:12:19 UTC). This confirms the
  earlier stale-artifact limitation; the smoke is metadata-only and the Oct
  19 timing still fails quiet-host/blocking thresholds. No run/test occurred.
  Both the quiet-host acceptance timing and authenticated EDI 1.0.2
  fixed-seed parity gates remain open.
  - [ ] On a quiet host, verify the installed package/DLL identity and run
    the installed `n=1000`, `batch=100`, seven-repeat timing with provenance;
    require iBCRD <= 1.5 ms and blocking <= 2.5 ms. Separately compare
    fixed-seed assignment weights against an authentic EDI 1.0.2 package.

- [ ] TODO-60 (added 2026-10-07, user decision): **Pocock–Simon: O(t) work
  per arrival (O(n²) per trial)** —
  `../bug_fix_plans/pocock_simon_per_arrival_rebuild.md → TODO-1..5`.

  0.0014x of `carat`, 0.3x of `Minirand`; per-arrival cost 3.0 → 3.7 ms
  growing with t while the minimization kernel is O(k). Three O(t) steps
  per arrival in `add_one_subject()` / `assign_wt()`: `rbindlist` copies
  the whole table (L149); the full model matrix is rebuilt every arrival
  once `t > ncol(Xraw) + 2` (L157) although the rule only reads raw strata
  columns; `ensure_factor_metadata()` rescans every strata column in
  full, twice per arrival. Fix: incremental level bookkeeping; a
  class-level "rule reads the model matrix" flag that skips the rebuild
  (default `TRUE`, Pocock–Simon `FALSE`); amortized append. All
  bit-preserving (fixed-seed assignment sequence identical). Acceptance:
  per-arrival cost flat in t and ≤ 0.5 ms. The `carat` and `Minirand`
  timings are report context, not an additional ratio gate: the ≤0.5 ms
  per-arrival limit implies a whole-sequence runtime that cannot also be
  within 10x of `carat`. See TODO-59 for the shared builder.

  **Implementation status 2026-10-09, corrected 2026-10-12:** linked-plan
  TODOs 1, 3--4 are complete; TODO-2's source implementation is reopened for
  a first-arrival missing-stratum regression:
  arrivals use incremental strata metadata, avoid assignment-time model-matrix
  rebuilding, and preallocate compatible fixed-size enrollment storage with a
  safe append fallback. Source-loaded validation passed the 53-expectation
  metadata suite, 25 all-design seed checks, and 62 schema/type/bootstrap
  checks. The level map now also keeps a missing stratum separate from a
  literal category named `"NA"`. A subsequent static audit found that the
  generic first-arrival cleanup had removed a missing declared stratum before
  this map could register it. The cleanup now retains declared strata and a
  focused public regression covers a missing first stratum followed by a
  literal `"NA"` category; that new regression still needs rebuilt-package
  execution. TODO-5 remains the installed-package
  benchmark/report gate: the source-loaded median is 0.525 ms per arrival, so
  it does not yet meet the 0.5 ms target, and the batch-C++ `carat` comparison
  is infeasible for the per-arrival public R API. This release checkbox stays
  unchecked. **Additional compile-free installed benchmark 2026-10-14:**
  `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5` completed
  on EDI 1.0.3 without a CSV, during concurrent R test load. Per-arrival
  medians at t=10/100/500/1000 were 1.75/3.55/2.75/1.30 ms; whole-sequence
  median was 1486.70 ms. This load-contended result is diagnostic, not clean
  acceptance evidence, and misses the ≤0.5 ms gate at all checkpoints. The
  linked plan records the run; an isolated rerun and remaining identity/report
  gates are still needed.
  **Installed focused regression, 2026-10-18:**
  `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
  passed 67 expectations (10 test blocks, 0 failures/warnings) against
  installed EDI 1.0.3, built 2026-10-18 00:57:28 UTC, DLL MD5
  `dd43c5d0e11708aea17ba82b900f66d1`. This confirms the installed behavior,
  including the missing-first-stratum versus literal-`"NA"` case; the
  installed build metadata does not identify the checkout SHA, so it is not
  proof that the current source revision was built.
  **Source-loaded regression, 2026-10-19:** ran
  `pkgload::load_all("R/EDI", quiet = TRUE, compile = FALSE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-pocock-simon-level-rows-and-binary-match-structure-reference.R")`;
  67 passed, 0 failed/warned/skipped. This validates the current checkout's R
  source against the installed EDI 1.0.3 native library, not rebuilt native
  code. The performance, identity, and EDI 1.0.2 parity gates below remain.
  **Source-loaded recheck 2026-10-20:** reran the same focused test separately
  with `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE,
  export_all = FALSE)`; it passed 67 expectations (10 test blocks, no
  failures/warnings/skips). R was `R Under development (unstable)
  (2026-10-13 r90668)`, and the namespace path was the checkout
  `/home/kapelner/workspace/EDI/R/EDI`. Pkgload used a temporary copy of the
  available EDI 1.0.3 DLL; `R/EDI/src/EDI.so` and installed
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` both had
  SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  No compile/install occurred. This reconfirms the first-arrival missing-
  stratum fix at the checkout R layer only; it does not satisfy current-head
  native matching, the isolated timing criterion, or authentic EDI 1.0.2
  assignment-vector parity.
  **Installed benchmark diagnostic 2026-10-20 (not acceptance):** ran
  `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5 /tmp/edi-v105-todo60-bench-n8DtfP/benchmark.csv`
  against installed EDI 1.0.3 (Built 2026-10-19 20:31:50 UTC; R-devel
  r90668). Per-arrival medians at t=10/100/500/1000 were 0.50/0.70/0.45/0.65
  ms; whole-sequence median was 509.95 ms. The <=0.5 ms checkpoint limit
  fails at t=100 and t=1000. No competing R job/user process was visible at
  start, but host load ranged 3.19--3.64 on 12 CPUs, so this was not a
  strictly idle/acceptance-clean run. Checkout HEAD was
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; relevant source/test/benchmark
  files were clean and no local build occurred. Installed DLL SHA-256:
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  CSV: `/tmp/edi-v105-todo60-bench-n8DtfP/benchmark.csv` (SHA-256
  `3a8fab5447a1aabe261597c62f25a393ca5eeab27d3d1542cbe219ce04fec88b`).
  This diagnostic does not close the timing gate; authentic EDI 1.0.2
  fixed-seed assignment-vector parity remains open.
  **Benchmark provenance safeguard, 2026-10-20:** the optional CSV output now
  refuses to overwrite an existing CSV or sidecar and writes an adjacent
  `.provenance.txt` record containing parameters/seeds, package/library/DLL
  path and SHA-256, checkout HEAD plus worktree status/tracked-diff SHA-256,
  R/platform/session, thread environment, and start/end host load and CPU
  affinity. `test-pocock-simon-benchmark-provenance-reference.R` passed 15
  assertions for clean, dirty, and unavailable Git states without running the
  benchmark. No timing result, native build, or canonical output was produced.
  **Post-reinstall installed regression and artifact audit, 2026-10-21:**
  `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
  passed all 67 expectations against installed EDI 1.0.3 (no failures,
  warnings, or skips), including the first missing-stratum/literal-`"NA"`
  case, fixed-seed assignment fixture, and zero matrix-builder calls during
  enrollment followed by one on first post-enrollment access. The installed
  package was built 2026-10-20 21:56:26 UTC; installed and checkout
  `R/EDI/src/EDI.so` are byte-identical (SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`). The
  installed package has no embedded checkout/R-source hash, so this is
  current installed-behavior evidence, not complete source provenance.
  Retained timing CSVs are summary-only and lack run provenance: the Oct 20
  `benchmark.csv` SHA-256 is
  `3a8fab5447a1aabe261597c62f25a393ca5eeab27d3d1542cbe219ce04fec88b`, with
  stdout retained but no adjacent sidecar; it recorded 0.50/0.70/0.45/0.65 ms
  and failed the t=100 and t=1000 caps on a loaded host. The older Oct 14
  `edi_v105_todo60_pocock_simon_arrivals.csv` SHA-256 is
  `e075920b5c927a384a2cc40b2db12600de2f1f4f3964259e66a794544822ca4c`, also
  with no sidecar. The candidate EDI 1.0.2 source archive remains
  unauthenticated, lacks a native binary, and supplies no retained assignment
  vectors. Thus the isolated, provenance-pinned timing acceptance and
  fixed-seed parity against an authentic 1.0.2 baseline remain open; this
  focused rerun does not close TODO-60.
  **Acceptance-matrix audit and installed rerun, 2026-10-21:** reran the
  focused `test-pocock-simon-level-rows-and-binary-match-structure-reference.R`
  against installed EDI 1.0.3; all 67 expectations passed (no failures,
  warnings, or skips). This covers the eight-row late-level/missing-value
  fixture, including the expected vector `c(1,0,0,1,0,1,0,0)`, and verifies
  deferred model-matrix construction. That expected vector is a checkout test
  expectation, not an independently captured EDI 1.0.2 result, so the
  baseline-parity matrix row remains **unverified**. The timing row also
  remains open: the Oct 20 run misses the 0.5 ms caps at t=100 and t=1000;
  the Oct 14 values (0.35/0.35/0.35/0.40 ms) have no sidecar and cannot
  establish their run conditions. The report already has a full n=1000,
  ten-warmed-run context table (EDI 3136 ms, carat 4.41 ms, Minirand 1054.50
  ms), but it is historical and not a parity/acceptance result; refresh is
  still required by the run protocol. The current harness can write a sidecar
  with DLL, HEAD, tracked-diff, worktree status, session, and host data, but
  its tracked-diff hash does not hash untracked file contents and it records
  no fingerprint for the installed package's R namespace. **Harness follow-up,
  2026-10-21:** the optional sidecar now also records the loaded EDI namespace
  path and a deterministic SHA-256 over sorted relative paths and per-file
  hashes under the installed namespace's `R/` directory. The focused
  provenance test passed 23 expectations, including a synthetic changed-file
  digest check and the actually loaded namespace. This closes the instrumentation
  gap for future runs only; it does not retroactively authenticate either
  retained timing CSV. No benchmark, build, or install ran. Neither retained
  timing CSV has an adjacent sidecar. Smallest useful next check is therefore
  not another correctness rerun: obtain an authenticated EDI 1.0.2 package or
  independently recorded vectors, then compare the exact fixture before any
  authorized rebuild/isolated timing run. TODO-60 remains open.
  **Operation-count guard validation:** the focused level-rows test, including
  the operation-count assertions, passed 86 expectations across 10 test blocks
  against installed EDI 1.0.3. Installed and checkout `R/EDI/src/EDI.so` are
  byte-identical with SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`; the
  exact invocation is not recorded here. This is installed-package correctness
  evidence, not a timing result or proof that the current checkout R source was
  loaded. The guard checks that later arrivals key only their current values,
  counts-row growth tracks newly observed levels, and model-matrix builds are
  deferred until access; it does not bound level-map lookup or matrix
  resize/copy cost. The isolated timing and authentic EDI 1.0.2 parity gates
  remain open.
  - [ ] After TODO-56 is terminal, run
    `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5` on an
    idle host; record installed package/DLL identity and host provenance, and
    require per-arrival medians at t=10/100/500/1000 to be <= 0.5 ms with no
    material upward trend. Separately verify fixed-seed assignment-vector
    identity against an authentic EDI 1.0.2 package and refresh the full
    n=1000 report context; do not use a carat ratio as an acceptance gate.

  **Current artifact/source reconciliation, 2026-10-21 (read-only):** the
  retained Oct 20 `benchmark.csv` (SHA-256
  `3a8fab5447a1aabe261597c62f25a393ca5eeab27d3d1542cbe219ce04fec88b`) has
  only its CSV and stdout retained, no adjacent sidecar. Its checkpoint medians
  0.50/0.70/0.45/0.65 ms at t=10/100/500/1000 miss the 0.5 ms cap at t=100
  and t=1000; host load was 3.19--3.64 on 12 CPUs. The 86-expectation
  operation-count test result is installed EDI 1.0.3 evidence, with no exact
  invocation recorded; it checks prefix re-keying and deferred matrix builds
  but does not prove current checkout R behavior or bound map-lookup/resize
  work. Current-source inspection confirms the preallocated compatible-row
  path, incremental level registration, and Pocock--Simon matrix-build opt-out.
  The 23-assertion sidecar test makes future run provenance available but
  cannot authenticate the retained CSV retroactively. Next, obtain trusted
  EDI 1.0.2 fixed-seed assignment vectors for parity; then, when an authorized
  quiet-host slot is available, run the documented acceptance command with a
  fresh CSV path and sidecar. TODO-60 remains open.

- [x] TODO-61 (added 2026-10-07, user decision): **Binary matching hands
  `nonbimatch` squared distances with a `double.xmax` diagonal** —
  `../bug_fix_plans/binary_match_nonbimatch_distance_input.md → TODO-1..3`.

  `DesignFixedBinaryMatch` is 0.6–0.7x of `nbpMatching`'s own pipeline
  although EDI's distance step is 2x faster than `gendistance()`; the
  shared matcher runs 1.6x slower on EDI's input. Measured at n = 1000,
  p = 4: a zero diagonal instead of `double.xmax` is 1.3x with **identical
  pairs** (plan TODO-1, bit-preserving); unsquared distances (the
  objective `nbpMatching` and Lu et al. 2011 minimize) are 2.2x in total
  but change 22% of pairs (plan TODO-2, **decision-gated default change**,
  listed in the standing constraint below; ships behind a
  `match_objective` argument with baseline regeneration if accepted).
  Acceptance: ≥ 1x of the `gendistance` + `nonbimatch` row after TODO-1.
  Independent of every other item.

  **Implementation status 2026-10-09:** matching now uses a zero diagonal
  and ordinary distance by default, with `match_objective =
  "squared_distance"` preserving the prior objective on both public design
  classes. Roxygen and NEWS record the default change, and the cross-product
  regression passes 55 expectations across sample sizes, dimensions and
  Euclidean/Mahalanobis modes. Linked TODOs 1-2 are closed; TODO-3's installed
  benchmark/report remains. The concurrent source-loaded diagnostic was only
  0.80x and was correctly not substituted for the installed acceptance run,
  so this release item stayed unchecked. An installed EDI 1.0.3 focused
  rerun on the design-table fixture (n=1000, p=4; four continuous normal
  covariates) timed the full EDI construction/ingestion/assignment workflow
  against `gendistance` + `nonbimatch` + within-pair coin flips: EDI was
  578/537/473 ms (median 537), canonical was 890/897/881 ms (median 890),
  for 1.66x, meeting the ≥1.3x acceptance threshold. Linked-plan TODO-3 is
  complete. On 2026-10-14, the canonical
  `benchmark_model_fits.md` row was refreshed to those medians and the Welch
  timing p-value (0.00618, **); the three-replicate command and fixture are
  recorded in the linked plan. The installed benchmark/report acceptance is
  complete.

- [ ] TODO-62 (added 2026-10-07, user decision): **Benchmark harness: R6
  construction inside the timed region misreads sub-10 ms rows** —
  `../bug_fix_plans/benchmark_r6_construction_timing.md → TODO-1..4`.

  Measurement fix in `R/benchmark/benchmark_model_fits.R`, not a package
  change. The Zhang exact-CI row reads 0.4x of `fisher.test(conf.int =
  TRUE)`; profiled, the CI is 1 ms (parity) and the other 2 ms is
  `InferenceIncidExactZhang$new()`, timed on purpose because results are
  cached per object. Every R6 row in the two 2026-10-07 tables carries a
  1.4–2 ms construction the comparators do not. Fix: time construction
  separately and report total / construction / procedure columns, compute
  `Speedup` on the procedure, color slower-than-canonical rows (today they
  render white), and add a `sections=` filter so the two tables
  regenerate in minutes rather than 90. Independent of every other item.
  **Source progress 2026-10-10:** significant slower-than-canonical rows now
  receive a light-red background, defined consistently in the shared
  methodology and HTML legend. R6 procedure/design rows now report separate
  total, construction, and cache-safe procedure measurements: a fresh
  configured object is prepared outside each timed procedure batch, so no
  benchmark-only public cache-reset API is needed. `Speedup` and `Timing Pval`
  use procedure time. Focused installed timing and generated-report acceptance
  remain open. The harness now also accepts
  `--sections=procedures,designs` to run just those focused tables (skipping
  the model-fit, Wald, and utility loops, including the utility wrapper
  compile); generated reports were not hand-edited and require an authorized
  benchmark run to regenerate. **Isolated output-path diagnosis 2026-10-14:**
  an instrumented official `--sections=designs` run completed all six design
  rows under installed EDI 1.0.3 and successfully wrote both Markdown and HTML
  reports in `/tmp/edi-todo62-instrumented.xpTSrk/R/package_metadata/`.
  Immediately before writing, cwd was the expected R root, the resolved parent
  existed and was writable, and neither target existed. The two prior
  `writeLines` failures (`file(con, "w"): cannot open the connection`) are
  therefore not currently reproducible; their path warning was hidden by
  `options(warn=-1)`. No canonical report was overwritten. The exact six-row
  output and diagnostic are in the linked plan. TODO-62 remains open for the
  Zhang parity criterion and canonical artifact synchronization.
  A separate noncanonical installed-package probe on 2026-10-15 (`n=1000`,
  fixed synthetic seed 20261015) measured Zhang CI procedure 4.83 ms vs.
  `fisher.test(conf.int=TRUE)` 0.87 ms (0.18x) and a 0.00642 maximum absolute
  log-bound difference. Because this was not the report's canonical fixture,
  it is diagnostic only and does not replace the canonical Zhang parity or
  artifact-synchronization gates. Harness/result are preserved in `/tmp` and
  described in the linked plan.
  **Section-parser guard, 2026-10-20:** the extracted pure parser rejects an
  explicitly empty `--sections=` rather than falling back to the exhaustive
  default. Its focused contract test passed 9 assertions; both shard planners
  validated the refreshed inventory. No benchmark or report generation was
  run, and the canonical Zhang parity/tolerance and report-sync gates below
  remain open.
  **Current parser and report-artifact recheck, 2026-10-21:** the focused
  `test-benchmark-model-fit-section-selection-contract-reference.R` reran
  against installed EDI 1.0.3 and passed all 9 assertions; no benchmark or
  report generation ran. The two tracked Markdown copies remain different
  (SHA-256 `27c0153604eadd3ba9578a63457e1ba4106e42a1ed0181e834fc46021dc69ab1`
  in `R/package_metadata/` and
  `9cf7b03ae0dbc13e4a67ea38c374d80cad8fed700f2ecbe50efd979d40624a7e` in
  `R/benchmark/`), while the two HTML copies are byte-identical (SHA-256
  `ae366ee3a325ac42e70dacd55e736d3743529fe6e3680f309973403d3d0f0408`). Both
  Markdown copies still show the unsplit Zhang row (2.44 ms EDI vs. 0.96 ms
  Fisher, 0.39x); the generated artifacts therefore remain stale relative to
  the construction/procedure methodology. The owner-approved numeric parity
  tolerance and synchronized report regeneration remain open.
  **Loaded R-layer identity follow-up, 2026-10-21:** the benchmark report
  previously recorded the installed package path but not a fingerprint for
  the loaded namespace's R payload. `benchmark_model_fits.R` now emits the
  namespace path, payload file count, and deterministic SHA-256 manifest in
  both compilation-context branches. The focused section-selection/provenance
  test passed 24 expectations, including a loaded-namespace digest and
  synthetic payload-change check. No benchmark/report generation ran and no
  generated report was changed. This binds future report generation only;
  TODO-62's owner-approved parity criteria and canonical report synchronization
  remain open.
  **Mixed `all` selector validation, 2026-10-21:** the section parser now
  validates every supplied name before honoring `all`, so a typo such as
  `--sections=all,modles` fails instead of silently selecting every section;
  `all` combined with a valid name remains accepted. The focused
  `test-benchmark-model-fit-section-selection-contract-reference.R` passed
  against installed EDI 1.0.3 after adding both cases. No benchmark or report
  generation ran; the numeric parity and report-synchronization gates remain
  open.
  **Three-pair artifact identity recheck, 2026-10-21 (read-only):** the
  retained diagnostic under `/tmp/edi-todo62-paired3.1o5VF5/` records the
  canonical seed-45265, n=1000 fixture and EDI 1.0.3, but only three pairs.
  Its recorded installed-DLL SHA-256 is
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  unlike the currently inspected installed/checkout DLL
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`.
  The diagnostic median `Fisher / EDI` procedure ratio is 0.2002, below the
  approved `>=1` speed target; its `0.00441339774953` maximum log-bound
  difference is evidence, not an approved endpoint tolerance. Thus it cannot
  establish current-provenance acceptance or resolve the owner choice of
  endpoint metric/bound. The tracked reports still contain the stale Zhang
  row; their HTML copies match but their Markdown copies differ as noted
  above. No benchmark, regeneration, or canonical report update occurred.
  - [ ] Set and record an owner-approved numeric Zhang parity tolerance;
    rerun the canonical fixture and confirm both parity and report rows.
    Only then regenerate and synchronize all four tracked reports from the
    harness (never by hand-editing generated artifacts).
  **Owner-criteria provenance check, 2026-10-21:** the project already has an
  owner-approved numeric speed target in `release_v1_2_0.md → TODO-29` and
  `canonical_parity_resampling_rows.md → TODO-3`: existing-object EDI CI
  procedure time must be no more than `1x` `fisher.test`, and the complete EDI
  row must be no more than `1.5x` the comparator after construction is
  reported separately. With this report's convention, that is
  `Fisher / EDI >= 1` for procedure speed and `EDI total / Fisher <= 1.5` for
  the whole row. The retained 30-pair median Fisher/EDI ratio `0.208x` (IQR
  `0.188–0.246`) is below the approved procedure target. The remaining owner
  decision is the cross-implementation CI endpoint error metric and numeric
  Zhang-vs-`fisher.test` bound: the canonical maximum absolute log-bound
  discrepancy `0.00441339775` is evidence, not a selected tolerance, and
  `pval_epsilon=1e-6` controls inversion precision, not endpoint parity.
  The `1e-12` summation-order constraint in `release_v1_2_0.md → TODO-29`
  and `canonical_parity_resampling_rows.md → TODO-3`, plus the `1e-10`
  current-interval comparison in TODO-3, preserve EDI implementation parity;
  neither is a Zhang-vs-Fisher endpoint acceptance bound.
  Installed EDI 1.0.3 deterministic tests passed 49 assertions for
  statistics, scalar p-values, internal CI crossing/bracketing, plus 5 for
  serial/parallel CI agreement. They verify null-p-value parity with
  `fisher.test` at `1e-8` and internal behavior, but do not compare CI
  endpoints against Fisher under an approved endpoint bound. After the owner
  selects that endpoint criterion, collect current-provenance paired canonical
  timing and verify the already-approved speed target.
  **Read-only gate audit, 2026-10-21:** the canonical seed-45265 fixture's
  maximum absolute log-bound discrepancy is 0.00441339775 (Zhang bounds
  ~0.132031/0.667727; Fisher ~0.127618/0.668427). The noncanonical seed
  20261015 discrepancy is 0.00642 and is diagnostic only. The preserved
  canonical timing has 30 alternating pairs, median procedure times 7.750 ms
  (Zhang) vs. 1.717 ms (Fisher), paired Fisher/Zhang ratio 0.208x (IQR
  0.188–0.246); its installed package was EDI 1.0.3 but the preserved metadata
  lacks source revision and DLL hash, so it does not validate the current
  installed artifact. All four tracked reports still contain the old unsplit
  timing row; Markdown copies differ in content while HTML copies match.
  Therefore a current-provenance paired run, the remaining owner-selected
  endpoint criterion, and a report reconciliation policy are still required
  before the harness regenerates the canonical reports. The procedure-speed
  target is already specified by TODO-29; the existing timing evidence falls
  short of it. No benchmark or canonical report was changed in this audit.
  **Bounded canonical-fixture diagnostic, 2026-10-21:** a standalone
  installed-package run reconstructed seed 45265 (`n=1000`, four covariates,
  table vector `348,303,152,197`, `num_cores=1`), warmed both procedures, then
  collected three randomized interleaved fresh-object Zhang / Fisher pairs;
  construction was timed separately. Median procedure times were 4.029 ms
  (Zhang) and 1.474 ms (Fisher), with median paired Fisher/Zhang ratio 0.200;
  the maximum absolute log-bound difference was 0.00441339775. This small
  diagnostic is not an acceptance run: host load average was about 4.96 at
  start/end and the Zhang pair times ranged from 3.820 to 7.362 ms. It does
  not select the owner-approved endpoint metric/tolerance or provide
  acceptance-grade timing; its median Fisher/EDI ratio is below the existing
  TODO-29 procedure-speed target. It also does not resolve report-copy
  reconciliation. The successful run exited 0 under a 90-second timeout,
  with outputs isolated under `/tmp/edi-todo62-paired3.1o5VF5/`; no tracked
  benchmark CSV or report was written. Provenance: installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; installed R-layer
  manifest SHA256 `cb1b1b5812cee41799ef53c1f0af1271d5a7c48e45b975b1954889e777cc76cd`
  (3 files); loaded DLL SHA256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`.
  Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9` with a dirty
  worktree; checkout Zhang R/C++ source SHA256s were
  `2886d74494573365c7b3cc3f4ba0a07325c42a789b04daff303ec925ced24542` /
  `bf7bdd64ae9313b78b2c87f2a158d39c550f6bd047b2529aa033ae8a53b95dfd`.
  Raw paired samples SHA256:
  `c067a45211e180b6895bf9f5acb6cd8898a16f91c57375dcd48af89afd4df2e2`;
  construction samples SHA256:
  `eb85e26c4a47dcf9d664dfca079ef9ea11bf33c07a0642e9db127ba3aeee4ba6`;
  summary SHA256:
  `ebfca1686048e4575228fb389375e4d44f96ede983b1f329f347dae6b9df3951`;
  metadata SHA256:
  `8f562db148b743a20abd44cb446894c8ff51f844ea8d6077b611806ec72d0911`.

  **Maintainer decision brief (read-only audit, 2026-10-21):** the linked
  benchmark times `compute_exact_confidence_interval()` and times
  `log(stats::fisher.test(tab)$conf.int)` separately; it does not calculate
  or assert endpoint agreement. `pval_epsilon=1e-6` is the CI inversion
  precision, not the cross-implementation endpoint tolerance. Existing
  endpoint observations are max absolute differences on the log-odds-ratio
  scale: `0.00441339775` for canonical seed 45265 and `0.00642` for one
  noncanonical fixture. Possible explicit endpoint gates are (a) `<=0.005`,
  which is just above the canonical observation but below the noncanonical
  one, or (b) `<=0.01`, which admits both observed cases (about a 1% relative
  odds-bound difference); these are choices, not validated guarantees. The
  owner-approved speed criteria and the retained timing failure are recorded
  in the preceding Owner-criteria provenance check; they are not open choices.
  Thus only the cross-method endpoint metric and tolerance remain for
  maintainer selection.

  Report copies also need explicit reconciliation: all four still show the
  obsolete unsplit Zhang row `2.44 ms` vs. `0.96 ms` (`0.39x`). The HTML
  copies are byte-identical (SHA-256
  `ae366ee3a325ac42e70dacd55e736d3743529fe6e3680f309973403d3d0f0408`), but
  the Markdown copies differ (package-metadata SHA-256
  `27c0153604eadd3ba9578a63457e1ba4106e42a1ed0181e834fc46021dc69ab1`,
  benchmark SHA-256
  `9cf7b03ae0dbc13e4a67ea38c374d80cad8fed700f2ecbe50efd979d40624a7e`).
  Besides the stale Zhang row, `R/package_metadata/benchmark_model_fits.md`
  has the updated BinaryMatch row (537/890 ms, 1.66x) while
  `R/benchmark/benchmark_model_fits.md` retains 639/453 ms (0.71x); metadata
  also contains the Oct 14 design-construction and Pocock–Simon context
  sections absent from the benchmark copy. Their shared procedure table also
  has conflicting OLS-kernel wiring descriptions. These differences mean the
  Markdown files cannot be treated as interchangeable. After the endpoint
  choice and a provenance-current canonical rerun, regenerate via the
  harness, then reconcile the Markdown-only sections deliberately and verify
  the Zhang row and required columns in all four files. No benchmark/report
  generation or overwrite was performed for this audit.

  **Retained paired-artifact inventory, 2026-10-21 (read-only):** the two
  earlier 30-pair CSVs under `/tmp/todo62_paired_zhang_20261016_01/` and
  `_02/` are still present (31 lines each including the header); their SHA-256
  values are `a1a2d53a8eb2bc7452a70593eda93b0b6968163e97875834065e7b5d299a15bd`
  and `c12065cd6aaad584dbf421661b1c95fa4615835aff19003302aba6b5b38f6c79`.
  Their shared metadata SHA-256 is
  `08efbed2bf50da36f28eb24cca1580109c142a89b55e2d5f9274a2c1e5b9b85c`;
  it records EDI 1.0.3, DLL path/mtime, R/platform, thread limits and the
  canonical seed-45265 fixture, but no DLL hash, checkout/source revision, or
  loaded-R-payload fingerprint. Their procedure medians were EDI/Fisher
  9.420/1.413 ms (`0.149x`) and 7.750/1.717 ms (`0.208x`), with construction
  separate; both fail the approved `Fisher / EDI >= 1` target. Although the
  current installed and checkout DLLs match at SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`, that
  cannot authenticate these Oct. 16 runs. The previously recorded isolated
  full-section output directories for 15 procedure and 6 design cases are no
  longer present. The separately recorded current-provenance three-pair
  canonical diagnostic above is still only diagnostic (small sample and
  host-load variation), not a substitute for the full section output or an
  acceptance timing run. The tracked reports remain the stale unsplit
  snapshots described above: HTML copies are byte-identical, Markdown copies
  differ. Therefore the owner-selected endpoint metric/tolerance, a
  provenance-current acceptance run, and harness-based report regeneration
  plus deliberate Markdown reconciliation remain open. No benchmark/report
  generation or canonical write occurred in this inventory.
  **Native identity recheck, 2026-10-21 (read-only):** at 16:30 IDT the
  installed `EDI.so` and checkout `R/EDI/src/EDI.so` both hash to
  `13a6dd534bacf3d9fa8e63d255c407745c26917e4c0e043f8bc1476f7cdcd313`
  (14,727,184 bytes; mtime 16:27:21 IDT), at checkout HEAD
  `bf3addd46b63c405b961178be09ea4e03c7c6275`. An earlier check during this
  audit found both DLLs at `2db64ed8ef36e13b1bc4101fee46b9e007afe4701e9bde11c34a88b564844d67`
  at the same HEAD, so the native bytes changed during the audit. This
  supersedes the previously noted then-current `f7cf...` identity; neither
  hash binds the retained timing to those bytes. The October 16 30-pair
  receipts have no DLL/source hash, and the three-pair diagnostic records DLL
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94` at
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. No benchmark, report
  generation, or canonical write was performed. The owner-selected endpoint
  criterion, current-provenance acceptance run, and report synchronization
  remain open.

- [ ] TODO-63 (added 2026-10-07, user decision): **C++ kernels accept a
  `warm_start_beta` of the wrong length and corrupt the heap** —
  `../bug_fix_plans/cpp_warm_start_length_checks.md → TODO-1..5`.

  Reproduced on installed 1.0.2: a single
  `fast_logistic_regression_cpp(X, y, TRUE)` (positional `TRUE` becomes a
  length-1 warm start; `beta = *warm_start_beta` at
  `fast_logistic_regression.cpp:91` has no length check) corrupts the heap
  and the next `gc()` segfaults. Source audit of every `warm_start_beta`
  dereference in `src/`: unguarded in logistic, Poisson (checks only
  `size() > 0`), Cox (two sites, out-of-bounds read loop), beta regression
  (block assignment, reached from all three exports) and robust
  (`apply_fixed_values` indexes into it unchecked); the other eleven
  kernels branch on the size. R6 callers are safe
  (`get_fit_warm_start_for_length()`, `inference_all_abstract.R:725`);
  direct callers (tests, benchmarks, the Python bindings, which pass
  `warm_start_beta` in eight files) are not. Fix: one inline length-check
  helper throwing `std::invalid_argument` outside any OpenMP region, at
  every warm-start site (also `warm_start_weights` /
  `warm_start_fisher_info`); a testthat contract test that every exported
  kernel errors cleanly on wrong-length warm starts, run under the
  `R-CMD-check-sanitizers` and `R-CMD-check-valgrind` jobs. Bit-preserving
  (only rejects inputs that were undefined behavior). Targeted compile
  only. Independent of every other item.
  **Source progress 2026-10-09:** F2's five unsafe kernel families now reject
  malformed coefficient starts at their native entry points, with matching
  weight/Fisher guards and a CRAN-shipped testthat contract file. Python
  bindings forward starts unchecked, so this native boundary also protects
  them. **Follow-up source correction 2026-10-11:** the Cox LBFGS dispatcher
  now forwards its Fisher start into the guarded implementation; a malformed
  Fisher matrix had otherwise been ignored on that path. The full
  **Adjacent-start audit, 2026-10-18:** the exhaustive pass found two
  additional silent-ignore paths: `fast_ordinal_clmm_internal()` and
  `fast_dep_cens_transform_optim_internal()` cold-started when a supplied
  `warm_start_params` had the wrong length. Both now call the shared length
  guard before consuming the start; the CRAN testthat contract covers short
  and long lengths for each API, and Python tests now cover the corresponding
  bindings. The pass found no other size-conditional silent-ignore for
  consumed warm starts; documented unused weights remain no-ops. This closes
  the source-audit subtask, not runtime validation. The explicitly required
  targeted compile/sanitizer/Valgrind validation remains open, so this release
  item is deliberately unchecked. The existing Python regression
  `test_wrong_length_warm_start_beta_raises_value_error` also passed against
  the preinstalled Python extension on 2026-10-14 (`1 passed in 0.29s`, via
  `python/.venv/bin/python -m pytest -q`); this is only a logistic smoke on
  that binary and does not validate the current C++ checkout or replace the
  pending rebuild-backed Python/sanitizer gate. **Stale-install check,
  2026-10-18:** the full CRAN contract was attempted against installed EDI
  1.0.3 and reported 16 failures / 180 passes. The failures include missing
  newly referenced wrappers and no rejection from the two newly guarded
  internals; the installed `EDI.so` mtime (`03:57 +0300`) predates the
  checkout edits to `fast_ordinal_clmm.cpp` and
  `fast_survival_models_optim.cpp` (`05:59 +0300`). Treat this run only as
  confirmation that the installed package is stale for these changes, not as
  source-regression evidence. The explicit rebuild-backed gate below remains
  open. The Python venv extension is stale for the companion binding/tests as
  well: `_core.cpython-314-x86_64-linux-gnu.so` is timestamped
  `2026-10-18 04:23 +0300`, before the binding edit (`06:19`) and the two
  new Python tests (`06:04`). Do not treat runs against that extension as
  validation of the current binding/source changes.
  **Static wrapper-test crosswalk, 2026-10-19:** all 63 exported wrappers
  accepting `warm_start_fisher_info` are referenced by the permanent contract
  test in malformed-matrix rejection or documented bypass/no-op assertions.
  Normalizing namespaced R call heads corrected an earlier undercount; this is
  test-presence evidence only and does not replace executing the tests against
  matching native code.
  **Matching-native R validation, 2026-10-20:** the checkout was installed
  with `EDI_UNITY=0 R CMD INSTALL --no-multiarch R/EDI` on 2026-10-19
  (installed package version 1.0.3; `EDI.so` SHA-256
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`,
  19,810,248 bytes, mtime 2026-10-19 23:47:15 +0300). Against that installed
  package, the CRAN contract file
  `test-kernel-warm-start-length-contracts.R` passed all 204 expectations
  (`testthat::test_file(..., package = "EDI")`), and the extended
  `test-mixed-kernel-warm-start-shape-guards-reference.R` passed 23. This
  closes the matching-native R malformed-start contract gate only. Python
  wrong-length-start validation and sanitizer/Valgrind CI remain open; no
  result against the previously timestamped Python extension is substituted.
  **Additional installed-package sibling revalidation, 2026-10-20:** eight
  focused tests passed (64 assertions) for log-identity binomial, probit,
  robust weighted, ordinal, ordinal probit/cauchit/cloglog, Weibull,
  negative-binomial, and weighted log-identity binomial wrong-length guards;
  the ZINB sibling test passed seven more assertions. These ran against EDI
  1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, with
  `EDI.so` at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`,
  SHA-256 `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  (MD5 `a75519a9256c0b3121398032314291d4`). This identity differs from the
  earlier recorded installed DLL, so these results apply only to the package
  loaded in this run and do not establish checkout-native equivalence. No
  build/install was run; ASAN/UBSAN and Valgrind remain open.
  **Fresh user-managed rebuild with checkout-R overlay, 2026-10-20:** the
  installed namespace-only CRAN contract reported 12 failures / 184 passes;
  the failures were missing R wrapper functions in the installed R layer, not
  wrong-length guards returning incorrectly. Re-running with
  `pkgload::load_all("R/EDI", compile = FALSE)` against the same native
  library passed all 204 CRAN expectations, plus 64 assertions across the
  eight sibling files and 7 ZINB assertions (275 total, no failures). The
  loaded overlay DLL at `/tmp/RtmpHlgw5S/pkgload99164b557f1e/EDI.so` had
  SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  matching the freshly installed binary and checkout `R/EDI/src/EDI.so`.
  This closes the R-source/native malformed-start runtime gate for these
  cases. The installed R-layer mismatch and sanitizer/Valgrind CI remain open.
  Local Python-extension provenance is not established; the same-source CI
  record below separately closes the Python wrong-length suite-validation
  subgate. No build/install was performed by the agent.
  **User-reinstalled package recheck, 2026-10-20:** using `library(EDI)` with
  no source overlay, `test-kernel-warm-start-length-contracts.R` passed all
  204 expectations. The installed package is EDI 1.0.3 and its DLL SHA-256 is
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`, equal
  to `R/EDI/src/EDI.so`. This confirms the installed R layer now contains the
  wrappers missing in the earlier namespace-only run and closes the matching
  installed-package R contract gate. The local Python extension remains
  unproven, although the same-source CI record below closes the Python
  wrong-length suite-validation subgate. Sanitizer/Valgrind CI remains open;
  the user, not this agent, performed the rebuild/install.
  **Local installed-package Memcheck, 2026-10-20:** the same 204-expectation
  CRAN contract passed under Valgrind Memcheck against EDI 1.0.3. Test output
  is in `/tmp/edi-v105-todo63-installed-valgrind-20261020.log`; the main R
  process's Memcheck log, `/tmp/edi-v105-todo63-valgrind-2.log`, reports
  `ERROR SUMMARY: 0 errors from 0 contexts` (the traced child-process logs
  also report zero). This is a local
  check of the installed malformed-start contract, not the project's
  `R-CMD-check-valgrind` or sanitizer CI job; those release gates remain open.
  **Existing-extension Python warm-start recheck, 2026-10-20:** the targeted
  node `python/tests/test_fast_logistic_regression.py::test_wrong_length_warm_start_beta_raises_value_error`
  passed (`1 passed in 0.37s`) using Python 3.14.4 and the existing
  `edi-kernels` 1.0.2 extension at
  `python/.venv/lib/python3.14/site-packages/edi_kernels/_core.cpython-314-x86_64-linux-gnu.so`
  (SHA-256
  `ea216d1626310beedcacc18bccf6419207da78c34ac1a5b41f1cea983b83de05`,
  mtime `2026-10-18 11:17 +0300`). The package initializer came from checkout
  `python/src/edi_kernels/__init__.py`; the relevant Python sources/tests are
  clean at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Although the
  extension timestamp follows the recorded source edits, no build manifest or
  embedded commit ties it to this checkout. This is a focused smoke of that
  existing binary, not rebuild-backed Python validation or sanitizer
  evidence. No build/install occurred.
  **Same-source Python CI validation, 2026-10-18:** successful Build
  `edi_kernels` wheels run [39110868916](https://github.com/kapelner/EDI/actions/runs/39110868916)
  tested commit `4d2531e97bc0636d3409003576a5766d15a308d0`; its Python
  coverage job 117626532957 successfully installed the editable package and
  ran the complete `python -m pytest tests -q --cov=edi_kernels` suite. The
  workflow source specifies `pip install -e "./python[test]"`. The full suite
  includes the logistic, ordinal-CLMM, and dependent-censoring malformed-start
  tests. `git diff --name-status 4d2531e97bc0636d3409003576a5766d15a308d0
  HEAD -- R/EDI/src python` is empty, so relevant sources/tests are unchanged
  at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This closes the Python
  suite validation subgate based on same-source CI, not the local extension
  provenance. R targeted compile/relink validation and ASAN/UBSAN/Valgrind CI
  remain open; no artifact download or local build/install was done.
  **Focused checkout-R length-contract recheck, 2026-10-20:** ran
  `Rscript -e 'pkgload::load_all("R/EDI", compile=FALSE, recompile=FALSE, quiet=TRUE); testthat::test_file("R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R", reporter="summary")'`.
  All 204 expectations passed, with 0 failures, warnings, or skips. Checkout
  HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the test source SHA-256
  is `b8cc1c438592d58760bca872a5de58219caf2d0c434bb1eb5eb686a9cd0c1171`.
  The loaded source-overlay DLL was
  `/tmp/RtmpoVXB57/pkgloadf58b237eaac1a/EDI.so`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to both checkout `R/EDI/src/EDI.so` and the installed EDI
  1.0.3 DLL at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`. This
  exercised checkout R definitions against that already-built native artifact
  with compilation/recompilation disabled; it is not an installed-library R
  layer run and does not substitute for the separately authorized
  installed-build/relink or sanitizer/Valgrind gates. No build/install was
  performed here.
  **Current installed-native identity and contract, 2026-10-21:** read-only
  SHA-256 checks show installed
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` and
  checkout `R/EDI/src/EDI.so` are byte-identical at
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`
  (14,727,184 bytes; mtimes differ by 0.04 seconds). The installed RDB is
  newer than the guarded R sources. Against `library(EDI)` with no source
  overlay, `test-kernel-warm-start-length-contracts.R` passed all 204
  expectations. The guarded C++ files and contract assertions are unchanged
  from the successful ASAN/UBSAN and Valgrind CI SHA; the current test diff
  only qualifies eight wrapper calls with `EDI:::`. This strengthens
  current-installed behavior and native identity evidence, but file identity
  does not reveal the build's `EDI_UNITY` setting or authenticate the RDB's
  exact source contents. Keep the checkbox open pending explicit build-mode/
  installed-source provenance and final gate review; no build/install was run
  in this audit.
  **Read-only build-metadata audit, 2026-10-21:** installed DESCRIPTION
  identifies EDI 1.0.3, R 4.7.0, x86_64 Linux, and Built time
  `2026-10-20 21:56:26 UTC`; the DLL ELF `.comment` identifies GCC 15.2.0.
  Checkout `src/Makevars` was generated at `2026-10-21 00:56:26 +0300`, seconds
  before the DLL, and currently lists `unity_01.o` through `unity_10.o`. This
  records the current generated object layout and strongly suggests unity-mode
  configuration for that install, but without its configure/install log it
  does not prove the actual compile command, `EDI_UNITY` environment, or
  compiler flags. The build metadata has no source-tree digest/commit record;
  current HEAD is `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, while
  `kk21_stepwise_survival.cpp` has a later uncommitted worktree edit timestamp
  than the DLL. Thus the hash-equal artifacts do not authenticate the entire
  current worktree as build input. The 204-expectation installed test above is
  tied to DLL SHA-256 `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`;
  targeted rebuild/relink and sanitizer/Valgrind gates remain open.
  **Build-provenance field audit, 2026-10-21:** current
  `/usr/local/lib/R/etc/Makeconf` records `CXX20=g++`,
  `CXX20STD=-std=gnu++20`, tuned `CXX20FLAGS` (`-O3 -march=native
  -funroll-loops -fno-math-errno -fno-semantic-interposition -fno-plt`, with
  empty `LTO`), and `SHLIB_OPENMP_CXXFLAGS=-fopenmp`; generated `PKG_CXXFLAGS`
  add `-DNDEBUG -DEIGEN_NO_DEBUG`. The current generated header says
  `EDI_UNITY=1`, while the earlier documented `EDI_UNITY=0` install identifies
  a different DLL hash, so there is no evidence current DLL `ae4f...` came
  from a per-file build. These configuration snapshots do not establish the
  effective compiler/linker command used for that binary.
  `edi_build_info_cpp()` reports compiler version and configured C++ flags but
  omits the generated UNITY value; neither it nor saved artifacts binds the
  DLL to a source-tree/dirty-state digest, exact compiler executable/toolchain,
  or complete build log. Approval-gated closure needs an authorized
  `EDI_UNITY=0` build/install plus a manifest tying the installed DLL hash to
  checkout revision/dirty state, per-source hashes, effective compile/link
  commands, and compiler/toolchain versions. No build was run for this audit.
  **Latest installed/staged identity recheck, 2026-10-21:** read-only SHA-256
  checks now find installed and checkout `EDI.so` byte-identical at
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (both dated 09:43), differing from the prior installed-test identity
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`. This
  current identity does not authenticate the DLL used by those earlier tests
  or bind the binary to checkout/build inputs. No test, build, or install was
  performed for this check; current-source/build provenance and
  sanitizer/Valgrind gates remain open.
  **Current contract-test diff recheck, 2026-10-21 (pending at inventory):**
  the shared worktree now has a `+184/-8` diff in
  `R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R`, superseding
  the earlier note that the diff only qualified eight wrapper calls. The new
  block adds short/long and non-finite `warm_start_params` cases for seven
  mixed-model kernels, short/long start checks and finite-value diagnostics
  for zero-augmented Poisson, and non-finite Fisher-information cases for the
  seven mixed-model kernels plus zero-augmented Poisson. These are uncommitted
  test assertions and were not run or treated as validation in this audit.
  The affected C++ files remain clean at HEAD; checkout and installed DLLs
  currently match at SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`, which
  still does not identify their build inputs. The new assertions need focused
  execution against the matching native artifact; the approved `EDI_UNITY=0`
  build/install manifest and sanitizer/Valgrind CI remain release gates.
  **Installed current-identity contract rerun, 2026-10-21:** after that
  inventory, `Rscript -e 'library(EDI); testthat::test_file("R/EDI/tests/testthat/test-kernel-warm-start-length-contracts.R", package="EDI")'`
  passed all 243 expectations (0 failures, warnings, or skips) against installed
  EDI 1.0.3. The loaded DLL path was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`; a
  read-only SHA-256 check immediately after the run found installed and
  checkout `R/EDI/src/EDI.so` identical at
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`.
  This validates the current contract-test diff against the available installed
  artifact and supersedes the pending test status above. It does not attest
  that this DLL was built from current C++ sources or establish build flags;
  the `EDI_UNITY=0` source/build manifest and sanitizer/Valgrind CI gates
  remain open. No build/install or source overlay was used.
  - [ ] After an explicitly authorized `EDI_UNITY=0` build/install, run the
  R kernel-equivalence tests and sanitizer/Valgrind CI jobs; retain per-wrapper
  results and verify no malformed start reaches an unchecked dereference.
  The Python wrong-length-start suite has same-source coverage above; rerun it
  if any of the validated C++ sources, Python bindings, or Python tests change.

- [x] TODO-64 (added 2026-10-07, filed on the model's initiative under the
  standing "add found bugs to v1.0.5" instruction; delete if unwanted):
  **Dead randomization fast paths: a kernel that does not exist, two type
  mismatches, and a dispatcher that hides both** —
  `../bug_fix_plans/dead_randomization_fast_paths.md → TODO-1..5`.

  Found by calling each class's `compute_fast_randomization_distr()`
  directly on the dispatcher's own permutation object (installed 1.0.2).
  - `InferenceCountPoisson` (`inference_count_poisson.R:821`) calls
    `compute_poisson_distr_parallel_cpp`, which exists nowhere in the
    package (no `src/` definition, no `RcppExports.R` wrapper) and never
    has since the initial commit. The OLS wiring plan (TODO-3) cites this
    method as its template.
  - `InferenceAllSimpleWilcox` and `InferenceAllKKWilcoxIVWC` pass the
    cached double `w_mat` to `Eigen::Map<Eigen::MatrixXi>` kernels: `Wrong
    R type for mapped matrix`. Measured 891 ms through the fallback vs
    404 ms for the kernel on an integer matrix (n = r = 1000).
  - The dispatcher (`inference_all_abstract_rand.R:61–66`) wraps the fast
    path in `tryCatch(..., error = function(e) NULL)` and falls back to the
    per-permutation R loop silently; no test exercises any fast path
    against the real permutation object.
  Fix: coerce to integer at the two Wilcoxon sites (shared step with
  v1.1.0's `TODO-42`, implement once); for Poisson either delete the dead
  method (bit-preserving, recommended) or write the kernel (tolerance-
  equal, the **result-changing exception** in the standing constraint
  below); rethrow under `should_run_asserts()` and warn once otherwise;
  a wiring test (fast path vs worker loop to 1e-10 per class, plus a
  static `*_cpp`-exists check). Independent of every other item.
  **Source progress 2026-10-10:** the two Wilcoxon fast paths now present
  integer matrices to their `MatrixXi` kernels; the dangling Poisson fast
  path was deleted (retaining its pre-existing worker behavior); and the
  dispatcher rethrows in assertion mode while warning once plus retaining
  the error diagnostically in normal mode. A complete static audit now
  classifies all 18 remaining overrides: seven direct native wrappers
  (including the newly wired OLS kernel), ten reusable-worker delegates, and
  the custom R/callback path; every direct native wrapper exists. Simple- and
  KK-Wilcoxon regressions exercise double dispatcher matrices. The linked
  OLS-plan correction is complete. **Compile-free installed-package probe,
  2026-10-14:** `Rscript scripts/todo64_installed_override_parity.R` exercised
  the 12 override definitions not covered by the numerical agent's 165
  assertions (Bai's one override via both KK14 and KK21 classes). All 13
  class cases returned 4 draws each (5 for RandCustom) and matched the
  reused-worker route at `1e-10`; 12 had finite draws. KK OLS-IVWC returned
  four `NA`s on both paths, making that parity vacuous; a separate randomized-
  covariate n=40 probe also returned all `NA`s despite a finite public point
  estimate. The 10 delegate methods route through the reused-worker method,
  so these are execution checks rather than independent native-kernel
  comparisons. The exact reproduction is the script above. `Rscript` now
  loads installed EDI 1.0.3, so the prior MKL startup failure is no longer a
  blocker. **Checked-in wiring-test and fixture follow-up, 2026-10-16:**
  `R/package_tests/testthat_bulk/test-randomization-fast-path-wiring-reference.R`
  now exercises all 18 concrete fast-path class cases with each object's
  generated 50-permutation object and compares fast-path output against the
  reused-worker route at `1e-10`. Its deterministic n=20 KK14 OLS-IVWC fixture
  (design/response seed 1; permutation seed 1) produces 50/50 finite values
  and matches the worker output. The Simple-Wilcoxon n=r=1000 public p-value
  check is `0.002` by both routes (ratio 1.0; 1000/1000 finite draws). Focused
  run against installed EDI 1.0.3 passed 79 assertions, with no failures or
  warnings. The existing pre-push wiring audit now checks callable Rcpp
  wrappers referenced by instantiated fast-randomization methods; its focused
  installed-package run passed 10 assertions. `InferenceCountPoisson` has no
  class-defined fast-distribution override in installed EDI 1.0.3, consistent
  with deleting the dead method. These close the checked-in all-class test and
  non-vacuous fixture gaps, but do not validate the current checkout's native
  coercion/symbol mapping. **Additional source-only registration gate,
  2026-10-16:** the
  checked-in wiring test now also verifies that each direct fast-path wrapper's
  `.Call` symbol has a generated registration entry in checkout
  `src/RcppExports.cpp`; the focused installed-package run passed 152
  assertions. This strengthened static source coverage but did not by itself
  close the current-head native-validation gate. **Closure evidence,
  2026-10-16:** following the user's reported rebuild, both
  `test-randomization-fast-path-wiring-reference.R` (152 assertions) and
  `R/EDI/tests/testthat/test-inference-class-wiring-completeness.R`
  (10 assertions) passed against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Its embedded build
  timestamp is `2026-10-16 18:00:39 IDT`, after current checkout HEAD
  `6a9b91c4231853de1a14ab935beb2349ca9a189a` (`17:50:36 IDT`); the checkout
  had no source changes at test time. The package does not embed a Git SHA,
  so this relies on the user's rebuild report plus timestamp and clean source
  tree rather than an artifact SHA attestation. This validates current native
  coercion/symbol mapping and closes the original dispatch-wiring acceptance.
  **TODO-6 post-HEAD installed-native recheck, 2026-10-20:** the independent
  n=40 OLS-IVWC reference test passed 27 assertions (0 failures, warnings, or
  skips) against installed EDI 1.0.3. Its `edi_build_info_cpp()` timestamp is
  `2026-10-19 23:31:50 IDT` (`EDI.so` mtime `23:47:15 IDT`), later than the
  current HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9` at `21:03:16 IDT`;
  the relevant R/native/test files are clean at HEAD. This closes the
  non-fallback public-fit validation gate for the user's reported rebuild,
  retaining the no-embedded-Git-SHA provenance caveat. No compile/install or
  canonical result write was performed.
  - [x] **Nested OLS-IVWC numerical fixture gate** — although the existing
    50-draw fast/worker parity case is finite and non-vacuous for dispatch
    parity, its three matched pairs and three-column matched design use the
    `estimate_only=TRUE` `n <= p` fallback; it does not exercise the public
    OLS-IVWC matched fit or IVWC combination. The new n=40 one-covariate
    independent HC2-reference case in
    `test-kk-ols-ivwc-shared-satterthwaite-df-and-combination-branches-reference.R`
    passed 27 assertions against installed EDI 1.0.3 again on 2026-10-18.
    Its `EDI.so` mtime was `2026-10-18 03:57:33 +0300`, two minutes after
    checkout HEAD `efdc1b4ebe07c6dc3aadba713b5f5fe0722fdfe1`
    (`03:55:42 +0300`); relevant checkout source and registration files
    were unmodified. This closes the nested gate for the user's rebuilt
    package. The package does not embed a Git SHA, so this is timestamp plus
    user-reported rebuild evidence, not an artifact-SHA attestation. No
    canonical outputs are involved. See
    `../bug_fix_plans/dead_randomization_fast_paths.md → TODO-6`.
    **Fixture non-vacuity assertion, 2026-10-20:** the independent HC2
    reference test was strengthened to require different matched/reservoir
    estimates and an IVWC result distinct from both, with exact agreement to
    the weighted reference formula. It passed 31 assertions (0 failures,
    warnings, or skips) using `testthat::test_file(...)` against installed
    EDI 1.0.3. **Current-native recheck, 2026-10-20:** reran the same focused
    test; all 31 assertions passed with no failures, warnings, or skips. The
    loaded `EDI.so` (14,727,184 bytes; mtime `2026-10-20 09:38:02 +0300`)
    SHA-256 `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
    (MD5 `a75519a9256c0b3121398032314291d4`) is byte-identical to checkout
    `R/EDI/src/EDI.so` at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
    This closes the current-native artifact identity gate for the non-fallback
    OLS-IVWC fixture. The package embeds no Git SHA, but the installed and
    checkout DLL hashes match exactly. No compile/install or canonical result
    write occurred.

- [x] TODO-65 (added 2026-10-08, user decision): **KK21 ordinal weight
  kernels: unprotected `wrap()` temporaries in an R callback in
  `src/` can be garbage-collected mid-call** —
  `../bug_fix_plans/kk21_ordinal_weight_callback_unprotected_temporaries.md → TODO-1..4`.

  Found 2026-10-08 while measuring the `*_use_speedup` approximation's cost
  (installed 1.0.2): three of five 150-replication ordinal design runs with
  `ordinal_use_speedup = FALSE` aborted ("Not compatible with requested
  type: [type=NULL; target=double]" then a segfault inside
  `kk21_ordinal_weights_cpp`); same-seed reruns completed, so it is GC
  timing, not data. `multivariate_ordinal_tstat` (`kk21_weights.cpp`
  ~L1239) does `List res = f(wrap(X), wrap(y));` — the second `wrap()`
  can collect the first before Rcpp shields either. Proven with
  `gctorture(TRUE)`: the kernel returns `NaN NaN NaN` where it returns
  `2.357 0.857 0.181` normally, while the callee called directly from R is
  GC-safe; a standalone sourceCpp demo of the identical pattern fails and
  the protected variant does not. Affects both ordinal weight kernels
  (plain and stepwise), only with the non-default flag. Fix: hold the
  wrapped values in `NumericMatrix`/`NumericVector` before the call
  (bit-preserving; three lines), a `gctorture` regression test, and a
  static check that no other `src/` callback passes inline `wrap()`
  temporaries. Optional TODO-4 bypasses the R round-trip entirely.
  Independent of every other item.
  **Reconciled 2026-10-10:** linked TODO-1--3 are implemented at source: the
  callback roots both wrapped arguments, the static callback sweep is clean,
  and the bulk-CI test exercises both ordinal weight kernels under
  `gctorture(TRUE)`. Optional TODO-4 is a separate performance decision.
  The focused bulk test
  ran against installed EDI 1.0.3 on 2026-10-14: 5 passed, 1 skipped, 0
  failures/warnings (about 10 minutes); both torture-protected kernel calls
  passed. The skipped static check could not locate the source tree from
  `test_file()`'s bulk-test working directory, while the linked plan records
  the independent source-sweep result.
  **Native-validation gate closed 2026-10-15:** bulk correctness run
  `38808821543` passed on current HEAD
  `430c19bcdb0702d998c79f9058c449449034134c`. The build job installed that
  commit into an isolated library (`116676541980`); the focused regression
  was assigned to correctness shard 2 (`116681563194`), whose test step and
  final `bulk tests passed` job (`116695886005`) succeeded. Correctness mode
  runs the `gctorture(TRUE)` assertions; the separate coverage run
  `38808821546` skips that block under `R_COVR=true` and is not the evidence
  used here. TODO-65 is closed for the GC-safety bug; optional linked TODO-4
  remains open and is not part of this release closure.

- [ ] TODO-66 (added 2026-10-08; serial-dispatch fix and bounded runtime
  checks recorded 2026-10-18; release closure still gated):
  **`InferenceCountHurdleNegBin`'s non-reusable-worker multi-core Bayesian
  bootstrap (`num_cores = 2`, `debug = TRUE`) hangs intermittently.**

  **Residual release gate (2026-10-20 reconciliation):** the linked
  `bayesian_bootstrap_performance.md` still requires release-scale
  runtime-manifest or sanitizer validation. The focused/source-loaded checks
  and three bounded fresh-process runs below do not satisfy that gate. A
  read-only process recheck found no active R/Rscript process and none of the
  recorded 2026-10-16 parent/worker PIDs; this resolves no cause of the
  historical hang.

  Found 2026-10-08 while replacing `InferencePropZeroOneInflatedBetaRegr`
  as the fixture in `test-bayesian-bootstrap-non-reusable-worker-debug-
  path.R` (that class gained `supports_reusable_bootstrap_worker() = TRUE`
  in TODO-1/commit `bca39750`, so it no longer exercises the duplicate()-
  per-iteration branch that test is about; `InferenceCountHurdleNegBin` is
  now the only class with an explicit `FALSE` override).
  `approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 16L, debug =
  TRUE)` with `num_cores = 2` on that class sometimes completes in ~1-2s
  and sometimes never returns, confirmed directly (outside testthat, same
  call, same seed, no other state changed) — not a timeout-tier slowness
  issue, a genuine intermittent hang. Consistent with a fork-after-OpenMP-
  threading race: `par_lapply()`'s lazy-fork-cluster path
  (`inference_all_abstract.R`) forks real OS processes, and if the parent
  still has live OMP worker threads at fork time, the child can inherit a
  permanently-locked mutex. Single-core and multi-core-without-debug both
  work reliably (confirmed repeatedly); only the `debug = TRUE` +
  `num_cores = 2` combination hangs. Also noted in passing: single-core vs
  multi-core values for this class are not bit-identical even when they do
  complete (~1e-7 differences, consistent with OpenMP's non-associative
  floating-point summation at different thread counts) — benign, but
  worth confirming it's not symptomatic of the same underlying race.
  Deliberately NOT exercised in the replacement test (would be a flaky CI
  assertion); needs its own investigation under `gdb`/thread inspection
  while reproducing, matching the diagnostic approach already used
  successfully for the mirai/nanonext fork hang in
  `project_ci_openblas_fork_hang.md`.

  **Source implementation 2026-10-10:** the diagnostic-only `debug = TRUE`
  branch now forces the non-reusable-worker duplicate path to run serially,
  preventing a fork after an OpenMP-using fit; ordinary `debug = FALSE`
  bootstrap retains its existing policy and warmup-based eligibility for
  parallel dispatch. The focused bulk-CI regression now requests two cores
  for debug mode and asserts the same seed-pinned values as the single-core
  run; its correctness and coverage runtime-manifest rows are registered.
  This release item remains unchecked pending focused execution on a usable R
  runtime; no compilation, installation, or R execution was performed at
  source implementation time. **Installed-package recheck 2026-10-14:** the
  focused debug-path regression passed all 19 assertions with EDI 1.0.3.
  This confirms that run completes on the installed binary but does not
  resolve the historical intermittent-hang reproduction or certify the
  checkout's native artifacts. An additional compile-free stress check on
  2026-10-15 ran five fresh `InferenceCountHurdleNegBin` fixtures through
  `debug = TRUE`, `num_cores = 2`, and `B = 16` against installed EDI 1.0.3;
  all five returned 16 values with no replicate errors or warnings. This
  increases confidence in the serial debug fallback but does not reproduce
  or explain the historical intermittent fork hang, and does not validate
  the checkout's package artifacts. This release item remains open.

  **Focused-test hang evidence, 2026-10-16:** a run of
  `testthat::test_file("R/package_tests/testthat_bulk/test-bayesian-bootstrap-non-reusable-worker-debug-path.R")`
  remained blocked for over six hours. The R parent (PID 1814140) was waiting
  in `do_select`; its two forked R workers (PIDs 1814272 and 1814273) were
  sleeping in `futex_wait_queue`, all at 0% CPU. The test sequence performs an
  ordinary `debug = FALSE`, `num_cores = 2` real-fork call after an earlier
  OpenMP-using fit, before the later debug-path checks. This is strong evidence
  of a fork-after-OpenMP hang in that ordinary test path, not a failed
  assertion and not evidence that the serial `debug = TRUE` fallback itself
  forked. Per maintainer authorization, SIGTERM was sent to the exact parent
  and then to both exact children; subsequent `ps` checks found all three
  absent. No successful test result or natural exit is claimed. The long hang
  means the focused file is not currently a reliable end-to-end gate; replace
  its ordinary real-fork dispatch assertion with the existing serial dispatch
  spy or isolate that fork-sensitive path before relying on a rerun. TODO-66
  remains open pending a bounded, repeatable validation of the serial debug
  fallback and the checkout's native artifacts.

  **Standalone reproduction of the ordinary path, 2026-10-18:** outside
  testthat and with no earlier fit in the process, a fresh
  `InferenceCountHurdleNegBin` (n = 80, two covariates, simulated hurdle
  NB response) with `inf$num_cores = 4L` hung in
  `approximate_bayesian_bootstrap_distribution_beta_hat_T(B = 151,
  show_progress = FALSE)` (`debug = FALSE`) in 3 of 3 runs, inside and
  outside the Claude sandbox, against installed EDI 1.0.3. Same signature
  as 2026-10-16: the parent (5 threads) waits in `do_select`; all four
  forked workers sleep in `futex_wait_queue`. The parent was still
  single-threaded after `compute_estimate()` and
  `compute_asymp_confidence_interval()`, so the OpenMP pool is most likely
  created by the warmup refits inside this call, just before
  `par_lapply()` forks. The same call at `num_cores = 1` finishes in
  ~12.6 s. `comprehensive_tests.R` runs this class at nc = 4 without
  hanging; why is not yet known. No stack: `ptrace_scope = 1` blocks gdb
  and eu-stack on the workers.
  **Source/test update, 2026-10-18 (not runtime-validated):** the ordinary
  non-reusable path now clamps its effective worker count to one before the
  warmup block, avoiding both the warmup-then-fork sequence and any real fork
  for this worker strategy. The existing dispatch-spy regression now records
  the requested `n_cores` and expects exactly one while still comparing the
  serial distribution to its seeded reference. The serial fallback is
  intentionally scoped to non-reusable workers and leaves reusable-worker
  dispatch untouched. **Installed-package test history, 2026-10-18:** an
  initial 23-assertion pass against EDI 1.0.3 was later found
  non-discriminating: with B = 8 the old warmup timing heuristic itself
  reduced effective cores to one, so the requested-core/dispatch assertion
  did not exercise the new pre-warmup clamp. The test now captures calls to
  `check_bootstrap_replicate_deadline()` labeled `Bayesian bootstrap warmup`.
  With the effective-core policy fixed at two, the pre-fix installed EDI
  1.0.3 enters warmup exactly twice; the focused test has one intentional
  negative-control failure (two labels, expected zero) and 23 passes. The
  check is timing-independent, and the serial `par_lapply` spy means no real
  fork occurs. This does not validate current-checkout source or native
  artifacts; rerun after a user rebuild/install. **Debug-policy non-vacuity
  correction, 2026-10-18:** the debug subcase now also stubs
  `effective_parallel_cores()` to record the request and return two, so an
  unrelated global serial policy cannot make its no-dispatch assertion pass
  vacuously. The focused test passed all debug-subcase assertions against
  installed EDI 1.0.3; its only failure remained the intentional ordinary
  pre-fix negative control (warmup observed twice, expected zero), for 24
  passes / 1 failure overall. No real fork was launched. This still does not
  validate the dirty checkout's ordinary clamp or provide the required
  bounded fresh-process stress run.
  - [x] Implement the ordinary non-reusable path, not only the debug branch:
    the source-only fix clamps this worker strategy to one core before
    warmup, avoiding warmup-then-fork. Runtime validation remains pending.
    `bayesian_bootstrap_performance.md → TODO-10` changes the same branch.
  - [x] Replace the ordinary real-fork assertion with a serial dispatch spy
    and deterministic no-warmup assertion. This is a source/test change only;
    it has not been run against a rebuilt current checkout.
  - [x] Source-loaded focused dispatch test, 2026-10-18: ran
    `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
    `testthat::test_file("R/package_tests/testthat_bulk/test-bayesian-bootstrap-non-reusable-worker-debug-path.R")`;
    all 25 assertions passed. This validates current R source against the
    already-installed EDI 1.0.3 native library, not a rebuilt current native
    artifact.
  - [x] Provenance refresh, 2026-10-18: reran that exact source-loaded test;
    all 25 assertions passed (0 failures, warnings, or skips). The temporary
    `pkgload` DLL was `/tmp/RtmpWJVtq2/pkgload370b917cf99ee3/EDI.so` (MD5
    `dd43c5d0e11708aea17ba82b900f66d1`), matching the installed EDI 1.0.3 DLL
    at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`.
    Thus the test exercised current checkout R sources but only the installed
    native binary; current-checkout native validation remains gated on the
    user's rebuild/install.
  - [x] Bounded fresh-process debug-fallback stress, 2026-10-18: three
    separate `timeout 90s Rscript /tmp/edi-v105-todo66-debug-stress.R` runs
    against installed EDI 1.0.3 each exited normally and matched the seeded
    single-core reference for all 16 finite values, with zero replicate
    errors or warnings. No real fork was requested by the debug path. This
    validates the installed debug fallback only; no binary/source SHA is
    available and the historical ordinary-path hang is not reproduced by
    this stress fixture.
  - [x] Post-rebuild current-artifact validation, 2026-10-18: reran the
    source-loaded focused dispatch test after the installed EDI 1.0.3 shared
    library was rebuilt (all 25 assertions passed; no failures, warnings, or
    skips). `pkgload::load_all(..., compile = FALSE)` loaded
    `/tmp/RtmpHGuCBT/pkgload39405660145362/EDI.so`, MD5
    `c07ee5a3a9d9b1909684dee3bb345cfe`, matching the installed
    `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`;
    installed artifact timestamp was 2026-10-18 10:56:47 +0300. Then ran
    three separate fresh R processes through the real ordinary
    `InferenceCountHurdleNegBin` path with `num_cores = 4` and `B = 16`;
    each completed under the 60-second R time limit with 16 finite values.
    The focused test confirms the non-reusable branch clamps to one worker
    before warmup and does not fork. The serial clamp removes the affected
    path; it does not claim to identify the underlying historical fork/OpenMP
    runtime failure. Do not retry the old real-fork path in-process.
  **Matching-native focused recheck, 2026-10-20:** after the user installed
  this checkout with `EDI_UNITY=0` on 2026-10-19, the same 25-assertion
  regression passed against installed EDI 1.0.3. Its loaded `EDI.so` SHA-256
  was `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  This closes the native-artifact identity gap for the focused R contract
  only; release-scale runtime-manifest or sanitizer validation and diagnosis
  of the historical fork/OpenMP hang remain open.
  **Read-only sanitizer/runtime artifact audit, 2026-10-20:** the bounded
  `/tmp` filename search found the debug-stress script and a parser output,
  but no TODO-66 Valgrind/ASAN/UBSAN report or release-scale runtime manifest.
  The focused regression is under `R/package_tests/testthat_bulk/`; the
  `R-CMD-check-sanitizers` and `R-CMD-check-valgrind` jobs run package `R CMD
  check`, which does not include this non-CRAN bulk suite (`run_bulk_tests.R`
  documents that the separate bulk workflow is its only runner). Thus generic
  sanitizer-job success would not cover this TODO-66 contract. Safe next
  action: obtain an authorized, current-source instrumented run of this
  focused test or a provenance-stamped release-scale runtime manifest; do not
  retry the historical real-fork path.
  **Installed focused-test recheck, 2026-10-21:** the serial dispatch-spy
  test passed all 29 expectations against installed EDI 1.0.3 after the
  user's latest rebuild. Its loaded native library is byte-identical to
  checkout `R/EDI/src/EDI.so` (SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`). The
  test uses a synchronous dispatch stub and does not exercise real fork or
  explain the historical hang. It adds current native identity for this
  focused path only; source/build-flag authentication and approved
  release-scale or instrumented validation remain open.
  **Bulk-CI artifact correction, 2026-10-21:** successful
  `test-bulk-non-cran` run
  [#39135640739](https://github.com/kapelner/EDI/actions/runs/39135640739)
  completed build, all five correctness shards, and the final gate at commit
  `c55198fef97b7ed24f1ea41e6556c7b88715b3ca`. Its shard plan assigned this
  focused test to shard 2, and the timing artifact records it complete in
  1.617 seconds. This corrects the earlier bounded `/tmp`-search statement:
  a release-scale manifest exists for that commit. It does not validate the
  current dirty checkout, whose bootstrap R sources and focused test have
  subsequent uncommitted changes, nor authenticate the currently installed
  R definitions/build flags. It also does not diagnose the historical
  real-fork/OpenMP failure or provide sanitizer evidence. The outer TODO
  remains open pending current-tree validation and the residual runtime or
  instrumentation gate; the historical real-fork path must not be rerun.
  **Current dirty-source overlay validation, 2026-10-21:** the focused test
  was then run with `pkgload::load_all("R/EDI", compile = FALSE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-bayesian-bootstrap-non-reusable-worker-debug-path.R")`;
  all 29 expectations passed. The loaded temporary DLL was
  `/tmp/Rtmpifikdb/pkgload1be79250995391/EDI.so`, SHA-256
  `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`,
  matching checkout `R/EDI/src/EDI.so`. This exercises current checkout R
  sources against that existing native library, without compilation. The
  ordinary dispatch spy invokes `lapply` synchronously, so this is bounded
  dispatch/reference evidence only: it does not enter the historical real-
  fork/OpenMP path, authenticate native build flags, or provide sanitizer or
  release-scale validation. Keep the corresponding gates and outer TODO open.
  **Retained-trace/current-gate audit, 2026-10-21 (read-only):** a targeted
  `/tmp` search found no remaining TODO-66 stress script or raw hang trace.
  Historical plan records remain the Oct 16 `do_select` parent with two
  `futex_wait_queue` children and the Oct 18 ordinary-path hang in 3/3
  B=151 attempts; those are not live processes or natural exits. The present
  checkout clamps non-reusable work to one core before warmup, and its
  29-assertion focused test uses a synchronous spy, intentionally avoiding
  the unsafe fork. Bulk CI run #39135640739 completed all five correctness
  shards at older commit `c55198fef97b7ed24f1ea41e6556c7b88715b3ca`; its
  shard timing is not sanitizer or current-dirty-source validation. The safe
  next step is a current-tree bulk-CI/instrumented run of the deterministic
  serial-clamp contract when authorized, not a rerun of the historical real-
  fork case. Native build-flag authentication and release-scale/instrumented
  validation remain open.

- [ ] TODO-67 (added 2026-10-09, user decision; from the algorithm-catalog
  sweep, `../new_feature_plans/algorithm_choice_audit.md → TODO-B1`):
  **KK21 Weibull AFT fits converge to the wrong point** —
  `../bug_fix_plans/kk21_weibull_irls_wrong_fixed_point.md → TODO-1..5`.

  `weibull_reduced_fit_for_score_test()` (`kk21_stepwise_survival.cpp:21-86`)
  and `univariate_weibull_tstat()` (`kk21_weights.cpp:744-840`) share two
  copy-pasted update errors. The IRLS working response `log_y − σ·adj/w` has
  fixed point `Σx(z−1)(eᶻ−δ) = 0` instead of the score equation
  `Σx(eᶻ−δ) = 0`, and the σ-score's δ term has the wrong sign (off by
  `2Σδ/σ`). Verified 2026-10-09 by hand derivation and by a pure-R port
  against `survival::survreg` (n = 400, 24% censored): `survreg` gives
  β = (1.006, .465, −.296), σ = .692; the loop as written gives
  β₀ = −9.48 with σ stuck at its 10 clamp; the corrected formulas reproduce
  `survreg` to 4 digits. With no censoring the loop diverges until `XᵀWX` is
  singular. `test-kk21-weighted-crossprod.R:59` re-implements the same wrong
  updates, so it passes. Impact: KK21 survival covariate weights and stepwise
  ordering (design efficiency only; randomization validity is unaffected).
  Fix: one shared helper reusing `fast_weibull_regression.cpp`'s likelihood
  and Newton, a `survreg` oracle test, and a re-run of the KK21 survival weight
  comparison. **Default change**: KK21 survival weights move (to the correct
  values). Independent of every other item.

  **Source implementation 2026-10-11:** both KK21 callers now share the
  exact/right-censored `WeibullAFTLikelihood` with the public fast Weibull
  kernel and optimize `(beta, log_sigma)` through its damped-Newton/L-BFGS
  path. The univariate Wald statistic uses the full observed information;
  censored and uncensored `survreg` references cover both the univariate and
  stepwise reduced-fit paths, and the smart-start offset is Euler's gamma.
  **Installed-package recheck 2026-10-14:** the stepwise MLE oracle test
  failed against the reinstalled EDI 1.0.3 binary (expected score statistic
  6.45, got 6.1); the survival-weight fallback test passed 6 assertions.
  This package version does not include the unbuilt checkout change, so this
  is baseline evidence, not validation of the fix. **Post-fix CI validation
  2026-10-15:** successful `test-bulk-non-cran` run
  [#38808821543](https://github.com/kapelner/EDI/actions/runs/38808821543)
  ran at HEAD `430c19bcdb0702d998c79f9058c449449034134c`. The workflow
  installed that current commit into an isolated library, planned the
  correctness suite, and all five correctness shards passed. At that SHA,
  the Weibull MLE source fix and `test-kk21-stepwise-survival-weibull-mle-score-reference.R`
  were present, and `test_runtimes.csv` registered that test in the
  correctness tier. This closes the native oracle execution gate. No local
  compile/build/install was run. TODO-67 remains open only for TODO-5's
  KK21 survival-weight comparison and affected package_tests benchmark/CSV
  regeneration.
  **Available installed-artifact oracle recheck, 2026-10-20:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-kk21-stepwise-survival-weibull-mle-score-reference.R")`
  against installed EDI 1.0.3 reported one failure and one pass: the censored
  fixture returned 6.1 versus the independent `survival::survreg` reference
  6.45, while the uncensored fixture passed. The loaded library was
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; `EDI.so` SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  identical to ignored checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. The artifact mtime follows the
  tracked source mtimes, but no build manifest or embedded commit attests its
  source revision. Treat this as an installed-artifact result, not proof of a
  current-source regression or a passing current-source native gate. It does
  not resolve the required old/new survival-weight comparison, replacement
  fixture/metric approval, or benchmark/CSV reconciliation. No build,
  simulation, or canonical write occurred.
  **Reduced-fit tolerance boundary regression, 2026-10-21:** the owner
  selected `1e-6` (instead of `1e-8`) for
  `weibull_reduced_fit_for_score_test()`. A source-aligned pure-R Newton
  port found a deterministic censored fixture with `set.seed(4)`, `n=120`,
  alternating treatment, `x ~ N(0,1)`, `time ~ Weibull(shape=1.4,
  scale=exp(0.35*treatment+0.55*x))`, and `event ~ Bernoulli(0.8)`: at
  `1e-8` the fit exits nonconverged at gradient norm `3.0732792e-7` although
  parameters match `survreg` within `1.7e-9`; at `1e-6` it converges at the
  same point. The independent score is `5.0684842`; the strict-tolerance
  FWL fallback is `4.1726661`. This case extends the existing
  `survreg`-reference test. Its installed-package run had two failures and
  one pass (old censored case `6.1` vs `6.45`, uncensored pass, seed-4 case
  `4.17` vs `5.07`) against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; the loaded DLL
  SHA-256 was `ae4fddafdadfaad9209b6a7e5c7617963eb4150f2e7e95841aec81b232f68d94`
  (mtime `2026-10-21 00:56:31 +0300`), identical to ignored
  `R/EDI/src/EDI.so`. The changed C++ source mtime is
  `2026-10-21 05:59:03 +0300`, so these are pre-edit artifact results, not
  current-source failures. Native validation remains open: after explicit
  rebuild/install permission, rebuild with `EDI_UNITY=0`, capture package/DLL
  provenance, and rerun the focused test. TODO-67 remains open for both this
  native check and TODO-5's owner-approved matching-quality comparison and
  affected benchmark/CSV regeneration; no compilation or install was run.
  **Seed-4 fixture/oracle review, 2026-10-21:** the new boundary assertion is
  behavior-discriminating rather than a hard-coded answer. It regenerates
  `set.seed(4L)`, `n=120` data and computes the expected one-covariate score
  using an independently optimized `survival::survreg(dist="weibull")`
  reduced-model MLE followed by explicit score-test arithmetic; the native
  KK21 call supplies only the value under test. The recorded source-aligned
  port has gradient norm `3.0732792e-7` and parameters within `1.7e-9` of
  `survreg`; at `1e-8` it falls back to score `4.1726661`, whereas the
  independent score at the selected `1e-6` tolerance is `5.0684842`. Their
  `0.8958181` separation is about 89,600 times the test's `1e-5` equality
  tolerance, so the stale strict-tolerance fallback does fail this assertion.
  The assertion intentionally checks the public score outcome rather than
  pinning an internal gradient or tolerance constant, so a different valid
  convergence path can pass. It establishes regression sensitivity and
  independent-oracle structure only: the available installed-DLL failure was
  recorded before the C++ source edit, while the earlier passing CI predates
  this seed-4 addition. The checkout-R overlay run below used an existing
  DLL and does not attest that it contains the edited C++ tolerance.
  **Checkout-R overlay / existing-DLL oracle recheck, 2026-10-21:**
  after confirming no other R/Rscript process was live and 16 GiB remained on
  `/tmp`, ran the focused test with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-kk21-stepwise-survival-weibull-mle-score-reference.R", reporter = "summary")`.
  All three fixture expectations passed. The loaded namespace was
  `/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3; temporary DLL
  `/tmp/RtmpLa2Vjo/pkgload21ddb3f6f/EDI.so` had MD5
  `bfea6f47ab8b27618d5d8633e9021f91` and SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
  byte-identical to checkout and installed `EDI.so`. Compilation, install,
  and canonical result writes were not performed. The matching hash proves
  only which existing DLL was loaded; no build manifest attests that it was
  built from the edited `kk21_stepwise_survival.cpp`. Treat this as checkout-R
  regression evidence over an existing artifact, not validation of the
  changed `1e-6` native tolerance. That native gate remains open pending an
  authorized `EDI_UNITY=0` rebuild/install with source/build provenance and a
  rerun of the focused test. TODO-5's owner-approved matching-quality
  comparison and affected benchmark/CSV regeneration remain open.
  - [ ] Owner decision before TODO-5: recover the historical fixture/generator,
    seed, options, and metric, or explicitly approve the proposed replacement
    and choose its paired-case count/seed schedule;
    approve/replace mASMD as primary outcome and set its numeric acceptance
    rule; decide whether matched fraction/pair count is a required guard (and
    its denominator), and specify denominator/handling for failed or
    nonestimable paired cases.
    Then run the `survreg`-referenced old/new survival-weight comparison,
    retaining attempted case rows/statuses, and regenerate/re-audit every
    affected benchmark row with current-code package and native-library
    provenance. The proposal is not an approved estimand, and the installed
    EDI 1.0.3 binary and CI at 430c19bc do not validate current HEAD.
  **Bounded historical-artifact lookup, 2026-10-21:** no tracked output or
  generator for `project_kk21_speedup_vs_glm_weights_20261008` was found;
  exact-string Git-history hits are documentation edits only. The known
  TODO-67 `/tmp` files are the seed-4 reduced-fit tolerance fixture/search
  script and unrelated CI timing CSVs, not paired old/new survival-weight or
  matching-quality inputs. Thus the original seeds/options/metric are not
  recoverable from this bounded repo/history/scratch check; retrieving the
  external project inputs or approving the replacement fixture, metric, and
  acceptance rules remains a maintainer choice. No benchmark was run.
  **Local source-to-installed-DLL provenance recheck, 2026-10-21 (read-only):**
  checkout HEAD is `bf3addd46b63c405b961178be09ea4e03c7c6275`; the target
  `kk21_stepwise_survival.cpp` SHA-256 is
  `46bd15f980d16ce299e7f20374979b911aebef401cd19ece3fbc81df7bca1b67`.
  Installed EDI 1.0.3 metadata says `Built: R 4.7.0; x86_64-pc-linux-gnu;
  2026-10-21 13:27:18 UTC`; installed and checkout `EDI.so` are byte-identical
  at SHA-256 `13a6dd534bacf3d9fa8e63d255c407745c26917e4c0e043f8bc1476f7cdcd313`
  (both mtimes 2026-10-21 16:27 IDT). This is temporally consistent with a
  recent build from the current tree, but neither package metadata nor the
  inspected `/tmp/edi-todo67-run391356/` timing-only files record a source
  revision/build receipt linking that binary to HEAD or the target source
  hash. Therefore it does not attest the edited native tolerance. The next
  native gate still requires an authorized, provenance-recorded
  `EDI_UNITY=0` rebuild/install and focused-test rerun; the independent
  matching-quality owner choices and comparison remain separately open. No R,
  build/install, benchmark, or artifact write was performed for this audit.

- [ ] TODO-68 (added 2026-10-09, user decision; from the algorithm-catalog
  sweep, `../new_feature_plans/algorithm_choice_audit.md → TODO-B2`):
  **Randomization and bootstrap-randomization CIs are (1 − α/2) intervals** —
  `../bug_fix_plans/rand_ci_inverts_two_sided_pval_at_half_alpha.md → TODO-1..4`.

  Both CI searches invert the **two-sided** p-value
  (`2·min tail`, `inference_all_abstract_rand.R:641`) at threshold
  **α/2** (`inference_all_abstract_rand_ci.R:210,322,325,535-536`;
  `inference_all_abstract_rand_bootstrap_ci.R:164,314-321,368`). That gives a
  97.5% interval at α = 0.05, labeled 2.5%/97.5%. Verified 2026-10-09 from
  existing `comprehensive_tests` CSVs: for paired runs with
  0.03 < p ≤ 0.045, the "95%" rand CI excludes 0 in only 17% of 429 cases
  (a correct inversion would give about 100%). Coverage audits read this as conservative,
  which is why it went unflagged. Fix: threshold α everywhere, a CI/test
  duality regression, and regenerated `rand`/`rand_bootstrap` CI rows.
  **Default change**: every randomization CI narrows to its documented
  level. Touches the same driver as TODO-2 and TODO-33. Land it with or
  before them so their tolerances are set against the corrected level;
  otherwise it is independent.
  **Source implementation status:** linked-plan TODOs 1--3 now use `alpha`
  throughout both public inversion paths, their SMC/bound-expansion controls,
  and the affine shortcut; the broader inverter audit and fixed-permutation
  duality coverage are complete. **Installed-package recheck 2026-10-14:**
  the rand-CI bounds/search tests (36), bootstrap-CI floor warning (3),
  bootstrap closed-form/failure guards (9), and `test-ci-rand.R` (80) all
  passed against EDI 1.0.3 (128 assertions total). Only TODO-4's installed `rand`/
  `rand_bootstrap` CSV regeneration and coverage/documentation reconciliation
  remains, so this release checkbox stays unchecked.
  **Post-HEAD installed-package focused recheck, 2026-10-20:**
  `test-rand-ci-bisection-and-high-precision-refinement-reference.R` passed
  30 assertions and `test-rand-bootstrap-ci-closed-form-and-bisection-failed-guards-reference.R`
  passed 9 (39 total, 0 failures, warnings, or skips) against installed EDI
  1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The DLL
  SHA-256 is `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`;
  its embedded build time is `2026-10-19 23:31:50 IDT` (mtime
  `23:47:15 IDT`), after HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`
  (`21:03:16 IDT`). There is no embedded Git SHA, and the current checkout's
  `inference_all_abstract_rand_ci.R` is modified, so this is artifact-specific
  focused test evidence—not validation of that uncommitted diff or proof of
  exact source identity. Comprehensive-row regeneration/reconciliation
  remains open; no build/install or canonical output write was done.
  **Checkout-source rerun, 2026-10-20:** both focused tests were then rerun
  after `pkgload::load_all("R/EDI", compile = FALSE)`: the rand-CI bisection/
  high-precision suite passed 30 assertions and the bootstrap-CI
  closed-form/failure-guard suite passed 9 (39 total; 0 failures, warnings,
  or skips). The loaded package reported version 1.0.3 and used the existing
  installed native DLL, whose SHA-256 is
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  Because `inference_all_abstract_rand_ci.R` is uncommitted in the shared
  worktree, this is focused checkout-R/installed-native evidence, not proof
  of native parity or canonical-row correctness. No compilation, install,
  or canonical write occurred. **Current-checkout source/current-native
  recheck, 2026-10-20:** reran the same two focused tests after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. The
  bisection/high-precision suite passed 37 assertions and the bootstrap-CI
  closed-form/failure-guard suite passed 9 (46 total; no failures, warnings,
  or skips). Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`;
  the loaded DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`
  matched both the user-rebuilt installed DLL and checkout `R/EDI/src/EDI.so`
  byte-for-byte. This closes focused checkout-R/current-native provenance
  for these tests only. Comprehensive-row regeneration, exact-key
  reconciliation, and coverage/documentation updates remain open; no
  build/install or canonical output write occurred.
  **Eligibility-helper correction, 2026-10-20:** class proxies now preserve
  registered R6 ancestry, fixing a false static `rand_bootstrap` CI eligibility
  prediction for the count-KK hurdle class under KK21. The source-derived
  helper now agrees with the runner for the KK21/Bernoulli comparison. The
  focused `test-comprehensive-rand-ci-eligibility-reference.R` passed 42
  expectations with checkout R loaded via
  `pkgload::load_all("R/EDI", compile = FALSE)`. This validates eligibility
  classification only; full-grid row regeneration, exact-key/status
  reconciliation, and coverage/documentation updates remain open.
  **Retained-artifact scope/provenance audit, 2026-10-21:** the affected
  `function_run` allowlist is exactly
  `compute_rand_confidence_interval`,
  `compute_rand_bootstrap_confidence_interval`, and its
  `_studentized`, `_symmetric-percentile-t`, and `_smoothed` variants.
  The 2026-10-16 inventory records 44,905/4,877/2,038/19,349 targeted rows
  in the continuous/count/proportion/survival CSVs (71,169 total), all with
  `status=ok` and complete seven-field keys. Continuous has 83 duplicate
  keys (82 with conflicting historical result/status/coverage signatures)
  and 3 duplicate `run_row_id`s; the other three files have no duplicate
  seven-field keys. Current CSVs are gitignored; their mtimes are
  2026-10-09 01:11 (continuous), 2026-09-27 11:17 (count), 2026-10-09 01:11
  (proportion), and 2026-09-27 11:19 (survival), all before the latest
  focused current-native evidence. These timestamps do not attest package,
  source, or native identity, and the retained rows have no established
  post-fix provenance. Key-wise upsert is unsafe: after a provenance-stamped
  post-fix regeneration, replace each affected CI slice as a whole, preserve
  non-target rows, then verify exact keys, coverage, and fresh
  `run_row_id` uniqueness. No result payload was read or changed in this
  audit; TODO-68 remains open.
  **Run-readiness reconciliation, 2026-10-21:** the retained source-derived
  candidate roster `/tmp/edi_todo68_rand_ci_candidate_attempt_roster.csv`
  (SHA-256
  `749f554ba93659b5c7e4d9f70e953bdeaf243780b57eac4e32027dec9fae3f2f`;
  generated by `/tmp/edi_todo68_generate_candidate_manifest.R`, SHA-256
  `ff730b1d8e99bc12df90acaa7d64555092ed23481556771a4cd4debe46a96ec5`)
  has 635,680 unique candidate keys: 160,800 `compute_rand_confidence_interval`,
  123,600 plain `compute_rand_bootstrap_confidence_interval`, 116,080 each
  studentized and symmetric-percentile-t, and 119,120 smoothed. It spans
  10 datasets, 7 designs, 2 formulas, 2 beta values, reps 1:40, and four
  response types. Its generator derives current source guards and labels, but
  explicitly marks keys conditional on successful case setup; it is not an
  actual-attempt roster. Exact seven-field matching against the four retained
  raw CSVs finds 71,169 targeted rows but only 21,857 unique keys matched to
  the current candidate roster; 49,229 raw unique keys are outside that
  roster, while 613,823 candidate keys have no retained counterpart. This
  reflects different/mixed historical grids and does not establish missing
  or erroneous post-fix attempts. The 71,169 raw rows break down by method as
  26,480 rand CI, 11,293 plain bootstrap-rand CI, 11,112 studentized, 11,111
  symmetric-percentile-t, and 11,173 smoothed. Their four CSVs total
  1,460,583,836 bytes. Summed retained per-row durations are 505,497.808
  seconds (140.416 hours of cumulative row time), not a single-run wall time
  or a valid runtime forecast; no whole-slice run-level timing log was found,
  and no estimate is extrapolated from unrelated runs.
  Before any whole-slice regeneration, preserve a fresh isolated output and
  adjacent provenance sidecar binding output hashes to the exact invocation,
  candidate-manifest/generator hashes, full seven-field expected and actual
  attempt keys plus setup/skip/error/status outcomes, source/runner/eligibility
  helper hashes, checkout HEAD and dirty/untracked-source digest, R version
  and platform, installed EDI R namespace/version/path and native DLL path/hash,
  dependency versions, `RNGkind()` and seed before sampling, sampled input and
  assignment fingerprints, `Nrep` and all grid/filter arguments, thread and
  environment settings, start/end host load and CPU affinity, and terminal
  completion/timeout record. Do not merge into canonical CSVs until actual
  attempts reconcile to the approved scope with no unexplained duplicates,
  missing keys, or status discrepancies. This audit did not read result
  payloads or change outputs; TODO-68 remains open.
  **Retained isolated-slice artifact audit, 2026-10-21:** the existing
  scratch outputs `/tmp/edi-todo68-rand-reps1to40.WXrm3D/` and
  `/tmp/edi-todo68-brt-reps1to40.n9uAFr/` contain one complete 40-replicate
  `diamonds` / continuous / Bernoulli / `InferenceContinOLS` run per family
  at `beta_T=0.5`. Each output has 480 unique seven-field keys over reps 1:40,
  four model/design-formula labels, and three emitted operations; every row is
  `status=ok`. The `rand` file includes the CI operation plus both public
  p-value operations; the `rand_bootstrap` file includes its plain CI and two
  p-value operations, but no studentized, symmetric-percentile-t, or smoothed
  CI variant. Result/sidecar SHA-256 pairs are respectively
  `11658067064b9de3c36898195b2127cb5660d83cc0a271f91ddf2c4aed99d36f` /
  `5790b1a983ae34a11dad72e178f38568c15866c7946005ed77de7f1c811bd864` and
  `8885a6dca4f3382178f7f5d24b17f448b3d2e0c108fc89a2aa1175045451a6cd` /
  `7bcca9017991471d4a2fc82353e5f3a11b6b90ba381411310290863ca7d62a27`.
  The sidecars bind the fresh outputs to command arguments, checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, checkout-diff SHA-256
  `88775848fae74c2ced98070ab6663d9496444aa3440b9fdd38ecbf6b8e233360`,
  runner SHA-256 `660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`,
  EDI 1.0.3 checkout namespace, R-devel `r90668`, and existing DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This is provenance-stamped execution evidence for one scratch selector,
  not a candidate-vs-attempt anti-join or full-grid reconciliation; it does
  not cover other strata or the omitted bootstrap-CI variants and is not
  canonical data. TODO-68 remains open.
  **Scratch-slice availability recheck, 2026-10-21 (read-only):** both
  previously cited 40-replicate artifacts remain present and their result/
  sidecar hashes still match: `rand` CSV
  `11658067064b9de3c36898195b2127cb5660d83cc0a271f91ddf2c4aed99d36f`,
  sidecar `5790b1a983ae34a11dad72e178f38568c15866c7946005ed77de7f1c811bd864`;
  `rand_bootstrap` CSV
  `8885a6dca4f3382178f7f5d24b17f448b3d2e0c108fc89a2aa1175045451a6cd`,
  sidecar `7bcca9017991471d4a2fc82353e5f3a11b6b90ba381411310290863ca7d62a27`.
  This remains exactly one `InferenceContinOLS`/diamonds/continuous/
  Bernoulli/beta-0.5 selector per family; it omits studentized,
  symmetric-percentile-t, and smoothed bootstrap-CI variants and does not
  reconcile the 635,680-key candidate universe or canonical rows. The full-
  grid attempt/status reconciliation and resulting coverage/documentation
  updates remain open. No artifact was modified.
  **Focused checkout-R regression, 2026-10-21:** after confirming the R/Rscript
  process table was clear, ran only
  `test-rand-ci-bisection-and-high-precision-refinement-reference.R` after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. The test file
  completed with no failures. Loaded EDI 1.0.3 from checkout namespace
  `/home/kapelner/workspace/EDI/R/EDI`; temporary DLL
  `/tmp/RtmpcPZaxM/pkgload242616505/EDI.so`, MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This validates focused checkout R-layer behavior against the existing
  user-built native DLL only. It does not close comprehensive `rand` /
  `rand_bootstrap` row regeneration, exact-key reconciliation, or coverage /
  documentation updates. No build/install or canonical output write occurred.
  **Candidate-key shape audit, 2026-10-21 (read-only):** the retained
  `/tmp/edi_todo68_rand_ci_candidate_attempt_roster.csv` has two
  `model_formula` values and no `design_formula` field; its class keys are
  unannotated class names. In contrast, the retained 40-replicate OLS `rand`
  output encodes both formula dimensions in `inference_class` and contains
  four distinct pairs (`~1/~1`, `~1/~.`, `~./~1`, `~./~.`). Thus the earlier
  635,680-row roster and raw-output overlap counts are not yet an exact
  candidate-to-emitted-key reconciliation unless both formula dimensions
  and the runner's label encoding are explicitly normalized. Candidate rows
  also remain conditional on successful setup, not proof of attempts/status.
  Rebuild the source-derived manifest with the full formula-pair key (or
  prove a lossless mapping) before relying on its missing/overlap counts.
  This correction does not alter the retained CSVs or canonical data.
  - [ ] Regenerate the affected `rand` and `rand_bootstrap` comprehensive rows
    using the corrected inversion, reconcile every affected result key and
    coverage claim, and update documentation only from the reconciled output.

- [x] TODO-69 (added 2026-10-09, fixed 2026-10-09; user decision; from the algorithm-catalog
  sweep, `../new_feature_plans/algorithm_choice_audit.md → row L,
  TODO-6(c) / TODO-B3`): **Cox tie method depends on which fallback
  fires.** The C++ kernel, `coxph.fit(method = "breslow")` paths and the
  log-rank/Gehan null fits are all Breslow. Two R calls are unpinned and so
  use `coxph`'s default **Efron**: `inference_survival_coxph.R:641` (the
  fallback when the C++ fit fails or `use_rcpp = FALSE`) and
  `inference_survival_strat_cox.R:54`
  (`cox_partial_likelihood_fit_with_formula`). On tied data the estimate
  therefore changes method depending on convergence. Fix: pass
  `ties = "breslow"` on both, and pin it in
  `test-rcpp-fitting-equivalence.R:129,549` (which compares to default-Efron
  `coxph` and is only valid while its fixtures have no ties). Add a tied-data
  regression that forces each fallback. **Default change** only on tied
  data reaching those fallbacks. Independent of every other item.
  **Resolution:** both fallbacks and the two C++-equivalence references now
  explicitly select Breslow; tied-data regressions cover the formula fallback
  and `InferenceSurvivalCoxPHRegr(use_rcpp = FALSE)`. Source-only validation
  passed 106 expectations; no rebuild or install was run.

- [x] TODO-70 (added 2026-10-09, fixed 2026-10-09; user decision; algorithm-sweep
  verification F1 + F1c): **`DesignSeqOneByOneRandomBlockSize` redraws are wrong** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-1`.
  The generic redraw loop never advances `private$t`, so every redraw uses the last subject's stratum. The block queue env is shared through the shallow clone and never reset, so redraws mutate the original design. Redraws are block-balanced 51–76% of the time (100% required). The existing `random_block_size_redraw_w_cpp` is never called. **Default change:** rand/bootstrap p and CI for this design. **Resolution:** the class now overrides redraw with independent C++ queues derived from realized stratum keys and preserves live `w`, `t`, and queue state.

- [x] TODO-71 (added 2026-10-09, fixed 2026-10-09; user decision; algorithm-sweep
  verification F1b): **`sample(private$block_sizes, 1)` gotcha corrupts real assignments** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-2`.
  With a single block size, `sample(4L, 1)` draws from `1:4`; the first block was balanced only 70% of the time. Affects actual assignments, not just redraws. The default `c(4,6,8)` is unaffected. **Resolution:** assignment samples an index into `block_sizes`; the package-wide sweep found no second vulnerable length-one call. The focused, shipped-design, and seed suites pass 255 expectations without compilation.

- [x] TODO-72 (added 2026-10-09, user decision; closed after installed native validation 2026-10-14; algorithm-sweep
  verification F8): **Ridit misscores an interior level absent from the reference arm** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-3`.
  It scores ½(R_{k−1}+R_k) instead of the mass below the level, in both `fast_ridit_analysis.cpp` and `ridit_distr_parallel.cpp`. Breaks the Mann–Whitney equivalence: 0.172 vs 0.225. Default `reference = "control"` path; coordinator re-ran it.
  **Resolution:** both native scoring paths retain the cumulative reference
  mass and score absent interior levels by mass-below. The linked plan records
  direct, analysis, randomization, bootstrap, and randomization-bootstrap
  regressions against the pairwise Mann–Whitney definition. Those focused
  regressions passed against the installed EDI 1.0.3 binary (see linked plan),
  including the missing-interior-level case; no rebuild was needed.

- [x] TODO-73 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F9): **Newcombe p-value returns 1 for strong effects; small p inflated** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-4`.
  Failed `uniroot` bracketing returns 1 (90/100 vs 10/100: p = 1, `prop.test` 1.1e-29; coordinator re-ran). The default `uniroot` tolerance inflates small p up to ~160×. A reference test pins p = 1 and must change. Default path.
  **Resolution:** the R-side inversion uses log-alpha search, explicit finite
  endpoint cases, and a stable direct-upper-tail Wilson calculation. The
  focused source test passed all 18 assertions against installed EDI 1.0.3;
  no compile or install was needed. See the linked algorithm-sweep plan.

- [x] TODO-74 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F12, OneLik): **`InferenceContinKKRobustRegrOneLik` randomization null ≠ observed estimator** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-5`.
  The null uses Huber M. The observed statistic is MM or M depending on call order. The Bayesian bootstrap hard-codes M. **Default change:** randomization p/CI.
  **Source implementation 2026-10-10:** estimate-only Rcpp and MASS fits now
  retain the configured robust M/MM method and omit only standard-error work;
  weighted bootstrap refits use that same method unless the observed fit has
  already fallen back to M. Focused regressions pin MM estimate-only and
  weighted-refit parity. The focused weighted-fit (6 assertions) and
  randomization/refit (10 assertions) tests passed against installed EDI
  1.0.3; see the linked algorithm-sweep plan.

- [x] TODO-75 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F21): **Dependent-censoring bootstrap CI is biased toward non-rejection** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-6`.
  It swaps to Wald only when the bootstrap CI excludes 0 and Wald does not. The studentized CI goes NA whenever it excludes 0, so it can never reject. Endpoints beyond ±2 are declared unstable. The docs are inaccurate, and two tests assert the biased behavior. **Default change.**
  **Source implementation 2026-10-10:** every finite bootstrap endpoint is
  retained across percentile/basic/BCa paths; the public studentized wrapper
  delegates to basic for this model (which has no replicate-SE estimator) and
  preserves that finite result. Zero/sign/width checks can no longer substitute
  Wald or NA. Contracts, roxygen, and the
  focused references are synchronized. Installed EDI 1.0.3 validation passed
  the wrapper-wiring test (8 assertions), endpoint-validation guards (11), and
  studentized instability guard (2); no compile/install was needed. See the
  linked algorithm-sweep plan.

- [ ] TODO-76 (added 2026-10-09, user decision; algorithm-sweep
  verification F13): **Ordinal KK random-effects Bayesian bootstrap fits a fixed-effects model** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-7`.
  BB is centred near 0.39 vs the reported conditional 0.583. KKGLMM is documented only as a "fast approximation"; CLMM is undocumented. CLMM is masked today by TODO-31's σ collapse, so land with or after TODO-31.
  **Implementation resolved 2026-10-09:** the nonconstant-weight bootstrap
  path now shares a weighted ordinal random-intercept refit across KKGLMM and
  all CLMM links, with deterministic finite-likelihood rescue; constant
  weights retain the existing exact unweighted fast path. Focused source-loaded
  validation passed and no native rebuild is required. **Installed validation
  2026-10-14:** the weighted-logit regression passed 16 assertions and the
  link-helper/weighted-estimate regression passed 34 against EDI 1.0.3. The
  TODO-76 implementation/focused-test gate is complete; release acceptance
  remains open for comprehensive-CSV regeneration and reconciliation. The
  weighted-refit helper is R-only and does not call TODO-31's native CLMM
  fitter, but affected CLMM rows also contain the native conditional point
  estimate. Do not finalize those rows from historical CSVs or helper-focused
  tests before TODO-31's current-head native validation of the CLMM estimate
  path. See `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-7`
  for the source-path audit.

  **Checkout-R source-overlay verification 2026-10-20:** reran the two
  authoritative focused files separately with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE, export_all = FALSE)`
  followed by `testthat::test_file(..., reporter = "summary")`. The
  `test-ordinal-kk-clmm-weighted-logit-reference.R` file passed 16 assertions;
  `test-ordinal-kk-clmm-link-helpers-and-weighted-estimate-reference.R` passed
  34. The loaded namespace path was the checkout `R/EDI`; pkgload loaded a
  temporary copy of the existing native `EDI.so`. Its source
  `R/EDI/src/EDI.so` and installed
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` had the
  same SHA-256 (`5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`);
  installed package version was 1.0.3. No build, compile, or install occurred.
  This confirms the focused R-source paths against that reused native binary,
  not a new native build or current-head native CLMM estimate validation.
  Comprehensive CLMM-row reconciliation remains gated on TODO-31's
  current-head native point-estimate validation, as noted above.

  **Installed-package focused CLMM recheck, 2026-10-20:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-ordinal-kk-clmm-link-helpers-and-weighted-estimate-reference.R")`
  passed 34 assertions with 0 failures, warnings, or skips against installed
  EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. This exercises the
  weighted logit/probit CLMM estimate path against `ordinal::clmm`, link
  helpers, and the cloglog point-estimate sign on a small seeded fixture; it
  is not calibration or row-regeneration evidence. Loaded `EDI.so` SHA-256
  was `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`,
  byte-identical to ignored checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. No build manifest or embedded
  Git SHA ties the binary to those tracked sources, and this installed-package
  test does not attest exact installed R-source identity. It therefore does
  not close TODO-31's current-head native gate. No build/install or canonical
  output write occurred; comprehensive-row regeneration and reconciliation
  remain open.

  **Exploratory out-of-scope formula check (2026-10-16; does not expand
  acceptance):** an isolated installed-package pilot for the logit
  `InferenceOrdinalKKCLMM` case (`model_formula=~.`, `FixedBinaryMatch`,
  `diamonds`, `beta_T=0`, rep 1, one core, 300-second per-method cap) timed out
  on default, basic, and Wald BB confidence intervals at 315.690s, 315.238s,
  and 315.304s. The same historical rows were finite in about 1.6s
  (respectively `[-0.756, 0.577]`, `[-0.624, 0.709]`, and `[-0.714, 0.667]`),
  but predate the weighted random-intercept BB refit and are not an
  apples-to-apples parity comparison. The pilot set
  `COMPREHENSIVE_FORCE_SLOW_PATHS=1`, which bypasses only the harness's slow
  operation skip registry; the log records each CI call entering and then
  being killed by the 300-second watchdog. The copied-scratch harness also
  emitted a stale-row-pruner warning because its scratch root is not a Git
  checkout; this cleanup-only failure does not alter fit execution. No
  p-value method completed, and no numerical success is implied. Artifacts:
  gitignored `scratch/edi-todo76-pilot-oDZJ2b/`. This higher-cost `~.` scenario
  remains outside the TODO-76 acceptance criteria.

  **Additional bounded installed-package outputs audited 2026-10-16
  (diagnostic only):** scratch runs under `/tmp/edi-todo76-*` contain the
  in-scope `FixedBinaryMatch` / `diamonds` / `beta_T=0` / rep-1 case for
  `InferenceOrdinalKKGLMM` and all four KK-CLMM links. The GLMM run recorded
  six methods with values; BCA and studentized were omitted as too slow. For
  the ten-method CLMM runs, logit had 10 usable rows; probit and cloglog each
  had 8 usable plus 2 `numeric_instability`; Cauchit had 9 timeouts plus 1
  `numeric_instability`. A recorded `status=ok` is not proof of a usable
  numerical result; inspect `skip_reason` and errors. These singleton outputs
  lack commit and installed-library/DLL provenance and do not meet the
  comprehensive regeneration/reconciliation gate. After TODO-56 releases the
  shared result paths, rerun the affected classes and all ten BB methods in
  isolated `/tmp` scratch with package/library/DLL provenance, then reconcile every
  affected key against canonical results.
  **Compile-free test-inventory check, 2026-10-20:** the five focused
  weighted-ordinal tests cited by the implementation are present in both the
  correctness and coverage runtime manifests; `plan_shards.py --check-only`
  validated the full inventories (1,158 correctness and 1,410 coverage
  files). This confirms test discovery only, not execution or numerical
  acceptance.

  **Source-only attempt-scope audit, 2026-10-20:** the five affected classes
  are dispatched only for KK designs (`FixedBinaryMatch` is explicitly in
  that harness branch), and their source class components supply the
  `BayesianBootstrap` capability. The ten harness labels are the five CI
  calls (default/percentile, basic, Wald, BCA, studentized) and five p-value
  calls (default/percentile, symmetric, Wald, BCA, studentized). This proves
  source eligibility, not an actual attempt: the runner still gates the calls
  on live capability, inference/family filters, slow-path policy, and
  `NARROW_MODE` (which suppresses typed BCA/studentized calls). An all-ten
  attempt needs a matching class/family filter, the slow-path override, and
  narrow mode off; every expected key must then have a terminal result or an
  explicit skip/error reason.

  The runner outer loop has both
  `design_formula=~1` and `~.`, while each affected class is separately called
  with both `model_formula=~1` and `~.`. The existing 50-row scratch candidate
  manifest selects one class-formula stratum but omits the outer design-formula
  suffix; it is not an exact runner key manifest. The prior pilot paragraph
  explicitly excludes its `model_formula=~.` scenario, but does not say whether
  the outer `design_formula=~.` stratum is also excluded. The owner has since
  selected `(design_formula=~., model_formula=~1)` for this bounded 50-key
  target; see the read-only exact-key audit below. A no-fit source inventory
  at `/tmp/edi-todo76-source-potential-manifest.csv` lists all 200 possible
  class × method × formula-pair keys for the case; these are source-potential
  keys conditional on runtime gates, not results. Reconciliation must filter
  the selected pair and compare exact composite keys and terminal outcomes,
  including `skip_reason`, rather than relying on row counts. This audit
  performed no assignment/outcome generation, fit, or canonical write.

  **Candidate-key validator unit test, 2026-10-20:**
  `test-todo76-result-key-validation-reference.R` passed all 62 expectations
  in six test blocks (0 failures, warnings, or skips; exit 0). This standalone
  pure-R check exercises explicit formula-pair scope, full result-key identity
  (including `design_formula` and `beta_T`), delimiter-safe key encoding, and
  fail-closed behavior for missing/duplicate/extra/malformed rows. It validates
  the reconciliation helper, not candidate data, an owner-approved formula
  scope, a fit, or comprehensive result reconciliation. R was
  `R Under development (unstable) (2026-10-13 r90668)`; checkout HEAD was
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Helper SHA-256:
  `176afe5807a550769948a0c21dfd80085da2e859722bf384cd27357579d967b4`;
  test SHA-256:
  `314877af4cfe265fb165465617319e586bb9d18908420c8de0dc90033afcbab6`.
  `testthat::test_file()` attached installed EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, whose loaded DLL
  SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
  the validator assertions exercise only the sourced pure-R helper and do not
  call native code. No build/install, result generation, or canonical output
  write occurred.

  **Installed pure-R validator recheck, 2026-10-21:** after confirming the
  R/Rscript process table was idle, reran
  `timeout 60s Rscript -e 'testthat::test_file("R/package_tests/testthat_bulk/test-todo76-result-key-validation-reference.R", reporter="summary")'`.
  All 62 expectations passed in six blocks (0 failures, warnings, or skips;
  exit 0). This sources and tests the validator helper only; no fit, native
  call, candidate output, or canonical artifact is involved. It did not
  resolve the owner’s accepted `design_formula`/`model_formula` pair scope at
  that time; the owner has since selected a pair, as recorded below. The test
  also does not reconcile retained rows, status usability, or provenance
  against the 200-key source-potential inventory. Those output acceptance
  gates remain open.

  **Finite-beta validator branch recheck, 2026-10-21:** broadened the
  existing pure-R fixture with non-finite `beta_T` cases for both the expected
  manifest (`Inf`) and candidate (`-Inf`), asserting each existing specific
  rejection. Rerunning the focused `testthat::test_file()` exited 0 with 79
  expectations and no failures, warnings, or skips. This is deterministic
  exact-key-validator coverage only; it does not validate candidate rows,
  attempt eligibility, native behavior, or reconciliation, and leaves the
  selected-slice regeneration gate open. No build/install or result generation
  occurred.

  **Selected-pair retained-artifact reconciliation audit, 2026-10-21
  (read-only):** applying the owner-selected pair
  (`design_formula=~.`, `model_formula=~1`) to the bounded case
  (`FixedBinaryMatch` / ordinal / diamonds / beta 0 / rep 1) yields 50 expected
  keys (five classes × ten methods). The 200-key source-potential manifest
  (`/tmp/edi-todo76-source-potential-manifest.csv`, SHA-256
  `20e9ca64c7da1558402484fc6ac301bda98edccee8df299a8973688329d987b6`)
  contains all four formula pairs; the older 50-row candidate manifest
  (`/tmp/edi-todo76-source-candidate-manifest.csv`, SHA-256
  `ed349ad283a669a7934a23cfc1a20c6f8f6636f7da041341f4c36b0cf7533f86`)
  has no `design_formula` field and is therefore not an exact pair-specific
  manifest. Parsing the retained `/tmp/edi-todo76-*` result CSVs by their
  embedded formula labels finds 62 rows for the selected case but only 46
  distinct full keys: all ten method keys appear for each of the four CLMM
  links, while the GLMM has only six (the four BCA/studentized CI/p-value keys
  are absent). The GLMM’s retained abalone rows and the `model_formula=~.`
  CLMM rows are outside this selected case/pair. The 16 duplicate keys are
  repeated logit-CLMM attempts; their numeric outcomes agree, but the files
  differ in empty versus missing `skip_reason`, so they cannot be collapsed
  by row count alone. Among the 62 selected-case rows, 14 carry errors (5
  `numeric_instability`, 9 `timeout`); all report `status=ok`, underscoring
  that status alone is not a usable-result criterion. Every selected row has
  `github_commit_id=NA`; the retained directories have no companion package,
  source, or DLL provenance manifest. The validator can check the explicit
  pair and exact keys and reject duplicates, but does not establish status
  usability or artifact provenance; its 62 unit expectations use synthetic
  inputs, not these rows. Safe next step: prepare a 50-key manifest with both
  formula columns explicit, then regenerate the complete selected slice in a
  fresh `/tmp` tree with package/source/DLL provenance and reconcile each key
  and terminal outcome before any canonical comparison. No run, baseline, or
  canonical result was changed in this audit.
  **Current artifact-presence recheck, 2026-10-21:** the previously audited
  `/tmp/edi-todo76-*` result CSVs are no longer present. The only weighted
  ordinal result CSV found is the retained exploratory `~.`/`~.` pilot under
  `scratch/edi-todo76-pilot-oDZJ2b/`; it contains three confidence-interval
  attempts (default, basic, Wald), each `skip_reason=timeout` with `result=NA`
  and `status=ok`, and no p-value rows. Its recorded commit ID is
  `430c19bcdb0702d998c79f9058c449449034134c`, but it has no package/DLL
  provenance sidecar and is outside the owner-selected
  `design_formula=~.` / `model_formula=~1` acceptance stratum. Thus none of
  the selected 50 exact keys has a currently retained result row or matching
  provenance sidecar; the prior 62-row reconciliation is historical evidence
  only. No canonical result was changed.
  **Retained-manifest inventory, 2026-10-21 (read-only):** the 200-key
  source-potential manifest remains at
  `/tmp/edi-todo76-source-potential-manifest.csv` (SHA-256
  `20e9ca64c7da1558402484fc6ac301bda98edccee8df299a8973688329d987b6`); the
  selected formula pair is 50 keys. The older 50-row candidate manifest
  (`/tmp/edi-todo76-source-candidate-manifest.csv`, SHA-256
  `ed349ad283a669a7934a23cfc1a20c6f8f6636f7da041341f4c36b0cf7533f86`)
  omits `design_formula` and is not pair-exact. The only retained result is
  the three-row `~.`/`~.` timeout pilot (CSV SHA-256
  `ae5b59d562287b2f0fc819a72399028ff849bbf8b4d8f459a248308d8dbe92e4`), so
  0/50 selected keys are present. The focused validator test is synthetic
  only; fresh current-source candidate/result reconciliation remains open.
  **Explicit selected-pair manifest recheck, 2026-10-21 (read-only):** the
  pair-specific manifest is now retained at
  `/tmp/edi-todo76-pair-explicit.lb97t9/selected_pair_50_key_manifest.csv`
  (SHA-256
  `1c18f55291f20c09f5fbec07838c0b43a3350a5f898e2c864e977b4b7706803a`),
  with provenance note SHA-256
  `992c0b1e60e160411e9c97749e4e1c53480f0eb99931fafcb9b8041fd25b9260`.
  It selects `design_formula=~.` and `model_formula=~1` from the 200-key
  source-potential manifest (SHA-256
  `20e9ca64c7da1558402484fc6ac301bda98edccee8df299a8973688329d987b6`):
  50 keys (5 classes × 10 method labels), with the other 150 keys belonging
  to the three other formula pairs. The recorded exact-pair validator result
  is `ok`. This resolves the manifest's missing-formula-column ambiguity and
  proves only the selected source-potential key set; it does not show that
  runtime gates attempted those calls or that any result is usable. The only
  retained pilot remains the three-row `~.`/`~.` timeout artifact above
  (SHA-256
  `ae5b59d562287b2f0fc819a72399028ff849bbf8b4d8f459a248308d8dbe92e4`),
  outside the selected pair, so the retained results still cover 0/50
  selected keys. Next gate: run the selected slice in a fresh isolated
  directory with source/package/native-DLL provenance, then validate exact
  keys, duplicates, status, `skip_reason`, errors, and usable values for every
  attempted key. Keep comprehensive reconciliation open until TODO-31's
  current-head native CLMM point-estimate gate is satisfied; no result or
  canonical artifact was changed in this manifest audit.

  - [ ] For the predeclared affected grid (KKGLMM and all four KKCLMM links),
    rerun all ten Bayesian-bootstrap procedures with commit, package, and DLL
    provenance; classify every skipped/error row by `skip_reason`, and
    reconcile exact keys against canonical results before updating the audit.

- [ ] TODO-77 (added 2026-10-09, user decision; algorithm-sweep
  verification F14): **KK clogit+GLMM Bayesian bootstrap fits glmmTMB/Laplace on all rows** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-8`.
  The point estimate is clogit + 20-node GH; replicates are shifted ~0.35 log-OR. The IVWC sibling shares the distribution. The similarly named proportion-only GLMM test does not cover this joint estimator.
  **Source implementation completed 2026-10-10:** bootstrap draws now use the
  weighted 20-node joint conditional-logit/random-intercept kernel (mean
  matched-pair weights for the conditional term and row weights for the GLMM),
  never the `glmmTMB` Laplace surrogate.  The native wrapper, registration, and
  focused joint-dispatch regression are updated. **Installed validation
  2026-10-14:** the joint-kernel/GLMER test passed 34 assertions, weighted
  class data assembly passed 25, and constant-weight/extreme-coefficient guards
  passed 4 each against EDI 1.0.3. The installed native wrapper exercised the
  weighted kernel arguments. Codex did not rebuild/install; comprehensive
  result regeneration and reconciliation remain open.
  **Post-HEAD installed-native recheck, 2026-10-20:**
  `test-incidence-kk-cond-logit-glmm-class-data-assembly-matches-joint-kernel-reference.R`
  passed 31 assertions with 0 failures, warnings, or skips against installed
  EDI 1.0.3. This exercises weighted bootstrap estimate calls for both OneLik
  and IVWC against the joint kernel. The installed DLL SHA-256 is
  `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`; its
  embedded build time (`2026-10-19 23:31:50 IDT`) and mtime (`23:47:15 IDT`)
  are after checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`
  (`21:03:16 IDT`), and the relevant class/native/test files are clean at
  HEAD. This relies on the user's reported reinstall because the package
  embeds no Git SHA. Comprehensive result regeneration and exact
  key/status reconciliation remain open; no build/install, snapshot, or
  canonical output write was done here.
  **Expected-key inventory, 2026-10-20 (no simulation):** the documented
  2-class × 2-model-formula × 2-design-formula × 10-method grid expands to 80
  unique exact keys, including runner-generated `case_id`s. The inventory is
  preserved under `/tmp/edi-todo77-expected-keys.iZAd6E/`; SHA-256
  `2c4228350bd76332ccc609fe30567cd6b1e60f48ee1ed255f74343c51c17563c`.
  Its expected key set exactly matches the existing 80-row diagnostic CSV
  (CSV SHA-256 `91a0b9780e6654df6148b132c9e828199099f84a8fa47e1f6c3bd617a7837759`),
  but those rows still lack commit and package/DLL provenance. The runner has
  a dirty beta-filter diff; its case-ID helper block is unchanged, and the
  scratch manifest records the runner SHA and dirty status. This is a future
  reconciliation aid, not result/acceptance evidence. No simulation or
  canonical result write was performed.
  **Expanded current-worktree focused rerun, 2026-10-20:** the same
  class-data-assembly test passed all seven blocks, 64 expectations total
  (0 failures, warnings, or skips), after loading checkout R with
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. Runtime was
  R Under development (2026-10-13 r90668), package version 1.0.3, namespace
  source `/home/kapelner/workspace/EDI/R/EDI`; loaded existing DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Checkout HEAD was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`; the run's test
  file SHA-256 was
  `d86c09a717c2f2bfbb2641ea0f9dc9f7135c62391e7780800e979d542526a1c3`.
  This is focused checkout-R/test-worktree evidence only; compile=FALSE
  reused the existing DLL and does not establish its build-to-source linkage.
  The full affected-row regeneration and exact key/status reconciliation
  remain open. No build/install or canonical output write occurred.
  **Read-only artifact/provenance recheck, 2026-10-21:** no newer provenance-
  pinned result artifact was identified. The retained source-derived
  80-key inventory and matching 80-row diagnostic CSV remain a candidate-key
  aid only; the CSV lacks commit/package/DLL provenance and cannot establish
  post-fix execution. The next in-scope step remains gated on TODO-56
  terminality and a provenance-recorded post-fix package: regenerate both
  affected classes across both design formulas, both model formulas, and all
  ten Bayesian-bootstrap procedures, then reconcile every exact key and
  terminal status/reason against canonical outputs. No result generation or
  canonical write occurred in this audit.
  **Read-only terminal-contract check, 2026-10-21:** the retained diagnostic
  candidate at
  `/tmp/edi-todo77-reconcile.yQTUzj/R/package_tests/comprehensive_tests_results_nc_1_incidence_filtered_design-KK21stepwise_class-InferenceIncidKKCondLogitGLMM_OneLik_IVWC_dataset-pima_beta-0_rep-1_family-bayesian_bootstrap.csv`
  has 80 rows and 80 unique full keys matching the expected inventory; all
  rows are `method_family=bayesian_bootstrap` and `status=ok`. Its recorded
  skip reasons are blank=38, `nonestimable`=32, and `numeric_instability`=10;
  the new terminal-field validator accepts these rows without discarding the
  explicit reasons. However, all 80 `github_commit_id` values are missing and
  the candidate directory contains no provenance sidecar. Its SHA-256 is
  `91a0b9780e6654df6148b132c9e828199099f84a8fa47e1f6c3bd617a7837759`
  (mtime 2026-10-16 04:54:07 +0300); this remains unauthenticated diagnostic
  evidence and cannot close the post-fix package/DLL provenance or terminal
  regeneration gate. No result or canonical output was changed.
  **Public-driver regression, 2026-10-21:** the existing class-data reference
  test compares a seeded `B=2` OneLik Bayesian-bootstrap distribution with
  direct weighted `fast_clogit_plus_glmm_cpp` evaluations from the same draws.
  The fixture now guards nonempty discordant/GLMM blocks and nonconstant draw
  weights, and exercises both `debug=TRUE` and the ordinary `debug=FALSE`
  distribution route on a fresh object (so the debug cache cannot short-circuit
  that route). The focused file passed 75 expectations (0 failures, warnings,
  or skips) with installed EDI 1.0.3. The direct weighted-kernel calculation
  independently exercises the public driver's draw/weight wiring; separate
  joint-kernel tests compare unweighted regimes against `glmer` and
  conditional-logit references. This installed-package test does not attest
  current checkout R/native provenance or replace the all-method
  comprehensive regeneration and exact key/status reconciliation gate below.
  No build, install, or result artifact was produced.
  **Candidate-only source-potential roster, 2026-10-21:** the existing pure-R
  candidate-key helper was exercised for the explicit TODO-77 incidence case:
  2 classes × 2 model formulas × 2 design formulas × 10 source-audited
  Bayesian-bootstrap labels = 80 unique full keys. The test verifies the key
  schema and formula-pair coverage while deliberately omitting status, expected
  status, and skip-reason fields. These are source-potential candidates only;
  runtime setup/support and slow-skip rules still determine actual attempts.
  The focused validator test passed 71 expectations (0 failures, warnings, or
  skips) with installed EDI 1.0.3. It did not fit models, generate result rows,
  or establish current-checkout native provenance; comprehensive regeneration
  and exact key/status reconciliation remain open. No canonical artifact was
  changed.
  **Current artifact-presence recheck, 2026-10-21:** the cited diagnostic CSV
  under `/tmp/edi-todo77-reconcile.yQTUzj/` is no longer present, and no
  TODO-77 result CSV or provenance sidecar was found in the inspected `/tmp`,
  `R/package_tests`, or `scratch` locations. The 80/80 key comparison and
  status counts above remain historical audit evidence, not a currently
  retained result cohort. The expected-key manifest remains at
  `/tmp/edi-todo77-expected-keys.iZAd6E/expected_keys.csv` with SHA-256
  `2c4228350bd76332ccc609fe30567cd6b1e60f48ee1ed255f74343c51c17563c`;
  current-provenance result rows and their matching sidecar are still absent.
  **Inventory detail, 2026-10-21:** the previously cited diagnostic CSV and
  its containing directory/sidecar are absent from the inspected `/tmp` and
  repository locations. The historical 80/80 match had all `github_commit_id`
  values `NA` and no sidecar, so it is inadmissible as post-fix evidence. The
  expected-key manifest remains present (23,677 bytes, SHA-256
  `2c4228350bd76332ccc609fe30567cd6b1e60f48ee1ed255f74343c51c17563c`), and
  its adjacent inventory note records only a source-derived key comparison,
  not run provenance. The manifest records an older runner fingerprint; current
  `R/package_tests/comprehensive_tests.R` is modified (SHA-256
  `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`, versus
  the manifest's runner SHA `0f4612616ec1362c6e8b100a1c2fec32c417f86b8c4bf8ce8c317f5eaa13b92a`).
  The current installed DLL SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`
  matches checkout `R/EDI/src/EDI.so`, but no run record ties it to the
  historical rows. Keep
  TODO-77 open for a fresh provenance-stamped run and exact 80-key/status/
  reason reconciliation; no run or canonical result write occurred.
  **Shared terminal-validator edge, 2026-10-21:** the comprehensive-result
  validator now recognizes the runner's anchored timeout terminal message
  rather than rejecting any successful row whose diagnostic merely contains
  the word `timeout`. This aligns artifact acceptance with the cache
  classifier's documented exact-marker rule; the existing synthetic
  output-directory/terminal-fields test now covers a non-timeout diagnostic
  containing that word while retaining the explicit `status=ok` timeout
  rejection. The focused test passed with no failures, warnings, or skips;
  it creates only temporary fixtures and no fit or result artifact. The test
  is already registered in correctness and coverage tiers. This shared
  validator contract does not close TODO-77's missing provenance-stamped
  result rows or its full exact-key/status reconciliation gate.
  - [ ] After TODO-56 is terminal and a post-fix package with recorded
    source/DLL provenance is available, regenerate both affected classes
    across all ten Bayesian-bootstrap p-value and confidence-interval
    procedures; reconcile every affected result key/status against canonical
    outputs before accepting the fix.

- [x] TODO-78 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F2): **`.cox_simulate_stratified` hazard mis-scaling** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-9`.
  The baseline is scaled by the stratum max risk but subjects by the global max. 61% of simulated times are tied at `max_time`; refit β 0.635 vs 1. Stratified-Cox parametric-bootstrap LR p/CI (non-default).
  **Source implementation 2026-10-10:** subject risks now use each stratum's
  maximum linear predictor, matching the corresponding Breslow baseline; a
  distinct-maxima oracle regression checks both stratum slices. The focused
  simulation suite passed all 35 assertions against installed EDI 1.0.3; no
  compile/install was needed. See the linked algorithm-sweep plan.

- [x] TODO-79 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F17): **ZOIB R side applies plogis-normalize to softmax coefficients** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-10`.
  Affects the marginal estimand and its SE, the reused-worker bootstrap, and the null simulator. `marginal_mean_diff` −0.0876 vs a consistent −0.0816 (non-default estimand); mild default parametric-bootstrap distortion. No test covers it.
  **Source implementation 2026-10-10:** the likelihood's stable
  reference-category softmax is now shared by the marginal-mean functional,
  weighted-bootstrap combination, and null simulator; the marginal reference
  test was corrected to an independent softmax derivation. The weighted path
  still uses its separate weighted submodel fits, rather than a joint-MLE
  refit. The marginal/delta-method, softmax likelihood, marginal-estimand and
  weighted-bootstrap, and randomization-estimate tests passed 73 assertions
  against installed EDI 1.0.3; no compile/install was needed. See the linked
  algorithm-sweep plan.

- [x] TODO-80 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F10): **Zhang exact CI bracket never validated** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-11`.
  Bounds are silently truncated (CI too narrow), and zero-cell tables report finite bounds where the truth is ±∞. The bisection stops at |p − α| < 0.005. The same bisection is in `inference_ext_quantile_rand_ci.R`.
  **Source implementation completed 2026-10-10:** the shared bisection expands
  an invalid finite bracket geometrically, returns signed infinity when the
  tail cannot reject by the finite log-odds cap, and resolves endpoints by
  parameter-scale bracket width no looser than `1e-6`, including locally flat
  p-value curves. Direct exact and
  randomization CI defaults are aligned; focused narrow-bracket, flat-crossing,
  and unbounded-tail regressions are added. The exact CI/search suite (49
  assertions), parallel-bounds suite (5), and nonfinite-point guard (5) passed
  against installed EDI 1.0.3; no compile/install was needed. See the linked
  algorithm-sweep plan.

- [x] TODO-81 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F23): **`DesignFixedOptimal` BRT replays a weaker solver than the observed allocation's** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-12`.
  Replicates use 1 × 2000 annealing moves (stops hot) vs MILP or 4 × 20000. Replicate objectives are 6–45× worse. **Conservative:** size ≈ 0.02–0.03 at nominal 0.05 at high R². Undocumented.
  **Source implementation completed 2026-10-10:** BRT replays now inherit the
  observed assignment's solver/profile by default; the cheap annealing profile
  is available only via an explicit `brt_solver` override, while an explicit
  `brt_solver = "ompr"` forces MILP instead of silently crossing the auto
  solver's large-design annealing threshold. The wiring test now pins default
  profile parity and both opt-in overrides. **Installed validation
  2026-10-14:** against EDI 1.0.3, the standalone `NOT_CRAN=true` BRT suite
  passed 22 assertions in approximately 13 minutes; the solver-argument guard
  passed 2 assertions. Exact BRT command:
  `Rscript -e 'Sys.setenv(NOT_CRAN="true"); library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-design-fixed-optimal-brt.R")'`.
  The prior process-level `EDI.rdb` corruption/libdeflate errors did not recur.
  No compile/install was run.

- [x] TODO-82 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F22): **`InferenceSurvivalKKRankRegrIVWC` always returns NA** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-13`.
  `aftsrr(se = "ISMB", B = 0)` computes no SE, so every ladder rung is rejected, and the estimate-only path needs a variance it never has. Coordinator re-ran it. The migration golden passes only because both sides are NA. Legacy IVWC.
  **Validation:** the AFT candidate/cache suite (12 assertions), weighted
  passthrough suite (10), and migration golden (36) passed against installed
  EDI 1.0.3; the golden helper was explicitly exposed for `test_file()`. See
  the linked algorithm-sweep plan.
  **Source implementation completed 2026-10-10:** component fits now request
  ISMB with 100 replicates when no usable variance is cached and use the
  unrounded `covmat$ISMB` treatment entry. Estimate-only calls retain cached
  component variances for IVWC rather than replacing them with `NA`; a later
  full call can still calculate the combined SE. A focused covariance-extractor
  regression was added.

- [x] TODO-83 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F15): **`InferenceAllKKMeanDiffIVWC` randomization null is the plain mean difference** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-14`.
  `m_mat` is replaced by zeros, so the kernel sees no pairs. Shipped p 0.19 vs 0.005 with the correct compound null; coordinator re-ran it. A reference test pins the zeros branch. Legacy IVWC.
  **Source implementation completed 2026-10-10:** an omitted permutation
  `m_mat` now expands the design's fixed matched-set ids for each draw rather
  than using zeros, preserving the compound IVWC null.  The focused reference
  test now asserts agreement with the observed compound estimator. The focused
  fast-randomization test passed 6 assertions and shared compound
  matched/reservoir dispatch passed 17 against installed EDI 1.0.3; no
  compile/install was needed. See the linked algorithm-sweep plan.

- [x] TODO-84 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F7): **`InferenceAllKKWilcoxIVWC` HL variance is 2.09× too small** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-15`.
  Coverage is 80.7% at nominal 95% (class run). The bootstrap CI aliases the asymptotic one. Legacy IVWC.
  **Source implementation completed 2026-10-10:** matched-pair and reservoir
  HL variances now use their normal-model calibration in both the R fit path
  and native fast-bootstrap path, removing the balanced-design `2*pi/3`
  under-scaling. The bootstrap-CI alias was removed, while the normal
  package-level restriction correctly rejects nonparametric bootstrap CIs for
  sequential KK designs. Focused source regressions cover the two variance
  formulas and that unsupported CI path. The R-side focused variance/CI test
  passed all 3 assertions against installed EDI 1.0.3. The installed native
  fast-bootstrap entry point was called directly on a deterministic mixed
  matched-pair/reservoir fixture and returned 2.625, matching the independently
  calculated calibrated-variance estimate to 1e-12; the bootstrap reference
  contract suite passed 14 assertions. The original class-level 300-replicate
  coverage fixture also passed against installed EDI 1.0.3: 281/300 = 93.7%
  coverage at nominal 95%, empirical SD(est)=0.2296, in 47.7 seconds. Exact
  command: `Rscript -e 'source("/tmp/edi_f7_class_cov_installed.R")'`; the
  temporary runner uses installed EDI and does not load or compile the
  checkout. No compile/install was run. See the linked plan for native direct
  fixture details.

- [x] TODO-85 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F11): **KK hurdle-Poisson IVWC placeholder SEs of 1.0** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-16`.
  Estimate-only paths make it an equal-weight average. Bayesian-bootstrap CI is miscalibrated; `compute_estimate(estimate_only = TRUE)` caches the wrong estimate; randomization stays valid but loses power. The existing test mocks the variances. Legacy IVWC.
  **Source implementation completed 2026-10-12:** ordinary, weighted
  bootstrap, and randomization estimate-only paths now obtain real matched
  and reservoir component variances before IVWC combination. The placeholder
  `1.0` helper branches are removed, so an unavailable variance rejects only
  that component instead of silently equal-weighting it; the direct Rcpp
  helper no longer accepts the former `se = FALSE` switch that returned a
  placeholder. Focused mock
  regressions assert the preserved IVWC weighting. The shared matched/reservoir
  test (9 assertions), weighted/randomization branches (17), and Rcpp fit
  guards (21) passed against installed EDI 1.0.3; no compile/install was
  needed. See the linked algorithm-sweep plan.

- [x] TODO-86 (added 2026-10-09, user decision; closed after installed validation 2026-10-14; algorithm-sweep
  verification F12, IVWC): **`InferenceContinKKRobustRegrIVWC` randomization p is always NA** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-17`.
  On the default `use_rcpp` path, the estimate-only component variance is NA, so the combined estimate is NA. Legacy IVWC.
  **Source implementation completed 2026-10-10:** estimate-only IVWC calls now
  request finite matched-pair and reservoir variances for the combination, while
  still omitting only the final combined SE. A focused mock regression covers
  the estimate-only branch and its closed-form IVWC point estimate.
  The shared matched/reservoir test passed 12 assertions and the CRAN migration
  golden passed 36 against installed EDI 1.0.3; no compile/install was needed.
  See the linked algorithm-sweep plan.

- [x] TODO-87 (added 2026-10-09, user decision; closed after installed native validation 2026-10-14; algorithm-sweep
  verification F20): **GEE exchangeable α̂ is not divided by φ̂** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-18`.
  Overdispersed Poisson gives 0.95 (clamped) vs a correct 0.33; proportions 0.06 vs 0.76. β and sandwich SEs stay valid, so this is efficiency and geepack parity. `test-kk-gee-parity.R`'s loose tolerance masks it.
  **Source implementation completed 2026-10-10:** native exchangeable-alpha
  estimation now divides the pairwise residual correlation by Pearson
  dispersion computed with `N - p` degrees of freedom. A strongly
  overdispersed Poisson geepack-parity regression covers the formerly clamped
  path. `test-kk-gee-parity.R` passed 22 assertions, including the strict
  overdispersed-Poisson case; weighted and count-weighted refit suites passed
  8 each against installed EDI 1.0.3. No Codex compile/install was run. See
  the linked algorithm-sweep plan.

- [x] TODO-88 (added 2026-10-09, user decision; algorithm-sweep
  verification F25): **g-computation SE estimand documented** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-19`.
  The delta method on β targets the sample-conditional effect; the population
  SE is 0–6% larger.  The public risk-difference and risk-ratio documentation
  now states that their sandwich-plus-delta Wald SE conditions on the empirical
  covariate distribution, excludes target-population covariate sampling
  variation, and is distinct from the absent likelihood-ratio/score tier.

- [x] TODO-89 (added 2026-10-09, user decision; algorithm-sweep
  verification F26): **Exact-binomial CI (Clopper–Pearson) and p-value are coherent** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-20`.
  They disagreed when δ0 ≠ 0 (d+ = 0, d− = 5, δ0 = 0.01: inside the CI,
  minlike p = 0.0305).  Exact-binomial inference now uses the central
  equal-tail p-value that inverts its Clopper--Pearson interval, while the
  Zhang kernel retains minlike behavior for its separate callers.  Reference
  coverage pins the nonzero-null coherence case.

- [x] TODO-90 (added 2026-10-09, user decision; algorithm-sweep
  verification F6): **Jonckheere–Terpstra exact p-value can hang uninterruptibly** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-21`.
  Composition enumeration, exponential in K: about 13 h at K = 11, n = 200, with no interrupt check. Reached only by an explicit exact call; results are correct. Fix with a polynomial DP, or at least a guard plus an interrupt check.
  **Source implementation completed 2026-10-10:** a polynomial preflight
  rejects exact allocation spaces above one million leaves before recursion,
  and permitted recursion checks R interrupts every 4096 leaves. The public
  exact-inference method warns and falls back to its asymptotic normal p-value
  for that capacity condition; direct kernel callers receive a clear error.
  Large 11-level regressions cover the immediate guard and public fallback.
  `R CMD INSTALL R/EDI` then installed the current checkout; its `make` phase
  reported no stale objects. `test-jonckheere-exact-enumeration.R` passed all
  33 assertions against that installed checkout, including the direct native
  guard and public fallback.

- [x] TODO-91 (added 2026-10-09, user decision; algorithm-sweep
  verification F3): **`std::shuffle` / `<random>` draws are stdlib-dependent** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-22`.
  The same seed gives different draws on Linux and macOS on default design and resampling paths (distributions correct). In-code "cross-platform guarantee" comments are wrong. Use Fisher–Yates on `bounded_rand` and add a fixed-seed golden. **Default change:** seed-pinned draws change once.
  **Source progress 2026-10-09:** native shuffle/distribution sites now use
  portable `RRng`/`bounded_rand` Fisher--Yates, with no stale `<random>`
  headers remaining at those sites. **Linux golden recorded 2026-10-14:** the
  seed queue's portable EDI 1.0.3 run produced six fixed-seed design digests
  for Bernoulli, rerandomization, greedy, greedy D-optimal, matching greedy
  pair-switching, and binary matching; each was identical at 1, 2, and 4
  threads. The committed fixture is
  `R/EDI/tests/testthat/fixtures/cross_platform_digests.csv`, copied from
  `/tmp/edi-todo91-linux-golden-20261014T211424/fixtures/cross_platform_digests.csv`
  and byte-identical to that generated artifact. The focused command
  `Rscript -e 'testthat::test_file("R/EDI/tests/testthat/test-cross-platform-reproducibility-digests.R")'`
  passed 18 assertions, zero failures/warnings/skips, against installed EDI
  1.0.3. (Historical: at this point the external macOS digest comparison was
  still required; it was closed 2026-10-15, below.) Utility-kernel
  coverage passed 25 assertions; the all-design seed suite passed 25
  assertions (1 CRAN-only skip) and verifies same-host repeatability.
  **Cross-platform confirmation, closed 2026-10-15:** the `R-CMD-check`
  workflow run 38629542755 on commit `95f4730b` (whose `src/` already had
  the Fisher--Yates code and no `<random>` use) ran the digest test on all 8
  legs: Linux release/devel/oldrel-1/native, macOS with and without
  OpenMP, Windows release/devel. All six design digests were identical on
  the six Linux and macOS legs and equal to the committed fixture. Both
  Windows legs reported different digests for all six designs, Bernoulli
  included; the cause was the test's `writeLines()` writing CRLF line
  endings before hashing, not the draws: recomputing each digest locally
  over the same allocation with `\r\n` reproduces the Windows hashes
  exactly (e.g. Bernoulli `1492c98a` with LF, `0f33141c` with CRLF). The
  test now hashes through `writeBin()`. The four recorded floats
  (`InferenceAllSimpleAverageDiff` estimate, Wald CI bounds, randomization
  p-value) spread by at most 2.2e-16 relative across the 8 legs, and the
  randomization p-value was identical on all of them. The run's two other
  failures were unrelated (`--as-cran`'s 2-process limit in
  `test-seed-reproducibility-all-designs.R`; an empty OpenMP flag on macOS
  in `test-build-info.R`) and are fixed in the working tree. The linked
  plan's required golden now exists:
  `test-local-rng-permutations.R` pins `generate_permutations_ibcrd_cpp`
  (seed 20261013, n = 10, 3 draws) to an exact allocation string, and the
  digest test gained `DesignFixediBCRD`, `DesignFixedBlocking`,
  `DesignSeqOneByOneiBCRD`, `DesignSeqOneByOneSPBR` and
  `DesignSeqOneByOneRandomBlockSize` (the sequential ones digest both the
  one-at-a-time assignment, `w_seq_md5`, and the redraws), covering the
  `generate_permutations.cpp`, `spbr_speedups.cpp` and
  `random_block_size_speedups.cpp` Fisher--Yates sites; the six earlier
  fixture rows are byte-identical, the eight new rows were generated on
  Linux, pass at 1/2/4 threads locally, and get their first cross-platform
  confirmation on the next CI run (reopen this item if that run disagrees).
  Still outside the digests: `stratified_bootstrap_indices_cpp` (a
  bootstrap path, not a design draw) and the annealing search in
  `design_optimal_annealing_search.cpp`; both moved to the portable
  shuffle in the same source change and are covered by
  `cross_platform_reproducibility.md → TODO-4`'s "every class" extension.
  At this point in the 2026-10-15 record, the NEWS line was pending; it was
  added later in `R/EDI/NEWS.md:12-13` (see final acceptance below).
  **Final cross-platform acceptance, 2026-10-20:** R-CMD-check run
  [39110868823](https://github.com/kapelner/EDI/actions/runs/39110868823)
  on commit `4d2531e97bc0636d3409003576a5766d15a308d0` completed the
  cross-platform comparison successfully. Its eight leg artifacts contain
  all 14 design-digest keys (the original six plus the eight added rows for
  `DesignFixediBCRD`, `DesignFixedBlocking`, and three sequential designs'
  assignment/redraw digests); each key is present on all eight Linux/macOS/
  Windows legs and has one identical digest across legs and thread counts
  1/2/4. All four recorded inference floats were also compared on eight legs;
  maximum observed range was `2.22e-16` (closed-form estimate and CI lower
  bound), with exact agreement for the upper bound and randomization p-value.
  The committed `test-local-rng-permutations.R` golden is in the R test suite
  run; the workflow completed successfully. The cross-platform CI artifacts
  and comparison job therefore close the newly added digest/golden gate.
  `R/EDI/NEWS.md:12-13` announces the one-time seed-pinned draw change.
  `stratified_bootstrap_indices_cpp` and optimal/annealing coverage remain in
  the broader `cross_platform_reproducibility.md` TODO-4 extension for
  v1.1.0; they are not part of this v1.0.5 TODO-91 fixture's acceptance set.
  **Re-audit 2026-10-20:** the 2026-10-18 CI commit precedes checkout HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but a scoped diff confirms no
  changes to `R/EDI/src`, either digest/golden test, the R-CMD-check workflow,
  or `R/EDI/NEWS.md` since the tested SHA. Thus the successful CI artifacts
  apply to the current TODO-91 source and fixture. The announcement is present
  in NEWS, and the remaining bootstrap/annealing all-class extension belongs
  to v1.1.0's linked TODO-4, not this v1.0.5 acceptance row.

- [x] TODO-92 (added 2026-10-09, user decision; algorithm-sweep
  verification F19): **Firth penalty has the wrong sign** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-23`.
  `evaluate_penalized_neg_loglik_at` adds +½ log|I| instead of −. No callers; the reference test asserts the wrong sign. Fix before anything uses it.
  **Source implementation completed 2026-10-10:** the opt-in Firth/Jeffreys
  negative objective, its comment, and its independent reference assertion now
  use `neg_loglik - 0.5 * log|I|`.
  After installing the current checkout, `test-off-optimum-likelihood-eval-mixin-reference.R`
  passed all 17 assertions.

- [x] TODO-93 (added 2026-10-09, user decision; algorithm-sweep
  verification F4): **Per-replicate seeds drawn with replacement from 31 bits (low priority)** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-24`.
  About 2.3% collision chance at B = 1e4; impact ≤ 1/B. Draw without replacement or use L'Ecuyer substreams.
  **Source implementation 2026-10-10:** both parametric-bootstrap runners
  and materialized randomization-bootstrap assignment replay now draw their
  batch seeds without replacement. `test-rand-bootstrap.R` passed 145
  assertions (4 CRAN-only skips) after installing the current checkout,
  including the deterministic BRT replay-seed regression. Source inspection
  confirms all three batch producers use `sample.int(..., replace = FALSE)`.

- [x] TODO-94 (added 2026-10-09, user decision; algorithm-sweep
  verification F16): **g-computation Bayesian-bootstrap weighting convention aligned (low priority)** —
  `../bug_fix_plans/algorithm_sweep_verified_findings.md → TODO-25`.
  Non-KK classes average equally over empirical covariates while KK used
  `weighted.mean`, a roughly 1% difference.  KK bootstrap weights now affect
  the model fit only; all g-computation implementations standardize its
  predictions equally over retained empirical covariate rows, and the public
  KK documentation records that sample-conditional convention alongside
  TODO-88's Wald-SE description.


- [x] TODO-95 (added 2026-10-11, user decision; found while scoping
  `marketing_plans/agent_proofing.md` W6): **Seed-pinned design draws depend
  on the OpenMP thread count** — `../bug_fix_plans/design_draws_depend_on_thread_count.md → TODO-1..4`.
  `DesignFixedGreedy`, `DesignFixedGreedyDOptimal` and
  `DesignFixedMatchingGreedyPairSwitching` give different allocations at
  `set_num_cores(1/2/4)` for the same seed. `DesignFixedRerandomization`
  also differs between repeat runs at 4 threads. Measured on installed
  EDI 1.0.3; `DesignFixedBinaryMatch` is invariant.
  - **Cause:** one seed per thread, indexed by `omp_get_thread_num()`
    (`design_fixed_greedy.cpp:76-144`, `optimal_design_search.cpp:143-195`,
    `rerandomization_helpers.cpp:215-293`).
  - **False documentation:** the reproducibility vignette (`:150-162`),
    two code comments and `design_class_registry.R:95-112` all claim
    thread-count independence for the greedy kernels, and `design_matrix.csv`
    publishes it.
  - **Fix:** seed per draw index, using the existing `binary_match_search.cpp`
    pattern. Rerandomization becomes a deterministic early-stopping sampler.
  - **Tests required:** a thread-invariance test over the design registry,
    a repeat-run test, rand p identical at 1 and 4 cores, and a pre-push ban
    on per-thread seeding.
  - Default threads (1) are unaffected today, but seed-pinned draws for the
    four classes change once with the fix. The package-wide guarantee
    follows in `release_v1_1_0.md → TODO-48`.
  - **Completed 2026-10-14:** draw-index stream derivation, deterministic
    rerandomization waves, metadata, documentation, NEWS, and static test
    coverage are present. After installing the current checkout, the required
    1/2/4-core allocation, repeat-run, tight-cutoff, and randomization-inference
    comparisons passed. The four post-migration streams are pinned as exact
    allocation digests in
    `R/EDI/tests/testthat/fixtures/openmp_design_seed_draws_v1_0_5.csv`; the
    single-thread fixture test passed 48 assertions with `NOT_CRAN=true` (or
    24 assertions with 4 CRAN-only skips). The cross-core seed-registry and
    tight-cutoff rerandomization suites passed 106 and 21 assertions,
    respectively.
- [x] TODO-96 (added 2026-10-14, user decision; found while wiring the
  cross-platform digest test for `release_v1_1_0.md → TODO-48`): **C++
  kernels overwrite OpenMP's global thread count with their own argument.**
  - `binary_match_search.cpp:35` calls `omp_set_num_threads(num_cores)`.
    `num_cores` comes from the design's `self$num_cores`, which is
    `get_num_cores()`, the R worker count (`design_abstract.R:913`). 21 other
    `src/*.cpp` files use the same pattern.
  - **Measured on the installed build, 2026-10-14:**
    - After `EDI:::set_package_threads(4)`: `get_num_cores()` is 1 and the
      OpenMP maximum is 4. A `DesignFixedBinaryMatch` draw then runs on 1
      thread and leaves OpenMP's global maximum at 1.
    - Through the public API, `set_num_cores(4)` sets both counts to 4, and
      nothing is reset.
  - **Effect:** a performance problem, not a reproducibility one. Draws are
    seeded per index. It shows up whenever the two counts diverge: the
    internal `set_package_threads()` used alone (tests,
    `setup-thread-limits.R`), and potentially workers and
    `SimulationFramework`. Every later OpenMP region that relies on the
    global setting then runs single-threaded. It also means the new digest
    test's thread probe, which is read before each draw, cannot see that
    BinaryMatch itself ran serially.
  - **Fix:**
    - Use `#pragma omp parallel for num_threads(k)`. This scopes the count
      to the region and leaves global state alone. Replace every
      `omp_set_num_threads()` call in a kernel with it.
    - Decide which count a kernel should use. Probably the package OpenMP
      count, not the R worker count. Document the split between
      `set_num_cores()` (R workers plus threads) and
      `set_package_threads()` (threads only).
  - **Source change, 2026-10-14:** active kernel setters were replaced by
    per-region thread clauses. `EDI_KERNEL_NUM_THREADS()` uses the package
    OpenMP maximum for the R build and preserves the explicit `num_cores`
    argument for the Python `EDI_CORE_ONLY` build. The shared parallelization
    threshold now follows the same policy. Source-level audit passes; native
    runtime verification (historical note: completed 2026-10-14, below). The new regression test
    reproduces the old installed-binary failure (maximum falls from 2 to 1),
    as expected before rebuilding.
  - **Tests required:**
    - After a draw from every OpenMP design kernel,
      `get_omp_max_threads_cpp()` is unchanged.
    - A kernel asked for k threads actually uses k. Probe
      `omp_get_num_threads()` inside the region through a small test-only
      export, or check a timing-independent proxy.
    - A pre-push ban on `omp_set_num_threads(` in `R/EDI/src/` outside
      `omp_control.cpp`.
  - After installing the current checkout (with no stale native objects),
    `test-omp-kernel-thread-count-scoped.R` passed all 40 assertions, including
    the source audit and binary-match global-count preservation check. The
    timing-independent proof is implemented as the internal
    `probe_omp_team_size_cpp()` Rcpp hook and regression test. The first probe
    test incorrectly skipped when EDI's intentional one-thread default was
    active, before attempting to configure a multi-thread team. It now sets
    the package OpenMP limit to two first, then checks runtime support; against
    the user's installed OpenMP-enabled package it passes all 42 assertions,
    including a two-thread team observed inside the probe and an unchanged
    global maximum afterward. The source audit checks all 19 threaded kernel
    files for scoped `num_threads(EDI_KERNEL_NUM_THREADS(num_cores))` regions
    and confirms `omp_set_num_threads()` appears only in the explicit package
    thread-control function. The focused test passed 42 assertions; the
    thread-control reference passed 13; and the fork-worker invariance test
    passed 8 with `NOT_CRAN=true`. Together these verify the shared per-region
    policy across every kernel plus runtime team size/global-state behavior.
    The installed build metadata now reports `-fopenmp`, matching R's
    `Makeconf`. **Completed 2026-10-14.**
- [ ] TODO-97 (added 2026-10-19, user decision; found while drawing the
  inference-component diagram for the HUJI seminar talk): **Inference component
  dependencies declare packaging, not use.** — `../new_feature_plans/inference_component_dependency_cleanup.md
  → TODO-1..7`. Each component's `dependencies` in `EDI_COMPONENT_SPECS` copies
  the retained legacy ladder's `inherit` parent. For example, `Wald` declares
  `Jackknife` but calls none of its methods. Meanwhile, undeclared calls form
  cycles: `Jackknife` and `NonparametricBootstrap` call each other, and both
  bootstrap components call resampling-cache helpers defined with
  `RandomizationTest`. The fix extracts the shared helpers into their own
  component(s), rewrites dependencies to the measured call graph, and lists
  formerly implied components explicitly on classes. It is gated on an
  unchanged per-class effective component and method golden. *(maintenance)*:
  no output or behavior change. Placed here rather than v1.1.0 by user
  decision as cleanup work, an exception to this file's bug-fix-only rule.
  **Decision gate, 2026-10-20:** the linked AST graph test covers all 106
  concrete classes against TODO-1's golden and confirms three packaging-only
  edges plus the real `Jackknife`↔`NonparametricBootstrap` cycle; it does not
  select the shared-component boundaries. Before TODO-3, the maintainer must
  approve component grouping/names and the cycle-break strategy. The proposed
  `ResamplingCore`/`BootstrapCIHelpers` names are examples only; preserve the
  TODO-1 method/component golden. No refactor or API change is authorized by
  this audit.
  **Boundary/cycle-break options audit, 2026-10-21:** current source and the
  AST acceptance test show three separable concerns: the actual
  `Jackknife`↔`NonparametricBootstrap` cycle: `Jackknife` calls
  `approximate_jackknife_distribution_beta_hat_T_private()` and
  `bootstrap_estimates_extreme()`, while `NonparametricBootstrap` calls
  `assert_jackknife_supported()` and `normalize_jackknife_unit()`. Resampling
  cache/draw-worker helpers (`get/set_cached_resampling_distribution()`,
  `get_resampling_draw_contract()`,
  `load_resampling_draw_into_worker()`) are implemented under
  `RandomizationTest` but called by bootstrap components; design-backed
  bootstrap-worker helpers are also called by `Wald`. The graph confirms the
  real acyclic spine `RandomizationCI → RandomizationTest`,
  `RandomizationBootstrap → NonparametricBootstrap`,
  `RandomizationBootstrapCI → RandomizationBootstrap`,
  `LikelihoodTests → Wald`, and
  `ParametricLikelihoodBootstrap → LikelihoodTests`; the three audited
  zero-call packaging edges remain `Wald → Jackknife`,
  `NonparametricBootstrap → RandomizationCI`, and
  `BayesianBootstrap → RandomizationBootstrapCI`.
  Candidate boundaries for owner review are (a) one neutral resampling-support
  component containing the shared cache/worker and cross-cycle helpers, which
  makes the dependency DAG simple but risks an overly broad mixed-responsibility
  component; (b) separate cache/worker and jackknife-bootstrap support
  components, which are narrower but require confirming the extracted methods
  have no back-calls or state ownership tied to their current providers; or
  (c) retain existing component names and choose one-way ownership for the
  cross-called helpers, which minimizes new registry surface but may couple
  unrelated capabilities. These are options, not a selected architecture.
  TODO-1's fixture compares each class's effective component list as well as
  public/private method-owner bindings. Adding a helper component to a class's
  resolved set would therefore change the golden even if methods and outputs
  remain identical. The owner must specify helper grouping/ownership and how
  the exact existing component-set golden is preserved; do not weaken or
  regenerate that golden implicitly. After that choice, TODO-3/4 can move
  bodies without edits to method logic, and TODO-7 must prove exact golden
  equality plus clean acyclic dependency validation. No source, test, or
  golden changed in this audit.
- [x] TODO-98 (added 2026-10-19; source fix and focused validation completed
  2026-10-19):
  **Randomization inference under left-/interval-
  censoring returns silent wrong results.** —
  `../bug_fix_plans/rand_inference_general_censoring_silent_results.md
  → TODO-1..5`.

  The shared nonzero-δ guard is now active with assertions disabled;
  randomization CI rejects unsupported general censoring before inversion;
  and Weibull parametric-bootstrap LR p-value/CI methods fail explicitly.
  Documentation and regressions cover a mixed exact/right/left/interval
  fixture, assertions-off calls across all six general-censoring-capable
  survival classes, and unaffected right-censored controls. The focused
  source-loaded test passed 24 assertions with no failures, warnings, or
  skips. Its temporary native DLL MD5 matches the installed EDI 1.0.3 DLL;
  no native source changed. See the linked plan for command and provenance.

  Supporting actual shifts of censoring bounds remains deferred.

- [ ] TODO-99 (added 2026-10-20, user decision; found while checking TODO-53):
  **`compute_rand_two_sided_pval()` must always use the `w` draws, not the Zhang
  exact test** — `../bug_fix_plans/investigate_kk21stepwise_incidence_randomization_pval_conservative.md`.
  The Zhang-dispatch branch (2026-08-23) returned `compute_exact_two_sided_pval_rand("Zhang")`
  for incidence on Bernoulli/matched designs, ignoring the draws; it is far more
  conservative (200 KK21stepwise nulls: reject@0.05 1% vs 3%, median p 0.82 vs
  0.58) and made `condition_on_ws_for_rand_tests` irrelevant for incidence.
  **Source done 2026-10-20 (R-only):** removed in `InferenceRand`'s method
  (`inference_all_abstract_rand.R`) and the `InferenceRandCI` and KK-GEE
  overrides, which now use Zhang only for an explicit `type`. The
  `transform_responses` guard for Zhang-eligible incidence is kept; the
  non-eligible-incidence refusal and the CI's Zhang path are unchanged. A
  nonzero `delta` now errors for incidence on this path. Roxygen and NEWS
  updated; the 6 dispatch test files were rewritten to pin the draw-based path
  and `migration-harness` now uses `r = 12` (the draw path needs >= 10 finite
  draws). Focused files pass source-loaded with `pkgload::load_all(compile =
  FALSE)` against the user's recompiled `EDI.so`. **Wide dispatch regression,
  2026-10-20:**
  `test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R`
  passed 30 expectations across six Zhang-eligible classes on Bernoulli and
  KK14 designs, checking finite reproducible draw-based p-values, nonzero-
  delta refusal, and explicit Zhang access. It used checkout R with
  compilation disabled and native DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Remaining: regenerate and reconcile comprehensive incidence `rand` rows
  (p-values and coverage change). No CI decision/change is needed because
  incidence randomization CIs are already disabled; see
  `incidence_randomization_cis.md`.
  **Companion dispatch/guard regression, 2026-10-20:** six additional
  focused files passed 47 assertions with checkout R loaded using
  `pkgload::load_all("R/EDI", compile = FALSE)` against the same rebuilt
  native DLL: extended Robins, log-binomial, Wald/CMH, KK g-computation risk
  difference, non-Zhang-eligible incidence refusal, and the Zhang eligibility
  predicate. Together with the 30-assertion wide class sweep, all 77
  assertions passed with no failures, warnings, or skips. Comprehensive
  incidence `rand` result-row regeneration and exact-key reconciliation remain
  open.

  **Post-reinstall installed-library recheck, 2026-10-20:** reran
  `testthat::test_file("R/package_tests/testthat_bulk/test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R", reporter = "summary")`
  against installed EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. Result remains 24
  pass / 6 fail: the same nonzero-`delta` refusal failures for Probit,
  BinomialIdentityRiskDiff, ModifiedPoisson, KKCondLogitOneLik,
  KKCondLogitIVWC, and KKNewcombeRiskDiff. R was
  `R Under development (unstable) (2026-10-13 r90668)`; installed DLL MD5
  `8b3ca30492d7b1c790deeebe94b201ad`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  Direct namespace-body inspection confirms the installed R layer still has
  default Zhang dispatch in `InferenceRand`, `InferenceRandCI`, and
  `InferenceMixinKKGEEShared`; the checkout source reserves it for explicit
  `type`. Thus the native DLL hash is not proof that the changed R definitions
  were installed. The same 30 assertions pass with checkout R loaded using
  `pkgload::load_all(..., compile = FALSE)` over the installed native DLL.
  Package metadata says `Built: R 4.7.0; x86_64-pc-linux-gnu; 2026-10-20
  07:40:04 UTC` (10:40:04 +0300), before the dirty checkout edits at
  10:45:20 (`inference_all_abstract_rand_ci.R` and
  `inference_mixin_kk_gee_shared.R`) and 10:48:54
  (`inference_all_abstract_rand.R`); `NEWS.md` was edited at 10:48:09.
  This timestamps the installed R layer as predating those edits. The matching
  DLL SHA-256 proves native identity only, not R-source freshness.
  Keep TODO-99 open until this same test passes against installed checkout R
  definitions and comprehensive incidence `rand` rows are regenerated and
  reconciled.

  **Current-checkout source-overlay rerun, 2026-10-21:** after confirming no
  competing R/Rscript process, reran the 30-assertion wide dispatch regression
  with `pkgload::load_all("R/EDI", compile = FALSE)` and the existing native
  DLL. It passed (exit 0; no failures, warnings, or skips). This validates the
  current R dispatch layer against the present DLL only; it does not reconcile
  comprehensive incidence `rand` rows or replace a correctly installed
  package. Exact-key regeneration and reconciliation remain open.

  **Scratch artifact audit, 2026-10-20:** the isolated directory
  `/tmp/edi-todo99-one-rep-GHPmHC` contains a 3-line CSV (SHA-256
  `e1ca008813ad51ca4d76ab2e56eddd6c768c1e5c1f2257453b4b940bf9e61fb9`) for
  the single `cars`/Bernoulli/`InferenceIncidProbitRegr` attempt. Its two rows
  (`compute_rand_two_sided_pval` and `delta=0.5`) both have `status=ok`; the
  nonzero-delta row returns p=0.1878905773 rather than an error. The CSV has
  no companion provenance sidecar and records only checkout commit metadata,
  not the loaded EDI R payload or DLL identity. Source tracing confirms the
  label comes from `safe_call("compute_rand_two_sided_pval(delta=0.5)",
  seq_des_inf$compute_rand_two_sided_pval(..., delta = 0.5, ...))`: this is the
  public class method, not an internal/helper dispatch. The runner loads
  `library(EDI)` and does not source checkout R definitions, so the row
  reflects whichever installed EDI namespace was active then; the CSV alone
  cannot tie that namespace to a package path/build. Therefore this scratch
  output is not evidence that the current source guard failed, and it cannot
  satisfy TODO-99; do not reconcile it into canonical results. The minimal
  installed-layer validation is the existing focused dispatch test
  `test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R`
  against the freshly installed package, after verifying the loaded namespace
  contains the checkout definitions. The output is retained only as a
  provenance-unresolved artifact requiring attribution.

  **Source-overlay focused recheck, 2026-10-20:** after confirming no active
  R/Rscript processes, ran
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` followed by
  `testthat::test_file("R/package_tests/testthat_bulk/test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R", reporter = "summary")`.
  All 30 expectations passed with no failures, warnings, or skips. Runtime
  output reports EDI 1.0.3; inspection confirms
  `InferenceIncidProbitRegr`'s public method environment is the loaded `EDI`
  namespace and its body contains the nonzero-incidence-delta guard. Its class
  definition explicitly supplies
  `InferenceRandCI$public_methods$compute_rand_two_sided_pval` as the public
  override (`inference_incidence_probit.R`); this is not a private harness
  helper. The loaded native library was
  `/tmp/Rtmp6ux7PA/pkgload13700a7e8ce483/EDI.so`, SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This validates checkout R definitions over that native library only; it
  does not close the separate installed-R-layer or comprehensive-row gates.

  **Expected-outcome validator, 2026-10-21:** added the TODO-99-specific
  `validate_comprehensive_incidence_rand_pvalue_result_artifact()` wrapper
  and `validate_comprehensive_incidence_rand_pvalue_expected_outcomes()`
  check. After generic provenance, exact-key, and terminal-field validation,
  the narrow check binds non-`NA` manifest `expected_status` and
  `expected_skip_reason` values to matching result rows. Its synthetic pure-R
  test passed 8 expectations, including rejecting a standard-statistic
  `delta=0.5` row recorded as `ok` or with the wrong skip reason. This closes
  only the expected-outcome validator subgate; current-source comprehensive
  incidence `rand` regeneration and exact-key/status reconciliation remain
  open.

  **Artifact-wrapper regression, 2026-10-21:** the focused
  `test-comprehensive-incidence-rand-attempt-manifest-reference.R` now also
  creates a temporary results CSV and schema-2 provenance sidecar, invokes
  `validate_comprehensive_incidence_rand_pvalue_result_artifact()` against
  exact expected keys, accepts the valid artifact, and rejects a wrong-status
  row. The whole file passed against installed EDI 1.0.3 via
  `Rscript -e 'testthat::test_file(...)'` (no build/install); this is synthetic
  pure-R validator integration, not current-source dispatch or result
  generation. It closes only that validator subgate. Runtime eligibility,
  provenance-stamped full incidence-`rand` regeneration, exact-key/status
  reconciliation, and explicit authorization before canonical updates remain
  open.

  **Installed-package R-layer recheck, 2026-10-20:** after confirming the R
  process table was idle, ran the same six-class dispatch test directly with
  `library(EDI)` (no `pkgload`, source overlay, build, or install). The installed
  package is EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The installed
  `InferenceIncidProbitRegr$public_methods$compute_rand_two_sided_pval` closure
  has environment `EDI`, but its body does not contain the
  `delta nonzero not supported for incidence` guard. The test result was 24
  passed / 6 failed: the only failures were the expected nonzero-delta error
  assertions for Probit, BinomialIdentityRiskDiff, ModifiedPoisson,
  KKCondLogitOneLik, KKCondLogitIVWC, and KKNewcombeRiskDiff. Installed DLL
  path: `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`;
  SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This reproduces the stale installed-R-layer mismatch: matching native DLL
  bytes do not establish that the checkout's changed R definitions are
  installed. The installed-R-layer gate remains open pending a user-managed
  install of those definitions and a passing rerun; comprehensive row
  regeneration/reconciliation remains separate.

  **Post-reinstall installed-package R-layer recheck, 2026-10-21:** after
  confirming no R/Rscript process was active, ran the same focused test against
  the installed package only (no source loading, build, or install):
  `timeout 90s Rscript -e 'library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-incidence-classes-rand-two-sided-pval-zhang-eligible-dispatch-sweep-reference.R", reporter="summary")'`.
  All 30 expectations passed, with no failures, warnings, or skips. The loaded
  package is EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its DLL is
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, MD5
  `ea0e2f72d87d401db15557e0ecc151c9`. The installed Probit public method body
  now contains the nonzero-delta incidence guard, unlike the stale R layer
  observed on 2026-10-20. This closes the focused installed-R-layer dispatch
  subgate. Comprehensive incidence `rand` row regeneration and exact-key
  reconciliation remain open; no canonical output was written.
  **Signed-shift boundary regression, 2026-10-21:** extended the same
  six-class test with `delta=-0.3` refusal assertions (the prior test covered
  only positive `delta=0.3`). The focused installed-package run passed all 36
  expectations with no failures, warnings, or skips; `library(EDI)` loaded
  EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`, and the installed
  Probit public-method body contained the guard. This closes only the
  two-sign argument-boundary subgate; comprehensive current-source incidence
  `rand` result regeneration and exact-key/status reconciliation remain open.

  **Retained-artifact reconciliation audit, 2026-10-21 (read-only):** the
  `/tmp/edi-todo99-incidence-rand-preflight/` roster has 189,280 unique
  candidate keys, but is a structural upper bound and stale against the
  current dirty runner: recorded `comprehensive_tests.R` SHA-256
  `39f1abc8e492b2307ed4229b1bf36d42021464af1521578e4683aaf3d3de7189` versus
  current `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`.
  The 525,863,531-byte canonical incidence CSV (about 502 MiB, dated
  2026-10-09) has no matching provenance sidecar. It contains 17,746
  incidence-rand p-value rows across 14 historical commit IDs; 14,470 match
  the stale candidate roster (6,983 plain calls and 7,487 delta calls), with
  no duplicate canonical keys. The only isolated output is the known two-row
  cars/Bernoulli/Probit CSV, without a receipt sidecar or loaded R/DLL identity.
  No complete current-source artifact is available. Regenerate the runtime
  expected manifest from the stabilized runner, execute the full incidence
  `rand` slice with attempt events/provenance into isolated output, and
  validate exact keys/statuses. Any canonical reconciliation remains a
  separate explicitly authorized gate; no R, build, merge, or canonical write
  occurred in this audit.

  **Manifest/runner wiring audit, 2026-10-21 (read-only; partially superseded
  by the artifact-wrapper regression above):** `trail callers` and exhaustive
  `rg` show the incidence-rand attempt-manifest builder is called only by its
  synthetic reference test, not by the comprehensive runner. The wrapper was
  not yet directly tested at that audit; the later synthetic CSV+sidecar
  regression above now exercises it and closes only the validator-integration
  subgate. The fixture supplies expected keys/statuses synthetically, and the
  wrapper still has no production-runner caller. It does not establish
  runtime eligibility or current-source completeness. The substantive gate
  still requires runner-produced runtime attempt/eligibility records and
  provenance in isolated output, exact-key/status reconciliation, and
  separate explicit authorization before canonical-row updates. No run or
  artifact write was performed.

  **Attempt-event/result reconciliation contract, 2026-10-21:** the TODO-99
  artifact validator now requires the attempt-event CSV named by the run
  receipt, checks its resolved path/byte count/SHA-256, and reconciles keyed
  events and results to the caller-supplied expected manifest. Each expected
  operation must have one `started` and one `terminal` event, a matching
  terminal result, and the expected status; missing/extra/duplicate keys,
  unpaired events, and status mismatches are rejected. The focused pure-R
  `test-comprehensive-incidence-rand-attempt-manifest-reference.R` passed 14
  expectations against installed EDI 1.0.3 using synthetic `/tmp` artifacts.
  Unkeyed `setup_skipped`/`setup_failure` events are retained only as context
  and are not counted as operation attempts. A follow-up source audit found
  `design_formula` in scope at all three `setup_skipped` emission sites; they
  now record its deparsed value. The outer `setup_failure` event already
  recorded `model_formula`. A focused pure-R source/writer regression passed
  with no failures, verifying all three calls pass formula context and the
  writer preserves it. These events remain unkeyed because setup failure has
  no inference/function operation key, so formula context does not identify a
  specific inference-method attempt. The
  expected manifest is still caller-supplied, and the validator has no
  production-runner caller. Runtime eligibility/full-roster completeness,
  current-source isolated regeneration and reconciliation, and separate
  authorization before canonical updates remain open.
  **Setup-context validation follow-up, 2026-10-21:** source
  review found the validator accepted unkeyed setup events without the
  `model_formula` now recorded by all three `setup_skipped` call sites; it
  also did not constrain setup lifecycle fields. The pure-R validator now
  requires nonempty case/formula/error context, no operation identity, and
  the writer's `setup_skipped` versus `setup_failure` status/function shape.
  The synthetic regression covers both valid event types plus missing-formula
  and invalid-status rejection. The focused test is registered in correctness
  and coverage tiers and passed 17 expectations against installed EDI 1.0.3
  with no failures, warnings, or skips; it uses synthetic `/tmp` artifacts and
  makes no build/install or canonical write. This closes only the setup-context
  validator contract subgate. The expected-manifest, runtime-eligibility,
  full-roster, provenance, and canonical authorization gates remain open.

- [ ] TODO-100 (added 2026-10-21, user decision; found while writing the
  Technion seminar slide on `InferenceRandCustom`):
  **Custom-statistic randomization CI is searched on the statistic's scale,
  not δ's** — `../bug_fix_plans/custom_rand_ci_statistic_scale.md → TODO-1..4`.
  With a Welch t statistic the CI comes back (1.35, 1.81) in place of about
  (-0.24, 1.09). Every δ in it is rejected (p = 0.004), and it excludes
  δ = 0 (p = 0.144). The p-values themselves are correct. The search seeds on
  `compute_estimate()` (the t value) and never checks that its seed is
  accepted.

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: default behavior with
no new switches set must reproduce 1.0.0 results (numerical equivalence
per owner decision D2, 2026-10-15:
`../new_feature_plans/cross_platform_reproducibility.md → Release-to-release
equivalence`; bit-for-bit before that date), except where
a TODO above explicitly documents a default change (TODO-2, TODO-3,
TODO-56, TODO-57's native weighted refits — its owning plan's TODO-6
(and TODO-8 if pursued), TODO-58's direct model-matrix subsetting (its
plan's TODO-3, tolerance-equal with a bit-preserving rebuild fallback),
TODO-61's unsquared matching objective (its plan's TODO-2,
decision-gated, off until the user accepts it), and TODO-64's Poisson
kernel only if its plan's TODO-3 chooses to write it rather than delete
the dead method (tolerance-equal), and the 2026-10-09 correctness fixes
TODO-67 (KK21 survival weights move to the correct Weibull MLE), TODO-68
(randomization CIs narrow from 1 − α/2 to the documented 1 − α), and
TODO-69 (Breslow on the two Cox fallbacks, tied data only), and the
algorithm-sweep verification fixes TODO-70..94, which by design change wrong
results (each names its default change; TODO-91 changes seed-pinned draws once), and TODO-95 (seed-pinned draws of the four OpenMP design classes change once, at every thread count); all document their equivalence
tolerance or verification).
No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn (see
top-level `CLAUDE.md`); verify any `.cpp`-adjacent change via targeted
compile only, never a full build.

**Historical verification snapshot, 2026-09-24** (checked against the installed package
plus each plan's own checklist, at the user's request — see each TODO's
own "Verified" note above for detail): only **TODO-5, 9, 10 (partial), 13,
14** are actually done. **TODO-1, 2, 3, 4, 6 are NOT implemented** despite
this file's earlier framing possibly reading as "likely done, pre-audit" —
that assumption was wrong and is corrected here. TODO-3 in particular is
not just unimplemented but actively broken (throws a programming-error
pattern and silently falls back to a ~800×-slower path). TODO-8, 12, 15,
16 are open investigations, not yet fixed, same as before this pass. A
real "ship what's ready now" release currently contains only TODO-5, 9,
10, 13, 14 — everything else needs implementation work first. (TODO-22,
added after this pass, is also done, per a fix applied by a separate
session and confirmed present in source — but not independently
re-verified here; TODO-17-21 are a separate, later triage wave with their
own per-item confidence levels, also not covered by this verification
pass.)

**Completed-item audit, 2026-10-07:** every checked entry was re-read with
its linked plan. TODO-12, TODO-55, and TODO-56 were reopened because their
own plans still require, respectively, a release-wide bit-for-bit sweep;
historical-row regeneration plus baseline re-audit; and regenerated results.
TODO-56's stale generated documentation, missing direct regression, and NEWS
decision were completed during this audit. At that audit's cutoff, the ten
entries still checked were TODO-22, TODO-28, TODO-30, TODO-34, TODO-35,
TODO-36, TODO-37, TODO-39, TODO-40, and TODO-44; their item-specific
checklists then had no unfinished work. This is a historical snapshot, not a
current aggregate: later per-item reconciliations above control the present
checkboxes. Superseded TODO-28 checklist items are closed with explicit
dispositions in its plan rather than left as apparent subtasks.
