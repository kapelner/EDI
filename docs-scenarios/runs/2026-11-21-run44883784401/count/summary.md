# Summary: count outcomes (EDI 1.0.4), asthma-program ED-visit trial

## Goal
A careful applied statistician analysing a year of emergency-visit counts per child would want four things:
- a rate ratio, with CI and p-value, that is robust to over-dispersion and excess zeros;
- proper handling of unequal follow-up (an offset, i.e. exposure);
- an honest choice between Poisson, NB, quasi/robust, zero-inflated and hurdle models;
- agreement with glm / MASS::glm.nb / pscl to at least 3 digits.

## Data and design
- n = 160, simulated in base R with a fixed seed.
- Follow-up U(0.25, 1) years.
- Covariates: prior-year visits (Poisson(1.5)) and age.
- Truth: ZINB with 30% structural zeros, NB size 0.9, true log RR -0.5. 61% of counts are zero; max 7.
- `DesignFixedBernoulli(prob_T = 0.4)` gave unequal arms (68 treated / 92 control).
- Extra designs:
  - n = 24 null-effect trial on `DesignFixediBCRD(prob_T = 1/3)`;
  - n = 30 trial in which every control count is zero (separation);
  - n = 100 and n = 120 `DesignSeqOneByOneKK14` sequential matched trials.

## Finished, with cross-checks (all to ≥ 3 digits unless noted)

**Fixed-design classes**
- Poisson: estimate and model SE match `glm` to 7 digits.
  - The reported CI and p-value are the documented union/max with the jackknife-Wald.
  - The jackknife SE equals a manual delete-1 jackknife (0.32638). The jackknife CI is centred at the bias-corrected estimate, as documented.
  - LR/score p-values are masked by the max-with-jackknife rule.
- QuasiPoisson: SE matches `glm(quasipoisson)` exactly.
  - EDI uses a normal reference (p = 0.0522); glm's summary uses t (0.0540). Both agree with `confint.default`.
- RobustPoisson: identical to `sandwich::vcovHC(type = "HC0")`.
- NegBin
  - The estimate matches `glm.nb` to 6 digits.
  - The SE is 0.27952 vs glm.nb's 0.27803. This is not a bug: EDI uses the joint observed information, and my numerical Hessian reproduces 0.2795213 exactly. glm.nb uses expected information.
  - The LR p-value matches the MASS LR test exactly (0.03943812).
- ZIP
  - The estimate matches `pscl::zeroinfl` to 6 digits.
  - The Wald SE is the sandwich SE (matches `sandwich::sandwich(zeroinfl)` to 6 digits), as documented. `get_summary()` shows the model SE instead (F2).
  - The marginal estimands (mean diff and log ratio) match my numeric delta method with the sandwich to 6 digits.
- Hurdle Poisson: the same picture as ZIP (sandwich Wald; F2 applies).
- Hurdle NB: the estimate and SE match `pscl::hurdle(dist = "negbin")` to 5 digits. `get_summary()` shows NA SEs (F3).
- ZINB, full zero formula
  - EDI flags the zero part as separated and reports -0.7096, against pscl's -0.6891.
  - pscl from 30 random starts and glmmTMB also run off to a ridge (zero coefficients in the thousands). EDI's verdict looks right; this is not a reference mismatch.
  - With the zero formula `~ w`, EDI and pscl agree to 4 digits.
- Small-n ZIP (n = 24): EDI gives 1.297, pscl 0.109. EDI's count part attains log-likelihood ≥ -25.19 vs pscl's -27.79, so EDI found the better optimum. Not a finding.

**Estimands, tests and resampling**
- The Poisson marginal rate difference (g-computation) and its delta-method SE match my manual computation exactly. The CI is unioned with the jackknife.
- Randomization p-values and bootstrap CIs agree with manual versions within Monte Carlo error. `set_seed()` reproduces them.
- InferenceSuite, cookbook call: runs and lists 17 rows.

**KK sequential matched designs**
- KK GLMM: the estimate matches `lme4::glmer(nAGQ = 25)` to 5 digits. The Wald SE is the jackknife SE, not the model SE (F5).
- `lik_ratio_bartlett_approx` is listed as supported but fails through `compute_asymp_*` (F6).
- KK GEE matches `geepack::geeglm(exchangeable)` to 3 digits (-0.7180 vs -0.7176; SE 0.3321 vs 0.3323). Its reported CI and p-value are wider than the GEE SE implies (design-conservative). I did not check whether that is documented.
- KK conditional-Poisson one-likelihood and the KK hurdle classes ran, but I did not cross-check them (no direct reference package).

## New findings (details in findings.md)
- F1: `model_formula_zero = ~ 1` and `model_formula_hurdle = ~ 1` silently fit `~ w`.
- F2: For ZIP and hurdle Poisson, the `get_summary()` SE and p (model-based) disagree with `compute_asymp_*` (sandwich).
- F3: HurdleNegBin `get_summary()` gives all-NA SEs and uses different labels from the other two-part classes.
- F4: `offset()` in `model_formula` is accepted and echoed back but silently ignored (Poisson, NB, ZIP).
- F5: KK GLMM's "model-based" Wald SE is actually the jackknife SE; `get_summary()` differs between `use_rcpp` TRUE and FALSE.
- F6: KK GLMM lists `lik_ratio_bartlett_approx` but `compute_asymp_*` reject it.
- F7: When every control count is zero, Poisson, QuasiPoisson and RobustPoisson give a randomization p of exactly 1 (should be about 0.01). After the separated fit, every randomization refit returns the observed estimate.

## Could not do / why
- An exposure offset: EDI offers none (cookbook: "planned addition — see ROADMAP.md"). ROADMAP.md is not shipped in the installed package, so I could not read it.
  - Decision: I used log(follow-up) as an ordinary covariate and cross-checked against glm with the same covariate.
  - Consequence: this estimates the exposure coefficient rather than fixing it at 1, so the reported RR is not strictly a per-person-year RR.
- I did not test the Bartlett-exact, parametric-bootstrap CI or Bayesian bootstrap on count classes (time). The Bartlett-approx CI on KK GLMM takes about 2 minutes.
- No package was missing: MASS, pscl, sandwich, glmmTMB, geepack and lme4 were all available. countreg is not installed and was not needed.

## Guesses made
- `model_formula` takes covariates only (`~ prior + age`). Including `w` or `y` errors ("not present in the available covariates"), so I concluded the treatment is always added by EDI.
- From the wording of the class pages, I took the reported ZI/hurdle estimand to be the count-part coefficient, not the effect on E[Y].
- I used `get_matching_cluster_ids()` to get the KK pair ids. It appears only in the KK14 example, not in the documented method list.
- The ZINB "separated" verdict on the main data I judged correct, from the pscl and glmmTMB ridges. I did not prove that EDI's log-likelihood is the global maximum.

## Known findings re-checked
None: known_findings.md lists no earlier findings for this area (first run).
