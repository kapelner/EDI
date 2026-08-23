# Ungate Strata Size for the Weibull-Frailty Survival Classes (Pairs → Arbitrary k)

> **Depends on:** the completed rename in this session
> (`InferenceSurvivalKKWeibullFrailtyIVWC`/`OneLik` → `...Normal...`,
> `InferenceSurvivalKKClaytonCopulaIVWC`/`OneLik` → `...Loggamma...`;
> `inference_survival_GLMM_weibull_frailty_normal.R` /
> `inference_survival_GLMM_weibull_frailty_loggamma.R`). No architectural
> dependency on any other open plan. **Proposed release scope: v1.1.0**
> (additive on the frozen 1.0.0 substrate) — not yet wired into
> `_master.md` or `../future_release_plans/release_v1_1_0.md`; see
> "Release scope" at the end of this document.

Date: 2026-08-23

## Purpose

Both `InferenceSurvivalGLMMWeibullFrailtyNormalIVWC`/`OneLik`
(`R/inference_survival_GLMM_weibull_frailty_normal.R`) and
`InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC`/`OneLik`
(`R/inference_survival_GLMM_weibull_frailty_loggamma.R`) currently model
within-stratum dependence **only for matched pairs (stratum size exactly
2)**. Any stratum of a different size — a singleton, or any group of 3+ —
is silently dropped into the iid "reservoir" and its dependence structure is
never modeled. This plan scopes the work to remove that restriction so both
classes correctly model shared-frailty dependence for a stratum of **any**
size k ≥ 1.

The two classes require genuinely different amounts of new work, because the
size-2 restriction is not one gate — it is baked in at different depths for
each:

- **Normal-frailty (log-normal random intercept, GH quadrature).** The
  compiled kernel is **already general over arbitrary cluster size** — no
  new numerical derivation needed. The blocker is a chain of narrower
  data-structure assumptions upstream of it (bootstrap resampling, and the
  Design layer that produces the grouping vector in the first place).
- **Loggamma-frailty (Clayton copula, closed-form Gamma frailty).** The
  compiled kernel is a **hand-derived bivariate closed form** (four
  hard-coded censoring-pattern branches). This needs a genuine
  re-derivation to the general multivariate Clayton-copula likelihood and a
  full C++ reimplementation — the hard part of this plan.

Both classes also share one prerequisite that sits **outside** either
class's own code: no `Design` in the package can currently produce, or even
accept, a matched group of size other than 2. That gap is called out
explicitly below (TODO-0) because without it, neither generalized class can
be exercised end-to-end from user code — only from directly-constructed
`m` vectors in tests.

## Current-state audit (exact gate locations)

### Normal-frailty family — already general at the math layer

- `R/EDI/src/fast_weibull_frailty.cpp:58` — `WeibullFrailtyNormalLikelihood`.
  Builds groups via `build_group_structure()` (`fast_weibull_frailty.cpp:82`),
  which sorts subjects by `group_id` and computes contiguous
  `[group_start, group_end)` spans of **any size** (`m_group_start`/
  `m_group_end`/`m_max_group_size`, `fast_weibull_frailty.cpp:70-72`). The
  per-node, per-group inner loop (`fast_weibull_frailty.cpp:171-193`,
  gradient loop `197-224`) is `for (int i = 0; i < sz; ++i)` where `sz` is
  the group's actual size — there is no `sz == 2` anywhere. This is a real
  one-dimensional-random-intercept GLMM quadrature kernel, not a
  pair-specialized one.
- `R/EDI/R/helper_survival_fits.R:478` — `.fit_weibull_frailty()` /
  `.fit_weibull_frailty_rcpp()` (line 490). Takes `pair_id` (any values),
  does `group_id = as.integer(factor(pair_id))` (line 502) and passes it
  straight through to `fast_weibull_frailty_cpp()`. No size assumption.
- `R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R` — every call site
  (`frailty_for_matched_pairs()` at line 266,
  `compute_treatment_estimate_during_randomization_inference()` at line
  143) obtains matched-subject indices via
  `split_kk_matched_reservoir_idx(private$m, private$n)`
  (`R/EDI/R/helper_matching.R:81`), which only classifies `m_vec > 0` vs.
  `== 0` — it never filters on group size. **This class's own R and C++
  code do not call `.complete_pair_index_matrix()` at all.**

So for the Normal-frailty family, the estimation math is already correct
for any k. What is *not* yet general:

- **Bootstrap resampling** (shared by both families — see below).
- **The Design layer** that produces `private$m` in the first place (TODO-0).
- Roxygen prose (e.g. `inference_survival_GLMM_weibull_frailty_normal.R:4-40`)
  says "matched pairs" throughout and needs rewriting once this ships.
- No regression test exercises a stratum size other than 1 or 2.

### Loggamma-frailty family — hard-coded bivariate closed form

- `R/EDI/src/fast_survival_models_optim.cpp:39` — `ClaytonWeibullLikelihood`.
  Constructor takes `pair_idx` as an `Eigen::MatrixXi` with **exactly 2
  columns** (`fast_survival_models_optim.cpp:42`, `m_pair_idx`). The
  likelihood loop (`fast_survival_models_optim.cpp:89-91`,
  `for (int k = 0; k < m_pair_idx.rows(); ++k) { int i1 = ...(k,0); int i2 =
  ...(k,1); ...}`) hand-differentiates **four explicit censoring-pattern
  branches** per pair — `mask00` (both censored, line 105), `mask10` (line
  118), and (by the same pattern, not shown in the excerpt read but present
  further down the file) `mask01`/`mask11`. Each branch's gradient
  contribution was worked out by hand for exactly two cluster members. This
  does not generalize by widening a loop bound — the branch structure itself
  is bivariate.
- `R/EDI/src/fast_survival_models_optim.cpp:471` —
  `get_clayton_weibull_aft_score_cpp()` and (line 495)
  `get_clayton_weibull_aft_hessian_cpp()` — both take the same `pair_idx`
  (n_pairs × 2) / `singleton_rows` pair, both call into
  `ClaytonWeibullLikelihood`.
- `R/EDI/src/fast_survival_models_optim.cpp:743` —
  `fast_clayton_weibull_aft_optim_cpp()` — the optimizer entry point, same
  signature.
- `R/EDI/R/helper_matching.R:232` — `.complete_pair_index_matrix()`:
  ```r
  pair_rows = split(which(valid), pair_id[valid])
  pair_rows = pair_rows[lengths(pair_rows) == 2L]   # drops everything != 2
  ```
  This is the explicit size-2 filter. Any stratum of size 1, 3, 4, ... is
  excluded from `pair_rows` entirely and its members fall through to
  `singleton_rows` — meaning a 3-person stratum is currently scored as
  **three independent singletons**, silently discarding its dependence.
- `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R` call sites that
  build the pair matrix and would need to switch to a general group layout:
  lines 135 (`pair_idx_m_r = .complete_pair_index_matrix(m_vec[i_matched])`),
  318-340 (`clayton_copula_for_matched_pairs()`, builds `pair_idx`/
  `singleton_rows` the same way), and 622-720 (`shared()`'s main fit path,
  same construction plus the score/Hessian/information calls that consume
  `pair_idx`/`singleton_rows` directly at lines 707/711/715/719).

### Shared bootstrap layer — hard-coded to pairs, used by both families

