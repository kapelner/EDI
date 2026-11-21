[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Coverage and bias away from the null

### Coverage at beta_T != 0 (gated)

5050 power cells, 3572 with a true estimand value (calibrate_study_truths.R; none for classes that apply only to matched designs, or whose large-sample fits failed); 3572 with enough results tested. Failing cells: **70**.

| response | design | class | procedure | formula | n | n_eff | order (basis) | effect | coverage | finite | note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.806 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.814 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.818 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | power20 | 0.855 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.841 **FAIL** (level 0.9, unknown) | 490/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 484/500 | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.809 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.81 **FAIL** (level 0.9, unknown) | 489/497 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.819 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.837 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.821 **FAIL** (level 0.9, unknown) | 442/457 | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 483/492 | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | score | ~. | 52 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.853 **FAIL** (level 0.9, unknown) | 490/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.817 **FAIL** (level 0.9, unknown) | 481/500 | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.838 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 480/500 | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.829 **FAIL** (level 0.9, unknown) | 486/497 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.827 **FAIL** (level 0.9, unknown) | 439/457 | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 482/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.823 **FAIL** (level 0.9, unknown) | 480/492 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.812 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.808 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.851 **FAIL** (level 0.9, unknown) | 497/497 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.849 **FAIL** (level 0.9, unknown) | 457/457 | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.802 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.831 **FAIL** (level 0.9, unknown) | 492/492 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.82 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.851 **FAIL** (level 0.9, unknown) | 497/497 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.849 **FAIL** (level 0.9, unknown) | 457/457 | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.808 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.835 **FAIL** (level 0.9, unknown) | 492/492 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.851 **FAIL** (level 0.9, unknown) | 457/457 | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.843 **FAIL** (level 0.9, unknown) | 492/492 | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.844 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.844 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | iBCRD | AllSimpleWilcox | wald | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | iBCRD | AllSimpleWilcox | wald | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | iBCRD | AllSimpleWilcox | wald | ~1 | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | iBCRD | AllSimpleWilcox | wald | ~1 | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.837 **FAIL** (level 0.9, cap) | 485/487 |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | lik_ratio | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.839 **FAIL** (level 0.9, cap) | 485/487 |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | Blocking | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.854 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | Greedy | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | GreedyDOptimal | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.854 **FAIL** (level 0.9, cap) | 478/479 |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.819 **FAIL** (level 0.9, cap) | 486/487 |  |
| ordinal | iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.849 **FAIL** (level 0.9, cap) | 497/500 |  |
| ordinal | MatchingGreedyPairSwitching | OrdinalCauchitRegr | score | ~. | 52 | 50 | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.9, cap) | 500/500 |  |

### Bias at beta_T != 0 (reported, not gated)

1704 estimand cells; flagged (z-test at 0.01 / 1592 and |bias| / SD > 0.1): **152**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the largest n, 50): **358** of 1704 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | effect | bias | bias / SD |
|---|---|---|---|---|---|---|---|
| count | GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power20 | 0.461 | 0.83 |
| count | GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power20 | 0.461 | 0.83 |
| count | MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power20 | 0.449 | 0.83 |
| count | MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power20 | 0.449 | 0.83 |
| count | Greedy | AllSimpleWilcox | ~. | 50 | power20 | 0.46 | 0.83 |
| count | Greedy | AllSimpleWilcox | ~1 | 50 | power20 | 0.46 | 0.83 |
| count | BinaryMatch | AllSimpleWilcox | ~. | 50 | power20 | 0.414 | 0.76 |
| count | BinaryMatch | AllSimpleWilcox | ~1 | 50 | power20 | 0.414 | 0.76 |
| count | Optimal | AllSimpleWilcox | ~. | 50 | power20 | 0.396 | 0.75 |
| count | Optimal | AllSimpleWilcox | ~1 | 50 | power20 | 0.396 | 0.75 |
| count | Blocking | AllSimpleWilcox | ~. | 50 | power20 | 0.464 | 0.72 |
| count | Blocking | AllSimpleWilcox | ~1 | 50 | power20 | 0.464 | 0.72 |
| count | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0.472 | 0.72 |
| count | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0.472 | 0.72 |
| count | Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0.479 | 0.71 |
| count | Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0.479 | 0.71 |
| count | Rerandomization | AllSimpleWilcox | ~. | 50 | power20 | 0.47 | 0.7 |
| count | Rerandomization | AllSimpleWilcox | ~1 | 50 | power20 | 0.47 | 0.7 |
| survival | MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~. | 52 | power20 | -0.198 | -0.68 |
| survival | MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~1 | 52 | power20 | -0.198 | -0.68 |
| count | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0.418 | 0.66 |
| count | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0.418 | 0.66 |
| count | OptimalBlocks | AllSimpleWilcox | ~. | 50 | power20 | 0.405 | 0.65 |
| count | OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power20 | 0.405 | 0.65 |
| survival | iBCRD | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | -0.219 | -0.64 |
| survival | iBCRD | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | -0.219 | -0.64 |
| survival | Optimal | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | -0.198 | -0.63 |
| survival | Optimal | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | -0.198 | -0.63 |
| count | Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0.541 | 0.61 |
| count | Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0.541 | 0.61 |
(30 shown of 358; all in [`summary/nonnull_bias_summary.csv`](summary/nonnull_bias_summary.csv).)

