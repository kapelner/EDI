# Algorithm A/B Testing Framework

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Depends on:** none to read. **Depended on by:** every "Prototype" row in
> `algorithm_choice_audit.md`, specifically `garthwaite_buckland_ci_search.md`
> and `em_algorithm_zero_inflated_mixtures.md` in this initial batch. Release:
> v1.1.0, alongside `algorithm_choice_audit.md`'s items
> (`release_v1_2_0.md → TODO-21`; moved from `release_v1_1_0.md →
> TODO-17t` on 2026-09-06, lighten-1.1.0 pass, user decision — the
> survey half, `algorithm_choice_audit.md`, stayed in v1.1.0; this
> harness and its two gated Prototype items moved). Not gated on any
> Phase 0 decision.

**Goal:** A reusable, maintainer-run benchmark harness that decides — with
paired timing comparisons and a formal statistical-equivalence check, on a
representative-plus-adversarial synthetic corpus — whether a candidate
algorithm should replace, sit alongside as an opt-in, or be rejected against
EDI's current default for a given kernel, and produces a written report a
human reads before flipping any default.

**Architecture:** Three pieces. (1) A **corpus generator**
(`R/EDI/tests/algorithm_ab/corpus.R`) producing named synthetic datasets
spanning the axes that make an algorithm's relative performance flip (`n`,
`p`, signal strength, contamination fraction, zero-inflation fraction,
censoring rate, imbalance, near-collinearity). (2) A **harness**
(`R/EDI/tests/algorithm_ab/harness.R`) that takes two callables (baseline,
candidate) implementing a common interface for a given kernel, runs both on
every corpus entry under machine-state-controlled, paired timing, computes a
kernel-appropriate correctness/equivalence metric, and emits a tidy results
table. (3) A **decision rule** applied to that table, producing one of
`keep | opt-in | adopt | reject`, with the threshold values fixed in
advance (never chosen after seeing the results). This is **not**
`tune_EDI_for_this_machine()`: that tool tunes *performance-policy* axes
under an invariant of bit-identical results
(`local_machine_optimization.md → "Explicitly out of scope"` says so
explicitly: "Anything that changes numerical results beyond timing … must
never" be in its scope). Algorithm-choice changes are precisely the things
that *can* change numerical results (a different local optimum, a different
Monte Carlo path) — this harness is the maintainer-run, one-time validation
step that must happen *before* such a change is allowed to ship, not a
runtime tool end users invoke.

**Tech Stack:** R, `bench` (already used for benchmarking elsewhere in the
repo per `performance_profiling_and_upgrades.md`), the machine-state capture
already specified in `performance_profiling_and_upgrades.md → TODO-175`
(`benchmark/_machine_state.sh`) — reused, not reimplemented — and
`local_machine_tuning_synthetic_fixtures.R`'s existing dataset-generation
helpers as a starting point for the corpus.

**Spec:** this file, plus the equivalence-metric definitions in the "Design"
section below.

## Global Constraints

- **NEVER run a full `R CMD INSTALL` / `pkgbuild::compile_dll()` /
  `load_all()` without `compile = FALSE`** — see the repo `CLAUDE.md`. The
  harness only calls already-built kernels through their R entry points; it
  never triggers a compile itself.
- **The harness never flips a default on its own.** It produces a report;
  a human decides. No `TODO` in a plan that consumes this harness may read
  "if the harness says X, ship it" without a human review step in between.
- **Every timing comparison is paired** (same seed, same dataset, both
  algorithms, back-to-back, machine-state-checked) — never two separately
  reported numbers from different runs. Unpaired comparisons are the classic
  benchmarking mistake this framework exists to prevent.
- **"Some gain on some datasets" is the bar, not uniform dominance**
  (2026-09-03, user decision): the decision rule must not require a
  candidate to win everywhere to be worth shipping as an *opt-in*, or even
  as a *conditional default* (dispatch-policy-gated on `n`/`p`/data shape,
  exactly like `get_cold_start_dispatch_policy()`). It must, however,
  **never lose accuracy anywhere** without being flagged loudly — speed and
  correctness are not symmetric trade-offs here.
- No new package dependencies beyond `bench` (Suggests already, verify) and
  `withr` (already a dependency).

---

## Design

### D1. The corpus

`generate_algorithm_ab_corpus(problem_class, axes = "default", seed = 20260903L)`
returns a named list of datasets. `problem_class` selects which axes matter
(e.g., `"mixture_likelihood"` sweeps zero-inflation fraction; `"ci_search"`
sweeps `n`, effect size, and target `α`; `"bootstrap"` sweeps `n` and `B`).
Every entry is reproducible from its name and the seed alone (no hidden
global state), and every entry is tagged with which axis value it
represents, so a result row can be grouped by axis without re-deriving it.

Axes, by problem class (extend as new Prototype rows are added):

| axis | levels | why it matters |
|---|---|---|
| `n` | 30, 100, 500, 2000 | small-`n` finite-sample behavior vs. large-`n` asymptotics |
| `p` | 2, 10, 40 | dimension-dependent cost terms |
| signal strength | null, weak, strong | optimizer basin difficulty; CI-search step-size behavior |
| contamination fraction (outliers) | 0%, 5%, 20% | robust-regression starts, EM mixture separability |
| zero-inflation / structural-zero fraction | 0%, 20%, 60%, 90% | EM vs. joint-optimizer separation of the two components |
| censoring rate | 0%, 30%, 70% | survival-kernel-specific |
| imbalance (treatment:control ratio) | 1:1, 1:3, 1:9 | design-search and matching kernels |
| near-collinearity | none, moderate (`κ ≈ 100`), severe (`κ ≈ 10^4`) | conditioning-sensitive linear algebra, EM vs. Newton stability |
| target tolerance (`tol`, `α`) | loose, default, tight | CI-search and small-p-value candidates specifically |

Every problem class also gets **two adversarial entries by construction**,
not swept from the axes above: one designed to trap the *current* algorithm
(reusing the known failure fixtures already in the repo where they exist —
e.g. `negbin_dispersion_convergence.md`'s no-overdispersion fixture for row
B, the ordinal-GLMM near-zero-variance fixture at
`fast_ordinal_glmm.cpp:337-359`'s comment for anything variance-component
related), and one designed to be easy for both (a sanity check that the
harness itself is not broken).

### D2. The harness interface

```r
run_algorithm_ab(
  problem_class,           # e.g. "mixture_likelihood"
  baseline,                # function(dataset) -> AlgorithmResult
  candidate,                # function(dataset) -> AlgorithmResult
  equivalence_metric,        # function(baseline_result, candidate_result, dataset) -> EquivalenceRecord
  corpus = generate_algorithm_ab_corpus(problem_class),
  reps = 10L,               # paired repetitions per corpus entry, for timing noise
  machine_state = capture_machine_state()  # from performance_profiling_and_upgrades.md TODO-175's script
)
```

`AlgorithmResult` is a small list every candidate function must return:
`list(value, converged, iterations, wall_time_s)` — `wall_time_s` is
measured *inside* the harness via `bench::mark()` around the call, not
self-reported, so `value`/`converged`/`iterations` are the only fields the
candidate function computes itself.

`EquivalenceRecord` is `list(metric_name, baseline_value, candidate_value,
difference, within_tolerance, tolerance_used)` — the metric is
**problem-class-specific**, not a single generic number, because "are these
two answers the same" means different things per row:

| problem class | equivalence metric |
|---|---|
| mixture likelihoods (row B) | `\|neg-loglik_candidate − neg-loglik_baseline\|`; candidate must never be *worse* by more than a fixed `ε`, and is credited for being *better* (lower) |
| CI search (row D) | coverage and mean CI width under repeated simulation at a fixed `n`/effect-size cell (paired, same underlying data-generating process, many replications) — not a single-dataset point comparison, since the object being validated is a *procedure's* long-run behavior |
| small p-values (row E) | max absolute difference between the candidate's p-value and an exact-enumeration or large-`B` Monte Carlo reference, across the statistic's whole support — this is the row where "equivalence" is the entire point, not a secondary check |
| bootstrap resampling (row J) | Monte Carlo variance of the resulting CI bound at fixed `B`, compared across many independent corpus draws (candidate must reduce variance, not just match the point estimate) |

Each new Prototype row that adopts this harness defines its own metric
function in `R/EDI/tests/algorithm_ab/metrics.R` before running anything —
this is a design decision made once per problem class, not something the
harness infers.

### D3. The decision rule

Fixed **in advance**, per problem class, before results are seen (write the
thresholds into the row's own plan — `garthwaite_buckland_ci_search.md` and
`em_algorithm_zero_inflated_mixtures.md` do this in their own Design
sections). The generic shape:

1. **Correctness gate (must pass everywhere in the corpus, no exceptions):**
   every corpus entry's `equivalence_metric$within_tolerance` is `TRUE`.
   A single `FALSE` fails the candidate outright for **default** adoption
   (it may still be worth shipping as an explicit opt-in with a
   documentation caveat — that is a human judgment call the report
   surfaces, not something the harness decides).
2. **Speed gate (the "some gain on some datasets" bar):** using a paired
   Wilcoxon signed-rank test (not a raw mean, which one slow outlier
   dominates) on `wall_time_s` across the `reps` repetitions **within each
   corpus entry**, count how many corpus entries show `candidate` faster
   at `p < 0.05` after a Holm correction across entries. The candidate
   clears the speed gate if this count is `> 0` — i.e., a genuine,
   statistically supported win on **at least one** documented regime, which
   is the bar the user set, not uniform dominance. The report **always**
   states which regimes won, which lost, and which were a wash, in a table
   — a single passing entry produces a *narrow, explicit* recommendation
   ("adopt for `n > 500` with `>50%` structural zeros"; not "adopt").
3. **Regression floor:** even on corpus entries where the candidate is
   slower, it must not be *pathologically* slower (default floor: no more
   than 3× the baseline's wall time) — a candidate that wins big in one
   regime and is catastrophic in another is an opt-in at best, never a
   default, regardless of gate 2.
4. **Output:** `keep` (gate 1 or 2 failed) / `opt-in` (gate 1 passed, gate 2
   passed narrowly or gate 3 failed somewhere) / `adopt-conditional` (gates
   1–3 passed on a well-defined sub-region of the corpus — becomes a
   dispatch-policy entry, exactly like `get_cold_start_dispatch_policy()`)
   / `adopt-default` (gates 1–3 passed everywhere). No row in this initial
   batch is expected to reach `adopt-default` on a first pass; that is a
   feature of an honest harness, not a bug in this plan.

### D4. The report

`render_algorithm_ab_report(results, problem_class)` writes a single
markdown file (`R/package_metadata/audits/algorithm_ab_<problem_class>_<date>.md`)
with: the machine-state capture, the corpus definition used, a table of
every corpus entry × its correctness verdict × its paired-timing verdict,
the Holm-corrected count from gate 2, and the resulting recommendation
sentence. This is the artifact a human reads before touching a default;
every Prototype-row plan's "close-out" TODO produces one of these and links
it from `algorithm_choice_audit.md`'s summary table.

---

## Implementation TODOs

### TODO-1: Corpus generator skeleton + one problem class end-to-end

**Files:**
- Create: `R/EDI/tests/algorithm_ab/corpus.R`
- Create: `R/EDI/tests/algorithm_ab/harness.R`
- Test: `R/EDI/tests/testthat/test-algorithm-ab-corpus.R`

**Interfaces:**
- Produces: `generate_algorithm_ab_corpus(problem_class, axes = "default", seed = 20260903L)` → named list of datasets, each tagged `list(data = ..., axis_values = list(...), label = "...")`.
- Produces: `run_algorithm_ab(problem_class, baseline, candidate, equivalence_metric, corpus, reps, machine_state)` → a tibble/data.frame with one row per `(corpus entry, rep)`.

- [ ] **Step 1: Write the failing test** for the `"mixture_likelihood"` problem class (the smallest concrete case, reusing `fast_zinb.cpp`-shaped data):

```r
library(testthat)
library(EDI)

test_that("the mixture_likelihood corpus covers every declared axis level exactly once per combination it claims", {
	corpus = generate_algorithm_ab_corpus("mixture_likelihood", seed = 1L)
	expect_true(length(corpus) >= 2L)  # at minimum the two adversarial entries
	labels = vapply(corpus, function(e) e$label, character(1))
	expect_true(any(grepl("adversarial_trap_current", labels)))
	expect_true(any(grepl("adversarial_easy", labels)))
	zi_fracs = vapply(corpus, function(e) e$axis_values$zero_inflation_fraction %||% NA_real_, numeric(1))
	expect_true(all(c(0, 0.2, 0.6, 0.9) %in% zi_fracs))
})

test_that("the corpus is reproducible from its seed alone", {
	a = generate_algorithm_ab_corpus("mixture_likelihood", seed = 7L)
	b = generate_algorithm_ab_corpus("mixture_likelihood", seed = 7L)
	expect_identical(lapply(a, function(e) e$data), lapply(b, function(e) e$data))
})
```

- [ ] **Step 2: Run to confirm failure** — `could not find function "generate_algorithm_ab_corpus"`.

- [ ] **Step 3: Implement `corpus.R`.** `generate_algorithm_ab_corpus()` dispatches on `problem_class` to a per-class generator (`.generate_mixture_likelihood_corpus(axes, seed)` first; others added by later rows' plans). Each generator sweeps the axis table in D1 restricted to the axes that apply to its problem class (mixture likelihoods: `n`, zero-inflation fraction, contamination — not censoring or imbalance), builds `X`, `y` via `withr::with_seed(seed + offset, ...)` per entry so entries are independent and reproducible, and adds the two adversarial entries by construction (for `mixture_likelihood`: `adversarial_trap_current` = a Poisson-only draw with no injected excess zeros or overdispersion, mirroring `negbin_dispersion_convergence.md`'s repro fixture; `adversarial_easy` = strong zero-inflation, strong signal, `n = 500`).

- [ ] **Step 4: Run the test to confirm it passes.**

- [ ] **Step 5: Write the harness's failing test:**

```r
test_that("run_algorithm_ab pairs timing and applies the equivalence metric per entry", {
	corpus = generate_algorithm_ab_corpus("mixture_likelihood", seed = 3L)[1:2]
	baseline_fn = function(d) {
		fit = fast_zinb_cpp(d$Xc, d$Xz, d$y)
		list(value = fit$neg_loglik, converged = isTRUE(fit$converged), iterations = fit$niter %||% NA_integer_)
	}
	candidate_fn = baseline_fn  # identity candidate: must show zero difference, used as a harness self-test
	eq_metric = function(base_res, cand_res, dataset) {
		diff = abs(cand_res$value - base_res$value)
		list(metric_name = "neg_loglik_diff", baseline_value = base_res$value,
		     candidate_value = cand_res$value, difference = diff,
		     within_tolerance = diff < 1e-6, tolerance_used = 1e-6)
	}
	res = run_algorithm_ab("mixture_likelihood", baseline_fn, candidate_fn, eq_metric,
	                        corpus = corpus, reps = 3L, machine_state = list())
	expect_true(all(res$within_tolerance))
	expect_true(all(c("wall_time_s_baseline", "wall_time_s_candidate") %in% names(res)))
	expect_identical(nrow(res), length(corpus) * 3L)
})
```

- [ ] **Step 6: Run to confirm failure.**

- [ ] **Step 7: Implement `harness.R`.** `run_algorithm_ab()` loops corpus entries × `reps`, calls `baseline`/`candidate` back-to-back per rep (alternating call order across reps to cancel any systematic warm-cache advantage — reps 1,3,5.. baseline-first, reps 2,4,6.. candidate-first), times each with `bench::mark(iterations = 1, ...)` around the call (not the candidate's self-reported time), applies `equivalence_metric` once per entry (not per rep — the answer should be deterministic given the seed; if it is not, that is itself a finding worth a warning column), and returns one row per `(entry, rep)` with columns `entry_label`, `rep`, `wall_time_s_baseline`, `wall_time_s_candidate`, plus the flattened `EquivalenceRecord` fields.

- [ ] **Step 8: Run all four tests, confirm pass.**

- [ ] **Step 9: Commit** — `git add R/EDI/tests/algorithm_ab/corpus.R R/EDI/tests/algorithm_ab/harness.R R/EDI/tests/testthat/test-algorithm-ab-corpus.R` ; `git commit -m "feat(algorithm-ab): corpus generator + harness, mixture_likelihood problem class"`.

### TODO-2: Decision rule + machine-state integration

**Files:**
- Create: `R/EDI/tests/algorithm_ab/decision.R`
- Modify: `R/EDI/tests/algorithm_ab/harness.R` (wire `capture_machine_state()`)
- Test: `R/EDI/tests/testthat/test-algorithm-ab-decision.R`

**Interfaces:**
- Consumes: the `run_algorithm_ab()` output table (D2/TODO-1).
- Produces: `decide_algorithm_ab(results, speed_alpha = 0.05, regression_floor = 3.0)` → `list(verdict, per_entry_table, winning_regimes, losing_regimes)`, `verdict ∈ {"keep","opt-in","adopt-conditional","adopt-default"}`.

- [ ] **Step 1: Write the failing tests** — three synthetic result tables built by hand (not via the harness, to isolate the decision logic): one where the candidate is uniformly faster and always within tolerance (`expect_identical(verdict, "adopt-default")`), one where it is faster on exactly one entry and within tolerance everywhere (`expect_identical(verdict, "adopt-conditional")` with `winning_regimes` naming that one entry), one where it fails tolerance on any single entry (`expect_identical(verdict, "keep")` regardless of speed).
- [ ] **Step 2: Run to confirm failure.**
- [ ] **Step 3: Implement `decide_algorithm_ab()`** exactly per D3 (paired Wilcoxon per entry, Holm correction across entries, the 3× regression floor, the four-way verdict).
- [ ] **Step 4: Wire `performance_profiling_and_upgrades.md → TODO-175`'s `benchmark/_machine_state.sh`** as the default `machine_state` argument in `harness.R` (call it, capture its output as a list, attach to every result row) — this script already exists per that plan's spec; if TODO-175 has not landed yet when this step runs, stub `capture_machine_state()` to return `list(note = "TODO-175 not yet implemented")` rather than blocking on it, and file that as a one-line dependency note back in this plan.
- [ ] **Step 5: Run tests, confirm pass.**
- [ ] **Step 6: Commit** — `git commit -m "feat(algorithm-ab): decision rule and machine-state capture"`.

### TODO-3: Report renderer

**Files:**
- Create: `R/EDI/tests/algorithm_ab/report.R`
- Test: `R/EDI/tests/testthat/test-algorithm-ab-report.R`

- [ ] **Step 1: Failing test** — call `render_algorithm_ab_report()` on the fixtures from TODO-2, assert the output file exists, contains the verdict string, and contains one table row per corpus entry.
- [ ] **Step 2: Implement**, writing to `R/package_metadata/audits/algorithm_ab_<problem_class>_<YYYYMMDD>.md` (create the `audits/` directory if it does not exist).
- [ ] **Step 3: Run, confirm pass, commit** — `git commit -m "feat(algorithm-ab): markdown report renderer"`.

### TODO-4: Dry-run against a solved case, to validate the harness itself

**Files:**
- Test: `R/EDI/tests/testthat/test-algorithm-ab-dryrun.R`

Before any real candidate uses this harness, run it once on a **known**
comparison to check the harness produces the expected verdict — the
single-precision-vs-Huber-start question already resolved conceptually in
`multistart_nonconcave_likelihoods.md → TODO-7` is a good dry run once that
plan lands (candidate = Huber-started bisquare, baseline = OLS-started
bisquare, expect `adopt-conditional` or `adopt-default` on the contaminated
corpus entries and `keep`/no-difference on the clean ones).

- [ ] **Step 1:** implement the dry run as a test once `multistart_nonconcave_likelihoods.md → TODO-7` has landed; if it has not, use a synthetic stand-in (a deliberately-slow-but-correct baseline vs. a deliberately-fast-and-correct candidate, both hand-coded in the test) so this task is not blocked on another plan's completion.
- [ ] **Step 2:** run, confirm the verdict matches expectation, commit — `git commit -m "test(algorithm-ab): harness dry-run against a known comparison"`.

---

## Self-review (2026-09-03)

- **Spec coverage:** D1 → TODO-1; D2 → TODO-1; D3 → TODO-2; D4 → TODO-3; the "never flips a default automatically" and "paired timing" constraints are enforced structurally (decision function returns a verdict string and a report, nothing calls it and acts on the result) and validated in TODO-4.
- **Placeholders:** none — every step has literal R code, not a description.
- **Type consistency:** `AlgorithmResult` (`value`, `converged`, `iterations`, `wall_time_s`) and `EquivalenceRecord` (`metric_name`, `baseline_value`, `candidate_value`, `difference`, `within_tolerance`, `tolerance_used`) are used identically in D2, TODO-1, and TODO-2.
