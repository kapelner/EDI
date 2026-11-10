# Feature Plan: Duplicate `betaregscale` — Interval-Censored Beta Regression for `proportion`

> **Depends on:** `censored_continuous_response.md` (its Tier-1 censored-quantile machinery is reused verbatim for the proportion logit-transform path); `interval_censored_survival_response.md` (schema). (Global ordering: see `_master.md`.)

## Status

This is a committed feature plan. It merges and supersedes
`package_metadata/new_research_ideas/censored_proportion_regression.md`
("Interior-Threshold Censored Proportion Regression"), which has been
deleted — its feasibility tiering across all 9 proportion `Inference*`
classes, its "What This Is (And Isn't)" scoping, and its "Next Steps"
are folded into this document below (see "Scope: What This Is (And
Isn't)" and "Feasibility By Inference Type"). This document narrows that
material to one concrete, primary target: duplicating the CRAN package
`betaregscale`'s functionality natively inside this package's own
beta-regression kernel, while retaining the deleted document's wider
survey of the other 8 proportion inference classes for completeness.

**This plan corrects the deleted document's central "Prior Art" claim.**
Its "Prior Art (Or Lack Thereof)" section stated: "Searching for a
dedicated 'censored beta regression' ... methodology for this specific
combination ... did not turn up one," and framed the work as "a genuine
(if narrow) methodological contribution" rather than a port of existing
work. That search missed one: **`betaregscale`** (CRAN) — "Beta
Regression for Interval-Censored Scale-Derived Outcomes" — does
maximum-likelihood estimation of beta regression for responses treated
as interval-censored on `(0,1)`, with the likelihood built from the
difference of the Beta CDF at the interval endpoints, and supports both
fixed- and variable-dispersion submodels. That is the same mechanism the
deleted document independently derived by hand for
`InferencePropBetaRegr`'s Tier 1 item (`log(pbeta(U, mu*phi, (1-mu)*phi)
- pbeta(L, mu*phi, (1-mu)*phi))`).

**Practical consequence**: this is no longer purely a from-scratch
research contribution — there is a published, working reference
implementation to check the math against and to validate a native port's
output on shared test data. But this package's established practice for
in-house kernels that already exist (see `interval_censored_survival_response.md`'s
Weibull item, extended natively rather than delegated to a third-party
package) argues for **native re-implementation inside
`fast_beta_regression.cpp`**, not adding `betaregscale` as a runtime
dependency — `fast_beta_regression_cpp` is already an iterative in-house
MLE optimizer (unlike Cox/KM, which had no in-house NPMLE engine to
extend and legitimately needed to delegate to `icenReg`/`interval`). See
"Delegate vs. Duplicate" below for the full reasoning; `betaregscale`'s
proper role in this plan is as a **test-time oracle**, not a production
dependency.

## Scope: What This Is (And Isn't)

This plan is about a third, distinct kind of censoring for a `[0,1]`
proportion response — **interior-threshold censoring**: "we know the
true proportion is `< 0.30`" or "we know it's `> 0.88`," at a threshold
set by the measurement/reporting process, not by the domain's natural
edge. It is explicitly *not* either of the two things this package could
plausibly be confused with:

- **Not zero-one-inflation.** `InferencePropZeroOneInflatedBetaRegr`
  (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R`) already
  handles exact mass piling up at `0` and `1` via a mixture model. That's
  a different empirical pattern (subjects making a categorically
  different decision at the boundary) from what this plan addresses.
- **Not two-limit Tobit at the natural boundary.** A structural latent
  variable that would exceed `0` or `1` if unclipped (the LGD/credit-risk
  case) is a different mechanism than an arbitrary interior detection
  threshold. This plan's threshold can be anywhere in `(0,1)`, not just
  at the domain edge.

A real-world pattern motivating this: clinical chimerism monitoring and
complex-biomarker reporting (MSI, TMB, genomic loss-of-heterozygosity)
routinely report proportions only relative to an assay-defined confidence
threshold — e.g. "insufficient tumor purity to call" below some cutoff
(literature figures range roughly 10%-35% depending on the biomarker), or
chimerism detectable "well below 1%" but not always precisely quantified
below that. That's a genuine interior-threshold-censored proportion, and
exactly what `betaregscale`'s interval-censored-on-`(0,1)` mechanism is
built to handle.

