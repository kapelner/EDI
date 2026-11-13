[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Failing cells: ordinal

34 failing ordinal cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ordinal | Bernoulli@0.2 | OrdinalCauchitRegr | gradient | ~. | 50 | 10 | 1 (assumed_default) | 0.13 **FAIL** (level 0.1, cap) | 0.892 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | BinaryMatch | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.857 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Greedy | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | GreedyDOptimal | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | OptimalBlocks | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.873 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Efron | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.875 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | PocockSimon | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.871 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | RandomBlockSize | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.132 **FAIL** (level 0.1, cap) | 0.875 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Urn | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.136 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | OptimalBlocks | OrdinalCauchitRegr | lik_ratio | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.874 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Urn | OrdinalCauchitRegr | lik_ratio | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.87 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.856 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Bernoulli@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 997/1000 |  |  |
| ordinal | BinaryMatch | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.152 **FAIL** (level 0.1, cap) | 0.847 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Blocking | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Greedy | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | GreedyDOptimal | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.136 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | OptimalBlocks | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.148 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Rerandomization | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.13 **FAIL** (level 0.1, cap) | 0.871 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Atkinson | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.139 **FAIL** (level 0.1, cap) | 0.863 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.138 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Efron | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.855 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.148 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | KK14 | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.857 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | KK21 | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.13 **FAIL** (level 0.1, cap) | 0.871 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | PocockSimon | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.854 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | RandomBlockSize | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.138 **FAIL** (level 0.1, cap) | 0.862 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SPBR | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.139 **FAIL** (level 0.1, cap) | 0.865 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Urn | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.152 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | MatchingGreedyPairSwitching | OrdinalCauchitRegr | score | ~. | 52 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.875 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | BinaryMatch | OrdinalGCompMeanDiff | rand | ~1 | 50 | 50 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| ordinal | BinaryMatch | OrdinalKKGEE | rand | ~. | 50 | 25 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| ordinal | BinaryMatch | OrdinalPartialProportionalOddsRegr | rand | ~1 | 50 | 50 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |


[← Campaign 2026-11-09-8c32d060 summary](README.md)
