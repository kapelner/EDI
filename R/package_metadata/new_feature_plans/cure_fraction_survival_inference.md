# Cure-Fraction (Mixture-Cure) Survival Inference — Scoping Report

> **Depends on:** shipped shallow inference hierarchy
> (`define_inference_class()`, components, registry metadata); the shipped
> y/y_L/y_R interval-censoring rework; `marginal_estimand_report.md`'s
> `set_estimand()` axis (shipped) for declaring which of the model's two
> effects is `beta_T`. No design-side dependency. Decision-gated (TODO-1).
> Independent of `competing_risks_response.md` (different question, same
> response type). (Global ordering: see `_master.md`; not yet indexed in
> `release_v1_1_0.md` — see TODO-0.)

Written 2026-08-27, commissioned from the "missing response families"
follow-up to `missing_inference_classes_literature_audit.md`. This is a
**new inference-class family on the existing `survival` response type** —
no storage change, no new response type — so it is a small standalone
plan.

## Scope

### The setting

Standard survival models assume every subject would eventually experience
the event if followed long enough: S(t) → 0 as t → ∞. In some settings a
fraction of subjects are effectively **cured** and never have the event,
so the Kaplan-Meier curve flattens to a plateau and stays there. Canonical
cases:

- oncology: relapse-free / recurrence-free survival after curative-intent
  therapy (the plateau is the cured fraction);
- smoking cessation: time to first relapse — some quitters never relapse;
- criminology: time to recidivism — some offenders never reoffend;
- credit / reliability: time to loan default, time to first failure of a
  defect-free unit;
- education / labour: time to dropout, time to leaving unemployment where
  some never do within the horizon.

### The model

The **mixture cure model** (Boag 1949; Farewell 1982; Sy & Taylor 2000;
Peng & Dear 2000) writes the population survival function as

```
S(t | x) = π(x) + (1 − π(x)) · S_u(t | x)
```

- `π(x)` — the **cure (incidence) probability**, modelled by a logistic
  regression `logit π(x) = x'γ`;
- `S_u(t | x)` — the survival function of the **uncured (latency)**
  subjects, modelled parametrically (Weibull AFT is standard; log-normal,
  log-logistic also common) or semiparametrically (Cox-type, Sy & Taylor
  2000, needs EM).

A treatment therefore has **two effects**: it can raise the cured fraction
(`γ_T`, a log odds ratio of cure) and/or delay the event among the uncured
(`β_T`, a log time ratio or log hazard ratio in the latency part). A plain
Cox hazard ratio blends the two and violates proportional hazards whenever
the plateaus differ by arm — which is precisely why the model exists.

The alternative **promotion-time (bounded cumulative hazard) cure model**
(Yakovlev & Tsodikov 1996; Chen, Ibrahim & Sinha 1999) writes
`S(t | x) = exp(−θ(x) F(t))` with `log θ(x) = x'β`, giving cure fraction
`exp(−θ)` and preserving proportional hazards; it has one treatment
coefficient, which fits EDI's scalar contract naturally.

Fitting: mixture cure by direct ML (parametric latency) or EM
(semiparametric latency). Identifiability requires adequate follow-up past
the plateau (Maller & Zhou 1996 provide a test); with insufficient
follow-up `π` and the latency tail are confounded and the fit is
unstable — a warning/diagnostic is part of the plan.

### Frequency in the experimental literature

- **Oncology**: occasional. Used for relapse/recurrence endpoints in
  haematology, melanoma, head-and-neck and paediatric trials where
  curative intent makes a plateau expected; more common in registry/
  secondary analyses than as a pre-specified primary analysis (estimate:
  low single-digit percent of oncology TTE trials). The methods literature
  is substantial (Amico & Van Keilegom 2018 review; Peng & Yu 2021
  monograph).
- **Behavioural / criminology / economics**: rare in RCT reports;
  split-population duration models (Schmidt & Witte 1989) appear in
  recidivism and unemployment-duration work, mostly observational.
- **Practitioner default when a plateau is visible**: run Cox anyway,
  note the PH violation, or switch to RMST. So the *need* is real but
  modest — this is a "do it right" feature for a recognizable niche, not
  a workhorse. Ranked below competing risks and recurrent events in the
  audit follow-up.

## What EDI Has Today

- `InferenceSurvivalWeibullRegr` (`inference_survival_weibull.R:487`):
  full-likelihood Weibull AFT via the native
  `fast_weibull_regression_cpp(X, y, dead, …)` kernel (right-censoring)
  and `fast_weibull_regression_general_cpp` (left/interval), with
  components `BayesianBootstrap`, `ParametricLikelihoodBootstrap`,
  `SurvivalWeibullLikelihood`; `likelihood_tier = "full"`; supports
  general censoring. This is the natural latency-part building block.
