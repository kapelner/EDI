# Investigation: Randomization p-Values Under `DesignSeqOneByOneKK21stepwise` Are Conservative at the Null (Incidence)

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-53`. Added 2026-09-24
> from the triage of the stale-cache regeneration findings
> (`stale_worker_cache_resampling.md`, TODO-7). **Open investigation, not a
> confirmed bug:** the pattern is reproduced, the mechanism is not known, and
> a conservative randomization test is not a validity failure, only lost power.

## The finding

Under a true null and `DesignSeqOneByOneKK21stepwise` with an incidence
response (n = 148, one covariate, `r = 151`), the randomization p-value is
super-uniform: 60 fresh simulations gave **0 rejections at 0.05, median p
0.71, mean p 0.66** (uniform would give about 0.5 / 0.5 and about 5%
rejections). The existing comprehensive-test rows say the same: 0/80 null
rejections for `InferenceIncidKKGCompRiskDiff` (median p 0.62).

`InferenceAllSimpleAverageDiff`'s randomization p-value on the same data is
identical (median 0.71, mean 0.66), and `InferenceIncidKKGCompRiskDiff`
returns the same p-values, so the cause is shared: the KK21stepwise design
replay (`draw_ws_according_to_design()`), the randomization loop for KK
designs, or the shared estimate/tie handling, not a class-specific fit. For
comparison the same test under `DesignFixedBernoulli` is not conservative
(reject 0.033 with 60 reps).

The power cost is visible: at `beta_T = 0.5` the KK randomization test rejects
0.183 versus 0.317 for the conditional-logit Wald test on the same data.

## First measurement (2026-09-24)

Under the same null, over 80 fresh KK21stepwise designs (n = 148), the
empirical standard deviation of `InferenceAllSimpleAverageDiff`'s estimate was
0.0741 while the mean standard deviation of its randomization distribution
(`r = 151`) was 0.0817, a ratio of **1.10**; the distribution is centred at
-0.0003 (the estimator's own mean is 0.0124, standard error about 0.008). So
the randomization draws are about 10% more variable than the design's true
sampling distribution. That is a modest excess and does not by itself explain
a mean p of 0.66, but it points at TODO-1 (replay fidelity) as the place to
look first, and it says the conservatism is a width problem rather than a
location problem.

## Items

- [ ] **TODO-1: Check the replay is faithful.** Compare the distribution of
  the randomization draws' allocations (match structure, arm balance) against
  fresh runs of the design on the same covariates. A replay that is
  systematically more variable than the real design widens the reference
  distribution and inflates p.
- [ ] **TODO-2: Rule out tie/discreteness effects.** With an incidence
  response the statistic is discrete; check how ties with the observed
  statistic are counted (`>=` versus `>`), and whether the match-structure
  (pairs + reservoir) combination produces a mass at the observed value.
- [ ] **TODO-3: Same check for other KK21stepwise response types**
  (continuous, count) to see whether the conservatism is incidence-specific.
- [ ] **TODO-4: Decide.** If it is a design-replay defect, fix it and
  regenerate; if it is inherent (the test is exact for the sequential design
  and merely discrete), document it and stop chasing the audit flag.
