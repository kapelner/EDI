# Release Scope: v1.2.0 — Performance, Kernels, and Engines

> **Depends on:** `release_v1_1_0.md`. Release index over plans in
> `../new_feature_plans/`; not new work of its own. (Global ordering: see
> `../new_feature_plans/_master.md`.)

Rewritten 2026-08-27 (user decision: the 1.x backlog is split
thematically into 1.1.0 inference quality / **1.2.0 performance &
engines** / 1.3.0 design theory / 1.4.0 response & data extensions;
2.0.0 remains the architecture release). Rule for all 1.x releases:
improvements on the current codebase plus simple additions on the
existing architecture and the six scalar response types; every default
reproduces the prior release. Since 2026-10-15 (owner decision D2)
"reproduces" means numerical equivalence per
`../new_feature_plans/v1_1_0/cross_platform_reproducibility.md → Release-to-release
equivalence`, not bit-for-bit.

**Theme.** Everything that makes existing classes faster or replaces an
R/Fortran dependency path with an exact-parity native kernel, plus the
one engine-level design refactor (the greedy merge) that later design
work builds on. No new statistical functionality.

## In scope (by plan)

`ols_distr_kernel_fwl.md` (added 2026-08-30; `→ TODO-1..5`; see `TODO-9`
below) — FWL per-replicate algebra for the OLS randomization kernel, gated on
v1.1.0's wiring of that kernel.

`kk14_incremental_covariance.md` (added 2026-08-30; `→ TODO-1..5`; see
`TODO-10` below) — O(p²)-per-subject running covariance for the sequential
KK14 matching design, replacing O(t·p²) recomputation.

- `quantile_regression_cpp_kernel_spec.md` — Barrodale-Roberts simplex
  port of `quantreg::rq.fit(method = "br")` and the `nid`/`iid` sandwich
  SEs, `use_rcpp` on all quantile classes (incl. the 1.1.0 count-QR and
  1.4.0 survival-QR classes once they exist).
- `ordinal_gee_cpp_kernel_spec.md` — native ordinal GEE kernel replacing
  `multgee::ordLORgee` in `InferenceOrdinalKKGEE`.
- `robust_regression_perf_optimization_spec.md` — bootstrap-loop
  allocation and warm-start work for the M/MM-regression classes.
- `cold_starts.md` — smart cold-start strategies across the optimizer-
  based kernels.
- `design_fixed_greedy_pair_switch_merge.md` — merge `DesignFixedGreedy`
  + `DesignFixedGreedyDOptimal` into `DesignFixedGreedyPairSwitch` (class
  consolidation only: `DesignFixedGreedy`'s unequal-arm support shipped in
  `release_v1_0_5.md → TODO-186`, and the planned swap-delta rederivation
  proved unnecessary); **soft-deprecation only**
  (aliases + warnings for the two old names); the hard deletion is
  `release_v2_0_0.md → TODO-7`. This is the engine that 1.3.0's unequal-
  allocation and objective-extension plans extend.
- `parallel_fork_cluster_test_safety.md` — fully closed (6/6); moved 2026-11-11 to
  `../finished_features/v1_0_0/` (closed 2026-08-26, before the v1.0.0 tag).
- `arm_hardware.md` — AArch64/Apple Silicon first-class targeting,
  compiler-target detection, Accelerate/BLAS dispatch, and portable fallback
  behavior.
- `intel_hardware.md` — Intel AMX/matrix-engine detection and size-gated GEMM
  dispatch, sharing the architecture-neutral dense-linear-algebra backend
  with the ARM plan.
- `memory_side_improvements.md` — NUMA placement, first-touch allocation,
  huge-page advice, HBM/Xeon Max handling, and portable stubs when OS/runtime
  capabilities are unavailable.

**Moved in from v1.1.0, 2026-09-06 (lighten-1.1.0 pass, user decision) —
the exploratory/measurement-first and consumer-gated half of that
release, none of it needed to ship v1.1.0's inference-quality theme:**

- `performance_profiling_and_upgrades.md` (§8 remainder, `→
  TODO-136..172, 174, 176..179`; see `TODO-11` below) — everything past
  the measurement infrastructure that stayed in v1.1.0 (`→ TODO-132..135,
  175`, needed there to benchmark that release's own speed claims):
  generated-code audits, the vectorized-exp/log and adaptive-Gauss–Hermite
  levers, end-to-end/R-layer profiling, parallelism/BLAS tuning, roofline.
- `more_simd_optimization.md`, `fixed_size_eigen_small_p.md`,
  `lto_reevaluation.md`, `memory_layout_row_major_irls.md` (the four
  build-tuning lanes that consume the profiling program's audits; see
  `TODO-12..15`).
- `count_quantile_regression.md` (see `TODO-16`) — moved beside this
  release's native quantile-regression kernel rather than shipping ahead
  of it.
- `ordinal_kk_gee_bayesian_bootstrap.md`,
  `ordinal_stereotype_logit_bayesian_bootstrap.md`,
  `ordinal_adjacent_category_logit_bayesian_bootstrap.md` (see `TODO-17`)
  — native weighted refits that should share machinery with this
  release's ordinal GEE kernel.
- `full_test_coverage.md` (see `TODO-18`) — pure test/CI-plumbing with no
  dependency on anything; runs whenever convenient.
- `save_load_api.md → section E` (see `TODO-19`) — Inference-object
  serialization; persistence infrastructure, off-theme for v1.1.0's
  inference-quality release.
- `multistart_nonconcave_likelihoods.md`'s remainder (see `TODO-20`) —
  the no-documented-failure kernels (GLMM/LMM/frailty, ZOIB, stereotype
  logit, copula/dependent-censoring survival, ordinal cauchit, bisquare);
  the documented-failure tranche (ZINB/ZIP/hurdle-NegBin, beta
  regression) stayed in v1.1.0 as `release_v1_1_0.md → TODO-17s`.
- `nonconcave_optimizer_techniques.md` (see `TODO-202`): profile grids,
  continuation from the concave limit, saddle and null-versus-full checks,
  bounded variance parameters and trust-region Newton for the nonconcave
  likelihoods (added 2026-11-16, owner request); composes with TODO-20
  and TODO-21.
- `trust_region_and_bounded_optimizer_engines.md` (see `TODO-203`): two
  new `optimization_alg` engines, trust-region Newton and bounded L-BFGS
  (added 2026-11-16, owner request); engines for TODO-202.
- `algorithm_ab_testing_framework.md` and its two harness-gated Prototype
  items, `garthwaite_buckland_ci_search.md` and
  `em_algorithm_zero_inflated_mixtures.md` (see `TODO-21`) — each is
  "win uncertain, validate first" exploratory work, the same character as
  the profiling lane above. `algorithm_choice_audit.md` itself (the
  survey; no code) stayed in v1.1.0 since it costs nothing and one of its
  Adopt verdicts (Brent) is already there.
- The 2026-10-09 sweep's speed-only drop-ins (`TODO-22`) and its
  harness-gated items (`TODO-23`), both from `algorithm_choice_audit.md`
  (added 2026-10-15, user decision). Its items that win on both speed and
  accuracy are in `release_v1_1_0.md → TODO-50`.

## Implementation TODOs (dependency order)

Ticked in owning plans; this list is the index.

- [ ] TODO-1: **Quantile-regression kernel**
  `quantile_regression_cpp_kernel_spec.md → TODO-1..6` (LP solver →
  weighted → SEs → R integration → parity suite → audit rows).
- [ ] TODO-2: **Ordinal GEE kernel** `ordinal_gee_cpp_kernel_spec.md →
  TODO-1..5`.
- [ ] TODO-3: **Robust-regression perf**
  `robust_regression_perf_optimization_spec.md → TODO-1..4` (profile
  before SIMD).
- [ ] TODO-4: **Cold starts** `cold_starts.md → TODO-2..14`.
- [ ] TODO-5: **Greedy engine merge** `design_fixed_greedy_pair_switch_merge.md
  → TODO-1..10` — TODO-2's `pair_mode` investigation first (its
  relationship to `DesignFixedMatchingGreedyPairSwitching` decides how
  1.3.0's unequal-allocation plan handles matched pairs); deprecation
  shims, not deletions.
- [x] TODO-6: Move `parallel_fork_cluster_test_safety.md` to
  `../finished_features/`. Done 2026-11-11 (owner): now
  `../finished_features/v1_0_0/parallel_fork_cluster_test_safety.md`.
- [ ] TODO-7: **Release mechanics** per `release.md`.
- [ ] TODO-8: **Architecture-specific CPU and memory engines**
  `arm_hardware.md → TODO-1..` (AArch64/Apple/Graviton/Grace detection and
  dispatch), `intel_hardware.md → TODO-1..` (AMX capability checks and GEMM
  thresholds), and `memory_side_improvements.md → TODO-1..` (NUMA/HBM/huge
  pages). Extract shared detection, dispatch, benchmark, and override logic
  once; retain scalar/portable fallbacks and require benchmark evidence before
  changing defaults.

- [ ] TODO-9: **OLS randomization kernel FWL rewrite** (added 2026-08-30,
  user decision): `ols_distr_kernel_fwl.md → TODO-1..5`. Rewrites the
  per-replicate algebra of `compute_ols_distr_parallel_cpp`
  (`src/ols_distr_parallel.cpp:60-103`): hoist the Cholesky of `X_cᵀX_c`
  and `y_res = My` once; per replicate only a masked sum for the numerator
  `w_bᵀy_res`, one masked column sum plus one O(p²) triangular solve for
  the denominator `w_bᵀMw_b` (which cannot be hoisted — permuting `w`
  changes its residual), then `num/den + δ`. O(np + p³) with pivoted QR and
  six heap allocations → O(np + p²) with none. Same estimator to floating
  point; rank guard on `w_bᵀMw_b ≈ 0` replaces ColPivQR's `rank()`.
  Expected 5–10× on the kernel. **Depends on**
  `ols_randomization_distr_cpp_wiring.md` (`release_v1_0_5.md → TODO-3`,
  moved 2026-09-23 from `release_v1_1_0.md → TODO-17p`)
  — the kernel is never executed until that lands. Optional TODO-4/5 cover
  the bootstrap sibling (multinomial-weight form) and Lin.
- [ ] TODO-10: **Sequential KK14 incremental covariance** (added 2026-08-30,
  user decision): `kk14_incremental_covariance.md → TODO-1..5`. Per
  arriving subject, `DesignSeqOneByOneKK14$assign_wt()` recomputes from
  scratch on all previous subjects: `compute_all_subject_data_cpp` (copy +
  varying-column scan + rank-revealing QR, O(t·p²)), `var(X_prev)`
  (O(t·p²)), then `solve()` (O(p³)) — O(n²·p²) over a run, plus an O(n²·p)
  per-`t` cache. Maintain the centred scatter matrix incrementally (Welford
  form, O(p²) per subject; the naive `Σxxᵀ − t·x̄x̄ᵀ` is rejected because the
  code already notes `diag ~ 1e6` covariate scales), track varying columns
  and rank monotonically so the QR runs only on change, and keep a
  reservoir-only `X_prev`. Expected 5–10× on a sequential run at `n = 1000`,
  growing with `n`; KK21 shares the `compute_all_subject_data()` path and
  benefits too. Sherman–Morrison on the inverse is explicitly out of scope
  (the regulariser changes every step; O(p³) is negligible at `p ≤ 20`) —
  and the class's unused `morrison` argument is Morrison & Owen threshold
  calibration, not Sherman–Morrison. Tolerance-equal; match decisions at
  exact distance ties are a documented reproducibility change.

- [ ] TODO-11: **Performance profiling & upgrades lane — remainder**
  (moved from `release_v1_1_0.md → TODO-4b` on 2026-09-06, lighten-1.1.0
  pass, user decision): `performance_profiling_and_upgrades.md` §8 →
  TODO-136..172, 174, 176..179; run in the plan's own "Suggested order":
  1. generated-code audits — `→ TODO-167, 168, 166` (instruction mix,
     compiler optimization reports, `llvm-mca`/OSACA/uiCA on the hot loops);
  2. the large levers — `→ TODO-136, 137` (vectorized exp/log via libmvec
     *without* `-ffast-math`) and `→ TODO-153` (adaptive Gauss–Hermite);
  3. end-to-end and R-layer — `→ TODO-158, 177, 173, 159, 160, 161` (this
     decides whether further kernel work moves user-visible time at all);
  4. parallelism and BLAS — `→ TODO-147, 148, 174, 176, 149, 150` —
     ideally alongside `tune_EDI_for_this_machine()`'s policy tables;
  5. `→ TODO-171` (roofline — decides where to stop), then the remainder
     as the measurements dictate: `→ TODO-138..146, 151, 152, 154..157,
     162..165, 169, 170, 172, 178, 179`.
  Bare-metal sub-batch (§8.0.2/8.0.3): `→ TODO-143` (`perf c2c`/`perf
  mem`), `→ TODO-171`, the Intel PT option of `→ TODO-132` (measurement
  infrastructure item; already done in v1.1.0, this is the bare-metal
  extension), and the *published* numbers for `→ TODO-147/148` run in one
  rented `c7i.metal-48xl` session; everything else runs on the dev box.
  Every fix follows the document's "root cause → fix → correctness →
  paired ABBA/BAAB benchmark" standard and this repo's
  targeted-compile-only rule; no timing number is cited anywhere without
  a measurement behind it. **Additive-constraint gates** (restated from
  `release_v1_1_0.md`'s standing constraints, which this item inherited
  when it moved): `→ TODO-137` (libmvec, ≤4 ulp result differences) and
  `→ TODO-153` (adaptive quadrature, changes GLMM numerics at tolerance
  level; since 2026-10-21 also the scheduled accuracy fix for the fixed-node
  GLMM error found under `release_v1_0_5.md → TODO-31`, with a
  `glmer(nAGQ=25)` before/after gate defined in that entry) need no exception when their measured differences fall inside
  the numerical-equivalence tiers
  (`../new_feature_plans/v1_1_0/cross_platform_reproducibility.md →
  Release-to-release equivalence`, since 2026-10-15); otherwise each ships
  either opt-in (configure flag / fit argument) or as an explicitly
  documented default change; `→ TODO-156`
  (Monte-Carlo early stopping) ships **opt-in only**; `→ TODO-149`
  (non-R RNG streams) changes draws under `set.seed()` and must be opt-in
  or documented as a default change. Everything else in this item ships
  no user-facing change and needs no gate. Exit criterion: every one of
  `→ TODO-136..179` has either a measured entry or a "measured and
  dropped" note, and `benchmark_model_fits.md` has been re-run.
  - See also (research triage, 2026-11-19): Adaptive GH with exact AQ gradient (Stringer 2024) for ordinal GLMM/CLMM (`clmm-ordinal-mixed-fit#43925959437.2`).
  - See also (research triage, 2026-11-19): Adaptive or pseudo-adaptive GH for the 20-node logistic/clogit/engine and 7-node hurdle GLMMs (`glmm-marginal-likelihood#43925959437.2`).
  - See also (research triage, 2026-11-19): Normal-equations LLT with ColPivQR fallback for OLS start values (`mle-starting-values#43925959437.1`).
  - See also (research triage, 2026-11-19): Anytime-valid betting (Fischer-Ramdas) stopping for standalone randomization p-values (`randomization-null-distribution#43925959437.1`).
  - See also (research triage, 2026-11-19): Lambert-W closed-form-mode adaptive GH (LAGHQ) for the Weibull normal frailty (`survival-frailty-copula-mle#43925959437.2`).
- [ ] TODO-12: **More SIMD optimization lane** (moved from
  `release_v1_1_0.md → TODO-4c` on 2026-09-06): `more_simd_optimization.md
  → TODO-1..7`. Premise: power users compile from source, so runtime ISA
  dispatch is moot and the work is making the compiler actually vectorize
  the hot loops. Consumes TODO-11's diagnostics (opt-report sweep,
  fast-math-subset/libmvec test, Eigen-vectorization audit, `.row(i)`
  classification, GLM-objective branch-free layout — `→ TODO-168/137/
  136/144/154`) and owns only the implementation work not already
  numbered there: `→ TODO-7` (flag-only `-fopenmp-simd`) → `→ TODO-1`
  (`__restrict` sweep) → `→ TODO-2` (wires TODO-11's TODO-137 result into
  `configure`) → `→ TODO-3` (aligned `Map` copies) → `→ TODO-4`
  (split-search SoA) → `→ TODO-5` (branch-free split-search comparisons)
  → `→ TODO-6` (float32 for split ranking, gated on a ranking-equivalence
  test). **Additive-constraint gate:** `→ TODO-6` ships opt-in or with
  re-justified tolerances; `→ TODO-2` inherits TODO-11's TODO-137 gate;
  `→ TODO-1, 3, 4, 5, 7` are bit-for-bit or flag-only.
  - See also (research triage, 2026-11-19): Vectorize the fused score + X'WX loop (SIMD reduction hint or Eigen dot) (`gram-matrix-accumulation#43925959437.1`).
