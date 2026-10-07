# Randomization-CI High-Precision Refinement Ignores `lower`: Upper Bound Converges to the Wrong End of Its Bracket

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-33`. Added 2026-09-24
> from the test-comment audit: originally pinned as `SOURCE BUG` in
> `test-rand-ci-bisection-and-high-precision-refinement-reference.R`
> (`high_precision_confirm_and_refine_ci_bound()`,
> `inference_all_abstract_rand_ci.R`). The test asserts the wrong behavior on
> a controlled fixture; how often production searches enter the refinement
> loop (`high_precision_confirm = TRUE` plus `mc_enable`) remains uncertain.
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
  effect, not just the unit fixture. A controlled public-API regression now
  forces the branch, but 12 real-data runs below reached only the confirmation
  helper, not its inner refinement loop.
- [x] **TODO-2: Fix** by branching on `lower` (mirror the accepted/rejected
  side for the upper bound), and check the sibling refinement or bisection
  helpers for the same one-sided assumption.
- [x] **TODO-3: Flip the pinned test** to assert convergence to the correct
  crossing for both bounds; add a symmetric-statistic test where the lower
  and upper bounds must mirror each other.
- [ ] **TODO-4: Coverage check** with the standard randomization-CI
  simulation for one tier-1 class after the fix.

Verification (2026-10-07): the controlled public-API regression makes the
cheap p-values obscure a wide crossing and checks that both refined bounds
converge to the analytic normal-score crossings. The focused bulk suite
passed 27 expectations with `pkgload::load_all(compile = FALSE)`; the sibling
CRAN test passed 11. A bounded `InferenceContinOLS` check with a true effect
of 1, 12 independent Bernoulli designs (`n = 32`, `r = 201`, nominal 90% CI,
sequential MC enabled) produced 12 finite CIs and 11/12 covered the effect.
The confirmation helper was called for both bounds in every run, but the
inner refinement loop was not entered. This was a bounded smoke check;
the standard coverage simulation remains to be run. The 12-replicate result
cannot precisely estimate operating coverage or the pre-fix effect.
