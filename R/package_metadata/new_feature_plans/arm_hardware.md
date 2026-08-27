# ARM / Apple Silicon as a First-Class Target

Date: 2026-08-27

Status: implementation plan; all speedups below are planning estimates, not
EDI measurements.

## Executive summary

EDI should support AArch64 as a first-class performance target across three
machines with different strengths:

- AWS Graviton4 for inexpensive, high-throughput cloud simulation;
- Apple M-series for developer workstations and dense linear algebra through
  Accelerate;
- NVIDIA Grace for large-memory, memory-bandwidth-heavy workloads and
  high-core-count simulation.

This is not primarily a porting project. The package is already C++20,
RcppEigen-based, uses OpenMP conditionally, and links R's configured
BLAS/LAPACK. Its source-build default also uses `-march=native -mtune=native`,
which maps naturally to NEON/SVE on ARM. The project is instead to make ARM a
tested, measured, observable target and to route the few genuinely dense
stages to the best library backend without slowing the many small-`p`,
loop-heavy likelihood kernels.

The expected payoff is workload-dependent:

- **First-class support alone:** correctness and reproducibility, not a
  promised speedup.
- **ARM-native compiler, layout, and thread tuning on the same ARM host:**
  approximately **1.05–1.25x in affected native kernels** and **1.02–1.15x
  end-to-end**.
- **Tuned BLAS/Accelerate routing for sufficiently large dense stages:**
  approximately **1.3–3x for the routed stage**, occasionally up to **4x**
  against an untuned/reference baseline, translating to roughly **1.05–1.5x
  for a typical mixed workflow** and **1.2–2x for a deliberately
  dense-dominated workflow**.
- **Moving a bandwidth-heavy workload from Graviton3 to Graviton4:** a
  planning range of **1.2–1.6x**, below the hardware's 1.75x bandwidth ceiling.
- **Large, parallel workloads on Grace:** approximately **1.2–2x versus a
  conventional server baseline** when memory bandwidth or memory capacity is
  the actual limiter; small or transcendental-heavy fits may see no gain.

These ranges must not become release claims until the benchmark matrix in this
report is run. In particular, “ARM” is not one performance class, cloud price
comparisons change by region and date, and Apple AMX is not a public API that
EDI can call directly.

## Why this fits EDI

### Current native architecture

The package already has most of the portability foundation:

- `EDI/configure:23-29` exposes portable, vectorization, native-speed, LTO,
  and debug build controls.
- `EDI/configure:48-72` generates portable Makevars and enables host-native
  code generation for source builds.
- `EDI/configure:57-59` links `$(LAPACK_LIBS) $(BLAS_LIBS) $(FLIBS)` rather
  than hard-coding an x86 library.
- `EDI/src/build_info.cpp:66-101` reports compiler flags and whether Eigen
  vectorization was disabled.
- `EDI/R/globals.R:1474-1522` coordinates OpenMP, BLAS, data.table, and R
  worker thread counts, including `VECLIB_MAXIMUM_THREADS`.
- `EDI/src/_helper_functions_core.h:405-429` already implements
  `symmetric_crossprod()` with BLAS `DSYRK`; the standalone core uses CBLAS
  and the R build uses R's BLAS interface.
- `EDI/src/fast_ols.cpp:14-72` uses that cross-product plus Eigen LDLT/QR.

The SIMD plan explicitly treats NEON/SVE as outputs of the native source build
and leaves ARM validation, AMX, and high-bandwidth-memory work to this plan
(`more_simd_optimization.md:26-43,182-183`). This report should consume the
measurement work owned by `performance_profiling_and_upgrades.md`, especially
its TODO-136, 143, 147, 148, 155, 171, 175, and 176, rather than duplicate it.

### Where the hardware can help

The current profile points to three distinct groups:

1. **Dense and semi-dense linear algebra.** OLS cross-products, weighted
   information matrices, covariance solves, GEE, Gaussian LMM, robust
   post-fit covariance, and some design searches perform `X'X`, `X'y`, GEMV,
   symmetric rank updates, factorizations, or small Hessian solves. Examples
   include `fast_ols.cpp:14-72`, `fast_gee.cpp:62-74,118-271`,
   `fast_gaussian_lmm.cpp:221-305,557-623`,
   `robust_post_fit_speedups.cpp:71-237`, and
   `_helper_functions_core.h:272-429,1165-1176`.
