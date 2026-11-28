# Summary: missing-data scenario (EDI 1.0.5, run 2026-11-28)

## Goal
A careful applied statistician running a 60-farm trial wants five things. First, a design that uses the baseline covariates: here, blocking on `region`. Second, covariates with about 15% of their values missing (27 of 180 cells; 21 farms miss one value, 3 miss two), entered as `NA`. Third, two farms without an outcome, handled transparently. Fourth, the covariate-adjusted (OLS, Lin) and unadjusted (pooled and Welch mean difference) estimates, each with an asymptotic CI and p-value, plus randomization and bootstrap inference. Fifth, cross-checks against `lm`, `t.test`, `sandwich`, `glm`, `MASS::polr` and `survival::coxph`, and a check of what EDI does with each kind of missing value against the docs.

## What I finished
- `analysis.R` runs end to end; its output is in `analysis_output.txt`. Design: `DesignFixedBlocking(strata_cols = "region", equal_block_sizes = FALSE)`, with `"impute"` and indicators. Farms with a missing region form their own block (see F1).
- Missing outcomes: `add_all_subject_responses()` and `add_one_subject_response()` refuse `NA` with the documented message, and nothing is stored. Recording responses one at a time and skipping the two farms leaves the experiment "incomplete": OLS and MeanDiff refuse with "This experiment is incomplete as all responses aren't recorded yet." Both match the article.
- Complete-case analysis: 58 farms, one missing outcome in each arm. I re-declared the design as `DesignFixedBlocking(m = original block ids)` with `w_precomputed`. Deriving the blocks again from `region` gives the same blocks and the same imputed matrix. Results (true effect 3):
  - OLS adjusted: 2.710, 95% CI [1.321, 4.099], p = 2.7e-4.
  - Lin adjusted: 2.760, CI [1.466, 4.055].
  - Unadjusted pooled: 2.626, CI [0.838, 4.413], p = 0.0047.
  - Welch: CI [0.823, 4.429].
  - Randomization p (r = 501), randomization CIs and bootstrap CIs are all finite and contain the estimate.
- Cross-checks: everything agreed to at least 6 digits except the ordinal model.
  - OLS matches `lm` (classical SE).
  - Pooled and Welch match `t.test`.
  - `InferenceSuite` rows for 4 `formulas` (`~ .`, a subset, a subset with indicators, `~ 1`) match `lm`.
  - Poisson and logistic estimates match `glm`, and so does the logistic CI and p. The Poisson CI and p are wider than glm's Wald; this is the documented union and max with the jackknife, and the jackknife CI's lower bound equals EDI's.
  - The proportional-odds model matches `polr` to 3 digits (0.5111 vs 0.5106).
  - Cox matches `coxph` exactly, with right-censoring and imputed covariates.
- Bootstrap and randomization reuse the single imputation. A design given the pre-imputed matrix gives an identical bootstrap distribution, bootstrap CI, randomization p and randomization CI.
- Sensitivity analyses:
  - `"drop_column"`: every covariate had an `NA`, so the "adjusted" OLS silently became the unadjusted estimate (known F5).
  - Delta-shifted fills of the two missing outcomes (delta = -4, 0, +4) on the full 60-farm design give estimates of 2.41, 2.67 and 2.92, all significant.
- Each kind of missing value, against the docs:
  - Continuous, factor and blocking-column `NA` under `"impute"`: imputed, with indicators. Blocks are built from the raw column, with `NA` as its own block.
  - `"drop_column"`: removes the columns; no message.
  - `"error"`: refuses at inference. It also refuses at assignment for GreedyDOptimal, Optimal, PairSwitching and BinaryMatch. It does not refuse for Blocking or Pocock–Simon (F1). It refuses even a column that `design_formula` excludes (F2).
  - Outcome `NA`: refused for continuous; for survival it is refused unless both bounds are given.
- Also exercised:
  - Pocock–Simon with an `NA` stratum: a missing value is its own level, distinct from a literal `"NA"` level, as the docs say.
  - KK21 with `"impute"`, `"drop_column"` and `"error"`.
  - `design_formula` with `log(herd)`, an interaction, and indicators named explicitly.
  - `include_is_missing_as_a_new_feature = FALSE`.
  - Count, incidence, ordinal and survival responses with imputed covariates.
  - `InferenceSuite` on an imputed blocked design.

## New findings
- F1: under `"error"`, `DesignFixedBlocking` and `DesignSeqOneByOnePocockSimon` randomize on an `NA` stratum without an error, while the other covariate designs refuse.
- F2: `"error"` refuses an incomplete covariate that `design_formula` leaves out of the model.

## Could not do / not reached
- The missRanger → missForest fallback: I could not find a documented way to make missRanger fail.
- `summarize_blocks()` (a public method on `DesignFixedBlocking`) shows `NaN` percentages for the NA-region block. The method has no documentation on `?DesignFixedBlocking`; it is only linked as inherited from KK14. Without documented semantics, I did not log this as a finding.
- I did not run `InferenceSuite` with all of its default methods. The full default run on 3 classes × 4 formulas went past my 280 s timeout, so I limited it to `methods = c("wald","rand")`.
- All cross-check packages were available (`sandwich`, `survival`, `MASS`).

## Guesses / decisions logged
- I treated the region-missing farms as their own "region unknown" block. I accepted this because the docs do not say what happens, and the Pocock–Simon docs describe the same behavior.
- For the complete-case design I reused the original block ids (`m =`). It also re-imputes the covariates on 58 rows, so the imputed values differ slightly from those of the 60-farm design. I judged this acceptable, because the imputation still uses only the covariates.
- I chose delta-shifted outcome fills as the sensitivity analysis. EDI offers no outcome-missingness method, so this choice is mine.
- `InferenceContinOLS$new()` has no `seed` argument, unlike the generic `?Inference` signature. I used `set.seed()` / `inf$set_seed()` instead; this matches its own help page, so it is not a finding.

## Known findings re-checked
- `ds-missing-data-44358267779-f2` (filed): still reproduces. `DesignSeqOneByOneKK21` with `"error"` assigned subjects 1–5, then failed on subject 6, whose covariates are complete; `w` was then `2/3/55 NA`.
- `ds-missing-data-44358267779-f3` (closed): not regressed. A refused sequential enrollment stopped at `t = 5`, and no extra subject was enrolled.
- `ds-missing-data-44358267779-f5` (filed): still reproduces.
  - `DesignFixedGreedyDOptimal`, `DesignFixedOptimal`, `DesignFixedMatchingGreedyPairSwitching` and `DesignSeqOneByOneKK21` under `"drop_column"` assign with 0 covariate columns and no message.
  - `InferenceContinOLS` likewise silently becomes unadjusted.
  - `DesignFixedBinaryMatch` instead errors with "no covariates provided to run the binary matching algorithm". The user did provide three covariates; the message does not say that `drop_column` removed them.
- `ds-missing-data-44358267779-f7` (filed): not re-checked directly.
- `ds-missing-data-44358267779-f8` (filed): not re-checked directly; I used `lm` on `get_X()` for coefficients.
- `f1`, `f4` and `f6`: not re-checked (`f6` is dismissed).
