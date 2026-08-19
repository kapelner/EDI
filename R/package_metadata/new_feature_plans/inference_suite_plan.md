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
  ci_a        = <numeric or NA_real_>,
  ci_b        = <numeric or NA_real_>,
  ci_method       = <character or NA_character_>,  # e.g. "wald", "rand"
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
  status          = "ok" | "nonest" | "error",
  message         = <character or NA_character_>,
  weight          = <numeric or NA_real_>  # "estimand_grouped" Combined Evidence
                                   # weight, w_i = 1 / (G * m_i) over usable
                                   # (status == "ok", finite pval) rows; NA
                                   # for any non-usable row
)
```

`run_all_inference()` also takes `alpha` (default `0.05`): the CI level
(`1 - alpha`) and the significance threshold used anywhere the report
flags/format significance — not hardwired to 95%.

Below the per-class table, both output modes append an
**unavailable-classes footer** listing
`unavailable_due_to_missing_packages` (class name → missing packages), so
the practitioner can see which estimators an `install.packages()` away.
Each line reads `"<class> - requires install.packages(\"<pkg1>\", ...)"`,
and the heading above the list is singular/plural-aware ("The following
Inference class is unavailable:" / "...classes are unavailable:").

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
gets `ci_a = ci_b = ci_method = NA` / `pval = pval_method = NA`
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
  "nonest"`, `message` set from the condition, all numeric fields
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
      ci_a = ..., ci_b = ..., ci_method = ...,
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
   — every class's `(1 - alpha)`-level `[ci_a, ci_b]` as a
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

