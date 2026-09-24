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
- [ ] TODO-4 (added 2026-08-30, user decision): **Guard the unguarded
  information-matrix inverses** — `../bug_fix_plans/guard_unguarded_information_inverse.md
  → TODO-1..5`. Correctness, not performance. `fast_negbin_regression.cpp:485`
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
  Plan's own checklist: 0/5 checked.

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
- [ ] TODO-11 (added 2026-09-22, user-requested investigation of a prior
  fix's explicit out-of-scope note; **resolved — do not enable**): **Cox
  Bartlett-approx likelihood-ratio correction, forced off** —
  `enable_cox_bartlett_approx.md`. A 300+300-rep validation of the
  currently-forced-off Bartlett-approx path on `InferenceSurvivalCoxPHRegr`
  (`n=100`, `B=49`, ~1.4h runtime) showed no improvement over plain Wald
  (Type-I error 0.077 vs. Wald's 0.057, nominal 0.05; CI coverage 0.937 vs.
  Wald's 0.947, nominal 0.95) — mild over-rejection/under-coverage if
  anything. **Decision: leave both Cox classes' explicit `FALSE` as they
  are.** Revisiting would need its own budgeted multi-scenario/multi-class
  simulation (each such run costs over an hour), not something to do
  speculatively.
- [ ] TODO-12 (added 2026-09-22, found during TODO-9's own final review,
  not a new audit finding; no concrete class reaches it yet): **Latent
  `cached_mod` reset gap, same bug shape as TODO-9** —
  `../bug_fix_plans/stale_worker_cache_resampling.md → TODO-9`. One level up from the
  `cached_values` gap TODO-9 fixed, the same randomization loader still
  resets a hand-maintained private-field allowlist that's missing
  `cached_mod` — the identical failure shape, just one field over.
  Confirmed a landmine, not a live defect (every concrete class writes
  `cached_mod` unconditionally rather than reading it stale; TODO-9's
  240-class non-degeneracy sweep found no additional degenerate class).
  Fix: reconcile the three separately-maintained private-field reset lists
  into one keep-list-driven reset the same way TODO-9 reconciled
  `cached_values`.
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
  separate and still unfixed; **see also TODO-28**, added 2026-09-24 — a
  confirmed shared `cached_design_matrix` staleness bug affecting this
  class's `compute_estimate_with_bootstrap_weights()` path, but NOT
  confirmed to be the same code path as the parametric-bootstrap/
  likelihood-ratio methods this TODO documents below, which route through
  the separate `ParametricLikelihoodBootstrap` component — treat as a
  second, possibly-unrelated finding for this same class until TODO-28's
  own TODO-8 verifies the overlap, not an explanation of this TODO's
  finding): **`InferenceContinLin` parametric-bootstrap
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
  `../bug_fix_plans/ordinal_cumulative_link_null_refit_multistart.md → TODO-1..12`
  (now including **TODO-12**, added 2026-09-24: `InferenceOrdinalContRatioRegr`'s
  `fit_null` is still single-start — the exact same unfixed Bug-1
  vulnerability, found by direct code comparison; high confidence, not yet
  reproduced — candidate explanation for this class's own 9-family
  `pval_miscalibration` audit finding).
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
  still open (plan's TODO-2b).
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
  `../bug_fix_plans/rand_bootstrap_smoothed_noise_unclamped.md → TODO-1..8`. Confirmed
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
  re-verified by this file's own investigation (no fresh repro run here —
  taken on the fix author's own before/after numbers).

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
- [ ] TODO-24 (added 2026-09-24, same audit-triage wave, root-caused
  same day, medium-high confidence for one sub-class, low for the other):
  **KK-matched Cox proportional-hazards classes — severe CI undercoverage,
  isolated to the KK-matching/reservoir-split mechanism** —
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
  C++ cluster-robust vcov kernel read directly. Independent of every other
  item in this release; depends on nothing else.
- [ ] TODO-25 (added 2026-09-24, same audit-triage wave, **low-medium
  confidence, not reproduced**; tracked as an open investigation, not a
  fix plan, in
  `bug_fix_plans/investigate_contin_ols_weighted_bootstrap_se.md`;
  **superseded/explained by `TODO-28`, added the same day** — a confirmed,
  high-confidence shared `cached_design_matrix` staleness bug with an
  EXACT mechanistic match to this class's worst-affected families —
  this TODO's own `solve()`-guard hypothesis below is likely NOT the real
  cause; see TODO-28 first):
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
- [ ] TODO-28 (added 2026-09-24, found via a dedicated cross-class
  investigation into TODO-15/TODO-25's shared-mechanism question — **high
  confidence, confirmed by direct code reading, not hypothesized**): **the
  reused bootstrap worker never resets `cached_design_matrix` — likely
  the single shared root cause behind FOUR classes' `~.`-specific
  miscalibration at once** — `../bug_fix_plans/bootstrap_worker_stale_design_matrix.md
  → TODO-1..9`. `load_bootstrap_sample_into_design_backed_worker()`
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
  denylist shape as this session's original bug and as the still-open
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
  total confirmed scope now the original 4 + these 4 = 8 classes. **The
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

- [ ] TODO-30 (added 2026-09-24, user decision: slotted into v1.0.5 from
  "unassigned"; found 2026-08-30 in the research-plan verification audit):
  **Cox risk-set cache staleness guard** —
  `../bug_fix_plans/cox_risk_set_cache_staleness.md → TODO-1..5`.
  `InferenceCoxPH` (`cox_*` caches) and `InferenceStratifiedCoxPH`
  (`strat_cox_*` caches) rebuild their prebuilt risk-set cache only when
  the cache is `NULL` or `w` changed, while the cache also embeds
  `y`/`dead`; a change to `y`/`dead` with unchanged `w` would serve a stale
  cache. The C++ builders are correct; the R-side cache owners must honor
  the invalidation contract at `helper_glm_fit.R:2274`. **No confirmed
  wrong result yet** — plan TODO-1 (exposure audit) determines whether any
  released path can realize the stale hit; the invariant violation is real
  and cheap to close (guard fix in both classes, same-pattern sweep of
  other `*_w_cache` guards, tests, contract doc touch-up). Plan's own
  checklist: 0/5 checked.
- [ ] TODO-31 (added 2026-09-24, promoted from asides inside TODO-4's and
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
- [ ] TODO-32 (added 2026-09-24, promoted from a one-line dead-code aside
  inside TODO-4's prose, same reason as TODO-31 — user flagged that un-homed
  findings risk getting lost; trivial, no plan file needed): **dead code in
  `_helper_functions_core.h`** — `set_min_eigenvalue_if_suspect()`
  (`:210-219`) is entirely commented out, so `min_eigenvalue_information` is
  never populated by any caller. Found while checking `InferenceCountPoisson`
  against TODO-4's unguarded-information-inverse bug (unrelated — there was
  no live caller to implicate either way). Fix is either delete the dead
  function and the now-unused `min_eigenvalue_information` field, or
  actually wire it in if it was meant to be live — a decision, not
  investigation work; not yet decided.

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
- [ ] TODO-32 (added 2026-09-24, same audit; pinned test): **`InferenceOrdinalRidit(
  reference = "treatment")` reports estimate 0 and `p = 1` always** —
  `../bug_fix_plans/ridit_treatment_reference_degenerate_estimate.md →
  TODO-1..5`. The treated group's mean ridit is `0.5` by construction, so
  `mean_ridit_t - 0.5` is identically zero while the SE is positive. Needs a
  semantics decision (redefine, refuse, or document) before the ridit
  performance plan builds on this path.
- [ ] TODO-33 (added 2026-09-24, same audit; pinned test): **Randomization-CI
  high-precision refinement ignores `lower`** —
  `../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md →
  TODO-1..4`. `high_precision_confirm_and_refine_ci_bound()` always sets
  `u2 <- m` on acceptance, right for a lower bound and wrong for an upper
  bound, which then converges to the wrong end of its bracket. Real-path
  reach not yet established.
- [ ] TODO-34 (added 2026-09-24, same audit; "confirmed source bug, NOT
  fixed"): **Interval-censored `compute_shared_icen()` blanket cache guard**
  — `../bug_fix_plans/interval_censored_compute_shared_cache_guard.md →
  TODO-1..4`. After `compute_estimate(estimate_only = TRUE)`, a later full
  call on `InferenceSurvivalLogRank`/`GehanWilcox` under general censoring
  never computes `s_beta_hat_T`, and `compute_asymp_confidence_interval()`
  crashes. Same family as the stale-cache fixes.
- [ ] TODO-35 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **`delta = NA` crash in the incidence g-computation risk ratio** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-1`. `InferenceIncidGCompRiskRatio`'s asymptotic/Wald p-value: `assertNumeric(delta, len = 1)` lets `NA` through, then `if (delta <= 0)` errors with "missing value where TRUE/FALSE needed" instead of the intended validation message. Fix with `any.missing = FALSE` and sweep the same pattern across all p-value methods.

- [ ] TODO-36 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Exact-test classes cannot use the shared weighted estimate** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-2`. `ExactTestSource$compute_estimate_with_bootstrap_weights()` needs `expand_subject_or_block_weights_to_row_weights()`, which only the BayesianBootstrap component provides, so it errors on the exact Fisher class. Decide: unsupported (clear reason) or supported.

- [ ] TODO-37 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **`inference_class_accepts_model_formula()` is always FALSE** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-3`. It inspects `formals(<R6 generator>$new)`, which is just `...`, so it is FALSE for every class. Find its callers and what they do with the wrong answer.

- [ ] TODO-38 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Fresh-process crash in `fast_zero_one_inflated_beta_cpp()`** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-4`. In a fresh Rscript the kernel returned `neg_loglik = NaN` and `coefficients = NULL` on ordinary data (8/8 seeds) but not inside testthat, suggesting undefined behavior in the C++ kernel; the R-level guard was fixed, the kernel was not. Check whether `InferencePropZeroOneInflatedBetaRegr` can hit it; run under the ASan/valgrind CI jobs.

- [ ] TODO-39 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Trailing incomplete block in one optimal-blocks design path** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-5`. `DesignFixedOptimalBlocks` (greedy/blockTools path) with `n` not a multiple of `B` leaves a trailing incomplete block that its own nearest-neighbour fallback never sees. Effect on balance and on block-assuming inference unknown.

- [ ] TODO-40 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Zero-length estimate instead of `NA` on sparse weights** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-6`. In the incidence risk-difference weighted refit with only two positive-weight rows, the hardened retry drops the treatment column and `which(attempt$keep == 2L)` is `integer(0)`, so the cached estimate is a zero-length numeric instead of `NA_real_`.

- [ ] TODO-41 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Unchecked callback result in the randomization loop** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-7`. `result[0]` on a length-0 vector is read without a length check; Rcpp only warns and the loop continues, leaving the entry undefined instead of failing.

- [ ] TODO-42 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Is the stale Bayesian-bootstrap worker workaround still needed?** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-8`. `test-cox-component-composition.R` uses a fresh object per capability to avoid a stale Bayesian-bootstrap worker context after a randomization or bootstrap call (also on `InferenceSurvivalKMDiff`). The stale-worker fix may have resolved it: remove the workaround and either delete the comment or plan a fix.

- [ ] TODO-43 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **RNG-state sensitivity in the IVWC frailty optimizer** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-9`. `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`: a freshly constructed `compute_estimate(estimate_only = TRUE)` reproducibly returns `NA` on the test fixture while the identical fit via the constant-weights shortcut converges. Suggests a start-value or seeding dependence.

- [ ] TODO-44 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Silent `NA` results with no recorded reason** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-10`. Jackknife summary with fewer than 2 replicates returns all-`NA` with no reason; subsampling and m-out-of-n b/m-list selection failures cache a reason only under `harden = TRUE`. Give them typed nonestimable reasons (feeds the v1.1.0 diagnostics plans).

- [ ] TODO-45 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Weighted-refit SEs never populated** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-11`. The Weibull fast surrogate, `InferenceIncidKKModifiedPoisson` and the modified-Poisson class return `NA` from the base `weighted_refit_se()` even with `estimate_only = FALSE`, contradicting a `@param` that implies a variance is computed. Implement the SE or correct the docs.

- [ ] TODO-46 (added 2026-09-24, test-comment audit; pinned by a test, not independently reproduced): **Cosmetic / minor list** — `../bug_fix_plans/test_comment_audit_small_defects.md → TODO-12`. Dead "Continuous covariates are not allowed for stratification" `stop()` in `add_one_subject()`; `extract_dollar_paths()` also returns nested sub-chains; `fast_weibull_regression(use_rcpp = FALSE)` ignores `estimate_only`; `with_var` kernel field sets differ across families. Record each as fix / document / accept.

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
  truth-mismatch for `LogRegr` specifically (same family as `TODO-32`'s
  fix), or (2) ordinary benign Wald/LR-type CI conservativeness for
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
  `InferenceAllSimpleMeanDiffPooledVar`'s prior coverage bug and `TODO-32`'s
  fix — but in tension with the fact that nonparametric resampling
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

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: default behavior with
no new switches set must reproduce 1.0.0 results bit-for-bit, except where
a TODO above explicitly documents a default change (TODO-2, TODO-3 — both
document their equivalence tolerance). No `R CMD INSTALL`/rebuild of
`R/EDI` without being asked in that turn (see top-level `CLAUDE.md`);
verify any `.cpp`-adjacent change via targeted compile only, never a full
build.

**Verification pass, 2026-09-24** (checked against the installed package
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
