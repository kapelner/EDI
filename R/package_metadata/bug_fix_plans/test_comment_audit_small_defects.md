# Test-Comment Audit: Smaller Defects, Robustness Gaps and Open Questions

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `../future_release_plans/release_v1_0_5.md → TODO-35..46` (plan item n is release TODO-(34+n), one release TODO each). Added 2026-09-24
> from an audit of comments in `R/package_tests/testthat_bulk/` and
> `R/EDI/tests/testthat/`. Each item below was recorded by a test author who
> saw it while writing coverage and deliberately did not fix it ("noted, not
> fixed" / "confirmed source bug, NOT fixed" / "quirk"). **None were
> independently reproduced by this audit beyond what the (passing) pinned
> tests already assert.** Items are ordered by suspected user impact. Larger
> items got their own plans (`glmm_variance_component_sigma_collapse.md`,
> `ridit_treatment_reference_degenerate_estimate.md`,
> `rand_ci_high_precision_refinement_upper_bound.md`,
> `interval_censored_compute_shared_cache_guard.md`).

## Items

- [x] **TODO-1: `delta = NA` crashes with a generic R error.**
  `InferenceIncidGCompRiskRatio`'s asymptotic/Wald p-value:
  `assertNumeric(delta, len = 1)` lets `NA` through (checkmate's
  `any.missing = TRUE` default), then `if (delta <= 0)` errors with "missing
  value where TRUE/FALSE needed" instead of the intended "delta must be
  strictly positive". Test: `test-incid-gcomp-risk-ratio-asymp-and-wald-pval-nonpositive-delta-guard-reference.R`.
  Fixed with `any.missing = FALSE` in ordinary and KK incidence g-computation
  p-values. The same sweep also fixed Newcombe risk-difference p-values, which
  previously returned 1 for a missing null value. Regression tests cover all
  three paths.
- [x] **TODO-2: Exact-test classes cannot use the shared weighted estimate.**
  `ExactTestSource$compute_estimate_with_bootstrap_weights()` calls
  `private$expand_subject_or_block_weights_to_row_weights()`, which only the
  BayesianBootstrap component provides, so it errored on the exact Fisher
  class instead of resampling. Exact-only classes now report that bootstrap-
  weighted estimation is unsupported, without invoking unavailable helpers.
  Test: `test-exact-test-source-type-resolution-arg-normalization-and-weighted-estimate-reference.R`.
  The corresponding exact-class exceptions were removed from
  `EDI_WIRING_KNOWN_GAPS` in `test-inference-class-wiring-completeness.R`.
- [x] **TODO-3: `inference_class_accepts_model_formula()` is always FALSE.**
  It inspects `formals(<R6 generator>$new)`, which is just `...`, so it
  returns FALSE for every class even when `initialize()` takes
  `model_formula`. Find its callers and what they do with the wrong answer.
  `run_all_inference_build_tasks()` consequently ignored every supplied
  formula and built only the default task. Fixed by inspecting the effective
  R6 initializer, including inherited methods and lazy component stubs.
  Regression coverage in `test-inference-suite-class-predicates-...-reference.R`;
  source behavior was checked without rebuilding the package. The ordinary
  release build/check will verify the installed artifact; it is a release-wide
  gate rather than unfinished work in this item.
- [x] **TODO-4 (kernel fixed 2026-09-24; sibling sweep still open): `.fit_zero_one_inflated_beta()` / `fast_zero_one_inflated_beta_cpp()`
  instability.** In a fresh Rscript the kernel returned `neg_loglik = NaN` and
  `coefficients = NULL` on ordinary well-conditioned data (8 of 8 seeds) and
  crashed downstream on a zero-length names assignment; the same call did not
  reproduce inside a testthat session, pointing at undefined
  behavior/memory safety in the C++ kernel. The R-level guard was fixed; the
  kernel was not. The R function has no callers in `R/EDI/R/`, but the same
  kernel backs `InferencePropZeroOneInflatedBetaRegr`, so first check whether
  that class can hit it. Run under ASan/valgrind (the CI sanitizer jobs).
  Test: `test-zoib-start-value-construction-reference.R`.
  **Reproduced 2026-09-24 (valgrind, installed package).** Root cause: the
  kernel does `params = *warm_start_params;` (`fast_zero_one_inflated_beta.cpp`
  around line 428) with no check that the vector has `total = p + 1 + 2 *
  p_zero_one` entries. The uncalled R helper `.fit_zero_one_inflated_beta()`
  passes a length-6 start (from `.build_zoib_start()`) to a kernel expecting 11
  parameters, so `optimize_fixed_likelihood<ZeroOneInflatedBeta>` and
  `FixedParameterFunctor::operator()` read and write one element past an
  88-byte block (heap overflow); a later allocation then aborts with
  `free(): invalid next size` / `double free or corruption`. Reproduced 3 of 3
  when kernel calls are followed by class calls in one fresh process, and not
  in either alone. `InferencePropZeroOneInflatedBetaRegr` calls the kernel
  with a correctly sized start and did not crash in 12 or 6 runs, so the class
  is not affected today; but any external caller, including the Python
  bindings, that passes a wrong-length `warm_start_params` corrupts the heap.
  Fix: validate the length (and the other optional vectors) in the kernel with
  a clear error; add the same guard to sibling kernels' warm-start handling
  (sweep `warm_start_params` in `src/*.cpp`); and delete or repair the dead
  R helper.
  **Kernel fixed 2026-09-24.** `fast_zero_one_inflated_beta_internal` now
  validates the warm-start length (`p + 1 + 2 * p_zero_one`), the
  `warm_start_fisher_info` shape, and that `X`, `X_zero_one` and `y` have equal
  row counts, throwing `std::invalid_argument` (same style as
  `fast_negbin_regression.cpp`). Verified: only `fast_zero_one_inflated_beta.cpp`
  was recompiled and `src/EDI.so` relinked (backup of the previous `.o` and
  `.so` kept outside the repo); the new `tests/testthat/test-zoib-kernel-input-length-validation.R`
  passes (9 expectations) on the fixed build and aborts R on the previous
  build; the original crash script, which aborted 3 of 3 times, now completes
  3 of 3. Not yet done: a valgrind rerun of the fixed build, the R helper
  cleanup, and the sibling sweep below (the "TODO-4" checkbox covers the
  ZOIB kernel only; the 9 other unchecked sites stay open).
  **Sweep of sibling kernels (static, 2026-09-24).** 26 sites copy a
  caller-supplied `warm_start_params` into the parameter vector
  (`= *warm_start_params;`). A crude check (any size comparison or
  length-related stop within a few lines) found none for 10 of them:
  `fast_gaussian_lmm.cpp:424`, `fast_hurdle_negbin.cpp:631` and `:769`,
  `fast_hurdle_poisson_glmm.cpp:490`, `fast_logistic_glmm.cpp:486`,
  `fast_ordinal_glmm.cpp:293`, `fast_poisson_glmm.cpp:376`,
  `fast_weibull_frailty.cpp:333`, `fast_zero_augmented_poisson.cpp:285`, and
  `fast_zero_one_inflated_beta.cpp:428`. The heuristic can miss checks done
  elsewhere in the function or in the R wrapper, so each of the 10 needs to be
  read; only the ZOIB kernel is confirmed as an overflow (valgrind).
- [x] **TODO-5: `DesignFixedOptimalBlocks` (blockTools/greedy path) trailing
  incomplete block.** When `n` is not a multiple of `B`, leftover subjects
  reach the nearest-neighbour fallback, but its unrestricted choices can put
  several in one block. Reproduced with `n = 8`, `B = 3`: block sizes were
  `4, 2, 2` instead of `3, 3, 2`. The fallback now chooses the nearest block
  still below `ceiling(n / B)`, preserving floor/ceiling sizes. Focused
  source-loaded tests cover the allocation, balanced assignment draws, and
  randomization inference without rebuilding the package. Test:
  `test-fixed-optimal-blocks-feasibility-draws-and-uneven-sizes-reference.R`.
- [x] **TODO-6: Sparse positive weights in the incidence risk-difference
  weighted refit.** With only two positive-weight rows, the hardened retry
  uses `required_cols = 1L` (intercept only), drops the treatment column too,
  and `which(attempt$keep == 2L)` is `integer(0)`, so the cached estimate is a
  zero-length numeric rather than `NA_real_`. Zero-length results can fail
  downstream `is.finite()` guards in unexpected ways. Fixed by retaining
  intercept and treatment in QR retries and caching a scalar `NA_real_` with
  reason `risk_diff_weighted_fit_unavailable` when a finite treatment estimate
  is unavailable. Sparse and ordinary weighted regressions pass focused
  source-loaded tests without rebuilding the package. Test:
  `test-incidence-risk-diff-fast-shortcut-and-sparse-weights-reference.R`.
- [ ] **TODO-7: `randomization_loop` callback result is unchecked.**
  `result[0]` on a length-0 vector is read without a length check; Rcpp only
  warns and the loop continues, leaving the entry undefined instead of failing.
  Test: `test-randomization-loop-kernel-callback-contract-...-reference.R`.
- [ ] **TODO-8: Is the stale Bayesian-bootstrap worker still there?**
  `test-cox-component-composition.R` works around a "pre-existing bug in the
  shared reusable-worker infrastructure" that leaves a stale
  Bayesian-bootstrap worker context after a randomization or non-parametric
  bootstrap call on the same object (also on `InferenceSurvivalKMDiff`),
  by using a fresh object per capability. The stale-worker work
  (`stale_worker_cache_resampling.md`, Option A) may have resolved it; check
  by removing the workaround, and either delete the comment or plan the fix.
  **Investigated 2026-09-24: the stale Bayesian-bootstrap worker was NOT
  reproduced; the workaround appears unnecessary.** On the installed package,
  240 same-object runs (`InferenceSurvivalCoxPHRegr` and
  `InferenceSurvivalKMDiff` x 15 seeds x 8 call orderings, including
  randomization then Bayesian bootstrap, non-parametric bootstrap then
  Bayesian-bootstrap distribution then p-value, and the reverse orders) had 0
  failures; every step returned finite results. The stale-worker fix
  (`stale_worker_cache_resampling.md`, Option A) is the likely reason. The
  one `NA` seen earlier on `InferenceSurvivalKMDiff` was a *different*,
  stochastic issue (release TODO-54 / plan TODO-13), independent of object
  reuse. Next: remove the fresh-object-per-capability workaround in
  `test-cox-component-composition.R` (keep the assertions), rerun, and delete
  the comment.
- [ ] **TODO-9: `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` optimizer is
  RNG-state sensitive.** A directly called, freshly constructed
  `compute_estimate(estimate_only = TRUE)` reproducibly returns `NA` on the
  test fixture while the identical fit reached via the constant-weights
  shortcut inside `compute_estimate_with_bootstrap_weights()` converges.
  Suggests a start-value or seeding dependence; related to
  `clayton_loggamma_frailty_optimizer_stability.md` and TODO-31's family.
  Test: `test-glmm-weibull-frailty-loggamma-ivwc-weighted-bootstrap-cluster.R`.
- [x] **TODO-10: Silent NA with no nonestimable reason (harden = FALSE or
  short paths).** Jackknife summaries with zero or one replicate now record
  SE-stage `jackknife_too_few_replicate_estimates`. Subsampling b-list and
  m-out-of-n m-list selection failures now record their existing estimate-stage
  `subsampling_b_selection_failed` and `m_out_of_n_m_selection_failed` reasons
  under either harden setting; confidence intervals retain their percentage
  labels. Focused source-loaded tests cover both harden settings and the
  successful selector paths without rebuilding the package. Tests:
  `test-jackknife-summary-nonfinite-and-extreme-guards-reference.R`,
  `test-prw-subsampling-pval-and-ci-b-list-selection-failure-guard-reference.R`,
  `test-m-out-of-n-bootstrap-pval-and-ci-m-list-selection-failure-guard-reference.R`.
- [ ] **TODO-11: Weighted-refit SEs never populated.** The Weibull fast
  surrogate, `InferenceIncidKKModifiedPoisson` and the modified-Poisson class
  return `NA` from the base `weighted_refit_se()` (`inference_all_abstract.R:566`) even with
  `estimate_only = FALSE`, contradicting a `@param` that implies `FALSE`
  computes a variance. Either implement the SE or correct the docs (see
  `test-modified-poisson-weighted-refit-reference.R`,
  `test-incid-kk-modified-poisson-weighted-refit-reference.R`,
  `test-weibull-bootstrap-surrogate-fit-shared-helper.R`).
- [ ] **TODO-12: Minor / cosmetic (batch).** Dead "Continuous covariates are
  not allowed for stratification" `stop()` in `add_one_subject()` (shadowed by
  `assertStrataClusterArgs()`); `extract_dollar_paths()` also returns nested
  sub-chains (pinned as documented behavior); `fast_weibull_regression(use_rcpp
  = FALSE)` ignores `estimate_only`; `with_var` kernel field sets differ across
  families (`XtWX` only on some), pinned so the inconsistency is visible.
  Record each as fix / document / accept.

