### Null treatment effect (beta_T = 0)

#### Continuous

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

#### Incidence

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

#### Count

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/overview-count-dark.png"><img alt="count overview: size and coverage by n" src="figures/overview-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/size-coverage-count-dark.png"><img alt="count size and coverage" src="figures/size-coverage-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/null-bias-count-dark.png"><img alt="count null bias" src="figures/null-bias-count.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/pvalue-curves-count-dark.png"><img alt="count p-value curves" src="figures/pvalue-curves-count.png"></picture>

##### Convergence of the error with n

140 of 280 cells ran at two or more sample sizes; the others, and every cell whose error is below 2 Monte Carlo SE at fewer than two sizes, are `undetermined`.
The verdict is the noise-aware power-law fit (binomial / normal likelihood) against the registry's expected order; reported, not gated. See `summary/convergence_summary.csv` (also the log-log regression slope, biased toward 0 where |error| is Monte Carlo noise).

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-count-wald-dark.png"><img alt="count convergence verdicts: wald" src="figures/convergence-grid-count-wald.png"></picture>

<picture><source media="(prefers-color-scheme: dark)" srcset="figures/convergence-grid-count-bias-dark.png"><img alt="count convergence verdicts: bias (estimator)" src="figures/convergence-grid-count-bias.png"></picture>

### Non-null treatment effect (beta_T != 0)

Coverage and bias are measured against the true value of each class's own estimand; cells with no true value
(classes that apply only to matched designs, or failed large-sample fits) are shown as such and not tested.

#### Continuous

#### Incidence

#### Count

