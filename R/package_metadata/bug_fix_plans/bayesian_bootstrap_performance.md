# Bayesian Bootstrap Performance: Parallel Scaling and Native Weighted Refits

> **Depends on:** nothing architectural. Touches the shared resampling
> machinery (`inference_all_abstract_bayesian_bootstrap.R`,
> `inference_all_abstract_non_param_boot.R →
> compute_reusable_bootstrap_worker_distribution()`,
> `inference_all_abstract.R → par_lapply()`), the parallel dispatch
> blocklist (`globals.R → get_parallel_dispatch_policy()`), and the
> R-side weighted refit helpers (`globals.R →
> weighted_cox_bootstrap_surrogate_fit()` /
> `weighted_weibull_bootstrap_surrogate_fit()`, the `lm.wfit` and
> `rq.fit` call sites). Does not depend on
> `../new_feature_plans/consolidate_parallelization_code.md`
> (`release_v1_1_0.md → TODO-18`). The two meet only where `par_lapply`'s
> mirai branch calls `ensure_mirai_daemons`. This plan ships first
> (v1.0.5), so TODO-18 rebases onto it, except for the conditional
> pull-in described under TODO-2.
> **Release target: v1.0.5** (`release_v1_0_5.md → TODO-57`).

Written 2026-10-07, user decision. Grew out of the `bayesboot` comparison
benchmark for the Bayesian CRAN Task View proposal
(`marketing_plans/cran_task_view_proposals.md`, draft #13). Moved from
`new_feature_plans/` and v1.1.0 (`TODO-39`) to here and v1.0.5 the same
day (user decision). Under the 2026-09-23 split rule this is a fix to a
misfiring performance path that already shipped, not new capability.

## Why

EDI offers the Bayesian bootstrap on 94 inference classes. Against
`bayesboot` (n = 500, B = 1000, same data and estimator), EDI is much faster
where the refit uses EDI's weighted C++ kernel: beta regression is 24x
faster, negative binomial 16x and proportional odds 12x. It is slower for
Cox (0.82x), Weibull (0.91x), median regression (0.95x) and the difference
in means (0.35x). When both packages get 3 cores, `bayesboot` speeds up
2–2.5x, while EDI stays flat or gets *slower*. Every lead shrinks, and OLS
goes from 2.2x to 1.0x. The raw numbers are in
`marketing_plans/bb_bench2_results.txt`, produced by
`marketing_plans/bb_bench2.R`.

The Bayesian bootstrap path does have a parallel branch, so this is not
"missing parallelism". It is parallelism that is either switched off or
costs more than it saves, plus refits that go through R where C++ kernels
exist or could exist.

## Findings (measured 2026-10-07, EDI 1.0.2 CRAN source build, n = 500)

Measurement scripts are scratch copies of `bb_bench2.R`'s setup that time
1 vs. 3 cores at B = 1000 and 5000, plus an `Rprof` breakdown. The default
backend was the fork cluster built by `set_num_cores(3)`.

**F1. The serial blocklist covers the classes that would benefit most.**
`get_parallel_dispatch_policy()$bootstrap` forces serial dispatch for
`^InferenceIncid`, `^InferenceSurvival(?!.*KK)` and
`^InferenceAllKKWilcoxIVWC$`, and for the whole `incidence` response type.
So logistic, Cox, Weibull and every other non-KK survival class always run
on one core, whatever `num_cores` is.

- The roxygen docs call the table a *correctness* fact ("not currently
  parallel-safe"), and `tune_EDI_for_this_machine()` is barred from
  touching it.
- The runtime reason string says "forced serial by benchmark policy".
- The entries predate this repository (present in the initial commit
  `ff079d54`, 2026-08-10). No plan or comment records which hazard each
  entry guards against.
- With the blocklist overridden (`edi_env$parallel_dispatch_policy_override`),
  Cox ran **1.87x faster at B = 1000 and 2.08x at B = 5000** on 3 cores. No
  errors or hangs were seen, but the values were not compared against the
  serial run.

**F2. For cheap refits, parallel dispatch is a net loss, and the loss grows
with B.**

| Case | B | 1 core | 3 cores | Scaling |
|---|---|---|---|---|
| OLS | 1000 | 1.02 s | 1.11 s | 0.92x |
| OLS | 5000 | 2.39 s | 3.82 s | 0.63x |
| Logistic (blocklist overridden) | 1000 | 0.81 s | 1.28 s | 0.63x |
| Logistic (blocklist overridden) | 5000 | 3.94 s | 4.41 s | 0.89x |

An overhead that scales with B points to data transfer, not worker
startup. By code reading:

- `compute_reusable_bootstrap_worker_distribution()`'s `run_chunk` closure
  captures the full `draws` list, plus `self` and `private`.
- `par_lapply` splits the work into `4 × n_cores` chunks and hands
  `RUN_CHUNK` (which wraps `run_chunk`) to `parallel::parLapply`.
- `parLapply` serializes the function and its environment with every job.
- So each of the 12 jobs ships **all B draws**, about 6.3 MB per 1000
  draws at n = 500, plus the inference object (about 1.4 MB serialized).
  That is roughly 100 MB of serialization at B = 1000 and 400 MB at
  B = 5000, for about 0.5–2 s of actual compute.

This is still a hypothesis; TODO-2 confirms it by measuring bytes per
task. The same function backs the nonparametric bootstrap and the
jackknife (`compute_bootstrap_distribution_with_reused_workers`,
`compute_jackknife_distribution_with_reused_workers`), which fits the
finding in `benchmark_model_fits.md` (2026-10-07 extension) that EDI's R6
resampling paths are slower than `boot`.

**F3. The "is parallel worth it" gate cannot say no.**
`approximate_bayesian_bootstrap_distribution_beta_hat_T()` runs one warmup
iteration, times a second, and goes parallel when
`t_warmup × B > fork_overhead_estimate × cores`.

- The timed warmup builds a fresh worker (`create_bootstrap_worker_state()`
  → `duplicate()`, which costs 7–10 ms), so it measures worker creation,
  not the 0.3–0.7 ms per-draw refit. That inflates the estimate 10–30x.
- With a fork cluster up, `fork_overhead_estimate` is 0.01 s, so the
  threshold is 0.03 s for 3 cores.
- Net effect: the gate passes for essentially any B, including the cases
  in F2 where parallel loses.

**F4. Several refit engines are R calls, rebuilt per draw.**

| Engine | Classes using it | Per-draw cost |
|---|---|---|
| `weighted_cox_bootstrap_surrogate_fit()`: builds a `data.frame` and a formula, then `do.call(survival::coxph, …)` | CoxPH, StratCox, KK StratCox, KK LWA Cox, DepCensTransform | 5.4 ms; `concordancefit` alone is ~20% of the bootstrap (an output never used here) |
| `weighted_weibull_bootstrap_surrogate_fit()`: same pattern with `survival::survreg` | Weibull, KK Weibull marginal, both Weibull-frailty GLMMs | not profiled separately |
| `stats::lm.wfit` | OLS, Lin, KK OLS one-lik, risk difference, KK robust one-lik; also starting values in beta/ZOIB | `lm.wfit` is ~30% of OLS bootstrap time; the rest is wrapper overhead |
| `quantreg::rq.fit` | continuous and proportion quantile regression | the refit itself is fine; this is the "matches `bayesboot`" row |

`fast_coxph_regression_cpp` and `fast_weibull_regression_cpp` exist but
take no observation weights. `fast_ols_cpp` exists, but the weighted path
does not use it.

**F5. Per-draw R overhead swamps fast kernels.** For logistic regression,
`fast_logistic_regression_weighted_cpp` is only about 30% of the
bootstrap's time. The rest is R-side wrapping:

- `fit_with_hardened_qr_column_dropping` → `attempt_fit` → `fit_fun`;
- a `tryCatch` per draw, plus `run_isolated_weighted_refit`;
- `gc` (about 13–25% across the cases profiled);
- a byte-compile (`cmpfun`) of per-call closures in OLS.

**F6. Weight draws are generated in an R loop in the parent.**
`bayesian_bootstrap_sample_weights()` is called B times via `replicate()`,
each time looping over groups with `stats::rgamma`. Each draw also carries
a context object (about 2.2 KB). This costs 0.09–0.16 s per 1000 draws,
which is 20–30% of the whole OLS bootstrap.

## Proposal

Fix in order of payoff per unit of risk: the dispatch machinery first
(F2, F3, F6, which helps every class, the nonparametric bootstrap and the
jackknife too), then the blocklist (F1), then the refit engines (F4, F5).

**Reproducibility contract (must hold throughout).** Draws are generated
in the parent before dispatch, so the Bayesian bootstrap distribution is
identical at any core count for a given seed. Keep that:

- worker-side work may only consume draws or seeds the parent fixed;
- serial vs. parallel equality is a test, not a hope.

**Bit-for-bit vs. tolerance.** v1.0.5's standing constraint (same as v1.1.0's) requires
default behavior to reproduce 1.0.x bit-for-bit unless a plan documents a
default change.

- TODO-2..5 and TODO-7 are bit-preserving.
- TODO-6 (and TODO-8, if pursued) swaps numerical engines, so it changes
  low-order bits of bootstrap replicates. This plan documents that as a
  default change:
  equivalence is asserted to a stated tolerance against the R engine on
  the test fixtures, the same as the existing
  `test-rcpp-fitting-equivalence.R` pattern.

## TODOs

- [ ] TODO-1: **Benchmark harness, before any change.** Promote the
  scratch timing (1 vs. 3 cores, B ∈ {1000, 5000}, OLS / logistic / Cox /
  Weibull / median regression / difference in means / beta regression) to
  `R/benchmark/` so every later TODO reports before/after on the same
  rows. Include the blocklist-override rows. Uses the installed package
  only.

- [ ] TODO-2: **Ship each worker only what it needs (F2).**
  - Pass each chunk its own slice of `draws` instead of capturing the
    full list in `run_chunk`'s environment.
  - Send the inference template once per worker (once per persistent
    fork-cluster node or mirai daemon), not once per job.
  - Measure serialized bytes per task before and after, which confirms
    or refutes F2's hypothesis.
  - Revisit `par_lapply`'s `4 × n_cores` chunk count for reusable-worker
    paths, where each chunk pays a worker creation.

  Bit-preserving. Fixes the nonparametric bootstrap and jackknife too.

  **Conditional pull-in** (2026-10-07, user decision): **if** this TODO
  ends up changing `ensure_mirai_daemons` (for example, to send the
  inference object once per mirai daemon), then first pull
  `../new_feature_plans/consolidate_parallelization_code.md → TODO-1`
  (unify the `Inference` and `SimulationFramework` copies of
  `ensure_mirai_daemons`, including the latter's 2-attempt retry) into
  v1.0.5. Do it before making the change, and record it under
  `release_v1_0_5.md → TODO-57`. That plan's TODO-2..4 stay in v1.1.0.
  Otherwise the whole of that plan stays in v1.1.0 and rebases onto this.

- [ ] TODO-3: **A gate that can say no (F3).**
  - Time worker creation and the per-draw refit separately.
  - Predict parallel time as setup + transfer + B · t_draw / cores and go
    parallel only when it beats B · t_draw.
  - Feed the constants from `tune_EDI_for_this_machine()`'s crossover
    benchmark when present.
  - An explicit user `num_cores` remains a ceiling, not a demand.

  Bit-preserving (dispatch choice never changes values, per the
  reproducibility contract).

- [ ] TODO-4: **Vectorized weight draws (F6).**
  - Generate all B draws in one `stats::rgamma` call in the parent and
    normalize per group with vectorized arithmetic.
  - Build the shared context once instead of per draw.
  - `rgamma(k)` consumes the RNG stream exactly as k sequential calls do,
    so with the group order unchanged the draws are bit-identical. Assert
    that in a test against the current implementation for subject-,
    block-, cluster- and matched-set weighting, under both
    `weighting_unit_type` values.

- [ ] TODO-5: **Audit the bootstrap serial blocklist (F1).** For each
  entry (`^InferenceIncid`, `^InferenceSurvival(?!.*KK)`,
  `^InferenceAllKKWilcoxIVWC$`, response type `incidence`):
  1. Find the hazard it guards against. Candidates: fork-after-OpenMP lock
     state (`../new_feature_plans/parallel_fork_cluster_test_safety.md`), shared mutable caches
     in worker state (the stale-worker-cache bug class fixed 2026-09-22),
     RNG use inside the refit.
  2. Run seeded serial vs. 3-core runs under both the fork cluster and
     mirai, and assert identical distributions. Use a repeated-run
     stress loop for hangs.
  3. Remove entries that pass. Keep entries that fail, with the reason
     written in the roxygen docs next to the pattern.
  4. Fix the runtime reason string ("benchmark policy") to match.

  Removing an entry changes no values (reproducibility contract). It only
  lets TODO-3's gate pick parallel. Real-daemon tests follow the existing
  `EDI_PREPUSH_NO_PARALLEL` / CI rules (they run in the sanitizer and
  valgrind jobs, not the three check jobs).

- [ ] TODO-6: **Native weighted refits for the R-engine classes (F4).**
  Each item needs an equivalence test against the R engine's weighted fit,
  plus a tolerance documented per the bit-for-bit note above.
  1. **Cox:** add observation weights to `fast_coxph_regression_cpp`
     (Efron ties, matching `survival::coxph`'s default) and the
     stratified kernel. Route `weighted_cox_bootstrap_surrogate_fit()`
     through them, keeping `survival::coxph` as the fallback on
     non-convergence.
     - Interim fallback if the kernel slips: call `survival::coxph.fit` /
       `agreg.fit` directly. That skips the per-draw `data.frame`/formula
       build and the unused concordance computation.
  2. **Weibull:** add observation weights to `fast_weibull_regression_cpp`
     and route `weighted_weibull_bootstrap_surrogate_fit()` through it,
     with `survreg` as the fallback.
  3. **OLS family:** a weighted `fast_ols_cpp` path (√w scaling plus the
     existing QR) replacing `stats::lm.wfit` at the weighted-refit sites.
  4. **Quantile regression:** lowest priority (EDI already matches
     `bayesboot` here). Measure whether calling `rq.fit` directly with
     pre-built matrices is enough before writing a kernel.

- [ ] TODO-7: **Thin the per-draw hot loop (F5).**
  - When the full-sample fit dropped no columns, call the weighted kernel
    directly for each draw and fall back to
    `fit_with_hardened_qr_column_dropping` only on failure or rank
    deficiency.
  - Move the per-draw `tryCatch` to per-chunk with an inner fast path.
  - Avoid per-call closure creation (the `cmpfun` cost).
  - Check whether the `gc` share drops once TODO-2 and TODO-4 stop
    allocating per-draw contexts.

  Bit-preserving when the fast path is the same kernel call the hardened
  path would have made.

- [ ] TODO-8 *(stretch — decide after TODO-7's numbers)*: **Batched C++
  replicate loop** for the GLM families (logistic, Poisson, probit, NB,
  beta, ordinal): one `.Call` per chunk that loops over that chunk's draws
  in C++, optionally OpenMP-parallel over draws. This only pays if TODO-7
  leaves R overhead dominant.

- [ ] TODO-9: **Re-run the comparison and update the claims.**
  1. Re-run `marketing_plans/bb_bench2.R` against the new build.
  2. Acceptance:
     - no row slower on 3 cores than on 1;
     - Cox and Weibull scale at least 1.8x on 3 cores;
     - EDI ≥ 1x vs. `bayesboot` on every row at both core counts.
  3. Update the table in `cran_task_view_proposals.md` draft #13 and its
     plan notes, and the performance section of the docs, if any claims
     changed.
  4. Unblock the Task View holds. Task View drafts #11 (HighPerformanceComputing)
     and #13 (Bayesian) are held until this ships (owner, 2026-10-07).
     - Re-measure bootstrap and randomization-test scaling with cores for
       #11's notes.
     - Rewrite #13's "does not yet gain from extra cores" sentence.
     - Ask the owner for the go-ahead to file both. Filing is outward-facing
       and never happens without it.

## Out of scope

- New Bayesian-bootstrap support for classes that lack it (for example
  the ordinal plans `../new_feature_plans/ordinal_kk_gee_bayesian_bootstrap.md`,
  `../new_feature_plans/ordinal_stereotype_logit_bayesian_bootstrap.md` and
  `../new_feature_plans/ordinal_adjacent_category_logit_bayesian_bootstrap.md` in v1.2.0).
  They inherit TODO-2..4 for free.
- Antithetic or other variance-reduction draws
  (`../new_feature_plans/algorithm_choice_audit.md`).
- The randomization-test dispatch (`rand_ci` blocklist). It has the same
  blocklist shape, but a separate audit should follow TODO-5's method.
