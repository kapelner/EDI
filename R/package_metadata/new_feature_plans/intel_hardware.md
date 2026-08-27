# Intel AMX / Matrix Engines (Sapphire Rapids+)

Date: 2026-08-27

Status: feasibility and implementation plan. All speedups are a-priori ranges,
not EDI measurements.

## Decision: separate plan, shared infrastructure

Keep this plan separate from `arm_hardware.md`.

The two plans share an explicit dense-linear-algebra adapter, backend
identification, size-based dispatch, thread control, machine fingerprints, and
benchmark methodology. That shared layer should have one implementation rather
than ARM and Intel copies. At implementation time, move the architecture-neutral
parts of `arm_hardware.md` Phase 2 into a small common module (and, if the plans
become hard to maintain, a future `dense_linear_algebra_backends.md`).

The hardware-specific work should remain separate:

- ARM targets FP64 performance through native NEON/SVE, Accelerate, ArmPL,
  NVPL/OpenBLAS, memory bandwidth, and Grace NUMA.
- Sapphire Rapids AMX uses x86 tile state, CPUID/XSTATE permission, special
  compiler targets, and primarily INT8/BF16 arithmetic.
- EDI's inferential kernels currently use FP64. Sapphire Rapids AMX does **not**
  accelerate FP64 `DGEMM`, `DSYRK`, LDLT, QR, or covariance solves. Those remain
  AVX-512/BLAS work even on an AMX-capable processor.

Therefore “Intel hardware support” and “use AMX” are not synonyms. EDI should
first get the ordinary FP64 Intel path right, then expose AMX only for a proven,
genuinely matrix-shaped mixed-precision stage.

## Executive summary

Intel Advanced Matrix Extensions (AMX), introduced in 4th-generation Xeon
Scalable processors (Sapphire Rapids), provides tile registers plus tile matrix
multiplication. The first implementation supports INT8 and BF16 inputs with
wider accumulation; later Intel generations add other low-precision AMX
formats. This is excellent for large, reused, low-precision GEMM. It is not a
general accelerator for scalar likelihoods, GEMV, reductions, sorting, tiny
Hessians, FP64 statistical solves, or hundreds of unrelated small model fits.

For current EDI, the honest default estimate is:

- **AMX speedup for ordinary FP64 inference today: 1.0x**, because the relevant
  AMX arithmetic does not implement FP64.
- **Sapphire Rapids FP64 BLAS/AVX-512 tuning:** potentially **1.2–3x for a large
  dense stage**, but that is an Intel FP64 backend benefit, not AMX.
- **A future or restructured BF16 GEMM-shaped stage:** approximately **2–8x for
  the multiplication itself**, **1.5–4x including conversion/packing**, and
  usually only **1.0–1.3x end-to-end** unless that stage is a large fraction of
  wall time.
- **A deliberately batched, dense workflow** in which accepted low precision
  accounts for most work could plausibly reach **1.5–3x end-to-end**. That is a
  research target, not a release promise.

The recommended implementation is measurement-gated:

1. inventory actual GEMM shapes and precision requirements;
2. establish FP64 `DGEMM`/`DSYRK` baselines on AVX-512 and oneMKL;
3. prototype one AMX-backed BF16 batch through a library backend;
4. prove statistical/numerical acceptability with FP64 correction or exact
   final recomputation;
5. ship only if total elapsed time, including packing and fallback, wins across
   an adjacent size range.

## Hardware and software constraints

### What Sapphire Rapids AMX provides

Intel documents AMX as:

- eight two-dimensional tile registers, each up to 1 KiB;
- tile load, store, configuration, and release operations;
- a tile matrix multiplication unit (TMUL);
- AMX-TILE plus datatype-specific capabilities such as AMX-BF16 and AMX-INT8;
- operating-system-managed XTILECFG and XTILEDATA extended state.

