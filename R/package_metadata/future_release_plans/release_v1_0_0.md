# Release Scope: v1.0.0 (CRAN)

> **Depends on:** the in-scope plans listed below — this document is the
> release index that batches them, not new work of its own. (Global ordering:
> see `_master.md`; this file does not reorder anything there, it draws the
> release line across it.)

Written 2026-08-15, from a scope discussion. Decision: **v1.0.0 is defined as
"every public contract frozen"** — architecture, data schema, kernel
conventions, serialization, extension contract, and documentation. Features
that are additive on top of those contracts ship in 1.x.

## The release criterion

A plan is in scope for v1.0.0 if and only if deferring it past CRAN would
mean either (a) breaking users later to finish it, or (b) shipping known-wrong
numbers or memory-unsafe code. Everything else waits, on the guarantee that
the frozen substrate makes it additive.

## In scope

1. **[x] `fix_inference_hierarchy.md`** — the class architecture, component and
   capability model, and discovery API. Both hierarchy plans justify deleting
   legacy names with "the package is unreleased"; that argument expires at
   v1.0.0, so the migration must be complete before it. **Progress
   (2026-08-17):** `_master.md` Phase 1A (the inference-hierarchy bug batch —
   lazy-component staleness, locked-binding sweep, dead-propagation bootstrap
   bug, silent-state-wipe tests, unregistered-subclass capability detection,
   globals.R dispatch-table validation) is done, all seven items `[x]` in the
   owning plan. Still open: Phase 1D (finish migrating the remaining
   Wald/KK/IVWC/full-likelihood families, then **Base Deletion** — retiring
   the legacy mixin machinery — then Discovery/Static Cleanup/Regression
   Gates), which is the bulk of this item's remaining scope.
   **Done (2026-08-23): 0 open items, moved to `../finished_features/`.**
   The 2026-08-23 verification audit found Phase 1D's migration complete
   (every per-class item `[x]`; live manifest: zero concrete classes with
   algorithmic-compatibility ancestors; the retained legacy ladder kept on
   purpose as internal component sources; 11 thin leaves of migrated
   abstracts "pending" as the documented accepted terminal state) and four
   items still open, all closed the same day (user decision): (a) raw
   component splicing is now banned outright — the guardrail's 20-file
   frozen count table is gone, replaced by a structural invariant (no
   `InferenceMixin*`/legacy-composition/hoisted-list splices anywhere;
   `InferenceExt*` lists are single-host file-splits of the enumerated
   retained legacy ladder; a `*Source` is consumed only by the factory or
   its own file), after inlining the 11 hoisted source lists, turning the
   two `...LegacyRaw` survival KK generators into plain leaf-only sources,
   deleting the inheritor-less `InferenceCountLikelihood` generator,
   mounting the StandardModelCache bases from their canonical Source, and
   assembling the two KK compound bases through `define_inference_class()`;
   (b) component redeclaration of root-owned state is banned — the frozen
   16-component set is empty, every root-owned field moved from
   `owns_state` to `requires_state`, the KK `optimization_alg = "lbfgs"`
   default now set through the root setter in `init_kk_passthrough()`/
   `init_kk_glmm_shared()`, and `validate_inference_class_definition()`
   rejects any recurrence (Source Invariant 15 / the "every mutable field
   has one owner" Definition-of-Done bullet now met); (c) the KK IVWC
   parent item reworded to cover thin leaves of migrated KK abstracts and
   closed; (d) focused non-KK count likelihood family tests added
   (`test-count-likelihood-families-focused.R`, 874 expectations).
   Verified on the current tree without recompilation: registry (25
   tests), mixin-contracts (26), capability-tables (6), static-cleanup
   guardrails (5, now real bans), all 45 KK test files, and 32 of 36
   non-KK migration/bootstrap/suite files green; the 4 remaining failing
   files (`test-design-inference.R`, `test-design-inference-introspection-
   audit.R`, `test-simple-mean-difference-migration-golden.R`,
   `test-simple-wilcox-migration-golden.R`) fail the same way on a HEAD
   snapshot run against the same compiled `.so` (identical failing test
   names for the three quick files, the same single failure for the
   audit), i.e. pre-existing and unrelated to this closure. Roxygen
   regenerated (`fast_roxygenize.R`; no new warning classes vs. baseline).
   Item 6 (`extending-edi-r6.md`) is now unblocked on the inference side.
2. **[x] `fix_design_hierarchy.md`** — same contract-freeze argument, and its
   `owns_state` metadata is the prerequisite for the serialization audit
   (item 5). **Done (2026-08-17): 0 open TODOs, moved to
   `../finished_features/`.** Unblocked item 5 (`save_load_api.md`), which is
   also now done — see item 5.
3. **[x] `interval_censored_survival_response.md`** — the y/y_L/y_R response
   schema is a data-contract change touching every design and inference
   class; it must finish before the contract freezes. It also gates the
   `edi_kernels` Python 1.0.0 wheel (see Coordination). **Done (2026-08-16):
   all TODOs closed, plan moved to `../finished_features/`.** The
   Python-release gate in Coordination below is lifted.
4. **[x] `sexp_removal_rcppeigen_conversion_spec.md`** — the C++ kernel
   conventions, and the memory-safety batch (heap corruption in
   `fast_truncated_negbin_count_cpp`, `fast_poisson_glmm_cpp` group-size
   validation, the comprehensive-suite `status="ok"` false positive). CRAN's
   sanitizer machines (ASAN/valgrind) will find memory bugs we ship.
   **Done (2026-08-16): all TODOs closed, plan moved to
   `../finished_features/`.** The `fast_truncated_negbin_count_cpp` heap
   corruption specifically is owned by `bootstrap_calibrated_lr_report.md →
   TODO-1`, a separate plan — also **done (2026-08-16)**: root cause was the
   unvalidated `get_hurdle_negbin_count_score_cpp`/`_hessian_cpp` getters,
   fixed with the same dimension guards as this plan's TODO-16.
5. **[x] `save_load_api.md`** — the serialization contract. EDI's core use
   case is sequential experiments running over weeks; a user must be able to
   save a mid-experiment design under 1.0.0 and load it under 1.2.0. That
   guarantee has to exist at 1.0, and cannot be bolted on later without a
   migration story. Depends on item 2's `owns_state`. **Done (2026-08-17):
   all TODOs closed (version stamp/accessor, one-time major-version-mismatch
   warning, full private-field serialization audit — which found and fixed a
   real non-serializable-XPtr bug in `DesignFixedOptimal`'s custom-objective
   path — roxygen "Saving and loading" section, `test-save-load-design.R`),
   moved to `../finished_features/`.**
6. **[x] `extending-edi-r6.md`** — the external extension contract; it freezes
   when the hierarchy plans do, per the standing constraint in `_master.md`.
   **Done (2026-08-23):** rewritten against the finished shallow-hierarchy
   architecture (both hierarchy plans closed): documents how package classes
   are now factory-built (`define_inference_class()`/`define_design_class()`,
   components, capability metadata, registry-only discovery), keeps the
   three inference shells and two design shells as the sole supported
   extension surface, states the updated subclassing rules
   (`lock_objects = FALSE`; `capabilities()` resolves through the nearest
   registered ancestor; external classes are never discovered; no ladder
   inheritance, no list splicing, no root-owned state), adds a custom-design
   example, and points in-package authors to
   `contracts/new_model_creation.md` (itself refreshed the same day for the
   completed migration and documentation standard). Both code examples
   verified to run on the current tree. **Later the same day:** the external
   contract moved into the package as `vignettes/extending-edi.Rmd`
   (`vignette("extending-edi")`, pkgdown "Package Concepts" article,
   executable examples, test-rendered clean), `extending-edi-r6.md` retired
   to `../finished_features/` with a superseded banner,
   `contracts/new_model_creation.md` de-duplicated to reference the
   vignette's sections, `_master.md`'s standing constraint repointed at the
   vignette, and `test-custom-extension-contract.R` extended (7 tests, 71
   expectations) to pin the capability-resolution/discovery/lock rules the
   vignette states.
7. **[x] `fix_documentation.md`** — CRAN requires complete documentation, and
   the master ordering already sequences doc batches after the hierarchies
   settle (regenerate the Rd snapshot after Phases 1D/1E first). **Done
   (2026-08-23): 0 open R-side TODOs (all 821 closed across the whole
   Inference* class family, tracking `fix_inference_hierarchy.md`'s
   migration as each class became ungated), moved to
   `../finished_features/`.** **The Python-docstring TODOs (#758-#816) are
   also done (2026-08-23):** verified against the real
   `python/cpp/bindings_*.cpp` pybind11 docstrings, not just the
   checkboxes — all 59 are genuinely expanded. One stale function name
   found and fixed (TODO #803 named a nonexistent `fast_weibull_regression`;
   the real binding, `fast_weibull_regression_general`, already had a full
   docstring). Item 7 is now **fully closed**, no open remainder.

### Amendments (added to the seven-plan batch)

8. **[x] `multi_arm_designs.md → TODO-6`** — the `InferenceIncidCMH`
   non-blocking balance-guard gap. `_master.md` calls it "a live two-arm
   correctness bug"; known-wrong numbers do not ship in 1.0.0. Only TODO-6 is
   pulled in; the rest of the multi-arm plan stays deferred. **Done
   (2026-08-16):** construction-time `prob_T == 0.5` guard added to the
   non-blocking branch (mirroring the blocking branch), plus a `warning()`
   for realized-allocation imbalance even at `prob_T = 0.5`. See
   `multi_arm_designs.md`'s TODO-6 for the full writeup.
9. **[x] `fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO`** — a
   clean `R CMD check --as-cran` is the literal gate to CRAN; it runs inside
   the release batch (after the first large doc batch, and again after Base
   Deletion), not adjacent to it. **Done (2026-08-23):** ran a full local
   `R CMD build` + `R CMD check --as-cran --no-manual` from a clean copy of
   the working tree (see the plan's own writeup for the `.claude`
   device-file build gotcha and full breakdown). Confirms the srcref fix
   holds under the real checker. Result: 1 ERROR (environmental —
   `tune_EDI_for_this_machine()`'s `\donttest{}` example correctly refused
   to run under the check run's own CPU contention; re-run idle), 11
   WARNINGs/4 NOTEs, most already tracked below. **Not yet "clean"** — see
   the plan's writeup for a new finding this run surfaced: 18 `.Rd` files
   (up from the "2 missing links" baseline below) now have missing/dead
   `\link[EDI:...]{}` cross-references, plus 7 `Inference*IVWC`/`OneLik`
   component-source classes reported as fully undocumented — looks like
   `fix_inference_hierarchy.md`'s KK/IVWC migration fallout, not this
   plan's doing, but it's real and CRAN-blocking (`error-on: "note"` in
   CI). Needs its own cleanup pass before this checklist can be marked
   clean; moved to `../finished_features/` since this plan's own scope
   (the srcref fix + verifying it under a real check) is done — the
   cross-reference cleanup is tracked as a new TODO-16 below instead.
10. **CRAN submission mechanics** (owned by this file; no other plan covers
    them) — see the Release Gate checklist below.
12. **[x] `design_fixed_optimal.md`** (added 2026-08-16, user decision) — the
    new `DesignFixedOptimal` class: a deterministic single-allocation optimal
    design (all `DesignFixedGreedyDOptimal` objectives + `DesignFixedGreedy`'s
    balance objectives + a compiled-C++ `custom_objective` XPtr, optimized via
    ompr MILP where exact and best-of-restarts otherwise; no randomization
    distribution, so randomization inference is fenced via the same
    capability metadata as `ObservationalDesign`). Release-relevant because it
    adds a public class, a new `randomization_family` enum value
    (`"deterministic_optimal"`), and a public XPtr calling convention — all
    API surface that must freeze at 1.0.0. **Done (2026-08-17):** every TODO
    (1, 1b, 2–4, 5, 5b, 6–9, 8b, 10, 11) closed, plus the follow-on TODO-A1
    (threading commercial-solver choice through the existing
    `DesignFixedOptimalBlocks$new()` too). Class + registry wiring + roxygen
    landed (`R/design_fixed_optimal.R`, `EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES`),
    with a fencing audit confirming the inference side needed zero changes
    (the Observational-design migration already made every rand/BRT call
    site capability-driven). Full test coverage
    (`test-design-fixed-optimal.R`, `test-design-fixed-optimal-brt.R`, 19
    BRT assertions alone) passing. One real bug found and fixed as a
    byproduct: the BRT reusable-worker impute path broke on a plain
    data.frame `Xraw` (data.table `..` syntax), fixed via
    `as.data.table(private$Xraw)`. Moved to
    `../finished_features/design_fixed_optimal.md` (2026-08-17).
11. **[x] `optimizer_diagnostics_report.md → TODO-4` decision** — redefining
    `converged` changes the meaning of a user-visible field, which after
    1.0.0 would be a quiet breaking change. Either do that one item pre-1.0
    or explicitly record that the current semantics are the stable ones
    (TODO-2 below). The rest of the diagnostics chain stays deferred either
    way. **Done (2026-08-17): implemented, not just recorded-as-stable.**
    See Implementation TODO-2 below for the full writeup.

13. **[x] `inference_suite_inspect.md`** (real file: `inference_suite_plan.md`
    — added 2026-08-17, user decision) —
    `InferenceSuite$run_all_inference()`: constructs and fits every applicable
    inference class and reports one uniform comparison schema (identical
    across response types and iid vs. KK/matched-pair designs), with
    incremental screen output + %-done/ETA progress bar
    (SimulationFramework pattern), a timestamped auto-opened HTML report,
    and two ggplot2 visualizations (estimate number line with angled
    class labels and a boxplot of estimates underneath; annotated
    `(1-alpha)`-level CI forest with per-row p-values, CI widths, and
    class/method labels, significance-styled at `alpha`) with an
    optional timestamped PDF. Release-relevant because it adds public API
    surface (`run_all_inference()`, its schema and `EDIInferenceSuiteResults`
    return object, its `screen`/`html`/`plots`/`pdf`/`alpha`/
    `save_results_as_JSON` parameters) that must freeze at 1.0.0.
    Implementation may proceed in parallel with the tail of Phase 1D;
    only its test-fixture lock waits for Phase 1D to close (amended
    2026-08-18, user decision) — see `_master.md` § 1G. **Done
    (2026-08-24):** Phase 1D closed 2026-08-23, unblocking `TODO-9`'s
    "full grid" test-fixture lock — the plan's own status note (claiming
    only 2 response types covered) was stale; the real gap was the
    design-class axis (only `continuous`/`incidence` had more than
    `{Bernoulli, KK14}` coverage). Added a `DesignFixedBlocking` (iid,
    non-KK) test for each of count/proportion/survival/ordinal, verified
    the entire test file (`test-inference-suite-run-all-inference.R`) runs
    clean end-to-end (three `testthat` batches, 198/341/307 successes,
    zero failures). See `inference_suite_plan.md → TODO-9` for the full
    writeup. **Plan fully closed, moved to `../finished_features/`
    (2026-08-25):** 0 remaining open TODOs.

14. **[x] `marginal_estimand_report.md`** (added 2026-08-18, user decision —
    pulled forward from the "Deferred to 1.x" list below; narrowed
    2026-08-18 to just this plan — see amendment below). The
    `set_estimand()` axis: conditional (current behavior) vs. marginal
    (unconditional-mean) target quantity for the mixture-model families
    (ZOIB, zero-augmented/hurdle Poisson). Release-relevant because
    `inference_suite_inspect.md`'s Combined Evidence Metric feature
    (TODO-14..21 there) keys its default weighting policy off each
    class's `estimand` tag — shipping that default at 1.0.0 without a
    real, package-wide `estimand` concept behind it would freeze a
    public-facing weighting default onto metadata that barely exists yet
    (today only the incidence g-computation classes implement
    `get_estimand_type()`). **TODO-1 decided (2026-08-18, user decision):
    yes, pursue `set_estimand()`.** **Done (2026-08-18):**
    `marginal_estimand_report.md → TODO-2`'s roxygen sharpening (folded
    into the doc batch, item 7, regardless of this move) — see that
    plan's own TODO-2 for the full writeup, including a scope correction
    found while doing it (the caveat needed to reach four concrete
    exported classes, not just the internal abstract base named in the
    original TODO text). Also done (2026-08-18): TODO-3 (`set_estimand()`
    implemented as a new `MarginalEstimand` `InferenceComponent`,
    composed by zero production classes so far — pure architecture),
    TODO-6 (estimand-aware `get_supported_testing_types()`, both setter
    directions loud-error regardless of order), TODO-8 (the
    `compute_estimate()` dispatch question resolved as part of TODO-3).
    TODO-7 was reclassified as a consequence of TODO-4/5/9, not
    independent work (randomization/bootstrap paths inherit estimand-
    awareness automatically from an estimand-aware `compute_estimate()`).
    **Done (2026-08-24): TODO-4 (ZOIB), TODO-5 (ZIP/hurdle Poisson), and
    TODO-9 (logistic/Poisson/beta-regression/identity-binomial) all
    closed** once `fix_inference_hierarchy.md`'s Full-Likelihood
    Estimators remainder closed (2026-08-23) unblocked them. Real bugs
    found and fixed along the way (see `marginal_estimand_report.md` for
    full writeups per TODO): CI/pval paths bypassing the estimand-aware
    `compute_estimate()`; a cache-invalidation bug returning stale
    marginal numbers after toggling back to `"conditional"`; a stale
    registry table silently breaking `self$supports("marginal_estimand")`;
    a truncated-NegBin mean-formula risk correctly identified and left
    out of scope (NegBin variants deliberately not wired — Poisson-
    specific derivations); a Fisher-information-matrix dimension bug in
    the beta-regression wiring (caught safely by a dimension guard, no
    wrong number shipped); and two families (`InferenceCountPoisson`'s
    `marginal_ratio`, `InferenceIncidBinomialIdentityRiskDiff`'s
    `marginal_mean_diff`) confirmed to numerically collapse to their
    conditional estimate for structural reasons (log-link/identity-link
    with no treatment interaction), documented explicitly rather than
    left as a silent surprise. All in `_master.md`'s Phase 0/Phase 5A
    step 1. **Plan fully closed, moved to `../finished_features/`
    (2026-08-25):** 0 remaining open TODOs.
    **Amendment (2026-08-18, user decision):** `expanded_estimate_report.md`
    — the orthogonal `estimate_type` axis, originally pulled into this
    item alongside `marginal_estimand_report.md` for a joint decision —
    is moved back to v1.1.0 (see the "Deferred to 1.x" list below).
    Nothing currently in v1.0.0 scope needs it: the Combined Evidence
    Metric that motivated this whole item only reads `estimand`, never
    `estimate_type`, and `estimate_type`'s own stated urgency (unblocking
    the Cox-Snell/Cordeiro-McCullagh/median-bias correction plans' API
    shape) is itself v1.1.0-scoped. The two plans' TODO-1 decisions no
    longer have to land in the same sitting — whichever is decided second
    should just check the first plan's chosen values so the two enums
    don't collide, per each plan's own `Depends on` header.

