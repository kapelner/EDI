# Treatment × Covariate Moderation (Subgroup / Interaction) Estimands

> **Depends on:** shipped inference hierarchy; the `estimand` axis.
> Moderate: a second named coefficient must flow through the scalar
> `beta_T` contract on regression classes. **Release target: v1.4.0
> (response & data extensions)** (`release_v1_4_0.md → TODO-10`;
> `_master.md` Phase 5W).

Written 2026-08-27. Owning plan for
`missing_inference_classes_literature_audit.md` item **#4** (Part 4A).

## Why

Pre-specified subgroup analyses with a treatment×covariate interaction
test are very common in every field (forest plots in medicine; PAP-
registered subgroups in economics; moderation via PROCESS in psychology /
marketing; WWC-required moderators in education). `model_formula` expands
covariate interactions but the treatment coefficient is always the single
main effect; `InferenceContinLin` builds the fully interacted matrix but
reports only the ATE.

## Proposal

- `moderator =` argument on regression-based classes (OLS, Lin, logistic,
  Poisson/NB, Cox, proportional odds, beta, …): a covariate name (binary,
  categorical, or continuous).
- The fit adds `w:x_mod` (and `x_mod` main effect if absent). Two
  estimands via `set_estimand()`:
  - `"interaction"` — the `w:x_mod` coefficient (difference in treatment
    effect per unit of / between levels of the moderator); this becomes
    `beta_T` for all Wald / LR / bootstrap / randomization contracts.
  - `"subgroup"(level)` — the treatment effect within a moderator level
    (`beta_w + beta_{w:x} · level`), with delta-method SE; a
    `get_subgroup_effects()` accessor returns all levels (the forest-plot
    table) with a Holm-adjusted p-value column.
- Randomization inference: permute `w` within the sharp null of no
  interaction? No — the sharp null of *no treatment effect at all* is the
  only one replay tests support cleanly; document that the interaction
  randomization p-value tests the joint sharp null, and offer the
  studentized FRT for the weak interaction null (Wu & Ding 2021 pattern).
- KK variants: interaction on the reservoir + pair-difference regression
  in OneLik; IVWC combines per-arm interaction estimates.

## Tests

Parity vs `lm` / `glm` / `coxph` with the explicit interaction; subgroup
effects vs `emmeans::emtrends` / `marginaleffects::slopes`; golden no-op
when `moderator = NULL`; simulation with a known interaction recovers it.

## TODOs

- [ ] TODO-1: `moderator =` + `"interaction"` estimand on OLS / Lin /
  logistic / Poisson (the `LikelihoodTests` families first).
- [ ] TODO-2: `"subgroup"` estimand, `get_subgroup_effects()` table with
  multiplicity adjustment.
- [ ] TODO-3: extend to survival (Cox) and ordinal (PO) classes.
- [ ] TODO-4: KK IVWC/OneLik pass-through.
- [ ] TODO-5: `SimulationFramework` interaction generator + truth;
  forest-plot helper in `run_all_inference()` output.
