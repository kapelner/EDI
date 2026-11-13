[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Figures: ordinal

### Null treatment effect (beta_T = 0)



<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-ordinal-dark.png"><img alt="ordinal overview" src="figures/overview-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-ordinal-dark.png"><img alt="ordinal size" src="figures/size-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-ordinal-dark.png"><img alt="ordinal coverage" src="figures/coverage-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-ordinal-dark.png"><img alt="ordinal null bias" src="figures/null-bias-ordinal.png"></picture>

##### Convergence of the error with n

0 of 4353 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-ordinal-dark.png"><img alt="ordinal convergence verdicts" src="figures/convergence-grid-ordinal.png"></picture>

### Non-null treatment effect (beta_T != 0)


Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.


<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-ordinal-dark.png"><img alt="ordinal non-null overview" src="figures/overview-nonnull-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-ordinal-dark.png"><img alt="ordinal non-null coverage" src="figures/coverage-nonnull-ordinal.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-ordinal-dark.png"><img alt="ordinal non-null bias" src="figures/bias-nonnull-ordinal.png"></picture>

##### Convergence of the error with n

0 of 1209 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-ordinal-dark.png"><img alt="ordinal convergence verdicts" src="figures/convergence-grid-nonnull-ordinal.png"></picture>



[← Campaign 2026-11-09-8c32d060 summary](README.md)
