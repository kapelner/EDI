# Fix: Stale Worker-Cache in Reused-Worker Resampling — Degenerate Randomization/Bootstrap Distributions

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) TODO-1..6
> shipped 2026-09-22 (see `Status` below), out of band ahead of
> `release_v1_1_0.md → TODO-31` as an urgent correctness fix; moved
> 2026-09-23 to `release_v1_0_5.md → TODO-9` (bug-fix/feature split).
> TODO-9 (the latent `cached_mod` gap found during this plan's final
> review) is slated for `release_v1_0_5.md → TODO-12` (was
> `release_v1_1_0.md → TODO-34`).

Found 2026-09-22, following up on three new checks added to
`audit_comprehensive_results.R` this session (`biased_estimate`,
`bad_type1_error`, `low_power`) — see memory
`project_stale_worker_cache_resampling_bug_20260922`. **This is a
correctness bug in shipped inference methods** (silently wrong p-values,
not an error/NA), found via the CSV audit, not a user report, on a package
that is CRAN-submission-imminent (`project_cran_status`).

## The bug, proven by direct repro (installed package, no rebuild)

`InferenceOrdinalGCompMeanDiff$compute_rand_two_sided_pval()` rejects a true
null essentially 100% of the time instead of the nominal 5% (reproduced:
20/20 independent datasets at `n=100`, `r=201` permutations, all rejected;
matches the audit's `bad_type1_error` finding — reject-rate 1.000 over 723
`beta_T=0` rows, z=117).

Root cause: `shared()` (`R/EDI/R/inference_ordinal_gcomp.R`) is guarded —
```r
shared = function(estimate_only = FALSE){
  if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
  if (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))
  if (estimate_only && !is.null(private$cached_values$md)) return(invisible(NULL))
  ...
```
The third guard is class-specific: `cached_values$md` is this class's own
point-estimate cache key (`compute_estimate()` returns
`private$cached_values$md` directly, not `beta_hat_T`). The reused
randomization worker's per-draw loader,
`load_randomization_perm_into_worker()`
(`R/EDI/R/inference_all_abstract_rand.R`, ~line 914-954), resets exactly
four cache fields between permutation draws: `KKstats`, `beta_hat_T`,
`s_beta_hat_T`, `likelihood_null_warm_cache`. It does **not** reset `md`
(or its siblings `mean1`, `mean0`, `se_md`). So:

1. Permutation draw 1 finds `md` unset, fits fresh, caches `md`.
2. Permutation draws 2..r find `md` already set (from draw 1) and
   early-return **without refitting** — the loader reset `beta_hat_T` to
   `NULL`, but `compute_estimate()` returns `cached_values$md` directly, a
   field the loader never touches, so the stale value is what actually gets
   returned.
3. The resulting "randomization distribution" is `r` copies of whatever
   draw 1 happened to compute — proven directly: printing
   `approximate_randomization_distribution_beta_hat_T()`'s raw output shows
   all 201 values bit-identical, and feeding two *opposite* treatment
   vectors straight into the worker's estimator
   (`compute_bootstrap_worker_estimate()`) returns bit-identical output for
   both.
4. That degenerate point mass essentially never equals the true observed
   estimate, so the two-sided p-value sits at its floor
   (`~2/(r+1) ≈ 0.01` at `r=201`) on **every call, regardless of the true
   treatment effect** — this is not specific to the null being true; it
   would inflate rejection just as much at any `beta_T`, it only happens to
   surface as `bad_type1_error` because that's where the audit can tell it
   apart from real power.

## Scope: this is not one class or one method family

`R/EDI/R/contracts_resampling_draws.R`'s `EDI_RESAMPLING_DRAW_CONTRACTS`
shows four of the five reusable-worker operations —
`rand`, `non_param_boot`, `m_out_of_n_boot`, `rand_bootstrap` — all
ultimately call the **same** generic `compute_bootstrap_worker_estimate()`
(different loaders, same estimator function). Any class whose point-estimate
caching uses a guard key outside
`{beta_hat_T, s_beta_hat_T, KKstats, likelihood_null_warm_cache}` is exposed
on **all four** of those operations, not just randomization. The fifth
operation, `bayesian_boot`, is **not** affected: its worker estimator
(`compute_bayesian_bootstrap_worker_estimate`) calls the purpose-built
`compute_estimate_with_bootstrap_weights()` instead, which
`InferenceOrdinalGCompMeanDiff`'s own docstring already documents as
explicitly side-effect-free (saves/restores `cached_values` around the
weighted refit) — consistent with Bayesian bootstrap never appearing in
this class's audit findings.

**Confirmed by direct repro:**
- `InferenceOrdinalGCompMeanDiff` (`inference_ordinal_gcomp.R`) —
  `compute_rand_two_sided_pval`, reject-rate 1.0 at true null (see above).

**Same code shape (`cached_values$md`-style custom guard), not yet directly
repro'd, high-confidence suspects:**
- `InferencePropGCompMeanDiff` (`inference_proportion_gcomp.R`) — identical
  `if (!is.null(private$cached_values$md) && ...)` guard.
- `InferenceIncidGCompRiskDiff` / `InferenceIncidGCompRiskRatio`
  (`inference_incidence_gcomp_abstract.R`), `InferenceIncidKKGCompRiskDiff`
  / `InferenceIncidKKGCompRiskRatio`
  (`inference_incidence_KK_gcomp_abstract.R`) — guarded via
  `gcomp_standardized_effect_cache_is_ready()` (`helper_gcomp.R`), a
  different custom-key helper, not yet inspected for which fields it checks
  vs. what any loader resets.

**Independently corroborated by the audit (different guard mechanism, same
failure signature):**
- `InferenceContinLin` (`inference_continuous_lin.R`) — guards on
  `cached_values$lin_estimate_only_complete` / `lin_full_complete`, not
  `beta_hat_T`. Topped the `bad_type1_error` list on three separate
  bootstrap-family p-values simultaneously
  (`compute_lik_ratio_bootstrap_two_sided_pval` z=19.4,
  `compute_param_bootstrap_pval` z=18.8,
  `compute_lik_ratio_bartlett_approx_two_sided_pval` z=16.4) — exactly the
  cross-method-family signature this bug's mechanism predicts (one stale
  point-estimate cache corrupts every resampling method that reuses it),
  distinguishing it from an isolated per-method bug.

**Not this bug — checked and ruled out:** `InferenceIncidKKModifiedPoisson`
(the other standout from the `low_power` audit check, 342/346 of those
findings). Its `shared()` guards on the standard `beta_hat_T`/`s_beta_hat_T`
(already correctly reset by every loader). Direct repro with a strong
synthetic risk ratio (RR=3, `DesignFixedBinaryMatch`) gave 100% Wald/score
rejection, i.e. its analytic inference works correctly. The harness's
near-zero power for this class is most likely a genuinely weak effect size
at its generative settings, not a defect — separate, lower-priority,
unconfirmed issue, out of scope for this plan.

**Full affected-class list is not yet known.** TODO-1 below is the
grep-every-`shared()` sweep needed to enumerate it exhaustively before
scoping the fix.

