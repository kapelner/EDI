# Censoring Support for the `count` Response Type

> **Depends on:** `censored_continuous_response.md` (its TODO-1 makes this plan's TODO-1 a one-line addition); `interval_censored_survival_response.md` (schema). (Global ordering: see `_master.md`.)

## Scope

Today every count-response `Inference*` class refuses censored data outright.
This document plans how to let `response_type = "count"` carry **right-censored**
observations — "the true count is known only to be at least `y`" (e.g. an
observation window closed before events stopped accruing, or a reporting cap
was hit) — through the same binary censoring flag `Design` already uses for
`survival`, and walks through feasibility for every concrete count inference
class in the package.

Left/interval censoring (count known only to lie in `[L, U]`) is **out of
scope** for this plan; see "Out Of Scope: Interval-Censored Counts" below for
why, and the Appendix for how common each form actually is in practice.

## Current State

`Design` already has a generic per-subject censoring flag, `dead` (1 = exact
value observed, 0 = censored) — it just happens to be usable only when
`response_type == "survival"` today:

- `R/EDI/R/design_abstract.R:130` allocates `private$dead` for every response
  type at construction time, not just `survival`.
- `R/EDI/R/design_abstract.R:180` (`add_one_subject_response`) and
  `R/EDI/R/design_abstract.R:216` (`add_all_subject_responses`) both gate
  `dead == 0` with `stop("censored observations are only available for
  survival response types")`.
- `R/EDI/R/design_abstract.R:300-301` (`any_censoring()`) is already fully
  generic — `sum(private$dead) < length(private$dead)` — it works for any
  response type unchanged.
- `R/EDI/R/other_helpers.R:226` defines `assertNoCensoring(any_censoring)`,
  which every count `Inference*` class calls once in its own `initialize()`
  to hard-refuse censored designs. Confirmed via
  `grep -rn assertNoCensoring R/EDI/R/inference_count_*.R
  R/EDI/R/inference_mixin_kk_*.R` — it appears in
  `inference_count_poisson.R:40`, `inference_count_negbin.R:38`,
  `inference_count_quasipoisson.R:37`, `inference_count_robust_poisson.R:37`,
  `inference_count_hurdle.R:83`,
  `inference_count_zero_augmented_poisson_abstract.R:46`,
  `inference_count_KK_cond_poisson.R:92,458,1230`,
  `inference_mixin_kk_gee_shared.R:147`, and
  `inference_mixin_kk_glmm_shared.R:95`.

Survival already proves the exact likelihood pattern this plan reuses:
`WeibullAFTLikelihood` in `R/EDI/src/fast_weibull_regression.cpp:17-90` folds
`dead` directly into the log-likelihood, score, and Hessian — for censored
rows (`dead == 0`) it drops the density term and keeps only the survivor
contribution (`m_exp_w` alone, no `log_sigma`/`log_y` term), and for `dead ==
1` rows the arithmetic is bit-for-bit what an uncensored fit would compute.
That "censored rows just zero out part of a per-row sum" shape is exactly
what a censored count likelihood needs, and it's why the zero-regression goal
below is achievable rather than aspirational.

## Proposed Semantics

Reuse `dead` as-is for `count`:

- `dead = 1`: `y` is the exact observed count.
- `dead = 0`: the true count is `Y >= y` (right-censored at `y`).

The censored-row likelihood contribution is the discrete survivor
probability `P(Y >= y) = 1 - F(y - 1)`, where `F` is the count
distribution's CDF (`ppois`/`pnbinom` at the C++ level). This is *simpler*
than continuous right-censoring: there's no hazard-function machinery needed
because, unlike a continuous density, a discrete PMF has genuine positive
mass at `y`, so `P(Y >= y)` is just "1 minus the CDF," directly computable
with the same `lambda`/`theta` parameterization the uncensored kernels
already use.

## Zero-Regression Design Principle

Every layer follows the same shape `WeibullAFTLikelihood` already validates
in this codebase — cost only shows up per-row via a branch, and when
`dead` is all-ones the formula reduces identically to today's:

1. **Design layer**: `design_abstract.R:180`/`:216` change from
   `private$response_type != "survival"` to
   `!(private$response_type %in% c("survival", "count"))`. This is a setter
   invoked once per subject at data-entry time, nowhere near a hot loop —
   the branch-condition change itself has no measurable cost either way.
2. **R inference layer**: `assertNoCensoring(private$any_censoring)` calls
   are removed (Tier 1/2 classes below) or left as-is (Tier 3 classes, which
   keep refusing censoring). Where removed, the call was already a cheap
   `sum()` comparison guarding a `stop()` — removing the guard for the
   uncensored case costs nothing, and the uncensored code path is otherwise
   untouched.
3. **C++ kernel layer**: new `dead` arguments default to (or are checked
   against) an all-ones vector. Mirroring
   `WeibullAFTLikelihood::operator()` in
   `R/EDI/src/fast_weibull_regression.cpp:44-64`, the censored-row branch is
   `dead(i) ? <existing log-pmf term> : <new log-survivor term>`; when every
   `dead(i) == 1` this reduces to exactly the current sum with one extra
   per-row predicate check — the same overhead the Weibull kernel has
   already carried in production.

Net effect: an uncensored `count` design (the overwhelming majority of
current and future users) pays a single relaxed `if` at data-entry time and,
if the new kernels are used, one branch-per-row in C++ that the compiler
predicts trivially since it's uniformly taken. No existing call site,
default, or numerical result changes for uncensored data.

## Feasibility By Inference Type

There are ~13 concrete count `Inference*` classes across 8 architectural
families. Grouped by how hard censoring is to add:

### Tier 1 — Feasible now: full-MLE point families

- **`InferenceCountPoisson`** (`R/EDI/R/inference_count_poisson.R`) — pure
  Poisson MLE. Censored-row contribution:
  `log(1 - ppois(y - 1, lambda))`. Score/Hessian w.r.t. `eta` (where
  `lambda = exp(eta)`) are closed-form via the chain rule through the
  survivor function — this is the textbook "Tobit-type censored Poisson"
  model (Terza 1985; see Appendix). Requires a `dead`-aware branch added to
  `fast_poisson_regression_cpp`/`fast_poisson_regression_with_var_cpp`
  (`R/EDI/src/fast_poisson_regression.cpp:373` and friends).
- **`InferenceCountNegBin`** (`R/EDI/R/inference_count_negbin.R`) — NegBin
  MLE via `fast_neg_bin_cpp` (`R/EDI/src/fast_negbin_regression.cpp:468`).
  Same idea with `pnbinom` as the survivor function; the extra dispersion
  parameter `theta` needs its own derivative through the censored term
  (standard digamma-based NegBin derivative machinery already exists in this
  kernel for the uncensored log-likelihood, so this is "extend," not
  "invent"). Established precedent: censored/Tobit-type negative binomial
  regression is a real applied-econometrics model (see Appendix).

**Effort**: new `dead`-aware likelihood/score/Hessian branches in 2 C++
files, following the Weibull pattern; R-layer changes are just removing the
`assertNoCensoring` guard and threading `private$dead` through to the
kernel calls (mirroring how `inference_survival_weibull.R` already threads
`private$dead` at, e.g., line 107 and line 184).

### Tier 2 — Moderate, rides on Tier 1: pseudo-/quasi-likelihood families

- **`InferenceCountRobustPoisson`** (`R/EDI/R/inference_count_robust_poisson.R`,
  inherits `InferenceCountCompositeLikelihood`) — the point estimate is a
  Poisson MLE, so it can reuse Tier 1's censored kernel directly. The
  robust sandwich "meat," however, is currently built from raw residuals
  `resid = private$y - mu_hat`
  (`inference_count_robust_poisson.R:190-191`, `fit_count_model_with_var`),
  which is undefined for a censored `y`. Fix: replace the residual with the
  per-row score contribution of the censored log-likelihood (for Poisson,
  the uncensored score row *is* `(y - mu) * x`, so this is a strict
  generalization, not a redesign — for censored rows the score row becomes
  the survivor-based term derived in Tier 1).
- **`InferenceCountQuasiPoisson`** (`R/EDI/R/inference_count_quasipoisson.R`,
  same parent) — same reasoning; the dispersion parameter is currently
  estimated from Pearson residuals `(y - mu) / sqrt(mu)`, also undefined
  under censoring. Two defensible fixes: (a) substitute a
  deviance-residual-style term derived from the censored log-likelihood, or
  (b) exclude censored rows from the dispersion-estimation sum only (since
  dispersion only rescales the variance, not the point estimate). This is a
  judgment call to make explicit in implementation, not a blocker.

**Effort**: no new C++ kernels beyond what Tier 1 already adds — this tier
is almost entirely an R-layer change to how the sandwich "meat" and
dispersion scalar are computed from the (now dead-aware) fitted model.

### Tier 3 — Hard: structurally incompatible with censoring as designed today

- **Zero-augmented/hurdle family** — `InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedPoisson`, `InferenceCountZeroInflatedNegBin`
  (all inherit `InferenceCountZeroAugmentedPoissonAbstract`,
  `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`),
  `InferenceCountHurdleNegBin`
  (`R/EDI/R/inference_count_hurdle.R:56-555`), and the KK matched-design
  variants `InferenceCountKKHurdlePoissonIVWC` /
  `InferenceCountKKHurdlePoissonOneLik`
  (`R/EDI/R/inference_count_KK_cond_poisson.R:54,433`). These already split
  the likelihood into a structural-zero mass `pi` and a
  zero-truncated/full count submodel. Adding right-censoring introduces a
  *third* possible row fate (exact zero / exact positive count / censored at
  `y`), and the censored contribution has to mix across both processes:
  `P(Y >= y | censored) = pi * 1[y <= 0] + (1 - pi) * P(Y >= y | count
  process)`. That's a real likelihood-construction problem across ~6
  variants (2 backends each: internal Rcpp and `glmmTMB`), not a small
  patch. Flag as a second-wave project.
- **`InferenceCountPoissonKKGEE`** (`R/EDI/R/inference_count_KK_gee.R`, via
  the `KKGEE` component — formerly the `InferenceMixinKKGEEShared` mixin,
  `R/EDI/R/inference_mixin_kk_gee_shared.R:147`) — GEE estimating equations
  are built from working residuals across a matched/reservoir design.
  Adapting to censored counts needs an IPCW-GEE-style correction
  (Lin & Ying-style; a real but separate literature, not a code-level
  extension of the existing working-independence machinery).
- **`InferenceCountKKGLMM`** (`R/EDI/R/inference_count_KK_combined.R`, via
  the `KKGLMM` component — formerly the `InferenceMixinKKGLMMShared` mixin,
  `R/EDI/R/inference_mixin_kk_glmm_shared.R:95`) — the Poisson GLMM
  integrates the exact-count likelihood over a random effect (Gauss-Hermite
  quadrature / Laplace, per `fast_poisson_glmm_cpp`). Extending the
  integrand to include the discrete survivor term inside the random-effects
  integral is a real numerical-integration project, not a branch.
- **`InferenceCountKKCondPoissonOneLik`**
  (`R/EDI/R/inference_count_KK_cond_poisson.R:1213-1213+`) — combines
  matched-set and reservoir components on top of whatever base model it
  wraps, so its feasibility is entirely gated by the tier of the model it's
  built on (currently Tier 3 by inheritance).

`InferenceCountCompositeLikelihood`
(`R/EDI/R/inference_count_composite_likelihood.R`) itself is an abstract
parent, never instantiated directly — no independent TODO; it's covered by
its Tier 2 subclasses.

## Out Of Scope: Interval-Censored Counts

General interval censoring (`Y` known only to lie in `[L, U]`, not just `Y
>= y`) needs a real `Design`-layer schema change — a second bound column,
not a reuse of `y` + `dead` — and would touch every response-storage call
site (`add_one_subject_response`, `add_all_subject_responses`, the
bootstrap/permutation resamplers that currently copy `y`/`dead` in lockstep,
etc.). The sibling document
`package_metadata/finished_features/interval_censored_survival_response.md`
rates the survival analogue of this schema change as real but more tractable
than it first looks (the `(L, R)` bound is the hard part; the statistical
engines themselves can mostly be delegated to existing R packages rather
than hand-rolled), and the count case would inherit that same schema-change
cost on top of every Tier 1-3 difficulty above. Deferred to TODO-14 as a
follow-up feasibility report rather than tackled inline here — not because
there's no demand (there is real, recent, published demand; see the final
section of this document), but because it depends on the same `(L, U)`
`Design` schema change `interval_censored_survival_response.md` proposes,
which should land once rather than be designed twice across two documents.

