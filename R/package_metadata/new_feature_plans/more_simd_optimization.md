# More SIMD Optimization (Source-Build Power Users)

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-4c`;
> 2026-08-27, user decision). Sits in the Phase 4 kernel/perf lane of
> `_master.md`, alongside `performance_profiling_and_upgrades.md` §8
> (`→ TODO-4b`), which stays in v1.1.0 too. No Phase 0 dependency;
> measurement-first.
>
> **Ownership split (no duplication):** `performance_profiling_and_upgrades.md`
> owns every *diagnostic/measurement* TODO that also happens to be
> SIMD-relevant — TODO-168 (opt-report sweep), TODO-137 (fast-math subset +
> libmvec), TODO-136 (Eigen vectorization audit), TODO-144 (`.row(i)`
> classification), TODO-154 (branch-free GLM objective layout). This file
> does not re-run any of those; it consumes their output and owns only the
> *implementation* work that is not already a numbered TODO in that plan:
> a general `__restrict` sweep, permanently wiring a confirmed fast-math
> flag into `configure`, aligned copies of `Map`ped R memory, split-search
> (tree code) SoA layout and branch-free comparisons — a different code
> path from TODO-154's GLM objectives — float32 ranking, and the
> `-fopenmp-simd` macOS gap. Where a TODO below depends on a specific perf-plan
> TODO's finding, that dependency is named explicitly; nothing here is
> started before its dependency has a result.

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
Nobody has yet asked the compiler which loops it gave up on — that ask is
`performance_profiling_and_upgrades.md → TODO-168`, not repeated here.

## Prior art to respect (do not re-run blind)

From `performance_profiling_and_upgrades.md`:

- **TODO-18 / TODO-67:** Eigen bulk `array().exp()` segfaulted under AVX2 on
  R's 8-byte-aligned heap; that was the original motivation for
  `EIGEN_DONT_VECTORIZE`. The flag is now opt-in and the audit at line ~1172
  found no `Map<...,Aligned>` and default `Map`s emit unaligned loads, so
  the crash should no longer be reachable — but this has not been
  re-verified end-to-end (TODO-136, owned by the perf plan; TODO-3 below
  depends on its result).
- **TODO-18 (MKL `vdExp`):** batch-exp via a *separate* pass lost at
  n=1000 (5 memory passes > SIMD gain). Win expected only at n ≥ 10⁴, or when
  the vector call sits *inside* the existing loop (no extra pass).
- **TODO-68 (dropped):** `-ffast-math` was measured and rejected — it
  changes NaN/Inf semantics the likelihoods rely on. Crucially, the
  measurement at line ~1209 found that GCC emitted libmvec calls **only
  under full `-ffast-math`** (`-ffinite-math-only` in particular);
  `-fno-math-errno` alone left `log1p` scalar (16.3 ns), and adding
  `-funsafe-math-optimizations` only got 13.8 ns vs 5.8 ns with full
  fast-math. TODO-137 re-tests the `-fno-math-errno -fno-trapping-math`
  subset with `#pragma omp simd` loops specifically; that earlier negative
  result is the null hypothesis TODO-137 has to beat, and TODO-2 below does
  not start until TODO-137 reports a result either way.
- **TODO-19 / TODO-20:** `mutable std::vector` members blocked LICM and
  auto-vectorization (18× regression) — the aliasing problem is real and
  has already bitten once.
- **TODO-15/16, TODO-144:** stride-n `.row(i)` on column-major matrices was
  a 5× regression in ZAP/ZINB; 75 `.row(` sites remain unclassified
  (TODO-144, owned by the perf plan).

## Items

Ordered by cost/benefit. Every item depends on the named perf-plan TODO
having a recorded result (measured, or "measured and dropped") before it
starts — none of them re-run that measurement.