15. **[x] `local_machine_optimization.md`** (added 2026-08-20, user decision —
    moved from the v1.1.0 line; was `release_v1_1_0.md → TODO-10` and part
    of its `TODO-1` step 11). `tune_EDI_for_this_machine()`: a user-invoked
    benchmark tuner that measures the current machine and overrides the
    machine-dependent performance-policy defaults hardcoded in
    `EDI/R/globals.R` (warm-start thresholds, core count, etc.) with a
    persisted, machine-specific config. **TODO-2 (the warm-start dispatcher
    refactor lifting the hardcoded n-conditioned layer into an overridable
    config table) done (2026-08-21):** see `local_machine_optimization.md`'s
    own TODO-2 for the full writeup, including the golden-equivalence test
    (4,875 combinations, zero mismatches) and the `set_warm_start_dispatch_policy()`
    `modifyList()`-on-unnamed-lists bug it caught and fixed along the way.
    **TODO-1 (the remaining decision-gate
    parts a, b, c, e — part (d) was decided 2026-08-17: tuned core count is
    recorded-only) done (2026-08-21, user decision):** name
    `tune_EDI_for_this_machine()`; storage via
    `tools::R_user_dir("EDI", "config")` + `.rds`; store-only-deviations
    persistence merged via existing setters; Python twin deferred to a
    later release. TODO-3..12 (harness, per-axis tuners, persistence, safety
    blocklist, contention guard, correctness gate, `.onLoad()` import,
    tests, docs) are now unblocked and in scope for this release.
    **TODO-3 (the benchmark harness) done (2026-08-21):** see
    `local_machine_optimization.md`'s own TODO-3 for the full writeup —
    registry-driven family enumeration, interleaved A/B timing, the
    noise-margin acceptance rule, and effort presets, plus moving the
    synthetic-data generator out of test-only helpers into shipped package
    code (`R/EDI/R/local_machine_tuning_synthetic_fixtures.R`) so both the tuner and the
    migration golden tests share one recipe. **TODO-4 (the four per-axis
    tuners) done (2026-08-21):** cold start, warm start (per-operation,
    with the n-conditioned layer reachable), optimizer algorithm (with the
    all-replicates-converge guard), and parallel crossover-n (blocked, not
    interleaved, timing — a fork cluster's setup cost rules out
    per-replicate interleaving), all in `R/EDI/R/local_machine_tuning_axes.R`,
    136 test assertions across two test files. Three scope boundaries are
    recorded honestly in that plan's TODO-4 writeup rather than papered
    over: the optimizer axis's convergence oracle is a required injected
    argument (no generic "did this fit converge" accessor exists yet —
    that's the diagnostics chain, `_master.md` Phase 2); best-default-core-
    count is a straightforward sweep deferred to TODO-5's assembly; and
    fork-vs-mirai preference is out of scope for v1.0.0 (the two backends
    can't be A/B'd in one R session by construction). **Also added to this
    plan's Architecture section (2026-08-21, user instruction):**
    `tune_EDI_for_this_machine()` must show the same rolling-update screen
    progress bar as `InferenceSuite$run_all_inference()` (reuse
    `run_all_inference_progress_bar_line()`/`run_all_inference_fmt_secs()`,
    not a reimplementation) — an ETA-bearing bar redrawn in place per
    benchmark cell; lands in TODO-5. **TODO-5 and TODO-6 done
    (2026-08-21):** `tune_EDI_for_this_machine()`,
    `clear_local_EDI_optimization()`, `get_local_EDI_optimization()` are
    implemented and exported (NAMESPACE regenerated by the user's own
    roxygenize from the `@export` tags); per-user `.rds` persistence with a
    hardware fingerprint; setter-shaped diffs with a **merge-aware** apply
    (the `set_*` setters `modifyList` over atomic override vectors, which
    replaces them wholesale — a naive one-class diff would wipe the other
    shipped overrides); the InferenceSuite progress bar reused via a
    backward-compatible `label` arg; and TODO-6's hard gate refusing any
    diff touching the bootstrap-CI-type policy or the parallel-safety
    blocklist. **TODO-9 also done (2026-08-21):** the `.onLoad()` import
    (`edi_tuning_import_saved_policies()`, called from `zzz.R` after the
    single-threaded-by-default thread pin) — fail-open by construction
    (no file: silent; unreadable/incompatible/unapplicable: ignored, every
    policy reset to shipped so no part-applied state survives, one
    `packageStartupMessage`; hardware changed: applied + suggest re-run;
    `EDI_SKIP_LOCAL_TUNING=1` disables it), never errors at load, never
    touches the active core count. **TODO-7 also done (2026-08-21):** the
    contention guard — 1-minute load average vs. cores, plus dispersion of
    a self-contained calibration timing (machine-relative by design, not
    a stored absolute reference) — refuses to benchmark a busy machine
    unless `force = TRUE` (interactive `[y/N]` prompt otherwise); it fired
    for real on the dev box during development. A side finding while
    verifying TODO-5: the bar `label` argument initially measured its
    label column from the already-rendered string, widening it by 4 and
    narrowing the bar for InferenceSuite too — caught by the new unit pin
    (the full InferenceSuite suite was too heavy for its timeout and has
    no bar-text assertions anyway) and fixed. **TODO-8 also done
    (2026-08-21):** the correctness gate — every accepted deviation is
    re-fit once under both settings on identical synthetic data before it
    can displace a shipped default (point estimates for cold
    start/optimizer/parallel; the resampling operation's own RNG-matched
    output for warm start, since a parallel axis's forked-worker CI is
    *expected* to differ and comparing it would manufacture false
    disagreements); disagreement or an unverifiable comparison discards
    the deviation with a `warning()`. Two small refactors improved shared
    infrastructure rather than adding parallel logic: one seed formula
    (`edi_tuning_default_seed()`) now backs every axis's timing *and* the
    gate's re-fit, replacing three independent copies; and
    `edi_tuning_warm_start_run_setting()` was fixed to return its
    resampling result instead of discarding it, which the timing
    harness's already-existing result capture and the gate both need.
    35 new tests, including each `verify_*` function confirmed reachable
    (`agree = TRUE`) against a real fit, not just defined in theory. Final
    tally: correctness 35, assembly 137, harness 68, axes 68, refactor 4
    — all green. **TODO-10 also done (2026-08-22):** closed the two test
    items not already covered as a byproduct of TODO-6/7/9 — (a) one
    explicit round-trip chaining a mocked-benchmark tuning run → simulated
    fresh-session policy reset → `.onLoad()` import, confirmed via the
    live dispatcher; (d) a saved diff naming a class pattern matching no
    live class applies cleanly and is confirmed inert, while a real
    co-occurring entry in the same diff still takes effect — and added a
    real (non-mocked), `skip_on_cran()`-guarded end-to-end run of
    `tune_EDI_for_this_machine()` itself. Assembly now 155/155; full local
    machine-tuning suite 326/326 across all four test files. The
    `.onLoad()` import hook
    itself goes live in `library(EDI)` on the user's *next* install (their
    current one predates the `zzz.R` edit — verified via `load_all()`
    meanwhile). Two recorded boundaries: the
    parallel diff is recorded-only (there is no runtime per-family
    crossover-threshold table yet to apply it to), and the optimizer axis
    still needs a caller-supplied `converged_fn`. Remaining sequencing note:
    `cold_starts.md → TODO-4` (the missing ZINB heuristic-table row), the
    remaining item named in this plan's own `Depends on` header, is
    **done (2026-08-21)**. Additive — a new opt-in
    function and a new load-time override path, no change to any frozen
    public contract — so it does not gate the freeze itself, but ships in
    the same batch per the user's explicit instruction. Benefits from
    landing late in the batch so the tuner benchmarks the release-candidate
    kernels rather than mid-release ones. **TODO-11 done (2026-08-23):**
    roxygen cross-linked both ways between `tune_EDI_for_this_machine()`
    and the four *tunable* `get_*`/`set_*_dispatch_policy()` pairs
    (cold start, warm start, optimizer); the parallel pair's cross-link was
    deliberately worded differently — that table is TODO-6's correctness
    blocklist, not a performance one, so its docs say the tuner benchmarks
    a related-but-separate question (crossover n/core count) and will
    never propose un-serializing anything named there. A new
    "Machine-dependent performance defaults" section was added to
    `vignettes/reproducibility.Rmd` (no dedicated performance vignette
    existed), framed on that vignette's own theme — tuning changes speed,
    never which draws are made or which estimate a fit produces, per the
    TODO-8 correctness gate. `cold_starts.md`'s conclusion now points a
    "these numbers look wrong on my machine" report at the tuner rather
    than at the document. **TODO-12 closed as superseded, and the plan is
    fully done (2026-08-23):** all twelve TODOs are `[x]`; TODO-4's two
    once-open scope boundaries are resolved (best-default-core-count, done
    in TODO-5) or permanently out of scope by construction (fork-vs-mirai
    A/B, and the optimizer axis's `converged_fn` requirement, both recorded
    as such rather than left as unfinished work). Moved to
    `../finished_features/local_machine_optimization.md`.

