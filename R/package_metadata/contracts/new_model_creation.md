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

- `R/EDI/vignettes/extending-edi.Rmd` (`vignette("extending-edi")`) — the
  user-facing primer on how EDI classes are built (factory, components,
  capabilities, registry-only discovery), the external extension shells, and
  the subclassing rules. **This contract does not repeat that material**: §1
  below cites the vignette's sections and adds only what an in-package class
  needs on top (registry lookup tables, factory arguments, Source literals,
  Collate, capability tables). Anything that changes the external contract is
  edited in the vignette, not here.
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

The architecture (shallow inheritance, components, capabilities, the retired
legacy ladder, registry-only discovery) is described once, for everyone, in
`vignette("extending-edi")` § "How EDI classes are built" and § "Subclassing
rules and capability detection"; `fix_inference_hierarchy.md`'s Architectural
Rule and Source Invariants are the formal statement. Read those first. This
section adds only what an **in-package** class must do beyond them.

**Templates (2026-08-23, migration complete):** every concrete class is a
`define_inference_class()` call and any is a valid template —
`InferenceCountQuasiPoisson`, `InferenceAllSimpleWilcox`,
`InferenceIncidLogRegr`, `InferenceSurvivalKKLWACoxPHOneLik` are compact
examples of, respectively, quasi-likelihood, no-likelihood, full-likelihood
GLM, and KK partial-likelihood classes. The few `R6::R6Class("InferenceXxx",
...)` definitions still at the top of some files are in-file *component
sources* that the following factory call composes, not templates. The
vignette's "never" rules (no ladder inheritance, no `supports_*()` flag pairs,
no hand-splicing of component lists, no redeclared root-owned state) are
enforced in-package by `test-static-cleanup-guardrails.R`,
`test-inference-class-registry.R`, `test-capability-tables.R`, and factory
validation.

### 1.1 Class identity

- Parent is `Inference`, or an estimator-family base only when every child is
  substitutable for that parent *as the same kind of estimator* (vignette,
  "How EDI classes are built").
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

The capability model itself (metadata-backed `capabilities()`/`supports()`,
public method presence == capability presence, no flag pairs or throwing
stubs) is the vignette's "How EDI classes are built"; here is what the class
author must decide and wire:

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
- Heavy optional components (parametric bootstrap, GLMM plumbing, Bartlett)
  should be `lazy`-loaded; keep discovery and `supports()` metadata-only.
- Structurally unsupported paths must be *intentional and documented* (e.g.
  Bayesian bootstrap is undefined for rank statistics because fractional
  weights have no meaning for the statistic) — record the reason in the
  path-audit row `notes` (§8.2) and in the roxygen docs (§3).

### 1.4 Discovery

Discovery is registry-only (vignette, "How EDI classes are built"); for an
in-package class that means the §1.2 tables decide everything.
`InferenceSuite`/`Design$applicable_inference_class_names()` must find the
class from metadata alone: `abstract == FALSE`, `exported == TRUE`,
`required_packages` available, compatibility predicates true. Verify the new
class appears for compatible designs and is absent (with the right reason,
e.g. in `unavailable_inference_classes_due_to_missing_packages()`) otherwise.
Never make discovery depend on constructor failures or private-method
sniffing.

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
- References: see §3.0 — every cited work goes through `R/EDI/REFERENCES.md`.
- The rest of the standard applies verbatim even though it is not restated
  here: numerical-implementation details (optimizer, starting values,
  tolerances, constraints, fallbacks, warnings), computational complexity and
  practical limits, input conventions (dimensions, coding, ties, boundary
  cases), return-object schema for anything returning a list, lifecycle
  status, and — for the `fast_*` backend — the backend contract of §5.1.

### 3.0 References and `R/EDI/REFERENCES.md`

`R/EDI/REFERENCES.md` is the package's single source of truth for primary
citations: one entry per work, organized by method family, with a stable key
(`[KK14]`, `[Fisher1935]`, …) and a "Used by:" line naming every class/kernel
that cites it. It is maintained **by hand** and has no automated sync check
(its own header says so), so a new class is responsible for keeping it true:

- Cite by stable key in the roxygen `@references` block (author-year plus the
  DOI/arXiv/book record, as the existing entries do) and link back to
  `REFERENCES.md`; never paste a bibliography that only lives inline.
