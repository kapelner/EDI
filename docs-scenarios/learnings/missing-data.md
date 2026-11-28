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

## Run 2026-11-28 (run 46127655814, 4adb1f1d, ok)

## Covered
- `DesignFixedBlocking` with `NA` in the blocking column (factor and continuous). `NA` forms its own block under all three `missingness_method` values, even `"error"` (F1). A continuous stratum column with `NA` gives the bins plus one NA block. With `strata_cols = NULL`, the NA block makes `equal_block_sizes = TRUE` fail, with a clear message.
- `DesignSeqOneByOnePocockSimon` with an `NA` stratum: assignments are identical under impute, drop_column and error. `NA` is a level distinct from a literal `"NA"`, as documented (checked with `p_best = 1`). A numeric strata column is refused.
- Fixed `DesignFixedGreedyDOptimal`, `DesignFixedOptimal`, `DesignFixedMatchingGreedyPairSwitching` and `DesignFixedBinaryMatch` under all three methods: `"error"` refuses at assignment.
- KK21 under all three methods: `"error"` reproduces known f2. `get_X_imp()` values for an early subject drift as later subjects arrive.
- Bootstrap CIs, randomization p-values and randomization CIs reuse the single imputation: results are identical to a design given the pre-imputed matrix.
- `InferenceSuite$run_all_inference(formulas = ..., methods = c("wald","rand"))` on a blocked, imputed, complete-case design matches `lm` row by row.
- `design_formula`: a transform of an imputed column (imputed first, then transformed), an interaction, and indicators named in the formula. `"error"` with an excluded incomplete column refuses (F2).
- Count (Poisson), incidence (logit), ordinal (proportional odds) and survival (Cox with right-censoring) responses on imputed covariates match glm, polr and coxph.
- Survival missing outcomes: a subject with `ys`, `y_Ls` and `y_Rs` all `NA` is refused ("Subject 2 has no response..."), and a half-specified bound is refused.
- Complete-case route on a blocking design via `DesignFixedBlocking(m = blk[cc], ...)`.

## Not reached
- The missRanger → missForest fallback (I found no documented way to trigger it).
- `DesignFixedBlockedCluster` or `DesignFixedCluster` with `NA` in the cluster or strata columns.
- `InferenceIncidCMH` and `InferenceIncidExtendedRobins` on a blocking design whose blocks come from an `NA` stratum.
- `summarize_blocks()` semantics for an NA block (it shows `NaN` percentages; the method is undocumented on `?DesignFixedBlocking`).
- `InferenceSuite` with the default `methods` on an imputed design (too slow for a 5-minute call with 3 classes × 4 formulas).
- Sequential `DesignSeqOneByOneEfron` or `iBCRD` with `design_formula` excluding an incomplete column under `"error"`.

## Workarounds
- Complete-case analysis on a blocking design: pass the original `get_block_ids()[cc]` as `m =`, with `n = length(cc)` and `w_precomputed = w[cc]`. Deriving the blocks again from `strata_cols` gives the same blocks here.
- For `"error"` with unused incomplete columns, pass only the modeled columns to `add_all_subjects_to_experiment()`.
- Concrete inference classes (for example `InferenceContinOLS`) take no `seed` argument, although `?Inference` `$new()` lists one: use `inf$set_seed()` or `set.seed()`.
- `run_all_inference()` needs `screen = TRUE` or `html = TRUE`; wrap it in `capture.output()` to keep logs short.

## Confusing docs
- `?DesignFixedBlocking`: nothing says what an `NA` in a `strata_cols` column does. (It becomes its own block, built from the raw data, not the imputed matrix.) The Pocock–Simon page does document this.
- With an explicit `design_formula`, the `*_is_missing` indicators enter only if you name them, even with `include_is_missing_as_a_new_feature = TRUE`. With `~ .` they are added automatically. Neither `?Design` nor the article says so.
- `?InferenceCountPoisson`: `compute_asymp_confidence_interval()` is the union with the jackknife-Wald interval, so it is asymmetric around the estimate and wider than `glm`'s Wald. This is documented, but easy to mistake for a mismatch.
