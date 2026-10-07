# Canonical Parity for the Five Slow Procedure Rows: Profiles of Both Sides, What Is Borrowable, and the Gates

> **Release:** v1.1.0 (`../future_release_plans/release_v1_1_0.md → TODO-43..46`;
> 2026-10-07, user decision). Parity gates and the canonical-package
> borrowings for the five rows of the 2026-10-07 procedure table that EDI
> loses. The mechanical fixes they depend on are already planned elsewhere
> and are referenced, not duplicated: `release_v1_0_5.md → TODO-3` (OLS kernel
> wiring), `→ TODO-58` (bootstrap worker), `→ TODO-57`'s plan TODO-7 (hot
> loop), `→ TODO-62` (harness construction column), `→ TODO-64` (dead fast
> paths); `release_v1_1_0.md → TODO-40` (closed-form nulls), `→ TODO-42`
> (permutation signature). New here: the per-instance byte-compilation tax
> of R6 (TODO-46), the `fisher.test` log-density precompute (TODO-45), the
> `boot` percentile definition and per-draw warm starts (TODO-44), and the
> canonical comparators for the two randomization-CI rows (TODO-43).

Written 2026-10-07, user decision ("check to see if we can use any of the
canonical implementation code or algorithm to speed our implementation up so
we are at parity"). All measurements on the installed CRAN EDI 1.0.2, no
rebuild, at the harness's settings (`N_PROC = 1000`, `R_PERMS = 1000`,
`B_BOOT = 1000`, `B_BOOT_GLM = 500`, `N_PROC_SURV = 500`). The host was
loaded during this session (coin's total measured 3x the table's value), so
the **table totals are the reference** and the component numbers below are
used as ratios within one run.

## Licenses (what may be copied)

| Package | License | Code reuse into EDI (GPL-3) |
|---|---|---|
| `coin`, `libcoin` | GPL-2 only | **No.** Algorithms only, reimplemented. |
| `boot` | Unlimited | Yes, anything. |
| `stats` (`fisher.test`) | Part of R, GPL-2 \| GPL-3 | Yes under GPL-3, with R-core attribution. |
| `survival` (`coxph.fit`) | LGPL (>= 2) | Linking and adaptation under LGPL terms. |

## Row 1: randomization test, mean difference (table: EDI 23.2 ms, coin 13.2 ms, 0.57x)

**coin's side.** `oneway_test(distribution = approximate(nresample = 1000))`
spends most of its time in its own R layer, not in C: `Rprof` puts 92% under
S4 `new`/`initialize` and 66% under the `ApproxNullDistribution` wrapper; the
`libcoin::LinStatExpCov` engine alone is a quarter to a third of the total
(11.3 ms vs 43.6 ms total in one run). Its asymptotic path (the default) is
closed-form moments: 0.5 ms in `libcoin`, 10.4 ms with the wrapper.

