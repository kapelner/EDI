# Permutation Set: Sign Once at Generation, Never Re-Hash or Re-Copy per Call

> **Release target: v1.1.0** (`../future_release_plans/release_v1_1_0.md →
> TODO-42`; 2026-10-07, user decision). Under the 2026-09-23 split rule this
> is a misfiring performance path that already shipped and would sit in
> `release_v1_0_5.md`; it is kept in v1.1.0 by user decision and moves with
> one line if that changes.
> **Depends on:** `dead_randomization_fast_paths.md` (`release_v1_0_5.md →
> TODO-64`) for the integer-storage contract (its TODO-2 and this plan's
> TODO-4 are the same change: implement once). Touches
> `inference_all_abstract_rand.R → generate_permutations()` (L736–760;
> `storage.mode(w_mat) = "numeric"` at L755), `subset_permutations()`
> (L660), `build_randomization_distribution_cache_key()` (L763) and
> `inference_all_abstract.R → stable_signature()` (L958).
> **Interaction:** multiplicative with
> `../new_feature_plans/randomization_ci_affine_shift_reuse.md`
> (`release_v1_0_5.md → TODO-2`: fewer null distributions per CI; this plan
> makes each one cheaper) and with
> `../new_feature_plans/ols_randomization_distr_cpp_wiring.md`
> (`→ TODO-3`). Otherwise independent of every item in both release files.

Written 2026-10-07, user decision. Root cause of the "R6 mean-difference
randomization test is 0.57x of `coin`" row in the 2026-10-07 benchmark
extension, profiled the same day against the installed CRAN EDI 1.0.2 (no
rebuild). `coin`'s engine never exposes its permutation set and returns only
the statistics; EDI's per-design permutation cache is a sound design (one
set shared by every inference object on a design, reproducible, inspectable),
but re-hashing it on every call is not.

## Findings (installed 1.0.2, n = r = 1000, mean difference, 1 thread)

End to end: first `compute_rand_two_sided_pval()` on a fresh object 28 ms;
a repeat call on the same object 12 ms. The kernel that consumes the
permutations takes 0.7 ms. Components, each micro-benchmarked alone:

| Step | Cost | Where |
|---|---|---|
| `generate_permutations_ibcrd_cpp` (once per design, cached) | 14.1 ms | `generate_permutations()` |
| `stable_signature(permutations)`: `serialize()` of the 8 MB double matrix + xxhash64 | 7.5 ms + ~1 ms, **every call** | `build_randomization_distribution_cache_key()` L763 |
| `subset_permutations()` full copy when `indices` is every column | 7.4 ms, every call | L660 |
| `compute_simple_mean_diff_parallel_cpp` | 0.7 ms (0.4 ms on 4 threads) | fast path |
| R6 construction | ~2 ms | once |

- The signature is also rebuilt on **every bisection step of the
  randomization CI search**, as `stable_signature()`'s own comment notes.
- **History.** `stable_signature()` was an O(1) strided sample until
  2026-09-21, when it collided for distinct 0/1 permutation matrices and
  served a cached null distribution for the wrong set (commit `a31ecc5e`,
  `project_source_bug_fixes_20260921`). The fix hashes the full
  serialization; its comment calls that "cheap enough". It was never
  re-timed because the benchmark harness timed kernels only.
- **Storage.** `generate_permutations()` converts the kernel's integer
  matrix to double (L755), doubling it from 4 to 8 MB and the hash cost
  with it. 50 of the 51 kernel signatures that take `w_mat` want integers:
  16 take `Eigen::Map<Eigen::MatrixXi>` (which cannot accept a double and
  errors "Wrong R type for mapped matrix": the dead fast paths of
  `→ TODO-64`) and 34 take `Rcpp::IntegerMatrix` (Rcpp coerces, a full copy
  per call). One takes `NumericMatrix`.

## Proposal

Sign the permutation set once, where it is created, and carry the signature
with it. Stop copying it when nothing is subset. Store it as the integer
matrix the kernels want. All bit-preserving: no draw, statistic or p-value
changes; only when hashing and copying happen.

**Correctness constraint (the 2026-09-21 lesson).** The stored signature is
only valid while the cached matrix is immutable. R's copy-on-modify makes
that true unless something writes in place (`data.table::set`, Rcpp code
writing into a mapped matrix). TODO-5 audits this and adds a debug-mode
recheck.

## TODOs

- [ ] TODO-1: **Harness, before any change.** Micro-benchmark script for
  (a) fresh object + p-value, (b) repeat p-value, (c) one randomization CI,
  at n = r = 1000 for the mean difference and one regression class;
  promoted to `R/benchmark/`. Installed package only.

- [ ] TODO-2: **Signature at generation.** In `generate_permutations()`,
  compute `stable_signature()` once over `w_mat` (and `m_mat` when present)
  and store it as `permutations$signature`, alongside the cache entry in
  `des_obj_priv_int$permutations_cache`. `build_randomization_distribution_cache_key()`
  uses `permutations$signature` when present and falls back to hashing
  only for caller-supplied `permutations` without one (documented; unchanged
  behavior for that path).

- [ ] TODO-3: **No-op subset.** `subset_permutations()` returns its input
  when `indices` is `seq_len(ncol(w_mat))` (an `O(r)` check). For genuine
  prefixes (the sequential-MC batches), derive the prefix signature as
  `paste(parent_signature, length(indices))` rather than re-hashing: a
  prefix is a deterministic function of the parent set and its length.
  Assert in a test that two different parents never share a prefix key.

- [ ] TODO-4: **Integer storage end to end.** Remove the
  `storage.mode(w_mat) = "numeric"` conversion (L755); make the one
  `NumericMatrix` kernel accept an integer matrix (or coerce at that single
  call site); confirm every `Map<MatrixXi>` fast path now receives what it
  maps. Same change as `dead_randomization_fast_paths.md → TODO-2`;
  implement once, close in both.

- [ ] TODO-5: **Immutability audit + debug recheck.** Grep every consumer
  of `permutations$w_mat` / `permutations_cache` for in-place writes
  (`set()`, `[<-` on a shared reference inside Rcpp, `.Call` with
  mutating kernels). Under `should_run_asserts()`, re-hash and compare
  against the stored signature on each cache-key build so a stale
  signature fails loudly in tests rather than serving a wrong distribution.

- [ ] TODO-6: **Copies carry the signature.** `duplicate()`, the
  reusable-worker design copies and the `SimulationFramework` paths that
  hand permutation sets around must preserve `permutations$signature`
  (or drop it, in which case the fallback hash applies and the test from
  TODO-1 shows the regression).

- [ ] TODO-7: **Acceptance.** Repeat `compute_rand_two_sided_pval()` on
  the mean difference at n = r = 1000: ≤ 2 ms (from 12 ms); first call
  ≤ 18 ms (generation + construction + kernel); randomization CI time down
  proportionally to the number of bisection steps; p-values and CIs
  bit-identical to 1.0.2 for a fixed seed on every class with a fast path.
  Update the procedure table in `benchmark_model_fits.md`.

## Out of scope

- Streaming permutations through the kernel without materializing them:
  generation (14 ms) dominates either way and the cache is shared across
  inference objects by design.
- Faster generation (partial Fisher–Yates, per-thread RNG streams): changes
  the draw sequence for a given seed, so a separate decision-gated item.
- The dead fast paths themselves (`→ TODO-64`) and the closed-form nulls
  that remove the permutations entirely for some tests (`→ TODO-40`).
