# Censoring Support for the `continuous` Response Type

> **Depends on:** `interval_censored_survival_response.md` (generalizes its Design-layer bounds schema); `sexp_removal_rcppeigen_conversion_spec.md` conventions for kernel changes. (Global ordering: see `_master.md`.)

## Scope

Every `continuous`-response `Inference*` class currently refuses censored
data outright. This document plans how to let `response_type = "continuous"`
carry **right-censored** observations — "the true value is known only to be
at least `y`" (top-coded survey values, a sensor/reporting ceiling, a
detection limit) — through the same binary censoring flag `Design` already
uses for `survival`, and walks through feasibility for every concrete
continuous inference class in the package. Right-censored continuous
regression is, not incidentally, the textbook Tobit model (Tobin, 1958) —
the single best-precedented censoring extension anywhere in this package.

Left/interval censoring (true value known only to lie in `[L, U]`) is **out
of scope**; see "Out Of Scope" below.

This plan is a companion to
`package_metadata/new_feature_plans/censored_count_response.md`, which did
the same analysis for `response_type = "count"`. Both plans touch the same
two `Design` gate lines, so their TODO-1s should land as one coordinated
change (see "Coordination With The Count Plan" below) rather than two
competing edits.

## Current State

`Design` already has a generic per-subject censoring flag, `dead` (1 = exact
value observed, 0 = censored), gated to `survival` only:

- `R/EDI/R/design_abstract.R:130` allocates `private$dead` for every response
  type at construction time.
- `R/EDI/R/design_abstract.R:180` (`add_one_subject_response`) and
  `R/EDI/R/design_abstract.R:216` (`add_all_subject_responses`) both gate
  `dead == 0` with `stop("censored observations are only available for
  survival response types")`.
- `R/EDI/R/design_abstract.R:300-301` (`any_censoring()`) is already generic
  and needs no change.
- `R/EDI/R/other_helpers.R:226` defines `assertNoCensoring(any_censoring)`,
  which every concrete continuous `Inference*` class calls once in its own
  `initialize()`. Confirmed via
  `grep -rn assertNoCensoring R/EDI/R/inference_continuous_*.R
  R/EDI/R/inference_mixin_kk_glmm_shared.R` — it appears in
  `inference_continuous_ols.R:42`, `inference_continuous_lin.R:39`,
  `inference_continuous_robust_regr.R:51`,
  `inference_continuous_quantile_regr.R:54`,
  `inference_continuous_KK_bai_abstract.R:41` (covers
  `InferenceBaiAdjustedT` and, by inheritance, `InferenceBaiAdjustedTKK14`
  and `InferenceBaiAdjustedTKK21`, neither of which has its own assert
  call), `inference_continuous_KK_ols_ivwc.R:60`,
  `inference_continuous_KK_ols_one_lik.R:47`,
  `inference_continuous_KK_quantile_regr_ivwc.R:91`,
  `inference_continuous_KK_quantile_regr_one_lik.R:56`,
  `inference_continuous_KK_robust_regr_ivwc.R:51`,
  `inference_continuous_KK_robust_regr_one_lik.R:48`, and
  `inference_mixin_kk_glmm_shared.R:95` (covers `InferenceContinKKGLMM`,
  which sets `glmm_family = function() stats::gaussian(link = "identity")`
  at `inference_continuous_KK_glmm.R:136`).

Survival already proves the exact censored-likelihood shape this plan wants:
`WeibullAFTLikelihood` in `R/EDI/src/fast_weibull_regression.cpp:17-90`
folds `dead` directly into the log-likelihood, score, and Hessian — censored
rows drop the density term and keep only the survivor contribution. A
Gaussian version of that same construction *is* Tobit regression: for
`dead == 1` rows, the ordinary normal log-density; for `dead == 0` rows,
`log(1 - Phi((y - eta) / sigma))` where `Phi` is the standard normal CDF.
Tobit is arguably a simpler case than Weibull's AFT likelihood, not a harder
one — the survivor term is a single `pnorm` call rather than a Weibull-shape
transform.

## Proposed Semantics

Reuse `dead` as-is for `continuous`:

- `dead = 1`: `y` is the exact observed value.
- `dead = 0`: the true value is `Y >= y` (right-censored at `y`).

