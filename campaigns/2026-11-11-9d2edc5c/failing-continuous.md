[← Campaign 2026-11-11-9d2edc5c summary](README.md)

# Failing cells: continuous

70 failing continuous cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~. | 1000 | 1000 | Inf (theory) | 0.0698 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1949/1949 |  |  |
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0698 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1949/1949 |  |  |
| continuous | BinaryMatch | ContinKKOLSOneLik | rand | ~1 | 200 | 100 (proxy) | Inf (theory) | 0.0605 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6824/6824 |  |  |
| continuous | BinaryMatch | ContinKKRobustRegrOneLik | rand | ~1 | 200 | 100 (proxy) | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | KK14 | ContinKKRobustRegrOneLik | wald | ~. | 50 | 25 (proxy) | unknown | 0.124 **FAIL** (level 0.1, unknown) | 0.876 **FAIL** (level 0.9, unknown) | 7365/7365 |  | rate unknown: open a TODO to establish it |
| continuous | Rerandomization | ContinLin | gradient | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0744 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 3855/3855 |  |  |
| continuous | Rerandomization | ContinLin | lik_ratio | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0744 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 3855/3855 |  |  |
| continuous | KK21 | ContinLin | rand | ~. | 50 | 50 | Inf (theory) | 0.0661 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7311/7311 |  |  |
| continuous | PocockSimon | ContinLin | rand | ~. | 50 | 50 | Inf (theory) | 0.064 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4000/4000 |  |  |
| continuous | Blocking | ContinLin | rand | ~. | 200 | 200 | Inf (theory) | 0.071 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4000/4000 |  |  |
| continuous | iBCRD@0.2 | ContinLin | rand | ~. | 200 | 200 | Inf (theory) | 0.071 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |
| continuous | MatchingGreedyPairSwitching | ContinLin | rand | ~. | 200 | 200 | Inf (theory) | 0.064 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4000/4000 |  |  |
| continuous | iBCRD | ContinLin | rand | ~1 | 200 | 200 | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4000/4000 |  |  |
| continuous | iBCRD@0.2 | ContinLin | rand | ~1 | 200 | 200 | Inf (theory) | 0.072 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |
| continuous | Bernoulli@0.2 | ContinLin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0753 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3680/3680 |  |  |
| continuous | iBCRD | ContinLin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0698 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3912/3912 |  |  |
| continuous | Rerandomization | ContinLin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0755 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3855/3855 |  |  |
| continuous | Rerandomization | ContinLin | score | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0744 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 3855/3855 |  |  |
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 4000/4000 |  |  |
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.192 **FAIL** (level 0.1, cap) | 0.808 **FAIL** (level 0.9, cap) | 2000/2000 |  |  |
| continuous | Bernoulli@0.2 | ContinLin | wald | ~1 | 1000 | 200 | 1 (assumed_default) | 0.0739 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 3680/3680 |  |  |
| continuous | Rerandomization | ContinLin | wald | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0744 **FAIL** (level 0.0525, rate) | 0.926 **FAIL** (level 0.948, rate) | 3855/3855 |  |  |
| continuous | Rerandomization | ContinOLS | gradient | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0746 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 4855/4855 |  |  |
| continuous | Rerandomization | ContinOLS | lik_ratio | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0746 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 4855/4855 |  |  |
| continuous | KK21 | ContinOLS | rand | ~. | 50 | 50 | Inf (theory) | 0.0674 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7311/7311 |  |  |
| continuous | Blocking | ContinOLS | rand | ~. | 200 | 200 | Inf (theory) | 0.068 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | iBCRD@0.2 | ContinOLS | rand | ~. | 200 | 200 | Inf (theory) | 0.07 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 2000/2000 |  |  |
| continuous | MatchingGreedyPairSwitching | ContinOLS | rand | ~. | 200 | 200 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | iBCRD | ContinOLS | rand | ~. | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | Blocking | ContinOLS | rand | ~1 | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | iBCRD | ContinOLS | rand | ~1 | 200 | 200 | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | iBCRD@0.2 | ContinOLS | rand | ~1 | 200 | 200 | Inf (theory) | 0.072 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 2000/2000 |  |  |
| continuous | MatchingGreedyPairSwitching | ContinOLS | rand | ~1 | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | Bernoulli@0.2 | ContinOLS | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0746 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4680/4680 |  |  |
| continuous | iBCRD | ContinOLS | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0698 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4911/4911 |  |  |
| continuous | Rerandomization | ContinOLS | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0756 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4855/4855 |  |  |
| continuous | Rerandomization | ContinOLS | score | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0746 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 4855/4855 |  |  |
| continuous | Rerandomization | ContinOLS | wald | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.0746 **FAIL** (level 0.0525, rate) | 0.925 **FAIL** (level 0.948, rate) | 4855/4855 |  |  |
| continuous | OptimalBlocks | ContinQuantileRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.061 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | Bernoulli | ContinQuantileRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.061 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | KK21 | ContinQuantileRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.0617 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5607/5607 |  |  |
| continuous | KK21stepwise | ContinQuantileRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.0613 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5771/5771 |  |  |
| continuous | Blocking | ContinQuantileRegr | rand | ~. | 200 | 200 | Inf (theory) | 0.061 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | Rerandomization | ContinQuantileRegr | rand | ~. | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | OptimalBlocks | ContinQuantileRegr | rand | ~. | 1000 | 1000 | Inf (theory) | 0.0619 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5720/5720 |  |  |
| continuous | iBCRD | ContinQuantileRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.064 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | iBCRD | ContinQuantileRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | SPBR | ContinQuantileRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 5000/5000 |  |  |
| continuous | KK21 | ContinQuantileRegr | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0748 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1297/1297 |  |  |
| continuous | Blocking@0.2 | ContinQuantileRegr | wald | ~. | 1000 | 200 | 0.667 (literature) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 2000/2000 |  |  |
| continuous | iBCRD | ContinQuantileRegr | wald | ~. | 1000 | 1000 | 0.667 (literature) | 0.0749 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 5911/5911 |  |  |
| continuous | OptimalBlocks | ContinQuantileRegr | wald | ~. | 1000 | 1000 | 0.667 (literature) | 0.0624 **FAIL** (level 0.05, rate check) | 0.938 **FAIL** (level 0.95, rate check) | 5720/5720 |  |  |
| continuous | Rerandomization@0.2 | ContinQuantileRegr | wald | ~. | 1000 | 200 | 0.667 (literature) | 0.071 **FAIL** (level 0.05, rate check) | 0.929 **FAIL** (level 0.95, rate check) | 2000/2000 |  |  |
| continuous | Greedy | ContinRobustRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | GreedyDOptimal | ContinRobustRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | Rerandomization@0.2 | ContinRobustRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |
| continuous | KK21 | ContinRobustRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.0698 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 2607/2607 |  |  |
| continuous | PocockSimon | ContinRobustRegr | rand | ~. | 50 | 50 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | MatchingGreedyPairSwitching | ContinRobustRegr | rand | ~. | 52 | 50 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | Blocking | ContinRobustRegr | rand | ~. | 200 | 200 | Inf (theory) | 0.069 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | iBCRD@0.2 | ContinRobustRegr | rand | ~. | 200 | 200 | Inf (theory) | 0.068 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |
| continuous | PocockSimon | ContinRobustRegr | rand | ~1 | 50 | 50 | Inf (theory) | 0.063 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | BinaryMatch | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.065 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3798/3798 |  |  |
| continuous | Blocking | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.062 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | iBCRD | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | iBCRD@0.2 | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.066 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |
| continuous | MatchingGreedyPairSwitching | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.061 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 7000/7000 |  |  |
| continuous | SPBR | ContinRobustRegr | rand | ~1 | 200 | 200 | Inf (theory) | 0.069 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 6000/6000 |  |  |
| continuous | iBCRD | ContinRobustRegr | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0651 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 4912/4912 |  |  |
| continuous | Rerandomization | ContinRobustRegr | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.067 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 3000/3000 |  |  |

[← Campaign 2026-11-11-9d2edc5c summary](README.md)
