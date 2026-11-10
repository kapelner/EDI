# Calibration convergence slopes vs the expected asymptotic rate

> **Release:** v1.0.5 TODO-199 (`future_release_plans/release_v1_0_5.md`).
> **Depends on:** TODO-193 (`inference_convergence_rate_registry.md`): the
> resolver `inference_convergence_expectation(design, class, procedure)` in
> `R/EDI/R/inference_procedure_regime.R` (expected `size_order`, `bias_order`,
> `n_eff` rule).
> **Consumer:** the published calibration study (`R/package_tests/calibration/`,
> `.github/workflows/calibration-study.yml`). Reported, not gated (owner
> 2026-11-10: gating is discussed after TODO-193).

Status: DONE 2026-11-10 (the owner's checkbox in release_v1_0_5.md TODO-199 stays open).

## What

For every cell of the published study whose procedure is asymptotic
(TODO-192 regime), across the sample sizes the campaign ran (n = 50, 200,
1000; fewer for the slow KK classes' power cells), estimate how fast the error
shrinks and compare it with the registry's expected order:

* size error: `size(n) - 0.05` (from `tests` stats: `rej`, `n_p`);
* coverage error: `0.95 - coverage(n)` (`cov`, `n_ci`), null and, where a true
  value exists, at each power effect;
* bias: `mean(beta_hat - truth)` (`est` stats: `sum_d`, `sum_d2`, `n_est`), null
  and non-null.

A cell here is (response type, design, prob_T, class, formula, procedure,
effect); its n varies. The x-axis is `log(n_eff)`, with n_eff from the
registry's rule (n, pairs, smaller arm, ...; the nominal n_eff at the
design's allocation, documented).

## Estimation (the owner asked for the log regression; do it, plus the noise-aware fit)

1. **Log-log regression (as asked).** Weighted least squares of
   `log|error(n)|` on `log(n_eff)`, weights from the delta-method variance of
   `log|error|`; slope = -a_hat. Report it, with its SE. Caveat it in the
   output: with 3 points and a Monte Carlo noise floor (1,000 reps give a size
   SE of about 0.007, while an O(1/n) excess at n = 1000 is about 0.001),
   `|error|` at large n is mostly noise, which biases the slope toward 0, and a
   sign change makes the log undefined.
2. **Binomial / normal power-law fit (primary).** Size: `rej ~ Binomial(n_p,
   0.05 + c * n_eff^-a)` (coverage likewise around 0.95; bias: normal with
   its SE, `bias(n) = c * n_eff^-b`), maximum likelihood over (c, a) with a
   profile-likelihood CI for a. Test the expected order: likelihood ratio of
   free a vs a fixed at the registry's `size_order` / `bias_order`.
3. **Verdict per cell and metric:** `consistent` (expected order in the CI),
   `slower` (CI entirely below the expected order: the warning case),
   `faster`, `undetermined` (the error is indistinguishable from 0 at every
   n, or fewer than 2 sizes with a measurable error), `not_applicable`
   (finite-sample procedure, or expected order `Inf` / `0` / `NA`; for an
   expected O(1) design-mismatch error, report the level instead), plus the
   registry `basis` so an "assumed_default" expectation is visible.

## Outputs

* New script `R/package_tests/calibration/convergence_calibration_study.R`
  (reads `stats/tests.csv.gz` + `stats/est.csv.gz`, sources the registry from
  the checkout like `analyze_calibration_study.R` does, base R + data.table
  only: the publish job has no EDI installed), writing
  `summary/convergence_summary.csv`: cell, metric, n values used, errors and
  their SEs, log-log slope + SE, power-law a_hat + CI, expected order, n_eff
  rule, basis, LR p-value, verdict.
* Figures (in `plot_calibration_study.R`, both sections): per response type,
  error vs n_eff on log-log axes for asymptotic cells, with the expected slope
  as a reference line; and a grid of verdicts (class x design, per procedure)
  like the overview grids.
* Campaign README (`render_calibration_study_readme.R`): a "Convergence"
  summary line (counts by verdict) and a short table of `slower` cells.
* Workflow: run it in the publish job whenever a campaign has at least two n
  values for some cell (interim, provisional) and at completion; it never
  fails the job.

## Tests

* Synthetic stats with known truth: size `0.05 + 2.5/n` at n = 50 / 200 / 1000
  with large n_p recovers a near 1 and verdict `consistent` vs expected 1;
  `0.05 + 0.3/sqrt(n)` gives `slower`; constant 0.05 gives `undetermined`;
  a finite-sample procedure gives `not_applicable`.
* Bias: `c/n` recovered; an unbiased cell gives `undetermined`.
* The script runs on the published wave tables of `2026-11-09-8c32d060`
  without error (n = 50 only so far, so everything is `undetermined`; say so).

## Constraints

* No change to the gate or its levels. No `.github/` change other than adding
  the step that runs the new script (keep it non-failing). R only; no build;
  `load_all(compile = FALSE)` only if the package is needed at all. Test file
  names carry no TODO number. NEWS is not needed (scripts outside the
  package), but update `calibration_gates.md` / `release_v1_2_0.md` TODO-36's
  notes with one line.

## Done

Implemented 2026-11-10. No gate, level, `analyze_calibration_study.R` or `inference_procedure_regime.R` change; no package build.

**What changed**

* `R/package_tests/calibration/convergence_calibration_study.R` (new; base R, sources the registry from the checkout, runs with no EDI): reads `stats/tests.csv.gz` + `stats/est.csv.gz` (screen stage), builds one point per cell x metric x effect x n (size and null / power-effect coverage from `tests`; bias from `est`, as procedure `(estimator)` resolved against the registry as `wald`), resolves `inference_convergence_expectation()` per (design label with `@prob_T=`, class, procedure), computes the nominal n_eff, and writes `convergence_summary.csv` (one row per cell x metric x effect: n values, n_eff values, errors, SEs, number measurable, log-log slope + SE + `loglog_a`, a_hat + 95% profile CI, error at the smallest n_eff, LR statistic / p, expected order, basis, regularity, n_eff rule and flag, verdict, note, `provisional`), `convergence_points.csv` (the points, joined by `cell_id`) and `convergence_summary.md` (verdict counts, the Monte Carlo noise caveat, table of `slower` cells). Exits 0 even if it errors (reported, never gated).
* `plot_calibration_study.R`: in both sections, per response type, `convergence[-nonnull]-<rt>.png` (|error| vs n_eff, log-log, Bernoulli design, `~ .`, asymptotic cells with at least 2 sizes, coloured by verdict, expected slopes as reference lines, open circles for negative errors) and `convergence-grid[-nonnull]-<rt>.png` (class x design verdict grid, one panel per procedure plus one for the estimator's bias). Skipped when `convergence_summary.csv` is absent; the line figure is skipped until some cell has two sizes.
* `render_calibration_study_readme.R`: includes `convergence_summary.md` (counts by verdict, table of `slower` cells) plus links to the two CSVs after the Summary section.
* `.github/workflows/calibration-study.yml`: one publish-job step, `continue-on-error: true`, before the analyze / plot / README step (`--final` at completion). `actionlint` clean.
* Tests: `R/package_tests/testthat_bulk/test-calibration-convergence-slopes.R`.
* One-line notes in `calibration_gates.md` and `release_v1_2_0.md` TODO-36.

**Estimation details**

* Noise-aware fit: size `rej ~ Binomial(n_p, 0.05 + d (n_eff / n_ref)^-a)`, coverage likewise around 0.95 (reported error `0.95 - cov` = `-d`), bias normal with its SE; ML over (d, a), a in [0, 5], d unconstrained in sign (conservative size / over-coverage allowed); profile CI by `uniroot` on a 0.1 grid; LR test (1 df) of free a vs the registry order. `consistent` = LR p >= 0.05; `slower` / `faster` = rejected with a_hat below / above the expected order.
* `undetermined` when fewer than 2 sizes ran or fewer than 2 have |error| >= 2 Monte Carlo SE (SE of the error under zero error: `sqrt(0.05 * 0.95 / n_p)`, the bias's own SE). `not_applicable` for finite-sample procedures, expected order Inf (bias of the difference-in-means classes), expected order 0 (design mismatch: the level is `err_largest_n`, with a note) and an unknown (NA) registry order (the fit is still reported).
* Log-log: WLS of `log|error|` on `log n_eff` with delta-method weights `(err / se)^2` (se from the continuity-corrected observed proportion), fixed-weight slope SE (exists with 2 points), points with error exactly 0 dropped, `loglog_sign_change` flagged. Reported next to the verdict, never the verdict.

**n_eff and its limits (stats do not carry the data-dependent counts)**

* `n` -> n; `n_pairs` -> n/2; `n_min_arm` -> n * min(prob_T, 1 - prob_T); `n_pairs_plus_reservoir` -> n/2 (a lower bound, flag "nominal (pairs only: lower bound)"); `n_events`, `n_nonzero`, `n_clusters`, `n_strata` -> n with flag `proxy_n`. Every rule is proportional to n, so the slope in n_eff equals the slope in n; for `proxy_n` rows the true count may scale differently (events with the censoring rate, non-zeros with the zero-inflation).
* The x of a cell is `n_nominal` (pair-switching's n = 52 counts as 50), screen replicates only (confirmation replicates are not pooled).

**Smoke run on the published campaign** (`2026-11-09-8c32d060`, n = 50 only, 31 s): 6,107 cell-metrics, 0 consistent / 0 slower / 0 faster, 5,053 undetermined, 1,054 not_applicable; 0 cells at two sizes, and the output says so. Figures: only the all-undetermined verdict grids are drawn (12 files). To see the full output a synthetic three-size table was derived from the published cells (scratch only, not committed): size / coverage errors scaled by (50 / n)^a with a = 1, and a = 0.5 for `score`; it recovers `slower` for `score` and `consistent` for most others; the line and grid figures were rendered and inspected.

**Tests** (from the repo root, `testthat::test_file(..., reporter = "silent")`): `test-calibration-convergence-slopes.R` 8 tests, 70 expectations, 0 failed (with `EDI_CAL_PUBLISHED_STATS_DIR` pointing at the published stats the last test runs the script on it; otherwise it skips). `test-calibration-gate-regime-levels.R` still 5 tests, 17 expectations pass. Covered: `0.05 + 2.5/n` -> a ~ 1, `consistent`; `0.05 + 0.3/sqrt(n)` -> `slower`; constant 0.05 -> `undetermined`; `rand` -> `not_applicable`; coverage `0.95 - 2.5/n`; `@prob_T=0.2` -> `n_min_arm`, n_eff 10 / 40 / 200; bias `2/n` -> `consistent`, unbiased -> `undetermined`, difference-in-means bias -> `not_applicable`; single n; empty stats; `--final`.

**Deviations / notes**

* The script always runs in the publish job (not only "when some cell has two n"): it is cheap (about 30 s on a full campaign), and single-n cells come out `undetermined`, so early waves carry a provisional file saying so.
* Extra output `convergence_points.csv` (the figures need the points) and `convergence_summary.md` (README section); `bias` rows use procedure `(estimator)`.
* The figure cut is Bernoulli / `~ .` like the existing dot plots; every other cell is in the CSV and the verdict grid.
* Ordering of the "worst verdict" in the grids (slower > faster > consistent > undetermined > not applicable) is my choice.
* With three sizes the profile CI is wide (the fit has 2 parameters on 3 points): `consistent` often means "cannot reject", not "confirms"; read it with `n_measurable`, `a_ci_lo` / `a_ci_hi`.