**EDI's side (one run, ms):** construction 3.3; `generate_permutations_ibcrd_cpp`
11.7 (once per design, cached); `stable_signature()` of the 8 MB double
matrix 10.5 (**every call**); `subset_permutations()` copy 5.5 (every call);
kernel on the stored double matrix 4.7 vs. 1.1 on an integer matrix (Rcpp
coerces the 8 MB `IntegerMatrix` argument per call); fresh object + p-value
22.9 (= the table's 23.2). A repeat call is 22 ms and is 92% hashing
(`serialize` 71% + `digest` 21%), because the cache *key* must be rebuilt to
find the cached distribution.

**Borrowable from coin:** nothing. Its code is GPL-2 and its engine is slower
than EDI's generation + kernel (p. `permutation_signature_once.md`). Its
*design* is already covered: return statistics, never re-hash the permutation
set (`→ TODO-42`); offer the closed-form moments as the default-speed path
(`→ TODO-40`'s `"asymptotic_null"`).

**Parity arithmetic.** After `→ TODO-42`: 3.3 + 11.7 + 1.1 ≈ 16 ms fresh (coin
13 ms) and ≈ 1 ms on any repeat (coin has no cache; every CI bisection step
pays 13 ms there and 1 ms here). After `→ TODO-40`: the moments-based p-value
is construction + 0.1 ms vs. coin's 10 ms asymptotic.

## Rows 2–4: nonparametric percentile bootstrap CIs (table: OLS 0.094x, logistic 0.86x, Cox 0.42x of `boot`)

**Per draw, both sides (one run, ms, both including the same row subset):**

| | `boot`'s statistic | EDI kernel | EDI R6 worker |
|---|---|---|---|
| OLS, n = 1000 | `lm.fit` 0.305 | `fast_ols_cpp` 0.275 | 3.5 |
| logistic, n = 1000 | `glm.fit` 4.20 | `fast_logistic_regression_cpp` 0.43 cold, 0.39 warm | 3.5 |
| Cox, n = 500 | `coxph.fit` 0.87 | `fast_coxph_regression_cpp` 0.75 | 3.4 |

The kernels are at or ahead of `boot`'s statistics on every row (10x on
logistic). The R6 worker adds about 3.1–3.2 ms per draw on every row, which
`bootstrap_worker_dataframe_subsetting.md` (`→ TODO-58`) root-causes: data.frame
row subsetting with `make.unique`, model-matrix rebuild, R-level `qr()`,
per-draw `tryCatch`. **This per-draw cost is independent of the byte
compiler**: measured 3.49 ms/draw with JIT on and 3.51 with JIT off (OLS),
3.48 vs 3.53 (logistic), fresh object per timing, two repeats each.

**Fixed cost per fresh object** (intercept of the same fits): 60–150 ms,
of which the JIT accounts for roughly 50–90 ms (see TODO-46). Visible in
the Cox row (616 ms total) but not decisive; the per-draw overhead is.

**Measurement caution (found the hard way):** EDI caches the bootstrap
distribution per object and `B`; identical repeated calls return in 1–2 ms
after the second call, and a `B` different from the cached one recomputes
from scratch. Any timing loop must use a fresh object per repetition, as the
harness already does.

**Borrowable from `boot` (license: Unlimited):**
- its structure: one index matrix up front, a stateless statistic closure
  over matrices, no object state between draws (this is what `→ TODO-58`
  and `→ TODO-3` converge on);
- `boot.ci(type = "perc")`'s endpoint definition, `norm.inter()`
  (interpolation on the normal-quantile scale). EDI uses
  `quantile(type = 8)`; adopting `norm.inter` (copy permitted) makes EDI's
  percentile endpoints reproduce `boot`'s exactly, which matters for parity
  *of results* in the table's footnotes.

**Parity arithmetic after `→ TODO-58` + `→ TODO-3`:** OLS 1000 × 0.275 ≈
275 ms vs `boot` 167–289 (parity; the batched
`compute_ols_bootstrap_parallel_cpp` row is already 9x `boot`); logistic
500 × 0.39 ≈ 195 ms vs 755 (3.9x); Cox 500 × 0.75 ≈ 375 ms vs 260–510
(parity).

## Row 5: Zhang exact CI (table: EDI 2.44 ms, `fisher.test(conf.int)` 0.96 ms, 0.39x)

**Both sides (one run, ms):** `fisher.test` 2.8; EDI `compute_exact_confidence_interval()`
on an existing object 2.1 (about 14 evaluations of `zhang_exact_fisher_pval_cpp`
at 0.155 each); EDI construction 1.4–1.6. The inversion itself is at parity or
faster; the row's deficit is construction plus first-call compilation
(`→ TODO-62` separates them in the table; TODO-46 reduces them).

**Borrowable from `stats::fisher.test` (R core, GPL-2 | GPL-3):** it computes
`logdc <- dhyper(support, m, n, k, log = TRUE)` **once per table** and
evaluates every noncentrality as `dnhyper(ncp) = exp(logdc + log(ncp) *
support)` normalized, then runs `uniroot` on the one-sided tails
(`ncp.U`, `ncp.L`). EDI's kernel (`zhang_exact_speedups.cpp:50–70`)
recomputes four `lgamma` terms per support point on every call. Precomputing
the central log-densities once per table and reusing them across the CI
search's evaluations removes the `lgamma` work (the dominant cost) from all
but the first call.

## TODOs

- [ ] TODO-1 (`→ TODO-43`): **Mean-difference randomization row at parity
  with `coin`.** Gate on the table after `→ TODO-42` and `→ TODO-40` land:
  fresh-object row ≥ 1x `coin::oneway_test(approximate)`; repeat call ≤ 2
  ms; `"asymptotic_null"` row ≥ 1x `coin` asymptotic. Also fix the two
  randomization-CI rows' comparators (see "Canonical randomization CIs"
  below): add a Wilcoxon rand-CI row against
  `coin::wilcox_test(conf.int = TRUE, distribution = approximate(...))`,
  and replace "no canonical R implementation" on the mean-difference and
  OLS rand-CI rows with the specific near-misses in the methodology text.

- [ ] TODO-2 (`→ TODO-44`): **Bootstrap rows at parity with `boot`.**
  1. Gate: after `→ TODO-58`, `→ TODO-3` and `→ TODO-57`'s TODO-7, all three
     rows ≥ 1x `boot`; logistic ≥ 3x.
  2. Warm-start every per-draw logistic and Cox refit from the full-data
     fit (`warm_start_beta`, correctly sized per `→ TODO-63`); verify the
     worker already does, else add. Bit-preserving to the kernel's
     convergence tolerance; assert equality to 1e-10 against cold starts.
  3. Adopt `boot`'s `norm.inter()` percentile endpoints behind
     `type = "percentile"` (copy permitted; attribute) **or** document the
     `quantile(type = 8)` difference in the table footnote. Changing the
     default endpoints is a documented default change; prefer an
     `interpolation =` argument defaulting to the current behavior.
  4. Record the per-class fixed cost (fresh object → first draw) in the
     harness's construction column (`→ TODO-62`).

