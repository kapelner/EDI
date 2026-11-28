# Summary: fixed-designs, 2026-11-28

## Goal
A lab has 40 mice with weight (g, 0.1 g resolution) and age (whole weeks, 6–12) measured at baseline, and wants the best-balanced assignment to two diets. A careful applied statistician would want four things:
- balance on both covariates, measured independently of the package (my own Mahalanobis M(w) and standardized mean differences);
- a design-respecting analysis: randomization CI/p for designs with a randomization law, and the bootstrap-randomization CI for the deterministic optimal design;
- an honest comparison of CI width, unadjusted and covariate-adjusted;
- cross-checks against `lm` and `t.test`.

Data: base R, `set.seed(20261128)`. Outcome y = 2 + 0.6·weight + 0.4·age + N(0,1) + 1.5·diet. Outcomes were generated before any design was built (learnings.md workaround).

## Finished (analysis.R → results.csv)
I compared 15 design configurations. "Unadjusted rand CI width" is for the mean difference; "rand SD" is the SD of that estimator over 300 design redraws under the sharp null:

| Design | Realized M | Unadjusted rand CI width | Rand SD | OLS rand CI width |
|---|---|---|---|---|
| Complete randomization (iBCRD) | 0.032 | 3.37 | 0.78 | 1.37 |
| Bernoulli (n_T = 21) | 0.24 | 3.39 | 0.77 | 1.30 |
| Blocking, 2 weight bins (19/21) | 0.14 | 2.78 | 0.64 | 1.33 |
| Blocking, user `m` = 10 weight quartets | 0.15 | 1.64 | 0.38 | 1.09 |
| Rerandomization, `obj_val_cutoff` at 5% (qchisq rule) | 0.0097 | 1.43 | 0.35 | 1.32 |
| Rerandomization, `prop_acceptable = 0.01` | 0.0016 | 1.45 | 0.32 | 1.33 |
| Rerandomization, abs_sum_diff, `prop_acceptable = 0.05` | 0.0020 | 1.63 | 0.40 | 1.39 |
| Greedy, Mahalanobis | 0.00064 | 1.26 | 0.29 | 1.26 |
| Greedy, abs_sum_diff with `n_iter = 200` | 0.00067 | 1.26 | 0.32 | 1.24 |
| GreedyDOptimal, A-optimal with `interest = "all"` | 0.042 | 1.29 | 0.31 | 1.29 |
| BinaryMatch | 0.0077 | 1.33 | 0.32 | 1.13 |
| Pair switching | 0.00064 | 1.23 | 0.29 | 1.28 |
| Optimal, mahal_dist (bootstrap-randomization CI, B = 101) | 0.00064 | 1.41 | — | 1.52 |
| Rerandomization, `prob_T = 0.4` | 0.0045 | 1.54 | 0.34 | 1.47 |
| Greedy, `prob_T = 0.4` | 0.00011 | 1.48 | 0.32 | 1.47 |

Conclusions:
- Balance-seeking designs cut the unadjusted randomization-CI width by more than half compared with complete randomization.
- After OLS adjustment for weight and age, every design gives about 1.3. Balance mainly buys robustness when the analysis is unadjusted.
- The naive t-interval (≈3.2) ignores the design and is far too conservative for the restricted designs.
- The M ≈ 0.00064 reached by greedy, pair-switching and optimal is the floor for these data: whole-week ages with an odd total cannot be split evenly.
- Every CI contains its estimate. All p-values are in [0, 1]; with the strong effect, the randomization p-values sit at their floor of 2/502.
- EDI's OLS matches `lm` (estimate and CI width to about 1e-13), and PooledVar matches `t.test` (CI to about 1e-15, p-value exactly).

Other checks:
- The documented `obj_val_cutoff` formula gives 5.4% empirical acceptance at a 5% target, and every redraw satisfies M ≤ a.
- Optimal: n = 16 exact MILP/Dinkelbach agree with annealing; `interest` given as a formula or names, `prior_precision` as a scalar or matrix, `standardize_covariates = FALSE`, `mirror_coin = FALSE`, `solver_args` tuning, and all validation errors behave as documented.
- Missing covariates (impute, drop_column or error, with and without the missingness indicator) work for Rerandomization, Greedy, Optimal and BinaryMatch.
- `design_formula` with `I(weight^2)` changes the balance criterion as expected.
- `w_precomputed` validation works.
- A null-effect analysis with `prob_T = 0.4` works.

## New findings (findings.md)
- F1: `exact_num_blocks = TRUE` error reports a false block count, and the option changes the blocking it builds.
- F2: an integer column that is categorical on its own is quantile-binned when combined with another stratum under `B_target`.
- F3: the default `DesignFixedBlocking` fails on ordinary data, and the error says `B_target = NA`.
- F4: iBCRD with the default `n = NULL` cannot bootstrap ("Block identifiers are undefined").
- F5: PairSwitching has no `n = NULL` default.
- F6: the optimal-design randomization error omits the bootstrap-randomization test.

## Could not do / skipped
- I did not test the custom C++ objective (needs compilation time), `roi_solver` gurobi/cplex (not installed), BlockedCluster, Cluster, Factorial or OptimalBlocks.
- No coverage simulations: the previous run did these, and my time went to the changed help pages.
- I did not use `coin` or `sandwich`; `lm` and `t.test` were enough for the models I fit.

## Guesses and decisions
- Rerandomization cutoff: I used the help page's qchisq rule with k = 2.
- Blocking with 2 weight bins: my data has ties at the median (19/21), so following the error message I set `equal_block_sizes = FALSE`. I also built quartet blocks via `m`.
- For the optimal design I used B = 101 bootstrap-randomization replays to save time; it is not compared with randomization CIs on equal footing.
- PairSwitching: I passed `n = 40` (F5).
- iBCRD in analysis.R used `n = NULL`; randomization inference works there. The bootstrap failure (F4) was found separately.

## Known findings re-checked
- `ds-fixed-designs-44358267779-f1` (closed): fixed. After `compute_rand_two_sided_pval()`, PooledVar's asymptotic p-value and CI still equal `t.test` exactly.
- `ds-fixed-designs-44358267779-f2` (closed): fixed. Realized `prop_acceptable = 0.05` allocations (150 seeds) and 1500 reference draws have the same M distribution (KS p = 0.57).
- `ds-fixed-designs-44358267779-f3` (closed): behaves as now documented. With tied covariates, Greedy and GreedyDOptimal agree in 12 of 20 seeds, and the help pages now describe this.
- `ds-fixed-designs-44358267779-f4` (closed): fixed. The abs_sum_diff MILP at n = 40 stops at `milp_time_limit = 20` s with a message and falls back to annealing.
- `ds-fixed-designs-44358267779-f5` (closed): fixed. `objective_value` equals my M(w) for mahal_dist and abs_sum_diff. The internal value is M·4n_T²n_C²/n⁴ and M·2n_Tn_C/n², as documented, also at `prob_T = 0.4`.
- `ds-fixed-designs-44358267779-f6` (closed): mostly fixed. `n = NULL` now works for assignment in all classes that have the default. Two remnants: iBCRD bootstraps fail under `n = NULL` (new F4), and PairSwitching still has no default (new F5).
