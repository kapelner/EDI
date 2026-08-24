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

- [x] TODO-1: **Split correctness from OS-fork risk.** **Done (2026-08-24):**
  `run_all_inference()`'s `use_fork_cluster` branch now checks
  `Sys.getenv("EDI_TESTING_DISABLE_FORK_CLUSTER")` (internal, never set
  outside tests — same env-var-hook convention as
  `EDI_VALIDATE_INFERENCE_CONTRACTS`/`EDI_REQUIRE_SHALLOW_*_HIERARCHY`
  elsewhere in the package); when `"true"`, `lapply(tasks, worker_fn)` runs
  in-process instead of `make_configured_fork_cluster()` +
  `clusterApply()`, exercising the identical task-building/result-
  reassembly/screen-output logic with zero OS-level forking. New always-on
  test added right after the real-fork test in
  `test-inference-suite-run-all-inference.R` (`withr::local_envvar()`,
  no `skip_on_ci()`/`skip_on_os()`/`skip_if_prepush_no_parallel()` needed
  since nothing forks) asserts `num_cores = 1` vs. `num_cores = 2` rows
  match, same assertion shape as the real-fork test. **Verification
  caveat:** could not run this test to completion locally — this sandbox
  times out (3 attempts, up to 180s) on `run_all_inference()`'s per-class
  randomization/exact-CI search even sequentially, for classes with or
  without bootstrapping, independent of forking (same environmental
  limit noted under TODO-4). Correctness is established by code review
  instead: both branches call the identical `worker_fn` closure over the
  identical `tasks` list and feed the identical `names(results_list) =
  names(results); results = results_list` downstream — `lapply()` and
  `clusterApply()` differ only in execution engine (in-process vs. forked
  workers), not in the value or order they return for a pure, order-
  preserving `worker_fn`. Real confirmation should come from the next CI
  run once it reaches this test.
