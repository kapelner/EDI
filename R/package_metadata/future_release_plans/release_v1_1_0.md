# Release Scope: v1.1.0

> **CRAN (2026-09-24, user decision):** the first CRAN submission is **v1.0.2**,
> not v1.1.0; 1.0.0 and 1.0.1 were GitHub-only. This release follows the CRAN
> submission. `R/EDI/cran-comments.md` describes 1.0.2.

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
> | **1.0.5** | **Bug fixes and hardening, no new capability** — split out of v1.1.0 on 2026-09-23 (user decision) so audit-found correctness bugs and pre-existing-feature fixes ship without waiting on v1.1.0's Phase 0 decisions: the pre-1.1.0-audit-wave randomization-CI/kernel fixes (affine reuse, dead-kernel wiring, information-inverse guards, the Cox-scale CI audit, the Weibull-frailty optimizer stability fix, the reusable-bootstrap-worker fix), and every `comprehensive_tests`-CSV-audit-found bug from 2026-09-17 on (`KKQuantileRegrOneLik` rand CI, stereotype-logit multimodality, stale worker-cache resampling, MC coverage-truth covariate mismatch, the Cox Bartlett-approx investigation, `InferencePropGCompMeanDiff`/`InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` all-NA bugs, `InferenceContinLin` and ordinal-cumulative-link parametric-bootstrap Type-I inflation) | `release_v1_0_5.md` |
> | **1.0.6** | **Bug fixes found during v1.0.5 work, no new capability** — added 2026-11-10 (owner decision): the v1.0.5-born bugs that had been parked here (call-history dependence, wrong or NA output, false convergence, the GLMM/CLMM warm-start regression) moved to v1.0.6, with a triage of the accepted calibration rows. Entry rule, gates and the per-TODO placement are in that file. | `release_v1_0_6.md` |
> | **1.1.0** (this file) | **Inference quality + CPU performance core** — the shared-cumulant likelihood corrections, Firth, the diagnostics chain, honest inference after model selection (Phase A), the randomization-CI speed/correctness core (Brent's method for CI inversion; the affine-shift reuse/kernel-wiring/inverse-guard fixes moved to v1.0.5), Phase 0 decisions for every gated track | `release_v1_1_0.md` |
> | 1.2.0 | **Performance & engines** — kernel/perf lanes (the full profiling program, SIMD, fixed-size Eigen, LTO, memory layout), the algorithm-choice A/B harness and its two Prototype items, ordinal Bayesian-bootstrap backends, count quantile regression, serialization, test-coverage triage, cold starts, greedy-engine merge (soft-deprecation) | `release_v1_2_0.md` |
> | 1.3.0 | **Design extensions from practice** — cluster-level balancing designs + saturation, unequal allocation + Neyman helper, many-by-many sequential family *(the theoretical-design backlog — classical completions, rerandomization criteria/samplers/diagnostics, optimal-objective extensions, GSW / balancing walk / ARM-PSR — moved to 2.0.0, user decision)* | `release_v1_3_0.md` |
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
> **Second lighten pass (2026-10-20, user decision):** TODO-40, -41, -42, -43, -44, -45, -46, -49, -51, -53, -54 and TODO-17z moved to `release_v1_2_0.md → TODO-24..35` (stubs below). The stay-list in the next paragraph already excludes TODO-17z.
>
> **Stays / added here (1.1.0):** TODO-1, TODO-3, TODO-5 (core), TODO-16,
> TODO-17y, TODO-17d (nominal vignette — ownership resolved to
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
> **Added 2026-08-27:** `../finished_features/v1_0_5/reusable_bootstrap.md` (**TODO-17e** below) —
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
>
> **Bug-fix/feature split (2026-09-23, user decision):** every item in this
> file that fixes something already shipped in v1.0.0 behaving wrongly —
> a bug, a dead/misfiring performance path, an unguarded numerical edge
> case — moved to a new sixth release file, `release_v1_0_5.md`, so those
> fixes aren't gated on this release's Phase 0 decisions or diagnostics-
> chain prerequisite. Moved: TODO-17e, TODO-17o, TODO-17p, TODO-17q,
> TODO-17x, TODO-22, TODO-25, TODO-30..38 (see each item's own "moved"
> stub below for detail). Everything that stays here adds new
> inference-quality machinery, not a fix to existing behavior.

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

Reproducibility *(added 2026-10-11, user decision; from
`marketing_plans/agent_proofing.md` W6)*: `cross_platform_reproducibility.md`
(`TODO-48`). It states the package's reproducibility guarantee (revised
2026-10-15, decision D3): RNG-only random draws are exactly identical across
platforms, thread counts and worker counts; one installed build is
bit-identical across runs, thread counts and worker counts for every output;
optimizer-chosen allocations match across platforms except at documented
near-ties; floating-point outputs agree across platforms within a
documented tolerance. It adds a
reproducibility record to every result, makes thread- and worker-count
independence a package-wide invariant with a static ban, fixes p-value tie
counting if verification confirms the problem, and enforces all of it with
golden digests on every CI platform leg. Each of its seven TODOs ships with
required tests. It builds on `release_v1_0_5.md → TODO-91, -93, -95`.

Algorithm choice *(added 2026-10-15, user decision)*:
`algorithm_choice_audit.md`'s items that are faster **and** at least as
accurate, with no new user options (`TODO-50`). The speed-only items and the
items that need the A/B harness are in `release_v1_2_0.md → TODO-22, -23`.

InferenceSuite performance **[moved to `release_v1_2_0.md → TODO-32` on 2026-10-20]** *(added 2026-10-15, user decision; from
`../audits/further_optimizations.md` section 3)*:
`inference_suite_worker_pool.md` (`TODO-51`). `run_all_inference()` moves
from one forked child per task to a pool of long-lived workers, about
halving its CPU, with per-task seeding so results no longer depend on
worker count.

Repository hygiene *(maintenance, added 2026-09-16, user decision)*:
`implement_a_lintr.md` (a `.lintr` codifying EDI's actual `=`/tab house
style, correctness linters on, content-gated hook + CI step — `TODO-23`)
and `spellcheck.md` (`spelling` + `inst/WORDLIST` + `tests/spelling.R` —
`TODO-24`). Both depend on nothing and can land at any point in the
release; neither changes runtime behavior.

Resampling performance *(added 2026-10-07, user decision)*:
`bayesian_bootstrap_performance.md` (`TODO-39`) **moved to v1.0.5 the same
day** (user decision) as `release_v1_0_5.md → TODO-57`, with its owning plan
now in `../bug_fix_plans/`. It fixes a misfiring performance path that already
shipped, so it falls under the 2026-09-23 split rule.

Exact and closed-form randomization inference **[TODO-40..42 moved to `release_v1_2_0.md → TODO-24..26` on 2026-10-20]** *(added 2026-10-07, user
decision; from the `coin` comparison in the 2026-10-07 benchmark
investigation)*: `exact_randomization_nulls_closed_form.md` (`TODO-40`:
hypergeometric / binomial / convolution PMFs and Strasser–Weber exact
moments as `type = "exact_null"` / `"asymptotic_null"`) and
`exact_rank_tests_shift_algorithm.md` (`TODO-41`: Streitberg–Röhmel shift
algorithm for exact Wilcoxon-family p-values and CIs with ties; depends on
`TODO-40`'s hook). Both additive and opt-in; each has one decision-gated
default switch (standing constraints below). Alongside them,
`../bug_fix_plans/v1_1_0/permutation_signature_once.md` (`TODO-42`) stops
re-hashing and re-copying the cached permutation set on every call; kept
in this release by user decision although the 2026-09-23 split rule would
place it in v1.0.5.

Canonical parity for the resampling rows **[TODO-43..46 moved to `release_v1_2_0.md → TODO-27..30` on 2026-10-20]** *(added 2026-10-07, user
decision)*: `canonical_parity_resampling_rows.md` (`TODO-43..46`) profiles
both sides of the five procedure-table rows EDI loses (mean-difference
randomization test vs `coin`; OLS / logistic / Cox percentile bootstrap vs
`boot`; Zhang exact CI vs `fisher.test`), records what is borrowable under
each package's license (nothing from GPL-2 `coin`; `boot`'s `norm.inter`;
`fisher.test`'s log-density precompute), sets the parity gates on top of
the v1.0.5 mechanical fixes, and adds the cross-cutting finding that R6's
environment rebinding discards bytecode so every instance is recompiled by
the JIT on first use.

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
`../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md` — the selected eventual Option 1
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

`../bug_fix_plans/v1_0_5/guard_unguarded_information_inverse.md` (added 2026-08-30; `→ TODO-1..5`;
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

`custom_rand_stat_batched_cpp_loop.md` (added 2026-10-13, user decision;
`→ TODO-1..7`; moved to `release_v1_2_0.md → TODO-31` on 2026-10-20) — moves `InferenceRandCustom`'s
per-permutation loop over `w_mat` from R into one C++ call that dereferences
the user's compiled statistic once, the pattern
`design_optimal_annealing_search.cpp` already uses for `custom_objective`.

The honest-inference-after-model-selection family's no-substrate half
(moved from v2.0.0 on 2026-09-05, user decision; see `TODO-17y` /
`TODO-17z`, which moved to `release_v1_3_0.md → TODO-5..6` on 2026-10-20): `model_selection_framework.md` **Phase A** — the
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

`../finished_features/v1_0_5/reusable_bootstrap.md` (added 2026-08-27; `→ TODO-1..6`; see `TODO-17e`
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

Covariate coefficient table *(added 2026-10-09, user decision)*:
`covariate_coefficient_table.md` (`TODO-47`) adds a public
`get_coefficient_table()` (a `coef(summary(glm))`-style Wald table for the
adjustment covariates, not just `w`), and has `get_summary()` print it instead
of the raw fit list. It ships **only on classes that support it**: a single
covariate regression whose full covariance can be formed with the same
estimator as the class's own treatment SE. The full vcov is built lazily and
never on a resampling hot path, so no existing result changes. **Hard
constraint (2026-10-09, user decision):** all of this is a new, separate
path. The treatment-variance path (`generate_mod()`, `shared()`, the kernels
it calls, their outputs and caches) is untouched and gains no work, memory or
kernel arguments.

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

- [ ] ~~TODO-74~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-1`** (owner approval of the v1.0.6 triage): Bayesian jackknife depends on call history.

- [ ] TODO-1: **Phase 0 decision batch** (ask the user, no code — one
  sitting, in this order because decisions cascade; this is `_master.md`
  Phase 0 verbatim, minus `marginal_estimand_report.md → TODO-1`, which
  moved to v1.0.0 and was decided **yes** there (2026-08-18); plus
  `expanded_estimate_report.md → TODO-1`, moved back here the same day —
  when decided, check which `estimand` values
  `marginal_estimand_report.md → TODO-3` already landed on so neither
  enum absorbs the other's):
  - Owner decision pending: [DECISION-v1.1.0-TODO-1](PENDING_DECISIONS.md#DECISION-v1.1.0-TODO-1) (the ten Phase 0 decisions, in cascade order).
  ~~11. `local_machine_optimization.md → TODO-1` remaining parts~~ — moved
  to v1.0.0 (2026-08-20, user decision; see `release_v1_0_0.md`'s item 15).
  ~~12. `randomization_ci_construction_audit.md → TODO-1`~~ — implemented
      2026-09-06 (see `TODO-17x` below). Cox-family
      randomization CI on the wrong scale. (A second item, the null
      construction, was withdrawn 2026-09-05: the code already uses
      impute-then-permute, verified by test — see that plan's §B.)
  - Decided 2026-09-06 (owner): refuse, like the stratified class; see [DECISION-v1.1.0-TODO-1a](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-1a).
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
- [ ] TODO-3a (added 2026-11-04, user decision; **after TODO-3**, it reports
  through the diagnostics it returns): **Zero-inflated score test on a
  partly collapsed zero-inflation submodel.** When the data have zeros but
  no excess zeros for part of the covariate space, the ZIP/ZINB
  (`InferenceCountZeroInflatedPoisson`/`NegBin`) zero-inflation logits run
  to +-Inf along a flat ridge: the null refits tie in neg-log-likelihood
  (to ~1e-6) at very different zi coefficients, the nuisance information
  block is numerically singular (min eigenvalue ~1e-14 vs max ~300), and
  `score_test_from_score_information_cpp`'s Schur complement
  `I_jj - I_jn I_nn^-1 I_nj` loses its precision, so the score p-value
  depends on where the optimizer stopped (0.00012 vs 0.064 at the same
  delta; root cause in the 2026-11-03 trail learning). Expected to be rare
  on real data (the calibration harness hit it only because it fed these
  classes plain Poisson counts, now fixed), and numerical error there is
  acceptable for now (user ruling 2026-11-04). Fix: (a) extend the
  2026-09-07 #18 boundary rule (all fitted pi ~ 0) to saturated zi
  coefficients; (b) compute the efficient information through an
  eigen-truncated pseudo-inverse of `I_nn` (relative tolerance ~1e-8),
  which gave the same p on both ridge points (0.0504/0.0504), replacing
  `score_test_with_ridge_fallback` on that path; (c) report the collapse
  through TODO-3's diagnostics instead of silently. The no-zeros case is
  handled separately (v1.0.5: error on the user's data, non-inflated
  fallback inside resampling).
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
- [ ] ~~TODO-11~~ **(split 2026-08-27: merge + soft-deprecation → `release_v1_2_0.md → TODO-5`; the hard deletion of `DesignFixedGreedy`/`DesignFixedGreedyDOptimal` → `release_v2_0_0.md → TODO-7`)**: **Greedy-design merge**:
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
  decision): `../finished_features/v1_0_0/interval_censored_survival_response.md →
  TODO-29` — rename the survival event/censoring indicator `dead` to
  `uncensored` (R, C++, docs, Python binding), now that left-/
  interval-censoring means `dead` no longer accurately describes the field.
  Wide blast radius (~576 R occurrences, `src/*.cpp`/`*.h`, Python
  binding).
  - Decided 2026-08-19 (owner): full hard rename in R, C++ and Python, no compat alias; see [DECISION-v1.1.0-TODO-15c](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-15c).
  Touched `.cpp`/`.h` files must be
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
- [x] ~~TODO-17e~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-1`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-1 is ticked; from the TODO audit's pointer check)*
  (2026-09-23 bug-fix/feature split, user decision): **Reusable-bootstrap-
  worker support for `InferencePropZeroOneInflatedBetaRegr`** —
  `../finished_features/v1_0_5/reusable_bootstrap.md → TODO-1..6`. A fix to already-shipped
  functionality, not new v1.1.0 capability — moved with the rest of this
  release's audit-found/correctness items to the new patch release so it
  isn't gated on v1.1.0's Phase 0 decisions.
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
  `../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md → TODO-1..4` — replace the unbounded
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
- [x] ~~TODO-17o~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-2`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-2 is ticked; from the TODO audit's pointer check)*
  (2026-09-23 bug-fix/feature split, user decision): **Randomization CI
  affine-shift reuse** — `randomization_ci_affine_shift_reuse.md →
  TODO-1..7` (plus a decision-gated TODO-8). Revives a dead fast path
  (`cached_values$t0s_rand` never assigned) so a randomization CI for a
  linear statistic costs one null distribution instead of ~20–35. A
  performance/correctness fix to already-shipped v1.0.0 machinery, not new
  v1.1.0 capability. **Interaction note (2026-09-04; jump formula
  corrected 2026-09-05 per TODO-17x §B, itself now also in
  `release_v1_0_5.md`):** once this lands, a tier-1 class's `p(δ)` is an
  exact step function of δ, so TODO-17w (Brent, below) does not apply to
  it and Robbins–Monro (moved to `release_v1_2_0.md → TODO-21`) is moot on
  it.
- [x] ~~TODO-17p~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-3`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-3 is ticked; from the TODO audit's pointer check)*
  (same split): **Wire the unused OLS randomization-distribution kernel;
  triage dead kernels** — `ols_randomization_distr_cpp_wiring.md →
  TODO-1..6`. Wires a complete, exported, never-called C++ kernel
  (`compute_ols_distr_parallel_cpp`) so `InferenceContinOLS` gets a fast
  randomization distribution instead of falling through to the R-level
  reused-worker loop; also triages eight other dead kernel exports.
  Multiplicative with the moved TODO-17o.
- [x] ~~TODO-17q~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-4`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-4 is ticked; from the TODO audit's pointer check)*
  (same split): **Guard the unguarded information-matrix inverses** —
  `../bug_fix_plans/v1_0_5/guard_unguarded_information_inverse.md → TODO-1..5`. Correctness, not
  performance: five kernels invert a free-parameter information block with
  a bare `.inverse()` and no invertibility check, unlike their siblings —
  a near-singular fit today yields a finite, wildly wrong SE with no
  warning.
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
- [x] TODO-17t: **Algorithm choice audit** (survey; no code) (added *(ticked by the TODO audit 2026-11-17: R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md:33; R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md:47; R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md:724; R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md:462;...)*
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
  - See also (research triage, 2026-11-19): Chandrupatla / ITP / modAB root-finders instead of textbook Brent for pval_invert_ci_cpp (`likelihood-ci-inversion#43925959437.1`).
  - See also (research triage, 2026-11-19): Log-binomial gradient CI is bisection, not Brent: fix inventory row, add to Brent plan (`likelihood-ci-inversion#43925959437.2`).
- [x] ~~TODO-17x~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-5`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-5 is ticked; from the TODO audit's pointer check)*
  (2026-09-23 bug-fix/feature split, user decision): **Randomization CI
  construction audit** — `randomization_ci_construction_audit.md →
  TODO-1..4`. §A found and fixed a real bug (six log-hazard-ratio Cox-
  family classes' randomization CI reported on the wrong scale, now
  refused with an explanation); §B closed a misreading with no code
  change. Both findings are about already-shipped v1.0.0 randomization-CI
  machinery, not new v1.1.0 capability.
- [ ] TODO-17y: **`ModelSelection` Phase A + the selection-inclusive
  randomization test** (moved from `release_v2_0_0.md → TODO-6h` on
  2026-09-05, user decision; **widened 2026-09-06, user question, to
  cover every design family**): `model_selection_framework.md →
  TODO-1..8` (Phase A parts; TODO-9 stays a narrower, response-type-only
  remainder). **Why it can move:** the selection-inclusive randomization
  test — wrap the whole choose-then-fit pipeline as the randomization
  statistic, redraw `w` from the design, re-run per replicate; exact
  under the sharp null for any selection rule — needs no `Design`-level
  fold/split substrate at all. It is a client of `InferenceRandCustom`
  (`inference_rand_custom.R`; replaced the prior `set_custom_
  randomization_statistic_function()` hook in 2026-09-13's
  `fix_custom_randomization_statistic.md`, `finished_features/`) plus the
  registry, and every design's redraw-of-`w` mechanism for the
  per-replicate re-run already exists and is design-agnostic. ~~Under
  fully treatment-blinded
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
  ordinal) are left to TODO-9 (its release placement: owner decision
  pending, [DECISION-v2.0.0-TODO-6h](PENDING_DECISIONS.md#DECISION-v2.0.0-TODO-6h)).
  **Additive:** a new workflow object beside `InferenceSuite`; no default
  of any existing class changes. Consumes TODO-17z's check results (now `release_v1_3_0.md → TODO-5..6`)
  as assumption gates once both exist; with 17z in v1.2.0 the optional gate
  waits for that release (the gate is optional for the pilot;
  the assumption-light fallback class is mandatory regardless).
  Externally: this is also the scoped deliverable of a funding proposal,
  re-scoped 2026-09-06 to this widened Phase A and carrying no blinding
  claims.
- [ ] ~~TODO-17z~~ **→ moved 2026-10-20 to `release_v1_3_0.md → TODO-5..6`** (user decision, lighten-1.1.0 pass 2): `ModelDiagnostics` — declaration contract + pilot batteries.
- [ ] TODO-18: **Consolidate duplicated parallelization primitives**
  (added 2026-09-07, user decision): `consolidate_parallelization_code.md
  → TODO-3..4`; its TODO-1 and TODO-2 shipped in v1.0.5 (see below). Maintenance, not a
  feature — no output/behavior change.
  `Inference$par_lapply` is already a shared chunked-map parallel helper
  reused by ~10 bootstrap/randomization classes, backed by shared
  construction/lifecycle helpers in `globals.R`; `SimulationFramework$run()`
  and `InferenceSuite$run_all_inference()` hand-roll their own backend
  selection instead, for real documented reasons (a stateful
  copy-on-write pool with rolling dispatch, and a zero-blast-radius
  `mcparallel`/PID-kill dispatcher respectively — see
  `parallel_fork_cluster_test_safety.md`'s TODO-5). This item does **not**
  unify those three scheduler shapes; it extracts three sub-pieces that
  duplicate across them and have already drifted: worker single-threading
  env-var setup (defined once for `clusterCall()`, hand-rederived once for
  `mcparallel` children), and, until v1.0.5, the mirai
  poll/liveness-check/stop-on-death loop and two inconsistent
  `ensure_mirai_daemons` implementations.
  Independent of every other 1.1.0 item; no dependency on the decision
  batch. It rebases onto `release_v1_0_5.md → TODO-57` (Bayesian bootstrap
  performance), which ships first. The two meet only where `par_lapply`'s
  mirai branch calls `ensure_mirai_daemons`.

  **Scope reduced 2026-11-03** (owner request, `release_v1_0_5.md →
  TODO-182`): the 2026-10-07 conditional split no longer applies, because
  plan TODO-1 was pulled into v1.0.5 for a bug fix, not because of TODO-57.
  One `ensure_mirai_daemons()` now lives in `globals.R`. TODO-182 also removed
  the private `.settle_mirai_tasks` and `.mirai_daemons_alive`, and moved all
  three polling sites onto `poll_mirai_tasks()` (plan TODO-2). Left for this
  item: plan TODO-3 (worker single-threading setup) and TODO-4.
  `ensure_mirai_daemons()` still inlines the worker env-var list, so count that
  site too.
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
  `../finished_features/v1_0_0/inference_suite_plan.md`, which documented the
  original per-class design intent this drifted from). Fix: one
  highest-priority row per `(class, estimand)` feeds `combined_evidence`;
  `results_table` display is unaffected.
- [x] ~~TODO-22~~ **→ moved 2026-09-23 to `release_v1_0_5.md → TODO-6`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-6 is ticked; from the TODO audit's pointer check)*
  (2026-09-23 bug-fix/feature split, user decision):
  **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` optimizer
  stability** — `../bug_fix_plans/v1_0_5/clayton_loggamma_frailty_optimizer_stability.md →
  TODO-1..4`. A ~200× bimodal slowdown found via a comprehensive-test-
  harness timing investigation, traced to an unbounded C++ optimizer
  parameter plus a stale-gradient mismatch. A performance/correctness fix
  to an already-shipped class, not new v1.1.0 capability.
- [x] ~~TODO-39~~ **→ moved 2026-10-07 to `release_v1_0_5.md → TODO-57`** *(pointer ticked 2026-11-19: its target v1.0.5-TODO-57 is ticked; from the TODO audit's pointer check)*
  (user decision, the same day it was added): **Bayesian bootstrap
  performance: parallel scaling and native weighted refits** —
  `../bug_fix_plans/v1_0_5/bayesian_bootstrap_performance.md → TODO-1..9`. It fixes
  already-shipped resampling dispatch that misfires (a serial blocklist with
  no recorded reason, per-job shipping of every draw, and a gate that never
  picks serial), plus R-side Cox, Weibull and OLS refits. That is a
  v1.0.5-type fix under the 2026-09-23 split rule. TODO-18 above rebases
  onto it. Their only contact point is `ensure_mirai_daemons`, already unified
  in v1.0.5 (`release_v1_0_5.md → TODO-182`).
- [ ] TODO-16: **Release mechanics**: see `release.md` for the full generic
  checklist (win-builder/mac-builder, check profile, submission artifacts,
  CHANGELOG, version bump, tagging/pushing/submitting go-ahead, post-
  acceptance plan moves) — run it on the 1.1.0 candidate; `edi_kernels`
  1.1.0 wheel ships from the same commit family, per `release.md`'s
  Python-coordination section.

- **`TODO-23`** (added 2026-09-16, user decision; *(maintenance)*, no
  user-visible effect): **`lintr` policy** — `implement_a_lintr.md →
  TODO-1..4`. EDI has no `.lintr` and its house style (`=` assignment,
  tab indentation — measured 26,306 `=` vs. 605 `<-`, 71,133 tab- vs.
  5,622 space-indented lines in `R/EDI/R`) is the inverse of lintr's
  defaults, so the plan is: write a `.lintr` that describes the code as
  written (zero style findings on the current tree, every *correctness*
  linter on), triage the correctness findings, take one explicit decision
  on the `<-`/space minority (recommended: freeze via per-file exclusions,
  migrate when touched), then gate — content-gated in the pre-push hook on
  changed `R/EDI/R/*.R`, plus a path-filtered CI step with inline PR
  annotations. Depends on nothing; can run any time in the release.
- **`TODO-24`** (added 2026-09-16, user decision; *(maintenance)*):
  **Spell-check the documentation** — `spellcheck.md → TODO-1..3`.
  `spelling::spell_check_package()` + a bootstrapped `inst/WORDLIST` for
  the statistical vocabulary, `Language: en-US` in `DESCRIPTION`, and
  `spelling::spell_check_test()` in `tests/spelling.R` so new typos fail
  `R CMD check` in our matrix (skipped on CRAN). Hook integration is
  content-gated on the same roxygen-edit trigger `fast_roxygenize` already
  uses, plus vignette/`NEWS.md` changes. One-time triage cost, then ~zero.
  Depends on nothing.
- **`TODO-25`, `TODO-30..38`** — **moved 2026-09-23 to `release_v1_0_5.md
  → TODO-7..16`** (bug-fix/feature split, user decision): every
  audit-found correctness bug from the `comprehensive_tests` CSV audit
  waves of 2026-09-17 through 2026-09-23 — `KKQuantileRegrOneLik`
  randomization CI (`TODO-25` → v1.0.5 `TODO-7`), stereotype-logit
  multimodal likelihood (`TODO-30` → `TODO-8`), stale worker-cache in
  reused-worker resampling (`TODO-31` → `TODO-9`), MC coverage-truth wrong
  covariate set (`TODO-32` → `TODO-10`), the Cox Bartlett-approx
  investigation (`TODO-33` → `TODO-11`, resolved: do not enable), the
  latent `cached_mod` reset gap (`TODO-34` → `TODO-12`),
  `InferencePropGCompMeanDiff` all-NA (`TODO-35` → `TODO-13`, fixed),
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` all-NA (`TODO-36` →
  `TODO-14`, fixed), `InferenceContinLin` parametric-bootstrap Type-I
  error (`TODO-37` → `TODO-15`), and ordinal cumulative-link
  parametric-bootstrap inference (`TODO-38` → `TODO-16`). None of these
  add new v1.1.0 capability or depend on this release's Phase 0 decisions
  — see `release_v1_0_5.md` for full detail on each.

- [ ] ~~TODO-40~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-24`** (user decision, lighten-1.1.0 pass 2): Closed-form randomization nulls: exact PMFs and exact conditional moments where they exist.

- [ ] ~~TODO-41~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-25`** (user decision, lighten-1.1.0 pass 2): Exact small-sample rank tests via the Streitberg–Röhmel shift algorithm.


- [ ] ~~TODO-42~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-26`** (user decision, lighten-1.1.0 pass 2): Sign the permutation set once at generation; never re-hash or re-copy it per call.

- [ ] ~~TODO-43~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-27`** (user decision, lighten-1.1.0 pass 2): Mean-difference randomization row at parity with `coin`.

- [ ] ~~TODO-44~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-28`** (user decision, lighten-1.1.0 pass 2): Bootstrap CI rows at parity with `boot`.

- [ ] ~~TODO-45~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-29`** (user decision, lighten-1.1.0 pass 2): Zhang exact CI at parity with `fisher.test`.

- [ ] ~~TODO-46~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-30`** (user decision, lighten-1.1.0 pass 2): R6 construction and the per-instance byte-compilation tax.

- [ ] TODO-47 (added 2026-10-09, user decision): **Covariate coefficient
  table on the supporting likelihood classes** —
  `covariate_coefficient_table.md → TODO-1..9`.

  Today every public method reports only on `w`. `get_summary()` would print
  a covariate table, but the `StandardModelCacheSource` `shared()` path caches
  only the scalar treatment variance (`ssq_b_2`/`ssq_b_j`), so it dumps the
  raw fit list instead. A 2026-10-09 sweep of all 102 exported classes sorts
  the ~45 that have a covariate model into tiers. Tier 0 (7 classes) already
  builds the table. Tier 1 (17) has a full vcov in the fit object. Tier 2
  (~20) needs a vcov formed from information, `XtX`, or the class's own
  sandwich. Tier 3 (~15) is include/exclude per class. Excluded:
  unadjusted/nonparametric procedures, g-computation, all `*IVWC`. Gate: the
  table's treatment row reproduces the class's own SE and CI for every
  flagged class; registry-wide wiring test in pre-push; parity vs
  `glm`/`glm.nb`/`betareg`/`coxph`/`survreg`/`polr`/`sandwich`/`pscl`/`lme4`;
  existing results bit-for-bit unchanged. **The table is a separate path**:
  no edits to `generate_mod()`/`shared()`/treatment-path kernels (any needed
  C++ is a new kernel function). It has its own cache slot and is enforced by
  a call-graph separation test, a builder call counter (0 across
  estimate/CI/p-value/resampling), a kernel signature freeze, and a manual
  hot-path timing check against the pre-feature baseline.

- [ ] TODO-48 (added 2026-10-11, user decision): **Cross-platform
  reproducibility guarantee** — `cross_platform_reproducibility.md →
  TODO-1..7`. Every TODO requires its listed tests before it can be ticked.
  - (1) **Guarantee and record:** state the five-level guarantee (D3) in the
    reproducibility vignette, and attach a reproducibility record (seed,
    `RNGkind`, version, threads, workers, build flag) to every result. This
    shares the slot with `algorithm_choice_audit.md → TODO-38`.
  - (2) **Thread- and worker-count invariance everywhere:** use
    `seed_for_index` for every parallel stream; registry-driven invariance
    tests at 1/2/4 cores on both the fork and `mirai` backends; a pre-push
    ban on `std::shuffle`, `<random>`, `rand()` and per-thread seeding,
    plus floating-point `parallel for` reductions, atomics and critical
    sections; `identical()` same-binary determinism tests (D3).
  - (3) **p-value tie tolerance:** verify first, then fix, gated on
    exact-enumeration fixtures.
  - (4) **CI enforcement:** golden integer digests; RNG-only draws must
    match exactly on every platform leg, optimizer-chosen allocations
    exactly except at reported near-ties; floats within tolerance; a
    meta-test that every registry class has a fixture.
  - (5) **Release-equivalence fixtures (D2):** last-release golden values
    checked with the numerical-equivalence tiers.
  - (6) **Near-ties in optimizer-chosen allocations (D3):** measure first;
    tie-tolerant comparisons only if near-ties are common (a one-time
    documented draw change).
  - (7) **`draw_version` (D4):** decision-gated; reproduces earlier
    releases' draws, as R's `RNGversion()` does.
  - **Depends on:** `release_v1_0_5.md → TODO-91, -93, -95`.
  - Decided 2026-10-14 (owner): D1 portable by default, `EDI_PORTABLE=0` opt-in; see [DECISION-v1.1.0-TODO-48](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-48). Implemented in the source tree; see the plan and NEWS.

- [ ] ~~TODO-49~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-31`** (user decision, lighten-1.1.0 pass 2): Batched C++ loop for the custom randomization statistic.

- [ ] TODO-50 (added 2026-10-15, user decision): **Algorithm audit: wins on
  both speed and accuracy, no new options** — `algorithm_choice_audit.md →
  TODO-14, -15, -16, -17, -22, -24, -28`, and the φ half of `-25`. Every item
  replaces an algorithm with one that is faster and at least as accurate,
  and adds no user-facing argument ("auto" in the audit's labelling pass).
  - **TODO-14:** analytic score / Hessian / Louis information instead of
    finite differences (log/identity-binomial, ordinal-GLMM and CLMM engine,
    Poisson marginal-estimand delta method, ordinal g-comp gradient).
  - **TODO-15:** JT exact null by polynomial DP. `release_v1_0_5.md →
    TODO-90` already added the size guard; the DP returns the exact p-value
    where the guard now errors.
  - **TODO-16:** closed-form Gaussian score / gradient / LR CIs, and the
    exact F(1, n−p) LR null as a `type` (the F null changes the p-value, so
    it is opt-in).
  - **TODO-17:** CMH design variance in closed form for complete, Bernoulli
    and blocked designs (Monte Carlo kept for sequential designs).
  - **TODO-22:** accuracy fixes at the same speed: `pnorm_fast` /
    `fast_log_pnorm` tail branch, shifted one-pass variances, stable
    `fast_dnbinom_mu`, exact `qnorm` in Wilson/Newcombe.
  - **TODO-24:** feasible / consistent starting values and glm2-style
    step-halving.
  - **TODO-28:** EMICM for the Turnbull NPMLE: `icfit(initfit =
    "initEMICM")` first, then `icenReg::ic_np` (its `weights=` unblocks the
    interval-censored Bayesian bootstrap).
  - **TODO-25, φ half only:** 1-D Brent on KK21's dispersion profile
    likelihood instead of the 19-point grid. The score-test stepwise half
    is `release_v1_2_0.md → TODO-23`.
  - **Gate:** the existing tests plus an equivalence test per item, using
    the tiers of `../new_feature_plans/v1_1_0/cross_platform_reproducibility.md →
    Release-to-release equivalence`: exact at n ≤ 12 against brute force for
    the JT DP; the iterative-solver tier for the derivative, start and NPMLE
    changes. Items that move results beyond their tier (the tail fix, the φ
    grid, Monte Carlo CMH variance) are documented default changes (see
    Standing constraints).
  - See also (research triage, 2026-11-19): Analytic score and Hessian for log/identity-binomial instead of finite differences (`constrained-binomial-mle#43925959437.2`).
  - See also (research triage, 2026-11-19): Tail-only JT polynomial DP with reachable-range pruning (`exact-rank-null-distribution#43925959437.1`).
  - See also (research triage, 2026-11-19): icenReg::ic_np (C++ EMICM, weights=) instead of interval::icfit EM for Turnbull stats (`interval-censored-npmle#43925959437.2`).
  - See also (research triage, 2026-11-19): erfcx-based log Phi / Phi / Mills ratio for the negative tail (`normal-cdf-quantile#43925959437.1`).

- [ ] ~~TODO-51~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-32`** (user decision, lighten-1.1.0 pass 2): InferenceSuite worker pool.

- [ ] TODO-52 (added 2026-10-19, user decision): **Algorithm-audit leftovers**
  — `algorithm_choice_audit.md → TODO-41, -7` (and TODO-39, now `TODO-61`
  below), the audit items that had no release slot.
  - **TODO-39:** moved 2026-10-22 to its own TODO, **v1.1.0 TODO-61** below
    (Cox `ties`: Efron default, `ties = "breslow"` exposed).
  - **TODO-41:** audit the exposed implementation toggles (`use_rcpp`,
    `smart_cold_start_default`, and any other): every reachable path must fit
    the same model as the default, enforced by one parity test per toggle.
    Document them as developer options.
  - **TODO-7:** re-run the audit's *method* (not its conclusions) as the
    release-close pass, after the v1.1.0 kernels land, to refresh the summary
    table and the exposure column (audit TODO-37). Recurs per release. Also
    ships the monthly drift-check workflow (`algorithm-audit-drift.yml`, 21st
    of each month) and its runbook; see the amended audit TODO-7. The files are
    drafted (2026-10-22); remaining here are the first manual run and triage.
  - **Gate:** parity tests for TODO-41, and the audit re-run plus the first
    drift-workflow run for TODO-7. (TODO-39's gate moved to TODO-61.)

- [ ] TODO-61 (added 2026-10-19 as a bullet of TODO-52, user decision; split into its own TODO 2026-10-22; audit `algorithm_choice_audit.md → TODO-39`, row L): **Cox `ties`: Efron becomes the default, `ties = "breslow"` exposed**
  - Decided 2026-10-19 (owner): Efron default, `ties = "breslow"` available; see [DECISION-v1.1.0-TODO-61](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-61).
  - Not yet implemented: today the kernel is Breslow-only and the R fallbacks are pinned to `ties = "breslow"` (`release_v1_0_5.md → TODO-69`, done, which is the prerequisite).
  - **Scope:**
    1. Efron in `fast_coxph_regression.cpp`: log-likelihood, gradient, Hessian, the neg-ll-only path and the robust sandwich, all on the same form.
    2. A `ties` argument across the Cox family (`"efron"` default, `"breslow"`).
    3. The two R fallbacks and the oracle references follow `ties`.
    4. The chosen method is recorded through `TODO-48`'s algorithm provenance.
  - **Documented default change:** every Cox estimate on tied data moves. `package_tests` CSVs, parity tests and the Breslow reference oracles are regenerated, and NEWS states it. Open: confirm there is no deprecation period for the changed default.
  - **Gate:** regenerated Cox tests; a tied-data test per `ties` value against `coxph(ties = ...)`; untied data identical under both values.

- [ ] ~~TODO-53~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-33`** (user decision, lighten-1.1.0 pass 2): Amortize across runs.

- [ ] ~~TODO-54~~ **→ moved 2026-10-20 to `release_v1_2_0.md → TODO-34`** (user decision, lighten-1.1.0 pass 2): Anytime results.

- [ ] TODO-55 (added 2026-10-22, maintainer decision; new capability and
  **default behavior change** for v1.1.0, not a bug-fix-only item):
  **Cluster-robust (CR2) variance for the remaining regression classes on
  cluster designs.**
  - Background: `release_v1_0_5.md → TODO-103` gave OLS and Lin a CR2 SE on
    `is_a_cluster_capable()` designs and added an interim warning
    (`edi_cluster_independence_warning`) for every other asymptotic class and for
    all likelihood-based / parametric-bootstrap procedures. This TODO removes
    the warning class by class as each gets a real clustered variance.
    **Depends on v1.0.5 TODO-103** (OLS/Lin CR2, `cluster_robust_cr2_variance()`
    and `design_cluster_ids_for_inference()` in `helper_robust_sandwich.R`, and
    the warning hook).
  - Scope, in order:
    1. GLMs: logistic, Poisson, negative binomial (and quasi/robust Poisson),
       reusing and generalizing `helper_robust_sandwich.R` (clustered score
       sandwich with a CR2-style leverage adjustment).
    2. Cox: clustered score-residual sandwich (see the existing
       `test-cox-cluster-constrained-sandwich-reference.R` kernels).
    3. Ordinal and mixed/other classes.
  - Satterthwaite df (G-1 df is the OLS/Lin interim choice); decide and
    document per class.
  - LR / score / gradient / Bartlett tests and the parametric bootstrap have no
    simple clustered version: document them as not cluster-aware and keep the
    interim warning for those paths (the "likelihood" family), pointing to
    randomization, cluster bootstrap and `compute_jackknife_wald_*(unit = "cluster")`.
  - **Default change:** Wald SE, p and CI move (wider) on cluster designs, so
    this needs validation and a NEWS entry, and regenerated CSVs. Validation
    target: `cluster_trial.csv` (20 schools, `~pretest`): Lin SE 0.605
    pre-fix vs cluster-jackknife 1.627; CR1 1.53, clubSandwich CR2 1.57
    (Satterthwaite df 17.6), lmer 1.61. Add a coverage check (cluster-correlated
    DGP) per class before the warning is dropped for it.
  - Gate: per-class reference test against an independent CR2 implementation
    (1e-8, as for OLS/Lin), warning-removal test, and a documented exception
    under the standing default-change gate below.

- [ ] TODO-56 (added 2026-10-22, maintainer decision; new capability and
  output-format standardization, not a bug fix): **Full per-coefficient
  `get_summary()` tables for every class, with a stable format.**
  - Background: v1.0.5 TODO-114 moved `get_summary()` to the `Inference` base
    class and made it always print and return a table. It builds a full
    per-coefficient table only when named coefficients and a vcov exist and the
    `treatment` coefficient is identifiable by name (helper
    `edi_build_summary_table()` in `inference_all_abstract.R`); every other class
    falls back to a one-row `treatment` table. The fast-C++ classes hit the
    fallback because their coefficient vector `b` is unnamed, and KK OLS because
    its columns carry generated names (`x1..x4`).
  - Scope:
    1. Pass the design matrix's column names through the fast-C++ paths so `b`
       and the vcov carry names, and add the coefficient/vcov/df plumbing each
       class needs to produce a full table (intercept, treatment, covariates).
       Start with the OLS, logistic, Poisson, Cox, ordinal and KK families.
    2. Give every class the same layout: the `treatment` row always present
       and first; the same four columns (Estimate / Std. Error / statistic / p);
       statistic and p-value labels that follow the class's own distribution
       (z vs t) consistently.
    3. Record which variance produced the SE and p (Wald, cluster-robust CR2,
       randomization-only with no SE, none) as an attribute or header line, so
       two classes' tables are not compared as if they were the same inference.
       Consider returning a classed object with a `print` method rather than a
       bare matrix, so the layout can evolve without breaking callers.
    4. Extend the all-class sweep test beyond v1.0.5's coverage (which skips
       the GLMM, Bayes, Exact, GEE, Stan and IVWC families for cost) and
       assert the `treatment`-row contract on every applicable class.
  - Depends on v1.0.5 TODO-114. Interacts with TODO-55 (cluster-robust SEs
    change what the table's SE column means; the method attribute from step 3
    should report CR2 where applied).
  - Output-format change: document in `NEWS.md`. Callers that read the old
    one-row fallback or the printed text of `get_summary()` may be affected.

- [ ] TODO-57 (added 2026-10-22, maintainer decision; moved from v1.0.5
  TODO-3's Lin stretch item, which is closed there; performance feature, not
  a bug fix): **Native randomization-distribution kernel for
  `InferenceContinLin`.**
  - Background: v1.0.5 TODO-3 wired `InferenceContinOLS` to its native batch
    kernel (`compute_ols_distr_parallel_cpp`; measured 43x one-core and 54x
    four-core speedups). `InferenceContinLin` defines
    `compute_fast_randomization_distr()` (`inference_continuous_lin.R`), but it
    delegates to the R reused-worker loop, so Lin's randomization p-value and
    CI still pay the R/R6 per-replicate overhead.
  - Scope (from `../new_feature_plans/v1_0_5/ols_randomization_distr_cpp_wiring.md`
    → TODO-6): a `compute_lin_distr_parallel_cpp` that builds
    `[1, w_b, Xc, w_b·Xc]` per replicate. Only the interaction block
    `diag(w_b)·Xc` changes with `w_b`, so the `XᵀX` blocks can update in
    O(np²) per replicate. Alternatively fold it into
    `ols_distr_kernel_fwl.md`'s scope (v1.2.0) if that plan lands first.
  - Must match the reused-worker path: same hardened covariate block, the same
    `NA` for one-arm or rank-deficient permutations, and fast/worker parity
    tests on the OLS pattern (`test-parallel-distribution-kernel-contracts.R`).
  - Interacts with the affine-shift reuse (`randomization_ci_affine_shift_reuse.md`):
    Lin is tier 1 there, so the kernel speeds up the one full delta = 0
    distribution per CI, not every bisection step.

- [ ] TODO-58 (added 2026-10-22, user decision; from
  `../audits/further_optimizations.md`, "Under fork=FALSE"; performance,
  partly a documented default change): **Bartlett-corrected
  likelihood-ratio intervals: stop over-solving the inversion, and stop the
  harness computing each one twice.** After bootstrap-draw reuse, Bartlett
  CIs were ~26% of `comprehensive_tests.R` time on the six-class mix (36
  calls, 10–82 s each; the matching p-values take ~0.8 s).
  Findings (2026-10-22, installed EDI 1.0.3, `InferenceCountHurdleNegBin`,
  n = 80, unless noted):
  - **One CI runs ~46 Bartlett-factor simulations; the p-value runs 1.**
    `compute_lik_ratio_bartlett_approx_confidence_interval()` inverts the
    approximate-Bartlett p-value (`invert_test_pval_confidence_interval()`),
    and every new `delta` re-simulates `B = 99` null datasets
    (`get_bartlett_factor_approx()`). The root search keeps refining to ~7
    significant digits: −0.94 was evaluated ~9 times and 0.1025 ~10 times.
    That precision is far below the factor's own Monte Carlo error at
    `B = 99`. CI 3.58 s vs. p-value 0.16 s here; plain LR CI 0.02 s.
  - **The harness computes every Bartlett CI twice.** None of the four
    classes in the mix that support Bartlett (`InferenceCountHurdleNegBin`,
    `InferenceIncidLogBinomial`, `InferenceOrdinalContRatioRegr`,
    `InferencePropBetaRegr`) has an exact factor, so
    `compute_lik_ratio_bartlett_confidence_interval()` ("best available")
    dispatches to the approx CI. 18 / 18 harness pairs returned identical
    results with near-identical times. For a user it is free: called right
    after the approx CI on the same object it took 0.06 s with zero new
    simulations (the likelihood-test memo in
    `inference_ext_likelihood_test_memoization.R` hits). The harness pays
    twice because `safe_call()`'s in-process restore wipes that memo.
  Work:
  1. **EDI: a Monte-Carlo-aware stopping rule for the Bartlett-approx
     inversion.** Stop when the bracket is narrow relative to the
     interval's scale (for example 1e-3 × the Wald SE) instead of
     near-machine precision, and seed the search from the uncorrected LR
     endpoints (`invert_lik_ratio_ci_newton()`), where the corrected
     endpoint usually lies close by. Target ~10 factor simulations per CI
     (~4x faster). Endpoints move by less than the new tolerance, which is
     still a **default change** under the bit-for-bit standing constraint:
     document it in NEWS and in the two Bartlett CI method docs. Check the
     exact-factor and score/gradient inversions that share the helper keep
     their current tolerance unless measured to be over-solved too.
  2. **Harness: stop paying twice.** Options, in order of preference:
     (a) when `supports_bartlett_likelihood_ratio_exact()` is `FALSE`, keep
     the likelihood-test memo entries for `lik_ratio_bartlett_approx` across
     the approx-CI → best-available-CI pair only (the way
     `REUSED_RESAMPLING_CACHES` keeps bootstrap draws), then check the pair
     stays identical and no other likelihood rows change, since the memo
     also carries null-fit warm starts (the jackknife-reuse lesson of
     2026-10-22); (b) skip the best-available call for those classes and
     record it as a duplicate of the approx result. Expected: about half
     of the Bartlett time, ~13% of the suite.
  3. Re-measure the six-class mix (quiet machine) and update
     `further_optimizations.md`.

- [ ] TODO-59 (added 2026-10-22, user decision; from
  `../audits/further_optimizations.md`, "Under fork=FALSE"; test harness
  only, no package change): **Make the coverage-truth simulation cheap and
  stop billing it to `compute_estimate`.** After bootstrap-draw reuse,
  `compute_estimate` rows were ~9% of suite time, but only the first per
  object was slow (12–86 s under load; 3–17 s on a quiet machine) and the
  rest took 0.01–0.1 s. Findings (2026-10-22, instrumented scratch copy of
  the harness, quiet machine):
  - **The slow part is the coverage truth, not the estimate.** The first
    numeric result per (class, covariate set, `beta_T`) makes
    `handle_success()` call `get_coverage_truth()`
    (`is_truth_anomalous_result()`), inside the call's timed window. The
    estimate itself took 0.01–0.03 s. The three slow classes are exactly
    the three in the mix with a `COVERAGE_MC_SPEC` entry
    (`InferenceOrdinalContRatioRegr`, `InferencePropBetaRegr`,
    `InferenceSurvivalStratCoxPHRegr`, all `mc_n = 20000`); the other three
    use a closed form or have no truth.
  - **Almost all of that is an unused randomization test.**
    `compute_mc_coverage_truth_simframe()` runs `SimulationFramework` with
    `inference_types_and_params = list(rand_pval = list())`, i.e. a
    201-draw randomization test on the 20,000-row dataset, then reads only
    `res$estimate`. Switching to `asymp_pval` cut each truth from 3.1–16.9
    s to 0.2–0.9 s, and all 28 truths (3 classes × objects × `beta_T`) were
    bit-identical, since the estimate is computed before any inference
    type.
  Work:
  1. Request the cheapest type that each spec class supports:
     `asymp_pval` when `supports_asymp_inference()`, else `rand_pval` with a
     tiny `r` (the estimate does not depend on it). A class that supports
     neither must still return a truth, not zero rows (the framework drops
     rows with no valid inference type).
  2. Verify every `COVERAGE_MC_SPEC` class (not just these three) returns
     an identical truth before and after, at both `beta_T` values and with
     and without real covariates.
  3. ~~Take the truth computation out of the call's timed window~~ **→ moved
     2026-10-22 to `release_v1_0_5.md → TODO-127`** (user decision: it fixes
     wrong recorded durations, so it is a harness correctness fix, not an
     optimization).
  4. Optional: persist truths to disk keyed by `coverage_truth_cache_key()`.
     Since 2026-10-16 each truth is simulated under its own seed, so it is
     deterministic and could be reused across processes and runs. Needs
     invalidation on any change to the DGP, the spec table or EDI's
     estimator.

- [ ] TODO-60 (added 2026-10-22, filed from `release_v1_0_5.md → TODO-125`
  step 4, user decision there; cleanup, no behaviour change): **Remove the
  post-clone rebind helper now that lazy components survive `clone()`.**
  - Background: v1.0.5 TODO-125 made `install_lazy_inference_component()`
    close each installed method over the calling stub's own R6 enclosing
    environment, which R6's `clone()` remaps itself. The helper
    `edi_rebind_lazy_components_after_clone()` (`R/EDI/R/contracts_mixins.R`,
    roxygen + body about L2809-2944) was kept for v1.0.5 as belt and braces
    and is now a no-op (asserted by
    `package_tests/testthat_bulk/test-lazy-component-raw-clone-isolation.R`).
  - Work:
    1. Delete `edi_rebind_lazy_components_after_clone()` (plus any
       marker-reading code that only it uses; check first), and the `source_private` threading in
       `Inference$duplicate()` (`R/EDI/R/inference_all_abstract.R`, the call
       `edi_rebind_lazy_components_after_clone(i, source_private = private)`
       right after `self$clone()`); about 90 lines in all. Update the comments
       that point at the helper (`contracts_mixins.R` near the installer,
       `inference_class_registry.R` ~L1671).
    2. Tests: drop the helper's no-op assertion from
       `test-lazy-component-raw-clone-isolation.R` (keep its raw-`clone()`
       isolation checks) and delete or rewrite
       `package_tests/testthat_bulk/test-edi-rebind-lazy-components-after-clone-reference.R`.
    3. Regenerate Rd (removes `man/edi_rebind_lazy_components_after_clone.Rd`)
       and the `comprehensive_suite_{registry,coverage,internal_surfaces,baseline_audit}.csv`
       rows that list the helper.
    4. Run the clone, bootstrap and worker tests and the full bulk suite
       (the change touches every lazy class).

- [ ] TODO-62 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #31`;
  from v1.0.5 TODO-2): **Direct order-statistic inversion for randomization
  CIs.**
  - Background: v1.0.5 TODO-2 shipped the affine-shift reuse for
    randomization CIs (measured 1.05-2.14x, target restated, G6 #2). The
    owning plan's decision-gated optional item
    `../new_feature_plans/v1_0_5/randomization_ci_affine_shift_reuse.md → TODO-8`
    (direct order-statistic inversion: `p(δ)` is a step function whose jumps
    are the sorted shifted statistics, so the CI endpoint can be read off the
    order statistics instead of bisected) was deferred here. It buys
    exactness, not wall time.
  - Scope: implement plan TODO-8 for the tier-1 (affine) classes as an
    opt-in or a documented default change. It moves CI endpoints from the
    bisection tolerance to the exact jump. Keep the bisection path as the
    fallback for non-affine classes. Add tests against the bisection result
    (within its tolerance) and against brute-force `p(δ)` evaluation at the
    jump points.
  - Standing constraint: endpoints move, so it is a documented default change
    if made the default.
  - Pointer: `release_v1_0_5.md → TODO-2` (closed) and G6 #31.

- [ ] TODO-63 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #37`;
  moved from v1.0.5 TODO-57): **Bayesian-bootstrap performance remainder.**
  - Background: v1.0.5 TODO-57 shipped the R slices that were done (for
    example plan TODO-11's statistics cache and seed). Option (b) of G6 #37
    moved the rest here because it is large and needs a build plus
    owner-authorized fork/mirai runs.
  - Baseline: the 1.0.5 G2 run (2026-11-09, `release_v1_0_5.md → TODO-57`)
    fails all three acceptance checks. Some rows are slower on 3 cores, Cox
    reaches only 1.72x with the blocklist overridden, and EDI is slower than
    `bayesboot` on difference in means, median regression and Weibull AFT.
  - Scope (`../bug_fix_plans/v1_0_5/bayesian_bootstrap_performance.md`):
    - TODO-2: ship each worker only its slice of draws.
    - TODO-3: a cost-model gate that can say no.
    - TODO-5: audit the bootstrap serial blocklist.
    - TODO-6: native weighted Cox/Weibull refits (C++; a documented default
      change per v1.0.5's standing constraints).
    - TODO-7: thin the per-draw hot loop.
    - TODO-8: the batched-C++ stretch, decided after TODO-7's numbers.
    - TODO-9: re-run the comparison and update the claims.
    - The TODO-11 item 7 audit: jackknife / m-out-of-n / subsampling
      statistics-cache gap.
  - Not moved: plan TODO-1 (benchmark harness into `R/benchmark/`). G6 #37
    did not name it, so it stays with v1.0.5 TODO-57. If it is not done in
    1.0.5, it moves here as the "before" baseline for TODO-2..9.
  - Acceptance: plan TODO-9's before/after table on the TODO-1 harness rows,
    with fixed-seed draw parity, serialized payload bytes and fork/mirai
    validation runs.
  - Pointer: `release_v1_0_5.md → TODO-57`, G6 #37.
  - See also (research triage, 2026-11-19): survreg.fit on prebuilt matrices for weighted Weibull Bayesian-bootstrap draws (`weibull-aft-mle#43925959437.2`).

- [ ] TODO-64 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #7`;
  from v1.0.5 TODO-105): **`add_block_fixed_effects` opt-in for regression
  inference on blocking designs.**
  - Background: regression classes on `DesignFixedBlocking` add no block
    fixed effects. v1.0.5 TODO-105 documented this on 37 regression classes
    and on `DesignFixedBlocking`, and made few-level integer `strata_cols`
    categorical. With equal within-block allocation the cost is power, not
    validity (simulated: coverage 100%, SE about 2x the true SD). With
    unequal allocation and the per-block floor rule there is Simpson bias.
  - Scope: an `add_block_fixed_effects = FALSE` (default) option that appends
    dummies from `get_block_ids()`, deduplicated against X. It covers
    OLS/Lin/robust/quantile and the GLM families (37 classes; KK/IVWC/OneLik
    variants only if wanted). For Lin, also interact them. Add tests for
    power gain and unchanged default results. Update the "Blocking designs"
    section (`@inheritSection` from `InferenceContinOLS`).
  - Default stays FALSE (additive, no default change).
  - Pointer: `release_v1_0_5.md → TODO-105` (closed by the deferral).

- [ ] TODO-65 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #10`;
  from v1.0.5 TODO-119): **Randomization CI inversion on the estimand's own
  scale.**
  - Background: v1.0.5 TODO-119 found that `compute_rand_confidence_interval()`
    inverts a sharp-null shift on a transformed scale (logit, log-time,
    rank) and returned those bounds as bounds on the class's estimand. v1.0.5
    refuses instead: the five classes in
    `EDI_RAND_CI_SHIFT_SCALE_MISMATCH_CLASSES` error and lose the
    `randomization_ci` capability, and exact 0/1 proportions are refused on
    the logit shift.
  - Scope: for each refused class, define a sharp-null family on the
    estimand's own scale (for example an additive shift on the
    proportion/mean scale, or a multiplicative one for ratio estimands),
    invert it, and restore the capability. Use the class-level
    "estimand scale == shift scale" contract proposed in TODO-119. Also
    audit the other ordinal and quantile/ZOIB classes. Add a "CI contains the
    estimate, on the same scale" sweep test. Regenerate the `rand` CI rows
    and the capability matrix.
  - Pointer: `release_v1_0_5.md → TODO-119`, G6 #10.

- [ ] TODO-66 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #41`;
  from v1.0.5 TODO-119): **Return the Monte Carlo SE of randomization CI
  endpoints.**
  - Background: randomization CI endpoints carry Monte Carlo error from the
    `r` draws. Differences such as "CI narrower than the randomization p
    implies" are MC noise. v1.0.5 documents this in
    `compute_rand_confidence_interval()` (docs only, G6 #41).
  - Scope: return `r` and an endpoint MC-SE as attributes of the CI (for
    example from the binomial SE of the p-value at each endpoint divided by
    the local slope of `p(δ)`, or by batching the draws). Test it against
    the empirical endpoint SD over seeds. Additive: the CI values do not
    change.
  - Pointer: `release_v1_0_5.md → TODO-119`, G6 #41.

- [ ] TODO-67 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #40`
  (a)(b); from v1.0.5 TODO-116): **NegBin jackknife with convergence checks;
  tighter NB `eps_g` in hurdle/ZAP/`helper_glm_fit`.**
  - Background: v1.0.5 TODO-116 made the unsupported-procedure stubs
    classed-warning and cache-safe. It passes `eps_g = 1e-10` for
    `InferenceCountNegBin` (matches `glm.nb` to ~1e-6), and patch 04 moves
    the native NegBin defaults (G6 #40 (c), G1). `InferenceCountNegBin`'s
    five jackknife methods are still documented stubs that return NA. All
    150 delete-one refits converged on the investigated data, giving a
    usable jackknife SE.
  - Scope:
    (a) Enable the NegBin jackknife with per-replicate convergence checks:
    a non-converged fold makes the result nonestimable with a classed
    reason, never a silent NA.
    (b) Tighten the NB `eps_g` used by the hurdle-NegBin, ZAP and
    `helper_glm_fit` NB fits the way NegBin was.
    Both are default changes: validate against `glm.nb` / `pscl` references
    and regenerate the affected rows.
  - Pointer: `release_v1_0_5.md → TODO-116`, G6 #40.

- [ ] TODO-68 (added 2026-10-22, owner decisions `release_v1_0_5.md → G6 #38,
  #39`; from v1.0.5 TODO-58 and TODO-62): **Speed acceptance for the
  restated bootstrap and Zhang targets.**
  - Background: v1.0.5 restated both speed targets as workload-specific and
    closes those TODOs on parity/correctness:
    - TODO-58: public bootstrap CI >= 1x vs `boot`. Measured on full-size
      diagnostics: OLS 0.137x, logistic 1.030x, Cox 0.392x; "no safe R-only
      optimization". TODO-58 closes on G3 parity.
    - TODO-62: Fisher/EDI >= 1 for the Zhang exact CI. Measured 0.149-0.208x
      in every run. TODO-62 closes on the #21 endpoint metric and the G2
      report.
  - Scope, only if a follow-up optimization is warranted:
    - Profile both paths on the G2 quiet host.
    - Decide per workload whether >= 1x is reachable (native refit loops
      overlap TODO-63's plan TODO-7; Zhang CI inversion cost).
    - Either optimize, or record the final workload-specific targets in the
      benchmark docs and close.
  - Pointer: `release_v1_0_5.md → TODO-58`, `→ TODO-62`, G6 #38/#39.

- [ ] TODO-69 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #19`;
  from v1.0.5 TODO-10): **Firth bias reduction for the KK-matched Cox
  classes, then lift the harness covariate cap.**
  - Background: the MC coverage truth for `InferenceSurvivalKKStratCoxPHOneLik`
    and `InferenceSurvivalKKLWACoxPHOneLik` on `~.` (24 covariates, ~74
    pairs) did not converge across constructions, which is consistent with
    severe small-pairs attenuation bias
    (`../bug_fix_plans/v1_0_5/mc_coverage_truth_covariate_mismatch.md`,
    "Recommendation"). v1.0.5 caps the harness covariates for these classes
    (test rows and MC truth alike; G4 runbook R7) instead.
  - Scope: once this release's Firth track lands for Cox / stratified Cox
    (TODO-4 step 4, `firth_penalties_report.md → TODO-2..5`; the Firth-Cox
    score is derived in that report's appendix), apply it to the two
    KK-matched classes. Then re-run the R7 convergence check without the cap
    and lift or keep the cap.
  - Pointer: `release_v1_0_5.md → TODO-10`, G6 #19.

- [ ] TODO-70 (added 2026-10-22, owner decision `release_v1_0_5.md → G6 #48`;
  from v1.0.5 TODO-126): **Native Clayton optimizer iteration limit /
  fallback start at large n.**
  - Background: v1.0.5 TODO-126's investigation (2026-10-22) found that, at
    n = 3000 with ~25 covariates scaled by 1/ncol, the native Clayton
    Weibull LBFGS hits its 2000-iteration cap on about 2/3 of starts
    (log-theta ~0.83, far from its bound). Most candidates then fall to
    three R BFGS fits (1.1-4.7 s each, all converge), about 6 s per
    randomization draw. This is a performance finding, not a correctness
    bug. The harness side is fixed in 1.0.5 by G6 #47 (cheap truth
    inference type).
  - Scope: raise `maxit` for the native Clayton fit at large n, and/or seed
    the R BFGS fallback with the capped native iterate instead of a cold
    start. Either changes estimates at the tolerance level. Validate against
    the current R-BFGS results (tolerance-equal) and time on a quiet host.
    Needs a build.
  - Pointer: `release_v1_0_5.md → TODO-126`, G6 #48; scripts and logs of
    the investigation were in `/tmp/claude-1000/todo126/` (scratch; may be
    gone).

- [ ] ~~TODO-71~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-12`** (owner approval of the v1.0.6 triage): Fractional-validity guard for bootstrap p-values with `na.rm`.

- [x] TODO-72 (added 2026-10-22, deferred from `release_v1_0_5.md → TODO-129`
  / G6 #50, coordinator default; owner may override):
  **Estimator-internal RNG in `InferenceSurvivalKKRankRegrIVWC`.**
  **Moved back to v1.0.5 TODO-129 on 2026-10-23, done** (owner override of
  G6 #50: every `aftsrr` call runs under a deterministic seed derived from the
  object seed and the fitted data, caller RNG restored; see
  `release_v1_0_5.md → TODO-129`, "Owner override 2026-10-23"). Nothing left
  here.
  - Background: this legacy IVWC class (never published; see the IVWC
    policy) computes its IVWC weights from `aftgee::aftsrr(se = "ISMB")`, a
    multiplier bootstrap that draws from the caller's global RNG inside the
    estimator. So `compute_estimate()` and every randomization /
    randomization-CI evaluation advance the caller's `.Random.seed`, and a
    seeded randomization CI differs by caller seed (2% at r = 7, TODO-129
    seed sweep). The resampling draws themselves are seeded correctly.
  - Scope: wrap the `aftsrr` call in the same save / deterministic
    `set.seed()` / restore pattern used by v1.0.5's fix for
    `robust_survreg_with_surv_object()`'s restart jitter (fixed constant, or
    the inference/design seed when set). This changes the class's seeded
    and unseeded estimates once (the ISMB variance draws change), so it is a
    documented default change. Alternatively drop the class's ISMB
    dependence (e.g. `se = "ZLMB"` or a deterministic sandwich) or retire
    the class with the other legacy IVWC classes. Test: `compute_estimate()`
    leaves `.Random.seed` untouched and is identical under different caller
    seeds.
  - Pointer: `release_v1_0_5.md → TODO-129` (seed sweep note), G6 #50.

- [ ] TODO-73 (added 2026-10-23, deferred from `release_v1_0_5.md → TODO-97`
  closing audit; plan `../new_feature_plans/v1_0_5/inference_component_dependency_cleanup.md
  → TODO-5`): **Retire the legacy ladder parents behind the component
  sources where possible.** *(maintenance; no output or behavior change)*
  - Background: v1.0.5 TODO-97 (plan TODO-3/4/6/7, done 2026-10-22) added the
    neutral `ResamplingCore` component and rewrote every component's
    `dependencies` in `EDI_COMPONENT_SPECS` to the measured call graph
    (acyclic; guarded by `test-inference-component-call-graph-acceptance-reference.R`).
    The retained legacy ladder is still a single `inherit` chain:
    `Inference` → `InferenceResamplingCore` → `InferenceRand` →
    `InferenceRandCI` → `InferenceNonParamBootstrap` → `InferenceRandBootstrap`
    → `InferenceRandBootstrapCI` → `InferenceBayesianBootstrap` →
    `InferenceJackknife` → `InferenceAsymp` → `InferenceMLEorKMSummaryTable` →
    `InferenceAsympLik` → `InferenceParamBootstrap` (plus
    `InferenceAbstractQuantileRandCI`, which inherits a KK pass-through
    generator). Each link now only reproduces packaging order, not a real
    dependency (e.g. `InferenceNonParamBootstrap` inherits `InferenceRandCI`
    although its component depends only on `ResamplingCore`). The owner's
    "do it now" instruction for 1.0.5 named plan TODO-3/4/6/7 only, and plan
    TODO-5 is phrased "where possible", so it was left out of 1.0.5.
  - Scope: for each ladder generator whose `inherit` exists only so its own
    code loads, re-parent it to its real dependency (or to `Inference` /
    `InferenceResamplingCore`) per the component graph. Keep every concrete
    class's effective component list and method-owner bindings exactly
    equal to the TODO-1 registry/method golden (the reviewed
    `inference_component_expect_reviewed_registry_baseline()` fixture in
    `R/package_tests/inference_component_call_graph_helpers.R`); a change to
    a ladder generator's own inherited method set is a reviewed delta, not a
    silent regeneration. Keep the retained-ladder guardrail
    (`testthat_bulk/test-inference-class-registry.R`, "retained legacy ladder
    generators are enumerated, real, and have no concrete descendants", and
    `EDI_INFERENCE_ABSTRACT_CLASS_NAMES`, which
    `tests/testthat/test-static-cleanup-guardrails.R` keys on) in sync. Check
    the DESCRIPTION Collate order still loads each file, regenerate the
    ladder Rd "Super classes" sections (G8-style roxygenize, twice: the
    first pass leaves new superclass links unlinked), and add a NEWS
    "Internal" line. R-only; no build needed beyond `load_all(compile =
    FALSE)` for tests.
  - Acceptance: registry/method golden unchanged (or only a reviewed delta
    on the abstract ladder generators themselves), call-graph acceptance and
    acyclicity tests pass, the component/registry/migration-baseline suites
    pass, and the retained-ladder guardrail passes. Generators that cannot
    be re-parented without changing a concrete class's bindings stay as
    they are, with the reason recorded here.
  - Pointer: `release_v1_0_5.md → TODO-97` (closing-audit note 2026-10-23);
    plan TODO-5.

- [ ] TODO-156 (added 2026-10-23, owner decision at G1 of v1.0.5):
  **DepCens kernel stalls at the atanh(rho) clamp.** After v1.0.5 patch 02,
  15 of 101 zero-covariate resamples (design seed 111,
  `test-depcens-clayton-kernel-numerics.R`) still end unconverged at
  `|atanh(rho)| = 3 + 1e-14` with `value = NaN`: LBFGSpp's strong-Wolfe line
  search throws at the clamp kink. Not a user-visible bug in v1.0.5 (the R
  retry ladder in `generate_mod()` rescues all of them), but the retries cost
  time in resampling loops.
  - Candidate fix: `R/package_metadata/bug_fix_plans/v1_0_5/cpp_patches_v105/deferred_v110/02b-depcens-clamp-boundary-refit.patch`
    (refit with atanh(rho) pinned at the clamp when LBFGS ends there
    unconverged; `git apply --check` clean on 2026-10-23). Known caveat: it
    refits at the clamp on the side LBFGS reached, which is not always the
    better side (resample 37: Newton finds atanh(rho) = -3.07, nll 57.97,
    vs 60.98 at +3). Fit both sides and keep the lower nll, or replace the
    hard clamp with a smooth reparameterization.
  - Acceptance: kernel failures <= 2/101 on the test fixture (tighten the
    test's `expect_lte(bad, 20L)` back to 2), nll at the returned fit no worse
    than the R-retry result on every resample, interior fits bit-identical.
  - Pointer: `release_v1_0_5.md → G1` (post-build verification, owner
    decision 2026-10-23).
- [ ] ~~TODO-160~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-3`** (owner approval of the v1.0.6 triage): Stereotype logit usability gate and silent covariate dropping.
- [ ] TODO-161 (added 2026-10-27, owner decision at v1.0.5 TODO-163): **Design-aware
  RMST variance.** `InferenceSurvivalRestrictedMeanDiff` keeps the independent-arms
  Greenwood-type SE (`get_restricted_mean_se_diff()`) in 1.0.x, documented as
  conservative on every design other than Bernoulli / BCRD / iBCRD. R4B measured
  SD(estimate)/RMS(Wald SE) of 0.72 FixedBinaryMatch, 0.74 FixedMatchingGreedy,
  0.80 KK21stepwise, 0.87 SPBR, 0.91 FixedBlocking (Bernoulli 0.97). Implement,
  using each subject's RMST influence value in place of the outcome:
  - Stratified randomization (SPBR, FixedBlocking): Shao, Yu & Zhong (Biometrika
    2010) and Bugni, Canay & Shaikh (JASA 2018) show the usual variance is
    conservative under strongly balancing designs, and they give the corrected
    form. It is roughly the within-stratum variance of the influence values plus
    a between-strata term weighted by how much balance the design enforces. For
    permuted blocks the overstated part drops out entirely. Ye & Shao (JRSS-B
    2020) do this for survival tests under covariate-adaptive randomization.
  - Matched pairs (FixedBinaryMatch, FixedMatchingGreedy): Bai, Romano & Shaikh
    (JASA 2022) give a variance estimator that compares adjacent pairs ("pairs of
    pairs"). Plugging in influence values instead of outcomes extends it to RMST.
  - KK21 (pairs plus reservoir): no off-the-shelf result known. The natural
    analogue of the Kapelner & Krieger combination: treat the matched pairs as
    above, the reservoir as two independent arms, and combine the two.
  - Citations were given from memory: verify each (volume, pages, DOI) before
    they go into roxygen `@references`.
  - Acceptance: SD/RMS(SE) within 0.95-1.05 and Wald coverage 0.94-0.96 on each
    design above in the R4B harness; Bernoulli/iBCRD results unchanged; remove the
    "conservative" paragraph from the class roxygen for the designs covered.
  - Pointer: `release_v1_0_5.md → TODO-163`.
- [ ] ~~TODO-162~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-4`** (owner approval of the v1.0.6 triage): Block jackknife on SPBR / FixedBlocking leaves out whole strata.

- [ ] TODO-163 (added 2026-10-31, owner decision at v1.0.5 G4-C R7 / survival SD 0.25
  regeneration): **`InferenceSurvivalKKStratCoxPHOneLik` on `~.`: small-sample
  attenuation, anti-conservative tests, and an unvalidated coverage truth.**
  - Evidence (`~/edi_regen/regen_survival_sd025_20261030T140038Z/`, beta 0.5,
    asymp CI): median per-row estimate -1.92 (diamonds) and -2.09 (abalone), but
    harness truth -2.62 / -2.59; coverage 0.29-0.85. At beta 0 (no truth needed):
    param-bootstrap p-value rejects 0.377, LR-bootstrap 0.164, Bartlett 0.158.
    KKLWACoxPH `~.` (0.85-0.94) and the KKStratCoxPH `~1` arm are fine.
  - The harness truth (`get_coverage_truth()`) matches pairs on the FULL X and caps
    only the Cox formula (as the per-row fits do). R7
    (`todo10_capped_truth_convergence.R`) capped X before matching, so it validated a
    different estimand (pte_example -1.59 vs harness -2.30). Before re-grading, fix
    R7 to match on the full X and rerun its convergence check.
  - Decided 2026-10-31 (owner): 1.0.5 keeps grading the `~.` arm, documented as a known limitation; see [DECISION-v1.1.0-TODO-163](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-163).
  - The arm-level exclusion
    `COVERAGE_TRUTH_UNAVAILABLE_REAL_COVARIATES` (`comprehensive_tests.R`) exists but
    is empty. Expect low-coverage audit findings for this arm until this TODO lands.
  - Scope: do it together with TODO-69 (Firth for the KK-matched Cox classes). Check
    whether Firth removes the attenuation and fixes the beta-0 type-I error; then
    remove the class from the list and regrade from
    `work/out/grid_kkcox_regrade_rows.csv`.
  - Pointer: `release_v1_0_5.md` → G4-C R7 notes (2026-10-29 to 31).

- [x] TODO-164 (added 2026-11-03, owner; found by the v1.0.5 TODO-183 allocation audit): **`DesignFixedRerandomization` used two base randomization laws at `prob_T != 0.5`.** Current state: DONE in source (uncommitted when ticked; it will ship with whichever release first includes the commit).
  - **Problem.** With no covariates, or with `prop_acceptable`, candidates were complete randomizations with a fixed `n_T = round(n * prob_T)`. The default rejection sampler (`generate_rerandomized_w_batch()`, plus the single-draw helper `generate_one_rerandomized_w()`) instead drew independent Bernoulli(`prob_T`) candidates, so the treated count varied. One design thus had a different reference distribution depending on `prop_acceptable` vs `obj_val_cutoff`; the audit's realized treated share was 0.355 at `prob_T = 0.3`. At `prob_T = 0.5` every path already used a fixed count.
  - **Fix** (`R/EDI/R/design_fixed_rerandomization.R`). Every path now draws complete randomizations with exactly `n_T = round(n * prob_T)` treated. `draw_ws_raw()` computes `n_T` once and errors clearly when it leaves an empty arm, where before the sampler ran until its draw budget was exhausted. The class docs and `@param prob_T` were updated.
  - **Default change.** Seeded draws change once, only for `prob_T != 0.5` with the rejection sampler. `prob_T = 0.5`, and the `prop_acceptable` and no-covariate paths, are unchanged.
  - **Verified** 2026-11-03 (`load_all(compile = FALSE)`). New tests in `test-rerandomization-objective-and-draw-paths-reference.R` (76 pass) cover exactly `n_T` treated on the cutoff, `prop_acceptable` and no-covariate paths, `generate_one_rerandomized_w()` and the realized assignment at n = 20 and 21, plus the empty-arm error. All 21 test files using `DesignFixedRerandomization` pass.
  - **Docs.** `man/DesignFixedRerandomization.Rd` regenerated with `R/fast_roxygenize.R` on 2026-11-03 (exit 0, no warnings).
  - **Not done when ticked.** `NEWS.md` entry, full test suite.

- [ ] ~~TODO-165~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-5`** (owner approval of the v1.0.6 triage): `InferenceIncidLogBinomial` full-data fit at exp(Xb) = 1.

- [ ] TODO-166 (added 2026-11-09, owner; follow-up of v1.0.5 TODO-189): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`: parametric-bootstrap-calibrated score p-value.**
  - Why: the asymptotic score test runs high at moderate n on correctly specified matched-pair data (n = 200: 0.063 vs Wald 0.049 / LR 0.045; n = 400: 0.060; n = 800: 0.069 vs Wald 0.065). The null fit's log-theta drops when the data show an effect, so the null information is small exactly when the score is large (v1.0.5 TODO-189 entry; scripts in `/tmp/claude-1000/t189/`). v1.0.5 documents it and recommends Wald / LR.
  - Fix: refer the score statistic to its parametric-bootstrap distribution under the null fit, reusing the class's `simulate_under_lik_null` (already used by its LR bootstrap).
  - Done when: score size within the binomial band of 0.05 at n = 200 on the TODO-189 DGP; runtime cost documented.

- [ ] ~~TODO-167~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-6`** (owner approval of the v1.0.6 triage): GLMM / CLMM multistart ignores `warm_start_params`.

- [ ] TODO-168 (added 2026-11-09, owner; opened with the accepted calibration rows it covers): **`InferenceOrdinalStereotypeLogitRegr`: score test oversized at small n with unequal allocation.**
  - Why: the v1.0.5 fast-tier re-run after TODO-175/176/178 and the `~1` non-estimable rule (2026-11-09, 1000 reps, installed EDI) gives `~.` score at n = 50, prob_T = 0.2 (about 10 treated) size 0.107 and coverage 0.905, with 982/1000 finite. Wald in the same cell is nominal (0.048); at n = 200 the score size is 0.062. The prob_T = 0.5 cell is also high (0.105). The likelihood is multimodal and the loadings are weakly identified near beta_T = 0, so the null information is unreliable at small n. Accepted rows (size 0.13, coverage 0.89) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` cite this TODO. v1.0.5 docs recommend Wald or LR at small n.
  - Investigate first: confirm it is a finite-sample property, not a null-refit bug (score size by n = 50/100/200/400; compare expected vs observed information at the null fit).
  - Fix: refer the score statistic to its parametric-bootstrap distribution under the null fit, reusing the class's `simulate_under_lik_null` (same approach as TODO-166).
  - Done when: score size within the binomial band of 0.05 at n = 50 for both prob_T values, and the TODO-168 accepted rows are pruned.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] ~~TODO-169~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-7`** (owner approval of the v1.0.6 triage): `InferenceIncidModifiedPoisson` `~1` NA at large n.

- [ ] TODO-170 (added 2026-11-09, owner; opened for accepted calibration rows; moved to `release_v1_0_6.md → TODO-8` 2026-11-10, moved back 2026-11-11, owner, after the re-run found no bug): **`InferenceOrdinalStereotypeLogitRegr`: gradient and LR tests oversized at n = 50.**
  - Why: 6 accepted rows (gradient and LR, n = 50, both prob_T). The 2026-11-09 local re-run (1000 reps) gives size 0.084-0.090 with yield >= 99%; n = 200 and n = 1000 are nominal (2026-11-11 re-run at n = 1000: all four `~.` tests size 0.051-0.060, coverage 0.940-0.949, yield 100%; the 8 n = 1000 rows were pruned). So this is a small-sample excess, not a large-n defect. Documented in the class's roxygen ("Small samples").
  - Also covers wald ~. n = 50 prob_T 0.5: 2026-11-09 local run size 0.077, coverage 0.923, p = 1.5e-4; it fails the local K = 32 cutoff but not the nightly's, so it has no accepted row; if the fast tier flags it, add one citing this TODO.
  - Investigate first: whether the excess comes from the null refit landing in a non-global mode (the multimodal likelihood) or from the information at the loading boundary; compare with the score test (TODO-168), which is worse (about 0.105).
  - Fix (candidates): a parametric-bootstrap-calibrated LR / gradient test reusing `simulate_under_lik_null` (same approach as TODO-168 and TODO-166), or a Bartlett correction for LR.
  - Done when: gradient and LR size within the binomial band of 0.05 at n = 50 for both prob_T values and the accepted rows (reason starting `v1.1 TODO-170`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or the owner rules the excess inherent and the rows stay with a reason saying why.
  - **Triage 2026-11-11:** `release_v1_0_6.md → TODO-13` first checks whether the null refit misses the global mode (multistart on the rejecting reps); a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-171 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceContinKKGLMM`: KK GLMM continuous: Wald oversized at n = 50.**
  - Why: accepted rows wald ~. n = 50 prob_T 0.5 (size 0.085, coverage 0.915); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run 40833827319. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: compare the Wald SE with sd(estimate) at n = 50; check whether the random-effect variance is underestimated (REML vs ML) or collapses to 0.
  - Fix (candidates): small-sample correction (REML variance, Kenward-Roger or Satterthwaite-type df, or t reference).
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-171`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-172 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceContinKKRobustRegrOneLik`: KK robust regression OneLik: Wald oversized at n = 50.**
  - Why: accepted rows wald ~. n = 50 prob_T 0.5 (size 0.09, coverage 0.91); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: SE vs sd(estimate) at n = 50; whether the sandwich / scale estimate is biased low at small n.
  - Fix (candidates): small-sample sandwich correction (HC2/HC3-type) or t reference.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-172`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-173 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceContinLin`: Lin (2013) estimator: Wald oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. n = 50 prob_T 0.2 (size 0.105, coverage 0.895); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run 42184383402. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: which HC variant is used; HC0/HC1 is known to be anti-conservative with about 10 treated and interacted covariates.
  - Fix (candidates): HC2 / HC3 default or a t reference with residual df.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-173`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` and `R/package_tests/calibration/calibration_study_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **2026-11-15:** the full calibration study fails the same cell in every campaign (size 0.17 / 0.17 / 0.192 on 1000 reps, campaigns 2026-11-09-8c32d060, 2026-11-12-a46ab113, 2026-11-15-e36c7710; level cap 0.10). Owner added accepted rows to `calibration_study_accepted.csv` at size 0.20 / coverage 0.80 so this known cell does not turn each campaign red.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-174 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceCountHurdlePoisson`: Hurdle Poisson: model-based likelihood tests anti-conservative when covariates are omitted.**
  - Why: 12 accepted rows: score / gradient / LR, ~1, n = 1000, prob_T 0.2 and 0.5 (size 0.085, coverage 0.915). Model misspecification, not small-sample: ~1 omits the DGP covariates, so the truncated-Poisson count part is overdispersed (0.064 at prob_T 0.5); the sandwich Wald and HurdleNegBin are calibrated; 2026-11-07 run 42366610368. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: confirm with a correctly specified ~. run at n = 1000 (should be nominal) and quantify overdispersion.
  - Fix (candidates): robust (sandwich-information) score / LR variants, or document only and keep the sandwich Wald as the default.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-174`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.
  - **2026-11-19:** v1.1.0-TODO-216 (ZeroInflatedPoisson `~1`, size 0.16-0.17 at every n) has the same cause and was ruled inherent; if robust score / LR variants are built here, build them for ZeroInflatedPoisson too.
  - **2026-11-16, calibration campaign 2026-11-15-e36c7710 (after wave 4, screen stage, 1000 reps per cell):**
    the same cause on far more cells. 54 tests flagged (q down to 7e-35), confirmation pending, on 6 designs:
    FixedBernoulli, FixediBCRD, SeqOneByOneKK14, SeqOneByOneKK21stepwise, SeqOneByOneSPBR and SeqOneByOneUrn.
    - Score, gradient and LR size, averaged over designs: `~1` 0.142-0.148 at n = 50, 0.151-0.153 at n = 200,
      0.099 at n = 1000. With covariates (`~.`) the same tests are nominal (0.038-0.053). That is the "Investigate
      first" check, now done.
    - Randomization p-values are nominal (0.044-0.051). HurdleNegBin `~1` is nominal (0.036-0.084) on the same cells.
    - Sandwich Wald `~1` is conservative at n = 1000 (0.015). That is new and worth a look.
    - The roxygen's "up to about 8.5%" figure understates it: the campaign DGP overdisperses the count part more
      than the fast tier does, so update the number, or word it as depending on how much the omitted covariates
      explain.
    - Not a null-fit bug: the 2026-11-07 check found the EDI score p matches an independent truncated-Poisson score
      test to 2e-5.
  - **2026-11-17, same campaign after wave 7:** 235 tests flagged across all 21 designs, all `~1` score,
    gradient or LR; every one has an accepted row citing this TODO. The excess does not shrink with n: `~1` LR size at
    n = 1000 is 0.15-0.185 on designs that don't balance covariates (Bernoulli, iBCRD, SPBR, Rerandomization,
    PocockSimon, Efron), 0.09-0.11 on covariate-balancing ones (Greedy, Optimal, KK14, Atkinson), and 0.05-0.085 on
    matched ones (KK21, BinaryMatch, PairSwitching). So the size tracks how much covariate imbalance is left
    unadjusted, which fits misspecification, not a finite-sample effect. Sandwich Wald `~1` ranges 0.005-0.069 at
    n = 1000.

- [ ] TODO-175 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidBinomialIdentityRiskDiff`: Binomial identity risk difference: Wald / LR oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. (size 0.135, coverage 0.865), wald ~1 (size 0.085), lik_ratio ~. coverage 0.88, n = 50 prob_T 0.2; unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: share of fits at the [0,1] boundary in the treated arm; Wald SE at a boundary fit; relation to v1.0.5 TODO-181 (KKT score) and the feasible-start null refit.
  - Fix (candidates): boundary-aware SE or a Newcombe / Miettinen-Nurminen-type interval for small arms.
  - Nightly-tier run 43207882653 (2026-11-12, `e4caff35`): the `~.` n = 50 prob_T 0.2 gradient, LR and score cells are now nominal (size 0.048-0.054, coverage 0.945-0.948, yield >= 99%), so their 3 coverage rows were pruned. Still accepted: Wald `~.` and `~1` at n = 50, prob_T 0.2.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-175`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

  - **2026-11-16:** the full calibration study (campaign 2026-11-15-e36c7710) fails the same cell on four designs (Bernoulli, Blocking, iBCRD, SeqOneByOneBernoulli at prob_T 0.2, n = 50, `~.`: size 0.141-0.159). Accepted rows at observed + 3 SE added to `R/package_tests/calibration/calibration_study_accepted.csv`; prune them too when this is done.
- [ ] TODO-176 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidGCompRiskDiff`: G-computation risk difference: Wald oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. (size 0.10) and ~1 (size 0.09), n = 50 prob_T 0.2; unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: delta-method SE vs sd(estimate); separation in the 10-subject arm.
  - Fix (candidates): small-sample variance (bias-reduced logistic fit or bootstrap SE).
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-176`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-177 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidKKCondLogitOneLik`: KK conditional logit OneLik: gradient test oversized at n = 50.**
  - Why: accepted rows gradient ~. n = 50 prob_T 0.5 (size 0.09, coverage 0.925); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: compare with score / Wald / LR in the same cell; few discordant pairs at n = 50.
  - Fix (candidates): exact conditional test for small discordant counts, or document.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-177`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

  - **2026-11-16:** the full calibration study (campaign 2026-11-15-e36c7710) shows a larger excess than the fast tier: gradient size 0.145-0.149 at n = 50 on BinaryMatch, KK21 and KK21stepwise (`~.`). Accepted rows at observed + 3 SE added to `R/package_tests/calibration/calibration_study_accepted.csv`; prune them too when this is done.
- [ ] TODO-178 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidLogBinomial`: Log-binomial: score / gradient / LR miscalibrated at prob_T = 0.2, n = 50.**
  - Why: accepted rows score ~. size 0.255, gradient ~. coverage 0.88, lik_ratio ~. coverage 0.895, n = 50 prob_T 0.2; unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run (before the v1.0.5 TODO-181 KKT boundary score). Re-run 2026-11-10 (installed build with the KKT score, 1000 reps, n = 50): score ~. size 0.106 / coverage 0.906 at prob_T 0.2 and 0.087 / 0.918 at prob_T 0.5 (still above nominal; size row tightened 0.255 -> 0.13); gradient and LR are now nominal (0.053-0.060), and their 3 coverage rows were pruned; `~1` score 0.071 at prob_T 0.2 (passes). What is left is the score test at n = 50. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: re-run on the build with the KKT score (v1.0.5 TODO-181); share of fits at exp(Xb) = 1; overlap with v1.0.5 TODO-179 (Wald) and v1.0.6 TODO-5 (boundary full fit; was v1.1 TODO-165). Since 2026-11-09 the Wald test is NA at boundary MLEs (v1.0.5 TODO-179; leftovers in TODO-189), and LR CIs there no longer fall back to Wald for lack of a feasible null start.
  - Fix (candidates): likely covered by v1.0.6 TODO-5 / v1.0.5 TODO-181; otherwise a boundary-aware reference distribution.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-178`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

  - **2026-11-16:** the full calibration study (campaign 2026-11-15-e36c7710) also fails it on Blocking and SeqOneByOneSPBR (score size 0.148-0.153, prob_T 0.2, n = 50). Accepted rows added to `R/package_tests/calibration/calibration_study_accepted.csv`. The n = 1000 excess is a separate item: `release_v1_0_6.md` TODO-29.
- [x] TODO-216 (added 2026-11-19, owner; opened for accepted calibration rows): **`InferenceCountZeroInflatedPoisson`: model-based likelihood tests anti-conservative when covariates are omitted (`~1`), at every n.**
  - Why: campaign 2026-11-15-e36c7710 (screening stage, 1000 replicates, waves 12-14): score / gradient / LR with `~1` have size and 1 - coverage 0.134-0.173 at n = 50, 200 and 1000, prob_T 0.2 and 0.5 (98 flags; at n = 200 and 1000 so far on FixedBernoulli, FixedRerandomization, SeqOneByOneEfron). Not shrinking with n, so not small-sample: the same pattern as TODO-174 (Hurdle Poisson). `~1` omits the DGP covariates, so the count part is overdispersed for a Poisson model and the model-based information is too large.
  - Investigate first: the `~.` cells at n = 1000 (should be nominal); the overdispersion of the count part under `~1`; whether ZeroInflatedNegBin `~1` is calibrated at n >= 200 (it absorbs the overdispersion, as HurdleNegBin does for TODO-174).
  - Fix (candidates): robust (sandwich-information) score / LR variants shared with TODO-174, or document it in the class roxygen and point to ZeroInflatedNegBin or the sandwich Wald.
  - Not covered here: the randomization flags of this class (9, size 0.075-0.185, mostly n = 50) wait for the confirmation stage.
  - Done when: the `~1` cells pass at nominal and the accepted rows (reason starting `v1.1.0-TODO-216`) in `R/package_tests/calibration/calibration_study_accepted.csv` are pruned; or the owner rules it inherent and the rows stay with a reason saying why.
  - **Investigated 2026-11-19: inherent misspecification, not a code bug.** Own simulation of the campaign DGP
    (`count_zip`, p = 5, `cal_study_seed("count", n, rep)` for reps 1-1000, so the same subjects as screening reps
    1-1000), DesignFixedBernoulli, null effect, 1000 reps per cell, source tree under `load_all(compile = FALSE)`.
    Script and outputs: `/tmp/claude-1000/-home-kapelner-workspace-EDI/36603969-ed9b-40ba-9f2e-044451c2e3b2/scratchpad/todo216/`
    (`sim.R`, `summarize.R`, `res_n*_p*.rds`). Rejection rates at alpha = 0.05:
  - Accepted rows completed 2026-11-21 (coordinator, owner request): wave 24 of campaign 2026-11-15-e36c7710 had 434 confirmed failing ZIP gradient / LR / score cells but only 98 rows; 336 rows added (168 size, 168 coverage), level = the worse of the screening and confirmation values + 3 SE. The reason text is this TODO's existing one; the owner ruling above (inherent, rows keep citing this TODO) covers them although the TODO is closed.

    | cell | ZIP `~1` score / LR / gradient | ZIP `~1` model-based Wald | ZIP `~1` class Wald (sandwich) | ZIP `~.` score / LR / gradient / Wald | ZINB `~1` Wald / score / LR / gradient |
    |---|---|---|---|---|---|
    | n = 1000, prob_T 0.5 | 0.169 / 0.169 / 0.169 | 0.169 | 0.049 | 0.046 / 0.046 / 0.046 / 0.051 | 0.052 / 0.054 / 0.052 / 0.051 |
    | n = 1000, prob_T 0.2 | 0.168 / 0.171 / 0.173 | 0.166 | 0.053 | 0.041 / 0.040 / 0.040 / 0.043 | 0.053 / 0.058 / 0.053 / 0.051 |
    | n = 200, prob_T 0.5 | 0.165 / 0.169 / 0.170 | 0.165 | 0.057 | 0.056 / 0.055 / 0.055 / 0.065 | 0.055 / 0.066 / 0.053 / 0.049 |
    | n = 200, prob_T 0.2 | 0.154 / 0.154 / 0.154 | 0.152 | 0.067 | 0.059 / 0.056 / 0.059 / 0.071 | 0.059 / 0.072 / 0.061 / 0.056 |
    | n = 50, prob_T 0.5 | 0.156 / 0.162 / 0.166 | 0.150 | 0.080 | 0.108 / 0.103 / 0.109 / 0.123 | 0.075 / 0.107 / 0.074 / 0.059 |

    - These match the campaign's DesignFixedBernoulli rows (e.g. n = 1000, prob_T 0.2: score/LR/gradient 0.168-0.173,
      Wald 0.053).
    - The Wald built from the model-based (inverse Fisher information) SE is oversized exactly like score / LR /
      gradient, so all four model-based tests agree. The class's own Wald is nominal only because it uses the
      sandwich SE (`zero_augmented_sandwich_se()`). At n = 1000, prob_T 0.5: sd(beta_hat_T) = 0.0715, mean
      model-based SE 0.0508, mean sandwich SE 0.0707. That is a variance ratio of 1.98, which predicts size
      2 * (1 - Phi(1.96 / sqrt(1.98))) = 0.164 against the 0.169 observed. With `~.` the three numbers agree
      (0.0501 / 0.0505 / 0.0501).
    - Overdispersion under `~1`: the omitted eta (variance 1) makes the count part Poisson-lognormal, with
      Var/mean = 2.18 instead of 1 (Monte Carlo, 2e6 draws; mean 2.72, so an NB theta of about 2.3). The structural-zero
      probability plogis(-1 + 0.5 x1) also varies and correlates 0.50 with the count mean. The median Pearson
      dispersion of the fitted ZIP `~1` is 1.37-1.39 at every n, and ZINB `~1` estimates theta at 2.19 (n = 1000),
      2.40 (n = 200) and 3.2 (n = 50).
    - ZINB `~1` is calibrated at n >= 200 (0.049-0.072; the highest is score at n = 200, prob_T 0.2) because the NB
      dispersion absorbs the heterogeneity. ZIP `~.` is nominal at n >= 200, and at n = 1000 is if anything slightly
      conservative (0.040-0.046).
    - Code checks: an independent R `optim` ZIP fit (count 1 + w, zi 1 + w, the class's `~1` layout; full fit and
      null fit with beta_T = 0) gives the same LR p as EDI in 100% of reps at n >= 200 (median |dp| 1e-10) and in
      99.6% at n = 50. The estimate matches to about 1e-6. The tested parameter is the count-part w coefficient
      (j = 2). So the null fit, the parameter tested and the LR statistic are right. Score and gradient track LR to
      the third decimal, so their information use is consistent; the excess comes from the model-based information
      itself being too large under misspecification.
    - The campaign's design spread (worse on designs that leave covariate imbalance, smaller on balancing or matched
      ones) and the sandwich Wald running conservative on balancing designs (Greedy 0.03) fit the same explanation,
      as for TODO-174.
    - Recommendation: the owner rules it inherent. Keep the accepted rows with that reason, and document in the
      class roxygen that score / LR / gradient assume the ZIP model is correctly specified: with omitted prognostic
      covariates, size is about 0.15-0.17 on this DGP at any n. Point users to the class's (sandwich) Wald,
      ZeroInflatedNegBin, or adjusting for the covariates. Robust score / LR variants (a sandwich-information score
      test, or a Rao-Scott-type LR adjustment by the variance ratio) are an option to share with TODO-174 if wanted.
      No code changed.
  - Decided 2026-11-19 (owner): inherent (model misspecification), done; see [DECISION-v1.1.0-TODO-216](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-216).
  - The accepted rows (reason starting `v1.1.0-TODO-216`) stay with that reason. Documented in the class roxygen and `man/InferenceCountZeroInflatedPoisson.Rd` ("Omitted covariates": prefer the sandwich Wald, adjust for covariates, or use ZeroInflatedNegBin), mirroring HurdlePoisson. Robust (sandwich-information) score / LR variants, optional, go with v1.1.0-TODO-174, which has the same cause.

- [x] TODO-217 (added 2026-11-19, owner; opened for accepted calibration rows): **`InferenceCountZeroInflatedNegBin`: Wald / score / LR / gradient oversized at n = 50.**
  - Why: campaign 2026-11-15-e36c7710 (screening stage, 1000 replicates, waves 12-14): 215 flags at n = 50 on all 19 designs that run it, prob_T 0.2 and 0.5, both formulas; size and 1 - coverage 0.134-0.230, worst for score with `~.` (0.18-0.23), then Wald `~.` (0.15-0.20). None at n = 200 or 1000 except one `~1` score cell at n = 1000 (0.080). Small-sample: a zero-inflation logit plus a NegBin dispersion is many parameters for 50 subjects, and the dispersion is weakly identified.
  - Investigate first: share of fits at the dispersion boundary (theta -> infinity) or with a degenerate zero-inflation part at n = 50; whether the score test uses the null information at a boundary dispersion.
  - Also open, not accepted here: its randomization test is flagged too (78 flags, size 0.075-0.109, at every n). A randomization test should hold its size whatever the model, so check how failed fits (NA statistics) are handled in the randomization distribution; wait for the confirmation stage first.
  - Fix (candidates): document a minimum n in the class roxygen and recommend the Wald with a bootstrap at small n; or a boundary-aware reference distribution.
  - Done when: the n = 50 cells pass at nominal and the accepted rows (reason starting `v1.1.0-TODO-217`) in `R/package_tests/calibration/calibration_study_accepted.csv` are pruned; or the owner rules it inherent and the rows stay with a reason saying why.
  - **Investigated 2026-11-19** (agent; scripts in the session scratchpad `todo217/`: `sim_model.R`, `sim_rand.R`, `perdraw.R`, `collapse_rate.R`, `emulate_rand.R`; calibration DGP `count_zinb`, DesignFixedBernoulli, current tree under `load_all(compile = FALSE)`).
    - (a) Model-based tests at n = 50: **small-sample, not a code bug.** `~.` (15 parameters for 50 subjects), 500 reps: Wald 0.185, score 0.186, LR 0.142, gradient 0.152, reproducing the campaign. 68% of fits are degenerate: 48% have a separated zero-inflation logit (a zi coefficient beyond +-10, fitted pi of 0 or 1) and 23% have theta at the Poisson boundary. On the 32% regular fits LR 0.052 and gradient 0.071 are close to nominal, while Wald 0.13 and score 0.14 stay high: the SD of the estimate is 0.46-0.59 against a median sandwich SE of 0.30-0.37. The fix below changes none of this (500 reps after the fix: Wald 0.213, score 0.194, LR 0.162, gradient 0.168, and yield rises from 479 to 500 because previously failed degenerate fits now converge). So the candidates above (document a minimum n, or bootstrap at small n) stand. Side finding: `get_likelihood_test_spec()` falls back to `get_zinb_score_cpp` / `get_zinb_hessian_cpp` / `get_zinb_neg_loglik_cpp`, which do not exist; those fallbacks are reachable only when a fit lacks the fields, which no current path hits.
    - (b) Randomization test: **a real bug, so it belongs in v1.0.6, not here.** `fast_zinb_cpp(optimization_alg = "newton_raphson")` (the class default), warm-started from the full-data MLE, returns a non-MLE fit on permuted assignments in two ways. (1) Newton steps to where every zi linear predictor is below -10, and `fit_zinb_zi_boundary_fallback()` (fast_zinb.cpp) accepts the zi-off NegBin fit (`reduced_model = "NegBinNoZI"`) without comparing likelihoods; its nll is 0.6-4 higher than the interior MLE (cold start, L-BFGS, pscl). (2) Newton runs along a separation ridge (zi coefficients near 1e5), and `accept_zinb_near_stationary_gradient()` reports converged with a gradient norm near 1e-2. Wrong-draw rate against fresh fits, Newton from the full-data fit (the current tree after c28bbb34 / v1.0.6-TODO-61): 14% at n = 200 `~1`, 13% at n = 1000 `~1`, 2% at n = 50 `~.`. Chained from the previous draw (the e36c7710 loop the campaign ran): 36%. NA statistics are not the issue: the NA rate over draws was 0, and NA draws are dropped with a minimum of max(10, r/10) finite draws.
    - Effect on size, class-level `compute_rand_two_sided_pval()` (r = 501): n = 50 `~.`, same 400 datasets: 0.082 before the fix vs 0.045 after (NegBin 0.045, ZIP 0.068 / 0.055). n = 200 `~1`: 0.058-0.060 both before and after (600 and 400 reps; the fix changed the p-value in 299 of 400 reps but not the size). A kernel-level emulation with 200 draws compared the three warm-start policies. n = 200 `~1`, 400 reps: chained 0.072, anchored 0.043, guarded 0.045. n = 1000 `~1`, 300 reps: 0.050 / 0.030 / 0.030. So the campaign's `~1` flags at n = 200 and 1000 fit the e36c7710 chaining (v1.0.6-TODO-30's c28bbb34 gate and v1.0.6-TODO-61 removed it). The n = 50 `~.` flags persist on the current tree and are fixed here. Re-check every n on the confirmation stage at a post-fix sha.
    - Fix (R only, no rebuild): `fast_zinb_cpp_guarded()` and `zinb_neg_loglik_r()` at the end of `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`. All five ZINB `fast_zinb_cpp()` calls in that file now go through the guard: the full fit, the randomization statistic, the likelihood-test null fits and the parametric-bootstrap full and null fits. A suspect fit is one at the zi boundary, with a zi coefficient beyond +-10, with a gradient norm above 1e-5, or not converged. If the data have zeros and no zi coefficient is fixed, a suspect fit is refit with L-BFGS from the same start and from the cold start, and the lowest-nll fit is kept. Blast radius: ZINB only (ZIP, Hurdle and ZOIB do not call it). The root fix belongs in C++: both acceptance paths should compare nll against an interior refit before accepting. Not built here.
    - A known test changed meaning: `test-count-classes-estimates-match-glm-nb-and-pscl-and-zinb-kernel-reference.R` expected the "no excess zeros" fit to equal glm.nb, but that was the spurious boundary fit. pscl's interior MLE has a lower nll (367.4735 vs 367.5391), and the class now matches pscl. That test was updated. Regression test: `R/package_tests/testthat_bulk/test-zinb-spurious-zero-inflation-boundary-refit.R` (fails before the fix, passes after).
  - Decided 2026-11-19 (owner): part (a) inherent (small-sample degeneracy at n = 50); see [DECISION-v1.1.0-TODO-217](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-217).
  - The accepted rows (reason starting `v1.1.0-TODO-217`) stay with that reason. Documented in the class roxygen and `man/InferenceCountZeroInflatedNegBin.Rd` ("Many covariates in small samples": adjust for fewer covariates or prefer the LR test at small n), in the same way as v1.1.0-TODO-216. Part (b), the randomization-test bug, moved to v1.0.6-TODO-222; this TODO is done once that is tracked there.
  - Accepted rows completed 2026-11-21 (coordinator, owner request): 19 confirmed n = 50 ZINB likelihood-test cells (10 size, 9 coverage) had no row after wave 24 of campaign 2026-11-15-e36c7710; added with this TODO's reason, level = the worse of the screening and confirmation values + 3 SE. The randomization-test cells are not accepted here; they belong to v1.0.6-TODO-222 (fixed after e36c7710).

- [ ] TODO-218 (added 2026-11-19, owner; opened for accepted calibration rows): **`InferenceCountPoisson` `~1`: every model-based test oversized on the blocking designs (FixedBlocking, SeqOneByOneSPBR, SeqOneByOneRandomBlockSize); cause unknown.**
  - Why: campaign 2026-11-15-e36c7710 (screening stage, 1000 replicates): Wald, score, LR and gradient with `~1` have size and 1 - coverage 0.078-0.106 at n = 200 and 1000, prob_T 0.2 and 0.5, on those three designs only (64 flags). The `~.` cells are nominal there.
  - Puzzle: covariate balancing should make the design-ignoring model-based variance conservative, and it does on the optimizing designs (Wald `~1` n = 1000 prob_T 0.5: FixedGreedy and FixedOptimal 0.008). The unstratified designs are mildly high (FixedBernoulli 0.071, SeqOneByOneBernoulli 0.065), consistent with overdispersion from the omitted covariates; the blocking designs, which stratify on the factor covariates x4 and x5, are worse (FixedBlocking 0.083, SPBR 0.082, RandomBlockSize 0.106).
  - Investigate first: arm sizes and treated share per replicate under these designs (unequal arms within strata at n = 1000?); whether the DGP's count mean depends on x4 / x5 strongly enough that stratification changes the marginal overdispersion; the same cells for QuasiPoisson and RobustPoisson (the sandwich should be nominal). A design bug (wrong allocation or prob_T) would move this to v1.0.6.
  - Done when: the cause is known, the cells pass or the behaviour is documented with an owner ruling, and the accepted rows (reason starting `v1.1.0-TODO-218`) in `R/package_tests/calibration/calibration_study_accepted.csv` are pruned or kept with that reason.
  - **Investigated 2026-11-19 (agent): cause found, a code bug in `InferenceCountPoisson`'s design-conservative guard, not a design bug and not inherent. Fixed (uncommitted).**
    - Mechanism. Every model-based test of this class reports max(model p, jackknife-Wald p) and the union of the CIs; the jackknife half is what absorbs overdispersion. With `~1` the DGP is overdispersed (Pearson dispersion 2.16; the omitted x1-x3, x4, x5 give Var(Y) about 2.2 x mean), so the raw Poisson Wald has sd(est)/mean(se) = 1.50-1.54 under Bernoulli and size 0.18-0.19. On a blocking design the automatic jackknife unit is `"block"`, and the campaign's blocks are the 4 strata of x4 x x5. Leave-one-stratum-out with 4 units: at the campaign commit e36c7710 it had 3 df with a normal reference, so its SE was usually too small to widen anything (partial rescue); since v1.0.6-TODO-135 (2026-11-18, fewer than 5 units gives NA) it is NA and the raw Poisson test is reported alone. Unstratified designs get the delete-1 observation jackknife (`build_jackknife_deletion_draws()` falls back to observations when there are fewer than 2 blocks, which is also why iBCRD is fine), so the guard works there. Stratification itself helps a little, as expected: the raw ratio drops from 1.50 to 1.35-1.49.
    - Evidence (scratchpad `todo218/sim2.R` and `edi3.R`: campaign seeds `cal_study_seed("count", n, rep)`, `cal_study_gen_X`, potential outcomes and `cal_study_run_design`, 1000 reps, closed-form `~1` leave-one-out). Wald size, n = 200, three blocking designs x prob_T 0.5 / 0.2: raw 0.145-0.185; emulated campaign guard (4-unit jackknife) 0.086-0.105 (the campaign's 0.085-0.106); current code = raw, 0.145-0.185, now worse than the campaign; stratified delete-1 jackknife guard 0.038-0.058; fixed EDI class (first 400 reps) 0.040-0.058. n = 1000 FixedBlocking prob_T 0.5: raw 0.147, campaign guard 0.083 (campaign 0.083), fix 0.047 (150 reps). The n = 1000 run died after that row (no R error text; probably the concurrent user build), so the other n = 1000 cells are not re-run.
    - Leads ruled out. Allocation is exact: n = 200 treated 100.0 (sd 0.7-1.1), per-stratum share 0.49-0.51; prob_T 0.2 gives 40.0 treated, share 0.19-0.21; n = 1000 FixedBlocking 500.0, share 0.499-0.501. The strata are the intended x4 x x5 (4 block ids), and no block variable enters the `~1` fit (EDI estimate and SE equal `glm(y ~ w, poisson)`). QuasiPoisson Wald (0.033-0.056) and RobustPoisson Wald (0.035-0.058) are nominal on the same cells in the campaign CSV, and so is rand (0.040-0.061).
    - Fix (`R/EDI/R/inference_count_poisson.R`): new private `design_stratified_jackknife()`. When the automatic jackknife p-value or CI is NA, the design is blocking with auto unit `"block"` and 2-4 blocks, and the estimand is `"conditional"`, the class falls back to the stratified delete-1 jackknife (Shao & Tu 1995 sec. 6.2): delete-1 refits with `fast_poisson_regression_cpp`, variance pooled within blocks, Wald centred at the full estimate, cached per object. `design_jackknife_pval()` and `design_jackknife_ci()` use it. Nothing else changes: unstratified designs, designs with 5 or more blocks, cluster and matching designs, the marginal estimands, and other classes (only this class has the guard) behave as before. No seeded design draws change.
    - Test: `R/package_tests/testthat_bulk/test-count-poisson-stratified-jackknife-guard-few-strata.R` (FixedBlocking and SPBR with 4 strata, exact match to a closed-form stratified jackknife; fallback off on iBCRD, on 8 blocks and for `marginal_mean_diff`): 23 pass. Under `load_all(compile = FALSE)` these also pass: the two existing count-poisson guard/refit tests, count-likelihood-families-focused (855 pass), marginal-estimand SE consistency, recorded-na-reason-warns, procedure-failure-keeps-wald-state, blocking-strata-in-design-formula-bca-jackknife.
    - Still open: (1) re-run the campaign cells (all 64 flags) on the fix, then prune the accepted rows; (2) Bernoulli / SeqOneByOneBernoulli `~1` at 0.065-0.076 is the delete-1 jackknife-Wald's own small anti-conservatism (0.071 under every variant at n = 1000), not this bug; tracked as v1.1.0-TODO-219; (3) owner decision pending: [DECISION-v1.1.0-TODO-218](PENDING_DECISIONS.md#DECISION-v1.1.0-TODO-218) (should the stratified delete-1 jackknife replace leave-one-stratum-out for every `"block"` unit?).
  - Decided 2026-11-19 (owner): fix accepted; see [DECISION-v1.1.0-TODO-218a](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-218a).
  - Reworked the same day to reuse the shared estimator instead of a private copy. v1.0.6-TODO-4 (committed 5bdb9dfb) had already moved DesignFixedBlocking to the stratified delete-1 unit `"observation_within_block"` and SPBR to `"permuted_block"`, so the gap left is blocking designs whose automatic unit is still `"block"` (DesignSeqOneByOneRandomBlockSize and the other blocking designs). `design_jackknife_pval()` / `design_jackknife_ci()` now retry the shared jackknife with `unit = "observation_within_block"` (Wolter 2007, Sec. 4.5, with EDI's reweighting scaling) when the automatic jackknife is NA there and the design has at least 2 blocks (private `use_within_block_jackknife_fallback()`); the private `design_stratified_jackknife()` is gone. Because the shared jackknife refits under the active estimand, the fallback now also covers the marginal estimands. Documented in NEWS ("Changes that alter results"), the class roxygen and `man/InferenceCountPoisson.Rd` ("Which jackknife", with the Wolter reference) and REFERENCES.md. Test `test-count-poisson-stratified-jackknife-guard-few-strata.R` rewritten to the Wolter JKn formula (23 pass); the stubs in `test-count-poisson-design-conservative-pval-ci-and-jackknife-wrappers-reference.R` now take `unit` (26 pass). Still open: re-run the 64 campaign cells on this code, then prune the accepted rows; the agent's simulated sizes used the unscaled formula, which differs from the shared one by a factor of about (n_h/(n_h - 1))^2 in the variance, negligible at these stratum sizes.
  - **Verified locally 2026-11-19 (agent): the fallback is nominal where it runs; the cells on the current tree are nominal except two jackknife-unit cells, both outside this fix.** The `InferenceCountPoisson` class itself with `~1` (`pkgload::load_all(compile = FALSE)`), campaign seeds `cal_study_seed("count", n, rep)`, `cal_study_gen_X`, null potential outcomes and `cal_study_run_design` (strata x4 x x5), 2 cores. Wald = `compute_asymp_two_sided_pval()`. Size at alpha 0.05 with a binomial (Clopper-Pearson) 95% interval. Wald, score and LR agree in every cell, because the jackknife p-value is the larger half of max(model p, jackknife p) in every replicate. "Fallback" is the share of replicates where `use_within_block_jackknife_fallback()` was TRUE.
    - Tree. The n = 200 rows ran at 6ae5d609. Commit 72ea20ba (2026-11-20 01:03, v1.0.6-TODO-231) landed before the n = 1000 rows started; it moves DesignSeqOneByOneRandomBlockSize's automatic unit from `"block"` to `"permuted_block"`. On that tree no campaign design reaches the fallback: FixedBlocking uses `"observation_within_block"`, and SPBR and RandomBlockSize use `"permuted_block"`. The RandomBlockSize n = 200 rows were re-run on the current tree (rows marked "re-run").

    | design | prob_T | n | reps | fallback | Wald (= score = LR) | raw glm Wald |
    |---|---|---|---|---|---|---|
    | FixedBlocking | 0.5 | 200 | 1000 | 0 | 0.035 [0.024, 0.048] | 0.145 |
    | FixedBlocking | 0.2 | 200 | 1000 | 0 | 0.041 [0.030, 0.055] | 0.174 |
    | SeqOneByOneSPBR | 0.5 | 200 | 1000 | 0 | 0.063 [0.049, 0.080] | 0.176 |
    | SeqOneByOneSPBR | 0.2 | 200 | 1000 | 0 | 0.063 [0.049, 0.080] | 0.163 |
    | SeqOneByOneRandomBlockSize (fallback, 6ae5d609) | 0.5 | 200 | 1000 | 1 | 0.035 [0.024, 0.048] | 0.173 |
    | SeqOneByOneRandomBlockSize (fallback, 6ae5d609) | 0.2 | 200 | 1000 | 1 | 0.055 [0.042, 0.071] | 0.185 |
    | SeqOneByOneRandomBlockSize (re-run, permuted_block) | 0.5 | 200 | 1000 | 0 | 0.055 [0.042, 0.071] | 0.173 |
    | SeqOneByOneRandomBlockSize (re-run, permuted_block) | 0.2 | 200 | 1000 | 0 | **0.082 [0.066, 0.101]** | 0.185 |
    | FixedBlocking | 0.5 | 1000 | 500 | 0 | 0.032 [0.018, 0.051] | 0.162 |
    | FixedBlocking | 0.2 | 1000 | 500 | 0 | 0.044 [0.028, 0.066] | 0.162 |
    | SeqOneByOneSPBR | 0.5 | 1000 | 500 | 0 | 0.052 [0.034, 0.075] | 0.160 |
    | SeqOneByOneSPBR | 0.2 | 1000 | 500 | 0 | 0.062 [0.043, 0.087] | 0.184 |
    | SeqOneByOneRandomBlockSize (permuted_block) | 0.5 | 1000 | 500 | 0 | 0.060 [0.041, 0.085] | 0.178 |
    | SeqOneByOneRandomBlockSize (permuted_block) | 0.2 | 1000 | 500 | 0 | 0.042 [0.026, 0.063] | 0.168 |

    - Verdict. The fix holds. The `"observation_within_block"` fallback gave 0.035 and 0.055 on RandomBlockSize at n = 200, and FixedBlocking, which uses the same unit automatically, gives 0.032-0.044. The campaign's 0.08-0.11 is gone wherever the jackknife has enough units.
    - New, from v1.0.6-TODO-231, not from this fix: on the current tree RandomBlockSize prob_T 0.2 at n = 200 is oversized (0.082). Its permuted-block layout has only 16-20 deletion units, 3-4 in the smallest stratum (prob_T 0.2 block sizes 5/10/15), and a jackknife-Wald with a normal reference is anti-conservative with that few units. The same cell under the fallback was 0.055. SPBR's `"permuted_block"` (38-49 units at n = 200) is mildly high, 0.052-0.063 over four cells (pooled about 0.061 over 3000 reps). That is similar to the delete-1 jackknife-Wald's own excess in v1.1.0-TODO-219. Options for the owner: fall back to `"observation_within_block"` when a permuted-block layout has fewer than about 5 units in some stratum, or use a t reference with (units - strata) df. The confirmation stage should expect the RandomBlockSize prob_T 0.2 n = 200 `~1` cells to stay flagged until then.
    - Scripts and outputs: session scratchpad `verify218_222/` (`v218.R`, `v218_n200.rds`, `v218_n1000.rds`, `v218_n200_rbs_current.rds`, `units.R`, `tables.md`). Accepted calibration rows not pruned (the owner does that after the confirmation stage).

- [ ] TODO-219 (added 2026-11-19, owner): **`InferenceCountPoisson` `~1` on unstratified designs: model-based tests slightly oversized (about 0.065-0.076) even with the design-conservative jackknife guard.**
  - Why: found while investigating v1.1.0-TODO-218. Under FixedBernoulli and SeqOneByOneBernoulli with `~1` (overdispersed DGP, Pearson dispersion about 2.16), Wald size is 0.065-0.076 in campaign 2026-11-15-e36c7710. In the TODO-218 agent's re-run (1000 reps, campaign seeds), FixedBernoulli prob_T 0.5 gave 0.057 at n = 200 and 0.071 at n = 1000, the same under every guard variant. So the excess is the delete-1 observation jackknife-Wald's own, not the blocking bug: max(model p, jackknife p) is still slightly anti-conservative when the raw Poisson SE is about 1.5x too small.
  - Investigate first: the jackknife-Wald alone at n = 1000 (is its size about 0.07, and why at large n?); the jackknife variance vs the sandwich (HC0/HC3) and vs sd(est) over replicates; whether a t reference or an HC3-style inflation brings it to nominal; whether the same excess appears in other classes that use the design-conservative guard. Scripts: the TODO-218 agent's `sim2.R` (session scratchpad, not in the repo).
  - Done when: the cause is known and either the cells are nominal at the confirmation stage or the owner rules the size inherent, with the advice to use QuasiPoisson / RobustPoisson under overdispersion added to the class documentation. Any accepted calibration rows for these cells cite this TODO.
  - **Investigated 2026-11-19 (agent): no bug, and not inherent to the jackknife. The excess comes from the screening replicate set: on fresh seeds the guard is nominal.** No code changed.
    - Method (scratchpad `todo219/jk1.R`, `analyze.R`): campaign DGP, designs and seeds (`cal_study_seed("count", n, rep)`). The closed-form delete-1 jackknife of log(mean y_T) - log(mean y_C) matches `InferenceCountPoisson` `~1` `compute_asymp_two_sided_pval()` and `compute_jackknife_wald_two_sided_pval()` to 3e-9 (80 reps checked at n = 200 and 1000). Screening reps 1-1000 vs confirmation-range reps 10001-19999 (9999 reps, MC SE of a 0.05 size 0.0022).
    - FixedBernoulli prob_T 0.5, size at nominal 5%. Reps 1-1000: n = 200 guard 0.057, n = 1000 guard 0.071 (the campaign's numbers). Reps 10001-19999: guard **0.051 at n = 200 and 0.051 at n = 1000**. On reps 1-1000 at n = 1000 every studentization gives 0.071: jackknife-Wald centred at the bias-corrected estimate, centred at the plain estimate, t_{n-2} reference, HC0, HC2, HC3, quasi-Poisson. Even the oracle Wald with SE = sd(est) over those same 1000 reps rejects 0.061. So those 1000 replicates happen to have heavy tails in the estimate; no SE formula could fix that. SeqOneByOneBernoulli, reps 1-1000: guard 0.054 at n = 200 and 0.065 at n = 1000 (the campaign's 0.065). At n = 1000 every studentization gives 0.064-0.065 and the oracle 0.056, the same seed-set pattern. Seq shares X and y with FixedBernoulli for each rep, so it is not independent evidence.
    - SE comparison (n = 1000, 9999 reps): sd(est) 0.0569; RMS jackknife SE 0.0566, HC0 0.0564, HC3 0.0565, raw Poisson 0.0384 (ratio 1.48 = sqrt(dispersion)). At n = 200: sd(est) 0.1266, jackknife 0.1276, HC0 0.1257, HC3 0.1270. The jackknife is unbiased for the variance here, and its CV across reps is 3% (n = 1000) and 7% (n = 200).
    - Fixes asked about: centring makes no difference (bias correction about 2e-5; size 0.0507 both ways). A t reference changes size by under 0.002 (0.0503 / 0.0495). HC3 inflation is not needed: the jackknife already sits at HC3 (0.0511 vs 0.0507). The binomial chance of at least 71/1000 rejections at a true size of 0.051 is 0.004; with hundreds of cells screened, one such cell (and its correlated Seq twin) is expected.
    - Other classes: only `InferenceCountPoisson` uses the max(model p, jackknife p) / CI-union guard. The KK conditional-Poisson OneLik classes use a related max(SE_model, SE_jackknife) rule (`.inflate_kk_onelik_standard_error_with_jackknife`), but only on KK matching designs (pair deletion units), so they never see these cells. Because seeds depend only on (response type, n, rep), every count class's `~1` Wald on FixedBernoulli n = 1000 reps 1-1000 should show the same replicate-set excess (the emulated quasi-Poisson and HC0/HC3 Walds give 0.071 there). Check QuasiPoisson / RobustPoisson in the campaign CSV, which was not on disk for this check.
    - Suggested close: let the confirmation stage (reps 10001+) decide these cells. Expect them to pass. Any accepted rows should cite v1.1.0-TODO-219 as screening-seed noise, not a defect. No change to the class or its documentation is needed for this item.

- [ ] TODO-179 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidRiskDiff`: Risk difference: Wald oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. (size 0.095) and ~1 (size 0.09), n = 50 prob_T 0.2; unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: unpooled Wald SE with about 10 treated (known anti-conservative); zero-event arms.
  - Fix (candidates): Agresti-Caffo adjustment or Newcombe / Miettinen-Nurminen interval for small arms.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-179`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-180 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceIncidWald`: Incidence Wald: oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. and ~1, n = 50 prob_T 0.2 (size 0.09, coverage 0.91); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: same mechanism as TODO-179 (unpooled SE in a small arm).
  - Fix (candidates): adjusted Wald (Agresti-Caffo) or document.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-180`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-181 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceOrdinalCauchitRegr`: Ordinal cauchit: likelihood tests oversized at n = 50.**
  - Why: accepted rows gradient / LR / score ~. n = 50 prob_T 0.5 (size 0.09-0.095) and score ~. / ~1 n = 50 prob_T 0.2 (size 0.125 / 0.10); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-10-30 and 2026-11-06 runs. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: heavy-tailed link: information accuracy at small n; separation / extreme cutpoints.
  - Fix (candidates): bootstrap-calibrated p-values or document; compare with OrdinalPropOddsRegr.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-181`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-182 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceOrdinalGCompMeanDiff`: Ordinal G-computation mean difference: Wald oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. n = 50 prob_T 0.2 (size 0.085, coverage 0.915); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: delta-method SE vs sd(estimate) in the 10-subject arm.
  - Fix (candidates): small-sample variance correction or bootstrap SE.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-182`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-183 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalDepCensTransformRegr`: Dependent-censoring transform regression: score / LR oversized at n = 50.**
  - Why: accepted rows lik_ratio ~. and score ~. / ~1 n = 50 prob_T 0.5 (size 0.085-0.09), score ~. coverage 0.915 at prob_T 0.2; small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-10-30 and 2026-11-06 runs. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: few events at n = 50; information accuracy of the copula / transform parameters.
  - Fix (candidates): bootstrap-calibrated p-values or document.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-183`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-184 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`: Weibull frailty (log-gamma) OneLik: Wald oversized at n = 50.**
  - Why: accepted rows wald ~. and ~1 n = 50 prob_T 0.5 (size 0.09, coverage 0.91); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run. The score excess at moderate n is TODO-166. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: frailty variance collapsing to the boundary at n = 50; SE vs sd(estimate).
  - Fix (candidates): boundary-aware SE or bootstrap SE; may share TODO-166's bootstrap.
  - Rows repointed 2026-11-12: the 6 score rows (`~.` n = 50; `~1` n = 50 / 200) that cited a bare `TODO-179` now cite this TODO. An earlier session's 2026-11-07 investigation called `~.` n = 50 small-sample and `~1` honest harness misspecification (BinaryMatch pairs on covariates `~1` omits); the `~1` part needed an owner ruling. The `~.` n = 50 rows remain open here.
  - Decided 2026-11-12 (owner): the 4 `~1` rows are inherent misspecification and stay; see [DECISION-v1.1.0-TODO-184](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-184).
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-184`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-185 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalGLMMWeibullFrailtyNormalOneLik`: Weibull frailty (normal) OneLik: score oversized at n = 50.**
  - Why: accepted rows score ~. and ~1 n = 50 prob_T 0.5 (size 0.085-0.09); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: check whether TODO-166's mechanism (null fit lowers the frailty variance, shrinking the null information) applies.
  - Fix (candidates): bootstrap-calibrated score p-value (as TODO-166).
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-185`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-186 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalKKWeibullMarginal`: KK Weibull marginal: Wald oversized at n = 50.**
  - Why: accepted rows wald ~. n = 50 prob_T 0.5 (size 0.085, coverage 0.915); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); 2026-10-30 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: SE vs sd(estimate); robust variance with few pairs.
  - Fix (candidates): small-sample sandwich correction or document.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-186`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-187 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalLogRank`: Log-rank Wald (HR) CI: oversized at prob_T = 0.2, n = 50.**
  - Why: accepted rows wald ~. and ~1 n = 50 prob_T 0.2 (size 0.095, coverage 0.905); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-11-06 run. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: which variance the HR Wald uses (O-E / V vs Cox); log-rank test p-value itself vs the Wald CI.
  - Fix (candidates): use the log-rank score variance for the CI, or document.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-187`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-188 (added 2026-11-09, owner; opened for accepted calibration rows): **`InferenceSurvivalWeibullRegr`: Weibull regression: score oversized at n = 50.**
  - Why: accepted rows score ~1 n = 50 prob_T 0.5 (size 0.095) and score ~. / ~1 n = 50 prob_T 0.2 (size 0.095 / 0.11); small-sample (n = 50 only) asymptotic anti-conservatism, shrinking with n (the n = 200 cell passes); unequal allocation prob_T = 0.2 (about 10 treated at n = 50), shrinking with n (the n = 200 cell passes); 2026-10-30 and 2026-11-06 runs. Documented in the class's roxygen ("Small samples") for now.
  - Investigate first: expected vs observed information at the null fit with few events.
  - Fix (candidates): observed-information score or bootstrap calibration.
  - Done when: the cell passes the fast-tier gate at nominal and its accepted rows (reason starting `v1.1 TODO-188`) in `R/package_tests/calibration/calibration_fast_tier_accepted.csv` are pruned; or, if it is an inherent property, the owner rules so and the rows stay with a reason saying why.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-189 (added 2026-11-09, owner; follow-up of v1.0.5 TODO-179): **Boundary MLEs of the constrained binomial classes: what is left after Wald became NA for `InferenceIncidLogBinomial`.**
  - Done in v1.0.5 TODO-179 (2026-11-09, the "make Wald NA at the boundary (with LR suggested)" idea): `InferenceIncidLogBinomial` returns NA for the Wald p-value and CI when the full-data MLE has a linear predictor within 1e-8 + 1e-6 of 0, with warning class `edi_wald_mle_boundary_unavailable` and `procedure_failure_reason[["wald"]]`; `fit_null` got a strictly feasible last-resort start, so the LR interval at those fits no longer falls back to Wald (526 -> 75 of 1000 at n = 50). Study cell (Bernoulli, `~.`, p = 5, 1000 null reps): Wald NA in 68% (n = 50) / 66% (n = 200) of reps; Wald size over the rest 0.041 / 0.047, coverage 0.959 / 0.953.
  - (a) LR is still oversized at boundary MLEs: size 0.085 (n = 50) / 0.078 (n = 200) in boundary reps vs 0.048 / 0.044 interior; LR coverage 0.924 / 0.934. Candidates: parametric-bootstrap-calibrated LR (`compute_lik_ratio_bootstrap_*`, already supported) as the recommended boundary procedure, or a chi-bar-squared reference.
  - (b) 75 of 1000 LR CIs at n = 50 (7 at n = 200) still fall back to Wald: one null refit at a single delta fails (non-converged) while neighbouring deltas succeed. Overlaps TODO-165 (kernel boundary convergence). Either fix the kernel or let the root search step past one failed refit; and decide whether a Wald fallback under the LR label should itself be NA at a boundary MLE.
  - (c) `InferenceIncidBinomialIdentityRiskDiff` (identity link, bounds at mu = 0 and 1, same TODO-128 warning and `edi_binomial_bound_kkt_core()`) was NOT changed: its Wald path is the generic `StandardModelCache` one, and the identity-link boundary needs its own decision (two-sided bounds; `~1` boundary is a 0% or 100% arm, where the SE is already 0). Measure its boundary share and Wald size in the study cell first. `InferenceIncidRiskDiff` (unpooled Wald, v1.1 TODO-179) does not have this boundary.
  - Done when: (a)-(c) are each fixed or ruled honest by the owner, and the LogBinomial / BinomialIdentity accepted calibration rows say which.
  - **Split 2026-11-10 (owner approval of the v1.0.6 triage):** parts (b) and (c) moved to `release_v1_0_6.md → TODO-9`; part (a) is triaged in `release_v1_0_6.md → TODO-13`. This TODO keeps (a) only.

- [ ] ~~TODO-190~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-10`** (owner approval of the v1.0.6 triage): `fast_clogit_plus_glmm_cpp()` false `converged = TRUE`.

- [ ] TODO-191 (added 2026-11-10, owner; rewritten the same day; started from v1.0.5 TODO-1 / `finished_features/v1_0_5/reusable_bootstrap.md` TODO-3): **Cache the column-dropping fallback of `fit_with_hardened_qr_column_dropping()` across resampling draws; first acceptance case: the ZOIB jackknife's "low hundreds of ms" for 50 folds.**
  - The cost. `fit_with_hardened_qr_column_dropping()` (`inference_all_abstract.R` ~L1344, called from 37 files: OLS, robust regression, NegBin, Poisson family, logit/probit/log-binomial/identity/risk-diff/modified Poisson, every ordinal regression, beta, fractional logit, ZOIB, the survival regressions and KK GEE/GLMM/CLMM/cond-logit/survival classes) picks a full-rank column set by pivoted QR, fits, and if `fit_ok` fails drops the least important column (reverse pivot order) and refits, until a fit passes. Every failed attempt is a full model fit, repeated from scratch on every draw that needs it. The existing rank certificate only skips the QR; it does not skip failed fits.
  - Example. ZOIB jackknife on the diagnosed fixture (proportion, n = 50, `edi_tuning_default_seed(cls, 50L)`): 5.84 s reusable vs 7.85 s legacy (earlier 11.05 vs 6.62 s). In 8 of 50 folds the direct fit gives a non-finite treatment coefficient and the fallback runs 3 full fits (two non-finite p = 4, one finite p = 3); see `reusable_bootstrap.md` TODO-3, "Exact-seed fallback observer, 2026-10-21".
  - Not in scope. The rank-only routes do one QR per draw and no refits: `reduce_design_matrix_preserving_treatment*()` (already has `reduced_design_keep_cache`), the class-specific reducers on `qr_reduce_preserve_cols_cpp` (KK quantile, KK cond Poisson, quantile regression, Cox PH) and `drop_linearly_dependent_cols()`. Side check while here: `try_cached_reduced_design_keep()` accepts the previous keep set whenever it is full rank, without checking that a fresh QR would keep more columns; harmless while the generic worker resets the cache per draw (`inference_all_abstract_non_param_boot.R` ~L1751), wrong if that cache is ever kept across draws.
  - Step 1, measure first. Count, per class and per resampling operation (non-parametric / Bayesian bootstrap, jackknife, randomization refits, parametric LR bootstrap refits), how often the drop loop goes past its first attempt and how many failed fits it costs, on the tuning fixtures and on a few real datasets from the catalog. For randomization and parametric LR bootstrap refits, count under both today's full-fit warm start and the v1.1.0-TODO-270 start: many `fit_ok` failures there may come from the off-center start rather than rank, and would go away without this cache. If it is rare outside degenerate fixtures, report the counts to the owner before building steps 2-3 and the API.
  - Parametric LR bootstrap (added 2026-11-24, owner request). It suits this cache well: only y changes between draws, while X and w stay fixed (`inference_all_abstract_param_boot.R` ~L1016 already keeps the design caches for that reason), so the QR and the drop search order are identical on every draw, and they are also identical at every delta of a CI inversion. A worker's cache can therefore cover the whole inversion, not one delta, still under the draw-order rule. Check first which of the 41 classes that define `get_likelihood_test_spec()` reach the drop loop inside the spec's full and null refits (22 of those files call `fit_with_hardened_qr_column_dropping()`, not necessarily from the spec). When the treatment coefficient is non-finite because the simulated data are separated, dropping a covariate cannot fix it: those attempts count as proven to fail for step 2.
  - Shared with v1.1.0-TODO-270: when the loop drops columns, the warm-start vector must be cut down to the kept columns (the treatment column is never dropped, so its start value keeps its place). With a cached column set the cut is the same on every draw.
  - Step 2, exact version. Store per worker and call site (one entry per design matrix) the number of columns the last draw's loop dropped. On a draw that needs the loop, the search order is fixed, so results may change only if attempts are skipped that would have passed: skip only the QR/closure setup, or skip attempts that are proven to fail, and keep every result bit-identical. Results must not depend on draw order (serial vs parallel, v1.0.5 TODO-95 rule). The cache dies with the worker.
  - Step 3, approximate version (owner request 2026-11-10): on a draw that needs the loop, start at the cached column set and accept it if `fit_ok` passes, so a draw can end with fewer columns than a fresh search would keep. It changes results on those draws and makes them depend on draw order, so it is opt-in only and never a default.
  - User API (owner request 2026-11-10): one setting with three modes, for every class and resampling operation on this path:
    - `"scratch"`: the column search runs from scratch on every draw (today's behavior).
    - `"exact"`: step 2; results identical to `"scratch"`.
    - `"approximate"`: step 3.
    - Shape it like the existing dispatch policies (`set_warm_start_dispatch_policy()` and siblings in `globals.R`): `set_column_selection_cache_policy()` / `get_column_selection_cache_policy()` with a global default, `inference_class_overrides`, and `reset = TRUE`. Draft names; settle them before the code lands.
    - Default: `"scratch"` until step 2 passes the parity gate; then `"exact"`. `"approximate"` is never the default, and the tuner (`tune_EDI_for_this_machine()`) must not select it (it changes results).
    - Record the mode in effect in each resampling result's provenance, so a result can say which mode produced it.
    - Document it (what each mode does, that `"approximate"` can change estimates and depends on draw order) in the roxygen of the resampling methods users call (bootstrap, Bayesian bootstrap, jackknife, randomization), not only on the setter. NEWS entry.
    - Tests: `"scratch"` and `"exact"` give bit-identical results on the golden fixtures; `"approximate"` gives the same results as `"scratch"` when no draw needs the loop; per-class override and reset behave like the other policies; serial and parallel give identical results under `"scratch"` and `"exact"`.
  - Done when: step 1's counts are recorded; the three-mode API ships with its docs and tests; if step 2 is built, all golden/parity tests pass unchanged (including `test-zoib-jackknife-reusable-worker-migration-golden.R`), the ZOIB 50-fold jackknife on that fixture runs in low hundreds of ms on a quiet host (or the shortfall is recorded with a reason), and `tune_EDI_for_this_machine()` still completes the ZOIB jackknife axis.

- [ ] TODO-270 (added 2026-11-24, agent, owner request; follows v1.0.6-TODO-61 and v1.0.6-TODO-30): **Randomization replicates and parametric LR bootstrap refits (p-value and CI inversion): warm-start from the null-model fit with the treatment coefficient at its hypothesized value (0 for the p-value), instead of from the full-data fit.**
  - Today. Every redraw starts from the worker's `base_fit_warm_start`, the full-data fit (beta-hat, tau-hat); it is reset per draw in `inference_all_abstract_rand.R` ~L1436. Chaining between redraws is banned (owner 2026-11-19, v1.0.6-TODO-61). Some classes already start each redraw from the redraw's own data instead (KK CLMM; see v1.1.0-TODO-266).
  - Proposal. Use one fixed start for every redraw: (beta_null, 0). beta_null is the fit of y on X without w (the restricted MLE under H0: tau = 0, plus ancillaries such as dispersion, cutpoints and frailty variance). Every treatment-related parameter starts at 0: both the count and zero parts in hurdle / zero-inflated models, and any w interactions. It is one start for all redraws and independent of the core count, so it keeps the TODO-61 reproducibility guarantee.
  - Why. Under the sharp null the permuted w is unrelated to y, so a redraw's treatment estimate centers on 0, not on tau-hat; with a large real effect, the tau-hat start is far from every redraw's optimum. Because w is randomized it is close to orthogonal to X, so the redraw's covariate coefficients land near beta_null. Take beta from the null fit, not beta-hat from the full fit with tau set to 0: under non-collapsibility (logit, Cox, ...), beta-hat is adjusted for a real effect that the permuted w does not have. It may also avoid the v1.0.6-TODO-30 trap: the ZIP full-data start sat on a treatment-driven ridge (zero-part intercept -23.8, treatment +23.8), which zeroing the treatment coefficients removes. The null fit can still sit on a ridge of its own (zero-part intercept going toward -infinity), so this is not a convergence fix for nonconcave likelihoods (`multistart_nonconcave_likelihoods.md`).
  - Generalize to the randomization CI (owner 2026-11-24). Each inversion step tests H0: delta = delta0, and delta0 converts arithmetically to a value of the treatment coefficient, beta_w0 = g(delta0) (identity on the coefficient's own scale, e.g. log-odds or log-rate; log for a ratio estimand; class-specific otherwise). Start every redraw of that step at (beta_null, g(delta0)), so delta0 = 0 gives beta_w = 0 and the p-value test is the special case. The start is fixed per delta0 and shared by all its redraws, so results stay independent of draw order and core count. Covariate start: the delta0 = 0 null fit, or the restricted fit with beta_w held at g(delta0) (offset) if step 1 shows it pays for its extra fit per inversion step. Where the adjusted response depends on w, check that this start is still close to each redraw's optimum. Classes whose estimand has no closed-form map to beta_w (e.g. marginal effects by g-computation) keep today's start; list them in step 1.
  - Third case: the parametric LR bootstrap test and its CI inversion (added 2026-11-24, owner request). At each delta it simulates B datasets from the null fit at delta, then refits the unrestricted and null models on each. The unrestricted refit starts from the observed full fit (`inference_all_abstract_param_boot.R` ~L1019, set from `private$fit_warm_start` at ~L1070), but the simulated data come from the null, so the unrestricted estimates center on g(delta), not tau-hat: the same mismatch as the randomization redraws. Start it from the null fit at delta that the worker already holds (`worker_eval$null_fit`, ~L1068): (beta_null(delta), g(delta)), at no extra fitting cost. Also check how each replicate's null refit is started, since the null warm cache is cleared per draw (~L1014). The non-parametric and Bayesian bootstraps and the parametric bootstrap of the estimate are out of scope: their replicates center on the full-data fit, so it is the right start there.
  - Shared with v1.1.0-TODO-191: when `fit_with_hardened_qr_column_dropping()` drops columns, this start must be cut down to the kept columns (the treatment column is never dropped, so g(delta) keeps its place). A better start may also make the drop loop run less often, which is why TODO-191's step 1 counts under both starts.
  - Reuse. The null fit may already exist through the `null_fit_warm_start_enabled` path (`inference_all_abstract.R` ~L802, ~L1011); check before adding a new fit.
  - Step 1, measure first. Compare (beta_null, 0), today's full-fit start and fresh cold fits on: the v1.0.6-TODO-30 ZIP repro (set.seed(3), n = 80, DesignFixedBernoulli, ~x1+x2, set_seed(11), 30 permutations), a logit with a large effect (non-collapsibility case), Poisson / NegBin, a hurdle model and one ordinal model. Record the per-redraw agreement with fresh fits (D2 numerical-equivalence rule), iteration counts, the share of redraws needing a retry, and wall time at n = 200 and 1000. Run one randomization CI inversion per fixture too, comparing the (beta_null, g(delta0)) start with today's on every inversion step, and list the classes with no closed-form g. Do the same for the parametric LR bootstrap test and its CI inversion on the fixtures whose class supports it (start (beta_null(delta), g(delta)) vs today's), recording how often the column-drop loop runs under each start (shared with v1.1.0-TODO-191 step 1). Report to the owner before changing any default.
  - Step 2. If step 1 favors it, make it the base start for randomization redraws and parametric LR bootstrap unrestricted refits (an opt-in first if results change beyond D2 tolerance; release rule for default changes otherwise). Classes whose redraws already start from their own data keep that unless step 1 shows the new start is better for them.
  - Done when: step 1's table is recorded here; if adopted, redraws match fresh fits within D2 on the step 1 fixtures, results are identical across `set_num_cores()` values, and NEWS names the change.

- [ ] TODO-271 (added 2026-11-25, agent, owner request): **Type I error on real outcomes by re-randomization: a real-data null wave, run first in every monthly calibration campaign.**
  - What it adds. The calibration study simulates outcomes, and `comprehensive_tests.R` puts simulated effects on real covariate matrices; neither tests a procedure on *real outcome distributions* (their skew, ties, excess zeros, censoring patterns, heavy tails, cluster structure) with a known truth. Re-randomization gives one: keep a real trial's covariates X and outcome y, discard its assignment, and draw a fresh w from a design D, independently of (X, y). The treatment then has no effect on any unit (the sharp null holds exactly), so every test of tau = 0 should reject at its nominal rate. For model-based tests the pseudo-true treatment coefficient is also 0 (w is independent of (X, y), so with an intercept the score for w is 0 at tau = 0), so the wave measures each procedure's size under the real y | X it would meet in practice, misspecification included.
  - The redraw design need not be the trial's own. Because w is ours, the null holds for any D; a trial whose catalog row says "Unknown ... assumed BCRD" is as usable as one with a documented design. Use the documented design where the catalog has one (e.g. `cgd`: blocking on `center`) and DesignFixedBernoulli / DesignFixedBCRD otherwise, and add the sequential designs by replaying subjects one at a time, in enrollment order where the data record it and a seeded random order otherwise (as in the README's "Sequential experimental data example → Real data").
  - Data. Start with the CRAN-hosted rows of `R/package_metadata/experimental_datasets.csv` whose Redistribution is `yes` (no Dataverse credentials or ICPSR terms in CI; the data are installed from CRAN at the pinned versions, never committed or uploaded as artifacts; only per-test results are published). One unit per (dataset, outcome, response type, design, inference class), using the catalog's outcome columns and types. Rows are taken as-is (complete cases on the analysis columns, the catalog's missingness sidecars say how many are lost); outcomes or datasets too large for a ~25-minute shard are subsampled without replacement to n = 50, 200 and 1000, matching the simulated grid, and the subsample is redrawn per replicate so the result is about the population of rows, not one subsample.
  - Placement (owner 2026-11-25: "maybe add it as the first wave in monthly calibration"). Plan these units ahead of the simulated null units in `plan_calibration_study.R` (a new effect level, e.g. `real_null`, ordered before `null`), so a campaign's first waves are the real-data null and its results publish before the long simulated sweep. They use the same shard packing, time box, dead-shard halving (v1.0.6-TODO-409), ledger and published README/figures; the gate compares each cell's rejection rate with the nominal level by the same binomial rule as the simulated null cells, and `calibration_study_accepted.csv` rows for real-data cells cite their own TODO like any other accepted row.
  - Sanity check built in: every randomization test redrawn from the same design D as the wave's w is exact by construction, so its cells must sit inside the binomial band; one outside it is a harness bug, not a finding.
  - Step 1, measure first. On 5-10 catalog datasets covering all six response types (suggested: `cgd` survival, `lalonde.exp` continuous, `strep_tb` ordinal, `indo_rct` incidence, `polyps` count, `Sleuth2::case1301` proportion; 223 catalog rows are CRAN-hosted with Redistribution `yes`), run 200 null redraws per (outcome, class) locally at the datasets' own n, and record: rejection rates at 0.05 per procedure, how they compare with the simulated null cells at the nearest n, the share of fits that fail or are non-estimable, and seconds per replicate (for `calibration_study_costs.csv`). Report to the owner before changing the planner: which datasets and outcomes to include, whether to subsample, how many replicates per unit (the simulated null uses --null-reps), and the added campaign cost in shards.
  - Step 2. If step 1 is approved: a dataset loader for the calibration scripts (from the installed CRAN packages, keyed by the catalog row), the `real_null` effect in the planner, runner, analysis and README renderer, and roster rules for which classes apply to each outcome's response type.
  - Done when: a campaign's first waves run the real-data null units and publish their size table and figure; the randomization-test cells pass the exactness check; any real-data cell outside the band has an open TODO or an accepted row citing one; and `R/package_tests/calibration/` documents the wave.

- [ ] ~~TODO-192~~ **→ moved 2026-11-10 to `release_v1_0_6.md → TODO-11`** (owner approval of the v1.0.6 triage): Realistic proportion data for `tune_EDI_for_this_machine()`.

## Standing constraints

All of `_master.md`'s standing constraints apply unchanged (update
`R/EDI/vignettes/extending-edi.Rmd` — which replaced `extending-edi-r6.md`
on 2026-08-23 — on any extension-contract change; new kernels follow
the SEXP/RcppEigen conventions including unity-build group membership; new
classes go through `define_inference_class()`/`define_design_class()`; tick
TODOs in owning plans). Additionally, everything in this release must be
**additive**: default behavior with no new switches set must reproduce
1.0.0 results — since 2026-10-15 (owner decision D2) under the
numerical-equivalence rule in
`../new_feature_plans/v1_1_0/cross_platform_reproducibility.md → Release-to-release
equivalence`, no longer bit-for-bit — except where a plan explicitly documents a
default change (currently TODO-11's class deletion, pending its
deprecation decision; the exact-null, small-n exact and Zhang-kernel default changes formerly listed here (TODO-40, -41, -45) moved to `release_v1_2_0.md → TODO-24, -25, -29` and are restated there; and TODO-48's reproducibility work, whose TODO-3 tie tolerance changes p-values only where a tie was resolved by rounding, its plan's TODO-3, documented when it lands, and its plan's TODO-6 tie-tolerant optimizer comparisons, if measurement adopts them, which change seed-pinned draws of the optimizer designs once; and TODO-50's algorithm-audit items that move results beyond the equivalence tiers because the old algorithm was inaccurate (clamped normal tails, the 19-point φ grid, Monte Carlo CMH variance), documented per item when it lands; its derivative, start and NPMLE changes need no exception when they land inside the iterative-solver tier). TODO-4b is narrowed to measurement infrastructure
only in this release (`performance_profiling_and_upgrades.md →
TODO-132..135, 175`, all infrastructure-only, no gate needed); the
result-changing performance items formerly gated here
(`→ TODO-137/149/153/156`, each requiring opt-in or a documented default
change with re-justified equivalence tolerances) moved with the rest of
TODO-4b's remainder to `release_v1_2_0.md → TODO-11` on 2026-09-06 — that
file's own standing constraints restate this gate. TODO-9b's
`qubo_backend` defaults to `"none"`, which must reproduce 1.0.0's MILP → SA
results (allocations exact, per the equivalence rule); every external backend is opt-in and falls back to the
classical solver with a warning, never silently.

- [ ] TODO-157 (added 2026-10-25, owner decision at G4-C R4A of v1.0.5):
  **RMST randomization-bootstrap: per-draw tau, and a possible
  uncensored-only CI.** v1.0.5 refuses every
  `compute_rand_bootstrap_confidence_interval*` type for
  `InferenceSurvivalRestrictedMeanDiff` (the survival shift is a log-time
  ratio, not the RMST difference). Two follow-ups:
  - Per-draw tau: with the default horizon, each null draw recomputes tau as
    the smaller arm's maximum follow-up (~10 in R4 vs ~4 observed), so the
    studentized pivot's SE is ~1.85x too large. Hold tau at the observed
    value in every draw (fast kernel `fast_survival_stats.cpp` `rmst_tau` arg
    plus the R slow path). This also affects the rand-bootstrap p-value at
    delta = 0; measure its null rejection (5% CP rule) before and after.
    Needs a rebuild.
  - Uncensored-only CI (optional): with no censoring, the RMST difference at
    a fixed tau is the mean difference of z = min(y, tau), so the sharp null
    "z shifted by delta" is invertible. It needs its own statistic (the mean
    difference of the pre-truncated z, with no re-truncation and no tau
    recompute) and an additive transform, not the log path. Validate the
    coverage with an R4-style study before enabling. The censored case stays
    refused.
  - Pointer: `release_v1_0_5.md → G4-C batch failures, R4A`.
  - **Split 2026-11-10 (owner approval of the v1.0.6 triage):** the per-draw tau half moved to `release_v1_0_6.md → TODO-2`. This TODO keeps the uncensored-only CI half only.

- [ ] TODO-158 (added 2026-10-25, owner decision): **Split
  `ObservationalDesign` into `FixedObservationalDesign` and
  `SeqOneByOneObservationalDesign`.** Today the observational family
  (`ObservationalDesign`, `ObservationalDesignBlocks`,
  `ObservationalDesignMatching`) inherits `DesignFixed`, so the whole table
  and the observed `w` arrive in one `add_all_subjects_to_experiment()` call.
  There is no way to record subjects as they arrive. The sequential family
  cannot stand in: `add_one_subject_to_experiment_and_assign()` calls the
  design's own `assign_wt()` (`design_seq_one_by_one_abstract.R:218-235`), a
  randomization step.
  - Decided 2026-10-25 (owner): all three get the `Fixed` prefix and stay fixed designs; see [DECISION-v1.1.0-TODO-158](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-158).
  - Rename: `ObservationalDesign` → `FixedObservationalDesign`,
    `ObservationalDesignBlocks` → `FixedObservationalDesignBlocks`,
    `ObservationalDesignMatching` → `FixedObservationalDesignMatching`. Keep
    each old name as a deprecated alias for one release (warn once, same
    class object). Update the registry entries, docs, examples, tests and
    NEWS under the new names.
  - New: `SeqOneByOneObservationalDesign`, inheriting the sequential
    one-by-one base. It exposes a recording method,
    `add_one_subject(x_new, w_new)`, that stores the externally observed `w`
    with no draw, and a matching hook for `y`. `assign_wt()` errors with a
    clear message.
  - Capability flags: both classes answer FALSE to `supports_randomization_draw()`
    and `supports_resampling_replay()` (and keep the existing
    `supports_resampling()` behavior), so randomization and
    bootstrap-randomization inference stay blocked and asymptotic,
    nonparametric-bootstrap and Bayesian-bootstrap inference work unchanged.
  - Touch points to check first: `design_class_registry.R:81-83` (the
    `"none"` entries), `inference_all_abstract.R:~115` and `~1157` (flag
    reads), `design_component_registry.R`, `inference_suite.R`,
    `simulations_framework.R`, and the sequential evolving-schema tests,
    which may assume sequential means randomized. Run `trail callers` on
    `ObservationalDesign` with `--depth all` before editing. Also check the
    `InferenceKK*` classes, which may assume a sequential KK design.
  - Tests: a sequential-observational design fed the same rows as the fixed
    one gives identical asymptotic estimates and SEs; every randomization
    method errors with the standard message; the deprecated alias works and
    warns once; add the new class to the wiring and registry gates.
  - Out of scope: streaming or warm-start refits (separate decision).
- [ ] TODO-159 (added 2026-10-25, owner decision at G4-C R1 of v1.0.5):
  **Cloglog ordinal: anti-conservative likelihood tests at `~.`, and a
  conservative parametric-bootstrap p-value.** v1.0.5 null study
  (`InferenceOrdinalCloglogRegr`, Bernoulli, `diamonds`, beta_T = 0, 500 null
  datasets per cell, B = 151; rows in `~/edi_regen/r1_todo16_pboot_20261025T071458Z/`):
  - LR-bootstrap at `~.`: 41/499 = 8.2% (CP 6.0-11.0%). It still rejects too
    often, but less than the direct LR test (12.0%). That fits the known
    limitation already recorded for `~.` with many covariates (before 1.0.5
    all five model-based tests rejected 16% at `~.`, 6% at `~1`). `~1` is
    calibrated (5.2%). Bartlett at `~.` is 54/499 = 10.8% (CP 8.2-13.9%; `~1`
    5.6%), so the correction barely helps there
    (`~/edi_regen/r1_todo16_bartlett_20261025T150308Z/`).
  - Parametric bootstrap (`compute_param_bootstrap_pval()`) is too
    conservative: 14/500 = 2.8% at `~1`, 3/499 = 0.6% at `~.`. It won't
    produce false positives, but it will miss real effects. Look into why
    (null-distribution width; centering of the bootstrap statistic; whether
    it is a test of `delta = 0` on the right scale), then fix or document.
  - Also measure power at beta_T = 0.5 for both, and the small-n `~.`
    excess at a larger n (the R1 re-scope gated only `~1`).
  - Documented in v1.0.5: NEWS "Known limitations" and the
    `InferenceOrdinalCloglogRegr` Details.
  - **Triage 2026-11-10:** `release_v1_0_6.md → TODO-13` checks this first; a bug found there moves the fix to v1.0.6, otherwise it stays here.

- [ ] TODO-193 (added 2026-11-10, owner): **Native C++ tests for this release's core additions.**
  - Plan: `../new_feature_plans/v1_1_0/native_cpp_tests_v1_1_0.md`, the follow-on to `release_v1_0_6.md` TODO-15.
  - Every C++ addition to the `EDI_CORE_ONLY` core in this release lands with its `cpp_tests/` target in the same
    change.
  - Each target builds from a minimal source subset (the CLAUDE.md whitelist).

- [x] TODO-194 (added 2026-11-13, owner; built and closed 2026-11-14 by owner request): **Run `comprehensive_tests.R` in the cloud after each calibration campaign.**
  - Built 2026-11-14: `.github/workflows/comprehensive-study.yml` + `R/package_tests/cloud/`, dispatched by calibration's last
    wave; see the plan's Status block for what differs from the design. Not yet run on GitHub: the first campaign is the
    real check (runtime, runner speed vs local, audit results vs the local baseline).
  - Plan: `../new_feature_plans/v1_1_0/comprehensive_tests_cloud_campaign.md`.
  - Why: the calibration study simulates its data; `comprehensive_tests.R` is the only harness on real covariates,
    and it runs only on the owner's machine, with gitignored results.
  - The calibration campaign's last wave dispatches a `comprehensive-study.yml` campaign at the same commit, on
    free hosted runners, published under `comprehensive/<campaign>/` on the `calibration-results` branch.
  - Never a required check; not part of the pre-push hook.
  - Raw rows and logs are published xz-compressed on the results branch (about 20x and 29x, measured 2026-11-13).
  - Decided 2026-11-13 (owner): path-audit gate is a complete cloud campaign or local regeneration, whichever finishes first; see [DECISION-v1.1.0-TODO-194a](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-194a).
  - Decided 2026-11-13 (owner): 50 reps; see [DECISION-v1.1.0-TODO-194b](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-194b).
  - The final wave regenerates the path audits and runs `compare_path_audits.R` against the campaign's commit;
    that script's fixed 2-point tolerance becomes an FDR-controlled exact test (plan Design 5, Phase 3b).
  - Start with the plan's Phase 0 (measure cost and compressed sizes).
  - Done when: the plan's Phase 6 (first full campaign compared with the local baseline) is ticked.

- [ ] TODO-195 (added 2026-11-13, owner): **Weekly benchmark regression check on GitHub-hosted runners.**
  - Plan: `../new_feature_plans/v1_1_0/weekly_benchmark_regression_check.md`.
  - Weekly, compares the last successfully benchmarked commit with `main`, timing both on the same runner in
    alternating order, and fails only on a slowdown seen in both comparisons and not in the allowlist.
  - Owner rules: no published results (pass/fail, log and step summary only); fail only on a commit-to-commit
    regression; skip when no functional R or C++ line changed.
  - Does not replace the release gate G2 benchmark regeneration.
  - Implemented 2026-11-14 as a nightly job (`.github/workflows/nightly.yml`, `bench-build`/`bench`), baseline = newest
    release tag; see the plan's header for the differences from its weekly design.
  - Done when: the plan's Phase 4 (a known speedup or slowdown is detected in the right direction) is ticked.
- [ ] TODO-196 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `adjacent-cat-cr-logit-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **Pattern-compressed
  (count-weighted) likelihood for adjacent-category and continuation-ratio fits**
  - Add a grouped path to AdjacentCategoryLogitNegLogLik/hessian (fast_adjacent_category_logit.cpp) and route CR through
    fast_continuation_ratio_regression_weighted_cpp with pattern counts when distinct (x, y) rows G < n/2. Benchmark
    against the current path on treatment-only and one-binary-covariate designs, n in {50, 200, 1000, 2000}, K in {3,
    5, 7}, timing one randomization CI and one parametric-bootstrap run.
  - Done when: >= 1.5x on the treatment-only rows with b, ssq_b_1 and neg_loglik equal within 1e-10 and no fallback
    change for continuous X; or closed with the numbers.
- [ ] TODO-197 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `beta-regression-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **ZOIB Bayesian-bootstrap replicates:
  fast_beta_regression_weighted_cpp instead of formula betareg()**
  - In inference_proportion_zero_one_inflated_beta.R compute_estimate_with_bootstrap_weights, replace betareg::betareg
    (keep it and lm.wfit as fallbacks) with fast_beta_regression_weighted_cpp on the interior rows. Benchmark one
    Bayesian-bootstrap CI (B = 1000) at n in {100, 500, 2000}, p in {1, 5}, old vs new.
  - Done when: >= 1.5x on the CI with every replicate beta_hat_T within 1e-6 of betareg's on the same weights (and
    fallback rate not higher); or closed with the numbers.
- [ ] TODO-198 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `binary-glm-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **fast_logistic_regression[_with_var]
  wrappers: decide lbfgs vs irls default**
  - First confirm whether the "lbfgs" default at helper_glm_fit.R:852/923 is intentional. If not, A/B irls vs lbfgs on
    the wrapper callers (KK21 and KK21-stepwise designs, helper_glm_fit.R:2015) at n in {50, 200, 1000}, p = 2,
    including separated fixtures: wall clock per design run and KK21 match/weight equality.
  - Done when: switched with identical KK21 assignments (or explained differences) and >= 1.5x on the wrapper calls, or
    closed with the numbers and the inventory wording fixed either way.
- [ ] TODO-199 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `blocking-partition#43925959437.2`, see `audits/research_triage_drafts.md`): **DesignFixedOptimalBlocks: nonbimatch
  fast path when n == 2B**
  - In design_fixed_optimal_blocks.R solve_optimal_blocks, dispatch n == 2B to nbpMatching::nonbimatch on D (offset
    negatives) and convert pairs to block ids. Compare with the MILP at n in {8, 12, 16} (B = n/2) on euclidean, mahal
    and a custom dist.
  - Done when: objective equal to the MILP's within the nonbimatch integer-scaling tolerance on every fixture and >=
    1.5x per solve; or closed with the numbers.
- [ ] TODO-200 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `conditional-logit-matched-fit#43925959437.1`, see `audits/research_triage_drafts.md`): **Clogit reservoir logit:
  fast_logistic_regression_weighted_cpp with fixed_idx instead of glm.fit**
  - Replace both glm.fit calls in fit_clogit_reservoir_logit (full fit, Bayesian-bootstrap replicate and fixed-delta
    null refit) with fast_logistic_regression_weighted_cpp, fixing the treatment coordinate via
    fixed_idx/fixed_values, keeping glm.fit as a fallback and preserving the aliased-column drop. Benchmark one
    bootstrap CI and one LR CI inversion at KK sizes n in {50, 200, 1000}.
  - Done when: >= 1.5x with params and neg_loglik within 1e-6 of glm.fit on fixtures (incl. separated/aliased ones); or
    closed with the numbers.
- [ ] TODO-201 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `cox-ph-fit#43925959437.2`, see `audits/research_triage_drafts.md`): **KK strat-Cox: build the design-ladder rungs
  lazily**
  - Profile shared() in InferenceSurvivalKKStratCox over one randomization CI at n in {100, 500}, p in {2, 10}: share of
    time spent building rungs (inference_survival_KK_strat_cox.R:155-177) vs fitting. If material, generate each rung
    only after the previous fit is rejected.
  - Done when: >= 1.5x on shared() with bit-identical estimates on the KK strat-Cox fixtures; or closed with the profile
    numbers if ladder building is < 10% of shared().
- [ ] TODO-202 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `cumulative-link-ordinal-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **Weighted native kernels for
  the ordinal bootstrap surrogate (replace per-draw MASS::polr)**
  - Add a weights argument to fast_ordinal_{probit,cloglog}_regression_cpp (FixedOrdinalRegression already supports it)
    and route weighted_ordinal_bootstrap_surrogate_fit (globals.R:177) through the weighted C++ kernels for logistic,
    probit and cloglog, warm-started from the full-data fit; keep polr for cauchit (nonconcave) and as the failure
    fallback. Mind the cloglog sign convention (catalog F18, linpred_sign = 1). Benchmark per-draw time and treatment
    coefficient against the current polr path on the ordinal Bayesian-bootstrap fixtures at n in {50, 200, 1000}, K in
    {3, 5}, p in {1, 5}.
  - Done when: >= 1.5x per-draw speedup with coefficients equal to polr within 1e-6 relative (polr reltol), or closed
    with the numbers.
- [ ] TODO-203 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `cumulative-link-ordinal-mle#43925959437.5`, see `audits/research_triage_drafts.md`): **Cloglog ordinal: run the
  full-data multistart only when the primary fit fails a convergence certificate**
  - Gate .cloglog_full_data_multistart (inference_ordinal_cloglog.R:1) on a certificate of the primary fit (gradient
    norm plus PD Hessian, or the Newton decrement already used by ordinal_scale_guard.h), or replace it with a
    damped-Newton polish. A/B against the current always-on multistart on the cases that motivated it
    (test-cloglog-parametric-bootstrap-native-sign.R, test-ordinal-cloglog-lik-test-null-refit-multistart-reference.R,
    and the null-truth comprehensive rows) and time a randomization/bootstrap run at n in {50, 200, 1000}.
  - Done when: identical selected fits (NLL within 1e-8) on all those cases and >= 1.5x faster per fit, or closed with
    the numbers (keep the multistart if any case regresses).
- [ ] TODO-204 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `design-matrix-preprocessing#43925959437.1`, see `audits/research_triage_drafts.md`): **Correlation-threshold design
  ladder: one cor() per call and candidates cached per dataset**
  - Add a ladder helper that drops constant columns once, computes cor() once and returns the keep-set for every
    threshold; use it at the five ladder call sites, and cache the candidate list (cox_design_candidates,
    gee_predictors_df_candidates) by covariate key so BB replicates reuse it. Test that per-rung keep-sets equal the
    current drop_highly_correlated_cols output across the test corpus. Benchmark a Bayesian-bootstrap run of the KK
    GEE and KK LWA Cox classes at n in {100, 500, 2000}, p in {5, 20}.
  - Done when: identical keep-sets and estimates and >= 1.5x end-to-end on the BB run, or closed with the numbers.
- [ ] TODO-205 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `glmm-marginal-likelihood#43925959437.1`, see `audits/research_triage_drafts.md`): **Poisson GLMM: cluster-total
  (sufficient-statistic) form of the GH objective and Louis Hessian**
  - Rewrite PoissonGLMMObjective::operator(), hessian and the score/Hessian exports in fast_poisson_glmm.cpp to use
    per-group S_g, log Lambda_g (log-sum-exp) and A_g, so per-node work is O(G) and the beta blocks are one
    GEMV/crossprod with posterior-weighted e^eta; carry row weights into the group totals and reproduce the eta+b
    clamp at 700 or document its removal. A/B against the current kernel on the R8 accuracy grid (all.equal tol 1e-10
    on estimates and SEs) and time fits plus a BB run at n in {100, 500, 1000}, p in {2, 5, 10}, cluster sizes 2 and
    5, n_gh = 60.
  - Done when: >= 1.5x per fit with results equal within 1e-10, or closed with the numbers.
- [ ] TODO-206 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `grouping-and-level-coding#43925959437.1`, see `audits/research_triage_drafts.md`): **KK pair weights: grouped
  aggregation instead of a per-pair which() scan in every replicate**
  - Replace the vapply/which loop in kk_pair_and_reservoir_bootstrap_weights (globals.R:276) with a rowsum-based mean
    (NA weights excluded from both sum and count) or a pair-row index cached per design, and cache the pair extraction
    in build_combined_cpoisson_data across replicates. Test pair weights equal the old ones to 1e-12. Benchmark the
    helper alone and a Bayesian-bootstrap run of InferenceContinKKOLSOneLik and the KK cond-Poisson class at n in
    {100, 1000, 5000}.
  - Done when: identical results and >= 1.5x on the helper with a measurable end-to-end share, or closed with the
    numbers.
- [ ] TODO-207 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `jackknife-replicates#43925959437.1`, see `audits/research_triage_drafts.md`): **Closed-form exact jackknife for
  least-squares classes (mean difference, OLS, Lin, WLS)**
  - Add a per-class fast-path hook that computes delete-one-unit/cluster replicates by cross-product downdating
    (MacKinnon, Nielsen & Webb 2023, eq. 15), weighted for the Bayesian jackknife, falling back to the refit path (or
    non-estimable) when X'X - X_g'X_g is near-singular. Compare against the current refit jackknife and BCa on the
    continuous fixtures for unit, pair and cluster deletion at n in {50, 500, 2000}, p in {1, 5, 20}.
  - Done when: replicates equal the refit jackknife within 1e-10 relative and the jackknife/BCa call is >= 1.5x faster,
    or closed with the numbers. Coordinate with the v1.0.6 block-jackknife unit fix (SPBR) so both use the same unit
    resolver.
- [ ] TODO-208 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `likelihood-tests-null-refits#43925959437.1`, see `audits/research_triage_drafts.md`): **Cloglog null refit: second
  start only when the first fails a convergence certificate**
  - In both fit_null closures of inference_ordinal_cloglog.R (:194, :240), run fit_from(full_start) only when the first
    refit is NULL, non-converged, has max|score| > tol, or a non-PD observed information. Benchmark LR/score/gradient
    CI and param-bootstrap LR p-value wall time on the existing cloglog fixtures (n = 50, 200, 1000; prob_T 0.5 and
    0.2), and count how often the second start changes neg_loglik by > 1e-8 on the current code (the fixtures that
    motivated the multistart, ordinal_cumulative_link_null_refit_multistart.md). Coordinate with release_v1_1_0.md
    TODO-159.
  - Done when: the second start never wins by > 1e-8 on certificate-passing fits and the change gives >= 1.5x on the
    null-refit-heavy paths with p-values/CIs identical within tolerance; or closed with the counts if the second start
    does win.
- [ ] TODO-209 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `logrank-family-tests#43925959437.1`, see `audits/research_triage_drafts.md`): **Linear-statistic fast path for
  right-censored log-rank / Gehan-Wilcoxon randomization nulls**
  - Add compute_fast_randomization_distr to InferenceSurvivalLogRank and InferenceSurvivalGehanWilcox for right-censored
    data at delta = 0: compute pooled null scores once (Nelson-Aalen martingale residuals; Peto-Prentice weighted for
    Gehan) and evaluate all draws as one t(W) %*% m product, falling back to the current path for delta != 0 or
    general censoring. Benchmark compute_rand_two_sided_pval at n = 100, 500, 2000, r = 501 and 5001 against the
    per-draw path. Gate: estimates tolerance-equal (1e-12) to fast_logrank_stats_cpp / fast_gehan_wilcox_stats_cpp per
    draw on fixtures with ties, deaths tied with censorings, and a Bernoulli design with variable n_T. Implement
    together with the interval-censored version (release_v1_2_0.md TODO-22, audit TODO-11) if that lands first.
  - Done when: >= 1.5x with identical p-values within tolerance, or closed with the numbers.
- [ ] TODO-210 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `performance-autotuning#43925959437.1`, see `audits/research_triage_drafts.md`): **Tuning harness: paired-difference
  acceptance with adaptive stopping (catalog §12 TODO-12)**
  - In local_machine_tuning_harness.R (edi_tuning_interleaved_ab / _blocked_ab / _accept_candidate), analyze per-round
    paired differences with a seeded percentile-bootstrap CI (or Wilcoxon signed-rank), accept only when the CI clears
    the 5% band, and add pairs adaptively between a minimum and maximum. Self-check on seeded synthetic timings (true
    effects 0%, 3%, 10%, 30%; noise CV 5-20%): false-accept rate, power, and mean reps per cell vs the current median
    + 2*IQR rule; then one real tune_EDI_for_this_machine() run.
  - Done when: false accepts at a 0% effect fall at equal or fewer reps, or closed with the numbers.
- [ ] TODO-211 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `pvalue-combination#43925959437.2`, see `audits/research_triage_drafts.md`): **Tail-accurate p-value combination:
  Stouffer, min-p and CCT (catalog §11 TODO-7)**
  - Rewrite zhang_combine_exact_pvals's Stouffer branch as qnorm(p/2, lower.tail=FALSE) and 2*pnorm(abs(z),
    lower.tail=FALSE), its min-p branch as -expm1(2*log1p(-p)), and cct_combine_pvalues_full with the ACAT small-p
    branch (1/(p*pi) for p < 1e-15) and pcauchy(T, lower.tail=FALSE). Unit tests at p in {0.5, 1e-8, 1e-16, 1e-20,
    1e-300}: equal to the old code within 1e-12 relative for p >= 1e-6, and finite, nonzero and correct against Rmpfr
    references below. No speed benchmark needed (same cost).
  - Done when: the tests pass and the moved values are listed in NEWS.
- [ ] TODO-212 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `random-number-generation#43925959437.1`, see `audits/research_triage_drafts.md`): **Per-draw RNG setup cost in
  index-seeded kernels; widen seed_for_index past 32 bits**
  - Micro-benchmark RRng(seed_for_index(master, d)) construction plus first draw against the full per-candidate work in
    rerandomization_search_cpp (and the greedy/optimal/binary-match search loops) at n in {50, 200, 1000}, p in {2,
    10}. If setup is >= 30% of a candidate, prototype a counter-based child stream (Philox4x32-10 from Random123,
    BSD-3, or xoshiro256++ via SplitMix64) keyed by the 64-bit (master, index), keeping draw-index determinism and
    thread-count invariance (TODO-48 (2) tests).
  - Done when: a >= 1.5x win on rerandomization_search_cpp end-to-end with thread-count invariance tests green and the
    draw change documented, or closed with the setup-share numbers. The 32-bit truncation is fixed either way (owner:
    confirm the one-time seed-pinned draw change).
- [ ] TODO-213 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `weibull-aft-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **robust_survreg: deterministic data-driven
  starts before random jitter**
  - On the survival fixtures (lognormal, loglogistic, and Weibull when the C++ warm start fails), count survreg attempts
    per fit and wall-clock for the current rule vs (1) init omitted (survreg's own start), (2) intercept = mean log
    time and log-scale from residual SD, then (3) jitter scaled by |start| only as a last resort, at n = 50, 200,
    1000, p = 1-10.
  - Done when: >= 1.5x fewer attempts or time with estimates identical within 1e-6 where both converge, or closed with
    the numbers.
- [ ] TODO-214 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `zero-inflated-count-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **Skip sdreport on estimate-only
  weighted glmmTMB replicates (ZIP/ZINB/hurdle)**
  - Add se = !estimate_only at the two weighted glmmTMB call sites and time one Bayesian-bootstrap run (B = 200) per
    class at n = 100, 500, 2000, before and after; check parallel = 1 inside already-parallel replicate loops in the
    same run.
  - Done when: a >= 1.5x win with identical replicate estimates (tolerance 1e-10), or closed with the numbers.
- [ ] TODO-259 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `beta-regression-mle#44618445718.1`): **Use the cached observed Hessian when a beta (and ZOIB) refit is
  warm-started.** `optimize_fixed_likelihood` ignores `warm_start_fisher_info` on every path: the L-BFGS branch never
  forwards it (`_helper_functions_core.h` ~L1635) and `optimize_likelihood_newton` discards it (~L1460), so each
  warm-started bootstrap or randomization refit rebuilds curvature from scratch. Related: v1.1.0-TODO-197 and the
  catalog's v1.0.5 TODO-7 (Fisher-scoring polish); the same gap applies to every fitter routed through
  `optimize_fixed_likelihood`.
  - First decide whether to honour or document `warm_start_fisher_info` there. Then A/B warm-started beta refits on
    bootstrap and randomization paths: L-BFGS from cold curvature vs Newton steps seeded with the cached Hessian
    (refreshed after the first accepted step). Count function evaluations and wall time at n = 100-1000, p = 2-10.
  - Done when: the faster variant reaches the same MLE to tolerance with timings recorded and is wired in, or the item
    closes with the numbers.
- [ ] TODO-260 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44683751221, finding
  `weibull-aft-mle#44683751221.1`): **Weibull AFT: damped Newton first on the standardized scale.**
  Since v1.0.6-TODO-163, `fit_weibull_aft_with_column_scaling` (`R/EDI/src/fast_weibull_regression.cpp`) runs L-BFGS on
  the standardized design and then up to 5 Newton polish steps. With the conditioning problem removed, run the existing
  `newton_then_lbfgs` from the smart cold start instead, keeping L-BFGS only as Newton's fallback. New evidence for the
  catalog's v1.0.5 TODO-3 prototype; see also v1.1.0-TODO-213 and v1.1.0-TODO-63.
  - Benchmark Newton-first against L-BFGS + polish (iterations, wall time, failure rate) on `survival::colon` and the
    simulation DGPs, for `fast_weibull_regression_internal` and the left/interval-censoring variant.
  - Done when: estimates match the current fit to 1e-8 on the package_tests CSVs and the faster path is the default, or
    the item closes with the numbers.
- [ ] TODO-261 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `resampling-refit-loop#44618445718.1`): **Weibull bootstrap-randomization replicates: smart start and
  Newton polish.** `compute_weibull_rand_bootstrap_parallel_cpp` still runs L-BFGS from all-zero parameters (maxit 100,
  tol 1e-8) with no polish, while the observed fit (v1.0.6-TODO-163) uses a smart start plus Newton polish; the code's
  own comment says L-BFGS alone stops about 1e-3 from the optimum, so replicates and the observed statistic converge to
  different tolerances. Reuse `fit_weibull_aft_with_column_scaling` (or the in-file damped Newton) from
  `weibull_aft_start_or_legacy` on each replicate's standardized X. Pairs with v1.1.0-TODO-260.
  - Benchmark at EDI's BRT sizes for iteration count and NA-draw rate; check that the replicate beta_T at the observed
    data matches the observed fit to within 1e-8.
  - Done when: replicates reach the observed fit's tolerance with timings and NA rates recorded, or the item closes with
    the numbers.
- [ ] TODO-215 (added 2026-11-17, agent, owner request; opened for accepted calibration rows): **`InferenceIncidExtendedRobins`:
  owner revisit of the matched-design anti-conservatism (size about 0.15 at every n).**
  - v1.0.5-TODO-168 (closed) checked the kernel against the paper (Azriel, Krieger, Kapelner, arXiv:2607.05768,
    Sec. 2.3.2: Eq. 12 per-block Robins + Eq. 13) and recorded the owner ruling of 2026-10-28: published estimator,
    inherent at small blocks, fix not applied because it changes default output.
  - The allowlist-hygiene audit (PR #19, 2026-11-17) removed the 24 `calibration_study_accepted.csv` rows citing that
    closed TODO, so later campaigns would flag these cells again.
  - Decided 2026-11-17 (owner): the rows stay for now and cite this TODO; owner revisits later; see [DECISION-v1.1.0-TODO-215](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-215).
  - Cells: `DesignFixedBinaryMatch` and `DesignFixedMatchingGreedyPairSwitching`, prob_T 0.5, formulas `~.` and `~1`,
    n = 50 (52), 200, 1000, size and coverage (campaign 2026-11-15-e36c7710).
  - Done when: the owner either keeps the published estimator (record the ruling here, and the rows keep citing a
    permanent rationale the hygiene audit accepts) or changes it (then the rows go and the cells pass).

## Drafted from calibration campaign 2026-11-15-e36c7710 (review)

Drafted by `R/package_tests/calibration/triage_calibration_study.R` from the campaign's `summary/triage.csv`: one TODO per failing class x procedure x metric. Review each: edit, merge or delete it, and move kept ones into the implementation list.

- [ ] TODO-254 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedPoisson`'s `wald` fails its coverage gate; small n only: passes at the largest n.** 3 failing cell(s) (0 confirmed, 3 awaiting confirmation (campaign still running when drafted)) on 3 design(s): Fixed:Bernoulli@0.2, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:iBCRD@0.2; formulas ~., ~1; failing at n = 50 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Bernoulli@0.2, ~1, n = 50, null: coverage 0.855 vs level 0.9 (1000 replicates). It passes at the largest n, so this looks like a small-sample effect: fix it, or document the small-sample behaviour and accept the cells. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneBernoulli@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedPoisson/wald/coverage -->
- [ ] TODO-255 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceCountZeroInflatedPoisson`'s `wald` fails its null size gate; small n only: passes at the largest n.** 3 failing cell(s) (0 confirmed, 3 awaiting confirmation (campaign still running when drafted)) on 3 design(s): Fixed:Bernoulli@0.2, SeqOneByOne:Bernoulli@0.2, SeqOneByOne:iBCRD@0.2; formulas ~., ~1; failing at n = 50 (tested at n = 50, 200, 1000); effects null. Worst cell: SeqOneByOne:Bernoulli@0.2, ~1, n = 50, null: size 0.145 vs level 0.1 (1000 replicates). It passes at the largest n, so this looks like a small-sample effect: fix it, or document the small-sample behaviour and accept the cells. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type count --design 'DesignSeqOneByOneBernoulli@prob_T=0.2' --n 50 --effect null --only InferenceCountZeroInflatedPoisson --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: count/CountZeroInflatedPoisson/wald/size -->
- [ ] TODO-256 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`'s `score` fails its coverage gate; small n only: passes at the largest n.** 1 failing cell(s) (0 confirmed, 1 awaiting confirmation (campaign still running when drafted)) on 1 design(s): Fixed:BinaryMatch; formulas ~1; failing at n = 50 (tested at n = 50, 200, 1000); effects null. Worst cell: Fixed:BinaryMatch, ~1, n = 50, null: coverage 0.864 vs level 0.9 (1000 replicates). It passes at the largest n, so this looks like a small-sample effect: fix it, or document the small-sample behaviour and accept the cells. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedBinaryMatch' --n 50 --effect null --only InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: survival/SurvivalGLMMWeibullFrailtyLoggammaOneLik/score/coverage -->
- [ ] TODO-257 (added 2026-11-19, drafted by `triage_calibration_study.R` from calibration campaign `2026-11-15-e36c7710`; owner to review): **`InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik`'s `score` fails its null size gate; small n only: passes at the largest n.** 1 failing cell(s) (0 confirmed, 1 awaiting confirmation (campaign still running when drafted)) on 1 design(s): Fixed:BinaryMatch; formulas ~1; failing at n = 50 (tested at n = 50, 200, 1000); effects null. Worst cell: Fixed:BinaryMatch, ~1, n = 50, null: size 0.136 vs level 0.1 (1000 replicates). It passes at the largest n, so this looks like a small-sample effect: fix it, or document the small-sample behaviour and accept the cells. Reproduce: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedBinaryMatch' --n 50 --effect null --only InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md. Any calibration_study_accepted.csv row for these cells cites this TODO. <!-- triage: survival/SurvivalGLMMWeibullFrailtyLoggammaOneLik/score/size -->
- [ ] TODO-258 (added 2026-11-20, coordinator; owner decision on v1.0.6-TODO-232): **ZIP ridge detector.** At small n
  with continuous covariates in the zero-inflation formula the ZIP MLE often does not exist (a separated zero-part
  ridge). v1.0.6-TODO-232 added a sharpened-start candidate, but about 41 of 602 unflagged fits in the 1197-dataset
  sweep still stop at a lower interior local maximum without a warning (the limit is documented in the
  `InferenceCountZeroInflatedPoisson` roxygen). Detect the ridge directly: solve an LP for which zeros can be separated
  from every positive count, compare against the Poisson fit on the remaining rows, and flag (or return) the ridge fit.
  Sweep scripts: /tmp/claude-1000/t232/ and /tmp/claude-1000/sweep/ (may be gone; rebuild the sweep if so).
- [ ] TODO-262 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24, confirmation pending): **`InferenceSurvivalKKStratCoxPHOneLik`: gradient test oversized at n = 50 on KK21stepwise.**
  - One cell: SeqOneByOneKK21stepwise `~.` n = 50, size 0.146 (level 0.1). Triage category small-sample.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignSeqOneByOneKK21stepwise' --n 50 --effect null --only InferenceSurvivalKKStratCoxPHOneLik --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: confirmation decides the cell; if confirmed, fixed or accepted as small-sample with rows citing this TODO.
- [ ] TODO-263 (added 2026-11-21, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 24): **Null bias above 0.1 SD at n = 1000 in 17 class x procedure groups (reported, not gated).**
  The study reports `bias_sd_large_n` but never fails a cell on it; these are the groups over the 0.1 SD line at n = 1000.
  - `InferenceSurvivalRestrictedMeanDiff`: 22 cells, all at prob_T 0.2 (FixedBernoulli, FixedRerandomization,
    FixedBlocking, FixedOptimalBlocks, FixedOptimal, FixediBCRD, FixedGreedyDOptimal, SeqOneByOneSPBR, iBCRD, Bernoulli,
    RandomBlockSize); worst FixedBernoulli@0.2 `~.`: 0.185. The largest and most systematic: look first at the
    restriction time and the arm-specific KM tail at unequal allocation.
  - Eight proportion groups on SeqOneByOneSPBR@0.2 only, 0.105-0.120: PropQuantileRegr 0.12, PropFractionalLogit 0.119,
    AllSimpleAverageDiff 0.114, AllSimpleMeanDiffPooledVar 0.114, PropGCompMeanDiff 0.114, AllSimpleWilcox 0.106,
    PropBetaRegr 0.105, PropZeroOneInflatedBetaRegr 0.105. One design shared by unrelated estimators points at the
    design or the proportion DGP at prob_T 0.2 (check the SPBR treated share), not at the classes.
  - Survival: SurvivalStratCoxPHRegr 0.129 (3 cells: FixedGreedy@0.2, FixedGreedyDOptimal, SeqOneByOneUrn), SurvivalLogRank
    0.122 (4 cells: FixedGreedy@0.2, FixedGreedyDOptimal), SurvivalWeibullRegr 0.111 (3 cells: SeqOneByOneUrn,
    FixedGreedyDOptimal).
  - Others, one or two cells just over the line: IncidModifiedPoisson -0.105 and IncidLogBinomial -0.100
    (FixedRerandomization@0.2), ContinQuantileRegr 0.105 and ContinRobustRegr 0.103 (SeqOneByOneEfron), PropKKGLMM
    -0.101 (FixedBinaryMatch `~1`).
  - Most sit within MC error of 0.1 on 1000 reps; only RestrictedMeanDiff, StratCoxPHRegr and LogRank are clearly over.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type survival --design 'DesignFixedBernoulli@prob_T=0.2' --n 1000 --effect null --only InferenceSurvivalRestrictedMeanDiff --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: each group is explained (estimand mismatch with the DGP truth, design artefact, or a real bias) and
    either fixed or documented; re-check against the next campaign's `null-bias.md`.
- [ ] TODO-264 (added 2026-11-22, coordinator, owner request; found by calibration campaign 2026-11-15-e36c7710 (simulated at e36c7710), screen flags after wave 27): **`InferenceOrdinalKKCLMM`: null bias 0.217 SD at n = 1000 on KK14 (reported, not gated).**
  - Two cells, SeqOneByOneKK14 `~.` and `~1` n = 1000: bias 0.217 SD (line 0.1). No TODO covers it; compare
    v1.1.0-TODO-263 (the other null-bias groups).
  - Caveat: the campaign abandoned the OrdinalKKCLMM n = 1000 units on FixedBinaryMatch and KK14 after repeated shard
    timeouts (about 12 min per replicate), so this bias rests on the replicates that finished, which may be a biased
    subset (the slow fits). Re-measure on a full replicate set before investigating the estimator.
  - Repro: `Rscript R/package_tests/calibration/run_calibration_study.R --response-type ordinal --design 'DesignSeqOneByOneKK14' --n 1000 --effect null --only InferenceOrdinalKKCLMM --reps 1:200 --out-dir "$TMPDIR/cal_repro"`. Campaign summary: https://github.com/kapelner/EDI/blob/calibration-results/campaigns/2026-11-15-e36c7710/README.md.
  - Done when: the bias is re-measured on complete replicates, and explained, fixed or documented.
  - Status 2026-11-23 (coordinator): wave 29 of campaign 2026-11-15-e36c7710: 4 cells now, SeqOneByOneKK14 and SeqOneByOneKK21stepwise at n = 1000; both units were abandoned after shard timeouts (KK21stepwise in wave 29), so the caveat above applies to all four. Re-measure once v1.0.6-TODO-409 (planner fix) is pushed and those units complete.
- [x] TODO-265 (added 2026-11-23, coordinator, owner request; from the OrdinalKKCLMM shard timeouts in calibration campaign 2026-11-15-e36c7710): **`InferenceOrdinalKKCLMM` randomization test: find why its cost grows faster than n.** `InferenceOrdinalKKCLMM`'s randomization test costs about 870 s per replicate at n = 1000 against 2.7 s for Wald (13.5 s at n = 50, 55 s at n = 200: 5x the data from 200 to 1000 costs 16x), which made its calibration shards time out (the planner side is fixed separately in v1.0.6).
  - Each redraw refits the full CLMM, but the growth beyond the fit's own cost suggests extra per-draw work. First suspect:
    the KK matching (pairs / reservoir) being redone on every redraw instead of once per design; also check per-draw
    setup (model matrix, cluster ids) and the number of redraws B used at n = 1000.
  - Profile one replicate at n = 200 and n = 1000 on SeqOneByOneKK14 and FixedBinaryMatch (`Rprof` or the timing hooks);
    report the share of time in the refit vs everything else.
  - Done when: the per-draw cost is broken down, any redundant per-draw work is removed, and the fixes in the next three
    TODOs are ranked by expected speed-up.
  - See also v1.2.0-TODO-21 (`garthwaite_buckland_ci_search.md`): Robbins-Monro CI search. It does not speed up the p-value tracked here (one pass of redraws, no endpoint to search), but it is the candidate for this class's randomization CI, whose bisection repeats this per-draw refit cost at every step; this class is now listed in that plan's benchmark corpus. Any per-draw saving found here also cuts the CI's cost.
  - Status 2026-11-23 (agent): cost broken down; no package code changed. Measured on this machine, calibration DGP
    (null), r = 501 (the `compute_rand_two_sided_pval()` default; the harness passes no r, and no early stop is used for a
    standalone p-value), num_cores = 1:
    - n = 200 (SeqOneByOneKK14 / FixedBinaryMatch): ~0.25 s per redraw, 100-135 s per p-value. 92-94% is the native
      CLMM fit (one 5-start L-BFGS fit at eps_g = 1e-12, ~0.22 s); the Newton retry fired in 0 of 61 redraws. The rest is
      R: design matrix, group ids, the redraw's fixed-effects start (~2 ms), cache resets, gc (~2%). The KK match data is
      not recomputed per redraw (0.4%); nothing else redundant in R.
    - n = 1000: 4.0 s (KK14) / 5.7 s (FixedBinaryMatch) per redraw, 99% in the kernel. The L-BFGS fit is 1.0-1.4 s
      (linear in n), but its gradient norm (a sum over n) now exceeds `clmm_gradient_accept = 1e-4` in 35-65% of
      redraws, and each Newton retry costs 6-9 s because the kernel reruns all 5 starts with Newton (numerical
      Hessians): 70-73% of the time. That is the extra growth (16x for 5x n). The retry's eps_g does not matter
      (1e-12..1e-6: 7-8.5 s).
    - Fix found: run the retry from the L-BFGS point only. End to end at n = 1000: 2.9x (KK14), 2.45x
      (FixedBinaryMatch), 5.3x (Cauchit), identical p-values; n = 200 unchanged. Not implemented: it is a C++ change
      to the kernel's multistart guard, one related test shows the guard can matter (a loosened L-BFGS stuck at the
      sigma boundary), and `fast_ordinal_clmm.cpp` has another session's uncommitted v1.0.6-TODO-410 edits.
    - Ranking of the next three by expected speed-up at n = 1000: v1.1.0-TODO-267 (score statistic, ~1000x, changes the
      statistic) >> this TODO's retry fix (2.5x-5x, numerically equivalent on the calibration data) > v1.1.0-TODO-268
      (sequential stop, ~3x at the null, 1.7x under power, changes p-values) >> v1.1.0-TODO-266 (none; ruled out).
      The retry fix and the sequential stop multiply.
  - Decided 2026-11-23 (owner): (b) single-start Newton retry except at a far-from-stationary boundary, then (d) the kernel KKT polish (plan TODO-5); see [DECISION-v1.1.0-TODO-265a](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-265a).
  - Status 2026-11-24 (agent): both implemented (C++ `fast_ordinal_clmm.cpp` + hand-edited `RcppExports`, R
    `clmm_accept_fit()`; verified by `sourceCpp` swap, no relink: **the owner must rebuild** for it to be live). The
    kernel now polishes its multistart winner and judges convergence by the projected gradient (KKT at the sigma
    boundary), so the R retry no longer fires on n <= 200 calibration fits and on 10 of 160 at n = 1000 (was 35); when
    it does, it starts from the fitted point only. End-to-end randomization p-value, same seeds: n = 1000
    SeqOneByOneKK14 4.3x, FixedBinaryMatch 3.2x, Cauchit 2.5x (single fit 4-9 s -> 0.6-1.2 s); n = 200 1.1x-1.7x.
    Equivalence on 1,600 fits (n = 50 / 200 / 1000, four links, both formulas): estimate <= 4.9e-6, SE <= 1.6e-5,
    Wald p <= 5.4e-6; randomization p identical at n = 200 and 1000, but 5 of 80 differ at n = 50 (up to 0.039) because
    degenerate redraws that were `NA` now return values (and one tie flip). Details:
    `../bug_fix_plans/v1_0_5/clmm_sigma_collapse_false_convergence.md` "TODO-5 implementation record". Tests: new
    `test-ordinal-kk-clmm-newton-retry-single-start-unless-boundary.R`, KKT assertions added to
    `test-ordinal-kk-clmm-stationary-fit-kkt.R`; 38 related files pass except 3 pre-existing failures in
    `test-randomization-sequential-mc-pval-stopping-rule-reference.R` (same with the HEAD kernel; from the merged
    v1.2.0-TODO-207 "+1" p-value change). `python/tests/test_fast_ordinal_clmm.py` re-pinned from R; it still needs the
    pre-push Python build to confirm. NEWS entry under "Changes that alter results / Ordinal responses".
  - Decided 2026-11-24 (owner): accept that degenerate n = 50 redraws that used to be `NA` now return values; see [DECISION-v1.1.0-TODO-265b](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-265b).
  - Status 2026-11-24 (agent, owner request; re-measured A/B): **the kernel change's speed-up holds where it was
    measured (n = 1000, `~ .`), but the current code is 2.3-3x slower everywhere else, because of the 60-node
    Gauss-Hermite rule (v1.0.6-TODO-48, commit dd161678), which landed after this TODO's measurement.** Three arms, each
    its own R code with its own kernel (`sourceCpp` of the single kernel file swapped into the namespace, no relink):
    "old" = b9567dd0 (f27d8c00^; e36c7710 has the same kernel and only doc/assert edits in the CLMM R code), "new" = the
    working tree (= HEAD), and "new20" = the working tree with `KK_CLMM_N_GH` set back to 20 (the TODO-265 change alone).
    Calibration DGP (null), SeqOneByOneKK14 and FixedBinaryMatch, logit and Cauchit, `~1` and `~.`, n = 200 and
    1000, study reps 1-3, r = 21 with identical permutations in all arms, single-threaded (OMP/MKL 1), arms
    interleaved per data set (ABC / CBA), load average 1.0-3.3 (12 cores). Rand p-value time, median [range] over 3
    data sets, speed-up = old / arm:

    | n | design | link | formula | old (s) | new20 (s) | new (s) | new20 speed-up | new speed-up |
    |---|---|---|---|---|---|---|---|---|
    | 1000 | KK14 | logit | `~.` | 65.3 [23-96] | 20.1 [12-23] | 48.2 [24-50] | 3.3x [2.0-4.1] | 1.4x [0.96-1.9] |
    | 1000 | BinaryMatch | logit | `~.` | 93.7 [80-103] | 21.6 [22-26] | 53.6 [50-63] | 4.0x [3.7-4.4] | 1.6x [1.5-1.9] |
    | 1000 | KK14 | cauchit | `~.` | 32.9 [31-47] | 14.0 [14-16] | 36.2 [34-37] | 2.4x [2.2-3.0] | 0.96x [0.85-1.3] |
    | 1000 | BinaryMatch | cauchit | `~.` | 28.8 [23-51] | 13.7 [13-23] | 33.9 [31-54] | 2.1x [1.8-2.3] | 0.85x [0.74-0.95] |
    | 1000 | both | both | `~1` | 5.6-7.5 | 6.2-8.2 | 17.5-24.1 | 0.81-0.98x | 0.30-0.33x |
    | 200 | both | both | both | 1.3-6.5 | 1.3-6.4 | 3.3-14.3 | 0.89-0.97x | 0.38-0.43x |

    Single observed fit at n = 1000, `~.` logit (medians of KK14 and BinaryMatch): old 6.9-7.3 s, new20 1.0-1.15 s, new 2.4-2.65 s (`~1`: 0.26-0.41 s,
    0.29-0.40 s, 0.82-1.11 s). Newton retries per 63 redraws at n = 1000 (old / new20 / new): `~.` 29-34 / 0 / 0-1
    (old: all 5-start, 2.5-5.6 s each, 60-77% of its time); `~1` 0-3 / 2-13 / 8-15 (single start, ~0.07 s each with
    20 nodes). n = 200: retries 0-1 in every arm. So TODO-265's 2.5-4.3x was right for its comparison (old vs the
    kernel + retry change at 20 nodes), and TODO-269's measurement was also right for the code as it now is: what makes
    the current code slow is the 60-node rule, which costs 2.3-3x per fit in every regime (likelihood and gradient cost
    are linear in the node count). The kernel change alone is 2-20% slower where the old code had no retries to save
    (`~1`, n = 200): the extra objective evaluation, the tight L-BFGS polish and the Newton steps (numerical Hessians)
    whenever the projected gradient exceeds 1e-5; at n = 1000 `~1` one redraw fit (without retry) costs ~0.24 s old vs ~0.30 s
    new20. (TODO-269's `~1` A/B gave the old kernel the current R code, so both its arms ran 60 nodes: a kernel-only
    comparison, 1.7x on a loaded machine against ~1.2x here.)
    Results agree: same data and permutations in every arm (checked); old vs new20 estimate <= 9.4e-7, SE <= 3.4e-7,
    redraw estimates <= 2.2e-6; old vs new (60 nodes) estimate <= 7e-4 (Cauchit `~1`; the node count, not the kernel);
    randomization p-values identical in all 48 data sets for both arms when recomputed under one counting rule (the
    reported ones differ only by the v1.2.0-TODO-207 (1 + b)/(1 + B) change between b9567dd0 and HEAD). The installed EDI
    (built 2026-11-24 02:00) already has the new kernel (17-argument signature, same result as the source kernel).
    Likely fixes, not implemented (owner to choose): (1) run the multistart L-BFGS at 20 nodes and refine only the winner
    at 60 nodes (a warm-started polish), which should recover most of new20's speed while landing on the 60-node
    optimum; or adaptive (mode-centred) quadrature, which reaches the same accuracy with far fewer nodes for these
    2-member clusters; (2) for the remaining ~1.2x at `~1`, skip the kernel polish when the L-BFGS gradient is already
    below the R acceptance (1e-4) instead of the kernel's 1e-5, so the extra L-BFGS/Newton pass and the R retry do not
    both run. Scratch scripts: `bench.R`, `driver.sh`, `analyze.R` in the measuring session's scratchpad (temporary).
  - Status 2026-11-24 (agent; owner approved both fixes above): implemented in `fast_ordinal_clmm.cpp` only (no signature
    or `RcppExports` change; verified by `sourceCpp` swap, no relink: **the owner must rebuild**). (1) Coarse-to-fine
    quadrature: with `n_gh > 20` the L-BFGS variance multistart runs on 20 nodes, the coarse endpoint best under the
    60-node rule is refit on 60 nodes (the far-from-stationary boundary guard refits every endpoint), so the reported
    fit is still the 60-node optimum and v1.0.6-TODO-48's accuracy is kept (its all-links `ordinal::clmm` test passes).
    Adaptive quadrature was not chosen: it changes the objective (beyond D2, a new decision) and needs a new engine
    path, while the coarse stage already brings a fit to 1.1-1.5x the 20-node cost. (2) The polish runs only when the
    projected gradient exceeds the R acceptance `max(1e-4, eps_g)`, and `converged` uses the same bound, so no fit pays
    for both polish and R retry (0 retries in the A/B at n = 1000; HEAD 8-15 per cell at `~ 1`). Same A/B harness, a
    fourth arm, 48 data sets, r = 21, ABCD/DCBA, one core, load 1.0-3.5: rand p-value vs HEAD 1.4x-2.2x faster in every
    cell (n = 1000 `~ .` logit 2.0-2.2x, Cauchit 1.6-1.7x, `~ 1` 1.8-2.2x; n = 200 1.4-2.2x); vs 1.0.5 (b9567dd0):
    n = 1000 `~ .` logit 2.7-3.8x, Cauchit 1.4x faster, but `~ 1` at n = 1000 0.52-0.67x and n = 200 0.59-0.96x (the
    60-node refit's own cost; per redraw `~ 1` ~0.5 s vs 0.35 s at 20 nodes). Equivalence vs HEAD (D2): estimate <=
    1.2e-6, SE <= 3.0e-7, Wald p <= 2.9e-6, redraw estimates <= 3.9e-6, randomization p identical in all 48.
    `test-ordinal-kk-clmm-stationary-fit-kkt.R` drops its kernel-verdict `gradient_norm <= 1e-5` assertion (now 1e-4 by
    design; 14 of 48 fits were 1.1e-5..6.2e-5); 44 related test files pass (4,652 / 0). Python fixture
    (`test_fast_ordinal_clmm.py`, n_gh 20) reproduced bit for bit from R; the pytest run itself needs the pre-push
    Python build. Docs: class roxygen + `man/InferenceAbstractKKOrdinalCLMM.Rd` (checkRd clean), NEWS (speed-up
    figures corrected for the 60-node rule), plan `clmm_sigma_collapse_false_convergence.md` follow-up section.
    Cross-reference: v1.0.6-TODO-48.
- [x] TODO-266 (added 2026-11-23, coordinator, owner request; from the OrdinalKKCLMM shard timeouts in calibration campaign 2026-11-15-e36c7710): **`InferenceOrdinalKKCLMM` randomization test: start each redraw's refit from the observed-data fit.** `InferenceOrdinalKKCLMM`'s randomization test costs about 870 s per replicate at n = 1000 against 2.7 s for Wald (13.5 s at n = 50, 55 s at n = 200: 5x the data from 200 to 1000 costs 16x), which made its calibration shards time out (the planner side is fixed separately in v1.0.6).
  - Warm-start every redraw from the observed-data fit, never from the previous redraw: the owner ruling of 2026-11-19
    (v1.0.6-TODO-61) bans chaining warm starts across redraws, not a fixed start from the observed fit. Check that the
    multimodality guards (`multistart_nonconcave_likelihoods.md`) still hold, since the CLMM likelihood is not concave.
  - Done when: redraw results match cold starts within the D2 numerical-equivalence rule (or the difference is
    documented), with the measured speed-up at n = 200 and 1000.
  - Status 2026-11-23 (agent): ruled out with evidence, no code change. Redraws already start from their own data (the
    fixed-effects cumulative-link MLE on the redraw, plus the kernel's log-sigma starts), never chained. Starting from
    the observed fit instead reaches the same maximum on every redraw tried (|d neg-loglik| <= 2e-10; 100 redraws at
    n = 200 on KK14, FixedBinaryMatch and Cauchit, 20 at n = 1000 on KK14 and FixedBinaryMatch, plus 100 + 20 with an
    interior sigma, model `~ x1`), but is 3-25% slower; the share of redraws needing the Newton retry barely moves (n = 1000: 8 vs 8 of 20 on
    KK14, 8 vs 11 on FixedBinaryMatch).
  - Decided 2026-11-24 (owner): ruled out, no code change; see [DECISION-v1.1.0-TODO-266](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-266).
- [x] TODO-267 (added 2026-11-23, coordinator, owner request; from the OrdinalKKCLMM shard timeouts in calibration campaign 2026-11-15-e36c7710): **`InferenceOrdinalKKCLMM` randomization test: a statistic that does not need a full refit per redraw.** `InferenceOrdinalKKCLMM`'s randomization test costs about 870 s per replicate at n = 1000 against 2.7 s for Wald (13.5 s at n = 50, 55 s at n = 200: 5x the data from 200 to 1000 costs 16x), which made its calibration shards time out (the planner side is fixed separately in v1.0.6).
  - Candidates: a score statistic evaluated at the null fit (computed once; each redraw only re-evaluates the score under
    the permuted assignment), or a one-step Newton update from the observed fit. Either changes the test statistic, so
    it changes results: put it behind an option, or follow the release rule for default changes.
  - Done when: a no-refit statistic is implemented and its null size checked against the current one (calibration
    cells at n = 50, 200, 1000), with the speed-up measured.
  - Status 2026-11-23 (agent): prototyped in scratch (not in the package), default unchanged. Statistic: the score for
    beta_T at the null fit, T(w) = sum_i w_i r_i, where the null CLMM is fit once (treatment coefficient fixed at 0) and
    r_i is the posterior mean over unit i's pair intercept of d log p(y_i | eta) / d eta (same 20-node Gauss-Hermite
    rule; checked against a numeric derivative). A redraw is one dot product. Cost per p-value (r = 501): 0.05 s at
    n = 50 (now 31 s), 0.17 s at n = 200 (now ~120 s), 0.55-0.87 s at n = 1000 (now ~2,000-2,900 s here; ~870 s in the
    campaign). Null size at alpha = 0.05 (calibration DGP): KK14 n = 50 0.050 (300 reps), n = 200 0.037 (300), n = 1000
    0.070 (400; 0.100 on reps 1-150, 0.052 on 151-400); FixedBinaryMatch n = 200 0.067 (300), n = 1000 0.065 (200);
    Cauchit KK14 n = 200 0.037 (300). On three n = 1000 data sets where the score test rejected, the current statistic
    also gave p = 0.059 / 0.020 / 0.020 (r = 101), so that excess is not the score statistic's (it is either noise or
    a property of the data/design shared with the current test; see v1.1.0-TODO-264's n = 1000 caveat). Agreement with
    the current statistic on the same data (KK14 n = 50, 40 null reps): cor(p) = 0.997, max |dp| = 0.06; at the power50
    effect (60 reps, same data) power 0.43 vs 0.37 now. Calibration cells at n = 50, 200, 1000 for the option are still
    to run once it is implemented.
  - Decided 2026-11-24 (owner): ship as an opt-in, `compute_rand_two_sided_pval(type = "score")`, default unchanged; see [DECISION-v1.1.0-TODO-267](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-267).
  - Status 2026-11-24 (agent): implemented (R only) in `inference_ordinal_KK_clmm_abstract.R`: public
    `compute_rand_two_sided_pval()` on the CLMM base dispatches `type = "score"` to private
    `compute_clmm_score_rand_pval()` and otherwise calls the shared `InferenceRandCI` method as before (which still
    rejects any other `type`); private `clmm_score_residuals()` (null fit via `fixed_idx`, cached). Same draws
    (`generate_permutations(r)` or `permutations`), +1 rule, tie tolerance, alternatives and finite-draw minimum
    (`compute_two_sided_randomization_pval_from_t0s()`); the null distribution is cached under a `type=score|` key.
    Only `delta = 0`, `transform_responses = "none"`, `args_for_type = NULL`; a failed null fit gives `NA` with reason
    `kk_clmm_score_null_fit_unavailable`. Other classes reject it (generic "type dispatch is only supported for
    incidence outcomes", or an unused-argument error). Package timing, r = 501, score vs default (default estimated
    from r = 101 at n = 200, r = 21 at n = 1000): n = 50 0.08-0.15 s vs 40-53 s; n = 200 0.28-0.47 s vs 155-258 s;
    n = 1000 1.0-2.0 s vs 558-1,169 s (KK14, FixedBinaryMatch, Cauchit; 250x-650x). Null size (300 reps each, alpha
    0.05): KK14 n = 50 0.043, n = 200 0.037; FixedBinaryMatch n = 200 0.057; Cauchit KK14 n = 200 0.037 (prototype
    0.050 / 0.037 / 0.067 / 0.037; the differences are the +1 rule merged since). Tests: new
    `test-ordinal-kk-clmm-score-statistic-randomization-pval.R` (23 expectations: score = numeric derivative for all four
    links, p-value = hand computation on the same w_mat for all three alternatives, seeded and separately cached,
    default unchanged, refusals); 39 related files 1,504 pass, 0 fail. Roxygen + hand-edited
    `man/InferenceAbstractKKOrdinalCLMM.Rd` (`tools::checkRd` clean), NEWS "New features".
  - CI: not wired (owner correction 2026-11-24: not ruled out, decide later). These classes refuse every
    randomization CI today (`EDI_ORDINAL_MODEL_COEFFICIENT_INFERENCE_CLASSES`), and the default p-value at delta != 0
    shifts the integer levels (1..4 -> 1, 1.5, ..., 4.5), not the latent log-odds coefficient. The private score
    function takes `delta` so a CI search can pass `type` through.
  - Decided 2026-11-24 (owner): (a) + (d), no randomization CI, and the default p-value refuses `delta != 0` (done); routes (b) and (c) recorded in `ordinal_model_coefficient_randomization_confidence_intervals.md`; see [DECISION-v1.1.0-TODO-267b](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-267b).
- [ ] TODO-268 (added 2026-11-23, coordinator, owner request; from the OrdinalKKCLMM shard timeouts in calibration campaign 2026-11-15-e36c7710): **`InferenceOrdinalKKCLMM` randomization test: fewer redraws at large n.** `InferenceOrdinalKKCLMM`'s randomization test costs about 870 s per replicate at n = 1000 against 2.7 s for Wald (13.5 s at n = 50, 55 s at n = 200: 5x the data from 200 to 1000 costs 16x), which made its calibration shards time out (the planner side is fixed separately in v1.0.6).
  - Use fewer redraws when n is large (or a sequential Monte Carlo stopping rule, which EDI already has for
    randomization p-values), so the p-value resolution is kept where it matters (near alpha) and spent less elsewhere.
  - Done when: the redraw count or stopping rule is chosen, documented, and its effect on size and on the p-value's Monte
    Carlo error at alpha = 0.05 measured.
  - Status 2026-11-23 (agent): measured, default unchanged. EDI's sequential-MC stop works for this class unchanged, but
    only the randomization CI turns it on; a standalone p-value always draws all r. With the CI-search defaults
    (r = 501, batch 45, >= 100 draws, 99% band, threshold 0.05), simulated under the null: 34% of the draws, size 0.0536
    both ways, 1 of 20,000 decisions differs (0 of 20,000 at a 99.9% band); under 32-80% power: 51-59% of the draws, 0
    of 5,000 differ. The p-value is the prefix's (SD of the change 0.06 under the null). On the class (KK14, n = 200):
    98-135 s -> 25-37 s per p-value. Enabling it changes every p-value away from alpha, so it is an owner decision.
  - Owner decision pending: [DECISION-v1.1.0-TODO-268](PENDING_DECISIONS.md#DECISION-v1.1.0-TODO-268) (turn on the sequential-MC early stop for the standalone randomization p-value, and for which classes?).
- [ ] TODO-269 (added 2026-11-24, agent, owner request; follows v1.1.0-TODO-265 and v1.1.0-TODO-267): **Calibration study: run the KK CLMM score-statistic randomization test (`rand_score`), and an opt-in replicate cap for slow units.** [DECISION-v1.1.0-TODO-267](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-267) shipped `compute_rand_two_sided_pval(type = "score")` as an opt-in and rejected making it the default "until a full calibration run shows no power loss" (its revisit condition: a calibration run of `type = "score"` with size and power at least as good as the refit statistic). The study had no way to produce that run.
  - Done (2026-11-24, agent), for the NEXT campaign: tier 1 has a seventh, p-value-only procedure `rand_score`
    (`CAL_STUDY_TIER1_METHODS` / `CAL_STUDY_TIER1_PVAL_ONLY` in `calibration_study_common.R`), declared in
    `CAL_EXTRA_PVAL_PROCEDURES` (`calibration_fast_tier_common.R`): run only for the four `InferenceOrdinalKKCLMM*`
    links, as a copy of each `rand` task (same formula, right after it), calling `compute_rand_two_sided_pval(type =
    "score")` with the method's default r (501, as `rand`) and the design's cached draws (the same ones `rand` used;
    checked: one permutation-cache entry per design). The default `rand` still runs. Capability check: a task is added
    only if the installed EDI's class (or an ancestor) has the private `compute_clmm_score_rand_pval`, so an EDI
    without it (e.g. the campaign 2026-11-15-e36c7710 commit) is skipped cleanly. Downstream: raw rows and stats carry it
    as `inf_procedure = "rand_score"` (its own cell; no cell-key change, so older campaigns analyze unchanged); the roster
    counts it in `n_size`, not `n_cov`; the gate, convergence study, triage and plots take it as a variant of `rand`
    (new `EDI_INFERENCE_PROCEDURE_VARIANTS` + `inference_procedure_base_label()` in `R/EDI/R/inference_procedure_regime.R`:
    finite-sample, every convergence-registry layer of `rand`; kept out of `EDI_INFERENCE_PROCEDURE_REGIME`, which must
    stay the sentinel list); size and power only, no coverage; README "Procedures" / "Data" text. The planner's cost
    model needs no change (a class's cost sums `fit_secs` over its procedures; `rand_score` costs 0.4-0.7 s per row at
    n = 50 and ~6 s at n = 1000, against ~100 s and ~1,100-1,400 s for `rand`).
  - What runs where (`.github/workflows/calibration-study.yml`): from the campaign's PINNED commit: EDI itself, the roster
    (`build_calibration_study_roster.R`), the shards (`run_calibration_study.R` and the `calibration_study_common.R` /
    `calibration_fast_tier_common.R` / `calibration_common.R` / `calibration_study_stats.R` it sources), the wave merge
    and the balance backfill's data generation, and the acceptance list. From the run's own commit (`main`): the
    planner (`plan_calibration_study.R` + `calibration_study_plan_common.R` + `calibration_study_stats.R` +
    `calibration_study_costs.csv`), the analysis, convergence, triage, plots, design comparison, balance summary, README
    rendering, and the regime / convergence registry (`inference_procedure_regime.R`, sourced from the checkout). So
    `rand_score` starts with the first campaign pinned at a commit that has this change (the next monthly one); the
    running campaign 2026-11-15-e36c7710 never produces it, and its analysis is unchanged (checked on its real
    `stats/` files: same plan and wave with the cap off).
  - Default `rand` cost with the v1.1.0-TODO-265 kernel (measured 2026-11-24, this machine, `load_all(compile = FALSE)`
    of the working tree, src/EDI.so built after the kernel change, one replicate, single core, machine shared with an
    EDI install and other sessions): see the Status line below. It is well above ~3 min per replicate
    at n = 1000, so a cap was added (next bullet). For comparison the running campaign (old kernel, GitHub runners)
    measured 1,595-1,870 s per replicate (logit) and 996-1,066 s (Cauchit) at n = 1000; nearly all of it is `rand`
    with `~ .`.
  - Done (2026-11-24, agent), opt-in: planner slow-unit cap `--slow-unit-cap-secs S --slow-unit-cap-reps R` (default
    S = 0, off; R = 300): a screening unit whose estimated single-core cost per replicate (the planner's own, measured
    on the campaign once it has `--min-measured-reps`) exceeds S runs at most R replicates. Confirmation units are never
    capped. `plan.csv` gets `rep_cap` / `rep_cap_secs` (only when something is capped), the `--plan-only` call in the
    workflow now passes `--campaign-dir` so it writes the same plan, and the campaign README names the capped units.
    Workflow env `SLOW_UNIT_CAP_SECS: '0'`, `SLOW_UNIT_CAP_REPS: '300'`. Test:
    `testthat_bulk/test-calibration-slow-unit-replicate-cap.R`.
  - Dry run on the running campaign (real `ledger.csv`, `planned.csv`, `roster.csv`, `stats/`, `summary/confirm_cells.csv`
    from `origin/calibration-results` 0dcff7de) with S = 300, R = 300: 21 units capped, all null at n = 1000: the 16
    `InferenceOrdinalKKCLMM*` units (4 links x KK14 / KK21 / KK21stepwise / FixedBinaryMatch), 4 `InferenceCountKKGLMM`
    units (already 500 done) and `InferenceIncidCMH` on DesignFixedGreedy (379 s per replicate, already 1,000 done).
    11 of them are already past 300, so their extra replicates stay in the statistics and only the plan's target moves.
    It skips 2,213 replicates still to run (Probit and Cloglog at n = 1000 not started, 200 each; Cauchit two at 0,
    two at 400-429; logit 2-24 each): about 2,000 x ~1,000-1,900 s, i.e. ~600-1,000 core-hours, ~10-16 h of the
    campaign's 64 cores. Plan: reps_total 15,265,000 -> 15,260,300, units done 6,477 -> 6,478, shards left after this
    wave 2,544 -> 2,350; 80 of the wave's 256 shards change. It also lowers those cells' replicate counts (size MC SD at
    300 replicates 0.0126 vs 0.0097 at 500).
  - Status 2026-11-24 (agent), measured default `rand` cost per replicate (both formulas, wald + rand + rand_score),
    SeqOneByOneKK14, rep 1 (the study's seed), single core, this machine under load 4-11 of 12 (an EDI install and other
    sessions): n = 1000: logit 3,166 s (`rand` `~1` 1,012 s, `~.` 2,110 s), Probit 3,342 s, Cauchit 2,484 s; n = 200:
    logit 521 s, Probit 555 s, Cauchit 642 s. `rand_score` 0.5-2 s per row at n = 200 and 4-8 s at n = 1000. Cloglog and
    FixedBinaryMatch were stopped unfinished (too slow to wait for). This machine is slower than a GitHub runner (wald `~1`
    at n = 1000: 2.0-2.9 s here against 0.23-0.44 s in the campaign), so on runners expect very roughly 3-7x less, i.e.
    ~8-17 min per replicate at n = 1000: far above ~3 min, hence the cap. Lead, not verified: a same-process A/B at n = 1000
    (KK14 logit, r = 21, current R code, e36c7710 kernel swapped in by `sourceCpp`, no relink) gave `~1` 0.88-0.90 s per
    redraw with the old kernel against 1.54 s with the new one, while `~.` took 4.2-4.6 s per redraw with the new kernel
    (the old kernel's `~.` fit is rejected as non-stationary by the current R acceptance, so no `~.` comparison). That is
    not the 2.5-4.3x end-to-end speedup v1.1.0-TODO-265 reported on its data; worth re-measuring on an idle machine
    before relying on the new kernel to bring the campaign's n = 1000 cost down.
  - Status 2026-11-24 (agent): re-measured side by side; both measurements were right. The kernel change is 2.1-4.0x
    faster at n = 1000 `~.`, but the 60-node quadrature rule (v1.0.6-TODO-48) makes the current code 2.3-3x slower at
    `~1` and at n = 200 and only 0.85-1.6x at n = 1000 `~.`; see the 2026-11-24 A/B status under v1.1.0-TODO-265.
  - Decided 2026-11-24 (owner): (d), cap only the planner's slow-list classes, on now (300 s / 300 replicates); planner flag `--slow-unit-cap-scope` (default `slow_classes`) and workflow `SLOW_UNIT_CAP_SECS: '300'` done; see [DECISION-v1.1.0-TODO-269](COMPLETED_DECISIONS.md#DECISION-v1.1.0-TODO-269).
  - Tests: new `test-calibration-kk-clmm-score-randomization-procedure.R` (task insertion, capability check, the call,
    registry variant, roster counts, a real n = 50 replicate on the same draws) and
    `test-calibration-slow-unit-replicate-cap.R`; a `rand_score` case in `test-calibration-gate-regime-levels.R`; the
    roster check in `test-calibration-class-major-order.R` counts every p-value-only procedure. All 12 calibration and
    registry test files pass (dev EDI via `load_all(compile = FALSE)`).
