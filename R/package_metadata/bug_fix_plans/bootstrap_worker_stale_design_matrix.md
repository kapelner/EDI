# Audit: Reused Bootstrap Worker Already Resets `cached_design_matrix`

> **Status correction (2026-10-07):** The reported source bug is absent from
> current HEAD. `load_bootstrap_sample_into_design_backed_worker()` has reset
> `cached_design_matrix`, `cached_hardened_X_cov`, and related design caches
> since commit `8aa321146` (2026-06-01), predating this plan. The historical
> investigation below describes a risk that the current loader already
> prevents; its class-specific calibration findings remain separate open
> questions. A new two-draw `InferenceContinOLS(model_formula = ~.)` regression
> confirms that a reused worker's second estimate matches both a fresh worker
> and an independent `lm.fit()`. The focused loader suite passed 48 expectations
> with `pkgload::load_all("R/EDI", compile = FALSE)` and no build.

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-28`. Found 2026-09-24, via a dedicated
> cross-class investigation into why `InferenceContinOLS`,
> `InferenceContinLin`, `InferenceIncidLogBinomial`, and
> `InferenceSurvivalWeibullRegr` all showed the same `model_formula=~.`-
> specific severe miscalibration signature (tracked separately in
> `investigate_contin_ols_weighted_bootstrap_se.md` / `release_v1_0_5.md →
> TODO-25`, and `contin_lin_param_bootstrap_bad_type1_error.md` /
> `TODO-15`). The cache diagnosis in that investigation was refuted by
> the 2026-10-07 source and history check above.

## Historical finding (superseded by the status correction)

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

The original report claimed it never reset `w_priv$cached_design_matrix`.
That claim was wrong for current HEAD: the loader resets it at line 1239,
immediately after updating `w_priv$w`/`w_priv$X` to the current draw.
`create_design_matrix()` (`inference_all_abstract.R:1032-1034`)
unconditionally returns the cached matrix if one already exists:
```r
dm = private$cached_design_matrix
if (!is.null(dm)) return(dm)
```
Without the loader reset, draws after the first could reuse draw 1's
design matrix. The current reset prevents this specific mismatch.

The original report compared this to the allowlist-not-denylist shape of
the earlier `cached_values` bug, and the category of the then-open
`release_v1_0_5.md → TODO-12` (`cached_mod` gap in a *different* loader,
`load_randomization_perm_into_worker()`) — just a different private field
(`cached_design_matrix`, not named in TODO-12's list) in what was
previously believed to be the one loader that already got this right.

## Historical scope hypotheses (do not attribute current calibration findings to this cache)

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

**GComp-family verification, 2026-09-24 (settled):**
- **CONFIRMED — 4 more classes**: `InferenceIncidGCompRiskDiff`,
  `InferenceIncidGCompRiskRatio` (`inference_incidence_gcomp.R`) and
  `InferenceIncidKKGCompRiskDiff`, `InferenceIncidKKGCompRiskRatio`
  (`inference_incidence_KK_marginal.R`) all have `build_design_matrix()`
  → `create_design_matrix()` AND `supports_reusable_bootstrap_worker() =
  TRUE` (via the shared `incidence_gcomp_worker_overrides`/
  `incidence_kk_gcomp_worker_overrides` lists in
  `inference_incidence_gcomp.R`/`inference_incidence_KK_gcomp_abstract.R`),
  and both conditions route through `create_bootstrap_worker_state()` →
  `create_design_backed_bootstrap_worker_state()` and
  `load_bootstrap_sample_into_worker()` →
  `load_bootstrap_sample_into_design_backed_worker()` — the literal same
  buggy loader function this whole plan is about. Direct code read, both
  conditions independently verified per class, no naming-similarity
  shortcut taken.
- **RULED OUT**: `InferenceOrdinalGCompMeanDiff`
  (`inference_ordinal_gcomp.R:223-228`) — its `build_design_matrix()` is a
  custom, uncached implementation (`X_cov = private$X; cbind(...)`) that
  never calls `create_design_matrix()` at all. Condition (1) fails
  outright; `supports_reusable_bootstrap_worker()` status is moot. Its
  `low_coverage`/`biased_estimate` findings are genuinely unexplained by
  this bug.

**Net effect:** this bug's confirmed scope has grown from 4 classes to
**6** (the original 4, plus `InferenceContinRobustRegr` and
`InferencePropFractionalLogit`; separately, `InferenceCountRobustPoisson`
was confirmed via `release_v1_0_5.md → TODO-28`, bringing the total to
**7**), plus `InferencePropGCompMeanDiff` (call-graph match, unconfirmed
`supports_reusable_bootstrap_worker()` status) and now **4 more
confirmed GComp-family classes** (`InferenceIncidGCompRiskDiff`/
`RiskRatio`/`KKGCompRiskDiff`/`KKGCompRiskRatio`), bringing the total
confirmed count to **12**. The entire "KKGLMM"/
"KKCLMM"-named cluster (7 classes), the `InferenceAbstractKKCondLogitGLMM`
cluster (3 classes), and now `InferenceOrdinalGCompMeanDiff` were
investigated and **ruled out** — 11 classes total,
none susceptible, either using the fresh-per-draw-`duplicate()` path
instead of the reused worker this bug requires, or never calling
`create_design_matrix()` at all. Still making this very
likely the single highest-impact fix this whole audit arc has surfaced.
TODO-4's reproduction step must now be re-scoped to check this full
expanded class list, not just the original 4, once the fix lands.
Several `low_coverage`/`biased_estimate` findings across the continuous/
proportion/GComp families remain genuinely unexplained by this bug and
need independent root-causing — do not assume they'll be fixed by this
patch.

## Related sibling cache — already reset

`cached_hardened_X_cov` (set inside `create_design_matrix()`, per
`inference_all_abstract.R:1036`/`:1049`) is already invalidated by this
loader at line 1242.

## Fix already present in HEAD

`w_priv$cached_design_matrix = NULL` and `cached_hardened_X_cov = NULL` are
already in `load_bootstrap_sample_into_design_backed_worker()`'s reset list,
along with the related design caches. The later TODO-12 implementation
centralized this private-field reset surface in one context-aware helper
shared by every reused-worker loader, so these fields no longer depend on
separate hand-maintained lists.

## TODOs

**Disposition audit, 2026-10-07:** the source premise was false: the reset
already existed before this plan. Every historical item below is therefore
closed for this plan. Items about unexplained class calibration were
transferred to their existing release TODOs (especially TODO-15, TODO-20,
and TODO-25); `[x]` here means no action remains under the refuted
`cached_design_matrix` hypothesis, not that those independent findings were
resolved.

- [x] TODO-1: Closed as inapplicable; there is no missing-reset fix whose
  class scope needs enumeration. Class-specific calibration findings remain
  in their own release TODOs.
- [x] TODO-2: Confirmed that the existing loader clears
  `cached_design_matrix`, `cached_hardened_X_cov`, and the related fields.
- [x] TODO-3: No fix was required. The existing resets were later
  centralized by release TODO-12.
- [x] TODO-4: A source-loaded two-draw OLS regression refuted the premise:
  the reused worker matches a fresh worker and `lm.fit()`.
- [x] TODO-5: The independent OLS Bayesian-bootstrap question is owned by
  release TODO-25; no work remains under this cache hypothesis.
- [x] TODO-6: Inapplicable because closing the finding changed no source
  behavior.
- [x] TODO-7: Added the permanent multi-covariate, two-draw reused-worker
  regression described above.
- [x] TODO-8: TODO-15 and TODO-25 now state that this refuted hypothesis does
  not explain their findings.
- [x] TODO-9: Inapplicable; the nonexistent bug affected no historical rows.
- [x] TODO-10: Ruled out for this cache hypothesis because the loader reset is
  unconditional. The independent quantile-regression tie-sensitivity lead
  remains release TODO-20.

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build. A
class/method combination not affected by this bug (e.g. `model_formula=~1`,
where there's only one column and a stale-vs-current design matrix
mismatch is far less consequential or possibly a no-op) must remain
bit-for-bit unchanged by the fix.
