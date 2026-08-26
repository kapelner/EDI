# Nominal Response Type Report

> **Depends on:** gated decision (TODO-1). Architecture prerequisites are
> all shipped: `fix_inference_hierarchy.md` (closed 2026-08-23) and
> `fix_design_hierarchy.md` (closed 2026-08-17) — every concrete class now
> goes through `define_inference_class()` / `define_design_class()` with
> registry metadata and components. Shares Stage 1 with
> `rank_choice_response_type_report.md` — do together if at all. (Global
> ordering: see `_master.md`; release index: `release_v1_1_0.md → TODO-1`
> step 8 and `→ TODO-6`.)

> **Rewritten 2026-08-27** after the two literature audits
> (`missing_inference_classes_literature_audit.md`,
> `missing_design_classes_literature_audit.md`) and a targeted sweep of
> published RCTs with nominal outcomes. Two things changed since the
> 2026-07 original and its 2026-08-14 patch: (1) the architecture it
> described has been replaced wholesale (shallow hierarchies, factories,
> registries, components, metadata-driven compatibility), so every
> "how the package would respond" section is rewritten against the current
> code; (2) the evidence on how common nominal outcomes are in *randomized
> experiments* turned out to be much weaker than the original report
> asserted, and the recommendation is revised accordingly — see
> "Recommendation on TODO-1" at the end. The feasibility verdict
> (moderate-to-hard) is unchanged.

## Scope

This report evaluates how difficult it would be to add a new
`response_type = "nominal"` to the package, where "nominal" means a
categorical outcome with ≥3 levels, no ordering of the levels, represented
most naturally as an unordered factor. This is distinct from the existing
`ordinal` type, which already has integer-coded storage, ordered-factor
support, level bookkeeping in `Design`, and 19 inference classes.

The report covers: the core plumbing needed to admit a new response type;
how the current factory/registry/component architecture would respond;
what the applied literature actually does with nominal outcomes; a
pragmatic set of nominal inference paths if the type is pursued; and a
recommendation on whether to pursue it.

## Short Answer

Adding the **label** `nominal` is easy. Adding a **coherent nominal
response type** that works across designs, `SimulationFramework`,
`InferenceSuite`, and a useful set of inference methods is a
**moderate-to-hard** project, because the package's estimand contract is
scalar (one treatment coefficient, one SE, one CI) and a nominal outcome
has no single natural scalar effect.

And — the new finding — the applied literature almost never asks for one.
In published randomized experiments with a nominal outcome, practitioners
recode to one-vs-rest binaries and run their standard binary estimator,
which EDI's 25-class incidence family already provides. See the next
section and the recommendation at the end.

## How Common Are Nominal Outcomes In Randomized Experiments?

The 2026-07 version of this report said nominal outcomes are "very common
in principle" and "common enough that a serious experimental-design
package should have a plan for them," citing a network-meta-analysis
methods paper, a trials protocol that lists "nominal" as an outcome scale,
and two political-science field experiments on vote choice / party ID.
None of those establish prevalence in RCTs. The 2026-08-26/27 audits
looked for actual published randomized experiments with a nominal outcome
and for any review quantifying them. Findings:

### No review counts them

Outcome-type censuses of RCTs (e.g. the JACC 2021 outcome-reporting
review; the binary-outcome practice review PMC7278160; Bruce et al. 2022;
Ooms et al. 2025) partition primary outcomes into binary / continuous /
time-to-event / ordinal and have **no nominal category**. The closest
analogue is Selman et al.'s scoping review of *ordinal* outcomes in
BMJ/NEJM/Lancet/JAMA 2017–2022 (PMC10998402): 144 RCTs, 59 with an ordinal
primary, of which 33% dichotomized even though proportional odds is well
known; that review explicitly excludes unordered outcomes and nobody has
done the nominal analogue — itself evidence the category is small.

### Where nominal outcomes do occur, and what practitioners do

Twenty published randomized experiments with a ≥3-level unordered outcome
were located across medicine, economics, education, political science and
marketing. In **18 of 20**, the analysis was one-vs-rest binary:

