# Extending EDI with Custom R6 Inference and Design Classes

> **Depends on:** none — `fix_inference_hierarchy.md` (closed 2026-08-23) and
> `fix_design_hierarchy.md` (closed 2026-08-17), both in
> `../finished_features/`, are the architecture this contract is written
> against. This is the v1.0.0 **external extension contract**; it freezes with
> the release (`release_v1_0_0.md` item 6). (Global ordering: see
> `_master.md`.) In-package authors adding a new model follow
> `../contracts/new_model_creation.md`, which this document only summarizes.

Updated 2026-08-23 for the finished shallow-hierarchy architecture.

EDI is implemented with R6 classes. Advanced users can define their own R6
classes outside the package and reuse EDI's design storage, response handling,
randomization, bootstrap, and summary methods.

## How EDI's classes are built (what changed)

Both hierarchies are now shallow and component-based. Inheritance answers only
"is every child substitutable for this parent as the same kind of estimator /
design?"; every optional behavior is a registered **component** composed by a
factory, and every optional public method is backed by a **capability**:

- Every inference class in the package is built by
  `define_inference_class(classname, inherit, components, public, private,
  active, metadata, overrides, ...)` (`EDI/R/contracts_mixins.R`) from
  components registered in `EDI_COMPONENT_SPECS` (`Wald`, `LikelihoodTests`,
  `NonparametricBootstrap`, `RandomizationTest`, `BayesianBootstrap`,
  `Jackknife`, `ParametricLikelihoodBootstrap`, `KKPassThrough`, `KKGEE`,
  `KKGLMM`, per-model `*Likelihood` components, …). The factory validates
  component contracts, collisions, capability tables, and root-owned state at
  definition time; no package class hand-splices component lists, and the
  legacy algorithmic inheritance ladder (`InferenceRand`,
  `InferenceNonParamBootstrap`, `InferenceAsymp`, `InferenceAsympLik`,
  `InferenceParamBootstrap`, …) survives only as internal component sources
  with zero concrete descendants. **Do not inherit from those ladder classes
  in an extension** — they are not a supported surface and may be deleted.
- Every design class is built by `define_design_class(classname, inherit,
  components, public, private, active, overrides, ...)`
  (`EDI/R/design_class_factory.R`) over the design component registry
  (`BlockingStructure`, `MatchingStructure`, `ClusterStructure`,
  `SequentialStrataBootstrap`, `BatchWPregeneration`;
  `EDI/R/design_component_registry.R`), with `DesignFixed` and
  `DesignSeqOneByOne` as the two timing-family bases directly under `Design`.
- Capabilities are metadata, queried with `obj$capabilities()` /
  `obj$supports("<capability>")` on both `Inference` and `Design` objects.
  Public optional method presence equals capability presence — there are no
  `supports_*()` flag pairs or throwing stubs on concrete classes. Discovery
  (`InferenceSuite`, `Design$applicable_inference_class_names()`,
  `Design$unavailable_inference_classes_due_to_missing_packages()`) reads the
  class registries only (`EDI_INFERENCE_CLASS_REGISTRY`,
  `EDI_DESIGN_CLASS_REGISTRY`), populated by a scan of the **package
  namespace** at load time.

The consequence for external authors is simple: build on the **custom shells**
below (themselves factory-built, so the components and capabilities are
already wired), implement the one documented hook, and call your class
directly — registry-driven discovery will never find an external class.

The custom-extension base classes are intentionally internal while the extension
contract is experimental. Retrieve them with `getFromNamespace()`:

```r
library(EDI)
library(R6)

InferenceCustomAsymp <- getFromNamespace("InferenceCustomAsymp", "EDI")
InferenceCustomRand <- getFromNamespace("InferenceCustomRand", "EDI")
InferenceCustomBoot <- getFromNamespace("InferenceCustomBoot", "EDI")
```

## Inference Contract

A custom asymptotic inference class should inherit from `InferenceCustomAsymp`
(`define_inference_class(inherit = Inference, components = c("Wald",
"NonparametricBootstrap"), metadata = list(likelihood_tier = "none"))`) and
implement a public `fit(estimate_only = FALSE)` method. `fit()` returns a
named list with:

- `estimate`: required numeric scalar treatment-effect estimate.
- `se`: optional numeric scalar standard error.
- `df`: optional degrees of freedom. Use `NA_real_` for z inference.
- `model`: optional fitted model object retained by `get_mod()`.
- `nonestimable_reason`: optional character scalar used when the estimate or
  standard error is unavailable.

Use public accessors instead of private fields:

- `get_response()`
- `get_treatment()`
- `get_covariates()`
- `get_analysis_data()`
- `get_design_object()`
- `get_response_type()`

### Randomization Inference