The initial Sapphire Rapids implementation performs INT8 and BF16 tile dot
products. Intel's documentation explicitly distinguishes this from FP32/FP64
vector arithmetic handled through AVX-512. Later CPUs may expose AMX-FP16 or
additional formats, but feature detection must test the exact capability rather
than infer it from “Sapphire Rapids+.”

Consequences for EDI:

- `-march=sapphirerapids` or `-mamx-*` merely makes instructions/intrinsics
  available; it does not turn an FP64 Eigen expression into AMX code.
- A normal BLAS `dgemm` call remains FP64 and generally uses AVX-512/FMA, not
  AMX-BF16.
- Using AMX requires datatype conversion, blocking/packing into tile-friendly
  shapes, accumulation semantics, tail handling, and numerical validation.
- Tile state has a setup and context-switch cost. Small matrices and isolated
  calls should remain on Eigen or ordinary BLAS.

### OS permission is part of availability

CPUID support is necessary but insufficient. XTILEDATA is a large dynamic
XSTATE component and may not be enabled automatically. On Linux, a process may
need to request permission with `arch_prctl(ARCH_REQ_XCOMP_PERM,
XFEATURE_XTILEDATA)` before executing tile instructions. The runtime gate must
therefore require all of:

1. an x86-64 binary containing an isolated AMX implementation;
2. CPUID support for AMX-TILE and the requested datatype feature;
3. OS/XCR0/XSTATE support and successfully granted tile-data permission;
4. a backend compiled and linked for that feature;
5. a supported input datatype and matrix shape;
6. a measured dispatch threshold.

Virtual machines and containers can mask AMX even when the physical host has
it. Failure to obtain permission is a normal fallback condition, never a reason
to execute optimistically or crash with an illegal instruction.

### Precision is the primary gate

EDI estimates, Hessians, covariance matrices, confidence intervals, and
p-values are FP64 calculations. BF16 has much less significand precision.
Blindly converting `X`, `y`, weights, or information matrices to BF16 can:

- change matrix rank and condition estimates;
- perturb treatment coefficients and standard errors;
- change the selected match/design when distances are close;
- create or remove ties;
- alter optimizer convergence and test decisions.

An AMX prototype must use one of these contracts:

- **Approximate-only:** AMX produces a screening score, starting value, or
  candidate set; the final selected candidates and all reported statistics are
  recomputed in FP64.
- **Mixed precision with correction:** AMX computes an approximate product or
  solve, then FP64 residual evaluation and iterative refinement recover the
  required result. This is allowed only when conditioning diagnostics say the
  correction is trustworthy.
- **Explicit approximate feature:** the user opts into a documented
  approximate result with its own statistical validation. This is a separate
  feature decision and must never silently replace FP64 inference.

For this plan, exact final FP64 semantics are the default requirement.

## Current EDI opportunity audit

### Existing operations that look dense but are not AMX candidates

- `EDI/src/_helper_functions_core.h:405-429` computes FP64 `X'X` with BLAS
  `DSYRK`. It is a genuine Level-3 shape, but AMX-BF16 cannot replace it in an
  FP64 OLS/inference contract without a mixed-precision method.
- `EDI/src/fast_ols.cpp:14-72,91-201` combines FP64 cross-products with small
  LDLT/QR solves. The solve and covariance path remain FP64.
- GLMM objectives are dominated by `exp`/`log`/`log1p`, matrix-vector work,
  group/node reductions, and optimizer iterations
  (`performance_profiling_and_upgrades.md:111-133`). They are not large GEMM.
- `EDI/src/fast_gaussian_lmm.cpp:221-305` includes matrix products, but many
  group matrices are explicitly at most `2 x 2`; tile setup would overwhelm
  them.
- Hessians, covariance solves, GEE systems, and outer products are commonly
  `p x p` with modest `p`. They should use Eigen/FP64 LAPACK unless profiling
  finds large dimensions.
- Mean differences, Wilcoxon/rank procedures, ridit statistics, exact tests,
  scalar CI searches, and custom R callbacks have no useful AMX shape.

### Candidate 1: batch randomization OLS cross-products