| Setting | Example | Analysis |
|---|---|---|
| Mode of delivery (vaginal / instrumental / caesarean) | BUMPES, *BMJ* 2017 (PMC5646262) | "spontaneous vaginal birth" primary; each level a separate log-binomial RR |
| Treatment chosen after a decision aid (AS / surgery / EBRT / brachy) | Lamers et al. 2021 (PMC8602175); Whelan *JAMA* 2004 | one-vs-rest logistic per option; collapsed to BCT-vs-not |
| Contraceptive method mix | Langston 2010; Dehlendorf *AJOG* 2019 | collapsed to "very effective method" yes/no |
| Discharge destination (home / rehab / SNF / died) | Aoki *PLoS One* 2024; REMAP NCT03861767 | descriptive proportions only |
| Occupation category | Blattman-Fiala-Martinez *QJE* 2014; Bandiera et al. *QJE* 2017 | separate LPM per occupation indicator |
| College enrollment (4-yr / 2-yr / none) | Bettinger & Evans *JPAM* 2019; Gurantz et al. *JPAM* 2021 | separate LPM per category |
| Vaccine brand chosen (A / B / neither) | Kreps & Kriner *PLoS One* 2022 | collapsed to A-vs-B share, ANOVA |
| Menu choice (3 dishes) | "Nudge the Lunch", *Games* 2021; Hansen *J Public Health* 2019 | share of meat dishes (binary) |
| Employment status (formal / informal / none) | Beam *J Dev Econ* 2016 | **multinomial logit** (econ exception) |
| Multi-party / multi-candidate vote choice | Borda-rule experiment, *Public Choice* 2025; Carlson *World Politics* 2015 | **multinomial / conditional logit** |

The two exceptions are political-science vote choice and one
labour-economics job-fair experiment — settings where the outcome *is* a
choice set and discrete-choice modelling is the disciplinary norm. Choice
experiments proper (conjoint, choice-based conjoint) are a different
paradigm (many randomized profiles per respondent) and are deferred in
`missing_design_classes_literature_audit.md` Part 4D / `rank_choice_...`.

No methodological commentary criticizing dichotomization of *nominal*
trial outcomes was found; the entire "don't dichotomize" literature is
about ordinal outcomes.

### Practical interpretation for this package

- Nominal outcomes are a **real but small niche** in randomized
  experiments: a handful of recurring settings, rarely primary.
- The dominant practice — in every field except political-science vote
  choice — is **one-vs-rest recoding**, which EDI already supports: recode
  `y` to `1{y = k}` and use any of the 25 incidence classes (LPM, logistic,
  log-binomial, modified Poisson, g-computation RD/RR, exact tests, KK
  variants), with full randomization/bootstrap inference.
