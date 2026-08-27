# Memory-Side Improvements: NUMA, Huge Pages, and HBM CPUs

Date: 2026-08-27

Status: implementation plan. All speedups are planning estimates until the
benchmark matrix below is run on bare-metal multi-socket and HBM systems.

## Decision and ownership boundary

This should be a separate, architecture-neutral plan.

- `arm_hardware.md` owns ARM compilation, Apple/Accelerate, Graviton, and
  Grace-specific enablement. It should consume the generic NUMA allocator and
  placement policy here for Grace.
- `intel_hardware.md` owns Intel AMX and Intel-specific matrix-engine dispatch.
  It should consume this plan for Sapphire Rapids/Xeon Max topology, HBM, and
  multi-socket placement.
- `performance_profiling_and_upgrades.md` owns the general diagnostic passes:
  cache/TLB/false-sharing counters (TODO-143), row-layout audit (TODO-144),
  OpenMP scaling (TODO-147), oversubscription (TODO-148), fork serialization
  (TODO-161), roofline placement (TODO-171), and machine-state capture
  (TODO-175). This plan consumes those results and owns the memory-topology
  implementation: topology discovery, EDI-owned large buffers, first touch,
  memory policy, huge-page advice, HBM placement, and topology-aware dispatch.

Do not implement separate ARM-NUMA and Intel-NUMA allocators. The OS topology
and memory-policy layer is shared; only machine-specific detection and benchmark
profiles differ.

## Executive summary

On multi-socket systems, adding threads can make a bandwidth-bound kernel
slower when threads repeatedly fetch pages allocated on another socket. The
first thread that writes an anonymous page usually determines its NUMA home
under the default Linux policy. A single-threaded initialization followed by a
cross-socket OpenMP loop is therefore a common anti-pattern. Thread affinity,
parallel first touch, socket-local work partitioning, and—where appropriate—one
process per socket can be worth more than additional cores.

Transparent huge pages (THP) can reduce dTLB pressure for large, densely
scanned buffers, but `madvise(MADV_HUGEPAGE)` is only a hint, is Linux-specific,
can waste memory or cause compaction stalls, and is unsafe to apply casually to
page ranges owned by R's allocator. EDI should advise only its own aligned,
anonymous mappings and verify whether huge pages were actually obtained.

Intel Xeon CPU Max provides up to 64 GB of on-package HBM2e per socket. Its
HBM-only and cache modes can benefit applications without source changes; flat
mode exposes HBM and DDR as separate NUMA memory nodes and requires deliberate
placement. HBM helps only when the active working set fits, the kernel is
bandwidth-bound, and threads remain close to the selected HBM node.

Planning ranges:

- fixing bad remote-NUMA placement: **1.2–2.5x for the affected kernel** and
  **1.1–1.8x end-to-end**;
- THP on a confirmed dTLB-bound, long-lived dense buffer: typically
  **1.02–1.2x**, occasionally **1.1–1.4x** for the affected scan, and sometimes
  a regression;
- moving a fitting working set from DDR to Xeon Max HBM: approximately
  **1.5–4x for a truly streaming kernel** and **1.2–3x end-to-end** when that
  kernel dominates;
- an already-local, cache- or compute-bound workload: approximately **1.0x**.

These are not additive. HBM, NUMA locality, and huge pages often address the
same stalled memory accesses; multiplying their headline speedups would double
count the benefit.

## Scope correction: EDI does not currently build trees

The motivating statement says tree building is bandwidth-bound. An exhaustive
search of the indexed `EDI/src` and `EDI/R` trees finds no current decision-tree
builder, linear-leaf model, or split-search kernel. `more_simd_optimization.md`
mentions future split-search layout, but there is no present implementation to
optimize.

This plan therefore targets real current consumers:

- pairwise Euclidean, weighted, Manhattan, and Mahalanobis distance scans in
  `EDI/src/optimal_blocks_distance.cpp:152-225` and
  `EDI/src/pair_dist_helpers.cpp:56-90`;
- greedy/optimal design searches and pairwise-swap engines that repeatedly
  consume distance/objective arrays;
- randomization and bootstrap kernels that scan `n x B` assignment/index
  matrices, including `EDI/src/ols_distr_parallel.cpp:15-206` and
  `EDI/src/rand_bootstrap_ols_parallel.cpp:22-93`;
- large reusable GLMM/model workspaces and row-/column-major feature copies;
- `SimulationFramework` replications and DGP data where process placement,
  copy-on-write, and per-worker duplication determine locality and capacity.

