# Investigate: `InferenceAllSimpleAverageDiff` — `bayesian_bootstrap_studentized`/`jackknife_wald` SE Quality

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class
> investigation fork chasing the audit's remaining `low_coverage`/
> `biased_estimate` cells. **Not the `TODO-28` (`cached_design_matrix`
> staleness) bug** — `InferenceAllSimpleAverageDiff` does not build or
> cache a design matrix at all in this path; confirmed a different
> mechanism entirely. Medium-low confidence — pattern is real and
> response-type-independent, but the proposed mechanism is a hypothesis,
> not yet confirmed.

## The finding

`InferenceAllSimpleAverageDiff`'s `low_coverage`/related audit flags are
**response-type-independent**: the `bayesian_bootstrap_studentized` and
`jackknife_wald` `function_run` families are consistently the worst-
performing across all 5 response types this class supports, while other
families (plain `bayesian_bootstrap`, `rand`, `non_param_boot`, etc.) are
comparatively fine. This shape argues for a mechanism specific to those
two families' SE computation, not a per-response-type data issue.

## Candidate mechanism (unconfirmed)

For the weighted-bootstrap path, a Kish effective-sample-size
approximation (`n_eff = sum(w)^2 / sum(w^2)`) may be used somewhere in
computing the studentized/Welch SE, in a way that's asymmetric with the
raw-`n` Welch formula used elsewhere in the same class — this was flagged
as a plausible source of SE bias but **not traced to an exact line or
confirmed against the class's actual source**.

`jackknife_wald`'s involvement is **entirely unexplained** — no candidate
mechanism was proposed for it; it may share a root cause with the
Bayesian-bootstrap-studentized finding, or may be an unrelated,
coincidentally-co-occurring bug.

## TODOs

- [ ] TODO-1: Read `InferenceAllSimpleAverageDiff`'s actual source
  (`R/EDI/R/inference_all_simple_average_diff.R` or wherever it lives —
  not yet located/read this session) and pin down exactly how
  `bayesian_bootstrap_studentized`'s SE is computed; confirm or refute
  the Kish-effective-n-vs-raw-n-Welch asymmetry hypothesis against the
  real code.
- [ ] TODO-2: Separately investigate `jackknife_wald`'s SE computation
  for this class — currently zero hypothesis, needs a first pass.
- [ ] TODO-3: Determine whether the two families' issues share one root
  cause or are two independent bugs that happen to co-occur in the audit
  output.
- [ ] TODO-4: Once a mechanism is confirmed, add to `release_v1_0_5.md`
  with an assigned TODO number and appropriate confidence label.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only.
