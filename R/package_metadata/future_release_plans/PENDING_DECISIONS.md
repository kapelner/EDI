# Pending owner decisions

Every open owner decision in the release TODOs lives here in full: the question, the context, the options with
their consequences, the evidence and any recommendation. Each has a stable id, `DECISION-v<version>-TODO-<n>`
(`DECISION-v1.0.6-TODO-294`), named after the TODO that raised it; a TODO with two independent decisions uses
`...-TODO-<n>a` / `...-TODO-<n>b`. The TODO entry keeps only a pointer line:

`  - Owner decision pending: [DECISION-v1.0.6-TODO-294](PENDING_DECISIONS.md#DECISION-v1.0.6-TODO-294) (<one-line question>).`

To resolve one: the owner decides; the section moves to [COMPLETED_DECISIONS.md](COMPLETED_DECISIONS.md) with the
ruling, the reasons and the date added; the TODO's pointer line becomes `  - Decided <date> (<who>): <option>; see
[DECISION-...](COMPLETED_DECISIONS.md#DECISION-...).`; the section and its table row are deleted here. Order: releases
newest first, and within a release, TODO numbers highest first (table and sections alike). Rule: see "Owner decisions: `PENDING_DECISIONS.md`,
`COMPLETED_DECISIONS.md` and `DISMISSED_DECISIONS.md`" in the repo's `CLAUDE.md`.

Last updated 2026-11-23.

## Summary

| Decision | TODO | Question |
|---|---|---|
| [DECISION-v4.0.0-TODO-3](#DECISION-v4.0.0-TODO-3) | [v4.0.0-TODO-3](release_v4_0_0.md) | Go or no-go on parametric joint multivariate models? |
| [DECISION-v3.0.0-TODO-16](#DECISION-v3.0.0-TODO-16) | [v3.0.0-TODO-16](release_v3_0_0.md) | Continuous treatments: pursue at all, and with which first-landing scope? |
| [DECISION-v3.0.0-TODO-11](#DECISION-v3.0.0-TODO-11) | [v3.0.0-TODO-11](release_v3_0_0.md) | Inference plots: all 19 families / 102 classes, or a prioritized subset first? |
| [DECISION-v3.0.0-TODO-7](#DECISION-v3.0.0-TODO-7) | [v3.0.0-TODO-7](release_v3_0_0.md) | When does the shared visualization theme ship: v3.0.0, or before the v2.0.0 diagnostics plots? |
| [DECISION-v3.0.0-TODO-1](#DECISION-v3.0.0-TODO-1) | [v3.0.0-TODO-1](release_v3_0_0.md) | Post-2.0.0 decision batch: pursue Bayesian-Stan, and on which backend and approach? |
| [DECISION-v2.0.0-TODO-6h](#DECISION-v2.0.0-TODO-6h) | [v2.0.0-TODO-6h](release_v2_0_0.md) | `ModelSelection` remaining response types: keep a 2.0.0 slot, or move to v1.4.0? |
| [DECISION-v2.0.0-TODO-1](#DECISION-v2.0.0-TODO-1) | [v2.0.0-TODO-1](release_v2_0_0.md) | The 2.0.0 decision batch for every gated track |
| [DECISION-v1.4.0-TODO-1](#DECISION-v1.4.0-TODO-1) | [v1.4.0-TODO-1](release_v1_4_0.md) | The v1.4.0 Phase 0 decisions for the gated survival / censoring items |
| [DECISION-v1.3.0-TODO-5](#DECISION-v1.3.0-TODO-5) | [v1.3.0-TODO-5](release_v1_3_0.md) | `ModelDiagnostics` contract decision gate (registry shape, result contract, severities, pilot families) |
| [DECISION-v1.1.0-TODO-218](#DECISION-v1.1.0-TODO-218) | [v1.1.0-TODO-218](release_v1_1_0.md) | Should the stratified delete-1 jackknife replace leave-one-stratum-out for every `"block"` unit? |
| [DECISION-v1.1.0-TODO-1](#DECISION-v1.1.0-TODO-1) | [v1.1.0-TODO-1](release_v1_1_0.md) | The v1.1.0 Phase 0 decision batch (ten cascading plan decisions) |
| [DECISION-v1.0.6-TODO-409a](#DECISION-v1.0.6-TODO-409a) | [v1.0.6-TODO-409](release_v1_0_6.md) | Calibration planner: keep halving a dead unit's shards below 4 replicates, or rely on the 180-minute timeout alone? |
| [DECISION-v1.0.6-TODO-409b](#DECISION-v1.0.6-TODO-409b) | [v1.0.6-TODO-409](release_v1_0_6.md) | Calibration planner: after three dead 1-replicate shards, abandon the whole unit or only those replicates? |
| [DECISION-v1.0.6-TODO-403](#DECISION-v1.0.6-TODO-403) | [v1.0.6-TODO-403](release_v1_0_6.md) | Objects saved under another EDI version keep their old method code: document only, warn on load, or rebind methods? |
| [DECISION-v1.0.6-TODO-402](#DECISION-v1.0.6-TODO-402) | [v1.0.6-TODO-402](release_v1_0_6.md) | How should audit-written bug tests skipped without a TODO be surfaced? |
| [DECISION-v1.0.6-TODO-380d](#DECISION-v1.0.6-TODO-380d) | [v1.0.6-TODO-380](release_v1_0_6.md) | Rank tests (log-rank, Gehan-Wilcoxon): keep the bootstrap fallback when the asymptotic p-value is unavailable? |
| [DECISION-v1.0.6-TODO-373](#DECISION-v1.0.6-TODO-373) | [v1.0.6-TODO-373](release_v1_0_6.md) | `InferenceIncidKKGEE`: drop the stale incidence randomization refusal, or stop advertising `rand`? |
| [DECISION-v1.0.6-TODO-371](#DECISION-v1.0.6-TODO-371) | [v1.0.6-TODO-371](release_v1_0_6.md) | OK to scale the `InferencePropGCompMeanDiff` model-based variance by the Pearson dispersion (results change)? |
| [DECISION-v1.0.6-TODO-367](#DECISION-v1.0.6-TODO-367) | [v1.0.6-TODO-367](release_v1_0_6.md) | `InferencePropQuantileRegr` on exact 0/1: Smithson-Verkuilen squeeze, or warn / error (results change)? |
| [DECISION-v1.0.6-TODO-342](#DECISION-v1.0.6-TODO-342) | [v1.0.6-TODO-342](release_v1_0_6.md) | `InferenceSuite`: down-weight or exclude rows that raised a separation / boundary warning? |
| [DECISION-v1.0.6-TODO-340](#DECISION-v1.0.6-TODO-340) | [v1.0.6-TODO-340](release_v1_0_6.md) | Retag the GLM / count-part coefficients `log_rate_ratio_conditional`? |
| [DECISION-v1.0.6-TODO-317](#DECISION-v1.0.6-TODO-317) | [v1.0.6-TODO-317](release_v1_0_6.md) | `Inf` in a numeric covariate: refuse at entry, or treat as missing under `"impute"`? |
| [DECISION-v1.0.6-TODO-308](#DECISION-v1.0.6-TODO-308) | [v1.0.6-TODO-308](release_v1_0_6.md) | Exact event time 0: refuse at data entry, or only in the parametric classes? |
| [DECISION-v1.0.6-TODO-305](#DECISION-v1.0.6-TODO-305) | [v1.0.6-TODO-305](release_v1_0_6.md) | Confirm that a one-level factor next to a two-level one (`list(dose = 1, arm = 2)`) now errors |
| [DECISION-v1.0.6-TODO-304](#DECISION-v1.0.6-TODO-304) | [v1.0.6-TODO-304](release_v1_0_6.md) | BCa on 2-block blocking designs: within-block jackknife acceleration, or percentile / BC fallback? |
| [DECISION-v1.0.6-TODO-303](#DECISION-v1.0.6-TODO-303) | [v1.0.6-TODO-303](release_v1_0_6.md) | Allow the plain randomization test at delta = 0 for incidence on `DesignFixedFactorial` / `DesignFixedBlocking`? |
| [DECISION-v1.0.6-TODO-298](#DECISION-v1.0.6-TODO-298) | [v1.0.6-TODO-298](release_v1_0_6.md) | Fixed designs with the default `n = NULL`: infer `n = nrow(X_all)`, or require `n`? |
| [DECISION-v1.0.6-TODO-294](#DECISION-v1.0.6-TODO-294) | [v1.0.6-TODO-294](release_v1_0_6.md) | Rerandomization with `prop_acceptable`: fixed cutoff, or best-of-k reference draws? |
| [DECISION-v1.0.6-TODO-291](#DECISION-v1.0.6-TODO-291) | [v1.0.6-TODO-291](release_v1_0_6.md) | `InferenceContinKKGLMM` Wald SE near sigma_b = 0: fix the kernel's `vcov`, or accept? |
| [DECISION-v1.0.6-TODO-290](#DECISION-v1.0.6-TODO-290) | [v1.0.6-TODO-290](release_v1_0_6.md) | Confirm KK `lambda` and `t_0_pct` allowed in the closed [0, 1] |
| [DECISION-v1.0.6-TODO-270](#DECISION-v1.0.6-TODO-270) | [v1.0.6-TODO-270](release_v1_0_6.md) | SPBR jackknife-Wald at 0.062: accept, raise the permuted-block threshold, or investigate? |
| [DECISION-v1.0.6-TODO-197](#DECISION-v1.0.6-TODO-197) | [v1.0.6-TODO-197](release_v1_0_6.md) | Delete or fix the unused ZOIB wrapper `.fit_zero_one_inflated_beta` (`helper_zoib.R`)? |
| [DECISION-v1.0.6-TODO-158](#DECISION-v1.0.6-TODO-158) | [v1.0.6-TODO-158](release_v1_0_6.md) | Confirm the perfect-predictor detection's three judgment calls |
| [DECISION-v1.0.6-TODO-106](#DECISION-v1.0.6-TODO-106) | [v1.0.6-TODO-106](release_v1_0_6.md) | Add `# checkmate-loose` opt-outs and put the explicit-defaults check in the pre-push hook? |
| [DECISION-v1.0.6-TODO-74](#DECISION-v1.0.6-TODO-74) | [v1.0.6-TODO-74](release_v1_0_6.md) | Jackknife on `DesignFixedBlockedCluster`: implement a stratified delete-one-cluster jackknife, fix the advice, or both? |
| [DECISION-v1.0.6-TODO-43](#DECISION-v1.0.6-TODO-43) | [v1.0.6-TODO-43](release_v1_0_6.md) | Delete the exported dead kernel `compute_coxph_rand_bootstrap_cpp`, or deprecate it first? |
| [DECISION-v1.0.6-TODO-17](#DECISION-v1.0.6-TODO-17) | [v1.0.6-TODO-17](release_v1_0_6.md) | Calibration early stopping of clearly passing null units: settle the five design questions |

## v4.0.0

<a id="DECISION-v4.0.0-TODO-3"></a>
### DECISION-v4.0.0-TODO-3: Go or no-go on parametric joint multivariate models?

- **TODO:** [v4.0.0-TODO-3](release_v4_0_0.md): **Parametric joint multivariate models**
  (`multivariate_response_modeling.md → TODO-5`).
- **Context:** this level is gated on a separate go/no-go. It requires v2.0.0's Levels 1-2
  (`multivariate_response_modeling.md → TODO-2..4`: marginal + joint sandwich covariance, randomization-based joint
  inference) and the one-`Design` named-response architecture to have shipped, and should reuse the shared C++
  backend (v4.0.0-TODO-1) if it lands first.
- **Options:** go (schedule the plan's TODO-5) or no-go. Details in the plan's TODO-5.
- **Raised:** in the release file's original scoping (no date recorded).

## v3.0.0

<a id="DECISION-v3.0.0-TODO-16"></a>
### DECISION-v3.0.0-TODO-16: Continuous treatments: pursue at all, and with which first-landing scope?

- **TODO:** [v3.0.0-TODO-16](release_v3_0_0.md): `continuous_treatments.md → TODO-1`.
- **Context:** the plan's TODO-1 is a decision gate. Independent of every other item and TODO in the v3.0.0 file.
- **Options:** (1) pursue at all, yes or no; (2) first-landing scope: parametric-only, or parametric + GPS together.
- **Raised:** 2026-09-11 (release file).

<a id="DECISION-v3.0.0-TODO-11"></a>
### DECISION-v3.0.0-TODO-11: Inference plots: all 19 families / 102 classes, or a prioritized subset first?

- **TODO:** [v3.0.0-TODO-11](release_v3_0_0.md): `inference_plots.md → TODO-1`.
- **Context:** the plan's TODO-1 is a decision gate; v3.0.0-TODO-12..14 build the reporting layer and the families
  after it.
- **Options:** (a) pursue all 19 families / 102 classes; (b) triage to a prioritized subset first.
- **Raised:** 2026-09-11 (release file).

<a id="DECISION-v3.0.0-TODO-7"></a>
### DECISION-v3.0.0-TODO-7: When does the shared visualization theme ship: v3.0.0, or before the v2.0.0 diagnostics plots?

- **TODO:** [v3.0.0-TODO-7](release_v3_0_0.md): **Decide `edi_visualization_theme.md`'s scheduling**.
- **Options:** (a) ship it as an ordinary v3.0.0 item; (b) pull it forward to land before or alongside
  `release_v2_0_0.md → TODO-6i/6j/6k`, per the "Scheduling caveat" section of `edi_visualization_theme.md`.
- **Raised:** 2026-09-10 (release file: "Not decided here").

<a id="DECISION-v3.0.0-TODO-1"></a>
### DECISION-v3.0.0-TODO-1: Post-2.0.0 decision batch: pursue Bayesian-Stan, and on which backend and approach?

- **TODO:** [v3.0.0-TODO-1](release_v3_0_0.md): **Decision batch**.
- **Context:** not yet taken for either item; neither has a Phase-0 sitting to join yet (v2.0.0's own Phase 0 does not
  cover post-2.0.0 work). It covers both plans' own "pursue this at all?" gates. Finite mixture regression's is
  implicitly decided by design (2026-09-10, in the scoping conversation; see that file's "Decisions Already Made").
  Bayesian-Stan's (`bayesian_stan_primary_analysis_report.md → TODO-1`) is genuinely undecided. v3.0.0-TODO-5 (the
  Bayesian-Stan Phase 1 plan) runs only if the answer is yes.
- **Options (Bayesian-Stan):** pursue at all; confirm `cmdstanr` as the backend; confirm the hand-written
  `.stan`-library approach; confirm the response-type entry order.
- **Recommendation (release file):** revisit both once a real post-2.0.0 planning cycle opens.
- **Raised:** release file scoping, 2026-09-10.

## v2.0.0

<a id="DECISION-v2.0.0-TODO-6h"></a>
### DECISION-v2.0.0-TODO-6h: `ModelSelection` remaining response types: keep a 2.0.0 slot, or move to v1.4.0?

- **TODO:** [v2.0.0-TODO-6h](release_v2_0_0.md): **`ModelSelection` Phase B — response-type coverage only**; also
  referenced from [v1.1.0-TODO-17y](release_v1_1_0.md) (`ModelSelection` Phase A).
- **Context:** Phase A and the selection-inclusive randomization test moved to v1.1.0-TODO-17y; only the remaining
  response types (count, proportion, survival, ordinal) are left to `model_selection_framework.md → TODO-9` (here).
  Its CV-fold need is solved by `resolve_resampling_unit()` and was never blocked on TODO-6e's substrate, so nothing
  else is left to build once here.
- **Options:** (a) keep response-type coverage alone as a 2.0.0 item; (b) move it to v1.4.0's
  response-and-data-extensions theme. See `model_selection_framework.md`'s header.
- **Raised:** 2026-09-06 (open question in both release files, "not yet resolved").

<a id="DECISION-v2.0.0-TODO-1"></a>
### DECISION-v2.0.0-TODO-1: The 2.0.0 decision batch for every gated track

- **TODO:** [v2.0.0-TODO-1](release_v2_0_0.md): **Decision batch** for every gated 2.0.0 track.
- **Questions (each recorded in its owning plan):** the multi-arm research question on K-arm KK; each response-shape
  plan's TODO-1; the GPU / quantum TODO-1s; nominal's TODO-1 (with its recorded "no" recommendation: nominal goes
  ahead only if its TODO-1 overturns it, v2.0.0-TODO-4); the audit-commissioned plans' TODO-1s (v2.0.0-TODO-2: "each
  TODO-1 is a decision"); censored ordinal responses' TODO-1 (v2.0.0-TODO-6m: go/no-go, the closed-interval bounds
  convention, native kernels vs delegation, first-wave membership).
- **Context:** may be taken in the v1.1.0 Phase 0 sitting ([DECISION-v1.1.0-TODO-1](#DECISION-v1.1.0-TODO-1)).
- **Raised:** release file scoping, 2026-08-27.

## v1.4.0

<a id="DECISION-v1.4.0-TODO-1"></a>
### DECISION-v1.4.0-TODO-1: The v1.4.0 Phase 0 decisions for the gated survival / censoring items

- **TODO:** [v1.4.0-TODO-1](release_v1_4_0.md): **Phase 0 decisions** still open for this release's gated items.
- **Questions:** `competing_risks → TODO-1`, `cure_fraction → TODO-1`, the interval-censored second wave (yes/no; gates
  v1.4.0-TODO-6), `semi_continuous → TODO-1` (gates the semi-continuous half of v1.4.0-TODO-8),
  `full_glmm_for_weibull_frailty → TODO-0`.
- **Context:** to be taken in the v1.1.0 sitting ([DECISION-v1.1.0-TODO-1](#DECISION-v1.1.0-TODO-1)).
- **Raised:** release file scoping (no date recorded).

## v1.3.0

<a id="DECISION-v1.3.0-TODO-5"></a>
### DECISION-v1.3.0-TODO-5: `ModelDiagnostics` contract decision gate (registry shape, result contract, severities, pilot families)

- **TODO:** [v1.3.0-TODO-5](release_v1_3_0.md): **`ModelDiagnostics` — contract** (`model_diagnostics_framework.md →
  TODO-1, 2, 4, 5, 6`).
- **Questions (plan TODO-1, the decision gate):** the registry field shape (per class vs per component); the typed
  check-result contract; the severity taxonomy and what the report does with each level; and ratify the pilot families
  (the gate text says "the nine pilot families"; since 2026-10-22 the pilot is cut to the Incidence GLM family only,
  v1.3.0-TODO-6, so the ratification is of that pilot).
- **Raised:** 2026-10-20 (moved to v1.3.0 by user decision).

## v1.1.0

<a id="DECISION-v1.1.0-TODO-218"></a>
### DECISION-v1.1.0-TODO-218: Should the stratified delete-1 jackknife replace leave-one-stratum-out for every `"block"` unit?

- **TODO:** [v1.1.0-TODO-218](release_v1_1_0.md): **`InferenceCountPoisson` `~1`: every model-based test oversized
  on the blocking designs** (fix accepted by the owner 2026-11-19).
- **Context:** the fix uses the stratified delete-1 jackknife only below 5 blocks. With 5 or more large strata,
  leave-one-stratum-out still treats fixed strata as sampled units.
- **Question:** should the stratified delete-1 jackknife replace it for every `"block"` unit, not only below 5 blocks?
- **Raised:** 2026-11-19, by the investigating agent.

<a id="DECISION-v1.1.0-TODO-1"></a>
### DECISION-v1.1.0-TODO-1: The v1.1.0 Phase 0 decision batch (ten cascading plan decisions)

- **TODO:** [v1.1.0-TODO-1](release_v1_1_0.md): **Phase 0 decision batch** (ask the user, no code; one sitting).
- **Context:** this is `_master.md` Phase 0 verbatim, minus `marginal_estimand_report.md → TODO-1` (moved to v1.0.0
  and decided yes there, 2026-08-18), plus `expanded_estimate_report.md → TODO-1` (moved back the same day). Take them
  in this order, because the decisions cascade:
  1. `expanded_estimate_report.md → TODO-1` (`estimate_type` design; blocks the API shape of steps 3 and 5 below);
  2. `firth_penalties_report.md → TODO-1` + `l1_l2_penalties_all_likelihood_paths_report.md → TODO-1` (joint
     penalized-fitting inference semantics);
  3. `median_bias_correction_likelihood_paths_report.md → TODO-1` (after Firth);
  4. `bias_correction_cox_snell.md → TODO-1` + `cordeiro_mccullagh_bias_correction_report.md → TODO-1` (one project);
  5. `modified_profile_likelihood_report.md → TODO-1`;
  6. `likrat_correction_bartlett.md → TODO-1` (incl. ordering vs. score / gradient corrections);
  7. `bootstrap_calibrated_lr_report.md → TODO-2` (Difficult tier yes/no);
  8. the response-type decisions in one pass: `nominal_… → TODO-1`, `rank_choice_… → TODO-1`,
     `semi_continuous_… → TODO-1`, `multivariate_… → TODO-1`, `compositional_… → TODO-1`,
     `longitudinal_repeated_measures_… → TODO-1`;
  9. `gpu_optimizations.md → TODO-1` and `→ TODO-7` (backend / build story);
  9b. `quantum_upgrade.md → TODO-1` (added 2026-08-23: vignette+hook only / nothing / full A1+A3; taken right after
      step 9 so it reuses the backend / dispatch answer; a "yes" of either kind also commits to its hardware-detection
      + classical-fallback spec, §I.7 there);
  10. `interval_censored_survival_response_type_report.md → TODO-1` (second-wave semiparametric yes/no).
- **Also joins this sitting:** the decision batches the v1.1.0 file defers to Phase 0 (v1.1.0-TODO-20, -21; the
  v1.3.0 many-by-many TODO-1), [DECISION-v1.4.0-TODO-1](#DECISION-v1.4.0-TODO-1) and possibly
  [DECISION-v2.0.0-TODO-1](#DECISION-v2.0.0-TODO-1).
- **Raised:** release file scoping, 2026-08-18.

## v1.0.6

<a id="DECISION-v1.0.6-TODO-409a"></a>
### DECISION-v1.0.6-TODO-409a: Calibration planner: keep halving a dead unit's shards below 4 replicates, or rely on the 180-minute timeout alone?

- **TODO:** [v1.0.6-TODO-409](release_v1_0_6.md): **Calibration planner: shards of slow units time out and the units get abandoned.**
- **Context:** owner decision 2026-11-22 took both fixes: halve a unit's shard after each timeout (down to 1 replicate)
  and give units that lost a shard a 180-minute job timeout (75 otherwise). A shard runs its replicates in parallel on 4
  cores and the first round is never cut by the 25-minute deadline, so a shard of 4 or fewer replicates lasts about as
  long as its slowest replicate (4-replicate `InferenceOrdinalKKCLMM` n = 1000 shards took up to ~66 min).
- **Options:** (a) keep the halving as built: going from 4 to 2 replicates only lowers the odds of drawing a slow
  replicate, and roughly doubles the number of jobs and their setup time; (b) stop halving at 4 replicates (one round on
  4 cores) and rely on the 180-minute timeout; (c) drop the halving entirely, timeout only.
- **Evidence:** dry run of the planner on the campaign 2026-11-15-e36c7710 files: 3 abandoned units return with 2-3
  replicates per shard (262 extra shards, all theirs); every other shard unchanged.
- **Recommendation (coordinator):** (b): the timeout does the work, and fewer jobs keep the waves faster.
- **Raised:** 2026-11-23, by the planner agent working on v1.0.6-TODO-409.

<a id="DECISION-v1.0.6-TODO-409b"></a>
### DECISION-v1.0.6-TODO-409b: Calibration planner: after three dead 1-replicate shards, abandon the whole unit or only those replicates?

- **TODO:** [v1.0.6-TODO-409](release_v1_0_6.md): **Calibration planner: shards of slow units time out and the units get abandoned.**
- **Context:** under the new rule only dead 1-replicate shards count toward `--max-dead 3`. Three of them still abandon
  the whole unit, even if hundreds of its other 1-replicate shards finish.
- **Options:** (a) keep it: three single replicates that cannot finish in 180 minutes mean the unit is not
  calibratable at this cost; (b) abandon only the replicates that died (the cell is reported with fewer replicates,
  and its gate uses the replicates it has).
- **Evidence:** none yet; no unit has reached 1-replicate shards. (b) risks a biased replicate set if the slow fits
  are systematically different (compare v1.1.0-TODO-264, a bias measured on an abandoned unit's finished replicates).
- **Recommendation (coordinator):** (a) for now; revisit if a unit actually reaches it.
- **Raised:** 2026-11-23, by the planner agent working on v1.0.6-TODO-409.

<a id="DECISION-v1.0.6-TODO-403"></a>
### DECISION-v1.0.6-TODO-403: Objects saved under another EDI version keep their old method code: document only, warn on load, or rebind methods?

- **TODO:** [v1.0.6-TODO-403](release_v1_0_6.md): **A saved design or inference object carries its own method code.**
- **Context:** R6 objects serialize their method closures. A design saved with `saveRDS()` under EDI 1.0.4 and
  restored under a later EDI runs the 1.0.4 methods, while new objects run the new ones; nothing tells the user.
  Saved designs already carry a version stamp (`get_edi_version_created()`), and `check_version_compat` exists.
- **Options:** (a) document it in `?Design` and the reproducibility vignette (saved objects reproduce the version
  that saved them; refit with a new object to use the new code); (b) (a) plus a warning on first use when the stamp
  differs from the installed version; (c) rebind methods to the installed class on load (objects then follow the new
  code, which breaks exact reproduction of the old allocations), with (a).
- **Evidence:** reported by the save-load docs-scenario agent as something it could not determine from the docs.
- **Raised:** 2026-11-22, coordinator, from the audit free-text sweep.

<a id="DECISION-v1.0.6-TODO-402"></a>
### DECISION-v1.0.6-TODO-402: How should audit-written bug tests skipped without a TODO be surfaced?

- **TODO:** [v1.0.6-TODO-402](release_v1_0_6.md): **Audit-written bug tests that are skipped without a TODO never
  reach any issue.**
- **Context:** numerical-robustness merges bug tests behind `skip("open a release TODO for this")`; test-suite-health
  sees them as `unconditional-skip` in `mechanical.json`, but `audit_decisions.py` and issue #56 never list them, so
  17 sat untracked (now v1.0.6-TODO-385..401).
- **Options:** (a) have `audit_decisions.py` read test-suite-health's `unconditional-skip` findings as open mechanical
  findings, cleared when the skip names a release TODO; (b) a pre-push / CI gate that fails on any
  `skip("open a release TODO for this")`; (c) have the numerical-robustness audit file the TODO itself in its PR
  instead of the placeholder skip; (d) leave as is and rely on periodic sweeps.
- **Raised:** 2026-11-22, coordinator, from the audit free-text sweep.

<a id="DECISION-v1.0.6-TODO-380d"></a>
### DECISION-v1.0.6-TODO-380d: Rank tests (log-rank, Gehan-Wilcoxon): keep the bootstrap fallback when the asymptotic p-value is unavailable?

- **TODO:** [v1.0.6-TODO-380](release_v1_0_6.md) (ticked): **A separate opt-in design-conservative Bartlett option, and
  "the testing type you ask for is the test you get".**
- **Context:** under the owner principle "If the user wants wald, we should always give wald" (2026-11-21), the Wald
  paths that fell back to the nonparametric bootstrap now return NA with a recorded reason and a warning. The agent
  left two fallbacks alone because they are not Wald tests: `InferenceSurvivalLogRank`'s p-value falls back to the
  bootstrap when its variance or the interval-censored p-value is missing (`R/EDI/R/inference_survival_log_rank.R`
  ~L181-187), and `InferenceSurvivalGehanWilcox`'s asymptotic p-value does the same for interval-censored data (~L196).
- **Options:** (a) keep both fallbacks and document them; (b) apply the same rule: the asymptotic p-value is NA with a
  reason and a warning, and the bootstrap stays its own method (results change where a fallback fired; NEWS entry).
- **Also to confirm (judgment call by the agent):** `InferenceCountPoisson`'s best-available
  `compute_lik_ratio_bartlett_*` pair was made model-only too, not only the approx pair, so the two cannot disagree.
  Revert those lines (`R/EDI/R/inference_count_poisson.R` ~L415-451) if only the approx pair should change.
- **Recommendation (agent):** (b), for one rule across testing types; keep the best-available pair model-only.
- **Raised:** 2026-11-23, by the agent that implemented v1.0.6-TODO-380.

<a id="DECISION-v1.0.6-TODO-373"></a>
### DECISION-v1.0.6-TODO-373: `InferenceIncidKKGEE`: drop the stale incidence randomization refusal, or stop advertising `rand`?

- **TODO:** [v1.0.6-TODO-373](release_v1_0_6.md): **`InferenceIncidKKGEE` can never return a randomization
  p-value.**
- **Context:** the KK GEE mixin's `compute_rand_two_sided_pval` override (`inference_mixin_kk_gee_shared.R` ~L125)
  stops with "not supported for incidence. Use Zhang method." unless the design is a rerandomization design, but the
  class accepts only KK designs, so the call always errors. The base method has allowed draw-based incidence p-values
  since 2026-10-20, so the refusal looks stale.
- **Options:** (a) drop the refusal and use the draw-based path, as the base does; (b) remove `rand` from the class's
  supported procedures and say so in its docs. Test either way.
- **Raised:** 2026-11-21, by the agent that fixed v1.0.6-TODO-328.

<a id="DECISION-v1.0.6-TODO-371"></a>
### DECISION-v1.0.6-TODO-371: OK to scale the `InferencePropGCompMeanDiff` model-based variance by the Pearson dispersion (results change)?

- **TODO:** [v1.0.6-TODO-371](release_v1_0_6.md): **`InferencePropGCompMeanDiff`'s `"model_based"` variance fallback
  uses the unscaled Bernoulli information for a fractional response.**
- **Context:** `resolve_effect_variance()` / `model_based_covariance_matrix()` (`inference_proportion_gcomp.R`
  ~L786-840, docs :92-110) use the binomial Fisher information, which `?InferencePropFractionalLogit` (:12-20) calls
  wrong for a fractional y; on the repro it is 2.5 x the sandwich SE.
- **Proposed fix (needs the owner's OK; results change, NEWS):** scale by the Pearson dispersion and document it;
  `model_based` SE on the repro about 0.0507 (quasi-binomial delta method).
- **Raised:** 2026-11-21, docs-scenarios run 44883784401 (ds-proportion-44883784401-f7).

<a id="DECISION-v1.0.6-TODO-367"></a>
### DECISION-v1.0.6-TODO-367: `InferencePropQuantileRegr` on exact 0/1: Smithson-Verkuilen squeeze, or warn / error (results change)?

- **TODO:** [v1.0.6-TODO-367](release_v1_0_6.md): **Exact 0s and 1s in proportion outcomes: Beta's silent squeeze,
  QuantileRegr's eps clamp, and the cookbook's open-interval claim.**
- **Context:** `InferencePropQuantileRegr` clamps to `.Machine$double.eps` before the logit
  (`inference_continuous_quantile_regr.R:139`, `helper_math.R:26`), giving a "log-odds shift" of about +/-34 with
  p ~ 1e-117 at low / high tau, no warning. Same clamp in the rand kernel's `zero_one_logit_clamp`. Precedent:
  v1.0.6-TODO-60.
- **Options (results change; owner OK and NEWS needed):** (a) apply the Smithson-Verkuilen squeeze, as
  `sanitize_beta_response()` does for Beta; (b) warn on exact 0/1; (c) error on exact 0/1.
- **Raised:** 2026-11-21, docs-scenarios run 44883784401 (ds-proportion-44883784401-f2).

<a id="DECISION-v1.0.6-TODO-342"></a>
### DECISION-v1.0.6-TODO-342: `InferenceSuite`: down-weight or exclude rows that raised a separation / boundary warning?

- **TODO:** [v1.0.6-TODO-342](release_v1_0_6.md): **The suite drops a valid exact p-value and CI when only the
  estimate is non-estimable, and keeps separated fits at full weight.**
- **Context:** on the incidence F9 repro, GComp RR (p = 0, CI 2.7e-10 to 7.6e-10) with its own separation warning
  stays `ok` at full weight in Combined Evidence (`inference_suite.R:1759-1771`).
- **Options:** (a) down-weight rows that raised a separation / boundary warning; (b) exclude them from the
  combination. The other half of the fix (keep the p / CI cells a class still returns when only the estimate stage is
  non-estimable) needs no decision.
- **Raised:** 2026-11-21, docs-scenarios run 44883784401 (ds-incidence-44883784401-f9).

<a id="DECISION-v1.0.6-TODO-340"></a>
### DECISION-v1.0.6-TODO-340: Retag the GLM / count-part coefficients `log_rate_ratio_conditional`?

- **TODO:** [v1.0.6-TODO-340](release_v1_0_6.md): **Count estimand tags and the QuasiPoisson/RobustPoisson
  randomization-CI scale.**
- **Context:** `EDI_INFERENCE_ESTIMAND_TAGS` (`inference_class_registry.R:1621-1634`) tags Poisson, Quasi, Robust,
  NegBin, ZIP and HurdlePoisson `log_rate_ratio_marginal` but HurdleNegBin and ZINB `log_rate_ratio_conditional`,
  while every object reports `get_estimand() == "conditional"`; Combined Evidence groups by these tags.
- **Options:** (a) retag GLM / count-part coefficients `log_rate_ratio_conditional`, keeping `marginal` for true
  marginal estimands (e.g. PoissonKKGEE); (b) keep the current tags. The rest of the fix (treat Quasi / Robust as
  model-scale, drop the internal path from the message) needs no decision.
- **Raised:** 2026-11-21, docs-scenarios run 44883784401 (ds-inference-suite-44883784401-f2, -f8).

<a id="DECISION-v1.0.6-TODO-317"></a>
### DECISION-v1.0.6-TODO-317: `Inf` in a numeric covariate: refuse at entry, or treat as missing under `"impute"`?

- **TODO:** [v1.0.6-TODO-317](release_v1_0_6.md): **An `Inf` covariate is accepted at enrollment, and inference later
  fails with `qr.default` "NA/NaN/Inf in foreign function call".**
- **Options:** (a) refuse `Inf` / `-Inf` in numeric covariates in `add_one_subject()` and
  `add_all_subjects_to_experiment()` with a message naming column and rows (the entry's fix); (b) treat them as
  missing under `"impute"` (as NaN already is). Either way, say so in a message.
- **Recommendation (entry):** (a), noting the owner may prefer (b).
- **Raised:** 2026-11-20, docs-scenario audit (ds-missing-data-44358267779-f4), filed by the coordinator.

<a id="DECISION-v1.0.6-TODO-308"></a>
### DECISION-v1.0.6-TODO-308: Exact event time 0: refuse at data entry, or only in the parametric classes?

- **TODO:** [v1.0.6-TODO-308](release_v1_0_6.md): **An exact event time of 0 is accepted, and
  `InferenceSurvivalWeibullRegr` then returns NA estimate, CI and p-value with no warning.**
- **Options:** (a) refuse an exact time of 0 at entry (require y > 0; a time-0 event is left-censored, `y_L = 0,
  y_R = <first assessment>`, which the message should say): one check in `assert_y()`, but it changes what every
  survival class accepts (Cox, log-rank and RMST give finite results on such data today); (b) keep accepting it and
  have the parametric classes (Weibull, other AFT / frailty models) refuse with a reason naming the zero times: keeps
  those working, needs a reason string in each AFT / frailty class.
- **Recommendation (agent, 2026-11-21):** (b) is the less disruptive.
- **Raised:** 2026-11-20, docs-scenario audit (ds-survival-censoring-44358267779-f3); investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-305"></a>
### DECISION-v1.0.6-TODO-305: Confirm that a one-level factor next to a two-level one (`list(dose = 1, arm = 2)`) now errors

- **TODO:** [v1.0.6-TODO-305](release_v1_0_6.md) (ticked): **`DesignFixedFactorial` accepts a non-integer number of
  levels.**
- **Context:** the fix requires every factor to be a whole number >= 2. A single-level factor next to a two-level one
  was accepted before and pinned as accepted by
  `test-factorial-design-two-arm-mapping-balance-and-factor-validation-reference.R`; per the entry's "1 errors" it now
  errors, and that assertion was changed to expect the error.
- **Options:** (a) confirm (one-level factors error); (b) allow one-level factors again.
- **Raised:** 2026-11-21, by the agent that fixed the TODO (judgment call beyond the finding).

<a id="DECISION-v1.0.6-TODO-304"></a>
### DECISION-v1.0.6-TODO-304: BCa on 2-block blocking designs: within-block jackknife acceleration, or percentile / BC fallback?

- **TODO:** [v1.0.6-TODO-304](release_v1_0_6.md): **On the 2 x 2 main-effect design the default BCa bootstrap CI and
  p-value and every jackknife unit return NA.**
- **Options (part (1) of the fix; both change the default BCa result on blocking designs):** (a) compute the BCa
  acceleration from a leave-one-subject-out jackknife within blocks (the jackknife currently refuses this on blocking
  designs with blocks of size > 1, `jackknife_block_size_gt_one_unsupported()`, the same refusal as v1.0.6-TODO-74);
  (b) fall back to the percentile / BC interval with a warning that says so.
- **Context:** parts (2)-(3) (the messages) depend on the advice chosen for
  [DECISION-v1.0.6-TODO-74](#DECISION-v1.0.6-TODO-74) and [DECISION-v1.0.6-TODO-303](#DECISION-v1.0.6-TODO-303) (which
  procedures run for incidence on these designs), so they are best done together after those rulings.
- **Raised:** 2026-11-20, docs-scenario audit (ds-factorial-44358267779-f3); investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-303"></a>
### DECISION-v1.0.6-TODO-303: Allow the plain randomization test at delta = 0 for incidence on `DesignFixedFactorial` / `DesignFixedBlocking`?

- **TODO:** [v1.0.6-TODO-303](release_v1_0_6.md): **Randomization tests refuse every incidence analysis on
  `DesignFixedFactorial` and `DesignFixedBlocking` although `supports("randomization_test")` is TRUE, and the "Use
  Zhang method" advice then fails.**
- **Options:** (a) allow it (as v1.0.6-TODO-110 did for custom statistics): parts (1)-(3) of the fix reduce to lifting
  `supports_rand_pval_for_incidence()`'s refusal for delta = 0 and keeping it for nonzero delta, and
  `supports("randomization_test")` is already right; (b) keep refusing: (1) makes `supports()` read
  `supports_rand_pval_for_incidence()`, (2)/(3) are message changes (name `InferenceIncidExactFisher` / CMH, mention
  Zhang only on Zhang-eligible designs), and (4) is an article and Rd change.
- **Context:** the two branches touch the same lines, so doing either before the ruling would be wasted work. The
  docs-scenario audit later added `DesignFixediBCRD` to the scope.
- **Raised:** 2026-11-20, docs-scenario audit (ds-factorial-44358267779-f1, -f2); investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-298"></a>
### DECISION-v1.0.6-TODO-298: Fixed designs with the default `n = NULL`: infer `n = nrow(X_all)`, or require `n`?

- **TODO:** [v1.0.6-TODO-298](release_v1_0_6.md): **Every fixed design accepts the default `n = NULL`, then
  `add_all_subjects_to_experiment()` errors although `X_all` gives n.**
- **Options:**
  - (a) infer `n = nrow(X_all)` in `add_all_subjects_to_experiment()` when `n` is NULL, set `fixed_sample = TRUE` and
    size `w` / `y` / caches there; each constructor that reads `n` before subjects arrive (Optimal, Rerandomization
    caches, Blocking / Cluster sizing, any `prob_T * n` target) must be checked, so it touches every fixed design;
  - (b) make `n` required in the fixed-design constructors (error at `$new()`, drop `= NULL` from the usage and Rd):
    small and safe, but breaks code that relies on the default reaching a later error;
  - (c) keep `n = NULL` but error at `$new()` with "fixed designs need n (or call ...)": the same as (b) for users.
  - Either way `assign_w_to_all_subjects()` before subjects are added must give a clear error.
- **Recommendation (agent, 2026-11-21):** (a) is what the help suggests a user expects; (b) is the smaller change.
- **Raised:** 2026-11-20, docs-scenario audit (ds-fixed-designs-44358267779-f6, ds-clusters-blocking-44358267779-f5);
  investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-294"></a>
### DECISION-v1.0.6-TODO-294: Rerandomization with `prop_acceptable`: fixed cutoff, or best-of-k reference draws?

- **TODO:** [v1.0.6-TODO-294](release_v1_0_6.md): **The realized `DesignFixedRerandomization` allocation with
  `prop_acceptable` comes from a different law than its randomization reference, and the randomization test
  over-rejects (7.25% at nominal 5%).**
- **Options (each changes randomization p-values and CIs):**
  - (a) define `prop_acceptable` as a fixed cutoff: the `prop_acceptable` quantile of M(w), estimated once from a
    large base sample (cached, seeded), then used as `obj_val_cutoff` for both the realized and the reference draws.
    Changes realized allocations and needs a cached quantile estimate.
  - (b) make the reference draws exchangeable with the realized one: draw each reference allocation as the best of
    `round(1 / prop_acceptable)` independently. Keeps every realized allocation as it is today and only changes the
    reference, at the same cost as now (501 groups of `round(1 / prop_acceptable)` draws = the 50,100 base draws
    already made, each group keeping its best instead of the best 501 overall).
- **Recommendation (agent, 2026-11-21):** (b) looks like the smaller and safer change.
- **Raised:** 2026-11-20, docs-scenario audit (ds-fixed-designs-44358267779-f2); investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-291"></a>
### DECISION-v1.0.6-TODO-291: `InferenceContinKKGLMM` Wald SE near sigma_b = 0: fix the kernel's `vcov`, or accept?

- **TODO:** [v1.0.6-TODO-291](release_v1_0_6.md) (ticked; the parametric-bootstrap fix is done).
- **Context:** on the F4 repro the Wald CI is [0.585, 1.056] (SE 0.120) against lmer's 0.233. The kernel's `vcov`
  (inverse full observed information) at log_sigma_b = -4.0 has a negative diagonal for log_sigma_b and a w SE of
  0.120, so the Wald SE looks wrong when sigma_b is near 0. The finding's run (older build) had Wald SE 0.230. The
  TODO's "within 25% of the Wald SE" test was written against the OLS SE instead.
- **Options:** (a) fix the Wald SE near the sigma_b = 0 boundary (new TODO); (b) accept and document.
- **Raised:** 2026-11-21, by the agent that fixed the TODO ("found, not changed (owner decision)").

<a id="DECISION-v1.0.6-TODO-290"></a>
### DECISION-v1.0.6-TODO-290: Confirm KK `lambda` and `t_0_pct` allowed in the closed [0, 1]

- **TODO:** [v1.0.6-TODO-290](release_v1_0_6.md) (ticked): **KK14/KK21 constructors accept `lambda` and `t_0_pct`
  outside [0, 1].**
- **Context:** the entry asked for 0 < lambda < 1; the fix keeps the endpoints legal: `lambda = 0` (never match) is
  used by `test-kk14-design-matching-threshold-early-phase-and-pair-invariants-reference.R`, and `lambda = 1` runs
  (matches whenever the reservoir is non-empty, 15 pairs of 30).
- **Options:** (a) confirm the closed [0, 1]; (b) tighten to (0, 1) and change the test.
- **Raised:** 2026-11-21, by the agent that fixed the TODO (judgment call against the entry's text).

<a id="DECISION-v1.0.6-TODO-270"></a>
### DECISION-v1.0.6-TODO-270: SPBR jackknife-Wald at 0.062: accept, raise the permuted-block threshold, or investigate?

- **TODO:** [v1.0.6-TODO-270](release_v1_0_6.md): **Permuted-block jackknife with few units per stratum is
  oversized.**
- **Context:** the implemented rule (switch to `"observation_within_block"` below
  `EDI_JACKKNIFE_MIN_PERMUTED_BLOCKS_PER_STRATUM` = 5) makes the RandomBlockSize cell nominal, but the SPBR cell stays
  at ~0.062 (8-9 blocks per stratum, so the switch never fires there): reps 1001-2000 0.062 [0.048, 0.079]; the
  2000-rep pool ~0.062 [0.052, 0.074]; `observation_within_block` there 0.055 [0.042, 0.071].
- **Options:** (a) accept SPBR at 0.062 (open a TODO per the calibration rule); (b) raise the threshold (e.g. 10
  would switch SPBR here too: `observation_within_block` 0.055); (c) investigate SPBR separately.
- **Raised:** 2026-11-20, by the implementing agent.

<a id="DECISION-v1.0.6-TODO-197"></a>
### DECISION-v1.0.6-TODO-197: Delete or fix the unused ZOIB wrapper `.fit_zero_one_inflated_beta` (`helper_zoib.R`)?

- **TODO:** [v1.0.6-TODO-197](release_v1_0_6.md): **Every `betareg` call in EDI fails, so the beta fits silently fall
  back to OLS on logit(y).**
- **Context:** the 2026-11-17 verdict re-review (`new_feature_plans/v1_0_5/algorithm_choice_audit.md`, section
  "2026-11-17: verdict re-review") put the ZOIB wrapper on hold. Unverified suspicion there: `helper_zoib.R:135,143`
  reads `fit$coefficients`, which `fast_zero_one_inflated_beta_cpp` never returns (it returns `params`), so the wrapper
  would return NULL on real data; it has no callers and the bulk tests mock the kernel.
- **Options:** (a) delete the wrapper; (b) fix it.
- **Raised:** 2026-11-17 (verdict re-review); cited as an open owner decision in v1.0.6-TODO-197 (2026-11-19).

<a id="DECISION-v1.0.6-TODO-158"></a>
### DECISION-v1.0.6-TODO-158: Confirm the perfect-predictor detection's three judgment calls

- **TODO:** [v1.0.6-TODO-158](release_v1_0_6.md) (ticked): **Detect perfect predictors in the inference covariates,
  drop them and warn.**
- **Judgment calls made by the implementing agent, for the owner to confirm or change:**
  1. ties drop the union (e.g. `y = 3z + 0.4 x1 + 1.5 w` drops z and x1), vs a deterministic single pick;
  2. the lazy re-run tracks the object's own `y`, not the design;
  3. covariate-ignoring classes skip the check (no warning there).
- **Context:** factor-dummy leaks in the component-formula filter are untested (kept in the TODO).
- **Raised:** 2026-11-18, by the implementing agent.

<a id="DECISION-v1.0.6-TODO-106"></a>
### DECISION-v1.0.6-TODO-106: Add `# checkmate-loose` opt-outs and put the explicit-defaults check in the pre-push hook?

- **TODO:** [v1.0.6-TODO-106](release_v1_0_6.md) (ticked): **Audit every other checkmate assertion in `R/EDI/R/`.**
- **Context:** the static check `R/package_tests/check_checkmate_explicit_defaults.R` flags 16 sites today, all
  loose but fine. It would need `# checkmate-loose: <why>` opt-outs at those sites before it can join the pre-push
  hook.
- **Options:** (a) add the opt-outs and gate pre-push on the check; (b) keep it a manual check.
- **Raised:** 2026-11-18, by the implementing agent.

<a id="DECISION-v1.0.6-TODO-74"></a>
### DECISION-v1.0.6-TODO-74: Jackknife on `DesignFixedBlockedCluster`: implement a stratified delete-one-cluster jackknife, fix the advice, or both?

- **TODO:** [v1.0.6-TODO-74](release_v1_0_6.md): **The jackknife silently returns `c(NA, NA)` on
  `DesignFixedBlockedCluster`.**
- **Context:** on a blocking design `jackknife_block_size_gt_one_unsupported()` (`inference_all_abstract_non_param_boot.R`
  ~L1332) refuses every unit except block / permuted_block / observation_within_block / pair / matched_set, so
  `unit = "cluster"` (and `"auto"`) is refused before any layout is built. Needs a new statistical method.
- **Options:**
  - (a) implement a stratified delete-one-cluster jackknife (clusters as deletion units, blocks as strata, the existing
    `jackknife_stratified_layout()` machinery): the natural estimator, but needs a validity check and calibration;
  - (b) keep the refusal and change the advice: the cluster-independence warning on a blocked-cluster design should
    name `unit = "block"` only when there are enough blocks, and otherwise a cluster bootstrap / CR2 SE, never the
    model-based SE;
  - (c) both.
- **Agent's note (2026-11-21):** (b) is a small message change; (a) is the real fix.
- **Raised:** 2026-11-17 (cluster-and-factorial article agent); investigated 2026-11-21 (agent).

<a id="DECISION-v1.0.6-TODO-43"></a>
### DECISION-v1.0.6-TODO-43: Delete the exported dead kernel `compute_coxph_rand_bootstrap_cpp`, or deprecate it first?

- **TODO:** [v1.0.6-TODO-43](release_v1_0_6.md): **Remove three dead C++ code paths.**
- **Context:** `compute_coxph_rand_bootstrap_cpp` (`src/fast_coxph_regression.cpp` ~L1135) has no caller in R or C++;
  only a reference test calls it. It is exported (`NAMESPACE` L147) but documented `@keywords internal`.
- **Options:** (a) delete it, its export, Rd page and test case, with a NEWS line (an exported internal kernel is
  removed): the entry's default; (b) deprecate it first, as v1.0.6-TODO-38 does for `robust_negbinreg`.
- **Raised:** 2026-11-17, by the agent that filed the TODO ("if the owner prefers").

<a id="DECISION-v1.0.6-TODO-17"></a>
### DECISION-v1.0.6-TODO-17: Calibration early stopping of clearly passing null units: settle the five design questions

- **TODO:** [v1.0.6-TODO-17](release_v1_0_6.md): **Stop clearly passing null cells early in calibration campaigns.**
- **Context:** two looks per null unit (e.g. at 500 and 1000 replicates); a unit stops at the first look if every test
  in it is clearly inside its bound. Rough saving 30-50% of null work. These questions are to be settled before any
  code.
- **Questions:**
  1. Stopping only for "clearly passing" is non-binding futility stopping: it cannot add false flags, but it lowers the
     power to flag a mildly miscalibrated cell (for example a true size of 0.06). Choose the first-look margin from the
     power that must be kept, and check it by simulation of the planner with known true sizes.
  2. Multiple testing: the campaign runs Benjamini-Hochberg over every test in the plan with unrun tests as p = 1, so
     interim flags are never withdrawn. Define the p-value of a stopped unit (its first-look p-value is valid under
     non-binding futility) and show that this keeps `m_total` and the monotonicity argument intact.
  3. Precision and the convergence analysis: stopped units have wider intervals; the |error| vs n_eff slopes and the
     per-class pages must weight by replicates actually run, and the README must say which units stopped.
  4. Estimates after a sequential stop are slightly biased; say whether the published size / coverage use them as
     they are.
  5. Confirmation replicates (5,000 at 0.01 / m_total) are unchanged.
- **Raised:** 2026-11-11, owner (the entry is an owner exception to the v1.0.6 entry rule).