- [ ] TODO-13: **Fixed-size Eigen specializations for small `p`** (moved
  from `release_v1_1_0.md → TODO-4d` on 2026-09-06):
  `fixed_size_eigen_small_p.md → TODO-1..5`. Compile-time-`p` dispatch
  for the `p×p` IRLS/Newton algebra; gated on its own `→ TODO-1`
  microbenchmark (drop if whole-fit gain < 10%). Consumes TODO-11's
  TODO-155 audit of which decompositions run at which sizes. Bit-for-bit
  with the dynamic path or ships behind a flag.
- [ ] TODO-14: **LTO re-evaluation** (moved from `release_v1_1_0.md →
  TODO-4e` on 2026-09-06): `lto_reevaluation.md → TODO-1..4`. Re-measures
  `EDI_NATIVE_LTO=1` under the current toolchain via TODO-11's TODO-135
  protocol, writes down the flip rule (no kernel regresses beyond noise
  **and** geometric-mean gain > 5%). Deliverable is a dated decision
  line, not necessarily code.
- [ ] TODO-15: **Memory layout — column-major `X` under row-wise IRLS**
  (moved from `release_v1_1_0.md → TODO-4f` on 2026-09-06):
  `memory_layout_row_major_irls.md → TODO-1..4`. Consumes TODO-11's
  TODO-144 `.row(` classification; owns the uniform mechanism (preferring
  the weight-vector + `rankUpdate` form over row-major copies) and the
  policy paragraph.
- [ ] TODO-16: **Count quantile regression** (moved from
  `release_v1_1_0.md → TODO-15e` on 2026-09-06):
  `count_quantile_regression.md → TODO-1..N` (implementation plan not yet
  written) — `InferenceCountQuantileRegr` plus
  `InferenceCountKKQuantileRegrIVWC`/`OneLik`, Machado & Santos Silva
  (2005) jittered `rq()` with `B`-averaged point estimates and
  single-jitter-draw bootstrap/randomization refits. Natural `use_rcpp`
  candidate once TODO-1's kernel lands; does not depend on it to ship.
- [ ] TODO-17: **Ordinal Bayesian-bootstrap completions** (moved from
  `release_v1_1_0.md → TODO-17g/17h/17i` on 2026-09-06): restore native
  weighted refits, replacing surrogates, for three ordinal classes —
  `ordinal_kk_gee_bayesian_bootstrap.md` (the primary
  `multgee::ordLORgee` estimating equations and matched/reservoir
  clustering), `ordinal_stereotype_logit_bayesian_bootstrap.md` (native
  stereotype-logit estimator), and
  `ordinal_adjacent_category_logit_bayesian_bootstrap.md` (native
  adjacent-category likelihood, replacing the cumulative-logit
  surrogate). Each enables its registry capability only after draw-level
  parity and calibration tests. Separately owned plans sharing this
  release lane because they guard different estimators and capabilities.
- [ ] TODO-18: **Full test coverage triage** (moved from
  `release_v1_1_0.md → TODO-17m` on 2026-09-06, reframed as a rolling
  non-gating track): `full_test_coverage.md → TODO-1..10` — take
  Codecov's line coverage from 64.79% into the high 90s. Phase 1 builds a
  tracked `coverage_gap_registry.csv`; Phase 2 targets files at literal
  0.00%; Phase 3 works the broadly-thin remainder by weighted opportunity
  (`(1 - coverage) * lines_of_code`); Phase 4 adds a coverage-floor CI
  gate — the only piece that should wait for the bulk of Phase 2/3.
  Pure test-writing/CI-plumbing; no dependency on anything else in this
  or any release; run whenever convenient.
- [ ] TODO-19: **Inference-object serialization** (moved from
  `release_v1_1_0.md → TODO-17r` on 2026-09-06): `save_load_api.md →
  section E (E-1..E-7)`. Make a fitted `Inference` object a supported
  `saveRDS()`/`readRDS()` unit so expensive resampling state survives a
  session, mirroring the v1.0.0 Design-side audit: reload-contract
  decision (E-1), private-field/component `owns_state` audit (E-2, run
  after every 1.1.0 item that adds `Inference`-side state — including
  TODO-17y's `ModelSelection` provenance object — has landed), XPtr
  liveness handling (E-3), version stamp + self-initializing fields (E-4),
  cache-persistence semantics (E-5), round-trip tests (E-6), and
  documentation (E-7).
- [ ] TODO-20: **Multistart — remainder tranche** (moved from
  `release_v1_1_0.md → TODO-17s` on 2026-09-06): apply
  `multistart_nonconcave_likelihoods.md`'s shared infrastructure (built
  in v1.1.0 for the documented-failure kernels) to the kernels with no
  documented failure: GLMM / LMM / frailty marginal likelihoods, ZOIB,
  stereotype logit, Clayton-copula and dependent-censoring survival,
  ordinal cauchit (the `fast_ordinal_glmm.cpp` 5-point sweep is
  unconditionally bit-for-bit and may land with either tranche), and
  Tukey-bisquare robust regression (additionally starts from a converged
  Huber fit instead of OLS). Same bit-for-bit contract as the v1.1.0
  tranche.
- [ ] TODO-21: **Algorithm-choice A/B harness + its two Prototype items**
  (moved from `release_v1_1_0.md → TODO-17t/17u/17v` on 2026-09-06):
  `algorithm_ab_testing_framework.md → TODO-1..4` — paired timing,
  problem-class-specific correctness/equivalence metrics, a
  fixed-in-advance decision rule requiring a genuine win on at least one
  documented regime plus zero accuracy regression anywhere; no default
  changes without a human reading the report. Then, gated on it:
  `garthwaite_buckland_ci_search.md → TODO-1..4` (Robbins–Monro CI search
  — opt-in alternative to bisection for randomization/bootstrap CI
  bounds; not offered for `release_v1_0_5.md → TODO-2`'s (moved 2026-09-23
  from `release_v1_1_0.md → TODO-17o`) tier-1
  classes, whose `p(δ)` is O(r) arithmetic after that item lands and
  cannot be beaten by a stochastic-approximation driver; A/B corpus
  stratified on `supports_additive_delta_shift()`) and
  `em_algorithm_zero_inflated_mixtures.md → TODO-1..5` (EM-then-Newton
  hybrid start for ZINB/ZIP, TODO-6/ZOIB deferred until TODO-2/3 validate
  the pattern; composes with TODO-20's multistart as one more
  deterministic start).
  - See also (research triage, 2026-11-19): Keep conservative CRN bisection (Glazer-Stark); narrow or downgrade Robbins-Monro plan (`monte-carlo-test-inversion-ci#43925959437.3`).
  - Benchmark case (2026-11-23, coordinator, owner request): `InferenceOrdinalKKCLMM`'s randomization test refits a CLMM on every redraw, about 870 s per p-value at n = 1000 (13.5 s at n = 50, 55 s at n = 200) in calibration campaign 2026-11-15-e36c7710, so its randomization CI (a bisection with a full redraw set per step) multiplies that cost by every step. That is the refit-heavy, non-affine statistic the 2026-11-19 research triage proposes keeping in this plan's scope: add it (and `InferenceOrdinalKKCLMMCauchit`, about 500 s per p-value at n = 1000) to the A/B corpus, comparing Robbins-Monro against the conservative common-random-number bisection. The p-value cost itself is tracked in v1.1.0-TODO-265..268.

- [ ] TODO-202 (added 2026-11-16, owner request): **Optimizer techniques for
  the nonconcave likelihoods.**
  - Plan: `../new_feature_plans/v1_2_0/nonconcave_optimizer_techniques.md`.
  - The techniques are: a profile grid over the nuisance parameters (T1),
    continuation from the concave limit (T2), a post-convergence
    saddle-point check (T3), bounded natural-scale variance and dispersion
    parameters (T4), a null-versus-full fit check (T6) and trust-region
    Newton (T7). EM (T5) is TODO-21.
  - Classes are chosen from the registry's `likelihood_concave`,
    `boundary_parameters`, `parameter_layout` and `derivatives` fields.
  - T1 and T2 become extra deterministic starts in TODO-20's multistart
    helper. T7 is promoted only on an A/B harness (TODO-21) win.
  - The phase 1 checks (T3, T6) change nothing on fits that pass. They
    could be pulled into v1.1.0 next to `release_v1_1_0.md → TODO-17s` if
    the owner wants them sooner.
  - The 2026-11-16 ZIP randomization finding turned out to be a warm-start
    bug, not an optimizer failure; it is `release_v1_0_6.md → TODO-6`.
  - Concave classes stay bit-for-bit.

- [ ] TODO-203 (added 2026-11-16, owner request): **Two new optimizer
  engines: trust-region Newton and bounded L-BFGS.**
  - Plan: `../new_feature_plans/v1_2_0/trust_region_and_bounded_optimizer_engines.md`.
  - Adds `optimization_alg = "trust_region"` (handles indefinite
    Hessians and cannot stop at a saddle) and `"lbfgsb"` (box constraints;
    a boundary MLE stops at its bound and is reported in `at_bound`
    instead of a false `converged = TRUE`).
  - No new dependency: `LBFGSpp::LBFGSBSolver` ships in RcppNumerical
    0.7.0 and in the LBFGSpp v0.4.0 the Python build pins.
  - Bounds come from the registry's `parameter_layout` and
    `boundary_parameters`. A new registry field `optimization_algs`
    lists the engines each class accepts.
  - Opt-in only. Defaults change per class only after TODO-21's A/B
    harness report and a calibration comparison.
  - Provides the engines for TODO-202's T4 and T7; native tests under
    TODO-37.

- [ ] TODO-22 (added 2026-10-15, user decision): **Algorithm audit:
  speed-only drop-ins** — `algorithm_choice_audit.md → TODO-10, -11, -18,
  -19, -21, -29, -34`. Same answer, less time; no new options.
  - **TODO-10:** Atkinson null draws via Schur complement / per-t
    precompute (same RNG consumption).
  - **TODO-11:** interval-censored log-rank / Wilcoxon randomization
    tests compute the pooled-NPMLE scores once (~r× fewer NPMLE solves;
    gate: reproduce `ictest` on fixtures).
  - **TODO-18:** presorting in survival resampling (bit-identical).
  - **TODO-19:** replicate-loop economics (memoized param-bootstrap batch,
    `rq.fit` instead of formula `rq()` with one method for point fit and
    replicates, C++ cpoisson-combined and Lin/KK OLS batch kernels,
    parallel BRT draw materialization). Coordinate the `rq.fit` part with
    `quantile_regression_cpp_kernel_spec.md` above.
  - **TODO-21:** the existing C++ block / cluster draw kernels instead of
    `replicate(randomizr::…)`, plus a C++ urn kernel. **Changes
    seed-pinned draws once** (documented default change; refresh fixtures).
  - **TODO-29:** low-priority linear algebra (whitened Mahalanobis, drop
    the redundant QR, LDLT, cached GH rule, SYRK Cox Hessian).
  - **TODO-34:** longest-first (LPT) scheduling in `run_all_inference`.
  - **Gate:** the existing tests and the numerical-equivalence tiers
    (exact for TODO-18's presorting, which is bit-identical by
    construction), except TODO-21 (documented draw change) and TODO-11
    (tolerance-equal to `ictest`).
  - See also (research triage, 2026-11-19): Weighted C++ cpoisson-combined Newton instead of R optim BFGS (`conditional-logit-matched-fit#43925959437.2`).
  - See also (research triage, 2026-11-19): Breslow hazard and R Cox NLL via one reverse cumsum per stratum (`cox-ph-fit#43925959437.1`).
  - See also (research triage, 2026-11-19): Pooled interval-censored NPMLE solved once per randomization test (icFIT= or wlr_trafo scores) (`interval-censored-npmle#43925959437.3`).
  - See also (research triage, 2026-11-19): Weighted Greenwood RMST SE by sort + reverse cumsum instead of O(n*D) vapply (`kaplan-meier-rmst#43925959437.1`).
  - See also (research triage, 2026-11-19): One weighted C++ KM sweep shared by weighted median, weighted RMST and RMST SE (`kaplan-meier-rmst#43925959437.2`).
  - See also (research triage, 2026-11-19): Interval-censored log-rank: pooled NPMLE scores once per test, faster single NPMLE solve (`logrank-family-tests#43925959437.2`).
  - See also (research triage, 2026-11-19): Arm-wise Gram plus two small LDLT solves for Lin's per-draw randomization fit (`ols-fit#43925959437.1`).
  - See also (research triage, 2026-11-19): Whiten once (LLT, relative ridge) then Euclidean pair loop for Mahalanobis (`pairwise-distance-matrix#43925959437.2`).
  - See also (research triage, 2026-11-19): Batched C++ random-block-size draw kernel with dense stratum ids (`permuted-block-randomization#43925959437.1`).
  - See also (research triage, 2026-11-19): Cluster-total collapse of Weibull-frailty GH likelihood and gradient to O(np + GK) (`survival-frailty-copula-mle#43925959437.1`).