Custom randomization-inference classes should inherit from
`InferenceCustomRand` (`inherit = Inference`, `components =
"RandomizationTest"`, `likelihood_tier = "none"`).

Subclasses implement `fit(estimate_only = FALSE)` and return a named list with
the same required `estimate` field used by `InferenceCustomAsymp`. Standard
errors and degrees of freedom are not part of this minimal contract; the class
only promises `fit()`/`compute_estimate()` behavior plus the randomization-test
machinery supplied by EDI.

### Bootstrap Inference

Custom bootstrap-inference classes should inherit from `InferenceCustomBoot`
(`inherit = Inference`, `components = "NonparametricBootstrap"` — which
transitively brings the randomization-test/CI machinery it depends on), so
subclasses reuse EDI's bootstrap machinery while supplying only the estimator.

Subclasses implement `fit(estimate_only = FALSE)` and return a named list with
the required numeric scalar `estimate`. Optional `model` and
`nonestimable_reason` fields are supported, but no standard error or degrees of
freedom is required for the minimal bootstrap extension contract.

## Example

```r
InferenceMedianDiff <- R6Class(
  "InferenceMedianDiff",
  inherit = InferenceCustomAsymp,
  # Required when subclassing EDI's factory-built classes: lazily loaded
  # components install their real methods onto the object after construction,
  # which needs an unlocked environment.
  lock_objects = FALSE,
  public = list(
    fit = function(estimate_only = FALSE) {
      dat <- self$get_analysis_data()
      y_t <- dat$y[dat$w == 1]
      y_c <- dat$y[dat$w == 0]

      est <- stats::median(y_t) - stats::median(y_c)
      if (estimate_only) {
        return(list(estimate = est))
      }

      list(
        estimate = est,
        se = sqrt(stats::var(y_t) / length(y_t) + stats::var(y_c) / length(y_c)),
        df = length(y_t) + length(y_c) - 2,
        model = NULL
      )
    }
  )
)

des <- DesignFixedBernoulli$new(n = 20, response_type = "continuous")
des$add_all_subjects_to_experiment(data.frame(x = seq_len(20)))
des$overwrite_all_subject_assignments(rep(c(0, 1), each = 10))
des$add_all_subject_responses(rnorm(20))

inf <- InferenceMedianDiff$new(des)
inf$compute_estimate()
inf$compute_asymp_two_sided_pval()
inf$compute_asymp_confidence_interval()
inf$compute_bootstrap_two_sided_pval(B = 501)
inf$capabilities()   # inherited from InferenceCustomAsymp's registry record
inf$supports("wald")
```

## Subclassing Rules And Capability Detection

- Always pass `lock_objects = FALSE` when subclassing an EDI inference or
  design class. EDI's classes are assembled by `define_inference_class()` /
  `define_design_class()` and inference classes use lazily loaded components
  that install methods onto `private` after construction; a locked subclass
  fails at first use with a locked-binding error. Some classes also create
  private config fields dynamically inside `initialize()`, which likewise
  requires an unlocked environment.
- Inherit only from the custom shells (or, with care, from a concrete exported
  class whose behavior you are specializing). Never inherit from the internal
  legacy ladder generators or from abstract `*Abstract*` bases, and never
  splice component `$public`/`$private` lists into your own class — the
  package bans that for itself (`test-static-cleanup-guardrails.R`) and the
  factory's validation is the only supported way to compose components.
- External subclasses are not registered in `EDI_INFERENCE_CLASS_REGISTRY` /
  `EDI_DESIGN_CLASS_REGISTRY` (only the package namespace is scanned at load
  time). Capability queries resolve through the **nearest registered
  ancestor**: `Inference$capabilities()` walks `class(self)` and returns the
  first registered class's effective capabilities, so an
  `InferenceCustomAsymp` subclass reports the Wald/bootstrap capabilities it
  inherited, and `supports()` works. Public methods you *add* on top are
  ordinary R6 methods — callable directly, but not capabilities, so
  capability-driven filtering (`InferenceSuite`, `SimulationFramework`) does
  not see them.
- Registry-driven discovery never lists an external class: `InferenceSuite`,
  `Design$applicable_inference_class_names()`, and the comprehensive test
  harness enumerate registered package classes only. Construct and call
  extension classes explicitly.
- On the design side the same fallbacks are deliberate (`fix_design_hierarchy.md`,
  TODO-13): `Design$capabilities()`/`supports()` are instance-level and work
  for any subclass; `is_design_class_abstract()` returns `FALSE` for any
  unregistered name, so custom designs stay freely instantiable; and the one
  generator-level read (`supports_batch_w_pregeneration`) falls back to
  checking the generator's public methods for unregistered subclasses.
