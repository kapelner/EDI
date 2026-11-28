[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Null bias

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
(30 shown of 57; all in [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv).)

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



[← Campaign 2026-11-09-8c32d060 summary](README.md)
