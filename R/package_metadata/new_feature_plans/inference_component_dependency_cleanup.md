# Inference Component Dependencies: Declare Only What Each Component Uses

> **Depends on:** none. A maintenance follow-up to the closed
> `../finished_features/fix_inference_hierarchy.md`. Release: v1.0.5
> (`release_v1_0_5.md → TODO-97`), slated there by user decision 2026-10-19
> as cleanup work. *(maintenance)*: no output or behavior change.

Date: 2026-10-19

## Problem

Each inference component's `dependencies` field in `EDI_COMPONENT_SPECS`
(`R/EDI/R/contracts_mixins.R`) copies the old inheritance ladder: every
component depends on the class its source used to `inherit` from. The
hierarchy migration kept that ladder on purpose, as internal component
sources. So the declared graph records packaging, not what the code needs.
For example, `Wald` (source `InferenceAsymp`, which still declares
`inherit = InferenceJackknife`) declares `dependencies = "Jackknife"`, but
`inference_all_abstract_asymp.R` calls no Jackknife method.

Found while drawing the component diagram for the HUJI seminar talk
(2026-10-19): a chain that reads "Wald needs Jackknife" is not true.

## What a static scan shows (2026-10-19, rough)

This scan matched `private$`/`self$`/`super$` calls in each source file against
the methods defined in the other components' source files. It misses methods
defined in `InferenceExt*` file-splits or on the root, and it counts
same-name overrides as uses. Treat it as a lead, not a result.

Declared edges and calls found across them:

| Declared edge | Calls found |
|---|---|
| `RandomizationCI → RandomizationTest` | 4 (real) |
| `NonparametricBootstrap → RandomizationCI` | **0** |
| `RandomizationBootstrap → NonparametricBootstrap` | 8 (real) |
| `RandomizationBootstrapCI → RandomizationBootstrap` | 5 (real) |
| `BayesianBootstrap → RandomizationBootstrapCI` | **0** |
| `Wald → Jackknife` | **0** |
| `LikelihoodTests → Wald` | 2 (real) |
| `ParametricLikelihoodBootstrap → LikelihoodTests` | 1 (real) |

The undeclared calls are the larger issue. The real graph does not follow the
chains and has cycles:

- `NonparametricBootstrap` and `BayesianBootstrap` call the resampling-cache
  and worker-contract helpers defined with `RandomizationTest`
  (`get/set_cached_resampling_distribution`, `load_resampling_draw_into_worker`,
  `get_resampling_draw_contract`).
- `Jackknife` calls `NonparametricBootstrap` helpers
  (`approximate_jackknife_distribution_beta_hat_T_private`,
  `bootstrap_estimates_extreme`), and `NonparametricBootstrap` calls
  `Jackknife` helpers (`assert_jackknife_supported`,
  `normalize_jackknife_unit`). That is a cycle.
- `Wald` calls design-backed bootstrap-worker helpers that live in
  `NonparametricBootstrap`.
- `BayesianBootstrap` calls the `NonparametricBootstrap` CI and extreme-value
  helpers directly.

Today these calls resolve only because the declared chains happen to load
the right code together.

## Goal

1. Every `dependencies` entry is an edge the component's code actually calls.
2. Shared infrastructure that several components call (the resampling cache
   and worker contract, bootstrap CI and extreme-value helpers, the jackknife
   unit helpers) moves into its own small component or components. This
   removes the cycles.
3. Every concrete class keeps exactly the same effective component set and
   public and private method set as today. Where a class got a component only
   through a packaging edge (e.g. `Jackknife` through `Wald`), it now lists
   that component explicitly. `resolve_component_dependencies()` still
   rejects listing a component that is also a transitive dependency.

## Implementation TODOs

- [x] TODO-1: **Freeze a golden.** For every concrete `Inference*` class,
  record the resolved effective components and the full public and private
  method names with their owners. Use only the registry and the generators,
  never constructors. This is the before/after gate for every later step.
  **Baseline captured 2026-10-19:**
  `R/package_tests/testthat_bulk/fixtures/inference_component_registry_baseline.csv` records
  all 106 concrete classes (8,172 public and 28,534 private method-owner
  bindings), generated from the registry and R6 generators without
  instantiating a class. Its SHA-256 is
  `6059f1a6bf59d2532224ee92a57ba009e6874fd4e0fdeb81ed683153fee65e8e`;
  the source revision was `4f7a6e4ca82829e880c15a76699701a95e5e83b9`.
  The existing registry test now compares the complete current surface to
  this golden. Source-loaded with `compile = FALSE`, the focused test file
  passed; this was registry-only and invoked no native kernels.
