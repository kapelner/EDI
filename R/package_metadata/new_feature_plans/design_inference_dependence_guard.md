# Design/Inference Dependence-Structure Guard

> **Depends on:** none for the guard mechanism itself. TODO-1's two-speed
> rollout references `cluster_robust_inference_glmm_gee.md` (5Y, v2.0.0)
> for the general-clustering case that has no corrected alternative yet.
> Release target: v1.1.0 (`release_v1_1_0.md → TODO-21`).

Written 2026-09-09, growing out of a conversation about why
`DesignFixedBinaryMatch` — and any blocking/clustering design — currently
permits constructing an ordinary, dependence-naive inference class (e.g.
plain logistic regression) that treats matched/blocked/clustered rows as
iid. **Revised same day**, before any code was written, after a direct
challenge to the first draft's premise: would this actually forbid
`InferenceAllAverageDiff`-style plain mean-difference classes on a
*blocking* design? Working the statistics through (below) says that
specific case should never have been gated in the first place — the draft
conflated "unmodeled dependence" with "wrong variance," which only holds
in one direction for one estimand family. This version replaces the single
binary gate with a severity model that depends on *which computation path*
and *which estimand family* a class uses, not just on whether the design
has structure the class doesn't declare. **Revised again same day**
(second challenge: Tier 1 being *legal* — it doesn't break size — isn't a
reason to stay silent about it, and showing every legal-but-known-inferior
computation in `run_all_inference()`'s sweep risks diluting a comparison
table with numbers a user shouldn't weight equally). Tier 1 now gets a
real, visible warning and a results-table flag instead of a
discovery-metadata footnote nobody reads — see "Levels of warning, not
just tiers of gating" in Proposal, and "Why Tier 1 classes stay in the
sweep" for why that's a labeling fix, not an exclusion.

Companion to `missing_inference_classes_literature_audit.md` item #2 and
`cluster_robust_inference_glmm_gee.md` (5Y): that plan builds the correct
general-purpose cluster-robust alternative; this plan stops silent misuse
of the existing wrong ones — narrower than the first draft, but for the
cases that are actually dangerous.

## Why

`is_inference_class_compatible_with_design_metadata()`
(`inference_suite.R:69-83`) is the coarse "warding" gate `discover_
applicable_inference_classes()` (`inference_suite.R:136-164`) and
`Design$applicable_inference_class_names()` (`design_abstract.R:624-626`)
run every candidate class through. It only encodes one direction: whether
the design provides structure a class *requires* to be computed at all
(`requires_kk`, `requires_blocking`, response type, censoring support). It
has no dimension for the opposite question: whether the design *imposes*
dependence — blocking, KK/matching pairs, clustering — that a candidate
class's default (asymptotic/Wald) variance computation doesn't account
for. A comment next to `InferenceIncidCMH`'s own hand-written structural
check says this plainly: these are "design-*structure* requirements
`infer_inference_response_types()`/`requires_blocking_design` have no
vocabulary for" (`inference_incidence_cmh.R:126-134`).

**But "unmodeled dependence" is not one failure mode — it splits at least
three ways, and only some of them are actually wrong:**

1. **Randomization-based (`ci_method = "rand"`) inference is already
   exact, regardless of whether the class declares any dependence
   awareness.** `compute_rand_confidence_interval()`/`compute_rand_two_
   sided_pval()` (`inference_all_abstract_rand_ci.R`) build their
   reference distribution by re-drawing treatment assignment through the
   design object itself (`assert_design_supports_randomization_draw()`,
   `inference_all_abstract.R:934-939`), and `BlockingStructure`/
   `MatchingStructure`/`ClusterStructure`'s own `draw_bootstrap_indices`
   overrides (`design_component_registry.R:314-507`) already respect
   blocks, pairs, and clusters. A sharp-null permutation p-value is exact
   for *any* test statistic, linear or not, under whatever randomization
   actually produced the data — the class doesn't need to "know" about
   the design's structure because the design tells it, every replicate.
   **The guard below only ever needs to apply to the closed-form/Wald
   path**, never to `rand`.

2. **Linear-contrast estimands (difference in means, risk difference,
   OLS coefficients) on blocking/matching designs, computed via the naive
   pooled/unpaired Wald formula, are conservative — not wrong.** Take
   matched pairs as the cleanest case: pair `j` has `Y_Tj = mu + b_j + tau
   + e_Tj`, `Y_Cj = mu + b_j + e_Cj`, pair effect `b_j` (variance
   `sigma_b^2`) shared by both arms of the pair, idiosyncratic noise `e`
   (variance `sigma^2`). The paired difference `D_j = Y_Tj - Y_Cj = tau +
   (e_Tj - e_Cj)` has the pair effect cancel entirely: `Var(D_j) =
   2*sigma^2`. Crucially, `mean(D_j)` **is** the ordinary
   difference-in-means estimator (`mean(Y_T) - mean(Y_C)`) — the same
   number, computed two ways — so the point estimate is identical whether
   or not the class "accounts for" pairing. The *naive pooled* Wald
   variance formula instead estimates `Var(Y_Tj)` and `Var(Y_Cj)`
   separately, each of which is `sigma_b^2 + sigma^2` (it hasn't
   differenced away the pair effect, because it never paired anything),
   giving `2*(sigma_b^2 + sigma^2)/n \ge 2*sigma^2/n` — the true variance
   of the very same estimator. The naive formula can only ever *add* a
   nonnegative, already-canceled-in-truth component. This is the textbook
   "unpaired *t*-test on paired data" result: valid coverage, lost power,
   never inflated Type I error, whenever pairing/blocking induces positive
   within-block correlation (the entire reason to block in the first
   place). **`InferenceAllAverageDiff`-style classes on a blocking or
   matching design belong in this tier — not gated.**
3. **Nonlinear-link estimands (logistic regression and other GLM
   coefficients) on blocking/matching designs are a genuinely different,
   more dangerous case.** There is no analogous cancellation: omitting a
   real block/pair random effect from a nonlinear-link model both
   attenuates the coefficient toward the null (noncollapsibility — already
   a named axis in this codebase, see `marginal_estimand_report.md`'s
   `estimand` metadata and `fix_inference_hierarchy.md:6284-6328`'s
   marginal-vs-conditional notes) *and* can leave the naive
   working-independence Fisher-information SE understating the true
   sampling variability of that same (already biased) estimate — a
   correctness risk on both the point estimate and the variance, not just
   lost power. This is exactly why conditional/matched-pair logistic
   regression (the KK pair family) exists as a distinct method rather than
   a mere efficiency upgrade.
4. **Clustering — units sharing one treatment assignment — is dangerous
   for any estimand, linear or not**, the standard motivation for
   cluster-robust SEs: treating individually-correlated observations that
   all received the same assignment as independent replicates understates
   the true variance, because the effective sample size is the cluster
   count, not the row count. `missing_inference_classes_literature_
   audit.md:71-72`: "there is no general model-based cluster-robust-SE or
   random-cluster-intercept GLMM/GEE outside the KK pair machinery."

So the registry's missing vocabulary is real, but the fix is a **tiered
severity model keyed to (estimand linearity) × (which capability) × (which
compute path)**, not a single "dependence-naive ⇒ gate" bucket.

**None of this needs re-deriving per class.** The obvious risk with a
tiered model is that it looks like it needs bespoke math for every
(design-dependence-capability × response-type × estimand) cell — that
would be infeasible and error-prone to get right one cell at a time. It
doesn't, because points 2–4 above are each an instance of one of two
already-established, estimator-agnostic results, not a fact specific to
`InferenceAllAverageDiff` or to matched pairs:

- **The sign of the naive-SE error is a structural property of the
  *design*, not of the estimator.** In M-estimation/sandwich-variance
  terms (Huber/White; Liang & Zeger 1986 for the GEE case), ignoring
  within-group correlation biases the naive (working-independence)
  variance by a correction term whose sign follows the sign of the
  correlation between the group's members' contributions to the
  parameter's own estimating equation. When a group's members are split
  across arms (blocking/matching — the whole reason to block is that
  same-block units are similar, so a treated and control member pull the
  treatment-effect estimating equation in *opposite* directions), that
  correction is negative — the naive formula overshoots, conservative.
  When a group's members share one arm (clustering), the correction is
  positive — the naive formula undershoots, anti-conservative. This is
  the same reasoning that justifies "cluster-robust SEs only ever widen
  the naive SE" as a general textbook fact, not a fact re-derived per
  model family. It holds for OLS, logistic, Poisson, or anything else
  estimated by an unbiased estimating equation. So the design-level
  classification — does capability X (blocking/matching vs. clustering)
  split correlated units across arms or keep them in one arm — needs
  answering **once per design class** (already evident from whether it
  composes `BlockingStructure`/`MatchingStructure`, which split by
  construction, vs. `ClusterStructure`, which shares by construction —
  `design_component_registry.R:314-507`), not once per `(inference class,
  design)` pair.
- **Noncollapsibility is a structural property of the *link function*,
  not of the specific class.** Every identity-link linear-in-parameters
  estimand (mean/risk difference, OLS, and — because collapsibility here
  only requires the mean model to be additive and doesn't require it to
  be scale-invariant under a random-effects shift — most log-link
  rate-type estimands with an additive treatment contrast) inherits
  result 2 above for free: no cancellation trick needed for
  every estimator, just confirmation that its estimating equation is
  linear in the response. Every genuinely nonlinear-link estimand (logit,
  probit, cloglog — the standard noncollapsible links; Neuhaus, Kalbfleisch
  & Hauck 1991 and the broader marginal-vs-conditional GLMM literature
  this codebase already cites via `marginal_estimand_report.md`) inherits
  result 3 for free. So `estimand_linearity` is a **link-function lookup**
  (already implicit in each class's own model specification — logistic
  regression classes use `logit`, mean/risk-difference and OLS classes use
  `identity`), not a per-class derivation. Default to `"nonlinear_link"`
  (the conservative, Tier-2 assignment) for anything not confirmed
  identity/collapsible, so an unclassified or ambiguous case fails safe
  (an unneeded advisory/gate) rather than fails dangerous (silently wrong).

Both results assume the textbook conditions this codebase's designs are
generally built to satisfy — constant treatment probability within a
block/pair, exchangeable block/cluster effects. Designs that violate those
conditions (uneven allocation across blocks, for instance) are a *bias*
problem independent of this guard, and are already handled by narrower,
class-specific checks where it matters today (`InferenceIncidCMH`'s own
`design_compatibility_reason`, `inference_incidence_cmh.R:135-151`, already
rejects uneven allocation for blocking designs). Where a design or class
genuinely falls outside the textbook case (see Abadie, Athey, Imbens &
Wooldridge, *When Should You Adjust Standard Errors for Clustering?*, QJE
2023, for the boundary conditions on the clustering side specifically),
that's scoped as its own narrower follow-up, not folded into this guard's
default classification.

**Why Tier 1 classes stay in the sweep instead of being excluded.** Legal
(size-preserving) is not the same as "don't bother telling anyone" — a
class that's provably conservative for this design is exactly the kind of
fact a user should see, even though it isn't wrong. But the fix for that
is *visibility*, not exclusion, because "pollution" is really two
different concerns that need two different answers:

- **Same estimand, dominated computation** (a class's own Wald CI is
  conservative on this design while its own `rand` CI, from the same
  fitted object, is exact) — this really is redundant once you know it,
  and is exactly what the warning below targets: don't let the dominated
  number sit unlabeled next to the better one.
- **Different estimand, different class** (e.g. a marginal risk
  difference next to the KK pair family's conditional log-odds ratio on
  the same `DesignFixedBinaryMatch`) — this is not redundancy, it's the
  documented, deliberate point of `run_all_inference()`: "different valid
  keys legitimately report different numbers from the same design ... the
  reason `run_all_inference()` reports multiple differing results by
  design" (the lock-and-key metaphor work, `release_v1_1_0.md → TODO-19`,
  `lock_key_metaphor.md`). Excluding Tier 1 classes outright would remove
  legitimate estimands from the comparison, not just redundant restatements
  of one.

