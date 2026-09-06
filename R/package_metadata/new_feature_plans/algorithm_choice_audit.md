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

Date: 2026-09-03

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
| `fast_zinb.cpp:412`, `fast_zero_augmented_poisson.cpp:303` (ZIP branch), `fast_zero_one_inflated_beta.cpp:467` | joint Newton/L-BFGS on the full parameter vector (all `β`, `log θ`, ZI coefficients at once), from a multistart set of cold starts (`multistart_nonconcave_likelihoods.md`) | `O(np)` per eval, superlinear but **no monotone-ascent guarantee**; can diverge toward a boundary (exactly `negbin_dispersion_convergence.md`'s finding) | **EM algorithm** (Dempster, Laird & Rubin 1977, *JRSS-B*; Lambert 1992, *Technometrics*, "Zero-Inflated Poisson Regression … " — the founding EM derivation for exactly this model; McLachlan & Peel 2000, *Finite Mixture Models*, ch. 2–3) | **Prototype** — `em_algorithm_zero_inflated_mixtures.md` |

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
`negbin_dispersion_convergence.md` exists to patch (an unconstrained
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
harness must measure (i) the fraction of `negbin_dispersion_convergence.md`
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
`randomization_ci_affine_shift_reuse.md` (one null distribution serves the
whole search via an exact shift identity, ~20–30×) and
`randomization_ci_search_precision.md` (a final high-precision confirmation
pass after early-stopped bisection). Both reduce the cost of **each**
bisection step or of the last one; neither changes the fact that the search
is bisection at all — `O(log(range/tol))` separate full-precision
evaluations.

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

## L. Cox partial-likelihood tie handling — **not verified, flagged for follow-up**

`fast_coxph_regression.cpp` was checked for explicit Breslow/Efron/exact
tie-handling branches and none were found under those names in a keyword
search; this may mean ties are handled by a different internal mechanism
not surfaced under the standard names, or that the risk-set construction
makes the distinction moot for this implementation. **This row is
intentionally left as an open question rather than a guess** — a future
pass of this audit should read `fast_coxph_regression.cpp`'s risk-set
construction directly (not just grep it) and confirm which method is
implemented, since Efron's approximation (the modern default in `coxph`)
and Breslow's are not the same algorithm and the choice matters for
tied-event-heavy survival data.

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
| B | (same) | (same) | (same) | fits the joint optimizer currently fails on (`negbin_dispersion_convergence.md`'s fixture) | not a wall-clock ratio — converts a failed/`nonest` fit to a converged one | theoretical: EM's monotone-ascent guarantee |
| C | GLMM/LMM/frailty quadrature | fixed 20-node GH | adaptive GH (5–9 nodes) | every GLMM objective call | 1.5–2.5× per call; 1.2–2× end-to-end on GLMM-heavy workflows | **already estimated elsewhere** — `performance_profiling_and_upgrades.md §8.8`, not this audit |
| D | randomization/bootstrap CI search | bisection (~20–35 full-precision steps) | Robbins–Monro (Garthwaite–Buckland) | any CI search | ~3–20× | structural: ratio derives from the bisection step count, unmeasured |
| D | (composed) | bisection + affine-shift-reuse (shipped) | + Robbins–Monro | any CI search | multiplicative with the ~20–30× `randomization_ci_affine_shift_reuse.md` already shipped | structural |
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
| L | Cox tie handling | unverified | Efron vs. Breslow | **Flagged for follow-up** |
| M | score / gradient / Bartlett-LR CI inversion | pure bisection (LR path already uses Newton) | Brent (Brent 1973) | **Adopt** → `brent_ci_inversion.md` |

---

## Implementation TODOs

- [ ] TODO-1: **A/B testing harness** (gates every Prototype row above):
  `algorithm_ab_testing_framework.md → TODO-1..N`. Build once, reuse for
  every item below and every future algorithm-choice question.
- [ ] TODO-2: **Garthwaite–Buckland CI search** (row D):
  `garthwaite_buckland_ci_search.md → TODO-1..N`. Depends on TODO-1's
  harness for the promotion decision.
- [ ] TODO-3: **EM for zero-inflated mixtures** (row B):
  `em_algorithm_zero_inflated_mixtures.md → TODO-1..N`. Depends on TODO-1.
- [ ] TODO-4: **Balanced bootstrap resampling** (row J) — not yet a plan.
  Scope: `bootstrap_indices.cpp`, `bootstrap_match_indices.cpp`; measure
  CI-width reduction at fixed `B` through the TODO-1 harness before writing
  the implementation plan.
- [ ] TODO-5: **Saddlepoint p-value screening** (row E) — not yet a plan;
  lowest priority of the four Prototype rows because it is the only one
  that changes an exactness guarantee rather than only cost. Scope as
  early-stop-trigger-only (reported p-value stays Monte Carlo) for the
  first version.
- [ ] TODO-6: **Cox tie-handling verification** (row L) — read
  `fast_coxph_regression.cpp`'s risk-set construction directly; either
  update this row to a real verdict or file a correctness finding if the
  method turns out to be neither Breslow nor Efron and ties are common in
  the survival-response test fixtures.
- [ ] TODO-7: Re-run this audit's method (not its conclusions) whenever a
  new kernel family ships, and after each Prototype item resolves through
  the harness, to keep the summary table current.
- [ ] TODO-8: **Replace the "Estimated speedup multiples" section's
  theoretical figures with measured ones** as each Prototype item's A/B
  report lands (TODO-2..5 above); until then that section's numbers must
  stay clearly labeled as unmeasured estimates, never quoted elsewhere as
  results.
- [ ] TODO-9: **Brent for the score / gradient / Bartlett-LR CI inverters**
  (row M): `brent_ci_inversion.md → TODO-1..3`. Adopt, not Prototype —
  deterministic root-finder swap, bound identical within `tol`; gated on
  the existing CI tests, not the A/B harness. Independent of TODO-1..5.
