# Investigation: `InferenceContinOLS` `model_formula=~.`-Specific Miscalibration in Weighted-Bootstrap Methods — Unconfirmed

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

## Next steps (none done yet — do these before attempting any fix)

- [ ] Reproduce using `comprehensive_tests.R`'s actual DGP call path/exact
  dataset (not a hand-built approximation) via
  `pkgload::load_all(".", compile = FALSE)` only (never `R CMD INSTALL`/
  `R CMD build`/`pkgbuild::compile_dll()`/`load_all(compile = TRUE)` or
  unspecified `compile=` — hard project rule, top-level `CLAUDE.md`).
- [ ] If it reproduces: confirm the near-singular-reweighted-crossprod
  mechanism directly (instrument `solve()`'s input condition number across
  draws) before proposing the QR-hardening fix.
- [ ] If it does NOT reproduce with the real DGP either: trace the C++
  kernels (`fast_ols_cpp`/`fast_ols_with_var_cpp`) and
  `expand_subject_or_block_weights_to_row_weights()` next.
- [ ] Separately (higher-leverage, not yet started): a dedicated
  cross-class investigation into whether `InferenceContinOLS`,
  `InferenceContinLin`, `InferenceIncidLogBinomial`, AND (added
  2026-09-24, a 4th class found the same day by the survival-cluster
  investigation) `InferenceSurvivalWeibullRegr`'s `~.`-specific CI
  undercoverage (worst cells 0.848-0.95, 16 of the worst 20 rows at
  `~.`)'s miscalibration shares ANY common code path (a generic covariate-
  reduction helper all four call, even if each also has its own
  class-specific wrapper) — this session's per-class investigations each
  found a DIFFERENT candidate mechanism and explicitly found no shared
  code between at least ContinOLS and ContinLin, so the "systemic"
  framing is a hypothesis to test, not an established fact. `InferenceSurvivalWeibullRegr`
  has no `shared()` method (unlike most classes this session touched) —
  its point-estimate/SE caching lives in an unread ancestor class, so
  tracing it might actually be the fastest way to find a genuinely shared
  mechanism, or to rule one out. Worth checking before writing four
  separate fix plans if there's actually
  one shared root cause.
- [ ] Only once reproduction confirms a concrete, fixable mechanism should
  this file be replaced/upgraded to a normal `# Fix:` plan with its own
  `## TODOs` fix checklist.

## Standing constraints

No `R CMD INSTALL`/rebuild of `R/EDI` without being asked in that turn;
verify via `pkgload::load_all(".", compile = FALSE)` only, never a full
build (hard project rule, see top-level `CLAUDE.md`). Any reproduction
work must state explicitly whether it used the real `comprehensive_tests.R`
DGP or an approximation — two prior attempts with an approximation both
failed to reproduce and that distinction must not be glossed over again.
