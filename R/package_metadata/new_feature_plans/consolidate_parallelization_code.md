# Consolidating Duplicated Parallelization Primitives

> **Depends on:** nothing; pure internal refactor, no dependency on the
> Phase 0 decision batch. **Does not depend on, and does not attempt,**
> `parallel_fork_cluster_test_safety.md`'s still-open TODO-6 note (a future
> `mcparallel`/`mccollect`-scheduler hardening pass for
> `SimulationFramework$run()`'s fork-cluster path) — that is a fork-after-
> OpenMP-lock *safety* fix, materially larger in scope, and explicitly
> deferred there to its own pass. This plan is scoped to duplication/drift
> cleanup only. (Global ordering: see `_master.md`.)

Written 2026-09-07.

## Purpose

EDI branches parallelization backend (fork cluster on \*nix, `mirai` on
Windows or when a fork cluster isn't available/safe) in several
independent places. An investigation (2026-09-07) into whether to
decompose this into one shared "threadpool" abstraction found that a
reusable, generic primitive already exists and is already shared
(`Inference$par_lapply`, `inference_all_abstract.R:726-838`, reused by
~10 bootstrap/randomization `Inference` subclasses via
`effective_parallel_cores()`), backed by shared construction/lifecycle
helpers in `globals.R` (`make_configured_fork_cluster()`,
`start_mirai_daemons_bounded()`, `set_num_cores()`,
`get_global_fork_cluster()`/`get_global_mirai_cores()`).

Two call sites do **not** use `par_lapply` and hand-roll their own
backend selection and cluster/daemon lifecycle instead —
`SimulationFramework$run()` (`simulations_framework.R:833-1970`) and
`InferenceSuite$run_all_inference()`/`run_all_inference_fork_dispatch()`
(`inference_suite.R:4763-5182`, `:1318-1420`). Both diverge for real,
documented reasons (see Problem Statement), not oversight, so this plan
does **not** propose merging them into `par_lapply` or into one shared
"threadpool class." What it does propose: the two divergent sites still
duplicate several *sub-pieces* of backend plumbing between themselves and
against the shared layer, and those copies have already drifted apart
(one has a bugfix/retry loop the other one lacks). That duplication is a
real, low-risk-to-fix maintenance hazard independent of the
scheduler-shape question. This plan extracts those sub-pieces into single
shared implementations.

## Non-Goals

- **Not a unified "threadpool" class or interface** across `par_lapply`,
  `SimulationFramework$run()`, and `InferenceSuite$run_all_inference()`.
  The 2026-09-07 investigation's conclusion: these are three genuinely
  different consumer contracts, not three implementations of one
  contract — (1) `par_lapply`'s stateless, one-shot chunked map over a
  reusable cluster; (2) `SimulationFramework`'s stateful persistent pool,
  with cell-state/design caches pushed into worker global state *once*
  via fork copy-on-write or `mirai::everywhere()`, then many cheap
  fine-grained (rep, cell) dispatches against that pre-loaded state via a
  bespoke rolling-window async scheduler; (3) `InferenceSuite`'s
  requirement for OS-level, PID-granular force-kill of an individual
  hung task with zero blast radius on siblings — a guarantee that is
  structurally incompatible with *any* shared cluster/daemon-pool object
  (fork or mirai), since both need a cooperative worker to tear down
  cleanly. Forcing these into one class would either sprout per-case mode
  flags (recreating today's complexity in one place) or leak abstraction
  (copy-on-write state-pushing and PID tracking are not generic
  "submit task" concerns). See `parallel_fork_cluster_test_safety.md`'s
  TODO-5 for the incident (2026-08-21 CI hang) that is the reason
  `InferenceSuite`'s contract (3) exists in the first place.
- **Not** `parallel_fork_cluster_test_safety.md`'s deferred TODO-6 work
  (root-cause fork-after-OpenMP-lock safety hardening for
  `SimulationFramework$run()`'s fork-cluster path, matching
  `run_all_inference_fork_dispatch()`'s `mcparallel`/PID-kill treatment).
  That plan's own TODO-6 explicitly scoped this out as "a materially
  larger, more interleaved code path... needs its own careful design and
  review, not a quick patch," and applied `skip_on_ci()` to the two tests
  that exercise the hazard as an interim stopgap. This plan does not
  touch that stopgap or attempt the safety fix; if that work happens, do
  it as its own pass, informed by (but not blocking on) this plan's
  primitives extraction.
- **Not a behavior or output change anywhere.** Every TODO below is a
  refactor: same backend selection, same thread limits, same daemon
  counts, same kill semantics — just one implementation instead of two or
  three. Bit-for-bit on every path.
- **Not touching `InferenceSuite`'s `mcparallel`/PID-kill dispatcher's
  core kill/poll logic.** It is deliberately independent of any shared
  cluster object (that independence is the point); TODO-3 below only
  extracts the *worker single-threading setup* the dispatcher's children
  run at startup, not its scheduling/kill loop.

## Problem Statement

Three concrete pieces of backend plumbing are duplicated, and have
already drifted:

1. **Two inconsistent mirai-daemon-lifecycle implementations.**
   `Inference$ensure_mirai_daemons` (`inference_all_abstract.R:839-850`)
   and `SimulationFramework$.ensure_mirai_daemons`
   (`simulations_framework.R:2129-2184`) are near-copies of the same
   "check running daemon count, tear down if stale, relaunch via
   `start_mirai_daemons_bounded()`" logic — but the `SimulationFramework`
   version carries an extra 2-attempt retry-with-teardown loop the
   `Inference` version does not have. Either the `Inference` version is
   missing a real robustness fix, or the `SimulationFramework` version
   has speculative extra complexity that was never ported back — either
   way, the same problem has now been solved twice, inconsistently.
2. **The mirai poll + throttled liveness-check + `stop_mirai`-on-death
   loop, written out multiple times.** Confirmed sites:
   `SimulationFramework$run()`'s cache-building phase
   (`simulations_framework.R:1393-1414`) and its rep-dispatch phase
   (`simulations_framework.R:1806-1825`) each contain their own copy of
   "poll for ready mirai tasks, check daemon liveness on a throttle,
   `stop_mirai()` on death." A third occurrence was flagged during
   investigation in `par_lapply`'s mirai-backed path but not pinned to an
   exact line range — **TODO-2 below starts with confirming the full
   site list** before extracting, per this codebase's standing practice
   of not guessing at scope.
3. **Worker single-threading environment/option setup, defined once and
   hand-rederived once.** `make_configured_fork_cluster()`
   (`globals.R:371-436`) sets `OMP_NUM_THREADS`, `MKL_NUM_THREADS`,
   `OPENBLAS_NUM_THREADS`, `GOTO_NUM_THREADS`, `VECLIB_MAXIMUM_THREADS`,
   `NUMEXPR_NUM_THREADS`, `mc.cores`, and the `data.table`/`fixest`
   thread caps via `clusterCall()` on persistent cluster workers.
   `run_all_inference_fork_dispatch()`'s `mcparallel()` children
   (`inference_suite.R`, per `parallel_fork_cluster_test_safety.md`
   TODO-5) need the identical list applied via `Sys.setenv()`/`options()`
   *inside the child*, since there is no persistent cluster to
   `clusterCall()` — and that list was hand-rederived at the child-setup
   site instead of shared. If a new thread-limited library is added in
   the future (e.g. `RcppParallel`), today it must be remembered and
   added in two places by hand; it is easy to update one and miss the
   other.

None of these three are the scheduler-shape divergence itself (the
fork/mirai backend *choice*, the cluster/task lifecycle, the kill
semantics) — those are load-bearing and each has its own documented
reason (see Non-Goals). These three are the sub-pieces of plumbing
*underneath* that choice that don't need to differ and are actively
costing correctness risk by being copy-pasted.

## Implementation TODOs

- [ ] TODO-1: **Confirm and unify the two `ensure_mirai_daemons`
  implementations.** Read both (`Inference$ensure_mirai_daemons`,
  `SimulationFramework$.ensure_mirai_daemons`) side by side; determine
  whether the `SimulationFramework` version's extra 2-attempt
  retry-with-teardown loop is (a) a genuine robustness improvement that
  should be promoted into a single shared implementation both callers
  use, or (b) unneeded complexity for the `Inference` call site's usage
  pattern. Default expectation, pending that read: promote the more
  defensive behavior (retry loop included) into one free function
  (`globals.R`, alongside `start_mirai_daemons_bounded()`), have both
  `Inference` and `SimulationFramework` call it, and delete both private
  near-duplicates. No behavior change for either caller if (a) holds;
  document explicitly if (b) holds and the simpler behavior is kept
  instead.
- [ ] TODO-2: **Locate every mirai poll/liveness/stop-on-death site, then
  extract one shared helper.** Start by confirming the full list via
  `graft grep` for the pattern's signature calls (`mirai::stop_mirai`,
  daemon-liveness checks against `mirai::status()`, non-blocking
  completion polling) across `simulations_framework.R`,
  `inference_all_abstract.R`, and any other file — do not assume the two
  `simulations_framework.R` sites (cache phase, rep-dispatch phase) are
  the only ones; the investigation flagged a possible third in
  `par_lapply` without pinning it. For each confirmed site, diff the
  poll interval, liveness-check throttle, and death-handling logic
  against the others; if they've already diverged in behavior (not just
  code shape), that divergence itself needs a decision (which behavior
  is correct) before extraction, not a silent pick. Extract the
  unified version as one shared helper (`globals.R` or a new
  small internal file, matching this codebase's convention of keeping
  cross-cutting parallel-runtime helpers in `globals.R`) taking the
  poll/liveness parameters as arguments; update every confirmed call
  site to use it.
- [ ] TODO-3: **Share the worker single-threading setup between
  `clusterCall()`-based and `mcparallel()`-child-based paths.** Extract
  the `OMP_NUM_THREADS`/`MKL_NUM_THREADS`/`OPENBLAS_NUM_THREADS`/
  `GOTO_NUM_THREADS`/`VECLIB_MAXIMUM_THREADS`/`NUMEXPR_NUM_THREADS`/
  `mc.cores`/`data.table`/`fixest` list currently inlined in
  `make_configured_fork_cluster()` (`globals.R:371-436`) into one small
  function (e.g. `apply_worker_thread_limits()`) that returns or directly
  applies the same settings; call it both from
  `make_configured_fork_cluster()`'s `clusterCall()` closure (fork/PSOCK
  workers) and from `run_all_inference_fork_dispatch()`'s per-child setup
  right after `mcparallel()`'s fork (`inference_suite.R`). Also check
  whether `SimulationFramework$run()`'s mirai path
  (`mirai::everywhere()`, per the investigation) needs the same
  treatment and wire it in if so. Single source of truth for "what
  thread-limiting libraries does EDI know about" — adding a new one in
  the future means editing one function, not searching for every call
  site by hand.
