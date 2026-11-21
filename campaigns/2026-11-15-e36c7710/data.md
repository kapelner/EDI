[← Campaign 2026-11-15-e36c7710 summary](README.md)

# Data

* Tables: [`summary/calibration_summary.csv`](summary/calibration_summary.csv) (size, coverage, with n_eff, expected order, level and rule per cell),
  [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv) (every cell the screen flagged, with its confirmation verdict),
  [`summary/triage.csv`](summary/triage.csv) (failing cells grouped by class x procedure x metric, with pattern, worst cell and a command to reproduce it),
  [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv) (with the `bias_sd_large_n` flag),
  [`summary/power_summary.csv`](summary/power_summary.csv) (power, and coverage of the true estimand),
  [`summary/nonnull_bias_summary.csv`](summary/nonnull_bias_summary.csv) (bias at beta_T != 0, with `bias_sd_large_n`),
  `design_comparison.csv` (paired power tests between designs; written when the campaign completes),
  [`summary/convergence_summary.csv`](summary/convergence_summary.csv) and [`summary/convergence_points.csv`](summary/convergence_points.csv),
  [`summary/balance_summary.csv`](summary/balance_summary.csv) (covariate balance per design and n: Mahalanobis, SMD, variance ratio, KS, energy),
  [`summary/pvalue_curves.csv`](summary/pvalue_curves.csv) (null p-value CDF minus u, the p-value curve figures).
* Raw per-replicate rows: the `study-rows` artifact of each workflow run ([43736391291](https://github.com/kapelner/EDI/actions/runs/43736391291), [43759657525](https://github.com/kapelner/EDI/actions/runs/43759657525), [43789410751](https://github.com/kapelner/EDI/actions/runs/43789410751), [43816955039](https://github.com/kapelner/EDI/actions/runs/43816955039), [43855234294](https://github.com/kapelner/EDI/actions/runs/43855234294), [43894131546](https://github.com/kapelner/EDI/actions/runs/43894131546), [43959107280](https://github.com/kapelner/EDI/actions/runs/43959107280), [44007143828](https://github.com/kapelner/EDI/actions/runs/44007143828), [44066886699](https://github.com/kapelner/EDI/actions/runs/44066886699), [44166877931](https://github.com/kapelner/EDI/actions/runs/44166877931), [44231932839](https://github.com/kapelner/EDI/actions/runs/44231932839), [44259908130](https://github.com/kapelner/EDI/actions/runs/44259908130), [44327482713](https://github.com/kapelner/EDI/actions/runs/44327482713), [44404630432](https://github.com/kapelner/EDI/actions/runs/44404630432), [44448806377](https://github.com/kapelner/EDI/actions/runs/44448806377), [44487751098](https://github.com/kapelner/EDI/actions/runs/44487751098), [44545449381](https://github.com/kapelner/EDI/actions/runs/44545449381), [44618585699](https://github.com/kapelner/EDI/actions/runs/44618585699), [44677605078](https://github.com/kapelner/EDI/actions/runs/44677605078), [44726720561](https://github.com/kapelner/EDI/actions/runs/44726720561), [44783038853](https://github.com/kapelner/EDI/actions/runs/44783038853), [44834170935](https://github.com/kapelner/EDI/actions/runs/44834170935), [44863031009](https://github.com/kapelner/EDI/actions/runs/44863031009), [44882428348](https://github.com/kapelner/EDI/actions/runs/44882428348)), one `rows.csv.xz` per wave (read it in R with `read_csv_fast(xzfile("rows.csv.xz"))`; kept 60 days, so the last two campaigns; a GitHub login is needed to download).
  One row per replicate x class x formula x procedure:
  `inf_class` (EDI inference class), `inf_procedure` (`wald`, `score`, `lik_ratio`, `gradient`, `exact`, `rand`),
  `formula` (`~1` or `~.`), `beta_T_hat` (treatment-effect estimate), `ci_beta_T_a` / `ci_beta_T_b` (95% CI
  ends; NA for `rand`, p-value only), `pval` (two-sided, H0: beta_T = `null_value`), `null_value` (0 on the
  class's scale), `fit_secs`, `status` (`ok`, `nonestimable`, `error`), `message` (error text), then the cell:
  `response_type`, `design`, `prob_T`, `n` (as run), `n_nominal` (as planned; pair-switching runs 52 for 50),
  `p` (covariates), `rep` (sets the seed: the same `rep` is the same subjects on every design), `effect_label`
  (`null`, `power20`, `power50`, `power80`), `beta_T` (the true effect, 0 under the null) and `estimand_true`
  (the true value of the class's own estimand, which coverage and bias are measured against: `null_value` under
  the null; NA at beta_T != 0 where there is none). Result columns
  are rounded to 7 significant digits; the published tables use the unrounded values.

[← Campaign 2026-11-15-e36c7710 summary](README.md)
