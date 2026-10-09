# Investigation: `InferenceContinOLS` Weighted-Bootstrap Calibration — Resolved as an Audit-Target Mismatch

> **Resolved 2026-10-09; no estimator source fix.** A faithful current-source
> replay used the harness's seeded 148-row diamonds sample, scaled full
> covariate matrix, continuous response construction, `FixediBCRD`, and
> `model_formula=~.` for 100 null replications with 99 draws per method. It
> reproduced the historical nonstudentized-bootstrap symptom, but directly
> refuted the proposed weighted-SE implementation bug. The ordinary OLS SE
> was calibrated (empirical SD 0.06017, mean SE 0.05984; ratio 0.995), the
> asymptotic reject rate was 0.06, and the studentized Bayesian-bootstrap
> p-value rejected 0.04. Across 9,900 independently instrumented Dirichlet
> draws, the weighted cross-products could be ill-conditioned (median maximum
> condition number 1.56e6 per replication) but produced no singular failure
> or pathological SE (median minimum 0.0316; mean weighted SE 0.0562), and a
> focused regression now pins the implementation to `stats::lm.wfit()` and
> the exact weighted cross-product reference.
>
> The remaining symptom comes from comparing an iid/superpopulation weighted
> bootstrap to repeated treatment randomization of one fixed finite dataset.
> In this replay, the Bayesian-bootstrap estimate distribution had mean SD
> 0.04826, about 20% below the repeated-randomization SD 0.06017; that target
> mismatch mechanically yielded percentile/symmetric rejection 0.12/0.11 and
> interval coverage 0.85--0.90. EDI exposes randomization inference separately,
> and the comprehensive audit must not grade every resampling family against a
> randomization-based operating characteristic as if they shared one target.

> **Depends on:** none. (Global ordering: see `../new_feature_plans/_master.md`.) Slated for
> `release_v1_0_5.md → TODO-25`. Added 2026-09-24, surfaced by the
> `pval_miscalibration`/`low_coverage` audit checks. **This is an open
> investigation, not a confirmed bug with a fix plan** — a plausible
> mechanism was identified by code reading but NOT confirmed by
> reproduction. Do not treat anything below as a diagnosed root cause
> until reproduction succeeds.

## The finding

At `model_formula=~.` (covariate-adjusted), `InferenceContinOLS` — plain
OLS regression, one of the most fundamental classes in the package — is
severely miscalibrated across resampling-family methods that reweight
rather than permute:
- Uniformity (should be ~0.05 true-null reject rate): `subsampling`
  reject=0.188 (n=672), `m_out_of_n_bootstrap` reject=0.158 (n=676),
  `bayesian_bootstrap_symmetric` reject=0.132 (n=1031), `rand_bootstrap`
  reject=0.136 (n=428), `bayesian_bootstrap_wald` reject=0.129 (n=1031) —
  3-4× nominal.
- Coverage (should be ~0.95): `bayesian_bootstrap_confidence_interval_studentized`
  0.817 (n=1735), `_basic` 0.827, `subsampling` 0.797 (n=1119),
  `m_out_of_n_bootstrap` 0.834 (n=1121), `_wald` 0.865.

At `model_formula=~1` (no covariates), the same method families are
near-nominal. This is the same SURFACE SIGNATURE (severe, `~.`-specific
miscalibration) already confirmed for `InferenceContinLin`
(`release_v1_0_5.md → TODO-15`) and `InferenceIncidLogBinomial` (found
2026-09-24 by a parallel investigation into the incidence-class cluster) —
**three unrelated classes now showing the same shape** (a fourth,
`InferenceSurvivalWeibullRegr`, was added 2026-09-24 — see "Next steps"
below), which raises the
question of a systemic shared mechanism. **This has NOT been confirmed**:
investigating `InferenceContinOLS` specifically found NO shared code path
with `InferenceContinLin`'s suspected mechanism (`get_centered_covariates()`/
`build_lin_design_matrix()`, never checked against `InferenceIncidLogBinomial`
either) — each class may have its own, analogous-but-distinct bug in how
it handles covariate-adjusted resampling, rather than one shared root
cause. Treat the "systemic mechanism" idea as a hypothesis worth a
dedicated cross-class investigation, not an established fact.

## `InferenceContinOLS`-specific candidate mechanism (unconfirmed)

`compute_estimate_with_bootstrap_weights()`
(`inference_continuous_ols.R:121-159`) — the shared refit path for
Bayesian-bootstrap and reweighted-bootstrap-family methods — uses
`X_full = private$create_design_matrix()` directly, fits via
`stats::lm.wfit()`, then computes the SE via an **unguarded**
`solve(crossprod(X_sub * sqrt(w_eff)))[2,2]` (line 149) with no rank/
conditioning check. This differs from the observed/asymptotic fit path,
`shared()` (lines 262-315), which applies a **second, adaptive** hardening
layer beyond `create_design_matrix()`'s static one:
`fit_with_hardened_qr_column_dropping()` (lines 282-296), dynamically
dropping rank-deficient columns per fit via QR — not just the static
`drop_highly_correlated_cols`/`drop_linearly_dependent_cols` check baked
into `create_design_matrix()` (`inference_all_abstract.R:1032-1064`,
confirmed shared/cached by both paths, so that static hardening is NOT the
asymmetry).

