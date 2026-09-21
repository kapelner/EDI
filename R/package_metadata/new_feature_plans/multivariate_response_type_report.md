# Multiple Outcome Metrics per Experiment — One `Design`, Many Named Responses

> **Depends on:** the stable scalar `Inference` surface (`fix_inference_hierarchy.md`, DONE 2026-08-23). Stage 0 below is a `Design` refactor and should land before anything else in this plan. (Global ordering: see `_master.md`.)

> **Rewritten 2026-09-20 (owner decision).** The earlier version of this report
> proposed K separate `Design` objects, one per outcome, and claimed "zero
> `Design` changes." That is withdrawn. The architecture is now **one `Design`
> holding several named responses**: covariates, assignment, and design state
> are stored once. The earlier pre-2026-08-14 notes about the completed
> hierarchy/interval-censoring migrations still apply: `InferenceAsympLikStdModCache`
> is the composed `StandardModelCache` component, and the response-entry API is
> `add_one_subject_response(t, y, y_L, y_R)`.

## Why this plan matters

Most real experiments track more than one outcome metric:
- **Clinical trials**: co-primary endpoints, key secondary endpoints, safety
  endpoints beside efficacy.
- **Online / A-B experiments**: one primary metric plus guardrail and
  diagnostic metrics (conversion, revenue, latency, retention, ...).
- **Field and social-science experiments**: several outcome scales or
  behavioral measures per subject.

Today a user must build one `Design` per metric, run each analysis, and
correct for multiplicity by hand (or not at all). Multi-metric experiments
should be a first-class workflow.

## Scope: composite analysis, not joint modeling

Two different features hide under "multivariate support":

1. **Multiple named responses per subject, each analyzed with the existing
   scalar machinery, then combined with a multiplicity rule** — the goal of
   this plan. Responses are independent named vectors; there is no `n × K`
   matrix and no joint covariance.
2. **True joint modeling** (SUR-style regression, multivariate GLM, a joint
   Wald/Hotelling test, joint bootstrap over a response matrix, a vector-valued
   treatment effect with cross-endpoint covariance) — **out of scope; separate
   decision required.** It would need new C++ cores, vector-truth simulation
   machinery, and a cache contract that holds a vector `beta_hat_T`.

Applied practice is dominated by (1): per-endpoint estimates plus a
multiplicity-controlled decision rule. Joint parametric models are rarer
because they are harder to interpret and need larger n to estimate the
cross-endpoint covariance.

## Architecture: one `Design`, many named responses

### Why one `Design` (and not K)

- **Covariates, assignment `w`, and design state (matching, blocks,
  rerandomization draws, sequential allocation history) are stored once**, not
  K times.
- **No drift risk**: K copies of `w`/`X` can silently diverge; one copy cannot.
- **Sequential/adaptive designs are incoherent with K designs**: allocation is
  a single decision as each subject arrives.
- **Shared-`w` randomization inference** (see Stage 2) needs the same draw of
  `w` across all metrics, which is natural in one object.

### Constructor contract

`Design` gains a new argument `response_name_to_types`: a named list mapping
response name (string) => response type (string), e.g.
`list(sbp = "continuous", responder = "incidence", os = "survival")`.

- The existing `response_type` argument is kept for backward compatibility and
  **must be a scalar string**. When used, the single response is stored under
  the internal name `"default"`, equivalent to
  `response_name_to_types = list(default = response_type)`.
- **Supplying both `response_type` and `response_name_to_types` is an error.**
  Supplying neither is an error (today `response_type` is required). A
  `response_type` of length != 1 is an error.
- Validation of `response_name_to_types`: non-empty named list; names
  non-empty, non-`NA`, and unique; every value a single string from the
  existing `assertChoice` set (`continuous`, `incidence`, `proportion`,
  `count`, `survival`, `ordinal`).
- `ordinal_levels` becomes per-response (a named list keyed by response name in
  the multi form; the scalar form keeps working unchanged).

### Internal storage

Responses are kept as a **named list, response name => vector**, replacing the
single-response privates in [design_abstract.R](../EDI/R/design_abstract.R)
(constructor ~L170-223, `add_one_subject_response` ~L255-335,
`add_all_subject_responses` ~L367-417, `get_response_type` ~L822,
`transform_y` ~L872, `assert_y` ~L1008):
- `private$y`, `private$y_L`, `private$y_R`, and the survival censoring
  bookkeeping become named lists keyed by response name.
- `private$response_type` and `private$response_type_original` become named
  character vectors keyed the same way; ordinal-level state is per response.
- The "observed responses == length(w)" completeness checks (~L450, ~L461)
  become **per-response**: a subject may have some responses observed and
  others missing/censored.
