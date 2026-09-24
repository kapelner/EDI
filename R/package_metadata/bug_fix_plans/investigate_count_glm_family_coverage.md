# Investigate: Count-Family GLM Coverage (`InferenceCountPoisson`/`InferenceCountNegBin`/`InferenceCountZeroInflatedPoisson`)

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's `low_coverage` check (95% CI
> coverage target, exact binomial test + FDR) after its first-ever run
> against the accepted baseline surfaced 650 new, never-triaged findings.
> These 3 classes account for 50 of those 650 (18/16/16 respectively), all
> new. **Medium-low confidence — real, broad pattern confirmed; root cause
> NOT pinned down; `TODO-28` cleanly ruled out for all 3.**

## The finding

All 3 classes show `low_coverage` findings, but with **two distinct
shapes**:

**`InferenceCountPoisson`/`InferenceCountNegBin` (~. formula, broad,
cross-method):** coverage sits at **~0.85-0.93** (moderately under target)
across almost every asymptotic method (`asymp`/`wald`/`score`/`gradient`/
`lik_ratio`/`lik_ratio_bartlett*`) AND most resampling methods
(`bayesian_bootstrap*`, `bootstrap_studentized`, `param_bootstrap`,
`jackknife_wald`) simultaneously — a few resampling methods
(`m_out_of_n_bootstrap`, `subsampling`, `lik_ratio_bootstrap`) instead
**OVER-cover** at ~0.98-0.99 (plausibly just those families' known
conservative width-inflation, not part of the same problem).

**`InferenceCountZeroInflatedPoisson`:** findings are confined to
**asymptotic/direct-fit methods only** (`asymp`/`gradient`/`lik_ratio`/
`score`/`wald`), coverage ~0.85-0.91 — no bootstrap-family methods flagged
at all (this class's component set, `InferenceCountZeroAugmentedPoissonAbstract`
→ `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
"ZeroAugmentedCountLikelihood")`, has no `NonParamBoot`/`Jackknife`
component, so `subsampling`/`m_out_of_n_bootstrap`/`jackknife_wald` simply
don't exist for this class — the shape difference from Poisson/NegBin may
just reflect which methods exist, not a different mechanism).

## `TODO-28` — cleanly ruled out for all 3, confirmed by direct code read

`InferenceCountPoisson$compute_estimate_with_bootstrap_weights()`
(`inference_count_poisson.R:402-420`) and
`InferenceCountNegBin$compute_estimate_with_bootstrap_weights()`
(`inference_count_negbin.R:121-140`) both build `X_full = cbind(Intercept,
treatment, X_data)` **directly inline** from `private$get_X()` on every
call — neither calls `create_design_matrix()`/`build_design_matrix()` at
all, so the `cached_design_matrix` staleness bug cannot apply regardless
of their `supports_reusable_bootstrap_worker()` status (both return
`TRUE`, but the vulnerable cache is simply never touched). Not
independently checked for `InferenceCountZeroInflatedPoisson`'s abstract
base, but moot anyway since it shows no bootstrap-family findings.

## Candidate mechanism (unconfirmed) — a coverage_truth/DGP mismatch, not necessarily a package bug

Neither `InferenceCountPoisson`, `InferenceCountNegBin`, nor
`InferenceCountZeroInflatedPoisson` appears in `comprehensive_tests.R`'s
`COVERAGE_CLOSED_FORM` or `COVERAGE_MC_SPEC` lists (checked directly,
`comprehensive_tests.R:3207+`/`:3302+`) — so `get_coverage_truth()` falls
through to the raw default, `coverage_truth = beta_T`
(`comprehensive_tests.R:1485`). This is the exact same class of harness
issue this project has found before for other classes (see the code
comment at `comprehensive_tests.R:3388-3392` describing
`InferenceAllSimpleMeanDiffPooledVar`'s prior ~51%-coverage false alarm
from the identical omission, and `release_v1_0_5.md`'s `TODO-32`/`fix_mc_coverage_truth_covariate_mismatch.md`
for a second confirmed instance).

