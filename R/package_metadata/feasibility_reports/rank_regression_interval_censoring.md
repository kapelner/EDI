# Feasibility Report: KK Rank-Regression IVWC Under Interval Censoring

## Status

Commissioned by TODO-12 in
`package_metadata/finished_features/interval_censored_survival_response.md`
("Commission a follow-up feasibility report for
`InferenceSurvivalKKRankRegrIVWC`/`InferenceAbstractKKSurvivalRankRegrIVWC`
under interval censoring, surveying rank-based interval-censored AFT
estimators as candidate approaches — no dominant existing R-package
function to delegate to, unlike the Tier 2 families above").

**Bottom line: the delegation path Tier 2 relies on does not exist for
this class, confirmed by direct inspection of the installed `aftgee`
package (not just recollection) — its `aftsrr()` documentation states
plainly that its response must be "a `Surv` object with right censoring,"
and the package exports no interval-censoring-capable alternative.**
Unlike TODO-11 (closed-form, mechanical, if laborious) and unlike TODO-10
(an identifiability question), this is a genuine "no ready building
block" gap: real rank-based interval-censored AFT estimators exist in the
literature, but implementing one means either building a new numerical
estimating-equation solver from a paper (not delegating to an existing
one), or dropping rank-based estimation for this response combination
in favor of a fallback strategy such as approximate imputation onto the
existing right-censored machinery. This report scopes both paths without
recommending implementation yet.

## What The Class Does Today

`InferenceAbstractKKSurvivalRankRegrIVWC`
(`R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R`) is the same
matched-pairs-plus-reservoir, inverse-variance-weighted-combination
IVWC pattern as the other KK survival classes in this plan (see
`shared()`, lines 179-236), but where the strat-Cox/LWA-Cox classes
delegate to `survival::coxph()`-family kernels and the Clayton-copula
class uses this package's own C++ kernel, this class delegates *entirely*
to the CRAN package `aftgee`, specifically `aftgee::aftsrr()`
(Accelerated Failure Time with Smooth Rank Regression — Chiou, Kang &
Yan's induced-smoothing extension of the classic Gehan/Prentice-Wilcoxon
rank-based AFT estimating equations). Both the matched-pairs component
(`aftsrr_for_matched_pairs()`, clustering matched pairs via `id = strata`
so the induced-smoothing sandwich variance accounts for the pairing) and
the reservoir component (`aftsrr_for_reservoir()`, no clustering) build
a `data.frame` with `y`/`dead`/`w`/covariates and call
`aftgee::aftsrr(survival::Surv(y, dead) ~ w + ..., id = ..., se =
"ISMB")`. This is a genuine Tier 2-style clean delegation *for the
right-censored case* — the package correctly offloads all of the rank
regression's real numerical complexity (the induced-smoothing solve, the
sandwich variance) to a maintained CRAN package rather than reimplementing
it, which is exactly the right call. The problem is specifically that
this delegation target has no interval-censored mode to switch into.

## Verified: `aftgee` Has No Interval-Censoring Support

This was checked directly against the actually-installed package
(`aftgee` 1.2.1) in this environment, not recalled from general
knowledge:

```r
> args(aftgee::aftsrr)
function (formula, data, subset, id = NULL, contrasts = NULL,
    weights = NULL, B = 100, rankWeights = c("gehan", "logrank",
        "PW", "GP", "userdefined"), eqType = c("is", "ns", "mis",
        "mns"), se = c("NULL", "bootstrap", "MB", "ZLCF", "ZLMB",
        "sHCF", "sHMB", "ISCF", "ISMB"), control = list())
```

The package's own `?aftsrr` documentation states, verbatim, under the
`formula` argument: *"The `response` is a `Surv` object object with
right censoring."* `ls("package:aftgee")` exposes exactly two
model-fitting entry points, `aftgee()` (a GEE-based AFT estimator,
also right-censoring-only per its analogous documentation) and `aftsrr()`
— no third, interval-censoring-capable function exists in the package,
and neither does an alternate `type=` argument on `aftsrr()` itself the
way `survival::Surv(..., type = "interval2")` exists at the data-object
level. Contrast this directly with what made Tier 2 easy: `icenReg::ic_sp()`
and `interval::ictest()`/`icfit()` are *purpose-built* for interval data
and were found by searching for exactly that use case; there is no
equivalently dominant, purpose-built CRAN package for *rank-based*
interval-censored AFT estimation the way there is for interval-censored
Cox/KM — this is precisely the asymmetry TODO-12 was written to confirm,
and it is confirmed.

