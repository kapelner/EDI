# Censoring Support for the `ordinal` Response Type

> **Depends on:** `../finished_features/interval_censored_survival_response.md`
> (the shipped `y`/`y_L`/`y_R` bounds schema this plan reuses);
> `censored_continuous_response.md` and `censored_count_response.md`
> (v1.4.0's censoring track, which turns the `Design` censoring gate into an
> allow-list first); `multistart_nonconcave_likelihoods.md` (Tier 2's
> non-concave partial-sum likelihoods);
> `sexp_removal_rcppeigen_conversion_spec.md` conventions for kernel
> changes. (Global ordering: see `_master.md`.)
> **Release target: v2.0.0** (user decision, 2026-10-03) →
> `../future_release_plans/release_v2_0_0.md → TODO-6m`.

Written 2026-10-03. All `file:line` references were checked against the
working tree on that date.

## Scope

Every `ordinal`-response `Inference*` class currently refuses censored data,
and `Design` refuses to store it. This document plans how to let
`response_type = "ordinal"` carry observations whose level is known only up
to a **contiguous range of levels**:

- **right-censored** — "at least `moderate`" (subject lost while at a given
  severity on a worst-state scale; top-coded scale; "grade >= 3" reporting);
- **left-censored** — "at most `mild`";
- **interval-censored** — "`mild` or `moderate`" (a site or instrument that
  records a coarser version of the scale).

Unlike the continuous and count sibling plans, which scope right-censoring
only and defer the interval case, this plan scopes all three shapes at once:
for the cumulative-link models the general case costs the same as the
right-censored case (see "Why Ordinal Is The Cheap Case").

Out of scope: informative censoring, truncation, fully missing outcomes,
not-yet-ascertained outcomes at an interim look, and longitudinal ordinal
states — see "Out Of Scope".

## Current State

`Design` stores a response as the triple `y` / `y_L` / `y_R` (exact value,
or `NA` plus two bounds), but only `survival` may use the bounds:

- `R/EDI/R/design_abstract.R:292` (`add_one_subject_response`) and `:391`
  (`add_all_subject_responses`) stop with `"censored observations are only
  available for survival response types"`.
- The bounds are validated as survival times: `y_L` finite and `>= 0`,
  `y_R > y_L` strictly (`:317-322`, `:394-399`), and typed numeric-only
  (`:265-266`). The ordered-factor → integer-code conversion exists for `y`
  alone.
- `any_censoring()` (`:481`) is `any(is.na(private$y))`;
  `has_general_censoring()` (`:494`) is `any(is.finite(private$y_R))` — both
  already response-type-agnostic.
- `R/EDI/R/inference_all_abstract.R:78-88` reads both flags and rejects
  general (left/interval) censoring centrally unless the class overrides
  `supports_interval_or_left_censored_data()` (default `FALSE`, `:440`). The
  error text says "survival data".
- `inference_all_abstract.R:92` sets `private$y` to
  `des_obj$get_effective_time()` for right-censored-only designs — i.e.
  `y_L` on censored rows. **Any ordinal class that dropped its guard without
  reading the bounds would silently treat "at least j" as "exactly j".**

Every likelihood-based ordinal class guards itself with
`assertNoCensoring(private$any_censoring)`
(`R/EDI/R/helper_response_asserts.R:9`):
`inference_ordinal_proportional_odds.R:24`, `_ordered_probit.R:21`,
`_cauchit.R:23`, `_cloglog.R:23`, `_adj_cat_logit.R:25`,
`_stereotype_logit.R:18,586` (the file that defines both
`InferenceOrdinalStereotypeLogitRegr` and `InferenceOrdinalContRatioRegr`),
`_partial_proportional_odds.R:62`, `_gcomp.R:54`, `_ridit.R:80`,
`_jonckheere_terpstra_test.R:63`, `_KK_clmm_abstract.R:47`, and — for
`InferenceOrdinalKKGLMM` / `InferenceOrdinalKKGEE` — the shared components
at `inference_mixin_kk_glmm_shared.R:127` and
`inference_mixin_kk_gee_shared.R:281`. The two response-agnostic Wilcoxon
classes that admit ordinal (`InferenceAllSimpleWilcox`,
`InferenceAllKKWilcoxIVWC`) refuse any censoring through
`design_compatibility_reason()` (`inference_all_simple_wilcox.R:224`,
`inference_all_KK_wilcox_ivwc.R:215`).

