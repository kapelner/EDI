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
- **Progress bar (added 2026-08-21, user instruction):** while running,
  `tune_EDI_for_this_machine()` shows the same rolling-update screen
  progress bar as `InferenceSuite$run_all_inference()` — reuse
  `run_all_inference_progress_bar_line(n_done, n_total, elapsed_secs_so_far)`
  and `run_all_inference_fmt_secs()` (`inference_suite.R`) directly rather
  than re-deriving the bar-rendering/ETA-estimation logic: a single
  bracketed percent-fill bar with an ETA (mean per-cell elapsed time so
  far × cells remaining), redrawn in place via `\r` as each benchmark cell
  (family × n × axis-candidate) completes, living at the bottom of the
  screen the same way `run_all_inference()`'s does. `n_total` is the total
  cell count across every axis/family/n-grid combination the current
  `effort`/`axes` selection will run — computable up front (it is exactly
  what the "up-front wall-time estimate" bullet above already needs), so
  the same count drives both the pre-run estimate and the live bar's
  denominator.
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
    `R/EDI/R/local_machine_tuning_synthetic_fixtures.R` — it has to live in shipped
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
- [x] TODO-4: **DONE (2026-08-21), with three recorded scope boundaries — see the per-axis writeups below.** Implement the four per-axis tuners (cold start, warm start +
  n-thresholds, optimizer algorithm with the all-replicates-converge
  guard, parallel crossover + core count). The load-time core-count
  decision is settled (TODO-1(d), 2026-08-17): recorded-only, consumed by
  `set_num_cores()` when the user opts in — implement accordingly.
  **In progress (2026-08-21):** `R/EDI/R/local_machine_tuning_axes.R` has
  the shared engine (`edi_tuning_tune_binary_axis()` — axis-agnostic:
  given a per-class current-setting getter and a "run one timed unit under
  this setting" callback, interleaved-times current vs. flipped candidate
  across every family x n-grid cell and keeps only flips that clear the
  TODO-3 acceptance rule) plus a **complete, real cold-start axis tuner**:
  `edi_tuning_cold_start_families()` (scoped to the ~9 patterns
  `get_cold_start_dispatch_policy()` already names — the only classes
  known to expose a real `smart_cold_start` C++ branch, per
  `cold_starts.md`; benchmarking classes outside that set would mean
  guessing whether their kernel even reads the dispatch table),
  `edi_tuning_cold_start_run_setting()` (overrides
  `set_cold_start_dispatch_policy()` for one class, constructs the
  `Inference` object on a synthetic experiment, restores the exact
  prior policy snapshot via `on.exit` — not `reset = TRUE`, which would
  discard any override already in effect before the call, a real bug
  caught while writing the restore path), and
  `edi_tuning_tune_cold_start()` tying them together. Verified end-to-end
  (`NOT_CRAN=true`) against a real `InferenceCountPoisson` construction,
  not just a mocked timer. Tests: `test-local-machine-tuning-axes.R` (16
  assertions: shared-engine accept/reject/call-count correctness with a
  mocked micro-benchmark per TODO-10(a)'s guidance, cold-start family
  scoping, policy-restore-on-exit, and one `skip_on_cran()`-guarded real
  end-to-end smoke test per TODO-10(f)).
  **Warm start also done (2026-08-21):** the shared engine's
  `get_current_setting` contract was widened from `function(class)` to
  `function(class, n)` — warm start's n-conditioned layer means "the
  current setting" genuinely depends on `n`, unlike cold start — with
  cold start's call site updated to just ignore the second argument.
  `EDI_TUNING_WARM_START_OPERATION_CALLS` maps each of the five
  operations (`jackknife`/`non_param_boot`/`bayesian_boot`/`param_boot`/
  `rand`) to one generic public method + a small `B`/`r` (benchmark speed,
  not accuracy), reusing the exact method names
  `helper-inference-migration-harness.R`'s `inference_migration_method_calls`
  already exercises across every migrated class rather than inventing a
  second generic entry point. `edi_tuning_class_has_public_method()` (walks
  the R6 inheritance chain) scopes `edi_tuning_warm_start_families(operation)`
  to classes that actually implement that operation's method (most classes
  support jackknife/non_param_boot; bayesian_boot/param_boot/rand are
  capability-gated to a subset). `edi_tuning_warm_start_run_setting()`
  overrides the policy for one class+operation unconditionally
  (`n_min = -Inf`/`n_max = Inf`, overriding this cell's decision regardless
  of where it falls in the n-conditioned table), runs the operation, and
  restores the exact prior snapshot directly (not via `reset = TRUE`, same
  bug class as cold start's fix) — with a defensive `tryCatch` swallowing
  only "not implemented/supported" errors (the same pattern
  `inference_migration_unsupported_error()` already uses) and re-throwing
  anything else. `edi_tuning_tune_warm_start(operation, ...)` ties it
  together; called once per operation (five independent dispatch tables
  and cost profiles, not combined into one call). Verified end-to-end
  (`NOT_CRAN=true`) against a real `InferenceCountPoisson` jackknife run.
  Tests: 23 new assertions in `test-local-machine-tuning-axes.R` (39 total
  in that file) covering method-existence walking, family scoping per
  operation, per-class-per-operation policy restore-on-exit, the
  not-supported-error regex (pinned against the migration harness's own
  pattern), and a real end-to-end smoke test.
  **Optimizer-algorithm axis also done (2026-08-21), with one honest
  scope boundary.** Added a shared categorical-axis engine,
  `edi_tuning_tune_categorical_axis()` — generalizes the binary engine to
  >2 candidate settings (`newton_raphson`/`lbfgs`/`irls`) and adds the
  all-replicates-converge guard: a candidate must (a) report
  `isTRUE(converged)` on **every** replicate of a cell (never trading speed
  for a convergence failure) and (b) still clear the noise-margin
  acceptance rule, and among candidates clearing both, the one with the
  largest relative improvement wins. This needed a small harness extension
  — `edi_tuning_interleaved_ab()` now also captures each timed call's
  *return value* (`results_a`/`results_b`, additive, existing callers
  unaffected) so the convergence verdict travels alongside the timing.
  `edi_tuning_optimizer_algorithm_families()`/`_run_setting()`/
  `edi_tuning_tune_optimizer_algorithm()` wire this to
  `get_optimization_dispatch_policy()`, scoped to its own ~26 override
  patterns, with the same policy-snapshot-restore-on-exit discipline as
  cold/warm start. **Scope boundary, stated directly rather than papered
  over:** `edi_tuning_tune_optimizer_algorithm()` takes `converged_fn` as a
  **required** argument with no default, because no generic,
  class-API-independent "did this fit converge" accessor exists on
  `Inference` objects yet — that is `optimizer_diagnostics_report.md`'s own
  still-open diagnostics chain (`_master.md` Phase 2), not a gap this plan
  should paper over with a guessed private-field lookup across ~50+
  heterogeneous classes. A real default `converged_fn` is a follow-up once
  that diagnostics API lands; until then, callers (including the eventual
  `tune_EDI_for_this_machine()` in TODO-4/5) must supply their own, and an
  always-`TRUE` `converged_fn` (which disables the guard) is explicitly
  documented as unsafe for a real tuning run, orchestration-testing use
  only. Tests: 24 new assertions (63 total in
  `test-local-machine-tuning-axes.R`) covering the categorical engine's
  winner-selection and convergence-gating logic (mocked timings), the
  candidates-must-have-length->=2 guard, family scoping, policy
  restore-on-exit with both `converged_fn` verdicts, the required-argument
  check, and a real end-to-end smoke test. One flaky mocked test found and
  fixed along the way: two identical `Sys.sleep(0.001)` calls could
  spuriously trigger the acceptance rule on OS sleep-granularity jitter —
  replaced with an actually-zero-cost no-op on both sides (5/5 clean
  reruns after the fix, vs. an observed failure before it).
  **Parallel crossover-n axis also done (2026-08-21), completing the
  four per-axis tuners.** Design decision (user-confirmed): this axis
  cannot use replicate-level interleaving like the other three, because
  each distinct core count means creating/tearing down a real OS fork
  cluster (`set_num_cores()` → `parallel::makeForkCluster()`), and
  alternating that on every timed replicate would measure cluster-startup
  noise instead of steady-state throughput. So a second harness primitive
  was added, `edi_tuning_blocked_ab()` — all of one setting's reps as one
  contiguous block (paying setup once), then all of the other's — with
  optional `setup_a`/`setup_b` hooks called exactly once per block (the
  hook for `set_num_cores(k)`), and an `a_first` flag the caller alternates
  across cells by loop-index parity so the same side doesn't systematically
  run cold every time (coarser decorrelation than true interleaving, but
  the best available once per-candidate setup cost rules that out).
  `edi_tuning_parallel_families(operation)` applies two required filters:
  the class implements the operation's generic method (reusing warm
  start's `EDI_TUNING_WARM_START_OPERATION_CALLS` via a
  `bootstrap`→`non_param_boot` / `rand_ci`→`rand` mapping, not a third
  generic entry point), **and** the class/response-type is not forced
  serial by `get_parallel_dispatch_policy()`'s blocklist — the concrete
  enforcement of this plan's "never un-serialize the parallel-safety
  entries" constraint for this axis (the general cross-axis assertion is
  TODO-6). `edi_tuning_tune_parallel_crossover(operation, num_cores, ...)`
  scans `n_grid` ascending per family, blocked-times serial (`num_cores =
  1`) vs. parallel (`num_cores = K`) at each `n`, and reports the smallest
  `n` where parallel clears the noise margin as that family's crossover
  point (stopping the scan there — larger `n` only widens parallel's
  advantage); families with no crossover anywhere in the grid are
  **omitted**, not reported with `NA`, matching every axis's
  "store only real deviations" convention. Core count is restored to its
  pre-call value on exit **including on error** (`on.exit`), so a
  benchmarking failure never leaks a stray fork cluster. Tests: 14 new
  assertions in `test-local-machine-tuning-axes.R` (68 total there; plus 14
  new in `test-local-machine-tuning-harness.R` for `edi_tuning_blocked_ab()`
  ordering/setup-hook/median-IQR/validation, 68 total there): blocklist
  exclusion per operation, `num_cores < 2` and unknown-operation guards, a
  **mocked** crossover test (stubs `edi_tuning_blocked_ab`/`set_num_cores`/
  `get_num_cores` via `unlockBinding`, so CI never spins up a cluster for
  it, per TODO-10(a)) asserting the exact crossover `n` is found, and a
  `skip_on_cran()`/`skip_on_os("windows")`-guarded **real** 2-core fork-
  cluster end-to-end smoke test that asserts core count is back to 1
  afterward. Stable across 3 consecutive reruns. The fork cluster was
  confirmed creatable in this sandbox before wiring the real test.
  **Scope boundary for this axis:** the plan's Architecture section lists
  three parallel tunables — (a) crossover n (done here), (b) best *default
  core count* per operation (not always `detectCores()`), and (c)
  fork-cluster vs. mirai dispatch preference. Only (a) is implemented.
  (b) would reuse `edi_tuning_tune_parallel_crossover()` swept over a
  `num_cores_grid` rather than one fixed K, picking the K with the largest
  improvement at a representative n — a straightforward extension left
  for TODO-5's assembly of `tune_EDI_for_this_machine()` (which already
  takes a `num_cores_grid` argument per the Architecture section). (c) is
  deliberately not benchmarked: `set_num_cores()` forbids switching between
  fork and mirai within one R session (nng is not fork-reentrant safe), so
  A/B-ing the two backends in a single tuning run is impossible by
  construction; it would need a subprocess per backend, which is out of
  proportion to the value, and is recorded here as out of scope for v1.0.0.
  **TODO-4 as a whole is now done** modulo those two recorded scope
  boundaries ((b) deferred to TODO-5's assembly, (c) out of scope) and the
  optimizer axis's required-`converged_fn` boundary noted above.
- [x] TODO-5: Implement persistence: the `.rds` schema above,
  `tune_EDI_for_this_machine()`'s write path,
  `clear_local_EDI_optimization()`, and a
  `get_local_EDI_optimization()` query/print method showing the active
  machine policies, their provenance, and the fingerprint. This is also
  where `tune_EDI_for_this_machine()` itself gets assembled end to end
  (effort/axes dispatch over TODO-4's tuners, wall-time estimate,
  `dry_run`, return value) — including the progress bar requirement in the
  Architecture section above (reuse `run_all_inference_progress_bar_line()`/
  `run_all_inference_fmt_secs()`, not a new implementation).
  **DONE (2026-08-21) — verified after the user's reinstall made the tree
  loadable again.** Final numbers: `test-local-machine-tuning-assembly.R`
  86/86 (includes TODO-6's tests, below), harness 68/68, axes 68/68,
  warm-start refactor 4/4, all seven touched source files `parse()`-clean;
  the user's roxygenize regenerated `NAMESPACE` from the `@export` tags
  exactly as predicted (`S3method(print,EDILocalMachineTuning)` +
  `export(clear_local_EDI_optimization/get_local_EDI_optimization/tune_EDI_for_this_machine)`
  all present in roxygen order). Three test-side fixes were needed on the
  first full run — all wrong *expectations*, no production-code change:
  (a) the shipped optimizer pattern is spelled `"InferenceCountPoisson$"`
  (no `^`), so the diff's `"^InferenceCountPoisson$"` is prepended (and
  wins by first-match) rather than replaced in place — asserted
  explicitly now; (b) the shipped NegBin/jackknife warm-start rule only
  covers `n < 1000`, so at `n = 5000` the shipped value was already the
  TRUE default, and the apply correctly leaves it — the test had assumed
  FALSE extended everywhere; (c) the dry-run cell-count expectation
  hardcoded "2 families × every op" when `edi_tuning_warm_start_families()`
  correctly drops a family lacking an op's method **and** NegBin isn't in
  the cold-start table at all — now derived from the same scoping rules.
  Verified directly that the merge-aware warm-start apply preserves the
  shipped rule at n=100/999, applies the new one at n=300, and leaves the
  shipped default at n=5000. **Amendment on the bar `label` argument
  (same day):** the full InferenceSuite suite was started as a regression
  guard but was killed by its own `timeout 580` (exit 143 — a budget kill,
  not a failure: that suite fits every inference class); and a grep showed
  no InferenceSuite test asserts on the bar text at all, so it could not
  have caught a bar regression anyway. Replaced by a direct unit pin in
  `test-local-machine-tuning-assembly.R` — and that pin **caught a real
  bug in the `label` change**: `label_width` was being measured *after*
  `label` had been reassigned to the rendered `"Classes 3/10"` string, so
  it measured `nchar("Classes 3/10 10/10")` = 18 instead of the original
  `nchar("Classes 10/10")` = 14, widening the label column by 4 and
  narrowing the bar for InferenceSuite itself. Fixed (noun stays in
  `label`, rendered string is `label_str`, width measured from
  `"Noun N/N"` as originally); the test now pins the original geometry
  explicitly (`"["` at column 15 for `n_total = 10`, for both nouns) and
  asserts the default output is identical to an explicit `"Classes"`.
  What landed: (1) `on_cell_done`
  threaded through all four axes (categorical engine fires once per
  (family, n) cell, after all candidates; the parallel tuner fires per run
  cell and `NA` per skipped grid point on an early crossover `break`, and
  the assembler's bar driver substitutes the running mean for `NA` so the
  ETA stays unbiased); `edi_tuning_count_cells(plan)` gives the up-front
  worst-case `n_total`. (2) `R/EDI/R/local_machine_tuning_persistence.R`:
  `EDI_TUNING_SCHEMA_VERSION = 1L`; config at `tools::R_user_dir("EDI",
  "config")/machine_policies.rds`, overridable via
  `edi_env$tuning_config_dir_override` (tests use a tempdir); best-effort
  `edi_tuning_hardware_fingerprint()` (every field `tryCatch` → `NA`);
  deviations→diffs exactly as specified in the checkpoint note (cold
  start/optimizer: a class's flip stored only if it won at **every** tested
  n with one consistent value; warm start: one n-conditioned rule per
  deviation over `[n_k, n_{k+1})`; parallel: recorded-only crossovers +
  `preferred_num_cores` = the K with the largest mean gain, ties → smaller
  — and stated plainly: there is currently **no runtime table for
  per-family crossover thresholds** (`get_parallel_dispatch_policy()` is a
  serial blocklist only), so the parallel diff has nothing to be applied
  *to* yet; it is stored for display and for future consumption);
  `edi_tuning_merge_override_vector()` + the **merge-aware**
  `edi_tuning_apply_policy_diffs()` (prepend-and-keep for cold
  start/optimizer; for warm start, new rules first, any conflicting
  *unconditional* entry for that op removed and re-expressed as a
  `[-Inf, Inf)` catch-all placed after the new rules and before the
  pre-existing ones, preserving prior behavior at every uncovered n);
  read/write/validate; exported `clear_local_EDI_optimization()` (deletes
  the file and resets the three setters in-session) and
  `get_local_EDI_optimization()` (reads + prints, never applies).
  (3) `R/EDI/R/local_machine_tuning.R`: exported
  `tune_EDI_for_this_machine(effort, axes, families, n_grid, reps,
  num_cores_grid, converged_fn, quiet, dry_run)` — default `axes` includes
  the optimizer axis only when `converged_fn` is given (explicit request
  without one errors), parallel only on unix with ≥2 cores; `effort =
  "quick"` narrows warm-start families to classes the shipped tables name
  and the parallel axis to the `bootstrap` operation; best-default-core-
  count via sweeping `num_cores_grid` through the crossover tuner; the
  **InferenceSuite progress bar** reused verbatim — a backward-compatible
  `label = "Classes"` argument was added to
  `run_all_inference_progress_bar_line()` so the tuner passes `"Cells"`
  and there is still exactly one bar implementation (`cat(bar(0))` before,
  `"\r\033[K"` + `cat(bar(i))` per cell, `"Status: Completed in …"` after,
  plus an up-front preamble with the cell count and the effort tier's
  nominal time); `dry_run` writes/applies nothing; otherwise writes the
  file **and** applies the diffs in-session; returns an
  `EDILocalMachineTuning` object (raw deviations as an attribute, diffs +
  provenance in the file) with a `print()` method. (4) `@export` tags plus
  hand-appended `export()`/`S3method(print,EDILocalMachineTuning)` lines in
  the roxygen-generated `NAMESPACE` (idempotent on the next roxygenize) and
  `Collate` entries for both new files. (5)
  `test-local-machine-tuning-assembly.R`: 16 tests over a sandboxed config
  dir with **stubbed** axis tuners (no real benchmarking in CI) — merge
  semantics, all-n/consistent-value storage rule, warm-start rule ranges,
  preferred-core-count tie-break, merge-aware apply (other shipped
  overrides provably survive; warm-start unconditional-conflict catch-all
  verified against the live dispatcher), config round-trip/validate/clear,
  `get_` no-file message, axis/`converged_fn`/parallel-availability
  validation, `dry_run` (no file, no apply, correct diffs, exact cell
  count), full write+apply+get+clear round-trip, the `Cells 0/1` →
  `Cells 1/1` → `Status: Completed` bar output, parallel cell accounting
  with `NA`-skipped cells + recorded-only core count, and
  `edi_tuning_count_cells()` arithmetic.
  **Verification status, stated exactly:** all 136 pre-existing tuning
  tests (harness 68, axes 68) and the 4 warm-start-refactor tests pass
  with the callback plumbing and the bar `label` change in place; of the
  assembly file, the 18 pure diff/merge/apply assertions passed on first
  run, and 9 tests errored on a bug in the **test sandbox helper** (an
  `ns$edi_env$x = v` form that tries to rebind the locked namespace symbol)
  — fixed by assigning into the environment object — but the re-run could
  not complete because the working tree then stopped loading on
  `R/inference_ordinal_paired_sign_test.R`/`contracts_mixins.R`, both
  carrying another session's uncommitted, actively-changing edits (the
  error text changed between attempts). Not touched, per this repo's rules.
  All seven touched/added source files `parse()` cleanly. **To close TODO-5:
  once that tree is loadable again, run**
  `pkgload::load_all(".", compile = FALSE); testthat::test_file("tests/testthat/test-local-machine-tuning-assembly.R")`
  (expect all green) and the InferenceSuite suite (the `label` arg defaults
  to the original `"Classes"`, so no behavior change is expected), then
  tick this TODO.
  **Original checkpoint note (superseded by the above, kept for history):**
  session ended on usage limit; package left loadable, all 136 tuning tests
  green. Done so far:
  an optional `on_cell_done = NULL` per-cell callback (fired once per
  (family, n) cell with its elapsed secs — the progress-bar hook) has
  been threaded through `edi_tuning_tune_binary_axis()`,
  `edi_tuning_tune_cold_start()`, and `edi_tuning_tune_warm_start()`.
  **Not yet done, in this order:** (1) thread the same `on_cell_done`
  through `edi_tuning_tune_categorical_axis()`/`_optimizer_algorithm()`
  (fire once per (family, n) cell, not per candidate) and
  `edi_tuning_tune_parallel_crossover()` (fire per run cell; on an
  early crossover `break`, fire `on_cell_done(NA_real_)` for each skipped
  grid point so `n_done` still reaches the worst-case up-front count —
  the assembler's bar driver must substitute `NA` with the running mean
  so the ETA is unbiased), plus a cell-count helper giving `n_total`
  up front per axis. (2) `local_machine_tuning_persistence.R`:
  config path (`tools::R_user_dir("EDI","config")/machine_policies.rds`,
  overridable via an `edi_env` field for tests), hardware fingerprint,
  deviations→setter-shaped diffs (cold start/optimizer: store a class's
  flip only if it won at **every** tested n, else keep default; warm
  start: one n-conditioned rule per deviation over `[n_k, n_{k+1})`,
  prepended so first-match wins), a **merge-aware apply** — critical:
  the `set_*_dispatch_policy()` setters `modifyList()` over *atomic*
  override vectors, which replaces them wholesale, so naively applying a
  one-class diff would wipe the other shipped overrides; apply must
  prepend the diff's entries and keep the rest — and for warm start, if
  a flipped class sits in that op's unconditional
  `inference_class_overrides`, drop it there and re-express the built-in
  value as a trailing catch-all n-conditioned rule so semantics are
  preserved; read/write; `clear_local_EDI_optimization()`;
  `get_local_EDI_optimization()`. (3) `local_machine_tuning.R`:
  `tune_EDI_for_this_machine()` — default `axes` includes the optimizer
  axis only when `converged_fn` is supplied (explicitly requesting it
  without one errors); parallel axis only on unix with ≥2 cores;
  best-default-core-count via sweeping `num_cores_grid` through the
  crossover tuner; the `InferenceSuite` progress bar (`cat(bar(0))`
  before, `cat("\r\033[K")` + `cat(bar(i))` per cell, `"Status:
  Completed in …"` after); `dry_run`; applies diffs in-session too;
  returns an `EDILocalMachineTuning` object with a print method. (4)
  Tests with a temp config dir and stubbed axis tuners (no real
  benchmarking in CI); `@export` tags **plus** hand-appended `export()`
  lines in the roxygen-generated `NAMESPACE` (idempotent on the next
  roxygenize) and `Collate` entries for both new files.
