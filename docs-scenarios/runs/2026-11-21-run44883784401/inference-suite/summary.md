# Summary: InferenceSuite and reporting an analysis (EDI 1.0.4, first run on this area)

## What I set out to do
A careful applied statistician with a finished two-arm count trial wants four things: every applicable
procedure side by side (estimate, CI, p), confidence that the suite's table is the same as fitting each
class by hand, cross-checks against standard software, and a pre-specified primary analysis justified
from the package's own validity statements, with the others as sensitivity analyses.

Data: base R, `set.seed(2026)`, n = 120, covariates `age` ~ N(50, 10) and `prior` ~ Poisson(2).
Design: `DesignFixediBCRD` with exactly 60/60 and design seed 11. Outcome: negative binomial
(size 3, so overdispersed, 30% zeros), true log rate ratio −0.4.

## What I finished
- **Suite listing.** `InferenceSuite$new(des)` found 11 classes: AverageDiff, MeanDiffPooledVar,
  Wilcox, Hurdle NB, Hurdle Poisson, NegBin, Poisson, QuasiPoisson, RobustPoisson, ZINB and ZIP.
  `unavailable_due_to_missing_packages` was empty, and the list equals
  `des$applicable_inference_class_names()`.
- **Full default run.** p-values only, 300 rows, about 6 min on 2 cores.
- **CI-enabled run.** Wald, score, LR, jackknife, randomization, and percentile/BCa bootstrap, with
  r = B = 501. It wrote HTML, PDF and JSON; the JSON parses and agrees with the R object.
- **`print()` and `summary()`.** Both used, and both compared against `results_table`.
- **Checks on the numbers.** Every finite CI contains its estimate and every p-value is in [0, 1].
- **Suite vs one-by-one.** With CIs off, every deterministic row agrees exactly (once names are
  stripped, see F12). With CIs on, 32/33 agree; the exception is the NegBin score p, which depends
  on whether the score CI ran first (F13: 0.0094925790 vs 0.0094921705). Wald, jackknife, score, LR and gradient p-values match to full precision. Resampling rows
  can't match an object's own `set_seed()` stream, because the suite derives per-task seeds. Instead I
  tested the documented promise directly: a task gives the same result alone as inside the full
  suite, and with num_cores 1 or 2. That holds.
- **Reference cross-checks:**
  - Welch t (p 0.078883) and pooled t: exact.
  - `wilcox.test` normal approximation, p 0.0197782 and HL CI: exact.
  - `MASS::glm.nb`:
    - Estimate: exact.
    - LR p (0.01323): exact.
    - Wald SE: 0.180447 vs MASS 0.179229. EDI matches the full observed-information Hessian
      (0.180454) instead of MASS's theta-fixed vcov, so this is a convention difference, not reported.
  - `glm(quasipoisson)`: SE agrees to 6 digits; EDI uses a normal reference (p 0.02653) where glm
    uses t (0.02848).
  - `sandwich` HC0 robust Poisson: p 0.025797 vs 0.025798.
  - `pscl`:
    - Hurdle NB and ZINB match the model SE.
    - Hurdle Poisson and ZIP match `sandwich::sandwich(pscl fit)` to 4 digits, as their help pages
      say.
  - Poisson: the reported p is max(model, jackknife). That is documented in `?InferenceCountPoisson`,
    so no finding, but it is why seven Poisson rows show the same p = 0.047457 while glm gives
    0.00406.
- **Options exercised:** `classes`, `exclude_classes`, `formulas` (formula list and character),
  `inference_params`, the three weighting modes (custom checked by hand against the Cauchy
  formula), `combined_evidence_estimands`, `basic_bootstrap`, `alpha`, the `B` guards,
  `max_secs_per_class`, `model_formula`, `html`/`pdf`/JSON/`plots`, and `num_cores` 1 and 2. Most
  error messages were accurate and helpful.
- **13 new findings in findings.md.** The most serious:
  - F3: `max_secs_per_class` kills the R session.
  - F11: `set_num_cores(2)` together with suite `num_cores = 2` silently breaks randomization tests
    and the rest of the session.
  - F2: inconsistent estimand labels drive the Combined Evidence grouping.
  - F1/F7: many NA rows marked `ok` with no explanation.

## The analysis I would report, and why
**Primary analysis:** covariate-adjusted negative binomial regression (`InferenceCountNegBin`),
adjusted for age and prior, with the treatment effect tested by a **randomization test** (r = 1000,
inference seed 1) and a 95% CI from test inversion. Why, from the docs:
- `vignette("procedure-trust")`: "If a finite-sample procedure fits your question, prefer it." The
  `rand` procedure is the only one with `regime = "finite_sample"`, size order "exact" and
  `rate_basis = "theory"` (also shown by `get_procedure_validity()`). Every asymptotic cell for these
  classes is `assumed_default` or `unknown`.
- NegBin models the overdispersion. `?InferenceCountPoisson` itself points to NegBin for that, and
  NegBin is a "regular" class. The ZI classes are in the "mixture, rate unknown" list, and the hurdle
  classes estimate a different, conditional-on-positive estimand.
- The randomization test is valid under the sharp null whether or not the NB model is right. The
  article says to state the null; this is the sharp null.

Results (from analysis.R):

| Role | Procedure | Rate ratio (95% CI) | p |
|---|---|---|---|
| primary | randomization, r = 1000 | 0.639 (0.421 to 0.860) | 0.012 |
| sensitivity | Wald | 0.639 (0.449 to 0.910) | 0.013 |
| sensitivity | likelihood ratio | 0.639 (0.445 to 0.909) | 0.013 |
| sensitivity | BCa bootstrap, B = 501 | 0.639 (0.466 to 0.933) | 0.004 (at the floor 2/501; report as ≤ 0.004) |

The estimated log rate ratio is −0.448; the true value is −0.4 and it is covered. The procedures
agree. I did not report the Combined Evidence p-value (0.021 default, 0.046 CI run), as the help page
warns against reading it as an effect, and because of F2.

## What I could not do, and why
- `lik_ratio_bartlett_exact` and `exact` are not offered by any count class here, and I didn't
  request `param_boot`/`rand_bootstrap` CIs or the slow paths, for time reasons.
- I tried no other designs (KK, blocked, unequal `prob_T`) with the suite.
- I could not inspect `EDI_INFERENCE_SUITE_METHOD_SENTINELS` (not exported, F10). I got the list
  from an error message instead.
- No cross-check package was missing (MASS, sandwich, lmtest, pscl and coin are installed;
  countreg is not, and wasn't needed).

## Where I had to guess
- **Design.** "A finished two-arm trial" doesn't name one. I chose complete randomization with fixed
  60/60 (iBCRD) as the most common case.
- **Primary class.** NegBin over Poisson, Quasi or Robust Poisson, from the dispersion argument
  above. The randomization p-value of all four log-rate-ratio classes was 0.024–0.040 in the suite,
  so the conclusion does not hinge on it.
- **Default bootstrap type.** I assumed BCa, as `vignette("procedure-trust")` and the reporting
  article state; `basic_bootstrap = TRUE` ran `percentile` as the "first" type.
- **Cores.** I first used `set_num_cores(2)` as the CI instructions suggest, then dropped it because
  of F11. The suite's own `num_cores = 2L` keeps within 2 cores.
- **Bad-type row (F4).** Which bootstrap flavour actually ran for the misspelled type is unknown;
  nothing reports it.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area (first run).
