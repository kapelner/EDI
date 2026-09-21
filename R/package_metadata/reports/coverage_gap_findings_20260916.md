# Findings from the coverage test audit (2026-09-16)

The initial audit used already-installed EDI 1.0.1 and preserved failing
statistical references separately from the passing coverage tests. On
2026-09-17 the user authorized production fixes and active regression tests.
The descriptions below retain the original reproductions.

## Fix and verification status (2026-09-17)

The original six defects now have source fixes and active bulk regressions.
The rebuilt installed package passes the main bisection, two-core
Hodges-Lehmann, sequential name-matching, partial-odds MASS, and nonlogit
weighted ordinal checks. Subsequent fixes also remove phantom first-arrival
rows, retain requested metrics/counts in empty simulation reports, preserve
fatal data-generation diagnostics, and reject invalid uniform-weight shortcuts.
Transient R-only verification replaces definitions only in the verification
process; committed tests contain no source replacement or compilation.

The newest bisection precision policy and multinomial stereotype sampler fix
now pass against the user's freshly rebuilt installed package (2026-09-17). An incremental install
did not pick up a header-only bisection change, so the shared search is now
defined in `bisection_ci.cpp`; its header contains only the declaration.

The MASS cauchit backend caps CDF arguments at +/-100, including endpoints.
Its fitted likelihood therefore differs from `ordinal::clm` at appreciable
Cauchy tail mass. The new cauchit oracle independently optimizes that capped-CDF
likelihood; other links retain `ordinal::clm` references. Positive weights are
normalized to mean one in the point-estimate-only surrogate: the coefficient
optimum is unchanged, while MASS initialization remains invariant to scaling.

## C++ bisection can stop making progress

Source: `R/EDI/src/bisection_ci.cpp:100-133`,
`bisection_ci_single_bound_cpp()`.

The lower search replaces a missing midpoint p-value with zero, but terminates
only on the difference between endpoint p-values. When the missing midpoint
is also the rejection boundary, the delta interval can collapse while that
p-value difference stays above tolerance. There is no width or iteration guard.

Bounded installed-package reproduction (12-second timeout returns status 124):

```sh
timeout 12s Rscript -e 'library(EDI); f <- function(r, delta, transform_responses, num_cores) if (delta == .5) NA_real_ else delta; cat("ENTER_BISECTION\n"); print(EDI:::bisection_ci_single_bound_cpp(f, 1L, 0, 1, .5, .01, "none", TRUE, 1L))'
```

The R implementation's missing-midpoint behavior is separately covered in
`test-rand-bootstrap-ci-recovery-contracts.R`; it has interval-width convergence.
The C++ coverage test uses a distinct cutoff so it terminates.

## Sequential schema changes can misalign covariates

Source: `R/EDI/R/design_seq_one_by_one_abstract.R:115-156`,
`DesignSeqOneByOne$add_one_subject()`.

After filling new or omitted columns, the arrival can have a different column
order from existing data. `rbindlist()` is called without explicit name matching.
It can bind by position, misplacing values and coercing numeric columns to
character. A new numeric score must not become a subject's site value.

Installed-package reproduction:

```r
library(EDI)
d <- DesignSeqOneByOneBernoulli$new("continuous", seed = 641)
d$add_one_subject_to_experiment_and_assign(data.frame(x = 1.0, site = "A"))
d$add_one_subject_to_experiment_and_assign(data.frame(x = 2.0, score = 5.0))
d$get_X_raw()
# Expected second subject: x = 2, site = NA, score = 5.
```

`test-sequential-evolving-schema-contracts.R` covers adding and omitting trailing
columns with consistent order, typed covariates, and rejected-schema state
preservation. The misalignment needs a separate regression test with its fix.

## Historical zero-coverage classification needs correction

