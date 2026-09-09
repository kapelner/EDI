# Master TODO Ordering

Generated 2026-08-14. This document orders **every open TODO across every plan
in `new_feature_plans/`** into one dependency-respecting execution sequence.
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
>   multivariate, compositional, longitudinal), 5D multi-arm, 5E GPU, Phase
>   6 item 6 quantum backend, sequential-inference *implementation*, 5Y
>   (cluster-robust GLMM/GEE), 5Z (mediation), 5AA (response-adaptive
>   randomization), **the theoretical-design backlog 5P (classical
>   sequential completions), 5Q (rerandomization criteria / samplers /
>   Grundy-Healy), 5R (optimal-objective extensions), 5S (Gram-Schmidt
>   Walk / balancing walk / ARM-PSR)**, Phase 6 item 4 landscape refresh,
>   and the greedy-class *deletion*.
> The phase text below is unchanged; each release file lists its own TODO
> order.

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

**Algorithmic lane (added 2026-08-30, user decision; v1.1.0):**
`randomization_ci_affine_shift_reuse.md` → TODO-1..7, plus a decision-gated
TODO-8 (`release_v1_1_0.md → TODO-17o`). Unlike the build-level lanes above,
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
→ TODO-1..6 (v1.1.0, `→ TODO-17p`; wire the never-called
`compute_ols_distr_parallel_cpp`, delete eight other dead exports; 20–50×
on the OLS null distribution, multiplicative with TODO-17o) and
`ols_distr_kernel_fwl.md` → TODO-1..5 (v1.2.0, `release_v1_2_0.md →
TODO-9`; FWL rewrite inside that kernel, 5–10×, depends on the wiring).
Hardening item from the same audit (v1.1.0, `→ TODO-17q`):
`guard_unguarded_information_inverse.md` → TODO-1..5 — five bare
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
the boundary-runaway failure `negbin_dispersion_convergence.md` and
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
`negbin_dispersion_convergence.md` patches). Both gated on the harness.
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
- **5S. Gram-Schmidt Walk, online balancing walk, ARM/PSR** (added
  2026-08-27) → `release_v2_0_0.md → TODO-5b-iv`.
  `gram_schmidt_walk_and_online_balancing.md`. Theoretical audit #1, #21,
  #22.
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
  fold/split substrate — it is a client of the shipped
  `set_custom_randomization_statistic_function()` hook (~~and under
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
  Consortium ISC proposal (`new_research_ideas/grants/RcISC/isc_grant.qmd`,
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
  warning/column target.

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
