# Multistart for the Nonconcave Likelihood Kernels

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-17s`;
> 2026-09-03, user decision). Correctness / robustness, not performance: every
> likelihood kernel whose objective is **not** concave currently runs a single
> L-BFGS/Newton descent from one smart cold start and returns whatever local
> optimum it lands in. Two kernels already carry a small deterministic
> multistart (`fast_ordinal_glmm.cpp:337-380`, `fast_hurdle_negbin.cpp:150-194`);
> this plan gives every nonconcave kernel the same protection through one shared
> helper, with random starts layered on top of family-specific deterministic
> ones. No Phase 0 dependency. **Bit-for-bit on every fit where the primary
> start already reaches the best optimum found** (see "Equivalence"); only fits
> that were returning a *worse* local optimum change — which is the point.
> Cross-references: `cold_starts.md` (the primary starts this plan perturbs),
> `optimizer_diagnostics_report.md` (the `LikelihoodFitResult` fields the new
> provenance sits beside), `quantum_upgrade.md → §II.6.1` (the audit that
> found the gap).

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Date: 2026-09-03

**Goal:** Every nonconcave likelihood kernel in `src/` runs a deterministic-plus-random multistart on full-data fits, keeps the best finite optimum, and reports which start won — while replicate (warm-started) fits and every concave kernel stay exactly as they are.

**Architecture:** One new header `src/optimization_multistart.h` (a `MultistartSpec`, a `MultistartFitResult`, `optimize_fixed_likelihood_multistart()` wrapping the existing `optimize_fixed_likelihood()`, and two small deterministic-start generators). Each nonconcave kernel swaps its single `optimize_fixed_likelihood(...)` call for the multistart call and gains three exported arguments (`n_random_starts`, `multistart_jitter_sd`, `multistart_seed`). The R side gets a per-class policy table mirroring `get_cold_start_dispatch_policy()` and a `set_multistart()` setter on the abstract inference class; the policy turns the random layer on for the nonconcave classes and leaves it off everywhere else.

**Tech Stack:** C++17 / Eigen / LBFGSpp (existing), `edi_rng::RRng` (`src/RNG.h`) for reproducible jitter, R6 + checkmate on the R side, testthat.

**Spec:** this file (the "Design" section below is the spec; the audit that motivates it is in `quantum_upgrade.md → §II.6` and §II.6.1).

## Global Constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` / `load_all()` without `compile = FALSE`** — see the repo `CLAUDE.md`. This is why the helper lives in a **new header** included only by the touched kernels: editing `_helper_functions_core.h` would force every one of the 100+ `.cpp` files to recompile, which is a full rebuild in disguise. Compile only the touched `.cpp` files (`R CMD SHLIB` with `src/Makevars` flags), relink, `pkgload::load_all(".", compile = FALSE)`; memory `feedback_targeted_compile_only` has the exact recipe.
- **Default off ⇒ bit-for-bit.** `n_random_starts = 0` with no deterministic extras must reproduce today's numbers exactly, in every kernel, for every argument combination (`release_v1_1_0.md → Standing constraints`).
- **Replicate fits never multistart.** Any call that supplies `warm_start_params` (bootstrap / randomization replicates re-fitting from the full-data optimum) skips the multistart entirely — otherwise every resampling loop's cost multiplies by `S + 1` for no benefit.
- **`set.seed()` reproducibility is untouched.** Random starts are drawn from a private `edi_rng::RRng` seeded by the `multistart_seed` argument (default a fixed constant), never from R's stream. They are a deterministic design-of-experiments around the primary start, not statistical randomness; no R RNG state is consumed.
- **Concave kernels are not touched.** Logistic, probit, Poisson, log-binomial, Cox, proportional-odds logit/probit/cloglog, adjacent-category, continuation-ratio, Weibull AFT (Burridge parametrization), COM-Poisson, Huber M-estimation, OLS: every local optimum is global, one start suffices (`quantum_upgrade.md → §II.6`).
- Python: `python/src/edi_kernels` binds several of these kernels through their `EDI_CORE_ONLY` translation units; every signature change here must be mirrored there and the `_core.pyi` stub regenerated (TODO-9).
- No new package dependencies.

---

## The finding

Audit of 2026-09-03 (recorded in `quantum_upgrade.md → §II.6`). The likelihood kernels split:

| concave — one start is provably enough | **nonconcave — this plan** |
|---|---|
| OLS, logistic, probit, Poisson, log-binomial, Cox PH, ordinal logit / probit / cloglog, adjacent-category, continuation-ratio, Weibull AFT, COM-Poisson, Huber robust | GLMM / LMM / frailty marginal likelihoods (variance components); ZINB, ZIP, zero-one-inflated beta (mixtures); negbin and hurdle negbin jointly in `(β, log θ)`; beta regression `(β, log φ)`; stereotype logit (bilinear); Tukey-bisquare robust regression (redescending ψ); Clayton-copula Weibull AFT and dependent-censoring transform (dependence parameter); ordinal cauchit (Cauchy is not log-concave) |

What the nonconcave kernels do today, by call site:

