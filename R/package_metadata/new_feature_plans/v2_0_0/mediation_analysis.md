# Mediation Analysis: Mediator Column and Indirect / Direct Effect Inference

> **Depends on:** shipped hierarchies; `encouragement_design_cace.md`
> (establishes the pattern of a third stored per-subject variable with
> replay plumbing). **Release target: v2.0.0** (`release_v2_0_0.md →
> TODO-2b`) — a new estimand family with its own identification
> assumptions and a new stored variable class.

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#12** (Part 4B).

## Why

Mediation is a third of all regression analyses in psychology journals
(Blanca et al. 2018), near-universal in consumer research (PROCESS), and
occasional in medicine (98 RCTs in two years, 96% Baron-Kenny). EDI has
no mediator concept. This is the single largest gap for psychology /
marketing users.

## Proposal

- Design side: `Design$add_mediator(m)` (numeric or binary, post-
  treatment), carried through replay / save-load like `y` and `d`.
- `InferenceContinMediationProduct` — product-of-coefficients `a·b` from
  `m ~ w + X` and `y ~ w + m + X`; bootstrap CI (percentile / BCa — the
  PROCESS default) via the existing bootstrap components; Sobel SE as the
  asymptotic path; direct effect `c'`; total = `c' + ab`; `proportion
  mediated` accessor. Binary `m` / `y` via logistic first- and second-
  stage with the usual scale caveats.
- `estimand = c("indirect", "direct", "total")` through `set_estimand()`.
- Second wave: counterfactual NDE / NIE (Imai-Keele-Tingley 2010; VanderWeele)
  with the `mediation`-package sensitivity parameter `ρ` for sequential
  ignorability; moderated mediation (index of moderated mediation) via
  `treatment_covariate_moderation.md`'s `moderator =`.
- Randomization inference: only `w` is randomized, so the FRT tests the
  sharp null of no effect of `w` on `(m, y)` jointly; document that the
  indirect-effect null is *not* randomization-testable without the
  sequential-ignorability assumption (which is why this is a new
  estimand family, not a wrapper).

## Tests

Parity vs `mediation::mediate` (quasi-Bayesian and bootstrap) and
`lavaan` for the product path; PROCESS reference values on a published
dataset; golden no-op when no mediator is stored.

## TODOs

- [ ] TODO-1: Design-side mediator column, asserts, replay, save/load.
- [ ] TODO-2: `InferenceContinMediationProduct` with bootstrap / Sobel;
  estimand switch; accessors.
- [ ] TODO-3: binary mediator / outcome variants.
- [ ] TODO-4: counterfactual NDE/NIE + sensitivity `ρ`; moderated mediation.
- [ ] TODO-5: `SimulationFramework` mediation generator + truth; vignette.
