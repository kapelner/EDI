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

Every item here is **independent of every other item in this file and of
every item in `release_v1_1_0.md`** (verified when each was originally
scoped into v1.1.0; nothing here depends on that release's Phase 0 decision
batch or its diagnostics-chain prerequisite). This release can ship the
moment its own items are done and verified, without waiting on v1.1.0 —
that independence is the entire reason for the split. TODO numbers below
are renumbered 1..16 in chronological "added" order; each still names its
owning plan file with that plan's own (unrenumbered) TODO range, since the
plan files' internal numbering did not change.

## Implementation TODOs

- [ ] TODO-1 (added 2026-08-27): **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`** — `../bug_fix_plans/reusable_bootstrap.md →
  TODO-1..6`. The one class (of 51 live inference families, audited)
  missing the `get_bootstrap_worker_spec()` fast path
  `local_machine_optimization.md`'s shipped `tune_EDI_for_this_machine()`
  already relies on elsewhere; its jackknife rebuilds a fresh
  `Design`/`Inference` object and reruns full column-selection from scratch
  per leave-one-out fold instead of reusing one warmed-up worker. Small,
  additive, R-layer only (no kernel change); must reproduce bit-identical
  jackknife results before/after (plan's TODO-4). **Verified NOT
  implemented, 2026-09-24**: `get_bootstrap_worker_spec()` — the specific
  method this plan says is missing — is still missing on the installed
  package. (The four generic reused-worker methods checked first,
  `supports_reusable_bootstrap_worker()` etc., exist, but that's a red
  herring — they're baseline mixin methods every class gets regardless of
  this fix.) Plan's own checklist: 0/6 checked.
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
  distribution; multiplicative with TODO-2. Also triages eight other
  never-called exports: wire the bootstrap one if its contract matches,
  delete the rest (with unity-group cleanup). **Verified NOT implemented —
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
- [x] TODO-4 (added 2026-08-30, fixed 2026-10-08): **Guard the unguarded
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
  `model_standard_error_unavailable` paths. All six linked-plan items are
  closed and 18 focused source-loaded assertions pass without compilation;
  native execution is staged for the next permitted rebuild.

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
  `set_min_eigenvalue_if_suspect()` (`_helper_functions_core.h:210-219`)
  is entirely commented out, so `min_eigenvalue_information` is never
  populated — minor, unrelated cleanup, not investigated further.
- [ ] TODO-5 (added 2026-09-04, found empirically): **Randomization CI
  construction audit** — `randomization_ci_construction_audit.md →
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
  `[x]`; only a cosmetic test-comment fix (TODO-3) remains. The one
  substantively complete item among TODO-1..6.