- [x] TODO-2: **Measure the real graph.** Add a test helper that builds the
  component call graph from parsed function bodies, not regex. It covers the
  `InferenceExt*` file-splits and root methods, and excludes same-name
  overrides. It must reproduce or correct the table above.
  **Acceptance design audited 2026-10-20 (still not a graph result):** keep
  method-body origin separate from the final dispatch binding. A read-only AST
  inventory against the TODO-1 class set found 97 factory-built concrete
  classes and 9 direct-R6 concrete leaves. Of the factory classes, 94 inherit
  directly from `Inference`, two (`InferenceCountHurdlePoisson` and
  `InferenceCountZeroInflatedPoisson`) inherit from
  `InferenceCountZeroAugmentedPoissonAbstract`, and one
  (`InferenceRandCustom`) inherits from `InferenceCustomRand`. Eight of the
  raw-R6 leaves inherit directly from factory-built parents; the remaining
  leaf, `InferenceIncidKKModifiedPoisson`, inherits through raw bridge
  `InferenceAbstractKKModifiedPoisson`, whose parent is factory-built
  `InferenceAbstractKKMarginalIncid`. The 9 raw leaves are
  `InferenceCountZeroInflatedNegBin`, `InferenceIncidKKCondLogitGLMMIVWC`,
  `InferenceIncidKKCondLogitGLMMOneLik`, `InferenceIncidKKModifiedPoisson`,
  `InferenceOrdinalKKCLMM`, `InferenceOrdinalKKCLMMCauchit`,
  `InferenceOrdinalKKCLMMCloglog`, `InferenceOrdinalKKCLMMProbit`, and
  `InferencePropKKGLMM`.

  The source-backed acceptance rule is:

  1. For each class generation, compute the dispatch map from inherited R6
     methods, then the class's components in the literal `components=` source
     order after dependency expansion, then that class's host entries. R6
     child entries override parent entries. Factory semantics are explicit in
     `define_inference_class()` and `combine_component_slot()`:
     `R/EDI/R/contracts_mixins.R:3321-3388,3653-3699`. The existing
     `test-registry-component-drift.R` checks factory component set parity,
     but explicitly does not check source order; TODO-2 must parse that order
     from the class call rather than assume the registry switch's order.
  2. Tag each active function body with its origin independently of the
     dispatch slot: a direct method from a registered component's
     `source_name` originates in that component; a body explicitly aliased to
     a component method keeps that origin even when the concrete class is the
     dispatch owner; an inline/non-alias host body is a host node, not a
     component caller. Source extraction is direct-slot-only
     (`inference_component_source_parts()`,
     `R/EDI/R/contracts_mixins.R:2675-2689`); a parent source's methods are
     accounted for through its own component/source entry, not copied into a
     child's source owner. `InferenceExt*` bodies spliced into a component's
     source class belong to that component; an extension with its own
     registered `source_name` is its own component source.
  3. Emit component edges only from active bodies whose origin is a component;
     resolve `self$` and `private$` targets through the final concrete
     dispatch map and map the selected body's origin. Do not emit edges from
     the losing same-name bodies or from a collision alone. Resolve `super$`
     through the active generator's actual R6 parent chain, not the flattened
     component order. Root `Inference` methods are a root source/provider.

  Named check cases: `InferenceAllKKMeanDiffIVWC` explicitly host-overrides
  `compute_rand_two_sided_pval` with
  `InferenceRand$public_methods$compute_rand_two_sided_pval` and declares the
  override (`R/EDI/R/inference_all_KK_mean_diff_IVWC.R:299-315`). Its dispatch
  owner is the host class, but its body origin is `RandomizationTest`; the
  same-name `RandomizationCI` body is inactive. This explains the earlier
  apparent order anomaly. The raw-leaf cases must also prove child-vs-parent
  override handling: e.g. `InferenceOrdinalKKCLMMCauchit` overrides
  `clmm_link` under `InferenceAbstractKKOrdinalCLMM`, while
  `InferenceIncidKKModifiedPoisson` adds a raw-R6 bridge level. The TODO-1
  golden can check the resulting method-name surface (root + effective
  source methods matched all 106 golden name sets in a compile-free probe),
  but its `method@owner` entries identify only concrete R6 generator owners;
  they cannot assert component body origin. TODO-2 must compare its parser's
  method-name surface with TODO-1 and assert origin/dispatch separately.
  **Boundary audit 2026-10-20:** the existing parser contract test exercises
  `self$`/`private$`/`super$` references in hand-built component bodies, not
  source-order extraction or ownership in composed classes. A standalone
  fixture for `components=` parsing would only test a test-local parser until
  the production graph helper exists, while a partial resolver risks giving
  false edges for aliases/host overrides. Therefore do not split out a
  parser-only acceptance item: add the AST source reader and its literal
  component-order fixture together with the first dispatch/origin resolver
  tests, then enforce the full named cases above and TODO-1 surface equality.
  **Acceptance test, 2026-10-20:** `test-inference-component-call-graph-acceptance-reference.R`
  now runs the source AST reader and dispatch/origin resolver over all 106
  concrete inference classes. With `pkgload::load_all(..., compile = FALSE)`,
  it passed 23 assertions: literal source component order, the full TODO-1
  class/method-owner surface, the `InferenceAllKKMeanDiffIVWC` aliased body
  origin, the `InferenceOrdinalKKCLMMCauchit` host override and retained
  parent method, the `InferenceIncidKKModifiedPoisson` raw-R6 bridge, and the
  positive/zero edges in the original dependency table including the
  Jackknife/bootstrap cycle. The graph probe contained 36,114 method rows,
  66,969 call references, and 49,772 component edges. The TODO-1 fixture
  remains unchanged; the test explicitly accounts for TODO-98's three
  subsequent private guard methods on `InferenceSurvivalWeibullRegr`, so
  further method drift still fails rather than silently refreshing the
  golden. The bulk test is registered in both runtime tiers. No native build
  or comprehensive-result operation was involved.