2. **Streaming and replicate-parallel kernels.** Pair distances,
   Mahalanobis/weighted distances, bootstrap distributions, randomization
   loops, and simulation DGPs read large arrays with modest arithmetic. These
   can benefit from bandwidth per core and many physical cores, subject to
   thread thresholds and NUMA placement.
3. **Likelihood and GLMM kernels.** The profile identifies repeated
   `exp`/`log`/`log1p`, grouped reductions, and Eigen GEMV in ordinal CLMM,
   logistic GLMM, Weibull frailty, clogit-plus-GLMM, and Poisson GLMM
   (`performance_profiling_and_upgrades.md:111-133`). These are mixed kernels;
   merely swapping BLAS cannot accelerate their scalar special functions or
   optimizer iteration count.

The broader profile is also a warning against over-selling matrix units.
`d_optimal_search`, ZINB, and ZAP dominate one broad sweep, while pair-distance
and Gaussian-LMM full paths are smaller shares
(`performance_profiling_and_upgrades.md:97-109`). Dense-library acceleration
must therefore be dispatched by operation and size, not enabled globally and
described as an end-to-end multiplier.

## Hardware facts and the correct interpretation

### AWS Graviton4

AWS documents Graviton4 R8g as providing up to 30% more performance than R7g,
with 75% more memory bandwidth and twice the L2 cache. An AWS HPC case study
identifies 96 Neoverse V2 cores and 12 DDR5-5600 channels. These are useful
ceilings, not an EDI speedup guarantee:

- a perfectly bandwidth-bound kernel cannot gain more than 1.75x from the
  advertised generation-to-generation bandwidth increase;
- an entirely compute-bound workload should be budgeted nearer the advertised
  1.30x ceiling;
- mixed EDI workflows must fall below the appropriate ceiling after R,
  allocation, optimization, and serial fractions are included.

R8g/C8g/M8g are the practical CI and cloud-throughput targets. R8g/X8g are
useful when memory per worker limits simulation scale. Price/performance must
be calculated from current regional prices at benchmark time; this document
does not freeze a price that will become stale.

### Apple M-series

Apple's Accelerate framework provides BLAS and LAPACK, including the CBLAS C
interface, and selects processor-appropriate instructions at runtime.
Representative high-end generations illustrate the bandwidth available:
Apple documents up to
546 GB/s for M4 Max and 819 GB/s for M3 Ultra. Lower-tier M-series chips have
far less bandwidth, so results from an Ultra must not be generalized to every
Mac.

The implementation contract is **Accelerate/CBLAS**, not AMX. Apple's
undocumented matrix coprocessor is commonly called AMX, and Accelerate may use
processor-specific acceleration internally for eligible operations, but Apple
does not expose a stable
“call AMX” API or promise that a particular CBLAS size/type uses it. EDI should
call documented BLAS/LAPACK routines, verify the linked backend, and report
measured performance. It should never ship private AMX instructions or claim
AMX utilization merely because `cblas_dgemm()` was called.

The unified-memory headline also needs care: CPU-only EDI cannot assume access
to the full GPU-advertised bandwidth for every access pattern. STREAM and
kernel measurements, not the product number, determine the CPU roofline.

### NVIDIA Grace

NVIDIA documents 72 Neoverse V2 cores and up to 500 GB/s CPU memory bandwidth
for one Grace CPU, or 144 cores and up to 1 TB/s for the two-die Grace CPU
Superchip. The Superchip is a NUMA system joined by NVLink-C2C. It is an
excellent target for large streaming kernels and many independent
replications, but only if memory is first-touched near the worker that uses it
and threads are not allowed to wander across NUMA domains.

On Grace, candidate BLAS providers include OpenBLAS, Arm Performance Libraries,
and NVIDIA Performance Libraries. Arm reports that recent ArmPL releases tune
DGEMM for Neoverse V2 and use thread throttling for smaller calls. EDI should
select through R's BLAS configuration or a documented optional standalone-core
configuration, not acquire a mandatory proprietary dependency.

## Proposed implementation

### Phase 0: establish correctness and observability