- [ ] TODO-23 (added 2026-10-15, user decision): **Algorithm audit: items
  gated on the A/B harness** — `algorithm_choice_audit.md → TODO-4, -5, -8,
  -12, -13, -20, -25 (score-test stepwise half), -26, -27, -30, -31, -32,
  -33, -35`. **Depends on TODO-21** (the harness). Each is a trade-off or an
  unmeasured win: no default changes without a human reading its harness
  report.
  - **Trade-offs / opt-in:** TODO-5 saddlepoint p-values (early-stop
    screen only), TODO-25 KK21 score-test stepwise (can select different
    covariates), TODO-31 true MM robust regression (the rename/document
    half of TODO-31 is not harness-gated and can land any time), TODO-32
    mixture / boundary solvers, TODO-33 nonconcave models, TODO-35 exact
    randomization support (needs a policy decision first).
  - **Unmeasured speed wins:** TODO-4 balanced bootstrap (changes
    seed-pinned draws once), TODO-12 Newton as default, TODO-13 separable
    fits (ZOIB, hurdle-Poisson, continuation-ratio), TODO-20 exact
    enumeration for `DesignFixedOptimal`, TODO-26 CI-search refit economics,
    TODO-27 weighted C++ Bayesian-bootstrap kernels, TODO-30 per-arrival
    re-imputation (changes design output).
  - **TODO-8:** replace the audit's theoretical speedup table with the
    measured multiples as each report lands.
  - See also (research triage, 2026-11-19): Exact subset dynamic program for small-n optimal blocking (`blocking-partition#43925959437.1`).
  - See also (research triage, 2026-11-19): Draw the double-bootstrap outer x inner set once for all grid alphas (`bootstrap-confidence-interval#43925959437.1`).
  - See also (research triage, 2026-11-19): Sufficient-statistic (pair/singleton stratum) evaluation of the Gaussian LMM likelihood (`gaussian-lmm-fit#43925959437.1`).
  - See also (research triage, 2026-11-19): Regularized (sqrt(||g||)) Newton with LLT/LDLT and indefiniteness shift in optimize_likelihood_newton (`generic-smooth-mle-optimization#43925959437.1`).
  - See also (research triage, 2026-11-19): Rao score z per candidate in beta/NB/ordinal KK21 stepwise instead of full refits (`kk21-covariate-weights#43925959437.2`).
  - See also (research triage, 2026-11-19): Stored missRanger forests: predict new arrivals, refit every k arrivals (`missing-covariate-imputation#43925959437.1`).
  - See also (research triage, 2026-11-19): Weighted C++ ZI/hurdle fits, with fastglm_hurdle/fastglm_zi as oracle (`zero-inflated-count-mle#43925959437.2`).

- **Moved in from v1.1.0 on 2026-10-20 (user decision, lighten-1.1.0 pass 2):** the performance, parity and exact-null items below (TODO-24..35) plus the two audit-lever items (TODO-17z moved on to v1.3.0). Their original text is kept verbatim; cross-references to other moved items are renumbered, and references to items that stayed in v1.1.0 are marked "v1.1.0".

- [ ] TODO-24 (moved 2026-10-20 from `release_v1_1_0.md → TODO-40`, user decision; added 2026-10-07, user decision): **Closed-form
  randomization nulls: exact PMFs and exact conditional moments where they
  exist** — `exact_randomization_nulls_closed_form.md → TODO-1..7`.

  From the `coin` comparison in the 2026-10-07 benchmark investigation.
  For statistics that are functions of the treated-arm sum, the
  randomization null is closed-form on several designs: hypergeometric on
  `DesignFixediBCRD` (fixed `n_T`, binary `y`), a convolution of
  hypergeometrics on blocking designs, binomial on discordant matched
  pairs, two independent binomials on Bernoulli designs; and for general
  `y` the exact mean and finite-population variance of the statistic
  (Strasser & Weber 1999). EDI draws `r` permutations for all of them
  (14 ms generation + 0.7 ms kernel at n = r = 1000). The existing Zhang
  exact dispatch (`should_use_zhang_incidence_randomization()`) covers
  only Bernoulli/matched incidence designs and uses a "minlike" two-sided
  ordering, not the doubled-tail ordering of the Monte Carlo path.
  Delivers: a registry of (class, design) closed forms; an exact-null hook
  next to the Zhang dispatch; `type = "exact_null"` (PMF) and
  `"asymptotic_null"` (moments) on `compute_rand_two_sided_pval()`; a
  closed-form bracket for the randomization CI search (feeds v1.0.5's
  affine-shift plan). Default stays Monte Carlo; the default switch is the
  plan's decision-gated TODO-7 (listed in the standing constraint below).
  Independent of every other item; `TODO-25` depends on its hook.

- [ ] TODO-25 (moved 2026-10-20 from `release_v1_1_0.md → TODO-41`, user decision; added 2026-10-07, user decision): **Exact small-sample
  rank tests via the Streitberg–Röhmel shift algorithm** —
  `exact_rank_tests_shift_algorithm.md → TODO-1..6`. Depends on
  `TODO-24`'s hook (its plan's TODO-2).

  `InferenceAllSimpleWilcox` has no exact inference: its asymptotic
  p-value and Hodges–Lehmann CI call `stats::wilcox.test(exact = FALSE)`
  (`inference_all_simple_wilcox.R:80,106`) and its randomization p-value is
  Monte Carlo. `coin` gives exact p-values for any integer-scored linear
  rank statistic, with ties, via the shift algorithm (Streitberg & Röhmel
  1986): a dynamic program over subjects counting `k`-subsets by score
  sum, `O(n · n_T · S)`. Delivers: one C++ kernel
  `exact_linear_rank_pmf_cpp(scores, n_T)` (midranks × 2 for ties, size
  rule `n_T · S ≤ 10^8`, overflow guard), the exact rank-sum p-value and
  exact HL CI through `TODO-24`'s hook, block convolution and the
  signed-rank subset-sum for matched designs, benchmark rows against
  `wilcox.test(exact = TRUE)` and `coin`. `coin` and `exactRankTests` are
  GPL-2 only against EDI's GPL-3: reimplemented from the papers, `coin`
  used only as a test oracle. Default stays as is; the small-`n` exact
  default is the plan's decision-gated TODO-6 (standing constraint below).

  **References (roxygen-ready in the house `@references` style; rotate into
  the kernel's and `InferenceAllSimpleWilcox`'s docs when implemented; use
  `\enc{Röhmel}{Roehmel}` if `R CMD check` objects to the non-ASCII name):**

  ```
  #' @references Streitberg, B., and Röhmel, J. (1986). "Exact distributions for
  #'   permutation and rank tests: An introduction to some recently published
  #'   algorithms." \emph{Statistical Software Newsletter}, 12(1), 10-17, for the
  #'   shift algorithm that computes the exact null distribution of an
  #'   integer-scored linear rank statistic by a dynamic program over subjects.
  #'   Streitberg, B., and Röhmel, J. (1987). "Exakte Verteilungen für Rang- und
  #'   Randomisierungstests im allgemeinen c-Stichprobenproblem." \emph{EDV in
  #'   Medizin und Biologie}, 18(1), 12-19, for the extension to tied scores and
  #'   the general c-sample problem. See also Hothorn, T., Hornik, K., van de
  #'   Wiel, M. A., and Zeileis, A. (2006). "A Lego system for conditional
  #'   inference." \emph{The American Statistician}, 60(3), 257-263,
  #'   \doi{10.1198/000313006X118430}, for the same algorithm as implemented in
  #'   \pkg{coin} (GPL-2; used here only as a test oracle, no code reused).
  ```

- [ ] TODO-26 (moved 2026-10-20 from `release_v1_1_0.md → TODO-42`, user decision; added 2026-10-07, user decision; kept here although the
  2026-09-23 split rule would place it in `release_v1_0_5.md`): **Sign the
  permutation set once at generation; never re-hash or re-copy it per
  call** — `../bug_fix_plans/v1_1_0/permutation_signature_once.md → TODO-1..7`.

  Root cause of the "R6 mean difference is 0.57x of `coin`" benchmark row.
  `build_randomization_distribution_cache_key()` calls
  `stable_signature(permutations)` on every p-value call and every CI
  bisection step: `serialize()` + xxhash64 over the 8 MB double matrix
  (7.5 ms + 1 ms) against a 0.7 ms kernel; `subset_permutations()` copies
  the whole matrix even when nothing is subset (7.4 ms); and
  `generate_permutations()` stores the kernel's integer matrix as double
  (L755), doubling its size although 50 of 51 kernels want integers (16
  cannot accept a double at all, see `release_v1_0_5.md → TODO-64`).
  `stable_signature()` became a full-content hash on 2026-09-21 to fix a
  real collision bug and was never re-timed. Fix: store the signature with
  the cached set, no-op subset, integer storage end to end, an
  immutability audit with a debug-mode recheck. Bit-preserving. Acceptance:
  repeat p-value call ≤ 2 ms from 12 ms. Shares its integer-storage step
  with v1.0.5's `TODO-64` and multiplies with v1.0.5's `TODO-2` and
  `TODO-3`; otherwise independent.

- [ ] TODO-27 (moved 2026-10-20 from `release_v1_1_0.md → TODO-43`, user decision; added 2026-10-07, user decision): **Mean-difference
  randomization row at parity with `coin`** —
  `canonical_parity_resampling_rows.md → TODO-1`.

  Both sides profiled 2026-10-07. `coin::oneway_test(approximate)` spends
  most of its time in its own S4 layer (92% under `new`/`initialize`; the
  `libcoin` engine is a quarter to a third of the total). EDI's 23 ms row is
  construction 3 + generation 12 (cached per design) + `stable_signature`
  10.5 **per call** + `subset_permutations` copy 5.5 per call + a kernel
  that costs 4.7 ms on the stored double matrix but 1.1 ms on an integer
  one. Nothing is borrowable from `coin` (GPL-2 only; engine slower than
  EDI's generation + kernel). Gate: after `TODO-26` and `TODO-24` land,
  fresh-object row ≥ 1x `coin`, repeat call ≤ 2 ms, `"asymptotic_null"`
  row ≥ 1x `coin`'s asymptotic default. Also fixes the two rand-CI rows'
  comparators: `coin::oneway_test(conf.int = TRUE)` **errors** (coin has
  CIs only for rank tests), so add a Wilcoxon rand-CI row against
  `coin::wilcox_test(conf.int = TRUE, approximate)` (147 s vs EDI 17 s at
  n = 1000) and state the near-misses in the methodology text.

- [ ] TODO-28 (moved 2026-10-20 from `release_v1_1_0.md → TODO-44`, user decision; added 2026-10-07, user decision): **Bootstrap CI rows at
  parity with `boot`** — `canonical_parity_resampling_rows.md → TODO-2`.

  Per draw, EDI's kernels already beat `boot`'s statistics: `lm.fit` 0.305
  vs `fast_ols_cpp` 0.275 ms, `glm.fit` 4.2 vs 0.39 (warm), `coxph.fit`
  0.87 vs 0.75. The R6 worker adds 3.1–3.2 ms per draw on every row, and
  that cost is **independent of the byte compiler** (3.49 ms/draw JIT on vs
  3.51 off). Fixes are `release_v1_0_5.md → TODO-58`, `→ TODO-3` and
  `→ TODO-57`'s plan TODO-7. New here: warm-start every per-draw logistic
  and Cox refit from the full-data fit; adopt `boot`'s `norm.inter()`
  percentile endpoints (`boot` is License: Unlimited) behind an argument so
  EDI's percentile interval reproduces `boot.ci(type = "perc")` exactly.
  Gate: all three rows ≥ 1x `boot`, logistic ≥ 3x (arithmetic: 275 vs 167–289
  ms, 195 vs 755, 375 vs 260–510).

- [ ] TODO-29 (moved 2026-10-20 from `release_v1_1_0.md → TODO-45`, user decision; added 2026-10-07, user decision): **Zhang exact CI at parity
  with `fisher.test`** — `canonical_parity_resampling_rows.md → TODO-3`.

  The inversion is already at parity (2.1 ms on an existing object vs 2.8
  for `fisher.test(conf.int = TRUE)`; ~14 kernel calls at 0.155 ms); the row
  loses on construction, which `release_v1_0_5.md → TODO-62` separates and
  `TODO-30` reduces. Borrowable from `stats::fisher.test` (R core, GPL-2 |
  GPL-3): precompute `logdc = dhyper(support, log = TRUE)` once per table
  and evaluate each noncentrality as `exp(logdc + log(ncp) * support)`;
  EDI's kernel recomputes four `lgamma` per support point per call.
  Tolerance-equal to 1e-12 (standing constraint below). Also compare
  `fisher.test`'s two `uniroot` calls on one-sided tails with EDI's
  bisection on the two-sided p-value.

- [ ] TODO-30 (moved 2026-10-20 from `release_v1_1_0.md → TODO-46`, user decision; added 2026-10-07, user decision; kept here although the
  2026-09-23 split rule could place parts in `release_v1_0_5.md`): **R6
  construction and the per-instance byte-compilation tax** —
  `canonical_parity_resampling_rows.md → TODO-4`.

  Measured 2026-10-07: an `InferenceContinOLS` instance carries 398 function
  bindings; a synthetic R6 class with the same method count instantiates in
  1.6 ms, EDI's classes in 1.4–4.7 ms. **R6's environment rebinding discards
  bytecode** (verified: `environment<-` on a compiled closure returns an
  uncompiled one), so every instance starts with none of its methods
  compiled and R's JIT recompiles them on first use, per instance and per
  duplicated worker; pre-compiling the generator does not help. Per fresh
  object this is 60–150 ms in the bootstrap paths (JIT adds 50–90 ms), paid
  ~90 times by `InferenceSuite$run_all_inference()`. Items: measure per
  class; make `Inference$initialize()`'s checks per-class (60% of Zhang's
  construction); *decision-gated* thin-method architecture
  (`function(...) .impl(self, private, ...)` over compiled namespace
  functions, emitted by `define_inference_class()`); persistent compiled
  workers across resampling calls.