| kernel | call site | starts today | what varies the basin |
|---|---|---|---|
| `fast_ordinal_glmm.cpp` | `:371` (loop), `:385` (polish) | **5 deterministic** over `log σ ∈ {start, −1, 0, 1, −max}`, best kept, always polished | `log σ` |
| `fast_hurdle_negbin.cpp` | `:241` inside `fit_truncated_negbin_with_fallback` | primary; deterministic extras (`make_truncated_negbin_candidate_starts`, `:150`) tried **only if the primary fails to converge** — a fallback, not a best-of | `log θ`, `β` |
| `fast_logistic_glmm.cpp` | `:514` | 1 (`log σ = −3`) | `log σ` |
| `fast_poisson_glmm.cpp` | `:408` | 1 | `log σ` |
| `fast_ordinal_clmm.cpp` | `:107` | 1 | `log σ` |
| `fast_clogit_plus_glmm.cpp` | `:559` | 1 | `log σ` |
| `fast_hurdle_poisson_glmm.cpp` | `:520` | 1 | `log σ` |
| `fast_gaussian_lmm.cpp` | `:450` | 1 | `log σ_u`, `log σ_e` |
| `fast_weibull_frailty.cpp` | `:369` | 1 | frailty `log σ` |
| `fast_zinb.cpp` | `:412` (+ ZIP-limit fallback `:301`) | 1 (`log θ = 0`, ZI coefficients 0) | `log θ`, ZI intercept |
| `fast_zero_augmented_poisson.cpp` | `:303` | 1 | ZI intercept (ZIP branch only; the hurdle-Poisson branch is two concave pieces) |
| `fast_zero_one_inflated_beta.cpp` | `:467` | 1 (`log φ = 2`) | `log φ` (the two logit pieces are concave) |
| `fast_beta_regression.cpp` | `:260` | 1 (`log φ = 2`) | `log φ` |
| `fast_negbin_regression.cpp` | `:308` | 1 (`log θ = 0`) | `log θ` |
| `fast_stereotype_logit.cpp` | `:815` | 1 | score vector `φ` (bilinear with `β`; sign symmetry) |
| `fast_survival_models_optim.cpp` | `:591` (Clayton), `:698` (dep-cens) | 1 | copula / dependence parameter |
| `fast_ordinal_cauchit_regression.cpp` | `:159` | 1 | heavy-tailed link: flat regions |
| `fast_robust_regression.cpp` | IRLS loop `:154-` (not `optimize_fixed_likelihood`) | 1, **from an OLS/QR solve** (`:101-112`) | bisquare redescending ψ: OLS is pulled by the very outliers the estimator rejects |

`fast_ordinal_glmm.cpp` is the pattern to generalize; `fast_hurdle_negbin.cpp`'s fallback-only extras become a real best-of once it goes through the shared helper.

## Design

### D1. `src/optimization_multistart.h` — the shared helper

A new leaf header (includes `_helper_functions_core.h` and `RNG.h`; included **only** by the kernels in the table above, never by `_helper_functions*.h`, so the compile footprint is the touched files).

```cpp
#ifndef EDI_OPTIMIZATION_MULTISTART_H
#define EDI_OPTIMIZATION_MULTISTART_H
#include "_helper_functions_core.h"
#include "RNG.h"
#include <cstdint>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

enum class MultistartPolish { Never, WhenSwitched, Always };

struct MultistartSpec {
    int n_random_starts = 0;             // 0 => primary + deterministic extras only
    double jitter_sd = 0.5;              // N(0, jitter_sd^2) added to every free coordinate
    std::uint32_t seed = 20260903u;      // private stream; never R's
    double improvement_tol = 1e-6;       // a non-primary start replaces the incumbent only if
                                         // it lowers neg-loglik by more than this (keeps ties
                                         // bit-for-bit on the primary)
    MultistartPolish polish = MultistartPolish::WhenSwitched;
    bool warm_hessian_all_starts = false; // ordinal GLMM passes its warm info to every start
};

struct MultistartFitResult {
    LikelihoodFitResult best;
    int n_starts_tried = 0;
    int n_starts_finite = 0;
    int selected_start = 0;              // 0 = primary; 1..D = deterministic; D+1.. = random
    double improvement = 0.0;            // primary.value - best.value (0 when primary selected;
                                         // NaN when the primary had no finite value)
    std::string primary_error;           // what() if the primary start threw
};

// Random starts: primary + N(0, jitter_sd^2) on each free coordinate, from a private RRng.
inline std::vector<Eigen::VectorXd> make_random_starts(const Eigen::VectorXd& primary,
                                                       const FixedParamSpec& fixed_spec,
                                                       const MultistartSpec& ms) {
    std::vector<Eigen::VectorXd> out;
    if (ms.n_random_starts <= 0) return out;
    edi_rng::RRng rng(ms.seed);
    out.reserve(static_cast<std::size_t>(ms.n_random_starts));
    for (int s = 0; s < ms.n_random_starts; ++s) {
        Eigen::VectorXd cand = primary;
        for (int k = 0; k < fixed_spec.free_idx.size(); ++k)
            cand[fixed_spec.free_idx[k]] += ms.jitter_sd * rng.norm_rand();
        out.push_back(cand);
    }
    return out;
}

// Deterministic sweep of one scalar nuisance coordinate (log sigma, log theta, log phi,
// a copula parameter) over `values`, keeping every other coordinate at the primary.
// Skips the coordinate if it is fixed, and skips values equal to the primary's.
inline std::vector<Eigen::VectorXd> scalar_nuisance_starts(const Eigen::VectorXd& primary,
                                                           int index,
                                                           const FixedParamSpec& fixed_spec,
                                                           const std::vector<double>& values) {
    std::vector<Eigen::VectorXd> out;
    for (int k = 0; k < fixed_spec.fixed_idx.size(); ++k)
        if (fixed_spec.fixed_idx[k] == index) return out;
    for (double z : values) {
        if (!std::isfinite(z) || std::abs(primary[index] - z) < 1e-12) continue;
        Eigen::VectorXd c = primary;
        c[index] = z;
        out.push_back(c);
    }
    return out;
}

// The ordinal-GLMM sweep (fast_ordinal_glmm.cpp:337-359), hoisted: {-1, 0, 1, -max_abs}.
inline std::vector<Eigen::VectorXd> variance_component_starts(const Eigen::VectorXd& primary,
                                                              int log_sigma_index,
                                                              const FixedParamSpec& fixed_spec,
                                                              double max_abs_log_sigma) {
    return scalar_nuisance_starts(primary, log_sigma_index, fixed_spec,
                                  {-1.0, 0.0, 1.0, -max_abs_log_sigma});
}

template <typename FullFunctor>
inline MultistartFitResult optimize_fixed_likelihood_multistart(
        FullFunctor& fun,
        const Eigen::VectorXd& primary_start,
        const std::vector<Eigen::VectorXd>& deterministic_starts,
        const MultistartSpec& ms,
        const FixedParamSpec& fixed_spec,
        int maxit, double tol,
        const std::string& optimization_alg,
        const std::string& default_optimization_alg,
        int max_linesearch = 0,
        const Eigen::MatrixXd* warm_start_hessian = nullptr) {
    MultistartFitResult out;
    auto finite_fit = [](const LikelihoodFitResult& f) {
        return std::isfinite(f.value) && f.params.allFinite();
    };
    // 1. The primary start: exactly today's call (same warm Hessian, same everything).
    bool have_primary = false;
    try {
        out.best = optimize_fixed_likelihood(fun, primary_start, fixed_spec, maxit, tol,
                                             optimization_alg, default_optimization_alg,
                                             max_linesearch, warm_start_hessian);
        have_primary = finite_fit(out.best);
    } catch (const std::exception& e) {
        out.primary_error = e.what();
    }
    out.n_starts_tried = 1;
    out.n_starts_finite = have_primary ? 1 : 0;
    const double primary_value = have_primary ? out.best.value
                                              : std::numeric_limits<double>::infinity();
    // 2. Deterministic extras, then random jitter (in that index order).
    std::vector<Eigen::VectorXd> candidates = deterministic_starts;
    const std::vector<Eigen::VectorXd> rnd = make_random_starts(primary_start, fixed_spec, ms);
    candidates.insert(candidates.end(), rnd.begin(), rnd.end());
    int idx = 0;
    for (const Eigen::VectorXd& start : candidates) {
        ++idx;
        if (start.size() != primary_start.size()) continue;
        if (start.isApprox(primary_start, 1e-12)) continue;
        ++out.n_starts_tried;
        LikelihoodFitResult fit;
        try {
            fit = optimize_fixed_likelihood(fun, start, fixed_spec, maxit, tol,
                                            optimization_alg, default_optimization_alg,
                                            max_linesearch,
                                            ms.warm_hessian_all_starts ? warm_start_hessian : nullptr);
        } catch (const std::exception&) { continue; }
        if (!finite_fit(fit)) continue;
        ++out.n_starts_finite;
        const double incumbent = (out.selected_start == 0) ? primary_value : out.best.value;
        if (fit.value < incumbent - ms.improvement_tol) {
            out.best = fit;
            out.selected_start = idx;
        }
    }
    // 3. Nothing finite anywhere: surface the primary's failure exactly as today.
    if (out.n_starts_finite == 0) {
        if (!out.primary_error.empty()) throw std::runtime_error(out.primary_error);
        return out;  // primary ran, returned non-finite, nothing better: today's behaviour
    }
    if (out.selected_start != 0)
        out.improvement = have_primary ? primary_value - out.best.value
                                       : std::numeric_limits<double>::quiet_NaN();
    // 4. Polish (the ordinal-GLMM step, fast_ordinal_glmm.cpp:382-389).
    const bool do_polish = ms.polish == MultistartPolish::Always ||
        (ms.polish == MultistartPolish::WhenSwitched && out.selected_start != 0);
    if (do_polish) {
        const double polish_tol = std::min(tol, 1e-10);
        try {
            LikelihoodFitResult polished = optimize_fixed_likelihood(
                fun, out.best.params, fixed_spec, maxit, polish_tol,
                optimization_alg, default_optimization_alg, max_linesearch, nullptr);
            if (finite_fit(polished) && polished.value <= out.best.value + 1e-10)
                out.best = polished;
        } catch (const std::exception&) { /* keep the unpolished winner */ }
    }
    return out;
}
#endif
```

