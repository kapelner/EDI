# Custom-Statistic Randomization CI Is Searched on the Statistic's Scale

> **Depends on:** none. Release: v1.0.5 (`../future_release_plans/release_v1_0_5.md →
> TODO-100`), user decision 2026-10-21. Found while writing the Technion
> seminar slide on `InferenceRandCustom`.

Date: 2026-10-21

## Problem

`InferenceRandCustom$compute_rand_confidence_interval()` returns a wrong,
finite interval whenever the user's statistic is not on the scale of the
additive treatment effect δ. A Welch two-sample t statistic is the simplest
example.

The randomization p-value itself is correct. Under H0: δ, the response is
shifted on the y scale (`y - δ w`) and the statistic is recomputed, so
`compute_rand_two_sided_pval(delta)` works for any statistic. The CI search
breaks because it centers its search on `compute_estimate()`, the observed
value of the statistic (`R/EDI/R/inference_all_abstract_rand_ci.R`, ~L547–580):
`est` is the statistic, `default_seed_ci = est ± 2 se_guess`, and the bracket
starts at `[est - min_radius, est + min_radius]`. `InferenceRandCustom` has no
Wald or asymptotic CI, so `se_guess` falls back to `sd(y) / sqrt(n)`. For a
t statistic, `est` is in t units, not y units, so the search runs in the
wrong place.

Reproduction (current source via `pkgload::load_all(compile = FALSE)`; also
installed EDI 1.0.3): `DesignFixedRerandomization`, continuous, n = 60,
`y = x1 + 0.5 w + N(0, 1)`, seed 1. The observed mean difference is 0.452 and
t = 1.505.

| δ | p (t statistic) | p (mean difference) |
|---|---|---|
| 0 | 0.144 | 0.144 |
| 0.40 | 0.858 | 0.858 |
| 0.80 | 0.196 | 0.196 |
| 1.35 | 0.004 | 0.004 |
| 1.50 | 0.004 | 0.004 |
| 1.81 | 0.004 | 0.004 |

The CIs:

- Mean difference: (-0.240, 1.087), which is correct.
- t statistic: **(1.353, 1.808)**. Every δ in it has p = 0.004 < α, and it
  excludes δ = 0, where p = 0.144.

The p-value curves are identical, which is expected: under a
shift null, t and the mean difference give the same randomization test here.
So the correct t-statistic CI is about (-0.24, 1.09).

There is a second defect: the search does not check that its starting point
is accepted. The bisection log shows `pval_span=0` at both ends, so the search
"converges" on a band in which every p-value is below α. It then returns that
band as a CI. A valid inversion CI must contain at least one δ with p ≥ α.

The roxygen does not say that the statistic must be on the δ scale for the
CI.

## Fix (v1.0.5)

- [ ] TODO-1: For `InferenceRandCustom` (and any class whose `compute_estimate()`
  is not on the δ scale), seed the CI search from an estimate on the δ scale.
  The simplest correct seed is the observed difference in means (for
  continuous y), with `se_guess` from its Welch SE. Alternatively, find a
  point with p ≥ α first, e.g. the δ that maximizes p on a coarse grid
  around the mean difference.
- [ ] TODO-2: In the shared CI search, check that the seed point is accepted
  (p ≥ α). If no accepted δ is found within the search radius, error clearly
  instead of returning a band of rejected values. This protects every class,
  not just the custom one.
- [ ] TODO-3: Regression test with the fixture above: the t-statistic CI must
  contain δ = 0 (p = 0.144) and match the mean-difference CI within MC
  tolerance. Also test a statistic with a different scale and sign, e.g.
  `-10 * (mean difference)`, so the test does not rely on t being close to
  the effect.
- [ ] TODO-4: Document in `InferenceRandCustom`'s roxygen that the CI inverts
  the test over an additive shift δ of y, so it is a CI for the additive
  effect, whatever the statistic's own units.

## Not in scope

- Non-additive nulls (e.g. multiplicative shifts) for custom statistics.
- `custom_randomization_statistic_cpp`: it goes through the same CI search, so
  TODO-1/2 cover it. Include it in TODO-3's test.
