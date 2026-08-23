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
   verified to run on the current tree.
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

13. **`inference_suite_inspect.md`** (added 2026-08-17, user decision) —
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
    2026-08-18, user decision) — see `_master.md` § 1G.

14. **`marginal_estimand_report.md`** (added 2026-08-18, user decision —
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
    TODO-4/5/7/9 (the concrete ZOIB/ZIP/hurdle/logit/Poisson/beta-
    regression wiring) remain gated on `fix_inference_hierarchy.md`'s
    Full-Likelihood Estimators remainder. Sequenced in `_master.md`'s
    Phase 0 and Phase 5A step 1.
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

16. **`parallel_fork_cluster_test_safety.md`** (added 2026-08-21, user
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
    full writeup.

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

- **`edi_kernels` 1.0.0 (PyPI) ships from the same commit family** as the
  CRAN 1.0.0. The interval-censoring rework it waited on (item 3) is now
  done (2026-08-16); this no longer blocks the Python side by itself, but
  the "ship from the same commit family" and "separate explicit go-ahead"
  rules below still apply.
- Tagging, pushing, and submitting (CRAN or PyPI) each remain a **separate
  explicit go-ahead** — nothing in this plan authorizes them.
- CHANGELOG: the 1.0.0 entry is written when the batch closes, dated at
  actual submission time (house convention).

## Release Gate — CRAN mechanics checklist

Audited 2026-08-15 against `.github/workflows/R-CMD-check.yaml`. Most of the
classic pre-CRAN checklist is **already continuously enforced by CI** and is
listed here only for the record, not as outstanding work:

- Covered by CI: `--as-cran` across a 5-leg matrix (macOS/Windows/Linux ×
  devel/release/oldrel-1) with `error-on: "note"`; a no-Suggests leg
  (`dependencies: NA` + `_R_CHECK_SUGGESTS_ONLY_`); ASAN/UBSAN
  (`rocker/r-devel-san`); valgrind memcheck; `\donttest{}` examples on 4 of
  5 legs; portable Makevars (`EDI_PORTABLE=1`); compacted vignettes.
  Package-size, Rd, and example-timing NOTEs fail CI by the `error-on`
  setting.

The outstanding gate items are the four things CI structurally cannot or
deliberately does not cover:

- [ ] **CRAN-incoming checks.** CI runs with `_R_CHECK_CRAN_INCOMING_=false`
  (set by `check-r-package@v2`; see the workflow's own comment). Run
  win-builder (release + devel) and mac-builder before submission — they are
  the only place the DESCRIPTION-policy checks (Title/Description phrasing,
  misspellings, URL validity, license), submission feasibility, and the
  overall-checktime NOTE actually execute. Win-builder devel also covers
  Windows/R-devel, which the CI matrix lacks (Windows runs release only).
- [ ] **Fix the Windows `\donttest{}` hang.** CI set
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
  pinned Windows-only, capped by the job's existing 90-minute
  `timeout-minutes` (so worst case is a 90-minute wait, not a repeat of the
  5.5-hour incident). **Not yet verified against a real CI run** — needs a
  push to trigger the Windows leg and a watch of the result; if the hang
  recurs, revert (`_R_CHECK_DONTTEST_EXAMPLES_` back to `'false'` on Windows,
  drop `OMP_NUM_THREADS`) and fall back to per-file-group CI bisection.
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
- [ ] **Submission artifacts** (not CI-able): `cran-comments.md` (test
  environments, check results, NOTE justifications), the no-reverse-deps
  statement, and the submission form itself.

## Implementation TODOs

- [ ] TODO-1: Record this scope as decided (done by this file's existence);
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
- [ ] TODO-3: Fold `marginal_estimand_report.md → TODO-2` (mixture-family
  roxygen sharpening) into a `fix_documentation.md` batch.
- [ ] TODO-4: Execute the Release Gate checklist above once items 1–9 and
  14 are closed in their owning plans.
- [ ] TODO-5: On submission acceptance: move the closed in-scope plans to
  `../finished_features/` per the standing constraint. ~~Open a
  `release_v1_1_0.md` scoping the first additive wave (likely
  `expanded_estimate_report.md` + `marginal_estimand_report.md` +
  Cox-Snell/Cordeiro-McCullagh, per Phase 5A order).~~ **Superseded
  (2026-08-17, user decision):** `release_v1_1_0.md` was opened ahead of
  acceptance with a broader scope — everything open in
  `new_feature_plans/` outside this file's release line, not just a first
  wave. Only the move-to-finished_features part of this TODO remains.
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
- [ ] TODO-7: Fix the Rd cross-reference regression surfaced by
  `fix_roxygenize_lazy_component_srcrefs.md`'s 2026-08-23 full local
  `R CMD check --as-cran` run (amendment 9 above): 18 `.Rd` files with
  missing/dead `\link[EDI:...]{}` targets (up from a "2 missing links"
  baseline on 2026-08-15), 7 files with un-anchored `\link{}` targets to
  non-existent functions, and 7 `Inference*IVWC`/`OneLik` component-source
  classes (`InferenceContinKKOLSIVWC`, `InferenceContinKKOLSOneLik`,
  `InferenceContinKKRobustRegrOneLik`, `InferenceCountKKHurdlePoissonIVWC`,
  `InferenceIncidKKCondLogitIVWC`, `InferenceSurvivalKKWeibullFrailtyLoggammaIVWC`,
  `InferenceSurvivalKKStratCoxPHIVWC`) reported as fully undocumented. Looks
  like `fix_inference_hierarchy.md`'s KK/IVWC migration renamed/merged
  classes without updating every sibling `*Source.Rd` cross-reference to
  match — not this srcref-fix plan's doing, but real and CRAN-blocking
  (`error-on: "note"` in CI). Full file list in that plan's writeup and the
  check log. This is the last known blocker for a clean
  `R CMD check --as-cran` on this codebase; TODO-4's Release Gate execution
  should not be attempted until this closes.
