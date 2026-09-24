# Release Scope: v1.5.0 — Statistical-Calibration Findings from the New Audit Infrastructure

> **Depends on:** `release_v1_4_0.md`. Inserted 2026-09-24 (user decision)
> between `release_v1_4_0.md` and `release_v2_0_0.md` — see note below on
> the pre-existing "v1.4.0 is the last 1.x release before 2.0.0" framing
> this supersedes. Release index over plans in `../bug_fix_plans/`; not
> new work of its own. (Global ordering: see
> `../new_feature_plans/_master.md`.)

**Note on numbering:** `release_v1_4_0.md`'s own header describes itself
as "Last 1.x release before 2.0.0," and `release_v2_0_0.md`'s header
states its dependency as "`release_v1_4_0.md` (the last 1.x release;
ships first)." This file's existence contradicts both of those framings
— it was created 2026-09-24 at the user's explicit direction, to give the
new `audit_comprehensive_results.R` `low_coverage`/`biased_estimate`
checks' confirmed findings a dedicated home distinct from
`release_v1_0_5.md` (hardening/correctness fixes already in flight) and
distinct from `release_v1_1_0.md` (inference-quality machinery). Whoever
next touches `release_v1_4_0.md` or `release_v2_0_0.md` should update
their headers to acknowledge this file sits between them, rather than
leaving the contradiction in place.

**Theme.** Confirmed real statistical-calibration bugs (miscalibrated
p-values, wrong CI coverage, biased point estimates) surfaced by this
session's `audit_comprehensive_results.R` expansion (four FDR-controlled
checks: `pval_miscalibration`, `low_power`, `low_coverage`,
`biased_estimate`, combined per-cell via the Cauchy combination test).
**Only findings confirmed as genuine bugs land here** — findings that
turn out to be benign (e.g. ordinary conservative-CI behavior, a harness
truth-registry gap rather than a package defect) are documented in their
investigation plan file and closed there, not added to this release.
Findings still under investigation, not yet confirmed either way, stay
tracked in `release_v1_0_5.md`'s TODO list (where this audit work began)
until resolved one way or the other, then move here or get closed.

## In scope (by plan)

(Populated as investigations confirm real bugs — see
`release_v1_0_5.md`'s TODO-28/29/47/48/49 and their linked
`../bug_fix_plans/investigate_*`/`fix_*` files for the investigation
threads feeding this release.)

- [ ] TODO-1 (added 2026-09-24, confirmed by direct reproduction —
  high confidence): `InferenceAllSimpleWilcox`'s resampling-family
  p-values AND CIs collapse/narrow to a degenerate state on tied,
  small-integer data — `../bug_fix_plans/simple_wilcox_hl_degenerate_pval_boundary.md
  → TODO-1..7`. The Hodges-Lehmann point estimate lands exactly on 0 on
  heavily-tied data; `compute_rand_two_sided_pval`'s boundary-collapse
  formula then saturates to `p=1`, and the same with-replacement
  resampling of tied data (`approximate_bootstrap_distribution_beta_hat_T()`)
  piles `boot_distr` up near 0, producing over-narrow, mis-centered CIs
  via `bootstrap_ci_from_distribution()`'s `"basic"` formula. Confirmed
  by direct reproduction (25 true-null reps: 80% land at `beta_hat_T==0`,
  100% of those give `p=1` exactly) and cross-validated 2026-09-24
  against a fresh full-package audit run (bootstrap-family CIs show
  0.84-0.93 coverage vs. 0.95 target, same direction/mechanism, ~18-20 of
  22 new Wilcox findings explained). Proposed fix: mid-p/tie-splitting
  correction to the generic randomization/bootstrap p-value formula
  (`inference_all_abstract_rand.R:317` and bootstrap-family equivalents)
  — likely belongs in shared machinery, protecting any other tie-prone
  class, not just this one (TODO-2 of the linked plan determines scope).
  **Not yet implemented.**
