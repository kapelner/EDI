[← Campaign 2026-11-11-9d2edc5c summary](README.md)

# Null bias

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
(30 shown of 65; all in [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv).)

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

[← Campaign 2026-11-11-9d2edc5c summary](README.md)
