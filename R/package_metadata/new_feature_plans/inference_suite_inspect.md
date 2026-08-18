# InferenceSuite run_all_inference(): Fit-and-Compare Every Applicable Inference Class

> **Depends on:** nothing blocking implementation start. Discovery
> (`discover_applicable_inference_classes()`) is already metadata-driven
> and stable (Phase 1A closed 2026-08-17), and `run_all_inference()` only
> calls each class's existing `compute_estimate()`/`compute_ci()`/
> `compute_pval()`, which work today regardless of a class's current
> hierarchy shape — `fix_inference_hierarchy.md`'s Phase 1D migrations are
> behavior-preserving (golden-tested against pre-migration output before
> a class is marked `migrated`). **Implementation (TODO-1..8) can proceed
> in parallel with the tail of Phase 1D.** Only **test-fixture lock**
> (TODO-9's full grid, and any snapshot of `likelihood_tier`/optional-method
> columns per class) should wait for Phase 1D to close, since Base
> Deletion there can still shift a class's capability metadata out from
> under a cut fixture. `fix_design_hierarchy.md` (closed 2026-08-17, in
> `../finished_features/`) supplies the design-side capability metadata.
> (Global ordering: see `_master.md` § 1G.)

Written 2026-08-17.

## Purpose

`InferenceSuite` (`R/inference_suite.R`) currently only *discovers* which
`Inference` classes are applicable to a completed `Design` — it never
constructs or fits any of them. A user who wants to know "which estimator
should I actually use, and what do they each say" has to construct and fit
every applicable class by hand, one at a time, and eyeball the results
against each other. There is no standardized way to compare estimate / SE /
CI / p-value across classes, and no single output shape that reads the same
way whether the response is continuous, incidence, count, ordinal, or
survival, or whether the design is plain iid randomization or KK
matched-pair.

This plan adds a `run_all_inference()` method to `InferenceSuite` that constructs and
fits every class in `applicable_design_classes`, and reports one uniform
comparison table across all of them.

## Non-Goals

- Do not change `InferenceSuite$initialize()`'s discovery/validation
  behavior. `run_all_inference()` is new, additive, opt-in (a user must call it
  explicitly — it fits models, unlike the constructor).
- Do not compute every optional method (bootstrap, randomization,
  jackknife, likelihood-ratio) per class. `run_all_inference()` reports each
  class's *primary* CI/p-value method, selected by the Method Selection
  Policy below, not a full diagnostics dump — that is
  `public_diagnostics_api_spec.md`'s job, not this one.
- Do not build a new diagnostics object schema (`EDIInferenceDebugResult`).
  This is a separate, flatter, comparison-oriented schema (decided in
  discussion: a new uniform schema, not a reuse of the debug-object
  contract).
- Do not add plotting, model selection, or a "recommended estimator" verdict
  in the first pass. `run_all_inference()` reports; it does not decide.

## Output Schema

One row per class in `applicable_design_classes`, identical column set
regardless of response type or iid/KK design family:

```r
list(
  inference_class = <character>,   # e.g. "InferenceContinOLS"
  response_type   = <character>,   # from des_obj$get_response_type()
  design_family   = <character>,   # "iid" | "kk_matched_pair"
  likelihood_tier = <character>,   # "none" | "quasi" | "partial" | "full"
  estimate        = <numeric or NA_real_>,
  se              = <numeric or NA_real_>,
  ci_lower        = <numeric or NA_real_>,
  ci_upper        = <numeric or NA_real_>,
  ci_method       = <character or NA_character_>,  # e.g. "wald", "randomization"
  pval            = <numeric or NA_real_>,
  pval_method     = <character or NA_character_>,
  estimand        = <character>,   # what the estimate IS: e.g. "mean_difference",
                                   # "log_odds_ratio", "hazard_ratio" — guards
                                   # against apples-to-oranges comparison of the
                                   # estimate column across classes
  fit_secs        = <numeric>,     # wall-clock seconds for this class's
                                   # construct+fit+summarize
  warnings        = <character or NA_character_>,  # captured R warnings from the
                                   # fit (convergence, separation, etc.),
                                   # collapsed to one string; NA if none
  status          = "ok" | "nonestimable" | "error",
  message         = <character or NA_character_>
)
```

`run_all_inference()` also takes `alpha` (default `0.05`): the CI level
(`1 - alpha`) and the significance threshold used anywhere the report
flags/format significance — not hardwired to 95%.

Below the per-class table, both output modes append an
**unavailable-classes footer** listing
`unavailable_due_to_missing_packages` (class name → missing packages), so
the practitioner can see which estimators an `install.packages()` away.

`design_family` is derived once from `normalize_inference_design_metadata()`'s
existing `is_kk` field (`"kk_matched_pair"` if `TRUE`, else `"iid"`) — no
response-type-conditional columns, no per-family schema branching. This is
the concrete meaning of "standard output for each response type and data
model type" from the brainstorming discussion: one schema, always these
columns, `NA`/`NA_character_` filled in wherever a class doesn't produce that
value (e.g. a `likelihood_tier = "none"` class has no `pval_method` beyond
whatever its default test is; a class with no closed-form SE reports
`se = NA_real_`).

## Method Selection Policy

**Correction (2026-08-18):** there is no existing generic `compute_ci()`/
`compute_pval()` on `Inference` today — that pairing is the *proposed*,
not-yet-built API from `public_diagnostics_api_spec.md`. Concrete classes
instead expose capability-gated, differently-named methods. `ci_method`/
`pval_method` are picked independently by checking `obj$capabilities()`
against this fixed priority order and calling the first available:

| Priority | Capability | CI method | P-value method |
|---|---|---|---|
| 1 | `wald` | `compute_asymp_confidence_interval(alpha)` | `compute_asymp_two_sided_pval(delta = 0)` |
| 2 | `exact_test` | `compute_exact_confidence_interval(alpha)` | `compute_exact_two_sided_pval_for_treatment_effect(delta = 0)` |
| 3 | `randomization_ci` / `randomization_test` | `compute_rand_confidence_interval(alpha)` | `compute_rand_two_sided_pval(delta = 0)` |
| 4 | `nonparametric_bootstrap` | `compute_bootstrap_confidence_interval(alpha)` | `compute_bootstrap_two_sided_pval(delta = 0)` |

CI and p-value each pick independently (a class could have `wald` CI but
lack a `wald`-tier p-value some other way) — `ci_method` and `pval_method`
are not forced to agree. A class with none of these four capabilities
gets `ci_lower = ci_upper = ci_method = NA` / `pval = pval_method = NA`
and `status` stays `"ok"` if `estimate` still computed (a point estimate
without an interval/test is not itself a failure). Bayesian bootstrap,
randomization bootstrap, jackknife, and likelihood-ratio-test methods are
deliberately excluded from this table — they're optional-method territory,
out of scope per the Non-Goals above. This table is intentionally small
and can grow (e.g. a `likelihood_tests`-tier LR p-value) if a future pass
finds classes with no method in it.

