# Conditional vs. Marginal Estimand Switch (`set_estimand()`)

> **Depends on:** its own TODO-1 decision, **decided (2026-08-18, user
> decision): yes, pursue `set_estimand()`.** Originally gated jointly with
> `expanded_estimate_report.md → TODO-1` (the two are orthogonal axes over
> the same fitted object, and deciding them separately risks one enum
> absorbing values that belong on the other) — that plan's TODO-1 remains
> open and was moved to v1.1.0 (see below); whenever it is decided, check
> which `estimand` values this plan's TODO-3 already landed on.
>
> **Release-scoped (amended 2026-08-18, user decision):** pulled forward
> into v1.0.0 from the v1.1.0 "everything else" bucket — see
> `release_v1_0_0.md`'s item 14. `expanded_estimate_report.md` was
> initially pulled forward alongside it, then moved back to v1.1.0 the
> same day: nothing in v1.0.0 scope needs `estimate_type`. Motivation for
> this plan's own move: `inference_suite_inspect.md`'s Combined Evidence
> Metric feature defaults its per-class weighting to grouping by
> `estimand`, so that default needs a real, package-wide `estimand`
> concept behind it at 1.0.0. (Global ordering: see `_master.md`.)

Written 2026-08-15, from a design discussion of what the mixture-model
inference classes actually estimate versus what users expect them to estimate.

## Context — what the mixture classes report today

Two inference families model the response as a finite mixture and report a
**component-conditional** treatment coefficient:

- **`InferencePropZeroOneInflatedBetaRegr`**
  (`R/inference_proportion_zero_one_inflated_beta.R`): the response is a
  three-component mixture — point masses at 0 and 1 (multinomial-logit
  submodels `gamma_0`, `gamma_1` over `X_zero_one`, interior category as
  softmax baseline) plus a mean-precision Beta on the interior, with
  `logit(mu_i) = x_i' beta`. The C++ kernel
  (`fast_zero_one_inflated_beta_cpp`) fits the joint vector
  `[beta, log_phi, gamma_0, gamma_1]` by direct ML, and the class reports
  `beta_hat_T = b[j_treat]` — the treatment entry of `beta` only. Estimand:
  the treatment effect on the log-odds of the mean of `Y`, **conditional on
  `0 < Y < 1`**. The treatment coefficients inside `gamma_0`/`gamma_1` are
  estimated but treated as nuisance (cached as
  `zero_coefficients`/`one_coefficients`, never reported).
- **`InferenceCountZeroAugmentedPoissonAbstract`** and its zero-inflated and
  hurdle concretes (`R/inference_count_zero_augmented_poisson_abstract.R`):
  the reported effect is the treatment coefficient from the **conditional
  count component, on the log-rate scale**; the zero/hurdle auxiliary
  component is nuisance.

This matches every major implementation (`pscl::zeroinfl`/`hurdle`,
`glmmTMB`, `VGAM`, `gamlss`, `brms`, Stata `zip`/`zinb`/`churdle`): they all
print component-specific coefficient tables and none synthesizes a composite.
So the current definition is the standard *software output*. The problem is
that it is not the standard *expectation* of what a "treatment effect" means.

## Why the conditional coefficient misleads

1. **Practitioners read the conditional-component `beta_T` as "the effect of
   treatment on the outcome."** It isn't — it is the effect within the latent
   at-risk class (ZIP) or among observed positives/interior observations
   (hurdle/ZOIB). The two-part-model literature in health economics (Duan et
   al.; Mullahy 1998) made exactly this point central: the quantity of
   substantive interest is the effect on the overall mean
   `E[Y] = P(Y > 0) * E[Y | Y > 0]`, and the parts must be recombined. This
   is why Stata users reflexively run `margins` after `zip`/`churdle` and why
   `emmeans`/`marginaleffects` exist for `glmmTMB`.
2. **The conditional estimand is not a clean causal contrast.** For hurdle
   and ZOIB models, "subjects with `0 < Y < 1`" is an outcome-defined,
   post-treatment subgroup — conditioning on it is conditioning on a
   collider, so `beta_T` compares potentially different subpopulations across
   arms. For ZIP it is worse: class membership is latent, can itself depend
   on treatment, and the structural-vs-sampling-zero decomposition is
   identified only through the parametric assumptions. `beta_T` can be near
   zero while treatment strongly moves mass into or out of the point masses.
3. **The estimand framework points the same way.** ICH E9(R1) and the FDA
   covariate-adjustment guidance push randomized-trial analyses toward
   marginal, model-robust estimands; g-computation/standardization is the
   recommended recipe. A latent-class-conditional coefficient does not
   correspond to a well-defined population-level contrast.
4. **The axis is wider than the mixture classes.** Because of
   non-collapsibility, conditional ≠ marginal for *any* nonlinear link —
   plain logistic and Poisson included. The mixture families are just where
   the gap is most misleading.

## The marginal (composite) estimand

The model-implied mean recombines all components. For ZOIB:

```
E[Y | x, w] = pi_1(x, w) * 1 + (1 - pi_0(x, w) - pi_1(x, w)) * inv_logit(x' beta + beta_T * w)
```

(the zero mass contributes nothing). The marginal mean difference is the
g-computation average

```
tau_hat = (1/n) * sum_i [ E_hat(Y | x_i, w = 1) - E_hat(Y | x_i, w = 0) ]
```

plugging every subject in at `w = 1` and `w = 0`. For the count family the
same construction uses `E[Y | x, w] = (1 - pi_0(x, w)) * exp(x' beta +
beta_T * w)` (ZIP) or the zero-truncated-Poisson mean version (hurdle); the
field-default scale there is a marginal **rate ratio** rather than a
difference.

Standard errors come from the delta method against the joint vcov of
`[beta, log_phi, gamma_0, gamma_1]` — which `fast_zero_one_inflated_beta_cpp`
already returns — or from the existing bootstrap machinery, which needs no
new mathematics.

**Crucially, this is a pure post-fit transform of the one cached fit**: same
`private$cached_mod`, different functional of its parameters. No refit. By
`expanded_estimate_report.md`'s own dividing line (the constraint that makes
`testing_type`-style mutable switches safe), it qualifies for the stateful
switch architecture — unlike Firth, which changes the estimating equation.

## Why this is NOT a value of `estimate_type`

`expanded_estimate_report.md`'s proposed `estimate_type` values — `"raw"`,
`"param_bootstrap"`, `"cox_snell"`, `"jackknife_bc"` — are different
**estimators of the same estimand** (bias-correction variants of the same
target). Conditional vs. marginal is a different **estimand**: a different
target quantity on a different scale. If both live in one enum, the
meaningful combinations become inexpressible — "parametric-bootstrap
bias-corrected *marginal* estimate" is a coherent request a user will make,
but a single switch cannot say it. The two axes must cross:

| | `estimate_type = "raw"` | `estimate_type = "param_bootstrap"` | ... |
|---|---|---|---|
| `estimand = "conditional"` | today's `beta_hat_T` | bias-corrected `beta_hat_T` | ... |
| `estimand = "marginal_mean_diff"` | g-computation `tau_hat` | bias-corrected `tau_hat` | ... |

Every cell is well-defined and computable with existing machinery.

## Proposed API

Mirror the `testing_type` architecture a second time, on its own axis:

- `set_estimand()` / `get_estimand()` / `get_supported_estimands()`, with
  default `"conditional"` — fully backward compatible; every existing class
  supports only `"conditional"` until it registers more.
- Values: `"conditional"`, `"marginal_mean_diff"`, and (counts)
  `"marginal_ratio"`. No bare `"marginal"`: the scale is part of the estimand
  and making it explicit in the value avoids a second `scale` argument and
  makes cache keys trivial.
- A validated setter erroring immediately on unsupported values, a per-class
  supported-values query, and an estimand-aware cache key — the same three
  properties `expanded_estimate_report.md` calls out for `testing_type`
  (generalizing `likelihood_test_delta_key()`).
- Implementation as a registered `InferenceComponent` composed through
  `define_inference_class()` with a capability read
  (`obj$supports("marginal_estimand")`), per the post-`fix_inference_hierarchy`
  architecture — no `supports_*` hooks, no mixin splicing. Each family
  contributes one small method — the model-implied mean function
  `E[Y | x, w; params]` — while the g-computation average and the
  delta-method gradient live once in the shared component.
