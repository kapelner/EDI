# Encouragement Designs: `treatment_received` and CACE / LATE Inference

> **Depends on:** shipped design/inference hierarchies. Adds one stored
> per-subject column on `Design` (moderate plumbing: bootstrap/permutation
> replay, save/load) and one new inference family. **Release target:
> v1.4.0 (response & data extensions)** (`release_v1_4_0.md → TODO-9`;
> `_master.md` Phase 5V). Uses the 1.1.0 HC-robust helper.

Written 2026-08-27. Owning plan for
`missing_design_classes_literature_audit.md` item **#3** and
`missing_inference_classes_literature_audit.md` item **#3** (both Part 4A).

## Why

An encouragement design randomizes an *offer* (voucher, invitation,
nudge); subjects decide whether to take it up. Two binary variables per
subject: `w` (assigned — EDI stores) and `d` (received — EDI has no slot).
With `w` alone EDI estimates the ITT. With `d` it can also estimate the
CACE / LATE — the effect among compliers — via the Bloom/Wald estimator
`CACE = ITT_y / ITT_d`, or 2SLS with `w` instrumenting `d` when covariates
are used. Very common in economics (any RCT with take-up < 100%), the
standard NCEE secondary estimand in education (Schochet & Chiang 2009),
occasional in behavioral/surgical medical trials.

## Design side (prerequisite)

- `Design$add_treatment_received(d)` / `add_one_subject_treatment_received(t, d)`;
  `get_treatment_received()`.
- Asserts: `d ∈ {0,1}`; optional `one_sided = TRUE` enforcing `d ≤ w`
  (no always-takers).
- Carried through `draw_bootstrap_indices()`, the design-backed bootstrap
  worker state, `duplicate()`, save/load — exactly like `y`.
- The randomization mechanism needs no change: any design class can be
  an encouragement design once `d` is recorded. Replay tests permute `w`
  and treat `d` as an outcome (the sharp null of no effect of *assignment*
  on either `d` or `y`).

## Inference side

- `InferenceAllCACEWald` — Bloom/Wald ratio of two ITTs; delta-method SE
  (Imbens & Rubin 2015 ch. 23), Bayesian/nonparametric bootstrap,
  randomization test via Fieller/Anderson-Rubin-type inversion (valid
  under weak instruments). Exposes `get_compliance_rates()`.
- `InferenceContin2SLS` (and `InferenceIncid2SLS` for the LPM) — 2SLS with
  covariates, HC-robust SE (reuses
  `heteroskedasticity_robust_standard_errors.md`'s helper), Anderson-Rubin
  CI option.
- Estimand metadata: `"cace"`; `set_estimand()` not needed (single target).
- Registry: `InferenceAll…` prefix ⇒ all six response types for the Wald
  ratio (the ITT_y is whatever mean-difference the type supports).

## Tests

Parity vs `AER::ivreg` / `estimatr::iv_robust`; `d ≡ w` reduces CACE to
ITT exactly (golden); weak-instrument fixture where the AR CI is
unbounded and the delta-method CI is flagged; storage round-trip and
replay tests; `SimulationFramework` compliance-generator option with
closed-form true CACE.

## TODOs

- [ ] TODO-1: Design-side `treatment_received` column, asserts, replay,
  save/load; golden no-op when absent.
- [ ] TODO-2: `InferenceAllCACEWald` (delta / bootstrap / randomization).
- [ ] TODO-3: `InferenceContin2SLS`, `InferenceIncid2SLS` with AR CI.
- [ ] TODO-4: `SimulationFramework` compliance generator + truth;
  `run_all_inference()` discovery; vignette section.
