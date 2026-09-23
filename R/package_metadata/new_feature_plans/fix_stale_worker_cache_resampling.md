# Fix: Stale Worker-Cache in Reused-Worker Resampling — Degenerate Randomization/Bootstrap Distributions

> **Depends on:** none. (Global ordering: see `_master.md`.) TODO-1..6
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
  of scope here (see `fix_contin_lin_param_bootstrap_bad_type1_error.md`).
  Scoped regen ran clean for all 7 classes (2400+ calls, 0 errors) and was
  merged into the real result CSVs the audit reads.

  **Blocker:** `audit_comprehensive_results.R` pools every historical row
  ever recorded for a `(class, function_run)` cell — not time-aware. A few
  hundred fresh "ok" rows are swamped by hundreds of leftover pre-fix rows
  in these 300-600MB files: `InferenceOrdinalGCompMeanDiff`'s `rand`
  p-value still shows reject-rate 0.952 (z=114.8), nearly identical to the
  original bug report, purely from old rows still mixed in. The correct
  tool exists (`R/package_tests/prune_stale_result_rows.R` +
  `stale_ok_row_rules.csv`, which expires pre-fix rows for a cell before a
  given commit timestamp) but was NOT used: `stale_ok_row_rules.csv` was
  under active concurrent edit by another session at the time (12 new
  TODO-32-related rules staged), and bulk-rewriting shared CI-gating
  result files plus the project-wide audit baseline is consequential and
  hard to reverse — not a unilateral mid-task call.

  **Two new findings surfaced by the regen, need a look before assuming
  "just needs pruning":**
  - `InferenceIncidKKGCompRiskDiff`/`RiskRatio` now show a **deflated**
    Type-I error (reject=0.0047, z=-4.3) — opposite direction from the
    stale-cache symptom, unexplained.
  - `InferenceIncidGCompRiskDiff`/`RiskRatio` show a new `low_power` flag
    at `beta_T≠0`.

  **Next steps, not yet executed:** add `stale_ok_row_rules.csv` rules for
  these 7 classes' `rand`/`rand_custom` two-sided-pval functions,
  `before_timestamp` just before commit `811e0683` (2026-09-22 13:45 IDT),
  `tracked_in = commit:811e0683`; run `prune_stale_result_rows.R --apply`;
  re-run `audit_comprehensive_results.R --write-baseline`. Hold until the
  other session's `stale_ok_row_rules.csv` edits settle and the two new
  findings above are triaged.

  New rows are already live in the 3 main result CSVs (harmless — this is
  what the harness would produce on its next unfiltered run regardless).
  No compile/install command was run at any point.
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
- [ ] TODO-9 (added 2026-09-22, found during this plan's own final
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

  **Not fixed in this plan's branch (deliberately, per the final review's
  own risk assessment):** no concrete class currently reaches this guard —
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

  **Fix, when picked up:** reconcile the three separately-maintained
  private-field reset lists (`inference_all_abstract_rand.R:970-978`,
  `inference_all_abstract_non_param_boot.R:1216-1225`,
  `inference_all_abstract_param_boot.R:913-917`, plus
  `inference_mixin_kk_passthrough.R:319-330`, a third differently-scoped
  list) the same way TODO-4 reconciled `cached_values` — a single
  keep-list-driven reset shared by all reused-worker loaders, so the three
  lists can't drift apart the way the original bug's `cached_values` reset
  did. Minimum: add `cached_mod` (+ `best_X_colnames`/`best_Xmm_colnames`)
  to the rand loader's private-field reset, matching the bootstrap loader.
  Should be a no-op for every currently-correct class (nothing reads
  `cached_mod` before `shared()` writes it), but changes the reset surface,
  so it needs a re-run of `scripts/reused_worker_bitforbit_sweep.R` (added
  by this plan) before shipping, same standing-constraint discipline as
  TODO-3/TODO-5 used for `cached_values`.

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

TODO-9 (latent `cached_mod` gap, above) is open, not yet fixed, tracked
separately at `release_v1_0_5.md → TODO-12` (was
`release_v1_1_0.md → TODO-34`).

TODO-7 (CSV regen) and TODO-8 (published-output audit) remain open,
deferred until an install is available — the fix's own final review notes
the package has since been reinstalled by the user
(2026-09-22), so TODO-7 is now unblocked whenever the user chooses to run
it; TODO-8 is an editorial decision, still outstanding.

Two pre-existing, unrelated defects were discovered by this plan's expanded
test coverage (NOT the `cached_values`/`cached_mod` mechanism — two
different, distinct bugs), root-caused 2026-09-22 and **both fixed
2026-09-23**:
- `InferencePropGCompMeanDiff` — randomization distribution all-NA in
  production. Root cause: worker-state gating (`sample_usable` flag only
  set by the bootstrap loader, never the randomization loader). **Fixed**
  (class-specific `compute_randomization_worker_estimate()` override,
  verified 99/99 finite draws, Type-I error nominal). Tracked at
  `fix_prop_gcomp_sample_usable_gating.md` /
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
  `fix_glmm_weibull_frailty_ivwc_estimate_only_na_pooling.md` /
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
`fix_contin_lin_param_bootstrap_bad_type1_error.md` /
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