- Root-owned state (`m`, `X`, `w`, `y`, `optimization_alg`, caches, …) belongs
  to `Inference`; do not redeclare those private fields in a subclass. Read
  data through the public accessors listed above.

## Custom Designs

EDI provides factory-built internal bases for user-defined designs
(`EDI/R/design_custom_extensions.R`):

```r
DesignFixedCustom <- getFromNamespace("DesignFixedCustom", "EDI")
DesignCustomSequential <- getFromNamespace("DesignCustomSequential", "EDI")
```

- `DesignFixedCustom` (`define_design_class(inherit = DesignFixed, components
  = character())`): implement public `draw_assignments(r)` and return an
  `n x r` 0/1 assignment matrix. EDI validates the shape and values (when
  asserts are enabled) and routes all randomization draws through it.
- `DesignCustomSequential` (`define_design_class(inherit = DesignSeqOneByOne,
  components = character())`): implement public `assignment_rule()` and
  return a scalar 0/1 assignment for the current subject.

EDI handles subject storage, response recording, and validation. Pass
`lock_objects = FALSE` here too. Use `des$capabilities()` / `des$supports()`
(`"blocking"`, `"matching"`, `"cluster"`, `"batch_w_pregeneration"`,
`"resampling"`, `"randomization_draw"`, `"resampling_replay"`) rather than
class-identity checks when your inference code needs to know what a design
can do.

```r
DesignFixedAlternating <- R6Class(
  "DesignFixedAlternating",
  inherit = DesignFixedCustom,
  lock_objects = FALSE,
  public = list(
    draw_assignments = function(r = 1) {
      n <- self$get_n()
      matrix(rep_len(c(0, 1), n), nrow = n, ncol = r)
    }
  )
)
```

## For in-package authors (summary; the real contract is elsewhere)

Adding a class *inside* the package is a different, heavier contract:

- Inference: `../contracts/new_model_creation.md` — `define_inference_class()`
  with exact `components`/`metadata`/`overrides`; the class-registry lookup
  tables in `EDI/R/inference_class_registry.R` that the load-time scan reads
  (`infer_inference_direct_components()` switch, `EDI_INFERENCE_ESTIMAND_TAGS`,
  `EDI_INFERENCE_CLASSES_USING_COVARIATES`/`_IGNORING_COVARIATES`, the
  `Inference*` name-prefix convention that drives `response_types` and the
  name-token tier inference); the capability tables (`capability_requires`,
  `public_methods_for_capability`); the Source Invariants of
  `fix_inference_hierarchy.md` (no root-owned state in a component's
  `owns_state`, no raw splicing, no `supports_*` flags); roxygen per
  `fix_documentation.md`; tests; C++/Python/benchmark/harness registration.
- Design: `define_design_class()` with components from
  `design_component_registry.R`; add the class to the name tables the
  load-time scan reads (`EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME` — mandatory,
  the scan errors without it; `EDI_DESIGN_ABSTRACT_CLASS_NAMES` for abstracts;
  `EDI_DESIGN_BATCH_W_PREGENERATION_CLASS_NAMES`,
  `EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES`,
  `EDI_DESIGN_SEED_REPRODUCIBLE_SINGLE_THREAD_ONLY_CLASS_NAMES`,
  `EDI_DESIGN_REQUIRED_PACKAGES_BY_NAME` as applicable); keep
  `timing_family` polymorphism through `DesignFixed`/`DesignSeqOneByOne` only;
  see `fix_design_hierarchy.md`'s Architectural Rule and Definition of Done.

## Custom Shell Audit

The current custom shell set is sufficient for the documented extension
contract:

- `DesignFixedCustom` covers fixed-sample assignment generators.
- `DesignCustomSequential` covers one-subject-at-a-time assignment rules.
- `InferenceCustomAsymp` covers custom estimators that provide Wald-style
  standard errors and optional degrees of freedom.
- `InferenceCustomRand` covers custom estimators that should reuse EDI's
  randomization-test machinery.
- `InferenceCustomBoot` covers custom estimators that should reuse EDI's
  jackknife/bootstrap machinery without requiring an asymptotic standard error.

Do not add response-family-specific custom inference shells unless a concrete
extension use case needs response-specific behavior beyond the generic analysis
data accessors. Most response/model R6 classes in `EDI/R` are concrete
implementations, not separate user extension surfaces.

No `InferenceCustomExact` or parametric-bootstrap custom shell is needed for
this contract. The `ExactTest` component dispatches exact p-value and interval
methods through private exact-test implementations, and the
`ParametricLikelihoodBootstrap` component requires likelihood-null
simulation/refit hooks. Those are not simple
`fit()`/`compute_estimate()` shells, so exposing them would need a separate API
design rather than another thin custom R6 wrapper.