- [ ] **TODO-1: `__restrict` / `-fstrict-aliasing` hygiene.** The profiling
  doc already found one 18× regression from a `mutable std::vector` blocking
  LICM/vectorization. Raw-pointer kernels with `double* __restrict`
  parameters, and hoisting `.data()` out of loops, remove the aliasing
  barrier generally rather than case-by-case. **Depends on:**
  `performance_profiling_and_upgrades.md → TODO-168`'s opt-report sweep,
  which already routes `possible aliasing` / `versioned for alias` findings
  here (TODO-168's own text: "`possible aliasing` → `__restrict__` on raw
  pointer parameters") but does not implement the fix — that implementation
  sweep across the flagged sites is this item, and it is the only place
  that work is owned. Verify with a re-run of TODO-168's opt-report that the
  reason string disappears on each fixed site, then A/B benchmark.

- [ ] **TODO-2: Wire a confirmed fast-math subset into `configure`.**
  `-ffast-math` globally is risky for a stats package (TODO-68 confirmed);
  the measurement of whether the safe subset (`-fno-math-errno
  -fno-trapping-math`) or the per-loop `#pragma omp simd reduction(...)`
  route (which permits reassociation without the global flag) actually
  unlocks vectorization and/or libmvec is entirely
  `performance_profiling_and_upgrades.md → TODO-137` — **not repeated
  here.** This item is the follow-on only: once TODO-137 reports which
  route wins (if any), add it to `configure`'s flag set as a documented,
  opt-in-by-default `EDI_SAFE_FAST_MATH` (documented in `build_info()`) and
  verify the existing `test-*-cpp-equivalence.R` tolerances still hold.
  Ships nothing if TODO-137 reports "measured and dropped".

- [ ] **TODO-3: Aligned allocation for `Map`ped R memory.**
  `performance_profiling_and_upgrades.md → TODO-136` audits whether the
  default build is Eigen-vectorized and whether an alignment crash is
  reachable; it does not change any allocation. If TODO-136 finds the
  default `Map`s over `SEXP`/`NumericMatrix` memory are leaving vectorized
  loads on the table (unaligned-load penalty, not a correctness issue —
  TODO-136 already established default `Map`s are `Unaligned` and safe),
  copy the big feature/design matrices into a 64-byte-aligned owned buffer
  once at construction (`Eigen::aligned_allocator` or `posix_memalign`) in
  the kernels TODO-136 flags as hot enough to be worth the copy —
  bootstrap/permutation workers that construct many times, not one-shot
  fits. Do not do this speculatively; it is gated on TODO-136's audit
  showing a real peeling/unaligned-load cost, not assumed.

- [ ] **TODO-4: Split-search (tree code) SoA layout.** Column-major,
  per-feature contiguous arrays (SoA) for split search; sort/bin indices to
  make the inner loop a stride-1 gather-free scan. **Depends on:**
  `performance_profiling_and_upgrades.md → TODO-144`'s `.row(i)`
  classification pass, which covers the 75 known sites generally but does
  not specifically examine the split-search files. Extend TODO-144's sweep
  to the tree/split-search files first (still ticked as part of TODO-144,
  not a separate sweep here); this item is the SoA rewrite once that
  extension flags a stride-n access pattern there.

- [ ] **TODO-5: Branch-free split-search comparisons.** Replace
  `if (x < thr) left += y else right += y` with mask arithmetic
  (`m = x < thr; left += m*y; right += (1-m)*y`) so the compiler can emit
  masked/blend ops. AVX-512 masking makes this nearly free. This is the
  same technique as `performance_profiling_and_upgrades.md → TODO-154`
  (branch-free observation ordering), but a different code path — TODO-154
  is scoped to the GLM objectives' `y == 0` / category branching, this item
  is the split-threshold comparison in the tree/split-search loops, which
  TODO-154 does not touch. Target loops TODO-4's SoA pass (or a targeted
  opt-report run limited to the split-search files) reports as `control
  flow in loop`.

- [ ] **TODO-6: Float32 where precision allows.** Doubles the SIMD lane
  count. Applicable for distances/histograms used only to *rank* splits
  (`pair_dist_helpers.cpp`, `compute_*_distances.cpp`, the design
  objective scans), not for final estimates. Requires a demonstration that
  the ranking is unchanged on the test-suite fixtures (ties are the risk:
  float32 can create ties double did not have, changing which split wins);
  gate on a fixture-level equivalence test before any kernel is switched.

- [ ] **TODO-7: Verify OpenMP SIMD is really on.** `#pragma omp simd`
  requires `-fopenmp` (or `-fopenmp-simd`) at compile time;
  `SHLIB_OPENMP_CXXFLAGS` provides it on Linux but is empty on default
  macOS clang, so those nine pragmas silently do nothing there.
  `-fopenmp-simd` is a safe unconditional addition to `configure`'s
  `pkg_cxxflags` (it does not pull in the OpenMP runtime). Confirm with
  `EDI:::build_info()` and a macOS build that the pragma is honoured
  (`-Rpass=loop-vectorize` on one of the six files).

## Suggested order

7 (flag-only, one-line, unblocks macOS immediately) → 1 (once TODO-168
reports aliasing findings) → 2 (once TODO-137 reports) → 3 (once TODO-136
reports) → 4 → 5 (only where TODO-4's pass flags control flow) → 6 last,
and only with the ranking-equivalence gate.

Each kept change gets a paired A/B benchmark entry in
`performance_profiling_and_upgrades.md` (same methodology as its §7) so the
two records stay consistent; reverted experiments are recorded there too.

## Explicitly out of scope

- Runtime ISA dispatch / `target_clones` / multi-versioned binaries — moot
  under source builds; revisit only if binary distribution (CRAN binaries,
  Python wheels) becomes the model.
- Hand-written intrinsics (`immintrin.h`, `arm_neon.h`) — not until an
  opt-report-driven loop is shown to be un-vectorizable by any of items
  1–5.
- ARM/Apple Silicon validation, NUMA / huge-page tuning, AMX/HBM — separate
  hardware topics, not SIMD; tracked elsewhere if adopted.
- Any diagnostic/measurement work already numbered in
  `performance_profiling_and_upgrades.md` (TODO-136, 137, 144, 154, 168) —
  read its results, do not re-run it.
