# Bug: seed-pinned design draws depend on the OpenMP thread count

Date: 2026-10-11 (found while scoping `marketing_plans/agent_proofing.md` W6, user decision to file)
Release index: `../future_release_plans/release_v1_0_5.md → TODO-95`
Follow-up feature (package-wide guarantee, v1.1.0): `../new_feature_plans/cross_platform_reproducibility.md`
(`release_v1_1_0.md → TODO-48`)

## Symptom

With the same `set.seed()`, four fixed designs produce different allocations
depending on `set_num_cores()`. One of them also differs between repeated
runs at the same thread count. The package default (`get_num_cores() == 1`,
enforced at load by `zzz.R:55-70`) is unaffected. Anyone who opts into
multi-core gets allocations that depend on their machine's core count: an
agent's 2-core container and a user's 16-core laptop disagree.

**Reproduction** (installed EDI 1.0.3, 2026-10-11; script in the session
scratchpad as `design_threads.R`). n = 40, three `rnorm` covariates,
`set.seed(42)` before construction and before
`draw_ws_according_to_design(30L)`, `set_num_cores(k)`. Digest =
`sum(w_mat * seq_along(w_mat)) %% 1e7`:

| class | 1 thread | 2 threads | 4 threads | 4 threads, again |
|---|---|---|---|---|
| `DesignFixedGreedy` | 360257 | 360401 | 360158 | 360158 |
| `DesignFixedGreedyDOptimal` | 360034 | 360298 | 360399 | 360399 |
| `DesignFixedMatchingGreedyPairSwitching` | 360201 | 360303 | 360474 | 360474 |
| `DesignFixedRerandomization` | 360199 | 360468 | 360107 | **360199** |
| `DesignFixedBinaryMatch` (control) | 360037 | 360037 | 360037 | 360037 |

A direct kernel call (`rerandomization_search_cpp`, threads 4, three
repeats) gave three different results. That confirms the rerandomization
kernel is nondeterministic at a fixed thread count, not merely
thread-count-dependent.

Randomization inference on these designs redraws allocations through the
same kernels, so multi-core rand p-values and CIs are expected to inherit
the dependence. Not yet measured; TODO-4's tests cover it.

## Root cause

All four kernels draw **one seed per OpenMP thread**
(`seeds.size() == omp_get_max_threads()`) and index the stream by
`omp_get_thread_num()`:

- `design_fixed_greedy.cpp:76-84` (seeding), `:94` (no-covariate branch),
  `:144` (search branch). These serve `DesignFixedGreedy` and
  `DesignFixedMatchingGreedyPairSwitching`.
- `optimal_design_search.cpp:143,148` (D-optimal) and `:190,195`
  (A-optimal), through `edi_search::seed_per_thread_rngs_from_r()`
  (`greedy_pairwise_swap_engine.h:48-56`). These serve `DesignFixedGreedyDOptimal`.
- `rerandomization_helpers.cpp:215-224` (seeding), `:270` (per-thread RNG).
  Threads also claim chunks through `next_draw.fetch_add` (`:277`) and claim
  output columns through `found.fetch_add` (`:293`). Which stream fills which
  column therefore depends on OS scheduling.

With `schedule(static)` the mapping from draw index to thread is fixed for
a given thread count, so results repeat at a fixed count. Changing the
count changes which stream generates draw *d*.

**The correct pattern is already in the tree.** `binary_match_search.cpp:22-48`
takes one master seed from R's stream, then seeds each column's `RRng` from
`splitmix64_seed(master_seed + j)`. The draw for column *j* depends only on
*j*, which is why `DesignFixedBinaryMatch` is invariant in the table above.

## The documentation states the opposite

Each of these claims is false or stale and must be corrected with the fix:

- `R/EDI/vignettes/reproducibility.Rmd:150-162` says `DesignFixedGreedy`'s
  "result is identical regardless of how many OpenMP threads … are actually
  used", calls it "the template other designs' parallel kernels should
  follow", and still says `std::mt19937`.
- `reproducibility.Rmd:47-49` describes `DesignFixedGreedyDOptimal` as "a
  single local generator". It uses per-thread generators.
- `greedy_pairwise_swap_engine.h:42-47` and `optimal_design_search.cpp:20-23`
  claim "identical draws independent of the thread count".
- `design_class_registry.R:95-112` says the greedy kernels have "no
  nondeterminism" and that `DesignFixedRerandomization` "is the *only*
  affected class". As a result, `R/package_tests/design_matrix.csv` publishes
  `seed_reproducible_single_thread_only = FALSE` for the three greedy-family
  classes. `llms.txt` points agents at that file.