- The legacy scalar path is the one-element case `list(default = ...)` and must
  reproduce all existing behavior bit-for-bit.

### Public API consequences

- `add_one_subject_response()` / `add_all_subject_responses()` need to know
  which response they write. Proposed: an optional `response_name` that
  defaults to `"default"` when the design has exactly one response and is
  **required (error if omitted) when there are several**.
- Accessors (`get_y()`, `get_response_type()`, `get_response_type_original()`,
  `transform_y()`, ...) gain `response_name = NULL`: `NULL` resolves to the
  sole response and errors clearly when there are several.
- **`Inference` classes bind to one `(Design, response_name)` pair**
  (constructor argument `response_name = NULL`, same resolution rule). The
  scalar-estimand math (`beta_hat_T`/`s_beta_hat_T` cache,
  `InferenceAsympLikStdModCache`, every concrete class) is unchanged; only data
  access changes.
- **Response-adaptive designs** (KK21 weighting and similar, with
  per-`response_type` branches at
  [design_seq_one_by_one_KK21.R:253-281](../EDI/R/design_seq_one_by_one_KK21.R:253))
  take a `primary_response_name` naming the one response that drives
  allocation; required when there are several responses. Fusing several
  responses into one allocation weight is an unresolved research question and
  is not attempted here.
- `SimulationFramework` dispatches its `transform_cont_y_based_on_response_type()`
  and default-inference-class curation per response name.
- Serialization (`save_load_api.md`) must version the `Design` layout and load
  old single-response objects as `default`.

### Blast radius (measured 2026-09-20; re-run `graft callers` before editing)

- `get_response_type()` is referenced in ~78 files under `R/EDI/R/`; the
  `Design` hierarchy is 36 `design_*.R` files that read the response through
  base-class privates. Inference classes, the simulation framework, save/load,
  print/summary methods, plots, and the Python bindings (if they wrap `Design`)
  are all affected by the accessor changes.
- No C++ change is expected if kernels keep receiving plain numeric vectors
  (the accessor just selects one). Any C++ verification follows the project
  rule: compile only touched `.cpp` files; never a full `R CMD INSTALL` or
  `load_all(compile = TRUE)`.

## Requirements for the composite layer

1. **Mixed response types per metric** via `response_name_to_types`, all
   sharing the one `Design`'s `w` and covariates.
2. **Metric roles and testing hierarchy.** Each metric is labeled
   `primary`/`co-primary`, `secondary`, or `guardrail`, with a decision rule
   per role: Holm or max-p IUT across co-primaries; fixed-sequence or
   gatekeeping for secondaries; non-inferiority for guardrails (a different
   hypothesis, not a multiplicity-adjusted superiority test). One-/two-sided
   alternatives are per metric.
3. **Per-metric estimand and direction.** Each metric reports estimate, CI,
   and p-value on its own scale; never a pooled effect size across
   incomparable scales.
4. **Multiplicity-adjusted intervals** where a valid construction exists, and
   an explicit statement where it does not.
5. **Per-metric missingness and unequal n.** Report per-metric n; never
   silently intersect subjects (see `missing_outcome_handling.md`).
6. **Reporting.** A multi-metric results table (per-metric estimate, CI, raw
   p, adjusted p, decision, role), integrated with
   `multiplicity_adjusted_results_table.md` and
   `inference_suite_interactive_reporting.md`, not a parallel path.
7. **Simulation.** K correlated metrics with mixed response types; power for
   the *family* of decisions (e.g. all co-primaries significant) and
   family-wise type-I error.

## Cross-metric decision rules (Stage 2)

For the K per-metric p-values, three distinct, separately labeled answers:
- **Holm's step-down** (default; FWER control under arbitrary dependence;
  answers "which outcome(s) are significant"). No multiplicity code exists in
  the package today; this is a thin wrapper over `stats::p.adjust()`.
