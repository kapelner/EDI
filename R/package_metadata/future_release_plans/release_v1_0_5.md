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
  or benchmark acceptance.
- [ ] TODO-3 (added 2026-08-30, user decision): **Wire the unused OLS
  randomization-distribution kernel; triage dead kernels** —
  `ols_randomization_distr_cpp_wiring.md → TODO-1..6`.
  `compute_ols_distr_parallel_cpp` (`src/ols_distr_parallel.cpp:15`) is
  complete and exported but has no caller anywhere (R, tests, python,
  benchmark); `InferenceContinOLS` has no `compute_fast_randomization_distr()`
  and falls through to the R-level reused-worker loop
  (`inference_all_abstract_rand.R:708-800`) — ~100–200 µs of R6 bookkeeping
  per replicate around a ~5 µs solve. Adds the method on the Poisson
  pattern (`inference_count_poisson.R:839`), passing the hardened covariate
  block and adding a per-replicate rank guard to the kernel so `NA`
  patterns match the worker. Same estimator to ~1e-14 (documented default
  change, tolerance 1e-10). Expected 20–50× on the OLS randomization
  distribution; multiplicative with TODO-2. It also triages eight exports
  without a production caller; their wire/delete dispositions remain open.
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
  matrix/parity evidence and TODO-5's benchmark; these results do not validate
  native code from the current checkout. Keep this parent unchecked pending
  current-head native validation, TODO-4's dead-export disposition, and the
  separate TODO-6 Lin stretch decision.
  - [ ] After an explicitly authorized `EDI_UNITY=0` build/install (or an
    equivalent user-managed current-head package), rerun the OLS kernel
    parity/edge matrix and public randomization test against that native
    artifact with source/DLL provenance.
  - [ ] Decide the disposition of the eight genuinely unused exports; only
    after approval, migrate their direct tests/benchmarks, update Rcpp
    registration/generated wrappers, and verify no production callers remain.
  - [ ] Obtain the separate owner decision on TODO-6's Lin stretch target and
    align the release claim with that decision.
