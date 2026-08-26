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

## Scope rule

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
  decided **yes** 2026-08-18). `expanded_estimate_report.md` was
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

Designs and orchestration: `multi_arm_designs.md` (TODO-1..5; TODO-6 already
shipped in 1.0.0), `design_fixed_greedy_pair_switch_merge.md`,
`design_seq_many_by_many.md` (added 2026-08-17, user decision — the new
sequential many-by-many design family: `DesignSeqManyByMany` abstract plus
Bernoulli/CRD/Blocking/Rerandomization/Atkinson concrete classes),
`sequential_inference.md` (research scoping — may produce a decision to
defer implementation to 1.2; the scoping itself is in scope).

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
- [ ] TODO-4: **Kernel/perf lane** (`_master.md` Phase 4 remainder; parallel
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
- [ ] TODO-6: **Response-type track** (`_master.md` Phase 5B order):
  `nominal_… → TODO-2 (Stage 1)` + `rank_choice_… → TODO-2 (Stage 1)`
  (spliced: admit `nominal` once); `nominal_… → TODO-3..4`;
  `rank_choice_… → TODO-3` (and `→ TODO-4` under its own sub-decision);
  `semi_continuous_… → TODO-2`, `→ TODO-6`, `→ TODO-3..5`;
  `multivariate_… → TODO-2..4`; `compositional_… → TODO-5` then
  `→ TODO-2..4` (vector storage last among scalar-adjacent types);
  `longitudinal_repeated_measures_… → TODO-5` then `→ TODO-2..4` (Stage 1
  extracts the clustered-fit core from `KKGEE`, so it follows 1.0.0's
  Phase 1D.2).
- [ ] TODO-7: **Censored-response track** (`_master.md` Phase 5C order):
  `censored_continuous_response.md → TODO-1..` (its TODO-1 generalizes the
  Design-layer bounds schema; everything downstream keys off it), then
  `censored_count_response.md → TODO-1..`, then
  `betaregscale_duplication.md → TODO-1..` (reuses the censored-quantile
  machinery).
- [ ] TODO-8: **Multi-arm track** (`_master.md` Phase 5D):
  `multi_arm_designs.md → TODO-1` (design side; the 1.0.0 hierarchy work
  supplies the capability metadata), `→ TODO-2`, `→ TODO-3`, `→ TODO-4`
  (coordinate with TODO-6's multivariate orchestration layer — same shape),
  `→ TODO-5` (demand-gated).
- [ ] TODO-9: **GPU track** (if TODO-1.9 said yes; `_master.md` Phase 5E):
  `gpu_optimizations.md → TODO-7` (backend/build design) then `→ TODO-2..5`,
  each merge gated by `→ TODO-6`'s benchmark matrix.
- [ ] TODO-9b: **Quantum / QUBO track** (if TODO-1.9b said (a) vignette+hook
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
- [ ] TODO-11: **Greedy-design merge**:
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
- [ ] TODO-12: **Interval-censored second wave** (if TODO-1.10 said yes):
  the NPMLE/Turnbull + stratified-Cox icenReg delegation work per
  `interval_censored_survival_response_type_report.md`, tracked as new
  TODOs in a reopened/new owning plan (the original
  `interval_censored_survival_response.md` is closed in
  `../finished_features/` — do not reopen it; open a fresh implementation
  plan).
- [ ] TODO-13: **Sequential inference scoping**:
  `sequential_inference.md` — run the scoping against the now-shipped
  1.0.0 public accessors; output is either a set of implementation TODOs
  (then decide 1.1.0 vs. 1.2) or an explicit defer note in that plan.
- [ ] TODO-14: **Landscape refresh**: `response_types_landscape_report.md →
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
- [ ] TODO-15: **Sequential many-by-many design family**:
  `design_seq_many_by_many.md → TODO-1..10` — its TODO-1 decision batch
  (Atkinson rule, bootstrap shape, threshold schedule) can join this file's
  TODO-1 sitting; the implementation is additive and independent of every
  other track (it needs only the 1.0.0 shallow design hierarchy), so it may
  run in parallel with TODO-5..8 any time after v1.0.0 ships. Note its
  TODO-2 extracts shared ingestion logic from the frozen
  `DesignSeqOneByOne$add_one_subject()` path — behavior-preserving under
  golden test, per the additive constraint below.
- [ ] TODO-15d: **Survival quantile regression** (added 2026-08-26):
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
- [ ] TODO-15c: **`dead` → `uncensored` rename** (added 2026-08-19, user
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