The legacy callback kernels `base_bootstrap_loop_cpp()`,
`matching_bootstrap_loop_cpp()`, `randomization_loop_cpp()` and
`bisection_ci_loop_cpp()` have no inference production callers in the graph;
they remain directly callable through Rcpp wrappers. Callback OpenMP is disabled
because callbacks use R. Their old zero-coverage classification as public
performance-dispatch paths is misleading. Direct kernel contract tests are
appropriate; merely increasing public inference resample counts cannot guarantee
reaching these wrappers.

The saved `/tmp/edi_full_coverage_20260915.rds` reports approximately 33.97% over
24,163 counters. A separate corrected instrumentation run is present in `/tmp`;
the saved report does not establish a trustworthy replacement for the plan's
historical full-suite baseline. In particular, source-list components need
instrumentation before interpreting their zero-hit entries as missing tests.

## Nonlogit weighted ordinal fits silently take the linear fallback

Source: `R/EDI/R/globals.R:160-225`,
`weighted_ordinal_bootstrap_surrogate_fit()`, called by
`R/EDI/R/inference_ordinal_KK_clmm_abstract.R:174-225`.

`fit_polr()` always passes `start = start`, including when `start` is `NULL`.
`MASS::polr()` treats an explicitly supplied NULL as an invalid starting vector;
the caught error sends every cold fit to the weighted linear fallback.
This changes the coefficient and ignores the requested nonlogit link.
The new independent references returned approximately .404 (probit), .650
(cauchit) and .525 (cloglog), while all three package fits returned .291.
The incomplete agent's failing regression test is preserved below, outside
the active bulk suite. A production fix and this regression belong together.

```r
test_that("nonlogit KK CLMM weighted surrogates agree with cumulative-link likelihood", {
  skip_if_not_installed("ordinal")
  des <- ordinal_clmm_coverage_design()
  y <- rep(1:3, 12L)
  w <- des$get_w()
  links <- c(InferenceOrdinalKKCLMMProbit = "probit",
             InferenceOrdinalKKCLMMCauchit = "cauchit",
             InferenceOrdinalKKCLMMCloglog = "cloglog")
  for (class_name in names(links)) {
    generator <- get(class_name, envir = asNamespace("EDI"))
    inf <- generator$new(des, model_formula = ~ 1, verbose = FALSE)
    private <- inf$.__enclos_env__$private
    context <- private$build_bayesian_bootstrap_context()
    private$current_bayesian_bootstrap_context <- context
    # KK bootstrap weights whole pairs and reservoir singletons together.
    weights <- rep(c(1, 2, 3, 2), length.out = context$n_units)
    row_weights <- weights[context$row_to_unit]
    reference <- ordinal::clm(ordered(y) ~ w, weights = row_weights,
                              link = links[[class_name]],
                              control = ordinal::clm.control(gradTol = 1e-8))
    estimate <- inf$compute_estimate_with_bootstrap_weights(weights, estimate_only = TRUE)
    expect_true(is.finite(estimate), info = class_name)
    expect_equal(estimate, unname(stats::coef(reference)["w"]), tolerance = 2e-4,
                 info = class_name)
    expect_true(is.na(private$cached_values$s_beta_hat_T), info = class_name)
    expect_equal(inf$compute_estimate_with_bootstrap_weights(5 * weights, estimate_only = TRUE),
                 estimate, tolerance = 2e-4, info = class_name)
  }
})
```

The regression uses `ordinal_clmm_coverage_design()` from
`test-ordinal-kk-clmm-boundaries-coverage.R`.

## Two-core Hodges-Lehmann bootstrap can abort R

An isolated installed-package validation by the resampling agent exited 134
with a C stack limit error and `Rcpp::internal::InterruptedException` when
`compute_wilcox_hl_bootstrap_parallel_cpp()` used two cores. Its serial
reference tests pass. Source `R/EDI/src/fast_wilcox_hl.cpp:381-433` enters
an OpenMP loop and calls `hl_from_groups()` (`:186-212`), which invokes
the R interrupt helper. Calling the R API from worker threads is the
likely cause; further isolated regression and production fix are needed.
New tests in `test-wilcox-hl-bootstrap-reference-contracts.R` intentionally
use one core. The crash itself is not included in the bulk suite.

