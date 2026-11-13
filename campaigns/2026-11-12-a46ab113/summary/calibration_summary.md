## EDI calibration study, campaign 2026-11-12-a46ab113

Progress: 2314983 of 13330000 replicates (17%) after wave 2; 2216 of 19930 cells complete, 0 abandoned.

10696 null cells and 0 power cells have results; 18716 of the plan's 129978 tests (null size and coverage, coverage of the true estimand at the power effects) have a p-value from a completed cell. Two-stage gate: Benjamini-Hochberg q < 0.05 over all 129978 tests of the plan on the screening replicates (a test enters with its p-value when its cell's screening replicates are all in and counts as p = 1 until then, so a flag is never withdrawn; only "not flagged" is provisional) flags **57** test(s); each flagged test is re-run on fresh replicates and fails only if those alone reject at 0.01 / 129978, fixed in advance, so a confirmed failure is final when it is made.

Confirmation so far: 24 confirmed failing, 33 pending, 0 could not be confirmed (counted as failing), 0 cleared. Failing null cells so far (provisional): **34**.

Levels (TODO-200): finite-sample procedures 0.05 / 0.95; asymptotic ones 0.05 + c n_eff^-a up to a cap of 0.1 reached at n_eff = 50 (a = the registry's expected order; rule `rate` below the cap, `cap` at it); unknown order: the cap below the campaign's largest n; a `slower` convergence verdict is held to the nominal level at the cell's largest n (`rate check`). Null cells by rule (size): cap 2448, finite 1728, mismatch 590, rate 4015, rate_check 13, unknown 1902.

304 design-mismatch null cell(s) are conservative (expected: model SE ignores the design); reported, never failed.

| response | design | class | procedure | formula | n | n_eff | order (basis) | size | coverage | finite | accepted | note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.17 **FAIL** (level 0.1, cap) | 0.83 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| continuous | Bernoulli@0.2 | ContinLin | wald | ~. | 50 | 10 | 1 (assumed_default) | 0.192 **FAIL** (level 0.1, cap) | 0.808 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.144 **FAIL** (level 0.1, unknown) | 0.856 **FAIL** (level 0.9, unknown) | 991/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.159 **FAIL** (level 0.1, unknown) | 0.841 **FAIL** (level 0.9, unknown) | 995/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli@0.2 | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | 50 (proxy) | unknown | 0.143 **FAIL** (level 0.1, unknown) | 0.857 **FAIL** (level 0.9, unknown) | 992/1000 |  | rate unknown: open a TODO to establish it |
| incidence | KK21stepwise | IncidExactZhang | exact | ~. | 1000 | 1000 (proxy) | Inf (theory) | 0.032 (level 0.05, finite) | 0.848 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | 1000 (proxy) | Inf (theory) | 0.032 (level 0.05, finite) | 0.848 **FAIL** (level 0.95, finite) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | 50 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.1, cap) | 0.85 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | 50 (proxy) | 1 (assumed_default) | 0.178 **FAIL** (level 0.1, cap) | 0.822 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.142 **FAIL** (level 0.0625, rate) | 0.858 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | 200 (proxy) | 1 (assumed_default) | 0.141 **FAIL** (level 0.0625, rate) | 0.859 **FAIL** (level 0.938, rate) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.15 **FAIL** (level 0.05, rate check) | 0.85 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | 1000 (proxy) | 1 (assumed_default) | 0.133 **FAIL** (level 0.05, rate check) | 0.867 **FAIL** (level 0.95, rate check) | 1000/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.188 **FAIL** (level 0.1, cap) | 1 (level 0.9, cap) | 650/1000 |  |  |
| incidence | KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.198 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 723/1000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.18 **FAIL** (level 0.1, cap) | 0.991 (level 0.9, cap) | 727/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.287 **FAIL** (level 0.1, cap) | 0.888 (level 0.9, cap) | 491/1000 |  |  |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.145 **FAIL** (level 0.1, cap) | 0.939 (level 0.9, cap) | 981/1000 |  |  |
| incidence | KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.149 **FAIL** (level 0.1, cap) | 0.913 (level 0.9, cap) | 942/1000 |  |  |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.147 **FAIL** (level 0.1, cap) | 0.919 (level 0.9, cap) | 956/1000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | 25 (proxy) | 1 (assumed_default) | 0.159 **FAIL** (level 0.1, cap) | 0.841 **FAIL** (level 0.9, cap) | 1000/1000 |  |  |
| incidence | Blocking@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.153 **FAIL** (level 0.1, unknown) | 0.867 (level 0.9, unknown) | 957/1000 |  | rate unknown: open a TODO to establish it |
| incidence | SPBR@0.2 | IncidLogBinomial | score | ~. | 50 | 50 (proxy) | unknown | 0.148 **FAIL** (level 0.1, unknown) | 0.87 (level 0.9, unknown) | 978/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Blocking@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0884 **FAIL** (level 0.0525, unknown) | 0.914 **FAIL** (level 0.948, unknown) | 996/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Rerandomization@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0906 **FAIL** (level 0.0525, unknown) | 0.911 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0865 **FAIL** (level 0.0525, unknown) | 0.915 **FAIL** (level 0.948, unknown) | 997/1000 |  | rate unknown: open a TODO to establish it |
| incidence | iBCRD@0.2 | IncidLogBinomial | score | ~. | 1000 | 1000 (proxy) | unknown | 0.0855 **FAIL** (level 0.0525, unknown) | 0.916 **FAIL** (level 0.948, unknown) | 998/1000 |  | rate unknown: open a TODO to establish it |

