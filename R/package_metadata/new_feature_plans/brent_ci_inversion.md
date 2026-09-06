# Brent's Method for the Score / Gradient / Bartlett-LR CI Inverters

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Depends on:** none. Found by `algorithm_choice_audit.md → row M`
> (2026-09-04, user question "can Garthwaite–Buckland also be applied to
> score and LR CIs?" — it cannot, but the question exposed that the score /
> gradient / Bartlett-LR inverter uses pure bisection while the LR inverter
> in the *same file* uses Newton). Release: v1.1.0
> (`release_v1_1_0.md → TODO-17w`). **Adopt, not Prototype**: a deterministic
> root-finder replacing a deterministic root-finder on an exactly-evaluable
> function — the returned bound is within `tol` of today's, so the gate is the
> existing CI tests, not `algorithm_ab_testing_framework.md`. Not to be
> confused with `garthwaite_buckland_ci_search.md`, which is for *Monte Carlo*
> `p(δ)` only. **Nor with the randomization CI search** — even after
> `randomization_ci_affine_shift_reuse.md` makes that search's `p(δ)`
> deterministic for its tier-1 classes, it is a *step* function (each
> `t0_b(δ) = t0_b(0) + δ·(1 − c_b)` is affine in δ under the corrected
> impute-then-permute identity, so the jumps sit at
> `(t − t0_b(0)) / (1 − c_b)`, plateaus between), on which Brent's
> interpolation steps are
> always rejected and the loop degrades to bisection; see that plan's
> "Interaction with the CI-search-driver plans" section (2026-09-04). This
> plan touches `lrt_ci_newton.cpp` only and nothing in
> `inference_all_abstract_rand_ci.R`.

Date: 2026-09-04

**Goal:** Replace the bisection phase of `pval_invert_ci_cpp()` with Brent's
method, cutting the number of constrained refits per CI bound from ~20 to
~5–8 with the same converged answer, and keep bisection available as an
explicit fallback.

**Architecture:** One C++ file changes. `pval_invert_ci_cpp()`
(`R/EDI/src/lrt_ci_newton.cpp:214-282`) has two phases: (1) a bracket
search — Wald seed first, then exponential expansion — that ends with
`p(a) > α` on the inner end and `p(b) ≤ α` on the outer end; (2) bisection
on `[a, b]` to `tol` in `δ`-space. Phase 1 is untouched. Phase 2 becomes a
Brent–Dekker iteration on `f(δ) = p(δ) − α` over the same bracket, with the
same `tol`, the same iteration cap, the same non-finite handling (break and
return the current outer endpoint), and the same return convention (the
outer endpoint `b`, i.e. the conservative side where `p ≤ α`). A new
`method = "brent" | "bisection"` argument (default `"brent"`) keeps the
old path callable for tests and as an escape hatch. The LR inverter
`lrt_ci_nr_cpp()` (`:99-159`, already Newton + bisection safeguard) is not
touched.

