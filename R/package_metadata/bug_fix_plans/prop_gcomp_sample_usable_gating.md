# Fix: `InferencePropGCompMeanDiff` Randomization Distribution All-NA — Reused-Worker Fast Path Never Adapted for the `rand` Operation

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-13` (moved 2026-09-23 from
> `release_v1_1_0.md → TODO-35`, bug-fix/feature split). Found 2026-09-22, surfaced as a side-finding
> during `stale_worker_cache_resampling.md`'s TODO-6 regression test
> (carried there as a self-retiring `KNOWN_BROKEN` entry); this plan is the
> dedicated fix for it.

Unrelated mechanism to `stale_worker_cache_resampling.md` — that plan
fixed a stale-cache bug (draws silently reusing a prior draw's fitted
estimate). This is a worker-state **gating** bug: every randomization draw
on this class returns `NA_real_`, not a stale value — an error-shaped
failure, not a silently-wrong number, but still a broken shipped inference
path.

## The bug, traced to source (not yet independently re-verified by direct repro in this session; high confidence per the trace below)

1. `create_bootstrap_worker_state()` (`R/EDI/R/inference_proportion_gcomp.R:424-433`)
   initializes `state$runtime$sample_usable = FALSE` (line 429) on every
   fresh reused worker.
2. `sample_usable` is set `TRUE`/`FALSE` in exactly one place:
   `load_bootstrap_sample_into_worker()` (`:434-457`) — the **bootstrap**
   row-sample loader. It runs a boundary/separation usability check
   (`bootstrap_sample_is_usable()`) and writes the result to
   `worker_state$runtime$sample_usable` (line 455), along with
   `runtime$current_X_full`/`current_y` (lines 453-454).
3. `compute_bootstrap_worker_estimate()` (`:458-464`) is the estimator:
   `if (!isTRUE(worker_state$runtime$sample_usable)) return(NA_real_)`
   (line 459), then reads `runtime$current_X_full`/`current_y`.
4. Per `EDI_RESAMPLING_DRAW_CONTRACTS$rand`
   (`R/EDI/R/contracts_resampling_draws.R:10-17`), the randomization path's
   estimator is `compute_randomization_worker_estimate`, whose **generic
   default implementation** (`R/EDI/R/inference_all_abstract_rand.R:839-845`)
   is a pure delegate: `estimator = private[["compute_bootstrap_worker_estimate"]];
   estimator(worker_state)`. `InferencePropGCompMeanDiff` never overrides
   this delegate with a randomization-specific estimator.
5. `load_randomization_perm_into_worker()`
   (`inference_all_abstract_rand.R:916` onward) is the generic,
   shared-by-every-class loader — it operates on `worker_priv$w`/`y`
   directly and has no concept of this class's private `runtime` env. It
   never touches `sample_usable`, `current_X_full`, or `current_y`.

Net effect: every randomization draw reuses the class's bootstrap-shaped
estimator, which reads a flag that only the bootstrap loader ever sets. On
the `rand` path that flag is permanently stuck at its init value `FALSE`,
so `compute_bootstrap_worker_estimate()` returns `NA_real_` on every draw —
the whole randomization distribution is uniformly NA in production.

## Broken implementation, not a missing capability declaration

`supports_reusable_bootstrap_worker()` returns `TRUE` unconditionally
(`inference_proportion_gcomp.R:421-423`) — a single flag gating the reused-
worker fast path for all of `{rand, non_param_boot, m_out_of_n_boot,
rand_bootstrap}` — so the class does intend to expose fast-path
randomization; it just never implemented it correctly.

Corroborating evidence the class **should** work here: it already has a
correct randomization-path estimator on the standard (non-reused-worker,
duplicate-per-iteration) path —
`compute_treatment_estimate_during_randomization_inference()`
(`:414-417`), which calls `private$shared()` and returns
`cached_values$md` directly, with none of the `sample_usable`/`runtime`
machinery. The bug is specifically that the reused-worker **fast-path**
estimator was written bootstrap-only-shaped and never adapted for a
permutation draw's differently-populated worker state — the fast path and
the (correct) standard path have diverged.

## Scope: isolated to this one class

`grep -rn "sample_usable" R/EDI/R/` outside `inference_proportion_gcomp.R`
returns zero hits — this `runtime`-env/`sample_usable` pattern is unique to
`InferencePropGCompMeanDiff`, not a shared mixin or base-class mechanism.
**No other class shares this defect.**

## Proposed fix (not yet applied — two options)

**Option A (recommended) — class-specific randomization estimator.**
Override `compute_randomization_worker_estimate()` on
`InferencePropGCompMeanDiff` so it does NOT delegate to
`compute_bootstrap_worker_estimate()`. Instead it should read the worker
state that `load_randomization_perm_into_worker()` actually populates (the
design-backed worker's permuted `w`/`y`) and compute the estimate the same
way `compute_treatment_estimate_during_randomization_inference()` does on
the standard path (`shared()` → `cached_values$md`), applied to the worker
clone instead of `self`. More consistent with how
`EDI_RESAMPLING_DRAW_CONTRACTS` already separates a distinct `rand`
`estimator` key from the bootstrap one — this class just never populated
it, falling through to the generic delegate.

**Option B — post-load hook in the randomization loader.** Extend
`load_randomization_perm_into_worker` with a class-specific hook
(mirroring `bootstrap_sample_is_usable()`) that populates
`runtime$current_X_full`/`current_y`/`sample_usable` from the permuted
assignment before the shared bootstrap-shaped estimator runs. Keeps one
estimator function but adds a class-specific branch to shared loader logic
— less consistent with the contract-driven separation the codebase is
moving toward (`stale_worker_cache_resampling.md`'s TODO-9 follow-up
makes the same "one shared, keep-list/contract-driven mechanism, not a
per-class branch" argument).

Recommend Option A. Not yet decided/reviewed — flagged here, not fixed.

## Status

Fixed 2026-09-23 (Option A, as recommended). Added a class-specific
`compute_randomization_worker_estimate()` override to
`InferencePropGCompMeanDiff` (`inference_proportion_gcomp.R`) — declared in
`define_inference_class()`'s `overrides$private` (required; R6/the
component system rejects an undeclared override with "overrides component
private member(s) without declaration"). Verified via direct repro: rand
distribution now 99/99 finite (`sd = 0.0162`, previously all-NA); Type-I
error at the true null measured at 0.05 over 20 reps (`r = 99`); bootstrap-
family distribution unaffected (unchanged code path, confirmed same
finite/sd behavior before and after). Removed from
`RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
`test-reused-worker-resampling-nondegenerate.R`; full suite re-run passes
(13/13). TODO-6 (CSV regeneration) still open, deferred to the same
regeneration pass as `stale_worker_cache_resampling.md → TODO-7`.

