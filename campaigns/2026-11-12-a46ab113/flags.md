[← Campaign 2026-11-12-a46ab113 summary](README.md)

# Screen flags and confirmation verdicts

57 test(s) flagged at the screen (Benjamini-Hochberg q < 0.05): 24 fail (confirmed), 33 flagged, confirmation pending.

By the rule that set the level: cap 23, finite 2, rate 8, rate_check 8, unknown 16.

The 57 most significant (all rows: [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv)).

| response | design | class | procedure | formula | n | effect | metric | level | rule | q | confirmation | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | size | 0.05 | rate_check | 3.36e-28 | 0.146 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 3.36e-28 | 0.146 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 3.36e-28 | 0.854 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.36e-28 | 0.854 over 5000 | fail (confirmed) |
| incidence | KK21stepwise | IncidExactZhang | exact | ~. | 1000 | null | coverage | 0.95 | finite | 3.36e-28 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | null | coverage | 0.95 | finite | 3.36e-28 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | score | ~. | 50 | null | size |  0.1 | cap | 3.68e-20 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | null | size | 0.05 | rate_check | 5.45e-20 | 0.145 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 5.45e-20 | 0.145 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 5.45e-20 | 0.855 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 5.45e-20 | 0.855 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | null | size | 0.0625 | rate | 1.33e-15 | 0.142 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | null | size | 0.0625 | rate | 1.33e-15 | 0.142 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 200 | null | coverage | 0.938 | rate | 1.33e-15 | 0.858 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 200 | null | coverage | 0.938 | rate | 1.33e-15 | 0.858 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | null | size | 0.0625 | rate | 2.63e-15 | 0.149 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | null | size | 0.0625 | rate | 2.63e-15 | 0.149 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 200 | null | coverage | 0.938 | rate | 2.63e-15 | 0.851 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 200 | null | coverage | 0.938 | rate | 2.63e-15 | 0.851 over 5000 | fail (confirmed) |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | size |  0.1 | cap | 1.03e-14 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | coverage |  0.9 | cap | 1.03e-14 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 1.64e-11 | pending | flagged, confirmation pending |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | null | size |  0.1 | cap | 2.05e-10 | 0.173 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | null | size |  0.1 | cap | 2.05e-10 | 0.173 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~. | 52 | null | coverage |  0.9 | cap | 2.05e-10 | 0.827 over 5000 | fail (confirmed) |
| incidence | MatchingGreedyPairSwitching | IncidExtendedRobins | wald | ~1 | 52 | null | coverage |  0.9 | cap | 2.05e-10 | 0.827 over 5000 | fail (confirmed) |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | size |  0.1 | cap | 3.43e-08 | pending | flagged, confirmation pending |
| continuous | Bernoulli | ContinLin | wald | ~. | 50 | null | coverage |  0.9 | cap | 3.43e-08 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 4.78e-08 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKCondLogitGLMMOneLik | lik_ratio | ~. | 50 | null | size |  0.1 | cap | 1.5e-07 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | size |  0.1 | cap | 1.73e-05 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | size |  0.1 | cap | 1.73e-05 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | cap | 1.73e-05 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKNewcombeRiskDiff | wald | ~1 | 50 | null | coverage |  0.9 | cap | 1.73e-05 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 1.99e-05 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 1.99e-05 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.000825 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | null | size |  0.1 | cap | 0.00142 | 0.172 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | null | size |  0.1 | cap | 0.00142 | 0.172 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~. | 50 | null | coverage |  0.9 | cap | 0.00142 | 0.828 over 5000 | fail (confirmed) |
| incidence | BinaryMatch | IncidExtendedRobins | wald | ~1 | 50 | null | coverage |  0.9 | cap | 0.00142 | 0.828 over 5000 | fail (confirmed) |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.00175 | pending | flagged, confirmation pending |
| incidence | Rerandomization | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.00366 | pending | flagged, confirmation pending |
| incidence | SPBR | IncidLogBinomial | score | ~. | 50 | null | size |  0.1 | unknown | 0.00442 | pending | flagged, confirmation pending |
| incidence | KK21 | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 0.00502 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.0059 | pending | flagged, confirmation pending |
| incidence | KK21stepwise | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 0.00669 | pending | flagged, confirmation pending |
| incidence | BinaryMatch | IncidKKCondLogitOneLik | gradient | ~. | 50 | null | size |  0.1 | cap | 0.016 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.016 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 0.0165 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 0.0165 | pending | flagged, confirmation pending |
| incidence | Blocking | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.0165 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | size |  0.1 | unknown | 0.0253 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | size | 0.0525 | unknown | 0.0253 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidBinomialIdentityRiskDiff | wald | ~. | 50 | null | coverage |  0.9 | unknown | 0.0253 | pending | flagged, confirmation pending |
| incidence | Bernoulli | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.0271 | pending | flagged, confirmation pending |
| incidence | iBCRD | IncidLogBinomial | score | ~. | 1000 | null | coverage | 0.948 | unknown | 0.0471 | pending | flagged, confirmation pending |

[← Campaign 2026-11-12-a46ab113 summary](README.md)