- [ ] TODO-6 (added 2026-09-11, found via a comprehensive-test-harness
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
  and the stale-gradient fix have not been applied.
- [ ] TODO-7 (added 2026-09-17, found via a raw `comprehensive_tests`
  results-CSV audit, not a user report): **`KKQuantileRegrOneLik`
  randomization CI** — `../bug_fix_plans/KKQuantileRegrOneLik_rand_ci.md → TODO-1..6`.
  `InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
  compose `QuantileRandomizationCI` (Zhang test-inversion) without ever
  supplying the `compute_rand_pval_matched_pairs`/`compute_rand_pval_reservoir`
  hooks it needs — the bisection silently collapsed to a zero-width
  interval at the point estimate instead of erroring (100% zero-width
  across ~1,644 audited rows, ~0-1% empirical coverage vs. ~95% nominal).
  Stopgap `stop()` landed 2026-09-17; the real fix (route through the
  already-correctly-wired generic `InferenceRandCI` bisection instead of
  Zhang) is unverified and needs its own decision before implementing.
- [ ] TODO-8 (added 2026-09-22, found via a raw `comprehensive_tests`
  results-CSV audit, not a user report): **Stereotype-logit multimodal
  likelihood** — `../bug_fix_plans/multimodal_log_liks.md → TODO-1..8`. The 2026-09-21
  fix to `InferenceOrdinalStereotypeLogitRegr`'s delta-constrained null
  refit (multi-start, closed a zero-width-CI bug) left a residual: the
  likelihood is multimodal and `compute_estimate()`'s own unconstrained fit
  is single-start, so it can silently return a non-global optimum (~3% of
  `n=50` fits in a 400-simulation measurement). Explains a residual ~13%
  Type-I error at `n=50` (vs. 6.5% at `n=100`). Proposed fix is multi-start
  `generate_mod()`, but this one changes reported point estimates in the
  affected fits, so it needs golden/reference-parity re-derivation and a
  cost/benchmark pass before it ships.
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
  permanent non-degeneracy regression test.
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

  **New class found 2026-09-24** (plan's new TODO-7, this one NOT yet
  fixed): `InferenceSurvivalKMDiff` was missed by the original 25-class
  `COVERAGE_MC_SPEC` sweep — surfaced instead by this session's new
  `biased_estimate` audit check as apparent large bias, confirmed on
  investigation to be the same truth-scale-mismatch mechanism (estimator
  itself is unbiased at the null; `coverage_truth` is identical to raw
  `beta_T` for 100% of rows despite KM-difference being a non-collapsible,
  different-scale quantity). Needs adding to `COVERAGE_MC_SPEC` and the
  same fix applied.
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
  focused source-loaded tests pass without compilation. The release-wide
  pre/post bit-for-bit sweep remains a final verification item because a
  comparable clean baseline is not currently available.
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
  already-correct standard-path logic. CSV regeneration still open (plan's
  TODO-6).
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
  same file. CSV regeneration still open (plan's TODO-7).
- [ ] TODO-15 (added 2026-09-23, from the same `bad_type1_error` audit wave
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
  difference estimators essentially never land exactly on 0). Recommended
  fix: a mid-p/tie-splitting correction to the generic two-sided p-value
  formula (`inference_all_abstract_rand.R:317` and the bootstrap-family
  equivalents) — likely belongs in the shared formula, not a per-class
  patch, since any other class with a discrete/tie-prone statistic could
  hit the same boundary-collapse pattern (plan's TODO-2 checks this).
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
- [ ] TODO-19 (added 2026-09-23, same audit-triage wave as TODO-17/18, a
  secondary lead the investigating fork did not have budget to fully
  confirm — **medium confidence**; tracked as an open investigation, not
  a fix plan, in
  `bug_fix_plans/investigate_incid_kk_modified_poisson_se_quality.md`):
  possible over-estimated standard error causing chronic
  under-rejection (reject-rate 0.000) across MULTIPLE unrelated test-
  statistic families simultaneously (Wald, score, gradient, likelihood-
  ratio, Bartlett all zero-reject at the same cell) for
  `InferenceIncidKKModifiedPoisson` at `model_formula=~1`. The original
  hypothesis (a structurally non-estimable/degenerate cell, similar in
  shape to `InferenceAllSimpleWilcox`'s TODO-17 finding) was directly
  REFUTED: `compute_estimate()` for this exact cell (n=172, beta_T=0) shows
  146 distinct values ranging -0.37 to 0.52, only 4.65% exactly 0 — a
  normally-varying point estimate, not a degenerate one. Alternative,
  unconfirmed lead: Wald CI width for the same cell has median 0.82
  (half-width ≈0.41) while the point estimate's own empirical IQR is only
  (-0.11, 0.12) — roughly 4x wider than the estimate's actual spread,
  consistent with an over-estimated SE that every test family consuming
  that same variance estimate would inherit. Not yet verified against the
  empirical SD of `beta_hat_T` across reps — that's the concrete next
  step before this becomes its own plan file.

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
  both are reproduced.
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
  else.
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
- [ ] TODO-25 (added 2026-09-24, same audit-triage wave, **low-medium
  confidence, not reproduced**; tracked as an open investigation, not a
  fix plan, in
  `bug_fix_plans/investigate_contin_ols_weighted_bootstrap_se.md`;
  the later TODO-28 cache hypothesis was closed as stale on 2026-10-07,
  so the root cause here remains open):
  `InferenceContinOLS` — one of the most fundamental classes in the
  package — shows severe `model_formula=~.`-specific miscalibration
  across resampling-family methods that reweight rather than permute
  (`subsampling` reject=0.19 vs nominal 0.05, `m_out_of_n_bootstrap`
  reject=0.16, several `bayesian_bootstrap` variants reject=0.13,
  `rand_bootstrap` reject=0.14; coverage as low as 0.80 on
  `bayesian_bootstrap`-family CIs). Confirmed NOT related to `TODO-15`
  (`InferenceContinLin`, different method-family group entirely — no
  overlap) or `TODO-3` (different code path). Candidate mechanism,
  unconfirmed by reproduction: `compute_estimate_with_bootstrap_weights()`
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
  higher-leverage than four separate per-class fixes.
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
  Root cause not yet pinned to a line — hypothesized as a leave-one-out
  fold landing on a degenerate/non-identifiable configuration (small
  matched-cluster counts + one held-out observation), a numerical-
  robustness gap analogous in shape (different location) to `TODO-4`'s
  unguarded-information-inverse pattern: an unstable fit silently
  producing a wild-but-finite number instead of failing loudly. Also a
  clean real-data validation of this session's `biased_estimate` check
  redesign (t-test alone would miss this — p=0.47 — Wilcoxon signed-rank
  catches it, p=5.7e-11 — exactly the outlier-robustness gap discussed
  when the check was designed). Independent of every other item in this
  release; depends on nothing else.
- [ ] TODO-27 (added 2026-09-24, same audit-triage wave, **medium
  confidence, not yet root-caused, plan file now written**):
  `InferenceIncidBinomialIdentityRiskDiff` shows real, moderate Type-I
  error inflation (~2.6× nominal, reject rate ~0.13) specifically on
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
  the one clear exception worth a dedicated look — not yet investigated
  beyond confirming the pattern is real and consistent.

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
- [ ] TODO-29 (added 2026-09-24, found via a dedicated cross-class
  investigation fork — medium-low confidence, pattern confirmed real and
  response-type-independent but mechanism unconfirmed): `InferenceAllSimpleAverageDiff`'s
  `bayesian_bootstrap_studentized`/`jackknife_wald` families are
  consistently the worst-covering across all 5 response types this class
  supports, while other families are fine — `../bug_fix_plans/investigate_average_diff_bayesian_jackknife_se_quality.md`.
  **Not TODO-28** — this class builds no design matrix in this path,
  confirmed a distinct mechanism. Candidate cause (unconfirmed, not yet
  traced to an exact line): a Kish effective-sample-size approximation
  used asymmetrically vs. the raw-`n` Welch SE formula elsewhere in the
  same class. `jackknife_wald`'s involvement is entirely unexplained —
  may share a cause with the Bayesian-bootstrap finding or be a separate,
  co-occurring bug. Independent of TODO-28 and everything else in this
  release.

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
- [ ] TODO-51 (added 2026-09-24 as TODO-32, renumbered 2026-09-24 for the
  same collision as TODO-50 above): promoted from a one-line dead-code aside
  inside TODO-4's prose, same reason as TODO-50 — user flagged that un-homed
  findings risk getting lost; trivial, no plan file needed): **dead code in
  `_helper_functions_core.h`** — `set_min_eigenvalue_if_suspect()`
  (`:210-219`) is entirely commented out, so `min_eigenvalue_information` is
  never populated by any caller. Found while checking `InferenceCountPoisson`
  against TODO-4's unguarded-information-inverse bug (unrelated — there was
  no live caller to implicate either way). Fix is either delete the dead
  function and the now-unused `min_eigenvalue_information` field, or
  actually wire it in if it was meant to be live — a decision, not
  investigation work; not yet decided.
- [ ] TODO-52 (added 2026-09-24, promoted from asides inside
  `bootstrap_worker_stale_design_matrix.md`'s (TODO-28) cross-class sweep,
  same reason and same pattern as TODO-50/51 — user asked for a double-check
  sweep of this file for orphans and buried secrets; tracked as an open
  investigation, not a fix plan, in
  `bug_fix_plans/investigate_beta_ols_kkglmm_low_coverage_orphans.md`):
  **six classes show real, audit-flagged `low_coverage`/unexplained
  findings, each checked only against the stale-`cached_design_matrix`
  bug and confirmed not to share it, with no other investigation opened**
  — `InferencePropBetaRegr`, `InferencePropZeroOneInflatedBetaRegr`,
  `InferenceContinKKOLSOneLik`, `InferenceContinKKRobustRegrOneLik`,
  `InferencePropKKGLMM`, `InferenceIncidKKCondLogitGLMMIVWC`/
  `InferenceIncidKKCondLogitGLMMOneLik` (grouped as one finding, all three
  inherit `InferenceAbstractKKCondLogitGLMM`). Lower-priority, not-yet-
  confirmed-real addendum: the 7-class KKGLMM/KKCLMM cluster was also ruled
  out from TODO-28's mechanism, but it's not yet confirmed whether that
  cluster even has real audit-flagged findings — check that first.

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
- [x] TODO-32 (added 2026-09-24, fixed 2026-10-08): **`InferenceOrdinalRidit(
  reference = "treatment")` now uses a non-degenerate symmetric estimand** —
  `../bug_fix_plans/ridit_treatment_reference_degenerate_estimate.md →
  TODO-1..5`. Treatment reference now reports
  `0.5 - mean_control_ridit` with the control-score SE. This is algebraically
  the same empirical Mann–Whitney contrast as the control-reference path and
  preserves the positive-treatment orientation; control and pooled behavior
  remain unchanged. The R class, weighted and resampling hooks, native R and
  Python kernels, docs, tests, NEWS and performance plan are aligned. Eighty-
  three focused R assertions pass without compilation. Python sources parse;
  binary Python validation remains part of the next permitted build/install.
- [ ] TODO-33 (added 2026-09-24, core fix and regression added 2026-10-07; real-data validation still open): **Randomization-CI
  high-precision refinement ignores `lower`** —
  `../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md →
  TODO-1..4`. Previously, `high_precision_confirm_and_refine_ci_bound()` set
  `u2 <- m` on acceptance, right for a lower bound and wrong for an upper
  bound. The loop now branches by bound direction, and a controlled public-API
  regression exercises both directions. Real-data reproduction of the inner
  loop and a standard coverage simulation remain open in the linked plan.
- [x] TODO-34 (added 2026-09-24, same audit; fixed 2026-10-07): **Interval-censored `compute_shared_icen()` blanket cache guard**
  — `../bug_fix_plans/interval_censored_compute_shared_cache_guard.md →
  TODO-1..4`. After `compute_estimate(estimate_only = TRUE)`, a later full
  call on `InferenceSurvivalLogRank`/`GehanWilcox` under general censoring
  never computes `s_beta_hat_T`, and `compute_asymp_confidence_interval()`
  crashes. Fixed for both classes; focused ordering and interval-reference tests pass without compilation. Same family as the stale-cache fixes.
- [x] TODO-35 (added 2026-09-24, fixed 2026-10-07): **`delta = NA` crash in the incidence g-computation risk ratio** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-1`. Added `any.missing = FALSE` to ordinary and KK g-computation p-values and the same vulnerable Newcombe risk-difference p-value. Focused regression tests pass without compilation.

- [x] TODO-36 (added 2026-09-24, fixed 2026-10-07): **Exact-test classes cannot use the shared weighted estimate** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-2`. Exact-only classes now report a clear unsupported error for bootstrap-weighted estimation; the dead helper calls and six wiring exceptions were removed. Focused exact-class and wiring tests pass without compilation.

- [x] TODO-37 (added 2026-09-24, fixed 2026-10-07): **`inference_class_accepts_model_formula()` is always FALSE** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-3`. The predicate now inspects the effective R6 initializer, including inherited and lazy component methods. `run_all_inference_build_tasks()` now expands requested formulas for eligible classes; the focused regression test passes without compilation.

- [ ] TODO-38 (added 2026-09-24, test-comment audit; **reproduced 2026-09-24 under valgrind: heap overflow from an unvalidated `warm_start_params` length**, see plan TODO-4; **ZOIB kernel length checks implemented and verified 2026-09-24**, sibling-kernel sweep of 9 other unchecked warm-start sites still open): **Fresh-process crash in `fast_zero_one_inflated_beta_cpp()`** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-4`. In a fresh Rscript the kernel returned `neg_loglik = NaN` and `coefficients = NULL` on ordinary data (8/8 seeds) but not inside testthat, suggesting undefined behavior in the C++ kernel; the R-level guard was fixed, the kernel was not. Check whether `InferencePropZeroOneInflatedBetaRegr` can hit it; run under the ASan/valgrind CI jobs.

- [x] TODO-39 (added 2026-09-24, fixed 2026-10-07): **Oversized greedy optimal block from multiple leftovers** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-5`. The fallback did see leftover subjects, but could assign several to one block (`n = 8`, `B = 3` yielded sizes `4,2,2`). It now chooses the nearest block below `ceiling(n / B)`, yielding `3,3,2`; focused allocation and randomization-inference tests pass without compilation.

- [x] TODO-40 (added 2026-09-24, fixed 2026-10-07): **Zero-length estimate instead of `NA` on sparse weights** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-6`. The incidence risk-difference weighted refit now retains the treatment column or returns scalar `NA_real_` with a typed nonestimable reason. Sparse and ordinary weighted-refit tests pass without compilation.

- [ ] TODO-41 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Unchecked callback result in the randomization loop** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-7`. `result[0]` on a length-0 vector is read without a length check; Rcpp only warns and the loop continues, leaving the entry undefined instead of failing.

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

- [ ] TODO-47 (added 2026-09-24, found via a dedicated cross-class
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
  logistic-MLE bias).
- [ ] TODO-48 (added 2026-09-24, same source — medium-low confidence,
  root cause genuinely unresolved): the count-family GLM `low_coverage`
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
  bug).
