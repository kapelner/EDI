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
  `InferencePropZeroOneInflatedBetaRegr`** — `fix_reusable_bootstrap.md →
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
  information-matrix inverses** — `guard_unguarded_information_inverse.md
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
  optimizer stability** — `clayton_loggamma_frailty_optimizer_stability.md
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
  randomization CI** — `fix_KKQuantileRegrOneLik_rand_ci.md → TODO-1..6`.
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
  likelihood** — `fix_multimodal_log_liks.md → TODO-1..8`. The 2026-09-21
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
  in reused-worker resampling** — `fix_stale_worker_cache_resampling.md →
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
  `fix_mc_coverage_truth_covariate_mismatch.md → TODO-1..6`. **Fixed.**
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
  `fix_stale_worker_cache_resampling.md → TODO-9`. One level up from the
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
  production** — `fix_prop_gcomp_sample_usable_gating.md → TODO-1..6`.
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
  `fix_glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md → TODO-1..7`.
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
  separate and still unfixed): **`InferenceContinLin` parametric-bootstrap
  / likelihood-ratio methods have inflated Type-I error, design-dependent**
  — `fix_contin_lin_param_bootstrap_bad_type1_error.md → TODO-1..7`. Three
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
  `fix_ordinal_cumulative_link_null_refit_multistart.md → TODO-1..7`.
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
  `fix_simple_wilcox_hl_degenerate_pval_boundary.md → TODO-1..7`. A
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
- [ ] TODO-18 (added 2026-09-23, surfaced by the new `pval_miscalibration`
  audit check — one function_run variant appeared across ~85 distinct
  (class, response_type) cells with wildly inconsistent miscalibration
  direction/severity, itself the tell that this is shared machinery
  breaking differently depending on data shape, not 85 per-class bugs;
  root-caused same day): **`smoothed` randomization-bootstrap p-value adds
  unclamped continuous noise to binary/ordinal responses** —
  `fix_rand_bootstrap_smoothed_noise_unclamped.md → TODO-1..8`. Confirmed
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
  confirm — **medium confidence, needs more work before its own plan
  file**): possible over-estimated standard error causing chronic
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
  multi-rep calibration repro (medium confidence). No plan file written
  yet; whoever picks this up should write one once the empirical-SD-vs-
  reported-SE check confirms the hypothesis for at least one class (or
  finds the real cause), and should treat this as a potential
  cross-class SE-quality audit, not a single-class fix.

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
  reproduced): `InferenceContinQuantileRegr` shows CONSISTENT-direction
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
  reproduced**): `InferenceIncidKKGEE` shows the same consistent-direction
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
  taken on the fix author's own before/after numbers). **Open follow-up,
  not yet done by anyone**: whether any *other* class shares "the
  identical buggy snippet" — the fix was applied to the three classes
  found so far, not from an exhaustive `grep`-and-check sweep of every
  survival class's `compute_treatment_estimate_during_randomization_inference()`
  override; that sweep is still needed before this can be considered fully
  closed.

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
