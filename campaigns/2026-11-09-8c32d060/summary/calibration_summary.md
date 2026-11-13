## EDI calibration study, campaign 2026-11-09-8c32d060

Progress: 192767 of 872000 replicates (22%) after wave 15; 225 of 1308 cells complete, 0 abandoned.

9166 null cells and 5050 power cells; 19251 tests (null size and coverage, coverage of the true estimand at the power effects). Two-stage gate: Benjamini-Hochberg q < 0.05 on the screening replicates flags **556** test(s); each flagged cell is re-run on fresh replicates and fails only if those alone reject (at 0.01 / 556).

Confirmation: pending (the flags are provisional). Failing null cells so far: **283**.

Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of 0.1 reached at n_eff = 50 (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n (`rate check`). Null cells by rule (size): cap 5242, finite 2306, mismatch 286, unknown 1332.

158 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
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
| count | Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.1, cap) | 0.842 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.836 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.184 **FAIL** (level 0.1, cap) | 0.816 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 0.812 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.856 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.849 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.1, cap) | 0.827 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.182 **FAIL** (level 0.1, cap) | 0.818 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.1, cap) | 0.815 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.1, cap) | 0.831 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.153 **FAIL** (level 0.1, cap) | 0.848 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Blocking | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.156 **FAIL** (level 0.1, cap) | 0.844 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | OptimalBlocks | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Rerandomization | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.1, cap) | 0.821 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Efron | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.183 **FAIL** (level 0.1, cap) | 0.817 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | KK14 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | PocockSimon | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | RandomBlockSize | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SPBR | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.167 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Urn | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.865 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | gradient | ~. | 52 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.879 (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.876 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.874 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.885 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | lik_ratio | ~. | 52 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.095 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 968/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | BinaryMatch | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0848 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Blocking | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0948 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 960/1000 |  |  |
| count | Greedy | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | GreedyDOptimal | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0912 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0944 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 943/1000 |  |  |
| count | Rerandomization | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0972 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Atkinson | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 956/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0933 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | Efron | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.102 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 962/1000 |  |  |
| count | iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0814 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 970/1000 |  |  |
| count | KK21 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0865 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 959/1000 |  |  |
| count | KK21stepwise | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0976 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 973/1000 |  |  |
| count | RandomBlockSize | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.101 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 966/1000 |  |  |
| count | SPBR | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0924 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 963/1000 |  |  |
| count | Urn | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0784 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 957/1000 |  |  |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~. | 52 | 50 | Inf (theory) | 0.086 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 977/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Blocking | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Greedy | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | GreedyDOptimal | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Atkinson | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Efron | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SPBR | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~1 | 52 | 50 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.221 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.216 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.202 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.208 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.212 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.224 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.229 **FAIL** (level 0.1, unknown) | 0.787 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.22 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.207 **FAIL** (level 0.1, unknown) | 0.809 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.196 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.213 **FAIL** (level 0.1, unknown) | 0.798 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.183 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 973/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.227 **FAIL** (level 0.1, unknown) | 0.806 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.186 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | score | ~. | 52 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.127 (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.13 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | BinaryMatch | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.179 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 953/1000 |  | rate unknown: open a TODO to establish it |
| count | Greedy | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | GreedyDOptimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 958/1000 |  | rate unknown: open a TODO to establish it |
| count | Optimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.193 **FAIL** (level 0.1, unknown) | 0.807 **FAIL** (level 0.9, unknown) | 940/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.195 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.189 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 952/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.185 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 948/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.188 **FAIL** (level 0.1, unknown) | 0.812 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.174 **FAIL** (level 0.1, unknown) | 0.826 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.167 **FAIL** (level 0.1, unknown) | 0.833 **FAIL** (level 0.9, unknown) | 951/1000 |  | rate unknown: open a TODO to establish it |
| count | MatchingGreedyPairSwitching | CountZeroInflatedNegBin | wald | ~. | 52 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.173 **FAIL** (level 0.1, unknown) | 0.827 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.147 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.843 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | rand | ~. | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.168 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | OptimalBlocks | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.075 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Atkinson | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | KK14 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.08 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.887 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.88 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | score | ~. | 50 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Blocking | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Rerandomization | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Atkinson | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Efron | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.178 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK14 | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.151 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | PocockSimon | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SPBR | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Urn | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~. | 50 | 10 | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 880/1000 |  | rate unknown: open a TODO to establish it |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.852 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | BinaryMatch | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK14 | SurvivalGLMMWeibullFrailtyNormalOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.129 (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | KK21stepwise | SurvivalKKStratCoxPHOneLik | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 1000/1000 |  |  |
| survival | KK21stepwise | SurvivalKKStratCoxPHOneLik | lik_ratio | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.132 **FAIL** (level 0.1, cap) | 0.893 (level 0.9, cap) | 999/1000 |  |  |
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

### Null bias (reported, not gated)

3066 estimand cells; flagged (z-test at 0.01 / 3038 and |bias| / SD > 0.1): **18**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the campaign's largest n, 50): **57** of 3066 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | null bias | bias / SD |
|---|---|---|---|---|---|---|
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0.119 | 0.31 |
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0.119 | 0.31 |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | ~1 | 50 | -0.107 | -0.23 |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 50 | 0.0584 | 0.19 |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | 0.115 | 0.18 |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | 0.115 | 0.18 |
| incidence | Efron | IncidGCompRiskRatio | ~1 | 50 | 0.0603 | 0.18 |
| incidence | PocockSimon | IncidGCompRiskRatio | ~1 | 50 | 0.056 | 0.18 |
| incidence | PocockSimon | IncidGCompRiskRatio | ~. | 50 | 0.0517 | 0.17 |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | ~1 | 50 | -0.115 | -0.17 |
| incidence | iBCRD | IncidGCompRiskRatio | ~1 | 50 | 0.0528 | 0.17 |
| incidence | Efron | IncidGCompRiskRatio | ~. | 50 | 0.0499 | 0.16 |
| incidence | KK21 | IncidGCompRiskRatio | ~1 | 50 | 0.0475 | 0.16 |
| incidence | KK21 | IncidKKGCompRiskRatio | ~1 | 50 | 0.0475 | 0.16 |
| incidence | Blocking | IncidGCompRiskRatio | ~. | 50 | 0.0461 | 0.15 |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~. | 52 | 0.0407 | 0.15 |
| incidence | KK21 | IncidGCompRiskRatio | ~. | 50 | 0.0427 | 0.15 |
| incidence | KK21 | IncidKKGCompRiskRatio | ~. | 50 | 0.0427 | 0.15 |
| incidence | Bernoulli@0.2 | IncidLogBinomial | ~1 | 50 | -0.0606 | -0.15 |
| incidence | BinaryMatch | IncidGCompRiskRatio | ~1 | 50 | 0.0431 | 0.14 |
| incidence | BinaryMatch | IncidKKGCompRiskRatio | ~1 | 50 | 0.0431 | 0.14 |
| incidence | Blocking | IncidGCompRiskRatio | ~1 | 50 | 0.0458 | 0.14 |
| incidence | iBCRD | IncidGCompRiskRatio | ~. | 50 | 0.0433 | 0.14 |
| incidence | BinaryMatch | IncidGCompRiskRatio | ~. | 50 | 0.0425 | 0.14 |
| incidence | BinaryMatch | IncidKKGCompRiskRatio | ~. | 50 | 0.0425 | 0.14 |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~1 | 52 | 0.0388 | 0.14 |
| incidence | Bernoulli | IncidGCompRiskRatio | ~. | 50 | 0.042 | 0.14 |
| incidence | iBCRD | IncidGCompRiskRatio | ~. | 50 | 0.0407 | 0.14 |
| incidence | iBCRD | IncidGCompRiskRatio | ~1 | 50 | 0.0427 | 0.14 |
| incidence | OptimalBlocks | IncidGCompRiskRatio | ~1 | 50 | 0.043 | 0.14 |
(30 shown of 57; all in `null_bias_summary.csv`.)

| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |
|---|---|---|---|---|---|---|---|---|---|
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.119 | 0.31 | 0.43 | 0.0% |
| survival | Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.119 | 0.31 | 0.43 | 0.0% |
| count | Bernoulli@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.107 | -0.23 | 0.57 | 0.0% |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0584 | 0.19 | 0.49 | 0.0% |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.115 | 0.18 | 0.47 | 1.6% |
| survival | Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.115 | 0.18 | 0.47 | 1.6% |
| incidence | Efron | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0603 | 0.18 | 0.5 | 0.0% |
| incidence | PocockSimon | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.056 | 0.18 | 0.48 | 0.0% |
| incidence | PocockSimon | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0517 | 0.17 | 0.48 | 0.0% |
| count | Bernoulli@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.115 | -0.17 | 0.55 | 0.0% |
| incidence | iBCRD | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0528 | 0.17 | 0.49 | 0.0% |
| incidence | Efron | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0499 | 0.16 | 0.49 | 0.0% |
| incidence | KK21 | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| incidence | KK21 | IncidKKGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| incidence | Blocking | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0461 | 0.15 | 0.49 | 0.0% |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~. | 52 | 1 | 0.0407 | 0.15 | 0.5 | 0.0% |
| incidence | KK21 | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0427 | 0.15 | 0.49 | 0.0% |
| incidence | KK21 | IncidKKGCompRiskRatio | ~. | 50 | 1 | 0.0427 | 0.15 | 0.49 | 0.0% |

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
(30 shown of 358; all in `nonnull_bias_summary.csv`.)

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

### Power (reported, not gated)

5050 power cells; see `power_summary.csv`, `design_comparison.csv` (paired tests between designs, when the campaign is complete) and the power figures.