- [ ] TODO-49 (added 2026-09-24, same source — medium confidence, root
  cause open): `InferenceContinQuantileRegr`'s 33 `low_coverage`
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
  methods specifically.

- [ ] TODO-53 (added 2026-09-24, from triaging the stale-cache regeneration
  findings; reproduced from scratch, mechanism unknown): **Randomization
  p-values are conservative at the null under
  `DesignSeqOneByOneKK21stepwise` (incidence)** —
  `../bug_fix_plans/investigate_kk21stepwise_incidence_randomization_pval_conservative.md →
  TODO-1..4`. 60 simulated nulls: 0 rejections, median p 0.71, mean p 0.66;
  `InferenceAllSimpleAverageDiff` gives identical p-values, so it is shared
  design-replay/randomization machinery, not the g-computation class. Costs
  power (0.183 vs 0.317 for the Wald test at `beta_T = 0.5`); not a validity
  failure.

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
  The closed form now matches the clamped-baseline logit DGP, and the audit
  also gave proportion Wilcox a response-qualified Monte Carlo truth.
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
  Independent of
  `mc_coverage_truth_covariate_mismatch.md`'s TODO-6/TODO-11 — different
  mechanism (closed-form path, not Monte-Carlo), different classes, do not
  conflate when resolving either.
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
- [ ] TODO-57 (added 2026-10-07, user decision; moved here from
  `release_v1_1_0.md → TODO-39` the same day): **Bayesian bootstrap
  performance: parallel scaling and native weighted refits** —
  `../bug_fix_plans/bayesian_bootstrap_performance.md → TODO-1..9`.

  A `bayesboot` comparison at n = 500, B = 1000 found two problems.
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
  Acceptance: all three rows ≥ 1x `boot`. Otherwise independent of every
  other item here and of v1.1.0.

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
  per-arrival cost flat in t and ≤ 0.5 ms; whole sequence within 10x of
  `carat`. See TODO-59 for the shared builder.