If tree building is later added, its column scans, histograms, sorted indices,
and node partitions should use the same allocator, first-touch, affinity, and
benchmark infrastructure. It should not be used to justify speculative changes
to today's kernels.

## Current package state

EDI already has useful pieces but no memory-topology policy:

- `EDI/R/globals.R:1474-1522` coordinates OpenMP, BLAS, and package thread
  counts, but does not set `OMP_PLACES`, `OMP_PROC_BIND`, CPU affinity, or NUMA
  memory policy.
- `EDI/R/zzz.R:4-41` makes the package single-threaded by default and imports
  saved local-machine tuning.
- `EDI/R/local_machine_tuning_persistence.R:58-90` fingerprints CPU model,
  cores, RAM, BLAS, LAPACK, platform, and R version, but not sockets, NUMA
  nodes, page policy, or HBM mode.
- `EDI/R/globals.R:371-436` constrains nested threads in fork/PSOCK workers,
  but does not bind workers to sockets or arrange local first touch.
- OpenMP kernels generally allocate with Rcpp, Eigen, or `std::vector` and then
  compute without placement control. The performance report explicitly notes
  that the current single-socket development host cannot reveal remote-memory
  penalties (`performance_profiling_and_upgrades.md:2447-2469`).
- `pair_dist_helpers.cpp:56-90` already copies an R column-major matrix into a
  row-major Eigen matrix before the repeated row scans. This is a good layout
  optimization but its allocation and initialization are not topology-aware.

## Hardware and OS model

### NUMA and first touch

Under Linux's default local allocation policy, an anonymous page is generally
allocated on or near the NUMA node of the CPU that first writes it. Allocation
alone is not sufficient; the write fault establishes physical backing. Thus:

```text
single thread allocates and zeroes X_copy on socket 0
    -> most pages reside on socket 0
threads on sockets 0 and 1 scan X_copy
    -> socket 1 repeatedly reads remote memory
```

The preferred pattern for a partitioned output is:

```text
bind worker/team to its target socket or NUMA place
allocate or map the buffer without serially touching every page
parallel-initialize each worker's eventual page range
compute on the same range with the same placement
```

For a shared read-only input used heavily from every socket, choose by
measurement among:

- interleaving pages across allowed nodes;
- one socket-local replica per worker team;
- leaving one copy on its natural node and accepting remote reads;
- one process per socket, with local data preparation.

Replication trades memory capacity and setup time for locality. It should be
limited to long-lived, repeatedly scanned inputs.

### Xeon Max HBM modes

Intel documents three Xeon CPU Max memory modes:

- **HBM-only:** HBM is the only system memory. EDI needs no placement API, but
  the process, R runtime, packages, data, and temporary buffers must fit within
  the available HBM (up to 64 GB per socket).
- **HBM cache / 2LM:** HBM transparently caches DDR. EDI cannot bind an object
  to a separately visible HBM node; benchmark and report the BIOS mode.
- **Flat / 1LM:** HBM and DDR appear as distinct NUMA memory nodes. EDI can
  prefer or bind hot owned buffers to HBM while leaving cold data and R's heap
  in DDR.

Flat mode is the main implementation target. HBM memory nodes may have no CPUs,
so “allocate on the current CPU's node” is not enough. Topology discovery must
associate CPU nodes with their closest HBM nodes using OS-provided distances
and memory attributes, and it must respect scheduler/cgroup allowed masks.

Strict HBM binding can fail when capacity is exhausted. The default automatic
policy should prefer HBM with an explicit fallback to local DDR; strict binding
is an expert/reproducibility option.

### Transparent versus explicit huge pages

Start with Linux THP and `MADV_HUGEPAGE`, not explicit hugetlb pages:

- THP does not require reserving a fixed huge-page pool at boot;
- it remains pageable and can fall back to normal pages;
- the hint may be ignored depending on kernel policy, alignment, fragmentation,
  mapping type, and memory pressure;
- direct reclaim/compaction can add latency;
- sparse access can waste memory because touching a small part may back a much
  larger page.

Explicit `MAP_HUGETLB`/hugetlbfs requires system administration, reservation,
and different failure handling. Keep it out of the package default; it may be
documented as an operator-controlled deployment experiment after THP results.

## Safety rule: never `madvise` arbitrary R heap memory

R matrices are allocated inside R's heap and may share virtual-memory areas and
pages with unrelated objects. Page-aligning an address range outward and
calling `madvise(MADV_HUGEPAGE)` can therefore affect memory EDI does not own.
It also gives EDI no control over lifetime, first touch, or alignment.

