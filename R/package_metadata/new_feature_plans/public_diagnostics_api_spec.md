# Public Diagnostics API Implementation Spec

> **Depends on:** `optimizer_diagnostics_report.md` (TODO-9..12 consume its layer); `fix_inference_hierarchy.md` (core-path phases run across migrated families). Hosts the re-homed diagnostics TODOs of the finished m-out-of-n spec and `prw_subsampling_implementation_spec.md`. (Global ordering: see `_master.md`.)

Generated: 2026-07-27

## Scope

This spec defines a public, opt-in diagnostics API for the primary inference
calls:

```r
compute_estimate()
compute_pval()
compute_ci()
```

The new API adds diagnostic variants:

```r
compute_estimate_details()
compute_pval_details()
compute_ci_details()
```

The existing scalar API must remain the fast path. It continues to return the
current value shape: a numeric estimate, p-value, confidence interval, or
`NA`/`c(NA_real_, NA_real_)` when the target is not estimable.

The debug API returns a structured object describing what happened during the
same logical computation: value, status, typed non-estimability reason,
timings, selected method, and collected diagnostics.

This feature should be implemented together with, or shortly after,
[optimizer_diagnostics_report.md](optimizer_diagnostics_report.md). That report
defines the lower-level solver/fit diagnostics layer. This spec defines the
public R-facing envelope that exposes those diagnostics without slowing normal
users.

## Non-Goals

- Do not change return values of `compute_estimate()`, `compute_pval()`, or
  `compute_ci()`.
- Do not make the fast path compute expensive diagnostics.
- Do not promise "all internals." The public debug object is a stable,
  curated diagnostic schema.
- Do not replace existing lower-level `debug = TRUE` options for bootstrap or
  randomization distribution helpers in the first pass. Those can feed into
  this API later.

## Naming

Use the exact public method names requested for now:

```r
compute_estimate_details()
compute_pval_details()
compute_ci_details()
```

Long term, other aliases (e.g. `diagnose_estimate()`) may be added, but the
initial implementation should keep one official name set to avoid documenting
multiple contracts.

## Core Design Rule

Shared implementation must share orchestration, not instrumentation.

The fast path must pass `diagnostics = FALSE` all the way down. Lower layers
must not compute extra QR decompositions, eigendecompositions, refits,
per-replicate traces, or root-search traces unless diagnostics are explicitly
requested.

Recommended shape:

```r
compute_estimate = function(...) {
  private$compute_estimate_core(..., diagnostics = FALSE)$value
}

compute_estimate_details = function(...) {
  private$compute_estimate_core(..., diagnostics = TRUE)
}
```

The core function may return the full debug object internally in both cases,
but when `diagnostics = FALSE` the object must contain only fields already
available at no extra cost. Avoid building large nested structures on the fast
path if allocation overhead is measurable.

## Diagnostic Object Contract

Return an S3 object with class:

```r
c("EDIInferenceDebugResult", "list")
```

Required top-level fields:

```r
list(
  value = <numeric result>,
  status = "ok" | "no_estimate" | "no_se" | "unsupported" | "invalid_argument" | "error",
  target = "estimate" | "pval" | "ci",
  method = <character scalar>,
  inference_class = <character scalar>,
  response_type = <character scalar>,
  design_type = <character scalar>,
  stage = <character scalar or NULL>,
  reason = <character scalar or NULL>,
  message = <character scalar or NULL>,
  timings = list(total_sec = <numeric>),
  diagnostics = list(),
  warnings = character(),
  errors = character()
)
```

`value` must match the public scalar API for the same object and arguments.
For non-estimable cases:

- estimate: `NA_real_`
- p-value: `NA_real_`
- CI: `c(NA_real_, NA_real_)` with normal CI names where applicable

`status` meanings:

- `ok`: the returned value is finite and usable.
- `no_estimate`: the path completed and returned a typed non-estimable state.
- `no_se`: the estimate was computed and finite, but the standard error stage
  was never attempted or did not produce a value. Distinct from `ok`: callers
  must not assume `se` is present just because `status` isn't an error/no_estimate
  state. See TODO-20.
