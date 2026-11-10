# `DesignDiagnostics`: Pre-Inference Design and Balance Reporting

> **Depends on:** `model_diagnostics_framework.md` (the model-side sibling —
> shares the registry-declared-checks philosophy, and the two are meant to
> become one combined pre-analysis report: design diagnostics first, model
> diagnostics second); the `draw_ws_according_to_design()` replay contract
> every design class already implements (the randomization-distribution
> plot, §3D, is a consumer of this existing machinery, not a new
> mechanism); `InferenceSuite`'s shipped `run_all_inference(plots=,
> html=)` visualization plumbing (`R/EDI/R/inference_suite.R`), reused for
> the reporting layer rather than duplicated. **Release target: v2.0.0**
> (wiring into `release_v2_0_0.md` / `_master.md` to follow).

Written 2026-09-10 (user request: scope design-side diagnostics —
covariate-balance/Love plots, a picture of the randomization distribution
— informed by a literature search on what tables and figures experimenters
conventionally produce *before* running inference on outcomes).

Commissioned by a gap `model_diagnostics_framework.md` itself flagged:
"design-side diagnostics (match quality, reservoir size, within-pair
distance distributions for the KK designs) are a natural adjacent panel
but **out of scope** — they diagnose the design, not a model; candidate
follow-on plan." This is that plan.

## 1. Why

`ModelDiagnostics` (once built) checks whether a *fitted model's*
assumptions hold. Nothing in the package checks whether the *realized
design* itself looks the way it should before any model is even fit.
Randomization only balances covariates in expectation, not on every single
draw — a matched design's structure can be audited independently of any
downstream model, and the randomization/permutation distribution an exact
test is built on is currently reported only as a p-value, never shown.
This matters most exactly where EDI's own inference philosophy leans on
the design: randomization-based (`ci_method = "rand"`) inference is only
as trustworthy as the realized randomization actually looks in the report,
not just in theory.

## 2. Architecture: `DesignDiagnostics(des_obj)`, registry-declared like its sibling

Same philosophy as `ModelDiagnostics`: a new registry field on
`define_design_class()` metadata (e.g. `diagnostic_checks`) names each
check and its applicability by **design family** — fixed vs. sequential,
matched vs. blocked vs. clustered vs. plain CRD/Bernoulli all warrant
different checks (within-pair distance only applies to matched designs;
accrual-balance-over-time only applies to sequential ones).
`DesignDiagnostics$new(des_obj)` discovers the design's class the same way
`InferenceSuite`/`ModelDiagnostics` discover applicable inference classes,
then pulls its declared battery from the registry. An undeclared class
shows a typed `no_declared_checks` row — never silent omission, same rule
as the model-side sibling.

Temporally, this report comes *before* `ModelDiagnostics`/`InferenceSuite`
in an analysis workflow (design diagnostics characterize what happened
before any model is fit), but the three are meant to eventually share one
report surface: design realized as expected → models trust themselves →
here's what they estimate, as three panels of one document.

## 3. The catalogue

From a literature search on pre-inference design/balance reporting
conventions (clinical-trial reporting guidelines, the causal-inference
matching literature, and the R packages that are the de facto standard
tools for this already — `tableone`/`table1`, `cobalt`, `MatchIt`), mapped
to which EDI design families each applies to.

### A. Baseline characteristics table ("Table 1")

CONSORT 2025 explicitly recommends a per-arm table of baseline
demographic/clinical covariates. A load-bearing methodological point from
the literature: CONSORT discourages **significance-testing** these
differences — randomization already guarantees exchangeability in
expectation, and testing it invites the well-documented "Table 1 fallacy"
(a recent meta-research study found ~48% of trials still wrongly report
baseline p-values despite longstanding guidance against it). EDI's table
must be descriptive only (mean/SD or count/%, by arm) and **never emit a
per-covariate p-value or star**, with the report explaining why in the
table's own caption. Universal — applies to every design family. R
precedent: `tableone`/`table1`.

### B. Standardized mean difference / Love plot

Per-covariate SMD — `|mean_T − mean_C| / pooled SD` — with the
conventional 0.1/0.05 "adequate balance" thresholds (the `cobalt` package
convention), rendered as a Love plot (one row per covariate, a point at
its SMD, reference lines at the thresholds). The workhorse balance check;
universal across every ≥2-arm design with covariates. For matched/blocked
designs, show before- vs. after-structure SMD side by side (the
`cobalt`/`MatchIt` "raw vs. adjusted" convention) — directly relevant to
`DesignFixedBinaryMatch`/`DesignFixedOptimalBlocks`/`DesignFixedCluster`.

### C. Full-distribution overlays (eCDF)

Beyond first-moment SMD: an empirical-CDF overlay per covariate by arm
(`MatchIt`'s `type = "ecdf"` convention), optionally supplemented by the
Kolmogorov–Smirnov statistic as a numeric companion. Catches distributional
imbalance (variance, shape) a mean-only SMD misses. Same scope as B.

### D. The randomization distribution itself

Not primarily from external literature — this is EDI's own machinery made
visible. Every design already implements `draw_ws_according_to_design()`,
the replay contract every randomization test and `ci_method = "rand"`
computation already uses. The plot: redraw the design `N` times under its
own randomization mechanism, compute the test statistic on each redraw,
histogram it, mark the observed statistic with a vertical line — the
conventional way the randomization-inference literature *shows* a Fisher
Randomization Test rather than only reporting its p-value. A direct visual
companion to every `ci_method = "rand"` row `InferenceSuite` already
produces — no new statistical machinery, only a plot consuming draws the
package already generates internally. Applies to every design that
supports replay (fixed and sequential alike).

### E. Propensity/selection-mechanism overlap — `DesignObservational*` only

For designs where treatment assignment is not researcher-controlled — a
propensity-score overlap/common-support plot (mirrored histograms or
kernel densities by arm), from the propensity-score-matching literature
(Rosenbaum–Rubin lineage; the `MatchIt`/`cobalt` convention). **Explicitly
out of scope for fixed/sequential randomized designs** — they have
known-by-construction assignment probabilities, so "overlap" is not a
meaningful diagnostic for them the way it is for observational designs.
Scope this check to `DesignObservational*` only.

### F. Match/cluster/block structure diagnostics — matched/clustered families only

Within-pair (or within-block/within-cluster) covariate distance
distribution — is the matching/blocking doing its job at the
unit-structure level, not just in the aggregate-arm SMD. Applies only to
`DesignFixedBinaryMatch`/`DesignFixedOptimalBlocks`/`DesignFixedCluster`/
the KK matching-on-the-fly family. Related to, and a visual companion of,
the **Grundy-Healy concurrence diagnostic** already catalogued as
`missing_theoretical_design_classes_literature_audit.md` item **#43** (a
numeric diagnostic: `max_{i,j} |P(w_i = w_j) − const|` over the design
distribution) — cite and visualize that statistic here; do not
re-derive it.

### G. Sequential-design accrual/balance-over-time — `DesignSeqOneByOne*`/`DesignSeqManyByMany` only

A jitter/strip plot of arm assignment against arrival order, and a
running-imbalance-over-time line (the `D_n` trajectory every sequential
coin is already designed to bound). Well-motivated by the sequential-design
literature generally (minimization/CAR methods are conventionally
evaluated exactly on their imbalance trajectory), but I did not find one
single named "accrual balance plot" convention as canonical as the Love
plot or eCDF overlay — `NEEDS VERIFICATION` for a specific citation; treat
as domain-convention-informed rather than a single named source.

## 4. Visualization / reporting layer

The same three-tier approach already proven in `InferenceSuite`
(`run_all_inference(plots=, html=)`), reused rather than reinvented:

- **ggplot2 static plots** — Love plot, eCDF overlay, randomization-
  distribution histogram, propensity-overlap density, within-pair-distance
  plot, accrual balance-over-time line — one function per plot type,
  following the same `run_all_inference_plot_*` naming/structure
  convention already in the codebase.
- **HTML report** — one `render_html()` surface analogous to
  `run_all_inference_render_html()`, rendering the baseline table (A, no
  p-values) and the Love plot (B) together, built toward the eventual
  shared-report goal with `ModelDiagnostics`/`SolverDiagnostics`.
- **plotly/DT interactivity** — new relative to what `InferenceSuite`
  ships today (its HTML tables are currently static). An interactive Love
  plot (hover → exact SMD + covariate name) and a sortable/filterable
  `DT::datatable()` for the baseline table are natural fits here — a wide,
  dense Table 1 is exactly the case interactivity helps most. If this
  lands, it shares its `interactive =` convention with
  `inference_suite_interactive_reporting.md` (added 2026-09-10, also
  v2.0.0), the matching retrofit onto `InferenceSuite`'s existing static
  HTML tables and forest plot — a cross-reference to that plan, not a new
  obligation of this one.

## Tests

- Registry discovery: undeclared design class → typed `no_declared_checks`
  row; declared check → typed result or typed failure, never silence
  (same pattern as `model_diagnostics_framework.md`'s own tests).
- Known-imbalance recovery: a deliberately unbalanced synthetic covariate
  is flagged by the SMD/eCDF checks at reasonable power; a balanced one is
  not flagged at gross excess of nominal rate.
- Randomization-distribution plot is golden against `compute_rand_*`
  internals' own draws — the plot must never show a distribution different
  from the p-value it illustrates.
- Baseline table never emits a per-covariate p-value or star under any
  option (assert on output structure, not just documentation).
- Family-scoping: the propensity-overlap check is absent from every
  fixed/sequential randomized-design report and present only for
  `DesignObservational*`; match/cluster and accrual-balance checks appear
  only for their respective families.

## TODOs

- [ ] TODO-1: **Decision gate** (ask the user, no code) — registry field
  shape, typed result contract (mirroring `model_diagnostics_framework.md`
  TODO-1's shape), and ratify "no significance testing of baseline
  balance" as a hard invariant rather than a default.
- [ ] TODO-2: **Declaration contract** — the registry field on
  `define_design_class()` metadata; discovery mechanism paralleling
  `ModelDiagnostics`'s.
- [ ] TODO-3: **Universal pilot battery** — baseline table (§A) and
  Love plot / SMD (§B), since both apply to every design family; ship
  first.
- [ ] TODO-4: **Randomization-distribution plot** (§D), consuming the
  existing replay contract — no new statistical machinery.
- [ ] TODO-5: **Family-scoped checks** — eCDF overlay (§C), propensity
  overlap for `DesignObservational*` only (§E), match/cluster structure
  diagnostics visualizing the existing Grundy-Healy statistic (§F),
  sequential accrual-balance-over-time (§G).
- [ ] TODO-6: **Reporting layer** — the ggplot2 functions, HTML report,
  and plotly/DT interactivity (§4).
- [ ] TODO-7: **Documentation** — vignette, roxygen, and the
  cross-reference to `model_diagnostics_framework.md` for the eventual
  combined design+model pre-analysis report.

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were not fetched
from the primary source and must be checked before citation in
roxygen/`REFERENCES.md`.)

- CONSORT 2025 statement — baseline-characteristics table recommendation.
  *PMC11995449*, *PMC11996237*. `NEEDS VERIFICATION` (full citation
  details).
- "The Enduring Table 1 Fallacy: A Meta-research Study of Baseline Testing
  in Anesthesiology and Pain Trials" — *PMC12677328* (the ~48%
  baseline-p-value-testing-despite-guidance finding motivating §A's hard
  no-testing rule). `NEEDS VERIFICATION` (full citation details).
- Greifer, N. — `cobalt`: Covariate Balance Tables and Plots (CRAN/GitHub
  `ngreifer/cobalt`) — Love plot, SMD conventions and thresholds (§B).
- Ho, D. E., Imai, K., King, G., and Stuart, E. A. — `MatchIt` package and
  its "Assessing Balance" vignette — eCDF balance plots, Kolmogorov–Smirnov
  statistic (§C). `NEEDS VERIFICATION` (primary paper citation).
- Rosenbaum, P. R., and Rubin, D. B. (1983) — propensity score / common
  support, foundational citation for §E. `NEEDS VERIFICATION` (not fetched
  from primary source this pass).
- Ritzwoller, D. M. — "Randomization Inference: Theory and Applications"
  (review) — the permutation/randomization-distribution visualization
  convention motivating §D. `NEEDS VERIFICATION` (venue/year).
- SPIRIT 2025 statement — protocol reporting of allocation-sequence
  generation; weaker direct support for §G's accrual-balance-over-time
  item specifically. `NEEDS VERIFICATION`.
- Cross-reference (not a new citation): `missing_theoretical_design_classes_literature_audit.md`
  item #43, the Grundy-Healy concurrence diagnostic §F visualizes.
