# Hardening `InferenceSuite$run_all_inference()`'s `num_cores` Testing (and Its Fork-Cluster Path)

> **Depends on:** nothing blocking scoping/investigation (TODO-1..3 below).
> TODO-4 (root-cause fork-safety fix) and TODO-5 (wall-clock kill-on-timeout
> for the fork-cluster path) touch `inference_suite.R`'s C++-adjacent
> parallel-worker code and should be scheduled as their own small
> implementation pass, not folded into an unrelated change. (Global
> ordering: see `_master.md`.)

Written 2026-08-21.

## Purpose

On 2026-08-21, every leg of the `R-CMD-check` matrix (macOS, Windows, 3x
Ubuntu, plus `R-CMD-check-sanitizers`) hung in "checking tests" until its own
`timeout-minutes` killed the job. Root-caused to
`test-inference-suite-run-all-inference.R`'s `"run_all_inference: num_cores >
1 fits in parallel and produces identical rows to sequential"` test:
`InferenceSuite$run_all_inference(num_cores = 2)` forks via
`parallel::makeForkCluster()` (`inference_suite.R`, the `use_fork_cluster`
branch) after the test suite has already run many OpenMP-parallel C++
kernels (`src/` is pervasively `_OPENMP`-gated) — forking while another
thread holds an OpenMP/malloc-arena lock is a classic deadlock, since the
forked child inherits that lock in a state that can never be released.
`clusterApply()` then blocks forever, and because it never returns, the
`on.exit(stopCluster())` registered right after `makeForkCluster()` never
runs either — there is no code path back to cleanup once this happens.

As an immediate stopgap, that one test now carries `skip_on_ci()` (in
addition to the pre-existing `skip_on_cran()` / `skip_on_os("windows")` /
`skip_if_prepush_no_parallel()`), so CI no longer hangs. **This plan is the
follow-up**: `skip_on_ci()` removes coverage of the parallel path everywhere
except an ad hoc local run, and does nothing for a real user who hits the
same deadlock outside of testing. The goal is a testing (and, where in
scope, library) structure where both `num_cores = 1` and `num_cores > 1` are
soundly covered — correctness always, real fork behavior wherever it's safe
to exercise it.

## Non-Goals

- Not a rewrite of `run_all_inference()`'s aggregation/reporting logic —
  that's covered by the many non-parallel tests already in
  `test-inference-suite-run-all-inference.R` and out of scope here.
- Not a general audit of every other `skip_if_prepush_no_parallel()`-guarded
  test (the mirai fork-cluster tests in
  `test-simulation-framework-parallel-cleanup.R`, etc.) — those carry the
  same theoretical CI risk per `helper-prepush-no-parallel.R`'s own comment,
  but only the `num_cores` test has a *confirmed* CI hang as of this
  writing. TODO-6 below scopes whether/how to extend this plan's findings to
  them.
- Not committing to a specific timeout mechanism up front — TODO-5 is
  investigation-first, since `setTimeLimit()` (already used for the
  sequential path's `max_secs_per_class`) cannot reach into a deadlocked
  child process; whatever replaces it needs real thought before landing.

## Problem Statement

Today, coverage of the two `num_cores` paths is lopsided:

- **`num_cores = 1` (sequential):** well covered.
  `"max_secs_per_class actually interrupts a slow R-level fit"` verifies the
  one real hazard on this path (a slow-but-alive fit) via `setTimeLimit()`,
  which *can* interrupt R-level computation in the same process. Safe to run
  everywhere, including CI.
- **`num_cores > 1` (fork cluster):** the only test that exercises real
  parallel fitting now skips on CRAN, Windows, local pre-push, *and* CI —
  meaning in practice it only ever runs when a developer opts in locally
  with `EDI_PREPUSH_NO_PARALLEL=false`. No automated system runs it
  regularly. And even when it does run, a hang there is unbounded: no
  wall-clock guard exists on the fork-cluster branch, and the standard
  `on.exit()` cleanup is unreachable once `clusterApply()` deadlocks.

Two separable problems live in that gap:

1. **Test coverage gap:** correctness of the parallel path (does
   `num_cores = 2` produce the same rows as `num_cores = 1`?) has no regular
   automated check anywhere.
2. **Library robustness gap:** `run_all_inference(num_cores > 1)` itself has
   no bound on how long it can hang, and no way to recover cleanly if it
   does — this affects real users, not just CI.

## Implementation TODOs

- [ ] TODO-1: **Split correctness from OS-fork risk.** Add a test-double /
  injection point so `run_all_inference()`'s parallel *aggregation* logic
  (task splitting, result-list reassembly, row ordering, name matching) can
  be verified without spinning up a real `makeForkCluster()` — e.g. a
  parameter or internal hook that swaps `clusterApply()` for a plain
  `lapply()` over the same `tasks`/`worker_fn` while still exercising the
  `use_fork_cluster = TRUE` code path's *surrounding* logic (task building,
  result reassembly, screen output). This gets `num_cores > 1`'s
  non-fork-related correctness back under safe, always-on CI coverage
  immediately, independent of TODO-4/TODO-5.