- [ ] TODO-31 (moved 2026-10-20 from `release_v1_1_0.md → TODO-49`, user decision; added 2026-10-13, user decision): **Batched C++ loop for the
  custom randomization statistic** — `custom_rand_stat_batched_cpp_loop.md →
  TODO-1..7`. `InferenceRandCustom$compute_fast_randomization_distr()` loops
  over `w_mat` in R and crosses R ↔ C++ once per permutation, even when the
  user supplied compiled C++. A new serial export,
  `compute_custom_rand_stat_distr_xptr_cpp()` in
  `user_compiled_fn_shims.cpp`, dereferences the `user_compiled_fns.h`
  pointer once and loops in C++. This is the pattern
  `design_optimal_annealing_search.cpp:152-155` already uses for
  `DesignFixedOptimal`'s `custom_objective`. R functions, pre-compiled
  Rcpp functions and Rcpp-typed source strings keep the R loop.
  - Decided 2026-10-13 (owner): D1 option (b), Eigen-typed source strings accepted too; see [DECISION-v1.2.0-TODO-31](COMPLETED_DECISIONS.md#DECISION-v1.2.0-TODO-31).
  - **Gate:** bit-for-bit equality with the R loop (2- and 3-argument forms,
    `delta` 0 and non-zero, fork and `mirai` workers). The speedup is
    measured through v1.1.0 TODO-4b's noise-floor harness before any number is
    published.
  - **Depends on:** `cached_cpp_compile()` (landed 2026-10-13), the
    per-process compile memo that stopped `cppFunction`/`cppXPtr` from
    leaving one `file*.cpp` per call in `tempdir()`.

- [ ] TODO-32 (moved 2026-10-20 from `release_v1_1_0.md → TODO-51`, user decision; added 2026-10-15, user decision): **InferenceSuite worker
  pool** — `inference_suite_worker_pool.md → TODO-1..5`.
  `run_all_inference(num_cores > 1)` forks one `mcparallel()` child per
  task, which roughly doubles its CPU (measured 2026-10-15: 369 s against
  ~194 s in-process at the same contention, about 1.1 s per task, median
  task 0.5 s). It moves to `num_cores` long-lived forked workers with a
  rolling dispatch. It keeps the per-task `max_secs_per_class` kill by PID
  (the killed worker is replaced, the others are untouched) and avoids
  `clusterApply()` / `stopCluster()`.
  - **Seeding:** each task is seeded with `seed_for_index`, so results no
    longer depend on worker count or scheduling. This is a documented draw
    change for bootstrap and randomization rows at `num_cores > 1`.
  - **Gate:** `identical()` results across `num_cores = 1, 2, 4` (all
    columns but `fit_secs`); hang and crash injection tests; the existing
    `run_all_inference` tests unchanged.
  - **Depends on:** v1.1.0 `TODO-48` (2) for `seed_for_index` and the invariance
    suite. Shares the worker single-threading helper with v1.1.0 `TODO-18`.

- [ ] TODO-33 (moved 2026-10-20 from `release_v1_1_0.md → TODO-53`, user decision; added 2026-10-20, user decision): **Amortize across runs**
  (audit lever 8) — `algorithm_choice_audit.md → TODO-42`. Today's only
  memo is per-process (`cached_cpp_compile()`, landed 2026-10-13); nothing
  survives across calls or sessions. Design first, code second:
  - **Step 1 (survey + plan, no code):** list what is recomputed that is a
    pure function of its inputs: pooled-NPMLE scores, design-side
    precomputes, runtime manifests, MC coverage-truth tables, exact-null
    tables (e.g. JT DP counts), GH rules. Per candidate: key (inputs hash),
    size, invalidation rule, and measured recompute cost via v1.1.0 `TODO-4b`'s
    noise-floor harness. Write `amortize_across_runs.md` with the verdict
    per candidate.
  - **Step 2:** implement only the candidates the plan approves, behind one
    shared cache helper (in-session first; on-disk opt-in with an explicit
    location and version-stamped keys).
  - **Constraints:** a cache hit must return exactly what a miss would
    (parity test per cache); never key on anything seed-dependent without
    including the seed; stale-state risk is the known failure mode here (see
    the stale worker-cache resampling bug), so every cache gets an
    invalidation test. No behavior change at defaults.

- [ ] TODO-34 (moved 2026-10-20 from `release_v1_1_0.md → TODO-54`, user decision; added 2026-10-20, user decision): **Anytime results**
  (audit lever 9) — `randomization_ci_search_precision.md → TODO-2..6`
  (its TODO-1 decision is now "pursue the full anytime-valid confidence
  sequence redesign"). Replaces the per-look Clopper–Pearson band in the
  randomization-CI search with a betting confidence sequence, valid at any
  stopping time, so early answers can sharpen over time without a
  multiplicity problem and `high_precision_confirm_and_refine_ci_bound()`
  can be deleted.
  - **Order:** CS helper plus coverage-simulation tests; wire behind
    `ci_search_control$mc_method` (existing behavior stays the default);
    flip the default only after `test-ci-rand.R`,
    `test-rand-ci-model-scale-classification.R` and a coverage sweep show no
    regression; then delete the stopgap and update the roxygen.
  - **Default change:** flipping `mc_method` moves rand-CI runtime and
    seed-pinned draws, so it is a documented default change under the
    release-equivalence tiers; if the flip does not clear the gate, the
    CS ships as opt-in.
  - **Depends on:** `release_v1_0_5.md → TODO-68` (rand CI α/2 inversion
    fix), since the search being made anytime-valid must first invert at
    the right level. Compose with `performance_profiling_and_upgrades.md →
    TODO-156` (Besag–Clifford) and audit TODO-5 (saddlepoint early stop):
    compare, don't assume.
  - See also (research triage, 2026-11-19): Anytime-valid Monte Carlo testing by betting for the BRT sequential p-value (`bootstrap-randomization-test#43925959437.1`).
  - See also (research triage, 2026-11-19): Anytime-valid betting stop in the randomization/BRT CI-search sequential MC (`sequential-mc-pvalue-stopping#43925959437.1`).

- [ ] ~~TODO-35~~ **→ moved 2026-10-20 to `release_v1_3_0.md → TODO-5..6`** (user decision; split into a contract item and a single Incidence GLM pilot item, the other eight families going to v2.0.0): `ModelDiagnostics` — declaration contract + pilot batteries.

- [ ] TODO-36 (added 2026-11-09, user decisions throughout): **Published monthly calibration study: size,
  coverage, null bias and power, every inference class on every applicable design.** Replaces the nightly +
  Saturday `.github/workflows/calibration-fast-tier.yml` monitor (design: `../new_feature_plans/v1_0_5/calibration_gates.md
  → CI fast tier`); results are published for anyone to inspect, as evidence that EDI's inference performs to spec.
  - **Data:** synthetic, p = 5 (x1-x3 N(0, 1), x4-x5 two-level factors; the linear predictor explains about half
    the outcome variance), each response type's own model; formulas `~ 1` (w only) and `~ .` (w + all covariates).
    Outcomes are drawn as potential outcomes y(0), y(1) before assignment, so sequential designs that use earlier
    responses (KK21) see the same data as fixed designs, and every design in a replicate shares the same subjects.
    The pre-push check keeps its own p = 2 data (its known-failures CSV is pinned to those seeds).
  - **Designs (21):** every exported design except the cluster and factorial ones. Fixed: Bernoulli (also at prob_T
    = 0.2), iBCRD, Blocking, Rerandomization, MatchingGreedyPairSwitching (n = 52 instead of 50: needs n divisible
    by 4), Optimal, BinaryMatch, Greedy, GreedyDOptimal, OptimalBlocks. Sequential: Bernoulli, iBCRD, Efron,
    Atkinson, PocockSimon, RandomBlockSize, SPBR, Urn, KK14, KK21, KK21stepwise. Each runs every class applicable
    to it (88 classes in all; no legacy IVWC class is applicable, so none is published).
  - **Effects:** the null (size, coverage, null bias) plus three local alternatives beta_T = h / sqrt(n), with h per
    response type set so the Bernoulli `~ .` baseline class has about 20 / 50 / 80% power, giving power curves
    comparable across n and a design comparison under identical data. Non-null coverage and bias need per-estimand
    truths and are a later item.
  - **n:** 50, 200, 1000 under the null (1000 replicates per cell); power at n = 50 and 200 only (500 replicates
    per cell; `--power-ns`): the effects are local alternatives, so power at n = 1000 is asymptotically what n = 200
    shows, and it would be a third of the campaign's compute. Cells still significantly off nominal at
    n = 1000 get a targeted n = 5000 follow-up after the campaign, and a convergence plot (deviation vs 1/n)
    separates small-sample behaviour (heads to 0) from inconsistency (nonzero intercept = bug).
  - **Procedures, by tier** (columns as in `R/package_tests/path_audits.html`, regression table):

    | Procedure | p-value | CI |
    |---|---|---|
    | wald, score, LR, gradient, exact (Fisher/Zhang); est → null bias | 1 | 1 |
    | other (likelihood test) | 1 | -- |
    | randomization (vanilla) | 1 | 2 |
    | LR-Bartlett-approx (measured 2026-11-09: 60-90% of a tier-1 replicate, not analytic-cheap), LR-Bartlett-exact, jackknife Wald, param boot, param-boot LR, boot-rand pctile, bayes-pctile, bayes-wald | 2 | 2 |
    | nonparametric bootstrap, at each class's default flavor (`edi_bootstrap_dispatch_policy`) | 2 | 2 |
    | nonparametric bootstrap, non-default flavors (incl. prepivoted / double / calibrated at n = 50 only), m-out-of-n, PRW subsampling, other Bayesian-bootstrap flavors, boot-rand stud / symm-t / smooth | 3 | 3 |
    | randomization custom | dropped | dropped |

    Tier 1: monthly, all designs, all n, null + power. Tier 2: monthly, Bernoulli / BinaryMatch / KK21, n = 50 and
    200, 500 replicates, package-default B and r. Tier 3: rotating, one response type per month (each pair refreshed
    twice a year), n = 50 (+ 200 for cheap classes); the report shows each cell's last-measured date. A
    (class, procedure) pair moves down a tier when its measured cost per replicate exceeds the tier's budget
    (~10 core-s for tier 2); a one-time CI timing pilot writes that cost table. Randomization redraws are cached
    per design object, so the p-value's cost is paid once per replicate and shared by every class and formula on
    it: measured 2026-11-09 at n = 1000, 0.2-0.3 s on KK21 / pair-switching / rerandomization and ~10 s on
    Atkinson (first class), ~0.1 s for each later class. `DesignFixedOptimal` has no randomization mechanism
    (deterministic solve), so its randomization cells are not applicable.
  - **Running:** free GitHub-hosted runners only (no self-hosted or paid runners; decided by the owner, undated, see [DECISION-v1.2.0-TODO-36](COMPLETED_DECISIONS.md#DECISION-v1.2.0-TODO-36)). One campaign per
    month (plus `workflow_dispatch`), pinned to the commit it started on. ~25-30-minute time-boxed shards and
    `max-parallel: 16`, so push CI keeps 4 of the 20 job slots and never waits more than one shard behind. GitHub's
    256-job matrix limit is handled by waves: each wave runs the next unfinished shards, publishes, then dispatches
    the next wave.
  - **Null bias:** per estimand cell, mean of estimate − null value, SD, bias / SD, share of non-finite estimates,
    and the share of estimates below the null value with an exact sign test (a median-unbiasedness check; the median
    itself is not mergeable across waves). Flagged (Bonferroni z-test + |bias| / SD > 0.1), never gated: an honest estimator has O(1/n) null
    bias on ratio scales and under unequal allocation.
  - **Publication:** every wave refreshes the summary CSVs, plots and `README.md` on the public
    `calibration-results` branch (`campaigns/<id>/`). Shards reduce their rows to mergeable per-cell counts and sums
    (`calibration_study_stats.R`); each wave adds them to the campaign's totals on the branch, so no step re-reads
    the ~40M result rows. The branch is rebuilt as one commit per publish (force-pushed by GITHUB_TOKEN, which
    starts no workflows), so rewritten figures never accumulate in git history. Plots: overview heatmap,
    size / coverage / null-bias dot plots, p-value calibration curves, power curves by design, design ranking,
    convergence plots, month-to-month history. Raw per-replicate rows (~0.3 GB per campaign as 7-significant-digit CSV + xz -9e, estimated 2026-11-09 from measured bytes per replicate) go to 60-day Actions
    artifacts, not git, and not GitHub Releases (the repo's Zenodo link would archive each release). The
    size/coverage gate is enforced only when a campaign completes; interim summaries are marked provisional.
  - **Convergence slopes (v1.0.5 TODO-199, 2026-11-10):** `convergence_calibration_study.R` fits each asymptotic cell's size / coverage /
    bias error against n_eff (noise-aware power law + log-log regression) and compares the order with the registry's; a non-failing publish step,
    figures and a README section report it, never gated (plan `../new_feature_plans/v1_0_5/calibration_convergence_slopes.md`).
  - **Rate-derived gate and `analyze` job (v1.0.5 TODO-200 / TODO-201, 2026-11-10):** the step schedule is replaced by min(0.10, 0.05 + c n_eff^-a) from the registry's order; analysis is its own job between `shards` and `publish` (analysis scripts from the run's commit, both commits recorded; only `Gate verdict` is a statistical red, all other failures are annotated "Calibration CI bug"); each campaign README is a master plus generated sub-pages (plan `../new_feature_plans/v1_0_5/calibration_rate_derived_gate.md`).
  - **Found while planning:** `path_audits.html` (v1.0.3, 2026-10-08) has no columns for 5 of the 10 bootstrap CI
    flavors now in `bootstrap_ci_types` (symmetric-percentile-t, prepivoted, double-bootstrap, calibrated,
    smoothed); add them when the audit is regenerated.
  - **Built 2026-11-09 (uncommitted at the time):** `.github/workflows/calibration-study.yml`;
    `R/package_tests/calibration/` `calibration_study_common.R`, `calibration_study_stats.R`,
    `run_calibration_study.R`, `plan_calibration_study.R`, `merge_calibration_study_wave.R`,
    `analyze_calibration_study.R`, `plot_calibration_study.R`, `render_calibration_study_readme.R`,
    `calibrate_study_effects.R` (+ `calibration_study_effects.csv`, `calibration_study_costs.csv`,
    `calibration_study_accepted.csv`). The fast tier's schedule is removed (it stays dispatchable; the pre-push check
    keeps its p = 2 data). Tested locally end to end on a two-wave mini campaign; the workflow itself has not run yet.
    Measured cost (all 22 designs, n = 50/200/1000 at KK21's measured per-class costs, 2026-11-09): ~19,200
    core-hours at full replicates, two-thirds of it the KK random-effects classes for count and ordinal on the
    four matched designs (one KK21 ordinal replicate at n = 1000 with every class is 57 single-core minutes, past
    the 55-minute shard timeout). **User decision 2026-11-09 (option B):** those classes (`InferenceCountKKGLMM`,
    `InferenceOrdinalKKCLMM{,Cauchit,Cloglog,Probit}`) run in their own shards (planner class groups, `--only` /
    `--exclude`; group "rest" is every other class) with 500 null replicates at n = 1000 (1,000 below) and power
    at n = 50 only. Result (per-class costs measured on KK21 at n = 50/200/1000, six probes sharing 12 cores, so
    slightly high): ~13,800 core-hours, ~9 days of 16 jobs x 4 vCPUs plus per-shard setup, so roughly the first
    10-11 days of each month. Longest single replicate: InferenceCountKKGLMM at n = 1000, ~33 single-core min. The first campaign's ledger
    replaces these estimates with measured per-unit costs anyway. Rejected: everything at full replicates (~15 days), and moving the slow
    classes to tier 2 (~6 days, but no matched-design coverage of them at n = 1000 monthly).
  - **Raw-row columns (user decisions 2026-11-09):** `inf_class`, `inf_procedure`, `formula`, `beta_T_hat`,
    `ci_beta_T_a`, `ci_beta_T_b`, `pval`, `null_value`, `fit_secs`, `status`, `message`, then the cell (`response_type`,
    `design`, `prob_T`, `n`, `n_nominal`, `p`, `rep`, `effect_label`, `beta_T`). The study renames them from
    `cal_run_tasks()`' names in `cal_study_run_rep()`; the fast tier keeps the old names. Result columns are
    rounded to 7 significant digits in the raw file only; the fast tier's `p_at_ci_a/b` endpoint check is not run
    and not written. **Tier 2 must add `inf_subprocedure`:** its bootstrap and Bayesian-bootstrap procedures
    (`bootstrap`, `bayes_boot`) run each class's default flavor (`type = NULL`, resolved per class), so the column
    records the resolved flavor (e.g. `percentile`), and it becomes part of the stats cell key. Tier 1's six
    procedures have no flavor, so the column is not written yet.
  - **Away from the null (user decision 2026-11-09):** coverage at every power effect is gated like the null
    coverage (same Bonferroni family, `analyze_calibration_study.R`), and bias at the power effects is reported
    and flagged like the null bias (`nonnull_bias_summary.csv`), both against `estimand_true`: the true value
    of each class's own estimand, from `calibrate_study_truths.R` -> `calibration_study_truths.csv` (the class's
    estimate on 8 Bernoulli samples of 20,000 from the study's generator at that effect and allocation; median,
    with its SD; counted only when >= 75% of the fits are finite). Same idea as `comprehensive_tests.R`'s
    `get_coverage_truth()` MC specs, rebuilt on the study's data generator. KK classes (matched-design only)
    have no truth: their estimand depends on the pairing. Under the null `estimand_true` = `null_value`, so the
    null results are unchanged. Re-run the truth script whenever `calibration_study_effects.csv`, a response
    model, the covariates or an estimator changes (~16 min on 10 cores).
    **Cells without a usable truth (2026-11-09, k = 8; 1,500 of 1,536 usable):** two are by design.
    `InferenceOrdinalStereotypeLogitRegr` `~1` is non-estimable with 3+ categories (owner ruling 2026-11-08), and
    `InferenceIncidCMH` refuses prob_T != 0.5. One is a defect: `InferenceIncidModifiedPoisson` `~1` gives NA
    (`model_fit_unavailable`) from n of about 10,000 (9 of 12 cells; v1.1.0 TODO-169). Also 1-2 cells each of
    `InferenceCountHurdlePoisson` `~1` and `InferenceCountZeroInflatedNegBin` `~.` (not yet examined).
  - **Two-stage gate (user decision 2026-11-09):** Bonferroni over the campaign's ~10^5 tests only failed a cell
    at size >= 0.10 or coverage <= 0.90 (1,000 replicates; 0.12 / 0.88 at 500). Now: (1) screen, BH q < 0.05 over
    every size / coverage test (null, and non-null coverage) on the screening replicates, written to
    `summary/confirm_cells.csv`; (2) confirm, once screening is done the planner gives each flagged cell 5,000
    fresh replicates (`--confirm-reps`; `--slow-confirm-reps` 1,000 for the slow KK classes), numbered 10001 on
    (`CAL_STUDY_CONFIRM_REP0`; rows and stats carry `stage`), running only the flagged classes. A cell fails only
    if the confirmation replicates alone reject at 0.01 / (flagged tests); fewer than 500 confirmation results
    (`--confirm-min-n`) counts as failing, never as cleared. `confirmation_summary.csv` gives each flagged test's
    verdict; `analyze_calibration_study.R --final` (campaign complete) turns pending into verdicts. Tested locally
    end to end on a 60-replicate incidence campaign (7 flags -> 1 confirmation unit -> verdicts).
  - **Paired design comparison (user decision 2026-11-09):** `compare_designs_calibration_study.R` runs once
    per campaign, at completion (the workflow fetches every wave's `study-rows` artifact): for each power cell
    and design, an exact McNemar test of its power against Bernoulli's on the replicates they share (same
    `rep` = same subjects); a design at another n (pair-switching's 52) gets an unpaired z-test. BH q-values;
    reported, not gated (`design_comparison.csv`).
  - **README links (added 2026-11-09):** the badge and the Highlights bullet link the workflow's Actions page,
    which exists already. The bullet was switched to the `calibration-results` branch on 2026-11-09, after the
    debug campaign's first wave published it (before that the link would 404, and `scripts/check_doc_links.py`
    in pre-push blocks a push on an external 404). The badge still links the workflow page.
  - **Debug campaign (2026-11-09):** `2026-11-09-f56e6e97` (ns=50, Bernoulli + KK21, 40 null / 20 power
    replicates) ran end to end in three waves: 64 shards, then the 4 left over (`WAVE_SIZE` 64), then
    confirmation. The screen flagged `InferenceIncidLogBinomial` Wald `~.` at n = 50 (TODO-179), and 5,000
    confirmation replicates confirmed it (size 0.134, coverage 0.866). The publish job then failed at the
    gate, as designed. Delete `campaigns/2026-11-09-f56e6e97` from `calibration-results` before the first
    real campaign.
  - **Done when:** one full campaign has completed and published from `main`'s workflow, the README links are in,
    and `calibration_gates.md` describes the study.

## Standing constraints

**Documented default changes carried here from v1.1.0 (2026-10-22, when TODO-24, -25 and -29 moved):** TODO-24's exact-null default switch (its plan's TODO-7) and TODO-25's small-n exact default (its plan's TODO-6) are decision-gated and off until the user accepts them; TODO-29's precomputed hypergeometric log-densities in the Zhang exact kernel (its plan's TODO-3) are tolerance-equal to 1e-12. TODO-34's `mc_method` default flip, if it clears its gate, is a documented default change under the equivalence tiers.