**Tech Stack:** C++ (Rcpp), ~40 lines for Brent–Dekker (Brent 1973,
*Algorithms for Minimization Without Derivatives*, ch. 4; the same
algorithm as R's `uniroot()` / `zeroin`). Implemented directly rather than
via R's `R_zeroin2()` C entry point so the per-evaluation non-finite check
can match today's `break` behavior exactly.

**Spec:** this file.

## Global Constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
  `load_all()` without `compile = FALSE`** — see the repo `CLAUDE.md`.
  Only `lrt_ci_newton.cpp` and `RcppExports.cpp` are recompiled here
  (memory `feedback_targeted_compile_only`).
- **Same answer within `tol`.** Both methods terminate when the bracket
  width is `< tol` (default `1e-6` in `δ`-space) and return the outer
  endpoint, so `|brent − bisection| < tol` on every bound. Tests assert
  exactly that; nothing looser.
- **Phase 1 and every degenerate branch are byte-identical**: `p(est)`
  non-finite → `c(NA, NA)`; `p(est) < α` → point CI at `est`; no bracket
  found → `NA` for that bound; non-finite `p` mid-search → return the
  current outer endpoint. Brent only replaces the loop between "bracket
  found" and "return `b`."
- No new dependencies. Python `edi_kernels` is expected to be unaffected
  (this kernel takes an R `Function` callback and is not `EDI_CORE_ONLY`);
  TODO-1 verifies that with a grep rather than assuming it.

---

## Design

### The Brent phase (replaces `lrt_ci_newton.cpp:269-281`)

Inputs from Phase 1: `a` (inner, `f(a) = p(a) − α > 0`), `b` (outer,
`f(b) ≤ 0`), both `p` values already evaluated (Phase 1 evaluated `p(b)`;
`p(a) = p_est` at the first step, or the last inner value if the bracket
was tightened). Standard Brent–Dekker state: `a, b, c` with `b` the current
best, `c` the previous iterate, and the bracket `[b, c]` with opposite
signs; each step tries inverse quadratic interpolation (three distinct
points) or secant (two), accepts it if it lands inside the bracket and
shrinks fast enough, otherwise bisects. Stop when `|b − c| < tol` or after
`max_iter` evaluations.

Two EDI-specific rules layered on the textbook loop:

1. **Non-finite `p`** at any trial point: stop and return the current
   outer endpoint — identical to today's `if (!R_finite(p_mid)) break;`.
2. **Return convention**: on exit, return whichever of the two bracket
   endpoints has `f ≤ 0` (the `p ≤ α` side). Brent's "best" `b` may sit on
   either side; returning the `p ≤ α` endpoint keeps the bound conservative
   and matches bisection's `ci[dir_idx] = b` exactly.

### Signature change

```cpp
NumericVector pval_invert_ci_cpp(Function pval_fn, double est, double alpha,
    double step, double lower_seed, double upper_seed,
    int max_bracket = 60, int max_bisect = 60, double tol = 1e-6,
    std::string method = "brent")   // new; "bisection" = today's loop verbatim
```

`max_bisect` keeps its name (it caps the Phase-2 loop for either method)
so the R caller at `inference_ext_ci_inversion.R:99-106` needs no change
beyond optionally passing `method`. The result gains an attribute
`n_evals` (integer, total `pval_fn` calls including Phase 1) so the
evaluation-count test below reads it directly instead of instrumenting the
callback.

---

## Implementation TODOs

### TODO-1: Baseline + failing tests

**Files:**
- Test: `R/EDI/tests/testthat/test-brent-ci-inversion.R` (new)
- Fixture: `R/EDI/tests/testthat/fixtures/brent_ci_inversion_baseline.rds` (new)

- [ ] **Step 1: Verify the Python binding is unaffected** —
  `grep -rn "pval_invert_ci\|lrt_ci_newton" python/src/` must return
  nothing; if it does not, add a binding-update step to TODO-2 before
  proceeding.
- [ ] **Step 2: Record the baseline.** With the current build
  (`pkgload::load_all("R/EDI", compile = FALSE)`), build three inference
  objects that exercise the three testing types through
  `invert_test_pval_confidence_interval()` — copy the fixture construction
  verbatim from `tests/testthat/test-bartlett-lr-ols-exact.R` (Bartlett
  path), `tests/testthat/test-incidence-probit.R` (score path), and any
  test that calls `set_testing_type("gradient")` (grep
  `tests/testthat` for it; if none exists, use the probit fixture with
  `set_testing_type("gradient")`). For each, save `compute_confidence_interval(alpha = 0.05)`
  to the fixture `.rds`, and also save the direct `pval_invert_ci_cpp()`
  output for a hand-built `pval_fn` (below) so the kernel is tested
  without the whole class stack.
- [ ] **Step 3: Write the failing tests:**

```r
library(testthat)
library(EDI)

# A smooth, monotone-on-each-side p(delta) with a known root, no model needed:
# two-sided normal p-value for an estimate of 1 with SE 0.5.
make_pval_fn = function(est = 1, se = 0.5) function(delta) 2 * stats::pnorm(-abs((est - delta) / se))
counting_pval_fn = function(f) { n = 0L; list(fn = function(d) { n <<- n + 1L; f(d) }, count = function() n) }

test_that("brent and bisection agree within tol on a known root", {
	f = make_pval_fn()
	bis = pval_invert_ci_cpp(f, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_, method = "bisection")
	brt = pval_invert_ci_cpp(f, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_, method = "brent")
	expect_equal(brt, bis, tolerance = 1e-6)
	expect_equal(as.numeric(brt), 1 + c(-1, 1) * stats::qnorm(0.975) * 0.5, tolerance = 2e-6)
})

test_that("brent uses materially fewer p-value evaluations than bisection", {
	cb = counting_pval_fn(make_pval_fn()); cbr = counting_pval_fn(make_pval_fn())
	invisible(pval_invert_ci_cpp(cb$fn,  est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_, method = "bisection"))
	invisible(pval_invert_ci_cpp(cbr$fn, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_, method = "brent"))
	expect_lt(cbr$count(), cb$count() / 2)
	res = pval_invert_ci_cpp(make_pval_fn(), est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_)
	expect_identical(attr(res, "n_evals"), cbr$count())
})

test_that("method = 'bisection' is bit-for-bit the pre-change kernel", {
	base = readRDS(test_path("fixtures", "brent_ci_inversion_baseline.rds"))
	res = pval_invert_ci_cpp(make_pval_fn(), est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_, method = "bisection")
	expect_identical(as.numeric(res), base$kernel_bisection)
})

test_that("degenerate branches are unchanged under brent", {
	f = make_pval_fn()
	expect_identical(as.numeric(pval_invert_ci_cpp(function(d) NA_real_, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_)), c(NA_real_, NA_real_))
	pt = pval_invert_ci_cpp(function(d) 0.01, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_)
	expect_identical(as.numeric(pt), c(1, 1))
	# non-finite p mid-search: returns the current outer endpoint, never errors
	flaky = function(d) if (abs(d - 1) > 0.9 && abs(d - 1) < 1.1) NaN else f(d)
	expect_true(all(is.finite(as.numeric(pval_invert_ci_cpp(flaky, est = 1, alpha = 0.05, step = 0.25, lower_seed = NA_real_, upper_seed = NA_real_)))))
})

test_that("score, gradient, and Bartlett CIs through the class stack are within tol of baseline", {
	base = readRDS(test_path("fixtures", "brent_ci_inversion_baseline.rds"))
	# <construct the three inference objects exactly as in Step 2>
	expect_equal(inf_score$compute_confidence_interval(alpha = 0.05),    base$score,    tolerance = 1e-6)
	expect_equal(inf_gradient$compute_confidence_interval(alpha = 0.05), base$gradient, tolerance = 1e-6)
	expect_equal(inf_bartlett$compute_confidence_interval(alpha = 0.05), base$bartlett, tolerance = 1e-6)
})
```

  Replace `<construct ...>` with the fixture code copied in Step 2.
- [ ] **Step 4: Run to confirm failure** — `unused argument (method = "brent")`.
- [ ] **Step 5: Commit the tests + fixture** — `git commit -m "test(brent-ci): baseline fixture and failing tests for the score/gradient/Bartlett inverter"`.

### TODO-2: Implement Brent in `pval_invert_ci_cpp`

**Files:**
- Modify: `R/EDI/src/lrt_ci_newton.cpp:192-290` (roxygen + body)

- [ ] **Step 1:** Add the `method` argument and an `int n_evals` counter
  incremented inside `eval_p` (and for the `p_est` call). Keep Phase 1
  verbatim.
- [ ] **Step 2:** Wrap today's Phase-2 loop in `if (method == "bisection") { … }`
  unchanged. Add the `else` branch:

```cpp
// Brent–Dekker on f(delta) = p(delta) - alpha over the Phase-1 bracket.
// a: inner (f > 0), b: outer (f <= 0). Both p-values already known.
double fa = p_a - alpha, fb = p_b - alpha;      // p_a = p(est) or last inner value; p_b from Phase 1
double c = a, fc = fa, d = b - a, e = d;
for (int k = 0; k < max_bisect; ++k) {
	if ((fb > 0.0) == (fc > 0.0)) { c = a; fc = fa; d = b - a; e = d; }
	if (std::abs(fc) < std::abs(fb)) { a = b; b = c; c = a; fa = fb; fb = fc; fc = fa; }
	const double tol1 = 2.0 * DBL_EPSILON * std::abs(b) + 0.5 * tol;
	const double xm = 0.5 * (c - b);
	if (std::abs(xm) <= tol1 || fb == 0.0) break;
	if (std::abs(e) >= tol1 && std::abs(fa) > std::abs(fb)) {
		double s = fb / fa, p, q;
		if (a == c) { p = 2.0 * xm * s; q = 1.0 - s; }               // secant
		else { const double qq = fa / fc, r = fb / fc;              // inverse quadratic
		       p = s * (2.0 * xm * qq * (qq - r) - (b - a) * (r - 1.0));
		       q = (qq - 1.0) * (r - 1.0) * (s - 1.0); }
		if (p > 0.0) q = -q; else p = -p;
		if (2.0 * p < std::min(3.0 * xm * q - std::abs(tol1 * q), std::abs(e * q))) { e = d; d = p / q; }
		else { d = xm; e = d; }
	} else { d = xm; e = d; }
	a = b; fa = fb;
	b += (std::abs(d) > tol1) ? d : (xm > 0.0 ? tol1 : -tol1);
	const double pb = eval_p(b);
	if (!R_finite(pb)) break;                                       // identical to today's break
	fb = pb - alpha;
}
// return the p <= alpha endpoint (conservative side), as bisection does
ci[dir_idx] = (fb <= 0.0) ? b : c;
```

  (`#include <cfloat>` for `DBL_EPSILON`. `p_a` must be tracked through
  Phase 1: it is `p_est` unless the Wald-seed/exponential search moved
  `a`, which today's code never does — `a` stays `est` — so `p_a = p_est`.)
- [ ] **Step 3:** Set `res.attr("n_evals") = n_evals;` before returning.
  Update the roxygen: title "bracket search + Brent (default) or bisection,"
  document `method` and the `n_evals` attribute, keep `@keywords internal`.
- [ ] **Step 4:** `Rcpp::compileAttributes("R/EDI")`; **targeted compile**
  of `lrt_ci_newton.cpp` + `RcppExports.cpp`; relink;
  `pkgload::load_all("R/EDI", compile = FALSE)`.
- [ ] **Step 5:** Run `test-brent-ci-inversion.R` → all PASS. Then run the
  eight existing files that exercise these CIs (`test-bartlett-lr-ols-exact.R`,
  `test-extracted-likelihood-mixin-public-contracts.R`,
  `test-incid-kk-cond-logit-onelik-fit-acceptance.R`,
  `test-incid-risk-diff-migration-golden.R`, `test-incidence-probit.R`,
  `test-kk-ols-se.R`, `test-smart-start-warm-paths.R`,
  `package_tests/testthat_bulk/test-bartlett-lr-logit.R`) → all PASS. Any
  golden that compares a CI bound more tightly than `1e-6` will need its
  tolerance set to `1e-6`, with a one-line comment citing this plan — a
  tighter-than-`tol` golden was over-specifying the bisection path, not
  the answer.
- [ ] **Step 6: Commit** — `git commit -m "perf(brent-ci): Brent's method replaces bisection in pval_invert_ci_cpp (score/gradient/Bartlett CIs)"`.

### TODO-3: Record the evaluation-count win + close out

- [ ] **Step 1:** On the three class-stack fixtures from TODO-1, record
  `attr(., "n_evals")` for both methods (call the kernel directly with the
  class's `pval_fn` closure — it is the `pval_fn` local at
  `inference_ext_ci_inversion.R:15-30`) and paste a three-row table
  (fixture, bisection evals, Brent evals, ratio) into this file under
  "Results".
- [ ] **Step 2:** Update `algorithm_choice_audit.md → row M` and its
  speedup table with the measured ratio, replacing the "~3–5×" estimate.
- [ ] **Step 3:** `NEWS.md` one-liner: "Score, gradient, and
  Bartlett-corrected LR confidence intervals now invert with Brent's
  method instead of bisection (~N× fewer refits; bounds unchanged within
  `1e-6`)."
- [ ] **Step 4: Commit** — `git commit -m "docs(brent-ci): measured evaluation counts, audit row, NEWS"`.

---

## Self-review (2026-09-04)

- **Spec coverage:** Brent phase → TODO-2 Step 2; `method` fallback and
  `n_evals` → TODO-2 Steps 1/3; identical degenerate branches → TODO-1 test
  4 and the "Phase 1 verbatim" rule; same-answer-within-`tol` → TODO-1
  tests 1 and 5; the LR inverter explicitly untouched.
- **Placeholders:** `<construct …>` in TODO-1 points at named fixture files
  to copy from; Step 2 names them.
- **Type consistency:** `method` (`std::string`, default `"brent"`),
  `max_bisect` (kept), `n_evals` (integer attribute) used identically in
  Design, TODO-1, TODO-2.
