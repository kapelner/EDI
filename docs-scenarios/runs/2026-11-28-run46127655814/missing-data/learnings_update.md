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