- [ ] TODO-61 (added 2026-10-07, user decision): **Binary matching hands
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

- [ ] TODO-64 (added 2026-10-07, filed on the model's initiative under the
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

- [ ] TODO-65 (added 2026-10-08, user decision): **KK21 ordinal weight
  kernels: unprotected `wrap()` temporaries in the only R callback in
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

- [ ] TODO-66 (added 2026-10-08, found while rewriting a stale test):
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

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: default behavior with
no new switches set must reproduce 1.0.0 results bit-for-bit, except where
a TODO above explicitly documents a default change (TODO-2, TODO-3,
TODO-56, TODO-57's native weighted refits — its owning plan's TODO-6
(and TODO-8 if pursued), TODO-58's direct model-matrix subsetting (its
plan's TODO-3, tolerance-equal with a bit-preserving rebuild fallback),
TODO-61's unsquared matching objective (its plan's TODO-2,
decision-gated, off until the user accepts it), and TODO-64's Poisson
kernel only if its plan's TODO-3 chooses to write it rather than delete
the dead method (tolerance-equal); all document their equivalence
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
decision were completed during this audit. The ten
entries still checked are TODO-22, TODO-28, TODO-30, TODO-34, TODO-35,
TODO-36, TODO-37, TODO-39, TODO-40, and TODO-44; their item-specific
checklists have no unfinished work. Superseded TODO-28 checklist items are
closed with explicit dispositions in its plan rather than left as apparent
subtasks.
