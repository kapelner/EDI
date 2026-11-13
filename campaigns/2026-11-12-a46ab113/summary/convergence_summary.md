## Convergence slopes

**Provisional.** 8256 cell-metrics: 352 consistent, 888 slower, 11 faster, 5313 undetermined, 1692 not_applicable. 8116 of them ran at two or more sample sizes.

Each asymptotic cell's error (size - 5%, 95% - coverage, bias) is fitted against n_eff with a noise-aware power law (binomial / normal likelihood, 95% profile CI for the order `a`) and compared with the registry's expected order (`consistent`, `slower`, `faster`; `undetermined` = the error is below 2 Monte Carlo SE at fewer than 2 sizes). The log-log regression of |error| on n_eff is in the table too (`loglog_slope`, expected `-expected_order`), but it is biased toward 0 wherever |error| is dominated by Monte Carlo noise: with 1,000 replicates the size SE is about 0.007, while an O(1/n) excess at n = 1000 is about 0.001. Reported, not gated.

### Cells converging slower than expected (888, 25 shown)

| class | design | procedure | formula | metric | effect | expected | a (95% CI) | basis |
|---|---|---|---|---|---|---|---|---|
| IncidModifiedPoisson | FixedOptimal | score | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | score | `~1` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | lik_ratio | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | gradient | `~1` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | lik_ratio | `~1` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedBernoulli | score | `~.` | size | null | 1.00 | 0.00 (0.00, 0.02) | assumed_default |
| IncidModifiedPoisson | FixedBernoulli | score | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.02) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | gradient | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | score | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidExtendedRobins | FixedBinaryMatch | wald | `~.` | size | null | 1.00 | 0.00 (0.00, 0.11) | assumed_default |
| IncidExtendedRobins | FixedBinaryMatch | wald | `~1` | size | null | 1.00 | 0.00 (0.00, 0.11) | assumed_default |
| IncidExtendedRobins | FixedBinaryMatch | wald | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.11) | assumed_default |
| IncidExtendedRobins | FixedBinaryMatch | wald | `~1` | coverage | null | 1.00 | 0.00 (0.00, 0.11) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | score | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | score | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | score | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | lik_ratio | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | score | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | lik_ratio | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | score | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | gradient | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimal | gradient | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | lik_ratio | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | lik_ratio | `~.` | size | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |
| IncidModifiedPoisson | FixedOptimalBlocks | gradient | `~.` | coverage | null | 1.00 | 0.00 (0.00, 0.01) | assumed_default |

