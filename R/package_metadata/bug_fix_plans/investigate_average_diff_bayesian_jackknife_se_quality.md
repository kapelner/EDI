# Fix: `InferenceAllSimpleAverageDiff` Bayesian-Bootstrap Studentization; Jackknife-Wald Finding Separately Closed

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's remaining `low_coverage`/
> `biased_estimate` cells. **Not the `TODO-28` (`cached_design_matrix`
> staleness) bug** — `InferenceAllSimpleAverageDiff` does not build or
> cache a design matrix at all in this path; confirmed a different
> mechanism entirely. Investigated and resolved 2026-10-08.

## The finding

`InferenceAllSimpleAverageDiff`'s `low_coverage`/related audit flags are
**response-type-independent**: the `bayesian_bootstrap_studentized` and
`jackknife_wald` `function_run` families are consistently the worst-
performing across all 5 response types this class supports, while other
families (plain `bayesian_bootstrap`, `rand`, `non_param_boot`, etc.) are
comparatively fine. This shape argues for a mechanism specific to those
two families' SE computation, not a per-response-type data issue.

## Root cause and fix

For the weighted-bootstrap path, the candidate was correct. The shared
`SimpleMeanDifference` component used
`n_eff = sum(w)^2 / sum(w^2)` in each Bayesian-bootstrap replicate. Kish
effective size is appropriate for unequal survey weights, but these Dirichlet
weights are frequency weights normalized to the resample size. Applying Kish
there counted their unequal weighting a second time: replicate standard errors
were about `sqrt(2)` too large, so bootstrap-t pivots were too small and the
resulting intervals too narrow.

The weighted Welch calculation now uses total arm weight `W = sum(w)` and
weighted residual sum of squares `Q`, contributing `Q / [W(W - 1)]` to the
variance of each arm mean. Satterthwaite-Welch degrees of freedom likewise use
`W - 1`. Unit weights reduce exactly to the ordinary Welch formula. A
1,000-dataset independent normal-null simulation at `B = 501` gave the old
Kish formula coverage of 0.820--0.840 for `n = 40, 100, 150`; the corrected
frequency formula gave 0.944--0.953. A separate 300-dataset run through the
actual source-loaded class at `n = 60`, `B = 199` covered 0 in 0.960 of runs,
with all 300 intervals finite.

The `jackknife_wald` finding is independent. That path never calls the weighted
refit or the corrected SE. It uses the package-wide delete-one jackknife
variance and the documented normal Wald critical value. A hand calculation
now pins both formulas. For a balanced two-arm mean difference, its SE is a
small finite-sample inflation over Welch (at total `n = 10`, exactly
`sqrt(9/8)`); normal-null simulations gave coverage 0.928, 0.942, 0.945, 0.948,
and 0.949 at total `n = 10, 20, 40, 60, 150`. Replacing the documented Wald
normal critical value with a t critical value would be a package-wide method
change, not a class-specific bug fix. The audit's jackknife rows are therefore
ordinary small-sample Wald approximation behavior and are closed without a
source change.

## TODOs

- [x] TODO-1: Read `InferenceAllSimpleAverageDiff`'s actual source
  (`R/EDI/R/inference_all_simple_average_diff.R` or wherever it lives —
  not yet located/read this session) and pin down exactly how
  `bayesian_bootstrap_studentized`'s SE is computed; confirm or refute
  the Kish-effective-n-vs-raw-n-Welch asymmetry hypothesis against the
  real code.
- [x] TODO-2: Separately investigate `jackknife_wald`'s SE computation
  for this class — currently zero hypothesis, needs a first pass.
- [x] TODO-3: Determine whether the two families' issues share one root
  cause or are two independent bugs that happen to co-occur in the audit
  output.
- [x] TODO-4: Once a mechanism is confirmed, add to `release_v1_0_5.md`
  with an assigned TODO number and appropriate confidence label.

The work was already assigned release TODO-29; the release owner will update
the shared checklist to avoid concurrent metadata conflicts.

## Validation

The regression suite independently computes the corrected weighted estimate,
SE, and degrees of freedom; verifies unit-weight equivalence and dispatch by
the other classes composing `SimpleMeanDifference`; and pins the jackknife
delete-one SE and Wald interval by hand. Using
`pkgload::load_all("R/EDI", compile = FALSE)`, 163 focused expectations passed
with no failures, errors, or warnings; one CRAN-only parallel test skipped as
expected. No compilation, build, or installation was performed.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