- [ ] TODO-2: **Add a test-level wall-clock guard as an interim safety net.**
  Independent of any library change, wrap the real-fork-cluster test itself
  (once it's allowed to run somewhere automated again) in a hard timeout at
  the test level (e.g. `R.utils::withTimeout()` around the
  `run_all_inference(num_cores = 2)` call, or a short-lived background
  watchdog that kills the test's own R process group on expiry) so a
  regression in the fork-safety fix (TODO-4) fails fast in whatever
  environment runs it, instead of consuming a full CI job timeout again.
  This is cheap and worth doing regardless of how far TODO-4/TODO-5 land.
- [ ] TODO-3: **Decide where the real-fork test runs.** Once TODO-1 and
  TODO-2 land, re-evaluate `skip_on_ci()` on the original test: either (a)
  keep it CI-skipped permanently and treat it as a local/manual-only check
  (matching `helper-prepush-no-parallel.R`'s existing philosophy for
  worker-spawning tests), or (b) re-enable it in CI once TODO-4 and/or
  TODO-5 make a hang bounded and recoverable. Prefer (b) if TODO-4 succeeds
  (a real fork-safety fix removes the hazard, not just its symptom in CI);
  fall back to (a) otherwise.
- [ ] TODO-4: **Investigate a root-cause fork-safety fix.** Leading
  candidate, found while scoping this plan: `run_all_inference()`'s
  fork-cluster branch calls raw `parallel::makeForkCluster(num_cores)`
  directly (`inference_suite.R`), instead of the package's own
  `make_configured_fork_cluster()` (`globals.R`) — the shared helper behind
  `set_num_cores()`/`get_global_fork_cluster()` that already caps
  OMP/BLAS/data.table thread counts to 1 on every worker via
  `clusterCall()` right after creation, retries alternate ports, and falls
  back to a PSOCK cluster if forking fails outright. `local_machine_
  optimization.md`'s own real 2-core fork-cluster tests (via this same
  helper) report stable, hang-free reruns, which is evidence the shared
  path is *not* what's deadlocking — `run_all_inference()`'s bypass of it
  is a real suspect, independent of (and cheaper to try first than) an
  OpenMP-thread-pool-teardown fix. Two things to check: (a) does switching
  `run_all_inference()` to `make_configured_fork_cluster()` alone clear the
  hang (the post-fork `OMP_NUM_THREADS=1` it sets on workers wouldn't stop
  a deadlock caused by a lock held *at fork time* in the parent — so this
  may only be a partial fix); (b) if not, the standard pattern for safely
  combining OpenMP with `fork()` is ensuring no OpenMP worker threads are
  alive (or holding locks) in the parent at fork time — e.g. an OpenMP
  thread-pool teardown/barrier immediately before the fork, restored after.
  Scope a small spike to confirm before committing to TODO-5's
  timeout-based mitigation as the primary fix rather than a
  belt-and-suspenders backstop.
  **In progress (2026-08-22, user decision):** (a) implemented —
  `run_all_inference()`'s fork-cluster branch now calls
  `make_configured_fork_cluster(num_cores)`. Verification attempted locally
  first: full/partial `num_cores=1` vs. `num_cores=2` comparisons both timed
  out mid-*sequential* run (this sandbox is too resource-constrained to fit
  bootstrap-CI classes in reasonable time — inconclusive, not a hang
  signal); a lighter isolated repro (one OpenMP kernel call, then
  `make_configured_fork_cluster(2)` + `clusterApply()` directly) completed
  in 0.5s with no hang, but is lighter than the real failure conditions
  (dozens of prior OpenMP-heavy tests before the fork). Real verification
  now running as a CI canary: `skip_on_ci()` removed from the `"num_cores >
  1"` test (with a best-effort `setTimeLimit(90)` safety net added so a
  repeat hang fails fast instead of re-burning the job timeout — see that
  test's own comment in `test-inference-suite-run-all-inference.R`). Next
  push's CI result decides this TODO: pass → mark done, keep
  `skip_on_ci()` removed; hang/timeout → (a) alone is insufficient, re-add
  `skip_on_ci()` and proceed to (b).
- [ ] TODO-5: **Add a wall-clock timeout + forced kill around the
  fork-cluster path**, as a backstop regardless of TODO-4's outcome.
  `setTimeLimit()` doesn't reach into child processes, so this needs real
  OS-level process management — e.g. track each worker's PID and use
  `tools::pskill()` (or platform equivalent) to force-terminate on timeout,
  replacing the single blocking `clusterApply()` call with a polling loop
  (`parallel::mccollect(wait = FALSE, timeout = ...)`-style) that can bail
  out. On timeout, surface a `status = "timeout"`/`"error"` row per
  in-flight task (matching the sequential path's existing `"timeout"`
  status convention) instead of hanging — and make sure the forced kill
  itself can't hang (don't reuse `stopCluster()` for this, since it also
  talks to the workers it's trying to stop; see the 2026-08-21 investigation
  for why that's exactly what fails during a real deadlock). Higher risk of
  introducing a subtle regression (orphaned resources from a mid-computation
  kill, e.g. open handles from forked copy-on-write memory) — needs its own
  careful design and review, not a quick patch.
- [ ] TODO-6: **Decide whether this plan's findings extend to the other
  `skip_if_prepush_no_parallel()`-guarded tests** (mirai fork-cluster tests
  in `test-simulation-framework-parallel-cleanup.R`, etc.), which carry the
  same theoretical CI hang risk per `helper-prepush-no-parallel.R`'s
  comment but have no *confirmed* CI hang yet. If TODO-4's fork-safety
  investigation generalizes, apply it there too; otherwise, audit each for
  whether it needs its own `skip_on_ci()` before it produces its own
  multi-hour CI incident.

## Related

- `helper-prepush-no-parallel.R` — existing skip-guard infrastructure for
  worker-spawning tests; its comment describing the local pre-push hang
  mechanism (orphaned workers, `sink()` not propagating) is the same failure
  class investigated here, just previously believed to be local-only.
- `inference_suite_plan.md` — `run_all_inference()`'s owning plan; TODO-4/
  TODO-5 above are follow-up work against that same function, not a new
  feature, so should reference this plan rather than duplicate the
  `num_cores` design discussion into that doc.
