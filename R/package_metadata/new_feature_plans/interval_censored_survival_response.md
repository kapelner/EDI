# Interval-Censoring Support for the `survival` Response Type

## Scope

`response_type = "survival"` already supports right-censoring (`dead = 0`
meaning "true time is `>= y`"). This document plans a further extension:
**interval censoring**, where the true event time is known only to lie in
`(L, R]` — the event is known to have happened *between* two observation
times, not continuously monitored. This is common in periodic-visit
clinical trials (see Appendix) and is materially different from
right-censoring, which is why it's split out into its own plan rather than
folded into `censored_count_response.md`'s or
`censored_continuous_response.md's` right-censoring work.

This document was previously referenced (but never written) as
`package_metadata/interval_censored_survival_response_type_report.md` from
`package_metadata/new_feature_plans/response_types_landscape_report.md`'s
TODO-8 — that file does not exist in the repository today (confirmed via
`ls package_metadata/new_feature_plans/ | grep -i interval`, which returns
nothing before this document). This plan fulfills that dangling reference
under a slightly different name; TODO-0 below is to fix the stale
cross-reference in the landscape report.

## Current State

`Design` stores exactly one scalar `y` and one binary `dead` flag per
subject:

- `R/EDI/R/design_abstract.R:127-130` allocates `private$y`,
  `private$y_original`, `private$w`, and `private$dead` — one number each
  per subject, no room for a second bound.
- `R/EDI/R/design_abstract.R:174-197` (`add_one_subject_response`) and
  `R/EDI/R/design_abstract.R:203-233` (`add_all_subject_responses`) are the
  only two places responses enter the system; both accept a single `y` and
  a single `dead` per subject.
- `InferenceSurvivalCoxPHRegr`'s kernel
  (`R/EDI/R/inference_survival_coxph.R:2-12`, `.fit_survival_coxph_kernel`)
  builds `survival::coxph(Surv(y, dead) ~ ...)` — the standard `survival`
  package's `coxph()` accepts `Surv()` objects with `type = "interval2"`
  input, but `coxph()`'s own Breslow/Efron partial-likelihood machinery
  does not extend to interval-censored response data; feeding it
  interval-typed `Surv()` data errors.
- `InferenceSurvivalWeibullRegr`'s kernel, `WeibullAFTLikelihood`
  (`R/EDI/src/fast_weibull_regression.cpp:20-84`), is a from-scratch
  closed-form MLE (not a call into the `survival` package), so it isn't
  blocked by any third-party library limitation — it's blocked only by
  the same `assertNoCensoring`-adjacent single-`y`/`dead` schema everything
  else is blocked by, and by not yet having an interval-likelihood branch.
- Every concrete survival `Inference*` class either builds directly on
  `survival::coxph()`/`survival::survfit()`/`survival::survdiff()` (Cox,
  stratified Cox, KM-diff, log-rank, Gehan-Wilcoxon, RMST) or on the
  from-scratch Weibull kernel (`InferenceSurvivalWeibullRegr` and its KK
  frailty/marginal variants) — none currently accept a second time bound.

Right-censoring is *already supported* everywhere in this family (that's
what `dead` already does); this document is specifically about extending
past right-censoring to genuine intervals.

## Proposed Schema Change

