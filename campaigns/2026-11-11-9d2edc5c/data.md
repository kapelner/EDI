[← Campaign 2026-11-11-9d2edc5c summary](README.md)

# Data

* Tables: [`summary/calibration_summary.csv`](summary/calibration_summary.csv) (size, coverage, with n_eff, expected order, level and rule per cell),
  [`summary/confirmation_summary.csv`](summary/confirmation_summary.csv) (every cell the screen flagged, with its confirmation verdict),
  [`summary/null_bias_summary.csv`](summary/null_bias_summary.csv) (with the `bias_sd_large_n` flag),
  [`summary/power_summary.csv`](summary/power_summary.csv) (power, and coverage of the true estimand),
  [`summary/nonnull_bias_summary.csv`](summary/nonnull_bias_summary.csv) (bias at beta_T != 0, with `bias_sd_large_n`),
  `design_comparison.csv` (paired power tests between designs; written when the campaign completes),
  [`summary/convergence_summary.csv`](summary/convergence_summary.csv) and [`summary/convergence_points.csv`](summary/convergence_points.csv),
  [`summary/pvalue_curves.csv`](summary/pvalue_curves.csv) (null p-value CDF minus u, the p-value curve figures).
* Raw per-replicate rows: the `study-rows` artifact of each workflow run ([42958825434](https://github.com/kapelner/EDI/actions/runs/42958825434), [42968963596](https://github.com/kapelner/EDI/actions/runs/42968963596), [42980067968](https://github.com/kapelner/EDI/actions/runs/42980067968), [42988664233](https://github.com/kapelner/EDI/actions/runs/42988664233), [43000313961](https://github.com/kapelner/EDI/actions/runs/43000313961), [43010503440](https://github.com/kapelner/EDI/actions/runs/43010503440), [43023471340](https://github.com/kapelner/EDI/actions/runs/43023471340), [43067621163](https://github.com/kapelner/EDI/actions/runs/43067621163), [43085771500](https://github.com/kapelner/EDI/actions/runs/43085771500), [43130238235](https://github.com/kapelner/EDI/actions/runs/43130238235), [43160199085](https://github.com/kapelner/EDI/actions/runs/43160199085), [43187993157](https://github.com/kapelner/EDI/actions/runs/43187993157)), one `rows.csv.xz` per wave (read it in R with `read.csv(xzfile("rows.csv.xz"))`; kept 60 days, so the last two campaigns; a GitHub login is needed to download).
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

[← Campaign 2026-11-11-9d2edc5c summary](README.md)