**Reasoning for why this is plausible but NOT confirmed:** the count DGP
(`apply_treatment_effect_and_noise()`, `comprehensive_tests.R:3129-3132`)
generates `lambda_t = y_t * exp(beta_T*[w_t==1] + eps)`, `eps ~
N(0,SD_NOISE)` drawn per-subject independent of treatment arm, then
`rpois(1, lambda_t)`. Algebraically, the marginal (population-averaged)
log-rate-ratio between arms should still equal `beta_T` in expectation
(since `eps`'s distribution doesn't differ by arm), which argues AGAINST
a pure truth-value bias. But the broad, near-uniform ~0.85-0.93
undercoverage spanning BOTH naive-model asymptotic methods AND genuinely
nonparametric resampling methods (which should be robust to Poisson-
variance misspecification) is hard to explain by a single per-method SE
bug — if it were only "naive Poisson SE ignores overdispersion," bootstrap
methods should still be well-calibrated, but they aren't. This tension is
unresolved: neither the "coverage_truth is subtly wrong" hypothesis nor a
"real overdispersion-driven SE bug replicated across an unusually large
number of methods" hypothesis was confirmed or ruled out in this pass.

**Overdispersion note (secondary candidate, also unconfirmed):** the
per-subject multiplicative `exp(eps)` noise is an added source of
variance beyond standard Poisson sampling (`Var(Y) = E[Y] +
Var(lambda_t)` by the law of total variance) — genuine overdispersion
relative to what `InferenceCountPoisson`'s naive model assumes.
`InferenceCountNegBin` has its own dispersion parameter and should be
more robust to this in principle, but still shows a similar pattern,
suggesting either (a) NegBin's gamma-mixture dispersion doesn't fully
match this DGP's log-normal-ish multiplicative noise structure (a benign
DGP/model mismatch, not a package bug), or (b) the shared
`coverage_truth` issue above dominates for both classes regardless of
dispersion handling.

## TODOs

- [ ] TODO-1: Determine whether `beta_T` actually IS the correct
  population-marginal log-rate-ratio target for these 3 classes under
  this exact DGP — either analytically (verify the Jensen's-inequality/
  arm-independence argument above holds exactly, not just approximately)
  or empirically (a large-`n`, `SD_NOISE=0` one-off simulation comparing a
  correctly-specified Poisson MLE fit against raw `beta_T` — NOT run in
  this pass, scoped out by this fork's read-only/no-heavy-simulation
  directive).
- [ ] TODO-2: If TODO-1 confirms `beta_T` is right, root-cause the actual
  SE/CI defect directly instead — start with `InferenceCountZeroInflatedPoisson`'s
  asymptotic-only cluster (`inference_count_zero_augmented_poisson_abstract.R`,
  `compute_asymp_confidence_interval`/`compute_wald_confidence_interval`/
  `compute_score_confidence_interval`/`compute_gradient_confidence_interval`,
  a large ~1300-line shared abstract file not fully read this pass) since
  it's the cleanest, most isolated candidate (single mechanism, no
  bootstrap-vs-asymptotic split to explain).
- [ ] TODO-3: If TODO-1 refutes `beta_T`, add a `COVERAGE_MC_SPEC` (or
  closed-form, if the Poisson-marginal math resolves cleanly) entry for
  all 3 classes, matching the pattern already used to fix
  `InferenceAllSimpleMeanDiffPooledVar`'s prior instance of this exact
  harness gap.
- [ ] TODO-4: Determine whether `InferenceCountNegBin`'s dispersion
  parameter materially changes its coverage vs. `InferenceCountPoisson`'s
  (compare the two classes' actual coverage numbers side by side, which
  this pass did not do quantitatively) — if NegBin is meaningfully better
  calibrated than Poisson despite both being flagged, that's evidence FOR
  the overdispersion-driven explanation over the truth-mismatch one, and
  vice versa.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only. TODO-1's
simulation step, if pursued, must not require any package recompilation —
it exercises `comprehensive_tests.R`'s DGP logic and/or the already-
installed package only.
