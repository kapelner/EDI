# Small Kernel Hoists Batch: Greedy `G = MᵀM`, Ordinal `y_slot`, Cox Bootstrap Ordering, Shared GH Rule

> **Release:** v1.4.0 (`../future_release_plans/release_v1_4_0.md → TODO-11i`;
> 2026-08-30, user decision). Four independent, small, kernel-internal
> items that did not merit a plan each. Phase 4 kernel/perf lane of
> `_master.md`; no dependencies among them or on other plans. Each item
> states its own equivalence contract; three are bit-identical, one
> (Cox) is tolerance-equal.

Date: 2026-08-30

## Item A — `design_fixed_greedy.cpp`: hoist the Gram matrix in exhaustive mode

**Today.** The pair-switch objective is `f(d) = ‖d‖²` (Mahalanobis) or
`‖d‖₁` with `d = M·(2w − 1)`, `M` (p×n) built once (`:115-135`). In
exhaustive best-improvement mode (`n_iter < 0`, `:188`) every (treated `i`,
control `j`) pair is scored per round via
`scratch = 2·(M.col(j) − M.col(i)); f + 2·d.dot(scratch) + scratch.squaredNorm()`
(`:236-247`) — O(p) per pair, O(n_T·n_C·p) per round.

**Shortcut (Mahalanobis mode only).** With `G = MᵀM` (n×n, computed once,
O(n²p)) and `g = Mᵀd` (n-vector, recomputed O(np) only on an accepted
swap): `scratch.squaredNorm() = 4(G_ii + G_jj − 2G_ij)` and
`d.dot(scratch) = 2(g_j − g_i)` — O(1) per pair, so a round is O(n_T·n_C).
`‖·‖₁` mode has no such identity; leave it.

**Guard.** `G` is n×n doubles: 8 MB at n = 1000, 200 MB at n = 5000. Use it
only when `n²·8 ≤ 64 MB` (n ≤ ~2,800) or when `p > 4` (below that the
per-pair O(p) is already ~O(1)); otherwise the existing path. Same
identity, same arithmetic up to reassociation → **tolerance-equal**; the
accepted swap sequence could differ at exact objective ties, so tests
assert identical final `w` on separated fixtures and objective values to
`1e-10`. Expected: round cost /p, so ~5–10× at p = 10 for the exhaustive
engine only (the default annealing/`n_iter > 0` paths are untouched).

- [ ] **A1.** Add the `G`/`g` fast path behind the size guard in the shared
  exhaustive engine (`:222-255`), Mahalanobis mode only. Refresh `g` in the
  accept hook that already refreshes `d` (`:203-231` region).
- [ ] **A2.** Tests: final `w` identical + objective to `1e-10` vs. the
  existing path on separated fixtures; `‖·‖₁` mode unchanged; guard
  boundary (`n` just above/below the memory cap) both produce the same `w`.
- [ ] **A3.** Microbenchmark exhaustive rounds at `n ∈ {200, 1000}`,
  `p ∈ {2, 5, 10, 20}`.

## Item B — `ordinal_fixed_link_helpers.h:163`: cache `y_slot` at construction

**Today.** `level_index(levels, y)` is a linear scan over the K levels
(`:163-168`), called per observation inside the objective, gradient, and
Hessian evaluations (`:254`, `:276`, `:323`) — i.e. O(n·K) of branchy
comparisons on **every L-BFGS iteration**, repeated per bootstrap/
randomization replicate. `fast_negbin_regression.cpp:71-83` already does
this right: an `m_y_slot` vector filled once in the constructor.

**Shortcut.** `std::vector<int> m_y_slot` filled once in
`FixedOrdinalRegression`'s constructor (`:170+`) with the same
`level_index` (so unknown levels still map to `-1` and take the existing
error/skip path); the three call sites read `m_y_slot[i]`. **Bit-identical**
— the index is the same integer. Saves O(n·K) per iteration; at K = 5, n =
500 that is ~2.5k comparisons per iteration against an objective that
costs ~n·(p + K) flops, i.e. a 10–20 % iteration-time trim, more for large
K. Also apply to any sibling with the same pattern (`grep level_index`
across `src/` — `fast_stereotype_logit`, `fast_continuation_ratio_regression`,
`fast_adjacent_category_logit` if they scan).

- [ ] **B1.** Constructor-time `m_y_slot`; replace the three call sites; same
  for siblings found by grep.
- [ ] **B2.** Tests: existing ordinal fixtures produce `identical()` fits
  (coefficients, log-lik, Fisher information) before/after; a `y` containing
  a level absent from `levels` still errors/skips as before.

## Item C — `fast_coxph_regression.cpp:1129`: order bootstrap draws from the parent's rank permutation

