# Per-Class Result/Effect Plots for Every `Inference*` Class

> **Depends on:** `inference_suite_interactive_reporting.md` (every class
> already gets a generic CI forest-plot row for free — this plan proposes
> only what's genuinely *additional* to that, never a re-description of
> it) and shares its ggplot2/HTML/`plotly` reporting conventions rather
> than inventing a new visual language. No duplicated *work* with
> `model_diagnostics_framework.md` (assumption-*checking* plots — did the
> model's own assumptions hold) — cross-referenced, not re-described.
> **A real, structural dependency, not merely "non-overlapping," on
> `survival_curve_visualization.md`** for six classes: Weibull's
> fitted-curve overlay (`InferenceSurvivalWeibullRegr`,
> `InferenceSurvivalKKWeibullMarginal`), Gehan-Wilcox/log-rank's statistic
> annotation (`InferenceSurvivalGehanWilcox`, `InferenceSurvivalLogRank`),
> and RMST's τ-shading (`InferenceSurvivalKMDiff`,
> `InferenceSurvivalRestrictedMeanDiff`) do not re-propose the raw per-arm
> Kaplan-Meier plot — they are additive layers (an overlay, an annotation,
> a shaded region) drawn *on top of* that exact plot object once it
> exists. If `survival_curve_visualization.md` is not built, these six
> entries have nothing to attach to; they are gated on it, not merely
> adjacent to it — see each subsection's own note and TODO-3 below. (Cox/
> stratified Cox's adjusted survival curve is a separate, independently
> computable covariate-adjusted display, not a layer on the raw KM plot —
> a real relationship, but not this same load-bearing dependency.)
> **Release target: v3.0.0** (user decision
> 2026-09-11, added as its own item — see `release_v3_0_0.md`). (Global
> ordering: see `_master.md`.)