- `InferenceIncidLogRegr`: logistic regression kernel — the natural
  incidence-part building block.
- The `estimand` axis (`set_estimand()` / `get_supported_estimands()`)
  already lets a class expose more than one scalar target per fit
  (conditional vs marginal for Poisson/beta/etc.) — the right mechanism
  for choosing between the cure effect and the latency effect.
- `InferenceSurvivalKMDiff` / `RestrictedMeanDiff` — nonparametric
  comparators; RMST is what practitioners reach for under a plateau.
- Neither `flexsurvcure`, `smcure`, `cuRe`, nor `flexsurv` is in
  `Suggests` (`DESCRIPTION:44`).

No design class is affected; `DesignSeqOneByOneKK21`'s survival weighting
(AFT per covariate) is unaffected.

## Proposed Classes

### `InferenceSurvivalMixtureCureWeibull` (first wave)

Parametric mixture cure model: logistic incidence part + Weibull AFT
latency part, both with treatment + `model_formula` covariates (optionally
separate formulas `cure_formula` / `latency_formula`, defaulting to the
same covariate set). Direct ML of the joint likelihood

```
L = Π_i [ (1−π_i) f_u(y_i) ]^{d_i} [ π_i + (1−π_i) S_u(y_i) ]^{1−d_i}
```

(right-censoring), with the interval-censored analogue using `S_u(y_L) −
S_u(y_R)` in place of `f_u`, exactly as the existing general Weibull
kernel does.

**Two effects, one scalar contract.** Use the `estimand` axis:

- `estimand = "latency"` (default): `beta_T` = log time ratio among the
  uncured (`β_T` in the Weibull AFT part). Default because it is the
  continuation of what `InferenceSurvivalWeibullRegr` reports.
- `estimand = "cure"`: `beta_T` = log odds ratio of being cured (`γ_T`).
- `estimand = "marginal_survival_diff"` (optional, later): difference in
  population S(t*) at a horizon, via g-computation over the fitted model
  — the most interpretable single number for trialists and the one that
  connects to RMST/KM comparators.

Inference contracts: Wald from the joint Fisher information; likelihood-
ratio / score / gradient via the existing `LikelihoodTests` component
(profile over the other effect); `BayesianBootstrap` and
`ParametricLikelihoodBootstrap` reuse; randomization test by refit per
permutation.

**Implementation route.** Two options, pick at TODO-1:

1. **Native kernel (`use_rcpp = TRUE`)**: a new
   `fast_mixture_cure_weibull_cpp(X_cure, X_lat, y, dead | y_L, y_R, …)`
   L-BFGS fit reusing the Weibull log-likelihood pieces from
   `fast_weibull_regression_*_cpp` and the logistic pieces from the
   logit kernel; analytic gradient; Fisher information by finite
   differences or analytic Hessian. Follows
   `sexp_removal_rcppeigen_conversion_spec.md` conventions
   (`EDI_CORE_ONLY` split if Python-bound). Medium effort.
2. **Delegation (`use_rcpp = FALSE` / parity oracle)**:
   `flexsurvcure::flexsurvcure(Surv(y, dead) ~ w + …, dist = "weibull",
   mixture = TRUE, anc = list(shape = ~ …))` or `smcure::smcure(...,
   model = "aft")`. `flexsurvcure` is the better oracle (direct ML,
   interval censoring supported via `Surv(type = "interval2")`,
   `flexsurv` is well-maintained); add to `Suggests`.

Recommended: ship route 2 first as the reference and fallback, route 1 as
the fast path in the same wave if the kernel is straightforward (it is —
it is two existing likelihoods glued by a mixture), otherwise as a
follow-up. Randomization inference on route 2 is slow (one `flexsurvcure`
fit per permutation); the native kernel is what makes randomization/
bootstrap practical.

### `InferenceSurvivalPromotionTimeCure` (second wave, optional)

Promotion-time model `S(t|x) = exp(−exp(x'β) F(t))` with a Weibull `F`.
Single treatment coefficient (log ratio of `θ`, which is both a PH hazard
ratio and a log-log ratio of cure fractions), so it fits the scalar
contract with no estimand switch. Cheaper than the mixture model and
PH-consistent; less interpretable to clinicians. Include if the mixture
kernel makes it nearly free (same likelihood skeleton with a different
mixing).

### Diagnostics (part of first wave)

- **Sufficient follow-up check** (Maller & Zhou 1996): flag when the
  largest observed event time is close to the largest censoring time, or
  when the KM plateau is not established; emit a warning that `π` may be
  weakly identified.
