# Exposure (Person-Time) Offset for Count Inference Classes

> **Depends on:** nothing architectural; touches the count likelihood
> family (`inference_all_abstract_count_likelihood.R` and the Poisson /
> NB / hurdle / zero-inflated classes and their C++ kernels). Additive.
> **Release target: v1.1.0** (`release_v1_1_0.md → TODO-17a`).

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#5** (Part 4A,
rank 1 in its prioritized list).

## Why

Rate outcomes — exacerbations, relapses, hospitalizations, crimes per
place-year — are counts observed over subject-specific exposure times
`t_i`. The standard analysis is Poisson or negative-binomial regression
with `log(t_i)` as an offset, giving a rate ratio per unit exposure.
Negative binomial with an offset is the standard for exacerbation-rate
trials in respiratory medicine (>70%, estimate; ERS-endorsed since Keene
et al. 2008) and for recurrent hospitalization in heart failure; Poisson
with offset is common in epidemiology and place-based criminology.

EDI's count classes (`InferenceCountPoisson`, `QuasiPoisson`,
`RobustPoisson`, `NegBin`, hurdle and zero-inflated variants, and the KK
`PoissonKKGEE` / `KKGLMM` / `KKCondPoissonOneLik` / hurdle IVWC/OneLik)
have no `offset` / `exposure` argument, and neither do their kernels
(grep confirms no `offset` in `inference_count_*.R` or the count kernels;
the only `offset` plumbing is the Cox fixed-coefficient path). Without it
the count family cannot analyze the most common count-endpoint trial
design.

## Proposal

- `initialize(..., exposure = NULL)` on every count inference class:
  a positive numeric vector of length `n` (or a column name in the
  design's covariates); internally `log(exposure)` enters the linear
  predictor with a fixed coefficient of 1.
- Kernels: add an `offset` vector argument (default zeros) to the count
  likelihood kernels; the Poisson/NB log-likelihood, gradient and Hessian
  change only through `η_i += offset_i`. Hurdle/ZI: offset on the count
  component; zero component unchanged (document).
- Marginal estimands (`set_estimand("marginal_ratio")` etc.) evaluate at
  a common reference exposure (default: `exposure = 1`, i.e. rates).
- Bootstrap / permutation replay carry `exposure` like a covariate column.
- Design-side: no change; exposure is stored on the inference object (or
  optionally as a reserved covariate column `exposure__` on `Design`,
  decide at TODO-1 — the covariate-column route lets `SimulationFramework`
  and `InferenceSuite$run_all_inference()` see it).

## Tests

Parity vs `glm(y ~ w + x + offset(log(t)), family = poisson)` and
`MASS::glm.nb(...)` at tight tolerance; `exposure = rep(1, n)` reproduces
every existing count golden test bit-for-bit; randomization p-value
invariance to a common exposure rescaling; KK variants against `geepack`
/ `glmmTMB` with `offset()`.

## TODOs

- [ ] TODO-1: Decide storage route (inference-object argument vs reserved
  design covariate column).
- [ ] TODO-2: Kernel `offset` argument on the Poisson / NB / hurdle / ZI
  count kernels (targeted compile only); parity tests.
- [ ] TODO-3: R-side `exposure =` on all plain count classes incl. marginal
  estimand reference exposure; golden no-op tests.
- [ ] TODO-4: KK count classes (GEE / GLMM / cond-Poisson / hurdle).
- [ ] TODO-5: `SimulationFramework` exposure generator option;
  `run_all_inference()` passes exposure through; roxygen + vignette line.
