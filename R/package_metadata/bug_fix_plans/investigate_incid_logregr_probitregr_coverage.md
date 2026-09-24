# Investigate: `InferenceIncidLogRegr`/`InferenceIncidProbitRegr` — Broad Mild CI Over-Coverage

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class fork
> triaging the 650 new `audit_comprehensive_results.R` findings surfaced
> after this session's `prune_stale_result_rows.R --apply` run. **Medium
> confidence lean toward "likely benign finite-sample conservativeness,
> not a bug"** — evidence and reasoning below; not fully resolved.

## The finding

Both `InferenceIncidLogRegr` (21 new `low_coverage` + 2 `biased_estimate`
findings) and `InferenceIncidProbitRegr` (21 new `low_coverage` findings)
show **broad, mild, uniform OVER-coverage**: actual coverage 0.97–0.998
against the 0.95 target, across **nearly every `function_run` family**
(`asymp`, `wald`, `score`, `gradient`, `lik_ratio`, `bayesian_bootstrap*`,
`bootstrap*`, `subsampling`, `m_out_of_n_bootstrap`, `param_bootstrap`),
for **both `~1` and `~.` formulas**, for **both classes**. Magnitude is
mild (2-5 points over target), not the severe (≥20pt) miscalibration
this session's other findings (e.g. `TODO-28`) show.

**One exception, opposite direction:** `InferenceIncidProbitRegr`,
`~1`, `compute_jackknife_wald_confidence_interval` — coverage **0.926,
UNDER** target (n=772, p=3.75e-03). Stands out against everything else
in this cluster being over. Not investigated further here; may echo
`TODO-29`'s independent `jackknife_wald` SE-quality finding for
`InferenceAllSimpleAverageDiff` (a different class, but the same
`function_run` family flagged there too) — worth checking whether
`jackknife_wald`'s SE computation is shared/similar machinery across
classes.

## Ruled out: `TODO-28` (`cached_design_matrix` staleness)

Not applicable — `asymp`/`wald`/`score`/`gradient` are purely asymptotic,
no resampling worker involved at all, and they show the identical
over-coverage pattern as the bootstrap-family methods. A resampling-cache
bug cannot explain findings on non-resampling methods. Not investigated
further at the code level (the breadth of the pattern across
resampling-free methods is sufficient to rule this bug family out).

## Two candidate explanations, not yet distinguished

### (A) Non-collapsibility / truth-definition mismatch for `InferenceIncidLogRegr` specifically