- [x] TODO-6: Hard-code the safety blocklist: the parallel-safety-motivated
  serial entries (`EDI/R/globals.R:544-559`, per the rationale at
  `EDI/R/globals.R:515-528`) and the entire bootstrap-CI-type policy are
  tagged untunable; the tuner must assert it never emits a diff touching
  them, with a test. **DONE (2026-08-21).**
  `EDI_TUNING_UNTUNABLE_SURFACES = c("bootstrap_ci_type",
  "parallel_safety_blocklist")` names the two surfaces, and
  `edi_tuning_assert_diffs_respect_untunable(diffs)`
  (`local_machine_tuning_persistence.R`) is the hard gate: it errors if
  the diff list carries any surface outside the four tunable axes (so a
  `bootstrap` / bootstrap-CI-type diff can never get through), and for the
  parallel axis checks every proposed crossover against the **shipped**
  `get_parallel_dispatch_policy()` blocklist (not the live, possibly
  user-modified one — the blocklist is a safety fact about the code, not a
  preference), refusing with an explicit "parallel-SAFETY reasons, not
  performance" error. Wired into `tune_EDI_for_this_machine()` immediately
  after the diffs are built and **before** anything is written or applied,
  on every run including `dry_run`. This is the hard complement to the soft
  gate already in TODO-4 (`edi_tuning_parallel_families()` never even
  benchmarks blocklisted combinations). Tests (in
  `test-local-machine-tuning-assembly.R`, part of its 86/86): clean diffs
  pass; any unknown/bootstrap surface is refused; an incidence-response
  crossover (blocklisted by response type for both ops) and a non-KK
  survival bootstrap crossover (blocklisted by class pattern) are refused,
  while that same survival class is accepted for `rand_ci` (not blocklisted
  there); an unknown operation is refused; and an end-to-end run with a
  stubbed rogue parallel tuner proposing a blocklisted class errors out
  with nothing written.