## Proposed fix

Two options, in increasing order of invasiveness:

**Option A — allowlist → denylist (the generic, systemic fix).** Change
`load_randomization_perm_into_worker()` (and the three sibling
`non_param_boot`/`m_out_of_n_boot`/`rand_bootstrap` loaders, which likely
have the identical narrow reset list — TODO-2 confirms) to reset **all** of
`worker`'s `cached_values` except an explicit keep-list (warm-start state,
the resampling-distribution caches themselves, anything else that must
legitimately survive across draws within one call). This can't miss a class
the way an allowlist of four specific keys can, and matches the "single
source of truth" direction of `release_v1_1_0.md → TODO-20`'s registry
hardening. Risk: some class may rely on *something* surviving across draws
for a legitimate performance reason not yet identified — needs an audit of
what's currently in `cached_values` across all affected classes before
flipping the default.

**Option B — per-class fix (narrower, lower-risk, slower to
cover everything).** Add each custom cache key found by TODO-1's sweep to
the specific loader(s) that class's resampling operations reach. Safer per
change, but leaves the same defect latent for the next class written with a
custom cache-guard key — doesn't fix the systemic gap, only today's known
instances.

Recommend Option A with the keep-list built from an explicit audit
(TODO-3), not Option B, given TODO-1 may well turn up more affected classes
than the ones already found here — a per-class patch list is exactly the
kind of hardcoded-allowlist pattern `release_v1_1_0.md → TODO-20` was
written to eliminate elsewhere in this codebase.

## Why this needs review before shipping

- **Correctness, not performance**: every resampling-based p-value/CI on
  every affected class, for as long as this has existed, may be silently
  wrong (not NA, not erroring — a plausible-looking number). Any historical
  results, examples, or vignette output computed with an affected class's
  `rand`/`non_param_boot`/`m_out_of_n_boot`/`rand_bootstrap` methods should
  be treated as suspect pending the fix.
- **Architectural change reaches shared machinery** used by every class in
  the package that goes through the reused-worker path — Option A changes
  behavior for classes that are NOT currently broken too (their cache reset
  becomes broader than before), so needs the standing-constraints
  bit-for-bit-reproduction discipline: a correctly-working class's results
  must not move.
- **CRAN timing**: `project_cran_status` says submission is imminent. This
  plan doesn't decide whether the fix blocks submission — that's the user's
  call — but the severity should be weighed explicitly rather than
  defaulting to "next available TODO slot."
- **Test coverage gap**: the fact that this sat undetected means the
  existing structural/adversarial test suite
  (`project_prepush_structural_and_results_gates_20260919`) doesn't check
  "does the resampling distribution actually vary across draws" for any
  class. TODO-6 adds that as a permanent regression guard, not just a
  one-off fix verification.

## TODOs

- [x] TODO-1: Exhaustive sweep — grep every `shared()` (and
  equivalently-named per-class estimate-caching function, e.g.
  `compute_shared()`, `shared_gee_dispatch()`) in `R/EDI/R/inference_*.R`
  for any cache-guard key outside
  `{beta_hat_T, s_beta_hat_T, KKstats, likelihood_null_warm_cache}`.
  Cross-reference each hit against which resampling operations
  (`rand`/`non_param_boot`/`m_out_of_n_boot`/`rand_bootstrap`) that class
  actually exposes (via its declared components/capabilities) to build the
  exact affected-class × affected-method-family list. Include classes
  reached indirectly through shared mixins
  (`inference_incidence_gcomp_abstract.R`,
  `inference_incidence_KK_gcomp_abstract.R`, `helper_gcomp.R`'s
  `gcomp_standardized_effect_cache_is_ready()`) — a mixin fix covers every
  class that composes it, don't patch each concrete class separately if the
  root cache-key lives in a shared helper.
- [x] TODO-2: Read the three sibling loaders
  (`load_non_param_bootstrap_draw_into_worker`,
  `load_m_out_of_n_bootstrap_draw_into_worker`,
  `load_rand_bootstrap_draw_into_worker`) and confirm whether they share
  the randomization loader's exact narrow reset list or have their own
  (possibly different) gap. `load_bayesian_bootstrap_draw_into_worker` is
  believed out of scope (different estimator function entirely) — confirm
  this holds for every Bayesian-bootstrap-capable class, not just
  `InferenceOrdinalGCompMeanDiff`.
- [x] TODO-3: Audit what every currently-passing (non-buggy) class's
  `cached_values` actually needs to survive across resampling draws within
  one call (warm-start fields, anything performance-motivated) to build
  Option A's keep-list; confirm nothing legitimate breaks.
- [x] TODO-4: Implement Option A (or B if TODO-3 surfaces a reason
  A is unsafe) across the four affected loaders.
- [x] TODO-5: Re-run the reproduction from this plan
  (`InferenceOrdinalGCompMeanDiff`, `r=201`, 20+ reps at `beta_T=0`) and
  confirm reject-rate returns to ~0.05; extend to every class TODO-1 found,
  confirming the randomization/bootstrap distribution is no longer constant
  across draws (a direct, cheap check: `sd(distribution) > 0`) and Type-I
  error/coverage return to nominal.
- [x] TODO-6: Add a permanent regression test to the structural gate suite
  (`R/EDI/tests/testthat/`, alongside
  `test-adversarial-and-fault-injection.R` per
  `project_prepush_structural_and_results_gates_20260919`) that checks,
  for every class exposing a reusable-worker resampling method: the
  returned distribution is not degenerate (`sd() > 0` over a small `r`,
  cheap enough for the pre-push hook). This is the general guard that would
  have caught this class of bug before it needed a CSV audit to surface.
