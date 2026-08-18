# Feature Plan: A One-Stage (`OneLik`) Joint Beta-Regression Likelihood For KK Designs

> **Depends on:** nothing release-blocking; additive on top of
> `InferencePropBetaRegr` (`R/EDI/R/inference_proportion_beta.R`) and the
> existing `InferenceMixinKKGLMMShared` mixin
> (`R/EDI/R/inference_mixin_kk_glmm_shared.R`). Should follow 1.0.0's Phase
> 1D.2 KK-hierarchy migration landing (this plan's TODOs read `KKstats`/
> `compute_basic_match_data()` conventions from the migrated classes, e.g.
> `inference_all_KK_quantile_regr_one_lik_abstract.R`) — same ordering
> constraint already noted for `ordinal_gee_cpp_kernel_spec.md`'s KK
> wirings in `_master.md`. (Global ordering: see `_master.md`.)

## Status

**v1.1.0 — committed feature plan.** Originated as a theory derivation in
`package_metadata/new_research_ideas/`; promoted here after the derivation,
proof, prior-art check, and existing-machinery audit below were worked
through and found sound. It fills in one of the two concrete open gaps
named in `package_metadata/new_research_ideas/KK_followup_research_plan.md`
(see its "Fill the two remaining narrow gaps" item and the Proportion row
of its one-stage coverage table): *"No beta-regression-specific one-stage
estimator for proportion (GLMM uses a quasi-binomial link, not the beta
family)."* The survival side's parallel gap (a one-stage rank-regression
estimator) is out of scope here — see `KK_followup_research_plan.md` and
this plan's own "Proof" section for the (separately citable) Weibull/
Gumbel-Logistic mechanism that gap would build on.

## What Already Exists For Proportion Responses In KK Designs

- `InferencePropBetaRegr` (`R/EDI/R/inference_proportion_beta.R`) — plain
  (non-KK) beta regression via `fast_beta_regression_cpp`, ignoring any
  matched-pair structure entirely.
- `InferencePropKKQuantileRegrOneLik` / `InferenceAbstractKKQuantileRegrOneLik`
  (`R/EDI/R/inference_proportion_KK_quantile_regr_one_lik.R`,
  `R/EDI/R/inference_all_KK_quantile_regr_one_lik_abstract.R`) — a genuine
  one-stage estimator, but for a *quantile* of the logit-transformed
  response, not the beta-family mean. It works by **row-stacking**: logit
  pair-differences `qlogis(y_T) - qlogis(y_C)` for the `m` matched pairs are
  stacked with `qlogis(y_r)` for the `nR` reservoir subjects into one design
  matrix with a shared treatment column, then `quantreg::rq()` is fit once
  over everything (`inference_all_KK_quantile_regr_one_lik_abstract.R:L138-L200`).
- `InferencePropKKGLMM` (`R/EDI/R/inference_proportion_KK_combined.R:L97-L249`)
  — a genuine one-stage joint likelihood, but for a **quasi-binomial**
  fractional-response mean model, built on the same conditional-logit +
  Gaussian-random-intercept machinery used for genuinely binary incidence
  responses (`fast_clogit_plus_glmm_cpp`, inherited via
  `InferenceAbstractKKCondLogitGLMM`). It treats `(0,1)`-valued `y` as a
  quasi-likelihood weight, not as a Beta-distributed outcome — it has no
  precision parameter `phi` and does not target the same estimand as
  `InferencePropBetaRegr`'s mean model.
- `InferencePropKKGEE` (same file) — GEE with an exchangeable working
  correlation over pair/reservoir "clusters," again quasi-likelihood
  (`likelihood_tier = "quasi"`), not a genuine Beta-family joint likelihood.
- **`InferenceMixinKKGLMMShared`** (`R/EDI/R/inference_mixin_kk_glmm_shared.R`)
  — generic KK random-pair-intercept GLMM plumbing (pairs as `(1|group_id)`
  clusters, reservoir singletons as their own groups), fit via `glmmTMB`,
  already used by three response types: `InferenceContinKKGLMM`
  (`glmm_family = stats::gaussian(link="identity")`), the count-response
  GLMM in `inference_count_KK_combined.R`, and `InferenceOrdinalKKGLMM`.
  **This is not itself a Beta-regression class** — no daughter class
  currently sets `glmm_response_type() = "proportion"` — but the mixin
  already special-cases that response type for `.sanitize_proportion_response`
  (`inference_mixin_kk_glmm_shared.R:L95-L97`, currently dead code, no
  caller reaches it) and `glmmTMB` natively supports
  `family = beta_family(link = "logit")` with random effects. **This is the
  cheapest available path to (an approximate version of) the model derived
  below** — see "Two Implementation Paths" after the derivation — much
  cheaper than writing a new Rcpp backend from scratch, at the cost of a
  Laplace rather than Gauss-Hermite approximation to the random-effect
  integral.

None of these is a *beta-regression-specific* one-stage estimator: something
that reduces to `InferencePropBetaRegr`'s exact mean/precision model when
there is no matching structure, and generalizes it to a genuine joint
likelihood over matched pairs + reservoir the way
`InferenceSurvivalKKWeibullFrailtyOneLik` does for the Weibull AFT model.
This document derives that model.

## Why The Row-Stacking Mechanism Doesn't Transfer

`InferenceAllKKQuantileRegrOneLik`/`InferenceContinKKOLSOneLik`'s
row-stacking trick (and the conditional-logit/-Poisson `OneLik` classes)
works because, in each of those cases, a *pair-level nuisance term cancels
exactly* out of the pair's contribution to the objective:

- **OLS** (`inference_continuous_KK_ols_one_lik.R:L349-L418`): under
  `E[y_ij | x_ij, pair k] = alpha_k + x_ij'beta_x + w_ij beta_T`, the pair
  difference `y_T - y_C = (w_T - w_C)beta_T + (x_T - x_C)'beta_x + eps_T -
  eps_C` is exactly linear in `(beta_T, beta_x)` with the pair intercept
  `alpha_k` differenced away identically — no approximation, because the
  mean function is linear in `alpha_k`.
- **Conditional logit/Poisson**: conditioning on the pair's sufficient
  statistic (the total event count within the pair) analytically eliminates
  the pair intercept from the conditional likelihood — a different
  mechanism, but again an *exact*, closed-form elimination specific to the
  exponential-family conditioning argument for logit/Poisson pairs.