- [x] TODO-7: Contention guard: before benchmarking, measure load average /
  a quick calibration timing against a stored reference op; if the machine
  looks busy, warn and require `force = TRUE` (or interactive confirmation)
  to proceed. **DONE (2026-08-21).** `edi_tuning_machine_load()`
  (`/proc/loadavg` on Linux, `uptime` elsewhere on Unix, `NA` on Windows)
  and `edi_tuning_machine_looks_busy(load_ratio_threshold = 0.5,
  calib_cv_threshold = 0.5, calib_reps = 15)` in `local_machine_tuning.R`.
  Two independent trip-wires, either suffices: 1-minute load average >
  0.5 × logical cores; or the IQR/median of 15 timings of one small fixed
  pure-R op (a 200×200 crossprod) > 0.5 — deliberately **not** "against a
  stored reference" as the TODO text sketched, because a stored absolute
  reference time is itself machine-dependent (the very thing this plan
  exists to escape); dispersion of a self-contained calibration is
  machine-relative and also works where load average is `NA`.
  `tune_EDI_for_this_machine()` gained `force = FALSE`: when busy,
  interactive sessions get a `[y/N]` prompt, non-interactive ones error
  with the reasons and the `force = TRUE` hint; applies under `dry_run` too
  (a dry run still benchmarks). **It fired for real during development** —
  this 12-core box at load 7.09 with calibration IQR/median 0.5–1.0 while
  another session ran builds — which both validated the thresholds as
  plausible and forced a test-hygiene change: the sandbox helper now stubs
  the guard to "idle" by default (every sandboxed test benchmarks via
  stubs, so contention is irrelevant to it), and the TODO-7 tests override
  that stub to exercise the busy path (non-interactive refusal, nothing
  written, `force = TRUE` proceeds, idle proceeds, `force` is a flag). The
  `edi_tuning_machine_looks_busy()` shape and threshold logic are unit-
  tested against the real function. Assembly suite now 137/137; harness
  68, axes 68, refactor 4 unchanged.
