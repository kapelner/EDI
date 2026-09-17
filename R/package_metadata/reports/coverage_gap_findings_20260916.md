# Findings from the coverage test audit (2026-09-16)

These findings are separate from the test-only coverage work. No production
behavior was changed, and the new bulk tests do not encode the defects as
expected behavior. Validation used already-installed EDI 1.0.1.

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
