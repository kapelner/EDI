# Covariate Coefficient Table (`get_coefficient_table()`) for Likelihood Classes

> **Depends on:** nothing architectural. Touches the shared fit cache
> (`inference_all_abstract_asymp_lik_std_mod_cache.R`,
> `inference_all_abstract_mle_or_KM_summary_table.R`), `InferenceAsymp$get_summary()`
> (`inference_all_abstract_asymp.R`), the class registry, and each
> supporting class's `generate_mod()` output. Additive.
> **Release target: v1.1.0** (`release_v1_1_0.md → TODO-47`).

Written 2026-10-09 (user decision): "add this as a feature only where it's
supported and slate for v1.1.0".

## Why

Every public inference method (`compute_estimate`,
`compute_asymp_confidence_interval`, `compute_asymp_two_sided_pval`, and the
randomization and bootstrap methods) reports on the treatment coefficient
`w` only. Users who fit a covariate-adjusted model reasonably expect a
`coef(summary(glm(...)))`-style table for the adjustment covariates too.
Today they can build one only by hand from `inf$get_mod()`, and only for
some classes. Checked 2026-10-09 on installed EDI 1.0.3 (dataset
`MASS::biopsy`; the treatment arm comes from `DesignFixedBernoulli`):

```r
mod = inf$get_mod()                       # InferenceCountPoisson
b = mod$b; se = sqrt(diag(mod$vcov)); names(b) = names(se) = colnames(mod$X)
cbind(Estimate = b, `Std. Error` = se, `z value` = b/se, `Pr(>|z|)` = 2*pnorm(-abs(b/se)))
```

This matches `glm(y ~ w + V1 + V2 + V3 + V4, poisson)` to four decimal places.

`get_summary()` is supposed to print this kind of table, and it does print
`private$cached_values$summary_table` when that table exists. However, the
`StandardModelCacheSource` `shared()` path
(`inference_all_abstract_asymp_lik_std_mod_cache.R:177`), which nearly every
likelihood class uses, never builds that table. It caches only the scalar
treatment variance (`ssq_b_2` / `ssq_b_j`), so `get_summary()` falls back to
`print(mod)`. That dumps the raw fit list (design matrix, information
matrices and so on). The test file `test-mle-km-summary-table.R` (Part 2
header) records this gap as known.

**Root cause:** the kernels compute only the treatment variance. They usually
avoid a full inverse of the information matrix for speed, so a full `vcov`
exists in the fit object only for some classes.

## Scope rule: "only where it's supported"

A class **supports** the table when all three of these hold:

1. It fits a single regression model with the adjustment covariates as
   terms, so the coefficients have a "coefficient of covariate `x_j`"
   meaning.
2. The full coefficient vector is available after the fit.
3. A full covariance matrix can be formed **with the same estimator the class
   uses for its own treatment SE**. That means model-based for model-based
   classes, the same sandwich for sandwich classes, and the same dispersion
   scaling for quasi classes.

**Invariant (tested):** `get_coefficient_table()["treatment", "Std. Error"]`
equals `sqrt(cached ssq)`, the SE behind the class's own
`compute_asymp_confidence_interval()`. It must match to a tight tolerance,
and to the bit where the treatment SE already comes from the same inverse.

Excluded by construction, with no method on these classes:

- Unadjusted and nonparametric procedures: mean-difference, Wilcoxon, exact,
  CMH, Newcombe, Miettinen–Nurminen, Wald, KM difference, log-rank, RMST,
  Gehan, ridit, Jonckheere–Terpstra, paired sign, Bai.
- G-computation classes. Their existing `summary_table` holds standardized
  effects, and the outcome model is a nuisance model.
- All `*IVWC` classes. They combine two separate estimators, so there is no
  single covariate model, and they are legacy (never surfaced publicly).

## Preliminary inventory (sweep 2026-10-09, installed 1.0.3; TODO-2 re-verifies)

The sweep built a fit for every exported class on `DesignFixedBernoulli`, or on
`DesignFixedBinaryMatch` for KK classes, then inspected `get_mod()` and
`cached_values`. Treat this as **preliminary**. A short `n_coef` sometimes
means the fit object stores only part of the parameter vector, not that the
model has none.

