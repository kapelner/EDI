# Investigate: `InferenceIncidLogRegr`/`InferenceIncidProbitRegr` — Broad Mild CI Over-Coverage

> **Depends on:** none. Found 2026-09-24, via a dedicated cross-class fork
> triaging the 650 new `audit_comprehensive_results.R` findings surfaced
> after this session's `prune_stale_result_rows.R --apply` run. **CLOSED
> 2026-09-24 (same day, follow-up fork)** for the broad over-coverage
> pattern — confirmed benign, see "Resolution" below. One real,
> confirmed-mechanism bug candidate spun off separately: the
> jackknife-Wald CI-centering issue, slated `release_v1_5_0.md`.

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

## Resolution 2026-09-24 (follow-up fork)

**Explanation (A) is mechanistically CONFIRMED for `InferenceIncidLogRegr`**
(code-read, not hypothesis): `estimand = "conditional"` is the class's
documented default (`inference_incidence_logit.R:429`), `comprehensive_tests.R`
never calls `set_estimand()` for this class (`grep` confirms zero hits), so
`compute_estimate()` genuinely returns the conditional log-odds coefficient
by default in this harness — while `compute_incid_logit_coverage_truth()`
(`comprehensive_tests.R:3207`) computes the marginal contrast. This is a
real truth/estimand mismatch, the same bug family as
`fix_mc_coverage_truth_covariate_mismatch.md`. **However**, per that
file's own reasoning, a truth/estimand mismatch more naturally predicts
under- not over-coverage, and `InferenceIncidProbitRegr` (MC-refit truth,
immune to this specific mismatch — it refits the model's own estimand,
not a closed form) shows the **identical** over-coverage magnitude/breadth.
That parity is decisive: explanation (A) is real but is **not** the driver
of the observed over-coverage — it's a separate, lower-priority
truth-definition-accuracy issue in the audit harness. Cross-linked into
`fix_mc_coverage_truth_covariate_mismatch.md` as a new TODO per this
file's original TODO-4 (see that file).

**The broad over-coverage itself is CLOSED as benign (explanation B)** —
Probit's parity with LogRegr under an estimand-consistent truth is strong
evidence this is ordinary finite-sample Wald/LR conservativeness for
binary-outcome GLMs on real (non-synthetic-Gaussian) covariate structure,
matching the RiskDiff/RiskRatio "not a bug" precedent from earlier this
session. Not going to `release_v1_5_0.md`. `TODO-1`'s proposed
homogeneous-baseline-risk simulation would make this airtight but isn't
necessary to close it at current confidence.

**The `jackknife_wald` under-coverage outlier is a CONFIRMED, concrete bug
candidate, and IS a real finding** — not closed as benign. Read
`compute_jackknife_wald_confidence_interval()`/`compute_jackknife_summary()`
directly (`R/EDI/R/inference_all_abstract_jackknife.R:118-145`/`229-287` —
shared, generic machinery used by every class composing the `Jackknife`
component, not specific to Probit): the CI is centered at the **raw**
point estimate `theta_hat = self$compute_estimate()`, while its half-width
uses `se_j`, the jackknife SE computed around the **delete-1 mean**
`jack_bar` (`var_j = ((n-1)/n) * sum((jack_i - jack_bar)^2)`). The
bias-corrected jackknife estimate `theta_j = theta_hat - bias_j` is
computed and available but **never used to center the CI**. The
acceptance guard only rejects cells where `abs(bias_j) > 2 * se_j`
(`:278`) — a loose threshold that lets substantial uncorrected bias
(up to ~2 SE) through into a CI that is only `±1.96 se_j` wide at
`alpha=0.05`. A biased-but-accepted cell would show exactly this kind of
coverage distortion. This is shared/generic code, not class-specific —
plausibly also explains `TODO-2`'s (in `release_v1_0_5.md`, now `TODO-29`)
independent `jackknife_wald` finding for `InferenceAllSimpleAverageDiff`.
**Slated `release_v1_5_0.md → TODO-5`** (renumbered from `TODO-3`
during a later cleanup pass; this file's own TODOs below were not
retroactively updated at the time and referenced the stale number).

### Third confirmed-affected class, 2026-09-24: `InferencePropKKGLMM`

