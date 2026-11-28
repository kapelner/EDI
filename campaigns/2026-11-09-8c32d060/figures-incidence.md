[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Figures: incidence

### Null treatment effect (beta_T = 0)



<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-incidence-dark.png"><img alt="incidence overview" src="figures/overview-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-incidence-dark.png"><img alt="incidence size" src="figures/size-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-incidence-dark.png"><img alt="incidence coverage" src="figures/coverage-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-incidence-dark.png"><img alt="incidence null bias" src="figures/null-bias-incidence.png"></picture>

##### Convergence of the error with n

0 of 3522 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-dark.png"><img alt="incidence convergence verdicts" src="figures/convergence-grid-incidence.png"></picture>

### Non-null treatment effect (beta_T != 0)


Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.


<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-incidence-dark.png"><img alt="incidence non-null overview" src="figures/overview-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-incidence-dark.png"><img alt="incidence non-null coverage" src="figures/coverage-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-incidence-dark.png"><img alt="incidence non-null bias" src="figures/bias-nonnull-incidence.png"></picture>

##### Convergence of the error with n

0 of 1113 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-dark.png"><img alt="incidence convergence verdicts" src="figures/convergence-grid-nonnull-incidence.png"></picture>



[← Campaign 2026-11-09-8c32d060 summary](README.md)