| Tier | Meaning | Classes |
|---|---|---|
| **0** | `summary_table` already built; needs only the accessor, row-name check and invariant test | `ContinLin`, `CountHurdlePoisson`, `CountKKHurdlePoissonOneLik`, `CountZeroInflatedPoisson`, `CountZeroInflatedNegBin`, `IncidKKModifiedPoisson`, `OrdinalKKGEE` |
| **1** | Full β and full `vcov` already in the fit object | `ContinKKGLMM`, `ContinKKOLSOneLik`, `CountKKGLMM`, `CountPoisson`, `CountQuasiPoisson`, `IncidBinomialIdentityRiskDiff`, `IncidKKCondLogitGLMMOneLik`, `IncidLogRegr`, `PropBetaRegr`, `PropKKGLMM`, `PropZeroOneInflatedBetaRegr`, `SurvivalCoxPHRegr`, `SurvivalStratCoxPHRegr`, `SurvivalKKLWACoxPHOneLik`, `SurvivalKKStratCoxPHOneLik`, `SurvivalGLMMWeibullFrailtyNormalOneLik`, `SurvivalKKWeibullMarginal` |
| **2** | β present; the new path must form `vcov` itself, from information, `XtX`/`sigma2_hat`, or the class's own sandwich (recomputed, not added to the fit) | `ContinOLS`, `CountNegBin`, `CountRobustPoisson` (sandwich), `IncidKKCondLogitOneLik`, `IncidModifiedPoisson` (sandwich), `IncidProbitRegr`, `IncidRiskDiff`, `IncidLogBinomial`, `PropFractionalLogit` (sandwich), `SurvivalWeibullRegr`, ordinal cumulative-link family (`PropOdds`, `Cauchit`, `Cloglog`, `OrderedProbit`, `AdjCatLogit`, `ContRatio`, `StereotypeLogit`; fit stores only 2 params, so the new path recomputes the thresholds' rows at the cached fit instead of the fit being widened to return them), `OrdinalKKCLMM*`, `OrdinalKKGLMM` |
| **3** | Fit not cached as a list, or semantics unclear; decide per class at TODO-1 | `ContinRobustRegr`, `ContinQuantileRegr`, `ContinKKRobustRegrOneLik`, `ContinKKQuantileRegrOneLik`, `PropQuantileRegr`, `PropKKQuantileRegrOneLik`, `CountPoissonKKGEE`, `IncidKKGEE`, `PropKKGEE`, `CountKKCondPoissonOneLik`, `CountHurdleNegBin`, `OrdinalKKCondAdjCatLogitRegr`, `OrdinalPartialProportionalOddsRegr`, `SurvivalDepCensTransformRegr`, `SurvivalGLMMWeibullFrailtyLoggammaOneLik` |

Tier 3 is "support if it falls out cleanly, otherwise exclude". It does not
commit to support. For example, quantile-regression covariate SEs need their
own rank-based or bootstrap machinery. The GEE classes are probably cheap
because the sandwich already exists.

## Hard constraint: a separate path, with zero cost to the treatment-variance path

Added 2026-10-09 (user decision). The existing treatment path stays
**byte-for-byte untouched**. That path covers each class's `generate_mod()`,
`shared()`, the C++ kernels it calls, what those return, and what gets
cached. Every extra computation for the covariate table runs in a **new,
separate path** that only `get_coefficient_table()` (and `get_summary()`
through it) can reach. Specifically:

1. **No edits to the existing fit path.** Do not edit `generate_mod()`,
   `shared()`, `get_standard_error()`, `compute_estimate_with_bootstrap_weights()`,
   or any kernel they call to make it return or cache more. That rules out an
   extra `vcov`, extra information matrices, a sandwich meat, ordinal
   thresholds, or names. If the fit already returns something (Tier 0/1), the
   new path may **read** it. If it doesn't, the new path **recomputes** what
   it needs from inputs that already exist:
   - the cached parameter vector (`b` / `params`), which the warm-start cache
     already keeps;
   - the design's `X`, `w` and `y`;
   - the class's existing likelihood or score helpers, called as functions,
     not by changing their callers.
