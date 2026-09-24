# Fix: Stereotype-Logit Likelihood Is Multimodal — `compute_estimate()` Can Return a Non-Global Optimum

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-8` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-30`, bug-fix/feature split).

Found 2026-09-21, following up on the `comprehensive_tests` results-CSV audit
(`audit_comprehensive_results.R`) finding that fixed
`InferenceOrdinalStereotypeLogitRegr`'s delta-constrained null refit
(`get_likelihood_test_spec()` / `simulate_under_lik_null()` in
`inference_ordinal_stereotype_logit.R`), landed 2026-09-21
(`inference_ordinal_stereotype_logit.R`, regression test in
`test-stereotype-logit-null-refit-pd-gate.R`). That fix closed the
zero-width-CI bug (the refit stalling far from the true constrained optimum,
inflating the LR statistic at the point estimate to below `alpha`, collapsing
`compute_lik_ratio_bootstrap_confidence_interval()` to `c(est, est)`). See
memory `project_stereotype_multimodal_likelihood_20260921`.

## The residual problem

Post-fix measurement (400 simulated null datasets, one continuous covariate,
`w` balanced 0/1) still shows anti-conservative behavior at small `n`:

| n | Fits | Type-I (`compute_lik_ratio_two_sided_pval`) | CI coverage | Zero-width CIs | Fits where the null refit didn't reach the full-fit likelihood |
|---|---|---|---|---|---|
| 100 | 386 | 6.5% | 0.933 | 0 | 0 |
| 50 (3 response categories) | 169 | 13% | 0.923 | 0 | 5 (3%) |

The 5 residual cases at `n = 50` are not a refit-stalling problem (the
2026-09-21 multi-start fix already tried the refit from many starts and
confirmed the reported gap is real, not a local-search failure of the
*refit*). The problem is upstream, in `compute_estimate()` itself: the
stereotype likelihood is multimodal, and the **unconstrained** fit that
`compute_estimate()` reports can land at a local, non-global optimum.

Example (`r = 183`, `n = 50`, seed `1183`): `compute_estimate()` reports
`beta_T = 0.057` with `neg_loglik = 42.22`. A jittered restart from that same
fit reaches `neg_loglik = 40.05` at `beta_T = 1.248` — a strictly better
(lower) likelihood at a very different treatment effect. Because
`get_likelihood_test_spec()`'s `full_fit` stores whatever `generate_mod()`
returned as the point estimate, the LR statistic at `delta = beta_T_hat` is
computed against the *worse* optimum's likelihood, comes out positive (not
~0 as it should at the MLE), and pushes `compute_lik_ratio_two_sided_pval()`
below `alpha` more often than the nominal rate — this is the residual 13%
Type-I at `n = 50`.

This also means: **the point estimate itself can be wrong** (not just the
test/CI built on top of it) — `compute_estimate()`'s contract is "the MLE",
and in ~3% of small-`n` fits observed here it silently isn't.

## Root cause

`generate_mod()` (`inference_ordinal_stereotype_logit.R`) calls
`fast_stereotype_logit_cpp()` / `fast_stereotype_logit_with_var_cpp()` with a
**single** warm start (the class's own warm-start cache, or a cold start with
no prior fit). Newton/L-BFGS-type optimizers on this likelihood converge to
whichever local optimum is nearest the start; nothing in the current fit path
compares candidate optima or restarts from a spread of starting points. The
model's non-regularity near `beta_T = 0` (documented in
`stereotype_fit_is_usable()`'s comments — the category-score/loading
parameters `phi_k` are not identified there) is exactly the region small-`n`
null-adjacent data lands in, which is presumably why multimodality shows up
disproportionately at small `n` / few categories rather than uniformly.

## Proposed fix

Multi-start `compute_estimate()`'s own fit (`generate_mod()`), not just the
constrained null refit (already multi-started as of 2026-09-21). Candidate
starts, in the same spirit as `../new_feature_plans/cold_starts.md` / `../new_feature_plans/multistart_nonconcave_likelihoods.md`
(the package's existing smart-cold-start and multistart infrastructure for
nonconcave kernels — reuse rather than reinvent):

1. The existing smart cold start / warm-start cache (current behavior,
   kept as the primary/cheapest candidate).
2. A small number of deterministic perturbations of the smart start (e.g.
   jittered `gamma`/loading coordinates, since those are the non-identified
   directions near `beta_T = 0`).
3. A reproducible random layer (seeded off the fit's own data, not global
   RNG state) for a few additional starts, matching
   `../new_feature_plans/multistart_nonconcave_likelihoods.md`'s pattern if that plan has already
   established one by the time this is implemented.

Keep whichever converged fit has the lowest `neg_loglik`. Cache its
`fisher_information`/`params` as the warm start exactly as today.

## Why this needs review before shipping (not done inline with the CI fix)

- **Changes reported estimates**, not just p-values/CIs, in ~3% of small-`n`
  fits observed so far (true rate over the full comprehensive-test grid
  unmeasured). This is a behavior change to `compute_estimate()`'s output,
  unlike the 2026-09-21 fix, which only touched an internal refit that never
  fed a public return value directly.
- **Migration/reference-parity risk**: `test-ordinal-kk-clmm-migration-golden`
  and similar golden-value tests, plus `test-reference-parity.R`
  (`R/EDI/tests/testthat/`, part of the structural pre-push gates — see
  memory `project_prepush_structural_and_results_gates_20260919`), may pin
  exact `InferenceOrdinalStereotypeLogitRegr` estimates that would move.
  Every such golden needs to be re-derived (not just re-recorded) with a
  documented justification (the new estimate is provably the better
  optimum), same standard as any other estimate-changing fix in this
  package.