## TODOs

### Prerequisite (blocks everything else)

- [ ] TODO-1: Relax `design_abstract.R:180` and `design_abstract.R:216` to
  allow `dead == 0` when `response_type %in% c("survival", "count")`,
  update the `add_one_subject_response`/`add_all_subject_responses` roxygen
  to document the count semantics ("true count is >= y"), and add a
  regression test asserting uncensored `count` designs still reject nothing
  new and behave identically to today.
- [ ] TODO-2: Audit every place that resamples or copies `y`/`dead` together
  for `count` designs (bootstrap workers, permutation/randomization-inference
  paths, `overwrite_all_subject_assignments`-adjacent helpers) to confirm
  `dead` survives resampling in lockstep with `y` — this is already true for
  `survival`, so this is a verification pass, not new code.

### Tier 1 — Poisson / NegBin MLE

- [ ] TODO-3: Add a `dead`-aware log-likelihood/score/Hessian branch to the
  Poisson kernel (`R/EDI/src/fast_poisson_regression.cpp`), following the
  `WeibullAFTLikelihood` pattern (`R/EDI/src/fast_weibull_regression.cpp:17-90`)
  — censored rows contribute `log(1 - ppois(y - 1, lambda))` instead of the
  log-pmf term.
- [ ] TODO-4: Same for the NegBin kernel
  (`R/EDI/src/fast_negbin_regression.cpp`), with `pnbinom` as the survivor
  function and the extra `theta` derivative term.
