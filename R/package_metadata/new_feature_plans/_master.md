# Master TODO Ordering

Generated 2026-08-14. This document orders **every open TODO across every plan
in `new_feature_plans/` and `bug_fix_plans/`** into one dependency-respecting execution sequence.
Each plan carries a `> **Depends on:**` header stating its upstream plans; this
file is the transitive ordering of those edges. TODO references are written
`<plan file> → <TODO id or section>`. Where work from different plans belongs
together (same machinery, same bug family, same decision), the TODOs are
spliced into one step and marked **[spliced]**.

> **Release line (2026-08-15).** `release_v1_0_0.md` batches Phase 1 (both
> hierarchy migrations, interval-censored survival, the SEXP spec), Phase 3
> (documentation, roxygenize R CMD check), `extending-edi-r6.md` (since
> 2026-08-23: `vignettes/extending-edi.Rmd`),
> `save_load_api.md`, `multi_arm_designs.md → TODO-6`, and a CRAN-mechanics
> checklist into the v1.0.0 CRAN scope — "every public contract frozen."
> Everything in Phases 0/2/4/5/6 not named there is deferred to 1.x as
> additive (amended 2026-08-16: `design_fixed_optimal.md` — the new
> deterministic single-allocation `DesignFixedOptimal` class — is also
> release-scoped; its decision gates TODO-1..4 join the Phase 0 batch, and
> its implementation follows `fix_design_hierarchy.md`'s
> `DesignFixedGreedyDOptimal`/shared-engine work in Phase 1E. Amended again
> 2026-08-16: `design_fixed_greedy_pair_switch_merge.md` — merging
> `DesignFixedGreedy`/`DesignFixedGreedyDOptimal` into
> `DesignFixedGreedyPairSwitch` by releasing `DesignFixedGreedy`'s
> `prob_T = 0.5` constraint — is explicitly **deferred to 1.x**, sequenced
> after both `fix_design_hierarchy.md`'s Stage-2 shared-engine extraction and
> `design_fixed_optimal.md`'s own implementation, in Phase 6 below).
> That file draws the release line; this file remains the
> execution order.
>
> **v1.1.0 line (2026-08-17, user decision).**
> `../future_release_plans/release_v1_1_0.md` batches **everything open in
> this directory that is not inside the v1.0.0 line** into the v1.1.0 scope
> — the full Phase 0 decision batch, Phases 2 and 4 remainders, all of
> Phase 5, and Phase 6 (including `design_fixed_greedy_pair_switch_merge.md`;
> `local_machine_optimization.md` was pulled out into the v1.0.0 line — see
> the amendment below). This supersedes
> `release_v1_0_0.md → TODO-5`'s earlier "small first wave" guess. As with
> the 1.0.0 file, it only draws the release line; this file remains the
> execution order, and its TODOs are ticked in their owning plans.
> Amended 2026-08-17: `design_seq_many_by_many.md` (the new sequential
> many-by-many design family — Phase 5F below) is written directly into the
> v1.1.0 scope (user decision; `release_v1_1_0.md → TODO-15`).
> Amended 2026-08-18: `kk_beta_regression_one_lik_derivation.md` (a genuine
> Beta-family one-stage `OneLik` joint likelihood for proportion responses
> under KK designs — Phase 5G below) is promoted from
> `../new_research_ideas/` and written directly into the v1.1.0 scope
> (`release_v1_1_0.md → TODO-15b`; **moved 2026-09-06 to
> `release_v1_4_0.md → TODO-15`, lighten-1.1.0 pass, user decision** — a
> new estimator family is off-theme for that release).
> Amended 2026-08-18 (user decision): `marginal_estimand_report.md` — the
> `set_estimand()` estimand axis — is pulled **out of** the v1.1.0
> "everything else" bucket and **into** the v1.0.0 line instead (see
> `release_v1_0_0.md`'s item 14). Its TODO-1 "whether to pursue this at
> all" decision moves from the Phase 0 batch below into the v1.0.0-gated
> portion of that same batch. Motivation:
> `inference_suite_inspect.md`'s Combined Evidence Metric feature
> (TODO-14..21 there) defaults its per-class weighting to grouping by
> `estimand`, so shipping that default at 1.0.0 needs the real,
> package-wide `estimand` concept behind it, not just the handful of
> gcomp classes that currently implement `get_estimand_type()`.
> `expanded_estimate_report.md` (the orthogonal `estimate_type` axis) was
> initially pulled in alongside it for a joint decision, then **moved back
> to v1.1.0 the same day (user decision)**: nothing in v1.0.0 scope needs
> `estimate_type` — the Combined Evidence Metric only reads `estimand` —
> and `estimate_type`'s own stated urgency (the Cox-Snell/
> Cordeiro-McCullagh/median-bias correction plans' API shape) is itself
> v1.1.0-scoped. The two plans' TODO-1s no longer have to be decided in
> the same sitting; whichever comes second just needs to check the
> first's chosen values so the two enums don't collide.
> **`marginal_estimand_report.md → TODO-1` decided (2026-08-18, user
> decision): yes, pursue `set_estimand()`.** TODO-3/6/8 (the ungated
> architecture/plumbing work) are **done** (2026-08-18); TODO-4/5/7/9
> (concrete ZOIB/ZIP/hurdle/logit/Poisson/beta-regression wiring — TODO-7
> turned out to have no independent architecture, it rides along with
> these as their consequence, not a separate gate) remain gated on
> `fix_inference_hierarchy.md`'s Full-Likelihood Estimators remainder per
> that plan's own "Recommended execution order" note.
>
> **Amended 2026-08-20 (user decision):** `local_machine_optimization.md` —
> the `tune_EDI_for_this_machine()` benchmark tuner — moves from the v1.1.0 line
> into the v1.0.0 line (`release_v1_0_0.md`'s item 15). It was previously
> Phase 6 item 5 below and `release_v1_1_0.md → TODO-10`/part of `TODO-1`
> step 11; those references are struck accordingly. Phase 6 in this file no
> longer lists it as a phase-ordered item since it now ships with the
> release-scoped batch, not the exploratory tail.
> **Closed (2026-08-23):** all twelve of that plan's TODOs done; moved to
> `../finished_features/local_machine_optimization.md`. See
> `release_v1_0_0.md`'s item 15 for the full closure writeup.
>
> **Amended 2026-08-23 (user decision):** `performance_profiling_and_upgrades.md`
> — the native-kernel performance record, moved here from
> `../audits/perf_experiments.md` on 2026-08-22 and extended with a
> forward-looking audit plan (§8, TODO-132..179) — is written into the v1.1.0
> scope as a second kernel/perf lane: `release_v1_1_0.md → TODO-4b`, Phase 4
> below. Measurement-first, no Phase 0 dependency; its result-changing items
> (libmvec exp/log, adaptive quadrature, Monte-Carlo early stopping, non-R RNG
> streams) are gated by the release's additive/bit-for-bit rule (opt-in or a
> documented default change). **Narrowed 2026-09-06 (lighten-1.1.0 pass,
> user decision): only the measurement-infrastructure sub-batch
> (TODO-132..135, 175) stays in v1.1.0, needed to benchmark that
> release's own speedup claims; everything past it, and the three
> build-tuning lanes below that consume it, moved to
> `release_v1_2_0.md → TODO-11..15`.**
>
> **Update (2026-08-16):** two of the release-scoped plans have since
> closed and moved to `../finished_features/`: the interval-censored
> survival (y/y_L/y_R) rework, and the SEXP/RcppEigen conversion spec
> (including its memory-safety TODO-16/17). See Phase 1C and 1F below.
> The `bootstrap_calibrated_lr_report.md → TODO-1` negbin heap-corruption
> item (Phase 1B step 2) is also done (2026-08-16) — root cause was the
> unvalidated `get_hurdle_negbin_count_score_cpp`/`_hessian_cpp` getters, not
> `fast_truncated_negbin_count_cpp` itself; fixed with the same dimension
> guards as TODO-16, so Phase 1B is now fully closed. Also done
> 2026-08-16: `multi_arm_designs.md → TODO-6` (Phase 4 step 1, the
> `InferenceIncidCMH` non-blocking balance-guard gap) — `multi_arm_designs.md`
> itself stays open (only TODO-6 was release-scoped) and does not move to
> `../finished_features/`. Also done 2026-08-17: `design_fixed_optimal.md` —
> every TODO closed (the new `DesignFixedOptimal` class, its registry/roxygen
> wiring, and the follow-on `DesignFixedOptimalBlocks` commercial-solver
> threading); moved to `../finished_features/design_fixed_optimal.md`
> (2026-08-17). The two remaining mentions of it in this file (the
> release-line note above and Phase 6's
> `design_fixed_greedy_pair_switch_merge.md` dependency) are unaffected —
> both refer to it by name only, not by path.

> **Thematic release split (2026-08-27, user decision; supersedes the
> same-day three-way split).** Rule: **1.x = improvements on the current
> codebase plus simple additions on the existing architecture and the six
> scalar response types; 2.0.0 = genuinely new functionality requiring
> large refactorings or new architecture.** The 1.x work is grouped by
> theme into four releases. Placement, by this file's phases and by the
> 2026-08-27 owning plans (Phase 5M–5Z below):
> - **v1.1.0 — Inference quality** (`../future_release_plans/release_v1_1_0.md`):
>   Phase 0 decision batch (records every gated track's yes/no, including
>   1.3.0/1.4.0/2.0.0 tracks), Phase 2 diagnostics, Phase 5A corrections
>   **core** (5N HC-robust SEs and 5M count exposure offset stay; 5A's
>   L1/L2-and-beyond tail, 5G KK beta OneLik, 5J count QR, 5O small
>   estimand additions, and the ordinal Bayesian-bootstrap plans **moved
>   to v1.2.0/v1.4.0 in the 2026-09-06 lighten-1.1.0 pass** — see each
>   phase's own entry below for its new home), `randomization_ci_search_precision.md`,
>   and **the nominal one-vs-rest vignette if its TODO-1 is "no"**.
>   **This last item is the single authoritative statement of that
>   vignette's release placement (resolved 2026-09-06, user decision,
>   after `release_v1_1_0.md`, `release_v1_4_0.md`, and
>   `release_v2_0_0.md` had each drifted into claiming a different home
>   for it): it ships in v1.1.0, immediately alongside the Phase 0
>   decision that gates it — the decision and its one-paragraph
>   documentation closeout are the same unit of work, not two.
>   `release_v1_1_0.md`'s `TODO-17d` and `release_v1_4_0.md`'s
>   corresponding mention must read as pointers to *this* line, not as
>   independent claims.**
> - **v1.2.0 — Performance & engines** (`release_v1_2_0.md`): Phase 4
>   kernel/perf lanes, `cold_starts.md`, Phase 6 item 5's *merge +
>   soft-deprecation* half; closes `parallel_fork_cluster_test_safety.md`.
>   (`performance_profiling_and_upgrades.md` and `more_simd_optimization.md`
>   stay in v1.1.0 — see the Phase 4 "Second lane" / "Third lane" notes
>   below.)
> - **v1.3.0 — Design extensions from practice** (`release_v1_3_0.md`):
>   5T (cluster-level balancing designs + saturation), 5U (unequal
>   allocation + Neyman helper), 5F (many-by-many designs). *(Amended
>   same day, user decision: the theoretical-design backlog — 5P, 5Q, 5R,
>   5S — moved to 2.0.0.)*
> - **v1.4.0 — Response & data extensions** (`release_v1_4_0.md`): 5H
>   (`dead → uncensored` rename) **in one sweep with** 5K (competing risks),
>   5L (cure fraction), Phase 6 item 3 (interval-censored second wave), 5I
>   (survival QR), Phase 5C censored-response track, the semi-continuous
>   member of 5B, `full_glmm_for_weibull_frailty.md`, 5V (encouragement /
>   CACE), 5W (moderation), 5X (missing outcomes), and the sequential-
>   inference *scoping* (Phase 6 item 1).
> - **v2.0.0 — Architecture** (`release_v2_0_0.md`): 5B's remaining
>   response-type reports (nominal — recorded "no" —, rank/choice,
>   multivariate [now one `Design` with named responses, plus
>   `multivariate_response_modeling.md` Levels 1-2: joint sandwich covariance
>   and randomization-based joint inference], compositional, longitudinal), 5D multi-arm, 5E GPU, Phase
>   6 item 6 quantum backend, sequential-inference *implementation*, 5Y
>   (cluster-robust GLMM/GEE), 5Z (mediation), 5AA (response-adaptive
>   randomization), **the theoretical-design backlog 5P (classical
>   sequential completions), 5Q (rerandomization criteria / samplers /
>   Grundy-Healy), 5R (optimal-objective extensions), 5S (Gram-Schmidt
>   Walk / balancing walk / ARM-PSR)**, Phase 6 item 4 landscape refresh,
>   and the greedy-class *deletion*. **Amended 2026-09-10 (user decision):**
>   two more theoretical-audit items, genuinely missed by the 2026-08-27
>   sweep, folded into 5R/5S respectively rather than getting new files —
>   Tabord-Meehan (2023) stratification trees (item #5, into
>   `optimal_design_objective_extensions.md` §H) and
>   Bertsimas-Korolko-Weinstein (2019) online MIO covariate-adaptive
>   optimization (item #30, into
>   `modern_covariate_balancing_designs.md` as
>   `DesignSeqOneByOneOnlineMIO`).
> The phase text below is unchanged; each release file lists its own TODO
> order.
>
> **Tentative v3.0.0 opened (2026-09-10, user decision; merged same day
> after two independent scoping efforts both proposed it).**
> `../future_release_plans/release_v3_0_0.md` — not yet a real scope, no
> Phase-0-style decision batch of its own, and possibly not even a
> permanent release boundary; a shared, tentative home for unrelated,
> independently-gated items, each scoped as landing after v2.0.0:
> `finite_mixture_regression.md` (finite/latent-class mixture regression
> for existing response families — genuinely new architecture even by
> v2.0.0's own bar) and `bayesian_stan_primary_analysis_report.md` (a
> `cmdstanr`-backed optional Bayesian primary-analysis family — posterior
> estimate/CI, decision outputs, hierarchical models, a
> `sequential_inference.md` tie-in — commissioned by
> `missing_inference_classes_literature_audit.md` item 21). Neither has a
> Phase-lettered item the way 5A–5AJ do (both are new reports, not
> promoted existing plans); their TODO order lives entirely in
> `release_v3_0_0.md`. **Added 2026-09-11 (this session):
> `continuous_treatments.md`** — makes `w` a genuinely continuous dose
> rather than today's hard-coded `{0,1}`, on both the design (randomized
> continuous-dose assignment) and inference (dose-response estimand)
> sides; independently gated (its own TODO-1), no dependency on the other
> two items here. See Phase 7 below.

Rules of use:

1. Work top to bottom within a phase; phases 2–4 may run in parallel with the
   tail of phase 1 where their stated dependencies are already met.
2. Nothing in Phase 5 starts before its Phase 0 decision is recorded in the
   owning plan.
3. When a TODO here is finished, tick it in its **owning plan** (the source of
   truth), not here — this file is an index, not a second checklist.

---

## Phase 0 — Decision batch (ask the user; no code)

One sitting; every gated plan's TODO-1, decisions taken in cascade order.
**Full item list: `release_v1_1_0.md → TODO-1`** (that file is now the
source of truth for this batch's order and per-item status — do not
maintain a second copy here).

Status not repeated in the release file: `marginal_estimand_report.md →
TODO-1` is **[x] DONE (2026-08-18, user decision: yes, pursue
`set_estimand()`)** and was pulled out of this batch entirely into the
v1.0.0 line (see the release-line note above and `release_v1_0_0.md`'s item
14) — it is not one of `release_v1_1_0.md → TODO-1`'s items.

---

## Phase 1 — Foundations (in flight; everything later rebases on these)

### 1A. Inference-hierarchy bug batch (blocks verification everywhere) — **DONE (2026-08-17)**

All seven items below are `[x]` in `fix_inference_hierarchy.md`'s
Follow-Ups section, including item 3's locked-binding sweep, closed
2026-08-17 once the `CoxData` compile blocker cleared and every named
runtime test file (`test-design-inference.R`,
`test-asymp-inference-paths.R`, `test-ci-rand.R`,
`test-brt-smoothed-wilcox-ci-perf.R`, `test-bayesian-bootstrap.R`,
`test-mixin-contracts.R`, `test-inference-class-registry.R`) confirmed zero
locked-binding failures remain. Item 4's `dead`-propagation fix landed as
part of the now-closed `interval_censored_survival_response.md` rework.
Each file's remaining failures (documented per-file in
`fix_inference_hierarchy.md`) are distinct, unrelated issues — not
locked-binding, not blocking this batch.

