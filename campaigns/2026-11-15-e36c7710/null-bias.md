[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Null bias

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
(30 shown of 49; all in [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv).)

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

[← Campaign 2026-11-15-e36c7710 summary](README.md)