## What `betaregscale` Actually Provides (Target Feature Set)

Read directly from its CRAN description, three capabilities need to be
matched for a genuine "duplicate":

1. **Interval-censored beta likelihood.** Observations may be exact,
   left-censored, right-censored, or interval-censored on `(0,1)`, with
   the log-likelihood built from Beta-CDF differences at the known
   interval endpoints — this is the core mechanism and the primary
   target of this plan.
2. **Variable-dispersion submodel.** Covariates may enter the precision
   parameter `phi`, not just the mean `mu` — `phi_i = g(Z_i' gamma)`
   alongside `mu_i = h(X_i' beta)`, both with configurable link
   functions. This is a **second, independent** feature from
   interval-censoring — a variable-dispersion *uncensored* beta
   regression is already useful on its own, and censoring composes with
   it rather than depending on it.
3. **Scale-to-unit transform for bounded rating-scale data.** Designed
   for responses "derived from bounded rating scales" — i.e. raw scores
   on a known bounded scale (e.g. a 0-100 assay reading, a 1-7 Likert
   scale) get linearly rescaled to `(0,1)` before fitting, typically with
   a small `epsilon` boundary adjustment so exact 0/1 don't break the
   Beta density's `(0,1)`-open-interval requirement. This is a data-prep
   convenience layered on top of (1)+(2), not new numerical machinery —
   lowest priority of the three.

This plan's primary scope is (1); it treats (2) as a valuable,
independently-shippable companion feature (see "Variable-Dispersion
Submodel" below) and (3) as a documentation/convenience item deferred to
the TODOs' tail.

## Current State (Verified Against The Codebase)

- **The `Design`-layer `y`/`y_L`/`y_R` schema this plan needs already
  exists**, landed by `interval_censored_survival_response.md`'s TODO-1:
  `design_abstract.R:127-131` allocates `y_L`/`y_R` alongside `y` for
  every `Design`, regardless of response type, both `NA_real_` by
  default.
- **But it is currently hard-gated to `response_type == "survival"`
  only**: `design_abstract.R:184-186` —
  ```r
  if (has_bounds && private$response_type != "survival"){
      stop("censored observations are only available for survival response types")
  }
  ```
  A `proportion` design cannot record a censored response today; this
  gate must be relaxed to admit `"proportion"` as part of this plan.
- **Even for `survival`, only right-censoring is actually accepted.**
  `design_abstract.R:216-222` explicitly `stop()`s on any finite `y_R`
  other than through the `y_R = Inf` right-censoring path:
  ```r
  if (is.finite(y_R)){
      if (y_L == 0){
          stop("Left censoring is not implemented yet.")
      } else {
          stop("Interval censoring is not implemented yet -- only exact and
  right-censored (y_R = Inf) survival data is currently supported.")
      }
  }
  ```
  This means **no engine anywhere in this package currently consumes
  left- or interval-censored data** — confirmed by grep: no survival
  `Inference*` file (including `inference_survival_weibull.R`, the
  Tier-1 target of the sibling survival plan) reads `y_L`/`y_R` yet;
  `interval_censored_survival_response.md`'s TODO-3/TODO-4 (extending the
  Weibull kernel and threading the bounds through) are still open (`[ ]`,
  not `[x]`). **This is a shared prerequisite, not proportion-specific
  work** — see "Coordinate With The Survival Plan" below.
- **`InferencePropBetaRegr`'s kernel has no incomplete-beta machinery to
  build from.** `fast_beta_regression.cpp`'s `BetaRegression::operator()`
  (density term at lines 82-88, gradient at 89-99) computes an ordinary
  pointwise Beta log-density — `-lgamma(phi) + lgamma(a) + lgamma(b) -
  (a-1)*log(y) - (b-1)*log(1-y)` where `a = mu*phi`, `b = (1-mu)*phi` —
  using `fast_lgamma`/`fast_digamma`/`fast_trigamma_vec` helpers already
  in the codebase. Grepping the entire `R/EDI/src/` tree for `pbeta`
  finds **zero hits** — no C++ kernel in this package currently evaluates
  the incomplete beta function at all. This confirms the research
  document's framing: the censored-beta score/Hessian is new derivation
  work, not adaptation of existing algebra.