- [ ] **TODO-1: Add the ARM CI matrix.** Test `linux-aarch64` and
  `macos-arm64` source builds, package tests, compiled-kernel equivalence, and
  installation with `EDI_PORTABLE=1`. Keep x86-64 as the parity reference.
  Add a scheduled native-speed lane with `EDI_PORTABLE=0`; it is a performance
  smoke test, not a distributable binary.
- [ ] **TODO-2: Add a Grace periodic lane.** A self-hosted or rented Grace
  runner should execute the large benchmark subset and NUMA checks. It need
  not block every pull request.
- [ ] **TODO-3: Extend `build_info()`.** Record `architecture`, CPU model,
  compiler target flags, SIMD macros (`__ARM_NEON`, `__ARM_FEATURE_SVE`, and
  SVE vector length when discoverable), BLAS/LAPACK paths, CBLAS availability,
  OpenMP runtime, logical/physical core counts, and macOS Accelerate status.
  Do not infer “AMX active.”
- [ ] **TODO-4: Add an ARM diagnostic helper.** `EDI:::arm_diagnostics()`
  should report the above plus effective OpenMP/BLAS thread limits and, on
  Linux, NUMA node count. It should provide actionable warnings for an x86
  binary running through Rosetta, a portable binary on a known native host,
  or nested BLAS/OpenMP/R-worker parallelism.

Acceptance gate: all public tests and C++ equivalence tests pass natively on
both operating systems, and benchmark output records enough context to
reproduce the binary and backend.

### Phase 1: make native compilation intentional

#### Explicit configure-time hardware selection algorithm

`EDI_ARM_PROFILE=auto` must be a real decision procedure, not an alias for a
single hard-coded flag. Implement it in `EDI/configure` with the following
inputs, precedence, probes, and recorded outputs.

**Inputs and precedence**

1. `EDI_PORTABLE=1` always wins and selects `portable`. This is the CRAN,
   redistributable-binary, and maximum-compatibility mode.
2. An explicit `EDI_ARM_PROFILE=portable|apple|neoverse-v2` wins over automatic
   model recognition, but its flags must still pass compiler-target and
   compile-only checks. An invalid explicit request is an error rather than a
   silent downgrade.
3. `EDI_ARM_PROFILE=auto` selects a native profile only for a native source
   build. If the build is a cross-compile, `auto` selects `portable`; obtaining
   target-specific code then requires an explicit non-native target profile.
4. `EDI_ARM_FLAGS` is an expert override for reproducible experiments. It must
   be compile-tested, printed prominently by `configure`, and captured by
   `build_info()`. It is never inferred or enabled by CI.

**Detect the compiler target, not merely the machine running `configure`**

- Read the actual C++20 compiler and standard flag from `R CMD config CXX20`
  and `R CMD config CXX20STD`.
- Ask that compiler for its target triple (for example with `-dumpmachine`),
  then confirm it by preprocessing a tiny input and inspecting predefined
  macros such as `__aarch64__`, `__arm64__`, `__APPLE__`, and `__linux__`.
- Normalize equivalent architecture names (`arm64` and `aarch64`, `amd64` and
  `x86_64`) before comparing the target with the build machine returned by
  `uname -m`.
- Treat a normalized mismatch, an explicit cross target/sysroot, or
  `EDI_CROSS_COMPILE=1` as cross-compilation. Never use `-mcpu=native`,
  `-march=native`, or `-mtune=native` in that state: `native` would describe
  the build machine, not necessarily the target.
- The compiler target is authoritative. For example, an x86-64 compiler under
  Rosetta on an Apple Silicon Mac must produce the x86 profile, not an arm64
  binary with Apple flags. The runtime diagnostic may recommend reinstalling
  with a native arm64 R/toolchain.

All feature tests in `configure` must be **compile-only**. Do not execute a
probe binary, because that fails for legitimate cross-builds.

**Select and validate flags**

For each candidate, compile a minimal C++20 translation unit with the proposed
flags using the same compiler family that R will use. A rejected flag advances
the automatic fallback chain; it fails an explicit profile.