Additive; defaults preserved under the numerical-equivalence rule
(`../new_feature_plans/v1_1_0/cross_platform_reproducibility.md → Release-to-release
equivalence`: integers exact, closed-form floats 1e-10 relative, iterative
fits 10× solver tolerance, Monte Carlo results only through near-ties;
kernel parity tests plus the last release's golden fixtures are the gate); every
new C++ kernel per `sexp_removal_rcppeigen_conversion_spec.md`; targeted
compile only — never `R CMD INSTALL` / `pkgbuild::compile_dll()` /
`load_all(compile = TRUE)`. **Inherited from `release_v1_1_0.md` when
TODO-11 moved here (2026-09-06):** `performance_profiling_and_upgrades.md
→ TODO-137` (libmvec, ≤4 ulp) and `→ TODO-153` (adaptive quadrature)
ship opt-in or as a documented default change unless their measured
differences fall inside the equivalence tiers (libmvec's ≤4 ulp should; adaptive
quadrature must be checked against each fit's solver tolerance); `→ TODO-156`
(Monte-Carlo early stopping) ships opt-in only; `→ TODO-149` (non-R RNG
streams) is opt-in or a documented default change. TODO-21's Robbins–Monro
item is opt-in by construction (`ci_search_algorithm` argument,
default `"bisection"`) until its own A/B report clears a wider default. TODO-22's draw-kernel item (`algorithm_choice_audit.md → TODO-21`) changes seed-pinned draws once, as a documented default change; every TODO-23 item ships opt-in or as a documented default change only after its harness report is read.

- [ ] TODO-37 (added 2026-11-10, owner): **Native C++ tests for this release's core additions.**
  - Plan: `../new_feature_plans/v1_2_0/native_cpp_tests_v1_2_0.md`, the follow-on to `release_v1_0_7.md` TODO-12.
  - Every C++ addition to the `EDI_CORE_ONLY` core in this release lands with its `cpp_tests/` target in the same
    change.
  - Each target builds from a minimal source subset (the CLAUDE.md whitelist).
- [ ] TODO-204 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `interval-censored-npmle#43925959437.1`, see `audits/research_triage_drafts.md`): **Interval-censored Cox (ic_sp):
  profile-likelihood SE prototype in place of bs_samples = 200 (owner decision: SE estimator change)**
  - Port icsp2's vcov/profile_fit logic (warm-started baseline refits at beta +/- h, OIM curvature) around icenReg's
    fitter, attributing the LGPL source; do not depend on icsp2 (not on CRAN). A/B against bs_samples = 200 on the
    interval-censored fixtures at n in {50, 200, 1000}: SE ratio, Wald CI coverage in a 1000-rep simulation,
    wall-clock, and convergence failures for the chosen h.
  - Done when: >= 1.5x faster SE with coverage within MC error of the bootstrap SE, and the owner approves the estimator
    change, or closed with the numbers (bootstrap stays the default either way until approved).
- [ ] TODO-205 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `monte-carlo-test-inversion-ci#43925959437.4`, see `audits/research_triage_drafts.md`): **Quantile Zhang CI: common
  random numbers across the delta search (catalog §9 TODO-6a)**
  - After the v1.0.6 reservoir-validity check (finding monte-carlo-test-inversion-ci .1) lands, pre-draw one sign-flip
    and one permutation matrix per CI search in ci_exact_zhang_combined / compute_rand_pval_matched_pairs /
    compute_rand_pval_reservoir and use p = (1+#)/(1+N). A/B against the current fresh-draw bisection at n = 50, 200,
    1000 (nsim_rand default) on the KK quantile IVWC fixtures: wall time, number of p evaluations per bound, and
    coverage over 500 reps. Needs the A/B harness (release_v1_2_0.md TODO-21); a changed MC realisation is a
    documented default change for the owner.
  - Done when: >= 1.5x fewer evaluations with coverage >= nominal within MC error, or closed with the numbers.
- [ ] TODO-206 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `pvalue-combination#43925959437.3`, see `audits/research_triage_drafts.md`): **Zhang combined p-value: exact joint
  convolution vs Fisher chi^2_4 on discrete exact p-values (owner decision: test change)**
  - Compare zhang_combine_exact_pvals (Fisher, Stouffer, min-p; inference_helpers_zhang.R) against (a) the exact joint
    convolution of the two discrete null supports (two-pointer sweep over log pM + log pR) and (b) DPComb 1.0.1 (MIT)
    as an oracle for the Wasserstein-adjusted rule, on the incidence KK Zhang classes at n = 50, 200, 1000 with 2,000
    null and alternative reps. Report size, power and CI width; runtime only to confirm the exact option stays under 1
    ms.
  - Done when: the owner picks one rule given the size/power table, or closes it with the numbers (no default change
    without that decision).