- [ ] TODO-7: Regenerate the `comprehensive_tests` CSV rows for every
  affected class/method-family combination once the fix lands and is
  installed (not before — regenerating first would just re-record the same
  bug), then re-run `audit_comprehensive_results.R --write-baseline` to
  drop the now-stale findings. Do this only after TODO-1's list is
  believed complete — writing the baseline against a partial fix would
  accept the remainder as debt.

  **Partially done 2026-09-23, blocked short of `--write-baseline`.**
  Affected-class list re-confirmed empirically (pre-fix-vs-post-fix
  bit-for-bit sweep at commit `d5f1d679`, zero compilation): the same 7
  classes as TODO-1/TODO-5. `InferenceContinLin`'s 3 originally-flagged
  bootstrap methods reconfirmed as a separate `param_boot` mechanism, out
  of scope here (see `contin_lin_param_bootstrap_bad_type1_error.md`).
  Scoped regen ran clean for all 7 classes (2400+ calls, 0 errors) and was
  merged into the real result CSVs the audit reads.

  **Blocker resolved (checked 2026-09-24).** The pooling problem is gone:
  `stale_ok_row_rules.csv` now carries rules for the 7 classes'
  `compute_rand_two_sided_pval` cells (`before_timestamp` 2026-09-23,
  `tracked_in = commit:811e0683`), and a `prune_stale_result_rows.R` dry run
  matches 0 rows for each, i.e. the pre-fix rows were already removed. The
  remaining `InferenceOrdinalGCompMeanDiff` `rand` rows at `beta_T = 0` are
  all post-fix: 80 rows with reject rates 0.05-0.09 (versus the 0.952 that
  pre-fix rows produced), so the p-value is calibrated. What is still open
  is the last step, `audit_comprehensive_results.R --write-baseline`, plus
  the two findings below.

  **Two findings surfaced by the regen, triaged 2026-09-24:**
  - `InferenceIncidGCompRiskDiff`/`RiskRatio` `low_power` at `beta_T = 0.5`:
    **benign.** The post-fix rows (diamonds, n = 148, Bernoulli design, 80
    rows per cell) reject 0.075 at the null and 0.200 at `beta_T = 0.5`. A
    fresh simulation (n = 148, 60 reps, `r = 151`) gives 0.033 / 0.217 for the
    g-computation randomization test, and exactly the same for
    `InferenceAllSimpleAverageDiff` (the randomization p-value is the same
    test) versus 0.317 for the logistic-regression Wald test. The effect is
    simply small for this sample size; nothing is wrong with the class.
  - `InferenceIncidKKGCompRiskDiff`/`RiskRatio` deflated Type-I error:
    **reproduced from scratch, but not specific to this class.** Post-fix
    rows: 0/80 null rejections (median p 0.62). Fresh simulation under
    `DesignSeqOneByOneKK21stepwise` (n = 148, 60 reps, `r = 151`): 0/60
    rejections, median p 0.71, mean p 0.66 (expected 0.5). The
    `InferenceAllSimpleAverageDiff` randomization p-value on the same data is
    identical (0.71 / 0.66), so the conservatism is in the shared
    randomization machinery or the KK21stepwise design replay, not in the
    g-computation code. Tracked as
    `investigate_kk21stepwise_incidence_randomization_pval_conservative.md`
    (release TODO-53); it is not a blocker for the stale-cache work.

  New rows are already live in the 3 main result CSVs (harmless — this is
  what the harness would produce on its next unfiltered run regardless).
  No compile/install command was run at any point.

  **Ordinal GComp randomization-p-value audit signal (2026-10-15; triage only):**
  a filtered installed-package audit in
  `/tmp/edi-todo9-target-audit-20261015` reported a new
  `InferenceOrdinalGCompMeanDiff::compute_rand_two_sided_pval` finding:
  275/4,675 finite `beta_T=0` p-values were below .05 (5.882%; ACAT
  `p=1.19e-4`). The 4,680 candidate rows covered nine datasets, seven designs,
  40 reps, and two model-formula variants; five fuel/`FixedMatchingGreedy`
  cells were explicitly skipped after 120-second timeouts and excluded by the
  audit. Rejection rates were 4.6–7.1% by dataset and 4.6–8.3% by design.
  These rows are clustered within dataset/replicate across designs and formula
  variants, so the pooled IID binomial signal is not a calibrated method-level
  test: an exploratory score-SE correction grouped by dataset×replicate gives
  `p≈.009`, while treating the nine datasets as clusters gives `p≈.063`.

  A fresh isolated installed-package replay on iris (`n=150`, truncated to 148;
  40 reps, seven designs, both formulas; `r=151`) produced 19/520 rejections
  (3.65%), with all 520 calls status `ok`; a separate 10-rep replay gave 7/130
  (5.38%). The original audit slice for iris was 37/520 (7.12%). The 40-rep
  run used `/tmp/edi-todo9-ordinal-replay.svol7d` and did not compile/build/
  install. A separate full audit copy has an additional older 10-rep block
  for diamonds (reps 41–50), yielding 4,805 finite rows rather than 4,675;
  this confirms that artifact provenance and replay composition must be
  checked before interpreting pooled significance. The focused iris replay
  does not reproduce inflation, but it is not enough to establish calibration
  across datasets/designs. No method semantics or canonical baseline were
  changed. TODO-7 remains open for a clean, complete installed regeneration
  and audit; any inference-method change requires a controlled, cluster-aware
  calibration study rather than this aggregate finding alone.

  **Isolated minimal ordinal regeneration (2026-10-16; diagnostic only):**
  in a fresh `/tmp/edi-todo9-ordinal-minregen-gW7hGl` copy, the absolute-path
  harness ran installed EDI 1.0.3 for `iris`, ordinal, Bernoulli,
  `InferenceOrdinalGCompMeanDiff`, `beta_T=0`, 40 reps, and `rand` only.
  The 80 ordinary null p-values (40 per `~1`/`~.` formula) were non-pointmass:
  32 distinct values per formula, ranges 0.013–0.954 and 0.013–0.967, with
  3/40 and 2/40 below .05. The delta=.5 controls were retained but excluded
  from null calibration by the audit as intended. The unmodified audit first
  exposed an empty-CI edge in this rand-only slice (`binom.test(k, n=0)`);
  one additional 1-rep bootstrap-family run in the same temp copy supplied
  real CI rows, after which the audit ran against only the staged ordinal CSV
  plus a copy of the tracked audit baseline: 0 current findings, 2165 baseline
  findings absent from this deliberately partial file. This checks the local
  stale-cache signature for one dataset/design; it is neither a calibration
  study nor canonical regeneration/baseline rewrite. All outputs remain in
  `/tmp/edi-todo9-ordinal-minregen-gW7hGl/`; no canonical CSV or baseline was
  written, and no build/install occurred. TODO-7 remains open.

  **Full canonical audit (2026-10-16; no canonical writes):** the unmodified
  audit ran with `--force` in a `/tmp` staging directory whose result CSVs
  were read-only symlinks to the canonical files and whose baseline was a
  copy. It reported 183 baseline findings absent and 373 new findings across
  the full suite, so `--write-baseline` remains blocked. There are 13 current
  `InferenceOrdinalGCompMeanDiff` findings: 12 already accepted in the
  baseline and one new `low_power` finding for
  `compute_rand_bootstrap_two_sided_pval_smoothed` (0/67 non-null rows reject
  at .05; p=8.60e-4). Its baseline-accepted null-calibration finding is the
  same method: 0/706 null rejections, with 36 distinct p-values in [0.450,
  0.993] (extreme excess of large p-values, not a point mass). The old rows
  include pre-cutoff observations (685 null and 11 non-null); post-cutoff
  rows still show 0/21 null and 0/56 non-null rejections, with 11 and 20
  distinct p-values respectively. The exact stale-cache rule cell,
  `compute_rand_two_sided_pval`, has 650 post-cutoff null rows, 75 distinct
  p-values and 46/650 rejections; it is not among current audit findings.
  Thus the two smoothed-method signals do not reproduce the old point-mass
  signature, but their mixed pre-/post-fix history means stale-worker
  causation is not fully excluded. Keep these as a separate method-specific
  follow-up: regenerate that smoothed method's null and beta_T=.5 rows with
  the current package, compare against the post-cutoff records, and inspect
  the randomization-bootstrap worker/smoothing path before deciding whether
  this is a method defect or a legitimate low-power regime. No canonical CSV,
  baseline, or stamp was modified.

  **Current-support qualification:** the current ordinal smoothing guard in
  `rand_bootstrap_smoothing_supported()` permits smoothed resampling only
  when the inference class supplies the private
  `compute_fast_rand_bootstrap_distr` method. `InferenceOrdinalGCompMeanDiff`
  does not supply that method, so the historical smoothed rows above do not
  represent currently supported behavior for this class. Reconcile the
  regeneration proposal with TODO-18's ordinal guard before treating any new
  smoothed rows as current-package results; keep TODO-7 open pending that
  decision and the remaining release-wide gates.

  **Scratch exact-key recheck (2026-10-18; no canonical writes):** the six
  locally present, gitignored full response CSVs were symlinked read-only
  into `/tmp/edi-todo9-audit.NnBBLg`; the tracked baseline was copied there.
  `audit_comprehensive_results.R --force` reproduced 183 baseline findings
  absent and 373 new findings. A second `--write-baseline` pass used the
  same output override and wrote only the scratch baseline/stamp, allowing an
  exact key join without touching canonical results or baseline. The input
  CSV mtimes range from 2026-09-27 to 2026-10-09, and they carry no verified
  source/DLL provenance, so this reproduces the prior audit counts but does
  not validate current-package results or authorize reconciliation.

  The exact join confirms the nine listed categorical baseline smoothed
  findings are still reported by these old rows. It also exposes four newly
  reported smoothed findings:
  `low_power|incidence|InferenceIncidLogRegr|~1|compute_rand_bootstrap_two_sided_pval_smoothed`,
  `low_power|ordinal|InferenceOrdinalGCompMeanDiff|NA|compute_rand_bootstrap_two_sided_pval_smoothed`,
  `pval_miscalibration|proportion|InferencePropBetaRegr|~.|compute_rand_bootstrap_two_sided_pval_smoothed`,
  and
  `pval_miscalibration|proportion|InferencePropFractionalLogit|~.|compute_rand_bootstrap_two_sided_pval_smoothed`.
  Static source review finds that the current smoothing predicate requires a
  private `compute_fast_rand_bootstrap_distr` method for incidence, ordinal,
  and proportion responses, and none of these four classes supplies one.
  Thus the three newly surfaced non-ordinal keys also appear to describe
  unsupported old output, not current source behavior. This classifies only
  these 13 smoothed keys; the remaining 183-absent/373-new differences still
  need row-level evidence and disposition before a baseline write.

  **Additional historical subset classification (2026-10-19; read-only):**
  comparing `/tmp/edi-todo9-audit.NnBBLg/baseline.before.csv` with that
  directory's scratch-generated `comprehensive_results_audit_baseline.csv`
  reproduces the 183 absent / 373 new key counts. Of the new keys, 29 are
  `pval_miscalibration` findings for proportion
  `InferencePropBetaRegr`, across 18 distinct p-value functions and the
  `~.`, `~1`, and `NA` formula strata. Their source input is the symlinked
  `R/package_tests/comprehensive_tests_results_nc_1_proportion.csv`; its
  mtime is 2026-10-09 01:11:31 +0300, and the scratch audit stamp records
  84,170,816 bytes / mtime epoch 1791497491. This predates the Oct 11
  null-fit warm-start change tracked by TODO-52, but the CSV has no verified
  source or native-DLL provenance. Disposition: **historical/pre-fix,
  current status unknown; not droppable from the baseline**. These rows
  cannot establish a current defect or justify accepting current behavior;
  only a provenance-pinned post-fix regeneration and key-level comparison
  can resolve them. The classification does not alter the baseline and does
  not close TODO-7.

  **Isolated-output integration audit (2026-10-18):**
  `comprehensive_tests.R` now passes its computed canonical filename through
  `resolve_comprehensive_results_file()`. Setting
  `EDI_COMPREHENSIVE_RESULTS_DIR` to an existing `/tmp` directory redirects
  the result CSV and adjacent lock while preserving the filename/filter
  suffix; when unset, the original `repo_path("package_tests", ...)`
  destination is unchanged. The pure helper regression covers unchanged
  default path, override path, and fail-closed behavior for a missing
  directory. For the later TODO-7 regeneration, use a new scratch directory
  per run and do not point the override at the existing filtered/canonical
  files.

  This is output isolation, not yet an end-to-end scratch audit: the runner's
  startup stale-row check still invokes `prune_stale_result_rows.R` relative
  to the checkout (default/report-only mode), and
  `audit_comprehensive_results.R` does not read
  `EDI_COMPREHENSIVE_RESULTS_DIR`. The latter derives `here` from its own
  `--file` path, reads only unfiltered
  `comprehensive_tests_results_nc_1_<response>.csv` names, and writes its
  baseline/stamp beside the script under `--write-baseline`. A filtered shard
  produced by the override will therefore not be consumed by that audit.
  Do not run `--write-baseline` against the checkout as part of an isolated
  pilot. Before claiming TODO-7 reconciliation, define a scratch-only audit
  input containing the complete response-level results required by the
  baseline comparison, and keep its baseline/stamp separate; filtered shards
  alone are insufficient. No run, audit, pruning, or baseline write was
  performed for this integration check.

  **Scratch baseline-write regressions (2026-10-20):**
  `test-comprehensive-audit-output-directory-override-reference.R` now has
  two CLI cases using isolated scratch inputs: a partial response artifact
  set must refuse `--write-baseline` without replacing an existing baseline
  or stamp; a complete synthetic response set must write its baseline and
  stamp only under `EDI_COMPREHENSIVE_RESULTS_DIR`, not beside the copied
  runner. These exercise scratch-path refusal/routing only. The full
  canonical audit was not run and no canonical baseline was written. The
  tests extend the earlier output-isolation check only for synthetic
  artifacts; they do not reconcile the canonical inputs. The exact-key
  comparison gate remains the previously recorded 183 baseline findings
  absent / 373 new findings, requiring row-level evidence and disposition
  before any baseline rewrite.

  **Structural input preflight, 2026-10-21:** the six-file write guard now
  also requires the result schema and at least one data row per response CSV
  (header plus first row only). The focused scratch-path test passes 39
  assertions, including rejection of header-only/wrong-schema files without
  replacing baseline/stamp sentinels. This prevents structurally empty inputs
  from reaching the writer, but does not establish complete expected keys,
  valid terminal outcomes, or current source/package/DLL provenance. The
  six-response provenance/key reconciliation remains open; the 183
  baseline-only and 373 finding-only differences are unresolved, and no
  canonical baseline write is authorized.

  **Scratch-evidence availability recheck (2026-10-21; read-only):** the
  previously cited `/tmp/edi-todo9-audit.NnBBLg` directory and its finding
  table are absent from the current environment. The recorded exact-key join
  (2,165 unique baseline keys; 2,355 unique finding keys; 1,982 common,
  183 baseline-only, and 373 finding-only) is therefore historical and
  unauthenticated here, not a currently inspectable or reproducible result.
  The original CSV inputs were gitignored artifacts without source/package/
  native-DLL provenance. Reconciliation still requires a provenance-stamped
  regeneration of all six complete response inputs, followed by exact-key
  disposition of every difference; no baseline promotion is authorized.