## Per-Class Failure Isolation

A single class's construction or fit failure must not abort the whole
report. Wrap each class's construct-and-fit sequence in `tryCatch()`:

- Construction/fit raises a non-estimability condition recognized by the
  package's existing non-estimable-result convention → `status =
  "nonestimable"`, `message` set from the condition, all numeric fields
  `NA`.
- Construction/fit raises any other error → `status = "error"`, `message =
  conditionMessage(e)`, all numeric fields `NA`.
- Success → `status = "ok"`, `message = NA_character_`, numeric fields
  populated from the fitted object.

`inference_params` (already validated by `initialize()`) is forwarded to
each class's constructor exactly as it would be for a manual construction.

## Output Modes: `screen`, `html`

```r
InferenceSuite$run_all_inference(screen = TRUE, html = FALSE)
```

- `screen`: print results to the console **incrementally, in computation
  order** — each class's row is printed as soon as its fit completes, not
  buffered into one table at the end. Below the streamed rows, maintain a
  live progress bar showing **% done and estimated time to complete**,
  following `SimulationFramework`'s existing pattern
  (`.draw_simulation_progress_bars()` / its `.fmt_secs()` ETA formatter and
  `\r`/`\033[2K` stderr redraw discipline in `simulations_framework.R`;
  also the throttled-redraw and "Estimating..." → measured-throughput ETA
  fallback there). Here one bar suffices (classes done / total classes;
  ETA from mean per-class elapsed time so far). Rows print to stdout;
  the bar redraws on stderr below them, cleared before each new row is
  emitted (the `.message_stderr()`-style clear-then-print pattern).
- `html`: render the same table to a self-contained HTML file, written to
  the **current working directory** with a timestamped filename —
  `inference_suite_results_<YYYYMMDD_HHMMSS>.html` — and then opened
  automatically in the user's default browser via `utils::browseURL()`.
- **Constraint: at least one of `screen`/`html` must be `TRUE`.** Both
  `FALSE` is a construction-time argument error (`stop()`), not a silent
  no-op — mirrors the existing `should_run_asserts()`-gated argument
  validation style already used in `InferenceSuite$initialize()`.
- Both may be `TRUE` simultaneously (console print + saved/opened HTML in
  the same call).
## Return Object

`run_all_inference()` returns (invisibly) one structured **list of lists** carrying
every piece of information the call generated — the programmatic
counterpart of the screen/HTML/plot outputs, complete enough to
reconstruct any of them without re-fitting. (Note: this is `run_all_inference()`'s
return, not `InferenceSuite$new()`'s — R6 semantics require `$new()` to
return the constructed object itself; the constructor remains
discovery/validation-only.) S3 class `c("EDIInferenceSuiteResults",
"list")`:

```r
list(
  results = list(          # one entry per applicable class, computation order
    InferenceContinOLS = list(
      inference_class = ..., response_type = ..., design_family = ...,
      likelihood_tier = ..., estimate = ..., se = ...,
      ci_lower = ..., ci_upper = ..., ci_method = ...,
      pval = ..., pval_method = ..., estimand = ...,
      fit_secs = ..., warnings = ..., status = ..., message = ...,
      diagnostics = list(...)   # numerical-fit diagnostics; see below
    ),
    ...                    # every schema field, one sub-list per class
  ),
  results_table = <data.frame>,   # the same rows, flat (what screen/HTML print)
  design = list(                  # snapshot of the design metadata used
    response_type = ..., design_family = ..., design_class = ...,
    n = ..., n_T = ..., n_C = ...
  ),
  alpha = <numeric>,
  unavailable_due_to_missing_packages = <named list>,
  plots = list(estimates = <ggplot or NULL>, ci_forest = <ggplot or NULL>),
  files = list(html = <path or NULL>, pdf = <path or NULL>,
               json = <path or NULL>),   # NULL when that output wasn't requested
  timestamp = <character>,        # the shared YYYYMMDD_HHMMSS artifact stamp
  total_secs = <numeric>,
  edi_version = <character>
)
```

- `save_results_as_JSON` flag (default `FALSE`): serialize the return
  object — minus the `plots` element (ggplot objects don't survive JSON;
  everything else is scalars/vectors/paths) — to a timestamped JSON file
  in the current working directory,
  `inference_suite_results_<YYYYMMDD_HHMMSS>.json` (same shared timestamp
  as the HTML/PDF artifacts). Use `jsonlite` if already a dependency;
  otherwise add to `Suggests` and gate with `requireNamespace()`, same
  rule as `ggplot2`. `NA` fields serialize as JSON `null`.
- The JSON flag is independent of `screen`/`html` — the
  at-least-one-of-`screen`/`html` constraint is unchanged.

### Per-class `diagnostics` element

Each class result carries a `diagnostics` sub-list with numerical-fit
diagnostics. **v1.0.0 scope: free fields only** — values the fit already
produced at no extra cost, read from the optimizer's result (the
`optimizer_diagnostics_report.md` TODO-4 layer that already shipped
pre-1.0):

```r
diagnostics = list(
  converged         = <logical or NA>,   # gradient-norm-based, per TODO-4
  hit_iteration_cap = <logical or NA>,
  iterations        = <integer or NA>,
  optimizer         = <character or NA>  # which algorithm/kernel fit it
)
```

`NA` for classes with no iterative fit (closed-form estimators, exact
tests). No extra QR/eigen/refit work on this path — same "share
orchestration, not instrumentation" rule as
`public_diagnostics_api_spec.md`.

**v1.1.0 expansion point:** this element is deliberately a named list so
the Phase 2 diagnostics chain (`optimizer_diagnostics_report.md` →
`public_diagnostics_api_spec.md`) can enrich it additively — condition
numbers, separation flags, per-stage timings, the curated
`EDIInferenceDebugResult` fields — without changing its shape or breaking
JSON consumers. The expansion is tracked as
`public_diagnostics_api_spec.md → TODO-19` (v1.1.0, Phase 3 there), not
here.

## Visualizations (ggplot2)

Two companion plots, generated with `ggplot2` from the same result
data.frame (only `status == "ok"` rows; classes on the y-axis, sorted by
estimate; consistent theming across both). An earlier draft had a third
standalone log10 p-value number line; it was merged into the forest plot
(user decision, 2026-08-17) — its information survives as per-row printed
p-values plus significance-driven segment styling.

1. **Estimate number line** — every class's point estimate on one shared
   horizontal axis (`geom_point`), with:
   - each dot labeled **above it at a 45° angle** with the class name and
     its estimate method (`geom_text(angle = 45, hjust = 0)` or
     `ggrepel`-style nudging if labels collide — decide during
     implementation; the 45° angle is the requested default),
   - a **box-and-whisker plot of the estimate values underneath** the
     number line (same x-axis, compressed y-band below the dots), giving
     an at-a-glance summary of the spread/consensus of estimates across
     classes and flagging outlier estimators.
   Facet by `estimand` so estimates on different scales are never drawn
   on one shared axis (the boxplot is per-facet too — a spread summary
   across mixed scales would be meaningless).
2. **Annotated CI forest plot** (merges the former p-value and CI plots)
   — every class's `(1 - alpha)`-level `[ci_lower, ci_upper]` as a
   horizontal segment with a point at the estimate, and per row:
   - the **p-value printed to the left** of the CI segment (scientific
     notation below ~1e-4, so tiny p-values stay readable),
   - the **CI width printed to the right** of the segment,
   - the **class name and its ci/pval method underneath** the segment
     (two-line label under the line rather than a y-axis label — long
     class names like `InferenceSurvivalKKGEEWeibull` don't fit an axis),
   - segment styling (color/alpha) keyed to significance at the user's
     `alpha`, so the which-classes-reject scan the old log10 plot
     provided survives the merge visually, not just as printed text.
   A vertical reference line sits at the null value for the panel's
   scale (zero on additive scales, 1 — or log-scale zero — on ratio
   scales), with the same per-`estimand` faceting rule as plot 1 (CI
   widths aren't comparable across scales either). The title/subtitle
   states the level explicitly (e.g. "95% confidence intervals" for
   `alpha = 0.05`) — the intervals plotted are the same `alpha`-driven
   ones in the table, never hardwired 95%. Row height scales with the
   number of classes (each row is ~3 text lines tall); the PDF page
   grows vertically with class count rather than shrinking text. Same per-`estimand` faceting rule as
   plot 1 (zero is only meaningful on additive scales; on ratio scales the
   reference line is at the null value for that scale, e.g. 1 — or the
   log-scale zero if estimates are reported on the log scale).

Wiring:

- `plots` flag (default `TRUE` when `screen = TRUE`): display the two
  plots on the current graphics device after the table completes.
- `pdf` flag (default `FALSE`): save the two plots to a single
  timestamped multi-page PDF in the current working directory —
  `inference_suite_results_plots_<YYYYMMDD_HHMMSS>.pdf` (same timestamp
  string as the HTML file when both are requested in one call, so the
  artifacts pair up).
- When `html = TRUE`, embed the same two plots into the HTML report as
  base64-inlined PNGs (keeps the HTML self-contained/offline, per the
  no-external-assets rule).
- `ggplot2` dependency: check `DESCRIPTION` — if not already an Import,
  add it to `Suggests` and gate the plot paths on
  `requireNamespace("ggplot2")` with a clear error, consistent with how
  the package treats other optional packages.
- The plot objects are also returned in the result's `plots` element (see
  Return Object above) so users can restyle them.

## Combined Evidence Metric (Cauchy Combination) — added 2026-08-18

### Motivation

Every row in the comparison table answers "is there evidence of a treatment
effect *under this specific model*" — a different question per row, since
each `Inference*` class's null hypothesis is a different functional of the
same underlying potential-outcome distributions (mean difference = 0, OLS
coefficient = 0, a given quantile's shift = 0, log-odds ratio = 0, hazard
ratio = 1, AFT location shift = 0, ...). A practitioner comparing 15-30
`pval` values by eye has no single number to answer the coarser question
"how much evidence is there for *a* treatment effect, in any respect."
`run_all_inference()` should compute and report one.

The p-values across rows cannot be combined with classical methods (Fisher's,
Stouffer's) for two independent reasons, both already true of this table:

1. **They are statistically dependent** — every class is fit on the same
   trial data, so their p-values are correlated in an unknown, unestimated
   way (classical combination methods assume independence and are invalid
   under dependence they don't account for).
2. **They test different null hypotheses**, not the same null estimated
   multiple ways.

(2) is not actually an obstacle once framed correctly: each class's null
`H0_i` (mean diff = 0, OR = 1, HR = 1, ...) is implied by — i.e. is a
necessary consequence of — the single **sharp null** of no treatment effect
whatsoever (Fisher's sharp null: treatment changes nothing for any unit). So
the sharp null is contained in the *intersection* of every row's null:
`H0_sharp ⊆ H0_1 ∩ H0_2 ∩ ... ∩ H0_k`. Testing that intersection null is a
**union-intersection test**: reject "no treatment effect in any respect" as
soon as *any single* class rejects its own (weaker) null — you need only one
strong signal, not consensus across all of them. This is the same logic
`InferenceSuite`'s existing Madigan-et-al. motivation (§3.5b of
`JSS_paper_research_plan.md`) already leans on: the suite's job is to make
"here is every legitimate way to look for an effect, combined honestly" the
default output, not "here is the one method I liked."

### Method: Cauchy Combination Test (CCT)

Use the Cauchy combination test (Liu, Y. and Xie, J. (2020), "Cauchy
combination test: a powerful test with analytic p-value calculation under
arbitrary dependency structures," *Journal of the American Statistical
Association*, 115(529), 393-402): given p-values `p_1, ..., p_k` (one per
`status == "ok"` class with a non-`NA` `pval`) and weights `w_1, ..., w_k`
summing to 1,

```
T = sum_i w_i * tan((0.5 - p_i) * pi)
combined_pval = 0.5 - atan(T) / pi        # for a single combined statistic
```

Its defining property, and the reason it is the right tool here rather than
Fisher's/Stouffer's/minP: **the combined p-value is asymptotically valid
under arbitrary and unknown dependence** among the `p_i` — no covariance
matrix to estimate, no resampling to calibrate it. It is also a natural fit
for a union-intersection test: CCT is a smooth, closed-form approximation to
a min-p test (heavily weighted toward the smallest `p_i`), so one strong
signal among many weak/null ones still drives the combined p-value down,
matching the "only one class needs to reject" logic above.

**Interpretation caveat — state this in the roxygen and any paper text
(cross-ref `JSS_paper_research_plan.md` §4 item 7), do not let it be
read as more than it is:** `combined_pval` is evidence for *"a treatment
effect exists, in at least one of these senses"*, not evidence for any
specific estimate or direction. A design where the effect is concentrated in
one quantile of the outcome (only `InferenceContinKKQuantileRegrIVWC`
rejects) will legitimately produce a small `combined_pval` even though the
mean-based rows show nothing — this is correct union-intersection behavior,
not a bug, but it must be described accurately: "evidence of an effect
somewhere in this model family," not "the treatment effect is real and
looks like X."

**Scope boundary — why this is safe by construction, not just by
convention (added 2026-08-18):** the intersection-null argument above only
holds when every combined class is a test about the *same* outcome
variable `Y` — combining, say, a Cox model's p-value (does treatment affect
time-to-event) with a Gamma model's p-value (does treatment affect cost)
would **not** be valid, since a real effect on one with zero effect on the
other is entirely plausible and there is no single sharp null forcing both
to hold simultaneously. `run_all_inference()` cannot accidentally do this:
`response_type` is a required constructor argument to `Design*$new()`
(`design_abstract.R:170,189`), stored once into `private$response_type`
at `initialize()` with no setter — only the read-only
`get_response_type()` accessor (`design_abstract.R:802`). `InferenceSuite`
is constructed from one `Design` object and reads `get_response_type()`
once to drive `discover_applicable_inference_classes()`
(`inference_suite.R`) — every class in `applicable_design_classes`, and
therefore every row `run_all_inference()` fits and combines, is
necessarily a test about that one fixed `Y`. There is no code path in this
class that lets one `run_all_inference()` call span two response types. The
one way to violate the same-`Y` assumption is manually combining raw
`pval`s from two separate `InferenceSuite` objects' `results_table`s
outside `cct_combine_pvalues()` — worth one explicit sentence in the
roxygen (folded into TODO-19) precisely because the architecture prevents
it internally but can't stop a user from doing that by hand externally.

### Weighting — open design question, not yet decided

Equal weighting (`w_i = 1/k`) is the CCT default and is fine when every row
tests a genuinely distinct estimand. But several rows in the same table can
test near-identical questions with correlated methods within one response
family (e.g. `InferenceContinOLS` and `InferenceContinKKOLSIVWC` both target
"is the mean/regression-adjusted difference zero" for a continuous outcome;
several ordinal-family classes overlap similarly). Equal-weighting a table
with, say, 5 near-redundant continuous-mean methods and 1 lone quantile
method would let the mean-difference *family* dominate the combined
statistic by sheer count, which contradicts the "each distinct sense of
'effect' should get a fair say" motivation above. Two candidate resolutions,
to be decided during implementation (flag to user, don't silently pick one):

- **(a) Equal weight per class, unconditionally** — simplest, matches CCT's
  standard usage, but has the redundancy problem above.
- **(b) Two-stage combination** — group rows by `estimand`
  (`JSS_paper_research_plan.md` §3.5b's own `estimand` column already exists
  in the schema for exactly this kind of grouping question), CCT-combine
  within each `estimand` group first, then CCT-combine the resulting
  per-estimand p-values with equal weight across groups. This treats "the
  mean-difference family says X" and "the quantile family says Y" as two
  votes regardless of how many classes happen to implement each, which is
  more defensible but adds a grouping step that needs its own edge-case
  handling (singleton groups, `estimand = NA_character_` classes).

**Does the same grouping problem also apply *across models*, not just across
methods of the same model — e.g. for incidence: logit vs. probit vs.
log-binomial vs. modified Poisson vs. conditional logit (KK) each fit a
different model to the same "does treatment affect P(Y=1)" question?**
Answered 2026-08-18: mechanically, no separate model-level grouping step is
needed — model choice and method choice both already reduce to the same
`estimand` field. Two models are only ever a redundancy risk for the
weighting scheme if they report the **same** `estimand` (e.g.
`InferenceIncidLogBinomial` and `InferenceIncidModifiedPoisson` both target
`"RR"`, so policy (b) already down-weights them together as one group,
correctly). Models on genuinely different scales (`logit`'s log-odds-ratio
vs. `probit`'s probit-index vs. `"RD"` risk-difference estimators) are
already different `estimand` values and so are already treated as separate,
equally-weighted questions under policy (b) — no third grouping layer
required. **What this does require, and is not yet verified:** that every
incidence-family class's `get_estimand_type()`/`estimand` tag is fine-grained
enough to actually distinguish "different scientific question" from
"different link function answering the same practical question." Grep
(2026-08-18) confirms `get_estimand_type()` currently only returns `"RD"`/
`"RR"` in the g-computation classes (`inference_incidence_gcomp*.R`) — the
non-gcomp classes (`InferenceIncidLogit`, `InferenceIncidProbit`, etc.)
have not yet been audited for what `estimand` they report. **New TODO
needed (see TODO-15a below): audit `estimand` tagging across every
response-type family before shipping policy (b)**, since an under-specified
or missing `estimand` tag would silently misgroup models policy (b) is
supposed to treat as distinct.

**Should models be weighted by fit quality — e.g. AIC?** No — rejected,
not an open question. Two independent reasons:

1. **It would break CCT's validity.** The null-calibration guarantee (T is
   approximately Cauchy regardless of unknown dependence) requires weights
   fixed *before* seeing the fitted p-values — i.e. a function of metadata
   known in advance (which `estimand` a class targets), not a function of
   the fit itself. AIC is computed from the same fit that produces the
   p-value, so an AIC-derived weight is a data-dependent weight; using it
   directly is not covered by Liu & Xie's (2020) validity proof and could
   inflate the false-positive rate in ways this plan cannot currently
   quantify.
2. **Even if it were statistically valid, it reintroduces the exact problem
   `InferenceSuite` exists to prevent** (§3.5b of
   `JSS_paper_research_plan.md`, the Madigan et al. 2013 framing): a
   procedure that automatically up-weights whichever model happens to fit
   best is functionally the same move as a researcher manually picking the
   best-fitting model and reporting mostly its p-value — just laundered
   through an algorithm instead of a human. `InferenceSuite`'s whole point
   is that every legitimate analytic choice gets an equal, transparent say
   *regardless* of which one the data happen to flatter. AIC also measures
   overall model fit (including the baseline covariate relationship), which
   is not the same question as "how much power does this analysis have for
   the treatment effect specifically" — a model can have excellent AIC from
   good covariate fit while being uninformative about treatment, or vice
   versa.

**User control, not a package-decided default (added 2026-08-18, per user
request):** rather than the package silently picking between (a)/(b)/a
future option, `run_all_inference()` takes explicit weighting arguments so
the user has the final say — see TODO-15 below for the parameter shapes.
The package still ships a documented default (policy (b), pending the
`estimand`-audit TODO-15a), but a user who disagrees with the grouping (or
wants to exclude a model family from the combination entirely, or supply
their own prior-informed weights) can override it without patching the
package.

### Output wiring

- New `combined_evidence` element on the `EDIInferenceSuiteResults` return
  object: `list(pval = <numeric or NA>, stat = <numeric or NA>, method =
  "cauchy_combination", n_classes_used = <integer>, weighting =
  <character>, weights_used = <named numeric vector, class -> weight>,
  classes_used = <character vector>)`. `weighting` records which policy was
  actually applied for this call (`"equal"` / `"estimand_grouped"` /
  `"custom"` — see TODO-15) and `weights_used` records the exact per-class
  weight vector, so a saved/JSON result is self-documenting about how its
  own combined p-value was built, not just that one was built. `NA` when
  fewer than 2
  `status == "ok"` classes have a non-`NA` `pval` (a "combination" of one
  p-value is just that p-value, not a meaningful combined-evidence claim —
  degenerate case, document explicitly rather than silently returning the
  single p-value as if it were combined).
- `screen` and `html` outputs print one summary line beneath the per-class
  table: `"Combined evidence (Cauchy combination, k = <n> classes): p =
  <value>"`.
- Independent of, and additive to, `save_results_as_JSON` (TODO-7b) — the
  new element serializes like every other scalar field.

## Implementation Notes

- Reuse `discover_applicable_inference_classes()`/
  `normalize_inference_design_metadata()` already in `inference_suite.R` —
  do not duplicate discovery logic.
- HTML rendering: a minimal `knitr::kable(..., format = "html")` (or
  equivalent already-a-dependency table-to-HTML helper — check
  `DESCRIPTION` before adding a new dependency) wrapped in a tiny static
  HTML shell. No JS, no external assets — must render standalone offline.
- Writing to the current working directory (not `tempdir()`) is a
  deliberate, user-visible side effect; document it prominently in
  `run_all_inference()`'s roxygen so it isn't a surprise mid-session.
- `utils::browseURL()` is base/recommended-package machinery; no new
  dependency.

## Implementation TODOs

Implementation started 2026-08-18 (user decision to begin ahead of Phase 1D
closing — see the amended `Depends on` header above); TODO-1..3 and 6/7b
(minus the unavailable-classes footer and the diagnostics enrichment, which
is out of v1.0.0 scope per its own note) landed in `inference_suite.R`,
smoke-tested end to end with `pkgload::load_all(compile = FALSE)` against a
live `DesignFixedBernoulli`/continuous fixture (7 applicable classes, all
`status = "ok"`, correct `se`/`ci`/`pval` values via the Method Selection
Policy table, JSON round-trip verified, and per-class failure isolation
verified by forcing one class to error — the other 6 rows stayed `"ok"`).

- [x] TODO-1: Add `run_all_inference(screen = TRUE, html = FALSE, alpha =
  0.05, save_results_as_JSON = FALSE)` to `InferenceSuite` in
  `inference_suite.R`; validates `screen || html` at entry (`assertFlag`/
  `assertNumber` gated by `should_run_asserts()`, matching
  `initialize()`'s existing validation style).
- [x] TODO-2: Per-class construct-fit-summarize loop
  (`run_all_inference_one_class()`) with `tryCatch()`/
  `withCallingHandlers()` isolation — a construction/fit error yields
  `status = "error"`; `is_nonestimable("any")` yields `status =
  "nonestimable"`; captured `warning()`s collapse into the `warnings`
  column. Verified: one class forced to error does not affect the other
  rows.
- [x] TODO-3: `design_family` normalization (`"iid"` vs.
  `"kk_matched_pair"`) from `normalize_inference_design_metadata()`'s
  existing `is_kk` field.
- [x] TODO-4: `screen` output streams one row per completed class
  (`cat()`, computation order), with a %-done/ETA progress-bar line
  underneath each row (`run_all_inference_progress_bar_line()` — bar
  rendering and `run_all_inference_fmt_secs()`'s duration formatting reuse
  `simulations_framework.R`'s `.draw_simulation_progress_bars()`/
  `.fmt_secs()` conventions; ETA = mean per-class elapsed time so far ×
  classes remaining). **Deliberate deviation from that precedent:** since
  `run_all_inference()` only updates once per completed class (not many
  times per second like `SimulationFramework`'s task-level bar), each bar
  redraw prints as a fresh line under its row rather than an in-place
  `\r`-overwrite — avoids an interleaving hazard between the row's stdout
  write and an in-place-redrawing bar, and reads fine at this update
  cadence. Verified visually against a live fixture.
- [x] TODO-5: `html` output implemented
  (`run_all_inference_render_html()`): self-contained HTML (inline `<style>`,
  no JS, no external assets — `knitr::kable(format = "html")`, gated behind
  `requireNamespace("knitr")`, an already-Suggested dependency, wrapped in
  a small static shell), written to a timestamped CWD file
  (`inference_suite_results_<YYYYMMDD_HHMMSS>.html`), auto-opened via
  `utils::browseURL()`. Verified: standalone rendering inspected directly
  (valid table + footer, no external references), and `browseURL()`'s call
  intercepted via `options(browser = ...)` in the test rather than actually
  spawning a browser. Plot embedding landed with TODO-7 (base64 PNGs,
  verified 2 images embedded with no external references).
- [x] TODO-6: `estimand` (best-effort via a class's private
  `get_estimand_type()` when declared, `NA_character_` otherwise — see the
  "Correction" note added to the Method Selection Policy section),
  `fit_secs`, `warnings` capture, `alpha`, and the unavailable-classes
  footer (`run_all_inference_unavailable_footer_lines()`) — implemented in
  **both** `screen` and `html` output, verified.
- [x] TODO-7: Both ggplot2 visualizations implemented
  (`run_all_inference_plot_estimates()`, `run_all_inference_plot_ci_forest()`)
  plus `run_all_inference_build_plots()` wiring, the `plots` (default
  `= screen`) and `pdf` (default `FALSE`) parameters on `run_all_inference()`,
  timestamped multi-page PDF output (`run_all_inference_save_plots_pdf()` —
  both pages share one page height, scaled to the CI-forest row count, since
  a single `pdf()` device can't vary page size mid-stream without truncating
  already-written pages), and base64-PNG embedding into the HTML report
  (`run_all_inference_plot_to_base64_png()`, via `jsonlite::base64_enc()`).
  `ggplot2` and `jsonlite` added to `DESCRIPTION` `Suggests` (both were
  previously undeclared — `jsonlite` was already used by TODO-7b's
  `save_results_as_JSON` without being declared, an oversight now fixed).
  **Per user decision:** if `ggplot2` (or, for JSON, `jsonlite`) is not
  installed, `run_all_inference()` issues a `warning()` and skips that
  output rather than erroring — verified for the `ggplot2` path by
  inspection (structurally identical to the already-exercised
  `save_results_as_JSON` warn-and-skip branch; runtime-mocking the locked
  package namespace to force the branch wasn't worth the fragility).
  Verified end-to-end with `plots = TRUE, pdf = TRUE, html = TRUE,
  save_results_as_JSON = TRUE` together: real `ggplot` objects returned,
  a genuine 2-page PDF (`pdfinfo` confirmed), 2 base64 images embedded in
  the HTML with no external references, and the rendered PNGs visually
  inspected. One real bug found and fixed in that inspection: the
  estimates plot's 45°-angled labels were clipped by the panel edge for
  points near the axis boundary; fixed with `coord_cartesian(clip =
  "off")`, asymmetric `scale_x_continuous()` expansion, and a wider
  `plot.margin`. Remaining known limitation, as documented in the code:
  labels for estimates clustered close together still visually overlap
  (no `ggrepel` dependency added in this pass).
- [x] TODO-7b: `EDIInferenceSuiteResults` return object (`results`,
  `results_table`, `design`, `alpha`, `unavailable_due_to_missing_packages`,
  `plots` (populated by TODO-7, `NULL` when not requested or `ggplot2` is
  unavailable), `files`,
  `timestamp`, `total_secs`, `edi_version`), plus `save_results_as_JSON`
  (`jsonlite::write_json()`, gated behind `requireNamespace()`, written to
  a timestamped CWD file, `plots` excluded, `NA` → JSON `null`) — round-trip
  verified. The per-class `diagnostics` element is present with the
  documented shape but every field is currently a hardcoded `NA`
  placeholder (there is genuinely no generic native-diagnostics accessor
  on `Inference` yet, confirmed by grep — `public_diagnostics_api_spec.md`'s
  TODO-9..12 is real future work, not something this feature can shortcut);
  wiring real values in is `public_diagnostics_api_spec.md → TODO-19`.
- [x] TODO-8 (partial): `run_all_inference()`'s roxygen (`@param` for
  `screen`/`html`/`alpha`/`save_results_as_JSON`/`plots`/`pdf`, the
  CWD-write side effects, the `screen`/`html` constraint, `@return`'s full
  schema) is complete; every new internal helper function carries
  `@keywords internal @noRd`; the `InferenceSuite` class-level doc's stale
  "does not itself compute any estimates..." claim is fixed to describe
  `run_all_inference()`, and its `@examples` block now includes a
  `run_all_inference()` call. **Real bug found and fixed during this
  pass:** an earlier edit had spliced all of TODO-1..7's new top-level
  helper functions (and their own `@keywords internal`/`@noRd` roxygen
  blocks) in between the `InferenceSuite` class's roxygen doc block (with
  `@export`/`@examples`) and the `InferenceSuite = R6::R6Class(...)`
  statement it documents -- since roxygen2 attaches a contiguous run of
  `#'` lines to whichever code statement follows immediately, the merged
  block would have attached to `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`
  instead (mixing `@export` with `@keywords internal`/`@noRd` in one
  invalid block), leaving `InferenceSuite` itself undocumented. Fixed by
  moving the whole inserted helper-function block to before the class doc
  (matching the file's existing convention of helpers-before-class).
  Verified via `parse()` and `roxygen2::parse_file()` (static parsing,
  doesn't load the package) -- 24 clean, non-overlapping blocks, zero
  blocks mixing `@export` with `@keywords internal`/`@noRd`.
  **Not done: actually regenerating Rd/NAMESPACE**
  (`roxygen2::roxygenize()`/`devtools::document()`), because that requires
  successfully loading the package first, and `pkgload::load_all()`
  currently fails on an unrelated private-component collision in
  `contracts_mixins.R`/`inference_incidence_KK_marginal.R` (not caused by
  this feature -- flagged to the user, left untouched per the project's
  no-unrequested-fixes rule for other people's in-progress work). Rerun
  the regen step once that's resolved.
- [x] TODO-9 (working/scratch subset — NOT the full grid, per this file's
  own gating; see the "Not done" note below):
  `test-inference-suite-run-all-inference.R` added. Covers the full
  **design-class** axis (BCRD, blocking, KK14 matched-pair, greedy,
  D-optimal — the latter `skip_if_not_installed`-gated on
  `ompr`/`ompr.roi`/`ROI.plugin.glpk`) but only two response types
  (continuous, incidence), using a shared
  `expect_valid_run_all_inference_report()` helper that asserts only
  **structure** (exact schema column names, `design_family` labeling,
  return-object shape, `diagnostics` sub-list shape, "at least one
  `status == 'ok'` row") — deliberately never a specific class's specific
  capability/value, so the suite is resilient to Phase 1D churn rather
  than needing to wait for it. Also covers: per-class failure isolation
  (a deliberately-broken class still yields a full report, verified via a
  real regression test rather than only ad hoc dev-session checks); the
  `screen`/`html` both-`FALSE` error; the HTML file gets written and is
  valid self-contained HTML (`<!DOCTYPE html>`, no `<script>`, no
  `http(s)://`); the PDF gets written and genuinely has at least one
  `/Type /Page` object (checked via `grepRaw()` directly on the file's
  raw bytes — avoids both a `pdftools`/`pdfinfo` test dependency and the
  encoding errors `rawToChar()` throws on a PDF's binary byte stream);
  `plots = TRUE` builds real `ggplot` objects (`skip_if_not_installed`
  on `ggplot2`); `save_results_as_JSON = TRUE` round-trips via
  `jsonlite::fromJSON()`. All file-writing tests isolate to a `tempfile()`
  directory (`setwd()` + `on.exit()` restore, not `withr` — no test file
  in this package uses `withr`, so this one doesn't introduce it either)
  and a null graphics device where plots are built, so nothing leaks into
  the repo working directory. **219 assertions, all passing, zero stray
  files after the run** (verified via `git status` before/after).

  Two real bugs found and fixed while writing and *actually running*
  these tests (not just reading the code):
  1. The shared test helper didn't pass `plots = FALSE`, and since
     `plots` defaults to `screen` (`TRUE` in every structural test),
     nearly every test was silently building *and printing* ggplots with
     no graphics device open — under `Rscript` that triggers R's default
     batch behavior of opening `Rplots.pdf` in the working directory.
     Same class of CWD-pollution risk the plan itself warns about for
     `html`/`pdf`, just via an untested code path. Fixed by passing
     `plots = FALSE` explicitly in every structural test.
  2. The per-class-failure-isolation test defined its throwing test
     double as a local variable inside the `test_that()` block.
     `run_all_inference_one_class()` looks classes up via
     `get(cls_name, envir = getNamespace("EDI"))` (the same pattern
     `InferenceSuite$initialize()`'s `inference_params` validation
     already uses) — that search chain reaches `.GlobalEnv` but not a
     `test_that()` block's own local closure, so the lookup silently hit
     "object not found" instead of the constructor's `stop()`, and the
     test failed on the wrong assertion. A quick manual `Rscript -e`
     reproduction of the same logic had passed, misleadingly, only
     because top-level `Rscript` code executes directly in `.GlobalEnv`.
     Fixed by explicitly `assign()`-ing the test double into
     `.GlobalEnv` with an `on.exit()` cleanup, matching how a real
     extension class would actually be reachable.

  **Not done:** the full grid (every response type × {iid, KK} × every
  design class) with tighter, class-specific assertions — still
  correctly gated on Phase 1D closing, per this file's `Depends on`
  header and `_master.md` § 1G. Extend this file (or add
  response-type-specific fixtures) once that lands.

### Practitioner Follow-Ups (added 2026-08-18)

Gaps identified after the initial implementation landed; not required for
the v1.0.0 slice already shipped, but real usability holes worth closing
before/around the same release:

- [x] TODO-10: `print.EDIInferenceSuiteResults()` (renders the same table
  `screen` prints, prefixed with a one-line design summary) and
  `summary.EDIInferenceSuiteResults()`/`print.summary.EDIInferenceSuiteResults()`
  (counts by `status`, including the new `"timeout"` value from TODO-12;
  the estimate range across `status == "ok"` rows; how many reject at
  `alpha`) implemented in `inference_suite.R`. **Required a NAMESPACE
  change to actually dispatch:** an initial assumption that
  `pkgload::load_all()` auto-registers S3 methods for un-exported-but-
  correctly-named functions turned out to be wrong (empirically verified
  — `print(res)`/`summary(res)` fell through to the base list/default
  methods despite `getS3method()` finding the functions by name). Since
  `roxygen2::roxygenize()`/`devtools::document()` call
  `pkgload::load_all()` internally with `compile = NA` (confirmed via
  `args(pkgload::load_all)`), not `compile = FALSE`, running them would
  violate the project's no-full-rebuild rule regardless of the current
  tree's load state — so instead of regenerating `NAMESPACE`, three
  `S3method()` lines (exactly what `roxygenize()` would generate from the
  `@export` tags already in the source) were hand-added to `NAMESPACE`.
  This is a plain-text metadata edit, not a build/compile action, and
  will be reproduced identically whenever a real `document()` pass
  eventually runs. Verified end-to-end: both methods dispatch correctly
  via plain `print(res)`/`summary(res)`, with a dedicated regression test.
- [x] TODO-11: `classes`/`exclude_classes` arguments on `run_all_inference()`
  — `classes` restricts to just the named applicable classes (`NULL` =
  all), `exclude_classes` removes named classes after that, both
  validated as a subset of `applicable_design_classes` with the same
  named-unknowns error style as `initialize()`'s `inference_params`
  validation. Verified: allow-list produces exactly the requested rows,
  deny-list removes exactly the excluded one, and both error correctly on
  an unknown name.
- [x] TODO-12: `max_secs_per_class` timeout via `setTimeLimit(elapsed =
  ..., transient = TRUE)` (reset via `on.exit()` so the limit never leaks
  past one class's fit), yielding a new `status = "timeout"` value
  alongside `"ok"`/`"nonestimable"`/`"error"`. **Verified it actually
  interrupts a genuinely slow fit, not just a fast one that happens to
  finish before a check**: a deliberately slow R-level test-double class
  (a 5-second busy-loop) was cut off at ~1.5s when given
  `max_secs_per_class = 1`, both in manual verification and as a
  committed regression test. Documented, real limitation carried into the
  roxygen and the plan: `setTimeLimit()` is checked at R-level interrupt
  points, so this reliably cuts off slow *R-level* work (many
  bootstrap/randomization replicates, each its own R-level call) but is
  not guaranteed to interrupt one very slow single native (C/C++/BLAS)
  call with no intervening R-level check — not tested against a real
  native-bound case, since that would require deliberately hanging a real
  kernel.
- [x] TODO-13: `num_cores` argument, using `parallel::makeForkCluster()`/
  `clusterApply()` (Unix/Linux only, matching `SimulationFramework`'s own
  fork-cluster idiom exactly — no `clusterExport()` needed, since forked
  workers inherit the master's memory via copy-on-write) with a
  `warning()`-and-sequential-fallback on other platforms (no `mirai`
  backend added — that's `SimulationFramework`'s much larger Windows
  fallback machinery, not justified for this feature). **Screen-output
  decision, made explicitly rather than left to degrade silently:** under
  `num_cores > 1`, `clusterApply()` is one blocking call that only
  returns once every worker has finished, so there is no meaningful
  per-class ETA while running — `screen = TRUE` instead prints a
  "fitting N classes across K workers" message up front, then every
  result row together once complete (via a new shared
  `run_all_inference_print_row()` helper, so sequential and parallel
  output rows are byte-identical in format), then one
  total-elapsed-time summary line. `num_cores = 1` (default) keeps the
  exact TODO-4 incremental-streaming behavior unchanged. Verified:
  parallel and sequential runs against the same design produce identical
  `results_table` rows (`fit_secs` excepted), via a committed regression
  test comparing both.

### Combined Evidence Metric (added 2026-08-18)

- [ ] TODO-14: Implement `cct_combine_pvalues(pvals, weights = NULL)` helper
  (`@keywords internal @noRd`, alongside the other `run_all_inference_*`
  helpers): the `T = sum(w_i * tan((0.5 - p_i) * pi))` /
  `combined_pval = 0.5 - atan(T) / pi` formula from Liu & Xie (2020).
  Defaults to equal weights when `weights = NULL`. Cite Liu & Xie (2020) in
  the roxygen `@references`.
- [ ] TODO-15: **User-facing weighting arguments on `run_all_inference()` —
  the user decides, the package does not silently pick a policy** (revised
  2026-08-18, per user request: weighting must be an argument the caller
  controls, not a hardcoded internal choice). Add:

  ```r
  run_all_inference(
    ...,
    combined_evidence_weighting = c("estimand_grouped", "equal", "custom"),
    combined_evidence_weights   = NULL
  )
  ```

  - `combined_evidence_weighting = "estimand_grouped"` (**default**):
    policy (b) below — group by `estimand`, `w_i = 1 / (G * m_i)`.
  - `combined_evidence_weighting = "equal"`: policy (a) — flat `w_i =
    1/k` over usable classes, no grouping.
  - `combined_evidence_weighting = "custom"`: the user supplies
    `combined_evidence_weights`, a **named numeric vector** (`inference_class
    name -> weight`, e.g. `c(InferenceIncidLogit = 2, InferenceIncidProbit =
    0.5, ...)`) covering some or all usable classes. Validate the same way
    TODO-11's `classes` argument validates against
    `applicable_design_classes` (names must be a subset of the classes
    that actually produced a usable `pval` for this fit; unnamed/omitted
    classes default to weight `0`, i.e. excluded from the combination, not
    an error — matches the "weight 0 = exclude" note under "Weighting"
    above). Weights need not pre-sum to 1; `cct_combine_pvalues()`
    (TODO-14) renormalizes internally. Reject (argument-time `stop()`, same
    style as `initialize()`'s validation) any custom weight that is
    negative, `NA`, or named for a class not present in the current fit —
    fail loud rather than silently dropping a typo'd class name.
  - Whichever policy is used, the resulting per-class weight vector is
    recorded verbatim in the return object's `combined_evidence$weights_used`
    (see "Output wiring" above) so a saved result is self-documenting.
  - This argument set replaces the earlier "package picks (a) or (b), TBD"
    framing — the package still ships a documented default
    (`"estimand_grouped"`) so a user who calls `run_all_inference()` with no
    opinion on weighting still gets a defensible combined p-value, but
    every policy is switchable per-call without patching the package.

  **What "weight" means and how `"estimand_grouped"` is generated,
  concretely:** in `T = sum(w_i * tan((0.5 - p_i) * pi))`, `w_i` is how
  much class `i`'s p-value moves the combined statistic; the only formal
  requirements are `w_i >= 0` and `sum(w_i) = 1`, and — the one hard rule
  for the built-in policies — the weights must be **fixed from metadata
  known before fitting**, never a function of the observed `p_i` values
  themselves (data-dependent weighting breaks the null-calibration
  guarantee that makes CCT valid under arbitrary dependence in the first
  place; this is exactly why AIC-based weighting was rejected, see
  "Weighting" above — a user picking `"custom"` weights from their own
  prior knowledge is fine, since those are still fixed before the fact, not
  derived from this fit's AIC). `"estimand_grouped"`'s two-stage
  combination (within-`estimand` CCT, then across-group CCT) is exactly
  equivalent to a single flat CCT call with a particular closed-form
  weight vector, so it needs no separate combiner: for a class `i`
  belonging to an `estimand` group of size `m_i`, out of `G` total
  distinct `estimand` groups among the usable rows, `w_i = 1 / (G * m_i)`.
  Every group gets total weight `1/G` regardless of how many classes
  happen to implement that estimand, and every class within a group splits
  that group's share evenly. Worked example: 8 usable classes split across
  `G = 3` estimand groups — 5 `mean_difference` classes, 1
  `quantile_shift_tau0.5` class, 2 `hazard_ratio` classes — gives `w =
  1/15` for each of the 5 mean-diff classes, `w = 1/3` for the lone
  quantile class, and `w = 1/6` for each of the 2 hazard-ratio classes;
  all three groups still sum to `1/3` each, so the lone quantile method is
  not out-voted by the mean-diff family's head count. Implementation-wise
  this means TODO-14's `cct_combine_pvalues(pvals, weights = NULL)` needs
  no group-aware logic of its own — a thin wrapper computes this
  `1/(G * m_i)` vector from `results_table$estimand` (for `status == "ok"`
  rows with non-`NA` `pval` only) and passes it in as `weights`.

- [ ] TODO-15a: **Audit `estimand`/`get_estimand_type()` tagging across
  every response-type family before `"estimand_grouped"` ships as the
  default.** `"estimand_grouped"`'s correctness depends entirely on
  `estimand` actually distinguishing "different scientific question" (logit
  vs. `"RD"`-type risk difference) from "different link/model answering the
  same practical question" (log-binomial vs. modified Poisson, both
  `"RR"`-type). Grep (2026-08-18) confirms only the incidence g-computation
  classes (`inference_incidence_gcomp*.R`) currently implement
  `get_estimand_type()` (returning `"RD"`/`"RR"`); non-gcomp incidence
  classes (`InferenceIncidLogit`, `InferenceIncidProbit`,
  `InferenceIncidLogBinomial`, `InferenceIncidModifiedPoisson`,
  `InferenceIncidCMH`, KK conditional-logit variants, etc.) and the other
  five response-type families have not been checked. For each family,
  confirm every class either declares a real `estimand` or is documented as
  `NA_character_` on purpose (and decide, per the "Weighting" discussion,
  whether `NA`-`estimand` classes should default into their own singleton
  group under `"estimand_grouped"`, or be excluded from the default policy
  entirely with a `warning()` — leaving this undecided would make the
  default weighting silently inconsistent between response types).
- [ ] TODO-16: Wire `combined_evidence` into `run_all_inference()`'s return
  object and into the `screen`/`html` summary line beneath the per-class
  table (only over `status == "ok"` rows with non-`NA` `pval`).
- [ ] TODO-17: Edge cases: clip `p_i` away from exactly 0/1 before the
  `tan()` transform (avoids `±Inf`/degenerate `atan()` input); fewer than 2
  usable p-values → `combined_evidence$pval = NA_real_`, documented, not
  silently treated as "the" p-value; all usable p-values identical (sanity:
  combined p should equal that value under equal weighting).
- [ ] TODO-18: Tests — simulate iid Uniform(0,1) p-values under a true
  global null and confirm `combined_pval` is calibrated (roughly uniform,
  not anti-conservative); simulate p-values sharing common data-driven
  correlation (e.g. bootstrap-derived, same underlying dataset) and confirm
  the combined p-value stays valid (does not spuriously reject under a true
  joint null) — this is the actual property being relied on, so it needs a
  simulation check, not just a unit test of the formula; all TODO-17 edge
  cases; whichever weighting policy TODO-15 resolves to, including the
  redundant-method-family scenario that motivated the question.
- [ ] TODO-19: Docs — roxygen section on `combined_evidence` stating the
  interpretation caveat verbatim ("evidence of an effect in at least one of
  these senses, not evidence for a specific estimate or direction"), the
  union-intersection-null framing, and the Liu & Xie (2020) citation.
  Cross-reference `JSS_paper_research_plan.md` §3.5b/§4 item 7 so the paper
  and the roxygen state the same caveat consistently.
- [ ] TODO-20: **`@references` roxygen block + `REFERENCES.md` entry —
  required by `check_references_sync.R`, not optional polish.** Confirmed
  by grep (2026-08-18): `inference_suite.R` currently has *no* `@references`
  block at all, and `REFERENCES.md` has no `InferenceSuite`/Madigan/Cauchy
  entries anywhere. `check_references_sync.R` (wired into `.githooks/
  pre-push`) fails the build if a file gains an `@references` block whose
  class/function name isn't indexed under some `REFERENCES.md` entry's
  "Used by:" list — so this TODO isn't just documentation hygiene, it's a
  pre-push gate. Two citations need adding together, since both attach to
  `InferenceSuite`/`run_all_inference()`:
  - **Liu, Y. and Xie, J. (2020)**, "Cauchy combination test: a powerful
    test with analytic p-value calculation under arbitrary dependency
    structures," *Journal of the American Statistical Association*,
    115(529), 393-402 — the combined-evidence metric's method (this TODO).
  - **Madigan, D., Ryan, P. B., and Schuemie, M. (2013)**, "Does design
    matter? Systematic evaluation of the impact of analytical choices on
    effect estimates in observational studies," *Therapeutic Advances in
    Drug Safety*, 4(2), 53-62, PMID 25083251 — `InferenceSuite`'s
    motivating citation (already used in `JSS_paper_research_plan.md`
    §3.5b's prose, but likewise never actually added to the package's own
    roxygen/`REFERENCES.md`; that's a pre-existing gap this TODO should
    close at the same time rather than leave for a separate pass, since
    both citations land on the same class in the same edit).
  Concretely: add an `#' @references` block to `InferenceSuite`'s
  class-level roxygen in `inference_suite.R` citing both works, then add
  both as new `REFERENCES.md` entries with stable citation keys (e.g.
  `[LiuXie2020]`, `[MadiganRyanSchuemie2013]`) under a new or existing
  "Inference orchestration" heading, each with `Used by: `InferenceSuite`,
  `run_all_inference()``. Run `Rscript R/package_tests/
  check_references_sync.R` after to confirm.
- [ ] TODO-21: `smoke_test_run_comprehensive_suite.R`
  (`R/package_tests/`) — check whether this comprehensive smoke test
  exercises `InferenceSuite$run_all_inference()`, and if so, extend its
  coverage to include the new `combined_evidence` element (present with a
  non-`NA` `pval` when >=2 usable classes, `NA` and documented otherwise)
  so a future regression in the Cauchy-combination wiring surfaces there,
  not only in TODO-18's unit tests.
