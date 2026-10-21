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

- [x] TODO-1: Use `alpha` (not `alpha / 2`) as `pval_th` in both inverters,
  the expansion helpers, `mc_stop_threshold`, and the closed-form affine path.
  Also check the `2/B ≥ alpha/2` floor warnings at
  `inference_all_abstract_rand_bootstrap_ci.R:119-124`, which should become
  `2/B ≥ alpha`. Implemented in both public search paths, the SMC stopping
  controls, bound expansion, bisection, and the affine shortcut; the warning
  now recommends `B > 2/alpha`.
- [x] TODO-2: Check every other inverter for the same convention (grep
  `alpha / 2` near `two_sided`). The asymptotic, score, and LR inverters already
  use α according to the shared-inference catalog, but confirm this. Confirmed:
  the shared likelihood/score/gradient inverter passes `alpha` directly to
  `pval_invert_ci_cpp`, and both Zhang inversion routes pass `alpha` to their
  bisection helper. Remaining `alpha / 2` occurrences are CI labels, two-tail
  critical values, or two-tail bootstrap quantiles.
- [x] TODO-3: Add a duality test. On a fixture, `rand_pval(δ = bound) ≈ α` at
  each returned bound (within MC tolerance), and `0 ∉ CI` ⟺ `p < α` for a
  shared fixed permutation set. Added a public fixed-permutation regression
  (399 shared assignments), generic bootstrap threshold-forwarding coverage,
  and an affine-shortcut regression whose old `alpha / 2` path returned NULL.
  Source-loaded (`pkgload`, `compile = FALSE`) focused validation passed for
  the randomization bisection/bounds, bootstrap-randomization CI guards and
  floor warning, the full bootstrap-randomization suite, the general rand-CI
  suite, custom-statistic delta shifting, and model-scale classification.
  **Focused source-loaded refresh, 2026-10-18:**
  `test-rand-ci-bisection-and-high-precision-refinement-reference.R` (30
  assertions) and `test-rand-bootstrap-ci-closed-form-and-bisection-failed-guards-reference.R`
  (9 assertions) passed after loading checkout R sources with
  `pkgload::load_all("R/EDI", compile = FALSE)`. Native calls used installed
  EDI 1.0.3's `EDI.so` (MD5
  `dd43c5d0e11708aea17ba82b900f66d1`, timestamp 2026-10-18 03:57:33 +0300).
  This is current R-source/installed-native evidence only; it does not validate
  a current-checkout native build or regenerate the comprehensive results.
  **Post-HEAD installed-package recheck, 2026-10-20:** reran both focused
  tests with `testthat::test_file(..., package = "EDI")`: the rand-CI
  bisection/high-precision test passed 30 assertions, and the bootstrap-CI
  closed-form/failure-guard test passed 9 (39 total; 0 failures, warnings, or
  skips). Installed EDI is version 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its `EDI.so` SHA-256
  is `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`,
  embedded build time `2026-10-19 23:31:50 IDT`, mtime `23:47:15 IDT`. The
  build postdates HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`
  (`21:03:16 IDT`), but the package embeds no Git SHA; the checkout's
  `inference_all_abstract_rand_ci.R` also has an uncommitted change, so this
  installed-package run is not claimed as validation of that worktree diff.
  It adds focused artifact evidence only; TODO-4's comprehensive-row
  regeneration/reconciliation remains open. No build/install or canonical
  output write was performed.
  **Focused checkout-source refresh, 2026-10-20:** repeated the same two
  focused files via `pkgload::load_all("R/EDI", compile = FALSE)` followed
  by `testthat::test_file()`: the rand-CI bisection/high-precision test passed
  30 assertions and the bootstrap-CI closed-form/failure-guard test passed 9
  (39 total; 0 failures, warnings, or skips). `load_all()` reported EDI 1.0.3
  and loaded `/tmp/Rtmplddi1a/pkgload21b3d676d/EDI.so`; the corresponding
  installed library DLL at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` has
  SHA-256 `5a0b94978e5d9150d2aa6f69df7135a164fe032b3a3e301495c5cfd7f6ca3224`.
  The current R source `inference_all_abstract_rand_ci.R` is modified in the
  shared worktree, so these results exercise that checkout source with the
  existing installed native library; they do not establish native/source
  build parity or validate comprehensive rows. No compile/install occurred.
  **Installed-package focused recheck after the 2026-10-20 native build:**
  ran the same two test files directly against installed EDI using
  `testthat::test_file(..., package = "EDI")`, without source loading. The
  bisection/high-precision file passed 37 expectations and the bootstrap
  closed-form/failure-guard file passed 9 (46 total; 0 failures, warnings, or
  skips). The fixed-permutation public-CI test checks both returned-bound
  two-sided p-values against `alpha` and the CI/test duality at zero; the
  bootstrap file checks `alpha` forwarding to bound expansion, bisection, and
  MC stopping, plus the affine shortcut's `alpha` threshold. Installed EDI
  reported version 1.0.3 at
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; its loaded DLL is
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so`, 14,727,184
  bytes, mtime 2026-10-20 09:38:02 +0300, MD5
  `a75519a9256c0b3121398032314291d4`, SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`.
  Checkout `R/EDI/src/EDI.so` is byte-identical. The package carries no
  embedded Git SHA, and `inference_all_abstract_rand_ci.R` remains modified in
  the worktree, so this validates the installed package/artifact only, not
  that uncommitted R diff. TODO-4's comprehensive-row regeneration, exact-key
  reconciliation, and coverage/documentation update remain open; no timing,
  build/install, or canonical output write occurred.
  **Current-checkout source/current-native recheck, 2026-10-20:** reran the
  same two focused tests after `pkgload::load_all("R/EDI", compile = FALSE,
  quiet = TRUE)`. The bisection/high-precision suite passed 37 assertions and
  the bootstrap-CI closed-form/failure-guard suite passed 9 (46 total; no
  failures, warnings, or skips). R-devel was `r90668`, namespace path was
  `/home/kapelner/workspace/EDI/R/EDI`, and checkout HEAD was
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. Loaded DLL SHA-256 was
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`;
  read-only SHA-256 and `cmp -s` checks confirmed it matches both the
  user-rebuilt installed DLL and checkout `R/EDI/src/EDI.so`. The source hashes
  were `0692be524ec0c7c8c84ea2d23c44bdfe3e8672dfd32c5bee3093a4c82a016229`
  (`inference_all_abstract_rand_ci.R`) and
  `b28ea7c67853e4362b888282a94b36b609f0499d3aad6ad7e613574eb031d36c`
  (`inference_all_abstract_rand_bootstrap_ci.R`); the test hashes were
  `9ab218cd084ace499bc071e6a0fc04ff188af40babeccd473c35b8fcafe45105` and
  `1f476c0430ac489ca2cc03495841e2630b588e5b8a308832acb2cee53f3e6441`.
  This closes focused checkout-R/current-native provenance for those tests
  only. Comprehensive-row regeneration, exact-key reconciliation, and
  coverage/documentation updates remain open. No build/install or canonical
  output write occurred.
  **Focused checkout-source refresh, 2026-10-21:** after confirming no other
  R/Rscript process was active, ran only
  `test-rand-ci-bisection-and-high-precision-refinement-reference.R` after
  `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`. The test file
  completed with no failures. Loaded EDI 1.0.3 from checkout namespace
  `/home/kapelner/workspace/EDI/R/EDI`; its temporary DLL was
  `/tmp/RtmpcPZaxM/pkgload242616505/EDI.so`, MD5
  `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`.
  This is focused current checkout-R/current-user-native evidence for this
  test file only; it does not close the comprehensive-row regeneration,
  exact-key reconciliation, or coverage/documentation gates. No build,
  install, source/test edit, or canonical output write occurred.
  **Retained isolated-slice artifact audit, 2026-10-21:** the existing
  scratch outputs `/tmp/edi-todo68-rand-reps1to40.WXrm3D/` and
  `/tmp/edi-todo68-brt-reps1to40.n9uAFr/` contain one complete 40-replicate
  `diamonds` / continuous / Bernoulli / `InferenceContinOLS` run per family
  at `beta_T=0.5`. Each output has 480 unique seven-field keys over reps 1:40,
  four model/design-formula labels, and three emitted operations; every row is
  `status=ok`. The `rand` file includes the CI operation plus both public
  p-value operations; the `rand_bootstrap` file includes its plain CI and two
  p-value operations, but no studentized, symmetric-percentile-t, or smoothed
  CI variant. The result/sidecar SHA-256 pairs are respectively
  `11658067064b9de3c36898195b2127cb5660d83cc0a271f91ddf2c4aed99d36f` /
  `5790b1a983ae34a11dad72e178f38568c15866c7946005ed77de7f1c811bd864` and
  `8885a6dca4f3382178f7f5d24b17f448b3d2e0c108fc89a2aa1175045451a6cd` /
  `7bcca9017991471d4a2fc82353e5f3a11b6b90ba381411310290863ca7d62a27`.
  Both run sidecars bind their output path/hash and fresh-file state
  to command arguments, checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`,
  checkout diff SHA-256 `88775848fae74c2ced98070ab6663d9496444aa3440b9fdd38ecbf6b8e233360`,
  runner SHA-256 `660dae16378ce533bf1d7bb816b2e7933b989bff838e93907889ec0cbf024159`,
  EDI 1.0.3 checkout namespace, R-devel `r90668`, and existing DLL SHA-256
  `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`.
  This is provenance-stamped execution evidence for one scratch selector, not
  a candidate-vs-attempt anti-join or full-grid reconciliation; it does not
  cover other strata or the omitted bootstrap-CI variants and is not canonical
  data. The full TODO-4 gate remains open.
  **Exact-key check of retained isolated slices, 2026-10-21:** independently
  parsed each CSV and compared its seven-field keys against the slice's exact
  selector: reps 1:40 × four observed model/design-formula labels × three
  family-specific emitted operations, with beta 0.5, diamonds, continuous,
  and Bernoulli fixed. Both `rand` and `rand_bootstrap` artifacts have 480/480
  expected keys, zero missing or extra keys, no duplicate keys, and all rows
  `status=ok`. This closes only exact-key/status validation for those two
  retained scratch slices; it does not establish full-grid attempt coverage,
  cover the omitted bootstrap-CI variants, or validate/update canonical rows.
