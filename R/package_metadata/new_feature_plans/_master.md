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
> Phase 5, and Phase 6 (including `local_machine_optimization.md` and
> `design_fixed_greedy_pair_switch_merge.md`). This supersedes
> `release_v1_0_0.md → TODO-5`'s earlier "small first wave" guess. As with
> the 1.0.0 file, it only draws the release line; this file remains the
> execution order, and its TODOs are ticked in their owning plans.
> Amended 2026-08-17: `design_seq_many_by_many.md` (the new sequential
> many-by-many design family — Phase 5F below) is written directly into the
> v1.1.0 scope (user decision; `release_v1_1_0.md → TODO-15`).
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

One sitting; every gated plan's TODO-1. Decisions cascade, so take them in
this order:

1. `expanded_estimate_report.md → TODO-1` **[spliced with]**
   `marginal_estimand_report.md → TODO-1` — one joint decision: the
   `estimate_type` design (**blocks the API shape** of every
   estimate-correction plan below) together with the orthogonal
   `set_estimand()` axis (conditional vs. marginal target quantity), scoped
   against each other so neither enum absorbs the other's values.
2. `firth_penalties_report.md → TODO-1` **[spliced with]**
   `l1_l2_penalties_all_likelihood_paths_report.md → TODO-1` — one joint
   decision; both plans share the penalized-fitting inference-semantics
   question (their Phase-2s are the same decision).
3. `median_bias_correction_likelihood_paths_report.md → TODO-1` — take
   *after* the Firth decision (the report recommends Firth first).
4. `bias_correction_cox_snell.md → TODO-1` **[spliced with]**
   `cordeiro_mccullagh_bias_correction_report.md → TODO-1` — same Easy-tier
   machinery; decide as one project.
5. `modified_profile_likelihood_report.md → TODO-1`.
6. `likrat_correction_bartlett.md → TODO-1` — whether to extend exact
   Bartlett, and the ordering across
   `score_correction_cordeiro_ferrari.md`/`gradient_correction_lemonte.md`
   (shared cumulant machinery — see Phase 5A step 3).
7. `bootstrap_calibrated_lr_report.md → TODO-2` — Difficult-tier families
   yes/no.
8. Response types, in one pass:
   `nominal_response_type_report.md → TODO-1` (+ its estimand question),
   `rank_choice_response_type_report.md → TODO-1`,
   `semi_continuous_response_type_report.md → TODO-1` (+ point-mass vs.
   censoring question), `multivariate_response_type_report.md → TODO-1`,
   `compositional_response_type_report.md → TODO-1` (+ estimand question),
   `longitudinal_repeated_measures_response_type_report.md → TODO-1`
   (+ estimand question).
9. `gpu_optimizations.md → TODO-1` and `→ TODO-7` (backend/build story).
10. `interval_censored_survival_response_type_report.md → TODO-1` —
    second-wave semiparametric (NPMLE/Turnbull, stratified-Cox icenReg
    delegation) yes/no.

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

### 1D. Inference-hierarchy migration completion (after 1A) — **26 open items remain (2026-08-17)**

Real progress since the last pass: Wald No-Likelihood Migration is down to 1
cleanup item, Quasi/Robust Estimators and Discovery are both fully `[x]`.
Remaining, by section (open-item counts):

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

### 1G. InferenceSuite run_all_inference() (after 1D)

Added 2026-08-17 (user decision), release-scoped into v1.0.0 (it adds
public API surface — `InferenceSuite$run_all_inference()` — that must freeze at
1.0.0; see `release_v1_0_0.md` amendment 13).

