# Randomization-CI High-Precision Refinement Ignores `lower`: Upper Bound Converges to the Wrong End of Its Bracket

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-33`. Added 2026-09-24
> from the test-comment audit: pinned as `SOURCE BUG (pinned, not fixed)` in
> `test-rand-ci-bisection-and-high-precision-refinement-reference.R`
> (`high_precision_confirm_and_refine_ci_bound()`,
> `inference_all_abstract_rand_ci.R`). The test asserts the wrong behavior on
> a controlled fixture; how often production searches reach this path
> (`high_precision_confirm = TRUE` plus `mc_enable`) is not established.
> Complements `../new_feature_plans/randomization_ci_search_precision.md` and
> `../new_feature_plans/randomization_ci_construction_audit.md`.

## The finding

In the refinement loop, when `p(m) >= threshold` the code always sets
`u2 <- m`. That is correct for a **lower** bound (the accepted side is the
upper end of the bracket) but wrong for an **upper** bound, where the
accepted side is the lower end. For an upper bound the loop therefore walks
`u2` down to `l2` instead of up to the crossing, and the refined upper bound
lands at the wrong end of its bracket. The function takes a `lower` flag but
the branch ignores it.

## Items

- [ ] **TODO-1: Reproduce end to end.** Find a real
  `compute_rand_confidence_interval()` call with `high_precision_confirm =
  TRUE` whose upper bound is moved to the wrong end; measure the coverage
  effect, not just the unit fixture.
- [ ] **TODO-2: Fix** by branching on `lower` (mirror the accepted/rejected
  side for the upper bound), and check the sibling refinement or bisection
  helpers for the same one-sided assumption.
- [ ] **TODO-3: Flip the pinned test** to assert convergence to the correct
  crossing for both bounds; add a symmetric-statistic test where the lower
  and upper bounds must mirror each other.
- [ ] **TODO-4: Coverage check** with the standard randomization-CI
  simulation for one tier-1 class after the fix.