- [ ] TODO-2 (added 2026-09-24, confirmed by live introspection — high
  confidence): `InferenceAllSimpleMeanDiffPooledVar`'s
  `compute_estimate_with_bootstrap_weights()` silently uses
  `InferenceAllSimpleAverageDiff`'s Welch (unequal-variance) formula
  instead of its own documented pooled-variance formula, despite
  `overrides$public` declaring an override that doesn't actually exist
  (`inference_all_simple_mean_diff_pooled_var.R:203-225`) —
  `../bug_fix_plans/simple_wilcox_hl_degenerate_pval_boundary.md → TODO-8`.
  Asymptotic inference for this class correctly uses pooled variance;
  resampling-based inference silently doesn't, for the same nominally
  "pooled-variance" class. Confirmed via
  `InferenceAllSimpleMeanDiffPooledVar$public_methods$compute_estimate_with_bootstrap_weights`
  being bit-for-bit identical to `InferenceAllSimpleAverageDiff`'s.
  **Does NOT fully explain** the `compute_bayesian_bootstrap_confidence_interval_basic`/
  `_studentized` coverage findings that surfaced it (those CI types read
  `boot_distr`/`s_beta_hat_T` in ways not fully traced — `TODO-9` of the
  linked plan, still open) — fix this real defect regardless, but don't
  assume it closes the coverage finding. **Not yet implemented.**
- [ ] TODO-3 (added 2026-09-24, confirmed by direct code reading + a
  rigorous statistical variance argument, not yet empirically
  reproduced — high confidence): the KK matched-pair-and-reservoir
  bootstrap weight helper `kk_pair_and_reservoir_bootstrap_weights()`
  (`R/EDI/R/globals.R:245-269`) collapses two independently-drawn
  per-subject bootstrap weights into one pair weight via `mean()`,
  halving the effective resampling variance of matched-pair statistics
  and causing broad CI undercoverage (0.76-0.91 vs. 0.95 target) across
  `InferenceContinKKOLSOneLik`, `InferenceContinKKRobustRegrOneLik`, and
  `InferenceContinKKQuantileRegrOneLik` — `../bug_fix_plans/investigate_contin_kk_onelik_glmm_coverage.md`.
  The resampling unit implied by the weight generator
  (`design_obj$get_block_ids()`) is the *subject* for most tested
  designs, not the KK class's own post-hoc greedy-matched pair, so
  `Var(mean(w_i, w_j)) = Var(w)/2` for the pair's two independent draws —
  a real defect, not a benign approximation. Fix needs design thought
  (likely drawing weights at the pair/reservoir-unit level directly for
  KK matched designs, not patching the collapse formula alone) — see the
  linked plan's TODO-3. Possible wider blast radius: other callers of the
  same shared helper (`inference_mixin_kk_passthrough.R`,
  `inference_incidence_KK_cond_logit.R`,
  `inference_all_abstract_KK_passthrough_compound.R`) not yet checked.
  `InferenceContinKKGLMM`'s 3 findings are explicitly NOT explained by
  this mechanism (architecturally distinct — passes per-row weights
  directly into a weighted GLMM with the pair as a random-effect grouping
  factor, not weight-averaged) and remain a separate, lower-priority open
  investigation.

- [ ] TODO-4 (added 2026-09-24, found via direct code comparison against
  an already-fixed sibling bug — high confidence, not yet reproduced):
  **`InferenceOrdinalContRatioRegr`'s likelihood-ratio `fit_null` is still
  single-start** — the exact vulnerability already found and fixed for
  `InferenceOrdinalStereotypeLogitRegr` this session, never patched here
  — `../bug_fix_plans/ordinal_cumulative_link_null_refit_multistart.md →
  TODO-12`. `get_likelihood_test_spec()`'s `fit_null` closure
  (`inference_ordinal_stereotype_logit.R:748-762`) calls
  `fast_continuation_ratio_regression_cpp()` exactly once per delta from a
  single warm start, with no second-start fallback — the same
  delta-constrained-refit multimodality risk this plan already diagnosed
  and fixed for the Stereotype-logit sibling (`inference_ordinal_stereotype_logit.R:313-334`).
  Directly explains the candidate mechanism for this class's 9-family
  `pval_miscalibration` finding. Fix: apply the identical two-start-then-
  `which.min(neg_loglik)` pattern, reusing the already-in-scope
  `full_start` construction. **Not yet implemented.**

