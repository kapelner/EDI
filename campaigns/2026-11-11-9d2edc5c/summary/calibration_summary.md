## EDI calibration study, campaign 2026-11-11-9d2edc5c

Progress: 1144691 of 13345000 replicates (8%) after wave 12; 1077 of 19933 cells complete, 0 abandoned.

10338 null cells and 0 power cells have results; 18326 of the plan's 129978 tests (null size and coverage, coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate: Benjamini-Hochberg q < 0.05 over all 129978 tests of the plan on the screening replicates (a test enters with its p-value when its cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only "not flagged" is provisional) flags **245** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at 0.01 / 129978, fixed in advance, so a confirmed failure is final when it is made.

Confirmation so far: 0 confirmed failing, 218 pending, 0 could not be confirmed (counted as failing), 27 cleared. Failing null cells so far (provisional): **146**.

Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of 0.1 reached at n_eff = 50 (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n (`rate check`). Null cells by rule (size): cap 2428, finite 1602, mismatch 480, rate 3794, rate_check 132, unknown 1902.

242 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

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

### Null bias (reported, not gated)

4494 estimand cells; flagged (z-test at 0.01 / 4468 and |bias| / SD > 0.1): **72**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the campaign's largest n, 1000): **65** of 1470 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | null bias | bias / SD |
|---|---|---|---|---|---|---|
| continuous | Efron | ContinRobustRegr | ~. | 1000 | 0.00669 | 0.1 |
| incidence | KK14 | IncidKKGEE | ~. | 1000 | -0.0453 | -0.4 |
| incidence | KK14 | IncidProbitRegr | ~. | 1000 | -0.0273 | -0.39 |
| incidence | KK14 | IncidLogRegr | ~. | 1000 | -0.0447 | -0.39 |
| incidence | KK14 | IncidLogBinomial | ~1 | 1000 | -0.0177 | -0.39 |
| incidence | KK14 | IncidKKModifiedPoisson | ~1 | 1000 | -0.0177 | -0.39 |
| incidence | KK14 | IncidModifiedPoisson | ~1 | 1000 | -0.0177 | -0.39 |
| incidence | KK14 | IncidKKGCompRiskDiff | ~. | 1000 | -0.00917 | -0.39 |
| incidence | KK14 | IncidKKCondLogitOneLik | ~1 | 1000 | -0.0415 | -0.39 |
| incidence | KK14 | IncidKKCondLogitGLMMOneLik | ~1 | 1000 | -0.0415 | -0.39 |
| incidence | KK14 | IncidRiskDiff | ~. | 1000 | -0.00913 | -0.39 |
| incidence | KK14 | IncidKKGEE | ~1 | 1000 | -0.0352 | -0.38 |
| incidence | KK14 | IncidKKGCompRiskDiff | ~1 | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidMiettinenNurminenRiskDiff | ~. | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidMiettinenNurminenRiskDiff | ~1 | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidNewcombeRiskDiff | ~. | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidNewcombeRiskDiff | ~1 | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidRiskDiff | ~1 | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidWald | ~. | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidWald | ~1 | 1000 | -0.00879 | -0.38 |
| incidence | KK14 | IncidProbitRegr | ~1 | 1000 | -0.022 | -0.38 |
| incidence | KK14 | IncidLogRegr | ~1 | 1000 | -0.0352 | -0.38 |
| incidence | KK14 | IncidKKNewcombeRiskDiff | ~. | 1000 | -0.00861 | -0.37 |
| incidence | KK14 | IncidKKNewcombeRiskDiff | ~1 | 1000 | -0.00861 | -0.37 |
| incidence | KK14 | IncidKKGCompRiskRatio | ~. | 1000 | -0.0171 | -0.37 |
| incidence | KK14 | IncidKKGCompRiskRatio | ~1 | 1000 | -0.0165 | -0.37 |
| incidence | KK14 | IncidKKCondLogitOneLik | ~. | 1000 | -0.0438 | -0.36 |
| incidence | KK14 | IncidKKCondLogitGLMMOneLik | ~. | 1000 | -0.0438 | -0.36 |
| incidence | KK14 | IncidKKModifiedPoisson | ~. | 1000 | -0.0168 | -0.35 |
| incidence | KK14 | IncidModifiedPoisson | ~. | 1000 | -0.0168 | -0.35 |
(30 shown of 65; all in `null_bias_summary.csv`.)

| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |
|---|---|---|---|---|---|---|---|---|---|
| continuous | Efron | ContinRobustRegr | ~. | 1000 | 0 | 0.00669 | 0.1 | 0.46 | 0.0% |
| continuous | Optimal@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0991 | 0.25 | 0.33 | 0.0% |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0584 | 0.19 | 0.49 | 0.0% |
| continuous | iBCRD@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.087 | 0.18 | 0.32 | 0.0% |
| incidence | Efron | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0603 | 0.18 | 0.5 | 0.0% |
| incidence | PocockSimon | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.056 | 0.18 | 0.48 | 0.0% |
| incidence | Blocking@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0727 | -0.17 | 0.52 | 0.5% |
| incidence | PocockSimon | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0517 | 0.17 | 0.48 | 0.0% |
| continuous | GreedyDOptimal@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0676 | 0.17 | 0.36 | 0.0% |
| continuous | Greedy@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0676 | 0.17 | 0.36 | 0.0% |
| incidence | iBCRD | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0528 | 0.17 | 0.49 | 0.0% |
| incidence | Efron | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0499 | 0.16 | 0.49 | 0.0% |
| continuous | Rerandomization@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0797 | 0.16 | 0.36 | 0.0% |
| incidence | KK21 | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| incidence | KK21 | IncidKKGCompRiskRatio | ~1 | 50 | 1 | 0.0475 | 0.16 | 0.49 | 0.0% |
| incidence | Blocking | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0461 | 0.15 | 0.49 | 0.0% |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~. | 52 | 1 | 0.0407 | 0.15 | 0.5 | 0.0% |
| incidence | KK21 | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0427 | 0.15 | 0.49 | 0.0% |
| incidence | KK21 | IncidKKGCompRiskRatio | ~. | 50 | 1 | 0.0427 | 0.15 | 0.49 | 0.0% |
| incidence | Bernoulli@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0606 | -0.15 | 0.52 | 0.9% |
| incidence | BinaryMatch | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0431 | 0.14 | 0.5 | 0.0% |
| incidence | BinaryMatch | IncidKKGCompRiskRatio | ~1 | 50 | 1 | 0.0431 | 0.14 | 0.5 | 0.0% |
| incidence | Blocking | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0458 | 0.14 | 0.52 | 0.0% |
| incidence | Urn | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0434 | 0.14 | 0.49 | 0.0% |
| incidence | iBCRD | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0433 | 0.14 | 0.5 | 0.0% |
| incidence | BinaryMatch | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0425 | 0.14 | 0.49 | 0.0% |
| incidence | BinaryMatch | IncidKKGCompRiskRatio | ~. | 50 | 1 | 0.0425 | 0.14 | 0.49 | 0.0% |
| incidence | MatchingGreedyPairSwitching | IncidGCompRiskRatio | ~1 | 52 | 1 | 0.0388 | 0.14 | 0.5 | 0.0% |
| incidence | Bernoulli | IncidGCompRiskRatio | ~. | 50 | 1 | 0.042 | 0.14 | 0.5 | 0.0% |
| continuous | iBCRD@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0654 | 0.14 | 0.36 | 0.0% |
| incidence | Rerandomization@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0537 | -0.14 | 0.51 | 0.1% |
| incidence | iBCRD | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0407 | 0.14 | 0.51 | 0.0% |
| incidence | OptimalBlocks@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0522 | -0.14 | 0.52 | 0.4% |
| incidence | Urn | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0439 | 0.14 | 0.49 | 0.0% |
| incidence | Rerandomization@0.2 | IncidModifiedPoisson | ~1 | 50 | 0 | -0.0529 | -0.14 | 0.51 | 0.0% |
| incidence | iBCRD | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0427 | 0.14 | 0.5 | 0.0% |
| incidence | OptimalBlocks | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.043 | 0.14 | 0.5 | 0.0% |
| incidence | Greedy | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0399 | 0.13 | 0.51 | 0.0% |
| incidence | GreedyDOptimal | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0399 | 0.13 | 0.51 | 0.0% |
| incidence | OptimalBlocks | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0413 | 0.13 | 0.5 | 0.0% |
| incidence | Greedy | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0403 | 0.13 | 0.51 | 0.0% |
| incidence | GreedyDOptimal | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0403 | 0.13 | 0.51 | 0.0% |
| incidence | Bernoulli@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0506 | -0.13 | 0.52 | 0.8% |
| incidence | KK21stepwise | IncidGCompRiskRatio | ~. | 200 | 1 | 0.017 | 0.13 | 0.5 | 0.0% |
| incidence | KK21stepwise | IncidKKGCompRiskRatio | ~. | 200 | 1 | 0.017 | 0.13 | 0.5 | 0.0% |
| incidence | KK21stepwise | IncidGCompRiskRatio | ~1 | 200 | 1 | 0.0172 | 0.12 | 0.49 | 0.0% |
| incidence | KK21stepwise | IncidKKGCompRiskRatio | ~1 | 200 | 1 | 0.0172 | 0.12 | 0.49 | 0.0% |
| continuous | RandomBlockSize@0.2 | ContinQuantileRegr | ~1 | 50 | 0 | 0.0682 | 0.12 | 0.41 | 0.0% |
| incidence | Bernoulli | IncidGCompRiskRatio | ~1 | 200 | 1 | 0.0169 | 0.12 | 0.47 | 0.0% |
| incidence | KK14 | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0362 | 0.12 | 0.51 | 0.0% |
| incidence | KK14 | IncidKKGCompRiskRatio | ~1 | 50 | 1 | 0.0362 | 0.12 | 0.51 | 0.0% |
| incidence | SPBR | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0369 | 0.12 | 0.51 | 0.0% |
| incidence | Optimal | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0352 | 0.12 | 0.52 | 0.0% |
| incidence | Blocking@0.2 | IncidModifiedPoisson | ~1 | 50 | 0 | -0.153 | -0.11 | 0.53 | 0.0% |
| incidence | GreedyDOptimal | IncidGCompRiskRatio | ~. | 200 | 1 | 0.0151 | 0.11 | 0.49 | 0.0% |
| incidence | Atkinson | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0334 | 0.11 | 0.5 | 0.0% |
| incidence | Optimal | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.034 | 0.11 | 0.54 | 0.0% |
| incidence | Optimal@0.2 | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0362 | 0.11 | 0.48 | 0.0% |
| incidence | Rerandomization | IncidGCompRiskRatio | ~. | 50 | 1 | 0.034 | 0.11 | 0.51 | 0.0% |
| incidence | RandomBlockSize | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0334 | 0.11 | 0.53 | 0.0% |
| incidence | Bernoulli | IncidGCompRiskRatio | ~. | 200 | 1 | 0.0139 | 0.11 | 0.48 | 0.0% |
| incidence | RandomBlockSize | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0331 | 0.11 | 0.52 | 0.0% |
| incidence | iBCRD@0.2 | IncidLogBinomial | ~1 | 50 | 0 | -0.0422 | -0.11 | 0.49 | 0.4% |
| incidence | KK14 | IncidGCompRiskRatio | ~. | 200 | 1 | 0.0138 | 0.11 | 0.47 | 0.0% |
| incidence | KK14 | IncidKKGCompRiskRatio | ~. | 200 | 1 | 0.0138 | 0.11 | 0.47 | 0.0% |
| incidence | Atkinson | IncidGCompRiskRatio | ~1 | 50 | 1 | 0.0309 | 0.11 | 0.51 | 0.0% |
| incidence | GreedyDOptimal | IncidGCompRiskRatio | ~1 | 200 | 1 | 0.014 | 0.1 | 0.49 | 0.0% |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | ~. | 50 | 0 | -0.219 | -0.1 | 0.53 | 0.2% |
| incidence | SPBR | IncidGCompRiskRatio | ~. | 50 | 1 | 0.0307 | 0.1 | 0.52 | 0.0% |
| incidence | Efron | IncidGCompRiskRatio | ~. | 200 | 1 | 0.0135 | 0.1 | 0.49 | 0.0% |
| incidence | KK14 | IncidGCompRiskRatio | ~1 | 200 | 1 | 0.0136 | 0.1 | 0.49 | 0.0% |
| incidence | KK14 | IncidKKGCompRiskRatio | ~1 | 200 | 1 | 0.0136 | 0.1 | 0.49 | 0.0% |