### Weighting — resolved (TODO-15/TODO-15a); kept below as design rationale

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
  "cauchy_combination", n_classes_used = <integer>, n_estimand_groups =
  <integer>, estimands_used = <character vector>, weighting =
  <character>, weights_used = <named numeric vector, class -> weight>,
  classes_used = <character vector>)`. `weighting` records which policy was
  actually applied for this call (`"equal"` / `"estimand_grouped"` /
  `"custom"` — see TODO-15) and `weights_used` records the exact per-class
  weight vector, so a saved/JSON result is self-documenting about how its
  own combined p-value was built, not just that one was built.
  `n_estimand_groups`/`estimands_used` record `G` and which `estimand`
  values actually fed the combination (after `combined_evidence_estimands`
  filtering, if any) — populated for every `weighting` policy, not only
  `"estimand_grouped"`, since "how many distinct senses of 'effect' does
  this number summarize" is informative regardless of how they were
  weighted. `NA`/`0`/empty when
  fewer than 2
  `status == "ok"` classes have a non-`NA` `pval` (a "combination" of one
  p-value is just that p-value, not a meaningful combined-evidence claim —
  degenerate case, document explicitly rather than silently returning the
  single p-value as if it were combined).
- `screen` and `html` outputs print one summary line beneath the per-class
  table, stating the estimand count *before* the p-value so a reader sees
  what's being summarized before the number itself:
  `"Combined evidence across G = <n_estimand_groups> estimands (k = <n>
  classes, weighting = <weighting>): p = <value>"`.
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
  "nonest"`; captured `warning()`s collapse into the `warnings`
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
  alongside `"ok"`/`"nonest"`/`"error"`. **Verified it actually
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

- [x] TODO-14: `cct_combine_pvalues(pvals, weights = NULL)` implemented in
  `inference_suite.R` (`@keywords internal @noRd`, alongside the other
  `run_all_inference_*` helpers) — the `T = sum(w_i * tan((0.5 - p_i) * pi))`
  / `combined_pval = 0.5 - atan(T) / pi` formula, equal weights when
  `weights = NULL`, and unnormalized weights renormalized internally
  (so callers, e.g. the future `"estimand_grouped"` weight vector, don't
  need to pre-sum to 1). `@references` Liu & Xie (2020) included in the
  roxygen (informational only, since `@noRd` suppresses actual Rd
  generation — the formal, rendered citation is `TODO-20`'s job on
  `InferenceSuite`'s own class-level roxygen). Deliberately excludes
  `TODO-17`'s edge-case hardening (0/1 clipping, <2-p-value guard), per
  the plan's own scoping split.

  **Verified beyond what TODO-14 strictly required**, since a formula this
  central deserves more than a smoke test: single p-value returns itself
  exactly; identical p-values combine to that same value regardless of
  weighting (a known CCT property); one tiny p-value dominates (min-p-like
  behavior); unnormalized vs. normalized weights give identical results.
  Then two calibration simulations (20,000 replicates each, effectively a
  lightweight preview of `TODO-18`): under a true null with **independent**
  p-values, the combined p-value is calibrated (mean 0.499, 5.0%/1.07% tail
  rates against nominal 5%/1%, KS-test-vs-Uniform(0,1) `p = 0.33`, no
  rejection); under a true null with **`rho = 0.9`-correlated** p-values
  (shared common factor), the false-positive rate stays at nominal (5.5%
  vs. 5% nominal, 1.1% vs. 1% nominal) — this is the actual headline
  property the plan cites as the reason CCT was chosen over
  Fisher's/Stouffer's/minP, confirmed empirically rather than assumed from
  the literature.
- [x] TODO-15: **User-facing weighting arguments on `run_all_inference()` —
  the user decides, the package does not silently pick a policy** (revised
  2026-08-18, per user request: weighting must be an argument the caller
  controls, not a hardcoded internal choice). Add:

  ```r
  run_all_inference(
    ...,
    combined_evidence_estimands = NULL,
    combined_evidence_weighting = c("estimand_grouped", "equal", "custom"),
    combined_evidence_weights   = NULL
  )
  ```

  - `combined_evidence_estimands = NULL` (**default: include every
    estimand**): restricts which `estimand` groups feed the combined
    p-value. `NULL` means every `estimand` present among usable
    (`status == "ok"`, non-`NA` `pval`) rows is included — this is the
    "show everyone, decide nothing on the user's behalf" default that
    matches the rest of `InferenceSuite`'s philosophy. A user can instead
    pass a character vector of `estimand` values to keep
    (e.g. `c("mean_difference", "hazard_ratio")`), which both restricts
    the combined p-value's inputs *and* changes `G` for
    `"estimand_grouped"` weighting (recomputed over only the retained
    groups, so remaining groups still split `1/G` evenly rather than
    inheriting stale shares from excluded ones). Validate against the
    actual `estimand` values present in `results_table` for this fit
    (argument-time `stop()` on an unknown value, same style as TODO-11's
    `classes` validation) — this is a coarser, estimand-level sibling of
    TODO-11's class-level `classes`/`exclude_classes` allow-list, not a
    replacement for it; both can be used together (e.g. restrict to
    certain classes *and* certain estimands in the same call).

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

  **Done 2026-08-19:** `run_all_inference()` gained
  `combined_evidence_estimands`/`combined_evidence_weighting`/
  `combined_evidence_weights` exactly as scoped above, argument-time
  validated (`inference_suite.R`): `combined_evidence_estimands` checked
  against the `estimand` values actually declared (via
  `get_inference_class_metadata(nm)$estimand`) among the
  `classes`/`exclude_classes`-filtered candidates -- given TODO-15a is
  **not actually finished** despite a doc note elsewhere claiming
  otherwise (see that entry), this filter is only usable today for the
  incidence g-comp/marginal families, which is the honest current state,
  not a bug. `combined_evidence_weighting = "custom"` requires
  `combined_evidence_weights` (named numeric, class name -> weight,
  non-negative, names a subset of the classes being fit) and errors if
  supplied under any other policy, rather than silently ignoring it.
  New `run_all_inference_compute_combined_evidence_weights()`
  (`inference_suite.R`) dispatches all three policies over the
  (`estimands`-filtered) usable set and now drives `results_table$weight`
  directly, replacing the previously-hardcoded `"estimand_grouped"`-only
  `run_all_inference_estimand_grouped_weights()` call (that function is
  kept, unused by `run_all_inference()` itself now, as the narrower
  building block the new dispatcher's `"estimand_grouped"` branch
  reimplements inline). **Verified**: all three policies smoke-tested by
  sourcing the real functions directly out of `inference_suite.R` against
  a 5-row/3-estimand-group mock table -- `"estimand_grouped"` reproduces
  this section's own worked example's weight ratios exactly (`1/9`/`1/9`/
  `1/9`/`1/3`/`1/3` for a 3/1/1 group-size split under `G=3`); `"equal"`
  gives flat `1/5`; `"custom"` respects named weights and zeroes unnamed
  classes; restricting via `estimands` correctly recomputes `G` over only
  the retained groups. Full package `parse()` clean.

**Infrastructure landed (2026-08-19, user decision — before this,
`get_estimand_type()` was only a private-instance-method convention two
gcomp classes happened to follow, with no registry presence and no
architectural home):**

- `Inference$get_estimand_type()` (`inference_all_abstract.R`): a new
  root-class default (`NA_character_`), declare-only, mirroring
  `requires_blocking_design()`'s exact pattern — a trivial,
  argument-less, self/private-free literal that a concrete class
  overrides to a fixed string (`"mean_difference"`, `"log_odds_ratio"`,
  `"hazard_ratio"`, etc.) when it wants to participate.
- `infer_inference_estimand_type(generator)`
  (`inference_class_registry.R`): safe, no-instantiation walk up the
  generator's `private_methods`, identical in shape to
  `infer_inference_requires_blocking_design()`, folded into
  `populate_inference_class_registry()`'s per-class metadata (a new
  `estimand` field, alongside `likelihood_tier`/`response_types`) and
  `register_inference_class()`'s default record. **Real bug found and
  fixed while building this**: `InferenceIncidGCompAbstract` already had
  an intentional `get_estimand_type() { stop(...) }` "must implement"
  stub for its own subclasses, referencing `self` — calling it bare (as
  the safe-walk does) crashed `populate_inference_class_registry()`
  outright for that abstract class's own registry entry. Fixed by
  wrapping the walk's function call in `tryCatch()`, treating any error
  as "no declared value" — the semantically correct outcome for an
  abstract class's own entry regardless of why the call failed.
- `run_all_inference_estimand()` (`inference_suite.R`) now reads
  `get_inference_class_metadata(cls_name)$estimand` instead of
  introspecting the fitted instance's private method — cheaper, and
  (a real improvement found while making the change) now populates
  **regardless of fit outcome**: a `status = "nonest"`/`"error"`/
  `"timeout"` row still correctly reports its class's declared estimand,
  since registry lookup needs no successful construction. Moved into
  `run_all_inference_one_class()`'s unconditional row initialization,
  matching `likelihood_tier`'s existing placement exactly, rather than
  only being set inside the `"ok"` branch as before.

  **Verified**: `EDI_VALIDATE_INFERENCE_CONTRACTS=true` strict load
  clean; direct registry checks confirm `InferenceIncidGCompRiskDiff`
  → `"RD"`, `InferenceIncidGCompRiskRatio` → `"RR"`,
  `InferenceContinOLS` (undeclared) → `NA`, the abstract gcomp base
  itself → `NA` (no crash); a live `run_all_inference()` call across
  both gcomp classes plus `InferenceIncidLogRegr` showed the
  registry-level fix working end-to-end — `InferenceIncidGCompRiskRatio`
  reported `estimand = "RR"` even on a `status = "nonest"` row for
  that random seed. A committed regression test
  (`test-inference-suite-run-all-inference.R`) asserts exactly this.
  Full test suite (`test-mixin-contracts.R`, `test-inference-class-
  registry.R`, `test-inference-suite-discovery.R`,
  `test-inference-suite-run-all-inference.R`) passed cleanly before the
  final regression test was added; that last run was blocked by an
  unrelated concurrent Phase 1D session mid-editing
  `inference_incidence_KK_cond_logit_glmm_abstract.R`/`contracts_mixins.R`
  (confirmed via `git status`/`git diff`, different transient error on
  each retry — an active save in progress, not a real bug) — re-run once
  that session's edit lands.

**Important finding for sequencing (2026-08-19): declaring
`get_estimand_type()` on a class is NOT gated on Phase 1D**, unlike
`marginal_estimand_report.md → TODO-4/5/7/9`'s full `set_estimand()`
switching wiring. The safe-walk mechanism
(`infer_inference_estimand_type()`) reads `private_methods` off *any* R6
generator via `get_inherit()` regardless of whether that class is still
on the legacy deep-hierarchy `inherit =` ladder or already migrated to
`define_inference_class()` — it never touches the component system at
all. So rolling out declare-only estimand tags across every response-type
family (the actual work TODO-15a's audit would motivate) can proceed in
parallel with Phase 1D, the same way `inference_suite_inspect.md`'s own
TODO-1..8 did.

- [x] TODO-15a: **Audit `estimand`/`get_estimand_type()` tagging across
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

  **Do not start this audit from a "should be a small number of estimand
  groups per response type" prior — added 2026-08-18, informed reasoning
  from the §3.4 method roster, not yet verified against real tags.** The
  number of distinct estimand groups (`G`) varies sharply by response
  type, for structural reasons, not accidents of implementation:
  - **Continuous** and **count** (excluding zero-inflated/hurdle) are
    plausibly genuinely small — OLS/robust-regression/Lin/KK-OLS-IVWC/
    KK-Bai variants all target one location-shift functional, and
    Poisson/quasi-Poisson/NegBin/robust-Poisson/conditional-Poisson/GEE
    all target one log-rate-ratio functional. Expect `G` on the order of
    2-3 for these, modulo quantile regression (see below).
  - **Ordinal is the sharpest counterexample, and likely has the *most*
    estimand groups of any response type, not the fewest.** Proportional
    odds, adjacent-category logit, stereotype logit, cauchit, cloglog,
    ordered probit, and ridit are not different *estimation methods* for
    one shared quantity — each is a genuinely different link function,
    which is exactly why they are separately named and implemented in the
    first place (cauchit/cloglog exist specifically to put the treatment
    effect on a different scale than proportional-odds logit does). Expect
    `G` closer to 6-10 for ordinal; the estimand-grouping weighting matters
    most here and is most at risk of being wrong if the audit
    under-differentiates these.
  - **Incidence has a subtlety beyond link functions: noncollapsibility.**
    Logistic regression's marginal (population-averaged) odds ratio and
    its conditional (subject-specific/cluster-adjusted) odds ratio are not
    asymptotically the same quantity even when both come from "a logistic
    model" — so a plain `InferenceIncidLogit` and a conditional-logit/GLMM
    (KK) variant plausibly need *different* `estimand` tags, not the same
    one, on top of logit/probit/log-binomial/modified-Poisson/
    risk-difference already being distinct scales. Resolve this
    explicitly during the audit rather than defaulting conditional and
    marginal variants into the same bucket by not thinking about it.
  - **Zero-inflated/hurdle count models (and ZOIB in proportion) may not
    reduce to *one* estimand at all — flag as an open question, do not
    force a single tag.** A zero-inflated Poisson has a structural-zero
    component and a count-process-rate component; treatment could
    plausibly affect one, the other, both, or neither, and there is no
    obviously correct single "the treatment effect" p-value for that class
    without picking which part is meant. This is a genuinely harder
    problem than link-function grouping and may need its own resolution
    (e.g. two separate rows/estimands per class, or an explicit
    documented simplification) rather than being swept into whichever
    single `estimand` string is easiest to assign.
  - **Quantile regression is τ-indexed, not fixed**, in continuous,
    proportion, and any other family that offers it — if quantile
    regression is fit at multiple τ values, each τ is arguably its own
    scientific question ("does treatment shift the 25th percentile" ≠
    "does treatment shift the median"), so this alone can turn what looks
    like one model into several estimand groups depending on
    configuration, even within an otherwise-small response-type family.

  **Done 2026-08-19, see `fix_inference_hierarchy.md`'s matching checklist
  item for the full class-by-class audit table** (verified real this time
  after an earlier, unrelated stale doc claim of "done" was checked and
  found false, then corrected — see that file's own note): a flat
  `EDI_INFERENCE_ESTIMAND_TAGS` name -> estimand-string map in
  `inference_class_registry.R`, consulted by `infer_inference_estimand_type()`
  before falling back to the two g-comp families' own real
  `get_estimand_type()` method overrides (kept as the source of truth for
  those four leaf classes, confirmed matching). 88 of ~99 concrete classes
  tagged by auditing each one's actual `compute_estimate()` fit code and
  `@description` roxygen, not name patterns. `NA_character_` retained for
  the genuinely hard cases the "do not force a single tag" guidance above
  flagged in advance: zero-inflated/hurdle/ZOIB models (structural-zero vs.
  rate-process ambiguity) and τ-indexed quantile regression (each τ is its
  own question) — both confirmed non-collapsible during the audit, not
  simply unaudited. `"estimand_grouped"` (TODO-15) is now safe to default
  to for every class that *is* tagged; `NA`-estimand classes still need the
  explicit singleton-group-vs-excluded-with-warning policy decision this
  TODO's own text called for — that decision remains open.
- [x] TODO-16: Wire `combined_evidence` (including `n_estimand_groups`/
  `estimands_used`, per "Output wiring" above) into `run_all_inference()`'s
  return object and into the `screen`/`html` summary line beneath the
  per-class table (only over `status == "ok"` rows with non-`NA` `pval`,
  after `combined_evidence_estimands` filtering per TODO-15). Apply
  `combined_evidence_weighting`/`combined_evidence_weights`/
  `combined_evidence_estimands` here, not at discovery/fit time — these
  arguments only affect which usable rows feed the combination and how,
  never which classes get constructed/fitted in the first place.

  **Done 2026-08-19:** `out$combined_evidence` now matches the "Output
  wiring" section's full shape: `list(pval, stat, method =
  "cauchy_combination", n_classes_used, n_estimand_groups, estimands_used,
  weighting, weights_used, classes_used)`. `stat` required widening
  `cct_combine_pvalues()`'s internals -- added `cct_combine_pvalues_full()`
  returning `list(pval, stat)`, with `cct_combine_pvalues()` now a thin
  `$pval`-only wrapper around it (unchanged external contract), and
  `run_all_inference_combine_pvalues()` widened the same way to
  `list(pval, stat, n_used)`. One deliberate deviation from the original
  spec text, necessitated by the `formulas` argument added earlier this
  same session (after TODO-16 was originally scoped): `weights_used`/
  `classes_used` are keyed/valued by each row's `results` name
  (`"<class>[<formula>]"` when `formulas` produced more than one row for a
  class, else the plain class name) rather than
  `results_table$inference_class` directly, since that column can now
  repeat within one fit. New shared
  `run_all_inference_combined_evidence_summary_line()` renders exactly the
  spec's line format (`"Combined evidence across G = <n> estimands (k = <n>
  classes, weighting = <weighting>): p = <value>"`) and is called from all
  three places TODO-16 named: `run_all_inference(screen = TRUE)`'s live
  output (right after `class(out) = c("EDIInferenceSuiteResults", "list")`),
  `run_all_inference_render_html()` (new `<p>` beneath the results table),
  and `print.EDIInferenceSuiteResults()` (beneath the pretty-printed table,
  for a later reprint of a saved result). **Verified**: sourced the real
  functions directly out of `inference_suite.R` against a 3-row mock table
  and confirmed the summary line renders correctly and appears in the
  rendered HTML; full-file `parse()` clean; `test-inference-suite-run-all-
  inference.R`'s `names(res)` structural assertion updated to include
  `combined_evidence`.
