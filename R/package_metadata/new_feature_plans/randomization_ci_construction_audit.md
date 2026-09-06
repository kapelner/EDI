# Randomization CI Construction Audit: Cox-Family Scale Mismatch (bug), and the Null Construction (verified correct)

> **Depends on:** none. Sibling of `incidence_randomization_cis.md` (same
> bug family: a randomization CI reported on a scale other than the class's
> estimand) and `randomization_ci_affine_shift_reuse.md` (whose shift
> identity must match the construction verified in §B — it did not, and was
> corrected 2026-09-05). Release: v1.1.0 (`release_v1_1_0.md → TODO-17x`).
> **§A ends in a user decision** (Phase 0 style); §B is closed.

Date: 2026-09-04; §B rewritten 2026-09-05 after the construction was
verified by test. Found while answering "is leaving the censoring indicator
untouched under the survival time-shift theoretically defensible?" — the
indicator question has a defensible answer (§A.0); checking it empirically
exposed §A.

## A. The Cox family's randomization CI is on the wrong scale — **bug**

### A.0 The indicator question (answered; not a bug)

The survival shift is `y_sim[w_b == 1] = y · e^δ` with `dead` untouched
(`inference_all_abstract_rand.R:1032-1057`, `shift_randomization_responses()`;
`fast_coxph_regression.cpp:1108-1124` for the C++ path). That scales
**both** event and censoring times of treated units and keeps each unit's
status. This is exactly the residual construction of rank-based AFT
inference — residuals `log y_i − δ w_i` for *every* observation, censored
or not, indicators carried over (Tsiatis 1990, *Ann. Statist.*; Wei, Ying &
Lin 1990, *Biometrika*; Jin, Lin, Wei & Ying 2003, *Biometrika*). The
alternative — scale only event times and recompute the indicator against a
fixed censoring time — is not identifiable, because `C_i` is unobserved for
units that had the event. Under independent censoring the rank/partial-
likelihood statistics on these residuals are asymptotically valid even
though the residual censoring distribution then depends on `w`; the
*finite-sample* permutation version is exact only if censoring times are
on the same accelerated clock (`C_i(1) = e^δ C_i(0)`), plausible for
health-driven dropout and false for calendar-time administrative
censoring. **Verdict: standard and defensible; documented in the roxygen
(2026-09-04), no code change.**

### A.1 Symptom

`InferenceSurvivalCoxPHRegr` on a Weibull DGP (`n = 120`, shape 2, true
log time-ratio `δ = 0.8` ⇒ true log HR `= −1.6`, 30 % censoring;
`$TMPDIR/cox_scale_check2.R`, seed 7):

```
Cox estimate (log HR):  -1.702        Wald CI: [-2.223, -1.180]
p(δ) with the log-time shift:  δ = -1.70 → 0.004   δ = 0 → 0.004   δ = 0.80 → 0.998   δ = 1.20 → 0.072
rand CI (r = 501, default tolerances):  [-1.702, -1.264]
```

The p-value machinery is a coherent AFT-scale test — it peaks at the true
log time-ratio `0.8`. The CI driver then seeds the bracket from the Wald
CI and the estimate (**log-HR scale**, all negative), expands and bisects
there, and returns a lower bound equal to the estimate itself and an upper
bound that corresponds to nothing. The same script on
`InferenceSurvivalWeibullRegr` (an AFT estimand) gives estimate `0.777`,
rand CI `[0.521, 1.076]` — correct, because its estimand *is* on the shift
scale.

### A.2 Root cause

