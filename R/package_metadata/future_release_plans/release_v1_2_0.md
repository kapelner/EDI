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
reproduces the prior release bit-for-bit.

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
  + `DesignFixedGreedyDOptimal` into `DesignFixedGreedyPairSwitch` with the
  general-`prob_T` swap-delta rederivation; **soft-deprecation only**
  (aliases + warnings for the two old names); the hard deletion is
  `release_v2_0_0.md → TODO-7`. This is the engine that 1.3.0's unequal-
  allocation and objective-extension plans extend.
- `parallel_fork_cluster_test_safety.md` — fully closed (6/6); move to
  `../finished_features/` as part of this release's housekeeping.
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
- `algorithm_ab_testing_framework.md` and its two harness-gated Prototype
  items, `garthwaite_buckland_ci_search.md` and
  `em_algorithm_zero_inflated_mixtures.md` (see `TODO-21`) — each is
  "win uncertain, validate first" exploratory work, the same character as
  the profiling lane above. `algorithm_choice_audit.md` itself (the
  survey; no code) stayed in v1.1.0 since it costs nothing and one of its
  Adopt verdicts (Brent) is already there.

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
- [ ] TODO-6: Move `parallel_fork_cluster_test_safety.md` to
  `../finished_features/`.
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
  Expected 5–10× on the kernel. **Depends on** v1.1.0's
  `ols_randomization_distr_cpp_wiring.md` (`release_v1_1_0.md → TODO-17p`)
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
  level) break the bit-for-bit default rule — each ships either opt-in
  (configure flag / fit argument) or as an explicitly documented default
  change with the equivalence tests' tolerances re-justified; `→ TODO-156`
  (Monte-Carlo early stopping) ships **opt-in only**; `→ TODO-149`
  (non-R RNG streams) changes draws under `set.seed()` and must be opt-in
  or documented as a default change. Everything else in this item ships
  no user-facing change and needs no gate. Exit criterion: every one of
  `→ TODO-136..179` has either a measured entry or a "measured and
  dropped" note, and `benchmark_model_fits.md` has been re-run.
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
  bounds; not offered for `release_v1_1_0.md → TODO-17o`'s tier-1
  classes, whose `p(δ)` is O(r) arithmetic after that item lands and
  cannot be beaten by a stochastic-approximation driver; A/B corpus
  stratified on `supports_additive_delta_shift()`) and
  `em_algorithm_zero_inflated_mixtures.md → TODO-1..5` (EM-then-Newton
  hybrid start for ZINB/ZIP, TODO-6/ZOIB deferred until TODO-2/3 validate
  the pattern; composes with TODO-20's multistart as one more
  deterministic start).

## Standing constraints

Additive; bit-for-bit defaults (kernel parity tests are the gate); every
new C++ kernel per `sexp_removal_rcppeigen_conversion_spec.md`; targeted
compile only — never `R CMD INSTALL` / `pkgbuild::compile_dll()` /
`load_all(compile = TRUE)`. **Inherited from `release_v1_1_0.md` when
TODO-11 moved here (2026-09-06):** `performance_profiling_and_upgrades.md
→ TODO-137` (libmvec, ≤4 ulp) and `→ TODO-153` (adaptive quadrature)
break the bit-for-bit default rule and ship opt-in or as a documented
default change with re-justified equivalence tolerances; `→ TODO-156`
(Monte-Carlo early stopping) ships opt-in only; `→ TODO-149` (non-R RNG
streams) is opt-in or a documented default change. TODO-21's Robbins–Monro
item is opt-in by construction (`ci_search_algorithm` argument,
default `"bisection"`) until its own A/B report clears a wider default.