## What The Actual Literature Offers

Rank-based (Gehan/Wilcoxon-type) estimating equations for AFT models
under interval censoring are a real, published research topic, just
without a single dominant, actively-maintained R implementation the way
`icenReg` dominates interval-censored Cox/AFT-via-NPMLE. Two broad
families exist:

- **Imputation/weighting-based Gehan estimators.** The classic approach
  (going back to Pan, 2000, and refined by several follow-ups) reduces
  interval-censored data to a synthetic right-censored or fully-observed
  dataset by multiply imputing exact event times within each `[L, R]`
  window (typically from the current-iteration model fit, i.e., an
  EM-like or multiple-imputation loop), then runs the *ordinary*
  Gehan estimating equations — potentially this package's existing
  `aftsrr(..., rankWeights = "gehan")` call — on the imputed data,
  repeating across imputations and combining. This has the attractive
  property of reusing `aftgee::aftsrr()` almost as-is rather than
  requiring a hand-rolled solver, at the cost of needing to build and
  validate the imputation loop itself (draw candidate `T` from the
  current model's implied conditional distribution within `[L, R]`,
  refit, iterate to convergence, combine — variance estimation across
  the imputation loop also needs its own derivation, since `aftsrr`'s
  own sandwich SE assumes its input is the true observed data, not an
  imputed draw).
- **Direct interval-censored rank estimating equations.** A smaller,
  more specialized literature (e.g. Betensky, Rabinowitz & Tsiatis-style
  work on rank-based inference for interval-censored regression, and
  later refinements) derives estimating equations directly analogous to
  the Gehan statistic but built from `[L,R]`-interval comparisons instead
  of point comparisons — no imputation loop, but a genuinely new
  estimating equation and variance sandwich to implement and verify from
  scratch, with no CRAN package to lean on for either the solve or the
  variance.

Neither of these is close to the "swap one delegated call for another"
shape of Tier 2, nor the "extend a closed-form kernel already in this
codebase" shape of TODO-11's Clayton-copula finding. Both require either
a real from-scratch numerical-methods implementation, or building and
validating a nontrivial imputation wrapper around an existing delegated
call — either way, meaningfully more work than anything else scoped in
this plan so far.

## A Third, Pragmatic Option Worth Naming

Given the matched-pairs-plus-reservoir IVWC combination this class
already performs is itself an approximation (inverse-variance-weighting
two separately-fit components rather than one joint model — the same
approximation every other IVWC class in this plan makes), a defensible
narrower scope for a first pass would be: **support interval censoring
only via the imputation-based approach above, reusing the existing
`aftsrr()` calls unchanged inside an outer multiple-imputation loop**,
rather than attempting the from-scratch estimating-equation derivation.
This keeps the delegation-first spirit of Tier 2 (no new C++ numerical
kernel, no new closed-form derivation to verify) at the cost of a slower,
iterative fit and a variance estimate that needs to correctly combine
within-imputation and between-imputation uncertainty (Rubin's rules or
a bootstrap-of-imputations scheme) — itself nontrivial to get right, but
substantially more contained than deriving new estimating equations from
a paper.

## Recommendation

Do not write implementation TODOs for a from-scratch rank-based
interval-censored estimating equation without an explicit decision from
the package maintainer about which of the two real options above (or a
third, e.g. dropping rank-based estimation for this response/design
combination entirely and pointing users at the Tier 2 Cox/KM-delegation
classes instead when they have interval-censored KK-matched survival
data) is worth the engineering investment relative to how often this
specific model (rank-regression AFT + KK matching + interval censoring,
a fairly narrow intersection of features) is actually likely to be used.
If pursued, the imputation-based option above is the more tractable
starting point — it reuses this class's existing `aftgee::aftsrr()` calls
almost unchanged and confines the new work to the outer imputation loop
and its variance combination, rather than requiring new estimating-equation
derivations verified against no existing reference implementation.
