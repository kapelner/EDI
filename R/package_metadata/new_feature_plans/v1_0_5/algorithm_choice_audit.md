# Algorithm Choice Audit: Is Every Kernel the Best-Known Algorithm for Its Problem?

> **Depends on:** none to read; several rows below depend on plans already
> in this directory (linked inline). Distinct from, and complementary to,
> `performance_profiling_and_upgrades.md`, which asks "is the *implementation*
> of the chosen algorithm fast?" (hoisting, allocation, SIMD, layout,
> parallelism). This file asks the question that program does not: "is the
> *chosen algorithm* the right one for the problem?" Its §8.5 ("Algorithmic:
> work per fit") already contains four items that belong to this audit
> (adaptive Gauss–Hermite, TODO-153; early stopping for Monte-Carlo p-values,
> TODO-156; linear-algebra choices, TODO-155; a scaling sweep, TODO-162) —
> referenced, not duplicated, below. Also complementary to `quantum_upgrade.md`,
> which asked the same question one level further out ("could a fundamentally
> different *substrate*, not just a different classical algorithm, help?") and
> answered no; this file stays entirely classical.
> **Motivating question (2026-09-03, user):** "GPUs and QPUs can't help EDI
> become faster. Only algorithms and CPUs and better parallelization. Do we
> have an audit of all the algorithms to ensure they're the best?" The answer
> at the time of asking was no — this file is that audit, and
> `algorithm_ab_testing_framework.md` is the harness that must clear any
> "prototype" row below before it is promoted to "adopt."

Date: 2026-09-03 (rows A–M); **2026-10-09 full per-kernel sweep** (rows N–AC,
corrections to A–M, new TODOs). The per-kernel evidence (one row per `.cpp`
kernel and R hot loop, with options-and-disadvantages tables) is in the
companion file **`algorithm_choice_audit_catalog.md`**. It is ~2,400 lines,
which is why it is a separate file rather than appended here. Start with the
section "2026-10-09 full-catalog sweep" below. **Which algorithms EDI implements, and where:**
the single source of truth is `../../audits/algorithm_inventory.csv` (one row per
file and symbol, with its audit row and reference URLs; built 2026-11-16 from the
catalog's kernel tables, which are now a frozen snapshot).

## Scope and method

Every `fast_*` / `design_*` / `bisection_*` / `randomization_*` computational
kernel in `EDI/src/` implements *some* algorithm for its problem. This audit
asks, per kernel or kernel family, four questions:

1. **What does EDI do today**, and what is its time complexity in the
   variables that matter (`n`, `p`, `B` replicates, `|R|` reservoir size)?
2. **What is the best-known algorithm** for the same problem in the
   statistical/numerical-methods literature, with a citation?
3. **What would it plausibly win**, at the sizes EDI actually runs at
   (`n` in the tens to low thousands, `p` in the tens, `B` in the hundreds
   to low thousands) — not at the asymptotic sizes where a textbook result
   is usually stated?
4. **Verdict** — one of:
   - **Keep** — current choice already is the best-known algorithm for this
     problem (or the literature has no better one), or a superior algorithm
     exists only at scales EDI does not run at.
   - **Keep, tracked elsewhere** — a real gap exists but is already an open
     item in another plan; referenced, not re-proposed.
   - **Prototype** — a credible alternative exists, is not yet validated on
     EDI's actual data shapes, and must go through
     `algorithm_ab_testing_framework.md` before any default changes.
   - **Adopt** — validated (rare on a first pass; nothing below starts here).

A **Keep** verdict is a citable claim, not a shrug. "Newton's method is
already optimal for a smooth strongly-concave objective at `p` in the tens"
is a claim from numerical optimization theory (no method converges faster
than quadratically without second-order information, and none needs less
than second-order information without paying for it elsewhere); "brute-force
search is fine at `n = 12`" is a claim about EDI's actual size regime, not
about the algorithm in the abstract. Both kinds appear below, and are
labeled as such.

A **Prototype** verdict is not a request to change the default. It is a
request to run the alternative through the A/B harness and let the data
decide, exactly as `multistart_nonconcave_likelihoods.md` already does for
optimizer starting points and `tune_EDI_for_this_machine()` already does for
hardware-dependent settings. Two prototype rows below are important and
concrete enough to have their own plans already
(`garthwaite_buckland_ci_search.md`, `em_algorithm_zero_inflated_mixtures.md`);
the rest are recorded here with enough detail that a future reader can spin
one out without re-deriving the finding.

---

## A. Convex / concave likelihood optimization — **Keep**

| kernel(s) | current algorithm | complexity | best-known alternative | verdict |
|---|---|---|---|---|
| logistic, probit, Poisson, log-binomial, COM-Poisson, Cox PH, ordinal logit/probit/cloglog, adjacent-category, continuation-ratio, Weibull AFT (Burridge parametrization), OLS | damped Newton / IRLS (= Fisher scoring for canonical-link GLMs) or L-BFGS, one smart cold start | `O(np²)` per iteration, quadratic (Newton) or superlinear (L-BFGS) local convergence | none — see below | **Keep** |

For a smooth, strongly concave objective in `p` in the tens, Newton's method
already achieves quadratic local convergence, which is the best rate any
method achieves without super-second-order information (McCullagh & Nelder
1989, *Generalized Linear Models*, ch. 2.5, on IRLS = Fisher scoring as the
natural algorithm for exponential-family likelihoods; Nocedal & Wright 2006,
*Numerical Optimization*, ch. 3, on Newton's quadratic-convergence
optimality among first/second-order methods). L-BFGS is the standard
fallback when the Hessian is expensive or `p` is large; at EDI's `p` the
Hessian is cheap, so Newton already wins and is already the default for
several of these families. There is no algorithm in the literature that
converges faster on this problem class at this scale — the only open
question for this family was ever *starting point* (already
`multistart_nonconcave_likelihoods.md`'s and `cold_starts.md`'s territory,
not this file's) and *linear-algebra micro-choices within one Newton step*
(`.inverse()` vs `.solve()`, QR vs Cholesky — already
`performance_profiling_and_upgrades.md → TODO-155`).

---

## B. Nonconcave *mixture* likelihoods (ZINB, ZIP, hurdle-Poisson-GLMM, ZOIB) — **Prototype**

| kernel(s) | current algorithm | complexity | best-known alternative | verdict |
|---|---|---|---|---|
| `fast_zinb.cpp:412`, `fast_zero_augmented_poisson.cpp:303` (ZIP branch), `fast_zero_one_inflated_beta.cpp:467` | joint Newton/L-BFGS on the full parameter vector (all `β`, `log θ`, ZI coefficients at once), from a multistart set of cold starts (`multistart_nonconcave_likelihoods.md`) | `O(np)` per eval, superlinear but **no monotone-ascent guarantee**; can diverge toward a boundary (exactly `../../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md`'s finding) | **EM algorithm** (Dempster, Laird & Rubin 1977, *JRSS-B*; Lambert 1992, *Technometrics*, "Zero-Inflated Poisson Regression … " — the founding EM derivation for exactly this model; McLachlan & Peel 2000, *Finite Mixture Models*, ch. 2–3) | **Prototype** — `em_algorithm_zero_inflated_mixtures.md` |

The zero-inflation indicator (structural zero vs. sampling zero) is a
textbook latent class. EM's E-step computes each observation's posterior
probability of being a structural zero in closed form from the current
`(β, θ)`; the M-step is a **weighted** GLM fit — exactly the IRLS machinery
these kernels already have (`fast_negbin_regression.cpp`'s Newton/IRLS path,
reused with observation weights). Each EM iteration is guaranteed to
increase the observed-data log-likelihood (monotone ascent, no divergence,
no boundary runaway), unlike joint Newton/L-BFGS on the mixture surface.

**The honest trade-off, not oversold:** EM does not solve the *global*
nonconcavity — it still converges to a local maximum, and multistart is
still needed for that. EM is also only linearly convergent near the optimum
(vs. Newton's quadratic), so a pure-EM run can be *slower* in wall-clock on
well-behaved data than the current L-BFGS path. The candidate win is
**robustness, not raw speed**: EM cannot produce the failure mode
`../../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md` exists to patch (an unconstrained
Newton/L-BFGS step running the dispersion parameter off to a numerical
boundary on data with no real overdispersion) because every EM step is a
likelihood increase, never an overshoot. The standard production recipe —
Redner & Walker (1984), *SIAM Review*, "Mixture Densities, Maximum
Likelihood and the EM Algorithm" — is a **hybrid**: a few EM iterations to
get near the basin reliably, then switch to Newton/L-BFGS for fast local
convergence, which is exactly a new deterministic "start" for the multistart
helper `multistart_nonconcave_likelihoods.md` already built — this item
composes with that plan rather than competing with it.

**Expected win at EDI's sizes.** Not a speed claim without data: the A/B
harness must measure (i) the fraction of `../../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md`
-style non-convergent fits that EM-then-Newton rescues that pure multistart
does not, and (ii) wall-clock relative to the current path, on the same
corpus. See `em_algorithm_zero_inflated_mixtures.md`.

---

## C. GLMM / LMM / frailty marginal likelihood (Gauss–Hermite quadrature) — **Keep, tracked elsewhere**

`_glmm_engine.h:32-41,168-242` integrates out each group's random effect
with a fixed `n_gh = 20`-node Gauss–Hermite rule. Two literature
alternatives exist:

- **Adaptive Gauss–Hermite** (Liu & Pierce 1994, *Biometrika*; Pinheiro &
  Bates 1995, *J. Comp. Graph. Stat.* — the `lme4`/`GLMMadaptive` `nAGQ`
  approach): center and scale the nodes per group at the conditional
  mode/curvature, reaching the same accuracy with 5–9 nodes instead of 20.
  **Already tracked**: `performance_profiling_and_upgrades.md → TODO-153`,
  with an expected 1.5–2.5× per-objective-call win. Not re-proposed here.
- **Laplace approximation** (`nAGQ = 1` in `lme4`'s terms): `O(1)` per group
  instead of `O(n_gh)`, much cheaper, but known to be biased for
  binary/count GLMMs with small per-group cluster sizes or extreme
  variance-component values (Joe 2008, *Comp. Stat. & Data Anal.*; Pinheiro
  & Chao 2006, *J. Comp. Graph. Stat.*, quantify the accuracy gap directly
  against AGQ). EDI's GH quadrature is the more accurate choice for the
  cluster sizes clinical-trial designs actually produce (often 2–4 per
  group in matched/blocked designs) — swapping to Laplace would be an
  accuracy *regression* disguised as a speedup. **Verdict: keep GH as the
  algorithm family; the adaptive-node refinement is the only real gap, and
  it already has an owner.**

---

## D. Randomization / bootstrap confidence-interval search — **Prototype**

`bisection_ci.cpp:29,99`, `bisection_ci_loop.cpp:26`,
`compute_ci_by_inverting_the_randomization_test_iteratively()`
(`inference_all_abstract_rand_ci.R:473`),
`invert_rand_bootstrap_test_bisection()`
(`inference_all_abstract_rand_bootstrap_ci.R:426`). Current algorithm:
**bisection** on the monotone function `p(δ)`, each step re-evaluating a
full `B`-replicate p-value at the candidate `δ`. Two improvements already
shipped against this exact bottleneck:
`randomization_ci_affine_shift_reuse.md` (the implementation reuses one null
distribution across the search via an exact shift identity) and
`randomization_ci_search_precision.md` (a final high-precision confirmation
pass after early-stopped bisection). Both reduce the cost of **each**
bisection step or of the last one; neither changes the fact that the search
is bisection at all — `O(log(range/tol))` separate full-precision
evaluations. The reuse implementation shipped 2026-10-09, but its projected
20–30× end-to-end speedup was not achieved in the recorded benchmarks:
the 2026-10-13 source-loaded grid measured 1.13–1.59× for average difference
and 1.05–2.14× for OLS; the 2026-10-15 installed-package check measured
1.12× and 1.82×, respectively. The 20–30× acceptance target remains open
pending reconciliation or an explicit maintainer decision (see
`randomization_ci_affine_shift_reuse.md` TODO-6 and release TODO-2).

**Best-known alternative for exactly this problem** — finding the root of a
function only observable through noisy Monte Carlo evaluations — is not
bisection at all: it is the **Robbins–Monro stochastic-approximation
process**, applied to Monte Carlo confidence-interval construction by
**Garthwaite & Buckland (1992, *Applied Statistics*, "Generating Monte Carlo
confidence intervals by the Robbins–Monro process")** and refined by
Garthwaite & Jones (2009, *J. Comp. Graph. Stat.*). Instead of `O(log
(range/tol))` independent full-`B` bisection steps, a single sequential
process draws one replicate at a time and updates the `δ` estimate after
each draw with a decreasing step size; it converges to the CI bound with
total simulation cost governed by the *target SE of the bound itself*, not
by re-running a fixed `B` at each of a fixed grid of candidate `δ`. This is
the standard method in permutation-test software for exactly this step
(e.g., the `coin` package's Monte Carlo confidence procedures cite
Garthwaite directly).

**Relationship to `randomization_ci_search_precision.md`'s "the real fix"
section.** That plan already names **anytime-valid confidence sequences**
(Waudby-Smith & Ramdas 2020, betting-martingale construction) as the
principled fix and records it as deferred. Garthwaite–Buckland is a
different, older, smaller lift: it is a drop-in replacement for the
bisection *driver* with only asymptotic (CLT-based) coverage guarantees,
not the exact-anytime guarantee a confidence-sequence redesign would give.
It is worth prototyping on its own because it is a much smaller change
(swap the search algorithm, keep everything else) with a plausible large
win, while the confidence-sequence redesign remains the eventual "real fix"
for a future release.

**Expected win.** Multiplicative with the affine-shift-reuse win (that
plan cuts the cost of *each* p-value evaluation the search calls;
Garthwaite–Buckland cuts the *number* of evaluations the search needs by
removing the `log(range/tol)` bisection-step structure entirely). Order of
magnitude to be measured, not asserted — see the spun-out plan.

**Verdict: Prototype** — `garthwaite_buckland_ci_search.md`.

---

## E. Small permutation p-values (tail resolution) — **Prototype, opt-in only**

Randomization/permutation p-values are computed by direct Monte Carlo:
`B` replicates, `p̂ = (\#\{|T(w)| \ge |T_{obs}|\} + 1)/(B+1)`. Resolving
`p ≈ 10^{-4}` to 10% relative accuracy needs `B ≈ 10^6` — the same
small-`p` regime `quantum_upgrade.md → §II.2` already discusses for the
(fault-tolerant-only) amplitude-estimation angle. A **classical** alternative
exists for exactly the linear-in-`w` statistics EDI already resamples
(mean difference, Wilcoxon at `δ = 0`, ridit, OLS via FWL — the same set
`quantum_upgrade.md`'s Tier B identifies): the **saddlepoint approximation**
to the permutation distribution of a linear rank/sum statistic (Robinson
1982, *Ann. Statist.*, "Saddlepoint Approximations for Permutation Tests
and Confidence Intervals"; Booth & Butler 1990, *Biometrika*). This is a
closed-form numerical approximation (one saddlepoint-equation solve, `O(1)`
in `B`, cost independent of the target p-value's size) that is known to be
extremely accurate deep in the tail — the opposite of Monte Carlo, whose
relative error is *worst* exactly where the saddlepoint approximation is
best.

**Why this is not a straightforward "adopt."** EDI's randomization tests
derive their validity from being *exact* (or asymptotically exact by
construction) under the randomization distribution — that is the whole
statistical appeal relative to model-based inference, and is presumably why
the package resamples rather than approximates everywhere else. Swapping
Monte Carlo for a saddlepoint approximation trades that exactness for
speed and tail accuracy. This is a case where the A/B harness's
*correctness*-equivalence check, not its speed check, is the gate: the
approximation must be validated against exact enumeration (`n ≤ 12`-style,
already the package's own standard for exactness checks) and against
large-`B` Monte Carlo across a battery of statistic shapes before it is
used for anything beyond a fast screening/early-stop trigger (which is a
safe use even unvalidated — a saddlepoint p-value that is clearly not near
`α` can trigger an early stop of the Monte Carlo loop, with the Monte Carlo
answer, not the approximation, still reported; this composes with
`performance_profiling_and_upgrades.md → TODO-156`'s Besag–Clifford
sequential stopping, which is a different mechanism for the same "stop
early" goal and should be compared to it, not assumed better).

**Verdict: Prototype, low priority, opt-in/diagnostic-only until validated**
— not yet spun into its own plan; record here for a future audit pass.

---

## F. Design allocation search (QUBO-shaped: `DesignFixedOptimal`) — **Keep, tracked elsewhere**

GLPK MILP exact solve for `n ≤ 20`, C++ simulated annealing (single-exchange
Metropolis) beyond that (`helper_optimal_annealing.R:117-176`,
`design_optimal_annealing_search.cpp:132`). Plain SA is a reasonable
heuristic but is known to underperform **parallel tempering** (Swendsen &
Wang 1986; Earl & Deem 2005, *Phys. Chem. Chem. Phys.*, the standard modern
reference) and **tabu search** (Glover 1989/1990) on rugged QUBO-shaped
landscapes at moderate size. This exact comparison — plain SA vs. a better
classical heuristic — is **already** the recorded follow-up in
`quantum_upgrade.md → §I.2` and `→ TODO-5`: "if [a classical Ising-style
solver] beats `annealing_design_search_cpp()` on objective-at-fixed-time,
the right follow-up is a better classical kernel (parallel tempering or
SBM), not hardware." **Verdict: keep, with the comparison already scheduled
under TODO-5** — not re-proposed as a separate item here.

---

## G. Matching (pairs, `k = 2`) — **Keep** (with a low-priority large-`n` note)

`nbpMatching::nonbimatch()` — Edmonds' blossom algorithm for minimum-weight
perfect matching, `O(n³)`. This **is** the best-known exact polynomial
algorithm for general-graph minimum-weight perfect matching; no faster
general algorithm is known (Edmonds 1965; Galil 1986 survey). **Verdict:
keep** for the general case.

One narrower opportunity: after Mahalanobis whitening, EDI's matching
distance is Euclidean, and **geometric** minimum-weight matching in the
Euclidean plane/low dimension admits faster algorithms than the general
blossom bound — `O(n^{1.5} \log n)` (Vaidya 1989, *Algorithmica*,
"Geometric Methods for Matching Points in the Plane"; Agarwal & Sharathkumar
2014 for further refinements). This only matters once `n` is in the
thousands (`nbpMatching`'s `O(n³)` is already sub-second at EDI's typical
matching sizes, tens to low hundreds). **Verdict: keep; revisit only if
matching at `n` in the thousands becomes a real use case** — not worth a
plan today.

---

## H. Sequential nearest-match designs (KK14, KK21, Atkinson, Pocock–Simon) — **Keep** (moving-metric caveat)

`kk14_incremental_covariance.md` already targets items (1)–(3) of
`DesignSeqOneByOneKK14$assign_wt()`'s per-arrival cost (rebuilding the
projected design and its covariance from scratch, `O(t p²)` per arrival,
`O(n² p²)` summed) via Welford incremental updates. It does **not** address
item (4), the nearest-match search itself against the current reservoir `R`
— `compute_proportional_mahal_distances_cpp` is a brute-force scan,
`O(|R| p²)` per arrival, `O(n |R| p²)` summed.

The textbook fix for repeated nearest-neighbor queries is a **k-d tree /
ball tree / cover tree** (Bentley 1975; Beygelzimer, Kakade & Langford
2006, cover trees), cutting the per-query cost to `O(\log |R|)` after an
`O(|R| \log |R|)` build. It does not straightforwardly apply here: the
Mahalanobis metric (`S_xs_inv`) is **recomputed every arrival** as the
running covariance updates, so a static tree built once is invalid by the
next subject — making this a *dynamic*, *metric-changing* nearest-neighbor
problem, which is a materially harder research question than "add a k-d
tree" (options include periodic tree rebuilds amortized over a window of
arrivals where the metric is nearly stable, or approximate structures
tolerant of a slowly drifting metric; neither is a known, off-the-shelf
recipe the way the k-d tree is for a static metric). At EDI's typical
reservoir sizes (`|R|` in the tens to low hundreds for a clinical trial),
brute force is already fast, and the audit finds no evidence this is a
current bottleneck. **Verdict: keep; revisit only if `|R|` in the thousands
becomes a real use case, and treat it as a research question (moving
metric), not a routine k-d-tree adoption, when it does.**

---

## I. Rerandomization acceptance–rejection — **Keep, tracked elsewhere**

`rerandomization_helpers.cpp:179`. Already fully addressed in
`quantum_upgrade.md → §II.1`: plain rejection sampling is the right
classical algorithm; amplitude amplification is a real asymptotic
improvement but fault-tolerant-only; the existing `prop_acceptable`
top-quantile mode is "the real answer today" for tight-cutoff cases. Not
re-litigated here.

---

## J. Bootstrap resampling loops (nonparametric, parametric, Bayesian) — **Prototype, moderate priority**

`base_bootstrap_loop.cpp:12`, `ols_distr_parallel.cpp:112`, the
`_bayesian_bootstrap.R` Dirichlet-weight draws, and every other
`*_bootstrap*` kernel: plain i.i.d. resampling, `B` replicates. No
algorithm improves on i.i.d. resampling's *point estimate* of the bootstrap
distribution, but **variance reduction of the Monte Carlo noise in that
estimate**, at fixed `B`, is a well-established, essentially free technique
this package does not use: **balanced bootstrap resampling** (Davison,
Hinkley & Schechtman 1986, *Biometrika*; Davison & Hinkley 1997, *Bootstrap
Methods and Their Application*, §9.4) forces each original observation to
appear exactly `B` times across all `B × n` resample slots (drawn via a
permutation of a balanced index array, rather than `n × B` i.i.d. draws),
which removes the first-order Monte Carlo variance contribution from the
imbalance itself, at the same `B` and the same per-replicate cost. It is
unbiased and requires no algorithmic change to the fitting step — only to
how bootstrap indices are drawn (`bootstrap_indices.cpp`).

A related technique, **antithetic variates** for the Bayesian bootstrap's
Dirichlet weight draws, is a smaller and more speculative win (needs a
symmetry in the weight distribution EDI would have to verify per statistic)
and is noted but not scoped here.

**Verdict: Prototype** — index-generation-only change, applies broadly
(every bootstrap-based CI/SE in the package), moderate priority; not yet
spun into its own plan. A future plan should scope it to
`bootstrap_indices.cpp` / `bootstrap_match_indices.cpp` and measure CI-width
reduction at fixed `B` on the existing bootstrap test fixtures.

---

## K. GEE working-correlation structure — **Keep** (scope gap, not an algorithm-choice gap)

`fast_gee.cpp:76-233` implements moment-based working-correlation
estimation (Liang & Zeger 1986, *Biometrika* — the founding GEE paper) for
`independence` and `exchangeable` structures only; no `AR(1)` or
`unstructured` option. Liang–Zeger's moment estimator *is* the standard
algorithm for whichever working-correlation family is chosen — this is a
**feature-scope gap** (which correlation families are offered), not an
algorithm-choice gap (the estimation method for a chosen family is already
correct). **Verdict: keep**; if `AR(1)`/`unstructured` support is ever
wanted, that is a new-feature plan, not an algorithm-audit item.

---

## L. Cox partial-likelihood tie handling — **Keep (Breslow); Efron recorded as an accuracy option** (settled 2026-10-09)

Read directly (2026-10-09). `fast_coxph_regression.cpp` implements the
**Breslow** approximation, deliberately and consistently:

- `CoxData` (`:26-74`) sorts once by `(y ↑, dead ↓)` — `O(n log n)`, done
  once per dataset and cached across replicates via
  `build_cox_data_cache_cpp` — and records `unique_event_times` and
  `event_counts` (`d_k`).
- `compute_cox_ll_grad_hess_fast` (`:143-233`) sweeps event times in reverse,
  accumulating `S0 = Σ_{R_k} e^η`, `S1 = Σ e^η x`, `S2 = Σ e^η xxᵀ` as running
  sums (no per-event risk-set rescan). Each tied set contributes
  `Σ_{D_k} η − d_k·log S0` to the log-likelihood and `d_k·(S2/S0 − e eᵀ)` to the
  information, so all `d_k` tied events share **one** denominator. That is
  Breslow (1974). Efron (1977) would instead subtract `(l/d_k)·Σ_{D_k} e^η x`
  for `l = 0..d_k−1`. Cost: `O(n p²)` per Newton iteration, which is optimal
  for this problem (every subject must touch `S2` once).
- `compute_cox_neg_ll_only` (`:105-132`) and the robust sandwich
  `compute_robust_vcov` (`:523-630`, `d_k/R_k` increments with prefix sums and a
  binary search per subject, `O(n log K + n p)`) use the same Breslow form,
  so the score, information, and sandwich agree with each other.
- It is documented (`helper_glm_fit.R:144`, "Breslow tie-handling") and
  parity-tested against `survival::coxph(ties = "breslow")`
  (`test-rcpp-fitting-real-data.R:99,196`), and `contracts_mixins.R:999-1001`
  names Breslow reference oracles.

**Options & disadvantages**

| option | cost per iteration | disadvantages | citation |
|---|---|---|---|
| **Breslow (current)** | `O(n p²)` | Biased toward 0 when ties are heavy (many events per distinct time, e.g. follow-up recorded in days or visits); the bias grows with `d_k / |R_k|` | Breslow 1974, *Biometrics* |
| Efron | `O(n p² + Σ_k d_k p²)`, i.e. about the same at EDI's tie rates | Slightly more code. Changes every Cox estimate on tied data, so parity tests, `package_tests` CSVs, and the Breslow reference oracles all need regenerating. Not faster | Efron 1977, *JASA*; default in `survival::coxph` |
| Exact partial likelihood (discrete/conditional-logistic) | `O(Σ_k |R_k| d_k)` via the Gail–Lubin–Rubinstein recursion; combinatorial if done naively | Much slower under heavy ties; assumes truly discrete time (a different model, not an approximation) | Kalbfleisch & Prentice 1973; Gail, Lubin & Rubinstein 1981 |

**Verdict: Keep.** Breslow is already the fastest of the three. Efron is
not a speed upgrade; it is an *accuracy* upgrade at essentially the same cost,
so it falls outside this audit's "faster algorithm" rule. Whether to offer it
(as an option, or as a changed default) is a modeling decision for the
package owner. It is recorded under TODO-6 rather than adopted here.

**R-side fallback consistency (fixed 2026-10-09, v1.0.5 TODO-69).** Most R paths pin it
(`inference_survival_coxph.R:21-29` `coxph.fit(method = "breslow")`,
`inference_survival_strat_cox.R:64-73`, the log-rank and Gehan null fits at
`inference_survival_log_rank.R:209` and `inference_survival_gehan_wilcox.R:218`).
Two calls previously did not, and silently used `coxph`'s default **Efron**:

- `inference_survival_coxph.R:641`, `survival::coxph(surv_obj ~ X_fit)`. This
  is the fallback when the C++ fit fails to converge, or when `use_rcpp = FALSE`.
  On tied data, the estimate therefore changes method depending on whether the
  C++ fit converged.
- `inference_survival_strat_cox.R:54`, `cox_partial_likelihood_fit_with_formula()`
  (used through `fit_cox_with_formula`, `:459`).

Both now pass `ties = "breslow"` (TODO-6(c)), so every path in the package fits
the same likelihood. Tied-data regressions cover both fallbacks and retain
explicit Efron fits as sensitivity contrasts.

`test-rcpp-fitting-equivalence.R:129,549` now also pins `ties = "breslow"`, so
those references stay correct if their currently untied fixtures gain ties.

---

## M. Deterministic CI inverters — score / gradient / Bartlett-LR use bisection where LR uses Newton — **Adopt** (added 2026-09-04, user question)

Found while answering "can Garthwaite–Buckland also be applied to score and
LR CIs?" The answer is no for these (see the note in
`garthwaite_buckland_ci_search.md`), but the question exposed an
inconsistency inside one file:

| CI | `p(δ)` | inverter | algorithm |
|---|---|---|---|
| LR (asymptotic χ²) | deterministic: one constrained refit per `δ`, closed-form p-value | `lrt_ci_nr_cpp` (`lrt_ci_newton.cpp:99-159`), called from `invert_lik_ratio_ci_newton()` (`inference_ext_ci_inversion.R:165`) | **Newton–Raphson** with the envelope-theorem derivative `dp/dδ = 2·f_χ²(T)·score[j]`, bisection only as a safeguard when the step leaves the bracket; stops at `tol_p = 1e-7` |
| score, gradient, Bartlett-corrected LR | deterministic (the Bartlett "approx" factor is analytic, Cordeiro-style — `inference_all_abstract_asymp_lik.R:437-449`, "No simulation, no replicate count"; its `B` argument is vestigial) | `pval_invert_ci_cpp` (`lrt_ci_newton.cpp:214-282`), called from `invert_test_pval_confidence_interval()` (`inference_ext_ci_inversion.R:57`; callers at `inference_all_abstract_asymp_lik.R:311,329,335`, `inference_all_abstract_count_likelihood.R:205-213`, `inference_count_hurdle.R:375`) | exponential bracket search, then **pure bisection** to `tol = 1e-6` in `δ`-space — no derivative, no secant |

Both inverters evaluate the same kind of thing (a full constrained refit
per candidate `δ`) on the same kind of function (smooth, monotone on each
side of the estimate, exactly evaluable). Bisection halves the bracket per
step — ~20 refits per bound for a `10⁶` bracket-to-tolerance ratio.
**Brent's method** (Brent 1973, *Algorithms for Minimization Without
Derivatives*, ch. 4; the algorithm behind R's `uniroot()`) converges
superlinearly on such functions with no derivative, typically in 5–8
evaluations; the Illinois/regula-falsi family gives similar counts. The
score statistic's `dδ` derivative lacks the LR's clean envelope-theorem
form, so a derivative-free method is the natural fit; alternatively, the
existing NR+bisection loop could be reused with a secant slope estimate.

**Why this is Adopt, not Prototype.** It is a deterministic root-finder
replacing a deterministic root-finder on an exactly-evaluable function: the
converged bound is identical to bisection's within `tol`, so there is no
equivalence question for `algorithm_ab_testing_framework.md` to arbitrate
— the existing CI tests (which check the bound, not the path to it) are
the gate. The win is purely the evaluation count, ~3–5× fewer constrained
refits per bound, on a path whose cost *is* the refits.

**Why not Robbins–Monro here** (the question that surfaced this row).
RM's advantage over bisection comes entirely from replacing one precise
`r`-replicate evaluation with one cheap noisy draw. For these inverters
there is no cheap draw — the atomic operation is a refit returning the
exact `p(δ)` — so RM and bisection pay identical cost per evaluation, and
on a noiseless residual RM's decreasing step size (`c_k = c₁/k^{0.75}`)
makes its error decay like `exp(−const·k^{0.25})`, sub-exponential:
~100–200 refits versus bisection's ~20 and Brent's ~5–8. RM would be the
*slowest* of the three on this problem.

---

## 2026-10-09 full-catalog sweep

**Why.** Rows A–M were organized by problem family and were never checked
against every kernel. On 2026-10-09 the owner asked for a full catalog: every
kernel's algorithm, a check that it is the fastest known, and a TODO
wherever it isn't, plus the faster-but-worse options with their
disadvantages. The sweep covered all 132 files in `R/EDI/src/` and all 211
files in `R/EDI/R/`, using 12 read-only subagents with disjoint file sets
(method and caveats are at the top of `algorithm_choice_audit_catalog.md`).
About 870 catalog/options table lines resulted.

**Standard used.** Rows were judged on "fastest known *that does not give
up something EDI needs*". Where a faster option exists but loses exactness,
accuracy, robustness, or RNG reproducibility, the options tables record it
along with the disadvantage, and the verdict stays Keep. This is the same
reasoning that keeps 20-node GH over Laplace (row C) and Monte Carlo over the
saddlepoint approximation (row E).

**Status of what follows.** Three findings below were verified by the
coordinator and have bug-fix plans. Everything else is subagent output. It is
specific (file:line, complexity, citations) but **unverified**, so re-read
the code before acting. All speed multiples are theoretical.

### Corrections to rows A–M

- **A.**
  - "COM-Poisson" is a mislabel. `fast_cpoisson_combined.cpp` is a
    conditional-Poisson (matched-pairs) plus reservoir-Poisson model. No
    COM-Poisson code exists.
  - Log-binomial does **not** merit Keep: it has a finite-difference Hessian, an
    infeasible default start (η > 0), and fits by design fail at boundary MLEs
    (→ rows N, Z).
  - Weibull AFT uses `(β, log σ)`, not the Burridge parametrization.
  - Most concave ordinal / continuation-ratio / Weibull / GLMM fits **default to
    L-BFGS** even though an analytic Hessian and a Newton path already exist.
    Their L-BFGS stopping rule often exits with the gradient well above `tol` (→ TODO-12).
  - Logistic IRLS, probit IRLS and the cpoisson-combined Newton have no step-halving.
- **B (re-scoped).**
  - EM applies only to **ZINB and ZIP**, the two with a genuine latent zero class.
  - Hurdle-Poisson, hurdle-NB and ZOIB likelihoods **factorize** into
    independent concave/regular parts (Mullahy 1986). ZOIB's 0/1/interior
    category is observed, not latent, so `em_algorithm_zero_inflated_mixtures.md`
    TODO-6 (ZOIB EM) is moot (→ row P).
  - **No multistart is wired into any of the five mixture kernels.** ZINB is
    one crude start plus boundary-rescue fallbacks.
  - The ZINB Hessian is finite-difference, despite the header.
  - The hurdle-Poisson GLMM belongs in row C. It has its own non-adaptive
    7-node GH, not the engine's 20-node rule.
- **C.**
  - Fixed 20-node non-adaptive GH is confirmed file by file.
  - `performance_profiling_and_upgrades.md → TODO-153` names only
    `_glmm_engine.h`. It must also cover `fast_weibull_frailty.cpp` and
    `fast_hurdle_poisson_glmm.cpp` (7-node).
  - For groups of size ≤ 2, the per-group mode solve eats most of the node
    saving, so expect about 1.2–1.6×, not 1.5–2.5×. The stronger case for
    adaptive GH is accuracy at large σ.
  - The Gaussian LMM already uses the closed-form marginal likelihood (no
    quadrature), but it is not profiled and has no REML option.
- **D.**
  - **Affine-shift reuse has not shipped**: the `t0s_rand` reuse branch is
    dead, consistent with the 2026-08-30 paper-plans audit. What has shipped:
    sequential-MC early stopping, the high-precision confirm pass, and the
    closed-form BRT CI for affine statistics.
  - Separately, the randomization and BRT CI inverters target the **wrong
    level** (verified bug, see below).
- **E.** There is no exact Wilcoxon or rank null anywhere in C++; it is all
  Monte Carlo (→ `exact_rank_tests_shift_algorithm.md`, row R).
- **F.**
  - The quadratic MILP is not the tightest known formulation: plain McCormick,
    no RLT cardinality rows (Adams & Sherali 1986), no symmetry cut, and the
    rank-p structure is ignored.
  - Exact revolving-door enumeration with an O(p) incremental objective would
    certify optima up to n ≈ 30 (n = 25: measured 311 s in GLPK, ~ms in theory).
  - **Validity concern:** the BRT for `DesignFixedOptimal` replays a much weaker
    solver (2k annealing moves, 1 chain) than the one that produced the
    observed allocation.
- **H.**
  - KK14's per-arrival distance search is fine: one inverse per arrival, then a
    batched distance computation.
  - The real hotspot is **Atkinson's null-draw kernel**, at O(B·n²·p²) (→ TODO-10).
  - Every sequential design **re-imputes all rows (missRanger) and rebuilds the
    model matrix on every arrival**, which is O(n²p) overall (→ TODO-30).
- **J.** `bootstrap_indices.cpp` is test-only. Production bootstrap draws go
  per replicate through `sample_int_replace_cpp(n, n)` and siblings, so the
  balanced bootstrap needs a batch-of-B API wired into
  `draw_bootstrap_indices()` (TODO-4 re-scoped).
- **K.** `fast_gee.cpp` clusters have size ≤ 2, so exchangeable, AR(1) and
  unstructured working correlations coincide, and the "family scope gap" is
  moot for this kernel. Possible bug: α̂ is never divided by φ̂ (efficiency only).
- **M.**
  - The Bartlett **"approx" factor is Monte Carlo** (B = 99 replicate pairs
    at *every* δ), not analytic. Only "exact" is analytic.
  - Count-family LR CIs also go through the bisection inverter.
  - The LR Newton inverter could iterate on the signed root
    `sgn·√T − z` (Venzon & Moolgavkar 1988), which takes ~2–3 refits instead
    of ~4–8.
  - None of `brent_ci_inversion.md`'s TODOs are done.

### New consolidated rows N–AC

The subagents tagged ~80 `NEW-<slug>` families. They consolidate into these
rows (slug mapping in the appendix):

| # | family | headline finding | verdict |
|---|---|---|---|
| N | finite-difference derivatives where analytic forms exist | log/identity-binomial score+Hessian, ordinal GLMM / CLMM engine observed information, delta-method gradients, ZINB Hessian, KK21 dependent-censoring Hessian (unreachable). These cost ~p× and give NaN Hessians at boundaries | **Adopt** (TODO-14) |
| O | special functions and floating-point accuracy | `pnorm_fast` / `fast_log_pnorm` are clamped at \|x\| ≥ 8 (`fast_erfc.h:154-170`), so probit, dependent-censoring and GLMM-probit likelihoods go flat in the tails. One-pass variances cancel catastrophically. Hurdle-NB `log(1−p0)` loses precision | **Adopt** (accuracy, same speed; TODO-22) |
| P | separable / reducible / closed-form models fit by a generic optimizer | ZOIB, hurdle-Poisson; continuation-ratio on a dense expanded matrix; Gaussian linear score/LR CIs (closed form, exact F null); CMH design variance by 5,000 MC draws | **Adopt** (TODO-13, -16, -17) |
| Q | sort-and-sweep statistics; presorting in resampling | KM/RMST/log-rank BRT re-sort every draw; JT weighted superiority builds `outer()` matrices; weighted KM median and Breslow hazard are O(n²)/O(nK) | **Adopt** (TODO-11, -18) |
| R | exact discrete nulls and enumeration | **JT exact p-value enumerates compositions, exponential in K**: 2.8e12 leaves at K = 11, n = 200, with no size guard and no interrupt, so R hangs. Fix with a polynomial DP. Also exact enumeration for `DesignFixedOptimal` | **Adopt** (TODO-15, -20) |
| S | randomization / sequential-design draws, sampling, RNG | Atkinson null draws O(B·n²·p²); `replicate(randomizr::…)` instead of the existing C++ block/cluster kernels; the urn design has no C++ kernel; `std::shuffle` is not cross-platform reproducible | **Adopt** (TODO-10, -21, -23) |
| T | forward-stepwise selection (KK21) | beta / NB / ordinal refit every candidate at every step (O(p²) fits). Logistic already uses the score-test scheme. φ uses a 19-point grid (up to ~13% SE bias) | **Prototype** (TODO-25) |
| U | distances and small dense linear algebra | optimal-blocks Mahalanobis O(n²p²) by explicit inverse; a redundant second QR; Atkinson FullPivLU+inverse to get one row; the GH rule recomputed per fit (3 duplicate copies) | **Adopt**, low priority (TODO-29) |
| V | refit economics in CI searches and replicate loops | the param-bootstrap batch is re-run 3× (estimate / CI / p); Bartlett MC per δ; double-bootstrap redraws per grid α; cold-started CI refits; pure-R replicate loops for Lin/KK OLS, cpoisson (`optim` BFGS), and **interval-censored rand tests re-solving the pooled NPMLE r times** | mixed: **Adopt** TODO-11, -16, -19; **Prototype** TODO-26, -27 |
| W | quantile-regression LP and rank estimators | `rq "br"` is right at EDI sizes (Keep), but the point fit and the BB replicates use different methods; the formula `rq()` is called inside ~20–40k-fit CI searches (use `rq.fit`); the HL bisection never early-stops on ties | **Adopt** (TODO-19) |
| X | robust regression | the **"MM" option is not Yohai's MM**: it is bisquare IRLS from an OLS start with the scale fixed once. There is no S-estimator and no high-breakdown guarantee. KK robust randomization draws fit M while the reported estimate is "MM" | **Prototype** + rename now (TODO-31) |
| Y | interval-censored NPMLE | `interval::icfit` runs plain self-consistency EM from a uniform start. `initfit = "initEMICM"` needs no new dependency; `icenReg::ic_np` (EMICM, C++, has `weights=`) would also unblock the interval-censored Bayesian bootstrap | **Prototype** (TODO-28) |
| Z | boundary / constrained MLE, cold starts | log-binomial infeasible start and no constrained solver; Cox and adjacent-category cold starts regress without an intercept; ZINB start π = 0.5, θ = 1 (a consistent truncated-count start exists); NB α = 1/θ bound-constrained parametrization could retire most boundary-rescue code | start fixes **Adopt**; solvers **Prototype** (TODO-24, -32) |
| AA | nonconcave non-mixture likelihoods | stereotype (Newton discarded at β = 0 since the γ Hessian block is singular; replicates get no multistart while the observed statistic does); cauchit; dependent-censoring copula | **Prototype** (TODO-33); the multistart part is already `multistart_nonconcave_likelihoods.md` TODO-5 |
| AB | variance estimators | weighted cluster sandwich scales scores by √w (check the convention); g-comp SE omits the covariate-sampling term (conditional vs population target, so check intent) | **Investigate** |
| AC | infrastructure algorithms | `run_all_inference` should schedule longest-first from the runtime manifest (LPT); the tuning harness should use paired-difference racing; per-arrival re-imputation (see H) | **Adopt** (LPT); others **Prototype** |

### Correctness findings surfaced by the sweep

These are not algorithm-choice items. They are recorded here because the
sweep found them, and they outrank every speed TODO.

**Verified by the coordinator (bug-fix plans written):**

1. **KK21 Weibull fits converge to the wrong point.** In
   `kk21_stepwise_survival.cpp:21-86` and `kk21_weights.cpp:744-840`, the IRLS
   working response has fixed point Σx(z−1)(eᶻ−δ) = 0, and the σ-score is off by
   2Σδ/σ. A pure-R port gave β₀ = −9.5 with σ stuck at its clamp of 10, against
   `survreg`'s 1.006 / 0.69. The existing test re-implements the same wrong
   formulas. → `../../bug_fix_plans/v1_0_5/kk21_weibull_irls_wrong_fixed_point.md`
2. **Randomization and BRT CIs are (1 − α/2) intervals.** They invert a two-sided
   p-value at α/2, giving 97.5% at α = 0.05. In existing comprehensive_tests
   output, for 0.03 < p ≤ 0.045 the "95%" rand CI excludes 0 in only 17% of 429
   cases. → `../../bug_fix_plans/v1_0_5/rand_ci_inverts_two_sided_pval_at_half_alpha.md`
3. **Cox tie method formerly depended on which point-estimate fallback fired.**
   The two unpinned `coxph()` calls used Efron while everything else used
   Breslow (row L, TODO-6(c)); **v1.0.5 TODO-69 resolved those two calls by
   explicitly selecting Breslow.**

**Verification of the remaining findings (2026-10-09, TODO-B4 done).** Five
adversarial verifier subagents checked 26 findings (F1–F26) by code reading and small
execution checks (`load_all(compile = FALSE)` or pure-R ports; nothing
compiled). The coordinator re-ran F8, F9, F15 and F22 and reproduced them, and
re-read F1/F1b. Evidence and fix sketches: `algorithm_choice_audit_catalog.md
§13`. **Result: 21 confirmed, 3 partial, 2 refuted.** "IVWC" marks a legacy
class: exported, but never used in public examples.

| id | finding | verdict | severity / path |
|---|---|---|---|
| F1 | `DesignSeqOneByOneRandomBlockSize` redraws: generic loop never advances `private$t` (every redraw uses the last subject's stratum); block queue env shared by shallow clone and never reset; working C++ kernel `random_block_size_redraw_w_cpp` is never called | **CONFIRMED** | wrong rand / bootstrap p and CI, default path; redraws 51–76% block-balanced vs 100% |
| F1b | `sample(private$block_sizes, 1)` with a single block size samples `1:k` (R gotcha) | **CONFIRMED** (coordinator re-read) | corrupts **real assignments** when `block_sizes` has length 1 (first block balanced 70%); default `c(4,6,8)` unaffected |
| F1c | `draw_ws_according_to_design()` on the user's design overwrites its `w` | **CONFIRMED** | design state corruption |
| F2 | `.cox_simulate_stratified` scales the baseline by the stratum-max risk but subjects by the global max | **CONFIRMED** | stratified-Cox parametric-bootstrap LR p/CI (non-default); 61% of simulated times tied at `max_time`, refit β 0.635 vs 1 |
| F3 | `std::shuffle` / `<random>` distributions are implementation-defined | **CONFIRMED** | cross-platform seed reproducibility only (distributions correct); default paths; in-code "cross-platform guarantee" comments are wrong |
| F4 | per-replicate seed collisions | **PARTIAL** | 31-bit space, ~2.3% chance at B = 1e4; effect ≤ 1/B; negligible |
| F5 | studentized/smoothed BRT unseeded | **REFUTED** | all sites seeded; repeat runs identical |
| F6 | JT exact p-value enumeration exponential in K, no interrupt | **CONFIRMED** | hang (~13 h at K = 11, n = 200), results correct; only on an explicit exact call |
| F7 | `InferenceAllKKWilcoxIVWC` HL variance 2.09× too small | **CONFIRMED** | ~81% coverage at nominal 95% (class run reproduced); IVWC |
| F8 | ridit scoring of an interior level absent from the reference arm | **CONFIRMED** (coordinator re-ran) | estimate / SE / p wrong on default `reference = "control"`: 0.172 vs Mann–Whitney 0.225; rand kernel too |
| F9 | Newcombe p-value when `uniroot` brackets fail | **CONFIRMED** (coordinator re-ran) | p = 1 where `prop.test` gives 1e-29 (90/100 vs 10/100); default `uniroot` tol inflates small p up to ~160×; a test pins p = 1 |
| F10 | Zhang exact CI bracket never validated | **PARTIAL** | truncation real and reachable (CI too narrow; ±∞ bounds reported finite); error-as-0 harmless; tolerance minor |
| F11 | KK hurdle-Poisson IVWC placeholder SEs of 1.0 | **CONFIRMED, wider** | BB CI miscalibrated; `estimate_only` estimate wrong; rand valid but low-power; IVWC |
| F12 | KK robust: draws M vs reported MM | **CONFIRMED** for KK (C++ kernel claim refuted) | `KKRobustRegrOneLik` M null vs call-order-dependent MM/M observed statistic; BB hard-codes M; `KKRobustRegrIVWC` rand p **always NA** on the default path |
| F13 | ordinal KK RE BB uses a fixed-effects fit | **CONFIRMED** | BB centred on the marginal β (0.39) vs reported conditional (0.583); CLMM currently masked by the open σ-collapse bug |
| F14 | KK clogit+GLMM BB via glmmTMB/Laplace on all rows | **CONFIRMED** | BB shifted ~0.35 log-OR; a reference test locks the mismatch in |
| F15 | legacy `KKMeanDiffIVWC` zero `m_mat` | **CONFIRMED** (coordinator re-ran) | rand p 0.19 shipped vs 0.005 with the correct compound null; IVWC |
| F16 | non-KK incidence g-comp BB unweighted mean | **PARTIAL** | consistent non-KK convention (sample estimand), ~1% effect; undocumented, inconsistent with KK |
| F17 | ZOIB R plogis-normalize vs C++ softmax | **CONFIRMED** | non-default `marginal_mean_diff` estimate+SE wrong (−0.0876 vs consistent −0.0816); mild default param-bootstrap distortion |
| F18 | cloglog opposite β sign convention | **CONFIRMED** | **root cause of the open ordinal param-bootstrap sign bug, for cloglog only** (PO / cauchit / probit fine); an uncommitted fix is already in the working tree (`inference_ordinal_cloglog.R` + a new test) |
| F19 | Firth penalty sign | **CONFIRMED** | no callers; the reference test asserts the wrong sign |
| F20 | GEE α̂ not divided by φ̂ | **CONFIRMED** | efficiency + Rcpp/geepack parity: overdispersed Poisson 0.95 (clamped) vs 0.33; proportions 0.06 vs 0.76 |
| F21 | dependent-censoring CI rule | **CONFIRMED, worse** | outcome-dependent CI choice biased toward non-rejection; the studentized CI goes NA whenever it excludes 0 (it can never reject); docs inaccurate |
| F22 | `aftsrr(se = "ISMB", B = 0)` | **CONFIRMED, worse** | `InferenceSurvivalKKRankRegrIVWC` **always returns NA** (coordinator re-ran); IVWC |
| F23 | `DesignFixedOptimal` BRT replays a weaker solver | **CONFIRMED** | conservative: replicate objective 6–45× worse; size ≈ 0.02–0.03 at nominal 0.05 when R² is high; undocumented |
| F24 | weighted cluster sandwich √w | **REFUTED** | cluster-constant Dirichlet weights make √w the correct convention |
| F25 | g-comp SE omits the covariate-sampling term | **CONFIRMED** (undocumented estimand choice) | 0–6% SE gap for the population effect; the roxygen claim "no closed-form SE" is false |
| F26 | exact binomial: Clopper–Pearson CI vs minlike p | **CONFIRMED** | CI/test incoherent for δ0 ≠ 0 only |

**Filed 2026-10-09 (owner decision):** all confirmed and partial findings →
`../../bug_fix_plans/v1_0_5/algorithm_sweep_verified_findings.md → TODO-1..25` →
`../../future_release_plans/release_v1_0_5.md → TODO-70..94` (F18 already in
v1.0.5 TODO-16; refuted F5 and F24 not filed). Original grouping, kept for reference: Suggested grouping,
by impact on non-legacy public classes:
- **(a) Wrong results on default paths:** F1/F1b/F1c, F8, F9, F12 (OneLik), F21.
- **(b) Wrong resampling calibration:** F13, F14, F2, F17, F10, F23.
- **(c) Legacy IVWC:** F7, F11, F12 (IVWC), F15, F22.
- **(d) Efficiency / docs / coherence:** F20, F25, F26, F16, F6, F3, F19, F4.

## Estimated speedup multiples (2026-09-04, theoretical — not measurements)

Requested follow-up: a single table of expected speedup across the
Prototype rows. **Read the basis column before the multiple column.** Only
one row below (C) is an estimate already produced by real benchmarking
elsewhere in the repo; every other number is a complexity or literature-typical
argument derived for this table, which is exactly what
`algorithm_ab_testing_framework.md`'s harness exists to confirm or kill —
none of these numbers should be quoted as a measured result.

| # | problem | current | alternative | regime | estimated multiple | basis |
|---|---|---|---|---|---|---|
| B | ZINB/ZIP/ZOIB mixtures | joint Newton/L-BFGS + multistart | EM-then-Newton hybrid | fits that already converge fine | ~0.8–1.0× (can be *slightly slower* — EM's linear-rate warm-up is overhead when Newton alone would've worked) | theoretical: EM is linearly convergent, Newton superlinear |
| B | (same) | (same) | (same) | fits the joint optimizer currently fails on (`../../bug_fix_plans/v1_1_0/negbin_dispersion_convergence.md`'s fixture) | not a wall-clock ratio — converts a failed/`nonest` fit to a converged one | theoretical: EM's monotone-ascent guarantee |
| C | GLMM/LMM/frailty quadrature | fixed 20-node GH | adaptive GH (5–9 nodes) | every GLMM objective call | 1.5–2.5× per call; 1.2–2× end-to-end on GLMM-heavy workflows | **already estimated elsewhere** — `performance_profiling_and_upgrades.md §8.8`, not this audit |
| D | randomization/bootstrap CI search | bisection (~20–35 full-precision steps) | Robbins–Monro (Garthwaite–Buckland) | any CI search | ~3–20× | structural: ratio derives from the bisection step count, unmeasured |
| D | (composed) | bisection + affine-shift-reuse | + Robbins–Monro | any CI search | multiplicative benefit is unmeasured; affine-shift reuse shipped 2026-10-09, but its projected 20–30× end-to-end speedup was not observed (see measurements above) | structural |
| E | small permutation p-values | Monte Carlo (`B` replicates) | saddlepoint approximation | `p ≈ 0.05` | ~25× but not a useful regime — already cheap | derived from this repo's `B(p)` figures (`quantum_upgrade.md`: `B ≈ 501` at `p ≈ 0.05`) vs. saddlepoint's O(1) cost |
| E | (same) | (same) | (same) | `p ≈ 10⁻⁴` | ~5×10⁴× | same derivation (`quantum_upgrade.md`: `B ≈ 10⁶` at `p ≈ 10⁻⁴`) |
| E | (same) | (same) | (same) | `p ≲ 10⁻⁶` | classical MC infeasible (`B` → 10⁸+); saddlepoint stays O(1) — unbounded | same |
| F | design allocation search (QUBO) | plain SA | parallel tempering / tabu | any `n` beyond exact MILP | not yet estimated — contingent on `quantum_upgrade.md → TODO-5`'s own benchmark, not yet run | none |
| G | pair matching | blossom, O(n³) | geometric matching, O(n^1.5 log n) | `n` in the thousands (not EDI's current regime) | asymptotic complexity ratio only: ~200× at `n=100`, ~40,000× at `n=5,000` — not a wall-clock measurement, moot at EDI's actual sizes | asymptotic complexity, illustrative only |
| J | bootstrap resampling | i.i.d. resample | balanced bootstrap | any bootstrap CI/SE at fixed `B` | ~1.1–1.5× effective-replicate reduction for smooth statistics (variance reduction at fixed `B`, not wall-clock reduction) | literature-typical (Davison, Hinkley & Schechtman 1986); not yet measured on EDI's own statistics |
| M | score / gradient / Bartlett-LR CI inversion | pure bisection (`pval_invert_ci_cpp`) | Brent (derivative-free, superlinear) | every such CI, both bounds | ~3–5× fewer constrained refits per bound (~20 → ~5–8); result identical within `tol` | evaluation-count arithmetic for a deterministic root; the only row here that needs no A/B — the existing CI tests are the gate |

## Summary table

| # | problem class | current | best-known alt. | verdict |
|---|---|---|---|---|
| A | concave/convex likelihoods | Newton/IRLS/L-BFGS | none better at this `p` | **Keep** |
| B | mixture likelihoods (ZINB/ZIP/hurdle/ZOIB) | joint Newton/L-BFGS + multistart | EM (Lambert 1992) | **Prototype** → `em_algorithm_zero_inflated_mixtures.md` |
| C | GLMM/LMM/frailty quadrature | fixed 20-node GH | adaptive GH | **Keep, tracked** (`performance_profiling_and_upgrades.md → TODO-153`) |
| D | randomization/bootstrap CI search | bisection | Robbins–Monro (Garthwaite & Buckland 1992) | **Prototype** → `garthwaite_buckland_ci_search.md` |
| E | small permutation p-values | Monte Carlo | saddlepoint (Robinson 1982) | **Prototype, opt-in only, low priority** |
| F | design allocation search (QUBO) | plain SA | parallel tempering / tabu | **Keep, tracked** (`quantum_upgrade.md → TODO-5`) |
| G | pair matching | blossom, O(n³) | geometric matching, O(n^1.5 log n) | **Keep** (large-`n` note only) |
| H | sequential nearest-match | brute force | k-d tree (moving metric) | **Keep** (research question if ever revisited) |
| I | rerandomization accept/reject | rejection sampling | amplitude amplification | **Keep, tracked** (`quantum_upgrade.md → §II.1`) |
| J | bootstrap resampling | i.i.d. resample | balanced bootstrap (Davison et al. 1986) | **Prototype, moderate priority** |
| K | GEE working correlation | moment estimator, 2 families | same estimator, more families | **Keep** (scope, not algorithm) |
| L | Cox tie handling | Breslow, `O(np²)`/iter (settled 2026-10-09) | Efron (same cost, more accurate under heavy ties; not faster) | **Keep** — Efron is an accuracy option, owner's call |
| M | score / gradient / Bartlett-LR CI inversion | pure bisection (LR path already uses Newton) | Brent (Brent 1973) | **Adopt** → `brent_ci_inversion.md` |
| N | FD derivatives where analytic forms exist | central differences | analytic score / Hessian / Louis information | **Adopt** (TODO-14) |
| O | special functions / FP accuracy | clamped normal tails, one-pass variances | asymptotic tail branch, shifted sums | **Adopt** (accuracy; TODO-22) |
| P | separable / closed-form models | joint generic optimizer | split fits, closed forms, structured Hessian | **Adopt** (TODO-13, -16, -17) |
| Q | sort/sweep stats in resampling | re-sort per draw, O(n²) loops | presort once + O(n) counting/merge | **Adopt** (TODO-11, -18) |
| R | exact nulls / enumeration | composition enumeration (JT), GLPK MILP | polynomial DP; revolving-door enumeration | **Adopt** (TODO-15, -20) |
| S | design null draws, sampling, RNG | O(B n² p²) Atkinson; R `replicate()`; `std::shuffle` | Schur-complement update; existing C++ kernels; explicit Fisher–Yates | **Adopt** (TODO-10, -21, -23) |
| T | KK21 forward-stepwise | refit every candidate (beta/NB/ordinal) | score-test scheme (already used for logistic) | **Prototype** (TODO-25) |
| U | distances / small dense LA | explicit inverses, duplicate QRs / GH rules | Cholesky whitening, LDLT, caching | **Adopt**, low priority (TODO-29) |
| V | refit economics in CI / replicate loops | recomputation, cold starts, pure-R loops | memoize, warm start, C++ batch kernels, pooled NPMLE | **Adopt** / **Prototype** (TODO-11, -16, -19, -26, -27) |
| W | quantile LP / rank estimators | mixed `br`/`fn`; formula `rq()` | one method; `rq.fit` | **Adopt** (TODO-19) |
| X | robust regression | bisquare IRLS from OLS start (labeled "MM") | true MM (FAST-S start) | rename now; **Prototype** (TODO-31) |
| Y | interval-censored NPMLE | self-consistency EM | EMICM (`initEMICM`, `icenReg::ic_np`) | **Prototype** (TODO-28) |
| Z | boundary MLE / cold starts | infeasible or crude starts; unconstrained solvers | feasible / consistent starts; constrained solvers | starts **Adopt**; solvers **Prototype** (TODO-24, -32) |
| AA | nonconcave non-mixture likelihoods | single start, plain Newton→L-BFGS | damped scoring, closed form at p = 1, multistart | **Prototype** (TODO-33) |
| AB | variance estimators | — | — | **Investigate** |
| AC | infrastructure (scheduling / tuning) | FIFO; independent-sample timing | LPT; paired racing | **Adopt** / **Prototype** |

---

## Implementation TODOs

- [ ] TODO-1 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-21`): **A/B testing harness** (gates every Prototype row above):
  `algorithm_ab_testing_framework.md → TODO-1..N`. Build once, reuse for
  every item below and every future algorithm-choice question.
- [ ] TODO-2 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-21`): **Garthwaite–Buckland CI search** (row D):
  `garthwaite_buckland_ci_search.md → TODO-1..N`. Depends on TODO-1's
  harness for the promotion decision.
- [ ] TODO-3 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-21`): **EM for zero-inflated mixtures** (row B):
  `em_algorithm_zero_inflated_mixtures.md → TODO-1..N`. Depends on TODO-1.
- [ ] TODO-4 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Balanced bootstrap resampling** (row J) — not yet a plan.
  **Re-scoped 2026-10-09:** `bootstrap_indices.cpp` is test-only; the change
  must be a batch-of-B generator wired into `draw_bootstrap_indices()` (see
  catalog §7 TODO-1). Original scope: `bootstrap_indices.cpp`, `bootstrap_match_indices.cpp`; measure
  CI-width reduction at fixed `B` through the TODO-1 harness before writing
  the implementation plan.
- [ ] TODO-5 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Saddlepoint p-value screening** (row E) — not yet a plan;
  lowest priority of the four Prototype rows because it is the only one
  that changes an exactness guarantee rather than only cost. Scope as
  early-stop-trigger-only (reported p-value stays Monte Carlo) for the
  first version.
- [x] TODO-6: **Cox tie-handling verification** (row L): DONE 2026-10-09.
  `fast_coxph_regression.cpp` is Breslow throughout (fit, neg-ll-only,
  robust sandwich), documented and parity-tested against
  `coxph(ties = "breslow")`. Remaining follow-up: (a) **owner decision made 2026-10-19**:
  Efron as the default with `ties = "breslow"` exposed (an accuracy change,
  not a speed change; needs CSV and oracle regeneration), implemented under
  `release_v1_1_0.md → TODO-61` / audit TODO-39. Follow-ups (b) and (c) were completed
  under v1.0.5 TODO-69: the equivalence references and both R fallbacks now
  explicitly select Breslow.
- [x] TODO-7 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-52`, as a per-release pass): Re-run this audit's method (not its conclusions) whenever a *(ticked by the TODO audit 2026-11-18: R/package_metadata/new_feature_plans/v1_0_5/algorithm_choice_audit.md:1202; .github/workflows/algorithm-audit-drift.yml:23; .github/scripts/algorithm_audit_drift.py:292; .github/workflows/algorithm-audit-drift.yml:30; R/package_metadata/audits/research_findings/2026-11-16-run43896063512.md; R/pac...)*
  new kernel family ships, and after each Prototype item resolves through
  the harness, to keep the summary table current.
  **Cadence and triggers (amended 2026-10-22, owner decision).** Two layers;
  procedure and guardrails in `algorithm_audit_runbook.md`:
  - *Full pass* (re-run the method on every flagged row): at each release
    close (the original trigger), when a new kernel family ships, and after
    each Prototype item resolves through the harness (TODO-1).
  - *Drift check* (mechanical, read-only): **monthly, the 21st at 06:07 UTC**,
    `.github/workflows/algorithm-audit-drift.yml`. It runs four checks and
    opens or updates one issue labelled `algorithm-audit-drift`; it commits
    nothing and closes the issue when clean:
    1. comparator versions: CRAN vs `audits/comparator_versions.json`, with
       keyword-filtered NEWS since the pinned version;
    2. kernel drift: `git log` since each row's `reviewed` date over the files
       that the `watch` column of `audits/algorithm_inventory.csv` assigns to it;
    3. plan-state hygiene: every audit TODO's `release_vX.md → TODO-N` target
       must exist and not be a moved-stub, and every unchecked TODO needs a tag;
    4. algorithm inventory (added 2026-11-16): every `R/EDI/src` and `R/EDI/R`
       file is inventoried or exempt, every entry's file and symbol still exist,
       and every entry's reference URLs are listed and still resolve.
  - *Research* (monthly, Friday 00:07 Jerusalem after the first Thursday, added 2026-11-16): one Claude agent per batch of
    ≤ 8 algorithms searches the web for a faster acceptable algorithm, and one
    `inventory` agent judges new and changed functions against the inventory.
    Results arrive as a pull request: `../../audits/research_findings/<date>.md`
    (unverified findings) plus inventory updates. Needs the
    `CLAUDE_CODE_OAUTH_TOKEN` or `ANTHROPIC_API_KEY` secret. Details:
    `algorithm_audit_runbook.md`.
  - *Re-review trigger:* a flag means "re-look", not "wrong". A row is cleared
    by re-reviewing it, then bumping its `reviewed` date and re-pinning
    (`--snapshot`) in the same commit.
  - *Done when:* the workflow is on `main`, has run once (manual dispatch),
    and the first issue has been triaged.
- [ ] TODO-8 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Replace the "Estimated speedup multiples" section's
  theoretical figures with measured ones** as each Prototype item's A/B
  report lands (TODO-2..5 above); until then that section's numbers must
  stay clearly labeled as unmeasured estimates, never quoted elsewhere as
  results.
- [ ] TODO-9 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-17w`): **Brent for the score / gradient / Bartlett-LR CI inverters**
  (row M): `brent_ci_inversion.md → TODO-1..3`. Adopt, not Prototype —
  deterministic root-finder swap, bound identical within `tol`; gated on
  the existing CI tests, not the A/B harness. Independent of TODO-1..5.
- TODO-37..41 (which choices users may make: auto / expose / dial) are in the
  last section, "Which algorithm choices should users get to make?".

### TODOs added by the 2026-10-09 sweep

**Release scheduling (2026-10-15, user decision).** Each TODO below names its
release slot. The split: items faster **and** at least as accurate with no
new options → `release_v1_1_0.md → TODO-50`; speed-only drop-ins →
`release_v1_2_0.md → TODO-22`; items needing the A/B harness →
`release_v1_2_0.md → TODO-23` (after that file's TODO-21 builds the harness).

Ordered by expected value. "§n TODO-k" points into
`algorithm_choice_audit_catalog.md`. **Adopt** = deterministic drop-in;
same result within tolerance (or bit-identical where stated); the existing
tests, plus an equivalence test where noted, are the gate. **Prototype** = needs
`algorithm_ab_testing_framework.md`. All wins are theoretical.

**Correctness first** (not speed; plans in `../../bug_fix_plans/`):
- [ ] TODO-B1 (scheduled in `../../future_release_plans/release_v1_0_5.md → TODO-67`): `kk21_weibull_irls_wrong_fixed_point.md`.
- [ ] TODO-B2 (scheduled in `../../future_release_plans/release_v1_0_5.md → TODO-68`): `rand_ci_inverts_two_sided_pval_at_half_alpha.md`.
- [x] TODO-B3 (completed 2026-10-09; scheduled in `../../future_release_plans/release_v1_0_5.md → TODO-69`): row L TODO-6(c), pin `ties = "breslow"` in the two R fallbacks. Both calls and the two generic C++-equivalence references now explicitly select Breslow; tied-data regressions cover the formula fallback and `InferenceSurvivalCoxPHRegr(use_rcpp = FALSE)` and retain default-Efron fits as sensitivity contrasts.
- [x] TODO-B4 (completed verification task; its resulting findings are
  scheduled separately in `release_v1_0_5.md → TODO-70..94`):
  **verification DONE 2026-10-09** (21 confirmed / 3 partial / 2 refuted;
  table above, evidence in catalog §13). Filed as
  `algorithm_sweep_verified_findings.md` → `release_v1_0_5.md → TODO-70..94`
  (2026-10-09, owner decision). Original text: verify, and file plans for,
  the unverified findings listed in
  "Correctness findings surfaced by the sweep". RandomBlockSize redraws, the
  KK Wilcoxon IVWC SE, and the ridit scoring come first.

**Adopt (deterministic drop-ins):**
- [ ] TODO-10 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **Atkinson null draws via Schur complement / per-t precompute**
  (`generate_permutations.cpp:80-119,279-293`). O(B·n²·p²) → O(n²p² + B·n·p²),
  ~50× at n = 200, p = 10, B = 501. Same RNG consumption; reproduce the singular
  0.5 fallbacks with explicit tolerances. §7 TODO-5, §12 TODO-3.
- [ ] TODO-11 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **Interval-censored log-rank/Wilcoxon randomization tests:
  compute the pooled-NPMLE scores once.** They are label-invariant at δ = 0, so each
  draw becomes one linear statistic (`inference_survival_log_rank.R:237`,
  `inference_survival_gehan_wilcox.R:251`). ~r× (≈ 500×) fewer NPMLE solves.
  Gate: reproduce `ictest`'s statistic on fixtures. §10 TODO-5.
- [ ] TODO-12 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Newton as default** where an analytic Hessian and a Newton path
  already exist and the likelihood is concave: ordinal logit/probit/cloglog,
  adjacent-category, continuation-ratio, and the logistic/Poisson/clogit GLMMs and
  Gaussian LMM (A/B for wall-clock only: unique MLE). Weibull AFT also gets
  warm-started BRT draws, but needs a full A/B because it is not jointly concave.
  §2 TODO-1/2, §4 TODO-6, §5 TODO-3.
- [ ] TODO-13 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Exploit separability.**
  - ZOIB: skip the fixed γ block in resampling now (Adopt), and fit the two blocks separately (§3 TODO-2, §11 TODO-1).
  - Hurdle-Poisson: block-separate Newton (§3 TODO-3).
  - Continuation-ratio: structured Hessian instead of a dense `X_aug`, ~5–8× (§2 TODO-3).
  - Update `em_algorithm_zero_inflated_mixtures.md` to drop ZOIB.
- [ ] TODO-14 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **Analytic derivatives instead of FD.**
  - log/identity-binomial (`fast_log_binomial_regression.cpp:580-662`, ~p×, also removes NaN Hessians; §1 TODO-1);
  - ordinal-GLMM and CLMM-engine Louis information (§4 TODO-2);
  - Poisson marginal-estimand delta method (§12 TODO-8);
  - ordinal g-comp gradient (§2 TODO-5).
- [ ] TODO-15 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`; size guard already shipped as `../../future_release_plans/release_v1_0_5.md → TODO-90`): **JT exact null by polynomial DP**, with a size guard and
  `checkUserInterrupt` (`fast_jonckheere_terpstra.cpp:82-136`). This turns a hang
  into sub-second at large K. Gate: brute force at n ≤ 12. §6 TODO-1.
- [ ] TODO-16 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **Closed-form Gaussian score/gradient/LR CIs and exact F(1, n−p)
  LR null** (`inference_continuous_lin.R:396`, `inference_continuous_KK_ols_one_lik.R:290`,
  `inference_continuous_ols.R:352`). ~10–20 refits → 0. §10 TODO-8.
- [ ] TODO-17 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **CMH design variance in closed form** for complete, Bernoulli
  and blocked designs (keep MC for sequential designs; `inference_incidence_cmh.R:192`). §11 TODO-3.
- [ ] TODO-18 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **Presort in survival resampling.**
  - KM/RMST BRT (`fast_survival_stats.cpp:536,628`, bit-identical, ~2–5×);
  - log-rank BRT presort+merge (§5 TODO-1/2);
  - weighted KM median O(n²) → O(n log n) (§10 TODO-6);
  - Breslow hazard and its inversion via reverse cumsum + `findInterval` (§12 TODO-7);
  - JT weighted superiority O(n_T·n_C) → O(n+K) (§10 TODO-1).
- [ ] TODO-19 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **Replicate-loop economics.**
  - Memoize the param-bootstrap batch across estimate/CI/p (3×; §9 TODO-1).
  - `rq.fit` instead of formula `rq()` in the KK quantile rand CI (3–10×; §9 TODO-6b).
  - Weighted C++ cpoisson-combined instead of R `optim` BFGS (10–50×; §10 TODO-2).
  - C++ batch randomization kernel for Lin/KK OLS (§10 TODO-9).
  - Parallel BRT draw materialization (§9 TODO-4).
- [ ] TODO-20 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Exact enumeration solver for `DesignFixedOptimal`**, n ≤ ~30
  (revolving door, O(p) incremental objective; §12 TODO-1). Then tighten the
  MILP beyond that size: RLT rows, symmetry cut (not for the A-ratio objective),
  optimal-blocks reformulation (§12 TODO-2, -5; benchmark only).
- [ ] TODO-21 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **Use the existing C++ block/cluster draw kernels** instead of
  `replicate(randomizr::…)` (§12 TODO-11). Add a C++ urn kernel (§12 TODO-10).
- [ ] TODO-22 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **Accuracy fixes at the same speed:**
  - `pnorm_fast` / `fast_log_pnorm` tail branch (§6 TODO-2);
  - shifted one-pass variances (§7 TODO-4);
  - stable `fast_dnbinom_mu` (§6 TODO-8);
  - exact `qnorm` in Wilson/Newcombe (§6 TODO-7).
- [x] TODO-23 (closed 2026-10-15 in `../../future_release_plans/release_v1_0_5.md → TODO-91` (finding F3)): **Explicit Fisher–Yates instead of `std::shuffle`** (portability
  and seed reproducibility; §7 TODO-3). Fixtures refreshed; 8-leg CI run confirmed identical draws on Linux, macOS and Windows.
- [ ] TODO-24 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **Feasible / consistent starts.**
  - Log-binomial: start with max η < 0.
  - Adjacent-category and Cox: put the intercept in the start regression.
  - Proportional odds: use marginal-quantile thresholds.
  - (§1 TODO-3a, §2 TODO-4.) Concave cases only change the iteration count.
  Also add glm2-style step-halving to logistic, probit and cpoisson-combined (§1 TODO-2).
- [ ] TODO-29 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): Low-priority linear-algebra items:
  - whitened Mahalanobis for optimal blocks;
  - drop the redundant QR;
  - Atkinson LDLT;
  - cache the GH rule;
  - Cox Hessian via SYRK;
  - Weibull-frailty gradient O(nK+np) (benchmark first, since a prior rewrite was slower);
  - `qr_reduce_preserve_cols` single factorization.

  (§1 TODO-6, §4 TODO-1, §5 TODO-4/5, §8 TODO-1/5/6.)
- [ ] TODO-34 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-22`): **LPT scheduling in `run_all_inference`** from the runtime manifest (§11 TODO-5).

**Prototype (A/B harness):**
- [ ] TODO-25 (φ half scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`; score-test stepwise half in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **KK21 score-test stepwise for beta/NB/ordinal** (~p/2× fewer
  fits), and 1-D Brent for φ instead of the 19-point grid (§8 TODO-3/4).
  Re-run the KK21 weight comparison afterward.
- [ ] TODO-26 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **CI-search refit economics.**
  - Bartlett-approx: compute the MC factor once per CI (5–20×; §9 TODO-3).
  - Double-bootstrap: one outer×inner set with continuous calibration (5×; §9 TODO-2).
  - Tangent warm start for CI refits (§9 TODO-5).
  - Fixed-critical-value bootstrap-calibrated LR CI (§9 TODO-9).
  - SMC early stopping in the param-bootstrap CI search (§9 TODO-8).
  - Influence-function BCa acceleration as an opt-in (§9 TODO-7).
- [ ] TODO-27 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Weighted C++ kernels for Bayesian-bootstrap replicates**
  instead of per-replicate glmmTMB: ZIP/ZINB/hurdle-NB/KK-hurdle at 10–100×,
  and KK clogit+GLMM. This also fixes the estimate/replicate model mismatches.
  (§10 TODO-3, §11 TODO-4.)
- [ ] TODO-28 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-50`): **EMICM for the Turnbull NPMLE** (`icfit(initfit = "initEMICM")`
  first, then `icenReg::ic_np`, whose `weights=` unblocks the interval-censored BB).
  §10 TODO-7, §12 TODO-6.
- [ ] TODO-30 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Stop the per-arrival full re-imputation and model-matrix
  rebuild** in sequential designs. O(n²p) → O(np), with n random-forest
  imputations reduced to a few (§12 TODO-9). This changes design output.
- [ ] TODO-31 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`; the rename/document half is not harness-gated): **Robust regression.** Rename or document "MM" as bisquare-M from an LS
  start *now* (no A/B). A true MM with a FAST-S start, used for the point estimate
  with warm-started replicates, is a Prototype (§1 TODO-4/8).
- [ ] TODO-32 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`): **Mixture / boundary solvers.**
  - ZINB/ZIP consistent truncated-count start, compared head-to-head with the EM plan (§3 TODO-1).
  - NB α = 1/θ bound-constrained parametrization (§3 TODO-4).
  - Log-binomial constrained solver (§1 TODO-3b).
  - NB2 Fisher scoring (§1 TODO-5).
  - Modified-Newton safeguard in the shared `optimize_likelihood_newton` (§1 TODO-9).
  - Profiled 1-D Gaussian LMM plus REML (§4 TODO-3).
  - Closed-form probit CLMM (§4 TODO-4).
- [ ] TODO-33 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`; the `DesignFixedOptimal` BRT solver-mismatch bullet shipped as `../../future_release_plans/release_v1_0_5.md → TODO-81` (F23)): **Nonconcave non-mixture models.**
  - Stereotype: curvature-safe scoring, the p = 1 closed form, and a well-defined replicate statistic (§2 TODO-6/7).
  - Annealing: polish pass plus an n-scaled move budget (§12 TODO-4).
  - Fix the `DesignFixedOptimal` BRT solver mismatch (validity).
- [ ] TODO-35 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-23`; needs a policy decision first): **Exact randomization distribution when the support is ≤ r**
  (complete randomization, pairs, clusters). This needs a policy decision first (§7 TODO-6).
  Also exact all-pairs enumeration for KK21's λ (§7 TODO-7).
- [x] TODO-36 (covered by `../../future_release_plans/release_v1_0_5.md → TODO-82` (`aftsrr`, F22) and `→ TODO-88` (g-comp SE, F25); the √w convention was refuted (F24)): Investigate the row AB items: the √w sandwich convention, *(ticked by the TODO audit 2026-11-18: R/package_metadata/bug_fix_plans/v1_0_5/algorithm_sweep_verified_findings.md:18; R/EDI/R/inference_incidence_gcomp.R:326; R/package_metadata/future_release_plans/release_v1_0_5.md:10241; R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R:178; R/EDI/R/inference_survival_KK_rank_regr_ivwc_abst...)*
  the g-comp SE target, and `aftsrr` with B = 0.

---

## Beyond algorithm choice: where speed comes from after rows A–AC are "done" (2026-10-09)

**Question (2026-10-09, owner):** "If we have the best algorithm, are sure it
cannot be faster on GPU/QPU/TPU, and we've audited the assembly
implementation and optimized compilation flags, does that mean we cannot get
faster? Is there anything else one can do?"

**Answer: no, that is not the limit.** "Best algorithm" means best for the
problem *as posed*, one kernel at a time. Several levers sit outside all four
of those boxes, and most of this sweep's findings are of these kinds rather
than "swap kernel X for a faster one". Each lever below cites this file's
TODOs where they apply.

1. **Do less work.** Avoid recomputing things: the parametric bootstrap
   reruns its B refits up to three times (TODO-19). Stop Monte Carlo early
   once the answer is clearly far from α (`performance_profiling_and_upgrades.md
   → TODO-156`, TODO-26). Replace simulation with exact or closed-form answers:
   the Gaussian CIs (TODO-16) and the CMH variance (TODO-17). Loosen
   tolerances that are tighter than the statistics need.
2. **Pose the problem differently.** An optimal kernel inside a loop can
   still be the wrong design. Inverting a CI by bisection, with a full null
   distribution at every step, is costly even if each step is optimal. Solving
   the whole CI in closed form from one set of draws is a different problem,
   and a much cheaper one (row D; `randomization_ci_affine_shift_reuse.md`;
   the closed-form BRT CI for affine statistics).
3. **Use the structure of real data.** Worst-case optimality isn't the same
   as being fast on actual inputs. Ties, small K, groups of size 2 and low rank
   all allow shortcuts that a general-purpose algorithm doesn't take
   (rows P, Q, R; TODO-13, -18, -20).
4. **Restructure the code in ways compilers can't.** Lay data out for the
   cache, avoid allocations inside hot loops, batch many tiny solves together,
   and fuse passes over the data. Compiler flags can't make these changes,
   because they change what the code means
   (`performance_profiling_and_upgrades.md`; TODO-29).
5. **Remove overhead between kernels.** R dispatch, R6 objects, copies across
   the R/C++ boundary, assertions and garbage collection add up. The
   2026-10-07 R benchmark found EDI slower than `boot` and `randomizr` for
   exactly this reason, not because of its algorithms. Optimizing a kernel
   only helps in proportion to its share of the total run time (Amdahl's law),
   so profile the whole run (TODO-19, -21; `release_v1_0_5.md → TODO-58`).
6. **Parallelize at the right level.** Load balancing (run the slowest tasks
   first, TODO-34), fork overhead, and BLAS threads oversubscribed under
   OpenMP.
7. **Reduce noise instead of adding compute.** Balanced bootstrap (row J,
   TODO-4), common random numbers and control variates give the same
   precision from fewer replicates.
8. **Amortize across runs.** Cache results across calls and sessions, and
   precompute tables.
9. **Make it feel faster.** Return early answers that sharpen over time
   (anytime results, confidence sequences;
   `randomization_ci_search_precision.md`'s deferred "real fix").

**When are you actually done?** For a single kernel: when a roofline check
shows it running at the hardware limit, either memory bandwidth or peak
floating-point throughput, for its arithmetic intensity. For the package:
when an end-to-end profile shows nearly all wall-clock time is spent inside
kernels that are at that limit. Until both hold, at least one of the levers
above still has room.

---

## Which algorithm choices should users get to make? (2026-10-09)

**Question (2026-10-09, owner):** "Do you think a future will be that we can
add all the algorithms and have the user choose which one to use? Because
there are tradeoffs."

**Answer: some of them, not all.** The tradeoffs in rows A–AC are of three
different kinds, and each kind gets a different treatment. Every option row in
this file and in `algorithm_choice_audit_catalog.md` should carry one of these
three labels:

| label | what the options differ in | treatment | examples |
|---|---|---|---|
| **auto** | speed only: same answer within tolerance (or within Monte Carlo error at the same `B`) | EDI picks; no user argument. If no option wins everywhere, EDI switches by size (n, K, ties). At most an `"auto"`-default override for debugging | Brent vs bisection (M), JT DP vs enumeration (R), presorting (Q), analytic vs FD derivatives (N) |
| **expose** | the answer itself: a different estimand, model, test or interval | a named, documented argument; the default matches standard software unless there is a stated reason not to | Breslow vs Efron ties (L), Clopper–Pearson vs minlike (F26), M vs MM robust (X) |
| **dial** | accuracy bought with time | one numeric control, not a menu of named algorithms (cf. lme4's `nAGQ`); default at the accurate end | GH nodes / Laplace (C), the KK21 `*_use_speedup` flags (T), `B` |

**Why not expose everything.** The 2026-10-09 sweep shows where bugs collect:
on the paths people rarely use. The legacy IVWC classes (F7, F11, F15, F22),
the R `coxph()` fallbacks that silently switched to Efron before TODO-69 (row L), and the
`sample(block_sizes, 1)` edge case (F1b) were all off the main path. Each
exposed option multiplies rows in the comprehensive_tests registry, needs its
own Type-I error and coverage evidence, and needs docs that tell users when
to pick it. An option tested less thoroughly than the default is a liability,
and most users never change the default anyway, so defaults matter more than
the menu.

### Conventions EDI already has (reuse them; don't invent per-class names)

Read from `R/EDI/R/` on 2026-10-09:

- **Which inference procedure** is already chosen by method name:
  `compute_score_*`, `compute_lik_ratio_*`, `compute_rand_*`,
  `compute_exact_*`, `compute_bayesian_bootstrap_*`, and so on. This is the main
  "expose" mechanism, and it already works.
- **Which variant of a procedure** goes in a `type =` argument on that method,
  `NULL` meaning "the class's default". Examples:
  `compute_bootstrap_confidence_interval(type = NULL)`,
  `compute_bayesian_bootstrap_confidence_interval(type = NULL)`,
  `compute_exact_confidence_interval(type = NULL, args_for_type = NULL)`, and
  the `"basic"` / `"centered"` types in `inference_all_abstract_non_param_boot.R`.
- **Which model or estimand** goes in a constructor argument:
  `reference = "control"` (`inference_ordinal_ridit.R:77`), `method = "MM"` (robust
  classes), `link`, `corstr`.
- **The "auto" pattern** already exists in one place:
  `DesignFixedOptimal$new(solver = "auto")` (`design_fixed_optimal.R:238`) picks
  MILP or annealing and lets the user override. This is the model for any
  "auto" row that needs an escape hatch.
- **Exposed implementation toggles:** `use_rcpp = TRUE` (constructor argument
  in 19 files) and `smart_cold_start_default`. These are developer and parity
  switches, not statistical choices. Row L showed the risk before TODO-69:
  the `use_rcpp = FALSE` path fit a different likelihood (Efron) from the C++
  path (Breslow). Both now fit Breslow. Any path reachable through such a
  toggle must fit the same model as the default.

**Rule:** if an option changes the model or estimand, it goes in the
constructor. If it changes only how the test or interval is built, it goes in
`type =` on the method. If it changes only speed, it gets no argument, or at
most `"auto"` plus an override.

### Gate before an option becomes public

1. It has its own rows in `comprehensive_suite_registry.csv`. Type-I error and
   coverage must meet the same standard as the default on the same datasets.
2. Its roxygen says what it changes, when to prefer it, and what it costs.
3. The fitted object records which algorithm actually ran, including the
   result of any `"auto"` choice and any fallback that fired. Otherwise results
   cannot be reproduced, and a silent fallback like row L's cannot be detected.
4. Tests and fixtures pin the option explicitly, so a change of default cannot
   silently change what a test checks (cf. the `ties` pinning in TODO-6(b)).

### Labelling pass over rows A–AC

"Exists" means the choice is already a user argument today.

| row | choice | label | note |
|---|---|---|---|
| A | Newton vs IRLS vs L-BFGS | **auto** | same MLE. `use_rcpp` stays a developer toggle (see above) |
| B | joint Newton vs EM-then-Newton | **auto** | same MLE when both converge; EM is a robustness start |
| C | 20-node GH vs adaptive GH vs Laplace | **dial** | one `n_gh` / `nAGQ`-style control (today `n_gh = 20L` is internal); Laplace only as the explicit low end, never the default |
| D | bisection vs Robbins–Monro CI search | **auto** | same target bound; `pval_epsilon` / `ci_search_control` on `compute_rand_confidence_interval` are already the precision dial |
| E | Monte Carlo vs saddlepoint p-value | **expose**, opt-in | changes exactness; as an early-stop screen it is **auto** (MC answer still reported) |
| F | MILP vs annealing (vs PT/tabu) | **auto** + override (exists: `solver`) | F23: BRT replicates must use the same solver as the observed allocation |
| G | blossom vs geometric matching | **auto** | same exact matching |
| H | brute-force vs tree nearest match | **auto** | same match |
| I | rejection vs top-quantile acceptance | **expose** (exists: `prop_acceptable`) | changes the design |
| J | i.i.d. vs balanced bootstrap | **auto** | same target, less MC noise; changes seed-pinned draws once |
| K | GEE working correlation | **expose** (exists: `corstr`) | AR(1)/unstructured would be a scope addition |
| L | Breslow vs Efron vs exact ties | **expose** (new `ties`, constructor) | the clearest case for this section. `survival::coxph` defaults to Efron; whether EDI's default follows is TODO-6(a) |
| M | bisection vs Brent (deterministic) | **auto** | identical within `tol` |
| N | FD vs analytic derivatives | **auto** | |
| O | clamped vs exact-tail special functions | **auto** | accuracy fix; no reason to keep the inaccurate one |
| P | generic optimizer vs closed form / separable fits | **auto** | exception: for Gaussian LR, exact F(1, n−p) vs asymptotic χ² changes the p-value. That is **expose**, as a `type` |
| Q | re-sort vs presort | **auto** | bit-identical |
| R | JT exact by enumeration vs DP | **auto** | exact vs MC JT is already a procedure choice (`compute_exact_*`) |
| S | Atkinson draws, C++ draw kernels, Fisher–Yates | **auto** | Fisher–Yates changes seed-pinned draws once |
| T | KK21 refit-every-candidate vs score-test stepwise; φ grid vs Brent | **dial** (exists: `count/ordinal/proportion_use_speedup`); φ search **auto** | the speedup flags can change which covariates get selected |
| U | small dense linear algebra | **auto** | |
| V | memoize / warm start / batch kernels | **auto** | early-stop and calibration changes must stay within MC error |
| W | `rq` `"br"` vs `"fn"`; `rq()` vs `rq.fit` | **auto** | but use one method for both the point fit and the replicates |
| X | bisquare-M vs true MM (S-start) | **expose** (exists: `method`) | today's `"MM"` is mislabeled (TODO-31); true MM becomes a new value of the same argument |
| Y | self-consistency EM vs EMICM | **auto** | same NPMLE |
| Z | start values, constrained solvers, NB parametrization | **auto** | same MLE where it exists |
| AA | multistart / damped scoring for nonconcave fits | **auto** | the target is the global MLE |
| AB | g-comp SE: conditional vs population target (F25, F16) | **expose** or document | an estimand choice; today it is implicit and inconsistent between KK and non-KK |
| AC | scheduling, tuning harness | **auto** | |

Statistical choices surfaced by the bug sweep (`release_v1_0_5.md →
TODO-70..94`) that also belong under **expose**:

- exact-binomial CI vs test construction (F26): Clopper–Pearson vs minlike, as
  `type` on `compute_exact_*`;
- the proportion-difference interval (Newcombe/Wilson, F9);
- the dependent-censoring CI rule (F21). It currently picks the interval *from
  the data*, which biases toward non-rejection. It should be a user-stated
  `type`, not a data-dependent switch.

**Net result.** Of rows A–AC, 21 are **auto**, 6 are **expose** (3 already
exist as arguments: I, K, X), and 2 are **dial** (T exists). The new user-facing surface this policy implies is small: `ties`
(L), a quadrature dial (C), an F-vs-χ² `type` (P), an explicit g-comp SE
target (AB), and the three `type`s from the bug sweep.

### TODOs

- [ ] TODO-37 (scheduled with the audit document itself, `../../future_release_plans/release_v1_1_0.md → TODO-17t`): Add an `exposure` column (auto / expose / dial) to the summary
  table and to each options table in `algorithm_choice_audit_catalog.md`,
  starting from the labelling pass above. TODO-7's re-audit keeps it current.
- [ ] TODO-38 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-48` (shares its reproducibility record)): **Algorithm provenance on fitted objects.** Record which
  algorithm, `"auto"` choice and fallback actually ran (gate item 3). It is a
  prerequisite for exposing anything new, and it would have caught row L's
  silent Efron fallback. Design it once in the inference base classes, not
  per class.
- [ ] TODO-39 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-61`; owner decision made 2026-10-19: **Efron default, `ties = "breslow"` exposed**): **`ties` for the Cox family** (row L). This resolves the owner decision
  in TODO-6(a). It depends on
  TODO-69 in `release_v1_0_5.md` (pin Breslow in the fallbacks first).
- [ ] TODO-40 (scheduled with adaptive GH, `../../future_release_plans/release_v1_2_0.md → TODO-11` (`performance_profiling_and_upgrades.md → TODO-153`)): **Quadrature dial** for GLMM/LMM/frailty (row C), shipped with
  adaptive GH (`performance_profiling_and_upgrades.md → TODO-153`). It should
  not ship before adaptive GH: a dial whose only cheap setting is plain
  low-node GH would invite inaccurate fits.
  **Laplace (2026-10-22, user question):** expose Laplace as the cheapest setting of this one dial (the `nAGQ = 1` analogue), not as a separate algorithm choice. The default stays at the accurate end (adaptive GH). It passes the public-option gate (registry rows, roxygen, provenance via TODO-38) before it ships, and the fitted object records which setting ran.
- [ ] TODO-41 (scheduled in `../../future_release_plans/release_v1_1_0.md → TODO-52`): Audit the exposed implementation toggles (`use_rcpp`,
  `smart_cold_start_default`): every reachable path must fit the same model as
  the default, enforced by a parity test per toggle. Document them as
  developer options.
- [ ] TODO-42 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-33`): **Amortize across runs** (lever 8 of "Beyond algorithm
  choice"). Survey which pure-function results are recomputed across calls
  and sessions, plan, then implement only approved caches.
- [ ] TODO-43 (scheduled in `../../future_release_plans/release_v1_2_0.md → TODO-34`): **Anytime results** (lever 9):
  `randomization_ci_search_precision.md → TODO-2..6`, anytime-valid
  confidence sequences in the randomization-CI search.

## Re-review log

Dated outcomes of drift-check re-reviews (runbook "Re-review procedure"). A corrected fact here
supersedes the older text in that row's section until the section is next rewritten. Inventory
details for every changed entry were updated in `../../audits/algorithm_inventory.csv` at the same time.

### 2026-11-16: drift issue #8 (commits since 2026-10-22) and research issue #9

Method: five read-only review agents, one per row group, each read every listed commit's diff of
the row's watched files, the row's section, and its inventory entries; no code was run. All 23
flagged rows **hold** (no verdict changed); `reviewed` dates bumped to 2026-11-16. Comparators re-pinned
after reading CRAN NEWS: lme4 2.1-0 (PIRLS weight refresh before Laplace/AGQ shifts glmer SEs
slightly; dispersion change only for estimated-dispersion families; EDI uses lme4 only as a test
oracle, so row C holds, but oracle-test tolerances may need attention), glmnet 5.2 (Efron-ties
Hessian and coefficient-limits fixes; EDI calls glmnet only as the `use_rcpp = FALSE` Cox fallback
with Breslow ties and no limits, so row L holds), nlme 3.1-172 (no CRAN NEWS; not called from
package code), ggplot2 and mirai (not algorithmic).

- **A** (holds with updates; a464f68e, 436ca96b, f2930d36, 96b34122): No kernel in row A changed its optimizer: the families are still damped Newton/IRLS or L-BFGS from one start. The commits add safeguards on top. Log-binomial/identity-binomial IRLS gained an active-set projection, a KKT convergence gate (TODO-128) and a reversal-damping cycle guard from iteration 20 (TODO-181b, identity-link zigzag). Probit fits saturated against their own outcome inside pnorm_fast's |eta|>=8 clamp are downgraded to unconverged (TODO-181a). Cox Newton now rejects a non-decreasing candidate after halving, its default maxit went from 20 to 100, and compute_cox_neg_ll_only now sums risk sets backwards (fixes I-6 cancellation there). The ordinal logit/probit/cloglog/cauchit/adjacent-category fits get a Newton-decrement certificate when covariates are badly scaled (TODO-107). The NB eps_g default is 1e-6 again, and the tighter tolerance is opt-in from R. The Clayton log-sum-exp gets a log1p/expm1 small-theta path, and the dep-cens atanh(rho) gradient is zeroed at the clamp. Every change is a convergence certificate or a damping/guard inside the same method, so 'Keep' stands. Several recorded facts are now stale; see the inventory updates below.
  - *Corrected facts:* Keep (unchanged). Add after the table: "2026-11 re-review: the algorithms are unchanged; the commits added convergence certificates and guards inside the same methods: log/identity-binomial active-set projection + KKT gate + reversal damping (TODO-128, TODO-181b), probit clamp-saturation non-convergence (TODO-181a), Cox Newton descent guard and maxit 100, backward risk-set sum in compute_cox_neg_ll_only, and a Newton-decrement certificate for badly scaled ordinal fits (ordinal_scale_guard.h, TODO-107)."
- **B** (holds with updates; 96b34122, f15b4423): The only B-kernel change is in fast_zinb.cpp (96b34122, f15b4423): when the free information block is exactly singular (an unidentified zero-inflation block), both fast_zinb_with_var_internal and fast_zinb_cpp now keep information_invertible = FALSE but return an eigendecomposition pseudo-inverse covariance, with NaN rows/columns for coordinates that load on the null space, and they label it with covariance_type. This changes only how the variance is reported after the fit. The joint L-BFGS fit and its multistart are unchanged, so the EM-hybrid Prototype verdict and the recorded facts still hold. The pseudo-inverse is correct: a coordinate orthogonal to the null space is estimable, so its variance is the same under any generalized inverse. Minor: the new helper duplicates most of symmetric_pseudo_inverse in _helper_functions_core.h (dedupe is incidental).
- **C** (holds with updates; f15b4423, 96b34122): f15b4423 raised the Poisson GLMM default from n_gh = 20 to 60 (fast_poisson_glmm.cpp, 4 defaults, plus the explicit 60L in inference_count_KK_combined.R:445), following the R8 accuracy grid on 2026-10-24: 20 non-adaptive nodes failed at n = 120 with clusters of 5 and sigma 0.9 (|dlog sigma| 0.17), 30 nodes also failed (the error is not monotone in the node count), and 60 passed at 2.3-2.8x the 20-node cost. 96b34122 only corrected the sign comment on get_poisson_glmm_hessian_cpp; the returned value is unchanged. The verdict holds: keep GH and do not use Laplace, with adaptive GH (TODO-153) as the gap. This is now stronger evidence for AGQ, because non-adaptive GH needed 60 nodes for Poisson. The section's 'fixed n_gh = 20' fact and the TODO-153 1.5-2.5x win estimate are now stale for the Poisson kernel.
  - *Corrected facts:* Add to section C after the first paragraph: "Update 2026-11-16: the Poisson GLMM kernel (`fast_poisson_glmm.cpp`) now defaults to n_gh = 60 (owner, 2026-10-24). On the R8 accuracy grid, 20 non-adaptive nodes failed for clusters of 5 at n = 120, sigma 0.9 (|dlog sigma| 0.17), 30 also failed (the GH error is not monotone in the node count), and 60 passed at 2.3-2.8x the 20-node cost (release_v1_0_5.md). The other `_glmm_engine.h` kernels stay at 20 and the hurdle-Poisson kernel at 7. This strengthens the case for adaptive GH (TODO-153): for Poisson the comparison is now 60 fixed nodes against 5-9 adaptive ones, so the expected per-call win there is larger than the 1.5-2.5x quoted. The verdict is unchanged."
- **D** (holds with updates; c28bbb34, a62da6e4, fe267250, f2930d36, 618bcbc1, 455a48e3): None of the six commits touch the search driver. c28bbb34 makes the closed-form breakpoint inversion (closed_form_ci_from_affine_null_draws) count ties with the same rand_tail_counts() tolerance rule the bisection path uses. f2930d36 refuses randomization-bootstrap CIs for InferenceSurvivalRestrictedMeanDiff (scale mismatch). 618bcbc1 and fe267250 are a capability-helper refactor and doc paths, a62da6e4 is an example, and 455a48e3 is TODO-116 failure bookkeeping in the deterministic inverters (row M). The CI search is still bracket + bisection on a Monte Carlo p(delta), so 'Prototype Garthwaite-Buckland' still holds. Separately, the inventory still says the randomization-bootstrap bisection uses threshold alpha/2. That has been wrong since 55f7a838 (2026-10-09): every call site passes alpha.
- **E** (holds with updates; c28bbb34, e4dca08e): e4dca08e and c28bbb34 change tie handling only. Draws within EDI_TIE_REL_TOL (sqrt(eps)) × max(|t|, max|t0s|) of the observed statistic now count in both tails. The rule is shared by the stored-distribution p-value, the affine-reuse branch and the sequential-MC band. c28bbb34 also stops chaining warm starts across replicates for nonconcave likelihoods (row J). The p-value is still direct Monte Carlo, so the saddlepoint-Prototype verdict and its reasoning hold. One more thing now matters for the future saddlepoint validation: on discrete statistics the both-tails tie rule is part of the reference p-value, so a continuous saddlepoint approximation needs a matching tie/continuity convention. Issue #9 overstates one point: the plain p-value does call compute_two_sided_pval_with_sequential_mc, but randomization_mc_control is NULL outside a CI search, so the call returns NULL and the standalone p-value still uses a fixed r. 'No early stopping for the plain p-value' is still true. Issue #9's suggested (b+1)/(r+1) formula is also wrong: the code computes 2·min(ge, le)/n, floored at 2/n.
  - *Corrected facts:* Replace the formula sentence with: 'Randomization/permutation p-values are computed by direct Monte Carlo: B replicates, two-sided p̂ = 2·min(#{T(w) ≥ T_obs}, #{T(w) ≤ T_obs})/B, floored at 2/B and capped at 1, where draws within EDI_TIE_REL_TOL·max(|T_obs|, max|T(w)|) of T_obs count as ties in both tails (rand_tail_counts(); cross_platform_reproducibility.md TODO-3). Standalone p-values use a fixed B; Clopper–Pearson sequential stopping is active only inside CI searches.' Add to the validation paragraph: 'For discrete statistics (ridit, Wilcoxon with ties, small-n exact enumerations) the reference p-value includes the both-tails tie rule, so the saddlepoint comparison must use a matching continuity/tie convention.'
  - *Unverified suspicion, scheduled as TODO-32-v1.0.6* (`R/EDI/R/inference_all_abstract_rand.R:35`): Edge-case robustness, not shown to happen: the tie tolerance scales with max|t0s|, so a single finite but blown-up replicate (e.g. a near-separated or near-zero-denominator refit returning about 1e7 when typical |t| is about 1) widens the tie window for every draw (tol about 0.15 at 1e7). Draws near t then count in both tails and push p toward 1 (conservative). Something like a high quantile of |t0s| instead of the max would keep the unit-invariance without a single draw setting the scale.
- **F** (holds; 618bcbc1): The only watched-file change (618bcbc1) is in design_fixed_optimal_blocks.R, whose kernels the inventory files under row R, not F: get_or_compute_block_ids now keys the cached blocking on the covariate rows and re-solves it (same method/B/dist/roi_solver) on each bootstrap-randomization replay draw; solve_greedy_blocks numbers complete blockTools rows consecutively and its leftover fallback handles empty blocks. Nothing in the DesignFixedOptimal MILP/annealing kernels (design_optimal_annealing_search.cpp, optimal_design_search.cpp, design_fixed_optimal.R) changed, so the plain-SA-vs-parallel-tempering/tabu comparison is still the open follow-up under quantum_upgrade.md TODO-5.
- **H** (holds; 41696739): 41696739 only removes the prob_T argument from DesignSeqOneByOneAtkinson and DesignSeqOneByOnePocockSimon (now hard-wired to 0.5) and edits the roxygen. The Atkinson D_A biased coin, the Pocock-Simon incremental counts and the KK nearest-match search are untouched, so the moving-metric nearest-neighbour verdict and the recorded costs still hold.
- **I** (holds with updates; 41696739, 618bcbc1): 618bcbc1 added the batch wrapper and S_inv cache refresh (plumbing). 41696739 (TODO-164) makes the base law fixed-n_T complete randomization (n_T = round(n*prob_T)) on every path: the Bernoulli/rbinom candidate branches are gone from the batched R sampler and generate_one_rerandomized_w, and a draw now errors if n_T leaves an empty arm. Plain rejection sampling plus prop_acceptable best-fraction selection is still the algorithm, so the verdict holds. The inventory text for generate_one_rerandomized_w that mentions rbinom is now out of date.
- **J** (holds; 618bcbc1, 455a48e3): 455a48e3 adds the active resampling operation to the reusable-worker cache key (fixes call-history dependence of warm/cold starts). 618bcbc1 makes ci_calibrated_bootstrap (a row V entry) honour set_seed() and only changes roxygen otherwise (BCa small-B guard, NA semantics). Bootstrap index generation is still plain i.i.d. multinomial resampling and no balanced-bootstrap change has landed, so the Prototype verdict (balanced resampling in bootstrap_indices.cpp) and the recorded facts still hold.
- **K** (holds; 618bcbc1, 168c2e92): fast_gee.cpp was not touched. 618bcbc1 removed the `start =` warm start from both geepack::geeglm fallback calls (fit_gee_on_data and fit_weighted_gee_on_data). geeglm forwards `start` to model.frame, so every warm-started geepack refit was failing with 'variable lengths differ' and silently returning NULL in jackknife, bootstrap and randomization. That is a bug fix that restores the fallback; the fallback now always starts cold. 168c2e92 only added an Rd @eval line. The Liang-Zeger moment estimator with exchangeable/independence structures is unchanged, so 'Keep (scope gap)' holds. The gee_family entry added on 2026-11-16 is accurate and gets verdict Keep under K.
- **L** (holds with updates; fe267250, 168c2e92, 96b34122): 96b34122 rewrote compute_cox_neg_ll_only (the line-search objective) to build S0 backwards, matching compute_cox_ll_grad_hess_fast. The old forward running difference cancelled to noise and once accepted a diverging bT = 166 step. It also rejects a line-search candidate that does not decrease the objective (converged stays FALSE) and raises maxit from 20 to 100. Ties are still Breslow: each tied set uses d_k*log S0, and the objective, gradient and Hessian now share one accumulation order. fe267250 fixes a doc path and 168c2e92 adds Rd small-sample sections, so the Keep (Breslow) verdict holds. Only line references and the description of the objective's sweep are stale.
  - *Corrected facts:* Line refs: `compute_cox_neg_ll_only` is now `:105-140` and, since 96b34122 (2026-10-23), accumulates S0 in reverse like the gradient/Hessian path (fixes the line-search half of catalog note I-6); `compute_cox_ll_grad_hess_fast` is `:151-262`; `compute_robust_vcov` is `:544-~650` and still uses the forward running difference (the other half of I-6, open); the R fallback `survival::coxph(..., ties = "breslow")` is at `inference_survival_coxph.R:650` (was :641). Newton now rejects a non-decreasing candidate after step-halving and maxit defaults to 100 (was 20). Breslow verdict unchanged.
  - *Unverified suspicion, scheduled as TODO-31-v1.0.6* (`R/EDI/src/fast_coxph_regression.cpp:580`): compute_robust_vcov still gets risk-set sums by forward subtraction (r_exp and r_x_exp start at the grand total, minus each subject who leaves). 96b34122 removed this exact pattern from compute_cox_neg_ll_only because, when one subject dominates exp(eta - max), the remainder after that subject leaves is rounding noise: safe_r clamps to 1e-100 and the objective was badly wrong (-509 vs +363.7). On such data, the dk/R_k and e_k terms of the Lin-Wei score residuals here would be similarly wrong, giving a wrong cluster-robust Cox SE. This is only reached when cluster != NULL. Fix: reverse accumulation, as in compute_cox_ll_grad_hess_fast. Already noted as catalog I-6 (precision), but now shown to cause gross errors in the sibling function.
- **M** (holds with updates; 67347569, b1e96231, 83f1f3cf, 455a48e3): 83f1f3cf/b1e96231 (TODO-172) change only the non-converged exit of the LR Newton inverter lrt_ci_nr_cpp. It used to return the bracket midpoint (a+b)/2. Now it returns the iterate closest to alpha if |p − α| ≤ 1e-4, the midpoint only if the bracket collapsed, and otherwise NA. 67347569 (TODO-174) adds a jump guard to pval_invert_ci_cpp: if bisection never moves the outer end b0 and p jumps by more than 1e-3 there, b0 is an isolated low-p null refit, and the outward search restarts up to 3 times before reporting NA. 455a48e3 is failure bookkeeping only (TODO-116). Score/gradient/Bartlett are still pure bisection and LR is still safeguarded Newton, so 'Adopt Brent' still holds. The Brent port (brent_ci_inversion.md) must keep the TODO-174 guard: Brent converges onto a discontinuity just as bisection does, and the guard's test 'b never moved' is bisection-specific, so it has to become 'final bracket straddles a p-jump > 1e-3'. Separately, two inventory rows wrongly attribute log-binomial's uniroot-based gradient CI to inference_ext_ci_inversion.R.
  - *Corrected facts:* Append to row M: 'Since 2026-11-03/08: lrt_ci_nr_cpp returns the closest-to-α iterate (|p−α| ≤ 1e-4) or NA when Newton hits max_nr_iter without converging (TODO-172), no longer the bracket midpoint; pval_invert_ci_cpp has a jump guard (TODO-174) that restarts the outward search, up to 3 times, when bisection collapses onto an isolated low-p point (a null refit on a worse local optimum). A Brent replacement must keep that guard, restated bracket-generically (|p(a) − p(b)| > 1e-3 across the final bracket ⇒ restart past b), because Brent, like bisection, converges onto such a discontinuity.'
- **N** (holds with updates; a464f68e, f15b4423, 96b34122): The FD paths named in row N are unchanged. Log-binomial/identity-binomial score and Hessian still use central differences (now at fast_log_binomial_regression.cpp:840-920), and the ZINB Hessian is still numerical_hessian. f15b4423/96b34122 only add an identified-coordinate pseudo-inverse on top of the ZINB FD Hessian when the information is singular, and the log-binomial commits touch the IRLS fit, not the derivative helpers. So 'Adopt analytic (TODO-14)' still holds. One new fact makes TODO-14 cheaper: closed-form score and observed information for log-binomial and identity-binomial now exist in R (edi_log_binomial_kkt_terms / edi_binomial_identity_kkt_terms), but they are used only when a row is within 1e-4 of the bound. Interior fits still call the C++ FD helpers.
  - *Corrected facts:* Adopt (TODO-14), unchanged. Fix the stale line cite in TODO-14: `fast_log_binomial_regression.cpp:580-662` → `:840-920`. Add: "Closed-form score/observed information for both links already exist in R (inference_incidence_log_binomial.R edi_log_binomial_kkt_terms, inference_incidence_binomial_identity.R edi_binomial_identity_kkt_terms) but run only near a bound; porting them to the C++ helpers is the log-binomial part of TODO-14."
- **P** (holds with updates; 96b34122): Of P's watched kernels, only fast_continuation_ratio_regression.cpp changed (96b34122). It added a post-fit guard: when the subject-level covariates look badly scaled and the Newton decrement at the returned params is too large, the fit is downgraded to converged = FALSE. The dense expanded matrix, the L-BFGS fit and the parameters are unchanged, so the row's Adopt verdict (TODO-13/-16/-17) and its facts still hold. The guard functions belong to row AA. The two issue-9 stale entries owned by P are fixes and do not overturn their Keep verdicts. The ridit SE is now the DeLong structural-components variance, which I checked: V10/V01 are the cross-arm CDF midranks; the control and treatment references give the same theta-1/2; pooled scales by n_C/N. This is the standard Mann-Whitney variance and replaces an SE that treated the reference as known. The KM-median CI is now MOVER over the per-arm Brookmeyer-Crowley intervals, a standard choice. The C++ median convention matches quantile.survfit, so d = m_T - m_C, which is the center MOVER assumes. Both entries keep Keep; only their details are updated.
- **Q** (holds; 96b34122): Only 96b34122 touches the watched files. In fast_logrank.cpp, fast_survival_stats.cpp and fast_wilcox_hl.cpp it treats an empty noise_mat as absent, which is an OOB guard. In the KM/RMST rand-bootstrap kernel it adds an optional user RMST horizon (rmst_tau caps shared_tau; km_stat_inline already honoured it). In fast_ridit_analysis.cpp it replaces the ridit SE with the DeLong SE. No sort/sweep logic changed. The KM/RMST and log-rank BRT kernels still re-sort every draw (km_stat_inline std::sort; log-rank full re-sort), so the Adopt verdict (TODO-11/-18 presort) is still right. The JT, Gehan, record_less and strata-id kernels are untouched. The ridit DeLong change is in a Q-watched file, but its inventory entry (fast_ridit_analysis_result) and the km_diff MOVER entry both have audit_row P, so the P reviewer owns them. I spot-checked the DeLong port: the pooled-reference scaling n_C/N and the treatment-reference sign are algebraically correct for theta - 1/2.
- **S** (holds with updates; 41696739): 41696739 adds an n_T argument to greedy_design_search_cpp (default n/2) for unequal arms: separate treated/control buffers sized nt/nc, random-swap control index drawn from nc, and pair mode requires n_T = #pairs. I checked the comment's claim that the swap delta needs no change: X is centred (lines 111-112), so M*(2w-1) = 2*M*w, which is a fixed positive multiple of the n_T-weighted mean difference for fixed n_T, and the abs-sum and Mahalanobis objectives rank allocations the same way. The sampling/RNG findings for row S (Atkinson draws, randomizr replicate, std::shuffle) are unaffected. The inventory entries for greedy_design_search_cpp (audit_row F) still say 'Random balanced start'.
- **V** (holds; 96b34122): The only change to the row's watched kernels in 96b34122 is a memory-safety fix in rand_bootstrap_mean_diff_parallel.cpp and rand_bootstrap_ols_parallel.cpp. An empty (0×0) noise matrix passes Nullable::isNotNull(), so has_noise is now noise_m.size() > 0, which prevents an out-of-bounds read. The replicate loops, refit counts and the memoize/warm-start/batch-kernel TODOs are unchanged, so the row's findings and verdicts stand.
- **W** (holds with updates; 618bcbc1): 618bcbc1 (TODO-129) seeds the global RNG once per compute_rand_confidence_interval() call in the quantile Zhang CI (seed_global_rng_for_draws(); the caller's stream is restored on exit). The sign-flip and permutation draws are now reproducible under the inference or design seed. Nothing about rq 'br' vs 'fn', rq() vs rq.fit, or the HL bisection changed, so the verdict holds. The one-time seeding does not give common random numbers across δ: each p(δ) evaluation still consumes fresh draws from one continuing stream, so the 'no CRN across δ' fact (and the bisection on a noisy p) still stands. Re-seeding per δ evaluation would be a cheap way to make p(δ) deterministic, which is relevant to TODO-6.
- **X** (holds; 96b34122): 96b34122 changed only input handling in fast_robust_regression.cpp. fast_robust_regression_internal now throws on non-finite X or y instead of returning a 0 coefficient (TODO-131). compute_robust_rand_bootstrap_parallel_cpp skips non-finite draws (left as NA) before calling it, so no exception escapes the OpenMP region. It also treats a 0-length noise matrix as absent, which fixes an out-of-bounds read. The other callers (the Rcpp export and the Python binding) are outside parallel regions, where the exception becomes an R or Python error. The IRLS algorithm, the 'MM' mislabel (bisquare-M from an OLS start with a fixed MAD scale) and the cold-start bootstrap are unchanged, so the Prototype + rename verdict (TODO-31) and the inventory descriptions remain accurate.
- **Z** (holds with updates; fe267250, a464f68e, f15b4423, 96b34122): Starts are unchanged. The log-binomial cold start is still OLS of log1p(y), which gives η > 0 (infeasible) for 0/1 y. The R layer now only drops infeasible warm starts (logbin_feasible_warm_start_args) and falls back to that cold start. Cox and adjacent-category smart starts still regress without an intercept, and the ZINB start (π = 0.5, θ = 1) is unchanged. Only the 'no constrained solver' fact moved: log/identity-binomial IRLS now projects the increment off rows already within 1e-6 of a bound (an active-set step in the Fisher metric), certifies boundary MLEs with a KKT gate (multipliers ≥ 0, small projected step), and damps reversals (cycle guard). It still reaches the bound by step-halving against the −∞ barrier from a possibly infeasible start, so a proper constrained solver stays a Prototype. Start fixes stay Adopt (TODO-24); solvers stay Prototype (TODO-32). Cox commits (descent guard, maxit 100, backward neg-ll) do not touch the start.
  - *Corrected facts:* Change the row-Z facts cell to: "log-binomial infeasible cold start (OLS of log1p(y) ⇒ η > 0); IRLS now has an active-set projection and a KKT gate at bounds (TODO-128) but no true constrained solver; Cox and adjacent-category cold starts regress without an intercept; ZINB start π = 0.5, θ = 1 (a consistent truncated-count start exists); NB α = 1/θ bound-constrained parametrization could retire most boundary-rescue code". Verdict unchanged: start fixes **Adopt**; solvers **Prototype** (TODO-24, -32).
- **AA** (holds with updates; 96b34122): 96b34122 changed only convergence reporting in the AA kernels. Cauchit, cloglog, probit and adjacent-category now downgrade a converged fit to FALSE when covariates are badly scaled and the Newton decrement exceeds max(1e-6, tol). Where the Hessian is not PD (the nonconcave cauchit case) the check passes, so the optimizer's verdict stands there. No solver or start changed, so 'Prototype (TODO-33)' holds. One recorded fact is stale (from issue9 and the stereotype R file, not a watched file): 'replicates get no multistart while the observed statistic does'. Since TODO-175/176/178, every stereotype fit goes through generate_mod with the cold primary fit plus .stereotype_full_data_multistart, including estimate_only randomization and bootstrap draws and parametric-bootstrap replicate full fits. Null refits use .stereotype_null_refit_multistart, with an adjacent-category two-stage start. compute_stereotype_logit_distr_parallel_cpp (row V, cold L-BFGS, no multistart) is no longer called from R. Treatment-only stereotype fits with K ≥ 3 are now non-estimable by owner ruling, which settles part of TODO-33's 'p = 1' item.
  - *Corrected facts:* Change the row-AA facts cell to: "stereotype (Newton discarded at β = 0 since the γ Hessian block is singular; observed fit, resampling draws and null refits now all get the deterministic multistart (TODO-175/178), and treatment-only fits with K ≥ 3 are refused as non-identified); cauchit; dependent-censoring copula". Verdict unchanged: **Prototype** (TODO-33).
- **AB** (holds; e4dca08e, 67347569, 618bcbc1, 455a48e3): None of the four commits touch a variance estimator. They only add unrelated helpers that happen to live in helper_robust_sandwich.R. 455a48e3 adds likelihood-test failure-reason routing (edi_lik_test_procedure). 618bcbc1 and e4dca08e add the binomial-MLE boundary count and warning (TODO-128/179). 67347569 adds the warm-start null-refit retry (TODO-177). The HC0 helpers, CR2 and gcomp_speedups.cpp are unchanged, so the Investigate verdict and its facts are unaffected. Both open items are already settled elsewhere: sqrt(w) was refuted (F24), and the g-comp SE estimand was documented under v1.0.5 TODO-88 [x]. The row could be marked resolved, but that is the owner's call.
- **AC** (holds; 168c2e92, 41696739): 168c2e92 adds a load-time consistency check between the method sentinels and the procedure-regime/convergence registry, plus four validity columns (regime, n_eff, size_order, rate_basis) in the run_all_inference results table. 41696739 adds a requires_even_allocation compatibility filter (prob_T == 0.5). Neither commit touches run_all_inference_fork_dispatch, which still does FIFO greedy list scheduling via mcparallel/mccollect polling, so the LPT Adopt verdict stands and has not been implemented.


### 2026-11-17: verdict re-review of inventory rows flagged by inventory runs 43957548346 / 43964304738

Method: three read-only review agents read the code and the plan files each verdict cites; nothing
was run. 16 flagged rows: 11 verdicts hold, 5 change (applied to `algorithm_inventory.csv`, with
2 sibling rows the review found stale in the same way).

- **Changed:** stereotype `fit_null` → Keep-tracked (`multistart_nonconcave_likelihoods.md`
  TODO-5, release_v1_2_0.md → TODO-20; null refits already use the TODO-175/178 deterministic
  multistart; the copied "Cloglog: Investigate" clause removed). `multivariate_ordinal_tstat` →
  Prototype (TODO 3): the unprotected-`wrap` crash is gone (it now calls the C++ ordinal kernel
  directly; v1.0.5 TODO-65 closed). KK cond-logit GLMM `compute_estimate_with_bootstrap_weights`
  → Keep: glmmTMB is gone and the replicate refits the point estimator's own weighted likelihood
  (F14 resolved; method relabelled IRLS). `dep_cens_percentile_bootstrap_ci` and sibling
  `dep_cens_validate_bootstrap_ci` → Keep (audit J): the Wald-swap / |bound|>2 selection rule was
  removed (F21, algorithm_sweep_verified_findings.md TODO-6). `gee_estimate_exchangeable_alpha`
  → Keep (audit K): the φ̂ scaling and −p df are in (F20, same plan TODO-18). Sibling
  `ci_exact_binomial`: the "different two-sided conventions" clause is false since F26 (release
  v1.0.5 TODO-89); now plain Keep.
- **Hold, relabelled:** logistic / Poisson GLMM and ordinal CLMM kernels are now multistart
  L-BFGS (verdicts unchanged: catalog §4 TODO-6 is the Newton-vs-L-BFGS default, TODO-153 AGQ
  and TODO-4 probit still open).
- **Hold:** ZOIB wrapper, KK cond-logit GLMM `shared`, binary-match structure (default cost
  change is the owner's G6 #42 decision), exact binomial p-value, exact JT, serial survival
  rand-bootstrap kernel, both ridit kernels.
- *Unverified suspicion*: `helper_zoib.R:135,143` reads `fit$coefficients`, which
  `fast_zero_one_inflated_beta_cpp` never returns (it returns `params`), so the wrapper would
  return NULL on real data; it has no callers and the bulk tests mock the kernel.
- *Unverified suspicion*: exact JT (`fast_jonckheere_terpstra.cpp:123-157`, guard at :211): the
  1e6 guard counts feasible leaves, but the DFS prunes only at the last level and checks for
  interrupts only at leaves, so a small control arm with many levels (e.g. ten levels of 20, a
  top level of 1, n_C = 1: 11 leaves, ~1.7e13 calls) could hang uninterruptibly.
- *Owner follow-ups found on the way*: `ridit_kernel_level_slots.md` TODO-2 (~lines 66-69) still
  prescribes the "mean of neighbours" fill for absent levels, which would reintroduce F8 (the
  code now uses the cumulative-mass rule); v1.0.5 TODO-175/178 are implemented in the code but
  not ticked; `compute_survival_stat_diff_rand_bootstrap_serial_cpp` has no production caller
  (tests only) and could be retired rather than presorted.

### 2026-11-20: drift issue #55 (commits since 2026-11-16, or 2026-10-22 for O, T, U, Y)

Method: six read-only review agents, one per row group. Each read the row's section, its latest
log entry and the diff of its watched files (from the last commit before the row's `reviewed`
date to HEAD `521ad30f`); nothing was run. O, Q and T changed only roxygen, and were checked
directly. All 26 flagged rows **hold** (no verdict changed); `reviewed` dates bumped to 2026-11-20.
Comparators: clubSandwich 0.7.0 pinned (new mmrm / `estimatr::iv_robust` support and an internal
`get_data()` fix; EDI compares only `lm` fits with explicit `cluster =` against
`coef_test(vcov = "CR2", test = "Satterthwaite")` / `vcovCR(type = "CR2")`, so row AB holds). No
other pinned comparator changed on CRAN. The pre-review note that F, H, M, U and W were doc-only was
wrong: each had 2-17 changed code lines; only O, Q and T had none.

- **A** (holds with updates; 5bdb9dfb, 72ea20ba, abd7e49d, 3dabce47, bf7a6ae9, c397cbc5): No family changed method; the commits add globalization and certificates inside the same Newton/IRLS or L-BFGS fits. Logistic IRLS reruns a failed plain pass with step-halving (up to 30 halvings) and accepts a Newton-decrement convergence rule (v1.0.6-TODO-192, -170). Log/identity-binomial IRLS checks an observed-information Newton step before declaring convergence and switches to observed-information Newton when it fails (v1.0.6-TODO-221), pulls infeasible starts into the support (v1.0.6-TODO-142) and restarts cold when a warm first step is rejected (v1.0.6-TODO-209). Weibull AFT fits badly scaled X on internally standardized columns with an exact back-map and up to 5 Newton polish steps (v1.0.6-TODO-163). Keep holds.
  - *Corrected facts:* "Logistic IRLS, probit IRLS and the cpoisson-combined Newton have no step-halving" → logistic IRLS has a step-halving fallback pass since 2026-11-19 (v1.0.6-TODO-192); probit IRLS and the cpoisson-combined Newton still have none.
  - *Suspected:* `fast_logistic_regression.cpp` run_irls (~L240-330): in the safeguarded pass the descent check runs at the top of the next iteration, so a step taken at iter = maxit - 1 is never checked and a capped (non-converged) fit can return a worse iterate than its best. Non-converging fits (separation) now run IRLS twice. No TODO covers it. The Weibull polish sets converged on the standardized-scale gradient but reports the original-scale gradient norm (covered by v1.0.6-TODO-169).
- **B** (holds; 97e466f1, 5bdb9dfb, 3dabce47): Hurdle-Poisson GLMM's private GH rule and soft log-sigma barrier replaced by the identical shared `glmm::` versions in `_glmm_engine.h` (v1.0.6-TODO-193); entry checks added to the hurdle-NB, hurdle-Poisson-GLMM and ZAP exports (v1.0.6-TODO-195); one dead helper removed. Joint fits, EM-hybrid multistart and barrier constants unchanged; Prototype holds.
- **C** (holds; 97e466f1, 3dabce47, e7c255b4): Poisson GLMM now calls the shared GH rule and barrier (same Golub-Welsch code, same constants), LMM input handling folded into `build_lmm_data`, a dead counter removed, and the ∂/∂log σ_e comment corrected (the code already had the term). Defaults unchanged (Poisson n_gh = 60, hurdle-Poisson 7, rest 20). Keep GH, adaptive GH (TODO-153) is the gap.
- **D** (holds with updates; abd7e49d, fe905ca8, 3395b6c3, 3dabce47, 5bdb9dfb, 72ea20ba, 4fc58cd0): Still bracket + bisection on a Monte Carlo p(δ). Changes are scope and failure reporting.
  - *Corrected facts:* The randomization CI now also runs under left-/interval-censoring (the null shift moves y_L/y_R with y; v1.0.6-TODO-143 follow-up); incidence δ ≠ 0 is refused for custom statistics too (v1.0.6-TODO-81, -110); marginal estimands are refused (v1.0.6-TODO-184). Inside the search, sequential-MC early stopping waits for max(mc_min_draws, 10, 10% of drawn) finite draws (v1.0.6-TODO-166), and the BRT search passes `min_fraction_usable_samples = 0`, so the new 95% gate (v1.0.6-TODO-12) does not move search intervals.
- **E** (holds with updates; abd7e49d, 3395b6c3, 3dabce47, 5bdb9dfb): Still direct Monte Carlo with the shared both-tails tie rule; the saddlepoint Prototype holds.
  - *Corrected facts:* p̂ = 2·min(#{T ≥ T_obs}, #{T ≤ T_obs}) / B_f over the B_f finite draws, floored at 2/B_f, capped at 1, and NA with a warning when B_f < max(10, ⌊B/10⌋). Since 3395b6c3 (v1.0.6-TODO-61) no permutation fit chains warm starts, for any likelihood; the 2026-11-16 entry's "for nonconcave likelihoods" is superseded. A saddlepoint validation must use the same finite-draw denominator. The tie tolerance scaling with max|t0s| stays under v1.0.6-TODO-32.
- **F** (holds; fe905ca8, 4fc58cd0): Only optimal-blocks files (inventory row R) changed: formula-named constant columns kept as placeholders (v1.0.6-TODO-107) and an rchk PROTECT fix. The `DesignFixedOptimal` MILP / annealing kernels are untouched.
- **H** (holds; fe905ca8, abd7e49d, 3395b6c3): Pocock-Simon rejects NA p_best/weights (v1.0.6-TODO-100) and its `draw_ws_raw` replays only enrolled subjects (v1.0.6-TODO-183); Atkinson rebuilds a stale model matrix in reusable bootstrap workers (v1.0.6-TODO-129). Biased coins, incremental counts and the KK nearest-match search unchanged.
  - *Corrected facts (docs):* the Atkinson coin probability lies in [0, 1) (0 only when M11/A = -1); `generate_permutations_pocock_simon_cpp` continues R's uniform stream and does not reproduce a per-subject `pocock_simon_assign_cpp` loop for the same seed.
- **I** (holds with updates; 7bf41069, 72ea20ba, e00ab78f): Still acceptance-rejection plus best-fraction `order()`. `abs_sum_diff` is SD-standardized on every path (v1.0.6-TODO-70); odd n at prob_T = 0.5 on the prop_acceptable path draws n_T = round(n·prob_T) (v1.0.6-TODO-234); one acceptance rule is mandatory.
  - *Corrected facts:* inventory text for `generate_rerandomized_w_batch` / `generate_one_rerandomized_w` should say abs_sum_diff is SD-standardized on every path (the balanced fast path's `mahal_dist` falls back to it when the Cholesky fails).
  - *Suspected, pre-existing, probably unreachable:* `compute_objective_vals_cpp` (`rerandomization_helpers.cpp:110-114, :153`) divides by `sd_all[j]` without the zero-variance guard the search kernel has (:209). Natural home: v1.4.0-TODO-11h.
- **J** (holds; abd7e49d, 5bdb9dfb, 3dabce47, 72ea20ba, dd255899): Indices are still plain i.i.d. multinomial / Dirichlet draws; no balanced bootstrap landed. New gates around the draws: 95% finite-replicate gate for na.rm p-values (v1.0.6-TODO-12); BCa needs ≥ 5 jackknife units, with a stratified jackknife on SPBR, RandomBlockSize and FixedBlocking (v1.0.6-TODO-231); the extreme-CI guard works on the log scale for ratios; the Bayesian bootstrap is refused under general censoring (v1.0.6-TODO-91); the parametric-bootstrap LR CI needs B ≥ 2/α - 1. A future balanced-resampling plan must balance within strata on those designs.
- **K** (holds with updates; fe905ca8, abd7e49d): `fast_gee.cpp` untouched. Logit-link KK GEE now reports SE / p / CI as NA when any |η̂| ≥ qlogis(1 - 1e-8) (separation, v1.0.6-TODO-118), keeping the estimate; a jackknife separation hook added (v1.0.6-TODO-122).
  - *Corrected facts:* add that rule to the `fit_gee_on_data` / `InferenceIncidKKGEE` / `InferencePropKKGEE` inventory entries.
  - *Suspected:* the rule (`inference_mixin_kk_gee_shared.R:493`) fires on one extreme fitted probability, so a non-separated fit with a high-leverage point can lose its SE. Same heuristic as plain logistic (v1.0.6-TODO-109); no TODO covers GEE.
- **L** (holds with updates; 5bdb9dfb, abd7e49d, fe905ca8): Ties are still Breslow in every point-estimate path; no watched C++ changed. KK StratCox IVWC `estimate_only` now always pools by inverse variance (v1.0.6-TODO-132), gained a treatment-only reservoir fallback (v1.0.6-TODO-133) and within-strata aliased-column dropping (v1.0.6-TODO-128); every IVWC replicate now pays for a full vcov fit (row V cost).
  - *Corrected facts:* the R paths that fit Cox models include `kk_ivwc_weighted_cox_half` (`globals.R:316`), which feeds Efron fits into the KK StratCox and KK LWA Cox IVWC Bayesian bootstraps.
  - *Verified by reading:* `globals.R:313-315` says the weighted fit uses "the same Efron-ties likelihood as the unweighted C++ fitter"; the C++ fitter is Breslow, so on tied data those Bayesian-bootstrap replicates fit a different partial likelihood than the reported estimate (uniform weights short-circuit to `compute_estimate()`). Same mismatch as the non-KK Cox Bayesian bootstraps; covered in substance by v1.1.0-TODO-61; no v1.0.6 TODO tracks the comment or the interim mismatch.
- **M** (holds; 4fc58cd0): rchk PROTECT fix (RObject for callback results) in `lrt_ci_newton.cpp`; inverters, the TODO-172 exit and TODO-174 jump guard untouched. Adopt Brent holds.
- **N** (holds with updates; 72ea20ba, abd7e49d, 5bdb9dfb, bf7a6ae9): The exported log/identity-binomial score and Hessian helpers still use central differences; all four commits change the IRLS fitter (see A and Z). Adopt analytic (TODO-14) holds and is now close to a drop-in.
  - *Corrected facts:* `observed_newton_step()` (`fast_log_binomial_regression.cpp`, 72ea20ba) computes the closed-form per-row score and observed curvature in C++ for both links (log: s = y - (1-y)μ/(1-μ), c = (1-y)μ/(1-μ)²; identity: s = y/μ - (1-y)/(1-μ), c = y/μ² + (1-y)/(1-μ)²) and every fit uses it as a convergence gate; the 2026-11-16 "exist in R … only near the bound" statement is superseded. The FD helpers moved to ~:1094-1180.
- **O** (holds; 21e0679a, 39ee46bd): roxygen only. The corrected `fast_log_pnorm` doc now states the ±8 tail clamp, already this row's finding (Adopt, audit TODO-22; fix scheduled as v1.0.6-TODO-224).
- **P** (holds; 97e466f1, 5bdb9dfb): shared GH rule / barrier in hurdle-Poisson GLMM and its input checks; hurdle and ZOIB are still one joint generic optimization, continuation ratio still on the expanded matrix. Adopt holds.
- **Q** (holds; 39ee46bd): roxygen only (BRT KM-diff / RMST kernel and strata helper documented).
- **T** (holds; 21e0679a, 39ee46bd): roxygen only (beta-regression docs now say `fisher_information` is the observed information).
- **U** (holds; 4fc58cd0): rchk PROTECT fix in `distance_matrix_custom_cpp_impl`; arithmetic unchanged.
  - *Corrected facts:* "GH rule recomputed per fit (3 duplicate copies)": the hurdle-Poisson copy is gone (v1.0.6-TODO-193); copies remain in `fast_logistic_glmm.cpp`, `fast_clogit_plus_glmm.cpp` and `fast_weibull_frailty.cpp`.
- **V** (holds; 97e466f1, 3dabce47): the duplicated compound matched-pair + reservoir estimate in `kk_compound_distr_parallel.cpp` is one shared `compound_beta_hat()`; two dead helpers removed. Refit counts and the memoize / warm-start / batch TODOs (TODO-11, -16, -19, -26, -27) unchanged.
- **W** (holds; fe905ca8): asserts on `alpha` / `pval_epsilon` in the quantile Zhang CI; rq 'br', the HL bisection and the one-time seeding (no CRN across δ) unchanged.
- **X** (holds with updates; e00ab78f, c397cbc5): `method = "M"` now re-estimates the MAD scale every IRLS iteration and stops on rlm's relative residual-change test, with Huber's κ² SE factor (v1.0.6-TODO-50), i.e. it is `MASS::rlm(method = "M", scale.est = "MAD")`. "MM" unchanged (bisquare IRLS from OLS, scale fixed once), so "not Yohai's MM" and Prototype + rename (TODO-31) hold.
  - *Corrected facts:* "scale fixed once" applies to MM only; KK robust randomization draws (forced "M") now fit rlm-style Huber M, so "draws fit M while the estimate is MM" still stands; inventory entries for `fit_rlm_with_treatment` / `fit_combined` / `fit_rlm` / `fit_weighted_combined` should say maxit = 100 for every p and that the Rcpp branch returns NULL when unconverged.
  - *Verified by reading, minor:* `fast_robust_regression.cpp:177` clamps the initial scale to 1e-10, so the new exact-fit stop (`res.scale <= 0`, :195) cannot fire at iteration 1; with an OLS start of MAD 0, rlm returns the start while EDI takes one more WLS step. The comment above `hit_iteration_cap` (~:268) still describes a coefficient-change stop. Not covered by v1.0.6-TODO-50's text.
- **Y** (holds; 3dabce47): new `turnbull_npmle_group_lowest_survival` (v1.0.6-TODO-144) refits `icfit` per arm on the once-per-fit "median not reached" warning path only, consistent with the median rule. NPMLE still plain self-consistency EM; Prototype (TODO-28) holds.
- **Z** (holds with updates; abd7e49d, 5bdb9dfb, 72ea20ba): see A for the three log/identity-binomial changes. Still step-halving against the -∞ barrier with a Fisher / observed hybrid metric, not a constrained solver: start fixes Adopt (TODO-24, now done for log/identity binomial), solvers Prototype (TODO-32).
  - *Corrected facts:* facts cell → "log/identity-binomial infeasible starts are pulled into the mean support (v1.0.6-TODO-142; the cold start is still OLS of log1p(y) / y) and a rejected warm first step restarts cold (v1.0.6-TODO-209); IRLS has the active-set projection, KKT gate and an observed-information Newton check near bounds (TODO-128, v1.0.6-TODO-221) but no true constrained solver; Cox and adjacent-category cold starts regress without an intercept; ZINB start π = 0.5, θ = 1". The 2026-11-16 "the R layer now only drops infeasible warm starts" is partly redundant: the kernel repairs them.
  - *Suspected, low:* `fast_log_binomial_regression.cpp:535` / `:818` loop on `iter < maxit || kkt_confirm_pending`; a later small step near a bound can re-set the flag, so in principle the loop could run past maxit while the observed check keeps failing (the relative-step criterion should nearly always pass; not shown). Belongs under v1.0.6-TODO-221. Bookkeeping: v1.0.6-TODO-142 is still `[ ]` and v1.0.6-TODO-221 says "uncommitted", but both kernel changes are in HEAD (abd7e49d, 72ea20ba).
- **AA** (holds; 97e466f1, 72ea20ba, 569f3f2e): cauchit, cloglog and probit cumulative kernels folded into one template (`ordinal_fixed_link_internal.h`, v1.0.6-TODO-193) keeping each link's cold-start thresholds, the smart cold start, one L-BFGS run and the Newton-decrement downgrade; edge cases unified (v1.0.6-TODO-203: inputs validated before the K < 2 return, probit returns empty instead of a threshold-free fit); adjacent-category probabilities reuse exp() values. Still single-start for cauchit: Prototype (v1.0.6-TODO-33) holds.
- **AB** (holds; 3395b6c3, 97e466f1): the CR2 "not estimable" floor is now relative to the fit scale (v1.0.6-TODO-58), making the NULL return equivariant; the logistic g-comp HC0 and cluster post-fits share one templated pipeline with identical results (v1.0.6-TODO-193). CR2 adjustment and Bell-McCaffrey / Satterthwaite df unchanged.
- **AC** (holds; 5bdb9dfb, abd7e49d, fe905ca8): `run_all_inference` seeds each task from one master draw plus a hash of its result name (v1.0.6-TODO-219), passes `r` / `B` through and pre-flights B for the param-boot LR CI. The fork dispatch is still FIFO, so LPT stays Adopt and unimplemented; results no longer depend on task order or core count, so an LPT reorder would not change any result.

Filed 2026-11-20: the findings above for rows L, A, X, K, Z and I are v1.0.6-TODO-271, -272, -273, -274, -275 and -276.