- [x] TODO-8: Correctness gate inside the tuner: for every cell where a
  non-default setting wins, re-fit once under both settings and assert
  estimates/CIs agree within solver tolerance before the deviation is
  accepted; any disagreement discards the deviation and logs it loudly.
  **DONE (2026-08-21).** New file `local_machine_tuning_correctness.R`.
  What is compared differs by axis, because what varies with the setting
  differs: cold start and optimizer algorithm change the fit path itself,
  so the comparable deterministic quantity is the point estimate
  (`compute_estimate()`); warm start only affects resampling replicates,
  not a fresh fit's point estimate, so that axis instead re-runs the
  actual resampling *operation* under both settings with the RNG reset to
  the identical seed immediately before each call
  (`inference_migration_with_seed()`) and compares every numeric value the
  call returns; parallel core count changes which RNG stream a forked
  worker uses, so a resampling CI is *expected* to differ and comparing it
  would manufacture false disagreements — the actual core-count-invariant
  quantity is the point estimate, so that axis compares that instead,
  exactly like cold start/optimizer. An output that can't be extracted as
  finite numerics (an error, empty, length-mismatched) is **unverifiable,
  not agreement** — discarded exactly like a real disagreement, since
  "could not check" is not evidence of safety.
  `edi_tuning_apply_correctness_gate(deviations, verify_fn, axis_label)` is
  the shared driver: kept vs. discarded, one loud `warning()` per discard
  naming the class/n and both compared values. Wired into
  `tune_EDI_for_this_machine()` right after all four axes finish and
  before diffs are built, so a discarded deviation never reaches
  `edi_tuning_build_policy_diffs()`/the file/the in-session apply; discards
  are exposed on the result via `n_discarded_by_correctness_gate` and
  `attr(x, "discarded_by_correctness_gate")`, and `print()` reports a
  nonzero count. Two small refactors this needed, both improving reused
  infrastructure rather than adding parallel logic: (1) factored the
  seed formula every axis's default `seed_fn` (and the parallel tuner's
  inline computation) already used into one `edi_tuning_default_seed()` in
  the harness file, so the gate's re-fit reproduces the *exact* same
  synthetic data the original benchmark saw — previously three copies of
  the same formula existed, a real drift risk once one changed; (2) fixed
  `edi_tuning_warm_start_run_setting()`, which was discarding the
  resampling operation's return value (`invisible(NULL)`) — now returns
  it, which `edi_tuning_interleaved_ab()`'s already-existing
  `results_a`/`results_b` capture (added for the optimizer axis's
  convergence guard) picks up for free, and which the correctness gate
  needs to compare. Tests: 35 new assertions in
  `test-local-machine-tuning-correctness.R` (agreement/tolerance edge
  cases; each `verify_*` function exercised against a real
  `InferenceCountPoisson` fit with `from == to`, confirming `agree =
  TRUE` is actually reachable, not just theoretically defined; the gate's
  keep/discard/warn logic with a mocked `verify_fn`), plus assembly
  coverage (a stubbed disagreeing deviation is discarded, warned about,
  excluded from the file, and counted/printed). One real test-design
  lesson along the way: an assembly test using fabricated stub deviations
  (`n = 50`, arbitrary class/n pairs not from a real timing race) hit the
  *real* correctness gate and was correctly discarded — `InferenceCountNegBin`'s
  jackknife estimate is genuinely `NA` at `n = 50`. That's the gate
  working as designed on unrealistic input, not a bug; fixed by stubbing
  the gate in tests whose purpose is diff-building/dry-run plumbing (the
  gate has its own dedicated tests), keeping concerns separated. Shared
  test helpers (`with_tuning_sandbox`/`with_stub`) were factored out of
  the assembly test file into `helper-local-machine-tuning.R` so both
  test files can use them. Final count: correctness 35, assembly 137,
  harness 68, axes 68, refactor 4 — all green.
