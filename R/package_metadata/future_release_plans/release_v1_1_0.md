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
> | **1.1.0** (this file) | **Inference quality** — practitioner-standard estimators, likelihood corrections, diagnostics chain, ordinal Bayesian-bootstrap backends, KK beta OneLik, count quantile regression, Phase 0 decisions for every gated track | `release_v1_1_0.md` |
> | 1.2.0 | **Performance & engines** — kernel/perf lanes, cold starts, greedy-engine merge (soft-deprecation) | `release_v1_2_0.md` |
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
> **Stays / added here (1.1.0):** TODO-1, TODO-3, TODO-5, TODO-15b,
> TODO-15e, TODO-16, plus the new **TODO-17a..d** below — the audit
> backlog's small inference-side items, each now with an owning plan:
> `count_exposure_offset.md`, `heteroskedasticity_robust_standard_errors.md`,
> `small_estimand_additions.md`, and the nominal one-vs-rest vignette.
> (The audit backlog's *design-side* items —
> `sequential_design_classical_completions.md`,
> `rerandomization_criterion_variants.md`, and the rest of the theoretical
> backlog — live in 2.0.0 by user decision.) Also here: the ordinal Bayesian-bootstrap / randomization-CI
> plans and `randomization_ci_search_precision.md`.
> **Added 2026-08-27:** `fix_reusable_bootstrap.md` (**TODO-17e** below) —
> a small fix to already-shipped `tune_EDI_for_this_machine()` functionality
> (`local_machine_optimization.md`, closed in the v1.0.0 line), not new
> scope of its own.
> **Added 2026-08-29 (user decision):** `full_test_coverage.md`
> (**TODO-17m** below) — a triage-and-test-writing plan to take Codecov's
> line coverage from 64.79% (first successful upload after the
> `test-coverage-R.yaml` pipeline fixes, 2026-08-28) into the high 90s.
> Pure test-writing/CI-plumbing, no source-behavior change; independent of
> every other item in this release.
> **Added 2026-08-30 (user decision):** `wilkinson_combined_pval.md`
> (**TODO-17n** below) — a Wilkinson r-out-of-k order-statistic combination
> test for `InferenceSuite`, complementing the existing Cauchy
> combination-test-based `combined_evidence$pval` ("does at least one
> procedure detect a signal") with a "do most procedures agree" question the
> Cauchy statistic cannot answer. Staged: a cheap descriptive vote-count
> field ships regardless; the formal order-statistic test is gated on
> deciding whether its dependence-robust null-calibration cost is worth it.
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

The corrections family (**minus `marginal_estimand_report.md`, pulled into
v1.0.0 — amended 2026-08-18, user decision; see `release_v1_0_0.md`'s item
14**): `expanded_estimate_report.md` (`estimate_type` — moved back here
2026-08-18, still an open Phase 0 decision, see `TODO-1` step 1 below),
`bias_correction_cox_snell.md`, `cordeiro_mccullagh_bias_correction_report.md`,
`score_correction_cordeiro_ferrari.md`, `gradient_correction_lemonte.md`,
`likrat_correction_bartlett.md`, `firth_penalties_report.md`,
`l1_l2_penalties_all_likelihood_paths_report.md`,
`median_bias_correction_likelihood_paths_report.md`,
`modified_profile_likelihood_report.md`, `bootstrap_calibrated_lr_report.md`
(its remaining Difficult-tier work).

The diagnostics family: `optimizer_diagnostics_report.md` (TODO-1, 2, 3, 5),
`public_diagnostics_api_spec.md`, `prw_subsampling_implementation_spec.md`
(its remaining TODO-14..17 splice and TODO-20).

The ordinal inference-quality family (Bayesian bootstrap and
randomization-CI guards): `ordinal_kk_gee_bayesian_bootstrap.md`,
`ordinal_stereotype_logit_bayesian_bootstrap.md`,
`ordinal_adjacent_category_logit_bayesian_bootstrap.md`, and
`ordinal_model_coefficient_randomization_confidence_intervals.md`. These
plans remain separately owned because they guard different estimators and
capabilities, even though they share the v1.1.0 release lane.

The incidence randomization-CI correction:
`incidence_randomization_cis.md` — per-estimand-scale Zhang intervals,
following the temporary hard-disable and independent of the generic CI-search
precision plan.

The negative-binomial convergence correction:
`negbin_dispersion_convergence.md` — the selected eventual Option 1
reparameterization of the dispersion coordinate, with the completed boundary
acceptance mitigation retained as a compatibility bridge.

The kernel/perf family: `robust_regression_perf_optimization_spec.md`,
`quantile_regression_cpp_kernel_spec.md`, `ordinal_gee_cpp_kernel_spec.md`,
`cold_starts.md`, `gpu_optimizations.md` (decision-gated),
`quantum_upgrade.md` (decision-gated; added 2026-08-22, its TODO-1 sits
behind `gpu_optimizations.md → TODO-7` in the Phase 0 batch),
`performance_profiling_and_upgrades.md` (§8 "Phase 8", TODO-132..179; added
2026-08-23, user decision — not decision-gated, measurement-first; see
`TODO-4b`). `quantum_upgrade.md`'s implementable Part I items — `→ TODO-2..6`
plus the hardware-detection / classical-fallback work `→ TODO-9..12` (§I.7,
added 2026-08-23, user request) — are indexed as `TODO-9b` below, gated on
its `→ TODO-1` decision (Phase 0 step 9b).
(`local_machine_optimization.md` moved to v1.0.0 — see
`release_v1_0_0.md`'s item 15 — 2026-08-20, user decision.)
Three further kernel/perf plans added 2026-08-30 (user decision), all
measurement-first and indexed as `TODO-4d`/`4e`/`4f` below:
`fixed_size_eigen_small_p.md` (compile-time-`p` Eigen dispatch),
`lto_reevaluation.md` (re-measure the `-fno-lto` default on triggers, flip
rule written down), and `memory_layout_row_major_irls.md` (cache threshold
for column-major `X` under row-wise IRLS; policy for kernel authors).

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

`fix_reusable_bootstrap.md` (added 2026-08-27; `→ TODO-1..6`; see `TODO-17e`
below) is a small, additive follow-on fix to that shipped feature, not a new
track.

The test-coverage family (added 2026-08-29): `full_test_coverage.md` (see
`TODO-17m` below) — triage and test-writing to take Codecov's line coverage
from 64.79% toward the high 90s, plus a coverage-floor CI gate against
backsliding. Pure test/CI-plumbing work; no source-behavior change and no
dependency on any other 1.1.0 item.

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

The KK one-stage-estimation family (added 2026-08-18): `kk_beta_regression_one_lik_derivation.md`
— a genuine Beta-family (not quasi-binomial) one-stage `OneLik` joint
likelihood for proportion responses under KK designs, closing one of the
two remaining gaps named in `../new_research_ideas/KK_followup_research_plan.md`.
Additive, no decision gate; may run in parallel with the response-type
family above once TODO-1's KK-migration dependency (see the plan's own
`Depends on` header) is satisfied.

The quantile-regression-family extension (added 2026-08-26, brainstormed
and approved same day): `survival_quantile_regression.md` — a custom
self-consistent EM estimator (Peng-Huang estimating equations extended to
general interval censoring) for survival responses, with both bootstrap
and asymptotic-sandwich inference, plain plus KK IVWC/one-lik variants,
and randomization inference on the KK variants — and
`count_quantile_regression.md` — jittered (Machado & Santos Silva 2005)
`rq()` for count responses, `B`-averaged point estimate, single-jitter-draw
bootstrap/randomization refits, same plain plus KK IVWC/one-lik scope.
Both additive, no decision gate (design already approved via
brainstorming); both build on `quantreg::rq()` like the rest of the
quantile-regression family and are natural `use_rcpp` candidates once
`quantile_regression_cpp_kernel_spec.md` lands, but do not depend on it.
May run in parallel with any other track.

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
decision — Inference-object serialization, motivated by expensive
resampling under slow models, e.g. a bootstrap distribution from thousands
of ZOIB refits). **Scope-rule exception, stated explicitly**: this plan
file is named in `release_v1_0_0.md`'s In-scope list because its Design-side
sections A–D shipped in v1.0.0; the file moved back from
`../finished_features/` to `new_feature_plans/` on 2026-09-01 carrying only
section E as open scope. Only section E is in this release; A–D remain
closed v1.0.0 history. See TODO-17r below.

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
- [ ] TODO-4b: **Performance profiling & upgrades lane**
  (`performance_profiling_and_upgrades.md` §8 → TODO-132..179; added
  2026-08-23, user decision; parallel with TODO-3/TODO-4, no Phase 0
  dependency; the owning plan ticks its own TODOs — this is the index
  entry). Run in that plan's own "Suggested order":
  1. measurement infrastructure first — `→ TODO-132..135, 175`
     (debug-symbol call-graph build, callgrind/cachegrind, top-down
     microarchitecture analysis, benchmark noise floor + regression gate,
     machine-state logging); these make every later A/B trustworthy and
     cheap, and the plan's `profile/install_perf_tools.sh` /
     `verify_perf_tools.sh` tool roster is already installed on the dev box
     (§8.0.1);
  2. generated-code audits — `→ TODO-167, 168, 166` (instruction mix,
     compiler optimization reports, `llvm-mca`/OSACA/uiCA on the hot loops);
  3. the large levers — `→ TODO-136, 137` (vectorized exp/log via libmvec
     *without* `-ffast-math`) and `→ TODO-153` (adaptive Gauss–Hermite);
  4. end-to-end and R-layer — `→ TODO-158, 177, 173, 159, 160, 161` (this
     decides whether further kernel work moves user-visible time at all);
  5. parallelism and BLAS — `→ TODO-147, 148, 174, 176, 149, 150` — ideally
     alongside `tune_EDI_for_this_machine()` (v1.0.0 item 15) so its policy
     tables benchmark the right axes (thread thresholds, OMP × BLAS × fork
     oversubscription, BLAS backend);
  6. `→ TODO-171` (roofline — decides where to stop), then the remainder as
     the measurements dictate: `→ TODO-138..146, 151, 152, 154..157, 162..165,
     169, 170, 172, 178, 179`.
  Bare-metal sub-batch (§8.0.2/8.0.3): `→ TODO-143` (`perf c2c`/`perf mem`),
  `→ TODO-171`, `→ TODO-175`, the Intel PT option of `→ TODO-132`, and the
  *published* numbers for `→ TODO-135/147/148` run in one rented
  `c7i.metal-48xl` session (single machine covers every Intel-side check;
  AMD/ARM rows optional); everything else runs on the dev box (WSL2 caveats
  measured and recorded in §8.0.1/8.0.2). Every fix follows the document's
  "root cause → fix → correctness → paired ABBA/BAAB benchmark" standard and
  this repo's targeted-compile-only rule; no timing number is cited anywhere
  without a measurement behind it (the plan's §8.8 payoff table is explicitly
  a-priori). **Additive-constraint gates** (see Standing constraints): `→
  TODO-137` (libmvec, ≤4 ulp result differences) and `→ TODO-153` (adaptive
  quadrature, changes GLMM numerics at tolerance level) break the bit-for-bit
  default rule — each ships either opt-in (configure flag / fit argument) or
  as an explicitly documented default change with the equivalence tests'
  tolerances re-justified; `→ TODO-156` (Monte-Carlo early stopping) is a
  statistical-policy change and ships **opt-in only**; `→ TODO-149` (non-R
  RNG streams) changes draws under `set.seed()` and must be opt-in or
  documented as a default change. Infrastructure items (`→ TODO-132..135,
  164, 166..168, 171..179`) ship no user-facing change and need no gate.
  Exit criterion: every one of `→ TODO-132..179` has either a measured entry
  or a "measured and dropped" note in the owning plan (its convention), §8.8's
  estimates are superseded by those measurements, and
  `benchmark_model_fits.md` has been re-run under the `→ TODO-135` gate.
