# Joint Multivariate Response Modeling

> **Depends on:** `multivariate_response_type_report.md` Stages 0-0.5 (one `Design` holding several named responses, `response_name` binding on `Inference`), and ideally its Stage 1-2 composite layer. Level 1 also needs the stable scalar `Inference` surface (`fix_inference_hierarchy.md`, DONE 2026-08-23). (Global ordering: see `_master.md`.)

Written 2026-09-21 at the owner's direction. It splits what
`multivariate_response_type_report.md` calls "true joint modeling" (its old
Stage 4) into three levels with different costs and release targets:

| Level | What | Release |
|---|---|---|
| 1 | Marginal models + joint sandwich covariance | **v2.0.0** |
| 2 | Randomization-based joint inference | **v2.0.0** |
| 3 | Fully parametric joint models | **v4.0.0** |

The composite layer in `multivariate_response_type_report.md` (per-metric fits,
then Holm / max-p IUT / Cauchy across p-values) ignores the correlation between
metrics. This plan adds inference that uses it.

## Level 1: marginal models plus a joint covariance (v2.0.0)

Fit each response with its existing scalar `Inference` class (any response
type, mixed types allowed), then estimate the **joint covariance of the K
treatment effects** from the stacked estimating equations.

- Per-subject influence function (score contribution) `psi_ik` for response
  `k`. Covariance between effects `j` and `k`:
  `V_jk = (1/n^2) * sum_i psi_ij * psi_ik` (with the usual finite-sample and
  design-specific corrections: matched pairs/blocks contribute clustered
  influence functions, so the sum runs over independent units).
- Reference approaches: Wei-Lin-Weissfeld (1989) for multiple survival
  endpoints; Pipper-Ritz-Bisgaard (2012) multiple marginal models
  (`multcomp`/`mmm`-style).
- Outputs: a vector `beta_hat_T` with a K x K covariance, asymptotically
  normal, giving
  - a **global Wald chi-square** test and an **O'Brien-type combined** test;
  - **max-T multiplicity-adjusted p-values and simultaneous CIs** that use the
    between-metric correlation (Holm ignores it);
  - correlation-aware family-wise power in simulation.
- New code:
  - an accessor on `Inference` classes exposing per-subject influence
    functions on the same observations the fit used (mechanical but touches
    many of the 102 concrete classes; roll out by response family, starting
    with OLS/logistic/Poisson/Cox, and error cleanly for classes that do not
    yet expose them);
  - a new `InferenceJointMarginal` class holding a *vector* `beta_hat_T` and a
    covariance, so the scalar `beta_hat_T`/`s_beta_hat_T` cache contract is not
    changed;
  - a missing-data policy (complete-case vs pairwise-complete covariance;
    default complete-case, reported n per pair);
  - censored/interval-censored responses need their own influence-function
    conventions (survival IF via martingale residuals).
- No new C++ expected if influence functions can be assembled in R from
  existing fit output; profile before deciding.

## Level 2: randomization-based joint inference (v2.0.0)

Redraw `w` from the design's own randomization scheme, apply the **same draw to
all K responses**, recompute the K statistics, and use their joint null
distribution.

- Outputs: Westfall-Young step-down min-p / max-T adjusted p-values and a
  global test (max-|T|, or a Mahalanobis/sum-of-squares statistic on the
  studentized effect vector) with no asymptotic assumption.
- This is why the one-`Design` architecture matters: one shared `w`.
- Must be validated against each design family's randomization scheme
  (complete randomization, blocking, matching, rerandomization, sequential
  designs) and against what null it controls (sharp null across all metrics).
  Confidence intervals by test inversion follow the existing randomization-CI
  machinery per metric; simultaneous randomization CIs are a research item.
- Reuses the existing randomization-distribution kernels; extends them to
  return K statistics per draw.

## Shared work for Levels 1-2 (v2.0.0)

- `SimulationFramework`: a vector `betaT` applied **within one replication**
  (not swept across cells), vector-valued truth, and family-wise summaries
  (power to reject all/any/which; family-wise type-I error). Cross-metric
  correlation is a user-specified matrix (see the report's Stage 3).
- Reporting: rows for the K metrics plus the joint tests, integrated with
  `multiplicity_adjusted_results_table.md`.
- Tests: known-correlation simulations where the joint max-T CI must beat Holm
  in power while holding FWER; parity between Level 1 and Level 2 on
  large-sample normal data.

## Level 3: fully parametric joint models (v4.0.0)

Only after Levels 1-2 ship and a concrete need appears for something the
marginal-plus-sandwich and randomization approaches cannot give.

- Candidates: multivariate normal / SUR / MANOVA (for all-continuous responses
  with identical regressors SUR reduces to per-equation OLS, so the gain is
  mainly efficiency with unequal regressors); copulas for mixed response types;
  multivariate GLMM with shared latent effects; joint models linking a
  longitudinal marker and a survival outcome.
- Needs new C++ likelihood cores (mixed-type likelihoods are the hard part),
  a vector-valued treatment effect and joint covariance in a new cache
  contract, and a joint bootstrap. A response *matrix* can be assembled from
  the named-response list on demand; matrix-valued `Design` storage is not
  assumed.
- Should sit on the shared C++ backend work already in `release_v4_0_0.md` if
  that lands first, so the numerical cores are written once.
- Gate: a separate go/no-go decision at the start of v4.0.0 planning; scope
  here is a placeholder, not a commitment.

## Implementation TODOs

- [ ] TODO-1: **Confirm go-ahead** and that `multivariate_response_type_report.md` Stage 0/0.5 have landed (one `Design`, named responses).
- [ ] TODO-2 (v2.0.0, Level 1): influence-function accessor on `Inference` classes, rolled out by response family; `InferenceJointMarginal` with joint covariance, global Wald, O'Brien, max-T adjusted p-values and simultaneous CIs; missing-data policy; survival/censored IF conventions.
- [ ] TODO-3 (v2.0.0, Level 2): joint randomization draws (same `w` across K responses), Westfall-Young step-down and a global joint test; per-design-family validation of the null controlled.
- [ ] TODO-4 (v2.0.0): `SimulationFramework` vector `betaT` within a replication and family-wise summaries; results-table integration; Level 1 vs Level 2 vs Holm power/FWER tests.
- [ ] TODO-5 (v4.0.0, Level 3): go/no-go decision, then parametric joint models (SUR/MANOVA, copula, multivariate GLMM) with new C++ cores, ideally on the shared backend.