Implement huge-page and NUMA advice only for buffers created by an EDI-owned
RAII mapping abstraction, for example:

```text
edi_large_buffer<T>
    mmap(MAP_PRIVATE | MAP_ANONYMOUS)
    page/huge-page-aware size and alignment
    optional mbind/set_mempolicy policy
    optional madvise(MADV_HUGEPAGE)
    parallel first-touch initializer
    munmap in destructor
```

Use overflow-checked byte calculations, move-only ownership, deterministic
cleanup, and an Eigen `Map` over the resulting memory. On unsupported systems,
fall back to aligned allocation without changing numerical results.

For an R input matrix, copy into an owned buffer only when reuse and measured
locality/THP gains repay the copy. One-shot kernels should continue mapping R
memory directly.

## Architecture and implementation plan

### Phase 0A: build-time capability detection

Add `configure` and `configure.win` probes before implementing any native
memory-placement backend. Detection must answer whether the toolchain can
compile and link a feature, while runtime detection answers whether the running
kernel, process, and machine permit its use. Never infer API support solely
from an OS name, compiler name, compiler version, or CPU model string.

- [ ] **TODO-0A: Probe the basic mapping and advice APIs.** Compile and link
  minimal programs for `mmap` and `madvise`, then separately compile references
  to `MADV_HUGEPAGE` and, when declared, `MADV_COLLAPSE`. Do not treat
  `MADV_COLLAPSE` as required. A declaration or successful link establishes
  build capability only; the runtime path must still handle `EINVAL`, `ENOMEM`,
  `EPERM`, and kernels or policies that decline huge-page backing.
- [ ] **TODO-0B: Probe Linux NUMA policy calls independently.** Check headers,
  declarations, and successful linking for `mbind`, `set_mempolicy`, and
  `move_pages`. Distinguish direct syscall availability from a libnuma wrapper
  so one missing optional library does not disable a usable lower-level
  backend. Each call receives its own feature macro because partial libc,
  headers, and container build environments exist.
- [ ] **TODO-0C: Probe CPU-affinity calls.** Compile and link
  `sched_getaffinity` and `sched_setaffinity`, including any required feature-test
  macro such as `_GNU_SOURCE`. Keep read-only affinity discovery available when
  the getter exists but the setter does not.
- [ ] **TODO-0D: Detect optional topology libraries.** Check `<numa.h>` plus a
  link against libnuma, and check hwloc headers plus the required hwloc library.
  Record headers and linkability separately. Prefer `pkg-config` when available,
  but verify its flags with an actual compile-and-link probe. Neither libnuma
  nor hwloc becomes a mandatory package dependency.
- [ ] **TODO-0E: Guard Linux sysfs/HMAT support.** At configure time, compile
  any Linux-only headers, types, constants, or parser dependencies used by the
  sysfs/HMAT backend. Files such as node topology and HMAT attributes are
  machine/runtime state, so their existence and readability must be checked at
  runtime rather than by executing a configure test on the build host.
- [ ] **TODO-0F: Generate a single capability header.** Have `configure` and
  `configure.win` produce an internal header consumed by every backend, with
  value-style macros such as `EDI_HAVE_MMAP`, `EDI_HAVE_MADVISE`,
  `EDI_HAVE_MADV_HUGEPAGE`, `EDI_HAVE_MADV_COLLAPSE`, `EDI_HAVE_MBIND`,
  `EDI_HAVE_SET_MEMPOLICY`, `EDI_HAVE_MOVE_PAGES`,
  `EDI_HAVE_SCHED_GETAFFINITY`, `EDI_HAVE_SCHED_SETAFFINITY`,
  `EDI_HAVE_LIBNUMA`, `EDI_HAVE_HWLOC`, and `EDI_HAVE_LINUX_HMAT`. Define every
  macro to `0` or `1`; do not rely on inconsistent `#ifdef` semantics. Wrap all
  Linux-only includes and implementations in these guards.
- [ ] **TODO-0G: Make compile-and-link tests authoritative.** Use preprocessor
  checks only for constants that cannot be linked. Do not accept a compiler or
  OS version table as proof that declarations, ABI, or libraries are usable.
  Cache probe results and print a concise configure summary including why each
  optional backend was disabled.
