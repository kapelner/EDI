# Investigation: Six Classes With Confirmed-Real `low_coverage`/Unexplained Flags — Ruled Out From The Stale-`cached_design_matrix` Bug

> **Depends on:** none. (Global ordering: see `_master.md`.) Slated for
> `release_v1_0_5.md → TODO-52`. Surfaced 2026-09-24 as a byproduct of
> `bootstrap_worker_stale_design_matrix.md`'s (TODO-28) cross-class sweep —
> each class below was checked specifically against that bug's mechanism,
> confirmed NOT to share it, and then left as an unexplained aside with no
> TODO number or plan file, same pattern as `investigate_count_family_unexplained_miscalibration_cluster.md`
> (TODO-50, renumbered from TODO-31 for a numbering collision — see
> that file's TODO-50 entry). **This is an open investigation, not a
> confirmed bug.**

## The six findings

All six were checked only against one specific candidate mechanism (the
reused bootstrap worker's stale `cached_design_matrix`,
`bootstrap_worker_stale_design_matrix.md`) and confirmed not to share it.
None has been root-caused on its own terms.

1. **`InferencePropBetaRegr`** — custom uncached `build_design_matrix()`
   (`inference_proportion_beta.R:657-660`), confirmed to never touch the
   broken cache. Real `low_coverage` flag, cause unidentified.
2. **`InferencePropZeroOneInflatedBetaRegr`** — uses
   `build_component_matrix()`, a different two-component builder, not
   `create_design_matrix()` at all. Real flag, cause unidentified, not
   traced further.
3. **`InferenceContinKKOLSOneLik`** and
4. **`InferenceContinKKRobustRegrOneLik`** — build `X_comb` directly from
   `KKstats$X_matched_diffs`/`X_reservoir`, cached via
   `reduce_design_matrix_once(..., cache_key=...)`
   (`inference_continuous_KK_ols_one_lik.R:459-506`,
   `inference_continuous_KK_robust_regr_one_lik.R:104-113`) — that cache
   lives in `private$cached_values[[cache_key]]`, correctly wiped by the
   bootstrap loader and self-validating on `ncol(X)`. Looks correctly
   designed on this specific point; their `low_coverage` flags are real
   and unexplained.
5. **`InferencePropKKGLMM`** and
6. **`InferenceIncidKKCondLogitGLMMIVWC`**/**`InferenceIncidKKCondLogitGLMMOneLik`**
   (grouped — all three inherit `InferenceAbstractKKCondLogitGLMM`) —
   `compute_estimate_with_bootstrap_weights()`
   (`inference_incidence_KK_cond_logit_glmm_abstract.R:80-99`) does call
   `private$create_design_matrix()` (the broken cache), but
   `supports_reusable_bootstrap_worker()` is never overridden in this
   hierarchy, so it inherits the base `FALSE` — every draw gets a fresh
   `duplicate()`d worker, immune to the staleness. Their `low_coverage`
   findings are real and unexplained by that bug.

## Lower-priority, not yet even confirmed as real findings

The 7-class "KKGLMM"/"KKCLMM" cluster (`InferenceContinKKGLMM`,
`InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferenceOrdinalKKCLMM`
+ its 3 link-function subclasses) was also ruled out from the stale-
design-matrix bug (same fresh-`duplicate()`-per-draw immunity as items 5/6
above) — but unlike items 1-6, it's not yet confirmed whether this cluster
actually shows real audit-flagged `low_coverage`/`biased_estimate` findings
at all. Check that first before investing in root-causing it. (Note:
`InferenceCountKKGLMM` specifically is *also* named in
`investigate_count_family_unexplained_miscalibration_cluster.md`/TODO-50 as
part of a separate count-family cluster — if this class does have a real
finding, coordinate with that file rather than duplicating the
investigation.)

## Next steps (none done yet)

- [ ] For each of the 6 confirmed-real-finding classes above, pull the
  exact historical `comprehensive_tests` CSV rows (which method families,
  what magnitude/direction) and look for a shared shape across any subset
  of them, the way TODO-28's cross-class comparison found one shared root
  cause for `InferenceContinOLS`/`InferenceContinLin`/
  `InferenceIncidLogBinomial`/`InferenceSurvivalWeibullRegr`. No shared
  mechanism is assumed here yet — these six were only grouped because they
  were found together, not because they're known to share a cause.
- [ ] Check whether the 7-class KKGLMM/KKCLMM cluster actually has any real
  audit-flagged findings before investigating it further; if none do,
  drop it from this file's scope.
- [ ] Only once a concrete mechanism is confirmed for at least one class
  should this file be split into (or upgraded to) proper `# Fix:` plan
  file(s) with their own fix checklists.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`).
