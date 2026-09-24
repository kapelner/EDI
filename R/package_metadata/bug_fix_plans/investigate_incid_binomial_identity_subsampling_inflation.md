# Investigation: `InferenceIncidBinomialIdentityRiskDiff` Subsampling / m-out-of-n Type-I Inflation — Boundary-Rejection Hypothesis (Not Yet Reproduced)

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.)
> Slated for `../future_release_plans/release_v1_0_5.md → TODO-27`. Added
> 2026-09-24, same audit-triage wave as TODO-25/26. **This is an open
> investigation, not a confirmed bug with a fix plan** — the mechanism below
> is a hypothesis from code reading; no reproduction of the mechanism has
> been run. Do not implement a fix before TODO-1..3 confirm it.

## The finding

`InferenceIncidBinomialIdentityRiskDiff` shows moderate Type-I inflation
(~2.6× nominal) on exactly two methods, consistent at both
`model_formula=~1` and `~.`:

| method | reject rate `~1` | reject rate `~.` |
|---|---|---|
| `compute_m_out_of_n_bootstrap_two_sided_pval` | 0.117 | 0.116 |
| `compute_subsampling_two_sided_pval` | 0.131 | 0.123 |

Because the pattern does not depend on `model_formula`, it is a different
mechanism from the formula-dependent pattern of TODO-15/TODO-25. A
broader incidence-cluster triage found the rest of the cluster
(`InferenceIncidLogRegr`, `InferenceIncidProbitRegr`, plain
`InferenceIncidModifiedPoisson`) mild and conservative (ordinary
finite-sample asymptotics, not worth chasing) and
`InferenceIncidKKCondLogitOneLik`'s worst cell already explained by TODO-18.
This class is the one clear exception.

## Why the generic code is not the first suspect

Both methods dispatch through package-wide shared code
(`inference_all_abstract_non_param_boot.R` →
`inference_ext_prw_subsampling.R`, `compute_subsampling_two_sided_pval_impl`,
a textbook Politis/Romano/Wolf centered-pivot scheme; the p-value itself
is `resampling_centered_pval()` in
`inference_ext_exchangeable_resampling_units.R`). A defect in the pivot
math would hit many classes, yet this is the only class showing it, which
points at how *this estimator* behaves on a subsample.

## Leading hypothesis

The identity-link binomial fit deliberately rejects any fit whose fitted
probabilities leave `[-1e-8, 1+1e-8]`
(`is_identity_binomial_fit_reasonable()`,
`inference_incidence_binomial_identity.R:133-146`) — a documented
limitation of the identity link, not a bug for the full-sample fit. A
subsample of size `b < n` (default `b ≈ floor(n^0.7)`) is much more likely
to produce an extreme treatment-arm split that pushes the fit outside
`[0,1]`. If those rejected draws are disproportionately the ones with large
`|beta_hat_sub − beta_hat_full|`, and the p-value path drops non-finite
draws (`pivot$finite`, and the `min_number_usable_samples` filter) in a way
that is not statistically neutral, the empirical pivot distribution is
artificially narrowed and the full-sample statistic is rejected too often —
independent of `model_formula`, matching the observation.

**Not confirmed:** `subsampling_centered_pivot()` and
`resampling_centered_pval()` were not read for their actual filtering
behavior, and nothing was reproduced.

## Items

- [ ] **TODO-1: Measure the dropout.** For the failing configuration,
  record per subsample draw whether the fit was boundary-rejected, and the
  dropped fraction per replicate of the p-value. Confirm or refute that
  dropped draws are a material fraction (rule the hypothesis out cheaply if
  the dropped fraction is ~0).
- [ ] **TODO-2: Read the filtering path.** Read
  `subsampling_centered_pivot()` and `resampling_centered_pval()`; state
  exactly how non-finite draws are removed and whether the remaining
  distribution is conditioned on fit success.
- [ ] **TODO-3: Confirm causation.** Rerun the null simulation with
  boundary rejection artificially disabled for the resampling context only
  (or with a clamped fit) and see whether the reject rate returns to
  nominal. Also rerun with larger `n`/`b` to see whether the inflation
  shrinks as boundary hits become rarer. Record the result here.
- [ ] **TODO-4: Fix, only if TODO-3 confirms.** Two directions, a design
  decision rather than a one-liner: (a) make the centered-pivot treatment of
  dropped draws statistically neutral (e.g. treat a boundary-rejected draw
  as a failure of the whole p-value, or resample until enough valid draws),
  or (b) relax/soften the `[0,1]` boundary for the resampling-distribution
  context only, keeping hard rejection for the observed fit. Pick with the
  user; document the choice.
- [ ] **TODO-5: Tests.** A regression test on the boundary-heavy scenario
  (small `n`, extreme base rate) pinning the calibrated reject rate, plus a
  test that the observed-fit rejection behavior is unchanged.
- [ ] **TODO-6: If refuted,** record the finding here and recommend
  accepting the two cells into the audit baseline as expected/benign
  small-sample behavior, as was done for the sibling investigation plans.

## Explicitly out of scope

- The other incidence classes in the triage cluster (accepted as benign).
- The `model_formula`-dependent miscalibration of TODO-15/TODO-25.
- Changing the identity-link boundary rule for the full-sample fit.
