[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Failing cells: ordinal

55 failing ordinal cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| ordinal | Fixed:Greedy | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:GreedyDOptimal | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:OptimalBlocks | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.133 **FAIL** (level 0.1, cap) | 0.873 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Bernoulli@0.2 | OrdinalCauchitRegr | gradient | ~. | 50 | 10 | 1 (assumed_default) | 0.136 **FAIL** (level 0.1, cap) | 0.882 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:iBCRD@0.2 | OrdinalCauchitRegr | gradient | ~. | 50 | 10 | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.872 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:PocockSimon | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.871 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.132 **FAIL** (level 0.1, cap) | 0.875 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Urn | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | 0.136 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | gradient | ~. | 200 | 200 | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | gradient | ~. | 1000 | 200 | 1 (assumed_default) | 0.076 **FAIL** (level 0.05, rate check) | 0.924 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalCauchitRegr | gradient | ~. | 1000 | 1000 | 1 (assumed_default) | 0.075 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:SPBR@0.2 | OrdinalCauchitRegr | gradient | ~. | 1000 | 200 | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Bernoulli@0.2 | OrdinalCauchitRegr | lik_ratio | ~. | 50 | 10 | 1 (assumed_default) | 0.138 **FAIL** (level 0.1, cap) | 0.87 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Urn | OrdinalCauchitRegr | lik_ratio | ~. | 50 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.87 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | lik_ratio | ~. | 200 | 200 | 1 (assumed_default) | 0.089 **FAIL** (level 0.0625, rate) | 0.911 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | lik_ratio | ~. | 1000 | 200 | 1 (assumed_default) | 0.075 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalCauchitRegr | lik_ratio | ~. | 1000 | 1000 | 1 (assumed_default) | 0.074 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:SPBR@0.2 | OrdinalCauchitRegr | lik_ratio | ~. | 1000 | 200 | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.856 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:Bernoulli@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 997/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.152 **FAIL** (level 0.1, cap) | 0.847 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:Blocking | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:Blocking@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.158 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 999/1000 |  |  |
| ordinal | Fixed:Greedy | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:Greedy@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.845 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:GreedyDOptimal | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:GreedyDOptimal@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.845 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.136 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.173 **FAIL** (level 0.1, cap) | 0.839 **FAIL** (level 0.9, cap) | 995/1000 |  |  |
| ordinal | Fixed:Optimal@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.155 **FAIL** (level 0.1, cap) | 0.854 **FAIL** (level 0.9, cap) | 998/1000 |  |  |
| ordinal | Fixed:OptimalBlocks | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.148 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:OptimalBlocks@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.194 **FAIL** (level 0.1, cap) | 0.812 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:Rerandomization@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.146 **FAIL** (level 0.1, cap) | 0.86 **FAIL** (level 0.9, cap) | 996/1000 |  |  |
| ordinal | SeqOneByOne:Atkinson | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.139 **FAIL** (level 0.1, cap) | 0.863 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.138 **FAIL** (level 0.1, cap) | 0.868 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:Bernoulli@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.197 **FAIL** (level 0.1, cap) | 0.818 **FAIL** (level 0.9, cap) | 997/1000 |  |  |
| ordinal | SeqOneByOne:Efron | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.855 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.148 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:iBCRD@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.19 **FAIL** (level 0.1, cap) | 0.821 **FAIL** (level 0.9, cap) | 997/1000 |  |  |
| ordinal | SeqOneByOne:KK14 | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.857 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:PocockSimon | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.854 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.138 **FAIL** (level 0.1, cap) | 0.862 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:RandomBlockSize@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.169 **FAIL** (level 0.1, cap) | 0.846 **FAIL** (level 0.9, cap) | 996/1000 |  |  |
| ordinal | SeqOneByOne:SPBR | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.139 **FAIL** (level 0.1, cap) | 0.865 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:SPBR@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.846 **FAIL** (level 0.9, cap) | 998/1000 |  |  |
| ordinal | SeqOneByOne:Urn | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | 0.152 **FAIL** (level 0.1, cap) | 0.852 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalCauchitRegr | score | ~. | 52 | 50 | 1 (assumed_default) | 0.131 **FAIL** (level 0.1, cap) | 0.875 (level 0.9, cap) | 1000/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | score | ~. | 200 | 200 | 1 (assumed_default) | 0.088 **FAIL** (level 0.0625, rate) | 0.911 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | score | ~. | 1000 | 1000 | 1 (assumed_default) | 0.075 (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | score | ~. | 1000 | 200 | 1 (assumed_default) | 0.075 (level 0.0625, rate) | 0.924 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalCauchitRegr | score | ~. | 1000 | 1000 | 1 (assumed_default) | 0.074 (level 0.0525, rate) | 0.922 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:PocockSimon | OrdinalCauchitRegr | score | ~. | 1000 | 1000 | 1 (assumed_default) | 0.07 (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | score | ~. | 1000 | 1000 | 1 (assumed_default) | 0.075 (level 0.05, rate check) | 0.923 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | wald | ~. | 1000 | 200 | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| ordinal | Fixed:BinaryMatch | OrdinalKKGEE | rand | ~. | 50 | 25 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
