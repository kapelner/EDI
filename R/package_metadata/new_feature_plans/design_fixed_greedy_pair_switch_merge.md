# Merge `DesignFixedGreedy` into `DesignFixedGreedyDOptimal` as `DesignFixedGreedyPairSwitch`

> **Depends on:** `fix_design_hierarchy.md`'s Stage-2 shared greedy-swap
> engine extraction (still `[ ]` in that plan's Follow-Ups as of 2026-08-16 —
> see `design_fixed_optimal.md`'s dependency header for the same
> verification) and the completed `DesignFixedGreedyDOptimal` Stage 1. This
> plan is best sequenced as Stage 2's natural conclusion: Stage 2 unifies the
> *engine* (same swap loop, same OpenMP parallelism/seeding, same stochastic
> `n_iter` mode for both families); this plan removes the one remaining
> *mathematical* obstacle (the `prob_T = 0.5` constraint baked into
> `DesignFixedGreedy`'s current swap-delta formulas) that Stage 2 alone does
> not touch. Land this after Stage 2, not before — rederiving the math against
> a kernel that's about to be rewritten wastes the rederivation.
> **Explicit non-goal for v1.0.0** (user instruction, 2026-08-16): this is a
> **post-1.0.0, additive 1.x target**. Do not pull any part of this into the
> v1.0.0 release batch; `_master.md`/`release_v1_0_0.md` are updated to record
> it as deferred.
> (Global ordering: see `_master.md`.)

Date: 2026-08-16

## Purpose

`DesignFixedGreedy` and `DesignFixedGreedyDOptimal` are, after the completed
A/D merge and the (pending) Stage-2 engine unification, differentiated by
exactly two things:

1. **Objective family**: model-free covariate-balance criteria
   (`"mahal_dist"`, `"abs_sum_diff"`) vs. model-based information criteria
   (`"D"`, `"A"`, and their Bayesian/subset variants).
2. **Balance constraint**: `DesignFixedGreedy` requires exactly
   `prob_T = 0.5` (constructor stop, even-`n` requirement, and — the deeper
   reason — a swap-delta formula in the C++ kernel that is only algebraically
   correct at that specific balance point); `DesignFixedGreedyDOptimal`
   accepts any `prob_T` via `n_T = round(n * prob_T)`.

Difference 1 is not an obstacle to merging — it is exactly the kind of
"flavor" axis the `objective` argument already unifies across both
`DesignFixedGreedyDOptimal` (`"D"`/`"A"`) and `DesignFixedOptimal`
(`"D"`/`"A"`/`"mahal_dist"`/`"abs_sum_diff"`/`"custom"`). Difference 2 is the
one genuine obstacle, and it is a **mathematical** one, not an architectural
one: the current `greedy_design_search_cpp` kernel's swap-delta update is
derived (and hardcoded) for the balanced case specifically. This plan removes
that obstacle by rederiving the general-`prob_T` swap-delta formula, then
merges `DesignFixedGreedy`'s objectives into `DesignFixedGreedyDOptimal`
under a new name, **`DesignFixedGreedyPairSwitch`** (user-specified,
2026-08-16), and deletes both prior classes outright.

## Where the balance constraint actually lives (verified against the shipped kernel)

Three layers, cited precisely so the rederivation below can be checked
against them:

1. **R-level validation**: `design_fixed_greedy.R`'s constructor stops on
   `prob_T != 0.5`; `draw_ws_raw()` additionally requires even `n`.
2. **C++ kernel has no `n_T` parameter at all**: unlike
   `d_optimal_search_cpp`/`a_optimal_search_cpp` (which take `n_T` as an
   argument), `greedy_design_search_cpp` (`design_fixed_greedy.cpp`)
   hardcodes `const int nt = n / 2;` — balance isn't passed in, it's assumed.
3. **The objective's algebraic form only means "balance criterion" at
   `n_T = n_C`**: the kernel's header comment states the invariant precisely:
   `d = M * (2w - 1)`, `M` a `p x n` matrix (`M = X_std'/n` for
   `abs_sum_diff`, `M = L^-1 X'/n` for `mahal_dist`, `L` the Cholesky factor
   of the unconditional sample covariance `Σ = X'X/(n-1)` — confirmed
   `Σ`'s construction does **not** depend on the treatment/control split at
   all, only `d`'s does). At balance, `(1/n) * sum((2w_i-1) x_i) = (mean_T -
   mean_C)/2` (a positive scalar multiple of the true mean-difference,
   confirmed by direct expansion: `(n_T/n) mean_T - (n_C/n) mean_C =
   (1/2)mean_T - (1/2)mean_C` when `n_T = n_C = n/2`) — so minimizing `‖d‖`
   is minimizing (a scalar multiple of) the treated-minus-control mean
   difference, exactly the balance interpretation the class documents. Away
   from balance, `(2w-1)` is no longer the right per-subject weight for that
   interpretation to hold.

## The rederivation (worked out and verified against the kernel's exact scaling convention)

Generalize the per-subject weight from `v_i(w) = 2w_i - 1` (fixed ±1) to a
weight that reduces to today's `2w-1` **exactly** at `n_T = n_C = n/2`, and
gives a genuine (scalar multiple of) `mean_T - mean_C` at every `n_T`:

```
v_i(w) = w_i * (n / (2 n_T)) - (1 - w_i) * (n / (2 n_C))
```

Check: at `n_T = n_C = n/2`, the coefficients are `n/(2*(n/2)) = 1` for both
terms, giving `v_i = w_i - (1-w_i) = 2w_i - 1` — **exact reduction to the
current formula**, not an approximation. In general,
`d(w) = M %*% v(w) = M %*% [w/(2n_T) - (1-w)/(2n_C)] * n`, which expands
(confirmed by direct substitution) to `d(w) = (1/2)[mean_T(M-columns) -
mean_C(M-columns)]` for **any** `n_T` — the same "half mean-difference"
interpretation the balanced case already has, now valid at every balance
point, not just `n_T = n/2`.

**Swap-delta**, the quantity the search loop actually needs on every
iteration (currently `delta = 2.0 * (M.col(j) - M.col(i))`,
`design_fixed_greedy.cpp`, verified at all 5 call sites in the exhaustive and
stochastic search branches): swapping treated index `i` (leaves treatment) for
control index `j` (enters treatment) leaves `n_T`/`n_C` unchanged (a swap
always preserves group sizes), so the coefficients `n/(2n_T)`, `n/(2n_C)` are
swap-invariant constants for the whole search. Only the *set* of columns
contributing to each sum changes:

```
Δv_i = -n/(2n_C) - n/(2n_T)     (i leaves treatment: was +n/(2n_T), becomes -n/(2n_C))
Δv_j = +n/(2n_T) - (-n/(2n_C))  (j enters treatment: was -n/(2n_C), becomes +n/(2n_T))
     = n/(2n_T) + n/(2n_C)
```

Both have the same magnitude (as they must, by the antisymmetry of a single
swap), giving:

```
delta = (n/2) * (1/n_T + 1/n_C) * (M.col(j) - M.col(i))
```

**Exact reduction check**: at `n_T = n_C = n/2`, `(n/2)*(1/n_T + 1/n_C) =
(n/2)*(4/n) = 2` — reproduces the kernel's current literal `2.0` exactly.
This is the single line that needs to change in the kernel: replace the
hardcoded `2.0` with `(n/2.0) * (1.0/n_T + 1.0/n_C)` (computed once per
design, since `n_T`/`n_C` are fixed for the whole search — not recomputed
per swap).

**Why the rest of the incremental-update machinery needs no rederivation**:
the identities `‖d+Δ‖² = ‖d‖² + 2 d·Δ + ‖Δ‖²` (used for `mahal_dist`'s
incremental `f`) and the direct `(d+Δ).lpNorm<1>()` re-evaluation (used for
`abs_sum_diff`) are generic algebraic facts about *any* vector `Δ`,
independent of what `Δ` represents — they do not encode a balance
assumption anywhere, only the *value* of `Δ` (the `delta` line above) does.
Confirmed by reading the actual incremental-update code
(`design_fixed_greedy.cpp`, both the exhaustive-search and stochastic-mode
branches): every one of the 5 sites computing `delta` and then evaluating
`f(d+delta)` uses these same generic identities.

**Initial `d`** (computed once per search from the BCRD start, currently
`dbl_w[i] = 2.0*w[i] - 1.0` then `d = M * dbl_w`): generalizes the same way —
replace `dbl_w[i] = 2.0*w[i] - 1.0` with the general
`v_i = w[i] * (n/(2.0*n_T)) - (1-w[i]) * (n/(2.0*n_C))`, an equally cheap
one-time O(n) computation.

**Covariance/whitening (`M`'s construction)**: unaffected — verified
`cov_mat = X'X/(n-1)` is the unconditional sample covariance over all `n`
subjects, with no dependence on treatment/control split anywhere in its
construction.

## What still needs checking (not derived here — flagged honestly)

- **Pair-constrained init branch.** The kernel has a `pair_mode`/`pairs`/
  `pair_cur_t` code path (confirmed present, `design_fixed_greedy.cpp`) not
  accounted for in the derivation above — trace what this branch is for
  (matched-pair-constrained search? shared with
  `DesignFixedMatchingGreedyPairSwitching`, whose name this plan's target
  class name deliberately echoes — confirm whether that's a real code
  relationship or a naming coincidence before assuming one) and re-derive or
  confirm-unaffected separately.
- **Stochastic mode's patience/early-stopping logic.** `n_iter >= 0` mode
  picks random pairs and accepts on improvement with patience-based early
  stopping — check whether any patience/tolerance threshold implicitly
  assumes the balanced-case delta magnitude (`2.0 * |M_j - M_i|`-scale) rather
  than being scale-invariant; if scale-dependent, the threshold needs to
  generalize alongside `delta` itself, not just the delta formula.
- **`abs_sum_diff`'s "fused expression, no temp vector" optimization**
  (per the kernel's own header comment) — confirm the fusion doesn't
  hardcode the `2.0` constant separately from the `delta` computation site
  already covered above (i.e., that there isn't a *second* place the balance
  assumption is baked in that a single-line change to `delta` would miss).
- **R-level validation removal**: drop the `prob_T != 0.5` constructor stop
  and the even-`n` requirement in `draw_ws_raw()` — replace with the same
  always-on `n_T = round(n*prob_T)` in `(1, n-1)` check
  `DesignFixedGreedyDOptimal`/`DesignFixedOptimal` already use (per the
  `DesignFixedGreedy` `prob_T`-bypass follow-up already tracked in
  `fix_design_hierarchy.md`).
- **Seed-reproducibility regression**: re-run the empirical same-seed check
  at several non-`0.5` `prob_T` values once the above lands, not just at the
  historical `0.5` case.

## Class merge target: `DesignFixedGreedyPairSwitch`

Once the rederivation above is implemented and verified, there is no
principled reason left to keep `DesignFixedGreedy` and
`DesignFixedGreedyDOptimal` as separate classes — after Stage 2 (shared
engine) and this plan (shared balance math) both land, they differ *only* in
which values `objective` may take, exactly the kind of difference the
`objective` argument already absorbs elsewhere in this class family (the
completed A/D merge; `DesignFixedOptimal`'s five-way `objective` enum).

- **New class name: `DesignFixedGreedyPairSwitch`** (user-specified,
  2026-08-16, superseding `DesignFixedGreedyDOptimal` as the surviving name —
  this plan's merge target absorbs and replaces that class, not the other
  way around).
- `objective` extends to the closed set `c("D", "A", "mahal_dist",
  "abs_sum_diff")` (**not** `"custom"` — that stays exclusive to the
  unrelated `DesignFixedOptimal` single-allocation class; this merge is
  purely `DesignFixedGreedy` + `DesignFixedGreedyDOptimal`, not a three-way
  merge with `DesignFixedOptimal`, which remains separate per that plan's
  own TODO-1 resolution).
- `interest`/`prior_precision`/`standardize_covariates` remain meaningful
  only for `objective %in% c("D", "A")`, exactly as today; `"mahal_dist"`/
  `"abs_sum_diff"` ignore them (validated: error if supplied with a
  non-default value under those objectives, per the existing
  argument-dependent-contract discipline this class family already
  practices).
- `prob_T` becomes unconstrained (any value in `(0,1)` with
  `1 <= n_T <= n-1`) for **every** objective, closing the gap this plan
  exists to close.
- Both `DesignFixedGreedy` and `DesignFixedGreedyDOptimal` are **deleted
  outright** (no aliases — the established no-alias policy for this
  unreleased-at-the-time-of-writing class family), with the same
  reference-sweep discipline used for the A/D merge: registry enum
  collapse (one `randomization_family` value, e.g.
  `"greedy_pair_switch"`), `EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME`/
  `EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES`/closed-enum test updates,
  `DESCRIPTION` Collate update, every roxygen cross-reference to either old
  name (including `DesignFixedOptimal`'s own docs, which currently reference
  `DesignFixedGreedy` by name), `vignettes/reproducibility.Rmd`, and
  `fix_documentation.md`'s per-Rd TODOs for both deleted classes marked
  superseded.
- **Reuses `DesignFixedOptimal`'s shared internal helper (TODO-1b in
  `design_fixed_optimal.md`)** for the `objective`/`interest`/
  `prior_precision`/`standardize_covariates` validation and `P`/`H`/`H_S`/
  `H_B` construction under `"D"`/`"A"` — do not write a third copy of that
  logic. If `design_fixed_optimal.md`'s TODO-1b hasn't landed by the time
  this plan is implemented, implement it first (or as part of this plan) —
  don't duplicate-then-reconcile.

## Testing plan

1. **Golden reduction at balance**: with `prob_T = 0.5`, the general
   formula's `delta`/initial-`d` must be **bit-identical** to today's
   `DesignFixedGreedy` output under the same seed — this is a strong,
   directly-derivable regression test (not just "close"), since the general
   formula was constructed to reduce exactly, not approximately, at that
   point.
2. **Brute-force optimality at small `n`, non-`0.5` `prob_T`**: for tiny `n`
   (say `n <= 14`), brute-force all `choose(n, n_T)` allocations and confirm
   the exhaustive-mode (`n_iter = Inf`) search reaches the same local-optimum
   quality a from-scratch objective evaluation would certify as a true local
   optimum (no single swap improves) — this doesn't certify global
   optimality (the greedy search never has), but does certify the
   incremental `delta` machinery agrees with a from-scratch recomputation at
   every step, which is the thing most likely to silently break in this
   rederivation.
3. **Incremental-vs-from-scratch consistency check**: at several non-`0.5`
   `prob_T` values, assert `f(d)` computed incrementally via `delta` matches
   `f` recomputed from scratch from the current `w` at every accepted swap
   (a direct numerical audit of the derivation above, not just an end-to-end
   outcome check).
4. **Pair-mode and patience-threshold behavior**: once the two "what still
   needs checking" items above are resolved, add dedicated tests for
   whichever behavior they turn out to require.
5. **Seed reproducibility** at several non-`0.5` `prob_T` values (same-seed,
   twice, identical draws).
6. **Full reference sweep** after deletion: `grep -rn
   "DesignFixedGreedy\b\|DesignFixedGreedyDOptimal"` across `R/`, `tests/`,
   `package_tests/`, `package_metadata/` must return only intentional
   historical mentions (e.g., this plan's own text, changelog entries), not
   live code/doc references.

## TODO Checklist

- [ ] TODO-1: Confirm this plan proceeds only after `fix_design_hierarchy.md`'s
  Stage-2 shared-engine extraction lands (per the dependency header) —
  re-verify that item's status before starting, since rederiving against a
  kernel about to be rewritten wastes the work.
- [ ] TODO-2: Investigate the `pair_mode` branch in `design_fixed_greedy.cpp`
  and its relationship (if any) to `DesignFixedMatchingGreedyPairSwitching`
  before finalizing the target class name's implied scope.
- [ ] TODO-3: Rederive/verify the stochastic-mode patience/early-stopping
  threshold's scale-dependence; generalize if needed.
- [ ] TODO-4: Verify the `abs_sum_diff` "fused expression" optimization has
  no second hardcoded balance assumption beyond the `delta` site.
- [ ] TODO-5: Implement the general `delta`/initial-`v(w)` formulas in the
  kernel (single-line-scale change at `delta`'s computation sites, per the
  worked derivation above); pass `n_T`/`n_C` into the kernel (it currently
  takes none).
- [ ] TODO-6: Remove the R-level `prob_T = 0.5`/even-`n` validation; replace
  with the standard `n_T = round(n*prob_T) in (1, n-1)` always-on check.
- [ ] TODO-7: Implement the class merge: `DesignFixedGreedyPairSwitch` via
  `define_design_class()`, `objective` extended to `c("D","A","mahal_dist",
  "abs_sum_diff")`, built on `design_fixed_optimal.md`'s shared
  validation/`P`/`H` helper (TODO-1b there — implement first if not already
  landed). Delete `DesignFixedGreedy`/`DesignFixedGreedyDOptimal` outright.
- [ ] TODO-8: Full reference sweep and update: registry enum/`BY_NAME`/
  seed-reproducibility tables, closed-enum tests, `DESCRIPTION` Collate,
  every roxygen cross-reference (including `DesignFixedOptimal`'s own docs),
  `vignettes/reproducibility.Rmd`, `fix_documentation.md`'s per-Rd TODOs for
  both deleted classes, `simulations_framework.R`'s generator list,
  `package_tests/comprehensive_tests.R`/`audit_comprehensive_suite_baseline.R`
  harness keys.
- [ ] TODO-9: Test suite per the Testing plan above (golden reduction,
  brute-force + incremental-consistency at non-`0.5` `prob_T`, pair-mode/
  patience tests once TODO-2/TODO-3 resolve, seed reproducibility, full
  reference sweep).
- [ ] TODO-10: Documentation: full roxygen for `DesignFixedGreedyPairSwitch`
  (objective/argument mapping table in the established D_M/D_s/D_A/D_B
  style, now also covering `"mahal_dist"`/`"abs_sum_diff"`'s model-free
  criteria and their argument-ignoring behavior under those objectives),
  `Rscript fast_roxygenize.R`, `reproducibility.Rmd` update.