`EDI/src/ols_distr_parallel.cpp:15-107` evaluates many treatment assignments.
It memoizes `X'X`, but computes `X' w_b` separately for each replicate. With
`W` stored as an `n x B` matrix, all replicate products can be expressed as:

```text
X'W  =  (p x n) * (n x B)  ->  (p x B)
```

This is genuinely GEMM-shaped when `n`, `p`, and especially `B` are large.
However:

- an FP64 `DGEMM` batched rewrite should be benchmarked first and may capture
  most of the data-reuse benefit without changing numerical semantics;
- AMX needs `X` and `W` represented in a supported low precision (binary `W`
  is exact, but BF16 `X` is not);
- each replicate still requires scalar summaries and a small FP64 solve;
- storing or converting the whole `W` batch can be memory-intensive.

This is the highest-priority existing prototype because it changes `B` GEMVs
into one or a few blocked GEMMs and leaves the final solve in FP64.

`EDI/src/rand_bootstrap_ols_parallel.cpp:22-93` and
`EDI/src/ols_distr_parallel.cpp:112-206` resample different rows for each
replicate. Their per-replicate design matrices differ, so they do not collapse
into one simple GEMM without a larger gather/packing transformation. Keep them
as lower-priority candidates.

### Candidate 2: Euclidean and weighted distance matrices

The direct loops in `EDI/src/optimal_blocks_distance.cpp:152-169` and
`EDI/src/pair_dist_helpers.cpp:56-90` compute all pairwise squared distances.
For unweighted Euclidean distance:

```text
G = X X'
D_ij = ||x_i||^2 + ||x_j||^2 - 2 G_ij
```

`G` is a large GEMM when both the number of rows and features are large.
Weighted Euclidean distance can similarly scale columns before the product.

The risks are substantial:

- the current triangular loop performs roughly half the pair work and writes
  the final result directly; GEMM may calculate more entries and require a
  separate norms/finalization pass;
- BF16 errors can change rankings near the matching/design boundary;
- `n x n` output and packing traffic can dominate;
- Manhattan, Mahalanobis with per-pair quadratic work, and custom distances do
  not all share the same transformation.

The safe AMX formulation is approximate screening followed by FP64 exact
recomputation of every candidate that could plausibly win. It requires a
conservative error bound or an expanding candidate set; “top k under BF16”
without such a guard can silently select the wrong design.

### Candidate 3: future linear-leaf, GP, or kernel features

Linear leaf models, Gaussian-process/kernel matrix construction, and batched
dense predictions could produce large GEMMs, but they are not established
current EDI hotspots in the indexed package. If those features are added, they
should use the common adapter and this plan's precision/dispatch gates rather
than add a separate AMX implementation.

### Candidate 4: deliberately batched model fits

Independent bootstrap fits generally have different resampled data and branch
through separate optimizers. They are parallel tasks, not automatically a
matrix multiplication. A batched AMX implementation is justified only if the
same operation and dimensions can be reorganized into a dense 3-D/batched
primitive with enough shared packing to amortize it. Do not describe an
OpenMP loop over model fits as “AMX-ready.”

## Architecture and implementation plan

### Phase 0: measure shapes before adding a backend

- [ ] **TODO-1: Add a dense-operation census.** Instrument the common adapter
  and selected Eigen sites to record operation (`gemm`, `syrk`, `gemv`, solve),
  datatype, `m/n/k`, strides, call count, bytes packed, and inclusive time.
  Keep counters opt-in and thread-safe.
- [ ] **TODO-2: Produce an end-to-end shape histogram.** Run all 36 native
  estimate/full paths, OLS randomization/bootstrap, pair distances,
  `InferenceSuite`, and `SimulationFramework`. Report how much wall time is in
  true Level-3 work at dimensions large enough to amortize tile setup.