- [ ] **TODO-0H: Define cross-compilation behavior.** Detect cross compilation
  using the configure host/build relationship. Compile-and-link probes remain
  valid, but never execute a target binary. Any capability that genuinely
  requires execution defaults to unknown/disabled. Accept explicit, documented
  `--with-edi-*`/`--without-edi-*` configure switches or narrowly scoped cache
  variables supplied by the packager; an override must still pass a
  compile-and-link test unless it selects the portable stub.
- [ ] **TODO-0I: Make `configure.win` select portable stubs by default.** Probe
  rather than assume where a portable API may exist, but compile a complete
  no-NUMA/no-THP/no-HMAT backend whenever the POSIX/Linux interfaces are absent.
  Unsupported functions return structured `unsupported_at_build_time` status,
  not link errors or missing symbols. Apply the same stub contract on macOS,
  BSD, restricted toolchains, and minimal Linux builds.
- [ ] **TODO-0J: Expose compiled capabilities in diagnostics and build
  metadata.** Extend `edi_build_info_cpp()` and `EDI:::memory_diagnostics()` with
  the generated macro values, selected backend, optional library versions when
  known, configure overrides, and cross-compilation status. This separates
  “not compiled,” “compiled but unavailable at runtime,” and “available but not
  selected.”

Acceptance gate: native and stub translation units compile from the same public
interface; native features are enabled only after successful compile-and-link
probes; a simulated cross build runs no target executables; missing libnuma,
hwloc, NUMA syscalls, affinity calls, or huge-page constants produces a usable
portable package rather than a configure or load failure.

### Phase 0B: topology and memory diagnostics

- [ ] **TODO-1: Extend the hardware fingerprint.** Record physical packages,
  NUMA nodes, CPUs per node, node distance matrix, memory bytes/free per node,
  cpuset/cgroup-allowed CPUs and memory nodes, base page size, THP modes and
  sizes, kernel automatic-NUMA-balancing state, and virtualization/container
  indicators.
- [ ] **TODO-2: Detect heterogeneous memory.** On Linux, consume sysfs/HMAT or
  an optional hwloc/libnuma backend to identify memory-only nodes and their
  bandwidth/latency class. Record Xeon Max HBM mode when discoverable. Do not
  identify HBM solely from a CPU model string.
- [ ] **TODO-3: Add `EDI:::memory_diagnostics()`.** Report current CPU affinity,
  OpenMP places/binding, process memory policy, node residency summary, THP
  eligibility/use, HBM capacity, and saved tuning policy. All probes fail open
  on restricted containers and unsupported operating systems.
- [ ] **TODO-4: Add benchmark topology capture.** Extend the machine-state
  artifact with `lscpu`, `lstopo`, `numactl --hardware`, `numastat`, THP sysfs,
  `/proc/self/status`, `/proc/self/numa_maps`, and relevant `/proc/self/smaps`
  fields. External commands are benchmark tools, not runtime dependencies.

Acceptance gate: diagnostics correctly describe a single-socket host, a
two-socket host, a cpuset-restricted container, and Xeon Max flat/cache/HBM-only
modes without changing process affinity or allocation policy.

### Phase 1: EDI-owned large-buffer abstraction

- [ ] **TODO-5: Implement `edi_large_buffer<T>`.** Initial Linux backend uses
  anonymous `mmap`; other Unix and Windows backends preserve aligned ownership
  without claiming NUMA/THP support. Never expose an advised pointer after its
  owner dies.
- [ ] **TODO-6: Add explicit policies.** Support `default`, `local`,
  `interleave`, `preferred_node`, and `bind_node` internally. Validate requested
  nodes against the process's allowed memory mask. `preferred` may spill;
  `bind` reports allocation failure and is never the automatic default.
- [ ] **TODO-7: Add THP advice.** `hugepage=auto|never|madvise` applies
  `MADV_HUGEPAGE` only above a tunable size and only to dense, long-lived
  mappings. Record syscall result separately from observed huge-page residency.
- [ ] **TODO-8: Consider `MADV_COLLAPSE` only experimentally.** It can force a
  synchronous collapse and stall. Test it after initialization for long-lived
  buffers, behind an explicit benchmark flag; do not ship it in `auto` without
  a latency and memory-pressure study.
- [ ] **TODO-9: Integrate safely with Eigen.** Provide aligned column- and
  row-major `Eigen::Map` helpers, verify leading dimensions/overflow, and avoid
  hidden copies. R-facing outputs remain ordinary R objects unless a separate
  ALTREP/external-memory design is approved.

### Phase 2: affinity and first-touch primitives