So the fix is: flag the first kind loudly, leave the second kind exactly
where the suite's own design already puts it. Excluding Tier 1 by default
would also cut against this release's own standing constraint that
default results must reproduce 1.0.0 bit-for-bit outside of Tier 2 — a
silent exclusion is itself a default-result change nothing before this
plan asked for.

## Proposal

- **`Design$dependence_structure()`** — a new accessor reporting, for
  each of `blocking` / `matching` (KK-pair) / `clustering` the concrete
  design composes, both that it's present *and* which of the two
  structural shapes it is: **`splits_arms`** (`BlockingStructure`/
  `MatchingStructure` — correlated units are, by construction, assigned to
  different arms) or **`shares_arm`** (`ClusterStructure` — correlated
  units are, by construction, assigned the same arm). No new design-side
  state and no per-design derivation: every design composing
  `BlockingStructure`/`MatchingStructure` gets `splits_arms` and every
  design composing `ClusterStructure` gets `shares_arm` unconditionally,
  since that shape is fixed by which component the design class declares
  (`design_component_registry.R:314-507`), not by anything data-dependent.
  This one field, decided **once per design class** (a handful of classes,
  not one per `(class, design)` pair), is what determines the sign of the
  Wald-SE error per the sandwich-variance argument below — the guard never
  needs to re-derive it per design instance.
