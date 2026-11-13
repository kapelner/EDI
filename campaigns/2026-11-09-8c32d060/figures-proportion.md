[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Figures: proportion

### Null treatment effect (beta_T = 0)



<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-proportion-dark.png"><img alt="proportion overview" src="figures/overview-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-proportion-dark.png"><img alt="proportion size" src="figures/size-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-proportion-dark.png"><img alt="proportion coverage" src="figures/coverage-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-proportion-dark.png"><img alt="proportion null bias" src="figures/null-bias-proportion.png"></picture>

##### Convergence of the error with n

0 of 2106 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-dark.png"><img alt="proportion convergence verdicts" src="figures/convergence-grid-proportion.png"></picture>

### Non-null treatment effect (beta_T != 0)


Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.


<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-proportion-dark.png"><img alt="proportion non-null overview" src="figures/overview-nonnull-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-proportion-dark.png"><img alt="proportion non-null coverage" src="figures/coverage-nonnull-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-proportion-dark.png"><img alt="proportion non-null bias" src="figures/bias-nonnull-proportion.png"></picture>

##### Convergence of the error with n

0 of 622 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-dark.png"><img alt="proportion convergence verdicts" src="figures/convergence-grid-nonnull-proportion.png"></picture>



[← Campaign 2026-11-09-8c32d060 summary](README.md)