- [ ] TODO-3 (`→ TODO-45`): **Zhang exact CI at parity with `fisher.test`.**
  1. Gate: CI work (existing object) ≤ 1x `fisher.test(conf.int = TRUE)`,
     already true; whole row within 1.5x once `→ TODO-62` reports
     construction separately.
  2. Precompute the central log-densities once per table in
     `zhang_exact_speedups.cpp` (a small struct cached per table on the
     R6 object, or a kernel taking the precomputed vector) and evaluate
     each noncentrality as in `fisher.test`. Tolerance-equal to 1e-12
     (summation order), the documented exception in the standing
     constraint; test against the current kernel on 200 random tables.
  3. Compare evaluation counts: EDI's bisection on the two-sided p-value
     (~14) vs. `fisher.test`'s two `uniroot` calls on the one-sided tails;
     adopt the cheaper search if it reproduces the current interval to
     1e-10.

- [ ] TODO-4 (`→ TODO-46`): **R6 construction and the per-instance
  byte-compilation tax (cross-cutting).**
  Facts measured 2026-10-07: `InferenceContinOLS` instances carry 398
  function bindings (329 methods on the generator); a synthetic R6 class
  with 329 trivial methods instantiates in 1.6 ms, `InferenceContinOLS` in
  4.7, `InferenceAllSimpleAverageDiff` 3.3, `InferenceIncidExactZhang` 1.4.
  **R6's environment rebinding discards bytecode** (`environment<-` on a
  compiled closure returns an uncompiled one; verified directly), so every
  instance starts with 0 of its 398 methods compiled, and R's JIT
  recompiles each on first use, per instance and per duplicated worker.
  Pre-compiling the generator's method lists does not help for the same
  reason. Measured per-fresh-object cost in the bootstrap paths: 60–150 ms
  with JIT on vs 40–65 ms with JIT off; `InferenceSuite$run_all_inference()`
  over ~90 classes pays this ~90 times.
  1. Measure per class: construction, first-call compile, first draw.
  2. Make `Inference$initialize()`'s per-instance checks per-class
     (`apply_inference_design_restrictions`, `assertClass`/`qassert`,
     `edi_cold_start_dispatch_policy`, the `grepl` scans: 60% of Zhang's
     construction) by caching their results on the generator.
  3. *(decision-gated, architectural)* Thin methods: have
     `define_inference_class()` emit R6 methods of the form
     `function(...) .impl_name(self, private, ...)` whose bodies are
     compiled namespace-level functions, so the per-instance closures are
     trivial and the hot code is compiled once at install. Prototype on one
     class; measure; decide.
  4. Persistent compiled workers: keep the reusable-worker state on the
     object across resampling calls instead of re-duplicating (the
     `duplicate()` → rebinding → recompile chain) when `B`/`r` changes.

## Canonical randomization CIs: what exists (answer to the 2026-10-07 question)

Checked on this machine for the two "no canonical R implementation" rows:

| Candidate | Result at n = 1000 |
|---|---|
| `coin::oneway_test(conf.int = TRUE)` | **Errors**: "cannot compute confidence interval for objects of class ScalarIndependenceTest". coin's CIs exist only for its rank tests. |
| `coin::wilcox_test(conf.int = TRUE, distribution = approximate(nresample = 1000))` | Works: a randomization CI for the Wilcoxon shift, **147 s** (re-runs the Monte Carlo at every inversion step). EDI's `InferenceAllSimpleWilcox` rand CI: 17 s. A fair new row; EDI wins 8.5x and is itself slow. |
| `coin::wilcox_test(conf.int = TRUE, distribution = "asymptotic")` | 394 ms, but not randomization-based. |
| `exactRankTests::perm.test(conf.int = TRUE, exact = TRUE)` | Exact shift CI for the mean difference via the shift algorithm: 1.9 s at n = 60, **infeasible at n = 1000** (killed after 10 min). `exact = FALSE` gives no CI ("cannot compute asymptotic confidence intervals"). The small-n comparator for `→ TODO-41`. |
| `perm::permTS` | `p.conf.int` is a CI for the Monte Carlo p-value, not for the effect. |
| `ri2::conduct_ri(sharp_hypothesis = ...)` | One hypothesis per arm, not a grid: "supply one per treatment condition minus 1". A CI needs a manual loop of full runs. |
| `lmPerm`, `permuco` | Permutation p-values for regression coefficients, no CI (not installed here). |
| `MKinfer::perm.t.test`, `randomizationInference` | Not installed; not verified. |

Conclusion: for the mean difference at n = 1000 there is no practical
canonical randomization CI, and for the covariate-adjusted OLS there is none
at all. The rows' "None" is correct; the methodology text should say why,
and a Wilcoxon rand-CI row against `coin::wilcox_test(conf.int = TRUE)`
should be added (TODO-1).

## Out of scope

- The design-generation rows (`→ TODO-59..61`).
- `InferenceAllSimpleWilcox`'s own 17 s rand CI (Hodges–Lehmann per
  permutation; `→ TODO-41` gives it an exact small-n path).
- Replacing R6.