**No guard was found by grep in `inference_ordinal_paired_sign_test.R`,
`inference_ordinal_KK_cond_adj_cat_logit.R`, or
`inference_ordinal_KK_cond_logit_abstract.R`.** Unless a component they
compose guards it, `InferenceOrdinalPairedSignTest` and
`InferenceOrdinalKKCondAdjCatLogitRegr` are protected today only by the
`Design` gate. TODO-3 closes this before TODO-2 opens the gate.

Kernel state:

- The four fixed-link cumulative kernels share one core,
  `edi_ordinal::FixedOrdinalRegression`
  (`R/EDI/src/ordinal_fixed_link_helpers.h:170`), wrapped by
  `fast_ordinal_regression.cpp:36-63` (logit) and
  `fast_ordinal_{probit,cauchit,cloglog}_regression.cpp:27-31`.
- Its per-row likelihood is already an interval probability,
  `cdf(alpha[k]) - cdf(alpha[k-1])` (`:253-260`), with derivatives
  accumulated per endpoint by `add_endpoint_derivatives()` /
  `add_endpoint_gradient()` (`:199-223`).
- The level set is **inferred from the observed data**: `init_levels(y)`
  (`:26-31`) in the constructor (`:231`), with `m_K = m_levels.size()`.
- `fast_ordinal_clmm.cpp:51-52,63-70` has the same `F_up - F_lo` row
  structure inside its quadrature, and takes `K` explicitly.
- Continuation-ratio fits a binary logit on a person-level expansion
  (`build_continuation_ratio_augmented_data`,
  `fast_continuation_ratio_regression.cpp:74-135`): one row per cut the
  subject reached, `z = 1` meaning "continued past this cut".
- The same sources build the `edi_kernels` Python package under
  `EDI_CORE_ONLY` (`python/src/edi_kernels/_core.pyi` exposes
  `fast_ordinal_*`, `fast_continuation_ratio_regression`,
  `fast_adjacent_category_logit`, `fast_ordinal_clmm`, `fast_ordinal_glmm`).

`SimulationFramework` generates censoring for survival only
(`prob_censoring`, `R/EDI/R/simulations_framework.R:469`; bounds mapping at
`:200-209`).

## Proposed Semantics

Reuse the triple, with bounds on the **level codes** `1..K`:

| Shape | Meaning | Stored as |
|---|---|---|
| exact | level is `j` | `y = j` |
| right-censored | level `>= a` | `y = NA, y_L = a, y_R = Inf` |
| left-censored | level `<= b` | `y = NA, y_L = 1, y_R = b` |
| interval-censored | level in `{a, ..., b}` | `y = NA, y_L = a, y_R = b` |

```r
# des: any Design with response_type = "ordinal" and declared
# ordinal_levels = c("none", "mild", "moderate", "severe")
des$add_one_subject_response(1, y = 2)               # exactly mild
des$add_one_subject_response(2, y_L = 3, y_R = Inf)  # at least moderate
des$add_one_subject_response(3, y_L = 1, y_R = 2)    # at most mild
des$add_one_subject_response(4, y_L = 2, y_R = 3)    # mild or moderate
```

- **Closed interval, both ends inclusive.** This differs from survival's
  half-open `(y_L, y_R]` and must be documented loudly. It matches
  `rms::Ocens`, whose `[a, b]` is "inclusive of a and b" with `-Inf`/`Inf`
  for left/right censoring (see Appendix). Decision in TODO-1.
- **`y_R = Inf` for right-censoring** keeps `has_general_censoring()`
  `FALSE` for right-only designs, exactly as for survival, so the existing
  two-level capability split (right-only vs general) carries over unchanged.
- **Canonical form at entry.** `y_L == y_R` is rejected (supply `y`). A
  finite `y_R == K` is normalized to `Inf`. `[1, Inf]` is rejected (no
  information; that is a missing outcome). `[K, Inf]` is rejected (it is
  exact `K`).
- **The level set must be declared.** Whenever any bound is supplied,
  `ordinal_levels` (hence `K`) must be known to the `Design`, because a bound
  may name a level never observed exactly. Bounds accept ordered factors as
  well as integer codes, as `y` does today.

For a cumulative-link model with thresholds `alpha_0 = -Inf < alpha_1 < ...
< alpha_{K-1} < alpha_K = +Inf`, the row contribution is

```
P(a <= Y <= b | x) = F(alpha_b - eta) - F(alpha_{a-1} - eta)
```

and the exact case is `a = b`.