- `unsupported`: the method/argument combination is deliberately unimplemented
  for this class (e.g. "not implemented", "only supported", "does not
  support" style exceptions) -- a known, permanent limitation, not a runtime
  failure.
- `invalid_argument`: the caller passed arguments the method rejects by
  design (e.g. out-of-range `alpha`, malformed `delta`) -- a caller error,
  not a numerical or estimability failure.
- `error`: catch-all for any other unexpected exception -- one that doesn't
  match a typed reason above. The debug API may catch and return this as a
  structured debug result, but the existing scalar API behavior should
  remain unchanged unless explicitly changed elsewhere. See TODO-21 for the
  classification mechanism.

`stage` should use the package's existing stages where possible:

```r
"estimate"
"se"
"pval"
"ci"
"bootstrap"
"bayesian_bootstrap"
"parametric_bootstrap"
"jackknife"
"randomization"
"ci_inversion"
"likelihood_null_fit"
"likelihood_full_fit"
"solver"
```

`reason` must be a stable typed string, not a free-form sentence. Existing
`cache_nonestimable_estimate()` and `cache_nonestimable_se()` reasons should
be reused where possible.

## Method-Specific Required Fields

### `compute_estimate_details()`

`estimate_only` is an explicit input parameter here, mirroring the existing
public `compute_estimate(estimate_only = FALSE)` signature -- the sole
argument on every one of the ~85 `compute_estimate()` overrides across the
package, with no exceptions -- rather than something only discovered after
the fact:

```r
compute_estimate_details = function(estimate_only = FALSE, diagnostic_level = c("standard", "extended", "trace"))
```

The `diagnostic_level` argument is the only addition beyond what
`compute_estimate()` already takes; see Lazy Diagnostics Levels below.

Required `diagnostics` subfields when available without extra work:

```r
diagnostics = list(
  estimate_only = TRUE | FALSE,
  converged = TRUE | FALSE | NA,
  iterations = <integer or NA>,
  coefficient_abs_max = <numeric or NA>,
  standard_error = <numeric or NA>,
  nonestimable_state = <list or NULL>,
  fit = <optimizer diagnostics or NULL>
)
```

`diagnostics$estimate_only` echoes the effective value actually used for the
underlying fit this snapshot describes -- normally the caller's own
`estimate_only` argument above, passed straight through the same
`private$shared(estimate_only = ...)` path `compute_estimate()` already uses.
It can still differ from the caller's input when, at diagnostic level
`"standard"`, an already-cached fit is reused instead of a fresh one (see
Lazy Diagnostics Levels) -- in that case it reports the mode the reused fit
actually ran in, so the caller can tell why `standard_error` or `fit` came
back `NA` even though they passed `estimate_only = FALSE`.

Setting `estimate_only = TRUE` still computes and returns `value` -- it only
concerns which of the diagnostics subfields above are cheaply available;
`converged`, `iterations`, and `coefficient_abs_max` are populated by any fit
mode, while `standard_error` and `fit$information`-style fields require
`estimate_only = FALSE`.

Do not compute rank, condition number, or eigenspectrum unless diagnostics mode
explicitly asks for them and the lower layer advertises support.

### `compute_pval_details()`

Required arguments mirrored in the result:

```r
parameters = list(
  delta = <numeric>,
  testing_type = <character>,
  alternative = "two_sided"
)
```

Required `diagnostics` subfields where applicable:

```r
diagnostics = list(
  estimate = <numeric or NA>,
  standard_error = <numeric or NA>,
  test_statistic = <numeric or NA>,
  reference_distribution = <character or NULL>,
  full_fit = <fit diagnostics or NULL>,
  null_fit = <fit diagnostics or NULL>,
  bootstrap = <bootstrap diagnostics or NULL>,
  randomization = <randomization diagnostics or NULL>
)
```

Bootstrap-style p-value diagnostics should include:

```r
list(
  n_requested = <integer>,
  n_attempted = <integer>,
  n_success = <integer>,
  n_finite = <integer>,
  n_nonfinite = <integer>,
  n_extreme = <integer>,
  min_required = <integer>,
  finite_fraction = <numeric>,
  reused_workers = TRUE | FALSE | NA,
  seed = <integer or NULL>
)
```

### `compute_ci_details()`

Required arguments mirrored in the result:

```r
parameters = list(
  alpha = <numeric>,
  testing_type = <character or NULL>,
  confidence_level = 1 - alpha
)
```

Required `diagnostics` subfields where applicable:

```r
diagnostics = list(
  estimate = <numeric or NA>,
  standard_error = <numeric or NA>,
  interval_method = <character>,
  fallback_used = TRUE | FALSE | NA,
  fallback_method = <character or NULL>,
  inversion = <list or NULL>,
  bootstrap = <list or NULL>
)
```

CI inversion diagnostics should include:

```r
list(
  root_engine = <character>,
  lower_seed = <numeric or NA>,
  upper_seed = <numeric or NA>,
  n_evaluations = <integer or NA>,
  bracket_found = TRUE | FALSE | NA,
  reject_at_estimate = TRUE | FALSE | NA,
  p_at_estimate = <numeric or NA>,
  validation_failure = <character or NULL>
)
```

## Lazy Diagnostics Levels

Use a `diagnostic_level` argument on debug methods:

```r
compute_estimate_details(..., diagnostic_level = c("standard", "extended", "trace"))
compute_pval_details(..., diagnostic_level = c("standard", "extended", "trace"))
compute_ci_details(..., diagnostic_level = c("standard", "extended", "trace"))
```

Default: `"standard"`.

Levels:

- `standard`: return values already computed by the normal path plus typed
  non-estimability state and timings. No extra model fits or expensive matrix
  decompositions.
- `extended`: allow one-off extra diagnostics such as QR rank checks or
  condition-number checks when the class advertises support and the cost is
  documented.
- `trace`: allow large per-replicate/per-root-evaluation traces. This is for
  development and should not be used by default in simulation sweeps.

The scalar fast API must never call `diagnostic_level = "extended"` or
`"trace"` internally.

### Why A Tiered Level Instead Of A Per-Diagnostic Flags List

An alternative design would let the caller pass a list enumerating exactly
which diagnostics to compute, e.g.
`diagnostics = list(condition_number = TRUE, quadrature_adequacy = FALSE, qr_rank = TRUE, ...)`.
This was rejected for the public contract:

- The set of *possible* diagnostics differs by family, and most flags would
  not apply to most families. `condition_number` only means something for
  likelihood-backed asymptotic families with an information matrix;
  `quadrature_adequacy` only exists for GH-quadrature GLMM paths; bootstrap
  finite-count diagnostics do not apply to closed-form Wald paths at all. A
  flags list forces every family to either silently ignore flags it does not
  support (confusing -- you asked for something and got nothing, with no
  signal why) or error on them (brittle -- breaks exactly the kind of generic
  sweep this package already relies on, e.g. `path_audits.html` and
  comprehensive tests calling the same method uniformly across dozens of
  heterogeneous classes).
- A named-flags API is functionally "all internals, gated behind booleans,"
  which contradicts the Non-Goals section above ("Do not promise 'all
  internals.' The public debug object is a stable, curated diagnostic
  schema"). A cost tier lets each family decide locally what `"standard"` vs
  `"extended"` vs `"trace"` means for itself without the public contract ever
  having to enumerate a global diagnostic vocabulary -- one that would only
  grow as [optimizer_diagnostics_report.md](optimizer_diagnostics_report.md)'s
  taxonomy (already 8 distinct failure categories) expands.

This is a real, acknowledged tradeoff, not a free win: the tiered design gives
up fine-grained cost control. A caller who wants only the condition number
and nothing else cannot ask for that in isolation -- they get whatever else
`"extended"` happens to bundle for that family, and pay for all of it. If a
specific diagnostic later turns out to be expensive enough that bundling it
into `"extended"` becomes a real cost problem for callers who don't want it,
that is the point to revisit this decision (e.g. an optional, family-specific
override layered on top of the tier), not to redesign the whole contract
around per-flag toggles up front.

## Integration With Optimizer Diagnostics

[optimizer_diagnostics_report.md](optimizer_diagnostics_report.md) proposes
native and R-level diagnostics for:

- iteration cap
- terminal gradient norm
- near-singular information
- separation or boundary divergence
- huge finite standard errors from an ill-conditioned information matrix
- GLMM variance-component boundary
- quadrature adequacy
- derivative-free optimizer convergence codes
- extreme bootstrap or LR statistics

The public details API should preserve the distinction between these cases.
Recent comprehensive-test failures in `InferenceOrdinalStereotypeLogitRegr`,
`InferenceOrdinalKKCondAdjCatLogitRegr`, and
`InferenceIncidKKCondLogitOneLik` showed two different shapes: extreme finite
point estimates, and moderate finite point estimates paired with enormous
finite SEs. Both should produce typed diagnostics; they should not be collapsed
into a generic "separation" label unless the coefficient path itself is the
evidence.

When that layer lands, debug methods should embed its output under:

```r
diagnostics$fit
diagnostics$full_fit
diagnostics$null_fit
diagnostics$replicate_fits
```

Expected fit diagnostic schema:

```r
list(
  converged = TRUE | FALSE | NA,
  hit_iteration_cap = TRUE | FALSE | NA,
  iterations = <integer or NA>,
  gradient_norm = <numeric or NA>,
  information_min_eigenvalue = <numeric or NA>,
  information_condition_number = <numeric or NA>,
  coefficient_abs_max = <numeric or NA>,
  boundary_hit = TRUE | FALSE | NA,
  boundary_type = <character or NULL>,
  optimizer = <character or NULL>,
  optimizer_code = <integer or NA>,
  diagnostic_category = <character or NULL>,
  diagnostic_severity = "ok" | "warning" | "failure" | NA
)
```

If optimizer diagnostics are not yet available for a family, set the relevant
field to `NULL` or `NA`, not by doing expensive substitute computation.

### Temporary class-local hardening to retire

As of 2026-08-24, `InferenceOrdinalStereotypeLogitRegr` has a temporary,
class-local fit-acceptance guard in
`R/EDI/R/inference_ordinal_stereotype_logit.R`. It prevents the comprehensive
harness and public scalar methods from reporting finite but unusable
stereotype-logit point estimates while the centralized diagnostics layer does
not yet exist. The guard rejects a fit when any available check fails:

- the native backend does not report `converged = TRUE`;
- the treatment coefficient is nonfinite or `abs(beta_T) > 10`;
- the returned information matrix is nonfinite, not positive definite, or has
  reciprocal condition number at most `sqrt(.Machine$double.eps)`; or
- a path requiring a standard error receives a nonfinite or nonpositive
  treatment variance.

The same predicate is applied to the ordinary fit, reusable bootstrap refits,
randomization refits, and parametric-likelihood-bootstrap full refits. Fixed-null
likelihood fits skip the treatment-coefficient cap because their coefficient is
the caller-supplied null value, but still require convergence and acceptable
information when it is available. The weighted ordinal surrogate does not
expose convergence or information diagnostics, so it currently applies only
the `abs(beta_T) <= 10` check. Rejected primary/weighted fits are returned as
`NA` and cached as nonestimable; rejected replicate fits contribute `NA` rather
than an extreme finite statistic.

This is deliberately temporary policy, not the public diagnostics API. During
Phase 3, replace `stereotype_treatment_estimate_is_usable()` and
`stereotype_fit_is_usable()` with the shared typed diagnostic classifier and
remove both class-local helpers only after the centralized acceptance policy
enforces equivalent convergence, conditioning, and separation decisions for
primary and resampled fits. Preserve regression coverage for the temporary
thresholds until that parity is demonstrated.

`InferenceIncidKKCondLogitOneLik` now has the same temporary architecture in
`R/EDI/R/inference_incidence_KK_cond_logit.R`. Its single
`assess_combined_fit()` predicate rejects ordinary, weighted,
randomization-statistic, fixed-null, and parametric-bootstrap refits unless the
native backend reports convergence without an iteration-cap exit, a finite
terminal gradient norm, finite coefficients, and positive-definite information
whose reciprocal condition number exceeds `sqrt(.Machine$double.eps)`. The
primary and resampled treatment coefficient is also capped at `abs(beta_T) <=
10`; fixed-null fits omit only that caller-controlled coefficient check. Paths
requiring uncertainty additionally require a finite positive treatment
variance, derived from the accepted information matrix when the backend did not
return one directly.

This incidence guard also prevents the class's incidence-specific Zhang
randomization shortcut from reporting a p-value when the declared primary model
statistic is nonestimable. Rejected primary fits are cached once as typed
estimate-stage nonestimability, leaving all dependent Wald, score, gradient,
likelihood-ratio, resampling, and randomization methods to return `NA` from that
shared state. Phase 3 must migrate `assess_combined_fit()` and the provisional
coefficient ceiling into the centralized classifier before deleting the
class-local implementation.

## Internal Implementation Plan

### Phase 1: Public wrapper and result object

- [ ] TODO-1: Add an `EDIInferenceDebugResult` constructor/helper.
- [ ] TODO-2: Add print and summary methods:
   - `print.EDIInferenceDebugResult`
   - `as.data.frame.EDIInferenceDebugResult`
- [ ] TODO-3: Add the base public methods on the root `Inference` class (they
   are universal wrappers around methods every class has). Any diagnostics
   method that only applies to an optional inference algorithm must instead be
   registered under that algorithm's capability in
   `public_methods_for_capability` — the shallow hierarchy's rule is that a
   public optional method exists iff the matching capability exists.
- [ ] TODO-4: The default implementations should call existing public methods and wrap
   their results with minimal diagnostics. This makes the API available
   package-wide without changing class internals.

Phase 1 default behavior is intentionally shallow but safe.

### Phase 2: Core-path integration

Move high-traffic families from wrapper-only diagnostics to shared core
functions:

```r
private$compute_estimate_core(diagnostics = FALSE, diagnostic_level = "standard")
private$compute_pval_core(diagnostics = FALSE, diagnostic_level = "standard")
private$compute_ci_core(diagnostics = FALSE, diagnostic_level = "standard")
```

Do this family-by-family. Do not attempt a single large rewrite across all
classes.

Priority targets:

- [ ] TODO-5: Move likelihood-backed classes (`likelihood_tier` `"full"`/`"partial"`,
   composing the `LikelihoodTests`/`StandardModelCache` components — formerly the
   `InferenceAsympLik` family) to shared core-path diagnostics.
- [ ] TODO-6: Move the `ParametricLikelihoodBootstrap` component (formerly
   `InferenceParamBootstrap`) and bootstrap-calibrated LR paths to shared core-path diagnostics.
- [ ] TODO-7: Move nonparametric bootstrap and Bayesian bootstrap methods to shared core-path diagnostics.
- [ ] TODO-8: Move randomization and jackknife paths to shared core-path diagnostics.
- [ ] TODO-17 (re-homed 2026-08-14 from `m_out_of_n_bootstrap_implementation_spec.md`'s
   Phase 4, which is otherwise complete and moved to `finished_features/`): wire
   m-out-of-n bootstrap and PRW subsampling diagnostics into this spec's public
   debug API once it exists. Both implementations already expose rich
   per-distribution diagnostics via their `debug = TRUE` mode
   (`inference_ext_m_out_of_n_bootstrap.R`, `inference_ext_prw_subsampling.R` —
   resolved size, finite fraction, failure reasons), so this is a wiring task,
   not new instrumentation. Covers `prw_subsampling_implementation_spec.md`'s
   open TODO-14/16/17 as well.
- [ ] TODO-18 (re-homed 2026-08-14, same source): preserve optimizer diagnostics
   for failed m-out-of-n/subsampling refits in debug mode when available —
   depends on this spec's Phase 3 optimizer-diagnostics layer, which is why it
   cannot land in the resampling specs themselves. Covers
   `prw_subsampling_implementation_spec.md`'s open TODO-15 as well.

### Phase 3: Optimizer diagnostics integration

After the optimizer diagnostics layer is implemented:

- [ ] TODO-9: Thread native diagnostics into R fit objects.
- [ ] TODO-10: Store last-fit diagnostics in a consistent private cache.
- [ ] TODO-11: Expose `get_last_fit_diagnostics()` as planned by
   [optimizer_diagnostics_report.md](optimizer_diagnostics_report.md).
- [ ] TODO-12: Have `compute_*_details()` pull from those caches without recomputing.
- [ ] TODO-22 (added 2026-08-24): migrate the temporary
   `InferenceOrdinalStereotypeLogitRegr` and
   `InferenceIncidKKCondLogitOneLik` acceptance guards documented above to the
   centralized typed diagnostic classifier, prove primary/refit behavior
   remains equivalent, then remove the class-local helper methods and their
   component-contract entries.
- [ ] TODO-19 (added 2026-08-18, user decision): enrich
   `EDIInferenceSuiteResults`' per-class `diagnostics` element (see
   `inference_suite_inspect.md → Per-class diagnostics element`;
   `InferenceSuite$run_all_inference()` ships in v1.0.0 with free fields
   only — `converged`, `hit_iteration_cap`, `iterations`, `optimizer`).
   Expand it **additively** from this spec's layers: condition numbers,
   separation flags, per-stage timings, and the curated
   `EDIInferenceDebugResult` fields, pulled from the TODO-10/11 caches
   without recomputation. The element is a named list precisely so this
   expansion never changes its shape or breaks JSON consumers
   (`save_results_as_JSON` output included). v1.1.0 scope, sequenced with
   this Phase 3.
- [ ] TODO-20 (added 2026-08-19): a class that computes an estimate but never
   attempts (or fails to produce) a standard error currently still reports
   `status = "ok"`, so callers can't distinguish "fully computed" from
   "estimate only, `se` missing." Fix by returning the new `status = "no_se"`
   sentinel (estimate present and finite, SE stage not attempted / produced
   no value) instead of `"ok"` in that case. Audit every class that can
   currently return an estimate without a computed `se` to confirm they
   adopt the new status. Depends on the `status` enum rename in this spec
   ("nonestimable" → "no_estimate", this update) landing first so the two
   sentinels are consistent.
- [ ] TODO-21 (added 2026-08-19): `status = "error"` is currently a single
   bucket for every unexpected exception, which is uninformative for callers
   triaging failures. Split it into typed statuses -- `unsupported` (method/
   argument combination deliberately unimplemented), `invalid_argument`
   (caller passed rejected arguments), and `error` as the true catch-all for
   anything else -- using message-pattern classification. Reuse the existing
   `classify_method_error()` logic in
   [run_public_workflow_coverage.R](../../package_tests/run_public_workflow_coverage.R)
   (lines ~318-323) as the starting taxonomy/regexes rather than designing a
   new one from scratch; that function already separates `unsupported` /
   `nonestimable` / `exempted` / `error` for a different (test-coverage)
   purpose, so port the applicable patterns and rename its `nonestimable`
   analogue here to line up with this spec's `no_estimate`/`no_se` statuses.

### Phase 4: Audit/report integration

Use debug results to improve `path_audits.html` and comprehensive tests:

- [ ] TODO-13: Distinguish numeric success, typed non-estimable, and unexpected error.
- [ ] TODO-14: Aggregate `reason` by class/method.
- [ ] TODO-15: Identify dominant failure mechanisms for 0%, <1%, <5%, and <25% cells.
- [ ] TODO-16: Produce a low-estimability hardening report directly from debug output.

This should complement [path_audit_hardening_report.md](../package_tests/path_audit_hardening_report.md).

## Fast-Path Performance Requirements

The following are hard requirements:

1. `compute_estimate()`, `compute_pval()`, and `compute_ci()` must not allocate
   large diagnostic structures.
2. They must not compute QR, eigenvalues, condition numbers, refits, or
   replicate traces solely for diagnostics.
3. They must not call debug wrappers internally.
4. Any shared core must branch before expensive instrumentation.
5. Benchmarks for representative fast paths must show no meaningful regression.

Suggested benchmark targets:

- closed-form/simple mean difference
- OLS
- logistic/probit GLM
- Poisson/count GLM
- one GLMM path
- one bootstrap path

Acceptance threshold: median runtime change on scalar calls should be within
measurement noise, with no systematic allocation increase visible in `Rprofmem`
or comparable tooling.

## Error Handling

Debug methods should catch unexpected errors, classify the exception message
against a stable set of typed patterns, and return:

```r
status = "unsupported" | "invalid_argument" | "error"
value = NA_real_ # or c(NA_real_, NA_real_) for CI
stage = <best known stage>
reason = <typed reason string, e.g. "not_implemented", "invalid_alpha", "unexpected_error">
message = conditionMessage(e)
errors = conditionMessage(e)
```

Classification should reuse the pattern already established by
`classify_method_error()` in
[run_public_workflow_coverage.R](../../package_tests/run_public_workflow_coverage.R)
(message-regex matching into `unsupported` / `nonestimable` / `exempted` /
`error` buckets), rather than inventing a second taxonomy:

- messages matching "not implemented", "must implement", "only supported",
  "not supported", "does not support" → `status = "unsupported"`
- messages matching known invalid-argument patterns (argument name/range
  validation failures raised before any computation starts) → `status =
  "invalid_argument"`
- anything else → `status = "error"` (true catch-all; do not expand this
  list to the point where `"error"` never fires -- an empty catch-all is a
  sign the classifier is silently misclassifying real unexpected failures)

This is a diagnostic API difference from the scalar API. Scalar methods should
keep their current behavior unless a separate API decision changes it.

## Public Documentation

Document that:

- scalar methods are for routine analysis and simulation sweeps
- debug methods are for investigating `NA`, non-estimable output, numerical
  fragility, and audit failures
- debug methods may be slower and may return larger objects
- not every diagnostic field is available for every class
- missing diagnostic fields mean "not collected" or "not applicable", not
  necessarily "no problem"

## Minimal Example

```r
res = inf$compute_pval_details(delta = 0)

res$value
res$status
res$stage
res$reason
res$diagnostics$fit$converged
res$diagnostics$bootstrap$n_finite
```

Example non-estimable output:

```r
list(
  value = NA_real_,
  status = "no_estimate",
  target = "pval",
  method = "lik_ratio_bartlett_approx",
  stage = "se",
  reason = "lik_ratio_bartlett_approx_test_unavailable",
  diagnostics = list(
    full_fit = list(converged = TRUE, iterations = 8),
    null_fit = list(converged = FALSE, diagnostic_category = "separation"),
    bootstrap = list(n_requested = 151, n_finite = 17, min_required = 31)
  )
)
```

## Acceptance Criteria

- `compute_estimate_details()`, `compute_pval_details()`, and
  `compute_ci_details()` exist for all public inference objects.
- Existing scalar methods return exactly the same values as before.
- Debug `value` matches the scalar return for the same arguments.
- Debug objects carry stable `status`, `stage`, and `reason` fields.
- At least one likelihood-backed family includes optimizer diagnostics once the
  optimizer diagnostics layer lands.
- At least one bootstrap path includes finite-count diagnostics.
- Fast-path benchmark shows no meaningful regression.
