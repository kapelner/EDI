# Cox Risk-Set Cache: Guard Keys Only on `w` While the Cache Embeds `y`/`dead` (Staleness Fix)

> **Release:** v1.0.5 (`../future_release_plans/release_v1_0_5.md → TODO-30`,
> slotted 2026-09-24, user decision) — a *correctness* fix. Found 2026-08-30 during the
> research-plan verification audit
> (`../new_research_ideas/paper/fast_randomization_inference/fast_randomization_inference.md`, work item
> V2). Reused workers in the current checkout can realize the stale hit;
> the tagged v1.0.0 source has the same `w`-only Cox guards, but no tagged
> binary was independently exercised in this audit.
>
> **Ownership:** the `cox_*` private caches of `InferenceCoxPH`
> (`inference_survival_coxph.R:427-428, 516-531`) and the `strat_cox_*`
> caches of `InferenceStratifiedCoxPH`
> (`inference_survival_strat_cox.R:285-294, 571+`). The C++ builders
> (`build_cox_data_cache_cpp`, `build_stratified_cox_data_cache_cpp`) are
> correct and untouched — the documented contract at
> `helper_glm_fit.R:2274` already says the R-side cache owners are
> responsible for invalidation; this plan makes them honor it.

Date: 2026-08-30

## The finding

`InferenceCoxPH$generate_mod()` rebuilds its prebuilt risk-set cache only
when the caches are `NULL` or `w` changed:

```r
# inference_survival_coxph.R:516
if (is.null(private$cox_X_fit_cache) || is.null(private$cox_data_cache) ||
    !identical(private$w, private$cox_w_cache)) {
    ...
    private$cox_data_cache = build_cox_data_cache_cpp(private$cox_X_fit_cache, private$y, private$dead)
    private$cox_w_cache = private$w
}
```

But the cache built at `:529` embeds `private$y` and `private$dead` (and,
via `cox_X_fit_cache` at `:517-528`, the covariate matrix `get_X()`), none
of which appear in the guard. `InferenceStratifiedCoxPH` has the same shape
at `inference_survival_strat_cox.R:571` (`!identical(private$w,
private$strat_cox_w_cache)`), with the additional twist that it *stores*
`strat_cox_y_cache`/`strat_cox_dead_cache` — but only as informative-row
subsets fed to the fitter, never as guard keys.

And no external invalidation covers the gap: neither the randomization
worker loader (`inference_all_abstract_rand.R:1139-1158` — resets
`cached_design_matrix`, `cached_reduced_X`, etc.; a repo grep finds **no
mention of any `cox` field** in that file) nor the bootstrap worker loader
(`inference_all_abstract_non_param_boot.R:1216-1302`, same grep result) nor
`reset_matching_caches` touches `cox_data_cache`/`strat_cox_data_cache`.

So the invariant "a cache hit implies the cached quantity equals what a
rebuild would produce" fails exactly when **`y` (or `dead`, or `X` rows)
changes while `w` does not**.

## Why it has not blown up yet

Within a single dataset at a single null value, equal `w` implies equal
`y_sim` (the null-shift is a deterministic function of `y`, δ, and `w`), so
every cache hit is *correct*. The incorrect hits require `y` to move at
fixed `w`, which only happens across a boundary the guard cannot see:

1. **Parametric / LR bootstrap replicates.** The
   reusable-worker path (`inference_all_abstract_param_boot.R:582-695`,
   `create_param_bootstrap_worker_state` → `compute_param_bootstrap_worker_lrt`)
   resimulates `y` per replicate **at fixed `w`**. If the worker's per-
   replicate load writes `y` without nulling `cox_data_cache` (nothing
   does — see above), every replicate after the first fits against the
   first replicate's risk sets. This path is live in the current checkout;
   the v1.0.0 Cox classes did not yet compose the parametric-bootstrap
   component.
2. **Randomization inference across δ in a reused worker.** Plain Cox wires
   the generic rand contract (`inference_survival_coxph.R:283`) and the
   permutation matrix is memoized on the design and shared across δ
   (`inference_all_abstract_rand.R:922-947`), so the *same* `w_b` vector
   recurs at different δ with different `y_sim`. The usual fast C++ kernel
   (`compute_fast_rand_bootstrap_distr`, `:728`) bypasses `generate_mod`
   entirely. A nonzero delta with the additive transform selects the slow
   fallback, which re-dispatches through `generate_mod` on the reused worker.
3. **Nonparametric bootstrap `w`-value collision.** A resample's `w` is a
   different vector that can *coincide in value* with the cached one
   (binary entries, small `n`, matched-pair designs with small `2^#pairs`
   assignment spaces) while its resampled `y`/`dead`/`X` rows differ.
   Rare, unbounded-in-B, and silent.
4. **Direct API mutation.** Any path that writes `private$y` or
   `private$dead` on a live object at fixed `w` (response updates,
   censoring edits) serves stale risk sets on the next fit.

## The fix

Key the guard on **everything the cache embeds**, in both classes:

