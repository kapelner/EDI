## EDI calibration study, campaign 2026-11-15-e36c7710

Progress: 12959805 of 16912000 replicates (76%) after wave 49; 13577 of 20648 cells complete, 7 abandoned.

39826 null cells and 36168 power cells have results; 93347 of the plan's 129978 tests (null size and coverage, coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate: Benjamini-Hochberg q < 0.05 over all 129978 tests of the plan on the screening replicates (a test enters with its p-value when its cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only "not flagged" is provisional) flags **2625** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at 0.01 / 129978, fixed in advance, so a confirmed failure is final when it is made.

Confirmation so far: 2089 confirmed failing, 289 pending, 0 could not be confirmed (counted as failing), 247 cleared. Failing null cells so far (provisional): **909**.

Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of 0.1 reached at n_eff = 50 (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n (`rate check`). Null cells by rule (size): cap 9284, finite 9884, mismatch 1320, rate 13299, rate_check 403, unknown 5636.

770 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Fixed:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.192 **FAIL** (level 0.1, cap) | 0.808 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | Fixed:Blocking@0.2 | ContinQuantileRegr | wald | ~. | 1000 | 200 | 0.667 (literature) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
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
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.1, cap) | 0.842 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.836 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.836 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.1, cap) | 0.831 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.184 **FAIL** (level 0.1, cap) | 0.816 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.199 **FAIL** (level 0.1, cap) | 0.801 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 0.812 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.161 **FAIL** (level 0.1, cap) | 0.839 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.144 **FAIL** (level 0.1, cap) | 0.856 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.849 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.1, cap) | 0.827 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.176 **FAIL** (level 0.1, cap) | 0.824 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.0625, rate) | 0.83 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.176 **FAIL** (level 0.0625, rate) | 0.824 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.0625, rate) | 0.84 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.156 **FAIL** (level 0.0625, rate) | 0.844 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.09 **FAIL** (level 0.0625, rate) | 0.91 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.09 **FAIL** (level 0.0625, rate) | 0.91 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.0625, rate) | 0.84 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.155 **FAIL** (level 0.0625, rate) | 0.845 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.103 **FAIL** (level 0.0625, rate) | 0.897 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.123 **FAIL** (level 0.0625, rate) | 0.877 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.14 **FAIL** (level 0.0625, rate) | 0.86 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.0625, rate) | 0.832 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.129 **FAIL** (level 0.0625, rate) | 0.871 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.0625, rate) | 0.841 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.177 **FAIL** (level 0.0625, rate) | 0.823 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.187 **FAIL** (level 0.0625, rate) | 0.813 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.177 **FAIL** (level 0.0625, rate) | 0.823 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.128 **FAIL** (level 0.0625, rate) | 0.872 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.0625, rate) | 0.892 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.112 **FAIL** (level 0.0625, rate) | 0.888 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.0625, rate) | 0.841 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.0625, rate) | 0.835 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.0625, rate) | 0.837 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.148 **FAIL** (level 0.0625, rate) | 0.852 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.0625, rate) | 0.815 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.05, rate check) | 0.829 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.05, rate check) | 0.841 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.135 **FAIL** (level 0.05, rate check) | 0.865 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.099 **FAIL** (level 0.05, rate check) | 0.901 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.099 **FAIL** (level 0.05, rate check) | 0.901 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.05, rate check) | 0.834 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.172 **FAIL** (level 0.05, rate check) | 0.828 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.089 **FAIL** (level 0.05, rate check) | 0.911 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.098 **FAIL** (level 0.05, rate check) | 0.902 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.114 **FAIL** (level 0.05, rate check) | 0.886 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.099 **FAIL** (level 0.05, rate check) | 0.901 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.05, rate check) | 0.83 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.05, rate check) | 0.84 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.05, rate check) | 0.892 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.05, rate check) | 0.815 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.05, rate check) | 0.835 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.177 **FAIL** (level 0.05, rate check) | 0.823 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.092 **FAIL** (level 0.05, rate check) | 0.908 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.087 **FAIL** (level 0.05, rate check) | 0.913 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.084 **FAIL** (level 0.05, rate check) | 0.916 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.05, rate check) | 0.831 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.05, rate check) | 0.854 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.153 **FAIL** (level 0.05, rate check) | 0.847 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.05, rate check) | 0.829 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.05, rate check) | 0.855 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.05, rate check) | 0.827 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.1, cap) | 0.836 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.182 **FAIL** (level 0.1, cap) | 0.818 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.19 **FAIL** (level 0.1, cap) | 0.81 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.1, cap) | 0.834 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.839 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.1, cap) | 0.815 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.154 **FAIL** (level 0.1, cap) | 0.846 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.1, cap) | 0.84 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.1, cap) | 0.831 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.0625, rate) | 0.83 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.0625, rate) | 0.829 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.0625, rate) | 0.841 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.153 **FAIL** (level 0.0625, rate) | 0.847 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.0625, rate) | 0.84 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.092 **FAIL** (level 0.0625, rate) | 0.908 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.0625, rate) | 0.9 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.123 **FAIL** (level 0.0625, rate) | 0.877 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.138 **FAIL** (level 0.0625, rate) | 0.862 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.0625, rate) | 0.834 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.129 **FAIL** (level 0.0625, rate) | 0.871 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.0625, rate) | 0.841 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.0625, rate) | 0.821 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.187 **FAIL** (level 0.0625, rate) | 0.813 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.0625, rate) | 0.827 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.127 **FAIL** (level 0.0625, rate) | 0.873 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.0625, rate) | 0.892 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.11 **FAIL** (level 0.0625, rate) | 0.89 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.0625, rate) | 0.835 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.0625, rate) | 0.837 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.143 **FAIL** (level 0.0625, rate) | 0.857 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.184 **FAIL** (level 0.0625, rate) | 0.816 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.05, rate check) | 0.829 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.161 **FAIL** (level 0.05, rate check) | 0.839 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.135 **FAIL** (level 0.05, rate check) | 0.865 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.166 **FAIL** (level 0.05, rate check) | 0.834 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.05, rate check) | 0.829 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.089 **FAIL** (level 0.05, rate check) | 0.911 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.097 **FAIL** (level 0.05, rate check) | 0.903 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.114 **FAIL** (level 0.05, rate check) | 0.886 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.099 **FAIL** (level 0.05, rate check) | 0.901 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.05, rate check) | 0.83 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.164 **FAIL** (level 0.05, rate check) | 0.836 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.05, rate check) | 0.892 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.185 **FAIL** (level 0.05, rate check) | 0.815 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.05, rate check) | 0.835 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.177 **FAIL** (level 0.05, rate check) | 0.823 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.092 **FAIL** (level 0.05, rate check) | 0.908 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.086 **FAIL** (level 0.05, rate check) | 0.914 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.05, rate check) | 0.831 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.05, rate check) | 0.854 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.152 **FAIL** (level 0.05, rate check) | 0.848 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.05, rate check) | 0.83 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.05, rate check) | 0.855 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.05, rate check) | 0.827 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.1, cap) | 0.837 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.153 **FAIL** (level 0.1, cap) | 0.848 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.156 **FAIL** (level 0.1, cap) | 0.844 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.154 **FAIL** (level 0.1, cap) | 0.846 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.1, cap) | 0.838 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.161 **FAIL** (level 0.1, cap) | 0.839 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.1, cap) | 0.821 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.181 **FAIL** (level 0.1, cap) | 0.819 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.154 **FAIL** (level 0.1, cap) | 0.846 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.1, cap) | 0.835 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.183 **FAIL** (level 0.1, cap) | 0.817 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.152 **FAIL** (level 0.1, cap) | 0.848 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.1, cap) | 0.858 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.1, cap) | 0.832 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.167 **FAIL** (level 0.1, cap) | 0.833 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.151 **FAIL** (level 0.1, cap) | 0.849 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.1, cap) | 0.843 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.17 **FAIL** (level 0.0625, rate) | 0.83 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.172 **FAIL** (level 0.0625, rate) | 0.828 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.0625, rate) | 0.841 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.151 **FAIL** (level 0.0625, rate) | 0.849 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.091 **FAIL** (level 0.0625, rate) | 0.909 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.906 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.091 **FAIL** (level 0.0625, rate) | 0.909 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.16 **FAIL** (level 0.0625, rate) | 0.84 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.091 **FAIL** (level 0.0625, rate) | 0.909 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.103 **FAIL** (level 0.0625, rate) | 0.897 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.121 **FAIL** (level 0.0625, rate) | 0.879 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.14 **FAIL** (level 0.0625, rate) | 0.86 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.161 **FAIL** (level 0.0625, rate) | 0.839 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.13 **FAIL** (level 0.0625, rate) | 0.87 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.0625, rate) | 0.821 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.187 **FAIL** (level 0.0625, rate) | 0.813 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.174 **FAIL** (level 0.0625, rate) | 0.826 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.126 **FAIL** (level 0.0625, rate) | 0.874 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.0625, rate) | 0.892 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.109 **FAIL** (level 0.0625, rate) | 0.891 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.158 **FAIL** (level 0.0625, rate) | 0.842 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.157 **FAIL** (level 0.0625, rate) | 0.843 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.168 **FAIL** (level 0.0625, rate) | 0.832 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.162 **FAIL** (level 0.0625, rate) | 0.838 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.143 **FAIL** (level 0.0625, rate) | 0.857 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.184 **FAIL** (level 0.0625, rate) | 0.816 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.172 **FAIL** (level 0.05, rate check) | 0.828 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.161 **FAIL** (level 0.05, rate check) | 0.839 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.135 **FAIL** (level 0.05, rate check) | 0.865 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.101 **FAIL** (level 0.05, rate check) | 0.899 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.1 **FAIL** (level 0.05, rate check) | 0.9 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.101 **FAIL** (level 0.05, rate check) | 0.899 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.05, rate check) | 0.835 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.05, rate check) | 0.827 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.089 **FAIL** (level 0.05, rate check) | 0.911 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.093 **FAIL** (level 0.05, rate check) | 0.907 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.114 **FAIL** (level 0.05, rate check) | 0.886 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.098 **FAIL** (level 0.05, rate check) | 0.902 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.05, rate check) | 0.831 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.163 **FAIL** (level 0.05, rate check) | 0.837 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.108 **FAIL** (level 0.05, rate check) | 0.892 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.18 **FAIL** (level 0.05, rate check) | 0.82 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.165 **FAIL** (level 0.05, rate check) | 0.835 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.179 **FAIL** (level 0.05, rate check) | 0.821 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.174 **FAIL** (level 0.05, rate check) | 0.826 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.092 **FAIL** (level 0.05, rate check) | 0.908 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.086 **FAIL** (level 0.05, rate check) | 0.914 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.169 **FAIL** (level 0.05, rate check) | 0.831 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.05, rate check) | 0.855 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.152 **FAIL** (level 0.05, rate check) | 0.848 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.171 **FAIL** (level 0.05, rate check) | 0.829 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.144 **FAIL** (level 0.05, rate check) | 0.856 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.173 **FAIL** (level 0.05, rate check) | 0.827 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | gradient | ~1 | 200 | 200 | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | gradient | ~1 | 200 | 200 | 1 (assumed_default) | 0.106 **FAIL** (level 0.0625, rate) | 0.894 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountPoisson | gradient | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountPoisson | gradient | ~1 | 1000 | 200 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | gradient | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.106 **FAIL** (level 0.05, rate check) | 0.894 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountPoisson | gradient | ~1 | 1000 | 200 | 1 (assumed_default) | 0.078 **FAIL** (level 0.05, rate check) | 0.922 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | gradient | ~1 | 1000 | 200 | 1 (assumed_default) | 0.095 **FAIL** (level 0.05, rate check) | 0.905 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | gradient | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | lik_ratio | ~1 | 200 | 200 | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | lik_ratio | ~1 | 200 | 200 | 1 (assumed_default) | 0.106 **FAIL** (level 0.0625, rate) | 0.894 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountPoisson | lik_ratio | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountPoisson | lik_ratio | ~1 | 1000 | 200 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | lik_ratio | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.106 **FAIL** (level 0.05, rate check) | 0.894 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountPoisson | lik_ratio | ~1 | 1000 | 200 | 1 (assumed_default) | 0.078 **FAIL** (level 0.05, rate check) | 0.922 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | lik_ratio | ~1 | 1000 | 200 | 1 (assumed_default) | 0.095 **FAIL** (level 0.05, rate check) | 0.905 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | lik_ratio | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | score | ~1 | 200 | 200 | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | score | ~1 | 200 | 200 | 1 (assumed_default) | 0.106 **FAIL** (level 0.0625, rate) | 0.894 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountPoisson | score | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountPoisson | score | ~1 | 1000 | 200 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | score | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.106 **FAIL** (level 0.05, rate check) | 0.894 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountPoisson | score | ~1 | 1000 | 200 | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | score | ~1 | 1000 | 200 | 1 (assumed_default) | 0.095 **FAIL** (level 0.05, rate check) | 0.905 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | score | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | wald | ~1 | 200 | 200 | 1 (assumed_default) | 0.093 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | wald | ~1 | 200 | 200 | 1 (assumed_default) | 0.105 **FAIL** (level 0.0625, rate) | 0.895 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountPoisson | wald | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountPoisson | wald | ~1 | 1000 | 200 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | wald | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.106 **FAIL** (level 0.05, rate check) | 0.894 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountPoisson | wald | ~1 | 1000 | 200 | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | wald | ~1 | 1000 | 200 | 1 (assumed_default) | 0.095 **FAIL** (level 0.05, rate check) | 0.905 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountPoisson | wald | ~1 | 1000 | 1000 | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.865 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.852 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.852 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.854 (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.142 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.869 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.147 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | gradient | ~. | 52 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.872 (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.881 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.879 (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.875 (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.876 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.151 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.866 (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.874 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.886 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.86 (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.86 (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.884 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.885 (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.859 (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.878 (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.095 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 968/1000 |  |  |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0848 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Fixed:Blocking | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0948 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 960/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0998 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 962/1000 |  |  |
| count | Fixed:Greedy | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.098 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 969/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0916 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.098 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 969/1000 |  |  |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0912 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.102 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 962/1000 |  |  |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0944 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 943/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0832 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 961/1000 |  |  |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0972 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 967/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0764 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 968/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0962 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 956/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.084 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 964/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0933 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 965/1000 |  |  |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.102 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 962/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0814 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 970/1000 |  |  |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0865 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 959/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0976 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 973/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.109 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 964/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.101 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 966/1000 |  |  |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0924 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 963/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0945 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 963/1000 |  |  |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | rand | ~. | 50 | 50 | Inf (theory) | 0.0784 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 957/1000 |  |  |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~. | 52 | 50 | Inf (theory) | 0.086 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 977/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | rand | ~. | 200 | 200 | Inf (theory) | 0.0731 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 998/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.0791 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 999/1000 |  |  |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~1 | 52 | 50 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.088 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.074 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.08 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.094 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.082 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.095 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.089 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.087 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.1 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.075 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.081 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.088 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.088 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.077 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.106 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.094 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.102 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.09 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.09 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.083 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.096 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.092 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.0901 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 999/1000 |  |  |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.08 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.097 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.105 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.081 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.084 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.089 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.077 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.083 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.09 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.094 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.082 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.077 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.097 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | rand | ~1 | 1000 | 1000 | Inf (theory) | 0.093 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.221 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.216 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.212 **FAIL** (level 0.1, unknown) | 0.8 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.23 **FAIL** (level 0.1, unknown) | 0.782 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.206 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.23 **FAIL** (level 0.1, unknown) | 0.782 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.202 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.197 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.208 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.204 **FAIL** (level 0.1, unknown) | 0.804 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.212 **FAIL** (level 0.1, unknown) | 0.797 **FAIL** (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.197 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.224 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.198 **FAIL** (level 0.1, unknown) | 0.819 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.229 **FAIL** (level 0.1, unknown) | 0.787 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.184 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.22 **FAIL** (level 0.1, unknown) | 0.792 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.207 **FAIL** (level 0.1, unknown) | 0.809 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.191 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.205 **FAIL** (level 0.1, unknown) | 0.801 **FAIL** (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.19 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.196 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.213 **FAIL** (level 0.1, unknown) | 0.798 **FAIL** (level 0.9, unknown) | 975/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.183 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 973/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.21 **FAIL** (level 0.1, unknown) | 0.799 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.227 **FAIL** (level 0.1, unknown) | 0.806 **FAIL** (level 0.9, unknown) | 970/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | 0.198 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 963/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | 0.186 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | score | ~. | 52 | 50 | unknown | 0.199 **FAIL** (level 0.1, unknown) | 0.817 **FAIL** (level 0.9, unknown) | 977/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.125 (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.131 **FAIL** (level 0.1, unknown) | 0.871 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.127 (level 0.1, unknown) | 0.869 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.13 (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.179 **FAIL** (level 0.1, unknown) | 0.821 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 953/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.191 **FAIL** (level 0.1, unknown) | 0.809 **FAIL** (level 0.9, unknown) | 961/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.195 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.187 **FAIL** (level 0.1, unknown) | 0.813 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.195 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 962/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 958/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 953/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.184 **FAIL** (level 0.1, unknown) | 0.816 **FAIL** (level 0.9, unknown) | 953/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.193 **FAIL** (level 0.1, unknown) | 0.807 **FAIL** (level 0.9, unknown) | 940/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 958/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.195 **FAIL** (level 0.1, unknown) | 0.805 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.189 **FAIL** (level 0.1, unknown) | 0.811 **FAIL** (level 0.9, unknown) | 952/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.185 **FAIL** (level 0.1, unknown) | 0.815 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 948/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.175 **FAIL** (level 0.1, unknown) | 0.825 **FAIL** (level 0.9, unknown) | 966/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 959/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.188 **FAIL** (level 0.1, unknown) | 0.812 **FAIL** (level 0.9, unknown) | 967/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 960/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.176 **FAIL** (level 0.1, unknown) | 0.824 **FAIL** (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.174 **FAIL** (level 0.1, unknown) | 0.826 **FAIL** (level 0.9, unknown) | 956/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 954/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | 0.167 **FAIL** (level 0.1, unknown) | 0.833 **FAIL** (level 0.9, unknown) | 951/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | wald | ~. | 52 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 968/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.173 **FAIL** (level 0.1, unknown) | 0.827 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.866 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.182 **FAIL** (level 0.1, unknown) | 0.818 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.843 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | 0.168 **FAIL** (level 0.1, unknown) | 0.832 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.86 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.172 **FAIL** (level 0.1, unknown) | 0.828 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.172 **FAIL** (level 0.1, unknown) | 0.828 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.171 **FAIL** (level 0.1, unknown) | 0.829 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.173 **FAIL** (level 0.0625, unknown) | 0.827 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.169 **FAIL** (level 0.0525, unknown) | 0.831 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.091 **FAIL** (level 0.0525, unknown) | 0.909 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.154 **FAIL** (level 0.0525, unknown) | 0.846 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.152 **FAIL** (level 0.0625, unknown) | 0.848 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.111 **FAIL** (level 0.0525, unknown) | 0.889 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.116 **FAIL** (level 0.0625, unknown) | 0.884 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.111 **FAIL** (level 0.0525, unknown) | 0.889 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.116 **FAIL** (level 0.0625, unknown) | 0.884 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.176 **FAIL** (level 0.0625, unknown) | 0.824 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.163 **FAIL** (level 0.0525, unknown) | 0.837 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.113 **FAIL** (level 0.0525, unknown) | 0.887 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.125 **FAIL** (level 0.0625, unknown) | 0.875 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.121 **FAIL** (level 0.0525, unknown) | 0.879 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.132 **FAIL** (level 0.0625, unknown) | 0.868 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.151 **FAIL** (level 0.0625, unknown) | 0.849 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.116 **FAIL** (level 0.0525, unknown) | 0.884 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.137 **FAIL** (level 0.0525, unknown) | 0.863 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.158 **FAIL** (level 0.0625, unknown) | 0.842 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.147 **FAIL** (level 0.0525, unknown) | 0.853 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.159 **FAIL** (level 0.0525, unknown) | 0.841 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.157 **FAIL** (level 0.0625, unknown) | 0.843 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.11 **FAIL** (level 0.0525, unknown) | 0.89 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.112 **FAIL** (level 0.0525, unknown) | 0.888 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.108 **FAIL** (level 0.0525, unknown) | 0.892 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.138 **FAIL** (level 0.0525, unknown) | 0.862 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.155 **FAIL** (level 0.0525, unknown) | 0.845 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.151 **FAIL** (level 0.0625, unknown) | 0.849 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 200 | unknown | 0.152 **FAIL** (level 0.0625, unknown) | 0.848 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.157 **FAIL** (level 0.0525, unknown) | 0.843 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.15 **FAIL** (level 0.1, unknown) | 0.85 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.855 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.18 **FAIL** (level 0.1, unknown) | 0.82 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.161 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.173 **FAIL** (level 0.1, unknown) | 0.827 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.172 **FAIL** (level 0.1, unknown) | 0.828 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.15 **FAIL** (level 0.1, unknown) | 0.85 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.147 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.171 **FAIL** (level 0.0625, unknown) | 0.829 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.169 **FAIL** (level 0.0525, unknown) | 0.831 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.091 **FAIL** (level 0.0525, unknown) | 0.909 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.153 **FAIL** (level 0.0525, unknown) | 0.847 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.152 **FAIL** (level 0.0625, unknown) | 0.848 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.111 **FAIL** (level 0.0525, unknown) | 0.889 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.117 **FAIL** (level 0.0625, unknown) | 0.883 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.111 **FAIL** (level 0.0525, unknown) | 0.889 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.117 **FAIL** (level 0.0625, unknown) | 0.883 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.176 **FAIL** (level 0.0625, unknown) | 0.824 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.163 **FAIL** (level 0.0525, unknown) | 0.837 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.113 **FAIL** (level 0.0525, unknown) | 0.887 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.125 **FAIL** (level 0.0625, unknown) | 0.875 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.121 **FAIL** (level 0.0525, unknown) | 0.879 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.131 **FAIL** (level 0.0625, unknown) | 0.869 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.154 **FAIL** (level 0.0625, unknown) | 0.846 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.116 **FAIL** (level 0.0525, unknown) | 0.884 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.137 **FAIL** (level 0.0525, unknown) | 0.863 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.157 **FAIL** (level 0.0625, unknown) | 0.843 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.147 **FAIL** (level 0.0525, unknown) | 0.853 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.159 **FAIL** (level 0.0525, unknown) | 0.841 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.156 **FAIL** (level 0.0625, unknown) | 0.844 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.11 **FAIL** (level 0.0525, unknown) | 0.89 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.112 **FAIL** (level 0.0525, unknown) | 0.888 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.108 **FAIL** (level 0.0525, unknown) | 0.892 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.138 **FAIL** (level 0.0525, unknown) | 0.862 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.155 **FAIL** (level 0.0525, unknown) | 0.845 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.15 **FAIL** (level 0.0625, unknown) | 0.85 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 200 | unknown | 0.151 **FAIL** (level 0.0625, unknown) | 0.849 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.157 **FAIL** (level 0.0525, unknown) | 0.843 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.111 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.092 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.079 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.099 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.082 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.103 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.086 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.088 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | rand | ~. | 200 | 200 | Inf (theory) | 0.091 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.168 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.166 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.185 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.185 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.178 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.146 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.178 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.177 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.173 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.169 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | 50 | Inf (theory) | 0.177 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.169 **FAIL** (level 0.1, unknown) | 0.831 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.163 **FAIL** (level 0.1, unknown) | 0.837 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.157 **FAIL** (level 0.1, unknown) | 0.843 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.162 **FAIL** (level 0.1, unknown) | 0.838 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.178 **FAIL** (level 0.1, unknown) | 0.822 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.15 **FAIL** (level 0.1, unknown) | 0.85 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.151 **FAIL** (level 0.1, unknown) | 0.849 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.141 **FAIL** (level 0.1, unknown) | 0.859 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.842 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.836 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.165 **FAIL** (level 0.1, unknown) | 0.835 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.166 **FAIL** (level 0.1, unknown) | 0.834 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.846 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.848 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.172 **FAIL** (level 0.1, unknown) | 0.828 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.847 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.15 **FAIL** (level 0.1, unknown) | 0.85 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.17 **FAIL** (level 0.1, unknown) | 0.83 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.155 **FAIL** (level 0.1, unknown) | 0.845 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.16 **FAIL** (level 0.1, unknown) | 0.84 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.139 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | 0.156 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.147 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.168 **FAIL** (level 0.0625, unknown) | 0.832 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.169 **FAIL** (level 0.0525, unknown) | 0.831 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.091 **FAIL** (level 0.0525, unknown) | 0.909 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.153 **FAIL** (level 0.0525, unknown) | 0.847 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.152 **FAIL** (level 0.0625, unknown) | 0.848 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.11 **FAIL** (level 0.0525, unknown) | 0.89 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.12 **FAIL** (level 0.0625, unknown) | 0.88 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.11 **FAIL** (level 0.0525, unknown) | 0.89 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.12 **FAIL** (level 0.0625, unknown) | 0.88 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.176 **FAIL** (level 0.0625, unknown) | 0.824 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.163 **FAIL** (level 0.0525, unknown) | 0.837 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.112 **FAIL** (level 0.0525, unknown) | 0.888 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.123 **FAIL** (level 0.0625, unknown) | 0.877 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.121 **FAIL** (level 0.0525, unknown) | 0.879 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.132 **FAIL** (level 0.0625, unknown) | 0.868 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.153 **FAIL** (level 0.0625, unknown) | 0.847 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.116 **FAIL** (level 0.0525, unknown) | 0.884 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.137 **FAIL** (level 0.0525, unknown) | 0.863 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.156 **FAIL** (level 0.0625, unknown) | 0.844 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.147 **FAIL** (level 0.0525, unknown) | 0.853 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.158 **FAIL** (level 0.0525, unknown) | 0.842 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.158 **FAIL** (level 0.0625, unknown) | 0.842 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.11 **FAIL** (level 0.0525, unknown) | 0.89 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.112 **FAIL** (level 0.0525, unknown) | 0.888 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.108 **FAIL** (level 0.0525, unknown) | 0.892 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.138 **FAIL** (level 0.0525, unknown) | 0.862 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.155 **FAIL** (level 0.0525, unknown) | 0.845 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.152 **FAIL** (level 0.0625, unknown) | 0.848 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | 200 | unknown | 0.149 **FAIL** (level 0.0625, unknown) | 0.851 **FAIL** (level 0.938, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.156 **FAIL** (level 0.0525, unknown) | 0.844 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 1000 | 1000 | unknown | 0.168 **FAIL** (level 0.0525, unknown) | 0.832 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~. | 50 | 10 | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 880/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | wald | ~. | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 887/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | 0.132 **FAIL** (level 0.1, unknown) | 0.868 **FAIL** (level 0.9, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.855 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| proportion | SeqOneByOne:KK14 | PropKKGLMM | rand | ~1 | 1000 | 500 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Greedy | SurvivalCoxPHRegr | rand | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal | SurvivalCoxPHRegr | rand | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Greedy@0.2 | SurvivalDepCensTransformRegr | score | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalDepCensTransformRegr | score | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.927 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | gradient | ~1 | 1000 | 1000 (proxy) | unknown | 0.08 **FAIL** (level 0.0525, unknown) | 0.92 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | lik_ratio | ~1 | 1000 | 1000 (proxy) | unknown | 0.08 **FAIL** (level 0.0525, unknown) | 0.92 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.852 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.858 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | Fixed:BinaryMatch | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.164 **FAIL** (level 0.1, unknown) | 0.839 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 50 | 50 (proxy) | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.851 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 1000 | 1000 (proxy) | unknown | 0.083 **FAIL** (level 0.0525, unknown) | 0.917 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | score | ~1 | 1000 | 1000 (proxy) | unknown | 0.079 **FAIL** (level 0.0525, unknown) | 0.921 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyLoggammaOneLik | wald | ~1 | 1000 | 1000 (proxy) | unknown | 0.081 **FAIL** (level 0.0525, unknown) | 0.919 **FAIL** (level 0.948, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalKKStratCoxPHOneLik | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | rand | ~. | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | rand | ~1 | 50 | 50 | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | rand | ~1 | 50 | 50 (proxy) | Inf (theory) | 0.073 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.904 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD@0.2 | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.074 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:Bernoulli | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.073 **FAIL** (level 0.05, rate check) | 0.926 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.077 **FAIL** (level 0.05, rate check) | 0.923 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
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

### Null bias (reported, not gated)

13310 estimand cells; flagged (z-test at 0.01 / 13043 and |bias| / SD > 0.1): **102**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the campaign's largest n, 1000): **44** of 4430 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | null bias | bias / SD |
|---|---|---|---|---|---|---|
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0269 | 0.18 |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0269 | 0.18 |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0253 | 0.17 |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0253 | 0.17 |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0232 | 0.16 |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0232 | 0.16 |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0204 | 0.15 |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0204 | 0.15 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0193 | 0.15 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0193 | 0.15 |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0205 | 0.15 |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0205 | 0.15 |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0213 | 0.14 |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0213 | 0.14 |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0199 | 0.14 |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0199 | 0.14 |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0195 | 0.14 |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0195 | 0.14 |
| ordinal | SeqOneByOne:KK21stepwise | OrdinalKKCLMM | ~1 | 1000 | 0.0152 | 0.13 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0179 | 0.12 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0179 | 0.12 |
| ordinal | SeqOneByOne:KK21stepwise | OrdinalKKCLMMCauchit | ~1 | 1000 | 0.0152 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | PropQuantileRegr | ~1 | 1000 | 0.0137 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | PropFractionalLogit | ~1 | 1000 | 0.00882 | 0.12 |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0152 | 0.12 |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0152 | 0.12 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0152 | 0.12 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0152 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleAverageDiff | ~. | 1000 | 0.00201 | 0.11 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleAverageDiff | ~1 | 1000 | 0.00201 | 0.11 |
(30 shown of 44; all in `null_bias_summary.csv`.)

| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |
|---|---|---|---|---|---|---|---|---|---|
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0 | 0.0269 | 0.18 | 0.46 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0 | 0.0269 | 0.18 | 0.46 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0 | 0.0253 | 0.17 | 0.45 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0 | 0.0253 | 0.17 | 0.45 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0 | 0.0232 | 0.16 | 0.46 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0 | 0.0232 | 0.16 | 0.46 | 0.0% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.132 | 0.34 | 0.42 | 0.0% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.132 | 0.34 | 0.42 | 0.0% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.128 | 0.34 | 0.41 | 0.0% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.128 | 0.34 | 0.41 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.129 | 0.33 | 0.42 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.129 | 0.33 | 0.42 | 0.0% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.126 | 0.32 | 0.42 | 0.0% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.126 | 0.32 | 0.42 | 0.0% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.123 | 0.32 | 0.41 | 0.0% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.123 | 0.32 | 0.41 | 0.0% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.12 | 0.32 | 0.42 | 0.0% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.12 | 0.32 | 0.42 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.119 | 0.31 | 0.43 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.119 | 0.31 | 0.43 | 0.0% |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.0965 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.0965 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.0972 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.0972 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.0972 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.0972 | 0.3 | 0.43 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.121 | 0.29 | 0.45 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.121 | 0.29 | 0.45 | 0.0% |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | 0 | 0.1 | 0.27 | 0.45 | 0.0% |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | 0 | 0.1 | 0.27 | 0.45 | 0.0% |
| continuous | Fixed:Optimal@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0991 | 0.25 | 0.33 | 0.0% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0634 | 0.25 | 0.45 | 0.0% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0634 | 0.25 | 0.45 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0595 | 0.23 | 0.45 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0595 | 0.23 | 0.45 | 0.0% |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.107 | -0.23 | 0.57 | 0.0% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.053 | 0.22 | 0.45 | 0.0% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.053 | 0.22 | 0.45 | 0.0% |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.053 | 0.22 | 0.45 | 0.0% |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.053 | 0.22 | 0.45 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0567 | 0.22 | 0.45 | 0.0% |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0567 | 0.22 | 0.45 | 0.0% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.133 | 0.19 | 0.49 | 1.1% |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.133 | 0.19 | 0.49 | 1.1% |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0502 | 0.19 | 0.46 | 0.0% |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0502 | 0.19 | 0.46 | 0.0% |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.131 | -0.19 | 0.56 | 0.0% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0492 | 0.19 | 0.45 | 0.0% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0492 | 0.19 | 0.45 | 0.0% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.128 | 0.19 | 0.47 | 0.4% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.128 | 0.19 | 0.47 | 0.4% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.05 | 0.19 | 0.45 | 0.0% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.05 | 0.19 | 0.45 | 0.0% |
| incidence | SeqOneByOne:Bernoulli | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0584 | 0.19 | 0.49 | 0.0% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0486 | 0.19 | 0.46 | 0.0% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0486 | 0.19 | 0.46 | 0.0% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0444 | 0.19 | 0.46 | 0.0% |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0444 | 0.19 | 0.46 | 0.0% |
| continuous | SeqOneByOne:iBCRD@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.087 | 0.18 | 0.32 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.115 | 0.18 | 0.47 | 1.6% |
| survival | Fixed:Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.115 | 0.18 | 0.47 | 1.6% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.116 | 0.18 | 0.47 | 0.6% |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.116 | 0.18 | 0.47 | 0.6% |
| count | Fixed:Optimal@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.0758 | -0.18 | 0.52 | 0.0% |
| incidence | SeqOneByOne:Efron | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0603 | 0.18 | 0.5 | 0.0% |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.0848 | -0.18 | 0.54 | 0.0% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.114 | 0.18 | 0.5 | 0.4% |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.114 | 0.18 | 0.5 | 0.4% |
| incidence | SeqOneByOne:PocockSimon | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.056 | 0.18 | 0.48 | 0.0% |
| count | Fixed:Optimal@0.2 | CountHurdleNegBin | ~1 | 50 | 0 | -0.0582 | -0.17 | 0.55 | 0.1% |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.079 | -0.17 | 0.53 | 0.0% |
| incidence | Fixed:Blocking@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0727 | -0.17 | 0.52 | 0.5% |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.117 | -0.17 | 0.56 | 0.1% |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.0787 | -0.17 | 0.55 | 0.0% |
| survival | Fixed:Blocking@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.119 | 0.17 | 0.49 | 1.1% |
| survival | Fixed:Blocking@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.119 | 0.17 | 0.49 | 1.1% |
| incidence | SeqOneByOne:PocockSimon | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0517 | 0.17 | 0.48 | 0.0% |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.0815 | -0.17 | 0.55 | 0.0% |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | ~1 | 50 | 0 | -0.0503 | -0.17 | 0.55 | 0.0% |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.115 | -0.17 | 0.55 | 0.0% |
| continuous | Fixed:GreedyDOptimal@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0676 | 0.17 | 0.36 | 0.0% |
| continuous | Fixed:Greedy@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0676 | 0.17 | 0.36 | 0.0% |
| incidence | SeqOneByOne:iBCRD | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0528 | 0.17 | 0.49 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | 0 | 0.0417 | 0.17 | 0.47 | 0.0% |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | 0 | 0.0417 | 0.17 | 0.47 | 0.0% |
| count | Fixed:Greedy@0.2 | CountHurdleNegBin | ~1 | 50 | 0 | -0.0555 | -0.17 | 0.54 | 0.1% |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdleNegBin | ~1 | 50 | 0 | -0.0555 | -0.17 | 0.54 | 0.1% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.105 | 0.17 | 0.48 | 1.5% |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.105 | 0.17 | 0.48 | 1.5% |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | ~1 | 50 | 0 | -0.0484 | -0.17 | 0.54 | 0.0% |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | ~1 | 50 | 0 | -0.0484 | -0.17 | 0.54 | 0.0% |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.0995 | -0.16 | 0.56 | 0.0% |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdleNegBin | ~1 | 50 | 0 | -0.0669 | -0.16 | 0.54 | 0.1% |
| incidence | SeqOneByOne:Efron | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0499 | 0.16 | 0.49 | 0.0% |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | ~1 | 50 | 0 | -0.0586 | -0.16 | 0.54 | 0.0% |
| continuous | Fixed:Rerandomization@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0797 | 0.16 | 0.36 | 0.0% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.0984 | 0.16 | 0.5 | 1.2% |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.0984 | 0.16 | 0.5 | 1.2% |
| survival | Fixed:Greedy@0.2 | SurvivalKMDiff | ~. | 50 | 0 | 0.0984 | 0.16 | 0.5 | 1.2% |
| survival | Fixed:Greedy@0.2 | SurvivalKMDiff | ~1 | 50 | 0 | 0.0984 | 0.16 | 0.5 | 1.2% |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0502 | 0.16 | 0.48 | 0.0% |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | ~1 | 50 | 0 | -0.0973 | -0.16 | 0.54 | 0.0% |

### Coverage at beta_T != 0 (gated)

36168 power cells, 25518 with a true estimand value (calibrate_study_truths.R; none for classes that apply only to matched designs, or whose large-sample fits failed); 25518 with enough results tested. Failing cells: **745**.

| response | design | class | procedure | formula | n | n_eff | order (basis) | effect | coverage | finite | note |
|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Fixed:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.9, cap) | 500/500 |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.796 **FAIL** (level 0.9, cap) | 500/500 |  |
| continuous | Fixed:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | power50 | 0.8 **FAIL** (level 0.9, cap) | 500/500 |  |
| continuous | Fixed:Greedy@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | Fixed:GreedyDOptimal@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | Fixed:iBCRD@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power20 | 0.902 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | SeqOneByOne:iBCRD@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | Fixed:Greedy@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power50 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | Fixed:GreedyDOptimal@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power50 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | Fixed:iBCRD@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power50 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power50 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| continuous | SeqOneByOne:iBCRD@0.2 | ContinQuantileRegr | wald | ~. | 200 | 40 | 0.667 (literature) | power50 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidCMH | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.768 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidCMH | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.9 **FAIL** (level 0.95, rate check) | 500/500 |  |
| incidence | Fixed:Greedy@0.2 | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.524 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.572 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.53 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.578 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | gradient | ~. | 50 | 50 (proxy) | unknown | power50 | 0.624 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | gradient | ~1 | 50 | 50 (proxy) | unknown | power50 | 0.618 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | lik_ratio | ~. | 50 | 50 (proxy) | unknown | power50 | 0.568 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | lik_ratio | ~1 | 50 | 50 (proxy) | unknown | power50 | 0.59 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | power50 | 0.493 **FAIL** (level 0.9, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.86 **FAIL** (level 0.938, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.889 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Greedy@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.885 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.885 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Optimal@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.872 **FAIL** (level 0.938, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:OptimalBlocks@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.89 **FAIL** (level 0.938, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Rerandomization@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.86 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.87 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:SPBR@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power20 | 0.882 **FAIL** (level 0.938, unknown) | 490/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.889 **FAIL** (level 0.938, unknown) | 495/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Blocking@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.895 **FAIL** (level 0.938, unknown) | 496/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Greedy@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.89 **FAIL** (level 0.938, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.89 **FAIL** (level 0.938, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:iBCRD@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.886 **FAIL** (level 0.938, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Optimal@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.889 **FAIL** (level 0.938, unknown) | 496/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:OptimalBlocks@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.892 **FAIL** (level 0.938, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| incidence | Fixed:Rerandomization@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.889 **FAIL** (level 0.938, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.875 **FAIL** (level 0.938, unknown) | 495/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidLogBinomial | score | ~. | 200 | 200 (proxy) | unknown | power50 | 0.864 **FAIL** (level 0.938, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | score | ~1 | 50 | 50 (proxy) | unknown | power50 | 0.538 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | wald | ~. | 50 | 50 (proxy) | unknown | power50 | 0.537 **FAIL** (level 0.9, unknown) | 231/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | wald | ~1 | 50 | 50 (proxy) | unknown | power50 | 0.578 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| incidence | SeqOneByOne:Urn | IncidLogRegr | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.632 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | Fixed:Greedy@0.2 | IncidLogRegr | gradient | ~. | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidLogRegr | gradient | ~. | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.56 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | lik_ratio | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.616 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.552 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | score | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.588 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.54 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.618 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidLogRegr | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.55 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.554 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.554 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidModifiedPoisson | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.566 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.53 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.53 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.606 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.554 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | lik_ratio | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.602 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.554 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | score | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.592 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.548 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.606 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.552 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.538 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.572 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidWald | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.572 **FAIL** (level 0.9, cap) | 500/500 |  |
| incidence | SeqOneByOne:Urn | IncidWald | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.572 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.896 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.762 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:BinaryMatch | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.752 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Greedy | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.87 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.87 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.754 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Optimal | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.768 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.822 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.78 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.786 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.774 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.862 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.774 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.766 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.78 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power50 | 0.842 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power50 | 0.764 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.896 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.762 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:BinaryMatch | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.752 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Greedy | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.87 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.87 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.754 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Optimal | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.768 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.822 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.78 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.786 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.774 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.862 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.774 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.766 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.78 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power50 | 0.842 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power50 | 0.764 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.806 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.812 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.814 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.78 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.802 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.812 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.81 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.808 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.826 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.82 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.82 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.808 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.808 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.782 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.804 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.812 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.822 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.806 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.826 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.836 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.902 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.882 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.862 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.898 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.83 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.816 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.844 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.84 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.898 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.898 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.846 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.884 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.8 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.9 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.864 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.826 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.82 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.814 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.788 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.806 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.822 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.808 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.826 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.81 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.788 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.814 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK21 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.826 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.826 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.84 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.842 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.862 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.898 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.83 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.816 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.846 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.844 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.902 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.902 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.842 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.884 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.804 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.9 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.864 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.812 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.818 **FAIL** (level 0.9, cap) | 499/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.804 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.826 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.84 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.824 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.81 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.826 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.814 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.814 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.782 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.824 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.816 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.822 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.83 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.846 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.84 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.836 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.842 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.89 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.846 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.886 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.862 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.83 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.836 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.834 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.83 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.818 **FAIL** (level 0.938, rate) | 500/500 |  |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.846 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.844 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Greedy@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:GreedyDOptimal@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.846 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Optimal | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:OptimalBlocks@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.892 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.832 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.804 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Atkinson | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.898 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.864 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.85 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.864 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.836 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK14 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:KK21stepwise | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.886 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.868 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.854 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.834 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.828 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.812 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power50 | 0.818 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | power50 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountPoisson | gradient | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | gradient | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountPoisson | gradient | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | gradient | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | Fixed:Blocking@0.2 | CountPoisson | lik_ratio | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | lik_ratio | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountPoisson | lik_ratio | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | lik_ratio | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | score | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountPoisson | score | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | score | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:RandomBlockSize | CountPoisson | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR | CountPoisson | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:SPBR@0.2 | CountPoisson | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.888 **FAIL** (level 0.95, rate check) | 500/500 |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | power50 | 0.855 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.841 **FAIL** (level 0.9, unknown) | 490/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 485/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 484/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.809 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.801 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.809 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.801 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.819 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.812 **FAIL** (level 0.9, unknown) | 485/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.837 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.812 **FAIL** (level 0.9, unknown) | 485/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.81 **FAIL** (level 0.9, unknown) | 484/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 481/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.823 **FAIL** (level 0.9, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.821 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.821 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.823 **FAIL** (level 0.9, unknown) | 492/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 494/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.833 **FAIL** (level 0.9, unknown) | 485/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.802 **FAIL** (level 0.9, unknown) | 479/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power20 | 0.847 **FAIL** (level 0.9, unknown) | 485/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power20 | 0.849 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | score | ~. | 50 | 50 | unknown | power50 | 0.845 **FAIL** (level 0.9, unknown) | 491/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | 10 | unknown | power50 | 0.793 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedNegBin | score | ~. | 52 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.853 **FAIL** (level 0.9, unknown) | 490/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.817 **FAIL** (level 0.9, unknown) | 481/500 | rate unknown: open a TODO to establish it |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.838 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.818 **FAIL** (level 0.9, unknown) | 479/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 480/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.817 **FAIL** (level 0.9, unknown) | 482/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.817 **FAIL** (level 0.9, unknown) | 482/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 481/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.831 **FAIL** (level 0.9, unknown) | 479/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.817 **FAIL** (level 0.9, unknown) | 481/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.818 **FAIL** (level 0.9, unknown) | 477/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 482/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.824 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.831 **FAIL** (level 0.9, unknown) | 479/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.833 **FAIL** (level 0.9, unknown) | 480/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 487/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.845 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.845 **FAIL** (level 0.9, unknown) | 489/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.842 **FAIL** (level 0.9, unknown) | 493/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 480/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.849 **FAIL** (level 0.9, unknown) | 476/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power20 | 0.843 **FAIL** (level 0.9, unknown) | 483/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedNegBin | wald | ~. | 50 | 50 | unknown | power50 | 0.84 **FAIL** (level 0.9, unknown) | 488/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | wald | ~. | 50 | 10 | unknown | power50 | 0.813 **FAIL** (level 0.9, unknown) | 486/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.812 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.808 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.802 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.8 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.8 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.842 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.82 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.796 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 50 | 10 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.834 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.828 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.802 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.836 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.886 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.876 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.852 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.872 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.846 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.828 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.844 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.878 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.83 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.842 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 200 | 40 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | gradient | ~1 | 200 | 200 | unknown | power50 | 0.89 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.808 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.806 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.822 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.806 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.834 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 10 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 50 | 50 | unknown | power20 | 0.824 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.834 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.828 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.802 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.836 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.888 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.878 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.844 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.836 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.828 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.846 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.88 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.844 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | lik_ratio | ~1 | 200 | 200 | unknown | power50 | 0.89 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.832 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.814 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.818 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.818 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.828 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.81 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.85 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.838 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.852 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.848 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.816 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | score | ~1 | 50 | 10 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 50 | 50 | unknown | power20 | 0.82 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.832 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.846 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.824 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Greedy | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:GreedyDOptimal | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.9 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.806 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.836 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:MatchingGreedyPairSwitching | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.888 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.88 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.858 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.854 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Atkinson | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.848 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.828 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.846 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK14 | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.85 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21 | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.874 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:KK21stepwise | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.882 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:PocockSimon | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.856 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.86 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.84 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.846 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | score | ~1 | 200 | 40 | unknown | power20 | 0.844 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power20 | 0.854 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal | CountZeroInflatedPoisson | score | ~1 | 200 | 200 | unknown | power50 | 0.89 **FAIL** (level 0.938, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | power20 | 0.838 **FAIL** (level 0.9, unknown) | 500/500 | rate unknown: open a TODO to establish it |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.844 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.842 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.84 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | wald | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.846 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.844 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:Blocking@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.842 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.828 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:OptimalBlocks@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.84 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | wald | ~1 | 50 | 10 | 1 (assumed_default) | power20 | 0.846 **FAIL** (level 0.9, cap) | 500/500 |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | lik_ratio | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.912 **FAIL** (level 0.95, rate check) | 500/500 |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.905 **FAIL** (level 0.95, rate check) | 482/500 |  |
| survival | SeqOneByOne:iBCRD | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.911 **FAIL** (level 0.95, rate check) | 482/500 |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | power20 | 0.908 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | wald | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | Fixed:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.86 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Bernoulli@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.892 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:BinaryMatch | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.89 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Blocking@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Blocking | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.874 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Greedy | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:GreedyDOptimal | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.89 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.878 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.894 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Optimal | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Optimal@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.894 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:OptimalBlocks | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Rerandomization | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.88 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Atkinson | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.874 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.86 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK14 | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK21 | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.87 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK21stepwise | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.868 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.882 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.87 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | wald | ~1 | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~1 | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~1 | 50 | 50 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | Fixed:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.86 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Bernoulli@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.892 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:BinaryMatch | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.89 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Blocking@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Blocking | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.874 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Greedy | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:GreedyDOptimal | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.89 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.878 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.894 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Optimal | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Optimal@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.894 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:OptimalBlocks | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.906 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Rerandomization | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.88 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Rerandomization@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.914 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Atkinson | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.872 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.838 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.874 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.856 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.86 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK14 | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK21 | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.87 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:KK21stepwise | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.868 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.848 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.85 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.916 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.866 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | wald | ~1 | 200 | 40 | 1 (assumed_default) | power20 | 0.882 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~1 | 200 | 200 | 1 (assumed_default) | power20 | 0.87 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:Efron | OrdinalCauchitRegr | gradient | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.847 **FAIL** (level 0.9, cap) | 497/500 |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | gradient | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.892 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:iBCRD@0.2 | OrdinalCauchitRegr | gradient | ~. | 200 | 40 | 1 (assumed_default) | power20 | 0.91 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | gradient | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.902 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | lik_ratio | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.9 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | lik_ratio | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.904 **FAIL** (level 0.95, rate check) | 500/500 |  |
| ordinal | Fixed:Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | Fixed:Blocking | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.854 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | Fixed:Blocking@0.2 | OrdinalCauchitRegr | score | ~. | 50 | 10 | 1 (assumed_default) | power20 | 0.855 **FAIL** (level 0.9, cap) | 496/500 |  |
| ordinal | Fixed:Greedy | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | Fixed:GreedyDOptimal | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | SeqOneByOne:Bernoulli | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.822 **FAIL** (level 0.9, cap) | 499/500 |  |
| ordinal | SeqOneByOne:Efron | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.853 **FAIL** (level 0.9, cap) | 497/500 |  |
| ordinal | SeqOneByOne:iBCRD | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.849 **FAIL** (level 0.9, cap) | 497/500 |  |
| ordinal | SeqOneByOne:KK14 | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.844 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.851 **FAIL** (level 0.9, cap) | 498/500 |  |
| ordinal | SeqOneByOne:Urn | OrdinalCauchitRegr | score | ~. | 50 | 50 | 1 (assumed_default) | power20 | 0.852 **FAIL** (level 0.9, cap) | 500/500 |  |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | score | ~. | 200 | 200 | 1 (assumed_default) | power20 | 0.894 **FAIL** (level 0.95, rate check) | 500/500 |  |

### Bias at beta_T != 0 (reported, not gated)

12680 estimand cells; flagged (z-test at 0.01 / 11579 and |bias| / SD > 0.1): **608**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the largest n, 200): **1119** of 6308 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | effect | bias | bias / SD |
|---|---|---|---|---|---|---|---|
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 200 | power50 | -0.125 | -1.8 |
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 200 | power20 | -0.0699 | -0.98 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.408 | 0.81 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.408 | 0.81 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.394 | 0.8 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.394 | 0.8 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.39 | 0.78 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.39 | 0.78 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.394 | 0.77 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.394 | 0.77 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.369 | 0.75 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.369 | 0.75 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.372 | 0.73 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.372 | 0.73 |
| count | Fixed:Blocking | AllSimpleWilcox | ~. | 200 | power50 | 0.345 | 0.73 |
| count | Fixed:Blocking | AllSimpleWilcox | ~1 | 200 | power50 | 0.345 | 0.73 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 200 | power50 | 0.34 | 0.72 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 200 | power50 | 0.34 | 0.72 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~. | 200 | power50 | 0.337 | 0.71 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~1 | 200 | power50 | 0.337 | 0.71 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~. | 200 | power50 | 0.336 | 0.7 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~1 | 200 | power50 | 0.336 | 0.7 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0.354 | 0.7 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0.354 | 0.7 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~. | 200 | power50 | 0.332 | 0.7 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~1 | 200 | power50 | 0.332 | 0.7 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 200 | power50 | 0.33 | 0.69 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 200 | power50 | 0.33 | 0.69 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 200 | power50 | 0.322 | 0.69 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 200 | power50 | 0.322 | 0.69 |
(30 shown of 1119; all in `nonnull_bias_summary.csv`.)

| response | design | class | formula | n | effect | true value | bias | bias / SD |
|---|---|---|---|---|---|---|---|---|
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 200 | power50 | 0.123 | -0.125 | -1.8 |
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 200 | power20 | 0.0687 | -0.0699 | -0.98 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.408 | 0.81 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.408 | 0.81 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.394 | 0.8 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.394 | 0.8 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.39 | 0.78 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.39 | 0.78 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.394 | 0.77 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.394 | 0.77 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.369 | 0.75 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.369 | 0.75 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.372 | 0.73 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.372 | 0.73 |
| count | Fixed:Blocking | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.345 | 0.73 |
| count | Fixed:Blocking | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.345 | 0.73 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.34 | 0.72 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.34 | 0.72 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.337 | 0.71 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.337 | 0.71 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.336 | 0.7 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.336 | 0.7 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.354 | 0.7 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.354 | 0.7 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.332 | 0.7 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.332 | 0.7 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.33 | 0.69 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.33 | 0.69 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.322 | 0.69 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.322 | 0.69 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.34 | 0.69 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.34 | 0.69 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.324 | 0.69 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.324 | 0.69 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.319 | 0.68 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.319 | 0.68 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.319 | 0.68 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.319 | 0.68 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.319 | 0.68 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.319 | 0.68 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.31 | 0.67 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.31 | 0.67 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.313 | 0.67 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.313 | 0.67 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.308 | 0.67 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.308 | 0.67 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.298 | 0.65 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.298 | 0.65 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.29 | 0.64 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.29 | 0.64 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.284 | 0.63 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.284 | 0.63 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.29 | 0.62 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.29 | 0.62 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.275 | 0.62 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.275 | 0.62 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.272 | 0.61 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.272 | 0.61 |
| count | Fixed:Optimal | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.262 | 0.6 |
| count | Fixed:Optimal | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.262 | 0.6 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.252 | 0.58 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.252 | 0.58 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.251 | 0.58 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.251 | 0.58 |
| count | Fixed:Greedy | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.243 | 0.57 |
| count | Fixed:Greedy | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.243 | 0.57 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~. | 200 | power50 | 0 | 0.243 | 0.57 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~1 | 200 | power50 | 0 | 0.243 | 0.57 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.216 | 0.5 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.216 | 0.5 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.216 | 0.48 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.216 | 0.48 |
| survival | Fixed:Greedy | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0931 | -0.45 |
| survival | Fixed:Greedy | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0931 | -0.45 |
| survival | Fixed:GreedyDOptimal | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0931 | -0.45 |
| survival | Fixed:GreedyDOptimal | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0931 | -0.45 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.199 | 0.45 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.199 | 0.45 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.196 | 0.45 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.196 | 0.45 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.196 | 0.45 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.196 | 0.45 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.192 | 0.44 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.192 | 0.44 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.164 | 0.43 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.164 | 0.43 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.172 | 0.41 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.172 | 0.41 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.154 | 0.41 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.154 | 0.41 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.146 | 0.41 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.146 | 0.41 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.176 | 0.4 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.176 | 0.4 |
| survival | Fixed:Rerandomization | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0938 | -0.4 |
| survival | Fixed:Rerandomization | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0938 | -0.4 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.137 | 0.39 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.137 | 0.39 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.132 | 0.39 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.132 | 0.39 |
| survival | Fixed:MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.077 | -0.38 |
| survival | Fixed:MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.077 | -0.38 |
| count | Fixed:Blocking | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.14 | 0.38 |
| count | Fixed:Blocking | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.14 | 0.38 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.129 | 0.38 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.129 | 0.38 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.129 | 0.38 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.129 | 0.38 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.132 | 0.38 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.132 | 0.38 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.129 | 0.37 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.129 | 0.37 |
| survival | SeqOneByOne:Efron | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0872 | -0.37 |
| survival | SeqOneByOne:Efron | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0872 | -0.37 |
| survival | Fixed:BinaryMatch | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.075 | -0.37 |
| survival | Fixed:BinaryMatch | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.075 | -0.37 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.124 | 0.37 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.124 | 0.37 |
| survival | Fixed:Optimal | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.075 | -0.36 |
| survival | Fixed:Optimal | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.075 | -0.36 |
| survival | SeqOneByOne:KK21 | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0708 | -0.36 |
| survival | SeqOneByOne:KK21 | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0708 | -0.36 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.124 | 0.36 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.124 | 0.36 |
| survival | SeqOneByOne:SPBR | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0789 | -0.35 |
| survival | SeqOneByOne:SPBR | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0789 | -0.35 |
| survival | SeqOneByOne:PocockSimon | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0799 | -0.35 |
| survival | SeqOneByOne:PocockSimon | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0799 | -0.35 |
| survival | SeqOneByOne:RandomBlockSize | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0826 | -0.35 |
| survival | SeqOneByOne:RandomBlockSize | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0826 | -0.35 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.112 | 0.34 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.112 | 0.34 |
| survival | SeqOneByOne:Urn | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0791 | -0.34 |
| survival | SeqOneByOne:Urn | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0791 | -0.34 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.121 | 0.34 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.121 | 0.34 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.106 | 0.34 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.106 | 0.34 |
| survival | SeqOneByOne:KK21stepwise | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0676 | -0.33 |
| survival | SeqOneByOne:KK21stepwise | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0676 | -0.33 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.11 | 0.33 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.11 | 0.33 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.102 | 0.32 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.102 | 0.32 |
| survival | Fixed:OptimalBlocks | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0664 | -0.32 |
| survival | Fixed:OptimalBlocks | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0664 | -0.32 |
| survival | SeqOneByOne:Atkinson | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0648 | -0.31 |
| survival | SeqOneByOne:Atkinson | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0648 | -0.31 |
| survival | Fixed:Bernoulli | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0727 | -0.31 |
| survival | Fixed:Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0727 | -0.31 |
| survival | SeqOneByOne:iBCRD | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0714 | -0.3 |
| survival | SeqOneByOne:iBCRD | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0714 | -0.3 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.084 | 0.29 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.084 | 0.29 |
| survival | SeqOneByOne:Bernoulli | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0685 | -0.29 |
| survival | SeqOneByOne:Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0685 | -0.29 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.076 | 0.29 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.076 | 0.29 |
| survival | SeqOneByOne:KK14 | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0585 | -0.28 |
| survival | SeqOneByOne:KK14 | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0585 | -0.28 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.078 | 0.28 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.078 | 0.28 |
| count | Fixed:Optimal | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.07 | 0.27 |
| count | Fixed:Optimal | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.07 | 0.27 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.066 | 0.27 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.066 | 0.27 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.252 | -0.0634 | -0.26 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.252 | -0.0634 | -0.26 |
| survival | Fixed:Blocking | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0547 | -0.25 |
| survival | Fixed:Blocking | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0547 | -0.25 |
| survival | Fixed:iBCRD | SurvivalRestrictedMeanDiff | ~. | 200 | power20 | 0.242 | -0.0619 | -0.25 |
| survival | Fixed:iBCRD | SurvivalRestrictedMeanDiff | ~1 | 200 | power20 | 0.242 | -0.0619 | -0.25 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.048 | 0.22 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.048 | 0.22 |
| count | Fixed:Greedy | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.048 | 0.22 |
| count | Fixed:Greedy | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.048 | 0.22 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~. | 200 | power20 | 0 | 0.048 | 0.22 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~1 | 200 | power20 | 0 | 0.048 | 0.22 |
| survival | Fixed:Greedy | SurvivalLogRank | ~. | 200 | power20 | -0.104 | 0.0213 | 0.22 |
| survival | Fixed:Greedy | SurvivalLogRank | ~1 | 200 | power20 | -0.104 | 0.0213 | 0.22 |
| survival | Fixed:GreedyDOptimal | SurvivalLogRank | ~. | 200 | power20 | -0.104 | 0.0213 | 0.22 |
| survival | Fixed:GreedyDOptimal | SurvivalLogRank | ~1 | 200 | power20 | -0.104 | 0.0213 | 0.22 |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | ~. | 50 | power50 | 1.45 | -0.429 | -1.8 |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | ~1 | 50 | power50 | 1.45 | -0.44 | -1.8 |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | ~. | 50 | power50 | 0.229 | -0.232 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | ~. | 50 | power50 | 0.229 | -0.232 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | ~1 | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | ~. | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | ~1 | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | ~. | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | ~1 | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | ~1 | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidWald | ~. | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidWald | ~1 | 50 | power50 | 0.231 | -0.238 | -1.7 |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | ~1 | 50 | power50 | 0.619 | -0.64 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | ~1 | 50 | power50 | 0.375 | -0.388 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidLogRegr | ~1 | 50 | power50 | 1.01 | -1.04 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 50 | power50 | 0.231 | -0.224 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | ~. | 50 | power50 | 0.375 | -0.385 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidModifiedPoisson | ~. | 50 | power50 | 0.372 | -0.377 | -1.6 |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | ~. | 50 | power50 | 0.709 | -0.732 | -1.4 |
| incidence | SeqOneByOne:Urn | IncidLogRegr | ~. | 50 | power50 | 1.19 | -1.23 | -1.4 |
| incidence | SeqOneByOne:Urn | IncidCMH | ~. | 50 | power20 | 0.134 | -0.127 | -0.89 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power20 | 0 | 0.449 | 0.83 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power20 | 0 | 0.449 | 0.83 |
| count | Fixed:Greedy | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.46 | 0.83 |
| count | Fixed:Greedy | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.46 | 0.83 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.46 | 0.83 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.46 | 0.83 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.451 | 0.8 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.451 | 0.8 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.476 | 0.78 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.476 | 0.78 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.414 | 0.76 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.414 | 0.76 |
| count | Fixed:Optimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.396 | 0.75 |
| count | Fixed:Optimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.396 | 0.75 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.492 | 0.75 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.492 | 0.75 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.492 | 0.75 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.492 | 0.75 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.447 | 0.73 |
| count | SeqOneByOne:KK14 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.447 | 0.73 |
| count | Fixed:Blocking | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.464 | 0.72 |
| count | Fixed:Blocking | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.464 | 0.72 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.472 | 0.72 |
| count | Fixed:iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.472 | 0.72 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.479 | 0.71 |
| count | Fixed:Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.479 | 0.71 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.47 | 0.7 |
| count | Fixed:Rerandomization | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.47 | 0.7 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.437 | 0.7 |
| count | SeqOneByOne:Efron | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.437 | 0.7 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.44 | 0.7 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.44 | 0.7 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.415 | 0.7 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.415 | 0.7 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.424 | 0.68 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.424 | 0.68 |
| survival | Fixed:MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~. | 52 | power20 | 0.456 | -0.198 | -0.68 |
| survival | Fixed:MatchingGreedyPairSwitching | SurvivalRestrictedMeanDiff | ~1 | 52 | power20 | 0.456 | -0.198 | -0.68 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.565 | 0.67 |
| count | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.565 | 0.67 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.446 | 0.66 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.446 | 0.66 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.418 | 0.66 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.418 | 0.66 |
| survival | Fixed:iBCRD | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.219 | -0.64 |
| survival | Fixed:iBCRD | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.219 | -0.64 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.408 | 0.64 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.408 | 0.64 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.4 | 0.63 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.4 | 0.63 |
| survival | SeqOneByOne:SPBR | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.213 | -0.63 |
| survival | SeqOneByOne:SPBR | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.213 | -0.63 |
| survival | Fixed:Optimal | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.198 | -0.63 |
| survival | Fixed:Optimal | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.198 | -0.63 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.533 | 0.63 |
| count | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.533 | 0.63 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.423 | 0.62 |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.423 | 0.62 |
| survival | SeqOneByOne:Atkinson | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.203 | -0.62 |
| survival | SeqOneByOne:Atkinson | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.203 | -0.62 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.541 | 0.61 |
| count | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.541 | 0.61 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.481 | 0.6 |
| count | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.481 | 0.6 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.484 | 0.6 |
| count | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.484 | 0.6 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.385 | 0.59 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.385 | 0.59 |
| survival | Fixed:Blocking | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.206 | -0.59 |
| survival | Fixed:Blocking | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.206 | -0.59 |
| survival | Fixed:BinaryMatch | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.19 | -0.59 |
| survival | Fixed:BinaryMatch | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.19 | -0.59 |
| survival | Fixed:Greedy | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | Fixed:Greedy | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | Fixed:GreedyDOptimal | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | Fixed:GreedyDOptimal | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.58 |
| survival | SeqOneByOne:iBCRD | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.203 | -0.58 |
| survival | SeqOneByOne:iBCRD | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.203 | -0.58 |
| survival | SeqOneByOne:Urn | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.203 | -0.58 |
| survival | SeqOneByOne:Urn | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.203 | -0.58 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.485 | 0.58 |
| count | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.485 | 0.58 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.474 | 0.57 |
| count | Fixed:Blocking@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.474 | 0.57 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.457 | 0.57 |
| count | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.457 | 0.57 |
| survival | SeqOneByOne:RandomBlockSize | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.192 | -0.54 |
| survival | SeqOneByOne:RandomBlockSize | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.192 | -0.54 |
| survival | Fixed:OptimalBlocks | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.185 | -0.53 |
| survival | Fixed:OptimalBlocks | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.185 | -0.53 |
| survival | SeqOneByOne:KK21 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.173 | -0.52 |
| survival | SeqOneByOne:KK21 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.173 | -0.52 |
| survival | SeqOneByOne:KK21stepwise | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.18 | -0.52 |
| survival | SeqOneByOne:KK21stepwise | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.18 | -0.52 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.482 | 0.52 |
| count | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.482 | 0.52 |
| survival | Fixed:Bernoulli | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.182 | -0.51 |
| survival | Fixed:Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.182 | -0.51 |
| survival | SeqOneByOne:PocockSimon | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.177 | -0.5 |
| survival | SeqOneByOne:PocockSimon | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.177 | -0.5 |
| survival | SeqOneByOne:KK14 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.172 | -0.48 |
| survival | SeqOneByOne:KK14 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.172 | -0.48 |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.188 | 0.47 |
| ordinal | Fixed:iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.188 | 0.47 |
| survival | Fixed:Rerandomization | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.176 | -0.47 |
| survival | Fixed:Rerandomization | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.176 | -0.47 |
| ordinal | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power20 | 0 | 0.18 | 0.47 |
| ordinal | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power20 | 0 | 0.18 | 0.47 |
| ordinal | SeqOneByOne:Efron | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.178 | 0.47 |
| ordinal | SeqOneByOne:Efron | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.178 | 0.47 |
| survival | SeqOneByOne:Efron | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.165 | -0.46 |
| survival | SeqOneByOne:Efron | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.165 | -0.46 |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.186 | 0.46 |
| ordinal | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.186 | 0.46 |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.177 | 0.46 |
| ordinal | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.177 | 0.46 |
| ordinal | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.184 | 0.46 |
| ordinal | SeqOneByOne:PocockSimon | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.184 | 0.46 |
| ordinal | Fixed:OptimalBlocks | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.183 | 0.46 |
| ordinal | Fixed:OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.183 | 0.46 |
| ordinal | Fixed:Rerandomization | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.176 | 0.46 |
| ordinal | Fixed:Rerandomization | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.176 | 0.46 |
| ordinal | SeqOneByOne:Atkinson | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.174 | 0.46 |
| ordinal | SeqOneByOne:Atkinson | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.174 | 0.46 |
| survival | SeqOneByOne:Bernoulli | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.456 | -0.169 | -0.45 |
| survival | SeqOneByOne:Bernoulli | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.456 | -0.169 | -0.45 |
| ordinal | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.171 | 0.45 |
| ordinal | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.171 | 0.45 |
| ordinal | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.174 | 0.45 |
| ordinal | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.174 | 0.45 |
| ordinal | Fixed:Bernoulli | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.165 | 0.44 |
| ordinal | Fixed:Bernoulli | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.165 | 0.44 |
| ordinal | SeqOneByOne:SPBR | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.159 | 0.44 |
| ordinal | SeqOneByOne:SPBR | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.159 | 0.44 |
| ordinal | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.184 | 0.43 |
| ordinal | Fixed:iBCRD@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.184 | 0.43 |
| ordinal | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.182 | 0.43 |
| ordinal | SeqOneByOne:iBCRD@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.182 | 0.43 |
| ordinal | Fixed:BinaryMatch | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.16 | 0.42 |
| ordinal | Fixed:BinaryMatch | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.16 | 0.42 |
| ordinal | Fixed:Greedy | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | Fixed:Greedy | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | Fixed:GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | Fixed:GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.148 | 0.42 |
| ordinal | Fixed:Blocking | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.159 | 0.41 |
| ordinal | Fixed:Blocking | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.159 | 0.41 |
| ordinal | SeqOneByOne:KK21 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.144 | 0.41 |
| ordinal | SeqOneByOne:KK21 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.144 | 0.41 |
| ordinal | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.162 | 0.4 |
| ordinal | SeqOneByOne:RandomBlockSize@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.162 | 0.4 |
| ordinal | Fixed:Optimal | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.136 | 0.4 |
| ordinal | Fixed:Optimal | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.136 | 0.4 |
| ordinal | Fixed:Optimal@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.156 | 0.39 |
| ordinal | Fixed:Optimal@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.156 | 0.39 |
| ordinal | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.155 | 0.39 |
| ordinal | SeqOneByOne:SPBR@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.155 | 0.39 |
| ordinal | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.126 | 0.38 |
| ordinal | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.126 | 0.38 |
| ordinal | Fixed:Blocking@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.159 | 0.38 |
| ordinal | Fixed:Blocking@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.159 | 0.38 |
| ordinal | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.144 | 0.37 |
| ordinal | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.144 | 0.37 |
| ordinal | Fixed:Greedy@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.144 | 0.37 |
| ordinal | Fixed:Greedy@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.144 | 0.37 |
| incidence | Fixed:iBCRD | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.356 | 0.37 |
| ordinal | SeqOneByOne:KK14 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.128 | 0.37 |
| ordinal | SeqOneByOne:KK14 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.128 | 0.37 |
| ordinal | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.153 | 0.37 |
| ordinal | Fixed:Rerandomization@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.153 | 0.37 |
| ordinal | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.164 | 0.37 |
| ordinal | Fixed:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.164 | 0.37 |
| ordinal | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.162 | 0.36 |
| ordinal | SeqOneByOne:Bernoulli@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.162 | 0.36 |
| ordinal | SeqOneByOne:Urn | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.377 | 0.35 |
| incidence | SeqOneByOne:PocockSimon | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.367 | 0.35 |
| ordinal | Fixed:OptimalBlocks | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.382 | 0.35 |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidLogRegr | ~. | 52 | power50 | 1.19 | 0.33 | 0.35 |
| incidence | Fixed:iBCRD | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.192 | 0.35 |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.363 | 0.34 |
| ordinal | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~. | 50 | power20 | 0 | 0.145 | 0.33 |
| ordinal | Fixed:OptimalBlocks@0.2 | AllSimpleWilcox | ~1 | 50 | power20 | 0 | 0.145 | 0.33 |
| ordinal | Fixed:Rerandomization | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.325 | 0.33 |
| ordinal | Fixed:Greedy | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.346 | 0.33 |
| ordinal | Fixed:GreedyDOptimal | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.346 | 0.33 |
| incidence | SeqOneByOne:RandomBlockSize | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.305 | 0.33 |
| incidence | SeqOneByOne:PocockSimon | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.2 | 0.33 |
| incidence | SeqOneByOne:Efron | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.327 | 0.33 |
| incidence | Fixed:BinaryMatch | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.196 | 0.33 |
| incidence | SeqOneByOne:KK14 | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.306 | 0.32 |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidProbitRegr | ~. | 52 | power50 | 0.709 | 0.175 | 0.32 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.202 | -0.32 |
| count | SeqOneByOne:KK21 | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.202 | -0.32 |
| ordinal | SeqOneByOne:Efron | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.382 | 0.32 |
| continuous | Fixed:MatchingGreedyPairSwitching | ContinQuantileRegr | ~1 | 52 | power50 | 0.543 | -0.11 | -0.32 |
| incidence | SeqOneByOne:KK21stepwise | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.309 | 0.32 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.203 | -0.32 |
| count | Fixed:OptimalBlocks | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.203 | -0.32 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~. | 52 | power50 | 1 | -0.164 | -0.32 |
| count | Fixed:MatchingGreedyPairSwitching | AllSimpleWilcox | ~1 | 52 | power50 | 1 | -0.164 | -0.32 |
| incidence | Fixed:iBCRD@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.476 | 0.32 |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.525 | 0.32 |
| ordinal | Fixed:BinaryMatch | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.347 | 0.32 |
| incidence | SeqOneByOne:iBCRD | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.304 | 0.32 |
| incidence | Fixed:Greedy | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.195 | 0.31 |
| incidence | Fixed:GreedyDOptimal | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.195 | 0.31 |
| count | Fixed:Greedy | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.17 | -0.31 |
| count | Fixed:Greedy | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.17 | -0.31 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.17 | -0.31 |
| count | Fixed:GreedyDOptimal | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.17 | -0.31 |
| incidence | SeqOneByOne:KK21 | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.18 | 0.31 |
| ordinal | SeqOneByOne:iBCRD | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.346 | 0.31 |
| ordinal | Fixed:Optimal | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.302 | 0.31 |
| incidence | Fixed:Greedy@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.506 | 0.31 |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.506 | 0.31 |
| ordinal | Fixed:iBCRD | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.341 | 0.31 |
| incidence | SeqOneByOne:Efron | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.177 | 0.31 |
| incidence | Fixed:Bernoulli | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.204 | 0.31 |
| incidence | Fixed:Blocking | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.197 | 0.31 |
| ordinal | Fixed:BinaryMatch | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.409 | 0.3 |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.44 | 0.3 |
| incidence | SeqOneByOne:KK21stepwise | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.167 | 0.3 |
| incidence | SeqOneByOne:KK14 | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.165 | 0.3 |
| ordinal | Fixed:Blocking | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.301 | 0.3 |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.52 | 0.3 |
| ordinal | SeqOneByOne:Bernoulli | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.326 | 0.3 |
| incidence | Fixed:Optimal@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.439 | 0.3 |
| incidence | SeqOneByOne:RandomBlockSize | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.159 | 0.3 |
| incidence | Fixed:Blocking@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.443 | 0.3 |
| ordinal | SeqOneByOne:iBCRD | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.48 | 0.3 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.168 | -0.3 |
| count | Fixed:BinaryMatch | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.168 | -0.3 |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.52 | 0.3 |
| incidence | Fixed:OptimalBlocks | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.218 | 0.3 |
| incidence | Fixed:OptimalBlocks@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.456 | 0.3 |
| incidence | SeqOneByOne:Atkinson | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.289 | 0.29 |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.55 | 0.29 |
| count | Fixed:Optimal | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.152 | -0.29 |
| count | Fixed:Optimal | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.152 | -0.29 |
| ordinal | Fixed:Bernoulli | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.326 | 0.29 |
| incidence | SeqOneByOne:iBCRD | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.161 | 0.29 |
| incidence | Fixed:Greedy@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.44 | 0.29 |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.44 | 0.29 |
| incidence | Fixed:BinaryMatch | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.391 | 0.29 |
| ordinal | SeqOneByOne:iBCRD | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.111 | 0.29 |
| incidence | Fixed:iBCRD@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.28 | 0.28 |
| incidence | Fixed:Bernoulli | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.395 | 0.28 |
| incidence | Fixed:Optimal | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.189 | 0.28 |
| incidence | Fixed:Greedy | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.384 | 0.28 |
| incidence | Fixed:GreedyDOptimal | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.384 | 0.28 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.192 | -0.28 |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.192 | -0.28 |
| ordinal | SeqOneByOne:PocockSimon | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.438 | 0.28 |
| incidence | Fixed:Bernoulli@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.417 | 0.28 |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.483 | -0.136 | -0.28 |
| survival | Fixed:iBCRD@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.483 | -0.136 | -0.28 |
| survival | Fixed:Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.242 | 0.28 |
| survival | Fixed:Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.242 | 0.28 |
| ordinal | Fixed:OptimalBlocks@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.603 | 0.28 |
| incidence | Fixed:Rerandomization | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.2 | 0.28 |
| incidence | SeqOneByOne:Bernoulli | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.234 | 0.28 |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalCauchitRegr | ~. | 52 | power20 | 0.534 | 0.264 | 0.28 |
| incidence | Fixed:Blocking | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.38 | 0.28 |
| incidence | SeqOneByOne:KK21 | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.353 | 0.28 |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.438 | 0.28 |
| incidence | Fixed:Rerandomization@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.427 | 0.28 |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.107 | 0.27 |
| incidence | Fixed:OptimalBlocks@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.28 | 0.27 |
| incidence | SeqOneByOne:SPBR@0.2 | IncidProbitRegr | ~. | 50 | power50 | 0.721 | 0.362 | 0.27 |
| ordinal | Fixed:OptimalBlocks | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.436 | 0.27 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.177 | -0.27 |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.177 | -0.27 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.181 | -0.27 |
| count | SeqOneByOne:Urn | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.181 | -0.27 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.483 | -0.108 | -0.27 |
| survival | Fixed:Optimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.483 | -0.108 | -0.27 |
| incidence | Fixed:Optimal@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.2 | 0.27 |
| incidence | Fixed:Blocking@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.23 | 0.27 |
| ordinal | Fixed:Optimal@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.581 | 0.27 |
| incidence | Fixed:OptimalBlocks | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.414 | 0.27 |
| incidence | SeqOneByOne:Atkinson | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.152 | 0.27 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.483 | -0.111 | -0.27 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.483 | -0.111 | -0.27 |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~. | 50 | power20 | 0.483 | -0.111 | -0.27 |
| survival | Fixed:Greedy@0.2 | SurvivalRestrictedMeanDiff | ~1 | 50 | power20 | 0.483 | -0.111 | -0.27 |
| incidence | Fixed:Blocking | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.226 | 0.27 |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.29 | 0.27 |
| ordinal | SeqOneByOne:Atkinson | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.269 | 0.27 |
| ordinal | SeqOneByOne:PocockSimon | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.277 | 0.27 |
| incidence | Fixed:Bernoulli@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.19 | 0.27 |
| incidence | Fixed:Rerandomization@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 1.26 | 0.27 |
| ordinal | SeqOneByOne:Urn | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.108 | 0.26 |
| ordinal | Fixed:iBCRD@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.539 | 0.26 |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 1.27 | 0.26 |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalStereotypeLogitRegr | ~. | 52 | power20 | 0.895 | 0.358 | 0.26 |
| ordinal | Fixed:GreedyDOptimal@0.2 | OrdinalCauchitRegr | ~. | 50 | power20 | 0.515 | 0.302 | 0.26 |
| ordinal | Fixed:Greedy@0.2 | OrdinalCauchitRegr | ~. | 50 | power20 | 0.515 | 0.302 | 0.26 |
| ordinal | SeqOneByOne:Bernoulli | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.408 | 0.26 |
| incidence | Fixed:Greedy | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.217 | 0.26 |
| incidence | Fixed:GreedyDOptimal | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.217 | 0.26 |
| incidence | Fixed:Rerandomization | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.391 | 0.26 |
| ordinal | SeqOneByOne:Urn | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.413 | 0.26 |
| incidence | SeqOneByOne:RandomBlockSize@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.37 | 0.26 |
| incidence | SeqOneByOne:SPBR | IncidProbitRegr | ~. | 50 | power50 | 0.709 | 0.157 | 0.26 |
| ordinal | Fixed:iBCRD@0.2 | OrdinalCauchitRegr | ~. | 50 | power20 | 0.515 | 0.374 | 0.26 |
| ordinal | Fixed:Rerandomization | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.405 | 0.26 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.169 | -0.26 |
| count | Fixed:GreedyDOptimal@0.2 | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.169 | -0.26 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.169 | -0.26 |
| count | Fixed:Greedy@0.2 | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.169 | -0.26 |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 1.3 | 0.26 |
| ordinal | SeqOneByOne:KK21stepwise | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.233 | 0.25 |
| continuous | Fixed:MatchingGreedyPairSwitching | ContinQuantileRegr | ~1 | 52 | power20 | 0.317 | -0.0803 | -0.25 |
| incidence | Fixed:BinaryMatch | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.207 | 0.25 |
| incidence | Fixed:Blocking | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.125 | 0.25 |
| ordinal | SeqOneByOne:Efron | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.393 | 0.25 |
| incidence | Fixed:Bernoulli | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.23 | 0.25 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.152 | -0.25 |
| count | SeqOneByOne:KK21stepwise | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.152 | -0.25 |
| ordinal | SeqOneByOne:SPBR | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.257 | 0.25 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.168 | -0.25 |
| count | Fixed:Optimal@0.2 | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.168 | -0.25 |
| incidence | Fixed:iBCRD | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.213 | 0.25 |
| incidence | SeqOneByOne:SPBR@0.2 | IncidLogRegr | ~. | 50 | power50 | 1.2 | 0.974 | 0.25 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.162 | -0.25 |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.162 | -0.25 |
| ordinal | Fixed:Greedy | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.391 | 0.25 |
| ordinal | Fixed:GreedyDOptimal | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.391 | 0.25 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.169 | -0.25 |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.169 | -0.25 |
| ordinal | SeqOneByOne:Atkinson | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.353 | 0.25 |
| ordinal | Fixed:BinaryMatch | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0941 | 0.25 |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.24 | 0.25 |
| survival | SeqOneByOne:iBCRD@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.24 | 0.25 |
| ordinal | SeqOneByOne:KK21 | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.233 | 0.25 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~. | 50 | power50 | 1 | -0.137 | -0.24 |
| count | SeqOneByOne:Atkinson | AllSimpleWilcox | ~1 | 50 | power50 | 1 | -0.137 | -0.24 |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidLogRegr | ~. | 52 | power20 | 0.667 | 0.212 | 0.24 |
| incidence | Fixed:Greedy@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 1.14 | 0.24 |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 1.14 | 0.24 |
| incidence | Fixed:Greedy | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.117 | 0.24 |
| incidence | Fixed:GreedyDOptimal | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.117 | 0.24 |
| ordinal | Fixed:Rerandomization | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0893 | 0.24 |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.215 | 0.24 |
| survival | SeqOneByOne:SPBR@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.215 | 0.24 |
| incidence | SeqOneByOne:Bernoulli | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.476 | 0.24 |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalCloglogRegr | ~. | 50 | power20 | 0.418 | 0.124 | 0.24 |
| ordinal | Fixed:Rerandomization@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.502 | 0.24 |
| incidence | SeqOneByOne:Bernoulli | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.215 | 0.24 |
| incidence | SeqOneByOne:SPBR | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.317 | 0.24 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.23 | 0.24 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.23 | 0.24 |
| ordinal | Fixed:Blocking | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.356 | 0.24 |
| ordinal | Fixed:Bernoulli@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.509 | 0.24 |
| incidence | Fixed:BinaryMatch | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.113 | 0.24 |
| incidence | Fixed:Optimal@0.2 | IncidProbitRegr | ~. | 50 | power20 | 0.421 | 0.263 | 0.24 |
| ordinal | SeqOneByOne:KK14 | OrdinalCauchitRegr | ~. | 50 | power20 | 0.534 | 0.249 | 0.24 |
| incidence | Fixed:OptimalBlocks | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.207 | 0.24 |
| incidence | Fixed:Optimal | IncidLogRegr | ~. | 50 | power50 | 1.19 | 0.39 | 0.24 |
| incidence | SeqOneByOne:Efron | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.197 | 0.23 |
| ordinal | Fixed:iBCRD@0.2 | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.298 | 0.124 | 0.23 |
| incidence | Fixed:Bernoulli | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.125 | 0.23 |
| continuous | Fixed:GreedyDOptimal@0.2 | ContinQuantileRegr | ~1 | 50 | power50 | 0.532 | -0.0911 | -0.23 |
| continuous | Fixed:Greedy@0.2 | ContinQuantileRegr | ~1 | 50 | power50 | 0.532 | -0.0911 | -0.23 |
| ordinal | SeqOneByOne:Bernoulli@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.484 | 0.23 |
| incidence | SeqOneByOne:Bernoulli | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0799 | 0.23 |
| incidence | SeqOneByOne:Bernoulli@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.348 | 0.23 |
| incidence | Fixed:Greedy@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.32 | 0.23 |
| incidence | Fixed:GreedyDOptimal@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.32 | 0.23 |
| count | Fixed:Optimal@0.2 | CountHurdleNegBin | ~1 | 50 | power20 | 0.199 | -0.0685 | -0.23 |
| count | Fixed:Optimal@0.2 | CountHurdlePoisson | ~1 | 50 | power20 | 0.176 | -0.0604 | -0.23 |
| ordinal | SeqOneByOne:RandomBlockSize | OrdinalContRatioRegr | ~. | 50 | power20 | 0.508 | 0.139 | 0.23 |
| incidence | Fixed:MatchingGreedyPairSwitching | IncidProbitRegr | ~. | 52 | power20 | 0.401 | 0.115 | 0.23 |
| incidence | Fixed:iBCRD@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.966 | 0.23 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.197 | 0.23 |
| survival | Fixed:GreedyDOptimal@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.197 | 0.23 |
| survival | Fixed:Greedy@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.197 | 0.23 |
| survival | Fixed:Greedy@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.197 | 0.23 |
| incidence | Fixed:iBCRD | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.23 |
| survival | SeqOneByOne:Bernoulli | SurvivalCoxPHRegr | ~. | 50 | power20 | -0.405 | -0.112 | -0.23 |
| ordinal | SeqOneByOne:SPBR | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.343 | 0.23 |
| incidence | Fixed:OptimalBlocks@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.999 | 0.23 |
| incidence | Fixed:iBCRD@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.287 | 0.23 |
| incidence | SeqOneByOne:iBCRD@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 1.03 | 0.23 |
| incidence | Fixed:Blocking | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0763 | 0.23 |
| ordinal | Fixed:MatchingGreedyPairSwitching | OrdinalAdjCatLogitRegr | ~. | 52 | power20 | 0.301 | 0.0836 | 0.23 |
| incidence | Fixed:Blocking@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.97 | 0.23 |
| ordinal | Fixed:Blocking@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.463 | 0.23 |
| incidence | Fixed:Optimal@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.925 | 0.23 |
| incidence | Fixed:Optimal@0.2 | IncidProbitRegr | ~1 | 50 | power50 | 0.616 | 0.276 | 0.23 |
| incidence | Fixed:Bernoulli | IncidGCompRiskRatio | ~. | 50 | power20 | 1.26 | 0.0833 | 0.22 |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalKMDiff | ~. | 50 | power20 | 0.316 | 0.214 | 0.22 |
| survival | SeqOneByOne:Bernoulli@0.2 | SurvivalKMDiff | ~1 | 50 | power20 | 0.316 | 0.214 | 0.22 |
| incidence | SeqOneByOne:Bernoulli | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.22 |
| incidence | SeqOneByOne:RandomBlockSize | IncidLogRegr | ~. | 50 | power20 | 0.667 | 0.195 | 0.22 |
| incidence | Fixed:OptimalBlocks | IncidProbitRegr | ~. | 50 | power20 | 0.401 | 0.116 | 0.22 |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedNegBin | ~1 | 50 | power20 | 0.253 | -0.136 | -0.22 |
| survival | SeqOneByOne:Bernoulli | SurvivalStratCoxPHRegr | ~. | 50 | power20 | -0.405 | -0.116 | -0.22 |
| incidence | Fixed:Bernoulli@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.96 | 0.22 |
| incidence | Fixed:Blocking | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0782 | 0.22 |
| ordinal | Fixed:GreedyDOptimal@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.407 | 0.22 |
| ordinal | Fixed:Greedy@0.2 | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.407 | 0.22 |
| ordinal | Fixed:Bernoulli | OrdinalStereotypeLogitRegr | ~. | 50 | power20 | 0.895 | 0.347 | 0.22 |
| incidence | Fixed:Rerandomization@0.2 | IncidLogRegr | ~1 | 50 | power50 | 1 | 0.987 | 0.22 |
| ordinal | SeqOneByOne:Efron | OrdinalAdjCatLogitRegr | ~. | 50 | power20 | 0.301 | 0.0908 | 0.22 |
| incidence | SeqOneByOne:PocockSimon | IncidGCompRiskRatio | ~1 | 50 | power20 | 1.26 | 0.0841 | 0.22 |

### Power (reported, not gated)

36168 power cells; see `power_summary.csv`, `design_comparison.csv` (paired tests between designs, when the campaign is complete) and the power figures.

