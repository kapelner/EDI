[← Campaign 2026-11-09-8c32d060 summary](README.md)

# Figures: survival

### Null treatment effect (beta_T = 0)



<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-survival-dark.png"><img alt="survival overview" src="figures/overview-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-survival-dark.png"><img alt="survival size" src="figures/size-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-survival-dark.png"><img alt="survival coverage" src="figures/coverage-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-survival-dark.png"><img alt="survival null bias" src="figures/null-bias-survival.png"></picture>

##### Convergence of the error with n

0 of 2932 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-dark.png"><img alt="survival convergence verdicts" src="figures/convergence-grid-survival.png"></picture>

### Non-null treatment effect (beta_T != 0)


Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.


<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-survival-dark.png"><img alt="survival non-null overview" src="figures/overview-nonnull-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-survival-dark.png"><img alt="survival non-null coverage" src="figures/coverage-nonnull-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-survival-dark.png"><img alt="survival non-null bias" src="figures/bias-nonnull-survival.png"></picture>

##### Convergence of the error with n

0 of 720 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-dark.png"><img alt="survival convergence verdicts" src="figures/convergence-grid-nonnull-survival.png"></picture>



[← Campaign 2026-11-09-8c32d060 summary](README.md)
