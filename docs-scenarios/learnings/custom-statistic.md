# Learnings: custom-statistic

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- InferenceRandCustom with R fn and C++ source (2/3-arg, lambda helper, Rcpp::cppFunction object); R vs C++ identical.
- Return-value contract: vector (first element kept), NULL/numeric(0)/NA (warning + NA), character/logical/list (silently coerced), error inside the stat (whole p-value errors), warning inside the stat (propagates).
- r: 1..9 (silent NA), 10, 0/negative/non-integer (rejected); NA-draw threshold max(10, r/10); floor 2/B.
- delta, alternative (incl. partial match "g"), na.rm, transform_responses (none/log/logit/bogus), permutations (list(w_mat=)), set_seed, num_cores 1 vs 2.
- CI: alpha values, pval_epsilon, ci_search_control mc_enable/bogus key, conservative bounds, sign/scale invariance.
- Response types incidence/count/proportion/survival with the custom stat; DesignFixedBlocking with unequal strata + ties.
- InferenceCustomRand/Asymp/Boot subclasses via getFromNamespace (extending-edi vignette).

## Not reached
- CI "errors if every delta rejected" path; KK/matched-pair/cluster/rerandomization designs with a trimmed-mean stat.
- type/args_for_type on custom incidence; zero_one_logit_clamp; debug=TRUE output when draws run in parallel.
- Why the lower CI bound was identical at r=1000 and r=2000 (0.6483714): check with other seeds.
- F10 follow-up: does InferenceRandCustom with a C++ stat or with closures over big objects behave the same across cores?

## Workarounds
- C++ helpers: put them as lambdas inside the single function (named helpers and // [[Rcpp::export]] break it).
- permutations must be list(w_mat = n x r 0/1 matrix).
- Custom shells: write the statistic inline in fit(), or set_num_cores(1), else silent NA with 2 cores.
- Never print an inference object (R6 print dumps all privates, very long).

## Confusing docs
- InferenceCustomRand help: transform_responses text says 'the default "log"' while Usage shows "none" (InferenceRandCI help explains "none" resolves to "log" for survival).
- InferenceRand help mentions "Before EDI 1.0.5" behaviour while the installed version is 1.0.4.
- Article says delta/CI are for continuous only; the code refuses some types (incidence, count/prop CI) but not others (survival, count/prop delta).

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

## Covered
- Trimmed-mean difference as R fn and C++ (lambda helper): estimate/p/CI identical, 1 vs 2 cores identical.
- Full enumeration via `permutations = list(w_mat=, enumeration=TRUE/FALSE/absent)`, shuffled columns, missing realized column; coin exact `oneway_test` matches the EDI enumeration to 6 digits.
- Seeded design (`seed=` on the design): realized allocation never among the draws; statistic called exactly 1 + r times.
- CI vs manual grid inversion (4000 own draws): agrees within the grid step; shift equivariance; r threshold 2/(r+1) < alpha at alpha 0.05 (39/40) and 0.01 (199/200).
- max(10, floor(r/10)) boundary at r = 50/200/205/209/210.
- `ci_search_control`: pval_cache_enable, max_expansions (0 rejected), max_radius_*_mult (forces a conservative bound), high_precision_confirm, mc_batch_size/mc_min_draws, seed (strategy strings), fallback ("fallback"/"na"/"error").
- The "every delta rejected" CI error path (sd-ratio statistic); `debug = TRUE` list structure.
- DesignFixedBlocking with unequal strata (needs `equal_block_sizes = FALSE`) and ties; DesignSeqOneByOneKK14 with the trimmed statistic.
- `InferenceCustomBoot` subclass with a trimmed-mean bootstrap CI.

## Not reached
- `permutations$m_mat`; DesignFixedRerandomization/BinaryMatch with the trimmed statistic; interval-censored survival with a custom statistic.
- Whether the per-object p-value cache (F1) is also stale after a design change (e.g. sequential design adding responses between calls).
- Why the conservative-bound message reports a different p at the same delta across identically seeded calls.
- Zhang on a matching design with InferenceRandCustom (F4 used Bernoulli).

## Workarounds
- Build a new InferenceRandCustom object whenever the statistic (or anything it reads) changes; `clear_randomization_cache()` does not reset the cached p-value (F1).
- To force exactly k finite draws, supply `permutations` and make the statistic NA unless w[1] == 1, then swap entries per column.
- In R wrappers that record calls, `force()` the p-value before inspecting the recorded list (lazy evaluation otherwise shows 0 calls).

## Confusing docs
- `?InferenceRandCI` ("keeps only the p-value at delta = 0") vs `?InferenceRandCustom` ("at delta = 0 or at a chosen delta") for count/proportion.
- `?InferenceRand`: `approximate_randomization_distribution_beta_hat_T()` treats "none" as additive for every type, unlike the p-value method; the article implies they share draws.
- `ci_search_control` lists `seed`/`fallback` without values; `high_precision_confirm` is described in prose but missing from the "Supported entries" list.
- DesignFixediBCRD help mentions "Before v1.0.6" behaviour while the installed version is 1.0.5.