- [ ] TODO-4: Regenerate the `rand` / `rand_bootstrap` CI rows of the
  `comprehensive_tests` CSVs, and re-run any coverage tables or docs that
  quote randomization-CI coverage.

  Reconciliation audit (2026-10-16): the targeted CI slice is the exact
  `compute_rand_confidence_interval` and
  `compute_rand_bootstrap_confidence_interval` `function_run` allowlist,
  including `_studentized`, `_symmetric-percentile-t`, and `_smoothed`
  variants. A read-only audit of the current continuous/count/proportion/
  survival CSVs found 44,905/4,877/2,038/19,349 selected rows respectively;
  every selected row had `status=ok` and complete seven-field keys. The
  continuous CSV has 83 duplicated keys (82 with conflicting
  result/status/coverage signatures across historical commits) and 3
  duplicated `run_row_id` values. The other three CSVs have no duplicate
  seven-field keys. Therefore key-wise upsert is unsafe, especially for
  continuous. After a full fresh regeneration, replace the targeted CI slice
  as a whole in each affected CSV, preserve non-target rows, and verify
  targeted cell coverage plus fresh `run_row_id` uniqueness. This audit does
  not close TODO-4: the current canonical rows have not been regenerated.

  **Runner-eligibility reconciliation, 2026-10-20:** the static CI-attempt
  helper had constructed class proxies without their R6 parent ancestry, so
  its capability result could disagree with the comprehensive runner. It now
  follows the registered class-parent chain. The focused regression
  `R/package_tests/testthat_bulk/test-comprehensive-rand-ci-eligibility-reference.R`
  passed 42 expectations after loading checkout R sources with
  `pkgload::load_all("R/EDI", compile = FALSE)`. In particular, static
  eligibility now agrees with the runner for KK21/Bernoulli: the count-KK
  hurdle class has no `rand_bootstrap` CI attempt under KK21, while the
  Bernoulli comparison retains the eligible path. This is helper/runner
  eligibility evidence only; it does not regenerate results or close TODO-4's
  full affected-row reconciliation gate.
