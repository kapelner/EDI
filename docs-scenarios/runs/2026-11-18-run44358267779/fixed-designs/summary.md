# Summary: fixed-designs run (2026-11-18, EDI v1.0.4)

## Goal
A lab has 40 mice with baseline weight (0.1 g resolution) and age (whole weeks, many ties) and wants the best-balanced assignment to two diets. A careful applied statistician would want to:
(a) know how much each fixed design improves balance on the measured covariates,
(b) analyze the outcome in a way that respects the design (randomization inference over the design's own allocation law where one exists; a bootstrap randomization test for the deterministic optimal design),
(c) see whether the CI gets narrower and whether coverage holds, and
(d) be sure the design's documented settings (balance criterion, acceptance rule, number of draws, unequal allocation, seeds) do what they say.

## What was done (analysis.R; output in analysis_output.txt)
- Data: base R, `set.seed(20261118)`: weight ~ N(25, 3) rounded to 0.1, age ~ U{6..12}. Outcome y = 5 + 0.6 weight + 0.8 age + 2·diet + N(0, 2²). The diet effect is 2.
- 12 design configurations: Bernoulli; iBCRD (prob_T 0.5 and 0.4); Rerandomization (obj_val_cutoff + mahal_dist, obj_val_cutoff + abs_sum_diff, prop_acceptable = 0.01, prob_T = 0.4 + cutoff); Greedy (default, and abs_sum_diff with n_iter = 200); BinaryMatch; MatchingGreedyPairSwitching; Optimal (mahal_dist, annealing).
- One trial per design: OLS estimate, asymptotic CI and p-value; randomization CI and p-value (r = 501), or for Optimal (no randomization draw) the bootstrap randomization CI and p-value (B = 199). All CIs contain their estimate, all p-values are in [0, 1], and there are no NAs.
- 150 replicated trials per design: mean Mahalanobis imbalance, mean CI width and coverage for covariate-adjusted OLS (asymptotic), for the unadjusted pooled-variance t-interval (asymptotic), and for the unadjusted estimator's randomization CI (r = 201).

## Results (150 replicates)
| design | mean M(w) | OLS width | unadj. asymp width (cover) | unadj. rand-CI width (cover) | unadj. RMSE |
|---|---|---|---|---|---|
| Bernoulli | 0.224 | 2.65 | 3.72 (0.93) | 3.80 (0.93) | 0.89 |
| iBCRD | 0.214 | 2.61 | 3.66 (0.93) | 3.76 (0.94) | 0.97 |
| Rerand cutoff (mahal) | 0.0010 | 2.54 | 3.69 (0.99) | 2.62 (0.97) | 0.62 |
| Rerand prop_acceptable 0.01 | 0.0023 | 2.54 | 3.69 (0.99) | 2.51 (0.93) | 0.60 |
| Greedy | 0.00059 | 2.53 | 3.69 (0.99) | 2.61 (0.96) | 0.67 |
| PairSwitch | 0.00065 | 2.54 | 3.69 (0.99) | 2.72 (0.95) | 0.60 |
| Optimal (mahal) | 0.00059 | 2.54 | 3.69 (0.99) | n/a (no randomization draw) | 0.63 |

- Balance: the balancing designs cut Mahalanobis imbalance by 100–400×. Greedy, PairSwitch and Optimal reach the same minimum (0.000588). BinaryMatch is in between (0.0165).
- CI width: with covariate-adjusted OLS, all designs give nearly the same width (2.53–2.67). Adjustment already removes most of what balance buys when the outcome is linear in the covariates. Unadjusted, the model-based t-interval ignores the design: it stays ~3.69 wide and overcovers (99%). The design-respecting randomization CI is ~30% narrower (2.5–2.7 vs 3.8) with ~95% coverage.
- Cross-checks: `InferenceContinOLS` matches `lm()` (estimate, CI, p) to all printed digits. `InferenceAllSimpleMeanDiffPooledVar` matches `t.test(var.equal = TRUE)` exactly.
- Documented claims checked and holding: the rerandomization cutoff is honored on the fast path, the pure-R path (prob_T = 0.3) and abs_sum_diff; abs_sum_diff is scale invariant; giving both or neither acceptance rule, or an invalid objective, errors as documented; a tight cutoff errors and reports how many draws were found; seeds give the same draws at 1 and 2 cores (Rerandomization, Greedy); the treated count is round(n·prob_T) on every path; odd n works; invalid n_iter / prob_T are rejected; Optimal falls back to annealing above n = 20 with a message; Optimal refuses randomization tests and its bootstrap randomization CI works; PairSwitch rejects n = 42 (not divisible by 4).

## New findings (findings.md)
F1 silent NA in the PooledVar asymptotic results after a randomization p-value; F2 prop_acceptable rerandomization: observed and reference allocation laws differ, size 7.25% at nominal 5%; F3 the Greedy = GreedyDOptimal claim fails with tied covariates; F4 Optimal abs_sum_diff with auto solver does not finish at n = 40; F5 the optimization diagnostics' objective_value is on an internal scale; F6 the documented default n = NULL fails for every fixed design.

## Could not do / not finished
- DesignFixedBlocking, BlockedCluster, Cluster, Factorial and OptimalBlocks were not analyzed end to end (only n = NULL was checked on Blocking). I ran out of time.
- Optimal with objective "A"/"D" + interest/prior_precision, the "custom" objective (RcppXPtrUtils is installed but compiling takes time), and Gurobi/CPLEX (not installed) were not tested.
- Size check for F2 has only 800 replicates (MCSE 0.77%). The excess (7.25% vs 5%) is about 2.9 MCSE, and the obj_val_cutoff contrast (5.9%) supports it.

## Places I had to guess
- I chose the obj_val_cutoff of 0.0018 as roughly the 1% quantile of M(w) under complete randomization, estimated by my own base R simulation. The docs give no guidance on choosing a cutoff for a given acceptance rate.
- I treated `compute_rand_bootstrap_confidence_interval` as the design-respecting CI for DesignFixedOptimal, because the help says the BRT "IS available". I took its argument name `B` from the method listing / error-free use, not from a help page I read in full.
- For the size simulation in F2 I picked a strongly prognostic null outcome (2·z(weight) + 2·z(age) + N(0, 1)), where the mismatch matters most. With a weakly prognostic outcome the excess would be smaller.
- When I printed a PairSwitching object (by accident, through tryCatch), R6 showed the member list (names and signatures). I did not read method bodies and did not use that list.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area.

## Cross-check packages
lm/t.test (stats) used. No other cross-check needed; nothing missing.