- **Boundary handling**: `π̂ → 0` (no cure — collapses to plain Weibull)
  and `π̂ → 1` (all cured — latency unidentified). Report `NA` for the
  latency effect at the `π̂ = 1` boundary rather than a spurious estimate;
  reuse the existing `set_failed_fit_cache()` pattern.
- A `get_cure_fraction_by_arm()` accessor (fitted `π̂` at `w = 0, 1`
  averaged over covariates) for reporting.

## Not In Scope

- Semiparametric (Cox-latency) mixture cure via EM (Sy & Taylor 2000;
  `smcure` `model = "ph"`) — heavier, no closed-form information, and the
  parametric Weibull latency covers the applied use cases. Revisit if
  requested.
- KK IVWC/OneLik variants — pair-stratified cure models are not standard.
- Competing risks with cure — separate, and rare.
- `SimulationFramework` generator changes beyond a simple option
  (`cure_fraction = c(pi_C, pi_T)` on the survival generator) — the truth
  is closed-form (`γ_T = logit(pi_T) − logit(pi_C)`; latency `β_T` from
  the existing Weibull generator), so this is small and can ship with the
  first wave.

## Testing

- Parity vs `flexsurvcure` (and `smcure` AFT) on right-censored and
  interval-censored fixtures at tight tolerance for both `γ̂_T` and
  `β̂_T` and their SEs.
- Reduction: with `cure_formula` forced to `π = 0` the class reproduces
  `InferenceSurvivalWeibullRegr` exactly.
- Simulation: recover known `(γ_T, β_T)` at increasing `n` with adequate
  follow-up; demonstrate degraded identifiability with truncated
  follow-up (the Maller-Zhou warning fires).
- Boundary fixtures: all-cured arm, no-cure data.
- Registry: name `InferenceSurvival…` so `infer_inference_response_types()`
  picks it up; `supports_general_censoring = TRUE` (interval likelihood is
  part of the design); estimand metadata lists `"latency"`, `"cure"`,
  optionally `"marginal_survival_diff"`; fixture matrix rows in
  `public_argument_combination_constraints.R`.

## Effort Summary

| Item | Effort | Dependencies |
|---|---|---|
| `flexsurvcure` delegation path + class shell + estimand switch + diagnostics | small–medium | `flexsurvcure` in `Suggests` |
| Native `fast_mixture_cure_weibull_cpp` kernel (gradient + information) | medium | Weibull/logit kernel pieces (exist) |
| Promotion-time variant | small (on top of kernel) | — |
| `SimulationFramework` cure option | small | — |

## Recommendation

**Pursue as a small v1.1.0 (or later) item, after competing risks and the
count exposure offset.** It is a self-contained inference-class addition
on an existing response type with a clear oracle for parity, and the
`estimand` axis already solves the two-effects problem cleanly. The
frequency is modest (occasional in oncology, rare elsewhere), so this is a
"correctness for a recognizable niche" feature; if backlog pressure is
high it can be deferred without loss.

## Implementation TODOs

- [x] TODO-0: **Done (2026-08-27)** — indexed as `release_v1_1_0.md →
  TODO-15g` and `_master.md` Phase 5L (after 5K); TODO-1 joins the Phase 0
  decision batch.
- [ ] TODO-1: **Decision — ask the user**: pursue at all; default estimand
  (`"latency"` recommended); route 1 (native kernel) in the first wave or
  delegation only; include the promotion-time variant; `flexsurvcure` in
  `Suggests`.
- [ ] TODO-2: `InferenceSurvivalMixtureCureWeibull` via `flexsurvcure`
  delegation: class shell, `cure_formula`/`latency_formula`, estimand
  switch, Wald/bootstrap/randomization contracts, Maller-Zhou follow-up
  diagnostic, boundary handling, `get_cure_fraction_by_arm()`.
- [ ] TODO-3: Native `fast_mixture_cure_weibull_cpp` kernel (right + general
  censoring), `use_rcpp = TRUE` path, parity tests vs TODO-2, LR/score/
  gradient tests through `LikelihoodTests`.
- [ ] TODO-4: `SimulationFramework` `cure_fraction` option and closed-form
  truth for both estimands; simulation tests incl. truncated-follow-up
  identifiability demo.
- [ ] TODO-5 (optional): `InferenceSurvivalPromotionTimeCure`.
- [ ] TODO-6 (optional): `"marginal_survival_diff"` estimand via
  g-computation; vignette section contrasting Cox / RMST / mixture-cure
  on a plateau dataset; update `response_types_landscape_report.md`'s
  survival section and the inference audit to point here.
