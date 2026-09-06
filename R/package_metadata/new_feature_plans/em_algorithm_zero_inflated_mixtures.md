# EM Algorithm for Zero-Inflated Mixture Likelihoods (ZINB, ZIP, ZOIB)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Depends on:** `algorithm_ab_testing_framework.md → TODO-1..4` (the
> harness this plan's promotion decision runs through);
> `multistart_nonconcave_likelihoods.md` (an EM-then-Newton hybrid, per
> this plan's Design section, is a new *deterministic start* for that
> plan's `optimize_fixed_likelihood_multistart()` — this plan composes with
> it, not around it). **Relevant, not blocking:**
> `negbin_dispersion_convergence.md` (the failure mode this plan targets:
> unconstrained joint Newton/L-BFGS running the dispersion parameter off to
> a numerical boundary on non-overdispersed data — already patched with a
> boundary-acceptance mitigation there; this plan is a structurally
> different fix at the algorithm level). Release: v1.1.0
> (`release_v1_2_0.md → TODO-21`; moved from `release_v1_1_0.md →
> TODO-17v` on 2026-09-06, lighten-1.1.0 pass, user decision; found by
> `algorithm_choice_audit.md` →
> row B, 2026-09-03).

Date: 2026-09-03

**Goal:** Add an EM-then-Newton hybrid fitting path for the zero-inflated
mixture kernels (ZINB, the ZIP branch of `fast_zero_augmented_poisson.cpp`,
zero-one-inflated beta), validate through the A/B harness that it either
rescues fits the current joint-optimizer path fails to converge on, wins on
wall-clock in some regime, or both — and ship it as whatever the report
supports (opt-in, conditional default, or "keep, documented as evaluated
and rejected").

**Architecture:** One new leaf header,
`R/EDI/src/em_zero_inflated_mixture.h`, implementing the EM iteration
generically over an "E-step responsibility function + weighted M-step
refit" interface, plus one small function per family
(`em_step_zinb`, `em_step_zip`, `em_step_zoib`) supplying that family's
specific E-step formula and calling the family's **existing** weighted
IRLS/Newton kernel for the M-step (`fast_negbin_regression.cpp`'s weighted
path for ZINB's count component, `fast_poisson_regression.cpp`'s weighted
path for ZIP, `fast_logistic_regression.cpp`'s weighted path for every
zero-inflation logit component — all three already accept a `weights`
vector; verified in TODO-1). EM runs for a capped number of iterations (or
until the log-likelihood increase falls below a threshold), then hands its
result to the existing `optimize_fixed_likelihood_multistart()` as one more
deterministic start (`multistart_nonconcave_likelihoods.md`'s
`MultistartSpec`), which polishes it with Newton/L-BFGS to the same
convergence tolerance every other start uses. EM never replaces the final
optimizer; it only replaces (or, initially, augments) the *starting point*
supply.

**Tech Stack:** C++17 / Eigen, reusing the existing weighted-IRLS objective
classes already compiled into `fast_negbin_regression.cpp`,
`fast_poisson_regression.cpp`, `fast_logistic_regression.cpp` (verified
present in TODO-1; if any is `.cpp`-local rather than header-exposed, that
translation unit needs a small refactor to expose it — scoped in TODO-1,
not assumed away).

**Spec:** this file. Algorithm citations: Dempster, A. P., Laird, N. M. &
Rubin, D. B. (1977), "Maximum Likelihood from Incomplete Data via the EM
Algorithm," *JRSS-B* 39(1), 1–38 (the general EM framework); Lambert, D.
(1992), "Zero-Inflated Poisson Regression, With an Application to Defects
in Manufacturing," *Technometrics* 34(1), 1–14 (the EM derivation for
exactly the ZIP model, generalizes directly to ZINB); McLachlan, G. J. &
Peel, D. (2000), *Finite Mixture Models*, Wiley, ch. 2–3 (general mixture
EM theory, monotone-ascent proof); Redner, R. A. & Walker, H. F. (1984),
"Mixture Densities, Maximum Likelihood and the EM Algorithm," *SIAM Review*
26(2), 195–239 (the EM-then-Newton hybrid-recipe justification this plan
follows).

## Global Constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
  `load_all()` without `compile = FALSE`** — see the repo `CLAUDE.md`.
  This plan touches multiple `.cpp` files across several tasks; each task's
  compile step is scoped to only the files it modified. Memory
  `feedback_targeted_compile_only` has the exact recipe.
