# Summary: custom-statistic run (EDI 1.0.5)

## Goal
The analysis: a two-arm completely randomized trial (`DesignFixediBCRD`, prob_T = 0.4, n = 60, so 24 treated and 36 control) with a heavy-tailed (t3) outcome. The statistic is the difference in 20%-trimmed means, written as an R function and as C++ source. A careful applied statistician would want four things. First, an exact randomization p-value that uses the design's own assignment mechanism. Second, a CI for the additive effect from test inversion. Third, reproducibility under a seed and across core counts. Fourth, an independent check of every number against a hand-rolled permutation computation.

## Done
- R and C++ (lambda helper) statistics give identical estimates, p-values and CIs. Results are the same with 1 and 2 cores, and repeated `set_seed()` calls give identical results.
- The p-value follows the documented Phipson–Smyth rule exactly. Checks:
  - the rule recomputed from `approximate_randomization_distribution_beta_hat_T()` with the same seed;
  - own `permutations = list(w_mat=)` draws at delta in {-1,0,0.5,1,1.5,2,3}, matching a manual impute-then-permute computation;
  - all three `alternative`s.
- Full enumeration (n = 10, choose(10,4) = 210, rounded y with ties):
  - EDI = manual exact p (0.257143), with auto-detection, `enumeration = TRUE` and a shuffled column order;
  - `enumeration = FALSE` gives the "observed counted twice" value;
  - `enumeration = TRUE` without the realized column gives a clear error.
- coin cross-check: the exact `oneway_test` for the mean difference equals EDI's enumeration p (0.180952, 6 digits). coin cannot run a trimmed-mean statistic directly, so the trimmed statistic was checked against base-R enumeration instead.
- CI: checked by manual grid inversion with 4000 own draws, which agrees with EDI to within about 0.02 (grid step 0.02). Also checked:
  - the CI contains the estimate, and the 90% CI is nested in the 95% CI;
  - the strong-effect and null datasets give CIs shifted by exactly 1.5 (shift equivariance);
  - the r threshold 2/(r+1) < alpha: r = 39 gives a conservative boundary CI with a message, r = 40 works; at alpha = 0.01, r = 199 is conservative and r = 200 works.
- Minimum finite draws max(10, floor(r/10)): verified at the boundaries with supplied draws (see F6).
- Return contract:
  - length-0, length-2, NULL, and a length-2 return on draws only all give the documented error;
  - NA/Inf/NaN on the observed data gives a warning and NA;
  - an error inside a draw propagates;
  - non-numeric types are silently coerced (F5).
- Calls: the statistic is called 1 + r times. A seeded design's realized allocation is never replayed among the draws.
- Other designs: `DesignFixedBlocking` with unequal strata (needed `equal_block_sizes = FALSE`, as the error said) and ties, where draws keep per-site counts and the p-value is within MC error of a manual stratified permutation (0.058 vs 0.067, r = 1000 vs 4000). `DesignSeqOneByOneKK14`, where draws keep the pairs, plus a CI.
- Other response types:
  - count: delta accepted, CI refused;
  - proportion: delta accepted, CI refused;
  - incidence: delta and CI refused, Zhang errors (F4);
  - survival: trimmed mean of log times, CI returned.
- `ci_search_control` entries tried (F8 for seed/fallback).
- `debug = TRUE` structure.
- The "every delta rejected" error path, using an sd-ratio statistic.
- `InferenceCustomRand` and `InferenceCustomBoot` subclasses: the bootstrap CI for the trimmed-mean difference works.

## Not done / why
- The DesignFixedOptimal custom_objective convention, which the help references, was not explored.
- Survival interval-censoring with a custom statistic.
- The `m_mat` entry of `permutations`.
- `zero_one_logit_clamp` effects.

All four were left out for lack of time.

## Guesses
- I took the R `mean(trim=)` convention (drop floor(n·trim) from each end) for the C++ version. It matches R to all digits.
- In F1 I assumed per-object caching of the null distribution is the cause. I inferred this from call counting, not from source.
- For F4 I could not tell whether Zhang is meant to be unavailable on `InferenceRandCustom`, or whether the dispatch is broken. Either way the message is false.
- The varying p-values reported in the "conservative bound" messages across identically seeded calls (0.2016, 0.1762, 0.1556 at the same delta) look like sequential-MC early-stopping noise. I did not file it.

## Known findings re-checked
- ds-custom-statistic-44358267779-f1 (closed): fixed. `transform_responses = "log"` at delta = 0.4 equals a manual multiplicative impute-then-permute (0.2177822), not the old incoherent version (0.919).
- ds-custom-statistic-44358267779-f2 (filed): still accepts `"bogus"` (treated as additive, same p as "none"). This is now documented in the help ("The value is not validated").
- ds-custom-statistic-44358267779-f3 (filed): behaves differently. r = 5 or 9 still gives NA, but now with a clear warning ("... at least 10 finite draws are needed. Increase r.").
- ds-custom-statistic-44358267779-f4 (filed): partly changed. The count/proportion CI refusal no longer mentions a bootstrap CI. It still points to the internal "TODO-119 in R/package_metadata/future_release_plans/release_v1_0_5.md", and it now says only "the p-value at delta = 0" remains available (see new F3).
- ds-custom-statistic-44358267779-f5 (closed): survival CI on a log-time statistic is returned. The docs now explain the log-time scale. No regression seen.
- ds-custom-statistic-44358267779-f6 (closed): count/proportion nonzero delta is accepted and now documented as log/logit scale. The doc contradiction is in new F3.
- ds-custom-statistic-44358267779-f8 (filed): still reproduces. A character vector of 2 lines gives "... not a character."
- ds-custom-statistic-44358267779-f10 (filed): still reproduces with 2 cores (an `InferenceCustomRand` subclass whose fit() calls a helper). It now emits a warning instead of a silent NA, but the warning is misleading: "Only 0 of 500 null-distribution draws gave a finite statistic ... try a more stable estimator or more draws". More draws cannot help. With 1 core, or with the code inlined, p = 0.2155689.
- ds-custom-statistic-44358267779-f11 (filed): the `permutations` format is now documented (list with `w_mat`, n x r). Supplied draws worked as documented.
- f7, f9, f12 (dismissed): not re-argued. Article text now matches the 2-arg rejection message and the 2/(B+1) floor.

## Cross-check packages
coin is available (used). statmod (permp) and WRS2 (trimmed-mean tests) are not installed, so there is no package reference for the trimmed-mean statistic itself; base-R enumeration and Monte Carlo were used instead.
