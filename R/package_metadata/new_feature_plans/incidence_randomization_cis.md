# Incidence Randomization CIs: Per-Estimand-Scale Zhang Exact Intervals

> **Depends on:** none (touches `InferenceRandCI$compute_rand_confidence_interval()`'s
> incidence branch in `inference_all_abstract_rand_ci.R` and the Zhang exact
> machinery in `inference_helpers_zhang.R`); independent of
> `randomization_ci_search_precision.md` (that plan is about the generic
> bisection's Monte Carlo precision -- this one is about a completely
> different dispatch path, Zhang's exact combined test for incidence
> responses, that never reaches the generic bisection at all). Slated for
> **v1.1.0** (user decision, 2026-08-27) -- `release_v1_1_0.md` should pick
> this up as an additional TODO; not yet cross-referenced there as of this
> writing.

## Status

**Randomization CIs are currently hard-disabled for every incidence
response** (`compute_rand_confidence_interval()` throws immediately when
`response_type == "incidence"`, per user decision 2026-08-27) as an
emergency stopgap while this plan's real fix is designed and implemented.
`compute_rand_two_sided_pval()`'s own Zhang dispatch is untouched at the
method level and still works if called directly -- only the CI side was
wrong (see below).

**`InferenceSuite$run_all_inference()` no longer attempts the `rand`
method for incidence responses at all** (`run_all_inference_class_
applicable_methods()`, per user request, 2026-08-27: "i'd rather the rand
CI attempt not show up as a row at all for incidence" -- a row with a real
p-value next to a permanently-`NA` CI and an explanatory message read as
noise rather than a useful result). This is broader than just the CI block:
`"rand"` used to be spared from exclusion specifically because Zhang
covered both its p-value and CI for a Zhang-eligible design; now that its
CI is disabled, `"rand"` is excluded like every other randomization-
dependent sentinel, so no incidence row for it is ever built -- including
its (still-correct) p-value, which no longer surfaces through
`run_all_inference()` for incidence either. Calling
`compute_rand_two_sided_pval()` directly on an incidence-response class
still works exactly as before; only the *suite's* auto-discovery stopped
offering it.

## Symptom (2026-08-27, reported against `inference_suite_results_20260827_115955.html`)

Every "rand" CI row across an entire incidence-response `run_all_inference()`
report -- 22 rows, spanning classes with wildly different estimands
(`mean_difference`: `Avg Δ`, `CMH`, `Extended Robins`, `G Comp Risk Δ`, `KK
G Comp Risk Δ`, `KK Newcombe Risk Δ`, `Miettinen Risk Δ`, `Newcombe Risk Δ`,
`Risk Δ`, `Wald`; `RR`: `G Comp Risk Ratio`, `KK G Comp Risk Ratio`;
`log_risk_ratio`: `KK Modified Poisson`, `Log Binom`, `Modified Poisson`;
`log_odds_ratio_conditional`: `KK Cond Logit GLMM`, `KK Cond Logit`;
`log_odds_ratio_marginal`: `KK GEE`, `Logist Regr`;
`probit_effect_marginal`: `Probit Regr`) -- reported the **identical** CI
bounds, `ci_a = -4.33e-09` (~0), `ci_b = 2.51`, and the **identical**
`pval = 6.96e-05`, regardless of each class's own point estimate (which
ranged from `0.48` to `2.45` across these rows) or scale.

## Root cause

`InferenceRandCI$compute_rand_confidence_interval()`
(`inference_all_abstract_rand_ci.R`) dispatches any incidence-response class
on a Bernoulli/matched design with no custom randomization statistic
(`should_use_zhang_incidence_randomization()`,
`inference_all_abstract_rand.R:542`) to `zhang_ci_exact_combined()`
(`inference_helpers_zhang.R:205`) instead of the generic bisection.

`zhang_ci_exact_combined()` computes **one CI from the raw 2×2
treatment/outcome contingency table**
(`zhang_get_exact_stats()` -- `n11`/`n10`/`n01`/`n00`, plus matched-pair
`d_plus`/`d_minus` when applicable), which depends only on `y`/`w`/matching
structure -- **the same for every class sharing that design and response**.
Both the point-estimate seed (`zhang_incid_treatment_estimate()`) and the
bisection search bounds (`zhang_incid_mle_ci()`) are hard-coded to the
**log-odds-ratio scale**:

```r
zhang_incid_treatment_estimate = function(stats){
    ...
    log((n11 + 0.5) * (n00 + 0.5) / ((n10 + 0.5) * (n01 + 0.5)))
}
```

