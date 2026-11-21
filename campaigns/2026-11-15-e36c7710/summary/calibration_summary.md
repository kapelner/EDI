## EDI calibration study, campaign 2026-11-15-e36c7710

Progress: 7031901 of 14965000 replicates (46%) after wave 24; 5689 of 20257 cells complete, 0 abandoned.

30792 null cells and 0 power cells have results; 52788 of the plan's 129978 tests (null size and coverage, coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate: Benjamini-Hochberg q < 0.05 over all 129978 tests of the plan on the screening replicates (a test enters with its p-value when its cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only "not flagged" is provisional) flags **1598** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at 0.01 / 129978, fixed in advance, so a confirmed failure is final when it is made.

Confirmation so far: 1429 confirmed failing, 81 pending, 0 could not be confirmed (counted as failing), 88 cleared. Failing null cells so far (provisional): **838**.

Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of 0.1 reached at n_eff = 50 (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n (`rate check`). Null cells by rule (size): cap 6722, finite 7548, mismatch 1260, rate 10325, rate_check 275, unknown 4662.

726 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Fixed:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | SeqOneByOne:Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.192 **FAIL** (level 0.1, cap) | 0.808 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
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
| incidence | SeqOneByOne:RandomBlockSize | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0785 **FAIL** (level 0.0525, unknown) | 0.924 (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |
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
| count | Fixed:Optimal | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.867 (level 0.9, unknown) | 971/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.864 **FAIL** (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.158 **FAIL** (level 0.1, unknown) | 0.854 (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.142 **FAIL** (level 0.1, unknown) | 0.867 (level 0.9, unknown) | 964/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | gradient | ~. | 50 | 50 | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.854 **FAIL** (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | gradient | ~. | 50 | 10 | unknown | 0.14 **FAIL** (level 0.1, unknown) | 0.868 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
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
| count | Fixed:Optimal@0.2 | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 10 | unknown | 0.151 **FAIL** (level 0.1, unknown) | 0.868 (level 0.9, unknown) | 965/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:OptimalBlocks | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.866 (level 0.9, unknown) | 947/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | lik_ratio | ~. | 50 | 50 | unknown | 0.154 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 972/1000 |  | rate unknown: open a TODO to establish it |
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
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.0791 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 999/1000 |  |  |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.085 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | SeqOneByOne:SPBR | CountZeroInflatedNegBin | rand | ~1 | 50 | 50 | Inf (theory) | 0.078 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| count | Fixed:BinaryMatch | CountZeroInflatedNegBin | rand | ~1 | 200 | 200 | Inf (theory) | 0.088 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
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
| count | Fixed:Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.134 **FAIL** (level 0.1, unknown) | 0.869 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Blocking | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.135 **FAIL** (level 0.1, unknown) | 0.863 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.149 **FAIL** (level 0.1, unknown) | 0.853 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.133 **FAIL** (level 0.1, unknown) | 0.869 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.152 **FAIL** (level 0.1, unknown) | 0.844 **FAIL** (level 0.9, unknown) | 999/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Bernoulli | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.137 **FAIL** (level 0.1, unknown) | 0.869 (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:Efron | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.136 **FAIL** (level 0.1, unknown) | 0.862 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedNegBin | score | ~1 | 50 | 10 | unknown | 0.138 **FAIL** (level 0.1, unknown) | 0.861 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | score | ~1 | 50 | 50 | unknown | 0.146 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
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
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | wald | ~1 | 50 | 10 | unknown | 0.145 **FAIL** (level 0.1, unknown) | 0.855 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| proportion | Fixed:Bernoulli@0.2 | PropQuantileRegr | wald | ~. | 1000 | 200 | 0.667 (literature) | 0.076 **FAIL** (level 0.05, rate check) | 0.924 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Greedy | SurvivalCoxPHRegr | rand | ~. | 200 | 200 (proxy) | Inf (theory) | 0.075 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal | SurvivalCoxPHRegr | rand | ~. | 200 | 200 (proxy) | Inf (theory) | 0.075 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Optimal@0.2 | SurvivalDepCensTransformRegr | score | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.125 (level 0.1, cap) | 0.867 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| survival | Fixed:GreedyDOptimal | SurvivalDepCensTransformRegr | score | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.075 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
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
| survival | SeqOneByOne:KK14 | SurvivalGLMMWeibullFrailtyNormalOneLik | score | ~. | 50 | 50 (proxy) | unknown | 0.129 (level 0.1, unknown) | 0.867 **FAIL** (level 0.9, unknown) | 1000/1000 |  | rate unknown: open a TODO to establish it |
| survival | SeqOneByOne:KK21stepwise | SurvivalKKStratCoxPHOneLik | gradient | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.146 **FAIL** (level 0.1, cap) | 0.886 (level 0.9, cap) | 1000/1000 |  |  |
| survival | SeqOneByOne:Efron | SurvivalStratCoxPHRegr | rand | ~. | 200 | 200 (proxy) | Inf (theory) | 0.076 **FAIL** (level 0.05, finite) |  (level 0.95, finite) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:RandomBlockSize | SurvivalWeibullRegr | gradient | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.077 **FAIL** (level 0.05, rate check) | 0.926 (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.079 **FAIL** (level 0.05, rate check) | 0.921 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:RandomBlockSize | SurvivalWeibullRegr | lik_ratio | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.078 **FAIL** (level 0.05, rate check) | 0.922 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Blocking@0.2 | SurvivalWeibullRegr | score | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.1, cap) | 0.859 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| survival | Fixed:Optimal@0.2 | SurvivalWeibullRegr | score | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.853 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.094 **FAIL** (level 0.0625, rate) | 0.904 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| survival | SeqOneByOne:iBCRD | SurvivalWeibullRegr | score | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.09 **FAIL** (level 0.0625, rate) | 0.907 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.083 **FAIL** (level 0.05, rate check) | 0.917 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:RandomBlockSize | SurvivalWeibullRegr | score | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.078 **FAIL** (level 0.05, rate check) | 0.925 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Bernoulli | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.081 **FAIL** (level 0.05, rate check) | 0.919 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:iBCRD | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.08 **FAIL** (level 0.05, rate check) | 0.92 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.082 **FAIL** (level 0.05, rate check) | 0.918 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | Fixed:Rerandomization@0.2 | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.077 **FAIL** (level 0.05, rate check) | 0.923 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| survival | SeqOneByOne:RandomBlockSize | SurvivalWeibullRegr | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.078 **FAIL** (level 0.05, rate check) | 0.922 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |

### Null bias (reported, not gated)

10842 estimand cells; flagged (z-test at 0.01 / 10704 and |bias| / SD > 0.1): **105**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the campaign's largest n, 1000): **49** of 3614 cell(s) there; reported, not part of the gate.

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
| survival | Fixed:Greedy@0.2 | SurvivalStratCoxPHRegr | ~1 | 1000 | 0.0107 | 0.13 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~. | 1000 | 0.0179 | 0.12 |
| survival | SeqOneByOne:RandomBlockSize@0.2 | SurvivalRestrictedMeanDiff | ~1 | 1000 | 0.0179 | 0.12 |
| survival | Fixed:Greedy@0.2 | SurvivalLogRank | ~. | 1000 | 0.0068 | 0.12 |
| survival | Fixed:Greedy@0.2 | SurvivalLogRank | ~1 | 1000 | 0.0068 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | PropQuantileRegr | ~1 | 1000 | 0.0137 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | PropFractionalLogit | ~1 | 1000 | 0.00882 | 0.12 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleAverageDiff | ~. | 1000 | 0.00201 | 0.11 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleAverageDiff | ~1 | 1000 | 0.00201 | 0.11 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleMeanDiffPooledVar | ~. | 1000 | 0.00201 | 0.11 |
| proportion | SeqOneByOne:SPBR@0.2 | AllSimpleMeanDiffPooledVar | ~1 | 1000 | 0.00201 | 0.11 |
| proportion | SeqOneByOne:SPBR@0.2 | PropGCompMeanDiff | ~1 | 1000 | 0.00201 | 0.11 |
(30 shown of 49; all in `null_bias_summary.csv`.)

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
| incidence | SeqOneByOne:KK21 | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| incidence | SeqOneByOne:KK21 | IncidKKGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | ~1 | 50 | 0 | -0.0691 | -0.16 | 0.55 | 0.0% |