**Today.** Each bootstrap draw builds `y_b`, `dead_b`, `X_b` by gathering
resampled rows (`:1117-1127`), then `CoxData(...)` sorts them
comparison-wise (`std::sort` with a lambda, `:42`) — O(n log n) per draw.

**Shortcut.** The draw's times are a multiset of the parent's times, so
their sorted order is determined by the parent's rank: precompute
`rank0[i]` = position of subject `i` in the parent's sorted order (once,
O(n log n)); per draw, a counting pass over `rank0[i_b]` (O(n)) yields the
sorted order directly, and `CoxData` gets a constructor overload that
accepts a presorted index. Ties: the parent sort's tie-breaking (whatever
the lambda at `:42` does for equal times — verify whether it is by index or
unstable) must be reproduced; with a stable counting sort by `rank0`, tied
draws keep the parent's relative order, which **may differ** from what an
unstable `std::sort` produced on the resampled vector. The partial
likelihood is invariant to order *within* a tie group under Breslow/Efron,
but summation order inside the risk-set accumulations is not, so this is
**tolerance-equal** (~1e-15 relative on `beta`), not bit-identical. Same
shortcut applies to `compute_coxph_rand_bootstrap_parallel_cpp` (`:1138+`)
if it re-sorts likewise.

- [ ] **C1.** `rank0` once; per-draw counting pass; `CoxData` presorted
  overload; apply to both bootstrap kernels.
- [ ] **C2.** Tests: bootstrap `beta` vector vs. old path to `1e-10`
  relative, on fixtures with and without tied event times, with censoring,
  and with `delta ≠ 0`; the parent-data fit unchanged (`identical()`).
- [ ] **C3.** Microbenchmark at `n ∈ {200, 1000}`, `B = 1000`: expect the
  sort's O(n log n) share (~10–20 % of a draw at n = 500) to vanish; the
  Newton iterations dominate and are untouched.

## Item D — one shared, cached Gauss–Hermite rule

**Today.** Four copies of the same Golub–Welsch construction — a tridiagonal
Jacobi matrix and a `SelfAdjointEigenSolver` — live in
`fast_logistic_glmm.cpp:39`, `fast_poisson_glmm.cpp:45`,
`fast_hurdle_poisson_glmm.cpp:42`, and `_glmm_engine.h:32` (used by
`fast_ordinal_glmm.cpp:49` and the engine's clients). Each GLMM fit
constructs its rule in the constructor (`:103`, `:104`, `:144`, `:77`), so a
B-replicate bootstrap runs the eigensolver B times. Callers use exactly two
values, `n_gh ∈ {7, 20}` (`RcppExports.R` defaults: 16 sites at 20, 7 at 7).

**Why do it anyway.** At `n_gh = 20` the eigensolve is ~40 µs against a
~5 ms GLMM fit — ~1 % — so this is not a performance item. It is a
ten-line deduplication that removes three copies of numerical code that
must stay identical, and it gives one place to add a `n_gh` cache.

**Shortcut.** Keep `glmm::gauss_hermite_rule(int n)` in `_glmm_engine.h` as
the single implementation; delete the three per-file copies and point their
constructors at it. Add a small thread-safe cache (`static std::mutex` +
`std::unordered_map<int, GHRule>`, or `std::call_once` per common `n`) so a
rule is built once per process per `n_gh`. **Bit-identical**: the same
eigensolver on the same matrix gives the same nodes/weights; the three
per-file copies must first be diffed against `_glmm_engine.h`'s to confirm
they are byte-for-byte the same construction (if one differs — e.g. a
different symmetrisation or weight normalisation — record it and keep the
engine's version, with a fixture test showing the GLMM fits are
`identical()`).

- [ ] **D1.** Diff the four implementations; unify on `_glmm_engine.h`'s;
  add the cache; delete the copies.
- [ ] **D2.** Tests: all GLMM fixtures `identical()` before/after; the
  cache returns the same object for repeated `n_gh`; two threads requesting
  the same `n_gh` concurrently do not race (run a bootstrap with
  `num_cores > 1` under the sanitiser build if available).

## Shared

- [ ] **TODO-E: Benchmark table.** One row per item in
  `benchmark_model_fits.md`'s kernel section, `→ TODO-135` protocol; items
  B and D are expected to show ≤ 20 % and ≤ 2 % respectively — record that,
  it is the point.
- Targeted compile of touched files only, per `CLAUDE.md`.

## Explicitly out of scope

- The `‖·‖₁` greedy mode (no Gram identity).
- Anything in the Cox Newton loop itself (already textbook per the audit).
- Changing `n_gh` defaults or the quadrature scheme.
