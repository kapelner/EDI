## Convergence slopes

**Provisional.** 21412 cell-metrics: 1053 consistent, 2956 slower, 49 faster, 12034 undetermined, 5320 not_applicable. 21359 of them ran at two or more sample sizes.

Each asymptotic cell's error (size - 5%, 95% - coverage, bias) is fitted against n_eff with a noise-aware power law (binomial / normal likelihood, 95% profile CI for the order `a`) and compared with the registry's expected order (`consistent`, `slower`, `faster`; `undetermined` = the error is below 2 Monte Carlo SE at fewer than 2 sizes). The log-log regression of |error| on n_eff is in the table too (`loglog_slope`, expected `-expected_order`), but it is biased toward 0 wherever |error| is dominated by Monte Carlo noise: with 1,000 replicates the size SE is about 0.007, while an O(1/n) excess at n = 1000 is about 0.001. Reported, not gated.

### Cells converging slower than expected (2956, 25 shown)

| class | design | procedure | formula | metric | effect | expected | a (95% CI) | basis |
|---|---|---|---|---|---|---|---|---|
| CountHurdlePoisson | SeqOneByOneBernoulli | lik_ratio | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneBernoulli | lik_ratio | `~1` | size | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneBernoulli | gradient | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneBernoulli | gradient | `~1` | size | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneBernoulli | score | `~1` | size | null | 1.00 | 0.00 (0.00, 0.04) | assumed_default |
| CountHurdlePoisson | SeqOneByOneBernoulli | score | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.04) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | score | `~1` | size | null | 1.00 | 0.01 (0.00, 0.10) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | score | `~1` | coverage | null | 1.00 | 0.01 (0.00, 0.10) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | score | `~1` | size | null | 1.00 | 0.00 (0.00, 0.06) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | score | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.06) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | lik_ratio | `~1` | size | null | 1.00 | 0.02 (0.00, 0.10) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | lik_ratio | `~1` | coverage | null | 1.00 | 0.02 (0.00, 0.10) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | gradient | `~1` | size | null | 1.00 | 0.00 (0.00, 0.07) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | gradient | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.07) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | gradient | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.06) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | gradient | `~1` | size | null | 1.00 | 0.00 (0.00, 0.06) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | gradient | `~1` | coverage | null | 1.00 | 0.02 (0.00, 0.11) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | gradient | `~1` | size | null | 1.00 | 0.02 (0.00, 0.11) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | lik_ratio | `~1` | size | null | 1.00 | 0.00 (0.00, 0.07) | assumed_default |
| CountHurdlePoisson | SeqOneByOneUrn | lik_ratio | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.07) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | lik_ratio | `~1` | size | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | lik_ratio | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | score | `~1` | size | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | SeqOneByOneiBCRD | score | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.05) | assumed_default |
| CountHurdlePoisson | FixedBernoulli | score | `~1` | size | null | 1.00 | 0.00 (0.00, 0.07) | assumed_default |