Written 2026-09-11 (user request: "each model can plot more than just
diagnostics... for every single Inference class we have, do a lit search
and see what plots people have decided are useful").

## Scope

`model_diagnostics_framework.md` answers "does this model's own
assumptions hold" — the earlier session's diagnostics work.
`inference_suite_interactive_reporting.md` gives every class a shared
CI-forest-plot row. Neither answers a different, equally real question:
**what plot would a paper or report built on this specific kind of model
actually include to communicate its *result*** — a predicted-effect curve,
a stratified outcome display, a component decomposition — the thing a
reader wants to *see*, not the thing a reviewer wants to *check*. This
plan is that catalogue, one section per model family, one subsection per
concrete class.

**Coverage.** Verified against `R/package_tests/public_api_inventory.csv`
and `infer_inference_likelihood_tier()`
(`R/EDI/R/inference_class_registry.R:623`) — the same authoritative source
`model_diagnostics_framework.md` §3B/§3C used: EDI ships **102 concrete
`Inference*` classes** (`InferenceSuite` itself excluded — it is the
orchestrator, not a fittable model). Grouped into **19 model families**
(13 with a real likelihood, matching §3B's families exactly, plus 6
`likelihood_tier = "none"` families matching §3C's catalogue) rather than
102 independent literature searches, since classes differing only by
variance-estimation method (`IVWC` vs. `OneLik`) or a KK-matched-design
wrapper share an identical fitted-model shape and therefore an identical
result plot — each such sibling cross-references the section that
actually derives the plot rather than repeating it. Every one of the 102
classes gets its own `###` subsection below regardless, even when its
content is "same as `X`, see §..." — completeness is auditable class by
class, not just family by family.

**Correction carried over from `model_diagnostics_framework.md`:** while
re-verifying the class roster for this plan, a gap surfaced in that file's
§3C none-tier catalogue (35 classes listed instead of 36 —
`InferenceSurvivalKKRankRegrIVWC` was missing from the "Rank /
distribution-free tests" row) and has been fixed there directly
(2026-09-10). The family list below already reflects the corrected count.

---

## Poisson / quasi-Poisson / robust-Poisson

Grounding convention: marginal/predicted-effect plots for GLM count models
follow the `ggeffects::ggpredict()` / `effects::allEffects()` convention
(Lüdecke 2018, *ggeffects: Tidy Data Frames of Marginal Effects from
Regression Models*, *JOSS* — `NEEDS VERIFICATION` exact citation) — fitted
rate/count as a function of one covariate, others held at representative
values, with a confidence band. This is the standard way a Poisson-family
regression's substantive effect is shown in a paper, distinct from
`model_diagnostics_framework.md`'s overdispersion/zero-inflation
*assumption checks* for this same family.

### `InferenceCountPoisson`
- Predicted-rate-vs-covariate marginal-effect plot (`ggeffects` convention),
  CI band, other covariates at representative values.
- Note, not a new plot: if `compute_estimate()` returns a log-rate-ratio,
  an exponentiated-scale (incidence-rate-ratio) axis is better framed as a
  transform option on `inference_suite_interactive_reporting.md`'s
  existing suite-level forest plot than as a second forest plot here.

### `InferenceCountQuasiPoisson`
Same plot as `InferenceCountPoisson` — quasi-likelihood changes only the
SE, not the fitted mean-model shape being plotted.

### `InferenceCountRobustPoisson`
Same plot as `InferenceCountPoisson` — sandwich SE only.

### `InferenceCountKKCondPoissonOneLik`
Same predicted-rate-vs-covariate plot as `InferenceCountPoisson`,
conditional on matched-set membership (KK design) rather than
unconditional; no new plot type.

## Negative binomial / ZINB / hurdle

Grounding convention: Zeileis, Kleiber & Jackman (2008), "Regression
Models for Count Data in R," *Journal of Statistical Software*, 27(8)
(`NEEDS VERIFICATION` page numbers) — the paper introducing `pscl`'s
`zeroinfl()`/`hurdle()` and their companion visualization convention:
decompose a two-part model into its two component curves rather than
plotting only the overall mixture mean.

### `InferenceCountNegBin`
- Predicted-count-vs-covariate marginal-effect plot, same convention as
  the Poisson family above.

### `InferenceCountZeroInflatedNegBin`
- **Two-part decomposition plot**: `P(structural zero)` vs. covariate,
  and conditional mean count `| not a structural zero` vs. covariate, as
  two panels (Zeileis/Kleiber/Jackman convention).
- Predicted-count-vs-covariate plot for the overall mixture mean.

### `InferenceCountZeroInflatedPoisson`
Same two-part decomposition as `InferenceCountZeroInflatedNegBin` — Poisson
count component instead of NegBin.

### `InferenceCountHurdleNegBin`
- **Two-part decomposition plot**: `P(cross the hurdle, i.e. Y > 0)` vs.
  covariate, and conditional mean count `| Y > 0` vs. covariate — the
  hurdle variant of the same convention (structurally a truncated-count
  second stage rather than zero-inflation's mixture, same visualization
  idea).

### `InferenceCountHurdlePoisson`
Same as `InferenceCountHurdleNegBin` — Poisson count component.

### `InferenceCountKKHurdlePoissonIVWC` / `InferenceCountKKHurdlePoissonOneLik`
Same plots as `InferenceCountHurdlePoisson` — matched-design (KK)
variance estimation only differs between the two; not a plotting
difference.

## OLS / robust regression

Grounding convention: `effects::allEffects()`/`ggeffects` predicted-effect
plots as above, plus the added-variable (partial-regression) plot —
Y-residual vs. X-residual after partialling out other covariates, Cook &
Weisberg's construction, `car::avPlot()`'s convention — which isolates a
single coefficient's effect visually. Distinct from
`model_diagnostics_framework.md`'s OLS row (residual structure/
heteroskedasticity/influence, a diagnostic use of a differently-built
residual plot), even though both involve residuals.

### `InferenceContinOLS`
- Predicted-Y-vs-treatment effect plot (`ggeffects` convention), CI band,
  other covariates at representative values.
- Added-variable (partial-regression) plot for the treatment coefficient
  (`car::avPlot()` convention).
- No-covariate case (`Y ~ w`): a direct scatter with group means/fitted
  line — the simplest, most literal version of the above two.

### `InferenceContinLin`
Same two plots as `InferenceContinOLS`. Caption note: Lin's (2013)
estimator regresses on *centered* covariate-by-treatment interactions —
the added-variable plot should partial out using that same centering, not
plain OLS residuals, to actually match what was fit.

### `InferenceContinKKOLSIVWC` / `InferenceContinKKOLSOneLik`
Same plots as `InferenceContinOLS` — matched-design (KK) variance
estimation only differs.

### `InferenceContinRobustRegr`
Same two plots as `InferenceContinOLS`. Caption note: use the
robust-regression fit's own (downweighted) residuals for the
added-variable plot, not OLS residuals, so the plot matches what was
actually fit rather than a different estimator.

### `InferenceContinKKRobustRegrIVWC` / `InferenceContinKKRobustRegrOneLik`
Same plots as `InferenceContinRobustRegr` — matched-design variance
estimation only differs.

## Quantile regression, joint-likelihood (`OneLik`)

Grounding convention: Koenker & Bassett (1978), *Econometrica* (already
cited in this session's `model_diagnostics_framework.md`), and Koenker
(2005), *Quantile Regression*, Cambridge — the `quantreg` package's own
plotting conventions (`plot.summary.rqs()`, fitted-quantile-curve
overlays). Two plots, genuinely different from anything already scoped:

- **Coefficient-vs-τ plot**: the treatment coefficient's estimate (with CI
  band) plotted as a function of the quantile level τ across a grid (e.g.
  0.1, 0.25, 0.5, 0.75, 0.9) — shows whether the treatment effect is flat
  across the outcome distribution or genuinely heterogeneous by quantile.
  The signature quantile-regression communication plot; nothing else
  scoped this session shows this.
- **Fitted-quantile-curves fan plot**: for a chosen covariate, the fitted
  `Y(τ | X)` at several τ as a fan of curves — `quantreg::plot.rq()`
  convention.

### `InferenceContinKKQuantileRegrOneLik`
- Coefficient(treatment)-vs-τ plot with CI band.
- Fitted-quantile-curves fan plot for a chosen covariate.

### `InferencePropKKQuantileRegrOneLik`
Same two plots. Caption note: axis scaling should respect the `[0, 1]`
response boundary (a proportion outcome) rather than an unbounded default.

## Quantile regression, IVWC (variance-only)

Same fitted quantiles as the joint-likelihood family above (`rq()`
computes the point estimates identically) — only the CI/variance
estimation method differs (IVWC vs. the `OneLik` joint likelihood's own).
Same two plot types, no new content; cross-referenced rather than
repeated.

### `InferenceContinQuantileRegr`
Same plots as `InferenceContinKKQuantileRegrOneLik` (above) — IVWC
changes only how the CI is estimated, not what is plotted.

### `InferenceContinKKQuantileRegrIVWC`
Same as `InferenceContinQuantileRegr` — matched-design (KK) wrapper only.

### `InferencePropQuantileRegr`
Same plots as `InferencePropKKQuantileRegrOneLik` (above).

### `InferencePropKKQuantileRegrIVWC`
Same as `InferencePropQuantileRegr` — matched-design wrapper only.

---

## Cox PH / stratified Cox

Grounding: `survminer::ggadjustedcurves()` is the de facto R convention for
a model-based (covariate-adjusted) survival curve, distinct from
`survival_curve_visualization.md`'s raw per-arm KM curve (no covariate
adjustment) and from the Schoenfeld-residual diagnostic already in
`model_diagnostics_framework.md`. The hazard-ratio point estimate + CI is
already covered generically by `InferenceSuite`'s CI forest plot — not
re-proposed here.

### InferenceSurvivalCoxPHRegr
- Adjusted survival curve (`ggadjustedcurves()` convention): predicted
  S(t) by arm, covariates fixed at representative values, with
  confidence band.
- Cumulative hazard plot (the complementary log-log-scale companion,
  `survminer::ggsurvplot(fun = "cumhaz")` convention) — standard
  alongside the survival curve in most Cox reporting workflows.

### InferenceSurvivalStratCoxPHRegr
- Same two plots as `InferenceSurvivalCoxPHRegr`, faceted/colored by
  stratum — stratified Cox's separate baseline hazard per stratum should
  be visible in the adjusted curve itself.

### InferenceSurvivalKKLWACoxPHIVWC / InferenceSurvivalKKLWACoxPHOneLik
- Same as `InferenceSurvivalCoxPHRegr` — identical model form; these
  differ only in variance-estimation method (IVWC vs. joint one-stage
  likelihood), which does not change what is plottable.

### InferenceSurvivalKKStratCoxPHIVWC / InferenceSurvivalKKStratCoxPHOneLik
- Same as `InferenceSurvivalStratCoxPHRegr` — KK-matched-design wrapper +
  variance-method variants of the same stratified-Cox model form.

## Weibull parametric survival

Grounding: the fitted parametric survival curve overlaid directly on the
raw KM curve is the standard way a parametric survival model's fit is
communicated — distinct from the Cox-Snell residual diagnostic
(`model_diagnostics_framework.md`, which checks the same fit numerically)
by showing the actual fitted curve shape, including extrapolation beyond
the last observed event time (a genuine capability the KM/Cox curves
don't have).

### InferenceSurvivalWeibullRegr
- Fitted parametric survival curve overlaid on the raw per-arm KM curve
  (`survival_curve_visualization.md`).
- Hazard function plot h(t) — Weibull's hazard is monotone
  increasing/decreasing/constant depending on shape `k`; plotting it
  directly communicates whether risk rises or falls over time more
  explicitly than the survival curve alone.

### InferenceSurvivalKKWeibullMarginal
- Same as `InferenceSurvivalWeibullRegr` — same model form under the KK
  marginal/matched-design wrapper.

## Dependent-censoring transform survival

Grounding: `NEEDS VERIFICATION` — a niche bivariate-transform (copula
linking failure and censoring times) model with no single canonical
plotting convention I can confidently cite; proposed from first
principles of what the model estimates.

### InferenceSurvivalDepCensTransformRegr
- Fitted survival curve under the estimated dependence structure vs. the
  naive independence-assumption KM curve, overlaid — the most
  decision-relevant single plot for a model whose entire purpose is
  showing whether ignoring dependence biases the answer. `NEEDS
  VERIFICATION` that this is directly computable from the fitted object;
  confirm at implementation time.
- The fitted copula/dependence parameter itself has no standard
  visualization beyond a numeric report — no plot proposed for it alone.

## GEE (quasi tier)

Grounding: the working-correlation-structure heatmap is already a
`model_diagnostics_framework.md` diagnostic — not repeated here. The
standard *result*-communication plot for a GEE marginal model is the
predicted marginal (population-averaged) response as a function of the
treatment/key covariate, with the correlation structure integrated out —
what a GEE model is actually for.

### InferenceCountPoissonKKGEE
- Predicted marginal count/rate by arm with CI band — the GEE analogue of
  a coefficient plot, on the response scale rather than log-rate for
  interpretability.

### InferenceIncidKKGEE
- Predicted marginal probability (population-averaged risk) by arm, CI
  band.

### InferenceOrdinalKKGEE
- Predicted marginal probability *per category* by arm — a stacked-bar or
  per-category line plot showing how the whole outcome distribution
  shifts by arm, since a single scalar coefficient plot loses the
  multi-category structure.

### InferencePropKKGEE
- Predicted marginal mean proportion by arm, CI band, on the `[0,1]`
  scale.

## GLMM classes

Grounding: two plots recur across every GLMM regardless of response
family — (1) a random-effects caterpillar/dot plot (`lme4`/
`broom.mixed::tidy(effects = "ran_vals")`/`sjPlot::plot_model(type =
"re")` convention: one point + CI per cluster/pair's estimated random
effect, sorted, showing between-cluster heterogeneity), and (2) a
marginal (population-averaged, random effect integrated out) vs.
conditional (cluster-specific) predicted-response comparison — the
standard device explaining that a GLMM's fixed-effect coefficient is
conditional, unlike a GEE's marginal one. The random-effect QQ plot is
already a `model_diagnostics_framework.md` diagnostic (normality check) —
the caterpillar plot below is a different use of the same random-effect
estimates (communication, not a distributional check).

### InferenceContinKKGLMM
- Random-effects caterpillar/dot plot (one point + CI per matched
  pair/cluster).
- Marginal vs. conditional predicted mean by arm, side by side.

### InferenceCountKKGLMM
- Same two plots as `InferenceContinKKGLMM`, on the count/rate scale.

### InferencePropKKGLMM
- Same two plots, on the proportion scale.

### InferenceOrdinalKKGLMM / InferenceOrdinalKKCLMM / InferenceOrdinalKKCLMMCauchit / InferenceOrdinalKKCLMMCloglog / InferenceOrdinalKKCLMMProbit
- Same two plots as `InferenceContinKKGLMM`, with the marginal/conditional
  plot showing predicted probability *per category* (same multi-category
  handling as the ordinal-GEE case above) rather than a scalar mean. All
  five classes share this identical model shape (a cumulative/
  adjacent-category link over a matched-pair or cluster random effect)
  and differ only in link function or ordinal parameterization (CLMM vs.
  GLMM) — the plot *design* is identical across all five; only the
  predicted-probability curve's numeric shape differs.

### InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC / InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik / InferenceSurvivalGLMMWeibullFrailtyNormalIVWC / InferenceSurvivalGLMMWeibullFrailtyNormalOneLik
- Frailty caterpillar/dot plot — the survival-specific version of the
  random-effects caterpillar plot above (one point + CI per cluster/
  pair's estimated frailty, log-gamma or log-normal depending on class).
- Marginal (population-averaged) vs. conditional (frailty-specific)
  survival curve — the survival-scale analogue of the marginal-vs-
  conditional plot above; complements (but is distinct from) the Weibull
  fitted-curve plot by specifically isolating frailty-driven
  heterogeneity rather than baseline-hazard shape. All four classes
  (log-gamma/log-normal × IVWC/OneLik) share this identical pair of
  plots — the frailty distribution changes the caterpillar plot's
  reference-distribution overlay but not its design; the variance method
  changes nothing plottable.

---

## Incidence GLM family (logit/probit/log/identity/modified-Poisson links)

Convention: a **predicted-probability curve** over a chosen covariate, by
arm, with a CI ribbon — the standard way binary-regression results are
actually communicated (`ggeffects::ggpredict()` / the `effects` package
convention — Fox 1987/2003, `NEEDS VERIFICATION` exact citation). This is
distinct from the coefficient/odds-ratio point-and-CI row
`InferenceSuite`'s forest plot already gives for free; the curve shows the
*shape* of the fitted relationship on the natural probability scale, not
just its endpoint summary.

### InferenceIncidLogRegr
- Predicted-probability curve (inverse-logit transform), one line per arm,
  CI ribbon.
- (Coefficient/OR row already covered by `InferenceSuite`'s forest plot —
  not repeated here.)

### InferenceIncidProbitRegr
- Same predicted-probability curve, probit link. Worth a caption note that
  probit and logit curves are visually near-indistinguishable at typical
  covariate ranges — the plot itself makes this an easy side-by-side
  comparison if both are fit.

### InferenceIncidLogBinomial
- Predicted-probability curve, log link — reads directly as a risk-ratio-
  scale display since the log link *is* the risk-ratio parameterization.
- Caption note (not a scoped diagnostic, just an interpretive caveat): a
  log-link fit can predict probabilities `> 1` outside the observed
  covariate range; the curve's own shape is the most visible place a user
  would notice this.

### InferenceIncidModifiedPoisson / InferenceIncidKKModifiedPoisson
- Same predicted-probability curve (robust/modified-Poisson working
  model for direct risk-ratio estimation). Caption note: this is a
  working-model quantity (quasi-likelihood), not an MLE-optimal fitted
  curve — same "robust SE, working mean model" caveat
  `model_diagnostics_framework.md` already states for the analogous
  Poisson/robust-Poisson family.
- KK variant: identical plot; cross-reference this section rather than
  repeat.

### InferenceIncidBinomialIdentityRiskDiff
- Predicted-probability curve, identity link — reads directly on the
  risk-difference scale. Same boundary caveat as log-binomial (identity
  link can predict outside `[0, 1]`).

---

## Beta / ZOIB / fractional logit

Convention: a **predicted-mean curve** over a covariate (the `betareg`
package's own `predict()`-then-plot convention — Cribari-Neto & Zeileis,
*JSS* 2010, `NEEDS VERIFICATION` exact citation), extended per class below.

### InferencePropBetaRegr
- Predicted-mean-proportion curve, one line per arm, CI ribbon.
- If a precision (`phi`) submodel is fit, a second predicted-precision
  curve — `betareg`'s own convention for showing both submodels rather
  than only the mean.

### InferencePropZeroOneInflatedBetaRegr
- Same predicted-mean curve as above (unconditional mean, mixing all
  three components).
- **Decomposed three-part plot**, the genuinely distinct addition for
  this class: `P(Y=0)`, `P(Y=1)`, and `E[Y | 0<Y<1]` shown separately by
  arm. Since ZOIB is literally a mixture of two point masses and a Beta
  middle, this decomposition is the natural way to show *what* is driving
  a treatment effect — e.g. "arm A has fewer zeros" is a different finding
  from "arm A's continuous mean is higher," and the pooled mean curve
  alone cannot distinguish them.

### InferencePropFractionalLogit
- Predicted-mean curve (quasi-likelihood fractional logit, Papke &
  Wooldridge 1996, `NEEDS VERIFICATION` exact citation) — same visual
  shape as the incidence-GLM family's logistic curve, since fractional
  logit reuses the logit link for continuous `[0,1]`-valued response.

---

## Conditional logistic, matched-set

Convention: conditional logistic conditions out the matched-set nuisance
parameters, so the coefficient/OR is already covered by `InferenceSuite`'s
forest plot. The genuinely distinct display is a **matched-set-level
outcome plot** — the standard matched case-control display (a "pair plot"
connecting each set's treated and control outcomes, or a concordant/
discordant summary analogous to a McNemar table) — cite Breslow & Day
(1980), *Statistical Methods in Cancer Research, Vol 1* as the classical
source for matched-set outcome displays, `NEEDS VERIFICATION` exact
citation.

### InferenceIncidKKCondLogitIVWC
- Matched-set outcome plot: each set's treated/control outcome pair,
  grouped into concordant (both same outcome — uninformative for the
  conditional likelihood) vs. discordant (informative) sets, with counts
  annotated — shows directly how much of the matched sample is actually
  contributing information to the fit.

### InferenceIncidKKCondLogitOneLik
- Same plot as `IVWC` above — the display is a function of the fitted
  model and matched-set structure, not the variance-estimation method.
  Cross-reference, not repeated.

### InferenceIncidKKCondLogitGLMMIVWC / InferenceIncidKKCondLogitGLMMOneLik
- Same matched-set outcome plot as the base conditional-logit pair above.
  Cross-reference.

---

## Exact/closed-form incidence (2×2-table)

Three distinct sub-conventions depending on whether the method is
stratified, matched, or a plain 2×2 table; each concrete class still gets
its own subsection below even where the content is fully shared within
its group.

### `InferenceIncidCMH`

**Per-stratum forest plot** — one row per stratum showing that stratum's
own risk/odds ratio and CI, plus the pooled Mantel-Haenszel estimate as a
summary diamond/row at the bottom. This is the standard meta-analysis
forest-plot display (`meta`/`metafor` package conventions — Mantel-Haenszel
pooling *is* a fixed-effect meta-analysis across strata, so the same
display applies directly, `NEEDS VERIFICATION` for the exact package
citation to use). Distinct from `InferenceSuite`'s own forest plot, which
shows one row per *inference class*, not one row per *stratum* within a
single class.

### `InferenceIncidExtendedRobins`

Same per-stratum forest plot as `InferenceIncidCMH` — Extended Robins
(Robins-Breslow-Greenland) is a variance refinement of the same
stratified Mantel-Haenszel display, not a different plot.

### `InferenceIncidKKNewcombeRiskDiff`

The KK-matched-pair variant of Newcombe's method is itself a form of
stratification (pairs are strata of size 2) — reuse the **matched-set-level
outcome plot** from the conditional-logistic family above rather than a
plain 2×2 mosaic, since that display already exists for exactly this
structure.

### `InferenceIncidExactBinomial`

Simple 2×2 mosaic or grouped-bar plot (arm × outcome), with the risk/odds
difference or ratio and its CI annotated directly on the plot
(`vcd::mosaic()` convention, Meyer, Zeileis & Hornik 2006 *JSS*, `NEEDS
VERIFICATION` exact citation).

### `InferenceIncidExactFisher`

Same 2×2 mosaic/annotated-CI plot as `InferenceIncidExactBinomial` — Fisher's
exact CI is a different interval computation on the identical table.

### `InferenceIncidExactZhang`

Same plot as `InferenceIncidExactBinomial` — Zhang's method is a different
interval computation on the identical table.

### `InferenceIncidMiettinenNurminenRiskDiff`

Same plot as `InferenceIncidExactBinomial` — Miettinen-Nurminen is a
different interval computation on the identical table.

### `InferenceIncidNewcombeRiskDiff`

Same plot as `InferenceIncidExactBinomial` — unmatched Newcombe is a
different interval computation on the identical table (contrast with the
matched `InferenceIncidKKNewcombeRiskDiff` above, which gets the
matched-set plot instead).

### `InferenceIncidRiskDiff`

Same plot as `InferenceIncidExactBinomial`.

### `InferenceIncidWald`

Same plot as `InferenceIncidExactBinomial` — Wald is the simplest interval
computation on the identical table; all seven "simple" classes in this
family differ only in which CI method computed the annotated interval,
never in what there is to show.

---

## G-computation risk-diff/ratio wrappers

Convention: a **standardized/counterfactual-outcome-under-each-arm plot**
— two bars or points, "predicted outcome if everyone received arm A" vs.
"...arm B," with CIs, and the risk difference/ratio shown as the gap
between them. This is a direct visualization of what g-computation
actually computes (standardization over the fitted outcome model to a
common population) — cite the `stdReg`/`stdReg2` or `riskCommunicator`
package conventions for standardized-outcome plots, `NEEDS VERIFICATION`
exact package/citation.

**Explicit scope boundary**: the *diagnostic* for whether the underlying
outcome model these classes standardize over actually fits the data
belongs entirely to that outcome model's own `Inference*` class in
`model_diagnostics_framework.md` — this plot only displays the
standardized result assuming that underlying model is trusted, and should
say so in its own caption/documentation rather than implying it validates
the model it rides on.

### InferenceIncidGCompRiskDiff / InferenceIncidGCompRiskRatio
- Standardized-outcome-under-each-arm plot as described above; risk-diff
  vs. risk-ratio versions differ only in whether the gap is shown as a
  difference or a ratio on the y-axis.

### InferenceIncidKKGCompRiskDiff / InferenceIncidKKGCompRiskRatio
- Same plot; KK-matched-design wrapper doesn't change what's displayed.
  Cross-reference the pair above.

### InferenceOrdinalGCompMeanDiff / InferencePropGCompMeanDiff
- Same standardized-outcome plot, generalized to the ordinal/proportion
  response scale (a mean or a per-category probability under each arm,
  respectively, rather than a binary risk). Cross-reference the incidence
  pair's plot design; only the outcome scale changes.

---

## Ordinal regression family (proportional-odds, adjacent-category, continuation-ratio, cauchit/cloglog/probit links, stereotype)

Grounding convention: the standard way ordinal-regression results are
communicated is a **predicted-probability-by-category plot** — `P(Y = j | x)`
(or the cumulative form `P(Y ≤ j | x)`) as stacked areas/ribbons across a
continuous covariate, or a grouped bar chart across a categorical covariate
(e.g. treatment arm) — the convention behind `effects::plot.effpoly()` and
`ggeffects::ggpredict()`'s ordinal support. `NEEDS VERIFICATION` on exact
function names/versions. Proportionality/parallel-lines checking (Brant
test plot) is **out of scope here** — that is
`model_diagnostics_framework.md`'s territory, not duplicated.

### InferenceOrdinalPropOddsRegr

- Stacked predicted-probability-by-arm plot (the family's canonical plot —
  every sibling below either reuses it as-is or notes why it can't).
- A single by-arm cumulative-log-odds point-range plot — proportional
  odds means one coefficient suffices, so this is the "effect size at a
  glance" companion to the stacked plot above.

### InferenceOrdinalAdjCatLogitRegr / InferenceOrdinalContRatioRegr

- Same stacked predicted-probability-by-arm plot, **but no single
  proportional coefficient exists for either model** — instead, a
  **per-cutpoint effect (forest-style) plot**: one row per category
  threshold, each with its own log-odds/log-hazard estimate and CI. This
  is the model-shape-appropriate substitute for the prop-odds single-point
  summary above, not an omission.

### InferenceOrdinalCauchitRegr / InferenceOrdinalCloglogRegr / InferenceOrdinalOrderedProbitRegr

- Same stacked predicted-probability-by-arm plot as `PropOddsRegr`, using
  each model's own link function for the predicted-probability
  transform — the plot type is shared across the ordinal link family,
  only the underlying link differs, so these three cross-reference
  `InferenceOrdinalPropOddsRegr`'s plot rather than repeating it.
- Single by-arm point-range effect plot, same as `PropOddsRegr` (all four
  of prop-odds/cauchit/cloglog/ordered-probit share the single-coefficient
  structure that makes this well-defined).

### InferenceOrdinalStereotypeLogitRegr

- Stacked predicted-probability-by-arm plot (shared convention).
- **Distinctive to this model**: a **stereotype-dimension plot** — the
  fitted category scores `φ_j` on the reduced-rank latent dimension
  (Anderson 1984's own diagnostic for this model family), a 1-D
  ordination showing whether adjacent categories are well-separated or
  effectively collapse together on the fitted dimension. No other class
  in this family has an analogous plot; do not generalize it elsewhere.

### InferenceOrdinalKKCondAdjCatLogitRegr

- Same as `InferenceOrdinalAdjCatLogitRegr` (per-cutpoint forest plot) —
  cross-reference rather than repeat; the `KKCond` prefix is a matched-set
  conditional-likelihood variant of the same adjacent-category model, not
  a different plot need.

## Ordinal partial-proportional-odds

### InferenceOrdinalPartialProportionalOddsRegr

- Predicted-probability-by-arm plot as above (shared convention).
- A **coefficient-by-category plot restricted to the covariates that were
  released from the proportional constraint** — this model's whole point
  is that *some* coefficients vary by cutpoint and others don't; the
  natural plot is exactly that split made visible (constrained
  coefficients as one flat line across categories, released ones as a
  per-category series), rather than either the single-point summary
  (wrong — some coefficients do vary) or the full per-cutpoint forest plot
  (wrong — some coefficients don't).

## Rank / distribution-free tests

Grounding convention: the standard nonparametric-test companion plot is a
**box-and-jitter (strip) plot by arm on the raw data scale**, annotated
with the test statistic/p-value — not a model-based effect plot, since
these classes fit no model. `NEEDS VERIFICATION` — no single canonical
software citation as clean as `effects`/`ggeffects` above; this is broad
statistical-graphics convention (e.g. base R `boxplot()` + `stripchart()`,
or `ggplot2`'s own `geom_boxplot()` + `geom_jitter()` combination, which is
closer to a house style than a single named source).

### InferenceAllSimpleWilcox / InferenceAllKKWilcoxIVWC

- Box+jitter plot by arm on the raw data scale (the family's canonical
  plot).
- A **rank overlay**: the same plot with data replaced by within-sample
  ranks, showing the Wilcoxon statistic's actual computation surface — the
  standard way to make "why did the test conclude this" visible for a
  rank-based procedure, not just report a p-value.

### InferenceOrdinalJonckheereTerpstraTest

- Box+jitter plot by (ordered) group, **with group medians connected by a
  line** — Jonckheere-Terpstra specifically tests an *ordered* alternative
  across ≥3 groups, so the connecting line is what makes the ordered-trend
  hypothesis visible, not merely a per-group comparison.

### InferenceOrdinalPairedSignTest

- **A paired-difference plot** (per-subject before/after points connected
  by a line, or a one-sample plot of the paired differences themselves)
  — **not** an unpaired box+jitter plot, since the sign test's whole
  premise is within-subject pairing; showing arm-level marginal
  distributions would misrepresent what the test actually uses.

### InferenceOrdinalRidit

- Box+jitter plot by arm on the raw ordinal scale.
- A **ridit-transformed strip plot** — the data replaced by their ridit
  scores (relative-to-reference-distribution percentile ranks), the
  direct visual analogue of `AllSimpleWilcox`'s rank overlay above but for
  ridit analysis specifically.

### InferenceSurvivalGehanWilcox / InferenceSurvivalLogRank

- Cross-reference `survival_curve_visualization.md`'s Kaplan-Meier plot
  (added this session, v3.0.0) — that file already scopes the KM curve
  with a log-rank annotation. **No separate result plot proposed here**;
  scoping one would duplicate that work. The one addition specific to
  this family: annotate the existing KM plot with the Gehan-Wilcox
  statistic alongside log-rank when `InferenceSurvivalGehanWilcox` is the
  fitted class, since the two tests can disagree (Gehan-Wilcox weights
  early events more heavily) and showing only log-rank's annotation would
  be misleading for a Gehan-Wilcox result.

### InferenceSurvivalKKRankRegrIVWC

- Cross-reference the per-cutpoint-style forest plot idea is **not**
  applicable here — this is a rank-based survival regression (KK-matched
  design), not a categorical-outcome model. Its natural plot is closer to
  `InferenceAllKKWilcoxIVWC`'s rank-overlay convention above, adapted to
  survival time ranks (a rank-transformed event-time strip plot by arm,
  within matched sets). `NEEDS VERIFICATION` — this specific combination
  (rank regression + survival + matched design) has no single canonical
  plotting citation found; flagged rather than asserted confidently.

## Simple mean/average-difference

Grounding convention: a **box+jitter plot by arm**, or equivalently a
**point-range plot of the mean difference with its CI** — the plain,
model-free two-group comparison every applied-stats course teaches first.
Both are cheap and standard; propose both, let implementation pick a
default.

### InferenceAllSimpleAverageDiff / InferenceAllSimpleMeanDiffPooledVar / InferenceAllKKMeanDiffIVWC

- Box+jitter plot by arm (canonical plot for this family).
- Point-range plot of the mean difference (redundant with, not
  replacing, `InferenceSuite`'s own CI forest-plot row per
  `inference_suite_interactive_reporting.md` — this per-class plot shows
  the *raw data* the forest-plot row summarizes, a different level of
  detail, not a duplicate of the same thing).

### InferenceBaiAdjustedTKK14 / InferenceBaiAdjustedTKK21

- Same box+jitter/point-range pair as above.
- Since both are matched-design mean-difference estimators (Bai's pilot-
  index adjustment on KK matching), also worth a **within-pair difference
  plot** (one point per matched pair, at the pair's outcome difference) —
  the matched-design analogue of the paired-difference plot already
  proposed for `InferenceOrdinalPairedSignTest` above, same underlying
  idea applied to a continuous outcome.

### InferenceSurvivalKMDiff / InferenceSurvivalRestrictedMeanDiff

- Cross-reference `survival_curve_visualization.md`'s Kaplan-Meier plot —
  **no separate result plot proposed here**, matching the same rule
  applied to `InferenceSurvivalGehanWilcox`/`InferenceSurvivalLogRank`
  above. `InferenceSurvivalRestrictedMeanDiff`'s one addition: the
  existing KM plot should optionally shade the area between curves up to
  the RMST truncation time τ when this class is the fitted one — RMST is
  literally that shaded area, so making it visible on the same plot the
  KM-curve work already scopes is a small, natural addition rather than a
  new plot type.

---

## Tests

- **Completeness**: every one of the 102 `Inference*` classes in
  `public_api_inventory.csv` has a `###` subsection here — a lint-style
  check (grep-count class headings against the inventory, the same method
  used to verify this file during scoping) rather than a statistical test,
  but a real regression guard against a class silently falling through a
  future family re-grouping.
- **No duplication**: none of the plots proposed here re-render a
  `model_diagnostics_framework.md` assumption-check plot or
  `inference_suite_interactive_reporting.md`'s generic CI forest-plot row
  — verified this session by grepping the assembled file for every
  diagnostic-plot name (Schoenfeld, Cox-Snell, calibration, overdispersion,
  working-correlation heatmap, random-effect QQ, Brant) and confirming
  each occurrence is a "distinct from" cross-reference, never a
  re-description; a CI lint could automate the same grep.
- **Dependency ordering**: the six survival classes named in this file's
  header (Weibull ×2, Gehan-Wilcox/log-rank, KM-diff/RMST) render as a
  layer *on* `survival_curve_visualization.md`'s plot object — test that
  their plotting functions take that object as an input rather than
  re-deriving a KM curve internally, and that they degrade sensibly
  (typed "not available" rather than silently rendering nothing) if that
  object isn't present.
- **Sibling-equivalence**: for every class documented as "same plot as
  `X`" (the large majority — IVWC/OneLik/KK-matched-design siblings), the
  rendered output is byte-for-byte/pixel-for-pixel identical to `X`'s
  given the same fitted values, not merely "looks similar."
- Golden/visual regression tests per concrete plot type, deferred to the
  real implementation plan (TODO-2) rather than specified here — this is
  a scoping document, not an implementation spec, matching every other
  `*_visualization.md`/`*_framework.md` plan from this session.

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — pursue all 19
  families/102 classes, or triage to a prioritized subset first? Given the
  volume, a real implementation plan should almost certainly batch by
  family rather than attempt all 19 in one sitting (the same lesson
  `finite_mixture_regression.md` and `model_diagnostics_framework.md`
  already encode: prove the pattern on a small number of families before
  scaling).
- [ ] TODO-2: **Build the reporting layer + first family batch**, proven
  on 2-3 genuinely different families (e.g. OLS/robust, the incidence GLM
  family, and one exact/closed-form family) before scaling to the
  remaining sixteen — reuses `inference_suite_interactive_reporting.md`'s
  ggplot2/HTML/`plotly` plumbing rather than building a second reporting
  layer.
- [ ] TODO-3: **The six survival-family entries are gated on
  `survival_curve_visualization.md`'s own TODO-1..7 landing first** — per
  this file's header, they are additive layers on that file's plot
  object, not independently buildable. Do not schedule these six ahead of
  that file's own implementation.
- [ ] TODO-4: **Extend to the remaining families**, batched per TODO-1's
  triage decision, each proven with its own golden/visual tests before
  being called done.
- [ ] TODO-5: **Documentation** — one vignette section per family (or a
  single "result plots" vignette covering all of them), roxygen, and a
  cross-reference from `model_diagnostics_framework.md`'s and
  `survival_curve_visualization.md`'s own documentation back to this file
  so a reader discovers both halves (checks vs. results) from either
  entry point.

## References

Citations are embedded inline per section throughout this file (each
tagged `NEEDS VERIFICATION` where not confidently sourced, per this
repo's convention), rather than re-derived into a single master
bibliography here — doing so risked introducing transcription errors
into citations the four contributing passes already stated precisely
in context. Verify each inline citation against its primary source at
implementation time, same as every `NEEDS VERIFICATION` tag elsewhere in
this codebase.
