[← Campaign 2026-11-12-a46ab113 summary](README.md)

# Figures: continuous

### Null treatment effect (beta_T = 0)

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-continuous-dark.png"><img alt="continuous overview: size and coverage by n" src="figures/overview-continuous.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-continuous-dark.png"><img alt="continuous size and coverage" src="figures/size-coverage-continuous.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-continuous-dark.png"><img alt="continuous null bias" src="figures/null-bias-continuous.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-continuous-dark.png"><img alt="continuous p-value curves" src="figures/pvalue-curves-continuous.png"></picture>

##### Convergence of the error with n

2900 of 2900 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-continuous-dark.png"><img alt="continuous convergence of the error with n" src="figures/convergence-continuous.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-continuous-wald-dark.png"><img alt="continuous convergence verdicts: wald" src="figures/convergence-grid-continuous-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-continuous-score-dark.png"><img alt="continuous convergence verdicts: score" src="figures/convergence-grid-continuous-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-continuous-lik-ratio-dark.png"><img alt="continuous convergence verdicts: lik_ratio" src="figures/convergence-grid-continuous-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-continuous-gradient-dark.png"><img alt="continuous convergence verdicts: gradient" src="figures/convergence-grid-continuous-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-continuous-bias-dark.png"><img alt="continuous convergence verdicts: bias (estimator)" src="figures/convergence-grid-continuous-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

[← Campaign 2026-11-12-a46ab113 summary](README.md)