- [ ] **TODO-10: Add an affinity policy.** Support
  `EDI_MEMORY_AFFINITY=auto|none|compact|spread|one-team-per-node`. Prefer
  standard OpenMP `OMP_PLACES`/`OMP_PROC_BIND` for OpenMP teams and optional
  hwloc/libnuma calls for process/worker binding. Respect affinity imposed by
  Slurm, MPI, containers, `taskset`, or `numactl`; never expand beyond it.
- [ ] **TODO-11: Implement parallel first touch.** Partition the buffer by
  whole page ranges matching the later compute partition. Bind threads first,
  then initialize each range in parallel. Avoid `MatrixXd::Zero`, `calloc`, or
  a serial `memset` before the topology-aware initializer, because those can
  establish the wrong page home.
- [ ] **TODO-12: Keep initialization and computation schedules consistent.** A
  static page partition followed by dynamic work stealing can undo locality.
  Either preserve ownership for the bandwidth-heavy phase or measure a bounded
  stealing policy whose load-balance gain exceeds remote traffic.
- [ ] **TODO-13: Add process-per-socket support to large workflows.** Compare a
  single cross-socket OpenMP team with one bound R worker/process per socket,
  inner native/BLAS threads constrained locally, and inputs prepared after
  binding. Integrate with existing nested-thread controls.
- [ ] **TODO-14: Audit fork copy-on-write locality.** Pages touched by the
  parent before `fork()` retain their original NUMA placement. Measure remote
  reads and `Private_Dirty`; allocate/touch per-worker scratch after binding and
  replicate immutable inputs only when amortized.

### Phase 3: apply only to measured hot buffers

Start with three prototypes:

- [ ] **TODO-15: Pair-distance input and output.** For large `m x p`, create the
  reusable row-major feature copy in an owned buffer. Partition the symmetric
  output by page-aligned row/tile blocks, first-touch and compute those blocks
  on the same NUMA team, and compare shared-interleaved input with per-node
  replicas. Avoid concurrent writes to the same cache line at tile boundaries.
- [ ] **TODO-16: Randomization/bootstrap batches.** Apply owned buffers to
  large assignment/index/noise matrices only when generated natively or copied
  once and reused. Partition replicate columns in contiguous chunks so each
  worker reads/writes local pages. Do not huge-page short-lived default-size
  batches.
- [ ] **TODO-17: Reusable model workspaces.** From the allocation-lifetime and
  row-layout audits, move only large repeatedly scanned feature/layout copies
  and workspaces into owned buffers. Small Hessians and optimizer vectors stay
  on ordinary Eigen/storage.
- [ ] **TODO-18: Optimal-design objective arrays.** Measure the greedy and
  pairwise-swap search arrays. Use topology-aware storage only if roofline and
  remote-access counters show bandwidth/locality limits rather than branch or
  algorithmic limits.

Future tree building should begin with column/feature partitions and per-node
histogram/split buffers, using this phase's primitives. It is not a prerequisite
for completing the current plan.

### Phase 4: HBM placement policy

- [ ] **TODO-19: Define hot versus cold allocations.** Hot means repeatedly
  scanned during the timed kernel; cold means metadata, final results, R
  objects, logs, or one-pass inputs. In Xeon Max flat mode, only owned hot
  buffers are HBM candidates by default.
- [ ] **TODO-20: Add
  `EDI_MEMORY_TIER=auto|default|dram|hbm-preferred|hbm-bind`.** `auto` selects
  HBM only when diagnostics identify it, predicted/observed
  working set fits under a safety fraction of free HBM, and a tuned policy
  exists for that operation. `hbm-preferred` spills to DDR; `hbm-bind` is an
  expert option that errors instead of silently spilling.
- [ ] **TODO-21: Use capacity-aware batching.** Pair-distance outputs are
  `O(m^2)` and bootstrap matrices are `O(nB)`. Keep the active tile/batch plus
  reusable feature copy in HBM while cold/full outputs reside in DDR when the
  complete working set exceeds HBM.
- [ ] **TODO-22: Benchmark all BIOS modes as different machines.** HBM-only,
  cache, and flat mode change visible topology and semantics. Saved tuning from
  one mode is invalid in another.
- [ ] **TODO-23: Generalize beyond Xeon Max.** Select memory tiers from
  discovered attributes and measured bandwidth/latency, not vendor names. This
  permits future HBM CPUs and CXL memory tiers without rewriting kernel APIs.

### Phase 5: automatic tuning and user controls