- [x] TODO-8: Once the affected-class list is final (TODO-1), decide
  whether any already-published example, vignette, or documentation output
  used an affected class's resampling p-value/CI and needs correction —
  separate from the code fix itself.

  **Investigated 2026-09-23** (published-material audit: vignettes, `.Rd`
  examples, README/NEWS, `python/` docs, JSS paper draft). Exactly one
  genuine correction candidate found:
  `R/EDI/vignettes/cookbook-incidence.Rmd:109-114` —
  `InferenceIncidKKGCompRiskDiff$compute_rand_two_sided_pval(r=200)`, a
  live-executed chunk (not `eval=FALSE`) that renders a real computed
  p-value in the built vignette. **Confirmed** (2026-09-23) —
  `InferenceIncidKKGCompRiskDiff` is on TODO-7's rebuilt, empirically-
  verified 7-class affected list. No manual number-editing needed — the
  vignette's surrounding prose doesn't assert a specific p-value/
  significance claim, it just prints the object's default output.

  **Also discovered while closing this out:** this package has a CI
  workflow (`.github/workflows/pkgdown.yaml`) that auto-deploys a pkgdown
  site to `https://kapelner.github.io/EDI/` on every push to `main`
  touching `R/EDI/R/**`/`R/EDI/vignettes/**`/etc., and it *executes*
  vignette code at build time — not a static copy. Of 107 historical
  commits touching those paths, only 11 used `[skip ci]`, so the live site
  has almost certainly been showing this vignette's wrong (bug-signature:
  pinned near its floor, `~2/(r+1)`) p-value for some time. Local `main`
  held the fix unpushed as of this finding. **Resolved 2026-09-23: user
  pushed `main` to `origin`**, which triggers the path-matched CI to
  rebuild and redeploy the site with the fix automatically — no separate
  manual vignette-fix commit or manual pkgdown rebuild needed. Loop closed.

  Everything else that superficially matched (grep hits on resampling
  method names or suspect class names) was a false positive: roxygen2's
  auto-generated "Methods" listing in `.Rd` files (not real `\examples{}`
  content — the actual example blocks for every suspect class call only
  `compute_estimate()`, and two suspect classes have no `\examples{}`
  section at all); non-suspect classes in README/NEWS/other vignettes;
  `python/README*.md`'s benchmark table (fit-time/speedup columns, not
  resampling p-values — confirmed by reading the underlying benchmark HTML,
  no `compute_rand_*`/`compute_bootstrap_*` calls anywhere in it); and the
  JSS paper draft (prose only, no worked numeric example tied to this bug,
  also not yet submitted/published).