- For every work the new class cites: if the key exists, append the class
  (and any new `fast_*` kernel) to that key's "Used by:" line; if it is new,
  add a full entry under the right family section (`## Inference methods` →
  response-type subsection, `## Numerical/backend utilities` for algorithms,
  …). Check the "Coverage gaps" section at the bottom and remove any gap the
  new docs close.
- Choose sources by the Primary Reference Hierarchy in `fix_documentation.md`
  (method-defining paper → journal/arXiv → textbook/monograph → software
  manual only as an implementation analog → Wikipedia only as orientation),
  and cite the **numerical and statistical ingredients** too, not just the
  method: approximations, optimizers, quadrature rules, transforms,
  corrections, and named algorithms (Lanczos, Stirling, Gauss–Hermite,
  LogSumExp, Bartlett, BCa, …) each get a reference.
- Apply the three-class link policy from `fix_documentation.md`: primary
  statistical references; analogous-software documentation (statsmodels,
  lifelines, scipy, scikit-survival — say explicitly they are *analogs, not
  dependencies*, and use its starter link maps); Wikipedia as "See also"
  orientation only, never as the primary source.

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
  until first use. Note that several existing suites *enumerate* classes and
  must be **extended**, not merely pass — the parametric-bootstrap smoke
  table, the count-family focused tests, the likelihood-tier baselines, and
  the InferenceSuite fixture lock; the list is in §9.1.
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

### 4.4 The advanced argument-combination tests and the second post-push CI (`test-coverage-R-advanced`)

Two GitHub Actions run on every push/PR to `main` that touches `R/EDI/**`
or `R/package_tests/**`: `test-coverage-R.yaml` (covr/testthat line
coverage) and the **second, advanced one**, `test-coverage-R-advanced.yml`,
which is the comprehensive-test-suite gate built from
`comprehensive_test_suite.md`. A new class is not done until its public
methods are wired into that gate's **multi-argument (argument-combination)
tests** and the workflow is green. Concretely, the workflow:

1. installs EDI, rebuilds the live-introspection artifacts
   (`public_api_inventory.R`, `extract_checkmate_argument_contracts.R`,
   `public_argument_contract_registry.R`);
2. rebuilds and runs the **argument-combination family** —
   `generate_public_argument_combinations.R` →
   `run_public_argument_combinations.R` (every public method of every
   exported class is called over the valid/invalid grid of argument values
   generated from the §2 contracts and §2.2 cross-argument constraints) →
   `analyze_public_argument_combinations.R` →
   `public_argument_combination_integration.R` →
   `check_public_argument_combination_quality_gates.R report`;
3. rebuilds the baseline audit, suite registry, and internal safety-net
   surfaces (`audit_comprehensive_suite_baseline.R` **before**
   `comprehensive_suite_registry.R`, then
   `comprehensive_suite_internal_surfaces.R`);
4. **fails if any regenerated `package_tests/*.csv` artifact differs from
   what is committed** (`git diff --exit-code` over the inventory,
   checkmate contracts, every `public_argument_combination_*.csv`,
   `comprehensive_suite_registry.csv`, `comprehensive_suite_baseline_audit.csv`,
   `comprehensive_suite_internal_surfaces.csv`);
5. runs `run_comprehensive_suite.R smoke "" 300 --force`,
   `analyze_comprehensive_suite.R`, and
   `check_comprehensive_suite_quality_gates.R ci`.

What this means for a new class:

- **Add the class's methods to the advanced tests, don't just let them be
  discovered.** The combination runner only knows what the §2 asserts and
  the `package_tests/public_argument_contract_registry.R` /
  `public_argument_combination_constraints.R` /
  `public_argument_combination_fixtures.R` declarations tell it. Every new
  public method with more than one argument needs its single-argument
  domains (checkmate, §2.1) and its cross-argument constraints (§2.2)
  declared there, plus a fixture when the method needs special construction
  (a KK design, a censored response, an optional package). A method with an
  undeclared constraint shows up as a spurious combination failure; a
  declared-but-unenforced one as a missed error; an unregistered method as
  a `public_api_missing_from_registry`/`uncovered_apis` hard-gate failure.
- **Regenerate and commit the artifacts in the workflow's order** (it is
  the same order as §4.3, with the argument-combination family run in full
  and `audit_comprehensive_suite_baseline.R` strictly before
  `comprehensive_suite_registry.R`). The drift check in step 4 is the
  mechanism that catches "added a class, forgot the CSVs" — if you push
  without regenerating, the second CI fails on the diff, not on your code.