`compute_rand_confidence_interval()` then returns this log-odds-ratio-scale
CI **verbatim** as the "rand" CI for whichever class called it -- with no
transform back to that class's own `compute_estimate()` scale. For the two
`log_odds_ratio_*`-tagged classes (`KK Cond Logit`/`KK Cond Logit GLMM`,
`Logist Regr`/`KK GEE`) this happens to be *approximately* the right kind of
quantity (though still not necessarily numerically identical to that
specific class's own conditional-vs-marginal odds-ratio estimator). For
every other estimand (`mean_difference`, `RR`, `log_risk_ratio`,
`probit_effect_marginal`) it is a CI in the **wrong units entirely** --
e.g. `G Comp Risk Ratio` (`estimate = 2.45`, Wald CI `[1.61, 3.73]`,
genuinely on a raw-ratio scale with support `(0, ∞)`) reporting a "rand" CI
of `[~0, 2.51]` that is actually a log-odds-ratio interval.

**The shared p-value is a different, likely-correct story.** Zhang's exact
combined test at `delta_0 = 0` (`compute_rand_two_sided_pval()`'s own Zhang
branch, untouched by this plan's stopgap) tests the **sharp null of no
treatment effect whatsoever** -- a hypothesis that is scale-invariant: if
treatment truly has zero effect for every unit, that is simultaneously "no
effect" on the odds-ratio scale, the risk-ratio scale, the mean-difference
scale, and every other monotone reparameterization at once. Sharing one
p-value across estimands under that one specific null is therefore
defensible (this was an explicit, documented 2026-08-23 design decision --
see that dispatch branch's own comment). A **confidence interval**, by
contrast, requires evaluating the test at every candidate non-null `delta`
in the bracket, and "`delta` on the log-odds scale" is not the same
hypothesis as "`delta` on the risk-ratio scale" or "`delta` on the additive
mean-difference scale" for any `delta != null`. That is precisely where the
reuse breaks: the CI-side sharing silently carried over a design decision
that was only ever justified for the point evaluation at the null.

## Why this was never caught

- `should_use_zhang_incidence_randomization()` gates purely on **design**
  eligibility (Bernoulli/matched, no custom statistic) -- it does not check
  whether the *calling class's own estimand* is compatible with what
  `zhang_ci_exact_combined()` actually computes.
- The 2026-08-23 change that added the p-value-side Zhang dispatch
  (closing "a 'rand' CI could come back for a row whose 'rand' p-value
  always came back NA") explicitly reasoned about the p-value's
  scale-invariance at the null, but the CI dispatch predates that change and
  was never revisited against the same question.
- Every class in a report shares the same design/response, so the bug is
  invisible reading any *one* row in isolation -- it only became visible
  once several rows with different estimands and different point estimates
  were compared side by side (the exact circumstance `run_all_inference()`'s
  combined report exists to create).

## Remediation options

1. **Restrict Zhang CI reporting to log-odds-ratio estimands only,
   everything else stays blocked.** Narrower than the current blanket
   stopgap: keep `compute_rand_confidence_interval()`'s Zhang dispatch for
   classes tagged `log_odds_ratio_conditional`/`log_odds_ratio_marginal` in
   `EDI_INFERENCE_ESTIMAND_TAGS` (or, more precisely, for classes whose own
   `compute_estimate()` is verifiably a log-odds-ratio -- the tag is a
   reasonable proxy but not a proof), report `NA` for every other estimand.
   Cheap or free to implement (a registry lookup gate before the existing
   dispatch), but still leaves every non-log-odds incidence class with no
   "rand" CI at all, and doesn't verify the conditional-vs-marginal
   distinction actually matches `zhang_ci_exact_combined()`'s own
   parameterization (KK conditional logit vs. plain marginal logistic
   regression are different odds-ratio *definitions* that happen to share a
   tag prefix).
2. **Real fix: make the Zhang exact bisection estimand-aware.** Generalize
   `zhang_ci_exact_combined()`/`zhang_bisect_ci_boundary()` so the null
   hypothesis tested at each candidate `delta` is expressed on the
   *calling class's own scale*, not hard-coded to log-odds-ratio. Concretely:
   - `zhang_pval_exact_combined(inf_obj, delta_0, ...)` already takes an
     `inf_obj` -- the missing piece is a per-class **link function** from
     "delta on this class's own estimand scale" to "the corresponding shift
     applied inside `zhang_compute_exact_pval_matched_pairs()`/
     `zhang_compute_exact_pval_reservoir()`'s exact combinatorics" (which
     operate on the observed 2×2 counts under a hypothesized *constant
     multiplicative/additive shift* -- exactly which shift model is
     "correct" depends on the estimand: a risk-ratio null shifts the
     event-probability multiplicatively, a risk-difference null shifts it
     additively, a log-odds-ratio null shifts it on the logit scale).
   - This likely means one exact-shift model per estimand family
     (odds-ratio, risk-ratio, risk-difference at minimum -- probit and
     other latent-scale estimands may not have a clean exact-combinatorial
     analogue at all and might need to stay on the "not supported, use a
     different CI method" list permanently), each needing its own
     derivation and its own `zhang_exact_*_pval_cpp()`-style kernel (the
     existing `zhang_exact_binom_pval_cpp()`/`zhang_exact_fisher_pval_cpp()`
     are themselves already odds-ratio/Fisher-specific).
   - `zhang_incid_treatment_estimate()`/`zhang_incid_mle_ci()` (the
     bisection's own seed/search-bound estimate) would also need an
     estimand-specific replacement -- reusing each class's own
     `compute_estimate()`/`compute_asymp_confidence_interval()` as the seed
     (mirroring how the *generic* bisection already seeds itself via
     `get_randomization_ci_seed_candidates()`) is probably more robust than
     re-deriving a new closed-form seed per estimand.
   - Substantially more work than option 1; the right scope for a v1.1.0
     implementation slot, not an emergency fix.
3. **Route non-log-odds incidence classes through the generic bisection
   instead of Zhang.** The generic `InferenceRandCI` bisection (used for
   every non-incidence response) inverts `compute_rand_two_sided_pval()`
   using each class's own `compute_estimate()` re-applied to permuted
   assignments -- genuinely estimand-correct by construction, just not
   currently reachable for incidence
   (`should_use_zhang_incidence_randomization()` intercepts first, and the
   generic path's own incidence guard
   (`!private$should_use_design_randomization_for_incidence()`) currently
   `stop()`s otherwise). If the generic path's permutation machinery
   already handles binary responses correctly for the classes that *do* use
   it via a custom randomization statistic, extending that route to
   ordinary (non-custom-statistic) incidence classes might be simpler than
   option 2's per-estimand exact-combinatorics work, at the cost of losing
   Zhang's *exactness* (falling back to Monte Carlo permutation, inheriting
   `randomization_ci_search_precision.md`'s own open precision questions
   too). Worth scoping alongside option 2 rather than assuming option 2 is
   the only real fix.

**No option has been chosen yet** -- this needs its own Phase-0-style
decision before implementation starts. Option 1 could plausibly ship as a
quick partial restoration (log-odds classes get their CI back) independently
of deciding between 2 and 3 for everything else, if the user wants partial
functionality back sooner than the full fix.

## Implementation TODOs

1. **Decision:** which of options 1/2/3 above (or a combination -- e.g. 1
   now, 2 or 3 as the real fix) to pursue for v1.1.0.
2. Whichever option: add a **regression test that would have caught this
   bug** -- fit >= 2 classes with genuinely different estimand tags to the
   *same* incidence design/response and assert their `rand` CIs are not
   identical (this exact multi-class-same-design comparison is what exposed
   the bug and what no existing single-class test could have caught).
3. If option 2: derive and validate each estimand family's exact shift
   model against a brute-force/simulation check (permute-and-count by hand
   for a small `n`, compare to the closed-form kernel) before trusting the
   C++ implementation -- the existing
   `zhang_exact_binom_pval_cpp`/`zhang_exact_fisher_pval_cpp` presumably
   already went through this for the odds-ratio case; find and reuse that
   validation harness rather than inventing a new one.
4. If option 3: audit whether the generic bisection's permutation machinery
   (`approximate_randomization_distribution_beta_hat_T()` et al.) has ever
   actually been exercised against a binary/incidence response outside the
   custom-statistic path, and what (if anything) currently prevents it --
   the existing `stop()` this plan's stopgap effectively replaced was itself
   guarding *something*; find out what before removing that guard for the
   general case.
5. Once a real fix ships, remove this plan's stopgap `stop()` in
   `compute_rand_confidence_interval()` **and** restore `"rand"` in
   `run_all_inference_class_applicable_methods()`'s incidence branch (both
   stopgaps landed together, 2026-08-27, and should be reverted together --
   the CI block alone would leave the suite still not offering the now-fixed
   p-value+CI row). Re-run the regression test from TODO-2 to confirm it now
   passes for real (not just "no longer identical," but each class's CI
   genuinely on its own scale, sanity-checked against that class's own Wald
   CI for rough plausibility), plus a `run_all_inference()`-level check that
   the `rand` row reappears for incidence with a real (non-`NA`) CI.
6. Cross-reference this plan from `release_v1_1_0.md`/`_master.md` once a
   TODO number is assigned there.

## Testing/verification plan

- The TODO-2 regression test (distinct CIs across estimands on one shared
  incidence design) is the load-bearing test -- it directly encodes "this
  bug cannot silently reappear."
- Whichever remediation option ships, spot-check against the original
  reported scenario's shape: fit the same handful of estimand families
  (mean-difference, risk-ratio, log-risk-ratio, log-odds-ratio,
  probit) to one shared Bernoulli/matched incidence design and confirm each
  class's `rand` CI is in the right ballpark of that class's own Wald CI
  (same order of magnitude, roughly overlapping), not just "not identical
  to the others."
- No change expected outside incidence-response randomization CIs --
  `compute_rand_two_sided_pval()`'s Zhang p-value dispatch, every other
  response type's CI machinery, and every non-`rand` CI method are
  unaffected by both the stopgap and (in scope, though implementation may
  reveal otherwise) the eventual real fix.
