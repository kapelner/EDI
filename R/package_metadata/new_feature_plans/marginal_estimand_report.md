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
- [ ] TODO-4: **Gated on `fix_inference_hierarchy.md`'s still-open
  "Full-Likelihood Estimators" remainder (`_master.md` § 1D) — verified
  2026-08-18: `InferencePropZeroOneInflatedBetaRegr` still `inherit =
  InferenceAsympLikStdModCache` (a legacy deep-hierarchy base), not yet
  migrated to `Inference` + explicit components.** Sequence after that
  migration lands, not before — wiring marginal-mean logic into a class
  about to be restructured means redoing the wiring. ZOIB: model-implied
  mean function, g-computation average, and delta-method SE against the
  joint vcov already returned by `fast_zero_one_inflated_beta_cpp`; wire
  `"marginal_mean_diff"`.
- [ ] TODO-5: **Gated on the same open Phase 1D item as TODO-4 — verified
  2026-08-18: `InferenceCountZeroInflatedPoisson`/`NegBin`,
  `InferenceCountHurdlePoisson`/`NegBin`, and their shared abstract
  `InferenceCountZeroAugmentedPoissonAbstract` all still `inherit =`
  legacy deep-hierarchy bases.** Sequence after migration. Zero-augmented
  Poisson (ZIP and hurdle concretes): mean functions (including the
  zero-truncated hurdle mean); wire `"marginal_ratio"` and
  `"marginal_mean_diff"`.
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
  can check against. Revisit `extending-edi-r6.md` when TODO-4 lands the
  first real shared helper.
- [ ] TODO-9: **Gated on the same open Phase 1D item as TODO-4/5 — verified
  2026-08-18: `InferenceIncidLogit`, `InferenceCountPoisson`,
  `InferenceProportionBeta`, and `InferenceIncidBinomialIdentity` all still
  `inherit =` legacy deep-hierarchy bases, not yet migrated.** Sequence
  after migration. Later wave: adopt on non-collapsible single-component GLM
  families (logistic, Poisson, beta regression) via one-line mean functions.