- **Per-class audit metadata, two small fields, not one:**
  - `estimand_linearity` — `"linear_contrast"` (identity-link mean/risk
    difference, OLS coefficients, and additive-contrast log-link rate
    estimands) or `"nonlinear_link"` (logit/probit/cloglog and anything
    else not confirmed collapsible — the conservative default). This is a
    **link-function lookup**, not a derivation: each class already knows
    its own link/estimating-equation from its model specification, so the
    audit is "which link does this class use," answered once per class,
    defaulting to `"nonlinear_link"` when unclear so an unaudited or
    ambiguous class fails safe (Tier 2) rather than fails dangerous.
    Reuses/extends the `estimand` metadata axis `marginal_estimand_
    report.md` already established package-wide rather than inventing a
    parallel concept.
  - `accounts_for_design_dependence` — character vector of dependence
    capabilities the class's *Wald/asymptotic* computation actually models
    (e.g. `InferenceIncidCMH` and the KK pass-through family declare
    `"blocking"`/`"matching"`) — already knowable from whether the class
    consumes the design's block/pair/cluster ids at all, not a new
    computation.

  Both fields are single per-class facts, recorded alongside the existing
  `infer_inference_*` inferred-metadata family in
  `inference_class_registry.R` — **not a per-`(class, design)`-pair
  derivation.** Tier assignment (below) is a static lookup combining one
  design-class fact (`splits_arms`/`shares_arm`) with one inference-class
  fact (`estimand_linearity`), so the audit is `O(design classes) +
  O(inference classes)` work, not `O(design classes × inference
  classes)`. See "This doesn't need re-deriving per class" in Why above
  for the general theory (sandwich-variance sign argument;
  noncollapsibility) that makes both facts lookups rather than fresh
  statistics.
