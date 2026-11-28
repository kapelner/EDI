# Summary: factorial, run 2026-11-28 (EDI 1.0.5 installed)

## Goal
A 2 x 2 email test: subject line (A) x send time (B), 200 customers, binary purchase. For each factor, a careful analyst wants the main effect (averaged over the other factor) as a risk difference with a CI and p-value, plus the A x B interaction. The analyst also needs to know exactly which estimand each EDI object targets.

## Done
- Design and assignment as the article's 2 x 2 recipe describes: `DesignFixedFactorial(list(subject_line = 2))` for A, then `DesignFixedBlocking(strata_cols = "A")` for B. This gave 50 per cell. Simulated outcome: P = .15 + .12A + .06AB + .05 loyal (true main A = .15, main B = .03, interaction .06 on the RD scale).
- Main effects: each factor declared as `DesignFixedBlocking` on the other factor, with `w_precomputed`. Classes run: RiskDiff, CMH, GCompRiskDiff/RiskRatio, LogRegr (all 3 estimands), ModifiedPoisson, LogBinomial, Probit, SimpleAverageDiff, MiettinenNurminen and ExactFisher, plus InferenceSuite (`methods = c("wald", "exact")`).
- Cross-checks, all agreeing to at least 6 digits:
  - RiskDiff vs `lm` + `sandwich::vcovHC(HC0)`
  - LogRegr vs `glm` logit
  - ModifiedPoisson vs `glm` Poisson + HC0
  - LogBinomial vs `glm` log link
  - GComp RD vs a hand standardization; its SE matches HC0 delta-method
  - LogRegr `marginal_mean_diff` SE matches the delta method with the model vcov, as each help page states
  - CMH vs a hand MH RD
  - ExactFisher on the blocked design vs `mantelhaen.test(exact = TRUE)`
- Main effect A: RD 0.179, 95% CI [0.066, 0.292], p = 0.0019. Main effect B: RD 0.041, CI [-0.073, 0.155], p = 0.48.
- Interaction (outside EDI, as the article says): LPM HC0 0.32 (CI 0.09 to 0.55, p = 0.006); logistic 2.00 log-OR (p = 0.010). The sample interaction is much larger than the true 0.06 because of noise in the (A = 0, B = 1) cell.
- Resampling: percentile and default BCa bootstrap, Bayesian bootstrap, and the jackknife with every documented unit.
- Options earlier runs did not reach:
  - `prob_T = 0.3` in the B step (30 of 100 treated in each A level; redraws keep that)
  - `m =` explicit blocks, including its validation errors
  - `missingness_method` = impute / drop_column / error (drop_column matches `lm` without the column)
  - NA in the strata column
  - NA incidence response (clear error)
  - unbalanced `w_precomputed`
  - `n = NULL` on DesignFixedFactorial with odd n
  - `factors` validation (changed file)
- Coverage simulation (300 reps, nominal 95%, MC SE 0.013). Main effect A: RiskDiff 0.927, CMH 0.950, GComp 0.927. B: 0.937, 0.947, 0.940. Near nominal, not reported.

## New findings (findings.md)
- F1: ExactFisher and ExtendedRobins refuse DesignFixedFactorial although the docs say it works with every Inference class (both accept iBCRD).
- F2: the warning for jackknife `unit = "observation"` points to `"block"` (NA with 2 blocks), never to the working `"observation_within_block"`.
- F3: estimand labels conflict. The suite calls the adjusted logistic coefficient "marginal" and the Fisher OR "conditional", and `get_estimand()` calls GComp's marginal RD "conditional".
- F4: GComp `get_summary()` prints unlabelled logistic coefficients and leaves out the RD/RR.
- F5: ExactFisher ignores `m =` blocks and silently runs a pooled test (CMH uses them).
- F6: a balanced factorial design accepts a 150/50 `w_precomputed` silently, and its randomization test then uses 100/100 redraws.
- F7: `get_w_factorial()` row names look like subject ids but are not.

## Could not do / why
- There is no EDI estimate of the interaction; this is documented, so I did it with lm/glm. A `model_formula` containing `w` is refused ("variables not present").
- A randomization test for the binary outcome is impossible (known f1).
- I ran the full `InferenceSuite$run_all_inference()` with default methods (323 rows, ETA about 25 min, over the per-call budget) and stopped it. I re-ran it restricted to `methods = c("wald", "exact")`.
- `marginaleffects` and `emmeans` are not installed (not needed). sandwich, lmtest, DescTools and coin are installed.

## Guesses / decisions
- "Main effect" = the article's definition (the effect averaged over the levels of the other factor). In this balanced design the adjusted RD with the other factor as a covariate estimates it.
- I took the estimand of each class from its own help page, not from `get_estimand()` or the suite column (see F3).
- I added covariates age and loyal to make adjustment matter. This is not in the task.
- I accidentally printed one design *instance* (R6 object print shows field values and method signatures, not bodies) while testing `m =`. I did not use anything from it.

## Known findings re-checked
- `ds-factorial-44358267779-f1` (filed): still reproduces on both DesignFixedBlocking and DesignFixedFactorial: "Randomization tests are not supported for incidence. Use Zhang method." The rand CI now gives a longer "temporarily disabled" message that points to an internal `R/package_metadata/...md` path.
- `ds-factorial-44358267779-f2` (filed): still reproduces: `type = "Zhang"` gives "Randomization type dispatch is only supported for incidence outcomes."
- `ds-factorial-44358267779-f3` (filed): now behaves differently. The default BCa bootstrap CI/p-value (B = 501) and the default jackknife (`auto` = observation_within_block) give finite values on the 2-block design. `unit = "block"` is still NA, and its warning still recommends a randomization test that errors for incidence (see new F2 for the related "observation" message).
- `ds-factorial-44358267779-f4` (closed): fix holds. `list(a = 2.5)` now errors: "factors$a must be a whole number of levels >= 2 (got 2.5)". Inf, c(2,2), 1, character, NA and logical are also refused.
- `ds-factorial-44358267779-f6` (closed): not re-triggered. The NA-in-strata unequal-block message now correctly says "strata_cols was named without B_target", and B_target was not passed.
- `ds-factorial-44358267779-f7` (closed): not re-tested with zero events this run.
