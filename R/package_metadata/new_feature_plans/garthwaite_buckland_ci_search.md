# Robbins–Monro (Garthwaite–Buckland) Search for Randomization/Bootstrap CI Bounds

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Depends on:** `algorithm_ab_testing_framework.md → TODO-1..4` (the
> harness this plan's promotion decision runs through). **Complements**,
> does not replace, `randomization_ci_affine_shift_reuse.md` (cuts the cost
> of each p-value evaluation the search calls; this plan cuts the *number*
> of evaluations — but only on the classes where both apply, since on that
> plan's tier-1 classes RM is not offered at all, see the Scope note) and
> `randomization_ci_search_precision.md` (whose "the real fix" section
> names anytime-valid confidence sequences as the eventual principled
> redesign — this plan is the smaller, sooner step: same bisection *driver*
> replaced, nothing else about the testing framework changes).
> **Scope (2026-09-04, user question):** applies only where `p(δ)` is a
> *Monte Carlo* estimate — randomization and bootstrap CIs, and the
> bootstrap-calibrated LR CI of `bootstrap_calibrated_lr_report.md` (its
> second consumer: there each draw is two refits, so the evaluation count
> is the whole cost). It does **not** apply to the deterministic score /
> gradient / Bartlett-LR inverters — on an exactly-evaluable `p(δ)` RM is
> slower than the bisection they already use; their upgrade is Brent,
> `brent_ci_inversion.md` (`algorithm_choice_audit.md → row M`).
> **Also not offered for the tier-1 classes of
> `randomization_ci_affine_shift_reuse.md`** (simple mean diff, average
> diff, OLS, Lin — `supports_additive_delta_shift() == TRUE`) once that
> plan lands: there `p(δ)` is an exact step function evaluable in O(r) from
> one cached δ = 0 distribution, so a single bisection step costs *less*
> than a single RM replicate draw and RM cannot win; see that plan's
> "Interaction with the CI-search-driver plans" section (2026-09-04).
> TODO-3 dispatches around those classes and TODO-4 stratifies the A/B
> corpus on the predicate. Release:
> v1.2.0 (`release_v1_2_0.md → TODO-21`; moved from `release_v1_1_0.md →
> TODO-17u` on 2026-09-06, lighten-1.1.0 pass, user decision; found by
> `algorithm_choice_audit.md`
> → row D, 2026-09-03).

Date: 2026-09-03

**Goal:** Add a Robbins–Monro stochastic-approximation search
(Garthwaite & Buckland 1992) as an **opt-in alternative driver** for
randomization/bootstrap CI bound-finding, validate it against the current
bisection driver through the A/B harness on a representative corpus, and
report — not assume — the size of the win.

**Architecture:** One new R-level driver function,
`garthwaite_buckland_ci_bound()`, implementing the same contract as the
**live, R-level** bound search — `compute_rand_confidence_interval()` →
`build_randomization_ci_search_bounds()` → the per-δ bisection loop over
`compute_randomization_ci_pval_cached()` in
`inference_all_abstract_rand_ci.R` — returning one CI bound.
**Correction (2026-09-04):** an earlier draft of this plan named
`bisection_ci_single_bound_cpp()` (`src/bisection_ci.cpp`) as the contract
to match. `graft callers` shows that kernel — and its siblings
`bisection_ci_parallel_cpp` / `bisection_ci_loop_cpp` — has **no caller
except its own `RcppExports` wrapper**; it is dead code that
`ols_randomization_distr_cpp_wiring.md → TODO-4` deletes. The
randomization CI search has always been driven from R; match the R driver.
It is a pure alternative *driver* — it calls the exact same p-value
evaluation machinery (`compute_randomization_ci_pval_cached()` and
everything under it, including the affine-shift-reuse optimization once
that plan lands) the bisection driver calls today. No C++ kernel changes.
Selected via a new `ci_search_algorithm` argument threaded the same way
`optimization_alg` is, defaulting to `"bisection"` (today's behavior,
untouched) until the A/B harness clears it for a wider default.

**Tech Stack:** R only. No new dependencies (the Robbins–Monro update is a
handful of arithmetic lines; no package implements it that would be worth
depending on for this).

**Spec:** this file; the algorithm itself is Garthwaite, P. H. & Buckland,
S. T. (1992), "Generating Monte Carlo Confidence Intervals by the
Robbins–Monro Process," *Applied Statistics* 41(1), 159–171; refinements in
Garthwaite, P. H. & Jones, M. C. (2009), "A stochastic approximation method
and its application to confidence intervals," *J. Comp. Graph. Stat.*
18(1), 184–200.

## Global Constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
  `load_all()` without `compile = FALSE`** — see the repo `CLAUDE.md`. This
  plan touches no `.cpp` file; if that changes during implementation, stop
  and re-read that file before compiling anything.
- **Default stays `"bisection"` until TODO-4's A/B report clears a wider
  default.** No task in this plan may change `get_optimization_dispatch_policy()`
  -style defaults ahead of that report.
- **The new driver must call the exact same `pval_fn` the bisection driver
  calls** — no separate, cheaper-but-different p-value path. The whole
  point of the comparison is "same evaluations, different search
  algorithm," not "different evaluations too," which would confound the
  A/B result.
- **Coverage is the correctness contract**, not point-agreement with
  bisection. Because this is a different stochastic algorithm converging
  to the same theoretical target, two runs will not produce bit-identical
  bounds even with the same seed; the equivalence metric is long-run
  coverage and mean width under repeated simulation (per
  `algorithm_ab_testing_framework.md`'s row-D metric definition), not a
  single-dataset point comparison.

---

## Design

### The algorithm

Garthwaite–Buckland treats CI-bound-finding as a stochastic root-finding
problem: find `δ` such that `p(δ) = α` (for a one-sided bound; the current
code already does one bound at a time, `bisection_ci_single_bound_cpp`'s
`lower` flag), where `p(δ)` is only observable through noisy simulation
(one randomization/bootstrap replicate at a time, not a full re-run of `B`
replicates per candidate `δ`).

Update rule, at step `k` with current estimate `δ_k`:

1. Draw **one** replicate `w_k` from the reference distribution at the
   current `δ_k` (reusing the exact machinery `pval_fn` already wraps —
   see "Interfaces" below for how the callback contract needs to expose a
   single-replicate primitive, not just a full-`B` batch call).
2. Compute the replicate's contribution to the test statistic's sign
   relative to the observed value (the indicator that would, summed over
   many replicates, give `p(δ_k)`).
3. Update: `δ_{k+1} = δ_k − c_k · (indicator_k − α)`, where `c_k = c_1 /
   k^θ` is a decreasing step-size sequence. `θ ∈ (1/2, 1]` is required for
   convergence at all (Robbins & Monro 1951: `Σ c_k = ∞` needs `θ ≤ 1`,
   `Σ c_k² < ∞` needs `θ > 1/2`). Within that window, `θ` near 1 gives the
   fastest rate but only if `c_1` is calibrated almost exactly to the local
   slope of `p(δ)` at the true root — an unknown quantity, since it's
   essentially the density at the boundary being searched for. Following
   the robust/averaged formulation (Polyak & Juditsky 1992; the variant
   Garthwaite & Jones 2009 build on), this plan fixes `θ = 0.75` — smaller,
   deliberately oversized steps that don't need `c_1` calibrated
   precisely — and relies on step 4's iterate averaging to recover the
   same asymptotic efficiency a perfectly-tuned `θ = 1` schedule would
   have. `θ` is a fixed algorithmic constant from this theory, not
   something tuned per dataset or searched by the A/B harness; `c_1` is
   the one constant that gets a per-run pilot calibration (below).
4. After `K` total steps, average the last `~K/2` iterates (Polyak–Ruppert
   averaging, standard practice for Robbins–Monro to reduce the asymptotic
   variance without changing the step-size schedule) as the final CI bound
   estimate.

Total simulation cost to reach a target SE on the bound is `O(1/tol²)`
**draws**, in one continuous sequential process — not `O(log(range/tol))`
separate full-`B`-replicate bisection steps. The two costs are not directly
comparable analytically (they trade off differently against the variance of
a single p-value evaluation vs. a single indicator draw), which is exactly
why this needs the empirical harness rather than a closed-form "this many
times faster" claim.

### Interfaces

**Consumes** (from the existing codebase, unchanged):
- `private$compute_randomization_ci_pval_cached(inf_obj, r, delta,
  transform_arg, permutations, ci_search_control, ci_pval_cache)` —
  `inference_all_abstract_rand_ci.R`'s existing per-δ p-value evaluator.
  This already computes a full-`B` p-value; TODO-1 below needs a
  **single-replicate** variant, since Robbins–Monro consumes one draw at a
  time. This is the one real implementation question this plan resolves
  (TODO-1) — everything else is the update-rule arithmetic.
- The R-level bound search in `build_randomization_ci_search_bounds()` and
  the bisection loop beneath it (`inference_all_abstract_rand_ci.R`) as the
  shape to match: an initial bracket, the `pval_th` (= `alpha`) target,
  the `pval_epsilon` tolerance, `transform_arg`, the `lower`/upper side,
  and one `double` bound returned. (Not `bisection_ci_single_bound_cpp` —
  dead, see the Architecture correction.)
- `supports_additive_delta_shift()` from
  `randomization_ci_affine_shift_reuse.md → TODO-1` (registry-visible),
  which TODO-3 uses to dispatch *around* tier-1 classes.

**Produces:**
- `garthwaite_buckland_ci_bound(single_replicate_fn, r, l, u, pval_th, tol,
  lower, max_steps = 2000L, c1 = NULL, theta = 0.75, seed = NULL) -> double`
  — the new driver, in `R/EDI/R/helper_garthwaite_buckland_ci.R`.
- A `ci_search_algorithm = c("bisection", "garthwaite_buckland")` argument
  on `compute_confidence_interval_rand()` and its bootstrap sibling
  (`inference_all_abstract_rand_ci.R`, `inference_all_abstract_rand_bootstrap_ci.R`),
  defaulting to `"bisection"`.

---

## Implementation TODOs

### TODO-1: Single-replicate p-value primitive

**Files:**
- Modify: `R/EDI/R/inference_all_abstract_rand_ci.R` (near
  `compute_randomization_ci_pval_cached`, wherever it is defined — search
  for its definition, not just its call site at `:276`)
- Test: `R/EDI/tests/testthat/test-garthwaite-buckland-single-draw.R` (new)

**Interfaces:**
- Produces: `private$draw_one_randomization_indicator(inf_obj, delta,
  transform_arg)` — draws exactly one replicate from the same reference
  distribution `compute_randomization_ci_pval_cached` draws `B` of, and
  returns `1` if that replicate's statistic is at least as extreme as the
  observed one (the summand whose mean over many draws *is* `p(delta)`),
  `0` otherwise. Must reuse the same generator (`generate_permutations_*`
  family or the bootstrap index draw, whichever the class already uses) —
  not a reimplementation.

- [ ] **Step 1: Read `compute_randomization_ci_pval_cached`'s definition**
  (find it — it's a `private$` method somewhere in
  `inference_all_abstract_rand_ci.R` or a mixin it composes) and identify
  exactly which line turns `B` replicate draws into the returned p-value
  (almost certainly a `mean(indicator)` or `(sum(indicator) + 1) / (B + 1)`
  pattern). This tells you the one-replicate primitive to extract.
- [ ] **Step 2: Write the failing test:**

```r
library(testthat)
library(EDI)

test_that("a single-replicate draw's long-run mean matches the batch p-value", {
	# Build any small Inference object the way the existing bisection CI
	# tests do (e.g. logistic-regression randomization inference on a
	# small fixture); reuse that fixture-construction code verbatim from
	# an existing test file such as tests/testthat/test-randomization-ci*.R
	inf = <construct as an existing randomization-CI test does>
	set.seed(42)
	batch_pval = inf$.__enclos_env__$private$compute_randomization_ci_pval_cached(
		inf, r = 2000L, delta = 0, transform_arg = NULL,
		permutations = NULL, ci_search_control = list(), ci_pval_cache = new.env())
	set.seed(42)
	draws = replicate(2000L, inf$.__enclos_env__$private$draw_one_randomization_indicator(
		inf, delta = 0, transform_arg = NULL))
	expect_equal(mean(draws), batch_pval, tolerance = 0.05)
})
```

  Replace `<construct ...>` with the concrete fixture from an existing
  bisection-CI test file — find one with
  `grep -rl "compute_confidence_interval_rand" R/EDI/tests/testthat/` and
  copy its setup, do not invent new fixture code.
- [ ] **Step 3: Run to confirm failure.**
- [ ] **Step 4: Implement `draw_one_randomization_indicator()`** by
  extracting the single-replicate body identified in Step 1 into its own
  method, and rewriting `compute_randomization_ci_pval_cached` to call it
  `B` times in a loop (or keep the batch path as-is for speed and add the
  single-draw method as a separate, smaller extraction — whichever avoids
  slowing down the untouched bisection path; **the batch path's existing
  behavior and speed must not regress**, verified in Step 6).
- [ ] **Step 5: Run the test, confirm pass** (within Monte Carlo tolerance
  — this is a statistical equivalence check, not a bit-identical one).
- [ ] **Step 6: Regression-check the untouched bisection path** — run the
  existing bisection-CI test suite (`test-randomization-ci*.R` or
  equivalent) and confirm no timing or numeric regression from the
  refactor in Step 4.
- [ ] **Step 7: Commit** — `git commit -m "feat(garthwaite-buckland): extract a single-replicate randomization-indicator primitive"`.

### TODO-2: The Robbins–Monro driver

**Files:**
- Create: `R/EDI/R/helper_garthwaite_buckland_ci.R`
- Test: `R/EDI/tests/testthat/test-garthwaite-buckland-driver.R` (new)

**Interfaces:** consumes TODO-1's `draw_one_randomization_indicator`;
produces `garthwaite_buckland_ci_bound()` per the Design section's
signature.

- [ ] **Step 1: Write the failing test** — a synthetic root-finding problem
  first, decoupled from the whole `Inference` machinery, to validate the
  update rule in isolation:

```r
test_that("garthwaite_buckland_ci_bound recovers a known root under Bernoulli noise", {
	# single_replicate_fn(delta) returns a noisy 0/1 indicator whose true
	# mean is a known monotone function of delta, e.g. plogis(2 * (delta - 3))
	single_replicate_fn = function(delta) as.numeric(runif(1) < plogis(2 * (delta - 3)))
	set.seed(11)
	bound = garthwaite_buckland_ci_bound(single_replicate_fn, l = -5, u = 10,
		pval_th = 0.5, tol = 0.05, lower = TRUE, max_steps = 4000L, seed = 11)
	expect_equal(bound, 3, tolerance = 0.3)
})

test_that("garthwaite_buckland_ci_bound is deterministic given the same seed", {
	single_replicate_fn = function(delta) as.numeric(runif(1) < plogis(2 * (delta - 3)))
	a = garthwaite_buckland_ci_bound(single_replicate_fn, l = -5, u = 10, pval_th = 0.5,
		tol = 0.05, lower = TRUE, max_steps = 1000L, seed = 5)
	b = garthwaite_buckland_ci_bound(single_replicate_fn, l = -5, u = 10, pval_th = 0.5,
		tol = 0.05, lower = TRUE, max_steps = 1000L, seed = 5)
	expect_identical(a, b)
})
```

- [ ] **Step 2: Run to confirm failure.**
- [ ] **Step 3: Implement `garthwaite_buckland_ci_bound()`** per the Design
  section's update rule: a short pilot phase (first ~50 steps at a fixed
  `c_1` estimated from the bracket width `u - l`) to calibrate the step
  scale, then the `c_k = c_1 / k^theta` schedule, clamped to stay within
  `[l, u]` each step, Polyak–Ruppert-averaging the last half of the
  iterates, using a private `edi_rng::RRng`-equivalent R-level generator
  seeded by `seed` (or, if this driver is only ever called from inside an
  already-seeded `Inference` replicate loop, document that it consumes R's
  live stream the same way the rest of the randomization machinery does —
  resolve this by checking how `draw_one_randomization_indicator` seeds
  itself in TODO-1 and matching that convention, not inventing a new one).
- [ ] **Step 4: Run tests, confirm pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat(garthwaite-buckland): Robbins-Monro CI bound driver"`.

### TODO-3: Wire into `compute_confidence_interval_rand()` as an opt-in

**Files:**
- Modify: `R/EDI/R/inference_all_abstract_rand_ci.R` (the bisection loop
  under `build_randomization_ci_search_bounds()` — locate it with
  `graft callers build_randomization_ci_search_bounds` and
  `graft callers compute_randomization_ci_pval_cached`; **not**
  `bisection_ci_single_bound_cpp`, which has no callers)
- Modify: `R/EDI/R/inference_all_abstract.R` (add `ci_search_algorithm` to
  wherever `optimization_alg`-style dispatch arguments live, mirroring
  `set_optimization_alg()`'s pattern)
- Test: `R/EDI/tests/testthat/test-garthwaite-buckland-integration.R` (new)

- [ ] **Step 1: Trace the call path** from `compute_confidence_interval_rand()`
  → `compute_rand_confidence_interval()` →
  `build_randomization_ci_search_bounds()` → the per-δ
  `compute_randomization_ci_pval_cached()` calls inside the bisection loop
  (`graft callers compute_randomization_ci_pval_cached`), confirming every
  call site. Expect no C++ bisection kernel on the path.
- [ ] **Step 2: Write the failing test** — construct the same Inference
  fixture as TODO-1's test, compute a CI with `ci_search_algorithm =
  "bisection"` (today's default, must be unchanged — assert bit-identical
  to a pre-change baseline recorded first) and with `ci_search_algorithm =
  "garthwaite_buckland"` (assert it returns a finite bound in a
  plausible range, not equal to bisection's — different algorithm, not a
  bit-for-bit requirement here).
- [ ] **Step 3: Run to confirm failure.**
- [ ] **Step 4: Add the dispatch** — a single `if (ci_search_algorithm ==
  "garthwaite_buckland") ... else <existing bisection call, untouched>`
  branch at the call site found in Step 1, defaulting the new argument to
  `"bisection"` everywhere it is threaded. **Before** that branch, dispatch
  around the affine-shift tier-1 classes: if
  `isTRUE(private$supports_additive_delta_shift())` and the caller asked
  for `"garthwaite_buckland"`, emit one `message()` ("Robbins–Monro is not
  offered for additive-shift classes; their p-values are exact from one
  cached null distribution — using bisection") and fall through to the
  bisection path. Add to Step 2's test: a tier-1 OLS fixture with
  `ci_search_algorithm = "garthwaite_buckland"` returns a CI **identical**
  to the `"bisection"` one (it never entered the RM driver).
- [ ] **Step 5: Run tests, confirm pass; run the full existing
  randomization-CI test suite to confirm zero change to the default path.**
- [ ] **Step 6: Commit** — `git commit -m "feat(garthwaite-buckland): opt-in ci_search_algorithm argument on randomization CI"`.

### TODO-4: A/B validation and the promotion report

**Files:**
- Create: `R/EDI/tests/algorithm_ab/metrics_ci_search.R` (the row-D
  equivalence metric from `algorithm_ab_testing_framework.md`'s design
  table: coverage + mean width under repeated simulation, not a
  single-dataset point comparison)
- Uses: `algorithm_ab_testing_framework.md`'s `run_algorithm_ab()` and
  `decide_algorithm_ab()`

- [ ] **Step 1: Define the `"ci_search"` corpus generator** in
  `R/EDI/tests/algorithm_ab/corpus.R` (extending TODO-1 of the framework
  plan): sweep `n` and effect size per the framework's axis table, plus
  `α ∈ {0.05, 0.01}` and the two adversarial entries (a case with a very
  flat `p(δ)` near the bound — the regime bisection is known to spend the
  most steps in — and an easy, steep-`p(δ)` case). **Stratify every entry
  by `supports_additive_delta_shift()`.** The tier-1 stratum (mean diff /
  OLS / Lin) is included only as a control whose expected verdict is
  `keep` — after `randomization_ci_affine_shift_reuse.md` lands, its
  baseline evaluations are O(r) arithmetic and RM cannot beat them — and it
  must not enter the promotion decision. Promote on the non-tier-1 stratum
  only: rank statistics (Wilcoxon, ridit, KK signed-rank), transformed-scale
  count / proportion / survival classes, non-linear model coefficients, and
  the bootstrap CIs.
- [ ] **Step 2: Define the equivalence metric** — for each corpus entry,
  run **many independent simulated datasets** from the same DGP (not one
  dataset re-analyzed many times), compute the CI both ways on each, and
  compare empirical coverage (nominal `1 - α`) and mean width between the
  two algorithms. `within_tolerance`: coverage differs by no more than 2
  percentage points and mean width differs by no more than 5%, both fixed
  in advance per D3's "fixed before results are seen" rule.
- [ ] **Step 3: Run `run_algorithm_ab("ci_search", baseline =
  <bisection-based CI call>, candidate = <garthwaite_buckland-based CI
  call>, equivalence_metric, ...)`**, then `decide_algorithm_ab()`, then
  `render_algorithm_ab_report()`.
- [ ] **Step 4: Read the report.** If `verdict` is `adopt-conditional` or
  `adopt-default`, open a follow-up decision (not automatic — a human
  reads the report) about whether to flip `get_optimization_dispatch_policy()`
  -style defaults for the qualifying regimes; if `keep` or `opt-in`, this
  plan's outcome is "shipped as a documented opt-in," which is still a
  real, useful result — record it plainly rather than treating a non-default
  outcome as a failure.
- [ ] **Step 5: Update `algorithm_choice_audit.md`'s row D** with the
  report's link and verdict.
- [ ] **Step 6: Commit** — `git commit -m "test(garthwaite-buckland): A/B validation against bisection, promotion report"`.

---

## Self-review (2026-09-03)

- **Spec coverage:** the single-replicate primitive (TODO-1), the driver
  itself (TODO-2), the opt-in wiring (TODO-3), and the mandatory A/B
  validation before any default change (TODO-4) cover the full Design
  section. The "complements, does not replace" relationship to the two
  sibling CI plans is stated in the header and not re-litigated in the
  tasks.
- **Placeholders:** `<construct ...>` in TODO-1/TODO-3 points at a concrete
  discovery step (grep existing test files) rather than an undefined
  blank.
- **Type consistency:** `garthwaite_buckland_ci_bound()`'s signature is
  identical between the Design section's "Produces" list and TODO-2's
  implementation step.