- `R/EDI/R/helper_matching.R:172-198` — `.init_kk_bootstrap_structure()`:
  `pr = matrix(integer(0), nrow = m_max, ncol = 2L)` then
  `pr[pid, ] = which(m_vec_int == pid)` (line 190). For any group of size
  ≠ 2 this is a **hard R error** ("number of items to replace is not a
  multiple of replacement length"), not silently wrong behavior — but it
  does mean the Bayesian-bootstrap path (used by both `IVWC` classes, per
  `contracts_mixins.R:2055-2200`'s `"BayesianBootstrap"` component) crashes
  outright on any k ≠ 2 group today.
- `R/EDI/src/bootstrap_match_indices.cpp:27` —
  `bootstrap_m_indices_internal()`: `std::array<int, 2> match_pairs[...]`
  (line 38) and `row_length = n_reservoir + 2 * m` (line 32) are both
  hard-coded to width 2. (This function backs `bootstrap_m_indices_cpp()`,
  line 76 — check whether it is actually still called anywhere live before
  touching it; it may be a superseded sibling of the function below.)
- `R/EDI/src/bootstrap_match_indices.cpp:91` —
  `draw_matching_bootstrap_sample_cpp()`: `const int out_n = n_reservoir + 2
  * m` (line 97) — the function this package's `.draw_kk_bootstrap_indices()`
  (`helper_matching.R:203`) actually calls. Same width-2 assumption.

A reusable primitive already exists for exactly this kind of ragged
grouping and is used by three other kernels:
`build_contiguous_group_layout()` (`R/EDI/src/_helper_functions_core.h:242`,
consumed by `fast_weibull_frailty.cpp:109`, `fast_logistic_glmm.cpp:118`,
`fast_clogit_plus_glmm.cpp:94`). The bootstrap kernel should be rewritten
against this same primitive rather than inventing a new ragged-array
convention.

### TODO-0 — the Design-layer prerequisite (decision required)

Neither class can be exercised end-to-end today with a stratum size other
than 2, because **no Design in the package can produce or accept one**:

- `R/EDI/R/design_fixed_binary_match.R:212-231` —
  `set_binary_match_structure_from_m()` explicitly validates and errors:
  ```r
  if (any(pair_sizes != 2L)) {
      stop("Explicit m for DesignFixedBinaryMatch must define matched pairs
  only: each pair ID must occur exactly twice.")
  }
  ```
  and its own matching algorithm (`compute_binary_match_structure()` →
  `nbpMatching::nonbimatch`, `helper_matching.R:7-46`) is a non-bipartite
  **pairwise** perfect-matching solver — it has no k-way generalization to
  call into.
- `R/EDI/R/design_seq_one_by_one_KK14.R` — matches each arriving subject to
  at most one prior unmatched subject and "guarantee[s] exactly one treated
  and one control per matched pair" (roxygen, lines 34-38) — also
  structurally pairs-only, and its within-pair randomization
  (opposite-of-match assignment) has no k-way analog either.

`is_a_kk_matching_capable()` (`R/EDI/R/design_abstract.R:130`, overridden
`TRUE` in both classes above) is a **generic capability flag** — any Design
subclass that sets it `TRUE` and exposes `private$m`/`self$m` is
automatically compatible with every "KK"-named inference class
(`inference_suite.R:39,72` gates purely on `requires_kk = grepl("KK", nm)`
+ `des_obj$is_a_kk_matching_capable()`). So a **new, additive** Design class
implementing k-way matching (its own distance-based grouping algorithm, plus
within-group treatment randomization for groups of size k) would slot in
without touching `DesignFixedBinaryMatch` or `DesignSeqOneByOneKK14` at all.

Building that new Design class is a substantial project in its own right
(a k-way non-bipartite grouping algorithm, plus a new
`draw_*_assignments_cpp()` randomization kernel analogous to
`draw_binary_match_assignments_cpp()` but for groups of k with, e.g.,
floor(k/2) treated per group) — comparable in size to
`design_seq_many_by_many.md`'s scope, and it is **not** required to make
the two inference classes themselves numerically correct or testable
(TDD in this plan constructs `m` directly, bypassing any Design — see
Testing strategy). **Decision needed before Phase 3 (Design) below is
scheduled:** ship v1.1.0 with the two inference classes generalized but only
reachable via a hand-supplied `m` on `DesignFixedBinaryMatch` with its
`pair_sizes != 2L` guard relaxed to an opt-in (smallest fix, TODO-8 below,
proposed default), or hold off on any Design change and land only the
inference-class + bootstrap generalization this cycle, leaving Design-side
k-way matching as its own future plan. This document recommends the former
(TODO-8) as in-scope for v1.1.0 — it is small (relax one validation, no new
randomization kernel) — and treats a brand-new k-way-matching Design class
as explicitly **out of scope**, deferred to its own plan.

## Mathematical basis for the Loggamma generalization

The bivariate Clayton copula currently implemented is the well-known result
of integrating a shared frailty `Z ~ Gamma(1/θ, 1/θ)` (mean 1, variance θ)
out of two conditionally-independent Weibull hazards (Clayton 1978; Oakes
1989 — already cited in the class's own roxygen,
`inference_survival_GLMM_weibull_frailty_loggamma.R:426-428`). This
construction generalizes cleanly to a cluster of any size k (Hougaard,
*Analysis of Multivariate Survival Data*, 2000, §7 — the multivariate
Clayton/Gamma-frailty family): for a cluster with cumulative hazards
`H_1, ..., H_k` and death indicators `δ_1, ..., δ_k` (d = Σδ_i deaths), the
frailty-marginalized joint density is

```
L = [ Π_{i : δ_i = 1} λ_i(t_i) ] · θ^{-d} · Γ(d + 1/θ) / Γ(1/θ) · A^{-(d + 1/θ)}

where  A = Σ_i exp(θ H_i) − (k − 1)
```

This is a direct k-term generalization of the existing pairwise
`logA = log_sum_exp_clayton(θh1, θh2)` (`fast_survival_models_optim.cpp:26`,
which computes `log(exp(a) + exp(b) − 1)` — the k=2 case of
`log(A)` above, since `k − 1 = 1`). Two things make this the right target
formula rather than a re-derivation from scratch:

1. It collapses to the existing bivariate formula exactly at k=2 (with
   `d ∈ {0,1,2}` reproducing the `mask00`/`mask10`/`mask01`/`mask11`
   branches as special cases of one general expression), so the existing
   pair-only tests become a regression check for k=2 of the new general
   code — not a separate code path to keep alive.
2. The formula depends on the cluster only through `(d, {H_i : δ_i=1},
   A)` — no per-member branching — so the C++ loop is a single pass over
   the cluster's members (via `build_contiguous_group_layout`), analogous
   in shape to `WeibullFrailtyNormalLikelihood`'s per-group loop, not an
   exponential-in-k branch table.

The score (gradient w.r.t. β, log σ, log θ) and Hessian must be re-derived
from this general form — this is real analytic work (chain rule through
`H_i = exp((log y_i − x_i'β)/σ)`, `A`, and the `Γ(d+1/θ)/Γ(1/θ)` term's
θ-derivative via the digamma function), but it is a single derivation done
once per parameter, not once per censoring pattern. The implementer should
(a) derive it symbolically (by hand or with a CAS), (b) cross-check every
partial derivative against `numDeriv::grad()`/`numDeriv::hessian()` on the
scalar log-likelihood for random k ∈ {1,2,3,5} synthetic clusters before
writing any C++, and (c) only then port to C++ — this order is enforced by
the task breakdown below.

## Task breakdown

### Phase 1 — Bootstrap kernel generalization (shared prerequisite)

**TODO-1. Rewrite `draw_matching_bootstrap_sample_cpp()` for ragged groups.**

Files:
- Modify: `R/EDI/src/bootstrap_match_indices.cpp:91-` (the live function;
  first confirm via `grep -rn "bootstrap_m_indices_cpp" R/EDI/R` whether
  `bootstrap_m_indices_internal`/`bootstrap_m_indices_cpp`, lines 27-84, are
  still called anywhere — if not, delete them in the same commit rather
  than generalizing dead code).
- Modify: `R/EDI/R/helper_matching.R:172-210`
  (`.init_kk_bootstrap_structure()`, `.draw_kk_bootstrap_indices()`).

Steps:
- [ ] Write a failing R test in a new
  `R/EDI/tests/testthat/test-kk-bootstrap-ragged-groups.R`: build
  `m_vec = c(1,1,1, 2,2, 0,0)` (one triple, one pair, two reservoir), call
  `.draw_kk_bootstrap_indices()` on a stub `des_priv` environment with that
  `m`/`n`, and assert it does not error and returns `i_b`/`m_vec_b` where
  every resampled group in the output preserves its original member's group
  size (a resampled triple contributes 3 rows sharing one new group id).
- [ ] Run it, confirm it fails with the current "not a multiple of
  replacement length" error from `helper_matching.R:190`.
- [ ] In `helper_matching.R:.init_kk_bootstrap_structure()`, replace the
  fixed `ncol = 2L` matrix with a ragged structure: `group_rows =
  split(which(m_vec_int > 0L), m_vec_int[m_vec_int > 0L])` (a named list,
  one integer vector per group, any length), stored as
  `des_priv$boot_group_rows`.
- [ ] In `bootstrap_match_indices.cpp`, replace `IntegerMatrix pair_rows`
  with a CSR-style pair of vectors — `IntegerVector group_starts` and
  `IntegerVector group_members` (flattened, ragged) — mirroring
  `build_contiguous_group_layout()`'s `start`/`size` fields
  (`_helper_functions_core.h:242`) so the R side can hand it the same shape
  the frailty kernel already produces internally. Resample **whole groups
  as units** (draw a random group index, copy all its members, assign them
  one new shared group id in the output) exactly as today, just for
  variable-width groups; `out_n = n_reservoir + sum(group sizes drawn)`.
- [ ] Update `.draw_kk_bootstrap_indices()` to pass the new CSR vectors.
- [ ] Run the failing test; confirm it passes.
- [ ] Run the existing pairs-only bootstrap tests (`grep -rl
  "draw_matching_bootstrap_sample_cpp\|\.draw_kk_bootstrap_indices"
  R/EDI/tests/testthat/`) unmodified — they must still pass bit-for-bit
  (k=2 is the existing behavior, not a new code path).
- [ ] Commit.

This phase is required before Phase 2 or Phase 3's tests can exercise a
group of size ≠ 2 through the Bayesian-bootstrap path, since both `IVWC`
classes wire `"BayesianBootstrap"` (`contracts_mixins.R:2055`, `:2116`).

### Phase 2 — Normal-frailty family (small: remove the incidental gates)

**TODO-2. Confirm and document the kernel's existing generality.**

Files:
- Modify: `R/EDI/R/inference_survival_GLMM_weibull_frailty_normal.R:4-40`
  (roxygen — replace "matched pairs" language with "matched strata of any
  size k ≥ 1" and add a short note citing `fast_weibull_frailty.cpp`'s
  `WeibullFrailtyNormalLikelihood` as already general).

Steps:
- [ ] Write `R/EDI/tests/testthat/test-weibull-frailty-normal-k-strata.R`:
  simulate n=60 subjects in 12 groups of size 5 (shared log-normal
  intercept per group, Weibull AFT margins, known β), plus a small
  reservoir, using `MASS::mvrnorm`-free direct simulation (draw one
  `u_g ~ N(0, σ_u^2)` per group, then `y_i = exp(x_i'β + σ_eps·log(-log(1
  -U_i)) + u_g)`-style AFT draw per member — follow the existing simulation
  helper pattern already used by `test-weibull-frailty-normal.R`, reusing
  its response-generation approach rather than inventing a new one). Build
  `m_vec` directly (bypassing any Design — see Testing strategy), construct
  a `InferenceSurvivalGLMMWeibullFrailtyNormalIVWC` by hand-populating the
  fields a Design would normally supply (`y`, `dead`, `w`, `X`, `m`) the
  same way any other direct-construction test in this suite does, and
  assert `compute_estimate()` is finite and recovers β within simulation
  noise, and that `compute_asymp_confidence_interval()` succeeds.
- [ ] Run it. **Expect it to already pass** (this is the "no code change
  needed" confirmation for the Normal-frailty math/R-glue layer) — if it
  fails, that means an undocumented size assumption exists somewhere in
  this class not found by the audit above, and this task becomes "find and
  fix it" instead of "confirm."
- [ ] Add a size-3 and size-1-only-reservoir variant of the same test
  (k=3 groups; all-reservoir/no-matches) to the same file for coverage
  breadth.
- [ ] Update the roxygen per above.
- [ ] Commit.

**TODO-3. Repeat TODO-2's test for `InferenceSurvivalGLMMWeibullFrailtyNormalOneLik`.**

Same file, same construction pattern, targeting the combined-likelihood
class (`inference_survival_GLMM_weibull_frailty_normal.R:886`,
`shared_combined_likelihood`). Steps mirror TODO-2 exactly; add to the same
test file as a second `test_that()` block.

### Phase 3 — Loggamma-frailty family (the hard part: new math + kernel)

**TODO-4. Derive and hand-verify the general k-cluster score/Hessian.**

No code file yet — this is a derivation task, checked against
`numDeriv::grad()`/`numDeriv::hessian()` in a throwaway R script before any
C++ is touched (do not skip this step; the existing bivariate C++ derivative
code was clearly hand-derived per branch, which is exactly the failure mode
to avoid repeating at higher k).

Steps:
- [ ] In a scratch R script, implement the scalar general log-likelihood
  from the "Mathematical basis" section above as a plain R function of
  `(beta, log_sigma, log_theta, X_cluster, y_cluster, dead_cluster)`.
- [ ] For clusters of size k ∈ {1, 2, 3, 5} with random covariates/censoring,
  verify this R function reproduces `ClaytonWeibullLikelihood`'s existing
  bivariate output (`fast_survival_models_optim.cpp:39`, callable via
  `get_clayton_weibull_aft_score_cpp`/existing R wrappers) bit-close at
  k=2, for all four censoring patterns.
- [ ] Derive `d(loglik)/d(beta)`, `d(loglik)/d(log_sigma)`,
  `d(loglik)/d(log_theta)` symbolically (Γ(d+1/θ)/Γ(1/θ) differentiates via
  `digamma()`); implement as a second R function; verify against
  `numDeriv::grad()` on the first function to < 1e-6 relative error across
  the same k ∈ {1,2,3,5} random-cluster sweep.
- [ ] Derive the Hessian (or verify numerically that L-BFGS convergence is
  acceptable without an analytic Hessian — check whether
  `fast_clayton_weibull_aft_optim_cpp`'s `optimization_alg` options
  actually require the analytic Hessian or only the score, per
  `_normalize_optimizer_algorithm`'s `allow_irls` flag pattern seen in
  `helper_survival_fits.R:490` — if L-BFGS-only is acceptable, the Hessian
  can be `numerical_hessian()` as `WeibullFrailtyNormalLikelihood` already
  does at `fast_weibull_frailty.cpp:241`, avoiding a second by-hand
  derivation entirely). Verify against `numDeriv::hessian()` regardless of
  which path is chosen, since the R implementation also serves as the C++
  port's ground truth in TODO-5's tests.
- [ ] Save the verified R reference implementation as a fixture inside
  `R/EDI/tests/testthat/test-clayton-loggamma-k-cluster-likelihood.R` (as
  a helper function used only by tests, not exported) — TODO-5's C++ tests
  compare against this fixture, not against a second independent
  derivation.

**TODO-5. Reimplement `ClaytonWeibullLikelihood` in C++ for general k.**

Files:
- Modify: `R/EDI/src/fast_survival_models_optim.cpp:39-460`
  (`ClaytonWeibullLikelihood` class body) — replace the `Eigen::MatrixXi
  m_pair_idx` (2-column) member and the `for (k rows) { i1, i2 }` loop
  structure with `group_starts`/`group_members` (CSR, same shape as
  Phase 1's bootstrap change and `build_contiguous_group_layout()`), and
  replace the four hand-derived mask branches with one loop implementing
  the general `(d, A)` formula from TODO-4.
- Modify: `fast_survival_models_optim.cpp:471`
  (`get_clayton_weibull_aft_score_cpp`), `:495`
  (`get_clayton_weibull_aft_hessian_cpp`), `:743`
  (`fast_clayton_weibull_aft_optim_cpp`) — signature changes from
  `pair_idx`/`singleton_rows` to `group_starts`/`group_members` (singletons
  become groups of size 1 in the same layout — `singleton_rows` as a
  separate argument disappears, simplifying the call sites).
- Modify: `R/EDI/R/RcppExports.R` and re-run **only**
  `Rcpp::compileAttributes()`'s R-side header sync — per this project's
  compile-avoidance rule, do not run `compileAttributes()`/any compile step
  yourself; hand this whole phase to the user to build and iterate, or ask
  before running it, exactly as `CLAUDE.md` requires.

Steps:
- [ ] Write `R/EDI/tests/testthat/test-clayton-loggamma-k-cluster-likelihood.R`
  (started in TODO-4): for k ∈ {1,2,3,5} random clusters, call the new
  `get_clayton_weibull_aft_score_cpp`/`_hessian_cpp` (post-rewrite
  signature) and assert they match the TODO-4 R fixture to floating-point
  tolerance (`1e-6`).
- [ ] Confirm the test fails to compile / fails against the *current*
  (pair-only) signature — i.e. confirm this test is actually exercising new
  code, not silently passing against old code.
- [ ] Implement the C++ rewrite per the file list above.
- [ ] **Do not compile.** Hand off to the user per `CLAUDE.md`'s
  compile-avoidance rule; this task's "done" state is "code written,
  awaiting the user's own build," not "tests green," since verifying C++
  changes here requires the compile step this project forbids running
  autonomously.
- [ ] Once the user confirms a successful build, run the test and iterate on
  any analytic-derivative mismatches surfaced (a mismatch means either the
  C++ port or the TODO-4 derivation has a bug — re-check both against the
  R fixture, do not silently patch away disagreement with slack tolerance).
- [ ] Commit once green (still gated on a user-run build).

**TODO-6. Rewire `.complete_pair_index_matrix()` call sites to the new
group layout.**

Files:
- Modify: `R/EDI/R/helper_matching.R:232-242` — either repurpose this
  function to return the new CSR layout (rename to
  `.complete_group_index_layout()` — a public rename, so grep the whole
  tree for the old name after) or add a sibling function and delete this
  one once all call sites move; prefer the rename (one function, one
  contract) since nothing outside the Loggamma class family should still
  want a pairs-only view.
- Modify: `R/EDI/R/inference_survival_GLMM_weibull_frailty_loggamma.R:135-146`,
  `:318-340` (`clayton_copula_for_matched_pairs`), `:622-720` (`shared()`),
  and the score/Hessian/information call sites at `:707/711/715/719`.

Steps:
- [ ] Write a failing test extending
  `R/EDI/tests/testthat/test-clayton-loggamma-k-cluster-likelihood.R`:
  construct an `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC` (and
  `OneLik`) directly from hand-built `y`/`dead`/`X`/`w`/`m` with a mix of
  size-1, size-2, and size-3/size-5 groups (same simulation approach as
  TODO-2/3, generalized to a Gamma-frailty AFT DGP — draw one shared
  `z_g ~ Gamma(1/θ, 1/θ)` per group, then `H_i = z_g · exp(-x_i'β/σ)·y_i^{1/σ}`
  inverted to simulate `y_i`), and assert `compute_estimate()` is finite and
  recovers β and θ within simulation noise.
- [ ] Run it, confirm it fails (current code silently treats the size-3/5
  groups as singletons, so the estimate should be visibly biased toward the
  reservoir-only Weibull fit — assert on the *failure mode*, not just an
  error, since this task starts from working-but-wrong code, not crashing
  code).
- [ ] Rewire the R call sites listed above to build and pass the new group
  layout instead of `pair_idx`/`singleton_rows`.
- [ ] Run the test, confirm it passes.
- [ ] Run every existing Loggamma golden test (`grep -rl
  "WeibullFrailtyLoggamma" R/EDI/tests/testthat/`) unmodified — k=2 behavior
  must be bit-for-bit unchanged (same argument as Phase 1/TODO-1's
  regression requirement).
- [ ] Update this class's roxygen (`inference_survival_GLMM_weibull_frailty_loggamma.R:414-457`
  and the `InferenceSurvivalGLMMWeibullFrailtyLoggammaOneLik` block) to
  describe general-k support and the closed-form generalization, citing
  Hougaard (2000) alongside the existing Clayton (1978)/Oakes (1989)
  references.
- [ ] Commit.

**TODO-7. Update `inference_class_registry.R`/`contracts_mixins.R`
`requires_state` metadata if the group-layout refactor changes which
private fields these components own.**

Files:
- Modify: `R/EDI/R/contracts_mixins.R:2055-2166` (the four
  `SurvivalGLMMWeibullFrailtyLoggamma*`/`SurvivalGLMMWeibullFrailtyNormal*`
  component entries) — audit `owns_state`/`requires_state` against whatever
  new private fields TODO-5/TODO-6 introduce (e.g. if a cached group layout
  gets stored on `private$` for reuse across calls, it must be declared).

Steps:
- [ ] After TODO-6 lands, diff the class bodies against their
  `contracts_mixins.R` entries; add any new state fields to `owns_state`.
- [ ] Run `R/EDI/tests/testthat/test-mixin-contracts.R` (already in the file
  list this session's rename touched) to confirm the static-contract
  checker accepts the updated declarations.
- [ ] Commit.

### Phase 4 — Design-layer opt-in (TODO-0's recommended resolution)

**TODO-8. Relax `DesignFixedBinaryMatch`'s pairs-only validation behind an
opt-in.**

Files:
- Modify: `R/EDI/R/design_fixed_binary_match.R:212-231`
  (`set_binary_match_structure_from_m`) and the constructor
  (`:121-155`) to accept a new constructor argument, e.g.
  `allow_k_wise_groups = FALSE` (default preserves today's exact-pairs
  guarantee and error message unchanged) — when `TRUE`, skip the
  `pair_sizes != 2L` stop() and skip `ensure_matching_structure_computed()`'s
  own-algorithm path (which stays pairs-only; k-wise groups can only be
  **injected** via `m`, never computed by `compute_binary_match_structure()`
  itself in this phase — building a k-way matching *algorithm* is the
  explicitly out-of-scope Design work from TODO-0).
- Modify: `R/EDI/R/design_fixed_binary_match.R`'s `draw_ws_raw()`
  (`:172-198`) — `draw_binary_match_assignments_cpp()`
  (a compiled kernel) is pairs-only randomization and **must not** be called
  when `allow_k_wise_groups = TRUE` with any group ≠ 2; when
  `w_precomputed` is supplied (already the documented bypass path, per this
  file's own roxygen at line 39-40) this is moot since no randomization
  draw happens. Document explicitly: with `allow_k_wise_groups = TRUE`,
  `draw_ws_raw()` must be given `w_precomputed` (or the design used only for
  a single fixed, externally-randomized allocation) — leave a `stop()` with
  a clear message if `draw_ws_raw()` is reached with an unresolved k-wise
  group and no `w_precomputed`, rather than silently calling the pairs-only
  kernel on non-pairs data.

Steps:
- [ ] Write a failing test: construct `DesignFixedBinaryMatch$new(...,
  m = c(1,1,1, 2,2, 0,0), n = 7, allow_k_wise_groups = TRUE)` and assert it
  does not error (today it errors per the audit above).
- [ ] Run it, confirm it fails against current code.
- [ ] Implement the constructor/validation relaxation and the `draw_ws_raw`
  guard described above.
- [ ] Add a second test: same construction with `allow_k_wise_groups =
  FALSE` (default) still errors with the existing message — the default
  behavior for every existing caller must be provably unchanged.
- [ ] Wire an end-to-end test:
  `DesignFixedBinaryMatch` with a k=3 group →
  `InferenceSurvivalGLMMWeibullFrailtyLoggammaIVWC$new(des, ...)` →
  `compute_estimate()` finite, using `w_precomputed` for the allocation.
- [ ] Update `design_fixed_binary_match.R`'s class-level roxygen
  (`:1-50`) to document the new parameter and its randomization caveat.
- [ ] Commit.

## Testing strategy

Every new test in Phases 2/3 constructs the `Inference` object **directly**,
bypassing any `Design`, by hand-populating the same private fields a Design
normally supplies (`y`, `dead`, `w`, `X`, `m`, `n`) — this is the pattern
already used by direct-construction tests elsewhere in this suite (grep
`R/EDI/tests/testthat/` for other `private$` field-injection helpers before
inventing a new one; reuse the existing helper if the suite already has one,
rather than duplicating it here). This deliberately decouples "is the
likelihood/estimator correct for k-sized groups" (Phases 1-3, testable
today) from "can a real Design produce a k-sized group" (Phase 4/TODO-8,
the opt-in escape hatch, tested separately in TODO-8's own end-to-end test).
Only Phase 4 needs a real `Design` object in its tests.

All new/changed C++ is verified two ways before being trusted: (1) against
a hand-written R reference implementation checked with `numDeriv` (TODO-4),
and (2) by confirming k=2 output is bit-for-bit identical to the pre-change
kernel on the existing golden tests (Phase 1's bootstrap regression
requirement, Phase 3's Loggamma golden-test requirement). Per `CLAUDE.md`,
no step in this plan compiles `R/EDI` — every C++ task ends with "hand off
to the user to build," and R-side work proceeds only after the user
confirms a successful build.

## Effort estimate

| Phase | Content | Estimate |
|---|---|---|
| 1 | Bootstrap kernel (R + C++) generalization | 1-2 days |
| 2 | Normal-frailty: confirm + test + docs (no math/C++ change expected) | 0.5-1 day |
| 3 | Loggamma-frailty: derivation, C++ rewrite, rewiring, docs | 1-2 weeks (dominated by TODO-4's derivation and TODO-5's build/iterate cycle, which depends on user-run compiles) |
| 4 | Design-layer opt-in (TODO-8) | 1-2 days |

Total: roughly two to three weeks of wall-clock work, most of it gated on
Phase 3's math and on compile turnaround the user must run per
`CLAUDE.md`'s rule (this plan's C++ tasks cannot be iterated to green
autonomously).

## Release scope

Proposed for **v1.1.0** (additive on the frozen v1.0.0 CRAN substrate — no
existing public API changes; `DesignFixedBinaryMatch`'s default behavior is
provably unchanged per TODO-8's own test). This document is **not yet**
referenced from `_master.md` or
`../future_release_plans/release_v1_1_0.md` — both list every other
v1.1.0-scoped plan with a dated "user decision" entry, and this plan should
get the same treatment once the scope above is confirmed, rather than being
silently added.

**Explicitly out of scope for this plan** (would need its own plan
document): a new Design class that *computes* its own k-way matching via a
non-bipartite k-way grouping algorithm, and a new within-k-group treatment
randomization kernel to go with it. TODO-8's opt-in only lets a k-wise `m`
be *injected*; it does not add a way to *generate* one from covariates.
