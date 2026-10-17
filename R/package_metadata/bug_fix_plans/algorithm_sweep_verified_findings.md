# Fix: Verified Correctness Findings from the 2026-10-09 Algorithm-Catalog Sweep

> **Depends on:** none (each TODO is independent unless noted). Release
> index: `../future_release_plans/release_v1_0_5.md → TODO-70..94`, one release
> TODO per plan TODO below, in the same order (plan TODO-k = release TODO-(69+k)).
> Origin: `../new_feature_plans/algorithm_choice_audit.md → TODO-B4`. Each
> finding was surfaced by the per-kernel catalog sweep, then checked on
> 2026-10-09 by an adversarial verifier subagent (code reading plus small
> execution checks: pure-R ports, or `pkgload::load_all(compile = FALSE)`
> against the existing `src/EDI.so`; nothing compiled). The coordinator
> re-ran F8, F9, F15 and F22 (reproduced exactly) and re-read F1/F1b.
> **Full evidence for each finding** is in
> `../new_feature_plans/algorithm_choice_audit_catalog.md §13`
> (13.1 = F1–F5, 13.2 = F6–F10, 13.3 = F11–F16, 13.4 = F17–F22, 13.5 = F23–F26).
> Line numbers are as of 2026-10-09; locate by symbol.
>
> **Not included:** F5 (refuted: the BRT studentized/smoothed paths are
> seeded), F24 (refuted: √w cluster-sandwich scaling is correct for
> cluster-constant Dirichlet weights), and F18 (cloglog sign convention;
> already tracked and implemented under `release_v1_0_5.md → TODO-16`).
>
> **Build rule:** per top-level `CLAUDE.md`, any `.cpp` change is verified by a
> targeted compile of the touched file(s) plus relink only. Never a full rebuild.

"IVWC" marks a legacy class (exported, never used in public examples). Those
are fixed here because they are still exported and registered.

## Group A — wrong results on default paths of public classes