## TODOs

- [x] TODO-1: Confirm the trace above with a direct repro:
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, see top-level `CLAUDE.md`).
  Construct a minimal `InferencePropGCompMeanDiff` fixture, call
  `approximate_randomization_distribution_beta_hat_T()` (or equivalent) with
  a small `r`, and confirm all draws are `NA_real_`. Also confirm the
  *unpermuted* point estimate and the *standard-path* (non-reused-worker)
  randomization distribution both work correctly — isolating the defect to
  specifically the reused-worker fast path, not the class in general.
- [x] TODO-2: Implement Option A (add a class-specific
  `compute_randomization_worker_estimate()` override) unless TODO-1's repro
  surfaces a reason Option B is preferable — if so, that's a ruling for
  whoever picks this up, not a default.
- [x] TODO-3: Verify the fix doesn't change the *bootstrap*-family
  distributions for this class (they were already correct — confirm
  bit-for-bit, reusing `scripts/reused_worker_bitforbit_sweep.R` from
  `stale_worker_cache_resampling.md` if it still applies, or a
  narrower ad hoc check).
- [x] TODO-4: Re-run the true-null repro (analogous to
  `stale_worker_cache_resampling.md`'s TODO-5): confirm the fixed
  randomization distribution is non-degenerate and has correctly-calibrated
  Type-I error, not just "not NA."
- [x] TODO-5: Remove `InferencePropGCompMeanDiff` from
  `RESAMPLING_NONDEGENERATE_KNOWN_BROKEN` in
  `R/EDI/tests/testthat/test-reused-worker-resampling-nondegenerate.R` once
  fixed — the test's `expect_identical` against that list will fail loudly
  if this isn't done, forcing the update.
- [ ] TODO-6: Regenerate any `comprehensive_tests` CSV rows for this class's
  `rand`-family methods once fixed and installed (same caution as
  `stale_worker_cache_resampling.md`'s TODO-7 — only after install, not
  before).

## Standing constraints

Same as `stale_worker_cache_resampling.md`: no `R CMD INSTALL`/rebuild
of `R/EDI` without being asked in that turn; verify via
`pkgload::load_all(".", compile = FALSE)` only, never a full build.