| Compiler target and mode | Candidate chain |
|---|---|
| Native Apple arm64 + `auto` | Apple Clang `-mcpu=native`; if rejected, try the compiler's supported native equivalent; if none is accepted, use the Apple arm64 toolchain default. Do not replace this with a permanent `apple-m1` flag, which would under-target later chips. |
| Native Linux AArch64 + `auto` | `-mcpu=native`; then `-march=native -mtune=native`; then the toolchain's baseline AArch64 target. |
| Explicit `neoverse-v2` | `-mcpu=neoverse-v2`; if the compiler only supports split controls, compile-test the documented `-march` plus `-mtune=neoverse-v2` equivalent. This profile covers Graviton4 and Grace because both use Neoverse V2 cores. |
| Explicit `apple` | Require an Apple arm64 compiler target. For a native build use the accepted Apple Clang `-mcpu=native` form; for a cross-build use a user-supplied Apple target/sysroot and a compile-tested explicit CPU flag, never `native`. |
| `portable` | Use the AArch64 baseline supplied by R's target toolchain, with no host-native CPU flag. Add an explicit baseline `-march` only if the toolchain requires and accepts it. |
| Non-ARM target | Preserve the existing x86/other-platform policy; the ARM selector makes no changes. |

Keep `-O3`, debug, LTO, and vectorization controls orthogonal to the CPU
profile. In particular, selecting `neoverse-v2` must not silently enable LTO or
unsafe fast-math.

**Verify SVE and NEON after flag selection**

Preprocess a second tiny input under the final flags and record the resulting
macros:

- `__ARM_NEON` / `__ARM_NEON__` for NEON;
- `__ARM_FEATURE_SVE` for SVE;
- `__ARM_FEATURE_SVE2` for SVE2;
- `__ARM_FEATURE_FMA` and other features used by measured kernels;
- `__ARM_FEATURE_SVE_BITS` only when the compiler intentionally fixes a vector
  length.

For `neoverse-v2`, absence of `__ARM_FEATURE_SVE` after the accepted flags is a
configuration failure, because the requested profile was not actually
produced. For `auto`, absence of SVE is valid on Apple Silicon and older/generic
AArch64: record `NEON=yes, SVE=no` and continue. EDI should generate
vector-length-agnostic SVE by default; do not add `-msve-vector-bits=<N>` unless
a separate benchmark selects it for a non-portable deployment.

Macro presence proves that the compiler may emit the ISA, not that a hot loop
was vectorized. TODO-6's optimization reports and disassembly spot checks
provide that second proof.

**Fallback behavior and audit trail**

The automatic fallback is:

```text
explicit portable or EDI_PORTABLE=1
    -> target-toolchain baseline
cross-compile + auto
    -> target-toolchain baseline
native ARM + auto
    -> accepted -mcpu=native
    -> accepted native -march/-mtune equivalent
    -> target-toolchain baseline
```

Every configure run should emit one concise summary and compile it into
`build_info()`:

```text
target=aarch64-unknown-linux-gnu
cross_compile=no
requested_profile=auto
selected_profile=native-aarch64
selection_reason=accepted:-mcpu=native
cpu_flags=-mcpu=native
neon=yes sve=yes sve2=yes sve_bits=scalable
blas=<resolved backend/path> openmp=<runtime or none>
rejected_candidates=<flag:compiler diagnostic, ...>
```

Add preprocessor definitions such as `EDI_ARCH_PROFILE`,
`EDI_ARCH_SELECTION_REASON`, `EDI_BUILD_TARGET`, `EDI_ARM_NEON_ENABLED`, and
`EDI_ARM_SVE_ENABLED` so `build_info.cpp` reports what the loaded shared object
was actually built to use. Keep the configure log's full compiler diagnostics;
the public summary should remain short.

This compile-time selection maximizes source builds for their host. It cannot
make one CRAN binary optimal for every ARM CPU. Portable binaries obtain most
dense-operation specialization from runtime-dispatching libraries such as
Accelerate, ArmPL, NVPL, or OpenBLAS. EDI-owned runtime multiversioning
(baseline/NEON/SVE variants) is a separate future option only if portable
binary benchmarks show enough uncovered hot-loop time to justify its testing
and maintenance cost.

- [ ] **TODO-5: Give `configure` named ARM profiles.** Add
  `EDI_ARM_PROFILE=auto|portable|apple|neoverse-v2` and implement the complete
  selection algorithm above. `portable` emits baseline AArch64 code; `auto`
  uses the strongest accepted host-native compiler target only when the build
  is demonstrably native. The named profiles are developer/benchmark controls
  and must validate the compiler target before adding flags; they are not
  silently used for cross-built CRAN binaries.
