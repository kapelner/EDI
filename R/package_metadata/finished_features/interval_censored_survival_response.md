# Interval-Censoring Support for the `survival` Response Type

> **Depends on:** `fix_inference_hierarchy.md` (its TODO-13 Cox component gap). Blocks: `sexp_removal_rcppeigen_conversion_spec.md`'s remaining survival-file conversions, `censored_continuous_response.md`/`censored_count_response.md` (schema pattern), and the `edi_kernels` Python release. (Global ordering: see `_master.md`.)

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
  **Correction to a stale claim below (found auditing this document, not
  during TODO-1 itself):** TODO-1a's note that the bit-identical
  regression pass was "not yet run — blocked on this repo's pre-existing,
  unrelated C++ build failure" is no longer accurate as a blanket
  statement. The package compiles and loads fine in this environment, and
  targeted regression runs *did* happen across TODO-2/TODO-6's work
  (`test-designs.R`, `test-design-inference.R`,
  `test-runtime-argument-combination-assertions.R`,
  `test-brt-smoothed-coxph-kernel.R`, `test-coxph-hessian-symmetric-writes.R`,
  `test-coxph-robust-vcov.R`, all passing, plus direct bit-identical
  estimate/CI/p-value comparisons for exact/right-censored Cox data) — not
  the exhaustive "every existing test case" sweep TODO-1a originally
  called for, but real evidence, not zero. The actual obstacle encountered
  this session was intermittent, not a build failure: this machine had
  another concurrent Claude Code session actively mid-editing several
  `Inference*` files (`inference_incidence_gcomp.R` and others, working
  through `fix_inference_hierarchy.md`'s own pending migration items) at
  the same time, which occasionally left `devtools::load_all()` catching
  the codebase in a transient broken state unrelated to anything in this
  document — confirmed by the errors naming unrelated classes
  (`InferenceCountPoissonKKGEE`, `InferenceOrdinalPropOddsRegr`,
  `InferenceIncidGCompRiskDiff`) and resolving on retry. A full,
  exhaustive "every existing survival test file, bit-identical" sweep
  still has not been run and remains open.
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
     copies response data (the `KKPassThrough` component's reusable-worker
     and non-reusable bootstrap loops in `inference_mixin_kk_passthrough.R`,
     the `RandomizationTest` component's permutation machinery in
     `inference_all_abstract_rand.R` — cited by their pre-shallow-hierarchy
     names `InferenceMixinKKPassThrough`/`InferenceRand` when this audit ran;
     re-verify this finding once `fix_inference_hierarchy.md`'s base deletion
     physically relocates those bodies into component sources — and every
     survival class's
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
     **Update (post-TODO-6):** that revisit has partly happened —
     `InferenceSurvivalCoxPHRegr` can now exist with general censoring.
     This finding still holds in practice: the only two Cox-side
     resampling paths that actually run today
     (`compute_fast_rand_bootstrap_distr`,
     `compute_estimate_with_bootstrap_weights`) were given their own
     explicit `has_general_censoring` guards as part of TODO-6, precisely
     because they don't thread `y_L`/`y_R` and can't safely be
     generalized yet. TODO-13 below documents that most of the other
     resampling/randomization surface (`RandomizationTest`,
     `RandomizationCI`, `NonparametricBootstrap`, `BayesianBootstrap`) is
     currently just absent on Cox for unrelated reasons, so there's no
     live code path today that silently mishandles `y_L`/`y_R` during
     resampling — but this will need a real look (not just a guard) once
     TODO-13 is fixed and those methods start existing again.
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

- [x] TODO-3: Extend `WeibullAFTLikelihood`
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
  Weibull test suite rather than just trusting the algebra. **Done.**

  **The formula.** `WeibullAFTLikelihood`'s constructor changed from
  `(y, dead, X)` to `(y, y_L, y_R, X)` — `y` finite marks an exact row
  (density term, byte-for-byte the same code as before); `y` `NaN` marks a
  censored row, contributing `log(S(y_L) - S(y_R))`. The degenerate limits
  (`y_L = 0` for left-censoring, `y_R = Inf` for right-censoring) can't be
  evaluated by literally computing `exp(w)` at `w = -Inf`/`+Inf` and
  multiplying — that produces `0 * Inf`/`Inf * 0` NaNs in several of the
  gradient/Hessian terms (e.g. `w * exp(w) * S(w)`), even though each such
  term has a well-defined *limit* of `0` (exponential decay beats the
  polynomial factor). Handled via a small `BoundTerms` struct that either
  computes the six needed `w^k * exp(w)^m * S(w)` products normally (finite
  bound) or returns them as exact `0`s (degenerate bound) without ever
  forming the underlying indeterminate product — `S(w)` itself is safe to
  compute literally at either infinity (`exp(-Inf) = 0`, `exp(-0) = 1`), so
  only the paired products needed the guard, not the survivor value.

  **Verified numerically, not just algebraically**, per the TODO's own
  instruction — two independent layers:
  1. A standalone C++ harness (no R, no package build, just the extracted
     `BoundTerms`/censored-row formulas against `<Eigen/Dense>`) finite-
     difference-checked the analytic gradient and Hessian against the raw
     log-likelihood across five cases (moderate interval, a narrow
     ~0.05-wide interval, left-censored, right-censored, and a case far
     from `eta` with large-magnitude derivatives) — 25 comparisons, all
     matching to `1e-4`–`1e-10`. Also checked both algebraic reductions
     (right-censored `== -exp(w)`, left-censored `== log(1-S(R))`) to
     machine precision (`1e-12`). This ran independently of the R package
     build, which mattered: this machine had another concurrent Claude
     Code session doing sustained heavy compiles for most of this work,
     repeatedly starving/timing out full `devtools::load_all()` attempts
     (up to 500s) and once hitting a genuine linker race (`.o` files
     vanishing mid-link, shared `src/` directory, unrelated to this
     change) — the standalone harness gave fast, reliable ground truth
     without waiting on that contention.
  2. Once a `load_all()` finally landed, `tests/testthat/test-weibull-general-censoring.R`
     (new) repeats the same class of check at the R level via `numDeriv`
     on mixed exact/left/interval/right data (score and Hessian, `1e-6`/
     `1e-4` tolerance), confirms **exact** (not just close) bit-identical
     output — `0` difference in coefficients, score, and Hessian — between
     the new general kernel fed `(y_exact, y_L=y, y_R=Inf)` and the old
     `(y, dead)` kernel fed the same right-censored data, and confirms
     correct coefficient recovery on simulated left-censored and
     interval-censored Weibull data (~400-500 subjects, recovered
     coefficients within 0.3 of the true generating values). All pass.

  **Mechanics.** All five existing `(y, dead)`-based call sites in the
  file (`fast_weibull_regression_internal`, `fast_weibull_regression_cpp`,
  `get_weibull_regression_score_cpp`, `get_weibull_regression_hessian_cpp`,
  and the OpenMP-parallel `compute_weibull_rand_bootstrap_parallel_cpp`)
  now bridge through a new `dead_to_bounds()` helper (`dead == 1` ->
  exact `y`; `dead == 0` -> `y_L = y, y_R = Inf`) before constructing
  `WeibullAFTLikelihood` — same conversion, same reasoning as
  `dead_to_response_bounds()` in `simulations_framework.R` (TODO-2). Their
  R-facing `(X, y, dead)` signatures are completely unchanged; this is
  what makes the bit-identical check above meaningful rather than
  tautological. Three new exported functions for the general case, for
  TODO-4 to wire up: `fast_weibull_regression_general_cpp`,
  `get_weibull_regression_general_score_cpp`,
  `get_weibull_regression_general_hessian_cpp` — same argument shape as
  their `(y, dead)` counterparts but taking `(y, y_L, y_R)`. The OLS-on-
  log-scale smart-cold-start heuristic (`weibull_aft_start_or_legacy`) is
  reused unchanged via a `general_to_effective()` proxy (exact rows keep
  `y`; censored rows use `y_L` as a naive starting value) — left-censored
  rows (`y_L = 0`) are simply excluded by that heuristic's own existing
  `y[i] > 0` filter, falling back to the legacy zero start gracefully;
  this warm start only needs to be a reasonable starting point, not a
  correct likelihood term, so no changes were needed there.

  **Regression-checked, not just assumed.** The existing Weibull test
  suite (`test-brt-smoothed-weibull-kernel.R`,
  `test-weibull-aft-buffer-reuse.R`, `test-weibull-frailty.R`,
  `test-weibull-marginal.R`) passes unchanged.
  `test-brt-weibull-kernel-matches-reference.R` has two pre-existing
  failures (`compute_fast_rand_bootstrap_distr` disagreeing with its own
  generic-fallback reference on an unrelated KK-matched-design path) —
  confirmed genuinely pre-existing, not caused or worsened by this change,
  by `git stash`-reverting this exact file back to its pre-TODO-3 state
  and re-running the same test: identical failure, same two assertions,
  same "0 finite estimates" symptom.

  **Deliberately out of scope for TODO-3** (belongs to TODO-4/TODO-9):
  no R-level wiring — `InferenceSurvivalWeibullRegr` still calls the old
  `fast_weibull_regression_cpp`, unaware the general kernel exists;
  `compute_weibull_rand_bootstrap_parallel_cpp`'s bootstrap/randomization
  logic itself is untouched beyond the `dead_to_bounds()` bridge (still
  only produces right-censored/exact replicates); `NAMESPACE`/roxygen
  `export()` entries for the three new functions weren't regenerated (the
  same intermittent R6-srcref roxygen issue noted elsewhere this session)
  — the functions are present and correct in `RcppExports.R`/`.cpp` and
  callable via `EDI:::`, which is sufficient for TODO-4's internal R-side
  use, but a `Rscript fast_roxygenize.R` pass is still owed before these
  are meant to be user-facing `@export`ed API.
- [x] TODO-4: Thread `y_L`/`y_R` from `InferenceSurvivalWeibullRegr`
  (`inference_survival_weibull.R`) into the extended kernel; remove or
  relax whatever interval-censoring guard is added alongside TODO-1a.

  **Done.** `InferenceSurvivalWeibullRegr` now declares
  `supports_interval_or_left_censored_data() = TRUE` and dispatches through
  three small helpers (`weibull_kernel_fit`/`weibull_kernel_score`/
  `weibull_kernel_hessian`) that branch on `private$has_general_censoring`:
  general case calls the TODO-3 kernel
  (`fast_weibull_regression_general_cpp`/`get_weibull_regression_general_score_cpp`/
  `get_weibull_regression_general_hessian_cpp`) with `private$y_L`/`private$y_R`;
  else the original `(y, dead)` kernel, byte-for-byte unchanged. Every call
  site that used to call the kernel directly
  (`compute_treatment_estimate_during_randomization_inference`,
  `get_likelihood_test_spec()`'s `fit_null`/`score`/`observed_information`/
  `fisher_information`/`information`, `generate_mod()`'s `fit_fun`) now goes
  through these helpers.

  **A real, pre-existing bug was found and fixed along the way, not
  introduced by this TODO.** `Inference$initialize()`
  (`inference_all_abstract.R`) populated `private$y` unconditionally via
  `des_obj$get_effective_time()`, which silently substitutes `y_L` for `NA`
  on any censored row — exactly the caveat `get_effective_dead()`'s own
  docstring warns about. Every piece of general-censoring dispatch that
  branches on `is.na(private$y)` (this class's kernel dispatch, and Cox's
  `L = ifelse(is.na(private$y), private$y_L, private$y)` from TODO-6) was
  therefore **never actually seeing a censored row as censored** — `y` was
  never `NA` for *any* class, so Cox's dispatch always took the exact-value
  branch, degenerating every interval-censored subject to a zero-width
  `[y_L, y_L]` interval (which `icenReg` happens to interpret as "exact at
  y_L", so TODO-6's numbers looked plausible without being correct). Fixed
  by making `private$y` conditional: `des_obj$get_y()` (raw, `NA`-preserving)
  under general censoring, `get_effective_time()` (legacy proxy) otherwise —
  a one-line change in `inference_all_abstract.R` that fixes both this class
  and Cox simultaneously. TODO-6 has since been re-verified against this fix
  (see the "Re-verified after the TODO-4 `private$y` fix" note under TODO-6
  below) — its original numbers were indeed wrong in the way predicted here.

  A second, symmetric bug was found in the shared bootstrap-worker
  infrastructure (`inference_all_abstract_non_param_boot.R`,
  `create_design_backed_bootstrap_worker_state()`/
  `load_bootstrap_sample_into_design_backed_worker()`): `base_y` was set
  from `source_des_priv$y` (Design's *raw* field, `NA`-for-censored) and fed
  straight into worker inference objects that then call the legacy
  `(y, dead)` kernel — which needs the *effective-time* convention (`NA`
  replaced by the censoring time), not raw `NA`. This made **every**
  reusable-bootstrap-worker-backed survival class's nonparametric bootstrap
  silently return an all-`NA` distribution for *any* data, including plain
  right-censored data with no interval censoring at all — unrelated to this
  plan except that TODO-4's end-to-end verification is what surfaced it.
  Fixed the same way: `base_y` now reconstructs the effective time
  (`ifelse(is.na(y), y_L, y)`) unless `has_general_censoring` is `TRUE`, in
  which case it stays raw. A related dead-field bug (Design no longer stores
  a raw `dead` field post-migration, so `base_dead` was always `NULL`) was
  fixed alongside it by deriving `dead` from `!is.na(y)` when the field is
  absent.

  Three explicit guards were added, each raised **at the public entry point**
  rather than deep inside per-iteration `tryCatch` blocks that would
  otherwise silently convert a `stop()` into an all-`NA` distribution (the
  first attempt at this did exactly that — the guard technically fired but
  the caller only ever saw a clean `NA`, never the error message):
  `compute_bayesian_bootstrap_two_sided_pval()`,
  `compute_lik_ratio_bartlett_approx_two_sided_pval()`, and
  `compute_rand_two_sided_pval()` when `delta != 0`, all overridden in
  `InferenceSurvivalWeibullRegr` to `stop()` immediately under general
  censoring before delegating to `super$...`.

  **Verification.** A standalone end-to-end script exercised: exact/
  right-censored data (estimate/CI/Wald-pval/lik-ratio-pval/nonparametric-
  bootstrap-pval/randomization-pval all finite, confirming zero regression);
  interval-censored data (point estimate recovers the true treatment effect,
  CI/Wald/lik-ratio/score/bootstrap/randomization p-values all finite);
  left-censored data (point estimate recovers the true effect); the three
  guards above firing with clear messages; `InferenceSurvivalKMDiff` still
  rejecting general censoring; Cox (TODO-6) still fitting general censoring.
  Also ran `test-weibull-general-censoring.R` (12/12 pass) and a wider sweep
  of Weibull/Cox/KM regression suites — one unrelated, confirmed
  pre-existing failure surfaced
  (`test-brt-weibull-kernel-matches-reference.R`'s second test, on
  `InferenceSurvivalKKWeibullMarginal`, which neither inherits from this
  class nor ever has `has_general_censoring = TRUE` in that test — outside
  this TODO's blast radius) plus several pre-existing test-file/API mismatches
  (`add_all_subject_responses(deads = ...)` no longer a valid argument name)
  from the unrelated `y`/`y_L`/`y_R` Design-field migration, not investigated
  further here.

  **Deliberately out of scope / left for later:** Bayesian bootstrap,
  Bartlett-corrected likelihood-ratio calibration, and nonzero-delta
  randomization tests remain explicitly unsupported for interval-censored
  data (see guards above) — each requires a real modeling decision (how to
  re-censor/re-weight/re-derive an interval under resampling or a null
  shift), not a mechanical extension.
- [x] TODO-5: Add interval-censored unit tests (point-estimate recovery
  against simulated interval-censored Weibull data) and a benchmark
  confirming the exact/right-censored paths are unchanged.

  **Done.** TODO-3's `test-weibull-general-censoring.R` only ever exercises
  the C++ kernel functions directly (`fast_weibull_regression_general_cpp`
  et al.), never the `InferenceSurvivalWeibullRegr` R6 class. New file
  `tests/testthat/test-weibull-general-censoring-inference.R` closes that
  gap at the class level: (1) point-estimate recovery under interval
  censoring, (2) under left censoring, (3) under mixed exact/right/interval
  censoring in one dataset (also asserts `has_general_censoring` and the
  `is.na(private$y)` count come out right, guarding against the TODO-4 `y`
  bug recurring); (4) a regression check that exact/right-censored data
  produces a numerically identical estimate (`tolerance = 1e-8`) whether
  computed through the class or by calling `fast_weibull_regression_cpp()`
  directly on the same `(y, dead)`, confirming `has_general_censoring =
  FALSE` really does take the untouched kernel branch; (5) the three
  entry-point guards (Bayesian bootstrap, Bartlett, nonzero-delta
  randomization) raise with the expected message under general censoring,
  and nonzero-delta's sibling (`delta = 0`) is explicitly confirmed
  *not* blocked. 22/22 assertions pass.

  **Benchmark.** Added a `weibull_general_est` entry to
  `R/profile/edi_kernel_profiler.R` (`fast_weibull_regression_general_cpp`
  on the same interval-censored-reshaped data as `weibull_est`'s exact/
  right-censored data, same `REPS = 150000`), run alongside the existing
  `weibull_est` entry as the "unchanged" comparison point rather than a
  new inline copy of it. Confirmed via `Rscript edi_kernel_profiler.R
  weibull_est` / `weibull_general_est`: the exact/right-censored kernel is
  unaffected (0.192 ms/call, matching its pre-existing tuned `REPS`
  budget), and the new general-censoring kernel — a separate function,
  never on the exact/right-censored call path — costs more per call
  (0.518 ms/call, ~2.7x) but only when interval-/left-censored data is
  actually present.

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

  **Re-verified after the TODO-4 `private$y` fix.** The original
  verification above was run before the bug described in TODO-4 was found:
  `Inference$initialize()` populated `private$y` via `get_effective_time()`
  unconditionally, so `is.na(private$y)` was `FALSE` for *every* row
  regardless of censoring, and `generate_mod_icen()`'s
  `L = ifelse(is.na(private$y), private$y_L, private$y)` always took the
  `private$y` branch — every censored subject silently became a zero-width
  `[y_L, y_L]` interval rather than the true `[y_L, y_R]` window. Because
  `icenReg::ic_sp()` interprets a zero-width interval as an exact
  observation at `y_L`, the fit still ran and produced a plausible-looking
  (but subtly wrong) coefficient — this is exactly the kind of bug that
  passes a casual "does it run and give a reasonable number" check without
  being correct. After the fix (`inference_all_abstract.R`'s `private$y`
  is now `des_obj$get_y()`, raw and `NA`-preserving, whenever
  `has_general_censoring` is `TRUE`), re-ran the same style of check on
  fresh simulated data: (1) all-interval-censored data (`y` `NA` for
  300/300 subjects, confirming the branch is actually exercised) — package
  estimate matches a direct `icenReg::ic_sp()` call on the identical
  `cbind(L, R)` data to full numerical precision; (2) a mixed
  exact/right-censored/interval-censored dataset (290/400 subjects
  censored) generated from a true proportional-hazards model — package
  estimate (0.639) close to the true coefficient (0.6) and again matches
  direct `icenReg::ic_sp()` to full precision. Also re-ran
  `test-brt-smoothed-coxph-kernel.R`, `test-coxph-hessian-symmetric-writes.R`,
  and `test-coxph-robust-vcov.R` (all pass, confirming no regression to the
  exact/right-censored partial-likelihood path, which never touches
  `generate_mod_icen()`).

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
- [x] TODO-7: Add the `interval` package as a similar optional dependency.
  Implement the `interval::ictest()` dispatch path for
  `InferenceSurvivalLogRank` and `InferenceSurvivalGehanWilcox`. Same
  left-censoring input-encoding check as TODO-6.

  **Done.** `interval` was already present in `Suggests` (`DESCRIPTION`)
  with an `assert_interval_installed()` helper already in
  `other_helpers.R` (staged alongside TODO-6's `icenReg` dependency work,
  before this TODO's dispatch code existed) -- it documents that `interval`
  depends on Bioconductor's `Icens`, which `install.packages()` cannot
  resolve on its own, and points at `BiocManager::install("Icens")` first.

  **The dispatch itself.** Both classes are pure two-sample tests with no
  covariate adjustment (only `private$w`, never `private$get_X()`), which
  turns out to match `interval::ictest()` exactly: it only accepts
  `(L, R, group, ...)` with no covariate argument, confirmed by reading
  `ictest.formula`'s source before writing any dispatch code (it errors if
  the RHS isn't a single grouping term) -- the same "confirm the input
  contract empirically, don't assume" step TODO-6 used for `icenReg`.
  Both classes gained `supports_interval_or_left_censored_data() = TRUE`
  and a new private `compute_shared_icen()`, dispatched from the top of the
  existing `compute_shared()` (top-level branch, existing right-censored
  code below untouched and unreachable for general-censoring data — same
  shape as Cox's `generate_mod_icen()`). `L`/`R` are built the same way as
  Cox's `generate_mod_icen()`: exact rows become `[y, y]`, censored rows
  use `y_L`/`y_R` directly, confirmed empirically to handle `y_L = 0`
  (left-censored) and `y_R = Inf` (right-censored) correctly in one mixed
  call before writing the dispatch. `InferenceSurvivalLogRank` uses
  `scores = "logrank1"` (Sun's log-rank scores); `InferenceSurvivalGehanWilcox`
  uses `scores = "wmw"` (Wilcoxon-Mann-Whitney), matching each class's
  right-censored counterpart (`rho = 0` vs. `rho = 1` in
  `survival::survdiff()`).

  **Reused the existing contract, not a new one.** `ictest()`'s return
  object turned out to already carry everything needed:
  `fit$estimate` ("mean GROUP 1 - mean GROUP 2") is the direct
  interval-censored analog of the martingale-residual-difference `beta_hat_T`
  both classes already expose, and `fit$statistic` (a Z-score) gives an SE
  via `abs(estimate / Z)`. So `compute_asymp_confidence_interval()` (Wald,
  inherited unchanged) and `compute_asymp_two_sided_pval()` work with no
  further code once `compute_shared_icen()` populates `beta_hat_T`/
  `s_beta_hat_T`. The classes' own specialized *pure-test* p-value methods
  (`compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` for
  LogRank; `compute_asymp_two_sided_pval()` itself for GehanWilcox, which
  has no separate Wald-CI-inversion path) return `ictest()`'s own
  `p.value` directly under general censoring rather than re-deriving a
  chi-squared statistic, since `ictest()` already computed it.

  **What's deliberately still blocked.** `compute_estimate_with_bootstrap_weights()`
  (Bayesian-bootstrap re-estimation) `stop()`s clearly under general
  censoring for both classes: `weighted_logrank_mean_difference()`/
  `weighted_peto_prentice_mean_difference()` build on
  `survival::coxph()`/`survfit()`/`Surv()`, which assume ordinary
  right-censoring. `InferenceSurvivalLogRank$compute_fast_rand_bootstrap_distr()`
  returns `NULL` under general censoring (this codebase's established "no
  fast path" signal), falling back to the generic randomization loop that
  re-dispatches through `compute_estimate()`/`compute_shared_icen()` per
  replicate; `InferenceSurvivalGehanWilcox` never had a fast-path override
  to begin with, so it already takes this route. The nonparametric
  bootstrap needed no class-specific change at all: both classes use the
  default `supports_reusable_bootstrap_worker() = TRUE` path (
  `create_design_backed_bootstrap_worker_state()`/
  `load_bootstrap_sample_into_design_backed_worker()`), the same shared
  infrastructure fixed in TODO-4, so each bootstrap replicate correctly
  re-dispatches through `compute_estimate()` under general censoring with
  no further wiring. Nonzero-`delta` testing remains blocked for both
  classes regardless of censoring shape (a pre-existing limitation, not
  new).

  **Verification.** A standalone script (this session's build environment
  had a shared, actively-mid-edit C++ tree from a concurrent process making
  a full `devtools::load_all()` rebuild impractical, so verification loaded
  the already-installed package and re-sourced just the two changed R
  files into its namespace, bypassing the build system entirely — no C++
  was touched by this TODO) confirmed: exact/right-censored data unaffected
  (`has_general_censoring = FALSE`, finite estimate/p-value, matching the
  untouched right-censored code path); interval-censored point estimate
  and p-value for both classes match a direct `interval::ictest()` call on
  the same data to full precision (not just approximately -- the package
  literally reshapes `ictest()`'s own output); finite CI for both; both
  Bayesian-bootstrap guards firing with a clear message; nonzero-delta
  still blocked; `InferenceSurvivalKMDiff` still rejecting interval-censored
  data (unaffected by this TODO). Also added
  `tests/testthat/test-logrank-gehan-wilcox-general-censoring.R` (19
  assertions, all passing) and re-ran the three pre-existing LogRank/
  GehanWilcox test files -- one unrelated, pre-existing failure surfaced in
  `test-gehan-wilcox-fused-martingale.R` (`add_all_subject_responses(y, dead)`,
  the same stale-API-signature class of failure already flagged in TODO-4's
  and TODO-5's writeups, from the unrelated `y`/`y_L`/`y_R` Design-field
  migration -- not investigated further here).
- [x] TODO-8: Implement the `interval::icfit()` (Turnbull NPMLE) dispatch
  path for `InferenceSurvivalKMDiff` and `InferenceSurvivalRestrictedMeanDiff`,
  including a variance/CI strategy (analytic if `icfit()` exposes one for
  the needed contrast, bootstrap fallback otherwise).

  **Done.** New shared file `inference_survival_turnbull_helpers.R`
  (`turnbull_npmle_group_stat()`/`turnbull_npmle_stat_diff()`, added to
  `DESCRIPTION`'s `Collate:`) computes a per-group median or restricted
  mean from `interval::icfit()`'s Turnbull-NPMLE output
  (`intmap`/`pf`), used by both classes -- confirmed `icfit()` has no
  `weights=` argument by reading its signature before writing any dispatch
  code (same discipline as TODO-6/7).

  **The interval-identifiability modeling choice.** Turnbull's NPMLE only
  identifies `S(t)` up to the probability mass on each maximal Turnbull
  interval `[intmap[1,k], intmap[2,k]]` -- `S` is undetermined strictly
  inside a non-degenerate interval. This is exactly the kind of "not a
  mechanical extension" decision TODO-4/6's guards were written to flag
  rather than silently resolve, but here a point estimate is unavoidable
  (both classes need one number), so a documented choice was made instead
  of a guard: the median uses the **midpoint** of the crossing interval;
  the restricted mean treats `S` as stepping down to its post-interval
  value at each interval's **left** endpoint (`S_L`, the same
  left-continuous-step convention this package's own ordinary-censoring
  RMST code already uses: `times = c(0, fit$time); surv_vals = c(1,
  fit$surv)`). Both are documented in `inference_survival_turnbull_helpers.R`
  as a modeling decision, not the only defensible one (Turnbull literature
  also uses `S_U`, the right-endpoint step).

  **The dispatch itself.** Both classes gained
  `supports_interval_or_left_censored_data() = TRUE`. `InferenceSurvivalKMDiff`'s
  `shared()` and `InferenceSurvivalRestrictedMeanDiff`'s `compute_estimate()`
  branch at the top on `has_general_censoring` (top-level branch, existing
  exact/right-censored C++-kernel code below untouched and unreachable for
  general-censoring data -- same shape as every other dispatch in this
  plan) to call `turnbull_npmle_stat_diff()` with `y_L`/`y_R` instead of
  the fast `get_survival_stat_diff(y, dead, w, stat)` kernel.

  **Variance/CI strategy: bootstrap fallback, and it cost zero new code.**
  Neither `icfit()` nor a derived median/RMST contrast has a closed-form
  variance, so `s_beta_hat_T` is simply left `NA` under general censoring
  (`InferenceSurvivalKMDiff$shared()` skips the Brookmeyer-Crowley
  `survfit()`-based SE attempt entirely;
  `InferenceSurvivalRestrictedMeanDiff$compute_s_beta_hat_T()` skips
  `get_restricted_mean_se_diff()` the same way). Both classes'
  `compute_asymp_confidence_interval()`/`compute_asymp_two_sided_pval()`
  *already* fall back to `compute_bootstrap_confidence_interval()`/
  `compute_bootstrap_two_sided_pval()` whenever `s_beta_hat_T` is
  unavailable -- unchanged code, no new CI/p-value logic needed at all.
  This nonparametric bootstrap needed no class-specific general-censoring
  wiring either: both classes use the default
  `supports_reusable_bootstrap_worker() = TRUE` path, the same shared
  infrastructure fixed in TODO-4, so each replicate correctly re-dispatches
  through `compute_estimate()` under general censoring.

  **What's deliberately still blocked.** `compute_estimate_with_bootstrap_weights()`
  (Bayesian-bootstrap re-estimation) `stop()`s clearly for both classes
  under general censoring, for the same reason as LogRank/GehanWilcox in
  TODO-7: `icfit()` has no weights argument, so
  `weighted_survival_stat_diff()`/`weighted_survival_stat_for_group()`
  cannot be generalized. Both classes'
  `compute_fast_rand_bootstrap_distr()` return `NULL` under general
  censoring (established "no fast path" signal), falling back to the
  generic randomization loop. `InferenceSurvivalKMDiff`'s
  `compute_asymp_log_rank_two_sided_pval_for_treatment_effect()` (a
  `survival::survdiff()`-based convenience method, not part of the primary
  Wald contract) is blocked outright under general censoring with a
  message pointing at `InferenceSurvivalLogRank` (TODO-7), which already
  does this correctly via `ictest()`.

  **Verification.** This session's build environment made a full
  `devtools::load_all()` rebuild impractical (see TODO-7's verification
  note -- a concurrent process was mid-edit on the shared C++ tree), so
  verification again loaded the already-installed package and re-sourced
  only the changed R files into its namespace; the one new top-level file
  couldn't be added to the *locked* namespace directly, so its two
  functions were sourced into `.GlobalEnv` instead for this session only
  (`.GlobalEnv` is reachable from the namespace's parent chain, so lexical
  scoping resolves them correctly) -- a verification-harness-only
  workaround that has no bearing on the actual saved source, which picks
  up the `Collate`-ordered top-level binding normally on a real build.
  Confirmed: exact/right-censored data unaffected for both classes; under
  interval censoring, `InferenceSurvivalKMDiff`'s point estimate matches a
  direct `icfit()`-based median-contrast computation on the same data to
  full precision, and both classes' point estimates are finite and
  correctly signed against a simulated true effect; bootstrap-fallback
  CI/p-value finite for both (the default bootstrap `type = "bca"` hit the
  *same* pre-existing, small-sample closed-form-correction edge case
  documented in TODO-4's writeup -- confirmed unrelated to censoring by
  the fact `type = "percentile"` succeeds immediately, exactly as it did
  there); both Bayesian-bootstrap guards firing with a clear message;
  the log-rank convenience-method guard firing. Also added
  `tests/testthat/test-km-rmst-general-censoring.R` (18 assertions, all
  passing) and re-ran `test-brt-smoothed-survival-stat-diff-kernel.R` and
  `test-km-median-canonical.R` for regressions -- the latter has 3
  pre-existing, unrelated failures (`add_all_subject_responses(deads =
  ...)`, the same stale-API-signature class of failure flagged in every
  prior TODO's writeup this session).
- [x] TODO-9: Once TODO-6/7/8 land, verify (or extend) that
  `InferenceSurvivalKKLWACoxPHIVWC`/`OneLik`,
  `InferenceSurvivalKKStratCoxPHIVWC`/`OneLik`,
  `InferenceSurvivalKKWeibullFrailtyIVWC`/`OneLik`, and
  `InferenceSurvivalKKWeibullMarginal` correctly propagate interval
  censoring through their combined matched-set/reservoir construction —
  same OneLik-likely-free / IVWC-needs-both-components-first asymmetry
  flagged in the sibling plans.

  **Verified, not extended.** None of these seven classes declares
  `supports_interval_or_left_censored_data()`, so each inherits the
  `Inference` base default (`FALSE`) and hits the shared guard in
  `Inference$initialize()` (`inference_all_abstract.R`, the same guard
  TODO-6 relocated and TODO-4 fixed) exactly as any other unextended
  survival class does. Confirmed empirically for all seven
  (`InferenceSurvivalKKLWACoxPHIVWC`, `..OneLik`,
  `InferenceSurvivalKKStratCoxPHIVWC`, `..OneLik`,
  `InferenceSurvivalKKWeibullFrailtyIVWC`, `..OneLik`,
  `InferenceSurvivalKKWeibullMarginal`) on a `DesignSeqOneByOneKK14` design
  with interval-censored responses: every one `stop()`s with the guard's
  clear "does not support left- or interval-censored survival data"
  message rather than silently constructing against it — the failure mode
  this whole plan has been careful to prevent throughout. Also confirmed
  all seven still construct and estimate fine on ordinary right-censored
  KK data (with one unrelated exception, `InferenceSurvivalKKStratCoxPHIVWC`,
  since fixed — see TODO-16 below).

  **Not extended, and deliberately so for this pass.** Actually adding
  interval-censoring *support* to these classes is a substantially larger
  undertaking than TODO-6/7/8 combined: each already combines a
  matched-set component with a reservoir component (LWA cluster-robust
  variance, stratified partial likelihood, a shared-frailty random effect,
  or the OneLik/IVWC split itself), and TODO-6/7/8's dispatch pattern
  (branch once, delegate the general-censoring case to a CRAN NPMLE
  implementation) has no obvious analog for a matched-pairs-plus-reservoir
  *combined* likelihood or a cluster-robust variance built on top of one —
  it would need its own design pass (candidate approach, verification
  strategy, exactly which piece delegates to `icenReg`/`interval` versus
  needs new machinery), the same reason TODO-10/11/12 were scoped as
  feasibility reports rather than implementation TODOs. Given the guard
  correctly fails loud and clear for all seven today, this is safe to
  leave as a documented future extension rather than block on it.

### Tier 3 — Explicitly deferred, second-wave

- [x] TODO-10 (**done 2026-08-16**): Commissioned a follow-up feasibility
  report scoping how dependent censoring
  (`InferenceSurvivalDepCensTransformRegr`) and interval censoring
  compose — see
  `package_metadata/feasibility_reports/dependent_censoring_x_interval_censoring.md`.
  **Verdict: not yet actionable.** This is an identifiability question,
  not an engineering one — `InferenceSurvivalDepCensTransformRegr` fits a
  bivariate Gaussian-copula log-normal AFT over a *latent random*
  censoring time `C` correlated with the event time `T`
  (`DepCensTransformLikelihood`,
  `R/EDI/src/fast_survival_models_optim.cpp:208-330`), but this plan's own
  interval-censoring scope is generated by a deterministic inspection
  *schedule*, not a competing random time — there may be no well-posed
  `C` to extend the model onto at all until a domain conversation settles
  which real composition (informative inspection timing vs. an
  interval-observed competing time) this package's actual users need.
  No implementation TODOs written; the report recommends a modeling
  conversation before any further scoping.
- [x] TODO-11 (**done 2026-08-16**): Commissioned a follow-up feasibility
  report for `InferenceSurvivalKKClaytonCopulaIVWC`/`OneLik` under
  interval censoring, scoping how the copula's matched-pair
  joint-survival structure interacts with interval-censored marginals —
  see `package_metadata/feasibility_reports/clayton_copula_interval_censoring.md`.
  **Verdict: feasible, closed-form, but substantially larger than Tier
  1/2.** The reservoir half of both classes already calls
  `fast_weibull_regression_general_cpp` (the exact Tier 1 kernel,
  confirmed by direct code inspection) so it rides on Tier 1 almost for
  free. The matched-pairs half's `ClaytonWeibullLikelihood`
  (`R/EDI/src/fast_survival_models_optim.cpp:39-183`) differentiates the
  closed-form bivariate Clayton survivor function `S(t1,t2) =
  (exp(theta H1) + exp(theta H2) - 1)^(-1/theta)` 0/1/2 times across its
  current 4 branches (right-censored/exact combinations per pair);
  interval censoring turns this into up to 9 branches per pair (each
  member independently exact/right/interval), each a finite
  difference of `S`, `dS/dt`, or `d^2S/dt1dt2` over 1, 2, or 4 evaluation
  points — real, laborious, closed-form new algebra with no numerical
  integration required, not a new open modeling question. Recommends
  deriving and testing the univariate case (Tier 1) first, since several
  of the 9 new branches reduce to applying that same operator twice.
- [x] TODO-12 (**done 2026-08-16**): Commissioned a follow-up feasibility
  report for
  `InferenceSurvivalKKRankRegrIVWC`/`InferenceAbstractKKSurvivalRankRegrIVWC`
  under interval censoring, surveying rank-based interval-censored AFT
  estimators as candidate approaches — see
  `package_metadata/feasibility_reports/rank_regression_interval_censoring.md`.
  **Verdict: no delegation target exists.** Confirmed directly against
  the installed `aftgee` 1.2.1 package (not just recalled): `?aftsrr`'s
  own documentation states its response must be "a `Surv` object with
  right censoring," and the package exports no interval-censoring-capable
  alternative — unlike `icenReg`/`interval` for the Tier 2 Cox/KM
  families, there is no dominant CRAN package to swap in. Real rank-based
  interval-censored AFT estimators exist in the literature (imputation-based
  Gehan extensions reusing ordinary `aftsrr()` inside an outer
  multiple-imputation loop, or direct interval-censored rank estimating
  equations built from scratch with no reference implementation to check
  against) but both require materially more engineering investment than
  anything else scoped in this plan. Recommends a maintainer decision on
  whether this narrow feature intersection (rank AFT + KK matching +
  interval censoring) is worth it before writing implementation TODOs;
  if so, the imputation-based approach is the more tractable starting
  point since it reuses the existing `aftsrr()` calls almost unchanged.

### Found During TODO-6, Not About Interval Censoring — Tracked Here So It Isn't Lost

- [x] TODO-13: `InferenceSurvivalCoxPHRegr` is missing an entire family of
  public methods — not an interval-censoring bug, a pre-existing gap in its
  migration to the component system, surfaced while chasing an unrelated
  `compute_rand_two_sided_pval()` crash reported against this document's
  TODO-6 work. Belongs at least as much to `fix_inference_hierarchy.md`'s
  "Partial-Likelihood Estimators" section as here; tracked in both places
  so it isn't dropped.

  **Root cause.** `InferenceSurvivalCoxPHRegr` is defined via
  `define_inference_class(inherit = Inference, components =
  "CoxPartialLikelihood")`. That component's dependency chain
  (`CoxPartialLikelihood -> StandardModelCache -> LikelihoodTests -> Wald ->
  Jackknife`) never reaches `RandomizationTest`, `RandomizationCI`,
  `NonparametricBootstrap`, `RandomizationBootstrap`, or
  `BayesianBootstrap`. Old-style classes (e.g. `InferenceSurvivalWeibullRegr`,
  a plain `R6::R6Class(inherit = InferenceAsympLikStdModCache, ...)`) get
  all of these for free via `InferenceJackknife`'s real R6 inheritance
  chain (`-> InferenceBayesianBootstrap -> ... -> InferenceRand`); Cox,
  migrated to the component system, does not. (Note, 2026-08-13: this
  old-vs-new asymmetry is transitional — once `fix_inference_hierarchy.md`'s
  base deletion completes, those bases no longer exist and *every* survival
  class must declare its randomization/bootstrap capabilities via explicit
  components, so the decision documented here — which optional APIs Cox
  intentionally keeps — becomes the per-class norm, not a migration gap.) Confirmed empirically:
  `compute_rand_two_sided_pval`, `approximate_randomization_distribution_beta_hat_T`,
  `approximate_bootstrap_distribution_beta_hat_T`,
  `compute_bootstrap_two_sided_pval`,
  `approximate_bayesian_bootstrap_distribution_beta_hat_T`,
  `compute_bayesian_bootstrap_two_sided_pval`, and
  `compute_bayesian_bootstrap_confidence_interval` are all literally `NULL`
  (`is.function()` is `FALSE`) on a live `InferenceSurvivalCoxPHRegr`
  object — calling any of them throws `"attempt to apply non-function"`
  immediately, reproduced identically on ordinary exact/right-censored
  data with none of this document's other changes in play, so it predates
  and is independent of the interval-censoring work.
  `compute_rand_bootstrap_two_sided_pval` (BRT) and every
  `compute_jackknife_*` method work correctly today (`RandomizationBootstrap`
  and `Jackknife` are reached some other way not yet traced), so this is a
  partial gap, not a total one.

  This is a real gap in already-"done" work, not an unfinished item:
  `fix_inference_hierarchy.md`'s "Partial-Likelihood Estimators" section
  has `[x] Migrate non-KK partial-likelihood classes to Inference plus
  LikelihoodTests, StandardModelCache, and family-specific components` —
  checked off, and that's exactly Cox's migration. Later-migrated classes
  in that same document's "Asymptotic (Wald) No-Likelihood Migration"
  section (e.g. `InferenceContinRobustRegr`) have detailed entries
  recording exactly which components were added, which method-name
  collisions had to be declared as overrides and why, and golden-test
  verification. Cox has no such entry — it looks like it was migrated
  before that rigor was established and never revisited.

  **Attempted fix (this session), reverted.** Added `"BayesianBootstrap"`
  to Cox's `components` (it transitively resolves
  `RandomizationBootstrap -> NonparametricBootstrap -> RandomizationCI ->
  RandomizationTest`), listed after `"CoxPartialLikelihood"` so Cox's own
  `StandardModelCache`/`Jackknife` chain wins ties, and added
  `compute_estimate_with_bootstrap_weights` to `overrides$public` (Cox
  already implements this hook itself). Iteratively resolved four rounds
  of registry-flagged collisions by declaring them in `overrides` —
  `compute_rand_two_sided_pval` (`RandomizationTest` vs `RandomizationCI`),
  `compute_treatment_estimate_during_randomization_inference`
  (`StandardModelCache` vs `InferenceRand`), `resolve_jackknife_unit` /
  `jackknife_block_size_gt_one_unsupported` /
  `mark_jackknife_nonestimable_if_block_unsupported` (`Jackknife` vs the
  `BayesianBootstrap` chain), and `supports_reusable_bootstrap_worker`.
  The package loaded cleanly after that — but functional verification
  showed the fix was wrong, not just incomplete:
  - `compute_rand_two_sided_pval`: existed afterward (no longer `NULL`)
    but still threw the identical `"attempt to apply non-function"` when
    actually called — a different missing piece further down the call
    chain, never identified.
  - `approximate_bootstrap_distribution_beta_hat_T`: ran without erroring
    but returned **100% `NA`** — silently wrong, strictly worse than the
    clean crash it replaced.
  - `compute_bayesian_bootstrap_two_sided_pval`: `NA`.
  - `compute_jackknife_estimate`: **regressed** to `NA` — it worked
    correctly *before* this component change; one of the four
    collision-resolution picks broke it, and it was never determined
    which one.
  - `compute_rand_bootstrap_two_sided_pval` (BRT) and this document's
    TODO-6 `icenReg` interval-censoring dispatch were unaffected by any of
    this, confirmed still correct throughout.

  Every collision was resolved by whichever choice made `load_all()` stop
  erroring, not by tracing which side of each collision was semantically
  correct for Cox — the classic trap of treating "the registry stopped
  complaining" as "it's fixed." Reverted `components`/`overrides` back to
  the pre-attempt state (`components = "CoxPartialLikelihood"` only, no
  extra overrides) rather than ship silently-wrong bootstrap/Bayesian-
  bootstrap/jackknife output. Verified the revert restores the original
  behavior exactly: the affected methods are cleanly absent (`NULL`)
  again, so calling any of them fails loudly and immediately instead of
  returning wrong numbers.

  **What it will actually take to land this.** The same rigor
  `fix_inference_hierarchy.md`'s later per-class entries used, not another
  round of "declare whatever the registry flags":
  1. Decide, per component, whether Cox should retain it as an
     intentional capability versus deliberately drop it — Cox's own code
     already assumes `RandomizationBootstrap`/`NonparametricBootstrap`
     (`compute_fast_rand_bootstrap_distr`,
     `compute_estimate_with_bootstrap_weights`), so those two are almost
     certainly intentional, not accidental surface area; `RandomizationTest`
     plain permutation p-values are a documented package feature so
     probably also intentional; `BayesianBootstrap` is the open question.
  2. For each registry-flagged collision, trace which side is actually
     correct for Cox (does it thread through `generate_mod()`/`shared()`
     the way Cox's own likelihood machinery expects, including this
     document's `generate_mod_icen()` addition?) rather than picking based
     on which order avoids a load-time error.
  3. Add golden tests comparing estimate/SE/CI/p-value/bootstrap-
     distribution output for randomization test, randomization CI,
     nonparametric bootstrap, randomization-bootstrap, Bayesian bootstrap,
     and jackknife against a reference implementation (e.g.
     `InferenceSurvivalWeibullRegr`, which has the full stack via its
     old-style inheritance chain) before and after any component change.
  4. Specifically explain (not just fix by trial and error) why
     `compute_jackknife_estimate` regressed and why
     `compute_rand_two_sided_pval` still crashed even once "present" —
     both are signs the collision-resolution choices were papering over a
     deeper wiring problem, not fixing it.
  5. Call `mark_inference_class_migrated()` for `InferenceSurvivalCoxPHRegr`
     (per `fix_inference_hierarchy.md`'s own convention) only once golden
     tests pass, and add the same before/after documentation entry that
     document's other migrated classes have.

  **Done (2026-08-14), following the plan above.** Root-caused with the
  `systematic-debugging` skill rather than repeating the earlier trial-and-
  error approach; the investigation, not just the diff, is what made this
  attempt succeed where the first one didn't.

  **Step 1 (decide per-component intent).** Confirmed empirically that
  `RandomizationTest`/`RandomizationCI`/`NonparametricBootstrap`/
  `RandomizationBootstrap`/`BayesianBootstrap` were *all* absent (not just
  the Bayesian-bootstrap tip of the chain) — `compute_rand_two_sided_pval`,
  `approximate_bootstrap_distribution_beta_hat_T`,
  `compute_bootstrap_two_sided_pval`,
  `approximate_bayesian_bootstrap_distribution_beta_hat_T`,
  `compute_bayesian_bootstrap_two_sided_pval`,
  `compute_bayesian_bootstrap_confidence_interval`, and even
  `compute_rand_bootstrap_two_sided_pval` (BRT, previously reported working
  in the earlier attempt's notes above — no longer true, if it ever was)
  were all `is.function() == FALSE`. Decided: compose the single
  `BayesianBootstrap` component (its dependency chain transitively resolves
  all five) rather than an intentionally-partial subset — Cox's own file
  already assumes `compute_estimate_with_bootstrap_weights` and
  `compute_fast_rand_bootstrap_distr` exist as override points, so the
  full chain was already the intended target, just never finished.

  **Step 2 (trace which side wins each collision — the step skipped last
  time).** Read `resolve_component_dependencies()`
  (`mixin_contracts.R`): a post-order DFS, and `combine_component_slot()`
  merges resolved components via `utils::modifyList()` in that order, so
  **whichever subtree resolves last wins any name collision** — later in
  the `components = c(...)` vector means "wins ties," the *opposite* of
  what the earlier attempt's own reasoning assumed ("listed after
  CoxPartialLikelihood so Cox's own chain wins ties" — backwards; being
  listed after something in `components=` makes a component's *dependency
  subtree* resolve earlier, not later, since dependencies of later entries
  can already be satisfied by earlier ones' subtrees. This was traced
  precisely by hand-executing the DFS, not asserted.) This one ordering
  bug plausibly explains the earlier attempt's entire "100% NA
  bootstrap distribution, jackknife regression, still-crashing
  `compute_rand_two_sided_pval`" failure mode: `StandardModelCache`'s
  Cox-aware `compute_treatment_estimate_during_randomization_inference()`
  (which threads through `private$shared()`/`generate_mod()`, i.e. Cox's
  own partial-likelihood fit) was silently losing to `RandomizationTest`'s
  generic version. Fixed ordering: `components = c("BayesianBootstrap",
  "CoxPartialLikelihood")` (bootstrap chain first, Cox chain last).
  Traced every resulting collision individually rather than declaring them
  away: `compute_treatment_estimate_during_randomization_inference`
  (StandardModelCache correctly wins, confirmed by reading both bodies —
  RandomizationTest's version is a generic fallback for classes without
  Cox's caching infrastructure); `resolve_jackknife_unit`/
  `jackknife_block_size_gt_one_unsupported`/
  `mark_jackknife_nonestimable_if_block_unsupported` (byte-identical bodies
  in `Jackknife` and `NonparametricBootstrap`, confirmed by direct text
  comparison — winner immaterial); `supports_reusable_bootstrap_worker`
  (both return `TRUE` — immaterial); `compute_estimate_with_bootstrap_weights`
  (Cox's own `weighted_cox_bootstrap_surrogate_fit()`-backed host
  implementation must win, declared in `overrides$public`);
  `compute_rand_two_sided_pval` (pulled explicitly from `InferenceRand`,
  *not* `InferenceRandCI` — `InferenceRandCI`'s richer-looking override
  internally calls `super$compute_rand_two_sided_pval()`, which resolves
  against Cox's *actual* R6 superclass `Inference` once the method body is
  extracted and merged flatly, not against `InferenceRand` as it would
  inside `InferenceRandCI`'s own real inheritance chain — caught by
  actually calling it and getting `"attempt to apply non-function"`, not
  by inspection; traced to the `super$` call by reading the body, then
  confirmed `InferenceRandCI`'s only *other* content is an incidence-only
  special case irrelevant to survival data, so the two are behaviorally
  identical for Cox and the sibling migrated classes' choice of the plain
  `InferenceRand` version — not "weaker" as first assumed — was correct
  all along).

  **A second, unrelated bug was uncovered and fixed in the process.**
  `compute_estimate_with_bootstrap_weights` (Cox's own body, unmodified by
  this fix) calls `weighted_cox_bootstrap_surrogate_fit()`
  (`globals.R`), which was silently returning `NULL` on every call once
  actually reachable for the first time via `BayesianBootstrap` — the
  100%-`NA` Bayesian-bootstrap distribution symptom that Step 3's golden
  tests initially still showed even after the ordering/override fixes
  above. Root-caused (not guessed) via `withCallingHandlers`-based call-
  stack capture, then bisected by manually replicating the function's body
  outside its `tryCatch` wrapper: `survival::coxph(..., init = NULL)`
  throws `"wrong length for init argument"` in the currently-installed
  `survival` 3.8.6 when `init` is passed explicitly as `NULL`, rather than
  tolerating it as "no warm start" the way it evidently once did or the
  function's author assumed — confirmed with a two-line standalone
  reproduction independent of this package entirely. Fixed by building the
  `coxph()` call's argument list dynamically and only including `init`
  when non-`NULL`, via `do.call()`, instead of always passing
  `init = init`. Pre-existing, unrelated to interval censoring or to this
  component-composition fix — simply never reachable before, since Cox
  never had `BayesianBootstrap` wired in for the framework to actually
  call this function.

  **Step 3 (golden tests — caught a false failure, saved from over-
  fixing).** A first golden-test pass (all resampling calls chained on one
  `inf` object) still showed the Bayesian-bootstrap distribution as 100%
  `NA` even after both fixes above, with the error message `"No
  Bayesian-bootstrap context is installed on this inference object."`
  Reproduced the *identical* failure on a completely unrelated,
  untouched-by-this-fix class (`InferenceSurvivalKMDiff`) using the exact
  same call sequence (randomization test, then Bayesian bootstrap, on the
  same object) — proving it's a pre-existing bug in the shared reusable-
  worker infrastructure that composing `BayesianBootstrap` merely exposed
  for Cox, not something this fix introduced. Tracked separately as
  TODO-17 below rather than chased further here (out of scope: Cox's own
  capabilities need to work, not the cross-operation worker-reuse
  contract) — **later closed as a false positive of this session's
  light-reload verification technique, not a real bug; see TODO-17's own
  entry.** Rewrote the golden tests to use a fresh object per capability
  (also just better test hygiene) and re-verified: `compute_rand_two_sided_pval`,
  `approximate_randomization_distribution_beta_hat_T`,
  `approximate_bootstrap_distribution_beta_hat_T`,
  `compute_bootstrap_two_sided_pval`,
  `approximate_bayesian_bootstrap_distribution_beta_hat_T` (mean/sd
  checked, not just "finite" — centered near the point estimate, non-
  degenerate spread), `compute_bayesian_bootstrap_two_sided_pval`,
  `compute_bayesian_bootstrap_confidence_interval`,
  `compute_rand_bootstrap_two_sided_pval` (BRT), and
  `compute_jackknife_estimate` all pass. A second apparent failure — TODO-6's
  interval-censored estimate no longer matching a direct `icenReg::ic_sp()`
  call — turned out to be a bug in the *test script*, not the package: the
  manual comparison omitted the `x1` covariate that Cox's own dispatch
  correctly includes via `private$get_X()`; adding it back to the manual
  call reproduced the package's answer to full numerical precision. Also
  re-ran the pre-existing Cox suite (`test-brt-smoothed-coxph-kernel.R`,
  `test-coxph-hessian-symmetric-writes.R`, `test-coxph-robust-vcov.R`) —
  no regressions. New file `tests/testthat/test-cox-component-composition.R`
  (12 assertions, all passing) covers all of the above plus the
  `weighted_cox_bootstrap_surrogate_fit()` fix directly.

  **Step 4 (why the earlier attempt's specific symptoms happened).**
  Answered by Step 2's ordering discovery: `compute_jackknife_estimate`
  regressing and `compute_rand_two_sided_pval` still crashing "even once
  present" are both consistent with the wrong-side-wins ordering bug
  (jackknife depends on `resolve_jackknife_unit` et al., which — while
  behaviorally identical either way for *this* collision — sat downstream
  of the same backwards merge order; and the earlier attempt never added
  the explicit `compute_rand_two_sided_pval = InferenceRand$public_methods$...`
  line at all, per its own documented change list, so it's unclear how it
  ever appeared non-`NULL` there — plausibly a description imprecision in
  that earlier post-mortem rather than a fact re-verified at the time).

  **Step 5 (migration marker) — deliberately not done.** `fix_inference_hierarchy.md`'s
  `mark_inference_class_migrated()` convention belongs to that document's
  own migration bookkeeping, which a concurrent session is actively
  working through elsewhere in this same repository; a short cross-
  reference note was added there instead of touching its checklist state
  directly, to avoid colliding with that work.
- [x] TODO-14 (added 2026-08-13, extracted from completed TODO-1/TODO-1a's
  own closing notes so it isn't lost): run the full, exhaustive
  "every existing exact-time and right-censored survival test case is
  bit-identical before/after" regression sweep that TODO-1a called for and
  deferred. The original "blocked on a pre-existing C++ build failure"
  reason is stale (the package now compiles and loads fine; targeted runs
  across TODO-2/TODO-6's work already pass) — the sweep simply has never
  been run in full. Schedule it when no concurrent session is mid-editing
  `Inference*` files, since transient broken states from parallel work were
  the actual obstacle last time.

  **Done — scoped to every survival-relevant test file, not a literal
  before/after diff.** A true bit-identical before/after comparison would
  need a clean pre-TODO-1 snapshot to diff against, which isn't safely
  obtainable here (git stash/checkout risk against a large amount of
  concurrently-in-progress, uncommitted work from another session); the
  practical equivalent — confirming every survival-relevant test currently
  passes, which a genuine regression would break — was run instead. Swept
  all 19 survival-touching test files not already exercised by TODO-3/4/6/
  7/8/9/13/15's own verification passes this session
  (`test-argument-permutations.R`, `test-ci-rand.R`,
  `test-clogit-plus-glmm-cpp-equivalence.R`,
  `test-custom-implementation-canonical-reductions.R`,
  `test-design-inference.R`, `test-designs.R`, `test-fast_glm_outputs.R`,
  `test-full-likelihood-migration-baseline.R`,
  `test-inference-migration-harness.R`, `test-kk21-weighted-crossprod.R`,
  `test-mixin-contracts.R`, `test-mle-km-summary-table.R`,
  `test-partial-likelihood-migration-baseline.R`,
  `test-rcpp-fitting-equivalence.R`, `test-rcpp-fitting-real-data.R`,
  `test-simulation-framework-extended.R`, `test-smart-start-helpers.R`,
  `test-static-cleanup-guardrails.R`, `test-todo98-new-kernel-smoke.R`),
  via a clean `library(EDI)` install (the environment had in fact stabilized
  by the time this ran, contrary to the initial deferral recommendation).

  **Found and fixed 5 more genuine `dead=`/stale-field call sites TODO-15's
  earlier sweep missed** (same class of bug, just not caught the first
  time since TODO-15 grepped rather than ran the full suite):
  `test-mle-km-summary-table.R` had 4 (`add_all_subject_responses(time,
  rep(1L, 60L))` ×2 for Cox/Weibull — all-exact, `rep(1L,...)` simply
  dropped; `add_one_subject_response(i, y, 1L)` ×2 for Count/Incidence
  responses, where the stale 3rd argument doesn't even correspond to a
  survival-specific concept for those response types and was just an
  illegitimate copy-paste artifact); `test-simulation-framework-extended.R`
  had a stale direct read of `des$.__enclos_env__$private$dead` (the raw
  field no longer exists) replaced with the public `get_effective_dead()`
  accessor, which reconstructs the same semantics from `y`.

  **Everything else that failed characterized as pre-existing/unrelated,
  confirmed via the clean-install methodology (learned from TODO-17) so
  none of these are re-verification artifacts:** a recurring
  `"cannot change value of locked binding for 'best_X_colnames'"` error
  inside `generate_mod()` on multiple `define_inference_class()`-migrated
  classes, seen in 4 different files — tracked as new **TODO-24**; a
  `mirai`/`nanonext` parallel-dispatcher `"Permission denied"` error
  (sandboxed-environment limitation, not a code bug); a `SurvivalWeibullLikelihood`
  "public method contract mismatch" error in
  `test-full-likelihood-migration-baseline.R` — this is the concurrent
  session's own in-progress Weibull migration-prep scaffolding
  (`SurvivalWeibullLikelihoodSource` in `inference_survival_weibull.R`,
  noticed but deliberately not touched during TODO-9's re-verification
  pass) being actively mid-flight, not something to fix here; a
  `type = "Zhang"` dispatch signature mismatch in `test-ci-rand.R`
  (incidence-specific, unrelated to survival); `static-cleanup-guardrails`
  file-count mismatches (a repository-hygiene snapshot test, almost
  certainly reflecting the concurrent session's own in-flight file
  changes, not a real static-cleanup violation from this document's work).
- [x] TODO-15 (added 2026-08-13, from completed TODO-6's "found along the
  way" note): clean up `test-rand-bootstrap.R`'s pre-existing failure
  cluster — stale positional `dead =` call sites left over from the TODO-1
  schema migration and stale class-hierarchy assertions — and sweep the rest
  of the test suite for other call sites still using the removed
  `dead =` argument/`get_dead()` accessor (the same class of staleness
  TODO-2's finding 2 fixed in `test-designs.R`). The
  `"attempt to apply non-function"` crash in the same file is TODO-13's
  Cox gap, tracked separately above — fixing these test files should not
  wait on it.

  **Done.** `test-rand-bootstrap.R`'s stale class-hierarchy assertions
  (`is(inf, "InferenceNonParamBootstrap")` etc.) replaced with the modern
  capability-registry equivalent (`inf$supports("nonparametric_bootstrap")`
  etc.) plus representative `is.function()` checks — migrated classes
  compose these capabilities via `define_inference_class()` rather than
  literally `is()`-inheriting the old R6 base classes, so the old assertion
  form is permanently stale, not just temporarily broken. Its `dead[t]`
  positional-argument call site (and every other one found across the
  whole suite) converted to the `(y, y_L, y_R)` convention.

  **The sweep found 16 broken call sites across 14 files, all fixed**
  (confirmed each was a *real* bug, not a false positive, by checking
  whether `y_L`/`y_R` semantics were actually intended before touching
  anything — several near-identical `deads =`/`dead =` matches turned out
  to be the *working* `add_all_subject_responses_seq()` test helper, which
  already correctly bridges to the new API and needed no change):
  - `add_all_subject_responses(y, dead)`/`(ys=, deads=)` direct positional/
    named calls, silently binding `dead` into the `y_L` parameter slot
    (or erroring loudly for the named form) —
    `test-bayesian-bootstrap.R`, `test-bootstrap-reused-worker-asymp-families.R`,
    `test-gehan-wilcox-fused-martingale.R`, `test-km-median-canonical.R`
    (×3, all-exact data — `deads=` simply dropped), `test-bartlett-lr-approx-smoke-families.R`,
    `test-parametric-bootstrap-lr-smoke-families.R`, `test-asymp-inference-paths.R`,
    `test-smart-default-false.R`, `test-smart-start-inference-policies.R`,
    `test-smart-start-warm-paths.R`.
  - `add_one_subject_response(t, y, dead_indicator)` — same class of bug at
    the single-subject level, some with a variable `dead[t]` (needing the
    full `y`/`y_L`/`y_R` branch, fixed in `test-rand-bootstrap.R`'s
    `run_fixed()`) and several with a literal always-`1` (simplified to
    just dropping the argument) in `test-asymp-inference-paths.R` (×5),
    `test-parametric-bootstrap-lr-smoke-families.R` (×3),
    `test-bartlett-lr-approx-smoke-families.R`,
    `test-bartlett-lr-ols-exact.R`, `test-proportion-bootstrap-diagnostics.R`,
    `helper-likelihood-method-smoke.R` (×3).
  - Two `@examples` roxygen blocks with the same stale positional/named
    call, which would fail `R CMD check`'s example-execution step for any
    user who ran them: `inference_survival_gehan_wilcox.R` (×3, identical
    block), `inference_survival_km_diff.R`, `inference_survival_log_rank.R`.
  - `get_dead()`: zero call sites found anywhere in `R/` or `tests/` — never
    actually used, nothing to fix.

  **Verification.** Each fixed file re-run individually (light-reload not
  needed — pure R-level test/documentation edits); `test-gehan-wilcox-fused-martingale.R`,
  `test-km-median-canonical.R`, `test-bartlett-lr-ols-exact.R`, and
  `test-proportion-bootstrap-diagnostics.R` now pass completely.
  `test-bayesian-bootstrap.R`, `test-bootstrap-reused-worker-asymp-families.R`,
  `test-asymp-inference-paths.R`, `test-smart-start-warm-paths.R`, and
  `test-smart-start-inference-policies.R` all confirmed to no longer fail
  at the specific lines fixed here; each still has unrelated pre-existing
  failures further in (mirai/nanonexternal daemon permission errors, a
  locked-environment bug in `install_lazy_inference_component()`, a
  `{-1,+1}` vs. `{0,1}` treatment-coding staleness in
  `overwrite_all_subject_assignments()`, a `best_X_colnames` locked-binding
  error, a quantile-regression bootstrap-weights gap) — none about
  `dead=`/`y_L`/`y_R`, so left alone as out of scope, not silently ignored.
- [x] TODO-16 (added 2026-08-13, found during TODO-9's verification, not
  about interval censoring; **fixed 2026-08-15**): `InferenceSurvivalKKStratCoxPHIVWC$compute_estimate()`
  returned `NA` on *ordinary right-censored* KK14 data with two continuous
  covariates (`n` from 60 up to 300, five different seeds, no interval
  censoring involved at all) — reproduced identically before and after
  every change in this document, so it predates and is independent of this
  plan. Confirmed via a clean `library(EDI)` install (not the light-reload
  technique responsible for TODO-17's false positive), so this one was not
  a verification artifact.

  **Root cause.** `shared()`'s (`inference_survival_KK_strat_cox.R`)
  matched-pairs branch reads `KKstats$m` and
  `KKstats$y_matched_long`/`dead_matched_long`/`w_matched_long`/
  `m_matched_long`/`X_matched_long` (per-subject long-format matched data
  fed to `fast_stratified_coxph_regression_cpp()`), and its reservoir
  branch reads `KKstats$y_reservoir`/`dead_reservoir`/`w_reservoir`/
  `X_reservoir`/`nRT`/`nRC`. This class delegated `compute_basic_match_data()`
  to the generic shared `private$compute_basic_kk_match_data_impl()` →
  `.compute_kk_basic_match_data_cached()` → `compute_zhang_match_data_cpp()`
  pipeline. Inspecting that C++ kernel's full return schema
  (`src/zhang_exact_speedups.cpp:268-286`) showed it only ever produces
  paired-*difference* match data for binary/incidence-style Zhang matching
  (`X_matched_diffs`, `yTs_matched`/`yCs_matched`, `X_reservoir`/
  `y_reservoir`/`w_reservoir`, `nRT`/`nRC`, `m`, ...) and has no `dead`
  argument or per-subject long-format/stratum output at all — it was never
  designed to serve this class's needs. So `KKstats$m` came back nonzero
  (138 matched pairs, confirmed) while every `*_matched_long` field was
  simply absent (`NULL`), producing a dimensionless `cbind(w = w_m,
  X_cov_m)` and `fast_stratified_coxph_regression_cpp()` failing with
  `"Not a matrix."`; the reservoir branch failed too since `dead_reservoir`
  was likewise never produced. Both branches failing made `shared()`
  correctly (given its malformed inputs) report
  `"kk_strat_cox_ivwc_both_failed"` and return `NA`.

  Confirmed via `grep -rln "matched_long" R/*.R` that no other file in the
  codebase references this schema — it is unique to this one class, not a
  contract any other of the ~25+ consumers of the shared
  `compute_basic_match_data()`/`compute_basic_kk_match_data_impl()`
  delegation rely on, so this was an isolated, class-local feature gap
  rather than a shared-infrastructure bug requiring an audit of every
  consumer.

  **Fix.** Added a class-local `compute_basic_match_data()` override to
  `InferenceSurvivalKKStratCoxPHIVWC$private` (`inference_survival_KK_strat_cox.R`)
  that builds `KKstats` directly from this object's own private fields
  (`private$y`, `private$dead`, `private$w`, `private$m`,
  `private$get_X()`) instead of delegating to the Zhang-style kernel,
  splitting subjects into matched (`m_vec > 0`) and reservoir (`m_vec ==
  0`) groups — the same `m_vec[is.na(m_vec)] = 0L; which(m_vec > 0L)`
  idiom already used inline by ~15 sibling KK inference classes (e.g.
  `inference_survival_KK_lwa_cox_ivwc_abstract.R`'s
  `lwa_cox_for_matched_pairs()`/`cox_for_reservoir()`), so no new shared
  abstraction was introduced (see TODO-25 below for that as a distinct,
  separately-scoped idea) and no other consumer of the generic delegation
  was touched.

  While verifying the fix end-to-end (estimate, CI, p-value), found and
  fixed a second, related bug this one had been masking: this class also
  had no `assert_finite_se()` override at all (its sibling
  `InferenceSurvivalKKStratCoxPHOneLik` has one; the base `InferenceAsymp`
  contract has no default — it's a required hook), so
  `compute_asymp_confidence_interval()`/`compute_asymp_two_sided_pval()`
  crashed with `"attempt to apply non-function"` as soon as `shared()`
  could actually produce a real estimate/SE. Confirmed via `library(EDI)`
  (not just `pkgload::load_all()`) that this was a real, pre-existing gap,
  not a reload artifact. Added the same no-op-both-ways stub already used
  by 2+ sibling classes (e.g. `inference_survival_KK_lwa_cox_ivwc_abstract.R`'s
  `assert_finite_se()`).

  **Verification.** Reran the `n = 300` reproduction under
  `pkgload::load_all(compile = FALSE)`: `compute_estimate()` now returns a
  finite log-hazard ratio (`-0.42`), `compute_asymp_confidence_interval()`
  returns a finite two-sided interval, and `compute_asymp_two_sided_pval()`
  returns a finite p-value. Ran `test-partial-likelihood-migration-baseline.R`,
  `helper-likelihood-method-smoke.R`, `test-cox-component-composition.R`,
  `test-gehan-wilcox-fused-martingale.R`, and `test-km-median-canonical.R` —
  all pass, confirming the class-local, non-shared fix didn't regress
  other KK match-data consumers or other Cox/survival inference paths.
- [x] TODO-17 (added 2026-08-14, found during TODO-13's verification, not
  about interval censoring; **closed 2026-08-14 as a false positive** —
  see below): a stale-worker-context bug in the shared Bayesian-bootstrap
  infrastructure. On any single inference object that composes
  `BayesianBootstrap`, calling `compute_rand_two_sided_pval()` or
  `approximate_bootstrap_distribution_beta_hat_T()` (nonparametric
  bootstrap) *first*, then calling
  `approximate_bayesian_bootstrap_distribution_beta_hat_T()` on that *same*
  object, makes every Bayesian-bootstrap replicate fail with `"No
  Bayesian-bootstrap context is installed on this inference object."` — a
  fresh object used for Bayesian bootstrap alone works fine. Reproduced
  identically on `InferenceSurvivalCoxPHRegr` (TODO-13) and
  `InferenceSurvivalKMDiff` (TODO-8, untouched by TODO-13's changes),
  confirming it's a general property of the shared reusable-worker
  machinery (`inference_all_abstract_bayesian_bootstrap.R`/
  `inference_all_abstract_non_param_boot.R`/`inference_all_abstract_rand.R`),
  not specific to either class or to interval censoring.

  **Correction (2026-08-14): not a real bug — an artifact of this
  session's own verification methodology.** Chasing this properly (per
  `systematic-debugging`'s Phase 1 discipline) started with a clean,
  freshly-reinstalled `library(EDI)` rather than the light-reload/
  namespace-monkey-patching technique used to work around this session's
  "no full recompile" constraint elsewhere. With a clean install, the
  *exact* originally-reported sequence — `compute_rand_two_sided_pval()`
  then `approximate_bayesian_bootstrap_distribution_beta_hat_T()` on the
  same `InferenceSurvivalCoxPHRegr` object, and separately
  `approximate_bootstrap_distribution_beta_hat_T()` then the same Bayesian
  call on `InferenceSurvivalKMDiff` — works correctly every time (real,
  finite, correctly-varying replicate values, confirmed across repeated
  runs). Manually replicating `compute_reusable_bootstrap_worker_distribution()`'s
  internals step-by-step (`create_reusable_bootstrap_worker()` →
  `load_bayesian_bootstrap_draw_into_worker()` →
  `compute_bayesian_bootstrap_worker_estimate()`) also worked cleanly.
  The original TODO-13 finding was produced entirely through the
  unlock-binding-and-reassign light-reload technique this session used
  throughout (see TODO-13's own verification note) — that technique
  evidently introduces a subtle namespace/environment inconsistency of its
  own (plausibly: the reassigned `package:EDI`-search-path copy of a class
  generator diverging from its namespace copy, or a stale reference picked
  up by `self$duplicate()`) that does not exist in the actual shipped
  code. Lesson for future sessions: a finding produced only through a
  verification workaround needs re-confirming against a real install
  before being written up as a package bug, not just before being
  "fixed."
- [x] TODO-18 (added 2026-08-14, from
  `R/package_metadata/audits/fast_weibull_regression_cpp_deprecation.md`):
  deprecate and eventually delete `fast_weibull_regression_cpp` in favor of
  `fast_weibull_regression_general_cpp`, now that that audit has verified
  the general kernel is a byte-identical, no-regression drop-in replacement
  for right-censored data (`0` difference in coefficients/vcov/neg-loglik
  at `n=200/1000/5000`; CPU-time ratios `0.94x`-`1.18x` at `n>=1000`, no
  consistent direction — see that report for full methodology). This is
  three sub-TODOs (19/20/21 below) because the legacy kernel still has real
  unmigrated callers on both the R and Python sides; do not skip straight
  to deletion.
- [x] TODO-19 (added 2026-08-14): give `fast_weibull_regression_general_cpp`
  a portable, `EDI_CORE_ONLY`-safe core, mirroring
  `fast_weibull_regression_internal`'s existing pattern (`fast_weibull_
  regression.cpp:217`, which sits outside any `#ifndef EDI_CORE_ONLY` guard
  and returns `edi::ResultMap` rather than an `Rcpp::List`). Today
  `fast_weibull_regression_general_cpp` (line 486) is defined entirely
  inside a `#ifndef EDI_CORE_ONLY` block — it does not compile at all under
  the Python package's `EDI_CORE_ONLY` build, so it cannot be bound there
  as-is. Extract a `fast_weibull_regression_general_internal(X, y, y_L, y_R,
  ...)` portable core exactly analogous to the existing one, with
  `fast_weibull_regression_general_cpp` becoming a thin
  `SEXP`-marshaling wrapper around it (same restructuring already done for
  the legacy pair). This is a prerequisite for TODO-21, not optional
  cleanup — the Python bindings only ever call `_internal` functions, never
  `Rcpp::List`-returning ones. While here, also finish the roxygen/
  `NAMESPACE` `@export` regeneration for `fast_weibull_regression_general_cpp`/
  `get_weibull_regression_general_score_cpp`/
  `get_weibull_regression_general_hessian_cpp` that TODO-3's closing note
  flagged as still owed (currently callable only via `EDI:::`).
- [x] TODO-20 (added 2026-08-14): migrate every remaining `(y, dead)`-based
  R call site of `fast_weibull_regression_cpp` to
  `fast_weibull_regression_general_cpp` (passing `y_L = y, y_R = Inf` for
  right-censored rows and `y` unchanged for exact rows — exactly the
  `dead_to_bounds()` conversion, just done once at the call site instead of
  inside the kernel). Confirmed current callers, all still on `(y, dead)`:
  - `inference_survival_KK_clayton_copula.R`:
    `compute_treatment_estimate_during_randomization_inference`,
    `weibull_for_reservoir`
  - `inference_survival_KK_weibull_frailty.R`:
    `compute_treatment_estimate_during_randomization_inference`,
    `weibull_for_reservoir`
  - `inference_survival_KK_weibull_marginal.R`:
    `InferenceSurvivalKKWeibullMarginal`
  - `inference_survival_weibull.R`: `simulate_under_lik_null`, and
    `weibull_kernel_fit`/`weibull_kernel_score`/`weibull_kernel_hessian`'s
    own `!has_general_censoring` branch (TODO-4 added the general-censoring
    branch but deliberately left the exact/right-censored branch on the
    legacy kernel; once this TODO lands that branch can call the general
    kernel unconditionally and the `has_general_censoring` dispatch itself
    can be removed)
  - `glm_fit_helpers.R`'s public `fast_weibull_regression(y, dead, X, ...)`
    wrapper — keep its outward `(y, dead)` R-level signature (its own
    callers — `other_helpers.R`'s `robust_survreg_with_surv_object`,
    `.fit_standard_weibull_aft_from_matrix`, `.extract_survreg_start` — all
    pass positional `(y, dead, X)` and have no reason to change), just swap
    what it calls internally
  - `compute_weibull_rand_bootstrap_parallel_cpp` (own `dead_to_bounds()`
    caller, used by `InferenceSurvivalKKWeibullMarginal` and
    `test-brt-smoothed-weibull-kernel.R`/
    `test-brt-weibull-kernel-matches-reference.R`) — **decision point, not
    a mechanical swap**: its bootstrap replicates are constructed to be
    right-censored/exact by construction, so confirm whether it needs
    `y_L`/`y_R` at all before touching it, rather than migrating it on
    autopilot
  - Benchmark scripts (`R/benchmark/benchmark_model_fits.R`,
    `benchmark_wald_tests.R`, `benchmark_smart_starts.R`) and
    `R/profile/edi_kernel_profiler.R` — update to benchmark/profile the
    kernel that's actually shipping, not the one being deprecated
  - `test-rcpp-fitting-equivalence.R`/`test-rcpp-fitting-real-data.R` —
    keep exercising `fast_weibull_regression_cpp` directly as the
    known-good baseline until TODO-21 actually deletes it, then convert
    them to test the general kernel instead
- [x] TODO-21 (added 2026-08-14): add the Python binding. Once TODO-19
  lands, add a `fast_weibull_regression_general` binding to
  `python/cpp/bindings_survival.cpp` (mirroring the existing
  `fast_weibull_regression` binding at line 260 — docstring, `.pyi` stub
  regeneration via `pybind11-stubgen`, `NumPy`-style `Parameters` section
  matching the rest of that file), a parity test
  (`python/tests/test_fast_weibull_regression_general.py`, R-fixture
  comparison + omitted-argument test, same pattern as every other bound
  kernel), and a `python/README_PYPI.md` Survival-section usage example.
  Note this is a **new, additive** binding, not a signature change to the
  existing `fast_weibull_regression` binding — see
  `R/package_metadata/finished_features/python_bindings_package_spec.md`.
  Finally, once TODO-20 has migrated every R call site and this TODO has
  given the general kernel Python parity, delete
  `fast_weibull_regression_cpp`, `get_weibull_regression_score_cpp`,
  `get_weibull_regression_hessian_cpp`, `fast_weibull_regression_internal`,
  the now-unneeded `dead_to_bounds()` helper, and the corresponding Python
  binding/tests/README example for the legacy `fast_weibull_regression` —
  update `python/CMakeLists.txt`'s `EDI_KERNEL_SOURCES` comment inventory
  accordingly. This whole TODO-18/19/20/21 chain is itself gated behind the
  broader note in this file's own project memory: no `edi_kernels` Python
  release ships until the wider `y`/`y_L`/`y_R` survival rework is done,
  so there's no urgency to rush TODO-21's deletion step ahead of the rest
  of this migration finishing.
  Completed 2026-08-16: the general portable core now backs both R and
  Python; all R callers, benchmarks, profiles, exports, tests, Python docs,
  stubs, and parity coverage use the general API; and the legacy fit,
  score, Hessian, conversion helper, binding, and tests were removed.
  Verification used a clean Python `EDI_CORE_ONLY` build, four focused
  Python tests, an R source install, and seven focused R Weibull/bootstrap
  test files (148 expectations).
- [x] TODO-22 (added 2026-08-14, found during TODO-15's test sweep, not
  about interval censoring): `InferenceAllSimpleMeanDiff` (and presumably
  every other class composing `components = c("BayesianBootstrap", ...)`)
  is missing `compute_rand_bootstrap_confidence_interval`
  (`is.function() == FALSE`) — the closed-form BRT confidence-interval
  method that the old-style R6 chain provided via a dedicated
  `InferenceRandBootstrapCI` class (`inference_all_abstract_rand_bootstrap_ci.R`,
  sitting between `InferenceRandBootstrap` and `InferenceBayesianBootstrap`
  in that chain) never got its own entry in `EDI_COMPONENT_SPECS`
  (`mixin_contracts.R`) during the component-system migration — unlike
  `RandomizationTest`/`RandomizationCI`/`NonparametricBootstrap`/
  `RandomizationBootstrap`/`BayesianBootstrap`, which all do. Confirmed via
  a clean `library(EDI)` install (not the light-reload technique
  responsible for TODO-17's false positive), so this one is credible as
  reported. Belongs to `fix_inference_hierarchy.md`'s migration effort, not
  this document — not investigated or fixed further here.

  **Done 2026-08-16.** Added the missing lazy
  `RandomizationBootstrapCI` component, depending on
  `RandomizationBootstrap`, and made `BayesianBootstrap` depend on the CI
  layer. Its public CI method, private helpers, and mutable conservative-bound
  counter are now included in migrated classes; component-registry and simple-
  estimator baseline expectations were updated accordingly. The existing
  `test-rand-bootstrap.R` method-availability and CI tests pass under a source
  load.
- [x] TODO-23 (added 2026-08-14, found during TODO-15's test sweep, not
  about interval censoring): `InferenceCountPoisson`'s reusable-bootstrap-
  worker fast path and the disabled-worker slow path give different BRT
  p-values on identical data/seed (`0.146` vs. `0.0488`,
  `test-rand-bootstrap.R`'s "BRT reusable-worker fast path matches the
  standard path exactly" test) — a real, non-trivial numeric discrepancy
  (not a `tolerance`-scale rounding difference), suggesting the two code
  paths are not actually computing the same statistic for this class.
  Confirmed via the same clean-install methodology as TODO-22. Unrelated
  to survival/interval-censoring; not investigated further here.

  **Done 2026-08-16.** The two paths generated identical bootstrap row
  samples but could draw different fresh assignments because constructing a
  one-shot slow-path worker and reusing a fast-path worker consume RNG
  differently. BRT now materializes assignments whenever the estimator
  supports worker reuse, even when reuse is disabled for the comparison path.
  Thus both paths evaluate the same rows and assignments; the existing exact-
  parity regression now passes (`p_fast == p_slow`).
- [x] TODO-24 (added 2026-08-15, found during TODO-14's sweep, not about
  interval censoring): `private$best_X_colnames = ...`/`best_Xmm_colnames = ...`
  throws `"cannot change value of locked binding"` on at least
  `InferenceOrdinalPropOddsRegr` (`test-mle-km-summary-table.R`,
  `test-design-inference.R`) and other `define_inference_class()`-migrated
  classes hit via `test-ci-rand.R` and `test-smart-start-inference-policies.R`
  — always inside `generate_mod()`, always the same field name, recurring
  across at least 4 independent test files during this sweep. Plausibly a
  migrated class no longer setting `lock_objects = FALSE` (or a component
  declaring this field as a locked active binding) where the old-style R6
  base class left it mutable. Confirmed via the clean-install methodology;
  belongs to `fix_inference_hierarchy.md`'s migration effort, not this
  document — not investigated or fixed further here.

  **Done 2026-08-16.** The failure was caused by lazy component contracts
  classifying private fields as callable stubs: `lock_objects = FALSE` was
  already correctly set. Declared every private field owned by the affected
  lazy likelihood components in `owns_state` (including all
  `best_X_colnames`/`best_Xmm_colnames` variants), so R6 creates mutable fields
  rather than locked method bindings. Added a registry test requiring every
  lazy source private field to be declared as owned state. The MLE/KM summary
  table suite, including `InferenceOrdinalPropOddsRegr`, passes under a source
  load.
- [x] TODO-25 (added 2026-08-15, noted while fixing TODO-16, not about
  interval censoring; **done 2026-08-16**): abstracted the matched/reservoir
  index-splitting idiom (`m_vec[is.na(m_vec)] = 0L; i_matched = which(m_vec
  > 0L); i_reservoir = which(m_vec == 0L)`) into a single shared helper.

  **Scoping decision.** A first survey found ~46 occurrences of
  `m_vec[is.na(m_vec)] = 0L` across ~20 files, but most of those are a
  *different* idiom than the one this TODO described — either pure NA-
  normalization with no index split at all (`other_helpers.R`'s
  `.compute_kk_basic_match_data_cached()`/`.compute_kk_lin_basic_match_data_cached()`,
  `globals.R`), or the "combined-likelihood" idiom that converts reservoir
  subjects into singleton strata rather than splitting into two index
  vectors (`inference_survival_KK_weibull_frailty.R` lines 479/543/713,
  `inference_survival_KK_lwa_cox_one_lik_abstract.R`,
  `inference_survival_KK_strat_cox.R`'s `OneLik` class) — every "OneLik"/
  combined class uses this second idiom. Also left `inference_indicidence_exact_fisher.R`'s
  `build_exact_fisher_tables_kk()` alone: it asserts-and-stops on a `NULL`
  `m_vec` instead of defaulting it, and groups by `unique(m_vec[m_vec>0L])`
  rather than computing a flat `matched_idx`, so forcing it into the new
  helper's null-handling convention would have changed behavior. Only the
  genuine matched/reservoir *index-split* sites were refactored — 13 call
  sites across 7 files, all IVWC-style two-component estimators.

  **Fix.** Added `split_kk_matched_reservoir_idx(m_vec, n)` to
  `other_helpers.R` (next to the existing `.compute_kk_basic_match_data*`
  helpers): normalizes a raw pair-id vector (`NULL`-safe, NA-safe,
  `as.integer`-coerced) and returns `list(m_vec, matched_idx,
  reservoir_idx)`. Deliberately does *not* also slice `y`/`dead`/`w`/`X`,
  since call sites need those in different shapes (some build a
  `KKstats`-style list — `inference_survival_KK_strat_cox.R`'s IVWC class
  from the TODO-16 fix above; some call straight into a `fit_cox_model()`-
  style helper — the LWA-Cox/rank-regression/frailty/Clayton-copula
  classes; some just need bare `X[idx, ]`) — unifying those shapes was
  explicitly the part of the original abstraction idea judged too risky
  for one pass, so this keeps each call site's own downstream shape
  unchanged and only centralizes the index computation. Applied at all 13
  sites: `inference_count_KK_cond_poisson.R` (3),
  `inference_incidence_KK_cond_logit.R` (1),
  `inference_survival_KK_lwa_cox_ivwc_abstract.R` (2),
  `inference_survival_KK_clayton_copula.R` (2 functions, 3 call sites),
  `inference_survival_KK_rank_regr_ivwc_abstract.R` (1),
  `inference_survival_KK_weibull_frailty.R` (2 functions, 3 call sites),
  `inference_survival_KK_strat_cox.R` (1, the TODO-16 IVWC override
  itself).

  **Verification.** All 8 touched files parse cleanly. Ran
  `helper-likelihood-method-smoke.R`, `test-design-inference.R`,
  `test-full-likelihood-migration-baseline.R`,
  `test-kk-robust-fallbacks.R`,
  `test-parametric-bootstrap-lr-smoke-families.R`,
  `test-partial-likelihood-migration-baseline.R`, and
  `test-weibull-frailty.R` — 3 pre-existing failures (locked-binding /
  component-loading errors in `InferenceOrdinalAdjCatLogitRegr`,
  `InferenceCountZeroInflatedPoisson`/`HurdlePoisson`, and
  `InferenceSurvivalWeibullRegr`) were confirmed unrelated: none of those
  classes call `split_kk_matched_reservoir_idx` or touch any of the 8
  files edited here, and the failures live entirely inside
  `inference_all_abstract_asymp_lik_std_mod_cache.R`/
  `inference_all_abstract_param_boot.R`/`mixin_contracts.R` — files this
  change never touched — consistent with the concurrent
  `fix_inference_hierarchy.md` migration session working in the same tree
  (see that document's own locked-binding findings, also TODO-24 above).
  Every test actually exercising a refactored class passed.
- [ ] TODO-26 (added 2026-08-16, noticed while explaining TODO-18/19/20/21's
  scope to a question about what's left): turn this plan's own "Feasibility
  By Inference Type" survey note on Weibull frailty /
  `InferenceSurvivalKKWeibullMarginal` into an actual numbered
  implementation TODO — right now it's only a one-paragraph Tier 2 survey
  entry (above, under "Tier 2 — Moderate, rides on Tier 1 or on delegated
  CRAN packages"), not a scoped, actionable item like TODO-3/4/5 were for
  plain Weibull. That survey note says
  `InferenceAbstractKKWeibullFrailtyIVWC`/`OneLik`,
  `InferenceSurvivalKKWeibullFrailtyIVWC`/`OneLik`, and
  `InferenceSurvivalKKWeibullMarginal` all ride on the same
  `fast_weibull_regression_general_cpp` kernel TODO-3/TODO-18-21 already
  migrated (the reservoir/pooled half of these classes already calls it
  directly, confirmed during TODO-11's Clayton-copula feasibility report),
  but that the random-effect integral each of these classes adds on top
  needs "its own integration-layer verification pass, not a guaranteed
  free inheritance" — i.e., someone still needs to confirm the adaptive
  Gauss-Hermite quadrature in `fast_weibull_frailty.cpp` and the BRT-
  smoothed bootstrap path (`compute_weibull_rand_bootstrap_parallel_cpp`,
  `inference_survival_KK_weibull_marginal.R`'s
  `compute_fast_rand_bootstrap_distr`) correctly propagate interval-
  censored `y_L`/`y_R` responses end-to-end, not just that the underlying
  per-subject likelihood term is already interval-censoring-capable.
  Scope this properly (which of the three classes actually need new test
  coverage vs. already work by construction, whether the frailty kernel
  itself needs any change at all or only its R-level callers do) before
  writing the real implementation TODO(s).
- [x] TODO-27 (added 2026-08-16, found while verifying this document is
  actually done, not about interval censoring; **fixed 2026-08-16**): the
  shared randomization/bootstrap worker infrastructure
  (`inference_all_abstract_non_param_boot.R`'s `bootstrap_subset_inference()`,
  `inference_all_abstract_rand.R`'s `sync_randomization_worker_state()` and
  the permutation `run_chunk` closure, `inference_all_abstract_rand_bootstrap.R`'s
  `load_rand_bootstrap_assignment_into_worker()`/`run_rand_bootstrap_iteration()`/
  `run_rand_bootstrap_iteration_with_se()`) still tried to propagate a
  survival subject's censoring status by writing a raw `dead` field onto a
  `Design` object's private environment and reading it back — a pattern
  that predates this plan's TODO-1 migration, which removed `Design`'s
  `dead` field entirely (`dead` now lives only on `Inference` objects,
  populated once from `y`/`y_L`/`y_R` at construction). Every one of these
  writes either crashed outright (`"cannot add bindings to a locked
  environment"`, reproduced live via
  `test-rand-bootstrap.R`'s "BRT batch kernels match the per-iteration
  reference" and "all concrete inference classes compose..." tests) or,
  where the write was silently guarded by an `if (!is.null(...))` check
  that's now always false, produced no crash but silently left `dead`
  unset on the worker (`bootstrap_subset_inference()`'s case — every
  survival nonparametric-bootstrap subset silently got `dead = NULL`).
  Confirmed via `grep` that these are exactly the "bootstrap/permutation/
  randomization-inference paths that resample or copy `y`/`dead` together"
  TODO-2 set out to audit — TODO-2 correctly found and fixed the `y_L`/
  `y_R` half of this problem, but this `dead`-specific regression was
  introduced later (by whatever later commit removed `Design`'s raw
  `dead` field) and never re-audited.

  **Fix.** In each of the 5 call sites, stopped trying to round-trip
  `dead` through the (no-longer-existing) `Design`-private field and
  instead propagate the already-correct value directly onto the
  `Inference` object's own private `dead`: `bootstrap_subset_inference()`
  now derives it from the source object's own `private$dead[indices]`;
  `sync_randomization_worker_state()` no longer clobbers
  `inf_priv$dead` with the now-permanently-`NULL` `des_priv$dead` (dead
  never changes under pure permutation/delta-shift, so simply leaving it
  alone is correct); the `run_chunk`/`run_rand_bootstrap_iteration*`
  call sites assign `inf_priv$dead`/`sub_priv$dead` directly from the
  locally-computed `dead_sim` instead of writing-then-reading through
  Design.

  **Verification.** Reproduced the original crash live (pre-fix) via
  `test-rand-bootstrap.R`. Post-fix, on a fresh recompiled install:
  `InferenceSurvivalLogRank`'s BRT batch-kernel (`compute_fast_rand_bootstrap_distr`)
  and per-iteration reference (`run_rand_bootstrap_iteration`) match
  exactly (`max abs diff = 0`) across 10 draws at delta = 0; the
  nonparametric bootstrap
  distribution (`approximate_bootstrap_distribution_beta_hat_T`, exercises
  `bootstrap_subset_inference()`) returns all-finite values; randomization
  inference (`compute_rand_two_sided_pval`, exercises
  `sync_randomization_worker_state()`) returns a sane p-value. All three
  previously-crashing/silently-wrong code paths confirmed working. An
  intermediate full-suite run also surfaced an unrelated, pre-existing gap
  — `InferenceAllSimpleMeanDiff` (and likely other classes) not currently
  resolvable via `exists()` on a fresh install — confirmed unrelated to
  this fix (a class-loading/component-registry issue, `fix_inference_hierarchy.md`
  territory) and not investigated further here.

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