- [x] TODO-2: **Add a test-level wall-clock guard as an interim safety net.**
  **Done (2026-08-22):** `setTimeLimit(elapsed = 90, transient = TRUE)` (with
  `on.exit()` reset) added around the `"num_cores > 1"` test's body in
  `test-inference-suite-run-all-inference.R`, alongside removing
  `skip_on_ci()` for the canary. Explicitly best-effort, not proven — the
  2026-08-23 canary run never reached this test at all (see TODO-4's
  status note), so the guard has not yet been exercised against a real
  fork deadlock. `R.utils::withTimeout()` wasn't used since `setTimeLimit()`
  is already the trusted, dependency-free pattern this file's
  `"max_secs_per_class"` test uses for the same purpose.
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
- [x] TODO-5: **Add a wall-clock timeout + forced kill around the
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

  **Done (2026-08-24).** `run_all_inference()`'s fork-cluster branch
  (`inference_suite.R`) no longer calls `make_configured_fork_cluster()` +
  `parallel::clusterApply()` at all (superseding TODO-4's approach (a) at
  this one call site — see the note at the end of this entry). It now goes
  through a new `run_all_inference_fork_dispatch()`: each task is forked as
  its own **independent, one-shot child** via `parallel::mcparallel()`
  (same underlying `fork()` primitive, no persistent cluster/socket layer
  on top), giving every task a real, individually-trackable PID. A
  bounded-concurrency scheduling loop keeps at most `num_cores` children
  alive, polling non-blockingly (`parallel::mccollect(wait = FALSE, timeout
  = 0.2)`) for completions every ~0.2s. A task whose child has run longer
  than `max_secs_per_class` (the existing sequential-path parameter,
  reused unchanged — no new differently-named parameter) is force-killed
  by raw PID (`tools::pskill(pid, tools::SIGKILL)`, then a short
  `mccollect(wait = TRUE, timeout = 5)` purely to reap the zombie) and
  replaced with a `run_all_inference_fork_timeout_row()` — same field set
  as `run_all_inference_one_class()`'s row, `status = "timeout"`, message
  naming the exceeded budget.

  **Why `mcparallel`/`mccollect` instead of the suggested
  `clusterApply()`-polling-loop shape, and the resulting answers to the
  "does a kill poison the cluster" question:** with a shared
  `makeForkCluster()` cluster, there's no way to kill one in-flight task's
  handler without also risking the shared socket/pipe connection the
  *other* concurrently-running tasks on that same persistent worker
  process are using — a single force-kill really could poison the whole
  cluster, and answering "can it still be used for the next class"
  honestly requires a full teardown-and-recreate either way. Switching to
  one independent forked child per task sidesteps the question entirely:
  there is no shared cluster object to poison. Killing one task's PID has
  **zero effect** on any other task — concurrently-running siblings are
  separate processes with their own pipes, and not-yet-dispatched tasks
  simply fork fresh children later, unaffected. The only resource a forced
  kill can leak is that one child's own open handles / partially-written
  copy-on-write memory, all private to that process — the OS reclaims all
  of it the instant the process exits, same as any other killed process;
  nothing is shared with the parent or siblings to clean up. This also
  answers the "forced kill can't itself hang" requirement structurally,
  not just procedurally: `tools::pskill()` is a raw kernel signal
  requiring zero cooperation from the (possibly deadlocked) target, unlike
  `stopCluster()`'s protocol handshake — the exact mechanism the 2026-08-21
  incident got stuck inside.

  Each forked child sets the same single-thread env vars/options
  `make_configured_fork_cluster()`'s `clusterCall()` sets on persistent
  cluster workers (`OMP_NUM_THREADS` etc., `data.table`/`fixest` thread
  caps) — but does so via `Sys.setenv()`/`options()` *inside the child
  only*, right after the fork, before real work starts, so it needs no
  `clusterCall()`-style round trip and never mutates the parent's
  environment.

  **A real bug found and fixed while writing the first standalone test**
  (not anticipated by this TODO's text): the completion-draining helper
  (`drain_finished()`, nested inside the dispatcher) removed a finished
  job from the live-jobs tracking list with a plain `jobs[[slot]] = NULL`
  instead of `jobs[[pid]] <<- NULL` — inside a nested closure, plain `=`
  creates a *local* shadow of `jobs` rather than mutating the enclosing
  scheduler's list, so completed jobs were silently never actually removed
  from the live set. Symptom: in a 4-task/2-core repro (2 fast tasks, 1
  deliberately-hung task, 1 more fast task), **every task** — including
  the three that finished correctly in well under a second — ended up
  reported as `status = "timeout"`, because the timeout-checker later
  iterated the same stale, never-shrinking job list and overwrote their
  already-correct `results[[idx]]` entries with bogus timeout rows once
  enough wall-clock time had passed. Fixed by super-assigning the removal
  (`jobs[[pid]] <<- NULL`, collected into a small `drained_pids` vector
  first so the removal doesn't mutate the list mid-iteration). This is
  exactly the class of "silently wrong, not just missing" bug the "leave
  it honestly unimplemented rather than ship a guess" standing instruction
  in this plan/session exists to catch — caught here by actually running
  a repro rather than trusting the code by inspection.

  **Verification:** package loads cleanly
  (`pkgload::load_all(compile = FALSE)`) and `run_all_inference_fork_dispatch()`
  was exercised directly (bypassing the full `InferenceSuite`/real-class
  machinery, which this sandbox has repeatedly been too resource-constrained
  to run to completion — see TODO-1/TODO-4's own notes) with a 4-task/
  2-core repro (3 fast test-double tasks + 1 deliberately `Sys.sleep(30)`
  task, `max_secs_per_class = 2`): total wall-clock 2.44s (not 30s), the
  three fast tasks reported `status = "ok"` with their correct estimates
  intact, the hung task reported `status = "timeout"` with a message
  naming the force-kill, and a post-run process check found zero zombie/
  orphaned processes. Two `testthat` tests added (mirroring this repro,
  plus a `max_secs_per_class = NULL` never-kills case) directly below the
  existing real-fork `"num_cores > 1 fits in parallel..."` test in
  `test-inference-suite-run-all-inference.R`, gated the same way (
  `skip_on_cran()`/`skip_on_os("windows")`/`skip_if_prepush_no_parallel()`
  — still real OS-level forking, same risk profile as the existing
  real-fork test). **Could not run these two new tests via
  `testthat::test_file()`** in this pass — an unrelated concurrent change
  elsewhere in the tree (`inference_ordinal_stereotype_logit.R`, a
  different class entirely, not touched here) broke `pkgload::load_all()`
  partway through this pass; per this session's standing no-unrequested-
  fixes policy, that wasn't debugged. The direct-invocation repro above
  (run successfully *before* that unrelated breakage appeared) exercises
  the exact same function the two new tests call, so this is considered
  sufficient evidence the implementation is correct, but re-running
  `testthat::test_file("tests/testthat/test-inference-suite-run-all-inference.R")`
  once the tree is stable again is the recommended final confirmation
  step for whoever picks this up next.

  **Interaction with TODO-3/TODO-4 (left as-is per this pass's directive,
  noted here for whoever owns those):** TODO-4's approach (a) — switching
  `run_all_inference()`'s fork-cluster branch to
  `make_configured_fork_cluster()` — is now moot at this specific call
  site: this TODO's dispatcher rewrite replaces that call entirely with
  the `mcparallel`-based scheduler above, which needs no persistent
  cluster object (and therefore no port-retry/PSOCK-fallback logic
  `make_configured_fork_cluster()` provides — deliberately not
  reimplemented here, since `mcparallel()` doesn't need a listening
  socket/port at all). TODO-3's pending "keep `skip_on_ci()` off or put it
  back" decision for the original real-fork test is unaffected by this
  change one way or the other — that test still creates real fork
  children via the same dispatcher, so it's still real signal about
  whether OS-level forking is safe to exercise on CI's machines — but the
  practical stakes of that decision are now lower: even if a future hang
  recurs there (or anywhere else that forks after OpenMP kernels have
  run), it can no longer block the whole job or leave orphaned processes
  behind the way the 2026-08-21 incident did, because this dispatcher
  bounds and recovers from it. Not this pass's call to make, so left
  exactly as TODO-3 already states it.

- [x] TODO-6: **Decide whether this plan's findings extend to the other
  `skip_if_prepush_no_parallel()`-guarded tests** (mirai fork-cluster tests
  in `test-simulation-framework-parallel-cleanup.R`, etc.), which carry the
  same theoretical CI hang risk per `helper-prepush-no-parallel.R`'s
  comment but have no *confirmed* CI hang yet. If TODO-4's fork-safety
  investigation generalizes, apply it there too; otherwise, audit each for
  whether it needs its own `skip_on_ci()` before it produces its own
  multi-hour CI incident.

  **Done (2026-08-24).** Audited every `skip_if_prepush_no_parallel()`-
  guarded test (4 files: `test-bayesian-bootstrap.R`,
  `test-inference-suite-run-all-inference.R` — this plan's own subject,
  `test-simulation-framework-parallel-cleanup.R`,
  `test-simulation-framework-extended.R`) by tracing each one's actual
  process-spawning mechanism, not just its file location — **this plan's
  own TODO-6 text named the wrong tests as the likely-hazardous ones**
  ("mirai fork-cluster tests in `test-simulation-framework-parallel-
  cleanup.R`"): mirai does not use `fork()` at all. `mirai::daemons()`
  spawns independent background processes via a subprocess-exec mechanism
  (a fresh process image, not a copy-on-write memory fork of the calling
  process), so a mirai daemon never inherits the calling process's
  OpenMP-thread-pool/malloc-arena lock state the way `parallel::
  makeForkCluster()`'s `fork()` does — the specific mechanism behind this
  whole plan's root cause structurally cannot occur there. Confirmed 3
  mirai-backed tests are safe on this basis and left untouched:
  `test-bayesian-bootstrap.R`'s "matches mirai-backed parallel execution"
  and `test-simulation-framework-extended.R`'s "supports mirai-backed
  replication parallelism" (both pass `force_mirai = TRUE`, never touch a
  fork cluster), and `test-simulation-framework-parallel-cleanup.R`'s
  "mirai use blocks later fork clusters in the same R session" (its one
  `set_num_cores(2L)` call at the end is wrapped in `expect_error()` —
  it's asserting that call fails before any real fork happens, so no fork
  cluster is ever actually created by this test either).

  **The real, previously-unflagged hazard: `SimulationFramework$run()`'s
  own fork-cluster branch** (`simulations_framework.R`, `use_fork_cluster`
  block) calls **raw `parallel::makeForkCluster(num_cores)` directly** —
  not even wrapped by the package's own `make_configured_fork_cluster()`
  helper (unlike `run_all_inference()`'s pre-TODO-5 state), so it's
  missing even the thread-capping/port-retry hardening that helper
  provides, on top of carrying the identical fork-after-OpenMP-lock hazard
  shape as the confirmed 2026-08-21 incident. Two tests create a real fork
  cluster this way: `test-simulation-framework-extended.R`'s "SimulationFramework
  supports parallel execution" (fork branch entered directly, `num_cores =
  2`, `mirai_already_used` false) and `test-simulation-framework-parallel-
  cleanup.R`'s "SimulationFramework restores parallelism settings" (its
  setup line `set_num_cores(2L, ...)` creates a real fork cluster via
  `make_configured_fork_cluster()`, even though the simulation itself then
  runs with `num_cores = 1`).

  **Decision: option (b), not (a) or (c).** Applying TODO-5's full
  `mcparallel`/`mccollect`-scheduler treatment to
  `SimulationFramework$run()`'s fork-cluster path is out of scope for this
  pass — it's a materially larger, more interleaved code path (a two-phase
  cache-then-replication fork-cluster lifecycle, not one flat task list)
  that, per this plan's own standing caution about TODO-5, "needs its own
  careful design and review, not a quick patch." Doing nothing (option c)
  isn't right either: the hazard is real and structurally identical to a
  confirmed incident, just not yet observed here. **Applied `skip_on_ci()`
  to both tests** (proportionate to "audit each for whether it needs its
  own `skip_on_ci()` before it produces its own multi-hour CI incident,"
  exactly as this TODO's text allows for a real-but-not-yet-this-plan's-
  full-treatment hazard), each with an inline comment naming the mechanism
  and pointing at a future dedicated TODO-5-style pass for
  `simulations_framework.R` as the real fix. Verified both edited test
  files parse cleanly (`parse()`); could not run them to completion in
  this pass for the same unrelated-breakage reason noted under TODO-5.

## Related

- `helper-prepush-no-parallel.R` — existing skip-guard infrastructure for
  worker-spawning tests; its comment describing the local pre-push hang
  mechanism (orphaned workers, `sink()` not propagating) is the same failure
  class investigated here, just previously believed to be local-only.
- `inference_suite_plan.md` — `run_all_inference()`'s owning plan; TODO-4/
  TODO-5 above are follow-up work against that same function, not a new
  feature, so should reference this plan rather than duplicate the
  `num_cores` design discussion into that doc.
