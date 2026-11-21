# Summary: simulation-framework (2026-11-21)

## Goal
Plan a 50-subject trial with a continuous outcome (one continuous and one binary prognostic covariate, plus a
quadratic term in x1, sd 1 noise). Compare two designs (complete randomization `DesignFixediBCRD` and pair
matching `DesignFixedBinaryMatch`) and two analyses (unadjusted `InferenceAllSimpleMeanDiffPooledVar`,
adjusted `InferenceContinOLS`), plus the matched analysis `InferenceContinKKOLSOneLik`. Report power at
betaT = 0.8, size at betaT = 0, and 95% CI coverage with `SimulationFramework` / `SimulationFrameworkReport`,
then check one cell against a hand-rolled base-R simulation. A careful statistician would want: size within
Monte Carlo error of alpha, coverage near 95%, power with a Monte Carlo interval, agreement with an
independent simulation, and reproducible runs.

## What I finished
- `analysis.R`: 1000 reps per cell, `num_cores = 2`, custom data generator, asymp CI and p-value. It ran in
  well under a minute. Results (n = 50):

  | design + analysis | size (betaT=0) | power (betaT=0.8) | coverage 0 / 0.8 | CI length |
  |---|---|---|---|---|
  | iBCRD + mean diff | 0.056 | 0.412 | 0.944 / 0.952 | 1.80 |
  | iBCRD + OLS | 0.055 | 0.601 | 0.945 / 0.951 | 1.40 |
  | Match + mean diff | 0.002 | 0.367 | 0.998 / 0.996 | 1.82 |
  | Match + OLS | 0.024 | 0.627 | 0.976 / 0.982 | 1.38 |
  | Match + KKOLSOneLik | 0.054 | 0.707 | 0.946 / 0.958 | 1.24 |

  These are plausible. The unpaired analyses on the matched design are conservative (their SE ignores the
  pairing), as the planning-a-study article predicts. The matched analysis holds size and has the most power.
  The `size_pval` values agree.
- Hand-rolled base-R check of the iBCRD cell (1000 reps, `t.test(var.equal = TRUE)` and `lm` with t-based CI):
  size 0.039 / 0.047, power 0.430 / 0.633, coverage 0.961 / 0.953, mean CI length 1.805 / 1.394. The
  two-sample z for each rate is between -1.8 and 1.8, and CI lengths agree to about 0.2%. They agree.
- Single-trial cross-check: `InferenceAllSimpleMeanDiffPooledVar` equals `t.test(var.equal = TRUE)` and
  `InferenceContinOLS` equals `lm` (estimate, p-value, CI) to all printed digits.
- `summarize()` power/size/coverage agree exactly with rates I recomputed from `get_results()`. All p-values are
  in [0,1] and every CI contains its estimate.
- All eight inference types at 150 reps (`asymp`, `boot` percentile, `rand` p-value and CI, `exact`) on both
  designs with OLS. Rand/boot/asymp sizes are 0.027 to 0.073 and coverages 0.91 to 0.97, all plausible. The
  randomization test on the matched design holds size (0.047). `exact_*` produced no rows and no error for OLS,
  which fits "runs whichever ... are supported".
- Options exercised: unnamed generators, duplicate design entries, `n` as a vector, `Nrep_Y_w = 3` (rows =
  Nrep_W × Nrep_Y_w as documented), `X_mat` (with and without `cov_draw_method = NULL`), `random_X_draws =
  FALSE`, `.csv.bz2` default file, `continue_from_last_result_row`, report from file, report `alpha` override,
  `keep_all_intermediate_data`, `stop_on_error = FALSE`, `custom_apply_treatment_and_noise`,
  `make_estimand_fn`, `asymp_pval = list(delta = ...)`, bad inputs (`alpha` 0 / 1.5, `betaT = NA`,
  `Nrep_W = 0`, `p = 0`, `sd_noise` 0 / -1, odd n with matching, bad type names / arguments, nonlinear
  model with p = 2, incompatible response type).
- Binary outcome (built-in DGP) with Newcombe vs G-computation risk difference: found F10.

## New findings (see findings.md)
F1 glossary says hooks get w in {-1,+1} (they get {0,1}); F2 `$get_errors()` documented on the framework, not
there; F3 `run()` description says it returns a report; **F4 seeds depend on `num_cores` (serial path ignores
`seed + i`)**; **F5 resuming a serial run duplicates earlier replications**; F6 alpha check names `'p'`, and
alpha = 0 is accepted; F7 negative `sd_noise` gives a missing-outcome error; F8 a typo in a design parameter
silently drops the design despite `stop_on_error = TRUE`; F9 report `alpha` override mis-tests coverage;
**F10 G-computation risk difference scored against the logit-scale betaT (coverage 0)**.

## Not done / guesses
- I did not test `custom_dgp`, sequential designs inside the framework, the survival/count/ordinal/proportion
  response types, `save_model_control_fits` output files, or the mirai backend (this is Linux, so fork).
- I did not run the F10 workaround (a `make_estimand_fn` giving the marginal risk difference), because the
  docs do not say whether `y_linear_model` is on the logit or the probability scale for incidence.
- Guess: the `simulation_mode` column (`crdg`, `crdg+catn+cte`) is undocumented. I read it as a tag for which
  custom hooks were used.
- Not reported: `X_mat` with the default (non-NULL) `cov_draw_method` is accepted although the help says it
  "must be NULL". `X_mat` is used, so the result is harmless.
- Not reported: `keep_all_intermediate_data = TRUE` with `num_cores > 1` errors with a clear message
  ("incompatible"). The help page does not mention this restriction, but the message is clear.
- Not reported: coverage differs slightly between the betaT = 0 and betaT = 0.8 cells of the same
  design/analysis (0.944 vs 0.952), so the cells do not share random numbers. The docs do not promise that they do.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area (first run).

## Cross-check packages
I used base R (`t.test`, `lm`, `binom.test`). No other package was needed.
