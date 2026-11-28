[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Figures: proportion

### Null treatment effect (beta_T = 0)

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-proportion-dark.png"><img alt="proportion overview: size and coverage by n" src="figures/overview-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-proportion-dark.png"><img alt="proportion size and coverage" src="figures/size-coverage-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-proportion-dark.png"><img alt="proportion null bias" src="figures/null-bias-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-proportion-dark.png"><img alt="proportion p-value curves" src="figures/pvalue-curves-proportion.png"></picture>

##### Convergence of the error with n

3047 of 3078 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-proportion-dark.png"><img alt="proportion convergence of the error with n" src="figures/convergence-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-wald-dark.png"><img alt="proportion convergence verdicts: wald" src="figures/convergence-grid-proportion-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-score-dark.png"><img alt="proportion convergence verdicts: score" src="figures/convergence-grid-proportion-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-lik-ratio-dark.png"><img alt="proportion convergence verdicts: lik_ratio" src="figures/convergence-grid-proportion-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-gradient-dark.png"><img alt="proportion convergence verdicts: gradient" src="figures/convergence-grid-proportion-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-proportion-bias-dark.png"><img alt="proportion convergence verdicts: bias (estimator)" src="figures/convergence-grid-proportion-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-proportion-dark.png"><img alt="proportion non-null overview" src="figures/overview-nonnull-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-proportion-dark.png"><img alt="proportion non-null coverage" src="figures/coverage-nonnull-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-proportion-dark.png"><img alt="proportion non-null bias" src="figures/bias-nonnull-proportion.png"></picture>

##### Convergence of the error with n

1580 of 1580 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-nonnull-proportion-dark.png"><img alt="proportion convergence of the error with n" src="figures/convergence-nonnull-proportion.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-wald-dark.png"><img alt="proportion convergence verdicts: wald" src="figures/convergence-grid-nonnull-proportion-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-score-dark.png"><img alt="proportion convergence verdicts: score" src="figures/convergence-grid-nonnull-proportion-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-lik-ratio-dark.png"><img alt="proportion convergence verdicts: lik_ratio" src="figures/convergence-grid-nonnull-proportion-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-gradient-dark.png"><img alt="proportion convergence verdicts: gradient" src="figures/convergence-grid-nonnull-proportion-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-proportion-bias-dark.png"><img alt="proportion convergence verdicts: bias (estimator)" src="figures/convergence-grid-nonnull-proportion-bias.png"></picture>

[← Campaign 2026-11-15-e36c7710 summary](README.md)
