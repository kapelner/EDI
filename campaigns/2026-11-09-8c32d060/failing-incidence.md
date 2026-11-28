[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Failing cells: incidence

16 failing incidence cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 991/1000 |  | rate unknown: open a TODO to establish it |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 1 (level 0.9, cap) | 650/1000 |  |  |
| incidence | KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.198 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 723/1000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.18 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 727/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.286 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 491/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.939 (level 0.9, cap) | 981/1000 |  |  |
| incidence | KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.149 **FAIL** (level 0.1, cap) | 0.913 (level 0.9, cap) | 942/1000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.919 (level 0.9, cap) | 956/1000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Bernoulli@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.877 (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.882 (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |


[← Campaign 2026-11-09-8c32d060 summary](README.md)