**Assumption.** Coarsening at random (Heitjan & Rubin 1991): which range is
reported may depend on arm and observed covariates but not on the true level
within the reported range. For randomization inference the assumption is the
one survival already uses: under the sharp null the subject's reported triple
is invariant to assignment, so re-randomization permutes `w` and holds
`(y, y_L, y_R)` fixed.

## Why Ordinal Is The Cheap Case

The count plan needs a new survivor term in each kernel; the continuous plan
needs a separate Tobit kernel because OLS is closed-form. The fixed-link
ordinal kernel needs neither. An exact row already touches two thresholds,
`alpha[k]` and `alpha[k-1]`; a censored row touches `alpha[hi]` and
`alpha[lo-1]`. The CDF, PDF, and endpoint-derivative helpers are unchanged —
only the pair of threshold indices per row changes. One core change therefore
covers four links times three entry points (plain, weighted, with-variance)
and every class built on them.

With the cloglog link and right-censoring this is the grouped
proportional-hazards model of Prentice & Gloeckler (1978); with the logit
link it is Bennett's (1983) proportional-odds survival model. Neither is a
new estimator.

## Zero-Regression Design Principle

1. **Design layer.** The gate becomes a member of the allow-list v1.4.0's
   censoring track introduces; ordinal bound validation is a separate branch
   from survival's. Setters run once per subject.
2. **Kernel layer.** New optional per-row endpoint indices. When absent, the
   constructor sets `lo = hi = level_index(y)` and the arithmetic is the
   current sum, bit-for-bit. Precomputing the indices once also removes the
   per-evaluation `level_index()` scan — coordinate with
   `small_kernel_hoists_batch.md`'s cached ordinal level lookups.
3. **R inference layer.** `assertNoCensoring` is removed only from classes
   whose tier ships; every other class keeps refusing.

## Ordinal-Specific Hazards Beyond The Likelihood

These are the parts that are not a one-line generalization.

- **Level discovery.** `init_levels(y)` cannot see a level that appears only
  inside a censored range. `K` and the level map must be passed in.
- **Threshold identifiability.** Cut `k` enters the likelihood only through
  rows with an endpoint at `k`. With no such row, `alpha_k` is a flat
  direction; and a level that appears only inside censored ranges can drive
  two thresholds together, which `validate_params()`
  (`ordinal_fixed_link_helpers.h:190-197`) rejects with a penalty wall the
  optimizer stalls against. Proposed rule: fit on the Turnbull innermost
  sets of the reported ranges, estimating thresholds only between adjacent
  sets; `beta` does not depend on which level inside a set carries the mass.
  Today the analogous event (a level never observed) is handled implicitly
  by `init_levels()` dropping it. `rms::orm` handles a related case by
  creating new outer categories (e.g. `10+`).
- **Expected information.** `expected_hessian()`
  (`ordinal_fixed_link_helpers.h:392`) assumes complete data. Under
  censoring the expected information depends on the coarsening mechanism, so
  censored fits must use the observed Hessian wherever a variance or a
  scoring step uses the expected one.
- **Cold starts.** `ordinal_smart_cold_start_or_legacy()`
  (`_helper_functions_core.h:1023`) starts from the observed `y`.
- **Parametric bootstrap.** `simulate_param_boot_ordinal_y()`
  (`inference_all_abstract_param_boot.R:718`; callers in the four
  fixed-link classes) simulates exact levels. Re-coarsening them needs a
  model of the coarsening mechanism, which this plan does not have.
- **Nonparametric bootstrap.** Resampling must carry `(y, y_L, y_R)` in
  lockstep. True for survival; unverified for the ordinal paths.
- **Randomization CIs.** Currently disabled for ordinal coefficients
  (`ordinal_model_coefficient_randomization_confidence_intervals.md`);
  whenever that plan lands it must define the shifted null for censored
  rows.

## Feasibility By Inference Type

Nineteen concrete ordinal classes, plus two response-agnostic Wilcoxon
classes that admit ordinal.

### Tier 1 — the shared fixed-link core (first wave)

- **`InferenceOrdinalPropOddsRegr`, `InferenceOrdinalOrderedProbitRegr`,
  `InferenceOrdinalCauchitRegr`, `InferenceOrdinalCloglogRegr`** — all three
  censoring shapes, through `FixedOrdinalRegression`.