- [ ] TODO-9 (implementation complete 2026-10-07; release verification
  remains; added 2026-09-22, found during this plan's own final
  whole-branch review — see `Status` below): **latent `cached_mod` reset
  gap, same bug shape, no concrete class reaches it yet.** The systemic fix
  (TODO-4) reset `cached_values` down to a `duplicate()`-derived keep-list,
  but the randomization loader (`load_randomization_perm_into_worker()`,
  `R/EDI/R/inference_all_abstract_rand.R:970-978`) still resets a
  hand-maintained *allowlist* of **private fields** (`cached_design_matrix`,
  `cached_w_for_design_matrix`, `cached_harden_for_design_matrix`,
  `cached_reduced_X`, `cached_X_full_for_reduced`, `cached_keep_for_reduced`,
  `cached_j_treat_for_reduced`) — the exact allowlist shape this plan exists
  to eliminate, one level up from `cached_values`. That list is strictly
  narrower than the bootstrap-family loader's reset
  (`load_bootstrap_sample_into_design_backed_worker()`,
  `R/EDI/R/inference_all_abstract_non_param_boot.R:1216-1225`, which
  additionally clears `reduced_design_keep_cache`, `fixed_covariate_keep_cache`,
  `best_X_colnames`, `best_Xmm_colnames`, and **`cached_mod`**) and
  `inference_all_abstract_param_boot.R:913-917` (also clears `cached_mod`).
  `cached_mod` matters because it is read as an early-return guard — the
  same bug shape TODO-4 fixed:
  ```r
  # R/EDI/R/inference_all_abstract_mle_or_KM_summary_table.R:92-100
  shared = function(estimate_only = FALSE){
    if (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))
    if (!estimate_only && !is.null(private$cached_values$summary_table)) return(invisible(NULL))
    if (is.null(private$cached_mod)) {
      private$cached_mod = private$generate_mod()
    }
    model_output = private$cached_mod
  ```
  With `beta_hat_T` correctly cleared, draw 2 passes the line-93 guard but
  hits line 97 with draw 1's stale `cached_mod` still live and re-derives
  draw 1's `beta_hat_T` from it — a degenerate distribution again, via the
  private-field door instead of the `cached_values` door.

  The original branch deferred this gap because no concrete class then reached this guard —
  every `generate_mod()`-taking class in the package belongs to the
  `InferenceAsympLikStdModCache` ladder, whose own `shared()`
  (`inference_all_abstract_asymp_lik_std_mod_cache.R:177-191`) *writes*
  `cached_mod` unconditionally rather than reading it stale, and the last
  concrete class that inherited the vulnerable `InferenceAsympLik` path was
  already migrated away (`inference_ordinal_paired_sign_test.R:63`). The
  240-class non-degeneracy sweep (this plan's TODO-6 test, extended to KK
  and blocking designs) forced every concrete class through the reused
  worker and found no additional degenerate class — empirical
  corroboration that this is a landmine, not a live defect.

  **Fixed 2026-10-07:** all reused-worker loaders now call one helper for the
  existing derived private fit-cache field set. The helper clears fit/model
  state including `cached_mod` and best-column selections on every changed
  draw, while preserving covariate-only caches when X is unchanged and design
  caches when both X and w are unchanged. Randomization, nonparametric,
  parametric, randomization-bootstrap, and KK pass-through paths use the same
  policy; the helper is registered in DESCRIPTION's explicit Collate list.
  The reset surface contains only fields previously reset by one of those
  loaders; unrelated model data and warm-start state are untouched. Structural
  tests assert the field set and per-context preservation, and three two-draw
  tests compare reused randomization, bootstrap, and randomization-bootstrap
  estimates to fresh workers. These and adjacent loader/warm-start tests pass
  with `pkgload::load_all(compile = FALSE)`. A full
  `scripts/reused_worker_bitforbit_sweep.R` pre/post comparison still needs a
  comparable clean baseline before release; no checkout build was run.

  **Baseline recovery audit (2026-10-18):** a compile-free staging pair is
  available under `/tmp`: pre-fix source at
  `/tmp/edi-todo12-sweep-SDoSWQ0B` (the relevant randomization-loader file
  matches parent commit `362c5d28fa6233d99d6d6815d1bffa02f5aa33ab`) and
  post-fix source at
  `/tmp/edi-todo12-postfix-430c19.j40X59/EDI` (the relevant helper file
  matches `430c19bcdb0702d998c79f9058c449449034134c`). Their staged
  `R/EDI/src/EDI.so` files are byte-identical, SHA-256
  `20f5713ae07cf3c7f53b7e5b66657bce028183a1b74d778d83fe0b061135f3a9`.
  The script's `record --source` mode can therefore compare these staged R
  layers without compiling. However, no before/after RDS snapshots were found,
  and the trees span unrelated source changes; inspect every `fixed`, `noise`,
  or `MOVED` result before attributing it to the cache fix. The acceptance
  gate remains open until the two snapshots, same-package/native provenance,
  noise-floor recordings, and result classification are recorded; keep all
  snapshot outputs outside the checkout.

  **Installed regression recheck (2026-10-18):**
  `Rscript -e 'testthat::test_file("R/EDI/tests/testthat/test-reused-worker-private-cache-reset.R")'`
  passed all 55 assertions (0 failures, warnings, or skips) against installed
  EDI 1.0.3 from `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`;
  loaded `EDI.so` SHA-256 was
  `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`.
  This confirms the installed package satisfies the structural cache-reset,
  context-preservation, and focused reused-worker regression assertions. It
  does not validate the current checkout source or substitute for the open
  identical-fixture/RNG pre/post bit-for-bit sweep using the staged source
  layers and recoverable snapshots described above. No source/native build or
  canonical result generation was performed.

  **Current-R-source regression recheck (2026-10-18):** after
  `pkgload::load_all("R/EDI", compile = FALSE)`,
  `test-reused-worker-private-cache-reset.R` passed 55 assertions and
  `test-reused-worker-cached-values-for-next-draw-reference.R` passed 9
  (64 total; no failures, warnings, or skips). R source was loaded from
  `/home/kapelner/workspace/EDI/R/EDI`, version 1.0.3. The native DLL used by
  this source overlay was `/tmp/Rtmpb7icUR/pkgload36f3365760677e/EDI.so`,
  SHA-256 `23033b395c5167d2e5cb88225084a5af63febe0483671498aaf0808d802a865e`
  (same hash as the installed EDI 1.0.3 DLL). Thus the current R cache-reset
  helper and structural/context and two-draw reused-vs-fresh regressions pass
  against the existing native ABI; this does not supply the missing pre/post
  snapshots or close the release-wide sweep/classification gate. No compile,
  build, install, shared-result operation, or canonical write occurred.

  **Installed-native regression recheck, 2026-10-20:** the focused
  `test-reused-worker-private-cache-reset.R` passed all 55 assertions (0
  failures, warnings, or skips) via `testthat::test_file()` against installed
  EDI 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`. The installed
  `DESCRIPTION` SHA-256 is
  `4a90096cefbca36c7f68d2d53af5821ed7747fa20d0d359880bcd704372998f0`;
  loaded `EDI.so` SHA-256 is
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  The DLL is byte-identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9` (`cmp -s` succeeded); the
  checkout `DESCRIPTION` hash differs, and this byte match does not establish
  the DLL's source/build provenance. This is installed-artifact evidence for
  the focused reset contract only, not the release-wide paired sweep or a
  reproducible current-source/native build attestation. No build, install,
  canonical output, or sweep snapshot was produced.

  **Sweep-provenance contract (2026-10-20):** new snapshots now record the
  loaded EDI package version and namespace path, native DLL path and MD5, and
  a per-file MD5 manifest for the loaded R layer (source files in `--source`
  mode, installed lazy-load files otherwise). `compare` rejects snapshots
  without valid provenance and refuses pairs with different EDI versions or
  native DLLs; the R-layer manifest remains separately inspectable because
  pre/post source changes are intentional. The focused sweep-contract test
  passed 24 assertions against installed EDI 1.0.3. This validates the
  provenance recorder/comparator contract only: no distribution sweep or
  RDS snapshot was produced. A separate `pkgload::load_all(...,
  compile=FALSE)` probe verified `--source` mode records the 211 source R
  files and the already-loaded DLL MD5 `dfd5bf4384b5a0cc0d430fd70dab2a59`.
  Neither check fills the missing comparable pre/post run or closes TODO-9.

  **Comparator classification guard (2026-10-20):** static review found that
  `classify_change()` treated an all-NA baseline as a point mass because zero
  finite unique values satisfied the old `<= 1` condition. That could label
  an all-NA-to-varying transition as a confirmed cache fix without any finite
  baseline evidence. The comparator now reserves `fixed` for a finite
  single-valued baseline becoming variable; an all-NA transition remains
  `MOVED` for investigation. The sweep-contract regression pins both cases
  (finite point mass → `fixed`; all-NA → `MOVED`). Its focused file was run
  against installed EDI 1.0.3: the new classification assertions passed, but
  two pre-existing strict-enumeration expectations failed because that
  installed registry marks `InferenceIncidExactBinomial` differently from
  the checkout. No sweep snapshots were produced; the comparable pre/post
  artifacts and full classification remain open.