- **EM is a start generator, not a replacement optimizer**, in this plan's
  first version. No task may remove the existing Newton/L-BFGS polish step
  or make EM's output the returned fit directly — see
  `multistart_nonconcave_likelihoods.md`'s `MultistartPolish::WhenSwitched`
  semantics, which this plan's integration (TODO-4) must respect.
- **Default stays off (`n_random_starts`-style opt-in) until TODO-5's A/B
  report clears a wider default** — same posture as
  `garthwaite_buckland_ci_search.md`.
- **Monotone-ascent is a testable invariant, not just a citation.** Every
  EM step's test in TODO-2/3 must assert the log-likelihood is
  non-decreasing step-over-step on real fixtures — if it ever decreases,
  that is an implementation bug (a wrong E-step formula or a M-step that
  isn't actually maximizing the expected complete-data log-likelihood),
  not algorithm noise, and must be fixed before proceeding.
- No new package dependencies.

---

## Design

### The EM formulation (ZINB, worked in detail; ZIP and ZOIB follow the same shape)

Model: `y_i` is 0 with probability `π_i = logit^{-1}(X_{zi,i} γ)`
(structural zero) or drawn from `NegBin(μ_i, θ)` with `μ_i =
exp(X_{c,i} β)` (which can itself produce a sampling zero) with probability
`1 - π_i`. Latent indicator `z_i = 1` if observation `i` is a structural
zero.

**E-step** (closed form, given current `(β, θ, γ)`):

```
For y_i > 0: ẑ_i = 0  (only the count component can produce a positive count)
For y_i = 0: ẑ_i = π_i / (π_i + (1 - π_i) · NegBin(0; μ_i, θ))
```

**M-step** (given `ẑ_i` fixed, this decouples into two independent weighted
fits — the mixture's whole point):

- `γ` (zero-inflation logit): weighted logistic regression of `ẑ_i` on
  `X_{zi}`, weights all `1` (it's a fit to the *responsibilities themselves*
  as a continuous pseudo-response in `[0,1]`, the standard EM-for-mixtures
  M-step shape — reuses `fast_logistic_regression.cpp`'s weighted path with
  a real-valued response, exactly like weighted least squares on
  probabilities; confirm the kernel accepts a non-`{0,1}` `y` in TODO-1,
  and if it asserts binary `y`, that assertion needs relaxing for this
  caller only).
- `(β, θ)` (count component): weighted NegBin regression of `y_i` on
  `X_c`, restricted to observations with weight `(1 - ẑ_i)` — this is
  exactly `fast_negbin_regression.cpp`'s existing weighted-fit machinery,
  called with `weights = 1 - ẑ`.

Each M-step is a **concave** sub-problem (ordinary weighted logistic and
weighted NegBin regression, both already in row A's "Keep" category), so
each M-step itself converges reliably via the existing IRLS/Newton kernels
— EM's role is only to decouple the *joint* nonconcave mixture problem into
two well-behaved concave problems per iteration, not to introduce a new
optimizer.

**Stopping rule:** iterate until the observed-data log-likelihood
(computable in closed form from `π_i`, `μ_i`, `θ` each step — the same
`ZeroInflatedNegBin` objective the current joint optimizer already
evaluates) increases by less than a tolerance, or a fixed iteration cap
(default 25 — Lambert 1992 reports typical convergence in 10–30 iterations
for ZIP-shaped data) is reached. Cap exists because EM's late-stage
linear convergence rate means it is a poor *terminal* optimizer; this plan
hands off to Newton/L-BFGS at the cap regardless of whether EM itself has
fully converged (Redner & Walker 1984's hybrid recipe).

### ZIP and ZOIB

- **ZIP** (`fast_zero_augmented_poisson.cpp`'s ZIP branch): identical
  shape, with the NegBin M-step replaced by a weighted Poisson M-step
  (`fast_poisson_regression.cpp`'s existing weighted path) and no `θ`
  parameter to track.
- **ZOIB** (`fast_zero_one_inflated_beta.cpp`): a three-component mixture
  (zero mass, one mass, beta-distributed interior) — the E-step has two
  responsibilities (`ẑ_i` for "at zero", `ô_i` for "at one") instead of
  one, and the M-step for the beta component is a weighted beta regression
  on the interior observations. Scoped as TODO-6 (after ZINB/ZIP validate
  the pattern), since it is a strictly larger version of the same
  derivation and should not block the simpler cases.

---

## Implementation TODOs

### TODO-1: Audit the weighted M-step building blocks

**Files:** read only — `R/EDI/src/fast_negbin_regression.cpp`,
`fast_poisson_regression.cpp`, `fast_logistic_regression.cpp`

- [ ] **Step 1:** For each of the three kernels, confirm (a) a `weights`
  argument exists and is honored in both the objective and gradient (not
  just accepted and ignored — read the `operator()` body, not just the
  constructor signature); (b) whether the exported R-level function
  requires `y` to be strictly `{0,1}` (for the logistic kernel, since the
  EM M-step's pseudo-response `ẑ_i` is continuous in `[0,1]`) or integer
  counts (for Poisson/NegBin, where `y` must stay untouched — only the
  *weights* carry the responsibility, not the response); (c) whether the
  weighted objective is reachable from an internal C++ call (the `*_internal`
  functions used elsewhere in this codebase, e.g. `fast_zinb_internal`) or
  only from the `Rcpp::export`-decorated wrapper — the EM step needs the
  internal call for speed (no R↔C++ round trip per EM iteration).
- [ ] **Step 2:** Write down the findings in this file's Design section as
  a short addendum (which kernel needed a relaxed assertion, which needed
  a new internal-facing overload) so TODO-2/3 do not have to re-derive
  them.
- [ ] **Step 3:** No code changes in this task; commit only if Step 2's
  addendum is written — `git commit -m "docs(em-mixtures): audit weighted M-step building blocks"`.

### TODO-2: `em_zero_inflated_mixture.h` — generic EM driver + ZIP instantiation

**Files:**
- Create: `R/EDI/src/em_zero_inflated_mixture.h`
- Modify: `R/EDI/src/fast_zero_augmented_poisson.cpp` (ZIP branch only,
  the file's other branch — hurdle Poisson — is concave and untouched)
- Test: `R/EDI/tests/testthat/test-em-zip.R` (new)

**Interfaces:**
- Produces: `struct EMStepResult { Eigen::VectorXd params; double
  loglik; int n_iter; bool loglik_ever_decreased; }` and
  `EMStepResult em_fit_zip(const Eigen::MatrixXd& Xc, const
  Eigen::MatrixXd& Xz, const Eigen::VectorXd& y, const Eigen::VectorXd&
  start, int max_em_iter = 25, double loglik_tol = 1e-6)` — the pattern
  every later family's `em_fit_*` function repeats.

- [ ] **Step 1: Baseline.** With the current build, record
  `fast_zero_augmented_poisson_cpp()`'s fit on a synthetic ZIP fixture
  (`n = 300`, ~40% structural zeros, moderate signal — `set.seed(9)`) —
  `params`, `neg_loglik`.
- [ ] **Step 2: Write the failing tests:**

```r
library(testthat)
library(EDI)

make_zip_fixture = function(seed = 9L, n = 300L, zi_frac = 0.4) {
	set.seed(seed)
	w = rep(c(0, 1), length.out = n)
	x = rnorm(n)
	Xc = cbind(1, w, x)
	Xz = cbind(1, w)
	mu = exp(0.5 + 0.4 * w + 0.2 * x)
	structural_zero = runif(n) < plogis(-0.4 + 1.2 * w) * 0 + qlogis(zi_frac)  # calibrate below
	# Simpler, directly calibrated construction:
	pi_i = plogis(qlogis(zi_frac) + 0.5 * w)
	is_structural = runif(n) < pi_i
	y_pois = rpois(n, mu)
	y = ifelse(is_structural, 0L, y_pois)
	list(Xc = Xc, Xz = Xz, y = as.numeric(y))
}

test_that("EM log-likelihood is monotone non-decreasing on a real ZIP fixture", {
	d = make_zip_fixture()
	trace = em_fit_zip_trace_cpp(d$Xc, d$Xz, d$y, max_em_iter = 15L)  # test-only C++ export returning the loglik at every step
	diffs = diff(trace$loglik)
	expect_true(all(diffs >= -1e-8))
})

test_that("EM-then-Newton reaches at least as good a likelihood as the direct joint fit", {
	d = make_zip_fixture()
	direct = fast_zero_augmented_poisson_cpp(d$Xc, d$y, d$Xz, family = "zip")
	hybrid = fast_zero_augmented_poisson_cpp(d$Xc, d$y, d$Xz, family = "zip", use_em_start = TRUE)
	expect_true(hybrid$converged)
	expect_lte(hybrid$neg_loglik, direct$neg_loglik + 1e-6)
})

test_that("use_em_start = FALSE is bit-for-bit the pre-EM path", {
	d = make_zip_fixture()
	base = readRDS(test_path("fixtures", "em_zip_baseline.rds"))  # from Step 1
	fit = fast_zero_augmented_poisson_cpp(d$Xc, d$y, d$Xz, family = "zip", use_em_start = FALSE)
	expect_identical(fit$params, base$params)
	expect_identical(fit$neg_loglik, base$neg_loglik)
})
```

  (Fix the fixture-construction duplication in the first draft above before
  committing — write `pi_i`/`is_structural` cleanly, the intent is: a
  `zi_frac`-controlled fraction of structural zeros with a small covariate
  effect, and Poisson-distributed counts elsewhere.)
- [ ] **Step 3: Run to confirm failure.**
- [ ] **Step 4: Implement `em_zero_inflated_mixture.h`'s generic pieces**
  (`EMStepResult`, the E-step/M-step loop skeleton parameterized by two
  callables: a responsibility function and a pair of weighted-refit calls)
  and `em_fit_zip()` per the Design section, calling
  `fast_poisson_regression.cpp`'s and `fast_logistic_regression.cpp`'s
  internal weighted paths (per TODO-1's findings). Add a **test-only**
  export `em_fit_zip_trace_cpp()` that returns the log-likelihood at every
  EM iteration (for the monotonicity test) — guard it so it is not part of
  the public API surface (follow the codebase's existing convention for
  internal-test-only exports, e.g. check how other `*_trace_cpp` or
  `@keywords internal` exports are gated).
- [ ] **Step 5: Wire `use_em_start` into `fast_zero_augmented_poisson.cpp`'s
  ZIP branch** — when `TRUE`, run `em_fit_zip()` first and pass its result
  as one more deterministic start into
  `optimize_fixed_likelihood_multistart()` (per
  `multistart_nonconcave_likelihoods.md`'s `extra` starts list — append,
  don't replace, the existing deterministic starts for that kernel). When
  `FALSE` (default), the call path is byte-identical to today's.
- [ ] **Step 6: Targeted compile** — only the touched files, relink,
  `pkgload::load_all(".", compile = FALSE)`.
- [ ] **Step 7: Run tests, confirm pass.**
- [ ] **Step 8: Commit** — `git commit -m "feat(em-mixtures): EM-then-Newton hybrid start for the ZIP kernel"`.

### TODO-3: ZINB instantiation

**Files:**
- Modify: `R/EDI/src/em_zero_inflated_mixture.h` (add `em_fit_zinb`)
- Modify: `R/EDI/src/fast_zinb.cpp`
- Test: `R/EDI/tests/testthat/test-em-zinb.R` (new)

Same recipe as TODO-2, with two differences worth calling out:

- [ ] **Step 1: The E-step's `NegBin(0; μ_i, θ)` term** needs the current
  `θ` estimate, which is *also* being updated by the M-step — this is the
  standard "profile the nuisance parameter through EM" pattern (θ enters
  both the E-step, via the zero-probability formula, and the M-step, as a
  parameter of the weighted NegBin fit); verify the existing
  `ZeroInflatedNegBin` objective already exposes a `negbin_zero_prob(mu,
  theta)` helper (or a trivial one-liner) to reuse rather than
  reimplementing the NegBin PMF at zero.
- [ ] **Step 2 (the important test):** reuse
  `negbin_dispersion_convergence.md`'s own repro fixture (a plain Poisson
  draw with no injected overdispersion or excess zeros — the exact data
  shape that makes the direct joint optimizer's dispersion parameter run
  away) and assert the EM-then-Newton hybrid **converges** on it, unlike
  (or in addition to) the existing boundary-acceptance mitigation:

```r
test_that("EM-then-Newton converges on the negbin_dispersion_convergence.md repro fixture", {
	set.seed(1)
	n = 100L; w = rep(c(0,1), length.out = n); x1 = rnorm(n)
	y = rpois(n, exp(0.5 + 0.3 * w + 0.1 * x1))  # plain Poisson, no real overdispersion, no ZI
	Xc = cbind(1, w, x1); Xz = cbind(1, w)
	hybrid = fast_zinb_cpp(Xc, Xz, y, use_em_start = TRUE)
	expect_true(hybrid$converged)
})
```

- [ ] **Step 3-8:** baseline, remaining failing tests (monotonicity,
  never-worse-than-direct, `use_em_start = FALSE` bit-for-bit), implement,
  targeted compile, test, commit — `git commit -m "feat(em-mixtures): EM-then-Newton hybrid start for ZINB"`.

### TODO-4: Wire into `multistart_nonconcave_likelihoods.md`'s provenance

**Files:**
- Modify: the four provenance fields on the ZIP and ZINB kernels
  (`multistart_n_tried`, etc., from `multistart_nonconcave_likelihoods.md`
  §D2) so `selected_start` can name "EM" distinctly from "deterministic #k"
  or "random #k" when the EM-seeded start wins.
- Test: append to TODO-2/3's test files.

- [ ] **Step 1: Failing test** — `expect_identical(hybrid$multistart_selected,
  <the index corresponding to the EM start>)` on a fixture constructed so
  EM's start is known to be the winner (reuse TODO-3's dispersion-boundary
  fixture, where the EM start is expected to dominate the plain cold
  start).
- [ ] **Step 2: Implement** — thread the EM start through the same `extra`
  vector the other deterministic starts use, so
  `multistart_nonconcave_likelihoods.md`'s existing selection/provenance
  logic requires no changes beyond correctly labeling which index is EM's.
- [ ] **Step 3: Run, confirm pass, commit** — `git commit -m "feat(em-mixtures): label the EM start in multistart provenance"`.

### TODO-5: A/B validation and promotion report

**Files:** uses `algorithm_ab_testing_framework.md`'s harness; extends its
`"mixture_likelihood"` corpus (already scoped in that plan's TODO-1).

- [ ] **Step 1: Run `run_algorithm_ab("mixture_likelihood", baseline =
  <use_em_start = FALSE>, candidate = <use_em_start = TRUE>,
  equivalence_metric = <neg-loglik never worse, per
  algorithm_choice_audit.md's row-B metric>, ...)`** across the corpus
  (which already includes the `negbin_dispersion_convergence.md`
  adversarial-trap entry per the framework plan's D1).
- [ ] **Step 2: Add a second metric beyond speed** — **convergence rate**:
  fraction of corpus entries where `converged` flips from `FALSE` to
  `TRUE` with the EM start vs. without. This is the primary claimed
  benefit (row B in `algorithm_choice_audit.md` frames this as a
  robustness win, not necessarily a speed win) and must be reported
  alongside the timing table, not folded into it.
- [ ] **Step 3: Run `decide_algorithm_ab()` and
  `render_algorithm_ab_report()`.**
- [ ] **Step 4: Read the report.** Given this plan's own framing (a
  robustness win, wall-clock uncertain), a `keep`/`opt-in` verdict on the
  speed gate with a clear win on the convergence-rate metric is an
  expected and acceptable outcome — do not read a `keep` on gate 2 (speed)
  as the plan having failed; report the convergence-rate finding
  regardless of the speed verdict.
- [ ] **Step 5: Update `algorithm_choice_audit.md`'s row B** with the
  report's link, verdict, and the convergence-rate number.
- [ ] **Step 6: Commit** — `git commit -m "test(em-mixtures): A/B validation, promotion report"`.

### TODO-6: ZOIB instantiation (deferred until TODO-2/3 validate the pattern)

Scoped in the Design section's "ZOIB" paragraph; not broken into steps here
— write its own TODO list, mirroring TODO-2/3 exactly, once TODO-5's report
confirms the pattern is worth extending to a third family.

---

## Self-review (2026-09-03)

- **Spec coverage:** ZINB and ZIP (the concrete Design section) →
  TODO-2/3; ZOIB (sketched, deferred) → TODO-6, explicitly not blocking;
  the multistart-provenance integration → TODO-4; the mandatory A/B
  validation → TODO-5; the weighted-kernel reuse claim → TODO-1's audit,
  so nothing later assumes an unverified building block.
- **Placeholders:** the fixture-construction draft in TODO-2 Step 2 is
  flagged in its own step as needing cleanup before commit — this is a
  known rough edge in the plan's example code, called out explicitly
  rather than silently left broken, which is different from a "TBD".
- **Type consistency:** `EMStepResult` and `em_fit_zip()`/`em_fit_zinb()`'s
  signature is used identically between the Design section and TODO-2/3.