- **Cost**: multi-start multiplies the per-fit cost of a class already
  tiered `"heavy"` (`get_complexity_tier()`); needs a benchmark before/after
  (same table format as `../new_feature_plans/cold_starts.md`) to size the impact on
  `comprehensive_tests.R`'s stereotype-logit runtime, which is already
  flagged as slow (`comprehensive_tests.R`'s per-class timing notes near the
  `InferenceOrdinalStereotypeLogitRegr||~.` jackknife-exclude entry).
- **Scope check**: confirm no other stereotype-logit entry point
  (`compute_estimate_with_bootstrap_weights()`'s weighted surrogate,
  `compute_treatment_estimate_during_randomization_inference()`) shares the
  same single-start fit path and needs the identical treatment, or
  deliberately differs and that's documented.

## TODOs

- [ ] TODO-1: Confirm scope — grep every call site in
  `inference_ordinal_stereotype_logit.R` that invokes
  `fast_stereotype_logit_cpp()` / `fast_stereotype_logit_with_var_cpp()` with
  a single start (`generate_mod()`,
  `compute_treatment_estimate_during_randomization_inference()`,
  `compute_estimate_with_bootstrap_weights()`'s surrogate) and decide, per
  call site, whether multi-start applies (the randomization-inference and
  bootstrap-weights paths run many times per replicate — a naive multi-start
  there may be too slow; may need a cheaper heuristic, e.g. only multi-start
  when the single-start fit's `beta_T` is near 0).
- [ ] TODO-2: Design the multi-start candidate set for `generate_mod()`
  (deterministic perturbations + seeded random layer, per "Proposed fix"
  above); align with `../new_feature_plans/multistart_nonconcave_likelihoods.md`'s scheme if it
  exists by implementation time, otherwise write this class's own and note
  the divergence there for future reconciliation.
- [ ] TODO-3: Implement, keeping the lowest-`neg_loglik` converged fit;
  preserve existing warm-start caching semantics.
- [ ] TODO-4: Re-run the 400-null-dataset measurement (both `n=100` and
  `n=50, K=3` configurations from this plan's table) post-fix; confirm the
  `n=50` non-global-optimum count drops to ~0 and Type-I/coverage improve
  accordingly. Extend to a few more `(n, K)` combinations to characterize
  where multimodality bites hardest.
- [ ] TODO-5: Audit and, where estimates move, re-derive (not just
  re-record) every golden/reference value touching
  `InferenceOrdinalStereotypeLogitRegr` in
  `test-ordinal-kk-clmm-migration-golden` (if applicable — confirm this is
  the CLMM class, not stereotype, before assuming it's in scope),
  `test-reference-parity.R`, `test-simple-estimator-migration-baseline`, and
  any `testthat_bulk/` stereotype-logit reference tests; document each
  change with the before/after `neg_loglik` showing the new value is the
  genuine improvement.
- [ ] TODO-6: Benchmark per-fit cost before/after (table format per
  `../new_feature_plans/cold_starts.md`); if the slowdown is material, gate multi-start behind a
  cheap pre-check (e.g. only trigger extra starts when `|beta_T_hat|` is
  small, since that's the observed non-identified/multimodal region) rather
  than always running the full candidate set.
- [ ] TODO-7: Update `inference_ordinal_stereotype_logit.R`'s class-level
  roxygen (rewritten 2026-09-21 with the post-refit-fix Type-I/coverage
  numbers) with the post-multi-start numbers from TODO-4, and regenerate
  `man/InferenceOrdinalStereotypeLogitRegr.Rd`
  (`fix_documentation.md`'s batch process — do not roxygenize ad hoc mid
  other work, see memory `feedback_no_interim_roxygenize`).
- [ ] TODO-8: Regenerate the `comprehensive_tests` CSV rows for this class
  (all `function_run`s, not just the lik-ratio-bootstrap slice already
  regenerated 2026-09-21) once the fix lands and is installed, then re-run
  `audit_comprehensive_results.R --write-baseline` to drop any
  now-stale `InferenceOrdinalStereotypeLogitRegr` baseline entries.
- [ ] TODO-9 (added 2026-09-24, found via a dedicated cross-class
  investigation fork re-auditing the ordinal cluster — **flag
  prominently, low-medium confidence, thin sample**): possible **post-fix
  coverage regression** from the already-shipped 2026-09-21 multi-start
  fix this file describes. Coverage on several families dropped after
  the fix: `wald`/`asymp` 0.973→0.762, `score` 0.955→0.762, `gradient`
  0.922→0.667, `lik_ratio` 0.686→0.524 (already bad pre-fix, worse
  after). Confirmed NOT explained by stale audit data (the comparison is
  against post-fix rows specifically). Post-fix sample is thin (n=21 per
  the fork's count) — needs a larger post-fix regeneration run before
  concluding this is real rather than sampling noise. If confirmed real,
  this would mean the multi-start fix (keeping the lowest-`neg_loglik`
  converged fit, per TODO-3) changed which local optimum gets selected in
  a way that's *worse* for CI coverage on the affected families, even
  while presumably improving point-estimate bias/Type-I error (the
  original target of the fix) — plausible if the SE/CI machinery for
  these families implicitly assumed the old (buggy) single-start fit's
  behavior somewhere downstream. Not investigated further; needs its own
  look once TODO-4's larger post-fix measurement run exists.

## Standing constraints

Same as `release_v1_1_0.md`'s standing constraints: additive by default
except where this plan explicitly documents an estimate-changing default
(TODO-3's fit change is exactly such a documented default change, same
category as `release_v1_1_0.md`'s TODO-11 class-deletion exception). No
`R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn (see
top-level `CLAUDE.md`); verify any C++-adjacent change (none expected here —
this is R-layer multi-start orchestration around existing kernels, not a new
kernel) via targeted compile only, never a full build.