**Revision note**: an earlier draft of this section proposed a two-phase
design — a `dead`+`alive` flag pair first, a `y_R` numeric bound
second. That's superseded by a single unified schema below, for two
reasons. First, a real bug: the `dead`+`alive` design reused `dead = 1` to
mean both "exact time known" (today's meaning) and "confirmed dead by `y`"
(the proposed left-censored meaning) — any code reading `private$dead`
directly without also checking `alive` (which is most of the existing
codebase; `inference_survival_weibull.R` and `inference_survival_coxph.R`
both thread `private$dead` straight into kernel calls) would silently
misread a left-censored row as an exact event. Second, an efficiency
argument: two booleans can only ever encode four discrete combinations,
not an arbitrary second real number, so the two-sided interior-interval
case (periodic-visit oncology PFS data — this document's own primary
motivating example) still needed a numeric bound regardless — meaning the
flag-only "Phase 1" wasn't actually saving engineering effort, just
staging a representation that would need migrating away from later.

**The schema**: replace `y` + `dead` with `y`, `y_L`, `y_R`. `y` means
exactly one thing — "the true point value" — and nothing else. If there
is *any* censoring at all, `y` is `NA`, full stop, and both bounds must be
given explicitly:

- **Exact**: `y = <value>`, `y_L = NA`, `y_R = NA`.
- **Right-censored** (today's existing capability): `y = NA`, `y_L =
  <value>`, `y_R = Inf`. The caller must write `y_R = Inf` explicitly —
  there is no default.
- **Left-censored** (new): `y = NA`, `y_L = 0`, `y_R = <value>`. The
  caller must write `y_L = 0` explicitly. This is a deliberate design
  choice, not an oversight: forcing the domain floor to be stated rather
  than silently defaulted is a reminder of what's actually being assumed
  (a real floor at `0`), and removes an entire class of "did the code
  default this correctly" bugs.
- **Interval-censored** (new — the PFS case): `y = NA`, `y_L =
  <lower>`, `y_R = <upper>`, both finite.
- **Not yet recorded**: `y = NA`, `y_L = NA`, `y_R = NA`.

So whenever there's any censoring, `y_L` and `y_R` are both **required**
— no implicit defaults for either bound, in either direction. `y` and
`y_L`/`y_R` are never simultaneously populated; exactly one side is used.

`y_L`, `y_R` are a new pair of per-subject numeric fields, allocated the
same `O(n)` way `dead` is today at `design_abstract.R:130`, both
defaulting to `NA`. `dead` is no longer a stored field.

**Consequence — this is a bigger migration than earlier drafts of this
document scoped, and that needs to be said plainly rather than glossed
over.** Right-censoring is *already* fully supported across every
survival `Inference*` class today, not just the ones this document is
actively upgrading — all ~17 survival files (`inference_survival_coxph.R`,
`inference_survival_strat_cox.R`, `inference_survival_log_rank.R`,
`inference_survival_gehan_wilcox.R`, `inference_survival_km_diff.R`,
`inference_survival_rmst.R`, `inference_survival_dep_cens_transform.R`,
`inference_survival_weibull.R`, and every KK survival variant) read
`private$y` directly today to get a right-censored subject's last-known
time. Under this schema, that value moves to `y_L` and `y` becomes `NA`
for those rows. Every one of those files needs a small compatibility
update — not just the 2-3 files (`inference_survival_weibull.R`,
`inference_survival_coxph.R`) this document was already planning to
touch for new capability. See "Migration: every survival class needs
updating" and TODO-1a below.

**The upside**: this actually *simplifies* the Weibull kernel. With
`y_L`/`y_R` always explicit and never defaulted, right-censoring
(`y_R = Inf`) and left-censoring (`y_L = 0`) both reduce algebraically to
the same general formula as interval-censoring —
`log(S(y_L) - S(y_R))` — since `S(Inf) = 0` and `S(0) = 1`. There's no
longer a need for a separate right-censored branch, a separate
left-censored branch, and a separate interval branch: it's just "exact"
(density term) vs. "censored" (the one `S(y_L) - S(y_R))` formula, for
every flavor of censoring at once. See the revised TODO-3.

`any_censoring()` (`design_abstract.R:300-301`) simplifies to
`any(is.na(private$y))` — every flavor of censoring now leaves `y`
unset, so this one check covers all of them. `Design`'s "has this
subject's response arrived" bookkeeping —
`assert_all_responses_recorded()`/`check_experiment_completed()`
(`design_abstract.R:260-279`) and the overwrite-warning check in
`add_one_subject_response` — changes from testing `is.na(private$y)`
alone to testing `is.na(private$y) & is.na(private$y_L) &
is.na(private$y_R)` as "not yet recorded." Every existing
`assertNoCensoring(private$any_censoring)` call site across every
response family in this repository — survival, count, continuous; this
fix isn't survival-specific — is automatically and correctly strengthened
to refuse left- and interval-censored data too, with zero code changes at
*those* call sites (they only ever call the function, never read the
underlying fields directly) — the code-change burden is entirely in the
survival files that read `private$y` for a *value*, covered above.

**No public-API backward compatibility needed**: nobody outside this
repository is using the package yet. `add_one_subject_response`'s `dead`
argument and `add_all_subject_responses`'s `deads` argument are removed
and replaced by `y_L`/`y_Ls` and `y_R`/`y_Rs` (both default `NULL`).
`get_dead()` (`design_abstract.R:361`) is removed; `get_y_L()` and
`get_y_R()` are added.

This maps onto the standard `(time1, time2)` interval-censoring
representation `survival::Surv(time1, time2, type = "interval2")` uses,
and the shape `icenReg`/`interval` (this document's Tier 2 delegation
targets) expect as input — worth double-checking the exact sentinel
conventions those functions use for the right-/left-censored edge cases
against their documentation during implementation.

## Migration: Every Survival Class Needs Updating

Add two shared, single-source-of-truth accessors rather than have every
survival file re-derive this logic independently:

- `Design$get_effective_time()`: `ifelse(is.na(private$y), private$y_L,
  private$y)` per subject — reconstructs "the one number `private$y` used
  to hold" for exact and right-censored rows.
- `Design$get_effective_dead()`: `as.integer(!is.na(private$y))` per
  subject — reconstructs today's `dead`: `1` for exact, `0` for
  right-censored.

**Important**: this pair only correctly reconstructs today's behavior for
exact/right-censored data. Fed a left- or interval-censored row, both
accessors return numbers (`get_effective_time()` returns `0` for a
left-censored row, since `y_L = 0` there; `get_effective_dead()` returns
`0`, indistinguishable from ordinary right-censoring) that are silently
*wrong* if passed to `Surv(time, status)`-shaped code expecting simple
right-censoring semantics. So every survival class not being upgraded to
handle the general case (i.e. everything except
`inference_survival_weibull.R`/`inference_survival_coxph.R`) needs *two*
changes, not one: (1) add an `assertNoCensoring`-equivalent guard refusing
left-/interval-censored data — which, unlike the count/continuous/
proportion families, survival's own classes don't call today at all,
since they've never needed to refuse censoring before — and (2) swap
`private$y`/`private$dead` for the two accessors above. Both are
mechanical, identical in shape everywhere, and the *numbers* produced for
existing right-censored data are unchanged (the accessors return exactly
what `private$y`/`private$dead` used to hold for those rows) — so the
zero-regression claim still holds at the level of "output is
bit-identical," even though it no longer holds at the level of "zero
lines touched."

Implementation should land incrementally even though the schema covers
every case at once: get the migration verified bit-identical on today's
exact/right-censored data first (TODO-1a), then interval-censoring, then
left-censoring — that's a testing/sequencing decision, not a second
schema design; see TODOs below.

## Zero-Regression Design Principle

Revised from the sibling plans' shape, given the migration above — the
"zero regression" guarantee here is about output correctness, not about
zero code touched:

1. **Design layer**: `y_L`/`y_R` default to `NA`, so every existing
   response-storage *call site* (constructing a `Design`, e.g.
   `add_one_subject_response(t, y = 12.3)`) behaves identically; the only
   new cost is allocating two more `NA`-filled vectors per `Design`, the
   same `O(n)` one-time cost `dead` already has.
2. **R inference layer**: every survival class needs the two-part
   migration described above (add a censoring guard where one didn't
   exist before; swap `private$y`/`private$dead` for
   `get_effective_time()`/`get_effective_dead()`). This is genuinely new
   work, not a zero-change guarantee — but it's mechanical, identical in
   shape across every file, and provably output-preserving: the
   accessors return the exact same numbers `private$y`/`private$dead`
   used to for exact/right-censored data, so a regression test comparing
   before/after on every existing test dataset should show bit-identical
   results. For the non-survival response families (count, continuous,
   proportion), the guarantee from the sibling plans still holds
   unchanged: `assertNoCensoring(private$any_censoring)` call sites there
   need zero changes, since `any_censoring()`'s definition changing
   underneath them only makes the guard stricter, never touches the call
   site itself.
3. **Engine layer**: interval and left-censoring support is added as a
   *new, separate* code path per engine (a new C++ likelihood branch for
   Weibull; a dispatch to a different R package for Cox/KM-family
   estimators — see below), never as a modification to the numeric
   result for exact/right-censored data. This mirrors
   `censored_continuous_response.md`'s point about `InferenceContinOLS`:
   when there's no natural in-place branch (because the existing solver is
   closed-form, or because it's a call into a third-party library that
   doesn't support interval data), the correct zero-regression strategy is
   a top-level dispatch, not a hot-path edit.

Net effect: every survival file gets a small, uniform, output-preserving
migration (new cost, but bounded and mechanical); every non-survival
response family gets strictly stronger correctness for free; an
interval-censoring-unaware `Design` pays two extra `NA`-filled vector
allocations and nothing else numerically.

## An Important Reframing Versus The Old "Hard" Verdict

`response_types_landscape_report.md`'s TODO-8 rated the semiparametric
Cox-analogue as **hard**, reasoning that "Cox partial likelihood has no
interval-data extension; needs a new NPMLE/EM engine." That's true as
stated, but it undersells how much of that engine already exists —
**outside this package**:

- `icenReg::ic_par()` fits parametric (including Weibull) interval-censored
  regression; `icenReg::ic_sp()` fits a semiparametric Cox-analogue via a
  fast NPMLE-based algorithm, described by its author as roughly 1000x
  faster than earlier competing interval-censored-Cox algorithms.
- The `interval` package (Fay & Shaw) provides `icfit()` (Turnbull NPMLE,
  the interval-censored analogue of `survfit()`/Kaplan-Meier) and
  `ictest()` (generalized log-rank and generalized Wilcoxon two-/k-sample
  tests for interval-censored data) — `icenReg`'s own documentation
  explicitly defers to the `interval` package for this kind of formal
  testing rather than reimplementing it.

So the real cost of this project is **not** "write an NPMLE/EM solver from
scratch in C++." It's: (a) the `Design`-layer schema change above, and (b)
glue code that hands `(L, R, X)` off to these existing, mature CRAN
packages and reshapes their output into this package's `compute_estimate`/
`compute_asymp_confidence_interval`/`compute_asymp_two_sided_pval` contract
— the same shape of "delegate to an existing R package" move
`censored_continuous_response.md` proposes for
`InferenceContinQuantileRegr` via `quantreg::crq()`. That reframes the Cox
and KM-family engines from "hard, needs new numerical-methods R&D" to
"moderate, needs integration engineering plus a new dependency."

## Feasibility By Inference Type

There are 24 concrete survival `Inference*` classes across roughly 6
architectural families (many are IVWC/OneLik KK-matched-design pairs
wrapping the same base engine).

### Tier 1 — Feasible now, closed-form extension

- **`InferenceSurvivalWeibullRegr`** (`R/EDI/R/inference_survival_weibull.R`)
  — `WeibullAFTLikelihood` (`R/EDI/src/fast_weibull_regression.cpp:20-84`)
  already computes a Weibull survivor function `exp(-exp(w))` internally
  (`m_exp_w`); the interval-censored contribution is simply
  `log(S(L) - S(R)) = log(exp(-exp(w_L)) - exp(-exp(w_R)))`, with `w_L`,
  `w_R` computed from the same `eta`/`sigma` the existing code already
  derives. Score/Hessian follow by the same chain rule already used for the
  exact/right-censored cases, just applied twice (once per bound) and
  differenced — more algebra, same closed-form shape, no new numerical
  method. This is the shortest path to a real interval-censored engine in
  the package.

### Tier 2 — Moderate, rides on Tier 1 or on delegated CRAN packages

- **`InferenceAbstractKKWeibullFrailtyIVWC`/`OneLik`** and their concrete
  `InferenceSurvivalKKWeibullFrailtyIVWC`/`OneLik`
  (`R/EDI/R/inference_survival_KK_weibull_frailty.R`), and
  **`InferenceSurvivalKKWeibullMarginal`**
  (`R/EDI/R/inference_survival_KK_weibull_marginal.R`) — all built on the
  same Weibull kernel as Tier 1. The frailty variants add a random-effect
  integral on top (similar in shape to the count/continuous plans'
  GLMM discussion), so treat as riding on Tier 1 but requiring their own
  integration-layer verification pass, not a guaranteed free inheritance.
- **`InferenceSurvivalCoxPHRegr`** (`R/EDI/R/inference_survival_coxph.R`)
  and **`InferenceSurvivalStratCoxPHRegr`**
  (`R/EDI/R/inference_survival_strat_cox.R`) — dispatch to `icenReg::ic_sp()`
  when there's censoring beyond plain right-censoring
  (`any(is.finite(private$y_R))` — under this schema, `y_R` is finite
  *only* for left- or interval-censored rows: exact rows have `y_R = NA`
  and right-censored rows have `y_R = Inf`, neither of which is finite —
  so this is `FALSE` when every censored row is still simple
  right-censoring, which keeps using the existing, faster
  `survival::coxph()` path unchanged; stratification maps onto
  `icenReg`'s own strata support). New dependency (`icenReg`), new glue
  code to reshape `ic_sp()`'s fit into this package's coefficient/SE/CI
  contract, but no new numerical method to invent.
- **`InferenceSurvivalLogRank`** (`R/EDI/R/inference_survival_log_rank.R`),
  **`InferenceSurvivalGehanWilcox`**
  (`R/EDI/R/inference_survival_gehan_wilcox.R`) — dispatch to
  `interval::ictest()` (generalized log-rank / generalized Wilcoxon) under
  the same left-/interval-censoring trigger as above, keep
  `survival::survdiff()`-based paths untouched otherwise. New dependency
  (`interval`), moderate glue code.
- **`InferenceSurvivalKMDiff`** (`R/EDI/R/inference_survival_km_diff.R`)
  and **`InferenceSurvivalRestrictedMeanDiff`**
  (`R/EDI/R/inference_survival_rmst.R`) — dispatch to `interval::icfit()`
  (Turnbull NPMLE survival curve) in place of `survival::survfit()` when
  interval-censored; RMST becomes the area under the Turnbull curve instead
  of the Kaplan-Meier curve, a well-defined generalization, but the
  variance/CI machinery needs its own derivation or a bootstrap fallback
  since `icfit()` doesn't hand back the same summary object shape
  `survfit()` does.
- **`InferenceSurvivalKKLWACoxPHIVWC`/`OneLik`** (+ their
  `InferenceAbstractKKLWACoxIVWC`/`InferenceAbstractKKLWACoxOneLik` bases,
  `R/EDI/R/inference_survival_KK_lwa_cox.R`,
  `inference_survival_KK_lwa_cox_ivwc_abstract.R`,
  `inference_survival_KK_lwa_cox_one_lik_abstract.R`) and
  **`InferenceSurvivalKKStratCoxPHIVWC`/`OneLik`**
  (`R/EDI/R/inference_survival_KK_strat_cox.R`) — inherit whatever tier
  plain Cox lands in above; the "OneLik" variants likely need only a
  censoring-aware combined design/model call into the same delegated
  `icenReg` fit, "IVWC" variants need the matched-set and reservoir
  sub-estimates to each independently support interval censoring before
  the inverse-variance combination step (same asymmetry the continuous
  plan found between its own OneLik/IVWC pairs) — verify during
  implementation.

### Tier 3 — Hard, structural, second-wave

- **`InferenceSurvivalDepCensTransformRegr`**
  (`R/EDI/R/inference_survival_dep_cens_transform.R`) — already handles a
  *different* hard problem (dependent right-censoring, via a transform
  regression approach). Whether/how dependent censoring and interval
  censoring compose is a genuine open modeling question, not an engineering
  question — needs its own dedicated scoping pass before any TODO is
  written.
- **`InferenceSurvivalKKClaytonCopulaIVWC`/`OneLik`**
  (`R/EDI/R/inference_survival_KK_clayton_copula.R`) — copula-based
  *dependent*-censoring model for matched pairs. Same composition problem
  as the transform-regression case above, compounded by the copula's own
  matched-pair joint-survival structure — flag as needing its own
  feasibility report, not folded into this one.
- **`InferenceSurvivalKKRankRegrIVWC`**
  (`R/EDI/R/inference_survival_KK_rank_regr.R`) and
  **`InferenceAbstractKKSurvivalRankRegrIVWC`**
  (`R/EDI/R/inference_survival_KK_rank_regr_ivwc_abstract.R`) — rank-based
  (Gehan-type) AFT regression. Rank-based interval-censored AFT estimators
  exist in the literature but are considerably more specialized than the
  Cox/KM delegation targets above, with no single dominant R-package
  function to lean on the way `icenReg`/`interval` cover the other
  families — needs its own scoping pass.

## TODOs

### Prerequisite

- [x] TODO-0: Fix the stale cross-reference in
  `package_metadata/new_feature_plans/response_types_landscape_report.md`'s
  TODO-8, which points at
  `package_metadata/interval_censored_survival_response_type_report.md` (a
  file that was never created) — repoint it at this document. **Done** —
  `response_types_landscape_report.md`'s TODO-8 now names this document's
  real filename and its revised (more tractable) verdict.
- [x] TODO-1: Replace `Design`'s `y` + `dead` storage with `y`, `y_L`,
  `y_R` (`design_abstract.R` field allocation; `y_L`, `y_R` new, both
  default `NA`, allocated the same `O(n)` way `dead` was). `y` is
  populated only for exact values now — never simultaneously with
  `y_L`/`y_R`. `check_experiment_completed()`/
  `assert_all_responses_recorded()` redefined to test
  `is.na(y) & is.na(y_L) & is.na(y_R)` as "not yet recorded."
  `any_censoring()` redefined as `any(is.na(y))`. `dead`/`deads` removed
  from `add_one_subject_response`/`add_all_subject_responses`, replaced
  with `y_L`/`y_Ls` and `y_R`/`y_Rs` (both required together, no partial
  supply); `get_dead()` removed, `get_y_L()`/`get_y_R()` added.
  `Design$get_effective_time()`/`get_effective_dead()` added. **Important
  correction made during implementation**: the initial cut only gated
  left-censoring (`y_L == 0`) with `stop("Left censoring is not
  implemented yet.")`, mirroring what this document originally said —
  but that left a real correctness bug, not just a scope gap. Since no
  engine (Weibull, Cox/KM delegation) has been extended yet, general
  interval-censored input (`y_L` finite `> 0`, `y_R` finite) would have
  passed the gate silently, then had `get_effective_time()`/
  `get_effective_dead()` silently collapse it to "right-censored at
  `y_L`," discarding the upper bound with no error. Fixed: the gate now
  blocks *any* finite `y_R` (both left- and interval-censored input),
  not just the `y_L == 0` case — only `y_R = Inf` (today's right-censoring)
  and exact responses are currently accepted. This also updated
  `design_fixed_abstract.R`'s own `add_all_subject_responses` override
  (same pattern), and a real bug found along the way in
  `design_seq_one_by_one_KK21.R`'s survival-weight computation, which
  filtered subjects via `which(!is.na(private$y))` — under the new
  schema this would have silently dropped every censored subject from
  weight computation; fixed to use the three-field presence check.
  **Follow-up correction (found post-hoc, not during the original TODO-1
  pass):** this gate was itself wrapped in `if (should_run_asserts())`,
  same as every ordinary type-check in `add_one_subject_response`/
  `add_all_subject_responses`. That's the wrong risk class for this
  particular check: an ordinary assert's failure mode when disabled is a
  cryptic downstream error (the documented, accepted tradeoff of
  `toggle_asserts(FALSE)`); this gate's failure mode when disabled is
  *no error at all* — left-/interval-censored data is stored silently and
  `get_effective_time()`/`get_effective_dead()` silently misread it as
  ordinary right-censoring, exactly the corruption this gate exists to
  prevent. And `SimulationFramework$run()` — the exact machinery TODO-2
  audited — sets `turn_off_asserts_for_speed = TRUE` **by default**, so
  this hole was live in the common case, not just an opt-in performance
  mode. Confirmed empirically (`toggle_asserts(FALSE)`; `add_all_subject_responses`
  with `y_L = 0, y_R = 5` was accepted with no error, and
  `get_effective_time()`/`get_effective_dead()` returned `0`/`0` — silently
  wrong). Fixed by pulling the shape/censoring-rejection checks (both
  `add_one_subject_response` and `add_all_subject_responses` in
  `design_abstract.R`, and `add_all_subject_responses` in
  `design_fixed_abstract.R`) out from under `should_run_asserts()` so they
  always run; the ordinary type/length/domain checks (`assertNumeric`,
  `assertCount`, `assert_y`) stay inside it, unchanged. Verified: the
  reproduction above now errors with assertions off; normal exact/
  right-censored data is unaffected with assertions off; both
  `test-designs.R` and the assertion-toggle test suite
  (`test-runtime-argument-combination-assertions.R`) still pass; the
  Weibull/`DesignFixediBCRD`/`DesignSeqOneByOneBernoulli` simulations from
  TODO-2's verification still run end-to-end under
  `SimulationFramework`'s default (asserts-off) mode.
- [x] TODO-1a: Superseded by how TODO-1 actually landed. The original
  plan was to add a per-file censoring guard to each of the ~17 survival
  `Inference*` files and swap each file's `private$y`/`private$dead`
  reads individually. Turned out to be unnecessary: (a) the censoring
  guard is enforced once, centrally, at data entry
  (`add_one_subject_response`/`add_all_subject_responses`) — no survival
  `Inference*` class can ever construct with left-/interval-censored
  data in the first place, so no per-class guard is needed; (b)
  `private$y`/`private$dead` turned out to be populated in exactly one
  place across the entire `Inference` class hierarchy — the shared base
  `Inference$initialize()` in `inference_all_abstract.R` — not
  independently re-derived per survival file as originally assumed, so
  fixing that one assignment (`private$y = des_obj$get_effective_time()`,
  `private$dead = des_obj$get_effective_dead()`) fixed every downstream
  survival file automatically, including the randomization-inference
  worker-mirroring code in `inference_all_abstract_rand.R` and
  `inference_mixin_kk_passthrough.R`, which only ever propagate that
  already-correct cached value and never re-read the design object
  directly. Remaining: a regression-test pass confirming every existing
  exact-time and right-censored survival test case is bit-identical
  before/after (not yet run — blocked on this repo's pre-existing,
  unrelated C++ build failure, not on anything in this migration).
- [x] TODO-2: Audit bootstrap/permutation/randomization-inference paths
  that resample or copy `y`/`dead` together for `survival` designs to
  confirm `y_L`/`y_R` need to be threaded through in lockstep too —
  mirrors the count and continuous plans' equivalent TODO-2s, but this one
  is genuinely new work (not just a verification pass) since `y_L`/`y_R`
  replace, not reuse, the existing `dead` storage. **Done** — two separate
  findings:
  1. *Design- and Inference-layer resampling is already correct, no change
     needed.* `Design$resample_assignment()` (`design_abstract.R:606-615`,
     the only implementation, called from `InferenceRand`) already
     resamples `y`, `y_original`, `y_L`, and `y_R` in lockstep with `w`.
     Every Inference-layer bootstrap/permutation path that resamples or
     copies response data (`InferenceMixinKKPassThrough`'s reusable-worker
     and non-reusable bootstrap loops in `inference_mixin_kk_passthrough.R`,
     `InferenceRand`'s permutation machinery in
     `inference_all_abstract_rand.R`, and every survival class's
     `compute_fast_rand_bootstrap_distr`/`compute_estimate_with_bootstrap_weights`
     C++ dispatchers) only ever reads/writes `private$y`/`private$dead` on
     `Inference` objects, never `y_L`/`y_R` directly — because, per
     TODO-1a, those two fields are populated exactly once, in
     `Inference$initialize()`, via `get_effective_time()`/
     `get_effective_dead()`. Since TODO-1's Design-layer guard currently
     refuses any survival response with a finite `y_R` (left- or
     interval-censored), no `Inference` object can exist today whose
     `y_L`/`y_R` would need threading through a resample — the accessors'
     "only valid for exact/right-censored data" caveat is always satisfied
     by construction. This will need revisiting *inside* the same TODO-4
     (Weibull)/TODO-9 (Cox/KM-family) work that lifts the guard for each
     engine, not as extra work here — flagging it there would be
     premature since the shape of what needs threading depends on how each
     engine consumes `y_L`/`y_R`.
  2. *A real, separate bug, found by tracing every remaining production
     call site of `add_one_subject_response`/`add_all_subject_responses`
     (`grep`, not the audit's original target list): `simulations_framework.R`'s
     Monte Carlo replication engine — the actual "generate many synthetic
     experiments and run randomization/bootstrap inference over each"
     driver this package ships — was never migrated off the pre-TODO-1
     `(y, dead)` contract.* Six call sites (both the closure-based
     `SimulationFramework$run()`-adjacent code and the parallel R6-private
     `.apply_treatment_and_noise`/design-building method) forwarded the
     legacy DGP output positionally as
     `add_one_subject_response(t, out$y, out$dead)` /
     `add_all_subject_responses(out$y, out$dead)`. Under the new signature
     `(t, y, y_L, y_R)` that silently rebinds `out$dead` to the `y_L`
     parameter instead of erroring at the call site — and then *does*
     error at runtime (`"y_L was supplied without y_R"`) the moment any
     survival replicate is generated, censored or not, since `y_L` alone
     is never legal. This made every survival Monte Carlo simulation
     through `SimulationFramework` (fixed-design, sequential
     `DesignSeqOneByOne`, and the `custom_dgp`/Mode 3 observational path)
     immediately fail. Fixed by adding a small bridging helper,
     `dead_to_response_bounds()` (`simulations_framework.R`, right after
     `get_r6_init_fn`), that converts the DGP's `(y, dead)` output into
     `(y, y_L, y_R)` at the boundary — `dead == 1` maps to plain `y`,
     `dead == 0` maps to `y_L = y, y_R = Inf` — and a second helper,
     `add_bounded_response_to_design()`, needed because
     `add_one_subject_response()` (unlike its vectorized sibling) treats
     any non-`NULL` argument as "supplied" even when it's `NA`, so the
     single-subject call sites must convert the unused bound to actual
     `NULL` rather than pass `NA_real_` through. Both the DGP contract
     itself (`apply_treatment_and_noise_cpp`, and the public
     `custom_apply_treatment_and_noise` extension point) are left
     unchanged — they're an established `(y, dead)`-shaped interface
     independent of `Design`'s internal storage, and every non-survival
     response type always returns `dead == 1` (`simulation_dgp.cpp:44`),
     so the conversion is a no-op there. Also removed one now-dead
     `priv$dead = rep(1L, n)` line (a validation-only fast path with no
     remaining reader) and fixed one stale test
     (`test-designs.R`'s "Response types work") still calling the removed
     `dead =` argument and `get_dead()` accessor. Verified: fixed-design,
     sequential, and `custom_dgp` survival simulations with
     `prob_censoring > 0` all run end-to-end post-fix
     (`InferenceSurvivalWeibullRegr` over `DesignFixediBCRD`/
     `DesignSeqOneByOneBernoulli`), and `test-simulation-framework-extended.R`'s
     pre-existing (unrelated, non-survival) failures are unchanged
     before/after this fix.

### Tier 1 — Weibull AFT

- [ ] TODO-3: Extend `WeibullAFTLikelihood`
  (`R/EDI/src/fast_weibull_regression.cpp:20-84`) with a single censored
  branch replacing today's `dead`-based one: `log(S(y_L) - S(y_R))`,
  valid uniformly for right- (`y_R = Inf`, reduces to today's `log(S(y_L))`
  since `S(Inf) = 0`), left- (`y_L = 0`, reduces to `log(1 - S(y_R))`
  since `S(0) = 1`), and interval-censored rows alike — no per-flavor
  branching needed inside the kernel, since `y_L`/`y_R` are always
  explicit numbers under this schema, never defaulted. The
  corresponding score/Hessian derived by differencing the existing
  per-bound derivative terms. Only two top-level branches needed: exact
  (`y` non-`NA`, density term, unchanged) vs. censored (`y_L`/`y_R`
  populated, the one formula above). Verify the right- and left-censored
  algebraic reductions numerically against the existing (pre-migration)
  Weibull test suite rather than just trusting the algebra.
- [ ] TODO-4: Thread `y_L`/`y_R` from `InferenceSurvivalWeibullRegr`
  (`inference_survival_weibull.R`) into the extended kernel; remove or
  relax whatever interval-censoring guard is added alongside TODO-1a.
- [ ] TODO-5: Add interval-censored unit tests (point-estimate recovery
  against simulated interval-censored Weibull data) and a benchmark
  confirming the exact/right-censored paths are unchanged.

### Tier 2 — Cox / KM-family via delegation

- [x] TODO-6: Add `icenReg` as a `Suggests`-style optional dependency
  (matching how `glmmTMB`/`quantreg` are already conditionally required
  elsewhere in this package via `check_package_installed()`). Implement
  the `icenReg::ic_sp()` dispatch path for `InferenceSurvivalCoxPHRegr`
  and `InferenceSurvivalStratCoxPHRegr`, reshaping its fit into this
  package's coefficient/SE/CI contract. Confirm how `y_L = NA` (a
  left-censored row) needs to be encoded for `ic_sp()`'s input format —
  don't assume it's handled without checking. **Done for
  `InferenceSurvivalCoxPHRegr`; `InferenceSurvivalStratCoxPHRegr`
  deliberately deferred** (see below) — landing one class correctly beat
  landing two hastily.

  **Dependency.** `icenReg` added to `Suggests` (plain CRAN, no transitive
  Bioconductor dependency, unlike `interval`/`Icens` — see TODO-7).
  `assert_icenreg_installed()` added to `other_helpers.R`, mirroring
  `assert_blocktools_installed()`'s pattern.

  **The guard had to move, not just relax.** TODO-1's Design-layer gate
  refused *any* finite `y_R` for *every* survival class, since Design has
  no way to know in advance which `Inference` class will consume the data
  — that blanket refusal was the only thing making the central-guard
  design in TODO-1a's note safe. Landing real interval-censoring support
  for even one class meant this had to become a per-class capability
  check instead of a blanket refusal, or every other not-yet-updated
  survival class would have silently regressed back to the exact bug
  TODO-1a fixed. Concretely: `Design`'s "not implemented yet" stops
  (`design_abstract.R`, `design_fixed_abstract.R`) are gone — storage now
  accepts any well-formed left-/interval-censored response for any
  survival `Design`, structural checks (`y_L` finite `>= 0`, `y_R > y_L`)
  aside. In their place: `Design$has_general_censoring()` (peer to
  `any_censoring()`: `any(is.finite(private$y_R))`, `TRUE` only for left-/
  interval-censored rows since right-censored rows have `y_R = Inf`), and
  a new capability check in the shared `Inference$initialize()`
  (`inference_all_abstract.R`) — `private$supports_interval_or_left_censored_data()`
  (default `FALSE` on the `Inference` base class) is checked once,
  centrally, exactly where TODO-1a's original guard lived, and `stop()`s
  with a clear per-class message if a class without that capability is
  constructed against a Design carrying general censoring. `private$y_L`/
  `private$y_R` are now threaded into every `Inference` object alongside
  `private$y`/`private$dead` (harmless `NA`s for classes that never
  populate them). Verified: `InferenceSurvivalWeibullRegr` and
  `InferenceSurvivalKMDiff` both still correctly reject interval-censored
  data with a clear error (the exact TODO-1a protection, now enforced one
  layer up); ordinary exact/right-censored data is completely unaffected
  (confirmed via existing test suites, not just spot checks).

  **The dispatch itself.** `InferenceSurvivalCoxPHRegr` overrides
  `supports_interval_or_left_censored_data()` to `TRUE` and gets a new
  private method, `generate_mod_icen()`, dispatched from the top of the
  existing `generate_mod()` (a top-level branch, not a hot-path edit --
  the existing Breslow partial-likelihood code below is untouched and
  unreachable for general-censoring data, which can only exist on this
  class in the first place because of the guard above). Exact rows
  (`private$y` non-`NA`) become a zero-width `[y, y]` interval; censored
  rows use `y_L`/`y_R` directly — right-censored (`y_R = Inf`) and
  left-censored (`y_L = 0`) both fall out of the same `cbind(L, R)` shape
  `ic_sp()` expects, confirmed empirically against a live `icenReg` fit
  mixing all three shapes in one call before writing any package code.
  Reshapes `fit$coefficients`/`fit$var` into the same
  `list(beta_hat_T=, ssq_b_2=, b=, vcov=, neg_log_lik=)` shape
  `generate_mod()`'s existing branches already return, so
  `compute_estimate()` and the default `testing_type = "wald"` path
  through `compute_asymp_confidence_interval()`/
  `compute_asymp_two_sided_pval()` work with no further changes needed —
  verified against a simulated interval-censored Weibull dataset
  (treatment coefficient recovered close to the true value, finite CI and
  p-value) and cross-checked to match a direct `icenReg::ic_sp()` call on
  the same data.

  **What's deliberately still blocked, not silently wrong.** icenReg's
  NPMLE fit has no partial-likelihood score/gradient/Hessian to feed the
  existing `score`/`gradient`/`lik_ratio`/`lik_ratio_bartlett_*`
  testing-type machinery, so `generate_mod_icen()` leaves
  `cached_values$likelihood_test_context` unset and
  `compute_asymp_confidence_interval()`/`compute_asymp_two_sided_pval()`
  now `stop()` immediately with a clear message if
  `testing_type != "wald"` under general censoring, rather than letting
  those paths silently misuse the icenReg fit or fail with a confusing
  downstream error. `compute_estimate_with_bootstrap_weights()`
  (Bayesian-bootstrap weighted re-estimation) similarly `stop()`s clearly
  under general censoring — `weighted_cox_bootstrap_surrogate_fit()`
  assumes ordinary right-censoring and doesn't generalize. The one Cox
  fast-path override that's safe to just disable is
  `compute_fast_rand_bootstrap_distr()`: it returns `NULL` under general
  censoring, which is this codebase's established "no fast path, use the
  generic implementation" signal (already used for several other early-out
  conditions in the same method), and the generic randomization loop
  re-dispatches through `generate_mod()`/`generate_mod_icen()` per
  replicate.

  **Found along the way, confirmed pre-existing and unrelated, not
  fixed:** `InferenceSurvivalCoxPHRegr`'s randomization-inference path
  (`compute_rand_two_sided_pval()`, `approximate_rand_bootstrap_distribution_beta_hat_T()`)
  throws `"attempt to apply non-function"` — reproduced identically on
  ordinary exact/right-censored data with none of this session's changes
  in play, so it's not something this work introduced or regressed.
  `test-rand-bootstrap.R` independently has a large pre-existing failure
  cluster (class-hierarchy assertions, stale positional `dead =` call
  sites from the TODO-1 migration, the same non-function crash) unrelated
  to survival or censoring specifically. Out of scope for this TODO; flagged
  here rather than silently worked around.

  **`InferenceSurvivalStratCoxPHRegr` deferred, not attempted.** Its
  strata-splitting logic (`get_informative_rows()`,
  per-stratum/all-strata dead-count checks, `generate_mod()`'s
  substantially larger body) would need its own pass to map onto
  `icenReg`'s own strata support cleanly — mechanically similar in shape
  to what landed here, but attempting it in the same pass would have
  meant less verification depth on either class. Follow-up, not a
  scoping gap: same pattern as `InferenceSurvivalCoxPHRegr`, applied to
  the strata-aware call sites.
- [ ] TODO-7: Add the `interval` package as a similar optional dependency.
  Implement the `interval::ictest()` dispatch path for
  `InferenceSurvivalLogRank` and `InferenceSurvivalGehanWilcox`. Same
  left-censoring input-encoding check as TODO-6.
- [ ] TODO-8: Implement the `interval::icfit()` (Turnbull NPMLE) dispatch
  path for `InferenceSurvivalKMDiff` and `InferenceSurvivalRestrictedMeanDiff`,
  including a variance/CI strategy (analytic if `icfit()` exposes one for
  the needed contrast, bootstrap fallback otherwise).
- [ ] TODO-9: Once TODO-6/7/8 land, verify (or extend) that
  `InferenceSurvivalKKLWACoxPHIVWC`/`OneLik`,
  `InferenceSurvivalKKStratCoxPHIVWC`/`OneLik`,
  `InferenceSurvivalKKWeibullFrailtyIVWC`/`OneLik`, and
  `InferenceSurvivalKKWeibullMarginal` correctly propagate interval
  censoring through their combined matched-set/reservoir construction —
  same OneLik-likely-free / IVWC-needs-both-components-first asymmetry
  flagged in the sibling plans.

### Tier 3 — Explicitly deferred, second-wave

- [ ] TODO-10: Commission a follow-up feasibility report scoping how
  dependent censoring (`InferenceSurvivalDepCensTransformRegr`) and
  interval censoring compose, before writing any implementation TODOs for
  it.
- [ ] TODO-11: Commission a follow-up feasibility report for
  `InferenceSurvivalKKClaytonCopulaIVWC`/`OneLik` under interval censoring,
  scoping how the copula's matched-pair joint-survival structure interacts
  with interval-censored marginals.
- [ ] TODO-12: Commission a follow-up feasibility report for
  `InferenceSurvivalKKRankRegrIVWC`/`InferenceAbstractKKSurvivalRankRegrIVWC`
  under interval censoring, surveying rank-based interval-censored AFT
  estimators as candidate approaches (no dominant existing R-package
  function to delegate to, unlike the Tier 2 families above).

## Appendix: How Common Is Interval-Censored Survival Data?

Interval censoring in time-to-event data is common and, in some subfields,
the *actual* generating mechanism behind data that gets mishandled as
right-censored. It arises whenever an event is only known to have occurred
between two scheduled observation times rather than continuously monitored
— which describes most periodic-visit clinical trials.

- Progression-free survival (PFS) in oncology trials is frequently assessed
  only at scheduled visits (e.g. every 6 months), making it genuinely
  interval-censored data by construction:
  [A review of statistical issues with progression-free survival as an
  interval-censored time-to-event
  endpoint](https://pubmed.ncbi.nlm.nih.gov/23957511/)
- A common but statistically problematic practice is to simplify
  interval-censored data into right-censored data and apply standard
  Kaplan-Meier/log-rank/Cox methods anyway, which can bias the estimated
  median time to event:
  [Use of interval-censored survival data as an alternative to Kaplan-Meier
  survival curves](https://link.springer.com/article/10.1186/s41241-018-0067-7),
  [Interval censoring — PMC](https://pmc.ncbi.nlm.nih.gov/articles/PMC3684949/)
- Interval-censored (and "current status," a special case) data are
  described as commonly encountered not just in medicine but also in
  econometrics and social science more broadly:
  [Recovering income distribution in the presence of interval-censored
  data](https://link.springer.com/article/10.1007/s10888-023-09617-2),
  [Boosting methods for interval-censored data with regression and
  classification](https://arxiv.org/pdf/2601.17973)
- Duration models — unemployment duration, strike duration, insurance claim
  duration, time to purchase — are a standard applied-econometrics topic
  where interval/current-status censoring is a recognized data feature:
  [Duration Analysis (Llull, lecture
  notes)](https://joanllull.github.io/Microeconometrics/Duration.pdf)
- Health-register data is sometimes deliberately binned into coarse
  intervals for anonymization, producing genuinely interval-censored event
  and censoring times as a matter of data-release policy, not measurement
  limitation:
  [Simple parametric survival analysis with anonymized register data: a
  cohort study with truncated and interval censored event and censoring
  times](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC3748025/)

**Verdict**: interval-censored survival data is common and arguably
under-served by current practice (too much of it gets forced into
right-censored analyses it doesn't fit). Combined with the reframing above
— the hard-looking NPMLE/EM machinery mostly already exists in mature CRAN
packages (`icenReg`, `interval`) — this makes interval-censored survival a
real, worthwhile, and more tractable-than-it-looks project, not a niche one
to defer indefinitely. Contrast with interval-censored *count* data, which
`censored_count_response.md`'s closing section finds to be considerably
rarer in practice and without an established dedicated methodology to lean
on.