- [ ] **TODO-24: Add a `memory` tuning axis.** Extend
  `tune_EDI_for_this_machine()` to compare affinity, first-touch, NUMA policy,
  input replication, THP advice, batch/tile size, and HBM tier for eligible
  operations. Use a staged search rather than a full Cartesian product.
- [ ] **TODO-25: Persist topology-sensitive policies.** Extend the fingerprint
  with sockets/nodes, allowed masks, HBM mode/capacity, kernel, THP policy,
  allocator/backend, OpenMP runtime, and BIOS/SNC topology. Invalidate rather
  than reuse when these change.
- [ ] **TODO-26: Add deterministic global overrides.** Proposed controls:
  `EDI_NUMA_POLICY=auto|default|local|interleave|preferred|bind`,
  `EDI_HUGEPAGE=auto|never|madvise`, `EDI_MEMORY_TIER=...`, and
  `EDI_MEMORY_AFFINITY=...`. Explicit invalid requests error; `auto` safely
  falls back and records why.
- [ ] **TODO-27: Keep defaults conservative.** Single-socket, unsupported OS,
  restricted topology, small buffers, and untuned operations use current
  allocation and scheduling. Do not add syscalls to every small model fit.

## Automatic detection and fallback algorithm

At package load or first eligible use:

1. Read the generated build-capability table. Calls absent at compile/link time
   route directly to portable stubs; runtime probing never references an
   uncompiled symbol.
2. Detect OS and kernel support only for compiled capabilities. Non-Linux starts
   with `numa=no`, `thp=no` unless a tested native backend exists.
3. Read the process's allowed CPU and memory masks before system-wide topology;
   container/scheduler restrictions are authoritative.
4. Discover packages, NUMA nodes, CPU-to-node mapping, distance matrix, node
   capacity, and heterogeneous-memory attributes.
5. Detect THP support and policy; `MADV_HUGEPAGE` availability is not proof it
   will succeed or produce huge pages.
6. Classify the machine:

```text
single NUMA node
multi-node UMA-ish
multi-socket NUMA
heterogeneous memory (HBM/DDR or other tiers)
unknown/restricted
```

7. For each eligible operation, query the saved tuned policy keyed by the full
   fingerprint. If absent, use the conservative default or run an explicitly
   requested short tuner—never benchmark unexpectedly in a normal call.
8. Check buffer size, lifetime/reuse, access density, working-set/HBM capacity,
   and active thread/process layout.
9. Allocate through `edi_large_buffer`, apply the selected memory policy and
   THP hint, bind workers, then parallel-first-touch.
10. Verify errors immediately. `mmap`, `mbind`, affinity, `madvise`, or HBM
   placement failure falls back to the ordinary allocator/default policy under
   `auto`; an explicit strict request errors.
11. Expose build capabilities, the runtime decision, and observed residency
    through diagnostics.

The automatic path must never require root, write sysfs, change BIOS mode,
reserve hugetlb pages, modify machine-wide THP settings, or move unrelated R
heap pages.

## Benchmark plan

### Required machines

| Machine | Purpose |
|---|---|
| Single-socket ordinary DDR | Establish that detection and default fallback add negligible overhead. |
| Dual-socket DDR | Measure local, remote, interleaved, one-team-per-node, and process-per-socket behavior. |
| Xeon CPU Max, HBM-only | Measure capacity fit and transparent all-HBM behavior. |
| Xeon CPU Max, cache mode | Measure transparent HBM caching with no explicit placement. |
| Xeon CPU Max, flat mode | Compare DDR, HBM preferred/bound, interleave, and active-set tiling. |
| Grace Superchip or another ARM NUMA host | Prove the common implementation is not Intel-specific. |

Bare metal is required for authoritative NUMA, memory-counter, and HBM results.
Virtual machines may obscure topology and precise hardware counters.

### Workloads and sizes

- Pair distances: vary rows `m`, features `p`, output size, weighting, and
  number of repeated consumers.
- OLS randomization/bootstrap: vary `n`, `p`, `B`, noise/index storage, and
  number of passes.
- Model workspaces: use the largest profile-supported GLMM/GEE/Gaussian-LMM
  cases, but retain them only if measured bandwidth-bound.
- Simulation: vary replication count, fork/PSOCK/OpenMP backend, input reuse,
  and per-worker memory footprint.
- Future tree prototype only after a tree feature exists; benchmark feature
  scans, histogram construction, split evaluation, and node partitioning
  separately.

