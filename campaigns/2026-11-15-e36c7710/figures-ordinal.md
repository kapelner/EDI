[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Figures: ordinal

### Null treatment effect (beta_T = 0)

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-ordinal-dark.png"><img alt="ordinal overview: size and coverage by n" src="figures/overview-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-ordinal-dark.png"><img alt="ordinal size and coverage" src="figures/size-coverage-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-ordinal-dark.png"><img alt="ordinal null bias" src="figures/null-bias-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-ordinal-dark.png"><img alt="ordinal p-value curves" src="figures/pvalue-curves-ordinal.png"></picture>

##### Convergence of the error with n

614 of 636 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-ordinal-dark.png"><img alt="ordinal convergence of the error with n" src="figures/convergence-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-ordinal-wald-dark.png"><img alt="ordinal convergence verdicts: wald" src="figures/convergence-grid-ordinal-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-ordinal-bias-dark.png"><img alt="ordinal convergence verdicts: bias (estimator)" src="figures/convergence-grid-ordinal-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

[← Campaign 2026-11-15-e36c7710 summary](README.md)
