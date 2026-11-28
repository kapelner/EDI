[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Convergence slopes

## Convergence slopes

**Provisional.** 23881 cell-metrics: 0 consistent, 0 slower, 0 faster, 20078 undetermined, 3803 not_applicable. 0 of them ran at two or more sample sizes.

Each asymptotic cell's error (size - 5%, 95% - coverage, bias) is fitted against n_eff with a noise-aware power law (binomial / normal likelihood, 95% profile CI for the order `a`) and compared with the registry's expected order (`consistent`, `slower`, `faster`; `undetermined` = the error is below 2 Monte Carlo SE at fewer than 2 sizes). The log-log regression of |error| on n_eff is in the table too (`loglog_slope`, expected `-expected_order`), but it is biased toward 0 wherever |error| is dominated by Monte Carlo noise: with 1,000 replicates the size SE is about 0.007, while an O(1/n) excess at n = 1000 is about 0.001. Reported, not gated.

No cell has run at two sample sizes yet, so every verdict is `undetermined` or `not_applicable`.

Tables: [`summary/convergence_summary.csv`](summary/convergence_summary.csv) (one row per cell and metric),
[`summary/convergence_points.csv`](summary/convergence_points.csv) (the errors it was fitted to).


[← Campaign 2026-11-09-8c32d060 summary](README.md)