- **Precision `phi` is currently a single scalar, package-wide, per
  fit** — `const double phi = std::exp(params[m_p])` (`fast_beta_regression.cpp:58`)
  — not a per-observation `phi_i` driven by covariates. `betaregscale`'s
  variable-dispersion submodel has no existing analog anywhere in this
  kernel; it is 100% new work, independent of censoring (see below).
- **`InferencePropBetaRegr$initialize()`** (`inference_proportion_beta.R:38`)
  calls `assertNoCensoring(private$any_censoring)`
  (`other_helpers.R:226`, gated on `design_abstract.R:382`'s
  `any_censoring()`), which must be relaxed for this class specifically
  once the kernel supports censored rows — mirroring exactly how
  `assertNoCensoring` gates are lifted per-class in the sibling plans,
  never globally.
- `betareg` is already an existing `Suggests` dependency
  (`R/EDI/DESCRIPTION:39`) for this package, though for an unrelated
  purpose (uncensored beta-regression comparisons elsewhere) — not the
  same as `betaregscale`, which is a separate, much newer, more narrowly
  scoped CRAN package and is not currently a dependency of any kind.

## Coordinate With The Survival Plan — Don't Duplicate The Gate-Lifting

The `design_abstract.R:184-222` gates are not response-type-specific in
structure — they're one shared block that happens to currently only
whitelist `"survival"`, and the left-/interval-censoring `stop()`s inside
it aren't parameterized by domain at all. Lifting them independently for
`survival` (per `interval_censored_survival_response.md`'s TODO-3/4) and
for `proportion` (per this document) risks two inconsistent
implementations of the same gate if done separately. Recommended
sequencing:

1. Whoever implements interval-censoring support first (survival's
   Weibull kernel or this plan's beta kernel — either could go first, see
   TODOs) should generalize `design_abstract.R:184-222` into a single
   **response-type-parameterized** check: which response types currently
   accept `has_bounds` (a whitelist, extended from `{"survival"}` to
   `{"survival", "proportion"}`), and a domain-bound check keyed off
   response type (`survival`: `y_L >= 0`, `y_R` unbounded above;
   `proportion`: `0 <= y_L`, `y_R <= 1`) rather than the current
   survival-only `y_L >= 0` check at `design_abstract.R:210-211`.
2. The `stop("... censoring is not implemented yet")` guards at
   `design_abstract.R:216-222` should be removed **per response type**,
   only once that response type's engine(s) actually consume `y_L`/`y_R`
   for computation — not lifted globally the moment either engine lands.
   Concretely: if the Weibull kernel (TODO-3/4 in the survival plan)
   lands first, the beta kernel's rows must still be rejected until this
   plan's own kernel work lands, and vice versa. A per-response-type flag
   or a small registry (`response types with a working censored engine`)
   is cleaner than sequential `stop()` removal races between two
   documents' implementers.
3. Whoever lands second should read the other document's TODO list
   before touching `design_abstract.R:184-222`, to avoid clobbering the
   other's needed generalization.

## Delegate vs. Duplicate: Why Native, Not A `betaregscale` Dependency

This package's own precedent (per `interval_censored_survival_response.md`)
draws the delegate/native line at "does an in-house engine already
exist": Weibull AFT is native (closed-form MLE already in-house,
extended in place); Cox/KM-family delegate to `icenReg`/`interval`
(no in-house NPMLE/EM engine existed to extend). Beta regression falls
on the native side of that line — `fast_beta_regression_cpp` is already
a from-scratch, in-house, iterative MLE optimizer
(`fast_beta_regression.cpp:345`), so extending its likelihood with a
censored branch is architecturally the same shape as the Weibull
extension, not the Cox/KM one. Concretely:

