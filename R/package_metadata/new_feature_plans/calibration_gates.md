# Calibration gates: pre-push check + scheduled CI fast tier

Status: pre-push check and CI fast tier BUILT 2026-10-26. Resampling tier and
automatic issue creation NOT built (see "Later").

## Why

Code coverage is gated (floor + Codecov patch); statistical validity was not.
`SimulationFrameworkReport`, `comprehensive_tests.R` and `check_anomalies.R`
measure size and coverage, but nothing gates on them, and the comprehensive
results pool real datasets whose truth comes from `coverage_truth`, so they
cannot tell a bug from misspecification. Past bugs this would have caught: the
Cloglog 60% Type-I error, the zero-width quantile rand CI, the rand/BRT CI at
alpha/2.

## Shared simulation (`R/package_tests/calibration/calibration_fast_tier_common.R`)

* Synthetic data, p = 2 (x1 ~ N(0,1), x2 ~ Bernoulli(0.5)); y from the response
  family's own model (normal, logistic, beta, Poisson, cumulative-logit latent,
  Weibull PH + independent exponential censoring).
* **Treatment is assigned before y and y depends on w only through `effect`.**
  With effect = 0 the sharp null holds, so every estimand of every class sits at
  the class's own null value (`private$default_null_value()`, else 0). No
  per-class truth is needed.
* Cheapest compatible design per class: iid classes under
  `DesignFixedBernoulli`; matched-pair-only classes under `DesignFixedBinaryMatch`.
* Fast analytic procedures only: wald, score, lik_ratio, gradient, at `~ 1` and
  `~ .`. Jackknife is excluded (refits n times; ~150 of 160 s of an ordinal
  replicate at n = 200).
* Fixed seeds per (response type, n, replicate, effect).

## Pre-push (`prepush_calibration_checks.R`, wired into `scripts/pre-push`)

Owner decisions: only classes the push touched; n = 200, p = 2; cheapest
design; **no size or coverage** (left to CI); failures block the push; the
endpoint check is included.

Per touched class: 3 null replicates + 1 large-effect replicate.

* **agreement** -- null replicates: "CI excludes null" must equal "p < 0.05"
  (ignored within 0.002 of alpha).
* **endpoint** -- the class's own test at each CI endpoint must give p in
  [0.035, 0.07]. Catches an interval built at the wrong level or not inverted
  from its own test, in one replicate. Only for p-value methods taking `delta`.
* **sign** -- large-effect replicate (`CAL_SIGN_EFFECT`): estimate on the
  expected side of the null (`CAL_DOWNWARD_ESTIMANDS` lists the estimands that
  go down when treatment lengthens survival: log hazard ratio, Gehan, log-rank)
  and CI excludes the null.

Touched = classes defined in a changed `R/EDI/R` file, classes composing a
component whose registry `file` changed (through dependencies), classes whose
defining/component files mention a top-level name or `[[Rcpp::export]]` kernel
defined in a changed file, plus all descendants. A changed header selects all
classes. `EDI_PREPUSH_CALIBRATION=skip|all`. `InferenceCountKKGLMM` is excluded
(~190 s per replicate).

Known failures: `prepush_calibration_known_failures.csv` (my call -- the owner
did not rule on it). Listed failures are reported, not blocking; a listed
failure that no longer reproduces on a checked class blocks until its row is
deleted. Seeded 2026-10-26 by running every class (`--all
--write-known-failures`, ~5 min): 22 rows, see "Findings".

## CI fast tier (`.github/workflows/calibration-fast-tier.yml`)

Owner decisions: scheduled monitor, never a required check; red runs are
triaged by hand; first version opens no issues; exact one-sided binomial tests
of size > 5% and coverage < 95% (anti-conservative only), Bonferroni
0.01 / K with K = number of size tests + number of coverage tests; a cell
accepted as honest small-sample behaviour reopens when it gets materially
worse than the accepted level.

* Nightly n = 50 and 200 (20 shards); Saturdays n = 1000 (39 shards);
  `workflow_dispatch` takes ns / reps / groups. 1000 null replicates per cell.
* `plan_calibration_fast_tier.R` sizes shards from
  `calibration_fast_tier_timings.csv` (single-core seconds per replicate;
  conservative estimates -- each shard writes its real `timing.csv`, use those
  to tighten the table). `InferenceCountKKGLMM` is its own group.
* EDI is built once and shared with the shards (as in test-bulk-non-cran.yml).
* `analyze_calibration_fast_tier.R` merges shards, tests every cell with >= 30
  finite results, writes `calibration_summary.csv` + a job-summary table, exits
  1 on any failure. Size at alpha = 0.10 and yield (< 80% finite) are reported,
  not gated.
* Accepted deviations: `calibration_fast_tier_accepted.csv` (response_type,
  design, inference_class, method, formula, n, metric, accepted_level, reason).
  The cell is then tested against `accepted_level` instead of 0.05 / 0.95, with
  the same test and 0.01 / K -- so it goes red again only when significantly
  worse. Starts empty.

## Findings at build time (2026-10-26)

Null baseline, n = 200, 300 replicates (`~ .` only), Bonferroni K = 429:

* `InferenceContinKKGLMM` score `~.`: size 0.213, coverage 0.813; score CI ~20%
  narrower than wald/LR/gradient from the same fit. Endpoint p 0.007.
* `InferenceIncidExtendedRobins` wald on matched pairs: size 0.140, coverage
  0.860 (CI and test agree -- the SE itself is too small; CI-only finding).
* `InferenceCountZeroInflatedNegBin` lik_ratio `~.`: coverage 0.803 while its
  test has size 0.079 -- CI not inverted from the test.

Pre-push checks over all classes (known-failures list):

* `InferenceBaiAdjustedTKK14/21` wald: p at both CI endpoints equals p at 0 --
  the test ignores `delta`.
* `InferenceAllSimpleWilcox` wald (every response type): endpoint p far from
  0.05 -- the HL interval is not the inversion of the test it reports.
* `InferenceContinKKGLMM` lik_ratio `~1`, `InferenceIncidKKCondLogitGLMMOneLik`
  lik_ratio, `InferenceCountZeroInflatedPoisson` lik_ratio `~1` (p = 0.89 with a
  CI excluding 0) and score `~.`, `InferenceOrdinalStereotypeLogitRegr` score:
  agreement/endpoint failures.
* `InferenceCountKKGLMM` lik_ratio p equals its wald p exactly on every replicate
  (LR likely falls back to Wald) -- not a calibration failure, worth a look.
* Harness "gross failures" that did NOT reproduce on synthetic data:
  CountKKGLMM size 0.50 (synthetic 0.067), KK LWA/stratified Cox, KKCLMMCloglog,
  KKQuantileRegr, pooled-variance mean diff, RMST diff, OLS/Lin.

## Later

* Resampling tier (bootstrap, randomization, param bootstrap, Bartlett,
  jackknife): B x the cost per replicate; needs a rotation (slice per night,
  full coverage weekly/monthly) and per-procedure timing first.
* Coverage at a nonzero effect (needs a committed per-class Monte Carlo truth
  table).
* Automatic GitHub issues per failing cell (stable marker, update in place,
  auto-close after two clean runs).
* Low-yield policy (fail a cell under ~80% finite?) -- owner to decide.
