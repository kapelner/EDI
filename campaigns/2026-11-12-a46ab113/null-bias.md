[← Campaign 2026-11-12-a46ab113 summary](README.md)

# Null bias

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

[← Campaign 2026-11-12-a46ab113 summary](README.md)