- **Run the gate locally first** — the same scripts in the same order, then
  `check_public_argument_combination_quality_gates.R report` and
  `check_comprehensive_suite_quality_gates.R ci` must both pass — and
  check the workflow run after pushing; a red `test-coverage-R-advanced`
  is a failed Definition of Done even when `R-CMD-check` and
  `test-coverage-R` are green.

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

### 5.5 Kernel performance engineering rules (from `performance_profiling_and_upgrades.md`)

`package_metadata/new_feature_plans/performance_profiling_and_upgrades.md` is
the package's evidence record of every kernel optimization tried, retained,
and reverted (Phases 1–8). It is not repeated here; its retained findings are
the rules a new kernel must satisfy *before* §5.2's profiling pass, so the
pass confirms a clean profile rather than discovering known sins:

- **No allocation in the hot path.** Objective/gradient/Hessian bodies use
  constructor-sized member scratch buffers and `.noalias()` assignments; no
  `VectorXd::Zero(n)`, `resize()`, `auto`-captured expressions, or
  `.transpose() * v` temporaries inside `operator()` (TODO-110 and the
  TODO-9/13/51 family). Verify with the cheap per-file version of TODO-141:
  a `-DEIGEN_RUNTIME_NO_MALLOC` build with `set_is_malloc_allowed(false)`
  around the objective must not assert.
- **Zero-copy boundary.** `Eigen::Map` over R memory (never
  `as<Eigen::MatrixXd>` copies) on the way in; results built once, not per
  replicate, on the way out (TODO-145).
- **Access patterns.** No `.row(i)` on column-major matrices inside
  per-observation loops (the 5× ZAP/ZINB regression, TODO-15/16/144); no
  `NumericMatrix(i, j)`/jagged `std::vector<std::vector<>>` in inner loops.
- **Special functions.** Hoist `lgamma`/`digamma`/`trigamma` and other
  per-fit-constant terms out of the objective loop (the v2.3 ZINB retained
  change); use the package's `fast_*` helpers (`fast_log1pexp`, `pnorm_fast`,
  `fast_digamma`, …) rather than libm in hot loops; clamp `exp` arguments
  algorithmically rather than relying on FTZ/DAZ (TODO-140).
- **Work per fit.** `estimate_only` early returns that skip the Hessian/
  variance path (Phase 4); do not evaluate `value()` and `operator()` at the
  same point (TODO-152); solve, don't `.inverse()`, and use Cholesky where
  the matrix is SPD (TODO-155); resampling paths warm-start from the
  full-data fit and, where the class supports it, use the reusable bootstrap
  worker / closed-form-CI patterns (the "BRT smoothed fast-kernel" section,
  §7.2 here).
- **Parallel kernels.** Per-thread accumulators are thread-local or padded to
  a cacheline and reduced once (TODO-143); never write adjacent result
  columns from different threads.
- **Measure the way the record measures.** Any optimization claim uses the
  document's format — root cause → fix → correctness → *paired* benchmark on
  an apples-to-apples build (same flags, `EDI_UNITY`, `-march`), ABBA/BAAB
  ordering, medians over repeated cold runs, machine state and BLAS recorded,
  and the `perf -F 199` sampling-noise caveat in mind (TODO-129/130/135/175/
  176). Name profiler entries `<type>_est` / `<type>_var`.
- **Don't add to the open audits.** Run `clang-tidy -checks='performance-*'`
  on the new file (TODO-163) and keep the kernel's `n`/`p` scaling no worse
  than its family's (TODO-162). The rest of Phase 8 (TODO-131..179) is
  package-wide work, not a per-kernel gate.

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

### 7.1 Canonical comparators — model benchmarking is mandatory

Every new model **must** be run through the model-fit benchmark harness on
both sides — `benchmark/benchmark_model_fits.R` (R) and
`benchmark/benchmark_model_fits_python.py` (Python) — so the release
artifact (`benchmark/benchmark_model_fits.md`, regenerated from the R and
Python HTML reports) shows an **apples-to-apples** timing of EDI's kernel
against the canonical R package and the canonical Python package: EDI rows
are bare-metal calls to the exported `fast_*` function with design matrices
pre-built outside the timed region, the comparator is the package's
*lowest-level* fit interface (`glm.fit`, `lm.fit`, `coxph.fit`, …), medians
over repeated cold runs at the standard `n`/`p` grid, same machine, same
compiled `EDI.so` (the report's "Compilation Context" block records the
flags — a non-optimized build invalidates the row), with the paired timing
p-value the harness already reports.