Invariants the tests lock (TODO-1):

- `n_random_starts = 0`, empty `deterministic_starts` ⇒ `out.best` is **bit-for-bit** the single `optimize_fixed_likelihood` call (one call, same arguments, no polish because `selected_start == 0` and `polish == WhenSwitched`).
- The primary wins every tie within `improvement_tol` ⇒ unchanged numbers whenever the primary is already in the best basin.
- A candidate that throws or returns non-finite is skipped silently; the primary's exception is re-thrown only if *nothing* was finite (so every kernel's existing `catch` path still sees the same error).
- `warm_start_hessian` goes to the primary only (unless `warm_hessian_all_starts`).
- Same `seed` ⇒ identical candidates ⇒ identical result, call after call.

### D2. Kernel signature extension

Every kernel in the table gains, after its existing `optimization_alg`-family arguments (before any trailing `warm_start_fisher_info` so Rcpp positional callers are unaffected — verify per kernel):

```cpp
int n_random_starts = 0,
double multistart_jitter_sd = 0.5,
int multistart_seed = 20260903
```

and, immediately after the primary start is assembled:

```cpp
MultistartSpec ms;
ms.n_random_starts = warm_start_params.has_value() ? 0 : n_random_starts;   // replicates skip
ms.jitter_sd = multistart_jitter_sd;
ms.seed = static_cast<std::uint32_t>(multistart_seed);
std::vector<Eigen::VectorXd> extra = warm_start_params.has_value()
    ? std::vector<Eigen::VectorXd>{}
    : <family-specific deterministic starts, D3>;
MultistartFitResult msr = optimize_fixed_likelihood_multistart(
    obj, par, extra, ms, fixed_spec, maxit, eps_g, optimization_alg, "lbfgs", 0, info_start_ptr);
LikelihoodFitResult fit = msr.best;
```

The result list gains four provenance fields, set right after `make_uniform_likelihood_fit_result()` (or the `edi::ResultMap` `.set` chain in the `EDI_CORE_ONLY` siblings):

```cpp
out["multistart_n_tried"]  = msr.n_starts_tried;
out["multistart_n_finite"] = msr.n_starts_finite;
out["multistart_selected"] = msr.selected_start;
out["multistart_improvement"] = msr.improvement;
```

### D3. Family-specific deterministic starts