- **`InferenceOrdinalContRatioRegr`, right-censoring only.** A subject known
  to be at level `>= a` contributes a "continued" row for every cut below
  `a` and no terminal row — a truncated expansion, which is
  discrete-time-hazard censoring (Berridge & Whitehead 1991). No likelihood
  change; only `build_continuation_ratio_augmented_data` changes.

### Tier 2 — rides on Tier 1, or needs one modest derivation

- **`InferenceOrdinalGCompMeanDiff`** — `ordinal_gcomp_post_fit_cpp`
  (`fast_ordinal_regression.cpp:527-678`) needs only the fitted parameters
  and `X`; it works once the fit and its Hessian are censoring-aware.
- **`InferenceOrdinalPartialProportionalOddsRegr`** — the parallel-only path
  uses the Tier 1 kernel. The non-parallel path falls back to
  `VGAM::vglm` / `ordinal::clm` / `MASS::polr`, which this plan does not
  assume accept censored responses; under censoring that path reports
  nonestimable until a native non-parallel kernel exists.
- **`InferenceOrdinalAdjCatLogitRegr`, `InferenceOrdinalStereotypeLogitRegr`**
  — category-probability models; the censored contribution is
  `log(sum_{k=a..b} pi_k(x))`. New likelihood, score, and Hessian branch.
  The partial sum removes the adjacent-category model's concavity, and the
  stereotype likelihood is already multimodal — pair with
  `multistart_nonconcave_likelihoods.md`.
- **`InferenceOrdinalContRatioRegr`, left/interval** — with continuation
  probabilities `c_j = P(Y > j | Y >= j)`,
  `P(a <= Y <= b) = prod_{j<a} c_j * (1 - prod_{j=a..b} c_j)`. Not a binary
  row; needs a custom objective instead of the augmented-data logit.
- **`InferenceOrdinalRidit`, `InferenceOrdinalJonckheereTerpstraTest`** —
  score a censored row by its expected score under the pooled NPMLE of the
  level distribution (Turnbull self-consistency on `K` support points). This
  is the interval-censored Wilcoxon construction of Fay & Shaw (2010),
  generalizing Gehan (1965). `helper_inference_survival_turnbull.R` is the
  starting point. Pooled-reference scores are fixed under permutation; the
  default control-referenced ridit would need the NPMLE per replicate.
  Derivation first (TODO-16).
- **`InferenceOrdinalPairedSignTest`** — a pair's sign is determined when
  the two reported ranges do not overlap, and indeterminate otherwise.
  Dropping indeterminate pairs as ties keeps the test valid under the sharp
  null, since indeterminacy is invariant to swapping the pair's labels.
  Changes `inference_ordinal_paired_sign_test.R:166`.
- **`InferenceOrdinalKKCLMM` and its `Probit` / `Cauchit` / `Cloglog`
  siblings, `InferenceOrdinalKKGLMM`** — the CLMM integrand is already
  `F_up - F_lo`, so the Tier 1 endpoint generalization applies inside the
  quadrature. Easier than the count plan's GLMM, where the survivor term is
  a new integrand. `fast_ordinal_glmm.cpp` was not inspected; confirm it has
  the same shape (TODO-18).
- **`InferenceAllSimpleWilcox`, `InferenceAllKKWilcoxIVWC` on ordinal** —
  keep refusing until TODO-16's derivation exists. Their existing censoring
  branch assumes survival's half-open convention.

### Tier 3 — keeps refusing

- **`InferenceOrdinalKKGEE`** — delegates to `multgee::ordLORgee`; no
  censored-response path.
- **`InferenceOrdinalKKCondAdjCatLogitRegr`** — conditional logit on an
  expansion stratified by pair; the conditioning statistic is unobserved
  when a pair member is censored.

## Out Of Scope

- **Informative coarsening** (sensitivity analysis, pattern-mixture models).
- **Truncation.**
- **Fully missing outcomes** — `missing_outcome_handling.md`.
- **Outcomes not yet ascertained at an interim analysis** — a different
  problem with its own estimator (see Appendix); belongs to
  `sequential_inference.md`.
- **Longitudinal ordinal states with absorbing categories** — the
  longitudinal response type.
- **Continuous outcomes analyzed as ordinal with detection limits** (Tian et
  al. 2024) — a semiparametric alternative for
  `censored_continuous_response.md`. The dense `(K-1+p)^2` Hessian here does
  not scale to `K` in the hundreds.
- **Binned counts as ordinal** — `censored_count_response.md` records Fu,
  Zhou & Guo (2021) finding that shortcut biased. Different problem; no
  conflict with this plan.