- **Tier assignment** is a static lookup on two already-known facts — the
  design class's `splits_arms`/`shares_arm` shape for the capability the
  inference class doesn't declare in `accounts_for_design_dependence`, and
  that inference class's `estimand_linearity` — never a fresh derivation
  per `(class, design)` pair:
  - No undeclared capability, or the design supports `rand` inference
    (`supports_design_randomization_draw`, already tracked per-instance —
    `inference_all_abstract.R`) → **Tier 0**, fully applicable, no
    advisory, no gate. (`rand` results are exact regardless of the class's
    declared awareness, per point 1 above.)
  - Undeclared `splits_arms` capability (blocking/matching) +
    `estimand_linearity == "linear_contrast"`, evaluated on the **Wald
    path specifically** → **Tier 1**: stays `applicable`, not excluded —
    see "Levels of warning, not just tiers of gating" below for how it's
    surfaced instead.
  - Undeclared `splits_arms` capability + `estimand_linearity ==
    "nonlinear_link"`, or an undeclared `shares_arm` capability
    (clustering) for **any** `estimand_linearity`, on the Wald path →
    **Tier 2**: new discovery bucket `dependence_naive_on_design`,
    excluded from `run_all_inference()`'s default run, gated behind
    acknowledgment (below).
- **The gate lives on the Wald-path compute methods, not on
  `$new()`.** Because `rand`-path methods on the very same object are
  already exact (Tier 0 always applies to them), blocking construction
  itself would needlessly deny a perfectly good `compute_rand_confidence_
  interval()` call. Instead, the asymptotic/default `compute_confidence_
  interval()`/`compute_two_sided_pval()` methods on a Tier-2 `(class,
  design)` pair require a companion `acknowledge_design_dependence_naive =
  FALSE` argument (default) to proceed; otherwise they stop, naming the
  ignored capability and the recommended alternative(s) when any exist.
  Object construction (`InferenceXyz$new(des_obj)`) itself is never
  blocked by this plan — only the specific Wald-path call is.