1. `inference_suite_inspect.md → TODO-1..9` — fit-and-compare every
   applicable inference class with one uniform output schema (identical
   across response types and iid vs. KK designs), incremental screen
   output with a %-done/ETA progress bar (SimulationFramework pattern),
   timestamped auto-opened HTML report, and two ggplot2 visualizations
   (estimate number line with angled class labels + boxplot of estimates
   underneath; annotated `(1-alpha)`-level CI forest with per-row
   p-values, CI widths, and class/method labels, significance-styled at
   the user's `alpha`) with optional timestamped PDF. Its test
   grid spans every response type × {iid, KK} × {BCRD, blocking, KK,
   greedy, D-optimal} design classes. Sequence after Phase 1D —
   `run_all_inference()` constructs and fits every applicable class, so the
   families should be migrated before its golden fixtures are cut
   (discovery itself is already metadata-driven and stable).

---

## Phase 2 — Diagnostics chain (strictly ordered)

1. `optimizer_diagnostics_report.md → TODO-1` (Phase 1: free diagnostics via
   flat `edi::ResultMap` fields; shared separation threshold; eigenvalue-cost
   decision).
2. `optimizer_diagnostics_report.md → TODO-2` (Phase 1b targeted hardening).
3. `optimizer_diagnostics_report.md → TODO-3` (Phase 2: `SolverDiagnostics`
   component) — **prerequisite for Firth in Phase 5A**.
4. **[x] DONE (2026-08-17)** `optimizer_diagnostics_report.md → TODO-4`
   (Phase 3: redefine `converged` as gradient-norm-based with an
   LBFGS-specific OR-fallback, `hit_iteration_cap` split out, every caller
   audited; a `fast_gaussian_lmm_cpp` segfault found and fixed along the
   way) — this also closes release amendment 11's decision gate. Then
   `→ TODO-5` (Phase 4, lower priority, still open).
5. `public_diagnostics_api_spec.md → TODO-1..4` (Phase 1 wrapper + result
   object), then `→ TODO-5..8` (core-path integration, after Phase 1D
   settles the families), then `→ TODO-9..12` (consumes step 1–4 output),
   then `→ TODO-13..16` (audit/report integration).
6. `public_diagnostics_api_spec.md → TODO-17, TODO-18` — the re-homed
   m-out-of-n/PRW diagnostics wiring; ticking these also closes
   `prw_subsampling_implementation_spec.md → TODO-14..17` **[spliced]**.
   `prw_subsampling_implementation_spec.md → TODO-20` (low-estimability
   summaries in the path audit) is *not* covered by those two — do it
   alongside as a small separate item.

---

## Phase 3 — Documentation (parallel with Phase 2)

1. `fix_documentation.md → remaining R-side TODOs` in batches (per the
   standing rule: parse checks only mid-batch, no interim roxygenize);
   regenerate the Rd snapshot after Phase 1D/1E before starting new batches.
2. `fix_documentation.md → TODO #758..#816` (Python docstrings) — each only
   after its R sibling's expanded documentation exists (they copy from it).
3. `fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO` — after the
   first large doc batch, and again after Phase 1D.4 (Base Deletion).

---

## Phase 4 — Independent kernel/perf lane (parallel with Phases 2–3)

No dependency on the decision batch; only on already-available SEXP
conventions.

1. **[x] DONE (2026-08-16)** `multi_arm_designs.md → TODO-6` — the
   `InferenceIncidCMH` non-blocking balance-guard gap. A live two-arm
   correctness bug; done first in this lane, as planned.
2. `robust_regression_perf_optimization_spec.md → TODO-1..4` (profile-first
   discipline per the spec).
3. `quantile_regression_cpp_kernel_spec.md → its TODO list` — kernel +
   integration for the already-migrated quantile classes; the KK-quantile
   wiring waits for Phase 1D.2.
4. `ordinal_gee_cpp_kernel_spec.md → TODO-1..2` (kernel + parity tests);
   `→ TODO-3..5` (R integration) after Phase 1D.2 settles
   `InferenceOrdinalKKGEE`.
5. `cold_starts.md → TODO-1..14` (documentation/audit of the cold-start
   policy tables).

---

## Phase 5 — Post-decision feature tracks

Each track starts only on a "yes" from Phase 0, and assumes Phase 1 is done
(shallow hierarchy is the substrate every new class/capability lands on).

### 5A. Corrections track (ordered; shared machinery flows downward)

1. `expanded_estimate_report.md → TODO-2..5` — implement `estimate_type`
   first (its values are consumed by steps 2 and 6), then
   `marginal_estimand_report.md → TODO-3..8` — the orthogonal `set_estimand()`
   switch (same get/set/supported-values/cache-key architecture; its TODO-2
   doc sharpening is decision-independent and can land any time).
2. `bias_correction_cox_snell.md → TODO-2..5` **[spliced with]**
   `cordeiro_mccullagh_bias_correction_report.md → TODO-2..4` — one project:
   shared `X'WX`/information helper, one component registration, Easy-tier
   GLMs first, one inference-policy write-up.
3. Higher-order test-correction batch, in this order (shared
   `apply_bartlett_type_polynomial_correction()` helper and GLM cumulant
   machinery built exactly once):
   1. `score_correction_cordeiro_ferrari.md → Phase 0..5` (mdscore
      reference implementation makes it the anchor),
   2. `gradient_correction_lemonte.md → Phase 0..4` (reuses score's helper;
      its own transcription-check gate),
   3. `likrat_correction_bartlett.md → exact-rollout TODO-2` (Phase-2 tier
      via the now-shared cumulant helper).
4. `firth_penalties_report.md → TODO-2..5` (requires Phase 2 step 3)
   **[spliced with]** `l1_l2_penalties_all_likelihood_paths_report.md →
   TODO-3` (the joint semantics decision is recorded once, in both plans).
5. `l1_l2_penalties_all_likelihood_paths_report.md → TODO-2` (ridge Phase 1
   families) and later `→ TODO-4` (structured models).
6. `median_bias_correction_likelihood_paths_report.md → TODO-3..4` (only
   after Firth ships and the decision holds).
7. `modified_profile_likelihood_report.md → TODO-2..4`.
8. `bootstrap_calibrated_lr_report.md → Difficult-tier work` (if Phase 0
   step 7 said yes).

### 5B. Response-type track

1. `nominal_response_type_report.md → TODO-2 (Stage 1)` **[spliced with]**
   `rank_choice_response_type_report.md → TODO-2 (Stage 1)` — literally the
   same stage; admit `nominal` once.
2. `nominal_response_type_report.md → TODO-3..4`, then
   `rank_choice_response_type_report.md → TODO-3` (conditional logit), and
   `→ TODO-4` (rankings) only under its own sub-decision.
3. `semi_continuous_response_type_report.md → TODO-2`, then `→ TODO-6` (the
   point-mass-vs-censoring modeling question — its plan requires it before
   Stage 2), then `→ TODO-3..5`.
4. `multivariate_response_type_report.md → TODO-2..4` (orchestration only;
   its TODO-5 is a standing constraint — no native joint modeling without a
   fresh decision — not a step).
5. `compositional_response_type_report.md → TODO-5` (estimand question,
   required before Stage 2), then `→ TODO-2..4` (vector storage is its own
   sub-project — schedule last among scalar-adjacent types).
6. `longitudinal_repeated_measures_response_type_report.md → TODO-5`
   (estimand question, before Stage 2), then `→ TODO-2..4` — Stage 1
   extracts the clustered-fit core from the `KKGEE` component, so it must
   follow Phase 1D.2.

### 5C. Censored-response track (after Phase 1C/1F)

1. `censored_continuous_response.md → TODO-1..` (its TODO-1 generalizes the
   Design-layer bounds schema; everything downstream keys off it).
2. `censored_count_response.md → TODO-1..` (its TODO-1 becomes a one-line
   addition once 5C.1 lands).
3. `betaregscale_duplication.md → TODO-1..` (reuses 5C.1's censored-quantile
   machinery for the proportion path).

### 5D. Multi-arm track

1. `multi_arm_designs.md → TODO-1` (Phase 1a design side — needs Phase 1E's
   capability metadata; register `supports("multi_arm")` per its updated §3c).
2. `→ TODO-2` (Phase 1b arm selection), `→ TODO-3` (Phase 2 KK simulation
   prototype), `→ TODO-4` (Phase 3a orchestration; coordinate with 5B.4's
   composite layer — same orchestration shape), `→ TODO-5` (Phase 3b native,
   demand-gated).

### 5E. GPU track (if Phase 0 step 9 said yes)

1. `gpu_optimizations.md → TODO-7` (backend/build design) then `→ TODO-2..5`
   (the three prototypes plus the GLMM reassessment, in the report's order),
   each gated by `→ TODO-6`'s benchmark matrix before merge.

### 5F. Sequential many-by-many design family (added 2026-08-17; v1.1.0)

Not Phase-0 gated (its only decisions are internal to its own TODO-1, which
can join any decision sitting); needs only the shipped 1.0.0 shallow design
hierarchy, so it may run in parallel with any other Phase 5 track.

1. `design_seq_many_by_many.md → TODO-1` (decision batch: Atkinson rule
   (a)/(b), bootstrap shape, rerandomization threshold schedule, Blocking
   carry-over queues), then
   `→ TODO-2` (the behavior-preserving shared-ingestion extraction from the
   frozen `DesignSeqOneByOne$add_one_subject()`, golden-tested first), then
   `→ TODO-3..6` (abstract + the five classes: Bernoulli, CRD, Blocking
   (TODO-4b, added 2026-08-18), Rerandomization per Zhou et al. 2018,
   Atkinson-type), then `→ TODO-7..9`
   (inference battery, discovery/`run_all_inference()` verification, docs/API
   bookkeeping), with `→ TODO-10` recording the named follow-ups only.

---

## Phase 6 — Exploratory / later

1. `sequential_inference.md` — after Phase 1E.4 delivers the public accessors
   its architecture depends on; it remains a research scoping doc until then.
2. `save_load_api.md → all TODOs` — after Phase 1E.3, when
   `EDI_DESIGN_COMPONENTS`' `owns_state` makes the serialization audit
   scriptable. Done (2026-08-17): every TODO closed (version stamp +
   accessor, one-time major-version-mismatch warning, full private-field
   serialization audit — which found and fixed a real non-serializable-XPtr
   bug in `DesignFixedOptimal`'s custom-objective path — roxygen "Saving and
   loading" section, and `test-save-load-design.R`); moved to
   `../finished_features/save_load_api.md`.
3. `interval_censored_survival_response_type_report.md → second wave` — per
   Phase 0 step 10, tracked in `interval_censored_survival_response.md`.
4. `response_types_landscape_report.md → its remaining open TODOs` — refresh
   the landscape after any 5B track ships.
5. `local_machine_optimization.md → TODO-1..12` — explicit v1.1.0 target
   (added 2026-08-17): `optimize_EDI_locally()`, a user-invoked benchmark
   tuner that recomputes the machine-dependent `globals.R` policy defaults
   (cold starts, warm starts + n-thresholds, optimizer algorithm, parallel
   crossover/core counts) on the user's own hardware, persists them to
   `tools::R_user_dir("EDI", "config")`, and has `.onLoad()` import them.
   Its TODO-2 (lifting the hardcoded sample-size-conditioned warm-start
   layer out of `edi_warm_start_dispatch_policy()` into the overridable
   config table) is valuable standalone and may be pulled earlier into a
   1.0.x. Sequence after `cold_starts.md`'s documentation audit (Phase 4
   step 5).
6. `design_fixed_greedy_pair_switch_merge.md → TODO-1..10` — explicit
   post-1.0.0 target (user instruction, 2026-08-16). Sequenced after
   `fix_design_hierarchy.md`'s Stage-2 shared-engine extraction (Follow-Ups)
   and, ideally, after `design_fixed_optimal.md`'s own implementation ships
   (reuses its TODO-1b shared validation/`P`/`H` helper rather than
   duplicating it). Deletes `DesignFixedGreedy`/`DesignFixedGreedyDOptimal`,
   replacing both with `DesignFixedGreedyPairSwitch`.

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