**The row is mandatory even when no comparator exists.** If there is no
canonical R and/or Python implementation of the model (custom joint
likelihoods, KK matched+reservoir estimators, zero-one-inflated beta, …),
the model still gets its row in the R and/or Python benchmark tables, timed
EDI-only, with `Canonical Package = None`, the note
"no canonical R implementation" / "no canonical Python implementation", and
`Canonical Time`/`Speedup`/`Timing Pval = NA` by design — the harness
renders these as the light-blue rows. "We couldn't find a baseline" is
recorded in the table, not used as a reason to skip the benchmark; the
absence of a comparator is itself information the README speed tables and
`python_bindings_package_spec.md`'s baseline-gap analysis depend on, and the
EDI-only timing is still the regression baseline for §5.5's paired
before/after comparisons. When a comparator exists on one side only, the
other side's row says so explicitly rather than borrowing the first side's
number.

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
5. `path_audits_nonestimability_defaults.csv` is the audit's cached
   estimability snapshot and is refreshed automatically (§8.3); do not edit
   it by hand.

### 8.3 Recommended: run `comprehensive_tests.R` on the class, then regenerate `path_audits.html` to read its estimability

The audit table is more than a support matrix: every "attempted" cell is
colored by the **observed estimability** of that class × method path in the
comprehensive-harness results, so the cheapest way to learn where a new
class's methods actually fail to produce a number — and whether that is by
design or a bug — is to run the harness on it and read its row. Do this
before declaring the class done:

1. **Run the harness for the class's response type(s)** (§4.2 invocation
   shape) on the standard datasets/designs, with enough replicates that
   rare failures show up (`nrep` in the tens, not 1). The harness records
   one row per (dataset × design × class × method) call in
   `package_tests/comprehensive_tests_results_nc_<ncores>_<response>.csv`;
   a call on an object whose `is_nonestimable()` is `TRUE` is recorded with
   `error_message = "Explicitly non-estimable in <method>"` (and the
   reason/stage), which is what the audit counts. Note that a run restricted
   with the class/design filters writes a `…_filtered_…` results file that
   `load_nonestimability_stats()` **deliberately ignores**, so results meant
   for the audit must come from the unfiltered response-type run (the
   filtered run is still useful for a fast first look at the raw rows).
2. **Regenerate the audit** — `Rscript package_tests/path_audits_source.R`
   (§8.2) — which pools every non-filtered results CSV, computes the explicit
   non-estimable rate per (class, method), and, when the pooled row count
   exceeds the cached snapshot's, rewrites
   `path_audits_nonestimability_defaults.csv` itself.
3. **Read the class's row in `path_audits.html`.** Cell meaning: green ✓ =
   `always_numeric_methods` (closed-form, theoretically guaranteed — never
   claim this for an optimizer-based path); "unknown" (pale green) = attempted
   but no result rows yet (your run has not been pooled); then the observed
   estimable-rate bins 100% → [95–100)% → [75–95)% → [25–75)% → [5–25)% →
   [1–5)% → (0–1)% → 0% from light green through yellow to dark orange,
   with the hover title giving the exact `nonestimable/n` counts; SLOW (light
   red) = `slow_methods`; NTS (dark grey) = `unsupported_methods`. Paths
   under 1% estimable are also listed in the "<1% Estimable Paths" table at
   the bottom.
4. **Act on what the colors say.** For each path that is not (near-)fully
   estimable, decide and record which of these it is: (a) a legitimate
   nonestimability of the design/data (e.g. no events, all-one-arm blocks,
   separation, too few matched pairs) — the class must report it through
   `is_nonestimable()`/`get_nonestimable_reason()`/`get_nonestimable_stage()`
   with the right reason, the roxygen (§3) must say so, and the audit row
   should list the method under `maybe_nonestimable_methods` with the
   reason in `notes`; (b) a structural unsupported path — declare it via
   capabilities (§1.3) and `unsupported_methods`, not by letting it fail;
   (c) a bug — an `estimate_only` guard missing on a resampling path, a
   variance computation failing where the estimate exists, an optimizer
   that never converges on the standard fixtures, a wrapper that turns a
   warning into an error — fix it and re-run. Compare against the sibling
   classes in the same family section of the table: a new class noticeably
   less estimable than its siblings on the same fixtures is almost always
   (c).