- The only capabilities a recode does *not* give are (a) a single joint
  test on the full K-vector ("treatment changes the category distribution"
  — Pearson χ² / G² / Fisher-Freeman-Halton / permutation) and (b)
  multiplicity control across the K one-vs-rest contrasts. Both are
  multi-endpoint features and belong to
  `multivariate_response_type_report.md`'s `InferenceMultiEndpointComposite`
  (Holm; Fisher/O'Brien global test) rather than to a new response type.
- A native multinomial-logit estimator is a legitimate second-order
  feature for political-science users. It is not evidence of a compelling
  general need.

This reverses the original report's "very common in principle" framing:
the need is **not compelling**, and the cheapest way to serve the actual
use cases is documentation plus the already-planned multi-endpoint
wrapper.

## What Already Exists (as of 2026-08-27)

The package has 103 concrete inference classes and 27 concrete design
classes, all built through factories with registry metadata:

- **Response types** are a closed enum validated at
  `design_abstract.R:189` (`assertChoice(response_type, c("continuous",
  "incidence", "proportion", "count", "survival", "ordinal"))`). `ordinal`
  carries `ordinal_levels` / `original_ordinal_levels` (`design_abstract.R:177,
  212`) and factor→integer coercion in `add_one_subject_response()` /
  `add_all_subject_responses()`; `transform_y()` (`design_abstract.R:869`)
  accepts an `ordinal_levels` argument for transformed responses.
- **Inference classes** are declared via `define_inference_class(classname,
  inherit = Inference, components = c(...), ...)`; the old algorithmic
  bases (`InferenceAsympLikStdModCache`, `InferenceRand`, etc.) are now
  components (`StandardModelCache`, `LikelihoodTests`, `Wald`,
  `BayesianBootstrap`, `Randomization`, …; see
  `inference_class_registry.R:968` for the base→component map). Raw
  component splicing and component redeclaration of root-owned state are
  banned (Source Invariant 15).
- **Response-type compatibility is metadata-driven**, not
  try-and-catch: `infer_inference_response_types()`
  (`inference_class_registry.R:540`) assigns `response_types` from the
  class-name prefix (`^InferenceContin` → continuous, `^InferenceIncid` →
  incidence, …, `^InferenceAll` → all six), and
  `InferenceSuite`/`SimulationFramework` filter with
  `is_inference_class_compatible_with_design_metadata()`
  (`inference_suite.R:69`). A class with an empty `response_types` vector
  is never offered.
- **Design classes** are declared via `define_design_class()` with
  `timing_family` / `randomization_family` metadata and components
  (`BlockingStructure`, `MatchingStructure`, `ClusterStructure`, …). No
  design restricts `response_type`.
- **`SimulationFramework`** transforms a latent continuous signal per
  response type in one `switch(response_type, …)` (`simulations_framework.R:167`)
  and picks curated default inference classes per type
  (`.default_inference_classes()`, `simulations_framework.R:4222`).
- **`InferenceSuite$run_all_inference()`** (shipped, v1.0.0 item 13)
  fits every compatible class with one uniform output schema — so a new
  type's classes would surface there automatically once registered.
- **Marginal estimands** (`set_estimand()`, `marginal_estimand_report.md`,
  shipped) give g-computation-style risk difference / risk ratio for
  binary outcomes — the natural home for a "focal-category risk
  difference" should one ever be wanted.

So the mechanics of adding a response type are now much more uniform than
when this report was first written: add the enum value, add a
`^InferenceNominal` prefix rule to `infer_inference_response_types()`, and
every registry/suite/simulation consumer picks it up. What has *not*
changed is the scalar-estimand contract that makes nominal awkward.

## Difficulty By Layer (current architecture)

### 1. `Design` base class: moderate

- add `nominal` to the `assertChoice` at `design_abstract.R:189`;
- generalize the `ordinal_levels` bookkeeping into a shared
  `categorical_levels` slot (or add `nominal_levels` alongside);
- unordered-factor coercion in `add_one_subject_response()` /
  `add_all_subject_responses()` and `assert_y()`;
- `transform_y()` semantics for nominal (probably: disallowed).

Not difficult, but real work because non-ordinal responses are assumed
numeric and `ordinal` is the only factor-backed special case.

### 2. Concrete design classes: easy

All 27 are response-type agnostic after initialization — except:

### 3. `DesignSeqOneByOneKK21` / `KK21stepwise`: moderate to hard

`compute_weights()` (`design_seq_one_by_one_KK21.R:324-361`) branches on
`response_type` to fit a per-covariate response model (OLS, logistic, NB,
beta, AFT, proportional-odds) and use |t| as the covariate's matching
weight. Nominal needs either a multinomial-logit per-covariate weight
(a new `kk21_nominal_weights_cpp()` kernel — moderate) or a documented
approximation. Same pattern every other response-type report flags.

### 4. Inference classes: the estimand problem is unchanged

Every inference class exposes one scalar `compute_estimate()`, one
`get_standard_error()`, one CI, one p-value. For nominal there is no
single obvious scalar effect: a vector of category-specific log-odds
ratios vs a baseline; a focal-category contrast; a scored expected-utility
shift; or a global no-effect statistic with no estimate. This choice
drives model output shape, the CI/p-value API, `SimulationFramework`
truth, and summary-table shape. Until fixed, `nominal` is a storage type,
not an inferential family.

The generic classes that would silently accept integer-coded nominal
levels and produce nonsense are exactly those with `^InferenceAll`
prefixes (`InferenceAllSimpleAverageDiff`,
`InferenceAllSimpleMeanDiffPooledVar`, `InferenceAllSimpleWilcox`,
`InferenceAllKKMeanDiffIVWC`, `InferenceAllKKWilcoxIVWC`) plus the planned
`InferenceAllWinOdds` / `InferenceAllQuantileDiff` from the inference
audit. Under the current architecture the fence is one line: exclude
`"nominal"` from the `^InferenceAll` branch of
`infer_inference_response_types()` (or add a per-class
`excluded_response_types` metadata field), and the suite/simulation
consumers will never offer them. No per-class `assertResponseType()` edits
needed.

### 5. `SimulationFramework`: hard

Needs a nominal generator (latent utilities + softmax, or
reference-category logits) in the `switch` at `simulations_framework.R:167`;
a definition of `betaT` for nominal; a scalar "truth" for MSE/coverage/
power; and a curated default class set. A fully multinomial effect is
vector-valued, so either the framework generalizes to vector estimands or
nominal simulation targets one focal-category contrast. This remains the
most expensive integration point.

## Candidate Nominal Inference Paths (if pursued)

Unchanged from the original report, restated for the component
architecture:

1. **`InferenceNominalCategoryContrast`** — pick focal category `k`,
   derive `1{y = k}`, delegate to an incidence class. Easy. Note this is
   *exactly* what the literature does by hand; the class would add
   convenience, not capability.
2. **`InferenceNominalPearsonChisq`** — global K×2 test (Pearson χ² /
   G² / Fisher-Freeman-Halton exact / permutation). Moderate. A test
   without a scalar estimate + CI, so it needs the "p-value-only"
   contract shape. Overlaps with the multi-endpoint composite plan.
3. **`InferenceNominalMultinomLogit`** — baseline-category multinomial
   logit via `define_inference_class(components = c("LikelihoodTests",
   "StandardModelCache", "Wald", …))`, with a scalar focal-category
   treatment coefficient first and the full vector later if a
   vector-valued contract is ever adopted. Moderate to hard; needs a new
   C++ kernel following `sexp_removal_rcppeigen_conversion_spec.md`
   conventions.
4. **Stratified nominal test / CMH generalization** — second wave, if ever.

## Recommendation on TODO-1 (2026-08-27)

**Recommend: do not pursue `response_type = "nominal"`; defer
indefinitely.** Rationale, in order of weight:

1. The literature evidence for a compelling need is thin: no review counts
   nominal RCT outcomes, and 18 of 20 located examples use one-vs-rest
   binaries that EDI already supports with a recode.
2. The one genuinely new capability (a joint K-vector test with
   multiplicity control across K contrasts) is a multi-endpoint feature
   and is already scoped in `multivariate_response_type_report.md`
   (`InferenceMultiEndpointComposite`). Build it there, once, for every
   K-outcome situation, instead of a nominal-specific version.
3. The remaining beneficiaries (political-science vote-choice
   experiments) are better served by the choice-experiment paradigm in
   `rank_choice_response_type_report.md`, which is itself deferred.
4. Cost is moderate-to-hard (estimand contract, KK21 kernel,
   `SimulationFramework`), and the two literature audits surfaced
   many higher-frequency gaps (count exposure offsets, HC-robust SEs,
   CACE/IV, cluster-level balancing designs, competing risks) that should
   be sequenced first.

**Cheaper alternative that covers the actual use cases:** a vignette
section (in `R/EDI/vignettes/extending-edi.Rmd` or a new
"response types" vignette) documenting the one-vs-rest recode pattern —
`des$transform_y(function(y) as.integer(y == k), "incidence")` per focal
category, or K parallel designs — with a pointer to the multi-endpoint
composite wrapper for joint testing once it ships. Zero new classes.

If the user nonetheless says yes to TODO-1, the staged plan below is the
right shape and Stage 1 should be spliced with
`rank_choice_response_type_report.md` so the type is admitted once.

## Implementation TODOs

- [ ] TODO-1: **Decide whether to implement this at all — ask the user.**
  Recorded recommendation (2026-08-27): **no / defer indefinitely**, for
  the reasons above. Do not start TODO-2..4 until a decision is recorded
  here. If the decision is "no", replace TODO-2..4 with the vignette
  item below and move this report to `../finished_features/` as a
  closed scoping report.
- [ ] TODO-1b (if "no"): write the one-vs-rest recode vignette section and
  cross-reference `multivariate_response_type_report.md` for joint tests.
- [ ] TODO-2 (if "yes"): Stage 1 — admit `nominal` safely: enum at
  `design_abstract.R:189`, level bookkeeping, factor coercion, `assert_y()`;
  fence `^InferenceAll` classes via `infer_inference_response_types()` /
  registry metadata rather than per-class asserts. Spliced with
  `rank_choice_… → TODO-2`.
- [ ] TODO-3 (if "yes"): Stage 2 — `InferenceNominalCategoryContrast`
  (delegating to incidence) and `InferenceNominalPearsonChisq`; decide the
  p-value-only contract shape with the multi-endpoint plan.
- [ ] TODO-4 (if "yes"): later waves — `InferenceNominalMultinomLogit`
  (new kernel), KK21 nominal weights, `SimulationFramework` generator and
  truth — each gated on the estimand decision.