- [ ] TODO-4c: **More SIMD optimization lane** (`more_simd_optimization.md`
  → TODO-1..7; added 2026-08-27, user decision, slated for v1.1.0 alongside
  TODO-4b). Premise: power users compile from source, so runtime ISA
  dispatch is moot and the work is making the compiler actually vectorize
  the hot loops. **No duplication with TODO-4b:** every diagnostic/
  measurement item — the opt-report sweep, the fast-math-subset/libmvec
  test, the Eigen-vectorization audit, the `.row(i)` classification, the
  GLM-objective branch-free layout — is owned solely by TODO-4b
  (`performance_profiling_and_upgrades.md` TODO-168/137/136/144/154); this
  lane consumes those results and owns only the implementation work that
  is not already numbered there. Run in that plan's own order: `→ TODO-7`
  (flag-only: `-fopenmp-simd` for the macOS gap, no dependency) → `→
  TODO-1` (`__restrict` sweep, once TODO-4b's TODO-168 reports aliasing
  findings) → `→ TODO-2` (wires TODO-4b's TODO-137 result into `configure`
  once it reports) → `→ TODO-3` (aligned `Map` copies, once TODO-4b's
  TODO-136 reports) → `→ TODO-4` (split-search SoA, extends TODO-4b's
  TODO-144 sweep to the tree files first) → `→ TODO-5` (branch-free
  split-search comparisons — same technique as TODO-4b's TODO-154 but a
  different code path, the split threshold rather than the GLM objective)
  → `→ TODO-6` (float32 for split ranking, gated on a ranking-equivalence
  test). **Additive-constraint gate:** `→ TODO-6` (float32) can change
  results at tolerance level and ships opt-in or with re-justified
  equivalence tolerances; `→ TODO-2` inherits whatever gate TODO-4b's
  TODO-137 assigns (libmvec, ≤4 ulp); `→ TODO-1, 3, 4, 5, 7` are
  bit-for-bit or flag-only. Exit criterion: every `→ TODO-1..7` has a
  measured entry or a "measured and dropped" note, and none of them
  duplicate a TODO-4b measurement.