1. `fix_inference_hierarchy.md → Follow-Ups: lazy-component/clone() staleness
   bug` — the silent-wrong-numbers framework bug; nothing with a lazily loaded
   `initialize`/`compute_estimate` can migrate before this.
2. `fix_inference_hierarchy.md → Follow-Ups: redo the reverted
   InferenceIncidGCompRiskDiff/RiskRatio migration` (immediately after 1).
3. `fix_inference_hierarchy.md → Follow-Ups: locked-binding sweep` (includes
   the `InferenceAllSimpleWilcox` missing
   `compute_rand_bootstrap_confidence_interval` sighting) **[spliced with]**
   `interval_censored_survival_response.md → TODO-13` (Cox's missing
   randomization/bootstrap component methods) — one "missing/locked
   component-method audit" over every migrated class, with TODO-13's
   golden-test rigor as the template.
4. `fix_inference_hierarchy.md → Follow-Ups: dead-propagation bootstrap bug`
   — coordinate with the in-flight y/y_L/y_R work that owns the plumbing.
5. `fix_inference_hierarchy.md → Follow-Ups: silent-state-wipe
   invariant/regression test` **[spliced with]**
   `fix_design_hierarchy.md → Follow-Ups: component-slot-state-survival test`
   — same test pattern, write both sides together.
6. `fix_inference_hierarchy.md → Follow-Ups: unregistered-subclass capability
   detection` **[spliced with]** the resulting doc update in
   `extending-edi-r6.md` (its Subclassing Rules section documents the gap).
7. `fix_inference_hierarchy.md → Follow-Ups: globals.R name-keyed dispatch
   table validation`.

### 1B. C++ memory-safety batch **[spliced]**

One pass, same bug family (exported kernels corrupting memory on malformed
input instead of erroring):

1. **[x] DONE (2026-08-16)** `sexp_removal_rcppeigen_conversion_spec.md →
   TODO-16` — `fast_poisson_glmm_cpp` group-size validation. (Plan closed,
   moved to `../finished_features/`.)
2. **[x] DONE (2026-08-16)** `bootstrap_calibrated_lr_report.md → TODO-1` —
   root cause was the unvalidated `get_hurdle_negbin_count_score_cpp`/
   `_hessian_cpp` getters (not `fast_truncated_negbin_count_cpp` itself),
   fixed with the same dimension guards as TODO-16.
3. **[x] DONE (2026-08-16)** `sexp_removal_rcppeigen_conversion_spec.md →
   TODO-17` — the
   comprehensive-suite harness `status="ok"` false positive. Do this early:
   every later verification pass relies on the harness telling the truth.

### 1C. Interval-censored survival completion — **DONE (2026-08-16)**

Plan closed, all TODOs (including TODO-14's exhaustive bit-identical
regression sweep and TODO-15's stale `dead =` cleanup) checked off; moved
to `../finished_features/interval_censored_survival_response.md`.

### 1D. Inference-hierarchy migration completion (after 1A) — **DONE (2026-08-23)**

Plan closed (0 open items); moved to
`../finished_features/fix_inference_hierarchy.md`. The 2026-08-23 closure
verified the migration complete (zero concrete classes with algorithmic-
compatibility ancestors; the retained legacy ladder enumerated as internal
component sources) and turned the last two Static Cleanup ratchets into real
bans (raw component splicing; component redeclaration of root-owned state —
Source Invariant 15), reworded/closed the KK IVWC parent item for the
accepted thin-leaf terminal state, and added the focused non-KK count
likelihood family tests. This unblocks item 6 (`extending-edi-r6.md`) on
the inference side, Phase 1G's fixture lock, and the Phase 5A items gated
on the Full-Likelihood Estimators remainder (`marginal_estimand_report.md
→ TODO-4/5/7/9`). The historical snapshot below (as of 2026-08-17) is kept
for the narrative:

Real progress since the last pass: Wald No-Likelihood Migration is down to 1
cleanup item, Quasi/Robust Estimators and Discovery are both fully `[x]`.
Remaining, by section (open-item counts, 2026-08-17 snapshot):

1. `fix_inference_hierarchy.md → Asymptotic (Wald) No-Likelihood Migration`
   — **1 open**: delete no-longer-used legacy scaffolding after all
   no-likelihood classes are migrated.
2. `fix_inference_hierarchy.md → KK And IVWC Estimators` — **7 open, the
   largest remaining block**: finish `KKPassThrough`/`KKCompound`/`KKGEE`
   declarations, remove direct `InferenceMixinKKPassThrough$public` access,
   replace `eval(body(...))` usage, migrate KK IVWC/one-likelihood/GEE/GLMM
   classes, add focused KK regression tests.
3. `fix_inference_hierarchy.md → Full-Likelihood Estimators` remainder — **2
   open** (migrate remaining classes, verify finite smoke tests);
   `→ Partial-Likelihood: KK classes` — **1 open** (blocked on step 2's
   `KKPassThrough` work).
4. `fix_inference_hierarchy.md → Base Deletion` — **5 open**: convert
   no-longer-subclassed algorithmic bases, delete
   `InferenceRand`/`InferenceRandCI`/`InferenceNonParamBootstrap` etc.,
   remove them from `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES`, enable
   `EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY`, add the final strict
   no-legacy-descendant test — then re-run
   `fix_roxygenize_lazy_component_srcrefs.md`'s spot-checks (component docs
   lose their Rd home here).
5. `fix_inference_hierarchy.md → Static Cleanup` — **4 open** (ban raw
   component splicing, ban `eval(body(...))` fully, ban semantic
   classification via method-name sniffing, ban component redeclaration of
   root-owned state); `→ Regression Gates` — **5 open** (golden tests before
   each family migrates, finite smoke tests, count-likelihood focused tests,
   roxygenize-after-migration discipline, keep-tests-green discipline);
   `→ Design-Side Discovery API` — **1 open** (a doc/export + roxygenize
   item). `→ Discovery` is done (0 open).

### 1E. Design-hierarchy completion — **DONE (2026-08-17)**

Plan closed (0 open TODOs); moved to
`../finished_features/fix_design_hierarchy.md`. This unblocks item 5
(`save_load_api.md`, gated on `owns_state`) and Phase 5D step 1
(`multi_arm_designs.md → TODO-1`, gated on this phase's capability
metadata) — neither has started yet, but both can now begin.

1. `fix_design_hierarchy.md → Follow-Ups` remainder: exported-metadata-under-
   `load_all()` fix, `get_or_compute_block_ids` decoupling, authoring the
   generalized stratified `draw_bootstrap_indices()`, `ClusterStructure`
   authoring, `AllocationMatrixValidation` reconciliation,
   `DesignFixedMatchingGreedyPairSwitching` `matching_capable` investigation;
   plus (added 2026-08-15) the unified optimal-design merge decision
   (`objective`/`interest`/`prior_precision` API — see the rewritten
   Follow-Ups bullet; supersedes the earlier `criterion = c("M", "A")`
   shape), the
   shared greedy-swap engine extraction, the stale A/D reproducibility-roxygen
   fix, and closing `DesignFixedGreedy`'s assert-gated `prob_T = 0.5` bypass.
2. `fix_design_hierarchy.md → Class Factory Implementation` remainder (first
   real rewiring proof: `DesignFixedBlocking`).
3. `fix_design_hierarchy.md → Timing-Family Split` (all items, then delete
   `DesignBlocking`/`DesignMatching`, add the
   `EDI_REQUIRE_SHALLOW_DESIGN_HIERARCHY` gate).
4. `fix_design_hierarchy.md → Class-Identity Dispatch Replacement` (all call
   sites), `→ Dead Flag Cleanup`, `→ Observational Design Migration`.
