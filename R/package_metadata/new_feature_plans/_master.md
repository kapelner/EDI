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
> (documentation, roxygenize R CMD check), `extending-edi-r6.md`,
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
> (`release_v1_1_0.md → TODO-15b`).
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
> documented default change).
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
kernels); runs in parallel with Phases 2–3; its parallelism sub-batch
(TODO-147/148/174/176) should be coordinated with the
`tune_EDI_for_this_machine()` axes (v1.0.0 item 15), and its bare-metal
sub-batch (TODO-143/171/175 + published 135/147/148 numbers) is one rented
`c7i.metal-48xl` session. TODOs are ticked in the owning plan.

---

## Phase 5 — Post-decision feature tracks

Each track starts only on a "yes" from Phase 0, and assumes Phase 1 is done
(shallow hierarchy is the substrate every new class/capability lands on).
**Full item lists now live in `release_v1_1_0.md`, one TODO per track —
this section only records the track → TODO mapping and any dependency not
already stated there:**

- **5A. Corrections track** → `release_v1_1_0.md → TODO-5`. Note:
  `marginal_estimand_report.md → TODO-3..8` (the `set_estimand()` switch)
  is **not** part of this track — it was pulled out into the v1.0.0 line
  (amended 2026-08-18, user decision; see `release_v1_0_0.md`'s item 14).
- **5B. Response-type track** → `release_v1_1_0.md → TODO-6`.
- **5C. Censored-response track** (after Phase 1C/1F) →
  `release_v1_1_0.md → TODO-7`.
- **5D. Multi-arm track** → `release_v1_1_0.md → TODO-8`.
- **5E. GPU track** (if Phase 0 step 9 said yes) → `release_v1_1_0.md →
  TODO-9`.
- **5F. Sequential many-by-many design family** (added 2026-08-17) →
  `release_v1_1_0.md → TODO-15`.
- **5G. KK one-stage Beta-regression estimator** (added 2026-08-18) →
  `release_v1_1_0.md → TODO-15b`.
- **5H. `dead` → `uncensored` rename** (added 2026-08-19) →
  `release_v1_1_0.md → TODO-15c`. Source TODO:
  `../finished_features/interval_censored_survival_response.md → TODO-29`.

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
   `../finished_features/save_load_api.md`.
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

---

## Standing constraints (apply to every phase)

- `extending-edi-r6.md` must be updated whenever a phase changes the external
  extension contract (capability registration, `lock_objects`, custom shells).
- Every new C++ kernel follows `sexp_removal_rcppeigen_conversion_spec.md`
  conventions (`Eigen::Map` params with the response/weights `SEXP` exception,
  `EDI_CORE_ONLY` + `edi::ResultMap` if Python-bound).
- Every new inference class goes through `define_inference_class()`; every new
  design class through `define_design_class()`; no `supports_*` hooks, no
  mixin splicing, no class-name dispatch.
- Tick TODOs in their owning plan; move a plan to
  `../finished_features/` only when its checklist is fully closed or
  explicitly re-homed.