## Coordination Within v2.0.0

- **Multivariate Stage 0** (`release_v2_0_0.md → TODO-4`) moves `Design`
  response storage to named responses. The ordinal bounds must ride on
  whatever per-response storage that produces; land TODO-2 after Stage 0 or
  in the same sweep.
- **Sibling plans are stale on the schema.** `censored_continuous_response.md`
  and `censored_count_response.md` still describe the pre-2026-08-16 `dead`
  flag and cite `design_abstract.R:180`/`:216`. `release_v1_4_0.md:65`
  already describes the continuous plan as generalizing the `y_L`/`y_R`
  schema; this plan assumes that reading.

## TODOs

### Decision (blocks everything else)

- [ ] TODO-1: **Decision batch** (joins `release_v2_0_0.md → TODO-1`).
  (a) Go/no-go. (b) Bounds convention — recommended: closed interval on
  level codes, matching `rms::Ocens`. (c) Canonical-form rules as listed
  under "Proposed Semantics". (d) Native kernels vs runtime delegation to
  `rms::orm` / `tram::Polr` — recommended: native, with those packages as
  test oracles only. (e) First-wave membership — recommended: Tier 1 plus
  TODO-12 and TODO-17. (f) Parametric bootstrap under censoring —
  recommended: refuse.

### Design and inference root

- [ ] TODO-2: Add `"ordinal"` to the censoring allow-list at
  `design_abstract.R:292`/`:391`; add the ordinal bound-validation branch
  (integer codes in `1..K` or labels/ordered factors, canonical form,
  declared levels required). Always enforced, never behind
  `should_run_asserts()` — same reasoning as the survival comment at
  `:270-278`. Update roxygen for both setters.
- [ ] TODO-3: **Before TODO-2 merges**, add an explicit censoring refusal to
  every ordinal class that lacks one (`InferenceOrdinalPairedSignTest`,
  `InferenceOrdinalKKCondAdjCatLogitRegr`, after confirming their composed
  components do not already guard), and make the root message at
  `inference_all_abstract.R:80-88` response-type-neutral.
- [ ] TODO-4: Resampling audit for ordinal: nonparametric bootstrap carries
  the triple in lockstep; randomization holds it fixed; parametric bootstrap
  and randomization CIs refuse under `any_censoring` per TODO-1(f).

### Tier 1

- [ ] TODO-5: `FixedOrdinalRegression`: accept explicit `K` and per-row
  `(lo, hi)` level indices; generalize `neg_log_likelihood`, the gradient,
  and `hessian`; use the observed Hessian under censoring and audit every
  `expected_hessian()` caller.
- [ ] TODO-6: Threshold identifiability: derive and implement the
  innermost-set rule; report which levels were merged; return nonestimable
  rather than a penalty-wall stall. Check the rule against `rms::orm`.
- [ ] TODO-7: Censoring-aware cold start (pooled NPMLE of the level
  distribution, or exact rows only when enough exist).
- [ ] TODO-8: Thread the new arguments through the four wrappers' plain,
  weighted, and with-variance entry points and the score/Hessian getters;
  keep the `EDI_CORE_ONLY` build and `scripts/check_core_no_rcpp.sh`
  passing; update the Python bindings and `_core.pyi`.
- [ ] TODO-9: R classes: remove `assertNoCensoring` from the four
  fixed-link classes, override `supports_interval_or_left_censored_data()`,
  read bounds from `des_obj` rather than `private$y`.
- [ ] TODO-10: Continuation-ratio right-censoring by truncated expansion;
  the class accepts right-censoring only.
- [ ] TODO-11: Tests. Oracle parity against `rms::orm(Ocens(a, b) ~ ...)`
  for each link `orm` offers, and against `tram::Polr` (both
  `skip_if_not_installed`; `rms` 8.1.1 is installed locally, `tram`/`mlt`
  are not). Bit-identical output
  when no row is censored. Simulated size and coverage under coarsening at
  random. Identifiability edge cases from TODO-6. A benchmark showing no
  slowdown on uncensored data.

### Tier 2

- [ ] TODO-12: `InferenceOrdinalGCompMeanDiff` on the censored fit.
- [ ] TODO-13: `InferenceOrdinalPartialProportionalOddsRegr`: parallel path
  on the Tier 1 kernel; non-parallel path nonestimable under censoring.
- [ ] TODO-14: Partial-sum likelihood for adjacent-category and stereotype
  kernels, with multistart.
