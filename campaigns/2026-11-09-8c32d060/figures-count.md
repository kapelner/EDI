[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Figures: count

### Null treatment effect (beta_T = 0)



<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-count-dark.png"><img alt="count overview" src="figures/overview-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-count-dark.png"><img alt="count size" src="figures/size-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-count-dark.png"><img alt="count coverage" src="figures/coverage-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-count-dark.png"><img alt="count null bias" src="figures/null-bias-count.png"></picture>

##### Convergence of the error with n

0 of 3770 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-count-dark.png"><img alt="count convergence verdicts" src="figures/convergence-grid-count.png"></picture>

### Non-null treatment effect (beta_T != 0)


Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.


<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-count-dark.png"><img alt="count non-null overview" src="figures/overview-nonnull-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-count-dark.png"><img alt="count non-null coverage" src="figures/coverage-nonnull-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-count-dark.png"><img alt="count non-null bias" src="figures/bias-nonnull-count.png"></picture>

##### Convergence of the error with n

0 of 980 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-count-dark.png"><img alt="count convergence verdicts" src="figures/convergence-grid-nonnull-count.png"></picture>



[← Campaign 2026-11-09-8c32d060 summary](README.md)