- [ ] **TODO-6: Verify compiler output rather than add intrinsics.** Consume
  the SIMD plan's optimization-report audit and confirm NEON/SVE on the hot
  raw-pointer loops. Use `-mcpu=native`/the compiler-supported equivalent only
  where it improves over the existing `-march=native -mtune=native` behavior.
  Keep hand-written `arm_neon.h`/SVE intrinsics out of scope until a specific
  hot loop fails auto-vectorization and a measured prototype wins.
- [ ] **TODO-7: Close the macOS OpenMP-SIMD gap.** Coordinate with
  `more_simd_optimization.md → TODO-7`: allow `-fopenmp-simd` where Apple
  clang accepts it, while keeping threaded OpenMP optional. Do not make a
  Homebrew `libomp` installation a package requirement.
- [ ] **TODO-8: Add ARM compile-report artifacts.** Save vectorization
  reports for the six files containing `#pragma omp simd` and the top ten hot
  likelihood/distance loops. CI should check capabilities and correctness;
  it should not fail on exact assembly text that changes with compilers.

### Phase 2: introduce a narrow dense-linear-algebra adapter

Do not set `EIGEN_USE_BLAS` globally. EDI contains many tiny matrices where
library-call and thread-launch overhead can exceed the arithmetic, and a global
switch makes it hard to know which expressions were rerouted. Instead add a
small internal adapter with explicit operations and measured thresholds:

- `edi_dsyrk()` for unweighted symmetric cross-products;
- `edi_dgemv()` for large contiguous matrix-vector products;
- `edi_dgemm()` for genuinely matrix-matrix stages;
- `edi_dpotrf()`/`edi_dpotrs()` or an equivalent SPD solve where the existing
  fallback contract permits it;
- Eigen implementations for small, strided, irregular, or fallback cases.

- [ ] **TODO-9: Preserve and generalize the existing `DSYRK` path.** Move the
  calling convention and backend selection behind the adapter. The R package
  should prefer `R_ext/BLAS.h`/`R_ext/Lapack.h`, so it uses the BLAS selected by
  R. The standalone/Python core may use CBLAS after configure proves it is
  present.
- [ ] **TODO-10: Add backend-specific configuration without hard-coding it.**
  On macOS standalone builds, detect and link Accelerate. On Linux, accept a
  user-supplied BLAS through the existing R/toolchain configuration and test
  OpenBLAS, BLIS, ArmPL, and NVPL externally. Preserve the portable fallback.
- [ ] **TODO-11: Benchmark dispatch thresholds.** Tune by operation, matrix
  dimensions, contiguity, and thread count. Start with `p <= 20` as an
  Eigen-first hypothesis, not a fixed policy; test `p` in
  `{2, 5, 10, 20, 32, 64, 128, 256}` and `n` in
  `{100, 1e3, 1e4, 1e5}`. Store thresholds per machine through the existing
  local-machine tuning mechanism rather than a growing architecture table.
- [ ] **TODO-12: Prototype weighted `X'WX` via BLAS.** Compare the current
  `weighted_crossprod()` loops with (a) materializing `sqrt(w) * X` then
  `DSYRK`, and (b) blocked rank updates. Include the materialization cost.
  Keep the current implementation for small `p` or when zero/signed weights
  make the transformation inappropriate.
- [ ] **TODO-13: Audit large GEMV sites.** Start with GLMM, Gaussian LMM, GEE,
  robust post-fit, and g-computation kernels identified by the profile. A
  CBLAS call is retained only if transfer/copy-free and faster across an
  adjacent size range, not at one cherry-picked dimension.
- [ ] **TODO-14: Replace explicit inverses with factored solves where
  semantics permit.** This overlaps `performance_profiling_and_upgrades.md →
  TODO-155`; that TODO owns discovery, while this item owns ARM-backed adapter
  implementation after a site is approved. Preserve rank-deficient fallbacks
  and numerical tolerances.

### Phase 3: exploit bandwidth without multiplying memory traffic