## Status

TODO-1 through TODO-6 **shipped** 2026-09-22 (commits `811e0683`,
`1c0c295e`, `db0d3f96`, `d6aa4505`, merged to `main`). Scope corrected
during implementation/review: only `load_randomization_perm_into_worker()`
needed the `cached_values` fix — the three bootstrap-family loaders already
fully wiped `cached_values` via `load_bootstrap_sample_into_design_backed_worker()`,
confirmed by reading all ten concrete implementations. Verified via a
240-distribution bit-for-bit sweep across three design families (Bernoulli,
KK-matching, blocking): 222 bit-identical (no change to already-correct
classes beyond documented ~1e-16 float noise in 5 KK compound-kernel
entries, independently reproduced by re-recording the unchanged package
twice), 13 newly non-degenerate, 0 moved to a different non-degenerate
value. A permanent regression test
(`R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R`) and
durable sweep script (`scripts/reused_worker_bitforbit_sweep.R`) now guard
against this bug class recurring. Slated for `release_v1_0_5.md → TODO-9`
(moved 2026-09-23 from `release_v1_1_0.md → TODO-31`, bug-fix/feature
split; originally shipped ahead of v1.1.0 as an out-of-band correctness
fix, per that TODO's own "may warrant revisiting ahead of the rest of
1.1.0" note — the split resolves that note by giving it its own release).

TODO-9's implementation (latent `cached_mod` gap, above) landed 2026-10-07
and is tracked at `release_v1_0_5.md → TODO-12` (was
`release_v1_1_0.md → TODO-34`). Its focused regressions pass. The item stays
open until the release-wide pre/post bit-for-bit sweep can use a comparable
clean baseline.

**TODO-12 sweep-enumeration metadata correction, 2026-10-20:** the
`InferenceIncidExactBinomial` registry record was missing its KK-matching
requirement even though its explicit compatibility guard accepts only
`DesignFixedBinaryMatch` or KK-capable designs. Added the class to
`EDI_INFERENCE_REQUIRES_KK_MATCHING_DESIGN_OVERRIDES` and extended
`test-inference-registry-capability-contracts.R` to assert both the inferred
flag and resolved registry metadata. The focused test passed 43 expectations
with checkout R code loaded using `compile = FALSE`; this used installed EDI
1.0.3 native artifact, but exercised registry/R metadata only. This corrects
the declared arm-routing flag. A no-draw strict-enumeration smoke then loaded
the runner helpers, completed registry candidate enumeration across all arms
and response types, routed ExactBinomial only to the `kk` arm, and constructed
its targeted KK-incidence candidate without error. That candidate was not a
reusable worker (`0` distribution keys); no distribution was called and no
snapshot was written. This does not run the runner's `record` mode or validate
the expected manifest against the old snapshots. No canonical artifacts were
read or written. The release-wide paired sweep, current-native verification,
and result reconciliation remain open.

**Persistent strict-candidate exclusion regression, 2026-10-20:** extended
the existing sweep-contract bulk test to exercise the runner's loaded
`resampling_nondegenerate_cases()` with the real arm and fixture helpers.
`InferenceIncidExactBinomial` is excluded from Bernoulli incidence; on the
KK-incidence fixture it constructs under `strict = TRUE` but produces zero
reusable-worker cases. No resampling distribution is invoked and no snapshot
is written. The test passed 28 expectations with checkout R sources loaded
using `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` on R 4.7.0
and the installed EDI 1.0.3 native artifact (temporary DLL MD5
`dfd5bf4384b5a0cc0d430fd70dab2a59`). It was run via
`testthat::test_file("R/package_tests/testthat_bulk/test-reused-worker-bitforbit-sweep-contracts.R")`;
the loaded DLL path was `/tmp/RtmpIYt73c/pkgload6ca786d46ea00/EDI.so` with
the same MD5. Runner, fixture, and test SHA-256 values
were `71f66399796a1534c31301c74f635c8ac5555cc0914e9fb452e8adc6173928b1`,
`5c1a428134aee72b969d06f446171d34a8d28bfb88e399b641ee7562109f2d53`, and
`cea8912eddcfa57e7bc512542646daeb68d9e2f8565135fe2e0a5b750a4487b4`.
This pins the ExactBinomial exclusion from the expected-key candidate set; it
does not establish full manifest completeness, paired parity, or current-native
validation. The same fixture also asserts that snapshot validation rejects a
duplicated expected-key manifest, covering the explicit duplicate-manifest
guard without running a distribution or recording a sweep.

**TODO-12 retained-artifact acceptance check, 2026-10-20:** read-only
inspection found the recorded `before-1.rds`, `before-2.rds`, and
`after-refined-v2.rds` under `/tmp/edi-todo12-paired-53rKFp/` and
`/tmp/edi-todo12-refined-9EdvIW/`. Their SHA-256 values match the recorded
hashes, and each contains 240 uniquely named entries; however, all three lack
both the `expected_keys` and `provenance` attributes required by the current
comparator. These artifacts cannot be promoted to acceptance by adding
metadata after the fact: their internal key-set consistency is not proof that
the current strict source-derived manifest and run-time provenance match.
The existing comparator had no focused assertion for its missing-manifest
guard, so the sweep-contract test now checks that it fails closed when
`expected_keys` is absent. The full focused test passed 31 expectations with
checkout R loaded via `pkgload::load_all(..., compile = FALSE)`; two unrelated
registry assertions fail against the stale installed EDI 1.0.3 when run
without that overlay. This test makes no distribution call and writes no
snapshot. Release-wide paired parity and current-native verification remain
open; no artifact or canonical result was modified.

**Live `/tmp` snapshot inventory (2026-10-21):** the previously recorded
`/tmp/edi-todo12-paired-53rKFp/before-1.rds`,
`/tmp/edi-todo12-paired-53rKFp/before-2.rds`, and
`/tmp/edi-todo12-refined-9EdvIW/after-refined-v2.rds` paths are absent. A
read-only search of 669 `/tmp` RDS files found no match for their recorded
SHA-256 values (`2ed850bfe71a073e36ee0aa6d264049a1062d131accbc7a9f44bbb171e14250e`,
`865e7580b555079a0359fec20e9ad455fd004de67d572b5bc3648c734789d83f`, and
`222a87ce4aac5304cdc9790c39bae4167cfa876ec2e8e117d4e7c861a2a1fb63`). The
remaining TODO-12-prefixed RDS files are synthetic contract fixtures or
staged `testthat-problems.rds`, not 240-key run snapshots. The historical
audit found 240 unique entries and matching key sets, but those files lacked
the current comparator's `expected_keys` and `provenance` attributes; that
check cannot be reproduced on extant artifacts. Current identity is HEAD
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, runner SHA-256
`f22124b58abc774b1a66b174cf18007b8048ac3a62b929e77805c9d606b19a45`. The
three fresh `r=15` snapshots (720 evaluations total) are still required. The
user explicitly prohibited this workload in the current assignment, so fresh
explicit approval is required before launch. No R run or artifact mutation
occurred in this audit.

**Current installed sweep-contract recheck, 2026-10-20:** attached installed
EDI 1.0.3 at `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI` and ran
`testthat::test_file("R/package_tests/testthat_bulk/test-reused-worker-bitforbit-sweep-contracts.R")`.
All 31 expectations passed, including installed-registry routing, mocked
constructor/distribution failures, key/NA/provenance rejection, and the
all-NA classification guard. The test sources the current checkout sweep
runner (`scripts/reused_worker_bitforbit_sweep.R`, SHA-256
`4510d0e8a56ffa681c84e3de8e7057b44c87f8bb581c88b8f0114ffb8c5e6bdf`) and
uses the installed namespace for registry lookups; test SHA-256 is
`a63dd474cf8f907112d1dcba0c56999180badf124b50484845646f84382ca922`.
Installed DESCRIPTION SHA-256 is
`9bc2620857fc1dce03c0cf8f0ce91f51c2385da011fb8d8c6f4264ef9c9231c5`; loaded
`EDI.so` SHA-256 is
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
This deterministic contract test calls no resampling distribution and writes
no sweep snapshot. It newly confirms the harness guards against the current
installed package, but does not exercise the `cached_mod` reset on an actual
reused-worker draw, reconcile the retained RDS files, or close release-wide
paired parity/current-native provenance.

**Positive paired-comparison contract, 2026-10-20:** extended the existing
bulk sweep-contract test with a two-key synthetic successful comparison. Both
snapshots have the same expected-key manifest, package version, and native-DLL
digest, while their provenance intentionally distinguishes installed lazy-load
R code from checkout source R code; one distribution is unchanged and the
other is substantively moved. The comparator reports one bit-identical and
one `MOVED` entry. The focused command
`Rscript -e 'pkgload::load_all("R/EDI", compile=FALSE, quiet=TRUE); testthat::test_file("R/package_tests/testthat_bulk/test-reused-worker-bitforbit-sweep-contracts.R")'`
passed 37 expectations with no failures, warnings, or skips. Namespace:
`/home/kapelner/workspace/EDI/R/EDI`, EDI 1.0.3, R Under development
`(2026-10-13 r90668)`; loaded temporary DLL
`/tmp/RtmpgfEUCP/pkgloadcdc3fc016909/EDI.so`, MD5
`8b3ca30492d7b1c790deeebe94b201ad`. Test SHA-256
`32fa2407c994826374e3c2cb56717a2173e8f354231799a97b081989ab39ab9a`.
This validates comparator acceptance only: it generates no sweep distributions
or snapshots and does not close paired parity, retained-artifact
reconciliation, or current-native validation.

**TODO-12 720-distribution preflight, 2026-10-21:** the proposed workload is
three snapshots of the exact 240-key source-derived roster: two same-source
pre-fix recordings for the noise floor, then one post-fix recording. Each key
is `class|arm|response_type|production/forced`; enumeration reuses the
nondegenerate fixture/registry helpers, strict arm/design construction, and
reusable-worker capability checks (not a hand-built Cartesian roster). The
fixture contract is `r = 15`, seed `20260922`, arms Bernoulli/KK/blocking, and
the six response types continuous/incidence/count/proportion/ordinal/survival.
Acceptance requires all three snapshots to contain the same 240 unique keys,
each numeric length 15 with no infinite non-NA values; the two pre snapshots
establish repeat noise, and pre/post comparison must preserve key and NA
patterns and classify every changed distribution for review. Provenance must
pin the package version and identical native DLL across all snapshots while
externally recording the exact R source, fixture, runner, seed, HEAD/worktree
state, and run inputs. The earlier 240-entry snapshots and staging directories
named above are no longer present under their recorded `/tmp` paths; the
bounded current `/tmp` inventory found only tiny synthetic comparator fixtures,
not usable paired distributions. At preflight, HEAD was
`4f7a6e4ca82829e880c15a76699701a95e5e83b9`, the working-tree runner SHA-256
was `4510d0e8a56ffa681c84e3de8e7057b44c87f8bb581c88b8f0114ffb8c5e6bdf`, and
the fixture SHA-256 was
`5c1a428134aee72b969d06f446171d34a8d28bfb88e399b641ee7562109f2d53`. The
installed and staged `EDI.so` files currently match at SHA-256
`0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0` (both
dated 2026-10-21 09:43), but these point-in-time identities do not authenticate
the absent historical snapshots or define the historical pre-fix source
bundle. No workload, R test, canonical write, or output generation was done;
the three-snapshot run remains pending explicit approval and a frozen,
reproducible pre/post input bundle.

**Checkout-R cache-reset regression recheck, 2026-10-20:**
`test-reused-worker-private-cache-reset.R` passed all 55 assertions (0
failures, warnings, or skips) after loading checkout R sources with
`pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)` and running
`testthat::test_file(...)`. The test covers structural/context-preserving
cache reset and fresh-versus-reused OLS estimates for randomization,
bootstrap, and randomization-bootstrap draws. Runtime provenance: R Under
development (2026-10-13 r90668), EDI 1.0.3, namespace
`/home/kapelner/workspace/EDI/R/EDI`; the loaded temporary DLL MD5 was
`8b3ca30492d7b1c790deeebe94b201ad`. This matches installed and ignored
checkout `EDI.so` SHA-256
`db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
No build/install, sweep, or result write occurred. This strengthens the
focused source-overlay cache-reset check only; it is distinct from the
release-wide 614-file paired sweep on identical fixtures and RNG seeds. That
sweep, classification review, and its native/provenance requirements remain
open.

TODO-7 (CSV regeneration and baseline rewrite) remains open and is owned by
the earlier release TODO-9. TODO-8's published-output audit is complete:
the codebase and public site needed no numeric correction, and the site was
redeployed to remove the obsolete caveat.

Two pre-existing, unrelated defects were discovered by this plan's expanded
test coverage (NOT the `cached_values`/`cached_mod` mechanism — two
different, distinct bugs), root-caused 2026-09-22 and **both fixed
2026-09-23**:
- `InferencePropGCompMeanDiff` — randomization distribution all-NA in
  production. Root cause: worker-state gating (`sample_usable` flag only
  set by the bootstrap loader, never the randomization loader). **Fixed**
  (class-specific `compute_randomization_worker_estimate()` override,
  verified 99/99 finite draws, Type-I error nominal). Tracked at
  `prop_gcomp_sample_usable_gating.md` /
  `release_v1_0_5.md → TODO-13` (was `release_v1_1_0.md → TODO-35`). CSV
  regeneration still open there.
- `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` — same NA symptom.
  Root cause: plain NA-propagation in an inverse-variance pooling step
  (`shared()` uses `ssq_m`/`ssq_r`, which are deliberately `NA` under
  `estimate_only = TRUE`), unguarded despite the file already containing a
  correct reference implementation of the guard elsewhere. **Fixed**
  (equal-weight fallback added, matching the existing reference pattern;
  verified `estimate_only = FALSE` unchanged bit-for-bit, `TRUE` now
  finite, reused-worker `rand` distribution 99/99 finite). Tracked at
  `glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md` /
  `release_v1_0_5.md → TODO-14` (was `release_v1_1_0.md → TODO-36`). CSV
  regeneration still open there.

Both fixed classes have been removed from
`RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
`test-reused-worker-resampling-nondegenerate.R` (per those plans' Status
sections) — check whether that test file's list is now empty, since an
empty `KNOWN_BROKEN` list changes the vacuity-canary behavior noted as
Minor finding #3 in this plan's final review (the guard against a global
test breakage silently passing relied on that list staying non-empty).