16. **[x] `parallel_fork_cluster_test_safety.md`** (added 2026-08-21, user
    decision). `InferenceSuite$run_all_inference(num_cores > 1)` — item 13's
    frozen public API — deadlocks via `parallel::makeForkCluster()` when
    forked after the process has run OpenMP-parallel kernels (root-caused
    2026-08-21 from a CI incident: every `R-CMD-check` matrix leg hung until
    its own job timeout). Release-relevant because `num_cores` is a
    documented parameter of a public contract freezing at 1.0.0 — shipping
    it with a known indefinite-hang path is exactly the "known-wrong/unsafe
    code" case the release criterion above excludes from deferral; fixing it
    post-1.0.0 without breaking anyone requires the fix to be purely
    internal (no signature change), so it's safe to sequence after other
    freeze-critical items but must close before submission. TODO-1/2
    (splitting parallel-aggregation correctness testing from real-fork risk,
    plus a test-level wall-clock safety net) are cheap and testing-only.
    TODO-4/5 (the actual library-side fix — candidate lead: `run_all_
    inference()` bypasses the package's own `make_configured_fork_cluster()`
    safety helper) touch `inference_suite.R`'s parallel-worker code directly
    and need their own careful review. TODO-3/6 are follow-on scoping
    decisions once TODO-1/2/4/5 land. See that plan's own TODOs for the
    full writeup. **Done (2026-08-26):** all 6 TODOs closed. TODO-5's
    `run_all_inference_fork_dispatch()` rewrite (per-task `mcparallel()` +
    polling `mccollect()` + PID-based force-kill on a
    `max_secs_per_class` timeout) replaced the shared-cluster approach at
    this call site entirely, superseding TODO-4's original fix in
    practice. Confirmed via GitHub Actions run 32907016076: `R-devel
    (ASAN/UBSAN)` and `R-devel (valgrind)` both pass `checking tests`
    cleanly (154s and 27min respectively) with the real fork-cluster test
    included and `skip_on_ci()` permanently removed (TODO-3, decision b) —
    the first clean pass on either leg since the 2026-08-21 incident.