- [ ] **TODO-15: Classify hot loops by roofline on each machine family.** Use
  STREAM-like measured bandwidth plus per-kernel counters. A high product
  bandwidth number is not enough; report achieved GB/s, arithmetic intensity,
  and percentage of the measured roof.
- [ ] **TODO-16: Remove avoidable full-size temporaries and boundary copies.**
  Prioritize pair-distance matrices, weighted distances, bootstrap matrices,
  DGP generation, and GLMM workspaces. On Apple unified memory this still
  matters: CPU copies consume bandwidth even without PCIe transfer.
- [ ] **TODO-17: Keep both row- and column-oriented layouts only when reuse
  repays the copy.** Observation-wise likelihood loops often want row-major
  storage, while BLAS and R inputs are naturally column-major. Build the
  alternate layout once per reusable fit/cache, never once per optimizer
  evaluation.
- [ ] **TODO-18: Add NUMA-aware Grace execution.** Detect the two NUMA nodes,
  benchmark one process per NUMA node versus a single 144-core process, first
  touch workspaces on the owning node, and pin OpenMP teams. Default changes
  require a repeatable win and must fall back cleanly when `numactl` or topology
  APIs are unavailable.
- [ ] **TODO-19: Tune replicate chunks.** For randomization/bootstrap kernels,
  give each worker a contiguous block large enough to reuse read-only inputs
  and avoid false sharing. Compare static scheduling with machine-tuned chunk
  sizes; do not assume all 144 Grace cores or all Apple performance/efficiency
  cores should be used for small jobs.

### Phase 4: thread policy and user-facing controls

- [ ] **TODO-20: Make one layer own parallelism.** Benchmark `(R workers,
  OpenMP threads, BLAS threads)` combinations. Dense BLAS inside replicate
  workers should normally use one BLAS thread; a single large dense operation
  may instead give threads to BLAS. Prevent the `workers x OMP x BLAS`
  explosion already identified in the performance plan.
- [ ] **TODO-21: Validate Apple thread control.** Test whether
  `VECLIB_MAXIMUM_THREADS`, `RhpcBLASctl`, and process-start timing actually
  constrain the linked Accelerate version. Report observed behavior instead
  of assuming the environment variable is sufficient.
- [ ] **TODO-22: Add architecture presets to local tuning.** Suggested labels
  are `arm-throughput`, `apple-interactive`, and `grace-bandwidth`, but the
  preset should seed a short empirical tuner rather than encode permanent
  magic numbers.
- [ ] **TODO-23: Document cloud deployment.** Provide reproducible source-build
  recipes for Graviton4 and Grace, including compiler/BLAS choice, core pinning,
  and recorded build info. Keep optional vendor libraries outside required
  package dependencies.

## Benchmark and validation plan

### Platforms

Use at least:

| Family | Minimum representative host | Dense backends |
|---|---|---|
| x86-64 reference | Existing benchmark machine | current R BLAS and one tuned BLAS |
| Apple Silicon | one base/Pro and one Max/Ultra if available | Accelerate; optional OpenBLAS comparison |
| Graviton4 | C8g and R8g at matched vCPU counts | system/OpenBLAS; ArmPL where available |
| Grace | one 72-core CPU or Grace Hopper, plus a 144-core Superchip when available | NVPL, ArmPL, OpenBLAS |

Do not compare a laptop's single-core time with a 144-core server's throughput
and call it an architecture result. Publish three separate comparisons:

1. same thread count and roughly matched core count;
2. full-machine maximum throughput;
3. cost per completed simulation or inference workflow using contemporaneous
   cloud prices.

### Workloads

- Dense microbenchmarks: `DSYRK`, `DGEMV`, `DGEMM`, weighted `X'WX`, LDLT/QR,
  and covariance solves across the dimension grid in TODO-11.
- Native model fits: all 36 estimate/full paths from
  `profile/edi_kernel_profiler.R`, emphasizing OLS, GEE, Gaussian LMM,
  logistic/ordinal/Poisson GLMM, frailty, ZINB/ZAP, and Cox.
- Streaming kernels: pair distances, Mahalanobis/weighted distances,
  randomization loops, and bootstrap distributions at default, 10x, and 100x
  work sizes.
- End-to-end workflows: `InferenceSuite`, a resampling-heavy inference path,
  `SimulationFramework`, and the Python binding benchmark.