## Weighted partial-odds MASS fallback loses the data environment

Source: `R/EDI/R/inference_ordinal_partial_proportional_odds.R:654-676`.
With preceding backends disabled, the weighted MASS backend returns NULL.
Re-evaluating its function body with the caught error printed gives
`object 'dat' not found`. The formula environment cannot resolve the
`weights = dat$.bootstrap_weight__` expression. The cascade then reaches the
linear surrogate, returning 0.4 instead of log(3) for two arms with exactly
the same cumulative-logit shift at both thresholds. A direct MASS fit to
the same data returns approximately 1.09834.

The passing unweighted reference allows 1e-4 error for default MASS
optimization (observed error 1.46e-5). This separate weighted regression
is preserved here until the production fix:

```r
test_that("weighted partial odds MASS fallback preserves an armwise common odds shift", {
  fixture <- partial_odds_fallback_fixture()
  p <- fixture$private
  p$current_bayesian_bootstrap_context <- p$build_bayesian_bootstrap_context()
  # Unequal arm weights change precision, but preserve each arm's category probabilities.
  weights <- rep(c(2, 3), each = 20L)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(weights), log(3), tolerance = 1e-5)
  expect_equal(fixture$inf$compute_estimate_with_bootstrap_weights(5 * weights), log(3), tolerance = 1e-5)
  expect_true(is.na(p$cached_values$s_beta_hat_T))
})

```

The fixture is defined in `test-partial-odds-backend-fallback-reference.R`.

## Legacy bisection upper-tail convergence uses the wrong sign

Source: `R/EDI/src/bisection_ci_loop.cpp:27-70`. With a decreasing
upper-tail p-value, `pval_u - pval_l` is negative, so the convergence
check succeeds before any midpoint is evaluated. The analytic callback
`1 - delta`, bounds 0 and 1, and cutoff .25 should locate .75; the
installed wrapper returns 1. The existing smoke test uses an increasing
callback for both tail directions and expects this unchanged endpoint,
so it does not detect the defect.

```r
expect_equal(EDI:::bisection_ci_loop_cpp(
  function(r, delta, transform_responses) 1 - delta,
  1L, 0, 1, .25, .001, "none", FALSE), .75, tolerance = .002)
```


## Multicategory stereotype sampler exits at a singular cold start

Source: `R/EDI/src/fast_stereotype_logit.cpp`,
`compute_stereotype_logit_distr_parallel_cpp()`.

The old sampler initialized all slopes to zero. Category-score nuisance
parameters then have a zero Hessian block; with enough categories the full
Hessian is singular. Its legacy Newton routine exits and accepts an unoptimized
zero treatment coefficient. An interior five-category fixture with positive
counts in both arms has independently fitted coefficients +/-log(5), while the
installed old sampler returns zero. The sampler now uses the shared LBFGS
likelihood optimizer; its unused Newton-only helpers were removed.
`test-stereotype-multicategory-sampler-reference.R` checks independent BFGS
references, shifted/merged levels, row permutations and one/two cores.
The rebuilt native sampler passes all 11 assertions against the independent
reference, including one/two-core execution.

## Uniform bootstrap shortcut loses valid weighting on small scales

Source: `R/EDI/R/globals.R`, `weights_are_effectively_constant()`.

The old helper ignored nonfinite entries and used an absolute weight
difference. All-zero draws returned an unweighted estimate, and multiplying a
nonuniform draw by a tiny positive scale made it appear uniform. The helper
now requires every weight to be finite and positive and compares the spread
relative to the maximum weight. Independent weighted normal equations in
`test-bootstrap-uniform-weight-scale-regressions.R` verify KK OLS under
ordinary, 1e-12 and 1e-200 scales and require NA for all-zero draws.

## Simulation worker fatal errors referenced uninitialized state

Source: `R/EDI/R/simulations_framework.R`,
`.run_single_replication_in_worker()`.

