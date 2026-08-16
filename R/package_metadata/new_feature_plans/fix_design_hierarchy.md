# Future Design Hierarchy

> **Depends on:** none — foundational (design-side twin of `fix_inference_hierarchy.md`). Blocks `multi_arm_designs.md` Phase 1, `sequential_inference.md` (public accessors), `save_load_api.md` (component-owned state). (Global ordering: see `_master.md`.)

Date: 2026-08-12

## Purpose

This document specifies the target `Design*` architecture, mirroring
`fix_inference_hierarchy.md`'s shift from "inheritance carries every optional
behavior" to "inheritance answers substitutability; components answer capability."
It is not a patch plan for the current inheritance ladder. The `Design*` hierarchy
has the identical disease the `Inference*` hierarchy had before that rewrite:
optional, cross-cutting structure (blocking, matching, clustering) is wired into
the inheritance spine instead of composed in, capability is signaled by
overridable booleans and bare class-name checks instead of validated metadata,
and several call sites reach past the object's public API entirely (private-field
sniffing, generator-shape sniffing) to find out what a design can do.

This plan was written immediately after adding `ObservationalDesign`,
`ObservationalDesignBlocks`, and `ObservationalDesignMatching` under the *current*
architecture. All three are cited throughout as concrete evidence of the problem
(they had to use a throwing-stub retraction and a documented "don't extend the
sibling class or you'll silently lose the real bootstrap" landmine) and are named
as first migration targets once the new architecture exists.

## Survey Method

Full inventory: all 33 `R6::R6Class(...)` definitions across
`R/EDI/R/design_*.R` (`Design`, 3 shared abstract bases, 26 concrete fixed/sequential
designs, 3 observational designs), their `inherit=` chains, every characterization-flag
override, every private capability-ish field set in each constructor, every
`draw_ws_raw`/`draw_bootstrap_indices` override, every throwing stub, and every
`is()`/`inherits()`-based dispatch site in `inference_*.R` and `simulations_framework.R`
that reads design *identity* rather than a queryable capability. Citations below are
file:line against that survey.

## Architectural Rule

Inheritance answers one question:

```text
Can every child be substituted for this parent as the same kind of design?
```

Components answer a different question:

```text
Which optional structural capabilities and resampling behaviors does this design expose?
```

Do not use inheritance to distribute blocking, matching, clustering, allocation-matrix
validation, or batch-pregeneration behavior. These are used by only a subset of
concrete designs, are combined in different ways per design (e.g. `DesignFixedBinaryMatch`
is blocking-*and*-matching-capable; `DesignFixedBlocking` is blocking-capable but never
matching-capable; `DesignFixedRerandomization` inherits both ancestries today but is
[explicitly documented as neither](#evidence-of-the-problem), because its `private$m` is
intentionally left unset), and none of them constrain what a design fundamentally *is*.

The one thing that legitimately *is* substitutability, and should stay inheritance, is
**subject-arrival timing**: a design either has a fixed sample size known at
construction (`DesignFixed`) or subjects arrive one at a time with assignment decided on
arrival (`DesignSeqOneByOne`). Every fixed design is substitutable for `DesignFixed`;
every sequential design is substitutable for `DesignSeqOneByOne`. Nothing else in the
current spine has that property.

The target hierarchy is shallow:

```text
Design
  -> DesignFixed        (fixed n at construction)
  -> DesignSeqOneByOne   (subjects arrive one at a time)
      -> KK family bases  (see "Allowed Family Bases" below -- the one place
                             deeper inheritance is legitimate)
```

Allowed parents:

- `Design`: owns root subject/response/covariate storage, lifecycle, the minimal
  `draw_ws_according_to_design()`/`get_w()`/`get_n()` contract, and capability-query
  methods (`supports()`, `capabilities()`).
- `DesignFixed` / `DesignSeqOneByOne`: the two substitutable timing families. Own only
  timing-specific bookkeeping (fixed-size arrays vs. growing arrays,
  `add_all_subjects_to_experiment()` vs. `add_one_subject()`), nothing structural.
- Family bases: allowed only when every descendant is substitutable for the base and the
  base does not expose optional structural capabilities as inherited side effects. The
  KK sequential-matching family (`DesignSeqOneByOneKK14` -> `DesignSeqOneByOneKK21` ->
  `DesignSeqOneByOneKK21stepwise`) is the one place in the current codebase that
  satisfies this: each concrete class genuinely refines the previous one's
  `assign_wt()`/weight computation, every descendant is a KK14 design, and the family
  doesn't leak matching-capability logic to non-KK siblings. Keep this as inheritance;
  it is not the problem this plan targets.
- Concrete designs: provide the mandatory assignment-drawing hook
  (`draw_ws_raw`/`assign_wt`), and declare which structural components and metadata they
  compose in.

Disallowed parents:

- `DesignBlocking` / `DesignMatching` as mandatory ancestry for every fixed and sequential
  design (see "Evidence of the Problem" below). These become components.
- Any base whose descendants must retract an inherited capability with a throwing stub
  (`ObservationalDesign`'s `draw_ws_raw`, `DesignMatching`'s abstract `draw_ws_raw` stub,
  `DesignSeqOneByOne`'s `assign_wt` stub, `DesignFixedCustom`'s `draw_assignments` stub,
  `DesignCustomSequential`'s `assignment_rule` stub -- design_matching_abstract.R:42,
  design_observational.R:84-86, design_seq_one_by_one_abstract.R:178,
  design_custom_extensions.R:18-20,57-59). A required hook is fine (every concrete design
  needs exactly one drawing mechanism); a hook whose *only* body is `stop()` to signal
  "this concrete design has no drawing mechanism at all" is not -- that should be
  declared metadata (`randomization = "none"`), not code that must be called to discover
  it errors.

## Evidence of the Problem

1. **Mandatory blocking/matching ancestry for designs that use neither.**
   `Design -> DesignBlocking -> DesignMatching -> DesignFixed` and
   `Design -> DesignBlocking -> DesignMatching -> DesignSeqOneByOne`
   (design_blocking_abstract.R:15, design_matching_abstract.R:15,
   design_fixed_abstract.R:15, design_seq_one_by_one_abstract.R:14) put every single
   concrete design -- `DesignFixedBernoulli`, `DesignFixedFactorial`,
   `DesignSeqOneByOneUrn`, `DesignSeqOneByOneEfron`, none of which have any block or
   matched-pair structure -- through both bases, carrying `m`, `strata_cols`, `B_target`,
   `cmh_se_w_mat`, `xm_structural`, `xm_m_vec`, `lin_xm_structural`, `lin_xm_m_vec`,
   `boot_pair_rows`, `boot_i_reservoir`, `boot_n_reservoir`, and `matching_capable` state
   they never touch.

2. **A design that inherits blocking/matching ancestry but is explicitly neither.**
   `DesignFixedRerandomization` (design_fixed_rerandomization.R) inherits the full
   `DesignBlocking`/`DesignMatching` chain via `DesignFixed`, yet its source comments
   explicitly note `private$m` is intentionally left unset because "this is not a
   blocking design" -- a class fighting its own mandatory ancestry.

3. **Structural state written directly, bypassing the capability's own guard.**
   `DesignFixediBCRD` and `DesignSeqOneByOneiBCRD` write `private$m = rep(1L, n)`
   directly rather than through `set_m()`, and never set `blocking_capable`/
   `matching_capable` -- so `is_blocking_design()`/`is_matching_design()` stay `FALSE`
   even though `private$m` is populated and `get_block_ids()` would return it. The
   capability flag and the state it's supposed to gate can silently disagree.

4. **Capability flags with zero external readers.** Exhaustive grep for
   `$is_a_fixed(`, `$is_a_seq_one_by_one(`, `$has_covariates(`, `$is_an_observational_design(`,
   `$is_a_fixed_custom(`, `$is_a_custom_sequential(` across every `.R` file in the package
   found no call sites outside their own defining file. These flags exist, are
   overridden by subclasses, are documented -- and inform nothing. Contrast with
   `is_a_bernoulli_capable`, `is_a_cluster_capable`, `is_a_kk_matching_capable`, and
   `supports_resampling`, which each have multiple confirmed external readers in
   `inference_*.R`. A contributor extending `Design` has no way to tell, from the class
   itself, which characterization methods are load-bearing and which are decoration.

5. **Class-identity dispatch instead of capability queries**, confirmed at:
   - `inference_suite.R:107` -- `inherits(des_obj, "DesignBlocking") || inherits(des_obj, "DesignFixedBlocking")`
     (redundant: `DesignFixedBlocking` already `inherits` `DesignBlocking`, so nobody
     trusts the inheritance signal enough to rely on it alone)
   - `inference_mixin_kk_glmm_shared.R:87`, `inference_mixin_kk_gee_shared.R:220`,
     `inference_mixin_kk_passthrough.R:294`, `inference_count_KK_cond_poisson.R:86,466`,
     `inference_incidence_exact_binomial.R:41,152` -- all six check
     `inherits(des_obj, "DesignFixedBinaryMatch")` by name to gate KK/GEE/GLMM/exact-binomial
     eligibility
   - `inference_all_abstract_bayesian_bootstrap.R:530` -- `is(design_obj, "DesignFixedBlockedCluster")`
   - `inference_all_abstract.R:68` (approx.) -- `inherits(des_obj, "DesignSeqOneByOneKK14")`
     cached as `private$is_KK`
   - `inference_all_abstract_rand.R:451` -- `inherits(private$des_obj, "DesignFixedRerandomization")`
   - `inference_indicidence_exact_fisher.R:89-97` -- checks four specific class names
     (`DesignSeqOneByOneiBCRD`, `DesignFixediBCRD`, `DesignFixedBlocking`,
     `DesignSeqOneByOneSPBR`, `DesignSeqOneByOneRandomBlockSize`) to decide exact-Fisher
     eligibility
   - `simulations_framework.R:3039,3063,3066,4035,4038,4051` -- `inherits(d, "DesignSeqOneByOne")`,
     `inherits(d, "DesignFixedBinaryMatch")`, `inherits(d, "DesignFixedOptimalBlocks")`

   Every one of these is a place where adding a new design class with equivalent
   *semantics* under a different name (exactly what `ObservationalDesignMatching` is
   relative to `DesignFixedBinaryMatch` -- both matched-pair, one drawn, one supplied)
   silently fails to participate unless someone remembers to extend every list by hand.

6. **A capability checked by generator-shape sniffing, not even a method call.**
   `simulations_framework.R:845,1239` check
   `!is.null(dc$public_methods$supports_batch_w_pregeneration)` -- testing for the
   *name's presence on the class generator object*, never invoking it as the
   boolean-returning method it's declared to be. This is worse than either a clean
   metadata flag or a real method call: it can't be given a default implementation on
   `Design`, and a subclass can't turn the capability back off (defining any override,
   even one that returns `FALSE`, would make the name "present" and flip the check).

7. **Duplicated allocation-matrix validation.** `validate_allocation_matrix` is defined
   independently, four times, near-identically, in `design_fixed_binary_match.R`,
   `design_fixed_greedy.R`, `design_fixed_matching_greedy_pair_switching.R`, and
   `design_fixed_rerandomization.R` -- the same shape/finite/{0,1}-entries/treated-count
   check copy-pasted rather than shared.

8. **Encapsulation-breaking private reads.** `inference_all_abstract_rand.R` reads
   `des_template$.__enclos_env__$private$uses_covariates` directly rather than through
   any public accessor -- the design-side analogue of the `Inference` plan's ban on
   generator-private reads, except here it's an *instance* private environment being
   read from outside the class entirely.

9. **A throwing-stub retraction built this session, under the old paradigm, as the only
   available pattern.** `ObservationalDesign$draw_ws_raw` (design_observational.R:84-86)
   throws `"This operation is not supported. Observational designs are not controlled
   designs based on randomized allocations."` -- correct behavior, wrong mechanism: it's
   indistinguishable, from the outside, between "this design's drawing mechanism happens
   to be broken right now" and "this design fundamentally has no drawing mechanism by
   design." A `supports("randomization_draw")` query would let callers (and
   `InferenceSuite` discovery, once it exists for designs) *ask* instead of *try and
   catch*.

10. **Two independent, differently-implemented self-checks that both stringify the
    object's own class name.** `DesignFixed$supports_resampling()`
    (design_fixed_abstract.R:183) is `class(self)[1] != "DesignFixed"`; `DesignSeqOneByOne`'s
    override is a hardcoded `TRUE`. Neither reads any actual state; both exist only to
    answer "am I literally the abstract base or a real subclass," which is precisely
    the kind of question `abstract`/`exported` class metadata answers for `Inference*`
    already.

## Class Metadata

Mirroring `EDI_INFERENCE_CLASS_REGISTRY`, every canonical `Design` generator should
have one immutable metadata record:

```r
list(
  name = "DesignFixedBernoulli",
  parent = "DesignFixed",
  abstract = FALSE,
  exported = TRUE,
  timing_family = "fixed",              # "fixed" | "sequential"
  randomization_family = "bernoulli",   # see enumerated list below
  seed_reproducible_draw = TRUE,        # FALSE for A-/D-optimal (std::random_device)
  direct_components = character(),      # e.g. c("BlockingStructure")
  supports_batch_w_pregeneration = FALSE,
  required_packages = character()
)
```

Mandatory fields:

- `name` / `parent` / `abstract` / `exported`: same meaning as the `Inference` registry.
- `timing_family`: `"fixed"` or `"sequential"`, replacing the currently-unread
  `is_a_fixed()`/`is_a_seq_one_by_one()` booleans with metadata that actually gets
  queried (`supports("fixed_sample")` derives from it).
- `randomization_family`: a closed enum describing the *drawing mechanism*, replacing
  ad hoc identity checks. Values needed by the current 26 concrete classes:
  `"bernoulli"`, `"complete_randomization"` (iBCRD), `"blocked"`, `"clustered"`,
  `"blocked_cluster"`, `"binary_match"`, `"matching_greedy_pair_switching"`,
  `"a_optimal"`, `"d_optimal"`, `"greedy"`, `"rerandomization"`, `"optimal_blocks"`,
  `"factorial"`, `"custom_fixed"`, `"kk14"`, `"kk21"`, `"kk21_stepwise"`, `"efron"`,
  `"atkinson"`, `"pocock_simon"`, `"random_block_size"`, `"spbr"`, `"urn"`,
  `"custom_sequential"`, `"none"` (observational family). This is the field that
  replaces the six-class-name checks in `inference_indicidence_exact_fisher.R:89-97`
  and the `DesignFixedBinaryMatch`/`DesignFixedOptimalBlocks` checks in
  `simulations_framework.R`.