Test working sets at approximately 25%, 75%, 100%, and 150% of per-socket HBM
capacity. The 100% boundary needs a safety reserve for R, libraries, page
tables, workers, and temporary buffers; “input bytes < 64 GB” does not imply the
process fits in 64 GB.

### Experiment matrix

Compare:

- threads `{1, cores_per_socket, all_physical_cores}`;
- `OMP_PROC_BIND` unset/false, `close`, and `spread` with appropriate places;
- default first touch, deliberate serial touch, parallel local touch;
- default, local, interleave, preferred, and strict bind policies;
- one shared input versus per-node replicas;
- one process versus one process per socket;
- base pages, `MADV_HUGEPAGE`, and experimental `MADV_COLLAPSE`;
- DDR versus HBM in flat mode, plus HBM-only/cache modes;
- current allocator versus owned-buffer path including copy/setup time.

### Measurements

Record:

- elapsed/CPU time, throughput, scaling efficiency, and end-to-end time;
- local/remote accesses, NUMA misses, page migrations, per-node residency, and
  memory-controller bandwidth;
- dTLB misses/walk cycles, page faults, THP eligibility, `AnonHugePages`, and
  actual kernel/MMU page size;
- LLC misses, `perf c2c` HITM/false sharing, cache-to-cache transfers;
- peak RSS, per-node memory use, HBM spill/failure, copy/replication bytes;
- CPU frequency, energy, thermal state, kernel/THP settings, and contention.

Use STREAM or an equivalent benchmark to measure each node/tier's attainable
bandwidth. Product peak bandwidth is not the roofline used for EDI estimates.
Use randomized ABBA/BAAB comparisons and include allocation, first touch,
copying, advice, pinning, and teardown in user-visible timings.

## Speedup estimates and interpretation

### A-priori ranges

| Change / condition | Affected-kernel estimate | End-to-end estimate | Confidence |
|---|---:|---:|---|
| Pin threads and parallel-first-touch pages that were mostly remote | 1.2–2.5x | 1.1–1.8x | Medium on a demonstrably bad dual-socket baseline; ~1x if already local. |
| One process/team per socket with local scratch/input | 1.2–2.5x throughput | 1.1–2x | Low-medium; replication/setup and load balance can erase it. |
| Interleave a shared streaming input across sockets | 1.1–1.8x | 1.05–1.4x | Low-medium; can hurt latency-sensitive reuse. |
| `MADV_HUGEPAGE` on a large dense dTLB-bound buffer | 1.02–1.2x typical; 1.1–1.4x favorable | 1.0–1.15x | Medium that gains are modest; regression possible from compaction/waste. |
| Xeon Max HBM versus local DDR, working set fits and is bandwidth-bound | 1.5–4x | 1.2–3x | Low-medium until achieved bandwidth and active fraction are measured. |
| HBM with working set over capacity and poor tiling | 0.8–1.5x | 0.9–1.3x | Medium; spill/remote traffic can nullify HBM. |
| More threads after memory bandwidth has saturated | 0.7–1.05x | 0.8–1.05x | High that adding cores is not automatically useful. |
| Compute-, branch-, sort-, or R-callback-bound workload | 0.95–1.05x | ~1x | High; memory placement is the wrong lever. |

These ranges are deliberately below vendor application headlines. EDI must
measure its own arithmetic intensity, active working set, memory mode, and
remote-access fraction.

### Amdahl and overlap

For fraction `f` accelerated by factor `s`:

```text
workflow speedup = 1 / ((1 - f) + f / s)
```

Examples:

- 30% bandwidth-bound work made 2x faster yields `1.18x` end-to-end;
- 60% made 2.5x faster yields `1.56x`;
- 80% made 3x faster yields `2.14x`.

Do not multiply, for example, a 2x NUMA fix by a 1.2x THP fix and a 3x HBM
move. Re-measure sequentially: once HBM/local placement removes memory stalls,
the remaining TLB or remote-memory fraction is different.

## Acceptance and stopping rules

Ship a topology-aware path only when:

1. counters/roofline show the target is memory- or TLB-bound;
2. EDI owns the advised/bound memory range;
3. allocation, copy, first-touch, and teardown are included;
4. numerical results and seeded behavior are unchanged;
5. automatic fallback works on single-socket, non-Linux, restricted-container,
   insufficient-HBM, and failed-THP cases;
6. an adjacent size range gains at least 10% end-to-end or at least 20% in a
   dominant kernel, with no material regression below the dispatch threshold;