- [ ] TODO-5: Remove `assertNoCensoring` from `InferenceCountPoisson`
  (`inference_count_poisson.R:40`) and `InferenceCountNegBin`
  (`inference_count_negbin.R:38`); thread `private$dead` through to the new
  kernel arguments the way `inference_survival_weibull.R` threads it today
  (e.g. lines 107, 184, 236).
- [ ] TODO-6: Add censored-data unit tests mirroring the existing survival
  censoring tests, covering: point-estimate recovery under simulated
  right-censoring, correct behavior when `any_censoring() == FALSE`
  (bit-identical to pre-change output), and a benchmark confirming no
  measurable slowdown on uncensored data (validates the zero-regression
  claim, doesn't just assert it).

### Tier 2 — Robust / Quasi-Poisson

- [ ] TODO-7: Update `InferenceCountRobustPoisson`'s sandwich "meat"
  (`inference_count_robust_poisson.R`, `fit_count_model_with_var`) to use
  the censored-likelihood score contribution instead of the raw
  `y - mu_hat` residual once Tier 1 lands.
- [ ] TODO-8: Decide and document the dispersion-estimation policy for
  `InferenceCountQuasiPoisson` under censoring (deviance-residual
  substitution vs. excluding censored rows from the dispersion sum only),
  then implement it.
- [ ] TODO-9: Remove `assertNoCensoring` from both classes
  (`inference_count_robust_poisson.R:37`,
  `inference_count_quasipoisson.R:37`) once TODO-7/TODO-8 land.

### Tier 3 — Explicitly deferred, second-wave

- [ ] TODO-10: Commission a follow-up feasibility report for censored
  zero-augmented/hurdle counts (mirrors the depth of
  `package_metadata/semi_continuous_response_type_report.md`), covering the
  mixed structural-zero/survivor likelihood construction across all 6
  variants and both backends (internal Rcpp and `glmmTMB`).
- [ ] TODO-11: Commission a follow-up feasibility report for censored KK-GEE
  counts, surveying IPCW-GEE / Lin-Ying-style corrections for censored count
  outcomes as the candidate approach.
- [ ] TODO-12: Commission a follow-up feasibility report for censored
  KK-GLMM counts, scoping what changes `fast_poisson_glmm_cpp`'s
  Gauss-Hermite/Laplace integration would need to fold in a censored
  integrand.
- [ ] TODO-13: No dedicated action for `InferenceCountKKCondPoissonOneLik`
  beyond TODO-10-12 — its feasibility inherits from whichever underlying
  model those reports land on.
- [ ] TODO-14: Commission a follow-up feasibility report for
  interval-censored (grouped/binned) counts, building on Fu, Zhou & Guo
  (2021, *JRSS Series A* 184(4):1347) and their `GRCRegression` R package
  rather than starting from scratch — see the final section of this
  document for why this family was upgraded from "no follow-up warranted"
  to a real candidate. Scope how much of `GRCRegression`'s modified-Poisson/
  ZIP estimator can be delegated to directly (mirroring
  `interval_censored_survival_response.md`'s `icenReg`/`interval`
  delegation pattern) versus how much needs a native implementation to fit
  this package's `Inference*` contract and the `Design`-layer `(L, U)`
  schema that document proposes.

## Appendix: How Common Is Interval/Left-Censoring In Practice?

This section exists to justify why the plan above targets right-censoring
only, and why Tier 3 / interval-censoring are explicitly deferred rather
than built now.

For interval-censored **survival** data specifically — how common it is,
its literature, and a full implementation plan with TODOs — see the
dedicated companion document
`package_metadata/finished_features/interval_censored_survival_response.md`.
(That material used to live in this appendix as a subsection; it moved out
once it grew into its own implementation plan rather than a background note.)
The rest of this appendix covers censored/truncated **count** data, which is
the family actually in scope for this document.

### Censored/truncated count data

Censored count regression is a real, named methodology with decades of
literature, but it shows up in a narrower, more specialized set of applied
niches than interval-censored survival does — it hasn't become a default
tool the way Cox regression has.

- The canonical model is Terza's Tobit-type censored Poisson regression,
  extended by Caudill & Mixon (1995) to variable censoring thresholds:
  [A Tobit-type estimator for the censored Poisson regression
  model](https://www.sciencedirect.com/science/article/abs/pii/0165176585900539)
- Censored/hurdle negative-binomial regression models exist for
  over-dispersed censored counts, including with excess zeros:
  [Hurdle Negative Binomial Regression Model with Right Censored Count
  Data](https://www.raco.cat/index.php/SORT/article/download/260681/347866),
  [A Poisson Regression Model For Analysis of Censored Count Data with
  Excess Zeroes](https://researchgate.net/publication/270706826_A_Poisson_Regression_Model_For_Analysis_of_Censored_Count_Data_with_Excess_Zeroes)
- A generalized-Poisson censored model exists for arbitrary
  under-/over-dispersion:
  [Censored generalized Poisson regression
  model](https://www.sciencedirect.com/science/article/abs/pii/S0167947303002093)
- The most-cited applied use case in this literature is household fertility
  (number of children, often top-coded):
  [Modeling household fertility decisions: censored regression models for
  count data](https://link.springer.com/article/10.1007/BF01205434)
- Outside econometrics, censored/truncated counts show up under
  "detection-limit" framing in environmental and epidemiological count
  monitoring (e.g. contaminant event counts capped by an instrument's
  detection limit), and as time-series-of-counts censoring in actuarial and
  hydrology contexts — described as a real but comparatively
  under-researched area even within its own literature:
  [Time Series of Counts under Censoring: A Bayesian
  Approach](https://pmc.ncbi.nlm.nih.gov/articles/PMC10138058/)
- Top-coding (a right-censoring mechanism) is a named, recognized practice
  for survey count/income data released to preserve respondent anonymity:
  [Top-coded — Wikipedia](https://en.wikipedia.org/wiki/Top-coded)

**Verdict**: censored count models are an established but comparatively
niche methodology, concentrated in a handful of applied areas (fertility
economics, top-coded survey counts, detection-limited environmental/
epidemiological counts, actuarial claim-count censoring) rather than being
a broadly-reached-for tool the way censored survival regression is. That
asymmetry is part of why this plan prioritizes right-censored Poisson/NegBin
(Tier 1) — the smallest change that covers the models with actual applied
precedent — over chasing interval-censoring or the harder Tier 3 families
first.

## Interval-Censored Count Response: How Common Is It?

Distinct from both right-censored counts (covered above) and
interval-censored survival (covered in
`interval_censored_survival_response.md`), this section asks specifically:
how often is a **count** — not a time-to-event, not a continuous
measurement — known only to lie in `[L, U]` rather than at an exact value?

**Correction after further research**: an earlier draft of this section
claimed no dedicated interval-censored count regression literature exists.
That was wrong. There is real, recent, peer-reviewed precedent, and it's
more mainstream than this document originally gave it credit for:

- **Fu, Zhou & Guo (2021), "Modified Poisson Regression Analysis of
  Grouped and Right-Censored Counts,"** *Journal of the Royal Statistical
  Society Series A*, 184(4):1347, with an accompanying CRAN package,
  `GRCRegression`. This is exactly the binned-survey-count case described
  below: counts collected in bins like "3-4 times" or "5 or more times" on
  sensitive survey topics. The paper directly compares their modified
  Poisson (and zero-inflated Poisson) estimators against the ordinal-
  regression shortcut and finds the ordinal approach **biased**, with 95%
  confidence intervals that fail to contain the true parameter even at
  large sample sizes — i.e. the applied literature doesn't just tolerate
  ordinal-as-a-substitute, a recent methods paper shows it's the wrong
  answer. Their motivating application is the Monitoring the Future
  survey's adolescent lifetime marijuana-use frequency data, with
  criminology, demography, epidemiology, and psychology named as target
  fields. The paper extends to zero-inflated Poisson and explicitly flags
  negative binomial, hurdle, and zero-inflated negative binomial as natural
  future extensions.
- **Stata's `cpoisson` command** natively supports interval-censoring
  (simultaneous lower and upper bounds) for Poisson regression — described
  in Stata's own documentation as "Left- and right-censoring combined is
  also known as interval-censoring." This is a real capability shipped in
  mainstream commercial statistical software, not a single niche paper.
- A Bayesian treatment of interval-censored Poisson counts with zero
  inflation *and* missing censoring-limit information exists too,
  motivated by an HIV vaccine trial with imprecise, left-censored, and
  zero-heavy count data (a Baylor University dissertation/technical
  report), showing the methodology has been pushed into the harder
  missing-data-plus-zero-inflation corner as well, not just the clean case.

**Binned/grouped survey counts** are therefore the real, named,
software-supported case: counts collected in bins ("0", "1-5", "6-10",
"11+") for respondent-burden or anonymity reasons. There *is* a real
latent count `Y` (e.g. number of doctor visits), and the likelihood
contribution for a bin `[L, U]` is
`P(L <= Y <= U | lambda) = F(U) - F(L-1)` — the same `S(L) - S(R)`
survivor-difference structure this document's survival companion uses for
interval-censored time-to-event data, just with a Poisson/NegBin CDF
standing in for a survivor function. Fu, Zhou & Guo's `GRCRegression`
package already implements a working estimator for exactly this
likelihood, which reframes this from "no clear approach exists" to "a
concrete, published R package to delegate to or adapt" — the same
delegate-rather-than-hand-roll pattern this document's Tier-2 sections and
`interval_censored_survival_response.md`'s Cox/KM delegation to
`icenReg`/`interval` already use.

**Anonymized/suppressed registry counts** are a related but distinct
shape — health-register and administrative data deliberately coarsened
into bins to preserve anonymity, described in the survival literature as
"binning of event and censoring times" and analyzed there via multiple
imputation:
[Simple parametric survival analysis with anonymized register data: a
cohort study with truncated and interval censored event and censoring
times](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3748025/). This
still doesn't have its own dedicated named methodology the way binned
survey counts now clearly do via Fu, Zhou & Guo (2021) — but it's plausibly
the same underlying likelihood construction with a different motivation.

**Revised verdict**: interval-censored count response is real, published,
and even commercially software-supported (Stata `cpoisson`), and current
best practice (per a 2021 JRSS-A paper) actively argues *against* the
ordinal-regression shortcut this document previously assumed was the
reasonable default. That changes the calculus from "there's no applied
pull for this" to "there's real applied pull and a concrete R package
(`GRCRegression`) to build from" — this family should not be dismissed the
way the earlier draft of this section did. It's plausibly closer in
tractability to interval-censored survival's delegate-to-an-existing-
package story than to the Tier 3 structural-blocker families elsewhere in
this document, though — like interval-censored survival — it still needs
the same `Design`-layer `(L, U)` schema extension
`interval_censored_survival_response.md` proposes before any of this can
be wired up. Given that, this family is upgraded from "no follow-up
warranted" to a genuine candidate for a dedicated future feasibility
report; see TODO-14 below.