- `seed_reproducible_draw`: surfaces the currently-undiscoverable gap where
  `DesignFixedAOptimal`/`DesignFixedDOptimal` use `std::random_device` internally and
  are **not** reproducible via the `seed` constructor argument that every other design
  honors. This is a real, currently-silent correctness/usability gap this survey
  turned up as a side effect, not an architecture nicety -- both classes must be fixed
  to be seed-reproducible, the same way `DesignFixedGreedy` already is (per-thread RNGs
  seeded from R's RNG state before the OpenMP region, instead of `std::random_device`);
  see the "Seed-Reproducibility Metadata" TODO section. Until that fix lands, this field
  makes the gap queryable and documented instead of silent.
- `direct_components`: components added by this class (see below).
- `supports_batch_w_pregeneration`: replaces the generator-shape-sniffing check in
  `simulations_framework.R:845,1239` with a real metadata read.
- `required_packages`: `nbpMatching` (`DesignFixedBinaryMatch`,
  `DesignFixedMatchingGreedyPairSwitching`), `randomizr` (`DesignFixedBlocking` optionally,
  `DesignFixedCluster`/`DesignFixedBlockedCluster` unconditionally, `DesignFixedOptimalBlocks`
  when `method="ompr"`), `anticlust` (`DesignFixedOptimalBlocks` default), `blockTools`
  (`DesignFixedOptimalBlocks` greedy), `ompr`/`ompr.roi`/`ROI.plugin.glpk` (`DesignFixedOptimalBlocks`
  ompr).

## Components

A component is a named, registered unit of optional structural behavior, mirroring
`InferenceComponent()`. Unlike the `Inference` components (which are mostly
*algorithms*), `Design` components are mostly *shared state + the public API over it*,
because that's what `DesignBlocking`/`DesignMatching` actually are today underneath the
forced inheritance.

Component families:

- `BlockingStructure` -- owns `m`, `strata_cols`, `preferred_num_bins_for_continuous_covariate`,
  `B_target`, `exact_num_blocks`, `equal_block_sizes`, `cmh_se_w_mat`; provides
  `is_blocking_design()`, `assert_blocking_design()`, `is_complete_blocking_design()`,
  `assert_equal_block_sizes()`, `add_all_subject_matched_pair_ids()`, `set_m()`,
  `get_block_ids()`, `summarize_blocks()`, `inject_cmh_se_w_mat()`, `get_cmh_se_w_mat()`,
  and the stratified/group-resample `draw_bootstrap_indices()` variant (generalizing
  what `DesignFixedBlocking`/`DesignFixedOptimalBlocks`/`ObservationalDesignBlocks`/
  `DesignSeqOneByOneRandomBlockSize`/`DesignSeqOneByOneSPBR` each currently reimplement).
- `MatchingStructure` -- depends on `BlockingStructure` (matching is blocking with
  pair-size-2 semantics plus extra structure); owns `xm_structural`, `xm_m_vec`,
  `lin_xm_structural`, `lin_xm_m_vec`, `boot_pair_rows`, `boot_i_reservoir`,
  `boot_n_reservoir`; provides `is_matching_design()`, `assert_matching_design()`,
  `get_matching_cluster_ids()`, and the pair-preserving `draw_bootstrap_indices()`
  variant (`draw_matching_bootstrap_sample_cpp`) -- this is the exact machinery
  `ObservationalDesignMatching` had to extend `ObservationalDesign` directly, rather
  than `ObservationalDesignBlocks`, in order to inherit correctly; under the component
  model it composes in `MatchingStructure` and gets this for free regardless of what
  else it composes.
- `ClusterStructure` -- owns `cluster_col`; provides the cluster-aware
  `draw_bootstrap_indices()` variant (`resample_group_rows_cpp` at the cluster level)
  used today by `DesignFixedCluster`/`DesignFixedBlockedCluster`.
- `AllocationMatrixValidation` -- absorbs the four duplicated `validate_allocation_matrix`
  implementations (`design_fixed_binary_match.R`, `design_fixed_greedy.R`,
  `design_fixed_matching_greedy_pair_switching.R`, `design_fixed_rerandomization.R`) into
  one shared, tested implementation.
- `BatchWPregeneration` -- a real capability (not generator-shape-sniffed) backing
  `supports_batch_w_pregeneration`, composed by `DesignFixedBinaryMatch`,
  `DesignFixedGreedy`, `DesignFixedMatchingGreedyPairSwitching`, `DesignFixedOptimalBlocks`.

Empty scaffolds are not components, per the same rule as the `Inference` plan.

## Component Contract

Same shape as `InferenceComponent()`:

```r
DesignComponent(
  name = "MatchingStructure",
  status = "active",
  dependencies = "BlockingStructure",
  public = list(...),
  private = list(...),
  provides_public_methods = c("is_matching_design", "assert_matching_design", "get_matching_cluster_ids"),
  provides_private_methods = c("draw_bootstrap_indices", "init_matching_bootstrap_structure", ...),
  owns_state = c("xm_structural", "xm_m_vec", "lin_xm_structural", "lin_xm_m_vec",
                 "boot_pair_rows", "boot_i_reservoir", "boot_n_reservoir"),
  requires_state = c("m"),                     # owned by BlockingStructure
  requires_public_methods = character(),
  requires_private_methods = character(),
  optional_public_methods = character(),
  optional_private_methods = character(),
  provides_capabilities = "matching",
  conflicts = character(),
  allowed_host_overrides = list(public = character(), private = character())
)
```

Contract rules are identical in spirit to the `Inference` plan's Component Contract
section (exact name matching, explicit state ownership, no implicit collisions, no
`super$` calls into a component that isn't a true `inherit` ancestor -- the
`InferenceContinRobustRegr` migration already hit this exact trap once with a dead
`super$approximate_bootstrap_distribution_beta_hat_T(...)` passthrough after flattening;
`Design` components must not repeat it).

## Capability Model

```text
effective_capabilities(class)
  = union(component_capabilities(effective_components(class)))
  + class_owned_capabilities(class)   # timing_family, randomization_family, etc.
```

Callers use:

```r
des_obj$supports("blocking")
des_obj$supports("matching")
des_obj$supports("cluster")
des_obj$supports("randomization_draw")   # FALSE for the ObservationalDesign family
des_obj$supports("batch_w_pregeneration")
des_obj$supports("seed_reproducible_draw")
des_obj$capabilities()
```

This is what replaces every `is()`/`inherits()` call site enumerated in "Evidence of
the Problem" item 5, and the generator-sniffing in item 6. `randomization_family` (a
scalar, not a boolean capability) replaces the exact-Fisher eligibility checks in
`inference_indicidence_exact_fisher.R:89-97` and the KK/GEE/GLMM `DesignFixedBinaryMatch`
name checks with `design_obj$randomization_family() %in% c("binary_match")` or an
equivalent `supports("binary_match_structure")` capability, whichever proves cleaner once
implemented -- decide during the Discovery TODO below, don't guess here.

## Class Factory

```r
DesignFixedBernoulli <- define_design_class(
  name = "DesignFixedBernoulli",
  parent = DesignFixed,
  metadata = list(
    abstract = FALSE,
    exported = TRUE,
    timing_family = "fixed",
    randomization_family = "bernoulli",
    seed_reproducible_draw = TRUE,
    required_packages = character()
  ),
  components = character(),
  public = list(
    initialize = initialize_fixed_bernoulli
  ),
  private = list(
    draw_ws_raw = draw_ws_raw_bernoulli
  ),
  overrides = list(public = character(), private = character()),
  lock_objects = FALSE
)
```

Same factory obligations as `define_inference_class()`: register metadata, resolve
components + dependencies, validate contracts, validate capability requirements,
validate public API presence, reject unauthorized collisions, assemble public/private
once, return an ordinary R6 generator.

## Discovery

There is currently no `Design`-side analogue of `InferenceSuite` (design selection is
manual -- the user picks a `Design*` class directly), so there's no discovery-metadata
requirement to satisfy the way `InferenceSuite` has one. The relevant "discovery" today
is entirely the scattered `is()`/`inherits()` compatibility checks living *inside*
`Inference*`/`simulations_framework.R` (item 5 above) that ask "is this design
compatible with what I'm about to do." Those become `supports()`/`randomization_family()`
reads once this plan lands; no new `DesignSuite` class is proposed here, since nothing in
the current codebase needs one -- if a future need for design auto-selection emerges,
revisit this section then rather than building it speculatively now.

## Source Invariants

Add structural tests, mirroring the `Inference` plan's list:

1. Every canonical `Design` generator has exactly one metadata record.
2. Every metadata record points to a real generator.
3. Every generator declares `abstract`, `exported`, `timing_family`,
   `randomization_family`, `seed_reproducible_draw`, and direct components.
4. `timing_family` is one of `"fixed"`, `"sequential"`.
5. No source creates a top-level `Design*` alias assignment to another `Design*`
   generator.
6. Public optional methods equal `public_methods_for_capability(effective_capabilities(class))`.
7. No public optional method is an unconditional error (retires the
   `ObservationalDesign`/`DesignMatching`/`DesignSeqOneByOne`/`DesignFixedCustom`/
   `DesignCustomSequential` throwing stubs enumerated above -- `ObservationalDesign`'s
   "no randomization" becomes `randomization_family = "none"` metadata plus
   `supports("randomization_draw") == FALSE`, queried by `draw_ws_according_to_design()`'s
   *caller* before calling, not discovered by calling and catching).
8. No public/private method-name duplicate exists without an explicit override.
9. No `is()`/`inherits()` dispatch on a `Design*` class name outside this file's
   migration tests and the class hierarchy itself (i.e. `parent=` relationships) --
   every current production call site listed in "Evidence of the Problem" item 5 must
   be gone.
10. No check of `dc$public_methods$<name>` generator-shape sniffing anywhere in the
    package (retires item 6).
11. No `.__enclos_env__$private` read of a `Design` instance from outside `design_*.R`
    (retires item 8; `des_template$.__enclos_env__$private$uses_covariates` in
    `inference_all_abstract_rand.R` needs a public accessor instead).
