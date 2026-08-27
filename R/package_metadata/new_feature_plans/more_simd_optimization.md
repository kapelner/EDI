# More SIMD Optimization (Source-Build Power Users)

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-4c`;
> 2026-08-27, user decision). Sits in the Phase 4 kernel/perf lane of
> `_master.md` alongside `performance_profiling_and_upgrades.md` §8. No Phase 0
> dependency; measurement-first.
>
> **Depends on:** nothing gated. Overlaps with, and should be executed
> jointly with, `performance_profiling_and_upgrades.md` TODO-136 (Eigen
> vectorization re-verify), TODO-137 (libmvec), TODO-144 (strided access),
> TODO-154 (branch-free layout), TODO-168 (opt-report sweep). Where an item
> below duplicates one of those, the *owning* TODO is the one in
> `performance_profiling_and_upgrades.md`; this file is the SIMD-specific
> ordering and rationale, and its TODOs cross-reference rather than re-own.

Date: 2026-08-27

## Premise

The distribution model for EDI's native code is **power users compile from
source** (`configure` → `-march=native -mtune=native -O3`, OpenMP, Eigen
packet math on by default since `EIGEN_DONT_VECTORIZE` became opt-in under
`EDI_DISABLE_VECTORIZATION=1`). That settles the question of runtime ISA
dispatch (`__builtin_cpu_supports`, `target_clones`, multi-versioned
binaries): **not needed** — every build already targets the host's widest
vector ISA (AVX2/AVX-512 on x86, NEON/SVE on ARM). Intrinsics-level code is
likewise not planned; there are zero `immintrin.h`/`arm_neon.h` includes in
`src/` and that is fine.

What remains is making sure the compiler *actually* vectorizes the hot
loops, and reshaping the loops it refuses. Today `src/` carries nine
`#pragma omp simd` sites across six files (`_helper_functions_core.h`,
`pair_dist_helpers.cpp`, `ols_distr_parallel.cpp`,
`simple_mean_diff_parallel.cpp`, `compute_mahal_distances.cpp`,
`compute_weighted_distances.cpp`) plus Eigen/BLAS for the dense stages.
Nobody has yet asked the compiler which loops it gave up on.

## Prior art to respect (do not re-run blind)

From `performance_profiling_and_upgrades.md`:

- **TODO-18 / TODO-67:** Eigen bulk `array().exp()` segfaulted under AVX2 on
  R's 8-byte-aligned heap; that was the original motivation for
  `EIGEN_DONT_VECTORIZE`. The flag is now opt-in and the audit at line ~1172
  found no `Map<...,Aligned>` and default `Map`s emit unaligned loads, so
  the crash should no longer be reachable — but this has not been
  re-verified end-to-end (TODO-136).
- **TODO-18 (MKL `vdExp`):** batch-exp via a *separate* pass lost at
  n=1000 (5 memory passes > SIMD gain). Win expected only at n ≥ 10⁴, or when
  the vector call sits *inside* the existing loop (no extra pass).
- **TODO-68 (dropped):** `-ffast-math` was measured and rejected — it
  changes NaN/Inf semantics the likelihoods rely on. Crucially, the
  measurement at line ~1209 found that GCC emitted libmvec calls **only
  under full `-ffast-math`** (`-ffinite-math-only` in particular);
  `-fno-math-errno` alone left `log1p` scalar (16.3 ns), and adding
  `-funsafe-math-optimizations` only got 13.8 ns vs 5.8 ns with full
  fast-math. TODO-137 proposes to re-test the `-fno-math-errno
  -fno-trapping-math` subset with `#pragma omp simd` loops; item 3/4 below
  must treat the earlier negative result as the null hypothesis, not assume
  the subset suffices.
- **TODO-19 / TODO-20:** `mutable std::vector` members blocked LICM and
  auto-vectorization (18× regression) — the aliasing problem is real and
  has already bitten once.
- **TODO-15/16, TODO-144:** stride-n `.row(i)` on column-major matrices was
  a 5× regression in ZAP/ZINB; 75 `.row(` sites remain unclassified.

## Items

Ordered by cost/benefit. Item 1 is the gate: nothing in items 2–8 should be
attempted on a loop that item 1 does not flag.

- [ ] **TODO-1: Check what actually got vectorized.** Build a handful of hot
  files once with `-fopt-info-vec-missed` (GCC) / `-Rpass-missed=loop-vectorize`
  (Clang). This is the highest-value step: it tells you which loops the
  compiler gave up on and why (aliasing, non-contiguous access, function
  calls, early exits). Everything below should be driven by that output, not
  guesses. Start with the six files carrying `#pragma omp simd` plus the
  hottest kernels from the perf record (`fast_weibull_frailty.cpp`,
  `fast_zero_augmented_poisson.cpp`, `fast_zinb.cpp`, the logistic/probit
  IRLS) and the tree/split-search code. Record per hot loop: file:line,
  reason string, which item (2–8) addresses it. *Owning TODO for the full
  108-file sweep:* `performance_profiling_and_upgrades.md → TODO-168`; this
  item is the SIMD-focused first pass and may tick TODO-168 partially.

- [ ] **TODO-2: `__restrict` / `-fstrict-aliasing` hygiene.** The profiling
  doc already found one 18× regression from a `mutable std::vector` blocking
  LICM/vectorization. Raw-pointer kernels with `double* __restrict`
  parameters, and hoisting `.data()` out of loops, remove the aliasing
  barrier generally rather than case-by-case. Apply to every loop TODO-1
  reports as `possible aliasing` / `versioned for alias`. Verify with a
  re-run of TODO-1 that the reason string disappears, then A/B benchmark.

