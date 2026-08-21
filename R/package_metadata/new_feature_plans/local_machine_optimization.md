# Local Machine Optimization: `tune_EDI_for_this_machine()`

> **Depends on:** `cold_starts.md` (its policy-table documentation audit should
> land first so the benchmarked axes are correctly described), and the
> warm-start dispatcher refactor in TODO-2 below (a prerequisite carved out of
> this plan itself). **Moved into the v1.0.0 release line (2026-08-20, user
> decision)** — this is additive API and touches no frozen public contract,
> but ships alongside the 1.0.0 batch rather than deferred to 1.1.0. (Global
> ordering: see `_master.md`, Phase 6.)

## Motivation

Every performance-policy default shipped in `EDI/R/globals.R` was computed
empirically **on the developer's machine, possibly under contention** (the
benchmark boxes were also running builds). Users' machines differ in core
count, cache sizes, BLAS backend, compiler flags used to build EDI, and
NUMA/SMT topology — so a policy that is net-positive on the dev box (e.g.
"smart cold start pays off for Weibull", "warm starts only pay off when
`n >= 200` for family X", "fork-cluster parallelism beats serial at 4+ cores
for bootstrap") can be net-negative elsewhere, and vice versa.

The feature: a user-facing, explicitly-invoked tuner,

```r
tune_EDI_for_this_machine(effort = c("quick", "standard", "thorough"), ...)
```

that re-runs the same benchmarks the shipped defaults came from **on the
user's own hardware**, decides the winning setting per axis, persists the
results to a per-user config file, and has `.onLoad()` import that file on
every subsequent `library(EDI)` so the machine-specific policies silently
replace the shipped defaults. Hardware changed? Re-run the function; it
rewrites the file.

## The tunable axes (what gets benchmarked)

These are exactly the policy tables in `globals.R` whose entries are
**empirical performance judgments** (as opposed to correctness/statistical
judgments — see "Explicitly out of scope" below):

1. **Cold starts** — `get_cold_start_dispatch_policy()`
   (`EDI/R/globals.R:746-761`): per inference class, is the OLS/heuristic
   `smart_cold_start` warm-up worth it vs. a plain zero start? The shipped
   `FALSE` overrides (logistic/Poisson IRLS, GComp families) are exactly the
   "one extra OLS solve costs more than the iterations it saves *at typical
   trial sizes on this machine*" finding — the canonical machine-dependent
   call. Runtime override already exists:
   `set_cold_start_dispatch_policy()` (`EDI/R/globals.R:796-808`).
2. **Warm starts** — `get_warm_start_dispatch_policy()`
   (`EDI/R/globals.R:863-897`): per inference class × operation
   (`jackknife` / `non_param_boot` / `bayesian_boot` / `param_boot` /
   `rand`), does reusing the previous replicate's parameters/curvature pay
   off? Note the dispatcher `edi_warm_start_dispatch_policy()`
   (`EDI/R/globals.R:953-1201`) carries a large **hardcoded,
   sample-size-conditioned layer** (e.g. disable only when `n < 200` or
   `n < 500`) that `set_warm_start_dispatch_policy()` cannot touch — those
   `n` thresholds are the *most* machine-dependent numbers in the package
   (they encode "at what n does per-replicate fit cost exceed the warm-start
   bookkeeping *on the dev box*") and are currently unreachable by any
   override mechanism. TODO-2 fixes this first.
3. **Optimizer algorithm** — `get_optimization_dispatch_policy()`
   (`EDI/R/globals.R:680-713`): `newton_raphson` vs. `lbfgs` vs. `irls` per
   family. Partially machine-dependent (relative cost of Hessian solves vs.
   L-BFGS iterations depends on BLAS and cache) — but also partially a
   *convergence-reliability* judgment. The tuner may only switch an
   algorithm when the candidate converges on **every** benchmark replicate
   for that family; speed never trumps a convergence failure.
4. **Parallel vs. serial, and core counts** —
   `get_parallel_dispatch_policy()` (`EDI/R/globals.R:544-559`),
   `set_num_cores()` / `make_configured_fork_cluster()` / mirai
   (`EDI/R/globals.R:321-504`), and `set_package_threads()`
   (`EDI/R/globals.R:1446-1494`). Tunables: (a) the crossover replicate
   count / sample size at which forking a cluster beats serial for
   `bootstrap` and `rand_ci` per family; (b) the best default core count per
   operation (not always `detectCores()` — SMT siblings and BLAS
   oversubscription can make fewer cores faster); (c) fork-cluster vs. mirai
   dispatch preference where both are available. **Constraint:** entries in
   the shipped serial-blocklist that exist for *parallel-safety* (documented
   at `EDI/R/globals.R:515-528`: "not currently parallel-safe") are
   correctness, not performance — the tuner must never un-serialize them
   (TODO-6).

## Explicitly out of scope

- **Bootstrap CI type** (`get_bootstrap_dispatch_policy()`,
  `EDI/R/globals.R:606-645`): BCa vs. percentile is a *statistical validity*
  table ("BCa is empirically unreliable for these classes"), not a
  performance table. Machine tuning must never touch it.
- Anything that changes numerical results beyond timing: tolerances, max
  iterations, seeds. The tuner's invariant is **bit-identical estimates and
  CIs under every setting it is allowed to flip** (cold/warm starts change
  the optimizer's path, so "bit-identical" there means: converged solution
  agrees within the solver's own convergence tolerance; the acceptance gate
  in TODO-8 makes this precise).
- Auto-running anything at install, load, or attach time. Benchmarks run
  **only** inside an explicit `tune_EDI_for_this_machine()` call (CRAN policy and
  basic courtesy). `.onLoad()` only *reads* a previously written file.

## Architecture

### The tuner

`tune_EDI_for_this_machine(effort, axes, families, n_grid, num_cores_grid, quiet, dry_run)`

- `effort`: `"quick"` (~2-5 min: coarse n-grid, fewest replicates, only the
  axes/families with the largest shipped effect sizes), `"standard"`
  (~15-30 min: default), `"thorough"` (~1-2 hr: full family × operation ×
  n-grid factorial, more replicates for tighter noise bounds). Print an
  up-front estimate of wall time and warn that the machine should be
  otherwise idle (a tuning run under contention reproduces the original sin
  this feature exists to fix — measure and warn on load average first,
  TODO-7).
- Benchmarks are generated, not hand-listed: iterate the inference-class
  registry (`EDI/R/inference_class_registry.R`) so newly added families are
  tuned automatically, using each class's own synthetic-data generator
  (reuse the existing test-fixture generators rather than inventing new
  ones).
- Per axis, per cell: run both settings interleaved (A/B/A/B, not A…A/B…B,
  to decorrelate thermal/frequency drift), take medians, and only deviate
  from the shipped default when the candidate wins by a **noise margin**
  (default: ≥ 5% median improvement *and* the improvement exceeds 2× the
  interquartile spread of the replicate timings). Ties → keep the shipped
  default. This keeps the output file small: it stores only *deviations*
  from shipped defaults, applied via the existing `modifyList`-merging
  setters.
- `dry_run = TRUE`: run the benchmarks and print the would-be policy diff
  without writing the file.
- Returns (invisibly) a structured result object: the policy diff, the raw
  timing tables, and the hardware fingerprint — printable/summarizable, so
  users can eyeball what changed and why.

### The persisted file

- Location: `tools::R_user_dir("EDI", which = "config")` (the
  CRAN-sanctioned per-user config dir), file `machine_policies.rds`.
  Written **only** by `tune_EDI_for_this_machine()` (plus a
  `clear_local_EDI_optimization()` to delete it and return to shipped
  defaults).
- Contents:
  - `schema_version` (integer, bumped when the policy schema changes),
  - `edi_version` (the package version that ran the tuning),
  - `hardware_fingerprint`: core count (physical + logical), CPU model
    string, total RAM, BLAS/LAPACK library string
    (`extSoftVersion()`/`La_library()`), platform, and the compiler flags
    EDI was built with where recoverable,
  - `timestamp`, `effort` level used,
  - one policy-diff list per axis (cold start / warm start incl. the
    n-thresholds from TODO-2 / optimizer / parallel + cores), each in the
    exact shape its `set_*_dispatch_policy()` setter accepts.

### Load-time import

In `.onLoad()` (`EDI/R/zzz.R:4-32`), after the existing
`set_package_threads(1L)` call: if the config file exists, read it and apply
each stored diff through the existing setters. Rules:

- **Fail open, quietly**: unreadable/corrupt file, unknown
  `schema_version`, or a diff that fails the setters' `checkmate`
  validation → ignore the file entirely (shipped defaults stand) and emit a
  single `packageStartupMessage` telling the user to re-run
  `tune_EDI_for_this_machine()`. Never error at load time.
- **Fingerprint mismatch** (core count or CPU model changed since tuning):
  still apply the stored policies (they're probably better than nothing),
  but `packageStartupMessage` that the hardware appears to have changed and
  suggest re-running.
- **Version skew**: stored diffs reference inference classes by the same
  regex-pattern keys the policy tables use; patterns matching classes that
  no longer exist are silently inert (the dispatchers already just don't
  match them), and new classes added since tuning simply fall through to
  shipped defaults — `modifyList` merging gives both properties for free.
- The parallel/core-count diff must respect the load-time
  single-threaded-by-default invariant established at `EDI/R/zzz.R:14-31`:
  the stored *preferred* core count is recorded but **not** auto-applied as
  the active core count at load (users still opt into parallelism via
  `set_num_cores()`, `EDI/R/globals.R:420-473`); what it does change is what
  `set_num_cores()`'s helpers and the crossover thresholds consider optimal
  once the user opts in. **(Decided by the user, 2026-08-17: recorded-only —
  never auto-applied at load. TODO-1(d) is resolved.)**

## Implementation TODOs

- [x] TODO-1: **Decision gate (ask the user, no code). DONE (2026-08-21,
  user decision).** (a) function name: **`tune_EDI_for_this_machine()`**
  (not `optimize_EDI_locally()`/`edi_autotune()`); (b) storage: **confirmed**
  — `tools::R_user_dir("EDI", "config")` + `.rds`; (c) persistence shape:
  **confirmed** — store only deviations from package defaults, merged in via
  the existing `set_*()` setters (not a full snapshot of every tunable
  value); (d) **resolved 2026-08-17 (user decision)**: the tuned core count
  is recorded-only — applied when the user opts into parallelism via
  `set_num_cores()`, never auto-applied at load; (e) Python-side twin:
  **deferred** — R-only for this release, a Python twin is a future plan
  item, not part of this release's scope.
- [x] TODO-2: **Prerequisite refactor — lift the hardcoded warm-start layer
  into the config table. DONE (2026-08-21).** Moved all ~90
  sample-size-conditioned disable rules out of `edi_warm_start_dispatch_policy()`'s
  hardcoded `if` cascade into a new `n_conditioned_overrides` list per
  operation in `get_warm_start_dispatch_policy()` (each rule:
  `list(pattern, value, n_min, n_max)`, matched when `n_val` falls in
  `[n_min, n_max)`). The "Global disables" (n-unconditioned hardcoded
  blocks) were folded into the existing `inference_class_overrides` vectors.
  `edi_warm_start_dispatch_policy()` now consults both layers generically
  (unconditioned pattern table, then n-conditioned rules) instead of a
  90-branch `if` cascade. `set_warm_start_dispatch_policy()` was also fixed
  to replace `n_conditioned_overrides` wholesale on override rather than
  routing it through `modifyList()`, which silently no-ops on unnamed lists
  (caught by the new test below) — both layers are now genuinely
  overridable, closing (a) and (b). Roxygen on both functions updated to
  drop the "unreachable"/"cannot override" caveats.
  **Verification:** a scripted golden-equivalence check compared the
  refactored dispatcher against the pre-refactor hardcoded function across
  4,875 (class, operation, n) combinations (every class named anywhere in
  the old policy, all 5 operations, every n boundary ± 1) — zero mismatches.
  That check is now a permanent regression test,
  `test-warm-start-dispatch-policy-refactor.R` (golden-equivalence test +
  a test confirming `set_warm_start_dispatch_policy()` can override an
  n-conditioned rule end-to-end), plus `test-inference-dispatch-policy-structure.R`
  extended to validate every `n_conditioned_overrides` pattern still matches
  a live inference class name. All of `test-gcomp-boot-warm-start-chaining.R`,
  `test-gee-warm-start.R`, `test-smart-start-warm-paths.R`,
  `test-warm-start-weights.R` pass unchanged (no behavior regression). Pure
  R change, no C++ touched — verified via `pkgload::load_all(compile = FALSE)`,
  no rebuild.
- [x] TODO-3: **Build the benchmark harness. DONE (2026-08-21).**
  `R/EDI/R/local_machine_tuning_harness.R` (all internal, `@noRd`, no
  exports yet — `tune_EDI_for_this_machine()` itself is TODO-4/5):
  - `edi_tuning_live_families()` — registry-driven family enumeration:
    iterates the live `EDI` namespace via `is_inference_r6_generator()`
    (same pattern as `test-inference-dispatch-policy-structure.R`), keeps
    concrete classes where `infer_inference_response_types()` resolves to
    exactly one response type (131 live classes → 107 single-family
    concretes; the 24 excluded are abstract/mixin bases and wildcard
    `InferenceAll*` classes with no single synthetic-data recipe). A newly
    added concrete inference class is picked up automatically.
  - `edi_tuning_synthetic_experiment()` — thin wrapper around
    `inference_migration_complete_design()`. **Literally reused, not
    reinvented**, per this TODO's own instruction: that generator (plus its
    `inference_migration_with_seed()`/`inference_migration_add_subjects()`/
    `add_all_subject_responses_seq()` dependencies) was moved out of the
    testthat-only `helper-inference-migration-harness.R`/
    `helper-sequential-responses.R` into a new package file,
    `R/EDI/R/tuning_synthetic_fixtures.R` — it has to live in shipped
    package code, not `tests/testthat/`, since a real user's
    `tune_EDI_for_this_machine()` call has no access to test helpers at
    runtime. The two golden-test helper files now just call the package's
    (identical, unqualified-visible-under-`load_all()`) internals instead
    of redefining them, eliminating the drift risk of two copies. All ~30
    dependent `*-migration-golden.R` test files verified unaffected.
  - `edi_tuning_interleaved_ab(fn_a, fn_b, reps)` — A/B/A/B (not
    A...A/B...B) wall-clock timing via `proc.time()[["elapsed"]]`, median +
    IQR of each side.
  - `edi_tuning_accept_candidate(baseline_times, candidate_times,
    min_rel_improvement = 0.05, iqr_multiplier = 2)` — the noise-margin
    acceptance rule: candidate must beat baseline by ≥5% median AND that
    absolute improvement must exceed 2× the candidate's own IQR, else keep
    the shipped default.
  - `edi_tuning_effort_presets()` — `quick`/`standard`/`thorough` n-grid +
    replicate-count + family-scope presets (`quick` defers *which* families
    count as "top effect size" to TODO-4, since that needs each axis's own
    effect-size data — this preset only fixes the axis-agnostic n-grid/reps).
  **Tests:** `test-local-machine-tuning-harness.R` (27 assertions covering
  family enumeration correctness/exclusions, synthetic-experiment
  determinism and RNG-non-leakage, interleaved-timing correctness, the
  acceptance rule's accept/reject boundaries — clean win, sub-5% win,
  IQR-swallowed win, tie, regression — and the effort-preset ordering
  invariants). No model fitting or real dispatch-policy wiring yet — that's
  TODO-4. Pure R; no C++ touched.
- [ ] TODO-4: Implement the four per-axis tuners (cold start, warm start +
  n-thresholds, optimizer algorithm with the all-replicates-converge
  guard, parallel crossover + core count). The load-time core-count
  decision is settled (TODO-1(d), 2026-08-17): recorded-only, consumed by
  `set_num_cores()` when the user opts in — implement accordingly.
- [ ] TODO-5: Implement persistence: the `.rds` schema above,
  `tune_EDI_for_this_machine()`'s write path,
  `clear_local_EDI_optimization()`, and a
  `get_local_EDI_optimization()` query/print method showing the active
  machine policies, their provenance, and the fingerprint.
- [ ] TODO-6: Hard-code the safety blocklist: the parallel-safety-motivated
  serial entries (`EDI/R/globals.R:544-559`, per the rationale at
  `EDI/R/globals.R:515-528`) and the entire bootstrap-CI-type policy are
  tagged untunable; the tuner must assert it never emits a diff touching
  them, with a test.
- [ ] TODO-7: Contention guard: before benchmarking, measure load average /
  a quick calibration timing against a stored reference op; if the machine
  looks busy, warn and require `force = TRUE` (or interactive confirmation)
  to proceed.
- [ ] TODO-8: Correctness gate inside the tuner: for every cell where a
  non-default setting wins, re-fit once under both settings and assert
  estimates/CIs agree within solver tolerance before the deviation is
  accepted; any disagreement discards the deviation and logs it loudly.
- [ ] TODO-9: `.onLoad()` import path in `EDI/R/zzz.R`: read, validate
  (schema version + `checkmate` on each diff), apply via setters, fail-open
  rules and the two `packageStartupMessage` cases (corrupt → re-run;
  fingerprint drift → suggest re-run).
- [ ] TODO-10: Tests: (a) round-trip — tune with a mocked micro-benchmark
  (so CI takes seconds, not minutes), write, fresh-load-simulate, assert
  policies applied; (b) corrupt/stale-schema file → shipped defaults +
  single startup message; (c) fingerprint-mismatch message; (d) unknown
  class patterns inert; (e) TODO-6's untunable-axes assertion; (f)
  `dry_run` writes nothing. Real (non-mocked) benchmark runs are exercised
  only in a skip-on-CRAN long test.
- [ ] TODO-11: Documentation: full roxygen for the new exported functions;
  cross-link from every `get_*_dispatch_policy()`/`set_*_dispatch_policy()`
  roxygen block ("these defaults were computed on the maintainer's machine;
  run `tune_EDI_for_this_machine()` to recompute them for yours"); a short
  vignette section under the performance/vignettes umbrella; update
  `cold_starts.md`'s conclusions to note the defaults are now
  locally-recomputable. Follow the standing no-interim-roxygenize batching
  rule.
- [ ] TODO-12: Add this plan to `_master.md` Phase 6 with its dependency
  edge (TODO-2 may be pulled earlier). *(Done at plan-creation time —
  verify the entry survives the next `_master.md` regeneration.)*
