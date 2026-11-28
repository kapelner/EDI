[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Figures: survival

### Null treatment effect (beta_T = 0)

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-survival-dark.png"><img alt="survival overview: size and coverage by n" src="figures/overview-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-survival-dark.png"><img alt="survival size and coverage" src="figures/size-coverage-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-survival-dark.png"><img alt="survival null bias" src="figures/null-bias-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-survival-dark.png"><img alt="survival p-value curves" src="figures/pvalue-curves-survival.png"></picture>

##### Convergence of the error with n

4214 of 4214 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-survival-dark.png"><img alt="survival convergence of the error with n" src="figures/convergence-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-wald-dark.png"><img alt="survival convergence verdicts: wald" src="figures/convergence-grid-survival-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-score-dark.png"><img alt="survival convergence verdicts: score" src="figures/convergence-grid-survival-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-lik-ratio-dark.png"><img alt="survival convergence verdicts: lik_ratio" src="figures/convergence-grid-survival-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-gradient-dark.png"><img alt="survival convergence verdicts: gradient" src="figures/convergence-grid-survival-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-survival-bias-dark.png"><img alt="survival convergence verdicts: bias (estimator)" src="figures/convergence-grid-survival-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-nonnull-survival-dark.png"><img alt="survival non-null overview" src="figures/overview-nonnull-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/coverage-nonnull-survival-dark.png"><img alt="survival non-null coverage" src="figures/coverage-nonnull-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/bias-nonnull-survival-dark.png"><img alt="survival non-null bias" src="figures/bias-nonnull-survival.png"></picture>

##### Convergence of the error with n

1974 of 1980 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-nonnull-survival-dark.png"><img alt="survival convergence of the error with n" src="figures/convergence-nonnull-survival.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-wald-dark.png"><img alt="survival convergence verdicts: wald" src="figures/convergence-grid-nonnull-survival-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-score-dark.png"><img alt="survival convergence verdicts: score" src="figures/convergence-grid-nonnull-survival-score.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-lik-ratio-dark.png"><img alt="survival convergence verdicts: lik_ratio" src="figures/convergence-grid-nonnull-survival-lik-ratio.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-gradient-dark.png"><img alt="survival convergence verdicts: gradient" src="figures/convergence-grid-nonnull-survival-gradient.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-nonnull-survival-bias-dark.png"><img alt="survival convergence verdicts: bias (estimator)" src="figures/convergence-grid-nonnull-survival-bias.png"></picture>

[← Campaign 2026-11-15-e36c7710 summary](README.md)
