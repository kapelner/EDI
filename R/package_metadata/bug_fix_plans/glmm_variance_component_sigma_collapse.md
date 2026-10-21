# Random-Effect Variance Collapse: GLMM/CLMM Fits Slide to the `log sigma` Boundary, Report `converged = TRUE`, and Return a Biased Estimate

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-31`. Added 2026-09-24 from
> an audit of the test-file comments (four existing tests pin these as
> `SUSPECTED SOURCE BUG (pinned, not fixed)`). The tests pass today, so the
> behavior is reproduced by the pinned fixtures; the extent across real data
> and the right fix are **not** established. Related, not duplicate:
> `multimodal_log_liks.md` and `../new_feature_plans/multistart_nonconcave_likelihoods.md`
> (v1.2.0 TODO-20) plan a general multistart for nonconcave kernels; this
> plan is the targeted, observed-wrong-answer subset and may be resolved by
> a narrow change well before that infrastructure lands.

## The finding

Four random-intercept kernels, from the same family of failure, in which
the optimizer slides `log sigma` to the lower boundary (about `-3`), stops
with `converged = TRUE`, and lands at a strictly worse likelihood and a
biased treatment coefficient:

| kernel / class | pinned by (test file) | observed |
|---|---|---|
| `fast_ordinal_clmm_cpp` started at `log sigma = -3` (the KK CLMM classes' `clmm_warm_start()`, `c(alpha_par, beta_nore, -3.0)` in `inference_ordinal_KK_clmm_abstract.R`) and its own cold start | `...ordinal-clmm-kernel-ordinal-package-agreement-and-sigma-collapse-from-minus-three-start...` | 6 of 12 simulated datasets (true sigma 0.9); worse nll and biased `b` |
| `InferenceOrdinalKKCLMM` (class level, same kernel) | `...ordinal-kk-glmm-class-matches-clmm-and-kk-clmm-class-collapses-to-fixed-effects...` | seed-302 fixture: estimate 0.4101 = fixed-effects `polr` 0.4100, vs `ordinal::clmm` / `InferenceOrdinalKKGLMM` 0.4228; the random effect is lost |
| `fast_logistic_glmm_cpp` default cold-start L-BFGS | `...logistic-glmm-fit-glmer-agreement-and-cold-start-variance-collapse...` | 12 of 30 datasets; up to ~2.4 nats worse; non-positive/non-finite variance in the pinned case |
| `InferenceCountKKGLMM` (`fast_poisson_glmm_cpp`, `optimization_alg = "newton_raphson"`) | `...count-kk-classes-match-joint-optimum-geeglm-and-glmer-and-newton-sigma-collapse...` | seed-6 fixture: log sigma about -3.5, `converged = TRUE`, gradient norm about 0.3, estimate 0.5475 vs L-BFGS / `glmer` 0.5359; on most datasets the optimizers agree |

A separate, related kernel-consistency defect, pinned in
`...logistic-glmm-neg-loglik-score-hessian-kernels...`:
`get_logistic_glmm_hessian_cpp`'s log-sigma row/column disagrees with the
Jacobian of the package's own (correct) score, and its diagonal has the wrong
sign (`h[3,3] > 0`, `|h - jac| > 1`). Anything that uses that Hessian for
standard errors at the sigma coordinate is suspect.

## Why it matters

Silently wrong estimates with a "converged" flag, in the KK classes that are
the package's default for matched designs. It also interacts with the
diagnostics work: `converged` here is gradient-norm based with a boundary
fallback that is not being treated as a failure (see
`../new_feature_plans/optimizer_diagnostics_report.md`, "valid lower-variance
boundary" handling). Careful: some sigma-at-boundary fits are legitimate
(true sigma near 0); the failure is a *non-stationary* boundary stop at a
worse likelihood.

## Resolution audit (2026-10-09)

The three distinct affected native fitters now use the same deterministic
log-sigma multistart pattern already used by `fast_ordinal_glmm_cpp`: retain
the supplied/cold start, add `{-1, 0, 1}` and the lower variance boundary,
respect a fixed log-sigma coordinate, and select the finite fit with the
smallest objective. `InferenceOrdinalKKCLMM` also now supplies a neutral
`log_sigma = 0` warm start. This fixes both the CLMM kernel/class fixtures and
the logistic/Poisson GLMM cold-start fixtures without changing the public
optimizer-policy contract (in particular, `InferenceCountKKGLMM` still uses
`newton_raphson`; the kernel makes that choice robust to its starting basin).

The logistic Hessian discrepancy was a chain-rule error. In
`LogisticGLMMObjective::hessian`, `node_factor` is already
`sqrt(2) * sigma * z`; its beta/log-sigma and log-sigma/log-sigma terms
multiplied by `sigma` one extra time. Those factors are removed, and the
regression now requires the full matrix to agree with both the score Jacobian
and the independently differentiated marginal likelihood.

The pre-fix characterization is preserved by the former pinned fixtures:
CLMM collapsed in 6/12 simulations at `n = 200`, true sigma 0.9; logistic
GLMM collapsed in 12/30 simulations at the same size/sigma; and Poisson
Newton had the deterministic seed-6 failure while agreeing on the four
seed-701--704 controls. A broader sigma-by-n grid and post-fix rates require
executing the rebuilt native library and remain part of TODO-1 below.

Reach sweep: `fast_ordinal_glmm_cpp` already has deterministic multistart;
Gaussian LMM starts its random-effect SD at half the residual SD rather than
at `-3`; the combined conditional-logistic/GLMM kernel initializes log sigma
at zero. There is no negative-binomial random-intercept kernel in this
checkout. `fast_hurdle_poisson_glmm_cpp` still has a single `-3` cold start,
but no pinned collapse or evidence of a wrong basin; it is recorded here for
the general v1.2 multistart plan rather than expanding this observed-defect
fix without a reproducer.

Static validation completed without compiling: all five edited R regression
files and the edited R class file parse, and `git diff --check` passes. Native
behavior cannot be validated until the package is rebuilt. After that, run
the five focused bulk regressions, the sigma-by-n characterization grid, and
the affected KK comprehensive rows; regenerate installed comprehensive CSVs
only after those checks pass.

**Installed-package validation 2026-10-14:** the user-reinstalled package
(reports EDI 1.0.3) passed the five focused native regression files: ordinal
CLMM kernel (23 assertions), ordinal KK class (8), logistic GLMM (13), KK
count GLMM (11), and logistic score/Hessian (7), for 62 passing assertions
with no failures or warnings. Codex did not compile, build, or install. The
bounded sigma-by-n characterization grid (TODO-1) has since been run against
the installed package; its partial evidence and residual Poisson local-optimum
cases are recorded below. Affected KK comprehensive-row regeneration
(TODO-6) remains outstanding.

## Items

- [ ] **TODO-1: Characterize.** For each of the four kernels, measure the
  rate of boundary stops with a strictly worse likelihood (vs. a high-quality
  reference: `ordinal::clmm(nAGQ=25)`, `glmer`) across a small grid of true
  sigma and `n`. Separate legitimate boundary solutions from non-stationary
  stops using the gradient norm at the stop.
  **Bounded installed-package grid 2026-10-14 (partial evidence; EDI 1.0.3):**
  because this plan specifies only a “small grid,” the convention used here
  was `n={120,200}`, true `sigma={0.6,0.9}`, and seeds `41001:41010` in each
  cell (40 fits per kernel, 160 total). The kernels were `fast_ordinal_clmm_cpp`
  and `fast_ordinal_glmm_cpp` (both compared with `ordinal::clmm(nAGQ=25)`),
  `fast_logistic_glmm_cpp`, and `fast_poisson_glmm_cpp` (the latter two compared
  with `glmer`; native objective evaluations used 40-node quadrature). A
  material worse-fit threshold of `1e-3` NLL units was used to avoid treating
  floating-point noise as a failure. Ordinal CLMM had 5/40 boundary fits and
  ordinal GLMM 5/40; none was worse than its reference by more than the
  threshold. Logistic GLMM had 3/40 boundary fits, each paired with a
  singular/zero-sigma `glmer` reference (so its zero-sigma likelihood gap is
  not finite); the fit gradient norms were 0.00062–0.00121. Poisson GLMM had
  no boundary fits, but two converged, non-boundary cold-start fits at
  `n=200, sigma=0.9` were materially worse than a glmer-informed native start:
  seed 41003, gap 0.12833 NLL (fit sigma 0.92225 vs reference sigma 0.84160),
  and seed 41008, gap 1.01325 (fit sigma 1.04495 vs 0.80532). Both cold fits
  reported `converged=TRUE`, no iteration-cap hit, and gradient norms below
  `8e-7`; the lower-NLL reference-informed fits also reported convergence but
  larger gradient norms (0.0475 and 0.0313), so the gradient diagnostic needs
  cautious interpretation. Repeating both cases with LBFGS cold starts
  reproduced the worse local optima. Source inspection shows the Poisson
  kernel's deterministic multistart varies `log_sigma` while retaining its
  single smart-cold beta initialization; this points to a remaining
  coefficient-start/local-optimum robustness gap, not a nonstationary
  boundary stop. The bounded grid therefore does not close TODO-1: the two
  Poisson cases need a validated start/reference policy, and the plan's
  boundary/gradient classification must be reconciled with this non-boundary
  finding. Temporary results are under `/tmp/edi_todo31_sigma_n_grid.csv`,
  `/tmp/edi_todo31_ordinal_glmm_grid.csv`, and
  `/tmp/edi_todo31_poisson_outlier_diagnostics.csv`; no repository baseline was
  changed and no build/install was run.
  **Candidate-beta probe 2026-10-14 (proposal only):** on the installed EDI
  1.0.3 wrapper, using the fixed-effects Poisson GLM coefficients as
  `warm_start_params` (with `smart_cold_start=FALSE`; the kernel still applied
  its current log-sigma starts) reached the lower basin for both fixtures
  under LBFGS: seed 41003 NLL 312.748983 and seed 41008 NLL 379.147299, versus
  cold LBFGS 312.877334 and 380.160551. The same candidate under Newton was
  less consistent: seed 41003 stopped at NLL 312.754654 with gradient norm
  1.73, while seed 41008 reached 379.147298 with gradient norm 0.0125. A
  plausible narrow source option is to retain the existing smart-cold beta
  start and add a fixed-effects Poisson-GLM beta start only when there is no
  caller-supplied warm start, then retain the best finite fit. Before adopting
  it, decide whether the GLM start is intended for both optimizer modes and
  whether the extra beta-by-log-sigma starts (and their runtime cost) are
  acceptable; a single beta seed did not resolve the Newton 41003 diagnostic.
  Regression location: `R/package_tests/testthat_bulk/test-poisson-glmm-fit-
  quadrature-convergence-and-glmer-agreement-reference.R`, adding seeds 41003
  and 41008 and checking 40-node marginal NLL against the glmer-informed
  reference. No source change or rebuild was made; this option is not yet
  validated across unaffected fits.
  **Focused logistic cold-start recheck 2026-10-16 (installed EDI 1.0.3; no
  build/install):** the existing `test-logistic-glmm-fit-glmer-agreement-and-
  cold-start-variance-collapse-reference.R` passed all 13 assertions. Its
  seed-4 default cold-start fit had `log_sigma = -0.1748084` versus the
  25-node `glmer` reference `-0.1747772`, 40-node NLL gap `1.33e-8`, reported
  gradient norm `7.61e-4`, and maximum absolute score component `6.99e-4`;
  `converged = TRUE`. This is a reproducible non-boundary post-fix agreement
  fixture, not a reproduction of the old collapsed basin or a replacement for
  TODO-1's multi-seed rate characterization.
  **Historical/source discriminator 2026-10-16:** commit `e706c6f6`
  (`more bug fixes in v1.0.5`, 2026-10-09) changed the logistic GLMM cold
  path from one L-BFGS optimization at the `smart_cold_start` beta vector
  with `log_sigma = -3` to deterministic starts retaining that supplied
  start and adding log-sigma values `-1`, `0`, `1`, and
  `-kLogSigmaPenaltyCenter`; it selects the finite fit with minimum objective.
  The pre-fix version of the existing seed-4 test is an exact discriminator:
  at `G = 40`, `m = 5`, true sigma `0.9`, it asserted `log_sigma < -2.5`,
  NLL gap `> 1` against the `glmer` parameters, and a non-finite or
  non-positive covariance diagonal. The post-fix test now asserts the opposite
  ML-basin agreement, and the installed post-fix seed-4 check above passes.
  This deterministic fixture is suitable for comparing old and new binaries,
  but no pre-fix binary was available to execute and no checkout-native build
  was run; historical behavior is supported by the old pinned test and source
  diff, not independently re-executed here.
  **Count-family variance discriminator 2026-10-16 (TODO-50 follow-up; installed
  EDI 1.0.3, no build/install):** reran the exact Poisson GLMM outlier fixtures
  (`n=200`, five observations/group, true `sigma=0.9`, seeds 41003 and 41008)
  with 40-node quadrature, comparing cold Newton/LBFGS starts with `glmer`-
  informed and fixed-effects Poisson-GLM beta starts. The cold fits reproduced
  the worse basins: seed 41003 NLL 312.877334 (`sigma=0.92225`) versus
  312.749005 at the `glmer` start; seed 41008 NLL 380.160550
  (`sigma=1.04495`) versus 379.147299. The NLL gaps are 0.128329 and 1.013251;
  cold Newton and LBFGS agree to displayed precision on both seeds. The
  `glmer`-informed fits were marked converged despite score norms 0.0475 and
  0.0313, while cold Newton was also marked converged (norms below `8e-7` for
  these two rows); thus a successful convergence flag or a small gradient
  alone does not distinguish the preferred basin in these fixtures. GLM beta
  starts reached the lower basin under LBFGS for both seeds, but Newton seed
  41003 stopped at NLL 312.754654 with score norm 1.731, so that candidate is
  not yet a validated optimizer-independent fix. This controlled installed
  comparison isolates a repeatable Poisson-GLMM cold-start/local-optimum
  failure mode; it does not establish a rate over the count family or reconcile
  comprehensive operating-characteristic CSVs. Harness and raw rows are in
  `/tmp/edi-todo50-count-variance-20261016/installed_check.R` and
  `/tmp/edi-todo50-count-variance-20261016/installed_check.csv`; command:
  `Rscript -e 'source("/tmp/edi-todo50-count-variance-20261016/installed_check.R")'`.
  The harness checked EDI version and loaded-library mtime before and after the
  run; both remained EDI 1.0.3 with `EDI.so` mtime `2026-10-16 01:54:58 +0300`.
  **Remediation assessment (TODO-50, source-level only; 2026-10-16):** the
  Poisson kernel already uses the same basic `log_sigma` multistart strategy
  as the post-fix logistic kernel: retain the supplied/cold start and try
  `log_sigma` values `-1`, `0`, `1`, and `-5`, optimizing each from the same
  beta vector and selecting the finite fit with the lowest objective. Since
  the two Poisson failures persist under both Newton and LBFGS despite that
  grid, simply copying the binomial remedy would not address the observed
  mechanism. The concrete remaining candidate is a second, data-derived beta
  seed for *automatic smart cold starts*: obtain fixed-effect Poisson GLM beta
  estimates (honoring row weights where present), cross that seed with the
  existing sigma grid, and retain the current transformed-OLS beta seed as a
  candidate. Keep an explicit caller-provided `warm_start_params` as the
  existing primary seed, and do not add generated beta starts when
  `smart_cold_start = FALSE`; if the GLM solve is rank-deficient or non-finite,
  skip only that candidate and preserve today's finite fallback behavior.
  The 2026-10-14/16 beta-start probe motivates but does not validate this
  candidate: LBFGS reached the lower basin on both outliers, while Newton seed
  41003 returned score norm 1.73. Before source work, the owner should decide
  whether the generated beta seed is intended for both optimizer modes and
  accept or reject the up-to-2x multistart cost.

  **Proposed validation gate:** add the two exact regression fixtures above
  (seeds 41003 and 41008; `n=200`, 40 groups of five, true `sigma=0.9`) to the
  existing Poisson GLMM quadrature/glmer agreement test. For both `newton` and
  `lbfgs`, require the selected 40-node marginal NLL to be no worse than the
  `glmer`-informed reference within a documented quadrature tolerance, finite
  parameters/covariance, and truthful optimizer diagnostics; assert that a
  caller-provided start and fixed-parameter constraints retain their contract.
  Also run unaffected seeds 41001:41010 and the existing small Poisson GLMM
  reference fixture to check for regressions, including weighted/rank-deficient
  inputs, and report per-fit runtime for cold starts versus the present path.
  No source change, native rebuild, or canonical CSV regeneration has been
  made; this is a candidate/design gate, not closure evidence.
  **Internal-only fixed-seed comparison 2026-10-16 (installed EDI 1.0.3):**
  the namespace's unexported `fast_poisson_glmm_cpp` wrapper accepts
  `warm_start_params`, so it permits a direct controlled call without a
  checkout build; the public exports do not include this wrapper. On three
  fixed generator seeds (`41001`, `41003`, `41008`; each `n=200`, 40 groups of
  five, true sigma 0.9), each algorithm compared the installed cold smart
  start against fixed-effects Poisson-GLM beta plus `log_sigma=-3` and the
  `glmer(nAGQ=25)` parameter start. For seed 41001, all three starts reached
  NLL 359.83376 under both algorithms. For seed 41003, the cold NLL was
  312.877334 under both algorithms; the GLM start gave 312.754654 under
  Newton (score norm 1.731) and 312.748983 under LBFGS, versus the glmer-start
  NLLs 312.749005 and 312.748983. For seed 41008, cold NLL was 380.160550 /
  380.160551 (Newton/LBFGS); GLM starts reached 379.147299 under both, versus
  glmer starts 379.147299 / 379.149076. Thus this tiny internal-only sample
  reproduces two material cold-start failures and shows the GLM start recovers
  the lower basin's NLL to within 0.0057 on the problematic Newton seed and to
  displayed precision on the other three algorithm/seed pairs. It does not
  validate convergence diagnostics (Newton seed 41003's score remains large),
  establish an incidence rate, or replace public-API/test-seam coverage. The
  18 fit rows and timings are in
  `/tmp/edi-todo50-multiseed-20261016/internal_comparison.csv`, generated by
  `/tmp/edi-todo50-multiseed-20261016/compare_internal_starts.R`; no package
  version/library-mtime change was observed and no repo CSV was touched.
- [x] **TODO-2: Decide the fix per kernel.** Candidates: a non-boundary
  default start (`log sigma = 0`, which the ordinal test shows recovers the
  ML solution); a short multistart over `{-1, 0, 1}` for the sigma
  coordinate (the multistart plan proposes a `scalar_nuisance_starts()` helper;
  it does not exist yet); refusing to report `converged = TRUE` on a
  non-stationary boundary stop. Align with the multistart plan so this is
  its first, narrow use rather than a competing mechanism.
- [x] **TODO-3: Hessian log-sigma block.** Determine whether
  `get_logistic_glmm_hessian_cpp`'s sigma row/column is wrong or the test's
  expectation is; if wrong, fix, and audit every caller that reads standard
  errors from it.
- [x] **TODO-4: Fix and flip the tests.** The four pinned tests are written
  to assert the *buggy* behavior; convert each to a regression test that
  asserts agreement with `clmm`/`glmer`, and remove the "pinned" wording.
- [x] **TODO-5: Reach.** Sweep the other random-intercept kernels
  (`fast_ordinal_glmm_cpp`, Poisson/negative-binomial GLMM, Gaussian LMM)
  for the same warm-start value, and record the answer here.
- [ ] **TODO-6: Comprehensive-test regeneration** for the affected KK
  classes after the fix, per the standing pruning workflow.

  **Read-only artifact audit 2026-10-16:** TODO-1 and TODO-6 remain open; no
  gate can be closed from the available artifacts alone. The post-fix
  10-seed logistic check is positive fixture evidence, not the required
  four-kernel sigma-by-n rate characterization. The existing grid still has
  two materially worse Poisson cold-start fits (seeds 41003 and 41008). The
  2026-10-21 owner decision below resolves the 1.0.5 policy: retain the shipped
  20-node default and optimizer/start behavior, and use a 20-vs-320 parameter
  non-regression comparison. The broader four-kernel sigma-by-n validation and
  current-source/native and comprehensive-row gates remain open.
  **Policy-neutral acceptance candidate, 2026-10-18:** the existing Poisson
  fit reference test already provides an independent exact marginal-likelihood
  evaluator and a `glmer(nAGQ = 25)` parameter candidate. Extend its fixture
  to seeds 41003 and 41008 (`n = 200`, 40 groups of five, true `sigma = 0.9`)
  and require the cold fit's independently integrated exact NLL to be no worse
  than that candidate's exact NLL plus `1e-4`. This tests a reproducible
  outcome without prescribing a beta-start or optimizer policy; it does not
  certify a global optimum. Add it with the corresponding fix, since the
  current cold-start implementation is known to fail the comparison.
  **Quadrature/metric reconciliation, 2026-10-20:** the later focused test
  now checks both Newton and L-BFGS for seeds 41003/41008 after fitting with
  320-point Gauss-Hermite quadrature, and compares the independent exact
  marginal NLL to the exact NLL at the `glmer(nAGQ=25)` parameters within
  `1e-4`. This is the same fixture as the older Newton diagnostic, but not the
  same optimizer cell: that diagnostic used 40-point quadrature and compared
  approximate kernel objectives. At seed 41003 the saved 40-node GLM-start
  objective was 312.754654 versus 312.749005 for the glmer start (gap
  0.005649; gradient norm 1.731), not independently integrated exact NLL.
  On the current installed artifact, a cold Newton fit at 40 nodes has exact
  NLL 312.919277 versus 312.828221 at the glmer candidate (gap 0.091056),
  while the 320-node cold Newton exact NLL is 312.828221 (gap below `1e-9`).
  Therefore the high-quadrature exact-NLL regression does not erase the
  separate 40-node optimizer diagnostic. The owner decision below uses the
  20-vs-320 parameter comparison for 1.0.5; it does not make the 40-node
  diagnostic an acceptance cell. Installed EDI 1.0.3 DLL SHA-256
  `dd9dd9a4c3c13619c473b29c6e90fd4b44d75903e25e6fa5ab78c91457c18716`
  matches checkout `R/EDI/src/EDI.so` byte-for-byte at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, but this is not source/build
  provenance. **Fixed-coordinate contract regression, 2026-10-20:** the same
  focused file now also supplies a caller warm start while fixing the
  log-sigma coordinate, then checks that the returned coordinate is exactly
  the fixed value and that the reported objective matches the independent
  exact integral within `1e-6`. The 24-assertion file passed (0 failures,
  warnings, or skips) against installed EDI 1.0.3, with no build/install.
  This covers the existing fixed-parameter contract only; it neither changes
  nor selects an optimizer/start policy, and does not settle the known
  production-quadrature 40-node Newton diagnostic. The installed-artifact
  result is not current-source/native provenance. TODO-1's broader four-kernel
  grid and TODO-6's canonical-row regeneration/audit remain open.
  **Fresh installed-native exact-NLL regression rerun, 2026-10-20:**
  `testthat::test_file("R/package_tests/testthat_bulk/test-poisson-glmm-fit-quadrature-convergence-and-glmer-agreement-reference.R", package = "EDI")`
  passed all 29 expectations (0 failures, warnings, or skips) against installed
  EDI 1.0.3. This exercises both optimizers on the two predeclared 320-node
  cold-start fixtures (seeds 41003/41008), the fixed-coordinate contract, and
  independent exact-NLL comparisons; it does not test the separate 40-node
  diagnostic. Installed `EDI.so`
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI/libs/EDI.so` has
  SHA-256 `db4b05da3ee1ad1a19f8f023e6036fe88d0fb45b8e0ef9d6be98908eea520041`,
  byte-identical to checkout `R/EDI/src/EDI.so` at HEAD
  `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This is focused installed-native
  evidence, not full source/build provenance or validation of the broader
  four-kernel grid. That grid and TODO-6 canonical-row regeneration/audit
  remain open.
  **Installed-package exact-NLL regression recheck, 2026-10-21:** reran the
  same focused file via `timeout 180s Rscript -e` with `library(EDI)` and
  `testthat::test_file(..., reporter = "summary")`; all 29 expectations passed
  (0 failures, warnings, or skips). Runtime package was EDI 1.0.3 from
  `/home/kapelner/R/x86_64-pc-linux-gnu-library/4.7/EDI`; loaded `EDI.so`
  MD5 `bfea6f47ab8b27618d5d8633e9021f91`, SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`,
  mtime `2026-10-21 09:43:34 +0300`; test-file SHA-256
  `40111009586499512e27258409339c8e25f5ecbcb01889c0918432678606eef2`;
  checkout HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This is a newer,
  distinct installed-artifact recheck, not proof that installed R definitions
  or the binary were built from current checkout. The 20-vs-320 parameter
  bound, four-kernel grid, current-source/native provenance, and comprehensive-
  row reconciliation remain open.
  **40-node criterion-scope check, 2026-10-20:** a minimal source-overlay
  reproducer (`pkgload::load_all("R/EDI", compile = FALSE)`) at seed 41003,
  `n=200`, 40 groups of five, `n_gh=40`, Newton requested, gives
  `converged=TRUE` after two iterations but gradient norm `1.73142`. The
  reported NLL `312.7547` agrees with a separately coded R 40-node
  Gauss-Hermite evaluation; that approximation is `0.2912` lower at the fit
  than at the `glmer(nAGQ=25)` parameters (`313.0458`). Independent exact
  integration reverses the ordering: `312.9193` at the fit versus `312.8282`
  at `glmer`, gap `+0.09106`. This exceeds both the grid's `1e-3` materiality
  marker and the `1e-4` exact-NLL allowance if applied, but neither is an
  approved criterion for this cell: `1e-3` was used for the boundary-stop
  grid classification, while `1e-4` is the optimizer-correctness gate at 320
  nodes. The 40-node fit is non-boundary, and the shipped wrapper default is
  20 nodes. The 2026-10-21 owner decision sets the 1.0.5 acceptance to
  20-vs-320 parameter agreement: each coefficient differs by at most `0.75`
  standard errors and log sigma by at most `0.10`; the 40-node result is
  diagnostic, not a separate acceptance cell. Validate that bound with
  current-source/native provenance as part of the remaining native gate; do
  not change shared optimizer/convergence policy for 1.0.5. The current test indicates
  the shared Newton-to-L-BFGS fallback can report convergence on an
  iteration-under-cap/function-decrease stop despite the large gradient, so
  that behavior is diagnostic evidence, not an authorized fix.
  **Installed-package 20-vs-320 bound recheck, 2026-10-21:**
  `timeout 180s Rscript -e` with `library(EDI)` ran
  `test-poisson-glmm-20-node-vs-320-node-bound.R`; all 20 expectations passed
  in 5.4 seconds (10 fixed seeds, checking coefficient differences in SE and
  log-sigma differences). Installed EDI 1.0.3 DLL SHA-256
  `0e5130770d0a74d86c26ba220c64561dffb71003510b678522ca860b7f37efc0`
  (MD5 `bfea6f47ab8b27618d5d8633e9021f91`, mtime
  `2026-10-21 09:43:34 +0300`) was byte-identical to ignored checkout
  `R/EDI/src/EDI.so`; test-file SHA-256
  `96cf46c3b67ed6a219aeaaff4a871062b48f09f102452447543db1cd8be32509`,
  HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. This is installed-artifact
  acceptance evidence, not source/build provenance; identical bytes do not
  establish how the DLL was built. The broader four-kernel grid,
  current-source/native provenance, and comprehensive-row reconciliation
  remain open. No build/install or canonical output occurred.
  **Read-only four-kernel artifact/source identity audit, 2026-10-21:** the
  20-vs-320 bound test evidence above was initially limited to the ten Poisson
  GLMM seeds. The earlier 160-fit four-kernel
  sigma-by-n grid was run against installed EDI 1.0.3 and has no retained
  current-source build receipt. No provenance-stamped broad-grid output was
  found in the bounded `/tmp` search. The four current source files are clean
  at HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`, with SHA-256:
  `fast_ordinal_clmm.cpp` `8f4be0f55e6ad7e8991e10cb9c28336b747d234f627371d1f8e7722b35abdf36`,
  `fast_ordinal_glmm.cpp` `b334c9bfaeab15fed070770ea5a61c19f1fa3a5004e9dfb406099c83b1ad98d3`,
  `fast_logistic_glmm.cpp` `a0ad6f1102bb504af9d60b834274a6c743f18696cb7ea29b1d73b3d767562920`,
  and `fast_poisson_glmm.cpp` `4631fa72397500f4cbd56442e6216d7512c876173b94f0c46e1172bdbd955191`.
  Current ignored checkout and installed `EDI.so` are byte-identical at SHA-256
  `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`
  (14,727,184 bytes; 2026-10-21 14:12 +0300), but no build manifest ties
  those bytes to the four source hashes. This differs from the `0e513077…`
  DLL recorded for the earlier Poisson bound recheck, so that test does not
  establish behavior of the currently installed artifact. Keep the current-
  source/native four-kernel bound/grid and comprehensive-row gates open.
  **Ordinal CLMM representative-bound fixture, 2026-10-21:** broadened the
  existing seeded ordinal CLMM reference test with a single `n=200`, 40-group,
  five-observations/group fixture (seed 301). It compares 20- and 320-node
  fits under the approved slope bound (difference divided by the 320-node
  treatment-coefficient SE <= 0.75) and log-sigma bound (<= 0.10), and checks
  the 320-node fit against the existing independent `ordinal::clmm(nAGQ=25)`
  reference. The focused file passed 38 expectations against installed EDI
  1.0.3; installed DLL SHA-256 is `f7cf39dec10be2caaf84f8813d38e2b0d1d8be1b9a070b0f30bd42f62d9006c7`,
  identical to ignored checkout `EDI.so` but without a build/source receipt.
  This is diagnostic installed-artifact evidence for one ordinal CLMM fixture,
  not current-source/native acceptance or the four-kernel sigma-by-n grid.
  Ordinal GLMM, logistic GLMM, the broader grid, and comprehensive-row gates
  remain open; no build/install or canonical output occurred.
  For TODO-6, the canonical count file
  `R/package_tests/comprehensive_tests_results_nc_1_count.csv` has 14,206
  `InferenceCountKKGLMM` text matches and mtime 2026-09-27; the canonical
  ordinal file `R/package_tests/comprehensive_tests_results_nc_1_ordinal.csv`
  has 69,121 `InferenceOrdinalKKCLMM` matches and mtime 2026-10-09. These
  timestamps/counts do not establish which rows were recomputed with the
  post-fix installed binary. The TODO-56 resume copy has the same observed
  match counts and must not be treated as independent completion evidence
  while that run is active. After TODO-56 releases the shared result files,
  the remaining evidence is a provenance-stamped post-fix regeneration of
  the affected CountKKGLMM and OrdinalKKCLMM rows using the standing stale-row
  pruning workflow, followed by the comprehensive audit/reconciliation; do
  not update the canonical baseline until that audit passes.

  **Read-only canonical-row provenance snapshot 2026-10-18:** direct reads of
  the two canonical CSVs found 14,206 `InferenceCountKKGLMM` rows in the
  count file (14,206 distinct `id`, 307 distinct `case_id`) and 69,121
  `InferenceOrdinalKKCLMM` rows in the ordinal file (69,121 distinct `id`,
  973 distinct `case_id`). Every matching row currently has `status = ok`.
  The recorded timestamp ranges are 2026-08-24 12:38:18 IDT–2026-09-27
  09:32:10 IDT (count) and 2026-08-24 12:30:58 IDT–2026-10-09 01:12:24 IDT
  (ordinal). Each class has 22 distinct `github_commit_id` values; the exact
  inventories are:

  ```text
  CountKKGLMM: 09b5905b413f70009104e6e0e19d0c7cf782fe90, 108db0377224cb71995a1bb2823d3e1152399f5f, 13e1eb113be3090456738eed75076f33fa4c2d4b, 36368a0e00f9feb5cafb316ed2e161e8fbfac659, 57dab4428119b05e724c5de9f9a1749d65f5e691, 5d8246300ea034bed7f4591d7f2258a7215436eb, 7241fc7b151c53c525e14039d0b9c02ef7435d16, 842da415c7e17697a118fb2e3dd50908c17ae8ba, 8918bada0547a6bfb5454b8623c69e8d50ccc6b5, 894668404512bb2de2472dae149823756c29d7fd, 8a03e5ddb976ce194f87dbc66f0b772af6fc3577, 903ced0404921b7f4a6b5a8b1f7d0a6702466a31, a18354bce4b10d7007601ef3a53c5f217d6c9154, a31ecc5e6fdae4e08c659caa479d6c877d80a551, a5878d83900ea7d647cfcc355f72d8be04fc5588, b6ec06b5e985414d05380c6926f4807452d9cb24, baec9f3d7282250d31343f9bc3ef0cfd66ca0d54, c4dbf91fb33eab1532a276da7e9576f5d54e4249, c8d4786e8d56f9e53b4f9a5a38a263f2fdd4f903, d41880c19a6c8a32a9515b1c19331d73e74f0b3e, ec003b7eeefab2e40b64b6412f4fc127dee4efac, f1e3bb2bbba0d37ea194724d4e859e32b488327b
  OrdinalKKCLMM: 13e1eb113be3090456738eed75076f33fa4c2d4b, 36368a0e00f9feb5cafb316ed2e161e8fbfac659, 363fbedee6b6d2a68f56eb3083dd190f73bd1ec4, 4d0040ab144c339b4096037164db0d8dea0629c8, 57dab4428119b05e724c5de9f9a1749d65f5e691, 5d8246300ea034bed7f4591d7f2258a7215436eb, 641eea900c1777e13d0ca81a86eeec8439444bab, 7241fc7b151c53c525e14039d0b9c02ef7435d16, 842da415c7e17697a118fb2e3dd50908c17ae8ba, 8918bada0547a6bfb5454b8623c69e8d50ccc6b5, 8a03e5ddb976ce194f87dbc66f0b772af6fc3577, 903ced0404921b7f4a6b5a8b1f7d0a6702466a31, 95e5203765fde92b5d501c0e93139603c2a95bf1, a18354bce4b10d7007601ef3a53c5f217d6c9154, a5878d83900ea7d647cfcc355f72d8be04fc5588, b6ec06b5e985414d05380c6926f4807452d9cb24, baec9f3d7282250d31343f9bc3ef0cfd66ca0d54, c4dbf91fb33eab1532a276da7e9576f5d54e4249, c8d4786e8d56f9e53b4f9a5a38a263f2fdd4f903, cd3a703471577eb391d899306356ed8d01e09561, d41880c19a6c8a32a9515b1c19331d73e74f0b3e, d948f6e9fb20ce6a500ef25fb00f77bce3c9a4c5
  ```

  `id` is the row-level key and includes replicate and `beta_T`; `case_id`
  identifies a broader case and omits those dimensions, so it is not a
  row-unique reconciliation key. A read-only ancestry check against the
  sigma-start fix commit `e706c6f67a6798eea666921155c259a751476feb` found
  zero matching rows whose recorded `github_commit_id` descends from it.
  These CSV columns stamp the source-tree HEAD (`github_commit_id`), not the
  loaded native-library build; even a descendant HEAD would not prove which
  `EDI.so` was loaded. Record the exact source revision and native artifact
  identity at regeneration. This snapshot is not post-fix native evidence;
  keep TODO-1's broader grid validation and TODO-6 regeneration/audit open.

  **Post-fix CI provenance check 2026-10-16:** GitHub Actions run
  `38808821543` (`test-bulk-non-cran`) completed successfully at commit
  `430c19bcdb0702d998c79f9058c449449034134c`, which descends from the sigma-
  start fix commit `e706c6f67a6798eea666921155c259a751476feb`. Its successful
  build and five correctness shards used the current-commit native package;
  the run's `correctness-shard-plan` schedules these five regression files:
  `test-ordinal-clmm-kernel-ordinal-package-agreement-and-sigma-collapse-from-minus-three-start-reference.R`,
  `test-logistic-glmm-fit-glmer-agreement-and-cold-start-variance-collapse-reference.R`,
  `test-count-kk-classes-match-joint-optimum-geeglm-and-glmer-and-newton-sigma-collapse-reference.R`,
  `test-ordinal-kk-glmm-class-matches-clmm-and-kk-clmm-class-collapses-to-fixed-effects-reference.R`,
  and `test-poisson-glmm-fit-quadrature-convergence-and-glmer-agreement-reference.R`.
  This is post-fix native fixture-regression evidence, but does not complete
  TODO-1's broader four-kernel sigma-by-n rate characterization or resolve
  the two Poisson outlier/start-policy question above. The run artifacts are
  the build and correctness-shard plan/results, not comprehensive result
  CSVs, so they do not satisfy TODO-6's canonical row reconciliation. The
  current working tree also has an uncommitted `require_square_matrix()` guard
  in `R/EDI/src/fast_ordinal_clmm.cpp`; that additional guard is outside the
  CI commit and is not validated by this run. Keep TODO-1 and TODO-6 open.

  **TODO-76 dependency path check 2026-10-16:** the weighted ordinal Bayesian-
  bootstrap refit is implemented through
  `weighted_ordinal_random_intercept_fit()` in `R/EDI/R/helper_ordinal_mixed_fit.R`;
  that helper calls `ordinal::clmm()` (and uses `ordinal::clm()` plus candidate
  starts only after the initial CLMM fit errors). It does not call the native
  `fast_ordinal_clmm_cpp()` fitter whose sigma-start behavior is changed here.
  Thus TODO-76's focused weighted-refit tests establish the helper's separate
  behavior, not TODO-31 native-kernel validation. The release cross-link still
  matters for the CLMM's reported point-estimate/BB comparison: its comprehensive
  rows must be regenerated and reconciled only after TODO-31's native gate is
  resolved. This path check does not waive either TODO-31's TODO-1/TODO-6 gates
  or TODO-76's result-regeneration gate; no test, build, install, or CSV run was
  performed for this note.

  **Post-policy regeneration sequence, 2026-10-20 (planning only):** after
  TODO-31's owner-approved 20-vs-320 acceptance bound is validated on the
  broader four-kernel grid and present in a user-rebuilt/reinstalled EDI,
  reuse—not recreate—the source-strata inventory
  `/tmp/edi-todo50-source-strata.8DTD1J/todo50_expected_current_source_strata.csv`
  (SHA-256 `5d0760ec7b2e750fe096c28bd67b5a38d309a67aaa856c3d5fc15974fab662bb`).
  It has 29,440 rows: 6,400 `InferenceCountKKGLMM`/count strata and 5,760
  strata for each of `InferenceOrdinalKKCLMM`, `InferenceOrdinalKKCLMMCauchit`,
  `InferenceOrdinalKKCLMMCloglog`, and `InferenceOrdinalKKCLMMProbit`.
  Use the comprehensive harness's response/class filters to regenerate only
  these five classes into a fresh `/tmp` directory via
  `EDI_COMPREHENSIVE_RESULTS_DIR`; do not point the run at canonical result
  files. Retain each output's comprehensive-run provenance sidecar: its
  before/after records bind checkout HEAD and diff, runner/helper hashes, EDI
  version/path, loaded DLL path/SHA-256, arguments, and output identity.
  Expand the source strata through the harness's attempted-function
  eligibility rather than treating each stratum as one result row. Reconcile
  complete expected row keys (including `function_run`, replicate, and
  `beta_T`; use row `id`, not `case_id`, as the unique row key), duplicates,
  missing/extra keys, and statuses against scratch candidates; then run the
  existing comprehensive audit before any separately authorized canonical
  merge. This temporary inventory is not runtime-success evidence or
  permission to update canonical results. No rows, fits, or canonical files
  were generated or changed for this sequence. TODO-31's optimizer/native
  gate and TODO-6's post-fix reconciliation remain open.

  **Source-only attempted-key audit, 2026-10-20:** the existing source-strata
  CSV is internally unique (29,440 rows, zero duplicate rows), but is not an
  exact result-key manifest: its columns stop at class/response/dataset/
  design/`beta_T`/replicate/design formula/class formula and contain no
  `function_run`. The only existing source helper that expands attempted
  functions from eligibility fields,
  `comprehensive_rand_ci_attempt_manifest()`, covers the randomization-CI
  branch only, not the complete set emitted by the comprehensive runner.
  For the full matrix, `comprehensive_tests.R` first reads each dataset's
  `X` and response vector, constructs the design, realizes assignments
  (`add_one_subject_to_experiment_and_assign()` or
  `assign_w_to_all_subjects()`), applies treatment effect/noise, and adds
  outcomes before constructing each inference object. The subsequent
  `run_inference_checks_impl()` derives attempted labels from that live
  object's private `supports_*` methods, design capabilities, formula-aware
  slow-path flags, and testing-type support. Therefore the full exact
  `function_run` inventory cannot be recovered from the 29,440 strata and
  static eligibility files alone under the no-assignment/no-outcome
  constraint; a source-only cross-product would be only a candidate superset,
  not proof of attempted keys. No candidate function-key manifest was
  written. Exact expansion must be emitted by the actual post-policy harness
  run (or by a future runner mode sharing its live gate decisions), then
  reconciled with the run's provenance sidecar and outputs.

  **Read-only retained-count CI denominator reconciliation 2026-10-21:**
  checked the retained `comprehensive_tests_results_nc_1_count.csv` rows for
  the zero-inflated negative-binomial class against the current and prior
  audit aggregates in `/tmp/edi-todo9-audit.NnBBLg/`. The current source
  `audit_one()` denominator is every `status == "ok"` CI attempt with finite
  `coverage_truth`; a non-finite interval is retained as uncovered. The
  aggregate snapshots instead use the finite-bound counts shown below. Each
  retained row set below had finite truth on every status-ok attempt:

  | formula | `function_run` | retained attempts | finite bounds / covered | retained rate under current source rule | current aggregate | prior aggregate |
  |---|---|---:|---:|---:|---:|---:|
  | `~.` | `compute_gradient_confidence_interval` | 381 | 118 / 104 | 104/381 = 0.273 | 0.881 / 118 | absent |
  | `~.` | `compute_lik_ratio_confidence_interval` | 381 | 118 / 98 | 98/381 = 0.257 | 0.831 / 118 | 0.851 / 87 |
  | `~.` | `compute_score_confidence_interval` | 381 | 118 / 102 | 102/381 = 0.268 | 0.864 / 118 | 0.885 / 87 |
  | `~.` | `compute_wald_confidence_interval` | 381 | 74 / 64 | 64/381 = 0.168 | 0.865 / 74 | 0.877 / 73 |
  | `~1` | `compute_bayesian_bootstrap_confidence_interval_basic` | 348 | 319 / 291 | 291/348 = 0.836 | 0.912 / 319 | 0.907 / 237 |
  | `~1` | `compute_bootstrap_confidence_interval_basic` | 304 | 262 / 239 | 239/304 = 0.786 | 0.912 / 262 | 0.906 / 180 |
  | `~1` | `compute_bootstrap_confidence_interval_studentized` | 304 | 230 / 210 | 210/304 = 0.691 | 0.913 / 230 | 0.906 / 170 |
  | `~1` | `compute_lik_ratio_confidence_interval` | 381 | 349 / 303 | 303/381 = 0.795 | 0.868 / 349 | 0.908 / 250 |

  Thus the saved aggregate denominators do not reconcile with the current
  source rule for these retained rows; the distinction is not evidence about
  Poisson GLMM fit quality or a resolution of TODO-31's start/optimizer
  policy. The retained CSV records source `github_commit_id` but not the EDI
  package version or loaded DLL path/hash, and prior raw attempts are not
  retained separately. These historical results therefore do not establish
  current-runtime provenance. Keep TODO-31's current-source/native validation
  and TODO-50's regeneration/reconciliation gates open.

  **Read-only retained-count CI denominator reconciliation, continued
  2026-10-21:** the next two ZeroInflatedPoisson `~.` rows in the same
  retained count file and aggregate snapshots have the same denominator
  conflict. Counts below use status-ok attempts with finite truth; the current
  source rule includes attempts with missing interval bounds as uncovered.

  | formula | `function_run` | retained attempts | finite bounds / covered | retained rate under current source rule | current aggregate | prior aggregate |
  |---|---|---:|---:|---:|---:|---:|
  | `~.` | `compute_asymp_confidence_interval` | 379 | 125 / 108 | 108/379 = 0.285 | 0.864 / 125 | 0.854 / 103 |
  | `~.` | `compute_gradient_confidence_interval` | 381 | 146 / 126 | 126/381 = 0.331 | 0.863 / 146 | 0.853 / 109 |
  | `~.` | `compute_lik_ratio_confidence_interval` | 381 | 146 / 126 | 126/381 = 0.331 | 0.863 / 146 | 0.853 / 109 |
  | `~.` | `compute_score_confidence_interval` | 381 | 146 / 126 | 126/381 = 0.331 | 0.863 / 146 | 0.853 / 109 |
  | `~.` | `compute_wald_confidence_interval` | 381 | 125 / 108 | 108/381 = 0.285 | 0.864 / 125 | 0.854 / 103 |
  | `~1` | `compute_asymp_confidence_interval` | 381 | 351 / 327 | 327/381 = 0.858 | no low-coverage finding | no low-coverage finding |
  | `~1` | `compute_gradient_confidence_interval` | 381 | 351 / 316 | 316/381 = 0.829 | 0.900 / 351 | 0.900 / 260 |
  | `~1` | `compute_lik_ratio_bartlett_approx_confidence_interval` | 381 | 349 / 293 | 293/381 = 0.770 | 0.840 / 349 | 0.837 / 258 |
  | `~1` | `compute_lik_ratio_bartlett_confidence_interval` | 381 | 350 / 293 | 293/381 = 0.770 | 0.837 / 350 | 0.834 / 259 |
  | `~1` | `compute_lik_ratio_confidence_interval` | 381 | 351 / 311 | 311/381 = 0.816 | 0.886 / 351 | 0.896 / 260 |
  | `~1` | `compute_rand_bootstrap_confidence_interval` | 195 | 172 / 170 | 170/195 = 0.872 | 0.988 / 172 (reported OVER) | 0.988 / 172 (reported OVER) |
  | `~1` | `compute_rand_bootstrap_confidence_interval_smoothed` | 195 | 178 / 153 | 153/195 = 0.785 | 0.860 / 178 | 0.860 / 178 |
  | `~1` | `compute_score_confidence_interval` | 381 | 351 / 315 | 315/381 = 0.827 | 0.897 / 351 | 0.896 / 260 |

  The missing-bound rows have `numeric_instability` skip reasons. The ZIP
  `~1` asymptotic row has 30 such attempts; absence from the saved low-coverage
  findings is not a pass, and no fresh aggregate was generated under the
  current denominator rule. In particular, the randomization-bootstrap row's
  saved finite-bound aggregate reports OVER (0.988), while the current-source
  all-attempt retained rate is 0.872; this denominator-driven reversal is not
  a re-run of the coverage audit or a pass/fail determination. Historical
  attempts are not separately retained for replay, and the CSV's source
  commit ID does not bind an EDI package version or loaded DLL path/hash.
  These rows do not establish current-runtime behavior and do not change the
  open TODO-31 native/grid-validation or TODO-50 regeneration/reconciliation
  gates.

  **TODO-50 retained-artifact disposition, 2026-10-21:** the targeted rows in
  the canonical count and ordinal CSVs total 83,327 (14,206 and 69,121); all
  have status `ok` and unique `id`/`run_row_id`, but every recorded source
  commit predates sigma-start fix `e706c6f67a6798eea666921155c259a751476feb`
  and current HEAD `4f7a6e4ca82829e880c15a76699701a95e5e83b9`. The count file
  is 329,319,605 bytes, mtime 2026-09-27 11:17:02 +0300, SHA-256
  `684e7fa07ea616d0743c226bae4a5300360ad7906d6d166872e4399ec144fba3`; the
  ordinal file is 417,165,307 bytes, mtime 2026-10-09 01:12:24 +0300, SHA-256
  `5da4c24e4e078bb47c18f8d8a5f78775c511d46c05e11bed40e0fe67c74111ce`.
  Neither records loaded-DLL identity. The only retained candidate inventory,
  `/tmp/edi-todo50-source-strata.8DTD1J/todo50_expected_current_source_strata.csv`,
  has 29,440 unique strata (SHA-256
  `5d0760ec7b2e750fe096c28bd67b5a38d309a67aaa856c3d5fc15974fab662bb`, mtime
  2026-10-20 14:56:52 +0300), but no `function_run`/attempt identities. Its
  README has no generator or source hashes and points to
  `comprehensive_tests.R`, which is now dirty, so it is not reproducible
  current-source attestation. No post-fix comprehensive result/sidecar was
  found; CI run `38808821543` at descendant commit `430c19bcdb0702d998c79f9058c449449034134c`
  is build/regression evidence only, not row reconciliation. Therefore exact
  post-fix reconciliation cannot proceed from retained artifacts: regenerate
  the affected rows in an isolated directory with current package/R and DLL
  provenance, then reconcile the complete attempted keys and terminal states.
  No result or canonical file was changed; TODO-50 remains open.

  **TODO-50 artifact recheck, 2026-10-21 (read-only):** the only matching
  `/tmp/edi-todo50-*` directory is still
  `/tmp/edi-todo50-source-strata.8DTD1J/`, containing only its README and
  29,440-row candidate-strata CSV. The CSV and both canonical result-file
  hashes still match the inventory above. Current raw source hashes are
  `comprehensive_tests.R` `72cd9d6b5f7afe58b5113eb7c7f1836a03e0b98cd386c09ef025c0f7b56d1221`
  and `_dataset_load.R`
  `7e3cf603ef384c369c4435dc5ca0b541d9248bbda9e5db7f3c17b2b41628bdda`, but
  the candidate README records neither generator nor source hashes and cannot
  bind its strata to these current bytes. The canonical count/ordinal CSVs
  still have no adjacent run-provenance sidecars. This confirms no retained
  post-fix attempt roster or current-source-complete output beyond the
  candidate strata; all regeneration and exact reconciliation gates above
  remain open. No result or canonical file was changed.

## Cross-links (kept in sync 2026-09-24)

Each of these carries a matching "Fed by"/"Related" note pointing back here:
`../new_feature_plans/multistart_nonconcave_likelihoods.md` (v1.2.0),
`../new_feature_plans/optimizer_diagnostics_report.md` and
`../new_feature_plans/public_diagnostics_api_spec.md` (v1.1.0, boundary vs.
failure classification), `../new_feature_plans/cold_starts.md`, and
`multimodal_log_liks.md` (same v1.0.5 wave, stereotype logit).

## Explicitly out of scope

- The general multistart infrastructure (`multistart_nonconcave_likelihoods.md`).
- The SolverDiagnostics taxonomy (v1.1.0).