**Theory**: a particular bootstrap-weight draw (Dirichlet weights
concentrating on a subset of rows, or a subsample draw) can make the
*reweighted* cross-product matrix near-singular in a way the *full-data*
static hardening never catches (it only ever saw the unweighted, full
design). `solve()` on a near-singular (not exactly singular) matrix
returns a large-but-finite value, passing the `is.finite(var_j) &&
var_j > 0` guard uncaught — producing an unstable, sometimes-way-too-small
SE. This would explain both the inflated rejection rate and severe
undercoverage, and why it's specific to `~.` (more covariates → more
collinearity opportunity) and specific to the reweighting-based method
families (`rand`'s C++ kernel path, `compute_rand_bootstrap_ols_parallel_cpp`,
is separate and not implicated — confirmed correctly-calibrated).

**NOT confirmed by reproduction**: two synthetic true-null fixtures
(n=60-80, 4-5 covariates, independent and then deliberately near-collinear
pairs, B=100-150 subsampling draws, 30 reps each) both stayed at 0%
rejection at `~.`. Either (a) the real trigger needs the actual harness's
specific dataset/covariate structure — the same "synthetic fixture doesn't
reproduce, needs the real DGP" lesson several other investigations this
session hit (`InferenceContinLin`'s TODO-15, `InferenceIncidKKModifiedPoisson`'s
TODO-19) — or (b) this hypothesis is wrong and the real mechanism is
elsewhere (not traced: the C++ kernels underlying `fast_ols_cpp`/
`fast_ols_with_var_cpp` themselves, or `expand_subject_or_block_weights_to_row_weights()`,
shared bootstrap-weight-generation machinery).

## Confirmed NOT related to two existing findings

- **`TODO-15` (`InferenceContinLin`)**: no contradiction, independent
  finding. TODO-15's "OLS near-nominal" comparison checked
  `compute_lik_ratio_bootstrap_two_sided_pval`/`compute_param_bootstrap_pval`/
  `compute_lik_ratio_bartlett_approx_two_sided_pval` (the
  `ParametricLikelihoodBootstrap` component, via `simulate_under_lik_null()`)
  — a completely different code path from THIS finding's worst-affected
  methods (`subsampling`/`m_out_of_n_bootstrap`/`rand_bootstrap`/
  `bayesian_bootstrap`, via `compute_estimate_with_bootstrap_weights()`).
  TODO-15 never checked the latter set — nothing to reconcile, these are
  two different (possible) bugs in two different classes' two different
  method-family groups.
- **`TODO-3`**: unrelated. TODO-3 is about `compute_fast_randomization_distr()`
  throwing and falling back to a slow R loop for the permutation (`rand`)
  path — a pure-performance issue on a correctly-calibrated, different
  code path (`compute_rand_bootstrap_ols_parallel_cpp`, unrelated to
  `compute_estimate_with_bootstrap_weights()`).

## Resolution checklist

- [x] Reproduced the exact harness dataset/DGP/design/model-formula path with
  current source loaded using `compile = FALSE`.
- [x] Instrumented the proposed near-singular weighted-cross-product mechanism
  over 9,900 draws. Ill-conditioning occurred, but the weighted estimates and
  SEs remained finite and matched the independent WLS reference.
- [x] Ruled out the OLS kernel and weight-expansion paths: ordinary OLS was
  calibrated, and a focused regression pins the weighted coefficient and SE
  to `stats::lm.wfit()` plus the exact weighted cross-product calculation.
- [x] Closed the four-class shared-mechanism lead as out of scope. Those
  classes have different estimands and resampling contracts; pooling their
  audit rows cannot establish one source defect.
- [x] Kept this as an investigation rather than upgrading it to a fix plan.
  The reproduced discrepancy is between the iid/superpopulation bootstrap
  target and the audit's repeated-randomization target, not an OLS code bug.

## Validation record

- [x] 100 faithful null replications and 9,900 instrumented weighted draws.
- [x] Focused weighted WLS/SE reference regression added at
  `test-continuous-ols-weighted-bootstrap-wls-reference.R`.
- [x] No installed-package CSV regeneration is required because estimator
  behavior did not change; the audit interpretation was corrected.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`). Any reproduction
work must state explicitly whether it used the real `comprehensive_tests.R`
DGP or an approximation — two prior attempts with an approximation both
failed to reproduce and that distinction must not be glossed over again.