- [ ] **TODO-13: `InferenceSurvivalKMDiff` Bayesian-bootstrap p-value is
  `NA` for about 30% of RNG states on heavily censored data (found 2026-09-24
  while investigating TODO-8).** With right-censored data (n = 100, event
  rate 0.5, censoring rate 0.3) a **fresh** object returned a non-finite
  `compute_bayesian_bootstrap_two_sided_pval()` in 12 of 40 RNG seeds, each
  with the recorded reason `bayesian_bootstrap_nonfinite_estimates`; a fresh
  object was also `NA` in 1 of 25 data seeds in a wider sweep. So it is not
  caused by object reuse, and the reason is recorded (my earlier note that none
  was recorded was wrong). Some resampled KM difference is evidently
  undefined (for example a statistic that needs the curve to reach a level in
  both arms). Decide whether one non-finite replicate should make the whole
  p-value `NA` (the non-parametric bootstrap on the same data does not) or
  whether non-finite replicates should be dropped subject to a minimum count,
  as other bootstrap p-values do; document what the statistic is.

## Explicitly out of scope

- Comments that merely note an *already fixed* bug (dozens; e.g. the
  `attempt$X_fit` typo, fixed 2026-09-24).
- Guards marked "unreachable in practice" and tested by mocking; those are
  intentional defensive code.
- The `KNOWN_BROKEN` / known-gap allowlists whose entries already have plans
  (`KKQuantileRegrOneLik_rand_ci.md`, the incidence randomization-CI stopgap).