A third, separate defect (also from the same original `bad_type1_error`
audit wave, also originally miscategorized as this bug's mechanism) was
investigated 2026-09-23 and remains open, NOT fixed: `InferenceContinLin`'s
parametric-bootstrap/likelihood-ratio methods
(`compute_lik_ratio_bootstrap_two_sided_pval`,
`compute_param_bootstrap_pval`,
`compute_lik_ratio_bartlett_approx_two_sided_pval`) have inflated,
design-dependent Type-I error via a separate mechanism (not the reused-
worker `rand` path, which IS fixed for this class). Tracked at
`contin_lin_param_bootstrap_bad_type1_error.md` /
`release_v1_0_5.md → TODO-15` (was `release_v1_1_0.md → TODO-37`).

Both are carried as self-retiring `KNOWN_BROKEN` entries in the new
regression test (they fail loudly via `expect_identical` once fixed) so
they cannot silently stay broken forever.

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: this is a bug fix, not
a new default — "additive" here means restoring the *documented* contract
(a genuinely-varying resampling distribution, correctly-calibrated
p-values), not introducing a new opt-in switch. A class whose resampling
distribution was already correctly varying must produce bit-for-bit
identical results after the fix (TODO-3/TODO-5 verify this). No
`R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn (see
top-level `CLAUDE.md`); verify via targeted compile only if any `.cpp` is
touched (none expected — this is R-layer cache-management logic in the
reused-worker machinery, not a kernel), never a full build.