12. `set_m()` is the only way `private$m` is ever assigned outside `design_*.R` itself,
    and every assignment to `private$m` inside `design_*.R` also results in
    `is_blocking_design() == TRUE` (retires item 3 -- `DesignFixediBCRD`/
    `DesignSeqOneByOneiBCRD`'s direct-write bypass).
13. Every component is registered, composed at most once effectively, and every
    component dependency is declared and ordered once (same as the `Inference` plan).
14. Only one implementation of allocation-matrix validation exists in the package
    (retires item 7).
15. Component slot state is never silently dropped by `modifyList()`/never silently
    reset by a worker-clone helper the way `InferenceContinQuantileRegr`'s
    `tau`/`fit_warm_keep` fields were during the `Inference` migration -- add the
    regression test the `Inference` plan flagged as still owed
    (`R/EDI/R/fix_inference_hierarchy.md`'s "Correction" note under
    `InferenceContinQuantileRegr`) for `Design` components too, since `Design` objects
    get cloned/duplicated for bootstrap/resampling workers exactly the way `Inference`
    objects do (`Design$duplicate()`, design_abstract.R).

Behavioral tests must remain in place for every concrete design's drawn allocation
distribution (marginal treatment probability, block/pair/cluster balance where
applicable) and bootstrap-index distribution (within-block, within-pair,
within-cluster, or plain, matching the pre-migration behavior exactly).

## Implementation TODOs

### Metadata Registry

- [x] TODO-1: Create `EDI_DESIGN_CLASS_REGISTRY`, `register_design_class()`,
  `get_design_class_metadata()`, `get_direct_design_components()`,
  `get_effective_design_components()`, `get_effective_design_capabilities()`.
  Implemented in `R/EDI/R/design_class_registry.R`, populated via a top-level
  `populate_design_class_registry()` call (same pattern as
  `inference_class_registry.R`), sourced last among the `design_*.R` files in
  `DESCRIPTION`'s `Collate:` order so every generator exists before registration
  runs. `direct_components` is `character()` for all 34 classes for now, since no
  `DesignComponent` registry exists yet (see "Component Registry"/"Component
  Extraction" below) -- `get_effective_design_components()`/
  `get_effective_design_capabilities()` are wired to a real (currently-empty)
  resolution path, not stubbed out, so they don't need to change shape once
  components land. `timing_family` is derived structurally by walking the real R6
  `get_inherit()` chain for `DesignFixed`/`DesignSeqOneByOne` ancestry rather than a
  name-based table, so new subclasses classify correctly with zero registry
  maintenance; `randomization_family` uses an explicit per-class table
  (`EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME`) since the drawing mechanism can't be
  inferred structurally, mirroring `infer_inference_direct_components()`'s style.
  Confirmed one known, pre-existing quirk shared with `inference_class_registry.R`
  (not introduced here): under `devtools::load_all()`, `exported` metadata computed
  by the populate-time `getNamespaceExports("EDI")` read comes back `FALSE` even for
  genuinely-exported classes, because the top-level populate call runs before
  `NAMESPACE` exports are attached in the dev-load sequence -- verified this is
  identical, not worse, for `InferenceContinOLS` under the same dev workflow, so it's
  a pre-existing characteristic of the whole registry pattern, not a defect specific
  to the design registry; not fixed here since it would mean changing when
  `populate_inference_class_registry()` runs too, out of scope for this TODO.
- [x] TODO-2: Add metadata validators for mandatory fields and allowed `timing_family`/
  `randomization_family` values. `validate_design_class_metadata()` requires all 10
  fields, rejects `timing_family`/`randomization_family` values outside their closed
  enums (`EDI_DESIGN_ALLOWED_TIMING_FAMILIES`, `EDI_DESIGN_ALLOWED_RANDOMIZATION_FAMILIES`),
  and additionally enforces *which* classes are allowed to leave those two fields
  `NA` (only `Design`/`DesignBlocking`/`DesignMatching` for `timing_family`; those
  three plus `DesignFixed`/`DesignSeqOneByOne` for `randomization_family`) -- so a
  concrete class silently missing its family assignment fails loudly at registration
  time rather than being indistinguishable from a genuine abstract base.
- [x] TODO-3: Add tests that every generator has one canonical metadata entry and that
  `randomization_family` values are drawn from the closed enum in "Class Metadata."
  `R/EDI/tests/testthat/test-design-class-registry.R`: canonical-generator-count
  test (mirrors `test-inference-class-registry.R`'s pattern exactly), closed-enum
  tests for both `timing_family` and `randomization_family` with spot-checks against
  the documented per-class mapping, `seed_reproducible_draw`/
  `supports_batch_w_pregeneration`/`required_packages` checks against the known
  exception lists, metadata-validator negative tests (missing field, invalid enum
  value, invalid `NA` placement), duplicate-registration rejection, and a test that
  `timing_family` in the registry agrees with the real R6 inheritance chain (not just
  the table used to populate it). 566 passing expectations; full existing
  `test-design-abstract-hierarchy.R` (24) and `test-inference-class-registry.R`
  (2787) suites still pass unchanged, confirming no regression.

### Component Registry

- [x] TODO-4: Create `EDI_DESIGN_COMPONENTS`, implement `DesignComponent()`. Implemented in
  `R/EDI/R/design_component_registry.R` as a parallel, self-contained implementation
  (not a refactor of `mixin_contracts.R`'s `InferenceComponent()` machinery, to avoid
  any risk to the already-shipped, tested Inference component system), scoped to what
  this plan's simpler contract needs: no lazy loading, no likelihood tiers, no
  `super$` reference category (Design components are pure state + method bundles, not
  deep-inheritance mixins the way some Inference components are -- none of the five
  planned components call `super$`). Includes `validate_design_component()`,
  `register_design_component()`, `resolve_design_component_dependencies()` (cycle/
  duplicate/scaffold detection, mirroring `resolve_component_dependencies()`), and
  wired `design_class_registry.R`'s previously-stub `resolve_design_components()` /
  `get_effective_design_capabilities()` to actually call it, so `direct_components`
  on a class (still `character()` for every class today -- see below) will resolve
  correctly the moment Component Extraction starts assigning real ones.
- [x] TODO-5: Register `BlockingStructure`, `MatchingStructure` (`dependencies =
  "BlockingStructure"`), `ClusterStructure`, `AllocationMatrixValidation`,
  `BatchWPregeneration` with full public/private lists, provided methods, owned state,
  required state, dependencies, and capabilities. `populate_design_component_registry()`
  registers all five. `BlockingStructure` and `MatchingStructure` are **real, active**
  components: their `public`/`private` lists are direct function references pulled off
  the still-live `DesignBlocking`/`DesignMatching` generators (`DesignBlocking$public_methods[["is_blocking_design"]]`,
  etc.) -- zero duplicated logic; the single source of truth for their behavior stays
  those two generators until Component Extraction actually rewires a concrete class to
  list `components = c(...)` instead of inheriting them. Every `owns_state`/
  `requires_state`/`requires_public_methods`/`optional_private_methods` declaration was
  derived by running the parser-backed reference collector against the real method
  bodies first (not transcribed by eye) and cross-checked, so the declarations are
  exact, not approximate:
  - `BlockingStructure` owns `m`, `strata_cols`, `preferred_num_bins_for_continuous_covariate`,
    `B_target`, `exact_num_blocks`, `equal_block_sizes`, `blocking_capable`,
    `cmh_se_w_mat`; requires root `Design` state `t`/`Xraw`/`y` and public method
    `get_X_raw`; and declares `optional_private_methods = "get_or_compute_block_ids"`
    because `DesignBlocking$get_block_ids()` conditionally reaches into a private
    method that today only exists on `DesignFixedOptimalBlocks` (guarded by an
    `is(self, "DesignFixedOptimalBlocks")` check) -- a real, slightly awkward
    cross-class coupling in the current code, surfaced honestly rather than hidden.
  - `MatchingStructure` depends on `BlockingStructure`, owns `matching_capable`,
    `boot_i_reservoir`, `boot_n_reservoir`, `boot_pair_rows`, `cluster_id`,
    `cluster_id_m_vec`, `lin_xm_m_vec`, `lin_xm_structural`, `xm_m_vec`,
    `xm_structural`; requires `m` (owned by its `BlockingStructure` dependency) and
    root `n`/`get_n`. Its private `draw_bootstrap_indices` is `DesignMatching`'s real
    pair-preserving implementation (`draw_matching_bootstrap_sample_cpp`), the exact
    thing `ObservationalDesignMatching` needed by extending `ObservationalDesign`
    directly instead of `ObservationalDesignBlocks` -- confirmed by reference-identity
    test that this is the *same* function object, not a reimplementation.
  - `BatchWPregeneration` is real and active: all four current
    `supports_batch_w_pregeneration = function() TRUE` definitions
    (`DesignFixedBinaryMatch`, `DesignFixedGreedy`, `DesignFixedMatchingGreedyPairSwitching`,
    `DesignFixedOptimalBlocks`) were confirmed byte-identical (`identical(body(...), body(...))`)
    before treating one as canonical.
  - `ClusterStructure` and `AllocationMatrixValidation` are registered as
    **`status = "scaffold"`**, per this plan's own rule that empty scaffolds are not
    components and must be forbidden from every effective component set (enforced:
    `resolve_design_component_dependencies()` errors if asked to resolve either).
    Diffing the four `validate_allocation_matrix` implementations
    (`design_fixed_binary_match.R`, `design_fixed_greedy.R`,
    `design_fixed_matching_greedy_pair_switching.R`, `design_fixed_rerandomization.R`)
    confirmed they are *not* safely consolidatable as-is: they differ in real
    behavior, not just error-message text -- `DesignFixedRerandomization` takes an
    extra `require_balanced` parameter and only conditionally checks treated-count
    balance, `DesignFixedBinaryMatch` recycles columns when the search returns fewer
    than `r` replicates while the other three error instead, and column-selection
    uses `seq_len(r)` in two classes vs. `min(r, ncol(w_mat))` in
    `DesignFixedRerandomization`. Reconciling those differences is real per-class
    design work needing its own golden tests -- exactly what "Component Extraction"
    below is for -- so `AllocationMatrixValidation` is left a scaffold rather than
    fabricating a single behavior that could silently change one of those four
    classes' semantics. Similarly, no single canonical stratified/cluster-aware
    `draw_bootstrap_indices()` exists yet for pure-blocking (non-matching) or
    cluster-capable designs -- every currently-blocking-or-cluster-capable concrete
    class still hand-rolls its own -- so `ClusterStructure` stays a scaffold (owns
    only `cluster_col` for now) and `BlockingStructure` does not yet include a
    `draw_bootstrap_indices` of its own; extraction/generalization of that shared
    stratified-resample logic is deferred to Component Extraction as originally
    planned, not rushed through here.
- [x] TODO-6: Add parser-backed tests that every component body reference is declared as
  provided, required, optional, owned, or forbidden (same as the `Inference` plan).
  `design_component_body_references()`/`design_component_declared_reference_names()`/
  `validate_design_component_body_references()` implement the same walk-the-parse-tree
  approach as `mixin_contracts.R`'s equivalents (receivers: `private`, `self` -- no
  `super`, since no Design component calls it). `populate_design_component_registry()`
  runs this validation against every active (non-scaffold) component at registration
  time, so a future component with an undeclared reference fails to load rather than
  silently shipping. `R/EDI/tests/testthat/test-design-component-registry.R` (61
  passing expectations) additionally covers: registration/duplicate/missing-field/
  invalid-status/stale-metadata validator errors, scaffold-cannot-be-resolved,
  dependency expansion (`MatchingStructure` resolves to
  `c("BlockingStructure", "MatchingStructure")`), duplicate/unknown/cycle rejection in
  dependency resolution, negative body-reference tests (undeclared `private$`/`self$`
  both correctly rejected), and a regression check that registering the components
  changes nothing about how `DesignFixedBlocking`/`DesignFixedBinaryMatch` actually
  behave today (they don't consume the components yet). Full existing
  `test-design-abstract-hierarchy.R` (24), `test-design-class-registry.R` (566),
  `test-inference-class-registry.R` (2787), and `test-resampling-draw-contracts.R`
  (46) suites all still pass unchanged.

### Component Extraction

Note on scope: "extract" here means what Component Registry already delivered --
`BlockingStructure`/`MatchingStructure`/`BatchWPregeneration` hold real, reference-identical
method pointers into `DesignBlocking`/`DesignMatching`/the four pre-generating classes, so
behavioral equivalence is already proven (reference identity implies identical output; see
`test-design-component-registry.R` and `test-design-component-extraction-golden.R`). What
remains -- actually cutting `DesignFixed`/`DesignSeqOneByOne`'s `inherit` chain away from
`DesignBlocking`/`DesignMatching` and rewiring concrete classes onto `components = c(...)`
-- needs a `define_design_class()` factory that does not exist yet (this plan's "Class
Factory" section sketches its target shape but never scheduled building it as its own TODO;
add that as an explicit prerequisite before the two `[ ]` items below can be completed, not
a silent gap).

- [x] TODO-7: Extract `BlockingStructure` from `DesignBlocking` (design_blocking_abstract.R) at the
  component-registry level (done in "Component Registry" above). Golden-tested against
  `DesignFixedBlocking`, `DesignFixedOptimalBlocks`, and `ObservationalDesignBlocks`'s
  `get_block_ids()`/`is_blocking_design()`/`is_complete_blocking_design()`/
  `summarize_blocks()`/`set_m()` output in `test-design-component-extraction-golden.R`.
  No stratified `draw_bootstrap_indices()` golden test yet, because -- as already noted in
  Component Registry -- no single canonical implementation of that exists to extract; every
  blocking-capable concrete class still hand-rolls its own. Deferred, not silently dropped.
- [x]/[ ] TODO-8: **Reconciled 2026-08-16 -- this item's prose had gone stale relative to
  actual completed work** (a plan-doc-only conflict from concurrent editing; the
  underlying code was never reverted, confirmed via direct inspection). Split into what
  actually landed vs. what's still open:
  - [x] `define_design_class()` (design_class_factory.R) was built ("Class Factory
    Implementation" section) and 7 of the 9 named classes were rewired onto explicit
    `components = c(...)`: `DesignFixedBlocking`, `DesignFixedBlockedCluster`,
    `DesignFixedOptimalBlocks`, `DesignSeqOneByOneKK14`, `ObservationalDesignBlocks`,
    `ObservationalDesignMatching` (`BlockingStructure`/`MatchingStructure` as
    applicable), plus `DesignFixedCluster`/`DesignFixedBinaryMatch` (see TODO-10/11
    below). Deliberately skipped: `DesignFixediBCRD`, `DesignFixedMatchingGreedyPairSwitching`
    -- both have real `blocking_capable`/`matching_capable` flag gaps (see TODO-9's own
    finding for the latter) that would force an undecided behavioral change as a side
    effect of mechanical rewiring; `DesignSeqOneByOneRandomBlockSize`/`DesignSeqOneByOneSPBR`
    -- out of scope, different row-by-row mechanism, own follow-up (see the
    generalized-bootstrap item elsewhere in this file). This phase also surfaced and fixed
    3 real bugs: a `DESCRIPTION` `Collate:` ordering defect (`define_design_class`
    sourced after classes that needed it), a production bug in the generalized
    `ClusterStructure` (see TODO-11), and an R6 `lock_objects` inheritance trap
    (`DesignSeqOneByOneKK21`/`KK21stepwise` needed `lock_objects = FALSE` added
    explicitly once their parent `DesignSeqOneByOneKK14` gained it).
  - [ ] Still open: actually cutting `DesignFixed`/`DesignSeqOneByOne`'s `inherit` away
    from `DesignBlocking`/`DesignMatching`. Deliberately **not** attempted yet --
    investigation found this needs the ~20 remaining concrete classes (not just the 9
    above) to also get at least `BlockingStructure` composed first, or they'd lose
    `is_blocking_design()`/`set_m()`/etc. entirely (not "returns FALSE", but "the method
    doesn't exist") the moment the flip happens. See the dedicated audit item for this
    scope expansion elsewhere in this section.
- [x] TODO-9: Extract `MatchingStructure` from `DesignMatching` (design_matching_abstract.R) at the
  component-registry level. Golden-tested `is_matching_design()`/`get_matching_cluster_ids()`/
  pair-preserving `draw_bootstrap_indices()` (verified by reference identity to
  `DesignMatching$private_methods$draw_bootstrap_indices`, which internally calls
  `draw_matching_bootstrap_sample_cpp`) for `DesignFixedBinaryMatch`,
  `DesignFixedMatchingGreedyPairSwitching`, `DesignSeqOneByOneKK14`, and
  `ObservationalDesignMatching`, exactly the four classes this item named. One genuine new
  finding surfaced by writing these tests: `DesignFixedMatchingGreedyPairSwitching` computes
  and constrains its search to matched pairs internally (`bms`/
  `ensure_pair_structure_computed`) but never sets `private$matching_capable` (confirmed:
  `design_fixed_matching_greedy_pair_switching.R` never references `matching_capable` or
  `blocking_capable` at all) -- so `is_matching_design()` is `FALSE` for it today, unlike its
  sibling `DesignFixedBinaryMatch`. Whether that's intentional (this class's "matching" is a
  pure local-search constraint, never exposed via `get_matching_cluster_ids()` or pair-aware
  jackknife/bootstrap treatment) or a latent gap deserves separate investigation; recorded
  here rather than silently changed.
- [x] TODO-10: **Reconciled 2026-08-16, same stale-prose issue as TODO-8.** Rewiring for
  `MatchingStructure` is done: `DesignFixedBinaryMatch`, `DesignSeqOneByOneKK14`,
  `ObservationalDesignMatching` all compose `components = "MatchingStructure"` (which
  auto-expands to include its `BlockingStructure` dependency), verified
  reference-identical/behavior-preserving via the existing test suite.
  `DesignFixedMatchingGreedyPairSwitching` deliberately skipped (see TODO-9's finding --
  flag gap, not mechanical).
- [x] TODO-11: **Reconciled 2026-08-16, same stale-prose issue.** `ClusterStructure` was
  generalized (not a reference extraction, since -- as this item correctly notes -- no
  single canonical implementation existed): one implementation now handles both
  `DesignFixedCluster`'s single-level resample and `DesignFixedBlockedCluster`'s
  two-level strata-then-cluster resample, dispatching on `isTRUE(private$blocking_capable)`.
  Golden-tested byte-identical against both real classes
  (`test-design-cluster-structure-golden.R`), and both classes are now actually wired to
  the component via `define_design_class()`.

  **A real production bug was found and fixed while wiring this up, not just during
  isolated testing:** the first version dispatched on
  `private$has_private_method("get_strata_keys")` (an existence check), which broke real
  `DesignFixedCluster` the moment it was wired to the component -- `DesignFixedCluster`
  has no `strata_cols` at all, but still inherits `get_strata_keys` transitively through
  `DesignMatching -> DesignBlocking` (pre "Timing-Family Split"), so the existence check
  incorrectly took the "call `get_strata_keys()`" branch and errored inside it. Fixed by
  switching to the explicit `blocking_capable` flag instead of an inherited-method
  existence probe -- correct both before and after the eventual inherit flip, and the
  same fix pattern documented for `BlockingStructure`'s own `get_or_compute_block_ids`
  hook.
- [ ] TODO-12: Extract `AllocationMatrixValidation`, delete the four duplicated
  `validate_allocation_matrix` implementations, point all four callers at the shared one.
  Still not attempted, and still correctly a scaffold: diffing all four confirmed they are
  not safely mergeable as-is (see Component Registry's writeup -- `DesignFixedRerandomization`
  takes an extra `require_balanced` parameter and only conditionally checks balance,
  `DesignFixedBinaryMatch` recycles short results where the other three error, column
  selection differs `seq_len(r)` vs `min(r, ncol(w_mat))`). Reconciling those differences is
  a real per-class design decision, not extraction.
- [x] TODO-13: Extract `BatchWPregeneration`; replace the generator-shape-sniffing checks in
  `simulations_framework.R:845,1239` with a real capability read. Implemented as
  `design_class_generator_supports_batch_w_pregeneration(dc)` (`design_class_registry.R`)
  rather than literally `design_obj$supports("batch_w_pregeneration")` as originally
  phrased here -- both call sites (`simulations_framework.R:844-845`, `:1239`) only have an
  R6 generator (`dc = private$design_classes[[di]]`) in hand at that point, not an
  instantiated design object, so an instance method wasn't the right shape; corrected that
  imprecision in this plan rather than silently deviating from it. The helper reads
  `get_design_class_metadata(dc$classname)$supports_batch_w_pregeneration` and falls back to
  the old shape-sniffing check only for generators absent from the registry (i.e.
  user-defined third-party `Design` subclasses the package-namespace scan never sees), so
  custom/extension designs are not newly misclassified. Also added real `Design$capabilities()`/
  `supports(capability)` public instance methods (`design_abstract.R`) as the groundwork for
  future capability queries generally (used by, e.g., `test-design-component-extraction-golden.R`'s
  `"Design$capabilities()/supports() bridge legacy predicates"` test) -- these bridge the
  not-yet-populated component registry with the existing `is_blocking_design()`/
  `is_matching_design()`/`supports_batch_w_pregeneration()` predicates so callers get correct
  answers today; the bridge is documented as temporary in the method's own roxygen and should
  be deleted once real class rewiring lands and the registry alone is authoritative.
- [x] TODO-14: (Found and fixed while verifying the above, not originally scoped here, but the same
  category of "Evidence of the Problem" item 5/9 staleness this plan targets on the design
  side): `simulations_framework.R`'s `.valid_inference_types()` (and its duplicated
  parallel-worker copy) gated `asymp_ci`/`asymp_pval` on `is(inf_obj, "InferenceAsymp")` and
  `boot_ci`/`boot_pval` on `is(inf_obj, "InferenceNonParamBootstrap")` -- both stale class
  checks left over from the (separate, already-`[x]`-marked-done-elsewhere) Inference shallow-
  hierarchy migration: `InferenceAllSimpleMeanDiff` and other migrated classes no longer
  inherit those bases (chain is now `InferenceAllSimpleMeanDiff -> Inference -> R6`), so every
  design/inference combo using a migrated class was silently filtered out as "invalid" with
  zero result rows -- confirmed by running the full simulation-framework test suite (not
  something design-hierarchy work would normally exercise) and finding `test-simulation-
  framework-advanced.R` at 6/6 test blocks failing and `test-simulation-framework-extended.R`
  at 9 failures, all from this one root cause. Fixed by replacing both checks with
  `.supports_inference_capability(inf_obj, "wald", "InferenceAsymp")` /
  `.supports_inference_capability(inf_obj, "nonparametric_bootstrap", "InferenceNonParamBootstrap")`
  -- the same capability-with-fallback-class pattern the file already used for
  `.supports_exact_inference()`, applied consistently to all four occurrences of the pattern
  (`simulations_framework.R` lines ~2722, ~2734, ~3195, ~3199, ~3289, ~3395). Result:
  `test-simulation-framework-advanced.R` 6→0 failures, `test-simulation-framework-extended.R`
  9→1 (the one remaining failure is about survival `dead`-indicator values, unrelated --
  matches the separately-tracked, already-known-incomplete y/y_L/y_R interval-censoring
  rework), `test-simulation-framework.R` reduced to a narrower 5-failure cluster confirmed
  (by direct empirical check: `is(inf, "InferenceAsymp")` and the new capability check both
  return `FALSE` for it) to be a *different*, pre-existing gap unrelated to this fix -- a
  test-file-local `InferenceAlwaysFailsPval` subclass of `InferenceAllSimpleMeanDiff` that
  was never registered in `EDI_INFERENCE_CLASS_REGISTRY` (only the package namespace is
  scanned at registry-population time), so capability lookup for it fails and falls back to
  a `fallback_class` check that also doesn't match post-migration. That gap -- ad-hoc
  unregistered subclasses of migrated Inference classes losing capability detection entirely
  -- is real but out of scope for a Design-hierarchy plan; belongs in
  `fix_inference_hierarchy.md` if picked up later, not fixed here. Not previously tracked
  anywhere in `fix_inference_hierarchy.md`'s own TODOs.

### Class Factory Implementation (`define_design_class()`)

Audit finding: both `[ ]` rewiring items in "Component Extraction" above ("Actually cut
`DesignFixed`/`DesignSeqOneByOne` away from inheriting..." and "Rewiring for
`MatchingStructure` blocked on the same...") say they are blocked on this factory, and
the "Class Factory" architecture section above sketches its target shape -- but nothing
in the original TODO list ever scheduled building it. That gap is why those two items
could not be completed this pass. Mirrors `define_inference_class()`
(`mixin_contracts.R`), scoped down the same way `DesignComponent()` was scoped down from
`InferenceComponent()`: no lazy loading, no likelihood tiers, no `super$` category.

- [x] TODO-15: Implement `assemble_public()`/`assemble_private()` equivalents for `Design`:
  combine a class's own `public`/`private` lists with its resolved effective components'
  lists, honoring `overrides` for declared collisions and rejecting undeclared ones.
  Implemented as `assemble_design_public()`/`assemble_design_private()`
  (`R/EDI/R/design_class_factory.R`), built on `combine_design_component_slot()`, a
  parallel implementation of `combine_component_slot()` (`mixin_contracts.R`) -- same
  method-vs-state kind-collision detection, same `overrides$public`/`overrides$private`
  shape. One behavior worth stating explicitly since a test initially assumed
  otherwise: declaring a name in `overrides` silences *both* a plain name collision and
  a method/state kind mismatch uniformly -- there is no separate declaration for "the
  kind changed too." Confirmed this matches `combine_component_slot()`'s identical
  behavior for `Inference`, not a Design-specific gap.
- [x] TODO-16: Implement `validate_design_class_definition()`: given `classname`, `inherit`,
  `components`, `public`, `private`, `overrides`, check component dependencies resolve,
  no undeclared method/state collisions exist between the host and its components,
  and every component-required public method/private method/private state is actually
  present on the assembled host. (`metadata`/capability-requirements validation was
  dropped from this signature versus the original sketch: `Design` has no
  `capability_requires` table the way `Inference` does -- nothing to validate against
  yet -- so accepting an unused `metadata` parameter would have violated "don't design
  for hypothetical future requirements." Add it back if/when a real capability-gating
  need appears.) A real bug was caught and fixed while building this: the first version
  of `design_r6_inherited_public_names()`/`design_r6_inherited_private_names()`
  (mirroring `r6_inherited_public_names()` in `mixin_contracts.R`) only walked one level
  of `inherit`, which is sufficient for `Inference` today (every migrated class inherits
  `Inference` directly) but not for `Design`: a synthetic test class declared
  `inherit = DesignFixed` -- which, pre-"Timing-Family Split," still sits three levels
  below `Design` -- and `BlockingStructure`'s `requires_public_methods = "get_X_raw"`
  (defined on root `Design`) was incorrectly reported missing. Fixed by walking the full
  `get_inherit()` chain instead of one level; this is also a real requirement for the
  *target* architecture, not just a workaround for the pre-split state, since the KK
  family (`DesignSeqOneByOneKK14 -> DesignSeqOneByOneKK21 -> DesignSeqOneByOneKK21stepwise`)
  is multi-level by design even after the split.
- [x] TODO-17: Implement `define_design_class()` itself: resolve components, validate the
  definition, assemble public/private once, return an ordinary `R6::R6Class(...)`
  generator with `lock_objects = FALSE`. Deliberately does **not** call
  `register_design_class()` -- confirmed `define_inference_class()` doesn't either;
  every `Design`/`Inference` generator, however built, is registered uniformly by
  `populate_design_class_registry()`'s/`populate_inference_class_registry()`'s
  namespace scan at package-load time, so self-registering here would double-register
  and error the moment the scan also finds the same generator.
- [x] TODO-18: Add contract tests mirroring `mixin_contracts.R`'s own test coverage for
  `define_inference_class()`: `R/EDI/tests/testthat/test-design-class-factory.R` (14
  passing expectations) covers a minimal passing `BlockingStructure`-composing class
  with real behavioral assertions (not just "it builds"), the multi-level-inherit-chain
  regression above (both a `DesignFixed`-inheriting and a `Design`-inheriting host),
  true and false-premise missing-required-method rejection (confirmed
  `inherit = NULL` correctly triggers it, and confirmed `inherit = Design` directly
  does *not*, since `Design` itself owns `get_X_raw`), undeclared-collision rejection,
  declared-override acceptance, scaffold-component rejection, automatic
  `MatchingStructure -> BlockingStructure` dependency expansion end-to-end (a composed,
  working matched-design instance, not just the resolved name list), `lock_objects`
  enforcement, the kind-mismatch-suppression behavior noted above, and confirmation
  that a factory-built class is *not* auto-registered in
  `EDI_DESIGN_CLASS_REGISTRY`. No golden round-trip test against an equivalent plain
  `R6::R6Class(inherit = DesignBlocking, ...)`-built class was added, since (see below)
  no real production class was rewired this pass -- there is no "old way" to diff
  against yet for a component-composed class; add that golden test alongside the first
  real rewiring instead.
- [x] TODO-19: **Reconciled 2026-08-16 -- attempted despite this item's own stale
  self-correction, and the "hollow test" concern turned out to be wrong in practice.**
  `DesignFixedBlocking` (the recommended first target) was rewired onto
  `components = "BlockingStructure"` while still (pre-split) inheriting the same
  blocking behavior redundantly through `DesignFixed -> DesignMatching -> DesignBlocking`
  -- exactly the "carries the same behavior twice" scenario this item worried would
  prove nothing. It proved plenty: doing this against a *real* production class (not
  the synthetic throwaway classes TODO-18's tests use) is what actually surfaced the
  `Collate:` ordering defect (`define_design_class` sourced after the classes that
  needed it -- a real load-time bug no synthetic test caught, since synthetic tests all
  ran *after* the full package was already loaded) and, once `ClusterStructure` was
  wired into real `DesignFixedCluster` the same way, the `has_private_method()`
  dispatch bug documented under TODO-11. Both bugs were specific to wiring into real,
  already-shipped classes; neither would have been caught by staying purely synthetic
  until after the inherit flip, as this item originally recommended. 6 more classes
  were rewired the same way afterward (see TODO-8/10 above) with no further surprises
  of this kind, suggesting the first rewiring was where the real risk actually was, not
  the inherit flip itself (which remains separately gated on the ~20-class audit, not
  on any doubt raised here).

### Follow-Ups From Implementation (Audit Findings)

Findings surfaced while building and testing the Metadata Registry, Component Registry,
and Component Extraction sections above, each recorded inline in this file's completed
(`[x]`) items but not yet turned into their own actionable TODOs. Collected here rather
than left as prose-only notes.

- [x] TODO-20: **`exported` metadata is wrong under `devtools::load_all()`.** Confirmed and
  fixed for both registries.

  Candidate (b) (move population into `.onLoad()`) was tried and **empirically
  disproven**: added a diagnostic `cat(length(getNamespaceExports("EDI")))` at the top
  of `.onLoad()` in `zzz.R` and reloaded -- printed `0`. Under `devtools::load_all()`,
  pkgload attaches NAMESPACE exports *after* `.onLoad()` runs, not before, so moving the
  populate calls into `.onLoad()` would not have helped. (Diagnostic removed after
  confirming this.)

  Went with candidate (a), lazy computation, but not a blanket one: the first attempt
  (unconditionally overwriting `exported` on every read with a live
  `getNamespaceExports()` check) broke
  `test-inference-suite-discovery.R`'s "InferenceSuite discovery is registry
  metadata-only" test, which deliberately `register_inference_class()`s a synthetic
  class with an explicit `exported = TRUE` that is never actually attached to the
  namespace, and asserts that explicit value is honored regardless. A blanket
  live-recompute silently clobbers exactly that kind of deliberate, explicit
  registration -- a real behavioral contract, not an oversight.

  Final fix: `exported = NA` is now a valid sentinel value (validation loosened in both
  `validate_design_class_metadata()`/`validate_inference_class_metadata()` to allow it,
  mirroring the existing `randomization_family` NA-sentinel pattern already in
  `design_class_registry.R`). `populate_design_class_registry()`/
  `populate_inference_class_registry()` (the namespace-scanning bulk-populate
  functions) now register every scanned class with `exported = NA` instead of eagerly
  (and, at that point in the sourcing sequence, always wrongly) computing it.
  `get_design_class_metadata()`/`get_inference_class_metadata()` and
  `design_class_registry_as_list()`/`inference_class_registry_as_list()` resolve `NA`
  to a live `getNamespaceExports("EDI")` check at read time (by which point, in any
  real usage, the package is fully loaded and the check is accurate) -- but leave any
  non-`NA` value (i.e. an explicit registration, like the test's) untouched. This
  preserves the "registry metadata-only" contract for explicit registrations while
  fixing the scan-populated case, in one place, without needing scattered per-call-site
  workarounds.

  Also removed the two now-redundant `|| nm %in% getNamespaceExports("EDI")` band-aid
  clauses in `inference_suite.R` (`.class_compatibility_metadata()` and
  `.discover_applicable_design_classes()`) that had been separately papering over this
  exact bug at the only call site that actually consumed `exported` for real filtering
  logic -- the registry itself is now authoritative, so the OR-fallback was pure
  redundancy once fixed at the source.

  **Verified via `R CMD INSTALL`/`library(EDI)` was not attempted** (would require a
  full package build; out of scope for this fix since the lazy-read approach makes the
  distinction moot -- correct either way, whether exports attach before or after
  populate-time).

  Full regression sweep across both registries (`design*`, `inference-class-registry`,
  `inference-suite-discovery`, `capability-tables`, `mixin-contracts` test files) is
  clean **except for 3 pre-existing, unrelated failures**, confirmed via `git diff` to
  predate this fix and lie outside `fix_design_hierarchy.md`'s scope entirely:
  1. `test-design-inference.R:567` ("ordinal hardening drops QR-ranked...") --
     `cannot change value of locked binding for 'best_Xmm_colnames'` in
     `inference_all_abstract_asymp_lik_std_mod_cache.R`, a file with no uncommitted
     changes and last touched by the already-committed
     "intermediate work on ... inference hierarchy migration ... y/y_L/y_R migration"
     commit -- part of that separate, in-progress migration, not this plan.
  2. & 3. `test-inference-suite-discovery.R:16` and `:79` -- expect
     `InferenceAllSimpleMeanDiff`/`InferenceAllKKMeanDiffIVWC` to be discoverable, but
     both are genuinely absent from `NAMESPACE` despite carrying `@export` roxygen tags
     in their source (confirmed via `grep`). Both source files
     (`inference_all_simple_mean_diff_pooled_var.R`,
     `inference_all_KK_mean_diff_IVWC.R`) show substantial *uncommitted* diffs already
     present at the start of this session (unrelated concurrent work), and `NAMESPACE`
     was never regenerated to match -- consistent with this repo's already-known
     `fast_roxygenize.R` package-wide failure blocking routine NAMESPACE regeneration.
     Confirmed this is not something the `exported` fix introduced: under the *old*
     buggy code, `inference_suite.R`'s live-namespace OR-fallback would have hit the
     exact same "genuinely not in NAMESPACE" answer for these two classes, so these
     two assertions were already failing before this fix, for the same underlying
     reason. Not fixed here -- hand-editing `NAMESPACE` outside a real roxygenize pass
     is exactly the kind of interim patch this project avoids doing mid-batch; belongs
     with whatever wraps up the concurrent migration.
- [x] TODO-21: **`DesignBlocking$get_block_ids()`'s coupling into `DesignFixedOptimalBlocks`-only
  private state.** Fixed the specific `is()` check without waiting for the full
  "Timing-Family Split" rewiring: `design_blocking_abstract.R:111`'s
  `is(self, "DesignFixedOptimalBlocks")` guard is replaced with
  `private$has_private_method("get_or_compute_block_ids")` (the existence-check helper
  already defined on root `Design`, `design_abstract.R:827`). This is option (b) from
  the original note in spirit -- no more class-identity dispatch -- achieved more
  cheaply than "move the computation into its own component/hook," which still needs
  the full rewiring this item originally assumed was a prerequisite. The existence
  check is exactly what `optional_private_methods` in the component contract already
  models (an optional hook that may or may not be present on the host), so this isn't
  a new pattern -- it's making the code match the contract that was already declared.
  Generalizes correctly to any future class that defines the same hook, without
  needing this check updated. `BlockingStructure`'s registration in
  `design_component_registry.R` gained `requires_private_methods =
  "has_private_method"` accordingly (caught immediately by the parser-backed
  body-reference validator when first tried without it -- confirms that validator
  does its job). Verified `DesignFixedOptimalBlocks` and `DesignFixedBlocking` both
  still produce correct block IDs; full regression suite (`test-design-*`,
  `test-resampling-draw-contracts.R`) passes unchanged. Left as a smaller, standalone
  fix rather than folding it into "Timing-Family Split" -- there was no reason to wait.
  Note: `get_block_ids()` has a second, closely related `is(self, "DesignFixedBlocking")
  || is(self, "DesignFixedBlockedCluster")` check (design_blocking_abstract.R:115-116)
  guarding the `strata_cols`-based fallback branch, not touched here -- unlike the fix
  above, removing it isn't a clean drop-in (the `!is.null(strata_cols) &&
  length(strata_cols) > 0` condition already present alongside it may or may not be
  sufficient on its own for every case), so it's left as a separate, smaller follow-up
  rather than assumed to be the same shape of fix.
- [x] TODO-22: **Author the generalized stratified `draw_bootstrap_indices()` for
  `BlockingStructure`.** Implemented in `design_component_registry.R`: calls
  `self$get_block_ids()` to derive `group_id`, then either
  `stratified_bootstrap_indices_cpp()` (`bootstrap_type` `NULL`/`"within_blocks"`) or
  `resample_group_rows_cpp()` (`"whole_group"`) -- the same two-branch shape as
  `ClusterStructure`'s generalization above, but keyed off blocks instead of clusters.
  Added to `BlockingStructure`'s `private` list and `provides_private_methods`; required
  adding `requires_private_methods = "has_private_method"` (already relied on
  transitively, now declared) since the body-reference validator caught the new
  reference.

  **Scope narrowed from the original 5 classes to 3.** Investigating all 5 named
  classes found only `DesignFixedBlocking`, `DesignFixedOptimalBlocks`, and
  `ObservationalDesignBlocks` actually reduce to one generalization via
  `self$get_block_ids()` (the public dispatcher, which itself already branches on
  `private$m` / `get_or_compute_block_ids()` / `get_strata_keys()`). The remaining two,
  `DesignSeqOneByOneRandomBlockSize` and `DesignSeqOneByOneSPBR`, use a fundamentally
  different row-by-row `private$get_strata_key(x_row)` mechanism against a growing
  `private$Xraw` (sequential one-by-one accrual, not a fixed matrix) -- not reducible to
  the same code without a separate generalization. Split out as its own follow-up below.

  Golden-verified (`test-design-blocking-structure-bootstrap-golden.R`, new file, 9
  passing expectations) byte-identical (`identical()`, matched seeds) against all 3
  real classes' actual output, across all 3 `bootstrap_type` values each:
  - `DesignFixedBlocking`: synthetic host needs `private$strata_cols` explicitly set
    (real `DesignFixedBlocking`'s constructor defaults it from covariate names when
    unsupplied, but a class not literally named `"DesignFixedBlocking"` doesn't get the
    `is(self, "DesignFixedBlocking")` bypass at design_blocking_abstract.R:115 -- see
    the untouched-check note above); also needs `equal_block_sizes = FALSE` to avoid a
    real, expected `assert_equal_block_sizes` rejection on unbalanced synthetic strata.
  - `DesignFixedOptimalBlocks`: real class's own `draw_bootstrap_indices` calls
    `private$get_or_compute_block_ids()` directly and never populates `private$m`; the
    synthetic host instead had to call the real instance's public `get_block_ids()`
    once (which *does* cache into `private$m`, design_blocking_abstract.R:131) to
    obtain a comparable block-id vector to seed the synthetic host with.
  - `ObservationalDesignBlocks`: straightforward, `m` supplied directly by the user at
    construction.

  **Collision fallout discovered and fixed while re-running the regression sweep:**
  adding `draw_bootstrap_indices` to `BlockingStructure` means any class composing
  *both* `BlockingStructure` and `MatchingStructure` or `ClusterStructure` now hits an
  undeclared private collision, because both sides provide the method and the more
  specific one (matching's pair-preserving resample; cluster's strata+cluster-aware
  resample) must win. This is the collision detector working as intended, not a bug --
  fixed by adding explicit `overrides = list(private = "draw_bootstrap_indices")` at the
  two affected composition sites (`test-design-class-factory.R`'s
  `MatchingStructure -> BlockingStructure` auto-expansion test, and
  `test-design-cluster-structure-golden.R`'s `DesignFixedBlockedCluster` host).
  `combine_design_component_slot()` resolves same-key collisions via
  `utils::modifyList()` in component-processing order, so whichever component is
  positioned later (either explicitly, as in `c("BlockingStructure",
  "ClusterStructure")`, or via dependency-expansion putting the depended-on component
  first) wins -- confirmed this ordering already produces the semantically correct
  winner in both cases without further changes. Also updated
  `test-design-component-registry.R`'s exact-list assertion of
  `BlockingStructure$provides_private_methods` to include the new method. Full
  regression sweep (8 files) green after these fixes: 9+24+566+64+38+18+5+46 = 770
  passing expectations, 0 failures.
- [x] TODO-23: **Generalize the sequential random-block-size bootstrap
  (`DesignSeqOneByOneRandomBlockSize`, `DesignSeqOneByOneSPBR`).** Split out of the
  `BlockingStructure` item above because these two classes don't go through
  `self$get_block_ids()` at all -- they maintain blocks incrementally via a
  private `get_strata_key(x_row)`-keyed structure against a growing `private$Xraw`
  as subjects accrue one at a time, and each currently hand-rolls its own
  near-duplicate version of that logic. Needs its own generalization (component TBD --
  likely a new sequential-specific component, not `BlockingStructure`, since the data
  model is row-by-row rather than matrix-based) and its own golden tests before any
  code is shared or classes are rewired.

  Implemented as the active `SequentialStrataBootstrap` component in
  `design_component_registry.R`, separate from matrix-based `BlockingStructure`. It
  provides the shared row-wise `get_strata_key()` and `draw_bootstrap_indices()`
  methods and explicitly records the one pre-existing host-policy difference:
  `DesignSeqOneByOneSPBR` supports whole-stratum resampling, whereas
  `DesignSeqOneByOneRandomBlockSize` historically treats every `bootstrap_type` as
  within-stratum and additionally supports an unstratified subject-resampling mode.
  `test-design-sequential-strata-bootstrap-golden.R` verifies matched-seed,
  byte-identical output against both real classes for `NULL`, `"within_blocks"`, and
  `"whole_group"`, including RandomBlockSize's unstratified reduction. The real
  classes remain unwired until the Timing-Family Split, consistent with the other
  component extractions.
- [x] TODO-24: **Author the generalized `ClusterStructure` (`draw_bootstrap_indices`).**
  Implemented in `design_component_registry.R`: one function handles both
  `DesignFixedCluster`'s single-level cluster resample and
  `DesignFixedBlockedCluster`'s two-level strata-then-cluster resample, using
  `private$has_private_method("get_strata_keys")` to decide whether real strata are
  available or whether to fall back to a single implicit stratum (the reduction case).
  `ClusterStructure` promoted from `status = "scaffold"` to `status = "active"`.
  Golden-verified (`test-design-cluster-structure-golden.R`, 5 passing expectations)
  byte-identical (`identical()`, matched seeds) against both real classes' actual
  output: `DesignFixedCluster` (no stratification) and `DesignFixedBlockedCluster`
  under all three `bootstrap_type` values (`NULL`, `"within_blocks"`,
  `"whole_group"`). Not wired into either real class yet -- same deferral as
  `BlockingStructure`/`MatchingStructure`, pending the actual "Timing-Family Split"
  rewiring.

  **Important finding surfaced while verifying this, worth generalizing beyond
  `ClusterStructure` itself:** the first verification attempt composed the synthetic
  test host as `inherit = DesignFixed` and failed with a real (if confusing) runtime
  error, because `DesignFixed` still (pre-split) inherits transitively through
  `DesignMatching -> DesignBlocking` -- confirmed empirically that
  `private$has_private_method("get_strata_keys")` returns `TRUE` for *any* current
  `DesignFixed` subclass today, including `DesignFixedBernoulli`, which has no
  blocking structure at all, purely because `DesignBlocking` is still a mandatory
  ancestor of everything. Fixed by composing the test host as `inherit = Design`
  directly, bypassing the contaminated ancestry, to test the generalized logic in
  isolation. This means **`has_private_method()` existence checks against a method
  defined on `DesignBlocking`/`DesignMatching` themselves are not a reliable
  "was this component actually composed" signal until "Timing-Family Split" cuts
  that ancestry** -- unlike the `get_or_compute_block_ids` existence check added to
  `BlockingStructure` earlier, which remains safe today specifically because that
  method lives only on the leaf class `DesignFixedOptimalBlocks`, never inherited by
  any sibling. Any future component author reaching for this same
  optional-hook-via-existence-check pattern against an ancestor-level (not
  leaf-level) method needs to know this gap exists before relying on it against a
  real (not synthetic) class.
  Also fixed two now-outdated test assertions this promotion broke (`ClusterStructure`
  was previously asserted to be a scaffold, and used as the scaffold example in the
  factory's scaffold-rejection test) -- `test-design-component-registry.R` now
  asserts `ClusterStructure` is active with real behavior, and the scaffold-rejection
  tests use `AllocationMatrixValidation` (still genuinely a scaffold) instead.
- [ ] TODO-25: **Reconcile `AllocationMatrixValidation`'s three behavioral differences**, each a
  concrete decision, not just "merge them": (1) should `require_balanced` (currently
  `DesignFixedRerandomization`-only, conditionally checked) apply to all four consuming
  classes, always-on, or stay an opt-in parameter? (2) when a search returns fewer
  replicate columns than requested, should the shared implementation recycle columns
  (current `DesignFixedBinaryMatch` behavior) or error (current behavior of the other
  three)? (3) should column selection use `seq_len(r)` (errors past the end) or
  `min(r, ncol(w_mat))` (current `DesignFixedRerandomization` behavior, silently
  truncates)? Record the decision and rationale for each before writing the merged
  implementation and deleting the four duplicates.
- [x] TODO-26: **Investigate `DesignFixedMatchingGreedyPairSwitching`'s missing
  `matching_capable`.** Decided: **latent gap, not intentional** -- but fix it as part
  of the class's "Timing-Family Split" rewiring, not as an isolated change here.
  Reasoning: this class's own `draw_bootstrap_indices` (design_fixed_matching_greedy_pair_switching.R:139-154)
  already calls `draw_matching_bootstrap_sample_cpp` directly and is documented
  (`inference_all_abstract_non_param_boot.R:85-92`) as correctly pair-preserving --
  that behavior does not depend on `matching_capable` at all, since this override
  shadows `DesignMatching`'s dispatch-by-flag version entirely, so it is *not* at
  risk here. The actual gap is narrower and confirmed real: code paths that query
  `is_matching_design()`/`get_matching_cluster_ids()` for a *different* purpose --
  jackknife unit selection (`inference_all_abstract_jackknife.R`), Bayesian-bootstrap
  unit selection, `inference_ext_exchangeable_resampling_units.R` -- currently treat
  this design as non-matching and fall back to a per-subject unit, inconsistent with
  the design's own already-pair-aware nonparametric bootstrap for the exact same
  data. Confirmed via grep that no test asserts `is_matching_design() == FALSE` for
  this class (only `test-w-encoding.R`'s `{0,1}`-encoding check touches it), so
  fixing the flag would not break an existing pinned expectation -- but it *would*
  change jackknife/Bayesian-bootstrap SE output for any current user of this class
  with those inference paths (a real statistical-behavior change, not pure
  plumbing), which is exactly the kind of change that belongs bundled with, and
  golden-tested alongside, the class's actual rewiring (set `matching_capable`/
  `blocking_capable`, populate `private$m` from `private$bms$indicies_pairs`,
  compose `MatchingStructure` via `define_design_class()`) rather than flipped in
  isolation disconnected from that work. Left unimplemented this pass, as originally
  scoped; this entry now records the decision and its reasoning, not just the open
  question.
- [x] TODO-27: **Add the component-slot-state-survival regression test flagged in Source
  Invariant #15.** Added in `test-design-class-factory.R`
  ("BlockingStructure component-owned state survives `Design$duplicate()`", now
  feasible because `define_design_class()` exists): builds a component-composed
  design, runs it through a full experiment (subjects, `set_m()`, responses), calls
  `duplicate()`, and confirms (a) the clone's `BlockingStructure`-owned `m` state
  survives with its actual value rather than being reset, and (b) the clone is a
  genuinely independent copy -- mutating the clone's `private$m` after duplication
  does not bleed back into the original. Result: **no bug found** here, unlike the
  `InferenceContinQuantileRegr` precedent this test was written to guard against --
  `Design$duplicate()`'s `self$clone()` (plain R6 clone, not a hand-rolled
  worker-clone helper) correctly preserves dynamically-added private fields, matching
  what the `Inference` migration's own correction note found for R6's built-in
  `clone()` versus its bespoke `duplicate()`-style helpers. This is a real regression
  guard now in place, not a fix for a bug that existed -- worth keeping precisely
  because it costs nothing today and catches the failure mode early if a future
  change (e.g. a hand-rolled bootstrap-worker clone path for `Design`, mirroring the
  ones that caused the `Inference`-side bug) reintroduces it.
- [ ] TODO-28: **Delete the temporary `Design$capabilities()`/`supports()` legacy-predicate
  bridge** once class rewiring lands and the component registry alone is authoritative.
  The bridge (added in the `BatchWPregeneration` extraction item above, documented as
  temporary in its own roxygen) currently answers capability queries by consulting the
  legacy `is_blocking_design()`/`is_matching_design()`/`supports_batch_w_pregeneration()`
  predicates; leaving it in place after rewiring would let the registry and the legacy
  predicates silently disagree about what a design supports.
- [ ] TODO-29: **Extend seed-reproducibility bookkeeping to OpenMP scheduling nondeterminism.**
  `sexp_removal_rcppeigen_conversion_spec.md`'s RNG migration (its TODO-12) confirmed
  `rerandomization_search_cpp` is not bit-reproducible across identically-seeded runs
  when `OMP_NUM_THREADS > 1`: which thread claims which chunk/result slot is decided by
  real-time OS scheduling (`std::atomic` `fetch_add`), not RNG state — single-threaded
  runs reproduce exactly. Decide whether `seed_reproducible_draw` metadata should encode
  this thread-count caveat for `DesignFixedRerandomization` (and audit the other
  OpenMP-parallel designs — greedy, binary-match, A-/D-optimal once fixed — for the same
  work-stealing pattern), or whether the kernels should assemble results
  deterministically (e.g. index-ordered result writes) so multi-threaded draws are
  seed-reproducible too; then make the seed-reproducibility regression test below run
  with `OMP_NUM_THREADS > 1` so the claim is tested under the setting where it can
  actually break.
- [x] TODO-30 (completed by a concurrent session, verified via code inspection
  2026-08-16 -- `design_fixed_a_optimal.R`/`design_fixed_d_optimal.R` are gone,
  `DesignFixedGreedyDOptimal` exists and is registered; not this session's work, so
  not narrated further here): **Merge `DesignFixedAOptimal`/`DesignFixedDOptimal` into one unified
  optimal-design class (decision updated 2026-08-15, superseding the earlier
  `criterion = c("M", "A")` shape).** Verified against the kernels before
  recording: `d_optimal_search_cpp` greedy-minimizes `w'Pw`, and by the
  Schur-complement identity `det([w Z0]'[w Z0]) = det(Z0'Z0) * (n_T - w'Pw)`
  (with `w'w = n_T` fixed), minimizing `w'Pw` simultaneously maximizes the
  full-matrix determinant **and** the information on the treatment
  coefficient given the covariate block — so full-`M` determinant optimality
  and treatment-focused D_s/c-/A-optimality coincide in the allocation they
  select, and the existing D kernel already serves both. The only member
  needing different machinery is trace-based A-optimality over all
  parameters (`a_optimal_search_cpp`, objective `(w'Hw + 1)/(n_T - w'Pw)`,
  `H = Z0 (Z0'Z0)^-2 Z0'`). Unified API (three orthogonal knobs; class name
  **`DesignFixedGreedyDOptimal`** — confirmed by the user 2026-08-15, closing
  the naming question):

  ```r
  DesignFixedGreedyDOptimal$new(
    response_type,
    objective              = "D",         # "D" (determinant) | "A" (trace)
    interest               = "treatment", # "treatment" (default) | "all" |
                                          #   covariate names/formula (D_s) |
                                          #   contrast matrix (D_A)
    prior_precision        = NULL,        # NULL | scalar tau | matrix R ->
                                          #   Bayesian D_B/A_B: build P and H
                                          #   from (Z0'Z0 + R0)^-1; scalar tau
                                          #   penalizes COVARIATES ONLY --
                                          #   treatment and intercept
                                          #   unpenalized (user decision
                                          #   2026-08-16), i.e. R0 = tau * D
                                          #   with zero diagonal entries for
                                          #   the treatment and intercept
                                          #   coordinates -- exactly the
                                          #   block-diagonal structure the
                                          #   determinant factorization below
                                          #   requires
    standardize_covariates = TRUE,        # honored when prior_precision scalar
    n_iter                 = Inf,         # Inf = exhaustive best-improvement;
                                          #   integer = stochastic swap mode
                                          #   (engine passthrough; in the
                                          #   constructor from day one --
                                          #   user decision 2026-08-16)
    ...                                   # prob_T, n, design_formula, seed, ...
  )
  ```

  Implementation scope (updated 2026-08-15: general D_s/D_A is implemented,
  not stubbed — the user rejected the forwarded proposal's
  "error until needed" hedge, and the math justifies it: the general-`K`
  kernel *subsumes* both existing kernels, so it is the unifying
  implementation rather than an add-on). The mathematical core, verified
  against the existing kernels: with `M(w) = [w Z0]'[w Z0]` and only `w`
  varying, block inversion gives `M(w)^-1 = G0 + u(w)u(w)'/s(w)` where
  `G0 = blockdiag(0, V)`, `V = (Z0'Z0)^-1`, `s(w) = n_T - w'Pw` (the scalar
  the D kernel already maintains via `Pw`), `b(w) = V Z0'w`, and
  `u = (1, -b')'`. For any contrast matrix `K` (partitioned `K1` treatment
  row, `K2` covariate rows), the criterion depends on `w` only through `s`
  and `c(w) = K1 - K2'b(w)`:
  - `A_K`: `tr(K'M^-1 K) = tr(K'G0 K) + c'c / s` — minimize `c'c / s`.
  - `D_K`: `det(K'M^-1 K) = det(K'G0 K) * (1 + c'(K'G0 K)^-1 c / s)` by the
    matrix determinant lemma (when `K'G0 K` is invertible; the treatment-only
    contrast `K = e1`, where it is singular, reduces to minimizing `s^-1`'s
    numerator — i.e. the existing D kernel).
  Consistency checks that anchor the implementation: `K = e1` reproduces the
  existing D kernel exactly; `K = I` gives `tr(M^-1) = tr(V) + (1 + b'b)/s`
  and `b'b = w'Hw` with `H = Z0 V^2 Z0'` — i.e. the existing A kernel's
  objective `(w'Hw + 1)/(n_T - w'Pw)` plus a constant.

  **Staging (user decision 2026-08-16, two stages):**
  - *Stage 1 — zero new C++*: **IMPLEMENTED 2026-08-16.** Landed as
    `R/design_fixed_greedy_d_optimal.R` (factory-built, dynamically-created
    private state per the `modifyList`-NULL-drop lesson, always-on
    validation, general `prob_T` with `n_T = round(n * prob_T)` in both
    kernel and no-covariate fallback paths); both old classes deleted
    (`git rm`); registry enum/`BY_NAME` updated,
    `EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES` now `character(0)` with
    the stale `std::random_device` comment replaced; `DESCRIPTION` Collate
    updated; roxygen cross-references fixed in five sibling design files +
    `inference_all_abstract_non_param_boot.R` (including
    `DesignFixedGreedy`'s now-false "unlike A/D, reproducible" contrast
    sentences); `simulations_framework.R`'s generator list and
    `package_tests/comprehensive_tests.R`/`audit_comprehensive_suite_baseline.R`
    harness keys updated (`FixedGreedyDOptimalD`/`FixedGreedyDOptimalA` —
    their CSV baselines will drift and regenerate at the next
    comprehensive-suite run); `vignettes/reproducibility.Rmd` rewritten (its
    whole "two genuinely non-reproducible designs" narrative predated the
    RNG migration); `fix_documentation.md`'s old-class Rd TODOs annotated as
    superseded; `man/`/`NAMESPACE` regenerated (old Rd pages deleted, new
    page + export created). Verified: new
    `test-greedy-d-optimal-merged.R` (32 assertions — golden equivalence
    against the raw kernel path byte-for-byte, empirical same-seed
    reproducibility for both kernels, the Schur `interest` equivalence, the
    silent `objective = "A", interest = "treatment"` equivalence, Bayesian
    scalar/matrix/tiny-tau behavior, `prob_T = 0.3` treated counts,
    validation errors, registry metadata) plus all design suites green: 789
    assertions across registry/component/extraction-golden/hierarchy/greedy/
    kernel test files, 46 in `test-resampling-draw-contracts.R`, 0 failures.
    `test-w-encoding.R` fails independently of this work
    (`_EDI_get_column_types_cpp` missing from the installed DLL — install-
    state drift from the concurrent session's sequential-design edits; the
    path is untouched by this refactor). Original Stage-1 scope for
    reference: the merged class via `define_design_class()`
    with R-side dispatch to the two existing kernels (`interest = "treatment"`
    or `"all"` with `objective = "D"` -> D kernel; `objective = "A",
    interest = "all"` -> A kernel), the Bayesian variants via the
    `(Z0'Z0 + R0)^-1` precompute swap, both old classes deleted, registry
    enum/closed-enum tests/`test-d-optimal-row-access.R`/
    `test-optimal-design-hoisted-allocs.R` updated, and the golden
    allocation-equivalence tests written here.
  - *Stage 1 addendum (implemented 2026-08-16, user request):* `interest =`
    **formula / formula-string / covariate-names is Stage 1 after all** — the
    natural subset cases need no new C++. Two reductions, both proven in the
    class docs and tests: subset-D (treatment + any covariate subset) has
    `det(K'M(w)^-1 K) = det(V_SS)/s(w)` by the adjugate identity
    (`adj(diag(0, V_SS)) = det(V_SS) e1 e1'`), so it selects allocations
    identical to the default D criterion — existing D kernel; subset-A is
    `(w'H_S w + 1)/s(w)` with `H_S = (Z0 V S)(Z0 V S)'` — the existing A
    kernel with a subset-restricted `H` built in R. Formula strings like
    `"x1 * x2 + x7"` are promoted to one-sided formulas; interest terms
    (including interactions) must be columns of the design's model matrix
    (put interactions in `design_formula` to target them). The roxygen now
    documents the D_M/D_s/D_A/D_B criterion family and its exact argument
    mapping, per user request.
  - *Stage 2 — one C++ work item*: the general-`K` kernel **together with**
    the shared greedy-swap engine extraction (next bullet) — naturally one
    piece of work, and Stage 1's golden tests become Stage 2's regression
    net. Remaining Stage-2 `interest` scope (narrowed by the addendum):
    general contrast matrices (D_A) and interest sets excluding the
    treatment coefficient (whose criteria pick up a linear-in-`w` term the
    current kernels cannot represent), plus the stochastic `n_iter` mode.

  **UX decision (user-confirmed 2026-08-16):** the redundant combination
  `objective = "A", interest = "treatment"` (single-parameter A- and
  D-optimality coincide) is allowed silently, with the equivalence documented
  in the roxygen.

  **Compatibility contract with this plan's own end state** (user
  instruction 2026-08-16: the implementation must not conflict with the
  completed shallow design hierarchy):
  - Built via `define_design_class()` with a full metadata record:
    `timing_family = "fixed"`, `randomization_family = "greedy_d_optimal"`,
    `direct_components = character()` (no blocking/matching/cluster
    structure, so the class is untouched by the Timing-Family Split and can
    be implemented before or after it), `required_packages = character()`,
    `seed_reproducible_draw = TRUE` once the empirical same-seed check in
    the Seed-Reproducibility section passes.
  - `supports_batch_w_pregeneration` is registry **metadata only** (never an
    overridable method — generator sniffing is retired): Stage 1 keeps it
    `FALSE` (today's serial A/D kernels); Stage 2 flips it to `TRUE` when
    the shared engine's OpenMP batched restarts land — a one-line metadata
    change the framework reads automatically.
  - No `supports_*()` boolean methods, no new `is_a_*` characterization
    flags, no `.__enclos_env__` reads, no class-name dispatch anywhere in
    the implementation; capability questions go through `supports()`/
    registry metadata, criterion questions through object accessors
    (e.g. `get_objective()`).
  - Constructor validation (`prob_T` in (0,1), `interest`/`prior_precision`
    shape checks) is **always-on cheap validation, not assert-gated** — the
    lesson from the `DesignFixedGreedy` `prob_T` bypass gap below.
  - Do not add a fifth `validate_allocation_matrix` duplicate: reuse the
    existing validation surface and coordinate with the
    `AllocationMatrixValidation` reconciliation follow-up above.
  - **Pre-deletion name-reference sweep** — the old class names live outside
    their own files; known hits that must change in the same commit as the
    deletion: `EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME`
    (`design_class_registry.R:46,53`),
    `EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES`
    (`design_class_registry.R:82`, plus its stale `std::random_device`
    comment), the closed-enum values and per-class spot-checks in
    `test-design-class-registry.R`, the two optimal-design test files,
    roxygen cross-references in other design files (`DesignFixedGreedy`'s
    docs cite both old classes by name — regenerate via
    `Rscript fast_roxygenize.R`), and `fix_documentation.md`'s per-Rd TODOs
    for the deleted classes (mark obsolete, as the `supports_*` TODOs were).
    Run `grep -rn "DesignFixedAOptimal\|DesignFixedDOptimal"` across `R/`,
    `tests/`, `package_tests/`, and `package_metadata/` before deleting.

  Kernel work items (Stage 2 unless noted):
  1. R-side canonicalization of `interest` into `K`: `"treatment"` -> `e1`;
     `"all"` -> `I`; covariate names/formula -> the selection matrix over the
     model-matrix columns (resolve against `colnames(private$X)` post
     `design_formula`, erroring on unmatched names); matrix -> validated
     `(1 + p) x q` contrast matrix.
  2. One generalized C++ search (`general_optimal_search_cpp` or the shared
     engine below with a `K`-criterion functor): precompute `B = V Z0'`
     (`p x n`), `G_K = K'G0 K`, its inverse and log-det once per call;
     maintain `(Pw, s, b, c)` across swaps — `b` updates in `O(p)` per swap
     from `B`'s columns, `c` in `O(p q)`, criterion in `O(q^2)`.
  3. Retire the two specialized kernels *or* keep them as fast paths for
     `K = e1`/`K = I` — decide by benchmark: the specialized D scan has a
     sorted-scan pruning bound that the general criterion lacks; if the
     general kernel's exhaustive `O(n_T * n_C)` pair scan per round (with the
     cheap deltas above) benchmarks within tolerance at realistic `n`, delete
     the specialized kernels; otherwise keep them as dispatch targets for the
     two degenerate `K`s.
  4. Bayesian variants compose: swap `V = (Z0'Z0)^-1` for `(Z0'Z0 + R0)^-1`
     in the `B`/`H`/`G_K` precomputes — no other kernel change.
  5. Tests: golden allocation-equivalence under a shared seed for `K = e1`
     vs. the current D kernel and `K = I` (trace) vs. the current A kernel;
     unit tests for the `interest` canonicalization (names, formula, matrix,
     unmatched-name errors); randomization-distribution behavior tests per
     this plan's standing requirements; and a numerical check of the
     determinant-lemma path against brute-force `det(K' solve(M) K)` on
     small `n`. Notes binding earlier discussion:
  `interest` subsumes the previously mooted `criterion_formula` argument;
  document the distinction from `design_formula` (which changes the design's
  model matrix globally *and* the inference-side default `model_formula`,
  `inference_all_abstract.R:43`, whereas `interest` affects only the
  allocation criterion). **Registry: exactly one `randomization_family`
  value, `"greedy_d_optimal"`** (confirmed by the user 2026-08-16) — the
  registry is class-level metadata;
  `objective`/`interest`/`prior_precision` are object state per the
  `DesignFixedOptimalBlocks` `method =` precedent, not a fan of per-criterion
  registry strings. **Delete both old classes outright** — the forwarded
  proposal's "keep them as two-line deprecated subclasses" contradicts this
  repo's no-alias policy for the unreleased package (and the registry's
  canonical-generator tests would flag alias generators); update
  `EDI_DESIGN_RANDOMIZATION_FAMILY_BY_NAME`, the closed-enum tests in
  `test-design-class-registry.R`, and the existing
  `test-d-optimal-row-access.R`/`test-optimal-design-hoisted-allocs.R`
  suites to construct the unified class. Explicitly still decided *against*
  folding in `DesignFixedGreedy` (model-free balance objectives, hard
  `prob_T = 0.5` requirement baked into their `X'(2w-1)/n` formulation) —
  it shares the search engine below, not the class.
- [ ] TODO-31: **Extract one shared greedy pairwise-swap search engine** used by the
  merged `DesignFixedGreedyDOptimal` and by `DesignFixedGreedy` (which stays its own
  class): a single C++ engine over an objective functor
  (`init(w)`/`delta(i, j)`/`apply_swap(i, j)`), replacing the three
  near-duplicate search loops. Wins to carry over in both directions:
  A/D gain `DesignFixedGreedy`'s per-thread OpenMP parallelism over the `r`
  restarts (they are currently serial), its thread-count-independent
  per-thread seeding, `supports_batch_w_pregeneration`, and the stochastic
  `n_iter` mode; greedy gains the A/D kernels' sorted-scan pruning
  acceleration for the exhaustive pair search. One engine also means one
  shared no-covariate BCRD fallback and one place for the seed-reproducibility
  regression test above.
- [ ] TODO-32: **Fix the stale A/D-optimal roxygen reproducibility claims** while
  merging: `design_fixed_d_optimal.R:27-28` (and `design_fixed_a_optimal.R`'s
  equivalent) still say the initial shuffle is *not* reproducible via the
  constructor's `seed` — stale since the RNG migration seeded
  `edi_rng::RRng` from `R::unif_rand()`; same staleness cluster as the
  registry metadata/comment covered in the Seed-Reproducibility audit note
  above. Fix all three surfaces (roxygen, registry values, registry comment)
  in one change with the empirical same-seed-identical-draws check.
- [ ] TODO-33: **Close the assert-gated `prob_T = 0.5` bypass in `DesignFixedGreedy`.**
  Both the constructor's `prob_T != 0.5` stop and `draw_ws_raw()`'s even-`n`
  check run only under `should_run_asserts()`, while the kernel
  unconditionally hardcodes `nt = n / 2` (`design_fixed_greedy.cpp:57`) —
  with asserts off, `prob_T = 0.3` constructs silently and every consumer
  reading `get_prob_T()` reasons about a different design than the one
  actually drawn (and odd `n` silently truncates). Make these
  always-on validation (cheap scalar checks, not assert-tier), or a
  registry-metadata constraint the factory enforces — the same
  "flag and the state it gates can silently disagree" disease Evidence item 3
  catalogs.

### Timing-Family Split (`DesignFixed`/`DesignSeqOneByOne` off `Design` directly)

- [x] TODO-34: **Phase 1: rewire concrete classes onto explicit `components = c(...)`,
  behavior-preserving, while `DesignFixed`/`DesignSeqOneByOne` still inherit
  `DesignMatching -> DesignBlocking`.** Converted 7 of the originally-planned 9
  classes from plain `R6::R6Class()` to `define_design_class()`, verified behavior
  unchanged (existing test suite + the blocking/cluster golden test files) after each:
  `DesignFixedBlocking`, `DesignFixedOptimalBlocks`, `ObservationalDesignBlocks`
  (`BlockingStructure`); `DesignFixedBlockedCluster` (`BlockingStructure` +
  `ClusterStructure`, with `overrides` since both now provide
  `draw_bootstrap_indices`); `DesignFixedCluster` (`ClusterStructure`);
  `DesignFixedBinaryMatch`, `DesignSeqOneByOneKK14`, `ObservationalDesignMatching`
  (`MatchingStructure`, which auto-expands to include `BlockingStructure`, requiring
  the same `draw_bootstrap_indices` override plus, for `DesignFixedBinaryMatch`
  specifically, an additional override for `ensure_matching_structure_computed` since
  that class's own nbpMatching-specific version genuinely differs from
  `MatchingStructure`'s generic one and must win).

  **Deliberately skipped, not mechanical:** `DesignFixediBCRD` and
  `DesignFixedMatchingGreedyPairSwitching`. Both currently have real
  flag/state gaps (`DesignFixediBCRD` sets `private$m` but never
  `blocking_capable`; `DesignFixedMatchingGreedyPairSwitching` sets neither
  `blocking_capable` nor `matching_capable` despite having real pair structure) --
  composing components here would force an immediate decision on whether to also fix
  those flags, which changes real downstream behavior (jackknife/Bayesian-bootstrap
  unit selection, CMH-family eligibility) for existing users and needs its own
  golden-tested follow-up, not a silent side effect of mechanical rewiring. Left as
  their own explicit TODO below.

  `DesignSeqOneByOneRandomBlockSize`/`DesignSeqOneByOneSPBR` were already out of scope
  (see the "Follow-Ups" `BlockingStructure` item above -- different row-by-row
  mechanism, separate follow-up needed first).

  **Three real bugs found and fixed while doing this, not just mechanical rewiring:**
  1. **File-load ordering.** `define_design_class` (design_class_factory.R) and the
     component registry's populate call (design_component_registry.R) both sourced
     *after* the concrete `design_fixed_*.R`/`design_seq_one_by_one_*.R` files in
     `DESCRIPTION`'s `Collate:` field, so the very first converted class
     (`DesignFixedBlocking`) failed to load with `could not find function
     "define_design_class"`. Fixed by moving `design_matching_abstract.R`,
     `design_fixed_abstract.R`, `design_fixed_greedy.R` (needed early because
     `BatchWPregeneration`'s registration pulls a real reference from
     `DesignFixedGreedy`), `design_component_registry.R`, and `design_class_factory.R`
     earlier in `Collate:` (right after `design_blocking_abstract.R`), and moved the
     `populate_design_component_registry()` invocation itself out of
     `design_class_registry.R`'s bottom into `design_component_registry.R`'s own
     bottom (so components are populated immediately once that file sources, not only
     once the much-later `design_class_registry.R` sources). `design_class_registry.R`'s
     own `populate_design_class_registry()` call stays last (it needs every Design
     generator, abstract and concrete, already defined for its namespace scan).
  2. **`ClusterStructure`'s `has_private_method("get_strata_keys")` dispatch broke
     real `DesignFixedCluster` the moment it was actually wired up** (not just a
     synthetic-host risk anymore, as originally flagged in the "Author the
     generalized ClusterStructure" item above): `DesignFixedCluster` has no
     `strata_cols` at all, but still inherits `get_strata_keys` transitively through
     `DesignMatching -> DesignBlocking`, so the existence check incorrectly took the
     "call `get_strata_keys()`" branch and errored inside it. Fixed by switching the
     dispatch to `isTRUE(private$blocking_capable)` -- an explicit capability flag,
     immune to the ancestry-contamination problem in both directions (correct today
     *and* after the eventual inherit flip below) -- rather than an inherited-method
     existence probe. Updated `ClusterStructure`'s `requires_state` from
     `requires_private_methods = "has_private_method"` to include
     `"blocking_capable"` accordingly, and fixed the two golden-test synthetic hosts
     (which use `inherit = Design` precisely to *avoid* ancestry contamination, so
     they never had `blocking_capable` declared anywhere in their own chain) by
     giving each an explicit `private = list(blocking_capable = ...)`.
  3. **`define_design_class()` requires `lock_objects = FALSE`, but R6 resolves
     `lock_objects` from the leaf class actually being instantiated, not inherited
     from a parent generator.** `DesignSeqOneByOneKK21`/`DesignSeqOneByOneKK21stepwise`
     (plain `R6::R6Class()`, not on the conversion list themselves) inherit from the
     newly-converted `DesignSeqOneByOneKK14`; once KK14 became `lock_objects = FALSE`,
     constructing a KK21/KK21stepwise instance broke with "cannot add bindings to a
     locked environment" the moment `super$initialize()` (KK14's own constructor) ran,
     even though `lambda` is a field KK14 itself declares. Fixed by adding
     `lock_objects = FALSE` explicitly to both subclasses' own `R6::R6Class()` calls
     (no component composition needed for either -- they don't themselves need
     `BlockingStructure`/`MatchingStructure`, only the matching `lock_objects`
     setting). **Generalizable finding: any class, anywhere in the codebase, that
     inherits (even transitively, even through classes not itself being converted)
     from a `define_design_class()`-built generator must also set
     `lock_objects = FALSE` on itself**, or construction will fail exactly this way.
     No other current subclass of any of the 7 converted classes exists (confirmed by
     grepping `inherit\s*=\s*<each classname>` across `R/`), but this is a standing
     trap for any *future* subclass of a converted class, and should be checked again
     before each subsequent conversion.

  Regression coverage: full `test-design-*`/`test-fixed-design*`/`test-designs.R`/
  `test-observational*`/`test-resampling-draw-contracts.R`/`test-w-encoding.R`/
  `test-group-bootstrap-rcpp.R`/`test-incidence-blocking-family.R`/`test-cluster*`/
  `test-binary-match*`/`test-*matching*`/`test-*kk*` sweep is clean after every step
  except the one already-documented pre-existing, unrelated failure
  (`test-design-inference.R:567`, locked-binding bug in the separate, already-in-progress
  inference hierarchy migration). A wider sweep including unrelated bootstrap/asymptotic-
  inference test files surfaced many more failures, but all trace to that same
  concurrent, already-in-progress inference-side migration (confirmed: none reference
  Design/blocking/matching/cluster code, all originate from
  `inference_all_abstract_asymp_lik_std_mod_cache.R` and sibling bootstrap files this
  session never touched) -- out of scope here, not a regression from this work.

- [ ] TODO-35: **Phase 1, continued: audit and convert the ~20 remaining concrete `DesignFixed`/
  `DesignSeqOneByOne` classes not in the original 9-class list** (e.g.
  `DesignFixedBernoulli`, `DesignFixedAOptimal`, `DesignFixedDOptimal`,
  `DesignFixedFactorial`, `DesignFixedGreedy`, `DesignFixedRerandomization`,
  `DesignFixedCustom`, `DesignCustomSequential`, `DesignSeqOneByOneAtkinson`,
  `DesignSeqOneByOneBernoulli`, `DesignSeqOneByOneEfron`, `DesignSeqOneByOneiBCRD`,
  `DesignSeqOneByOnePocockSimon`, `DesignSeqOneByOneUrn`, plus
  `DesignFixediBCRD`/`DesignFixedMatchingGreedyPairSwitching` skipped above, and
  `DesignSeqOneByOneRandomBlockSize`/`DesignSeqOneByOneSPBR` pending their own
  generalization). **This is a real scope expansion discovered while doing Phase 1,
  not originally planned as part of "Timing-Family Split": every one of these classes
  currently gets `is_blocking_design()`, `set_m()`, `get_block_ids()`,
  `is_matching_design()`, `get_matching_cluster_ids()`, etc. "for free" via inheriting
  `DesignBlocking`/`DesignMatching`, even though most of them never set
  `blocking_capable`/`matching_capable` and the methods are effectively inert no-ops
  for them (`is_blocking_design()` just returns `FALSE`). Once the inherit chain is
  actually cut (next item), any of these classes that DON'T get at least
  `BlockingStructure`/`MatchingStructure` composed loses those methods *entirely* --
  not "returns FALSE", but "the method doesn't exist on the object" -- which will break
  any code (inference or simulation-framework) that calls them universally regardless
  of capability. Audit each remaining class for exactly this exposure before the flip,
  not after.
- [ ] TODO-36: Change `DesignFixed`'s `inherit` from `DesignMatching` to `Design`
  (design_fixed_abstract.R:15).
- [ ] TODO-37: Change `DesignSeqOneByOne`'s `inherit` from `DesignMatching` to `Design`
  (design_seq_one_by_one_abstract.R:14).
- [ ] TODO-38: Delete `DesignBlocking`/`DesignMatching` as generators once no concrete class
  inherits from them (they become component sources only, same end-state as the
  `Inference` plan's "Base Deletion" section for `InferenceRand`/`InferenceNonParamBootstrap`/etc.).
  **Not just a deletion -- needs its own fix first:** `design_component_registry.R`'s
  registrations currently pull *live references* from `DesignBlocking`/`DesignMatching`
  (e.g. `blocking$public_methods[["is_blocking_design"]]`) at populate time; deleting
  these generators outright would break that extraction mechanism. Needs the component
  registry switched to literal copies (or the extraction moved to a one-time snapshot
  taken before deletion) before the generators themselves can actually go.
- [ ] TODO-39: Add a migration gate mirroring `EDI_REQUIRE_SHALLOW_INFERENCE_HIERARCHY`:
  `EDI_REQUIRE_SHALLOW_DESIGN_HIERARCHY`, failing while any concrete `Design` still
  inherits through `DesignBlocking`/`DesignMatching`.

### Class-Identity Dispatch Replacement

Replace every call site from "Evidence of the Problem" item 5 with a capability or
`randomization_family` read. Unlike "Timing-Family Split," this section does not depend
on any concrete `Design` class being rewired onto `define_design_class()` or on the
inherit flip -- every read here goes through `Design$capabilities()`/`supports()`
(already built, "Component Extraction") or the new `Design$randomization_family()`
(added this pass, mirrors `capabilities()`), both of which work correctly today
regardless of migration state:

- [x] TODO-40: `inference_suite.R:107` -- `inherits(des_obj, "DesignBlocking") || inherits(des_obj, "DesignFixedBlocking")`
  -> `des_obj$supports("blocking")`. **This was a real, currently-live bug, not just a
  style cleanup**: because `DesignBlocking` is (pre "Timing-Family Split") a mandatory
  ancestor of literally every current `DesignFixed`/`DesignSeqOneByOne` subclass, the
  first half of the old `||` was `TRUE` for *every* design regardless of actual
  blocking capability, making the `requires_blocking` gate for
  `InferenceIncidCMH`/`InferenceIncidExtendedRobins` a permanent no-op --
  confirmed empirically (`InferenceIncidCMH` was discoverable even for a plain
  `DesignFixedBernoulli`) before the fix, and correctly excluded after. Added a
  permanent regression test (`test-inference-suite-discovery.R`, "InferenceSuite's
  requires_blocking gate actually rejects non-blocking designs").
- [x] TODO-41: `inference_mixin_kk_glmm_shared.R:87`, `inference_mixin_kk_gee_shared.R:277`,
  `inference_mixin_kk_passthrough.R:319`, `inference_count_KK_cond_poisson.R:86,470`,
  `inference_incidence_exact_binomial.R:56,175` (7 call sites total, not 6 -- the
  original survey missed one duplicate site in `inference_count_KK_cond_poisson.R`) --
  each was `if (inherits(des_obj, "DesignFixedBinaryMatch")) { ...ensure_matching_structure_computed() }`.
  **Not replaced with a capability/family read at all** -- removed the guard entirely
  and call `ensure_matching_structure_computed()` unconditionally instead, which is
  simpler and behavior-preserving for a different reason: `DesignMatching`'s base
  implementation of this method is a no-op (`design_matching_abstract.R:54-56`), and
  only `DesignFixedBinaryMatch` overrides it with real (lazy nbpMatching) work, so
  calling it unconditionally on any kk-matching-capable design (already asserted at
  every call site before reaching this line) is a no-op for KK14-family/
  `ObservationalDesignMatching` designs and real work for `DesignFixedBinaryMatch`,
  exactly reproducing today's behavior without needing a new capability at all, and
  automatically correct for any future lazily-computed matching design without a
  spelling to invent. `simulations_framework.R` already used a related pattern
  (`exists("ensure_matching_structure_computed", envir = priv, inherits = FALSE)`) at
  two of its own call sites -- left alone there since it's a distinct branch-selection
  context (see below), not a guard being removed.
- [x] TODO-42: `inference_all_abstract_bayesian_bootstrap.R:530` -- `is(design_obj,
  "DesignFixedBlockedCluster")` -> `design_obj$is_a_cluster_capable()`. Simpler than the
  planned `supports("blocked_cluster")`/`randomization_family()` options:
  `is_a_cluster_capable()` already exists as a real capability-flag public method
  (`design_abstract.R:50`, default `FALSE`, overridden `TRUE` on
  `DesignFixedCluster`/`DesignFixedBlockedCluster`) and is already the established
  idiom used by `inference_all_abstract_jackknife.R`,
  `inference_all_abstract_non_param_boot.R`, and
  `inference_ext_exchangeable_resampling_units.R` for the exact same purpose -- this
  call site was simply the one holdout still using class identity. Within this call
  site's nesting (`if (is_blocking_design) { ... }`), `is_a_cluster_capable() == TRUE`
  is exactly equivalent to "is `DesignFixedBlockedCluster`" today (`DesignFixedCluster`
  is cluster-capable but never blocking-capable, so it never reaches this branch), and
  additionally correct for any future blocked-and-clustered design.
- [x] TODO-43: `inference_all_abstract.R:68` -- `inherits(des_obj, "DesignSeqOneByOneKK14")`
  cached as `private$is_KK` -> `des_obj$randomization_family() %in% c("kk14", "kk21",
  "kk21_stepwise")`. Checked all downstream reads of `private$is_KK` (8 call sites
  across `inference_all_mean_diff.R`, `inference_ordinal_ridit.R`,
  `inference_all_KK_quantile_regr_ivwc_abstract.R`,
  `inference_all_KK_quantile_regr_one_lik_abstract.R`,
  `inference_all_abstract_jackknife.R`, `inference_all_simple_wilcox.R`,
  `inference_all_abstract_non_param_boot.R` (x3),
  `inference_ext_exchangeable_resampling_units.R`): all distinguish "matched_set" (KK
  on-the-fly, has a reservoir of never-matched units) vs. "pair" (fully paired, e.g.
  `DesignFixedBinaryMatch`, no reservoir) resampling semantics -- a randomization-family
  question about the KK on-the-fly family specifically, not a general matching
  capability, so `randomization_family()` (not a new `supports("kk_sequential")`
  capability) is the right primitive. Added `Design$randomization_family()` (mirrors
  `capabilities()`/`supports()`, reads `get_design_class_metadata(class(self)[1L])$randomization_family`)
  since no instance-level accessor existed yet, only the registry-level function.
- [x] TODO-44: `inference_all_abstract_rand.R:451` -- `inherits(private$des_obj,
  "DesignFixedRerandomization")` -> `isTRUE(private$des_obj$randomization_family() == "rerandomization")`.
- [x] TODO-45: `inference_indicidence_exact_fisher.R:124-133` -- two call sites (the survey's
  "89-97" line numbers were stale), `design_supports_exact_fisher()` and
  `get_exact_fisher_tables()`'s branch selection, both hardcoding the same 5 class
  names via `is()`. **Not a single new capability** (deviating from the plan's
  `supports("exact_fisher_eligible")` suggestion, which its own text flagged as "or
  equivalent"): the 5 classes are eligible for two genuinely different reasons --
  `DesignSeqOneByOneiBCRD`/`DesignFixediBCRD` because they have *no* stratification at
  all (single overall 2x2 table), `DesignFixedBlocking`/`DesignSeqOneByOneSPBR`/
  `DesignSeqOneByOneRandomBlockSize` because they *do* have real per-stratum structure
  (Mantel-Haenszel stratified tables) -- so one shared capability flag would blur a
  real distinction the code branches on immediately afterward. Used a direct
  `randomization_family() %in% c(...)` membership check instead (mechanical
  class-name-to-family translation, not a new judgment call): `"complete_randomization"`
  for the iBCRD pair in `design_supports_exact_fisher()`'s eligibility gate (`||
  has_match_structure` unchanged), and `c("blocked", "spbr", "random_block_size")`
  (excluding `"complete_randomization"`, since iBCRD correctly falls through to the
  existing single-table `else` branch) in `get_exact_fisher_tables()`'s branch
  selection.
- [x] TODO-46: `simulations_framework.R` -- confirmed (matching the plan's own hedge) that the
  two `inherits(d, "DesignSeqOneByOne")` checks are legitimate as-is and left
  unconverted: `DesignSeqOneByOne` remains a true, still-existing substitutable parent
  after this plan (unlike `DesignFixedBinaryMatch`/`DesignFixedBlockedCluster`, which
  stood in for a capability, not genuine substitutability), so this is ordinary,
  idiomatic R6 dispatch rather than the class-identity-as-capability-proxy smell the
  rest of this section targets. The two `inherits(d, "DesignFixedBinaryMatch")` /
  `inherits(d, "DesignFixedOptimalBlocks")` block-ID-derivation branch selectors (one
  in the `Nrep_W` caching fast path, one in the validation-only `skip_assignment` fast
  path) were converted to `randomization_family()` checks -- **not simplified to a bare
  existence check** (the more obvious-looking fix, and the one already used elsewhere
  in this same file) because `ensure_matching_structure_computed`/
  `get_or_compute_block_ids` existence alone isn't discriminating: the former is
  present (as a no-op) on every current design via inherited `DesignMatching` ancestry
  (the same hazard already documented for `ClusterStructure`/`BlockingStructure`
  above), which would make the binary-match branch fire for every design and starve
  the other two branches in this particular priority-chain context (existence checks
  stay safe only where they're paired with a real discriminator, as they already were
  here via the now-fixed `inherits()`/family check, or where the checked method is
  leaf-only).

### Dead Flag Cleanup

- [x] TODO-47: **Reconciled 2026-08-16, same stale-prose issue as TODO-8/10/11/19 --
  the underlying deletions were never reverted.** Re-confirmed via fresh grep across
  all of `R/*.R`: zero readers anywhere (not even internal to `design_*.R`, not in
  tests) for all 6 flags -- `is_a_fixed`, `is_a_seq_one_by_one`, `has_covariates`,
  `is_an_observational_design`, `is_a_fixed_custom`, `is_a_custom_sequential`.
- [x] TODO-48: Since re-verification (TODO-47) found zero internal readers to migrate
  onto `timing_family` reads, there was nothing to replace -- `is_a_fixed`/
  `is_a_seq_one_by_one` (and their base-class `FALSE` defaults on `Design`) were
  deleted outright from `design_abstract.R`/`design_fixed_abstract.R`/
  `design_seq_one_by_one_abstract.R`.
- [x] TODO-49: Same outcome as TODO-48 -- zero readers, nothing to replace with
  `randomization_family`/a capability read. `is_an_observational_design` (and its
  `Design`-level `FALSE` default) deleted outright from `design_abstract.R`/
  `design_observational.R`.
- [x] TODO-50: Deleted `is_a_fixed_custom`/`is_a_custom_sequential`/`has_covariates`
  (and their `Design`-level `FALSE`/computed defaults) outright from
  `design_abstract.R`/`design_custom_extensions.R` -- no deprecation shim, matching
  the `Inference` plan's "no legacy aliases" rule this item cites.
- [x] TODO-51: Consolidated the two independent `supports_resampling()` implementations
  into one metadata-backed method on `Design` (`!isTRUE(get_design_class_metadata(class(self)[1L])$abstract)`,
  with a fail-open default for unregistered/third-party subclasses to match both old
  implementations' behavior for that case). **Superseded by a later, more complete fix**
  ("Observational Design Migration" below): this single flag was later found to
  conflate two genuinely different eligibility questions and was split into
  `supports_resampling()` (kept, general check) plus two new, narrower capabilities --
  see that section for the full writeup and the live bug the split fixed.

### Observational Design Migration

- [x] TODO-52: **Split the single `supports_resampling()` capability into two.**
  Re-verified the call-site count fresh per this item's own instruction (it had
  gone stale, as warned): **15 call sites across 9 files**, not "9 across 4" --
  `inference_mixin_kk_gee_shared.R` (1), `inference_all_abstract_bayesian_bootstrap.R`
  (1), `inference_all_abstract_non_param_boot.R` (2), `inference_all_abstract_rand.R`
  (2), `inference_all_abstract_rand_bootstrap.R` (2), `inference_all_abstract_rand_ci.R`
  (4), `inference_all_abstract_rand_bootstrap_ci.R` (1), `inference_ext_m_out_of_n_bootstrap.R`
  (1), `inference_ext_prw_subsampling.R` (1).

  **Deviated from the literal "both FALSE for ObservationalDesign" instruction after
  checking each call site's actual mechanism** (grepped every one of the 15 for
  `draw_ws_raw`/`draw_ws_according_to_design` calls): only 10 of the 15 actually invoke
  the design's randomization mechanism at all. The other 5 --
  `inference_all_abstract_bayesian_bootstrap.R`, `inference_all_abstract_non_param_boot.R`
  (both sites), `inference_ext_m_out_of_n_bootstrap.R`, `inference_ext_prw_subsampling.R`
  -- purely resample already-observed rows/units and never call the design's mechanism at
  all. Setting these 5 to the same "both FALSE" as the mechanism-dependent ones would have
  silently broken already-working, already-documented behavior:
  `ObservationalDesign`'s own class documentation explicitly states "Procedures that
  resample subjects instead of redrawing w (plain nonparametric bootstrap, Bayesian
  bootstrap) are unaffected and remain available, since resampling subjects with their
  observed, fixed assignment does not require a known randomization probability" -- a
  deliberate, pre-existing design decision from this class's original construction, not
  an oversight to silently reverse as a side effect of this split.

  Landed as a **three-way** split instead of two:
  - `Design$supports_resampling()` (kept, not deleted -- the general "is this a real
    concrete class, not a literal abstract base" check already built for "Dead Flag
    Cleanup") gates the 5 non-mechanism-dependent sites. Stays `TRUE` for
    `ObservationalDesign`.
  - `Design$supports_randomization_draw()` (new) gates the 7 sites that draw a fresh
    assignment directly: `inference_all_abstract_rand.R` (2),
    `inference_all_abstract_rand_ci.R` (4), `inference_mixin_kk_gee_shared.R` (1).
  - `Design$supports_resampling_replay()` (new) gates the 3 BRT sites that resample
    *and* redraw: `inference_all_abstract_rand_bootstrap.R` (2),
    `inference_all_abstract_rand_bootstrap_ci.R` (1) -- confirmed via grep that these
    (unlike the other bootstrap-family files) do call `draw_ws_according_to_design()`
    repeatedly, consistent with BRT's actual definition (resample units, then
    re-randomize each resample using the design's own mechanism).

  Both new capabilities default to the same abstract-base check as
  `supports_resampling()` (shared private helper
  `supports_resampling_by_registry_abstract_check()`, `design_abstract.R`), so every
  ordinary concrete design gets all three `TRUE` with zero extra work, matching this
  item's own "no class needs an explicit override just to stay at today's behavior"
  requirement. `ObservationalDesign` overrides only the two new, narrower methods to
  `FALSE`. `Inference$initialize()` now caches all three flags
  (`inference_all_abstract.R:79-88`); `assert_design_supports_resampling()` is
  unchanged (still backs the 5 general sites) and two new sibling asserts
  (`assert_design_supports_randomization_draw()`/`assert_design_supports_resampling_replay()`)
  back the other 10.

  `capabilities()`/`supports()` gained matching entries: `"resampling"`,
  `"randomization_draw"`, `"resampling_replay"`.

  Verified empirically (`test-observational-design-resampling-capabilities.R`, new
  file, 16 passing expectations -- no dedicated `ObservationalDesign` test file existed
  before this): `ObservationalDesign` now correctly rejects
  `compute_rand_two_sided_pval()` and `approximate_rand_bootstrap_distribution_beta_hat_T()`
  with a clear, early, correctly-worded error, while `approximate_bootstrap_distribution_beta_hat_T()`
  and `approximate_bayesian_bootstrap_distribution_beta_hat_T()` both still succeed.
  Also updated `test-design-abstract-hierarchy.R`'s stale expected-error-message
  regex (the plain-`DesignFixed` case now goes through the new, more specific
  `assert_design_supports_randomization_draw()` message) and added coverage there for
  the two new capability methods on the literal abstract base.
- [x] TODO-53: Migrated `ObservationalDesign`'s `draw_ws_raw() { stop(...) }` onto
  metadata: added `supports_randomization_draw()`/`supports_resampling_replay()`
  overrides (both `FALSE`, see TODO-52) as the primary signal callers should check.
  The throwing stub itself is kept, unmodified, as an explicit fallback for any caller
  that reaches `draw_ws_according_to_design()` without checking `supports()` first, so
  behavior doesn't regress for existing code relying on the documented
  tryCatch-and-message pattern (verified still throws the same message,
  `test-observational-design-resampling-capabilities.R`). No caller in this codebase
  currently does reach it via the old catch-the-message pattern (grepped) -- the assert
  layer now rejects earlier and more clearly for all in-tree callers, so this was a
  metadata addition, not a call-site migration.
- [x] TODO-54: Migrate `ObservationalDesignBlocks` (design_observational_blocks.R) onto
  `components = "BlockingStructure"` instead of its own hand-rolled
  `draw_bootstrap_indices()` override. Done as part of "Timing-Family Split" Phase 1
  (concrete-class rewiring) rather than as a standalone item -- same mechanism, same
  golden-test verification (`test-design-blocking-structure-bootstrap-golden.R`,
  identical output confirmed).
- [x] TODO-55: Migrate `ObservationalDesignMatching` (design_observational_matching.R) onto
  `components = "MatchingStructure"` instead of manually setting
  `private$blocking_capable = TRUE; private$matching_capable = TRUE`. Also done as part
  of "Timing-Family Split" Phase 1. The docstring's "why not just extend
  `ObservationalDesignBlocks`" explanation was left as-is rather than shortened --
  component composition doesn't actually remove that footgun's *underlying* cause
  (`ObservationalDesignBlocks` still resolves `draw_bootstrap_indices` from
  `BlockingStructure` alone, not `MatchingStructure`, so subclassing it would still
  silently run the wrong bootstrap), so the warning remains accurate and worth keeping;
  revisit only if a future change makes the two truly interchangeable.

### Seed-Reproducibility Metadata

Audit note (2026-08-14): the A-/D-optimal kernel fix below has effectively
already landed via `sexp_removal_rcppeigen_conversion_spec.md`'s TODO-12 RNG
migration — `optimal_design_search.cpp` now seeds `edi_rng::RRng` from
`R::unif_rand()` (both entry points; no `std::random_device` left, and the file
has no OpenMP region). But `design_class_registry.R:77-82` still hardcodes
`EDI_DESIGN_NOT_SEED_REPRODUCIBLE_CLASS_NAMES = c("DesignFixedAOptimal",
"DesignFixedDOptimal")` with a comment citing the now-removed
`std::random_device` — the metadata and its rationale are stale. The remaining
work on the third item is therefore: verify reproducibility empirically (same
`seed`, identical draws, twice), then flip the registry metadata and delete the
stale comment — not a kernel rewrite.

- [ ] TODO-56: Add `seed_reproducible_draw` metadata to every concrete design's registry entry.
- [ ] TODO-57: Confirm and document `DesignFixedAOptimal`/`DesignFixedDOptimal`'s
  `std::random_device` usage (non-reproducible) vs. `DesignFixedGreedy`'s per-thread
  RNGs seeded from R's RNG state before the OpenMP region (reproducible) -- these were
  found to differ silently during this survey.
- [ ] TODO-58: Fix `DesignFixedAOptimal`/`DesignFixedDOptimal` to be seed-reproducible, using the
  same per-thread-seeding pattern `DesignFixedGreedy` already uses (per-thread RNGs
  seeded from R's RNG state before the OpenMP region, instead of `std::random_device`).
  This is a real, currently-silent correctness/usability gap, not just an architecture
  nicety -- treat it as a required fix, not an optional cleanup item. Until it lands,
  `seed_reproducible_draw = FALSE` must be set for both classes so the gap is at least
  queryable instead of silent.
- [ ] TODO-59: Add a regression test that calls every concrete design twice with the same `seed`
  and asserts either identical draws (if `seed_reproducible_draw = TRUE`) or explicitly
  skips the reproducibility assertion (if `FALSE`) -- so a future change that
  accidentally breaks reproducibility for a class that currently has it is caught.

### Regression Gates

These four are ongoing practices this plan's implementation has followed throughout
(not one-time deliverables), re-audited here rather than left as perpetually-open
checkboxes:

- [x] TODO-60: Before extracting each component, add focused golden tests for every currently
  blocking/matching/cluster-capable concrete design's assignment draws and bootstrap
  index distributions. Followed throughout: `test-design-blocking-structure-bootstrap-golden.R`,
  `test-design-cluster-structure-golden.R`, `test-design-component-extraction-golden.R`,
  plus the reference-identity checks in `test-design-component-registry.R` for
  `BlockingStructure`/`MatchingStructure`'s extracted-not-reimplemented methods.
- [x] TODO-61: Add a test enumerating all `Design*` generators and asserting each has exactly one
  registry entry and a valid `timing_family`/`randomization_family`. Already existed
  from the "Metadata Registry" phase: `test-design-class-registry.R`'s "design class
  registry has one canonical metadata entry per generator" test does exactly this
  (`canonical_design_generators()` walks the live namespace, cross-checked 1:1 against
  the registry, with per-class assertions on every metadata field including
  `timing_family`/`randomization_family` type and the closed-enum tests immediately
  following it).
- [ ] TODO-62: Run `Rscript fast_roxygenize.R` after exported API, class name, inheritance, or
  roxygen changes (note: as of this survey, `fast_roxygenize.R` fails package-wide on an
  unrelated pre-existing bug -- `R6 class <InferenceAllKKWilcoxIVWC> lacks source
  references` -- confirmed present on unmodified `main`; man pages were hand-edited to
  work around it for `ObservationalDesign`/`ObservationalDesignBlocks`/
  `ObservationalDesignMatching`. Fix that blocker, or keep hand-editing man pages, before
  this plan's migrations multiply the number of files needing hand-edited docs). Still
  blocked -- not attempted this pass, and not safe to attempt while a concurrent
  restructuring is touching the same design class surface (see below).
- [x] TODO-63: Keep package load and targeted tests
  (`test-design-abstract-hierarchy.R`, `test-w-encoding.R`,
  `test-resampling-draw-contracts.R`, `test-simulation-framework*.R`, and every
  `test-*-permutation-*`/`test-*-bootstrap-*` file exercising a migrated design) passing
  after each migrated family. Followed for every change this pass, each verified with a
  scoped regression run before moving to the next item; failures were triaged rather
  than assumed innocent, and several confirmed pre-existing/unrelated (locked-binding
  bugs in the separate, already-in-progress inference hierarchy migration; mirai/sandbox
  permission errors; a stale `NAMESPACE`) are documented at their first occurrence above
  rather than repeated at every subsequent item.

**Note (this pass):** work stopped mid-way through "Timing-Family Split"/"Seed-
Reproducibility Metadata" because another session began actively restructuring the same
design-class surface concurrently (merging `DesignFixedAOptimal`/`DesignFixedDOptimal`
into a new `DesignFixedGreedyDOptimal`, touching `design_class_registry.R` and several
files this pass had already edited). Per explicit user direction, remaining work
continued but avoided every file that session was touching -- so the Phase 2 inherit
flip, the ~20-class audit it depends on, and all of "Seed-Reproducibility Metadata" are
untouched this pass, not because they're unimportant but to avoid corrupting concurrent,
overlapping work. Re-survey both this file's remaining `[ ]` items and the concurrent
session's actual landed changes before resuming either.

## Definition of Done

The hierarchy is complete when:

- `DesignFixed` and `DesignSeqOneByOne` inherit `Design` directly; `DesignBlocking`/
  `DesignMatching` no longer exist as mandatory ancestry for any concrete class.
- Blocking, matching, clustering, allocation-matrix validation, and batch-pregeneration
  are components with enforced contracts, composed only by the designs that actually use
  them.
- Every design class has valid `timing_family`/`randomization_family`/
  `seed_reproducible_draw` metadata.
- No `is()`/`inherits()` call outside the hierarchy declarations themselves reads a
  `Design*` class name to make a behavioral decision; every current site enumerated in
  "Evidence of the Problem" item 5 is converted.
- No capability is discovered by generator-shape sniffing (`dc$public_methods$...`).
- No public method exists only to `stop()` in place of declaring the capability absent
  as metadata.
- No `.__enclos_env__$private` reach-through of a `Design` instance from outside
  `design_*.R`.
- `private$m` is only ever written through `set_m()`, and writing it always keeps
  `is_blocking_design()` in sync.
- `validate_allocation_matrix` exists once, not four times.
- Seed-reproducibility is documented and queryable for every concrete design, not silent.
- `ObservationalDesign`/`ObservationalDesignBlocks`/`ObservationalDesignMatching` (and
  every other concrete design) are migrated onto the new component/metadata model, with
  no behavioral regression versus their pre-migration golden tests.
