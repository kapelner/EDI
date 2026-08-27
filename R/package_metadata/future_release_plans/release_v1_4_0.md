# Release Scope: v1.4.0 — Response and Data Extensions

> **Depends on:** `release_v1_3_0.md`. Last 1.x release before 2.0.0.
> Release index over plans in `../new_feature_plans/`. (Global ordering:
> see `../new_feature_plans/_master.md`.)

Written 2026-08-27 (thematic 1.x split). **Theme.** Everything that adds
information *to the data a design carries* or extends an existing
response type's semantics without introducing a new response shape:
censoring bounds on continuous / count / proportion outcomes, a cause code
and cure fraction on survival outcomes, a treatment-received column
(encouragement designs), a moderator role for a covariate, missing
outcomes, and the survival quantile-regression estimator. Also the
one hard field-name break already decided by the user (`dead →
uncensored`), placed here so it ships in the same sweep as the new
`event_type` column, and the sequential-inference scoping that prepares
2.0.0.

## In scope (by plan)

### Survival-model extensions (one plumbing sweep)
- `../finished_features/interval_censored_survival_response.md → TODO-29`
  — the **`dead → uncensored` rename** (R, C++, Python binding; hard break,
  user decision 2026-08-19). Do it in the same sweep as:
- `competing_risks_response.md` — `event_type` cause code on `survival`;
  cause-specific Cox / log-rank recode wrappers; Aalen-Johansen CIF
  difference, Gray's test, RMTL; Fine-Gray via `cmprsk` delegation (native
  counting-process Cox kernel deferred to a later kernel spec). Decision-
  gated; v1 = exact/right-censored only.
- `cure_fraction_survival_inference.md` — `InferenceSurvivalMixtureCureWeibull`
  (+ optional promotion-time variant) via the `estimand` axis;
  `flexsurvcure` delegation first, native kernel second. Decision-gated.
- `interval_censored_survival_response_type_report.md → second wave` (if
  decided yes) — NPMLE/Turnbull Cox-analogue, stratified `icenReg`,
  current-status estimator (new implementation plan; do not reopen the
  finished one).
- `survival_quantile_regression.md` — custom self-consistent EM censored
  QR + KK IVWC/OneLik; approved design with three recorded open risks,
  each to be closed by a test before export.
- `full_glmm_for_weibull_frailty.md` — Weibull-frailty classes generalized
  from pairs to k-strata; `allow_k_wise_groups` opt-in (depends on the
  rename).

### Censoring on the other scalar types
- `censored_continuous_response.md` — generalizes the `y_L`/`y_R` bounds
  schema to `continuous`; Tobit kernel inside OLS; Lin / `crq` / robust /
  KK variants.
- `censored_count_response.md` — censored Poisson/NB; binned counts.
- `betaregscale_duplication.md` — interval-censored beta regression with
  variable dispersion.
- `semi_continuous_response_type_report.md` (if decided yes) — hurdle
  log-normal / gamma on the `continuous` type (no new enum).

### New per-subject data roles
- `encouragement_design_cace.md` — `treatment_received` column;
  `InferenceAllCACEWald`, `InferenceContin2SLS` / `Incid2SLS` (uses the
  1.1.0 HC-robust helper).
- `treatment_covariate_moderation.md` — `moderator =` with
  `"interaction"` / `"subgroup"` estimands and the forest-plot table.
- `missing_outcome_handling.md` — missing-outcome representation, Lee /
  Manski bounds, multiple-imputation wrapper with Rubin's rules, IPW for
  attrition, tipping-point sensitivity.

### Preparation for 2.0.0
- `sequential_inference.md → TODO-1..5` — the **scoping** (design-side
  ledger audit, public-accessor targeting, decision on 2.0.0 vs later);
  implementation is `release_v2_0_0.md → TODO-5`.
- `nominal_response_type_report.md → TODO-1b` — if its TODO-1 is decided
  "no" (recorded recommendation), the one-vs-rest recode vignette section
  ships here and the report closes.

## Implementation TODOs (dependency order)

- [ ] TODO-1: **Phase 0 decisions** still open for this release's gated
  items (`competing_risks → TODO-1`, `cure_fraction → TODO-1`,
  `interval_censored second wave`, `semi_continuous → TODO-1`,
  `full_glmm_for_weibull_frailty → TODO-0`) — take in the 1.1.0 sitting.
- [ ] TODO-2: **Survival plumbing sweep** — the `dead → uncensored` rename
  and `competing_risks_response.md → TODO-2` (Wave 0: `event_type`
  storage, replay, save/load) in one pass over the 31 `Surv()` sites and
  `get_effective_dead()`; golden bit-for-bit for every existing survival
  class with `event_type = 1`.
- [ ] TODO-3: **Competing risks Waves 1–3a** `competing_risks_response.md
  → TODO-3..5`; Wave 3b kernel and `SimulationFramework` (`→ TODO-6..8`)
  may trail into 2.0.0.
- [ ] TODO-4: **Cure fraction** `cure_fraction_survival_inference.md →
  TODO-2..6`.
- [ ] TODO-5: **Weibull-frailty k-strata** `full_glmm_for_weibull_frailty.md
  → TODO-1..40`.
- [ ] TODO-6: **Interval-censored second wave** (if yes) — new
  implementation plan, then execute.
- [ ] TODO-7: **Survival quantile regression** — implementation plan
  (writing-plans step), then execute with the three risk-closing tests.
- [ ] TODO-8: **Censoring track** `censored_continuous_response.md →
  TODO-1..12` → `censored_count_response.md → TODO-1..14` →
  `betaregscale_duplication.md → TODO-2..12`; then `semi_continuous →
  TODO-2..6` if decided yes.
- [ ] TODO-9: **Encouragement / CACE** `encouragement_design_cace.md →
  TODO-1..4`.
- [ ] TODO-10: **Moderation** `treatment_covariate_moderation.md → TODO-1..5`.
- [ ] TODO-11: **Missing outcomes** `missing_outcome_handling.md → TODO-1..5`.
- [ ] TODO-12: **Sequential-inference scoping** `sequential_inference.md →
  TODO-1..5`; nominal vignette section if applicable.
- [ ] TODO-13: **Release mechanics** per `release.md`, including the
  rename's migration note (the only 1.x-era break).

## Standing constraints

As the other 1.x releases, with one exception recorded here: the `dead →
uncensored` rename is a deliberate break with a migration note; every
other default reproduces 1.3.0 bit-for-bit.