- **Levels of warning, not just tiers of gating.** "Legal" (size-
  preserving) was being read as "therefore silent" — it shouldn't be.
  Each tier maps onto R's own condition severity levels, and Tier 1 gets a
  real signal it didn't have in the first two drafts:
  - **Tier 0:** no condition, no flag — genuinely nothing to say.
  - **Tier 1:** the Wald-path `compute_confidence_interval()`/
    `compute_two_sided_pval()` call raises an actual `warning()` (not just
    a discovery-metadata string), naming the ignored capability and
    pointing at `ci_method = "rand"` on the same object as the exact,
    already-available fix. **Throttled, not per-call** — a naive per-call
    warning would flood any simulation study or `comprehensive_tests.R`
    sweep calling the same class thousands of times (this package's
    `should_run_asserts()` gate exists for exactly this class of
    hot-loop-cost problem); fire once per R session per `(class, design
    class)` pair, the same "warn once" shape `.Deprecated()`-style
    warnings already use elsewhere in R. Independently of the runtime
    warning, `run_all_inference()`'s results table carries a
    `dependence_note` column (`NA` / `"conservative"` / `"gated"`) so the
    signal survives in the artifact users actually read (the pretty-print
    table, the forest plot, the JSON export) even when warnings were
    suppressed or the call happened deep inside a simulation loop.
  - **Tier 2:** unchanged from above — the required
    `acknowledge_design_dependence_naive` argument *is* the warning
    (an unmissable, non-default argument the caller must type), so no
    separate runtime `warning()` is layered on top of an already-explicit
    opt-in; the `dependence_note` column still records `"gated"` so a
    batch run that used the acknowledgment is auditable after the fact.
  This directly targets the "same estimand, dominated computation" case
  from the "Why Tier 1 classes stay in the sweep" note above — the row
  stays in the table, but it now carries a label instead of looking
  exactly as authoritative as the exact number next to it. Explicitly not
  in scope: changing `run_all_inference()`'s *default* `ci_method`
  selection to prefer `rand` over Wald for Tier 1/2 designs. That would
  itself be a default-result change (`rand` costs real compute — batches
  of resampling replicates versus a closed form) and would violate this
  release's own "must reproduce 1.0.0 results" standing constraint; the
  fix here is entirely additive (a new warning, a new column), not a
  change to what any existing call already returns.
- **`applicable_inference_class_names()`/discovery invariant is
  unaffected by the gate move.** `test-design-inference-introspection-
  audit.R` already encodes `nm %in% des$applicable_inference_class_names()
  <=> ClassName$new(des) does not throw` (default arguments) — since
  construction is never gated by this plan, that invariant needs no
  change. `dependence_naive_on_design` is a *reporting* bucket
  (`discover_applicable_inference_classes()`'s partition, alongside
  `unavailable_due_to_missing_packages`), not a constructibility one; a
  Tier-2 class stays constructible and its `rand` methods stay callable,
  it's specifically excluded from `run_all_inference()`'s default sweep
  and its Wald-path calls require acknowledgment.
- **No *numeric* result changes for the documented-correct or Tier-0/
  Tier-1 path — a returned estimate/SE/CI/p-value is bit-for-bit identical
  before and after this plan for any class that already declares the
  capability it's run against, and for every Tier 1 call.** Tier 1's
  `warning()` is a genuinely new side channel, not a numeric change — it
  changes what a caller *sees on stderr*, not what a caller *gets back*,
  which is what this release's "must reproduce 1.0.0 results" standing
  constraint is actually about. Still worth auditing deliberately (TODO-6)
  rather than assumed harmless: a script running with `options(warn = 2)`
  turns any new warning into an error, and any existing test asserting
  `expect_silent()`/no-warning on a Tier-1 `(class, design)` combination
  needs updating to expect the new (once-per-session-throttled) warning
  rather than being newly, surprisingly broken by it. The only *numeric*
  behavior change anywhere in this plan is Tier-2 Wald-path calls on a
  dependence-inducing design that today run silently — exactly the case
  this plan exists to surface.