`compute_rand_confidence_interval()` (`inference_all_abstract_rand_ci.R`)
seeds, brackets, and reports on the **estimate's** scale
(`build_randomization_ci_search_bounds`), while the survival
`transform_arg = "log"` shifts responses on the **log-time** scale. For AFT
classes the two coincide. For proportional-hazards classes the estimand is
a log hazard ratio, related to the log time-ratio only under a parametric
assumption (Weibull: `log HR = −shape · δ`) that the Cox model does not
make — there is no conversion available. `InferenceSurvivalStratCoxPHRegr`
already refuses for exactly this reason (`inference_survival_strat_cox.R:279-281`:
"estimator units (Log-Hazard Ratio) are inconsistent with the randomization
test's required transformed scale (Log-Time Ratio / AFT effect)"); the
unstratified class and the KK Cox variants never got the same guard.

### A.3 Affected classes (verified by walking each class's method chain, `$TMPDIR/surv_caps.R`)

| class | estimand | rand CI today | status |
|---|---|---|---|
| `InferenceSurvivalCoxPHRegr` | log HR | generic AFT-scale driver | **wrong scale** |
| `InferenceSurvivalKKLWACoxPHIVWC`, `…OneLik` | log HR | generic driver | **wrong scale** (unverified numerically; same driver, same estimand) |
| `InferenceSurvivalKKStratCoxPHIVWC`, `…OneLik` | log HR | generic driver | **wrong scale**; inconsistent with their non-KK sibling, which refuses |
| `InferenceSurvivalStratCoxPHRegr` | log HR | `stop()` | correct behaviour |
| `InferenceSurvivalWeibullRegr`, `…KKWeibullMarginal`, the four `…GLMMWeibullFrailty…` classes, `…KKRankRegrIVWC` | AFT log time-ratio | generic driver | consistent |
| `InferenceSurvivalKMDiff`, `LogRank`, `RestrictedMeanDiff`, `GehanWilcox` | various | `stop()` | correct behaviour |
| `InferenceSurvivalDepCensTransformRegr` | — | returns `NA` | fine |

`package_tests/testthat_bulk/test-ci-rand.R:151-176` tests only the Weibull
class (and asserts `all(ci > 0)` with the comment "ratios should be
positive" — the CI is on the *log* time-ratio scale and is positive there
only because the fixture's effect is; the assertion is scale-confused but
harmless).

### A.4 Remediation options (user decision — TODO-1)

1. **Refuse, as the stratified class does** — copy its `stop()` override
   onto the five Cox-family classes; the suite stops offering `rand` CI for
   them the way it already does for incidence. Smallest, safest, matches
   an existing precedent. Loses nothing that currently works.
2. **Report the AFT-scale interval, labelled** — keep the driver but seed
   the bracket from `0` (not the log-HR estimate) with a radius on the
   log-time scale, and return the bounds with an attribute
   `scale = "log_time_ratio"`; document that for Cox classes the
   randomization CI is an AFT-effect interval, not a log-HR interval. Gives
   users a *valid* interval, but for a different estimand than the point
   estimate — the mismatch the incidence plan called unacceptable.
3. **Invert on the log-HR scale directly** — a proportional-hazards sharp
   null cannot be imposed on individual outcomes (no potential-outcome
   transform realises a hazard ratio), so this would have to be a
   *parametric* re-simulation, not a randomization test. Out of scope for
   a randomization CI; recorded to close the question.

Recommendation: **option 1 now** (one commit, five classes, a test that
each raises), with option 2 as a possible later feature if an AFT-scale
interval for Cox classes is ever wanted.

## B. The null construction — **verified: already impute-then-permute; earlier draft of this section was wrong**

### B.1 What the code does (verified 2026-09-05)

For a nonzero sharp-null effect `δ`, `setup_randomization_template_and_shifts()`
(`inference_all_abstract_rand.R:1058-1100`) first **imputes the control
potential outcomes** by removing the hypothesised effect from the units
that were actually treated,

```
y_delta = shift_randomization_responses(y, w_obs, δ, inverse = TRUE)     # y − δ·w_obs on the additive scale
```

and every path then adds it back to the units each reference allocation
`w_b` treats: the reused-worker path sets the worker's responses to
`y_delta` (`:738`, `w_priv$y = as.numeric(y)`) before the per-permutation
forward shift; `load_randomization_perm_into_worker()` (`:1102-1135`)
shifts `y_delta` forward; the C++ fast kernels receive `setup$y_delta`
(`:168`); and the randomization-bootstrap path does the same
(`inference_all_abstract_rand_bootstrap.R:249-262`, `y0_full` with
`inverse = TRUE`, then `:726-736` forward per draw). That is the textbook
construction (Rosenbaum 2002, *Observational Studies*, ch. 2; Imbens &
Rubin 2015, *Causal Inference*, ch. 5): `y_sim = y − δ·w_obs + δ·w_b`.

**The earlier draft of this section claimed the construction was
shift-the-null (`y + δ·w_b`).** That was a misreading of
`w_priv$y_temp = w_priv$y` at `:739` in isolation — the line immediately
above assigns the imputed `y_delta` into `w_priv$y`. The claim, the option
analysis, the "no user option" discussion, and the "switch unconditionally"
recommendation that followed from it are all withdrawn; nothing needed to
change in the code.

### B.2 The test that pins it

`tests/testthat/test-rand-null-construction.R` (added 2026-09-05) computes
the null draws at `δ = 0.7` on a Bernoulli continuous design with **fixed**
reference allocations and compares them, exactly, with both constructions
computed by hand — on the C++ fast-kernel path (`InferenceAllSimpleAverageDiff`)
and on the R reused-worker path (`InferenceContinOLS`, which has no fast
kernel). Both match impute-then-permute to `1e-8`/`1e-6` and differ from
shift-the-null by more than `1e-3` on the fixture (so the test cannot pass
vacuously). A third case checks `δ = 0` is the plain permutation
distribution. 9/9 expectations pass on the current build.

### B.3 Consequence for `randomization_ci_affine_shift_reuse.md` (corrected 2026-09-05)

That plan's identity section stated EDI's convention as `y_sim = y + δ·w_b`
— the same misreading — and derived `t0_b(δ) = t0_b(0) + δ` from it. Under
the actual construction, for a statistic that is the coefficient on `w_b`
in a linear design containing `w_b`,

```
t0_b(δ) = coef_{w_b}(y − δ·w_obs + δ·w_b) = t0_b(0) + δ·(1 − c_b),
c_b = coefficient on w_b when w_obs is regressed on the permuted design [1, w_b, X]
    (= d_b = mean(w_obs | w_b = 1) − mean(w_obs | w_b = 0) for the simple mean difference)
```

Still an exact affine identity, still one cached `δ = 0` distribution
serving the whole search — but the per-permutation slope is `1 − c_b`, not
`1`, and `c_b` costs one regression of the fixed vector `w_obs` on each
permuted design (one `O(nB)` dot product for the mean difference; one small
solve per permutation for OLS/Lin), computed once. **Implementing that
plan as originally written would have silently replaced the exact
construction with shift-the-null.** A correction note was added to the plan
the same day; the test in B.2 is the guard that will catch it if the
identity is ever wired without the `(1 − c_b)` factor.

### B.4 Heterogeneous effects (still worth a coverage check, unrelated to the construction)

Both the sharp-null test and its inversion assume a constant effect. Under
heterogeneous effects (`τ_i ~ N(τ, σ_τ²)`), a sharp-null interval for the
*average* effect can under-cover (Ding, Feller & Miratrix 2016, *JRSS-B*;
Wu & Ding 2021, *JASA*). The principled fix is a **studentized** statistic
(Wu & Ding 2021), valid for the weak null. This is a separate audit row for
`algorithm_choice_audit.md` (TODO-2 below), not a construction question.

## Implementation TODOs

- [x] TODO-1: **§A remediation — decided and implemented 2026-09-06 (user
  decision: option 1, refuse).** Implemented by mirroring the ordinal
  model-coefficient precedent rather than five copy-pasted overrides, which
  gives the same refusal in one place plus the suite exclusion the decision
  asked for: (i) `EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES` +
  `inference_is_log_hazard_ratio_class()` in `inference_class_registry.R`
  (the six log-HR classes, including the already-refusing
  `InferenceSurvivalStratCoxPHRegr`; pinned to agree with the
  `"log_hazard_ratio"` entries of `EDI_INFERENCE_ESTIMAND_TAGS`); (ii) the
  six added to `EDI_INFERENCE_EXCLUDED_CAPABILITIES` for `randomization_ci`
  only, so `capabilities()` no longer lists it and `InferenceSuite` never
  offers the method; (iii) a guard at the top of
  `InferenceRandCI$compute_rand_confidence_interval()` that `stop()`s with
  the stratified class's explanation, generalized. The randomization
  p-value and the randomization-**bootstrap** CI are untouched — the latter
  was checked empirically and is a percentile interval of the
  resample-and-reassign distribution on the estimate's own scale (Cox:
  `[−2.12, −1.28]` around `−1.70`), not a `δ` inversion, so it never had
  the bug. Tests: `tests/testthat/test-log-hazard-ratio-randomization-ci-disabled.R`
  (list ↔ tag-table agreement; capability exclusion with p-value and BRT
  capabilities retained; direct-call refusal on the two non-KK classes;
  Cox p-value and BRT CI still work; Weibull rand CI still works).
  `NEWS.md` entry added. Option 2 (a labelled AFT-scale interval for Cox
  classes) remains a possible later feature.
