[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Figures: incidence

### Null treatment effect (beta_T = 0)

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-incidence-dark.png"><img alt="incidence overview: size and coverage by n" src="figures/overview-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-incidence-dark.png"><img alt="incidence size and coverage" src="figures/size-coverage-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-incidence-dark.png"><img alt="incidence null bias" src="figures/null-bias-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-incidence-dark.png"><img alt="incidence p-value curves" src="figures/pvalue-curves-incidence.png"></picture>

##### Convergence of the error with n

5076 of 5076 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-incidence-dark.png"><img alt="incidence convergence of the error with n" src="figures/convergence-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-wald-dark.png"><img alt="incidence convergence verdicts: wald" src="figures/convergence-grid-incidence-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-score-dark.png"><img alt="incidence convergence verdicts: score" src="figures/convergence-grid-incidence-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-lik-ratio-dark.png"><img alt="incidence convergence verdicts: lik_ratio" src="figures/convergence-grid-incidence-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-gradient-dark.png"><img alt="incidence convergence verdicts: gradient" src="figures/convergence-grid-incidence-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-incidence-bias-dark.png"><img alt="incidence convergence verdicts: bias (estimator)" src="figures/convergence-grid-incidence-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-incidence-dark.png"><img alt="incidence non-null overview" src="figures/overview-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-incidence-dark.png"><img alt="incidence non-null coverage" src="figures/coverage-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-incidence-dark.png"><img alt="incidence non-null bias" src="figures/bias-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/power-designs-incidence-dark.png"><img alt="incidence power by design" src="figures/power-designs-incidence.png"></picture>

##### Convergence of the error with n

5250 of 5415 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-nonnull-incidence-dark.png"><img alt="incidence convergence of the error with n" src="figures/convergence-nonnull-incidence.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-wald-dark.png"><img alt="incidence convergence verdicts: wald" src="figures/convergence-grid-nonnull-incidence-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-score-dark.png"><img alt="incidence convergence verdicts: score" src="figures/convergence-grid-nonnull-incidence-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-lik-ratio-dark.png"><img alt="incidence convergence verdicts: lik_ratio" src="figures/convergence-grid-nonnull-incidence-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-gradient-dark.png"><img alt="incidence convergence verdicts: gradient" src="figures/convergence-grid-nonnull-incidence-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-incidence-bias-dark.png"><img alt="incidence convergence verdicts: bias (estimator)" src="figures/convergence-grid-nonnull-incidence-bias.png"></picture>

[← Campaign 2026-11-15-e36c7710 summary](README.md)