- [ ] TODO-4d: **Fixed-size Eigen specializations for small `p`**
  (`fixed_size_eigen_small_p.md → TODO-1..5`; added 2026-08-30, user
  decision). Compile-time-`p` dispatch for the `p×p` IRLS/Newton algebra
  (`XᵀWX`, LDLᵀ solve, `H⁻¹g`) — Eigen unrolls and stack-allocates
  fixed-size types, a 2–3× win on that algebra at `p ≤ 8`, but the `O(np)`
  data passes dominate at EDI's `n`, so the whole-fit gain is smaller and
  is measured first. Gated on its own `→ TODO-1` microbenchmark (drop if
  whole-fit gain < 10%). **No duplication with TODO-4b:** the audit of
  which decompositions run at which sizes is TODO-4b's TODO-155; this lane
  owns the dispatch mechanism and consumes that list. Bit-for-bit with the
  dynamic path or ships behind a flag.
- [ ] TODO-4e: **LTO re-evaluation** (`lto_reevaluation.md → TODO-1..4`;
  added 2026-08-30, user decision). `-fno-lto` is the measured-negative
  default (`configure:74-81`, README build table); standing action is
  none. This lane records the original baseline (compiler/Eigen/unity-build
  state), re-measures `EDI_NATIVE_LTO=1` under the current toolchain via
  the `→ TODO-135` protocol, writes down the flip rule (no kernel regresses
  beyond noise **and** geometric-mean gain > 5%; any mixed result is a no),
  and adds re-measurement triggers (GCC major bump, RcppEigen major bump,
  unity-grouping change) to `release.md`. Deliverable is a dated decision
  line, not necessarily code.