- [x] TODO-207 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `randomization-null-distribution#43925959437.2`, see `audits/research_triage_drafts.md`): **Randomization p-value
  rule: (b+1)/(r+1) vs b/r with floor (owner policy decision)**
  - Simulate the null rejection rate of the current rule (rand_pval_from_tail_counts) and the Phipson-Smyth rule at r in
    {101, 201, 501} and alpha in {0.01, 0.05}, using a cheap statistic (mean difference) on 20,000 null datasets, and
    report the exact size of each. Also fix catalog section 7 P4's description of the current rule.
  - Done when: the owner decides to switch (documented default change, bundled with release_v1_2_0.md TODO-11 / perf
    TODO-156) or to keep b/r with the floor and document why, with the size table attached.
  - Decided 2026-11-23 (owner): switch to (b+1)/(B+1) per tail, two-sided doubled and capped at 1, before the 1.0.5
    freeze (not bundled with TODO-11); see [DECISION-v1.2.0-TODO-207](COMPLETED_DECISIONS.md#DECISION-v1.2.0-TODO-207).
  - Done 2026-11-23 (agent, branch `rand-pvalue-plus-one`, commit bb0fa2b8; R only, no C++ change, no rebuild
    needed; Rd not regenerated). Every Monte Carlo randomization p-value counts the observed statistic as one draw:
    `rand_pval_from_tail_counts()` (doubled smaller tail; `compute_rand_two_sided_pval()`, its sequential-MC and
    affine-reuse paths, `InferenceRandCustom`, the KK GEE mixin, BRT percentile/smoothed), new
    `rand_pval_from_abs_count()` (|T| form), `compute_two_sided_brt_pval_studentized()` (signed: doubled; symmetric:
    |T|), `closed_form_ci_from_affine_null_draws()` and the BRT CI's B-too-small message (now 2/(B+1) >= alpha), and
    the KK quantile IVWC `compute_rand_pval_matched_pairs()`/`compute_rand_pval_reservoir()` (|T|; were b/B with no
    floor and could return 0, which `zhang_combine_exact_pvals()` treated as a missing component). Catalog section 7
    P4 corrected. Size table (exact under exchangeable ranks, no ties; 20,000-dataset simulation within MC error):

    | r | alpha | old two-sided | new two-sided | old KK-quantile abs, b/r | old BRT symmetric, floor 2/r | new abs |
    |---|---|---|---|---|---|---|
    | 101 | 0.01 | 0.0000 | 0.0000 | 0.0196 | 0.0000 | 0.0098 |
    | 101 | 0.05 | 0.0588 | 0.0392 | 0.0588 | 0.0588 | 0.0490 |
    | 201 | 0.01 | 0.0198 | 0.0099 | 0.0149 | 0.0149 | 0.0099 |
    | 201 | 0.05 | 0.0594 | 0.0495 | 0.0545 | 0.0545 | 0.0495 |
    | 501 | 0.01 | 0.0120 | 0.0080 | 0.0120 | 0.0120 | 0.0100 |
    | 501 | 0.05 | 0.0518 | 0.0478 | 0.0518 | 0.0518 | 0.0498 |

    Real EDI calls (`InferenceAllSimpleAverageDiff`, iBCRD n = 20, normal y, unseeded design, inference seed per
    dataset; old and new rule on the same draws), rejection rate at alpha = 0.01 / 0.05: r = 101 (5,000 datasets) old
    0.0000 / 0.0588, new 0.0000 / 0.0396; r = 201 (5,000) old 0.0194 / 0.0596, new 0.0090 / 0.0482; r = 501 (3,000) old
    0.0123 / 0.0507, new 0.0087 / 0.0450. Seeded design with no inference seed (r = 201, 3,000): old 0.0117 / 0.0553,
    new 0.0000 / 0.0417, because draw 1 replays the observed allocation (v1.2.0-TODO-263).
  - Follow-up: v1.2.0-TODO-263 below (the observed allocation already among the reference draws).
- [ ] TODO-208 (added 2026-11-17, agent, owner approved; from the algorithm-research triage of run 43925959437, finding
  `ridit-mann-whitney#43925959437.1`, see `audits/research_triage_drafts.md`): **Ridit: Brunner-Konietschke unbiased
  variance as an option beside DeLong (owner decision: estimator change)**
  - Implement the BK estimator from the placements already computed in ridit_delong_se_from_scores, and compare it with
    DeLong on Wald size and CI coverage for the ridit class at n_T, n_C in {5, 10, 25, 100} with 3-7 ordered
    categories and heavy ties (2,000 reps per cell); include the n_i = 1 case.
  - Done when: the owner chooses default/option/none from the size-coverage table, or the item closes with the numbers.
- [ ] TODO-209 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `balanced-allocation-optimization#43925959437.1`, see `audits/research_triage_drafts.md`): **BLDM + complete
  Karmarkar-Karp for p = 1 optimal allocation (deferred)**
  - Why deferred: Plausible but narrow: only p = 1 and the |sum difference| kinds, with an exponential certification
    tail near n = 50-60. The exact enumeration solver for n <= ~30 (algorithm_choice_audit.md TODO-20, in
    v1.2.0-TODO-23) covers the MILP range first; revisit for n > 30, p = 1 after it lands.
  - Related: v1.2.0-TODO-23; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-210 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `balanced-allocation-optimization#43925959437.2`, see `audits/research_triage_drafts.md`): **Low-rank convex MIQCP via
  the CRAN scip package for DesignFixedOptimal (deferred)**
  - Why deferred: New optional dependency, no benchmark, applies_at_edi_sizes unknown. The MILP is used only up to n =
    20 (EDI_OPTIMAL_DEFAULT_LINEARIZATION_MAX_N, helper_optimal_milp_solvers.R:25), which the planned exact enumerator
    (audit TODO-20, v1.2.0-TODO-23) supersedes up to ~30; the MIQP formulation is already noted in catalog §12 TODO-2.
  - Related: v1.2.0-TODO-23; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-211 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `balanced-allocation-optimization#43925959437.3`, see `audits/research_triage_drafts.md`): **HiGHS instead of GLPK as
  the MILP backend for optimal designs (deferred)**
  - Why deferred: Unquantified, new dependency, and the source itself says results depend on the formulation; GLPK runs
    only at n <= 20 (helper_optimal_milp_solvers.R:25), where audit TODO-20's enumerator (v1.2.0-TODO-23) is the planned
    replacement. Revisit as one arm of that benchmark if MILPs are still used beyond the enumeration cap.
  - Related: v1.2.0-TODO-23; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-212 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `beta-regression-mle#43925959437.2`, see `audits/research_triage_drafts.md`): **Vectorize the per-row rbeta loop in
  the ZOIB parametric-bootstrap simulator (deferred)**
  - Why deferred: Real but small: the loop at inference_proportion_zero_one_inflated_beta.R:791-801 draws u as a vector
    first and interleaves no other RNG, so a vectorized rbeta should be identical(); but it saves only O(n) interpreted
    iterations next to a C++ ZOIB refit per replicate. Fold into the ZOIB BB TODO (finding
    beta-regression-mle#43925959437.1) if that is approved, gated on identical() under a fixed seed.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-213 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `binary-glm-mle#43925959437.2`, see `audits/research_triage_drafts.md`): **Route fractional-logit estimate_only
  glm.fit branch to C++ IRLS (deferred)**
  - Why deferred: The glm.fit(quasibinomial) branch (inference_proportion_fractional_logit.R:165) runs only when harden
    = FALSE, and harden defaults to TRUE (:140) with no internal caller setting it FALSE, so this is a cold opt-in path;
    the default path already uses fast_logistic_regression_cpp (:257).
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-214 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `blocking-partition#43925959437.3`, see `audits/research_triage_drafts.md`): **HiGHS as an open-source MILP backend
  for optimal blocks (deferred)**
  - Why deferred: Unquantified for this model; ROI.plugin.highs MILP support is unconfirmed by the finding itself, and
    it adds a dependency. roi_solver is a closed set (helper_optimal_milp_solvers.R:30). Relevant only beyond the
    small-n range that the reformulation/DP work in v1.2.0-TODO-23 targets.
  - Related: v1.2.0-TODO-23; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-215 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `bootstrap-index-generation#43925959437.1`, see `audits/research_triage_drafts.md`): **Dense bitset instead of
  unordered_set in sample_group_units (deferred)**
  - Why deferred: Bit-identical but negligible end to end (the finding says so); rejection + unordered_set is at
    exchangeable_resampling_draws.cpp:81. The partial Fisher-Yates half (catalog §7 TODO-2) is unscheduled and changes
    the stream. Revisit only if profiling shows subsampling draws matter.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-216 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `bootstrap-index-generation#43925959437.2`, see `audits/research_triage_drafts.md`): **Batched bounded random integers
  (Brackett-Rozinsky & Lemire) for bootstrap indices (deferred)**
  - Why deferred: Unquantified at EDI sizes, needs 64-bit words while RRng is 32-bit MT19937, changes seed-pinned
    streams, and index generation is small next to per-replicate refits. Belongs with the RNG-throughput measurement
    (performance_profiling_and_upgrades.md TODO-149, in v1.2.0-TODO-11).
  - Related: v1.2.0-TODO-11; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-217 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `complete-randomization-draws#43925959437.1`, see `audits/research_triage_drafts.md`): **C++ partial Fisher-Yates
  kernel for block_ra_batch (deferred)**
  - Why deferred: block_ra_batch is already vectorized R (design_fixed_blocking.R:16, used by
    blocking/cluster/optimal-blocks designs), so the old replicate(randomizr) cost that audit TODO-21 (v1.2.0-TODO-22)
    targeted is mostly gone; the remaining constant-factor gain is unmeasured and changes seed-pinned draws. Profile
    first under that item.
  - Related: v1.2.0-TODO-22; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-218 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `complete-randomization-draws#43925959437.2`, see `audits/research_triage_drafts.md`): **Batched bounded random
  integers for Fisher-Yates shuffles (deferred)**
  - Why deferred: Same as the bootstrap-index finding: measured only with 64-bit generators, changes the seed-pinned
    R/Python stream, and the shuffle is rarely dominant (rerandomization spends O(np) per draw on balance). Revisit with
    the RNG-throughput item (performance TODO-149 in v1.2.0-TODO-11).
  - Related: v1.2.0-TODO-11; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-219 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `constrained-binomial-mle#43925959437.1`, see `audits/research_triage_drafts.md`): **Exponential-cone interior-point
  (ECOS/Clarabel) solver for log/identity-binomial MLE (deferred)**
  - Why deferred: A robustness idea with a new solver dependency and no measured gain over EDI's own active-set
    projection and KKT gate; probably slower per fit than IRLS. It is a candidate arm for the log-binomial constrained
    solver in algorithm_choice_audit.md TODO-32 (v1.2.0-TODO-23), not its own item.
  - Related: v1.2.0-TODO-23; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-220 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `covariance-from-information#43925959437.1`, see `audits/research_triage_drafts.md`): **Factor the information matrix
  once (reuse FullPivLU or LDLT) for vcov (deferred)**
  - Why deferred: Microseconds per fit at p <= 20, and the FullPivLU check plus inverse() pair is deliberate for
    bit-compatibility (comment at _helper_functions_core.h:724-748). Tracked under performance_profiling_and_upgrades.md
    TODO-155 (v1.2.0-TODO-11); try lu.inverse() there with a vcov-fixture A/B.
  - Related: v1.2.0-TODO-11; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-221 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `cumulative-link-ordinal-mle#43925959437.3`, see `audits/research_triage_drafts.md`): **Tail-accurate cell-probability
  differences per link (rms celldiff) instead of F(u)-F(l) floored at 1e-12 (deferred)**
  - Why deferred: Robustness only, no speed gain; the cancellation and the 1e-12 floor
    (ordinal_fixed_link_helpers.h:258,285,343) are already recorded as a catalog section 2 incidental that 'only matters
    from extreme starts', and no fit failure has been traced to it. Revisit if a near-separated ordinal replicate
    failure is traced to the floor (it would then be a v1.0.6 false-convergence item).
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-222 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `cumulative-link-ordinal-mle#43925959437.4`, see `audits/research_triage_drafts.md`):
  **fastglm::fastglm_ordinal(nonparallel=) instead of VGAM::vglm for partial proportional odds (deferred)**
  - Why deferred: Low confidence: no timings, fractional-weight behaviour undocumented (weights are frequency counts),
    estimator equivalence unknown, and fastglm_ordinal is a brand-new release (CRAN 0.1.4, 2026-11-11). It would add a
    dependency, so it would belong in v1.2.0+ with an owner decision; vglm is called at
    inference_ordinal_partial_proportional_odds.R:574,607. Revisit once the package has matured.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-223 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `dense-linear-algebra#43925959437.2`, see `audits/research_triage_drafts.md`): **Cancellation-free centred form of the
  LMM per-group quadratic form W_g (deferred)**
  - Why deferred: Robustness only, low confidence, and it matters only at v_b/v_e of about 1e6 or more; W_g = Q_g -
    (v_b/a_g) S_g^2 is at fast_gaussian_lmm.cpp:109-118 / :158. The natural time to change it is the profiled-LMM
    rewrite (audit TODO-32, v1.2.0-TODO-23), which reworks neg_ll_and_grad anyway.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-224 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `design-matrix-preprocessing#43925959437.2`, see `audits/research_triage_drafts.md`): **Single forced-front pivoted QR
  or column-append QR updates in qr_reduce_preserve_cols_cpp (deferred)**
  - Why deferred: Already listed in audit TODO-29 ('qr_reduce_preserve_cols single factorization', v1.2.0-TODO-22,
    low-priority linear algebra). The keep-set is cached, so the path is cold, and a different pivot could change the
    keep-set on near-collinear designs; no new reason to raise its priority.
  - Related: v1.2.0-TODO-22; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-225 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `exact-conditional-tests#43925959437.1`, see `audits/research_triage_drafts.md`): **p-value-only Fisher exact path
  (zhang_exact_fisher_pval_cpp or conf.int=FALSE) (deferred)**
  - Why deferred: pval_exact_fisher (inference_indicidence_exact_fisher.R:109) is only reached from the user-level
    p-value at a given delta (:78); the CI comes from one fisher.test call, not from inversion, so there is no
    repeated-call hot path. Low value; the conf.int = FALSE change is trivial when the file is next touched.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-226 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `gamma-family-functions#43925959437.1`, see `audits/research_triage_drafts.md`): **Exact finite sums for
  integer/half-integer df upper chi-square tail (deferred)**
  - Why deferred: Catalog verdict for fast_gamma_functions.h fast_pchisq_upper is Keep (catalog line 1024), and the
    finding expects negligible end-to-end gain since each p-value follows a refit; the accuracy benefit is unquantified.
    Could ride with the accuracy batch (audit TODO-22, v1.1.0-TODO-50) if that is reopened.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-227 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `gee-fit#43925959437.1`, see `audits/research_triage_drafts.md`): **Cache the multgee uniform local-odds-ratio
  structure across ladder rungs and draws (deferred)**
  - Why deferred: Low confidence: the LOR estimation's share of an ordLORgee call is unmeasured, and the cache couples
    EDI to multgee's LORterm layout. The native ordinal GEE kernel that replaces multgee::ordLORgee is already scheduled
    (v1.2.0-TODO-2), which supersedes an interim cache.
  - Related: v1.2.0-TODO-2; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-228 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `hodges-lehmann-estimation#43925959437.1`, see `audits/research_triage_drafts.md`): **O(n) closed-form Hodges-Lehmann
  variance from centred group sums (deferred)**
  - Why deferred: Exact and more stable, but the only caller is compute_wilcox_matching_ivwc_bootstrap_parallel_cpp
    (fast_wilcox_hl.cpp:574-576), used by the legacy InferenceAllKKWilcoxIVWC (inference_all_KK_wilcox_ivwc.R:467). Low
    value; do it when that file is next touched for the HL SE scale fix.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-229 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `jackknife-replicates#43925959437.2`, see `audits/research_triage_drafts.md`): **Linearized (CV3L) jackknife from
  per-unit scores/information as an opt-in (deferred)**
  - Why deferred: Estimator change (first-order approximation; BCa a-hat and jackknife SE move), low confidence, and it
    needs per-unit score and information contributions that most EDI specs do not expose (the same obstacle the catalog
    records for the infinitesimal jackknife, line ~1676). The 'v1.0.7-TODO-6' the finding cites is unrelated
    (ModifiedPoisson ~1 at large n). Revisit after the exact LS jackknife lands and if per-unit hooks are added.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-230 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `kk21-covariate-weights#43925959437.1`, see `audits/research_triage_drafts.md`): **Distinct-y frequency table for the
  NB theta score/information sums in KK21 tstats (deferred)**
  - Why deferred: Exact regrouping, but the theta step is one Newton step per outer iteration (kk21_weights.cpp:553-564,
    digamma/trigamma per obs) while the IRLS beta loop (<=25 its) dominates; only reached when count_use_speedup=FALSE.
    Unquantified, low confidence; revisit with a profile.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-231 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `link-function-evaluation#43925959437.1`, see `audits/research_triage_drafts.md`): **Minimax (fdlibm-style) polynomial
  in s^2 for fast_log1pexp instead of 10-term Taylor (deferred)**
  - Why deferred: Marginal speed (about 3 FMAs per element while exp dominates) and the current series already meets its
    claimed <5e-12 abs error (inventory row fast_log1pexp, 'Keep'). Worth doing only as an accuracy item; the citation
    fix for catalog P11 (algorithm_choice_audit_catalog.md:1474) can be done anytime.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-232 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `missing-covariate-imputation#43925959437.2`, see `audits/research_triage_drafts.md`): **missForestPredict
  warm-started periodic refits and per-arrival predict (deferred)**
  - Why deferred: New dependency, a different imputer (estimator change), unquantified gain, and only needed if the
    missRanger predict path in v1.2.0-TODO-23 (audit TODO-30) proves insufficient. Revisit after that prototype reports.
  - Revisit on or after 2027-07-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-233 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `mle-starting-values#43925959437.2`, see `audits/research_triage_drafts.md`): **Factor X_pos once for both hurdle-NB
  OLS start columns (deferred)**
  - Why deferred: Real but tiny: fast_hurdle_negbin.cpp:167 and :170 each run a ColPivQR on X_pos, saving one O(np^2)
    factorization in a start grid of a whole iterative fit. Bit-identical; bundle with the next edit to the start code
    (e.g. v1.2.0-TODO-11's TODO-155 work) rather than ship alone.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-234 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `monte-carlo-test-inversion-ci#43925959437.2`, see `audits/research_triage_drafts.md`): **Exact quadratic jump-point
  inversion for studentized BRT pivots (Zhu & Liu 2024) (deferred)**
  - Why deferred: Applies only to OLS / mean-diff / Lin studentized BRT pivots, which fall back to bisection in
    invert_rand_bootstrap_test_bisection (inventory 'Keep-tracked'); low confidence, no EDI-size benchmark, and the
    reference code is unlicensed (implement from the paper). Revisit after v1.2.0-TODO-21's harness exists.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-235 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `monte-carlo-test-inversion-ci#43925959437.5`, see `audits/research_triage_drafts.md`): **ITP (n0=0) instead of
  bisection in zhang_bisect_ci_boundary (deferred)**
  - Why deferred: Each p(delta) evaluation is O(d+S) arithmetic, so even 20 -> 8-10 evaluations saves microseconds; the
    inventory already lists three conflicting verdicts for zhang_bisect_ci_boundary ('Keep', 'Adopt-with-caveat',
    'Prototype') that should be reconciled first (the 'step function' rationale is the part to correct).
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-236 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `pairwise-distance-matrix#43925959437.1`, see `audits/research_triage_drafts.md`): **XPtr compiled custom distance and
  hoisted buffers for the R-callback distance matrix (deferred)**
  - Why deferred: Adds API surface; the matrix is computed once per design and the ompr MILP dominates (finding
    tradeoffs; inventory distance_matrix_custom_cpp_impl 'Keep (inherent to a black-box R fn)'). Low value now.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-237 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `quantile-rank-regression#43925959437.2`, see `audits/research_triage_drafts.md`): **Portnoy-Koenker/CFM preprocessing
  for bootstrap quantile-regression refits (deferred)**
  - Why deferred: Exact (same estimates), but the cited gains are against Stata simplex at k = 20 and the paper reports
    no gain for a single fit at n = 500, k = 8; EDI's quantile classes have small p, and the inventory verdict for
    inference_continuous_quantile_regr.R is 'Keep br at EDI sizes'. Revisit after the rq.fit/C++ quantile work
    (v1.2.0-TODO-1, TODO-22 audit TODO-19) if profiling shows replicate QR fits dominate at n >= 1,000.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-238 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `random-number-generation#43925959437.2`, see `audits/research_triage_drafts.md`): **Batched bounded integers
  (Brackett-Rozinsky & Lemire) for Fisher-Yates shuffles (deferred)**
  - Why deferred: bounded_rand (RNG.h:324-336) is already Lemire's method (inventory verdict 'Keep (best-known
    method)'); the batched variant changes every seed-pinned shuffle for a gain bounded by the RNG share, which is
    unmeasured and, per the finding above, likely smaller than the per-draw MT seeding cost. Revisit together with the
    RNG-stream TODO if that benchmark shows word generation matters.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-239 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `rerandomization-sampling#43925959437.1`, see `audits/research_triage_drafts.md`): **Early-abandon partial sums in
  rerandomization acceptance check (deferred)**
  - Why deferred: The gain is bounded by the O(np) GEMV share of a candidate (rerandomization_helpers.cpp:236-238), and
    the per-draw MT seeding (finding random-number-generation .1) is likely the larger cost at EDI sizes. Accumulating f
    in a different order can also flip decisions exactly at the cutoff, which changes seed-pinned draws. Revisit after
    the RNG setup benchmark.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-240 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `resampling-refit-loop#43925959437.1`, see `audits/research_triage_drafts.md`): **nth_element sample quantile for
  intercept-only sign-flip refits instead of rq(yd ~ 1) (deferred)**
  - Why deferred: The rq.fit replacement is already scheduled as audit TODO-19 (catalog section 9 TODO-6b) under
    v1.2.0-TODO-22, but the code path (qr_intercept_pairs, inference_all_KK_quantile_regr_ivwc_abstract.R:402-407) is
    hosted only by the legacy KK quantile IVWC classes (inference_continuous_KK_quantile_regr_ivwc.R:69,
    inference_proportion_KK_quantile_regr_ivwc.R:64), which are never published. Fold the p == 0 nth_element special
    case into TODO-22 if that work touches this file.
  - Related: v1.2.0-TODO-22; take this up with or after it.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-241 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `risk-difference-ci#43925959437.1`, see `audits/research_triage_drafts.md`): **Closed-form MN constrained MLE (cubic)
  plus Brent on z(delta) for the risk-difference CI (deferred)**
  - Why deferred: Catalog section 6 candidate 3 rates it 'Adopt, low priority': mn_ci_cpp/mn_pvalue_cpp are called once
    per CI/p-value (inference_incidence_miettinen_nurminen_univ.R:155,172), not inside resampling, and absolute cost is
    microseconds. No release TODO schedules it; brent_ci_inversion.md (v1.1.0-TODO-17w) does not yet name
    mn_ci_internal. Fold into that plan when it lands, using lrstat remlRiskDiff as the reference.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-242 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `robust-m-regression#43925959437.1`, see `audits/research_triage_drafts.md`): **Finite-termination active-set Newton
  for the Huber M-estimator (deferred)**
  - Why deferred: Same estimator and same O(np^2) per step; the finding's own source says Huber IRLS converges in 4-5
    iterations, so the saving at n <= 1000, p <= 10 is likely small. Robust-regression performance work is already a
    v1.2.0 lane (v1.2.0-TODO-3, robust_regression_perf_optimization_spec.md); revisit there if profiling shows IRLS
    iterations dominate KK randomization draws.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-243 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `sandwich-variance#43925959437.1`, see `audits/research_triage_drafts.md`): **pxp Bell-McCaffrey df and kxk meat
  reduction for CR2 (estimatr 2.0) (deferred)**
  - Why deferred: Same CR2 estimator, but cluster_robust_cr2_variance (helper_robust_sandwich.R:116-157) runs once per
    fit, only on cluster-randomized designs (callers inference_continuous_ols.R:399, inference_continuous_lin.R:392),
    and its O(nG^2) crossprod is milliseconds at n <= 1000. Revisit if the CR2 SE is put inside studentized bootstrap or
    randomization loops.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-244 (added 2026-11-19, owner; deferred finding from the algorithm-research triage of run 43925959437, finding
  `simulation-study-engine#43925959437.1`, see `audits/research_triage_drafts.md`): **Boos-Zhang 1/B extrapolation of
  coverage/power in the simulation engine (deferred)**
  - Why deferred: This changes what the simulation report states (an extrapolated B = infinity summary) rather than
    speeding any EDI algorithm, and it needs nested sub-B bookkeeping in every bootstrap/randomization cell; the
    inventory verdict for result_key_store is Keep. Plausibly useful for the monthly calibration study (v1.2.0-TODO-36),
    so revisit when that study's compute budget is set.
  - Revisit on or after 2027-05-01.
  - Done when: a benchmark or check at EDI sizes shows a worthwhile gain with unchanged results (identical() or within
    tolerance), or the item closes with the numbers. Anything that changes results needs an owner decision.
