# Heteroskedasticity-Robust (HC0–HC3) Standard Errors for OLS and the LPM

> **Depends on:** nothing architectural. Additive `se_type` argument on
> `InferenceContinOLS` and `InferenceIncidRiskDiff`; reuses the sandwich
> machinery already in `InferenceContinLin` (HC2). **Release target:
> v1.1.0** (`release_v1_1_0.md → TODO-17b`).

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#1** (Part 4A,
rank 2).

## Why

OLS on a treatment dummy plus covariates with an HC-robust sandwich SE
(HC1 by default in Stata) is the single most common estimator in
economics and political-science RCTs, and the LPM with robust SEs is the
dominant binary-outcome estimator there (Angrist & Pischke; Gomila 2021).
`InferenceContinOLS` reports homoskedastic SEs only; `InferenceContinLin`
provides HC2 but only with the full treatment×centered-covariate
interaction, which is a different estimator. `InferenceIncidRiskDiff` (the
LPM) has no robust option.

## Proposal

- `initialize(..., se_type = c("classical", "HC0", "HC1", "HC2", "HC3"))`
  on `InferenceContinOLS` and `InferenceIncidRiskDiff`; default
  `"classical"` (bit-for-bit no-op).
- One shared `.hc_sandwich(X, resid, type)` helper (factor out of the Lin
  class), used by all three classes; HC2/HC3 need the hat-matrix diagonal
  (already computed for Lin).
- Wald CI / p-value use the robust SE with the same `n − p` df convention
  as today; likelihood-based tests (`likelihood_tier = "full"` on OLS)
  are unaffected and documented as such.
- KK OLS IVWC/OneLik: pass-through of `se_type` to the reservoir OLS
  (optional, TODO-4).

## Tests

Parity vs `sandwich::vcovHC(lm(...), type = "HC0".."HC3")`; `se_type =
"classical"` reproduces existing golden tests; Lin class unchanged after
the helper extraction (golden).

## TODOs

- [ ] TODO-1: Extract the HC sandwich helper from `inference_continuous_lin.R`
  (behavior-preserving, golden test).
- [ ] TODO-2: `se_type` on `InferenceContinOLS`; parity + no-op tests.
- [ ] TODO-3: `se_type` on `InferenceIncidRiskDiff`; parity tests.
- [ ] TODO-4 (optional): pass-through on KK OLS IVWC/OneLik reservoir fits.
- [ ] TODO-5: roxygen; note in the OLS docs that HC1 is the econ default.
