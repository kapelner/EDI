# Link-Time Optimization (LTO) Re-Evaluation

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-4e`;
> 2026-08-30, user decision). Phase 4 kernel/perf lane of `_master.md`. No
> Phase 0 dependency. This is a *re-measurement* plan with a standing
> default of "no change"; it produces a decision and a dated benchmark
> table, not necessarily code.
>
> **Ownership split (no duplication):** the noise-floor / regression-gate
> protocol is `performance_profiling_and_upgrades.md → TODO-135`; the
> per-kernel timing table is `benchmark_model_fits.md`. This plan runs
> *those* under LTO and records the result; it does not define a new
> benchmark.

Date: 2026-08-30

## Premise

`configure` sets `-fno-lto` on the default (non-portable, `-march=native`)
build and exposes `EDI_NATIVE_LTO=1` to opt in (`R/EDI/configure:74-81`).
The comment there, and the README's "Tuning Local Builds" table, record
why: **GCC/RcppEigen LTO builds have shown severe slowdowns in the small
model-fit kernels.** That is a measured negative, so the correct action today
is nothing — LTO stays off.

But the measurement is a point in time. Three things can move it:

1. **Compiler.** GCC's LTO inliner heuristics and partitioning
   (`-flto-partition`, `--param lto-partitions`, `-flto=auto`) change across
   major versions; Clang's ThinLTO behaves differently again. The recorded
   slowdown is one compiler at one version.
2. **Eigen/RcppEigen.** The slowdown mechanism (inlining decisions inside
   Eigen's expression templates, or the loss of `-O3` per-TU decisions when
   the LTO backend re-optimizes) is version-specific.
3. **EDI's own build.** `EDI_UNITY=1` (default) already merges `src/*.cpp`
   into ~10 translation units, which captures most of the cross-file
   inlining LTO would have provided. That both reduces what LTO can add and
   changes the shape of what it sees; the original measurement predates the
   unity build.

So the plan is: re-measure on a fixed cadence and on trigger events, with a
clear rule for flipping the default, and otherwise leave it alone.

## Items

- [ ] **TODO-1: Record the baseline that justified `-fno-lto`.** Find the
  original numbers (in `performance_profiling_and_upgrades.md` history or
  the benchmark logs); if they were never written down, state that here.
  Note compiler, version, Eigen/RcppEigen version, and whether it was a
  unity build. Without this, "it slowed some kernels" cannot be compared
  against anything.
- [ ] **TODO-2: Re-measure under the current toolchain.** `EDI_NATIVE_LTO=0`
  vs `EDI_NATIVE_LTO=1`, both with `EDI_UNITY=1`, via the existing
  `benchmark_build_modes` script and `benchmark_model_fits.md`'s table,
  under the `→ TODO-135` protocol (pinned, single-thread, turbo off, ABBA/
  BAAB). Also one `-flto=auto` / ThinLTO (Clang) variant if that compiler is
  available. Record per-kernel deltas; a kernel is "slowed" if its median
  regresses by more than the measured noise CI.
- [ ] **TODO-3: Decision rule (write it down, apply it).** Flip the default
  to LTO only if *no* kernel regresses beyond noise **and** the geometric
  mean speedup across the table exceeds 5%. Otherwise the default stays
  `-fno-lto`, the README table row keeps its caveat, and this file gets a
  dated "re-measured, still negative/neutral" line. Any partial result
  (some kernels faster, some slower) is a *no*: per-kernel LTO selection is
  not worth the build-system complexity at microsecond scale.
- [ ] **TODO-4: Re-measurement triggers.** Re-run TODO-2 on: a GCC major
  version bump on the release machine, an RcppEigen/Eigen major bump, or a
  change to the unity-build grouping. Add a one-line reminder to
  `release.md`'s checklist so it is not forgotten.

## Explicitly out of scope

- Per-file or per-kernel LTO partitioning.
- Any LTO on the portable (`EDI_PORTABLE=1`, CRAN-style) build — CRAN's own
  flags govern that path.
- Profile-guided optimization (PGO) — a separate question; if ever wanted it
  gets its own plan.