## Deferred to 1.x (additive by construction)

Everything below attaches to the frozen substrate without breaking it —
that is the point of freezing first:

- **Phase 0 decision batch + Phase 5A corrections track** (minus
  `marginal_estimand_report.md`, pulled forward into item 14 above, added
  2026-08-18): `expanded_estimate_report.md` (`estimate_type` — moved back
  here 2026-08-18, see item 14's amendment), Cox-Snell / Cordeiro-McCullagh /
  median-bias corrections, Firth, L1/L2, Bartlett extensions, modified
  profile likelihood, bootstrap-calibrated LR. All are new switches/methods
  whose defaults preserve 1.0.0 behavior.
- **Phase 2 diagnostics chain** (except the `converged` decision, item 11):
  new diagnostics fields and the public diagnostics API are additive.
- **Phase 4 kernel/perf lane** (except `multi_arm_designs.md → TODO-6`,
  item 8): quantile/ordinal kernels, robust-regression perf, cold-start
  audits — internal speedups and new kernels behind existing APIs.
- **Phase 5B/5C/5D/5E**: new response types, censored count/continuous,
  multi-arm designs proper, GPU.
- **Phase 6**: `sequential_inference.md` (research scoping).
- **`design_fixed_greedy_pair_switch_merge.md`** (added 2026-08-16, explicit
  user instruction: post-1.0.0 target). Merges `DesignFixedGreedy` into
  `DesignFixedGreedyDOptimal` as `DesignFixedGreedyPairSwitch` by releasing
  `DesignFixedGreedy`'s `prob_T = 0.5` constraint — requires rederiving the
  kernel's swap-delta math (worked out in that plan, not yet implemented) and
  deletes both prior classes. Sequenced after `fix_design_hierarchy.md`'s
  Stage-2 shared-engine extraction and, ideally, after `design_fixed_optimal.md`
  ships (reuses its shared validation/`P`/`H` helper, TODO-1b there). Public
  API surface changes twice removed from 1.0.0 (`design_fixed_optimal.md`
  itself is also 1.0.0-scoped per item 12 above; this plan is scoped after
  that), so explicitly not part of the freeze.

## Coordination

Generic release/submission mechanics (tagging, pushing, submitting,
CHANGELOG, Python coordination) now live in `release.md` and apply
unchanged. 1.0.0-specific note: the interval-censoring rework
`edi_kernels` 1.0.0 waited on (item 3) is done (2026-08-16), so it no
longer blocks the Python side by itself.

## Release Gate — CRAN mechanics checklist

> **The generic parts of this checklist now live in `release.md`** (CI
> coverage inventory, win-builder/mac-builder submission via
> `R/EDI/scripts/submission_tar_build_and_win_mac_check.sh`, check-profile measurement,
> `cran-comments.md`/CHANGELOG/version-bump/tagging steps, post-acceptance
> plan moves) — that file applies to every release, not just 1.0.0. What
> remains here is the 1.0.0-specific work: the CRAN-incoming CI job and
> Windows-devel matrix leg were *added* as part of closing out this release
> (recorded once, in `release.md`, not duplicated here), and the still-open
> Windows `\donttest{}` hang investigation below is a real bug found during
> this release's own check runs, not generic release process.

- [x] **CRAN-incoming checks / platform CI coverage.** Done (2026-08-25) —
  added the `R-CMD-check-incoming` CI job and the Windows-devel matrix leg;
  see `release.md`'s "CI coverage already enforced on every push" for what
  they cover. Actually submitting to win-builder/mac-builder is a per-release
  step, not a per-release-development one — see `release.md`'s pre-submission
  checklist item 1 when cutting the submission-candidate tarball.
- [x] **Fix the Windows `\donttest{}` hang.** CI set
  `_R_CHECK_DONTTEST_EXAMPLES_=false` on windows-latest specifically because
  a 2026-08-09 run hung 5.5+ hours in "checking examples with
  --run-donttest" with no isolatable culprit. CRAN's Windows machine will
  not skip that pass — as it stands the package fails on CRAN-Windows in a
  way CI is engineered not to reproduce. Diagnose the hang or restructure
  the offending examples; win-builder (previous item) is the verification
  vehicle.
  **In progress (2026-08-17):** static audit of every `\donttest{}` block (83
  blocks, 68 files) found no blocking call (`system()`, `Sys.sleep`,
  `readline`, sockets, `download.file`, `parallel::mclapply`/cluster) and no
  example on the known-hanging GLPK/`ompr` MILP path (that one's already
  fenced via `skip_on_os("windows")` in `test-fixed-design-optimal-blocks.R`,
  a `testthat` test, not a roxygen example) — consistent with the original
  "no isolatable culprit" finding. Leading remaining hypothesis: MinGW's
  OpenMP/pthread implementation interacting badly with R's single-threaded
  example harness (the package's kernels are pervasively OpenMP-parallel).
  Deployed as a targeted experiment in `R-CMD-check.yaml`
  (2026-08-17): re-enabled the Windows donttest pass with `OMP_NUM_THREADS=1`
  pinned Windows-only, capped by the job's `timeout-minutes` (90 at the time
  this was written; raised to 150 on 2026-08-19 for an unrelated reason —
  the comment inside `R-CMD-check.yaml` claiming "90-minute" is stale and
  needs updating to 150).

  **Checked against real CI runs (2026-08-24, runs 32704188187 and
  32731525153) — still not resolved, and worse than assumed:**
  - **Windows still doesn't finish.** In both runs the windows-latest job
    ran silently from `* checking files in 'vignettes' ... OK` all the way
    to the job's 150-minute timeout with zero further output, then printed
    `* checking examples ...` / `Execution halted` only because the cancel
    signal flushed the buffer — i.e. it was still inside (or just entering)
    the examples/donttest pass when killed, not stuck in a step that logged
    anything. `OMP_NUM_THREADS=1` has not been shown to fix the original
    hang; it's simply now bounded at 150 minutes instead of running to
    GitHub's 6h hard kill (still far past the original "worst case ~90
    minutes" assumption above, which itself is stale since the timeout is
    150 now).
  - **New discovery: the donttest pass is not "fast and clean" on the
    other legs either**, contrary to the `R-CMD-check.yaml` env-block
    comment ("macOS: ~32s, all 3 Ubuntu configs: ~67-68s"). On
    `ubuntu-latest (release)` in both runs, `checking examples with
    --run-donttest` took 20–26 minutes and ended in `ERROR`:
    `tune_EDI_for_this_machine`'s own `\donttest{}` example
    (`res = tune_EDI_for_this_machine(effort = "quick", dry_run = TRUE,
    force = TRUE)`) spends ~1026s benchmarking one `InferenceSuite` cell of
    its 828-cell grid, then crashes with `Error in
    private$init_kk_passthrough(des_obj) : InferenceIncidKKGCompRiskDiff
    requires a KK matching-on-the-fly design (DesignSeqOneByOneKK14) or
    DesignFixedBinaryMatch` — the internal benchmark harness is pairing
    `InferenceIncidKKGCompRiskDiff` with an incompatible design in its
    generated grid. This is a pre-existing bug (present in both the
    2026-08-24 08:01 and 13:14 runs, unrelated to `OMP_NUM_THREADS`), not
    something the Windows-only OMP change touches.
  - **Implication:** the Windows-specific hang cannot be properly
    re-verified until `tune_EDI_for_this_machine`'s benchmark-grid bug is
    fixed — right now every leg's donttest pass is dominated by that one
    example (slow even where it doesn't crash), which likely also explains
    why Windows never even reaches a pass/fail verdict within 150 minutes:
    it's plausibly stuck in the same benchmark grid, serialized further by
    `OMP_NUM_THREADS=1`, either hitting the same crash eventually or
    running long enough to hit the timeout first.

  **Follow-up (2026-08-24, same day): the `InferenceIncidKKGCompRiskDiff`
  crash was already independently fixed** by commit `9a91ce91` ("slow
  paths now a constant, fixed some more bugs in testing", 2026-08-24
  17:44 UTC+3) — landed *after* the two runs analyzed above, so neither
  reflected it. The fix added a
  `!infer_inference_requires_kk_matching_design(name)` filter to
  `edi_tuning_live_families()` in `local_machine_tuning_harness.R`,
  excluding any concrete class that needs a KK-matching design from the
  benchmark grid (that function's own docstring already names this exact
  CI failure as the confirmed cause). The next push (`916f6b9c`, run
  `32773046195`, started 2026-08-24 20:17 UTC) includes this fix and
  gives real signal:
  - **Windows genuinely progressed for the first time.** `checking
    examples ... [63s] OK` (no more silent stall), then `checking
    examples with --run-donttest ... [38m] ERROR` — a real 38-minute run
    ending in an actual R error, not an indefinite hang. This is the
    first evidence `OMP_NUM_THREADS=1` is doing what it was meant to:
    Windows now reaches a verdict instead of running forever.
  - **But a second, different bug in the same example blocked it**: at
    cell 144/338, `Error: min_number_usable_samples must be less than or
    equal to B for compute_bootstrap_confidence_interval, but
    min_number_usable_samples = 10 and B = 9.` Root cause:
    `EDI_TUNING_WARM_START_OPERATION_CALLS$non_param_boot`
    (`local_machine_tuning_axes.R`) hardcodes `B = 9L` for every class's
    `compute_bootstrap_confidence_interval` benchmark call, but
    `InferenceSurvivalDepCensTransform`'s override of that method
    defaults `min_number_usable_samples = 10` (every other concrete
    class defaults to `5L`, which is `<= 9`) — `assertBootstrapArgs()`
    then rejects the combination. **Fixed** in
    `local_machine_tuning_axes.R`: pinned `min_number_usable_samples =
    5L` explicitly in that call's `args`, overriding every class's own
    default so the benchmark-speed call can't trip this again regardless
    of what an individual class defaults to.
  - **Separately, `checking tests ...` (the full testthat suite) ran
    from 21:36 to the 22:47 cancellation (~71 min) without finishing** —
    consistent with the pre-existing "legitimately slow, not a hang"
    finding from the 2026-08-19 timeout raise, not a new issue, but worth
    noting it's now the long pole once the donttest pass itself is fast.
  - **Confirmed resolved (2026-08-28), CI run 33121847188 (2026-08-27
    22:16 UTC), a fully green run across all 10 matrix legs:**
    `windows-latest (release)` job 98690365560: `checking examples ...
    [47s] OK` then `checking examples with --run-donttest ... [341s] OK`.
    `windows-latest (devel)` job 98690365588: the same pattern, `[47s] OK`
    then `[338s] OK`. Both legs reach a clean pass in ~6 minutes each, no
    stall, no error — the `OMP_NUM_THREADS=1` fix plus the
    `min_number_usable_samples` fix together resolve the original
    5.5-hour hang. Item closed; no further action needed.
- [x] **Measure and gate the CRAN-facing check profile.** Measured
  2026-08-15 (`NOT_CRAN=false R CMD check --as-cran` on the mid-migration
  tree; `Status: 2 ERRORs, 1 WARNING, 6 NOTEs`). Findings:
  - **Tests: CRAN runs zero of them.** `tests/testthat.R` wraps the whole
    suite in `if (NOT_CRAN == "true")` — the CRAN-visible test time is ~2s.
    No gating work needed. **Decision (2026-08-15): intended policy.** The
    full suite runs continuously on the CI matrix (5-platform `--as-cran`,
    no-Suggests, ASAN/UBSAN, valgrind — `R-CMD-check.yaml`), so CRAN-side
    tests add no coverage; skipping them keeps the CRAN check inside its
    time budget. State this in `cran-comments.md`.
  - **Compile time is the real budget item:** installation took 4017s CPU
    (453s elapsed under `make -j`). Profiled 2026-08-15: an
    RcppEigen-heavy TU costs ~30s vs ~2.8s for a plain-Rcpp TU, and 82 of
    the 106 TUs pay that ~27s header tax (via `_helper_functions.h`,
    first include in ~51 files) — ~41 of the 67 CPU-min is redundant
    header re-parsing, not package code. **Fix: unity-build
    consolidation** — group the 82 heavy files into ~10 unity TUs (thin
    `.cpp`s `#include`-ing 8–12 kernel files each); `configure` already
    generates `src/Makevars`, so emit `OBJECTS = unity_*.o RcppExports.o`
    by default with an `EDI_UNITY=0` escape hatch preserving per-file
    objects for the targeted-compile dev workflow. Projected ~8–12
    CPU-min (~6–7x). One-time cost: collision audit across the 82 files
    (file-scope statics, anonymous namespaces, macro leaks); the
    `NDEBUG`-first-include discipline is already centralized in
    `_helper_functions.h`. Keep groups at 8–12 files for compiler RAM.
    Include-hygiene is not a lever (only 2 files touch RcppNumerical; the
    kernels genuinely need Eigen). Fallback if not pursued: precedent
    justification in `cran-comments.md` (duckdb-class compile times exist
    on CRAN). See TODO-6.
  - **`unlockBinding` NOTE** ("possibly unsafe calls", 3 sites in
    `mixin_contracts.R`) — a known CRAN friction point for new
    submissions. Likely disappears with `fix_inference_hierarchy.md`'s
    Base Deletion (which retires the mixin machinery); if any survive,
    prepare a justification in `cran-comments.md` or restructure. Also:
    `self`/`private` no-visible-binding NOTEs in
    `populate_design_component_registry` (globals fix).
  - **2 ERRORs are mid-migration staleness, owned by existing plans:**
    `InferenceSurvivalGehanWilcox` example still calls
    `add_all_subject_responses(deads = ...)` (y/y_L/y_R migration —
    extend `interval_censored_survival_response.md → TODO-15`'s stale
    `dead =` cleanup to *examples*, not just tests). **Note (2026-08-16):
    that plan has since fully closed and moved to `../finished_features/`;
    re-run this measurement to confirm the example-site fix landed as part
    of closeout, rather than assuming it's still open.** Also,
    `ExactBinomialIncidenceSource`'s example references
    `InferenceIncidExactBinomial`, which no longer exists (hierarchy
    migration). The Rd cross-reference WARNING (2 missing links) is the
    same migration family.
  - **Local-artifact leaks fixed in `.Rbuildignore`** (2026-08-15):
    `cran-comments.md`, `simulation_framework_results.*`, `.mcp.json`,
    `.claude`. Additionally the dev tree's configure-generated
    `src/Makevars` carried `-march=native` into the tarball — **build
    release tarballs from a clean checkout**, as CI does.
  - Rd `\usage` NOTE: `X_r` documented-but-absent in 5
    `fast_*_binomial_regression*` Rd files → fold into
    `fix_documentation.md`.
  - Possibly-dead URLs flagged by incoming feasibility
    (`Block_randomisation`, `Matched_pair` on Wikipedia, 404): verify
    outside the sandbox and fix in the roxygen sources during a doc batch.
  - Re-run this measurement on the release candidate once the Phase 1
    migrations land; the numbers above are the mid-migration baseline.
- [x] **Fix the `EDI_PORTABLE` non-portable-flags default bug.** The
  2026-08-28 local `R CMD check --as-cran` run (TODO-4 below) found 3
  WARNINGs: `checking compilation flags in Makevars ... WARNING`
  (non-portable `PKG_CXXFLAGS`: `-march=native -mtune=native
  -Wno-ignored-attributes -fno-lto`, plus a `CXXFLAGS` override),
  `checking for GNU extensions in Makefiles ... WARNING` (`src/Makevars`'s
  `+=`), and `checking compilation flags used ... WARNING` (compilation
  actually used `-Wno-ignored-attributes -march=native`). Root cause: `R/EDI/
  configure` only writes a portable, GNU-extension-free `Makevars` when the
  `EDI_PORTABLE` environment variable is set to `1` at *install* time —
  `EDI_PORTABLE=0` was configure's default. CI always sets `EDI_PORTABLE: 1`,
  so this never surfaced there; it is a condition CRAN's own build machines
  (and win-builder/mac-builder) will always hit, regardless of anything set
  when the submission tarball was *built*, since `configure` reruns at
  install time. Confirmed by the 2026-08-28 win-builder run (2 WARNINGs, 2
  NOTEs — `checking whether package 'EDI' can be installed` and `checking
  compilation flags used`) and the 2026-08-28 mac-builder run (2 WARNINGs, 1
  NOTE — `checking compilation flags in Makevars` and `checking for GNU
  extensions in Makefiles`). **Fix (2026-08-29):**
  `scripts/submission_tar_build_and_win_mac_check.sh` now patches its
  throwaway scratch copy of `configure` (never the real `R/EDI/configure`,
  and never CI/local dev's build) so that an *unset* `EDI_PORTABLE` defaults
  to the portable build in the tarball it ships — i.e. the exact file CRAN/
  win-builder/mac-builder run at install time, with no env var required on
  their end — and added a verification step that extracts the built
  tarball, reruns its shipped `configure` with `EDI_PORTABLE` explicitly
  unset, and fails the script if `src/Makevars` still contains non-portable
  flags. **Confirmed fixed by the 2026-08-29 mac-builder rerun**
  (https://mac.r-project.org/macbuilder/results/1788035096-11c57fc8646da48a/):
  Status dropped to **1 NOTE** (only the already-justified `unlockBinding()`
  NOTE remains) — both non-portable-flags WARNINGs are gone. **Still open:**
  win-builder has not yet been rerun against the fixed script; do that
  before submission and record the result in `cran-comments.md`. (Separately
  discovered and fixed along the way: the same local check run showed a
  `checking compilation flags used ... NOTE` for a bare `-march=native` that
  traced not to EDI's `configure` at all but to this dev machine's own R
  installation baking `-march=native` into R's global `CXXFLAGS` via
  `Makeconf` — a local-machine artifact CRAN's own R build won't have. Since
  a plain `CXXFLAGS=...` environment variable does not override a
  makefile's own plain assignment of the same name (confirmed by direct
  test), the script's own `R CMD check --as-cran` step now sets
  `R_MAKEVARS_USER` to a scratch file pinning `CXXFLAGS = -O3`, which does
  take precedence per *Writing R Extensions*, so this script's local check
  output stays a fair proxy for what CRAN will see. The script also now sets
  `EDI_SKIP_LOCAL_TUNING=1` on that same check invocation, since a saved
  `tune_EDI_for_this_machine()` result on the developer's machine — stored
  outside the package tree via `tools::R_user_dir()`, never in the tarball
  — otherwise prints a load-time startup message that would be local-only
  noise in a check log meant to be pasted into `cran-comments.md`.)
- [ ] **Submission artifacts.** See `release.md`'s pre-submission checklist
  items 3-4 (`cran-comments.md`, no-reverse-deps statement) — generic across
  releases, tracked there now.

## Implementation TODOs

- [x] TODO-1: Record this scope as decided (done by this file's existence);
  keep `_master.md` phases as the execution order — this file only marks
  which items sit inside the release line.
- [x] TODO-2: Resolve amendment 11: do `optimizer_diagnostics_report.md →
  TODO-4` pre-1.0, or record current `converged` semantics as stable.
  Decision goes in `optimizer_diagnostics_report.md`; note the outcome here.
  **Done (2026-08-17): implemented, not just recorded-as-stable.** `converged`
  redefined as gradient-norm-based (with an LBFGS-specific OR-fallback to
  LBFGSpp's own criterion, added after a compiled/tested regression showed
  the pure-gradient rule made ordinary LBFGS fits spuriously report
  `converged = FALSE`), `hit_iteration_cap` added, every caller audited (see
  `optimizer_diagnostics_report.md → TODO-4` for the full writeup). A
  reproducible `fast_gaussian_lmm_cpp` segfault (unrelated to this decision,
  found while investigating it) was also fixed along the way.
- [x] TODO-3: Fold `marginal_estimand_report.md → TODO-2` (mixture-family
  roxygen sharpening) into a `fix_documentation.md` batch. **Done** — landed
  as part of item 7's doc batch regardless of this item's own move (see
  item 14's writeup); `marginal_estimand_report.md` itself is now fully
  closed (0 open TODOs) and moved to `../finished_features/` (2026-08-25).
- [x] TODO-4: Execute the Release Gate checklist above once items 1–9 and
  14 are closed in their owning plans. **Done (2026-08-28):** a full local
  `R CMD check --as-cran` run against the release candidate, run by the
  user on their own machine (not run by the agent, per this repo's
  standing rule) — found the 3-WARNING `EDI_PORTABLE` default bug, see the
  new Release Gate bullet above for the full root-cause/fix writeup.
  **cran-comments.md partially updated (2026-08-29):** mac-builder
  re-submitted against the fixed script and result recorded (1 NOTE,
  WARNINGs gone). **Still open:** win-builder rerun against the fixed
  script, and a local rerun of the check with the now-fixed script (to
  confirm 0 WARNINGs locally too) — see `release.md`'s pre-submission
  checklist.
- [x] TODO-5: On submission acceptance: move the closed in-scope plans to
  `../finished_features/` per the standing constraint. ~~Open a
  `release_v1_1_0.md` scoping the first additive wave (likely
  `expanded_estimate_report.md` + `marginal_estimand_report.md` +
  Cox-Snell/Cordeiro-McCullagh, per Phase 5A order).~~ **Superseded
  (2026-08-17, user decision):** `release_v1_1_0.md` was opened ahead of
  acceptance with a broader scope — everything open in
  `new_feature_plans/` outside this file's release line, not just a first
  wave. **Done (2026-08-28):** every fully-closed v1.0.0-scoped plan is
  confirmed moved to `../finished_features/`; what remains in
  `new_feature_plans/` is either partially-scoped (only a fragment was
  v1.0.0, the rest is legitimately v1.1.0), genuinely still open
  (`parallel_fork_cluster_test_safety.md` TODO-3/4, blocked on a real CI
  canary push), or reopened since with new v1.1.0-scoped work
  (`marginal_estimand_report.md`).
- [x] TODO-6: Unity-build consolidation — audit, fix pass, and build wiring
  all complete (2026-08-16). See `unity_build_collision_audit.md` for the
  full history. Summary:
  - **Audit + fix pass:** the 105-file mega-TU compiles with zero errors
    (compiler-verified). Two latent bugs surfaced as a byproduct, both
    resolved: a default-argument drift needed no further action (already
    eliminated by item B's own fix), and a real `transform_code == 4` gap
    between two `apply_shift` copies was fixed by adding the missing
    branch (verified, no regression).
  - **Build wiring:** `R/EDI/configure` generates `src/unity_NN.cpp` (10
    groups) under `EDI_UNITY=1` (default), overriding Makevars' `OBJECTS`
    to build only the 10 unity objects + `RcppExports.o`; `EDI_UNITY=0`
    restores the original one-object-per-file build. Generation is
    idempotent (compare-before-write; an unchanged group keeps its mtime,
    so a no-op `configure` re-run — which every `R CMD INSTALL` triggers —
    doesn't force all 10 groups to recompile). Verified end-to-end: a real
    clean `R CMD INSTALL` compiles, links, and loads correctly under both
    `EDI_UNITY=1` and `=0`; a smoke-test suite exercising kernels from
    every file touched during the fix pass (logistic regression, hurdle
    negbin, ZOIB, log-rank, Gehan-Wilcoxon, Hodges-Lehmann, Pocock-Simon)
    produced **bit-identical numeric output** between the two modes.
  - **A real bug found and reverted during implementation:** an initial
    attempt to add `-MMD -MP` + a Makevars `-include $(OBJECTS:.o=.d)`
    line for automatic header/member-file dependency tracking silently
    broke `R CMD SHLIB`/`R CMD INSTALL` outright — it built only the
    *first* object in `$(OBJECTS)` and reported success (exit 0) without
    ever linking `EDI.so`. 100% reproducible, root cause not fully
    diagnosed (suspected: R's own SHLIB-building R code textually
    inspects `Makevars`' `OBJECTS=` line for purposes beyond just handing
    the file to `make`, and chokes on the unexpected trailing directive).
    Removed; do not reintroduce without first understanding why it broke.
    Documented in `configure`'s own comments as a known limitation:
    editing one member `.cpp` file doesn't retrigger a Make-level rebuild
    of its unity group under an *unclean/incremental* install (every fresh
    build — CI, CRAN, `--preclean` — is unaffected, since wrappers are
    always regenerated from the current source tree first). Recommended
    workaround for fast local targeted iteration: `EDI_UNITY=0`.
  - **Standing regression gate:** `scripts/check_unity_build_safety.sh`
    (isolated scratch-copy generation + parallel `-fsyntax-only` check,
    ~30-40s) wired into `.githooks/pre-push`, independent of whatever
    `EDI_UNITY` the working tree currently has configured. Both the pass
    and fail paths verified.
  - **Python side: done (2026-08-16).** `python/CMakeLists.txt`'s `_core`
    target now sets `UNITY_BUILD ON UNITY_BUILD_BATCH_SIZE 10`. This
    surfaced a real collision the R-side mega-TU audit had missed entirely
    — it only ever compiled the non-`EDI_CORE_ONLY` branch, so 7 files each
    independently defining `constexpr double NA_REAL` under
    `#ifdef EDI_CORE_ONLY` had never been checked together. Fixed by
    hoisting one `inline constexpr` definition into a new
    `R/EDI/src/na_real_core.h` (see `unity_build_collision_audit.md` for
    the full writeup — also recorded there as a methodology finding:
    R-only verification doesn't cover the `EDI_CORE_ONLY` branch). Verified
    locally: a clean `pip install -e ".[test]"` build succeeds, the
    extension imports and returns correct kernel output, and the full test
    suite passes (181/181). The original sequencing note (wait for the
    full multi-platform `cibuildwheel` wheel matrix to cycle green first)
    was explicitly waived — that full-matrix validation is deferred to a
    later real CI run rather than blocking this change.
- [x] TODO-7: Fix the Rd cross-reference regression surfaced by
  `fix_roxygenize_lazy_component_srcrefs.md`'s 2026-08-23 full local
  `R CMD check --as-cran` run (amendment 9 above): 18 `.Rd` files with
  missing/dead `\link[EDI:...]{}` targets (up from a "2 missing links"
  baseline on 2026-08-15), 7 files with un-anchored `\link{}` targets to
  non-existent functions, and 7 `Inference*IVWC`/`OneLik` component-source
  classes (`InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`,
  `InferenceContinKKRobustRegrOneLik`, `InferenceCountKKHurdlePoissonIVWC`,
  `InferenceIncidKKCondLogitIVWC`, `InferenceSurvivalKKClaytonCopulaIVWC`,
  `InferenceSurvivalKKStratCoxPHIVWC`) reported as fully undocumented. **Done
  (2026-08-23):** root cause confirmed as a recurring "misplaced doc block"
  bug (same pattern found earlier in `fix_documentation.md`'s work) — each
  of the 7 classes' real title/`@details`/`@examples`/`@export` roxygen
  block was sitting above an intermediate bare component-source `list(...)`
  variable instead of directly above its own `ClassName =
  define_inference_class(...)` call, so roxygen2 never generated a real Rd
  page for the class itself; every `\link[EDI:ClassName]{}` pointing at it
  from a sibling doc was consequently "missing." Fixed by moving each of
  the 7 blocks to the correct location (verified no accidental content
  loss — each moved block's prose was preserved verbatim). The remaining
  un-anchored/dead `\link{}` targets (5 more: `assertNoCensoring`,
  `BayesianBootstrap`, `compute_bayesian_bootstrap_confidence_interval`,
  `conditional_logit_fit_matched_pairs`/`_reservoir`,
  `get_continuation_ratio_regression_hessian_cpp`,
  `fast_probit_regression_weighted_cpp`, `gcomp_fractional_logit_post_fit_cpp`,
  a nonexistent `OrdinalRegression` object, and one wrong package anchor —
  `\link[base]{pnorm}` should be `\link[stats]{pnorm}`) were links to
  internal/undocumented names or component names, not real Rd topics;
  fixed by de-linking to plain `\code{}` (or the correct package anchor).
  C++-sourced fixes were made in the `.cpp` roxygen source (not the
  generated `RcppExports.R`, which was also hand-synced so it doesn't look
  stale until the next `compileAttributes()` run). Verified with a full
  local `R CMD build` + `R CMD check --as-cran --no-manual --no-examples
  --no-tests --no-vignettes` (fast Rd-only pass) from a clean checkout:
  **zero "Missing link(s)" and zero "Undocumented code objects" entries**
  (down from 18 files / 7 classes). Remaining WARNINGs/NOTEs are the
  already-tracked pre-existing/environmental ones (Makevars flags, `X_r`
  usage NOTE, non-ASCII chars, missing `inst/doc`, etc.) — none are Rd
  cross-reference issues. TODO-4's Release Gate execution is unblocked.
