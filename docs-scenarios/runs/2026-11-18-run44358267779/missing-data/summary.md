# Summary: missing-data run (EDI 1.0.4 as installed)

## Goal
I simulated a field trial of 60 farms with three baseline covariates (`prior_yield`, `soil_ph`, `farm_ha`); `sim.R` uses base R with seed 2026. 27 of 180 cells (15%) are missing: 21 farms miss one value and 3 farms miss two. Two farms (7 and 40) never report an outcome. A careful applied statistician would want:
- a design that balances on the covariates despite the gaps;
- covariate-adjusted inference (OLS and Lin/HC2) and unadjusted inference (Welch), plus randomization tests and CIs;
- an honest treatment of the missing outcomes;
- certainty about what EDI does with each kind of missing value.

## What I finished (`analysis.R`)
- **Design:** `DesignFixedRerandomization(prop_acceptable = 0.1, seed = 11)`, enrolled with `NA`s as the docs say. Assignment ran, and imputation fed the balance criterion.
- **Missing outcomes:** `add_all_subject_responses()` with 2 `NA`s is refused with the documented message, and nothing is partially recorded. Following the article, I ran a complete-case analysis on the 58 farms, declared as `DesignFixediBCRD` with the observed number treated (1 missing outcome per arm). The covariates of those 58 farms were imputed again.
- **Inference**, for tau = 0.8 and tau = 0 (estimate, 95% CI, p):

  | Method | tau = 0.8 | tau = 0 |
  |---|---|---|
  | OLS | 0.9935 [0.612, 1.375], p < 1e-4 | -0.193 [-0.647, 0.261], p 0.397 |
  | Lin (HC2) | 0.981 [0.607, 1.355] | -0.183 [-0.619, 0.254], p 0.404 |
  | Welch (unadjusted) | 1.174 [0.530, 1.818], p 6e-4 | 0.011 [-0.665, 0.687], p 0.975 |
  | Randomization CI, OLS (r = 501) | [0.626, 1.396] | |
  | Randomization CI, unadjusted (r = 501) | [0.552, 1.930] | |

- **Cross-checks** (all agree to 4 digits):
  - OLS matches `lm` on `get_X_imp()`.
  - Lin matches `lm(y ~ w * centered X)` with `sandwich::vcovHC(type = "HC2")` and t(df_resid) quantiles. EDI uses t, not z, for the Lin CI.
  - Welch matches `t.test`.
  - `model_formula` fits (subset of covariates, `log(farm_ha)`, an `*_is_missing` indicator, `~ 1`) match `lm` on `get_X_imp()`.
  - The partial `drop_column` fit matches `lm` without the dropped column.
- **Documented claims checked and confirmed:**
  - Imputation ignores y: identical `get_X_imp()` for different y, and before vs after responses are added.
  - Imputation is seeded: no seed gives the same result as `seed = 1`, and a different seed gives different imputations.
  - The caller's RNG is untouched for fixed designs, including after inference.
  - Observed values are preserved.
  - Indicators appear only under `"impute"` and only when `include_is_missing_as_a_new_feature = TRUE`. The subclass default is `TRUE`, as the article says (the abstract `Design$new` shows `FALSE`).
  - `"error"` names the incomplete columns. On a covariate-using fixed design it errors at assignment; otherwise it errors at inference construction, including for unadjusted `InferenceAllSimpleAverageDiff` and `model_formula = ~ 1`.
  - Invalid `missingness_method` values are rejected clearly.
  - A missing outcome is refused for continuous and incidence responses, by `add_one_subject_response(t, NA)`, and for `NaN`. Survival `NA` without `y_Ls`/`y_Rs` gets its own clear message. Skipping two subjects gives the documented "incomplete" error.
  - Factor and character covariates with `NA` are imputed, dummy-coded and get indicators. `NaN` in a covariate is treated as missing.
- **Sequential designs** (KK14, Atkinson, Efron, Bernoulli) with `NA` covariates arriving one at a time, under all three methods: see F2, F3, F5 and F7.

## What I could not do / why
- I did not test the missRanger to missForest fallback; I don't know how to trigger a missRanger failure from the docs.
- I did not run multiple imputation of the outcome: `mice` is not installed (`sandwich`, `lmtest`, `missRanger` and `missForest` are).
- `DesignSeqOneByOnePocockSimon` needs `strata_cols`, so I left it out of the sequential loop.
- I did not check imputation quality beyond a quick RMSE. The random-forest imputation was no better than mean imputation on this small, weakly correlated data, which is expected and not a finding.

## Places I guessed
- For the complete-case design I passed `prob_T = mean(w[cc])` to `DesignFixediBCRD`, reading "declare the design that matches them (with the observed number treated)" as meaning that. With 29/29 this is 0.5 anyway.
- That the article's "EDI 1.0.4 and earlier" means the CRAN release, not this dev build that reports 1.0.4 (F6).
- For F8, I treated `InferenceContinOLS` as a "model-based class with coefficient names and a covariance matrix". The docs do not list which classes give the full table.
- The rerandomization randomization test on the complete-case data uses iBCRD reassignments, not the original rerandomization law. The article says to treat this as approximate.

## Known findings re-checked
None: `known_findings.md` lists no earlier findings for this area.