- **`compute_estimate()` should honor the estimand.** This deliberately
  diverges from `expanded_estimate_report.md`'s lean for `estimate_type`
  (where the report prefers not to mutate `compute_estimate()`'s meaning).
  Rationale: a bias correction is a refinement of the same number, so a
  separately named method is honest; the estimand is *which question is being
  asked*, and having `compute_estimate()` ignore it while a
  `compute_marginal_estimate()` sits off to the side recreates precisely the
  "users think the conditional `beta_T` is the treatment effect" trap this
  plan exists to close. The estimand-aware cache keys make the state mutation
  safe. (Recorded as open question 1 below until decided.)

## Interactions with existing machinery

1. **Supported testing types become estimand-dependent.** Under
   `"conditional"` everything works as today (Wald, score, gradient, LR,
   Bartlett variants). Under a marginal estimand there is no single
   coefficient to profile: `fixed_idx`-style constrained refits do not apply,
   so the supported set shrinks to Wald-via-delta-method plus the bootstrap
   paths. `get_supported_testing_types()` must consult the estimand, and
   incompatible combinations (`set_testing_type("lik_ratio")` +
   `set_estimand("marginal_mean_diff")`) must error loudly in whichever order
   the two setters are called.
2. **Randomization inference is free.** The permutation machinery needs only
   a test statistic per re-randomization;
   `compute_treatment_estimate_during_randomization_inference()` dispatches
   on the estimand and everything downstream is untouched.
3. **Bootstrap paths are free.** The Bayesian-bootstrap and nonparametric
   paths already refit under weights; the marginal functional simply
   evaluates on the weighted fit inside
   `compute_estimate_with_bootstrap_weights()`.
4. **CI/p-value inversion** under a marginal estimand reduces to
   delta-method Wald or bootstrap; the likelihood-test spec
   (`get_likelihood_test_spec()`) remains conditional-only.

## Scope

- **Phase 1:** the mixture families — `InferencePropZeroOneInflatedBetaRegr`
  and the zero-augmented Poisson concretes (ZIP and hurdle), where the
  conditional/marginal gap is largest and most misleading. Proportions get
  `"marginal_mean_diff"`; counts get `"marginal_ratio"` (field default) and
  `"marginal_mean_diff"`.
- **Later wave:** any nonlinear-link single-component GLM class (logistic,
  Poisson, beta regression, ...) — non-collapsibility makes the axis
  meaningful there too, and adoption is a one-line mean-function
  contribution per family.
- Several response-type reports (`nominal_response_type_report.md`,
  `compositional_response_type_report.md`,
  `longitudinal_repeated_measures_response_type_report.md`) carry their own
  open "estimand question" TODOs; once `set_estimand()` exists it is the
  natural home for their answers rather than more per-family ad hoc choices.
- Independent of the yes/no decision: the roxygen headers of both mixture
  families should state the conditioning more bluntly than "on the logit
  scale" / "conditional count component" — e.g. "conditional on the response
  falling strictly inside (0, 1); this is not the effect on E[Y]".

## Compatibility with `fix_inference_hierarchy.md`

Audited 2026-08-15: no fundamental conflict — this plan already targets the
shallow-hierarchy component architecture — but three of its rules constrain
the implementation and must be honored explicitly:

1. **`compute_estimate()` dispatch needs a declared mechanism.**
   `compute_estimate()` is the concrete estimator's class-owned method, and
   the hierarchy contract (rules 8/16: no implicit method or state
   collisions) forbids a component from silently changing a host method's
   behavior. If open question 1 resolves toward dispatch, it must be done
   either (a) by making the estimand field root-owned state consulted by the
   root `Inference` estimate contract, or (b) via an explicit
   `allowed_host_overrides` declaration on the `MarginalEstimand` component
   wrapping the host's `compute_estimate()`. Pick one at TODO-3 time; do not
   wrap implicitly.
2. **Capabilities stay immutable; only runtime validity is estimand-aware.**
   `obj$supports()` and `capabilities()` read immutable metadata by
   architectural rule. The estimand-dependent gating in TODO-6 therefore
   lives in `get_supported_testing_types()` and the setters' validation — an
   instance-level validity query — never in the capability set itself. A
   class's `likelihood_ratio` capability does not disappear when the object
   is switched to a marginal estimand; the testing type merely becomes
   currently invalid on that object.
3. **`set_estimand()` exists only where the capability does.** "Public
   method exists ⇔ capability exists" plus "no public throwing stubs" means
   there is no package-wide `set_estimand()` that rejects everything except
   `"conditional"`. Classes that do not compose the `MarginalEstimand`
   component have no setter and are implicitly conditional; "default
   `"conditional"`" in this plan means the component's own initial state,
   not a universal method.

The component's interaction with `Wald`/`LikelihoodTests` supported-types
logic is a cross-component dependency and must be declared through the
component contract's `dependencies`/`conflicts` fields, not reached into ad
hoc.

## Open questions

1. **Does `compute_estimate()` dispatch on the estimand, or does a new
   `compute_marginal_estimate()` exist alongside?** This plan leans strongly
   toward dispatch (see Proposed API), the opposite of
   `expanded_estimate_report.md`'s lean for `estimate_type` — the asymmetry
   is intentional but should be confirmed as one joint decision.
2. **Degrees of freedom for the delta-method Wald** under a marginal
   estimand: inherit the family's existing df convention or use `Inf`?
3. **Which scales for proportions?** `"marginal_mean_diff"` is the
   uncontroversial primary; is a marginal risk/odds ratio worth a value, or
   noise?
4. **Naming:** `estimand` vs. `estimand_type`. This plan uses `estimand`
   (it is the standard term of art and cannot be confused with
   `estimate_type`), but the final name should be fixed jointly with the
   `estimate_type` decision.

## Implementation TODOs

**Recommended execution order across both estimand plans (added
2026-08-18, verified against `fix_inference_hierarchy.md`'s current
migration status; updated 2026-08-18 — the two plans' TODO-1s no longer
have to land together, see the release-line note in the header above):**

1. **[x] DONE** `marginal_estimand_report.md → TODO-2` (roxygen) —
   ungated, ran independent of TODO-1.
2. **[x] DONE (this plan's half):** `marginal_estimand_report.md →
   TODO-1` decided **yes** (2026-08-18). `expanded_estimate_report.md →
   TODO-1` remains open, moved to v1.1.0 — not required to proceed with
   the steps below.
3. `marginal_estimand_report.md → TODO-8` (cheap scope/mechanism
   decision, ungated). (`expanded_estimate_report.md → TODO-3, TODO-4,
   TODO-5` are the analogous steps for that plan, now sequenced in its
   own v1.1.0 execution order instead.)
4. `marginal_estimand_report.md → TODO-3` (implement the `set_estimand()`
   switch as an `InferenceComponent` — architecture only, no concrete
   class).
5. `marginal_estimand_report.md → TODO-6` (testing-type awareness — the
   `LikelihoodTests` component is real shared machinery, so this is
   genuine standalone architecture) **[x] done**, `→ TODO-8` (open
   question 1, resolved during TODO-3) **[x] done**. **Correction
   (2026-08-18):** TODO-7 (randomization/bootstrap dispatch) turned out
   to have no independent architecture to build — grepping the codebase
   found 50+ per-class definitions of the relevant methods, owned by no
   shared component, so it is not a standalone step; it is a consequence
   of TODO-4/5/9 (see TODO-7's own entry below) and moves to step 6.
6. **Wait for `fix_inference_hierarchy.md`'s "Full-Likelihood Estimators"
   remainder to close (`_master.md` § 1D, 2 open items), then:**
   `marginal_estimand_report.md → TODO-4` (ZOIB), `→ TODO-5` (ZIP/hurdle),
   `→ TODO-9` (logistic/Poisson/beta-regression) — verified 2026-08-18 by
   grepping every target class's `inherit =` line: all still point at
   legacy deep-hierarchy bases (`InferenceAsympLikStdModCache`/
   `InferenceCountLikelihood`/`InferenceCountZeroAugmentedPoissonAbstract`),
   none migrated yet. Building marginal-mean wiring into these now means
   redoing it once Phase 1D restructures them. `→ TODO-7` rides along
   with these three — it has no separate implementation, only its own
   verification (a randomization/bootstrap cross-check in each family's
   golden test).

- [x] TODO-1: **Decision: yes, pursue `set_estimand()` (2026-08-18, user
  decision).** Originally to be decided jointly with
  `expanded_estimate_report.md → TODO-1` (`estimate_type` = estimator
  corrections, `estimand` = target quantity, so the two enums don't
  collide) — that plan's TODO-1 was moved to v1.1.0 and remains open
  independently; when it is eventually decided, check the `estimand`
  values TODO-3 below lands on. TODO-3/6/7/8 below are now unblocked;
  TODO-4/5/9 remain gated on `fix_inference_hierarchy.md`'s
  Full-Likelihood Estimators remainder (see "Recommended execution
  order" above).
- [x] TODO-2: Sharpened the roxygen headers of
  `inference_proportion_zero_one_inflated_beta.R` and
  `inference_count_zero_augmented_poisson_abstract.R` to state the
  component-conditioning bluntly (not the effect on `E[Y]`), plus a scope
  correction found while doing it: `inference_count_zero_augmented_
  poisson_abstract.R` defines `InferenceCountZeroAugmentedPoissonAbstract`
  as `@keywords internal @noRd` — it generates no Rd page, so sharpening
  only that file's header would have been invisible to any actual user of
  `?InferenceCountZeroInflatedPoisson` etc. The caveat was therefore also
  added to all four concrete exported subclasses' own doc blocks
  (`InferenceCountZeroInflatedPoisson`/`NegBin` in
  `inference_count_zero_inflated.R`, `InferenceCountHurdlePoisson`/`NegBin`
  in `inference_count_hurdle.R`), each phrased for its own mechanism
  (excess-zero-inflation vs. hurdle-crossing). Verified: all four touched
  files still `parse()` cleanly, `roxygen2::parse_file()` (static, doesn't
  load the package) confirms one well-formed block per class (5 total
  across the 4 files), and the package still loads via
  `pkgload::load_all(compile = FALSE)`. Not gated on anything — ran
  independent of TODO-1's decision, per the "Recommended execution order"
  above.
- [x] TODO-3: Implemented. `InferenceMarginalEstimand`
  (`inference_all_abstract_marginal_estimand.R`, new file, added to
  `DESCRIPTION`'s `Collate:` right after `inference_all_abstract_asymp_lik.R`)
  is a standalone scaffold R6 class providing `set_estimand()`/
  `get_estimand()`/`get_supported_estimands()` (mirroring `set_testing_type`/
  `get_testing_type`/`get_supported_testing_types` in
  `inference_all_abstract_asymp_lik.R` exactly, including a private
  `normalize_estimand()` for case-insensitive alias handling and a private
  `get_supported_estimands_impl()` default returning just `"conditional"`
  that concrete host classes are expected to override — same pattern
  already used for `get_supported_testing_types_impl()`), plus a private
  `marginal_estimand_cache_key()` generalizing `likelihood_test_delta_key()`.
  Registered as `MarginalEstimand` in `EDI_COMPONENT_SPECS`
  (`contracts_mixins.R`), `owns_state = "estimand"`,
  `provides_capabilities = "marginal_estimand"`,
  `allowed_likelihood_tiers = c("partial", "full")`, no `dependencies`.

  **The three `fix_inference_hierarchy.md` compatibility constraints,
  resolved:**
  1. *`compute_estimate()` dispatch mechanism* (open question 1): resolved
     to **neither (a) nor (b) as literally described in the plan text** —
     `compute_estimate()` stays entirely class-owned and this component
     never overrides or wraps it, so no `allowed_host_overrides`
     declaration is needed at all. The component owns only the `estimand`
     state and (once TODO-4/5/9 add it) a shared g-computation/delta-method
     helper; each host's own `compute_estimate()` body explicitly checks
     `self$get_estimand()` and calls into that helper when non-conditional
     — nothing implicit, satisfying rules 8/16 by construction. This
     reconciles the plan's stated goal ("the g-computation average and the
     delta-method gradient live once in the shared component") with
     keeping `compute_estimate()` un-overridden.
  2. *Capabilities stay immutable*: satisfied by construction — the
     component's `provides_capabilities` is fixed at registration; nothing
     about `set_estimand()` touches `capabilities()`/`supports()`.
  3. *Setter exists only where the capability does*: satisfied — a class
     that does not compose `MarginalEstimand` has no `set_estimand()` at
     all (ordinary component-driven method presence), and is implicitly
     `"conditional"` by construction, not via a package-level stub.

  **Verified** (via `pkgload::load_all(compile = FALSE)`, no full
  rebuild): the component registers correctly
  (`EDI:::get_inference_component("MarginalEstimand")`); **zero production
  classes currently compose it**, confirming this landed as pure
  architecture with no concrete-class wiring; a bare test-double host
  correctly defaults to `"conditional"`, rejects
  `set_estimand("marginal_mean_diff")` with a clear supported-values
  error, rejects an unrecognized spelling, and correctly gains
  `"marginal_mean_diff"` support (while still rejecting
  `"marginal_ratio"`) once its `get_supported_estimands_impl()` is
  overridden — exactly the override contract TODO-4/5/9 will later use on
  the real ZOIB/ZIP/hurdle classes. Also ran the full suite under
  `EDI_VALIDATE_INFERENCE_CONTRACTS=true` (the expensive, opt-in
  parser-backed body-reference/collision validation normally skipped at
  runtime for performance) — the new component's
  `complete_component_reference_contract()` pass came back with empty
  `forbidden_refs`, i.e. every `self$`/`private$` reference in its methods
  classified cleanly with no undeclared reference. That strict run also
  caught a real, necessary follow-up: `test-mixin-contracts.R`'s
  `canonical_component_names()` (a hardcoded registry-completeness guard
  list, separate from `fix_inference_hierarchy.md`) didn't yet include
  `"MarginalEstimand"` — fixed by adding it. Two *other* failures surfaced
  by that same strict run (`RandomizationTest`'s
  `optional_private_methods` count) are confirmed pre-existing and
  unrelated (verified via `git diff` on `contracts_mixins.R`: nothing in
  this change touches `RandomizationTest` at all) — left alone as another
  session's in-progress Phase 1D work, per this session's standing policy
  of not touching other people's in-flight changes. Full existing test
  suite (`test-inference-suite-discovery.R`, `test-inference-suite-run-all-
  inference.R`, `test-inference-class-registry.R`, `test-mixin-contracts.R`
  — together exercising the full component/registry invariant suite)
  passes cleanly under normal (non-strict) conditions with the new
  component registered. **Confirmed not gated on Phase 1D**,
  per this file's own "Recommended execution order" note above.
- [x] TODO-4: **Done (2026-08-23).** Re-verified live before starting:
  `InferencePropZeroOneInflatedBetaRegr` is `define_inference_class(inherit
  = Inference, ...)` with zero `algorithmic_compatibility_ancestors` in the
  live manifest — `fix_inference_hierarchy.md` closed 2026-08-23, this
  class's own migration landed separately before that.

  **Implementation.** Added `"MarginalEstimand"` to the class's
  `components =`. Overrode private `get_supported_estimands_impl()` to
  return `c("conditional", "marginal_mean_diff")`. The model-implied mean
  function (`private$zoib_mean_from_coefs()`) reproduces exactly the
  normalized-mixture-probability construction the class's own
  `simulate_under_lik_null()` already uses to draw from this model (raw
  `p0`/`p1` renormalized against `pmax(1 - p0 - p1, 0)` before combining —
  not the naive `p0 + p1 + p_mid` sum, which need not equal 1 with this
  model's parameterization): `E[Y|x,w] = p1(x,w)*1 + p_mid(x,w)*mu(x,w)`.
  `private$zoib_marginal_mean_diff_from_coefs()` does the g-computation
  average (every subject's design row set to `w=1` then `w=0`, treatment
  column fixed at index 2 per `build_component_matrix()`'s convention,
  difference of means). `private$zoib_marginal_mean_diff_functional()`
  re-expresses the same quantity as a function of the full stacked
  parameter vector `theta = [b_beta, log_phi, gamma_0, gamma_1]` — the
  exact layout `fast_zero_one_inflated_beta_cpp()`'s `params`/`vcov`
  already use.

  **Gradient: numerical, not analytic (documented decision).** Given the
  three-submodel mixture with per-observation renormalization, a
  hand-derived analytic gradient was judged a realistic source of a silent
  sign/index error under implementation time pressure; a new generic
  helper (`R/helper_marginal_estimand.R`:
  `numerical_gradient_central()`/`marginal_estimand_delta_se()`, added to
  `DESCRIPTION`'s `Collate:` after `helper_gcomp.R`) computes a
  central-difference gradient instead and combines it with the joint vcov
  for the delta-method SE. **Verified**: recomputing the SE by hand outside
  the class at two different step sizes (`eps = 1e-4` vs. `1e-6`) on a real
  fitted model gave a relative difference of `1.5e-10` — the gradient is
  numerically stable, not step-size-sensitive — and matched the class's own
  cached SE to `< 1e-8` in both the ad hoc script and the new test file's
  assertion.

  **`generate_mod()` change**: the full joint `vcov` and design matrix `X`
  returned by `fast_zero_one_inflated_beta_cpp()` were already being
  computed (that C++ call's `estimate_only` was never set, defaulting
  `FALSE`) but previously discarded by `generate_mod()`'s returned list —
  added as two new fields (`vcov`, `X`), purely additive, no change to the
  conditional path.

  **Real bug found and fixed while wiring this in (not anticipated by the
  plan text): `compute_asymp_confidence_interval()`/
  `compute_asymp_two_sided_pval()` are NOT class-owned for this class** —
  they were inherited from the composed `StandardModelCache` component and
  called `private$shared()` directly, never `self$compute_estimate()`. TODO-3's
  design (`compute_estimate()` is the sole class-owned dispatch point) is
  correct for `compute_estimate()` itself, but doesn't reach these two
  methods for classes that don't already override them. Fixed by overriding
  both in this class (added to `overrides$public`, which already listed
  both names anticipating this) with the identical `StandardModelCache`
  switch-on-`testing_type` body, but calling `self$compute_estimate(estimate_only
  = FALSE)` first instead of `private$shared()` directly — under a marginal
  estimand `testing_type` is always `"wald"` (enforced by `set_estimand()`),
  so the non-wald switch branches are unreachable there by construction and
  the conditional-estimand dispatch (score/gradient/lik_ratio/Bartlett) is
  preserved unchanged.

  **Second real bug found and fixed: a cache-invalidation bug on
  estimand toggling.** `compute_estimate()`'s original marginal branch only
  overwrote `cached_values$beta_hat_T`/`s_beta_hat_T` when computing the
  marginal branch itself; `private$shared()`'s own short-circuit guard
  (checks those same two fields) meant that switching back to
  `"conditional"` after having computed a marginal estimate returned the
  *stale marginal* numbers, since `shared()` skipped re-fitting (correctly
  — the underlying ML fit doesn't change with estimand) but nothing
  restored the conditional values. Fixed by making the conditional branch
  of `compute_estimate()` unconditionally re-derive `beta_hat_T`/
  `s_beta_hat_T`/`df` from the estimand-invariant `private$cached_mod` on
  every call (free — no refit, `cached_mod` already holds everything
  needed) rather than trusting `cached_values` to already hold the right
  numbers.

  **`compute_estimate_with_bootstrap_weights()`**: this method does its own
  independent reweighted fit (not calling `compute_estimate()`), already
  producing weighted `b_zero`/`b_one`/the beta submodel's `coef_vec` for its
  existing (conditional) point estimate — no new fitting needed for the
  marginal branch, just a call to the same mean-difference function using
  those already-available weighted coefficients when
  `get_estimand() == "marginal_mean_diff"`. Point estimate only, no SE
  (bootstrap/randomization never read `s_beta_hat_T` from a weighted-fit
  call).

  **Verification performed** (`pkgload::load_all(".", compile = FALSE)`
  throughout, no compile step):
  1. `roxygen2::parse_file()` and base `parse()` clean on both edited files.
  2. Real simulated dataset (n=300, treatment-dependent zero/one-inflation
     and interior mean): conditional estimate/CI/pval unchanged whether
     `compute_asymp_confidence_interval()` is called directly (no prior
     `compute_estimate()` call) or after — confirms the `private$shared()`
     bypass fix didn't regress the conditional path, and is itself
     call-order-independent.
  3. Marginal-estimand call-order independence: `compute_estimate()` then
     `compute_asymp_confidence_interval()`, vs. the reverse order, produce
     identical point estimates and CIs.
  4. Toggle regression test: conditional → marginal → conditional returns
     to the exact original conditional point estimate (`tolerance = 1e-9`),
     confirming the cache-invalidation fix.
  5. `get_supported_testing_types()` shrinks to `"wald"` only after
     `set_estimand("marginal_mean_diff")`; `set_estimand()` errors and rolls
     back when `testing_type` is incompatible; `set_testing_type()` errors
     symmetrically under a marginal estimand — all per TODO-6's already-
     implemented mechanism, confirmed working for a real production class
     (TODO-6 itself was previously verified only against a test-double
     host).
  6. Marginal-estimand bootstrap (`approximate_bootstrap_distribution_beta_hat_T`,
     B=12/15) and randomization (`compute_rand_two_sided_pval`, r=25)
     inference both produce finite, `[-1,1]`-bounded draws/valid p-values —
     confirming TODO-7's "free" claim holds in practice for this class'
     `compute_treatment_estimate_during_randomization_inference()`, which
     does call `self$compute_estimate()` internally.
  7. Full existing test suites re-run clean: `test-mixin-contracts.R`,
     `test-inference-class-registry.R`,
     `test-parametric-bootstrap-lr-all-capable-classes.R`,
     `test-zero-one-inflated-beta-fast-math.R` (pre-existing, unrelated to
     this change). Package also loads cleanly under
     `EDI_VALIDATE_INFERENCE_CONTRACTS=true` (the strict parser-backed
     body-reference/collision validation) with all the new private methods
     and cross-references.
  8. **Registry stale-table bug found and fixed** (the same known hazard
     class documented repeatedly elsewhere in this migration effort):
     `inference_class_registry.R`'s static `infer_inference_direct_components()`
     switch table still listed this class's OLD three-component set,
     independent of the real `components =` argument in the factory call —
     `self$supports("marginal_estimand")` returned `FALSE` even after
     `MarginalEstimand` was correctly composed and its methods were
     reachable, because `get_effective_capabilities()` reads that stale
     static table, not the live factory call. Fixed by adding
     `"MarginalEstimand"` to that table's entry for this class. Caught only
     by an end-to-end `self$supports("marginal_estimand")` check, not by
     `roxygen2::parse_file()`/loading alone — worth remembering as a
     required verification step for any future class composing a new
     component via this registry pattern.
  9. New focused test file:
     `tests/testthat/test-zoib-marginal-estimand.R` (8 test blocks: default
     estimand/supported-estimands, conditional-path preservation across
     call orders and estimand round-trips, marginal point-estimate
     boundedness and call-order independence, delta-method SE numerical-
     gradient cross-check, testing-type shrink/symmetric-error behavior,
     bootstrap and randomization sanity) — all passing.

  New `@details` section added to the class's roxygen documenting the
  marginal estimand's formula, scale, and delta-method/testing-type
  caveats; verified with `roxygen2::parse_file()`.

- [x] TODO-5: **Gated on the same open Phase 1D item as TODO-4 — verified
  2026-08-18: `InferenceCountZeroInflatedPoisson`/`NegBin`,
  `InferenceCountHurdlePoisson`/`NegBin`, and their shared abstract
  `InferenceCountZeroAugmentedPoissonAbstract` all still `inherit =`
  legacy deep-hierarchy bases.** Sequence after migration. Zero-augmented
  Poisson (ZIP and hurdle concretes): mean functions (including the
  zero-truncated hurdle mean); wire `"marginal_ratio"` and
  `"marginal_mean_diff"`.

  **Partial pass, 2026-08-23: math/plumbing groundwork done and verified in
  isolation, but NOT wired into any public API — no behavior change to any
  shipped class.** What landed, all in
  `inference_count_zero_augmented_poisson_abstract.R` (plus one registry
  fix): (1) `zero_augmented_sandwich_se()` refactored — without changing
  its existing output for any current caller — to factor its bread/meat
  sandwich construction into a new `zero_augmented_poisson_sandwich_vcov_full()`
  that returns the *full* robust covariance matrix instead of throwing away
  every entry but `[j_treat, j_treat]`; this is Poisson-only (the score
  formulas assume a plain `exp()`-link Poisson mean with no dispersion
  term) — confirmed by reading the function fully, matches the plan's own
  warning. (2) `zero_augmented_poisson_mean_from_theta()`: the model-implied
  mean, `(1 - pi) * lambda` for ZIP (untruncated Poisson mean) or
  `(1 - pi) * lambda / (1 - exp(-lambda))` for hurdle (zero-truncated
  Poisson mean — verified algebraically: truncating a Poisson to exclude 0
  does not change its rate parameter, only the normalizing constant, so
  `E[Y | Y>0] = lambda / P(Y>0)` is exact for Poisson specifically, per
  Cameron & Trivedi ch. 4.2 — this Poisson-only shortcut does **not**
  generalize to NegBin, confirming the plan's warning). (3)
  `zero_augmented_poisson_marginal_functional()`: g-computation average
  (all-treated vs. all-control design-matrix substitution, mirroring
  ZOIB's `zoib_marginal_mean_diff_from_coefs()` pattern) for both
  `"marginal_mean_diff"` and log-scale `"marginal_ratio"`. (4)
  `compute_marginal_estimand_estimate()`: the post-fit dispatcher, reusing
  `marginal_estimand_delta_se()` (TODO-4's generic helper, unchanged)
  against the new full sandwich vcov. (5) Stashed `X_fit`/`Xzi_fit`/
  `is_hurdle` onto the cached fit object in `generate_mod()`'s Poisson
  branch (mirroring ZOIB's `mod$X`/`mod$X_zero_one`) so the marginal path
  is a pure post-fit transform, no refit — confirmed this field did not
  already exist (unlike TODO-4's ZOIB, which already had it). (6) Found
  and fixed one real bug while wiring this in: the component registry's
  static `ZeroAugmentedCountLikelihood` spec (`contracts_mixins.R`) lists
  `provides_private_methods` explicitly and rejects any component-body
  method not named there (contract rule #2) — the package failed to load
  at all (`"has stale private method metadata"`) until the 4 new private
  method names were added to that list. Manually smoke-tested post-fix: a
  fresh `InferenceCountZeroInflatedPoisson` fit's existing (conditional)
  `compute_estimate()`/`compute_asymp_confidence_interval()` behavior is
  unchanged (spot-checked numerically, not a full golden diff).

  **Deliberately NOT done — the actual public-API wiring — because of a
  real architectural blocker found mid-implementation, not a math
  uncertainty:** `InferenceCountZeroInflatedPoisson`/`HurdlePoisson` (and
  their NegBin siblings) are plain `R6::R6Class(inherit =
  InferenceCountZeroAugmentedPoissonAbstract)` leaves, not
  `define_inference_class()` calls of their own — only the shared
  *abstract* is factory-built. Composing a new component
  (`"MarginalEstimand"`) is only legal through `define_inference_class()`,
  and it can't be added at the abstract level without also silently
  handing the (unimplemented, NegBin-invalid) capability to the NegBin
  siblings that share that same abstract. The correct fix is converting
  the two Poisson leaves to real `define_inference_class(inherit =
  InferenceCountZeroAugmentedPoissonAbstract, components =
  c("MarginalEstimand"), ...)` calls of their own (`resolve_inference_
  components()` inherits a `define_inference_class`-built parent's
  components automatically, so this is legal and matches how other
  "thin leaf of an already-composed abstract" classes are migrated
  elsewhere in this codebase) — but every such conversion done elsewhere
  this session needed a careful, class-specific `overrides` list to
  resolve public/private method collisions between the newly-composed
  component and the existing inherited body, and getting that wrong
  produces exactly the kind of silently-broken state this plan's own
  standing instruction says to avoid. Under the time/context budget
  available for this pass, converting two classes' inheritance shape
  carefully enough to trust was not achievable alongside the math work
  above without rushing one or the other — left honestly unfinished
  rather than risk a subtly-wrong collision resolution.

  **Resume instructions for whoever picks this up:** the math (items 1-5
  above) is done, isolated, and doesn't need to be redone — only wire it
  in. For each of `InferenceCountZeroInflatedPoisson`/`HurdlePoisson`:
  convert `R6::R6Class(...)` to `define_inference_class(classname = "...",
  inherit = InferenceCountZeroAugmentedPoissonAbstract, components =
  "MarginalEstimand", public = list(...its existing public members...,
  get_supported_estimands_impl is private, not public...), private =
  list(get_supported_estimands_impl = function() c("conditional",
  "marginal_ratio", "marginal_mean_diff")), overrides = list(...))`,
  following `InferencePropZeroOneInflatedBetaRegr`'s exact `components =
  c(..., "MarginalEstimand")` + `overrides` shape as the template. Then add
  `compute_estimate()`/`compute_asymp_confidence_interval()`/
  `compute_asymp_two_sided_pval()` overrides that branch on
  `self$get_estimand()`, calling `private$compute_marginal_estimand_
  estimate("marginal_mean_diff"/"marginal_ratio", estimate_only)` in the
  marginal branch and the existing conditional logic otherwise — mirror
  ZOIB's `compute_estimate()`/CI/pval bodies verbatim, just swapping the
  functional call. NegBin variants remain out of scope (the mean-function
  and sandwich-score derivations above are Poisson-specific by
  construction) — do not attempt to reuse `zero_augmented_poisson_mean_
  from_theta()`/`_sandwich_vcov_full()` for `InferenceCountZeroInflatedNegBin`/
  `HurdleNegBin` without rederiving both for the NegBin likelihood first.
  Add a test file mirroring `test-zoib-marginal-estimand.R`'s structure
  once wired. Verify `self$supports("marginal_estimand")` end-to-end on a
  real instance of both classes, not just that the package loads (this
  pass's own registry bug, found above, is exactly the kind of thing that
  silently breaks capability detection while the package still loads
  fine).

  Files touched this pass:
  `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`,
  `R/EDI/R/contracts_mixins.R` (registry fix only). No public API changed;
  `pkgload::load_all(compile = FALSE)` succeeds; a manual smoke test of
  `InferenceCountZeroInflatedPoisson`'s existing conditional
  `compute_estimate()`/CI confirmed unchanged output.

  **Earlier verification note (superseded by the above, kept for
  context):** re-verified 2026-08-23, migration gating is lifted: live
  manifest confirms
  zero `algorithmic_compatibility_ancestors` for all four concrete classes
  and their shared abstract (three of the four concretes show
  `migration_status == "pending"` only because they're one level removed
  through the abstract, the documented accepted terminal state of
  `fix_inference_hierarchy.md` — not a real gate). **What's different from
  TODO-4 and why this needs its own dedicated pass rather than a quick
  extension of TODO-4's pattern:**
  - The count family's covariance is a **sandwich (robust) estimator**
    (`private$zero_augmented_sandwich_se()`), not a plain MLE-inverse-Hessian
    joint vcov like ZOIB's — read that method fully before assuming
    `marginal_estimand_delta_se()` can reuse the same joint-vcov-times-
    gradient recipe unchanged; the sandwich matrix's exact parameter
    ordering/dimension needs to be confirmed against whatever `generate_mod()`
    already caches (or doesn't yet cache — check, the same "add a field
    that's already computed but discarded" opportunity TODO-4 found may or
    may not exist here).
  - NegBin uses a distinct C++ path (`fast_zinb_cpp`) from Poisson
    (`fast_zero_augmented_poisson_cpp` with an `is_hurdle` flag) —
    confirm both return the same covariance-matrix shape/field name before
    writing one shared mean-function helper for all four classes.
  - Two genuinely different mean-function formulas needed, and getting them
    right matters more here than for ZOIB since this family also needs a
    **log-scale ratio** estimand (`"marginal_ratio"`), not just a
    difference: zero-inflated mean is `(1 - P(structural zero)) * mu_count`
    (untruncated Poisson/NegBin mean); hurdle mean is `P(Y>0) *
    E[Y | Y>0]` using the **zero-truncated** count mean, which is NOT the
    same formula as the untruncated mean divided by `P(Y>0)` for NegBin
    (only true for Poisson) — verify the truncated-NegBin mean formula
    against a primary source before shipping it; a plausible-looking wrong
    formula here would be a silently-wrong-numbers bug, exactly what this
    package's CLAUDE.md and this plan's own motivation (ICH E9(R1)/FDA
    marginal-estimand guidance) both take most seriously.
  - Whether one generic marginal-mean/gradient helper belongs on the shared
    abstract `InferenceCountZeroAugmentedPoissonAbstract` (probably yes,
    given `za_family()`/`za_description()`'s existing per-class-supplies-
    one-hook pattern) or per-concrete-class is an open design call for
    whoever picks this up — the abstract's `generate_mod()`/`shared()`/
    sandwich-SE machinery is already substantially more complex and
    interleaved (`is_hurdle` branches throughout, `record_zero_augmented_fit_summary()`,
    fallback paths) than ZOIB's, and deserves a careful read (not a
    skim) before deciding.
  - Same `compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval`-
    bypass and cache-invalidation-on-toggle bugs TODO-4 found and fixed are
    architecturally certain to recur here (same `StandardModelCache`-style
    composition pattern) — apply the same two fixes (override both methods
    to call `self$compute_estimate()` first; re-derive conditional values
    from `cached_mod` unconditionally rather than trusting
    `cached_values`) proactively rather than rediscovering them.
  - Same registry-stale-table risk TODO-4 hit
    (`infer_inference_direct_components()` in `inference_class_registry.R`)
    — check `self$supports("marginal_estimand")` end-to-end on a real
    instance of each of the four classes, not just that the package loads.

  Left entirely unimplemented rather than half-wired, per this session's
  explicit directive: a wrong truncated-mean formula shipped confidently
  is worse than an honest "not yet done."

  **Wiring pass, 2026-08-23: complete for ZIP and hurdle Poisson (NegBin
  variants remain explicitly out of scope, per above).** Converted
  `InferenceCountZeroInflatedPoisson` (`inference_count_zero_inflated.R`)
  and `InferenceCountHurdlePoisson` (`inference_count_hurdle.R`) from plain
  `R6::R6Class(inherit = InferenceCountZeroAugmentedPoissonAbstract)` leaves
  to real `define_inference_class(inherit =
  InferenceCountZeroAugmentedPoissonAbstract, components =
  "MarginalEstimand", ...)` calls of their own, mirroring
  `InferencePropZeroOneInflatedBetaRegr`'s TODO-4 conversion exactly:
  `get_supported_estimands_impl()` returns
  `c("conditional", "marginal_mean_diff", "marginal_ratio")`;
  `compute_estimate()`/`compute_asymp_confidence_interval()`/
  `compute_asymp_two_sided_pval()` overridden to branch on
  `self$get_estimand()`, dispatching to
  `private$compute_marginal_estimand_estimate(estimand, estimate_only)`
  under a marginal estimand and to a re-derive-from-`cached_mod` conditional
  path otherwise (same toggle-safety fix as ZOIB); `metadata =
  list(likelihood_tier = "full")` restated explicitly (validated against
  the class's own declared metadata at `define_inference_class()` time, not
  the inherited value — same requirement TODO-4 hit).

  **Two real bugs found and fixed while wiring this in** (beyond the two
  already anticipated and applied proactively — the `compute_asymp_*`
  bypass fix and the `infer_inference_direct_components()` registry entry,
  both needed and both added exactly as predicted above):
  1. **`private$cached_mod` is not the raw backend fit for this family.**
     Unlike ZOIB (where `private$cached_mod` stays the actual fitted-model
     object throughout), this family's shared `shared()`
     (`CountLikelihoodPlumbingSource`, `inference_all_abstract_count_
     likelihood.R`) unconditionally overwrites `private$cached_mod` with
     `generate_mod()`'s full return wrapper (`out`: `beta_hat_T`/`ssq_b_j`/
     `params`/`fisher_information`/`mod`) immediately after calling it —
     silently clobbering the `private$cached_mod = fit` assignment
     `generate_mod()` makes internally (where the TODO-5 partial pass had
     stashed `X_fit`/`Xzi_fit`/`is_hurdle` onto `fit`, per its own writeup
     above). The raw fit — and the stashed fields — actually live one level
     deeper, at `private$cached_mod$mod`. Caught immediately by an end-to-end
     smoke test (`inf$compute_estimate()` returned `NA` under a marginal
     estimand despite `supports("marginal_estimand")` correctly returning
     `TRUE` and the conditional path working) — confirmed via direct
     inspection (`mod$X_fit` was `NULL`, `mod$mod$X_fit` was not). Fixed
     `compute_marginal_estimand_estimate()`
     (`inference_count_zero_augmented_poisson_abstract.R`) to read
     `raw = mod$mod` and use `raw$X_fit`/`raw$Xzi_fit`/`raw$is_hurdle`/
     `raw$params` throughout (the sandwich-vcov helper also needs the raw
     fit object, not the wrapper, per its own signature — confirmed
     consistent with how `generate_mod()` itself already calls
     `zero_augmented_sandwich_se(fit, ...)` with the raw fit for the
     conditional SE).
  2. **Also fixed the same toggle-safety gap for the conditional path
     itself**, one level more than TODO-4 needed: `generate_mod()`'s
     Poisson branch computed `beta_hat_T`/`ssq_b_j` only onto the `out`
     wrapper, not onto `fit` (== `private$cached_mod$mod`), so the new
     `compute_estimate()`'s conditional re-derivation (reading
     `mod$beta_hat_T %||% mod$params[2L]` from `private$cached_mod`, which
     IS the `out` wrapper — this part was already correct, since `out$beta_
     hat_T`/`out$ssq_b_j` exist directly) worked by coincidence for the
     *conditional* path but would have broken if anyone later tried to read
     those fields off `raw`/`private$cached_mod$mod` instead. Stashed
     `fit$beta_hat_T`/`fit$ssq_b_j` onto the raw fit too, alongside the
     existing `X_fit`/`Xzi_fit`/`is_hurdle` stash, for consistency and
     future-proofing (not required for either path in this pass, but
     documented inline as to why it's there).

  **Verification performed:**
  - Truncated-Poisson-mean formula: re-verified numerically (independent of
    the model fit) — `rpois(3e5, lambda = 2.3)` truncated to exclude 0 has
    empirical mean `2.5566`-ish vs. formula `lambda / (1 - exp(-lambda))
    = 2.5563`, relative difference `~0.0005`, consistent with Monte Carlo
    noise at that sample size (also spot-checked at `N = 2e6` interactively:
    relative difference `~0.0005` again). Formula confirmed exact, not just
    plausible.
  - Both classes' marginal `"marginal_mean_diff"`/`"marginal_ratio"` point
    estimates verified to match a fully independent hand-computed
    g-computation average (constructed from the raw fitted coefficients via
    `plogis()`/`exp()` by hand in a test, not by calling any package
    function) to `1e-8` tolerance.
  - Conditional estimate/CI verified byte-identical (`1e-8` tolerance)
    between a fresh object that never touches `set_estimand()` and one that
    round-trips through both marginal estimands and back to `"conditional"`,
    for both classes — confirms the toggle-safety fix.
  - `self$supports("marginal_estimand")` verified `TRUE` on real constructed
    instances of both classes (not just successful package load) — this
    exact bug class bit the very first attempt at this pass too, caught the
    same way as TODO-4.
  - `NegBin` siblings (`InferenceCountZeroInflatedNegBin`,
    `InferenceCountHurdleNegBin`) verified to still report
    `supports("marginal_estimand") == FALSE` — confirms they were correctly
    left untouched, not accidentally granted the Poisson-only capability
    via the shared abstract.
  - New test file `test-zip-hurdle-poisson-marginal-estimand.R`: 11
    assertions, all passing, covering all the checks above plus delta-method
    SE finiteness and testing-type shrink-to-Wald symmetry (mirroring
    `test-zoib-marginal-estimand.R`'s structure).
  - Full regression check: `test-zoib-marginal-estimand.R` (TODO-4's own
    suite, unaffected by this pass's changes) and
    `test-count-likelihood-families-focused.R`, `test-mixin-contracts.R`,
    `test-inference-class-registry.R`, `test-static-cleanup-guardrails.R`
    all pass clean with no new failures.
  - A `DESCRIPTION`-`Collate:` ordering bug also surfaced and was fixed:
    `inference_count_hurdle.R` was collated *before*
    `inference_count_zero_augmented_poisson_abstract.R`, which
    `R6::R6Class()`'s lazy-promise `inherit` argument tolerated (only forced
    at `$new()` time) but `define_inference_class()`'s definition-time
    validation does not (it resolves `inherit` immediately) — reordered
    `inference_count_hurdle.R` to load after the abstract.

  All verification used `pkgload::load_all(".", compile = FALSE)` only; no
  compile/install step was run at any point in this pass.

  Files touched this pass: `R/EDI/R/inference_count_zero_inflated.R`,
  `R/EDI/R/inference_count_hurdle.R`,
  `R/EDI/R/inference_count_zero_augmented_poisson_abstract.R`,
  `R/EDI/R/inference_class_registry.R`, `R/EDI/DESCRIPTION`, and the new
  `R/EDI/tests/testthat/test-zip-hurdle-poisson-marginal-estimand.R`.
- [x] TODO-6: `get_supported_testing_types_with_bartlett()`
  (`inference_all_abstract_asymp_lik.R`, the `LikelihoodTests` component's
  source) now shrinks to `"wald"` only when
  `self$supports("marginal_estimand")` is `TRUE` and
  `self$get_estimand() != "conditional"` — checked via the sanctioned
  capability query, not a private-method-name probe (Source Invariant #19
  bans `has_private_method()`-based semantic classification), so classes
  that don't compose `MarginalEstimand` pay no cost and see zero behavior
  change. Since `set_testing_type()`'s own validation already calls
  `get_supported_testing_types_with_bartlett()`, this one change makes
  both directions loud-error correctly with no separate code needed there.
  Added the symmetric direction to `set_estimand()`
  (`inference_all_abstract_marginal_estimand.R`): if the host also
  composes `LikelihoodTests` (`self$supports("likelihood_tests")`), the
  currently configured `testing_type` is checked against the (now
  possibly estimand-shrunk) supported set; an incompatible combination
  errors loudly and rolls the estimand change back, regardless of which
  setter is called first.

  **Verified** via a real `define_inference_class()`-built test-double
  host composing both `LikelihoodTests` and `MarginalEstimand` (through
  the full factory + registry path, not a bare R6 mixin, so
  `self$supports()`/`self$capabilities()` resolve exactly as they would
  for a real class) — confirmed all four cases: default `"conditional"`
  keeps the full testing-type set; switching to `"marginal_mean_diff"`
  shrinks it to `"wald"`; `set_testing_type("lik_ratio")` under a
  marginal estimand errors with the shrunk supported-values list;
  `set_estimand("marginal_mean_diff")` while `testing_type = "lik_ratio"`
  errors and leaves the estimand at `"conditional"`, then succeeds once
  `testing_type` is switched to `"wald"` first. Also ran the full test
  suite under `EDI_VALIDATE_INFERENCE_CONTRACTS=true` again after this
  change (clean) and isolated a batch of `test-asymp-inference-paths.R`
  failures that appeared mid-work: confirmed **100% pre-existing and
  unrelated** by `git stash`-ing just this change and re-running the same
  failing test file — identical failures occurred with my change fully
  removed, tracing to the concurrent Phase 1D session's own in-progress
  migration (`inference_continuous_KK_ols_one_lik.R`,
  `inference_survival_KK_strat_cox.R`, matching new golden-test files,
  none touched by me) — left untouched per this session's standing policy.
- [x] TODO-7: **Correction to the "not gated on Phase 1D" claim in the
  "Recommended execution order" note above — this item has no independent
  architecture to build.** Unlike `get_supported_testing_types()`
  (centrally owned by the `LikelihoodTests` component, hence TODO-6 being
  a real, standalone change), grepping every
  `compute_treatment_estimate_during_randomization_inference`/
  `compute_estimate_with_bootstrap_weights` definition in the codebase
  found **50+ of them, one per concrete class, owned by no shared
  component** — there is nothing centrally dispatchable to modify. This
  actually matches what the "Interactions with existing machinery"
  section already said, precisely: these paths are "free" and "need no
  new mathematics" *because* they call into each class's own
  `compute_estimate()`/fitted-value logic on resampled/reweighted data —
  once TODO-4/5/9 make a class's own `compute_estimate()` estimand-aware,
  the randomization and bootstrap paths inherit that automatically, with
  no separate TODO-7 code required. Reclassified: TODO-7 is not
  independent work, it is a **consequence of TODO-4/5/9**, verified by
  those items' own golden tests (add a randomization/bootstrap
  cross-check to each family's golden test when it lands) rather than a
  standalone gate. Same Phase 1D dependency as TODO-4/5/9.
- [x] TODO-8: Open question 1 (`compute_estimate()` dispatch mechanism)
  was resolved during TODO-3 (see that entry): `compute_estimate()` stays
  100% class-owned, never overridden/wrapped by `MarginalEstimand` — each
  host's own body will explicitly consult `self$get_estimand()` and call
  a shared g-computation helper when non-conditional (TODO-4/5/9). No
  `extending-edi-r6.md` update yet: the "mean-function contribution
  point" it would document doesn't exist as working code — that hook's
  exact interface is deliberately not designed until a real family
  (TODO-4's ZOIB) validates it, rather than guessing a signature nothing
  can check against. Revisit the extension contract (since 2026-08-23:
  `R/EDI/vignettes/extending-edi.Rmd`, not the retired `extending-edi-r6.md`)
  when TODO-4 lands the first real shared helper.
- [x] TODO-9: **Gated on the same open Phase 1D item as TODO-4/5 — verified
  2026-08-18: `InferenceIncidLogit`, `InferenceCountPoisson`,
  `InferenceProportionBeta`, and `InferenceIncidBinomialIdentity` all still
  `inherit =` legacy deep-hierarchy bases, not yet migrated.** Sequence
  after migration. Later wave: adopt on non-collapsible single-component GLM
  families (logistic, Poisson, beta regression) via one-line mean functions.

  **Done (2026-08-24).** The plan's own class names above were stale (the
  real names are `InferenceIncidLogRegr`, `InferenceCountPoisson`,
  `InferencePropBetaRegr`, `InferenceIncidBinomialIdentityRiskDiff`); all
  four confirmed live (`inherit = Inference` directly, `algorithmic_
  compatibility_ancestors` empty) before starting. All four now compose
  `MarginalEstimand` and are fully wired, each verified against a
  hand-computed g-computation average on a real fitted model (not just unit
  tests) plus the full `test-mixin-contracts.R`/`test-inference-class-
  registry.R`/`test-static-cleanup-guardrails.R` regression suites (all
  green):

  - **`InferenceIncidLogRegr`** — `"marginal_mean_diff"`/`"marginal_ratio"`
    (marginal risk difference / log risk ratio), mean function
    `plogis(X %*% beta)`. Point estimate matched a hand-computed g-computation
    average to full floating-point precision on a real logistic fit.
  - **`InferenceCountPoisson`** — `"marginal_mean_diff"`/`"marginal_ratio"`
    (marginal rate difference / log rate ratio), mean function
    `exp(X %*% beta)`. **Finding:** `"marginal_ratio"` is numerically
    identical to `"conditional"` for this family — a log-link GLM with no
    treatment-by-covariate interaction has
    `exp(b0+bT+X'g)/exp(b0+X'g) = exp(bT)` for every subject individually,
    so averaging before or after the ratio changes nothing;
    `"marginal_mean_diff"` is where g-computation actually changes the
    reported number (a difference does not collapse under the nonlinear log
    mean the way a ratio does). Documented explicitly in the class's
    roxygen so this isn't mistaken for a wiring bug. Also verified the
    class's pre-existing design-conservative union-with-jackknife-Wald
    testing machinery (unrelated to this TODO, found during TODO-9's own
    earlier gap analysis) correctly composes with the marginal estimand —
    the jackknife component refits under whatever estimand is active, so
    the union/max combination rule applies transparently to marginal CIs
    and p-values too, verified empirically (a marginal CI came back wider
    than the pure delta-method interval, confirming the union actually
    fired).
  - **`InferencePropBetaRegr`** — `"marginal_mean_diff"` only (no ratio —
    a ratio of two mean proportions, both bounded in \[0,1\], is not the
    standard estimand for a beta-regression treatment effect the way a
    rate ratio is for count data). Mean function `plogis(X %*% beta)`; the
    precision parameter \eqn{\phi} does not enter the mean. **Bug found
    and fixed while wiring:** `generate_mod()`'s Fisher information matrix
    is sized to the *joint* `[b, log_phi]` parameter vector (verified:
    `nrow == length(b) + 1`), not to `b` alone — naively inverting and
    passing the full joint vcov to `marginal_estimand_delta_se()` against
    a length-`length(b)` gradient silently returned `NA` for the SE (the
    helper's own dimension guard caught the mismatch safely, so this
    produced an honest `NA` rather than a wrong number, but still needed a
    real fix). Fixed by inverting the full joint information matrix first
    (correct — this preserves the b/log_phi covariance in the inversion)
    and then taking only the leading `length(b) x length(b)` block,
    matching `mod$b`'s order exactly. Verified against `betareg::betareg()`
    on the same data: point estimate matched to ~4 decimal places (small
    residual difference from a different optimizer/parameterization, not a
    bug), and the corrected SE is now finite and positive.
  - **`InferenceIncidBinomialIdentityRiskDiff`** — `"marginal_mean_diff"`
    only, wired for estimand-API consistency. **Confirmed the anticipated
    collapsing behavior exactly**: for an identity-link model with no
    treatment-by-covariate interaction, the g-computation marginal risk
    difference is algebraically \eqn{\hat\beta_T} for every subject
    individually (not just on average), so it is numerically identical to
    the conditional estimate — verified empirically to floating-point
    precision (\eqn{|{\rm marginal} - {\rm conditional}| \approx 5\times
    10^{-17}} on a real fit). Documented explicitly in the class's roxygen,
    including the explicit warning that a user comparing estimands for
    this class should not expect them to ever differ. The two paths'
    standard errors are computed independently (delta method vs.
    information matrix) and are not guaranteed to coincide even though the
    point estimates always do, though in practice they matched closely on
    the test fit.

  **Bug-classes proactively guarded against in all four** (per TODO-4/5's
  own findings, confirmed still architecturally relevant): (1)
  `compute_asymp_confidence_interval()`/`compute_asymp_two_sided_pval()`
  now call `self$compute_estimate()` first rather than `private$shared()`
  directly, so the estimand-aware cache is always current regardless of
  call order; found and fixed a related variant specific to this batch —
  `get_standard_error()`'s generic body tries an information-matrix-based
  SE first whenever `supports_information_preference()` is `TRUE` (true
  for all four of these `likelihood_tier = "full"` classes), which would
  silently substitute the wrong (conditional) SE for a marginal estimand
  if left unguarded; all four classes now override `get_standard_error()`/
  `get_degrees_of_freedom()` directly to short-circuit to the
  estimand-aware cached values whenever the estimand is non-conditional.
  (2) Conditional-path cache re-derivation from the estimand-invariant
  `cached_mod` on every `compute_estimate()` call, so toggling back to
  `"conditional"` after a marginal computation never returns stale
  numbers — verified via an explicit round-trip check on all four classes
  (conditional → marginal → conditional returns byte-identical values).
  (3) `inference_class_registry.R`'s `infer_inference_direct_components()`
  static switch-table updated for all four classes (same recurring
  stale-table bug TODO-4/5 hit) — verified `self$supports("marginal_estimand")`
  returns `TRUE` on real instances of all four, not just that the package
  loads.

  All edits verified with `roxygen2::parse_file()` and base `parse()`
  (clean), `pkgload::load_all(".", compile = FALSE)` (clean, no compile
  step used anywhere), and the full `test-mixin-contracts.R`/
  `test-inference-class-registry.R`/`test-static-cleanup-guardrails.R`
  suites (all green, no regressions). Files touched:
  `R/EDI/R/inference_incidence_logit.R`, `R/EDI/R/inference_count_poisson.R`,
  `R/EDI/R/inference_proportion_beta.R`,
  `R/EDI/R/inference_incidence_binomial_identity.R`,
  `R/EDI/R/inference_class_registry.R`. No commits made.

- [ ] TODO-10: **NegBin mixture variants — `InferenceCountZeroInflatedNegBin`
  and `InferenceCountHurdleNegBin`** (added 2026-08-27, this plan reopened —
  moved back out of `../finished_features/` to `new_feature_plans/`
  accordingly). Explicitly out of scope through TODO-4/5/9 above: every
  Poisson-family sibling (`InferenceCountZeroInflatedPoisson`,
  `InferenceCountHurdlePoisson`) now supports `"marginal_mean_diff"`/
  `"marginal_ratio"`, but the two NegBin concretes still report every
  marginal-estimand row as `nonest` for *every* inference method (Wald,
  randomization, all bootstrap variants, jackknife, score, LR, gradient) —
  not a convergence failure, but the documented absence of a `MarginalEstimand`
  component on these two classes (confirmed by inspection:
  `InferenceCountZeroInflatedNegBin`, `inference_count_zero_inflated.R:275-304`,
  is a plain `R6::R6Class(inherit = InferenceCountZeroAugmentedPoissonAbstract)`
  leaf with no `components =` argument at all, same shape
  `InferenceCountHurdleNegBin` had before TODO-5's Poisson-only wiring pass).

  Real math work required before wiring, not just a mechanical repeat of
  TODO-5's pattern (see that TODO's own "Resume instructions" — it
  explicitly warns future work not to reuse the Poisson helpers for NegBin
  without rederiving both pieces below):
  1. **Model-implied mean function**, using `fast_zinb_cpp`'s parameterization
     (`log_theta` tail entry, per `bootstrap_calibrated_lr_report.md`'s own
     note that this extraction is already done there for a different
     purpose): zero-inflated NegBin mean is `(1 - pi(x)) * mu(x)` — the
     same untruncated-mean shape as Poisson's ZIP case, so this half may
     port directly. The hurdle NegBin mean is **not** a direct port: TODO-5
     found that `E[Y | Y>0] = lambda / P(Y>0)` is a Poisson-only identity,
     and the truncated-NegBin mean must be rederived from a primary source
     (Cameron & Trivedi or equivalent) before shipping — a plausible-looking
     wrong truncated-mean formula here is exactly the silently-wrong-numbers
     failure mode this plan's own TODO-5 refused to risk.
  2. **Covariance source.** Unlike the Poisson family's sandwich
     (`zero_augmented_poisson_sandwich_vcov_full()`, score formulas assume a
     plain `exp()`-link Poisson mean with no dispersion term — confirmed
     Poisson-only, cannot be reused as-is), the NegBin fit's joint
     information matrix already covers `[beta, log_phi/log_theta, gamma...]`
     via `fast_zinb_cpp`/`fast_hurdle_negbin_cpp`'s own Hessian — confirm its
     exact field name/shape (mirrors ZOIB's plain MLE-inverse-Hessian vcov,
     per TODO-4, more than it mirrors the Poisson family's sandwich, per
     TODO-5) before assuming `marginal_estimand_delta_se()` can be reused
     unchanged.
  3. **Wiring**, once 1–2 are derived and verified in isolation: convert both
     classes from bare `R6::R6Class(...)` leaves to
     `define_inference_class(inherit = InferenceCountZeroAugmentedPoissonAbstract,
     components = "MarginalEstimand", ...)`, following TODO-5's Poisson
     conversion as the template — including its three found-and-fixed bug
     classes, all architecturally certain to recur here: (a) `private$cached_mod`
     for this family is the `generate_mod()` wrapper, not the raw fit — the
     raw fit (and any stashed `X_fit`/`Xzi_fit`/`is_hurdle` fields) lives one
     level deeper at `private$cached_mod$mod`; (b) `compute_asymp_confidence_interval()`/
     `compute_asymp_two_sided_pval()` must call `self$compute_estimate()`
     first, not `private$shared()` directly; (c) the `inference_class_registry.R`
     `infer_inference_direct_components()` static switch-table needs both
     classes added, and `self$supports("marginal_estimand")` must be checked
     end-to-end on real instances, not inferred from a clean package load.
  4. New test file mirroring `test-zip-hurdle-poisson-marginal-estimand.R`'s
     structure, including the truncated-mean-formula numerical cross-check
     TODO-5 ran (simulate a large truncated draw, compare empirical vs.
     formula mean) before trusting the hurdle path's point estimates.

  Not started. Release-line placement is an open question for whoever
  schedules it — see `future_release_plans/release_v1_1_0.md` for the
  current v1.1.0 TODO list this should be added to.