5. Record measured avg/max timings for anything you mark SLOW (§8.1), and
   keep the Python/benchmark/path-audit rows consistent with the final
   capability decisions.

---

## 9. Package wiring that breaks if skipped, and recommended extras

### 9.1 Required — a gate, build, or test fails without each of these

- **`DESCRIPTION` `Collate`.** The package declares an explicit `Collate`
  field, so a new `R/*.R` file that is not listed is simply never sourced.
  Add the file (after the files defining anything its `define_inference_class()`
  call references eagerly — `inherit =`, component sources; see §1.1).
- **Extend the enumerating tests — they fail on a new class until you do.**
  Several suites assert "classes in my table == classes in the registry":
  `test-parametric-bootstrap-lr-all-capable-classes.R` (a finite smoke case
  for every class advertising `parametric_likelihood_bootstrap`, with an
  exact registry-to-case equality guard),
  `test-count-likelihood-families-focused.R` (every non-KK concrete
  `InferenceCount*` class by tier), `test-full-likelihood-migration-baseline.R`
  / `test-partial-likelihood-migration-baseline.R` (expected class lists per
  tier and effective components), `test-inference-suite-run-all-inference.R`
  (the InferenceSuite fixture lock: the set of classes `run_all_inference()`
  reports on each fixture design), plus `test-inference-class-registry.R` /
  `test-capability-tables.R` / `test-mixin-contracts.R`. Add the new class
  to each table it belongs in — these are "extend" obligations, not "pass".
- **Unity-build safety for the new `.cpp`.** `EDI_UNITY=1` is the default
  build, so the file is `#include`d into a ~10-file translation unit with
  its neighbors. Per `unity_build_collision_audit.md`: no file-scope
  `static` names, anonymous-namespace names, or surviving `#define`s that
  could collide with any other kernel (hoist shared helpers/structs into a
  header such as `_glmm_engine.h`, as `GHRule` was); rely on
  `_helper_functions.h` being the first include of every unity TU; never
  merge `RcppExports.cpp`; and re-run a default (`EDI_UNITY=1`) build, not
  only the per-file `EDI_UNITY=0` developer build, before declaring the
  kernel done (that is the `R CMD check` CI builds with). Unity safety rots
  silently — a colliding static is a link error for everyone later.
- **pkgdown reference index.** `EDI/_pkgdown.yml` indexes inference classes
  by name pattern (`matches("^InferenceContin")`, `^InferenceIncid`,
  `^InferenceCount`, `^InferenceProp`, `^InferenceOrdinal`,
  `^InferenceSurvival`) and lists cross-cutting classes and backend kernels
  explicitly. A new exported class must fall under its family pattern or be
  added to the right section; every new exported `fast_*` kernel goes into
  the matching "Backend: …" list. An exported topic missing from the index
  fails the pkgdown build.