- Native gives a single unified kernel producing coefficient estimates,
  standard errors (via the existing Hessian-based path,
  `fast_beta_regression_with_var_cpp`, `fast_beta_regression.cpp:465`),
  and this package's design-conservative jackknife/bootstrap machinery
  for free, the same way every other `Inference*` class gets it — a
  `betaregscale`-delegation path would need custom glue to reshape its
  fit object into this package's `compute_estimate`/
  `compute_asymp_confidence_interval` contract, and `betaregscale` was
  not written with this package's resampling-based inference paths in
  mind — published asymptotic theory for a delegated fit does not
  automatically transfer cleanly to this package's design-based
  (jackknife/bootstrap/randomization) inference machinery, the same
  caveat the sibling survival plan raises about `icenReg`/`interval`.
- `betaregscale` is a young, narrowly-scoped package; treating it as a
  hard runtime dependency for a core response family is a heavier
  commitment than treating it as an optional validation oracle.

**`betaregscale`'s actual role in this plan**: add it as a **test-only**
`Suggests` entry (`R/EDI/DESCRIPTION`'s `Suggests:` block, alongside
`betareg`, `testthat`, etc.), used exclusively in the new unit tests
(TODO-6 below) to cross-check this package's native censored-beta point
estimates against `betaregscale`'s fit on identical simulated
interval-censored data — analogous to how other `Inference*` classes in
this package are tested against a reference implementation where one
exists, but never called from production code.

## Proposed Numerical Extension

### Core: censored-row branch in `BetaRegression`

