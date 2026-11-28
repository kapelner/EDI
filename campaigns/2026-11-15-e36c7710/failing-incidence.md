[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Failing cells: incidence

52 failing incidence cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | Fixed:Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 991/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.841 **FAIL** (level 0.9, unknown) | 995/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:iBCRD@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 992/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 996/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:SPBR@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:KK21 | IncidExactZhang | exact | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.026 (level 0.05, finite) | 0.882 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidExactZhang | exact | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.032 (level 0.05, finite) | 0.848 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | SeqOneByOne:KK21 | IncidExactZhang | exact | ~1 | 1000 | 1000 (proxy) | Inf (theory) | 0.026 (level 0.05, finite) | 0.882 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | 1000 (proxy) | Inf (theory) | 0.032 (level 0.05, finite) | 0.848 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 1 (level 0.9, cap) | 650/1000 |  |  |
| incidence | SeqOneByOne:KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.198 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 723/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.18 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 727/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.286 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 491/1000 |  |  |
| incidence | Fixed:BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.939 (level 0.9, cap) | 981/1000 |  |  |
| incidence | SeqOneByOne:KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.149 **FAIL** (level 0.1, cap) | 0.913 (level 0.9, cap) | 942/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.919 (level 0.9, cap) | 956/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | SeqOneByOne:KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Fixed:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.877 (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.867 (level 0.9, unknown) | 957/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:iBCRD@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.889 (level 0.9, unknown) | 973/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:SPBR@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 978/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Bernoulli | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0766 **FAIL** (level 0.0525, unknown) | 0.924 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0797 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0784 **FAIL** (level 0.0525, unknown) | 0.922 (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0884 **FAIL** (level 0.0525, unknown) | 0.914 **FAIL** (level 0.948, unknown) | 996/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:iBCRD | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0796 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:iBCRD@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0793 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 996/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Optimal | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0774 **FAIL** (level 0.0525, unknown) | 0.925 (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Rerandomization | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0785 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Fixed:Rerandomization@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0906 **FAIL** (level 0.0525, unknown) | 0.911 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Bernoulli | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0865 **FAIL** (level 0.0525, unknown) | 0.915 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0786 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Efron | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0794 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:iBCRD | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0836 **FAIL** (level 0.0525, unknown) | 0.917 **FAIL** (level 0.948, unknown) | 995/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0855 **FAIL** (level 0.0525, unknown) | 0.916 **FAIL** (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:KK21stepwise | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0765 **FAIL** (level 0.0525, unknown) | 0.925 (level 0.948, unknown) | 996/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:RandomBlockSize | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0785 **FAIL** (level 0.0525, unknown) | 0.924 **FAIL** (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0794 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