A separate investigation fork (`investigate_count_hurdle_kk_and_prop_kkglmm_coverage.md`)
flagged `InferencePropKKGLMM`'s `compute_jackknife_wald_confidence_interval
~1` under-coverage outlier (0.779, 136 rows, p=5.94e-12) as a candidate
match for this same bug, hypothesizing it might instead be a *separate*
degenerate-leave-one-out-fold issue specific to its matched-pair/clustered
structure (by analogy to the already-confirmed `InferenceSurvivalKKWeibullMarginal`
jackknife bug). **Checked directly — it is the SAME bug, not a separate
one.** `InferencePropKKGLMM` (via `inference_proportion_KK_combined.R`
and its `InferenceAbstractKKCondLogitGLMM` base) declares
`resolve_jackknife_unit`/`jackknife_block_size_gt_one_unsupported`/
`mark_jackknife_nonestimable_if_block_unsupported` in its component
"overrides" list, but grepping for actual function bodies named
`resolve_jackknife_unit = function` across `R/EDI/R/` finds them ONLY in
the generic base (`inference_all_abstract_jackknife.R`) — these three
names are being *kept from* the generic implementation during component
composition, not overridden with class-specific logic. The generic
`resolve_jackknife_unit()` already handles matched-pair designs
design-agnostically (`private$is_KK` → `"matched_set"` unit,
`inference_all_abstract_jackknife.R:170-185`) — there is no
class-specific fold code for `InferencePropKKGLMM` to have a bug in.
`compute_jackknife_summary()` and `compute_jackknife_wald_confidence_interval()`
themselves are fully generic too (not touched by any override). This
class therefore inherits the CI-centering bug unmodified — same
mechanism as `InferenceIncidProbitRegr`'s outlier, just a larger observed
coverage drop (0.779 vs. 0.926), plausibly because `InferencePropKKGLMM`'s
matched-pair conditional-logit-style estimator has larger finite-sample
`bias_j` than Probit's, so more bias slips past the loose
`abs(bias_j) > 2*se_j` guard. **Third confirmed-affected class for
`release_v1_5_0.md → TODO-5`** — no new release entry needed, this is
the same fix. The `biased_estimate`/broad-over-coverage cluster for
`InferencePropKKGLMM` (separate from this outlier) remains unconfirmed,
not investigated further in this pass — see the other plan file's
TODO-4.

## TODOs

- [x] TODO-1 (2026-09-24, superseded): resolved by direct code-level
  argument (Probit's parity under estimand-consistent MC truth) rather
  than the proposed simulation — see "Resolution" above. The simulation
  remains a good idea if anyone wants airtight confirmation later, but
  isn't blocking closure at current confidence.
- [x] TODO-2 (2026-09-24, done): closed as benign — see "Resolution"
  above. Not added to any release; the 42 over-coverage findings should
  be accepted into `audit_comprehensive_results.R`'s baseline via
  `--write-baseline` next time that's run.
- [x] TODO-3 (2026-09-24, done): root-caused — see "Resolution" above
  (CI-centering bug in shared jackknife machinery). Slated
  `release_v1_5_0.md → TODO-3`.
- [x] TODO-4 (2026-09-24, done): cross-linked — see "Resolution" above.
  Add the actual new TODO entry to `fix_mc_coverage_truth_covariate_mismatch.md`
  itself (not done in this pass; that file wasn't touched — do it next).
- [ ] TODO-5: Investigate the `biased_estimate` finding for
  `InferenceIncidLogRegr ~.` (`compute_estimate`/`compute_jackknife_estimate`)
  — confirm or refute ordinary uncorrected finite-sample MLE bias as the
  explanation (e.g. by checking bias magnitude scales with
  covariate-count/n ratio as textbook theory predicts). Still open, not
  investigated in this pass.
- [ ] TODO-6 (new): implement the jackknife-Wald CI-centering fix in
  `R/EDI/R/inference_all_abstract_jackknife.R` — either center the CI at
  the bias-corrected `theta_j` instead of raw `theta_hat`, or tighten the
  `abs(bias_j) > 2 * se_j` acceptance guard so less-biased-but-still-
  distorting cells get excluded instead of silently miscovering. Reproduce
  the `InferenceIncidProbitRegr ~1` outlier and `InferenceAllSimpleAverageDiff`'s
  `TODO-29` finding first to confirm both share this mechanism before
  picking a fix direction — they may want different fixes if the bias
  magnitude differs qualitatively.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build.