2. **New kernels are new functions.** If an information matrix or sandwich has
   to be evaluated at the fitted parameters in C++, add a **new** exported
   kernel (e.g. `*_full_vcov_at_params_cpp`). Never add an argument or an
   output field to a kernel the treatment path calls, even with a default
   that "does nothing". Use a targeted compile only.
3. **No extra work or memory on the hot path.** Calling `compute_estimate()`,
   any CI or p-value method, or any resampling path performs no extra
   allocation, inversion, copy or cache write because this feature exists.
   The new path's results are cached in their **own** slot
   (`private$coef_table_cache`, a different name from `cached_values`). The
   existing cache-reset sites clear it with a single `NULL` assignment, and
   that is the only touch on existing code apart from mounting the component.
   Better still, the new slot can key on the identity of the cached fit
   object, so no reset site needs to change at all (decide in TODO-3).
4. **The treatment SE is never re-derived from the new path.** The class's
   reported SE always comes from the existing `ssq`. The new path's
   treatment row is a **check** against it (the invariant below), not a
   replacement.

## Proposal

- **Public method** `get_coefficient_table()` exists **only on supporting
  classes**. It is mounted as a component through `define_inference_class()`
  and driven by a registry capability flag (`supports_coefficient_table`),
  not defined on the abstract base. It returns a numeric matrix like
  `coef(summary(glm))`:
  - Columns: `Estimate`, `Std. Error`, `z value` / `t value`, `Pr(>|z|)` /
    `Pr(>|t|)`. Use `t` with the class's own `df` when the class uses `t` for
    its treatment CI (e.g. OLS); otherwise use `z`.
  - Rows: model-matrix column names, with the treatment row labelled
    `treatment`. Multi-part models use the prefixes the existing tables
    already use (`conditional:`, `zero:`, `hurdle:`). Ordinal thresholds
    are labelled `threshold:<k>|<k+1>`. Mixed models list fixed effects only.
  - The matrix carries an attribute (e.g. `attr(, "inference") = "model-based
    Wald"`) so downstream code can tell what the table is.
- **Separate and lazy** (see the hard constraint above): the full `vcov` is
  formed only inside the new path, on an explicit
  `get_coefficient_table()` / `get_summary()` call. It is never formed in
  `shared()`, never in `generate_mod()`, and never inside bootstrap,
  randomization or parametric-bootstrap refits. Tier 0 classes that already
  build `summary_table` on their existing path keep doing exactly that,
  unchanged. The new path only reads it.
- **`get_summary()`:** on supporting classes, print the coefficient table
  (plus the existing fallback header) instead of the raw fit list. Leave
  unsupported classes' current output unchanged.
- **Documentation:** each supporting class's roxygen states that the
  covariate rows are **model-based only**. They are not justified by the
  randomization (only `w` was randomized), have no randomization, bootstrap
  or exact counterpart, and under KK `OneLik` they come from the combined
  likelihood. Add a short vignette section. Add an `InferenceSuite`
  cross-reference only if TODO-1 decides the suite should expose it (default:
  no).
- **Python:** the Python package exposes neither `get_mod()` nor
  `get_summary()` today (grep 2026-10-09). Parity is out of scope here; TODO-1
  records yes or no.

## Tests

- **Registry-wide invariant:** for every class with
  `supports_coefficient_table`, the table's treatment row equals the class's
  own estimate and SE, and the class's own CI is reproduced from the row (`z`
  or `t` with `df`).
- **Registry-wide wiring gate:** every class with the flag has the method, and
  no class without it has the method. Add this to the pre-push structural
  gates beside the existing wiring/drift tests. Keep it lean, with no
  `comprehensive_tests` dependence.
- **Parity at tight tolerance, per family:**
  - `stats::lm` / `glm` (gaussian, poisson, quasipoisson, binomial
    logit/probit/identity/log)
  - `MASS::glm.nb`, `betareg`, `survival::coxph` (plus `strata()`),
    `survival::survreg` (Weibull), `MASS::polr` / `ordinal::clm` for the
    cumulative-link family
  - `sandwich::vcovHC(type = "HC0")` for the modified-Poisson, robust-Poisson
    and fractional-logit sandwich classes
  - `pscl` for hurdle/ZI, `lme4` / `glmmTMB` for the GLMM fixed effects