- [x] TODO-16a: **Organize the per-class table by `estimand`, not just
  computation order** (added 2026-08-18, per user request). Two separate
  surfaces, resolved differently:
  - **`results_table` (the final, complete data.frame) and the `html`
    report's table**: sort/group rows by `estimand` (rows sharing an
    `estimand` adjacent; `NA_character_`-`estimand` rows last as their own
    group), with a natural secondary sort (e.g. by `inference_class` name)
    within each group. This is a pure presentation reorder — it does not
    change `results` (the list, TODO-7b), which stays in computation order
    since that is documented as its contract and other code (e.g. the
    per-class failure-isolation test) may rely on it.
  - **`screen`'s live incremental streaming (TODO-4, already shipped)
    is *not* changed by this** — rows print as each class's fit
    completes, which is inherently completion-order and can't be
    pre-sorted by `estimand` without buffering (defeating the "streamed as
    it happens" point of TODO-4). Instead, print a compact per-estimand
    breakdown as part of the final combined-evidence summary line block
    (after all rows have streamed): one line per `estimand` group showing
    its own within-group `estimand_grouped` sub-combination p-value (the
    intermediate value TODO-15's two-stage-equivalent formula computes
    internally on the way to the flat weight vector), immediately above
    the overall combined-evidence line — so a screen reader sees "here's
    what each estimand group says" before "here's the one number
    combining all of them," even though the per-class rows above it
    streamed in fit-completion order, not estimand order.
  - `print.EDIInferenceSuiteResults()` (TODO-10, not yet implemented) must
    use the same `estimand`-grouped ordering as `results_table`/`html`,
    since it is documented to render "the same table `screen` already
    prints" — reconcile that TODO-10 description with this one: it prints
    the same *rows and columns*, in the `estimand`-grouped order, not
    necessarily replaying `screen`'s original streaming order.
  - Already consistent with this direction and needing no change: the two
    ggplot2 visualizations (TODO-7, shipped) already facet by `estimand`.

  **Done 2026-08-19:** `results_table` (and, via the shared
  `run_all_inference_build_display_table()`, the `html` report's table)
  now sorts by `order(estimand, inference_class, na.last = TRUE)` right
  after the `weight` column is computed in `run_all_inference()`, before
  `combined_evidence` is built -- `row_ids` (the `results`-name vector
  `weights_used`/`classes_used` key off) is reordered by the identical sort
  index so it stays aligned. `results` (the list) is untouched, still
  computation order, per this TODO's own explicit contract. New
  `run_all_inference_per_estimand_breakdown_lines()` prints one line per
  `estimand` group (`"<estimand> (k = <n>): p = <within-group CCT
  p-value>"`, equal-weighted within the group) immediately above the
  overall Combined Evidence summary line, in both `screen`'s live output
  and `print.EDIInferenceSuiteResults()` -- `screen`'s per-row streaming
  itself is unchanged (still completion order), exactly as scoped.
  `print.EDIInferenceSuiteResults()` (referenced above as "TODO-10, not yet
  implemented") now exists and does print in the same `estimand`-grouped
  order as `results_table`, via `run_all_inference_format_pretty_table()`.
  **Verified**: sourced the real functions directly out of
  `inference_suite.R` against a 4-row mock table with a
  `status = "nonest"` row mixed in -- confirmed the sort correctly moves
  `NA`-`pval` rows out of the way while still respecting `estimand`
  grouping (the `nonest` row's `estimand` is non-`NA`, so it sorts inside
  its group, not excluded from grouping -- only excluded from weighting/
  combination), the per-estimand breakdown gives `NA` for the
  singleton-class group and a real combined p for the 2-class group, and
  the HTML output contains the summary line; full-file `parse()` clean.
- [x] TODO-17: `run_all_inference_combine_pvalues(pvals, weights = NULL,
  pval_eps = 1e-4)` implemented in `inference_suite.R`, wrapping
  `cct_combine_pvalues()` (TODO-14): drops `NA` p-values (with aligned
  weight-vector dropping); returns `NA_real_` for fewer than 2 usable
  p-values rather than treating a lone p-value as a combined one; clips
  every usable p-value to `[pval_eps, 1 - pval_eps]` before the `tan()`
  transform. **`pval_eps` is a user-adjustable parameter (per user
  request, 2026-08-18), default `1e-4`** — named and defaulted now so it
  can be exposed directly as a `run_all_inference()` parameter once
  TODO-16 wires `combined_evidence` into its public signature; not added
  to `run_all_inference()` itself yet, since nothing calls this helper
  until that wiring lands (avoids dead public-API surface).

  **Verified** (in isolation, sourcing just the two helper functions
  directly, since the package didn't load at verification time due to an
  unrelated concurrent session mid-editing
  `inference_count_KK_cond_poisson.R` — confirmed via `git diff`/`git
  status` that file is 84 insertions/22 deletions in progress, untouched
  by this work, left alone): `p = 0`/`p = 1` inputs no longer produce
  `Inf`/`NaN` (all finite); `f(0.05)`, `f(c(0.05, NA))`, and
  `f(numeric(0))` all correctly return `NA`; `NA`-dropping with weight
  realignment matches the direct equivalent call exactly; four identical
  p-values (`0.15`) combine to exactly `0.15` under equal weighting,
  confirming the CCT mathematical identity holds through the wrapper;
  `pval_eps` genuinely changes clipping behavior (`p = 0` combined with
  `p_eps = 1e-4` gives a different, correctly less-extreme result than
  `p_eps = 1e-8`).

  **Known, deliberately out-of-scope gap for v1.0.0 (added 2026-08-18):** a
  single numerically pathological fit (e.g. separation-driven near-zero
  Wald `p_i` from an unstable coefficient/SE) can dominate `T` the same
  way a genuine signal would, at both the per-class and per-`estimand`-group
  level — CCT has no way to distinguish "real evidence" from "numerical
  artifact" on its own. The 0/1 clipping above is a pure floating-point
  safety net (prevents `Inf`/`NaN` propagation) and does **not** address
  this — it still lets an artifact-driven `p_i = 1e-300` dominate `T`
  cleanly. A real fix needs a native diagnostics signal
  (`converged`/`boundary_hit`/`diagnostic_category = "separation"`) to
  exclude or flag such fits before they enter `cct_combine_pvalues()`, and
  that signal does not exist yet: `inference_suite_inspect.md`'s own
  per-class `diagnostics` sub-list is currently hardcoded `NA` for every
  field (confirmed under TODO-7b) because there is no generic
  native-diagnostics accessor on `Inference` at the R level — wiring real
  values in is tracked as `public_diagnostics_api_spec.md → TODO-19`
  (v1.1.0). Do not substitute an ad hoc magnitude-threshold heuristic
  (e.g. flag `abs(estimate) > 1e6` or similarly small `se`) as a stopgap —
  `optimizer_diagnostics_report.md` documents that exact pattern (a
  "copy-pasted `max(abs(b)) <= 1e6` magnitude threshold" scattered across
  3-4 C++ call sites) as an unreliable proxy the diagnostics API exists
  specifically to replace; adding a second copy of it here for the
  combined-evidence path would work against that cleanup rather than with
  it. Revisit this TODO once `public_diagnostics_api_spec.md → TODO-19`
  lands and `diagnostics$converged`/`diagnostic_category` carry real
  values — at that point, exclude (or downweight, TBD) any class whose
  diagnostics indicate a boundary/separation fit before it contributes to
  `combined_evidence`, both at the per-class and per-`estimand`-group
  level.
- [x] TODO-18: Tests — simulate iid Uniform(0,1) p-values under a true
  global null and confirm `combined_pval` is calibrated (roughly uniform,
  not anti-conservative); simulate p-values sharing common data-driven
  correlation (e.g. bootstrap-derived, same underlying dataset) and confirm
  the combined p-value stays valid (does not spuriously reject under a true
  joint null) — this is the actual property being relied on, so it needs a
  simulation check, not just a unit test of the formula; all TODO-17 edge
  cases; whichever weighting policy TODO-15 resolves to, including the
  redundant-method-family scenario that motivated the question.

  **Done 2026-08-19:** New `test-cct-combine-pvalues.R`
  (`R/EDI/tests/testthat/`), four `test_that()` blocks against the
  standalone combiner/weighting functions directly (no `Inference`/
  `Design` objects involved -- the property under test is the combiner's
  own statistical behavior): (1) 2000-replication global-null calibration
  check (`k = 5` iid `Unif(0,1)` p-values per replication) -- rejection
  rate at `alpha = 0.05` and a KS-test-against-uniform goodness-of-fit
  check, both with Monte Carlo tolerance, not an exact-uniformity
  assertion; (2) 2000-replication correlated-null check, p-values derived
  from a shared latent factor (`rho = 0.6`) via the probability integral
  transform, confirming the combined p-value does not spuriously reject at
  an inflated rate despite correlated inputs -- CCT's defining
  arbitrary-dependence-validity property; (3) all TODO-17 edge cases
  (`NA`-dropping with weight realignment, <2-usable degenerate case at
  `n = 1`/`n = 0`/all-`NA`, `0`/`1` p-value clipping avoiding non-finite
  `atan()` output, the four-identical-p-values mathematical identity,
  `pval_eps` genuinely changing clipping behavior); (4) all three TODO-15
  weighting policies (`"estimand_grouped"`'s ratios checked against this
  same file's own worked example, `"equal"`, `"custom"` with unnamed-class
  zeroing, `estimands`-filtered `G` recomputation, and a non-usable-row
  guard). **Verified**: every assertion validated by sourcing the real
  functions directly out of `inference_suite.R` (not a standalone
  reimplementation) before committing the test file -- global-null
  rejection rate `0.0565` (threshold `0.075`), correlated-null rejection
  rate `0.0555` (threshold `0.10`), KS `p = 0.227` (threshold `0.001`), all
  edge-case and weighting-policy values matched exactly. Full test-file
  `parse()` clean; not yet run through `testthat::test_file()` against a
  loaded package build (per this repo's no-full-rebuild rule -- the user's
  own build tooling should run it).
- [x] TODO-19: Docs — roxygen section on `combined_evidence` stating the
  interpretation caveat verbatim ("evidence of an effect in at least one of
  these senses, not evidence for a specific estimate or direction"), the
  union-intersection-null framing, and the Liu & Xie (2020) citation.
  Cross-reference `JSS_paper_research_plan.md` §3.5b/§4 item 7 so the paper
  and the roxygen state the same caveat consistently.

  **Done 2026-08-19:** New "Combined Evidence interpretation caveat"
  paragraph added to `InferenceSuite`'s class-level roxygen
  (`inference_suite.R`), immediately before the existing `@references`
  block (which already carries the Liu & Xie 2020 citation, landed under
  TODO-20) -- states the union-intersection-test framing
  (\eqn{H_0: \theta_1=0 \cap \dots \cap \theta_k=0} vs. "at least one
  \eqn{\theta_i \neq 0}") and the exact verbatim caveat sentence this
  TODO specifies. `JSS_paper_research_plan.md`'s §3.5b interpretive-caveat
  bullet updated to use the identical verbatim sentence (previously a
  differently-worded paraphrase), with an explicit cross-reference note
  pointing each document at the other so they don't drift apart again.
- [x] TODO-20: `@references` added to `InferenceSuite`'s class-level
  roxygen in `inference_suite.R` (Madigan/Ryan/Schuemie 2013 + Liu/Xie
  2020), and both added to `REFERENCES.md` under a new "Inference
  orchestration" subsection (`[MadiganRyanSchuemie2013]`, `[LiuXie2020]`)
  with stable citation keys, matching house format exactly.
  `cct_combine_pvalues()`'s own internal `@keywords internal @noRd`
  roxygen (added with TODO-14) already carried an informational
  `@references Liu, Y. and Xie, J. (2020)...` line too, so this file had
  two `@references`-bearing blocks by the time this TODO ran.

  **Ran the actual gate** (`Rscript R/package_tests/
  check_references_sync.R`), not just assumed it would pass, and it
  caught two real issues:
  1. **A genuine mechanical gap in my first draft**: I initially wrote
     `Used by: \`InferenceSuite\`, \`run_all_inference()\`` per this
     TODO's own instructions, but `check_references_sync.R`'s live-name
     extraction only recognizes **top-level** assignments
     (`^name = ...` at column 0, or `R6::R6Class("Name", ...)`/
     `classname = "Name"`) — `run_all_inference` is a method nested
     inside `InferenceSuite`'s `public = list(...)`, not a top-level
     assignment, so it doesn't count as a "live name" and the check
     failed with "cites a name that no longer exists." Confirmed via the
     one other precedent in the file (`generate_covariate_dataset()`,
     which *is* a top-level function) that nested R6 methods are
     structurally never citable this way. Fixed by citing only
     `InferenceSuite` in both entries.
  2. **A pre-existing, unrelated failure**: `design_fixed_optimal.R` has
     an `@references` block with no matching `REFERENCES.md` entry.
     Confirmed via `git diff`/`git log` that this file was last touched
     2026-08-17 (the `design_fixed_optimal.md` finished feature) and I
     have never touched it this session — left alone, not this plan's
     scope to fix, but worth flagging since it's a real standing
     pre-push-gate failure independent of anything here.

  After the fix, `check_references_sync.R` reports only that one
  pre-existing, unrelated failure — everything this TODO touched is
  clean. Full test suite still passes, package still loads via
  `pkgload::load_all(compile = FALSE)`, zero stray files.
- [x] TODO-21: `smoke_test_run_comprehensive_suite.R`
  (`R/package_tests/`) — check whether this comprehensive smoke test
  exercises `InferenceSuite$run_all_inference()`, and if so, extend its
  coverage to include the new `combined_evidence` element (present with a
  non-`NA` `pval` when >=2 usable classes, `NA` and documented otherwise)
  so a future regression in the Cauchy-combination wiring surfaces there,
  not only in TODO-18's unit tests.

  **Done 2026-08-19: checked, does not apply.** Read
  `smoke_test_run_comprehensive_suite.R` directly -- it drives
  `run_comprehensive_suite.R`'s unrelated dependency-gate/argument-
  combinations/comprehensive-harness/public-workflow-coverage/internal-
  safety-nets pipeline for one hardcoded class
  (`InferenceAllSimpleMeanDiff`), and never constructs an `InferenceSuite`
  or calls `run_all_inference()` anywhere. TODO-21's own conditional ("if
  so, extend") does not trigger the extend branch, so no change was made
  to this file -- adding an `InferenceSuite`-specific check here would be
  scope creep into a harness that tests something else entirely.
  `combined_evidence` regression coverage instead lives where it actually
  belongs: `test-inference-suite-run-all-inference.R`'s structural
  `names(res)` assertion (includes `"combined_evidence"`) and TODO-18's new
  `test-cct-combine-pvalues.R`.

- [x] TODO-22: **Redesign `run_all_inference()`'s `methods` argument from a
  flat character vector of sentinels to a named list, `sentinel ->
  character vector of requested "type" values` (e.g. `list(bootstrap =
  c("percentile", "bca"), rand_bootstrap = NULL)`), with `NULL` (the
  default) meaning every sentinel, every valid `type` within each --
  "truly all the possible methods *and* all their resampling flavors."
  Blocked, by explicit user decision (2026-08-19), on `fix_inference_
  hierarchy.md`'s new `get_supported_*_types()` accessor-methods TODO
  (bootstrap-family components) -- do not ship this against a hardcoded,
  drift-prone `type`-choices table in `inference_suite.R`; wait for real
  runtime introspection.**

  Motivation: `EDI_INFERENCE_SUITE_METHOD_SENTINELS` (TODO-15-adjacent,
  11 sentinels as of 2026-08-19) covers *which testing procedure*
  (`wald`/`exact`/`rand`/`rand_bootstrap`/`jackknife`/`score`/
  `lik_ratio`/`gradient`/`param_boot`/`bayes_boot`/`bootstrap`), but three
  of those sentinels (`bootstrap`, `bayes_boot`, `rand_bootstrap`) each
  gate a method that itself takes a `type` argument selecting among
  several distinct resampling/CI-construction flavors (percentile,
  BCa, studentized, symmetric, smoothed, etc.) -- a second, currently
  invisible fan-out axis `run_all_inference()` has no way to request today
  (every bootstrap-family row silently uses whatever `type` the method's
  own default resolves to). Confirmed by reading source directly
  (`fix_inference_hierarchy.md`'s new TODO has the full per-method,
  per-side `type` value lists): the CI-side and p-value-side `type` choice
  sets are **not identical** for `bootstrap`/`bayes_boot` (e.g.
  `compute_bootstrap_confidence_interval()` accepts `"basic"` where
  `compute_bootstrap_two_sided_pval()` instead accepts `"symmetric"`), so
  this redesign must handle CI/pval `type` validity independently per
  sentinel, the same way `ci_method`/`pval_method` already resolve
  independently per row today. `rand_bootstrap` is the one sentinel where
  CI and pval already agree on the same four `type` values.

  Once unblocked: extend `run_all_inference_build_tasks()`'s fan-out to a
  third dimension (class x formula x method x type), disambiguating
  `results`/`results_table` row names with a `"<class>{<method>:<type>}"`
  tag when a class contributes more than one `type` for a given sentinel;
  add a `type` column to `results_table` alongside `method`; thread
  `type` through `run_all_inference_call_ci_for_method()`/
  `run_all_inference_call_pval_for_method()`, passing it to the
  underlying `compute_*` call only when that method actually accepts a
  `type` argument for that side (returning `NA` for a `type` value valid
  on one side but not the other, mirroring the existing "capability
  doesn't apply to this row" pattern rather than erroring). Full roxygen
  on the new `methods` shape, explaining every sentinel's valid `type`
  values (or "no type axis" for the eight non-resampling sentinels),
  analogous to the existing per-sentinel `\describe{}` block.

  **Done (2026-08-19), implemented once both blocking TODOs landed.**
  `methods` now accepts either shape: the legacy flat character vector
  (unchanged meaning), or a named list `sentinel -> character vector of
  requested type values, or NULL` (`run_all_inference_normalize_methods()`).
  `run_all_inference_build_tasks()` gained the third `type` fan-out
  dimension: for each applicable typed sentinel (`"bootstrap"`/
  `"bayes_boot"`/`"rand_bootstrap"`, `EDI_INFERENCE_SUITE_TYPED_SENTINELS`),
  one task per `type` value the class actually supports (via
  `run_all_inference_class_typed_task_types()`), intersected with any
  requested subset; a typed sentinel with zero resulting types still gets
  one task, `type = NA_character_` (mirrors the existing "no applicable
  method -> NA row" rule). `results_table` gained a `type` column next to
  `method`. `run_all_inference_call_ci_for_method()`/`_call_pval_for_
  method()` both gained a `type` parameter, passed to the underlying
  `compute_*` call only when `type %in% get_supported_*_{ci,pval}_types()`
  for that side -- otherwise degrading to `NA` with `method` still reported,
  exactly the existing "capability doesn't apply" pattern, never erroring.

  **Real runtime introspection, not a hardcoded type table, with one
  documented compromise**: `run_all_inference_probe_supported_types()`
  calls each class's own `get_supported_bootstrap_{pval,ci}_types()` etc.
  accessor (TODO-22's blocking prerequisite) on a constructed instance.
  Verified directly that the field defaults backing those accessors
  (`bootstrap_pval_types` etc.) are **not** reachable off the
  un-instantiated R6 generator (`cls$private_fields[[...]]` returns `NULL`
  for all of them, checked before writing any probing code) -- so probing
  requires one throwaway construction per (class, formula-slot, typed
  sentinel) during task-building, a deliberate, narrow, documented
  exception to this file's "discovery never constructs" rule, justified
  because the type vocabulary genuinely has no other queryable source.

  Roxygen on `methods` fully rewritten: the list-shape example, the
  "requesting `type` for a non-typed sentinel errors" rule, and each of the
  three typed sentinels' documented CI-side/pval-side `type` value sets
  (marked "(typed)" in the `\describe{}` block, confirming the CI/pval
  asymmetry `fix_inference_hierarchy.md`'s accessor TODO found for
  `"bootstrap"`/`"bayes_boot"` and the CI/pval agreement for
  `"rand_bootstrap"`). `type` folds into the `ci method`/`pval method`
  display columns (e.g. `"boot (bca)"`) via a new
  `method_with_type_short_label()` helper, shared by the live table and
  `print()`'s pretty table -- kept as its own real `type` column in
  `results_table` for programmatic use, not display-only.

  Verified via `pkgload::load_all(".", compile = FALSE)` (no full rebuild,
  per this repo's CLAUDE.md) against a real `DesignSeqOneByOneBernoulli`/
  `DesignFixedBernoulli` continuous fixture and `InferenceAllSimpleMeanDiff`:
  (1) `methods = list(bootstrap = c("percentile", "bca"), wald = NULL)`
  produced exactly 3 rows, `type` correctly `"percentile"`/`"bca"`/`NA`,
  all `status = "ok"`; (2) `methods = list(bootstrap = NULL)` (every type,
  no restriction) produced all 11 CI-side `type` values as separate rows,
  all `"ok"`, `html = TRUE` report generated successfully; (3) legacy flat
  `methods = c("wald", "rand")` unaffected, `type` correctly `NA` for both;
  (4) `methods = list(wald = c("percentile"))` (type requested for a
  non-typed sentinel) errors with a clear message naming the three typed
  sentinels. Two new `test-inference-suite-run-all-inference.R` cases cover
  (1) and (4) as permanent regressions; the existing structural
  `names(tbl)` assertion updated to include `"type"`.

- [x] TODO-23: **Derive `EDI_INFERENCE_SUITE_METHOD_SENTINELS`/
  `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`/
  `EDI_INFERENCE_SUITE_PVAL_METHOD_PRIORITY` via introspection of
  `contracts_mixins.R`'s `public_methods_for_capability` registry at
  load/call time, instead of keeping them as hand-maintained constants in
  `inference_suite.R` that can silently drift out of sync with the real
  capability registry. Blocked on `fix_inference_hierarchy.md`'s new
  "audit `public_methods_for_capability` for completeness" TODO --
  introspecting an incomplete registry only moves the staleness risk
  from one hardcoded list to another, so that audit must land and make
  the registry genuinely exhaustive first.**

  Motivation: the current 11-sentinel list was assembled by hand
  (2026-08-19), cross-checked against `public_methods_for_capability`'s
  12 keys at the time -- and even that manual cross-check needed two
  separate follow-up passes to catch real gaps the first pass missed
  (`RandomizationBootstrapCI`'s ungated CI capability, three separate
  ungated Bartlett-correction method variants, `m_out_of_n_bootstrap`/
  `subsampling` methods absent from the registry's own method-name
  lists entirely -- see `fix_inference_hierarchy.md`'s TODOs for the
  full detail on each). A hand-maintained constant has no way to notice
  when a new capability/method pair is added to `contracts_mixins.R`
  later and nobody remembers to mirror it here -- exactly the failure
  mode that produced this session's gaps in the first place, just
  discovered proactively this time instead of by a user hitting a
  silently-missing sentinel later.

  Once unblocked: replace the three hardcoded constants with a function
  (e.g. `run_all_inference_derive_method_sentinels()`) that reads
  `public_methods_for_capability` (by then complete, per the blocking
  audit) directly -- one sentinel per registered
  `compute_*_two_sided_pval`/`compute_*_confidence_interval` method pair,
  auto-deriving the sentinel label from the capability key (collapsing
  known intentional duplicates like `likelihood_ratio`/
  `estimating_equation_likelihood_ratio` onto `likelihood_tests`'s own
  `lik_ratio` sub-procedure, the same merge the current hand-built list
  already does manually) -- so adding a new capability/method pair to
  `contracts_mixins.R` automatically surfaces as a new `run_all_inference()`
  sentinel with no `inference_suite.R` change required. Keep the CI-side/
  p-value-side asymmetry TODO-22 already established (independent
  capability checks per side) rather than assuming a single shared
  capability suffices for every future sentinel derived this way.

  **Done (2026-08-19).** Implemented as designed, with one adjustment found
  necessary during implementation: a purely mechanical "one sentinel per
  capability key" auto-derivation turned out not to be a valid rule on its
  own (confirmed by reading the registry directly, not assumed) --
  `"wald"` registers two duplicate-alias method pairs
  (`compute_asymp_*`/`compute_wald_*`, same procedure), and
  `"likelihood_tests"` legitimately fans out into five sentinels
  (`score`/`lik_ratio`/`gradient`/`lik_ratio_bartlett_{approx,exact}`) from
  one capability. So `(capability, method, label)` triples remain an
  explicit spec table (matching this TODO's own text: "auto-deriving...
  collapsing known intentional duplicates" already implies human judgment
  stays in the loop) -- but each spec entry is now built by
  `run_all_inference_derive_method_priority()`, which `stopifnot()`s the
  named method is genuinely present under the named capability in the live
  `public_methods_for_capability` at package-load time, so a future rename/
  removal in `contracts_mixins.R` fails the package load loudly instead of
  `run_all_inference()` silently keeping a stale sentinel.

  The actual completeness guarantee is a separate function,
  `run_all_inference_check_sentinel_completeness()`: it enumerates every
  `compute_*_confidence_interval`/`compute_*_two_sided_pval`/`compute_*_pval`
  method registered anywhere in `public_methods_for_capability` (excluding
  the `likelihood_ratio`/`estimating_equation_likelihood_ratio` capabilities,
  intentional duplicates of `likelihood_tests`'s own methods) and asserts
  each one is either named in the CI/pval priority specs or explicitly
  listed in `EDI_INFERENCE_SUITE_DELIBERATELY_UNSENTINELED_METHODS` with a
  one-line reason (duplicate `wald` alias, plain Bartlett dispatcher,
  `m_out_of_n_bootstrap`/`subsampling` — open scope question, not this
  TODO's to resolve). Running this check against the real, current registry
  (via `pkgload::load_all(".", compile = FALSE)`, no full rebuild) found one
  genuine, previously-uncaught gap neither prior manual audit round caught:
  `compute_param_bootstrap_confidence_interval`/`compute_param_bootstrap_pval`
  (registered under `parametric_likelihood_bootstrap` alongside
  `compute_lik_ratio_bootstrap_*`, but a distinct procedure -- a direct
  parametric-bootstrap estimate/CI/pval for the treatment coefficient, not
  a bootstrap-calibrated LR test) -- added as a new 14th sentinel,
  `"param_boot_direct"`, with its own roxygen `\describe{}` entry
  explaining the distinction from `"param_boot"`. After that fix,
  `run_all_inference_check_sentinel_completeness()` returns `character(0)`
  against the live registry, landed as a permanent regression test
  (`test-inference-suite-run-all-inference.R`'s "sentinel tables stay
  complete against the live capability registry (TODO-23)").
  `EDI_INFERENCE_SUITE_METHOD_SENTINELS` itself is now `union()` of the two
  derived specs' labels rather than typed out a third time.
