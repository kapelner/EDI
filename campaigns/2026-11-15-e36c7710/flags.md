[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Screen flags and confirmation verdicts

2625 test(s) flagged at the screen (Benjamini-Hochberg q < 0.05): 247 cleared by confirmation, 2089 fail (confirmed), 289 flagged, confirmation pending.

By the rule that set the level: cap 421, finite 177, rate 293, rate_check 660, unknown 1074.

The 300 most significant (all rows: [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv)).

| response | design | class | procedure | formula | n | effect | metric | level | rule | q | confirmation | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| incidence | SeqOneByOne:Urn | IncidLogBinomial | score | ~. | 50 | power50 | coverage |  0.9 | unknown | 2.69e-109 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 4.99e-97 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 1.06e-94 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 1.06e-94 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidNewcombeRiskDiff | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 1.06e-94 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | score | ~1 | 50 | power50 | coverage |  0.9 | unknown | 2.89e-91 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 2.89e-91 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | score | ~1 | 50 | power50 | coverage |  0.9 | cap | 1.95e-90 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | score | ~1 | 50 | power50 | coverage |  0.9 | cap | 5.64e-87 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 3.76e-86 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | lik_ratio | ~1 | 50 | power50 | coverage |  0.9 | cap | 2.3e-85 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 2.3e-85 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 1.26e-84 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidMiettinenNurminenRiskDiff | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 1.26e-84 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | gradient | ~1 | 50 | power50 | coverage |  0.9 | cap | 1.26e-84 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | lik_ratio | ~1 | 50 | power50 | coverage |  0.9 | cap | 1.26e-84 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | gradient | ~1 | 50 | power50 | coverage |  0.9 | cap | 4.37e-82 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidModifiedPoisson | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 1.41e-79 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | lik_ratio | ~. | 50 | power50 | coverage |  0.9 | unknown | 9.23e-79 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidGCompRiskDiff | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 3.53e-77 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidRiskDiff | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 3.53e-77 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidWald | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 3.53e-77 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidWald | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 3.53e-77 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidGCompRiskRatio | wald | ~1 | 50 | power50 | coverage |  0.9 | cap | 9.61e-75 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | wald | ~1 | 50 | power50 | coverage |  0.9 | unknown | 9.61e-75 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | score | ~. | 50 | power50 | coverage |  0.9 | cap | 1.03e-70 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | lik_ratio | ~1 | 50 | power50 | coverage |  0.9 | unknown | 6.26e-70 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | score | ~. | 50 | power50 | coverage |  0.9 | cap | 3.77e-69 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | lik_ratio | ~. | 50 | power50 | coverage |  0.9 | cap | 3.05e-65 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | gradient | ~. | 50 | power50 | coverage |  0.9 | cap | 9.98e-64 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidProbitRegr | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 9.98e-64 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | lik_ratio | ~. | 50 | power50 | coverage |  0.9 | cap | 6.05e-60 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | gradient | ~1 | 50 | power50 | coverage |  0.9 | unknown | 3.19e-59 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | wald | ~. | 50 | power50 | coverage |  0.9 | cap | 3.19e-59 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | gradient | ~. | 50 | power50 | coverage |  0.9 | unknown | 5.18e-57 | pending | flagged, confirmation pending |
| incidence | SeqOneByOne:Urn | IncidLogRegr | gradient | ~. | 50 | power50 | coverage |  0.9 | cap | 4.12e-54 | pending | flagged, confirmation pending |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 1.78e-49 | 0.186 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 1.78e-49 | 0.177 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 1.78e-49 | 0.176 over 5000 | fail (confirmed) |
| count | Fixed:Greedy@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 1.78e-49 | 0.186 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.78e-49 | 0.823 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.78e-49 | 0.824 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 2.38e-46 | 0.177 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.38e-46 | 0.823 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.179 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.178 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.178 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.167 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.167 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 7.8e-46 | 0.167 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.821 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.822 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.822 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.833 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.833 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.8e-46 | 0.833 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 3.12e-45 | 0.173 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 3.12e-45 | 0.165 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 1.17e-44 | 0.171 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 1.17e-44 | 0.17 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 1.17e-44 | 0.167 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 1.17e-44 | 0.182 over 4999 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.17e-44 | 0.829 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.17e-44 | 0.83 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 7.57e-43 | 0.169 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 7.57e-43 | 0.831 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 2.67e-42 | 0.164 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 2.67e-42 | 0.174 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 2.67e-42 | 0.174 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 2.67e-42 | 0.174 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 2.67e-42 | 0.177 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.67e-42 | 0.836 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.67e-42 | 0.826 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.67e-42 | 0.826 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.67e-42 | 0.826 over 5000 | fail (confirmed) |
| incidence | SeqOneByOne:Urn | IncidLogBinomial | wald | ~. | 50 | power50 | coverage |  0.9 | unknown | 4.03e-42 | pending | flagged, confirmation pending |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 9.96e-42 | 0.165 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 9.96e-42 | 0.175 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 9.96e-42 | 0.835 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 9.96e-42 | 0.825 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.95 | rate_check | 1.97e-41 | pending | flagged, confirmation pending |
| count | SeqOneByOne:RandomBlockSize | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.95 | rate_check | 1.97e-41 | pending | flagged, confirmation pending |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 3.42e-41 | 0.161 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 3.42e-41 | 0.162 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 3.42e-41 | 0.165 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 3.42e-41 | 0.175 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 3.42e-41 | 0.175 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.42e-41 | 0.839 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.42e-41 | 0.838 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.42e-41 | 0.835 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.42e-41 | 0.825 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 3.42e-41 | 0.825 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 1.26e-40 | 0.16 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 1.26e-40 | 0.173 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 1.26e-40 | 0.173 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.26e-40 | 0.84 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.26e-40 | 0.827 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.26e-40 | 0.827 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 4.5e-40 | 0.172 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 4.5e-40 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 4.5e-40 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 4.5e-40 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 4.5e-40 | 0.175 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 4.5e-40 | 0.828 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 4.5e-40 | 0.84 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 4.5e-40 | 0.84 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 4.5e-40 | 0.84 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 1.72e-39 | 0.187 over 5000 | fail (confirmed) |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.95 | rate_check | 1.56e-38 | pending | flagged, confirmation pending |
| count | SeqOneByOne:PocockSimon | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.95 | rate_check | 1.56e-38 | pending | flagged, confirmation pending |
| count | Fixed:Blocking@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 2.37e-38 | 0.178 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 2.37e-38 | 0.171 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 2.37e-38 | 0.171 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.37e-38 | 0.829 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.37e-38 | 0.829 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 8.4e-38 | 0.171 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 8.4e-38 | 0.176 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 8.4e-38 | 0.176 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 8.4e-38 | 0.175 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.4e-38 | 0.829 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.4e-38 | 0.824 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.4e-38 | 0.824 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.4e-38 | 0.825 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 9.21e-38 | 0.171 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 9.21e-38 | 0.17 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 9.21e-38 | 0.169 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 9.21e-38 | 0.829 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 9.21e-38 | 0.83 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 9.21e-38 | 0.831 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 1.55e-37 | 0.162 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 1.55e-37 | 0.162 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 1.55e-37 | 0.162 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.55e-37 | 0.838 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.55e-37 | 0.838 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.55e-37 | 0.838 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 2.84e-37 | 0.168 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.84e-37 | 0.832 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 2.91e-37 | pending | flagged, confirmation pending |
| count | Fixed:Blocking | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 2.91e-37 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.168 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.168 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.168 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.157 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.157 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 5.09e-37 | 0.156 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.832 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.832 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.832 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.843 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.843 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 5.09e-37 | 0.844 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 9.21e-37 | 0.169 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 9.21e-37 | 0.831 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 9.36e-37 | 0.168 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 9.36e-37 | 0.832 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 1.27e-36 | pending | flagged, confirmation pending |
| count | Fixed:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 1.27e-36 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 2.99e-36 | 0.168 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 2.99e-36 | 0.167 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 2.99e-36 | 0.832 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 2.99e-36 | 0.833 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 1.2e-35 | 0.172 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 1.2e-35 | 0.17 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.2e-35 | 0.828 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.2e-35 | 0.83 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 4.32e-35 | 0.169 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 4.32e-35 | 0.831 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 1.55e-34 | 0.173 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 1.55e-34 | 0.827 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 2.65e-34 | 0.158 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 2.65e-34 | 0.158 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 2.65e-34 | 0.158 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 2.65e-34 | 0.842 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 2.65e-34 | 0.842 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 2.65e-34 | 0.842 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 6.08e-34 | pending | flagged, confirmation pending |
| count | Fixed:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 6.08e-34 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 1.11e-33 | 0.169 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 1.11e-33 | 0.165 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 1.11e-33 | 0.831 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 1.11e-33 | 0.835 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 2.76e-33 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Urn | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 2.76e-33 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 1.14e-32 | 0.169 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 1.14e-32 | 0.164 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 1.14e-32 | 0.831 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 1.14e-32 | 0.836 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 3.47e-32 | 0.169 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0625 | unknown | 3.47e-32 | 0.172 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0625 | unknown | 3.47e-32 | 0.172 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0625 | unknown | 3.47e-32 | 0.172 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 3.47e-32 | 0.165 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 3.47e-32 | 0.165 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 3.47e-32 | 0.831 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.938 | unknown | 3.47e-32 | 0.828 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.938 | unknown | 3.47e-32 | 0.828 over 5000 | fail (confirmed) |
| count | Fixed:iBCRD@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.938 | unknown | 3.47e-32 | 0.828 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.47e-32 | 0.835 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.47e-32 | 0.835 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 5.33e-32 | pending | flagged, confirmation pending |
| count | Fixed:Rerandomization | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 5.33e-32 | pending | flagged, confirmation pending |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 1.15e-31 | 0.165 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.15e-31 | 0.835 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 2.48e-31 | 0.163 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.48e-31 | 0.837 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 3.42e-31 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 3.42e-31 | 0.84 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 3.74e-31 | 0.164 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 3.74e-31 | 0.163 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.74e-31 | 0.836 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.74e-31 | 0.837 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 8.12e-31 | 0.162 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 8.12e-31 | 0.162 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.12e-31 | 0.838 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.12e-31 | 0.838 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 1.02e-30 | 0.162 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0625 | unknown | 1.02e-30 | 0.156 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 1.02e-30 | 0.838 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.938 | unknown | 1.02e-30 | 0.844 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 1.2e-30 | 0.163 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.2e-30 | 0.837 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 3.16e-30 | 0.164 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 3.16e-30 | 0.836 over 5000 | fail (confirmed) |
| incidence | SeqOneByOne:KK21stepwise | IncidExactZhang | exact | ~. | 1000 | null | coverage | 0.95 | finite | 3.19e-30 | 0.868 over 4949 | fail (confirmed) |
| incidence | SeqOneByOne:KK21stepwise | IncidExactZhang | exact | ~1 | 1000 | null | coverage | 0.95 | finite | 3.19e-30 | 0.868 over 4949 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 3.85e-30 | 0.15 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 3.85e-30 | 0.149 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 3.85e-30 | 0.149 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.85e-30 | 0.85 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.85e-30 | 0.851 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.85e-30 | 0.851 over 5000 | fail (confirmed) |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 4.14e-30 | pending | flagged, confirmation pending |
| count | SeqOneByOne:iBCRD | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 4.14e-30 | pending | flagged, confirmation pending |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | size | 0.05 | rate_check | 8.3e-30 | 0.146 over 5000 | fail (confirmed) |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | size | 0.05 | rate_check | 8.3e-30 | 0.146 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 8.3e-30 | 0.152 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 8.3e-30 | 0.154 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 8.3e-30 | 0.156 over 5000 | fail (confirmed) |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~. | 1000 | null | coverage | 0.95 | rate_check | 8.3e-30 | 0.854 over 5000 | fail (confirmed) |
| incidence | Fixed:BinaryMatch | IncidExtendedRobins | wald | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.3e-30 | 0.854 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.3e-30 | 0.848 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.3e-30 | 0.846 over 5000 | fail (confirmed) |
| count | Fixed:Blocking@0.2 | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.3e-30 | 0.844 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 8.9e-30 | 0.167 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0625 | unknown | 8.9e-30 | 0.156 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 8.9e-30 | 0.833 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.938 | unknown | 8.9e-30 | 0.844 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 1.19e-29 | 0.153 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | coverage | 0.948 | unknown | 1.19e-29 | 0.847 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | power50 | coverage | 0.95 | rate_check | 1.3e-29 | pending | flagged, confirmation pending |
| count | Fixed:GreedyDOptimal@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | null | size |  0.1 | unknown | 2.57e-29 | 0.199 over 4847 | fail (confirmed) |
| count | Fixed:Greedy@0.2 | CountZeroInflatedNegBin | score | ~. | 50 | null | size |  0.1 | unknown | 2.57e-29 | 0.199 over 4847 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 2.64e-29 | 0.157 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 2.64e-29 | 0.157 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 2.64e-29 | 0.157 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 2.64e-29 | 0.843 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 2.64e-29 | 0.843 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 2.64e-29 | 0.843 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 3.71e-29 | 0.153 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0525 | unknown | 3.71e-29 | 0.153 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.71e-29 | 0.847 over 5000 | fail (confirmed) |
| count | Fixed:Blocking | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.948 | unknown | 3.71e-29 | 0.847 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Atkinson | CountZeroInflatedNegBin | score | ~. | 50 | null | size |  0.1 | unknown | 1.18e-28 | 0.208 over 4848 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 2.39e-28 | 0.166 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | size | 0.0625 | rate | 2.39e-28 | 0.155 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | null | size | 0.0625 | unknown | 2.39e-28 | 0.155 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 2.39e-28 | 0.834 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | score | ~1 | 200 | null | coverage | 0.938 | rate | 2.39e-28 | 0.845 over 5000 | fail (confirmed) |
| count | Fixed:Bernoulli@0.2 | CountZeroInflatedPoisson | score | ~1 | 1000 | null | coverage | 0.938 | unknown | 2.39e-28 | 0.845 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | power50 | coverage | 0.95 | rate_check | 2.67e-28 | pending | flagged, confirmation pending |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | score | ~1 | 200 | power50 | coverage | 0.95 | rate_check | 2.67e-28 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 2.86e-28 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Bernoulli | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 2.86e-28 | pending | flagged, confirmation pending |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 2.86e-28 | pending | flagged, confirmation pending |
| count | SeqOneByOne:SPBR | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 2.86e-28 | pending | flagged, confirmation pending |
| count | SeqOneByOne:RandomBlockSize | CountZeroInflatedNegBin | score | ~. | 50 | null | size |  0.1 | unknown | 3.84e-28 | 0.209 over 4828 | fail (confirmed) |
| count | Fixed:OptimalBlocks@0.2 | CountZeroInflatedPoisson | rand | ~1 | 50 | null | size | 0.05 | finite | 8.73e-28 | 0.177 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 8.73e-28 | 0.155 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 8.73e-28 | 0.155 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.73e-28 | 0.845 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.73e-28 | 0.845 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 2.07e-27 | 0.165 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 2.07e-27 | 0.835 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 2.76e-27 | 0.155 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 1000 | null | size | 0.05 | rate_check | 2.76e-27 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | size | 0.05 | rate_check | 2.76e-27 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.76e-27 | 0.845 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | gradient | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.76e-27 | 0.84 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | lik_ratio | ~1 | 1000 | null | coverage | 0.95 | rate_check | 2.76e-27 | 0.84 over 5000 | fail (confirmed) |
| count | Fixed:Rerandomization | CountZeroInflatedNegBin | score | ~. | 50 | null | size |  0.1 | unknown | 3.43e-27 | 0.203 over 4837 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | size | 0.0625 | rate | 5.98e-27 | 0.156 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | size | 0.0625 | rate | 5.98e-27 | 0.155 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | gradient | ~1 | 200 | null | coverage | 0.938 | rate | 5.98e-27 | 0.844 over 5000 | fail (confirmed) |
| count | SeqOneByOne:RandomBlockSize@0.2 | CountHurdlePoisson | lik_ratio | ~1 | 200 | null | coverage | 0.938 | rate | 5.98e-27 | 0.845 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 1000 | null | size | 0.05 | rate_check | 8.71e-27 | 0.16 over 5000 | fail (confirmed) |
| count | SeqOneByOne:SPBR | CountHurdlePoisson | score | ~1 | 1000 | null | coverage | 0.95 | rate_check | 8.71e-27 | 0.84 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~. | 200 | power50 | coverage | 0.938 | rate | 1.93e-26 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Efron | AllSimpleWilcox | wald | ~1 | 200 | power50 | coverage | 0.938 | rate | 1.93e-26 | pending | flagged, confirmation pending |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | gradient | ~1 | 1000 | null | size | 0.0525 | unknown | 3.46e-26 | 0.157 over 5000 | fail (confirmed) |
| count | SeqOneByOne:Efron | CountZeroInflatedPoisson | lik_ratio | ~1 | 1000 | null | size | 0.0525 | unknown | 3.46e-26 | 0.157 over 5000 | fail (confirmed) |

[← Campaign 2026-11-15-e36c7710 summary](README.md)