- **No-op golden:** existing estimates, SEs, CIs and p-values are bit-for-bit
  unchanged, per the v1.1.0 additive standing constraint.
- **Hot-path separation guard (structural):**
  - Run a static call-graph check (`codetools::findGlobals` /
    `all.names` on the method bodies, or the graft call graph in CI). No
    function on the treatment path (`generate_mod`, `shared`,
    `get_standard_error`, `compute_estimate_with_bootstrap_weights`, the
    resampling workers) references any symbol of the new path.
  - Put a call counter on the new path's builder. It stays at 0 across
    `compute_estimate()`, every CI and p-value method, and a bootstrap and a
    randomization call. It reaches 1 only after `get_coefficient_table()`.
- **Hot-path no-regression check (timing, manual, not in pre-push):** for
  one class per tier, the median timings of `compute_asymp_confidence_interval()`
  and a 1,000-draw bootstrap and randomization run must sit within the
  benchmark noise floor of the pre-feature baseline
  (`performance_profiling_and_upgrades.md` measurement infrastructure). This
  applies to both fresh-object and repeat-call timings.
- **Kernel signature freeze:** the formal arguments and returned field names
  of every kernel the treatment path calls stay identical before and after.
  Snapshot them in a test.

## TODOs

- [ ] TODO-1: Decisions (ask the user):
  1. Method absent on unsupported classes (recommended, matches the scope
     rule) vs. present everywhere with an informative error.
  2. Column set. Recommended: the four `glm` columns only; CIs come from
     `confint`-style arithmetic in the docs, not extra columns.
  3. Python parity yes or no.
  4. `InferenceSuite` exposure yes or no (recommended: no).
  5. Tier 3 include/exclude, per class.
- [ ] TODO-2: Per-class audit. For every Tier 0–3 class, confirm which
  estimator produces its treatment SE (model-based, sandwich, or
  dispersion-scaled), where the full β lives (`b` vs `params` vs
  `coefficients`), and whether the names match the design's model-matrix
  columns. Output: the allowlist (`supports_coefficient_table = TRUE`) and,
  for each class, how its vcov is formed. Start from the 2026-10-09 sweep
  script pattern.
- [ ] TODO-3: Shared component, as a **separate path** (hard constraint
  above). Covers:
  - a lazy `vcov` builder that reads the existing fit object, or else
    recomputes from the cached parameters plus the design `X`/`w`/`y`: a full
    inverse of an information matrix it evaluates itself,
    `sigma2_hat * solve(XtX)`, or the class's sandwich recomputed by a new
    function;
  - its own cache slot;
  - the row-naming helper;
  - the `CoefficientTable` component mounted through
    `define_inference_class()`;
  - the registry capability flag;
  - the `get_summary()` integration.

  No edits to `generate_mod()`, `shared()` or any kernel the treatment path
  calls. Any needed C++ is a **new** kernel function (targeted compile only).
  Per class, TODO-2's audit records which existing helpers the new path can
  call read-only, and what it must recompute.
- [ ] TODO-4: Wire Tier 0, plus the invariant and parity tests.
- [ ] TODO-5: Wire Tier 1, plus the invariant and parity tests.
- [ ] TODO-6: Wire Tier 2, including the sandwich classes (reuse each class's
  own meat; HC0 parity) and the ordinal threshold surfacing.
- [ ] TODO-7: Tier 3, per the TODO-1 decisions.
- [ ] TODO-8: Registry-wide wiring gate in pre-push, the structural
  separation guard (call-graph check plus builder call counter), the kernel
  signature freeze, the no-op golden check, and a one-off manual hot-path
  timing comparison against the pre-feature baseline, recorded in this file.
- [ ] TODO-9: Docs. Per-class roxygen (model-based-only caveat), a vignette
  section, a NEWS entry when it ships, and the `test-mle-km-summary-table.R`
  Part 2 header (the gap it records is closed).