- [ ] **TODO-3: Establish FP64 Intel baselines.** Compare current Eigen/R BLAS,
  OpenBLAS, BLIS, and oneMKL on a Sapphire Rapids host. Record AVX2/AVX-512,
  BLAS threads, frequencies, and whether AVX-512 downclocking affects the
  workflow. This baseline prevents ordinary oneMKL/AVX-512 gains from being
  mislabeled as AMX gains.

Stop gate: if less than 10% of a target workflow is convertible GEMM-shaped
work, or all useful calls are below the measured crossover, do not implement
AMX for that workflow.

### Phase 1: explicit Intel capability detection

Add `EDI_X86_PROFILE=auto|portable|native|sapphirerapids` without changing the
meaning of `EDI_PORTABLE`:

- `EDI_PORTABLE=1` selects baseline x86-64 and excludes AMX instructions from
  the general shared object path.
- Native source builds may compile an isolated AMX translation unit after the
  compiler accepts `-march=sapphirerapids` or the narrower
  `-mamx-tile -mamx-bf16 -mamx-int8` flags.
- Cross-builds never use `native`; an explicit target profile must pass
  compile-only checks.
- The baseline dispatcher must remain executable on non-AMX x86-64 CPUs. Do
  not compile the whole package with mandatory AMX if the artifact will be
  distributed.

- [ ] **TODO-4: Add compile-time probes.** Record compiler target, accepted AMX
  flags, intrinsic/header availability, and whether the optional backend was
  built. A compiler accepting AMX flags is not evidence that the running CPU or
  OS permits AMX.
- [ ] **TODO-5: Add a runtime capability gate.** Check the precise CPUID
  features (AMX-TILE plus the requested BF16/INT8/other datatype), OSXSAVE and
  tile XSTATE support, then request XTILEDATA permission where required. Cache
  success only after the complete check. Any failure selects the FP64 baseline.
- [ ] **TODO-6: Test process and worker behavior.** Request permission before
  launching native threads. Linux documents permission as process-wide,
  inherited across `fork()` and cleared across `exec()`: fork workers should
  verify the inherited state, while PSOCK/exec workers must request permission
  in their new process. Test OpenMP threads, containers, restricted VMs, and
  every supported OS rather than generalizing the Linux behavior.
- [ ] **TODO-7: Extend diagnostics.** `build_info()` should distinguish
  `compiled_with_amx_backend`, `cpu_amx_tile`, `cpu_amx_bf16`,
  `os_xtiledata_permission`, `selected_backend`, and fallback reason. Never
  report simply `amx=yes` when only one layer passed.

### Phase 2: backend choice

Prefer this order:

1. **Vendor/library prototype first.** Use an optional oneMKL or oneDNN
   BF16-matmul interface that already owns blocking, packing, tails, tile
   configuration, and CPU dispatch. The R package must retain its normal BLAS
   fallback and must not require oneAPI to install.
2. **Isolated intrinsic kernel second.** Consider `_tile_*` intrinsics only if
   the library cannot express a proven EDI shape or its overhead is measured as
   the limiter. Place it in a separate translation unit and expose a narrow C
   ABI to the baseline dispatcher.
3. **No global AMX compiler flag.** This protects portable execution and keeps
   accidental tile instructions out of Rcpp/Eigen code paths.

- [ ] **TODO-8: Add a common matrix-backend interface.** Reuse the adapter
  proposed in `arm_hardware.md` for shape, backend, threshold, thread count,
  and fallback selection. Add datatype and accuracy-contract fields rather
  than creating an Intel-only parallel API.
- [ ] **TODO-9: Implement conversion and workspace accounting.** Reuse aligned
  packed buffers across repeated calls; count BF16 conversion, packing, tile
  setup, final conversion, and FP64 correction in elapsed time and peak RSS.
- [ ] **TODO-10: Define one-owner parallelism.** Compare AMX threads, BLAS
  threads, OpenMP replicate threads, and R workers. AMX on every core inside
  every forked worker is an oversubscription bug, not acceleration.

### Phase 3: prototype the two credible candidates