- [x] TODO-2 (was: decide the §B construction): **closed 2026-09-05** — the
  construction is already impute-then-permute on every path; pinned by
  `tests/testthat/test-rand-null-construction.R`. Replaced by: add a
  "studentized statistics for the weak null" row to
  `algorithm_choice_audit.md` (Wu & Ding 2021) with a heterogeneous-effect
  coverage corpus entry in `algorithm_ab_testing_framework.md`.
- [x] TODO-2b: **Correct `randomization_ci_affine_shift_reuse.md`'s identity**
  to `t0_b(δ) = t0_b(0) + δ·(1 − c_b)` — done 2026-09-05 (note added to that
  plan's identity section); the implementation tasks there must compute
  `c_b`.
- [ ] TODO-3: Fix `test-ci-rand.R:171-172`'s scale-confused comment/assertion
  (`all(ci > 0)` is not a property of a log-scale CI) — independent of
  TODO-1; replace with an assertion that the CI brackets the class's
  estimate *on the estimate's own scale*, which is exactly the property §A
  found violated for Cox.
- [x] TODO-4: §A.0 assumptions added to the `compute_rand_confidence_interval()`
  roxygen, the Weibull class references, the Cox kernel `@param delta`, and
  `REFERENCES.md` — done 2026-09-04/05.
- [x] TODO-5 (path_audits.html registry-mirroring side quest, 2026-09-06):
  while deriving `path_audits.html`'s theoretical-support and slow-path
  fields live from the registry (a byproduct of this audit's Cox fix — see
  `path_audits_source.R`'s own header), found and fixed a genuine
  measurement gap: `comprehensive_tests.R` only ever tested the generic
  "best available" `compute_lik_ratio_bartlett_two_sided_pval` wrapper,
  never the two independently-implemented `..._approx_...`/`..._exact_...`
  variants its own doc comment recommends for reproducibility-sensitive
  callers. Added four new gated `safe_call()`s (approx/exact × pval/ci) to
  `comprehensive_tests.R`, smoke-tested against `InferenceContinKKOLSOneLik`
  (the one class supporting both — approx pval `0.0042` vs exact pval
  `0.0129`, confirming they are genuinely distinct computations, not
  duplicates), and repointed `path_audits_source.R`'s `cell_likrat_bart_p`/
  `_c`/`_ex_p`/`_ex_c` at the specific method IDs. Found and fixed one more
  bug in the process: `EDI_COMPREHENSIVE_SLOW_PATHS$bartlett_pval`'s class
  list doesn't distinguish which variant a class has, so naively mapping it
  to all four method names promoted several classes' structurally-absent
  exact variant from `NI` to a false `SLOW`; fixed by filtering the derived
  Bartlett entries against each row's own `pboot`/`bartlett_exact` flags.
  Full report on the registry's class/method-only (never design/formula)
  granularity: `comprehensive_slow_paths_report.md`.
