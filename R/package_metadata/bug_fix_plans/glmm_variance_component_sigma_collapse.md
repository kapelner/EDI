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
  two materially worse Poisson cold-start fits (seeds 41003 and 41008), so
  TODO-1 needs either a validated start/reference policy with an optimizer-
  and unaffected-fit regression check, or an explicit decision to split that
  non-boundary local-optimum issue from the original boundary-collapse scope.
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
