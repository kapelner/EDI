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
`../new_feature_plans/cross_platform_reproducibility.md → Release-to-release
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
  (`../new_feature_plans/cross_platform_reproducibility.md →
  Release-to-release equivalence`, since 2026-10-15); otherwise each ships
  either opt-in (configure flag / fit argument) or as an explicitly
  documented default change; `→ TODO-156`
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
  bounds; not offered for `release_v1_0_5.md → TODO-2`'s (moved 2026-09-23
  from `release_v1_1_0.md → TODO-17o`) tier-1
  classes, whose `p(δ)` is O(r) arithmetic after that item lands and
  cannot be beaten by a stochastic-approximation driver; A/B corpus
  stratified on `supports_additive_delta_shift()`) and
  `em_algorithm_zero_inflated_mixtures.md → TODO-1..5` (EM-then-Newton
  hybrid start for ZINB/ZIP, TODO-6/ZOIB deferred until TODO-2/3 validate
  the pattern; composes with TODO-20's multistart as one more
  deterministic start).

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
  call** — `../bug_fix_plans/permutation_signature_once.md → TODO-1..7`.

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
  - **Decision D1 (resolved 2026-10-13, user decision): option (b).** Source
    strings may now also use the Eigen-typed `user_compiled_fns.h`
    signature. Those sources, and XPtrs, get the C++ loop. Existing
    Rcpp-typed sources are unchanged, so the change is additive. Making the
    Eigen signature the only one is breaking and is deferred to
    `release_v2_0_0.md → TODO-7b`.
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

- [ ] ~~TODO-35~~ **→ moved 2026-10-20 to `release_v1_3_0.md → TODO-5..6`** (user decision; split into a contract item and a single Incidence GLM pilot item, the other eight families going to v2.0.0): `ModelDiagnostics` — declaration contract + pilot batteries.

- [ ] TODO-36 (added 2026-11-09, user decisions throughout): **Published monthly calibration study: size,
  coverage, null bias and power, every inference class on every applicable design.** Replaces the nightly +
  Saturday `.github/workflows/calibration-fast-tier.yml` monitor (design: `../new_feature_plans/calibration_gates.md
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
  - **Running:** free GitHub-hosted runners only (owner ruling: no self-hosted or paid runners). One campaign per
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
    figures and a README section report it, never gated (plan `../new_feature_plans/calibration_convergence_slopes.md`).
  - **Rate-derived gate and `analyze` job (v1.0.5 TODO-200 / TODO-201, 2026-11-10):** the step schedule is replaced by min(0.10, 0.05 + c n_eff^-a) from the registry's order; analysis is its own job between `shards` and `publish` (analysis scripts from the run's commit, both commits recorded; only `Gate verdict` is a statistical red, all other failures are annotated "Calibration CI bug"); each campaign README is a master plus generated sub-pages (plan `../new_feature_plans/calibration_rate_derived_gate.md`).
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
(`../new_feature_plans/cross_platform_reproducibility.md → Release-to-release
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