- [ ] **TODO-11: Batch `X'W` in OLS randomization using FP64 `DGEMM`.** This is
  the required control experiment. Preserve replicate order, seeded inputs,
  NA behavior, and FP64 results. Tune batch size to cap memory.
- [ ] **TODO-12: Add an AMX-BF16 `X'W` prototype.** Convert/pack `X` once,
  exploit exact binary treatment indicators where the backend permits, compute
  the batch product, and perform summaries/solves in FP64. Compare raw BF16,
  FP64 residual correction, and full FP64 `DGEMM`.
- [ ] **TODO-13: Prototype Euclidean Gram screening.** Compute approximate
  `XX'` with AMX, derive candidate distances, then recompute a conservative
  candidate set exactly in FP64. Demonstrate that the chosen pairs/design are
  identical on adversarial near-tie fixtures, or drop the prototype.
- [ ] **TODO-14: Do not prototype the weak candidates yet.** GLMM, tiny
  Hessians, rank tests, custom callbacks, and per-replicate resampled OLS stay
  out until the census shows a new large repeated GEMM shape.

### Phase 4: numerical acceptance

- [ ] **TODO-15: Build adversarial matrices.** Cover ill-conditioned and
  rank-deficient designs, rare treatment assignments, high dynamic range,
  collinearity, sparse/zero weights, near-tied distances, and values near
  inferential decision thresholds.
- [ ] **TODO-16: Require final-result parity.** For default/public inference,
  coefficients, standard errors, covariance, p-values, intervals, selected
  designs, failure classifications, and seeded results must satisfy existing
  FP64 equivalence contracts. Kernel-relative error alone is insufficient.
- [ ] **TODO-17: Gate mixed precision by conditioning.** Estimate condition or
  residual quality cheaply. Route questionable matrices directly to FP64;
  retry in FP64 when refinement stagnates or a residual exceeds tolerance.
- [ ] **TODO-18: Record fallback rates.** A fast AMX path that falls back on
  most realistic datasets may lose end-to-end. Benchmarks must include the
  detection, failed attempt, and recomputation costs.

### Phase 5: dispatch and machine tuning

- [ ] **TODO-19: Learn thresholds empirically.** Benchmark grids over `m/n/k`,
  batch count, conditioning, datatype conversion reuse, and thread count. The
  dispatch key includes all of these, not merely CPU model.
- [ ] **TODO-20: Extend `tune_EDI_for_this_machine()`.** Add an optional
  `matrix_backend` axis comparing Eigen, FP64 BLAS, and AMX mixed precision for
  eligible operations. Persist choices under the existing hardware/software
  fingerprint and invalidate them when compiler, BLAS, microcode, kernel, or
  CPU model changes.
- [ ] **TODO-21: Provide deterministic overrides.** Support
  `EDI_MATRIX_BACKEND=auto|eigen|blas|amx|no-amx`. An explicit unavailable
  `amx` request errors with the exact failed capability layer; `auto` silently
  and safely falls back while diagnostics retain the reason.

## Benchmark plan

### Hardware

At minimum compare:

- one pre-AMX AVX-512 Xeon baseline;
- Sapphire Rapids with AMX-BF16/INT8 exposed by the OS;
- one later AMX generation if it offers a relevant additional datatype;
- the same Sapphire Rapids host with AMX forcibly disabled to isolate backend
  effects;
- a matched ARM high-bandwidth host only for end-to-end cost/performance, not
  as evidence about an AMX microkernel.

Record exact CPU SKU, sockets, NUMA mode/SNC, microcode, kernel, compiler,
oneMKL/oneDNN/BLAS versions, memory configuration, frequency, power limits, and
cloud instance type. “Sapphire Rapids” covers many SKUs and memory/core ratios.

### Dimension grid

For GEMM and `X'W`, cover:

- `m/n/k` around tile and cache boundaries, including tails;
- `n` in `{100, 1e3, 1e4, 1e5}` where memory permits;
- covariate count `p` in `{2, 5, 10, 20, 32, 64, 128, 256}`;
- replicate/batch count `B` in `{32, 128, 512, 2048, 8192}`;
- one-shot versus reused packed left/right operand;
- threads in `{1, 2, 4, 8, socket_cores}` and one process per NUMA node.

Small EDI defaults must remain in the table even when they are expected losses.
They determine the dispatch floor.

### Comparisons

Measure separately:

1. current per-replicate Eigen/OpenMP;
2. FP64 Eigen batch;
3. FP64 BLAS `DGEMM`/`DSYRK`;
4. AMX library call excluding conversion (diagnostic only);
5. AMX including conversion, packing, permission, and setup;
6. AMX plus FP64 correction/fallback;
7. complete public EDI workflow.

Report time, throughput, achieved operations/s, memory bandwidth, packing
bytes, peak RSS, energy, fallback rate, error/residual measures, and final
statistical parity. Use randomized ABBA/BAAB order, warm-up, dispersion, and
machine-state controls from `performance_profiling_and_upgrades.md`.

## Speedup estimates

### A-priori ranges, not promises

| Candidate | Kernel/stage estimate | End-to-end estimate | Confidence |
|---|---:|---:|---|
| Current FP64 inference, enabling AMX flags only | 1.0x | 1.0x | High: no FP64 AMX operation is invoked. |
| Large FP64 `DGEMM`/`DSYRK` through tuned oneMKL versus a weak/reference backend | 1.2–3x | 1.02–1.4x | Medium; valuable Intel work, but not AMX. |
| AMX BF16 GEMM versus FP64 GEMM, multiplication only | 2–8x | not applicable | Low-medium; highly shape/thread dependent and excludes conversion/correction. |
| AMX BF16 including conversion and packing, with reusable operand | 1.5–4x for the stage | 1.0–1.3x typical | Low until EDI dimensions are measured. |
| Batched OLS `X'W`: FP64 GEMM versus `B` separate GEMVs | 1.5–6x for `X'W` | 1.1–2x for large `B`; ~1x at defaults | Medium; reuse is real even without AMX. |
| Batched OLS `X'W`: AMX plus FP64 correction versus FP64 GEMM | 1.2–3x if accepted | 1.05–1.5x for large batches | Low; BF16 error and small FP64 solves limit it. |
| Approximate distance screening plus exact refinement | 2–6x screening stage | 1.2–3x only when refinement set stays small | Low; near ties can erase the gain. |
| GLMM, rank, exact-test, or tiny-Hessian paths | 0.8–1.05x | 0.9–1.02x | Medium-high that AMX is the wrong tool. |

Do not cite Intel AI benchmark multipliers as EDI estimates. They compare
different datatypes, models, software stacks, CPUs, or generations and usually
exclude EDI's FP64 final-result requirement.

### Amdahl-law interpretation

For accelerated fraction `f` and stage speedup `s`:

```text
workflow speedup = 1 / ((1 - f) + f / s)
```

Examples:

- 10% of wall time made 4x faster yields only `1.08x` end-to-end;
- 30% made 3x faster yields `1.25x`;
- 70% made 3x faster yields `1.88x`;
- if conversion/correction reduces a nominal 6x multiply to 2x for the whole
  stage, use 2x—not 6x—in the workflow estimate.

The initial release target should therefore be a demonstrated **at least 1.2x
end-to-end win** on a named, naturally large workload, with no default-result
change and no more than a 2% regression in any neighboring dispatch cell.

## Ship, retain experimentally, or stop

Ship an AMX path only if all are true:

1. the workload contains a measured, large GEMM-shaped stage;
2. CPUID and OS permission detection cannot execute AMX accidentally;
3. the optional backend does not make ordinary package installation depend on
   oneAPI or an AMX host;
4. default/public results retain FP64 statistical semantics;
5. conversion, packing, setup, correction, and fallback are included;
6. end-to-end speedup is at least 1.2x across an adjacent size range;
7. the machine tuner and explicit overrides produce explainable decisions.