- **Dispatch and parallel-safety policy tables.** The policy tables in
  `R/globals.R` are keyed by class-name regular expressions: the parallel
  dispatch policy's forced-serial `serial_inference_class_patterns` blocklist
  (`parallel_fork_cluster_test_safety.md` — a randomization-CI/bootstrap
  path that oversubscribes or deadlocks under a fork cluster after OpenMP
  must be blocklisted), and the cold-start / warm-start / optimizer dispatch
  tables. Decide explicitly whether the new class falls under an existing
  pattern or needs its own entry (a too-broad existing pattern silently
  applies another family's policy), and confirm
  `tune_EDI_for_this_machine()`'s registry-driven family enumeration handles
  it (`test-local-machine-tuning-*.R`).
- **`inst/NEWS.Rd`.** Add the class under the current version's NEW FEATURES
  (the release CHANGELOG entry is written at batch close; the per-class line
  is the author's).

### 9.2 Recommended

- **SimulationFramework and parallel backends.** Run the class under
  `SimulationFramework` with `num_cores > 1` on both the fork and `mirai`
  backends, and confirm every resampling path is seed-deterministic
  independent of core count and backend, per the conventions in
  `vignette("reproducibility")` (`test-simulation-framework-capability-dispatch.R`
  is the dispatch pattern; the framework finds the class by capabilities).
- **Validation evidence.** Add a row to `vignettes/validation-evidence.Rmd`
  mapping the class and its kernel to the test file that proves them
  against the canonical comparator (or closed-form/limiting case), and a
  `vignettes/notation-glossary.Rmd` entry if the class introduces a symbol
  or convention.
- **Survival classes: censoring stance.** Implement
  `supports_interval_or_left_censored_data()` deliberately (the registry
  reads it for design compatibility) and handle `y_L`/`y_R` per
  `interval_censored_survival_response.md`, rather than silently treating
  every response as right-censored.
- **Runtime budgets.** Keep the tiny roxygen example well inside CRAN check
  time and OpenMP-light (the Windows `\donttest{}` hang in
  `release_v1_0_0.md` is still open), and keep each method inside the
  comprehensive-suite tier timeouts (`comprehensive_suite_runtime_tiers.csv`)
  or mark it SLOW with measured timings (§8.1).
- **Serializable private state.** Keep `private` fields plain R values — no
  external pointers or environment handles (the `save_load_api.md` audit
  found exactly that in `DesignFixedOptimal`). `Inference*` objects are
  transient today, but keeping them plain keeps that cheap to change.

---

## 10. Definition of Done (checklist)

- [ ] Package wiring (§9.1): `DESCRIPTION` `Collate` entry; every
      enumerating test table extended (parametric-bootstrap smoke cases,
      count-family focused, likelihood-tier baselines, InferenceSuite
      fixture lock); new `.cpp` unity-safe and built with `EDI_UNITY=1`;
      `_pkgdown.yml` index covers the class and any new kernel; dispatch /
      parallel-safety policy patterns decided; `inst/NEWS.Rd` entry.
- [ ] Recommended extras (§9.2) considered and either done or consciously
      skipped: SimulationFramework multi-core/backend determinism,
      `validation-evidence.Rmd` row, survival censoring stance, runtime
      budgets, plain serializable private state.
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
      `\donttest{}` realistic example; references cited by stable key and
      `R/EDI/REFERENCES.md` updated (new entries and/or "Used by:" lines for
      every cited work, numerical ingredients included, coverage gaps
      re-checked); `Rscript fast_roxygenize.R` run; Rd non-thin.
- [ ] testthat unit tests: correctness vs. canonical fitter, asserts,
      capabilities, nonestimability, finite smoke tests.
- [ ] Prerequisite artifacts refreshed (§4.3 order) and
      `run_comprehensive_suite.R smoke` + `ci` fully `ok`.
- [ ] Advanced multi-argument tests (§4.4): new public methods declared in
      the argument-combination registry/constraints/fixtures, the
      argument-combination family run, all `package_tests/*.csv` artifacts
      regenerated in workflow order and committed, both quality-gate scripts
      passing locally, and the post-push `test-coverage-R-advanced` workflow
      green.
- [ ] C++ kernel obeys the §5.5 performance engineering rules (no hot-path
      allocation — `EIGEN_RUNTIME_NO_MALLOC` clean — zero-copy boundary, no
      strided inner-loop access, hoisted special functions, `estimate_only`
      early returns, padded per-thread accumulators); profiled with
      `profile/run_edi_perf.sh` (registered in `edi_kernel_profiler.R`) and
      optimized with paired before/after benchmarks; clean valgrind memcheck
      run; `clang-tidy performance-*` clean.
- [ ] Core compiles under `EDI_CORE_ONLY`; `check_core_no_rcpp.sh` passes.
- [ ] Python: pybind11 binding + `_core.pyi` stub + docstring + tests;
      `python/README.md`, `README_PYPI.md`, `CHANGELOG.md` updated with
      regenerated (not hand-edited) numbers.
- [ ] Benchmarks (mandatory, §7.1): R and Python model-fit benchmark rows
      added and run apples-to-apples against the lowest-level canonical fit
      of the R and Python packages (comparator R package in `Suggests`;
      R-side fallback baseline when no Python canonical exists); when no
      canonical package exists on a side, the EDI-only row is still added
      with `Canonical Package = None` / "no canonical … implementation" /
      NA speedup; reports and README speed tables regenerated, not
      hand-edited.
- [ ] Cold-start heuristic implemented and benchmarked vs. naive; warm
      starts benchmarked for all resampling paths (optimization-based
      models).
- [ ] `path_audits_source.R` row added with deliberate skip/slow decisions;
      comprehensive-harness run for the class's response type(s) pooled into
      the audit and `path_audits.html` regenerated; every non-fully-estimable
      cell in the class's row classified as legitimate (reason reported and
      documented), unsupported (declared), or a bug (fixed) per §8.3;
      `refresh_inference_paths_info.R` mapping extended.
