# Fix: KK-Matched Cox Proportional-Hazards Classes — Severe CI Undercoverage, Two Distinct Mechanisms

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-24`. Found 2026-09-24, surfaced by the new
> `low_coverage` audit check (two-sided exact-binomial test, H0:
> coverage = 0.95). Confirmed distinct from the already-fixed
> `release_v1_0_5.md → TODO-5 §A` finding (that one was about
> `compute_confidence_interval_rand()`'s log-time-scale shift, fixed
> 2026-09-06 by excluding these classes from the `randomization_ci`
> capability entirely — randomization-CI isn't even callable for them
> anymore, so this is a completely different code path).

## The finding: KK-matched/reservoir-split variants only, not Cox generally

`InferenceSurvivalKKStratCoxPHOneLik` and `InferenceSurvivalKKLWACoxPHOneLik`
show severe, broad CI undercoverage (0.47-0.94, varying by method family,
should be 0.95) across six-plus unrelated CI-construction families
(`wald`, `asymp`, `score`, `gradient`, several `bootstrap` flavors,
`lik_ratio`, `jackknife_wald`, `param_bootstrap`). The **plain,
non-KK-matched siblings on the same log-HR-excluded-from-rand-CI list are
fine**: `InferenceSurvivalCoxPHRegr` (0.94-1.00 across all 21 methods) and
`InferenceSurvivalStratCoxPHRegr` (0.90-1.00 across 20 methods). This
isolates the problem to the KK-matching/reservoir-split mechanism
specifically, not Cox regression or stratification generally.

Full per-method breakdown (worst to best):

**`InferenceSurvivalKKStratCoxPHOneLik`**: `param_bootstrap` 0.47 (worst)
→ `gradient` 0.57 → `bootstrap`/`lik_ratio`/`score` 0.60-0.61 → `wald`
0.65 → `asymp` 0.73 → `bayesian_bootstrap` 0.81-0.96 →
`subsampling`/`m_out_of_n_bootstrap` 0.86-0.88 → `jackknife_wald` 0.94
(best, near-nominal).

**`InferenceSurvivalKKLWACoxPHOneLik`**: `score`/`gradient` 0.50 (worst)
→ `wald`/`lik_ratio`/bootstrap variants 0.51-0.58 → `asymp` 0.64 →
`bayesian_bootstrap` 0.65-0.67 → `jackknife_wald` 0.69 →
`param_bootstrap` 0.79 → best resampling variants 0.85-1.00.

The gradient itself is diagnostic: the worst-affected families in both
classes are exactly the ones that directly consume the class's own
reported `s_beta_hat_T` (Wald-family, score, gradient, lik-ratio);
resampling-based families that re-derive variability empirically
(bayesian bootstrap, subsampling, jackknife) are better but still
degraded — consistent with an underestimated variance formula that
resampling only partially self-corrects for.

## `InferenceSurvivalKKStratCoxPHOneLik` — medium-high confidence root cause

`shared()` (`inference_survival_KK_strat_cox.R:176-265`) fits matched
pairs (`beta_m`, `ssq_m`) and the reservoir (`beta_r`, `ssq_r`) as two
**separate** Cox fits, then combines via standard inverse-variance
pooling: `w_star = ssq_r/(ssq_r+ssq_m)`, `beta_hat_T = w_star*beta_m +
(1-w_star)*beta_r`, `s_beta_hat_T = sqrt(ssq_m*ssq_r/(ssq_m+ssq_r))`
(`:252-254`). This arithmetic is textbook-correct **IF `beta_m` and
`beta_r` are independent** — both the weight and combined-variance
formula match the standard result exactly when checked directly.

That independence assumption is the suspect: the matched-pairs and
reservoir subsets are two halves of the *same* KK-matching allocation
process (a subject becomes a pair member vs. a reservoir member based on
availability at arrival time), so `beta_m` and `beta_r` may share
correlated information through the design/DGP rather than being truly
independent. If `Cov(beta_m, beta_r) > 0`, the true combined variance is
`w²·ssq_m + (1-w)²·ssq_r + 2w(1-w)·Cov(beta_m,beta_r)` — strictly larger
than the naive independence-assuming formula — which would produce
exactly the systematic, severe undercoverage observed, and explains the
severity gradient (every SE-consuming method inherits the same
underestimated `s_beta_hat_T` and fails worst; resampling methods
partially self-correct since they don't reuse this formula).

**Not yet empirically confirmed** — the independence-violation hypothesis
is plausible and mechanistically sound but has not been verified by
directly estimating `Cov(beta_m, beta_r)` across true-null reps on real
matched data.

## `InferenceSurvivalKKLWACoxPHOneLik` — root cause NOT found, lower confidence

This class does **not** use the matched/reservoir pooling pattern at all
(confirmed: zero hits for `w_star`/`ssq_m`/`ssq_r` in its file). Instead
`shared_combined_likelihood()`
(`inference_survival_KK_lwa_cox_one_lik_abstract.R:300-359`) fits a
**single joint** Cox model with a `cluster` argument
(`fast_coxph_regression_cpp(..., cluster = cluster_ids)`, `:322-329`) —
matched pairs get one cluster ID, reservoir singletons each get their own
unique ID (`:311-316`), a proper cluster-robust sandwich-SE setup that,
read at face value, looks textbook-correct — arguably *more* correct than
the strat-Cox class's naive pooling. Yet it shows the same-shaped, even
slightly worse undercoverage. Candidates not yet checked: a bug in the
shared C++ kernel's cluster-robust vcov computation itself
(`fast_coxph_regression_cpp`'s cluster-SE path was not read), or a
`coverage_truth` mismatch (checked only at a coarse level — 100%
populated, distribution tracks the point estimate reasonably, no obvious
"stuck at wrong constant" red flag, but no detailed per-row correctness
check of the MC-truth derivation itself was done).

## Scope note

`coverage_truth` was checked at a coarse level for both classes (100%
populated, sensible-looking distribution) — ruling out an obvious
missing-target explanation, but not a detailed correctness audit of the
MC-truth derivation itself for these specific classes.

## Resolution audit (2026-10-08)

The reported package bug is refuted. The plan conflated each affected
`OneLik` class with its separately fitted `IVWC` sibling:

- `InferenceSurvivalKKStratCoxPHOneLik` has always used one joint stratified
  Cox partial likelihood. The `beta_m`/`beta_r` inverse-variance pooling
  quoted above belongs to `InferenceSurvivalKKStratCoxPHIVWC`, which was not
  the class named by the coverage findings.
- `InferenceSurvivalKKLWACoxPHOneLik` uses one marginal Cox fit over all rows
  with pair-clustered sandwich covariance and singleton reservoir clusters.
  Its C++ sandwich implementation matches both an independent subject-score
  derivation and `survival::coxph(... + cluster(...), ties="breslow")`.

The common symptom has a harness-side explanation established by
`mc_coverage_truth_covariate_mismatch.md`: at nonzero treatment effects, the
matched-Cox high-covariate MC target changes materially with the large-sample
construction and lies far from the finite-sample estimator distribution.
The old rows therefore cannot diagnose CI calibration. The harness now
returns an explicitly unavailable coverage truth for these two classes
instead of grading against either that unconverged target or raw `beta_T`.
At the true null, where the target is unambiguous, the historical coverage
was already 0.93--1.00 across the method families.

Focused source-loaded validation passed 112 expectations: both OneLik
classes' estimates/SEs against `survival` references (8), the Cox kernel and
cluster sandwich references (68), and the coverage-truth registry/unavailable
target guards (36). No production estimator or variance change is warranted.

## TODOs

- [x] TODO-1 (`InferenceSurvivalKKStratCoxPHOneLik`): empirically estimate
  `Cov(beta_m, beta_r)` across true-null reps on real matched data, via
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
  Confirm or refute the independence-violation hypothesis directly before
  proposing a specific fix. **Refuted as inapplicable:** this `OneLik` class
  does not pool `beta_m` and `beta_r`; the hypothesis describes the IVWC
  sibling. No covariance term exists to estimate for this implementation.
- [x] TODO-2 (`InferenceSurvivalKKStratCoxPHOneLik`): if TODO-1 confirms
  correlation, the fix is a proper JOINT (not pooled-independent) variance
  — likely meaning this class should adopt the same cluster-robust
  joint-fit approach `KKLWACoxPHOneLik` already uses, rather than patching
  the pooling formula's covariance term in place. Decide and implement.
  **Closed:** the premise is false; the class already has a joint stratified
  partial-likelihood fit, and its numerical reference test passes.
- [x] TODO-3 (`InferenceSurvivalKKLWACoxPHOneLik`): read
  `fast_coxph_regression_cpp`'s cluster-robust vcov C++ implementation
  directly for a formula bug. **Done:** the score-residual meat is summed by
  cluster and sandwiched by the inverse information. Independent formula and
  `survival::coxph` regressions pass for tied times, arbitrary cluster labels,
  row permutations, fixed coefficients, and both optimizers.
- [x] TODO-4 (`InferenceSurvivalKKLWACoxPHOneLik`): empirically compare
  `s_beta_hat_T` against the empirical SD of `beta_hat_T` across true-null
  reps (same diagnostic pattern used elsewhere this session) if TODO-3
  doesn't turn up a clean code-level answer. **Closed as superseded:** TODO-3
  found no formula discrepancy, null-target coverage is nominal, and the
  non-null coverage rows have no defensible numeric target.
- [x] TODO-5: detailed correctness check of the `coverage_truth`
  MC-derivation for both classes, ruling it in or out more rigorously than
  the coarse check already done. **Done in the linked truth audit:** block
  recycling and bootstrap resampling give materially different targets;
  both classes are now explicitly ungraded until a converged target or
  revised scenario is chosen.
- [x] TODO-6: implement whichever fix(es) TODO-1/2/3/4 land on. If C++
  changes are needed (likely for TODO-3/4's path), verify via targeted
  compile of only the touched `.cpp` file(s), never a full package
  rebuild, per top-level `CLAUDE.md`. **Closed:** no estimator/C++ fix is
  indicated. The only required implementation is the already-completed
  harness guard against invalid coverage targets.
- [x] TODO-7: re-run coverage checks across all affected method families
  for both classes and confirm return to nominal ~95%. **Closed as invalid
  validation:** nominal coverage cannot be asserted until a numeric target is
  defined. Existing null-target rows were already nominal.
- [x] TODO-8: regenerate affected `comprehensive_tests` CSV rows once
  fixed and installed (only after install, not before). **Closed for this
  alleged package bug:** no package fix exists to regenerate. Release-wide
  regeneration after the truth-policy change remains tracked by
  `mc_coverage_truth_covariate_mismatch.md` TODO-4/5.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only for R-layer checks, targeted
compile only for any `.cpp` change, never a full build. The plain
(non-KK-matched) sibling classes, already confirmed unaffected, must
remain bit-for-bit unchanged by whatever fix is applied here.
