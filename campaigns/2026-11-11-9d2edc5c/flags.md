[← Campaign 2026-11-11-9d2edc5c summary](README.md)

# Screen flags and confirmation verdicts

245 test(s) flagged at the screen (Benjamini-Hochberg q < 0.05): 27 cleared by confirmation, 218 flagged, confirmation pending.

By the rule that set the level: cap 31, finite 77, mismatch 4, rate 22, rate_check 38, unknown 73.

The 245 most significant (all rows: [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv)).

| response | design | class | procedure | formula | n | effect | metric | level | rule | q | confirmation | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | size | 0.05 | rate_check | 2.78e-119 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 2.78e-119 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 2.78e-119 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.78e-119 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | null | size |  0.1 | cap | 1.86e-86 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | null | size | 0.05 | rate_check | 1.86e-86 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 1.86e-86 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 1.86e-86 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.86e-86 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | null | size | 0.0625 | rate | 1.31e-68 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | null | size | 0.0625 | rate | 1.31e-68 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | null | coverage | 0.938 | rate | 1.31e-68 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | null | coverage | 0.938 | rate | 1.31e-68 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | null | size | 0.0625 | rate | 3.77e-67 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | null | size | 0.0625 | rate | 3.77e-67 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | null | coverage | 0.938 | rate | 3.77e-67 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | null | coverage | 0.938 | rate | 3.77e-67 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | null | size |  0.1 | cap | 2.96e-47 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | null | size |  0.1 | cap | 2.96e-47 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | null | coverage |  0.9 | cap | 2.96e-47 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | null | coverage |  0.9 | cap | 2.96e-47 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidExactZhang | exact | ~. | 1000 | null | coverage | 0.95 | finite | 4.8e-47 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | null | coverage | 0.95 | finite | 4.8e-47 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 1.49e-38 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | size |  0.1 | cap | 2.01e-38 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | coverage |  0.9 | cap | 2.01e-38 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 7.17e-38 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | size |  0.1 | cap | 1.48e-31 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | coverage |  0.9 | cap | 1.48e-31 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidExactZhang | exact | ~. | 1000 | null | coverage | 0.95 | finite | 1.87e-29 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidExactZhang | exact | ~1 | 1000 | null | coverage | 0.95 | finite | 1.87e-29 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 1.67e-26 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | size |  0.1 | cap | 2.92e-20 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | size |  0.1 | cap | 2.92e-20 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | cap | 2.92e-20 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | coverage |  0.9 | cap | 2.92e-20 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | null | size |  0.1 | cap | 8.55e-20 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | null | size |  0.1 | cap | 8.55e-20 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | null | coverage |  0.9 | cap | 8.55e-20 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | null | coverage |  0.9 | cap | 8.55e-20 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 1.88e-15 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 2.04e-15 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.34e-14 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinQuantileRegr | wald | ~. | 1000 | null | size | 0.05 | rate_check | 3.36e-13 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinQuantileRegr | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 3.36e-13 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 7.29e-13 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 7.29e-13 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 7.44e-13 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 8.71e-13 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 9.35e-13 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 2.22e-12 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | rand | ~1 | 1000 | null | size | 0.05 | finite | 3.34e-11 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 4.01e-11 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 4.01e-11 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | score | ~1 | 1000 | null | size | 0.05 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.61e-10 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinOLS | rand | ~1 | 1000 | null | size | 0.05 | finite | 6.77e-10 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 9.12e-10 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 1.2e-09 | pending | flagged, confirmation pending |
| incidence | Efron | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 1.49e-09 | pending | flagged, confirmation pending |
| continuous | KK21 | ContinKKGLMM | rand | ~. | 50 | null | size | 0.05 | finite | 1.62e-09 | 0.0482 over 5000 | cleared by confirmation |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.02e-09 | pending | flagged, confirmation pending |
| incidence | Efron | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.02e-09 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 4.54e-09 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinRobustRegr | rand | ~. | 200 | null | size | 0.05 | finite | 4.99e-09 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 6.74e-09 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 7.07e-09 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 9.77e-09 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | rand | ~1 | 1000 | null | size | 0.05 | finite | 1.29e-08 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 1.88e-08 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 2.89e-08 | pending | flagged, confirmation pending |
| incidence | Optimal | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 4.12e-08 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | rand | ~1 | 1000 | null | size | 0.05 | finite | 5.04e-08 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 5.2e-08 | pending | flagged, confirmation pending |
| continuous | KK14 | ContinKKRobustRegrOneLik | wald | ~. | 50 | null | size |  0.1 | unknown | 6.04e-08 | pending | flagged, confirmation pending |
| continuous | KK14 | ContinKKRobustRegrOneLik | wald | ~. | 50 | null | coverage |  0.9 | unknown | 6.04e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | score | ~1 | 1000 | null | size | 0.05 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | KK21 | ContinOLS | rand | ~. | 50 | null | size | 0.05 | finite | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 6.3e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | wald | ~1 | 1000 | null | size | 0.0525 | rate | 6.58e-08 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinOLS | wald | ~1 | 1000 | null | coverage | 0.948 | rate | 6.58e-08 | pending | flagged, confirmation pending |
| continuous | SPBR | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 1.25e-07 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 1.32e-07 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.21e-07 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 3.63e-07 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.63e-07 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 3.84e-07 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 3.93e-07 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 4.31e-07 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 8.74e-07 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 9.68e-07 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 1.03e-06 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 1.03e-06 | pending | flagged, confirmation pending |
| incidence | Optimal | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 1.09e-06 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinOLS | rand | ~1 | 1000 | null | size | 0.05 | finite | 1.13e-06 | pending | flagged, confirmation pending |
| continuous | KK21 | ContinLin | rand | ~. | 50 | null | size | 0.05 | finite | 1.21e-06 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 2.16e-06 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 2.47e-06 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.49e-06 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 2.49e-06 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 3.35e-06 | pending | flagged, confirmation pending |
| continuous | KK14 | ContinKKGLMM | rand | ~. | 50 | null | size | 0.05 | finite | 4e-06 | 0.0578 over 5000 | cleared by confirmation |
| incidence | iBCRD | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 4.18e-06 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 4.18e-06 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidGCompRiskDiff | wald | ~. | 50 | null | size |  0.1 | cap | 4.51e-06 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidGCompRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | cap | 4.51e-06 | pending | flagged, confirmation pending |
| continuous | KK21stepwise | ContinKKGLMM | rand | ~1 | 50 | null | size | 0.05 | finite | 5.04e-06 | 0.0568 over 5000 | cleared by confirmation |
| continuous | Rerandomization | ContinLin | wald | ~1 | 1000 | null | size | 0.0525 | rate | 5.14e-06 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinLin | wald | ~1 | 1000 | null | coverage | 0.948 | rate | 5.14e-06 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinLin | rand | ~. | 200 | null | size | 0.05 | finite | 5.66e-06 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinOLS | rand | ~. | 200 | null | size | 0.05 | finite | 1.75e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | gradient | ~. | 1000 | null | size | 0.05 | rate_check | 1.99e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 1000 | null | coverage | 0.95 | rate_check | 1.99e-05 | pending | flagged, confirmation pending |
| continuous | Greedy | ContinRobustRegr | rand | ~. | 50 | null | size | 0.05 | finite | 2.01e-05 | pending | flagged, confirmation pending |
| continuous | GreedyDOptimal | ContinRobustRegr | rand | ~. | 50 | null | size | 0.05 | finite | 2.01e-05 | pending | flagged, confirmation pending |
| continuous | MatchingGreedyPairSwitching | ContinRobustRegr | rand | ~. | 52 | null | size | 0.05 | finite | 2.01e-05 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinLin | rand | ~1 | 1000 | null | size | 0.05 | finite | 4.59e-05 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 6.16e-05 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 6.16e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | lik_ratio | ~. | 1000 | null | size | 0.05 | rate_check | 7.84e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | score | ~. | 1000 | null | size | 0.05 | rate_check | 7.84e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | lik_ratio | ~. | 1000 | null | coverage | 0.95 | rate_check | 7.84e-05 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | score | ~. | 1000 | null | coverage | 0.95 | rate_check | 7.84e-05 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinOLS | rand | ~1 | 200 | null | size | 0.05 | finite | 8.06e-05 | pending | flagged, confirmation pending |
| continuous | BinaryMatch | ContinKKRobustRegrOneLik | rand | ~1 | 200 | null | size | 0.05 | finite | 8.06e-05 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinLin | rand | ~1 | 200 | null | size | 0.05 | finite | 0.000109 | pending | flagged, confirmation pending |
| incidence | Efron | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.000112 | pending | flagged, confirmation pending |
| incidence | Optimal | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.000131 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinQuantileRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.000172 | pending | flagged, confirmation pending |
| incidence | PocockSimon | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.00021 | pending | flagged, confirmation pending |
| incidence | RandomBlockSize | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.000283 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.000298 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinLin | rand | ~. | 200 | null | size | 0.05 | finite | 0.000338 | pending | flagged, confirmation pending |
| incidence | RandomBlockSize | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.000351 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 0.000552 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 0.000552 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.000562 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.000626 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.000738 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinQuantileRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.000853 | pending | flagged, confirmation pending |
| continuous | Bernoulli | AllSimpleMeanDiffPooledVar | rand | ~. | 1000 | null | size | 0.05 | finite | 0.00088 | 0.0518 over 5000 | cleared by confirmation |
| continuous | Bernoulli | AllSimpleMeanDiffPooledVar | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.00088 | 0.0518 over 5000 | cleared by confirmation |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | size |  0.1 | cap | 0.000939 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | size |  0.1 | cap | 0.000939 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | cap | 0.000939 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | coverage |  0.9 | cap | 0.000939 | pending | flagged, confirmation pending |
| incidence | PocockSimon | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.000957 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.00108 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinLin | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0012 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinRobustRegr | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.00141 | pending | flagged, confirmation pending |
| continuous | MatchingGreedyPairSwitching | ContinOLS | rand | ~. | 200 | null | size | 0.05 | finite | 0.00142 | pending | flagged, confirmation pending |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | rand | ~. | 1000 | null | size | 0.05 | finite | 0.00195 | 0.0564 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.00195 | 0.0564 over 5000 | cleared by confirmation |
| incidence | Blocking | IncidLogBinomial | score | ~. | 50 | null | coverage |  0.9 | unknown | 0.00208 | pending | flagged, confirmation pending |
| incidence | KK14 | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.00253 | pending | flagged, confirmation pending |
| continuous | SPBR | AllSimpleWilcox | rand | ~. | 200 | null | size | 0.05 | finite | 0.00267 | 0.0504 over 5000 | cleared by confirmation |
| continuous | SPBR | AllSimpleWilcox | rand | ~1 | 200 | null | size | 0.05 | finite | 0.00267 | 0.0504 over 5000 | cleared by confirmation |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.00305 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | lik_ratio | ~. | 1000 | null | size | 0.0525 | unknown | 0.00326 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | lik_ratio | ~. | 1000 | null | size | 0.0525 | unknown | 0.00326 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | lik_ratio | ~. | 1000 | null | coverage | 0.948 | unknown | 0.00326 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | lik_ratio | ~. | 1000 | null | coverage | 0.948 | unknown | 0.00326 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.00356 | pending | flagged, confirmation pending |
| continuous | PocockSimon | ContinRobustRegr | rand | ~1 | 50 | null | size | 0.05 | finite | 0.00356 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinQuantileRegr | wald | ~. | 1000 | null | size | 0.05 | rate_check | 0.00406 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinQuantileRegr | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 0.00406 | pending | flagged, confirmation pending |
| continuous | KK21 | ContinRobustRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.00476 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidLogBinomial | score | ~. | 52 | null | size |  0.1 | unknown | 0.00576 | pending | flagged, confirmation pending |
| incidence | Optimal | IncidLogBinomial | score | ~. | 50 | null | coverage |  0.9 | unknown | 0.00617 | pending | flagged, confirmation pending |
| continuous | iBCRD | AllSimpleWilcox | rand | ~. | 200 | null | size | 0.05 | finite | 0.00696 | 0.0488 over 5000 | cleared by confirmation |
| continuous | iBCRD | AllSimpleWilcox | rand | ~1 | 200 | null | size | 0.05 | finite | 0.00696 | 0.0488 over 5000 | cleared by confirmation |
| continuous | iBCRD | ContinRobustRegr | rand | ~. | 200 | null | size | 0.05 | finite | 0.00696 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | lik_ratio | ~. | 1000 | null | size | 0.0525 | unknown | 0.00868 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | lik_ratio | ~. | 1000 | null | coverage | 0.948 | unknown | 0.00868 | pending | flagged, confirmation pending |
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~. | 200 | null | size | 0.05 | finite | 0.00872 | 0.0516 over 5000 | cleared by confirmation |
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~1 | 200 | null | size | 0.05 | finite | 0.00872 | 0.0516 over 5000 | cleared by confirmation |
| continuous | iBCRD | ContinOLS | rand | ~1 | 200 | null | size | 0.05 | finite | 0.00872 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidLogBinomial | score | ~. | 50 | null | coverage |  0.9 | unknown | 0.0092 | pending | flagged, confirmation pending |
| continuous | Bernoulli | AllSimpleWilcox | rand | ~. | 1000 | null | size | 0.05 | finite | 0.0102 | 0.0524 over 5000 | cleared by confirmation |
| continuous | Bernoulli | AllSimpleWilcox | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.0102 | 0.0524 over 5000 | cleared by confirmation |
| incidence | Rerandomization | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 0.0115 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 0.0115 | pending | flagged, confirmation pending |
| continuous | OptimalBlocks | ContinQuantileRegr | wald | ~. | 1000 | null | size | 0.05 | rate_check | 0.012 | pending | flagged, confirmation pending |
| continuous | OptimalBlocks | ContinQuantileRegr | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 0.012 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinQuantileRegr | rand | ~. | 200 | null | size | 0.05 | finite | 0.0139 | pending | flagged, confirmation pending |
| continuous | PocockSimon | ContinRobustRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0139 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.0151 | pending | flagged, confirmation pending |
| continuous | MatchingGreedyPairSwitching | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0156 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.0156 | pending | flagged, confirmation pending |
| continuous | BinaryMatch | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0168 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidGCompRiskDiff | wald | ~. | 50 | null | size |  0.1 | cap | 0.0168 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidGCompRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | cap | 0.0168 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinRobustRegr | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.0169 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinRobustRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0169 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinQuantileRegr | wald | ~. | 1000 | null | size | 0.05 | rate_check | 0.0175 | pending | flagged, confirmation pending |
| continuous | Rerandomization | ContinQuantileRegr | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 0.0175 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 1000 | null | size | 0.055 | rate | 0.0185 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | gradient | ~. | 1000 | null | coverage | 0.945 | rate | 0.0185 | pending | flagged, confirmation pending |
| continuous | Rerandomization | AllSimpleWilcox | rand | ~. | 1000 | null | size | 0.05 | finite | 0.0198 | 0.0558 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleWilcox | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.0198 | 0.0558 over 5000 | cleared by confirmation |
| incidence | BinaryMatch | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.02 | pending | flagged, confirmation pending |
| continuous | Rerandomization | AllSimpleWilcox | wald | ~. | 1000 | null | size | 0.0525 | rate | 0.0207 | 0.0534 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleWilcox | wald | ~1 | 1000 | null | size | 0.0525 | rate | 0.0207 | 0.0534 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleWilcox | wald | ~. | 1000 | null | coverage | 0.948 | rate | 0.0207 | 0.947 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleWilcox | wald | ~1 | 1000 | null | coverage | 0.948 | rate | 0.0207 | 0.947 over 5000 | cleared by confirmation |
| continuous | OptimalBlocks | ContinQuantileRegr | rand | ~. | 1000 | null | size | 0.05 | finite | 0.0223 | pending | flagged, confirmation pending |
| continuous | MatchingGreedyPairSwitching | ContinLin | rand | ~. | 200 | null | size | 0.05 | finite | 0.0316 | pending | flagged, confirmation pending |
| continuous | PocockSimon | ContinLin | rand | ~. | 50 | null | size | 0.05 | finite | 0.0316 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 50 | null | coverage |  0.9 | unknown | 0.0322 | pending | flagged, confirmation pending |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | wald | ~. | 1000 | null | size | 0.0525 | mismatch | 0.0326 | 0.0554 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | wald | ~1 | 1000 | null | size | 0.0525 | mismatch | 0.0326 | 0.0554 over 5000 | cleared by confirmation |
| continuous | KK21 | ContinQuantileRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0326 | pending | flagged, confirmation pending |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | wald | ~. | 1000 | null | coverage | 0.948 | mismatch | 0.0326 | 0.945 over 5000 | cleared by confirmation |
| continuous | Rerandomization | AllSimpleMeanDiffPooledVar | wald | ~1 | 1000 | null | coverage | 0.948 | mismatch | 0.0326 | 0.945 over 5000 | cleared by confirmation |
| continuous | iBCRD | ContinOLS | rand | ~. | 200 | null | size | 0.05 | finite | 0.0342 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidGCompRiskDiff | wald | ~. | 1000 | null | size | 0.05 | rate_check | 0.0342 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidGCompRiskDiff | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 0.0342 | pending | flagged, confirmation pending |
| continuous | BinaryMatch | ContinKKOLSOneLik | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0342 | 0.0459 over 4942 | flagged, confirmation pending |
| continuous | iBCRD | AllSimpleWilcox | rand | ~. | 1000 | null | size | 0.05 | finite | 0.038 | 0.052 over 5000 | cleared by confirmation |
| continuous | iBCRD | AllSimpleWilcox | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.038 | 0.052 over 5000 | cleared by confirmation |
| continuous | iBCRD | ContinRobustRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0387 | pending | flagged, confirmation pending |
| continuous | KK21stepwise | ContinQuantileRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0402 | pending | flagged, confirmation pending |
| continuous | KK21 | ContinQuantileRegr | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.0424 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.0447 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinQuantileRegr | rand | ~. | 200 | null | size | 0.05 | finite | 0.0459 | pending | flagged, confirmation pending |
| continuous | OptimalBlocks | ContinQuantileRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0459 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinQuantileRegr | rand | ~. | 50 | null | size | 0.05 | finite | 0.0459 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 1000 | null | size | 0.055 | rate | 0.0461 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 1000 | null | size | 0.055 | rate | 0.0461 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 1000 | null | coverage | 0.945 | rate | 0.0461 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 1000 | null | coverage | 0.945 | rate | 0.0461 | pending | flagged, confirmation pending |
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~. | 1000 | null | size | 0.05 | finite | 0.0461 | pending | flagged, confirmation pending |
| continuous | iBCRD | AllSimpleMeanDiffPooledVar | rand | ~1 | 1000 | null | size | 0.05 | finite | 0.0461 | pending | flagged, confirmation pending |
| continuous | Blocking | ContinOLS | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0492 | pending | flagged, confirmation pending |
| continuous | MatchingGreedyPairSwitching | ContinOLS | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0492 | pending | flagged, confirmation pending |
| continuous | iBCRD | ContinOLS | rand | ~. | 200 | null | size | 0.05 | finite | 0.0492 | pending | flagged, confirmation pending |
| continuous | SPBR | ContinQuantileRegr | rand | ~1 | 200 | null | size | 0.05 | finite | 0.0492 | pending | flagged, confirmation pending |

[← Campaign 2026-11-11-9d2edc5c summary](README.md)