### Null bias (reported, not gated)

4678 estimand cells; flagged (z-test at 0.01 / 4644 and |bias| / SD > 0.1): **15**.

`bias_sd_large_n` (|bias| / SD > 0.1 at the campaign's largest n, 1000): **26** of 1546 cell(s) there; reported, not part of the gate.

| response | design | class | formula | n | null bias | bias / SD |
|---|---|---|---|---|---|---|
| incidence | Urn | IncidBinomialIdentityRiskDiff | ~1 | 1000 | 0.00709 | 0.29 |
| incidence | Urn | AllSimpleAverageDiff | ~. | 1000 | 0.00709 | 0.29 |
| incidence | Urn | AllSimpleAverageDiff | ~1 | 1000 | 0.00709 | 0.29 |
| incidence | Urn | AllSimpleMeanDiffPooledVar | ~. | 1000 | 0.00709 | 0.29 |
| incidence | Urn | AllSimpleMeanDiffPooledVar | ~1 | 1000 | 0.00709 | 0.29 |
| incidence | Urn | IncidCMH | ~1 | 1000 | 0.00709 | 0.29 |
| incidence | Urn | IncidBinomialIdentityRiskDiff | ~. | 1000 | 0.00687 | 0.29 |
| incidence | Urn | IncidCMH | ~. | 1000 | -0.00557 | -0.18 |
| incidence | Urn | IncidLogBinomial | ~1 | 1000 | -0.00782 | -0.14 |
| incidence | Urn | IncidModifiedPoisson | ~1 | 1000 | -0.00782 | -0.14 |
| incidence | Urn | IncidLogRegr | ~1 | 1000 | -0.0157 | -0.13 |
| incidence | Urn | IncidProbitRegr | ~1 | 1000 | -0.00984 | -0.13 |
| incidence | Urn | IncidGCompRiskDiff | ~1 | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidMiettinenNurminenRiskDiff | ~. | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidMiettinenNurminenRiskDiff | ~1 | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidNewcombeRiskDiff | ~. | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidNewcombeRiskDiff | ~1 | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidRiskDiff | ~1 | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidWald | ~. | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidWald | ~1 | 1000 | -0.00392 | -0.13 |
| incidence | Urn | IncidGCompRiskRatio | ~1 | 1000 | -0.00616 | -0.11 |
| incidence | Rerandomization@0.2 | IncidModifiedPoisson | ~. | 1000 | -0.00784 | -0.11 |
| continuous | Efron | ContinQuantileRegr | ~. | 1000 | 0.00829 | 0.1 |
| continuous | Efron | ContinRobustRegr | ~. | 1000 | 0.00669 | 0.1 |
| incidence | Rerandomization@0.2 | IncidModifiedPoisson | ~1 | 1000 | -0.00798 | -0.1 |
| incidence | Rerandomization@0.2 | IncidLogBinomial | ~1 | 1000 | -0.00798 | -0.1 |

| response | design | class | formula | n | null value | null bias | bias / SD | share below null | non-finite |
|---|---|---|---|---|---|---|---|---|---|
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