7. memory footprint, latency tail, and energy remain acceptable.

Stop or revert when the workload is not bandwidth/TLB bound, the feature copy
is not reused enough, HBM capacity causes frequent spill, THP is not realized,
or the tuner selects the ordinary allocator consistently. A measured “no gain”
is a successful outcome.

## Risks and non-goals

- No claim that EDI currently contains a tree builder.
- No machine-wide affinity, THP, BIOS, or sysfs changes from package code.
- No root requirement and no mandatory libnuma/hwloc dependency.
- No `madvise` or `mbind` on arbitrary R heap pages.
- No default strict HBM/NUMA binding that can turn pressure into allocation
  failure.
- No assumption that a successful `madvise` produced a huge page.
- No assumption that `OMP_PROC_BIND=spread` is always better than `close`.
- No process migration outside scheduler/container-allowed CPU or memory masks.
- No explicit hugetlb dependency until THP has been measured and found
  insufficient.
- No speedup claim based on product peak bandwidth or vendor workloads.

## Definition of done

The feature is complete when:

1. `configure`/`configure.win` compile-and-link probes generate a truthful
   capability header, cross builds execute no target programs, and absent APIs
   select portable stubs;
2. topology/HBM/THP diagnostics and fingerprints are reliable and fail open;
3. `edi_large_buffer` provides owned, aligned, exception-safe mappings with
   optional memory policy and THP advice;
4. first-touch and affinity primitives respect external allowed masks;
5. at least two current EDI kernels have been prototyped and either retained or
   rejected with counters and end-to-end evidence;
6. dual-socket DDR, Xeon Max modes, and one ARM NUMA host have reproducible
   benchmark reports;
7. saved policies invalidate on topology, memory-mode, kernel, or runtime
   changes;
8. all default results and seeded computations remain equivalent;
9. documentation explains when fewer cores, process-per-socket, interleaving,
   huge pages, or HBM is selected and why.

## Recommended order

TODO-0A–0J (compile/link capability checks and stubs) → TODO-1–4 (observe
topology) → TODO-5–9 (safe owned buffers) → TODO-10–14 (affinity and first
touch) → TODO-15–18 (real-kernel prototypes) → TODO-19–23 (HBM) → TODO-24–27
(automatic tuning and controls).

The first performance prototype should be the large pair-distance row-major
copy/output because it has dense repeated scans and explicit `O(m^2 p)` work.
The first correctness-only increment should be diagnostics. Do not start HBM
placement until owned buffers and dual-socket first-touch behavior are proven.

## References

Repository evidence:

- `EDI/R/globals.R:371-436,1474-1522`
- `EDI/R/zzz.R:4-41`
- `EDI/R/local_machine_tuning.R:296-514`
- `EDI/R/local_machine_tuning_persistence.R:58-90`
- `EDI/src/pair_dist_helpers.cpp:56-90`
- `EDI/src/optimal_blocks_distance.cpp:152-225`
- `EDI/src/ols_distr_parallel.cpp:15-206`
- `EDI/src/rand_bootstrap_ols_parallel.cpp:22-93`
- `performance_profiling_and_upgrades.md:2354-2469,2520-2532,2556-2578`
- `arm_hardware.md:391-433`
- `intel_hardware.md:370-416`

Primary documentation:

- [Intel Xeon CPU Max Series](https://www.intel.com/content/www/us/en/products/details/processors/xeon/max-series.html)
- [Intel Xeon Max HBM modes and profiling](https://www.intel.com/content/www/us/en/docs/vtune-profiler/cookbook/2023-2/profiling-hbm-performance-on-intel-max.html)
- [Intel Xeon CPU Max configuration and tuning guide](https://cdrdv2-public.intel.com/769060/354227-intel-xeon-cpu-max-series-configuration-and-tuning-guide.pdf)
- [Linux transparent huge-page documentation](https://www.kernel.org/doc/html/latest/admin-guide/mm/transhuge.html)
- [Linux `madvise(2)`](https://man7.org/linux/man-pages/man2/madvise.2.html)
- [Linux `mbind(2)`](https://man7.org/linux/man-pages/man2/mbind.2.html)
- [Linux NUMA library API](https://man7.org/linux/man-pages/man3/numa.3.html)
- [OpenMP `OMP_PROC_BIND`](https://www.openmp.org/spec-html/5.1/openmpse61.html)
- [OpenMP `OMP_PLACES`](https://www.openmp.org/spec-html/5.1/openmpse62.html)