`fast_beta_regression.cpp`'s `operator()` (score) and `hessian()` both
loop per-observation computing a pointwise Beta density term. Add a
per-row branch, keyed on whether the row is exact (`y` present) or
censored (`y_L`/`y_R` present, mirroring the `L`/`R` pattern
`WeibullAFTLikelihood` uses for survival, per
`interval_censored_survival_response.md`'s Tier 1 item):

- **Exact** (today's only path): unchanged, `-lgamma(phi) + lgamma(a) +
  lgamma(b) - (a-1)*log(y) - (b-1)*log(1-y)`.
- **Censored**: `-log(pbeta(U, a, b) - pbeta(L, a, b))`, using R's
  `Rf_pbeta` (already available — `Rmath.h` is already included at
  `fast_beta_regression.cpp:6`, and this file already links against it
  indirectly through the digamma/trigamma helpers) with `a = mu*phi`,
  `b = (1-mu)*phi` as today. `L = 0` recovers a left-censored
  contribution (`-log(pbeta(U, a, b))`); `U = 1` recovers a
  right-censored contribution (`-log(1 - pbeta(L, a, b))`) — the same
  "one formula, both edge cases fall out algebraically" property
  `interval_censored_survival_response.md` found for `log(S(L) - S(R))`.
- **Score/Hessian — the genuinely hard, novel part.** The exact-row
  gradient uses `d/d(mu) log f(y; mu, phi)` via `digamma(a)`,
  `digamma(b)` (`fast_beta_regression.cpp:91-99`). The censored-row
  gradient instead needs `d/d(mu) log(I_U(a,b) - I_L(a,b))` where `I_x`
  is the regularized incomplete beta function — i.e. the partial
  derivatives of `pbeta` with respect to its two shape parameters `a`,
  `b` (not with respect to its argument `x`, which is the easy/standard
  case). This derivative has a known closed form but is algebraically
  involved (expressible via the generalized hypergeometric function
  `3F2` or as a defined integral with no elementary closed form in
  general — see e.g. Boik & Robison-Cox (1998), "Derivatives of the
  Incomplete Beta Function," *Journal of Statistical Software* 3(1),
  which is the standard reference implementation target for this exact
  problem). This is the one piece in this document with no existing
  in-repo implementation to check against (confirmed above: zero
  `pbeta` hits anywhere in `R/EDI/src/`) — see "What Would Actually Be
  Novel Here" below.
- **Recommended sequencing to de-risk the hard part**: ship a first,
  slower-but-correct version using `numDeriv` (already an `Imports`
  dependency, `R/EDI/DESCRIPTION:26`) to numerically differentiate the
  censored-row log-likelihood term for the gradient/Hessian contribution,
  validated against `betaregscale`'s point estimates (which do not
  require this package to have its own analytic derivative — `betaregscale`
  presumably has its own, independently derived, gradient/Hessian).
  Once the numeric-gradient version is verified correct end-to-end
  (estimate recovery on simulated data, standard errors calibrated),
  replace the censored-row contribution to `grad`/`H` with the
  closed-form Boik & Robison-Cox derivative as a pure performance
  optimization. This splits what would otherwise be a hard prerequisite
  ("derive the `pbeta`-difference score/Hessian before committing to any
  C++ kernel work") into a shippable numeric-first milestone plus a
  follow-up analytic one, rather than blocking all progress on getting
  the closed form right first.

### Variable-Dispersion Submodel (independent feature)

To fully match `betaregscale`'s feature set (not just its censoring
mechanism), `phi` needs to become per-observation: `phi_i = exp(Z_i'
gamma)` (log link, matching the existing scalar `phi`'s implicit log
link via `params[m_p]`), with `Z` a second design matrix (defaulting to
intercept-only, recovering today's single-`phi` behavior exactly — the
zero-regression default). This touches the same loop as the censoring
branch but is logically orthogonal — recommend implementing and testing
it independently (uncensored variable-dispersion beta regression is
already a useful, shippable feature on its own, well precedented in
`betareg`'s own `| dispersion_formula` syntax) **before** combining it
with the censored-row branch, so failures in one don't get attributed to
the other during development.

## R6 / Package Integration

Following this package's established pattern (the Weibull survival
extension modifies its existing class in place rather than adding a
parallel shell class): extend `InferencePropBetaRegr`
(`inference_proportion_beta.R`) itself, not a new sibling class. The
`assertNoCensoring(private$any_censoring)` guard at
`inference_proportion_beta.R:38` is removed (or made conditional, if a
staged rollout is preferred — e.g. gated behind a constructor argument
during initial development, then unconditionally removed once the
kernel's censored branch is verified). `private$y`/`private$y_L`/
`private$y_R` are threaded into `fast_beta_regression_cpp`/`_with_var_cpp`/
`_weighted_cpp` the same way `WeibullAFTLikelihood` is planned to consume
`get_effective_time()`-style accessors in the survival plan — except
here there's no legacy `dead`-flag reconstruction needed, since
`proportion` never had a `dead` concept to begin with; the accessor is
simply "is this row's `y` non-`NA`."

`assertResponseType`/domain validation: add a `[0,1]` bound assertion for
`y`, `y_L`, `y_R` when `response_type == "proportion"` — today's
survival-oriented check at `design_abstract.R:210-211` only enforces
`y_L >= 0` with no upper bound, which is correct for survival's `[0,
Inf)` domain but wrong for `proportion`'s `[0,1]` domain; this is exactly
the response-type-parameterized domain check described in "Coordinate
With The Survival Plan" above.

## Zero-Regression Design Principle

Same shape as every sibling document: `y_L`/`y_R` default to `NA` (already
true today, `design_abstract.R:130-131`), so an uncensored `proportion`
design is unaffected. Inside the kernel, the exact-row branch is
untouched code (today's `operator()`/`hessian()` bodies stay exactly as
they are for rows where `y` is present); the censored-row branch is
strictly additive — new code executed only when a row actually carries
`y_L`/`y_R`. A regression test comparing a fully-uncensored dataset's fit
before/after this change should be bit-identical, the same guarantee the
survival plan makes.

## Feasibility By Inference Type

There are 9 concrete proportion `Inference*` classes (excluding
`InferencePropZeroOneInflatedBetaRegr`, out of scope per "Scope: What
This Is (And Isn't)" above) across 5 families. This plan's primary
target is the Tier 1 item below (`InferencePropBetaRegr`); the rest are
retained here for completeness (folded in from the deleted
`censored_proportion_regression.md`) but are not addressed by this
plan's TODOs.

### Tier 1 — Primary target of this plan: feasible now, in-kernel branch

- **`InferencePropBetaRegr`** (`R/EDI/R/inference_proportion_beta.R`) —
  full beta-regression MLE via `fast_beta_regression_cpp`/
  `_with_var_cpp`/`_weighted_cpp` (`fast_beta_regression.cpp:345, 402,
  465`), already an iterative optimizer (not closed-form), so a
  censored-row-aware branch can live *inside* the existing kernel the
  same way Poisson/NegBin's branches do in the sibling count plan, no
  separate dispatch kernel needed. The censored-row likelihood
  contribution is `log(pbeta(U, mu*phi, (1-mu)*phi) - pbeta(L, mu*phi,
  (1-mu)*phi))` — a regularized-incomplete-beta-function difference, i.e.
  the beta-distribution analogue of the `S(L) - S(R)` construction used
  throughout the sibling censoring documents. See "Proposed Numerical
  Extension" above for the full kernel-level plan, including why the
  score/Hessian derivative is the one genuinely novel piece here.
  Structurally comparable in difficulty to `censored_continuous_response.md`'s
  Tobit item and `interval_censored_survival_response.md`'s Weibull item
  — this is the anchor case for this whole family of censoring plans.

### Tier 1/2 — Cheapest item in this family, via reuse (not this plan's scope)

- **`InferencePropQuantileRegr`** (`R/EDI/R/inference_proportion_quantile_regr.R`)
  — fits `quantreg::rq()` on `logit(private$y)`, not on the raw proportion
  (`inference_proportion_quantile_regr.R:73-107,191-207`). Since `logit`
  is a strictly increasing bijection `(0,1) -> R`, an interval-censored
  `Y` with bounds `[L, U]` maps directly to an interval-censored
  `logit(Y)` with bounds `[logit(L), logit(U)]` on the real line — exactly
  the input `quantreg::crq()` expects. This means the dispatch
  `censored_continuous_response.md`'s TODO-7 already proposes
  (`rq()` -> `crq()` when censored) can be **reused verbatim** here, just
  feeding transformed bounds instead of raw ones. No new methodology, no
  new dependency beyond what the continuous plan already adds. Likely the
  single cheapest censoring item across every response-type censoring
  plan in this repository — worth doing first or in parallel with this
  plan's Tier 1 work, since it shares no kernel code with it.
- **`InferencePropKKQuantileRegrIVWC`/`OneLik`**
  (`inference_proportion_KK_quantile_regr_ivwc.R`,
  `inference_proportion_KK_quantile_regr_one_lik.R`) — inherit
  `InferencePropQuantileRegr`'s tier via the same logit-transform trick;
  "OneLik" likely needs only a censoring-aware combined design/model call
  into the same delegated fit, "IVWC" needs the matched-set and reservoir
  sub-estimates to each independently support censoring before the
  inverse-variance combination — the same OneLik/IVWC asymmetry flagged
  throughout the sibling documents.

### Tier 2 — Moderate, quasi-likelihood, genuine modeling ambiguity (not this plan's scope)

- **`InferencePropFractionalLogit`**
  (`R/EDI/R/inference_proportion_fractional_logit.R`) — this is Papke &
  Wooldridge's fractional-response QMLE, implemented by literally calling
  `fast_logistic_regression_cpp`/`_with_var_cpp` on the raw fractional `y`
  (`inference_proportion_fractional_logit.R:134-206`). It works as a
  quasi-likelihood (a valid estimating equation regardless of the true
  distribution of `y`) precisely because the score `(y - mu) * x` doesn't
  require `y` to be a real Bernoulli draw. That's also what makes
  censoring genuinely ambiguous here, unlike the Tier 1 Beta case: there's
  no unique "correct" censored quasi-score, because there's no underlying
  density to integrate over `[L, U]` in the first place — only a working
  equation. A defensible fix is to substitute a conditional-expectation
  term for the censored `y` in the score (analogous to the count plan's
  robust-Poisson sandwich fix), but that's a modeling choice to make
  explicit and defend, not a derivation. Since `fast_logistic_regression_cpp`
  is already iterative, an in-kernel branch is architecturally cheap once
  the modeling question is settled — the cost here is intellectual, not
  computational. **If this is ever promoted**: settle the censored-score
  modeling question (what does "censoring" mean for a quasi-likelihood
  with no underlying density?) as its own short design note before
  writing code, since it's a genuine judgment call, not a derivation.
- **`InferencePropGCompMeanDiff`** (+ its abstract parent
  `InferencePropGCompAbstract`, `R/EDI/R/inference_proportion_gcomp.R`) —
  built directly on the same `fast_logistic_regression_cpp` fractional-logit
  fit (`fit_fractional_logit_with_sandwich`,
  `inference_proportion_gcomp.R:440-524`), then standardizes to a
  mean-difference effect (`compute_standardized_effect_components`,
  `inference_proportion_gcomp.R:525-549`). Inherits
  `InferencePropFractionalLogit`'s Tier-2 status and its modeling
  ambiguity; the standardization step itself needs no separate censoring
  treatment once the underlying fractional-logit fit is censoring-aware.

### Tier 3 — Hard, structural, same reasoning as the sibling documents (not this plan's scope)

- **`InferencePropKKGEE`** (`R/EDI/R/inference_proportion_KK_combined.R`,
  via the `KKGEE` component — source `inference_mixin_kk_gee_shared.R`,
  formerly the `InferenceMixinKKGEEShared` mixin — `gee_family = stats::binomial(link =
  "logit")` at `inference_proportion_KK_combined.R:106`) — binomial-family
  GEE built on working residuals across the matched/reservoir design.
  Same IPCW-GEE-style blocker flagged for `InferenceCountPoissonKKGEE` in
  `censored_count_response.md`. **If this is ever promoted**: commission a
  dedicated feasibility/scoping pass before writing implementation TODOs.
- **`InferencePropKKGLMM`** (`inference_proportion_KK_combined.R`, via
  `fast_clogit_plus_glmm_cpp`) — combines a conditional-logit component
  (matched-set) with a GLMM random-effects integral (reservoir), i.e. it's
  the proportion family's analogue of `InferenceCountKKGLMM`/
  `InferenceContinKKGLMM` *plus* an additional conditional-likelihood
  layer on top. Likely harder than either sibling GLMM case precisely
  because of that extra layer. **If this is ever promoted**: needs its own
  dedicated scoping pass before any implementation TODO is written, not
  folded into Tier 3 by analogy alone.

### What Would Actually Be Novel Here

Worth naming explicitly, independent of `betaregscale`'s existence:
`InferencePropBetaRegr`'s Tier 1 item — a censored-beta log-likelihood
with `pbeta`-difference contributions, fit via this package's own
in-house MLE machinery with its own design-conservative
jackknife/bootstrap inference layered on top — does not appear to exist
as a published, named methodology the way Tobit-Poisson,
Tobit/two-limit-Tobit, and interval-censored-Cox/`icenReg` all do for the
sibling response types (`betaregscale` is a working implementation, not
a named peer-reviewed methodology with its own asymptotic theory
citation). If built, this package's version — with resampling-based
inference `betaregscale` itself doesn't provide — would plausibly be
worth documenting as its own contribution, not treated purely as an
internal feature.

## TODOs

### Prerequisite / Coordination

- [x] TODO-0: Merge
  `package_metadata/new_research_ideas/censored_proportion_regression.md`
  into this document and delete it, correcting its "Prior Art" section's
  claim that no dedicated censored-beta-regression methodology exists
  along the way (see this document's opening section). **Done** — its
  content is folded into "Scope: What This Is (And Isn't)" and
  "Feasibility By Inference Type" above; the source file no longer
  exists.
- [ ] TODO-1: Generalize `design_abstract.R:184-222`'s response-type
  whitelist and domain-bound checks per "Coordinate With The Survival
  Plan" above, extended to admit `"proportion"` with a `[0,1]` bound
  (not just `"survival"`'s `[0, Inf)`). Coordinate with whoever is
  implementing `interval_censored_survival_response.md`'s TODO-3/4 to
  avoid duplicate/conflicting edits to the same lines.
- [ ] TODO-2: Add a `[0,1]` domain assertion for `y`/`y_L`/`y_R` when
  `response_type == "proportion"` (today's checks are survival-shaped:
  `y_L >= 0`, no upper bound).

### Core Kernel Work

- [ ] TODO-3: Add the censored-row branch to `BetaRegression::operator()`
  (`fast_beta_regression.cpp:57-101`) using `Rf_pbeta`-difference
  log-likelihood, initially with `numDeriv`-based numeric
  gradient/Hessian for the censored contribution (see "Recommended
  sequencing" above).
- [ ] TODO-4: Add the matching censored-row branch to
  `BetaRegression::hessian()` (`fast_beta_regression.cpp:110-160+`),
  same numeric-first approach.
- [ ] TODO-5: Derive (or find/adapt, e.g. from Boik & Robison-Cox 1998)
  the closed-form analytic derivative of the regularized incomplete beta
  function with respect to its shape parameters, and swap it in to
  replace the numeric-differentiation fallback from TODO-3/4 as a
  performance optimization, verified bit-compatible (within numerical
  tolerance) against the numeric version on the same test data first.
- [ ] TODO-6: Add `betaregscale` as a test-only `Suggests` dependency
  (`R/EDI/DESCRIPTION`); write unit tests simulating interval-censored
  proportion data and comparing this package's native fit (point
  estimates, and standard errors where `betaregscale` exposes them)
  against `betaregscale::betaregscale()`'s fit on the same data.
- [ ] TODO-7: Thread `y_L`/`y_R` through `InferencePropBetaRegr`
  (`inference_proportion_beta.R`) into the extended kernel; relax the
  `assertNoCensoring` guard at `inference_proportion_beta.R:38`.
- [ ] TODO-8: Add censored-proportion unit tests at the `Design`/
  `Inference` integration level (not just the C++ kernel level) —
  point-estimate recovery on simulated left-, right-, and
  interval-censored proportion data; confirm the uncensored path is
  bit-identical before/after (zero-regression check).

### Variable-Dispersion Submodel (independent, can proceed in parallel)

- [ ] TODO-9: Add a `phi` design matrix `Z` (default intercept-only,
  recovering today's scalar-`phi` behavior exactly) and a
  `dispersion_formula` constructor argument to `InferencePropBetaRegr`,
  mirroring `betareg`'s `| dispersion_formula` convention.
- [ ] TODO-10: Extend `BetaRegression`'s score/Hessian for a
  per-observation `phi_i = exp(Z_i' gamma)` instead of a single scalar
  `phi`, on uncensored data first (independent of TODO-3/4/5), then
  verify it composes correctly with the censored-row branch once both
  land.

### Lower Priority

- [ ] TODO-11: Add a scale-to-unit transform convenience helper
  (bounded rating-scale input -> `(0,1)` with a small boundary
  `epsilon`, matching `betaregscale`'s "scale-derived outcomes" framing)
  as user-facing documentation/utility, not new kernel numerics.

## Appendix: `betaregscale` Reference

- CRAN: `betaregscale` — "Beta Regression for Interval-Censored
  Scale-Derived Outcomes." MLE for beta regression where the response is
  interval-censored on `(0,1)`; likelihood built from Beta-CDF
  differences at interval endpoints; supports mixed censoring types
  (uncensored, left, right, interval) in a single dataset; fixed- and
  variable-dispersion submodels; flexible mean/precision link functions.
- Boik, R.J. & Robison-Cox, J.F. (1998). "Derivatives of the Incomplete
  Beta Function." *Journal of Statistical Software*, 3(1) — standard
  reference for the closed-form incomplete-beta-function shape-parameter
  derivatives needed for TODO-5.
- Ferrari, S. & Cribari-Neto, F. (2004). "Beta Regression for Modelling
  Rates and Proportions." *Journal of Applied Statistics* 31(7):799-815 —
  the mean-precision beta regression parameterization this package's
  existing `fast_beta_regression_cpp` kernel already implements, and
  that `betaregscale`'s variable-dispersion submodel (TODO-9/10) also
  builds on.