## Scope decisions (Phase 0, decision-gated TODO-1)

- **Gate placement.** Confirm gating the specific Wald-path compute
  methods (not `$new()`) is the right mechanism shape — it's a departure
  from the existing `stop_if_design_incompatible()` pattern, which always
  gates at construction, so it needs its own small helper, not a reuse of
  that one.
- **Linearity classification.** Confirm `estimand_linearity` reuses/extends
  `marginal_estimand_report.md`'s `estimand` axis rather than being a new,
  parallel registry field — and confirm the rubric: "linear_contrast" =
  point estimate is provably invariant to whether the pairing/blocking is
  used in its computation (mean/risk difference, OLS); everything else
  (any GLM link, likelihood-based fit) defaults to "nonlinear_link" absent
  a specific proof otherwise.
- **Two-speed rollout for clustering.** Matched pairs
  (`DesignFixedBinaryMatch`, KK on-the-fly) have a real drop-in
  alternative today — the KK pair family — so Tier-2 matched-pair cases
  both gate *and* recommend it. General clustering (`ClusterStructure`)
  has no general-purpose corrected alternative outside the KK-pair
  machinery until `cluster_robust_inference_glmm_gee.md` (5Y) ships in
  v2.0.0; the message there says no corrected alternative exists yet
  instead of pointing at a nonexistent class. Confirm this shape rather
  than waiting on 5Y to land the whole guard.
- **Blocking-alone sensitivity.** Whether Tier assignment for
  `nonlinear_link` classes should differ between coarse blocking (many
  units per block) and fine matching (pairs) — the noncollapsibility/
  attenuation effect plausibly shrinks as block size grows and the random
  effect's per-block leverage on any one contrast shrinks — needs TODO-2b's
  per-class link-function audit to answer empirically/theoretically rather
  than guessed up front; default to treating both as Tier 2 until shown
  otherwise.
- **Naming.** Confirm `dependence_naive_on_design`,
  `acknowledge_design_dependence_naive`, and `dependence_note` before
  wiring — all three touch the public `InferenceSuite`/class surface this
  release promises to keep additive.
- **Warning throttle key and mechanism.** Confirm "once per R session per
  `(class, design class)` pair" as the throttle granularity for Tier 1's
  `warning()` (coarser — e.g. once per session, full stop — risks a user
  never seeing it for the second design they actually care about; finer —
  e.g. once per object — risks flooding a simulation loop that constructs
  a fresh object per replicate) and confirm the implementation (a small
  package-environment flag set, mirroring how base R throttles repeated
  `.Deprecated()` warnings, vs. `rlang::warn(.frequency = "once", 
  .frequency_id = ...)` if `rlang` is already a dependency here).

## Tests

- Widen `test-design-inference-introspection-audit.R`
  (`R/package_tests/testthat_bulk/`) — it already audits discovery-vs-
  constructibility for response types; add discovery-vs-tier parity the
  same way (every concrete class's `accounts_for_design_dependence`/
  `estimand_linearity` must agree with what its Wald-path methods actually
  gate).
