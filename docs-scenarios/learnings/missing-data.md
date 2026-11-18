# Learnings: missing-data

Appended by each weekly docs-only scenario run.

## Run 2026-11-18 (run 44358267779, 4ce2b712, ok)

## Covered
- All three `missingness_method` values on `DesignFixediBCRD`, `DesignFixedRerandomization` (`prop_acceptable`), `DesignFixedGreedy`, and sequentially on `DesignSeqOneByOneKK14`, Atkinson, Efron and Bernoulli.
- `include_is_missing_as_a_new_feature` set to TRUE and to FALSE.
- `model_formula` on imputed covariates: a subset of covariates, a transform, an `*_is_missing` indicator, `~ 1`, an unknown name, a dropped column, and an all-`NA` column.
- Covariate edge cases: an all-`NA` column, a column with a single observed value, a row with every covariate `NA`, `NaN`, `Inf`, and factor/character columns with `NA`.
- Outcome edge cases: `NA`, `NaN`, `Inf`, a short vector, a character vector, one-at-a-time entry with skipped subjects, incidence `NA`, and survival `NA` without bounds.
- Imputation independent of y, seeded (no seed is the same as `seed = 1`), RNG untouched (fixed designs), observed values preserved.
- Cross-checks against `lm`, `sandwich` HC2 and `t.test` all agree (Lin's CI uses t quantiles with the residual df).
- Complete-case route on 58 of 60 farms, with randomization CIs and p-values (r = 501).

## Not reached
- The missRanger to missForest fallback.
- `DesignSeqOneByOnePocockSimon` (needs `strata_cols`) and KK21 with missing covariates.
- Non-continuous responses (count, ordinal, proportion) with missing covariates.
- `InferenceSuite` on a design with imputed covariates.
- Blocking designs where the blocking column itself has `NA`.
- `DesignFixedGreedyDOptimal` and `DesignFixedOptimal` with imputed covariates.
- Bootstrap CIs (do resamples re-impute or reuse the imputed matrix?).
- `get_X_imp()` changing for earlier subjects as sequential subjects arrive, and whether that alters past assignments' reproducibility.

## Workarounds
- Missing outcomes: drop those subjects and build a new `DesignFixediBCRD(n = n_cc, prob_T = mean(w[cc]))` with `w_precomputed = w[cc]`.
- To see covariate coefficients (`get_summary()` shows only the treatment row): run `lm(y ~ w + ., data = as.data.frame(des$get_X_imp()))`. This reproduces EDI's OLS exactly.
- Wrap sequential `add_one_subject_to_experiment_and_assign()` with your own `anyNA()` check: a failed call still enrolls the subject (F3).

## Confusing docs
- The article and NEWS refer to "EDI 1.0.4 and earlier" as buggy, but the installed dev build reports 1.0.4.
- `?Design` `$new()` shows `include_is_missing_as_a_new_feature = FALSE`, while every concrete design defaults to `TRUE`. The article states the subclass default correctly.
- `?Inference` `get_covariates()` / `get_analysis_data()` return all covariates (including indicators) even when `model_formula` selects a subset. The docs do not say whether extension classes should honor the formula themselves.
- Repeated identical indicator columns (two covariates missing on exactly the same rows) are de-duplicated without a message: only `a_is_missing` remains. This is probably deliberate, but it is undocumented.
- Under `"error"`, sequential designs check only once the covariate model kicks in (after a burn-in of about p + 3 subjects); `?Design` says "as soon as any missing value is detected".