### Measurement discipline

- Record elapsed and CPU time, throughput, peak RSS, energy where available,
  achieved memory bandwidth, cycles/instructions, vector instructions, thread
  count, BLAS backend, compiler, temperature/frequency state, and cloud price.
- Use warm-up followed by randomized ABBA/BAAB ordering and enough repetitions
  to report median plus dispersion. Isolate noisy cloud neighbors by repeating
  on at least three fresh instances for release-level claims.
- Include setup, materialization, copying, and thread-launch costs. A library
  call timed after prepacking is a diagnostic, not the user-visible result.
- Validate estimates, gradients, Hessians, covariance matrices, p-values, and
  deterministic seeded resampling against the x86 reference. Use the existing
  equivalence tolerances; any relaxation requires a numerical explanation.
- Run single-thread first. Multi-thread comparisons are invalid until nested
  parallelism and affinity are recorded.

## Speedup estimates and derivation

### Baselines

Every result must name one of these baselines:

- **same ARM host, portable build**: isolates compiler and EDI changes;
- **same ARM host, current EDI native build**: isolates the new adapter/layout;
- **matched x86 host**: estimates hardware migration;
- **previous hardware generation**: e.g. Graviton3 to Graviton4;
- **cost-normalized cloud run**: completed workloads per current dollar.

Without the baseline, “2x on ARM” is not meaningful.

### A-priori ranges

| Change / workload | Affected-stage estimate | Plausible end-to-end estimate | Confidence and limiting factor |
|---|---:|---:|---|
| Native ARM flags and confirmed NEON/SVE versus portable ARM build | 1.05–1.25x | 1.02–1.15x | Medium; many loops already vectorize, and special functions/branches remain. |
| Accelerate/tuned BLAS for large contiguous `DSYRK`/`DGEMM` versus untuned or Eigen generic path | 1.5–4x | 1.05–1.5x typical; 1.2–2x dense-dominated | Low-medium until dimensions are known; small calls can regress. |
| Tuned BLAS versus already tuned OpenBLAS/ArmPL/NVPL | 1.0–1.5x | 1.0–1.2x | Medium; this is the more honest backend-to-backend range. |
| Weighted `X'WX` materialize + `DSYRK` | 1.15–2.5x when large | 1.03–1.35x | Low; an extra `n x p` pass may erase the BLAS gain. |
| Graviton4 versus Graviton3, bandwidth-heavy kernel | 1.2–1.6x | 1.1–1.4x mixed workflow | Medium; bounded by AWS's 1.75x bandwidth and 1.30x compute claims. |
| Grace versus conventional server, large streaming/replicate workload | 1.2–2x | 1.1–1.7x | Low-medium; capacity, NUMA, and baseline selection dominate. |
| Grace or Graviton for small, scalar/transcendental-heavy model fits | 0.8–1.3x | 0.9–1.2x | Low; high bandwidth and core count may be irrelevant. |
| Correcting nested parallelism or Grace NUMA placement | 1.2–3x on an affected run | 1.1–2x | Medium that bad configurations exist; zero gain if already correct. |
| Many independent simulation replications using all physical cores | 1.5–5x throughput over a small workstation | workload-specific | Low as an architecture claim; mostly a core-count/capacity comparison. |

The upper BLAS range is intentionally limited to large, favorable operations.
Most EDI regressions use modest `p`; a `p x p` solve with `p <= 20` is too small
to justify AMX/SVE marketing claims and may run faster in Eigen with one thread.

### Amdahl-law checks

Use

`workflow_speedup = 1 / ((1 - f) + f / stage_speedup)`,

where `f` is the measured pre-change fraction of wall time in the accelerated
stage. For example:

- if dense linear algebra is 30% of a workflow and becomes 2.5x faster, the
  end-to-end gain is only `1 / (0.70 + 0.30 / 2.5) = 1.22x`;
- if it is 60%, the same kernel improvement yields `1.56x`;
- if memory-bound work is 50% and Graviton4 makes it 1.6x faster, the workflow
  gains `1.23x`.

This is why the release target should initially be **1.1–1.4x end-to-end on
workloads selected because ARM matches their bottleneck**, with larger numbers
reported only for named dense or high-throughput workloads.

