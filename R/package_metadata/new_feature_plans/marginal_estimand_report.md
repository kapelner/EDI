# Conditional vs. Marginal Estimand Switch (`set_estimand()`)

> **Depends on:** gated decision only — but it must be decided **jointly with**
> `expanded_estimate_report.md → TODO-1` (the `estimate_type` decision): the two
> are orthogonal axes over the same fitted object, and deciding them separately
> risks one enum absorbing values that belong on the other. (Global ordering:
> see `_master.md`.)

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

- [ ] TODO-1: **Decision — ask the user; decide jointly with
  `expanded_estimate_report.md → TODO-1`** so the two enums are scoped
  against each other (`estimate_type` = estimator corrections,
  `estimand` = target quantity). Record both decisions in both plans before
  starting anything below.
- [ ] TODO-2: Independent of TODO-1's outcome: sharpen the roxygen headers of
  `inference_proportion_zero_one_inflated_beta.R` and
  `inference_count_zero_augmented_poisson_abstract.R` to state the
  component-conditioning bluntly (not the effect on `E[Y]`). Pulled into the
  v1.0.0 documentation batch per `release_v1_0_0.md → TODO-3` (the rest of
  this plan is deferred to 1.x).
- [ ] TODO-3: If pursued: implement the switch architecture — `set_estimand()`
  / `get_estimand()` / `get_supported_estimands()`, estimand-aware cache key
  generalizing `likelihood_test_delta_key()`, initial state `"conditional"` —
  as a registered `InferenceComponent` with a `marginal_estimand` capability,
  honoring the three constraints in "Compatibility with
  `fix_inference_hierarchy.md`" (the setter exists only on composing classes;
  choose the `compute_estimate()` dispatch mechanism explicitly).
- [ ] TODO-4: ZOIB: model-implied mean function, g-computation average, and
  delta-method SE against the joint vcov already returned by
  `fast_zero_one_inflated_beta_cpp`; wire `"marginal_mean_diff"`.
- [ ] TODO-5: Zero-augmented Poisson (ZIP and hurdle concretes): mean
  functions (including the zero-truncated hurdle mean); wire
  `"marginal_ratio"` and `"marginal_mean_diff"`.
- [ ] TODO-6: Make `get_supported_testing_types()` estimand-aware; loud
  errors on incompatible `testing_type` × `estimand` combinations regardless
  of setter order.
- [ ] TODO-7: Dispatch the randomization-inference statistic and the
  bootstrap-weight recompute paths on the estimand.
- [ ] TODO-8: Resolve open question 1 (`compute_estimate()` dispatch) as part
  of the TODO-1 joint decision; update `extending-edi-r6.md` if the external
  extension contract changes (mean-function contribution point).
- [ ] TODO-9: Later wave: adopt on non-collapsible single-component GLM
  families (logistic, Poisson, beta regression) via one-line mean functions.
