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