- [ ] TODO-245 (added 2026-11-19, owner; from the algorithm-research triage of run 43925959437, finding
  `exact-conditional-tests#43925959437.2`, see `audits/research_triage_drafts.md`): **O(log n) boundary search for the
  minlike exact binomial p-value**
  - Port R's `.binom_test_two_sided_pval_minlike` (stats/R/binom.test.R, GPL-2+) into
    `zhang_exact_speedups.cpp::binom_two_sided_pval` (used by `zhang_exact_binom_pval_cpp`): find the opposite-side
    boundary by a linear scan on one side of the mode, or a binary search for n >= 1234, then
    p = pbinom(yL) + pbinom(yR - 1, upper). That is O(log n) dbinom calls plus two pbinom calls instead of the current
    O(n) dbinom loop.
  - Keep the same minlike rule and 1e-7 relative tolerance. Gate with an equality test against the current kernel and
    `stats::binom.test(...)$p.value` over a grid of (x, n, p0), including x = 0, x = n and ties at the boundary; the
    pbinom tails may differ in the last bits, so compare to tolerance.
  - Benchmark the Zhang exact CI bisection at EDI's discordant-pair counts and at large n.
  - Done when: merged with the equality test passing and the timings recorded, or closed with the numbers.
- [ ] TODO-246 (added 2026-11-19, owner; from the algorithm-research triage of run 44358397244, findings
  `likelihood-tests-null-refits#44358397244.1` and `#44358397244.3`, see
  `audits/research_findings/2026-11-18-run44358397244.md`): **Profiled 1-D null refit for the Gaussian LMM likelihood
  tests**
  - With beta_T = delta moved into an offset, profile beta (GLS) and sigma_e^2 (closed form) out and search the single
    ratio lambda = sigma_b^2 / sigma_e^2 in [0, lambda_max] with Brent or a safeguarded 1-D Newton (the lme4 /
    MixedModels.jl profiled deviance, with the lambda = 0 boundary handled exactly). KK groups have only two sizes
    (pairs, singletons), so after one O(n p^2) pass each profile evaluation is O(p^3), independent of n. Build on
    `fast_gaussian_lmm_gls_cpp`. One deterministic search replaces both L-BFGS starts and the 1e-4 switching rule.
  - Folded in (finding .3): for the score test, return a cached p x p beta-block information from the null fit
    (sum_g X_g' P_g X_g, which equals the efficient information once the cross blocks are zero) instead of rebuilding
    the full information per accessor; fix the comment to "observed Hessian with cross blocks zeroed; beta block
    equals expected".
  - Done when: LR / score / gradient p-values and CI endpoints match the current refit to tolerance on the KK GLMM
    package_tests rows (or a difference is shown to be the current refit missing the optimum), with timings recorded;
    or the item closes with the numbers.
- [ ] TODO-247 (added 2026-11-19, owner; from the algorithm-research triage of run 44358397244, finding
  `likelihood-tests-null-refits#44358397244.2`): **Warm-start the KK conditional-Poisson fallback null refits**
  - In `fit_with_fixed` (`R/EDI/R/inference_count_KK_cond_poisson.R` ~L69), pass the previous null fit's nuisance
    coefficients (`start[-j]`, already returned by `extract_start`) to `glm.fit(start = ...)`, with a cold-start retry on
    non-convergence. When `Z[, -j]` is intercept-only (Poisson reservoir-only fallback), return the closed form
    log(sum y / sum exp(delta * Z[, j])) without IRLS.
  - Done when: p-values and CI endpoints match the current output to 1e-8 on the existing KK conditional-Poisson
    fallback tests, with timings recorded; or the item closes with the numbers.
- [ ] TODO-248 (added 2026-11-19, owner; from the algorithm-research triage of run 44358397244, finding
  `cox-ph-fit#44358397244.1`): **Early stop for the Cox Newton-Raphson loop in estimate-only fits**
  - After accepting a step-1 candidate with |ll - ll_candidate| < tol, stop with converged = TRUE; when `estimate_only`
    and nothing consumes the Hessian at the final beta, skip the confirming pass, else run only the gradient pass for
    `gradient_norm`. Optionally stop on the Newton decrement g'H^-1 g / 2 < tol from the LDLT already computed
    (lifelines 0.15.0). beta is bit-identical under the first variant.
  - First count `num_iter` on KK and stratified Cox randomization runs; proceed only if most replicates converge in
    <= 4 iterations (saving 1 of k O(n p^2) passes, ~15-40% of kernel time).
  - Done when: beta is bit-identical on the package_tests CSVs and `fisher_information` / `gradient_norm` consumers are
    unaffected, with timings recorded; or the item closes with the iteration counts.
- [ ] TODO-249 (added 2026-11-19, owner; low priority; from the algorithm-research triage of run 44358397244, finding
  `clmm-ordinal-mixed-fit#44358397244.3`): **LP overlap pre-check before the CLMM ordinal multistart**
  - Run the single linear-programming overlap test of Sablica, Hornik & Rusch (2026) to decide whether a finite MLE of
    the cumulative-link fixed part exists; if not, skip the multistart and polish and mark the fit or replicate
    non-estimable, consistent with EDI's separation warnings.
  - First read the paper's LP formulation and check on a separated KK ordinal dataset whether it flags the cases where
    the CLMM/GLMM fits diverge. If it does, consider it as a shared pre-check alongside the separation handling in
    v1.0.6-TODO-76.
  - Done when: the check is reported (flags vs divergent fits) and the pre-check is merged with unchanged results on
    non-separated inputs, or the item closes with the numbers.
- [ ] TODO-250 (added 2026-11-19, owner; from docs-claims audit finding `docs-claims-d218ace01`): **Joint weighted ZOIB
  MLE for the bootstrap refit.** `InferencePropZeroOneInflatedBetaRegr$compute_estimate_with_bootstrap_weights()`
  (`R/EDI/R/inference_proportion_zero_one_inflated_beta.R`) does not refit the joint zero/one-inflated beta likelihood:
  it runs two separate weighted logistic fits plus a weighted `betareg` on the interior rows, with an `lm.wfit` fallback
  on logit(y). Even unit weights therefore do not reproduce the joint-MLE estimate of `compute_estimate()`, so the
  Bayesian/weighted bootstrap distribution is centred on a different estimator.
  - Investigate a weighted version of the joint ZOIB likelihood the full fit maximizes (row weights on each
    log-likelihood term), warm-started from the unweighted fit; check cost per replicate.
  - Done when: with unit weights the weighted refit equals `compute_estimate()` to optimizer tolerance on the existing
    fixtures (conditional and `marginal_mean_diff`), the doc's note on the separate fits is removed, and timings are
    recorded; or the item closes with the numbers.
- [ ] TODO-251 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `binary-glm-mle#44618445718.1`): **C++ logistic fits in the KK conditional-logit IVWC
  Bayesian-bootstrap replicate.** `compute_weighted_estimate_ivwc` (`R/EDI/R/inference_incidence_KK_cond_logit.R`, added in
  v1.0.6-TODO-158) runs two `stats::glm.fit(family = quasibinomial())` fits per draw (discordant-pair differences and
  reservoir). Swap both for `fast_logistic_regression_weighted_cpp`, taking ssq from the inverse of the returned
  `fisher_information`, with `glm.fit` kept as the non-convergence fallback and an explicit rank check that keeps the
  current NULL when rank < p. Low priority: IVWC classes are legacy. Related to the deferred v1.2.0-TODO-213.
  - Done when: replicates agree with the current ones on the v1.0.6-TODO-158 fixture (log-OR 2.66) and B = 500 draws
    are timed before and after, or the item closes with the numbers.
- [ ] TODO-252 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `atkinson-optimal-biased-coin#44618445718.1`): **Atkinson biased coin in imbalance-vector form.** Atkinson's
  probability depends only on a = z_t' C_t^-1 v_b (C_t = Z'Z over earlier subjects, w-independent; v_b = running sum of
  treated z_i), so storing g_t = C_t^-1 z_t and h_t = z_t' C_t^-1 z_t per t makes each (draw, t) step O(p) instead of the
  current per-step LU and full inverse (`generate_permutations_atkinson_internal`, `compute_atkinson_weight_internal` in
  `R/EDI/src/generate_permutations.cpp`). Track the invertibility quantity s with the recursive-residual update and
  recompute it only where `indep_cols` changes. Memory drops to O(np). Apply when implementing the catalog's Schur-form
  plan (v1.0.5 TODO-5 / TODO-3).
  - Cross-check probabilities against the current kernel and `covadap::DABCD` on random designs, including binary
    covariates where s can reach 0.
  - Done when: assignment probabilities match to 1e-12 with fixed seeds and timings are recorded at n = 200, p = 10,
    B = 501, or the item closes with the numbers.