- [ ] TODO-4f: **Memory layout — column-major `X` under row-wise IRLS**
  (`memory_layout_row_major_irls.md → TODO-1..4`; added 2026-08-30, user
  decision). Row-wise access to column-major `X` strides by `n·8` bytes;
  invisible while `X` is L2-resident (`n·p·8 < ~1 MB`, i.e. `n ≲ 10⁴` at
  `p = 10`) and only costs past cache. `→ TODO-1` finds that threshold
  empirically; if EDI's regime never reaches it, the plan closes with the
  number documented in `extending-edi.Rmd`. **No duplication with
  TODO-4b:** the 75-site `.row(` classification is TODO-4b's TODO-144;
  this lane consumes it (`→ TODO-2` triage: fix now / never / if `n`
  grows) and owns only the uniform mechanism (`→ TODO-3`, preferring the
  weight-vector + `rankUpdate` form over row-major copies) and the policy
  paragraph.
- [ ] TODO-5: **Corrections track** (`_master.md` Phase 5A order, minus
  `marginal_estimand_report.md`, moved to v1.0.0, amended 2026-08-18;
  `expanded_estimate_report.md` moved back here the same day; each
  decision-gated item gated by its TODO-1 decision):
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
     → TODO-3` (joint semantics recorded once in both plans),
  5. `l1_l2_penalties_all_likelihood_paths_report.md → TODO-2` then
     `→ TODO-4`,
  6. `median_bias_correction_likelihood_paths_report.md → TODO-3..4` (only
     after Firth ships),
  7. `modified_profile_likelihood_report.md → TODO-2..4`,
  8. `bootstrap_calibrated_lr_report.md → Difficult-tier work` (if TODO-1.7
     said yes).
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
- [ ] TODO-15b: **KK one-stage Beta-regression estimator** (added
  2026-08-18): `kk_beta_regression_one_lik_derivation.md → TODO-1..10` —
  TODO-1 (prototype validation) first; TODO-2/TODO-3 (glmmTMB-reuse cheap
  path + its golden tests) ship before TODO-4/TODO-5 (the from-scratch
  Gauss-Hermite backend and its `OneLik` class), mirroring
  `InferenceContinKKGLMM`'s own `use_rcpp` history. Additive and
  independent of every other track in this file; may run in parallel with
  TODO-6's response-type track any time after its own KK-migration
  dependency is met (see the plan's `Depends on` header).
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
- [ ] TODO-15e: **Count quantile regression** (added 2026-08-26):
  `count_quantile_regression.md → TODO-1..N` (implementation plan not yet
  written) — `InferenceCountQuantileRegr` plus
  `InferenceCountKKQuantileRegrIVWC`/`OneLik`, Machado & Santos Silva
  (2005) jittered `rq()` with `B`-averaged point estimates and
  single-jitter-draw bootstrap/randomization refits. Additive, no decision
  gate. May run in parallel with every other track; independent of
  TODO-15b/15d.
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
- [ ] TODO-17c: **Small estimand additions** (added 2026-08-27):
  `small_estimand_additions.md → TODO-1..7` — Hedges' g, win odds /
  Brunner-Munzel across all six types, Mantel-Haenszel OR/RD,
  non-inferiority / equivalence conveniences, unconditional QTE, log-link
  QMLE / Gamma-log for continuous non-negative `y` (inference audit #6,
  #11, #17–#20). Each sub-item independent.
- [ ] TODO-17d: **Nominal one-vs-rest vignette** — if
  `nominal_response_type_report.md → TODO-1` is decided "no" in this
  release's Phase 0 sitting, its TODO-1b (vignette section +
  cross-reference to the multivariate plan) ships here and the report
  closes to `../finished_features/`; otherwise it stays a 2.0.0 item.
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
- [ ] TODO-17f: **NegBin mixture marginal estimand** (added 2026-08-27):
  `marginal_estimand_report.md → TODO-10` — reopened (moved back from
  `../finished_features/`) to extend `set_estimand("marginal_mean_diff"/
  "marginal_ratio")` to `InferenceCountZeroInflatedNegBin` and
  `InferenceCountHurdleNegBin`, the two mixture classes left out of scope
  when the Poisson siblings were wired (TODO-5/9 above). Needs a rederived
  truncated-NegBin mean formula (the Poisson shortcut does not generalize)
  and confirmation of the NegBin joint-information-matrix shape before the
  same `define_inference_class(components = "MarginalEstimand")` conversion
  TODO-5 already used for the Poisson concretes. Not started; see the
  plan's TODO-10 for the full scope. Independent of other 1.1.0 items —
  schedule alongside TODO-17c (estimand additions) if convenient.
- [ ] TODO-17g: **Ordinal KK GEE Bayesian bootstrap**
  `ordinal_kk_gee_bayesian_bootstrap.md` — restore weighted refits that use
  the primary `multgee::ordLORgee` estimating equations and matched/reservoir
  clustering, then enable the guarded capability after parity and calibration
  tests.
- [ ] TODO-17h: **Ordinal stereotype-logit Bayesian bootstrap**
  `ordinal_stereotype_logit_bayesian_bootstrap.md` — implement weighted
  refits of the native stereotype-logit estimator and enable its registry
  capability only after draw-level parity tests.
- [ ] TODO-17i: **Ordinal adjacent-category-logit Bayesian bootstrap**
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
- [ ] TODO-17m: **Full test coverage triage** (added 2026-08-29):
  `full_test_coverage.md → TODO-1..10` — take Codecov's line coverage from
  64.79% (first successful upload after `test-coverage-R.yaml`'s
  `stop_on_failure = FALSE` fix, 2026-08-28) into the high 90s. Phase 1
  builds a tracked `coverage_gap_registry.csv`; Phase 2 targets the 31
  files currently at literal 0.00% (performance-dispatch kernels only
  reachable above thresholds the test suite deliberately stays under,
  a handful of untested classes, diagnostic-only code); Phase 3 works the
  broadly-thin remainder by weighted opportunity
  (`(1 - coverage) * lines_of_code`); Phase 4 adds a coverage-floor CI
  gate. Pure test-writing/CI-plumbing — no source-behavior change; a real
  bug surfaced along the way becomes its own separate fix, not folded in
  here. No dependencies on other 1.1.0 items; run whenever convenient.
- [ ] TODO-17n: **Wilkinson r-out-of-k combined-evidence test** (added
  2026-08-30): `wilkinson_combined_pval.md → TODO-1..5` — `InferenceSuite`'s
  existing `combined_evidence$pval` (Cauchy combination test) answers "does
  at least one applicable procedure detect a signal," but structurally
  cannot answer "do most agree" (its tan-transform statistic is always
  dominated by the smallest p-value). Stage 1 (TODO-2, cheap, no new theory)
  ships a plain descriptive vote-count field (`vote_fraction`, overall and
  per-estimand); Stage 2 (TODO-1 gate, then TODO-3/4) is a formal
  r-th-order-statistic test, gated on deciding whether its
  bootstrap/permutation null-calibration cost (no closed-form result exists
  under arbitrary dependence, unlike CCT) is worth it. No dependencies on
  other 1.1.0 items.
- [ ] TODO-17o: **Randomization CI affine-shift reuse** (added 2026-08-30,
  user decision): `randomization_ci_affine_shift_reuse.md → TODO-1..6`. The
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
  verification. Independent of other 1.1.0 items.
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
- [ ] TODO-17r: **Inference-object serialization** (added 2026-09-01, user
  decision): `save_load_api.md → section E (E-1..E-7)`. Make a fitted
  `Inference` object a supported `saveRDS()`/`readRDS()` unit so expensive
  resampling state (e.g. a bootstrap distribution from thousands of slow
  ZOIB refits) survives a session, mirroring the v1.0.0 Design-side audit:
  reload-contract decision (E-1, ask the user), private-field/component
  `owns_state` audit (E-2), XPtr liveness handling ported from
  `ensure_custom_objective_xptr_live()` (E-3), version stamp +
  self-initializing fields on `Inference` (E-4), cache-persistence
  semantics (E-5), round-trip tests including the expensive-resampling and
  custom-C++-statistic paths (E-6), and documentation updates including
  the JSS manuscript's "candidate for a future release" sentence (E-7).
  Additive; independent of other 1.1.0 items except that E-2 is cheapest
  after any 1.1.0 work that adds `Inference`-side state has landed.
- [ ] TODO-17s: **Multistart for the nonconcave likelihood kernels** (added
  2026-09-03, user decision): `multistart_nonconcave_likelihoods.md →
  TODO-1..10`. Correctness / robustness, not performance. The 2026-09-03
  audit (`quantum_upgrade.md → §II.6`) found that every kernel whose
  likelihood is *not* concave — GLMM / LMM / frailty marginal likelihoods,
  ZINB / ZIP / ZOIB mixtures, negbin and hurdle negbin in `(β, log θ)`,
  beta regression, stereotype logit, Clayton-copula and dependent-censoring
  survival, ordinal cauchit, Tukey-bisquare robust regression — runs a
  single descent from one smart cold start, except `fast_ordinal_glmm.cpp`
  (a 5-point deterministic `log σ` sweep) and `fast_hurdle_negbin.cpp`
  (extra starts tried only on failure). One new leaf header
  `src/optimization_multistart.h` (`optimize_fixed_likelihood_multistart()`
  wrapping the existing `optimize_fixed_likelihood()`; family-specific
  deterministic starts + a reproducible random layer from a private
  `edi_rng::RRng`, never R's stream), three new kernel arguments
  (`n_random_starts`, `multistart_jitter_sd`, `multistart_seed`), four
  provenance fields, a `get_multistart_dispatch_policy()` table mirroring
  the cold-start one, and `set_multistart()` on the abstract class.
  **Bit-for-bit** whenever the primary start already reaches the best
  optimum found (ties go to the primary), on every replicate
  (warm-started) fit, and on every concave kernel; the ordinal GLMM
  refactor is bit-for-bit unconditionally. Bisquare robust regression
  additionally starts from a converged Huber fit instead of OLS. Python
  `edi_kernels` parity included. Independent of other 1.1.0 items; shares
  the "new leaf header, targeted compile only" discipline with TODO-17q.
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
deprecation decision, and — added 2026-08-23 — any of TODO-4b's
result-changing performance items, `performance_profiling_and_upgrades.md
→ TODO-137/149/153/156`, each of which must ship opt-in or as a documented
default change with its equivalence-test tolerances re-justified; the
measurement-only items there change nothing user-facing). TODO-9b's
`qubo_backend` defaults to `"none"`, which must reproduce 1.0.0's MILP → SA
results bit-for-bit; every external backend is opt-in and falls back to the
classical solver with a warning, never silently.