This is one-sided (matches survival's existing convention). Left-censoring
(detection-limit-below data, e.g. "true value is known only to be `<= y`")
is not natively supported by the single `dead` flag as currently defined,
but the standard practical workaround — negate `y` before fitting and negate
the resulting coefficient back — covers it without any schema change; this
is the same workaround the applied Tobit literature uses routinely and is
worth documenting rather than building new machinery for.

## An Important Architectural Difference From The Count Plan

The count plan (`censored_count_response.md`) could add a `dead`-aware
branch *inside* each existing kernel at effectively zero cost because
`fast_poisson_regression_cpp` and `fast_neg_bin_cpp` are already iterative
MLE optimizers — they run the same kind of loop whether or not censoring
exists, so one more per-row predicate check inside that loop is free.

`fast_ols_cpp`/`fast_ols_with_var_cpp`
(`R/EDI/src/fast_ols.cpp:76,93`) are **not** iterative — they are closed-form
`(X'X)^-1 X'y` solves. There is no closed-form solution for the Tobit
likelihood; it requires the same kind of iterative optimization Weibull
already uses. That means the zero-regression strategy for `continuous` can't
be "branch inside the existing kernel" — it has to be a **dispatch above the
kernel call**: keep the existing closed-form solver completely untouched for
the uncensored path, and route only to a new, separate Tobit-MLE kernel when
`any_censoring()` is true. This is if anything a *cleaner* guarantee than
count's in-kernel branch, since the uncensored code path is never even
compiled into the same execution branch as the new logic — it's a different
function call entirely, selected once per fit rather than once per row.

## Zero-Regression Design Principle

1. **Design layer**: same one-line gate relaxation as the count plan (see
   "Coordination With The Count Plan"); a setter invoked once per subject,
   no measurable cost.
2. **R inference layer**: `assertNoCensoring` calls are removed for Tier 1/2
   classes below (each guarded a cheap `sum()` comparison; removing the
   guard costs nothing on the uncensored path) or left as-is for Tier 3.
3. **C++/dispatch layer**: for `InferenceContinOLS`, `private$shared()`
   keeps calling `fast_ols_cpp`/`fast_ols_with_var_cpp` exactly as today
   when `!private$any_censoring()`, and only calls the new Tobit kernel
   otherwise — a single `if` at the top of `shared()`, not a change to the
   hot solve path itself. Every downstream Tier-2 class that rides on the
   OLS point estimate inherits this same "existing path untouched, new path
   opt-in" shape.

Net effect: an uncensored `continuous` design pays one relaxed `if` at
data-entry time and one branch-not-taken at fit time. No existing call
site, default, or numerical result changes for uncensored data.

## Coordination With The Count Plan

Both this plan's TODO-1 and `censored_count_response.md`'s TODO-1 edit the
same two lines (`design_abstract.R:180`, `:216`). Whichever implementation
lands first should generalize the gate to an allow-list
(`!(private$response_type %in% c("survival", "count", "continuous"))` or
equivalent), and the second plan's TODO-1 becomes a one-line addition to
that existing list rather than a second edit to the `stop()` condition.

## How Common And Important Is This In Practice?

### Right-censored continuous (Tobit)

Right-censored continuous regression is not a niche request — it is one of
the most heavily used censored-data models in applied statistics, dating to
Tobin's original 1958 paper on household durable-goods expenditure:

- Tobit-type models are described as widely used across "medical
  expenditures, labor supply behavior, internet auctions, and financial
  portfolios at the household level":
  [Tobit model — an overview | ScienceDirect
  Topics](https://www.sciencedirect.com/topics/economics-econometrics-and-finance/tobit-model)
- In labor economics, Tobit is the standard tool for labor-supply models
  where a substantial fraction of the sample has zero hours worked (e.g.
  married women's labor-force participation), and more generally for any
  "corner solution" outcome — consumer expenditure, credit amounts, labor
  supply hours:
  [The Ultimate Guide to Tobit Model in
  Econometrics](https://www.numberanalytics.com/blog/ultimate-guide-tobit-model-econometrics)
- In health economics, Tobit is the standard way to separate "the decision
  to seek care from actual usage" when modeling health-care utilization
  data with many zero visits — directly relevant to the medical/clinical
  applications this package targets:
  [The Ultimate Guide to Tobit Model in
  Econometrics](https://www.numberanalytics.com/blog/ultimate-guide-tobit-model-econometrics)
- The core econometric argument for why it matters is not stylistic:
  ordinary least squares on censored data produces *biased and
  inconsistent* estimates because it discards the censoring mechanism's
  information — Tobit isn't a refinement over OLS for censored outcomes,
  it's a correctness requirement.
- The model spans household economics, corporate finance, and regional
  health economics as a standard limited-dependent-variable tool, per a
  review of spatial discrete-choice/limited-dependent-variable models in
  regional health economics:
  [Spatial Discrete Choice and Spatial Limited Dependent Variable Models: a
  review with an emphasis on the use in Regional Health
  Economics](https://arxiv.org/pdf/1302.2267)

**Priority recommendation: highest priority among the censoring extensions
scoped across this document and its two companions**
(`censored_count_response.md`, `interval_censored_survival_response.md`).
The reasons compound rather than trade off against each other: Tobit has
the broadest, best-established real-world demand of any censored-response
family surveyed (medicine, labor economics, health economics, household
and corporate finance all reach for it routinely); `InferenceContinOLS`
is simultaneously the *cheapest* item to build (Tier 1, closed-form
likelihood, no new third-party dependency, a single dispatch point per
the architecture note above); and unlike interval-censored survival's
delegation-to-`icenReg` path or the count family's structural Tier-3
blockers, there's no missing piece that has to be commissioned as a
separate report before implementation can start. If only one item across
all three censoring plans gets built first, this document's Tier 1
(`InferenceContinOLS`) is the one with the best cost-to-value ratio.

### Interval-censored continuous

Interval censoring for continuous measurements is real and comes up more
often than interval-censored counts, but less as a single dominant
methodology than interval-censored survival's `icenReg`/Turnbull ecosystem
— it shows up as a collection of related-but-distinct problems rather than
one well-packaged family:

- Environmental and occupational-health measurement is described as
  "almost always Type I censored," and the same literature explicitly
  distinguishes interval censoring (a value known to lie in `[L, U]`, e.g.
  "5 ppb < X <= 10 ppb") from simple below-detection-limit left-censoring
  — both are common, but interval censoring specifically arises when
  measurements have *both* a lower reporting bound and an upper
  interference/saturation bound:
  [Chapter 11: Censored Data — Dealing with "Below Detection Limit"
  Values](https://pdixon.stat.iastate.edu/stat505/Chapter%2011.pdf),
  [Correcting for Censored Environmental
  Measurements](https://pubs.acs.org/doi/10.1021/acs.est.9b05042)
- Epidemiological exposure measurement faces the same issue: "upper or
  lower detection limits or interfering compounds" prevent precise
  measured values, which is a genuine interval-censoring structure, not
  just one-sided censoring:
  [Epidemiologic Evaluation of Measurement Data in the Presence of
  Detection Limits](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC1253661/)
- How much this matters in practice is dose-dependent on the *fraction*
  of censored observations: common imputation approaches for
  below-detection-limit data are biased unless the censored fraction is
  small (5-10%), and even bias-corrected approaches distort inference once
  30%+ of the data is censored — meaning interval-censored continuous data
  isn't just a rare edge case to shrug off when it does occur, the
  downstream statistical damage from ignoring it scales with how common it
  is in a given dataset:
  [Correcting for Censored Environmental
  Measurements](https://pubs.acs.org/doi/10.1021/acs.est.9b05042)
- Outside environmental/epidemiological measurement, interval-censored
  continuous data also shows up as bracketed/rounded self-report data in
  social science and economics (income and wealth surveys reported in
  brackets, "current status" designs), the continuous analogue of the
  binned-count and binned-survival-time patterns discussed in this
  document's companion plans.

**Verdict**: interval-censored continuous data sits between the two
extremes established by the companion documents — more common and more
consequential than interval-censored count data (which the count plan
finds has essentially no dedicated methodology and is usually routed
through ordinal regression instead), but less unified as a single
well-packaged methodology than interval-censored survival (which has
`icenReg`/`interval` as mature, purpose-built CRAN tooling to delegate to).
It's real enough — particularly in environmental/epidemiological
measurement with both upper and lower detection bounds — to be worth a
dedicated future feasibility pass, but per the "Out Of Scope" section
above, that pass needs its own `Design`-layer schema work (the same
`y`/`y_upper` extension `interval_censored_survival_response.md` proposes)
and is deliberately not bundled into this document's right-censoring-only
scope.

## Feasibility By Inference Type

There are 14 concrete continuous `Inference*` classes across 7 families.

### Tier 1 — Feasible now, best-precedented case in the package

- **`InferenceContinOLS`** (`R/EDI/R/inference_continuous_ols.R`) — this
  *is* Tobit regression. Requires a new censored-Gaussian MLE kernel
  (`fast_tobit_regression_cpp`/`_with_var_cpp`, new file or appended to
  `fast_ols.cpp`) implementing the likelihood/score/Hessian sketched above,
  following `WeibullAFTLikelihood`'s structure
  (`R/EDI/src/fast_weibull_regression.cpp:20-84`) with a Gaussian survivor
  term in place of the Weibull one. `shared()`
  (`inference_continuous_ols.R:203-256`) dispatches to it only when
  censored, per the architecture note above.

### Tier 2 — Moderate, rides on Tier 1, real literature precedent exists

- **`InferenceContinLin`** (`R/EDI/R/inference_continuous_lin.R`) — Lin
  (2013) covariate-adjusted OLS with an HC2 sandwich SE computed by
  `ols_hc2_post_fit_cpp` (`R/EDI/src/robust_post_fit_speedups.cpp:258`).
  The point estimate can reuse Tier 1's censored MLE; the HC2 leverage-based
  residual construction needs to be replaced with a Tobit-appropriate
  generalized residual once censoring is present (same shape of fix as the
  count plan's robust-Poisson sandwich generalization).
- **`InferenceContinQuantileRegr`** (`R/EDI/R/inference_continuous_quantile_regr.R`)
  — currently delegates entirely to `quantreg::rq()` /
  `quantreg::rq.fit()` (there is no internal C++ kernel yet for quantile
  regression at all, per the existing
  `package_metadata/new_feature_plans/quantile_regression_cpp_kernel_spec.md`).
  This is the most surprisingly easy Tier-2 item: `quantreg` already ships
  `quantreg::crq()`, implementing the well-known Portnoy/Powell censored
  quantile regression estimators. Since the package already depends on
  `quantreg`, the fix is dispatching to `crq()` instead of `rq()` when
  `any_censoring()` — an R-layer-only change, no new C++ needed either way
  (uncensored or censored), which also means the "zero regression" question
  here is really "don't change the existing `rq()` call path," which the
  dispatch trivially satisfies.
- **`InferenceContinRobustRegr`** (`R/EDI/R/inference_continuous_robust_regr.R`)
  — M-/MM-estimation via `fast_robust_regression_cpp`
  (`R/EDI/src/fast_robust_regression.cpp:227`) or `MASS::rlm`. Robust
  censored regression ("censored M-regression," robust Tobit variants) is a
  real but more bespoke literature than plain Tobit — no single dominant
  R-package function to delegate to the way `quantreg::crq()` covers
  quantile regression. Needs a genuine new IRLS-with-conditionally-imputed-
  censored-residuals scheme (EM-style). More work than `InferenceContinLin`
  or `InferenceContinQuantileRegr`, but still fundamentally an extension of
  an existing iterative estimator rather than a structural redesign.
- **`InferenceContinKKOLSOneLik`**, **`InferenceContinKKQuantileRegrOneLik`**,
  **`InferenceContinKKRobustRegrOneLik`**
  (`inference_continuous_KK_ols_one_lik.R`,
  `inference_continuous_KK_quantile_regr_one_lik.R`,
  `inference_continuous_KK_robust_regr_one_lik.R`) — the "OneLik" KK
  variants build one combined design matrix/model across the matched-set
  and reservoir components and fit it through the same underlying
  estimator. If that underlying estimator (OLS/Tobit, quantile, robust)
  becomes censoring-aware, these should mostly inherit that support for
  free — verify during implementation rather than assume, since the exact
  combined-design-matrix construction wasn't traced in this pass.

### Tier 2/3 boundary — combining-layer classes gated by their components

- **`InferenceContinKKOLSIVWC`**, **`InferenceContinKKQuantileRegrIVWC`**,
  **`InferenceContinKKRobustRegrIVWC`**
  (`inference_continuous_KK_ols_ivwc.R`,
  `inference_continuous_KK_quantile_regr_ivwc.R`,
  `inference_continuous_KK_robust_regr_ivwc.R`) — "IVWC" (inverse-variance-
  weighted combination) variants fit a matched-pair estimate and a
  reservoir estimate *separately* and combine them by inverse-variance
  weighting. Unlike the "OneLik" variants, both sub-estimates need their
  own censoring-aware point estimate *and* variance before the combination
  step means anything — strictly more work than OneLik, gated on Tier 1/2
  landing first, and needs its own scoping pass to confirm the combination
  math itself (not just the sub-estimators) tolerates censored inputs.

### Tier 3 — Hard, structural, second-wave

- **`InferenceBaiAdjustedT`** (`R/EDI/R/inference_continuous_KK_bai_abstract.R`)
  and its **`InferenceBaiAdjustedTKK14`** / **`InferenceBaiAdjustedTKK21`**
  subclasses — this estimator is built directly from sample moments: paired
  differences (`d_i = yT - yC`) and reservoir group means/variances
  (`compute_reservoir_and_match_statistics`,
  `compute_bai_variance_for_pairs` at
  `inference_continuous_KK_bai_abstract.R:257-279`). A censored observation
  has no well-defined raw value to difference or average — this needs a
  restricted-mean or Tobit-conditional-mean substitute wherever a raw `y`
  currently enters a sum, which is a real methodological redesign (the same
  shape of problem the count plan's `InferenceCountPoissonKKGEE` has: a
  moment-based estimator built on raw observed values rather than a
  likelihood). Flag as a second-wave project.
- **`InferenceContinKKGLMM`** (`R/EDI/R/inference_continuous_KK_glmm.R`,
  via the `KKGLMM` component — source `inference_mixin_kk_glmm_shared.R`,
  formerly the `InferenceMixinKKGLMMShared` mixin — Gaussian family) — integrates the
  exact-value likelihood over a random effect via Gauss-Hermite
  quadrature/Laplace, same shared machinery the count plan's
  `InferenceCountKKGLMM` uses. This is comparatively more tractable than
  the Poisson-GLMM case in `censored_count_response.md`, because the
  censored-Gaussian conditional density is a single closed-form `pnorm`
  term rather than a discrete survivor sum — but it still requires
  modifying the quadrature integrand itself, not adding a branch to
  existing code. Moderate-to-hard; second-wave.

## Out Of Scope: Interval/Left-Censored Continuous Data

General interval censoring (`Y` known only to lie in `[L, U]`) needs the
same kind of `Design`-layer schema change flagged as **hard** for survival
in `package_metadata/interval_censored_survival_response_type_report.md`
and for count in this plan's companion document — a second bound column,
not a reuse of `y` + `dead`. `package_metadata/semi_continuous_response_type_report.md`
already flags the related "detection-limit-censored (true Tobit)" case for
*zero-inflated* continuous responses as blocked on exactly the
`assertNoCensoring()` gate this plan proposes lifting for plain continuous
responses — this document is a prerequisite for that harder follow-on case,
not a duplicate of it. See `censored_count_response.md`'s appendix for a
literature-grounded discussion of how common interval-censored data is in
practice; the same conclusions (common in periodic-visit clinical/survey
contexts, generally best served by a dedicated future project rather than
folded into this one) apply here.

## TODOs

### Prerequisite (shared with the count plan — see "Coordination" above)

- [ ] TODO-1: Relax `design_abstract.R:180` and `design_abstract.R:216` to
  allow `dead == 0` for `response_type %in% c("survival", "count",
  "continuous")` (generalize to an allow-list if `censored_count_response.md`'s
  TODO-1 hasn't landed yet; otherwise just add `"continuous"` to the
  existing list). Update the `add_one_subject_response`/
  `add_all_subject_responses` roxygen to document continuous semantics
  ("true value is >= y"). Add a regression test confirming uncensored
  `continuous` designs behave identically to today.
- [ ] TODO-2: Audit bootstrap/permutation/randomization-inference paths that
  resample or copy `y`/`dead` together for `continuous` designs, mirroring
  the count plan's TODO-2 — a verification pass, not new code, since this
  already works correctly for `survival`.

### Tier 1 — OLS / Tobit

- [ ] TODO-3: Implement a new censored-Gaussian MLE kernel
  (`fast_tobit_regression_cpp`/`fast_tobit_regression_with_var_cpp`),
  following `WeibullAFTLikelihood`'s log-likelihood/score/Hessian structure
  (`R/EDI/src/fast_weibull_regression.cpp:20-90`) with the Gaussian
  survivor function `1 - pnorm((y - eta) / sigma)` in place of the Weibull
  one, jointly estimating `beta` and `log_sigma` the same way Weibull does.
- [ ] TODO-4: In `InferenceContinOLS$private$shared()`
  (`inference_continuous_ols.R:203-256`), add a top-level dispatch: call
  the existing `fast_ols_cpp`/`fast_ols_with_var_cpp` path unchanged when
  `!private$any_censoring()`, call the new Tobit kernel from TODO-3
  otherwise. Remove `assertNoCensoring` at `inference_continuous_ols.R:42`.
- [ ] TODO-5: Add censored-data unit tests (point-estimate recovery under
  simulated right-censoring against a known Tobit ground truth) plus a
  benchmark confirming the uncensored path is bit-identical and shows no
  measurable slowdown, mirroring the count plan's TODO-6.

### Tier 2 — Lin / Quantile / Robust and their "OneLik" KK variants

- [ ] TODO-6: Update `InferenceContinLin`'s HC2 sandwich construction
  (`ols_hc2_post_fit_cpp`, `R/EDI/src/robust_post_fit_speedups.cpp:258`) to
  use a Tobit-appropriate generalized residual once TODO-3/4 land; remove
  `assertNoCensoring` at `inference_continuous_lin.R:39`.
- [ ] TODO-7: In `InferenceContinQuantileRegr`'s `fit_quantile_model`/
  `compute_estimate_with_bootstrap_weights`
  (`inference_continuous_quantile_regr.R:70-107,188-207`), dispatch to
  `quantreg::crq()` when `any_censoring()` is true, keep the existing
  `quantreg::rq()`/`rq.fit()` path untouched otherwise. Remove
  `assertNoCensoring` at `inference_continuous_quantile_regr.R:54`.
- [ ] TODO-8: Scope and implement a censored M-/MM-estimation scheme for
  `InferenceContinRobustRegr` (literature: robust/censored Tobit
  M-regression), most likely an EM-style IRLS with conditionally-imputed
  censored residuals. Remove `assertNoCensoring` at
  `inference_continuous_robust_regr.R:51`.
- [ ] TODO-9: Once TODO-4/7/8 land, verify (or extend as needed) that
  `InferenceContinKKOLSOneLik`, `InferenceContinKKQuantileRegrOneLik`, and
  `InferenceContinKKRobustRegrOneLik` correctly propagate censoring through
  their combined matched-set/reservoir design matrix construction; remove
  `assertNoCensoring` at `inference_continuous_KK_ols_one_lik.R:47`,
  `inference_continuous_KK_quantile_regr_one_lik.R:56`,
  `inference_continuous_KK_robust_regr_one_lik.R:48`.
- [ ] TODO-10: Once TODO-4/7/8 land, extend
  `InferenceContinKKOLSIVWC`, `InferenceContinKKQuantileRegrIVWC`, and
  `InferenceContinKKRobustRegrIVWC` so both the matched-pair and reservoir
  sub-estimates independently support censoring before the
  inverse-variance-weighted combination step; confirm the combination math
  itself needs no further change. Remove `assertNoCensoring` at
  `inference_continuous_KK_ols_ivwc.R:60`,
  `inference_continuous_KK_quantile_regr_ivwc.R:91`,
  `inference_continuous_KK_robust_regr_ivwc.R:51`.

### Tier 3 — Explicitly deferred, second-wave

- [ ] TODO-11: Commission a follow-up feasibility report for censored
  Bai-adjusted-t inference (`InferenceBaiAdjustedT`,
  `InferenceBaiAdjustedTKK14`, `InferenceBaiAdjustedTKK21`), scoping how to
  replace the raw matched-pair-difference and reservoir sample mean/
  variance statistics (`inference_continuous_KK_bai_abstract.R:225-279`)
  with censoring-aware substitutes (e.g. restricted-mean or
  Tobit-conditional-mean estimators).
- [ ] TODO-12: Commission a follow-up feasibility report for censored
  `InferenceContinKKGLMM`, scoping the Gauss-Hermite/Laplace
  quadrature-integrand change needed to fold in a closed-form censored-
  Gaussian conditional density term.