- **Quantile regression** (`InferencePropKKQuantileRegrOneLik`): this one is
  actually an approximation dressed up as row-stacking — it differences the
  *logit-transformed* responses and treats the result as a plain check-loss
  regression target. It works reasonably as an estimating equation for a
  *quantile* of the difference distribution, but it does not correspond to
  any exact elimination of a pair effect from a Beta likelihood; it is not
  a template for a genuine joint Beta likelihood.

For beta regression, `y_ij | mu_ij, phi ~ Beta(mu_ij phi, (1-mu_ij)phi)` with
`logit(mu_ij) = x_ij'beta_x + w_ij beta_T + b_k` — the link is nonlinear, and
the Beta family is **not closed under subtraction**: `y_T - y_C` need not lie
in `(0,1)` (it lies in `(-1,1)`) and has no Beta (or any other tractable
closed-form) distribution, so there is no exact linear cancellation the way
there is for OLS. There is also no known sufficient statistic that
eliminates a pair-level nuisance parameter from a Beta likelihood in closed
form (unlike the logit/Poisson conditioning argument) — the Beta family's
canonical link/conditioning structure doesn't admit it. Row-stacking
therefore cannot be made exact here; it can only be approximated (as the
quantile-regression class already does, at the cost of leaving the Beta
family entirely).

## Does Dividing Instead Of Subtracting Fix This?

Worth checking directly, since it's the natural next thing to try once
subtraction fails: replace the pair *difference* `y_T - y_C` with a pair
*ratio*, either the raw-response ratio `y_T / y_C` or the odds ratio
`OR = [y_T/(1-y_T)] / [y_C/(1-y_C)]`. Use the standard Gamma representation
of a Beta variable to make the algebra explicit: for member `i in {T,C}` of
pair `k`, with shape parameters `a_i(b) = mu_i(b) phi`, `d_i(b) = (1 -
mu_i(b)) phi` (using `d` here to avoid clashing with `beta_x`),

```
y_i(b) = G_{a_i(b)} / (G_{a_i(b)} + G_{d_i(b)}),   G_{a_i(b)}, G_{d_i(b)} ~ Gamma(., 1) independent
```

**Raw ratio `y_T / y_C`.** This is a ratio of two *independent* Beta
variables (independent given `b`, since `T` and `C` are conditionally
independent given the shared `b_k`), not a ratio of the two Gamma pieces of
a single Beta variable. There is no known closed-form density for the ratio
of two independent Beta random variables in general (it is expressible only
through a Gauss hypergeometric function `_2F_1`), and nothing about this
pair's structure removes `b` from that expression — `b` enters both
`a_T(b), d_T(b)` and `a_C(b), d_C(b)` through the nonlinear `plogis(.)` mean
function, so it does not cancel algebraically the way the pair intercept
cancels in `y_T - y_C` for OLS. **Dividing the raw responses is no better
than subtracting them**: still no closed form, still no cancellation of
`b_k`.

**Odds ratio / log-odds-ratio.** This is the one worth taking seriously,
because — unlike the raw ratio — it *is* exactly `exp(logit(y_T) -
logit(y_C))`, i.e. `log(OR) = logit(y_T) - logit(y_C)`. This is not new
territory: it is the identical quantity `InferencePropKKQuantileRegrOneLik`
already row-stacks (`inference_all_KK_quantile_regr_one_lik_abstract.R:L138-
L160` differences `qlogis(y_T) - qlogis(y_C)`), just written multiplicatively.
Two things are true about it simultaneously, and both matter:

1. **Its conditional mean does cancel `b_k` exactly.** `logit(mu_T(b)) -
   logit(mu_C(b)) = (x_T - x_C)'beta_x + beta_T` for *every* value of `b`,
   because `b` enters *additively* on the logit scale by construction (it's
   the linear predictor, not the response). So `log(OR)`'s location is a
   clean, matching-structure-free function of `(beta_x, beta_T)` alone —
   this is exactly why the quantile-regression class can treat it as a
   usable one-stage estimating-equation target without needing quadrature.