`InferenceIncidLogRegr`'s documented generative model
(`inference_incidence_logit.R`'s class docstring) is the **conditional**
`logit(P(Y_i=1)) = beta_0 + beta_T*W_i + X_i'gamma` — i.e.
`compute_estimate()` targets the individual-level (conditional) log-odds
coefficient `beta_T` directly, no sign flip.

But the audit's truth for this class
(`COVERAGE_CLOSED_FORM[["InferenceIncidLogRegr"]]` →
`compute_incid_logit_coverage_truth()`, `comprehensive_tests.R:3176-3179`)
computes a **different quantity**: `qlogis(mean(p_t)) - qlogis(mean(p_c))`
— the difference of the logits of the *population-average* probabilities.
Under this harness's incidence DGP (`incid_p_base_and_treated()`,
`:3170-3174`), individual baseline risk `p_base` is heterogeneous
(drawn from the real dataset's own outcome column) while the per-subject
logit shift `beta_T_val` is applied uniformly — the textbook setup where
the **marginal** log-odds-ratio contrast (what the closed-form truth
computes) is attenuated toward 0 relative to the **conditional**
log-odds-ratio (what the fitted model targets), a classic non-collapsibility
gap. This is the same class of bug this session already tracks in
`fix_mc_coverage_truth_covariate_mismatch.md` (`TODO-1..7`, most recently
extended for `InferenceSurvivalKMDiff`'s analogous truth-scale mismatch).

If real, this predicts the CI (correctly centered near the true
conditional `beta_T`) would systematically miss a truth defined on a
different, attenuated scale — but a truth/estimand mismatch more
naturally predicts **under**-coverage (missing a moving/offset target),
not the over-coverage actually observed. This tension is not resolved;
either the direction of the attenuation happens to still fall inside
typical CI widths more than 95% of the time (plausible for a mild
mismatch with wide CIs), or this mechanism is not the actual explanation.

### (B) Genuine finite-sample conservativeness of logistic/probit CI methods (more likely primary driver)

`InferenceIncidProbitRegr` is **not** in `COVERAGE_CLOSED_FORM` — it uses
the Monte-Carlo-refit truth (`compute_mc_coverage_truth_simframe()`),
which estimates the truth by refitting the *actual* estimator at large
MC sample size, and should NOT suffer explanation (A)'s closed-form
marginal/conditional mismatch. **`InferenceIncidProbitRegr` shows the
same magnitude and breadth of over-coverage as `InferenceIncidLogRegr`.**
This is fairly strong evidence that explanation (A) is not the primary
(or sole) driver — a truth-definition artifact specific to the
closed-form logit truth would not be expected to reproduce this cleanly
in a class using a completely different (simulation-based) truth
mechanism.

The more likely shared explanation: **known finite-sample conservativeness
of Wald/score/LR-type confidence intervals for binary-outcome GLMs**
(logistic/probit) is a well-documented statistical phenomenon,
especially away from very large `n` or with real, non-i.i.d.-Gaussian
covariate structure (this harness recycles real dataset covariates/base
rates, not synthetic well-behaved ones). If so, this is **not a bug** —
it is expected conservativeness, similar in spirit to this session's
earlier "not a bug" closure for the `IncidGCompRiskDiff`/`RiskRatio`
`low_power`/exact-test conservativeness cluster.

## Separate, smaller finding: `biased_estimate` for `InferenceIncidLogRegr` (`~.` only)

`compute_estimate` (mean bias +0.0325, ACAT p=1.35e-02) and
`compute_jackknife_estimate` (mean bias +0.0599, ACAT p=2.80e-03), both
`~.` only (not `~1`). Plausibly ordinary finite-sample first-order MLE
bias of logistic regression under covariate adjustment (well-documented,
worsens with more covariates relative to effective sample size,
uncorrected here — no Firth/bias-reduction applied) — likely benign, but
not confirmed against this specific harness's covariate count/n ratio.

## TODOs

- [ ] TODO-1: Distinguish explanation (A) vs (B) directly: run a
  synthetic simulation with a HOMOGENEOUS baseline risk (constant
  `p_base`, removing the non-collapsibility gap of explanation A) through
  the same `InferenceIncidLogRegr`/`asymp`/`wald` pipeline. If
  over-coverage vanishes, (A) (or something correlated with
  heterogeneous `p_base`) is implicated after all; if it persists, (B)
  (benign conservativeness) is confirmed and this can likely be closed as
  not-a-bug, matching the RiskDiff/RiskRatio precedent.
- [ ] TODO-2: If (B) is confirmed, close this as "not a bug, documented
  finite-sample conservativeness" and add a note to
  `audit_comprehensive_results.R`'s baseline acceptance (or a
  known-conservative-methods allowlist, if one gets built) rather than
  leaving 42 individual findings unexplained forever.
- [ ] TODO-3: Investigate `InferenceIncidProbitRegr`'s lone
  `jackknife_wald` UNDER-coverage outlier (`~1`, 0.926) separately — check
  whether its SE computation shares machinery with
  `InferenceAllSimpleAverageDiff`'s `TODO-29` `jackknife_wald` finding.
- [ ] TODO-4: If (A) is confirmed relevant (even partially), cross-link
  this finding into `fix_mc_coverage_truth_covariate_mismatch.md` as a
  new TODO for `InferenceIncidLogRegr`'s closed-form truth definition —
  do not duplicate that plan's tracking structure here.
- [ ] TODO-5: Investigate the `biased_estimate` finding for
  `InferenceIncidLogRegr ~.` (`compute_estimate`/`compute_jackknife_estimate`)
  — confirm or refute ordinary uncorrected finite-sample MLE bias as the
  explanation (e.g. by checking bias magnitude scales with
  covariate-count/n ratio as textbook theory predicts).

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build.
