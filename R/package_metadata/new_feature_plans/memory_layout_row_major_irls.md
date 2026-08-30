# Memory Layout: Column-Major `X` Under Row-Wise IRLS Access

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-4f`;
> 2026-08-30, user decision). Phase 4 kernel/perf lane of `_master.md`. No
> Phase 0 dependency; measurement-first with a threshold finding as the
> primary deliverable.
>
> **Ownership split (no duplication):** `performance_profiling_and_upgrades.md
> → TODO-144` owns the *site-by-site audit* of the 75 `.row(` uses (strided
> in a hot loop vs one-off setup) and already found the 5× ZAP/ZINB
> regression (its TODO-15/16). This file does not redo that classification.
> It owns the *general policy question* TODO-144 stops short of: at what
> `n` does layout matter at all for EDI's workloads, and what is the one
> mechanism (if any) to adopt uniformly rather than fixing sites one at a
> time.

Date: 2026-08-30

## Premise

Eigen defaults to column-major storage, and R hands `X` over column-major, so
every `Eigen::Map` of a design matrix (~1,060 `Map` uses in `src/`) is
column-major with zero copy. An IRLS/Newton iteration, however, is naturally
row-wise: for each observation `i`, compute `ηᵢ = xᵢᵀβ`, the link, the
weight `wᵢ`, the working response — and then accumulate `xᵢxᵢᵀwᵢ` into
`XᵀWX`. Touching `xᵢ` in a column-major matrix means `p` loads with stride
`n·8` bytes.

At EDI's sizes this is invisible: `X` at `n = 1,000`, `p = 10` is 80 KB and
sits in L2 for the whole fit, so every stride hits cache anyway. The stride
only costs when `X` grows past cache — roughly `n·p·8 > 1 MB` per core, i.e.
`n ≳ 10⁴` at `p = 10` — at which point each row touch becomes `p` cache-line
misses and the `O(np)` pass becomes memory-bound. `X` is not the only
candidate: the same reasoning applies to per-replicate `Xᵦ` copies in
bootstrap loops and to `SimulationFramework`'s larger synthetic designs.

The tree currently uses `RowMajor` in 20 places and `.row(` in 22 files, so
the practice is ad hoc: some kernels were fixed by hand after a profiler
found them, others never were. The question this plan answers is whether
that is fine (because nothing reaches the threshold) or whether a uniform
mechanism is warranted.

## Items

- [ ] **TODO-1: Find the threshold (gate).** One microbenchmark: a
  representative IRLS iteration (logistic link) over column-major `X`
  vs a row-major copy vs the weight-vector-plus-GEMV formulation
  (`XᵀWX` via `X.transpose() * w.asDiagonal() * X` / `rankUpdate`, no
  per-row access at all), for `p ∈ {5, 10, 20}` and `n` from `10²` to `10⁶`
  on a log grid, single-threaded, pinned, under the `→ TODO-135` protocol.
  Report the `n` at which column-major first loses by more than noise, and
  by how much at `10⁵`/`10⁶`. **Exit:** that `n` recorded here; if it is
  above `10⁴` at `p = 10`, EDI's designed-experiment regime never reaches
  it and TODO-3 is skipped.
- [ ] **TODO-2: Cross-reference with TODO-144's classification.** For each
  `.row(i)`-in-hot-loop site TODO-144 flags, note whether the kernel is ever
  called at `n` above TODO-1's threshold (bootstrap/randomization loops at
  `n < 1,000`: no; `SimulationFramework` with large synthetic `n`: maybe;
  Python-binding callers with observational data: possibly). This turns
  TODO-144's list into a "fix now / fix never / fix if `n` grows" triage.
- [ ] **TODO-3: Uniform mechanism (only if TODO-1's threshold is reachable).**
  Prefer the formulation that removes row access entirely (weight vector +
  `rankUpdate`/GEMV, which is also what `→ TODO-28` in the perf plan
  recommends for `weighted_crossprod`) over storing a row-major copy — the
  copy costs `O(np)` memory and a pass, and only pays off if the kernel
  iterates many times. Where a kernel genuinely needs per-row access
  (line-search objectives, per-observation likelihood contributions with
  data-dependent branching), take one row-major copy at kernel entry, once,
  behind an `n·p` size threshold from TODO-1 so small fits are untouched.
- [ ] **TODO-4: Document the policy.** One paragraph in
  `R/EDI/vignettes/extending-edi.Rmd`'s kernel-writing section: "`X` arrives
  column-major; do not `.row(i)` inside a per-observation loop unless `n`
  is bounded; use the weight-vector form." Plus the threshold number from
  TODO-1 so future kernel authors know when it matters.

## Explicitly out of scope

- The site-by-site `.row(` audit itself (TODO-144).
- SoA layout for tree/split-search code (`more_simd_optimization.md
  → TODO-4`), which is a different access pattern.
- Anything result-changing: reordering the `XᵀWX` accumulation can change
  floating-point results at the last ulp; any TODO-3 change ships bit-for-bit
  or behind a flag (v1.1.0 additive constraint).