- [ ] TODO-253 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `blocking-partition#44618445718.1`): **Clique-equipartition MIP arm in the optimal-blocks
  reformulation benchmark.** Brixius (2025, revised 2025), "Optimal Matched Block Design for Multi-Arm Experiments",
  gives an exact clique-based equipartition MIP for the same objective as `solve_optimal_blocks`
  (`R/EDI/R/design_fixed_optimal_blocks.R`, label-based McCormick MILP, ~79 s per solve at n = 16, B = 4). Add it as a
  citation on the catalog's label-free clique-partitioning row, and as a written-out arm (y_ij, triangle rows, size rows)
  in the v1.2.0-TODO-23 benchmark next to the subset DP and the symmetry-broken label model.
  - Done when: the arm is benchmarked at n in {12, 16, 20, 24}, comparing objective values (not block ids) and solve
    times, or the item closes with the numbers.
- [ ] TODO-254 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `bootstrap-confidence-interval#44618445718.1`): **Exact early stopping of the calibrated double
  bootstrap's inner loop.** `ci_calibrated_bootstrap` (`R/EDI/R/inference_all_abstract_non_param_boot.R`) runs all 51
  inner refits for every outer resample and grid alpha. Draw the inner replicates in index-seeded chunks and stop once
  `covered[b]` is settled at every grid alpha still being scored (Nankervis-style bounds), which leaves alpha_adj and the
  CI bit-identical for a given seed. Implement with the grid hoist of v1.2.0-TODO-23; estimated 2.5-3.5x fewer inner
  refits on top of the hoist (unmeasured).
  - Done when: a regression test shows alpha_adj and the CI bit-identical to the full computation for fixed seeds and
    refit counts are profiled on the benchmark designs, or the item closes with the numbers.
- [ ] TODO-255 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `monte-carlo-test-inversion-ci#44618445718.1`; rescoped 2026-11-20): **Zhang exact CI: find the inside point (or prove the
  set empty) from the breakpoints, replacing `zhang_ci_inside_point_grid`.** Already done, not part of this item: v1.0.6-TODO-167 (owner decision) made
  `InferenceIncidExactZhang`'s exact CI the convex hull of the accepted set (Blaker 2000; Fay 2010; documented in the
  class roxygen, NEWS and `REFERENCES.md` [Blaker2000]/[Fay2010]), using the closed-form breakpoints of both
  minimum-likelihood components (`zhang_exact_pval_breakpoints`, `zhang_ci_hull_endpoint` in
  `R/EDI/R/inference_helpers_zhang.R`), so the endpoints no longer miss an outer piece of a gapped set. Still open: the
  start point the endpoint searches begin from (`zhang_ci_inside_point`) comes from 3 candidates, `optimize()`, then a
  2001-point grid plus 5 local refinements (`zhang_ci_inside_point_grid`, v1.0.6-TODO-157). A grid can miss a very
  narrow accepted window (TODO-233 found one around delta = 0 at p0 = 0.5) and then report the confidence set as empty
  (`exact_ci_empty_acceptance_set`) when it is not.
  - Replace the grid with an exact search: the combined p-value at each breakpoint (ties counted, so at least its limit
    from either side) plus its maximum within each stretch between consecutive breakpoints, where both components are
    smooth sums over fixed outcome sets. Score the breakpoints with `zhang_pval_exact_combined_vec` (one vectorised
    call; at most k + S points). The set is empty only if that maximum is at most alpha.
  - Expected effect: the CI is identical wherever the current search finds an accepted point; where the grid missed a
    narrow accepted window, the class now returns a CI instead of NA. That is a documented result change (NEWS entry).
  - Done when: every CI and empty-set verdict matches the current code on the TODO-216/TODO-233 fixtures except the
    missed-window cases (each listed, with its new CI), and the start-point search is timed before and after; or the
    item closes with the findings.
- [ ] TODO-256 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `quantile-rank-regression#44618445718.1`): **Closed-form quantile regression for covariate-free
  designs.** When the reduced design is [1, w], the fit is two group tau-quantiles (order statistics; weighted quantiles
  for Bayesian-bootstrap replicates), O(n) per group instead of an LP solve through quantreg on every randomization draw
  and replicate (`fit_quantile_model`, `compute_estimate_with_bootstrap_weights`, `shared` in
  `R/EDI/R/inference_continuous_quantile_regr.R`; `compute_estimate_with_bootstrap_weights` in
  `inference_proportion_quantile_regr.R`). Fall back to the LP when the solution is not unique (tau * n_g an integer, or
  ties at the cut), unless br's vertex choice is reproduced and tested. Fits with the native quantile kernel plan.
  - A/B bit-for-bit against `rq.fit(br)` and `rq(weights)` at n = 20-1000, tau in {0.25, 0.5, 0.75}, odd and even group
    sizes, tied y.
  - Done when: the fast path matches on all of those and timings are recorded, or the item closes with the numbers.
- [ ] TODO-257 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `rerandomization-sampling#44618445718.1`): **Exact small-n rerandomization sampler.** When
  C(n, n_T) is small (n <= ~20-24), enumerate every assignment in revolving-door Gray-code order with an O(p) incremental
  balance update, keep the acceptable set, then draw r assignments i.i.d. from it with the draw-indexed seeds: the same
  law as i.i.d. rejection sampling. Dispatch on C(n, n_T) * p against the expected rejection cost. Affects
  `rerandomization_search_cpp` (`R/EDI/src/rerandomization_helpers.cpp`) and `generate_rerandomized_w_batch` /
  `generate_one_rerandomized_w` (`R/EDI/R/design_fixed_rerandomization.R`); reuse the DesignFixedOptimal enumeration
  kernel if it is built (catalog section 12 table (a)).
  - Benchmark at n = 12-24, p = 2-10, acceptance 1e-1 to 1e-4.
  - Done when: the sampler's draws are verified uniform on the acceptable set and the dispatch rule is set from the
    timings, or the item closes with the numbers.
- [ ] TODO-258 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `rerandomization-sampling#44618445718.2`; OWNER DECISION 2026-11-20: one kernel, documented draw change): **Route every
  rerandomization path through `rerandomization_search_cpp`.** Today only even n with prob_T = 0.5 uses the C++ kernel
  (`R/EDI/src/rerandomization_helpers.cpp`: one master seed from R, then a per-candidate `RRng` stream, OpenMP,
  thread-count-invariant). Odd n and prob_T != 0.5 run in R on R's own `runif()` stream: `generate_rerandomized_w_batch`
  (`apply(U, 2, order)` per candidate, O(n log n), serial) and `generate_one_rerandomized_w`
  (`R/EDI/R/design_fixed_rerandomization.R`). Generalize the kernel to any n_T with d = M s (s_i = 1/n_T treated,
  -1/n_C control, M = L^-1 X' whitened once; abs_sum_diff standardized with the L1 norm), keeping its Fisher-Yates draws,
  per-draw-index seeding and thread-invariant merging, and delete both R paths.
  - Decided 2026-11-20 (owner): ship as a documented default change, bundled with the RNG streams change; see [DECISION-v1.2.0-TODO-258](COMPLETED_DECISIONS.md#DECISION-v1.2.0-TODO-258).
  - Benchmark against the R path at n = 51-501 (odd), p = 5-20, prob_T in {0.3, 0.5}, acceptance 1e-2 to 1e-3.
  - Done when: both R paths are gone; draws are reproducible across thread counts; a test checks that the accepted
    assignments are uniform over the acceptable set (n_T fixed, objective below the cutoff) for odd n and prob_T = 0.3;
    the NEWS entry, regenerated fixtures and timings are in.
- [ ] TODO-259 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `robust-m-regression#44618445718.1`): **Accelerate the robust-regression M-path IRLS.** The
  Huber "M" path in `fast_robust_regression_internal` (`R/EDI/src/fast_robust_regression.cpp`) is a plain fixed-point
  iteration on (beta, MAD scale), up to 26 iterations with outliers at n ~ 20, run in every KK randomization or
  bootstrap draw. Wrap it in a safeguarded SQUAREM or damped Anderson step that falls back to the plain step when the
  merit does not decrease; the fixed point is unchanged. Under the robust-regression lane, v1.2.0-TODO-3.
  - First log iteration counts in KK randomization draws; prototype only if the median is well above ~10.
  - Done when: iterations, time and |delta beta| are compared against plain IRLS and `MASS::rlm`, or the item closes
    with the iteration counts.
- [ ] TODO-260 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `robust-m-regression#44618445718.2`): **Huber-Dutter H-algorithm step for robust regression.**
  Each IRLS iteration rebuilds X'WX and refactors it (O(np^2 + p^3)) though the OLS start already factored X. The
  H-algorithm step beta <- beta + (X'X)^-1 X' sigma psi(r / sigma) reuses that factor, O(np + p^2) per iteration, but
  converges linearly and may need more iterations (Heng, Zhou & Lange, arXiv 2501.02475). Add a catalog O8 row; prototype
  for method = "M" only if v1.2.0-TODO-3 profiling targets per-iteration cost.
  - Done when: iterations and time are compared against the current W-algorithm at n ~ 50-1000, p ~ 2-10, or the item
    closes with the numbers.
- [ ] TODO-261 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44618445718, finding
  `stereotype-logit-mle#44618445718.1`): **Variable projection for the stereotype logit fit.** For
  fixed scores gamma the stereotype model is a concave multinomial logit, so the fit reduces to a (K - 2)-dimensional
  search over gamma. For K = 3, a deterministic 1-D grid over gamma with warm-started concave inner fits
  (`fast_stereotype_logit_cpp` with `fixed_idx`), then a free polish, gives the global MLE up to grid resolution with no
  random starts, versus today's up to 9 nonconcave starts (`.stereotype_full_data_multistart`,
  `.stereotype_multistart_candidates`, `.stereotype_null_refit_multistart` in
  `R/EDI/R/inference_ordinal_stereotype_logit.R`; about 3% non-global optima at n = 50). The gain is mainly reliability.
  - Prototype for K = 3 and A/B against the current multistart on the reference fixtures and simulated nulls (NLL
    attained, beta_T, wall-clock) before considering it for resampling loops.
  - Done when: it attains an NLL at least as low on every fixture with timings recorded, or the item closes with the
    numbers.
- [ ] TODO-262 (added 2026-11-20, agent, owner request; from the algorithm-research triage of run 44683751221, finding
  `survival-frailty-copula-mle#44683751221.1`): **Cheaper Hessians for the frailty and Clayton
  replicate variances.** Since v1.0.6-TODO-86 every IVWC resampling and randomization replicate of the frailty and
  copula classes computes its own variance by finite differences over all parameters, even when `fixed_idx` pins the
  two variance-component parameters and only the free block is inverted (`fast_weibull_frailty.cpp` ~L398-408).
  (1) Difference only the free coordinates in `WeibullFrailtyNormalLikelihood::hessian`,
  `ClaytonWeibullLikelihood::hessian` and `DepCensTransformLikelihood::hessian`: bit-identical SE, 2(p+2) -> 2p gradient
  evaluations (frailty) and p+3 -> p+1 (Clayton). (2) Later: a closed-form observed information for the GH frailty
  likelihood (Louis identity, Pan & Thompson 2003), folded into v1.2.0-TODO-22 with the cluster-total collapse.
  Reopens the catalog's NEW-fd-hessian row.
  - Done when: (1) is merged with a test that the SE is bit-identical, and per-replicate time for the frailty IVWC
    randomization test is benchmarked at n = 50-500 pairs; (2) is decided with those numbers.
- [x] TODO-263 (added 2026-11-23, agent; found while landing v1.2.0-TODO-207): **The observed allocation can already be
  one of the randomization reference draws, so the (b+1)/(B+1) rule counts it twice**
  - A fixed design created with a `seed` and analysed with no inference seed draws its reference allocations from the
    design seed (`effective_draw_seed()` falls back to it), and column 1 of `draw_ws_according_to_design(r)` then
    replays the realized allocation (checked 2026-11-23 for `DesignFixediBCRD` and `DesignFixedBernoulli`; not for
    `DesignFixedBlocking`, `DesignSeqOneByOneBernoulli` or `DesignSeqOneByOneKK14`). The same holds when a user passes
    the full enumeration as `permutations`. With the v1.2.0-TODO-207 rule the observed statistic is then counted twice:
    the test stays valid but is conservative, its smallest two-sided p is 4/(B+1), and at r = 201 it cannot reject at
    alpha = 0.01 (`InferenceAllSimpleAverageDiff`, iBCRD n = 20, 3,000 seeded-design datasets: size 0% at 0.01 and 4.17%
    at 0.05, vs 0.90% / 4.82% with an inference seed). Under the old b/r rule this case happened to be close to exact.
  - Decided 2026-11-23 (owner): (a) drop the replayed draw; see
    [DECISION-v1.2.0-TODO-263](COMPLETED_DECISIONS.md#DECISION-v1.2.0-TODO-263).
  - Done when: the owner picks an option and it lands with a test that a seeded design's draws do not include the
    replay (or the documentation states the conservative case), or the item closes with the numbers.
  - Done 2026-11-23 (agent, branch `rand-pvalue-plus-one`, commit 264b95ec; R only, no rebuild; Rd not
    regenerated). `rand_skip_replayed_realized_draw()`, called from `seed_global_rng_for_draws()` (so
    `generate_permutations()`, the deferred sequential-MC draws and the CI searches all get it): when the draw seed equals
    the design seed, the first draw from set.seed(seed) is consumed if it is identical to the realized w, else the RNG
    is reset; the outcome is cached on the design per (seed, w). Replay confirmed before the change for iBCRD,
    Bernoulli, cluster, binary-match, greedy, greedy D-optimal and greedy pair-switching; not for rerandomization or
    blocking. `rand_drop_realized_from_enumeration()` at the p-value entry points (`InferenceRand` and the KK GEE mixin)
    removes one copy from a supplied full enumeration (`permutations$enumeration = TRUE`, or auto-detected as the whole
    complete-randomization support; `enumeration = FALSE` disables). Size after the change: seeded designs with no inference seed, InferenceAllSimpleAverageDiff, n = 20, r = 201, 5,000 datasets each, rejection rate at alpha = 0.01 / 0.05: iBCRD 0.0098 / 0.0500, Bernoulli 0.0092 / 0.0524 (before: iBCRD 0.0000 / 0.0417 on 3,000). Full enumeration (iBCRD n = 10, N = 252, 5,000 datasets): one copy dropped 0.0048 / 0.0448 (exact b/N; min p 2/252 = 0.0079), not dropped (enumeration = FALSE) 0.0000 / 0.0350 (min p 0.0158).
    Test: `test-rand-realized-allocation-not-a-reference-draw.R`; `test-rand-pval-tie-tolerance.R` is back to the exact
    enumeration values.