- **Simulation goldens confirming the direction of the effect, not just
  that a gate fires** (this is the part that would have caught the
  original draft's over-broad scope):
  - `DesignFixedBinaryMatch` + a linear-contrast mean-difference class:
    simulate under a real pair effect, confirm the naive pooled Wald SE
    *overstates* the empirical sampling SE (Tier 1, conservative, no
    gate) while `ci_method = "rand"` already matches the empirical
    truth.
  - `DesignFixedBinaryMatch` + incidence logistic regression: simulate
    under a real pair effect, confirm both attenuation of the point
    estimate and understatement of the naive Wald SE relative to
    simulation truth (Tier 2, justifying the gate); confirm the KK pair
    family does not show either effect.
  - `DesignFixedCluster` + continuous, any estimand: confirm the naive
    Wald SE understates the empirical sampling SE (Tier 2; no corrected
    alternative to recommend yet, message says so).
- Extend `test-design-compatibility-reason.R` and
  `test-inference-suite-discovery.R` (both already exercise the
  blocking-axis regression designs) with Tier 1 and Tier 2 cases.
- Tier-1 warning behavior specifically: confirm the `warning()` fires on
  the first Wald-path call for a given `(class, design class)` pair and is
  suppressed on the second within the same session (throttle test); a full
  suite run under `options(warn = 2)` doesn't newly error out anywhere it
  didn't before **except** where a Tier-1 or Tier-2 path is genuinely
  exercised for the first time — audit existing `expect_silent()`/no-
  warning assertions across the test suite for Tier-1 `(class, design)`
  combinations that would now (correctly) emit one, and update them to
  expect it rather than treating the new warning as a regression.
- Comprehensive-suite regen: `comprehensive_tests.R`'s coverage CSVs
  (`comprehensive_suite_coverage.csv` etc.) will shift only for Tier-2
  Wald-path class × design pairs newly requiring acknowledgment — confirm
  the pre-push auto-regen hook (`d7c19ba8`, "pre-push: auto-regenerate
  drifted package_tests CSVs") picks this up rather than needing a manual
  run.

## TODOs

- [ ] TODO-1: Decision batch above (gate placement, linearity
  classification/rubric, two-speed clustering rollout, blocking-alone
  default, naming) — joins the Phase 0 sitting.
- [ ] TODO-2a: Classify each *design class* as `splits_arms` or
  `shares_arm` per dependence capability it composes — mechanical, one
  fact per design class (`BlockingStructure`/`MatchingStructure` ⇒
  `splits_arms`, `ClusterStructure` ⇒ `shares_arm`; see "This doesn't need
  re-deriving per class" in Why), not a per-response-type audit.
- [ ] TODO-2b: Classify each *inference class* not already declaring a
  capability in `accounts_for_design_dependence` as `estimand_linearity =
  "linear_contrast"` (confirmed identity-link/additive-contrast) or
  `"nonlinear_link"` (default) — a link-function lookup per class, land as
  registry metadata alongside the existing `infer_inference_*` family.
  Bulk of this plan's *engineering* effort is running this lookup across
  every concrete class once, not deriving new statistics per class — see
  Why's general-theory note for why TODO-2a/2b together are `O(design
  classes) + O(inference classes)`, not a combinatorial per-`(class,
  design)` derivation.
- [ ] TODO-3: `Design$dependence_structure()` accessor exposing TODO-2a's
  classification; extend
  `is_inference_class_compatible_with_design_metadata()` and
  `discover_applicable_inference_classes()` with Tier-1 advisory
  annotations and the Tier-2 `dependence_naive_on_design` bucket.
- [ ] TODO-4a: Tier-1 `warning()` on the Wald-path compute methods (new
  shared helper, once-per-session-per-`(class, design class)` throttle per
  TODO-1's decision) naming the ignored capability and the `rand`
  alternative; `run_all_inference()`/`discover_applicable_inference_
  classes()` gain the `dependence_note` column/field
  (`NA`/`"conservative"`/`"gated"`) so the signal survives outside a live
  R session (pretty-print table, forest plot, JSON export).
- [ ] TODO-4b: Tier-2 default exclusion from `run_all_inference()` +
  alternative-recommendation reporting (`dependence_note = "gated"` for
  any row that used the acknowledgment).
- [ ] TODO-5: Wald-path `acknowledge_design_dependence_naive` gate (new
  shared helper, gating the specific asymptotic compute methods, not
  `$new()`) wired into every Tier-2-audited class.
- [ ] TODO-6: Tests — introspection-audit widening, the simulation
  goldens above (direction of effect, not just gate presence), the
  Tier-1 warning-throttle and `options(warn = 2)`/`expect_silent()` audit,
  comprehensive-suite CSV regen.
- [ ] TODO-7: Docs — vignette callout (`extending-edi.Rmd`)
  cross-referencing the lock-and-key metaphor (TODO-19) for this new
  axis; `?run_all_inference` note on Tier 1 vs. Tier 2.