| response | design | class | formula | n | effect | true value | bias | bias / SD |
|---|---|---|---|---|---|---|---|---|
| count | GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.461 | 0.83 |
| count | GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.461 | 0.83 |
| count | MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power20 | 0 | 0.449 | 0.83 |
| count | MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power20 | 0 | 0.449 | 0.83 |
| count | Greedy | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.46 | 0.83 |
| count | Greedy | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.46 | 0.83 |
| count | BinaryMatch | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.414 | 0.76 |
| count | BinaryMatch | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.414 | 0.76 |
| count | Optimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.396 | 0.75 |
| count | Optimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.396 | 0.75 |
| count | Blocking | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.464 | 0.72 |
| count | Blocking | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.464 | 0.72 |
| count | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.472 | 0.72 |
| count | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.472 | 0.72 |
| count | Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.479 | 0.71 |
| count | Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.479 | 0.71 |
| count | Rerandomization | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.47 | 0.7 |
| count | Rerandomization | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.47 | 0.7 |
| survival | MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~. | 52 | power20 | 0.456 | -0.198 | -0.68 |
| survival | MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~1 | 52 | power20 | 0.456 | -0.198 | -0.68 |
| count | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.418 | 0.66 |
| count | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.418 | 0.66 |
| count | OptimalBlocks | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.405 | 0.65 |
| count | OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.405 | 0.65 |
| survival | iBCRD | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.219 | -0.64 |
| survival | iBCRD | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.219 | -0.64 |
| survival | Optimal | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.198 | -0.63 |
| survival | Optimal | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.198 | -0.63 |
| count | Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.541 | 0.61 |
| count | Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.541 | 0.61 |
| count | Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.386 | 0.59 |
| count | Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.386 | 0.59 |
| survival | Blocking | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.206 | -0.59 |
| survival | Blocking | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.206 | -0.59 |
| survival | Greedy | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | Greedy | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | GreedyDOptimal | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | GreedyDOptimal | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | BinaryMatch | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.192 | -0.58 |
| survival | BinaryMatch | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.192 | -0.58 |
| survival | OptimalBlocks | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.53 |
| survival | OptimalBlocks | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.53 |
| survival | Bernoulli | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.182 | -0.51 |
| survival | Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.182 | -0.51 |
| ordinal | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.188 | 0.47 |
| ordinal | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.188 | 0.47 |
| survival | Rerandomization | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.176 | -0.47 |
| survival | Rerandomization | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.176 | -0.47 |
| ordinal | MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power20 | 0 | 0.18 | 0.47 |
| ordinal | MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power20 | 0 | 0.18 | 0.47 |
| ordinal | iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.186 | 0.46 |
| ordinal | iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.186 | 0.46 |
| ordinal | OptimalBlocks | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.183 | 0.46 |
| ordinal | OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.183 | 0.46 |
| ordinal | Rerandomization | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.176 | 0.46 |
| ordinal | Rerandomization | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.176 | 0.46 |
| survival | Bernoulli | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.169 | -0.45 |
| survival | Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.169 | -0.45 |
| ordinal | Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.17 | 0.44 |
| ordinal | Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.17 | 0.44 |
| ordinal | Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.165 | 0.44 |
| ordinal | Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.165 | 0.44 |
| ordinal | BinaryMatch | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.16 | 0.42 |
| ordinal | BinaryMatch | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.16 | 0.42 |
| ordinal | Greedy | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | Greedy | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.146 | 0.41 |
| ordinal | GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.146 | 0.41 |
| ordinal | Blocking | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.159 | 0.41 |
| ordinal | Blocking | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.159 | 0.41 |
| ordinal | Optimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.136 | 0.4 |
| ordinal | Optimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.136 | 0.4 |
| ordinal | Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.164 | 0.37 |
| ordinal | Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.164 | 0.37 |
| ordinal | OptimalBlocks | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.382 | 0.35 |
| ordinal | Rerandomization | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.325 | 0.33 |
| ordinal | Greedy | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.346 | 0.33 |
| ordinal | GreedyDOptimal | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.339 | 0.33 |
| ordinal | BinaryMatch | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.347 | 0.32 |
| ordinal | iBCRD | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.346 | 0.31 |
| ordinal | Optimal | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.302 | 0.31 |
| ordinal | iBCRD | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.341 | 0.31 |
| ordinal | BinaryMatch | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.409 | 0.3 |
| ordinal | Blocking | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.301 | 0.3 |
| ordinal | Bernoulli | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.328 | 0.3 |
| ordinal | iBCRD | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.48 | 0.3 |
| ordinal | Bernoulli | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.326 | 0.29 |
| ordinal | iBCRD | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.111 | 0.29 |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.242 | 0.28 |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.242 | 0.28 |
| ordinal | MatchingGreedyPairSwitching | OrdinalCauchitRegr | ~. | 52 | power20 | 0.534 | 0.264 | 0.28 |
| ordinal | OptimalBlocks | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.436 | 0.27 |
| incidence | Blocking | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.226 | 0.27 |
| ordinal | MatchingGreedyPairSwitching | OrdinalStereotypeLogitRegr | ~. | 52 | power20 | 0.895 | 0.358 | 0.26 |
| incidence | Greedy | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.217 | 0.26 |
| incidence | GreedyDOptimal | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.217 | 0.26 |
| ordinal | Rerandomization | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.405 | 0.26 |
| ordinal | Bernoulli | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.403 | 0.26 |
| ordinal | GreedyDOptimal | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.404 | 0.25 |
| continuous | MatchingGreedyPairSwitching | ContinQuantileRegr | ~1 | 52 | power20 | 0.317 | -0.0803 | -0.25 |
| incidence | BinaryMatch | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.207 | 0.25 |
| incidence | Blocking | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.125 | 0.25 |
| incidence | Bernoulli | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.23 | 0.25 |
| incidence | iBCRD | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.213 | 0.25 |
| ordinal | Greedy | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.391 | 0.25 |
| ordinal | BinaryMatch | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0941 | 0.25 |
| incidence | MatchingGreedyPairSwitching | IncidLogRegr | ~. | 52 | power20 | 0.667 | 0.212 | 0.24 |
| incidence | Greedy | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.117 | 0.24 |
| incidence | GreedyDOptimal | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.117 | 0.24 |
| ordinal | Rerandomization | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0893 | 0.24 |
| incidence | Bernoulli | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.215 | 0.24 |
| ordinal | Blocking | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.356 | 0.24 |
| ordinal | Bernoulli@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.509 | 0.24 |
| incidence | BinaryMatch | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.113 | 0.24 |
| incidence | OptimalBlocks | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.207 | 0.24 |
| incidence | Bernoulli | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.125 | 0.23 |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0799 | 0.23 |
| incidence | MatchingGreedyPairSwitching | IncidProbitRegr | ~. | 52 | power20 | 0.401 | 0.115 | 0.23 |
| incidence | iBCRD | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.23 |
| survival | Bernoulli | SurvivalCoxPHRegr | ~. | 50 | power20 | -0.405 | -0.112 | -0.23 |
| incidence | Blocking | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0763 | 0.23 |
| ordinal | MatchingGreedyPairSwitching | OrdinalAdjCatLogitRegr | ~. | 52 | power20 | 0.301 | 0.0836 | 0.23 |
| incidence | Bernoulli | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0833 | 0.22 |
| incidence | Bernoulli | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.22 |
| incidence | OptimalBlocks | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.22 |
| survival | Bernoulli | SurvivalStratCoxPHRegr | ~. | 50 | power20 | -0.405 | -0.116 | -0.22 |
| incidence | Blocking | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0782 | 0.22 |
| ordinal | Bernoulli | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.347 | 0.22 |
| ordinal | iBCRD | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.349 | 0.22 |
| ordinal | iBCRD | OrdinalPropOddsRegr | ~. | 50 | power20 | 0.61 | 0.151 | 0.22 |
| ordinal | iBCRD | OrdinalPartialProportionalOddsRegr | ~. | 50 | power20 | 0.61 | 0.151 | 0.22 |
| ordinal | GreedyDOptimal | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0821 | 0.22 |
| ordinal | iBCRD | OrdinalOrderedProbitRegr | ~. | 50 | power20 | 0.361 | 0.0865 | 0.22 |
| ordinal | MatchingGreedyPairSwitching | OrdinalCloglogRegr | ~. | 52 | power20 | 0.418 | 0.102 | 0.22 |
| incidence | OptimalBlocks | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.085 | 0.22 |
| incidence | Optimal | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.169 | 0.22 |
| ordinal | OptimalBlocks | OrdinalCauchitRegr | ~1 | 50 | power20 | 0.365 | 0.108 | 0.22 |
| ordinal | BinaryMatch | OrdinalCloglogRegr | ~. | 50 | power20 | 0.418 | 0.109 | 0.22 |
| ordinal | OptimalBlocks | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0827 | 0.21 |
| ordinal | iBCRD | OrdinalContRatioRegr | ~. | 50 | power20 | 0.508 | 0.129 | 0.21 |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~. | 52 | power20 | 1.26 | 0.074 | 0.21 |
| ordinal | Greedy | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0792 | 0.21 |
| incidence | OptimalBlocks | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0832 | 0.21 |
| incidence | Greedy | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0661 | 0.21 |
| incidence | GreedyDOptimal | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0661 | 0.21 |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0801 | 0.21 |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~1 | 52 | power20 | 1.26 | 0.0726 | 0.21 |
| ordinal | Bernoulli | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0836 | 0.21 |
| ordinal | Rerandomization | OrdinalCloglogRegr | ~. | 50 | power20 | 0.418 | 0.103 | 0.21 |
| ordinal | Optimal | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.301 | 0.2 |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | ~1 | 50 | power20 | 0.202 | -0.083 | -0.2 |
| incidence | iBCRD | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0662 | 0.2 |



[← Campaign 2026-11-09-8c32d060 summary](README.md)