- [ ] TODO-4: **Comment-hygiene pass at all three main scheduler sites**
  (`Inference$par_lapply`, `SimulationFramework$run()`,
  `InferenceSuite$run_all_inference()`/`run_all_inference_fork_dispatch()`)
  pointing at this plan and stating in one or two sentences *why* the
  three scheduler shapes are not unified (stateless map vs. stateful
  pushed-state pool vs. PID-granular force-kill), so a future contributor
  who notices the apparent duplication reads the reasoning before
  attempting a merge — mirroring this codebase's existing practice of
  leaving a comment so a future reader doesn't "clean up" something that
  looks redundant but isn't (see
  `parallel_fork_cluster_test_safety.md` TODO-5's RNG-reseed comment for
  the precedent).

## Related

- `parallel_fork_cluster_test_safety.md` — the plan that produced
  `make_configured_fork_cluster()`'s hardening, `run_all_inference_fork_dispatch()`'s
  `mcparallel`/PID-kill design (TODO-5), and the still-open TODO-6 note
  about `SimulationFramework$run()`'s fork-cluster path needing its own
  future safety pass. This plan is downstream of and consistent with
  that one's findings but does not reopen or extend its scope.
- `inference_suite_plan.md` — `run_all_inference()`'s owning plan;
  TODO-3 above touches `run_all_inference_fork_dispatch()` and should
  reference this plan rather than duplicate the primitives-extraction
  discussion there.
- `Inference$par_lapply` (`inference_all_abstract.R:726-838`) and
  `globals.R`'s `make_configured_fork_cluster()`/
  `start_mirai_daemons_bounded()`/`set_num_cores()` — the existing shared
  layer this plan extends, not replaces.