- [ ] **TODO-3: Fast-math, selectively.** `-ffast-math` globally is risky
  for a stats package (TODO-68 confirmed), but `-fno-math-errno
  -fno-trapping-math` alone is semantics-preserving for this code and
  unlocks vectorization of `exp`/`log`/`sqrt` calls (with errno tracking,
  GCC won't vectorize them). Add to the `configure` flag set (a new
  `EDI_SAFE_FAST_MATH`, default on; document in `build_info()`).
  Per-function `#pragma GCC optimize("fast-math")` or `#pragma omp simd
  reduction(...)` (which permits reassociation) for kernels where reduction
  order doesn't matter. **Caveat from TODO-68:** the earlier measurement
  found the safe subset did *not* by itself trigger libmvec — confirm with
  TODO-1's opt-report on the exact loops before claiming the win; the
  fallback is the per-loop pragma route.

- [ ] **TODO-4: Vectorized libm.** With `-fno-math-errno` plus
  `-mveclibabi` / glibc's `libmvec` (`-ffast-math` or `#pragma omp simd` +
  `-lmvec`), GCC will call `_ZGVdN4v_exp` batch exp. The doc's MKL `vdExp`
  experiment lost because of extra memory passes; libmvec inside an existing
  loop has no extra pass. That's the right way to attack the 42%-scalar-`exp`
  bottleneck noted in the profile. Confirm in the asm (`objdump -d EDI.so |
  grep _ZGV`) that the call is emitted; libmvec is ≤ 4 ulp so the
  `test-*-cpp-equivalence.R` tolerances must be checked, not assumed. Test at
  n ∈ {200, 1000, 10000}. *Owning TODO:*
  `performance_profiling_and_upgrades.md → TODO-137`; tick both. On macOS
  (no libmvec) this is a no-op — Eigen packet exp remains the path there.

- [ ] **TODO-5: Aligned allocation.** Allocate the big feature/design
  matrices with 64-byte alignment (`Eigen::aligned_allocator` or
  `posix_memalign`) and copy from R once. Lets Eigen use aligned loads and
  removes the peeling prologues, and it's the real fix for the AVX2
  segfaults that motivated `EIGEN_DONT_VECTORIZE`. Scope: owning
  `MatrixXd`/`VectorXd` are already Eigen-aligned; the targets are the
  `Eigen::Map`s over `SEXP`/`NumericMatrix` memory in the hot kernels (each
  `Map` becomes one copy at construction, so only do it where TODO-1 shows
  the loop is peeling or where the kernel is called many times per
  construction — bootstrap/permutation workers). Pair with
  `performance_profiling_and_upgrades.md → TODO-136(b)` (UBSan alignment
  run) so the copy is proven necessary, not assumed.

- [ ] **TODO-6: Data layout for tree code.** Column-major, per-feature
  contiguous arrays (SoA) for split search; sort/bin indices to make the
  inner loop a stride-1 gather-free scan. The profiling doc shows stride-n
  row access killed vectorization — likely applies to the split search if it
  hasn't been checked. First step is purely diagnostic: run TODO-1 on the
  tree/split files and look for `unsupported data-ref` / `not consecutive
  access`. *Owning TODO for the `.row(i)` audit:*
  `performance_profiling_and_upgrades.md → TODO-144`.

- [ ] **TODO-7: Branch-free inner loops.** Replace `if (x < thr) left += y
  else right += y` with mask arithmetic (`m = x < thr; left += m*y; right +=
  (1-m)*y`) so the compiler can emit masked/blend ops. AVX-512 masking makes
  this nearly free. Target: loops TODO-1 reports as `control flow in loop`.
  *Owning TODO:* `performance_profiling_and_upgrades.md → TODO-154`.

- [ ] **TODO-8: Float32 where precision allows.** Doubles the SIMD lane
  count. Applicable for distances/histograms used only to *rank* splits
  (`pair_dist_helpers.cpp`, `compute_*_distances.cpp`, the design
  objective scans), not for final estimates. Requires a demonstration that
  the ranking is unchanged on the test-suite fixtures (ties are the risk:
  float32 can create ties double did not have, changing which split wins);
  gate on a fixture-level equivalence test before any kernel is switched.

- [ ] **TODO-9: Verify OpenMP SIMD is really on.** `#pragma omp simd`
  requires `-fopenmp` (or `-fopenmp-simd`) at compile time;
  `SHLIB_OPENMP_CXXFLAGS` provides it on Linux but is empty on default
  macOS clang, so those nine pragmas silently do nothing there.
  `-fopenmp-simd` is a safe unconditional addition to `configure`'s
  `pkg_cxxflags` (it does not pull in the OpenMP runtime). Confirm with
  `EDI:::build_info()` and a macOS build that the pragma is honoured
  (`-Rpass=loop-vectorize` on one of the six files).

## Suggested order

1 → 3 + 9 (flag-only, one-line changes; measure) → 2 → 4 → 5 → 6/7 only
where item 1 says the tree loops fail to vectorize → 8 last, and only with
the ranking-equivalence gate.

Each kept change gets a paired A/B benchmark entry in
`performance_profiling_and_upgrades.md` (same methodology as its §7) so the
two records stay consistent; reverted experiments are recorded there too.

## Explicitly out of scope

- Runtime ISA dispatch / `target_clones` / multi-versioned binaries — moot
  under source builds; revisit only if binary distribution (CRAN binaries,
  Python wheels) becomes the model.
- Hand-written intrinsics (`immintrin.h`, `arm_neon.h`) — not until an
  opt-report-driven loop is shown to be un-vectorizable by any of items 2–7.
- ARM/Apple Silicon validation, NUMA / huge-page tuning, AMX/HBM — separate
  hardware topics, not SIMD; tracked elsewhere if adopted.
