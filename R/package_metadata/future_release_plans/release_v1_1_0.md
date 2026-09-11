# Release Scope: v1.1.0

> **Depends on:** `release_v1_0_0.md` (the contract freeze ships first; every
> plan below is additive on top of the frozen substrate), plus the in-scope
> plans listed below — like the 1.0.0 file, this document is the release
> index that batches them, not new work of its own. (Global ordering: see
> `_master.md`; this file draws the next release line across it.)

Written 2026-08-17, user decision. **v1.1.0 is defined as "everything
currently open in `new_feature_plans/` that is not inside the v1.0.0 release
line"** — the entire additive backlog in one release, superseding
`release_v1_0_0.md → TODO-5`'s earlier guess that 1.1.0 would be only a small
first wave (estimate/estimand + the Easy-tier bias corrections).

Amended 2026-08-23 (user decision): `performance_profiling_and_upgrades.md`
— the native-kernel performance record, moved from
`audits/perf_experiments.md` on 2026-08-22 and extended with a forward-looking
audit plan (§8, TODO-132..179: measurement infrastructure, generated-code and
assembly-level audits, vectorization/compiler levers, allocator/layout,
OpenMP/BLAS/fork parallelism, algorithmic work such as adaptive quadrature,
R-layer and end-to-end profiling, a bare-metal/AWS session) — is written into
the v1.1.0 scope as a second kernel/perf lane, `TODO-4b` below.