The registry's stated reason for leaving rerandomization as work-stealing
(`:113-124`) is that `schedule(static)` would give up early termination.
TODO-2 below keeps early termination and is still deterministic.

## Fix

Seed-pinned draws change once for these four classes, including at one
thread, because the seed derivation changes. That is a documented default
change under v1.0.5's standing constraints.

- [x] TODO-1: **Greedy and D/A-optimal: seed per draw, not per thread.**
  - Move `splitmix64_seed` from `binary_match_search.cpp` into `RNG.h` as
    `edi_rng::seed_for_index(master, i)`.
  - Replace `seed_per_thread_rngs_from_r()` with one master draw from R's
    stream, then `RRng rng(seed_for_index(master, d))` inside the loop over
    draws *d*.
  - Apply this to both branches of `greedy_design_search_cpp` and to both
    optimal kernels. Delete the per-thread helper so it cannot be reused.
  - Cost: one Mersenne-Twister initialisation per draw, which is negligible
    next to a full pairwise-swap local search per draw.
- [x] TODO-2: **Rerandomization: deterministic early-stopping rejection
  sampler.**
  - Seed draw *d* from `seed_for_index(master, d)`.
  - Threads keep claiming fixed-size blocks of draw indices from
    `next_draw` and record each acceptance together with its index.
  - Track the longest fully completed prefix of blocks and the number of
    acceptances in it. Stop claiming new blocks once that prefix holds at
    least `r` acceptances; let in-flight blocks finish.
  - Return the `r` smallest-index acceptances.
  - The output is then a function of the seed alone. Early termination is
    kept, and the extra work is at most threads × block size draws.
  - Afterwards, remove the class from
    `EDI_DESIGN_SEED_REPRODUCIBLE_SINGLE_THREAD_ONLY_CLASS_NAMES`.
- [x] TODO-3: **Correct the documentation and metadata.**
  - Fix the five locations above.
  - Rewrite the vignette subsection around the per-draw pattern.
  - Rewrite the registry comment and regenerate `design_matrix.csv`.
  - Add a NEWS entry naming the four classes whose seed-pinned draws change
    once.
- [x] TODO-4: **Tests (required; the fix does not land without them).**
  - (a) For each of the four classes plus `DesignFixedBinaryMatch` and
    `DesignFixedOptimal` (per-chain annealing seeds, expected invariant):
    same seed at `set_num_cores(1, 2, 4)` gives identical `w` matrices, and
    two repeats at 4 threads are identical.
  - (b) A rerandomization case with a tight cutoff, forcing many
    rejections, so block boundaries and early stopping are exercised.
  - (c) A **registry-driven** test: every design class with
    `seed_reproducible_draw = TRUE` passes (a). New classes are then covered
    automatically.
  - (d) One randomization p-value per affected class is identical at 1
    and 4 cores.
  - (e) A pre-push static check that fails on per-thread-indexed seeding
    (`seeds[tid]`, `seeds[omp_get_thread_num()]`) or on the removed
    helper's name.
  - Tests skip cleanly when OpenMP reports a single thread. Pin
    seed-dependent fixtures that change under TODO-1/2 in the same commit.

## Implementation status (2026-10-11)

The source implementation now derives every affected candidate stream through
`edi_rng::seed_for_index(master_seed, draw_index)`. Master seeds are obtained
with `seed_from_unif01()` and then widened, avoiding a boundary-sensitive
floating-point-to-`uint64_t` conversion. The former per-thread helper is
removed. Rerandomization evaluates deterministic waves of contiguous
candidate-index blocks and returns accepted allocations in block/index order.
The registry, matrix, vignette, NEWS, and the shipped metadata/static-guard
test have been updated to match that implementation.

Execution verification 2026-10-14: after installing the current checkout
(`make` reported no stale native objects), the registry-driven seed test passed
at 1/2/4 package threads across all seed-reproducible designs, including the
four changed classes, BinaryMatch, and optimal designs; the 4-thread repeat
checks passed. The static guard rejects reintroduction of the per-thread seed
helper. A new tight-cutoff rerandomization test passed at 1/2/4 threads and on
the 4-thread repeat. A new OLS randomization-p-value test passed at 1/4 threads
for Greedy, D-optimal, matching-pair-switching, and rerandomization designs.
The four classes' intentionally changed seed streams are pinned as exact
allocation digests in `tests/testthat/fixtures/openmp_design_seed_draws_v1_0_5.csv`;
the single-thread metadata test regenerates each 12-allocation matrix and checks
its digest. The fixture was captured from the post-migration implementation,
and the thread-invariance tests independently confirm the same outputs at
multiple core counts. This completes TODO-1..4.
