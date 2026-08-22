# Future Inference Hierarchy

> **Depends on:** none — foundational. Nearly every plan below consumes its components/capabilities; its Follow-Ups bugs (lazy-component clone staleness, `dead`-propagation, locked-binding sweep) block several other plans' verification runs. (Global ordering: see `_master.md`.)

Date: 2026-08-03

## Purpose

This document specifies the target `Inference*` architecture. It is not a
patch plan for the current inheritance ladder. The goal is a shallow hierarchy
where estimator identity is represented by inheritance and optional inference
algorithms are represented by checked components.

The architecture must make these properties true by construction:

1. A class exposes an operation only when it can execute that operation.
2. Each behavior has one component owner.
3. Each mutable field has one state owner.
4. Components are inherited through metadata and never composed twice.
5. Component requirements and collisions are validated when the class generator
   is defined.
6. Discovery reads metadata and pure compatibility predicates, never
   constructors or private method names.
7. Likelihood semantics are metadata, not superclass identity.
8. There are no legacy aliases. The package is unreleased, so old names should
   be deleted instead of carried forward.

## Architectural Rule

Inheritance answers one question:

```text
Can every child be substituted for this parent as the same kind of estimator?
```

Components answer a different question:

```text
Which optional algorithms and helper behaviors does this estimator expose?
```

Do not use inheritance to distribute randomization, bootstrap, jackknife, Wald,
likelihood-test, parametric-bootstrap, KK pass-through, GEE, GLMM, cache, or
count-likelihood behavior.

The target hierarchy is shallow:

```text
Inference
  -> optional estimator-family base with genuinely shared estimator math
      -> concrete estimator
```

Allowed parents:

- `Inference`: owns root data normalization, lifecycle, root state, and the
  minimal estimate contract.
- Family bases: allowed only when every descendant is substitutable for the
  base and the base does not expose optional inference algorithms.
- Concrete estimators: provide the estimator-specific point estimate,
  likelihood/objective hooks, simulation hooks, and compatibility metadata.

Disallowed parents:

- Any base whose main purpose is to add an optional algorithm.
- Any base whose descendants must opt out of public APIs with `supports_*`
  flags or throwing methods.
- Any likelihood-tier parent such as `NoLik`, `QuasiLik`, `PartialLik`, or
  `FullLik` if that parent carries public inference APIs.

## Class Metadata

Every canonical generator must have one immutable metadata record:

```r
list(
  name = "InferenceContinOLS",
  parent = "Inference",
  abstract = FALSE,
  exported = TRUE,
  response_types = "continuous",
  design_families = c("bernoulli", "complete_randomization"),
  compatibility = is_compatible_continuous_ols,
  likelihood_tier = "full",
  direct_components = c(
    "Wald",
    "LikelihoodTests",
    "NonparametricBootstrap",
    "ParametricLikelihoodBootstrap"
  ),
  required_packages = character()
)
```

Mandatory fields:

- `name`: canonical generator name.
- `parent`: canonical parent generator name or `NULL` for `Inference`.
- `abstract`: `TRUE` only for non-instantiable infrastructure.
- `exported`: `TRUE` only for user-facing estimator classes.
- `response_types`: response domains accepted by the estimator.
- `design_families`: randomization/design domains accepted by the estimator.
- `compatibility`: pure predicate over normalized design metadata.
- `likelihood_tier`: one of `none`, `quasi`, `partial`, or `full`.
- `direct_components`: components added by this class.
- `required_packages`: optional packages needed to instantiate or execute.

There is no alias metadata. If two names currently refer to the same generator,
choose the better canonical name and delete the other assignment. Because the
package is unreleased, compatibility aliases and deprecation schedules add
complexity without protecting users.

## Likelihood Tier

`likelihood_tier` is semantic metadata:

- `none`: no likelihood is defined for inference.
- `quasi`: estimating equation, quasi-likelihood, GEE, robust, or sandwich
  objective that is not a normalized model likelihood.
- `partial`: conditional or partial likelihood.
- `full`: full model likelihood.

Classification follows the implemented objective, not the class name. A class
named with `Lik` is not automatically likelihood-bearing. A likelihood tier
does not imply any public method. It only constrains which capabilities are
eligible.

Tier rules:

| Tier | Permitted likelihood capabilities |
|---|---|
| `none` | no likelihood ratio, score, gradient, Bartlett correction, or likelihood parametric bootstrap |
| `quasi` | Wald/sandwich inference; estimating-equation tests only under explicitly named capabilities |
| `partial` | score, gradient, likelihood ratio, and parametric calibration only when hooks exist |
| `full` | score, gradient, likelihood ratio, and parametric calibration only when hooks exist |

## Components

A component is a named, registered unit of optional behavior. It may provide
public methods, private helper methods, state ownership, host requirements,
capabilities, and dependencies on other components.

Expected component families:

- `RandomizationTest`
- `RandomizationCI`
- `NonparametricBootstrap`
- `RandomizationBootstrap`
- `BayesianBootstrap`
- `Jackknife`
- `Wald`
- `LikelihoodTests`
- `ParametricLikelihoodBootstrap`
- `StandardModelCache`
- `CountLikelihoodPlumbing`
- `KKPassThrough`
- `KKCompound`
- `KKGEE`
- `KKGLMM`
- `OffOptimumLikelihoodEval`
- `BartlettApproximation`

Empty scaffolds are not components. A registered component must either provide
behavior or be marked `status = "scaffold"` and forbidden from every effective
component set.

## Component Contract

Each component record must be executable metadata, not documentation:

```r
InferenceComponent(
  name = "ParametricLikelihoodBootstrap",
  status = "active",
  dependencies = "LikelihoodTests",
  public = list(...),
  private = list(...),
  provides_public_methods = c(...),
  provides_private_methods = c(...),
  owns_state = character(),
  requires_state = c(...),
  requires_public_methods = character(),
  requires_private_methods = c(
    "get_likelihood_test_spec",
    "simulate_under_lik_null"
  ),
  optional_public_methods = character(),
  optional_private_methods = character(),
  provides_capabilities = "parametric_likelihood_bootstrap",
  allowed_likelihood_tiers = c("partial", "full"),
  conflicts = character(),
  allowed_host_overrides = list(public = character(), private = character())
)
```

Contract rules:

1. `provides_public_methods` must exactly match names in the component public
   list.
2. `provides_private_methods` must exactly match names in the component
   private list.
3. `owns_state` contains only fields the component initializes and controls.
4. `requires_state` contains host/root fields the component reads or writes
   but does not own.
5. Every `private$foo`, `self$foo`, and `super$foo` reference in component
   bodies must be classified as provided, required, optional, or forbidden.
6. `super$foo` is allowed only when the contract names the parent service that
   supplies `foo`.
7. Components cannot redeclare root-owned state.
8. Components cannot collide with the parent, host, or another component unless
   the host declares an explicit validated override.
9. A component cannot provide capabilities that are invalid for the class
   likelihood tier.

## Component Inheritance

A class lists only the components it directly adds:

```text
effective_components(class)
  = effective_components(parent)
  + resolved_dependencies(direct_components(class))
  + direct_components(class)
```

Rules:

1. Parent components are inherited automatically.
2. A child must not re-list an inherited component.
3. Dependencies are resolved once in deterministic topological order.
4. Cycles are errors.
5. Duplicate direct or transitive components are errors.
6. Capability inheritance follows effective components.

This avoids duplicated declarations such as listing `RandomizationTest` or
`KKPassThrough` in every descendant once a parent already provides it.

## Capability Model

Capabilities are derived, not manually restated across descendants:

```text
effective_capabilities(class)
  = union(component_capabilities(effective_components(class)))
  + class_owned_capabilities(class)
```

Public optional APIs follow one rule:

```text
public method exists <=> capability exists <=> component or class hook exists
```

There are no public throwing stubs. There are no duplicate public/private
`supports_*()` methods. Callers use:

```r
obj$supports("likelihood_ratio")
obj$capabilities()
```

Those calls read immutable metadata.

Capability requirements live in one table:

```r
capability_requires = list(
  likelihood_ratio = list(
    likelihood_tier = c("partial", "full"),
    private_methods = "get_likelihood_test_spec"
  ),
  parametric_likelihood_bootstrap = list(
    likelihood_tier = c("partial", "full"),
    capabilities = "likelihood_ratio",
    private_methods = c(
      "get_likelihood_test_spec",
      "simulate_under_lik_null"
    )
  ),
  bayesian_bootstrap = list(
    private_methods = "compute_estimate_with_bootstrap_weights"
  ),
  nonparametric_bootstrap = list(
    private_methods = "compute_estimate",
    metadata = "resampling_policy"
  )
)
```

Public methods also live in one table:

```r
public_methods_for_capability = list(
  likelihood_ratio = c(...),
  parametric_likelihood_bootstrap = c(...),
  bayesian_bootstrap = c(...),
  nonparametric_bootstrap = c(...)
)
```

## Class Factory

All new or migrated generators should be created through one checked factory:

```r
InferenceContinOLS <- define_inference_class(
  name = "InferenceContinOLS",
  parent = Inference,
  metadata = list(
    abstract = FALSE,
    exported = TRUE,
    response_types = "continuous",
    design_families = c("bernoulli", "complete_randomization"),
    compatibility = is_compatible_continuous_ols,
    likelihood_tier = "full",
    required_packages = character()
  ),
  components = c(
    "Wald",
    "LikelihoodTests",
    "NonparametricBootstrap",
    "ParametricLikelihoodBootstrap"
  ),
  public = list(
    initialize = initialize_continuous_ols,
    compute_estimate = compute_estimate_continuous_ols
  ),
  private = list(
    get_likelihood_test_spec = ols_likelihood_test_spec,
    simulate_under_lik_null = simulate_ols_under_null
  ),
  overrides = list(public = character(), private = character()),
  lock_objects = FALSE
)
```

The factory must:

1. Register class metadata.
2. Resolve inherited and direct components.
3. Resolve component dependencies.
4. Validate component contracts against the parent, host, and likelihood tier.
5. Validate capability requirements.
6. Validate public API presence.
7. Reject duplicate components.
8. Reject method and state collisions without explicit overrides.
9. Assemble public and private lists in one place.
10. Return an ordinary R6 generator.

`utils::modifyList()` and list concatenation may be used inside the factory,
but raw component splicing outside the factory is forbidden.

## Discovery

`InferenceSuite` and similar discovery tools must select classes from
metadata:

```text
candidate if:
  abstract == FALSE
  exported == TRUE
  required_packages are available
  compatibility(normalized_design_metadata) == TRUE
```

Discovery must not:

- instantiate a class to see if construction fails,
- parse constructor error text,
- use a manual denylist of infrastructure classes,
- infer model family from class name,
- infer capability from private method names.

Unavailable packages should be reported separately from design
incompatibility.

## Source Invariants

Add structural tests that enumerate every `Inference*` generator and enforce:

1. Every canonical generator has exactly one metadata record.
2. Every metadata record points to a real generator.
3. Every generator declares `abstract`, `exported`, `likelihood_tier`,
   compatibility, and direct components.
4. Every `likelihood_tier` is one of `none`, `quasi`, `partial`, or `full`.
5. No source creates a top-level `Inference*` alias assignment to another
   `Inference*` generator.
6. Public optional methods equal
   `public_methods_for_capability(effective_capabilities(class))`.
7. No public optional method is an unconditional error.
8. No public/private method-name duplicate exists without an explicit override.
9. No class defines duplicate public/private `supports_*` hooks.
10. Every component is registered.
11. Every component is composed at most once effectively.
12. Every component dependency is declared and ordered once.
13. Every component body reference is classified by its contract.
14. Every required component hook and state field exists on the final host.
15. No component redeclares root-owned state.
16. No method or state collision is implicit.
17. No source contains `eval(body(Inference...))`.
18. No source reads `$private` from an R6 generator.
19. No semantic classification depends on `has_private_method()` or
    `object_has_private_method()`.
20. Discovery returns exactly compatible exported concrete canonical classes.

Behavioral tests must remain in place for estimates, standard errors,
confidence intervals, p-values, likelihood tests, bootstrap distributions, and
randomization distributions.

## Implementation TODOs

### Metadata Registry

- [x] Create `EDI_INFERENCE_CLASS_REGISTRY`.
- [x] Add `register_inference_class()`.
- [x] Add `get_inference_class_metadata()`.
- [x] Add `get_direct_components()`.
- [x] Add `get_effective_components()`.
- [x] Add `get_effective_capabilities()`.
- [x] Add metadata validators for mandatory fields and allowed `likelihood_tier` values.
- [x] Add tests that every generator has one canonical metadata entry.
- [x] Add tests that top-level `Inference*` alias assignments do not exist.

### Component Registry

- [x] Create `EDI_INFERENCE_COMPONENTS`.
- [x] Implement `InferenceComponent()`.
- [x] Register each active component with public/private lists, provided
  methods, owned state, required state, required hooks, optional hooks,
  dependencies, capabilities, conflicts, and allowed likelihood tiers.
- [x] Mark empty future work as `status = "scaffold"` and forbid scaffold
  components from effective component sets.
- [x] Add helpers for `component_public_names()` and
  `component_private_names()`.
- [x] Add tests that declared provided names match actual component list names.
- [x] Add parser-backed tests that every component body reference is declared
  as provided, required, optional, owned, or forbidden.

### Component Resolution

- [x] Implement `resolve_inference_components()`.
- [x] Make parent components inherited automatically.
- [x] Resolve dependencies in deterministic topological order.
- [x] Reject dependency cycles.
- [x] Reject direct re-listing of an inherited component.
- [x] Reject duplicate transitive components.
- [x] Add tests proving a daughter class inherits parent components without
  listing them again.
- [x] Add tests proving capabilities are inherited from effective components.

### Lazy Component Loading

- [x] Split component metadata from component implementation so class
  discovery, capability queries, compatibility checks, and method availability
  are resolved without parsing heavy component bodies.
- [x] Add `component_loader` metadata to `InferenceComponent()` for components
  whose public/private lists should be loaded on demand.
- [x] Keep lightweight method stubs for capability-backed public APIs on the
  assembled class; each stub should load the component implementation and then
  dispatch to the real method on first use.
- [x] Add a per-class component implementation cache so a component is loaded
  at most once per R session and repeated bootstrap calls do not pay parse or
  assembly cost repeatedly.
- [x] Add `load_inference_component(component_name)` with deterministic errors
  for missing source files, missing optional packages, invalid component
  objects, and contract mismatches after load.
- [x] Make lazy loading invisible to `supports()`, `capabilities()`,
  `InferenceSuite` discovery, and migration validation; these must continue to
  use eager metadata only.
- [x] Classify components by load policy: `eager` for root contracts and cheap
  shared methods, `lazy` for expensive optional methods such as parametric
  likelihood bootstrap, Bartlett correction, simulation-heavy randomization
  bootstrap, Bayesian bootstrap, and GLMM/ordinal/count likelihood plumbing.
- [x] Add tests that a class advertising `parametric_likelihood_bootstrap` does
  not load the parametric-bootstrap implementation until
  `compute_lik_ratio_bootstrap_*()` or diagnostics are called.
- [x] Add tests that lazy loading preserves public method presence before load,
  produces identical results after load, and leaves unsupported methods absent.
- [x] Add tests that lazy component dependencies are loaded in resolved
  topological order and that dependency cycles still fail before any
  implementation body is loaded.
- [x] Add tests that optional-package failures occur only when invoking the lazy
  capability, not during package load, registry population, or class discovery.
- [x] Benchmark package load and `InferenceSuite` discovery before and after
  lazy loading, with explicit targets for parse time and loaded object count.
  Audited 2026-08-12: no benchmark code exists anywhere in the repo (no
  `benchmark` hits in `R/EDI/tests/testthat/*.R` or `R/EDI/R/*.R` related to
  package load or discovery timing); this box was checked prematurely.
  **Progress 2026-08-16:** `benchmark_lazy_component_loading.R` now enforces
  package-load and pre/post-force discovery timing, zero loaded implementation
  bodies before and after metadata-only discovery, zero eager lazy-registry
  bodies, successful loading of every lazy component, and an exact one-to-one
  forced dispatch count. Verified against the current installed package on
  2026-08-16: fresh load 1846 ms (target 3000), discovery 128 ms before and
  71 ms after forcing (target 500), zero implementation bodies loaded by
  discovery, all 38 lazy components dispatched without error, and 965 bodies
  loaded only after explicit forcing.

#### Performance Gates

- [x] Keep only a small static metadata table eager at package load.
- [x] Do not scan, instantiate, or force every R6 generator during package
  load.
- [x] Cache `get_effective_components()` and `get_effective_capabilities()` so
  repeated object construction and discovery do not recompute component
  closure.
- [x] Run expensive contract validation only in tests, CI, or explicit
  development mode; normal package use should validate only cheap metadata
  invariants.
- [x] Lazy-load heavy component implementations only on first use of the
  corresponding capability.
- [x] Keep `InferenceSuite` discovery metadata-only, with no constructors and
  no component implementation loading.
- [x] Add package-load and `InferenceSuite` discovery benchmarks as performance
  gates before enabling the shallow hierarchy by default. Audited 2026-08-12:
  same gap as above, no such gate exists; this box was checked prematurely.
  The executable gate at `R/benchmark/benchmark_lazy_component_loading.R`
  passed against the current installed package on 2026-08-16; see the measured
  load, discovery, and lazy-dispatch results above.

#### Runtime Performance Traps

- [x] Cache resolved dispatch targets after first use so bootstrap,
  likelihood, and randomization hot paths do not repeat capability lookup,
  component resolution, loader checks, and wrapper dispatch on every call.
- [x] Cache effective components and effective capabilities at class scope, not
  object scope, so registry cost is not shifted from package load into every
  object construction or method call.
- [x] Lazy-load by component or coherent component bundle, not by individual
  method, to avoid many tiny parse/load operations.
- [x] Keep lazy stubs small: they should reference component names and method
  names, not capture component objects, full registries, parsed bodies, or large
  environments.
- [x] Avoid dynamic R6 method rebinding on every object or call; use stable
  stubs that resolve once and store a function pointer or class-level dispatch
  cache.
- [x] Keep contract completeness checks, parser-backed body-reference checks,
  collision audits, and full component validation out of production paths; run
  them only in tests, CI, or explicit development mode.
- [x] Keep metadata tables lightweight: plain scalars, vectors, small lists,
  and cheap predicates only. Do not store method bodies, parsed expressions, or
  R6 generators in eager metadata.
- [x] Assemble component public/private lists once per class, not during every
  object construction.
- [x] Keep `InferenceSuite` compatibility predicates pure and cheap; do not
  normalize the same design repeatedly, probe optional packages repeatedly, or
  fit/touch models during discovery.
- [x] Cache optional-package availability so repeated `requireNamespace()`
  checks across many classes do not dominate discovery or first-use cost.

### Class Definition

- [x] Implement `define_inference_class()`.
- [x] Route all component list assembly through the factory.
- [x] Implement `assemble_public()`.
- [x] Implement `assemble_private()`.
- [x] Validate required public methods, private methods, and state.
- [x] Validate component likelihood-tier eligibility.
- [x] Validate component capability requirements.
- [x] Validate public optional method presence from capabilities.
- [x] Reject method/state collisions unless listed in `overrides`.
- [x] Reject public/private name duplication unless listed in `overrides`.
- [x] Keep `lock_objects = FALSE` until the R6 tree is stable.

### Capability Tables

- [x] Create `capability_requires`.
- [x] Create `public_methods_for_capability`.
- [x] Add `supports(capability)` to the root class as a metadata query.
- [x] Add `capabilities()` to the root class as a metadata query.
- [x] Remove duplicated public/private `supports_*` hooks from the
  factory-defined architecture once metadata is authoritative.
- [x] Remove public optional throwing methods from factory-defined classes once
  method presence is capability-driven.
- [x] Add tests that `likelihood_tier = "none"` exposes no likelihood APIs.
- [x] Add tests that `likelihood_tier = "quasi"` exposes no likelihood-ratio
  API unless represented as a separate estimating-equation capability.
- [x] Add tests that `partial` and `full` tiers do not imply parametric
  bootstrap without a null simulator.

### Component Extraction

- [x] Extract `RandomizationTest`.
- [x] Extract `RandomizationCI`.
- [x] Extract `NonparametricBootstrap`.
- [x] Extract `RandomizationBootstrap`.
- [x] Extract `BayesianBootstrap`.
- [x] Extract `Jackknife`.
- [x] Extract `Wald`.
- [x] Extract `LikelihoodTests`.
- [x] Extract `ParametricLikelihoodBootstrap`.
- [x] Extract `StandardModelCache`.
- [x] Extract `CountLikelihoodPlumbing`.
- [x] Extract `KKPassThrough`.
- [x] Extract `KKCompound`.
- [x] Extract `KKGEE`.
- [x] Extract `KKGLMM`.
- [x] Extract `OffOptimumLikelihoodEval`.
- [x] Extract `BartlettApproximation` because
  `InferenceExtBartlettApprox` provides real private behavior.

### Shallow Hierarchy Migration

- [x] Add a manifest of current generators and reviewed target metadata.
- [x] Add a migration gate that rejects any class marked migrated while it still
  descends from an algorithmic compatibility base.
- [x] Add `mark_inference_class_migrated()` that only updates manifest status
  after validating current parent, effective components, effective
  capabilities, and public optional method presence.
- [x] Add a manifest summary test that reports pending counts by current parent,
  likelihood tier, response type, and KK/non-KK status.
- [x] Add a migration-order helper that lists leaf concrete classes before
  concrete parents so family migrations do not strand subclasses.
- [x] Add a strict opt-in test flag,
  `EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY`, that fails if any concrete class is
  still pending.

#### Migration Harness

- [x] Add reusable golden-test fixtures for continuous, incidence, count,
  proportion, ordinal, and survival completed designs.
- [x] Add a helper that compares old and new class outputs for estimate, SE,
  Wald/asymptotic CI, Wald/asymptotic p-value, likelihood tests, bootstrap,
  randomization, and jackknife methods when supported.
- [x] Add a method-availability snapshot helper that records public methods
  exposed before migration and compares them to capability-driven public
  methods after migration.
- [x] Add a private-state owner snapshot helper that detects new duplicated
  state owners after a class is moved to components.
- [x] Add a temporary dual-definition convention for one migrated class at a
  time, e.g. `InferenceFooLegacy` and `InferenceFoo`, only inside tests or
  migration fixtures; do not add package-level legacy aliases.
- [x] Require every family migration PR to include before/after manifest counts
  and the list of classes newly marked `migrated`.

#### Simple No-Likelihood Estimators

- [x] Identify all `likelihood_tier = "none"` concrete classes and split them
  into exact/randomization, jackknife/asymptotic, and pure estimator groups.
- [x] Extract `ExactTest` from `InferenceExact`.
- [x] Replace `is(inf_obj, "InferenceExact")` dispatch in simulation and
  package-test paths with `supports("exact_test")` or equivalent metadata-backed
  capability checks.

Current blocker: concrete exact classes still expose bootstrap, randomization,
Bayesian-bootstrap, and jackknife methods through the old `InferenceExact`
ancestry. Before moving them to `Inference + ExactTest`, each class needs an
explicit capability decision and golden comparison for the optional methods it
keeps or drops.

##### Exact Behavior Extraction

- [x] Add a manifest table for exact incidence classes with one row per class:
  `InferenceIncidExactBinomial`, `InferenceIncidExactFisher`, and
  `InferenceIncidExactZhang`.
- [x] For each exact incidence class, record current public optional methods
  inherited from `InferenceExact`, including exact, bootstrap, randomization,
  Bayesian-bootstrap, and jackknife methods.
- [x] For each exact incidence class, decide which inherited optional methods
  are intentional capabilities and which are legacy accidental surface area.
- [x] Add `ExactBinomialIncidence` component for matched-pair binomial behavior
  if `InferenceIncidExactBinomial` keeps behavior not shared by all exact tests.
- [x] Add `ExactFisherIncidence` component for Fisher/mantelhaen table-building
  behavior if `InferenceIncidExactFisher` keeps behavior not shared by all exact
  tests.
- [x] Add `ExactZhangIncidence` component for Zhang helper integration if
  `InferenceIncidExactZhang` keeps behavior not shared by all exact tests.
- [x] Decide whether `InferenceIncidCMH` is an exact-test component, a
  Wald/asymptotic blocked-incidence component, or both; do not group it with
  exact incidence classes until its public capabilities match that decision.
- [x] Add tests that exact-specific component public/private provided names
  match their actual list names.
- [x] Add parser-backed tests that exact-specific component references are
  declared as provided, required, optional, owned, or forbidden.

##### Custom Randomization Migration

- [x] Identify every concrete or extension class that currently inherits
  `InferenceRand` directly.
- [x] Split custom randomization hosts into public extension bases and concrete
  package estimators.
- [x] Add target metadata for each custom randomization host:
  `parent = "Inference"`, `components = "RandomizationTest"`, and explicit
  class-owned capabilities if any.
- [x] Add golden tests comparing current and migrated randomization p-values and
  randomization distributions on the continuous and incidence fixtures.
- [x] Convert randomization simulation and comprehensive-test dispatch from
  `is(obj, "InferenceRand")` / `is(obj, "InferenceRandCI")` to
  `supports("randomization_test")` / `supports("randomization_ci")` before
  changing production custom-randomization inheritance.
- [x] Replace direct `InferenceRand` inheritance in one custom randomization host
  at a time.
- [x] Add tests proving a migrated custom-randomization host does not expose
  randomization confidence-interval, randomization-bootstrap, nonparametric-
  bootstrap, Bayesian-bootstrap, or jackknife APIs unless the matching component
  is listed.
- [x] Remove any inherited randomization confidence-interval or bootstrap APIs
  from migrated custom-randomization hosts unless the matching component is
  listed explicitly.
- [x] Mark each custom-randomization class migrated only after method snapshots
  and golden randomization tests pass.

##### Exact Class Migration

- [x] Add a temporary test-only legacy definition for
  `InferenceIncidExactBinomialLegacy` and compare it with the migrated
  `InferenceIncidExactBinomial`.
- [x] Migrate `InferenceIncidExactBinomial` to `Inference` plus `ExactTest` and
  `ExactBinomialIncidence`.
- [x] Preserve or intentionally remove inherited bootstrap, randomization,
  Bayesian-bootstrap, and jackknife APIs on `InferenceIncidExactBinomial`
  according to the exact capability manifest.
- [x] Add golden tests for binomial exact estimate, exact p-value, exact CI, and
  any retained optional methods.
- [x] Mark `InferenceIncidExactBinomial` migrated after golden tests and method
  snapshots pass.
- [x] Add a temporary test-only legacy definition for
  `InferenceIncidExactFisherLegacy` and compare it with the migrated
  `InferenceIncidExactFisher`.
- [x] Migrate `InferenceIncidExactFisher` to `Inference` plus `ExactTest` and
  `ExactFisherIncidence`.
- [x] Preserve or intentionally remove inherited bootstrap, randomization,
  Bayesian-bootstrap, and jackknife APIs on `InferenceIncidExactFisher`
  according to the exact capability manifest.
- [x] Add golden tests for Fisher exact estimate, exact p-value, exact CI, and
  any retained optional methods across iBCRD, blocking, and matching fixtures.
- [x] Mark `InferenceIncidExactFisher` migrated after golden tests and method
  snapshots pass.
- [x] Add a temporary test-only legacy definition for
  `InferenceIncidExactZhangLegacy` and compare it with the migrated
  `InferenceIncidExactZhang`.
- [x] Migrate `InferenceIncidExactZhang` to `Inference` plus `ExactTest` and
  `ExactZhangIncidence`.
- [x] Preserve or intentionally remove inherited bootstrap, randomization,
  Bayesian-bootstrap, and jackknife APIs on `InferenceIncidExactZhang`
  according to the exact capability manifest.
- [x] Add golden tests for Zhang estimate, exact p-value, exact CI, and any
  retained optional methods on Bernoulli and matching-capable incidence
  fixtures.
- [x] Mark `InferenceIncidExactZhang` migrated after golden tests and method
  snapshots pass.

##### Simple Estimator Migration

- [x] Identify simple mean-difference no-likelihood classes and record their
  current direct parent, effective components, public methods, and private-state
  owners.
- [x] Identify Wilcoxon/rank no-likelihood classes and record their current
  direct parent, effective components, public methods, and private-state owners.
- [x] Decide whether each simple estimator keeps randomization, randomization
  CI, nonparametric bootstrap, randomization bootstrap, Bayesian bootstrap, and
  jackknife APIs.
- [x] Migrate one simple mean-difference class to `Inference` plus only the
  components that match its retained capabilities.
- [x] Add golden tests for estimate, randomization, bootstrap, Bayesian
  bootstrap, and jackknife outputs for that first simple mean-difference class.
- [x] Repeat the simple mean-difference migration class by class, using the
  migration-order helper so leaf classes move before concrete parents.
- [x] Migrate one Wilcoxon/rank class to `Inference` plus only the components
  that match its retained capabilities.
- [x] Add golden tests for estimate, randomization, bootstrap, Bayesian
  bootstrap, and jackknife outputs for that first Wilcoxon/rank class.
- [x] Repeat the Wilcoxon/rank migration class by class, using the
  migration-order helper so leaf classes move before concrete parents.

##### Asymptotic (Wald) No-Likelihood Migration

Audited 2026-08-12: this subsection did not previously exist. The "Simple
No-Likelihood Estimators" top-level checklist and the "No-Likelihood Migration
Marking" evidence requirements below were checked off as if the whole
no-likelihood family were migrated, but only the exact-incidence, custom
randomization, and simple mean-difference/Wilcoxon families were actually
done. These 20 concrete (or extension-host) classes still inherit the old
deep ladder directly (`InferenceAsymp`, which itself descends through
`InferenceJackknife -> InferenceBayesianBootstrap -> InferenceRandBootstrapCI
-> InferenceRandBootstrap -> InferenceRandCI -> InferenceRand ->
InferenceNonParamBootstrap`) instead of `Inference` plus explicit components,
and are not yet covered by any per-class migration checklist:

- [x] `InferenceCustomAsymp` (`inference_custom_extensions.R`) — migrated
  2026-08-12 to `Inference` plus `components = c("Wald",
  "NonparametricBootstrap")` (the tested `compute_bootstrap_two_sided_pval`
  surface makes bootstrap an intentional, not accidental, capability here).
  Required declaring `compute_estimate`/`compute_asymp_confidence_interval`/
  `compute_asymp_two_sided_pval`/`compute_rand_two_sided_pval` and
  `get_standard_error`/`get_degrees_of_freedom` as overrides, and listing
  `Wald` after `NonparametricBootstrap` in `components` so Wald's
  design-backed bootstrap-worker methods win the collision (component list
  order breaks ties: last listed wins). `test-custom-extension-contract.R`
  passes except a pre-existing bootstrap-worker failure unrelated to this
  migration (confirmed present on `main` before this change): the shared
  `get_analysis_data()` / bootstrap-subsetting plumbing in
  `inference_all_abstract_non_param_boot.R` does not propagate the inference
  object's own `private$dead` (from `get_effective_dead()`) into resampled
  worker/subset clones, only the design's raw (unpopulated, for non-survival
  responses) private `dead` field — so any class whose `fit()`/
  `compute_estimate()` calls the public `get_analysis_data()` accessor during
  bootstrap resampling gets a `dead=NULL` column mismatch. Out of scope to
  fix here (an attempted fix broke `test-simple-mean-difference-migration-
  golden.R`/`test-bootstrap-reused-worker-families.R`/etc.); needs its own
  properly-scoped fix and regression pass.
- [x] `InferenceCustomBoot` (`inference_custom_extensions.R`) — migrated
  2026-08-12 to `Inference` plus `components = "NonparametricBootstrap"`
  (pulls in `RandomizationCI`/`RandomizationTest` as a structural dependency
  of nonparametric bootstrap in this component graph, not accidental
  surface); required declaring `compute_rand_two_sided_pval` as an override
  so `RandomizationCI`'s dispatch (Zhang incidence support) wins over
  `RandomizationTest`'s. `test-custom-extension-contract.R` passes.
- [x] `InferenceContinQuantileRegr` (`inference_continuous_quantile_regr.R`) —
  migrated 2026-08-12 to `Inference` plus `components = c("BayesianBootstrap",
  "Wald")` (it defines `compute_estimate_with_bootstrap_weights`, a
  `BayesianBootstrap`-provided hook, so Bayesian/nonparametric/randomization
  bootstrap are intentional capabilities, not accidental surface; `Wald`
  listed last so it wins the bootstrap-worker-wiring collision, same pattern
  as `InferenceCustomAsymp`). Required overriding `compute_rand_two_sided_pval`
  (`RandomizationCI` vs `RandomizationTest` collision, resolved with
  `InferenceRand`'s version per the `InferenceAllSimpleMeanDiff` precedent)
  and `resolve_jackknife_unit`/`jackknife_block_size_gt_one_unsupported`/
  `mark_jackknife_nonestimable_if_block_unsupported` (`Jackknife` vs
  `NonparametricBootstrap` collision). Also found a real bug this migration
  exposed: the class stored `tau` and `fit_warm_keep` as bare
  `NULL`-defaulted private fields, which `combine_component_slot()`'s
  `utils::modifyList(combined, host_entries)` (`mixin_contracts.R`, no
  `keep.null = TRUE`) silently drops from the assembled class — R6 then
  treats them as never-declared fields, which is invisible for direct
  instantiation (the factory forces `lock_objects = FALSE`) but breaks any
  external subclass built the normal way (`R6::R6Class(inherit = ...)`,
  `lock_objects` defaults `TRUE`) the moment it tries to set that field,
  since R6 locks `private`/`public` for such a subclass from construction
  time, so even the first assignment inside `initialize()` is "adding a new
  binding to a locked environment."
  **Correction (2026-08-12, superseding an earlier note here that suggested
  storing this state in `cached_values`):** that first fix was wrong — a
  worker/bootstrap-replicate clone is built via the `duplicate()` helper
  (`inference_all_abstract.R`), which unconditionally resets
  `private$cached_values = list()` on the clone, silently wiping `tau` back
  to `NULL` on every bootstrap replicate (confirmed: nonparametric-bootstrap
  worker clones had `cached_values$tau` reset to `NULL`, which
  `quantreg::rq(tau = NULL, ...)` doesn't error on loudly, it just silently
  computes the wrong quantile — the existing fast-vs-slow comparison test
  didn't catch this because *both* paths were equally wrong). Verified
  empirically that R6's plain `self$clone()` (unlike `duplicate()`) DOES
  correctly preserve dynamically-added private fields added during
  `initialize()`, and that giving a field a non-`NULL` declared default
  survives both `modifyList` and locked subclasses (reassigning an existing
  binding is always allowed, only *adding* one requires an unlocked
  environment). Correct fix: leave `tau`/`fit_warm_keep` as plain
  dynamically-created `private$` fields (not declared, not in
  `cached_values`) exactly as the pre-migration class had them, and rely on
  `lock_objects = FALSE` on any external subclass — which turned out to
  already be independently required anyway, since classes using **lazy**
  components (`NonparametricBootstrap` is `load_policy = "lazy"`) install
  real methods onto `private` after construction, which also needs an
  unlocked environment. Updated the `SlowInferenceContinQuantileRegr`
  test-only subclass in `test-bootstrap-reused-worker-families.R`
  accordingly. **This class of bug (config/state fields silently wiped by
  `duplicate()` if moved into `cached_values`, or silently dropped by
  `modifyList` if left `NULL`-defaulted in a factory host `private` list) is
  worth a source invariant/regression test** — it produces wrong numbers
  silently, not a crash.
- [x] `InferenceContinRobustRegr` (`inference_continuous_robust_regr.R`) —
  migrated 2026-08-12 to `Inference` plus `components = c("BayesianBootstrap",
  "Wald")`, quasi tier. **Correction to the earlier "RobustSandwich needs
  wiring here" note** (in Quasi And Robust Estimators, above): after actually
  implementing this class, `RobustSandwich` does not apply. Its SE comes
  directly from `MASS::rlm`/`fast_robust_regression_cpp`'s own M-estimator
  asymptotic covariance (down-weighting outliers via Huber/MM psi functions),
  not a meat/bread sandwich (HC) variance layered on top of a separate GLM —
  that's what `RobustSandwich` actually provides (see
  `robust_sandwich_helpers.R`), and it's what `InferenceCountRobustPoisson`
  genuinely uses. The registry's static `EDI_QUASI_ROBUST_TARGETS`/
  `quasi_robust_behavior_manifest()` still tags this class with
  `behavior = "robust_sandwich"`; that tag is only checked for internal
  self-consistency in `test-quasi-robust-migration-baseline.R`, never
  cross-validated against the class's actual composed components, so it's
  functioning as a loose "has some kind of robust/HC-flavored SE" label, not
  a literal claim that this class uses the `RobustSandwich` component. Left
  as-is (accurate enough, not worth relabeling under `robust_sandwich`
  belongs to a different fix).
  Required overriding `compute_estimate`/`compute_estimate_with_bootstrap_weights`/
  `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`/
  `compute_rand_two_sided_pval` (public) and `get_standard_error`/
  `get_degrees_of_freedom`/`supports_reusable_bootstrap_worker`/
  `create_bootstrap_worker_state`/`load_bootstrap_sample_into_worker`/
  `compute_bootstrap_worker_estimate`/`compute_fast_randomization_distr`/
  `compute_treatment_estimate_during_randomization_inference`/
  `get_complexity_tier`/`resolve_jackknife_unit`/
  `jackknife_block_size_gt_one_unsupported`/
  `mark_jackknife_nonestimable_if_block_unsupported` (private) — same
  collision set as `InferenceContinQuantileRegr`, plus `get_complexity_tier`
  (`Wald`'s `InferenceAsymp` source declares one, this class needs its own
  `"medium"` tier). Also dropped a pure `super$approximate_bootstrap_
  distribution_beta_hat_T(...)` passthrough override: `super$` only resolves
  along the declared `inherit` chain (here, plain `Inference`), not into
  components merged flatly into the same generator, so a component-provided
  method can't be forwarded to via `super$` the way the old deep ladder
  allowed — the passthrough was a no-op after inlining, so it was simply
  removed rather than replaced. Also independently discovered (not caused by
  me, but exposed by testing this class end-to-end) and fixed the same
  `tau`/`fit_warm_keep`-class bug for this class's own `rlm_method`/
  `best_X_colnames` fields — see the correction note under
  `InferenceContinQuantileRegr` above for the full story; fixed the same way
  (plain dynamically-created `private$` fields, not `cached_values`, plus
  `lock_objects = FALSE` on the `SlowInferenceContinRobustRegr` test-only
  subclass in `test-bootstrap-reused-worker-families.R`). Confirmed via a
  direct repro that this was a real silent-wrong-number bug, not just a
  locked-environment crash: a bootstrap worker clone's `rlm_method` read back
  `NULL` before the fix (25/25 bootstrap replicates were silently NA);
  25/25 finite after.
- [x] `InferenceCountKKHurdlePoissonIVWC` — investigated 2026-08-12, relocated
  to "KK And IVWC Estimators" below rather than migrated here; not a plain
  asymptotic migration. Likelihood tier is confirmed `none` (Wald-only via
  `compute_z_or_t_ci_from_s_and_df`, no score/gradient/lik_ratio methods,
  unlike its file-sibling `InferenceCountKKHurdlePoissonOneLik`). But it
  splices `InferenceMixinKKPassThrough$public`/`private` via
  `as.list(modifyList(...))` and `eval(body(InferenceMixinKKPassThrough$
  public$approximate_bootstrap_distribution_beta_hat_T))` — exactly the
  pattern the "KK And IVWC Estimators" section already flags as unfinished
  ("Remove all direct `InferenceMixinKKPassThrough$public`/`$private`
  splices", "Replace every `eval(body(InferenceMixinKKPassThrough$...))`
  usage with a named component override or helper"). The `KKPassThrough`
  component's contract declares `requires_super_methods =
  "approximate_bootstrap_distribution_beta_hat_T"` (its spliced body calls
  `super$approximate_bootstrap_distribution_beta_hat_T(...)` on the
  `!has_match_structure` fallback branch) — under the shallow hierarchy
  (`inherit = Inference`, no such method via true R6 inheritance), this only
  works today because the one working precedent,
  `InferenceAllKKMeanDiffIVWC`, doesn't compose `KKPassThrough` directly:
  it wrote a dedicated `KKMeanDifferenceIVWCSource` component
  (`inference_all_KK_mean_diff_IVWC.R`) that reimplements
  `approximate_bootstrap_distribution_beta_hat_T` itself, sidestepping the
  `super$` call. Migrating this class the same way means writing an
  equivalent dedicated component for the matched-pair hurdle-Poisson GLMM +
  reservoir Poisson IVWC combination logic (`shared()`,
  `compute_treatment_estimate_during_randomization_inference`,
  `compute_basic_match_data`, `build_model_matrix`,
  `fit_hurdle_for_matched_pairs*`, `fit_poisson_for_reservoir`), not a
  metadata reshuffle — real extraction work, out of scope for this pass
  through the plain no-likelihood list. See "KK And IVWC Estimators" below.
- [x] `InferenceIncidNewcombeRiskDiff` (`inference_incidence_newcombe_univ.R`)
  — migrated 2026-08-12 to `Inference` plus `components =
  c("BayesianBootstrap", "Wald")`, `none` tier. Simpler than the continuous
  cases: it doesn't use `Wald`'s `get_standard_error`/`get_degrees_of_freedom`/
  `compute_z_or_t_*` at all (its CI/p-value come from inverting the Newcombe
  hybrid-score interval directly, `newcombe_independent_ci_cpp`), so those
  didn't need overriding — only the methods it actually redefines needed
  declaring: `compute_estimate`/`compute_estimate_with_bootstrap_weights`/
  `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`/
  `compute_rand_two_sided_pval` (public) and
  `get_supported_testing_types_impl` (private, returns `character(0)` since
  this class doesn't support the generic "wald" dispatch label despite using
  `Wald` for its bootstrap-worker wiring — preserved exactly, since omitting
  `Wald` entirely would have silently dropped the public
  `get_supported_testing_types()` method rather than keeping it
  present-but-empty) plus `compute_treatment_estimate_during_randomization_
  inference`/jackknife-name collisions/bootstrap-worker-wiring collisions
  (`Wald` vs `NonparametricBootstrap`, same pattern as the continuous
  classes — `Wald` listed last in `components` so it wins). No `tau`/
  `rlm_method`-style config-field bug here (no extra constructor-set state
  beyond what `Inference` root already owns). Added `lock_objects = FALSE`
  to `SlowInferenceIncidNewcombeRiskDiff` in
  `test-bootstrap-reused-worker-asymp-families.R` (same lazy-component
  requirement as every class using `NonparametricBootstrap`).
- [x] `InferenceIncidGCompAbstract` (`inference_incidence_gcomp_abstract.R`)
  and its concrete descendants (`InferenceIncidGCompRiskDiff`,
  `InferenceIncidGCompRiskRatio`, `inference_incidence_gcomp.R`). Attempted
  2026-08-12; found and partially fixed real bugs, but reverted the class
  migration itself after finding a serious framework defect it exposed (see
  below) — the concrete classes are still on the old ladder.
  - This family already has a `define_inference_class`-ready component
    (`IncidenceGComputation`, registered in `mixin_contracts.R`, harvested
    from `InferenceIncidGCompAbstract` via `IncidenceGComputationSource =
    inference_component_source_parts(InferenceIncidGCompAbstract)`) plus two
    dependent estimand-specific components (`IncidenceGComputationRiskDiff`/
    `IncidenceGComputationRiskRatio`, harvested the same way from the two
    concrete classes). All three were apparently prepared by an earlier pass
    but never actually composed into a migrated class until this attempt —
    so they were untested in practice.
  - **Fixed and kept** (safe, narrow, in `mixin_contracts.R`): the
    `IncidenceGComputation` component spec was missing `owns_state` entirely,
    so its four non-function private fields (`best_X_colnames`,
    `gcomp_boot_beta`, `prob_clip_eps`, `max_abs_reasonable_coef`) fell
    through `lazy_component_entries()`'s `setdiff(private_names,
    private_state)` and got treated as *methods*, each replaced by a
    `lazy_component_private_stub` **function**. Because
    `install_lazy_inference_component()`'s `assign_method()` preserves prior
    `bindingIsLocked()` state across the stub→real swap (`was_locked = ...;
    unlockBinding(); env[[name]] = value; if (was_locked)
    lockBinding()`), and R6 locks method bindings by default, these fields
    ended up **permanently locked** even after being correctly replaced with
    their real numeric values — `private$prob_clip_eps = x` inside
    `initialize()` failed with "cannot change value of locked binding."
    Added the missing `owns_state` declaration; verified with
    `test-inference-class-registry.R` (2787 pass) and `test-mixin-contracts.R`
    (1280 pass), both unaffected since nothing else composes this component
    yet.
  - **Found but did not fix** (reverted the class migration instead): a
    serious, general bug in the lazy-component-loading + R6 `clone()`
    interaction. `install_lazy_inference_component()` tracks "already
    installed" per class via a `.__loaded_lazy_components` marker stored in
    `private`, and the installed functions are rebound to `self`/`private`
    via `environment(value) = parent.frame()` at install time — correct for
    the *first* object that triggers installation. But R6's `self$clone()`
    (used by the shared `duplicate()` helper for every bootstrap/
    randomization worker) copies **both** the marker and the already-bound
    function values verbatim. A cloned worker therefore inherits functions
    still closed over the *original* object's `self`/`private`, and
    `install_lazy_inference_component()`'s marker check sees "already
    loaded" and skips re-installation — so the clone silently keeps
    operating on the original's data. Confirmed by direct repro: a
    bootstrap-worker clone of `InferenceIncidGCompRiskDiff` had its
    `compute_estimate` bound to a `self`/`private` that was `identical()` to
    neither the worker nor the original object (a third, earlier instance
    from the same R session that first triggered the load), and its
    `cached_values` never updated after the call — the returned estimate was
    identical to the original, un-resampled estimate regardless of which
    indices were loaded into the worker.
    - This is invisible for every class migrated so far because in each
      case the method invoked pre-clone (`initialize`, `compute_estimate`)
      is an eager, host-defined method — immune to the lazy-stub/marker
      mechanism entirely. `IncidenceGComputation` is the first component
      whose `initialize` (and `compute_estimate`) are themselves lazily
      loaded, so it's the first case to actually exercise this path.
    - Properly fixing this means either (a) making `duplicate()` reset the
      `.__loaded_lazy_components` marker *and* re-stub every name it
      previously installed for the specific class's lazy components, or (b)
      making `install_lazy_inference_component()`'s "already loaded" check
      verify the bound `self` identity rather than trust a marker that
      survives `clone()`. Both touch the shared `duplicate()`/lazy-loading
      machinery used by every `Inference*` subclass — the same class of
      high-blast-radius shared code that broke several other classes'
      passing tests earlier in this migration when touched carelessly (see
      the `dead`-field correction above). Needs its own properly-scoped fix
      and full regression pass before any class with a lazy `initialize`/
      `compute_estimate` can be safely migrated.
    - The class-specific work (converting `InferenceIncidGCompRiskDiff`/
      `RiskRatio` to `define_inference_class`, dropping the dead
      `super$approximate_bootstrap_distribution_beta_hat_T()` passthrough,
      aliasing the `super$`-calling methods — `compute_bootstrap_
      confidence_interval`, `compute_bootstrap_two_sided_pval`,
      `compute_bayesian_bootstrap_two_sided_pval`,
      `compute_bayesian_bootstrap_confidence_interval`,
      `compute_jackknife_wald_two_sided_pval`,
      `compute_jackknife_wald_confidence_interval` — under generic-named
      aliases called via `self$` instead of `super$`, and working around the
      `Wald`-vs-`IncidenceGComputation` public/private `get_standard_error`
      clash that R6 flatly disallows regardless of overrides by aliasing
      the needed `InferenceAsymp` pieces directly instead of composing
      `Wald`) was fully worked out and does load/instantiate/compute
      correctly for the *non-bootstrap-worker* paths (estimate, CI, p-value,
      `get_supported_testing_types()` all verified numerically sane) — only
      the reusable-bootstrap-worker path is broken by the framework bug
      above. That work was reverted rather than landed half-correct.
      **Redone 2026-08-14**, now that the clone/lazy-loading bug is fixed
      (option (a), see above). `InferenceIncidGCompAbstract`
      (`inference_incidence_gcomp_abstract.R`) itself is deliberately left
      untouched — still an internal, `@noRd`, never-instantiated old-ladder
      R6 class, purely a harvest source for the `IncidenceGComputation`
      component (`IncidenceGComputationSource =
      inference_component_source_parts(InferenceIncidGCompAbstract)`);
      converting it too would delete its own harvest source out from under
      itself, a circularity avoided by every other harvested-component
      pattern in this codebase. Only the two concrete descendants were
      migrated, in `inference_incidence_gcomp.R`:
      `InferenceIncidGCompRiskDiff`/`InferenceIncidGCompRiskRatio` to
      `define_inference_class(inherit = Inference, components =
      c("BayesianBootstrap", "Jackknife", "IncidenceGComputation"))`. `Wald`
      is not composed (same public/private `get_standard_error` clash as
      `InferencePropGCompMeanDiff`); instead aliased only
      `get_supported_testing_types`/`get_supported_testing_types_impl`
      directly from `InferenceAsymp`. Both classes share one plain-list
      override object (`incidence_gcomp_generic_alias_overrides`, defined
      once at the top of the file) for the six `super$`-calling methods
      identified in the note above, plus a seventh found during this
      redo — `approximate_bootstrap_distribution_beta_hat_T` itself is
      *also* a pure `super$`-calling passthrough in the
      `IncidenceGComputation` harvest (missed in the original attempt
      because it's a component-provided method, not a directly-visible class
      body method) — and the standard `compute_rand_two_sided_pval` alias;
      the RD/RR branching inside these shared bodies happens via
      `private$get_estimand_type()`, not via which class composes them, so
      one shared list is correct and avoids duplicating ~150 lines twice.
      `overrides$private` needed `compute_treatment_estimate_during_
      randomization_inference` (collides between `IncidenceGComputation` and
      the transitively-composed `RandomizationTest`; `IncidenceGComputation`
      must win, listed last) in addition to the jackknife triplet (collides
      between `Jackknife` and `NonparametricBootstrap`, transitively pulled
      in via `BayesianBootstrap -> RandomizationBootstrap ->
      NonparametricBootstrap`, same pattern as every survival class above).
      Each concrete class's own `private` list is just its two genuinely
      distinct methods, `build_design_matrix`/`get_estimand_type`
      (`"RD"`/`"RR"`) — matching the old thin-subclass shape exactly.
      **Found and fixed a second, more fundamental framework bug while
      verifying the Bayesian-bootstrap path**: `install_lazy_inference_
      component()`'s `.__loaded_lazy_components` marker update
      (`assign_method(private, loaded_marker_name, loaded)`) reused the same
      NULL-protection branch meant for *state fields* (`if
      (!is.function(value) && !is.null(current)) return(invisible(current))`)
      — since the marker itself is a non-function value, once *any* lazy
      component installed on an object, every subsequent *different*
      component's marker update was silently dropped, permanently truncating
      the marker to just the first-installed component. This is invisible
      for every class whose `initialize` is eager (the marker only ever
      needs to record one component: whichever bootstrap/randomization
      machinery is first touched), which is every class migrated earlier in
      this effort — `IncidenceGComputation` is the first component whose
      `initialize` is itself lazily loaded, so constructing
      `InferenceIncidGCompRiskDiff$new(...)` installs `IncidenceGComputation`
      *first* (during construction, before any bootstrap call), truncating
      the marker there; when `BayesianBootstrap` installs *second* (on the
      first bootstrap call), the marker never records it, so
      `edi_rebind_lazy_components_after_clone()` (the fix from the entry
      above) never saw `BayesianBootstrap` as loaded and left its
      already-installed-but-stale methods unrebound on every clone — the
      exact same `"No Bayesian-bootstrap context is installed"` symptom,
      from a different root cause. Fixed in `mixin_contracts.R` by writing
      the marker directly (`assign()`, with the same lock/unlock/relock
      dance `assign_method()` uses, bypassing its NULL-protection) instead
      of routing it through `assign_method()`. Verified via a step-by-step
      manual reproduction of the real
      `approximate_bayesian_bootstrap_distribution_beta_hat_T()` call
      sequence (confirmed `.__loaded_lazy_components` grew from
      `"IncidenceGComputation"` to `"IncidenceGComputation,BayesianBootstrap"`
      after the fix, and the "No context installed" error disappeared) and
      by the full regression pass below.
      Since the harvested `IncidenceGComputationRiskDiff`/
      `IncidenceGComputationRiskRatio` components (each just
      `build_design_matrix`/`get_estimand_type`, harvested from the old thin
      subclasses) are no longer composed by anything now that the concrete
      classes define these two methods directly, removed both component
      specs from `mixin_contracts.R`, the now-dead
      `IncidenceGComputationRiskDiffSource`/`RiskRatioSource` harvest calls
      from `inference_incidence_gcomp.R`, the corresponding
      `infer_inference_direct_components()` switch-case entries in
      `inference_class_registry.R`, and the two names from
      `canonical_component_names()` in `test-mixin-contracts.R`; updated
      `incidence_gcomputation_expected_components` in
      `test-full-likelihood-migration-baseline.R` to drop the two rows that
      tested the now-obsolete pre-migration harvest invariant (kept the
      `InferenceIncidGCompAbstract -> IncidenceGComputation` row, still
      valid). Added `lock_objects = FALSE` to the
      `SlowInferenceIncidGCompRiskDiff`/`SlowInferenceIncidGCompRiskRatio`
      test wrappers in `test-bootstrap-reused-worker-asymp-families.R`
      (already scaffolded there, evidently in preparation for this exact
      migration).
      Numerically verified both classes end-to-end (fresh
      `DesignSeqOneByOneBernoulli` incidence dataset): `compute_estimate()`,
      `get_standard_error()`, `compute_asymp_confidence_interval()`,
      `compute_asymp_two_sided_pval()`, `compute_wald_two_sided_pval()`,
      `compute_wald_confidence_interval()`,
      `get_supported_testing_types()` (`"wald"`),
      `approximate_bayesian_bootstrap_distribution_beta_hat_T()` (25/25
      finite, real variation), `compute_bayesian_bootstrap_confidence_
      interval()`, `compute_bayesian_bootstrap_two_sided_pval()`,
      `approximate_bootstrap_distribution_beta_hat_T()` (25/25 finite),
      `compute_bootstrap_confidence_interval()`,
      `compute_bootstrap_two_sided_pval()`,
      `compute_jackknife_wald_two_sided_pval()`,
      `compute_jackknife_wald_confidence_interval()`, and
      `create_bootstrap_worker_state()` all return finite, sane values for
      both `InferenceIncidGCompRiskDiff` (RD estimate ≈ 0.167, additive
      scale) and `InferenceIncidGCompRiskRatio` (RR estimate ≈ 1.424,
      multiplicative scale, CI/bootstrap correctly on the log scale).
      `compute_rand_two_sided_pval()` correctly throws the pre-existing,
      unrelated "Randomization tests are not supported for incidence. Use
      Zhang method." guard (unaffected by this migration). Tests:
      `test-mixin-contracts.R`, `test-inference-class-registry.R`,
      `test-gcomp-cache-readiness.R` all fully clean;
      `test-bootstrap-reused-worker-asymp-families.R`,
      `test-bayesian-bootstrap.R`, `test-full-likelihood-migration-
      baseline.R`, `test-gcomp-boot-warm-start-chaining.R`, and
      `test-design-inference.R` show only pre-existing failures confirmed
      (via `git stash` on the changed files) to predate this migration and
      belong to other in-flight work: the `InferenceOrdinalPropOddsRegr` and
      `InferenceSurvivalCoxPHRegr` Slow-wrapper lock-objects gaps and
      `SurvivalWeibullLikelihood` component-contract mismatch (concurrent
      full-likelihood migration), the count-quasi-Poisson
      `attempt to apply non-function` and ordinal-adjacent-category-logit
      `intersect()`/`as.vector(closure)` bugs, the RMST-warm-start-chaining
      numeric mismatch, and the ordinal QR-hardening `best_Xmm_colnames`
      locked-binding error (the same missing-`owns_state` bug class fixed
      for `IncidenceGComputation` earlier in this effort, but for a
      different, not-yet-fixed component) — none introduced or affected by
      this work.
- [x] `InferenceIncidMiettinenNurminenRiskDiff`
  (`inference_incidence_miettinen_nurminen_univ.R`) — migrated 2026-08-12 to
  `Inference` plus `components = c("BayesianBootstrap", "Wald")`, `none`
  tier. Structurally almost identical to `InferenceIncidNewcombeRiskDiff`
  (self-contained score-based CI/p-value via `mn_ci_cpp`/`mn_pvalue_cpp`, no
  use of Wald's `get_standard_error`/`compute_z_or_t_*` helpers), except it
  does NOT override `get_supported_testing_types_impl` — it keeps `Wald`'s
  default `"wald"` label (verified: `get_supported_testing_types()` returns
  `"wald"`), unlike Newcombe's intentional `character(0)`. Same standard
  collision set as the other `Inference + BayesianBootstrap + Wald`
  migrations (`compute_rand_two_sided_pval`, jackknife names,
  bootstrap-worker wiring). No `tau`/`rlm_method`-style state-field bug (no
  extra constructor-set fields). Added `lock_objects = FALSE` to
  `SlowInferenceIncidMiettinenNurminenRiskDiff` in
  `test-bootstrap-reused-worker-asymp-families.R`. All directly relevant
  tests pass (`test-miettinen-nurminen-ci-dispatch.R` 6/6,
  `test-inference-class-registry.R` 2787/2787,
  `test-mixin-contracts.R` 1280/1280); only the same pre-existing unrelated
  failures remain elsewhere.
- [x] `InferenceIncidWald` (`inference_incid_wald.R`) — migrated 2026-08-17 to
  `Inference` plus `components = c("BayesianBootstrap", "Wald",
  "SimpleMeanDifference")`, `none` tier (auto-derived). Found via a fresh
  `inference_hierarchy_migration_manifest_as_list()` audit as a genuinely
  unaddressed class (zero prior mentions anywhere in this doc) — not one of
  the original 19/20 enumerated at the top of this subsection. Previously
  `R6::R6Class(inherit = InferenceAllSimpleMeanDiff, ...)`, overriding only
  `initialize` (adds the incidence response-type/no-censoring asserts),
  `get_standard_error`/`get_degrees_of_freedom` (unpooled Wald SE:
  \eqn{\sqrt{p_T(1-p_T)/n_T + p_C(1-p_C)/n_C}}, `df = NA`), and a private
  `compute_incidence_wald_components` helper — kept verbatim. Since it now
  composes `SimpleMeanDifference` directly (rather than inheriting the
  already-migrated `InferenceAllSimpleMeanDiff`), its own `initialize`
  collides with the component's and had to be added to `overrides$public`
  (the only new override beyond copying `InferenceAllSimpleMeanDiff`'s own
  full `overrides` lists verbatim). Verified via a new
  `test-incid-wald-migration-golden.R`: a byte-for-byte legacy-class copy
  compared against the migrated class two ways — (a)
  `expect_inference_migration_outputs_equal()` for every deterministic
  method (estimate, asymptotic CI/p-value, capability-absence checks, etc.,
  all bit-identical), and (b) the stochastic methods (bootstrap,
  randomization, randomization-bootstrap, jackknife distributions/CIs/
  p-values) compared separately under a shared explicit `set_seed()` reset
  before each side's call — necessary because
  `expect_inference_migration_outputs_equal()` calls legacy then migrated
  back-to-back off one continuing global RNG stream with no reset, so an
  RNG-consuming method legitimately diverges by call order alone; this
  divergence was hit and diagnosed here (first time this harness was used
  on a stochastic-bootstrap class) before being corrected, not a real
  migration bug. All comparisons pass bit-identical.
  `test-inference-class-registry.R` (full suite) and `test-mixin-contracts.R`
  both clean except the same pre-existing `testthat` version-mismatch
  failure documented elsewhere in this doc. Manual smoke test also confirmed
  identical `compute_estimate`/CI/p-value/error-message output against the
  pre-migration class on an independent fixture.
- [x] `InferenceIncidCMH` (`inference_incidence_cmh.R`) and
  `InferenceIncidExtendedRobins` (`inference_incidence_extended_robins.R`) —
  migrated 2026-08-17, same shape as `InferenceIncidWald` above
  (`Inference` plus `components = c("BayesianBootstrap", "Wald",
  "SimpleMeanDifference")`, `none` tier auto-derived). Both also found via
  the same fresh manifest audit, zero prior mentions in this doc. Both
  override `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`
  publicly (not just the private SE/df pair) to force a fresh
  `get_standard_error()` computation first — this exposed a real migration
  pitfall distinct from `InferenceIncidWald`'s (which didn't override these
  two): the pre-migration bodies called `super$compute_asymp_confidence_
  interval(alpha)`/`super$compute_asymp_two_sided_pval(delta)`, relying on
  `super$` reaching `InferenceAllSimpleMeanDiff`'s own composed
  `SimpleMeanDifference`-sourced implementation through the old layered
  R6 inheritance chain. Under `define_inference_class()`, composed-component
  methods are flattened directly into the class's own body rather than
  reached through a separate inheritance layer, so `inherit = Inference`
  means `super$` now resolves to `Inference`'s own (unimplemented) base
  method instead -- caught immediately by golden tests as an `"ok"` vs.
  `"unsupported"` status mismatch (`"Asymptotic inference is not
  implemented for this inference class"`). Fixed by calling the `Wald`
  component's shared helpers directly instead of through `super$`:
  `private$compute_z_or_t_ci_from_s_and_df(alpha)`/`private$compute_z_or_t_
  two_sided_pval_from_s_and_df(delta)` -- the same pattern already used by
  e.g. `InferenceContinRobustRegr`. Also surfaced a second, orthogonal test-
  harness gap while diagnosing the first: `InferenceIncidCMH`'s own
  non-blocking `get_standard_error()` draws random reference vectors via
  `Design$draw_ws_according_to_design()` when no design-level
  `cmh_se_w_mat` precompute exists, making `compute_asymp_confidence_
  interval`/`compute_wald_confidence_interval` (and their p-value
  counterparts) genuinely stochastic for this specific class -- and
  `Inference$set_seed()` alone does not control it, since
  `draw_ws_according_to_design()` reads R's global RNG stream directly, not
  the object's `private$seed`. `test-incid-cmh-extended-robins-migration-
  golden.R`'s comparison helper now wraps every method call (not just the
  pre-classified stochastic ones) in both an `obj$set_seed(...)` reset and
  an outer `inference_migration_with_seed()` global-RNG reset, which is
  safe/free for genuinely deterministic methods and correctly aligns the
  ones that secretly aren't. All comparisons pass bit-identical on both a
  blocking and a non-blocking (exactly-balanced) fixture for CMH, and a
  blocking fixture for ExtendedRobins. Confirmed via
  `test-design-inference.R`'s existing "CMH get_standard_error block and
  non-block paths agree" tests (unaffected, same pre-existing imbalance
  warnings as before) and `test-inference-class-registry.R`/
  `test-mixin-contracts.R` (both clean, no locked-binding or migration-
  related failures) that nothing else regressed.
- [x] `InferenceIncidRiskDiff` (`inference_incidence_risk_diff.R`) — migrated
  2026-08-17 to `Inference` plus `components = c("BayesianBootstrap",
  "Wald")`, `none` tier (declared via `metadata`; also the auto-derived
  value). This was the first migration off the
  `InferenceAsympLikStdModCacheNoParamBootstrap` ladder, and it surfaced a
  genuine architectural conflict rather than a mechanical port: the class's
  mechanically-projected target component set (`LikelihoodTests` +
  `StandardModelCache`, from `target_inference_components()` walking its old
  ancestor chain) is **contract-illegal and wrong** — the class is
  tier-"none" (its OLS linear-probability objective is a misspecified
  Gaussian working model for binary y; `supports_likelihood_tests = FALSE`
  is deliberate), while `StandardModelCache`'s `standard_model_cache`
  capability requires `likelihood_tests`, which requires tier >= quasi
  (`define_inference_class()` fails fast on this at line ~2693 of
  `contracts_mixins.R`). Composing it anyway would make the class advertise
  a capability it refuses at runtime, violating property 1. Resolution: do
  **not** compose `StandardModelCache`; instead absorb the likelihood-free
  subset it actually used as host-owned private methods — the `shared()`
  model-cache state machine (verbatim), `get_standard_error`/
  `get_degrees_of_freedom` (minus the information-matrix-preference branch,
  which is gated on `supports_information_preference()` →
  `supports_likelihood_tests()` and therefore never fired for this class on
  the old ladder either), and the three design-backed bootstrap-worker
  delegation one-liners (their generic backends live in the
  NonparametricBootstrap layer, already composed transitively). Everything
  else it needs (`fit_with_hardened_qr_column_dropping`,
  `compute_z_or_t_*`) lives in root `Inference` or the `Wald` component.
  The old ladder's score/gradient/LR/Bartlett public surface and the
  `get/set_testing_type`/`information_preference` accessors are
  **intentionally dropped** (golden test asserts the dropped set is exactly
  that API family and nothing else). Empirically verified what that surface
  actually did on the old ladder, which is worse than "errored": the
  score/gradient/LR **p-value** methods errored cleanly ("does not expose a
  likelihood-test specification"), but the corresponding **confidence
  intervals** silently returned bounds *bit-identical to the Wald interval*
  (the CI-inversion helpers fall back to Wald when the test machinery is
  unavailable) — i.e. `compute_score_confidence_interval()` handed callers
  a mislabeled Wald interval while `compute_score_two_sided_pval()` threw.
  Internally inconsistent, misleading API — the exact property-1 violation
  this doc bans, and what tier "none" forbids outright. The golden test
  pins this down: for each dropped label, migrated must be absent AND the
  legacy result must be unsupported, all-NA, or exactly the legacy's own
  Wald interval — so if any dropped method had carried information the
  retained Wald API doesn't, the test fails loudly.
  Golden-tested in `test-incid-risk-diff-migration-golden.R` against a
  byte-for-byte legacy copy (per-call seeded comparison for every harness
  method; the intentionally-dropped likelihood-family labels instead assert
  migrated-absent + legacy-degenerate-or-unsupported, so a drop of any
  *working* surface still fails loudly), plus a registry migrated-status
  check. **Randomization-dispatch decision, deliberately breaking with the
  `InferenceAllSimpleMeanDiff` precedent:** this class pins
  `compute_rand_two_sided_pval = InferenceRandCI$public_methods$...` (the
  randomization-CI layer's version), **not** `InferenceRand$public_methods$...`
  — the RandCI version dispatches incidence responses to the working Zhang
  exact randomization test (`should_use_zhang_incidence_randomization()` →
  `compute_exact_two_sided_pval_rand("Zhang", ...)`; all required privates
  come along via the composed `RandomizationCI` component, whose
  `source_name` is `InferenceRandCI` itself), while the `InferenceRand` base
  version refuses incidence outright ("Randomization tests are not supported
  for incidence. Use Zhang method."). The golden comparison caught this as a
  legacy-"ok"-vs-migrated-"unsupported" status mismatch before the pin was
  corrected. **Flag for the simple-estimator migration's owner:** the
  established precedent of pinning `InferenceRand`'s version (used by
  `InferenceAllSimpleMeanDiff` and inherited by every class built on it,
  including this session's `InferenceIncidWald`/`InferenceIncidCMH`/
  `InferenceIncidExtendedRobins` migrations, whose goldens compared against
  factory-based parents and so couldn't see it) appears to have silently
  dropped the old deep ladder's Zhang incidence dispatch for those classes
  when *they* were first migrated — pre-existing, not introduced here, but
  worth an explicit review of whether incidence users of the
  simple-mean-difference family should get the RandCI pin too.
- [x] **Tier-fix (not a migration): `InferenceSurvivalDepCensTransformRegr`
  reclassified `none` → `full`.** Found 2026-08-17 while investigating why
  the two remaining non-KK "none"-tier ladder classes couldn't compose
  `StandardModelCache`: this class's registry tier was a pure
  name-derivation bug, not a real classification — it implements a genuine
  full parametric (bivariate log-normal transformation) likelihood with a
  real `get_likelihood_test_spec` (score/information/`neg_loglik`),
  `supports_likelihood_tests = TRUE`, `supports_lik_ratio_param_bootstrap =
  TRUE`, and `simulate_under_lik_null`, but
  `infer_inference_likelihood_tier()`'s full-tier name regex matched no
  token in "DepCensTransformRegr", so it fell through to "none" — which
  this doc's own tier table flatly forbids (none permits no LR/score/
  parametric bootstrap), and which made its mechanically-projected target
  component set self-contradictory (`ParametricLikelihoodBootstrap`
  requires tier partial/full). The wrong value had even been frozen into
  `test-full-likelihood-migration-baseline.R` as a
  `survival_none_tier_expected_components` table (with the harvested
  `SurvivalDepCensTransform` component's `allowed_likelihood_tiers` set to
  `"none"` to match). Fixed end to end: added `DepCensTransform` to the
  full-tier regex (only this one class matches); flipped the component's
  `allowed_likelihood_tiers` to `"full"` (`contracts_mixins.R`, with an
  explanatory comment); and updated the baseline — class added to
  `full_likelihood_expected_classes`, the `survival` and `non_kk` groups,
  and `full_likelihood_expected_standard_model_cache_classes`; both 45-class
  count assertions bumped to 46; the none-tier table and its dedicated test
  deleted, with the class/component pair moved into
  `full_likelihood_expected_survival_components` (every assertion in that
  loop — lazy load policy, `allowed_likelihood_tiers == "full"`,
  source-method parity, effective-components membership — now holds for
  it). Verified live: `infer_inference_likelihood_tier()` returns "full",
  and the class now appears in `full_likelihood_concrete_class_names()`.
  The class itself is untouched and still on the old
  `InferenceAsympLikStdModCache` ladder — its actual migration belongs to
  the Full-Likelihood Estimators effort, which this fix unblocks (its
  target set is now internally consistent).
- [x] `InferenceOrdinalGCompMeanDiff` (`inference_ordinal_gcomp.R`) — migrated
  2026-08-12 to `Inference` plus `components = c("BayesianBootstrap",
  "Wald")`, `none` tier. Dropped a dead `super$approximate_bootstrap_
  distribution_beta_hat_T(...)` passthrough (same as `InferenceContinRobustRegr`
  earlier). Had the same bare-`NULL`-defaulted `best_X_colnames` private field
  as the earlier `tau`/`rlm_method` cases; fixed the same correct way (left
  it undeclared/dynamically-created rather than moving it into
  `cached_values`, per the corrected pattern). This class defines a real
  `get_standard_error`/`get_degrees_of_freedom` and its own
  `compute_wald_confidence_interval`/`compute_wald_two_sided_pval` (not
  just `compute_asymp_*`), all requiring the standard `Wald`-collision
  overrides. `compute_estimate_with_bootstrap_weights` saves/restores
  `cached_values`/`best_X_colnames`/`fit_warm_start*` via `on.exit()` to keep
  the weighted-replicate fit side-effect-free — unaffected by the migration
  since these are all plain private fields, not component-provided. Verified
  numerically: estimate, CI, p-value, and `get_supported_testing_types()`
  (`"wald"`, `Wald` composed) all sane; `compute_estimate_with_bootstrap_
  weights` correctly guards on a missing Bayesian-bootstrap context (expected
  behavior, not a bug). Added `lock_objects = FALSE` to the two duplicate
  `SlowInferenceOrdinalGCompMeanDiff` definitions in
  `test-bootstrap-reused-worker-asymp-families.R`. All directly relevant
  tests pass (`test-inference-class-registry.R` 2787/2787,
  `test-mixin-contracts.R` 1280/1280, this class's fast-vs-slow bootstrap
  comparisons in `test-bootstrap-reused-worker-asymp-families.R`); only the
  same pre-existing unrelated failures remain elsewhere.
- [x] `InferenceOrdinalPartialProportionalOddsRegr`
  (`inference_ordinal_partial_proportional_odds.R`) — migrated 2026-08-12 to
  `Inference` plus `components = c("BayesianBootstrap", "Wald")`, `none`
  tier (despite the class name matching the `full`-tier `PropOdds` name
  pattern in `infer_inference_likelihood_tier()` — classification follows
  the implemented objective per the doc's own rule, and this class only
  implements Wald-type inference: model SE via delta method / plug-in from
  whichever backend fit succeeded, no score/gradient/likelihood-ratio
  methods). No dead `super$` passthrough here (cleaner than the previous few
  classes). Same bare-`NULL`-defaulted `best_X_colnames` field as before,
  fixed the same way (left undeclared/dynamically-created). No dedicated
  `Slow*` bootstrap-worker test wrapper exists for this class, so no
  `lock_objects = FALSE` fix was needed. Verified numerically: estimate, CI,
  p-value, `get_supported_testing_types()` (`"wald"`) all sane;
  `compute_estimate_with_bootstrap_weights` correctly guards on a missing
  Bayesian-bootstrap context. All directly relevant tests pass
  (`test-design-inference.R` 71/72 — the one failure is in
  `InferenceOrdinalAdjCatLogitRegr`, a different, already-migrated class
  hitting the same "locked binding" pattern documented earlier, unrelated to
  this class; `test-inference-class-registry.R` 2787/2787,
  `test-mixin-contracts.R` 1280/1280).
- [x] `InferenceOrdinalRidit` (`inference_ordinal_ridit.R`) — migrated
  2026-08-12 to `Inference` plus `components = c("BayesianBootstrap",
  "Wald")`, `none` tier. No dead `super$` passthrough, no
  `get_standard_error`/`get_degrees_of_freedom` override (bypasses `Wald`'s
  accessor path entirely via `compute_z_or_t_ci_from_s_and_df` directly, same
  as several earlier classes), no `compute_treatment_estimate_during_
  randomization_inference` override (relies on `RandomizationTest`'s generic
  default). Same bare-`NULL`-defaulted private field pattern as before
  (`reference`), fixed the same way. The three `compute_fast_*` optional
  resampling hooks (`compute_fast_rand_bootstrap_distr`,
  `compute_fast_randomization_distr`, `compute_fast_bootstrap_distr`) aren't
  provided as defaults by any component (purely host-implemented optional
  hooks components check for via `has_private_method()`), so no override
  declarations were needed for them. No dedicated `Slow*` bootstrap-worker
  test wrapper exists for this class. Verified numerically: estimate, CI,
  p-value, `get_supported_testing_types()` (`"wald"`) all sane; the
  reusable-bootstrap-worker path gives 15/15 finite replicates with real
  variation (confirms proper per-replicate resampling, not the earlier
  found-and-reverted `IncidenceGComputation` staleness bug — this class's
  `compute_estimate` is host-defined/eager, not lazily loaded, so it isn't
  exposed to that bug). All directly relevant tests pass
  (`test-brt-smoothed-noise-mat-plumbing.R` 7/7,
  `test-inference-class-registry.R` 2787/2787,
  `test-mixin-contracts.R` 1280/1280).
- [x] `InferenceOrdinalJonckheereTerpstraTest`
  (`inference_ordinal_jonckheere_terpstra_test.R`) — migrated 2026-08-12 to
  `Inference` plus `components = c("BayesianBootstrap", "Wald")`, `none`
  tier. Same clean shape as `InferenceOrdinalRidit`: no dead `super$`
  passthrough, no bare-`NULL` private fields, no `get_standard_error`/
  `get_degrees_of_freedom`/`compute_treatment_estimate_during_randomization_
  inference` overrides needed (bypasses `Wald`'s accessor path via
  `compute_z_or_t_ci_from_s_and_df` directly; relies on
  `RandomizationTest`'s generic randomization-inference default), no
  dedicated `Slow*` bootstrap-worker test wrapper. Verified numerically:
  estimate, CI, asymptotic p-value, `compute_exact_two_sided_pval_for_
  treatment_effect()` (the exact JT p-value, a class-specific public method
  with no component collision), and `get_supported_testing_types()`
  (`"wald"`) all sane; reusable-bootstrap-worker path gives 15/15 finite
  replicates with real variation. `test-asymp-inference-paths.R` shows 10
  failures, all confirmed unrelated (`y_L`/`y_R` design-API signature
  changes from a concurrent session's in-flight work, and a locked-binding
  bug in `inference_all_abstract_asymp_lik_std_mod_cache.R` — a different,
  full-likelihood-tier class family entirely); `test-brt-smoothed-noise-mat-
  plumbing.R` 7/7, `test-inference-class-registry.R` 2787/2787,
  `test-mixin-contracts.R` 1280/1280 all clean.
- [x] `InferencePropQuantileRegr` (`inference_proportion_quantile_regr.R`) —
  migrated 2026-08-12, byte-for-byte the same shape as
  `InferenceContinQuantileRegr` (proportion response, logit-transformed).
  Same `components = c("BayesianBootstrap", "Wald")`, same bare-`NULL`
  `tau`/`fit_warm_keep` field fix, same overrides. Verified numerically
  (estimate/CI/pval/testing-type/bootstrap all sane) and confirmed `tau`
  survives worker cloning correctly (`0.5`, not `NULL`).
- [x] `InferencePropGCompAbstract` (`inference_proportion_gcomp.R`) and its
  one concrete descendant `InferencePropGCompMeanDiff` — migrated
  2026-08-12, **merged into a single class** (`InferencePropGCompMeanDiff`,
  deleting `InferencePropGCompAbstract` entirely) since — unlike the
  reverted `InferenceIncidGCompAbstract` case — there was no pre-existing
  lazy component to reuse, only one concrete descendant existed, and this
  class's `compute_estimate`/`initialize` are host-defined/eager (not
  lazily loaded), so none of that family's clone-staleness bug applies here.
  Two `super$` calls (`compute_bootstrap_two_sided_pval`,
  `compute_bootstrap_confidence_interval` — both "modify a screening
  control, then delegate to the generic resampling implementation" wrappers)
  fixed with the same generic-alias-plus-`self$`-dispatch pattern developed
  (and left in place) for the reverted incidence case. `components =
  c("BayesianBootstrap", "Jackknife")` — `Wald` deliberately excluded
  (its private `get_standard_error` would collide with this class's public
  `get_standard_error`, an R6-hard-forbidden cross-slot clash no override
  can resolve); only `get_supported_testing_types`/`_impl` aliased directly
  from `InferenceAsymp` instead. Found and fixed a real side effect: a
  `class(self)`-regex-keyed optimizer-dispatch table in `globals.R`
  (`inference_class_overrides`) had `"InferencePropGCompAbstract$" =
  "irls"`, which would have silently stopped matching once that class name
  was deleted, falling back to the wrong default optimizer — updated the key
  to `"InferencePropGCompMeanDiff$"`. Verified numerically: estimate, CI,
  p-value, Wald CI, testing-type, bootstrap distribution/p-value (with
  screening-control args working through the generic alias), and the
  expected Bayesian-bootstrap-context guard all correct.
  `test-inference-class-registry.R` and `test-mixin-contracts.R` both fully
  clean; `test-ci-rand.R` shows 2 pre-existing unrelated failures (a
  different class's locked-binding bug, and an unrelated argument-signature
  mismatch).
- [x] `InferenceSurvivalKKWeibullMarginal` — investigated 2026-08-12,
  relocated to "KK And IVWC Estimators" below rather than migrated here; same
  category as `InferenceCountKKHurdlePoissonIVWC` above. It splices
  `InferenceMixinKKPassThrough$public`/`private` via `as.list(modifyList(...))`
  and `eval(body(InferenceMixinKKPassThrough$public$approximate_bootstrap_
  distribution_beta_hat_T))`, calls `private$init_kk_passthrough(des_obj)` in
  `initialize()`, and uses `compute_basic_kk_match_data_impl()` — the same
  unfinished splice pattern, needing the same kind of dedicated extracted
  component (a `SurvivalKKWeibullMarginalSource`-based component covering
  the cluster-robust Weibull AFT fit, `get_cluster_ids()`, and the
  matched-pair/reservoir combination logic) before a clean migration is
  possible. See "KK And IVWC Estimators" below.
- [x] `InferenceSurvivalGehanWilcox` (`inference_survival_gehan_wilcox.R`) —
  migrated to `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald"))`. Standard `compute_rand_two_sided_pval`
  alias added. `overrides$public` includes `compute_rand_confidence_interval`
  since the class overrides it to throw an explicit "randomization CIs are
  not supported ... Peto-Prentice score-scale" error by design.
  `overrides$private` needed the standard jackknife + bootstrap-worker-wiring
  set (`supports_reusable_bootstrap_worker`, `create_bootstrap_worker_state`,
  `load_bootstrap_sample_into_worker`, `compute_bootstrap_worker_estimate`)
  even though the class itself never redefines them, since both `Wald` and
  `Jackknife`-adjacent components declare them and `Wald` (listed last) must
  win. No bare-`NULL` fields, no dead `super$` calls. Loaded clean via
  `pkgload::load_all(compile = FALSE)` on the first try. Fixed the
  `SlowInferenceSurvivalGehanWilcox` bootstrap-worker test wrapper in
  `test-bootstrap-reused-worker-asymp-families.R` with `lock_objects =
  FALSE`. Tests: `test-gehan-wilcox-fused-martingale.R` 23/23 pass (the 1
  failure at line 85 is the unrelated, concurrent `y_L`/`y_R` design-API
  rework — `add_all_subject_responses()` no longer accepts positional
  `(y, dead)`, unrelated to this migration);
  `test-logrank-gehan-wilcox-general-censoring.R` 19/19 pass;
  `test-inference-class-registry.R` 2772/2772 pass;
  `test-mixin-contracts.R` 1280/1280 pass. Numerically verified against a
  fresh `DesignSeqOneByOneBernoulli` survival dataset built with the current
  `add_all_subject_responses(ys=, y_Ls=, y_Rs=)` signature (right-censoring
  encoded as `y_L = event/censor time, y_R = Inf` for `dead == 0` rows,
  `ys = event time` for `dead == 1` rows): `compute_estimate()`,
  `compute_asymp_confidence_interval()`, and
  `compute_asymp_two_sided_pval()` (the class's only supported testing type,
  `"wald"`) all return finite, sane values, matching the already-passing
  canonical `survival::survdiff(rho = 1)`-based end-to-end test in
  `test-gehan-wilcox-fused-martingale.R`. `compute_rand_confidence_interval()`
  correctly throws the designed not-supported error. **Found (but did not
  introduce) a pre-existing framework bug**: the Bayesian-bootstrap and
  randomization-pval paths, which route through the reusable-bootstrap-worker
  `clone()`, return silently-wrong all-`NA` results due to the
  lazy-component/`clone()` staleness bug already tracked under "Follow-Ups
  From Implementation (Audit Findings)" — confirmed this reproduces
  identically on `InferenceOrdinalJonckheereTerpstraTest` (already marked
  complete) and is absent on old-ladder classes, and confirmed
  `InferenceSurvivalGehanWilcox`'s own bootstrap-weight arithmetic is correct
  via a direct (non-cloned) call. See the expanded bug writeup there for
  full detail and the session-wide implication.
- [x] `InferenceSurvivalKMDiff` (`inference_survival_km_diff.R`) — migrated
  to `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald"))`. Standard `compute_rand_two_sided_pval`
  alias added. Deleted the class's own pure-passthrough
  `approximate_bootstrap_distribution_beta_hat_T` override (its body was
  only `super$approximate_bootstrap_distribution_beta_hat_T(B, show_progress,
  debug, bootstrap_type)` with an identical signature — redundant with the
  `NonparametricBootstrap` component's own method, which is pulled in
  transitively via `BayesianBootstrap -> RandomizationBootstrap ->
  NonparametricBootstrap`, so no generic-alias workaround was needed here at
  all). `overrides$public` includes `compute_rand_confidence_interval` (the
  class throws an explicit not-supported error for the same
  inconsistent-estimator-units reason as `InferenceSurvivalGehanWilcox`) and
  `compute_rand_two_sided_pval`. `overrides$private` needed both the
  jackknife triplet (`resolve_jackknife_unit`,
  `jackknife_block_size_gt_one_unsupported`,
  `mark_jackknife_nonestimable_if_block_unsupported` — collide because
  `Wald` depends on `Jackknife` while `BayesianBootstrap` pulls in
  `NonparametricBootstrap`, both of which define these three directly) and
  the standard bootstrap-worker-wiring set; the initial migration omitted
  the jackknife triplet and failed to load with an "undeclared private
  component collision" error, caught immediately by
  `pkgload::load_all(compile = FALSE)`. No bare-`NULL` fields. Loaded clean
  after adding both override sets. Fixed the `SlowInferenceSurvivalKMDiff`
  bootstrap-worker test wrapper in
  `test-bootstrap-reused-worker-asymp-families.R` with `lock_objects =
  FALSE`. Tests: `test-mixin-contracts.R` and `test-inference-class-
  registry.R` both fully clean; `test-bootstrap-reused-worker-asymp-
  families.R` and `test-logrank-gehan-wilcox-general-censoring.R` show only
  their pre-existing unrelated failures (the `InferenceOrdinalPropOddsRegr`
  Slow-wrapper lock-objects issue and the `y_L`/`y_R` `deads=`
  design-API-rework issue for the former; the `InferenceSurvivalKMDiff`
  interval-censoring-rejection test for the latter — confirmed via `git
  stash` on the class file that this exact failure predates this migration,
  i.e. it is an artifact of the concurrent `y_L`/`y_R` rework changing what
  the design layer accepts, not something this migration introduced or can
  fix). Numerically verified against a fresh `DesignSeqOneByOneBernoulli`
  survival dataset (same `ys=`/`y_Ls=`/`y_Rs=` construction as
  `InferenceSurvivalGehanWilcox`): `compute_estimate()`,
  `compute_asymp_confidence_interval()`, `compute_asymp_two_sided_pval()`
  (`"wald"`, the only supported testing type),
  `compute_asymp_log_rank_two_sided_pval_for_treatment_effect()`,
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()` (25/25 finite,
  real variation), `compute_bayesian_bootstrap_confidence_interval()`,
  `compute_bayesian_bootstrap_two_sided_pval()`,
  `approximate_bootstrap_distribution_beta_hat_T()` (the
  `NonparametricBootstrap`-provided generic, 25/25 finite), and
  `compute_rand_two_sided_pval()` all return finite, sane values (this is
  the first class in this migration verified end-to-end with the
  lazy-component/`clone()` staleness fix from the entry above already in
  place — no `NA`s anywhere in the bootstrap/randomization paths).
  `compute_rand_confidence_interval()` correctly throws the designed
  not-supported error.
- [x] `InferenceSurvivalLogRank` (`inference_survival_log_rank.R`) — migrated
  to `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald"))`, same shape as `InferenceSurvivalKMDiff`
  above (identical `overrides` needs: the jackknife triplet
  `resolve_jackknife_unit`/`jackknife_block_size_gt_one_unsupported`/
  `mark_jackknife_nonestimable_if_block_unsupported` collides between
  `Wald`'s `Jackknife` dependency and `BayesianBootstrap`'s transitive
  `NonparametricBootstrap` dependency; the standard bootstrap-worker-wiring
  set; `compute_rand_confidence_interval` (explicit not-supported error, same
  inconsistent-estimator-units reasoning as `InferenceSurvivalGehanWilcox`/
  `InferenceSurvivalKMDiff`, this time for the log-rank score scale); and
  the standard `compute_rand_two_sided_pval` alias). Unlike
  `InferenceSurvivalKMDiff`, this class had no pure-passthrough
  `super$`-calling override to delete — its own
  `compute_asymp_two_sided_pval`, `compute_asymp_log_rank_two_sided_pval_
  for_treatment_effect`, and interval-censored `compute_shared_icen`/
  `ictest()` dispatch (TODO-7) are all genuinely class-specific with unique
  names, no collisions. No bare-`NULL` fields. Loaded clean on the first
  try (no undeclared-collision errors, since the full `overrides` set was
  copied directly from the already-debugged `InferenceSurvivalKMDiff`
  entry). Fixed the `SlowInferenceSurvivalLogRank` bootstrap-worker test
  wrapper in `test-bootstrap-reused-worker-asymp-families.R` with
  `lock_objects = FALSE`. Numerically verified against a fresh
  `DesignSeqOneByOneBernoulli` survival dataset (same `ys=`/`y_Ls=`/`y_Rs=`
  construction as the other two survival classes above): `compute_estimate()`
  = -0.166, `compute_asymp_confidence_interval()` = [-0.539, 0.207],
  `compute_asymp_two_sided_pval()` = 0.383,
  `compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` = 0.386
  (close to the Wald p-value as expected for a well-behaved log-rank
  statistic), `approximate_bayesian_bootstrap_distribution_beta_hat_T()`
  25/25 finite with real variation (sd = 0.166),
  `compute_bayesian_bootstrap_confidence_interval()` = [-0.442, 0.183],
  `compute_bayesian_bootstrap_two_sided_pval()` = 0.24,
  `approximate_bootstrap_distribution_beta_hat_T()` (the
  `NonparametricBootstrap`-provided generic) 25/25 finite,
  `compute_rand_two_sided_pval()` = 0.407 — all finite and sane, confirming
  the lazy-component/`clone()` staleness fix continues to hold across
  classes. `compute_rand_confidence_interval()` correctly throws the
  designed not-supported error. Tests: `test-mixin-contracts.R` and
  `test-inference-class-registry.R` both fully clean;
  `test-bootstrap-reused-worker-asymp-families.R` and
  `test-logrank-gehan-wilcox-general-censoring.R` show only the same two
  pre-existing unrelated failures already documented under
  `InferenceSurvivalKMDiff` above (the `InferenceOrdinalPropOddsRegr`
  Slow-wrapper lock-objects issue plus the `y_L`/`y_R` `deads=` design-API
  mismatch; and the `InferenceSurvivalKMDiff` interval-censoring-rejection
  test respectively) — no new failures. Verification was briefly blocked by
  an unrelated concurrent-session package-load break in
  `design_component_registry.R` (`"BlockingStructure has undeclared private
  reference(s): has_private_method"`); resolved itself without any change
  on this end once that other session's edit landed.
- [x] `InferenceSurvivalRestrictedMeanDiff` (`inference_survival_rmst.R`) —
  migrated to `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald"))`, same shape as `InferenceSurvivalKMDiff`/
  `InferenceSurvivalLogRank` above (identical `overrides`: jackknife triplet,
  bootstrap-worker-wiring set, `compute_rand_confidence_interval` explicit
  not-supported override — this class's variant of the error cites
  "estimates time difference, but randomization test searches for log-time
  ratio" — and the standard `compute_rand_two_sided_pval` alias). Like
  `InferenceSurvivalKMDiff`, deleted a pure-passthrough
  `approximate_bootstrap_distribution_beta_hat_T` override whose body was
  only `super$approximate_bootstrap_distribution_beta_hat_T(B,
  show_progress, debug, bootstrap_type)` — redundant with the
  `NonparametricBootstrap` component method pulled in transitively via
  `BayesianBootstrap`. No bare-`NULL` fields. Loaded clean on the first try
  (full `overrides` set copied directly from the already-debugged
  `InferenceSurvivalKMDiff`/`InferenceSurvivalLogRank` entries). Fixed the
  `SlowInferenceSurvivalRestrictedMeanDiff` bootstrap-worker test wrapper in
  `test-bootstrap-reused-worker-asymp-families.R` with `lock_objects =
  FALSE`. Numerically verified against a fresh `DesignSeqOneByOneBernoulli`
  survival dataset (same `ys=`/`y_Ls=`/`y_Rs=` construction as the other
  three survival classes above): `compute_estimate()` = 0.351,
  `compute_asymp_confidence_interval()` = [-0.283, 0.986],
  `compute_asymp_two_sided_pval()` = 0.278,
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()` 25/25 finite
  with real variation (sd = 0.369),
  `compute_bayesian_bootstrap_confidence_interval()` = [-0.219, 1.182],
  `compute_bayesian_bootstrap_two_sided_pval()` = 0.32,
  `approximate_bootstrap_distribution_beta_hat_T()` (the
  `NonparametricBootstrap`-provided generic) 25/25 finite,
  `compute_rand_two_sided_pval()` = 0.331 — all finite and sane.
  `compute_rand_confidence_interval()` correctly throws the designed
  not-supported error. This completes the "Asymptotic (Wald) No-Likelihood
  Migration" checklist's survival-class block; all four survival classes
  (`InferenceSurvivalGehanWilcox`, `InferenceSurvivalKMDiff`,
  `InferenceSurvivalLogRank`, `InferenceSurvivalRestrictedMeanDiff`) now
  share the identical `BayesianBootstrap` + `Wald` template and identical
  `overrides` shape. **Regression-suite verification for this class is
  incomplete**: while working through it, an unrelated concurrent-session
  C++ change desynced the compiled `src/EDI.so` from `RcppExports.R` (new
  symbol `_EDI_columns_have_missingness_cpp` referenced but not yet
  compiled in), breaking every test that constructs a design via
  `add_all_subjects_to_experiment()` (the batch-construction path; this
  class's own smoke test above used
  `add_one_subject_to_experiment_and_assign()` in a loop instead, which was
  unaffected). `test-mixin-contracts.R` and `test-inference-class-
  registry.R` (neither of which construct designs that way) both ran fully
  clean before this appeared. **Resolved**: `pkgbuild::compile_dll(force =
  FALSE)` (an incremental in-place compile, not a full recompile) hit the
  shared-repo `.o`-file build race documented earlier in this effort on its
  first attempt (`cannot find kk21_weights.o`) and timed out on a second
  attempt (heavy concurrent-session contention), then succeeded cleanly on
  a third attempt once the interfering session's own build had finished.
  Re-ran the full regression suite afterward: `test-mixin-contracts.R` and
  `test-inference-class-registry.R` fully clean;
  `test-bootstrap-reused-worker-asymp-families.R` and
  `test-logrank-gehan-wilcox-general-censoring.R` back to showing only the
  same two pre-existing unrelated failures documented under
  `InferenceSurvivalKMDiff` above — no new failures from this migration or
  from the recompile.

For each class above:

- [x] Record its current direct parent, effective components, public methods,
  and private-state owners.
- [x] Decide which inherited randomization, randomization-CI, nonparametric
  bootstrap, randomization-bootstrap, Bayesian-bootstrap, and jackknife APIs
  are intentional capabilities versus legacy accidental surface area.
- [x] Migrate to `Inference` plus only the components matching its retained
  capabilities, one class at a time, using the migration-order helper so leaf
  classes move before concrete parents.
- [x] Add golden tests for estimate, randomization, bootstrap, Bayesian
  bootstrap, and jackknife outputs for each migrated class.
- [x] Call `mark_inference_class_migrated()` for each class only after golden
  tests and method/private-state snapshots pass.

**Section complete (verified 2026-08-17):** every concrete class listed above
is individually `[x]` with its own per-class evidence entry, and a fresh
programmatic sweep confirmed all 22 concrete classes from this section
(`InferenceCustomAsymp`, `InferenceCustomBoot`, `InferenceContinQuantileRegr`,
`InferenceContinRobustRegr`, `InferenceIncidNewcombeRiskDiff`,
`InferenceIncidGCompRiskDiff`/`RiskRatio`,
`InferenceIncidMiettinenNurminenRiskDiff`, `InferenceOrdinalGCompMeanDiff`,
`InferenceOrdinalPartialProportionalOddsRegr`, `InferenceOrdinalRidit`,
`InferenceOrdinalJonckheereTerpstraTest`, `InferencePropQuantileRegr`,
`InferencePropGCompMeanDiff`, `InferenceSurvivalGehanWilcox`,
`InferenceSurvivalKMDiff`, `InferenceSurvivalLogRank`,
`InferenceSurvivalRestrictedMeanDiff`, `InferenceIncidWald`,
`InferenceIncidCMH`, `InferenceIncidExtendedRobins`,
`InferenceIncidRiskDiff`) pass `mark_inference_class_migrated()`'s full
validation gate: parent = `Inference`, zero algorithmic-compatibility-base
ancestors, effective components and capabilities identical to the manifest
targets, and every capability-required public method present. A manifest
query further confirmed the **only** remaining pending class that is neither
KK-family nor full-likelihood-tier is `InferenceOrdinalPairedSignTest`,
which is functionally KK (a paired/matched-set test composing
`KKPassThrough`) and belongs to the "KK And IVWC Estimators" section — the
non-KK no-likelihood ladder is done. (`InferenceCountKKHurdlePoissonIVWC`
and `InferenceSurvivalKKWeibullMarginal` were relocated to the KK section by
their own `[x]` entries above; they are not part of this count.)

##### No-Likelihood Migration Marking

- [x] Require every no-likelihood migration PR to include before/after manifest
  counts by no-likelihood group.
- [x] Require every no-likelihood migration PR to list newly migrated classes and
  the optional methods intentionally kept or dropped for each class.
- [x] Require `mark_inference_class_migrated()` to pass for each newly migrated
  no-likelihood class before checking off its class-specific migration TODO.
- [x] Require golden output comparison to pass before marking any no-likelihood
  class `migrated`.
- [x] Require method-availability snapshots to pass before marking any
  no-likelihood class `migrated`.
- [x] Require private-state owner snapshots to pass before marking any
  no-likelihood class `migrated`.
- [x] After all no-likelihood classes are migrated, delete no-longer-used
  algorithmic bases in this family and remove them from
  `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES`. **Closed 2026-08-21**: all
  family-specific bases were drained and removed from the list one by one
  (see the per-removal notes threaded through this item and the "Base
  Deletion" section); the 12 remaining list entries are the shared
  rand/bootstrap/Wald/KK-compound ladder, resolved as kept-and-converted
  internal component sources with the always-on strict gate making them
  unusable as concrete parents -- see the Base Deletion endgame items'
  2026-08-21 closure notes for the full disposition. **Status update 2026-08-17
  (superseding the stale "none of which are migrated yet" note):** every
  concrete class in the "Asymptotic (Wald) No-Likelihood Migration" section
  is now migrated and passes `mark_inference_class_migrated()` (see that
  section's completion note), and the first two descendant-free bases have
  been deleted (`InferenceCountCompositeLikelihood`,
  `InferenceCountLikelihoodNoParamBootstrap` — see the Base Deletion entry
  below). The remaining bases in this family (`InferenceAsymp` →
  `InferenceRand*`/`InferenceNonParamBootstrap`/`InferenceBayesianBootstrap`/
  `InferenceJackknife` chain, `InferenceAsympLik`, `InferenceParamBootstrap`,
  `InferenceAsympLikStdModCache*`, `InferenceCountLikelihood`,
  `InferenceMLEorKMSummaryTable`) still have 1-67 pending concrete
  descendants each — all in the full-likelihood and KK families — so their
  deletion stays blocked on those two migration ladders, not on this
  section.
  **Status update 2026-08-20**: full re-audit via live ancestor-chain
  introspection (`inference_class_ancestor_names()` intersected against
  `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` for every non-abstract
  registered class) found the KK and IVWC ladders are now **fully drained**
  — zero concrete `*KK*`/`*IVWC*`-named classes retain any algorithmic
  ancestor (confirmed both directly and via the already-shallow-composed-
  abstract pattern, e.g. `InferenceIncidKKCondLogitGLMMIVWC`/`OneLik`/
  `InferencePropKKGLMM`, whose shared `InferenceAbstractKKCondLogitGLMM`
  base composes `Inference` + components even though the 3 thin leaves
  still classically inherit it — the accepted terminal state per that
  family's own golden test, `test-incid-kk-cond-logit-glmm-migration-
  golden.R`'s "base is marked migrated" case). 22 pending concrete classes
  remain package-wide, all non-KK full-likelihood-family classes:
  `InferenceAsymp`'s only non-KK descendant `InferenceOrdinalPairedSignTest`
  (functionally KK, tracked under "KK And IVWC Estimators" instead);
  `InferenceAsympLikStdModCache` (12: `InferenceIncidBinomialIdentityRiskDiff`,
  `InferenceIncidLogBinomial`, `InferenceIncidLogRegr`,
  `InferenceIncidModifiedPoisson`, `InferenceIncidProbitRegr`,
  `InferenceOrdinalContRatioRegr`, `InferenceOrdinalOrderedProbitRegr`,
  `InferenceOrdinalStereotypeLogitRegr`, `InferencePropBetaRegr`,
  `InferencePropZeroOneInflatedBetaRegr`,
  `InferenceSurvivalDepCensTransformRegr`, `InferenceSurvivalWeibullRegr`);
  `InferenceCountLikelihood` (3: `InferenceCountHurdleNegBin`,
  `InferenceCountNegBin`, `InferenceCountPoisson`, plus 3 more one level
  down via `InferenceCountZeroAugmentedPoissonAbstract`:
  `InferenceCountHurdlePoisson`, `InferenceCountZeroInflatedNegBin`,
  `InferenceCountZeroInflatedPoisson`); `InferenceParamBootstrap` (2:
  `InferenceContinLin`, `InferenceContinOLS`); and (1, now closed, see
  below) `InferenceAsympLikStdModCacheNoParamBootstrap`.

  **`InferenceAsympLikStdModCacheNoParamBootstrap` fully drained and
  removed from the bases list (2026-08-20)**: its sole pending descendant,
  `InferencePropFractionalLogit`, migrated from `inherit =
  InferenceAsympLikStdModCacheNoParamBootstrap` to `define_inference_class(
  inherit = Inference, components = c("BayesianBootstrap", "Wald",
  "StandardModelCache"))` — composing the already-registered
  `StandardModelCache` component (source `StandardModelCacheSource` in
  `inference_all_abstract_asymp_lik_std_mod_cache.R`, registered earlier in
  this effort but not yet composed by any concrete class until now).
  `StandardModelCache` -> `LikelihoodTests` -> `Wald` -> `Jackknife` and
  `BayesianBootstrap` -> ... -> `RandomizationTest` transitively resolve
  the full 10-component manifest target without listing every name
  directly. Required declaring 17 component-vs-component and host-vs-
  component collisions in `overrides` (the full likelihood-test-machinery
  surface `StandardModelCache` and its `LikelihoodTests` dependency
  provide, plus the jackknife/bootstrap-worker trio `Jackknife`/
  `NonparametricBootstrap` both touch) — found iteratively via repeated
  load-time collision errors, the same pattern established throughout this
  whole migration effort. Also required adding
  `InferencePropFractionalLogit`'s `direct_components` entry to
  `infer_inference_direct_components()`'s switch (omitting it silently
  zeroed the class's effective capabilities post-migration -- the exact
  documented failure mode this switch's own inline comment already warns
  about for direct-composition classes with no intermediate algorithmic
  base). Dropped an initially-copied but unnecessary `capabilities =
  "likelihood_ratio"` metadata declaration (only required for classes
  composing `ParametricLikelihoodBootstrap`, which this class does not).
  Verified via a from-source legacy-fixture comparison (git `HEAD` copy of
  the pre-migration file, top-level binding renamed but literal classname
  string preserved per the established dispatch-by-name-safety precedent):
  `compute_estimate`, `compute_asymp_confidence_interval`,
  `compute_asymp_two_sided_pval`, `compute_bootstrap_two_sided_pval`, and
  `compute_rand_two_sided_pval` all bit-identical between legacy and
  migrated on a seeded fixture. `mark_inference_class_migrated()` now
  passes for `InferencePropFractionalLogit`. `InferenceAsympLikStdModCache
  NoParamBootstrap` removed from `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_
  BASES` (zero remaining `inherit =` references anywhere in `R/*.R`) but
  its R6 generator itself was **not** deleted -- `test-incid-risk-diff-
  migration-golden.R` still uses it as a legacy-comparison fixture base,
  same precedent as `InferenceKKPassThroughCompound`'s own note below (a
  real remaining consumer, just not a package-source one). Full battery
  green: `test-incid-risk-diff-migration-golden.R`,
  `test-inference-class-registry.R`, `test-mixin-contracts.R`,
  `test-capability-tables.R`, `test-static-cleanup-guardrails.R`,
  `test-full-likelihood-migration-baseline.R`,
  `test-bootstrap-reused-worker-asymp-families.R`,
  `test-bayesian-bootstrap.R`, `test-param-bootstrap-method-availability.R`.

  **`InferenceIncidLogRegr` migrated (2026-08-20)**, from `inherit =
  InferenceAsympLikStdModCache` (the "with param bootstrap" sibling of the
  `NoParamBootstrap` base above) to composing `c("BayesianBootstrap",
  "ParametricLikelihoodBootstrap", "IncidenceLogisticLikelihood")` directly.
  `IncidenceLogisticLikelihood` was **already registered** (source
  `IncidenceLogisticLikelihoodSource` in `inference_incidence_logit.R`,
  `dependencies = "StandardModelCache"`) from earlier prep work but never
  composed by any concrete class -- confirmed the same is true for 9 more
  of the 12 `InferenceAsympLikStdModCache` descendants (each already has a
  registered, unused per-class `*Likelihood` component: `IncidenceProbit
  Likelihood`, `IncidenceLogBinomialLikelihood`,
  `IncidenceModifiedPoissonLikelihood`,
  `IncidenceBinomialIdentityLikelihood`,
  `OrdinalContinuationRatioLikelihood`, `OrdinalOrderedProbitLikelihood`,
  `OrdinalStereotypeLikelihood`, `SurvivalDepCensTransform`,
  `SurvivalWeibullLikelihood`; only `InferencePropBetaRegr`/
  `InferencePropZeroOneInflatedBetaRegr` have no dedicated component,
  composing the shared chain directly). Since `inference_component_source_
  parts()`-style post-hoc harvesting from the OLD raw class breaks once the
  class itself is rebuilt via `define_inference_class()` (the merged
  generator's `$public_methods`/`$private_methods` would then include every
  composed component's own methods too), the class's `public=`/`private=`
  content was hoisted into named `inference_incid_log_regr_public`/`_private`
  list objects *before* the class definition, with `IncidenceLogisticLikelihood
  Source` built from those directly and the class definition following
  after -- the same "static leaf-only source" shape as every other
  `*Source` object in this file (`StandardModelCacheSource`, etc.); this is
  the reusable recipe for the remaining 8 `*Likelihood`-component siblings.
  Registered `InferencePropFractionalLogit = c("BayesianBootstrap", "Wald",
  "StandardModelCache")` (see immediately above) in the same switch fix;
  `InferenceIncidLogRegr`'s own entry needed **fixing an existing stale stub**
  at `infer_inference_direct_components()`'s switch rather than adding a
  new one (a pre-existing `InferenceIncidLogRegr = "IncidenceLogisticLikelihood"`
  single-name entry, apparently a placeholder from the earlier component-
  extraction prep pass, silently zeroed the class's effective capabilities
  post-migration until corrected to the real 3-component list) -- the same
  9 other already-registered-but-uncomposed components have identical
  stale single-name stub entries at that switch waiting for the same fix
  when each is migrated. 17 component-vs-component/host-vs-component
  collisions needed `overrides` declarations (the full `StandardModelCache`
  + `LikelihoodTests`/`Wald`/`Jackknife` + Bartlett-plumbing surface),
  found iteratively via load-time errors -- the same pattern applies to
  every sibling in this family. Re-declared `cached_mod = NULL` in the
  component's own private list (also added to its `owns_state`/
  `provides_private_methods`): `Wald`'s own `cached_mod = NULL` declaration
  never survives component composition because `modifyList()`-based
  assembly drops `NULL`-valued entries for *eager* components (`keep.null`
  is `TRUE` only for lazy ones); harmless for real package instances
  (`lock_objects = FALSE` lets the field spring into existence on first
  assignment) but breaks any `R6::R6Class(inherit = <migrated class>, ...)`
  test/user subclass, which locks its own instances by default --
  `test-bartlett-lr-plumbing.R`'s Bartlett opt-in subclasses hit "cannot
  add bindings to a locked environment" until fixed.

  **Found and fixed a separate, more serious, genuinely pre-existing bug**
  surfaced by this migration's own test suite
  (`test-incidence-logit-bootstrap-fast-path.R`): a `Slow*` test subclass
  forcing `supports_reusable_bootstrap_worker() = FALSE` returned the exact
  same constant bootstrap estimate for every replicate, regardless of the
  resampled data -- silently wrong bootstrap inference, not a load-time or
  test-infrastructure failure. Root cause, in `contracts_mixins.R`'s
  `edi_rebind_lazy_components_after_clone()` (called from `Inference$
  duplicate()`, which `bootstrap_subset_inference()`'s row-resampling relies
  on): (1) `install_lazy_inference_component()` stores its "already
  installed" bookkeeping marker as an **environment attribute**, not a
  binding, whenever the instance's private environment is already locked
  at install time (true for any `R6::R6Class(inherit = <migrated class>,
  ...)` subclass that doesn't itself pass `lock_objects = FALSE` -- every
  migrated class does, but a plain test/user subclass does not by default)
  -- the rebind function's read only checked the binding form; (2) even
  fixing that read, `self$clone()` copies environment *bindings* but does
  **not** preserve environment-level *attributes*, so an attribute-stored
  marker never survives cloning at all regardless of how it's read --
  there is nothing on the clone's own private environment to find. Net
  effect: any lazy component already installed on a locked-subclass
  instance stayed silently un-rebound after `clone()`/`duplicate()`; its
  methods kept resolving `self`/`private` to the pre-clone SOURCE instance,
  so every "fresh" cloned/resampled worker silently computed against the
  original, un-resampled data. Fixed by threading the source instance's own
  `private` through `duplicate()` into `edi_rebind_lazy_components_after_
  clone(i, source_private = private)`, reading the marker from the
  reliable source (not the potentially attribute-stripped clone), and
  re-recording it on the clone itself (binding if unlocked, else the same
  attribute fallback) so a clone-of-a-clone also has something to read.
  **Confirmed this is not specific to this migration**: reproduced the
  identical bug directly against the already-migrated, already-shipped
  `InferenceOrdinalPropOddsRegr` via the same `Slow*`-subclass-plus-row-
  resampling-clone construction -- a real, previously-undetected latent
  defect in the shared lazy-component/clone machinery affecting any class
  with lazy components whenever a locked subclass of it gets cloned before
  triggering an already-installed component's methods. Verified fixed for
  both classes (`InferenceIncidLogRegr`'s own fast-vs-slow-path golden
  test now passes; direct reproduction against `InferenceOrdinalPropOddsRegr`
  now returns distinct per-replicate estimates instead of a constant).
  Regression battery (24 test files spanning likelihood-test plumbing,
  Bartlett correction, parametric/nonparametric bootstrap, warm-start
  policies, capability tables, static-cleanup guardrails, and the
  full-likelihood baseline) all green after the fix; one guardrail
  expected-count table updated (`inference_incidence_logit.R` added to the
  raw-splicing-pattern allowlist, 2 occurrences, matching the established
  `*Source`-object exemption already given to every other file in that
  table).

  **`InferenceIncidProbitRegr` and `InferenceIncidLogBinomial` migrated
  (2026-08-20)**, same recipe as `InferenceIncidLogRegr` immediately above
  (both already had registered-but-uncomposed `IncidenceProbitLikelihood`/
  `IncidenceLogBinomialLikelihood` components from earlier prep work; both
  needed the same stale single-name `infer_inference_direct_components()`
  switch entries corrected to the full 3-component list; both needed
  `cached_mod` re-declared in their own component spec for the same eager-
  NULL-dropping reason). `InferenceIncidLogBinomial` additionally overrides
  `compute_score_confidence_interval`/`compute_gradient_confidence_interval`
  with try/catch-wrapped fallback logic that called `super$compute_score_
  confidence_interval(...)`/`super$compute_gradient_confidence_interval(...)`
  -- the identical `super$`-through-a-composed-class breakage as the
  `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval` fix
  documented in `inference_all_abstract_asymp_lik_std_mod_cache.R` above,
  just for two more of `InferenceAsympLik`'s public dispatch methods.
  Fixed the same way: replaced each `super$...(...)` call with the private
  impl the composed `LikelihoodTests` component's own public method
  delegates to directly (`private$compute_score_confidence_interval_impl`/
  `private$compute_gradient_confidence_interval_impl`) -- confirmed
  behavior-preserving since the old ladder's `super$` call itself just
  reached that same private impl one indirection layer up, virtually
  dispatched to this class's own override either way. Both verified via
  from-source legacy-fixture comparison, bit-identical across
  `compute_estimate`/`compute_asymp_confidence_interval`/
  `compute_asymp_two_sided_pval`/`compute_rand_two_sided_pval`/
  `compute_lik_ratio_bootstrap_two_sided_pval`/`compute_score_two_sided_pval`
  (plus `compute_score_confidence_interval`/`compute_gradient_confidence_
  interval` for the log-binomial class specifically); `mark_inference_
  class_migrated()` passes for both. Full targeted battery green for both
  (`test-incidence-probit.R`, `test-parametric-bootstrap-lr-all-capable-
  classes.R`, `test-full-likelihood-migration-baseline.R`, `test-bayesian-
  bootstrap.R`, `test-incid-kk-cond-logit-glmm-migration-golden.R`,
  `test-smart-start-inference-policies.R`, `test-bootstrap-reused-worker-
  families.R`, `test-mixin-contracts.R`, `test-inference-class-registry.R`,
  `test-capability-tables.R`, `test-static-cleanup-guardrails.R` -- the
  latter's expected-count table gained both files' 2-occurrence entries,
  same exemption as every other `*Source`-object file).

  **`InferenceIncidModifiedPoisson` and `InferenceIncidBinomialIdentityRiskDiff`
  migrated (2026-08-20)**, same recipe. `InferenceIncidModifiedPoisson`
  already declared `supports_likelihood_tests()`/`supports_lik_ratio_
  param_bootstrap()` as `FALSE` (Wald-only, per its pre-existing
  `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` entry, left in place since
  the class still structurally composes `ParametricLikelihoodBootstrap`
  and just declines to use it at runtime -- exactly the case that entry's
  own removal instruction says to *keep*, not the "no longer composes it
  at all" case that already triggered two other entries' removal earlier
  in this effort) and its own `compute_asymp_confidence_interval`/
  `compute_asymp_two_sided_pval` overrides call the shared z/t helpers
  directly rather than dispatching through `super$`, so neither needed the
  `super$` fix. `InferenceIncidBinomialIdentityRiskDiff` overrides
  `compute_lik_ratio_confidence_interval` (not the asymp dispatcher this
  time) with the same `super$`-through-a-composed-class breakage, fixed
  the same way. Both verified via from-source legacy-fixture comparison,
  bit-identical across the same method battery as the siblings above
  (plus `compute_lik_ratio_confidence_interval` specifically for the
  binomial-identity class). `test-incidence-modified-poisson-bootstrap-
  fast-path.R` -- the same fast-vs-slow-bootstrap-worker golden shape that
  caught the lazy-component/clone bug on `InferenceIncidLogRegr` -- passed
  clean on first run, confirming that fix generalizes. Full targeted
  battery green for both; `test-static-cleanup-guardrails.R`'s
  expected-count table gained both files' entries.

  **`InferenceOrdinalStereotypeLogitRegr` and `InferenceOrdinalContRatioRegr`
  migrated (2026-08-20)**, same recipe (both classes share
  `inference_ordinal_stereotype_logit.R`; hoisted each into its own
  `inference_ordinal_stereotype_public/private`/`inference_ordinal_
  contratio_public/private` pair). Pinned `compute_rand_two_sided_pval`
  from plain `InferenceRand` (not `InferenceRandCI`) -- confirmed this
  matches every other already-migrated ordinal class in the codebase
  (`InferenceOrdinalPropOddsRegr`/`AdjCatLogitRegr`/`CloglogRegr`/
  `CauchitRegr` all do the same), unlike the incidence-response siblings
  above which need `InferenceRandCI` for Zhang dispatch. Neither needed
  the `cached_mod` fix (neither uses `private$cached_mod`). Both verified
  bit-identical via from-source legacy-fixture comparison; full targeted
  battery green including the stereotype/continuation-ratio kernel unit
  tests (`test-stereotype-logit-*`, `test-continuation-ratio-*`).

  **`InferenceOrdinalOrderedProbitRegr` migrated (2026-08-20)**, same
  recipe, no new issues (no `cached_mod` usage, no `super$` overrides).
  Verified bit-identical via legacy-fixture comparison; full targeted
  battery green.

  **`InferencePropBetaRegr` migrated (2026-08-20)**. Unlike its 10
  `AsympLikStdModCache` siblings above, this class had **no pre-registered
  per-class component** (no `*Source` extraction line existed in the file
  at all), so its `public=`/`private=` content was declared inline
  directly in the `define_inference_class()` call, composing
  `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "StandardModelCache")` with no dedicated leaf component -- no separate
  registered-component step needed, and no `test-static-cleanup-
  guardrails.R` raw-splicing-pattern entry needed either (no separately-
  named `inference_*_public`/`_private` variables to match that pattern).
  `cached_vc_params` was previously entirely undeclared (created
  dynamically on first assignment); declared it explicitly alongside
  `cached_mod`, for the same reason. Verified bit-identical via
  legacy-fixture comparison; full targeted battery green.

  **`InferencePropZeroOneInflatedBetaRegr` migrated (2026-08-20)**, same
  no-pre-registered-component shape as `InferencePropBetaRegr`. Also
  dropped a pure-passthrough `approximate_bootstrap_distribution_beta_
  hat_T` override (`super$approximate_bootstrap_distribution_beta_hat_T(...)`
  with no added logic) -- composed classes have no `super$` chain, and
  since the override added no behavior, the composed `NonparametricBootstrap`
  component's own version is used directly with no change in behavior.
  `cached_mod`/`cached_vc_params` declared explicitly for the same reasons
  as the sibling above. Verified bit-identical via legacy-fixture
  comparison (including `approximate_bootstrap_distribution_beta_hat_T`
  itself); full targeted battery green.

  **`InferenceSurvivalDepCensTransformRegr` migrated (2026-08-20)** -- the
  most complex class in this batch. Findings:
  - The pre-registered `SurvivalDepCensTransform` component spec had
    `dependencies = character()`, but the class's own body calls
    `private$shared()` (from `StandardModelCache`) in four places
    (`compute_estimate`/`compute_asymp_confidence_interval`/`compute_asymp_
    two_sided_pval`/`get_likelihood_test_spec`). This spec had never
    actually been composed by a concrete class before now, so the missing
    dependency was never exercised until this migration surfaced it as
    "attempt to apply non-function" (`private$shared` resolving to `NULL`).
    Fixed by adding `dependencies = "StandardModelCache"`.
  - 5 genuine `super$`-through-a-composed-class fixes (the most of any
    class so far): `compute_bootstrap_confidence_interval`,
    `compute_score_two_sided_pval` (two `super$` calls inside one method),
    and `compute_lik_ratio_confidence_interval`. Unlike every prior
    `super$` fix in this effort, `compute_bootstrap_confidence_interval`'s
    real provider (`NonparametricBootstrap`'s own `compute_bootstrap_
    confidence_interval`) is a full self-contained implementation, not a
    thin wrapper around a private impl -- so there's no private helper to
    call directly instead. Fixed by pinning the real method body from its
    source generator (`InferenceNonParamBootstrap$public_methods$compute_
    bootstrap_confidence_interval`) into a private helper under a
    non-colliding name (`nonparam_boot_compute_bootstrap_confidence_
    interval`), the same "pin from the named source generator" pattern
    used throughout this effort for `compute_rand_two_sided_pval`, just
    stored privately instead of publicly since this override needs to call
    it without recursing into itself.
  - **Confirmed two pre-existing, already-broken methods, left unchanged**:
    `compute_bootstrap_confidence_interval_basic`/`_bca` call
    `super$compute_bootstrap_confidence_interval_basic`/`_bca`, but no
    class in the *entire* deep ladder (including root `Inference`) has
    ever defined those method names -- confirmed by reproducing the
    identical "attempt to apply non-function" error against the
    pre-migration source directly, unmodified. Since `Inference` root
    doesn't define them either, a composed class's own (nonexistent)
    `super$` binding produces the exact same error, so no behavior change
    was needed -- verified both legacy and migrated throw the identical
    error message.
    **Fixed 2026-08-21**: replaced both broken `super$` calls with
    `self$compute_bootstrap_confidence_interval(alpha=..., type="basic")`/
    `type="bca"` -- `NonparametricBootstrap`'s own generic, `type`-
    parameterized `compute_bootstrap_confidence_interval()` already
    supports `"basic"`/`"bca"`, and calling it with the right `type` is
    the evident original intent (validate a real basic/BCa CI for this
    model) rather than perpetuating a crash that predates this migration
    entirely. Verified: both methods now return real, finite CIs on a
    representative fixture (previously always threw); `test-full-
    likelihood-migration-baseline.R`/`test-parametric-bootstrap-lr-all-
    capable-classes.R` green.
  - **Testing methodology note**: an initial legacy-vs-migrated comparison
    of `compute_bootstrap_confidence_interval` showed a real numeric
    difference (migrated returned `NA`/`NA`) -- traced this to the method
    using ambient global RNG state with no internal seeding (unlike
    `compute_rand_two_sided_pval`/bootstrap-distribution methods elsewhere,
    which explicitly save/restore `.Random.seed` via `private$seed`).
    Constructing and calling methods on the `legacy` object first shifted
    the global RNG stream before `migrated`'s call, changing which
    bootstrap resamples succeeded for this small-B, fragile-fit model. Not
    a migration regression: re-run with `set.seed()` immediately before
    each object's call (matching the method's actual, undocumented
    contract) gave bit-identical results. Also added the new `cached_
    vc_params` entry to `test-static-cleanup-guardrails.R`'s "component
    redeclarations of root-owned state" allowlist (root-owned, same
    pattern as `SurvivalKKWeibullMarginal`'s existing entry; `cached_mod`
    is not root-owned). Full targeted battery green.

  **`InferenceSurvivalWeibullRegr` migrated (2026-08-20)** -- the 12th and
  last of this family. 3 `super$`-through-a-composed-class fixes:
  `compute_bayesian_bootstrap_two_sided_pval` (self-contained, like
  `compute_bootstrap_confidence_interval` above -- pinned from
  `InferenceBayesianBootstrap$public_methods$...` into a private helper),
  `compute_lik_ratio_bartlett_approx_two_sided_pval` (thin wrapper, fixed
  via the usual private-impl-direct-call pattern), and
  `compute_rand_two_sided_pval` (self-contained -- pinned from plain
  `InferenceRand$public_methods$...`, matching the established
  plain-Cox-survival precedent, not the incidence-only `InferenceRandCI`
  case).

  **Found and fixed a third systemic gap** in the shared lazy-component
  machinery, distinct from the earlier `cached_mod`-NULL-dropping and
  clone-rebinding bugs: `infer_inference_supports_general_censoring()`
  (used by `populate_inference_class_registry()` for every class) calls a
  class's `supports_interval_or_left_censored_data()` implementation
  **directly and unbound** (`fn()`, no `self`/`private`), on the documented
  assumption that every implementation is a trivial, self/private-free
  literal -- true of the literal body itself, but not of how a *lazy*
  component's copy of it behaves before first use: a lazy component's
  `provides_private_methods` entries are template-level install *stubs*
  (real installation deferred to first access through a live instance),
  and the stub's own body references `self`/`private` to perform that
  install -- calling the stub raw and unbound throws "object 'private' not
  found". This is the first class in the whole migration effort whose
  composed component overrides this specific method (survival-only), so
  the gap was never exercised until now. Fixed narrowly, not by touching
  the shared registry helper: declared `supports_interval_or_left_
  censored_data` directly in the class's own (always-eager) host `private=`
  instead of inside the lazy `SurvivalWeibullLikelihood` component source,
  so it's never wrapped in an install stub at all -- restores the "safe to
  call raw" assumption exactly. Verified via `EDI:::inference_class_
  registry_as_list()[["InferenceSurvivalWeibullRegr"]]$supports_general_
  censoring == TRUE` (correctly detected) and `test-weibull-general-
  censoring-inference.R` (the dedicated left-/interval-censoring golden
  suite) passing clean. Verified bit-identical via legacy-fixture
  comparison across the full method battery including all 3 fixed
  `super$` paths; full targeted battery green (12 files).

  **`InferenceAsympLikStdModCache` fully drained and removed from
  `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES`** now that all 12
  descendants above are migrated -- confirmed via the same live
  ancestor-chain audit used throughout this effort (zero non-abstract
  registered classes have it in their ancestor chain). The R6 generator
  itself was **not** deleted: 4 already-migrated ordinal classes'
  `...LegacyRaw`/harvesting-source objects
  (`inference_ordinal_adj_cat_logit.R`/`cauchit.R`/`proportional_odds.R`/
  `cloglog.R`) still classically inherit from it as their own harvesting
  mechanism -- same "real remaining consumer, just not a package-source
  algorithmic-ancestry one" precedent as `InferenceKKPassThroughCompound`
  and `InferenceAsympLikStdModCacheNoParamBootstrap` above. Full targeted
  battery green after the removal (`test-inference-class-registry.R`,
  `test-mixin-contracts.R`, `test-static-cleanup-guardrails.R`,
  `test-capability-tables.R`, `test-full-likelihood-migration-baseline.R`).

  **Remaining pending classes package-wide: 11** (down from 22 at the
  start of this per-class migration push): `InferenceOrdinalPairedSignTest`
  (1, functionally KK, tracked under "KK And IVWC Estimators"),
  `InferenceCountLikelihood` family (3: `InferenceCountHurdleNegBin`,
  `InferenceCountNegBin`, `InferenceCountPoisson`, plus 3 more via
  `InferenceCountZeroAugmentedPoissonAbstract`: `InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`),
  and `InferenceParamBootstrap` (2: `InferenceContinLin`,
  `InferenceContinOLS`).

  **Scoping note on the remaining 11 (2026-08-20):** all 11 remaining
  classes sit below `InferenceParamBootstrap`
  (`inference_all_abstract_param_boot.R`, 1076 lines,
  `inherit = InferenceAsympLik`), not below `InferenceAsympLikStdModCache`
  like everything migrated in this push. `InferenceCountLikelihood`
  (`inference_all_abstract_count_likelihood.R:268`) classically
  `inherit`s `InferenceParamBootstrap` directly, and
  `InferenceCountZeroAugmentedPoissonAbstract`
  (`inference_count_zero_augmented_poisson_abstract.R`, 1132 lines) sits
  below that. `InferenceParamBootstrap` itself is substantially more
  complex than any component migrated so far: it owns worker-clone
  machinery for parallel bootstrap replicates
  (`create_param_bootstrap_worker_state`/`compute_param_bootstrap_worker_lrt`,
  which `self$duplicate()`s the whole object and mutates a clone's
  private fields directly), deterministic-vs-stochastic RNG-seeding
  paths, and a reusable-worker optimization -- none of which resembles
  the `StandardModelCache`/`LikelihoodTests`/`Wald`/`Jackknife` component
  chain used by every class migrated in this push. `CountLikelihoodPlumbing`
  (already registered in `contracts_mixins.R`) depends only on
  `LikelihoodTests`, not on any `ParamBootstrap`-equivalent component --
  so composing it alone would not give `InferenceCountLikelihood` (or its
  descendants) the `compute_lik_ratio_bootstrap_*`/
  `compute_param_bootstrap_*` methods they currently get via classic
  `super`. Migrating this family correctly means first designing and
  registering a new component (something like `ParametricBootstrapCore`)
  that wraps this worker-clone machinery, then composing it under
  `InferenceCountLikelihood` and separately under
  `InferenceContinLin`/`InferenceContinOLS` -- a materially larger,
  higher-risk unit of work than any single class migrated in this push
  (which were each a few hundred lines with a handful of `super$` calls).
  Paused here rather than rushing a same-session redesign of shared
  parallel/RNG-sensitive machinery without dedicated review; next step is
  to scope the `ParametricBootstrapCore` component design explicitly
  before touching any of these 11 classes.

  **Correction (2026-08-21): the scoping note above was wrong.** A
  component that wraps `InferenceParamBootstrap`'s worker-clone/RNG
  machinery already exists and is already composed by 6+ already-migrated
  classes -- `ParametricLikelihoodBootstrap`
  (`contracts_mixins.R`, `source_name = "InferenceParamBootstrap"`,
  `dependencies = "LikelihoodTests"`), the exact component this note
  claimed needed to be designed from scratch. No new component was
  needed; the recipe is the same one used throughout this whole push:
  compose `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "CountLikelihoodPlumbing")` (the last one also already registered,
  `source_name = "CountLikelihoodPlumbingSource"`, itself a static harvest
  of `InferenceCountLikelihood`'s own `inference_count_likelihood_public`/
  `_private` -- including that class's own `super$`-through-a-composed-
  class calls, which need the same per-leaf-class fix as everywhere else
  in this migration, not a new fix for this family).

  **`InferenceCountPoisson` migrated (2026-08-21)**, composing
  `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "CountLikelihoodPlumbing")`. Fixed 2 `super$`-through-a-composed-class
  calls (`compute_lik_ratio_bootstrap_two_sided_pval`/
  `compute_lik_ratio_bootstrap_confidence_interval`, both self-contained --
  pinned from `InferenceParamBootstrap$public_methods$...` into private
  helpers, same pattern as every other bootstrap-LR pin in this effort).
  This class's own `compute_asymp_*`/`compute_wald_*`/`compute_score_*`/
  `compute_lik_ratio_*`/`compute_gradient_*` overrides were already fully
  self-contained (calling `private$compute_X_impl(...)` directly, never
  `super$`), so no fix was needed there. Required an unusually large
  `overrides` list (13 public, 17 private) since `CountLikelihoodPlumbing`
  is a full static harvest of `InferenceCountLikelihood`'s entire
  public/private surface, colliding on nearly every name with
  `LikelihoodTests`/`Wald`/`Jackknife`/`BayesianBootstrap`'s own
  transitively-composed defaults -- found iteratively via load-time errors,
  same methodology as every prior class, just more rounds than usual.
  Declared `cached_mod = NULL` explicitly (collides with `Wald`'s own
  owned field, same reason as every prior class in this push).
  **Testing-methodology note, not a bug**: an initial legacy-vs-migrated
  `compute_rand_two_sided_pval` comparison seeded via each object's own
  `$set_seed()` showed a real numeric mismatch -- traced to
  `generate_permutations()`'s `des_template$draw_ws_according_to_design()`
  call using the ambient global RNG directly rather than `private$seed`
  (unlike the bootstrap paths, which explicitly `set.seed(private$seed)`
  first) -- `$set_seed()` only stores the value for later use, it does not
  call `set.seed()` itself. Re-run with R's own `set.seed()` called
  immediately before each isolated object's call (matching the
  `InferenceSurvivalDepCensTransformRegr` RNG-testing lesson from earlier
  in this push) gave bit-identical results. Verified bit-identical via
  legacy-fixture comparison across `compute_estimate`,
  `compute_asymp_confidence_interval`/`_two_sided_pval`,
  `compute_wald_two_sided_pval`, `compute_gradient_confidence_interval`,
  `compute_rand_two_sided_pval`, `compute_lik_ratio_bootstrap_two_sided_pval`,
  and `compute_bayesian_bootstrap_two_sided_pval`. One pre-existing test
  needed updating, not fixing: `test-bayesian-bootstrap.R`'s "jackknife
  descendants expose Bayesian bootstrap methods" asserted
  `inherits(inf, "InferenceJackknife")`, which is definitionally false for
  a `define_inference_class()`-composed class (no classic inheritance) --
  replaced with a functional check
  (`is.function(inf$compute_jackknife_wald_two_sided_pval)`), the same
  "check the contract, not the class name" fix pattern used for every
  other migrated class's inheritance-based test assertions. Full targeted
  battery green (18 files: `test-rand-bootstrap.R`,
  `test-asymp-inference-paths.R`, `test-bartlett-lr-approx-smoke-families.R`,
  `test-bayesian-bootstrap.R`, `test-bootstrap-reused-worker-families.R`,
  `test-bootstrap-worker-hook-contract.R`, `test-extracted-likelihood-
  mixin-public-contracts.R`, `test-full-likelihood-migration-baseline.R`,
  `test-mle-km-summary-table.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`,
  `test-smart-default-false.R`, `test-smart-start-warm-paths.R`,
  `test-smart-start-inference-policies.R`,
  `test-warm-start-dispatch-policy-refactor.R`, `test-mixin-contracts.R`,
  `test-inference-class-registry.R`, `test-capability-tables.R`,
  `test-static-cleanup-guardrails.R`) -- 3 pre-existing failures/errors in
  that battery (`test-asymp-inference-paths.R`'s KK Bai-adjusted testing-
  type message, `test-parametric-bootstrap-lr-all-capable-classes.R`'s
  unrelated unexported-class lookup, `test-smart-default-false.R`'s design
  assignment-overwrite assertion) confirmed unrelated via a `git stash`
  clean-baseline re-run before investigating further. `mark_inference_
  class_migrated()` passes for `InferenceCountPoisson`.

  **Found and fixed a component-level (not per-class) bug while migrating
  `InferenceCountNegBin` (2026-08-21)**: `CountLikelihoodPlumbingSource`
  had been reusing `inference_count_likelihood_public`/`_private` verbatim
  (`inference_all_abstract_count_likelihood.R`) -- 12 of those methods
  (`compute_asymp_confidence_interval`/`_two_sided_pval`,
  `compute_wald_*`, `compute_score_*`, `compute_lik_ratio_*`,
  `compute_gradient_*`, `compute_lik_ratio_bootstrap_*`) call
  `super$compute_X(...)`, which only resolves under the classic ladder
  `InferenceCountNegBin`/`InferenceCountPoisson` used to inherit through.
  `InferenceCountPoisson` never exercised this because it happens to fully
  self-override all 12 methods itself; `InferenceCountNegBin` does not
  override any of them, so composing the untouched `CountLikelihoodPlumbing`
  would have thrown "attempt to apply non-function" on first use. Fixed at
  the component level, not per-class, and without touching
  `inference_count_likelihood_public`/`_private` themselves (still used
  as-is by the classic, not-yet-migrated `InferenceCountLikelihood` R6
  generator, where `super$` genuinely resolves) -- `CountLikelihoodPlumbingSource`
  now `utils::modifyList()`s a composition-safe override on top of the
  original public list: the 8 wald/score/lik_ratio/gradient methods now
  call their `private$compute_X_impl(...)` directly (same thin-wrapper
  shape as every `LikelihoodTests`/`Wald` descendant); the 2 asymp
  dispatchers and the 2 bootstrap-LR methods are self-contained real
  implementations with no `_impl` equivalent, so those are pinned from
  their real source generators (`InferenceAsympLik$public_methods$compute_
  asymp_confidence_interval`/`_two_sided_pval`,
  `InferenceParamBootstrap$public_methods$compute_lik_ratio_bootstrap_
  two_sided_pval`/`_confidence_interval`) into `cl_plumbing_`-prefixed
  private helpers (prefixed to avoid colliding with `InferenceCountPoisson`'s
  own differently-named pins for the same two bootstrap methods). Added
  the 4 new private helper names to `CountLikelihoodPlumbing`'s
  `provides_private_methods` in `contracts_mixins.R`. Re-verified
  `InferenceCountPoisson` still bit-identical against its legacy fixture
  after this change (it does, since its own overrides always shadow the
  component's copies regardless).

  **`InferenceCountNegBin` migrated (2026-08-21)**, composing
  `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "CountLikelihoodPlumbing")` -- the same 3-component recipe as
  `InferenceCountPoisson`, but exercising the fixed component's public
  dispatch methods directly rather than self-overriding them (this class's
  own `public=` only supplies `initialize`,
  `compute_estimate_with_bootstrap_weights`, and the 5 "jackknife not
  supported" stub overrides -- everything else comes from the composed
  components). Declared `cached_mod`/`cached_vc_params` explicitly (both
  collide with `Wald`'s/other components' own owned fields, same reason as
  every prior class). Verified bit-identical via legacy-fixture comparison
  across `compute_estimate`, `compute_asymp_confidence_interval`/
  `_two_sided_pval`, `compute_wald_confidence_interval`,
  `compute_score_two_sided_pval`, `compute_lik_ratio_two_sided_pval`,
  `compute_gradient_confidence_interval`, `compute_rand_two_sided_pval`,
  `compute_lik_ratio_bootstrap_two_sided_pval`, and
  `compute_bayesian_bootstrap_two_sided_pval` (RNG-sensitive methods
  seeded via R's own `set.seed()` immediately before each isolated call,
  per the established testing-methodology lesson). `mark_inference_class_
  migrated()` passes. Full targeted battery green (18 files); the same 2
  pre-existing, unrelated failures from the `InferenceCountPoisson`
  migration recur here (confirmed already unrelated then) plus
  `test-smart-default-false.R`'s 4 pre-existing design-assignment errors
  (also confirmed unrelated via the same clean-baseline `git stash`
  re-run).

  **`InferenceCountHurdleNegBin` migrated (2026-08-21)**, same recipe as
  `InferenceCountNegBin` (composing `CountLikelihoodPlumbing`'s now-fixed
  public dispatch methods directly rather than self-overriding them, since
  this class's own `public=` only supplies `initialize`,
  `compute_estimate_with_bootstrap_weights`, and the 5 "jackknife not
  supported" stub overrides -- it also self-overrides
  `compute_asymp_confidence_interval`/`_two_sided_pval` and
  `compute_gradient_confidence_interval`/`_two_sided_pval`, all
  self-contained with no `super$`, so those needed declaring in
  `overrides$public` but no per-class fix). Declared `cached_vc_params`
  explicitly (`cached_mod` was already explicit in the pre-migration
  source); `supports_lik_ratio_param_bootstrap` was NOT overridden by this
  class (unlike NegBin), so it's a component-vs-component-only collision,
  declared without a host override needed. Verified bit-identical via
  legacy-fixture comparison across the same method battery as
  `InferenceCountNegBin`. **Blocked mid-verification by the same
  transient package-wide C++ symbol-not-found issue as earlier in this
  session** (missing `.so`, `library(EDI)` construction failing
  package-wide) -- per this file's own CLAUDE.md instructions, stopped and
  reported rather than attempting any compile step; resumed cleanly after
  the user's own concurrent build/reinstall completed and confirmed
  working.

  **Found and fixed a second pre-existing issue while re-verifying**,
  surfaced by a new test file that landed concurrently
  (`test-design-compatibility-reason.R`, regression coverage for the
  `design_compatibility_reason()` discovery-time-applicability feature
  from earlier in this session): (1) it read
  `EDI:::InferenceIncidCMH$private_methods$design_compatibility_reason`/
  etc. directly (hardcoded-class-name reflection), tripping
  `test-static-cleanup-guardrails.R`'s "bans R6 generator private member
  reads" guardrail -- fixed by using the actual registry helper,
  `infer_inference_design_compatibility_reason_fn(EDI:::ClassName)`,
  instead (more idiomatic, and the guardrail's own intent is clearly
  hardcoded-class-name reflection, not the generic walk-any-generator
  pattern the registry code itself already uses). (2) one assertion
  incorrectly expected `InferenceIncidExtendedRobins` to appear in
  `incompatible_inference_classes_due_to_design_structure()` for a
  non-blocking design -- wrong, since that design is already excluded by
  the pre-existing coarse `requires_blocking_design` registry filter
  before `design_compatibility_reason()` is ever consulted, so it's never
  added to that bucket (which only holds classes that pass the coarse
  filter but fail the finer-grained predicate, e.g. CMH's block-size-
  inequality case); removed the incorrect assertion with an explanatory
  comment. Both fixes verified: `test-design-compatibility-reason.R` and
  `test-static-cleanup-guardrails.R` full green.

  **Remaining pending classes: 8** -- `InferenceOrdinalPairedSignTest`
  (1), `InferenceCountLikelihood` family (3 via
  `InferenceCountZeroAugmentedPoissonAbstract`: `InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`),
  `InferenceParamBootstrap` direct (2: `InferenceContinLin`,
  `InferenceContinOLS`). All 3 `InferenceCountZeroAugmentedPoissonAbstract`
  descendants share one abstract base (1132 lines, not yet migrated) --
  migrating that single abstract should resolve all 3 leaves at once,
  matching the "thin leaf of an already-composed abstract" pattern
  established earlier in this file (`InferenceAbstractKKCondLogitGLMM`
  precedent). `InferenceContinLin`/`InferenceContinOLS` should follow the
  same `ParametricLikelihoodBootstrap`-composing recipe as the count
  family (not a new component, per the correction above).

  **`InferenceContinLin` and `InferenceContinOLS` migrated (2026-08-21)**,
  composing `c("BayesianBootstrap", "ParametricLikelihoodBootstrap")` --
  simpler than the count family: neither class ever composed
  `CountLikelihoodPlumbing` (no count-specific plumbing needed), so
  `compute_wald_*`/`compute_score_*`/`compute_lik_ratio_*`/
  `compute_gradient_*`/`compute_lik_ratio_bootstrap_*` all come straight
  from `ParametricLikelihoodBootstrap`'s own `LikelihoodTests` -> `Wald`
  -> `Jackknife` dependency chain with **no `super$` fixes needed at
  all** -- neither class's pre-migration source overrode any of those
  methods itself (only `compute_asymp_confidence_interval`/
  `_two_sided_pval`, both already self-contained). Both classes loaded
  clean on the first `pkgload::load_all()` attempt with only the
  overrides list carried over from the count-family recipe (no new
  collisions found), and both verified bit-identical via legacy-fixture
  comparison across the full method battery (`compute_estimate`,
  `compute_asymp_confidence_interval`/`_two_sided_pval`,
  `compute_wald_two_sided_pval`, `compute_score_two_sided_pval`,
  `compute_lik_ratio_two_sided_pval`, `compute_gradient_confidence_interval`,
  `compute_rand_two_sided_pval`, `compute_lik_ratio_bootstrap_two_sided_pval`,
  `compute_bayesian_bootstrap_two_sided_pval`) with zero deviation from
  the recipe. `mark_inference_class_migrated()` passes for both. Full
  targeted battery green for both (12 files each); only the same
  pre-existing, unrelated `test-parametric-bootstrap-lr-all-capable-
  classes.R` failure recurs.

  **Remaining pending classes: 4** -- `InferenceOrdinalPairedSignTest`
  (1, functionally KK, tracked under "KK And IVWC Estimators"),
  `InferenceCountLikelihood` family (3 via
  `InferenceCountZeroAugmentedPoissonAbstract`: `InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`).
  This is the last remaining item in this per-class migration push:
  migrating `InferenceCountZeroAugmentedPoissonAbstract` (1132 lines, raw
  R6, `inherit = InferenceCountLikelihood`) once should resolve all 3
  leaves via the "thin leaf of an already-composed abstract" pattern.

  **`InferenceCountZeroAugmentedPoissonAbstract` migrated (2026-08-21)** --
  the last item in this push. Composes `c("BayesianBootstrap",
  "ParametricLikelihoodBootstrap", "ZeroAugmentedCountLikelihood")` (the
  latter already registered, `dependencies = "CountLikelihoodPlumbing"`).
  Its 3 classic-inheritance leaves (`InferenceCountHurdlePoisson`,
  `InferenceCountZeroInflatedNegBin`, `InferenceCountZeroInflatedPoisson`)
  stay thin leaves per the accepted terminal-state pattern -- all 3 now sit
  in the same manifest "pending" bucket as the KK thin leaves, documented
  as correct, not a gap. Key findings:
  - The file's `public=`/`private=` content was hoisted into
    `inference_count_za_public`/`_private` named lists and
    `ZeroAugmentedCountLikelihoodSource` rebuilt from those statically
    (replacing the old `inference_component_source_parts(<generator>)`
    post-hoc harvest, which breaks once the generator itself is composed
    -- same fix as `InferenceIncidLogRegr`).
  - Fixed 4 `super$`-through-a-composed-class calls
    (`compute_bootstrap_two_sided_pval`/`_confidence_interval`,
    `compute_bayesian_bootstrap_two_sided_pval`/`_confidence_interval`,
    all bca-gate wrappers) via pins from
    `InferenceNonParamBootstrap`/`InferenceBayesianBootstrap`'s source
    generators; declared the 4 pin names + `cached_vc_params` in the
    component spec's `provides_private_methods`/`owns_state`.
  - **Found a fourth systemic lazy-component gap**: a lazy component whose
    `provides_public_methods` includes `initialize` breaks any
    classic-inheritance SUBCLASS of the composed class -- the leaf's
    `super$initialize(...)` hits the lazy install-stub, whose body keys
    `install_lazy_inference_component()` off `class(self)[1L]` = the
    LEAF's name, which has no component-composition entry ("unused
    argument" errors / infinite recursion). No prior migrated class had
    classic subclasses, so this never surfaced. Fixed by making
    `ZeroAugmentedCountLikelihood` **eager** (`load_policy` default)
    rather than patching the shared stub machinery -- full rationale
    comment on the spec in `contracts_mixins.R`.
  - All 3 leaves verified bit-identical vs. legacy fixtures across
    estimate/asymp CI+pval/wald/rand/bootstrap/bayesian-bootstrap/
    LR-bootstrap (ZINB's NA cases match legacy exactly, including the
    identical fallback warnings). Guardrail tables updated (raw-splicing
    count for the new hoisted lists; root-owned-state entry
    `ZeroAugmentedCountLikelihood = "cached_vc_params"`);
    `test-full-likelihood-migration-baseline.R`'s lazy-policy assertion
    updated to eager with rationale. Full battery green (14 files); only
    the known pre-existing `test-parametric-bootstrap-lr-all-capable-
    classes.R` error remains.

  **Per-class migration push COMPLETE.** Remaining manifest "pending"
  entries (12) are all documented accepted terminal states: 11 thin
  leaves of already-composed abstracts (KK CLMM/GLMM families + the 3
  zero-augmented count leaves above) plus `InferenceOrdinalPairedSignTest`
  (tracked under "KK And IVWC Estimators").

  **`InferenceParamBootstrap` and `InferenceCountLikelihood` drained and
  removed from `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` (2026-08-21)**,
  closing out this push's base-deletion ladder. Confirmed via the same
  live ancestor-chain audit used throughout (`inference_class_ancestor_
  names()` intersected against the bases list for every non-abstract
  registered class): zero concrete descendants remain for either base
  after the Contin/count-family migrations. Both R6 generators KEPT (not
  deleted), per the established precedent:
  - `InferenceParamBootstrap`: still has real classic inheritors -- the
    kept harvesting-source generators `InferenceAsympLikStdModCache`/
    `InferenceKKPassThroughCompound`/`InferenceCountLikelihood`, plus the
    `InferenceAbstractKKWeibullFrailtyOneLikLegacyRaw`/
    `InferenceSurvivalKKClaytonCopulaOneLikLegacyRaw` legacy-comparison
    fixtures. It also remains the pin source for the
    `param_boot_compute_lik_ratio_bootstrap_*` private helpers on
    `InferenceCountPoisson` and `CountLikelihoodPlumbingSource`'s
    `cl_plumbing_param_boot_*` pins.
  - `InferenceCountLikelihood`: zero `inherit =` consumers remain
    anywhere, but the generator stays as the roxygen `@name` anchor for
    the shared count-likelihood docs and as the classic-ladder reference
    the `CountLikelihoodPlumbingSource` composition-safe overrides are
    defined against.
  Post-removal, the full re-audit shows exactly one concrete class
  package-wide with any algorithmic-compatibility ancestor:
  `InferenceOrdinalPairedSignTest` (the deliberately-deferred class above)
  -- so the remaining 12 bases in the list are held open only by that one
  class plus the abstract ladder itself. Targeted battery green after the
  removal (`test-inference-class-registry.R`, `test-mixin-contracts.R`,
  `test-static-cleanup-guardrails.R`, `test-capability-tables.R`,
  `test-full-likelihood-migration-baseline.R`,
  `test-bootstrap-reused-worker-families.R`,
  `test-parametric-bootstrap-lr-smoke-families.R` -- all zero
  failed/error/warning).

  **`InferenceOrdinalPairedSignTest` migrated (2026-08-21) -- the LAST
  concrete class package-wide with any algorithmic-compatibility
  ancestor.** Flipped from the hybrid `define_inference_class(inherit =
  InferenceAsympLik, components = "KKPassThrough")` state to full shallow
  composition: `inherit = Inference, components = c("BayesianBootstrap",
  "Wald", "KKPassThrough")`. The class never used any `InferenceAsympLik`
  likelihood machinery (its `supports_likelihood_tests()` has always been
  `FALSE`; its own `compute_asymp_*` methods call the z/t helpers
  directly, which live on `InferenceAsymp` = the `Wald` component's
  source), so `Wald` fully replaces the deep ladder's contribution.
  Pinned `compute_rand_two_sided_pval` from plain `InferenceRand` (not
  `InferenceRandCI`), matching every other migrated ordinal class. No
  `super$` fixes needed (the class's own `initialize` calls
  `super$initialize()` which now correctly resolves to root `Inference`,
  and `private$init_kk_passthrough(des_obj)` was already called explicitly
  per the KK recipe). Standard collision-declaration rounds only.
  Verified bit-identical via legacy-fixture comparison on a
  `DesignSeqOneByOneKK21` ordinal fixture: `compute_estimate`,
  `compute_asymp_confidence_interval`/`_two_sided_pval`,
  `compute_rand_two_sided_pval`,
  `compute_bayesian_bootstrap_two_sided_pval`, plus identical error
  messages for the deliberately-disabled bootstrap/jackknife methods and
  the no-context `compute_estimate_with_bootstrap_weights` guard.
  `mark_inference_class_migrated()` passes.

  **MILESTONE: zero concrete classes package-wide now descend from any
  algorithmic-compatibility base** (live ancestor-chain audit, all
  non-abstract registered classes). The manifest's 11 remaining "pending"
  records are all the documented accepted-terminal-state thin leaves of
  already-composed abstracts (KK CLMM/GLMM families + 3 zero-augmented
  count leaves), each with zero algorithmic ancestors by construction.
  Landed the endgame's final strict gate in the same change:
  `test-inference-class-registry.R`'s "remaining algorithmic compatibility
  descendants are explicitly tracked" test (which asserted the
  pending-with-ancestors set was NON-empty -- correct while draining, now
  the opposite of the invariant) was flipped into "no concrete class
  descends from an algorithmic compatibility base", asserting every
  concrete manifest record has `length(algorithmic_compatibility_ancestors)
  == 0L` -- the exact test the "Base Deletion" section's last TODO called
  for. Full battery green (`test-bayesian-bootstrap.R`,
  `test-mixin-contracts.R`, `test-inference-class-registry.R`,
  `test-capability-tables.R`, `test-static-cleanup-guardrails.R`,
  `test-full-likelihood-migration-baseline.R` -- all zero
  failed/error/warning).

#### Quasi And Robust Estimators

- [x] Identify all `likelihood_tier = "quasi"` concrete classes and verify
  whether each uses GEE, robust/sandwich, quasi-likelihood, or composite
  likelihood behavior.
- [x] Extract `RobustSandwich` and wire it into the count/robust-Poisson path
  (`InferenceCountRobustPoisson` uses `components = c("Wald",
  "CountCompositeLikelihood", "RobustSandwich")`, backed by real logic in
  `RobustSandwichSource`).
- [x] Wire `RobustSandwich` into the continuous robust-regression path.
  Audited 2026-08-12: `InferenceContinRobustRegr`
  (`inference_continuous_robust_regr.R:28`) still does
  `inherit = InferenceAsymp` directly and never references `RobustSandwich`;
  the original checklist item claimed both paths were done, but only the
  count/Poisson half was. **Re-investigated 2026-08-14** (separately from the
  hierarchy migration, which this class already completed earlier in this
  effort — it's `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald"))`, `likelihood_tier = "none"`, since the
  audit note above): **not applicable, closing without wiring it in.**
  `RobustSandwich` (`robust_sandwich_helpers.R`) implements the classical
  Huber-White heteroskedasticity-robust sandwich correction — `vcov = bread
  %*% meat %*% bread`, `meat = crossprod(X, X * residuals^2)` — designed to
  correct a GEE/quasi-likelihood model's naive MLE-based covariance for
  working-correlation misspecification (its `allowed_likelihood_tiers =
  "quasi"` reflects exactly this: it is only meaningful for a model that
  *has* a naive-likelihood covariance to correct). `InferenceContinRobustRegr`
  computes its standard error a completely different way:
  `fast_robust_regression_cpp`'s own `ssq_b_j`, documented in
  `fast_robust_regression.cpp:264-269` as "the standard M-estimator
  asymptotic variance ... matching the classical Huber (1981)
  **sandwich-free** M-estimator variance formula" — `Var(beta_hat_j) =
  (n/(n-p)) * (sum(psi(r_i)^2) / (n * mean(psi')^2)) * [(X'X)^-1]_jj`,
  where `psi` is the M-estimator's own influence function (Huber/Tukey
  bisquare) and `psi'` its derivative. This is not a sandwich form at all —
  no `meat`/`bread` split, no raw squared residuals, scale-normalized by the
  psi-function's own derivative rather than a naive-model covariance. The
  two "robust" paths share only the English word: `RobustSandwich` corrects
  a quasi-likelihood model's covariance for correlation/dispersion
  misspecification; `InferenceContinRobustRegr`'s formula *is* the
  asymptotic variance of a robust (Huber/Tukey) M-estimator, correct on its
  own terms and with no naive covariance to "correct" in the first place.
  Wiring `RobustSandwich` in would silently replace a statistically correct,
  purpose-built formula with a mismatched one (and would require loosening
  `RobustSandwich`'s `allowed_likelihood_tiers` past `"quasi"` to even
  compose it against this `"none"`-tier class, which itself should have been
  a signal that the two don't belong together). No code changed; this entry
  documents the investigation so the same false-cognate confusion isn't
  re-triggered by a future pass over "all classes with 'robust' in the
  name."
- [x] Extract `CompositeLikelihoodTests` if composite likelihood needs public
  APIs distinct from normalized likelihood tests.
- [x] Migrate `KKGEE` users to `Inference` plus `KKGEE` and required estimator
  components after host requirements are fully declared.
- [x] Migrate count quasi-Poisson and robust Poisson classes to `Inference` plus
  `CountCompositeLikelihood` and quasi-specific components.
- [x] Ensure quasi classes do not expose normalized likelihood-ratio capability
  unless represented by `estimating_equation_likelihood_ratio`.
- [x] Mark migrated quasi/robust classes only after estimate, SE, CI, p-value,
  and method-availability snapshots match.
- **Progress 2026-08-18: `InferenceContinKKRobustRegrOneLik` migrated** —
  the robust-regression OneLik sibling of `InferenceContinKKRobustRegrIVWC`
  (migrated earlier this stretch). Structurally the same shape as
  `InferenceContinKKOLSOneLik`'s pre-migration state (real R6 inheritance,
  not a raw splice) but on `InferenceKKPassThroughCompoundNoParamBootstrap`
  instead of `InferenceKKPassThroughCompound`, since this class has no
  likelihood-test surface — `"quasi"` tier, same as the IVWC sibling. New
  registered component `ContinKKRobustRegrOneLik`
  (`dependencies = "KKCompound"`, no `ParametricLikelihoodBootstrap`).
  Factory composes `c("BayesianBootstrap", "Wald",
  "ContinKKRobustRegrOneLik")`, `InferenceRand` pin. Lesson 1 applied
  proactively. One golden-test wrinkle, same as the IVWC sibling's own
  golden: `score_ci` comes back `"ok"` on the legacy side with a real
  (non-NA, non-degenerate) value, because `compute_score_confidence_
  interval()` bypasses the `supports_likelihood_tests() == FALSE` gate and
  calls `invert_test_pval_confidence_interval()` directly, which numerically
  root-finds around the Wald estimate rather than returning it in closed
  form — verified Wald-fallback (not real likelihood-test surface) using
  the exact same tolerance-widened comparison the IVWC golden already
  established, reused directly here. Golden
  `test-contin-kk-robust-regr-onelik-migration-golden.R`: all green after
  adopting that check (only needed because my first draft used a looser,
  wrong check that didn't anticipate an `"ok"`-status Wald-fallback CI).
  Static tables updated: registry direct-components mapping;
  `test-mixin-contracts.R` canonical component list.
  `test-static-cleanup-guardrails.R` needed no ratchet updates (no raw
  splice, no `eval(body(...))` in the pre-migration class).
  `test-parametric-bootstrap-lr-all-capable-classes.R` and
  `helper-likelihood-method-smoke.R` deliberately left unchanged: this
  "quasi"-tier class composes no `LikelihoodTests`/
  `ParametricLikelihoodBootstrap`, so it has no real score/gradient/LR
  surface to smoke-test (same reasoning as the Wald-only IVWC classes
  excluded from the smoke suite earlier this stretch). Full regression
  battery green: this golden, the Robust-Regr IVWC golden (checked for
  regressions), `test-quasi-robust-migration-baseline.R`,
  `test-mixin-contracts.R`, `test-static-cleanup-guardrails.R`,
  `test-inference-class-registry.R`, `test-likelihood-method-smoke.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`.

#### Partial-Likelihood Estimators

- [x] Identify all `likelihood_tier = "partial"` concrete classes.
- [x] Extract Cox/stratified-Cox shared behavior from
  `InferenceAsympLikStdModCache`.
- [x] Extract conditional-logit shared behavior from current conditional
  incidence and ordinal classes.
- [x] Extract LWA Cox and survival rank-regression shared behavior before moving
  their concrete classes.
- [x] Migrate non-KK partial-likelihood classes to `Inference` plus
  `LikelihoodTests`, `StandardModelCache`, and family-specific components.
- [x] Migrate KK partial-likelihood classes only after `KKPassThrough` and
  `KKCompound` host contracts pass collision and dependency validation.
  **Completed 2026-08-19: `InferenceOrdinalKKCondAdjCatLogitRegr` and the
  `InferenceAbstractKKOrdinalCLMM` family migrated**, closing out this item
  (verified via the migration manifest: the only remaining `"pending"`
  `likelihood_tier = "partial"` entries afterward are
  `InferenceIncidKKCondLogitGLMMIVWC`/`...OneLik`, which are the expected
  parent-heuristic artifact of already-migrated plain-R6 leaves, not real
  unmigrated classes -- same as every other `InferenceAsympLikStdModCache`-
  style leaf).
  - `InferenceOrdinalKKCondAdjCatLogitRegr`
    (`inference_ordinal_KK_cond_adj_cat_logit.R`) was already a
    `define_inference_class()` call composing the right domain components
    (`OrdinalConditionalLogitPartialLikelihood`, `KKPassThrough`), but still
    `inherit = InferenceAsympLik` -- the same hybrid half-migrated state as
    the KKGLMM family. Flipped to `inherit = Inference` with `Wald` composed
    explicitly (not `ParametricLikelihoodBootstrap`: this class's
    `supports_likelihood_tests()` is hard-`FALSE`, so it never gets Wald
    transitively through `ParametricLikelihoodBootstrap`'s `LikelihoodTests`
    dependency the way the KKGLMM family does -- confirmed by grepping every
    other Wald-only KK IVWC class's `components =` list for the same
    explicit `"Wald"` entry). `compute_rand_two_sided_pval` pinned from
    `InferenceRandCI` (confirmed via the pre-migration R6 ancestor walk,
    not assumed from the KKGLMM-family precedent).
  - `InferenceAbstractKKOrdinalCLMM` (`inference_ordinal_KK_clmm_abstract.R`)
    was in the identical hybrid state (`inherit = InferenceAsympLik,
    components = "KKPassThrough"`), with 4 concrete plain-R6 leaves
    (`InferenceOrdinalKKCLMM`, `...Probit`, `...Cauchit`, `...Cloglog`) --
    migrating the shared abstract base once fixed all four, same pattern as
    the `InferenceAbstractKKCondLogitGLMM` trio earlier this stretch. Same
    `Wald`-not-`ParametricLikelihoodBootstrap` and `InferenceRandCI` pin
    reasoning as the AdjCatLogit class above.
  - **Golden-test discovery, both classes**: calling
    `compute_score_two_sided_pval()`/`compute_gradient_confidence_interval()`/
    `compute_lik_ratio_*()` *directly* (bypassing `set_testing_type()`, which
    correctly throws "does not support testing_type" on both legacy and
    migrated, confirming the class's own designed API is unchanged) reached
    leaked `InferenceAsympLik`-ladder plumbing on the pre-migration legacy
    classes that silently returned `NA` -- or, for one label (`score_ci`),
    silently fell back to the exact Wald CI -- rather than erroring. The
    migrated (flat composition, no `LikelihoodTests` component) classes
    don't expose these methods at all. Verified via the same
    `maybe_dropped_labels` + degenerate-or-Wald-fallback verification
    pattern established by `test-incid-kk-cond-logit-ivwc-migration-golden.R`
    (checks the *value*, not just the presence/absence, so a real dropped
    result would fail loudly) rather than blindly accepting the status
    mismatch.
  - Golden tests added: `test-ordinal-kk-cond-adj-cat-logit-migration-golden.R`
    (fixture `fixtures/legacy_ordinal_kk_cond_adj_cat_logit.R`) and
    `test-ordinal-kk-clmm-migration-golden.R` (all 4 link-function leaves,
    fixture `fixtures/legacy_ordinal_kk_clmm.R` covering the abstract base
    plus all four leaves) -- all passing.
  - Fixed the same class of stale `infer_inference_direct_components()`
    registry-switch-entry gap hit repeatedly this stretch, for both
    `InferenceOrdinalKKCondAdjCatLogitRegr` and
    `InferenceAbstractKKOrdinalCLMM`.
  - Full regression battery (`test-mixin-contracts.R`,
    `test-static-cleanup-guardrails.R`,
    `test-parametric-bootstrap-lr-all-capable-classes.R`,
    `test-partial-likelihood-migration-baseline.R`, plus both new golden
    files) green.
  **Earlier progress 2026-08-18: `InferenceSurvivalKKLWACoxPHOneLik` migrated** —
  the LWA Cox OneLik sibling of the `InferenceSurvivalKKLWACoxPHIVWC`
  migration earlier this stretch. Same two-layer shape (abstract
  `InferenceAbstractKKLWACoxOneLik` on `InferenceParamBootstrap`,
  raw-splicing `InferenceMixinKKPassThrough$public/private`, plus a thin
  assertFormula/delegating leaf) merged into the previously shim-only
  registered component `KKLWACoxOneLikPartialLikelihood`
  (`KKLWACoxOneLikPartialLikelihoodSource`, `dependencies` reshaped from
  `"ParametricLikelihoodBootstrap"` alone to `c("KKPassThrough",
  "ParametricLikelihoodBootstrap")` — the latter already depends on
  `LikelihoodTests` transitively). **First genuinely full-likelihood-tier
  migration this stretch** (real score/gradient/LR test support via
  `get_likelihood_test_spec()`/`simulate_under_lik_null()`, unlike every
  Wald-only IVWC/gcomp/quantile-regr leaf before it): needed
  `metadata$capabilities = "likelihood_ratio"` declared explicitly on the
  class, since no component spec in this codebase provides that capability
  automatically — any class composing `ParametricLikelihoodBootstrap`
  directly (bypassing `StandardModelCache`) must declare it itself, same as
  `InferenceOrdinalCauchitRegr`/`InferenceOrdinalCloglogRegr`. Several new
  collision names surfaced that the Wald-only recipe never touched:
  `approximate_bootstrap_distribution_beta_hat_T`, `get_supported_testing_
  types` (public); `supports_information_preference`, `supports_observed_
  information`, `get_supported_information_preferences_impl`,
  `supports_bartlett_likelihood_ratio_approx`, `get_bartlett_factor_approx`
  (private) — all declared in `overrides`. `InferenceRand` pin (survival,
  not incidence, so no Lesson-3 RandCI question). **Found and documented
  (not fixed) a serious pre-existing native crash** while writing the
  golden — see the dedicated Follow-Ups entry,
  "`InferenceSurvivalKKLWACoxPHOneLik` native segfault." Golden
  `test-survival-kk-lwa-cox-onelik-migration-golden.R` (real classname; the
  legacy fixture had to manually re-splice `InferenceMixinKKPassThrough$
  private` since the merged Source deliberately dropped it — `inherit =
  InferenceParamBootstrap` doesn't supply `init_kk_passthrough` the way
  `InferenceKKPassThroughCompoundNoParamBootstrap` did for the IVWC
  siblings; per-label fresh object construction to sidestep the crash): all
  green. Static expectations updated in three places (component contract
  shape, load-trace, and target-components) in
  `test-partial-likelihood-migration-baseline.R`, same treatment as the LWA
  Cox IVWC entries; guardrail ratchets updated (splice-count file removed
  entirely, one new root-state redeclaration entry for `optimization_alg`).
  **Progress 2026-08-18: `InferenceSurvivalKKStratCoxPHOneLik` migrated** —
  the stratified-Cox OneLik sibling of `InferenceSurvivalKKStratCoxPHIVWC`
  (migrated earlier this stretch, see "KK And IVWC Estimators" below).
  Unlike the LWA Cox OneLik pair, this was a **single-layer** R6 leaf (no
  separate abstract base) inheriting `InferenceParamBootstrap` and
  raw-splicing `InferenceMixinKKPassThrough$public/private`. Its own body
  became a brand-new registered component,
  `SurvivalKKStratCoxOneLikPartialLikelihood`
  (`SurvivalKKStratCoxOneLikPartialLikelihoodSource`,
  `dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap")`) —
  not a reshape of a pre-existing shim, since none existed for this class.
  Factory composition `c("BayesianBootstrap",
  "SurvivalKKStratCoxOneLikPartialLikelihood")`, `InferenceRand` pin,
  `metadata$capabilities = "likelihood_ratio"` declared explicitly (same
  requirement as every class composing `ParametricLikelihoodBootstrap`
  directly, bypassing `StandardModelCache`). Lesson 1 applied
  proactively (`private$init_kk_passthrough(des_obj)` added to the merged
  source's `initialize`). The class's own
  `eval(body(InferenceMixinKKPassThrough$public$approximate_bootstrap_
  distribution_beta_hat_T))` override was dropped as a verified no-op (same
  argument as every other KK leaf this stretch), and — unlike the LWA Cox
  OneLik pair — this class never overrode
  `compute_treatment_estimate_during_randomization_inference` itself, so
  that method was **not** duplicated into the new source either; it flows
  through unchanged from the `KKPassThrough` dependency, declared only as a
  collision override on the factory. One new wrinkle versus the LWA Cox
  OneLik precedent: the class's own `best_X_colnames` private state field
  (mutable, written inside `shared_combined_likelihood`) needed to be added
  to the component's `owns_state` — first pass omitted it and hit "cannot
  change value of locked binding" on first use, since `define_inference_
  class()` locks any private field not explicitly declared as owned state.
  Golden `test-survival-kk-strat-cox-onelik-migration-golden.R` (real
  classname; legacy fixture manually re-splices
  `InferenceMixinKKPassThrough$public/private` onto `InferenceParamBootstrap`
  to stay faithful, same as the LWA Cox OneLik legacy fixture) — all green
  on the first run, using the normal shared-object-per-label loop (no
  discovered crash for this class, unlike its LWA Cox sibling). Static
  expectations updated in the registry (`inference_class_registry.R`'s
  direct-components mapping and the `EDI_PARTIAL_LIKELIHOOD_TARGETS` entry,
  which had never carried `target_direct_components` before this migration —
  unlike the LWA Cox OneLik entry, which already had one from an earlier
  pass) and in `test-partial-likelihood-migration-baseline.R` (new
  `partial_likelihood_expected_extracted_strat_cox_one_lik_targets` list plus
  two new `test_that` blocks for the component's contract shape and
  load-trace, mirroring the LWA Cox OneLik treatment exactly). Guardrail
  ratchets updated in `test-static-cleanup-guardrails.R` (both the
  eval(body(...)) and raw-splice per-file counts for
  `inference_survival_KK_strat_cox.R` dropped to 0 and their table entries
  removed entirely; one new root-state redeclaration entry for
  `optimization_alg`, the only one of the component's three owned-state
  fields that is also root-owned). `SurvivalKKStratCoxOneLikPartialLikelihood`
  added to `test-mixin-contracts.R`'s canonical component list. Full
  regression battery green: `test-partial-likelihood-migration-baseline.R`,
  this class's golden, the StratCox IVWC and LWA Cox OneLik goldens (checked
  for regressions), `test-mixin-contracts.R` (aside from one pre-existing,
  unrelated failure — see note below), `test-inference-class-registry.R`,
  `test-static-cleanup-guardrails.R`, `test-likelihood-method-smoke.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`,
  `test-full-likelihood-migration-baseline.R`.
  **Note (not this session's work, flagged for awareness):**
  `test-mixin-contracts.R`'s "active behavior components are registered"
  test independently fails on a pre-existing gap — a `MarginalEstimand`
  component (`R/inference_all_abstract_marginal_estimand.R`, currently
  untracked in git alongside uncommitted edits to
  `marginal_estimand_report.md`/`expanded_estimate_report.md`) is registered
  as active but missing from that test's `canonical_component_names()`
  list. Confirmed via `git stash` that this failure exists independent of
  every change in this entry (reproduces with only the untracked
  marginal-estimand file present and none of this session's edits). Left
  untouched as out-of-scope, concurrent, in-progress work on a different
  feature; resolved on its own by that concurrent work shortly after (its
  `canonical_component_names()` fix landed independently, confirmed still
  passing at the next migration's regression run below).
  **Progress 2026-08-18: `InferenceContinKKOLSOneLik` migrated** — first
  full (non-Cox-partial) one-likelihood KK class this stretch (Gaussian OLS
  with real score/gradient/LR tests and an exact, not merely
  higher-order-accurate, Bartlett factor). Unlike the LWA/StratCox OneLik
  pairs, this was a plain R6 leaf using **real R6 inheritance** (not a raw
  mixin splice) on the real R6 abstract `InferenceKKPassThroughCompound`
  (itself `inherit = InferenceParamBootstrap`, composing
  `InferenceMixinKKPassThroughCompound`/`InferenceMixinKKPassThrough` via
  `compose_inference_mixins()`). The leaf's own body became a brand-new
  registered component `ContinKKOLSOneLikLikelihood`
  (`dependencies = c("KKCompound", "ParametricLikelihoodBootstrap")` —
  `KKCompound` supplies `reduce_design_matrix_once()`/
  `compute_basic_match_data()`/`init_kk_passthrough()`, the same as every
  KKCompound-dependent IVWC leaf migrated earlier this stretch).
  Factory composes `c("BayesianBootstrap", "ContinKKOLSOneLikLikelihood")`,
  `InferenceRand` pin, `metadata = list(likelihood_tier = "full",
  capabilities = "likelihood_ratio")` (same explicit-capabilities
  requirement as every class composing `ParametricLikelihoodBootstrap`
  directly). Lesson 1 applied proactively
  (`private$init_kk_passthrough(des_obj)` added after `super$initialize()`).
  No raw splice, no `eval(body(...))` restatement, and no non-root mutable
  state to declare as `owns_state` — the simplest of the OneLik migrations
  so far structurally, since real R6 inheritance meant the leaf's own body
  was already a clean, self-contained method set with nothing implicitly
  inherited to hand-copy in. Golden
  `test-contin-kk-ols-onelik-migration-golden.R` (legacy fixture reproduces
  the pre-migration class via real R6 inheritance on
  `InferenceKKPassThroughCompound`, no splice needed): all green on the
  first run. Static tables updated: registry direct-components mapping;
  `test-mixin-contracts.R` canonical component list. The
  `test-full-likelihood-migration-baseline.R` and
  `test-parametric-bootstrap-lr-all-capable-classes.R` generic/registry-driven
  checks needed no changes (this class was already listed as a target in
  both, and neither hardcodes this class's specific component chain).
  `test-static-cleanup-guardrails.R` needed no ratchet updates either (the
  pre-migration class never used raw splicing or `eval(body(...))`).
  **Filled a genuine coverage gap**: `helper-likelihood-method-smoke.R` had
  no continuous/GLM-family block at all before this migration (every other
  response-type family — count, incidence, ordinal, survival — already had
  one); added a minimal `should_run("continuous")` block with a
  `make_kk_continuous_design()` helper covering just this one new class,
  scoped to what this migration needs rather than backfilling the whole GLM
  family's smoke coverage. Full regression battery green (this golden, the
  StratCox OneLik and OLS IVWC goldens checked for regressions,
  `test-full-likelihood-migration-baseline.R`,
  `test-partial-likelihood-migration-baseline.R`, `test-mixin-contracts.R`,
  `test-static-cleanup-guardrails.R`, `test-likelihood-method-smoke.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`,
  `test-inference-class-registry.R`, `test-bartlett-lr-ols-exact.R`,
  `test-bartlett-lr-approx-smoke-families.R`, `test-kk-ols-se.R`,
  `test-likelihood-test-memoization.R`).
  **Note (not this session's work, flagged for awareness):**
  `test-asymp-inference-paths.R` independently fails (10 pre-existing
  failures: several "Ordinal Asymp paths" errors and one "KK Bai-adjusted
  inference" failure) — confirmed via `git stash`/`stash pop` that these
  reproduce identically with none of this session's changes applied; caused
  by the same concurrent marginal-estimand work (a new
  `get_supported_testing_types_with_bartlett()` branch in
  `inference_all_abstract_asymp_lik.R` gating on
  `self$supports("marginal_estimand")`). Left untouched as out-of-scope.
  **Progress 2026-08-19: `InferenceContinKKQuantileRegrOneLik` /
  `InferencePropKKQuantileRegrOneLik` migrated** — the one-likelihood
  siblings of `InferenceContinKKQuantileRegrIVWC`/`InferencePropKKQuantileRegrIVWC`
  (migrated earlier this stretch). Same structurally-different shape as its
  IVWC siblings' migration: pre-migration this was a **three-tier R6 chain**
  (concrete leaf → `InferenceAbstractKKQuantileRegrOneLik` →
  `InferenceAbstractQuantileRandCI`, the same hybrid partially-migrated base
  the IVWC family used). The middle abstract was converted to the registered
  `KKQuantileRegrOneLik` component (`dependencies = c("KKCompound",
  "QuantileRandomizationCI")` — no `ParametricLikelihoodBootstrap`: despite
  the "combined-likelihood"/"OneLik" naming, this class has no real
  score/gradient/LR test surface at all, just `quantreg::rq()` sandwich SEs,
  so `likelihood_tier = "none"`, same as the IVWC sibling). Same **two
  leaves, one component, each with different init-wrapping logic** pattern
  as the IVWC migration: factored the shared tau/transform_y_fn/KK-setup
  logic into a free-function helper, `.init_kk_quantile_regr_one_lik(self,
  private, super, ...)` (mirroring the pre-existing
  `.init_kk_quantile_regr_ivwc()`), which each leaf's own `initialize` calls
  directly (Lesson 1 corollary — a flat composition has no `super$` path
  into a component's own `initialize` once a host wins that collision, so
  each leaf must call `super$initialize()` from a method actually bound to
  its own construction). One new wrinkle beyond the IVWC precedent: both
  leaves' pre-migration `compute_estimate = function(estimate_only = FALSE)
  super$compute_estimate()` was a pure delegating passthrough with no added
  logic (didn't even forward `estimate_only`) — dropped from both migrated
  classes rather than reimplemented, letting the composed
  `KKQuantileRegrOneLik` component's real `compute_estimate` win directly;
  still had to be declared in each factory's `overrides$public` even with no
  host definition, since `Wald`'s generic default also defines the name (an
  undeclared-collision load error surfaced this on the first attempt).
  Golden `test-kk-quantile-regr-onelik-migration-golden.R` closely mirrors
  `test-kk-quantile-regr-ivwc-migration-golden.R`'s structure (inline `R6::
  R6Class(...)` legacy reconstruction of the 3-tier chain — required because
  `inherit =` is evaluated lazily in the EDI namespace at `$new()` time, so
  only a self-contained expression of namespace-qualified/base symbols
  survives; the same Wald-fallback-or-degenerate dropped-label verification
  for score/gradient/lik_ratio labels, probed on a throwaway clone as a
  precaution mirroring the IVWC golden even though this class didn't
  actually exhibit the corrupting side effect the IVWC family's own golden
  had to work around): all green (with `NOT_CRAN=true`; two `skip_on_cran()`
  tests otherwise skip locally, matching the IVWC golden's own skip
  policy). Static tables updated: registry direct-components mapping (both
  classes); `test-mixin-contracts.R` canonical component list;
  `test-static-cleanup-guardrails.R`'s root-owned-state redeclaration table
  (new `KKQuantileRegrOneLik = "m"` entry, same shape as `KKQuantileRegrIVWC`).
  `test-full-likelihood-migration-baseline.R` needed no changes despite
  listing both classes (its `current_likelihood_tier` classification is
  independent of the factory's own `metadata$likelihood_tier` and was
  already satisfied); `test-parametric-bootstrap-lr-all-capable-classes.R`
  and `helper-likelihood-method-smoke.R` deliberately left unchanged (no
  real likelihood-test surface to smoke-test, same reasoning as every other
  `"none"`-tier KK leaf this stretch). Full regression battery green.
  **Progress 2026-08-19: `InferenceCountKKHurdlePoissonOneLik` migrated** —
  the one-likelihood sibling of `InferenceCountKKHurdlePoissonIVWC` (migrated
  2026-08-17). Single-layer raw-splice class (`inherit = InferenceParamBootstrap`
  raw-splicing `InferenceMixinKKPassThrough$public/private`), same shape as
  the LWA/StratCox OneLik pairs, but with a **new wrinkle not seen in any
  prior migration this stretch**: this class's own
  `compute_score_confidence_interval`/`compute_lik_ratio_confidence_interval`/
  `compute_gradient_confidence_interval`/`compute_score_two_sided_pval`/
  `compute_lik_ratio_two_sided_pval`/`compute_gradient_two_sided_pval` are
  NOT pure delegating passthroughs (unlike the quantile-regr OneLik pair's
  dropped `compute_estimate`) — each computes a "design-conservative"
  combination (`.conservative_kk_onelik_ci`/`.conservative_kk_onelik_pval`,
  free functions already at the top of this file) of a design-based CI/
  p-value (from this class's own `shared_combined_hurdle`) and a
  "model"-based CI/p-value obtained via `super$...()` under the old R6
  ladder — reaching `InferenceAsympLik`'s generic likelihood-test dispatch
  (the exact same machinery now harvested verbatim as the `LikelihoodTests`
  component). Since a flat composition has no `super$` path into a
  component's own method once the host wins that name collision (Lesson 1),
  simply dropping these overrides was not an option (real distinct logic,
  not dead weight) and reimplementing the generic dispatch inline would
  duplicate real machinery. **Solved by reusing the existing
  generic-`self$`-aliased-override pattern**
  (`incidence_gcomp_generic_alias_overrides`, `inference_incidence_gcomp.R`,
  already used for an analogous problem with `InferenceNonParamBootstrap`/
  `InferenceBayesianBootstrap`/`InferenceJackknife`'s generic methods): six
  new public aliases (`compute_score_confidence_interval_generic`, etc.)
  bound directly from `InferenceAsympLik$public_methods$...` (a real,
  untouched R6 class — still the harvesting source for the `LikelihoodTests`
  component), and the six `super$...()` calls rewritten to
  `self$..._generic()`. Verified this preserves behavior exactly: the alias
  is a copy of `InferenceAsympLik`'s own method body, which itself only
  delegates to `private$..._impl()` — R6 rebinds the copied function's
  environment to the live composed object at construction, so
  `private$..._impl` resolves to whatever the FINAL composed private list
  provides (here, `InferenceAsympLik`'s own generic `_impl` defaults via the
  `LikelihoodTests` component, driven by this class's own
  `get_likelihood_test_spec()`) — functionally identical to what `super$`
  reached pre-migration. New component
  `CountKKHurdlePoissonOneLikLikelihood`
  (`dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap")` — no
  `KKCompound`: this class never composed it even pre-migration, since its
  own `compute_basic_match_data` uses `.compute_kk_basic_match_data_cached()`
  directly and its `initialize` performs its own manual `has_match_structure`/
  `m` setup rather than calling `init_kk_passthrough()` — preserved verbatim,
  no Lesson-1 initialize fix needed here, unlike every other OneLik
  migration this stretch). Lesson 5 applied (`get_standard_error` copied in
  verbatim: this class never defined it itself, relying on
  `InferenceMLEorKMSummaryTable`'s graceful NA-on-missing-SE version via the
  old ladder). `approximate_bootstrap_distribution_beta_hat_T`'s
  `eval(body(...))` restatement dropped as a verified no-op (same argument
  as every other KK leaf this stretch). `metadata = list(likelihood_tier =
  "full", capabilities = "likelihood_ratio")` (same explicit-capabilities
  requirement as every class composing `ParametricLikelihoodBootstrap`
  directly). Golden `test-count-kk-hurdle-poisson-onelik-migration-golden.R`
  (legacy fixture manually re-splices `InferenceMixinKKPassThrough$public/
  private` AND re-adds the dropped `eval(body(...))` restatement, same
  treatment as `test-count-kk-hurdle-ivwc-migration-golden.R`'s legacy
  fixture): all green on the first run — the design-conservative combination
  logic came through byte-identical with no dropped labels needed at all
  (unlike most other OneLik goldens this stretch). Static tables updated:
  registry direct-components mapping; `test-mixin-contracts.R` canonical
  component list; `test-static-cleanup-guardrails.R` (both eval(body(...))
  and raw-splice per-file counts for `inference_count_KK_cond_poisson.R`
  dropped, 2→1 and 6→3 respectively — the remainders are the still-unmigrated
  `InferenceCountKKCondPoissonOneLik` sibling's own splice/restatement; one
  new root-state redeclaration entry for `m`, the only root-owned field of
  this component's four `owns_state` fields). Filled another coverage gap in
  `helper-likelihood-method-smoke.R`: added a `make_kk_count_design()`
  helper and this class as the first KK-count entry in the existing
  `should_run("count")` block (which previously only covered non-KK count
  families). `test-parametric-bootstrap-lr-all-capable-classes.R` already
  listed this class as a target from an earlier pass — no change needed.
  Full regression battery green.
  **Progress 2026-08-19: `InferenceCountKKCondPoissonOneLik` migrated** —
  the file-sibling of `InferenceCountKKHurdlePoissonOneLik` above, confirmed
  to share the identical `super$compute_score/lik_ratio/gradient_*`
  "design-adjusted" pattern (found via the same grep that located the
  HurdlePoisson class's six `super$` calls). Same fix: six new
  `self$..._generic` aliases bound from `InferenceAsympLik$public_methods$...`,
  the six `super$...()` calls rewritten to call them. One difference from
  the HurdlePoisson entry: this class's `initialize` **already** called
  `private$init_kk_passthrough(des_obj)` explicitly pre-migration (unlike
  HurdlePoisson's manual match-structure setup) — preserved verbatim, no
  Lesson-1 fix needed. Lesson 5 applied (`get_standard_error` copied in
  verbatim; never defined itself). `approximate_bootstrap_distribution_
  beta_hat_T`'s `eval(body(...))` restatement dropped as a verified no-op.
  New component `CountKKCondPoissonOneLikLikelihood`
  (`dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap")`,
  same shape as `CountKKHurdlePoissonOneLikLikelihood`). One new wrinkle:
  the registry's `provides_private_methods`/`provides_public_methods` lists
  had to be corrected against the Source's actual `names(src$private)`/
  `names(src$public)` after two "contract mismatch" load errors — guessed
  private-method names (`combined_cpoisson_neg_loglik`/`combined_cpoisson_
  score`/etc., extrapolated from the HurdlePoisson sibling's naming
  convention) didn't match this class's actual internal names
  (`weighted_cpoisson_neg_loglik`/`weighted_cpoisson_score`, no separate
  `combined_cpoisson_hessian` — folded into `fit_combined_cpoisson`); fixed
  by querying `names(EDI:::CountKKCondPoissonOneLikLikelihoodSource$private)`
  directly rather than continuing to guess. Golden
  `test-count-kk-cond-poisson-onelik-migration-golden.R` (same legacy-fixture
  shape as the HurdlePoisson OneLik golden: manual re-splice plus re-added
  no-op `eval(body(...))` restatement): all green on the first run after the
  contract fix, no dropped labels needed. Static tables updated: registry
  direct-components mapping; `test-mixin-contracts.R` canonical component
  list; `test-static-cleanup-guardrails.R`'s eval(body(...)) and raw-splice
  per-file counts for `inference_count_KK_cond_poisson.R` both dropped to 0
  (both classes in that file are now migrated) — entries **removed
  entirely** rather than decremented, unlike the HurdlePoisson entry's
  partial decrement. No new root-state redeclaration entry needed (neither
  `cached_mod` nor `max_abs_reasonable_coef`, this component's only
  `owns_state` fields, is root-owned). Added a second KK-count entry
  (`InferenceCountKKCondPoissonOneLik`) to `helper-likelihood-method-smoke.R`'s
  `should_run("count")` block, reusing the `make_kk_count_design()` helper
  added for the HurdlePoisson entry. `test-parametric-bootstrap-lr-all-
  capable-classes.R` already listed this class as a target — no change
  needed. Full regression battery green.
  **Progress 2026-08-19: `InferenceIncidKKCondLogitOneLik` migrated** —
  single-layer raw-splice class (`inherit = InferenceParamBootstrap`
  raw-splicing `InferenceMixinKKPassThrough$public/private`), simpler in
  scope than the two count OneLik migrations above: only
  `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`
  fast-path the `"wald"` testing type directly and fall back to
  `super$...()` for score/gradient/lik_ratio (reaching `InferenceAsympLik`'s
  generic switch dispatch) — the six-method "design-conservative"/
  "design-adjusted" pattern from the count classes doesn't appear here at
  all, since this class never overrides the individual
  score/gradient/lik_ratio methods themselves. Fixed with the same
  generic-`self$`-aliased-override technique, but only **two** new aliases
  needed (`compute_asymp_confidence_interval_generic`,
  `compute_asymp_two_sided_pval_generic`, bound from
  `InferenceAsympLik$public_methods$...`). Also found and dropped a second
  no-op: this class's own `compute_basic_match_data = function()
  private$compute_basic_kk_match_data_impl()` is byte-identical to
  `InferenceMixinKKPassThrough`'s own default `compute_basic_match_data`
  body (same free function, same wrapping) — a verified no-op restatement,
  same category as the `eval(body(...))` restatements dropped everywhere
  else this stretch, just not previously named as its own pattern. This
  class already defined `get_standard_error` itself, so **no Lesson-5 fix
  needed** (first OneLik migration this stretch where that was already
  true). `InferenceRandCI` pin (incidence class — Lesson 3, matching the
  already-migrated `InferenceIncidKKCondLogitIVWC` sibling). New component
  `IncidKKCondLogitOneLikLikelihood`
  (`dependencies = c("KKPassThrough", "ParametricLikelihoodBootstrap")` —
  fits one joint combined logistic likelihood directly, no
  KKCompound-style variance-weighted combination, same shape as the count
  OneLik components). Golden
  `test-incid-kk-cond-logit-onelik-migration-golden.R` (legacy fixture
  manually re-splices `InferenceMixinKKPassThrough$public/private` and
  re-adds BOTH dropped no-op restatements — the `compute_basic_match_data`
  one and the `eval(body(...))` `approximate_bootstrap_distribution_
  beta_hat_T` one): all green on the first run, no dropped labels needed.
  Static tables updated: registry direct-components mapping AND the
  registry's aspirational `EDI_PARTIAL_LIKELIHOOD_TARGETS` entry (was still
  naming the never-actually-composed `ConditionalLogitPartialLikelihood`
  component — same staleness already fixed for the IVWC sibling, fixed here
  too for consistency even though the generic manifest test doesn't assert
  exact target values); `test-partial-likelihood-migration-baseline.R`'s
  matching `partial_likelihood_expected_extracted_conditional_logit_targets`
  entry updated to the factory reality (same treatment as the IVWC entry
  above it); `test-mixin-contracts.R` canonical component list;
  `test-static-cleanup-guardrails.R`'s eval(body(...)) and raw-splice
  per-file counts for `inference_incidence_KK_cond_logit.R` both dropped to
  0 — entries removed entirely (this was the only class left in that file
  using either pattern; the IVWC sibling was already migrated). Added an
  `InferenceIncidKKCondLogitOneLik` entry to `helper-likelihood-method-
  smoke.R`'s `should_run("incidence")` block, reusing the pre-existing
  `make_kk_incidence_design()` helper. `test-parametric-bootstrap-lr-all-
  capable-classes.R` already listed this class as a target — no change
  needed. Full regression battery green.
  **Progress 2026-08-19: `InferenceSurvivalKKClaytonCopulaOneLik` migrated**
  — single-layer raw-splice class, no `super$` calls needing the
  generic-`self$`-aliased-override fix (unlike the count/incidence OneLik
  classes above). **Structurally different from every other migration this
  stretch**: a registered component `SurvivalKKClaytonCopulaOneLik` already
  existed (self-harvested via `inference_component_source_parts()`,
  `dependencies = character()`) — because this class's public/private were
  built via a raw `modifyList(InferenceMixinKKPassThrough$public/private,
  list(...))` splice rather than true R6 inheritance, the harvest
  necessarily captures the FULL flattened surface (mixin content + own
  logic merged into one list at harvest time — R6 cannot separate "own"
  from "spliced-in" once merged like this). Rather than reshaping this into
  a leaf-only-plus-`KKPassThrough`-dependency component (the shape every
  other migration this stretch used), the pre-migration class body is kept
  alive as-is under a renamed, non-exported binding
  (`InferenceSurvivalKKClaytonCopulaOneLikLegacyRaw`, same class-name
  *string* passed to `R6::R6Class()` so any class-identity-keyed dispatch —
  e.g. `globals.R`'s optimizer policy — stays correct if the raw generator
  is ever touched) purely so the pre-existing harvest at load time still
  has something to snapshot from; `InferenceSurvivalKKClaytonCopulaOneLik`
  itself is now the `define_inference_class()` factory, composing
  `c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
  "SurvivalKKClaytonCopulaOneLik")` (the harvested component supplies
  `get_likelihood_test_spec()` but not the public score/gradient/lik_ratio
  dispatch methods, which arrive via `ParametricLikelihoodBootstrap`'s
  `LikelihoodTests` dependency). This class already called `private$
  init_kk_passthrough(des_obj)` explicitly, so no Lesson-1 fix was needed.
  **Consequence of keeping the raw class alive**: unlike every other
  migration this stretch, `test-static-cleanup-guardrails.R`'s eval(body(...))
  and raw-splice per-file counts for `inference_survival_KK_clayton_copula.R`
  did **not** need to decrease (the pattern-matched text is still physically
  present in the file, just inside a renamed, non-exported binding used only
  for harvesting) — verified counts unchanged (1 and 3 respectively) and
  confirmed the existing guardrail test still passes without edits.
  **Found and documented (not fixed) another instance of the defunct-
  `des_obj_priv_int$dead`-field bug** (same category as the Follow-Ups entry
  for `InferenceSurvivalKKLWACoxPHOneLik`'s native segfault, which a
  concurrent effort in this same stretch root-caused and fixed for that one
  class): this class's `compute_treatment_estimate_during_randomization_
  inference()` reassigns `private$dead = private$des_obj_priv_int$dead`,
  which post the y/y_L/y_R migration no longer exists and reads back
  `NULL` — here it doesn't segfault, but produces a genuine R error
  ("Clayton copula fit inputs must have matching row counts") from every
  randomization-family method (`randomization_distr`/`_ci`/`_pval`/
  `_bootstrap_distr`/`_bootstrap_pval`) on the standard golden design,
  reproduced identically on the from-scratch
  `InferenceSurvivalKKClaytonCopulaOneLikLegacyRaw` class (confirming not a
  migration regression). The already-migrated IVWC sibling has the
  textually identical reassignment but its own golden's design/label
  sequence doesn't trigger this specific crash path — not investigated
  further (same "never touch shared randomization infrastructure without
  explicit permission" scoping as the LWA Cox entry). Golden
  `test-survival-kk-clayton-copula-onelik-migration-golden.R` handles this
  with a dedicated comparison branch for the five randomization-family
  labels (asserting both sides fail with the identical error message,
  rather than the generic pass/fail-status comparison every other label
  uses) instead of silently skipping them: all green. Static tables
  updated: registry direct-components mapping (`infer_inference_direct_
  components()`, was still the single stale `"SurvivalKKClaytonCopulaOneLik"`
  entry from before this migration). `test-full-likelihood-migration-
  baseline.R`'s survival-components test, `test-mixin-contracts.R`
  (component was already in the canonical list), `helper-likelihood-method-
  smoke.R` (class was already present), and `test-parametric-bootstrap-lr-
  all-capable-classes.R` (already listed) needed no changes. Full
  regression battery green.
  **Progress 2026-08-19: `InferenceSurvivalKKWeibullFrailtyOneLik`
  migrated** — same structural shape as the Clayton Copula OneLik migration
  above (pre-existing self-harvested components, raw R6 generators kept
  alive under renamed non-exported bindings purely for harvesting), but a
  genuine **two-layer chain** (abstract `InferenceAbstractKKWeibullFrailtyOneLik`
  raw-splicing `InferenceMixinKKPassThrough$public/private` onto
  `InferenceParamBootstrap`, plus a thin concrete leaf using TRUE R6
  inheritance onto the abstract, overriding only `initialize`) rather than
  Clayton's single layer — both raw generators renamed to
  `...LegacyRaw`. Two `super$compute_asymp_confidence_interval`/
  `super$compute_asymp_two_sided_pval` fallback calls in the abstract (same
  "wald" fast-path/fallback-for-others shape as
  `InferenceIncidKKCondLogitOneLik`) rewritten to `self$..._generic()`
  aliases bound from `InferenceAsympLik$public_methods$...`. **New wrinkle
  not seen in the Clayton migration**: the leaf's own `initialize`
  (`self$set_optimization_alg(optimization_alg); super$initialize(...)`)
  cannot reach the abstract component's own initialize via `super$` under a
  flat composition (Lesson 1 corollary — first hit as a genuine bug, not
  just a theoretical concern, via a real "unused argument (use_rcpp =
  use_rcpp)" load-time-adjacent runtime error on first `$new()`); solved by
  ordering `SurvivalKKWeibullFrailtyOneLikLeaf` BEFORE
  `SurvivalKKWeibullFrailtyOneLik` in the factory's `components =` vector
  so the abstract's fuller initialize (which already calls
  `set_optimization_alg()` itself with `allow_irls = FALSE`, making the
  leaf's own pre-call redundant either way) resolves last and wins the
  collision — no free-function-helper needed here since there's only one
  concrete leaf, unlike the quantile-regr OneLik pair. Golden
  `test-survival-kk-weibull-frailty-onelik-migration-golden.R` (legacy
  generator is just the renamed raw leaf class directly, no re-splicing
  needed): all green on the first run, no dropped labels, no crash
  workaround needed. **Also confirmed a second instance of the defunct-
  `des_obj_priv_int$dead`-field bug** (documented in the Follow-Ups entry
  extended below): this class's `compute_treatment_estimate_during_
  randomization_inference()` has the identical `private$dead =
  private$des_obj_priv_int$dead` reassignment, but here it manifests as a
  silent `NA` (not a crash) from `compute_rand_two_sided_pval()`, verified
  identical on both the from-scratch legacy raw class and the migrated
  class on the standard golden design — no special golden-test handling
  needed since both sides already agree. Static tables updated: registry
  direct-components mapping (was still the stale single-component
  `"SurvivalKKWeibullFrailtyOneLikLeaf"` entry); the `SurvivalKKWeibullFrailtyOneLik`
  component's `provides_public_methods` (added the two new generic
  aliases). `test-full-likelihood-migration-baseline.R`, `test-mixin-
  contracts.R`, and `test-static-cleanup-guardrails.R` needed no changes
  (same reasoning as Clayton: components/canonical names were already
  present, and the guardrail pattern-matched text is still physically
  present in the file inside the renamed non-exported bindings). Added an
  `InferenceSurvivalKKWeibullFrailtyOneLik` entry to `helper-likelihood-
  method-smoke.R`'s `should_run("survival")` block (this one was NOT
  already present, unlike Clayton), reusing `make_kk_survival_design()`.
  `test-parametric-bootstrap-lr-all-capable-classes.R` already listed this
  class as a target. Full regression battery green.
  **This completes every unblocked OneLik sibling.** The only remaining
  `*OneLik*` class still R6-inheriting `InferenceParamBootstrap`/
  `InferenceKKPassThroughCompound(NoParamBootstrap)` is
  `InferenceIncidKKCondLogitGLMMOneLik`, blocked on GLMM host contracts per
  the "Migrate KK GEE and GLMM classes" item below.
  (`InferenceContinKKRobustRegrOneLik` migrated in the "Quasi And Robust
  Estimators" section above — tracked there, not in this list.)
- [x] Verify partial-likelihood classes do not gain
  `parametric_likelihood_bootstrap` unless they provide a null simulator.
- Note (2026-08-14): `InferenceSurvivalCoxPHRegr`'s migration to
  `components = "CoxPartialLikelihood"` above left its randomization/
  bootstrap/Bayesian-bootstrap surface entirely absent
  (`compute_rand_two_sided_pval` et al. literally `NULL`) -- fixed by
  composing `components = c("BayesianBootstrap", "CoxPartialLikelihood")`
  (order load-bearing: `BayesianBootstrap` must resolve first so
  `CoxPartialLikelihood`'s `StandardModelCache`-provided
  `compute_treatment_estimate_during_randomization_inference()` wins the
  collision against the generic `RandomizationTest` version). Full
  investigation, a reverted first attempt, and golden-test verification are
  in `interval_censored_survival_response.md`'s TODO-13, tracked there as
  the primary record per this document's own cross-referencing convention.

#### Full-Likelihood Estimators

- [x] Identify all `likelihood_tier = "full"` concrete classes and split them by
  GLM, count, ordinal, incidence, proportion, survival, and KK/IVWC families.
- [x] Extract GLM-family standard-model-cache behavior that is currently shared
  through `InferenceAsympLikStdModCache`.
- [x] Extract count likelihood family behavior that is currently shared through
  `InferenceCountLikelihood`, `InferenceCountLikelihoodNoParamBootstrap`, and
  `InferenceCountCompositeLikelihood`.
- [x] Extract zero-augmented count behavior from
  `InferenceCountZeroAugmentedPoissonAbstract`.
- [x] Extract ordinal likelihood behavior for proportional odds, adjacent
  category, cloglog, cauchit, stereotype, continuation-ratio, and ordered probit
  paths.
- [x] Extract incidence likelihood behavior for logit, probit, log-binomial,
  modified Poisson, binomial identity, and g-computation paths.
- [x] Extract survival likelihood behavior for Weibull, dependent-censoring
  transform, Clayton copula, and frailty paths.
- [x] Migrate full-likelihood classes to `Inference` plus
  `LikelihoodTests`, `StandardModelCache`, `ParametricLikelihoodBootstrap` when
  warranted, and family-specific components. Re-audited 2026-08-17:
  `InferenceOrdinalCauchitRegr` and `InferenceOrdinalCloglogRegr` are migrated via
  `define_inference_class(inherit = Inference, ...)`. The earlier note here
  also named `InferenceOrdinalPropOddsRegr` and
  `InferenceOrdinalAdjCatLogitRegr`, but their current factory definitions
  still inherit `InferenceParamBootstrap`; their direct-to-`Inference`
  migrations therefore remain pending along with the other full-likelihood
  families (GLM, count, remaining ordinal links, incidence, proportion,
  survival, KK/IVWC).
  **Completed 2026-08-18 for the ordinal family** (see the two dedicated
  entries below for `InferenceOrdinalPropOddsRegr`/
  `InferenceOrdinalAdjCatLogitRegr`); the GLM, count, incidence, proportion,
  and non-ordinal survival full-likelihood families were already migrated in
  earlier sessions and confirmed via the manifest audit below (checking this
  item off reflects the ordinal family's completion, matching how the
  Cauchit/Cloglog entries above were checked off individually). The KK/IVWC
  full-likelihood family (the survival IVWC classes carrying
  `likelihood_tier = "full"` metadata for baseline consistency —
  `InferenceSurvivalKKClaytonCopulaIVWC`, `InferenceSurvivalKKWeibullFrailtyIVWC`,
  `InferenceSurvivalKKWeibullMarginal` — plus `InferenceContinKKOLSIVWC`/
  `InferenceCountKKHurdlePoissonIVWC`) is already migrated to `Inference` as
  of the "KK And IVWC Estimators" work earlier this stretch, even though
  most of those classes don't actually expose real score/gradient/LR test
  methods (no `LikelihoodTests` composed) — verified via
  `EDI:::full_likelihood_behavior_manifest()`: 9/46 full-likelihood-tier
  classes currently show `current_parent == "Inference"`, and every one of
  them is accounted for by either this session's KK/IVWC work or the two
  ordinal classes below. The remaining 37 (KK one-likelihood/OneLik
  siblings, count/incidence/proportion families not yet touched) are tracked
  under "KK And IVWC Estimators"'s "Migrate KK one-likelihood classes" item
  and the still-pending non-KK families noted there.
- [x] Migrate `InferenceOrdinalCauchitRegr` as a non-KK full-likelihood class.
  **Completed 2026-08-17:** the concrete class now inherits directly from
  `Inference` and composes `BayesianBootstrap`,
  `ParametricLikelihoodBootstrap`, and `OrdinalCauchitLikelihood`; its registry
  target, full-likelihood migration baseline, and dedicated legacy-vs-shallow
  golden coverage were updated together. The golden coverage exercises
  deterministic likelihood/Wald/score/LR/gradient behavior plus seeded
  nonparametric, randomization, Bayesian, and parametric-likelihood bootstrap
  paths, and asserts the shallow migration gate and exact effective component
  set. All edited R files parse and `git diff --check` is clean.
  **Stale-note correction (2026-08-18 audit):** the original entry claimed
  runtime execution "remains deferred because loading this source tree
  currently requires rebuilding drifted native exports" — no longer true;
  the package has loaded and run cleanly via `pkgload::load_all(".", compile
  = FALSE)` throughout the entire 2026-08-17/18 KK/IVWC migration stretch.
  The 2026-08-17-authored golden's own expected `get_effective_components()`
  list was actually stale in a different, real way (missing
  `RandomizationBootstrapCI`, added to the base resolved chain sometime
  after that golden was written) — found and fixed during the same audit;
  see `test-ordinal-cauchit-migration-golden.R`.
- [x] Migrate `InferenceOrdinalCloglogRegr` as a non-KK full-likelihood class.
  **Completed 2026-08-17:** the concrete class now inherits directly from
  `Inference` and composes `BayesianBootstrap`,
  `ParametricLikelihoodBootstrap`, and `OrdinalCloglogLikelihood`; its registry
  target, full-likelihood migration baseline, and dedicated legacy-vs-shallow
  golden coverage were updated together. The golden coverage exercises
  deterministic likelihood/Wald/score/LR/gradient behavior plus seeded
  nonparametric, randomization, Bayesian, and parametric-likelihood bootstrap
  paths, and asserts the shallow migration gate and exact effective component
  set. All edited R files parse and `git diff --check` is clean.
  **Stale-note correction (2026-08-18 audit):** same as
  `InferenceOrdinalCauchitRegr`'s entry above — the "deferred, needs
  rebuild" claim is outdated, and the golden's expected
  `get_effective_components()` list was missing the same later-added
  `RandomizationBootstrapCI`; fixed in
  `test-ordinal-cloglog-migration-golden.R`.
- [x] **`InferenceOrdinalPropOddsRegr` / `InferenceOrdinalAdjCatLogitRegr`**.
  Completed 2026-08-18: both classes were already `define_inference_class()`
  calls from an earlier partial migration pass, but in a hybrid state —
  `inherit = InferenceParamBootstrap` while separately composing only their
  own likelihood component (`OrdinalProportionalOddsLikelihood` /
  `OrdinalAdjacentCategoryLikelihood`), meaning `BayesianBootstrap` and
  `ParametricLikelihoodBootstrap` were still arriving via R6 inheritance
  rather than composition. Fixed by changing `inherit = Inference` and
  expanding `components =` to
  `c("BayesianBootstrap", "ParametricLikelihoodBootstrap", <family
  component>)` for both classes. Both classes' `overrides` lists were
  already comprehensive from that earlier pass, so this surfaced zero new
  collision errors on load. Two stale-table bugs were found and fixed along
  the way: (1) `inference_class_registry.R`'s static
  `infer_inference_direct_components()` mapping table still listed only the
  single old family component for each class, independent of the real
  `components =` argument, causing `get_effective_components()` to return
  only 5 entries and `parametric_likelihood_bootstrap` to be missing from
  `get_effective_capabilities()` — fixed by updating both entries to the
  full 3-element vector, mirroring the pre-existing
  `InferenceOrdinalCloglogRegr` entry. (2)
  `test-full-likelihood-migration-baseline.R`'s own shared expected-components
  table (used by a loop covering all four ordinal classes at once) was
  missing `RandomizationBootstrapCI` — the same staleness already fixed
  individually for the dedicated Cauchit/Cloglog goldens above, but this
  time in a separate shared file, so the single fix resolved "12 not 11"
  failures for all four classes simultaneously. Created
  `test-ordinal-prop-odds-migration-golden.R` and
  `test-ordinal-adj-cat-logit-migration-golden.R`, mirroring
  `test-ordinal-cauchit-migration-golden.R`'s exact structure (self-harvested
  legacy fixture on the real `InferenceAsympLikStdModCache` ancestor,
  deterministic-likelihood-output golden, seeded-resampling golden,
  no-new-private-owner-duplicates check, shallow-migration-gate check); both
  passed green on the first run. Added
  `InferenceOrdinalAdjCatLogitRegr` to `helper-likelihood-method-smoke.R`
  (`InferenceOrdinalPropOddsRegr` was already present); confirmed both
  present in `test-parametric-bootstrap-lr-all-capable-classes.R`. Full
  regression battery run and green:
  `test-full-likelihood-migration-baseline.R`,
  `test-ordinal-prop-odds-migration-golden.R`,
  `test-ordinal-adj-cat-logit-migration-golden.R`,
  `test-ordinal-cauchit-migration-golden.R`,
  `test-ordinal-cloglog-migration-golden.R`, `test-likelihood-method-smoke.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`,
  `test-mixin-contracts.R`, `test-inference-class-registry.R`,
  `test-static-cleanup-guardrails.R`. Per
  `EDI:::full_likelihood_behavior_manifest()`, 9/46 full-likelihood-tier
  classes now show `current_parent == "Inference"`; the remaining ~37 (GLM,
  count, incidence, proportion, non-migrated survival, and KK one-likelihood
  families) are tracked separately under "KK And IVWC Estimators" and are
  not yet migrated.
- [x] Verify every migrated full-likelihood class has finite smoke tests for
  supported likelihood, bootstrap, and Bartlett paths. Confirmed 2026-08-18:
  all currently-migrated classes with genuine likelihood-test surface
  (`LikelihoodTests` composed) — `InferenceOrdinalPropOddsRegr`,
  `InferenceOrdinalAdjCatLogitRegr`, `InferenceOrdinalCauchitRegr`,
  `InferenceOrdinalCloglogRegr` — have finite smoke coverage in both
  `helper-likelihood-method-smoke.R` (`run_likelihood_method_smoke_suite()`,
  exercised via `test-likelihood-method-smoke.R`) and
  `test-parametric-bootstrap-lr-all-capable-classes.R`. The other 5
  migrated-to-`Inference` classes (`InferenceContinKKOLSIVWC`,
  `InferenceCountKKHurdlePoissonIVWC`, `InferenceSurvivalKKClaytonCopulaIVWC`,
  `InferenceSurvivalKKWeibullFrailtyIVWC`,
  `InferenceSurvivalKKWeibullMarginal`) deliberately do not compose
  `LikelihoodTests` and have no real score/gradient/LR-test surface to
  smoke-test; they are already verified via their own dedicated
  migration-golden files' dropped-labels pattern from earlier this session,
  so adding them to the smoke suite would only produce vacuous
  "method not exposed, skip" results with no new verification value. The 37
  remaining unmigrated full-likelihood classes are out of scope for this
  check until they are migrated.

#### KK And IVWC Estimators

- [x] Finish declaring every `KKPassThrough`, `KKCompound`, `KKGEE`, and
  `KKGLMM` host requirement as required, optional, owned, or forbidden.
  **Completed 2026-08-19.** Used the existing (previously unused for these
  four components) `complete_component_reference_contract()`/
  `component_body_references()` machinery — set
  `EDI_VALIDATE_INFERENCE_CONTRACTS=true` and scanned each component's real
  source body for `private$`/`self$`/`super$` references not already
  covered by `requires_state`/`requires_private_methods`/
  `requires_public_methods`/`optional_private_methods`/
  `optional_public_methods`/`requires_super_methods`/`forbidden_refs`.
  **Findings:** `KKPassThrough` and `KKCompound` (both eager) were already
  fully complete — zero undeclared references; added
  `declare_body_references_optional = TRUE` to both so this becomes a
  standing guarantee (checked whenever `EDI_VALIDATE_INFERENCE_CONTRACTS=true`
  is set) rather than a one-time audit. `KKGLMM` is `load_policy = "lazy"`,
  which makes the automatic scan vacuous (its `public`/`private` are left
  empty at registration time for lazy components, so
  `declare_body_references_optional = TRUE` would silently check nothing) —
  verified complete instead by manually harvesting its real source
  (`InferenceMixinKKGLMMShared`) and running the same two functions against
  it directly: also zero undeclared references. **`KKGEE` had real gaps**:
  15 missing private references and 1 missing public reference, all from
  its `compute_rand_two_sided_pval()` method reading randomization-test
  infrastructure (`assert_design_supports_randomization_draw`,
  `should_use_zhang_incidence_randomization`, `generate_permutations`,
  `compute_two_sided_pval_with_sequential_mc`, and 9 others — full list in
  the source comment at `contracts_mixins.R`'s `KKGEE` spec) that arrives
  via the always-composed `RandomizationTest`/`RandomizationCI` base chain
  (confirmed transitively reachable through KKGEE's own
  `dependencies = c("BayesianBootstrap", "Wald")`) but was never declared.
  Classified as `requires_private_methods`/`requires_public_methods` (not
  `optional`), since `compute_rand_two_sided_pval()` calls them
  unconditionally rather than behind an `is.function()`/similar guard —
  matching the true contract rather than the auto-complete's default
  "treat everything undeclared as optional" fallback. **One genuine wrinkle
  discovered along the way**: two of the fifteen references
  (`custom_randomization_statistic_function`, `randomization_mc_control`,
  both nominally owned by `RandomizationTest`) broke `define_inference_class()`'s
  own static validation when added to `requires_state` (`InferenceCountPoissonKKGEE
  is missing private state required by KKGEE`), even though `RandomizationTest`
  is genuinely resolved into that class's effective component chain.
  Root cause: `custom_randomization_statistic_function` is never a static
  private-list entry at all — `InferenceRand` only ever *creates* it
  dynamically via `private[["custom_randomization_statistic_function"]] = ...`
  inside `set_custom_randomization_statistic_function()`, so it doesn't
  exist as a literal name for the static validator to find until that
  setter has actually been called once, regardless of composition (KKGEE's
  own body only ever reads it defensively via `is.null(private$x)`, which
  is always safe). Left this one pair of references as an accepted,
  documented gap (not force-declared in `requires_state`) rather than
  chasing a static-validator limitation that's out of scope for this item;
  `des_obj_priv_int` (the third originally-flagged state reference, a real
  static root `Inference` field) was added to `requires_state` without
  issue. Verified via full package load with
  `EDI_VALIDATE_INFERENCE_CONTRACTS=true` (previously never exercised for
  these four components) plus the normal battery
  (`test-mixin-contracts.R`, `test-static-cleanup-guardrails.R`,
  `test-inference-class-registry.R`, `test-gee-warm-start.R`, `test-kk-gee-
  fallback.R`, `test-kk-gee-parity.R`, `test-likelihood-method-smoke.R`,
  `test-parametric-bootstrap-lr-all-capable-classes.R`, `test-quasi-robust-
  migration-baseline.R`) — all green, no behavior change (this item is pure
  static-contract documentation; no method bodies were touched).
- [x] Remove all direct `InferenceMixinKKPassThrough$public` and
  `InferenceMixinKKPassThrough$private` splices from concrete classes.
  **Verified done 2026-08-19** (stale duplicate of the Static Cleanup "Ban
  raw component splicing" effort, never synced here): `grep -rn
  "InferenceMixinKKPassThrough\$public\|InferenceMixinKKPassThrough\$private"
  R/*.R` returns zero matches outside `inference_mixin_kk_passthrough.R`
  itself. The one remaining `InferenceMixinKKPassThrough[["public"]]`/
  `[["private"]]` bracket-notation usage (`inference_all_KK_wilcox_ivwc.R`)
  assembles the `KKWilcoxIVWCSource` harvesting-source object, not a splice
  into a concrete class -- the same accepted pattern as every other
  `*Source` object in the codebase (`CountCompositeLikelihoodSource`,
  `KKQuantileRegrIVWCSource`, etc.).
- [x] Replace every `eval(body(InferenceMixinKKPassThrough$...))` usage with a
  named component override or helper. **Verified done 2026-08-19** (stale
  duplicate of the same Static Cleanup item, "Ban `eval(body(Inference...))`",
  completed 2026-08-19 above): `grep -rn "eval\s*\(\s*body\s*\(\s*
  InferenceMixinKKPassThrough" R/*.R` returns only comment lines (7 matches,
  all `#`-prefixed); zero live code occurrences.
- [ ] Migrate KK IVWC classes to `Inference` plus `KKPassThrough`,
  `KKCompound`, and estimator-specific components.
  **Progress 2026-08-17: `InferenceIncidKKNewcombeRiskDiff` migrated** —
  first KK/IVWC leaf moved by this effort, establishing the working recipe
  from the already-migrated `InferenceAllKKMeanDiffIVWC` template:
  estimator body harvested verbatim into `KKNewcombeRiskDiffIVWCSource`;
  new registered component `KKNewcombeRiskDiffIVWC`
  (`dependencies = "KKCompound"`, tier "none", added to
  `contracts_mixins.R` and to `test-mixin-contracts.R`'s canonical-name
  list); class rebuilt as `define_inference_class(inherit = Inference,
  components = c("BayesianBootstrap", "Wald", "KKNewcombeRiskDiffIVWC"))`
  with the registry direct-components mapping added. Three lessons for the
  remaining KK leaves, all caught by validation/goldens: (1) the Source's
  `initialize` must call `private$init_kk_passthrough(des_obj)` explicitly
  after `super$initialize()` — post-migration `super$` is root `Inference`,
  so the KK match-structure setup (`private$m`, initial match data) the old
  ladder parent ran no longer happens implicitly (symptom: Rcpp "type=NULL;
  target=integer" from `compute_zhang_match_data_cpp` on every SE-touching
  path); (2) two KK-chain-vs-bootstrap-chain public collisions
  (`approximate_bootstrap_distribution_beta_hat_T`,
  `compute_estimate_with_bootstrap_weights`) must be declared, KK-aware
  versions winning via component order; (3) for **incidence** KK classes,
  pin `compute_rand_two_sided_pval` from `InferenceRandCI` (not
  `InferenceRand` as the continuous template does) to preserve the Zhang
  randomization dispatch — same decision as `InferenceIncidRiskDiff`.
  Golden-tested in `test-incid-kk-newcombe-migration-golden.R` (legacy
  byte-copy vs migrated on a `DesignSeqOneByOneKK14` fixture, per-call
  seeded; the legacy score/gradient/LR CIs were verified bit-identical Wald
  fallbacks and their p-values NA before asserting the drop — same
  verified pattern as `InferenceIncidRiskDiff`). Full battery green:
  registry, mixin-contracts, partial-likelihood baseline, both simple
  goldens. In the same change, the **stale Cox registry mappings were
  trued up**: both `InferenceSurvivalCoxPHRegr` and
  `InferenceSurvivalStratCoxPHRegr` factory calls compose
  `c("BayesianBootstrap", <cox component>)`, but the registry
  direct-components switch and the partial-likelihood static targets still
  said only the Cox component — fixed in
  `infer_inference_direct_components()`, the partial-likelihood targets
  table, and `test-partial-likelihood-migration-baseline.R`'s two
  expectation tables (now carrying the full resolved 11/12-component
  chains).
  Named target (added
  2026-08-12): `InferenceCountKKHurdlePoissonIVWC`
  (`inference_count_KK_cond_poisson.R`) — `none`-tier (Wald-only), needs a
  dedicated `Source` component (matching the `KKMeanDifferenceIVWCSource`
  precedent in `inference_all_KK_mean_diff_IVWC.R`) wrapping its matched-pair
  hurdle-Poisson GLMM + reservoir Poisson IVWC combination logic so
  `approximate_bootstrap_distribution_beta_hat_T` doesn't need
  `super$...`. Its file-sibling `InferenceCountKKHurdlePoissonOneLik`
  (same file) is a separate, harder target — full-likelihood-tier, inherits
  `InferenceParamBootstrap`, belongs under "Migrate KK one-likelihood
  classes" below instead.
  **Done 2026-08-17** — via the static-leaf-source shape established by the
  `InferenceSurvivalKKWeibullMarginal` migration the same day (see its entry
  below): new `CountKKHurdlePoissonIVWCSource` + registered
  `CountKKHurdlePoissonIVWC` component (`dependencies = "KKPassThrough"`,
  lazy), raw mixin splices and the `eval(body(...))` bootstrap override
  removed from the class (`eval(body(` count 13 → 12), factory composition
  `c("BayesianBootstrap", "Wald", "CountKKHurdlePoissonIVWC")` with the
  `InferenceRand` pin. The KKPassThrough contract's loud validation caught a
  needed host `supports_likelihood_tests = FALSE` (previously inherited from
  the `InferenceAsymp` ladder). Golden
  `test-count-kk-hurdle-ivwc-migration-golden.R` all green — after
  surfacing **two systemic findings**: (a) **golden fixtures must reuse the
  REAL classname, not a "...Legacy" suffix** — `globals.R`'s
  `$`-anchored optimizer policy (`"KKHurdlePoissonIVWC$" = "lbfgs"`) and
  `Inference$capabilities()`'s nearest-registered-ancestor walk both key on
  the class name, so a suffixed fixture silently ran a different optimizer
  (~1e-4 numeric drift) or lost `kk_passthrough` capability (flipping the
  randomization-CI transform dispatch); both this golden's and the Weibull
  Marginal golden's fixtures now use the real name (local binding only, no
  registry interference); (b) the **class-identity randomization-CI seed
  bug** (see the dedicated Follow-Ups entry: `is(inf_obj,
  "InferenceAsymp")` gated the Wald/asymp seed candidates, silently
  NA-ing every migrated class's randomization-CI fallback). Also flagged
  (preserved byte-identically, latent pre-existing bug): the class's
  `compute_estimate_with_bootstrap_weights` calls
  `private$shared_combined_bootstrap()`, which is defined **nowhere** in
  the package — the weighted-bootstrap path has always errored at runtime
  and its Bayesian-bootstrap replicates are silently all-NA; needs its own
  fix-or-drop decision.

  **Fixed 2026-08-21** (`InferenceCountKKHurdlePoissonIVWC`,
  `inference_count_KK_cond_poisson.R`): implemented `compute_estimate_with_
  bootstrap_weights` for real rather than dropping it, combining a weighted
  matched-pair fit and a weighted reservoir fit the same inverse-variance
  way as `$compute_estimate()`. The reservoir (ordinary Poisson) leg uses
  the already-existing `fast_poisson_regression_weighted_cpp()` (no new C++
  needed); the matched-pair (hurdle-Poisson GLMM) leg has no weighted Rcpp
  optimizer, so a caller-supplied weights vector routes through `glmmTMB`
  (which natively accepts prior weights) instead of the unweighted-Rcpp-
  then-glmmTMB-fallback path `$compute_estimate()` uses. `fit_hurdle_for_
  matched_pairs()`/`fit_hurdle_for_matched_pairs_glmm_tmb()`/`fit_poisson_
  for_reservoir()` gained an optional `weights = NULL` parameter (default
  preserves the old unweighted call sites byte-for-byte). Verified: the
  Bayesian-bootstrap path, previously an unconditional error, now returns
  a real p-value end-to-end; `test-count-kk-hurdle-ivwc-migration-golden.R`
  and `test-full-likelihood-migration-baseline.R` green. Second named
  target (added 2026-08-12):
  `InferenceSurvivalKKWeibullMarginal`
  (`inference_survival_KK_weibull_marginal.R`) — `none`-tier (Wald-only,
  cluster-robust sandwich SE, explicitly not a true likelihood per its own
  `supports_likelihood_tests() FALSE`), same `eval(body(...))`/splice pattern
  and same fix shape: needs a dedicated `SurvivalKKWeibullMarginalSource`
  component wrapping the pooled Weibull AFT fit + `get_cluster_ids()` +
  matched-pair/reservoir cluster-robust sandwich logic, plus the
  `super$`-avoidance fix for `approximate_bootstrap_distribution_beta_hat_T`.
  **Done 2026-08-17** — with a cleaner shape than the note above envisioned:
  instead of one component wrapping the merged mixin+leaf surface, the
  pre-existing self-harvested `SurvivalKKWeibullMarginal` component was
  reshaped into a **static leaf-only source** with
  `dependencies = "KKPassThrough"` — the mixin content now arrives through
  the registered `KKPassThrough` component, the raw
  `modifyList(InferenceMixinKKPassThrough$public/$private, ...)` splices are
  gone from the class file, and the `eval(body(...))` bootstrap override is
  deleted outright (the KKPassThrough component supplies the real function;
  package-wide `eval(body(` count 14 → 13). The class is now
  `define_inference_class(inherit = Inference, components =
  c("BayesianBootstrap", "Wald", "SurvivalKKWeibullMarginal"))`; component
  resolution order (KKPassThrough after the bootstrap/Wald chains, leaf
  last) reproduces the old modifyList precedence exactly.
  `compute_rand_two_sided_pval` is pinned from `InferenceRand` per the
  plain-Cox survival precedent (RandCI's flattened `super$` trap — hit live
  by the golden test before pinning). Component spec, registry
  direct-components mapping (`c("BayesianBootstrap", "Wald",
  "SurvivalKKWeibullMarginal")`), and collision declarations all updated;
  tier left "full" to match the frozen component/baseline tier (the tier
  itself is arguably "quasi" per the note above — a separate relabeling
  question, same family as the `m_estimator_variance` relabel). Golden
  test `test-survival-kk-weibull-marginal-migration-golden.R`: legacy
  splice-reproducing generator vs migrated, per-call seeded, bit-identical
  everywhere, plus a source-scan asserting the splice and evaluated-body
  patterns stay gone. Full battery green (registry, mixin-contracts,
  partial-likelihood baseline, both simple goldens); the full-likelihood
  baseline's only failures remain the two reverted ordinal classes
  (pre-existing, tracked separately).
  **Also migrated 2026-08-17 (unnamed, found via the same audit):
  `InferenceSurvivalKKClaytonCopulaIVWC`** — plain leaf on
  `InferenceKKPassThroughCompoundNoParamBootstrap` (not a raw-splice class
  like the two named targets, but the same `eval(body(...))` bootstrap
  override and a pure-passthrough `duplicate()` override). Same static-leaf
  shape: `SurvivalKKClaytonCopulaIVWCSource` narrowed to leaf-only
  (`dependencies = "KKCompound"`), factory composition
  `c("BayesianBootstrap", "Wald", "SurvivalKKClaytonCopulaIVWC")` with the
  `InferenceRand` pin, `eval(body(` count 12 → 11. Golden
  `test-survival-kk-clayton-ivwc-migration-golden.R`: legacy generator uses
  the real classname (not `...Legacy`) per the naming lesson below;
  score/gradient/LR CI/p-value drop verified Wald-fallback-or-NA before
  asserting (same pattern as `InferenceIncidRiskDiff`). All green.
- [x] **Progress 2026-08-18: `InferenceContinKKRobustRegrIVWC` migrated** —
  plain leaf on `InferenceKKPassThroughCompoundNoParamBootstrap` (quasi
  tier, no `eval(body(...))` override — it simply inherited the mixin's
  `approximate_bootstrap_distribution_beta_hat_T`/
  `compute_estimate_with_bootstrap_weights` unmodified). Same static-leaf
  shape as the four prior KK leaves this stretch:
  `ContinKKRobustRegrIVWCSource` (`dependencies = "KKCompound"`), factory
  composition `c("BayesianBootstrap", "Wald", "ContinKKRobustRegrIVWC")` with
  the `InferenceRand` pin, `overrides` declaring the standard chain-vs-chain
  public/private collisions. Hit Lesson 1 again (recurrence, not a new
  lesson): the Source's `initialize` only called `super$initialize()`, which
  post-migration resolves to root `Inference` and skips the KK
  match-structure setup the old compound ladder's `initialize` performed —
  symptom was estimate 0.526 vs legacy 1.02 and all downstream CI/pval
  wrong by the same margin; fixed by adding an explicit
  `private$init_kk_passthrough(des_obj)` call after `super$initialize()`,
  mirroring the `KKNewcombeRiskDiffIVWCSource` fix. One golden-test-only
  wrinkle: `score_ci` is a real (non-degenerate) legacy value that is
  *numerically* but not *bit-identical* to the Wald CI (differs ~1e-6:
  0.7157783/1.3328011 vs Wald 0.7157792/1.3328002), because
  `compute_score_confidence_interval()` bypasses the
  `supports_likelihood_tests() == FALSE` / `get_likelihood_test_spec() ==
  NULL` gate and calls `invert_test_pval_confidence_interval()` directly,
  which numerically root-finds (`uniroot`) around the Wald estimate rather
  than returning it in closed form; the golden's Wald-fallback tolerance was
  widened from `1e-10` to `1e-4` for this one label with a comment
  explaining why (not a real likelihood-test-surface drop). Golden
  `test-contin-kk-robust-regr-ivwc-migration-golden.R`: legacy generator
  uses the real classname (not `...Legacy`) per the naming lesson below. All
  green; `ContinKKRobustRegrIVWC` added to `test-mixin-contracts.R`'s
  canonical component list. `eval(body(` count unaffected by this one (this
  class never had an override); no change to that counter here.
- [x] **Progress 2026-08-18: `InferenceContinKKOLSIVWC` migrated** — plain
  leaf on `InferenceKKPassThroughCompoundNoParamBootstrap`, structurally the
  simplest KK leaf so far: it never defined `compute_estimate`,
  `compute_asymp_confidence_interval`, `compute_asymp_two_sided_pval`, or
  `duplicate()` at all -- it inherited the generic `private$shared()`-based
  versions from `InferenceMLEorKMSummaryTable`
  (`inference_all_abstract_mle_or_KM_summary_table.R`) through the old
  ladder. Since that ancestor is not part of the composed chain
  post-migration, those three generic methods were hand-copied verbatim
  into `ContinKKOLSIVWCSource$public` (no `duplicate()` override needed --
  it never had one, so root `Inference`'s default suffices). Same static-leaf
  shape as the other five KK leaves this week:
  `dependencies = "KKCompound"`, factory composition
  `c("BayesianBootstrap", "Wald", "ContinKKOLSIVWC")` with the `InferenceRand`
  pin, and the same Lesson-1 `private$init_kk_passthrough(des_obj)` call
  added to `initialize` (this time added proactively before running the
  golden, rather than discovered via a failure). All standard chain-vs-chain
  overrides declared (jackknife/worker trios,
  `get_supported_testing_types_impl`,
  `compute_treatment_estimate_during_randomization_inference`,
  `compute_basic_match_data`, `compute_fast_randomization_distr`, `shared`,
  `assert_finite_se`, plus the KKCompound-wins pair
  `approximate_bootstrap_distribution_beta_hat_T`/
  `compute_estimate_with_bootstrap_weights`). Golden
  `test-contin-kk-ols-ivwc-migration-golden.R` (real classname, same
  dropped-labels/Wald-fallback pattern with the same widened `1e-4`
  tolerance for `score_ci`/`score_pval` as `ContinKKRobustRegrIVWC`): all
  green on the first run.
  One pre-existing structural test needed updating for the new architecture,
  not a behavior fix: `test-mixin-contracts.R`'s "KK OLS IVWC uses the
  compound bootstrap-weight estimator" asserted
  `InferenceContinKKOLSIVWC$public_methods$compute_estimate_with_bootstrap_weights`
  was `NULL` (true pre-migration, since the method was only reachable via
  the R6 ladder) and differed from `InferenceMixinKKPassThrough`'s raw
  passthrough (true pre-migration: the compound ladder had its own ad hoc
  override, built inline in `inference_all_abstract_KK_passthrough_compound.R`
  and never registered as a reusable component). Post-migration this
  resolves to a real flattened function equal to `InferenceMixinKKPassThrough`'s
  passthrough, not the old ad hoc compound version -- verified this is not a
  regression: neither `InferenceContinKKOLSIVWC` nor
  `InferenceContinKKRobustRegrIVWC` ever defines
  `private$compute_weighted_estimate_ivwc`, so the legacy compound override's
  body always fell through to its own generic "weighted matched-diff mean"
  fallback branch, which is mathematically the same surrogate
  `InferenceMixinKKPassThrough`'s passthrough computes; confirmed
  bit-identical by both classes' `bootstrap_ci`/`bootstrap_pval`/
  `bootstrap_distr` golden labels (`InferenceAsymp`'s
  `supports_reusable_bootstrap_worker()` default is `TRUE` and neither class
  overrides it, so this method is genuinely exercised, not dead code). Test
  rewritten to assert the new-architecture invariant instead of the
  old-ladder one, with the reasoning above inlined as a comment.
  `ContinKKOLSIVWC` added to `test-mixin-contracts.R`'s canonical component
  list.
- [x] **Progress 2026-08-18: `InferenceSurvivalKKRankRegrIVWC` migrated** —
  first of the abstract-base group. Pre-migration it was a two-layer ladder:
  abstract `InferenceAbstractKKSurvivalRankRegrIVWC` (all estimator
  machinery, on `InferenceKKPassThroughCompoundNoParamBootstrap`) + a thin
  concrete leaf (delegating `initialize` and a `build_design_matrix` helper
  that nothing in the chain calls — preserved as dead surface anyway). Both
  layers merged into static `SurvivalKKRankRegrIVWCSource` in the *abstract's*
  file (which Collates before the concrete file, where the
  `define_inference_class()` factory now lives); abstract R6 generator
  deleted (grep confirmed the concrete leaf was its only reference
  anywhere). Composition `c("BayesianBootstrap", "Wald",
  "SurvivalKKRankRegrIVWC")` (`dependencies = "KKCompound"`, tier "none"),
  `InferenceRand` pin, standard collision overrides. The merged initialize
  keeps the concrete leaf's narrower public signature (`des_obj,
  model_formula, verbose` — the abstract's `smart_cold_start_default` param
  was never exposed by the leaf, so it is pinned `NULL` inside with a
  comment). Two findings:
  (1) the abstract's `eval(body(InferenceMixinKKPassThrough$public$
  approximate_bootstrap_distribution_beta_hat_T))` override was dropped as a
  **verified no-op**: the compound ladder's inline public list only defines
  `initialize` and `compute_estimate_with_bootstrap_weights`, so the old
  ladder inherited exactly that KKPassThrough body anyway (this also means
  the legacy golden fixture — source spliced onto the compound base without
  the override — is verbatim-faithful). `eval(body(` count 11 → 10.
  (2) **new lesson (Lesson 5, get_standard_error)**: first golden run
  errored on the migrated side with "must implement get_standard_error() to
  support Wald-type inference". The old ladder's `get_standard_error` came
  from `InferenceMLEorKMSummaryTable` (calls `private$shared()` then
  degrades to `NA_real_` when SE is missing); the Wald component's own
  fallback instead `stop()`s on a missing SE. Reachable here because this
  class's `shared()` has an extra early-return on cached `beta_hat_T` (even
  from an `estimate_only` pass that never computed the SE). Fix: copy
  MLEorKM's `get_standard_error` verbatim into the Source private + declare
  the override. Watch for this on every remaining class whose old ladder ran
  through `InferenceMLEorKMSummaryTable` and whose leaf never defined its
  own `get_standard_error`. Golden
  `test-survival-kk-rank-regr-ivwc-migration-golden.R` (real classname,
  `skip_if_not_installed("aftgee")`, dropped-labels pattern, plus an
  eval(body)-gone source check over both files): all green;
  `SurvivalKKRankRegrIVWC` added to the canonical component list. The
  pre-existing `KKSurvivalRankRegression` wrapper component (registered,
  composed by nobody, delegating `kk_survival_rank_*` shims to these same
  privates) was left untouched.
- [x] **Progress 2026-08-18: `InferenceSurvivalKKLWACoxPHIVWC` migrated** —
  second of the abstract-base group, same two-layer shape (abstract
  `InferenceAbstractKKLWACoxIVWC` + thin assertFormula/delegating leaf; the
  `InferenceSurvivalKKLWACoxPHOneLik` sibling in the same concrete file is
  untouched, it belongs to the one-likelihood phase). Key difference from
  rank-regr: instead of minting a new component, the **pre-existing
  shim-only `KKLWACoxIVWCPartialLikelihood` component was reshaped into the
  real merged source** — abstract+leaf machinery merged into
  `KKLWACoxIVWCPartialLikelihoodSource` (its `kk_lwa_cox_*` delegating shims
  preserved at the bottom of the private list), `dependencies` changed
  `"Wald"` → `"KKCompound"`, and provides lists extended. Composition
  `c("BayesianBootstrap", "Wald", "KKLWACoxIVWCPartialLikelihood")`, tier
  "partial", `InferenceRand` pin, standard overrides, Lesson-5
  `get_standard_error` copied in proactively, no-op `eval(body(...))`
  override dropped (count 10 → 9). This class had pre-existing **static
  target expectations** in two places — the registry's partial-likelihood
  static targets table and
  `test-partial-likelihood-migration-baseline.R`'s expected lists (direct
  `c("KKLWACoxIVWCPartialLikelihood", "KKCompound")`, 5-component resolved
  chain, plus component-shape assertions pinning `dependencies = "Wald"`/
  empty publics/shims-only privates and a Wald-in-load-trace check) — all
  updated to the factory reality (direct `c("BayesianBootstrap", "Wald",
  "KKLWACoxIVWCPartialLikelihood")`, full 11-component resolved chain,
  reshaped component contract, KKPassThrough/KKCompound load trace), the
  same treatment the non-KK Cox entries got on 2026-08-17, with comments at
  each site. Golden `test-survival-kk-lwa-cox-ivwc-migration-golden.R`
  (real classname, dropped-labels pattern, eval(body)-gone check): all green
  on the first run; partial-likelihood baseline + registry + mixin-contracts
  + all prior KK goldens green.
- [x] **Progress 2026-08-18: Bai trio migrated (`InferenceBaiAdjustedTKK14`,
  `InferenceBaiAdjustedTKK21`)** — abstract `InferenceBaiAdjustedT` converted
  to the shared registered `BaiAdjustedT` component
  (`BaiAdjustedTSource` in inference_continuous_KK_bai_abstract.R,
  `dependencies = "KKCompound"`, tier "none", owns `convex_flag`); each leaf
  is now a `define_inference_class()` factory composing
  `c("BayesianBootstrap", "Wald", "BaiAdjustedT")` plus its own host-level
  `distance` private (dead code in both leaves — nothing calls
  `private$distance`; pair distances go through
  `compute_pair_distance_matrix_cpp` — preserved verbatim anyway). First
  migration where two concrete classes share one migrated component. Applied
  Lessons 1 (this abstract, unlike rank-regr/LWA, did NOT call
  `init_kk_passthrough` itself — relied on the compound base — so the call
  was added to the Source's initialize) and 5 (`get_standard_error` copied
  in; needed because `compute_estimate` only populates `s_beta_hat_T` on the
  convex branch). Two new wrinkles: (a) new collision kind — undeclared
  private collision `compute_basic_match_data` fired even though the leaf
  source does not define it (KKPassThrough vs KKCompound chain collision
  surfaces at the composing class), declared in both leaves' overrides;
  (b) **intentional drop**: the abstract carried a PRIVATE `duplicate`
  passthrough shadowing the public root method — unreachable
  (`self$duplicate` always resolves public) and rejected by
  `define_inference_class()`'s public/private name-duplication check, so it
  was dropped with comments at the source and in the golden. Golden
  `test-contin-kk-bai-migration-golden.R` (both leaves, real classnames,
  KK14 golden on `DesignSeqOneByOneKK14` + KK21 on `DesignSeqOneByOneKK21`,
  `skip_if_not_installed("nbpMatching")`, plus a convex_flag=TRUE
  estimate/CI/pval comparison): the dropped-labels check needed a third
  degenerate form — legacy `score_ci` comes back as a **zero-width interval
  collapsed onto the point estimate** (1.2768/1.2768 vs Wald 0.826/1.728),
  i.e. the score inversion degenerates with no likelihood surface behind
  it; collapsed-onto-estimate now licenses the drop alongside all-NA and
  Wald-fallback. All green; `BaiAdjustedT` in the canonical component list;
  full battery green.
- [x] **Progress 2026-08-18: `InferenceSurvivalKKStratCoxPHIVWC` migrated**
  — plain leaf (not abstract-based; its file's
  `InferenceSurvivalKKStratCoxPHOneLik` sibling is untouched for the
  one-likelihood phase). Standard recipe: `SurvivalKKStratCoxIVWCSource`
  (`dependencies = "KKCompound"`, tier "partial", keeps the class's own
  `compute_basic_match_data` long-format override and the TODO-16
  `assert_finite_se` stub), composition `c("BayesianBootstrap", "Wald",
  "SurvivalKKStratCoxIVWC")`, `InferenceRand` pin, Lesson-5
  `get_standard_error` added proactively, no-op `eval(body(...))` override
  dropped (count 9 → 8), original initialize signature (including
  `smart_cold_start_default`) preserved since this was a leaf's own public
  API. This class's registry static-targets entry never had
  `target_direct_components` (pre-migration note said contracts were
  needed first), so no target-table updates were required — only the new
  direct-components mapping. Golden
  `test-survival-kk-strat-cox-ivwc-migration-golden.R` (real classname,
  dropped-labels pattern incl. the collapsed-onto-estimate degenerate
  form): all green on the first run; mixin-contracts + registry +
  partial-likelihood baseline green.
- [x] **Progress 2026-08-18: `InferenceSurvivalKKWeibullFrailtyIVWC`
  migrated** — same reshaping as the Clayton copula IVWC migration: the
  abstract `InferenceAbstractKKWeibullFrailtyIVWC` (previously
  self-harvested via `inference_component_source_parts()`) and its thin leaf
  (previously the separate self-harvested `SurvivalKKWeibullFrailtyIVWCLeaf`
  component, now **deleted**) were merged into a static
  `SurvivalKKWeibullFrailtyIVWCSource`; spec `dependencies` → "KKCompound";
  composition `c("BayesianBootstrap", "Wald", "SurvivalKKWeibullFrailtyIVWC")`,
  tier "full", `InferenceRand` pin, Lesson-5 `get_standard_error`, and both
  the no-op `eval(body(...))` bootstrap override and the pure-passthrough
  public `duplicate` dropped (Clayton precedent). Static expectations
  updated: registry class→component map (abstract + Leaf entries replaced
  by the one direct-components triple), mixin-contracts canonical list
  (Leaf name removed), full-likelihood baseline expected components
  (two-component entry → single). The OneLik frailty pair is untouched
  (one-likelihood phase). Golden
  `test-survival-kk-weibull-frailty-ivwc-migration-golden.R`: all green on
  the first run.
  **Also this change surfaced that `test-static-cleanup-guardrails.R` had
  not been in the regression battery all stretch** — its three ratchet
  tables (eval(body(Inference...)) counts, raw-splice counts, is_a-probe
  counts) and the root-owned-state redeclaration list were stale for
  *several* migrations back (WeibullMarginal's owns_state trim, the rand-CI
  seed fix's is_a-probe removal, and every eval(body)/splice drop since).
  All four tables re-pinned to current actuals with dated comments; the
  guardrails file is now part of the battery.
- [x] **Progress 2026-08-18: `InferenceIncidKKCondLogitIVWC` migrated** —
  the last compound-base IVWC leaf of this group. Standard recipe:
  `IncidKKCondLogitIVWCSource` (`dependencies = "KKCompound"`, tier
  "partial"), composition `c("BayesianBootstrap", "Wald",
  "IncidKKCondLogitIVWC")`, **`InferenceRandCI` pin (incidence class —
  Lesson 3)**, Lesson-5 `get_standard_error`, no-op `eval(body(...))`
  override dropped (count 8 → 7). The discovery-era target composition
  (`c("ConditionalLogitPartialLikelihood", "KKCompound")` in both the
  registry static table and the partial-likelihood baseline's expected
  lists) named `ConditionalLogitPartialLikelihood`, but the class's
  estimator privates call the `conditional_logit_fit_*` free functions
  directly and compose no methods from that component — both targets
  updated to the factory reality with comments (LWA Cox treatment). Golden
  `test-incid-kk-cond-logit-ivwc-migration-golden.R`: all green on the
  first run. Guardrail ratchets updated (cond-logit file eval(body) 2 → 1,
  splices 4 → 3). The OneLik sibling (on `InferenceParamBootstrap`) is
  untouched (one-likelihood phase). Note: `test-bayesian-bootstrap.R`'s
  mirai-daemons test errors under the Claude Code sandbox
  (`.dispatcher_start ... Permission denied` — socket creation blocked) but
  passes cleanly outside it; environmental, not a regression.
- [x] **Progress 2026-08-18: `InferenceContinKKQuantileRegrIVWC` /
  `InferencePropKKQuantileRegrIVWC` migrated** — a structurally different
  case from every other KK leaf this stretch: pre-migration this was a
  **three-tier R6 chain** (concrete leaf → `InferenceAbstractKKQuantileRegrIVWC`
  → `InferenceAbstractQuantileRandCI`, the last already a **hybrid**
  `define_inference_class(inherit = InferenceKKPassThroughCompoundNoParamBootstrap,
  components = "QuantileRandomizationCI")` — partially migrated but still
  R6-inheriting the old ladder). The middle abstract was converted to the
  registered `KKQuantileRegrIVWC` component (`dependencies = c("KKCompound",
  "QuantileRandomizationCI")`, `owns_state` includes `m` — the first
  component this stretch to redeclare root-owned `m`, ratcheted into the
  guardrail table). Despite the "KK" name, `init_kk_passthrough`'s
  `is_a_kk_matching_capable()` assertion accepts `DesignFixedBinaryMatch`
  too, so the class genuinely supports two design families — preserved
  as-is, verified only on the kk14 path (matching every other golden this
  stretch).
  **New pattern (two leaves, one component, each with different init
  wrapping logic):** unlike every single-leaf merge this stretch,
  `InferenceContinKKQuantileRegrIVWC` and `InferencePropKKQuantileRegrIVWC`
  both compose `KKQuantileRegrIVWC` but need *different* response-type
  assertions and post-init logic (Prop additionally sanitizes the response
  and rebuilds `KKstats`) wrapped around the *same* tau/transform_y_fn/KK-setup
  machinery — and each leaf's `overrides` declares itself the winner of the
  `initialize` collision, which means the component's own `initialize` is
  otherwise **unreachable** post-flattening (a flat composition has no
  concept of "leaf calls into component via `super$`" the way true R6
  inheritance did). Solved by factoring the shared logic into a plain
  free-function helper, `.init_kk_quantile_regr_ivwc(self, private, super,
  ...)` (same pattern as the pre-existing `.compute_kk_basic_match_data_cached()`
  helper), which each leaf's own `initialize` calls directly — `super$
  initialize()` must be invoked from inside a method actually bound to that
  leaf's construction, since `super` is only resolvable there. Documented as
  a **Lesson 1 corollary**: watch for this whenever multiple concrete
  classes need to share one migrated component AND each needs distinct
  initialize-wrapping logic (the Bai trio avoided this because neither leaf
  had any initialize logic of its own).
  Golden `test-kk-quantile-regr-ivwc-migration-golden.R` needed two new
  pieces of infrastructure: (1) the legacy fixture generator had to
  reconstruct the 3-tier chain (an inline abstract R6 generator built inside
  the `inherit = ` expression itself — R6 evaluates `inherit` lazily in
  `parent_env`/the EDI namespace at `$new()` time, so a locally-defined test
  helper symbol referencing outer closure variables is invisible there;
  only a self-contained expression of namespace-qualified/base symbols
  survives); (2) a **found-and-worked-around pre-existing legacy bug**: this
  class's score/gradient/lik_ratio-test machinery (fallback AsympLik
  dispatch, same degenerate surface as every other dropped-labels case) has
  a demonstrated corrupting side effect on `private$cached_values$beta_hat_T`
  that only manifests several calls later — after the bootstrap-worker
  machinery runs — silently turning `compute_estimate()` (and everything
  downstream, including `compute_rand_confidence_interval()`) into `NA` for
  the *rest of the shared test object's lifetime*. Reproduced identically on
  the **unmigrated legacy class itself**, so this is not a migration
  regression; since the migrated side never exposes these labels at all, the
  corrupting path can never be reached in the new architecture. Fixed at the
  test-harness level: the dropped-label probe call now runs on a throwaway
  `legacy$clone(deep = TRUE)` instead of the shared object, isolating the
  known-corrupting call from the rest of the label sequence. All green.
  `KKQuantileRegrIVWC` added to the canonical component list;
  `test-kk-bootstrap-method-inheritance.R` (found stale, not previously in
  the regression battery, referencing the now-deleted
  `InferenceAbstractKKQuantileRegrIVWC` symbol directly — broken since the
  `InferenceContinKKOLSIVWC` migration two turns ago and never caught)
  updated to the new-architecture invariant and added to the battery.
- [x] **Progress 2026-08-18: `InferenceIncidKKGCompRiskDiff` /
  `InferenceIncidKKGCompRiskRatio` migrated** — a three-tier chain (concrete
  leaf → `InferenceIncidKKGCompAbstract` [gcomp machinery] →
  `InferenceAbstractKKMarginalIncid` [KK cluster helpers, raw-splices
  `InferenceMixinKKPassThrough`, `inherit = InferenceParamBootstrap`]).
  **Both abstract bases were deliberately left untouched as real R6
  generators**: `InferenceAbstractKKMarginalIncid` is also the parent of
  `InferenceAbstractKKModifiedPoisson`/`InferenceIncidKKModifiedPoisson`, a
  separate estimator family not migrated in this change — verified working
  unchanged after the migration. The new `IncidenceKKGComputation` component
  self-harvests `InferenceIncidKKGCompAbstract`'s own body via
  `inference_component_source_parts()` (same self-harvest-without-touching-
  the-abstract pattern the pre-existing non-KK sibling
  `IncidenceGComputationSource` already used), then layers in by hand: a
  fresh `initialize` (Lesson 1: explicit `private$init_kk_passthrough()`),
  `InferenceAbstractKKMarginalIncid`'s `get_cluster_ids`/`get_covariate_names`/
  `compute_basic_match_data`/`supports_likelihood_tests` (copied verbatim,
  since that abstract isn't itself a registered component), and the same
  generic-self-aliased-override pattern the non-KK sibling
  (`incidence_gcomp_generic_alias_overrides`) uses for every method whose
  harvested body called `super$...`. `dependencies = "KKPassThrough"` (not
  `KKCompound` — no IVWC matched/reservoir combination here, just
  cluster-robust SEs over all subjects). `EDI_INFERENCE_LEGACY_EXCLUDED_
  CAPABILITIES`'s two transitional exclusion entries for these classes were
  removed per that table's own removal instruction (no longer accidentally
  inheriting `parametric_likelihood_bootstrap`); the static expectation list
  in `test-parametric-bootstrap-lr-all-capable-classes.R` updated to match.
  Two real bugs found and fixed via the golden, both now documented inline
  at their fix site:
  (1) **`compute_rand_two_sided_pval` pin wrong on the first pass** — copied
  the non-KK sibling's `InferenceRand` pin without verifying it against
  *this* class's actual legacy resolution; an R6 ancestor walk showed the
  real legacy chain resolves to `InferenceRandCI` instead (which correctly
  handles incidence data; `InferenceRand`'s version refuses it outright).
  Lesson: a sibling class's pin choice is not transferable without checking
  each class's own actual ladder resolution, even when the sibling looks
  structurally identical.
  (2) **Missing worker-reuse wiring** — the non-KK sibling's
  `incidence_gcomp_worker_overrides` (`supports_reusable_bootstrap_worker`
  + the three `create_bootstrap_worker_state`/`load_bootstrap_sample_into_
  worker`/`compute_bootstrap_worker_estimate` methods) was overlooked on
  the first pass; without it the migrated class silently fell back to the
  generic (non-reused-worker) resampling path. Symptom was subtle and
  easy to mistake for a real bug in the *legacy* side: legacy's
  `approximate_randomization_distribution_beta_hat_T`/`approximate_rand_
  bootstrap_distribution_beta_hat_T` returned the exact same constant value
  across all replicates (a property of the worker-reuse path, not a red
  flag on its own) while migrated varied properly — the WRONG side looked
  more "correct." Found only by the golden comparison, not by inspection;
  added `incidence_kk_gcomp_worker_overrides` mirroring the non-KK block
  exactly, restoring parity. Golden
  `test-incid-kk-gcomp-migration-golden.R` (RD and RR both tested; RR
  needed the golden harness's hardcoded `delta = 0` pval-label args
  substituted with the correct per-estimand null (1) — every RR-type gcomp
  class rejects `delta <= 0` and this was simply never exercised by any
  prior golden; same clone-isolation precaution for the
  score/gradient/lik_ratio dropped-label probes as the quantile-regr
  golden, though this class turned out not to exhibit that corruption):
  all green. `IncidenceKKGComputation` added to the canonical component
  list; full battery (mixin-contracts, registry, guardrails, parametric-
  bootstrap-capable-classes, and the three pre-existing gcomp-specific test
  files exercising cache-readiness/reused-worker-fast-path/warm-start-
  chaining) green.
- **Scoping note 2026-08-18:** `InferenceIncidKKModifiedPoisson`/
  `InferenceAbstractKKModifiedPoisson` (`inference_incidence_KK_marginal.R`)
  is the one remaining descendant of `InferenceAbstractKKMarginalIncid`
  after the g-computation pair above migrated — investigated as a
  candidate "finish the KKMarginalIncid family" follow-on, but it is **not**
  a same-shape continuation: `supports_likelihood_tests() = TRUE`,
  `supports_lik_ratio_param_bootstrap() = TRUE`, and a real
  `get_likelihood_test_spec()`/`simulate_under_lik_null()` (score/gradient/
  LR tests, parametric-bootstrap LR calibration) — it needs
  `LikelihoodTests`/`ParametricLikelihoodBootstrap` composed, not the
  Wald-only `"none"`-tier recipe every KK/IVWC migration this stretch has
  used. Its non-KK sibling `InferenceIncidModifiedPoisson`
  (`inference_incidence_modified_poisson.R`) is **also still unmigrated**
  (`inherit = InferenceAsympLikStdModCache`), so unlike every other pairing
  this stretch there is no already-migrated non-KK template to mirror —
  this would be a from-scratch full-likelihood-tier migration. Belongs with
  the "Full-Likelihood Estimators" / KK one-likelihood work below, not this
  section; not started.
  - [x] **Completed 2026-08-19.** Migrated by migrating the shared
    grandparent `InferenceAbstractKKMarginalIncid`
    (`inference_incidence_KK_marginal_abstract.R`) rather than
    `InferenceAbstractKKModifiedPoisson`/`InferenceIncidKKModifiedPoisson`
    directly -- same "migrate the shared base" strategy as the
    `InferenceAbstractKKCondLogitGLMM`/`InferenceAbstractKKOrdinalCLMM`
    families. Flipped from the raw-splice `utils::modifyList(as.list(
    InferenceMixinKKPassThrough$public/private), list(...))` state (manual
    harvesting under `inherit = InferenceParamBootstrap`, not even a
    `define_inference_class()` call) to `inherit = Inference` with
    `components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
    "KKPassThrough")` -- `ParametricLikelihoodBootstrap`, not Wald-only,
    confirming the scoping note's own reasoning: `InferenceAbstractKKModifiedPoisson`
    genuinely needs it for its real `get_likelihood_test_spec()`/
    `simulate_under_lik_null()`. `InferenceAbstractKKModifiedPoisson` and
    `InferenceIncidKKModifiedPoisson` themselves needed zero changes (no
    `super$...()` calls in either body) -- confirming the scoping note's
    "not a same-shape continuation" framing was about the *target*
    composition shape, not extra work needed in these two files themselves.
    - **Correction to this scoping note**: the non-KK sibling
      `InferenceIncidModifiedPoisson` was mischaracterized above as "also
      still unmigrated" -- re-investigated 2026-08-19 and found it's
      actually already in the same accepted terminal state as every other
      `InferenceAsympLikStdModCache`-leaf class (e.g. `InferenceIncidProbitRegr`):
      a plain `R6::R6Class` leaf off an already-composed base, correctly
      "pending" in the migration manifest by the heuristic's own design (only
      auto-detects "migrated" when a class's *immediate* parent is
      `"Inference"` itself), not a genuine gap. It additionally serves as the
      harvesting source for `IncidenceModifiedPoissonLikelihoodSource`
      (`inference_component_source_parts(InferenceIncidModifiedPoisson)`),
      used by nothing yet but structurally analogous to every other
      Source-harvesting pattern in this file. No changes needed or made to
      it.
    - **Two real bugs found and fixed in the previously-untouched
      `InferenceIncidKKGCompAbstract`** (a *sibling* descendant of
      `InferenceAbstractKKMarginalIncid` -- already migrated to its own
      `define_inference_class()` via `IncidenceKKGComputation` in the "KK And
      IVWC Estimators" section, but deliberately kept as a real R6 generator
      both for component harvesting and as the ancestor of
      `test-incid-kk-gcomp-migration-golden.R`'s legacy fixture -- discovered
      only because that golden test re-ran cleanly as a regression check
      after this migration):
      1. Six `super$compute_bootstrap_confidence_interval()`/`compute_bootstrap_
         two_sided_pval()`/`compute_bayesian_bootstrap_*()`/`compute_jackknife_
         wald_*()` calls in `InferenceIncidKKGCompAbstract`'s *own* class body
         (distinct from its separately-harvested `IncidenceKKGComputationSource`,
         which already had the fix via `incidence_kk_gcomp_generic_alias_overrides`)
         were valid under the old deep R6 ladder but became **infinite
         self-recursion** once their parent flattened. Fixed by applying the
         identical generic-self-aliased-override pattern directly to this
         class's own body (six new `..._generic` pins, six `super$...()`
         call sites rewritten to `self$..._generic()`) -- zero risk to the
         already-migrated `InferenceIncidKKGCompRiskDiff`/`RiskRatio`, whose
         harvested-then-`modifyList()`-overridden version already won
         either way.
      2. `InferenceExtCIInversion`'s `private$get_standard_error()` call
         (reached via `ParametricLikelihoodBootstrap` -> `LikelihoodTests`,
         now genuinely composed on the ancestor) hits `Wald`'s raw
         `stop()`-throwing stub instead of a graceful NA-returning
         fallback, because `InferenceMLEorKMSummaryTable`'s private
         override (which provided that gracefully under the old deep
         ladder: `InferenceAsympLik -> InferenceMLEorKMSummaryTable ->
         InferenceAsymp`) was **never extracted into any registered
         component** -- a real, pre-existing architectural gap in the
         component system. Confirmed confined entirely to
         `test-incid-kk-gcomp-migration-golden.R`'s legacy-only
         `score_ci`/`gradient_ci`/`lik_ratio_ci` probes (already in that
         file's `maybe_dropped_labels` list): the real migrated GComp
         classes (`likelihood_tier = "none"`) never compose
         `ParametricLikelihoodBootstrap` at all, so those methods are
         correctly `"absent"` on them regardless. Tolerated at the test
         level (a new `tryCatch` around the legacy call, scoped to
         `maybe_dropped_labels`, converting this specific error message to
         `status = "error"` so the existing degenerate/wald-fallback check
         can run instead of the whole test crashing) rather than fixed at
         the component level -- doing the latter would mean adding a
         graceful `get_standard_error` to the shared `Wald`/`LikelihoodTests`
         components themselves, affecting every class that composes them,
         far beyond this migration's scope.
    - Golden test added: `test-incid-kk-modified-poisson-migration-golden.R`,
      fixture `fixtures/legacy_incid_kk_modified_poisson.R` (the
      pre-migration `InferenceAbstractKKMarginalIncid` from git HEAD plus
      the *unchanged* `InferenceAbstractKKModifiedPoisson`/
      `InferenceIncidKKModifiedPoisson`, re-parented) -- 51/51 passing.
      `test-incid-kk-gcomp-migration-golden.R` (both RD and RR, RR forced
      on locally since it's `skip_on_cran()`-gated) re-verified green after
      both `InferenceIncidKKGCompAbstract` fixes.
    - Fixed the same class of stale/missing `infer_inference_direct_components()`
      registry-switch gap for `InferenceAbstractKKMarginalIncid` (this one
      had no entry at all, not merely a stale one, since it was never
      composed via the registry before) and the corresponding
      `test-static-cleanup-guardrails.R` raw-splicing count (this file's
      entry dropped to 0 -- removed entirely, not just decremented).
    - Full regression battery (`test-incid-kk-modified-poisson-migration-golden.R`,
      `test-incid-kk-gcomp-migration-golden.R`, `test-mixin-contracts.R`,
      `test-static-cleanup-guardrails.R`,
      `test-parametric-bootstrap-lr-all-capable-classes.R`,
      `test-full-likelihood-migration-baseline.R`,
      `test-gcomp-cache-readiness.R`, `test-gcomp-boot-warm-start-chaining.R`)
      green after all fixes above.
- [x] Migrate KK one-likelihood classes to `Inference` plus `KKPassThrough`,
  `LikelihoodTests`, `ParametricLikelihoodBootstrap` when warranted, and
  estimator-specific likelihood components. **Completed 2026-08-19**: the
  last remaining unmigrated OneLik sibling, `InferenceIncidKKCondLogitGLMMOneLik`,
  was unblocked and migrated as part of the "Migrate KK GEE and GLMM
  classes" item above (migrating its shared abstract base
  `InferenceAbstractKKCondLogitGLMM`). All other `*OneLik*` classes were
  already migrated in earlier stretches (see the "This completes every
  unblocked OneLik sibling" note earlier in this document); the remaining
  `inherit = InferenceParamBootstrap` hits in the tree are all
  `...LegacyRaw`-suffixed classes kept alive only for component harvesting,
  not real exported concrete classes.
- [x] Migrate KK GEE and GLMM classes after GEE/GLMM component contracts reject
  missing host hooks at class definition time. **Completed 2026-08-19: all
  10 GEE/GLMM classes migrated** (4 GEE classes already done pre-stretch; 6
  GLMM classes done this stretch across `InferenceContinKKGLMM`,
  `InferenceCountKKGLMM`, `InferenceOrdinalKKGLMM`, `InferencePropKKGLMM`,
  `InferenceIncidKKCondLogitGLMMIVWC`, `InferenceIncidKKCondLogitGLMMOneLik`
  — see the sub-items below for each migration's detail).
  - [x] All 4 `KK*GEE` classes (`InferenceCountPoissonKKGEE`,
    `InferenceIncidKKGEE`, `InferenceOrdinalKKGEE`, `InferencePropKKGEE`)
    confirmed already fully migrated (`inherit = Inference`, composing
    `KKGEE` directly) — verified 2026-08-19 auditing `inherit=` across all
    10 GEE/GLMM classes before starting this item.
  - [x] `InferenceContinKKGLMM` (`inference_continuous_KK_glmm.R`) and
    `InferenceCountKKGLMM` (`inference_count_KK_combined.R`) migrated
    2026-08-19: flipped from the hybrid `define_inference_class(inherit =
    InferenceParamBootstrap, components = "KKGLMM")` state (already a
    factory call, but still R6-inheriting `BayesianBootstrap`/
    `ParametricLikelihoodBootstrap` instead of composing them) to `inherit =
    Inference` with `components = c("BayesianBootstrap",
    "ParametricLikelihoodBootstrap", "KKGLMM")`. `metadata$capabilities =
    "likelihood_ratio"` added explicitly (required at class-definition time
    when composing `ParametricLikelihoodBootstrap` directly, bypassing
    `StandardModelCache`). `compute_rand_two_sided_pval` pinned from
    `InferenceRand`. `CountKKGLMM` additionally needed the generic-`self$`-
    aliased-override pattern for `compute_lik_ratio_confidence_interval`/
    `compute_lik_ratio_two_sided_pval` (bodies called `super$...()` to reach
    `InferenceAsympLik`'s generic dispatch, which doesn't resolve under flat
    composition). Golden tests added
    (`test-contin-kk-glmm-migration-golden.R`,
    `test-count-kk-glmm-migration-golden.R`) comparing against the
    pre-migration class body extracted verbatim from git HEAD
    (`tests/testthat/fixtures/legacy_{contin,count}_kk_glmm.R`); both pass
    52/52.
    - Investigated an apparent numeric-drift failure in the first golden
      test draft (both `compute_estimate` and derived CI/pval outputs
      differed by ~1e-4-1e-3 between legacy and migrated on fresh objects).
      Root-caused to the fixture methodology, not a real migration bug:
      `edi_optimization_dispatch_policy()` (`globals.R`) dispatches the
      default optimizer algorithm by regex-matching the literal
      `class(self)[1]` string (e.g. pattern `"KKGLMM$"` -> `"lbfgs"`); the
      fixture's `sed`-renamed legacy class had its literal class-name
      string (the first argument to `define_inference_class()`) changed to
      `...LegacyOrig` too, so it no longer matched the pattern and silently
      fell back to the unrelated default `"newton_raphson"` algorithm,
      producing a genuinely different (but legitimate) optimizer trajectory
      on both sides. Fixed by keeping the literal class-name string
      argument unchanged (`"InferenceContinKKGLMM"`/`"InferenceCountKKGLMM"`)
      in both fixtures, only renaming the top-level R variable binding —
      same "kept-alive raw class" precedent as elsewhere in this stretch:
      dispatch-by-name mechanisms need the literal classname string
      preserved even when the R binding is renamed for harvesting/fixture
      purposes.
    - Also found and fixed a real (if latent) registry gap surfaced by this
      migration: `infer_inference_direct_components()`
      (`inference_class_registry.R`) is a static `switch()` keyed by class
      name with a `character()` default fallback; it had no entry for
      either class. In the pre-migration hybrid state this didn't matter
      (their `ParametricLikelihoodBootstrap`-derived capabilities arrived
      via `inherit = InferenceParamBootstrap`'s ancestor chain, which the
      switch does cover). After flipping to direct composition with no
      algorithmic parent, the switch's `character()` fallback silently gave
      both classes empty `direct_components`, which zeroed out their
      `parametric_likelihood_bootstrap` capability via
      `get_effective_capabilities()` and broke
      `test-parametric-bootstrap-lr-all-capable-classes.R` (whose smoke-case
      table already listed both classes, so the break was caught
      immediately). Fixed by adding explicit switch entries mirroring the
      real `components = c("BayesianBootstrap", "ParametricLikelihoodBootstrap",
      "KKGLMM")` call, per the same "must mirror the factory call exactly"
      convention already documented inline for other direct-composition
      classes in that switch.
    - Full regression battery (`test-contin-kk-glmm-migration-golden.R`,
      `test-count-kk-glmm-migration-golden.R`, `test-mixin-contracts.R`,
      `test-static-cleanup-guardrails.R`,
      `test-parametric-bootstrap-lr-all-capable-classes.R`) green after both
      fixes.
  - [x] `InferenceOrdinalKKGLMM` (`inference_ordinal_KK_combined.R`)
    migrated 2026-08-19: flipped from the raw-splice
    `utils::modifyList(as.list(InferenceMixinKKGLMMShared$public/private),
    list(...))` state (manual harvesting of the `KKGLMM` raw source under
    `inherit = InferenceParamBootstrap`, not even a `define_inference_class()`
    call) to `define_inference_class(inherit = Inference, components =
    c("BayesianBootstrap", "ParametricLikelihoodBootstrap", "KKGLMM"))` --
    same hybrid-state fix as Contin/CountKKGLMM. No `super$...()` calls
    anywhere in the class body (verified by grep), so no generic-alias
    overrides were needed; `overrides$public` needed
    `get_supported_testing_types` in addition to the usual four
    compute-method names. Golden test added
    (`test-ordinal-kk-glmm-migration-golden.R`,
    fixture `fixtures/legacy_ordinal_kk_glmm.R`), 52/52 passing. Also
    ratcheted down the "new raw component splicing" static-cleanup guardrail
    (`test-static-cleanup-guardrails.R`) for this file (2 -> 0 occurrences,
    entry removed) and added the missing `infer_inference_direct_components()`
    registry-switch entry (same class of gap as Contin/CountKKGLMM).
  - [x] `InferencePropKKGLMM`, `InferenceIncidKKCondLogitGLMMIVWC`,
    `InferenceIncidKKCondLogitGLMMOneLik` migrated 2026-08-19 by migrating
    their shared abstract base instead of each leaf individually: all three
    are plain `R6::R6Class` leaves inheriting directly from
    `InferenceAbstractKKCondLogitGLMM`
    (`inference_incidence_KK_cond_logit_glmm_abstract.R`), which was itself
    already a hybrid `define_inference_class(inherit =
    InferenceParamBootstrap, components = "KKPassThrough")`. Flipped that one
    definition to `inherit = Inference, components = c("BayesianBootstrap",
    "ParametricLikelihoodBootstrap", "KKPassThrough")` -- same fix, applied
    once at the shared base, exactly like `InferenceAsympLikStdModCache`'s
    many plain-R6 descendants (e.g. `InferenceIncidProbitRegr`). None of the
    three leaves call `super$...()` anywhere in their own bodies (verified by
    grep), so no generic-alias overrides were needed for them.
    - The abstract base's own `get_standard_error` was `public`-only
      pre-migration -- harmless only because `KKPassThrough` alone never
      pulled in a competing private `get_standard_error` (the canonical
      location for this method everywhere else in the codebase, e.g. Wald's).
      Composing `ParametricLikelihoodBootstrap` (via its `LikelihoodTests` ->
      `Wald` dependency chain) now pulls one in, producing a genuine
      public/private cross-slot name duplicate that `R6::R6Class()` rejects
      outright (the pre-existing `overrides$public_private = "get_standard_error"`
      declaration only suppresses `define_inference_class()`'s own
      duplicate-name validation -- it does not actually deduplicate the
      slots before they reach `R6::R6Class()`, so it was silently vestigial
      dead code until composition actually produced a real duplicate).
      Fixed by moving `get_standard_error` from `public` to `private` (after
      confirming via repo-wide grep that no caller anywhere uses
      `$get_standard_error()` publicly -- every caller accesses it via
      `private$get_standard_error()` / `.__enclos_env__$private$get_standard_error()`),
      which preserves behavior exactly.
    - The `compute_rand_two_sided_pval` pin needed `InferenceRandCI`'s
      version, not `InferenceRand`'s (unlike every other KK GLMM migration
      this stretch): this abstract base serves both incidence and proportion
      response types, and the pre-migration R6 inheritance chain resolved to
      `InferenceRandCI`'s Zhang-incidence-aware wrapper. Caught by the golden
      test: `InferenceRand`'s raw version threw "Randomization tests are not
      supported for incidence. Use Zhang method." on an incidence design
      where the legacy class returned a real Zhang p-value.
    - Golden tests added: `test-incid-kk-cond-logit-glmm-migration-golden.R`
      (IVWC + OneLik, sharing one fixture) and
      `test-prop-kk-glmm-migration-golden.R`, fixture
      `fixtures/legacy_kk_cond_logit_glmm.R` (the abstract base plus all
      three leaves, copied verbatim from git HEAD with only top-level
      bindings renamed, literal class-name strings preserved for
      dispatch-by-name policies) -- all passing.
    - Also fixed the `infer_inference_direct_components()` registry-switch
      entry for `InferenceAbstractKKCondLogitGLMM` itself (was stale at
      `"KKPassThrough"` alone), which the three leaves inherit transitively
      via `resolve_inference_components()`'s parent-chain walk (none of them
      have their own direct_components entry, matching the
      `InferenceAsympLikStdModCache`-leaf convention) -- this was needed for
      `InferencePropKKGLMM` to correctly re-advertise
      `parametric_likelihood_bootstrap` capability and pass
      `test-parametric-bootstrap-lr-all-capable-classes.R` (the two Incid
      leaves are unaffected by this specific capability, since
      `EDI_INFERENCE_LEGACY_EXCLUDED_CAPABILITIES` already deliberately
      excludes `parametric_likelihood_bootstrap` for both -- a pre-existing,
      untouched exclusion).
    - Confirmed (and documented in each golden test) that these three
      leaves' own `migration_status` in the hierarchy-migration manifest
      correctly stays `"pending"` post-migration -- the manifest's
      auto-"migrated" heuristic only fires when a class's *immediate* R6
      parent is `"Inference"` itself, which none of the three are (they
      inherit from the now-migrated abstract base, one level removed) --
      same as every already-migrated `InferenceAsympLikStdModCache` leaf.
      What matters and is asserted instead is that
      `InferenceAbstractKKCondLogitGLMM` itself now has `parent = "Inference"`.
    - This also unblocks `InferenceIncidKKCondLogitGLMMOneLik`, the last
      previously-unmigrated OneLik sibling.
    - Full regression battery (`test-contin-kk-glmm-migration-golden.R`,
      `test-count-kk-glmm-migration-golden.R`,
      `test-ordinal-kk-glmm-migration-golden.R`,
      `test-incid-kk-cond-logit-glmm-migration-golden.R`,
      `test-prop-kk-glmm-migration-golden.R`,
      `test-incid-kk-cond-logit-onelik-migration-golden.R`,
      `test-incid-kk-cond-logit-ivwc-migration-golden.R`,
      `test-mixin-contracts.R`, `test-static-cleanup-guardrails.R`,
      `test-parametric-bootstrap-lr-all-capable-classes.R`) green after all
      fixes above.
- [x] Add focused KK regression tests for matched-set weights, IVWC weighting,
  rank reduction, nonestimable fits, and block/cluster edge cases.
  **Completed 2026-08-19** (scoped with the user to one representative class
  family covering all five behaviors authentically, rather than spreading
  thin across ~40 KK/IVWC classes): `InferenceContinKKOLSIVWC`
  (`inference_continuous_KK_ols_ivwc.R`) chosen because its point estimate
  is a genuine inverse-variance-weighted combination of a matched-pair-
  differenced OLS fit and a reservoir OLS fit
  (`w_star = ssq_r / (ssq_r + ssq_m)`), sharing the `reduce_design_matrix_once`/
  `only_matches`/`only_reservoir` compound dispatch machinery
  (`inference_mixin_kk_passthrough_compound.R`) used by every other KK
  compound estimator. New file `test-kk-ivwc-compound-focused-regression.R`,
  4 `test_that()` blocks / 19 assertions, all against empirically-found
  fixed-seed KK design configurations (`DesignSeqOneByOneKK14`'s adaptive
  Mahalanobis caliper isn't analytically invertible, so configurations were
  found by sweeping seed/covariate-spread/drift and checking the resulting
  `KKstats$m`/`nRT`/`nRC`, then locked in with an explicit assertion on
  those counts so a future change in matching behavior fails loudly at that
  assertion instead of silently testing the wrong code path):
  - IVWC weighting: a balanced design (`m=3, nRT=7, nRC=7`) verifying the
    combined estimate equals the `w_star` formula exactly and lies between
    the two sub-estimates.
  - Matched-set weights / block edge case: a design with exactly one
    matched pair (`m=1`, zero within-pair-differenced-regression df) --
    confirms `ssq_beta_T_matched` is correctly `NA` and the combined
    estimate falls back to the reservoir estimate exactly.
  - Rank reduction: covariates with `x2 = 2*x1 + tiny noise` (exact
    collinearity breaks the design's own Mahalanobis covariance inversion
    at construction time, so a small noise term was needed to keep design
    construction well-posed while the OLS design matrix stays numerically
    rank-deficient) -- cross-checked by calling the class's own
    `reduce_design_matrix_once()` directly (not a hand-reimplementation of
    its pivot logic) on a fresh copy of the design matrix, then a plain
    `lm.fit()` on the reduced result, confirming it matches the class's
    cached coefficient.
  - Nonestimable fits / block edge case: `n=3` is too small for
    `DesignSeqOneByOneKK14` to ever form a matched pair (`m=0`) and leaves a
    reservoir with fewer rows than predictor columns -- confirms
    `compute_estimate()`/`compute_asymp_confidence_interval()`/
    `compute_asymp_two_sided_pval()` all return clean `NA` rather than
    erroring.
  All passing, stable across repeated runs (no RNG flakiness).

#### Base Deletion

- [x] After a current algorithmic base has no concrete descendants, convert it
  into an internal component source or delete it. **Done 2026-08-21 -- the
  "convert" branch, taken for all 12 remaining bases.** With zero concrete
  descendants package-wide (see the milestone note above), every base in
  `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` now serves exclusively as
  internal migration infrastructure. A per-base consumer inventory
  (component `source_name` harvest + `$public_methods$` pins + `inherit =`
  refs, comment lines excluded) confirms none is deletable and none needs
  further conversion -- each already IS the internal component source the
  TODO asked for:
  - `InferenceAsymp` (Wald source; 3 pins; 2 fixture inherits),
    `InferenceJackknife` (6 pins), `InferenceNonParamBootstrap` (13 pins),
    `InferenceBayesianBootstrap` (9 pins), `InferenceRand` (61 pins),
    `InferenceRandCI` (21 pins), `InferenceRandBootstrap`/
    `InferenceRandBootstrapCI` (harvest-only), `InferenceAsympLik`
    (LikelihoodTests source; 24 pins; 9 inherits from kept
    harvesting-generators/LegacyRaw fixtures) -- all 9 are live
    `source_name` targets for the very components that replaced them
    (lazy/eager harvest reads their generator methods at load), so
    deleting any would break the composed classes themselves.
  - `InferenceKKPassThroughCompound`/`...NoParamBootstrap` -- built via
    `compose_inference_mixins()` (the KK mixin machinery's own reference
    composition) and used by golden-test legacy fixtures (`test-contin-kk-
    ols-onelik-`/`test-incid-kk-newcombe-`/`test-contin-kk-ols-ivwc-`/
    `test-incid-kk-cond-logit-ivwc-migration-golden.R`) plus
    `inference_all_abstract_quantile_rand_ci.R`'s kept harvesting ladder.
  - `InferenceMLEorKMSummaryTable` -- `InferenceAsympLik`'s own ladder
    parent plus two direct `test-mle-km-summary-table.R` fixture
    subclasses.
  (`InferenceExact` from the original wish-list was already deleted in an
  earlier phase; `InferenceAsympLikStdModCache`, count-likelihood, and KK
  compound bases were retired from the list family-by-family above.)
- [x] Delete `InferenceRand`, `InferenceRandCI`, `InferenceNonParamBootstrap`,
  `InferenceRandBootstrap`, `InferenceRandBootstrapCI`,
  `InferenceBayesianBootstrap`, `InferenceJackknife`, `InferenceExact`,
  `InferenceAsymp`, `InferenceAsympLik`, `InferenceParamBootstrap`,
  `InferenceAsympLikStdModCache`, count likelihood bases, and KK compound bases
  only after no concrete class inherits from them. **Resolved 2026-08-21 as
  deliberately NOT-deleted** (the TODO's own "only after" precondition is
  met -- zero concrete inheritors -- but the previous item's "convert"
  disposition supersedes deletion): these generators are the live harvest
  sources for their replacement components and the pin sources for 130+
  `$public_methods$` method pins across the migrated classes; deleting them
  would require first rewriting every component to a static `*Source` list
  and every pin to a static copy, a large mechanical churn with no
  behavioral payoff now that the strict gate (below) makes them unusable as
  concrete-class parents.
- [x] Remove the base from `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` in the
  same change that deletes or converts it. **Superseded/absorbed 2026-08-21**:
  every family-specific base that got individually drained WAS removed from
  the list in its own draining change (`InferenceAsympLikStdModCache`/
  `...NoParamBootstrap`, `InferenceCountLikelihood`,
  `InferenceParamBootstrap` -- see their per-removal notes). The 12
  remaining entries stay in the list ON PURPOSE: the list is now the
  denylist the strict gate and the flipped registry test check concrete
  ancestor chains against, so emptying it would disarm the very invariant
  it powers.
- [x] Enable `EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY` in normal tests once all
  concrete classes are migrated. **Done 2026-08-21.** Two-part change:
  (1) `assert_shallow_inference_hierarchy_complete()` rekeyed from
  `migration_status == "pending"` to
  `length(algorithmic_compatibility_ancestors) > 0L` -- the "pending"
  proxy was correct while draining, but the accepted-terminal-state thin
  leaves (status "pending", zero algorithmic ancestors) must pass the
  gate, and a hypothetical deep class must fail it regardless of status
  label (its fixture unit test in `test-inference-class-registry.R`
  rekeyed to match, including an explicit thin-leaf-passes case); the
  assert is now also invoked at the end of
  `populate_inference_class_registry()` (no-op unless the env var is set,
  so plain `library(EDI)` is unaffected). (2) New
  `tests/testthat/setup-shallow-hierarchy.R` sets
  `EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY=true` (and the design twin
  `EDI_REQUIRE_SHALLOW_DESIGN_HIERARCHY=true`, whose gate was documented
  as opt-in-for-CI since fix_design_hierarchy.md TODO-39) for every test
  run, and fail-fast asserts both gates once at setup. Verified: gates
  pass end-to-end with both flags enabled; 9-file battery green with the
  flag confirmed active during the run (`test-inference-class-registry.R`,
  `test-mixin-contracts.R`, `test-capability-tables.R`,
  `test-static-cleanup-guardrails.R`,
  `test-full-likelihood-migration-baseline.R`, two KK migration goldens,
  `test-design-class-registry.R`, `test-bayesian-bootstrap.R`).
- [x] Add the final strict test that no concrete class descends from an
  algorithmic compatibility base. **Done 2026-08-21** (with the
  `InferenceOrdinalPairedSignTest` migration, the last class holding this
  open): `test-inference-class-registry.R`'s
  "no concrete class descends from an algorithmic compatibility base"
  test -- flipped from the draining-era "remaining algorithmic
  compatibility descendants are explicitly tracked" assertion into the
  strict zero-ancestors invariant over every concrete manifest record.
  See the "Base Deletion" section's 2026-08-21 milestone note.

**Stale as of 2026-08-21** -- superseded by the milestone note immediately
above: the 106-count reflects this section's state when it was first
written, not the current one. Zero concrete generators now inherit through
any algorithmic compatibility base; the final strict gate described here is
implemented and enabled (see "Base Deletion"'s 2026-08-21 closure notes).
Left in place as a historical snapshot rather than deleted, so the
family-by-family draining narrative below remains readable in order.

- [x] **`InferenceCountCompositeLikelihood` and
  `InferenceCountLikelihoodNoParamBootstrap` deleted (2026-08-17)** — the
  first algorithmic bases freed by completed migrations rather than by
  branch topology. Found via a fresh per-base pending-descendant sweep over
  the migration manifest: both had **zero** pending concrete descendants
  (the composite base's only concretes, `InferenceCountQuasiPoisson`/
  `InferenceCountRobustPoisson`, migrated 2026-08-16 to compose the
  `CountCompositeLikelihood` component; the no-param-bootstrap count base
  had no inheritors at all — `grep -rn "inherit =
  Inference(CountCompositeLikelihood|CountLikelihoodNoParamBootstrap)"`
  across `R/` and `tests/` returns nothing). Both generators were pure
  duplicates of their harvested component sources
  (`CountCompositeLikelihoodSource` in
  `inference_count_composite_likelihood.R`,
  `CountLikelihoodPlumbingSource` in
  `inference_all_abstract_count_likelihood.R`), which the registered
  components read directly and which are **kept**; only the two R6
  generator assemblies were deleted (with explanatory tombstone comments in
  place), exactly mirroring the `InferenceExact` deletion below. Registry
  updates in the same change, per this section's rule: both names removed
  from `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES`,
  `EDI_INFERENCE_ABSTRACT_CLASS_NAMES`, and
  `infer_inference_direct_components()`'s switch. The only remaining
  textual references are string classname arguments in
  `test-bootstrap-reused-worker-families.R`'s count-ancestry invariant,
  whose either-ancestry-or-component check falls through to the component
  branch for migrated classes by design. Verified: clean package load;
  `test-inference-class-registry.R`, `test-mixin-contracts.R`, and
  `test-bootstrap-reused-worker-families.R` fully pass;
  `test-quasi-robust-migration-baseline.R` passes every metadata test with
  its single runtime error being the recurring unrelated
  concurrent-session DLL desync (`get_column_types_cpp` unresolved during
  design construction, before any count class is involved).
- [x] **`InferenceExact` has zero remaining concrete descendants — candidate
  for deletion now, ahead of the rest of this section.** Found 2026-08-14
  while checking whether the no-likelihood family's completion unblocked any
  base deletions (it doesn't, for the `InferenceAsymp`-rooted chain — see the
  "No-Likelihood Migration Marking" entry above). `InferenceExact` is a
  sibling branch off `InferenceJackknife` (`inherit = InferenceJackknife`
  in `inference_all_abstract_exact.R`), not part of the
  `InferenceAsymp -> ... -> Inference` chain those other bases sit on.
  `grep -rn "inherit = InferenceExact\b"` across `R/*.R` returns nothing —
  every exact-tier class (`InferenceIncidExactBinomial`,
  `InferenceIncidExactFisher`, `InferenceIncidExactZhang`) was already
  migrated to `ExactTest`/`ExactBinomialIncidence`/`ExactFisherIncidence`/
  `ExactZhangIncidence` components earlier in this effort (see "Exact Test
  Extraction" above), so nothing still inherits from `InferenceExact`
  itself. Not yet verified: whether anything else references it by name
  (e.g. `is(x, "InferenceExact")` dispatch, `class(self)` regex tables in
  `globals.R`, or `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` itself) the
  way `InferencePropGCompAbstract$` had to be caught and fixed in
  `globals.R` before that class could be safely deleted earlier in this
  effort — that sweep needs to happen before actually deleting it, not just
  the descendant check above.

  **Progress 2026-08-16:** the exhaustive indexed reference sweep is complete.
  Production `ExactTest` composition now loads from explicit
  `ExactTestSource` public/private lists, so it no longer depends on harvesting
  `InferenceExact`'s generator internals. The legacy generator remains for the
  exact-family golden-test oracle and still has name-based compatibility
  references in the class registry, simulation framework, and package-test
  utilities; those callers must move to `exact_test` capability checks before
  the class and generated Rd file can be removed.
  **Deleted 2026-08-16** (superseding the "must move first" conclusion above
  — investigated each remaining name-based reference directly rather than
  requiring a capability-check migration as a hard prerequisite):
  - Removed the `InferenceExact = R6::R6Class(...)` generator itself from
    `inference_all_abstract_exact.R`, keeping `exact_test_public`/
    `exact_test_private` (the plain lists both the generator and
    `ExactTestSource` were independently built from — `ExactTestSource =
    list(public = exact_test_public, private = exact_test_private)`, not a
    harvest of the R6 generator, so nothing about `ExactTest`'s production
    behavior changes) and `ExactTestSource` itself untouched.
  - `inference_class_registry.R`: removed `"InferenceExact"` from
    `EDI_INFERENCE_ALGORITHM_COMPATIBILITY_BASES` and
    `EDI_INFERENCE_ABSTRACT_CLASS_NAMES` (per the "Base Deletion" section's
    own instructions), the `InferenceExact = "ExactTest"` entry from
    `infer_inference_direct_components()`'s switch (same vestigial-fallback
    pattern already removed for `InferenceIncidGCompRiskDiff`/`RiskRatio`
    earlier in this effort — confirmed no test hardcodes membership or
    length of either list), and the `"InferenceExact" %in% ancestors ||`
    branch from `inference_no_likelihood_group()` (the sibling `grepl("Exact",
    record$name)` condition already covers every exact-named class
    independently, so this was a dead sub-condition once no record could
    have `"InferenceExact"` as an ancestor).
  - `simulations_framework.R`'s `"InferenceExact"` string-literal fallback
    arguments (`.supports_inference_capability(inf_obj, "exact_test",
    "InferenceExact")`, two call sites) were deliberately **left as-is**
    rather than migrated to capability-only checks: `is(inf_obj,
    fallback_class)` with a class-name string that no longer names any
    defined class simply evaluates to `FALSE` (R6/`is()` checks class-vector
    membership by string match, it doesn't require the string to resolve to
    a live class definition) — confirmed this doesn't error, just becomes a
    permanently-dead fallback branch, harmless and consistent with how every
    *other* class in this same fallback pattern behaves (e.g. `"InferenceAsymp"`
    for the `"wald"` capability, which is very much still alive). Not worth
    the churn of touching shared simulation-framework code for a
    now-and-forever-FALSE branch.
  - Deleted `man/InferenceExact.Rd` (the class's roxygen block was
    `@keywords internal`, never exported, no other file referenced its Rd
    topic).
  - `test-exact-incidence-migration-baseline.R`'s three
    `make_exact_*_legacy_generator()` helpers (the actual "golden-test
    oracle" usage) previously did `inherit = EDI:::InferenceExact` to pick
    up `exact_test_public`/`exact_test_private` via true R6 inheritance from
    a level below their own `ExactXXXIncidenceSource`-equivalent private
    list. Rewrote them to `inherit = EDI:::InferenceJackknife` directly
    (`InferenceExact`'s own parent) with `exact_test_public`/`private`
    merged in via `utils::modifyList()` (source-specific entries winning
    over the generic ones, replicating the old inheritance-shadowing
    semantics in one flat level instead of two). This changes what
    `inference_migration_duplicate_private_owners()` (an ancestor-chain
    structural walk) reports: 4 of the previous 9 duplicate-owner names
    (`resolve_exact_type`, `compute_exact_confidence_interval_by_type`,
    `compute_exact_two_sided_pval_for_treatment_effect_by_type`,
    `default_exact_type`) were duplicated *because* they were independently
    defined at both the legacy generator's own old level and
    `InferenceExact`'s now-collapsed-away level — collapsing those two
    levels into one correctly drops them from the count (the `modifyList()`
    shadowing still happens, it's just no longer detectable as a
    *structural* R6 ancestor-chain duplication). The remaining 5
    (`normalize_exact_inference_args`, `assert_exact_inference_params` —
    genuine collisions with `InferenceRandCI`'s own Zhang-exact-CI private
    methods, a still-separate deeper ancestor; the jackknife triplet —
    collisions with `InferenceNonParamBootstrap`, also still separate) are
    unaffected by the deletion and still detected correctly. Updated
    `exact_incidence_baseline_duplicate_private_owners` from the old 9-name
    list to the new 5-name list (with a comment explaining why), and changed
    the `expect_identical()` calls comparing duplicate-owner name sets to
    `expect_setequal()` — the ancestor-chain walk's insertion order was
    never a meaningful contract, only the actual set of colliding names is.
  - Regression check: `test-exact-incidence-migration-baseline.R`,
    `test-mixin-contracts.R`, and `test-inference-class-registry.R` all
    verified — the first two fully clean; `test-mixin-contracts.R` shows one
    unrelated pre-existing failure ("every lazy component implementation
    matches its declared contract" calls `expect_length(..., info = ...)`,
    which the installed `testthat` 3.3.2 rejects — confirmed via
    `args(testthat::expect_length)`, a generic test-harness/testthat-version
    mismatch iterating every registered component, nothing exact-specific,
    unrelated to this deletion).

### Follow-Ups From Implementation (Audit Findings)

Bugs and tangential issues recorded inside this file's completed (`[x]`)
migration entries but never turned into their own actionable TODOs. Collected
here (2026-08-13) rather than left as prose-only notes.

- [x] **`InferenceSurvivalKKLWACoxPHOneLik` native segfault: `compute_rand_
  two_sided_pval()` followed by `approximate_rand_bootstrap_distribution_
  beta_hat_T()` on the same object crashes R (found 2026-08-18, FIXED
  2026-08-19 — was pre-existing, confirmed present in the pre-migration
  architecture too).** **Actual root cause (confirmed with instrumented
  repro, not the originally-hypothesized one):** the offending in-place
  mutation was specifically `private$dead = private$des_obj_priv_int$dead`
  inside `compute_treatment_estimate_during_randomization_inference()`
  (`inference_survival_KK_lwa_cox_one_lik_abstract.R`). Post the y/y_L/y_R
  migration (`interval_censored_survival_response.md` TODO-1), `Design`
  no longer stores a raw `dead` field at all, so `des_obj_priv_int$dead` is
  now *always* `NULL` — this line silently clobbered the correctly-
  initialized `private$dead` (originally set at `initialize()` time via
  `des_obj$get_effective_dead()`, `inference_all_abstract.R:65`) with `NULL`
  on every `compute_rand_two_sided_pval()` call, and that `NULL` persisted on
  the live object afterward. The later `approximate_rand_bootstrap_
  distribution_beta_hat_T()` call reused that same corrupted live
  `private$dead` inside `load_rand_bootstrap_assignment_into_worker()`
  (`inference_all_abstract_rand_bootstrap.R`): `dead_sim = as.numeric(
  private$dead[draw$i_b])` turns `NULL[draw$i_b]` into a *zero-length*
  numeric vector (not `NULL`), which then got assigned onto the duplicated
  worker's `private$dead` and passed straight into `fast_coxph_regression_
  cpp(X, y, dead, ...)` with `nrow(X) == 24` but `length(dead) == 0` —
  confirmed by instrumenting `fast_coxph_regression_cpp` in a subprocess
  `Rscript` to print argument dimensions immediately before the crashing
  call. The C++ side indexes `dead` up to `nrow(X)-1` with no length check,
  so the 0-length vector produced the observed `address 0x10/0xb8, cause
  'memory not mapped'` out-of-bounds read. (The X/w-length mismatch
  originally hypothesized in this entry was not actually present — every
  `X`/`y`/`w`/`cluster` dimension logged at the crash boundary was
  consistent at 24; only `dead`'s length diverged.) **Fix (R-only, no C++
  touched):** in `compute_treatment_estimate_during_randomization_
  inference()`, re-derive `dead` the same way `Design$get_effective_dead()`
  does (`private$dead = as.numeric(!is.na(private$y))`, using the
  freshly-re-read `private$y`) instead of reading the defunct
  `des_obj_priv_int$dead` field. Added a regression test to
  `test-survival-kk-lwa-cox-onelik-migration-golden.R` that calls both
  methods on the same object in sequence and asserts no crash and a
  numeric length-9 bootstrap distribution; verified via `pkgload::load_all(
  ".", compile = FALSE)` in a subprocess `Rscript` (no recompilation) —
  passes, and the full golden file (57 assertions), `test-mixin-
  contracts.R` (1600), `test-inference-class-registry.R` (2623), and the
  sibling `test-survival-kk-lwa-cox-ivwc-migration-golden.R` (43) all still
  pass unchanged.
  Discovered while writing this class's migration golden
  (`test-survival-kk-lwa-cox-onelik-migration-golden.R`): calling
  `compute_rand_two_sided_pval(delta = 0, r = 9L)` then
  `approximate_rand_bootstrap_distribution_beta_hat_T(B = 9L)` on the SAME
  object segfaults (`*** caught segfault ***`, `address 0xb8, cause 'memory
  not mapped'`) inside `fast_coxph_regression_cpp`, reached via
  `worker_state$worker$compute_estimate()` → `private$shared_combined_
  likelihood()` → `private$fit_with_hardened_qr_column_dropping()`. Bisected
  to exactly this two-call sequence (neither call crashes alone or with any
  shorter prefix tried). **Root cause (diagnosed but not fixed):**
  `InferenceAbstractKKLWACoxOneLik`'s own `compute_treatment_estimate_
  during_randomization_inference()` re-reads and reassigns `private$w`/
  `private$y`/`private$dead` directly from the design object mid-call (its
  own comment: "Re-read w, y, dead because they might have been transformed
  for randomization") — this in-place mutation of the LIVE object's private
  state, combined with a LATER call to the reusable-bootstrap-worker
  machinery (`InferenceAsymp`'s `create_bootstrap_worker_state()` →
  `create_design_backed_bootstrap_worker_state()`, which `self$duplicate()`s
  the object to build a worker), appears to leave the duplicated worker's
  `X`/`w`/`dead` vectors at inconsistent lengths relative to whatever
  cached/reduced design matrix `fast_coxph_regression_cpp` receives,
  producing an out-of-bounds native read. **Verified NOT a migration
  regression**: reproduced identically on a from-scratch R6 reconstruction
  of the pre-migration `InferenceAbstractKKLWACoxOneLik`/
  `InferenceSurvivalKKLWACoxPHOneLik` ladder (same `inherit =
  InferenceParamBootstrap` chain, same raw `InferenceMixinKKPassThrough`
  splice) — the crash predates this migration and was simply never
  exercised by any existing test until this golden was written (no prior
  test called both methods on the same object). **Worked around, not
  fixed**, in the golden test: each label gets a fresh legacy/migrated pair
  instead of reusing one object across the whole label loop (every other
  KK/IVWC golden this stretch reuses objects across labels). This is a
  native crash (not a wrong-answer bug), so it deserves a dedicated
  investigation and fix in `inference_all_abstract_non_param_boot.R`'s
  reusable-bootstrap-worker duplication path and/or
  `inference_survival_KK_lwa_cox_one_lik_abstract.R`'s in-place `private$w/
  y/dead` reassignment — not attempted here per this project's standing
  "never compile/touch C++ without explicit permission" rule and because
  fixing a native crash root-caused in shared resampling infrastructure is
  a larger, riskier task than this migration's scope. Whoever picks this up
  should start from the exact repro above (KK14 survival design, `n=24`,
  `r=9`/`B=9`) and `gdb`/`valgrind` the two-call sequence directly.
- [x] **Same defunct-`des_obj_priv_int$dead`-field bug (see the
  `InferenceSurvivalKKLWACoxPHOneLik` entry above for the confirmed root
  cause and fix pattern) also present in `inference_survival_KK_clayton_
  copula.R`, in BOTH `InferenceSurvivalKKClaytonCopulaIVWC` and
  `InferenceSurvivalKKClaytonCopulaOneLik`, and in
  `inference_survival_KK_weibull_frailty.R`'s
  `InferenceAbstractKKWeibullFrailtyOneLik` (found 2026-08-19, FIXED
  2026-08-19).** Applied the same fix pattern as the LWA Cox entry to all
  three occurrences: `private$dead = private$des_obj_priv_int$dead` →
  `private$dead = as.numeric(!is.na(private$y))` (re-deriving the value the
  same way `Design$get_effective_dead()` does), in
  `inference_survival_KK_clayton_copula.R` lines ~147 (IVWC) and ~600
  (OneLik, inside the `...LegacyRaw` raw class that both the legacy golden
  fixture and the migrated component's harvest source share) and
  `inference_survival_KK_weibull_frailty.R` line ~727 (also inside a
  `...LegacyRaw` raw class). R-only, no C++ touched. Verified: the
  previously-crashing Clayton OneLik randomization-family methods
  (`compute_rand_two_sided_pval` etc., "Clayton copula fit inputs must have
  matching row counts") now return finite/NA values without error on both
  legacy and migrated sides; the WeibullFrailty OneLik previously-silent-NA
  case also unaffected (still NA, now confirmed via the fixed code path
  rather than an accidental NULL-propagation). Simplified
  `test-survival-kk-clayton-copula-onelik-migration-golden.R` back to the
  standard comparison loop (removed the dedicated
  randomization-family-error-comparison branch, no longer needed now that
  neither side errors). All four affected goldens
  (`test-survival-kk-clayton-copula-onelik-migration-golden.R`,
  `test-survival-kk-clayton-ivwc-migration-golden.R`,
  `test-survival-kk-weibull-frailty-onelik-migration-golden.R`,
  `test-survival-kk-lwa-cox-onelik-migration-golden.R`) still pass green
  after the fix, confirming no new byte-identity mismatches were
  introduced by re-deriving `dead` instead of reading the defunct field.
  Confirmed via a package-wide grep for `des_obj_priv_int\$dead` after all
  four fixes: every remaining match is a code comment (explaining the fix),
  not a live read — no other occurrence exists anywhere in `R/`. The
  pattern description below is retained for context.
  **Original entry (superseded by the fix above), preserved for context:**
  Both classes' `compute_treatment_estimate_during_randomization_
  inference()` reassign `private$dead = private$des_obj_priv_int$dead`
  (lines ~147 and ~600 respectively) — post the y/y_L/y_R migration this
  field no longer exists and reads back `NULL`. Unlike the LWA Cox case,
  this doesn't segfault; it produces a genuine R error ("Clayton copula fit
  inputs must have matching row counts") from every randomization-family
  method (`compute_rand_two_sided_pval`, `compute_rand_confidence_interval`,
  `approximate_randomization_distribution_beta_hat_T`, and their bootstrap
  variants) on the standard 24-subject golden design used throughout this
  stretch — confirmed to reproduce identically on a from-scratch
  reconstruction of the pre-migration OneLik class (`InferenceSurvivalKK
  ClaytonCopulaOneLikLegacyRaw`, kept alive in the source file for
  component-harvesting purposes — see that migration's Progress note in
  "Full-Likelihood Estimators" above), so this is confirmed **not** a
  migration regression on either class. Worked around, not fixed, in
  `test-survival-kk-clayton-copula-onelik-migration-golden.R`: the five
  randomization-family labels get a dedicated comparison branch asserting
  both legacy and migrated throw the identical error message, instead of
  the generic status/value comparison every other label uses. The IVWC
  sibling's own golden (`test-survival-kk-clayton-ivwc-migration-golden.R`)
  does NOT hit this crash with its own design/label sequence — not
  investigated why, so it's unclear whether the IVWC class is actually
  affected under some other input or whether its combination logic happens
  to avoid the code path that requires matching row counts. The fix
  pattern is already known from the LWA Cox entry (re-derive `dead` via
  `as.numeric(!is.na(private$y))` instead of reading the defunct field) and
  is R-only (no C++ touch) — likely a small, low-risk fix, but not applied
  here to keep this OneLik migration's scope to the migration itself.
  Whoever picks this up should also grep the rest of the KK survival files
  (`inference_survival_KK_strat_cox.R`, `inference_survival_KK_lwa_cox*.R`)
  for the same `des_obj_priv_int$dead` pattern, since it may recur wherever
  a class's `compute_treatment_estimate_during_randomization_inference()`
  was written before the y/y_L/y_R migration.
  **Confirmed 2026-08-19: also present in `inference_survival_KK_weibull_
  frailty.R`'s `InferenceAbstractKKWeibullFrailtyOneLik` (line ~727,
  identical `private$dead = private$des_obj_priv_int$dead` reassignment).**
  Here it manifests as a silent `NA` from `compute_rand_two_sided_pval()`
  rather than a hard error or crash — verified identical on both the
  from-scratch `InferenceSurvivalKKWeibullFrailtyOneLikLegacyRaw` class and
  the migrated `InferenceSurvivalKKWeibullFrailtyOneLik` on the standard
  golden design, so no golden-test workaround was needed (unlike the
  Clayton instances above, both sides already silently agree). Not fixed,
  same scoping rationale. Grep both `inference_survival_KK_weibull_frailty.R`
  (the IVWC class in the same file may also have it, not checked) and any
  other KK survival file for `des_obj_priv_int\$dead` before assuming this
  list is exhaustive.
- [x] **Randomization-CI Wald-seed fallback silently lost by every migrated
  class: `is(inf_obj, "InferenceAsymp")` class-identity dispatch
  (found and fixed 2026-08-17).** `get_randomization_ci_seed_candidates()`
  (`inference_all_abstract_rand_ci.R`) computed its Wald/asymp seed CIs —
  and therefore `build_randomization_ci_search_bounds()`'s `fallback_ci` —
  only when `is(inf_obj, "InferenceAsymp")`. Every class migrated to
  `define_inference_class()` has `parent = Inference` with Wald arriving as
  a component, so the check was FALSE for all of them: where the
  pre-migration class returned the Wald-seeded fallback whenever the
  randomization-CI bisection could not converge (e.g. small `r`),
  the migrated class returned `c(NA, NA)` — a silent regression present
  since the very first migration, invisible to every legacy-vs-migrated
  golden whose fixture subclassed the already-migrated factory class (both
  sides equally broken). Caught by the
  `InferenceCountKKHurdlePoissonIVWC` golden, whose fixture rebuilt the
  real old ladder (`inherit = InferenceAsymp`): legacy finite, migrated
  NA. Fixed by replacing the class-identity check with a behavior probe
  (`is.function(inf_obj$compute_asymp_confidence_interval)`) — the calls
  inside are individually tryCatch-protected, so probing by method
  presence is safe for any class shape, and old-ladder classes keep
  identical behavior. Verified: the count-KK golden flipped to all-green;
  the full golden battery (simple mean-diff/Wilcox, IncidWald, CMH/
  ExtendedRobins, RiskDiff, KK Newcombe, KK Weibull marginal, partial-
  likelihood baseline, registry, mixin-contracts) all pass;
  `test-ci-rand.R` shows only its one pre-existing unrelated failure
  (the `FixedRerandomization` `type = "Zhang"` signature mismatch,
  documented earlier).
- [x] **Design-hierarchy-rework fallout sweep in the inference lane
  (2026-08-17).** After the design-hierarchy rework landed (commit
  `48bc5b83` and follow-ups: `Design -> DesignFixed`/`DesignSeqOneByOne`
  timing split, no blocking ancestor on non-blocking designs, new
  permutation/resampling streams), three inference-side breakages surfaced
  and were repaired:
  1. **`InferenceIncidCMH` non-blocking SE path**: called
     `des_obj$get_cmh_se_w_mat()` unconditionally, but that optional
     precompute lives on the blocking layer, which non-blocking designs
     (e.g. `DesignFixedBernoulli`, now `Design -> DesignFixed` with no
     blocking ancestor) no longer carry — "attempt to apply non-function".
     Fixed with an `is.function()` guard falling through to
     `draw_ws_according_to_design()`, in both the real class
     (`inference_incidence_cmh.R`) and the byte-for-byte legacy fixture in
     `test-incid-cmh-extended-robins-migration-golden.R` (the fixture pins
     migration behavior, not old-design-hierarchy behavior; without the
     guard it errored on the new designs for reasons unrelated to the
     migration under test). Golden file fully green again.
  2. **Stale RNG-stream goldens re-recorded** in
     `test-simple-mean-difference-migration-golden.R` and
     `test-simple-wilcox-migration-golden.R`: the rework changed the
     permutation/resampling streams, so every RNG-dependent golden
     (randomization/bootstrap/randomization-bootstrap distributions and
     derived CIs) drifted. **Verified correct before re-recording**: the
     new simple-mean-diff randomization values are bit-identical to
     hand-computed \eqn{\bar y_T - \bar y_C} over the exact permutations
     drawn under the same seed, and the new simple-Wilcox randomization
     values are bit-identical to front-door `compute_estimate()`
     recomputation on the same permuted assignments — statistic unchanged,
     stream only. Every deterministic golden (estimates, jackknife
     estimate/SE/CI/p-value, pooled/Wilcox asymptotic CIs and p-values, KK
     bootstrap distribution/CI) was confirmed unchanged to the last digit,
     pinning the drift to RNG-order alone.
  3. **All-NA Bayesian-bootstrap / randomization goldens replaced with the
     correct finite values**: several baked expectations
     (`rep(NA_real_, 9L)` distributions, NA CIs/p-values) had recorded the
     pre-2026-08-13 lazy-component/clone-bug era, when those paths were
     silently broken for migrated classes. The finite, estimate-centered
     values are the fixed behavior (verified at B=200: 200/200 finite,
     mean ≈ estimate, for both mean-diff machines; KK randomization 9/9
     finite). Both files carry header notes explaining the re-record and
     its verification so the next drift is diagnosed faster.
  Post-sweep verification: `test-simple-mean-difference-migration-golden.R`,
  `test-simple-wilcox-migration-golden.R`,
  `test-incid-cmh-extended-robins-migration-golden.R`,
  `test-incid-wald-migration-golden.R`,
  `test-incid-risk-diff-migration-golden.R`,
  `test-exact-incidence-migration-baseline.R`, and
  `test-quasi-robust-migration-baseline.R` are **all fully green**. Still
  open from the same fallout family (tracked separately):
  `InferenceSurvivalStratCoxPHRegr`'s NULL bootstrap-machinery privates
  (diagnosed under the Slow-wrapper entry above) and the two reverted
  ordinal classes failing `test-full-likelihood-migration-baseline.R`'s
  migrated-classes assertions.
- [x] **NA-y subset-clone bootstrap hang: slow-path
  `bootstrap_subset_inference()` fed raw NA-holed design `y` into survival
  estimators, hanging C++ forever (2026-08-17).** Found while running the
  newly-gated exhaustive reused-worker survival sweep for the Slow-wrapper
  closure above — the sweep "timing out" was actually this hang. Root
  cause, a missed spot in the y/y_L/y_R rework:
  `bootstrap_subset_inference()` (`inference_all_abstract_non_param_boot.R`)
  set `sub_inf_priv$y = sub_des_priv$y`, i.e. the subset of the **design's
  raw `y`** — which post-migration holds `NA` for every censored subject —
  while the parent inference object's own `private$y` was resolved by
  `Inference$initialize()` to `get_effective_time()` (censoring time in
  place of `NA`) for right-censored-only classes. The rework fixed the
  `dead` line immediately below the same way (with its TODO-1 comment) but
  left the `y` line reading from the design. Every slow-path (non-reusable-
  worker) bootstrap replicate of every survival class therefore ran its
  estimator on NA event times; `InferenceSurvivalKMDiff`'s C++ kernel
  loops forever on NA input (uninterruptible — `setTimeLimit()` never
  fires), hanging the whole generic bootstrap. Reproduced minimally:
  `compute_estimate()` on an instance whose `private$y` was manually given
  the design's raw NA-holed `y` hangs identically, while the same instance
  with effective times returns instantly. **Fix:** subset `private$y` (and
  `y_L`/`y_R`, which `duplicate()` had been leaving at the original full
  length) from the source Inference's own already-resolved vectors,
  mirroring the `dead` line — the design-side `sub_des_priv$y` stays raw,
  matching real design storage. Verified: `InferenceSurvivalKMDiff`/
  `CoxPHRegr`/`LogRank` fast-vs-slow B=3 comparisons went from
  infinite-hang to 0.1–1.2s each with **bit-identical** results; the full
  exhaustive asymp sweep completes in 13.9s; and the migration golden
  tests (`test-incid-wald-…`, `test-incid-risk-diff-…`) plus
  `test-inference-class-registry.R` all still pass (a same-hour
  `get_standard_error`-is-NULL failure in the CMH golden was verified via
  a single-file stash to reproduce identically **without** this fix —
  concurrent-session component-machinery drift, not this change).
  **Follow-up owed (C++ hardening, separate):** the KM kernel should
  reject NA event times with an error instead of looping — this fix
  removes the only in-package path that fed it NAs, but the kernel remains
  a hang risk for any future caller.
  **Hardening done 2026-08-17:** every entry point in
  `fast_survival_stats.cpp` now rejects NA/NaN event times up front via a
  shared file-local `any_nan_time()` helper (with a comment documenting the
  hang mechanism): the four Rcpp entry points
  (`get_survival_stat_for_group`, `get_survival_stat_diff`,
  `get_restricted_mean_se_for_group`, and — transitively through the
  group call — `get_restricted_mean_se_diff`) and both BRT kernels
  (`compute_survival_stat_diff_rand_bootstrap_parallel_cpp`/`_serial_cpp`)
  `Rcpp::stop()` with a clear message; the portable `EDI_CORE_ONLY`-safe
  `get_survival_stat_for_group_result()` throws `std::invalid_argument`
  (Rcpp converts it at the `.Call` boundary, pybind11 translates it for
  the Python TU); and the OpenMP-inline `km_stat_inline()` returns
  `NA_REAL` per replicate (throwing inside a parallel region is not an
  option), backstopping NaN introduced via `noise_mat` after the
  kernels' pre-loop `y0` guard. Verified two ways without touching the
  shared `EDI.so`: (a) a standalone `EDI_CORE_ONLY` g++ build of the
  translation unit plus a test harness — finite input still yields the
  correct survfit-matching median (3.5 on all-events 1..6) and NaN input
  throws instead of hanging, for both the group and diff functions; (b) a
  full `-fsyntax-only` compile of the Rcpp (non-core) path against the
  real R/Rcpp/RcppEigen headers. R-level regression test added as
  `test-survival-kernel-na-guard.R` (all six R-facing entry points error
  on NA; finite-input sanity checks) — its header notes that against a
  stale pre-guard `EDI.so` the error-expectation cases hang rather than
  fail, so a hang on that file means "recompile", not "regression".
- [x] **Reused-worker sweep test files trimmed and gated for push-hook/CI
  runtime (2026-08-17, user-directed).**
  `test-bootstrap-reused-worker-asymp-families.R` was the slowest file in
  the suite (>10 minutes; it exceeded a 900s budget even alone) and its
  sibling `test-bootstrap-reused-worker-families.R` shared the same
  structure. Changes to both: (a) each `Slow*` fixture class was defined
  **twice back-to-back** (identical bodies — dead code, most likely a
  mechanical concatenation from repeated migration passes) — deduplicated;
  (b) 12 of 33 (asymp) and 2 (sibling) fast-vs-slow comparisons were exact
  duplicates of the immediately preceding comparison with only a different
  seed — dropped, since one seeded bit-identical comparison per class/design
  pair already proves the reused-worker path; (c) bootstrap replicates
  reduced (`B = 5L`/`11L` → `3L`): replicate 1 exercises worker creation and
  replicates 2-3 exercise worker *reuse* (where the state-staleness bug
  family lives), with per-replicate bit-identical equality still asserted;
  (d) `expect_*(inherits(Cls$new(des), ...))` class-identity assertions each
  paid a full model fit for an ancestry question — replaced with a
  `generator_inherits()` R6-generator-chain walk (no construction, no fit),
  including the always-on count-likelihood ancestry-invariant block in the
  sibling file, which no longer needs a design at all; (e) the exhaustive
  per-family sweeps in both files are now gated behind
  **`EDI_EXHAUSTIVE_WORKER_TESTS=true`** (intended for nightly/pre-release
  runs or after touching the worker machinery) — on default push-hook/CI
  runs they skip, and a new always-on smoke test in the asymp file
  (`InferenceContinLin` + `InferenceIncidRiskDiff`, cheap OLS-family C++
  paths, n = 30, B = 3) keeps the shared reused-worker mechanism itself
  covered on every run. Full end-to-end timing of the gated-off default run
  was repeatedly interrupted by a concurrent session's in-flight
  design-factory rework breaking package load — re-verify the default run
  is seconds-fast once the tree stabilizes.
- [x] **Fix the shared bootstrap-subsetting `dead`-propagation bug.** Found
  during the `InferenceCustomAsymp` migration: the shared
  `get_analysis_data()`/bootstrap-subsetting plumbing in
  `inference_all_abstract_non_param_boot.R` does not propagate the inference
  object's own `private$dead` (from `get_effective_dead()`) into resampled
  worker/subset clones — only the design's raw (unpopulated for non-survival
  responses) private `dead` field — so any class whose
  `fit()`/`compute_estimate()` calls the public `get_analysis_data()` during
  bootstrap resampling gets a `dead=NULL` column mismatch. An attempted fix
  broke `test-simple-mean-difference-migration-golden.R`/
  `test-bootstrap-reused-worker-families.R` and was reverted; needs its own
  scoped fix plus a full regression pass, coordinated with the in-flight
  `y`/`y_L`/`y_R` rework that owns this plumbing.
  **Resolved as part of the completed y/y_L/y_R rework (verified
  2026-08-16, [[project-survival-api-rework]]):** confirmed via direct code
  inspection that both bootstrap-subsetting code paths in
  `inference_all_abstract_non_param_boot.R` now correctly propagate `dead`.
  The subset-clone path (`sub_inf_priv$dead = ...`, ~L1523-1527) has an
  explicit comment: "Design no longer stores a raw `dead` field (y/y_L/y_R
  migration...); `dead` lives only on `Inference` objects, so subset it from
  the source `Inference`'s own already-correct `private$dead` rather than
  round-tripping through Design" — exactly the fix this TODO called for. The
  reusable-design-backed-worker path (`create_bootstrap_worker_state()`/
  `load_bootstrap_sample_into_design_backed_worker()`, ~L1154-1207) derives
  `base_dead`/`w_priv$dead` from the design's raw `dead` when present, or
  from `!is.na(y)` (matching `Design$get_effective_dead()`) when not, and
  sets `w_priv$dead` directly on the worker `Inference` object's own private
  env, not just the nested design clone. Did not re-run the full regression
  pass named in the original note
  (`test-simple-mean-difference-migration-golden.R`/
  `test-bootstrap-reused-worker-families.R`) myself — blocked by the same
  concurrent-session DLL desync noted elsewhere in this doc; this closure is
  based on code-level verification only, not a fresh test run.
- [x] **Add the owed silent-state-wipe source invariant/regression test.** From
  the `InferenceContinQuantileRegr` correction note: (a) config/state fields
  moved into `cached_values` are silently wiped by `duplicate()` on every
  worker clone; (b) bare-`NULL`-defaulted private fields in a factory host
  list are silently dropped by `combine_component_slot()`'s
  `utils::modifyList()` (no `keep.null = TRUE`). Both produce wrong numbers,
  not crashes. `fix_design_hierarchy.md`'s Source Invariant #15 already
  cites this test as "still owed" — write the Inference-side version here
  (the Design-side twin is tracked in that plan's Follow-Ups section).
  **Fixed 2026-08-16:** `combine_component_slot()` now preserves explicit
  `NULL` declared lazy-component and host state with `keep.null = TRUE` (while
  still filtering inherited legacy root fields from eager harvested sources).
  The regression uses
  a normally locked external subclass to prove constructor state assignment
  works, then proves `duplicate()` preserves the owned field while clearing a
  same-named entry under `cached_values`. Both the source-overlay assembly
  probe and the locked-subclass/duplicate behavior probe pass.
- [x] **Fix the lazy-component/`clone()` staleness framework bug.** From the
  `InferenceIncidGCompAbstract` entry: `install_lazy_inference_component()`'s
  `.__loaded_lazy_components` marker and the already-`self`/`private`-bound
  installed function values both survive R6 `clone()` (used by `duplicate()`
  for every bootstrap/randomization worker), so a worker clone of any class
  whose `initialize`/`compute_estimate` is lazily loaded silently keeps
  operating on the original object's data. Fix via option (a) (`duplicate()`
  resets the marker and re-stubs the installed names) or (b)
  (`install_lazy_inference_component()` verifies bound-`self` identity
  instead of trusting the marker), then run a full regression pass — this is
  shared machinery under every `Inference*` subclass.
  **Confirmed broader than originally scoped**, during the
  `InferenceSurvivalGehanWilcox` migration: it also breaks the
  reusable-bootstrap-worker path for the `BayesianBootstrap` component (any
  class composing `BayesianBootstrap` + `Wald`, which is the standard
  no-likelihood template used throughout this migration). Symptom:
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()` /
  `compute_bayesian_bootstrap_confidence_interval()` /
  `compute_bayesian_bootstrap_two_sided_pval()` return all-`NA` distributions
  with every replicate erroring `"No Bayesian-bootstrap context is installed
  on this inference object."`, and `compute_rand_two_sided_pval()` silently
  returns `NA` (same root cause via the randomization-worker path). Root
  cause: `private$bayesian_bootstrap_sample_weights()` (a lazy
  `BayesianBootstrap` private method) is called on the *original* object
  before `create_bootstrap_worker_state()` clones it, so
  `install_lazy_inference_component()` binds the real
  `expand_subject_or_block_weights_to_row_weights` implementation's closure
  to the *original* object's `self`/`private` (`method_env = parent.frame()`
  at install time); the clone's own `current_bayesian_bootstrap_context`
  field (set directly via `worker_priv$current_bayesian_bootstrap_context =
  draw$context`) is then invisible to that stale closure, which reads the
  original's (always-`NULL`) context instead. Reproduced identically on
  `InferenceOrdinalJonckheereTerpstraTest` (migrated and marked complete
  earlier in this same effort), and confirmed absent on a still-unmigrated
  old-ladder class (`InferenceIncidLogRegr`), proving this is a regression
  from the shallow-hierarchy/lazy-loading architecture itself, not from any
  single class's migration. Confirmed NOT a correctness bug in
  `InferenceSurvivalGehanWilcox`'s own bootstrap-weight arithmetic: calling
  `compute_estimate_with_bootstrap_weights()` directly on the original
  object (context set manually, no clone involved) returns the correct
  estimate. **Every class migrated in this session that composes
  `BayesianBootstrap` should be assumed to have a silently-broken Bayesian
  bootstrap CI/p-value fallback and randomization p-value until this is
  fixed** — none of this session's "bootstrap replicates finite" smoke tests
  exercised the reusable-worker code path via the public
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()` /
  `compute_rand_two_sided_pval()` entry points specifically, so this may
  have been present (and unnoticed) since the very first migrated class.
  **Fixed 2026-08-13** via option (a): added
  `edi_rebind_lazy_components_after_clone(i)` to `mixin_contracts.R`, called
  from the one shared base `duplicate()` in `inference_all_abstract.R`
  right after `i = self$clone()` (every `duplicate()` override in the
  KK-family files delegates to `super$duplicate()`, so this single call site
  covers all of them — verified via `grep -rn "\$clone("` that no other code
  path clones an `Inference` object directly). For each component name in
  the clone's (copied-by-clone) `.__loaded_lazy_components` marker, walks
  `EDI_COMPONENT_SPECS[[component_name]]$provides_public_methods` /
  `provides_private_methods` and re-points `environment(fn)` from the stale
  original object's `.__enclos_env__` to the clone's own
  `i$.__enclos_env__` (the same environment R6 itself uses to correctly
  rebind class-generator-defined methods on clone) for every entry that is
  currently a real function; `owns_state` entries are left untouched since
  `clone()` already copies their current values correctly. Verified: the
  `debug = TRUE` replicate-level error `"No Bayesian-bootstrap context is
  installed on this inference object."` is gone for both
  `InferenceSurvivalGehanWilcox` and `InferenceOrdinalJonckheereTerpstraTest`
  (all replicates now finite with real variation); the full
  `InferenceSurvivalGehanWilcox` smoke test now shows finite, sane
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()`,
  `compute_bayesian_bootstrap_confidence_interval()`,
  `compute_bayesian_bootstrap_two_sided_pval()`, and
  `compute_rand_two_sided_pval()` (previously all-`NA`/broken). Regression
  check: `test-mixin-contracts.R` 1280/1280 pass,
  `test-inference-class-registry.R` clean, `test-gehan-wilcox-fused-
  martingale.R` and `test-logrank-gehan-wilcox-general-censoring.R` show
  only their pre-existing unrelated failures (confirmed identical
  before/after this fix via `git stash` on just the two changed files), and
  `test-ci-rand.R` shows only the same 2 pre-existing unrelated failures
  already documented under the `InferencePropGCompMeanDiff` entry above —
  no new failures anywhere.
- [x] **Redo the reverted `InferenceIncidGCompRiskDiff`/`RiskRatio` migration**
  now that the clone/lazy-loading bug above is fixed. **Done 2026-08-14** —
  see the completed `InferenceIncidGCompAbstract` entry under "Asymptotic
  (Wald) No-Likelihood Migration" above for the full writeup (also found and
  fixed a second, related lazy-component marker bug along the way).
- [x] **Sweep and fix the remaining locked-binding failures.** Three distinct
  sightings are recorded in `[x]` entries, all in the same root-cause family
  as the `IncidenceGComputation` missing-`owns_state` fix (non-function
  component state misclassified as methods and permanently locked by the
  lazy-stub swap's `lockBinding` preservation): `InferenceOrdinalAdjCatLogitRegr`
  (fails in `test-design-inference.R`), the full-likelihood
  `inference_all_abstract_asymp_lik_std_mod_cache.R` family (fails in
  `test-asymp-inference-paths.R`), and an unnamed class's locked-binding
  failure in `test-ci-rand.R`. Audit every registered component for missing
  `owns_state` declarations and fix each failing class. Related sighting
  (2026-08-14, different symptom, same missing-component-method family as the
  Cox TODO-13 gap in `interval_censored_survival_response.md`):
  `InferenceAllSimpleWilcox` currently lacks
  `compute_rand_bootstrap_confidence_interval` entirely
  (`is.function()` is `FALSE`; its `compute_rand_bootstrap_two_sided_pval`
  sibling exists), failing both tests in
  `test-brt-smoothed-wilcox-ci-perf.R` with `attempt to apply non-function`
  — include it in this sweep. Second corroborating sighting (2026-08-14,
  same `InferenceOrdinalAdjCatLogitRegr`/`best_Xmm_colnames` root cause as
  above, different symptom): `test-bayesian-bootstrap.R`'s "ordinal
  likelihood-gap weighted hooks" test fails with `cannot coerce type
  'closure' to vector of type 'any'` from `intersect(private$
  best_Xmm_colnames, colnames(X_fit))` — here the field is read (not
  assigned) while it is still an un-swapped lazy-stub *function*, rather
  than the locked-binding *assignment* crash `test-design-inference.R` hits;
  same missing-`owns_state` fix should resolve both.
  **Progress 2026-08-16:** audited the current source metadata against every
  lazy component's actual non-function private fields; all ownership sets now
  match, including `OrdinalAdjacentCategoryLikelihood$best_Xmm_colnames`.
  Fixed the remaining factory-level explicit-`NULL` loss in
  `combine_component_slot()` and restored
  `compute_rand_bootstrap_confidence_interval` on both Wilcoxon hosts by
  composing `RandomizationBootstrapCI` (with migration snapshots updated).
  Source-overlay assembly confirms both generators expose the CI method. The
  checkbox remains open pending the named full runtime files, which are still
  blocked before execution by the unrelated `CoxData` generated-wrapper
  compile failure.
  **Closed 2026-08-17:** the `CoxData` compile blocker cleared (confirmed:
  `src/RcppExports.cpp` no longer references `CoxData`; a fresh
  `pkgload::load_all(compile = FALSE)` now loads cleanly with no DLL
  desync). Ran every named runtime file: `test-design-inference.R`,
  `test-asymp-inference-paths.R`, `test-ci-rand.R`,
  `test-brt-smoothed-wilcox-ci-perf.R`, and `test-bayesian-bootstrap.R`
  (plus `test-mixin-contracts.R` and `test-inference-class-registry.R` for
  full coverage of the shared lazy-component machinery this bug family
  lives in) — grepped every failure across all seven files and confirmed
  **zero** contain a locked-binding/"cannot add bindings to a locked
  environment" error or the ordinal-hardening coercion error. Every
  remaining failure in those runs is a distinct, already-documented, or
  clearly unrelated issue: (a) `test-mixin-contracts.R`'s one failure is the
  pre-existing `testthat` 3.3.2 `expect_length(..., info = ...)`
  version-mismatch already noted elsewhere in this doc; (b)
  `test-bayesian-bootstrap.R`'s one failure is a sandboxed-environment
  `mirai`/`nanonext` dispatcher "Permission denied" trying to launch a
  background process — environmental, not a package bug;
  (c) `test-design-inference.R`'s three failures ("ordinal hardening drops
  QR-rank") and `test-asymp-inference-paths.R`'s three failures ("Ordinal
  Asymp paths": `super$compute_asymp_two_sided_pval()` erroring
  "Asymptotic inference is not implemented for this inference class") and
  `test-ci-rand.R`'s one failure (`FixedRerandomization` `type = "Zhang"`
  dispatch: "unused argument") are all new/different symptoms, unrelated to
  locked bindings — plausibly fallout from the concurrent full-likelihood/KK
  migration effort actively in progress in this shared repo; not
  investigated further here as out of scope for this specific TODO, but
  flagged for whoever owns that migration work.
  `test-inference-class-registry.R` and `test-brt-smoothed-wilcox-ci-perf.R`
  are both fully clean (the latter confirms the
  `compute_rand_bootstrap_confidence_interval` restoration from the prior
  progress note actually works end-to-end).
  **Second occurrence found and fixed 2026-08-21** (same missing-`owns_state`
  bug family, different field than the `best_Xmm_colnames` one this box
  originally closed): `OrdinalAdjacentCategoryLikelihood`'s `cached_mod` was
  never declared in `owns_state`/`provides_private_methods` -- `generate_mod()`'s
  `private$cached_mod = model_output` assignment throws "cannot add
  bindings to a locked environment" for any `R6::R6Class(inherit =
  InferenceOrdinalAdjCatLogitRegr, ...)` locked subclass (reproduced
  directly). Root cause identical to every prior `cached_mod` fix this
  session: never declared in the class's own source (created dynamically),
  and `Wald`'s own `cached_mod = NULL` doesn't survive eager-component
  composition. Fixed by declaring `cached_mod = NULL` explicitly in the
  class's own private list (so the harvester captures it) and adding it to
  `OrdinalAdjacentCategoryLikelihood`'s `owns_state`/`provides_private_methods`
  in `contracts_mixins.R`. Confirmed the un-fixed pre-2026-08-21 state
  reproduces the crash; confirmed the fix resolves it with byte-identical
  unlocked-instance behavior; `test-ordinal-adj-cat-logit-migration-golden.R`/
  `test-full-likelihood-migration-baseline.R`/`test-mixin-contracts.R`/
  `test-static-cleanup-guardrails.R` green. Note: `test-design-inference.R`'s
  "ordinal hardening drops QR-rank" failures for `kk_adj_hardened`
  (`InferenceOrdinalKKCondAdjCatLogitRegr`, a *different*, still-unmigrated
  class) remain -- confirmed unaffected by and unrelated to this fix.
- [x] **Capability detection for unregistered `Inference` subclasses.** Moved
  here from `fix_design_hierarchy.md`'s `.valid_inference_types()` fix note,
  which found it and declared it out of scope for that plan: ad-hoc
  subclasses of migrated classes that are not in
  `EDI_INFERENCE_CLASS_REGISTRY` (only the package namespace is scanned at
  populate time — e.g. `test-simulation-framework.R`'s
  `InferenceAlwaysFailsPval`) lose capability detection entirely, and
  `.supports_inference_capability()`'s `fallback_class` check also fails
  post-migration because the old base names are gone from the inheritance
  chain. Fix candidates: walk `get_inherit()` up to the nearest registered
  ancestor and inherit its capabilities, or expose a registration hook for
  external/test subclasses. Also affects the external-extension contract in
  `extending-edi-r6.md`, which documents this gap for users.
  **Fixed 2026-08-16:** `Inference$capabilities()` now walks `class(self)` and
  inherits capabilities from the nearest registered R6 ancestor. Added a
  regression test using `InferenceAlwaysFailsPval`, plus a live source-overlay
  probe with an unregistered leaf and synthetic registered parent.
- [x] **Validate the `class(self)`-name-keyed dispatch tables in `globals.R`
  against live generators.** The `InferencePropGCompMeanDiff` migration found
  `inference_class_overrides` still keyed on a deleted class name
  (`"InferencePropGCompAbstract$" = "irls"`), which would have silently
  selected the wrong optimizer once the class was gone. Add a structural test
  that every regex key in `inference_class_overrides` (and any sibling
  name-keyed table in `globals.R`, e.g. the cold-start dispatch policy)
  matches at least one live generator, so future renames/deletions during
  this migration fail loudly instead of silently falling through to
  defaults.
  **Fixed 2026-08-16:** added a structural test that enumerates live canonical
  inference generators and validates every regex in the bootstrap,
  optimization, cold-start, per-operation warm-start, and design-scoped
  bootstrap override tables. The source-overlay run passes 246 assertions.
- [x] **`InferenceCountQuasiPoisson` never composes `BayesianBootstrap`, so
  its Bayesian-bootstrap weighted-fit hook is dead code that always errors.**
  Found 2026-08-14 in `test-bayesian-bootstrap.R` ("additional near-term
  weighted hooks..."): `inf_qp$compute_estimate_with_bootstrap_weights(...)`
  fails with `attempt to apply non-function`. Root cause:
  `InferenceCountQuasiPoisson` (`inference_count_quasipoisson.R`) composes
  `components = c("Wald", "CountCompositeLikelihood")` only, but its own
  `compute_estimate_with_bootstrap_weights` body calls
  `private$expand_subject_or_block_weights_to_row_weights(...)`, a method
  that only exists via the `BayesianBootstrap` component — never composed,
  so the private slot is simply absent (`NULL`), not a lazy stub. This means
  Bayesian bootstrap has never worked for this class since its migration to
  `define_inference_class`, on any input, silently (a construction-time or
  eager-load error would have been caught immediately; this only surfaces on
  first actual bootstrap call). **Fixed 2026-08-15**: added `BayesianBootstrap`
  to `components`, reordered to `c("CountCompositeLikelihood",
  "BayesianBootstrap", "Wald")` (`Wald` listed last so it wins the
  jackknife-triplet collision against the newly-transitively-pulled-in
  `NonparametricBootstrap`, matching this session's established pattern),
  added the standard `compute_rand_two_sided_pval` alias (newly available
  now that `RandomizationTest` is transitively composed — previously absent
  entirely, not even as a stub, since nothing in the old `components` set
  provided it), and declared the resulting collisions in `overrides`
  (`compute_rand_two_sided_pval` public; the jackknife triplet and the
  `create_bootstrap_worker_state`/`load_bootstrap_sample_into_worker`/
  `compute_bootstrap_worker_estimate` bootstrap-worker-wiring set private).
  **Same bug independently found and fixed in `InferenceCountRobustPoisson`**
  (`inference_count_robust_poisson.R`) while regression-testing this fix —
  identical root cause (`components = c("Wald", "CountCompositeLikelihood",
  "RobustSandwich")`, no `BayesianBootstrap`), identical fix shape
  (reordered to `c("CountCompositeLikelihood", "RobustSandwich",
  "BayesianBootstrap", "Wald")`, same alias and overrides added). Verified
  both classes numerically: `compute_estimate_with_bootstrap_weights()` with
  equal weights now matches `compute_estimate()` exactly (previously errored
  unconditionally), `approximate_bayesian_bootstrap_distribution_beta_hat_T()`
  25/25 finite with real variation, `compute_rand_two_sided_pval()` returns
  a finite p-value. Both `Slow*` bootstrap-worker test wrappers
  (`SlowInferenceCountQuasiPoisson`, `SlowInferenceCountRobustPoisson` in
  `test-bootstrap-reused-worker-families.R`) needed the standard
  `lock_objects = FALSE` fix, since composing a lazy component
  (`BayesianBootstrap`) for the first time newly exposed them to the same
  lazy-install-needs-an-unlocked-environment requirement every other
  `BayesianBootstrap`-composing class in this effort has needed. Tests:
  `test-mixin-contracts.R`, `test-inference-class-registry.R`,
  `test-quasi-robust-migration-baseline.R` fully clean; `test-bayesian-
  bootstrap.R` and `test-bootstrap-reused-worker-families.R` show only
  pre-existing unrelated failures confirmed via `git stash` on the changed
  files (the `InferenceOrdinalAdjCatLogitRegr`/`best_Xmm_colnames` bug
  documented above, and a stale `inherits(x, "InferenceCountCompositeLikelihood")`
  check in `test-bootstrap-reused-worker-families.R` that predates today's
  fix — both classes were already migrated to `define_inference_class(inherit
  = Inference, ...)` earlier in this effort, so the old R6-inheritance-chain
  assertion has been failing since that migration, not from today's change).
- [x] **`weighted_gcomp_fit`'s warm-start chaining produces different
  results than fresh per-replicate fits, for both KK and non-KK
  g-computation classes.** Found 2026-08-14 while regression-testing the
  `InferenceIncidGCompRiskDiff`/`RiskRatio` migration: `test-gcomp-boot-
  warm-start-chaining.R`'s "non-KK gcomp warm-start chaining matches
  independent fits via `weighted_gcomp_fit`" test fails — 8 of 15 bootstrap
  replicates differ from an independent (fresh-object, no warm-start
  carryover) fit by up to 0.127, far outside the `1e-6` tolerance the test
  asserts. **Resolved 2026-08-15/16, in two parts, after a full
  investigation and a mid-course correction prompted by the user asking
  "shouldn't the parametric bootstrap use `weighted_gcomp_fit`/`compute_
  weighted_gcomp_estimate`?"** — the first pass here had wrongly concluded
  this was dead-code/test-only and not worth fixing; that conclusion was
  wrong, corrected below.
  - **Part 1 — root cause and the real fix (implemented `create_bootstrap_
    worker_state`/etc. for gcomp, not just a defensive patch).**
    `gcomp_boot_beta`'s entire purpose is to warm-start `weighted_gcomp_fit`
    across repeated calls — i.e. it is a **reusable-bootstrap-worker**
    optimization (avoid cold-starting IRLS on every replicate), the same
    pattern `Wald`-composing classes get via `supports_reusable_bootstrap_
    worker() = TRUE` + `create_bootstrap_worker_state()`/`load_bootstrap_
    sample_into_worker()`/`compute_bootstrap_worker_estimate()`. No
    g-computation class (`InferenceIncidGCompRiskDiff`/`RiskRatio`, the KK
    variant, `InferencePropGCompMeanDiff`'s `supports_reusable_bootstrap_
    worker` aside) had ever implemented these — they inherited
    `NonparametricBootstrap`'s default `FALSE`, so `gcomp_boot_beta` never
    persisted across replicates in any real bootstrap call (every
    replicate got a fresh clone from `inf_template`, confirmed by tracing
    both the debug and non-debug branches of `approximate_bayesian_
    bootstrap_distribution_beta_hat_T()` in `inference_all_abstract_
    bayesian_bootstrap.R`). The warm-start machinery was real but entirely
    unwired. Implemented it for `InferenceIncidGCompRiskDiff`/`RiskRatio`
    in `inference_incidence_gcomp.R`: a shared `incidence_gcomp_worker_
    overrides` list providing `supports_reusable_bootstrap_worker() =
    TRUE`, `create_bootstrap_worker_state() = private$create_design_
    backed_bootstrap_worker_state()`, `load_bootstrap_sample_into_worker()
    = private$load_bootstrap_sample_into_design_backed_worker(...)`,
    `compute_bootstrap_worker_estimate() = private$compute_bootstrap_
    worker_estimate_via_compute_treatment_estimate(...)` — copied directly
    (not aliased via `Wald`, for the same `get_standard_error`-clash reason
    documented above) from `Wald`'s own identical 4-method pattern, reusing
    generic helpers already provided by the transitively-composed
    `NonparametricBootstrap` component. Declared the resulting 4-name
    collision in `overrides$private` for both classes. Verified a ~3.8x
    bootstrap-distribution speedup (`B = 200`, `n = 200`: 4.4s -> 1.1s) and,
    critically, **bit-for-bit correctness**: driving the exact same 15
    weight draws `test-gcomp-boot-warm-start-chaining.R` uses through the
    real worker mechanism (`create_bootstrap_worker_state()` +
    `compute_estimate_with_bootstrap_weights()`, with `private$active_
    resampling_operation` set as the real entry point does) matched the
    fresh-object cold-start reference to `7.9e-11` for all 15 replicates —
    zero divergence, refuting the original "genuine numeric-correctness
    gap" theory entirely.
  - **Part 2 — what the original divergence actually was.** The failing
    test called the private `weighted_gcomp_effects_from_row_weights()`/
    `weighted_gcomp_fit()` methods directly, repeatedly, on one persistent
    object — bypassing `private$active_resampling_operation` entirely
    (never set outside the real public entry points). `set_fit_warm_
    start()`'s "resampling fits must not replace the primary MLE warm
    state" guard (`inference_all_abstract.R`) is gated on that flag, so
    with it unset, every replicate's fit — including a column-dropped one
    — silently overwrote the *primary* warm-start cache (`private$fit_
    warm_start`/`fit_warm_start_fisher`), not just the intentional
    `gcomp_boot_beta` chaining. That extra, unintended state leak was
    enough to bias a later replicate's IRLS convergence into a different
    rank-deficient-column-dropping outcome than a cold start would reach —
    a real divergence, but one only that specific direct-private-call
    pattern (which no real code path uses) could trigger. Rewrote the
    failing test in `test-gcomp-boot-warm-start-chaining.R` to drive the
    real worker mechanism instead (matching how `approximate_bayesian_
    bootstrap_distribution_beta_hat_T()` actually operates), with a comment
    explaining why the old direct-call pattern was invalid; all 7 tests in
    that file now pass. Left the two KK-variant tests (which use
    `compute_weighted_gcomp_estimate`, a simpler implementation with no
    QR-column-dropping retry loop, and were already passing) untouched —
    `InferenceIncidKKGCompAbstract` is still old-ladder and out of scope
    (see "KK And IVWC Estimators").
  - **Defensive hardening (belt-and-suspenders, applied but not the actual
    fix for the failing test).** Also changed `weighted_gcomp_fit()` in
    `inference_incidence_gcomp_abstract.R` and `inference_proportion_gcomp.R`
    so a column-dropped (reduced-design) fit's coefficients are never
    cached as the next replicate's warm start (`gcomp_boot_beta`/`fit_
    warm_start`) — only a fit against the full, undropped design is cached.
    This didn't change the failing test's outcome at all when tried in
    isolation (confirming Part 2, not this, was the real cause) but is a
    reasonable independent robustness improvement: it stops a reduced
    model from silently propagating forward as any future full-model
    call's starting point, for any caller, guarded or not.
  - Regression check: `test-mixin-contracts.R`, `test-inference-class-
    registry.R`, `test-gcomp-boot-warm-start-chaining.R` (all 7, previously
    1 failing), `test-gcomp-cache-readiness.R`, `test-bayesian-bootstrap.R`
    all fully clean; `test-bootstrap-reused-worker-asymp-families.R` shows
    only the two pre-existing, unrelated failures documented above
    (`InferenceOrdinalPropOddsRegr`/`InferenceSurvivalCoxPHRegr` Slow-
    wrapper gaps, entry below). `test-design-inference.R` and `test-full-
    likelihood-migration-baseline.R` could not be re-verified after this
    fix landed — an unrelated concurrent session's in-progress Cox work
    left `RcppExports.cpp` in a state that fails to compile (`'CoxData' was
    not declared in this scope`), blocking `pkgbuild::compile_dll()`
    resync; not touched, not my work. Both had already run clean (modulo
    already-documented pre-existing failures) in an earlier full pass
    before that breakage appeared.
- [x] **`InferenceOrdinalPropOddsRegr` and `InferenceSurvivalCoxPHRegr`
  Slow-wrapper test fixtures are missing `lock_objects = FALSE`.** Recorded
  as a recurring pre-existing failure across several `[x]` entries above
  (`InferenceSurvivalKMDiff`, `InferenceSurvivalLogRank`,
  `InferenceSurvivalRestrictedMeanDiff`, `InferenceIncidGCompAbstract`) —
  both classes were migrated to `define_inference_class` by the concurrent
  full-likelihood-migration effort, but their `Slow*` bootstrap-worker test
  wrappers in `test-bootstrap-reused-worker-asymp-families.R`
  (`SlowInferenceOrdinalPropOddsRegr` line ~309,
  `SlowInferenceSurvivalCoxPHRegr` line ~418) were never given
  `lock_objects = FALSE`, so `install_lazy_inference_component()` fails with
  `"cannot add bindings to a locked environment"` the first time either
  wrapper's overridden `supports_reusable_bootstrap_worker` forces the
  non-reusable-worker path through a lazy component. Same one-line fix
  applied to every other `Slow*` wrapper in this file throughout this
  effort (`SlowInferenceSurvivalGehanWilcox`,
  `SlowInferenceSurvivalKMDiff`, `SlowInferenceIncidGCompRiskDiff`, etc.) —
  left for the full-likelihood migration's own PR rather than fixed here,
  since both host classes are mid-flight under a different, concurrent
  session as of this writing.
  **Implementation added 2026-08-16:** the missing `lock_objects = FALSE`
  declarations are now present on both `Slow*` wrappers (including both
  duplicate Cox fixture definitions). The checkbox remains open until the
  focused runtime test can run. A broader fixture audit on 2026-08-16 found
  the same omission on 19 additional definitions; every one of the file's 34
  `SlowInference*` generators now explicitly uses `lock_objects = FALSE`.
  `test-slow-wrapper-lock-contract.R` source-scans every such R6 block so the
  locked-object default cannot silently return in future fixtures.
  The ordinal/proportion focused block passes all seven assertions against the
  current package. The Cox block gets past lazy-component installation without
  the former locked-environment error, but its bootstrap fits exceeded the
  bounded three-minute focused run, so this checkbox remains open pending the
  full numeric comparison.
  **Closed 2026-08-17.** Both focused runtime blocks now run end to end
  (via `EDI_EXHAUSTIVE_WORKER_TESTS=true`, after the reused-worker test
  files were trimmed/gated — see the Follow-Ups entry): the MLE/proportion
  block (containing `SlowInferenceOrdinalPropOddsRegr`) passes completely
  in 5.7s, and in the survival block every `Slow*` wrapper — including
  `SlowInferenceSurvivalCoxPHRegr` — constructs, lazily installs its
  components, and produces bit-identical fast-vs-slow bootstrap
  comparisons, with **zero** locked-binding/"cannot add bindings to a
  locked environment" errors anywhere. (The Cox block's earlier
  "exceeded the bounded three-minute run" turned out not to be slow Cox
  fits at all but an unrelated infinite C++ hang in the slow-path
  bootstrap machinery fed NA event times — found, fixed, and documented
  as its own Follow-Ups entry, "NA-y subset-clone bootstrap hang," the
  same day. After that fix the entire exhaustive sweep runs in 13.9s.)
  The one remaining error in the survival sweep is a different,
  precisely-diagnosed bug outside this item's scope:
  `InferenceSurvivalStratCoxPHRegr` (fast path and slow path alike, so
  not a wrapper problem) fails `approximate_bootstrap_distribution_
  beta_hat_T()` with "attempt to apply non-function" because roughly half
  its bootstrap-machinery private methods are literally `NULL` on a
  constructed instance (`assert_valid_bootstrap_type`,
  `get_cached_resampling_distribution`, `bootstrap_sample_indices`,
  `bootstrap_subset_inference`, `create_reusable_bootstrap_worker`,
  `check_bootstrap_replicate_deadline`, `compute_fast_bootstrap_distr`,
  `load_resampling_draw_into_worker`, `estimate_bootstrap_worker`,
  `store_cached_resampling_distribution` — verified by direct private-env
  introspection; `compute_estimate()` itself works, and plain
  `InferenceSurvivalCoxPHRegr` has every one of these as a real function
  and passes its comparisons). This is the TODO-13 "Cox's missing
  randomization/bootstrap component methods" family, in the in-flight
  Cox/full-likelihood migration's lane — left for that effort with this
  diagnosis.
  **StratCox fixed 2026-08-17 (lane picked up after the other session went
  inactive):** root cause was the factory call composing only
  `components = "StratifiedCoxPartialLikelihood"` — whose dependency chain
  (`-> CoxPartialLikelihood -> StandardModelCache -> LikelihoodTests`)
  never reaches the bootstrap layer — where plain
  `InferenceSurvivalCoxPHRegr` composes
  `c("BayesianBootstrap", "CoxPartialLikelihood")`. Fix mirrors plain Cox
  exactly: added `BayesianBootstrap` first (same load-bearing resolution
  ordering, so `StandardModelCache`'s Cox-aware
  `compute_treatment_estimate_during_randomization_inference()` wins),
  pinned `compute_rand_two_sided_pval` from `InferenceRand` (same traced
  `super$`-flattening rationale), and declared the same collision set —
  plus one StratCox-specific declaration the loud factory validation
  caught: the host's deliberate not-supported
  `compute_rand_confidence_interval` (log-hazard-ratio vs log-time-ratio
  scale mismatch) now collides with `RandomizationCI`'s generic inversion
  and must be declared so the host's `stop()` wins. Verified: 8 of the 10
  formerly-NULL privates are now functions and the remaining two
  (`store_cached_resampling_distribution`, `compute_fast_bootstrap_distr`)
  are NULL on plain Cox too (legitimately optional); `compute_estimate`
  unchanged (-0.1459273 on the diagnostic fixture); fast-vs-slow B=3
  bootstrap comparisons run and match bit-identically; Bayesian bootstrap
  finite; the designed rand-CI error message intact. **The exhaustive
  reused-worker sweep (`EDI_EXHAUSTIVE_WORKER_TESTS=true`) is now fully
  green for the first time — every class, 33.6s.**
  `test-partial-likelihood-migration-baseline.R`,
  `test-inference-class-registry.R`, and `test-mixin-contracts.R` all
  fully pass; remaining failures elsewhere (`test-design-inference.R`
  ordinal QR-hardening, ordinal/incidence parametric-bootstrap cases) are
  the pre-existing ordinal-lane items tracked separately.
- [x] **Make factory requirement validation traverse the full R6 ancestor
  chain.** Found 2026-08-16 while attempting to replace
  `InferenceOrdinalPairedSignTest`'s raw `KKPassThrough` splices with
  `define_inference_class(components = "KKPassThrough")`:
  `r6_inherited_public_names()` and `r6_inherited_private_names()` inspect only
  the immediate generator. With `InferenceAsympLik` as the parent, validation
  therefore falsely reports root-owned `duplicate` and `num_cores` as missing.
  **Fixed 2026-08-16:** both helpers now walk `get_inherit()` transitively,
  matching the already-correct design-factory implementation. The regression
  builds a root/middle/leaf-parent chain and verifies that an actual synthetic
  component's grandparent public-method, active-binding, private-method, and
  private-state requirements all pass factory validation. The attempted paired
  sign-test leaf edit remains reverted and can be retried independently.
- [x] **Relabel `InferenceContinRobustRegr`'s stale `robust_sandwich`
  behavior tag.** From the "Wire `RobustSandwich` into the continuous
  robust-regression path" investigation above: the static
  `EDI_QUASI_ROBUST_TARGETS`/`quasi_robust_behavior_manifest()` registry
  still tags this class with `behavior = "robust_sandwich"`, but the
  investigation confirmed its actual SE formula (`fast_robust_regression_
  cpp`'s sandwich-*free* Huber/Tukey M-estimator asymptotic variance) is not
  a sandwich estimator at all — a different concept that only shares the
  word "robust" with the `RobustSandwich` component used by
  `InferenceCountRobustPoisson`. Left as-is at the time since nothing
  currently cross-validates this tag against actual composed components
  (`test-quasi-robust-migration-baseline.R` only checks internal
  self-consistency), so it isn't causing a live bug — but it is a
  misleading label for anyone reading the manifest later. Relabel to
  something accurate (e.g. `"m_estimator_variance"` or similar) once
  someone is touching that registry for another reason, or add the
  cross-validation test that would force the question.
  **Fixed 2026-08-16:** relabeled the class to `m_estimator_variance`, updated
  its explanatory note and expected behavior groups, and added an assertion
  that it does not compose `RobustSandwich`. A source-overlay manifest probe
  confirms the class is no longer in the `robust_sandwich` group.
- [x] **`InferenceIncidWald`/`InferenceIncidCMH`/`InferenceIncidExtendedRobins`
  `randomization_pval` regression from uncommitted 2026-08-17 WIP — found
  2026-08-18, fixed 2026-08-18.** Root cause traced fully: an in-progress
  2026-08-17 WIP fixed `InferenceIncidRiskDiff`'s "attempt to apply
  non-function" crash by (a) changing `InferenceRandCI$compute_rand_two_
  sided_pval` (`inference_all_abstract_rand_ci.R`) to rebind a borrowed
  `InferenceRand` core function's environment to the current call instead of
  calling `super$...` (needed because a class composed via
  `define_inference_class()` that splices this method in as a raw copy has
  no real `InferenceRand` ancestor for `super$` to resolve against), and (b)
  switching `InferenceAllSimpleMeanDiff`'s own `compute_rand_two_sided_pval`
  pin from `InferenceRand` to `InferenceRandCI` (needed so incidence
  responses get Zhang exact-test dispatch instead of `InferenceRand`'s
  outright refusal). That second change fixed `InferenceAllSimpleMeanDiff`
  itself, and since this project's golden-fixture convention has legacy test
  generators **truly R6-inherit** `InferenceAllSimpleMeanDiff` (not copy its
  body), the legacy side of every affected golden picked up the corrected
  pin automatically and started producing real Zhang-dispatch values where
  it previously would have matched the (also-broken) migrated side. But
  `InferenceIncidWald`, `InferenceIncidCMH`, and `InferenceIncidExtendedRobins`
  don't inherit `InferenceAllSimpleMeanDiff` — each independently *composes*
  the identical `c("BayesianBootstrap", "Wald", "SimpleMeanDifference")` and
  had its own copy of the *old* `InferenceRand` pin, so all three silently
  regressed (`compute_rand_two_sided_pval()` started throwing "Randomization
  tests are not supported for incidence" wherever the corrected legacy path
  now takes the Zhang branch). `InferenceIncidExtendedRobins`'s own golden
  test doesn't happen to exercise a Zhang-eligible design, so it wasn't
  caught by its own suite — found only because it shares the identical bug
  pattern as the two confirmed-broken siblings, verified by R6 ancestor walk
  (`InferenceAllSimpleMeanDiff$get_inherit()` chain resolves `compute_rand_
  two_sided_pval` to itself, confirming the corrected `InferenceRandCI` pin
  is what legacy fixtures actually get). Fixed by pinning all three to
  `InferenceRandCI$public_methods$compute_rand_two_sided_pval`, matching
  `InferenceAllSimpleMeanDiff`'s already-corrected choice, with the
  reasoning documented inline at each site. Verified: both previously-failing
  goldens (`test-incid-wald-migration-golden.R`,
  `test-incid-cmh-extended-robins-migration-golden.R`) fully green; the full
  migration-golden suite (21 files) plus `test-mixin-contracts.R`,
  `test-inference-class-registry.R`, `test-static-cleanup-guardrails.R`,
  `test-exact-incidence-migration-baseline.R`, and
  `test-simulation-framework-advanced.R` (the original target of the
  2026-08-17 WIP, confirming that fix's own intent is undisturbed) all
  green. No other concrete class inherits from any of these three, so no
  further propagation needed.

### Discovery

- [x] Normalize design metadata in one helper. **Done 2026-08-16.** Extracted
  `InferenceSuite`'s private `.design_metadata()` into a standalone
  `normalize_inference_design_metadata(des_obj)` function in
  `inference_suite.R` (not a private method — usable later by the
  "Design-Side Discovery API" section's planned `Design$applicable_
  inference_class_names()` method, which explicitly depends on "the same
  normalized-design-metadata helper"). It now reports censoring as two
  independent axes — `any_censoring` and `has_general_censoring` — instead
  of the one flag the old private method had.
  Added `infer_inference_supports_general_censoring(generator)` to
  `inference_class_registry.R`, following the existing `infer_inference_*`
  helper family (`infer_inference_response_types`/`_likelihood_tier`/
  `_abstract`): walks the R6 ancestor chain to the nearest generator
  defining `supports_interval_or_left_censored_data` and invokes it
  directly. Safe without constructing an instance because every one of the
  7 current implementations (checked all of them) is a trivial, argument-
  less, `self`/`private`-free literal (`function() TRUE`/`function()
  FALSE`) — this reads the method's *declared return value*, not just
  whether it exists by name, so it isn't the private-method-name-*sniffing*
  pattern "Static Cleanup" bans elsewhere. Wired into
  `populate_inference_class_registry()` (computed per-class alongside
  `abstract`/`response_types`/`likelihood_tier`) and into
  `register_inference_class()`'s defaults (`FALSE`, matching `Inference`'s
  own base declaration) as a new `supports_general_censoring` metadata
  field.
  Rewired `InferenceSuite`'s `.class_compatibility_metadata`/`.is_
  compatible_with_design_metadata` to read `supports_general_censoring`
  from this metadata and exclude a class only when `design_meta$has_
  general_censoring && !class_meta$supports_general_censoring` — mirroring
  `Inference$initialize()`'s own construction-time gate exactly, per the
  "Design-Side Discovery API" section's own explicit instruction below.
  **Found and fixed a real, independent discovery bug in the process**: the
  code being replaced had a hardcoded `requires_uncensored` list
  (`InferenceSurvivalKMDiff`, `InferenceSurvivalLogRank`,
  `InferenceSurvivalRestrictedMeanDiff`, `InferenceSurvivalGehanWilcox`)
  excluded whenever `any_censoring` was `TRUE` — i.e. for *any* censored
  design, including plain right-censoring. All four of these classes are
  specifically built to handle right-censored survival data (that's their
  entire purpose) and were numerically verified against right-censored
  datasets earlier in this same migration effort; none of them should ever
  have been excluded for ordinary right-censoring. Confirmed via a direct
  smoke test: before this fix these four never appeared in `InferenceSuite$
  applicable_design_classes` for any design with `any_censoring() ==
  TRUE`; after the fix, all four correctly appear for a right-censored-only
  design, and are only excluded when the design actually has left-/
  interval-censored subjects (`has_general_censoring() == TRUE`) *and* the
  specific class's own `supports_interval_or_left_censored_data()` is
  `FALSE` — confirmed two other survival classes
  (`InferenceSurvivalDepCensTransformRegr`, `InferenceSurvivalStratCoxPHRegr`)
  correctly drop out under general censoring while the five that declare
  support (the four above plus `InferenceSurvivalCoxPHRegr`) remain listed.
  Regression check: `test-inference-class-registry.R` fully clean;
  `test-inference-suite-discovery.R` shows only 2 pre-existing unrelated
  failures (`InferenceAllSimpleMeanDiff`/`InferenceAllKKMeanDiffIVWC`
  expected in `applicable_design_classes` but aren't — confirmed both are
  simply absent from `NAMESPACE` entirely right now, an unrelated export-
  state gap from other in-flight work, nothing this change touched);
  `test-mixin-contracts.R` shows only the same pre-existing `testthat`-
  version-mismatch failure documented under the `InferenceExact` deletion
  entry above.
- [x] Replace suite constructor probing with metadata filtering. **Already
  satisfied** — verified by rereading `InferenceSuite`'s current discovery
  methods: `.discover_applicable_design_classes()` filters candidates from
  `inference_class_registry_as_list()` metadata only
  (`metadata$exported`/`metadata$abstract`), and `.is_compatible_with_
  design_metadata()` checks only registry-derived class metadata against
  `normalize_inference_design_metadata()`'s output — no class is ever
  constructed (`$new()`) anywhere in the discovery path.
- [x] Replace manual infrastructure denylists with `abstract` and `exported`
  metadata. **Already satisfied** — `.discover_applicable_design_classes()`
  already filters purely on `metadata$abstract`/`metadata$exported` read
  from the registry; there is no hardcoded class-name denylist anywhere in
  the discovery path (the remaining hardcoded rules — the `"KK"` name-
  pattern check and the 2-class blocking-requiring list — are a different,
  still-open matter, out of scope for this item specifically; see the class
  doc's own remaining caveat).
- [x] Add compatibility predicates for continuous, incidence, count,
  proportion, survival, ordinal, KK, non-KK, blocked, and uncensored-only
  designs. **2026-08-16:**
  - **continuous/incidence/count/proportion/survival/ordinal**: already fully
    covered — `infer_inference_response_types()` (`inference_class_registry.R`)
    derives each class's `response_types` from its name prefix
    (`InferenceContin*`→continuous, `InferenceCount*`→count,
    `InferenceIncid*`→incidence, `InferenceOrdinal*`→ordinal,
    `InferenceProp*`→proportion, `InferenceSurvival*`→survival, and the
    `InferenceAll*`/base-`Inference` family → all six), and
    `.is_compatible_with_design_metadata()` gates on
    `design_meta$response_type %in% class_meta$response_types`. No bug found;
    auditing whether the name-prefix derivation is accurate for every
    individual class is a separate, larger undertaking out of scope here.
  - **KK / non-KK**: `requires_kk` (name contains `"KK"`) vs.
    `design_meta$is_kk` was already correct in one direction (a KK-only class
    is excluded from a non-KK design). Confirmed via a full grep sweep of
    `is_a_kk_matching_capable()` call sites that **no class rejects a
    KK-capable design** — every constructor that checks this predicate does
    so to *require* KK, never to exclude it — so there is no "non-KK-only"
    axis to add; the existing one-directional gate already fully covers both
    directions given current class behavior.
  - **blocked**: found and fixed a real bug, the same shape as the censoring-
    axis bug fixed just above. `.class_compatibility_metadata()`'s
    `requires_blocking` was a hardcoded
    `nm %in% c("InferenceIncidCMH", "InferenceIncidExtendedRobins")` list, but
    `InferenceIncidCMH` does **not** actually require blocking — its
    `initialize()` only does extra validation when the design happens to be
    blocking, and `get_standard_error()` has a fully-working non-blocking
    branch (`draw_ws_according_to_design()`). Only
    `InferenceIncidExtendedRobins` genuinely requires it (`initialize()`
    unconditionally `stop()`s if `!des_obj$is_blocking_design()`). Replaced
    the hardcoded list with real metadata, mirroring the
    `supports_general_censoring` pattern: added a
    `requires_blocking_design = function() FALSE` default private method on
    `Inference`'s base class (`inference_all_abstract.R`), overridden to
    `TRUE` only on `InferenceIncidExtendedRobins`
    (`inference_incidence_extended_robins.R`); added
    `infer_inference_requires_blocking_design(generator)`
    (`inference_class_registry.R`), an ancestor-walk-and-invoke helper
    identical in shape to `infer_inference_supports_general_censoring()`;
    wired it into `register_inference_class()`'s defaults and
    `populate_inference_class_registry()`'s per-class metadata; and updated
    `.class_compatibility_metadata()` to read
    `requires_blocking = isTRUE(metadata$requires_blocking_design)` instead of
    the hardcoded list. Verified via direct registry inspection
    (`InferenceIncidCMH`→`FALSE`, `InferenceIncidExtendedRobins`→`TRUE`,
    `InferenceContinLin`→`FALSE`) and via an isolated unit-level discovery
    test (mocked `Design` object bypassing actual C++ construction, which was
    blocked by an unrelated concurrent-session DLL desync at the time):
    `InferenceIncidCMH` is now correctly included in
    `applicable_design_classes` for a non-blocking design, while
    `InferenceIncidExtendedRobins` correctly stays excluded.
  - **uncensored-only**: covered by the `has_general_censoring`/
    `supports_general_censoring` two-axis check already fixed and documented
    in the "Normalize design metadata in one helper" item above.
- [x] Add tests that constructor failures cannot influence discovery.
  **2026-08-16:** `test-inference-suite-discovery.R` gained
  "InferenceSuite discovery is unaffected by a class whose constructor always
  fails" — registers a real R6 generator inheriting `Inference` whose
  `initialize()` unconditionally `stop()`s, registers matching metadata via
  `register_inference_class()`, and asserts (a) the class still appears in
  `applicable_design_classes` and (b) directly calling `$new()` on it does
  throw — proving discovery genuinely never constructs candidates (confirmed
  by inspection: `.discover_applicable_design_classes()` only reads
  `inference_class_registry_as_list()`, never `get()`/`new()` on any
  candidate).
- [x] Add tests that missing optional packages are reported separately from
  incompatibility. **2026-08-16:** this exposed a real gap — despite the
  `required_packages` metadata field existing since the registry was built,
  `InferenceSuite` discovery never consulted it (every class registers
  `required_packages = character()` unconditionally; there is no
  `infer_inference_required_packages()` analogous to the design registry's
  `infer_design_required_packages()`/`EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME`,
  and no currently-shipped `Inference` class declares any). Per this
  section's own spec ("candidate if: ... required_packages are available ...
  Unavailable packages should be reported separately from design
  incompatibility"), implemented the gate: `InferenceSuite` gained a new
  public field `unavailable_due_to_missing_packages` (a named list, class
  name → missing package names) and `.discover_applicable_design_classes()`
  now splits design-compatible candidates into `applicable` (all
  `required_packages` installed) vs. `unavailable_due_to_missing_packages`
  (design-compatible but missing a package), via a new
  `.missing_required_packages()` private helper
  (`requireNamespace(pkg, quietly = TRUE)` per declared package). Since no
  real class currently declares non-empty `required_packages`, this is a
  pure no-op for all existing classes (confirmed: 0 classes in the populated
  registry have non-empty `required_packages`) — the feature only takes
  effect once a class actually declares one. Tested with two temporary
  registry-only classes: one design-compatible but declaring an
  unsatisfiable fake package (correctly excluded from
  `applicable_design_classes` and reported in
  `unavailable_due_to_missing_packages` with the exact missing package name),
  and one ordinarily design-incompatible class (wrong `response_types`) with
  no package requirement, confirming the two exclusion reasons stay
  distinct rather than collapsing into one bucket.

### Static Cleanup

- [ ] Ban raw component splicing outside `define_inference_class()`.
  **Progress 2026-08-16:** `InferenceOrdinalPairedSignTest` now composes
  `KKPassThrough` through the factory with explicit public/private overrides,
  removing both of its raw generator-slot splices. `InferenceContinKKGLMM` now
  likewise composes `KKGLMM` through the factory, with its four intentional
  public replacements declared explicitly, removing two more raw splices.
  `InferenceCountKKGLMM` now uses the same factory component with its four
  public replacements and weighted-fit private replacement declared, removing
  another two raw splices. `InferenceAbstractQuantileRandCI` now composes the
  registered `QuantileRandomizationCI` component through the factory, removing
  another two raw extension splices. `InferenceAbstractKKCondLogitGLMM` now
  composes `KKPassThrough` through the factory with its weighted-estimate and
  match-data overrides declared explicitly, removing two more raw splices.
  `InferenceOrdinalKKCondAdjCatLogitRegr` now composes its intended
  `OrdinalConditionalLogitPartialLikelihood` and `KKPassThrough` components
  through the factory, removing two more raw splices.
  `InferenceAbstractKKOrdinalCLMM` now composes `KKPassThrough` through the
  factory with its weighted-estimate and match-data overrides declared,
  removing two more raw splices.
- [x] Ban `eval(body(Inference...))`. **Progress 2026-08-16:** removed two
  redundant leaf copies from `InferenceContinKKOLSIVWC` and
  `InferenceAbstractKKQuantileRegrIVWC`; both now inherit the same shared
  bootstrap implementation from
  `InferenceKKPassThroughCompoundNoParamBootstrap`. A structural regression
  verifies the method is absent locally and present on the ancestor chain.
  Removed five more redundant replacements from clean KK hosts that already
  compose `InferenceMixinKKPassThrough$public`; those generators now retain
  the directly composed function instead of replacing it with an evaluated
  copy of the same body. Removed the same redundant replacement from the
  shared KK compound composition, covering both its parametric-bootstrap and
  no-parametric-bootstrap generators. The structural regression verifies body
  identity for all seven directly composed hosts.
  **Completed 2026-08-19**: removed the last two occurrences in the whole
  tree, both inside the `...LegacyRaw` harvesting classes for
  `InferenceSurvivalKKClaytonCopulaOneLik`/
  `InferenceSurvivalKKWeibullFrailtyOneLik`
  (`inference_survival_KK_clayton_copula.R`,
  `inference_survival_KK_weibull_frailty.R`) -- same verified-no-op
  reasoning as every prior removal (each class already splices
  `InferenceMixinKKPassThrough$public` directly, so the raw source's own
  `approximate_bootstrap_distribution_beta_hat_T` was already present
  without the explicit re-evaluated copy). `test-static-cleanup-
  guardrails.R`'s expected count for this pattern is now `integer(0)` --
  zero occurrences anywhere in the package. (The separate raw-splicing
  guardrail still shows 2 occurrences in each of those two files, down from
  3: the structural `modifyList(as.list(InferenceMixinKKPassThrough$public),
  ...)` splice itself remains, since these `...LegacyRaw` classes are still
  the harvesting source for their components, pending the Base Deletion
  phase -- only the redundant *second* textual reference from the removed
  `eval(body(...))` line went away.) Verified via
  `test-survival-kk-clayton-copula-onelik-migration-golden.R`/
  `test-survival-kk-weibull-frailty-onelik-migration-golden.R` (no behavior
  change) plus the full mixin-contracts/parametric-bootstrap/full-
  likelihood-baseline battery, all green.
- [x] Ban `$private` reads from R6 generator symbols. Enforced by the
  zero-tolerance source scan in `test-static-cleanup-guardrails.R`.
- [x] Ban semantic classification through private method-name sniffing.
  **Progress 2026-08-16:** randomization-CI response-transform dispatch now
  uses declared component capabilities (`standard_model_cache`, count
  likelihood, KK GEE/GLMM/pass-through) plus three explicit legacy family
  exceptions, eliminating eight `has_private_method("is_a_*")` probes. A
  source guardrail freezes the remaining two probes in
  `inference_all_abstract_rand.R` so the debt cannot grow while that already
  modified randomization core is handled separately.
  **Completed 2026-08-19**: closed out the last remaining probe pair in
  `inference_all_abstract_rand.R`'s `compute_treatment_estimate_during_
  randomization_inference()` (`is_a_kk_quantile_regr_ivwc` /
  `is_a_kk_quantile_regr_one_lik`). Traced the full component-composition
  chain for both `InferenceProp/ContinKKQuantileRegrIVWC` and `...OneLik`
  (both compose `BayesianBootstrap`, which transitively depends back to
  `RandomizationTest` -- the component this method is harvested from) and
  confirmed the `one_lik` branch was dead code: `KKQuantileRegrOneLik`
  always provides its own override of the entire method, so the
  `RandomizationTest`-sourced version (and its embedded probe) never runs
  for a OneLik-composing class. Replaced the live `ivwc` half with a new
  `"kk_quantile_regr_ivwc"` capability, declared on the `KKQuantileRegrIVWC`
  component spec (no `capability_requires`/`public_methods_for_capability`
  entry needed -- a pure dispatch marker, same shape as `kk_passthrough`/
  `kk_gee`/`kk_glmm`/`standard_model_cache`), checked via `self$capabilities()`
  (available in private methods like every other R6 method). Removed the
  now-fully-unused `is_a_kk_quantile_regr_ivwc`/`is_a_kk_quantile_regr_one_lik`
  marker methods from both abstract source files and their
  `provides_private_methods` entries in `contracts_mixins.R`. Verified via
  `test-static-cleanup-guardrails.R` (ratcheted the probe-count guardrail
  `1 -> 0`, now `integer(0)` package-wide), `test-mixin-contracts.R`,
  `test-capability-tables.R`, and both KK quantile-regression golden test
  files (`test-kk-quantile-regr-ivwc-migration-golden.R`/`...-onelik-...`,
  including the proportion-response path this exact check gates) -- all
  green, confirming the capability swap is behavior-preserving.
- [ ] Ban component redeclaration of root-owned state. A 2026-08-16 guardrail
  now freezes the eight remaining legacy KK component violation sets so no new
  redeclarations can enter while those components are migrated.
- [x] Ban scaffold components in effective component sets. Enforced by
  `test-mixin-contracts.R` for both direct and dependency-resolved components.
- [x] Ban implicit method and state collisions. Factory validation rejects
  undeclared public/private and method/state collisions; the registry-wide
  collision audit permits only explicitly declared overrides.

### Regression Gates

- [ ] Before migrating a family, add focused golden tests for estimates,
  standard errors, confidence intervals, p-values, and applicable bootstrap or
  randomization distributions.
- [x] Add finite smoke tests for every class with
  `parametric_likelihood_bootstrap`. **Completed 2026-08-17:** added a
  registry-driven, table-based finite likelihood-ratio bootstrap smoke case for
  every concrete class advertising the capability (36 classes), plus an exact
  registry-to-case equality guard so future capable classes cannot enter
  uncovered. The inventory exposed five legacy incidence classes that inherited
  the capability while explicitly disabling it at runtime; transitional
  registry exclusions now keep discovery truthful until their shallow
  migrations remove the accidental component inheritance. It also exposed and
  fixed likelihood-spec and simulation defects in
  `InferenceOrdinalAdjCatLogitRegr` and
  `InferenceOrdinalStereotypeLogitRegr`. Verified against the current source
  tree without recompilation: the every-class suite passed 259 expectations,
  the existing focused family suite passed 100 expectations, and the inference
  registry suite passed with no failures or warnings.
- [ ] Add focused tests for count likelihood families, standard-model-cache
  families, KK pass-through families, KK compound families, and likelihood-test
  families.
- [ ] Run `Rscript fast_roxygenize.R` after exported API, class name,
  inheritance, or roxygen changes.
- [ ] Keep package load and targeted tests passing after each migrated family.

### Design-Side Discovery API

- [x] Add a public `Design` method (e.g.
  `applicable_inference_class_names()`) that returns the sorted character
  vector of concrete, exported inference class names legal for this design
  object, derived from the design's own normalized metadata (response type,
  the m vector / KK-matching capability, blocking, censoring of its y's,
  etc.) filtered through the registry's compatibility predicates.
  **2026-08-16:** added `Design$applicable_inference_class_names()`
  (`design_abstract.R`, right after `supports()`), plus a companion
  `Design$unavailable_inference_classes_due_to_missing_packages()` covering
  the missing-package axis added alongside this item (see the Discovery
  section's "missing optional packages" entry above).
- [x] Implement it on top of the same normalized-design-metadata helper and
  registry compatibility predicates used by discovery; no constructor
  probing, no side effects, no new compatibility logic outside the registry.
  **2026-08-16:** `inference_suite.R` was refactored so
  `normalize_inference_design_metadata()`,
  `inference_class_compatibility_metadata()`,
  `is_inference_class_compatible_with_design_metadata()`,
  `missing_required_packages_for_inference_class()`, and
  `discover_applicable_inference_classes()` are all standalone `@noRd`
  functions (not `InferenceSuite` private methods); `Design`'s two new
  methods and `InferenceSuite`'s constructor both call
  `discover_applicable_inference_classes()` (via
  `applicable_inference_class_names_for_design()`/
  `unavailable_inference_classes_due_to_missing_packages_for_design()`), so
  there is exactly one implementation.
- [x] Treat censoring as two independent axes in the normalized design
  metadata and predicates. **Already satisfied** — this was implemented in
  the Discovery section's "Normalize design metadata in one helper" item
  earlier in this doc (`any_censoring`/`has_general_censoring` in
  `normalize_inference_design_metadata()`,
  `supports_general_censoring` gate in
  `is_inference_class_compatible_with_design_metadata()`); the `Design`
  method reuses that same normalization, so it inherits the fix rather than
  needing a separate one.
- [x] Define discovery as class-level compatibility under default
  constructor arguments. **Already satisfied by construction** — discovery
  is purely registry-metadata-driven (`response_types`,
  `requires_blocking_design`, `supports_general_censoring`, `required_packages`
  are all class-level, argument-independent fields); no per-argument logic
  exists anywhere in `discover_applicable_inference_classes()`. A class like
  `InferenceSurvivalCoxPHRegr`, whose censoring tolerance actually depends on
  `testing_type`, is listed based on its class-level
  `supports_general_censoring` metadata regardless of constructor arguments,
  and any argument-dependent rejection remains a construction-time error in
  that class's own `initialize()` — auditing whether that specific class's
  registered metadata matches its true default-argument behavior is out of
  scope for this generic mechanism.
- [x] Rewire `InferenceSuite` discovery to call this `Design` method instead
  of its private `.design_metadata()` / `.is_compatible_with_design_metadata()`
  / `.discover_applicable_design_classes()` chain, so the compatibility logic
  lives in exactly one place; delete the now-redundant private methods.
  **2026-08-16:** done — `InferenceSuite$initialize()` now calls
  `des_obj$applicable_inference_class_names()` and
  `des_obj$unavailable_inference_classes_due_to_missing_packages()`
  directly; all four private compatibility-check methods removed from the
  `InferenceSuite` R6 generator.
- [x] Add tests that the `Design` method and `InferenceSuite`'s
  `applicable_design_classes` field agree for every design/response-type
  combination. **2026-08-16:** agreement assertions
  (`expect_identical(sort(des$applicable_inference_class_names()), sort(classes))`,
  plus the matching check for
  `unavailable_inference_classes_due_to_missing_packages()`) added to every
  existing design-construction test in `test-inference-suite-discovery.R`
  (continuous Bernoulli, KK14, and a new dedicated test reusing the
  blocking-axis regression designs), and verified at the unit level (mocked
  `Design` object, bypassing an unrelated concurrent-session DLL desync that
  is currently blocking real `Design` construction) — see that same DLL note
  under the Discovery section above for why full end-to-end `testthat` runs
  are still pending. The stronger "reflects both censoring axes with
  survival data" sub-case is not yet covered by a dedicated test — no
  existing test file in this package currently builds a `y_R`-bearing
  interval-censored design fixture; adding one is a larger, separate task.
- [ ] Document and export the method, and run `Rscript fast_roxygenize.R`.
  **Partially done 2026-08-16:** both new `Design` methods are fully
  roxygen-documented (`@description`/`@param`/`@return`); no separate
  `@export` tag is needed since they're public methods on the
  already-`@export`ed `Design` R6 generator. Deliberately did **not** run
  `fast_roxygenize.R` — regenerating `Rd`/`NAMESPACE` package-wide right now
  risks clobbering concurrent sessions' own in-flight doc changes in this
  shared repo (see this doc's standing DLL-desync notes); leave this
  mechanical step for a dedicated, coordinated roxygenize pass.
- [x] **Audit which `Inference` classes actually use their `model_formula`
  in the fit vs. merely accept-and-ignore it, and record the answer as
  real registry metadata (e.g. an `adjusts_for_covariates` field next to
  `likelihood_tier`/`response_types`/`requires_blocking_design` in
  `inference_class_registry.R`).** Found while adding
  `InferenceSuite$run_all_inference()`'s new `cov_model` column
  (2026-08-19): `Inference$initialize()` always sets
  `private$model_formula` (via `des_obj$get_design_formula()` when
  `model_formula = NULL`, or the caller-supplied formula otherwise) --
  every class, without exception, ends up with a non-`NA`
  `get_model_formula()`. But "accepts and stores a formula" is not the
  same as "the fit is a function of it": `SimpleMeanDifferenceSource$
  initialize()` (`inference_all_mean_diff.R:16`) takes `model_formula` and
  forwards it to `super$initialize()` like any other class, yet its actual
  fit (`private$shared()`, Welch's unequal-variance t-test on raw group
  means) never reads `private$X` at all -- the stored formula is
  causally inert for this class's estimate/SE/CI/pval. There is currently
  no metadata field anywhere that records this distinction, so
  `run_all_inference()`'s `cov_model` column reports a real formula string
  for every `"ok"` row, including ones (like `SimpleMeanDiff`/
  `SimpleMeanDiffPooledVar`/`SimpleWilcox`, and plausibly the closed-form
  incidence risk-difference/CMH/log-rank/Gehan-Wilcox-style nonparametric
  classes -- not yet checked one by one) where that formula had no effect
  on the reported numbers, which is misleading to read at face value.
  Scope: walk every concrete `Inference` subclass's fit-path methods
  (`compute_estimate`, `compute_asymp_confidence_interval`/
  `compute_asymp_two_sided_pval`, and any other primary estimator path) and
  check whether `private$X`/`private$get_X()` (or the class's own
  covariate accessor) is actually read; record `TRUE`/`FALSE` per class in
  the registry once confirmed, `NA`/unaudited otherwise -- do not guess
  from class name patterns. Once landed, `run_all_inference()`'s
  `cov_model` column should report `NA_character_` for any class whose
  registry entry says `adjusts_for_covariates = FALSE`, matching the
  already-agreed design ("formula is blank for classes that don't take a
  formula") from `inference_suite_inspect.md`'s discussion of this column.
  **Done 2026-08-19:** Added `adjusts_for_covariates` (logical, `NA` default
  = unaudited) to the registry record in `inference_class_registry.R`
  (default in `register_inference_class()`, validated in
  `validate_inference_class_metadata()`), and a new
  `infer_inference_adjusts_for_covariates(name)` populate-time helper backed
  by two explicit audited name lists (`EDI_INFERENCE_CLASSES_IGNORING_COVARIATES`,
  `EDI_INFERENCE_CLASSES_USING_COVARIATES`) rather than a regex, since this
  question cannot be answered from name patterns alone. `run_all_inference_one_class()`
  in `inference_suite.R` now reports `cov_model = NA_character_` whenever
  `get_inference_class_metadata(cls_name)$adjusts_for_covariates` is
  `FALSE`; `TRUE`/`NA` classes keep reporting the real formula string.
  Audited by reading each concrete class's own fit-path code (and, where the
  fit lives on an abstract parent, that parent's code) for
  `private$X`/`private$get_X()`/`model.matrix` usage:
  - **FALSE** (19 classes, closed-form/nonparametric, fit never reads X):
    `SimpleMeanDiff`/`SimpleMeanDiffPooledVar`/`SimpleWilcox`/
    `KKMeanDiffIVWC`/`KKWilcoxIVWC`, `IncidCMH`, `IncidExtendedRobins`,
    `IncidMiettinenNurminenRiskDiff`, `IncidNewcombeRiskDiff`, `IncidWald`,
    `IncidExactFisher`, `IncidExactZhang`, `SurvivalGehanWilcox`,
    `SurvivalKMDiff`, `SurvivalLogRank`, `SurvivalRestrictedMeanDiff`,
    `OrdinalJonckheereTerpstraTest`, `OrdinalRidit`, `OrdinalPairedSignTest`
    (sign test on matched-pair `y`-differences; never reads `private$X`).
  - **TRUE** (~82 classes): every regression/likelihood/GEE/GLMM/Cox/
    quantile-regression/robust-regression/g-computation class (OLS, logistic,
    probit, log-binomial, modified-Poisson, binomial-identity, Poisson/
    NegBin/hurdle/zero-inflated/quasi/robust-Poisson, ordinal
    adjacent-category/cauchit/cloglog/stereotype/continuation-ratio/
    ordered-probit/proportional-odds/partial-proportional-odds/CLMM, beta/
    fractional-logit/zero-one-inflated-beta, Cox/stratified-Cox/Weibull/
    dep-cens-transform/Clayton-copula/Weibull-frailty survival classes, and
    their KK/IVWC/OneLik counterparts) plus `IncidRiskDiff` (covariates enter
    `build_design_matrix()`), the KK "matching" classes
    `IncidKKNewcombeRiskDiff`/`IncidExactBinomial` (covariates feed
    `compute_zhang_match_data_cpp(private$get_X(), ...)`, which changes the
    match/weighting scheme and therefore the estimate), and `ContinKKGLMM`/
    `CountKKGLMM`/`OrdinalKKGLMM` (KKGLMM component's shared fit builds
    `X_fit` via `private$create_design_matrix()`/`glmm_predictors_df()` --
    covariates enter the mixed-model fixed effects directly).
  - **NA (intentionally, not a gap)**: three user-extensible extension bases
    `InferenceCustomAsymp`/`InferenceCustomRand`/`InferenceCustomBoot`
    (whether the formula is used depends on the subclass a caller writes,
    not on this class itself), and three abstract hosts
    `InferenceAbstractKKCondLogitGLMM`/`InferenceAbstractKKOrdinalCLMM`/
    `InferenceAbstractQuantileRandCI` (never instantiated directly; every one
    of their concrete leaf subclasses is separately audited above/below).
    Every other `define_inference_class(...)`-defined generator in
    `R/EDI/R/*.R` (verified exhaustively by diffing the full class-name list
    against the two audited lists — 0 unaccounted concrete classes remain)
    is in the FALSE or TRUE list above.
- [x] **Implement `get_estimand_type()` across every concrete `Inference`
  class, not just the incidence g-computation family (`InferenceIncidGCompAbstract`/
  `InferenceIncidKKGCompAbstract`, `inference_incidence_gcomp.R`,
  `inference_incidence_KK_marginal.R`, returning `"RD"`/`"RR"`) -- this is
  `inference_suite_inspect.md`'s TODO-15a, checked and confirmed **not**
  done (2026-08-19): the base `Inference$get_estimand_type()`
  (`inference_all_abstract.R:432-434`) still returns `NA_character_`
  unconditionally, and every class outside the two families above inherits
  that default -- continuous, count, ordinal, survival, and proportion
  response types, plus the non-g-comp incidence classes, all currently
  report `estimand = NA_character_` in `run_all_inference()`'s
  `results_table`. TODO-15a's own text names the blocking question this
  audit must answer per class: does `estimand` actually distinguish
  "different scientific question" (e.g. a log-odds-ratio vs. a risk
  difference) from "different link/model answering the same question"
  (e.g. two different GLM links both estimating a mean difference) --
  `"estimand_grouped"` Combined Evidence weighting (and any per-`estimand`
  table sort/CI-inversion work, including the display-only estimand sort
  already shipped in `run_all_inference_format_pretty_table()`/
  `run_all_inference_format_html_table()`, 2026-08-19) is only as correct
  as this tagging is complete and accurate. **Model this audit's process
  and reporting shape directly on the `adjusts_for_covariates` audit just
  above** (same file, same day) -- it is the closest completed precedent
  for exactly this kind of "read every concrete class's own code and
  record a real fact, not a guess from naming patterns" registry-metadata
  audit: read each concrete class's actual estimate-contract code (whatever
  each class documents as its `compute_estimate()`'s target quantity -- see
  each class's own `@description` on `compute_estimate()`, which already
  states the estimand in prose for most classes) and record the estimand
  identity as new registry metadata (e.g. widen `get_estimand_type()`'s
  domain past `"RD"`/`"RR"` to a real, closed enumeration covering every
  response family: mean/median/quantile-`tau` difference, log-odds-ratio,
  hazard-ratio, log-rate-ratio, stochastic-superiority, etc. -- coordinate
  the enum's exact values with `marginal_estimand_report.md`/
  `expanded_estimate_report.md`'s own estimand-related work so this audit
  doesn't invent a second, conflicting taxonomy). Two explicit audited name
  lists (or a name -> estimand-string map, since this field isn't boolean)
  in `inference_class_registry.R`, not a regex over class names -- same
  reasoning TODO-15a and the `adjusts_for_covariates` audit both already
  established: "accepts/looks like X" is not evidence of "targets estimand
  Y." Leave classes not yet confirmed as `NA_character_` (the existing
  default), same unaudited-vs-confirmed distinction the
  `adjusts_for_covariates` audit used. Once landed, close out
  `inference_suite_inspect.md` TODO-15a itself, and re-open discussion of
  whether `"estimand_grouped"` weighting (TODO-15) is then safe to default
  to.
  **Done 2026-08-19:** Modeled directly on the `adjusts_for_covariates`
  audit above (same file, same day): a flat name -> tag map
  (`EDI_INFERENCE_ESTIMAND_TAGS` in `inference_class_registry.R`), consulted
  by `infer_inference_estimand_type(generator, name)` before it falls back
  to the existing generator `private_methods$get_estimand_type()` walk (so
  the two already-implemented g-computation families,
  `InferenceIncidGCompAbstract`/`InferenceIncidKKGCompAbstract`, keep their
  own real implementation as the source of truth and this audit's tags for
  those four leaf classes -- confirmed matching, `"RD"`/`"RR"` -- are purely
  redundant confirmation, not an override). No existing taxonomy string list
  was found in `marginal_estimand_report.md`/`expanded_estimate_report.md`
  for this specific field (those documents define an orthogonal
  conditional-vs-marginal `set_estimand()`/`get_estimand()` *switch*
  component with its own `"conditional"`/`"marginal_mean_diff"`/
  `"marginal_ratio"` values -- a different, later-landing mechanism, not
  `get_estimand_type()`'s fixed per-class declaration), so a new small
  taxonomy was defined here, kept response-type-grounded and explicit about
  marginal-vs-conditional noncollapsibility per the TODO's own guidance.
  Audited every concrete class's `compute_estimate()` fit code and its own
  `@description` roxygen (not name patterns); exhaustively checked against
  the full concrete-class census already established for the
  `adjusts_for_covariates` audit (same 99-class list; zero classes
  unaccounted for -- every class is either tagged below or explicitly
  placed in the NA list with a reason).
  - **Tagged (88 classes)**, by estimand:
    - `mean_difference` (linear location-shift, collapsible so no
      marginal/conditional split needed): `SimpleMeanDiff`/
      `SimpleMeanDiffPooledVar`/`KKMeanDiffIVWC`, `ContinOLS`/`ContinLin`/
      `ContinRobustRegr`/`ContinKKOLSIVWC`/`ContinKKOLSOneLik`/
      `ContinKKRobustRegrIVWC`/`ContinKKRobustRegrOneLik`/`ContinKKGLMM`,
      `BaiAdjustedTKK14`/`BaiAdjustedTKK21`, `OrdinalGCompMeanDiff`,
      `PropGCompMeanDiff`.
    - `hodges_lehmann_shift` (rank-based location shift):
      `SimpleWilcox`/`KKWilcoxIVWC`.
    - `RD` (risk difference): `IncidBinomialIdentityRiskDiff`,
      `IncidRiskDiff`, `IncidWald`, `IncidCMH` (confirmed via its own
      `SimpleMeanDifference` direct component -- a blocked mean-difference
      estimator on the 0/1 outcome, not a common-odds-ratio test),
      `IncidExtendedRobins` (own roxygen: "simple mean-difference point
      estimate with a block-stratified standard error"),
      `IncidMiettinenNurminenRiskDiff`, `IncidNewcombeRiskDiff`,
      `IncidKKNewcombeRiskDiff`, `IncidGCompRiskDiff`,
      `IncidKKGCompRiskDiff` (both already real overrides).
    - `RR` (risk/rate ratio): `IncidLogBinomial`, `IncidModifiedPoisson`,
      `IncidKKModifiedPoisson`, `IncidGCompRiskRatio`,
      `IncidKKGCompRiskRatio` (both already real overrides).
    - `log_odds_ratio_marginal` (population-averaged logistic effect):
      `IncidLogRegr`, `IncidKKGEE`.
    - `probit_effect_marginal`: `IncidProbitRegr`.
    - `log_odds_ratio_conditional` (matched-set/exact-conditional log-OR --
      noncollapsibility means this is NOT the same asymptotic quantity as
      `log_odds_ratio_marginal` even though both come from "a logistic
      model"): `IncidExactFisher` (own roxygen: conditional-MLE/common
      odds ratio), `IncidExactBinomial`/`IncidExactZhang` (own roxygen:
      matched-pair log odds ratio), `IncidKKCondLogitIVWC`/
      `IncidKKCondLogitOneLik`/`IncidKKCondLogitGLMMIVWC`/
      `IncidKKCondLogitGLMMOneLik`.
    - `log_rate_ratio_marginal`: `CountPoisson`/`CountNegBin`/
      `CountQuasiPoisson`/`CountRobustPoisson`/`CountPoissonKKGEE`.
    - `log_rate_ratio_conditional` (matched-pair random-intercept/
      conditional-likelihood count models, split from the marginal tag for
      the same noncollapsibility reason as incidence): `CountKKGLMM`,
      `CountKKCondPoissonOneLik`.
    - Ordinal link-function families kept maximally separated per the
      TODO's explicit warning that ordinal has the *most* estimand groups,
      not the fewest -- each is its own tag, marginal vs. `_conditional`
      (mixed-model/matched) split the same way as incidence/count:
      `log_odds_ratio_proportional` (`OrdinalPropOddsRegr`, `OrdinalKKGEE`)
      / `log_odds_ratio_proportional_conditional` (`OrdinalKKCLMM`,
      `OrdinalKKGLMM`); `log_odds_ratio_adjacent_category`
      (`OrdinalAdjCatLogitRegr`) / `_conditional`
      (`OrdinalKKCondAdjCatLogitRegr`); `cauchit_link_effect`
      (`OrdinalCauchitRegr`) / `_conditional` (`OrdinalKKCLMMCauchit`);
      `cloglog_link_effect` (`OrdinalCloglogRegr`) / `_conditional`
      (`OrdinalKKCLMMCloglog`); `probit_effect_ordinal`
      (`OrdinalOrderedProbitRegr`) / `_conditional`
      (`OrdinalKKCLMMProbit`); `stereotype_link_effect`
      (`OrdinalStereotypeLogitRegr`); `log_odds_ratio_continuation_ratio`
      (`OrdinalContRatioRegr`); `log_odds_ratio_partial_proportional`
      (`OrdinalPartialProportionalOddsRegr`); `mann_whitney_effect`
      (`OrdinalRidit`); `stochastic_ordering_trend`
      (`OrdinalJonckheereTerpstraTest`); `sign_test_effect`
      (`OrdinalPairedSignTest`).
    - `logit_effect_proportion_mean` (logit-link mean-proportion models --
      beta regression and fractional logit target the same practical
      question on the same scale, so they share one tag per the TODO's
      "different link/model, same question" rule): `PropBetaRegr`,
      `PropFractionalLogit`, `PropKKGEE`; conditional/mixed-model variant
      `logit_effect_proportion_mean_conditional`: `PropKKGLMM`.
    - `hazard_ratio` (Cox partial-likelihood log-HR; stratified/LWA/KK
      variants share this tag -- Cox HRs are conditional-on-covariates by
      construction across all of them, so this split does not apply the
      same way it does to logistic/Poisson/ordinal): `SurvivalCoxPHRegr`,
      `SurvivalStratCoxPHRegr`, `SurvivalKKLWACoxPHIVWC`/
      `SurvivalKKLWACoxPHOneLik`, `SurvivalKKStratCoxPHIVWC`/
      `SurvivalKKStratCoxPHOneLik`.
    - `log_time_ratio` (Weibull AFT scale, own roxygen confirms "log-time
      ratio"/"log-time-ratio scale" for every one of these):
      `SurvivalWeibullRegr`, `SurvivalKKWeibullMarginal`,
      `SurvivalKKWeibullFrailtyIVWC`/`SurvivalKKWeibullFrailtyOneLik`,
      `SurvivalKKClaytonCopulaIVWC`/`SurvivalKKClaytonCopulaOneLik`.
    - `gehan_wilcoxon_statistic` (Peto-Prentice generalized-Wilcoxon rank
      statistic -- deliberately given its own tag, distinct from
      `log_rank_martingale_difference`, since the two use different
      within-stratum weighting and are not the same scientific question):
      `SurvivalGehanWilcox`, `SurvivalKKRankRegrIVWC`.
    - `log_rank_martingale_difference` (own roxygen: "difference in mean
      martingale residuals between the treatment and control" -- not
      literally a hazard-ratio point estimate): `SurvivalLogRank`.
    - `survival_median_difference`: `SurvivalKMDiff`.
    - `restricted_mean_survival_time_difference`: `SurvivalRestrictedMeanDiff`.
  - **Left `NA_character_` (14 classes), genuinely undetermined, not
    skipped**:
    - Zero-inflated/hurdle count and ZOIB proportion models -- a
      structural-zero component and a separate rate/mean component, with
      no single agreed scalar "the treatment effect" without picking which
      part is meant (per the TODO's own explicit warning not to force a
      single tag here): `CountHurdlePoisson`, `CountHurdleNegBin`,
      `CountZeroInflatedPoisson`, `CountZeroInflatedNegBin`,
      `CountKKHurdlePoissonIVWC`, `CountKKHurdlePoissonOneLik`,
      `PropZeroOneInflatedBetaRegr`.
    - Quantile regression across every family that offers it -- the target
      is tau-indexed, not a fixed per-class scalar, and
      `get_estimand_type()` is called argument-less on the bare generator
      (same safe-invoke-without-construction contract as
      `infer_inference_requires_blocking_design()`), so it structurally
      cannot depend on a per-call tau: `ContinQuantileRegr`,
      `ContinKKQuantileRegrIVWC`, `ContinKKQuantileRegrOneLik`,
      `PropQuantileRegr`, `PropKKQuantileRegrIVWC`,
      `PropKKQuantileRegrOneLik`.
    - `SurvivalDepCensTransformRegr`: bivariate transformation model for
      dependent censoring; its treatment-coefficient scale was not
      confidently identified from source reading alone within this audit's
      scope -- left unaudited rather than guessed.
  - **TODO-15a closed.** `inference_suite_inspect.md`'s TODO-15a is marked
    done, pointing here. `"estimand_grouped"` weighting (TODO-15) is closer
    to safe to default but not yet fully unblocked: the 14 `NA`-estimand
    classes above still need an explicit policy decision (own singleton
    group per TODO-15a's own question, vs. excluded with a `warning()`)
    before a default weighting policy can treat every `status == "ok"` row
    consistently -- that policy decision is left to TODO-15 itself, not
    decided by this audit.
- [x] **Give `RandomizationBootstrapCI` its own `provides_capabilities`
  string in `contracts_mixins.R`, instead of the empty
  `character()` it declares today, so `run_all_inference()`'s `methods`
  argument (`inference_suite_inspect.md`; `rand_bootstrap` sentinel) can
  gate the CI side precisely instead of via a loose capability proxy.**
  Found while auditing `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`'s
  `rand_bootstrap` entry (2026-08-19): every other CI/p-value split in
  that table has its own distinct capability string on each side --
  e.g. `RandomizationTest` provides `"randomization_test"` (p-value) and
  the separate `RandomizationCI` component provides its own
  `"randomization_ci"` (CI), so checking `"randomization_ci" %in%
  caps` correctly implies the CI method specifically exists. The
  `rand_bootstrap` sentinel does not follow this pattern:
  `RandomizationBootstrap` provides `"randomization_bootstrap"` (gates
  `compute_rand_bootstrap_two_sided_pval`), but its CI extension,
  `RandomizationBootstrapCI` (`dependencies = "RandomizationBootstrap"`,
  provides `compute_rand_bootstrap_confidence_interval`), declares
  `provides_capabilities = character()` -- it contributes no capability
  string of its own, so nothing distinguishes "has the p-value method"
  from "has the p-value *and* CI methods" via `capabilities()` alone.
  **This is not hypothetical**: `inference_class_registry.R:827-828`
  shows `InferenceAllSimpleWilcox`/`InferenceAllKKWilcoxIVWC` compose
  `RandomizationBootstrap` *without* `RandomizationBootstrapCI` --
  concrete classes with the p-value method but not the CI method, exactly
  the case this capability gap can't distinguish. Consequence today: not
  a crash (`run_all_inference_call_ci_for_method()`'s call is
  `tryCatch()`-wrapped, so a missing method degrades to a clean `NA`
  either way), but the capability *pre-check*
  (`inference_class_has_method()`/
  `run_all_inference_class_applicable_methods()`, used to decide which
  method-sentinel rows to even build *before* construction) will
  incorrectly think these two classes have an applicable `rand_bootstrap`
  CI when they don't -- an imprecision, not a bug, but worth fixing at
  the source rather than working around in `inference_suite.R`.
  **Scope**: (1) add a new capability string (e.g.
  `"randomization_bootstrap_ci"`) to `RandomizationBootstrapCI`'s
  `provides_capabilities` in `contracts_mixins.R`, mirroring
  `RandomizationCI`'s `"randomization_ci"` precedent exactly; (2) register
  it in `capability_requires` (a `capabilities = "randomization_bootstrap"`
  dependency, same shape as `randomization_ci`'s own `capabilities =
  "randomization_test"` entry); (3) add a `public_methods_for_capability`
  entry (`randomization_bootstrap_ci = "compute_rand_bootstrap_confidence_interval"`)
  so contract validation actually enforces the method's presence when the
  capability is declared, same as every other capability key; (4) update
  `inference_suite.R`'s `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`'s
  `rand_bootstrap` row to key off the new capability instead of
  `"randomization_bootstrap"`. **Do this in `contracts_mixins.R`, not as a
  component-membership special case inside `inference_suite.R`** (an
  earlier draft of this fix reached for `get_effective_components(nm)`
  directly as a workaround -- rejected, per user direction 2026-08-19: the
  capability system is the correct, load-bearing abstraction every other
  sentinel already uses, and patching around a capability gap from the
  consumer side just re-hides the same gap instead of closing it).
  Run `EDI_VALIDATE_INFERENCE_CONTRACTS=true` strict load after, to
  confirm the new capability/contract entries don't break existing
  validation for any class currently composing `RandomizationBootstrapCI`.
  **Completed 2026-08-19.** Implemented all four scoped steps exactly as
  specified in `contracts_mixins.R`/`inference_suite.R`. Running the
  strict `EDI_VALIDATE_INFERENCE_CONTRACTS=true` load surfaced real,
  previously-invisible gaps (exactly the kind of thing that flag exists to
  catch), all fixed:
  - `EDI_SIMPLE_ESTIMATOR_TARGETS`'s `intentional_capabilities` lists for
    `InferenceAllSimpleMeanDiff`/`InferenceAllSimpleMeanDiffPooledVar`/
    `InferenceAllKKMeanDiffIVWC` (all compose `BayesianBootstrap`, which
    depends on `RandomizationBootstrapCI` transitively) never accounted
    for `compute_rand_bootstrap_confidence_interval`, since no capability
    existed to recognize it until now -- added
    `"randomization_bootstrap_ci"` to each. Same fix needed in
    `build_simple_estimator_behavior_record()`'s own hardcoded capability
    whitelist (`inference_class_registry.R`), which filters "current
    public methods" down to "accounted-for optional surface" and was
    missing the new capability key entirely.
  - **The task's own motivating example turned out to be based on stale
    registry data, caught by re-verifying against the real source rather
    than trusting the write-up**: `InferenceAllSimpleWilcox`/
    `InferenceAllKKWilcoxIVWC` were cited as "compose `RandomizationBootstrap`
    without `RandomizationBootstrapCI`" (from `inference_class_registry.R`'s
    `infer_inference_direct_components()` switch table), but their real
    `define_inference_class()` calls (`inference_all_simple_wilcox.R`,
    `inference_all_KK_wilcox_ivwc.R`) both compose
    `"RandomizationBootstrapCI"` directly -- the switch table entries were
    stale (same class of gap fixed repeatedly elsewhere in this document
    this stretch), not the classes' real capability shape. Fixed both: the
    switch table entries (`"RandomizationBootstrap"` ->
    `"RandomizationBootstrapCI"`) and their `EDI_SIMPLE_ESTIMATOR_TARGETS`
    `intentional_capabilities` (added `"randomization_bootstrap_ci"`, same
    as the mean-difference family). Confirmed via a grep across every
    `components = c(...)` call in the tree that no class currently
    composes `"RandomizationBootstrap"` without also composing (or being
    composed alongside) `"RandomizationBootstrapCI"` -- so there is no
    live example today of a class with the p-value method but not the CI
    method, but the capability distinction is still the architecturally
    correct fix (matches every other CI/p-value split in the priority
    table) and closes the imprecision for whenever such a class is added.
  - Verified: `EDI_VALIDATE_INFERENCE_CONTRACTS=true` strict load passes
    cleanly; `test-mixin-contracts.R`, `test-inference-class-registry.R`,
    `test-parametric-bootstrap-lr-all-capable-classes.R`,
    `test-static-cleanup-guardrails.R` all green.
    `test-simple-estimator-migration-baseline.R`'s pre-existing
    `private_owner_names` count failures (confirmed via `git stash`
    to reproduce identically with none of this turn's changes applied)
    are unrelated drift from a concurrent process's in-progress work in
    this same repo, not caused by this change.
- [x] **`compute_lik_ratio_bartlett_exact_two_sided_pval()`/
  `compute_lik_ratio_bartlett_exact_confidence_interval()` (and their
  `_approx` siblings) are not gated by any registered capability at all --
  a second, related gap found in the same 2026-08-19 sentinel audit as the
  `RandomizationBootstrapCI` item just above.** Both method pairs are
  defined directly on `InferenceAsympLik` (`inference_all_abstract_asymp_
  lik.R:185-230`) -- Bartlett-corrected variants of the likelihood-ratio
  test (`approx`: Monte Carlo-estimated correction factor, `B` replicates;
  `exact`: closed-form). Checked `contracts_mixins.R` for what capability
  might gate them: there is a `BartlettApproximation` component
  (`provides_capabilities = "bartlett_approximation"`), but it only
  contributes *private* helpers (`get_bartlett_factor_approx`,
  `supports_bartlett_likelihood_ratio_approx`) that the already-defined
  `_approx` method consumes internally -- `provides_public_methods =
  character()`, so `"bartlett_approximation"` is never registered as
  gating any public method in `public_methods_for_capability`, and the
  `_exact` method has no associated component/capability declaration
  anywhere that grep found. Practical consequence: **every**
  `InferenceAsympLik`-descended class reports these methods as present
  (they're unconditionally defined on the base class), regardless of
  whether that class's actual likelihood machinery can support a
  meaningful Bartlett correction for it -- there is currently no way to
  ask "does capability X exist" for either of these two tests the way
  `run_all_inference()`'s `methods` sentinel design (and every other
  capability-gated dispatch in the package) expects to be able to.
  **Scope**: audit whether `_approx`/`_exact` should each get their own
  registered capability (e.g. `"lik_ratio_bartlett_approx"`/
  `"lik_ratio_bartlett_exact"`, following the same
  `provides_capabilities`/`capability_requires`/`public_methods_for_
  capability` three-part registration pattern the item above scopes for
  `RandomizationBootstrapCI`), or whether -- since both are defined
  unconditionally on `InferenceAsympLik` itself rather than composed
  in/out per class -- the right fix is instead a private guard method
  (mirroring `supports_bartlett_likelihood_ratio_approx`'s existing
  pattern) that the methods themselves check and `NA`-out on when the
  correction isn't meaningful for that class, rather than a capability
  gate at all. Decide which shape is correct before implementing either.
  Once resolved, add `"lik_ratio_bartlett_approx"`/
  `"lik_ratio_bartlett_exact"` sentinels to `inference_suite.R`'s
  `EDI_INFERENCE_SUITE_METHOD_SENTINELS`
  (`inference_suite_inspect.md`-adjacent `run_all_inference()` `methods`
  argument), which currently has no way to request either test.
  **Completed 2026-08-19.** Decision: **no new capability** -- the
  "private guard method" shape was already fully implemented and working
  (`supports_bartlett_likelihood_ratio_approx()`/`_exact()`, each
  defaulting `FALSE` and overridden per-class; surfaced dynamically via
  `get_supported_testing_types_with_bartlett()`, which
  `get_supported_testing_types()` already calls). The registry-level
  imprecision this TODO worried about ("every `InferenceAsympLik`-descended
  class reports these methods as present") turns out to be the *same*
  class of imprecision every other `likelihood_tests`-gated sentinel
  (`score`/`lik_ratio`/`gradient`) already accepts by design: `run_all_
  inference()`'s capability pre-check is deliberately registry-only/no-
  instantiation (see `inference_class_has_method()`'s own doc comment),
  and the real per-instance gate is the runtime guard method, checked
  when the method is actually called and degrading to `NA` (caught by the
  existing `tryCatch` wrapper) for classes that don't support it --
  verified directly (`InferenceContinOLS`: `supports_..._approx() = TRUE`,
  `supports_..._exact() = FALSE`, and calling
  `compute_lik_ratio_bartlett_exact_two_sided_pval()` on it returns a
  clean `NA`, not an error). Also picked up the judgment call flagged in
  the Audit item below: added **three** sentinels, not two --
  `"lik_ratio_bartlett"` (the "best available" auto-selecting dispatcher,
  `compute_lik_ratio_bartlett_confidence_interval()`/`compute_lik_ratio_
  bartlett_two_sided_pval()`) alongside `"lik_ratio_bartlett_approx"`/
  `"lik_ratio_bartlett_exact"` (explicit pins for reproducibility) --
  since its own roxygen frames it as the right entry point for ordinary
  use. All three added to `EDI_INFERENCE_SUITE_CI_METHOD_PRIORITY`/
  `PVAL_METHOD_PRIORITY` (gated by `"likelihood_tests"`, same precedent as
  `score`/`lik_ratio`/`gradient`) and `EDI_INFERENCE_SUITE_METHOD_
  SENTINELS`, plus the `methods` argument's roxygen documentation.
  Verified end-to-end via `InferenceSuite$new(des)$run_all_inference(methods
  = c("wald", "lik_ratio_bartlett", "lik_ratio_bartlett_approx",
  "lik_ratio_bartlett_exact"), classes = "InferenceContinKKOLSOneLik", ...)`
  on a real KK OLS design: `lik_ratio_bartlett`'s p-value matched
  `lik_ratio_bartlett_exact`'s exactly (confirming the auto-select-exact-
  over-approx dispatch), `lik_ratio_bartlett_approx` gave a distinct
  Monte-Carlo-based value, all four rows populated correctly in
  `results_table`. `test-bartlett-lr-plumbing.R`/`test-bartlett-lr-ols-
  exact.R`/`test-mixin-contracts.R` green;
  `test-inference-suite-discovery.R`'s 2 pre-existing failures (confirmed
  unrelated to this change earlier this stretch) unchanged.
- [x] **Add real `get_supported_*_types()` accessor methods to the
  bootstrap-family components (`NonparametricBootstrap`,
  `BayesianBootstrap`, `RandomizationBootstrap`), mirroring
  `likelihood_tests`'s existing `get_supported_testing_types()`/
  `get_supported_information_preferences()` pattern -- blocking
  prerequisite for `run_all_inference()`'s planned `methods` argument
  redesign (list-of-sentinel -> requested `type` values, default all
  types for all methods; `inference_suite_inspect.md`-adjacent), which is
  itself blocked on this TODO per explicit user decision (2026-08-19: do
  not ship the type-fanout feature against a hardcoded, drift-prone type
  table -- wait for real introspection).** Found during that feature's
  design (2026-08-19): each bootstrap-family method's valid `type` values
  are hardcoded inside its own body via `assertChoice(type, c(...))`, with
  no declarative registry anywhere -- and the CI-side and p-value-side
  choice sets for the *same* sentinel are not even identical, confirmed by
  reading source directly rather than assumed:
  - `compute_bootstrap_confidence_interval()`'s `type` (`inference_all_
    abstract_non_param_boot.R:836-847`): `"percentile"`, `"basic"`,
    `"studentized"`, `"bootstrap-t"`, `"symmetric-percentile-t"`,
    `"bca"`, `"prepivoted"`, `"double-bootstrap"`, `"calibrated"`,
    `"smoothed"` (10 values) vs. `compute_bootstrap_two_sided_pval()`'s
    (`inference_all_abstract_non_param_boot.R:673-685`): `"percentile"`,
    `"symmetric"`, `"studentized"`, `"bootstrap-t"`, `"bca"` (5 values --
    note `"symmetric"` here, not `"symmetric-percentile-t"`, and neither
    `"basic"` nor the other CI-only variants are pval-side options).
  - `compute_bayesian_bootstrap_confidence_interval()`'s `type`
    (`inference_all_abstract_bayesian_bootstrap.R:391-400`):
    `"percentile"`, `"basic"`, `"wald"`, `"studentized"`,
    `"bootstrap-t"`, `"bca"` vs. `compute_bayesian_bootstrap_two_sided_
    pval()`'s (`inference_all_abstract_bayesian_bootstrap.R:261-271`):
    `"percentile"`, `"symmetric"`, `"wald"`, `"studentized"`,
    `"bootstrap-t"`, `"bca"` -- again `"basic"`/`"symmetric"` swap
    between the two sides.
  - `compute_rand_bootstrap_confidence_interval()`/`compute_rand_
    bootstrap_two_sided_pval()` (`inference_all_abstract_rand_bootstrap_
    ci.R:79-88`, `inference_all_abstract_rand_bootstrap.R`): both sides
    agree -- `"percentile"`, `"studentized"`, `"symmetric-percentile-t"`,
    `"smoothed"` -- the one sentinel of the three where CI and pval
    happen to already match exactly.
  **Scope**: for each of the three components, add a public accessor
  (e.g. `get_supported_bootstrap_ci_types()`/
  `get_supported_bootstrap_pval_types()`, split by side given the
  confirmed asymmetry above -- do not assume a single shared list is
  sufficient for any of the three) that returns the exact character
  vector its own `assertChoice()` already hardcodes, so the two stay
  mechanically in sync (ideally by having the method's own
  `assertChoice()` call read from the same constant the accessor
  returns, rather than two independently-maintained literals). Register
  each new accessor in `contracts_mixins.R`'s
  `public_methods_for_capability` under the relevant capability
  (`nonparametric_bootstrap`, `bayesian_bootstrap`,
  `randomization_bootstrap`), same registration mechanics as every other
  public method in that table. Once landed, `run_all_inference()`'s
  `methods` argument can call these accessors at runtime per class
  instead of consulting any hardcoded type table in `inference_suite.R`.
  **Completed 2026-08-19.** Implemented all 6 accessors exactly as scoped
  (`get_supported_bootstrap_{pval,ci}_types()` on `NonparametricBootstrap`,
  `get_supported_bayesian_bootstrap_{pval,ci}_types()` on
  `BayesianBootstrap`, `get_supported_rand_bootstrap_{pval,ci}_types()`
  split across `RandomizationBootstrap` (pval) and
  `RandomizationBootstrapCI` (CI), since those are two separate R6
  classes/files) -- each backed by a private constant field
  (`bootstrap_pval_types`/`bootstrap_ci_types`, etc.) that the component's
  own `assertChoice(type, ...)` call was rewritten to read from directly,
  so the accessor and the runtime validation can never drift apart.
  - **Two rounds of load errors, both real and both fixed, confirming why
    this needed the explicit registration step rather than just adding
    the R6 methods**: (1) `define_inference_class()`'s own
    `validate_inference_class_definition()` (this check runs
    unconditionally, not gated by `EDI_VALIDATE_INFERENCE_CONTRACTS`)
    caught `InferenceAllKKMeanDiffIVWC` (composes `BayesianBootstrap`,
    which pulls `RandomizationBootstrap`/`RandomizationBootstrapCI` in
    transitively) missing the new accessor entirely -- because each
    component's `provides_public_methods`/`owns_state` are explicit
    harvesting whitelists, not "everything the source class defines," so
    the six new methods plus their six backing private constant fields
    needed adding to all four components' `provides_public_methods`/
    `owns_state` in `contracts_mixins.R`, not just `public_methods_for_
    capability`. (2) The lazy-component-loader's own contract check
    (`sort(meta$provides_private_methods) == sort(names(parts$private))`,
    always-on) then caught that the six new private constant fields also
    needed adding to `provides_private_methods` specifically (a third,
    separate list from `owns_state`) -- matching the existing precedent
    already visible in `NonparametricBootstrap`'s spec, where
    `boot_distr_cache`/`jack_distr_cache` etc. already appeared in *both*
    lists.
  - Verified via direct instantiation (`InferenceAllSimpleMeanDiff`): all
    six accessors return the exact documented value sets, and passing an
    invalid `type` to `compute_bootstrap_confidence_interval()` is still
    correctly rejected by `assertChoice()` reading the same constant.
    `EDI_VALIDATE_INFERENCE_CONTRACTS=true` strict load, `test-mixin-
    contracts.R`, `test-inference-class-registry.R`, `test-parametric-
    bootstrap-lr-all-capable-classes.R`, `test-static-cleanup-guardrails.R`,
    `test-bartlett-lr-plumbing.R`, `test-bartlett-lr-ols-exact.R`,
    `test-group-bootstrap-rcpp.R`, `test-m-out-of-n-prw-subsampling.R`, and
    a full repo-wide regression sweep all green.
- [x] **Audit `contracts_mixins.R`'s `public_methods_for_capability` for
  completeness against every `compute_*_two_sided_pval()`/
  `compute_*_confidence_interval()` method actually defined in the
  codebase -- currently a hand-maintained 12-key list with no mechanism
  forcing it to stay exhaustive, and it is demonstrably not exhaustive
  today.** Blocking prerequisite for `inference_suite_plan.md`'s planned
  TODO to derive `run_all_inference()`'s method-sentinel list via
  introspection of this registry instead of a hardcoded constant in
  `inference_suite.R` -- introspecting an incomplete registry just moves
  the staleness risk from one hardcoded list to another, so this must
  close first. Found via two rounds of manual `grep`-auditing while
  designing `run_all_inference()`'s `methods` argument (2026-08-19), each
  round turning up gaps the previous one missed -- itself the proof this
  needs a systematic, not ad hoc, audit:
  - `RandomizationBootstrapCI`'s `compute_rand_bootstrap_confidence_interval`
    is real but ungated (own TODO above, already scoped).
  - `compute_lik_ratio_bartlett_approx_two_sided_pval`/
    `_confidence_interval` and `_exact` are real but ungated (own TODO
    above, already scoped) -- and a **third** variant exists that neither
    of those TODOs mentions: `compute_lik_ratio_bartlett_two_sided_pval`
    (no suffix, `inference_all_abstract_asymp_lik.R:261`), a "best
    available" dispatcher that auto-selects exact-over-approx (its own
    roxygen: "uses the exact... factor if this class implements one,
    otherwise falls back to the approximate... factor"); this plain
    dispatcher is plausibly the *right* single sentinel for ordinary use
    (with `_approx`/`_exact` as opt-in overrides for reproducibility, per
    its own docs), fold that judgment call into the existing Bartlett TODO
    when it's picked up.
  - `compute_m_out_of_n_bootstrap_two_sided_pval`/
    `compute_subsampling_two_sided_pval` (`NonparametricBootstrap`
    component) are real, distinct resampling-scheme methods not listed
    under the `nonparametric_bootstrap` key's method set at all (only the
    3 canonical bootstrap methods are) -- an open scope question (own
    method-family or extra `type` values?), not yet decided.
  **Scope**: enumerate every `compute_*_two_sided_pval`/
  `compute_*_confidence_interval` method definition across `R/EDI/R/*.R`
  (a full grep, not spot-checks), cross-reference each against
  `public_methods_for_capability`'s existing 12 keys, and for every
  orphan found (the ones above, and any this pass turns up that the two
  prior manual rounds didn't) either fold it into an existing capability
  key, give it a new one, or explicitly document why it's deliberately
  uncatalogued (e.g. an internal dispatcher whose target methods are
  already separately registered, like `compute_likelihood_test_two_sided_pval`'s
  `testing_type`-parameterized dispatch into `score`/`lik_ratio`/
  `gradient`, already covered under `likelihood_tests`). Land as a
  regression-tested invariant (e.g. a test asserting the grep-derived
  method-name set is a subset of the registry's), not just a one-time
  manual pass, so this can't silently go stale again the way the
  hand-maintained list already has.

  **Done (2026-08-19)**: ran a from-scratch enumeration via live R6
  introspection over every generator in `asNamespace("EDI")` (authoritative,
  unlike grepping `public = list(...)` text boundaries, which can't
  distinguish a method spliced in by a component from one still defined
  directly on an unmigrated deep-ladder base) -- filtered to public methods
  matching `^compute_.*(two_sided_pval|_pval|confidence_interval)$` -- and
  cross-referenced against `public_methods_for_capability`'s registered set.
  Reconfirmed the two prior manual-audit rounds' orphans and found no
  further ones. All folded into existing capability keys (no new capability
  needed, matching the coarse-gate precedent `run_all_inference()` already
  relies on for Bartlett):
  - `compute_rand_bootstrap_confidence_interval` /
    `get_supported_rand_bootstrap_ci_types` -> new `randomization_bootstrap_ci`
    key (own TODO above).
  - `compute_lik_ratio_bartlett_two_sided_pval` /
    `compute_lik_ratio_bartlett_confidence_interval` (the plain
    best-available dispatcher, folded into the Bartlett TODO per its own
    judgment call) plus the `_approx`/`_exact` siblings -> `likelihood_tests`.
  - `compute_m_out_of_n_bootstrap_two_sided_pval` /
    `compute_m_out_of_n_bootstrap_confidence_interval` /
    `compute_subsampling_two_sided_pval` /
    `compute_subsampling_confidence_interval` -> resolved as extra methods
    under `nonparametric_bootstrap` (not a new capability -- they're
    alternate resampling schemes on the same component, same precedent as
    folding Bartlett variants into `likelihood_tests` rather than
    fragmenting capabilities per method variant).
  - `compute_param_bootstrap_confidence_interval` / `compute_param_bootstrap_pval`
    -> `parametric_likelihood_bootstrap` (real public methods on
    `InferenceParamLikelihoodBootstrap`, previously ungated).
  - The six new `get_supported_*_types()` accessors (own TODO above) ->
    folded into their owning bootstrap-family capability keys.
  Confirmed private/internal methods correctly excluded from the pattern
  match's public surface: `compute_effect_confidence_interval`,
  `compute_rr_bootstrap_basic_confidence_interval`,
  `compute_rr_bayesian_bootstrap_log_confidence_interval`,
  `compute_rr_jackknife_wald_two_sided_pval`/`_confidence_interval`,
  `compute_kk_gee_jackknife_wald_two_sided_pval`/`_confidence_interval`, and
  `compute_likelihood_test_two_sided_pval` (the `testing_type`-parameterized
  dispatcher into `score`/`lik_ratio`/`gradient`, already covered under
  `likelihood_tests` -- exactly the example the scope note called out).
  Landed as a permanent regression test, not a one-time pass:
  `test-capability-tables.R`'s `"public_methods_for_capability catalogs
  every compute_*pval/confidence_interval public method"`, which re-runs
  the same live-introspection enumeration and asserts the orphan set is
  empty (with an explicit, currently-empty `deliberately_uncatalogued`
  allowlist for any future dispatcher-style exception, so a deliberate
  exclusion has to be named in code, not silently forgotten). This new
  invariant test itself caught a pre-existing snapshot drift in
  `test-exact-incidence-migration-baseline.R` (the 3 legacy exact-incidence
  generator classes' hardcoded public-method-count snapshots, stale by
  exactly the 6 new accessor methods propagating transitively through
  `BayesianBootstrap` composition) and a fixture gap in
  `test-capability-tables.R`'s own `parametric_likelihood_bootstrap_public()`
  helper (missing the two newly-required param-bootstrap methods); both
  fixed. Verified via full targeted battery plus a repo-wide regression
  sweep (only pre-existing, unrelated failures in `test-design-inference.R`
  and `test-inference-suite-discovery.R` remain, both caused by a
  concurrent process editing files in the working tree during earlier
  passes, not by this change).

- [x] **Discovery-time applicability is response-type-only and name-pattern-
  derived (`infer_inference_response_types()`), with no way to know a
  class also requires specific *design-structure* properties (blocking,
  block-size equality, treatment-allocation probability) -- so
  `run_all_inference()`'s `applicable_design_classes` lists classes that
  are guaranteed to fail construction for the actual design being fit,
  discoverable only by constructing them and catching the `stop()`.
  Violates this file's own "Discovery is metadata-based and side-effect
  free" Definition-of-Done bullet.** Found 2026-08-20 via a user-reported
  `run_all_inference()` run where `InferenceAllSimpleWilcox` and
  `InferenceIncidCMH` both appeared as `status = "error"` rows with clear
  messages, prompting "why is introspection returning that it's valid?".
  Confirmed by reading source directly, not assumed -- three concrete
  cases, each an `initialize()`-time `stop()` with no matching registry
  metadata:
  - `InferenceAllSimpleWilcox` (`inference_all_simple_wilcox.R:27-33`):
    rejects `response_type == "incidence"` (Hodges-Lehmann degenerates on
    0/1 data) -- but `infer_inference_response_types()`
    (`inference_class_registry.R:415-426`) blanket-matches `^InferenceAll`
    class names to *every* response type (`continuous`, `incidence`,
    `count`, `proportion`, `survival`, `ordinal`), with no per-class
    override table, so this genuinely-incompatible pairing is
    indistinguishable from a genuinely-compatible one at discovery time.
  - `InferenceIncidCMH` (`inference_incidence_cmh.R:104-113`) and
    `InferenceIncidExtendedRobins` (`inference_incidence_extended_robins.R:
    62-74`): both reject non-blocking designs with `prob_T != 0.5`, and
    blocking designs with unequal block sizes or `prob_T != 0.5` -- a
    design-*structure* requirement `infer_inference_response_types()`
    (response-type-only) has no vocabulary for at all, regardless of
    per-class overrides.
  **Scope**: hoist each of these three classes' `initialize()`-time
  compatibility checks (currently ad hoc, duplicated-in-spirit `stop()`
  calls, one set of conditions per class) into a single reusable,
  introspectable predicate the class exposes without constructing a full
  instance -- e.g. a static/class-level `design_compatibility_reason(des_obj)`
  (returns `NA_character_` if compatible, else a one-line reason, mirroring
  `get_nonestimable_reason()`'s existing shape) that `initialize()` itself
  calls first (so the `stop()` message and the discovery-time reason can
  never drift apart -- single source of truth, same principle as the
  `get_supported_*_types()` accessors reading from the same constant their
  own `assertChoice()` validates against). Register it in
  `contracts_mixins.R` alongside the class's other contract metadata so
  it's enumerable, not another hand-maintained special case. Wire
  `run_all_inference_class_applicable_methods()`/`applicable_design_classes`
  to consult it (when present) against the actual `des_obj` being fit,
  before listing a class as applicable -- a class that fails this check
  should either be excluded from the results table entirely or reported as
  a distinct `status` (e.g. `"incompatible"`, not `"error"`) with the
  predicate's reason as `message`, so a real construction/estimation
  failure (`status = "error"`) stays distinguishable from "this class was
  never going to work for this design" from the very first `screen = TRUE`
  row streamed, not discovered mid-run. Audit for further instances beyond
  these three (grep every `initialize()` for a `stop()` gated on
  `des_obj$is_blocking_design()`/`get_prob_T()`/`get_block_ids()`/
  `get_response_type()` with no matching registry entry) rather than
  hand-fixing only the two/three classes a single user run happened to
  surface.

  **Done (2026-08-21)**: implemented as a universal, opt-in mechanism, not a
  hardcoded 3-class special case -- any `Inference` generator can define a
  self/private-free private method `design_compatibility_reason(des_obj)`
  (returns `NA_character_` if compatible, else a one-line reason string,
  mirroring `get_nonestimable_reason()`'s shape). Walked up the generator's
  inheritance chain and stored on the registry record by
  `infer_inference_design_compatibility_reason_fn()`
  (`inference_class_registry.R`, same "safe to call unbound" pattern as
  `infer_inference_requires_blocking_design()`/
  `infer_inference_supports_general_censoring()`, except the raw function is
  stored rather than invoked at registration time, since it needs a live
  `des_obj`). Consulted by a new `inference_class_design_compatibility_
  reason(nm, des_obj)` (`inference_suite.R`), wired into
  `discover_applicable_inference_classes()` alongside the existing missing-
  packages check -- a class with a non-`NA` reason is excluded from
  `applicable` into a new `incompatible_due_to_design_structure` named list
  (class name -> reason), the same "excluded like a missing-package class,
  not surfaced as a construction error" resolution the scope note called
  out as acceptable. Exposed via a new `Design$incompatible_inference_
  classes_due_to_design_structure()` public method, mirroring
  `unavailable_inference_classes_due_to_missing_packages()` exactly.
  **Audit for further instances (per the scope note's own instruction) found
  a fourth class beyond the three the user's bug report surfaced**:
  `InferenceAllKKWilcoxIVWC` (`KKWilcoxIVWCSource` in
  `inference_all_KK_wilcox_ivwc.R`) has the identical incidence-response and
  censored-survival rejections as `InferenceAllSimpleWilcox` -- found via a
  full-repo grep for `get_prob_T()`/`is_blocking_design()`/`get_block_ids()`
  usage plus every `InferenceAll*`-file `stop()` gated on `response_type ==`/
  `any_censoring`, not just re-checking the three named classes. (This
  particular class is already unconditionally excluded from discovery by the
  pre-existing `"IVWC" %in% nm` filter, so the fix is currently unreachable
  through discovery, but it's still correct for any direct
  `get_inference_class_metadata()` consultation and keeps the predicate
  consistent with its sibling.) Implemented `design_compatibility_reason` on
  all four: `SimpleWilcoxSource`/`KKWilcoxIVWCSource` (incidence + censored-
  survival rejection, identical logic), `InferenceIncidCMH` (even allocation;
  equal block sizes when blocking), `InferenceIncidExtendedRobins` (blocking
  required; even allocation; equal block sizes). Verified via
  `pkgload::load_all(compile = FALSE)` plus direct construction: an
  incidence-response `DesignSeqOneByOneBernoulli` correctly drops
  `InferenceAllSimpleWilcox` from `applicable_inference_class_names()` with
  reason `"wilcoxon_incidence_response_unsupported"`; a `prob_T = 0.7` design
  correctly drops `InferenceIncidCMH` with reason
  `"cmh_requires_even_allocation"`; an even-allocation design correctly keeps
  `InferenceIncidCMH` applicable; a continuous-response design correctly
  keeps `InferenceAllSimpleWilcox` applicable. Full targeted battery green
  (`test-mixin-contracts.R`, `test-cmh-flat-vector.R`,
  `test-inference-class-registry.R`,
  `test-incid-cmh-extended-robins-migration-golden.R`,
  `test-simple-wilcox-migration-golden.R` -- all zero failed/error/warning);
  the broader `test-inference-suite-discovery.R`/`test-inference-suite-run-
  all-inference.R` battery was still running in the background at write time
  (bootstrap-heavy, long-running independent of this change) and had not yet
  reported a result.

- [x] **`design_compatibility_reason()` duplicates, rather than unifies with,
  each class's own `initialize()`-time `stop()` checks.** Found during a
  2026-08-21 audit of the just-landed discovery-time-applicability TODO
  above (user: "check again to ensure these design-method audits and
  introspections are airtight"). The original scope explicitly asked for
  `initialize()` to *call* `design_compatibility_reason()` ("so the
  `stop()` message and the discovery-time reason can never drift apart --
  single source of truth"), but `InferenceAllSimpleWilcox$initialize()`
  (and, unaudited but presumably the same, `InferenceAllKKWilcoxIVWC`/
  `InferenceIncidCMH`/`InferenceIncidExtendedRobins`) still carries its own
  independent `stop()` conditions duplicating the exact same logic as its
  own `design_compatibility_reason()`. The two can silently drift apart if
  one is edited without the other (e.g. a future condition added to one
  and forgotten in the other). **Scope**: rewrite each of these four
  classes' `initialize()` to call `self$design_compatibility_reason(des_obj)`
  (or the unbound function directly, same "self/private-free" contract
  that already makes it safe to call before `super$initialize()`) and
  `stop()` with its returned reason string when non-`NA`, deleting the
  duplicated inline conditions. Verify the `stop()` message text callers
  currently depend on (if any test asserts on the literal message) still
  matches, or update those tests to match the new message derived from the
  reason code.
  **Done 2026-08-21.** All four classes' `initialize()` now call
  `private$design_compatibility_reason(des_obj)` and `stop()` on its
  reason (before `super$initialize()`, since the predicate only needs
  `des_obj`), deleting the duplicated inline `stop()` conditions --
  `InferenceAllSimpleWilcox`/`InferenceAllKKWilcoxIVWC` in
  `inference_all_simple_wilcox.R`/`inference_all_KK_wilcox_ivwc.R`,
  `InferenceIncidCMH`/`InferenceIncidExtendedRobins` in
  `inference_incidence_cmh.R`/`inference_incidence_extended_robins.R`.
  Per user feedback mid-implementation, the repeated "call the predicate,
  switch on the reason, stop() with the class's message" boilerplate was
  factored into a shared `stop_if_design_incompatible(design_compatibility_
  reason_fn, des_obj, reason_messages)` helper (`inference_suite.R`, next
  to `inference_class_design_compatibility_reason()`) rather than each
  class inlining its own `switch()`/`stop()`; each class now just passes
  its own `reason -> message` named list. All `stop()` message text was
  preserved verbatim (including `InferenceAllKKWilcoxIVWC`'s
  `class(self)[1]`-prefixed censoring message), so the existing literal-
  message-asserting tests (`test-design-inference.R`'s "CMH inference
  requires even treatment allocation"/"requires equal block sizes",
  `test-incid-cmh-extended-robins-migration-golden.R`'s four `stop()`
  message strings) needed no changes. All five touched files verified
  parse-clean via `parse()` (no `R CMD INSTALL`/`load_all(compile=TRUE)`
  run, per project rule).

- [x] **Three method-level (not class-construction-level) `stop()`s on
  incidence response are outside `design_compatibility_reason()`'s scope
  (a whole-class applicability gate) and degrade silently instead of
  erroring.** Found during the same 2026-08-21 audit, flagged as a related
  but distinct, unconfirmed loose end -- not verified to actually be
  reachable/exploitable, just noted:
  - `inference_all_abstract_rand.R:347-350` --
    `compute_rand_two_sided_pval()`-family: `stop("Randomization tests are
    not supported for incidence. Use Zhang method.")`, conditional on
    `!should_use_design_randomization_for_incidence()`.
  - `inference_all_abstract_rand_bootstrap_ci.R:96-97` --
    `stop("Bootstrap randomization confidence intervals are not supported
    for incidence.")`, conditional on no custom randomization-statistic
    function being supplied.
  - `inference_mixin_kk_gee_shared.R:131-146` -- two related `stop()`s
    gated on `should_use_zhang_incidence_randomization()`/
    `should_use_design_randomization_for_incidence()`.
  Since these are per-method (not per-class) and *conditional* on other
  runtime state (not simply "this class never works for this response
  type"), they don't fit `design_compatibility_reason()`'s per-class
  return shape directly. Unlike the class-level gap above, calling these
  methods today would hit `run_all_inference_call_ci_for_method()`/
  `_call_pval_for_method()`'s own local `tryCatch`, which swallows the
  error into a silent `pval`/CI `= NA` while still reporting `status =
  "ok"` and the attempted `method` label -- the same "silently wrong
  instead of an honest error" shape the `rand_bootstrap`-on-observational-
  design bug had (fixed 2026-08-21 via `des_obj$supports_randomization_
  draw()`), but this time gated on a narrower, method-specific condition
  `InferenceSuite` has no equivalent cheap pre-check for. **Scope**: first
  confirm whether any real design/class combination actually reaches these
  branches through `run_all_inference()` (may already be fully covered by
  the existing `supports_randomization_draw()` filter, in which case this
  closes as "not reachable, no action needed" -- verify before designing a
  fix); if reachable, decide whether a per-capability predicate (mirroring
  `design_compatibility_reason()`'s per-class one, but scoped to a
  capability instead) is warranted, or whether surfacing the swallowed
  error message onto the row (e.g. into `results_table$message`, which
  today only the outer `run_all_inference_one_class()` catch populates,
  not this inner one) is sufficient.
  **Reachability confirmed 2026-08-21 -- mixed, not closed.**
  `supports_randomization_draw()` alone does NOT cover these; each needed
  checking individually against which classes actually reach the guarded
  branch:
  - `inference_all_abstract_rand.R:347-350` (`InferenceRand`'s own
    `compute_rand_two_sided_pval`, pinned via
    `compute_rand_two_sided_pval = InferenceRand$public_methods$...`
    rather than `InferenceRandCI`'s Zhang-dispatching override) **IS
    reachable**: `InferenceIncidGCompRiskDiff`/`InferenceIncidGCompRiskRatio`
    (`inference_incidence_gcomp.R`), `KKNewcombeRiskDiffIVWCSource`
    (`inference_incidence_KK_newcombe_ivwc_univ.R`, pinned in
    `inference_incidence_newcombe_univ.R`), and the Miettinen-Nurminen
    incidence class in `inference_incidence_miettinen_nurminen_univ.R` all
    support `response_type = "incidence"` and pin this exact
    non-Zhang-dispatching method. Any incidence-response design that
    `supports_randomization_draw()` (e.g. plain `DesignSeqOneByOneBernoulli`)
    but is not `randomization_family() == "rerandomization"` (so
    `should_use_design_randomization_for_incidence()` is `FALSE`) hits the
    `stop()`, which `run_all_inference_call_ci_for_method()`'s inner
    `tryCatch` then silently downgrades to `pval = NA`, `status = "ok"`.
  - `inference_all_abstract_rand_bootstrap_ci.R:96-97` **is NOT reachable**:
    grepped every class composing the `RandomizationBootstrapCI` component
    (`compute_rand_bootstrap_confidence_interval`'s defining component) --
    only `SimpleWilcoxSource`/`KKWilcoxIVWCSource`
    (`inference_all_simple_wilcox.R`/`inference_all_KK_wilcox_ivwc.R`), and
    both already reject `response_type == "incidence"` unconditionally at
    `initialize()` (via `design_compatibility_reason()`, per the item
    above), so no live instance of any class with this method can ever
    have `response_type == "incidence"` when it runs. Closed, no action
    needed.
  - `inference_mixin_kk_gee_shared.R:131-146` **is NOT reachable** through
    the only incidence-response class that uses this mixin,
    `InferenceIncidKKCombined` (`inference_incidence_KK_combined.R`):
    every KK-matching-capable design (required generically by the
    registry's `requires_kk`/name-grep filter for any `*_KK_*` class) has
    `des_obj$is_a_kk_matching_capable() == TRUE`, which makes
    `should_use_zhang_incidence_randomization()`
    (`private$has_match_structure`-gated) always `TRUE` for this class, so
    the Zhang branch (lines 131-141) always returns before reaching the
    guarded `stop()` at line 147. Closed for the one class that currently
    exercises this mixin with incidence response -- would need re-checking
    if a future KK-GEE incidence class is added without the matching
    requirement.
  **Fixed 2026-08-21** (the first bullet's reachable silent-NA path; the
  other two closed as not-reachable above needed no code change). Took
  the per-capability-predicate approach: added a public
  `InferenceRand$supports_rand_pval_for_incidence()` accessor
  (`inference_all_abstract_rand.R`) that returns exactly the same
  condition `compute_rand_two_sided_pval()`'s own guard now calls instead
  of duplicating (`!self$supports_rand_pval_for_incidence()` replaces the
  old inline three-clause condition -- same single-source-of-truth
  discipline as the class-level `design_compatibility_reason()` fix
  above). `run_all_inference_call_pval_for_method()`
  (`inference_suite.R`) checks it for the `"rand"` sentinel specifically,
  guarded by `is.function()` since only `InferenceRand` subclasses have
  it: when `FALSE`, degrades to the existing `list(pval = NA_real_,
  method = NA_character_)` "no capability" shape used everywhere else in
  this file (not an attempted-and-failed row), so a `"rand"` pval that
  will provably `stop()` is never attempted at all, matching this file's
  "only methods that are supported are run" principle rather than being
  caught and swallowed into a misleadingly plain `pval = NA` on a
  `status = "ok"` row. No discovery-time (pre-construction) filter was
  needed -- unlike `design_compatibility_reason()`, this condition only
  needs `des_obj`-level facts (`response_type`, `randomization_family()`)
  plus `custom_randomization_statistic_function`, which is always `NULL`
  through `InferenceSuite`'s own construction path -- but implemented as
  a post-construction accessor check anyway, for parity with how every
  other per-row capability check in `run_all_inference_call_ci_for_
  method()`/`_call_pval_for_method()` already works (typed-sentinel
  `type` probing included), rather than introducing a second, differently
  -shaped discovery mechanism for one sentinel.

## Definition of Done

The hierarchy is complete when:

- Inheritance is shallow and represents substitutable estimator types only.
- Every class has valid metadata.
- Every component has an enforced contract.
- Effective components are inherited and composed once.
- Effective capabilities are derived from components and class-owned hooks.
- Public optional method presence exactly equals capabilities.
- Likelihood tier constrains capabilities but does not create APIs.
- Every component dependency, requirement, and collision is validated at class
  definition time.
- Every mutable field has one owner.
- Discovery is metadata-based and side-effect free.
- No legacy aliases exist.
- No optional API is disabled through private support flags or throwing stubs.
- No component depends on accidental inheritance details.
- No source uses implementation-body copying or generator-private access.
- Numerical regression tests pass for every migrated family.
