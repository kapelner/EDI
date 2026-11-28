[← Campaign 2026-11-11-9d2edc5c summary](README.md)

# Failing cells: incidence

76 failing incidence cell(s) (provisional: confirmation pending or running).

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 2973/3000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.841 **FAIL** (level 0.9, unknown) | 1990/2000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 1998/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.129 **FAIL** (level 0.1, unknown) | 0.871 **FAIL** (level 0.9, unknown) | 1998/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1984/2000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 1992/2000 |  | rate unknown: open a TODO to establish it |
| incidence | SPBR@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 1996/2000 |  | rate unknown: open a TODO to establish it |
| incidence | KK21 | IncidExactZhang | exact | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.026 (level 0.05, finite) | 0.882 **FAIL** (level 0.95, finite) | 2000/2000 |  |  |
| incidence | KK21stepwise | IncidExactZhang | exact | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.0306 (level 0.05, finite) | 0.85 **FAIL** (level 0.95, finite) | 1635/1635 |  |  |
| incidence | KK21 | IncidExactZhang | exact | ~1 | 1000 | 1000 (proxy) | Inf (theory) | 0.026 (level 0.05, finite) | 0.882 **FAIL** (level 0.95, finite) | 2000/2000 |  |  |
| incidence | KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | 1000 (proxy) | Inf (theory) | 0.0306 (level 0.05, finite) | 0.85 **FAIL** (level 0.95, finite) | 1635/1635 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 4000/4000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 4000/4000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 4000/4000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 4000/4000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 4000/4000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 4000/4000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 4000/4000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 4000/4000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 4000/4000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 4000/4000 |  |  |
| incidence | Bernoulli@0.2 | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.123 **FAIL** (level 0.1, cap) | 0.877 **FAIL** (level 0.9, cap) | 3000/3000 |  |  |
| incidence | SPBR@0.2 | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 2000/2000 |  |  |
| incidence | BinaryMatch | IncidGCompRiskDiff | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.0639 **FAIL** (level 0.05, rate check) | 0.936 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | gradient | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0702 **FAIL** (level 0.05, rate check) | 0.93 **FAIL** (level 0.945, rate) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 1 (level 0.9, cap) | 2600/4000 |  |  |
| incidence | KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.198 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 2169/3000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.18 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 2181/3000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0692 **FAIL** (level 0.055, rate) | 0.931 **FAIL** (level 0.945, rate) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.286 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 1964/4000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0692 **FAIL** (level 0.055, rate) | 0.931 **FAIL** (level 0.945, rate) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.939 (level 0.9, cap) | 3924/4000 |  |  |
| incidence | KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.149 **FAIL** (level 0.1, cap) | 0.913 (level 0.9, cap) | 2826/3000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.919 (level 0.9, cap) | 2868/3000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0702 **FAIL** (level 0.055, rate) | 0.93 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | lik_ratio | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0692 **FAIL** (level 0.05, rate check) | 0.931 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | score | ~. | 1000 | 500 (proxy) | 1 (assumed_default) | 0.0692 **FAIL** (level 0.05, rate check) | 0.931 **FAIL** (level 0.95, rate check) | 3990/3990 |  |  |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.127 **FAIL** (level 0.1, cap) | 0.873 **FAIL** (level 0.9, cap) | 3000/3000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 3000/3000 |  |  |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | 25 (proxy) | 1 (assumed_default) | 0.127 **FAIL** (level 0.1, cap) | 0.873 **FAIL** (level 0.9, cap) | 3000/3000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 3000/3000 |  |  |
| incidence | Blocking@0.2 | IncidLogBinomial | lik_ratio | ~. | 1000 | 1000 (proxy) | unknown | 0.075 **FAIL** (level 0.0525, unknown) | 0.925 **FAIL** (level 0.948, unknown) | 2000/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli | IncidLogBinomial | lik_ratio | ~. | 1000 | 1000 (proxy) | unknown | 0.069 **FAIL** (level 0.0525, unknown) | 0.931 **FAIL** (level 0.948, unknown) | 4000/4000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD | IncidLogBinomial | lik_ratio | ~. | 1000 | 1000 (proxy) | unknown | 0.069 **FAIL** (level 0.0525, unknown) | 0.931 **FAIL** (level 0.948, unknown) | 4000/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.13 **FAIL** (level 0.1, unknown) | 0.887 (level 0.9, unknown) | 3868/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.877 **FAIL** (level 0.9, unknown) | 2883/3000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.122 **FAIL** (level 0.1, unknown) | 0.9 (level 0.9, unknown) | 2910/3000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 1914/2000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.889 (level 0.9, unknown) | 1946/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Optimal@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1926/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.882 (level 0.9, unknown) | 3908/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Efron | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.126 **FAIL** (level 0.1, unknown) | 0.886 (level 0.9, unknown) | 3876/4000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.88 (level 0.9, unknown) | 1940/2000 |  | rate unknown: open a TODO to establish it |
| incidence | KK14 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.126 **FAIL** (level 0.1, unknown) | 0.892 (level 0.9, unknown) | 2889/3000 |  | rate unknown: open a TODO to establish it |
| incidence | SPBR@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.87 **FAIL** (level 0.9, unknown) | 1956/2000 |  | rate unknown: open a TODO to establish it |
| incidence | MatchingGreedyPairSwitching | IncidLogBinomial | score | ~. | 52 | 50 (proxy) | unknown | 0.122 **FAIL** (level 0.1, unknown) | 0.894 (level 0.9, unknown) | 3892/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0766 **FAIL** (level 0.0525, unknown) | 0.924 **FAIL** (level 0.948, unknown) | 3988/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0797 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 2991/3000 |  | rate unknown: open a TODO to establish it |
| incidence | BinaryMatch | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0701 **FAIL** (level 0.0525, unknown) | 0.93 **FAIL** (level 0.948, unknown) | 2984/2990 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0784 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 2991/3000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0884 **FAIL** (level 0.0525, unknown) | 0.914 **FAIL** (level 0.948, unknown) | 1992/2000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0796 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 3992/4000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0793 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 1992/2000 |  | rate unknown: open a TODO to establish it |
| incidence | MatchingGreedyPairSwitching | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0676 **FAIL** (level 0.0525, unknown) | 0.934 (level 0.948, unknown) | 3992/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Optimal | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0774 **FAIL** (level 0.0525, unknown) | 0.925 **FAIL** (level 0.948, unknown) | 3992/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0785 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 3988/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0906 **FAIL** (level 0.0525, unknown) | 0.911 **FAIL** (level 0.948, unknown) | 1994/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0865 **FAIL** (level 0.0525, unknown) | 0.915 **FAIL** (level 0.948, unknown) | 3988/4000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0786 **FAIL** (level 0.0525, unknown) | 0.922 **FAIL** (level 0.948, unknown) | 1994/2000 |  | rate unknown: open a TODO to establish it |
| incidence | Efron | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0794 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 3992/4000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0836 **FAIL** (level 0.0525, unknown) | 0.917 **FAIL** (level 0.948, unknown) | 3980/4000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0855 **FAIL** (level 0.0525, unknown) | 0.916 **FAIL** (level 0.948, unknown) | 1996/2000 |  | rate unknown: open a TODO to establish it |
| incidence | PocockSimon | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0714 **FAIL** (level 0.0525, unknown) | 0.93 **FAIL** (level 0.948, unknown) | 3996/4000 |  | rate unknown: open a TODO to establish it |
| incidence | RandomBlockSize@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0794 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 1998/2000 |  | rate unknown: open a TODO to establish it |

[← Campaign 2026-11-11-9d2edc5c summary](README.md)