- **Maintainer decision gate before TODO-3 (2026-10-20):** the AST test confirms
  three packaging-only edges and the real `Jackknife`↔`NonparametricBootstrap`
  cycle, but it does not choose extraction boundaries. Before moving helpers,
  approve the shared-component grouping/names and how that cycle is broken;
  `ResamplingCore` and `BootstrapCIHelpers` remain examples, not a settled
  architecture. Keep TODO-1's exact per-class method/component golden as an
  invariant; no refactor or dependency rewrite should precede this choice.
- [x] TODO-3: **Extract shared infrastructure.** Move the cycle-causing shared
  helpers into new component(s), for example `ResamplingCore` (resampling
  cache and draw/worker contract) and `BootstrapCIHelpers`. The original
  components then depend on them. No method body changes; moves only.
  **Done 2026-10-22 (Option A):** one `ResamplingCore` component
  (`inference_all_abstract_resampling_core.R`) holds the resampling cache and
  draw-contract helpers, `normalize_jackknife_unit`/`assert_jackknife_supported`,
  `bootstrap_estimates_extreme` with its threshold field, and the `NULL`
  `create_bootstrap_worker_state()` default. Details, golden delta and tests:
  `release_v1_0_5.md → TODO-97`.
- [x] TODO-4: **Rewrite the dependencies** to match TODO-2's graph. Drop
  `Wald → Jackknife`, `NonparametricBootstrap → RandomizationCI` and
  `BayesianBootstrap → RandomizationBootstrapCI` if they are confirmed
  packaging-only. Add explicit `components = c(...)` entries to classes so
  TODO-1's golden is unchanged.
  **Done 2026-10-22:** the three edges dropped; new edges `Jackknife`,
  `BayesianBootstrap`, `Wald` → `NonparametricBootstrap`,
  `RandomizationBootstrap` → `RandomizationTest`, and `RandomizationTest`,
  `NonparametricBootstrap` → `ResamplingCore`. 94 classes list the formerly
  implied components; the golden changes only by the reviewed delta recorded in
  the TODO-97 entry (`ResamplingCore` added, 15 forced reorders, 3 classes gain
  Core methods).
- [ ] TODO-5: **Retire the ladder parents behind the sources where possible.**
  A source class that still `inherit`s from another ladder class only to make
  its own code load should stop doing so once TODO-4 lands. Keep the
  existing guardrail test that enumerates retained ladder generators in sync.
- [x] TODO-6: **Guard against regression.** Add a test that fails when a
  declared dependency has zero calls, or when a component calls another
  component's method without declaring it, directly or transitively.
  **Done 2026-10-22** in `test-inference-component-call-graph-acceptance-reference.R`,
  restricted to the resampling/Wald/likelihood family components; virtual-hook
  edges (caller defines the hook, or the hook's base is in its closure) are
  accepted.
- [x] TODO-7: **Verify.** TODO-1 golden identical; the inference contract and
  static-cleanup guardrail suites pass; the pre-push structural gates pass.
  No `comprehensive_tests` rerun is needed, because no computation changes.
  **Done 2026-10-22** with the reviewed golden delta (not "identical"; see
  TODO-97), an acyclicity test, and the focused suites listed in the TODO-97
  entry. The pre-push hook itself was not run.

## Non-goals

- No change to any estimate, p-value, CI, or public API.
- No change to the shallow-hierarchy rules or the class factory's contract.
- Design-side components (`define_design_class`) are out of scope. Check them
  with the same scan afterwards, as a separate item.