Fatal custom-data errors invoked the error handler before its results and
skip-count state existed, replacing the original condition with
`object 'results' not found`. State initialization now precedes data
generation. `test-simulation-worker-data-error-contracts.R` checks invalid
custom data and preserves condition class, stage, replication and cell metadata
under both stopping modes. Sixty-eight assertions pass against the rebuilt installed package.

## Empty simulation summaries omitted requested metrics

Source: `R/EDI/R/simulation_framework_report.R`, `summarize()`.

Completed runs with no successful rows previously omitted requested coverage,
size and calibration columns. Missing cells in partially observed grids also
reported NA coverage counts. Typed empty metric columns and zero coverage
counts now preserve every valid cell without inventing observations.
`test-simulation-report-completed-state-contracts.R` adds 44 assertions,
including parameter annotations and framework alpha inheritance/override.


## Weighted ordinal all-zero shortcut and finite-MLE smoke fixture

The actual logistic KK CLMM path now requires positive finite weights before
taking its unweighted shortcut. Its new independent `ordinal::clm` references
check paired-unit expansion, coefficient and standard error, uncertainty scaling,
zero-weight pair/singleton omissions, and warm starts (19 passing assertions).
A small native stopping-rule coefficient difference after omissions is checked
against both a 3e-4 coefficient tolerance and independent likelihood loss <1e-6.

The broader shipped Bayesian-bootstrap suite already failed on the installed
baseline for an ordinal fixture perfectly ordered by its adjustment covariate.
Finite estimates were not a valid expectation for that separated fixture.
The smoke test now has every category in both arms and covariate overlap, and
reports the failing class name. The suite passes with the updated R definitions;
the mirai parity block remains skipped under the default CRAN flag.

Final verification against the user's rebuilt package passes all eight selected
files (341 assertions), including the tiny-response-scale bisection change and
four multicategory sampler coefficient assertions, without substituting R definitions.


## Conditional-Poisson combined point estimate loses tiny bootstrap weights

Source: `R/EDI/R/inference_count_KK_cond_poisson.R`,
`compute_weighted_combined_estimate()`.

The rebuilt baseline returns 0.6174581 for weights (1, 2, 4, 7), but
0.6419020 for the same relative weights scaled by 1e-12 or 1e-200. The
absolute optimization stopping threshold accepts its initial unweighted fit.
All-zero weights also return that initial coefficient. The R-only fix rejects
zero positive mass and normalizes weights by their maximum before point-estimate
optimization. Uncertainty calculations retain their original weights.

`test-count-kk-poisson-weighted-profile-reference.R` compares the fit with an
independently profiled conditional-binomial plus reservoir-Poisson likelihood,
including objective loss, omitted units, tiny scales and zero-mass cache clearing.
Eighteen assertions now pass against the rebuilt installed package (2026-09-18),
without source-method substitution.


## Conditional-logistic weights retained discarded concordant pairs

Source: `R/EDI/R/inference_incidence_KK_cond_logit.R`,
`conditional_logit_weighted_combined_estimate()`.

The combined conditional-logistic design omits concordant pairs, while the
old weighting code retained all matched-pair weights. With a reservoir this
caused a logical-subscript length error; without a reservoir it silently
used prefix weights belonging to other pairs. The helper now selects
discordant pairs and orders their weights by pair completion, matching the
native design. It normalizes weights before fitting and restores the original
scale in the standard error.

`test-kk-logistic-discordant-weight-reference.R` passes 35 assertions against
independent weighted logistic likelihood, coefficient and Fisher-information
references: pair-only and reservoir designs, concordant pairs, reversed pair
IDs, omitted units, tiny scales, zero draws, and warm cache reuse. This fix
now passes against the rebuilt installed package (2026-09-18). Committed tests
contain no namespace replacement.


## Serial resume discarded simulation-mode metadata

Source: `R/EDI/R/simulations_framework.R`, `.load_existing_results()`,
and `R/EDI/R/simulation_framework_report.R`, `summarize()`.