2. **It still has no closed-form distribution**, so it cannot supply an
   *exact likelihood* the way this document needs. `logit(y_i)` for `y_i ~
   Beta(a_i, d_i)` is itself a "logit-Beta" / generalized-logistic variate
   whose density involves `a_i, d_i` in the exponent
   (`f(u) \propto e^{a_i u} / (1+e^u)^{a_i+d_i}`, a shifted/scaled special
   case of the generalized logistic distribution, not Normal), and the
   *difference* of two such variates (even conditionally independent given
   `b`) has no known closed-form density either — there is no beta-family
   (or any other standard-family) distribution for `log(OR) | b`, and hence
   none after integrating `b` out either. A "log-odds-ratio one-stage
   regression" is therefore exactly as legitimate as the existing
   quantile-regression class (an M-estimator / estimating-equation device
   whose target's *mean* has the right structure) but it is not a route to
   an exact joint Beta *likelihood* — nothing is gained over what
   `InferencePropKKQuantileRegrOneLik` already provides.

**Verdict.** Dividing instead of subtracting does not unlock a new exact
construction. The raw ratio is strictly worse than the difference (no
cancellation *and* no closed form, vs. the difference's "no closed form"
alone). The odds ratio / log-odds-ratio is mathematically the multiplicative
restatement of the transform the package's existing quantile-regression
`OneLik` class already uses — useful confirmation that that class's target
is the *right* transform for an estimating-equation approach (its mean is
exactly matching-structure-free), but it does not change the conclusion of
the previous section: an *exact* joint Beta likelihood for the mean/precision
model still requires integrating the pair nuisance term out numerically
(random-intercept + quadrature, below) rather than eliminating it
algebraically through any monotonic transform of `(y_T, y_C)`.

## Proof: No Transform Of `(y_T, y_C)` Achieves Exact Nuisance-Free Invariance

The claim above ("no monotonic transform cancels `b_k` in closed form") is
provable, not just a failed-attempts survey — here is the argument in full.

**What "cancel" has to mean.** For OLS, `y_T - y_C` doesn't merely have the
right *mean* — its entire distribution, `N(beta_T + (x_T-x_C)'beta_x, 2
sigma^2)`, does not depend on `b_k` at all. That full distributional
invariance (not just a matching mean) is what licenses treating `y_T - y_C`
as an ordinary datum in a likelihood with no `b_k` left in it anywhere.
That is the bar a candidate transform has to clear, and it is provably
higher than "the mean lines up," as Claim 3 below shows.

**Fact used throughout.** For `Y ~ Beta(a, d)`, `U = logit(Y)` has the
generalized-logistic ("Beta-logistic") distribution with density
`f_U(u) = e^{au} / (1+e^u)^{a+d} / B(a,d)` and moment generating function
`E[e^{tU}] = B(a+t, d-t) / B(a,d)` for `-a < t < d`. Differentiating the
cumulant generating function `K(t) = log Gamma(a+t) - log Gamma(a) + log
Gamma(d-t) - log Gamma(d)` twice at `t=0` gives the standard identities
`E[U] = psi(a) - psi(d)` and `Var(U) = psi'(a) + psi'(d)`, where
`psi = digamma`, `psi' = trigamma`. (The same digamma/trigamma pair
already underlies `InferencePropBetaRegr`'s own Fisher information.)

**Claim 1 — the raw difference `y_T - y_C` fails even at the mean.**
Write `mu_T(b) = sigma(b + eta_T)`, `mu_C(b) = sigma(b + eta_C)` for the
logistic function `sigma`, `eta_T = x_T'beta_x + beta_T`,
`eta_C = x_C'beta_x`. Then `E[y_T - y_C | b] = mu_T(b) - mu_C(b)`. If
`eta_T > eta_C` (the case of actual interest — a nonzero treatment/
covariate effect is the whole point of fitting the model), `sigma` strictly
increasing gives `mu_T(b) > mu_C(b)` for *every* `b`, so this difference is
strictly positive for all `b` — yet it tends to `0` as `b -> +-infinity`
(both `mu_T, mu_C` are driven together to `1` or to `0`). A function
that is strictly positive somewhere and `0` in both tails cannot be
constant. So `E[y_T - y_C | b]` genuinely depends on `b` whenever there is
a treatment effect to estimate: the raw difference fails to cancel the
nuisance term even in expectation, let alone in distribution.

**Claim 2 — the raw ratio `y_T / y_C` is no better.** Beyond having no
closed-form distribution at all (see "Does Dividing..." above), the same
shift-dependence argument applies to its mean: `E[y_T/y_C | b]` involves
`mu_T(b)`, `mu_C(b)` and their shape (not just location), and nothing about
dividing rather than subtracting removes the `b`-dependence introduced by
the sigmoid — it fails on the same grounds as Claim 1, in addition to
having no closed form to even inspect directly.

**Claim 3 — the log-odds-ratio gets the mean exactly right, but fails at
the variance.** `log(OR) = logit(y_T) - logit(y_C)`, and because `b` is
additive on the logit scale, `E[log(OR) | b] = (x_T - x_C)'beta_x +
beta_T` for *every* `b` — no dependence on `b` at all, confirming the
earlier claim. But by conditional independence of `y_T, y_C` given `b`,

```
Var(log(OR) | b) = Var(logit(y_T) | b) + Var(logit(y_C) | b)
                  = [psi'(a_T(b)) + psi'(d_T(b))] + [psi'(a_C(b)) + psi'(d_C(b))]
```

with `a_T(b) = phi * mu_T(b)`, `d_T(b) = phi - a_T(b)`. Fix `phi` and look
at `g(a) = psi'(a) + psi'(phi - a)` for `a in (0, phi)`. Trigamma `psi'`
is strictly positive and finite on `(0, infinity)` but diverges,
`psi'(a) -> infinity`, as `a -> 0+` (a standard polygamma asymptotic). So
`g(a) -> infinity` as `a -> 0+` (or `a -> phi-`, by symmetry), while
`g(phi/2)` is finite — a function finite somewhere and unbounded elsewhere
on the same interval is not constant. Since `a_T(b) = phi * sigma(b +
eta_T)` is a strictly monotonic bijection from `R` onto `(0, phi)`,
`g(a_T(b))` inherits this non-constancy as a function of `b`:
`Var(log(OR) | b)` genuinely depends on `b_k`, exploding as `b_k ->
+-infinity` (one pair member's mean is driven toward `0` or `1`, making
that member's Beta density near-degenerate and its logit wildly variable).
**So even the one candidate whose mean cancels exactly still fails the
actual bar** — its spread carries information about `b_k`, so it cannot
serve as a pivot the way OLS's pair difference can. It can only be used as
an *estimating-equation* target (unbiased for the right mean), which is
exactly the role `InferencePropKKQuantileRegrOneLik` already puts it to —
never as a term in an exact likelihood free of `b_k`.

**Claim 4 — a scale-family (multiplicative-invariance) rescue also fails.**
The transforms above all treat `b_k` as entering *additively* on the logit
scale. The other classical closed-form-cancellation mechanism (besides
translation) is a *scale* nuisance under multiplicative invariance — e.g. if
two Gamma variables shared a common scale factor, their ratio would cancel
it exactly (this is literally how `Beta = Gamma_a/(Gamma_a+Gamma_b)` and
Beta-prime ratios arise). But `b_k` here does not enter `mu_i(b) =
plogis(eta_i + b)` as a multiplicative scale factor on any Gamma piece of
the Beta construction — it enters the *logit-scale linear predictor*
additively, then gets warped nonlinearly by `plogis(.)` before it reaches
the Gamma-ratio representation `y_i(b) = G_{a_i(b)}/(G_{a_i(b)} +
G_{d_i(b)})`. There is no reparametrization under which `b_k` is a shared
multiplicative factor of `G_{a_i(b)}` or `G_{d_i(b)}` (both shape
parameters move nonlinearly and jointly as `b` varies), so no ratio-type
construction rescues this any more than the odds-ratio did. Multiplicative
invariance is ruled out for the same underlying reason as additive
invariance: the sigmoid.

**Two genuinely different classical mechanisms are actually in play here,
and it is worth being precise about which is which** (this document
conflated them in an earlier draft and that was a real error, caught and
corrected in review — see the epistemic-status paragraph below):

- **Mechanism A — location-family / translation-invariance.** If a nuisance
  term is a pure additive shift of an error term whose *shape* doesn't
  depend on the nuisance, differencing removes it exactly. This needs no
  exponential-family structure at all — it is elementary probability
  (a group-invariance / pivotal-quantity fact). It is why OLS works
  (Gaussian errors): `y_T - y_C` is exactly `N(beta_T + (x_T-x_C)'beta_x, 2
  sigma^2)`, fully free of `b_k`, because `b_k` is a pure translation of a
  fixed-shape (Gaussian) error term. **It is also why a Weibull AFT model
  with a shared additive frailty works, via a different but equally exact
  route**: for `T ~ Weibull(k, lambda)`, `log T = log(lambda) + (1/k) W`
  with `W` a standard Gumbel (extreme-value) variate — the classical
  log-Weibull-is-Gumbel fact. The Gumbel MGF is `E[e^{tW}] = Gamma(1-t)`,
  so for two i.i.d. Gumbel `W_T, W_C`, the difference has MGF `Gamma(1-t)
  Gamma(1+t)`, which is *exactly* the MGF of a standard Logistic(0,1)
  (McFadden's classical random-utility fact underlying conditional logit
  choice models). With a shared additive frailty `b_k` on the log-time
  scale, `log(T_Tk/T_Ck) = (eta_T - eta_C) + (1/k)(W_C - W_T)`, and `b_k`
  cancels **completely and exactly, pointwise**, for *any* distribution of
  `b_k` (not just Gaussian) — leaving `Logistic(eta_T - eta_C, 1/k)`, fully
  free of `b_k`. This is a genuinely different worked example of Mechanism
  A (Gumbel/Logistic rather than Gaussian), and it is the reason
  `InferenceSurvivalKKWeibullFrailtyOneLik`'s pair terms *could in
  principle* be handled by exact row-stacking rather than quadrature — a
  route worth pursuing separately for the still-open survival
  rank-regression `OneLik` gap named in `KK_followup_research_plan.md`, but
  out of scope here. **Not a novel observation** — checked against the
  literature specifically because it's exactly the kind of "obvious once
  you see it" fact that usually already has a name: it is published
  independently in two literatures, predating this document by five
  decades. Chamberlain (1985) develops conditional-MLE estimation for
  Weibull (and gamma, log-normal) duration models with an individual fixed
  effect shared across `T >= 2` spells per unit, eliminated via a
  sufficient statistic — the `T=2` case is exactly the matched-pair
  scenario, and this is the standard econometric citation for the trick
  (developed explicitly as the fixed-effects response to the Weibull
  heterogeneity-bias problem raised by Lancaster 1979). Holt and Prentice
  (1974) independently derive the identical construction (their §3, models
  2-3), confirmed by direct reading of the primary source. The full
  writeup of this Weibull worked example — including what happens under
  right-censoring, which is a genuinely separate question this document
  does not need — lives in
  `../new_research_ideas/KK_followup_research_plan.md` (its note on "a
  parallel Weibull/Gumbel-Logistic mechanism" the still-open survival
  rank-regression `OneLik` gap could build on); not reproduced here since
  it is out of scope for a proportion-response plan.
- **Mechanism B — Andersen (1970) canonical-parameter conditioning.** A
  genuinely exponential-family-specific mechanism: if the nuisance is a
  canonical parameter of a discrete exponential family, conditioning on its
  sufficient statistic removes it from the *conditional* likelihood (a
  weaker guarantee than Mechanism A's full-distribution invariance). This is
  why conditional logistic/Poisson regression's pair-intercept elimination
  works: the canonical parameter of a Bernoulli or Poisson observation is,
  by convention, the same logit/log linear predictor the mean model already
  uses, so an additive random pair intercept `b_k` lands additively in the
  canonical parameter.

**Why Beta regression under the logit link fails both.** It fails Mechanism
A because `b` does not merely translate a fixed-shape error term — it warps
the Beta density's *shape*: Claim 3 above shows `Var(logit(y)|b)` genuinely
depends on `b` (via `psi'(a_T(b)) + psi'(d_T(b))`), so this is not a
location family in `b` at all, unlike Gaussian or Gumbel/Logistic. It fails
Mechanism B because, writing the Beta density in canonical form with `phi`
fixed, the canonical parameter is `a = phi*mu`, with `logit(y)` as its own
sufficient statistic — but `a = phi*sigma(eta + b)` depends on `b` through
the *sigmoid*, not additively, so `b` is not a canonical parameter under the
logit link (the only sensible, range-preserving link choice), and Andersen's
condition fails.

**Epistemic status of this argument — corrected from an earlier overreach.**
Claims 1-4 are a complete, self-contained proof that the four natural
transform candidates (difference, raw ratio, odds ratio, and a
scale-invariance variant) each fail for this specific model — that part
does not depend on anything below. An earlier draft of this document then
overstated the general case, implying Mechanisms A and B jointly exhaust
*every* possible route to exact nuisance elimination for *any* model. There
is no known theorem establishing that; it was a real error, not a hedge
being added defensively — Mechanism A is elementary probability with no
exhaustiveness claim attached, and Andersen (1970) proves Mechanism B is
*sufficient* within exponential families, not that it is the *only*
mechanism available. Other known routes exist that were not checked
against this specific model — e.g. Barndorff-Nielsen's "cuts" (a
generalization of Andersen's condition to some curved exponential families)
and, more broadly, invariance under an arbitrary group action on the sample
space (Lehmann's theory of maximal invariants), of which location and scale
are merely the two simplest examples; nothing here rules out some more
exotic transformation group under which `b_k` acts as a group element
specific to the Beta family. The sharper, fully general tool for closing
this gap is Fisher information: if a statistic `T = g(y_T, y_C)` has a
distribution exactly free of `b`, its Fisher information about `b` must be
identically zero for every `b` (immediate from the definition — a
parameter-free law has an a.e.-zero score). The full data `(y_T, y_C)`
carries strictly positive information about `b` here (nonzero score, same
digamma/trigamma machinery as above), but that alone does not finish the
proof, because a *reduction* of the data can legitimately have zero
information — that is exactly what an ancillary statistic is. Ruling out
every possible ancillary statistic for the specific curve `b -> (a_T(b),
a_C(b))` swept through the 2-D canonical parameter space is a real question
in the theory of curved exponential families (Efron's curvature, Amari's
information geometry) that this document does not resolve. **The accurate
claim, and the one this document actually relies on, is: "no known
mechanism achieves exact elimination here" — not "no transform whatsoever,
provably, can."**

**Conclusion.** Claims 1-4 rule out the four natural candidates by direct,
closed-form calculation, and the two-mechanism analysis explains why none
of the classical closed-form routes apply: the logit link makes `b_k` enter
non-additively (ruling out Mechanism A) and non-canonically (ruling out
Mechanism B). Given the honest epistemic status above, the Gaussian
random-intercept + Gauss-Hermite-quadrature construction below should be
read as "the best available exact mechanism, given every route checked so
far fails" rather than "provably the only possible one" — but it is
sufficient to proceed with, since the numerical-integration route is exact
by construction regardless of whether some undiscovered closed-form
transform might also exist.

## The Available Exact Mechanism: Gaussian Random-Intercept + Quadrature

The codebase already has a working template for exactly this situation —
where a pair-level nuisance term cannot be eliminated in closed form from a
nonlinear-link likelihood — in
`InferenceSurvivalKKWeibullFrailtyOneLik`/`InferenceAbstractKKCondLogitGLMM`
(`InferencePropKKGLMM`'s own base class): place a **Gaussian random
intercept** on the linear-predictor scale, shared within a pair, and
integrate it out numerically via **Gauss-Hermite quadrature**
(`n_gh = 20` nodes by default; see `fast_ordinal_glmm.cpp:223,244` and the
`glmm::gauss_hermite_rule` helper it calls). This is the natural mechanism
to reuse for beta regression's mean model.

### Model

For matched pair `k = 1,...,m` with members `T` (treatment) and `C`
(control):

```
logit(mu_Tk) = x_Tk' beta_x + beta_T + b_k
logit(mu_Ck) = x_Ck' beta_x + b_k
y_Tk | mu_Tk, phi  ~  Beta(mu_Tk * phi, (1 - mu_Tk) * phi)
y_Ck | mu_Ck, phi  ~  Beta(mu_Ck * phi, (1 - mu_Ck) * phi)     (conditionally independent given b_k)
b_k  ~  N(0, sigma_b^2)                                          i.i.d. across pairs
```

For reservoir subject `r = 1,...,nR` (treated `w_r in {0,1}`):

```
logit(mu_r) = x_r' beta_x + w_r * beta_T
y_r | mu_r, phi  ~  Beta(mu_r * phi, (1 - mu_r) * phi)
```

**No random intercept for reservoir subjects.** This is a deliberate choice,
not a simplification of convenience — it mirrors what
`InferenceSurvivalKKWeibullFrailtyOneLik`'s own reservoir component already
does (plain Weibull AFT, no frailty term; see
`inference_survival_KK_weibull_frailty.R:L309-L341`). The random intercept
exists to model *within-pair* correlation; a reservoir singleton has no
partner to be correlated with, so there is nothing for `b_k` to represent
for that subject. Giving every reservoir subject its own free-standing
`b_r ~ N(0, sigma_b^2)` would not add correlation structure (there is no
second observation to correlate it with) — it would only inflate the
reservoir subjects' marginal variance relative to a plain Beta model, which
is not motivated by anything in the design. `beta_x`, `beta_T`, and `phi`
are shared across pairs and reservoir; `sigma_b^2` is identified only from
the pairs.

### Joint log-likelihood

Using the Ferrari & Cribari-Neto (2004) mean/precision parameterization of
the Beta density,

```
f(y; mu, phi) = [Gamma(phi) / (Gamma(mu*phi) Gamma((1-mu)*phi))] * y^(mu*phi - 1) * (1 - y)^((1-mu)*phi - 1)
```

the pair contribution requires integrating the shared random intercept out
of the *joint* density of the pair (not two separate integrals — the two
members are dependent only through the one shared `b_k`):

```
L_k(beta_x, beta_T, phi, sigma_b^2) =
    integral_{-inf}^{inf}  f(y_Tk; mu_Tk(b), phi) * f(y_Ck; mu_Ck(b), phi) * phi_N(b; 0, sigma_b^2)  db
```

where `phi_N(.; 0, sigma_b^2)` is the Normal(0, sigma_b^2) density and
`mu_Tk(b) = plogis(x_Tk'beta_x + beta_T + b)`,
`mu_Ck(b) = plogis(x_Ck'beta_x + b)`. This integral has no closed form (the
Beta density is not conjugate to a Normal random effect on the logit scale,
the same reason ordinary logistic-Normal GLMMs need quadrature), so
approximate it by Gauss-Hermite quadrature with nodes/weights `(z_q, w_q)`,
`q = 1,...,Q` (`Q = n_gh`, default 20, per the package's existing
convention), using the standard substitution `b = sqrt(2) * sigma_b * z`:

```
L_k  ~=  (1/sqrt(pi)) * sum_{q=1}^{Q} w_q * f(y_Tk; mu_Tk(sqrt(2) sigma_b z_q), phi) * f(y_Ck; mu_Ck(sqrt(2) sigma_b z_q), phi)
```

The reservoir contribution needs no integral:

```
L_r(beta_x, beta_T, phi) = f(y_r; mu_r, phi)
```

The full joint log-likelihood, in `log_phi = log(phi)` and
`log_sigma_b = log(sigma_b)` for unconstrained optimization (matching the
package's existing convention of optimizing over log-scale dispersion/
variance parameters, e.g. `max_abs_log_sigma` in
`InferencePropKKGLMM`/`fast_ordinal_glmm.cpp`):

```
ell(beta_x, beta_T, log_phi, log_sigma_b) = sum_{k=1}^{m} log L_k + sum_{r=1}^{nR} log f(y_r; mu_r, phi)
```

### Degenerate cases (must match existing convention exactly)

- **`m = 0` (reservoir only)**: `ell` reduces to the ordinary Beta-regression
  log-likelihood already implemented in `fast_beta_regression_cpp` — the new
  backend should literally dispatch to it in this case rather than
  reimplementing it, both for correctness and to inherit its existing
  hardened-fit machinery.
- **`nR = 0` (pairs only)**: `ell` is the frailty-only sum over pairs; this
  is the natural "pairs-only" fit needed for the two-stage comparator below.
- **`sigma_b^2 -> 0`**: `L_k -> f(y_Tk; mu_Tk(0), phi) * f(y_Ck; mu_Ck(0),
  phi)`, i.e. the pairs collapse to plain independent Beta observations with
  no matching adjustment. The whole model should then coincide exactly with
  fitting `InferencePropBetaRegr` on the pooled matched+reservoir data —
  this is a strong, cheap correctness check (see Validation Plan below), and
  it is also the null hypothesis for testing whether the matched-pair
  structure carries any real within-pair correlation worth modeling.

### Score and information

For a joint MLE fit and Wald/likelihood-based inference following the
package's existing `get_likelihood_test_spec()` contract
(`InferencePropBetaRegr`'s own `get_beta_regression_score_cpp`/
`get_beta_regression_hessian_cpp`, and the GH-quadrature analogs already used
for `fast_clogit_plus_glmm_cpp`/`fast_ordinal_glmm.cpp`), the score for the
reservoir terms is exactly the existing Beta-regression score (Ferrari &
Cribari-Neto 2004, their Eqs. 4-6, already implemented). The score for a
pair term requires differentiating under the quadrature sum, which is
mechanical once `L_k` is written as a normalized quadrature sum — this is
exactly the same differentiate-through-quadrature step
`fast_ordinal_glmm.cpp` and `fast_clogit_plus_glmm_cpp` already perform for
their own random-intercept terms (see e.g.
`fast_ordinal_glmm.cpp:L85-L180`'s per-node log-likelihood/gradient
accumulation, which is a direct template to adapt). The observed/Fisher
information for the combined likelihood is the negative Hessian of `ell`,
giving asymptotic (sandwich-free, model-based) standard errors the same way
`InferencePropBetaRegr` and `InferenceSurvivalKKWeibullFrailtyOneLik` already
report them; the package's existing likelihood-ratio/score/gradient testing
machinery (`supports_likelihood_tests`, `get_likelihood_test_spec`) should
attach without needing new inference-theory work, only the new `neg_loglik`/
`score`/`observed_information`/`fisher_information` closures over this
backend.

## Two Implementation Paths

The derivation above specifies the model precisely; it does not by itself
dictate *how* to build it. There are two genuinely different-cost routes,
and the package's own history with `InferenceContinKKGLMM` suggests doing
both, in this order:

1. **Cheap path (recommended first): reuse `InferenceMixinKKGLMMShared` +
   `glmmTMB::beta_family()`.** Add a new class, shaped like
   `InferenceContinKKGLMM` (`inference_continuous_KK_glmm.R:L22-L138`) but
   with `glmm_response_type = function() "proportion"` and
   `glmm_family = function() glmmTMB::beta_family(link = "logit")`, no
   `use_rcpp` fast path (there is no internal backend yet), splicing in
   `InferenceMixinKKGLMMShared$public`/`$private` exactly as the three
   existing daughters do. This reaches the mixin's already-written
   `.sanitize_proportion_response` branch, which is currently dead code.
   **This is not exactly the model derived above** — `glmmTMB` integrates
   the random pair intercept via a Laplace approximation (TMB's automatic
   differentiation), not Gauss-Hermite quadrature. For a single scalar
   random effect per pair, Laplace is a real but usually mild accuracy
   tradeoff against adaptive GH quadrature; whether it matters at the
   small-`m` sample sizes KK designs target should be checked empirically
   before treating the two as interchangeable. Estimated cost: on the order
   of `InferenceOrdinalKKGLMM`/`InferenceCountKKCombined`'s own leaf-class
   size (a few hundred lines, mostly boilerplate already handled by the
   mixin) — a small fraction of the from-scratch backend below.
2. **Exact path (natural follow-up, mirroring `InferenceContinKKGLMM`'s own
   `use_rcpp` precedent): the Gauss-Hermite-quadrature backend derived
   above.** `InferenceContinKKGLMM` shipped with `glmmTMB`-only support
   first and later gained an internal Rcpp Gaussian-LMM fast path
   (`use_rcpp = TRUE` by default now); the same evolutionary path applies
   here — ship the glmmTMB version, then build `fast_beta_regression_glmm_cpp`
   (Section "The Available Exact Mechanism" above) as a faster, dependency-free,
   exactly-GH-quadrature replacement once the model itself is validated to
   be worth the investment.

## Alternatives Considered And Rejected

- **Bivariate copula with Beta margins** (mirroring
  `InferenceSurvivalKKClaytonCopulaIVWC`'s Clayton-copula-with-Weibull-margins
  construction): would avoid needing a quadrature integral, but the Beta CDF
  has no closed-form inverse (it's the regularized incomplete beta function),
  so evaluating a copula density built on Beta margins requires numerically
  inverting `pbeta()` at every likelihood evaluation for both pair members —
  more expensive per iteration than a 20-node GH sum over a scalar frailty,
  and without a closed-form frailty-mixture shortcut the way the
  gamma-frailty Clayton-Weibull construction has (Clayton/Oakes closed form
  exists specifically because Weibull hazards are gamma-frailty-conjugate;
  no analogous closed form is known for Beta margins). Also, unlike the
  survival Clayton-copula class, which is IVWC-only in this codebase (see
  `inference_survival_KK_clayton_copula.R:L1-L6` — it explicitly combines a
  matched-pair copula estimate with a separate reservoir Weibull estimate by
  inverse-variance weighting, *not* a single joint likelihood), a genuine
  `OneLik` class needs the pair and reservoir terms to already share one
  optimization — the random-intercept construction does this natively,
  since reservoir terms are already ordinary Beta log-likelihood terms
  summed into the same `ell`.
- **Differenced-logit linear/quantile row-stacking treated as a mean model**
  (i.e., just reuse `InferencePropKKQuantileRegrOneLik`'s design but with a
  squared-error or Beta-motivated loss instead of check loss): rejected for
  the reason in "Why Row-Stacking Doesn't Transfer" above — there is no
  version of this that is an exact Beta likelihood; it would produce a
  different (linear-in-logit-difference) estimand, not a generalization of
  `InferencePropBetaRegr`'s mean/precision model.
- **Beta-Binomial-style overdispersion instead of a random intercept**: the
  Beta-Binomial device (mixing a Binomial success probability over a Beta
  distribution) is for count-of-successes data, not continuous `(0,1)`
  proportions, so it doesn't apply to this response type at all.

## Two-Stage (IVWC) Comparator

`KK_followup_research_plan.md` frames the open statistical question as
one-stage vs. two-stage efficiency, not merely "does a one-stage estimator
exist." No beta-regression IVWC class exists yet either (there is nothing
analogous to `InferenceContinKKOLSIVWC` for the Beta family) — the
`sigma_b^2 -> 0` / `nR = 0` degenerate paths above give a nearly-free way to
build one for comparison: fit the same GH-quadrature model restricted to
pairs only (`nR = 0`) to get a matched-pairs Beta-regression estimate +
model-based variance, fit plain `InferencePropBetaRegr` restricted to
reservoir subjects only for the reservoir estimate + variance, and combine
the two by inverse-variance weighting exactly as
`InferenceAllKKMeanDiffIVWC`/`InferenceBaiAdjustedT`'s `convex_flag` path
already does for continuous responses
(`inference_continuous_KK_bai_abstract.R:L90-L109`). This reuses the same
backend twice rather than requiring a second, independent derivation, and
gives the paper's simulation study its natural one-stage-vs-two-stage arm
for the Beta family specifically.

## Open Questions / Risks

- **Weak identifiability of `phi` vs. `sigma_b^2`.** Both a large Beta
  precision `phi` and a small frailty variance `sigma_b^2` push pair members
  toward looking similar; with typically small `m` in KK designs, these two
  dispersion parameters may be poorly separated in the likelihood surface.
  Needs a simulation check (recover both parameters at plausible KK sample
  sizes before trusting SEs) rather than an a priori assumption either way.
- **Boundary testing for `sigma_b^2 = 0`.** A likelihood-ratio test of
  "no pair correlation" sits on the boundary of the parameter space; the
  usual chi-square(1) reference is invalid there (Self & Liang 1987) — the
  correct reference distribution is a 50:50 mixture of a point mass at 0 and
  chi-square(1). Any LRT this class exposes for `sigma_b^2` specifically
  needs that correction; the treatment-effect (`beta_T`) LRT/Wald tests are
  unaffected since `beta_T` is an interior parameter.
- **Computational cost.** GH quadrature per pair, per optimizer iteration,
  is `O(m * Q)` Beta-density evaluations per gradient/likelihood call —
  cheap in absolute terms (`Q = 20`) but should be checked against the
  package's existing `get_complexity_tier()` convention
  (`InferencePropBetaRegr` is already tagged `"heavy"`) so randomization
  inference / bootstrap callers budget for it correctly.
- **Whether `m = 0` and `nR = 0` degenerate paths should dispatch to the
  existing `fast_beta_regression_cpp` backend directly** (recommended above)
  **or reimplement them inside the new quadrature backend** for a single
  code path — the former is safer (reuses already-hardened code) but means
  the new class needs the same branching-by-availability logic every other
  `*OneLik`/`KKPassThrough` class already has (see
  `inference_continuous_KK_ols_one_lik.R:L349-L388`'s `m > 0 && nRT > 0 &&
  nRC > 0` / `m > 0` / `nRT > 0 && nRC > 0` branch structure — this class
  should follow the same three-way branch).

## TODOs

Work top to bottom; TODO-2 and TODO-3 may run in parallel once TODO-1 is
recorded. Per house convention, tick these here (this is the owning plan).

- [ ] TODO-1: **Prototype validation, no production code yet.** Simulate
  under a known `(beta_x, beta_T, phi, sigma_b^2)` and confirm the
  quadrature log-likelihood, score, and Hessian in "Score and information"
  above are internally consistent (score ~ 0 at the MLE; Hessian negative
  definite; numerical-vs-analytical gradient check). Confirm the
  `sigma_b^2 -> 0` degeneracy claim numerically against `InferencePropBetaRegr`
  fit on pooled matched+reservoir data with no matching adjustment — the
  cheapest possible correctness check, and a prerequisite for trusting
  either implementation path below.
- [ ] TODO-2: **Cheap path — glmmTMB reuse (ship first).** Add a new leaf
  class analogous to `InferenceContinKKGLMM`
  (`R/EDI/R/inference_continuous_KK_glmm.R:L22-L138`), splicing in
  `InferenceMixinKKGLMMShared$public`/`$private`, with
  `glmm_response_type = function() "proportion"` and
  `glmm_family = function() glmmTMB::beta_family(link = "logit")`, no
  `use_rcpp` fast path. Naming: `InferencePropKKBetaGLMM`, matching the
  `InferencePropKK*` convention (`InferencePropKKGLMM`,
  `InferencePropKKGEE`, `InferencePropKKQuantileRegrOneLik`) while staying
  distinct from the existing quasi-binomial `InferencePropKKGLMM` — pick a
  name that won't be confused with it in the public docs (e.g. spell out
  "Beta" as done here, or `InferencePropKKBetaRegrGLMM`). Wire through
  `define_inference_class()`/the class registry per house convention. This
  reaches the mixin's already-written but currently-dead
  `.sanitize_proportion_response` branch
  (`inference_mixin_kk_glmm_shared.R:L95-L97`).
- [ ] TODO-3: **Degenerate-case + correctness tests for TODO-2.** Golden
  tests following this package's existing `test-*-migration-golden.R`
  convention: `m = 0` (reservoir only) matches `InferencePropBetaRegr`
  fit on the reservoir alone; a synthetic zero-within-pair-correlation
  dataset recovers the same treatment estimate as pooled
  `InferencePropBetaRegr` (the `sigma_b^2 -> 0` check from TODO-1, now
  automated); bootstrap/Wald CI coverage under simulation at plausible KK
  sample sizes.
- [ ] TODO-4: **Exact path — Gauss-Hermite backend (follow-up, mirrors
  `InferenceContinKKGLMM`'s own `use_rcpp` history).** Write
  `fast_beta_regression_glmm_cpp` per "The Available Exact Mechanism"
  above: joint log-likelihood, score, and Hessian, following
  `fast_ordinal_glmm.cpp`'s per-node quadrature-sum accumulation pattern
  (`n_gh = 20` default) and `fast_clogit_plus_glmm_cpp`'s
  `estimate_only`/`warm_start_params`/`fixed_idx`+`fixed_values`/
  `optimization_alg` argument contract for reuse by the likelihood-test
  machinery. Dispatch to the existing `fast_beta_regression_cpp` directly
  for the `m = 0` and `nR = 0` degenerate cases (do not reimplement them)
  per the three-way branch structure in
  `inference_continuous_KK_ols_one_lik.R:L349-L388`.
- [ ] TODO-5: **`InferencePropKKBetaRegrOneLik` class**, wired to the
  TODO-4 backend with `use_rcpp = TRUE` default and TODO-2's class as the
  `use_rcpp = FALSE` glmmTMB fallback (same pattern as
  `InferenceContinKKGLMM`). Attach `get_likelihood_test_spec()`
  (`neg_loglik`/`score`/`observed_information`/`fisher_information`
  closures) so the package's existing LRT/score/gradient testing machinery
  attaches per "Score and information" above.
- [ ] TODO-6: **Boundary LRT correction for `sigma_b^2 = 0`.** Implement the
  Self & Liang (1987) 50:50 point-mass/chi-square(1) mixture reference for
  any exposed test of "no pair correlation"; confirm the treatment-effect
  (`beta_T`) LRT/Wald tests are unaffected (interior parameter) per "Open
  Questions / Risks" above.
- [ ] TODO-7: **Pairs-only / reservoir-only IVWC comparator**
  (`InferencePropKKBetaRegrIVWC` or similar): reuse the TODO-5 backend
  restricted to `nR = 0` for the matched-pairs estimate + variance, plain
  `InferencePropBetaRegr` restricted to reservoir subjects for the
  reservoir estimate + variance, combined by inverse-variance weighting
  exactly as `InferenceBaiAdjustedT`'s `convex_flag` path does
  (`inference_continuous_KK_bai_abstract.R:L90-L109`). Gives the
  simulation study (TODO-9) its one-stage-vs-two-stage arm for the Beta
  family specifically.
- [ ] TODO-8: **Identifiability + complexity-tier check.** Simulation check
  of `phi` vs. `sigma_b^2` separation at plausible KK `m` (per "Open
  Questions / Risks"); confirm/adjust `get_complexity_tier()` (candidate:
  `"heavy"`, matching `InferencePropBetaRegr`) so randomization-inference
  and bootstrap callers budget for the `O(m * n_gh)` per-iteration cost
  correctly.
- [ ] TODO-9: **Simulation-study arm + real-data check.** Fold into
  `KK_followup_research_plan.md`'s simulation study (one-stage-row-stacking
  vs. one-stage-random-intercept vs. two-stage, per its "Simulation Study
  Design" section) using `SimulationFramework`; compare against
  `InferencePropKKQuantileRegrOneLik` (row-stacking) and `InferencePropKKGLMM`
  (quasi-binomial) for the same response type.
- [ ] TODO-10: **Documentation + release mechanics.** Roxygen for both new
  classes (docstring pattern matching `InferencePropBetaRegr`/
  `InferenceContinKKGLMM`), registry entries, NEWS/CHANGELOG entry on
  batch close, and cross-link from `betaregscale_duplication.md` if any
  notation/scope overlap turns up when that plan's censored-beta-regression
  work lands in the same release (both touch `fast_beta_regression.cpp`
  and `InferencePropBetaRegr`-adjacent code — coordinate merge order to
  avoid conflicting edits to that file, no deeper coupling expected since
  one is about censoring and the other about matched-pair joint likelihood).

## References

- Ferrari, S., and Cribari-Neto, F. (2004). "Beta Regression for Modelling
  Rates and Proportions." *Journal of Applied Statistics*, 31(7), 799-815.
  (Mean/precision Beta parameterization and score/information used above.)
- Self, S. G., and Liang, K.-Y. (1987). "Asymptotic Properties of Maximum
  Likelihood Estimators and Likelihood Ratio Tests Under Nonstandard
  Conditions." *JASA*, 82(398), 605-610. (Boundary LRT correction for
  `sigma_b^2 = 0`.)
- Clayton, D. G. (1978). "A Model for Association in Bivariate Life Tables
  and Its Application in Epidemiological Studies of Familial Tendency in
  Chronic Disease Incidence." *Biometrika*, 65(1), 141-151; Oakes, D.
  (1982). "A Model for Association in Bivariate Survival Data." *JRSS
  Series B*, 44(3), 414-422. (Cited already in
  `inference_survival_KK_clayton_copula.R` for the rejected copula
  alternative's closed-form gamma-frailty comparison.)
- Barnard, G. A. (1963). "Some Aspects of the Fiducial Argument." *JRSS
  Series B*, 25(1), 111-114; Fraser, D. A. S. (1968). *The Structure of
  Inference*. New York: Wiley. (Marginal-likelihood/group-invariance
  framework Holt & Prentice use for the AFT log-ratio elimination — the
  same conclusion as the Gumbel-MGF route above, reached via classical
  fiducial/structural inference rather than McFadden's random-utility
  argument.)
- Andersen, E. B. (1970). "Asymptotic Properties of Conditional Maximum
  Likelihood Estimators." *JRSS Series B*, 32(2), 283-301. (Mechanism B:
  exponential-family canonical-parameter conditioning; the classical basis
  for conditional logit/Poisson pair-intercept elimination, and the
  mechanism shown above *not* to apply to Beta regression under the logit
  link.)
- McFadden, D. (1974). "Conditional Logit Analysis of Qualitative Choice
  Behavior." In *Frontiers in Econometrics*, 105-142. (The i.i.d.-Gumbel-
  difference-is-Logistic fact used in the Weibull/Mechanism-A worked
  example above; the same random-utility identity underlies multinomial
  logit's discrete-choice derivation.)
- Barndorff-Nielsen, O. E. (1978). *Information and Exponential Families in
  Statistical Theory*. Wiley. (The theory of "cuts" — a generalization of
  Andersen's canonical-parameter condition to some curved exponential
  families; named in the epistemic-status discussion above as a known
  mechanism not checked against this specific model.)
- Lehmann, E. L., and Casella, G. (1998). *Theory of Point Estimation*, 2nd
  ed. Springer, Ch. 3 (invariance / equivariant statistics; location and
  scale families as the two simplest cases of the general theory of maximal
  invariants under a group action, referenced above when scoping what this
  document has and hasn't ruled out).
- Efron, B. (1975). "Defining the Curvature of a Statistical Problem (with
  Applications to Second Order Efficiency)." *Annals of Statistics*, 3(6),
  1189-1242. (Curvature of curved exponential families; the relevant open
  tool for a fully general impossibility proof this document does not
  attempt — see the epistemic-status paragraph above.)
- Holt, J. D., and Prentice, R. L. (1974). "Survival Analyses in Twin
  Studies and Matched Pair Experiments." *Biometrika*, 61(1), 17-30.
  Independent prior art for the AFT log-ratio-is-Logistic Weibull worked
  example above, confirmed by direct reading of the primary source
  (2026-08-18). Full detail, including their right-censoring findings, is
  out of scope here — see `../new_research_ideas/KK_followup_research_plan.md`.
- Chamberlain, G. (1985). "Heterogeneity, Omitted Variable Bias, and
  Duration Dependence." In J. J. Heckman and B. Singer (eds.),
  *Longitudinal Analysis of Labor Market Data*, Cambridge University Press,
  3-38. (Conditional-MLE elimination of an individual fixed effect from
  Weibull/gamma/log-normal duration models with `T >= 2` spells per unit;
  the `T=2` case is the matched-pair case, and this is the standard
  econometric citation for the Weibull Mechanism-A trick above — developed
  as the fixed-effects response to the heterogeneity-bias problem in
  Lancaster, T. (1979), "Econometric Methods for the Duration of
  Unemployment," *Econometrica*, 47(4), 939-956.)
- Kapelner, A., and Krieger, A. (2014, 2021) — the base KK designs; see
  `pub_2021_kapelner_and_krieger_with_supp.pdf` in this directory and
  `KK_followup_research_plan.md` for full context on the matched-pair +
  reservoir structure this model is built on.