- **Max-p intersection-union test** (opt-in; Berger's IUT; "are ALL K
  significant," for co-primary designs). A one-line `max()`.
- **Cauchy combination** (opt-in; reuses `cct_combine_pvalues()` unchanged on
  the K-vector; "is at least one significant"). A real question (a global
  gatekeeping test) but not what most users want, so it ships as a labeled
  third output, never the default or sole summary.

Proposed, to be validated: because EDI's randomization inference permutes or
redraws `w`, applying the *same* draw across all K metrics preserves their joint
dependence, enabling **Westfall-Young min-p / max-T step-down** FWER control
under the sharp null, typically more powerful than Holm when metrics are
positively correlated. Needs a careful check of the null it controls and its
interaction with the design's own scheme (matching, blocking, rerandomization).

Per-metric representative p-value: by default a full `InferenceSuite` per
response with `combined_evidence$pval` (existing Cauchy combination within the
metric). If the caller pinned a specific `(Inference class, method, action)` for
a metric (pre-registered analysis plan), use that model's raw `pval` instead.

## Estimand question

The ambiguity here is whether there should be one number at all: a global test
(Hotelling/O'Brien-type; evidence somewhere, no CI for a quantity), K
per-endpoint scalar estimates with a multiplicity-adjusted decision rule (best
fit for the scalar-estimand architecture; this plan), or a joint vector effect
with a joint covariance (out of scope).

## Implementation stages

- **Stage 0 — `Design` refactor, no behavior change.** Constructor contract,
  named-list storage, legacy scalar path routed through `list(default = ...)`,
  error tests (both supplied / neither supplied / bad or duplicate names /
  non-scalar `response_type`). The full existing test suite and the
  package_tests wiring/drift/parity gates must pass **unchanged** before
  anything else ships. This is the riskiest step; do it in isolation.
- **Stage 0.5 — multi-response `Design`.** Allow more than one entry;
  per-response entry, missingness, ordinal levels, `transform_y`;
  `response_name` on accessors and `Inference` constructors;
  `primary_response_name` for response-adaptive designs; explicit errors on
  ambiguous access.
- **Stage 1 — per-metric orchestration.** `InferenceMultiEndpointComposite`
  (new R6 class) loops over response names of one `Design` and collects the K
  `(beta_hat_T, s_beta_hat_T, pval)` results.
- **Stage 2 — cross-metric decision rules** (above), plus roles/gatekeeping,
  adjusted intervals, and evaluation of the shared-`w` Westfall-Young rule.
- **Stage 3 — `SimulationFramework`.** Correlated latent signals via a
  multivariate normal draw with a user-specified correlation matrix, then
  `transform_cont_y_based_on_response_type()` per response; K fits per
  replication; per-metric scalar MSE/coverage/power plus family-wise summaries.
- **Stage 4 — true joint modeling: not planned.** Gate on a concrete user need
  for a joint covariance estimate; it would be a second-generation project
  (matrix-valued response storage, SUR-style C++ cores, vector-truth
  simulation).

## What exists today (checked against the code)

- No multiplicity-correction infrastructure anywhere in the package (one
  unrelated docstring mention at
  [simulation_framework_report.R:83](../EDI/R/simulation_framework_report.R:83)).
- Single-response storage in `Design`: `add_one_subject_response(t, y, y_L,
  y_R)` asserts a length-1 numeric `y`; `add_all_subject_responses` sets
  `private$y = as.numeric(ys)`. `response_type` is a fixed `assertChoice` over
  six values.
- `SimulationFramework`'s `betaT` accepts a vector but sweeps scalar effect
  sizes across separate DGP cells; it is not a vector-valued joint effect and
  should not be mistaken for multivariate support.

## Open questions for the owner

1. Entry API: one call per response, or one call carrying all of a subject's
   responses?
2. Is `"default"` reserved (disallowed as a user name in the multi form)?
   Recommendation: yes.
3. Save/load compatibility policy for old single-response objects.
4. Whether `Inference` should also accept a vector of response names and return
   the composite directly, or whether the composite class is always separate.

## Implementation TODOs

- [ ] TODO-1: **Confirm go-ahead to implement.** The owner has flagged this as an important plan (2026-09-20) and chosen the one-`Design` architecture, but has not yet explicitly authorized implementation. Do not start the items below until recorded here.
- [ ] TODO-2: **Stage 0** — `Design` constructor + storage refactor with zero legacy behavior change (see "Implementation stages"). Run `graft callers` on the response accessors first; resolve the open questions above.
- [ ] TODO-3: **Stage 0.5** — multi-response `Design`, `response_name` on accessors/`Inference`, `primary_response_name` for adaptive designs, mixed-type tests.
- [ ] TODO-4: **Stage 1** — `InferenceMultiEndpointComposite` per-metric orchestration (`InferenceSuite` per response or a caller-pinned model's raw `pval`).
- [ ] TODO-5: **Stage 2** — Holm (default), max-p IUT, Cauchy across metrics as three separately labeled answers; metric roles, gatekeeping, non-inferiority guardrails; multiplicity-adjusted intervals; evaluate shared-`w` Westfall-Young.
- [ ] TODO-6: Multi-metric results table integrated with `multiplicity_adjusted_results_table.md` and the interactive reporting plan.
- [ ] TODO-7: **Stage 3** — `SimulationFramework` composite support with family-wise power/type-I-error.
- [ ] TODO-8: Update `save_load_api.md`, roxygen docs, README/vignette examples, and the Python binding surface for the new constructor.
- [ ] TODO-9: Do NOT pursue native joint modeling (matrix response, joint covariance) without a separate decision.
