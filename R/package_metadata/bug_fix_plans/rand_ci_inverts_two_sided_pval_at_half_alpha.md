# Fix: randomization and bootstrap-randomization CIs are (1 − α/2) intervals, not (1 − α)

> **Depends on:** none. Release index:
> `../future_release_plans/release_v1_0_5.md → TODO-68`. Found 2026-10-09 by the algorithm-catalog sweep
> (`../new_feature_plans/algorithm_choice_audit.md`, per-kernel appendix,
> R shared-inference section). Confirmed by the coordinator from the code and
> from existing `comprehensive_tests` results. No new runs were needed.

## The finding

Both CI searches invert a **two-sided** p-value at threshold **α/2**:

- p-value: `compute_two_sided_randomization_pval_from_t0s`
  (`R/EDI/R/inference_all_abstract_rand.R:641`) =
  `min(1, max(2/B, 2·min(P̂(T ≥ t), P̂(T ≤ t))))`.
- Randomization CI: `compute_ci_by_inverting_the_randomization_test_iteratively(..., alpha / 2, ...)`
  (`inference_all_abstract_rand_ci.R:322,325`). Also `expand_bound(..., alpha / 2, ...)` at
  `:535-536`, and `mc_stop_threshold = alpha / 2` at `:210`.
- Bootstrap-randomization CI: `inference_all_abstract_rand_bootstrap_ci.R:314-321`
  (bisection and expansion at `alpha / 2`), `:368` (closed-form affine path,
  `pval_th = alpha / 2`, "match the bisection path's threshold convention"), and `:164`.

The acceptance region `{δ : 2·min tail(δ) ≥ α/2}` = `{δ : min tail ≥ α/4}`
is a **(1 − α/2)** interval: **97.5% at α = 0.05**. The names
`paste0(c(alpha/2, 1 - alpha/2) * 100, "%")` say 2.5% / 97.5%, which describes a 95%
interval, so the labels are wrong too. Even the comment at
`inference_all_abstract_rand_bootstrap_ci.R:358` says the acceptance region is
`{δ : pval(δ) ≥ α}`, which contradicts the code below it.

The correct pairing is either a two-sided p-value at α, or a one-sided tail
at α/2 per bound. The code mixes the two.

## Evidence (existing `package_tests/comprehensive_tests_results_nc_1_*.csv`)

Paired `compute_rand_two_sided_pval` with `compute_rand_confidence_interval`
from the same run (same rep / β_T / dataset / design / class), n = 27,896 pairs:

| rand p-value band | n | CI excludes 0 |
|---|---|---|
| p ≤ 0.02 | 8,319 | 0.93 |
| **0.03 < p ≤ 0.045** | **429** | **0.17** (a 95% inversion would give about 1.0) |
| p > 0.06 | 18,173 | 0.03 |

The remaining mismatch is Monte Carlo disagreement between the p-value draws
and the CI's own draws.

## Impact

- Every `compute_rand_confidence_interval` and
  `compute_rand_bootstrap_confidence_interval*` result is wider than
  documented. Coverage audits would read this as over-coverage
  (conservative), not as a failure, which is likely why it went unflagged.
- CI/test duality is broken: a test rejecting at 0.05 can have a "95%" CI
  that contains 0.
- It also slows the CI search a little: the target α/4 tail is deeper in the
  tail, so the MC early-stop and confirmation passes need more replicates.

## Fix

- [ ] TODO-1: Use `alpha` (not `alpha / 2`) as `pval_th` in both inverters,
  the expansion helpers, `mc_stop_threshold`, and the closed-form affine path.
  Also check the `2/B ≥ alpha/2` floor warnings at
  `inference_all_abstract_rand_bootstrap_ci.R:119-124`, which should become
  `2/B ≥ alpha`.
- [ ] TODO-2: Check every other inverter for the same convention (grep
  `alpha / 2` near `two_sided`). The asymptotic, score, and LR inverters already
  use α according to the shared-inference catalog, but confirm this.
- [ ] TODO-3: Add a duality test. On a fixture, `rand_pval(δ = bound) ≈ α` at
  each returned bound (within MC tolerance), and `0 ∉ CI` ⟺ `p < α` for a
  shared fixed permutation set.
- [ ] TODO-4: Regenerate the `rand` / `rand_bootstrap` CI rows of the
  `comprehensive_tests` CSVs, and re-run any coverage tables or docs that
  quote randomization-CI coverage.