- [x] TODO-1 (F1 + F1c): **`DesignSeqOneByOneRandomBlockSize` redraws are wrong.**
  The class does not override `draw_ws_raw`, so it uses the generic loop at
  `design_seq_one_by_one_abstract.R:190-204`. That loop iterates a *local* `t`,
  but `assign_wt()` reads `private$Xraw[private$t, ]`
  (`design_seq_one_by_one_random_block_size.R:121-140`), so every redrawn
  position uses the last subject's stratum. The block queue `strata_states` is an
  environment shared by the shallow `duplicate()` clone and never reset, so
  redraws start from the real experiment's leftover block and mutate the
  original design (F1c: calling `draw_ws_according_to_design()` directly
  also overwrites the user's `w`). Measured: redraws are block-balanced 51–76% of the time
  (100% required). `random_block_size_redraw_w_cpp` already handles strata
  correctly and is never called (neither are `spbr_redraw_w_cpp` and
  `shuffle_cpp`). **Fix:** override `draw_ws_raw` like SPBR does: per-row
  strata keys plus `random_block_size_redraw_w_cpp` with fresh queues, and no
  mutation of `private$w`, `private$t` or `strata_states`. **Test:** a
  redraw-balance test (every completed block in every stratum balanced; the
  original design's queue and `w` unchanged after `r` redraws). Replace the
  vacuous `0 <= sum(ws[1:4]) <= 4` check in `test-designs.R`.
  **Default change:** randomization and bootstrap p-values and CIs for this design.

  **Resolved 2026-10-09.** `draw_ws_raw()` now derives realized per-row
  stratum keys and calls `random_block_size_redraw_w_cpp()` independently per
  requested draw, using fresh local queues without mutating `w`, `t`, or the
  live `strata_states` environment. The focused decomposition/state regression
  passes 127 expectations, `test-designs.R` passes 103, and the all-design
  seed suite passes 25 under `pkgload::load_all(..., compile = FALSE)`.

- [x] TODO-2 (F1b): **`sample(private$block_sizes, 1)` R gotcha corrupts real
  assignments** (`design_seq_one_by_one_random_block_size.R:129`).
  `assertIntegerish(block_sizes, min.len = 1)` accepts one value, and
  `sample(4L, 1)` then draws from `1:4`. With `block_sizes = 4` the first four
  subjects were balanced only 70% of the time. The default `c(4,6,8)` is
  unaffected. **Fix:** `private$block_sizes[sample.int(length(private$block_sizes), 1L)]`.
  Grep the package for other `sample(x, 1)` on possibly length-1 vectors.
  **Test:** `block_sizes = 4` gives perfectly balanced consecutive blocks.

  **Resolved 2026-10-09.** Real assignment now samples an index into
  `block_sizes`, avoiding base R's length-one `sample()` special case; an
  exhaustive R-source grep found no second possibly-length-one `sample(x, 1)`
  call. The shared redraw validation is recorded under TODO-1.

- [x] TODO-3 (F8, fixed 2026-10-09): **Ridit misscores an interior level that is absent from the
  reference arm** (`src/fast_ridit_analysis.cpp:76-81`,
  `src/ridit_distr_parallel.cpp:59-61`). It scores ½(R_{k−1}+R_k) instead of the
  reference mass below the level, R_{k−1} + ½p_{k−1}, which breaks the documented
  equivalence with Mann–Whitney. Example: class estimate 0.1717 vs
  Mann–Whitney 0.2247. The class's own weighted R path and the JT class both
  give 0.2247. Default `reference = "control"` path. **Fix:** keep the cumulative
  masses in a vector and score the missing level by mass-below, in both files.
  **Test:** a fixture whose control arm omits an interior level, asserting
  equality with Mann–Whitney. The existing reference test's fixture never omits
  a level.

  **Resolution:** both native scoring implementations now retain the cumulative
  reference mass through each observed category and use that mass for a missing
  interior category. The regression covers direct scores, the analysis kernel,
  and the randomization, bootstrap, and randomization-bootstrap distribution
  kernels against the independent pairwise Mann–Whitney definition. **Installed
  native validation 2026-10-14:** `test-ridit-analysis-and-bootstrap-kernels-
  reference-groups-and-treatment-reference-degeneracy-reference.R` (34
  assertions), `test-ordinal-ridit-weighted-bootstrap-reference.R` (19), and
  `test-ordinal-ridit-unweighted-scores-wald-and-fast-kernels-reference.R`
  (34) all passed against EDI 1.0.3; the parallel distribution-kernel contract
  suite also passed 54 assertions. The installed native regression covers the
  missing-interior-level path, so no Codex rebuild was needed.

- [x] TODO-4 (F9, closed after installed validation 2026-10-14): **Newcombe p-value returns 1 for strong effects, and small p
  are inflated** (`inference_incidence_newcombe_univ.R:~157`). The inversion's
  `uniroot` fails to bracket, and the error branch returns 1: 90/100 vs 10/100
  gives p = 1 where `prop.test` gives 1.1e-29 (likewise 180/200 vs 20/200 and
  250/500 vs 100/500). Also, the default `uniroot` tolerance (~1.2e-4 on α)
  inflates small p up to ~160× (75/100 vs 40/100: 7.0e-5 vs 4.3e-7).
  **Fix:** root-search on log α over [log 1e-300, log(1−ε)] with a tight tol.
  Decide the end-point signs explicitly: outside the CI at the floor α means
  return the floor; inside at α ≈ 1 means return 1. **Tests:**
  `test-incid-newcombe-hybrid-wilson-score-reference.R:84-88` currently pins
  p = 1 and must change. Add a strong-effect and a precision regression.

  **Implementation status (2026-10-09):** the inversion now searches
  `log(alpha)` from `log(1e-300)` to `log(1 - eps)` at `1e-12` tolerance and
  classifies the two unbracketed endpoint cases explicitly (outside at the
  floor returns the floor; inside near one returns 1). Its inversion uses a
  stable R Wilson implementation with `qnorm(alpha / 2, lower.tail = FALSE)`:
  the native CI helper's `1 - alpha / 2` expression rounds to one in the
  necessary tail and would otherwise produce an infinite quantile. The
  reference test now covers 90/100 vs 10/100 and 75/100 vs 40/100 as well as
  the endpoint behavior. **Installed validation 2026-10-14:** the focused
  reference test passed all 18 assertions against EDI 1.0.3. No build,
  reinstall, or native change was required for this R-only TODO.

- [x] TODO-5 (F12, OneLik, closed after installed validation 2026-10-14): **`InferenceContinKKRobustRegrOneLik` randomization
  null uses a different estimator than the observed statistic.** In
  estimate-only mode the null draws fit Huber "M". The observed statistic is
  bisquare "MM" (0.5394) if `compute_estimate()` ran first, otherwise M (0.6248),
  so it depends on call order. `fit_weighted_combined` (Bayesian bootstrap)
  hard-codes "M". **Fix:** keep `private$rlm_method` in every path and only skip
  the SE in estimate-only mode (warm-start bisquare from the cached full fit if
  speed matters). **Test:** randomization statistic at the observed `w` equals
  the reported estimate, regardless of call order.
  **Source implementation 2026-10-10:** the Rcpp and MASS paths now retain
  `rlm_method` for estimate-only fits and skip only standard-error extraction;
  weighted bootstrap refits now use that same method (or an already-established
  observed-fit fallback to M). The stale documentation and direct MM
  estimate-only/weighted-refit regressions were updated. **Installed
  validation 2026-10-14:** the weighted-combined-fit test passed 6 assertions
  and the randomization/refit test passed 10, against EDI 1.0.3. The R runtime
  now starts with oneMKL on its library path; no compile or install was needed.

- [x] TODO-6 (F21, closed after installed validation 2026-10-14): **Dependent-censoring bootstrap CI is outcome-dependent and
  biased toward non-rejection** (`inference_survival_dep_cens_transform.R:~363`,
  `dep_cens_validate_bootstrap_ci`). The percentile, basic and BCa CIs are replaced
  by the Wald CI whenever the bootstrap CI excludes 0 and Wald does not (never
  the reverse). The studentized CI goes NA (nonestimable) whenever it excludes
  0, so it can never reject. Any endpoint beyond ±2 is declared unstable. The
  roxygen says NA, but the code substitutes Wald. Present since the initial
  commit. **Fix:** remove every zero-based swap or NA. Keep only data-independent
  sanity checks (non-finite values, too few usable replicates, bootstrap-distribution
  diagnostics). Fix the docs. **Tests:** two reference tests assert the biased
  behavior and must be rewritten. Add a test that a CI excluding 0 is returned unchanged.
  **Source implementation 2026-10-10:** percentile, basic, BCa, and
  percentile, basic, and BCa intervals retain all finite bootstrap endpoints;
  the public studentized wrapper delegates to basic for this model (which has
  no replicate-SE estimator) and preserves that finite interval. The
  zero-based Wald substitution, ±2 cutoff, and studentized exclusion rule are
  removed.
  Component contracts, roxygen, and focused references now cover unchanged
  rejecting/wide intervals and numerical failure. **Installed validation
  2026-10-14:** the wrapper-wiring test passed 8 assertions, CI validation
  guards passed 11, and the studentized instability guard passed 2 against EDI
  1.0.3 (21 total). No compile or install was needed.

## Group B — resampling calibrated against the wrong target

- [x] TODO-7 (F13): **Ordinal KK random-effects Bayesian bootstraps use a
  fixed-effects fit** (`inference_ordinal_KK_clmm_abstract.R:~169`,
  `inference_ordinal_KK_combined.R:~460`). `InferenceOrdinalKKGLMM` reports
  0.583 (matches `ordinal::clmm`), but BB replicates are about 0.414 and the BB
  median is about 0.39. The BB targets the marginal coefficient, not the
  reported conditional one. The KKGLMM roxygen calls it a "fast approximation",
  and the CLMM classes don't document it. CLMM is currently masked by the σ-collapse
  bug (`→ TODO-31`, `glmm_variance_component_sigma_collapse.md`). Once that is
  fixed, CLMM shows the same mismatch, so **land this with or after TODO-31**.
  **Fix:** weighted random-intercept kernels for the BB, or disable BB for these
  classes (as KKGEE does). At a minimum, document that it targets the marginal coefficient.

  **Resolved 2026-10-09.** Both ordinal random-effects families now refit the
  conditional random-intercept model for every nonconstant bootstrap draw.
  `InferenceOrdinalKKGLMM` no longer calls the fixed-effects
  `fast_ordinal_regression_weighted_cpp`; it and all four CLMM links share
  `weighted_ordinal_random_intercept_fit()`, which expands matched-unit weights
  to rows and fits `ordinal::clmm` with 20-point adaptive Gauss-Hermite
  quadrature. A failed default CLMM start is retried from a fixed-effects
  cumulative-link fit over deterministic log-sigma starts
  `{-5,-3,-1,0,1}`, retaining the highest finite likelihood. If the suggested
  `ordinal` package is unavailable or every mixed-model fit fails, the draw is
  nonestimable rather than silently changing estimands. Constant weights still
  take the existing exact unweighted fast path. Focused source-loaded tests
  cover logit/probit/cauchit/cloglog, zero-weight units, replicate SEs, the
  mixed-vs-fixed coefficient distinction, and direct agreement with an
  independently constructed weighted CLMM. No native rebuild is required for
  this R-only fix; installed comprehensive CSV regeneration remains a release
  reconciliation step.

- [ ] TODO-8 (F14): **KK clogit+GLMM Bayesian bootstraps fit glmmTMB (Laplace)
  on all rows**, while the point estimate uses clogit + 20-node GH
  (`inference_incidence_KK_cond_logit_glmm_abstract.R:~103-151`). Reported
  1.256 / 0.002 vs near-unit-weight replicates 0.910 / 0.339 (two seeds), a ~0.35
  log-OR shift. The IVWC sibling gets the identical BB distribution.
  **Fix:** add weights to `fast_clogit_plus_glmm_cpp` (per-pair on the clogit
  term, per-row in the GLMM) and use it for replicates, or disable BB.
  **Tests:** add a direct weighted-joint-kernel/class-dispatch regression;
  `test-prop-kk-glmm-weighted-refit-reference.R` covers the separate
  proportion-only GLMM class and is not evidence for this joint estimator.

  **Source implementation completed 2026-10-10; execution pending rebuild.**
  `fast_clogit_plus_glmm_cpp` now accepts strictly positive finite likelihood
  weights for the discordant-pair and concordant/reservoir blocks.  The
  conditional-logit log likelihood, score, and information use one mean
  matched-pair weight per discordant pair; every GH-integrated GLMM
  contribution uses its row weight.  The shared incidence/proportion bootstrap
  path now removes zero-weight likelihood rows and calls that weighted 20-node
  joint kernel rather than `glmmTMB`.  A focused joint-kernel/class-dispatch
  regression was added beside the independent data-assembly reference.
  **Installed validation 2026-10-14:** the direct joint-kernel/GLMER reference
  passed 34 assertions; class data assembly against the weighted joint kernel
  passed 25 (including `weights_disc`/`weights_conc`); constant-weight and
  extreme-coefficient guards passed 4 each, all against EDI 1.0.3. The
  installed native wrapper accepted and exercised the weighted arguments.
  Codex did not rebuild/install; comprehensive regeneration remains open.

  **Comprehensive-results readiness audit, 2026-10-16 (read-only):** the
  checkout contains no `comprehensive_tests_results*.csv`. The available
  `/tmp` artifacts contain older `InferenceIncidKKCondLogitGLMMOneLik`
  incidence/Bayesian-bootstrap rows on commit
  `5d8246300ea034bed7f4591d7f2258a7215436eb`, predating this implementation;
  they are not post-fix evidence. No comprehensive CSV found in the available
  `/tmp/edi-*` trees contains `InferenceIncidKKCondLogitGLMMIVWC`. The stale
  filtered OneLik artifact has only the ten Bayesian-bootstrap methods
  (five confidence-interval variants and five two-sided-p-value variants),
  repeated across `model_formula=~1` and `model_formula=~.`; its rows are all
  `beta_T=0`, rep 1, dataset `pima`, design `KK21stepwise`, with status `ok`.
  The matching workspace CSV and TODO-56 snapshot copy are byte-identical
  (SHA-256 `329a7182430e46eb5f4f97c387f397ba378978e8489f1aa92ea742c5293b6fd2`).
  Thus current post-fix rows are absent for both
  affected incidence classes: `InferenceIncidKKCondLogitGLMMOneLik` and
  `InferenceIncidKKCondLogitGLMMIVWC`, for all ten methods in
  `bayesian_bootstrap`.

  **CI artifact reconciliation, 2026-10-16 (read-only):** successful bulk
  test run `38808821543` used SHA
  `430c19bcdb0702d998c79f9058c449449034134c`, which includes the source fix
  from ancestor commit `c189e94f` (2026-10-10). It is post-fix, but it
  predates the current checkout HEAD `3af6e7a3`; the run's result scope is
  limited to the joint-kernel/class-dispatch regression and is not evidence
  for comprehensive Bayesian-bootstrap rows at current HEAD. The installed
  EDI 1.0.3 library was built at 2026-10-16 01:54:50 IDT, before current HEAD
  was produced at 17:40 IDT, so it too is stale for current-HEAD validation.
  (shard-4 job `116681563370`, artifact `correctness-shard-4`, SHA-256
  `0263aa80b11c88929309ac72ca8d9926d88b0efe9807ef4414db743586a608ed`). Its
  shard plan assigns `test-clogit-plus-glmm-joint-kernel-glmer-and-conditional-logit-references.R`
  to correctness shard 4; the artifact timing row reports `0.839` seconds,
  status `complete`. This is valid post-fix focused native-kernel/class
  validation, not a comprehensive Bayesian-bootstrap run: the artifact has
  only shard timings, not result CSV rows. In the current tracked
  `comprehensive_suite_workflow_coverage.csv` (also generated at
  `430c19bc…`), the generic fixed-Bernoulli constructor smoke rows for both
  classes are `exempted` because those inference classes require a
  KK-matching or binary-match design; the two default Bayesian-bootstrap
  method rows per class remain `workflow_only` with zero recorded calls.
  Consequently this CI evidence does not satisfy the comprehensive-results
  reconciliation gate.

  The focused comprehensive selector in `run_inference_checks_both_paths()`
  emits both `model_formula=~1` and `model_formula=~.` for these classes. For
  the one-rep/one-dataset slice below, reconcile 40 expected keys: 2 classes
  × 2 formula labels × 10 methods. The ten method labels are default/basic/
  Wald/BCa/studentized Bayesian-bootstrap confidence intervals and
  default/symmetric/Wald/BCa/studentized two-sided p-values. Compare the CSV
  key fields `rep`, `beta_T`, `dataset`, `response_type`, `design`,
  `inference_class`, and `function_run` (plus `case_id`), and require
  `method_family=bayesian_bootstrap`, the post-fix `github_commit_id`, and
  terminal per-row status; preserve explicit `nonestimable` reasons rather
  than treating them as errors. Expected post-fix slice: rep 1, beta_T 0,
  pima, incidence, KK21stepwise. A wider release reconciliation must then
  cover every accepted seed/beta/dataset slice, not just this minimal
  diagnostic.

  **Minimum isolated regeneration (static protocol only; not run):** after
  TODO-56 is terminal and a package built/installed from the intended current
  source commit is available, make a disposable copy of the required current
  `R/` test/data tree under `/tmp/edi-todo77.*` and run the harness from that
  copy's `R/` root. Keep `repo_root` at the disposable copy so its CSV goes to
  `/tmp/edi-todo77.*/R/package_tests/`, never the checkout. Because the
  harness obtains `github_commit_id` with `git -C repo_root rev-parse HEAD`,
  preserve the intended source commit in the isolated runner's Git context
  (for example, expose the checkout's read-only `.git` metadata via
  `GIT_DIR`/`GIT_WORK_TREE`) and verify the emitted commit field before
  accepting rows. The exact filtered run is:

  ```sh
  R_LIBS_USER=<library containing EDI built from the intended source commit> \
    Rscript package_tests/comprehensive_tests.R 1 1 incidence KK21stepwise \
    'InferenceIncidKKCondLogitGLMM(OneLik|IVWC)' pima 0 1 bayesian_bootstrap
  ```

  This selects `Nrep=1`, one core, incidence, design `KK21stepwise`, class
  regex `InferenceIncidKKCondLogitGLMM(OneLik|IVWC)`, dataset `pima`,
  `beta_T=0`, rep 1, and family `bayesian_bootstrap`. The expected filtered
  output basename is
  `comprehensive_tests_results_nc_1_incidence_filtered_design-KK21stepwise_class-InferenceIncidKKCondLogitGLMM_OneLik_IVWC_dataset-pima_beta-0_rep-1_family-bayesian_bootstrap.csv`.
  Reconcile exactly 40 method/configuration keys: for each of OneLik and
  IVWC, both `model_formula=~1` and `model_formula=~.`, and these ten
  `function_run` labels: `compute_bayesian_bootstrap_confidence_interval`,
  `compute_bayesian_bootstrap_confidence_interval_basic`,
  `compute_bayesian_bootstrap_confidence_interval_wald`,
  `compute_bayesian_bootstrap_confidence_interval_bca`,
  `compute_bayesian_bootstrap_confidence_interval_studentized`,
  `compute_bayesian_bootstrap_two_sided_pval`,
  `compute_bayesian_bootstrap_two_sided_pval_symmetric`,
  `compute_bayesian_bootstrap_two_sided_pval_wald`,
  `compute_bayesian_bootstrap_two_sided_pval_bca`, and
  `compute_bayesian_bootstrap_two_sided_pval_studentized`. Each result key
  includes `rep`, `beta_T`, `dataset`, `response_type`, `design`,
  `inference_class`, `function_run`, and `case_id`; additionally verify
  `method_family=bayesian_bootstrap`, intended `github_commit_id`, formula
  configuration, and terminal `status`/result fields (retaining explicit
  `nonestimable` reason fields). Record source HEAD and dirty status, package
  version/library path and installed DLL build time, exact argv, R/platform,
  seed behavior, and output SHA-256 in a `/tmp`-only run manifest. Do not use
  the 01:54 installed package or claim current-checkout validation; no
  build/install is authorized here, and this isolated result would not
  replace the canonical comprehensive-results regeneration/reconciliation
  gate.

- [ ] TODO-9 (F2): **`.cox_simulate_stratified` hazard mis-scaling**
  (`helper_survival_fits.R:592-615`). The baseline is normalized by the stratum's
  max risk, but subject risk by the global max, so the hazard shrinks by
  exp(M_s − M_g) in strata without the global max. Result: 61% of simulated
  times tied at `max_time` in such a stratum (corrected: 0.5%), and the refit
  β_x is 0.635 vs a true 1 (corrected: 0.991). This affects
  `InferenceSurvivalStratCoxPHRegr` (stratified) and the `KKStratCox*`
  parametric-bootstrap LR p-values and CIs (non-default; bites with covariates or δ ≠ 0).
  **Fix:** per-stratum `r_s = exp(eta[idx] − max(eta[idx]))`. **Test:** a
  simulate-then-refit recovery test across strata.
  **Source implementation 2026-10-10:** simulation now normalizes subject
  risks within the active stratum, exactly matching `.breslow_hazard()`; a
  deterministic two-stratum oracle with distinct risk maxima compares each
  slice to the single-stratum simulator. **Installed validation 2026-10-14:**
  `test-weibull-frailty-and-stratified-cox-simulation-reference.R` passed all
  35 assertions against EDI 1.0.3. No compile or install was needed.

- [x] TODO-10 (F17, closed after installed validation 2026-10-14): **ZOIB R side uses plogis-then-normalize on softmax
  coefficients.** The C++ likelihood is a softmax with mid as the reference
  (`params` = [β, log φ, γ0, γ1]). `zoib_mean_from_coefs` (marginal estimate and
  delta-method SE), the reused-worker bootstrap, and `simulate_under_lik_null`
  apply plogis-normalize instead. `marginal_mean_diff`: EDI −0.0876 vs
  softmax-consistent −0.0816 (truth −0.0782). The default-estimand parametric
  bootstrap is mildly distorted. The weighted-BB path fits separate logits (a
  distinct separate-fit model, so document or align it). **Fix:**
  `d = 1 + e^{a0} + e^{a1}`, `p0 = e^{a0}/d`, `p1 = e^{a1}/d`, `p_mid = 1/d`.
  **Test:** a `marginal_mean_diff` test against a softmax-consistent reference
  (none exists today).
  **Source implementation 2026-10-10:** a stable reference-category softmax
  helper now supplies both `zoib_mean_from_coefs()` and
  `simulate_under_lik_null()`, replacing their independent-logit
  plogis-normalize calculations. The weighted-bootstrap path still estimates
  separate weighted zero/one and beta submodels, but now combines those
  coefficients through the same softmax g-computation rather than treating
  its logits as independent probabilities; it therefore remains a distinct
  fitted model rather than a joint-MLE refit. The marginal-estimand reference
  now derives the same softmax independently. **Installed validation
  2026-10-14:** the marginal-estimand/delta-method test passed 11 assertions,
  softmax likelihood reference passed 25, marginal-estimand/weighted-bootstrap
  tests passed 26, and randomization-estimate refit passed 11 against EDI
  1.0.3 (73 total). The default and non-default paths now execute on the
  installed package; no compile/install was needed.

- [x] TODO-11 (F10, closed after installed validation 2026-10-14): **Zhang exact CI bracket is never validated**
  (`inference_helpers_zhang.R:~44,180,205`). The search bracket is the 2α Wald CI
  widened 50%, and its ends are never checked to lie outside the CI, so bounds are
  silently truncated (CI too narrow). Examples via `InferenceIncidExactZhang`:
  1/19/6/14 gives lower −4.953 (p there 0.068) vs about −5.27; zero-cell tables
  report finite bounds where the truth is ±∞. Also: bisection stops at
  |p − α| < 0.005 (about 0.04·se). Error-as-p = 0 is harmless (pinned
  deliberately). The same bisection is used in `inference_ext_quantile_rand_ci.R`.
  **Fix:** expand the bracket geometrically while p(outside) > α, return ±Inf at
  the cap, and stop on interval width (or tol around 1e-6). **Test:** zero-cell and
  too-narrow-bracket fixtures.

  **Source implementation completed 2026-10-10; execution pending.**  The
  shared Zhang bisection now expands either Wald-derived endpoint geometrically
  until it is outside the acceptance region, returns the appropriate infinite
  endpoint if the finite log-odds cap remains accepted, and uses a parameter
  interval tolerance capped at `1e-6` (rather than the old default 0.005
  p-value residual), including when a locally flat p-value curve would make a
  residual-only stop inaccurate.  Both direct exact and randomization-CI callers inherit
  this helper; their public default now requests `1e-6`.  Focused source tests
  cover a too-narrow bracket, a locally flat crossing, and an unbounded tail.
  **Installed validation 2026-10-14:** the exact incidence statistics/search
  suite passed 49 assertions, parallel CI bounds passed 5, and nonfinite-point
  guards passed 5 against EDI 1.0.3 (59 total). No compile/install was needed.

- [x] TODO-12 (F23): **`DesignFixedOptimal` BRT replays a weaker solver than
  produced the observed allocation.** Replicates always use annealing with
  1 chain × 2000 moves (`design_fixed_optimal.R:512-529`), which stops hot
  (T_final ≈ 0.135 T_0). The observed `w` comes from exact MILP (n ≤ 20) or
  4 × 20000 annealing. Replicate objectives are 6–45× worse (p = 3, n = 20–100), so the
  null is wider. This is **conservative**: size ≈ 0.02–0.03 at nominal 0.05 when R² is
  high, negligible at moderate R² for n ≥ 40. It is undocumented, and the plan
  calls the reduced budget harmless. **Fix:** a replicate profile that
  matches the observed one, or re-solve the observed `w` with the replicate
  profile. At minimum, end the cheap profile cold and document the
  conservativeness. Interacts with `algorithm_choice_audit.md → TODO-20`
  (exact enumeration would make the replicate solver exact at n ≤ ~30).

  **Source implementation completed 2026-10-10; execution pending.**  BRT
  replays now inherit the ordinary observed-assignment solver and budget unless
  a caller explicitly supplies `solver_args$brt_solver`; the old implicit
  `1 × 2000` annealing fallback is gone.  An explicit `brt_solver = "ompr"`
  now forces the MILP replay rather than silently taking the auto solver's
  large-design annealing threshold. The BRT wiring regression now checks the
  default certified solve and both explicit overrides. **Installed validation
  2026-10-14:** against EDI 1.0.3, the standalone non-CRAN
  `test-design-fixed-optimal-brt.R` run passed 22 assertions with
  `NOT_CRAN=true` in approximately 13 minutes, and
  `test-design-fixed-optimal-solver-args-brt-solver-guards-reference.R`
  passed 2 assertions. Exact BRT command:
  `Rscript -e 'Sys.setenv(NOT_CRAN="true"); library(EDI); testthat::test_file("R/package_tests/testthat_bulk/test-design-fixed-optimal-brt.R")'`.
  The prior `EDI.rdb` corruption/libdeflate failure did not recur in the fresh
  standalone run. No compile or install was run.

## Group C — legacy IVWC classes (still exported)

- [x] TODO-13 (F22, closed after installed validation 2026-10-14): **`InferenceSurvivalKKRankRegrIVWC` always returns NA**
  (estimate, SE, p, CI; reason `kk_rank_regr_ivwc_no_usable_component`, with or
  without covariates; coordinator re-ran). `aftgee::aftsrr(se = "ISMB", B = 0)`
  computes no variance when B = 0, so every rung of the 13-rung ladder is fitted and rejected
  (`inference_survival_KK_rank_regr_ivwc_abstract.R:~286/300/330/344`). Separately,
  the estimate-only path forces the variance to NA while `shared()` needs it finite.
  **Fix:** B ≥ 100 for ISMB (or ISCF), read the SE from
  `sqrt(diag(mod$covmat$ISMB))` rather than the rounded `summary()`, and let the
  estimate-only path combine with cached weights. **Tests:** the migration golden
  passes only because both sides are NA. Add a finite-output test.
  **Source implementation completed 2026-10-10; execution pending.** Both
  matched and reservoir `aftsrr` fits now request `ISMB` with 100 bootstrap
  replicates whenever a component variance is absent, and extract the
  unrounded treatment SE from `mod$covmat$ISMB`. Estimate-only resampling
  reuses finite cached component variances instead of overwriting them with
  `NA`; a later full call recomputes its final SE after an estimate-only call.
  A focused reference pins the direct ISMB covariance extraction. **Installed
  validation 2026-10-14:** the AFT candidate/cache suite passed 12 assertions,
  weighted-passthrough suite passed 10, and migration golden passed 36 after
  exposing its namespace helper for `test_file()` (58 total) against EDI
  1.0.3. No compile/install was needed.

- [x] TODO-14 (F15, closed after installed validation 2026-10-14): **`InferenceAllKKMeanDiffIVWC` randomization null is the
  plain mean difference** (`inference_all_KK_mean_diff_IVWC.R:~160-163`).
  `generate_permutations` never returns `m_mat`, the class substitutes zeros,
  and the C++ kernel sees no pairs. Shipped p = 0.19 vs 0.005 with the correct compound
  null (coordinator re-ran). **Fix:** fill `m_mat` with the design's match ids
  (fixed across re-randomizations), not zeros. **Tests:**
  `test-kk-mean-diff-ivwc-fast-randomization-distr-and-bootstrap-type-bug-reference.R`
  must assert the compound, not zeros, branch.

  **Source implementation completed 2026-10-10; execution pending.**  A
  missing `m_mat` from the matching permutation generator now restores the
  inference object's fixed match ids (with unmatched rows encoded as zero) in
  every randomization draw, instead of manufacturing an all-unpaired null.
  The focused regression now checks this path against the observed compound
  IVWC estimate. **Installed validation 2026-10-14:** the focused fast-randomization
  regression passed 6 assertions and the shared compound matched/reservoir
  dispatch suite passed 17 against EDI 1.0.3. No compile/install was needed.

- [x] TODO-15 (F7): **`InferenceAllKKWilcoxIVWC` HL variance is 2.09× too small**
  (`src/fast_wilcox_hl.cpp:~250-285` and its R mirror). Both component formulas
  (all pairwise differences / (n_T+n_C), Walsh averages / m) are wrong by the
  same factor under normality. Class coverage is 80.7% at nominal 95% (KK14,
  n = 80, 300 reps). The bootstrap CI aliases the asymptotic one. **Fix:** a
  consistent τ̂, e.g. the SE from the distribution-free Lehmann interval
  (`wilcox.test(conf.int = TRUE)`) per component, or a Koul–Sievers–McKean τ̂ with
  the correct factor. **Test:** a coverage smoke test.
  **Source implementation completed 2026-10-10; execution pending.** The R
  fit path and the native fast-bootstrap path now use the same normal-model
  calibrated HL variances: `2*pi/3 * Var(Walsh)/m` for matched pairs and
  `pi * Var(Y_T-Y_C) * (n_T+n_C)/(6*n_T*n_C)` for the reservoir. The
  class-level bootstrap-CI override that returned the asymptotic interval was
  removed. KK designs are sequential, however, and the package-level
  capability restriction disables ordinary nonparametric bootstrap CIs for
  them; the focused regression therefore pins both component formulas and
  asserts that this unsupported CI path errors rather than aliases Wald.
  **Installed validation 2026-10-14:** the focused R-side variance/CI test
  passed all 3 assertions against EDI 1.0.3. The native fast-bootstrap
  fast path was also called directly from installed EDI 1.0.3 with a
  deterministic mixed matched-pair/reservoir fixture. It returned 2.625,
  matching the independently calculated calibrated-variance estimate to
  1e-12 (matched variance 1.0471975512; reservoir variance 1.7453292520).
  `test-wilcox-hl-bootstrap-reference-contracts.R` passed 14 assertions.
  The original class-level coverage smoke test was rerun against installed
  EDI 1.0.3, with its original seed/DGP (KK14, n=80, two N(0,1) covariates,
  N(0,1) noise, treatment effect 1, 300 reps): the 95% asymptotic CI covered
  281/300 = 93.7%, with empirical SD(est)=0.2296 (47.7 seconds). The run used
  `Rscript -e 'source("/tmp/edi_f7_class_cov_installed.R")'`; that temporary
  script uses `library(EDI)` rather than loading the checkout. No compile or
  install was run.

- [x] TODO-16 (F11, closed after installed validation 2026-10-14): **KK hurdle-Poisson IVWC placeholder SEs of 1.0**
  (`inference_count_KK_cond_poisson.R:~364,419,449/470,165/177,274/284`). With
  `estimate_only = TRUE` the IVWC combination becomes an equal-weight average.
  Effects: randomization stays valid but loses power (observed and null both
  equal-weight); BB replicates are equal-weight while the CI is centred on the IVWC estimate
  (miscalibrated); `compute_estimate(estimate_only = TRUE)` caches the wrong
  estimate (0.8275 vs reported 0.8199). **Fix:** compute real component variances
  in estimate-only paths, or fix `w*` from the observed variances and reuse it.
  **Tests:** the existing reference test mocks real variances and must exercise
  the estimate-only path.
  **Source implementation completed 2026-10-12; execution pending.** All
  three IVWC estimate-only paths now obtain the matched hurdle-GLMM and
  reservoir Poisson variances before combining their estimates: ordinary,
  weighted/Bayesian-bootstrap, and randomization. The formerly reachable
  `1.0` placeholder branches were removed, so the fit helpers always return a
  usable variance or fail the component. The direct Rcpp helper no longer
  accepts the former `se = FALSE` switch that returned a placeholder.
  Focused mock regressions pin the
  real-variance IVWC result and verify that the weighted path no longer asks
  either helper for estimate-only fitting. **Installed validation
  2026-10-14:** the shared matched/reservoir test passed 9 assertions, weighted
  and randomization branches passed 17, and the Rcpp fit-guard suite passed 21
  against EDI 1.0.3 (47 total). No compile/install was needed.

- [x] TODO-17 (F12, IVWC, closed after installed validation 2026-10-14): **`InferenceContinKKRobustRegrIVWC` randomization
  p-value is always NA** on the default `use_rcpp` path. With
  `estimate_only = TRUE` the component variance returns NA (`_ivwc.R:~274`), so
  the combined estimate is NA. A fresh `compute_estimate(estimate_only = TRUE)`
  is also NA. **Fix:** the same approach as TODO-5 (keep the method, compute or
  cache component variances).
  **Source implementation completed 2026-10-10; execution pending.** The
  matched-pair and reservoir fits now obtain their finite component variances
  even when the outer IVWC call is estimate-only; only the final combined SE is
  suppressed. This preserves the configured robust-fit method and lets
  randomization combine the component estimates with its ordinary inverse
  variance weight. A focused private-method regression asserts that
  estimate-only calls request both component variances and retain the closed
  form IVWC point estimate. **Installed validation 2026-10-14:** the shared
  matched/reservoir test passed 12 assertions and the CRAN migration golden
  passed 36 against EDI 1.0.3 (48 total). No compile/install was needed.

## Group D — efficiency, documentation, coherence, robustness

- [x] TODO-18 (F20, closed after installed native validation 2026-10-14): **GEE exchangeable α̂ is not divided by φ̂**
  (`src/fast_gee.cpp`, `gee_estimate_exchangeable_alpha`). Overdispersed Poisson
  (φ̂ 4.75): EDI 1.54, clamped to 0.95, vs correct 0.327 (geepack 0.325).
  Proportions (φ̂ 0.083): 0.063 vs 0.763. Affects `InferenceCountKKGEE` and the
  KK GEE fits for proportion (probably ordinal) responses. Incidence is
  unaffected (φ = 1). β and sandwich SEs stay valid, so this is efficiency and
  Rcpp/geepack parity. **Fix:** Pearson φ̂ = Σ w r²/(N − p), then α̂ = num/((den − p) φ̂).
  **Test:** tighten `test-kk-gee-parity.R` (Poisson α tolerance 6e-2 masks it;
  add strongly overdispersed Poisson and a proportion case).
  **Source implementation completed 2026-10-10; execution pending rebuild.**
  The native exchangeable-alpha estimator now calculates weighted Pearson
  dispersion from all standardized residuals using `N - p` degrees of freedom,
  applies it to the pairwise residual-correlation denominator, and retains the
  existing bounded alpha safeguard. A strongly overdispersed Poisson
  geepack-parity reference asserts the corrected alpha rather than allowing the
  former near-0.95 clamp. **Installed validation 2026-10-14:**
  `test-kk-gee-parity.R` passed 22 assertions, including strict
  overdispersed-Poisson parity; weighted and count-weighted refit suites passed
  8 each against EDI 1.0.3. No Codex compile/install was run.

- [x] TODO-19 (F25): **g-computation SE estimand is documented.** The
  delta method propagates β uncertainty only (`src/gcomp_speedups.cpp:244-266,
  453-470`, the KK R fallback, and the ordinal/proportion g-comp classes), so it
  targets the effect conditional on the sample covariates. The population SE is
  larger by 0–6% (coverage 0.932–0.941 vs 0.933–0.945 with the term). **Fix:**
  document the conditional target, or add the `var(r1 − r0)/n` term as an option.
  Also fix `InferenceIncidGCompRiskDiff`'s false roxygen sentence "no closed-form
  asymptotic standard error is used" (its Wald methods use `se_rd`).
  **Resolution 2026-10-10:** the public incidence g-computation documentation
  now identifies both the risk-difference and risk-ratio sandwich-plus-delta
  SEs as conditional on the empirical covariate distribution used for
  standardization.  It explicitly distinguishes that Wald inference from the
  intentionally absent likelihood-ratio/score tier and states that the SE
  does not include target-population covariate-distribution sampling
  variation.  The existing sample-conditional estimand is retained; adding a
  population-marginal variance option is outside this release's scope.

- [x] TODO-20 (F26): **Exact-binomial CI and p-value use one two-sided
  rule.** The CI is Clopper–Pearson (central) but `zhang_exact_binom_pval_cpp` is
  minlike. They disagree only when δ0 ≠ 0: d+ = 0, d− = 5, δ0 = 0.01 is inside the
  CI (−∞, 0.087) yet p = 0.0305 (13,110 disagreeing grid points for k = 5–40).
  **Fix:** one rule for both (central p to match CP, or a minlike/Blaker CI).
  `test-incidence-exact-binomial.R:36` pins CP. Add a coherence test.
  **Resolution 2026-10-10:** `InferenceIncidExactBinomial` now uses the
  equal-tail central binomial p-value directly, matching its
  Clopper--Pearson interval for every null log odds ratio.  The exported
  Zhang kernel retains its minlike definition for its distinct callers.  New
  reference coverage pins the previously incoherent `d_+=0`, `d_-=5`,
  `delta_0=0.01` case and confirms that its central p-value does not reject
  when the null is in the interval.

- [x] TODO-21 (F6): **Jonckheere–Terpstra exact p-value can hang
  uninterruptibly** (`src/fast_jonckheere_terpstra.cpp:82-131`). The recursion
  enumerates compositions with no memoization, no size guard and no
  `checkUserInterrupt`: 4.78e12 leaves at K = 11, n = 200, about 13 h at 1e8 leaves/s.
  Only reached by an explicit
  `compute_exact_two_sided_pval_for_treatment_effect()` or the exported cpp
  function (results are correct). **Fix:** polynomial DP over (level, treated
  seen). At minimum add an interrupt check plus a leaf-count guard falling back to
  the normal approximation with a warning. See
  `algorithm_choice_audit.md → TODO-15`.
  **Source implementation completed 2026-10-10; execution pending rebuild.**
  A polynomial constrained-composition preflight now caps direct exact
  enumeration at one million allocations before recursion begins, and the
  permitted recursion checks for R interrupts every 4096 leaves. The public
  inference method catches only this capacity error, warns, and returns its
  existing asymptotic normal p-value; direct kernel users receive the explicit
  capacity error. Large 11-level regressions assert both the direct guard and
  public warning/fallback without entering recursion. After installing the
  current checkout (`make` found no stale native objects),
  `test-jonckheere-exact-enumeration.R` passed all 33 assertions, including
  direct-kernel rejection and public warning/fallback.

- [x] TODO-22 (F3, closed 2026-10-15 via `../future_release_plans/release_v1_0_5.md → TODO-91`, which records the 8-leg CI evidence and the golden tests): **`std::shuffle` / `<random>` distributions make draws
  stdlib-dependent.** Algorithms are implementation-defined (libstdc++ vs libc++),
  so the same seed gives different draws on Linux and macOS (distributions
  correct). Default paths: iBCRD initial assignment and redraws,
  `DesignFixedBlocking`, SPBR, stratified blocking bootstrap, greedy,
  rerandomization and optimal/annealing searches. The in-code "cross-platform
  guarantee" comments (`rerandomization_helpers.cpp:34-40`,
  `generate_permutations.cpp:126-133, 438-444`) are wrong; `RNG.h` itself only
  claims raw-stream portability, which is true. **Fix:** hand-written
  Fisher–Yates on `edi_rng::bounded_rand`, and `bounded_rand` / `unif_rand`
  in place of the distributions. **Test:** a fixed-seed golden for
  `generate_permutations_ibcrd_cpp` so macOS CI catches drift.
  **Default change:** seed-pinned draws change once on whichever platform's
  library is not matched. See `algorithm_choice_audit.md → TODO-23`.
  **Source progress 2026-10-09:** `RNG.h` now supplies portable
  Fisher--Yates over `bounded_rand`; the native design/resampling sources no
  longer use `std::shuffle`, `std::uniform_*` distributions, or stale
  `<random>` headers. **Linux golden recorded 2026-10-14:** the portable EDI
  1.0.3 build produced the six fixed-seed digests now committed in
  `R/EDI/tests/testthat/fixtures/cross_platform_digests.csv`; the focused
  cross-platform digest test passed all 18 assertions on Linux, including
  thread-count invariance and exact fixture matches. The macOS comparison has
  not yet run, so cross-platform confirmation remains the only outstanding
  platform gate and this plan item remains unchecked.

- [x] TODO-23 (F19): **Firth penalty has the wrong sign** in
  `evaluate_penalized_neg_loglik_at`
  (`inference_mixin_off_optimum_likelihood_eval.R:92-106`): it returns
  `neg_loglik + 0.5*log_det` and should be `−`. There are no callers today, and
  `test-off-optimum-likelihood-eval-mixin-reference.R` asserts the wrong sign.
  **Fix:** flip the sign in code, comment and test before anything calls it.
  **Source implementation completed 2026-10-10; execution pending.** The
  opt-in Firth/Jeffreys negative objective now returns
  `neg_loglik - 0.5 * log|I|`; its explanatory comment and independent
  hand-calculated reference were changed to the same sign.
  After installing the current checkout,
  `test-off-optimum-likelihood-eval-mixin-reference.R` passed all 17
  assertions.

- [x] TODO-24 (F4, low priority): **Per-replicate seeds drawn with
  replacement from 31 bits** (`sample.int(.Machine$integer.max, B, replace = TRUE)`
  at `param_boot.R:598`, `param_bootstrap_estimate.R:171`,
  `rand_bootstrap.R:698`). Collision probability is about 2.3% at B = 1e4, giving an
  identical parametric-bootstrap replicate. Impact ≤ 1/B. **Fix:** draw without
  replacement, or use L'Ecuyer substreams.
  **Source implementation 2026-10-10:** all three batch seed producers now
  call `sample.int(..., B, replace = FALSE)`. Randomization-bootstrap first
  creates one unique `w_seeds` vector, then attaches its corresponding seed
  to each materialized draw, preserving replay semantics. A regression checks
  that 31 generated BRT draws have unique, deterministic replay seeds.
  After installing the current checkout, `test-rand-bootstrap.R` passed 145
  assertions (4 CRAN-only skips), including the deterministic 31-draw BRT
  uniqueness/replay regression. The installed R code is the source under audit,
  whose three batch producers use `replace = FALSE`.

- [x] TODO-25 (F16, low priority): **g-computation Bayesian-bootstrap
  weighting convention is consistent.** Non-KK incidence, proportion, and
  ordinal g-computation average predictions equally over retained empirical
  covariate rows (the sample-conditional estimand, consistent with their Wald
  SE); the KK incidence implementation now does the same after its weighted
  logistic refit.  This changes only the Bayesian-bootstrap/resampling
  replicate standardization, not the ordinary estimate.  Its public KK
  incidence documentation now makes the convention explicit; see also
  TODO-19 for the corresponding Wald-SE target.