5. `fix_design_hierarchy.md → Seed-Reproducibility Metadata` — per its audit
   note, this is now verify-and-flip-metadata (the kernel fix landed via the
   SEXP spec's RNG migration) plus the OpenMP nondeterminism follow-up and
   the `Follow-Ups: capabilities()/supports() bridge deletion`.

### 1F. SEXP spec closeout — **DONE (2026-08-16)**

Plan closed (0 open TODOs, including TODO-5/8/10's survival-family
conversions, TODO-15's ownership decision, and TODO-14's final grep
sweep); moved to
`../finished_features/sexp_removal_rcppeigen_conversion_spec.md`.

### 1G. InferenceSuite run_all_inference() (implementation parallel with 1D; fixture-lock after 1D)

Added 2026-08-17 (user decision), release-scoped into v1.0.0 (it adds
public API surface — `InferenceSuite$run_all_inference()` — that must freeze at
1.0.0; see `release_v1_0_0.md` amendment 13). **Amended 2026-08-18 (user
decision):** not functionally gated on Phase 1D — discovery is already
metadata-driven and stable (Phase 1A), and `run_all_inference()` only
calls each class's existing, behavior-preserving fit methods. Only its
TODO-9 fixture *lock* waits for Phase 1D to close (Base Deletion there
can still shift a class's `likelihood_tier`/optional-method columns);
TODO-1..8 (the plumbing, output modes, visualizations, return object) can
proceed now, in parallel with the tail of Phase 1D.

1. `inference_suite_inspect.md → TODO-1..8` — fit-and-compare every
   applicable inference class with one uniform output schema (identical
   across response types and iid vs. KK designs), incremental screen
   output with a %-done/ETA progress bar (SimulationFramework pattern),
   timestamped auto-opened HTML report, two ggplot2 visualizations
   (estimate number line with angled class labels + boxplot of estimates
   underneath; annotated `(1-alpha)`-level CI forest with per-row
   p-values, CI widths, and class/method labels, significance-styled at
   the user's `alpha`) with optional timestamped PDF, and the
   `EDIInferenceSuiteResults` return object (including its per-class
   `diagnostics` element — free optimizer fields only in v1.0.0, expanded
   in v1.1.0 per `public_diagnostics_api_spec.md → TODO-19`) with the
   `save_results_as_JSON` flag. May start immediately, in parallel with
   the tail of Phase 1D.
2. `inference_suite_inspect.md → TODO-9` — the full test grid (every
   response type × {iid, KK} × {BCRD, blocking, KK, greedy, D-optimal}
   design classes), **locked only once Phase 1D closes**.
3. `inference_suite_inspect.md → TODO-10..13` — practitioner follow-ups
   (`print`/`summary` S3 methods, `classes`/`exclude_classes`
   allow/deny-list, `max_secs_per_class` timeout, `num_cores` fork-cluster
   parallelization). Independent of Phase 1D and of step 4 below.
4. `inference_suite_inspect.md → TODO-14..21` — the Combined Evidence
   Metric (Cauchy combination across every class's p-value).
   **Depends on the release-scoped estimand work** (Phase 0 step 1 /
   Phase 5A step 1 above, `expanded_estimate_report.md`/
   `marginal_estimand_report.md`): TODO-15a's `estimand`-tagging audit and
   the `"estimand_grouped"` default weighting policy need the real,
   package-wide `estimand` concept those plans define, not just the
   handful of gcomp classes that implement `get_estimand_type()` today.
   Sequence after that work lands (or after its Phase 0 decision at least
   settles what `estimand` values exist, if implementation is still in
   flight).

---

## Phase 2 — Diagnostics chain (strictly ordered)

**Full item list: `release_v1_1_0.md → TODO-3`.** Status not repeated
there: step 4 (`optimizer_diagnostics_report.md → TODO-4`) is **[x] DONE
(2026-08-17)** — `converged` redefined as gradient-norm-based with an
LBFGS-specific OR-fallback, `hit_iteration_cap` split out, every caller
audited, plus an unrelated `fast_gaussian_lmm_cpp` segfault found and fixed
along the way; this also closed release amendment 11's decision gate.

---

## Phase 3 — Documentation (parallel with Phase 2)

1. **[x]** `fix_documentation.md → remaining R-side TODOs` in batches (per
   the standing rule: parse checks only mid-batch, no interim roxygenize).
   **Done (2026-08-23): 0 open R-side TODOs, plan moved to
   `../finished_features/`.**
2. **[x]** `fix_documentation.md → TODO #758..#816` (Python docstrings) —
   each only after its R sibling's expanded documentation exists (they
   copy from it). **Done (2026-08-23):** all 59 items were already `[x]`
   in the (moved) plan; verified for real against the actual
   `python/cpp/bindings_*.cpp` pybind11 docstrings (not just the
   checkboxes) — every one is genuinely expanded. One labeling bug found
   and fixed along the way: TODO #803 named a nonexistent
   `fast_weibull_regression`; the real binding is
   `fast_weibull_regression_general`, whose docstring was already fully
   expanded — only the TODO's function name was stale.
3. `fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO` — after the
   first large doc batch, and again after Phase 1D.4 (Base Deletion).
4. `lock_key_metaphor.md` (renamed from `lego_metaphor.md`) → TODO-2..7
   (added 2026-09-08, user decision; scope widened same day to every doc
   surface incl. `DESCRIPTION`; went through nine rounds of narrowing same
   day, all user decisions, ending with "lego" dropped entirely) —
   **Design = lock/instrument base, Inference = key**, settled by the
   discovery-API asymmetry plus `InferenceSuite$run_all_inference()`'s
   one-instrument-many-keys pattern; two confirmed gates (warding = coarse
   metadata predicate, bitting = the fine capability check) and the shear
   line (all-or-nothing capability match); "bow"/"housing" name the
   internal parts (e.g. `likelihood_tier`) neither side inspects. **Final
   framing: a key-operated measuring instrument, not a door** —
   `Inference$new(design)` assembles a machine, and turning the key both
   gates and configures which computation it runs, which is why different
   valid keys legitimately report different numbers from the same design
   (different circuits, one instrument) — self-description across README/
   vignette/pkgdown/`?EDI`/`DESCRIPTION`/CITATION. Release index:
   `release_v1_1_0.md → TODO-19`. Independent of every other Phase 3 item.

---

## Phase 4 — Independent kernel/perf lane (parallel with Phases 2–3)

No dependency on the decision batch; only on already-available SEXP
conventions. **Full item list: `release_v1_1_0.md → TODO-4`.** Status not
repeated there: step 1 (`multi_arm_designs.md → TODO-6`, the
`InferenceIncidCMH` non-blocking balance-guard gap) is **[x] DONE
(2026-08-16)**.

**Second lane (added 2026-08-23, user decision):
`performance_profiling_and_upgrades.md` §8 → TODO-132..179 — full item list
and ordering in `release_v1_1_0.md → TODO-4b`.** Independent of TODO-4's
kernel specs (it profiles and tightens what already exists rather than adding
kernels); its parallelism sub-batch (TODO-147/148/174/176) should be
coordinated with the `tune_EDI_for_this_machine()` axes (v1.0.0 item 15),
and its bare-metal sub-batch (TODO-143/171/175 + published 135/147/148
numbers) is one rented `c7i.metal-48xl` session. TODOs are ticked in the
owning plan. **Narrowed 2026-09-06 (lighten-1.1.0 pass, user decision):**
only TODO-132..135, 175 (measurement infrastructure — needed to benchmark
v1.1.0's own randomization-CI speedup claims) stay in `release_v1_1_0.md →
TODO-4b`; TODO-136..172, 174, 176..179 moved to `release_v1_2_0.md →
TODO-11`.

**Third, fourth, fifth, and sixth lanes (added 2026-08-27/30, user
decision; all moved 2026-09-06 to `release_v1_2_0.md → TODO-12..15`,
lighten-1.1.0 pass, user decision — each consumes the second lane's
measurements, which moved with it):** `more_simd_optimization.md` →
TODO-1..7 (index entry `release_v1_2_0.md → TODO-12`). Source-build
premise (`-march=native`, no runtime dispatch); implements what the
second lane's diagnostics find: `-fopenmp-simd` (the macOS gap),
`__restrict` sweep, wiring a confirmed fast-math subset into `configure`,
aligned `Map` copies, tree-code SoA, branch-free split-search
comparisons, float32 for split ranking. **No duplication:** every
measurement/diagnostic step (opt-report sweep, fast-math/libmvec test,
Eigen-vectorization audit, `.row(i)` classification, branch-free
GLM-objective layout) is owned solely by the second lane's
TODO-168/137/136/144/154; this lane consumes those results rather than
re-running them. Then `fixed_size_eigen_small_p.md` → TODO-1..5
(`release_v1_2_0.md → TODO-13`), `lto_reevaluation.md` → TODO-1..4
(`→ TODO-14`), and `memory_layout_row_major_irls.md` → TODO-1..4
(`→ TODO-15`). Each is measurement-first with its own TODO-1 gate and an
explicit "measured and dropped" exit; each names the second-lane TODO it
consumes rather than repeats (TODO-155 for fixed-size, TODO-135 for LTO,
TODO-144 for layout). Expected outcome at EDI's `n < 1,000`, `B < 2,000`
scale is small or nil for all four — the plans exist to replace
estimates with numbers and to record the thresholds where each *would*
matter.

**Algorithmic lane (added 2026-08-30, user decision; moved 2026-09-23 to
v1.0.5, bug-fix/feature split):**
`randomization_ci_affine_shift_reuse.md` → TODO-1..7, plus a decision-gated
TODO-8 (`release_v1_0_5.md → TODO-2`, was `release_v1_1_0.md → TODO-17o`).
Unlike the build-level lanes above,
this one is expected to be
large: it revives the dead `t0s_rand` fast path so a randomization CI for a
linear-in-`y` statistic reuses one null distribution across every bisection
step (~20–30×). R-level only, no kernel changes, independent of the other
lanes. Its 2026-09-04 interaction section records that, once it lands, a
tier-1 class's `p(δ)` is an exact step function — Brent (`→ TODO-17w`)
does not apply to it, Robbins–Monro (`→ TODO-17u`) is not offered on it,
and a direct order-statistic inversion with no search at all becomes
possible (TODO-8, gated: exactness, not speed).
Two siblings added the same day: `ols_randomization_distr_cpp_wiring.md`
→ TODO-1..6 (moved 2026-09-23 to `release_v1_0_5.md → TODO-3`, was
`release_v1_1_0.md → TODO-17p`; wire the never-called
`compute_ols_distr_parallel_cpp`, delete eight other dead exports; 20–50×
on the OLS null distribution, multiplicative with TODO-17o) and
`ols_distr_kernel_fwl.md` → TODO-1..5 (v1.2.0, `release_v1_2_0.md →
TODO-9`; FWL rewrite inside that kernel, 5–10×, depends on the wiring).
Hardening item from the same audit (moved 2026-09-23 to
`release_v1_0_5.md → TODO-4`, was `release_v1_1_0.md → TODO-17q`):
`../bug_fix_plans/guard_unguarded_information_inverse.md` → TODO-1..5 — five bare
`.inverse()` sites on the free information block get the `isInvertible()`
guard Cox/ordinal/ZOIB already use; bit-for-bit on invertible fits.
Second hardening item, 2026-09-03 (v1.1.0, `→ TODO-17s`, **narrowed
2026-09-06, lighten-1.1.0 pass, user decision**):
`multistart_nonconcave_likelihoods.md` → TODO-1..10 — every nonconcave
likelihood kernel (GLMM/LMM/frailty, ZINB/ZIP/ZOIB, negbin, beta,
stereotype, copula survival, cauchit, bisquare) gets a deterministic +
reproducible-random multistart through one new leaf header
`optimization_multistart.h`, generalizing the sweep `fast_ordinal_glmm.cpp`
already has; bit-for-bit whenever the primary start was already best, on
every replicate fit, and on every concave kernel. **v1.1.0 keeps only the
documented-failure tranche** (ZINB/ZIP/hurdle-NegBin, beta regression —
the boundary-runaway failure `../bug_fix_plans/negbin_dispersion_convergence.md` and
`em_algorithm_zero_inflated_mixtures.md` exist to patch); the remainder
(GLMM/LMM/frailty, ZOIB, stereotype, copula survival, cauchit, bisquare)
moved to `release_v1_2_0.md → TODO-20`.
Third item, 2026-09-03 (v1.1.0 survey / v1.2.0 harness — **split
2026-09-06, lighten-1.1.0 pass, user decision**): `algorithm_choice_audit.md`
(`→ TODO-17t`, stays v1.1.0 — a document, costs nothing, and one of its
Adopt verdicts, Brent, is already there) — a per-kernel/problem-class
survey asking "is this the best-known algorithm?" (as opposed to "is the
implementation fast?", this document's own question). Its harness and
both gated Prototype items **moved to `release_v1_2_0.md → TODO-21`**:
`algorithm_ab_testing_framework.md → TODO-1..4`, the maintainer-run
paired-benchmark harness every Prototype verdict must clear before a
default changes; `garthwaite_buckland_ci_search.md → TODO-1..4`
(Robbins–Monro search replacing bisection for randomization/bootstrap CI
bounds — opt-in, composes with `randomization_ci_search_precision.md`;
**not offered** for `randomization_ci_affine_shift_reuse.md`'s tier-1
classes, where each p-value is O(r) arithmetic and RM cannot win —
dispatches to bisection there, A/B corpus stratified on
`supports_additive_delta_shift()`; plan corrected 2026-09-04 to target
the live R-level search driver, not the caller-less
`bisection_ci_single_bound_cpp` that TODO-17p deletes); and
`em_algorithm_zero_inflated_mixtures.md → TODO-1..5` (an EM-then-Newton
hybrid start for ZINB/ZIP, feeding `multistart_nonconcave_likelihoods.md`
as one more deterministic start; targets the failure mode
`../bug_fix_plans/negbin_dispersion_convergence.md` patches). Both gated on the harness.
One audit row is an outright Adopt with no harness gate (v1.1.0, `→
TODO-17w`): `brent_ci_inversion.md` → TODO-1..3 — the score / gradient /
Bartlett-LR CI inverter (`pval_invert_ci_cpp`) polishes by pure bisection
while the LR inverter beside it uses Newton; Brent on the same bracket,
~20 → ~5–8 refits per bound, bound unchanged within `tol`. No dependencies;
`lrt_ci_newton.cpp` only — not applicable to the randomization CI search
(step-function `p(δ)` after TODO-17o).
Also v1.2.0: `kk14_incremental_covariance.md` → TODO-1..5
(`release_v1_2_0.md → TODO-10`; Welford running covariance and
monotone rank tracking for the sequential KK14 design, 5–10× per run,
tolerance-equal with a documented tie caveat; no dependencies).
A further sibling for v1.4.0: `wilcox_hl_kernel_hoisting.md` → TODO-1..6
(`release_v1_4_0.md → TODO-11e`; sort-once / per-thread buffers /
early-stop + warm-bracket bisection in the live HL kernel, 3–4×, all
bit-identical, no dependencies).
And `ridit_kernel_level_slots.md` → TODO-1..5 (`release_v1_4_0.md →
TODO-11f`; precomputed level slots for the default `"control"` reference in
the ridit kernels, ~8–10×, bit-identical, no dependencies).
And `kk_signed_rank_hoisting.md` → TODO-1..5 (`release_v1_4_0.md →
TODO-11g`; hoist the permutation-invariant pair ranks in the KK signed-rank
kernel at `δ = 0`, ~4–5× on the pair component, bit-identical, no
dependencies).
And `rerandomization_objective_vals_gemm.md` → TODO-1..5
(`release_v1_4_0.md → TODO-11h`; GEMM + whitening in
`compute_objective_vals_cpp`, 5–15×; the one item in this batch that is
tolerance-equal rather than bit-identical, with a documented ranking-tie
caveat; no dependencies).
And `small_kernel_hoists_batch.md` (`release_v1_4_0.md → TODO-11i`;
four small independent hoists — greedy `G = MᵀM`, ordinal `y_slot`, Cox
bootstrap ordering, one cached GH rule; no dependencies).

**Parallelization-primitives consolidation (added 2026-09-07, user
decision; unrelated to the algorithmic lane above):**
`consolidate_parallelization_code.md` → TODO-1..4. An investigation into
whether to decompose EDI's fork/mirai parallelism branching into one
shared "threadpool" abstraction found the divergence is mostly load-
bearing, not oversight: `Inference$par_lapply` (already shared by ~10
bootstrap/rand classes) is a stateless one-shot chunked map;
`SimulationFramework$run()` needs a stateful pool with cell-state pushed
once via copy-on-write and a continuous rolling-window dispatch;
`InferenceSuite$run_all_inference()`'s `mcparallel`/PID-kill dispatcher
(from `parallel_fork_cluster_test_safety.md`'s TODO-5) needs
zero-blast-radius force-kill, structurally incompatible with any shared
cluster/daemon object. This plan does **not** merge those three. It
extracts three sub-pieces of plumbing that duplicate across them and have
already drifted apart: the two inconsistent `ensure_mirai_daemons`
implementations (`inference_all_abstract.R` vs. `simulations_framework.R`,
one has a retry loop the other lacks), the mirai
poll/liveness-check/stop-on-death loop (confirmed written out twice in
`simulations_framework.R`, a possible third site to be confirmed), and
the worker single-threading env-var setup (`make_configured_fork_cluster()`
vs. hand-rederived for `run_all_inference_fork_dispatch()`'s `mcparallel`
children). No dependency on the Phase 0 decision batch. Explicitly does
**not** attempt `parallel_fork_cluster_test_safety.md`'s still-open
TODO-6 note (a future fork-after-OpenMP-lock safety pass for
`SimulationFramework$run()`'s fork-cluster path) — that is a separate,
larger project, deferred there on purpose. Release index:
`release_v1_1_0.md → TODO-18`.

**Capability/slow-path registry hardening (added 2026-09-08, user
decision; grew out of a `comprehensive_tests.R`/`path_audits.html`
slow-path recheck session, unrelated to the parallelization item above):**
`harden_registry.md` → TODO-1..4. Two capability-exclusion registries
exist in `inference_class_registry.R` —
`EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` (documented as migration debt,
to be removed once affected classes finish migrating to shallow component
composition) and `EDI_INFERENCE_EXCLUDED_CAPABILITIES` (documented as
permanent). A read-only audit of all 39 classes composing
`ParametricLikelihoodBootstrap` (no mutation — generator introspection
plus `get_effective_components()`) confirms the legacy list's three
entries are exactly the classes whose own `supports_lik_ratio_param_bootstrap()`
guard already resolves to `FALSE` on its own — fully redundant, not debt
still pending a migration. This plan deletes the legacy list and folds its
entries into the permanent one as plain data. A dynamic, package-load-time
resolver (walk the generator's inheritance chain, resolve lazy-component
stubs via `get_lazy_component_dispatch()`) was prototyped and rejected —
real fragility (locked-namespace mutation, lazy-stub bare-invoke crashes,
instance-dependent-guard crashes, all hit during this session's testing)
for zero benefit over reading the hardcoded fact once; drift is instead
caught by a test-only version of the same resolver, never at load time.
Two further duplicated-fact issues surfaced in the same session are
explicitly **out of scope** for this TODO, documented in the plan instead:
`comprehensive_tests.R`'s own four hardcoded, pre-registry exclusion lists
plus two single-class special-cases (`skip_bootstrap`, `skip_rand`,
`skip_ci_rand`, `skip_ci_rand_custom`, `InferenceCountKKGLMM`'s jackknife
exclusion, `InferenceIncidLogBinomial`'s always-on BRT opt-in — each mixes
structural and performance facts, needs a class-by-class sort before any
TODO can be written), and a recheck of the ~82 already-registry-backed
`EDI_COMPREHENSIVE_SLOW_PATHS` category-bucket entries for staleness (same
mechanism as this session's already-completed `exact_operations` recheck,
just larger scope, no new engineering needed). No dependencies. Release
index: `release_v1_1_0.md → TODO-20`.

---

## Phase 5 — Post-decision feature tracks

Each track starts only on a "yes" from Phase 0, and assumes Phase 1 is done
(shallow hierarchy is the substrate every new class/capability lands on).
**Full item lists now live in `release_v1_1_0.md`, one TODO per track —
this section only records the track → TODO mapping and any dependency not
already stated there:**

- **5A. Corrections track** → `release_v1_1_0.md → TODO-5` (core: estimate
  type, bias corrections, the shared-cumulant score/gradient/Bartlett
  batch, Firth); its L1/L2-and-beyond tail **moved 2026-09-06 to
  `release_v1_4_0.md → TODO-14`**, lighten-1.1.0 pass, user decision. Note:
  `marginal_estimand_report.md → TODO-3..8` (the `set_estimand()` switch)
  is **not** part of this track — it was pulled out into the v1.0.0 line
  (amended 2026-08-18, user decision; see `release_v1_0_0.md`'s item 14).
  `marginal_estimand_report.md → TODO-10` (NegBin mixture classes, added
  2026-08-27, plan reopened from `../finished_features/`) is tracked
  separately at `release_v1_1_0.md → TODO-17f` (**moved 2026-09-06 to
  `release_v1_4_0.md → TODO-17`**, lighten-1.1.0 pass, user decision).
- **5B. Response-type track** → `release_v1_1_0.md → TODO-6`.
- **5C. Censored-response track** (after Phase 1C/1F) →
  `release_v1_1_0.md → TODO-7`.
- **5D. Multi-arm track** → `release_v1_1_0.md → TODO-8`.
- **5E. GPU track** (if Phase 0 step 9 said yes) → `release_v1_1_0.md →
  TODO-9`.
- **5F. Sequential many-by-many design family** (added 2026-08-17) →
  `release_v1_1_0.md → TODO-15`.
- **5G. KK one-stage Beta-regression estimator** (added 2026-08-18) →
  `release_v1_1_0.md → TODO-15b` (**moved 2026-09-06 to
  `release_v1_4_0.md → TODO-15`**, lighten-1.1.0 pass, user decision — a
  new estimator family is off-theme for that release).
- **5H. `dead` → `uncensored` rename** (added 2026-08-19) →
  `release_v1_1_0.md → TODO-15c`. Source TODO:
  `../finished_features/interval_censored_survival_response.md → TODO-29`.
- **5I. Survival quantile regression** (added 2026-08-26) →
  `release_v1_1_0.md → TODO-15d`. `survival_quantile_regression.md`:
  `InferenceSurvivalQuantileRegr` (custom self-consistent EM for general
  interval-censored data) plus KK IVWC/one-lik variants. Independent of
  every other track; open risks (EM-reduction validation, sandwich-variance
  rigor, randomization-inference perf) live in the plan itself.
- **5J. Count quantile regression** (added 2026-08-26) →
  `release_v1_1_0.md → TODO-15e` (**moved 2026-09-06 to
  `release_v1_2_0.md → TODO-16`**, lighten-1.1.0 pass, user decision —
  beside the native quantile-regression kernel it should eventually
  share machinery with). `count_quantile_regression.md`:
  `InferenceCountQuantileRegr` (Machado & Santos Silva jittered `rq()`)
  plus KK IVWC/one-lik variants. Independent of every other track.
- **5K. Competing risks for survival responses** (added 2026-08-27) →
  `release_v1_1_0.md → TODO-15f`. `competing_risks_response.md`: `event_type`
  cause code on the existing `survival` type; cause-specific Cox/log-rank,
  Aalen-Johansen CIF difference, Gray's test, RMTL, Fine-Gray. Decision-
  gated (its TODO-1, which joins the Phase 0 batch). **Wave 0 is spliced
  with 5H** (`dead → uncensored`): same event-indicator plumbing, one sweep.
- **5L. Cure-fraction survival inference** (added 2026-08-27) →
  `release_v1_1_0.md → TODO-15g`. `cure_fraction_survival_inference.md`:
  `InferenceSurvivalMixtureCureWeibull` (+ optional promotion-time variant)
  on the existing `survival` type via the shipped `estimand` axis. Decision-
  gated (its TODO-1 joins the Phase 0 batch); sequenced after 5K.

- **5M. Count exposure offset** (added 2026-08-27) →
  `release_v1_1_0.md → TODO-17a`. `count_exposure_offset.md`. Inference
  audit #5.
- **5N. HC-robust standard errors** (added 2026-08-27) →
  `release_v1_1_0.md → TODO-17b`. `heteroskedasticity_robust_standard_errors.md`.
  Inference audit #1.
- **5O. Small estimand additions** (added 2026-08-27) →
  `release_v1_1_0.md → TODO-17c` (**moved 2026-09-06 to
  `release_v1_4_0.md → TODO-16`**, lighten-1.1.0 pass, user decision).
  `small_estimand_additions.md` — Hedges'
  g, win odds / Brunner-Munzel, Mantel-Haenszel, NI/equivalence,
  unconditional QTE, log-link QMLE / Gamma. Inference audit #6, #11,
  #17–#20.
- **5P. Classical sequential-design completions** (added 2026-08-27) →
  `release_v2_0_0.md → TODO-5b-i` (theoretical-design backlog, user
  decision). `sequential_design_classical_completions.md`. Design audit
  #6–#7; theoretical audit #23–#27.
- **5Q. Rerandomization criterion variants, samplers, Grundy-Healy
  diagnostic** (added 2026-08-27) → `release_v2_0_0.md → TODO-5b-ii`.
  `rerandomization_criterion_variants.md`. Theoretical audit #6–#7,
  #11–#18, #20, #43, #45.
- **5R. Optimal-design objective extensions** (added 2026-08-27) →
  `release_v2_0_0.md → TODO-5b-iii`. `optimal_design_objective_extensions.md`.
  Theoretical audit #2–#5, #9, #41–#42.
- **5S. Modern covariate-balancing designs** (Gram-Schmidt Walk, online
  balancing walk, ARM/PSR; added 2026-08-27, online MIO added 2026-09-10)
  → `release_v2_0_0.md → TODO-5b-iv`.
  `modern_covariate_balancing_designs.md`. Theoretical audit #1, #21,
  #22, #30.
- **5T. Cluster-level covariate-balancing designs + randomized
  saturation** (added 2026-08-27) → `release_v1_3_0.md → TODO-2`.
  `cluster_level_covariate_balancing_designs.md`. Design audit #2, #4, #8.
- **5U. Unequal allocation in matching / greedy / minimization + Neyman
  helper** (added 2026-08-27) → `release_v1_3_0.md → TODO-1`.
  `unequal_allocation_matching_greedy_minimization.md`. Design audit #1;
  theoretical audit #38. Depends on the 1.2.0 greedy merge; its ARP-coin
  half ships with 5P in 2.0.0.
- **5V. Encouragement designs / CACE** (added 2026-08-27) →
  `release_v1_4_0.md → TODO-9`. `encouragement_design_cace.md`. Design
  audit #3 / inference audit #3.
- **5W. Treatment × covariate moderation** (added 2026-08-27) →
  `release_v1_4_0.md → TODO-10`. `treatment_covariate_moderation.md`.
  Inference audit #4.
- **5X. Missing-outcome handling** (added 2026-08-27) →
  `release_v1_4_0.md → TODO-11`. `missing_outcome_handling.md`. Inference
  audit #16.
- **5Y. Cluster-robust inference: CR-SE component, cluster GLMM/GEE**
  (added 2026-08-27) → `release_v2_0_0.md → TODO-2a`.
  `cluster_robust_inference_glmm_gee.md`. Inference audit #2. Depends on
  the longitudinal plan's Stage 1 component extraction.
- **5Z. Mediation analysis** (added 2026-08-27) → `release_v2_0_0.md →
  TODO-2b`. `mediation_analysis.md`. Inference audit #12.
- **5AA. Two-arm response-adaptive randomization + inference after
  adaptivity** (added 2026-08-27) → `release_v2_0_0.md → TODO-2c`.
  `response_adaptive_randomization.md`. Design audit #5; theoretical audit
  Part 2D.
- **5AB. Wilkinson r-out-of-k combined-evidence test for `InferenceSuite`**
  (added 2026-08-30, user decision) → Stage 1 `release_v1_1_0.md →
  TODO-17n`; Stage 2 **moved 2026-09-06 to `release_v1_4_0.md →
  TODO-18`**, lighten-1.1.0 pass, user decision. `wilkinson_combined_pval.md`.
  Complements the existing Cauchy combination-test `combined_evidence$pval`
  ("at least one procedure detects a signal") with a "do most procedures
  agree" question CCT's min-dominated statistic structurally cannot
  answer. Staged: the cheap descriptive vote-count field (TODO-2) shipped
  in v1.1.0 regardless of TODO-1's decision on whether the formal,
  dependence-robust-calibrated r-th-order-statistic test (TODO-3/4,
  v1.4.0) is worth its cost.
- **5AC. Model-averaged point estimate/CI for `InferenceSuite`** (added
  2026-08-30, user decision; moved to v1.4.0 same day, user decision) →
  `release_v1_4_0.md → TODO-11b`. `model_averaged_estimand_report.md`.
  Complementary to 5AB (v1.1.0): produces an actual reportable point
  estimate + CI (Buckland, Burnham & Augustin 1997 model-averaging variance
  formula) instead of another existence test. Stage 1 averages within one
  estimand group's distinct model fits (additive, no new dependency); Stage
  2 extends across estimand groups (e.g. different link functions) on the
  shared marginal-estimand scale, depending on the already-shipped
  `set_estimand("marginal_*")` machinery.
- **5AD. Multiplicity-adjusted `results_table` for `InferenceSuite`** (added
  2026-08-30, user decision) → `release_v1_4_0.md → TODO-11c`.
  `multiplicity_adjusted_results_table.md`. Holm/Benjamini-Hochberg
  adjustment applied directly to `results_table`'s raw p-values
  (estimand-grouped by default), reporting *which specific* rows survive
  correction rather than one combined number — a different deliverable from
  5AB/5AC. Thin wrapper over `stats::p.adjust()`; independent of every other
  1.4.0 item.
- **5AE. Sample-splitting / data-carving model selection for
  `InferenceSuite`** (added 2026-08-30, user decision) →
  `release_v2_0_0.md → TODO-6e`. `sample_splitting_model_selection.md`.
  Honest-by-construction alternative to 5AB/5AC/5AD's full-data
  combine/average/adjust approaches: split subjects into a selection set and
  a confirmation set, pick the winning model on the selection set only, test
  only that winner on the confirmation set at full alpha. Real cost
  (confirmatory power) and real architectural cost (`Design`-level
  splitting, especially for sequential matching-on-the-fly designs), hence
  2.0.0 scope rather than an additive v1.x item.
- **5AF. Selective (post-selection) inference for `InferenceSuite`** (added
  2026-08-30, user decision) → `release_v1_4_0.md → TODO-11d`.
  `selective_inference_post_selection.md`. Technically strongest honest
  answer to "picked the best of k models": p-values/CIs already valid
  conditional on the selection event (PoSI or data carving), no data
  sacrificed to a split unlike 5AE. Scoped narrowly (Phase 0 + one pilot
  class, `InferenceContinOLS`) since a full rollout is per-model-class work,
  not a generic wrapper — broader rollout may move to 2.0.0 alongside 5AE's
  data-carving stage depending on the pilot's measured cost. Its
  design-based route (the rejection-sampled conditional randomization
  test, `→ TODO-7`) is unblocked by 5AI Phase A (v1.1.0) and ships as
  `TODO-17y`'s stretch sub-item (f) if that lands with margin (2026-09-05).
- **5AG. E-values / safe testing for `InferenceSuite`** — **SHELVED
  2026-09-09 (user decision, resolving `e_value_safe_testing.md`'s TODO-1 as
  "no"), removed from `release_v2_0_0.md → TODO-6f`.** `e_value_safe_testing.md`.
  Its entire justification was staying valid under *adaptive*
  stopping/inclusion of more tests — a property EDI's workflow has no use
  for, since `applicable_design_classes` is discovered structurally and fit
  once, never grown mid-stream. Without that use case the plan's own text
  concedes Stage 1 is a valid but less powerful alternative to CCT, for no
  benefit. Kept as an idea record, not an active plan; revisit only if EDI
  ever grows a genuine interim-look/group-sequential workflow.
- **5AH. `ModelDiagnostics` — per-model assumption batteries** (added
  2026-09-02, user decision; split 2026-09-02 from a briefly combined
  plan; **moved to v1.1.0 on 2026-09-05, user decision**) →
  `release_v1_1_0.md → TODO-17z` (was `release_v2_0_0.md → TODO-6g`).
  `model_diagnostics_framework.md`. The *absolute* half of model
  criticism: each class declares its own assumption checks in the
  registry like capabilities (Cox PH via Schoenfeld, Poisson
  overdispersion, proportional-odds proportionality, logistic
  separation/calibration as pilots — the last surfacing the existing
  internal separation guard), typed results, one report shared with
  `SolverDiagnostics`' numerical rows, never gating on the treatment
  effect, with the
  handoff rule guarding against diagnose-then-switch pretest bias. Its
  TODO-1(e) is decided: checks are in-sample, no v2.0.0 substrate is
  needed, so the contract + pilots ship in v1.1.0 alongside 5AI's Phase
  A (sequenced after `SolverDiagnostics` for the shared report surface).
  **Amended 2026-09-10 (user decision): the per-class rollout ledger this
  entry originally deferred is promoted to scoped v2.0.0 work** —
  `release_v2_0_0.md → TODO-6i` — extending the pilot's nine families to
  all 66 `likelihood_tier != "none"` classes (verified against
  `public_api_inventory.csv`) plus the visualization layer (`ggplot2`
  diagnostic plots per check type, HTML, optional `plotly`/`DT`) the
  pilot's own TODO-5 never detailed. The v1.1.0 pilot scope above is
  unchanged by this amendment.
- **(new, added 2026-09-10, user decision, no Phase letter — see the
  v3.0.0 note's precedent above for why): `DesignDiagnostics`** →
  `release_v2_0_0.md → TODO-6j`. `design_diagnostics_framework.md`. The
  design-side sibling of 5AH, commissioned by a gap 5AH's own plan
  explicitly flagged as out of scope: registry-declared, per-design-family
  checks (baseline "Table 1" with a hard no-significance-testing rule;
  SMD/Love plots; eCDF balance overlays; the randomization/permutation
  distribution visualized via the existing `draw_ws_according_to_design()`
  replay contract; propensity overlap for `DesignObservational*` only;
  match/cluster structure diagnostics visualizing the existing Grundy-Healy
  concurrence statistic; sequential accrual-balance-over-time), sharing
  5AH's reporting layer. Meant to become one combined pre-analysis report
  with `ModelDiagnostics` eventually, not a separate document long-term.
- **(new, added 2026-09-10, user decision, no Phase letter, same
  precedent): `InferenceSuite` interactive reporting** →
  `release_v2_0_0.md → TODO-6k`. `inference_suite_interactive_reporting.md`.
  The retrofit the two entries above already cross-referenced:
  `DT::datatable()` for the existing (often 40+ row) results table,
  `plotly::ggplotly()` wrapping the existing CI forest plot, both
  `Suggests`-gated with a bit-for-bit-identical static default. Initially
  targeted at v1.2.0, corrected same day to v2.0.0 since v1.2.0's own
  theme is explicitly "no new statistical functionality."
- **(new, added 2026-09-16, user decision, no Phase letter, same
  precedent): Incidence randomization CI, risk-difference estimand
  family** → `release_v2_0_0.md → TODO-6l`. `rand_ci_for_incidence.md`.
  Implements Rigdon & Hudgens (2015)'s attributable-effects Bonferroni
  construction to replace the hard `stop()` stopgap
  (`incidence_randomization_cis.md`) for the risk-difference-scale
  incidence estimand family; other incidence estimand families
  (log-odds-ratio, risk-ratio) remain owned by
  `incidence_randomization_cis.md → TODO-17k` (v1.1.0). Not architectural
  like the rest of v2.0.0's scope — purely additive — but slated here per
  explicit user decision.
- **5AI. `ModelSelection` — comparative fit over the model × formula
  grid** (added 2026-09-02, user decision; the *relative* half of the
  same split; **split into two release phases on 2026-09-05, user
  decision; Phase A widened and Phase B narrowed again on 2026-09-06,
  user question**) → **Phase A: `release_v1_1_0.md → TODO-17y`** (every
  design family); Phase B: `release_v2_0_0.md → TODO-6h` (response types
  only).
  `model_selection_framework.md`. Likelihood-tier-gated criteria (AIC
  only at `"full"`, QIC at `"quasi"`, partial-likelihood AIC at
  `"partial"`, CV/scoring rules everywhere) over `~w`/`~w + .`/`~w * .`/spline
  grids, CV folds on `resolve_resampling_unit()` units, 5AH's checks
  wired in as assumption gates, criteria never keyed to the treatment
  effect,
  and the report ending in a handoff to this family's honest test steps —
  including its own new mechanism, a selection-inclusive randomization
  test wrapping the entire diagnose-choose-fit pipeline as the
  randomization statistic (valid under the sharp null for any statistic;
  selection costs compute, not validity). **Two recorded findings, both
  correcting the same underlying conflation:** (2026-09-05) the
  selection-inclusive randomization test needs *no* `Design`-level
  fold/split substrate — it is a client of `InferenceRandCustom`
  (`inference_rand_custom.R`; replaced the prior `set_custom_
  randomization_statistic_function()` hook in 2026-09-13's
  `fix_custom_randomization_statistic.md`, `finished_features/`) (~~and under
  treatment-blinded selection it commutes with the test and collapses to
  the plain randomization test of the winner at zero extra cost~~ —
  **removed 2026-09-06, user decision:** `w` is in every fit, every
  replicate re-runs the whole pipeline, embarrassingly parallel over
  `set_num_cores()`'s fork/`mirai` pool; see the plan's §5 removal note); its
  2.0.0 slating had been inherited from 5AE's fold problem, which it
  never shared. (2026-09-06) **The CV-fold substrate was never actually
  shared with 5AE either** — this plan's own remaining need, CV folds for
  the comparative-criteria layer, is weaker than 5AE's (avoid
  leakage across already-linked units in static, already-realized data,
  vs. 5AE's requirement that a subject subset itself be a valid design
  realization), and `resolve_resampling_unit()` already provides it
  uniformly for every design family — fixed, matched-pair, cluster, and
  KK-family sequential matching-on-the-fly alike, since that function
  dispatches on matching/clustering/blocking structure, never on
  assignment timing. So Phase A (**every design family**, continuous +
  incidence, the workflow + the test + provenance + CI inversion
  (post-grant, paired with the Garthwaite–Buckland driver — 2026-09-07) +
  simulation study) is v1.1.0 — and the scoped deliverable of the R
  Consortium ISC proposal (`new_research_ideas/grants/26_10_01_RcISC/isc_grant.qmd`,
  re-scoped 2026-09-06 to this widened Phase A, no blinding claims) — while Phase B
  narrows to just the remaining response types, with an open question
  (not yet resolved) whether that remainder still belongs in 2.0.0 or
  fits v1.4.0's response-and-data-extensions theme better. 5AE's own
  difficulty (splitting a sequential design's subjects) is unaffected by
  either correction and remains a genuine, unshared 2.0.0 problem.
- **5AJ. Design/inference dependence-structure guard** (added 2026-09-09;
  **revised same day, user challenge**: the first draft gated *any*
  dependence-naive class uniformly — corrected after checking the
  statistics, since a naive pooled/unpaired Wald SE on a linear-contrast
  estimand, e.g. `InferenceAllAverageDiff`, is provably conservative on a
  blocking/matching design, never anti-conservative, so it must not be
  gated the same way as logistic regression or clustering) →
  `release_v1_1_0.md → TODO-21`. `design_inference_dependence_guard.md`.
  `discover_applicable_inference_classes()`/`is_inference_class_compatible_
  with_design_metadata()` (`inference_suite.R:69-83, 136-164`) only check
  whether a design gives a class structure it *requires*
  (`requires_kk`/`requires_blocking`); nothing checks the reverse — whether
  a design *imposes* dependence a class's Wald-path variance ignores. Now a
  tiered severity model: Tier 0 (`ci_method = "rand"`, exact regardless —
  the design's own re-randomization already encodes blocking/matching/
  clustering); Tier 1 (linear-contrast estimand + blocking/matching on the
  Wald path — conservative only, advisory note, no gate); Tier 2
  (nonlinear-link estimand, e.g. logistic regression, + blocking/matching
  — noncollapsibility/attenuation risk — or clustering for any estimand —
  hard gate on the Wald-path compute methods specifically, not on
  `$new()`, since `rand`-path methods on the same object stay exact and
  unblocked). Companion to 5Y (`cluster_robust_inference_glmm_gee.md`) and
  inference audit #2 — 5Y builds the correct general-purpose clustering
  alternative (v2.0.0); this plan stops silent misuse of the genuinely
  dangerous combinations now (v1.1.0), including matched pairs, which
  already have a correct answer today (the KK pair family) and don't need
  to wait on 5Y. **Second revision, same day** (user question: does tier
  assignment need bespoke math per class?): no — both tier inputs are
  cheap, already-established structural lookups (design classes get a
  one-time `splits_arms`/`shares_arm` tag from which dependence component
  they compose; inference classes get a one-time link-function
  `estimand_linearity` tag, default-conservative), following the general
  sandwich-variance sign argument and the noncollapsibility literature
  rather than a fresh derivation per `(class, design)` pair — `O(design
  classes) + O(inference classes)`, not a combinatorial audit. **Third
  revision, same day** (user question: legal/size-preserving isn't a
  reason to stay silent, and wouldn't showing every conservative estimator
  in `run_all_inference()` pollute the comparison?): Tier 1 gains a real
  `warning()` (once-per-session-throttled, so simulation loops aren't
  flooded) plus a `dependence_note` results-table column, rather than
  either silence or exclusion. Not excluded, because a different class
  targeting a different estimand on the same design is the suite's
  documented "many valid keys" behavior (TODO-19's lock-and-key doc), not
  redundancy — the actual redundancy (a class's own dominated Wald number
  sitting unlabeled next to its own exact `rand` number) is what the
  warning/column target. **Fourth revision, same day** (follow-up
  question: doesn't that redundancy specifically poison the Cauchy
  combined-evidence p-value, not just the display table?): checked the
  actual weighting code — `run_all_inference()`'s `methods = NULL` default
  already fans out to all 13 method sentinels per class (not just `rand`),
  and `combined_evidence`'s default `"estimand_grouped"` weighting divides
  fairly *across* estimand groups but counts rows, not classes, *within*
  one — so a class with more supported methods already gets
  proportionally more combined-evidence weight than a single-method class
  targeting the same estimand, on any design, independent of dependence
  structure. This is the identical failure mode `inference_suite_plan.md`'s
  own TODO-15 rationale warned about for redundant classes, just not
  extended to one class's own method fan-out. Fix: `combined_evidence`
  weighting takes at most one (highest-priority) row per `(class,
  estimand)`; `results_table` itself is untouched.

### Audit reports (2026-08-26/27) — reference, not work items

Three literature audits now sit in this directory and are the source of
5I–5L and of a ranked backlog that has **no owning plan yet**:
`missing_inference_classes_literature_audit.md` (inference classes vs.
applied practice; 32 items, univariate/multivariate-tagged),
`missing_design_classes_literature_audit.md` (design classes vs. applied
practice; 33 items, arms/assignments-tagged), and
`missing_theoretical_design_classes_literature_audit.md` (design classes vs.
the methodological literature; 59 items). Rule of use: an audit
recommendation enters a release index only once it has a scoping report or
a TODO in an owning plan — cite the audit item number when creating one.
`nominal_response_type_report.md` was rewritten 2026-08-27 against these
audits; its own TODO-1 now carries a recorded "no / defer" recommendation.

---

**Repository hygiene (added 2026-09-16, user decision; grew out of the
CONTRIBUTING.md / pre-push-hook work — "what else can we gate before a
push?"; *(maintenance)*, no user-visible effect, no dependency on any
phase above — schedule anywhere in v1.1.0):**
`implement_a_lintr.md` → TODO-1..4. EDI has no `.lintr`, and its house
style is the inverse of lintr's defaults (measured 2026-09-16 over
`R/EDI/R`: 26,306 statement-level `=` assignments vs. 605 `<-`; 71,133
tab-indented lines vs. 5,622 space-indented), so lintr cannot simply be
switched on — the first step is a `.lintr` that *describes* the code as
written (zero style findings on the current tree, every correctness
linter on), then a triage of the correctness findings (the real payoff:
`object_usage`, `equals_na`, `seq`, `vector_logic`), then one explicit
user decision on the `<-`/space minority (recommended: freeze via
per-file exclusions, migrate when touched — not a repo-wide reformat),
then gating: content-gated in `.githooks/pre-push` on changed
`R/EDI/R/*.R` plus a path-filtered CI step with inline PR annotations.
`spellcheck.md` → TODO-1..3. The non-controversial sibling:
`spelling::spell_check_package()` with a bootstrapped `inst/WORDLIST`
for the statistical vocabulary, `Language: en-US` in `DESCRIPTION`, and
`spelling::spell_check_test()` in `tests/spelling.R` so new typos fail
`R CMD check` in our matrix (skipped on CRAN); hook integration reuses
`fast_roxygenize`'s roxygen-edit trigger plus vignette/`NEWS.md` changes.
Release index: `release_v1_1_0.md → TODO-23` (lintr), `→ TODO-24`
(spelling).

**`KKQuantileRegrOneLik` randomization CI** (added 2026-09-17, found via a
raw `comprehensive_tests_results_nc_1_*.csv` audit, not a user report; no
dependency on any phase above — schedule anywhere in v1.1.0):
`../bug_fix_plans/KKQuantileRegrOneLik_rand_ci.md → TODO-1..6`.
`InferenceContinKKQuantileRegrOneLik`/`InferencePropKKQuantileRegrOneLik`
compose `QuantileRandomizationCI` (Zhang test-inversion bisection) without
their `KKQuantileRegrOneLik` component ever supplying the
`compute_rand_pval_matched_pairs`/`compute_rand_pval_reservoir` hooks that
bisection requires from its host — every call silently collapsed to a
zero-width interval at the point estimate instead of erroring (~0-1%
empirical coverage vs. ~95% nominal, confirmed over ~1,644 audited rows).
Same symptom family as `incidence_randomization_cis.md` (a randomization
CI silently reporting a wrong-but-plausible answer instead of failing) but
a different mechanism (missing composition hooks, not a scale mismatch); a
`stop()` stopgap landed 2026-09-17, same pattern as that plan's own. The
likely-cheap real fix (route through the already-correctly-wired generic
`InferenceRandCI` bisection instead of Zhang, since the stacked-model
estimator already supplies that path's own hooks) is unverified and needs
its own decision before implementing. Release index:
`release_v1_0_5.md → TODO-7` (was `release_v1_1_0.md → TODO-25`).

**Stereotype-logit multimodal likelihood** (added 2026-09-22, found the
same way as `TODO-7` (old numbering `TODO-25`); no dependency on any phase above): `fix_multimodal_
log_liks.md → TODO-1..8`. The 2026-09-21 fix to
`InferenceOrdinalStereotypeLogitRegr`'s delta-constrained null refit
(multi-start) left a residual: the likelihood is multimodal and
`compute_estimate()`'s own unconstrained fit is single-start, so it can
silently return a non-global optimum (~3% of `n=50` fits). Explains a
residual ~13% Type-I error at `n=50` (vs. 6.5% at `n=100`). The fix
(multi-start `generate_mod()`) changes reported point estimates in the
affected fits, so it needs golden/reference-parity re-derivation before it
ships. Release index: `release_v1_0_5.md → TODO-8` (was `release_v1_1_0.md → TODO-30`).

**Stale worker-cache in reused-worker resampling** (added 2026-09-22,
found the same way as `TODO-7`/`TODO-8` (old numbering `TODO-25`/`TODO-30`); three new checks —
`biased_estimate`, `bad_type1_error`, `low_power` — added to
`audit_comprehensive_results.R` itself this wave; **fixed and merged**):
`../bug_fix_plans/stale_worker_cache_resampling.md → TODO-1..8`. A correctness bug: any
class whose point-estimate cache guard used a key outside the reused
randomization/bootstrap worker's narrow, hardcoded reset list had every
permutation/bootstrap draw after the first silently reuse the first
draw's stale fit — collapsing the resampling distribution to a constant,
regardless of which draw was used (proven: `InferenceOrdinalGCompMeanDiff`
rejected a true null 100% of the time instead of 5%). Fixed systemically
(allowlist → denylist reset, `cached_values` reconciled to a
`duplicate()`-derived keep-list) plus a permanent non-degeneracy
regression test. Release index: `release_v1_0_5.md → TODO-9` (was `release_v1_1_0.md → TODO-31`).

**MC coverage-truth uses the wrong covariate set** (added 2026-09-22,
found the same way; a harness bug, not an inference-code bug): `fix_mc_
coverage_truth_covariate_mismatch.md → TODO-1..6`. `get_coverage_truth()`'s
Monte-Carlo path fits the class's own estimator against a synthetic
single-covariate dataset to compute the coverage target, but the graded
rows were generated with the real dataset's full multi-column covariate
matrix — for a non-collapsible coefficient the adjustment set changes the
target itself. Confirmed on 13 of 25 `COVERAGE_MC_SPEC` classes (a 14th,
`PropQuantileRegr`, found via a per-dataset check after the pooled check
looked clean). Fixed via a shared `coverage_truth_uses_real_covariates()`
helper. `KKStratCoxPHOneLik`/`KKLWACoxPHOneLik` remain untrustworthy under
the fix (their MC truth hasn't converged, likely genuine finite-sample
attenuation bias, not a further harness bug) — do not re-run those two
pending further work. Release index: `release_v1_0_5.md → TODO-10` (was `release_v1_1_0.md → TODO-32`).

**Cox Bartlett-approx likelihood-ratio correction** (added 2026-09-22,
user-requested investigation; **resolved — do not enable**):
`enable_cox_bartlett_approx.md`. A 300+300-rep validation of the
currently-forced-off Bartlett-approx path on `InferenceSurvivalCoxPHRegr`
showed no improvement over plain Wald (Type-I 0.077 vs. Wald's 0.057, CI
coverage 0.937 vs. 0.947) — mild over-rejection/under-coverage if
anything. Decision: leave both Cox classes' explicit `FALSE` as they are.
Release index: `release_v1_0_5.md → TODO-11` (was `release_v1_1_0.md → TODO-33`).

**Latent `cached_mod` reset gap** (added 2026-09-22, found during the
stale-worker-cache fix's (release `TODO-9`, old numbering `TODO-31`) own
final review, not a new audit finding; no concrete class
reaches it yet): `../bug_fix_plans/stale_worker_cache_resampling.md → TODO-9`
(that plan file's own internal TODO numbering, unrelated to the release
index). One level up from the `cached_values` gap release `TODO-9` fixed, the same
randomization loader still resets a hand-maintained private-field
allowlist that's missing `cached_mod` — the identical failure shape,
just one field over. Confirmed a landmine, not a live defect (every
concrete class writes `cached_mod` unconditionally rather than reading it
stale). Release index: `release_v1_0_5.md → TODO-12` (was `release_v1_1_0.md → TODO-34`).

**`InferencePropGCompMeanDiff` randomization distribution all-NA** (added
2026-09-22, surfaced as a `KNOWN_BROKEN` entry in release `TODO-9`'s (old
numbering `TODO-31`) regression
test; **fixed 2026-09-23**): `../bug_fix_plans/prop_gcomp_sample_usable_gating.md →
TODO-1..6`. An error-shaped bug (not silently-wrong like release `TODO-9`), and a
different mechanism — worker-state gating, not stale caching: the class's
reused-worker randomization path fell through to a bootstrap-shaped
estimator gated on a flag only the bootstrap loader ever set, permanently
stuck `FALSE` on the `rand` path. Fixed with a class-specific
`compute_randomization_worker_estimate()` override. CSV regeneration still
open. Release index: `release_v1_0_5.md → TODO-13` (was `release_v1_1_0.md → TODO-35`).

**`InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` randomization
distribution all-NA** (added 2026-09-22, surfaced the same way as
release `TODO-13` (old numbering `TODO-35`); **fixed 2026-09-23**): `fix_glmm_weibull_frailty_ivwc_
estimate_only_na_pooling.md → TODO-1..7`. A plain arithmetic NA-propagation
bug, unrelated to release `TODO-9`/`TODO-12`/`TODO-13` (old numbering
`TODO-31`/`TODO-34`/`TODO-35`): `shared()`'s
inverse-variance pooling weight used two variance components
unconditionally, even though they're deliberately `NA` under
`estimate_only = TRUE` (every resampling draw). Fixed with the equal-weight
fallback already correct elsewhere in the same file. CSV regeneration
still open. Release index: `release_v1_0_5.md → TODO-14` (was `release_v1_1_0.md → TODO-36`).

**`InferenceContinLin` parametric-bootstrap Type-I error, design-dependent**
(added 2026-09-23, from the same `bad_type1_error` audit wave as release
`TODO-9` (old numbering `TODO-31`),
originally hypothesized to be the same mechanism — confirmed separate,
still unfixed): `../bug_fix_plans/contin_lin_param_bootstrap_bad_type1_error.md →
TODO-1..7`. Three parametric-bootstrap/likelihood-ratio methods flagged
simultaneously; confirmed NOT release `TODO-9`'s reused-worker path (already
fixed for this class) and isolated to this class's own overrides, not
shared machinery. Rejection rate at a true null ranges from 0.059 (SPBR,
near nominal) to 0.406 (`FixedMatchingGreedy`, 8× nominal) — design-
dependent, but not reproduced with a plain Bernoulli design plus a
correlated covariate, so the actual structured `Design` subclass's
block/match machinery is needed to trigger it. Root cause not yet pinned
down. Release index: `release_v1_0_5.md → TODO-15` (was `release_v1_1_0.md → TODO-37`).

**Ordinal cumulative-link parametric-bootstrap inference** (added
2026-09-23, from the same raw `comprehensive_tests` CSV audit wave as
release `TODO-9`/`TODO-15` (old numbering `TODO-31`/`TODO-37`); no dependency on any phase above — schedule anywhere
in v1.1.0): `../bug_fix_plans/ordinal_cumulative_link_null_refit_multistart.md →
TODO-1..7`. Two distinct bugs found investigating
`InferenceOrdinalCloglogRegr`'s 60% Type-I error on
`compute_param_bootstrap_pval()`. Fixed: a single-start delta-constrained
refit in `get_likelihood_test_spec()`/`simulate_under_lik_null()` — the
same vulnerability already found and fixed in
`InferenceOrdinalStereotypeLogitRegr` (release `TODO-8`, old numbering
`TODO-30`); same multi-start fix
applied. Root-caused but not fixed, and the actual cause of the reproduced
Type-I inflation: the shared `simulate_param_boot_ordinal_y()` helper
generates bootstrap replicates using the model's native fitted parameters,
but this class's own `compute_estimate()` negates that native coefficient
for public use — the helper's generative formula has the wrong sign for
this class's fit convention, so every bootstrap replicate is generated
under the *negated* true value. A per-class audit found this does not
affect the five sibling classes the same audit wave flagged (`Cauchit`,
`PropOddsRegr`, `KKCondAdjCatLogitRegr`, `AdjCatLogitRegr`,
`OrderedProbitRegr`) — none negate their native coefficient the same way,
or don't use the shared helper at all; their own flags are on unrelated
mechanisms, out of scope here. A package-wide sweep for any other class
sharing both the helper and the negation pattern is still open. Release
index: `release_v1_0_5.md → TODO-16` (was `release_v1_1_0.md → TODO-38`).

**Cox risk-set cache staleness** (found 2026-08-30, slotted into v1.0.5
2026-09-24 from "unassigned"; no dependency on any phase above):
`../bug_fix_plans/cox_risk_set_cache_staleness.md → TODO-1..5`. The
`InferenceCoxPH`/`InferenceStratifiedCoxPH` risk-set caches are guarded only
on `w` while embedding `y`/`dead`. No confirmed wrong result yet (plan
TODO-1 is the exposure audit). Release index: `release_v1_0_5.md → TODO-30`.

**Incidence identity-link risk-difference subsampling inflation** (added
2026-09-24, same audit-triage wave; no dependency on any phase above):
`../bug_fix_plans/investigate_incid_binomial_identity_subsampling_inflation.md
→ TODO-1..6`. `InferenceIncidBinomialIdentityRiskDiff` shows ~2.6× nominal
Type-I error on subsampling and m-out-of-n bootstrap p-values, formula-
independent; leading (unconfirmed) hypothesis is boundary-rejected subsample
fits biasing the pivot distribution. Investigation-first. Release index:
`release_v1_0_5.md → TODO-27`.

**`InferenceAllSimpleAverageDiff` studentized-bootstrap / jackknife-Wald SE
quality** (added 2026-09-24, cross-class audit-triage fork; no dependency on
any phase above): `../bug_fix_plans/investigate_average_diff_bayesian_jackknife_se_quality.md
→ TODO-1..4`. An open investigation (medium-low confidence; a Kish
effective-n vs. raw-n Welch asymmetry is the unconfirmed hypothesis). Release
index: `release_v1_0_5.md → TODO-29`.

**KK21stepwise randomization p-values conservative at the null** (added
2026-09-24, from triaging the stale-cache regeneration findings; no dependency
on any phase above): `../bug_fix_plans/investigate_kk21stepwise_incidence_randomization_pval_conservative.md
→ TODO-1..4`. Open investigation. Release index: `release_v1_0_5.md → TODO-53`.

**Test-comment audit findings** (added 2026-09-24; no dependency on any
phase above): five plans from defects that test authors recorded but did not
fix. `../bug_fix_plans/glmm_variance_component_sigma_collapse.md →
TODO-1..6` (`release_v1_0_5.md → TODO-31`; the targeted, observed-wrong-answer
subset of the multistart problem in Phase 1E/`multistart_nonconcave_likelihoods.md`);
`../bug_fix_plans/ridit_treatment_reference_degenerate_estimate.md →
TODO-1..5` (`→ TODO-32`; decide before `ridit_kernel_level_slots.md`);
`../bug_fix_plans/rand_ci_high_precision_refinement_upper_bound.md →
TODO-1..4` (`→ TODO-33`; touches the randomization-CI search-precision area);
`../bug_fix_plans/interval_censored_compute_shared_cache_guard.md →
TODO-1..4` (`→ TODO-34`); and the batch
`../bug_fix_plans/test_comment_audit_small_defects.md → TODO-1..12`
(`→ TODO-35..46`, one release TODO per plan item).

**Full `release_v1_0_5.md` reconciliation, 2026-09-24 (user-requested):** the
20 items below had no entry anywhere in this file — found via a systematic
cross-check after a numbering collision (two concurrent sessions both used
`TODO-31`/`TODO-32`, resolved by renumbering to `TODO-50`/`TODO-51`; see
that file) exposed how far index and release file had drifted apart.

**Reusable-bootstrap-worker support for `InferencePropZeroOneInflatedBetaRegr`**
(added 2026-08-27): `../bug_fix_plans/reusable_bootstrap.md → TODO-1..6`. The
one class (of 51) missing the `get_bootstrap_worker_spec()` fast path;
its jackknife rebuilds a fresh `Design`/`Inference` object per fold instead
of reusing one warmed-up worker. R-layer only, must reproduce bit-identical
jackknife results. Release index: `release_v1_0_5.md → TODO-1`.

**Randomization CI construction audit** (added 2026-09-04, found
empirically): `../bug_fix_plans/randomization_ci_construction_audit.md →
TODO-1..4`. Two findings: **§A**, Cox-family classes ran the generic
randomization-CI driver on the wrong scale (log-time vs. log-hazard-ratio);
fixed by excluding the six log-HR classes from the `randomization_ci`
capability. **§B**, an earlier draft's null-construction claim was wrong;
closed with no code change, pinned by a test. Release index:
`release_v1_0_5.md → TODO-5`.

**`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` optimizer stability**
(added 2026-09-11, timing investigation, not a user report):
`../bug_fix_plans/clayton_loggamma_frailty_optimizer_stability.md →
TODO-1..4`. A ~200× bimodal slowdown in the Bartlett-approx Monte-Carlo
null replicates, traced to the Clayton-copula/loggamma-frailty optimizer
having no bound on its dependence parameter (unlike the sibling
normal-frailty optimizer) plus a stale-gradient mismatch. Additive fix,
needs golden-parity check. Release index: `release_v1_0_5.md → TODO-6`.

**`InferenceAllSimpleWilcox` resampling-family p-values collapse to
exactly 1** (added 2026-09-23, `pval_miscalibration` audit's extreme-
violation triage — ACAT-combined p as low as 2.5e-300):
`../bug_fix_plans/simple_wilcox_hl_degenerate_pval_boundary.md → TODO-1..9`.
A resurfacing of an already-partially-fixed bug: the Wald-family variant
of this mechanism was fixed 2026-09-06, but the resampling-family methods
(`rand`, `bootstrap*`, `m_out_of_n_bootstrap`, `subsampling`) still carry
it — the Hodges-Lehmann estimate lands on exactly 0 on tied data, saturating
`min(1, ...)`. Also explains the same class's CI undercoverage via the
identical mechanism (later found, same plan). Recommended fix: a mid-p/
tie-splitting correction in the shared two-sided p-value formula. Release
index: `release_v1_0_5.md → TODO-17`.

**`smoothed` randomization-bootstrap p-value adds unclamped noise to
binary/ordinal responses** (added 2026-09-23, `pval_miscalibration` audit —
one shared function_run variant hit ~85 (class, response_type) cells with
wildly inconsistent direction/severity): `../bug_fix_plans/rand_bootstrap_
smoothed_noise_unclamped.md → TODO-1..8`. `add_rand_bootstrap_smooth_noise()`
has an explicit rounding/clamping special case for `count` responses
(fixed 2026-09-15) but none for `incidence`/`ordinal` — continuous Gaussian
noise lands on 0/1 or integer-coded responses. Bounded to the R-level
dispatch path; C++ batch kernels apply noise themselves and are believed
unaffected. Release index: `release_v1_0_5.md → TODO-18`.

**`InferenceIncidKKModifiedPoisson` chronic under-rejection — SE-quality
investigation** (added 2026-09-23, same triage wave as TODO-17/18; tracked
as an open investigation, not a fix plan): `../bug_fix_plans/
investigate_incid_kk_modified_poisson_se_quality.md`. Original ~4×
SE-overestimation hypothesis refuted by a faithful harness replay (found
1.23-1.33×, and the dramatic zero-rejection symptom did reproduce with the
real DGP — magnitude of the SE gap remains genuinely ambiguous at the rep
counts tried). Broadened into a cross-class "per-class SE-estimator
quality" hypothesis via a separate studentized-bootstrap-pivot trace.
Release index: `release_v1_0_5.md → TODO-19`.

**`InferenceContinQuantileRegr` bootstrap-family Type-I inflation — BRT
tie-sensitivity investigation** (added 2026-09-23, same triage wave):
`../bug_fix_plans/investigate_contin_quantile_regr_bootstrap_family_
inflation.md`. Original `fit_warm_keep` stale-cache hypothesis refuted by
direct code trace (that path never executes for the flagged methods). New
lead: with-replacement BRT resampling manufactures exact row ties, to
which `quantreg::rq()`'s simplex method and sandwich SE are known to be
numerically sensitive — not yet reproduced; may end up as a documented
limitation rather than a fix. Release index: `release_v1_0_5.md → TODO-20`.

**`InferenceIncidKKGEE` bootstrap-family Type-I inflation investigation**
(added 2026-09-23, same triage wave): `../bug_fix_plans/
investigate_incid_kk_gee_bootstrap_family_inflation.md`. Reservoir-
singleton cluster-bootstrap-mishandling hypothesis refuted by code trace
AND direct reproduction (the resampler is textbook-correct; a fresh
true-null fixture reproduced nominal/conservative rates, not the historical
0.31). Historical finding itself now unconfirmed — needs the exact
triggering dataset/formula, not a fresh fixture, before any further work.
Release index: `release_v1_0_5.md → TODO-21`.

**KK survival compound classes fed real `NA`s into the fitter for censored
subjects during randomization inference** (added 2026-09-23/24, found and
fixed by a separate concurrent session, recorded here at user request; no
dedicated plan file — the fix's own detailed comment lives in the affected
source files): `InferenceSurvivalKKLWACoxPHOneLik` (original site) and
`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`/`...IVWC` (identical
buggy snippet, found the same day). Root cause: `y`/`dead` were re-derived
from the raw `Design$y` field directly (`dead = as.numeric(!is.na(y))`),
but post the `y`/`y_L`/`y_R` migration `y` uses `NA` to encode censoring,
not a missing value — every censored subject's response was silently fed
to the fitter as a real `NA`. **Fixed**; a follow-up sweep of all 16
`inference_survival_*.R` files found and confirmed-fixed one more site
(`InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`) and no others. Release
index: `release_v1_0_5.md → TODO-22` (done).

**`InferenceSurvivalRestrictedMeanDiff` computes RMST to a different
truncation horizon per treatment arm** (added 2026-09-24, `low_coverage`
audit, root-caused same day, high confidence): `../bug_fix_plans/
rmst_mismatched_truncation_horizon.md → TODO-1..7`. τ is derived
independently per arm as that arm's own max observed/censored time, when
RMST requires a shared τ for the difference to be a coherent estimand —
near-universal severe undercoverage (0.53-0.65 vs. 0.95) across nearly
every CI method. Fix is a scoped 3-site shared-τ change, but an intentional
documented DEFAULT CHANGE to the point estimate for mismatched-follow-up
cases. A second, narrower, unconfirmed finding
(`InferenceSurvivalDepCensTransformRegr`) is tracked in the same plan.
Release index: `release_v1_0_5.md → TODO-23`.

**KK-matched Cox proportional-hazards classes — severe CI undercoverage,
isolated to the matching/reservoir-split mechanism** (added 2026-09-24,
same audit-triage wave, root-caused same day): `../bug_fix_plans/
survival_kk_cox_coverage_variance.md → TODO-1..8`. Distinct from `TODO-5
§A`. Plain Cox/stratified-Cox siblings are fine, confirming this is
KK-matching-specific. `InferenceSurvivalKKStratCoxPHOneLik`: medium-high
confidence its inverse-variance pooling of matched/reservoir estimates
wrongly assumes independence. `InferenceSurvivalKKLWACoxPHOneLik`: does
NOT share that pooling pattern (single joint cluster-robust fit) — root
cause not found, needs the C++ cluster-robust vcov kernel read directly.
Release index: `release_v1_0_5.md → TODO-24`.

**`InferenceContinOLS` weighted-bootstrap SE investigation — superseded**
(added 2026-09-24; tracked as an open investigation): `../bug_fix_plans/
investigate_contin_ols_weighted_bootstrap_se.md`. Severe `~.`-specific
miscalibration across reweighting resampling families. Its own unguarded-
`solve()` hypothesis is likely superseded by `TODO-28` (added the same
day), which found an exact mechanistic match for this class's worst-
affected families. Release index: `release_v1_0_5.md → TODO-25`.

**`InferenceSurvivalKKWeibullMarginal` jackknife estimate has catastrophic
single-fold outliers** (added 2026-09-24, found independently twice the
same day, high confidence real): `../bug_fix_plans/
kk_weibull_marginal_jackknife_outliers.md → TODO-1..8`. Apparent "bias"
(mean -0.080) is actually RMSE (2.154), ~27× the bias magnitude — a small
number of catastrophic single-fold outliers (raw values -38.0, +17.5 found
directly), not a mean shift. Root cause hypothesized as an unstable fit on
a degenerate leave-one-out fold configuration, analogous in shape to
`TODO-4`'s unguarded-inverse pattern. Release index: `release_v1_0_5.md →
TODO-26`.

**Reused bootstrap worker never resets `cached_design_matrix` — the
single highest-leverage finding of this whole audit arc** (added
2026-09-24, found via a dedicated cross-class investigation into `TODO-15`/
`TODO-25`'s shared-mechanism question; high confidence, confirmed by
direct code reading): `../bug_fix_plans/bootstrap_worker_stale_design_
matrix.md → TODO-1..10`. `load_bootstrap_sample_into_design_backed_worker()`
(the `subsampling`/`m_out_of_n_bootstrap`/plain-`bootstrap` loader —
previously believed, from this session's original stale-cache fix, to
already be fully correct) resets several caches between draws but never
`w_priv$cached_design_matrix`; `create_design_matrix()` unconditionally
returns the cached matrix if one exists, so every draw after the first
silently reuses draw 1's design matrix while the weights are the current
draw's — a scrambled data/weight correspondence. Confirmed scope has grown
to 12+ classes across 3 waves of cross-class checking (exact mechanistic
match for `InferenceContinOLS`'s worst-affected families), with several
classes explicitly ruled out (the whole KKGLMM/KKCLMM cluster, several
KKCondLogitGLMM classes — none reach the reused-worker path this bug
requires) and a few still unresolved (`InferenceContinKKQuantileRegrOneLik`).
Fix not yet implemented — this file is still pure investigation/scoping.
Release index: `release_v1_0_5.md → TODO-28`.

**`InferenceIncidLogRegr`/`InferenceIncidProbitRegr` broad mild
over-coverage** (added 2026-09-24, first real-data run of the new
`low_coverage` check, medium confidence, likely NOT a bug): `../bug_fix_
plans/investigate_incid_logregr_probitregr_coverage.md`. `TODO-28` ruled
out (hits purely asymptotic methods, same magnitude as bootstrap-family).
Favored explanation: ordinary benign Wald/LR-type CI conservativeness for
binary-outcome GLMs, matching this session's earlier RiskDiff/RiskRatio
"not a bug" precedent — `InferenceIncidProbitRegr` uses MC-refit truth
(immune to a truth-mismatch explanation) yet shows the identical pattern.
One opposite-direction outlier noted, possibly connected to `TODO-29`.
Release index: `release_v1_0_5.md → TODO-47`.

**Count-family GLM `low_coverage` cluster** (added 2026-09-24, same
source, medium-low confidence, root cause genuinely unresolved):
`../bug_fix_plans/investigate_count_glm_family_coverage.md`.
`InferenceCountPoisson`, `InferenceCountNegBin` (broad undercoverage
across both asymptotic AND resampling methods), `InferenceCountZeroInflatedPoisson`
(asymptotic-only) — 50 findings total. `TODO-28` cleanly ruled out for all
3 (design matrix built inline, never touches the broken cache). Leading,
unconfirmed lead: none of the 3 appear in `comprehensive_tests.R`'s
coverage-truth tables, so coverage falls back to raw `beta_T` — but in
tension with nonparametric methods (which should be immune to a
truth-mismatch) showing the same undercoverage. Release index:
`release_v1_0_5.md → TODO-48`.

**`InferenceContinQuantileRegr`'s 33 `low_coverage` findings** (added
2026-09-24, same source, medium confidence, root cause open): `../bug_fix_
plans/investigate_contin_quantile_regr_coverage.md`. The single largest
uninvestigated cluster in this audit wave. Ruled out the obvious
missing-`COVERAGE_MC_SPEC`-entry hypothesis (a direct distributional
argument shows the raw-`beta_T` fallback is actually correct for this
harness's DGP). Two unconfirmed candidates: `quantreg`'s `"nid"` sandwich
SE misbehaving at this harness's near-noiseless noise scale, or
compounding with `TODO-20`'s tie-sensitivity hypothesis. Release index:
`release_v1_0_5.md → TODO-49`.

**Four count-family classes with confirmed-real, unexplained
miscalibration** (added 2026-09-24, promoted from asides inside `TODO-4`'s
and `TODO-9`'s prose — un-homed findings risk getting lost; tracked as an
open investigation): `../bug_fix_plans/investigate_count_family_
unexplained_miscalibration_cluster.md`. `InferenceCountPoisson` (16
families), `InferenceCountQuasiPoisson` (9 families uniformity + 4
coverage), `InferenceCountKKGLMM`, `InferenceCountKKHurdlePoissonOneLik` —
each ruled out from a specific candidate mechanism (`TODO-4`'s unguarded
inverse, `TODO-28`'s stale design matrix) but never root-caused on its own
terms. Release index: `release_v1_0_5.md → TODO-50` (renumbered 2026-09-24
from a colliding `TODO-31`).

**Dead code in `_helper_functions_core.h`** (added 2026-09-24, same
promotion reason as the item above; trivial, no plan file): `set_min_
eigenvalue_if_suspect()` is entirely commented out, so `min_eigenvalue_
information` is never populated by any caller. Fix is delete-or-wire-in, a
decision not yet made. Release index: `release_v1_0_5.md → TODO-51`
(renumbered from a colliding `TODO-32`).

**Six classes with confirmed-real `low_coverage` findings ruled out from
the stale-`cached_design_matrix` bug, never root-caused** (added
2026-09-24, promoted from asides inside `TODO-28`'s cross-class sweep;
tracked as an open investigation): `../bug_fix_plans/investigate_beta_ols_
kkglmm_low_coverage_orphans.md`. `InferencePropBetaRegr`,
`InferencePropZeroOneInflatedBetaRegr`, `InferenceContinKKOLSOneLik`,
`InferenceContinKKRobustRegrOneLik`, `InferencePropKKGLMM`, and the
`InferenceIncidKKCondLogitGLMMIVWC`/`OneLik` pair. Lower-priority
addendum: the 7-class KKGLMM/KKCLMM cluster was also ruled out from
`TODO-28`, but it's not yet confirmed whether that cluster even has real
findings to explain. Release index: `release_v1_0_5.md → TODO-52`.

## Phase 6 — Exploratory / later

1. `sequential_inference.md` — after Phase 1E.4 delivers the public accessors
   its architecture depends on; it remains a research scoping doc until then.
   Scoped as `release_v1_1_0.md → TODO-13`.
2. `save_load_api.md → all TODOs` — after Phase 1E.3, when
   `EDI_DESIGN_COMPONENTS`' `owns_state` makes the serialization audit
   scriptable. Done (2026-08-17): every TODO closed (version stamp +
   accessor, one-time major-version-mismatch warning, full private-field
   serialization audit — which found and fixed a real non-serializable-XPtr
   bug in `DesignFixedOptimal`'s custom-objective path — roxygen "Saving and
   loading" section, and `test-save-load-design.R`); moved to
   `../finished_features/save_load_api.md`. **Reopened (2026-09-01, user
   decision): the file moved back to this directory carrying a new section
   E — Inference-object serialization (motivated by expensive resampling
   state under slow models, e.g. ZOIB bootstrap distributions) — scoped as
   `release_v1_1_0.md → TODO-17r`, **moved 2026-09-06 to
   `release_v1_2_0.md → TODO-19`** (lighten-1.1.0 pass, user decision —
   persistence is off-theme for an inference-quality release). The
   Design-side sections A–D above stay closed as v1.0.0 history; only
   `save_load_api.md → E-1..E-7` is open. Sequenced here in Phase 6
   (additive, independent), cheapest after every v1.1.0 item adding
   `Inference`-side state — including `TODO-17y`'s `ModelSelection`
   provenance object — has landed.**
3. `interval_censored_survival_response_type_report.md → second wave` — per
   Phase 0 step 10; scoped as `release_v1_1_0.md → TODO-12`.
4. `response_types_landscape_report.md → its remaining open TODOs` — refresh
   the landscape after any 5B track ships; scoped as
   `release_v1_1_0.md → TODO-14`.
5. `design_fixed_greedy_pair_switch_merge.md` — explicit post-1.0.0 target
   (user instruction, 2026-08-16); deletes `DesignFixedGreedy`/
   `DesignFixedGreedyDOptimal`, replacing both with
   `DesignFixedGreedyPairSwitch`. Full item list:
   `release_v1_1_0.md → TODO-11`.
6. `quantum_upgrade.md` (added 2026-08-22) — decision-gated scoping report
   (its TODO-1 joins the Phase 0 decision batch, to be taken *after*
   `gpu_optimizations.md → TODO-7`'s backend/dispatch answer, which it reuses).
   Only realistic item is an opt-in QUBO-export + external-sampler hook on
   `DesignFixedOptimal`'s quadratic/ratio objectives (TODO-2..5) — plus, added
   2026-08-23 (user request), the hardware-by-proposal map with run-time
   detection and classical fallback (§I.7 there; TODO-9..12: `detect_qubo_backends()`,
   the `qubo_backend` dispatch with `"none"` default and an opt-in `"auto"`
   chain ending in classical SA, R-native backend adapters, hardware-free tests)
   — **pure R + vendored Apache-2.0 C++ (minorminer `busclique` for QPU
   embedding), no Python/`reticulate` anywhere** (amended 2026-08-23, user
   decision).
   Release index: `release_v1_1_0.md → TODO-9b` (gated on its TODO-1, Phase 0
   step 9b); everything
   else in it is either not a candidate (Tier C) or — the amplitude-estimation
   speedup for randomization p-values, bisection CI inversion and bootstrap
   quantiles (Tier B) — a real quadratic speedup that needs fault-tolerant
   hardware and is kept as a standing kernel-factoring constraint (its TODO-8),
   not scheduled work.

7. `full_test_coverage.md` (added 2026-08-29, user decision) — triage and
   test-writing to take Codecov's line coverage from 64.79% (first
   successful upload after `test-coverage-R.yaml`'s `stop_on_failure =
   FALSE` fix, 2026-08-28) into the high 90s: Phase 1 builds a tracked
   `coverage_gap_registry.csv`; Phase 2 targets the 31 files currently at
   literal 0.00%; Phase 3 works the broadly-thin remainder by weighted
   opportunity; Phase 4 adds a coverage-floor CI gate. Pure
   test-writing/CI-plumbing, no source-behavior change, no dependency on
   any other open plan — run whenever convenient. Release index:
   `release_v1_1_0.md → TODO-17m`, **moved 2026-09-06 to
   `release_v1_2_0.md → TODO-18`** (lighten-1.1.0 pass, user decision;
   the plan's own zero-dependency status is exactly why it cost nothing
   to move).

---

## Phase 7 — Post-2.0.0 (tentative; opened 2026-09-10, user decision)

No Phase-0 decision batch exists for this phase yet — nothing here is
committed, and v2.0.0 remains the frontier of actually-planned work. This
phase exists only to index `release_v3_0_0.md`'s tentative contents: six
independent items (the third through sixth added the day of and the days
after the first two — the third itself a cluster of nine visualization
items), none sharing a TODO-1 decision gate with the others.

1. `finite_mixture_regression.md` (added 2026-09-10) — finite
   (latent-class) mixture regression for existing response families,
   generalizing `em_algorithm_zero_inflated_mixtures.md`'s "EM driver
   reusing each family's existing weighted kernel" pattern from a fixed
   2-part mix of two families to a general K-way mix of one family, with
   EM as the terminal optimizer rather than a start generator. Depends on
   `marginal_estimand_report.md`'s concrete per-family wiring (verify
   landed, not just decided, before starting) for its mixture-weighted
   marginal estimand, and reuses `multistart_nonconcave_likelihoods.md`'s
   random-restart infrastructure for initialization. Release index:
   `release_v3_0_0.md → TODO-1..4`.
2. `bayesian_stan_primary_analysis_report.md` (added 2026-09-10) — a
   `cmdstanr`-backed optional Bayesian primary-analysis family (real
   priors, declared likelihood, posterior probability statements,
   optionally Bayes factors and hierarchical borrowing), complementary to
   and separately labeled from the existing `BayesianBootstrap`.
   Commissioned by `missing_inference_classes_literature_audit.md` item
   21. No structural dependency on the finite-mixture item above — the
   two share this tentative release only because both were scoped the
   same day, not because either needs the other. Release index:
   `release_v3_0_0.md → TODO-1, TODO-5`.
3. **Visualization batch** (added 2026-09-10, from this session's
   visualization brainstorm) — nine items: three brand-new plans
   (`survival_curve_visualization.md` — Kaplan-Meier curves;
   `simulation_framework_visualization.md` — power/operating-
   characteristic curves for `SimulationFramework`;
   `edi_visualization_theme.md` — a shared `theme_edi()`/`edi_palette()`
   foundation, whose own "Scheduling caveat" argues it may belong pulled
   forward into v2.0.0 rather than shipped here, not resolved) plus six
   new sections grafted onto existing plans (two already v3.0.0 —
   `bayesian_stan_primary_analysis_report.md` §4B/TODO-3,
   `finite_mixture_regression.md` §F/step 5 — and four otherwise still
   v2.0.0, only their new section targeting v3.0.0:
   `sequential_inference.md → TODO-6`,
   `response_adaptive_randomization.md → TODO-6`,
   `causal_forest_inference.md`'s "HTE visualization" section,
   `multi_arm_designs.md → TODO-4b`). All nine reuse
   `inference_suite_interactive_reporting.md`'s ggplot2/HTML/`plotly`
   convention. Release index: `release_v3_0_0.md → TODO-6..10`.
4. **`inference_plots.md`** (added 2026-09-11, user decision) — every one
   of the package's 102 concrete `Inference*` classes gets its own
   section listing result/effect plots (not diagnostics, not a
   re-description of `InferenceSuite`'s generic CI forest plot),
   organized by the same 19 model families `model_diagnostics_framework.md`
   §3B/§3C established. A real structural dependency (not mere
   non-overlap) on `survival_curve_visualization.md` for six classes —
   see that file's own note. A genuine gap in that same §3C catalogue
   (`InferenceSurvivalKKRankRegrIVWC`, 35 listed instead of 36) surfaced
   and was fixed while re-verifying the roster for this item. Release
   index: `release_v3_0_0.md → TODO-11..14`.
5. **`optimal_design_finder.md`** (added 2026-09-11, user decision;
   release placement assigned 2026-09-11, also user decision — the one
   open item its own TODO-1 originally flagged) — a continuously-running,
   genuinely open crowdsourced simulation benchmark comparing every
   applicable `(design, inference, response_type)` combination EDI ships,
   publishing results as public Parquet/CSV in a public GitHub repo
   (DuckDB `httpfs`, no server/API/login) rather than a private dataset.
   Pure orchestration/publishing on top of `SimulationFramework` — no new
   statistical method, no new package functionality. Integrity for
   anonymous contribution rests on a trust-tiered CI spot-check (never a
   full re-run), CI-chosen random replicate indices (never a fixed,
   gameable prefix — closed after a direct user challenge), a SHA-256
   commitment hash over raw per-replicate output, and mandatory
   `mirai`/fork execution (serial is resume-unsafe and not cheaply
   spot-checkable until that plan's own TODO-4 lands). Custom functions/
   datasets/`Design`/`Inference` classes require PR review into
   `R/custom_design_simulations/`'s eight subdirectories before they're
   eligible for the public dataset — no loose contributor code or data
   ever reaches it. Every row forces `num_cores`, per-row timing, and full
   hardware/EDI-build provenance (`edi_tuning_hardware_fingerprint()`,
   substantially extended this session), with a client- and CI-enforced
   scrub for genuinely identifying fields. No structural dependency on, or
   from, items 1–4 above — shares this tentative release purely by
   scoping-day coincidence, the same reasoning already covering them.
   Release index: `release_v3_0_0.md → TODO-15`.
6. **`continuous_treatments.md`** (added 2026-09-11) — makes `w` a
   genuinely continuous dose (drug dose, ad spend, duration, …) rather
   than today's hard-coded `{0,1}`
   (`EDI/R/design_fixed_abstract.R:173`, `EDI/R/design_abstract.R:423`),
   on both the design side (a `treatment_type` axis on the root-owned `w`
   state, plus `DesignFixedContinuousUniform` — the MVP randomized
   continuous-dose analog of `DesignFixedBernoulli`) and the inference
   side (a new `"dose_response"` `set_estimand()` value: a fitted average
   dose-response function plus a classical marginal-effect scalar for
   compatibility with the existing Wald/LR/bootstrap/randomization
   contracts). MVP estimator is parametric, reusing existing
   continuous-covariate GLM/OLS/Cox machinery; a generalized-propensity-
   score adjustment wave (Hirano & Imbens 2004) follows. Explicitly not
   Phase I dose-finding (permanently out of scope per
   `missing_design_classes_literature_audit.md` #32 — a safety rule, not
   randomization) and not a full rerandomization/D-optimal continuous-
   dose design or a doubly-robust nonparametric dose-response curve
   (Kennedy et al. 2017) — both deferred past this first landing. No
   structural dependency on, or from, items 1–5 above — shares this
   tentative release purely by scoping-day coincidence. Release index:
   `release_v3_0_0.md → TODO-16..23`.

---

## Phase 8 — Post-3.0.0 (tentative; opened 2026-09-21)

Indexes `release_v4_0_0.md`. Nothing here is committed.

1. `multivariate_response_modeling.md` **Level 3** (added 2026-09-21, user
   decision) — fully parametric joint multivariate models (SUR/MANOVA,
   copula, multivariate GLMM). Its Levels 1-2 (marginal models with a joint
   sandwich covariance; randomization-based joint inference) are v2.0.0 and
   are the prerequisite. Release index: `release_v4_0_0.md → TODO-3`.

(`release_v4_0_0.md` also holds the shared C++ backend and language-bindings
plans, indexed under their own phases.)

---

## Standing constraints (apply to every phase)

- `R/EDI/vignettes/extending-edi.Rmd` (which replaced `extending-edi-r6.md`
  on 2026-08-23; the md is retired to `../finished_features/`) must be updated
  whenever a phase changes the external extension contract (capability
  registration, `lock_objects`, custom shells) — its chunks execute at vignette
  build, and `test-custom-extension-contract.R` pins the same promises.
  Contributor-facing mechanics go in `contracts/new_model_creation.md`, which
  references the vignette's sections instead of duplicating them.
- Every new C++ kernel follows `sexp_removal_rcppeigen_conversion_spec.md`
  conventions (`Eigen::Map` params with the response/weights `SEXP` exception,
  `EDI_CORE_ONLY` + `edi::ResultMap` if Python-bound).
- Every new inference class goes through `define_inference_class()`; every new
  design class through `define_design_class()`; no `supports_*` hooks, no
  mixin splicing, no class-name dispatch.
- Tick TODOs in their owning plan; move a plan to
  `../finished_features/` only when its checklist is fully closed or
  explicitly re-homed.