- [ ] TODO-15: Continuation-ratio left/interval custom objective.
- [ ] TODO-16: Rank-based classes: write the derivation (estimand, pooled
  vs control-referenced scores, permutation validity), then implement for
  ridit and Jonckheere–Terpstra; decide whether the two Wilcoxon classes
  follow.
- [ ] TODO-17: Paired sign test on determinate pairs.
- [ ] TODO-18: Endpoint generalization inside `fast_ordinal_clmm_cpp` and
  `fast_ordinal_glmm_cpp`; confirm the KK pair-building code does not read
  `y` values directly.

### Tier 3

- [ ] TODO-19: `InferenceOrdinalKKGEE` and
  `InferenceOrdinalKKCondAdjCatLogitRegr` keep refusing. Record a one-page
  feasibility note for each only if a user asks.

### Cross-cutting

- [ ] TODO-20: `SimulationFramework`: an ordinal coarsening generator
  (right, left, interval, and site-collapse mechanisms), coarsened at random
  by construction, plus one informative mechanism for the documentation's
  cautionary example.
- [ ] TODO-21: Registry and `InferenceSuite` discovery metadata
  (`inference_class_registry.R:770-784`), `public_api_inventory.csv`, the
  pre-push structural allowlists, and comprehensive-test registry rows.
- [ ] TODO-22: Documentation: a censored-data section in
  `cookbook-ordinal.Rmd`, the closed-interval convention and the
  coarsening-at-random assumption in the notation glossary, Rd for the
  changed setters and classes.

## Appendix: Literature And Software

Verified by web search on 2026-10-03:

- Prentice & Gloeckler (1978), "Regression analysis of grouped survival data
  with application to breast cancer data," *Biometrics* 34(1):57–67,
  doi:10.2307/2529588 — grouped proportional hazards with censoring; the
  cloglog cumulative-link model.
- Berridge & Whitehead (1991), "Analysis of failure time data with ordinal
  categories of response," *Statistics in Medicine* 10(11):1703–1710 —
  continuation-ratio model:
  [Wiley](https://onlinelibrary.wiley.com/doi/10.1002/sim.4780101108)
- `rms::Ocens` and `rms::orm` (Harrell) — left-, right-, and
  interval-censored ordinal responses, closed `[a, b]` convention; also used
  by `rmsb::blrm`:
  [Ocens](https://rdrr.io/cran/rms/man/Ocens.html),
  [rms](https://hbiostat.org/r/rms/)
- `tram::Polr` on `mlt` (Hothorn) — ordered categorical responses "allowing
  for stratification, censoring and truncation":
  [tram](https://cran.r-project.org/web/packages/tram/tram.pdf)
- Tian, Li, Tu, James, Harrell & Shepherd (2024), "Addressing Multiple
  Detection Limits with Semiparametric Cumulative Probability Models,"
  *JASA* 119(546):864–874, with the `multipleDL` package:
  [arXiv](https://arxiv.org/pdf/2207.02815)
- "Estimation of the odds ratio in a proportional odds model with censored
  time-lagged outcome in a randomized clinical trial" — the interim-look
  problem listed under "Out Of Scope":
  [arXiv](https://arxiv.org/pdf/2106.15559)

Cited from memory, not re-verified — check before any of these reach
user-facing documentation:

- McCullagh (1980), "Regression Models for Ordinal Data," *JRSS-B*
  42(2):109–142 (already cited in this package's roxygen).
- Bennett (1983), "Analysis of survival data by the proportional odds
  model," *Statistics in Medicine* 2(2):273–277.
- Heitjan & Rubin (1991), "Ignorability and coarse data," *Annals of
  Statistics* 19(4):2244–2253.
- Gehan (1965), "A generalized Wilcoxon test for comparing arbitrarily
  singly-censored samples," *Biometrika* 52:203–223.
- Fay & Shaw (2010), "Exact and asymptotic weighted logrank tests for
  interval censored data: the interval R package," *Journal of Statistical
  Software* 36(2).

**How common is it?** No prevalence survey was found, so this plan has
weaker demand evidence than the count plan's appendix. The case for it rests
on mainstream software support (`rms`, `tram`) and on four recognizable
situations: loss to follow-up on a worst-state severity scale; sites or
instruments recording coarser versions of one scale; top- or bottom-coded
scales and "grade >= 3" reporting; and composite endpoints where a survivor's
exact non-death state is unknown. That list is this plan's own enumeration,
not a finding from the literature.
