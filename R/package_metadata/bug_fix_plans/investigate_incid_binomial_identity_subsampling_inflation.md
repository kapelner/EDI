# Investigation: `InferenceIncidBinomialIdentityRiskDiff` Subsampling / m-out-of-n Type-I Inflation — Historical Finding Not Reproduced, Boundary Hypothesis Refuted

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.)
> Slated for `../future_release_plans/release_v1_0_5.md → TODO-27`. Added
> 2026-09-24, same audit-triage wave as TODO-25/26. The investigation was
> closed on 2026-10-08 after the proposed mechanism was refuted and current
> source-loaded results did not reproduce the reported inflation.

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

## Resolution (2026-10-08)

The boundary-rejection mechanism is impossible in the reported
`model_formula = ~1` cells. With only an intercept and binary treatment, the
identity model is saturated for the two arms: its fitted probabilities are
exactly the two observed arm proportions and therefore remain in `[0,1]` for
every estimable resample. A permanent regression pins that identity and
confirms that 31 deterministic draws from each resampling family are all
finite.

The actual filtering path does condition on fit success, but only after a
majority-success gate. `subsampling_centered_pivot()` and
`m_out_of_n_bootstrap_centered_pivot()` retain finite estimates, fail the
whole pivot when fewer than 50% of draws succeed, and otherwise center the
survivors at the full estimate. The p-value call then requires at least
`min_number_usable_samples` (default 5), and `resampling_centered_pval()`
filters nonfinite values once more before computing the two empirical tails.
That conditioning can matter for another estimator with material asymmetric
fit failure, but it cannot cause the `~1` finding here because dropout is zero.

Three independent checks support closure:

- The actual package path, loaded with `compile = FALSE`, produced zero
  nonfinite draws in five independent null datasets with 99 m-out-of-n and 99
  subsampling draws per dataset. A representative adjusted (`~x1`) fixture
  likewise had zero failures across 151 draws from each family.
- An independent 1,000-dataset null simulation of the exact centered-pivot
  formulas at the comprehensive-test scale (`n = 150`, `B = 501`, default
  size 33) rejected at 0.056 for m-out-of-n and 0.046 for subsampling, with
  100% usable draws. At `n = 60` (default size 17), rates were 0.055 and
  0.039; minimum usable fractions were 0.998 and 1.000.
- The fresh 2026-10-04 focused comprehensive CSV has 0/12 rejections for
  each `~1` method and 1/12 for each `~.` method under `beta_T = 0`. These
  small counts are not a calibration study by themselves, but they contradict
  a persistent 0.12--0.13 failure mode.

There is therefore no source change to make. Disabling the fitted-probability
boundary cannot repair an effect that occurs in the algebraically boundary-safe
`~1` case, and current null calibration is nominal at both moderate and larger
sample sizes. The historical aggregate should be treated as a stale or
non-reproducible audit finding rather than accepted as a package defect.

## Items

- [x] **TODO-1: Measure the dropout.** For the failing configuration,
  record per subsample draw whether the fit was boundary-rejected, and the
  dropped fraction per replicate of the p-value. Confirm or refute that
  dropped draws are a material fraction (rule the hypothesis out cheaply if
  the dropped fraction is ~0).
- [x] **TODO-2: Read the filtering path.** Read
  `subsampling_centered_pivot()` and `resampling_centered_pval()`; state
  exactly how non-finite draws are removed and whether the remaining
  distribution is conditioned on fit success.
- [x] **TODO-3: Confirm causation.** Rerun the null simulation with
  boundary rejection artificially disabled for the resampling context only
  (or with a clamped fit) and see whether the reject rate returns to
  nominal. Also rerun with larger `n`/`b` to see whether the inflation
  shrinks as boundary hits become rarer. Record the result here.
- [x] **TODO-4: Fix, only if TODO-3 confirms.** No fix: TODO-3 refuted the
  mechanism and current behavior is calibrated. The two previously proposed
  directions therefore do not apply. They were: (a) make the centered-pivot treatment of
  dropped draws statistically neutral (e.g. treat a boundary-rejected draw
  as a failure of the whole p-value, or resample until enough valid draws),
  or (b) relax/soften the `[0,1]` boundary for the resampling-distribution
  context only, keeping hard rejection for the observed fit. Pick with the
  user; document the choice.
- [x] **TODO-5: Tests.** Added a deterministic regression proving the
  intercept-only fitted probabilities equal the arm proportions and checking
  that both default resampling families produce only finite, bounded risk
  differences. The observed-fit boundary predicate remains covered by its
  existing focused tests.
- [x] **TODO-6: If refuted,** record the finding here and recommend
  accepting the two cells into the audit baseline as expected/benign
  small-sample behavior, as was done for the sibling investigation plans.

Focused validation used `pkgload::load_all("R/EDI", compile = FALSE)` only.
The new regression's 10 expectations and 123 related identity-fit/shared-pivot
expectations passed with no failures, errors, or warnings. No compilation,
build, or installation was performed.

## Explicitly out of scope

- The other incidence classes in the triage cluster (accepted as benign).
- The `model_formula`-dependent miscalibration of TODO-15/TODO-25.
- Changing the identity-link boundary rule for the full-sample fit.
