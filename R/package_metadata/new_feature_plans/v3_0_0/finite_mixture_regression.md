# Finite Mixture Regression (Latent-Class Mixtures of Existing Families)

> **For agentic workers:** this file is a **scoping document**, not yet an
> executable implementation plan. It records the architecture and the
> decisions already made about it; it deliberately stops short of a
> TODO-by-TODO breakdown with test code (see "Implementation Sequencing"
> below for why). When this is picked up, run it through
> superpowers:writing-plans (or this repo's own plan-writing convention) to
> produce the granular TODOs against the *then-current* codebase — much of
> the per-family wiring below depends on kernel details that may have
> shifted by the time v2.0.0 actually ships.

> **Depends on:** `marginal_estimand_report.md` (the marginal/mixture-
> averaged treatment-effect estimand, §D below, reuses its
> `set_estimand("marginal_*")` transformation machinery — **verify at
> implementation time** that its concrete per-family wiring, TODO-4/5/7/9,
> has actually landed, not just that its TODO-1 decision was made;
> `fix_inference_hierarchy.md`, that plan's own gate, closed 2026-08-23 per
> that plan's closure note, but this file's dependency is on the concrete
> wiring, not the gate); `multistart_nonconcave_likelihoods.md` (this
> plan's EM fitting reuses that plan's random-restart infrastructure for
> initialization robustness — see §A); every existing
> `fast_<family>_regression.cpp` kernel's weighted-fit entry point (audited
> per family before use, not assumed — see TODO-1 under Implementation
> Sequencing). **Relevant, not blocking:**
> `em_algorithm_zero_inflated_mixtures.md` — same "generic E/M driver
> reusing each family's existing weighted kernel for the M-step" pattern,
> generalized here from a *fixed 2-part mix of two different families*
> (zero mass + count component) to a *general K-way mix of one family*.
> That plan's EM is a **start generator** for a separate joint optimizer;
> this plan's EM **is** the terminal optimizer. Worth keeping straight —
> these are two different uses of the same trick, not the same feature
> twice. Release: **`release_v3_0_0.md`** (tentative). Explicitly scoped for after
> v2.0.0 (user decision, 2026-09-10, made in the same sitting that produced
> this document) — genuinely new architecture per `_master.md`'s own
> release-split rule ("2.0.0 = genuinely new functionality requiring large
> refactorings or new architecture"), and past that boundary rather than
> inside it. Wired into `release_v3_0_0.md` and `_master.md` (2026-09-10,
> same day, once that post-2.0.0 release line opened to hold it —
> alongside `bayesian_stan_primary_analysis_report.md`, the other v3.0.0
> item).

Date: 2026-09-10

**Goal:** Let any existing EDI regression family be fit as a **K-component
finite mixture** — unobserved latent subpopulations, each with its own
family-specific coefficients, jointly estimated by EM — rather than adding
one bespoke mixture implementation. Report per-component estimates plus a
mixture-weighted marginal (population-averaged) estimate, with bootstrap
confidence intervals and BIC/ICL for comparing a handful of user-chosen `K`
values.

**Architecture:** A generic EM driver (new C++ header,
`em_finite_mixture_regression.h`) parameterized by two per-family
callbacks — a per-observation log-density function (E-step) and the
family's **existing** weighted internal fit function (M-step, already
present and already accepting a `weights` vector for every family audited
so far: logistic, probit, Poisson, NegBin, OLS, robust regression, beta
regression, continuation-ratio, log-binomial — see
`R/EDI/src/fast_*_regression.cpp`'s `*_weighted_cpp` exports). On the R
side, one concrete `Inference*Mixture` class per family (e.g.
`InferenceContinOLSMixture`, `InferenceCountPoissonMixture`,
`InferencePropBetaRegrMixture`), each defined via `define_inference_class()`
composing a new shared mixin component, `InferenceMixinFiniteMixtureEM`,
that supplies the generic orchestration (E/M loop, multistart, bootstrap,
label-switching correction, BIC/ICL, print/summary). Each concrete class
supplies only its two family-specific callbacks. This mirrors the
codebase's existing "shallow hierarchy, shared behavior via components, not
inheritance" architecture (`fix_inference_hierarchy.md`'s guardrails)
rather than introducing a new inheritance ladder.

**Tech Stack:** C++17 / Eigen, reusing existing per-family weighted-fit
kernels; no new package dependency (R or C++) — matches every other
EM-adjacent plan's constraint in this codebase.

**Spec:** this file. Key citations: McLachlan, G. J. & Peel, D. (2000),
*Finite Mixture Models*, Wiley, ch. 2–3 (general EM-for-mixtures theory,
monotone-ascent proof — shared with `em_algorithm_zero_inflated_mixtures.md`);
DeSarbo, W. S. & Cron, W. L. (1988), "A Maximum Likelihood Methodology for
Clusterwise Linear Regression," *Journal of Classification* 5(2), 249–282
(the Gaussian/continuous case); Wedel, M. & DeSarbo, W. S. (1995), "A
Mixture Likelihood Approach for Generalized Linear Models," *Journal of
Classification* 12(1), 21–55 (the general-family case this plan's generic
driver is built to cover); Leisch, F. (2004), "FlexMix: A General Framework
for Finite Mixture Models and Latent Class Regression in R," *Journal of
Statistical Software* 11(8), 1–18 (the closest prior-art architecture —
useful as a design reference even though this plan deliberately does not
depend on the package itself); Stephens, M. (2000), "Dealing with Label
Switching in Mixture Models," *JRSS-B* 62(4), 795–809 (§C's ordering rule);
Biernacki, C., Celeux, G. & Govaert, G. (2000), "Assessing a Mixture Model
for Clustering with the Integrated Completed Likelihood," *IEEE TPAMI*
22(7), 719–725 (ICL, §C); Louis, T. A. (1982), "Finding the Observed
Information Matrix When Using the EM Algorithm," *JRSS-B* 44(2), 226–233
(cited for the asymptotic-SE approach explicitly deferred past v1 — see
"Explicitly Deferred" below).

## Decisions Already Made (2026-09-10, this conversation)

- **General finite mixture regression**, not mixture-of-experts (constant
  mixing proportions, not covariate-dependent gating) and not merely an
  extension of the existing zero-inflated two-part mixtures.
- **Native implementation, no new dependency** — reuses existing weighted
  kernels; no `flexmix`/`mixtools` wrapping considered further.
- **Generic architecture across (eventually) every family from day 1** —
  but concrete per-family wiring is still batched (see Implementation
  Sequencing).
- **`n_components = K` is user-specified**; no automatic K-search in v1.
  BIC and ICL are exposed so a user can compare a few `K` values by hand.
- **Bootstrap-only inference for v1** — no asymptotic (Louis' method) SEs;
  no randomization-based CI (see "Explicitly Deferred").
- **Both per-component and marginal (mixture-weighted) estimates ship in
  v1** — the marginal estimand depends on `marginal_estimand_report.md`'s
  machinery (see header dependency note).
- **Class shape:** one concrete class per family + a shared
  `InferenceMixinFiniteMixtureEM` component, not one generic
  parameterized class and not per-family inheritance.

---

## Design

### A. The generic EM driver

For a `K`-component mixture of family `f` with parameters `θ_1..θ_K` and
mixing proportions `π_1..π_K` (`Σπ_k = 1`):

- **E-step:** responsibility `r_{ik} ∝ π_k · density_f(y_i | x_i; θ_k)`,
  normalized over `k` for each `i`.
- **M-step:** for each `k`, a **weighted refit** of family `f`'s existing
  kernel with `weights = r_{·k}` (the family's current parameter estimate
  `θ_k`), plus `π_k = mean(r_{·k})`. Each component's M-step is exactly the
  concave sub-problem the family's existing IRLS/Newton kernel already
  solves — EM's role is only to decouple the mixture's joint nonconcave
  problem into `K` well-behaved weighted refits per iteration, the same
  role it plays in `em_algorithm_zero_inflated_mixtures.md`.
- **Stopping:** observed-data log-likelihood (`Σ_i log Σ_k π_k ·
  density_f(y_i|x_i;θ_k)`) increases by less than a tolerance, or an
  iteration cap.
- **Termination role — the key difference from the zero-inflated plan:**
  there, EM only generates a *start* for a separate joint optimizer,
  because the zero-inflated model's two components are different families
  glued together and a joint Newton polish is well-defined and cheap on
  the resulting concave-ish objective. Here, EM **is** the fitting
  algorithm. A full `K`-component mixture likelihood in one family is
  genuinely and structurally multimodal — permutation symmetry across
  components alone produces `K!` equivalent optima, on top of any real
  local optima — so there is no single "joint optimizer" to hand off to.
  Robustness instead comes from **multistart random restarts**
  (`multistart_nonconcave_likelihoods.md`'s existing infrastructure,
  reused for initialization diversity rather than polish), keeping the
  run with the best observed-data log-likelihood.

### B. R-level class shape and registry integration

One concrete class per family (`InferenceContinOLSMixture`,
`InferenceCountPoissonMixture`, `InferencePropBetaRegrMixture`, …), each
via `define_inference_class()` composing `InferenceMixinFiniteMixtureEM`.
The mixin owns everything generic (E/M loop, multistart, bootstrap,
label-switching correction, BIC/ICL, print/summary); each concrete class
supplies only:

1. A per-observation log-density function for its family (E-step). **Not
   yet confirmed to exist** for every family — the existing per-family
   objective classes compute an *aggregated* weighted negative
   log-likelihood for IRLS, not necessarily an exposed per-row density.
   This needs the same kind of audit `em_algorithm_zero_inflated_mixtures.md`
   → TODO-1 already did for its three kernels, generalized to every family
   this plan eventually covers.
2. A pointer to the family's existing weighted internal fit function
   (M-step) — confirmed present (as `*_weighted_cpp` / an internal
   equivalent) for every family checked so far during this scoping pass.

`response_types` metadata on each mixture class stays identical to its
non-mixture sibling (a Poisson-mixture class is still `response_type =
"count"`). A new capability flag (name TBD at implementation time, e.g.
`is_a_mixture_model()`) marks these classes for `InferenceSuite`/discovery/
the slow-path registry: bootstrap capability only, excluded from the
Wald-path and randomization-CI capability sets in v1 (see "Explicitly
Deferred").

### C. Label switching and bootstrap inference

Bootstrap CIs (nonparametric resampling refit of the full `K`-component EM
per replicate, reusing `Inference$par_lapply`) are meaningless without a
consistent component ordering, since EM has no notion of which fitted
component is "first." A fixed, documented ordering rule is applied
identically to the original fit and every bootstrap replicate *before*
aggregating — default: order components by the treatment-indicator
coefficient `w` when present (the scientifically meaningful axis in this
package's causal-inference context), falling back to the intercept
otherwise (Stephens 2000's general treatment of this problem is the
citation; the specific ordering rule chosen here is simpler than that
paper's full relabeling algorithm, deliberately — a fixed coordinate-based
rule is enough when one coefficient is already privileged, and revisiting
this is one of the "Explicitly Deferred" items below if it proves
insufficient in practice).

### D. Marginal (mixture-weighted) estimand

Beyond the `K` per-component estimates, report one marginal estimand:
`Σ_k π_k · θ_k^(w)`, the population-averaged treatment effect using the
fitted mixing proportions as weights. For an identity-link family this is
a plain weighted average of per-component coefficients; for a nonlinear
link (Poisson, logistic, …), getting this onto the natural probability/
rate scale needs the same transformation `marginal_estimand_report.md`'s
`set_estimand("marginal_*")` machinery already implements — this plan
depends on that machinery rather than re-deriving it (see header). The
marginal estimand's bootstrap CI comes for free: compute it inside each
bootstrap replicate, after the same §C ordering rule, alongside the
per-component estimates.

### E. Model comparison helpers

`BIC = -2·loglik + (num_params)·log(n)` and `ICL = BIC + 2·Σ_i Σ_k r_{ik}
log(r_{ik})` (the entropy penalty — Biernacki, Celeux & Govaert 2000),
both computable generically from any fitted mixture object regardless of
family. No automatic K-search — a user fits a few `K` values and compares
these numbers themselves (decision already made above).

### F. Visualization (added 2026-09-10, from this session's visualization brainstorm)

Three plots, generic across every family since the mixin owns the
orchestration (§B) and therefore already has the fitted `θ_1..θ_K`,
`π_1..π_K`, and per-observation responsibilities `r_{ik}` needed for all
three:

- **Fitted-component-density overlay** — the observed-data histogram
  (or empirical density for a discrete family) with the `K` fitted
  component densities `π_k · density_f(y | θ_k)` overlaid, plus their
  mixture sum — the standard "does this mixture actually look like the
  data" check (McLachlan & Peel 2000's own recommended diagnostic; ch.
  2–3, already cited in this file's header).
- **Classification/responsibility plot** — each observation's `K`
  responsibilities `r_{i·}` as a stacked bar or a scatter colored by
  most-likely component (`argmax_k r_{ik}`), against the treatment
  indicator `w` or a chosen covariate — shows which subjects the mixture
  is confidently assigning vs. which sit ambiguously between components
  (`r_{ik}` near `1/K`).
- **BIC/ICL-vs-`K` comparison plot** — since §E already computes both
  generically and the package's own decision was "no automatic K-search,
  a user compares a few `K` values by hand" (§ "Decisions Already Made"),
  this plot *is* that comparison: BIC and ICL as two lines over the `K`
  values the user actually fit, the human-in-the-loop equivalent of an
  automatic selector.
- All three apply the same §C ordering rule (fixed component labeling)
  before rendering, so a plot from the original fit and one from a
  bootstrap replicate are visually comparable — never showing component 2
  in one panel and component 3 in another for what is statistically the
  same component. Reuses `InferenceSuite`'s ggplot2/HTML/`plotly`
  reporting conventions (`inference_suite_interactive_reporting.md`)
  rather than a new visual language; `plotly`/`DT` interactivity is
  `Suggests`-gated the same way as everywhere else in this codebase.

---

## Explicitly Deferred (not v1, not this plan's problem to solve)

- **Automatic K-selection.** A real, separately-scoped piece of machinery
  (search over a K range, multistart-per-K cost, boundary-of-parameter-
  space testing issues for comparing K vs. K+1). Decided out of v1 above.
- **Asymptotic (Louis' method) standard errors.** Bootstrap-only per the
  decision above; Louis (1982) is the citation if/when this is revisited.
  Known to misbehave near component boundaries even when implemented
  correctly, which is part of why bootstrap was chosen for v1.
- **Randomization-based CIs.** A design-based randomization null under a
  latent-class mixture would require re-running the full multistart EM fit
  per permutation replicate — likely prohibitively expensive, and not
  solved by anything in this plan. A future plan's problem if it's ever
  worth pursuing.
- **Mixture-of-experts (covariate-dependent mixing proportions).**
  Explicitly ruled out of scope by the "general finite mixture regression"
  decision above, not merely postponed — a heavier, more general model
  than what was scoped here.
- **Families needing more than a per-observation density callback** (e.g.
  GLMM/frailty marginal likelihoods, survival with censoring, ordinal) —
  not ruled out, but not audited during this scoping pass either. TODO-1
  at implementation time should say explicitly which families the generic
  driver's two-callback contract actually covers cleanly vs. which need
  their own design extension first.

---

## Implementation Sequencing

Deliberately not broken into TODO-by-TODO steps with test code here (see
the note at the top of this file for why). The shape agreed in this
conversation:

1. **Audit** (mirrors `em_algorithm_zero_inflated_mixtures.md` → TODO-1,
   generalized): for each family in scope, confirm (a) a per-observation
   log-density function exists or can be cheaply added, (b) the existing
   weighted internal fit function is reachable without an R↔C++ round
   trip per EM iteration.
2. **Build the generic driver + mixin once**, proven end-to-end on three
   families spanning genuinely different density shapes: continuous
   (Gaussian/OLS — DeSarbo & Cron 1988's clusterwise-regression case),
   count (Poisson), and proportion (Beta). Multistart, bootstrap,
   label-switching ordering, BIC/ICL, and the marginal estimand (§D) all
   get proven on these three before anything is called done.
3. **Extend to remaining families** as a mechanical repeat of step 2's
   per-family TODO shape, batched (not all in one sitting) — logistic,
   probit, log-binomial, NegBin, robust regression, continuation-ratio,
   and whichever others the step-1 audit clears.
4. **Testing**, per family batch: monotone observed-data log-likelihood
   per EM step (hard invariant, same discipline as the zero-inflated
   plan); recovery on synthetic `K`-component fixtures with known ground
   truth; bootstrap-CI coverage checks; BIC/ICL sanity on deliberately
   over- and under-specified `K`.
5. **Visualization** (added 2026-09-10): §F's three plots, proven on the
   same three families as step 2 before extending with step 3 — cheap
   once the generic driver exists, since all three consume only
   already-fitted `θ`/`π`/`r_{ik}`, no new estimation.

---

## Self-review (2026-09-10)

- **Spec coverage:** every decision made in the scoping conversation (see
  "Decisions Already Made") is reflected in a numbered design section;
  nothing decided was left implicit.
- **Placeholders:** the mixture-model capability flag's exact name is
  explicitly marked TBD (§B) rather than invented and left inconsistent —
  a real open item, not a silent gap.
- **Dependency honesty:** the header's dependency on
  `marginal_estimand_report.md` is stated as "verify the concrete wiring
  landed, don't assume from this conversation" — this scoping pass did not
  itself check that plan's current TODO checkboxes.
- **Scope boundary:** "Explicitly Deferred" exists precisely so this plan
  doesn't quietly grow the mixture-of-experts / auto-K / asymptotic-SE /
  randomization-CI directions later without a fresh decision — each is a
  separate future plan's problem, not this one's, if ever pursued.
