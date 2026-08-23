# Contract: Creating a New Inferential Model

Date: 2026-08-12 (updated 2026-08-23: `fix_inference_hierarchy.md` and
`fix_documentation.md` are both finished, so the "migration in progress"
caveats below are gone and the registry mechanics are described as they
actually are).

This is the end-to-end contract for adding a new `Inference*` model to EDI.
A new model is not "done" when its point estimate is correct. It is done when
every section below is satisfied: capability metadata, argument checking,
documentation, unit and integration tests, C++ core hygiene and profiling,
the R/Python core split, Python bindings and docs, benchmarking (including
cold/warm starts where applicable), and registration in the comprehensive
test harness and path audits.

Companion documents (read them; this contract references but does not repeat
them):

- `package_metadata/finished_features/fix_inference_hierarchy.md` — the class
  architecture, metadata, components, capabilities, and Source Invariants.
  **Done (2026-08-23): 0 open items, moved to `finished_features/`.** Every
  concrete inference class is factory-built; the legacy algorithmic ladder
  is retained only as internal component sources with zero concrete
  descendants; raw component splicing and component redeclaration of
  root-owned state are banned by guardrail tests and factory validation.
- `package_metadata/finished_features/fix_documentation.md` — the
  documentation standard every new roxygen block must meet. **R-side TODOs
  done (2026-08-23): 0 open, moved to `finished_features/`.** Still apply
  its Documentation Standard/General Instructions to any new class; the
  Python-docstring TODOs (#758-#816) are now unblocked (each depended only
  on its R sibling's expanded documentation existing) and remain the only
  open item in `_master.md` Phase 3.
- `package_metadata/new_feature_plans/python_bindings_package_spec.md` —
  Python bindings design, kernel scope, and baseline-benchmark methodology.
- `package_metadata/new_feature_plans/cold_starts.md` and
  `package_metadata/audits/warm_starts.html` — smart-start
  heuristics and their benchmarks.

---

## 1. Capabilities and Categorization

New classes follow the shallow-hierarchy architecture in
`fix_inference_hierarchy.md`. Do not add a new class by inheriting from an
algorithmic base (`InferenceRand`, `InferenceAsympLikStdModCache`, etc.);
those bases are being drained and deleted.

**Current state (2026-08-23): the migration is complete.** Every concrete
class is a `define_inference_class()` call (any of them is a valid template;
`InferenceCountQuasiPoisson`, `InferenceAllSimpleWilcox`,
`InferenceIncidLogRegr`, `InferenceSurvivalKKLWACoxPHOneLik` are compact
examples of, respectively, quasi-likelihood, no-likelihood, full-likelihood
GLM, and KK partial-likelihood classes). The only non-factory `Inference*`
generators left are the retained legacy ladder (`EDI_INFERENCE_ABSTRACT_CLASS_NAMES`
minus the root), kept purely as component sources and golden-test fixtures;
the few `R6::R6Class("InferenceXxx", ...)` definitions you will still see at
the top of some files are in-file *component sources* that the following
`define_inference_class()` call composes, not templates. Never add a class
that inherits from the ladder, never re-create a `supports_*()` flag pair,
and never splice a component's `$public`/`$private` lists by hand — all
three are enforced (`test-static-cleanup-guardrails.R`,
`test-inference-class-registry.R`, factory validation).

### 1.1 Class identity

- Parent is `Inference`, or an estimator-family base only when every child is
  substitutable for that parent *as the same kind of estimator*. Never
  inherit to acquire an optional algorithm (bootstrap, randomization, Wald,
  likelihood tests, KK pass-through, GEE, GLMM, caches).
- Define the class through `define_inference_class()` (defined in
  `EDI/R/contracts_mixins.R`; component specs in `EDI_COMPONENT_SPECS` in
  the same file; registry helpers in `EDI/R/inference_class_registry.R`) so
  contracts are validated at definition time. Its actual signature is
  `define_inference_class(classname, inherit, components, public, private,
  active, metadata, overrides, public_methods_for_capability,
  lock_objects = FALSE, ...)` — note `classname`/`inherit`, not the
  `name`/`parent` spelling used in `fix_inference_hierarchy.md`'s
  illustrative sketch, and `lock_objects = FALSE` is enforced. `components`
  lists only what the class adds (a component's declared dependencies are
  resolved for you; listing a dependency alongside the component that pulls
  it in is an error); `metadata$likelihood_tier` (and
  `metadata$capabilities` when a capability such as `"likelihood_ratio"` is
  not provided by any composed component) feed the capability-table
  validation; `overrides` must name every intentional public/private
  collision. Raw component splicing outside the factory is forbidden, and a
  component's `owns_state` may never contain root-owned private fields
  (`m`, `X`, `w`, `y`, `dead`, `y_temp`, `any_censoring`, `optimization_alg`,
  `cached_vc_params`, …) — declare those in `requires_state`; the factory
  rejects both. If the class needs a new component (a per-model
  `*Likelihood` source is the usual case), define it as a plain
  `XxxSource = list(public = list(...), private = list(...))` literal in the
  class's file, register a spec in `EDI_COMPONENT_SPECS`, and let only the
  factory consume it (a `*Source` may be referenced by name only from the
  registry or its own file). The factory resolves `inherit` eagerly, so a
  class whose parent is defined in another file must come after it in
  `DESCRIPTION`'s `Collate`.

### 1.2 Metadata record (mandatory, immutable)

Exactly one metadata record per class lives in `EDI_INFERENCE_CLASS_REGISTRY`
(validated by `validate_inference_class_metadata()`,
`EDI/R/inference_class_registry.R`). It is **not** registered by the factory
call: `populate_inference_class_registry()` scans the package namespace at
load time and builds the record from the generator plus a set of lookup
tables in that file, so a new class must feed every one of them (the
registry/manifest tests fail otherwise):

- `response_types` — inferred from the **class-name prefix**
  (`InferenceContin*`/`InferenceBai*` → continuous, `InferenceCount*`,
  `InferenceIncid*`, `InferenceOrdinal*`, `InferenceProp*`,
  `InferenceSurvival*`, `InferenceAll*` → every type). A class named outside
  that convention gets no response types and is never discovered;
- `likelihood_tier` — inferred from name tokens
  (`infer_inference_likelihood_tier()`: `GEE|Quasi|Robust|Composite` →
  quasi, `Cox|CondLogit|CondAdjCat|LWA` → partial, the GLM/AFT/GLMM/CLMM
  token list → full, otherwise none). Name the class so the inferred tier
  equals the `metadata$likelihood_tier` you pass to the factory; if no
  existing token fits, add one to that function in the same change;
- `direct_components` — add an entry to the `infer_inference_direct_components()`
  switch that **mirrors the factory's `components =` vector exactly**;
- `abstract` — any name containing `Abstract` (or listed in
  `EDI_INFERENCE_ABSTRACT_CLASS_NAMES`) is abstract and excluded from
  discovery; concrete classes must not use that token;
- `estimand` — add the class to `EDI_INFERENCE_ESTIMAND_TAGS` (or implement
  a private `get_estimand_type()`); `adjusts_for_covariates` — add it to
  `EDI_INFERENCE_CLASSES_USING_COVARIATES` or
  `EDI_INFERENCE_CLASSES_IGNORING_COVARIATES`;
- design compatibility beyond response type — implement the private hooks
  the scan reads without instantiating: `requires_blocking_design()`,
  `supports_interval_or_left_censored_data()`, and, for structural
  requirements (even allocation, equal block sizes, …),
  `design_compatibility_reason(des_obj)` returning a reason string or
  `NA_character_`; KK/matching compatibility follows from composing
  `KKPassThrough`/`KKGEE`/`KKGLMM`;
- `required_packages`/optional packages — declare `optional_packages` on the
  lazily loaded component spec that needs them, so
  `Design$unavailable_inference_classes_due_to_missing_packages()` can
  report the class instead of discovery failing at construction.

The record's fields are:

- `name`, `parent`, `abstract`, `exported`;
- `response_types` — one or more of `continuous`, `incidence`, `proportion`,
  `count`, `survival`, `ordinal`;
- `design_families` — which randomization designs the estimator accepts
  (Bernoulli, complete randomization, blocking, matching/KK, cluster, …);
- `compatibility` — a *pure, cheap* predicate over normalized design
  metadata. No model fitting, no package probing, no constructor calls;
- `likelihood_tier` — `none`, `quasi`, `partial`, or `full`, classified by
  the **implemented objective**, not the class name;
- `direct_components` — only the components this class *adds* (parents'
  components are inherited automatically; re-listing is an error) — kept in
  lock-step with the factory call by the `infer_inference_direct_components()`
  entry above;
- `required_packages` — optional packages needed to instantiate or execute.

### 1.3 Capabilities

- Decide explicitly which optional inference paths the model supports:
  Wald/asymptotic, likelihood tests (LR/score/gradient), exact, randomization
  test and randomization CI, nonparametric bootstrap (and its typed flavors),
  randomization bootstrap, Bayesian bootstrap (all six flavors), jackknife,
  parametric likelihood bootstrap, m-out-of-n bootstrap, PRW subsampling,
  Bartlett correction.
- Every capability must be backed by the component or class hook that the
  capability table (`capability_requires`) demands — e.g.
  `parametric_likelihood_bootstrap` requires `likelihood_tier` in
  {`partial`, `full`}, `get_likelihood_test_spec`, and
  `simulate_under_lik_null`. If you cannot write a null simulator, the class
  does not get the capability.
- Public optional method presence must equal capabilities:
  `public method exists <=> capability exists <=> hook exists`. No throwing
  stubs, no `supports_*` flag pairs. Callers query
  `obj$supports("capability")` / `obj$capabilities()`.
- Heavy optional components (parametric bootstrap, GLMM plumbing, Bartlett)
  should be `lazy`-loaded; keep discovery and `supports()` metadata-only.
- Structurally unsupported paths must be *intentional and documented* (e.g.
  Bayesian bootstrap is undefined for rank statistics because fractional
  weights have no meaning for the statistic) — record the reason in the
  path-audit row `notes` (§9) and in the roxygen docs (§3).

### 1.4 Discovery

`InferenceSuite` must find the class from metadata alone: `abstract == FALSE`,
`exported == TRUE`, `required_packages` available, `compatibility(design)`
true. Verify the new class appears for compatible designs and is absent (with
the right reason) otherwise. Never make discovery depend on constructor
failures or private-method sniffing.

---

## 2. Argument Checking (asserts) Contract

### 2.1 Single-argument checks

- Every public method validates every argument with `checkmate` asserts
  (`assertCount`, `assertChoice`, `assertNumeric`, `assertFlag`,
  `assertFormula`, `assertClass`, …) or the package's domain asserts
  (e.g. `assertResponseType`). Checks are gated on `should_run_asserts()` so
  hot resampling loops can skip them.
- The assert must encode the *real* domain: positivity, integer-ness, allowed
  choice sets, `null.ok` only when `NULL` is genuinely meaningful, matrix and
  vector dimensions, factor-level and treatment-coding requirements.
- Only assertion forms recognized by
  `package_tests/extract_checkmate_argument_contracts.R` are machine-audited;
  prefer those forms so the new method's contracts land in
  `checkmate_argument_contracts.csv` automatically.

### 2.2 Cross-argument (combination) checks

- Constraints that couple two or more arguments live in internal helpers in
  `EDI/R/additional_asserts.R` (e.g. `assertBootstrapArgs` enforces
  `min_number_usable_samples <= B` and type-choice sets;
  `assertFormulaContext` enforces that formula variables exist in the data).
  Add a new helper there rather than open-coding the check in each method,
  and give it a clear, actionable error message naming both arguments and
  their observed values.
- Cross-argument constraints must also be declared to the public-argument
  combination machinery: `public_argument_contract_registry.R`,
  `public_argument_combination_constraints.R`, and (when the method needs
  special construction) `public_argument_combination_fixtures.R`, all under
  `package_tests/`. The combination runner generates valid/invalid argument
  grids from these declarations; an undeclared constraint shows up as a
  spurious failure, and a declared-but-unenforced one as a missed error.
- Error semantics: invalid arguments must `stop()` with `call. = FALSE` and a
  message the combination harness can match. Nonestimability is *not* an
  argument error — it flows through `is_nonestimable()` /
  `get_nonestimable_reason()` / `get_nonestimable_stage()` and returns `NA`s
  per the package's failure-semantics conventions.

---

## 3. Roxygen Documentation Contract

Follow the full documentation standard in `fix_documentation.md` §"General
Instructions". **As of 2026-08-23 that standard *is* the state of the
existing `man/` pages** — all 821 R-side TODOs across the whole `Inference*`
family are closed — so any recently documented exported class (its class
block, `initialize`, and `compute_*` methods) is a fair exemplar of adequate
depth; new models must meet the same standard from day one. Non-negotiables
for a new class and its public methods:

- State the estimand and its **scale** (mean difference, risk difference,
  log odds ratio, log hazard ratio, …), the model/likelihood/estimating
  equation, the mathematical form of the key statistic and variance
  estimator, and validity assumptions (design, censoring, matching, blocking,
  clustering, asymptotics).
- Map every argument to its mathematical symbol; state parameterizations,
  link functions, reference categories, and which scale each returned
  quantity lives on. Document null/alternative hypotheses, tail conventions,
  and how each CI is obtained (Wald, inversion, profile, bootstrap quantile,
  randomization inversion).
- Document R6 state: what is cached, call-order requirements, whether
  repeated calls are deterministic for fixed seed, and RNG/seed behavior for
  every resampling method.
- Document nonestimability and unsupported-path behavior explicitly.
- Shared contracts (bootstrap flavors, randomization mechanics, jackknife)
  are documented once at the highest level of the hierarchy; the new class
  links to the parent/component docs and documents only its own deltas. Do
  not repeat boilerplate.
- References: primary method-defining paper (DOI/arXiv preferred), textbook
  for standard theory, analogous Python API links (statsmodels, lifelines,
  scipy) labeled as *analogs, not dependencies*, and Wikipedia only as
  "See also" orientation. Follow the Primary Reference Hierarchy in
  `fix_documentation.md`.

### 3.1 Examples

Every exported class gets:

1. one **tiny runnable example** (small n, fast method, runs in CRAN check
   time) — never wrapped;
2. one **realistic example** wrapped in `\donttest{}` when it is correct but
   slow (bootstrap/randomization with real replicate counts, optional
   Suggests packages);
3. `\dontrun{}` only for code that genuinely cannot run (requires external
   resources or intentionally errors to demonstrate an assert). Do not use
   `\dontrun{}` as a speed dodge — that is what `\donttest{}` is for;
4. an example or note showing the returned estimand scale.

### 3.2 Regeneration

After any exported API, class-name, inheritance, or roxygen change, run:

```bash
Rscript fast_roxygenize.R
```

(from `R/`; it handles the R6-mixin file-attribution problem that stock
roxygen mishandles). Confirm the new `man/*.Rd` topic renders with no
placeholder text — the documentation tests fail on thin/boilerplate
descriptions.

---

## 4. Unit Tests and Integration Tests

### 4.1 testthat unit tests (`EDI/tests/testthat/`)

- Correctness of the point estimate, SE, CI, and p-value against a canonical
  implementation (closed form, `glm`, `survival::coxph`, published numerical
  example, or a simulation check) on at least one fixture per supported
  response type and design family.
- Argument-assert tests: each single-argument and cross-argument check
  errors with the documented message.
- Capability tests: `supports()` returns exactly the declared capability set;
  no undeclared public optional method exists; lazy components are not loaded
  until first use.
- Nonestimability tests: degenerate inputs (separation, all-one-arm blocks,
  zero counts, no events) produce `is_nonestimable() == TRUE` with the right
  reason/stage rather than a crash.
- Finite smoke tests for every supported likelihood, bootstrap, and Bartlett
  path (see `helper-likelihood-method-smoke.R`).
- Golden/regression fixtures if the class replaces or generalizes an existing
  one (see the migration-harness conventions in `fix_inference_hierarchy.md`).

### 4.2 Comprehensive harness registration

The class must run under `package_tests/comprehensive_tests.R`, which
exercises every (design × dataset × inference path) cell. Its discovery is
metadata-driven, but you must verify the new class actually appears and that
each supported path yields finite output. Invocation shape:

```bash
Rscript package_tests/comprehensive_tests.R <nrep> <ncores> <response> <design> <inference_filter> <dataset> <beta> <rep> <family>
```

### 4.3 The comprehensive suite and its prerequisite refresh scripts

`package_tests/run_comprehensive_suite.R <tier>` (tiers: `smoke`, `ci`, …,
`release`) is the integration gate. It hard-fails at the `dependency_gate`
step if its prerequisite artifacts are stale or missing, so after adding a
class or public method **regenerate the artifacts in this order**:

1. `Rscript package_tests/public_api_inventory.R` →
   `public_api_inventory.csv` (loads the package, inventories exported
   functions and R6 public methods);
2. `Rscript package_tests/extract_checkmate_argument_contracts.R` →
   `checkmate_argument_contracts.csv` (parses the assert calls of §2);
3. update/regenerate `public_argument_contract_registry.R` (→ `.csv`),
   `public_argument_combination_constraints.R`, and
   `public_argument_combination_fixtures.R` with the new method's contracts;
4. `Rscript package_tests/generate_public_argument_combinations.R` →
   `public_argument_combination_cases.csv`;
5. `Rscript package_tests/comprehensive_suite_registry.R` →
   `comprehensive_suite_registry.csv`;
6. `Rscript package_tests/audit_comprehensive_suite_baseline.R` →
   `comprehensive_suite_baseline_audit.csv`.

The gate also requires `public_argument_combination_results.csv`,
`_coverage.csv`, and `_failures.csv` — these come from a (possibly prior)
`run_public_argument_combinations.R` run; the suite's own
`argument_combinations` step regenerates them, but the files must exist
before the gate check.

Then run at least:

```bash
Rscript package_tests/run_comprehensive_suite.R smoke
Rscript package_tests/run_comprehensive_suite.R ci
```

Suite steps (`argument_combinations`, `comprehensive_harness`,
`public_workflow_coverage`, `internal_safety_nets`) must all be `ok` with
zero `failures_written`. The suite resumes completed steps; use `--force`
after changing the class to avoid stale-pass illusions. Quality gates are
checked by `check_comprehensive_suite_quality_gates.R` and
`check_public_argument_combination_quality_gates.R`.

---

## 5. Core C++ Code

### 5.1 Kernel design

- The numerical hot path lives in `EDI/src` as a `fast_*` kernel (e.g.
  `fast_<model>_regression.cpp`, with a `_with_var` variant when Wald SEs are
  needed), following existing conventions: Eigen linear algebra, analytic
  gradients (and Hessians where feasible), L-BFGS/IRLS/Newton per family,
  the shared smart cold-start heuristics (§8.3), and explicit convergence
  flags in the returned struct.
- Document the backend contract per `fix_documentation.md`: indexing and
  storage-order conventions, unchecked assumptions, domains, NA/NaN and
  overflow behavior, convergence fields, and the relationship to the safe R
  wrapper.
- R-facing correctness first: the R wrapper must reproduce the canonical
  fitter (e.g. `glm.fit`, `survreg`, `coxph`) to tight tolerance on standard
  and adversarial fixtures before any optimization work.

### 5.2 perf profiling (mandatory for a new kernel)

Add the kernel to the profiling harness and run it:

- register a `<kernel>_est` (and variance-path) entry in
  `profile/edi_kernel_profiler.R`, add it to the `KERNELS` list in
  `profile/run_edi_perf.sh`, and run the script. It produces per-kernel
  `perf stat` counters, `perf record` samples, and `perf annotate` output
  under `/tmp/`.
- Inspect the annotate output for the usual sins: allocation inside the
  optimizer loop, redundant `exp`/`log` in the objective vs. gradient,
  missed vectorization, un-cached design-matrix products. Optimize until the
  kernel's profile is dominated by irreducible linear algebra / special
  functions, and record before/after numbers in the PR.

### 5.3 valgrind (mandatory for a new kernel)

There is no packaged valgrind harness in the repo yet (unlike perf, which
has `profile/run_edi_perf.sh`) — this is policy for new kernels, run
manually. Run the new kernel's unit tests and a representative resampling
loop under valgrind before shipping:

```bash
R -d "valgrind --tool=memcheck --leak-check=full --track-origins=yes" \
  -e 'devtools::load_all("EDI"); testthat::test_file("EDI/tests/testthat/test-<new-model>.R")'
```

Zero definite leaks, zero invalid reads/writes, zero conditional jumps on
uninitialized values originating in EDI code. Also run once under
`--tool=callgrind` if perf results look anomalous (callgrind's deterministic
counts catch instruction bloat perf sampling can miss).

### 5.4 EDI_CORE split (R vs. Python)

The C++ core is shared verbatim between the R and Python packages — nothing
under `python/` copies a `R/EDI/src` file; the Python extension `#include`s
them directly. Therefore:

- the numerical core of the new kernel must compile under the
  `EDI_CORE_ONLY` preprocessor guard with **no Rcpp, no SEXP, no Rmath**
  reachable — vanilla Eigen + LBFGSpp + the fast-math headers only. Keep the
  Rcpp marshalling in a thin non-core wrapper (pattern:
  `_helper_functions_core.h` vs. `_helper_functions.h`);
- random-number needs inside the core use the core-safe RNG plumbing, not
  `R::runif`/`unif_rand`;
- verify with `R/scripts/check_core_no_rcpp.sh`, which fails if any
  core-marked translation unit still references Rcpp/SEXP (see
  `sexp_removal_rcppeigen_conversion_spec.md` for what "core" means);
- after adding exported C++ functions, regenerate `RcppExports` (via
  `fast_roxygenize.R` / `Rcpp::compileAttributes`) and keep
  `NAMESPACE`/docs in sync.

---

## 6. Python Bindings (`python/`, package `edi_kernels`)

Every core kernel worth exporting to Python (see
`python_bindings_package_spec.md` for the inclusion bar) requires:

1. **Bindings**: a pybind11 binding in the family file
   `python/cpp/bindings_<family>.cpp` (binary, continuous, count, glmm,
   incidence, ordinal, proportion, survival, fast_math), registered in
   `bindings_module.cpp`, returning the standard result-map shape
   (`result_map_pybind.h`).
2. **Python documentation**: a full docstring on the binding (same standard
   as §3 for backend contracts: parameterization, memory layout, unchecked
   assumptions, convergence flags, links to the analogous
   statsmodels/lifelines/scipy API) **and** a matching typed signature in
   `python/src/edi_kernels/_core.pyi` (the stub is the IDE-facing API; it
   must not drift from the binding).
3. **Tests**: `python/tests/test_fast_<kernel>.py` asserting agreement with
   the canonical Python fitter (statsmodels/lifelines/scipy) where one
   exists, and with R-generated golden values otherwise; plus edge cases
   (zero counts, separation, all-censored) mirroring the R tests.
4. **READMEs**: update `python/README.md` (kernel inventory and the
   speed-gains table — rerun the timing methodology it documents, do not
   hand-edit numbers) and `python/README_PYPI.md` (the PyPI landing page;
   every usage example there is audited — new examples must actually run).
   Add a `python/CHANGELOG.md` entry; version bumps follow the existing
   `pyproject.toml` conventions and ship through
   `.github/workflows/build-wheels.yml`.
5. **Build**: confirm `cmake`-based build passes on a clean tree and that
   the smoke/ci comprehensive-harness pass in CI still imports and runs the
   new symbol (CI runs a bounded harness pass rather than a bare import).

---

## 7. Benchmarking

### 7.1 Canonical comparators

- **R**: add the model to `benchmark/benchmark_model_fits.R`. Identify the
  canonical R function for this model (`glm`, `MASS::glm.nb`,
  `survival::coxph`/`survreg`, `ordinal::clm`, `betareg::betareg`,
  `quantreg::rq`, `pscl::hurdle`, …). When EDI itself references the
  comparator (tests, examples, fallback paths), it belongs in `Suggests`
  (never `Imports` — `survival` and `MASS` are the pre-existing exceptions,
  already core Imports), and EDI must load, run, and skip gracefully without
  it. Packages used *only* by the benchmark scripts (e.g. `microbenchmark`,
  `DescTools`, `sandwich`) need not be package dependencies at all.
- **Python**: add the model to `benchmark/benchmark_model_fits_python.py`
  with the canonical Python fitter (statsmodels, lifelines, scipy,
  scikit-survival; the baseline registry is `python/benchmarks/baselines.py`).
  Benchmark against the *lowest-level* fit interface the baseline exposes;
  fall back to its high-level API only when no low-level entry point exists,
  and flag that in the report. Per
  `python_bindings_package_spec.md`, a family with **no clean Python
  canonical baseline gets correctness-only treatment** — validated against
  the R canonical comparator's golden values — rather than a fabricated
  speedup claim; the R comparator (in `Suggests`, per above) remains the
  reference implementation.
- Report medians over repeated cold runs at the standard n/p grid the
  existing benchmark files use; regenerate the rendered reports
  (`benchmark_model_fits_R.html`, `benchmark/benchmark_model_fits.md`,
  `python/benchmark/benchmark_model_fits_python.html`) and the README speed
  tables (§6.4) from the same run.

### 7.2 Cold starts and warm starts (optimization-based models only)

- **Cold start**: implement a smart-start heuristic in the kernel (OLS on a
  transformed response, moment-based secondary parameters — see
  `cold_starts.md` for family-by-family conventions, aligned with `glm.fit`
  / `survreg` where an R standard exists). Benchmark smart vs. naive-zero
  with `benchmark/benchmark_cold_starts_vs_naive.R` /
  `benchmark/comprehensive_cold_start.R` and record iterations-to-converge
  and end-to-end time; `benchmark/exhaustive_cold_start_audit.R` must still
  pass.
- **Warm start**: resampling paths (bootstrap, Bayesian bootstrap,
  randomization, jackknife) must reuse the full-data MLE (or the appropriate
  anchor) as the starting point for each replicate fit. Benchmark with the
  `benchmark/benchmark_*_warm_starts.R` family (assembled by
  `assemble_warm_starts.R`, run via `run_all_warm_starts.sh`) and confirm
  the warm path is both faster and estimate-identical to cold refitting.

---

## 8. comprehensive_tests.R and path_audits.html

### 8.1 comprehensive_tests.R

Beyond metadata-driven discovery (§4.2), check the harness's per-path skip
machinery: if any of the class's supported methods is too slow at scale,
mark it via the audit row's `slow_methods` override (with measured avg/max
timings in `notes`) rather than silently letting the harness time out.