> **Amended 2026-08-27 (user decision): thematic release split.** The
> "everything open goes into 1.1.0" rule below is **superseded**. The open
> backlog is split across **five** release files by one rule — **1.x =
> improvements on the current codebase plus simple additions on the
> existing architecture and the six scalar response types; 2.0.0 =
> genuinely new functionality requiring large refactorings or new
> architecture** — and the 1.x releases are grouped by theme:
>
> | Release | Theme | File |
> |---|---|---|
> | **1.1.0** (this file) | **Inference quality + CPU performance core** — the shared-cumulant likelihood corrections, Firth, the diagnostics chain, honest inference after model selection (Phase A), the randomization-CI speed/correctness core (affine reuse, kernel wiring, Brent, inverse guards), Phase 0 decisions for every gated track | `release_v1_1_0.md` |
> | 1.2.0 | **Performance & engines** — kernel/perf lanes (the full profiling program, SIMD, fixed-size Eigen, LTO, memory layout), the algorithm-choice A/B harness and its two Prototype items, ordinal Bayesian-bootstrap backends, count quantile regression, serialization, test-coverage triage, cold starts, greedy-engine merge (soft-deprecation) | `release_v1_2_0.md` |
> | 1.3.0 | **Design extensions from practice** — cluster-level balancing designs + saturation, unequal allocation + Neyman helper, many-by-many family *(the theoretical-design backlog — classical completions, rerandomization criteria/samplers/diagnostics, optimal-objective extensions, GSW / balancing walk / ARM-PSR — moved to 2.0.0, user decision)* | `release_v1_3_0.md` |
> | 1.4.0 | **Response & data extensions** — censoring on continuous/count/proportion, competing risks + `dead → uncensored` rename (one sweep), cure fraction, interval-censored second wave, survival QR, semi-continuous, frailty k-strata, encouragement/CACE, moderation, missing outcomes, sequential-inference scoping | `release_v1_4_0.md` |
> | 2.0.0 | **Architecture + modern designs** — multi-arm, new response shapes, sequential-inference implementation + RAR, cluster GLMM/GEE, mediation, the theoretical-design backlog (GSW, ARM/PSR, rerandomization criteria, objective extensions, classical completions), compute backends, deferred breaking changes | `release_v2_0_0.md` |
>
> **Moved out of this file** (TODO bullets below retained verbatim for
> history, each prefixed with its new home): → 1.2.0: TODO-4,
> TODO-11 (merge half). → 1.3.0: TODO-15. → 1.4.0: TODO-7, TODO-12,
> TODO-13 (scoping), TODO-15c, TODO-15d, TODO-15f, TODO-15g,
> `semi_continuous_…` from TODO-6, `full_glmm_for_weibull_frailty.md`.
> → 2.0.0: TODO-6 (remaining response-type reports), TODO-8, TODO-9,
> TODO-9b (backend; vignette-only option may stay 1.x), TODO-14, TODO-11
> (deletion half).
>
> **Lighten-1.1.0 pass (2026-09-06, user decision) moved further items
> out**, each a verbatim "moved" stub below with its new TODO number: →
> 1.2.0: TODO-4b (remainder), TODO-4c, TODO-4d, TODO-4e, TODO-4f, TODO-15e,
> TODO-17g, TODO-17h, TODO-17i, TODO-17m, TODO-17r, TODO-17s (remainder),
> TODO-17t (the A/B harness half), TODO-17u, TODO-17v. → 1.4.0: TODO-5
> (steps 5–8), TODO-15b, TODO-17c, TODO-17f, TODO-17n (Stage 2). TODO-17d
> (nominal one-vs-rest vignette) is **not** on this list — its ownership
> conflict across three files was separately resolved the same day (user
> decision) in `_master.md`'s favor, and it stays a v1.1.0 item; see
> `TODO-17d`'s own entry below. The rule applied to everything else: keep
> only what the new v1.1.0 theme — inference quality
> plus the CPU/correctness core of randomization inference, plus the
> no-substrate half of honest-inference-after-model-selection (TODO-17y/z,
> moved in from 2.0.0 the day before) — actually needs; exploratory/
> measurement-first work, new estimator families, and items whose
> consumer moved (ordinal Bayesian-bootstrap depends on the v1.2.0 GEE
> kernel; the A/B harness's two Prototype items are "win uncertain")
> follow their consumer or theme instead.
>
> **Stays / added here (1.1.0):** TODO-1, TODO-3, TODO-5 (core), TODO-16,
> TODO-17y, TODO-17z, TODO-17d (nominal vignette — ownership resolved to
> `_master.md`, see that entry), plus **TODO-17a/17b** below — the audit
> backlog's smallest inference-side items, each now with an owning plan:
> `count_exposure_offset.md`, `heteroskedasticity_robust_standard_errors.md`
> (`small_estimand_additions.md`, TODO-17c, moved out per the lighten
> pass above — the vignette did not move).
> (The audit backlog's *design-side* items —
> `sequential_design_classical_completions.md`,
> `rerandomization_criterion_variants.md`, and the rest of the theoretical
> backlog — live in 2.0.0 by user decision.) Also here:
> `ordinal_model_coefficient_randomization_confidence_intervals.md` and
> `randomization_ci_search_precision.md` (its three Bayesian-bootstrap
> siblings moved to 1.2.0, see above).
> **Added 2026-08-27:** `fix_reusable_bootstrap.md` (**TODO-17e** below) —
> a small fix to already-shipped `tune_EDI_for_this_machine()` functionality
> (`local_machine_optimization.md`, closed in the v1.0.0 line), not new
> scope of its own.
> **Added 2026-08-29 (user decision):** `full_test_coverage.md` — a
> triage-and-test-writing plan to take Codecov's line coverage from
> 64.79% (first successful upload after the `test-coverage-R.yaml`
> pipeline fixes, 2026-08-28) into the high 90s. Pure test-writing/CI-
> plumbing, no source-behavior change, independent of every item in every
> release — which is exactly why it **moved 2026-09-06 to
> `release_v1_2_0.md → TODO-18`** rather than gating this release.
> **Added 2026-08-30 (user decision):** `wilkinson_combined_pval.md` — a
> Wilkinson r-out-of-k order-statistic combination test for
> `InferenceSuite`, complementing the existing Cauchy combination-test-
> based `combined_evidence$pval` ("does at least one procedure detect a
> signal") with a "do most procedures agree" question the Cauchy statistic
> cannot answer. Staged: the cheap descriptive vote-count field ships here
> (**TODO-17n**); the formal order-statistic test — gated on deciding
> whether its dependence-robust null-calibration cost is worth it — **moved
> 2026-09-06 to `release_v1_4_0.md → TODO-18`**.
> (`model_averaged_estimand_report.md`, the complementary model-averaged
> point-estimate/CI plan, was also added 2026-08-30 alongside this one but
> moved to `release_v1_4_0.md → TODO-11b` the same day, user decision.)

## Scope rule (historical — superseded by the 2026-08-27 split above)

A plan (or plan fragment) is in scope for v1.1.0 if and only if it lives in
`new_feature_plans/` and is **not** named in `release_v1_0_0.md`'s "In scope"
list or its amendments. Concretely, the exclusions are:

- `fix_inference_hierarchy.md` (all remaining Phase 1D work — 1.0.0 item 1;
  closed 2026-08-23 and moved to `../finished_features/`),
- `extending-edi-r6.md` (1.0.0 item 6; closed 2026-08-23 — now shipped as
  `R/EDI/vignettes/extending-edi.Rmd`, md retired to `../finished_features/`),
- `fix_documentation.md` (1.0.0 item 7 — including the Python docstring
  TODOs, which ride the same-commit-family `edi_kernels` 1.0.0 wheel, and
  the folded-in `marginal_estimand_report.md → TODO-2` roxygen sharpening),
- `marginal_estimand_report.md` in full (1.0.0 item 14, amended 2026-08-18
  — the package-wide `estimand` concept `inference_suite_inspect.md`'s
  Combined Evidence Metric default weighting policy needs; its TODO-1
  decided **yes** 2026-08-18) — **amended again 2026-08-27: the plan was
  reopened with a new TODO-10 (NegBin mixture classes) and moved back to
  `new_feature_plans/`; TODO-10 itself is in v1.1.0 scope, tracked at
  `TODO-17f` below, even though TODO-1..9 remain excluded here as already
  shipped in v1.0.0**. `expanded_estimate_report.md` was
  initially excluded alongside it, then **moved back into v1.1.0 scope
  the same day** (user decision) — see "In scope" and `TODO-1`/`TODO-5`
  below.
- `fix_roxygenize_lazy_component_srcrefs.md → R CMD check TODO` (1.0.0
  item 9),
- the already-closed fragments: `multi_arm_designs.md → TODO-6`,
  `optimizer_diagnostics_report.md → TODO-4`,
  `bootstrap_calibrated_lr_report.md → TODO-1`,
- everything already in `../finished_features/`.

Decision-gated tracks below (Firth, GPU, response types, etc.) are in scope
**conditional on their Phase 0 decision being "yes"** — a "no" removes that
track from this release without replacement; it does not block the release.

## In scope (by plan)

The corrections family — **core only** (**minus `marginal_estimand_report.md`,
pulled into v1.0.0 — amended 2026-08-18, user decision; see
`release_v1_0_0.md`'s item 14; and minus the L1/L2-and-beyond tail, moved
to `release_v1_4_0.md → TODO-14` on 2026-09-06, user decision, to lighten
this release**): `expanded_estimate_report.md` (`estimate_type` — moved
back here 2026-08-18, still an open Phase 0 decision, see `TODO-1` step 1
below), `bias_correction_cox_snell.md`,
`cordeiro_mccullagh_bias_correction_report.md`,
`score_correction_cordeiro_ferrari.md`, `gradient_correction_lemonte.md`,
`likrat_correction_bartlett.md`, `firth_penalties_report.md`. Moved to
v1.4.0: `l1_l2_penalties_all_likelihood_paths_report.md` (its L1/L2 path
proper — TODO-3's joint-semantics note stays here with Firth),
`median_bias_correction_likelihood_paths_report.md`,
`modified_profile_likelihood_report.md`, `bootstrap_calibrated_lr_report.md`
(its remaining Difficult-tier work).

The diagnostics family: `optimizer_diagnostics_report.md` (TODO-1, 2, 3, 5),
`public_diagnostics_api_spec.md`, `prw_subsampling_implementation_spec.md`
(its remaining TODO-14..17 splice and TODO-20).

The ordinal inference-quality family: `ordinal_model_coefficient_randomization_confidence_intervals.md`
stays here (see `TODO-17j` below) — it's a randomization-CI guard on the
existing regression classes, no kernel dependency. Its three Bayesian-
bootstrap siblings, `ordinal_kk_gee_bayesian_bootstrap.md`,
`ordinal_stereotype_logit_bayesian_bootstrap.md`, and
`ordinal_adjacent_category_logit_bayesian_bootstrap.md`, moved to
`release_v1_2_0.md → TODO-17` on 2026-09-06 (lighten-1.1.0 pass, user
decision) — their native weighted refits should share machinery with
v1.2.0's ordinal GEE C++ kernel rather than ship a release ahead of it.

The incidence randomization-CI correction:
`incidence_randomization_cis.md` — per-estimand-scale Zhang intervals,
following the temporary hard-disable and independent of the generic CI-search
precision plan.

The negative-binomial convergence correction:
`negbin_dispersion_convergence.md` — the selected eventual Option 1
reparameterization of the dispersion coordinate, with the completed boundary
acceptance mitigation retained as a compatibility bridge.

The kernel/perf family — **note (2026-09-06): the whole build-tuning
sub-lane below moved to `release_v1_2_0.md` to lighten this release; only
`performance_profiling_and_upgrades.md`'s measurement-infrastructure
TODOs (`TODO-132..135, 175`) stay here, since `TODO-17o`/`17p`/`17w` need
a trustworthy benchmark noise floor**: `robust_regression_perf_optimization_spec.md`,
`quantile_regression_cpp_kernel_spec.md`, `ordinal_gee_cpp_kernel_spec.md`,
`cold_starts.md`, `gpu_optimizations.md` (decision-gated),
`quantum_upgrade.md` (decision-gated; added 2026-08-22, its TODO-1 sits
behind `gpu_optimizations.md → TODO-7` in the Phase 0 batch) are v1.2.0/
v2.0.0 items, unaffected by this move (they were never v1.1.0 scope).
`performance_profiling_and_upgrades.md` (§8 "Phase 8", TODO-132..179;
added 2026-08-23, user decision — not decision-gated, measurement-first)
is **narrowed to TODO-132..135, 175 here; TODO-136..172, 174, 176..179
moved to `release_v1_2_0.md → TODO-11`** (see `TODO-4b`).
`quantum_upgrade.md`'s implementable Part I items — `→ TODO-2..6`
plus the hardware-detection / classical-fallback work `→ TODO-9..12` (§I.7,
added 2026-08-23, user request) — are indexed as `TODO-9b` below, gated on
its `→ TODO-1` decision (Phase 0 step 9b).
(`local_machine_optimization.md` moved to v1.0.0 — see
`release_v1_0_0.md`'s item 15 — 2026-08-20, user decision.)
Three further kernel/perf plans added 2026-08-30 (user decision), all
measurement-first and **moved 2026-09-06 to `release_v1_2_0.md →
TODO-12..15`** alongside the profiling lane they consume:
`more_simd_optimization.md`, `fixed_size_eigen_small_p.md` (compile-time-`p`
Eigen dispatch), `lto_reevaluation.md` (re-measure the `-fno-lto` default
on triggers, flip rule written down), and `memory_layout_row_major_irls.md`
(cache threshold for column-major `X` under row-wise IRLS; policy for
kernel authors).

`guard_unguarded_information_inverse.md` (added 2026-08-30; `→ TODO-1..5`;
see `TODO-17q` below) — hardening: five `with_var` kernels get the same
`isInvertible()` guard their siblings already have; bit-for-bit on
invertible fits.

`ols_randomization_distr_cpp_wiring.md` (added 2026-08-30; `→ TODO-1..6`;
see `TODO-17p` below) — gives `InferenceContinOLS` a batch C++ randomization
distribution by wiring an existing, never-called kernel, and deletes eight
other dead kernel exports.

`randomization_ci_affine_shift_reuse.md` (added 2026-08-30; `→ TODO-1..6`;
see `TODO-17o` below) — revives the never-populated `t0s_rand` fast path so a
randomization CI for a linear statistic costs one null distribution instead
of ~20–35.

The honest-inference-after-model-selection family's no-substrate half
(moved from v2.0.0 on 2026-09-05, user decision; see `TODO-17y` /
`TODO-17z` below): `model_selection_framework.md` **Phase A** — the
`ModelSelection` workflow and the **selection-inclusive randomization
test** on fixed designs — and `model_diagnostics_framework.md` — the
`ModelDiagnostics` declaration contract and pilot batteries. The finding
that unlocked the move: the selection-inclusive randomization test needs
no `Design`-level fold/split substrate (the reason the family had been
slated 2.0.0), only the shipped custom-statistic hook and the registry.
(~~A blinding-commutation shortcut noted here 2026-09-05~~ was removed
2026-09-06, user decision: `w` is in every fit, every replicate re-runs
the full pipeline, embarrassingly parallel over `set_num_cores()`'s
pool.) Phase B is now response-type coverage only (narrowed 2026-09-06);
the design-family extension moved into Phase A the same day.

`fix_reusable_bootstrap.md` (added 2026-08-27; `→ TODO-1..6`; see `TODO-17e`
below) is a small, additive follow-on fix to that shipped feature, not a new
track.

The test-coverage family (added 2026-08-29; **moved 2026-09-06 to
`release_v1_2_0.md → TODO-18`, lighten-1.1.0 pass, user decision**):
`full_test_coverage.md` — triage and test-writing to take Codecov's line
coverage from 64.79% toward the high 90s, plus a coverage-floor CI gate
against backsliding. Pure test/CI-plumbing work with no dependency on any
other item in any release, so nothing was lost by moving it.

The response-type family: `nominal_response_type_report.md`,
`rank_choice_response_type_report.md`,
`semi_continuous_response_type_report.md`,
`multivariate_response_type_report.md`,
`compositional_response_type_report.md`,
`longitudinal_repeated_measures_response_type_report.md`,
`censored_continuous_response.md`, `censored_count_response.md`,
`betaregscale_duplication.md`,
`interval_censored_survival_response_type_report.md` (second wave,
decision-gated), `response_types_landscape_report.md` (refresh).

The KK one-stage-estimation family (added 2026-08-18; **moved 2026-09-06
to `release_v1_4_0.md → TODO-15`, lighten-1.1.0 pass, user decision**):
`kk_beta_regression_one_lik_derivation.md` — a genuine Beta-family (not
quasi-binomial) one-stage `OneLik` joint likelihood for proportion
responses under KK designs, closing one of the two remaining gaps named
in `../new_research_ideas/KK_followup_research_plan.md`. A new estimator
family, off-theme for a release about inference quality and CPU
performance on existing classes.

The quantile-regression family (added 2026-08-26, brainstormed and
approved same day; **neither member is v1.1.0 scope**):
`survival_quantile_regression.md` moved to `release_v1_4_0.md → TODO-7`
on 2026-08-27 (custom self-consistent EM estimator for survival
responses; note this paragraph had drifted stale before today's pass —
corrected here in passing), and `count_quantile_regression.md` — jittered
(Machado & Santos Silva 2005) `rq()` for count responses — moved
2026-09-06 to `release_v1_2_0.md → TODO-16`, beside the native
quantile-regression C++ kernel it should eventually share machinery with.
Both build on `quantreg::rq()` and are natural `use_rcpp` candidates once
`quantile_regression_cpp_kernel_spec.md` lands.

The survival-model extension (added 2026-08-27, commissioned from the
literature audits below): `competing_risks_response.md` — an `event_type`
cause code on the existing `survival` response plus cause-specific
Cox/log-rank (recode wrappers), Aalen-Johansen CIF difference, Gray's test,
RMTL, and Fine-Gray (via `cmprsk` delegation first, counting-process C++
kernel later); decision-gated (its TODO-1), and to be spliced with the
`dead → uncensored` rename (TODO-15c) since both rewrite the same event-
indicator plumbing — and `cure_fraction_survival_inference.md` —
`InferenceSurvivalMixtureCureWeibull` (logistic cure part + Weibull AFT
latency part, two effects exposed through the shipped `estimand` axis;
`flexsurvcure` delegation first, native kernel second), decision-gated,
sequenced after competing risks. Both are univariate-`y` additions on an
existing response type; no design-side change.

Audit reports (2026-08-26/27, reference documents, not work items — they
commission the plans above and rank the remaining gaps):
`missing_inference_classes_literature_audit.md`,
`missing_design_classes_literature_audit.md`,
`missing_theoretical_design_classes_literature_audit.md`. Their
prioritized recommendations (count exposure offset, HC-robust OLS/LPM SEs,
Hedges' g, win odds / Brunner-Munzel, CACE/IV with a design-side
`treatment_received` field, treatment×covariate moderation, cluster-robust
GLMM/GEE, cluster-level covariate-balancing designs, unequal allocation in
matching/greedy designs, Gram-Schmidt Walk, ARM/PSR, generalized quadratic-
form rerandomization, and the two-arm RAR family) are **not yet owned by
any plan** — each needs its own scoping report or a TODO in an existing
plan before it can enter this release index. `nominal_response_type_report.md`
was rewritten 2026-08-27 in light of the inference audit; its recorded
recommendation for its own TODO-1 is now **no / defer indefinitely** (see
`TODO-1` step 8 below).

Designs and orchestration: `multi_arm_designs.md` (TODO-1..5; TODO-6 already
shipped in 1.0.0), `design_fixed_greedy_pair_switch_merge.md`,
`design_seq_many_by_many.md` (added 2026-08-17, user decision — the new
sequential many-by-many design family: `DesignSeqManyByMany` abstract plus
Bernoulli/CRD/Blocking/Rerandomization/Atkinson concrete classes),
`sequential_inference.md` (research scoping — may produce a decision to
defer implementation to 1.2; the scoping itself is in scope).

Persistence: `save_load_api.md → section E` (added 2026-09-01, user
decision — Inference-object serialization; **moved 2026-09-06 to
`release_v1_2_0.md → TODO-19`, lighten-1.1.0 pass, user decision**),
motivated by expensive resampling under slow models, e.g. a bootstrap
distribution from thousands of ZOIB refits. **Scope-rule note, stated
explicitly**: this plan file is named in `release_v1_0_0.md`'s In-scope
list because its Design-side sections A–D shipped in v1.0.0; the file
moved back from `../finished_features/` to `new_feature_plans/` on
2026-09-01 carrying only section E as open scope, and section E itself
now moves on to v1.2.0. A–D remain closed v1.0.0 history.

## Implementation TODOs (dependency order)

Work top to bottom. TODO-3 and TODO-4 may run in parallel with each other
once TODO-1 is recorded; everything from TODO-5 on assumes v1.0.0 has shipped
(shallow hierarchy, frozen kernels). Per the standing constraint, TODOs are
ticked in their **owning plans**; this list is the release index.

- [ ] TODO-1: **Phase 0 decision batch** (ask the user, no code — one
  sitting, in this order because decisions cascade; this is `_master.md`
  Phase 0 verbatim, minus `marginal_estimand_report.md → TODO-1`, which
  moved to v1.0.0 and was decided **yes** there (2026-08-18); plus
  `expanded_estimate_report.md → TODO-1`, moved back here the same day —
  when decided, check which `estimand` values
  `marginal_estimand_report.md → TODO-3` already landed on so neither
  enum absorbs the other's):
  1. `expanded_estimate_report.md → TODO-1` (`estimate_type` design —
     blocks the API shape of steps 3 and 5 below),
  2. `firth_penalties_report.md → TODO-1` +
     `l1_l2_penalties_all_likelihood_paths_report.md → TODO-1` (joint
     penalized-fitting inference semantics),
  3. `median_bias_correction_likelihood_paths_report.md → TODO-1` (after
     Firth),
  4. `bias_correction_cox_snell.md → TODO-1` +
     `cordeiro_mccullagh_bias_correction_report.md → TODO-1` (one project),
  5. `modified_profile_likelihood_report.md → TODO-1`,
  6. `likrat_correction_bartlett.md → TODO-1` (incl. ordering vs.
     score/gradient corrections),
  7. `bootstrap_calibrated_lr_report.md → TODO-2` (Difficult tier yes/no),
  8. the response-type decisions in one pass: `nominal_… → TODO-1`,
     `rank_choice_… → TODO-1`, `semi_continuous_… → TODO-1`,
     `multivariate_… → TODO-1`, `compositional_… → TODO-1`,
     `longitudinal_repeated_measures_… → TODO-1`,
  9. `gpu_optimizations.md → TODO-1` and `→ TODO-7` (backend/build story),
  9b. `quantum_upgrade.md → TODO-1` (added 2026-08-23: vignette+hook only /
      nothing / full A1+A3 — taken right after step 9 so it reuses the
      backend/dispatch answer; a "yes" of either kind also commits to its
      hardware-detection + classical-fallback spec, §I.7 there),
  10. `interval_censored_survival_response_type_report.md → TODO-1`
      (second-wave semiparametric yes/no).
  ~~11. `local_machine_optimization.md → TODO-1` remaining parts~~ — moved
  to v1.0.0 (2026-08-20, user decision; see `release_v1_0_0.md`'s item 15).
  ~~12. `randomization_ci_construction_audit.md → TODO-1`~~ — **decided
      2026-09-06 (user decision: refuse, like the stratified class) and
      implemented the same day** (see `TODO-17x` below). Cox-family
      randomization CI on the wrong scale. (A second item, the null
      construction, was withdrawn 2026-09-05: the code already uses
      impute-then-permute, verified by test — see that plan's §B.)
- ~~TODO-2: `local_machine_optimization.md → TODO-2`~~ — moved to v1.0.0
  along with the rest of that plan (2026-08-20, user decision; see
  `release_v1_0_0.md`'s item 15). Already shipped in a 1.0.x patch, per
  that item's own note.
- [ ] TODO-3: **Diagnostics chain** (`_master.md` Phase 2, strictly ordered):
  `optimizer_diagnostics_report.md → TODO-1` (free diagnostics), `→ TODO-2`
  (hardening), `→ TODO-3` (`SolverDiagnostics` component — **prerequisite
  for Firth in TODO-5**), `→ TODO-5` (Phase 4, lower priority); then
  `public_diagnostics_api_spec.md → TODO-1..4`, `→ TODO-5..8`, `→ TODO-9..12`,
  `→ TODO-13..16`, `→ TODO-17..18` (which also closes
  `prw_subsampling_implementation_spec.md → TODO-14..17` **[spliced]**),
  plus `prw_subsampling_implementation_spec.md → TODO-20` alongside.
- [ ] ~~TODO-4~~ **→ moved 2026-08-27 to `release_v1_2_0.md → TODO-1..4`** — **Kernel/perf lane** (`_master.md` Phase 4 remainder; parallel
  with TODO-3): `robust_regression_perf_optimization_spec.md → TODO-1..4`
  (profile-first), `quantile_regression_cpp_kernel_spec.md → its TODO list`,
  `ordinal_gee_cpp_kernel_spec.md → TODO-1..2` then `→ TODO-3..5` (the KK
  wirings in both wait on 1.0.0's Phase 1D.2 KK migration landing),
  `cold_starts.md → TODO-1..14` (documentation/audit — also a prerequisite
  for TODO-10, which benchmarks the axes this audit documents).
- [ ] TODO-4b: **Performance profiling & upgrades lane — measurement
  infrastructure only** (`performance_profiling_and_upgrades.md` §8 →
  TODO-132..135, 175; added 2026-08-23, user decision; **narrowed
  2026-09-06, user decision, to lighten this release** — everything past
  measurement infrastructure moved to `release_v1_2_0.md → TODO-11`,
  below; parallel with TODO-3/TODO-4, no Phase 0 dependency). Debug-symbol
  call-graph build, callgrind/cachegrind, top-down microarchitecture
  analysis, **benchmark noise floor + regression gate**, and machine-state
  logging (`→ TODO-132..135, 175`) — the plan's `profile/install_perf_tools.sh`
  / `verify_perf_tools.sh` tool roster is already installed on the dev box
  (§8.0.1). Kept in 1.1.0 because TODO-17o/17p/17w's speedup claims need a
  trustworthy noise floor to benchmark against; everything downstream of
  that (generated-code audits, the large levers, end-to-end/R-layer
  profiling, parallelism/BLAS tuning, roofline) is exploratory measurement
  work with no 1.1.0 consumer and moves with the rest of the build-tuning
  lanes. Infrastructure-only; no user-facing change, no gate needed.
- [ ] ~~TODO-4b (remainder)~~ **→ moved 2026-09-06 to `release_v1_2_0.md
  → TODO-11`**: `performance_profiling_and_upgrades.md → TODO-136..172,
  174, 176..179` — generated-code audits, the vectorized exp/log and
  adaptive-Gauss–Hermite levers, end-to-end/R-layer profiling,
  parallelism/BLAS tuning, and the roofline exit. `_master.md` already
  expects this measurement program to find "small or nil" gains at EDI's
  scale; it belongs beside the v1.2.0 kernel/engine work it measures, not
  gating v1.1.0's inference-quality release.
- [ ] ~~TODO-4c~~ **→ moved 2026-09-06 to `release_v1_2_0.md → TODO-12`**
  (`more_simd_optimization.md → TODO-1..7`): More SIMD optimization —
  consumes TODO-4b's audits, so it moves with them.
- [ ] ~~TODO-4d~~ **→ moved 2026-09-06 to `release_v1_2_0.md → TODO-13`**
  (`fixed_size_eigen_small_p.md → TODO-1..5`): Fixed-size Eigen
  specializations for small `p` — gated on TODO-4b's TODO-155 audit,
  which moved with it.
- [ ] ~~TODO-4e~~ **→ moved 2026-09-06 to `release_v1_2_0.md → TODO-14`**
  (`lto_reevaluation.md → TODO-1..4`): LTO re-evaluation — uses TODO-4b's
  TODO-135 protocol, which moved with it.
- [ ] ~~TODO-4f~~ **→ moved 2026-09-06 to `release_v1_2_0.md → TODO-15`**
  (`memory_layout_row_major_irls.md → TODO-1..4`): Memory-layout audit —
  consumes TODO-4b's TODO-144 classification, which moved with it.
- [ ] TODO-5: **Corrections track — core** (`_master.md` Phase 5A order,
  minus `marginal_estimand_report.md`, moved to v1.0.0, amended
  2026-08-18; `expanded_estimate_report.md` moved back here the same day;
  each decision-gated item gated by its TODO-1 decision; **narrowed
  2026-09-06, user decision, to lighten this release** — steps 5–8 below
  moved to `release_v1_4_0.md → TODO-14`, keeping 1.1.0's scope to the
  shared cumulant machinery plus Firth):
  1. `expanded_estimate_report.md → TODO-2..5` (`estimate_type` first —
     its values are consumed by steps 3 and 5),
  2. `bias_correction_cox_snell.md → TODO-2..5` +
     `cordeiro_mccullagh_bias_correction_report.md → TODO-2..4` (one
     project: shared `X'WX` helper, Easy-tier GLMs first),
  3. the higher-order test-correction batch in order:
     `score_correction_cordeiro_ferrari.md → Phase 0..5` (anchor), then
     `gradient_correction_lemonte.md → Phase 0..4`, then
     `likrat_correction_bartlett.md → exact-rollout TODO-2` (shared
     cumulant machinery built exactly once),
  4. `firth_penalties_report.md → TODO-2..5` (requires TODO-3's
     `SolverDiagnostics`) + `l1_l2_penalties_all_likelihood_paths_report.md
     → TODO-3` (joint semantics recorded once in both plans — documents the
     interaction only; the L1/L2 path itself is step 5, moved below).
- [ ] ~~TODO-5 (steps 5–8)~~ **→ moved 2026-09-06 to `release_v1_4_0.md →
  TODO-14`**:
  5. `l1_l2_penalties_all_likelihood_paths_report.md → TODO-2` then
     `→ TODO-4` (the L1/L2 path itself; TODO-3's joint-semantics note
     stays with Firth above),
  6. `median_bias_correction_likelihood_paths_report.md → TODO-3..4` (only
     after Firth ships),
  7. `modified_profile_likelihood_report.md → TODO-2..4`,
  8. `bootstrap_calibrated_lr_report.md → Difficult-tier work` (if TODO-1.7
     said yes).
  None of these gate anything else in 1.1.0 — they are additional
  corrections beyond the shared-machinery core, not prerequisites for it.
- [ ] ~~TODO-6~~ **→ moved 2026-08-27: semi-continuous to `release_v1_4_0.md → TODO-8`, all other response-type reports to `release_v2_0_0.md → TODO-4`** — **Response-type track** (`_master.md` Phase 5B order):
  `nominal_… → TODO-2 (Stage 1)` + `rank_choice_… → TODO-2 (Stage 1)`
  (spliced: admit `nominal` once); `nominal_… → TODO-3..4`;
  `rank_choice_… → TODO-3` (and `→ TODO-4` under its own sub-decision);
  `semi_continuous_… → TODO-2`, `→ TODO-6`, `→ TODO-3..5`;
  `multivariate_… → TODO-2..4`; `compositional_… → TODO-5` then
  `→ TODO-2..4` (vector storage last among scalar-adjacent types);
  `longitudinal_repeated_measures_… → TODO-5` then `→ TODO-2..4` (Stage 1
  extracts the clustered-fit core from `KKGEE`, so it follows 1.0.0's
  Phase 1D.2).
- [ ] ~~TODO-7~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-8`** — **Censored-response track** (`_master.md` Phase 5C order):
  `censored_continuous_response.md → TODO-1..` (its TODO-1 generalizes the
  Design-layer bounds schema; everything downstream keys off it), then
  `censored_count_response.md → TODO-1..`, then
  `betaregscale_duplication.md → TODO-1..` (reuses the censored-quantile
  machinery).
- [ ] ~~TODO-8~~ **→ moved 2026-08-27 to `release_v2_0_0.md → TODO-3`** — **Multi-arm track** (`_master.md` Phase 5D):
  `multi_arm_designs.md → TODO-1` (design side; the 1.0.0 hierarchy work
  supplies the capability metadata), `→ TODO-2`, `→ TODO-3`, `→ TODO-4`
  (coordinate with TODO-6's multivariate orchestration layer — same shape),
  `→ TODO-5` (demand-gated).
- [ ] ~~TODO-9~~ **→ moved 2026-08-27 to `release_v2_0_0.md → TODO-6`** — **GPU track** (if TODO-1.9 said yes; `_master.md` Phase 5E):
  `gpu_optimizations.md → TODO-7` (backend/build design) then `→ TODO-2..5`,
  each merge gated by `→ TODO-6`'s benchmark matrix.
- [ ] ~~TODO-9b~~ **→ moved 2026-08-27 to `release_v2_0_0.md → TODO-6` (the backend architecture); only the vignette-plus-hook option, if chosen, stays 1.x** — **Quantum / QUBO track** (if TODO-1.9b said (a) vignette+hook
  or (c) full A1+A3; `_master.md` Phase 6 item 6; added 2026-08-23, user
  decision; amended the same day: **pure R + vendored open-source C++, no
  Python / `reticulate` anywhere**). Part I of `quantum_upgrade.md` only —
  Part II is recorded there as not buildable. Order: `→ TODO-2` (QUBO
  builder + penalty + repair, brute-force-exact tests at `n ≤ 12`), `→ TODO-3`
  (`qubo_sampler` hook, `"qubo_sampled"` certificate, provenance), then
  **before any external backend becomes user-reachable**: `→ TODO-9`
  (`detect_qubo_backends()` — offline-first detection of `httr2` + credentials
  (env vars or the D-Wave INI config file, parsed in base R), optional one
  HTTPS probe for QPU working graph / hybrid limits, session cache,
  test-injection override), `→ TODO-10` (`qubo_backend` dispatch: default
  `"none"` = today's MILP → SA bit-for-bit; opt-in `"auto"` chain D-Wave QPU →
  Leap hybrid → cloud Ising → classical SA; a *named* backend falls back only
  to classical SA, never to a different paid backend; size/embedding/time/cost
  guards; one `warning()` per hop; `backend_requested`/`backend_used`/
  `fallback_reason` provenance), `→ TODO-11` (R-native adapters behind one
  `qubo_submit()` interface — Stage 1: R client for D-Wave's Solver API
  (REST, `httr2`/`jsonlite` in Suggests) + R serializer for dimod's BQM file
  format for the Leap hybrid solver, plus REST adapters for cloud Ising
  services on request; Stage 2, only if TODO-5's numbers justify it: vendor
  `minorminer`'s `busclique` (Apache-2.0 C++, attributed in `inst/COPYRIGHTS`)
  for dense-clique embedding on the direct QPU; no gate-model adapter),
  `→ TODO-12` (hardware-free tests: HTTP-mocked SAPI fixtures, byte-exact
  serializer round-trips against checked-in dimod fixtures, embedding tests on
  synthetic Pegasus/Zephyr graphs, every fallback row; paid tests only under
  `EDI_RUN_PAID_BACKEND_TESTS=true` — never CI), `→ TODO-4` (R-only
  vignette), `→ TODO-5` (benchmark table; decide whether a classical
  Ising-style C++ kernel is the real follow-up), `→ TODO-6` (A3 blocks
  encoding + CQM serializer) **only if TODO-5 is positive**. Hardware per
  proposal is fixed in that plan's §I.6/§I.7.1 (A1: D-Wave Advantage /
  Advantage2 direct QPU ≲170 dense vars, Leap hybrid above; A3: Leap hybrid
  CQM; I.2: EDI's own C++ SA locally, SQBM+/Fujitsu DA/NEC VA cloud;
  gate-model QAOA dropped from the R path). Shares the backend registry /
  "never auto-route to a non-default backend" convention with TODO-9's
  `gpu_optimizations.md → TODO-7`; whichever lands first sets it. `→ TODO-7/8`
  stay explicitly unscheduled. Additive: `qubo_backend = "none"` reproduces
  1.0.0 results bit-for-bit; nothing quantum enters `Imports` (`httr2`,
  `httptest2`/`webfakes` in `Suggests` only; GPL-3-compatible Apache-2.0
  vendoring with attribution).
- ~~TODO-10: **Local machine optimization**~~ — the whole
  `local_machine_optimization.md` plan moved to v1.0.0 (2026-08-20, user
  decision; see `release_v1_0_0.md`'s item 15). Removed from this release's
  scope entirely, not just resequenced.
- [ ] ~~TODO-11~~ **(split 2026-08-27: merge + soft-deprecation → `release_v1_2_0.md → TODO-6`; the hard deletion of `DesignFixedGreedy`/`DesignFixedGreedyDOptimal` → `release_v2_0_0.md → TODO-7`)**: **Greedy-design merge**:
  `design_fixed_greedy_pair_switch_merge.md → TODO-1..10` — deletes
  `DesignFixedGreedy`/`DesignFixedGreedyDOptimal`, replacing both with
  `DesignFixedGreedyPairSwitch`. Sequenced here per its plan (after the
  1.0.0 design-hierarchy shared-engine work and `design_fixed_optimal.md`,
  both already shipped). **Note:** this deletes two public 1.0.0 classes —
  a breaking change under the 1.0.0 freeze. Before implementation, record
  the deprecation story (soft-deprecate with warnings in 1.1.0 and delete
  in 2.0.0, vs. the plan's current delete-outright shape); the explicit
  user instruction (2026-08-16) made it post-1.0.0 but did not settle the
  deprecation mechanics.
- [ ] ~~TODO-12~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-6`** — **Interval-censored second wave** (if TODO-1.10 said yes):
  the NPMLE/Turnbull + stratified-Cox icenReg delegation work per
  `interval_censored_survival_response_type_report.md`, tracked as new
  TODOs in a reopened/new owning plan (the original
  `interval_censored_survival_response.md` is closed in
  `../finished_features/` — do not reopen it; open a fresh implementation
  plan).
- [ ] ~~TODO-13~~ **(split 2026-08-27: the scoping → `release_v1_4_0.md → TODO-12`; implementation → `release_v2_0_0.md → TODO-5`)**: **Sequential inference scoping**:
  `sequential_inference.md` — run the scoping against the now-shipped
  1.0.0 public accessors; output is either a set of implementation TODOs
  (then decide 1.1.0 vs. 1.2) or an explicit defer note in that plan.
- [ ] ~~TODO-14~~ **→ moved 2026-08-27 to `release_v2_0_0.md → TODO-8`** — **Landscape refresh**: `response_types_landscape_report.md →
  remaining open TODOs` — refresh after the TODO-6/7 tracks ship, so the
  landscape describes the release, not the plan.
- [ ] ~~TODO-15b~~ **→ moved 2026-09-06 to `release_v1_4_0.md →
  TODO-15`** (lighten-1.1.0 pass, user decision): **KK one-stage
  Beta-regression estimator** (added 2026-08-18):
  `kk_beta_regression_one_lik_derivation.md → TODO-1..10` — a new
  estimator family (glmmTMB-reuse prototype, then a from-scratch
  Gauss-Hermite backend), off-theme for a release about inference
  quality and CPU performance on existing classes; joins v1.4.0's other
  new-estimand work.
- [ ] ~~TODO-15~~ **→ moved 2026-08-27 to `release_v1_3_0.md → TODO-7` (its TODO-1 decisions may still be taken in this file's Phase 0 sitting)** — **Sequential many-by-many design family**:
  `design_seq_many_by_many.md → TODO-1..10` — its TODO-1 decision batch
  (Atkinson rule, bootstrap shape, threshold schedule) can join this file's
  TODO-1 sitting; the implementation is additive and independent of every
  other track (it needs only the 1.0.0 shallow design hierarchy), so it may
  run in parallel with TODO-5..8 any time after v1.0.0 ships. Note its
  TODO-2 extracts shared ingestion logic from the frozen
  `DesignSeqOneByOne$add_one_subject()` path — behavior-preserving under
  golden test, per the additive constraint below.
- [ ] ~~TODO-15d~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-7` (custom EM estimator with three recorded open risks — not a simple addition)** — **Survival quantile regression** (added 2026-08-26):
  `survival_quantile_regression.md → TODO-1..N` (implementation plan not
  yet written) — `InferenceSurvivalQuantileRegr` plus
  `InferenceSurvivalKKQuantileRegrIVWC`/`OneLik`, a custom self-consistent
  EM estimator for general interval-censored data (no existing
  `quantreg::crq()`-based path covers this), bootstrap + heuristic
  asymptotic-sandwich inference, and KK randomization inference. Additive,
  no decision gate. Open risks flagged in the plan (EM-to-Peng-Huang
  reduction unverified until tested, sandwich variance unproven for
  interval censoring, randomization-inference performance unresolved)
  carry into its implementation plan. May run in parallel with every
  other track; independent of TODO-15b/15e.
- [ ] ~~TODO-15e~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-16`** (lighten-1.1.0 pass, user decision): **Count quantile
  regression** (added 2026-08-26): `count_quantile_regression.md →
  TODO-1..N` (implementation plan not yet written) —
  `InferenceCountQuantileRegr` plus
  `InferenceCountKKQuantileRegrIVWC`/`OneLik`, Machado & Santos Silva
  (2005) jittered `rq()`. Moved beside v1.2.0's quantile-regression C++
  kernel (`quantile_regression_cpp_kernel_spec.md → TODO-1` there) rather
  than shipping ahead of the native kernel it should eventually share
  machinery with.
- [ ] ~~TODO-15f~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-2..3` (one plumbing sweep with the rename)** — **Competing risks for survival responses** (added
  2026-08-27): `competing_risks_response.md → TODO-1..9` — gated on its
  TODO-1 (pursue at all; v1 = exact/right-censored only; `event_type`
  storage shape; `cause =` as an inference-class argument; `cmprsk` in
  `Suggests`). Wave 0 (storage + replay) **must be spliced with TODO-15c**
  (the `dead → uncensored` rename) — both rewrite the 31 `Surv(y, dead)`
  call sites and `get_effective_dead()`; do them in one sweep. Waves 1–2
  (cause-specific Cox/log-rank; CIF/Gray/RMTL) target v1.1.0; Wave 3a
  (Fine-Gray via `cmprsk::crr`) if the `Suggests` dependency is accepted;
  Wave 3b (counting-process Cox kernel) is a later kernel spec that also
  serves a future recurrent-events plan. Independent of every other track
  except 15c.
- [ ] ~~TODO-15g~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-4`** — **Cure-fraction (mixture-cure) survival inference** (added
  2026-08-27): `cure_fraction_survival_inference.md → TODO-1..6` — gated on
  its TODO-1 (pursue at all; default `estimand = "latency"`; native kernel
  in the first wave or delegation only; `flexsurvcure` in `Suggests`).
  Small standalone inference-class addition on the existing `survival`
  type; sequenced after TODO-15f and the inference audit's count-offset
  item; may be deferred to 1.2 without loss.
- [ ] ~~TODO-15c~~ **→ moved 2026-08-27 to `release_v1_4_0.md → TODO-2` (same sweep as the competing-risks `event_type` column; the user's 2026-08-19 "full hard rename" decision is unchanged, only its release slot)** — **`dead` → `uncensored` rename** (added 2026-08-19, user
  decision): `../finished_features/interval_censored_survival_response.md →
  TODO-29` — rename the survival event/censoring indicator `dead` to
  `uncensored` (R, C++, docs, Python binding), now that left-/
  interval-censoring means `dead` no longer accurately describes the field.
  Wide blast radius (~576 R occurrences, `src/*.cpp`/`*.h`, Python
  binding). **Scoping decided (2026-08-19, user decision): full rename** —
  R, C++, and Python binding identifiers/args/columns all renamed from
  `dead` to `uncensored` (not R-layer-only); no `spec$dead` backward-compat
  alias — a hard break, since the package is still pre-1.0.0-frozen public
  API territory for this field. Touched `.cpp`/`.h` files must be
  recompiled per this repo's targeted-compile-only rule (never a full
  `R CMD INSTALL`/`pkgbuild::compile_dll()`/`load_all(compile=TRUE)`).
  Additive-adjacent but touches shared survival files, so avoid
  interleaving with TODO-6's response-type track or TODO-12's
  interval-censored second wave on the same files at the same time.
- [ ] TODO-17a: **Count exposure offset** (added 2026-08-27):
  `count_exposure_offset.md → TODO-1..5` — `exposure =` on every count
  class and kernel; unlocks the standard rate-ratio trial analysis
  (inference audit #5, rank 1). Small; no dependencies.
- [ ] TODO-17b: **HC-robust standard errors** (added 2026-08-27):
  `heteroskedasticity_robust_standard_errors.md → TODO-1..5` — `se_type =
  HC0..HC3` on `InferenceContinOLS` and `InferenceIncidRiskDiff`; shared
  sandwich helper extracted from the Lin class (inference audit #1). Small;
  the helper is reused by 1.4.0's 2SLS classes.
- [ ] ~~TODO-17c~~ **→ moved 2026-09-06 to `release_v1_4_0.md →
  TODO-16`** (lighten-1.1.0 pass, user decision): **Small estimand
  additions** (added 2026-08-27): `small_estimand_additions.md →
  TODO-1..7` — Hedges' g, win odds / Brunner-Munzel across all six types,
  Mantel-Haenszel OR/RD, non-inferiority / equivalence conveniences,
  unconditional QTE, log-link QMLE / Gamma-log for continuous
  non-negative `y` (inference audit #6, #11, #17–#20). A grab-bag of new
  estimands, not a fix to an existing one; joins v1.4.0's InferenceSuite
  summary additions.
- [ ] TODO-17d: **Nominal one-vs-rest vignette** (ownership resolved
  2026-09-06, user decision: `_master.md`'s thematic-release-split
  summary is the single authoritative statement of this item's release
  placement — `release_v1_4_0.md`'s and `release_v2_0_0.md`'s competing
  mentions are corrected to point here rather than claim it
  independently). If `nominal_response_type_report.md → TODO-1` is
  decided "no" in this release's Phase 0 sitting (its recorded
  recommendation, per `release_v2_0_0.md`'s TODO-1), its TODO-1b
  (vignette section + cross-reference to the multivariate plan) ships
  here in the same release as the decision, and the report closes to
  `../finished_features/`. If TODO-1 instead overturns that
  recommendation, this item does not fire and nominal proceeds as a
  2.0.0 response-shape item (`release_v2_0_0.md → TODO-4`).
- [ ] TODO-17e: **Reusable-bootstrap-worker support for
  `InferencePropZeroOneInflatedBetaRegr`** (added 2026-08-27):
  `fix_reusable_bootstrap.md → TODO-1..6` — the one class (of 51 live
  inference families, audited) missing the `get_bootstrap_worker_spec()`
  fast path `local_machine_optimization.md`'s shipped `tune_EDI_for_this_
  machine()` already relies on elsewhere; its jackknife rebuilds a fresh
  `Design`/`Inference` object and reruns full column-selection from
  scratch per leave-one-out fold instead of reusing one warmed-up worker.
  Small, additive, R-layer only (no kernel change); must reproduce
  bit-identical jackknife results before/after (plan's TODO-4). No
  dependencies on other 1.1.0 items.
- [ ] ~~TODO-17f~~ **→ moved 2026-09-06 to `release_v1_4_0.md →
  TODO-17`** (lighten-1.1.0 pass, user decision): **NegBin mixture
  marginal estimand** (added 2026-08-27): `marginal_estimand_report.md →
  TODO-10` — extend `set_estimand("marginal_mean_diff"/"marginal_ratio")`
  to `InferenceCountZeroInflatedNegBin` and `InferenceCountHurdleNegBin`.
  Response-family estimand extension, not a fix; joins v1.4.0's suite
  summary additions (moved alongside its natural companion TODO-17c).
- [ ] ~~TODO-17g~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-17`**: **Ordinal KK GEE Bayesian bootstrap**
  `ordinal_kk_gee_bayesian_bootstrap.md` — restore weighted refits that use
  the primary `multgee::ordLORgee` estimating equations and matched/reservoir
  clustering, then enable the guarded capability after parity and calibration
  tests. Moved beside v1.2.0's ordinal GEE C++ kernel, which these native
  weighted refits should share machinery with.
- [ ] ~~TODO-17h~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-17`**: **Ordinal stereotype-logit Bayesian bootstrap**
  `ordinal_stereotype_logit_bayesian_bootstrap.md` — implement weighted
  refits of the native stereotype-logit estimator and enable its registry
  capability only after draw-level parity tests.
- [ ] ~~TODO-17i~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-17`**: **Ordinal adjacent-category-logit Bayesian bootstrap**
  `ordinal_adjacent_category_logit_bayesian_bootstrap.md` — replace the
  cumulative-logit surrogate in weighted draws with the native
  adjacent-category likelihood before enabling the capability.
- [ ] TODO-17j: **Ordinal model-coefficient randomization CIs**
  `ordinal_model_coefficient_randomization_confidence_intervals.md` — add
  estimand-scale CI inversion while preserving the existing randomization-test
  and randomization-bootstrap p-value capabilities.
- [ ] TODO-17k: **Incidence randomization CIs**
  `incidence_randomization_cis.md` — implement per-estimand-scale Zhang exact
  intervals and remove the temporary incidence CI disable only after tests
  demonstrate that bounds no longer reuse a log-odds-ratio scale incorrectly.
- [ ] TODO-17l: **Negative-binomial dispersion reparameterization**
  `negbin_dispersion_convergence.md → TODO-1..4` — replace the unbounded
  `log_theta` coordinate with an attainable Poisson-boundary parameterization
  (`phi = 1/theta` or `log(phi)`) across ZINB, plain NegBin, and hurdle-NegBin;
  rederive score/Hessian and downstream covariance/warm-start consumers;
  retain the completed boundary-acceptance mitigation as a compatibility
  bridge until parity and non-overdispersion regression tests pass.
- [ ] ~~TODO-17m~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-18`, reframed as a rolling non-gating track** (lighten-1.1.0 pass,
  user decision): **Full test coverage triage** (added 2026-08-29):
  `full_test_coverage.md → TODO-1..10` — take Codecov's line coverage
  from 64.79% into the high 90s. Pure test-writing/CI-plumbing with zero
  dependency on any other item in any release; it was in v1.1.0 only
  because it was added while that release was being planned, not because
  anything here needs it. Runs whenever convenient starting in v1.2.0;
  the coverage-floor CI gate (Phase 4) is the only piece that should wait
  for the bulk of Phase 2/3 to land first, wherever that ends up.
- [ ] TODO-17n: **Wilkinson r-out-of-k combined-evidence test, Stage 1**
  (added 2026-08-30): `wilkinson_combined_pval.md → TODO-2` —
  `InferenceSuite`'s existing `combined_evidence$pval` (Cauchy combination
  test) answers "does at least one applicable procedure detect a signal,"
  but structurally cannot answer "do most agree" (its tan-transform
  statistic is always dominated by the smallest p-value). Stage 1 ships a
  plain descriptive vote-count field (`vote_fraction`, overall and
  per-estimand) — cheap, no new theory. No dependencies on other 1.1.0
  items.
- [ ] ~~TODO-17n (Stage 2)~~ **→ moved 2026-09-06 to `release_v1_4_0.md
  → TODO-18`** (lighten-1.1.0 pass, user decision): `wilkinson_combined_pval.md
  → TODO-1 (gate), TODO-3..4` — the formal r-th-order-statistic test,
  gated on deciding whether its bootstrap/permutation null-calibration
  cost (no closed-form result exists under arbitrary dependence, unlike
  CCT) is worth it. The TODO-1 gate decision may still be taken in this
  release's Phase 0 sitting; only the implementation moves.
- [ ] TODO-17o: **Randomization CI affine-shift reuse** (added 2026-08-30,
  user decision): `randomization_ci_affine_shift_reuse.md → TODO-1..7`
  (plus a decision-gated TODO-8, below). The
  fast path at `inference_all_abstract_rand.R:436` (`t0s = t0s_rand + delta`)
  is dead — `cached_values$t0s_rand` has never been assigned a value, so
  the δ-keyed distribution cache misses on every bisection step and a
  randomization CI costs ~20–35 full `r`-permutation distributions. For
  statistics linear in `y` with `w` in the design (simple mean diff,
  average diff, OLS, Lin) `t0_b(δ) = t0_b(0) + δ` is an exact identity, so
  one full δ = 0 distribution serves the whole search. Adds a
  `supports_additive_delta_shift()` predicate (default `FALSE`; never for
  rank statistics, transformed scales, custom statistics, non-linear
  models), populates `t0s_rand` only from a full-`r` δ = 0 call (never an
  MC-shortened prefix), and forces that one full call in
  `build_randomization_ci_search_bounds()`. Expected 20–30× on
  `compute_confidence_interval_rand()` for those classes. Equivalence is to
  floating point, not bit-for-bit (documented default change; tolerances in
  the plan). KK combined estimators are tier 2, opt-in after numerical
  verification. Independent of other 1.1.0 items. **Interaction note
  (2026-09-04; jump formula corrected 2026-09-05 per TODO-17x §B):** once
  this lands, a tier-1 class's `p(δ)` is an exact *step function* of δ
  (each `t0_b(δ) = t0_b(0) + δ·(1 − c_b)` is affine in δ, so the jumps
  sit at `(t − t0_b(0)) / (1 − c_b)`), so TODO-17w (Brent) does not
  apply to it and Robbins–Monro (moved 2026-09-06 to `release_v1_2_0.md
  → TODO-21`) is moot on it — the RM driver
  dispatches to bisection there and its A/B corpus is stratified on
  `supports_additive_delta_shift()`. The same fact opens a direct
  order-statistic inversion (the two `α/2`-level order statistics of
  `(t − t0_b(0)) / (1 − c_b)`, guarded on `min_b (1 − c_b) > 0` so every
  term is increasing in δ; one sort, no search, exact endpoints) —
  recorded as the plan's decision-gated TODO-8; its gain over TODO-3 is
  exactness and the removal of the bracket/expansion failure modes, not
  wall time.
- [ ] TODO-17p: **Wire the unused OLS randomization-distribution kernel;
  triage dead kernels** (added 2026-08-30, user decision):
  `ols_randomization_distr_cpp_wiring.md → TODO-1..6`.
  `compute_ols_distr_parallel_cpp` (`src/ols_distr_parallel.cpp:15`) is
  complete and exported but has no caller anywhere (R, tests, python,
  benchmark); `InferenceContinOLS` has no `compute_fast_randomization_distr()`
  and falls through to the R-level reused-worker loop
  (`inference_all_abstract_rand.R:708-800`) — ~100–200 µs of R6
  bookkeeping per replicate around a ~5 µs solve. Adds the method on the
  Poisson pattern (`inference_count_poisson.R:839`), passing the
  *hardened* covariate block (`create_design_matrix()[, -(1:2)]`) and
  adding a per-replicate rank guard to the kernel so `NA` patterns match
  the worker. Same estimator to ~1e-14 (LDLT vs. ColPivQR; documented
  default change, tolerance 1e-10). Expected 20–50× on the OLS
  randomization distribution; multiplicative with TODO-17o. Also triages
  eight other never-called exports (`compute_ols_bootstrap_parallel_cpp`,
  two `compute_wilcox_distr_*`, `base_bootstrap_loop_cpp`,
  `matching_bootstrap_loop_cpp`, `fill_i_b_with_matches_loop_cpp`, three
  `bisection_ci_*_cpp`): wire the bootstrap one if its contract matches,
  delete the rest (with unity-group cleanup). Lin is a stretch item; the
  kernel-internal FWL rewrite is v1.2.0 (`ols_distr_kernel_fwl.md`).
- [ ] TODO-17q: **Guard the unguarded information-matrix inverses** (added
  2026-08-30, user decision): `guard_unguarded_information_inverse.md →
  TODO-1..5`. Correctness, not performance.
  `fast_negbin_regression.cpp:485` inverts the free-parameter information
  block with a bare `.inverse()` and no invertibility check (its own
  roxygen at `:411-418` admits it); the same pattern is at
  `fast_zinb.cpp:457`, `fast_zero_augmented_poisson.cpp:340`/`:566`, and
  `fast_beta_regression.cpp:643`, while Cox, ordinal, and ZOIB check
  `FullPivLU::isInvertible()` and return a `NaN` covariance. A
  near-singular block today yields a *finite, wildly wrong* SE with no
  warning (the R side's `res$vcov %||% …` accepts any non-`NULL` matrix).
  One shared `invert_free_information()` helper in
  `_helper_functions_core.h` — `FullPivLU` for the decision, the original
  `.inverse()` for the value so every invertible fit stays **bit-for-bit**
  — applied at the five sites, plus tests that a duplicated-column
  `harden = FALSE` design now yields `NA` SE/CI, and roxygen rewrites.
  Independent of other 1.1.0 items.
- [ ] ~~TODO-17r~~ **→ moved 2026-09-06 to `release_v1_2_0.md →
  TODO-19`** (lighten-1.1.0 pass, user decision): **Inference-object
  serialization** (added 2026-09-01, user decision): `save_load_api.md →
  section E (E-1..E-7)`. Make a fitted `Inference` object a supported
  `saveRDS()`/`readRDS()` unit, mirroring the v1.0.0 Design-side audit.
  Persistence infrastructure, off-theme for an inference-quality/
  performance release; **E-2's `owns_state` audit is cheapest after
  TODO-17y (ModelSelection Phase A) and every other 1.1.0 item that adds
  `Inference`-side state has landed** — which is itself a reason to run
  this after 1.1.0, not during it.
- [ ] TODO-17s: **Multistart for the nonconcave likelihood kernels —
  documented-failure tranche only** (added 2026-09-03, user decision;
  **narrowed 2026-09-06, user decision, to lighten this release**):
  `multistart_nonconcave_likelihoods.md → TODO-1..10`, scoped in 1.1.0 to
  the kernels with a *documented* failure mode: ZINB / ZIP / hurdle
  NegBin in `(β, log θ)` (the boundary-runaway failure `TODO-17l` and
  `em_algorithm_zero_inflated_mixtures.md` exist to patch) and beta
  regression. Builds the shared infrastructure regardless — one new leaf
  header `src/optimization_multistart.h`
  (`optimize_fixed_likelihood_multistart()` wrapping the existing
  `optimize_fixed_likelihood()`; family-specific deterministic starts + a
  reproducible random layer from a private `edi_rng::RRng`, never R's
  stream), three new kernel arguments (`n_random_starts`,
  `multistart_jitter_sd`, `multistart_seed`), four provenance fields, a
  `get_multistart_dispatch_policy()` table mirroring the cold-start one,
  and `set_multistart()` on the abstract class. **Bit-for-bit** whenever
  the primary start already reaches the best optimum found, on every
  replicate (warm-started) fit, and on every concave kernel. Python
  `edi_kernels` parity included. Shares the "new leaf header, targeted
  compile only" discipline with TODO-17q.
- [ ] ~~TODO-17s (remainder)~~ **→ moved 2026-09-06 to `release_v1_2_0.md
  → TODO-20`**: applying the same infrastructure to the kernels with no
  documented failure — GLMM / LMM / frailty marginal likelihoods, ZOIB,
  stereotype logit, Clayton-copula and dependent-censoring survival,
  ordinal cauchit (the `fast_ordinal_glmm.cpp` 5-point sweep is
  unconditionally bit-for-bit and may land with either tranche), and
  Tukey-bisquare robust regression (additionally starts from a converged
  Huber fit instead of OLS).
- [ ] TODO-17t: **Algorithm choice audit** (survey; no code) (added
  2026-09-03, user decision): `algorithm_choice_audit.md`. Complements
  `performance_profiling_and_upgrades.md` (which asks "is the
  implementation fast?") by asking "is the chosen algorithm the right
  one?" per kernel/problem class, with citations and a verdict (keep /
  keep tracked elsewhere / prototype / adopt). Pure document; kept in
  1.1.0 because it costs nothing and TODO-17w (Brent) is already one of
  its Adopt verdicts. **The A/B testing harness the survey's Prototype
  verdicts need — `algorithm_ab_testing_framework.md → TODO-1..4` — and
  the two Prototype items gated on it (Robbins–Monro, EM hybrid start)
  moved 2026-09-06 to `release_v1_2_0.md → TODO-21`**, below: their
  outcome is "win uncertain, validate first," which is exploratory work
  in the same spirit as the profiling lane, not a release-gating item.
  No default changes without a human reading the harness's report, per
  that plan's own rule.
- [ ] TODO-17w: **Brent's method for the score / gradient / Bartlett-LR CI
  inverters** (added 2026-09-04, user decision): `brent_ci_inversion.md →
  TODO-1..3`. `pval_invert_ci_cpp` (`lrt_ci_newton.cpp:214-282`) polishes
  the bracket by pure bisection while the LR inverter in the same file
  (`lrt_ci_nr_cpp`) already uses Newton; Brent–Dekker on the same bracket
  cuts ~20 constrained refits per bound to ~5–8 with the bound unchanged
  within `tol = 1e-6`. **Adopt**, not Prototype — deterministic
  root-finder swap on an exactly-evaluable `p(δ)`, gated on the existing
  CI tests rather than the algorithm-choice A/B harness (moved
  2026-09-06 to `release_v1_2_0.md → TODO-21`); `method = "bisection"` kept
  as an escape hatch. Independent of every other 1.1.0 item.
  (`algorithm_choice_audit.md → row M`; explicitly *not* a
  Garthwaite–Buckland case — see that plan's scope note — and explicitly
  *not* applicable to the randomization CI search either, whose `p(δ)` is
  a step function after TODO-17o; see that plan's interaction section.)
- [ ] TODO-17x: **Randomization CI construction audit** (added 2026-09-04,
  found empirically): `randomization_ci_construction_audit.md → TODO-1..4`.
  Two findings, both ending in a Phase 0 user decision. **§A (bug):** the
  Cox-family classes (`InferenceSurvivalCoxPHRegr`, KK LWA Cox ×2, KK strat
  Cox ×2) run the generic randomization-CI driver, which shifts responses
  on the log-time (AFT) scale but seeds, brackets, and reports on the
  estimate's log-hazard-ratio scale — on a Weibull DGP with true log HR
  `−1.6` the Cox rand CI came back `[−1.702, −1.264]` with the lower bound
  equal to the estimate, while `p(δ)` correctly peaks at the log time-ratio
  `0.8`. Same bug family as `incidence_randomization_cis.md`; the
  stratified non-KK Cox class already refuses for exactly this reason.
  **Decided and implemented 2026-09-06 (user decision, option 1):** the
  six log-HR classes are listed in `EDI_LOG_HAZARD_RATIO_INFERENCE_CLASSES`,
  excluded from the `randomization_ci` capability (suite never offers it,
  as for incidence), and refused with an explanation on a direct call;
  randomization p-value and randomization-bootstrap CI untouched (the
  latter verified scale-consistent). Test:
  `test-log-hazard-ratio-randomization-ci-disabled.R`; `NEWS.md` entry.
  **§B (closed 2026-09-05):** an earlier draft claimed the null construction was
  shift-the-null (`y + δ·w_b`); it is not — every path imputes the control
  potential outcomes first (`y − δ·w_obs`, `setup_randomization_template_and_shifts()`
  `inverse = TRUE`) and then shifts the permuted-treated units, i.e. the
  Rosenbaum / Imbens–Rubin construction. Pinned by
  `tests/testthat/test-rand-null-construction.R` (C++ fast path and R
  worker path, fixed allocations, both constructions computed by hand);
  no code change. The same misreading had reached
  `randomization_ci_affine_shift_reuse.md`'s identity, corrected the same
  day to `t0_b(δ) = t0_b(0) + δ·(1 − c_b)`. The censoring-indicator
  question that started the audit is answered as defensible (rank-based
  AFT residual construction, Tsiatis 1990 / Wei–Ying–Lin 1990) and is in
  the roxygen and `REFERENCES.md`.
- [ ] TODO-17y: **`ModelSelection` Phase A + the selection-inclusive
  randomization test** (moved from `release_v2_0_0.md → TODO-6h` on
  2026-09-05, user decision; **widened 2026-09-06, user question, to
  cover every design family**): `model_selection_framework.md →
  TODO-1..8` (Phase A parts; TODO-9 stays a narrower, response-type-only
  remainder). **Why it can move:** the selection-inclusive randomization
  test — wrap the whole choose-then-fit pipeline as the randomization
  statistic, redraw `w` from the design, re-run per replicate; exact
  under the sharp null for any selection rule — needs no `Design`-level
  fold/split substrate at all. It is a client of the shipped
  `set_custom_randomization_statistic_function()` hook
  (`inference_all_abstract_rand.R:22`) plus the registry, and every
  design's redraw-of-`w` mechanism for the per-replicate re-run already
  exists and is design-agnostic. ~~Under fully treatment-blinded
  selection it commutes with the test, collapsing to the plain
  randomization test of the winner at zero extra cost, with CI inversion
  by de-treating once per δ.~~ **Removed 2026-09-06 (user): blinding is
  stripped from the plan — `w` is in every fit, every replicate re-runs
  the full pipeline, CI inversion is a full re-run per δ (hence
  post-grant, paired with the Garthwaite–Buckland driver — 2026-09-07,
  see the plan's TODO-7), and the cost
  is embarrassingly parallel over `set_num_cores()`'s fork/`mirai`
  pool.** **Why it widened past fixed designs (2026-09-06):** the one
  thing that did still need design cooperation — CV folds for the
  comparative-criteria layer — turns out to
  already exist too. `resolve_resampling_unit()`
  (`inference_ext_exchangeable_resampling_units.R:15-33`) dispatches on
  matching/clustering/blocking structure, never on whether treatment
  assignment was fixed-upfront or sequential, and already returns
  `"matched_set"` for KK-family sequential matching designs exactly as it
  returns `"pair"` for a fixed matched-pair design — the same dispatch
  the bootstrap already relies on for both. The original 2026-09-05
  slating of "matched-pair/cluster/sequential designs" into Phase B had
  conflated this plan's (weak) CV-fold need with sample splitting's
  (genuinely hard) requirement that a subject subset be its own valid
  design realization — a conflation corrected the same day this file's
  header records it. **Scope (the pilot, widened):** every design family
  EDI supports (completely randomized, blocked, stratified, matched-pair,
  cluster, sequential matching-on-the-fly including KK14/KK21), continuous
  + incidence, grid `~w`/`~w + .`/`~w * .` (TODO-1(d), 2026-09-06),
  tier-gated criteria (AIC/BIC at `"full"`, QIC at `"quasi"`, scoring
  rules everywhere; cross-tier AIC refused), a provenance object, the
  per-replicate re-run parallelized over `set_num_cores()`'s pool with
  `method = "auto"` dispatch, naive inference on a selection-tainted winner as a
  typed refusal, and the simulation study (naive inflation → exact size →
  coverage → power cost). Stretch: (e) simultaneous max-|t| bands; (f)
  the rejection-sampled conditional randomization test
  (`selective_inference_post_selection.md → TODO-7`, unblocked by this
  item). Only the remaining response types (count, proportion, survival,
  ordinal) are left to TODO-9, and whether that remainder still belongs
  in 2.0.0 or fits v1.4.0 better is an open question, not yet resolved.
  **Additive:** a new workflow object beside `InferenceSuite`; no default
  of any existing class changes. Consumes TODO-17z's check results as
  assumption gates once both exist (the gate is optional for the pilot;
  the assumption-light fallback class is mandatory regardless).
  Externally: this is the scoped deliverable of the R Consortium ISC
  proposal (`new_research_ideas/grants/RcISC/isc_grant.qmd`; the
  earlier LaTeX draft was deleted 2026-09-07), re-scoped 2026-09-06 to
  this widened Phase A and carrying no blinding claims.
- [ ] TODO-17z: **`ModelDiagnostics` — declaration contract + pilot
  batteries** (moved from `release_v2_0_0.md → TODO-6g` on 2026-09-05,
  user decision, resolving that plan's TODO-1(e)):
  `model_diagnostics_framework.md → TODO-1..6`. Each class declares its
  own assumption checks in the registry (Schoenfeld/PH for Cox,
  overdispersion for Poisson, proportionality for cumulative logit,
  separation/calibration for logistic — surfacing the existing internal
  separation guard), returning typed results with a pre-specified gate
  threshold per check (the `blindable` tag was dropped 2026-09-06),
  rendered in one report with
  `SolverDiagnostics`' numerical rows. Checks are in-sample and need no
  fold/split substrate. **Sequenced after TODO-3** (`SolverDiagnostics`)
  for the shared report surface; independent of TODO-17y (each is useful
  alone; together they give TODO-17y its diagnose-then-choose gate). The
  per-class rollout beyond the pilots is a ledger inside the plan.
  Additive.
- [ ] TODO-18: **Consolidate duplicated parallelization primitives**
  (added 2026-09-07, user decision): `consolidate_parallelization_code.md
  → TODO-1..4`. Maintenance, not a feature — no output/behavior change.
  `Inference$par_lapply` is already a shared chunked-map parallel helper
  reused by ~10 bootstrap/randomization classes, backed by shared
  construction/lifecycle helpers in `globals.R`; `SimulationFramework$run()`
  and `InferenceSuite$run_all_inference()` hand-roll their own backend
  selection instead, for real documented reasons (a stateful
  copy-on-write pool with rolling dispatch, and a zero-blast-radius
  `mcparallel`/PID-kill dispatcher respectively — see
  `parallel_fork_cluster_test_safety.md`'s TODO-5). This item does **not**
  unify those three scheduler shapes; it extracts three sub-pieces that
  duplicate across them and have already drifted: two inconsistent
  `ensure_mirai_daemons` implementations, the mirai
  poll/liveness-check/stop-on-death loop (written out at least twice),
  and worker single-threading env-var setup (defined once for
  `clusterCall()`, hand-rederived once for `mcparallel` children).
  Independent of every other 1.1.0 item; no dependency on the decision
  batch.
- [ ] TODO-19: **"Lock-and-key" (Design/Inference) metaphor rotated into
  documentation** (added 2026-09-08, user decision; scope widened same day
  to every doc surface; went through several narrowing/refinement rounds
  same day, all user decisions, ending with "lego" dropped entirely):
  `lock_key_metaphor.md` (renamed from `lego_metaphor.md`) → TODO-2..7.
  Pure prose — no code, no public API, no tests. **Design = lock**
  (capabilities fix at construction), **Inference = key** (declared
  required capabilities are its cut teeth) — settled by
  `InferenceSuite$run_all_inference()`'s one-lock-many-keys usage pattern.
  Two confirmed gates: **warding** (`Design$applicable_inference_class_names()`'s
  coarse metadata-only predicate, no object constructed) then **bitting**
  (the fine `capabilities()`/`supports()` check); the **shear line** names
  the all-or-nothing moment every declared capability must align
  simultaneously (`get_effective_capabilities()`, no partial credit). Real
  locksmith terms **bow** (key) / **housing** (lock) name the internal
  parts (e.g. `likelihood_tier`) that are real but never checked by the
  other side. **Final framing: a key-operated measuring instrument, not a
  door.** `Inference$new(design)` assembles a machine rather than unlocking
  access to a separately-explored room — turning the key both gates
  (capability check) and configures (which computation the assembled
  instrument runs), the same mechanism a real keyed selector-switch meter
  uses. That's why different valid keys legitimately report different
  numbers from the same design (different circuits through one instrument,
  not different tools brought in afterward) — the reason
  `run_all_inference()` reports multiple differing results by design.
  Placements: `README.md` Highlights bullet (top-level only), `R/EDI/
  vignettes/extending-edi.Rmd`'s "How EDI classes are built" section
  (highest value — carries the full picture, mechanism already documented
  there, unnamed), the pkgdown home (a second tagline, not the
  keyword-optimized meta description), the `?EDI` package-level roxygen
  block (`EDI.R`), `DESCRIPTION`'s `Description:` field (one plain factual
  clause, not a slogan, given CRAN's plain-language expectation for that
  field and the imminent submission — lowest-cost item to drop if a
  reviewer flags it), and an optional `CITATION.cff`/`inst/CITATION`
  mention if either has a natural free-text slot. Doc-only knit/parse
  checks, not an `R CMD check`, no package rebuild; independent of every
  other 1.1.0 item.
- [ ] TODO-20: **Harden the capability/slow-path registries — single
  source of truth** (added 2026-09-08, user decision):
  `harden_registry.md → TODO-1..4`. Maintenance, not a feature — no
  output/behavior change. Eliminates
  `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES`
  (`inference_class_registry.R`), a hardcoded "migration debt"
  capability-exclusion list whose three entries are provably redundant
  with what the affected classes already say about themselves — verified
  by a read-only, 39-class audit: exactly the same three classes, nothing
  more, nothing less. Folds them into the already-permanent
  `EDI_INFERENCE_EXCLUDED_CAPABILITIES` list as plain data (a dynamic
  package-load-time resolver was prototyped and rejected as unnecessary
  risk — see the plan's "Decision: static data, not a runtime resolver"),
  with a test-only (never package-load-time) drift-detection check added
  alongside. Surfaced two further, larger fact-duplication issues in the
  same session that this TODO does **not** attempt, both documented in the
  plan as explicit follow-on work: `comprehensive_tests.R`'s own four
  pre-registry hardcoded exclusion lists plus two single-class
  special-cases (needs a class-by-class structural-vs-performance sort,
  its own scoping pass first — "Finding 2"), and a recheck of the ~82
  already-registry-backed `EDI_COMPREHENSIVE_SLOW_PATHS` category-bucket
  entries for staleness (mechanically identical to this session's
  already-completed `exact_operations` recheck, just larger — "Also still
  open"). Independent of every other 1.1.0 item; no dependency on the
  decision batch.
- [ ] TODO-21: **Design/inference dependence-structure guard** (added
  2026-09-09; revised same day after a challenge to the first draft's
  scope — see the plan's opening note): `design_inference_dependence_
  guard.md → TODO-1..7`. Closes a registry blind spot: `discover_
  applicable_inference_classes()` only checks whether a design gives a
  candidate class structure it *requires* (`requires_kk`/
  `requires_blocking`), never whether the design *imposes* dependence
  (blocking, KK/matching pairs, clustering) the class's Wald-path variance
  ignores. **Not a uniform gate** — a tiered severity model, since the
  direction of the naive-SE error depends on estimand linearity: Tier 0
  (`ci_method = "rand"` is exact regardless, since the design's own
  re-randomization already respects blocking/matching/clustering — no
  action needed); Tier 1 (a linear-contrast class, e.g.
  `InferenceAllAverageDiff`, ignoring blocking/matching on the Wald path
  is provably conservative, never anti-conservative — stays in
  `run_all_inference()`'s default sweep (excluding it would remove a
  legitimate estimand, not just a redundant restatement — the suite's
  documented "many valid keys" design) but now raises a real, once-per-
  session-throttled `warning()` and carries a `dependence_note` results-
  column flag rather than sitting silent and unlabeled next to an exact
  number); Tier 2 (a nonlinear-link class, e.g. logistic regression,
  ignoring blocking/matching risks noncollapsibility attenuation *and* an
  understated SE — or any class ignoring clustering, which understates SE
  outright — hard-gated on the specific Wald-path compute methods, not on
  `$new()`, so `rand`-path methods on the same object stay exact and
  unblocked). Tier 2 gets the new `dependence_naive_on_design` discovery
  bucket, excluded from `run_all_inference()`'s default run with a steer
  toward the KK pair family for matched pairs. Tier assignment is a
  cheap lookup, not a per-`(class, design)` derivation: a one-time
  `splits_arms`/`shares_arm` classification per *design class* (TODO-2a —
  mechanical, fixed by which component it composes) crossed with a
  `estimand_linearity` link-function lookup per *inference class*
  (TODO-2b, defaulting conservatively to "nonlinear_link"); its own
  TODO-1 decision batch (gate placement, linearity rubric, two-speed
  clustering rollout since it has no corrected alternative until 5Y ships
  in v2.0.0) joins the Phase 0 sitting. Additive per this release's
  standing constraint: no result changes for Tier 0, Tier 1, or any class
  that already declares the capability it's run against. Independent of
  every other 1.1.0 item; companion to `cluster_robust_inference_glmm_
  gee.md` (5Y, v2.0.0), which this plan does not duplicate or block on.
  **Also surfaced (TODO-4c), and tracked whether it ships here or as its
  own item, a pre-existing, more general bug in `InferenceSuite`'s Cauchy
  combined-evidence weighting**: `run_all_inference()`'s `methods = NULL`
  default already fans out to every applicable method sentinel per class
  (up to 13, not just `rand`), and the default `"estimand_grouped"`
  weighting counts *rows* (`table(estimand)`) rather than distinct
  classes — correctly balancing across estimand groups but letting a
  class with more supported methods outvote a comparable single-method
  class within one, independent of dependence structure entirely (see the
  "Known gap found 2026-09-09" addendum in
  `../finished_features/inference_suite_plan.md`, which documented the
  original per-class design intent this drifted from). Fix: one
  highest-priority row per `(class, estimand)` feeds `combined_evidence`;
  `results_table` display is unaffected.
- [ ] TODO-22: **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`
  optimizer stability** (added 2026-09-11, found via a comprehensive-test-
  harness timing investigation, not a user report):
  `clayton_loggamma_frailty_optimizer_stability.md → TODO-1..4`. A ~200x
  bimodal slowdown (0.5-1s vs. 150-180s, same scenario, only the data
  realization differs) in `compute_lik_ratio_bartlett_approx_two_sided_
  pval()`'s B=99 Monte-Carlo null replicates, traced to the Clayton-copula/
  loggamma-frailty C++ optimizer having no bound on its dependence
  parameter (unlike the sibling normal-frailty optimizer's
  `max_abs_log_sigma=8.0` cap) plus a stale-gradient mismatch (the
  objective clips `theta` but the gradient terms don't), which can leave
  the optimizer thrashing toward its 2000-iteration cap and triggering an
  expensive R-level Nelder-Mead fallback cascade that only this class's
  fit path has. Additive/no-op for every other class (different `.cpp`
  file); needs a golden-test parity check to confirm the new bound doesn't
  move existing point estimates. Independent of every other 1.1.0 item.
- [ ] TODO-16: **Release mechanics**: see `release.md` for the full generic
  checklist (win-builder/mac-builder, check profile, submission artifacts,
  CHANGELOG, version bump, tagging/pushing/submitting go-ahead, post-
  acceptance plan moves) — run it on the 1.1.0 candidate; `edi_kernels`
  1.1.0 wheel ships from the same commit family, per `release.md`'s
  Python-coordination section.

## Standing constraints

All of `_master.md`'s standing constraints apply unchanged (update
`R/EDI/vignettes/extending-edi.Rmd` — which replaced `extending-edi-r6.md`
on 2026-08-23 — on any extension-contract change; new kernels follow
the SEXP/RcppEigen conventions including unity-build group membership; new
classes go through `define_inference_class()`/`define_design_class()`; tick
TODOs in owning plans). Additionally, everything in this release must be
**additive**: default behavior with no new switches set must reproduce
1.0.0 results bit-for-bit, except where a plan explicitly documents a
default change (currently TODO-11's class deletion, pending its
deprecation decision). TODO-4b is narrowed to measurement infrastructure
only in this release (`performance_profiling_and_upgrades.md →
TODO-132..135, 175`, all infrastructure-only, no gate needed); the
result-changing performance items formerly gated here
(`→ TODO-137/149/153/156`, each requiring opt-in or a documented default
change with re-justified equivalence tolerances) moved with the rest of
TODO-4b's remainder to `release_v1_2_0.md → TODO-11` on 2026-09-06 — that
file's own standing constraints restate this gate. TODO-9b's
`qubo_backend` defaults to `"none"`, which must reproduce 1.0.0's MILP → SA
results bit-for-bit; every external backend is opt-in and falls back to the
classical solver with a warning, never silently.
