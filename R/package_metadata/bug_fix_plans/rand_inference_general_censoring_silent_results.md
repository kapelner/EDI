# Randomization Inference Under Left-/Interval-Censoring Returns Silent Wrong Results

> **Depends on:** none. Release: v1.0.5 (`../future_release_plans/release_v1_0_5.md →
> TODO-98`), user decision 2026-10-19. Found while preparing the HUJI seminar
> survival demo.

Date: 2026-10-19

## Problem

A nonzero-δ randomization null for survival data shifts the treated units'
times by `e^δ` (AFT sharp null). `shift_randomization_responses()`
(`R/EDI/R/inference_all_abstract_rand.R`) shifts only the plain `y` vector. A
left- or interval-censored subject has `y = NA`, and its value lives in `y_L` and `y_R`. So for every censored
row the shift is silently a no-op, and the "null-shifted" statistic mixes
shifted exact rows with unshifted censored rows.

Three paths produce a number instead of an error:

1. **The shared guard only runs with asserts on.** The stop in
   `setup_randomization_template_and_shifts()` (~L995–1004) sits inside
   `if (should_run_asserts() && delta != 0)`. With asserts off, the
   unshifted computation runs. `SimulationFramework` turns asserts off by
   default (`turn_off_asserts_for_speed = TRUE`), so any simulation study of
   left- or interval-censored survival data takes this path.
2. **Classes without their own guard.** Measured on the current source
   (`pkgload::load_all(compile = FALSE)`, 60 subjects: 55% exact, 25% right,
   10% left, 10% interval-censored), with asserts off:
   - `InferenceSurvivalCoxPHRegr$compute_rand_two_sided_pval(delta = 0.3)` returns 0.438 (delta = 3 returns 0.0100)
   - `InferenceSurvivalLogRank$compute_rand_two_sided_pval(delta = 0.3)` returns 0.408 (delta = 3 returns 0.975)

   Both should error. The other classes that accept general censoring
   (`supports_interval_or_left_censored_data()` is TRUE in
   `inference_survival_{coxph,gehan_wilcox,km_diff,log_rank,rmst,weibull}.R`)
   need the same check.
3. **The randomization CI swallows the guard.**
   `InferenceSurvivalWeibullRegr` has an always-on guard in its public
   `compute_rand_two_sided_pval()` (`inference_survival_weibull.R` ~L164),
   and it fires: `delta = 0.3` errors, with asserts on or off. But
   `compute_randomization_ci_pval_cached()`
   (`inference_all_abstract_rand_ci.R` ~L375–385) wraps each p-value call in
   `tryCatch(..., error = function(e) NA_real_)`. The CI search then
   returns a finite interval anyway: (-0.147, 0.749) on the data above,
   asserts on. That interval is built from NA p-values and is not a valid
   randomization CI. The installed EDI 1.0.3 behaves the same way: it
   returned (0.19, 0.92) on the seminar demo's interval-censored data.

Right-censored-only data are not affected the same way; check that while
fixing this. Cox and log-rank already refuse randomization CIs for
unit-mismatch reasons, independent of censoring.

A related silent failure: under left- or interval-censoring,
`InferenceSurvivalWeibullRegr$compute_lik_ratio_bootstrap_two_sided_pval()`
and `..._confidence_interval()` return `NA` with no message. The
Bartlett-approx sibling stops with a clear error for the same underlying
limitation (`simulate_param_boot_weibull_observed()` can only re-censor
against one right-censoring time).

## Fix (minimal, for v1.0.5)

The goal is errors instead of silent results. Supporting the shift for
censored rows is a separate feature; see "Later" below.

- [x] TODO-1: Make the δ ≠ 0 general-censoring stop in
  `setup_randomization_template_and_shifts()` always-on, not gated on
  `should_run_asserts()`. This covers every class at once, Cox and
  log-rank included.
- [x] TODO-2: In `compute_randomization_ci_pval_cached()`, stop treating
  every error as `NA`. Rethrow "not supported" errors, or check up front in
  `compute_rand_confidence_interval()` and refuse with the same message,
  so that no CI is ever built from NA p-values. Also audit what the CI search
  returns when most p-values are NA: it should fail loudly, not return a
  boundary interval.
- [x] TODO-3: Give the Weibull parametric-bootstrap LR p-value and CI the same
  explicit stop as the Bartlett-approx method under general censoring.
- [x] TODO-4: Regression tests with the fixture above (left- and
  interval-censored rows). Run them with asserts **off**: the CI and every
  δ ≠ 0 randomization p-value must error, and right-censored-only data must
  still work.
- [x] TODO-5: Document in the `compute_rand_confidence_interval()` and
  `compute_rand_two_sided_pval()` roxygen that δ ≠ 0 is unsupported under
  left- or interval-censoring.

**Implementation and validation, 2026-10-19:** the shared nonzero-δ guard is
unconditional; randomization-CI inversion rejects general censoring before
its error-to-NA search can run; and both Weibull parametric-bootstrap LR
entry points reject the unsupported censoring types. Roxygen documents the
randomization limitation. The focused regression now uses a 60-subject mixed
exact/right/left/interval-censored fixture, runs with assertions disabled,
checks the six general-censoring-capable survival classes, and retains
right-censored controls. `pkgload::load_all("R/EDI", compile = FALSE, quiet = TRUE)`
followed by
`testthat::test_file("R/package_tests/testthat_bulk/test-weibull-general-censoring-unsupported-operations-rejected-reference.R")`
passed all 24 assertions (0 failures, warnings, or skips). The loaded
`/tmp/Rtmp2hPjG6/pkgload2f2a21ca9ce0e/EDI.so` has MD5
`c07ee5a3a9d9b1909684dee3bb345cfe`, matching the installed EDI 1.0.3 native
library; this is sufficient for the R-only change, and no native source was
changed or compiled. Supporting censoring-bound shifts remains deferred.

## Later (not v1.0.5)

The AFT sharp-null shift extends naturally to intervals: multiply `y_L`
and `y_R` of treated rows by `e^δ`. `0` and `Inf` are fixed points, so left-
and right-censoring stay well-formed. Supporting this means threading
`y_L`/`y_R` through the template, worker, standard-iteration and parallel
paths in `inference_all_abstract_rand.R`. The user deferred this on
2026-10-19.