- [x] TODO-9: `.onLoad()` import path in `EDI/R/zzz.R`: read, validate
  (schema version + `checkmate` on each diff), apply via setters, fail-open
  rules and the two `packageStartupMessage` cases (corrupt → re-run;
  fingerprint drift → suggest re-run). **DONE (2026-08-21).** Factored as
  `edi_tuning_import_saved_policies(quiet)` in
  `local_machine_tuning_persistence.R` (so it is directly testable without
  reloading the package), called from `.onLoad()` right after the
  single-threaded-by-default `set_package_threads(1L)`. Returns a status:
  `"skipped"` (new `EDI_SKIP_LOCAL_TUNING=1` env var — CI/debugging escape
  hatch), `"none"` (no file: silent no-op), `"invalid"` (unreadable or
  incompatible `schema_version`: ignored + one `packageStartupMessage`),
  `"error"` (the TODO-6 gate or a setter rejected a diff: ignored + one
  message, **and every policy reset to shipped defaults so a part-applied
  diff can never leave a mixed state** — the cold-start diff that had
  already applied before a malformed warm-start diff errored is verifiably
  rolled back), `"applied"`, or `"applied_hardware_changed"` (logical core
  count or CPU model differs from the saved fingerprint: still applied,
  plus a message suggesting a re-run). Never errors at load. The parallel
  diff stays recorded-only — verified the import never changes
  `get_num_cores()`. Validation is schema + structural (the diffs are lists
  in setter shape) with the setters' own `checkmate` asserts as the
  per-diff check, exactly as the TODO text asks. Tests: 9 new in
  `test-local-machine-tuning-assembly.R` (now 116/116) — none/skip/valid/
  hardware-mismatch/bad-schema/unreadable/apply-error-with-rollback/
  untunable-refused-with-rollback/core-count-untouched; the test sandbox
  now also resets the three policies on *entry*, since a developer machine
  with a real saved config would otherwise start tests from non-shipped
  state once this hook exists. Note for TODO-10/11: `library(EDI)` on the
  user's *current* install predates this `zzz.R` edit, so the hook is only
  live after their next install (verified here via `load_all()`, which
  runs `.onLoad()`).
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
