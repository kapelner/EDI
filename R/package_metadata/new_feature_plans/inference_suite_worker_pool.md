# InferenceSuite: Long-Lived Worker Pool Instead of One Fork per Task

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Depends on:** `release_v1_1_0.md → TODO-48` (2), which provides
> `seed_for_index` and the worker-count invariance tests. Coordinate with
> `TODO-18` (`consolidate_parallelization_code.md`), which extracts the
> worker single-threading setup this pool reuses. Release: v1.1.0
> (`release_v1_2_0.md → TODO-32`). Found by
> `../audits/further_optimizations.md → section 3, "InferenceSuite's
> per-task fork roughly doubles its CPU"` (2026-10-15).

Date: 2026-10-15

**Goal:** Cut `run_all_inference(num_cores > 1)`'s CPU roughly in half by
running tasks on `num_cores` long-lived workers instead of forking a fresh
child per task. Keep what the per-task fork gives today: a per-task
`max_secs_per_class` kill by PID that affects no other task, and no
cluster-protocol cleanup step that a hung worker can block.

## The finding

`run_all_inference_fork_dispatch()` (`R/EDI/R/inference_suite.R`) forks
one `parallel::mcparallel()` child per task, at most `num_cores` at once.
Measured 2026-10-15 on the installed PGO R: continuous response,
`DesignFixedBernoulli`, n = 200, three covariates, all applicable classes
(7 classes, 154 tasks).

| Run | Wall | CPU | Sum of `fit_secs` |
|---|---|---|---|
| Fork dispatch, `num_cores = 4` | 94.6 s | 369 s | 258 s |
| Same tasks in-process, serial | 170 s | 170 s | 169 s |
| Four in-process copies at once (same contention, no forks) | ~194 s each | ~194 s each | 190–195 s |

- About 175 s of CPU is fork overhead: 1.1 s per task, against a median
  task of 0.5 s.
- Most of it is user time. An empty fork costs 8–9 ms. A fork whose child
  runs one `gc()` costs 380–480 ms (220–310 ms system time, copy-on-write).
  Lazily loaded namespaces are not the cause (quantreg, SparseM and
  MatrixModels, 0.12 s in total).
- Untested hypothesis: caches on the shared design object are built once
  in-process but rebuilt in every child. TODO-1 checks this before any
  code changes.
- Fork mode still wins on wall time (94.6 vs 170 s), so the fix is a
  pool, not in-process execution.
- Fork and in-process runs differ in bootstrap and randomization rows.
  Each `mcparallel()` child is reseeded independently, so today's results
  at `num_cores > 1` depend on scheduling. TODO-48 forbids that.

Rough estimate, not measured: about 194 s of CPU over four workers, so
50–60 s of wall time, with the largest task (25 s) as the tail.

## Design

- **Workers.** Fork `num_cores` workers once, after a warm-up in the parent
  that loads the namespaces the task list needs. Each worker runs the
  same single-threading setup as `configured_worker_fn()` today (shared
  with `TODO-18`'s extracted helper), then loops: read a task, run it,
  send the result row back.
- **Dispatch.** A rolling window like `SimulationFramework`'s mirai path:
  a worker gets its next task as soon as it returns a result. The parent
  polls without blocking.
- **Timeouts.** A task past `max_secs_per_class` is killed by PID
  (`tools::pskill(pid, tools::SIGKILL)`). Its connection is closed
  without any protocol handshake, it gets a timeout row as today, and a
  fresh worker is forked in its place. Other workers are unaffected.
- **Seeding.** Each task sets its seed from `seed_for_index(task index)`
  before it runs, so results do not depend on worker count or scheduling.
  This changes bootstrap and randomization draws at `num_cores > 1` and
  must be documented as a draw change.
- **Per-task state.** A worker runs many tasks, so state that one task
  leaves on the shared design object is seen by the next. This is the
  benefit (shared caches), but it must not change results. TODO-1 lists
  what persists, and the gate below checks it.
- **OpenMP after fork.** Workers are forked from the parent, so the parent
  must not have started an OpenMP thread pool before forking (the hazard in
  `parallel_fork_cluster_test_safety.md`). The warm-up stays R-only, or
  the pool is forked before it.
- **Mechanism.** Choose in TODO-2 between (a) `parallel::makeForkCluster()`
  nodes driven one at a time with `socketSelect()`, with node PIDs
  collected once at startup, and (b) `parallel:::mcfork()` children
  reading tasks from a pipe. Avoid `clusterApply()` and `stopCluster()`
  for the reasons in `run_all_inference_fork_dispatch()`'s `@details`.

## TODOs

- [ ] TODO-1: **Confirm the cause.** Profile one forked child against the
  same task in-process (`Rprof` in both; `perf` if needed). List the state
  that persists on the design object between tasks. If the cause is not
  cache rebuilding, revise the estimate above before TODO-2.
- [ ] TODO-2: **Pool.** Implement the design above as a replacement for
  `run_all_inference_fork_dispatch()`, keeping its signature and return
  contract. Choose the mechanism and record why.
- [ ] TODO-3: **Timeout and crash.** A hung task (an injected sleep in
  compiled code) is killed at `max_secs_per_class`, recorded as a timeout
  and replaced, and the other tasks finish. A worker that dies (an injected
  SIGSEGV) is recorded as an error row and replaced.
- [ ] TODO-4: **Seeding.** Seed each task with `seed_for_index`. Add the
  `num_cores = 1 / 2 / 4` invariance test for `run_all_inference()` to
  `TODO-48`'s registry-driven suite. Document the draw change in NEWS.
- [ ] TODO-5: **Measure.** Rerun the workload above on the same machine and
  report wall time, CPU and system time against the 2026-10-15 numbers.
  Use `TODO-4b`'s noise-floor harness if it has landed.

## Gate

- `run_all_inference()` results identical (`identical()` on every column
  except `fit_secs`) across `num_cores = 1, 2, 4`, for every response type.
- The `max_secs_per_class` and crash tests in TODO-3 pass.
- The existing `run_all_inference` tests pass unchanged, including the
  `EDI_TESTING_DISABLE_FORK_CLUSTER` path.

## Standing constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
  `load_all()` without `compile = FALSE`.** See the repo `CLAUDE.md`. This
  plan changes R code only.