- [ ] TODO-5 (added 2026-09-24, confirmed by direct code reading — high
  confidence mechanism, magnitude/reproduction not yet empirically
  confirmed): **jackknife-Wald CI is centered at the raw point estimate,
  not the bias-corrected jackknife estimate, and the acceptance guard
  lets substantial uncorrected bias through** —
  `../bug_fix_plans/investigate_incid_logregr_probitregr_coverage.md →
  TODO-3/6`. `R/EDI/R/inference_all_abstract_jackknife.R`'s
  `compute_jackknife_wald_confidence_interval()` (`:118-145`) builds the
  CI as `theta_hat ± z*se_j`, where `theta_hat = self$compute_estimate()`
  (the raw, uncorrected estimate) but `se_j` comes from
  `compute_jackknife_summary()` (`:229-287`), whose variance is computed
  around the delete-1 mean `jack_bar`, not `theta_hat`. The bias-corrected
  jackknife estimate `theta_j = theta_hat - bias_j` is computed in the
  same function but never used to center the CI. The only guard
  (`abs(bias_j) > 2 * se_j`, `:278`) is loose enough to admit bias up to
  ~2 SE into a CI that is only `±1.96 se_j` wide at `alpha=0.05`. This is
  shared, generic machinery used by every class composing the
  `Jackknife` component (not class-specific), and directly explains
  `InferenceIncidProbitRegr ~1 compute_jackknife_wald_confidence_interval`'s
  under-coverage outlier (0.926 vs. 0.95 target) — plausibly also
  explains `TODO-29`'s (in `release_v1_0_5.md`) independent
  `jackknife_wald` finding for `InferenceAllSimpleAverageDiff`, since it's
  the same underlying code. Fix direction: center the CI at `theta_j`
  instead of `theta_hat`, or tighten the acceptance guard — pick after
  reproducing both affected classes' findings to confirm they share this
  mechanism (they may want different fixes if the bias magnitude differs
  qualitatively between them). **Not yet implemented.**

- [ ] TODO-6 (added 2026-09-24, confirmed by direct code reading — medium-high
  confidence, concrete and low-risk to fix): `InferenceCountPoisson`'s
  documented "design-conservative" equidispersion-robustness treatment
  (every asymptotic CI unioned with a design-based jackknife-Wald
  interval, per the class's own docstring at `inference_count_poisson.R:11-29`,
  implemented correctly via `private$design_conservative_ci()`,
  `:551-567` — verified this IS a mathematically valid enclosing interval
  that provably guarantees coverage ≥ both components') is **incompletely
  wired**: `compute_wald`/`asymp`/`score`/`gradient`/`lik_ratio_confidence_interval`
  all correctly use it and show clean coverage, but the Bartlett-corrected
  sibling of the last one — `compute_lik_ratio_bartlett_confidence_interval`/
  `compute_lik_ratio_bartlett_approx_confidence_interval` — does NOT, and
  shows the exact anti-conservative undercoverage (0.834-0.915) the union
  exists to prevent — `../bug_fix_plans/investigate_count_glm_family_coverage.md
  → TODO-5`. Fix: wire the Bartlett variants through the same
  `design_conservative_ci()` call the plain `lik_ratio` CI already uses —
  mechanical, matches an existing in-file pattern. **Separately flagged,
  not slated here:** whether to extend the same union to the
  resampling-family CI methods (`bayesian_bootstrap*`, `param_bootstrap`,
  `bootstrap_studentized`, also undercovering) is a design decision, not
  an obvious bug — see the linked plan's TODO-6. `InferenceCountNegBin`/
  `InferenceCountZeroInflatedPoisson`'s own undercoverage (no jackknife
  backstop exists for either) remains genuinely unresolved, tracked at
  `release_v1_0_5.md → TODO-48`, not promoted here.

