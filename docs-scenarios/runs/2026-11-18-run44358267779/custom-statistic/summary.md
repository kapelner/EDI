# Summary: custom randomization statistic (20%-trimmed-mean difference), EDI 1.0.4

## Goal
A careful applied statistician wants, for a statistic EDI does not ship (difference in 20% trimmed means): a design-based
randomization test, a test-inversion CI for an additive effect that contains the estimate, results that can be reproduced
with a seed, identical results from the R and C++ versions of the statistic, and agreement with a standard reference
(Yuen's trimmed-mean t interval; a hand-rolled randomization test).

## Done
- `InferenceRandCustom` with an R function and with C++ source (2- and 3-argument signatures; also a compiled
  `Rcpp::cppFunction` object, which the help page does not mention). Estimates, null distributions, p-values (delta 0 and shifted) and CIs
  were identical between the R and C++ versions. C++ CI took 0.22 s vs 0.97 s for R.
- Bernoulli design (n = 50, 22/28 split, t3 errors, effect 1): estimate 1.4948; p = 0.001 (r = 2000); 95% CI [0.648, 2.256].
  Yuen (hand-coded; WRS2 not installed): CI [0.737, 2.253], p = 0.00036. Hand-rolled Bernoulli randomization test with
  20000 draws: p = 0.0005; at delta = 1.8: 0.0073 (EDI 0.008 at r = 1000, 0.0062 at r = 20000). The manual p-value from
  `approximate_randomization_distribution_beta_hat_T()` matched `compute_rand_two_sided_pval()` exactly under the same seed
  (two-sided, greater, less, and nonzero delta).
- Checked these documented promises: the `fn(y, w, dead)` call (y in subject order, `w` numeric 0/1, `dead` an integer vector of 1s); the 2-argument
  function rejected (but with a different message than the article: F9); returning a vector keeps the first element silently
  (as documented); NA/NULL/length-0 on observed data gives a warning and NA; dropped non-finite draws and the
  max(10, floor(r/10)) rule (confirmed at 14/19/95 finite of 200); floor 2/B (help right, article wrong: F12); `na.rm = FALSE`
  ignored as documented, non-flag rejected; `alternative` greater/less/partial match; `alpha` 0.01/0.2/0.5 (CIs nest and contain
  the estimate) and invalid alpha rejected; `pval_epsilon`; `ci_search_control = list(mc_enable = FALSE)`; conservative-bound
  messages for a constant statistic and a variance statistic; sign/scale invariance of the CI (-10*stat gives the same CI);
  reproducibility (same p across fresh objects, num_cores 1 vs 2, `set.seed` alone); draws respect blocks in
  `DesignFixedBlocking` with unequal site sizes (10/17/23) and ties; null and strong effects.
- Other response types: incidence (p only; delta and CI refused), count/proportion (p; CI refused, delta accepted: F4, F6),
  survival (p, delta and CI all accepted: F5).
- Extension shells from the extending-edi vignette: `InferenceCustomRand`, `InferenceCustomAsymp` (Wald CI/p with Yuen SE
  matched Yuen exactly: CI [-0.36097, 1.294451], p 0.257545), `InferenceCustomBoot`. The vignette example itself works, but
  a `fit()` that calls a global helper gives silent NA with 2 cores (F10).

## Not done / could not do
- `WRS2` (yuen) is not installed; Yuen's test was hand-coded. `coin` has no trimmed-mean statistic, so it was not used.
- Did not reach a case where "the test rejects every delta tried" so the CI errors (as the help says it should).
- Did not test KK / matched-pair / cluster designs with the custom statistic beyond what the article already shows.
- Did not look for the cause of F10 (needs source); the workaround is documented in the finding.

## Guesses
- `permutations` format: guessed `list(w_mat = <n x r matrix>)` (F11).
- `transform_responses` values: guessed "log"/"logit" (F1, F2).
- Treated the "hypothesis scale" in the task as `transform_responses`; `compute_rand_confidence_interval()` has no such argument.
- Noticed but did not log as a finding: the lower CI bound was 0.6483714 at both r = 1000 and r = 2000 while the upper bound moved
  (2.3045 -> 2.2557). This may be by design (cached search); it needs more runs before it can be called a finding.
- Out of area, not logged: `DesignFixedBlocking$new(n = NULL)` (default in Usage) errors "you must specify n upon initialization".
- Printing an `InferenceRandCustom` object (R6 default print) shows all private fields and methods. I did not use any of them.
- Several messages and help pages point at internal repo paths (`R/package_metadata/...`, `private$...`,
  `rand_ci_conservative_count++`). Only the false part of one such message is logged (F4).

## Known findings re-checked
None (first run for this area; known_findings.md was empty).