- [ ] TODO-4 (added 2026-08-30, source fixed 2026-10-08; focused edge tests added, full validation pending): **Guard the unguarded
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
  compile/install). Plain installed-namespace execution still uses the older
  class until the maintainer's independent reinstall. The release item remains
  open: linked TODO-3 still lacks an explicit before/after `identical()` sweep
  for all `with_var` fixtures. The new literal-Inf assertion passed against
  the installed EDI v1.0.3 binary, whose metadata reports a Sep 20 native
  build; it confirms the behavior of the available binary, not the current
  source revision's native migration.
  - [ ] Run linked-plan TODO-3's before/after comparison over every
    `with_var` fixture on a provenance-pinned current-head native package;
    apply the release's numerical-equivalence policy to invertible fits and
    confirm singular/non-finite cases surface the typed SE/CI fallback.

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
  `compute_lik_ratio_bartlett_approx_two_sided_pval()`'s B=99 Monte-Carlo
  null replicates, traced to the Clayton-copula/loggamma-frailty C++
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
  TODO-8 remains open pending reconciliation and authorized current-native
  validation; TODO-7's documentation update and comprehensive-results
  regeneration must wait. Full results and metadata are preserved at
  `/tmp/edi-todo8-400-null-installed-20261014T142934Z/`.
  **Full-data wiring regression, 2026-10-18:** the new integration assertion
  in `test-stereotype-logit-full-fit-multistart.R` confirms ordinary
  `generate_mod()` invokes the multi-start selector and returns a finite
  treatment estimate with a selected start. Source-loaded test passed 17
  assertions with compilation disabled; native calls used installed EDI
  1.0.3 (`EDI.so` MD5 `dd43c5d0e11708aea17ba82b900f66d1`). This closes only
  the call-site regression gap, not calibration or current-native validation.
  **Scratch audit-path check (2026-10-18):** the focused
  `test-comprehensive-audit-output-directory-override-reference.R` passed 7
  assertions with 0 failures and 0 warnings. This verifies that response-level
  audit inputs, baseline, and stamp route to the configured scratch directory;
  it is not a full audit or post-fix regeneration and does not close TODO-8.
  Before any scratch `--write-baseline` pass, stage all complete response-type
  inputs covered by the baseline; an ordinal-only audit input set could make
  findings for absent response types appear resolved and prune them.
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
  unchecked.
  - [ ] After a post-fix package is available, regenerate the complete
    supported proportion `rand` family (both `~1` and `~.` formulas and all
    supported design/data/beta/rep keys); reconcile by `case_id` and `id`,
    validate provenance, statuses, finite CI endpoints and coverage fields,
    then merge/deduplicate only the complete target set.
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
  **8,640 runner-attempt keys** (9 × 2 × 2 × 40 × 2 × 2 × 3); it is not a
  claim that any of those rows have run or succeeded. Build the expected-key
  manifest independently from these source loop/selector dimensions under
  the fresh `/tmp` run directory, before running the harness; do not infer
  the target set from the emitted CSV. The natural key is
  `(rep, beta_T, dataset, response_type, design, inference_class,
  function_run)`, identical to the harness result key `id` formed by joining
  those values with `||` and serializing numeric `beta_T` with
  `format(as.numeric(beta_T), scientific=TRUE, digits=17)`. `case_id` is not
  unique across replicates and is not the merge key.
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
  are on unrelated mechanisms, out of scope here. A package-wide sweep for
  any other class sharing both the helper and the negation pattern is
  still open (plan's TODO-2b). **2026-09-25, investigated at user request
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
  focused migration/registry suites pass. **Linked-plan status corrected
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

  **Independent confirmation 2026-10-09** (algorithm-sweep verification F18,
  `../new_feature_plans/algorithm_choice_audit_catalog.md §13.4`): the cloglog
  native `α + xβ` convention is the root cause of the sign bug, **for cloglog
  only**. Proportional-odds, cauchit and ordered-probit callers match the shared
  simulator and are unaffected. AdjCat, KKCondAdjCat, CR and stereotype never call it.
  The staged cloglog fix (`inference_ordinal_cloglog.R` +
  `test-cloglog-parametric-bootstrap-native-sign.R`) checked out as correct.
- [ ] TODO-17 (added 2026-09-23, surfaced by the new `pval_miscalibration`
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
  - [ ] Obtain a maintainer decision on the Wilcoxon-specific remedy or an
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
  - [ ] Finish the dispatch/support cross-reference and continuous-bandwidth
    investigation; then, after TODO-56 releases shared result paths, run the
    predeclared matched calibration for supported continuous and count cells
    (at least 500 estimable cases per stratum, B=101, shared assignments and
    noise, exact binomial intervals and paired discordances). Verify bounded
    categorical cases are rejected, select and pin a permanent-test fixture/
    tolerance, then regenerate rows with package/DLL provenance.
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
  - [ ] After a provenance-pinned post-fix package is installed, regenerate
    and reconcile the `InferenceIncidKKModifiedPoisson` comprehensive rows:
    unsupported score/gradient/LR/Bartlett/parametric-bootstrap rows must be
    absent and the supported Wald rows must remain. Record exact result keys
    and package/DLL provenance before re-auditing.
- [ ] TODO-20 (added 2026-09-23, same audit-triage wave; original
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
  TODO-20 remains open without a fix or dismissal of the historical finding.
- [ ] TODO-21 (added 2026-09-23, same audit-triage wave; reservoir-
  singleton hypothesis **REFUTED 2026-09-23 by code trace AND direct
  reproduction, high confidence on the code being correct — but the
  historical inflation finding itself is now UNCONFIRMED, not
  reproduced**; tracked as an open investigation, not a fix plan, in
  `bug_fix_plans/investigate_incid_kk_gee_bootstrap_family_inflation.md`):
  `InferenceIncidKKGEE` shows the same consistent-direction
  bootstrap-family inflation shape as TODO-20
  (`compute_bayesian_bootstrap_two_sided_pval_wald` 0.314,
  `compute_bayesian_bootstrap_two_sided_pval` 0.306,
  `compute_rand_bootstrap_two_sided_pval_symmetric-percentile-t` 0.185 —
  all vs. nominal 0.05, from historical `comprehensive_tests` CSV rows).

  **Refuted**: read the full chain —
  `design_matching_abstract.R:55-114` (separates reservoir-singleton
  indices from matched-pair row pairs, both cached in
  `init_matching_bootstrap_structure()`) and
  `bootstrap_match_indices.cpp:92-130`
  (`draw_matching_bootstrap_sample_cpp`, the actual C++ resampler). This
  is textbook-correct cluster bootstrap: reservoir singletons resampled
  i.i.d. with replacement, matched pairs resampled as intact 2-member
  units with fresh relabeled pair IDs. No mishandling of the singleton
  case found.

  **Direct reproduction could NOT reproduce the historical inflation
  either**: a fresh true-null `InferenceIncidKKGEE` fixture
  (`DesignSeqOneByOneKK14`, `pkgload`, no compilation) gave
  `compute_bayesian_bootstrap_two_sided_pval(type="wald")` = **0.050**
  (n=100, B=200, 40 reps — exactly nominal) and the default variant =
  **0.025** (mildly conservative). A second, smaller check (n=60, B=100,
  25 reps) gave 0/25 rejections — consistent with nominal/conservative,
  not inflated. Neither run is remotely close to the historical
  0.306-0.314.

  **Open question, not yet checked**: the reproduction fixture used a
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

  **Bottom line**: this may be resolved/noise, may need the exact
  triggering dataset to reproduce, or may not be a real defect at all —
  genuinely unclear. Do not write a plan file without first pulling the
  exact historical dataset/design/formula and confirming the inflation
  reproduces on it.
  - [ ] Recover the stamped historical input or obtain an owner-approved
    equivalent with dataset, design, both formulas, DGP, seed schedule,
    commit/runtime, denominator, and pooling rules. Replay the flagged rates;
    if they reproduce, check the three KKGEE siblings and near-collinearity
    before deciding whether to create a fix plan. Do not infer a defect from
    the simplified null pilots.
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
  - [ ] Regenerate the documented 50-rep matrix (two formulas × three
    jackknife operations) into a fresh `/tmp` output using a provenance-pinned
    post-fix package; audit exact keys and statuses, then perform separately
    authorized canonical reconciliation without overwriting the existing
    filtered rows.
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
  and results. TODO-50 stays open pending TODO-31 resolution and canonical
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
  regeneration. No result CSV or baseline was changed. Policy resolution,
  current-head native validation, and row regeneration/audit remain open.
  - [ ] Close TODO-31's Poisson local-optimum/start-policy decision, validate
    the selected policy on the broader four-kernel grid, and reconcile the
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
  - [ ] For the historical `InferencePropBetaRegr` lead, run the six corrected
    one-replicate proportion-response pilots in isolated `/tmp` outputs; time
    the B=151 generic LR-bootstrap cell first. Inspect the actual affected
    p-value/coverage results before deciding whether a post-fix calibration
    study or source change is warranted.

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
  added GLM beta candidate reports exact NLL 312.754654 versus 312.749004 for
  the `glmer` candidate at seed 41003 (gap about 0.00565, above the linked
  plan's 1e-3 material threshold; gradient norm 1.731). This probe is not a
  current-checkout native validation, but it means the present change does not
  yet establish optimizer-independent acceptance. The sigma-by-n runner also
  labels `strictly_worse` at 1e-6 while the plan's material threshold is
  1e-3; compare raw likelihood gaps under the declared threshold before
  interpreting its classification. Keep TODO-31 open until the Newton path
  is covered and the optimizer policy passes the full grid.
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
  - [ ] Resolve Poisson local-optimum cases at seeds 41003/41008 with an
    optimizer/start policy that preserves already-correct fits, or obtain an
    explicit scope decision separating that issue from the boundary-collapse
    finding. Validate the selected policy on the broader four-kernel sigma-by-n
    grid, then run current-head native tests and reconcile provenance-stamped
    CountKKGLMM/OrdinalKKCLMM comprehensive rows.
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
  regression exercises both directions. Real-data reproduction of the inner
  loop remains open. **Installed-package coverage recheck 2026-10-14:** a
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
  - [ ] After TODO-56 terminates and host load is suitable, run the bounded
    20-seed `trees` public-API search and retain a candidate only if it enters
    upper-bound inner refinement with finite full-precision endpoints that
    bracket the threshold. If a trigger is found, preserve replay inputs and
    pause for review before the old-branch counterfactual or repeated-trial
    coverage study.
- [x] TODO-34 (added 2026-09-24, same audit; fixed 2026-10-07): **Interval-censored `compute_shared_icen()` blanket cache guard**
  — `../bug_fix_plans/interval_censored_compute_shared_cache_guard.md →
  TODO-1..4`. After `compute_estimate(estimate_only = TRUE)`, a later full
  call on `InferenceSurvivalLogRank`/`GehanWilcox` under general censoring
  never computes `s_beta_hat_T`, and `compute_asymp_confidence_interval()`
  crashes. Fixed for both classes; focused ordering and interval-reference tests pass without compilation. Same family as the stale-cache fixes.
- [x] TODO-35 (added 2026-09-24, fixed 2026-10-07): **`delta = NA` crash in the incidence g-computation risk ratio** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-1`. Added `any.missing = FALSE` to ordinary and KK g-computation p-values and the same vulnerable Newcombe risk-difference p-value. Focused regression tests pass without compilation.

- [x] TODO-36 (added 2026-09-24, fixed 2026-10-07): **Exact-test classes cannot use the shared weighted estimate** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-2`. Exact-only classes now report a clear unsupported error for bootstrap-weighted estimation; the dead helper calls and six wiring exceptions were removed. Focused exact-class and wiring tests pass without compilation.

- [x] TODO-37 (added 2026-09-24, fixed 2026-10-07): **`inference_class_accepts_model_formula()` is always FALSE** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-3`. The predicate now inspects the effective R6 initializer, including inherited and lazy component methods. `run_all_inference_build_tasks()` now expands requested formulas for eligible classes; the focused regression test passes without compilation.

- [x] TODO-38 (added 2026-09-24, test-comment audit; **reproduced 2026-09-24 under valgrind: heap overflow from an unvalidated `warm_start_params` length**, see plan TODO-4; **ZOIB kernel length checks implemented and verified 2026-09-24**, sibling source sweep completed 2026-10-09; installed-native recheck 2026-10-14): **Fresh-process crash in `fast_zero_one_inflated_beta_cpp()`** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-4`. In a fresh Rscript the kernel returned `neg_loglik = NaN` and `coefficients = NULL` on ordinary data (8/8 seeds) but not inside testthat, suggesting undefined behavior in the C++ kernel. The direct input-validation test passed 9 assertions against the reinstalled EDI package and under Valgrind Memcheck; the CRAN fast-math test passed 2 assertions. Codex did not compile/build/install. The class was previously verified not to pass malformed starts; the broad sibling-kernel validation remains tracked separately.
  **Source implementation status 2026-10-09:** the ZOIB native guard remains
  fixed, and the successor plan `mixed_kernel_warm_start_shape_guards.md`
  records completed audit, native guard, orphaned-R-helper, and focused-test
  source work (TODO-1..4). Rebuilt-native kernel tests, ASAN/Valgrind, and
  installed comprehensive-CSV reconciliation (TODO-5..6) remain release
  gates, so this checkbox deliberately stays unchecked.

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

- [x] TODO-53 (added 2026-09-24, fixed/audited 2026-10-09; from triaging the stale-cache regeneration
  findings; reproduced from scratch, mechanism unknown): **Randomization
  p-values are conservative at the null under
  `DesignSeqOneByOneKK21stepwise` (incidence)** —
  `../bug_fix_plans/investigate_kk21stepwise_incidence_randomization_pval_conservative.md →
  TODO-1..4`. 60 simulated nulls: 0 rejections, median p 0.71, mean p 0.66;
  `InferenceAllSimpleAverageDiff` gives identical p-values, so it is shared
  design-replay/randomization machinery, not the g-computation class. Costs
  power (0.183 vs 0.317 for the Wald test at `beta_T = 0.5`); not a validity
  failure. **Resolution:** KK21 inherited KK14's fixed-realized-pair redraw,
  which is invalid once outcome-adaptive weights make pair formation depend
  on the assignment path. KK21 now replays the full sequential rule while
  exposing only prior responses and restores all completed-design state.
  Match-count and balance distributions agree with fresh designs, and focused
  incidence/continuous/count regressions plus the seed suite pass 90
  assertions without compilation. The remaining incidence conservatism is
  discrete exact-test behavior: inclusive tails retain finite-sample
  validity; strict or mid-p tails reduce it only by changing that contract.
  All four linked-plan items are closed.

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
  Independent of
  `mc_coverage_truth_covariate_mismatch.md`'s TODO-6/TODO-11 — different
  mechanism (closed-form path, not Monte-Carlo), different classes, do not
  conflate when resolving either.
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

  **Focused source/fixture check, 2026-10-18:** the design-backed bootstrap
  worker state/sample-loading reference test passed 113 assertions against
  installed EDI 1.0.3. Its QR-certificate assertions extract the current
  checkout's `load_bootstrap_sample_into_design_backed_worker()` definition;
  setup and native calls still came from the installed DLL. This is focused
  R-source evidence, not current-checkout native validation or performance
  acceptance.

  Acceptance: `marketing_plans/bb_bench2.R` shows no
  row slower on 3 cores than on 1, and EDI ≥ 1x vs. `bayesboot` on every
  row.

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
  - [ ] Run the full original-bootstrap-size public R6 percentile-CI benchmark
    for OLS, logistic, and Cox against `boot`, requiring each row to reach at
    least 1x; separately confirm fixed-seed distribution parity against an
    authoritative EDI 1.0.2 package. Record package/DLL provenance and keep
    diagnostic or reduced-B pilots out of acceptance.

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
  after a four-row materialization; it remains unexecuted here because this
  task forbids R execution.
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
  - [ ] After TODO-56 is terminal, run
    `Rscript R/benchmark/benchmark_pocock_simon_arrivals.R 1000 20 5` on an
    idle host; record installed package/DLL identity and host provenance, and
    require per-arrival medians at t=10/100/500/1000 to be <= 0.5 ms with no
    material upward trend. Separately verify fixed-seed assignment-vector
    identity against an authentic EDI 1.0.2 package and refresh the full
    n=1000 report context; do not use a carat ratio as an acceptance gate.

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
  - [ ] Set and record an owner-approved numeric Zhang parity tolerance;
    rerun the canonical fixture and confirm both parity and report rows.
    Only then regenerate and synchronize all four tracked reports from the
    harness (never by hand-editing generated artifacts).

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
  - [ ] After an explicitly authorized `EDI_UNITY=0` build/install, run the
    full malformed-start contract against the matching native library, the
    Python wrong-length-start suite, and the sanitizer/Valgrind CI jobs; retain
    per-wrapper results and verify no malformed start reaches an unchecked
    dereference.

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

- [x] TODO-66 (added 2026-10-08; serial-dispatch fix and runtime gates
  completed 2026-10-18):
  **`InferenceCountHurdleNegBin`'s non-reusable-worker multi-core Bayesian
  bootstrap (`num_cores = 2`, `debug = TRUE`) hangs intermittently.**

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
  - [ ] Review/approve or replace the linked plan's TODO-5 replacement-fixture
    and mASMD proposal, and set any acceptance threshold; then run the
    `survreg`-referenced KK21 survival-weight comparison and regenerate/re-audit
    every affected benchmark row with current-code package and native-library
    provenance. The proposal is not an approved estimand, and the installed
    EDI 1.0.3 binary and CI at 430c19bc do not validate current HEAD.

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
  regression was added. This remains unchecked pending R execution; this host's
  `Rscript` cannot load `libmkl_gf_lp64.so.2`.

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
  the estimate-only branch and its closed-form IVWC point estimate. This remains
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
  1.0.3. The external macOS digest comparison is still required; this item
  remains unchecked pending that cross-platform confirmation. Utility-kernel
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
  The NEWS line announcing the one-time draw change is still to be
  written (release step).

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
    runtime verification remains pending a rebuild. The new regression test
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
- [ ] TODO-98 (added 2026-10-19, user decision; found while preparing the
  HUJI seminar survival demo): **Randomization inference under left-/interval-
  censoring returns silent wrong results.** — `../bug_fix_plans/rand_inference_general_censoring_silent_results.md
  → TODO-1..5`. A δ ≠ 0 null shift moves only `y`, not `y_L`/`y_R`, so censored
  rows stay unshifted. The shared guard against this runs only with asserts on
  (`SimulationFramework` turns them off by default). With asserts off,
  Cox and log-rank randomization p-values at δ ≠ 0 are computed silently:
  0.438 and 0.408 on the plan's fixture, where both should error. Weibull's own
  always-on guard is swallowed by the randomization CI's `tryCatch(..., NA)`.
  As a result, `compute_rand_confidence_interval()` returns a finite interval
  built from NA p-values: (-0.147, 0.749) on the current source, asserts on.
  Also covers the Weibull parametric-bootstrap LR returning a silent `NA`
  under general censoring. Fix scope: errors instead of silent results.
  Supporting the shift is deferred.

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