The resume loader selected a fixed schema without `simulation_mode`. Combining
loaded and new rows introduced missing modes, lost disk/report agreement and
made summary null classification fail with `missing value where TRUE/FALSE
needed`. The schema now preserves the mode and infers it from the configured
framework when loading older files without that column. Summary classification
with an explicitly missing mode uses the legacy betaT rule.

The real serial custom-data regression checks CSV and compressed CSV resumes
that add CI methods and replications, against independent Welch estimates,
p-values and intervals. It also checks RNG restoration, disk agreement,
summary counts and complete resume deduplication. A legacy-schema regression
and 14 missing-mode summary assertions cover compatibility. These R-only
changes now pass against the rebuilt installed package (2026-09-18).

## Proportion g-computation stopped early under tiny weights

Source: `R/EDI/R/inference_proportion_gcomp.R`, `weighted_gcomp_fit()`.

The rebuilt baseline gives 0.180383 under ordinary weights but zero when
those weights are scaled by 1e-12 or 1e-200. The point-estimate-only weighted
logistic fit now normalizes valid weights before optimization. Independent
weighted GLM coefficients and standardization over the full original cohort
verify fitted treatment/control means, omitted subjects and zero-mass cache
clearing in 35 assertions. This fix now passes against the rebuilt installed
package (2026-09-18), without source-method substitution.


## Fixed Weibull parameters retained unrestricted covariance

Source: `R/EDI/src/fast_weibull_regression.cpp`, both standard right-censoring
and general left/interval-censoring fitting cores.

Both kernels inverted the entire observed information even when parameters
were fixed. In one fixture the reported intercept variance is 0.101847335;
the inverse free-parameter information block gives 0.046833218, and a fixed
coefficient incorrectly receives variance 0.192842. Sibling likelihood
kernels instead invert the free block and fill fixed covariance entries
with NA. Public constrained Weibull inference currently discards raw covariance,
so this correction affects the raw native result contract.

Both cores now use the existing free-block covariance and expansion helpers;
unrestricted covariance, full score and information outputs are retained.
`test-weibull-mixed-censoring-constrained-reference.R` has 54 assertions and
`test-weibull-right-censoring-fixed-covariance-reference.R` adds 36, using
independent Weibull likelihood and observed-Hessian references. The installed
pre-fix binary passes 79 and fails precisely 11 covariance assertions. The
user's rebuilt installed package (2026-09-18) passes all 90 assertions. No
compilation has been run by this team; the active regressions remain enabled.


## Constrained Cox cluster covariance contaminated free parameters with NA

Source: `R/EDI/src/fast_coxph_regression.cpp`, `compute_robust_vcov()`.

The model covariance already marks fixed parameters NA. Multiplying this full
matrix by the full cluster score covariance propagates those NA values into
otherwise estimable free standard errors. The helper now forms the sandwich
on the free block before expanding fixed entries to NA. The unrestricted
calculation, fitted coefficients, score and information remain unchanged.

`test-cox-cluster-constrained-sandwich-reference.R` derives individual Breslow
score contributions and sums them by independently specified clusters. The
current installed binary passes 56 assertions and reproduces 12 failures on
fixed-parameter covariance under both solvers. The later native source fix
has not been compiled by this team and requires the user's next rebuild.

## Simulation hook documentation misstated treatment encoding

The custom response-noise and estimand hooks receive `des_obj$get_w()` in
0/1 encoding. Roxygen and checked-in Rd documentation incorrectly described
-1/+1 encoding and an unnecessary conversion. Both now describe actual
callback behavior. A real serial heterogeneous-estimand/noise integration
checks passed assignments, extra replication fields, repeated response draws
and independent Welch estimates, p-values and intervals (56 assertions).


## Incidence g-computation tiny weights and reduced-fallback cache poisoning

Source: `R/EDI/R/inference_incidence_gcomp_abstract.R`, `weighted_gcomp_fit()`
and `weighted_gcomp_effects_from_row_weights()`; the latter method also in
`R/EDI/R/inference_proportion_gcomp.R`.

