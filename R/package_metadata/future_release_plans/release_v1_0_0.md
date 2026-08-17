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

1. **`fix_inference_hierarchy.md`** — the class architecture, component and
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
6. **`extending-edi-r6.md`** — the external extension contract; it freezes
   when the hierarchy plans do, per the standing constraint in `_master.md`.
7. **`fix_documentation.md`** — CRAN requires complete documentation, and
   the master ordering already sequences doc batches after the hierarchies
   settle (regenerate the Rd snapshot after Phases 1D/1E first).

### Amendments (added to the seven-plan batch)

8. **[x] `multi_arm_designs.md → TODO-6`** — the `InferenceIncidCMH`
   non-blocking balance-guard gap. `_master.md` calls it "a live two-arm
   correctness bug"; known-wrong numbers do not ship in 1.0.0. Only TODO-6 is
   pulled in; the rest of the multi-arm plan stays deferred. **Done
   (2026-08-16):** construction-time `prob_T == 0.5` guard added to the
   non-blocking branch (mirroring the blocking branch), plus a `warning()`
   for realized-allocation imbalance even at `prob_T = 0.5`. See
   `multi_arm_designs.md`'s TODO-6 for the full writeup.
9. **`fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO`** — a
   clean `R CMD check --as-cran` is the literal gate to CRAN; it runs inside
   the release batch (after the first large doc batch, and again after Base
   Deletion), not adjacent to it.
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
    `save_results_as_JSON` parameters) that must freeze at 1.0.0. Sequenced after Phase
    1D per `_master.md` § 1G.

## Deferred to 1.x (additive by construction)

Everything below attaches to the frozen substrate without breaking it —
that is the point of freezing first:

- **Phase 0 decision batch + Phase 5A corrections track**:
  `expanded_estimate_report.md` (`estimate_type`),
  `marginal_estimand_report.md` (`set_estimand()`), Cox-Snell /
  Cordeiro-McCullagh / median-bias corrections, Firth, L1/L2, Bartlett
  extensions, modified profile likelihood, bootstrap-calibrated LR. All are
  new switches/methods whose defaults preserve 1.0.0 behavior. (One
  decision-independent exception folds into item 7 now:
  `marginal_estimand_report.md → TODO-2`, the roxygen sharpening of the
  mixture families' conditional-estimand wording, is documentation and
  belongs in the 1.0.0 doc batch.)
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
- [ ] TODO-4: Execute the Release Gate checklist above once items 1–9 are
  closed in their owning plans.
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