| kernel | `extra` (all via `scalar_nuisance_starts` / `variance_component_starts` on the primary) |
|---|---|
| all GLMM / CLMM / clogit-GLMM / hurdle-Poisson-GLMM / Weibull frailty | `variance_component_starts(par, log_sigma_index, fixed_spec, max_abs_log_sigma)` (use `8.0` where the kernel has no `max_abs_log_sigma` argument) |
| Gaussian LMM | the sweep on `log σ_u`, then on `log σ_e` (two calls, concatenated) |
| negbin, hurdle negbin (truncated part), ZINB | `scalar_nuisance_starts(par, log_theta_index, fixed_spec, {log(θ_moment), log(10), log(25), kNegBinPoissonBoundaryLogTheta})` where `θ_moment = max(0.1, ȳ² / (s² − ȳ))` if `s² > ȳ` else `10` (the formula already at `fast_hurdle_negbin.cpp:156-157`; hoist it into the header as `negbin_moment_theta(y)`) |
| ZINB, ZIP branch of `fast_zero_augmented_poisson` | additionally one start with the zero-inflation intercept at `logit(max(0.01, π̂_0))`, `π̂_0 = (observed zero fraction − mean Poisson zero probability at the cold-start β)⁺` |
| beta regression, ZOIB (beta part) | `scalar_nuisance_starts(par, log_phi_index, fixed_spec, {0.0, 4.0})` |
| stereotype logit | (i) the sign-flipped score vector `φ → −φ` with `β → −β` (the bilinear symmetry); (ii) equally spaced scores `φ_k = (k−1)/(K−1)` if the cold start does not already use them |
| Clayton copula AFT / dep-cens transform | dependence parameter (on the kernel's internal scale) at `{log(0.1), log(1), log(5)}` — confirm the scale from the functor before choosing values |
| ordinal cauchit | none (random layer only) |

Ordinal GLMM keeps its exact current semantics through the spec: `improvement_tol = 0`, `polish = Always`, `warm_hessian_all_starts = true`, deterministic extras = `variance_component_starts(...)`. That is the bit-for-bit refactor (TODO-2).

### D4. Robust regression (bisquare) — IRLS, not `optimize_fixed_likelihood`

`fast_robust_regression.cpp` is an IRLS loop, so it does not go through D1. Its fix is narrower:

1. When the ψ is bisquare (audit `method` / `c` handling at `:22-30` and `:301-312` first — if `method = "MM"` already runs a Huber stage before bisquare, step 2 is already satisfied and only step 3 applies), start the bisquare IRLS from a **converged Huber fit** (`c = 1.345`), not from OLS.
2. If it does not, add that Huber stage: run the existing loop once with the Huber weight function, then continue with bisquare from its `b` and `scale`.
3. Multistart layer: `n_random_starts` jittered starts around the Huber fit, each run through the bisquare IRLS; select by the M-objective `Σ ρ_bisquare(r_i / s)` at fixed `s` (the scale from step 1). Same three exported arguments, same four provenance fields, same warm-start skip.

### D5. R side

- `R/globals.R`, next to `get_cold_start_dispatch_policy()` (`:894`): `get_multistart_dispatch_policy()` returning `list(default = 0L, inference_class_overrides = c(<pattern> = 4L, ...))`, `set_multistart_dispatch_policy(policy, reset)`, `edi_multistart_dispatch_policy(inference_class)` — copy the three cold-start functions verbatim and change the names and the value type (integer instead of flag). Overrides list every class that calls a kernel in the table (resolve with `graft callers <kernel>` per kernel; the caller files are listed in TODO-6).
- `R/inference_all_abstract.R`: `private$multistart_n_random_starts`, `private$multistart_jitter_sd = 0.5`, `private$multistart_seed = 20260903L`, initialized in `initialize()` from the policy; public `set_multistart(n_random_starts = NULL, jitter_sd = NULL, seed = NULL)` mirroring `set_optimization_alg()` (`:366-381`), including the cache clear; `get_multistart()`.
- Every kernel call site passes `n_random_starts = private$multistart_n_random_starts, multistart_jitter_sd = private$multistart_jitter_sd, multistart_seed = private$multistart_seed`.
- Diagnostics: the four provenance fields are carried into the fit-diagnostics list the way `hit_iteration_cap` / `gradient_norm` are (`optimizer_diagnostics_report.md`).
- `tune_EDI_for_this_machine()` does **not** benchmark multistart (it is a correctness setting, like the serial-execution policy — see the roxygen at `globals.R:630-660`).

### Equivalence

With the shipped policy (random layer on for the nonconcave classes), a fit's numbers change **iff** some non-primary start lowers the negative log-likelihood by more than `improvement_tol = 1e-6`. That is exactly the set of fits that were previously returning a worse local optimum. Every other fit — and every fit in every concave kernel, every replicate fit, and every fit with `n_random_starts = 0` and no deterministic extras — is bit-for-bit. The ordinal GLMM refactor is bit-for-bit unconditionally (TODO-2 locks it).

Cost: `(1 + D + S)` optimizer runs per **full-data** fit, `D ≤ 5`, `S = 4` by default — milliseconds. Replicate fits are unaffected. The simulation framework pays it once per replicate for the nonconcave families only; document in `performance_profiling_and_upgrades.md`'s ledger after TODO-8's timing.

---

## Implementation TODOs

### TODO-1: `src/optimization_multistart.h` + a hardware-free unit test through `fast_logistic_glmm_cpp`

**Files:**
- Create: `R/EDI/src/optimization_multistart.h` (content: D1 verbatim)
- Modify: `R/EDI/src/fast_logistic_glmm.cpp:478-530` (signature at its `Rcpp::export` block; the call at `:514`)
- Test: `R/EDI/tests/testthat/test-multistart-nonconcave.R` (new)

**Interfaces:**
- Produces: `MultistartSpec`, `MultistartFitResult`, `optimize_fixed_likelihood_multistart<F>(...)`, `make_random_starts()`, `scalar_nuisance_starts()`, `variance_component_starts()` — exact signatures in D1; every later task consumes them unchanged.
- Produces: the three kernel arguments and four result fields named in D2, which every later kernel task repeats verbatim.

- [ ] **Step 1: Record the baseline.** Before touching code, with the *current* build loaded (`pkgload::load_all("R/EDI", compile = FALSE)`), run the fixture below and save the result:

```r
make_logistic_glmm_fixture = function(seed = 11L, sigma = 1.2, n_groups = 40L) {
	set.seed(seed)
	group_id = as.integer(rep(seq_len(n_groups), each = 4L))
	w = rep(c(0, 1), length.out = 4L * n_groups)
	x = rnorm(4L * n_groups)
	u = rnorm(n_groups, sd = sigma)
	eta = -0.3 + 1.1 * w + 0.4 * x + u[group_id]
	y = as.numeric(runif(length(eta)) < plogis(eta))
	list(X = cbind(1, w = w, x = x), y = y, group_id = group_id)
}
d = make_logistic_glmm_fixture()
base = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8)
saveRDS(base[c("params", "neg_loglik", "converged")],
        "R/EDI/tests/testthat/fixtures/multistart_logistic_glmm_baseline.rds")
```

- [ ] **Step 2: Write the failing tests** in `test-multistart-nonconcave.R`:

```r
library(testthat)
library(EDI)

make_logistic_glmm_fixture = function(seed = 11L, sigma = 1.2, n_groups = 40L) {
	# identical to Step 1
	set.seed(seed)
	group_id = as.integer(rep(seq_len(n_groups), each = 4L))
	w = rep(c(0, 1), length.out = 4L * n_groups)
	x = rnorm(4L * n_groups)
	u = rnorm(n_groups, sd = sigma)
	eta = -0.3 + 1.1 * w + 0.4 * x + u[group_id]
	y = as.numeric(runif(length(eta)) < plogis(eta))
	list(X = cbind(1, w = w, x = x), y = y, group_id = group_id)
}

test_that("n_random_starts = 0 is bit-for-bit the pre-multistart fit", {
	d = make_logistic_glmm_fixture()
	base = readRDS(test_path("fixtures", "multistart_logistic_glmm_baseline.rds"))
	fit = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8, n_random_starts = 0L)
	expect_identical(fit$params, base$params)
	expect_identical(fit$neg_loglik, base$neg_loglik)
	expect_identical(fit$multistart_n_tried, 1L)
	expect_identical(fit$multistart_selected, 0L)
	expect_identical(fit$multistart_improvement, 0)
})

test_that("random starts are reproducible and never worse than the primary", {
	d = make_logistic_glmm_fixture()
	a = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8, n_random_starts = 4L)
	b = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8, n_random_starts = 4L)
	base = readRDS(test_path("fixtures", "multistart_logistic_glmm_baseline.rds"))
	expect_identical(a$params, b$params)
	expect_identical(a$multistart_selected, b$multistart_selected)
	expect_true(a$multistart_n_tried >= 5L)          # primary + 4 random (+ deterministic later)
	expect_lte(a$neg_loglik, base$neg_loglik + 1e-6)  # never worse than the single start
	expect_true(a$multistart_improvement >= 0)
})

test_that("a warm-started fit skips the multistart", {
	d = make_logistic_glmm_fixture()
	full = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8, n_random_starts = 4L)
	rep = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8,
		warm_start_params = full$params, n_random_starts = 4L)
	expect_identical(rep$multistart_n_tried, 1L)
	expect_identical(rep$multistart_selected, 0L)
})

test_that("a trapped primary start is rescued by a random start", {
	# Force the primary into the near-zero-variance basin: a cold start at log_sigma = -8
	# on data with a large true sigma. warm_start_params would skip the multistart, so use
	# smart_cold_start = FALSE (log_sigma = -3, betas = 0) on a high-variance fixture.
	d = make_logistic_glmm_fixture(seed = 23L, sigma = 2.5, n_groups = 60L)
	single = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8,
		smart_cold_start = FALSE, n_random_starts = 0L)
	multi = fast_logistic_glmm_cpp(d$X, d$y, d$group_id, j_T = 1L, eps_g = 1e-8,
		smart_cold_start = FALSE, n_random_starts = 8L, multistart_jitter_sd = 1.5)
	expect_lte(multi$neg_loglik, single$neg_loglik + 1e-6)
	# If this fixture does not trap the single start (multistart_selected == 0 and the
	# two neg_loglik agree), change `seed` / `sigma` until it does and record which
	# values were needed in a comment here; the assertion below is the one that matters.
	if (multi$multistart_selected != 0L) expect_gt(single$neg_loglik - multi$neg_loglik, 1e-6)
})
```

- [ ] **Step 3: Run the tests to confirm they fail** — `Rscript -e 'pkgload::load_all("R/EDI", compile = FALSE); testthat::test_file("R/EDI/tests/testthat/test-multistart-nonconcave.R")'`. Expected: FAIL — `unused argument (n_random_starts = 0)`.

- [ ] **Step 4: Create `src/optimization_multistart.h`** with the D1 content.

- [ ] **Step 5: Wire `fast_logistic_glmm.cpp`.** Add `#include "optimization_multistart.h"` after its existing helper include. Add the three arguments to the exported signature and to the internal function it forwards to (the pattern at `:478`; keep them **before** `warm_start_fisher_info`). Replace the `optimize_fixed_likelihood(...)` call at `:514` with the D2 block, using `extra = variance_component_starts(par, total - 1, fixed_spec, 8.0)`. Add the four provenance `.set(...)` fields to both the success and the `catch (...)` result maps (zeros / `NA` in the catch branch). Run `Rcpp::compileAttributes("R/EDI")` so `RcppExports.R/.cpp` pick up the new arguments.

- [ ] **Step 6: Targeted compile** — only `fast_logistic_glmm.cpp` and `RcppExports.cpp`, relink, `pkgload::load_all("R/EDI", compile = FALSE)` (memory `feedback_targeted_compile_only`). Never a full build.

- [ ] **Step 7: Run the tests** — same command as Step 3. Expected: 4 PASS. If test 4's `if` branch is skipped, tune the fixture as its comment says.

- [ ] **Step 8: Commit** — `git add R/EDI/src/optimization_multistart.h R/EDI/src/fast_logistic_glmm.cpp R/EDI/R/RcppExports.R R/EDI/src/RcppExports.cpp R/EDI/tests/testthat/test-multistart-nonconcave.R R/EDI/tests/testthat/fixtures/multistart_logistic_glmm_baseline.rds` ; `git commit -m "feat(multistart): shared multistart helper, wired into the logistic GLMM kernel"`.

### TODO-2: Refactor `fast_ordinal_glmm.cpp` onto the helper — bit-for-bit

**Files:**
- Modify: `R/EDI/src/fast_ordinal_glmm.cpp:337-395` (the hand-rolled sweep), export signature `:757-775`
- Test: `R/EDI/tests/testthat/test-multistart-nonconcave.R` (append), `R/EDI/tests/testthat/fixtures/multistart_ordinal_glmm_baseline.rds` (new)

**Interfaces:** consumes D1 exactly; produces nothing new.

- [ ] **Step 1: Record the baseline** with the current build, using `make_ordinal_glmm_optimizer_fixture()` from `test-ordinal-glmm-optimizer-robustness.R:4-18` (copy the function into the new test file) at `eps_g = 1e-6`, both with `warm_start_params = c(0, 0, 0, 0, -3)` and with the smart cold start; save `params`, `neg_loglik`, `b`, `log_sigma` for both to the fixture `.rds`.

- [ ] **Step 2: Write the failing test:**

```r
test_that("ordinal GLMM refactor onto the multistart helper is bit-for-bit", {
	d = make_ordinal_glmm_optimizer_fixture()
	base = readRDS(test_path("fixtures", "multistart_ordinal_glmm_baseline.rds"))
	warm = fast_ordinal_glmm_cpp(d$X, d$y, d$group_id, K = 3L, j_T = 0L,
		warm_start_params = c(0, 0, 0, 0, -3), eps_g = 1e-6)
	cold = fast_ordinal_glmm_cpp(d$X, d$y, d$group_id, K = 3L, j_T = 0L, eps_g = 1e-6)
	expect_identical(warm$params, base$warm$params)
	expect_identical(warm$neg_loglik, base$warm$neg_loglik)
	expect_identical(cold$params, base$cold$params)
	expect_identical(cold$neg_loglik, base$cold$neg_loglik)
	expect_true(cold$multistart_n_tried >= 4L)   # the deterministic log-sigma sweep
})
```

  Note the ordinal GLMM is the one kernel where a supplied `warm_start_params` does **not** skip the deterministic sweep today (`:346-358` runs it regardless) — preserve that: its `extra` is unconditional, and only the *random* layer is gated on `warm_start_params.has_value()`.

- [ ] **Step 3: Run to confirm failure** (`multistart_n_tried` is `NULL`). 

- [ ] **Step 4: Replace `:346-395`** with: `MultistartSpec ms; ms.n_random_starts = warm_start_params.has_value() ? 0 : n_random_starts; ms.jitter_sd = multistart_jitter_sd; ms.seed = ...; ms.improvement_tol = 0.0; ms.polish = MultistartPolish::Always; ms.warm_hessian_all_starts = true;` then `auto extra = variance_component_starts(par, total - 1, fixed_spec, max_abs_log_sigma);` and the multistart call with `info_start_ptr`. Keep the `multistart_used_lbfgs` / Newton-polish logic that follows `:395` reading from `msr.best`. Add the three arguments and four provenance fields.

- [ ] **Step 5: Targeted compile + tests** — `fast_ordinal_glmm.cpp`, `RcppExports.cpp`; run the new test file **and** `test-ordinal-glmm-optimizer-robustness.R`, `test-ordinal-glmm-alpha-buf.R`. Expected: all PASS, identical numbers.

- [ ] **Step 6: Commit** — `git commit -m "refactor(multistart): ordinal GLMM sweep onto the shared helper, bit-for-bit"`.

### TODO-3: The remaining variance-component kernels

**Files (modify, one commit each, same recipe as TODO-1 Step 5):**
- `R/EDI/src/fast_poisson_glmm.cpp:408`
- `R/EDI/src/fast_ordinal_clmm.cpp:107`
- `R/EDI/src/fast_clogit_plus_glmm.cpp:559`
- `R/EDI/src/fast_hurdle_poisson_glmm.cpp:520`
- `R/EDI/src/fast_weibull_frailty.cpp:369`
- `R/EDI/src/fast_gaussian_lmm.cpp:450` — two sweeps (`log σ_u`, `log σ_e`); read the parameter layout above `:450` to get both indices
- Test: append one block per kernel to `test-multistart-nonconcave.R`

- [ ] **Step 1 (per kernel): baseline fixture** — a small deterministic dataset in the test file (grouped design, `n ≈ 160`, `set.seed`) and the current build's `params` / `neg_loglik` saved to `fixtures/multistart_<kernel>_baseline.rds`.
- [ ] **Step 2: failing tests** — the same three assertions as TODO-1's first three tests (`n_random_starts = 0` bit-for-bit; reproducible and never worse; warm start skips), with the kernel's own argument names.
- [ ] **Step 3: wire** — include, three arguments, D2 block with `variance_component_starts(...)`, four provenance fields (both success and error branches), `compileAttributes`.
- [ ] **Step 4: targeted compile, run tests, commit** `feat(multistart): <kernel>`.

### TODO-4: Mixture / dispersion kernels

**Files:**
- `R/EDI/src/fast_negbin_regression.cpp:308` — `extra = scalar_nuisance_starts(par, p, fixed_spec, {log(negbin_moment_theta(y)), log(10), log(25), kNegBinPoissonBoundaryLogTheta})`; add `inline double negbin_moment_theta(const Eigen::VectorXd& y)` to `optimization_multistart.h` (the formula from `fast_hurdle_negbin.cpp:153-157`).
- `R/EDI/src/fast_zinb.cpp:412` — the θ sweep above **plus** the ZI-intercept start from D3; the ZIP-limit fallback at `:301` stays as the post-hoc boundary check it is today (it runs on `msr.best`).
- `R/EDI/src/fast_hurdle_negbin.cpp:150-290` — replace `fit_truncated_negbin_with_fallback`'s "extras only on failure" with the helper (`extra = make_truncated_negbin_candidate_starts(...)`, unchanged generator); keep its Newton-then-L-BFGS retry order by leaving `try_alg` for the *primary* only. This changes semantics from fallback to best-of: document in the commit message.
- `R/EDI/src/fast_zero_augmented_poisson.cpp:303` — ZIP branch only (the hurdle-Poisson branch is concave; gate `extra` and the random layer on the ZIP flag the kernel already carries).
- `R/EDI/src/fast_beta_regression.cpp:260`, `R/EDI/src/fast_zero_one_inflated_beta.cpp:467` — `scalar_nuisance_starts(par, log_phi_index, fixed_spec, {0.0, 4.0})`. Both hard-code `maxit`/`tol` (`1000, 1e-6` and `1500, 1e-6`); pass those through unchanged.
- Test: append per kernel.

- [ ] **Step 1: baselines** (per kernel; count fixtures with ~60% zeros for ZINB/ZIP so the mixture is live; `y ∈ (0,1)` from a beta with `φ = 5` for beta / ZOIB).
- [ ] **Step 2: failing tests** — the three standard assertions, plus for ZINB: `expect_true(fit$multistart_n_tried >= 6L)` (primary + 4 θ + 1 ZI-intercept).
- [ ] **Step 3: wire, compile, test, commit** per kernel.

### TODO-5: Stereotype logit, copula / dependent-censoring survival, ordinal cauchit

**Files:**
- `R/EDI/src/fast_stereotype_logit.cpp:815` (default alg `"newton_raphson"` — pass it through as `default_optimization_alg`) — `extra` = the sign-flipped start and the equally-spaced-scores start (D3); read the parameter layout (`β` block, `φ` block) from the functor above `:815` to build them.
- `R/EDI/src/fast_survival_models_optim.cpp:591` (Clayton) and `:698` (dep-cens) — confirm the dependence parameter's index and scale from the functors at the top of each optim function, then `scalar_nuisance_starts` at the D3 values.
- `R/EDI/src/fast_ordinal_cauchit_regression.cpp:159` — random layer only (`extra` empty).
- Test: append per kernel; for the stereotype logit add `expect_equal(abs(fit$params[phi_idx]), abs(single$params[phi_idx]), tolerance = 1e-6)` to check the sign-flip start lands on the same optimum up to symmetry.

- [ ] Steps as TODO-3 (baseline, failing tests, wire, targeted compile, test, commit) per kernel.

### TODO-6: R side — policy table, setter, call sites

**Files:**
- Modify: `R/EDI/R/globals.R` (after `:1018`) — `get_multistart_dispatch_policy()`, `set_multistart_dispatch_policy()`, `edi_multistart_dispatch_policy()`; export the first two like their cold-start twins (check `NAMESPACE` / roxygen `@export` on `set_cold_start_dispatch_policy`).
- Modify: `R/EDI/R/inference_all_abstract.R:34-76` (initialize), `:366-386` (add `set_multistart` / `get_multistart` beside `set_optimization_alg`).
- Modify: every R call site of a touched kernel. Known files: `inference_count_zero_augmented_poisson_abstract.R` (`fast_zinb_cpp` ×3, `fast_zero_augmented_poisson_cpp`), `helper_zoib.R`, `inference_proportion_zero_one_inflated_beta.R`, `local_machine_tuning_axes.R` (ZOIB — pass `n_random_starts = 0L` there: the tuner must not multistart), `inference_count_KK_combined.R` (Poisson GLMM), `inference_ordinal_KK_clmm_abstract.R`, `inference_incidence_KK_combined.R`, `inference_proportion_KK_combined.R`, `inference_incidence_KK_cond_logit_glmm_abstract.R`, `inference_continuous_KK_glmm.R`, `helper_survival_fits.R`, `inference_survival_GLMM_weibull_frailty_normal.R`, `inference_survival_GLMM_weibull_frailty_loggamma.R`, `inference_survival_dep_cens_transform.R`, `inference_count_KK_cond_poisson.R`, `inference_ordinal_stereotype_logit.R`, `helper_glm_fit.R` + `inference_proportion_beta.R` (beta), `inference_count_hurdle.R`, `inference_ordinal_cauchit.R`, `inference_ordinal_KK_combined.R`. `fast_logistic_glmm_cpp` and `fast_negbin_regression_cpp` have no direct `name(` caller — find their wrappers with `graft callers fast_logistic_glmm_cpp` / `graft callers fast_negbin_regression_cpp` (likely `do.call` or a `helper_*` wrapper) before editing.
- Test: `R/EDI/tests/testthat/test-multistart-policy.R` (new)

**Interfaces:**
- Produces: `set_multistart(n_random_starts = NULL, jitter_sd = NULL, seed = NULL)` (invisible `self`, clears `private$cached_values` when anything changes), `get_multistart()` → `list(n_random_starts, jitter_sd, seed)`, and the three `globals.R` policy functions.

- [ ] **Step 1: Write the failing tests:**

```r
library(testthat)
library(EDI)

test_that("multistart policy defaults: on for nonconcave classes, off elsewhere", {
	expect_identical(edi_multistart_dispatch_policy("InferenceIncidLogRegr"), 0L)
	expect_identical(edi_multistart_dispatch_policy("InferenceOrdinalKKCLMM"), 4L)
	expect_identical(edi_multistart_dispatch_policy("InferenceOrdinalCauchitRegr"), 4L)
})

test_that("set_multistart_dispatch_policy overrides and resets", {
	on.exit(set_multistart_dispatch_policy(reset = TRUE))
	set_multistart_dispatch_policy(list(default = 2L))
	expect_identical(edi_multistart_dispatch_policy("InferenceIncidLogRegr"), 2L)
	set_multistart_dispatch_policy(reset = TRUE)
	expect_identical(edi_multistart_dispatch_policy("InferenceIncidLogRegr"), 0L)
})

test_that("set_multistart on an inference object flows to the kernel and clears the cache", {
	# Use the ordinal CLMM class: build a KK design + Inference object exactly as
	# test-ordinal-glmm-optimizer-robustness.R / fixtures/legacy_ordinal_kk_glmm.R do,
	# then:
	inf = <construct InferenceOrdinalKKCLMM on the fixture>
	expect_identical(inf$get_multistart()$n_random_starts, 4L)
	est_default = inf$compute_estimate()
	inf$set_multistart(n_random_starts = 0L)
	expect_identical(inf$get_multistart()$n_random_starts, 0L)
	est_single = inf$compute_estimate()
	# Both are legitimate optima; the multistart one is never worse in likelihood.
	expect_true(is.finite(est_default) && is.finite(est_single))
})
```

  Replace `<construct ...>` with the concrete constructor call from `fixtures/legacy_ordinal_kk_glmm.R` — copy it, do not describe it.

- [ ] **Step 2: Run to confirm failure** (`could not find function "edi_multistart_dispatch_policy"`).
- [ ] **Step 3: Implement** the `globals.R` trio (copy `:894-971`, rename, integer values, `checkmate::assertIntegerish` on override values), the abstract-class fields + setter/getter, and thread the three arguments through every call site listed above.
- [ ] **Step 4: `pkgload::load_all("R/EDI", compile = FALSE)`; run `test-multistart-policy.R` and `test-multistart-nonconcave.R`.** Expected: PASS.
- [ ] **Step 5: Run the bulk suite for the touched families** — `R/package_tests/testthat_bulk` files matching `ordinal|count|proportion|survival|glmm|robust` (see `run_comprehensive_suite.R` for the invocation). Any numeric diff must be a fit where `multistart_selected != 0`; inspect each and confirm `multistart_improvement > 1e-6`. A diff on a fit with `multistart_selected == 0` is a bug — stop and fix.
- [ ] **Step 6: Commit** — `git commit -m "feat(multistart): policy table, set_multistart(), kernel call sites"`.

### TODO-7: Robust regression (bisquare) — Huber start + multistart (D4)

**Files:**
- Modify: `R/EDI/src/fast_robust_regression.cpp:22-30` (ψ definitions), `:101-112` (initial estimate), `:154-` (IRLS loop), `:301-312` (signature)
- Test: `R/EDI/tests/testthat/test-multistart-robust.R` (new)

- [ ] **Step 1: Audit first.** Read `:22-60` and `:301-340` and write down, in the test file's header comment, what `method = "MM"` and `c` actually do today (does a Huber stage precede bisquare? which `c` applies to which ψ?). The rest of this task assumes bisquare starts from OLS; if the audit shows a Huber stage already exists, skip Step 4's Huber addition and keep the rest.
- [ ] **Step 2: Baseline** — `set.seed(5); n = 120; x = rnorm(n); y = 1 + 2 * x + rnorm(n); y[1:12] = y[1:12] + 15` (10% gross outliers); save the current bisquare fit's `b`, `scale`, `num_iter`.
- [ ] **Step 3: Failing tests** — `n_random_starts = 0` is bit-for-bit **only when the Huber stage already existed** (otherwise this test asserts the *new* Huber-started result equals a recorded MASS::rlm(method = "MM") reference to `tolerance = 1e-4`, and the roxygen documents the change); reproducibility; warm-start skip; and `expect_lt(objective(multi), objective(single) + 1e-8)` where `objective` is `Σ ρ_bisquare(r / s)` computed in R.
- [ ] **Step 4: Implement D4** (Huber stage if missing; jittered starts around it; select by the bisquare M-objective at fixed scale; three arguments; four provenance fields).
- [ ] **Step 5: Targeted compile (`fast_robust_regression.cpp`, `RcppExports.cpp`), tests, commit** `feat(multistart): bisquare robust regression starts from Huber, with multistart`.

### TODO-8: Documentation, diagnostics, cost ledger

**Files:**
- Modify: roxygen on every touched kernel (`@param n_random_starts`, `@param multistart_jitter_sd`, `@param multistart_seed`, and a `@section Multistart:` paragraph pointing at this plan's D1 semantics — copy the paragraph, do not summarize it differently per kernel); `set_multistart` / policy roxygen in `inference_all_abstract.R` and `globals.R`.
- Modify: `cold_starts.md` — add a "Multistart" section after the table: primary start = the row's heuristic; deterministic extras = D3 per family; random layer = `n_random_starts`, on by default for the nonconcave classes per `get_multistart_dispatch_policy()`.
- Modify: `optimizer_diagnostics_report.md` — one paragraph registering the four `multistart_*` fields beside `hit_iteration_cap` / `gradient_norm`, and the diagnostics-list plumbing (the fields ride the same path).
- Modify: `performance_profiling_and_upgrades.md` ledger — one row per nonconcave family: full-data fit time before / after with the shipped policy, measured with the `local_machine_tuning_synthetic_fixtures.R` fixtures at `n = 200`.
- Modify: `R/EDI/NEWS.md` — one entry under the next unreleased heading: "Nonconcave likelihood kernels (GLMM/LMM/frailty, ZINB/ZIP/ZOIB, negbin, beta, stereotype, copula survival, cauchit, bisquare) now run a deterministic + random multistart on full-data fits; `set_multistart()` / `set_multistart_dispatch_policy()` control it; replicate fits and concave kernels are unchanged."

- [ ] Steps: write the roxygen (no `roxygenize` mid-batch — `feedback_no_interim_roxygenize`; run it once at the end of this task), edit the three plan files, run the timing script and paste the rows, commit `docs(multistart): roxygen, cold_starts/diagnostics/perf ledger, NEWS`.

### TODO-9: Python `edi_kernels` binding parity

**Files:**
- Find with `grep -rn "fast_logistic_glmm\|fast_zinb\|fast_gaussian_lmm" python/src/` (the binding translation units and the generated `python/src/edi_kernels/_core.pyi`).
- Modify: each binding that exposes a touched kernel — add the three arguments with the same defaults; regenerate the stub per `python/README`'s stubgen instruction.
- Test: `python/tests/` — one test per touched binding asserting `fast_zinb(..., n_random_starts=0)` returns the same `params` as before (record the baseline in the test as literals from a fixed numpy seed), and that `n_random_starts=4` returns a `dict` carrying the four `multistart_*` keys.

- [ ] Steps: baseline, failing test, bind, build the wheel per `feedback_python_package_release_workflow` (scoped commit; **no push / tag**), test, commit `feat(edi_kernels): multistart arguments on the nonconcave kernels`.

### TODO-10: Close-out

- [ ] Re-run the full `R/EDI/tests/testthat` suite and the bulk suite (`run_comprehensive_suite.R`); paste the summary line into this file under "Results".
- [ ] Tick the TODOs above, add a "Results" section here with the TODO-6 Step 5 diff inventory (which fits changed, by how much), and update `release_v1_1_0.md → TODO-17s` and `_master.md` Phase 4 to "done".

---

## Self-review (2026-09-03)

- **Spec coverage:** D1 → TODO-1; D2/D3 → TODO-1..5; D4 → TODO-7; D5 → TODO-6; Equivalence → the bit-for-bit tests in every kernel task and TODO-6 Step 5; Python → TODO-9; docs → TODO-8. The ordinal GLMM's "sweep even when warm-started" quirk is preserved explicitly (TODO-2 Step 2 note).
- **Placeholders:** the two intentional discovery steps are commands, not "TBD" (`graft callers ...` for the two kernels without a direct `name(` caller; `grep` for the Python binding files). TODO-6's `<construct ...>` is a pointer to a concrete fixture file to copy from.
- **Type consistency:** `n_random_starts` (`int` / `integer`), `multistart_jitter_sd` (`double`), `multistart_seed` (`int` → `std::uint32_t`), result fields `multistart_n_tried`, `multistart_n_finite`, `multistart_selected`, `multistart_improvement` — the same names in D2, every kernel task, TODO-6, TODO-8, TODO-9.