- [ ] TODO-7 (added 2026-09-24, HIGH confidence, confirmed by direct
  code reading at 3 sites): `InferenceSurvivalRestrictedMeanDiff` computes
  restricted mean survival time (RMST) to a **different truncation
  horizon τ per arm** — `../bug_fix_plans/rmst_mismatched_truncation_horizon.md
  → TODO-1..7`. `weighted_survival_stat_for_group()`
  (`inference_survival_rmst.R:239`) and the two C++ functions
  (`fast_survival_stats.cpp:158`/`:290` for the point estimate, `:400`
  for the SE) each independently derive τ from `subjects.back().time`
  per arm instead of sharing one τ across both — a genuinely different
  estimand per arm, not a well-defined single-estimand comparison.
  Coverage as low as 0.47-0.65 across every asymptotic method family;
  bootstrap/resampling families are less severe (0.86-0.94) but still
  degraded. Cross-validated 2026-09-24 against a fresh full-package audit
  run (3 new `rand_bootstrap*` findings, 0.857-0.870, land squarely
  inside the historical range). Fix: shared τ (standard convention: min
  of both arms' max observed/censored time) at all 3 sites — this is an
  **intentional, documented default change** to the point estimate
  itself, not just its SE. Requires targeted C++ compile only, never a
  full rebuild. **Not yet implemented.**
- [ ] TODO-8 (added 2026-09-24, medium-high confidence, root cause
  hypothesized not yet pinned to an exact line): `InferenceSurvivalKKStratCoxPHOneLik`
  and `InferenceSurvivalKKLWACoxPHOneLik` show severe, broad CI
  undercoverage (0.47-0.94, varying by method family) across 6+ unrelated
  CI-construction families, isolated to the KK-matching/reservoir-split
  mechanism specifically (plain, non-KK-matched Cox siblings are fine) —
  `../bug_fix_plans/survival_kk_cox_coverage_variance.md`. For
  `KKStratCoxPHOneLik`: medium-high confidence, an independence-violation
  hypothesis in `w_star` inverse-variance pooling
  (`inference_survival_KK_strat_cox.R:176-265`). For `KKLWACoxPHOneLik`:
  root cause not yet found (different, textbook-correct-looking
  cluster-robust joint fit). Worst-affected families directly consume the
  class's own reported `s_beta_hat_T` (Wald/score/gradient/LR), while
  resampling-based families are better but still degraded — consistent
  with an underestimated variance formula only partially self-corrected
  by resampling. Cross-validated 2026-09-24 against a fresh full-package
  audit run — new findings for both classes land inside the ranges
  already documented here; no new information, still blocked on further
  root-causing. **Note**: this may substantially overlap with
  `mc_coverage_truth_covariate_mismatch.md`'s separately-confirmed
  truth-scale-mismatch bug for the SAME two classes (both are on that
  plan's 14-class confirmed list) — that plan's fix is blocked on its own
  TODO-6 (MC truth doesn't converge for KK-matched/high-covariate-count
  classes). Whether this variance-pooling bug and the truth-mismatch bug
  are two independent, compounding causes of the same undercoverage
  symptom, or whether one fully explains it once fixed, is not yet
  determined — resolve `mc_coverage_truth_covariate_mismatch.md`'s TODO-6
  first, since it's closer to being actionable. **Not yet implemented.**
- [ ] TODO-9 (added 2026-09-24, high confidence for the root cause,
  fix direction undecided): `comprehensive_tests.R`'s Monte-Carlo
  coverage-truth machinery uses the wrong covariate adjustment set for
  every class in `COVERAGE_MC_SPEC` (~25 classes) whose per-row test uses
  `design_formula = ~.` over a real multi-column dataset — the harness's
  default — `../bug_fix_plans/mc_coverage_truth_covariate_mismatch.md`.
  The MC truth fits against one synthetic covariate; the real per-row
  test uses the real dataset's full covariate matrix, so for
  non-collapsible link-scale classes (Cox, logit/probit, GLMM/GEE) the
  two are different estimands entirely (omitted-variable
  attenuation/non-collapsibility). 14 classes confirmed by the
  "clean at `beta_T=0`, collapses at `beta_T≠0`, uniform across every CI
  method at once" signature (see plan for full list — includes
  `InferenceSurvivalKKStratCoxPHOneLik`, `InferenceSurvivalKKLWACoxPHOneLik`,
  `InferenceSurvivalKMDiff`, `InferenceSurvivalStratCoxPHRegr`,
  `InferenceSurvivalGehanWilcox`, `InferenceSurvivalLogRank`, several
  ordinal/proportion classes). Cross-validated 2026-09-24 against a fresh
  full-package audit run — new findings for `KKStratCoxPHOneLik`/
  `KKLWACoxPHOneLik`/`KMDiff` all confirm this plan's existing numbers,
  no new information. **This is a test-harness bug, not a package bug**
  — the fix lives in `comprehensive_tests.R`, not `R/EDI`. Blocked on
  TODO-6 in the linked plan (the real-covariate MC truth doesn't converge
  for KK-matched/high-covariate-count classes specifically — needs a
  convergence check, a covariate cap, or Firth-type bias correction
  first). **Not yet implemented**, and per the linked plan's own
  recommendation, should NOT ship for the KK-matched high-covariate
  classes until TODO-6 resolves, even once implemented for the other 12.
- [ ] TODO-10 (added 2026-09-24, HIGH confidence, independently
  corroborated twice): `InferenceSurvivalKKWeibullMarginal`'s
  `compute_jackknife_estimate()` has catastrophic single-fold outliers
  (raw errors of −38.0/+17.5, ~27× the mean-bias magnitude) —
  `../bug_fix_plans/kk_weibull_marginal_jackknife_outliers.md`. Most
  plausibly a leave-one-out fold landing on a degenerate/non-identifiable
  configuration for marginal Weibull models. Cross-validated 2026-09-24
  against a fresh full-package audit run, which ALSO surfaced 8 new
  `low_coverage` findings for this class spanning asymptotic AND every
  resampling family at once (0.87-0.91 undercoverage) — not yet confirmed
  whether this shares the jackknife outlier's root cause or is
  independent; the root-cause trace (TODO-1/2 of the linked plan) should
  check both. **Not yet implemented.**

## Closed as likely benign, NOT added to this release

- **`InferenceSurvivalCoxPHRegr`** (added 2026-09-24): 9 `low_coverage`
  findings, all mild OVER-coverage (0.974-0.998 vs. 0.95 target) across
  both asymptotic (`asymp`/`wald`/`gradient`/`lik_ratio`/`score`) and
  resampling (`bootstrap_basic`/`subsampling`/`rand_bootstrap_smoothed`)
  families at once. Read the class's CI-construction code
  (`inference_survival_coxph.R:343-406`) — standard, shared,
  heavily-used Cox partial-likelihood Wald/score/gradient/LR machinery,
  no defect found. This matches the same broad-mild-over-coverage
  "benign asymptotic conservativeness" shape already closed for
  `InferenceIncidGCompRiskDiff`/`RiskRatio` (`low_power`) and flagged as
  the leading (favored) explanation for `InferenceIncidLogRegr`/
  `InferenceIncidProbitRegr`'s `low_coverage` cluster. Not deeply
  root-caused beyond this — if this pattern recurs across enough classes
  to look systemic rather than per-class-benign, it may be worth
  revisiting as a harness-sensitivity question (the FDR-controlled exact
  binomial test may simply be very sensitive at these sample sizes) —
  but per-class, this one specific finding is closed, not added here.

## Standing constraints

Same as every release in this series: no `R CMD INSTALL`/`R CMD build`/
`pkgbuild::compile_dll()`/`devtools::load_all()` or `pkgload::load_all()`
without explicit `compile = FALSE` and without being asked in that exact
turn (top-level `CLAUDE.md`). Verify any `.cpp`-adjacent change via
targeted compile only, never a full rebuild.