Actual incidence risk-difference fitting returns 0.2134636 under ordinary
weights but zero when scaled by 1e-12 or 1e-200. The shared point-estimate fit
now normalizes positive weights before calling the native optimizer.
An empty draw can additionally invoke a reduced-model fallback that overwrites
the shared column-reduction cache. Subsequent valid incidence and proportion
draws then omit their covariate. Scoped save/restore of that cache isolates
replicate-specific fallback choices without changing design data.

`test-incidence-gcomp-weighted-risk-difference-reference.R` checks actual
risk-difference and risk-ratio classes against independent weighted GLM
coefficients and standardization over the original cohort, including tiny
scales, omitted subjects, empty draws and valid-draw recovery. Its 91 assertions
and the expanded proportion file's 38 assertions pass through isolated
source-method substitution. These later R-only fixes are not yet installed.
The installed-only broad run reproduces precisely two newly added proportion
recovery failures, confirming the previously missed cache defect.

## TODO-1 triage candidates (2026-09-19, surfaced not fixed)

The first complete, provenance-bearing coverage run (73.57%, commit
`f72b8fdb`, see `full_test_coverage.md`) fed 58 newly-discovered sub-80%
files into `coverage_gap_registry.csv` triage. Per the plan's own non-goals
("if a gap investigation surfaces what looks like an actual bug... that
becomes its own separate plan/fix, not folded into this one"), the following
were noticed while classifying coverage, not fixed, and are unverified beyond
a source read + `grep` for callers. A maintainer should confirm each before
acting on it; see the registry CSV's per-file `notes` column for the full
reasoning.

- `inference_ordinal_KK_cond_logit_abstract.R`: `ordinal_cond_clogit_assert_finite_se()`
  (lines 35-39) appears to be a no-op -- both the finite and non-finite SE
  branches fall through to an identical implicit `NULL` return, with no
  `stop()`/warning/cache-nonestimable call, so the assertion it is named for
  never fires.
- `inference_mixin_kk_passthrough.R`: the entire "reused worker" bootstrap
  branch (`create_kk_bootstrap_worker_state`,
  `load_kk_bootstrap_sample_into_worker`,
  `compute_kk_bootstrap_worker_estimate`,
  `compute_kk_bootstrap_debug_with_reused_worker`,
  `compute_kk_bootstrap_distribution_with_reused_workers`, ~145 lines) is
  unreachable by construction: its only gate,
  `private$use_reusable_kk_bootstrap_worker()`, is hardcoded `FALSE` and is
  never overridden by any class in the codebase.
- `helper_matching.R`: `.init_kk_bootstrap_structure()`/
  `.draw_kk_bootstrap_indices()` (lines 174-210) have zero callers anywhere;
  the identical algorithm is independently implemented as private methods
  directly inside `design_matching_abstract.R` (lines 56-86, operating on
  `private$boot_*` instead of `des_priv$boot_*`), which is what every real
  caller actually uses. Looks like an orphaned duplicate from a refactor.
- `inference_incidence_KK_combined.R`: `InferenceAbstractKKCondLogitGLMMOneLik`
  has zero concrete subclasses anywhere (`grep` for
  `inherit = InferenceAbstractKKCondLogitGLMMOneLik` finds none). Easily
  confused by name with the real, heavily-tested
  `InferenceIncidKKCondLogitGLMMOneLik` (no "Abstract"), defined in a
  different file and inheriting from a different abstract class. Looks like
  orphaned refactor scaffolding.
- `helper_package_checks.R`: `print_progress()` looks dead -- every other
  module calls `utils::setTxtProgressBar()` inline instead; its only caller
  anywhere is a direct unit test with `pb=NULL`.
- `inference_all_abstract_KK_passthrough_compound.R`: 0% coverage traced to
  being structural, not merely undertested -- every real concrete class
  overrides both `initialize()` and
  `compute_estimate_with_bootstrap_weights()`, fully shadowing this base's
  methods. Candidate for a documented `covr` exclusion rather than a test;
  kept only for migration golden-test generators and as an inherit target.

### Coverage-measurement discrepancies (resolved 2026-09-19 -- not source gaps)

Three files were initially left `unclassified` rather than guessed. Spot-checks
resolved all three the same way: **the code is exercised by existing tests;
the coverage measurement is wrong.** These are candidate defects in the
coverage pipeline itself, not test-writing backlog items, and each registry
row is now `excluded` with a note saying so (no new tests needed).

- `inference_incidence_gcomp_abstract.R` (0.15% measured) and
  `inference_incidence_KK_gcomp_abstract.R` (0.17% measured) are "harvest
  source" files whose R6 class methods are extracted at file scope via
  `inference_component_source_parts()` and composed into concrete classes
  (`define_inference_class()`) -- closure composition, not plain R6
  inheritance. A first attempt to detect execution by monkey-patching
  `gen$public_methods` (on both the abstract and the concrete generators)
  reported no hits at all; that turned out to be a false negative from the
  method (R6 does not re-read the exposed `public_methods` list when
  `$new()` runs), not evidence of dead code. The reliable check was a
  temporary `cat()` inserted at the top of `initialize()` and
  `compute_estimate()` in each source file, reloaded via
  `pkgload::load_all(compile = FALSE)`, run against four existing bulk test
  files, then reverted (`git diff` clean, files byte-identical to backups).
  Both methods fired dozens of times per file (non-KK: two test files; KK:
  two test files). So `covr::package_coverage()`'s line attribution back to
  these source files is broken for the harvested-composition pattern. The
  root cause of the mis-attribution is **not** determined here -- it needs a
  `covr` internals investigation.
- `local_machine_tuning_harness.R` (21.21% measured): a literal
  `covr::file_coverage()` against its dedicated bulk test file gives
  **98.99%** (98 of 99 coverable lines; only line 32 of
  `edi_tuning_default_seed()` is not hit), contradicting the merged 35-shard
  run on the same commit. A skip-condition explanation was checked and ruled
  out: the test has no `skip*()`/`Sys.getenv()` logic, the shard's
  `timings.csv` records status `complete`, and locally it runs 14 tests / 68
  passing assertions / 0 skipped. Cause of the discrepancy is unresolved.

Implication for the plan: the 73.57% aggregate (R code only; the report
contains no C++ files at all, see `full_test_coverage.md`) is probably an
**under**-estimate of R coverage. The two gcomp abstract files alone account for 1,265
coverable lines counted as ~0% (668 + 597 uncovered), and the harness file
another 78 uncovered lines that a direct check says are covered. Any other
file built on the same harvested-composition pattern may be similarly
under-counted. This is worth investigating before treating the remaining
sub-80% backlog as ground truth.

### Dead-code cleanup outcome (2026-09-19)

Each `dead_or_unreachable` candidate was checked against every release and feature
plan and every reference in the repo before any deletion.

- **Deleted** (no plan references; 430 lines removed; 521 assertions across 16
  wiring/registry/contract/migration/KK/ordinal test files pass with `compile = FALSE`):
  the KK "reused worker" bootstrap branch in `inference_mixin_kk_passthrough.R`;
  the orphaned `InferenceAbstractKKCondLogitGLMMOneLik` class (plus its man page and
  `_pkgdown.yml` entry); and `ordinal_cond_clogit_shared_univ` (plus its wrapper,
  contract entry and baseline-test expectation).
- **Kept**: `helper_matching.R`'s two functions, because
  `full_glmm_for_weibull_frailty.md` (release v1.4.0, TODO-5) names them (that plan
  looks stale and should point at `design_matching_abstract.R`);
  `inference_all_abstract_KK_passthrough_compound.R`, a deliberate hierarchy base;
  and `inference_count_composite_likelihood.R`, whose `stop()` stubs are guardrails.
- **Process note**: my first deletion pass wrongly removed
  `clear_kk_bootstrap_worker_design_caches`, which the live bootstrap path still
  calls (my reference search had excluded the file itself). It was caught before
  any test ran and restored.

### Candidates from the 2026-09-21 triage of newly measured files (not fixed, unverified beyond reading)

- `fast_probit_regression.cpp`: its own test header says `optimization_alg = "lbfgs"` gives
  non-deterministic coefficients and sometimes a NaN `neg_ll` with `converged = TRUE`, and that
  `min_eigenvalue_information` is NaN for the default IRLS fit. Worth confirming.
- `fast_zero_augmented_poisson.cpp` ~line 414: the documentation says the failure return has no
  other fields, but the code returns many.
- Dead-code candidates for a TODO-8 decision (no release plan references them):
  `compose_inference_mixins` and `EDI_LEGACY_MIXIN_COMPONENT_NAMES` (`contracts_mixins.R` 3752-3781); the
  5-argument overload at `rand_bootstrap_mean_diff_parallel.cpp` 119-127 (already documented as unused in
  `finished_features`); `simulation_dgp.cpp` lines 62 and 72 (unreachable because an earlier clamp maps
  NaN into range).
- C++ blocks with no R caller (only reachable from Python), which need exclusion decisions, not deletion:
  `robust_post_fit_speedups` 71-113, `fast_wilcox_hl` 325-339, `fast_zero_augmented_poisson` 316-353,
  `fast_survival_stats` 163-192.

### Follow-up verdicts (2026-09-21)

- **The four "reachable only from Python" C++ blocks are live, not dead.** `robust_post_fit_speedups.cpp`
  71-113 (`ols_hc2_post_fit_result`), `fast_wilcox_hl.cpp` 325-339 (`wilcox_hl_point_estimate_result`),
  `fast_zero_augmented_poisson.cpp` 316-353 (`fast_zap_with_var_internal`) and `fast_survival_stats.cpp`
  163-192 (`get_survival_stat_diff_result`) are called by the pybind11 package (`python/CMakeLists.txt` compiles
  the `R/EDI/src` files directly; bindings in `bindings_continuous/count/survival.cpp`) and each has a Python
  test. R never calls them, so they belong in a documented R-coverage exclusion (TODO-8), never deletion.
- **Dead code removed (user decision):** `compose_inference_mixins()` and `EDI_LEGACY_MIXIN_COMPONENT_NAMES`
  (`contracts_mixins.R`), the non-exported 5-argument overload in `rand_bootstrap_mean_diff_parallel.cpp`, two
  provably unreachable checks in `simulation_dgp.cpp`, and the duplicated `.init_kk_bootstrap_structure()` /
  `.draw_kk_bootstrap_indices()` in `helper_matching.R` (with their two tests; the v1.4.0 plan was repointed at
  the live methods in `design_matching_abstract.R`). C++ edits were syntax-checked only (`-fsyntax-only`) and take
  effect on the next rebuild. Possible follow-on orphans in `contracts_mixins.R`
  (`assert_valid_mixin_composition`, `EDI_MIXIN_ALLOWED_COLLISIONS/OVERRIDES`) were not checked.
- **Ordinal KK CLMM golden (peer reported 0.087 vs 0.0152): not reproducible.** All 13 `test-ordinal-kk-*` files
  pass (about 370 assertions) with `load_all(compile = FALSE)`; the numbers appear in no test file. The peer had
  tested a build installed at 20:20, older than the relinked `EDI.so` (20:38); most likely a stale binary. They
  should rerun it against current source to close it.
- **Zero-augmented-Poisson failed-fit docs are stale but harmless.** The roxygen (`fast_zero_augmented_poisson.cpp`
  ~416, repeated in `RcppExports.R` and the Rd) says a caught optimizer exception returns only
  `list(converged = FALSE, gradient_norm = NA)`; `failed_fit_result` actually returns a full diagnostic list
  (params, converged, num_iter, neg_ll, information/Hessian, gradient_norm, params_origin, exception_message). The
  seven R callers gate on `converged`, so nothing breaks. Fix: update the roxygen text and regenerate the docs.