### 8.2 path_audits.html

`package_tests/path_audits_source.R` is the hand-curated source of truth for
which inference paths each class supports, skips, or runs slowly. For a new
class:

1. add one entry to `audit_classes` in its response-type section, filling
   every column deliberately: `resp`, `kk`, `types` (Wald/score/grad/LR
   support), `skip_asymp`/`skip_ci`, `skip_boot`, `skip_bbt`(+`_ci`),
   `jack`, `skip_rand`/`rand_resp`, `skip_rpv`, `skip_rci`/`rci_resp`,
   `pboot` (TRUE/FALSE/NA per the header's three-state convention),
   `exact_p`/`exact_c`, plus `slow_methods`/`unsupported_methods` overrides
   and a `notes` string recording ancestry, capability decisions, and
   measured slow-path timings;
2. every `FALSE`/`NA`/skip must correspond to a documented capability
   decision (§1.3), not an untested unknown;
3. regenerate the HTML report (the source file calls `html_from_audit()` at
   the end, so running it is enough):

   ```bash
   Rscript package_tests/path_audits_source.R
   ```

4. `package_tests/refresh_inference_paths_info.R` regenerates the derived
   inference-paths metadata (optimization strategy, algorithm, analytic
   Hessian) — extend its `get_opt_metadata()` mapping for the new class and
   rerun it;
5. keep `path_audits_nonestimability_defaults.csv` consistent if the class
   introduces new nonestimability behavior.

---

## 9. Definition of Done (checklist)

- [ ] Class defined via `define_inference_class()` with complete, validated
      metadata; correct likelihood tier; components/capabilities exact; no
      root-owned state in any new component's `owns_state`; new `*Source`
      literals consumed only through the registry.
- [ ] Registry lookup tables fed (§1.2): name prefix/tier token,
      `infer_inference_direct_components()` entry mirroring `components =`,
      `EDI_INFERENCE_ESTIMAND_TAGS`, covariate-use table, compatibility
      hooks; `test-inference-class-registry.R`, `test-mixin-contracts.R`,
      `test-capability-tables.R`, `test-static-cleanup-guardrails.R` green.
- [ ] Discovered by `InferenceSuite` for exactly the compatible designs.
- [ ] All single-argument checkmate asserts present and gated on
      `should_run_asserts()`; cross-argument helpers in
      `additional_asserts.R`; combination constraints/fixtures declared.
- [ ] Roxygen meets `fix_documentation.md`; tiny runnable example +
      `\donttest{}` realistic example; references cited;
      `Rscript fast_roxygenize.R` run; Rd non-thin.
- [ ] testthat unit tests: correctness vs. canonical fitter, asserts,
      capabilities, nonestimability, finite smoke tests.
- [ ] Prerequisite artifacts refreshed (§4.3 order) and
      `run_comprehensive_suite.R smoke` + `ci` fully `ok`.
- [ ] C++ kernel profiled with `profile/run_edi_perf.sh` (registered in
      `edi_kernel_profiler.R`) and optimized; clean valgrind memcheck run.
- [ ] Core compiles under `EDI_CORE_ONLY`; `check_core_no_rcpp.sh` passes.
- [ ] Python: pybind11 binding + `_core.pyi` stub + docstring + tests;
      `python/README.md`, `README_PYPI.md`, `CHANGELOG.md` updated with
      regenerated (not hand-edited) numbers.
- [ ] Benchmarks: R and Python canonical-comparator entries added
      (comparator R package in `Suggests`; R-side fallback baseline when no
      Python canonical exists); reports regenerated.
- [ ] Cold-start heuristic implemented and benchmarked vs. naive; warm
      starts benchmarked for all resampling paths (optimization-based
      models).
- [ ] `path_audits_source.R` row added with deliberate skip/slow decisions;
      `path_audits.html` regenerated; `refresh_inference_paths_info.R`
      mapping extended.