## Risks and non-goals

- **No undocumented AMX instructions.** Accelerate is the supported boundary.
- **No global `EIGEN_USE_BLAS` until proven safe and faster.** Explicit dispatch
  is observable and protects tiny matrices.
- **No mandatory vendor BLAS.** The package remains installable with R's normal
  BLAS/LAPACK; ArmPL/NVPL are optional deployment choices.
- **No ARM-wide result.** Apple base chips, Ultra chips, Graviton4, and Grace
  differ in core topology, vector ISA, bandwidth, memory capacity, and OS.
- **No blind full-core default.** Apple efficiency cores, Grace NUMA, BLAS
  throttling, and nested workers can make “all cores” slower.
- **No reduced precision for inferential linear algebra.** FP32/BF16/AI matrix
  units are out of scope for estimates, Hessians, solves, and covariance unless
  a separate numerical-analysis plan proves statistical equivalence. EDI's
  current dense paths are primarily FP64.
- **No promise from peak bandwidth.** Achieved CPU bandwidth and arithmetic
  intensity control speedup.
- **No cloud-price constant.** Record region, purchase model, date, instance,
  and actual billed price with each price/performance result.

## Definition of done

ARM/Apple Silicon is first-class when:

1. native Linux AArch64 and macOS arm64 correctness lanes are required and
   stable;
2. `build_info()` identifies architecture, vector capability, BLAS/LAPACK,
   OpenMP, and effective thread policy without claiming undocumented AMX use;
3. Graviton4, at least two Apple performance tiers, and Grace have reproducible
   benchmark reports containing microkernel and end-to-end results;
4. dense dispatch thresholds are measured, include setup cost, and never cause
   a material regression in the adjacent tested size bins;
5. Grace NUMA and nested-parallel policies are documented and machine-tuned;
6. numerical parity and seeded reproducibility pass across x86-64 and AArch64;
7. every public speed claim names hardware, backend, dimensions, thread count,
   baseline, uncertainty, and whether it is kernel or end-to-end speedup.

## Recommended order

TODO-1–4 (correctness and observability) → TODO-5–8 (native compiler proof) →
TODO-9–11 (adapter and thresholds) → TODO-12–14 (only measured dense targets) →
TODO-15–19 (roofline, layout, and Grace NUMA) → TODO-20–23 (thread policy and
deployment documentation).

The first shippable increment is CI plus diagnostics. The first performance
increment is the explicit dense adapter around the already-proven `DSYRK`
pattern. Grace NUMA tuning follows only after a large workload demonstrates
that bandwidth or locality, rather than scalar math or R overhead, is limiting.

## References

Repository evidence:

- `EDI/configure:23-115`
- `EDI/src/_helper_functions_core.h:40-61,272-429,1165-1176`
- `EDI/src/fast_ols.cpp:14-72,91-201`
- `EDI/src/fast_gee.cpp:62-74,118-271`
- `EDI/src/fast_gaussian_lmm.cpp:221-305,557-623`
- `EDI/R/globals.R:1474-1522`
- `EDI/src/build_info.cpp:66-101`
- `performance_profiling_and_upgrades.md:43-133,2528-2558,2574-2619`
- `more_simd_optimization.md:26-43,154-183`

Primary platform documentation:

- [Apple Accelerate](https://developer.apple.com/documentation/accelerate)
- [Apple Accelerate BLAS / CBLAS](https://developer.apple.com/documentation/accelerate/blas-library)
- [Apple Mac Studio technical specifications](https://www.apple.com/mac-studio/specs/)
- [AWS Graviton4 R8g](https://aws.amazon.com/ec2/instance-types/r8g/)
- [AWS Graviton4 R8g generation comparison](https://aws.amazon.com/blogs/aws/aws-graviton4-based-amazon-ec2-r8g-instances-best-price-performance-in-amazon-ec2/)
- [NVIDIA Grace Performance Tuning Guide](https://docs.nvidia.com/dccpu/grace-perf-tuning-guide/index.html)
- [Arm Performance Libraries](https://developer.arm.com/tools-and-software/arm-performance-libraries)
- [R: Writing R Extensions, numerical analysis and BLAS/LAPACK linking](https://stat.ethz.ch/R-manual/R-devel/doc/manual/R-exts.html)
