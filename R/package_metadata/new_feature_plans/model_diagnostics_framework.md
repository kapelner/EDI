# `ModelDiagnostics`: Per-Model Assumption Batteries, Registry-Declared

> **Depends on:** `InferenceSuite`'s shipped plumbing (registry discovery,
> per-class failure isolation, `num_cores`, `formulas`, screen/HTML
> reporting) — reused, not duplicated. Sits **above** the numerical
> diagnostics layer (`public_diagnostics_api_spec.md`'s
> `SolverDiagnostics`, v1.1.0) and shares its reporting surface: a user
> should see "converged fine, PH violated" as one row. Split (2026-09-02,
> user decision) from what was briefly one combined plan with
> `model_selection_framework.md` — that sibling consumes this plan's
> check results as assumption gates in its selection table; this plan
> stands alone as the **absolute** half of model criticism ("does this
> model's own assumptions hold"), the sibling is the **relative** half
> ("which candidate fits best"). **Release target: v2.0.0**
> (`release_v2_0_0.md → TODO-6g`); see TODO-1(e) — this is the lighter
> half (no fold/split substrate needed; checks are in-sample) and pulling
> the pilot batteries into a 1.x release is a live option to put to the
> user. (Global ordering: see `_master.md` 5AH.)

Written 2026-09-02 (user proposal: `ModelDiagnostics(des_obj)` giving "a
whole host of model diagnostics for the different offered models, where
each model has different diagnostic checking functions based on its own
specific assumptions," across formulas `~1`, `~.`, `~.*w`,
nonparametrics).

Related:
[post_selection_inference_menu.md](../new_research_ideas/post_selection_inference_menu.md)
— the reference report on honest inference after diagnostics-gated
selection; this plan's `blindable` tags and gate constants (§2) are what
make that report's cheap execution paths mechanically dispatchable.

## 1. Why

`InferenceSuite` reports what every applicable model *estimates*, but
nothing in the package checks whether any model's *assumptions hold* on
this data: no proportional-hazards check for the Cox classes, no
overdispersion check for the Poisson classes, no proportionality check
for the cumulative-logit classes, no calibration or residual diagnostics
anywhere user-visible. The gap matters most where the package's own
estimands lean on the outcome model — the g-computation and
marginal-estimand classes standardize over a fitted outcome model, so
that model's adequacy directly determines the estimate's quality — and
it matters for the suite's transparency story too: a table of forty
estimates is more honest when each row carries evidence about whether
its model believes in itself.

## 2. The architectural centerpiece: checks are declared, not switchboarded

**Classes declare their assumption checks the same way they declare
capabilities.** A new registry field (per class or per component, e.g.
`assumption_checks`) names each check, its applicability conditions, and
its implementation. `ModelDiagnostics$new(des_obj)` discovers applicable
classes exactly as `InferenceSuite` does, then discovers each class's
declared battery from the registry — no hand-maintained mapping from
~140 classes to their checks, and a newly added class brings its own
battery with it or shows up as a typed `no_declared_checks` row (never a
silent omission).

A check returns a **typed result** — statistic, p-value or qualitative
flag, severity, optional plot object — never free text, so the panel
renders uniformly and downstream consumers (the selection sibling's
gates; the HTML report) are mechanical.

Three contract requirements ratified 2026-09-02 (user decision, working
through the post-selection-inference mechanics with the sibling plan —
see its §5):

- **Gate thresholds are declared constants.** Each check's declaration
  carries its disqualification threshold (e.g., "Schoenfeld rejects at
  0.05 → Cox cell disqualified") as a typed field, so the sibling's
  pipeline is a pure, pre-specified function — a requirement for the
  selection-inclusive randomization statistic to be well-defined, and
  the difference between a gate and a judgment call.
- **Every check carries a `blindable` tag.** Covariate-side checks
  (covariate PH, overdispersion, proportionality of covariate effects,
  calibration of the `w`-omitted outcome model) can run
  treatment-blinded; treatment-side checks (the treatment coefficient's
  own PH, adequacy of `~ . * w` interaction cells) inherently see `w`
  and cannot. The tag partitions each battery into a blinded and an
  unblinded tranche; the sibling's `InferencePostSelection` dispatches
  its execution path off this tag mechanically (blinded-tranche-only
  gates keep the free-lunch plain-randomization path; any unblinded
  gate forces the full per-replicate re-run).
- **`likelihood_tier = "none"` classes never disqualify.** Rank/exact
  classes have essentially no parametric assumptions to violate; their
  batteries are empty-or-advisory by construction, which is what lets
  the sibling plan require one as the guaranteed non-empty-qualified-set
  fallback.

Checks run across the same formula grid the sibling plan uses (`~1`,
`~.`, `~.*w`, splines): an assumption can hold under one specification
and fail under another, and the panel should show that per cell.

## 3. Pilot batteries

Full rollout is per-class work tracked like the path audit's per-class
metadata was; the pilot tranche (TODO-3) is:

| Class family | Assumption checks |
|---|---|
| Cox PH / stratified Cox | proportional hazards via scaled Schoenfeld residuals (Grambsch–Therneau); covariate functional form |
| Poisson / quasi-Poisson | overdispersion tests (Cameron–Trivedi); zero-inflation check against the observed zero count |
| Negative binomial / ZINB / hurdle | dispersion-parameter adequacy; mixture-component support |
| Logistic / probit | separation — surfacing the package's **existing internal** `EDI_SEPARATION_THRESHOLD` / `is_separated_coefficient_magnitude()` machinery as a user-visible diagnostic rather than only an internal guard; calibration (Hosmer–Lemeshow-style plus calibration plots); linearity of the link |
| Proportional odds | proportionality/parallel-lines test (Brant); category-collapsibility sanity |
| OLS / robust | residual structure, heteroskedasticity, influence — with the honest caveat, stated in the report, that under HC/sandwich SEs several classical checks matter less for the treatment coefficient |
| Beta / ZOIB / fractional logit | boundary-mass adequacy; precision-submodel checks |
| GEE (quasi tier) | working-correlation adequacy |
| GLMM classes | random-effect distribution and variance-component sanity |

## 4. Boundaries

- **Below**: `SolverDiagnostics` (v1.1.0) owns numerical health —
  convergence, conditioning, identifiability. This plan owns statistical
  assumptions. One shared report (coordinate via TODO-2).
- **Beside**: design-side diagnostics (match quality, reservoir size,
  within-pair distance distributions for the KK designs) are a natural
  adjacent panel but **out of scope** — they diagnose the design, not a
  model; candidate follow-on plan.
- **Sibling**: comparative fit, formula-grid guardrails, CV folds,
  blinding infrastructure, the selection-inclusive randomization test,
  and the pre-specification workflow all live in
  `model_selection_framework.md`. This plan's outputs feed that plan's
  selection table as gates/flags (its TODO decides gate-vs-flag
  semantics).

## 5. The honesty rules still bind

Assumption checking is standard good practice and lower-risk than
selection, but **diagnose-then-switch is data-driven selection through
the back door** (pretest bias). Two rules, inherited from the sibling
plan and enforced here too: (1) checks never display, sort, or gate on
treatment-effect magnitude or significance, and run treatment-blinded
where feasible (`blind = c("omit_w", "mask_w", "none")`, shared
implementation with the sibling); (2) when a diagnostic motivates
switching models, the report routes to the sibling plan's honest exits
(selection-inclusive randomization test, sample splitting 5AE, selective
inference 5AF) rather than to the switched-to model's naive p-value.
Reporting diagnostics *alongside* a prespecified analysis, without
switching, needs no correction and is encouraged — that is this plan's
front-door workflow.

## Tests

- Battery discovery: undeclared class → typed `no_declared_checks` row;
  declared check → typed result shape or typed failure; never silence.
- Known-violation recovery: simulated non-PH hazards, overdispersed
  counts, and non-parallel ordinal lines are flagged by the
  corresponding battery at reasonable power; clean data is not flagged
  at gross excess of nominal size.
- Blinding: with `blind = "omit_w"`, every check result is invariant to
  permuting `w`; with `"mask_w"`, no output object contains the
  treatment coefficient.
- Separation surfacing: the logistic battery's separation row agrees
  with the internal guard's determination on the same fit.
- Failure isolation: one pathological (class × formula × check) cell
  yields a typed status, never an aborted panel.

## TODOs

- [ ] TODO-1: **Decision gate (ask the user, no code).** (a) Registry
  field shape (per class vs. per component) and the typed check-result
  contract; (b) ratify the §3 pilot tranche; (c) severity taxonomy and
  what the HTML report does with each level; (d) `blind` default shared
  with the sibling plan; (e) **release placement of the pilots** — the
  declaration contract plus pilot batteries need no v2.0.0 substrate and
  could ship in a 1.x release ahead of the sibling; confirm or decline.
- [ ] TODO-2: **Declaration contract + shared report surface**: the
  registry field, typed result shape — **including the ratified
  per-check gate-threshold constant and `blindable` tag (§2)** —
  discovery, and one rendering table with `SolverDiagnostics` rows
  (coordinate with `public_diagnostics_api_spec.md`).
- [ ] TODO-3: **Pilot batteries** per §3's table, plus the
  known-violation recovery tests; per-class rollout beyond the pilots
  tracked as its own ledger thereafter.
- [ ] TODO-4: **Formula-grid wiring** (consume the sibling's grid engine
  once it exists, or a minimal local grid if this plan ships first per
  TODO-1(e)).
- [ ] TODO-5: **Reporting**: assumption table, check plots, HTML, and
  the §5 handoff footer.
- [ ] TODO-6: **Documentation**: vignette fronting the
  report-alongside-prespecified-analysis workflow, roxygen, and a
  JSS-manuscript sentence when shipped.

## References

(Repo convention: entries marked `NEEDS VERIFICATION` were supplied from
general knowledge and must be checked against the primary source before
citation in roxygen/`REFERENCES.md`.)

- Box, G. E. P. (1980). "Sampling and Bayes' inference in scientific
  modelling and robustness." *JRSS-A*, 143(4), 383–430. (Model criticism
  umbrella.) `NEEDS VERIFICATION`.
- Grambsch, P. M., and Therneau, T. M. (1994). "Proportional hazards
  tests and diagnostics based on weighted residuals." *Biometrika*,
  81(3), 515–526. `NEEDS VERIFICATION` (pages).
- Brant, R. (1990). "Assessing proportionality in the proportional odds
  model for ordinal logistic regression." *Biometrics*, 46(4),
  1171–1178. `NEEDS VERIFICATION`.
- Cameron, A. C., and Trivedi, P. K. (1990). "Regression-based tests for
  overdispersion in the Poisson model." *Journal of Econometrics*, 46,
  347–364. `NEEDS VERIFICATION`.
- Hosmer, D. W., and Lemeshow, S. (1980). "Goodness of fit tests for the
  multiple logistic regression model." *Communications in Statistics —
  Theory and Methods*, A9(10), 1043–1069. `NEEDS VERIFICATION`.
- Madigan, D., Ryan, P. B., and Schuemie, M. (2013) — already
  `[MadiganRyanSchuemie2013]` in `REFERENCES.md` (the honesty framing).
