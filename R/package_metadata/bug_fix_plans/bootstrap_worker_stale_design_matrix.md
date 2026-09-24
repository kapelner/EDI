# Fix: Reused Bootstrap Worker Never Resets `cached_design_matrix` — Scrambled Data/Weight Correspondence Across Draws

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-28`. Found 2026-09-24, via a dedicated
> cross-class investigation into why `InferenceContinOLS`,
> `InferenceContinLin`, `InferenceIncidLogBinomial`, and
> `InferenceSurvivalWeibullRegr` all showed the same `model_formula=~.`-
> specific severe miscalibration signature (tracked separately in
> `investigate_contin_ols_weighted_bootstrap_se.md` / `release_v1_0_5.md →
> TODO-25`, and `contin_lin_param_bootstrap_bad_type1_error.md` /
> `TODO-15`). **High confidence — confirmed by direct code reading, not
> hypothesized.**

## The bug

`load_bootstrap_sample_into_design_backed_worker()`
(`R/EDI/R/inference_all_abstract_non_param_boot.R:1191-1235` — the loader
used by `subsampling`, `m_out_of_n_bootstrap`, and plain `bootstrap`)
resets `cached_values`, `cached_mod`, `reduced_design_keep_cache`,
`fixed_covariate_keep_cache`, `best_X_colnames`, `best_Xmm_colnames`
between draws (`:1216-1225`) — this is the exact loader this session's
original stale-cache fix (`stale_worker_cache_resampling.md`) already
confirmed "fully wipes `cached_values`" and treated as the *correctly-
behaving* reference implementation the broken `rand` loader needed to
match.

**It is not fully correct either.** It never resets
`w_priv$cached_design_matrix`, even though it DOES correctly reset
`w_priv$w`/`w_priv$X` to the current draw's resampled rows (`:1200-1205`).
`create_design_matrix()` (`inference_all_abstract.R:1032-1034`)
unconditionally returns the cached matrix if one already exists:
```r
dm = private$cached_design_matrix
if (!is.null(dm)) return(dm)
```
So every draw after the first silently reuses **draw 1's** design matrix
(draw 1's treatment column, draw 1's covariate rows) while the *weights*
being applied to it are correctly the *current* draw's — a scrambled
correspondence between the resampled/reweighted data and the design
matrix it's supposedly built from, repeating on every draw after the
first.

This is the same allowlist-not-denylist shape as this session's original
bug (`cached_values` reset), and the same category as the still-open
`release_v1_0_5.md → TODO-12` (`cached_mod` gap in a *different* loader,
`load_randomization_perm_into_worker()`) — just a different private field
(`cached_design_matrix`, not named in TODO-12's list) in what was
previously believed to be the one loader that already got this right.

## Scope: confirmed shared across (at least) four classes

All four classes declare their own `compute_estimate_with_bootstrap_weights()`
override, and all four call `private$expand_subject_or_block_weights_to_row_weights()`
then `private$create_design_matrix()` — the same shared, unguarded-cache
code path (confirmed by direct grep and read for `InferenceContinOLS`;
confirmed all four call the same entry-point function, not individually
re-verified for the other three classes' exact internal call graph beyond
that).

**Exact match for `InferenceContinOLS`**: this mechanism precisely
explains its worst-affected families — `subsampling` (reject=0.19) and
`m_out_of_n_bootstrap` (reject=0.16) are literally the two families that
call this exact loader function.

**Not fully explained**: `InferenceContinOLS`'s `bayesian_bootstrap`
families are also badly affected, but `load_bayesian_bootstrap_draw_into_worker`
doesn't resample row order, only reweights — not confirmed how (or
whether) this same stale-`cached_design_matrix` mechanism reaches
Bayesian-bootstrap calls. Plausible, unconfirmed explanation: if the same
underlying worker/cache persists across an earlier `subsampling`/
`m_out_of_n_bootstrap` call and a later `bayesian_bootstrap` call on the
same object instance, the earlier calls' scrambled
`cached_design_matrix` would still be stale for the later call too.

## Scope update 2026-09-24: confirmed to reach 3 more classes, 10 more ruled out

A wave of dedicated cross-class investigation forks (dispatched to chase
down the audit's remaining `low_coverage`/`biased_estimate` cells)
independently confirmed this exact mechanism — `create_design_matrix()`'s
unguarded cache, read directly inside a class's bootstrap-weighted refit
path — in several more classes, via direct call-chain reads (not
inference from naming):

**Confirmed, same mechanism, high confidence (direct call-chain read):**
- `InferenceContinRobustRegr` — `build_design_matrix()` →
  `create_design_matrix()` (`inference_continuous_robust_regr.R:102,236`);
  also uses `load_bootstrap_sample_into_design_backed_worker()` for its
  reused-worker path (`:227-228`), so both its bootstrap mechanisms share
  the stale cache.
- `InferencePropFractionalLogit` — `build_design_matrix()` →
  `create_design_matrix()` (`inference_proportion_fractional_logit.R:182,347-348`);
  `supports_reusable_bootstrap_worker()` confirmed `TRUE`
  (`:245-247`), so it genuinely reaches the reused-worker path.
- `InferencePropGCompMeanDiff` — confirmed call-graph match (worker-state
  investigation fork); its `biased_estimate` finding is separate/
  unexplained and should not be assumed to share this cause.

**Ruled out 2026-09-24 (direct re-check — a prior fork's "confirmed" call
above was incomplete, see below):** `InferenceContinKKGLMM`,
`InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM` (all three compose the
shared `"KKGLMM"` component, `inference_mixin_kk_glmm_shared.R`, whose
`glmm_predictors_df()` does call `private$create_design_matrix()`
directly) and `InferenceOrdinalKKCLMM` + its three link-function
subclasses (`InferenceOrdinalKKCLMMProbit`, `InferenceOrdinalKKCLMMCauchit`,
`InferenceOrdinalKKCLMMCloglog`; identical pattern via
`compute_estimate_with_bootstrap_weights()` →
`compute_weighted_clmm_estimate()` → `clmm_X_for_rcpp()` →
`clmm_predictors_df()` → `create_design_matrix()`). A prior investigation
fork flagged all 7 as "confirmed, same mechanism" based only on that call
chain existing, without checking whether the class ever actually reaches
the *stale* branch of that cache. Re-checked directly: none of these 7
classes (nor the `KKGLMM`/`KKPassThrough`/`BayesianBootstrap`/`Wald`
components they compose) override `supports_reusable_bootstrap_worker()`,
so all 7 inherit the base default `FALSE`
(`inference_all_abstract_non_param_boot.R:1090-1092`). Confirmed via the
Bayesian-bootstrap driver (`inference_all_abstract_bayesian_bootstrap.R:192-246`):
when `supports_reusable_bootstrap_worker()` is `FALSE`, every draw gets a
**fresh** `worker_inf = inf_template$duplicate(...)` before calling
`compute_estimate_with_bootstrap_weights()`. Since these classes' design
matrix depends only on `w`/covariates (unchanged across Bayesian-bootstrap
draws, which reweight rather than resample rows) and never on
`load_bootstrap_sample_into_design_backed_worker()` (the actually-buggy
loader, confirmed unreached by any of these 7 — they never call
`supports_reusable_bootstrap_worker() == TRUE`), `cached_design_matrix`
cannot go stale across draws for this whole cluster. If any of these 7
show real `low_coverage`/`biased_estimate` findings in the audit, it is a
different, not-yet-investigated mechanism — see `release_v1_0_5.md →
TODO-28`'s own note on this for the parallel ruling-out of
`InferencePropKKGLMM` and its two incidence siblings below.

**Refuted for this bug (does not call `create_design_matrix()` at all,
so needs independent root-causing) — confirmed by direct code read:**
- `InferenceContinKKOLSOneLik`, `InferenceContinKKRobustRegrOneLik` —
  build `X_comb` directly from `KKstats$X_matched_diffs`/`X_reservoir`,
  cached via `reduce_design_matrix_once(..., cache_key=...)`
  (`inference_continuous_KK_ols_one_lik.R:459-506`,
  `inference_continuous_KK_robust_regr_one_lik.R:104-113`) — that cache
  lives in `private$cached_values[[cache_key]]`, which IS correctly wiped
  by the bootstrap loader and additionally self-validates on `ncol(X)`.
  Looks correctly designed; their `low_coverage` flags are unexplained.
- `InferencePropBetaRegr` — custom uncached `build_design_matrix()`
  (`inference_proportion_beta.R:657-660`). Unexplained cause.
- `InferencePropZeroOneInflatedBetaRegr` — uses
  `build_component_matrix()`, a different two-component builder, not
  `create_design_matrix()`. Unexplained cause, not traced further.
- `InferencePropKKGLMM`, `InferenceIncidKKCondLogitGLMMIVWC`,
  `InferenceIncidKKCondLogitGLMMOneLik` — architecturally distinct despite
  the name: all three inherit `InferenceAbstractKKCondLogitGLMM`, which
  composes `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "KKPassThrough")` — no `"KKGLMM"` component. **Upgraded to high
  confidence 2026-09-24**: its bootstrap-weight path now read directly —
  `compute_estimate_with_bootstrap_weights()`
  (`inference_incidence_KK_cond_logit_glmm_abstract.R:80-99`) does call
  `X_fit = private$create_design_matrix()` at line 99, same broken cached
  path — but `supports_reusable_bootstrap_worker()` is not overridden
  anywhere in this hierarchy, so it inherits the base `FALSE`, giving it
  the same fresh-`duplicate()`-per-draw immunity confirmed above for the
  `KKGLMM`/`KKCLMM` cluster. Their `low_coverage` findings remain
  unexplained by this bug.

**Unresolved, not traced to a conclusion:**
- `InferenceContinKKQuantileRegrOneLik` — composed from a registered
  component (`components = c("BayesianBootstrap", "Wald",
  "KKQuantileRegrOneLik")`, `inference_continuous_KK_quantile_regr_one_lik.R:60`);
  the actual `compute_estimate_with_bootstrap_weights()` body lives in
  component source not read by that fork. By analogy to its OneLik
  siblings above, likely NOT this bug, but unconfirmed. Independently has
  its own pre-existing lead at `TODO-20` (with-replacement bootstrap +
  quantile-regression tie sensitivity) worth checking first.
- `InferenceOrdinalGCompMeanDiff` — GComp-family staleness check not
  done for this class specifically.
- The other GComp-family siblings (`InferenceIncidGCompRiskDiff`/
  `RiskRatio` and their KK variants) — plausible-but-unverified TODO-28
  candidates by architectural similarity to `InferencePropGCompMeanDiff`,
  not individually call-graph-confirmed.

**Net effect:** this bug's confirmed scope has grown from 4 classes to
**6** (the original 4, plus `InferenceContinRobustRegr` and
`InferencePropFractionalLogit`; separately, `InferenceCountRobustPoisson`
was confirmed via `release_v1_0_5.md → TODO-28`, bringing the total to
**7**), plus `InferencePropGCompMeanDiff` (call-graph match, unconfirmed
`supports_reusable_bootstrap_worker()` status). The entire "KKGLMM"/
"KKCLMM"-named cluster (7 classes) and the `InferenceAbstractKKCondLogitGLMM`
cluster (3 classes) were investigated and **ruled out** — 10 classes total,
none susceptible, all use the fresh-per-draw-`duplicate()` path instead of
the reused worker this bug requires. Still making this very
likely the single highest-impact fix this whole audit arc has surfaced.
TODO-4's reproduction step must now be re-scoped to check this full
expanded class list, not just the original 4, once the fix lands.
Several `low_coverage`/`biased_estimate` findings across the continuous/
proportion/GComp families remain genuinely unexplained by this bug and
need independent root-causing — do not assume they'll be fixed by this
patch.

## Related sibling cache possibly also affected — not yet checked

`cached_hardened_X_cov` (set inside `create_design_matrix()` itself, per
`inference_all_abstract.R:1036`/`:1049`) is also never invalidated by this
loader — likely needs the same reset treatment, not yet confirmed.

## Proposed fix

Add `w_priv$cached_design_matrix = NULL` (and `cached_hardened_X_cov`,
pending TODO-2 below) to `load_bootstrap_sample_into_design_backed_worker()`'s
reset list. Per this session's own established direction (see
`stale_worker_cache_resampling.md`'s TODO-9/TODO-12 discussion),
prefer routing this through whatever shared keep-list/reset mechanism the
earlier `cached_values` fix introduced (`EDI_REUSED_WORKER_CACHE_KEEP_KEYS`/
`reused_worker_preserved_cache_keys()`) rather than another hand-maintained
field list — this bug is a direct instance of exactly the pattern that
mechanism was built to prevent, just for a field outside `cached_values`
(private fields, the same category TODO-12 already covers for a different
loader). Worth considering whether TODO-12's eventual fix and this one
should be unified into one general private-field reset pass across all
reused-worker loaders, rather than three separate per-loader patches.

## TODOs

- [ ] TODO-1: Confirm the fix's scope precisely — for each of the 4
  classes (`InferenceContinOLS`, `InferenceContinLin`,
  `InferenceIncidLogBinomial`, `InferenceSurvivalWeibullRegr`), verify
  their `compute_estimate_with_bootstrap_weights()` override actually
  depends on `create_design_matrix()`'s cache the same way `InferenceContinOLS`'s
  does (confirmed only for OLS so far).
- [ ] TODO-2: Check whether `cached_hardened_X_cov` (and any other private
  field `create_design_matrix()` sets internally) needs the same reset.
- [ ] TODO-3: Implement the fix — add the missing reset(s) to
  `load_bootstrap_sample_into_design_backed_worker()`, ideally unified
  with `TODO-12`'s eventual private-field-reset mechanism rather than as
  an independent patch.
- [ ] TODO-4: Reproduce directly via `pkgload::load_all(".", compile = FALSE)`
  only (never `R CMD INSTALL`/`R CMD build`/`pkgbuild::compile_dll()`/
  `load_all(compile = TRUE)` or unspecified `compile=` — hard project
  rule, top-level `CLAUDE.md`). Confirm the fix resolves
  `InferenceContinOLS`'s `subsampling`/`m_out_of_n_bootstrap` inflation
  first (the class/families with an exact, confirmed mechanistic match),
  then check whether it also resolves `InferenceContinLin`,
  `InferenceIncidLogBinomial`, and `InferenceSurvivalWeibullRegr`'s
  `~.`-specific findings — this may fully close `TODO-15`/`TODO-25` and
  the other two classes' open leads, or may only partially explain them
  (each of those investigations found their own candidate mechanism too,
  not yet confirmed to be the same bug or a compounding second bug).
- [ ] TODO-5: Investigate the `bayesian_bootstrap`-family involvement for
  `InferenceContinOLS` specifically — confirm or refute the
  same-worker-persists-across-calls explanation.
- [ ] TODO-6: Verify the fix doesn't change results for currently-correct
  cases (e.g. `model_formula=~1`, or classes/methods not affected by this
  bug) — bit-for-bit or floating-point tolerance, matching this session's
  standing discipline for reused-worker cache fixes.
- [ ] TODO-7: Add a permanent regression test analogous to
  `stale_worker_cache_resampling.md`'s TODO-6 — a fixture with
  `model_formula=~.` (multiple covariates) run through
  `subsampling`/`m_out_of_n_bootstrap`, asserting the resampling
  distribution is not degenerate/miscalibrated, specifically covering the
  `compute_estimate_with_bootstrap_weights()` path this bug lives in
  (the existing non-degeneracy test may not exercise this exact path —
  confirm).
- [ ] TODO-8: Once fixed, update `TODO-15`/`TODO-25` and the survival/
  incidence cluster investigation notes to reflect whether this fix fully
  or partially resolves each of the four classes' findings.
- [ ] TODO-9: Regenerate affected `comprehensive_tests` CSV rows once
  fixed and installed (only after install, not before).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. A
class/method combination not affected by this bug (e.g. `model_formula=~1`,
where there's only one column and a stale-vs-current design matrix
mismatch is far less consequential or possibly a no-op) must remain
bit-for-bit unchanged by the fix.