Retain only as an experimental opt-in if numerical behavior is useful but not
identical, or if the win occurs only at extreme sizes.

Stop after the census or prototype if FP64 GEMM captures the benefit, BF16
correction removes it, candidate refinement is too large, or GEMM is too small
a share of wall time. A well-supported conclusion that AMX is not appropriate
for present EDI is a successful outcome of this plan.

## Risks and non-goals

- No claim that `-march=native` automatically makes Eigen use AMX.
- No whole-package `-march=sapphirerapids` in redistributable binaries.
- No undocumented tile-state assumptions or unguarded intrinsics.
- No silent BF16 replacement for FP64 estimates or inference.
- No AMX optimization of GEMV, scalar math, sorting, branching, or small solves.
- No mandatory oneMKL/oneDNN dependency.
- No benchmark that excludes conversion/packing from its user-visible number.
- No conflation of AVX-512/oneMKL FP64 improvements with AMX improvements.
- No new GP, kernel, or linear-leaf feature merely to justify the hardware;
  those features should be statistically motivated independently.

## Definition of done

This plan is complete when either:

**A. A backend ships:** capability detection, optional build isolation,
diagnostics, numerical gates, fallbacks, tuning, cross-platform tests, and a
reproducible end-to-end benchmark all pass the ship criteria; or

**B. The feature is rejected with evidence:** the shape census and at least one
credible prototype show that current EDI has insufficient GEMM work, FP64
requirements preclude AMX, or total elapsed time does not improve. Record the
negative result and continue using FP64 BLAS/AVX-512.

## Recommended order

TODO-1–3 (shape census and honest FP64 baseline) → TODO-4–7 (safe capability
detection) → TODO-8–10 (optional backend infrastructure) → TODO-11 (FP64 batch
control) → TODO-12 (AMX OLS prototype) → TODO-15–18 (numerical gate) → TODO-13
(distance screening only if OLS infrastructure succeeds) → TODO-19–21
(dispatch and tuning).

Do not start intrinsic-kernel work before TODO-1–3. The likely first useful
optimization is batched FP64 `X'W`; AMX is the optional experiment after that
control establishes that the restructured workload is actually GEMM-bound.

## References

Repository evidence:

- `EDI/configure:48-82`
- `EDI/src/build_info.cpp:66-101`
- `EDI/R/globals.R:1474-1522`
- `EDI/R/local_machine_tuning.R:296-514`
- `EDI/src/_helper_functions_core.h:272-429`
- `EDI/src/fast_ols.cpp:14-72,91-201`
- `EDI/src/ols_distr_parallel.cpp:15-206`
- `EDI/src/rand_bootstrap_ols_parallel.cpp:22-93`
- `EDI/src/optimal_blocks_distance.cpp:152-225`
- `EDI/src/pair_dist_helpers.cpp:56-90`
- `EDI/src/fast_gaussian_lmm.cpp:221-305,557-623`
- `performance_profiling_and_upgrades.md:43-133,2528-2558,2574-2619`
- `arm_hardware.md:347-390`

Primary documentation:

- [Intel AMX overview](https://www.intel.com/content/www/us/en/products/docs/accelerator-engines/what-is-intel-amx.html)
- [Intel AMX intrinsics code sample and tile/XSTATE requirements](https://www.intel.com/content/www/us/en/developer/articles/code-sample/advanced-matrix-extensions-intrinsics-functions.html)
- [Intel 4th-generation Xeon Scalable architecture overview](https://www.intel.com/content/www/us/en/developer/articles/technical/fourth-generation-xeon-scalable-family-overview.html)
- [Intel Intrinsics Guide](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html)
- [Intel Architecture Instruction Set Extensions Programming Reference](https://cdrdv2-public.intel.com/843860/architecture-instruction-set-extensions-programming-reference-dec-24.pdf)
- [Linux kernel XSTATE userspace documentation](https://www.kernel.org/doc/Documentation/x86/xstate.rst)
