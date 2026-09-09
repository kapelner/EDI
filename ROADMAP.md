# EDI Roadmap

**Where things stand (last updated 2026-09-08):** v1.0.0 is released
([Zenodo DOI](https://doi.org/10.5281/zenodo.22170036)) and has been
submitted to CRAN; the `edi_kernels` Python package is on PyPI. Everything
below is planned, not shipped.

Each bullet summarizes one planned feature in at most a paragraph and links
to its owning plan; the authoritative scope, dependency ordering, and work
breakdowns live in
[`R/package_metadata/future_release_plans/`](R/package_metadata/future_release_plans/)
(one index file per release) and the per-feature plans in
[`R/package_metadata/new_feature_plans/`](R/package_metadata/new_feature_plans/).
Within each release, items that gate or feed other items come first; the
rest are grouped by theme. No dates are attached — each release ships when
its scope is done. Plans are statements of intent, not promises;
decision-gated items are marked as such, and items tagged *(maintenance)*
have no user-visible effect. "KK" throughout refers to the Kapelner–Krieger
family of matching designs and estimators.

---

## v1.1.0 — Inference Quality and CPU Performance

Lightened 2026-09-06: exploratory/measurement-first work, new estimator
families, and items whose consumer lives in a later release moved out to
v1.2.0 or v1.4.0, keeping this release to what its own theme — inference
quality plus the CPU/correctness core of randomization inference, plus
the no-substrate half of honest inference after model selection — actually
needs.

### Decisions and prerequisites

- **[Phase 0 decision batch](R/package_metadata/future_release_plans/release_v1_1_0.md)** —
  one sitting that settles every gated design question for the 1.x line:
  the `estimate_type` API shape, penalized-fitting (Firth/L1/L2) inference
  semantics, the bias- and test-correction family, the response-type
  yes/nos (nominal, rank-choice, semi-continuous, multivariate,
  compositional, longitudinal), and the GPU/quantum backend story. No
  code; everything below that depends on a decision cites it.
- **[Diagnostics chain](R/package_metadata/new_feature_plans/public_diagnostics_api_spec.md)** —
  a public API for convergence and optimizer diagnostics on every fit,
  built on an internal `SolverDiagnostics` component (which the Firth work
  below requires). Strictly ordered; a prerequisite for the corrections
  track.

### Corrections and higher-order inference

- **[Corrections track — core](R/package_metadata/future_release_plans/release_v1_1_0.md)** —
  better small-sample inference across the likelihood classes: expanded
  `estimate_type` values; Cox–Snell and Cordeiro–McCullagh bias
  corrections; higher-order test corrections (Cordeiro–Ferrari score,
  Lemonte gradient, Bartlett LR — one shared cumulant machinery); Firth
  penalties. (The L1/L2 penalized path, median bias correction, modified
  profile likelihood, and bootstrap-calibrated LR moved to v1.4.0 — see
  below — since none of them gate anything else here.)

### New estimators and estimands

- **[Count exposure offset](R/package_metadata/new_feature_plans/count_exposure_offset.md)** —
  `exposure =` on every count class and kernel, unlocking the standard
  rate-ratio trial analysis.
- **[Heteroskedasticity-robust standard errors](R/package_metadata/new_feature_plans/heteroskedasticity_robust_standard_errors.md)** —
  `se_type = HC0..HC3` on the OLS and risk-difference classes.

### Ordinal, incidence, and count fixes

- **[Ordinal model-coefficient randomization CIs](R/package_metadata/new_feature_plans/ordinal_model_coefficient_randomization_confidence_intervals.md)** —
  randomization-based confidence intervals (not just p-values) for the
  ordinal regression classes.
- **[Incidence randomization CIs](R/package_metadata/new_feature_plans/incidence_randomization_cis.md)** —
  exact (Zhang) randomization intervals on each estimand scale, removing
  the temporary incidence CI disable.
- **[Negative-binomial dispersion reparameterization](R/package_metadata/new_feature_plans/negbin_dispersion_convergence.md)** —
  more reliable convergence near the Poisson boundary for NegBin,
  zero-inflated NegBin, and hurdle-NegBin fits.
- **[Faster zero-one-inflated Beta resampling](R/package_metadata/new_feature_plans/fix_reusable_bootstrap.md)** —
  the jackknife/bootstrap for this class stops rebuilding its model from
  scratch per fold, with bit-identical results.

### InferenceSuite

- **[Wilkinson r-out-of-k combined evidence, Stage 1](R/package_metadata/new_feature_plans/wilkinson_combined_pval.md)** —
  a `vote_fraction` field reporting how many applicable procedures agree,
  complementing the existing Cauchy combination test, which answers only
  "does at least one detect a signal." (The decision-gated formal
  order-statistic test, Stage 2, moved to v1.4.0.)
- **[Design/inference dependence-structure guard](R/package_metadata/new_feature_plans/design_inference_dependence_guard.md)** —
  discovery currently only checks whether a design gives a class structure
  it *requires*, never whether the design imposes dependence (blocking,
  matched pairs, clustering) a class's Wald-path variance ignores. Tiered,
  not a blanket gate: exact randomization-based (`ci_method = "rand"`)
  inference is unaffected (the design's own re-randomization already
  respects the structure); a linear-contrast class (plain mean/risk
  difference) ignoring blocking or matching only ever gets *conservative*
  SEs and stays in the default comparison (a different estimand isn't
  redundancy — that's the suite's own "many valid keys" design), now with
  a real, throttled `warning()` plus a results-table flag instead of
  silence; a nonlinear-link class
  (e.g. logistic regression) ignoring blocking/matching, or any class
  ignoring clustering, risks a genuinely understated SE and is hard-gated
  behind an explicit acknowledgment on its Wald-path methods, steered
  toward the already-correct KK pair family for matched pairs. Companion
  to the cluster-robust GLMM/GEE track below, which supplies the corrected
  general-clustering alternative this guard cannot yet recommend.

### Honest inference after model selection

Moved up from v2.0.0 on 2026-09-05. The family had been slated 2.0.0
because its sample-splitting sibling needs `Design`-level splitting; the
pieces below never did.

- **[Comparative model selection + the selection-inclusive randomization test, Phase A](R/package_metadata/new_feature_plans/model_selection_framework.md)** —
  `ModelSelection(des_obj)` compares fit across the model × formula grid
  (`~w`, `~w + .`, `~w * .`) with likelihood-tier-gated criteria that
  never rank by the treatment effect, and hands off to honest inference rather than a
  p-value. The honest exit is new: make the whole choose-then-fit
  pipeline the randomization statistic and redraw treatment under the
  design, so data-driven model selection costs compute, not validity —
  exact under the sharp null for any selection rule. Every replicate
  re-runs the full pipeline — embarrassingly parallel over
  `set_num_cores()`'s fork/`mirai` pool; confidence intervals follow by
  inversion.
  Pilot scope (widened 2026-09-06 — matched-pair, cluster, and sequential
  matching-on-the-fly designs moved in from what was Phase B, since the
  package's existing `resolve_resampling_unit()` already resolves CV-fold
  units uniformly across every one of those design families, not just
  fixed ones): **every design family EDI supports**, continuous and
  binary responses, with a simulation study showing naive post-selection
  inference's Type I inflation and its removal. Naive inference on a
  selection-tainted winner is a typed refusal. Only the remaining
  response types (count, proportion, survival, ordinal) are left to
  Phase B, below.
- **[Per-model assumption diagnostics](R/package_metadata/new_feature_plans/model_diagnostics_framework.md)** —
  `ModelDiagnostics(des_obj)` runs each model's own registry-declared
  assumption battery: proportional-hazards checks for Cox,
  overdispersion for Poisson, proportionality for cumulative logit,
  separation and calibration for logistic (surfacing the package's
  existing internal separation guard as a user-visible diagnostic) —
  typed results with pre-specified gate thresholds, rendered in one
  report with the solver diagnostics' numerical rows. Checks never gate
  on the treatment effect and are in-sample, so nothing here waits on 2.0.0;
  the report warns that diagnose-then-switch is selection through the
  back door and routes to the honest exit above. Ordered after the
  diagnostics chain.

### Performance and correctness (CPU)

- **[Much faster randomization CIs for linear statistics](R/package_metadata/new_feature_plans/randomization_ci_affine_shift_reuse.md)** —
  ~20–30× on `compute_confidence_interval_rand()` for mean-difference,
  OLS, and Lin-adjusted analyses: an exact shift identity lets one null
  distribution serve the entire CI search instead of ~20–35 of them.
- **[Much faster OLS randomization distributions](R/package_metadata/new_feature_plans/ols_randomization_distr_cpp_wiring.md)** —
  ~20–50×: OLS randomization tests move from an R-level per-replicate
  loop onto an existing C++ batch kernel; multiplicative with the item
  above. Eight dead kernel exports get wired in or deleted in the same
  pass.
- **[No more silent garbage standard errors](R/package_metadata/new_feature_plans/guard_unguarded_information_inverse.md)** —
  five `with_var` kernels (NegBin, ZINB, zero-augmented Poisson ×2, Beta)
  currently return a finite but meaningless SE on a near-singular design;
  they gain the invertibility guard their siblings already have and
  return `NA` instead. Bit-for-bit on all healthy fits.
- **[Multistart for the nonconcave likelihoods, documented-failure tranche](R/package_metadata/new_feature_plans/multistart_nonconcave_likelihoods.md)** —
  the kernels with a documented failure mode (ZINB/ZIP/hurdle-NegBin in
  `(β, log θ)`, Beta) gain family-specific deterministic starts plus a
  reproducible random layer, keep the best, and report which start won.
  Bit-for-bit wherever the single start was already best, on every
  replicate fit, and on every concave kernel. (The shared infrastructure
  is built once here; applying it to the remaining kernels with no
  documented failure — GLMM/LMM/frailty, ZOIB, stereotype logit, copula
  survival, cauchit, bisquare — moved to v1.2.0.)
- **[Algorithm choice audit](R/package_metadata/new_feature_plans/algorithm_choice_audit.md)**
  *(maintenance)* — a per-kernel survey of whether the *chosen
  algorithm*, not just its implementation, is the best known one for its
  problem, with citations and a keep/prototype/adopt verdict per row. A
  pure document, kept here since one of its Adopt verdicts (Brent, below)
  ships in this release; the A/B testing harness its Prototype verdicts
  need, and the two candidates gated on it (Robbins–Monro CI search,
  EM-then-Newton hybrid start for ZINB/ZIP), moved to v1.2.0.
- **[Brent's method for score / gradient / Bartlett-LR confidence intervals](R/package_metadata/new_feature_plans/brent_ci_inversion.md)** —
  these CIs invert a deterministic p-value function by pure bisection
  while the likelihood-ratio CI beside them already uses Newton; Brent's
  method on the same bracket needs ~4× fewer constrained refits per bound
  and returns the same bound within tolerance. No approximation, no
  A/B gate — the existing CI tests are the check.
- **[Benchmark noise floor and regression gate](R/package_metadata/new_feature_plans/performance_profiling_and_upgrades.md)**
  *(maintenance)* — the measurement infrastructure needed to substantiate
  this release's own randomization-CI speedup claims. (Everything else in
  the performance measurement program — the compiler optimization-report
  sweep, strided-access and linear-algebra audits, BLAS backend
  visibility, and the SIMD/fixed-size-Eigen/LTO/memory-layout lanes that
  consume them — moved to v1.2.0, an exploratory program with no v1.1.0
  consumer.)
- **[Consolidate duplicated parallelization primitives](R/package_metadata/new_feature_plans/consolidate_parallelization_code.md)**
  *(maintenance)* — no output/behavior change. `Inference$par_lapply` is
  already a shared parallel-map helper reused by ~10 bootstrap/
  randomization classes; `SimulationFramework$run()` and
  `InferenceSuite$run_all_inference()` hand-roll their own fork/`mirai`
  backend selection instead, for real reasons (a stateful copy-on-write
  worker pool with rolling dispatch, and a zero-blast-radius
  `mcparallel`/PID-kill dispatcher, respectively) that this item does
  *not* try to unify. It does extract the sub-pieces that duplicate
  across all three and have already drifted apart: two inconsistent
  mirai-daemon-lifecycle implementations, a mirai poll/liveness-check/
  stop-on-death loop written out more than once, and worker
  single-threading setup defined once for persistent clusters and
  hand-rederived once for forked child processes.
- **[Harden the capability/slow-path registries](R/package_metadata/new_feature_plans/harden_registry.md)**
  *(maintenance)* — no output/behavior change. Eliminates a hardcoded
  "migration debt" capability-exclusion list in
  `inference_class_registry.R`, verified redundant by a 39-class audit
  against the package's one permanent exclusion registry, which absorbs
  its three entries; a test-only drift check replaces the dynamic
  resolver that was prototyped and rejected as unneeded runtime risk.
  Also documents, but defers, two larger duplicated-fact issues found
  along the way: `comprehensive_tests.R`'s own pre-registry hardcoded
  slow-path exclusion lists, and a still-open recheck of ~82
  already-registry-backed slow-path entries for staleness.

---

## v1.2.0 — Performance, Kernels, and Engines

Gained several items from v1.1.0's 2026-09-06 lightening pass — each
either consumes this release's own kernel work or is exploratory
measurement work with no v1.1.0 consumer.

### New native kernels

- **[Quantile-regression C++ kernel](R/package_metadata/new_feature_plans/quantile_regression_cpp_kernel_spec.md)** —
  a native LP-based kernel replacing the delegated fit: faster quantile
  regression with weighted variants and standard errors, verified by a
  parity suite.
- **[Count quantile regression](R/package_metadata/new_feature_plans/count_quantile_regression.md)** —
  quantile treatment effects for count responses
  (`InferenceCountQuantileRegr` and its KK variants) via Machado & Santos
  Silva (2005) jittering; moved here from v1.1.0 to ship beside the
  native kernel above rather than ahead of it.
- **[Ordinal GEE C++ kernel](R/package_metadata/new_feature_plans/ordinal_gee_cpp_kernel_spec.md)** —
  a native estimating-equations kernel for the ordinal GEE classes.
- **[Ordinal Bayesian-bootstrap completions](R/package_metadata/future_release_plans/release_v1_2_0.md)** —
  native weighted refits for the ordinal KK GEE, stereotype-logit, and
  adjacent-category-logit classes (replacing surrogates), each enabled
  only after draw-level parity tests; moved here from v1.1.0 to share
  machinery with the ordinal GEE kernel above.

### Algorithmic speedups

- **[OLS randomization kernel rewrite](R/package_metadata/new_feature_plans/ols_distr_kernel_fwl.md)** —
  a further ~5–10× inside the batch kernel wired in v1.1.0, via the
  Frisch–Waugh–Lovell decomposition (factor the fixed covariates once;
  each replicate reduces to two masked sums and one small solve).
- **[Faster sequential matching designs](R/package_metadata/new_feature_plans/kk14_incremental_covariance.md)** —
  ~5–10× on a KK14 matching-on-the-fly run: the covariance of past
  subjects is updated incrementally per arrival instead of recomputed
  from scratch, with the KK21 designs sharing the benefit.
- **[Robust-regression performance](R/package_metadata/new_feature_plans/robust_regression_perf_optimization_spec.md)** —
  profile-first optimization of the robust regression paths.
- **[Cold starts](R/package_metadata/new_feature_plans/cold_starts.md)**
  *(maintenance)* — audit and tighten how every fit family initializes its
  optimizer.

### Engines and machine dispatch

- **[Greedy engine merge](R/package_metadata/new_feature_plans/design_fixed_greedy_pair_switch_merge.md)** —
  unify the greedy design-search engines behind one implementation
  (deprecation shims, not deletions); its `pair_mode` finding decides how
  v1.3.0 handles matched pairs under unequal allocation.
- **[Architecture-specific CPU and memory engines](R/package_metadata/new_feature_plans/arm_hardware.md)** —
  AArch64/Apple/Graviton detection and dispatch
  ([ARM](R/package_metadata/new_feature_plans/arm_hardware.md)),
  Intel AMX capability checks and GEMM thresholds
  ([Intel](R/package_metadata/new_feature_plans/intel_hardware.md)), and
  NUMA/huge-pages tuning
  ([memory](R/package_metadata/new_feature_plans/memory_side_improvements.md));
  benchmark evidence required before any default changes.

### Moved in from v1.1.0's lightening pass (2026-09-06)

- **[Performance measurement program, remainder](R/package_metadata/new_feature_plans/performance_profiling_and_upgrades.md)**
  *(maintenance)* — everything past the noise floor and regression gate
  that stayed in v1.1.0: compiler optimization-report sweep,
  strided-access and linear-algebra audits, BLAS backend visibility,
  end-to-end/R-layer profiling, parallelism/BLAS tuning, roofline.
- **[More SIMD optimization](R/package_metadata/new_feature_plans/more_simd_optimization.md)**
  *(maintenance)* — implements what the measurement program's diagnostics
  find (`__restrict` sweep, a verified fast-math subset, aligned copies,
  branch-free comparisons, `-fopenmp-simd`).
- **[Fixed-size Eigen specializations for small p](R/package_metadata/new_feature_plans/fixed_size_eigen_small_p.md)**
  *(maintenance)* — compile-time-`p` dispatch for the per-iteration
  algebra; gated on a microbenchmark showing a ≥10 % whole-fit win.
- **[LTO re-evaluation](R/package_metadata/new_feature_plans/lto_reevaluation.md)**
  *(maintenance)* — re-measure the measured-negative `-fno-lto` default
  under the current toolchain and write down the rule for flipping it.
- **[Memory-layout audit](R/package_metadata/new_feature_plans/memory_layout_row_major_irls.md)**
  *(maintenance)* — measure the sample size at which matrix layout starts
  to matter (predicted well beyond the designed-experiment regime) and
  record the kernel-author policy.
- **[Full test-coverage triage](R/package_metadata/new_feature_plans/full_test_coverage.md)**
  *(maintenance)* — line coverage from 64.8 % into the high 90s, then a
  CI coverage floor; a rolling, non-gating track with no dependency on
  anything else.
- **[Inference-object serialization](R/package_metadata/new_feature_plans/save_load_api.md)** —
  make a fitted `Inference` object a supported `saveRDS()`/`readRDS()`
  unit, so expensive resampling state (a bootstrap distribution built
  from thousands of refits of a slow model such as zero-one-inflated
  beta) survives a session instead of being extracted as plain data. The
  v1.0.0 Design-side serialization contract extends to `Inference` and
  its components; the `owns_state` audit is cheapest after every v1.1.0
  item that adds `Inference`-side state (including the `ModelSelection`
  provenance object) has landed.
- **[Multistart for the nonconcave likelihoods, remainder](R/package_metadata/new_feature_plans/multistart_nonconcave_likelihoods.md)** —
  the same shared infrastructure v1.1.0 builds for the documented-failure
  kernels, applied to the kernels with no documented failure: GLMM / LMM
  / frailty marginal likelihoods, ZOIB, stereotype logit, Clayton-copula
  and dependent-censoring survival, ordinal cauchit, and Tukey-bisquare
  robust regression.
- **[Algorithm-choice A/B testing harness](R/package_metadata/new_feature_plans/algorithm_ab_testing_framework.md)** —
  paired benchmarks, a correctness equivalence check, and a
  fixed-in-advance rule requiring a genuine win on at least one
  documented data regime plus zero accuracy regression anywhere, before
  a default changes. Two candidates gated on it:
  **[Robbins–Monro CI search](R/package_metadata/new_feature_plans/garthwaite_buckland_ci_search.md)**
  (a stochastic-approximation alternative to bisection for
  randomization/bootstrap CI bounds — not offered for v1.1.0's
  affine-shift tier-1 classes, where each p-value is already O(r)
  arithmetic and cannot be beaten by a stochastic driver) and an
  **[EM-then-Newton hybrid start for zero-inflated mixtures](R/package_metadata/new_feature_plans/em_algorithm_zero_inflated_mixtures.md)**
  (ZINB/ZIP), aimed at the failure mode where the joint optimizer runs
  away on non-overdispersed data.

---

## v1.3.0 — Design Extensions from Practice

- **[Unequal allocation](R/package_metadata/new_feature_plans/unequal_allocation_matching_greedy_minimization.md)** —
  `prob_T ≠ 0.5` on matched and greedy designs, `target_ratio` on
  sequential coins, a `neyman_prob_T()` helper, and per-stratum
  allocation; the route depends on v1.2.0's greedy-merge `pair_mode`
  finding (allocation-ratio-preserving coin rules follow in 2.0.0).
- **[Cluster-level covariate-balancing designs](R/package_metadata/new_feature_plans/cluster_level_covariate_balancing_designs.md)** —
  `cluster_col =` on every fixed balancing design (constrained cluster
  randomization, pair-matched clusters, matched quadruplets) plus
  `DesignFixedClusterSaturation`.
- **[Sequential many-by-many design family](R/package_metadata/new_feature_plans/design_seq_many_by_many.md)** —
  `DesignSeqManyByMany` with Bernoulli / CRD / Blocking / Rerandomization
  (Zhou et al. 2018) / Atkinson members: batches of subjects arriving over
  time, a new timing family between fully-fixed and one-by-one.
- **[Registry and capability metadata sweep](R/package_metadata/future_release_plans/release_v1_3_0.md)**
  *(maintenance)* — `supports("cluster")`, the `prob_T` capability, the
  new `timing_family`, and the design-side vignette update.

---

## v1.4.0 — Response and Data Extensions

### Survival track (ordered)

- **[Survival plumbing sweep](R/package_metadata/future_release_plans/release_v1_4_0.md)** —
  the hard `dead → uncensored` rename across R, C++, and Python (the only
  planned 1.x-era break), done in the same pass as competing-risks
  `event_type` storage; existing survival analyses reproduce bit-for-bit.
- **[Competing risks](R/package_metadata/new_feature_plans/competing_risks_response.md)** —
  cause-specific Cox and log-rank, CIF/Gray/RMTL, and Fine–Gray (via
  `cmprsk`, if the dependency is accepted). Decision-gated.
- **[Cure-fraction (mixture-cure) survival inference](R/package_metadata/new_feature_plans/cure_fraction_survival_inference.md)** —
  a standalone inference class on the existing survival type.
  Decision-gated.
- **[Weibull-frailty k-strata](R/package_metadata/new_feature_plans/full_glmm_for_weibull_frailty.md)** —
  the full GLMM generalization of the Weibull frailty model beyond two
  strata.
- **[Interval-censored second wave](R/package_metadata/new_feature_plans/interval_censored_survival_response_type_report.md)** —
  semiparametric additions for interval-censored responses.
  Decision-gated.
- **[Survival quantile regression](R/package_metadata/new_feature_plans/survival_quantile_regression.md)** —
  quantile treatment effects under general interval censoring via a
  self-consistent EM estimator, plus KK variants.

### Other response and data extensions

- **[Censoring track](R/package_metadata/new_feature_plans/censored_continuous_response.md)** —
  censored continuous responses, then
  [censored count responses](R/package_metadata/new_feature_plans/censored_count_response.md),
  then semi-continuous responses if decided yes.
- **[Encouragement designs / CACE](R/package_metadata/new_feature_plans/encouragement_design_cace.md)** —
  record treatment received alongside treatment assigned, and infer the
  complier-average causal effect.
- **[Treatment–covariate moderation](R/package_metadata/new_feature_plans/treatment_covariate_moderation.md)** —
  moderation analysis on the existing classes.
- **[Missing outcomes](R/package_metadata/new_feature_plans/missing_outcome_handling.md)** —
  principled handling of missing responses beyond the current
  NA-filtering.

### Moved in from v1.1.0's lightening pass (2026-09-06)

New estimator families, a grab-bag of new estimands, and the corrections
track's non-gating tail — off-theme for v1.1.0's inference-quality-plus-
CPU-performance release, at home beside this release's other new
estimands and response-type work.

- **[Corrections track — tail](R/package_metadata/future_release_plans/release_v1_4_0.md)** —
  the L1/L2 penalized path, median bias correction, modified profile
  likelihood, and bootstrap-calibrated LR (if approved) — everything
  beyond v1.1.0's shared-cumulant-plus-Firth core.
- **[KK one-stage Beta-regression estimator](R/package_metadata/new_feature_plans/kk_beta_regression_one_lik_derivation.md)** —
  a joint-likelihood matched-pairs + reservoir estimator for proportion
  responses, prototyped against a glmmTMB-reuse path before the native
  Gauss–Hermite backend ships.
- **[Small estimand additions](R/package_metadata/new_feature_plans/small_estimand_additions.md)** —
  Hedges' g, win odds / Brunner–Munzel, Mantel–Haenszel OR/RD,
  non-inferiority/equivalence conveniences, unconditional QTE, and a
  log-link QMLE path for non-negative continuous responses.
- **[NegBin mixture marginal estimands](R/package_metadata/new_feature_plans/marginal_estimand_report.md)** —
  extend `set_estimand("marginal_*")` to the zero-inflated and hurdle
  negative-binomial classes.
- **[Wilkinson r-out-of-k combined evidence, Stage 2](R/package_metadata/new_feature_plans/wilkinson_combined_pval.md)** —
  the formal, dependence-robust-calibrated r-th-order-statistic test,
  gated on deciding whether its bootstrap/permutation null-calibration
  cost is worth it; Stage 1's `vote_fraction` field already shipped in
  v1.1.0.

### InferenceSuite summaries

- **[Model-averaged estimate/CI](R/package_metadata/new_feature_plans/model_averaged_estimand_report.md)** —
  a reportable model-averaged point estimate and CI across applicable
  models (Buckland/Burnham/Augustin variance), complementing the
  existence-style combined tests with an actual number.
- **[Multiplicity-adjusted results table](R/package_metadata/new_feature_plans/multiplicity_adjusted_results_table.md)** —
  Holm (always valid) and Benjamini–Hochberg (gated on a dependence
  calibration check) applied to `results_table`'s rows: which specific
  rows survive correction.
- **[Selective (post-selection) inference, pilot](R/package_metadata/new_feature_plans/selective_inference_post_selection.md)** —
  p-values and CIs that remain valid after picking the best of k models,
  piloted on one class (OLS) to price the approach before deciding on a
  broader rollout versus 2.0.0's sample-splitting sibling. Its
  design-based variant — the rejection-sampled conditional randomization
  test, which needs no selection-rule geometry — is unblocked by v1.1.0's
  selection-inclusive test and may ship there as a stretch item.

### Faster randomization and design kernels

All produce identical results to today's code unless noted.

- **[Wilcoxon randomization tests ~3–4× faster](R/package_metadata/new_feature_plans/wilcox_hl_kernel_hoisting.md)** —
  the Hodges–Lehmann kernel stops re-sorting fixed data every replicate
  and stops its median search ~4× earlier; bit-identical.
- **[Ridit randomization tests ~8–10× faster](R/package_metadata/new_feature_plans/ridit_kernel_level_slots.md)** —
  the default control-referenced ridit stops rebuilding its level map per
  replicate; bit-identical.
- **[KK signed-rank tests ~4–5× faster](R/package_metadata/new_feature_plans/kk_signed_rank_hoisting.md)** —
  the matched-pair ranks are computed once instead of per replicate (only
  the signs change under permutation); bit-identical.
- **[Rerandomization scoring ~5–15× faster](R/package_metadata/new_feature_plans/rerandomization_objective_vals_gemm.md)** —
  candidate allocations are scored by one matrix product instead of
  scalar loops; equal to floating point, with a documented tie-breaking
  caveat.
- **[Small kernel hoists batch](R/package_metadata/new_feature_plans/small_kernel_hoists_batch.md)**
  *(maintenance)* — four minor speedups/dedups: greedy-search Gram
  matrix, cached ordinal level lookups, Cox bootstrap ordering, one
  shared Gauss–Hermite rule.

### Scoping

- **[Sequential-inference scoping](R/package_metadata/new_feature_plans/sequential_inference.md)** —
  the analysis plan for anytime-valid/sequential inference, implemented
  in 2.0.0.

---

## v2.0.0 — Multi-Arm, New Response Shapes, and Backends

### Decisions and substrate

- **[Decision batch](R/package_metadata/future_release_plans/release_v2_0_0.md)** —
  every gated 2.0.0 track: the K-arm KK research question, each
  response-shape decision, GPU/quantum backends.
- **[Longitudinal response type](R/package_metadata/new_feature_plans/longitudinal_repeated_measures_response_type_report.md)** —
  first, because it is the substrate for cluster GLMM/GEE and
  multi-period designs; then **multivariate**, **compositional**, and
  **rank/choice** response types in that order (nominal only if its
  recorded "no" recommendation is overturned).

### Major tracks

- **[Multi-arm designs](R/package_metadata/new_feature_plans/multi_arm_designs.md)** —
  K-arm designs and inference on the existing factory.
- **[Sequential inference and response-adaptive randomization](R/package_metadata/new_feature_plans/response_adaptive_randomization.md)** —
  implement the v1.4.0 scoping output, then two-arm RAR on top of it.
- **[Cluster-robust GLMM/GEE inference](R/package_metadata/new_feature_plans/cluster_robust_inference_glmm_gee.md)** —
  after the longitudinal extraction. Decision-gated.
- **[Mediation analysis](R/package_metadata/new_feature_plans/mediation_analysis.md)** —
  after v1.4.0's treatment-received plumbing. Decision-gated.
- **[Theoretical-design backlog](R/package_metadata/new_feature_plans/sequential_design_classical_completions.md)** —
  classical sequential-coin completions (with the
  allocation-ratio-preserving rules),
  [rerandomization criterion variants](R/package_metadata/new_feature_plans/rerandomization_criterion_variants.md),
  [optimal-design objective extensions](R/package_metadata/new_feature_plans/optimal_design_objective_extensions.md),
  and the
  [Gram–Schmidt walk / online balancing family](R/package_metadata/new_feature_plans/gram_schmidt_walk_and_online_balancing.md)
  with its two simulation studies.
- **[Causal forest and Bayesian tree inference](R/package_metadata/new_feature_plans/causal_forest_inference.md)** —
  a heterogeneous-treatment-effect estimand and capability contract, a
  randomized-design forest path, then design-aware resampling modes and
  BART/BCF posterior adapters.

### Model-selection honesty

The diagnostics and the selection-inclusive randomization test moved to
v1.1.0 (see "Honest inference after model selection" there), and as of
2026-09-06 so did every design family `ModelSelection` covers — matched-
pair, cluster, and sequential matching-on-the-fly designs included, once
it turned out the package's existing `resolve_resampling_unit()` already
resolves CV-fold units uniformly for all of them (it dispatches on
matching/clustering/blocking structure, not on whether treatment
assignment was fixed-upfront or sequential — the same function the
bootstrap already relies on for these designs). What remains here is only
what didn't move: the part that's a genuinely separate, harder problem
(sample splitting, below) plus this feature's own now-much-smaller
remainder.

- **[Comparative model selection, Phase B](R/package_metadata/new_feature_plans/model_selection_framework.md)** —
  narrowed 2026-09-06 to just the response types Phase A's pilot doesn't
  reach (count, proportion, survival, ordinal) and the spline/flexible
  grid entries; no design-family work remains here (that moved to
  v1.1.0). An earlier version of this item claimed it shared its CV-fold
  substrate with sample splitting below — that was a conflation between
  two different requirements (this item's own need is much weaker) and
  has been corrected; whether the response-type remainder still belongs
  in v2.0.0 or fits this file's v1.4.0 response-and-data-extensions theme
  better is an open question, not yet resolved.
- **[Sample-splitting / data-carving model selection](R/package_metadata/new_feature_plans/sample_splitting_model_selection.md)** —
  pick the winning model on a selection half, test it on a confirmation
  half at full alpha; needs real `Design`-level splitting (thorny for
  matching-on-the-fly designs), which is why it is 2.0.0 scope. Data
  carving is gated on the measured power cost.

### Backends and bindings

- **[Compute backends](R/package_metadata/new_feature_plans/gpu_optimizations.md)** —
  the GPU dispatch architecture first, the
  [quantum QUBO-export hook](R/package_metadata/new_feature_plans/quantum_upgrade.md)
  second (see the README's "Why `EDI` targets the CPU" section for why
  both are optional accelerators for specific workloads, not the fitting
  path), then an optional
  [NPU graph/runtime adapter](R/package_metadata/new_feature_plans/npu_ai_engine_optimizations.md).
- **[Shared C++ inference backend](R/package_metadata/new_feature_plans/migrate_EDI_into_shared_cpp_backend.md)** —
  a stable ABI with a dual-backend compatibility window, the substrate
  for bindings beyond R and Python.
- **[Additional language bindings](R/package_metadata/new_feature_plans/more_language_bindings.md)** —
  only after the shared backend's ABI, release, and ownership decisions
  are complete.

### Breaking changes

- **[Deletions and migrations](R/package_metadata/future_release_plans/release_v2_0_0.md)** —
  the deprecated greedy classes are removed, and every accumulated
  1.x → 2.0.0 contract break ships with a documented deprecation path and
  a migration guide.