```r
if (is.null(private$cox_X_fit_cache) || is.null(private$cox_data_cache) ||
    !identical(private$w, private$cox_w_cache) ||
    !identical(private$y, private$cox_y_cache) ||
    !identical(private$dead, private$cox_dead_cache) ||
    !identical(private$get_X(), private$cox_X_cov_cache)) {
```

storing `cox_y_cache`/`cox_dead_cache`/`cox_X_cov_cache` alongside
`cox_w_cache` at build time. `identical()` short-circuits on
pointer-equality for the unchanged-object common case, so the hot path
(repeated fits at truly fixed data — the case the cache exists for, per
`helper_glm_fit.R:2109-2177`) pays a few pointer compares; the changed
case pays one O(n) memcmp before an O(n log n) rebuild it needed anyway.

Deliberately **not** the alternative fix: adding `cox_data_cache` to the
worker loaders' reset blacklists. That repairs scenarios 1-2 but not 3-4,
spreads the invariant across three files, and inverts the package's own
caching discipline — a cache should be keyed by what it embeds
(self-validating), not kept alive by every mutation site remembering to
kill it. The `get_X()` comparison covers the stratified class's
strata-derived state too, since strata columns come from `X`.

For the stratified class, guard on the *full* inputs (`w`, `y`, `dead`,
`X`), not the informative-row subsets it already stores — the subset
indices themselves depend on `y`/`dead` through `get_informative_rows`.

## Items

- [x] **TODO-1: Exposure audit.** Verdicts from current source and the
  local `v1.0.0` tag:
  (a) Both current Cox classes take the reusable LR bootstrap path; a
  public `compute_lik_ratio_bootstrap_two_sided_pval()` test compares its
  replicate LR values with fresh-worker fits. The `v1.0.0` Cox classes
  did **not** compose `ParametricLikelihoodBootstrap`, so this particular
  exposure was absent then.
  (b) Plain Cox reaches the slow randomization worker path for nonzero
  `delta` with the additive transform. A public distribution call at two
  deltas inside one worker-reuse session agrees with a fresh object at the
  second delta. The tag contains the same cross-delta worker reuse logic.
  (c) Reordering subjects within each treatment arm produces different
  `y`/`X` with an exactly identical `w` vector. The nonparametric bootstrap
  loader reuses the worker; a regression checks both Cox classes against a
  fresh worker after this collision. The tag has the same loader and guards.
  (d) Direct `y`, `dead`, `X`, and strata-only changes at fixed `w` rebuild
  both classes' risk-set caches and match fresh fits. The tagged source
  retains the old `w`-only guards. Tagged binaries were not run, so no
  released wrong numerical result is claimed; this is a silent-correctness
  risk rather than a measured released effect.
- [x] **TODO-2: Guard fix in both classes** as specified above
  (`inference_survival_coxph.R:516`, `inference_survival_strat_cox.R:571`),
  new cache fields declared next to the existing ones
  (`inference_survival_coxph.R:427-428`,
  `inference_survival_strat_cox.R:285-294`).
- [x] **TODO-3: Same-pattern sweep.** The `cox_*` and `strat_cox_*`
  risk-set caches embed `w`, `y`, `dead`, and `X`; both now use the full key.
  Four other `w`-guarded caches embed only a model matrix, not responses:
  `logit_X_full_cache`, `logbin_X_full_cache`, `poisson_X_full_cache`, and
  `negbin_X_full_cache`. All four reproduced a stale hit when `X` changed
  at fixed `w`, with no worker-loader invalidation; each now keys on its
  covariate input as well. `SimulationFramework`'s `design_w_cache` is a
  precomputed assignment cache by design name, not a fitted-data cache.
- [x] **TODO-4: Tests.** (a) Direct regression: fit, overwrite `private$y`
  at fixed `w`, fit again; assert equality with a fresh object's fit (fails
  before the fix if the mutation path is reachable, passes after). Same for
  `dead` and for a permuted-rows `X` at colliding `w`. Both classes.
  (b) Public LR bootstrap and slow randomization tests, plus a deterministic
  worker-loader resample collision. (c) A mocked builder spy asserts exactly
  one cache build across two identical-input fits for each Cox class. The
  four matrix caches have a changed-`X` regression; logit's changed-`X`
  estimate also matches a fresh fit. Focused tests pass with
  `pkgload::load_all(compile = FALSE)`; no package rebuild was run.
- [x] **TODO-5: Contract doc touch-up.** `helper_glm_fit.R:2274` and
  `:2109-2177` describe the R-side owners' invalidation responsibility;
  add one sentence naming the complete key set (`w`, `y`, `dead`, `X`) so
  the next cache of this shape copies the right pattern.

## Explicitly out of scope

- Making the XPtr caches serializable or reusable across sessions (the
  documented non-goal at `helper_glm_fit.R:2156` stands).
- Randomization-CI support for stratified Cox (blocked on the scale
  mismatch, `inference_survival_strat_cox.R:280`).
- The analogous *performance* question of sharing risk-set caches across
  permutations by keying on `(w, y_sim)` pairs — that is the research
  paper's territory, not this fix.
